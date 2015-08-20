#include <stdio.h>
#include <errno.h> 
#include <stdlib.h>
#include <sys/types.h> 
#include <sys/socket.h> 
#include <netinet/in.h> 
#include <linux/net.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <uci.h>

#define SOCKET_IO_REV   "0.1"

#define TIMEOUT	100000L   	/* in us */
#define SOCKET_BUFLEN 1500	/* One standard MTU unit size */ 
#define PORT 9930
#define SIOD_ID	"1000"		/* The ID of the SIOD. Must be unique 4 digit number */
#define GPIO_MAX_NUMBER	10	/* We have that many GPIOs */
#define STR_MAX		100	/* Maximum string length */

enum {OUT, IN };
struct gpio {
	int number;		/* Number of the GPIO of the AR9331 SoC */
	int index;		/* This is how the IO are refered in the wireless mesh */
	int direction;		/* can be 0 for output or 1 for input */
	int value;		/* current value, can be 0 or 1. The state 
				   of the inputs is known only at the moment of reading it*/ 
			
};
struct {		
	int gpios_count;	/* We have that many IOs in the current SIOD */
	struct gpio gpios[GPIO_MAX_NUMBER];
	} gpios;		/* Keeps the state of the local IOs */


typedef struct GST_node GST_node;
struct GST_node {
	int siod_id;		/* ID of the SIOD */					
	struct gpios;		/* gpios.gpio.number is populated only for the local IOs */
	struct GST_node *next;  /* points to the next element in the list */ 
	struct GST_node *prev;	/* points to the previous element in the list */
	} *GST;			/* Keeps the status of all IOs of all nodes including the local node */


int strfind(const char *s1, const char *s2);
int process_data(char *datagram);
void RemoveSpaces(char* source);
int read_config(void);

int verbose=0; 	/* get value from the command line */

int main(int argc, char **argv){

	int udpfd, n, nready; 
	char datagram[SOCKET_BUFLEN];
	fd_set rset;
	socklen_t len;
	struct sockaddr_in servaddr, cliaddr;
	struct timeval	timeout;
	int res;	

	/* Splash ============================================================ */

	/* Check for verbosity argument */
	if(argc>1) {
		if(!strcmp(argv[1], "-v")){
			verbose=1;
			printf("socket_io - rev %s (verbose)\n", SOCKET_IO_REV);		
		} else if(!strcmp(argv[1], "-vv")){
			verbose=2;
			printf("socket_io - rev %s (very verbose)\n", SOCKET_IO_REV);
		}
	} else
		printf("socket_io - rev %s\n", SOCKET_IO_REV);

	/* read GPIO config ================================================== */
	read_config();	

	/* Update GST with the local IOs  ==================================== */
	GST = malloc(sizeof(GST_node));
	GST->siod_id = atoi(SIOD_ID);
	GST->next=NULL;  
	GST->prev=NULL;
	GST->gpios = gpios;


	/* Broadcast PUT commands  =========================================== */
	

	/* Start UDP Socket server and listening for commands ================ */
	udpfd = socket(AF_INET, SOCK_DGRAM, 0);
	if(udpfd == -1){
                perror("socket() failed");
		exit(-1);
	}

	/* Prepare the address */
	memset(&servaddr, 0, sizeof(servaddr)); 	
	servaddr.sin_family = AF_INET;
	servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
	servaddr.sin_port = htons(PORT);

	if(bind(udpfd, (const struct sockaddr *)&servaddr, sizeof(servaddr)) == -1){
		perror("bind() failed");
		exit(-1);
	}

	if(verbose) printf("Listening on port %d\n", PORT);	

	for ( ; ; ) {

		/* descritors set prepared */ 
        	FD_ZERO(&rset);
        	FD_SET(udpfd, &rset);

		/* Set the timeout */
		timeout.tv_sec  = 0;
		timeout.tv_usec = TIMEOUT;

		nready = select(udpfd+1, &rset, NULL, NULL, &timeout);
		if (nready < 0) {
			printf("Error or signal\n");
			if (errno == EINTR)
				continue; /* back to for() */
			else {
      				perror("select() failed");
				exit(-1);
			}
		} else if (nready) {
			/* We have data to read */
				
			len=sizeof(cliaddr);
			if((n = recvfrom(udpfd, datagram, SOCKET_BUFLEN, 0, (struct sockaddr *)&cliaddr, &len))<0){
				/* System error */

				perror("recvfrom() failed");
				exit(-1);
			} else if (n>0){
				/* We have got an n byte datagram */
				datagram[n] = '\0';
				process_data(datagram);

                        	/* Send it back */
                        	//sendto(udpfd, datagram, n, 0, &cliaddr, len);		
	
			} else {
				/* The socket closed, this should not happen with UDP */
				printf("The socket closed ?!?!\n");
			}
			
		} else {
			/* Timeout, expected to happens each 100ms or so */
		}
	}

	return(0);

}

/*
 * Read config file and populate the gpios 
 */
int read_config(void){

	struct  uci_ptr ptr;
	struct  uci_context *c;
	struct uci_element *e1, *e2;
	const char *cur_section_ref = NULL;
	char str[STR_MAX];
	int fd, n, number;

	if(!(c = uci_alloc_context())){ 
		printf("Can not allocate the uci_context\n");
		return -1;
	}

	if ((uci_lookup_ptr(c, &ptr, "siod", true) != UCI_OK)) { 
		printf("uci_lookup_ptr failed\n");
		uci_free_context(c);
		return -1;
	}

	if (!(ptr.flags & UCI_LOOKUP_COMPLETE)) {
		c->err = UCI_ERR_NOTFOUND;
		printf("uci redaing didn't complete\n");
		return -1;
	}

	uci_foreach_element( &ptr.p->sections, e1) {
		struct uci_section *s = uci_to_section(e1);
		gpios.gpios[atoi(e1->name)].index = atoi(e1->name);
		uci_foreach_element(&s->options, e2) {
			struct uci_option *o = uci_to_option(e2);
				
			if (!strcmp(e2->name, "number")){
				fd = open("/sys/class/gpio/export", O_WRONLY);
				n = snprintf(str, STR_MAX, "%s", o->v.string);
				write(fd, str, n);
				close(fd);
				number=atoi(o->v.string);

                                gpios.gpios[atoi(e1->name)].number=number;
				gpios.gpios_count = atoi(e1->name) + 1;

			} else if (!strcmp(e2->name, "direction")){
				n = snprintf(str, STR_MAX, "/sys/class/gpio/gpio%d/direction", number);
				fd = open(str, O_WRONLY);
				n = snprintf(str, STR_MAX, "%s", o->v.string);
				write(fd, str, n);
				close(fd);
				if (!strcmp(o->v.string, "out")) 
					gpios.gpios[atoi(e1->name)].direction=0;
				else
					gpios.gpios[atoi(e1->name)].direction=1;
				
			} else if (!strcmp(e2->name, "initialize")){
				n = snprintf(str, STR_MAX, "/sys/class/gpio/gpio%d/value", number);
				fd = open(str, O_WRONLY);
				n = snprintf(str, STR_MAX, "%s", o->v.string);
				write(fd, str, n);
				close(fd);
				if (!strcmp(o->v.string, "1"))    
                                        gpios.gpios[atoi(e1->name)].value=1;
                                else
                                        gpios.gpios[atoi(e1->name)].value=0;
			}
		}
	}
	
	if(verbose ==2) printf("GPIOs are configured as per the configuration file\n");	

	for(n=0;n<gpios.gpios_count; n++){
		printf("gpios[%d].number=%d\n", n, gpios.gpios[n].number);
		printf("gpios[%d].direction=%d\n", n, gpios.gpios[n].direction);
		printf("gpios[%d].value=%d\n", n, gpios.gpios[n].value);
	}
		

	return 0;
}


/* process the data coming from the udp socket
 * data - the command coming from the socket.
 *	  Zero terminated string assumed 
 *
 *
 * supported formats are: (note that the spaces in the commands are optional)
 *
 *   Command to set local output 
 *
 *    SET AAAA X Y
 *
 *	  AAAA = ID of the SIOD
 *	  X    = number of an output [0, 1, .. 9]
 *	       if X is not an output the command is ignored 		
 *	  Y    = Active / not active [0, 1]
 *
 *   Comand to request the state of the local input
 *
 *
 *    GET AAAA X Y
 *
 *        AAAA = ID of the SIOD
 *        X    = number of input/output [0, 1, .. 9]
 *        Y    = Active / not active [0, 1]
 *
 *
 *   Command to update the global status table (GST) with the current IO states
 *
 *
 *    PUT AAAA X Y
 *
 *        AAAA = ID of the SIOD
 *        X    = number of input/output [0, 1, .. 9]
 *        Y    = Active / not active [0, 1]
 *
 * 
 *   Command to update the global status table (GST) with the IO type
 *
 *
 *    MOD AAAA X Y
 *
 *        AAAA = ID of the SIOD
 *        X    = number of input/output [0, 1, .. 9]
 *        Y    = IO type 0 - output, 1 - input 
 *	 	
 */
enum {SET, GET, PUT, MOD };
int process_data(char *data){
		
	char str[STR_MAX];
	int fd, n, cmd, AAAA, X, Y, len=strlen(data);

	RemoveSpaces(data);

/*	if(len<3 || tolower(data[0]) != 's' ||  tolower(data[1]) != 'e' || tolower(data[2]) != 't' ){
		if(verbose ==2) printf("Wrong command format. At the moment command should start with SET\n");  
                return -1; 
	}
*/
	if strncmp(data, "SET", 3) {
		cmd = SET;
	} else if strncmp(data, "GET", 3) {
		cmd = GET;
	} else if strncmp(data, "PUT", 3) {
		cmd = PUT;
	} else if strncmp(data, "MOD", 3) {
		cmd = MOD;
	} else {
		if(verbose) printf("Wrong command.\n");
		return -1;
	}
		

	if(len>6) {
		AAAA=atoin(data+3, 4);
	} else {
		if(verbose) printf("SIOD_ID is missing\n");	
		return -1; 
	}

	if(len>7) 
		X=data[7]-'0';
	else{
		if(verbose) printf("IO is not specified\n");
		return -1; 
	}

	if(len>8)                
		Y=data[8]-'0';
        else{
                if(verbose) printf("Value or type is not specified\n");
                return -1; 
        }

	if(len>9){
                if(verbose) printf("command line is to long \n");
                return -1; 
        } 

	switch (cmd){
	
		case SET:/* set the GPIO as per the command */
			if (gpios.gpio[X].direction != OUT){
				if(verbose) printf("SET command tries to set value to an input, ignoring\n");
				return -1;
			} else if (X > gpios.gpios_count-1) {
				if(verbose) printf("Output out of range, ignoring\n");
				return -1;
			}
			if(verbose ==2) printf("SET: GPIO%d = %d\n", gpios.gpio[X].number, Y);
			n = snprintf(str, STR_MAX, "/sys/class/gpio/gpio%d/value", gpios.gpio[X].number);
			fd = open(str, O_WRONLY);
			n = snprintf(str, STR_MAX, "%d", Y);
			write(fd, str, n);
			close(fd);

			break;

		case GET:
			break;

		case PUT:

			break;

		case MOD:
			break;

	}
	return 0;

}

/*
 * Removes spaces in string
 */
void RemoveSpaces(char* source)
{
	char *i = source;
	char *j = source;
  
	while(*j != 0){
    		*i = *j++;
    		if(*i != ' ') i++;
  	}

  	*i = 0;
}

/*
 * The function searches for the posible match of s2 inside s1
 * Returns 0 if match found 
 */
int strfind(const char *s1, const char *s2){

        int i, len1, len2;

        len1=strlen(s1);
	len2=strlen(s2);
        for(i=0; i<len1; i++){

                if(s1[i]==s2[0]){
                        if (!strncmp(&(s1[i]), s2, len2)){
                                break;
                        }
                }
        }
        if(i==len1)
                return -1;
        else
                return 0; /* match found */


}

