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

int strfind(const char *s1, const char *s2);
int process_data(char *datagram, int n);

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
		
	char str[10];
	int port, val, len=strlen(data);

	RemoveSpaces(data);

	if(strncmp(data, SIOD_ID, 4)){
		if(verbose ==2) printf("The SIOD_ID doesn't match\n");	
		return -1; 
	}

	if(len>4) 
		port=data[4]+'0';
	else{
		if(verbose ==2) printf("Port is not specified\n");
		return -1; 
	}

	if(len>5)                
		val=data[5]+'0';
        else{
                if(verbose ==2) printf("Value is not specified\n");
                return -1; 
        }

	
	return 0;

}


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

//The function searches for the posible match of s2 inside s1
//Returns 0 if match found 
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

