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

#define SOCKET_IO_REV   "0.1"

#define TIMEOUT	100000L   	/* in us */
#define SOCKET_BUFLEN 1500	/* One standard MTU unit size */ 
#define PORT 9930
#define SIOD_ID	"1000"		/* The ID of the SIOD. Must be unique 4 digit number */
#define GPIO_NUMBER	10	/* We have that many GPIOs */
#define STR_MAX		100	/* Maximum string length */

int gpio[GPIO_NUMBER] ={0, 1, 13, 14, 15,16,17, 24, 26, 27};


int strfind(const char *s1, const char *s2);
int process_data(char *datagram);
void RemoveSpaces(char* source);

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

	
	/* init GPIOs ======================================================== */
	init_gpios();


	/* Socket Stuff ====================================================== */
	/* create UDP socket */
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
 * Set all GPIOs as outputs 
 */
int init_gpios(void){
	
	int i, n ,fd, gpio_val_fd[GPIO_NUMBER];
	char str[STR_MAX];

	/* export the GPIOs */
	fd = open("/sys/class/gpio/export", O_WRONLY);
	for(i=0;i<GPIO_NUMBER;i++){
		n = snprintf(str, STR_MAX, "%d", gpio[i]);
		write(fd, str, n);
	}
	close(fd);

	/* set GPIOs as outputs and set them low */
	for(i=0;i<GPIO_NUMBER;i++){
		n = snprintf(str, STR_MAX, "/sys/class/gpio/gpio%d/direction", gpio[i]);
		fd = open(str, O_WRONLY);
                write(fd, "low", 3);
		close(fd);
        }
	
	return 0; 

}

/* process the data coming from the udp socket
 * data - the command coming from the socket.
 *	  Zero terminated string assumed 
 *
 *
 * supported format is :
 *
 *	SET 5000XY
 *
 *	X = input/output number [0 .. 9]
 *	Y = Active / not active [0, 1]
 */
int process_data(char *data){
		
	char str[STR_MAX];
	int fd, n, port, val, len=strlen(data);

	RemoveSpaces(data);

	if(len<3 || tolower(data[0]) != 's' ||  tolower(data[1]) != 'e' || tolower(data[2]) != 't' ){
		if(verbose ==2) printf("Wrong command format. At the moment command should start with SET\n");  
                return -1; 
	}


	if(len>6 && strncmp(data+3, SIOD_ID, 4)){
		if(verbose ==2) printf("The SIOD_ID doesn't match\n");	
		return -1; 
	}

	if(len>7) 
		port=data[7]-'0';
	else{
		if(verbose ==2) printf("Port is not specified\n");
		return -1; 
	}

	if(len>8)                
		val=data[8]-'0';
        else{
                if(verbose ==2) printf("Value is not specified\n");
                return -1; 
        }

	if(len>9){
                if(verbose ==2) printf("command line is to long \n");
                return -1; 
        } 

	/* set the GPIO as per the command */
	if(verbose ==2) printf("SET: GPIO[%d] = %d\n", gpio[port], val);
	n = snprintf(str, STR_MAX, "/sys/class/gpio/gpio%d/value", gpio[port]);
	fd = open(str, O_WRONLY);
	n = snprintf(str, STR_MAX, "%d", val);
	write(fd, str, n);
	close(fd);

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

