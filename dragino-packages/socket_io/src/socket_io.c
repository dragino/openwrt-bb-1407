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
#include <arpa/inet.h>

#define SOCKET_IO_REV   "0.1"
#define HW_VER "0.1"	

#define TIMEOUT	100000L   	/* in us */
#define SOCKET_BUFLEN 1500	/* One standard MTU unit size */ 
#define PORT 9930
#define SIOD_ID	"1000"		/* The ID of the SIOD. Must be unique 4 digit number */
#define GPIO_MAX_NUMBER	10	/* We have that many GPIOs */
#define STR_MAX		100		/* Maximum string length */
#define MSG_MAX     500     /* Maximum UDP message length */
#define UDP_ARGS_MAX 20		/* we can have that much arguments ('/' separated) in the UDP datagram */ 

enum {OUT, IN };
struct gpio {
	int number;		/* Number of the GPIO of the AR9331 SoC */
	int index;		/* This is how the IO are refered in the wireless mesh */
	int direction;	/* can be 0 for output or 1 for input */
	int value;		/* current value, can be 0 or 1. The state 
				       of the inputs is known only at the moment of reading it */ 
};

struct gpios_tag {		
	int gpios_count;	/* We have that many IOs in the current SIOD */
	struct gpio gpios[GPIO_MAX_NUMBER];
	} gpios;		/* Keeps the state of the local IOs */


typedef struct GST_node GST_node;
struct GST_node {
	int siod_id;		/* ID of the SIOD */					
	struct gpios_tag gpios;		/* gpios.gpio.number is populated only for the local IOs */
	struct GST_node *next;  /* points to the next element in the list */ 
	struct GST_node *prev;	/* points to the previous element in the list */
	} *GST;			/* Keeps the status of all IOs of all nodes including the local node */


int strfind(const char *s1, const char *s2);
int process_udp(char *datagram);
void RemoveSpaces(char* source);
int read_config(void);
int extract_args(char *datagram, char *args[], int *n_args);
char *strupr(char *s);
unsigned long long MACaddress_str2num(char *MACaddress);
void MACaddress_num2str(unsigned long long MACaddress, char *MACaddress_str);
unsigned long IPaddress_str2num(char *IPaddress);
void IPaddress_num2str(unsigned long IPaddress, char *IPaddress_str);
unsigned long long eth0MAC(void);
unsigned long long eth1MAC(void);
unsigned long long wifiMAC(void);
int uciget(const char *param, char *value);
int uciset(const char *param, const char *value);
void ucicommit(void);
void restartnet(void);
void uptime(char *uptime);
int getsoftwarever(char *ver);
int broadcast(char *msg);

enum {ConfigBatmanReq, ConfigBatmanRes, ConfigBatman, ConfigReq, ConfigRes, Config, \
	  RestartNetworkService, RestartAsterisk, ConfigAsterisk, AsteriskStatReq, AsteriskStatRes, \
	  ConfigNTP, Set, SetIf, TimeRange, TimeRangeOut, Get, Put, Req, Mod, \
	  GSTCheckSumReq, GSTCheckSum, GSTReq, GSTdata, Ping, PingRes};
char *cmds[26]={"ConfigBatmanReq", "ConfigBatmanRes", "ConfigBatman", "ConfigReq", "ConfigRes", "Config", \
      "RestartNetworkService", "RestartAsterisk", "ConfigAsterisk", "AsteriskStatReq", "AsteriskStatRes", \
      "ConfigNTP", "Set", "SetIf", "TimeRange", "TimeRangeOut", "Get", "Put", "Req", "Mod", \
      "GSTCheckSumReq", "GSTCheckSum", "GSTReq", "GSTdata", "Ping", "PingRes"};

int verbose=0; 	/* get value from the command line */


/* listening socket */
int udpfd;
struct sockaddr_in servaddr, cliaddr;

/* socket for the brodcasting messages*/
int bcast_sockfd;
struct sockaddr_in bcast_servaddr;

int main(int argc, char **argv){

	int /*udpfd,*/ n, nready; 
	char datagram[SOCKET_BUFLEN];
	fd_set rset;
	socklen_t addrlen;
	//struct sockaddr_in servaddr, cliaddr;
	struct timeval	timeout;
	int res, enabled;	

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
	GST->gpios = gpios; // What I am wanted to do ???????????????????????????????????????


	/* Initialize the broadcasting socket  =============================== */
    bcast_sockfd=socket(AF_INET,SOCK_DGRAM,0);
    enabled = 1;
    setsockopt(bcast_sockfd, SOL_SOCKET, SO_BROADCAST, &enabled, sizeof(enabled));
    bzero(&bcast_servaddr,sizeof(servaddr));
    bcast_servaddr.sin_family = AF_INET;
    bcast_servaddr.sin_addr.s_addr=inet_addr("255.255.255.255");
    bcast_servaddr.sin_port=htons(PORT);	

	/* Start UDP Socket server and listening for commands ================ */
	udpfd = socket(AF_INET, SOCK_DGRAM, 0);
	if(udpfd == -1){
                perror("socket() failed");
		exit(-1);
	}

	//enable reception of broadcasting data
	//enabled = 1;
    //setsockopt(udpfd, SOL_SOCKET, SO_BROADCAST, &enabled, sizeof(enabled));

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
				
			addrlen=sizeof(cliaddr);
			if((n = recvfrom(udpfd, datagram, SOCKET_BUFLEN, 0, (struct sockaddr *)&cliaddr, &addrlen))<0){
				/* System error */

				perror("recvfrom() failed");
				exit(-1);
			} else if (n>0){
				/* We have got an n byte datagram */
				datagram[n] = '\0';
				process_udp(datagram);

				/* Send it back */
				//sendto(udpfd, datagram, n, 0, &cliaddr, addrlen);		
	
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


/* 
 * process the data coming from the udp socket
 */

int process_udp(char *datagram){
		
	int n_args;
	char *args[UDP_ARGS_MAX];  	

	printf("In process_udp \n");


	/* We process only datagrams starting with JNTCIT */
	if ((strlen(datagram)<7) || strncmp(datagram, "JNTCIT/", 7)){
		if(verbose) printf("unrelated datagram => %s\n", datagram);
		return 0;
	} else
		datagram = datagram + 7;

	/* UDP pre processing */
	RemoveSpaces(datagram);
	//datagram = strupr(datagram);
	
	/* extract arguments */
	extract_args(datagram, args, &n_args);

	//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1
	{
		int i;
		//To be removed
		for(i=0;i<n_args;i++){
			printf("%s\n", args[i]);
		}
	}


	switch (hashit(args[0])){
		/*
			ConfigBatmanReq

		*/		
		case ConfigBatmanReq:{



			}
			break;
        /*
       ConfigBatmanRes/MACAddress/SSID/Encryption/Passphrase/WANbridge
			MACAddress:(WiFi)	0a:ba:ff:10:20:30 (WiFi MAC used as reference)
			SSID:				jntcit
			Encryption:			WPA2
			Passphrase:			S10D
			WANbridge:			True, False

        */  
        case ConfigBatmanRes:{
			/* We may fill our table about the available MACaddresses in the mesh */
			char *MACaddress = args[1];
						


            }
            break;
		/*
		ConfigBatman/MACAddress/SSID/Encryption/Passphrase/WANbridge
			MACAddress:(WiFi)(optional)	0a:ba:ff:10:20:30
			SSID:					jntcit
			Encryption:				WPA2
			Passphrase:				S10D
			WANbridge:				True, False	
		*/
        case ConfigBatman:{

            }
            break;
		/*
		ConfigReq

		We send our network parameters, check ConfigRes
		*/
        case ConfigReq:{
				char msg[MSG_MAX];
				char MACAddressWiFi[STR_MAX], MACAddressWAN[STR_MAX], Uptime[STR_MAX], SoftwareVersion[STR_MAX], AAAA[STR_MAX];
				char IPAddressWiFi[STR_MAX], IPMaskWiFi[STR_MAX], IPAddressWAN[STR_MAX], IPMaskWAN[STR_MAX], Gateway[STR_MAX], DNS1[STR_MAX], DNS2[STR_MAX], DHCP[STR_MAX];

				if(verbose) printf("Rcv: ConfigReq\n");

				IPaddress_num2str(wifiMAC(), MACAddressWiFi);
				IPaddress_num2str(eth1MAC(), MACAddressWAN);
            	uptime(Uptime);
            	getsoftwarever(SoftwareVersion);
    			uciget("siod.siod_id.id", AAAA);        
				uciget("network.mesh_0.ipaddr", IPAddressWiFi);
            	uciget("network.mesh_0.ipaddr", IPMaskWiFi);
            	uciget("network.wan.ipaddr", IPAddressWAN);
            	uciget("network.wan.netmask", IPMaskWAN);
            	uciget("network.mesh_0.gateway", Gateway);
            	uciget("network.mesh_0.dns", DNS1);
				uciget("network.mesh_0.proto", DHCP);
				
				sprintf(msg, "JNTCIT/ConfigRes/%s/%s/%s/SIOD/HW_VER/%s/%s/%s/%s/%s/%s/%s//%s", MACAddressWiFi, MACAddressWAN, Uptime, SoftwareVersion, AAAA, \
						IPAddressWiFi, IPMaskWiFi, IPAddressWAN, IPMaskWAN, Gateway, DNS1, DNS2, DHCP);

				printf("Sent: %s\n", msg);

				broadcast(msg);

            }
            break;
		/*
		ConfigRes/MACAddressWiFi/MACAddressWAN/UpTime/UnitType/HardwareVersion/SoftwareVersion/AAAA/IPAddressWiFi/IPMaskWiFi/IPAddressWAN/IPMaskWAN/Gateway/DNS1/DNS2/DHCP
			MACAddressWiFi:				0a:ba:ff:10:20:30
			MACAddressWAN:				0a:cc:10:bb:ab:00
			Uptime: (Linux in seconds)	123.43		
			UnitType: 					SIOD, AsteriskPC, Intercom
			HardwareVersion: 			0.1
			SoftwareVersion: 			0.5(it is convenient to get this from /etc/banner)
			AAAA: (optional)			SIOD ID Only if the UnitType is SIOD
			IPAddressWiFi:(optional)	10.10.0.55
			IPMaskWiFi:(optional)		255.255.255.0
			IPAddressWAN:(optional)		20.20.0.10
			IPMaskWAN:(optional)		255.255.255.0
			Gateway:(optional)			10.10.0.1
			DNS1:(optional)				8.8.8.8
			DNS2:(optional)				4.4.4.4
			DHCP:(optional)				True, False

		Does noting at the moment
		*/
        case ConfigRes:{

            }
            break;
		/*
		Config/MACAddress/IPAddress/IPMask/Gateway/DNS1/DNS2/DHCP
			MACAddress:			0a:ba:ff:10:20:30
			IPAddress:			10.10.0.55
			IPMask:				255.255.255.0
			Gateway:(optional)	10.10.0.1
			DNS1:(optional)		8.8.8.8
			DNS2:(optional)		4.4.4.4
			DHCP:				True, False

		We set our network parameters
		*/
        case Config:{

            }
            break;
		/*
		RestartNetworkService/MACAddress
			MACAddress:(optional)	0a:ba:ff:10:20:30

		We restart network services
		*/
        case RestartNetworkService:{

            }
            break;
        case RestartAsterisk:{

            }
            break;
        case ConfigAsterisk:{

            }
            break;
        case AsteriskStatReq:{

            }
            break;
        case AsteriskStatRes:{

            }
            break;
        case ConfigNTP:{

            }
            break;
        case Set:{

            }
            break;
        case SetIf:{

            }
            break;
        case TimeRange:{

            }
            break;
        case TimeRangeOut:{

            }
            break;        
		case Get:{

            }
            break;        
		case Put:{

            }
            break;        
		case Req:{

            
            }
            break;        
		case Mod:{


            }
            break;        
		case GSTCheckSumReq:{


            }
           	break;        
		case GSTCheckSum:{

            }
            break;        
		case GSTReq:{

            }
            break;
        case GSTdata:{

            }
            break;
        case Ping:{

			}
            break;
        case PingRes:{

			}
            break;

		default:
			if(verbose) printf("Wrong command.\n");
			return -1;
	}


/*

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
	
		case SET:// set the GPIO as per the command 
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
*/

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

	return (i==len1)?-1:0;
}
/*
 * The function extracts the arguments from the UDP datagram. 
 * Standard separator '/' is assumed
 */
int extract_args(char *datagram, char *args[], int *n_args){

	int i;
	*n_args=1;
	args[*n_args-1]=datagram;
	for(i=0;i<strlen(datagram); i++){
		if(datagram[i] == '/'){
			args[(*n_args)++]=&datagram[i+1];
			datagram[i]='\0';
		}
	}	


}

/*
 * Calculates index of the command string so we can use C switch   
 */
int hashit(char *cmd) {

	int i;
	for(i=0; i<sizeof(cmds)/sizeof(char *); i++){
		if(!strcmp(cmd, cmds[i])) return i; 
	}

	return -1;
}

/*
 * Convert MAC address in string format xx:xx:xx:xx:xx:xx into u64 value   
 */
unsigned long long MACaddress_str2num(char *MACaddress){
	
	unsigned char mac[6];
	int ret;	

	ret=sscanf(MACaddress, "%hhx:%hhx:%hhx:%hhx:%hhx:%hhx", &mac[5], &mac[4], &mac[3], &mac[2], &mac[1], &mac[0]);
	if(ret == 6)
		return (unsigned long long)mac[0] | ((unsigned long long)mac[1]<<8) | ((unsigned long long)mac[2]<<16) | ((unsigned long long)mac[3]<<24) | ((unsigned long long)mac[4]<<32) | ((unsigned long long)mac[5]<<40);
	else {
		if(verbose) printf("Wrong MAC address format.\n");
		return 0;
	}
		
}

/*
 * Convert MAC address from a u64 value into string format xx:xx:xx:xx:xx:xx
 * the string should be allocated by the caller
 */
void MACaddress_num2str(unsigned long long MACaddress, char *MACaddress_str){


    sprintf(MACaddress_str, "%02x:%02x:%02x:%02x:%02x:%02x", (unsigned char)(MACaddress>>40), (unsigned char)(MACaddress>>32), (unsigned char)(MACaddress>>24),
															 (unsigned char)(MACaddress>>16), (unsigned char)(MACaddress>>8), (unsigned char)(MACaddress));

}

/*
 * Convert IP address in string format d.d.d.d into u32 value   
 */
unsigned long IPaddress_str2num(char *IPaddress){

    unsigned int ip[4];
    int ret;

    ret=sscanf(IPaddress, "%u.%u.%u.%u", &ip[3], &ip[2], &ip[1], &ip[0]);
    if(ret == 4)
        return (unsigned long)(ip[0]&0xff) | ((unsigned long)(ip[1]&0xff)<<8) | ((unsigned long)(ip[2]&0xff)<<16) | ((unsigned long)(ip[3]&0xff)<<24);
    else {
        if(verbose) printf("Wrong IP address format.\n");
        return 0;
    }

}

/*
 * Convert IP address from a u32 value into string format d.d.d.d
 * the string should be allocated by the caller
 */
void IPaddress_num2str(unsigned long IPaddress, char *IPaddress_str){


    sprintf(IPaddress_str, "%d.%d.%d.%d", (unsigned char)(IPaddress>>24), (unsigned char)(IPaddress>>16), (unsigned char)(IPaddress>>8), (unsigned char)(IPaddress));

}

/*
 * Convert string to upper case
 */
char *strupr(char *s){ 
	unsigned c; 
    unsigned char *p = (unsigned char *)s; 
    while (c = *p) *p++ = toupper(c);

	return s; 
}


/*
 * Retreive local eth0 MAC address
 */ 
unsigned long long eth0MAC(void){
	int fd;
	char mac[18];
	
	fd = open("/sys/class/net/eth0/address", O_RDONLY);

	read(fd, mac, 18);

	close(fd);

	return MACaddress_str2num(mac);
}

/*
 * Retreive local eth1 MAC address
 */
unsigned long long eth1MAC(void){
    int fd;
    char mac[18];

    fd = open("/sys/class/net/eth1/address", O_RDONLY);

    read(fd, mac, 18);

    close(fd);

    return MACaddress_str2num(mac);
}

/*
 * Retreive local WiFi MAC address
 */
unsigned long long wifiMAC(void){
    int fd;
    char mac[18];

    fd = open("/sys/class/net/wlan0/address", O_RDONLY);

    read(fd, mac, 18);

    close(fd);

    return MACaddress_str2num(mac);
}

/*
 * Execute uci get command to retreive a value from the openwrt configuration files 
 * Value should have at least STR_MAX bytes alocated.
 * returns 0 on success
 */
int uciget(const char *param, char *value){

    FILE *fp;
	char *ret, str[100];
	int i, len;	

	sprintf(str, "uci get %s", param);

    fp=popen(str,"r");
    ret=fgets(value, STR_MAX, fp);
    pclose(fp);

	len=strlen(value);
	if(value[len-1]=='\r' || value[len-1]=='\n') value[len-1]='\0';

	if(ret==NULL) 
		return -1;
	else
		return 0;
}

/*
 * Execute uci set command to update value to the openwrt configuration files
 * Note that you have to commit the change afterwords
 * returns 0 on success
 */
int uciset(const char *param, const char *value){

    FILE *fp;
    char str[100];
	char dummy[STR_MAX];

    sprintf(str, "uci set %s=%s 2>&1", param, value);

    fp=popen(str,"r");
    fgets(dummy, STR_MAX, fp);
    pclose(fp);

    if(!strfind(dummy, "Invalid"))
        return -1;
    else
        return 0;
}

/*
 * Commit all changes (in the config files) done by uci set commands
 */
void ucicommit(void){

    FILE *fp;

    fp=popen("uci commit","r");
    pclose(fp);
}


/*
 * Restart network services
 */
void restartnet(void){

    FILE *fp;

	char dummy[STR_MAX];

    fp=popen("/etc/init.d/network reload 2>&1","r");

	while(fgets(dummy, STR_MAX, fp) != NULL){
		printf("%s\n", dummy);

	}

    if(pclose(fp)==-1)
		printf("Issue reloading network services");

}



/*
 * Get the uptime in seconds.
 * Value should have at least STR_MAX bytes alocated.
 *
 */
void uptime(char *uptime){

    FILE *fp;
	int len;

    fp=popen("cut -d ' ' -f 1 </proc/uptime","r");

    fgets(uptime, STR_MAX, fp);

	len=strlen(uptime);
    if(uptime[len-1]=='\r' || uptime[len-1]=='\n') uptime[len-1]='\0';

}

/*
 * Get the software version.
 * ver should have at least STR_MAX bytes alocated.
 */
int getsoftwarever(char *ver){

    FILE *fp;
	char *ret;	
	int len;

    fp=popen("cat /etc/banner | grep 'Version: .*'| cut -f3- -d' '","r");
    ret=fgets(ver, STR_MAX, fp);
    pclose(fp);

	len=strlen(ver);
    if(ver[len-1]=='\r' || ver[len-1]=='\n') ver[len-1]='\0';

    if(ret==NULL)
        return -1;
    else
        return 0;
}

int broadcast(char *msg){
	
	return(sendto(bcast_sockfd,msg,strlen(msg),0, (struct sockaddr *)&bcast_servaddr,sizeof(bcast_servaddr)));

}
