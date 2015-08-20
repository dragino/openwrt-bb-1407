#/bin/sh

# Set the following values to somewhat less than your actual download
# and uplink speed. In kilobits. Also set the device that is to be shaped.
#INGOING traffic (gateway)
IN=br-lan
OUT=ifb0
#what ip do you want to limit
INET="192.168.1."
LimitedIP=`cat /proc/net/arp | grep $INET | grep -v ${INET}254 | awk -F "[.| ]" '{print $4}'`
#Total DOWNLINK

#Set Limit rate for Download and Upload
GLOBAL_TRAFFIC_CONTROL=`uci get nodogsplash.trafficcontrol.enable`
SAME_BANDWIDTH=`uci get nodogsplash.trafficcontrol.all_user_same_bandwidth`
DownloadLimitTotal=`uci get nodogsplash.trafficcontrol.DownloadLimitTotal`
UploadLimitTotal=`uci get nodogsplash.trafficcontrol.UploadLimitTotal`
USER_DOWNLIMIT_DEF=100
USER_UPLIMIT_DEF=100
Unit="kbit"


##Start Traffic Control 
start(){
	#create a temporary folder to store the traffic control per user.
	[ ! -d /var/tc ] && mkdir /var/tc
	[ ! -f /var/tc/client ] && touch /var/tc/client
	
    #clean br-lan existing down- and uplink qdiscs, hide errors
    /usr/sbin/tc qdisc del dev $IN root 2>/dev/null
	/usr/sbin/tc qdisc del dev $IN ingress 2>/dev/null
	ip link set dev $OUT up
	/usr/sbin/tc qdisc del dev $OUT root 2>/dev/null


    # install root htb of downlink and uplink
    # main class
	/usr/sbin/tc qdisc add dev $IN ingress
    /usr/sbin/tc qdisc add dev $IN root handle 1: htb
    /usr/sbin/tc class add dev $IN parent 1: classid 1:1 htb rate $DownloadLimitTotal$Unit
	/usr/sbin/tc qdisc add dev $OUT root handle 1: htb default 30
	/usr/sbin/tc class add dev $OUT parent 1: classid 1:1 htb rate $UploadLimitTotal$Unit
	
    #simgle ip limit
    /usr/sbin/tc class add dev $IN parent 1:1 classid 1:2 htb rate $DownloadLimitTotal$Unit
    /usr/sbin/tc qdisc add dev $IN parent 1:2 sfq perturb 2
	/usr/sbin/tc class add dev $OUT parent 1:1 classid 1:30 htb rate $UploadLimitTotal$Unit
	/usr/sbin/tc qdisc add dev $OUT parent 1:30 handle 30: sfq perturb 10
	ifconfig $OUT up
	
	if [ $SAME_BANDWIDTH == '0' ]; then
		##Save User Limit "
		if [ ! -z $USER_IP ];then
			sed "/$USER_IP/d" /var/tc/client -i
			echo "$USER_IP;$USER_DOWNLIMIT;$USER_UPLIMIT" >> /var/tc/client 
		fi
	fi 
	
	for i in `echo $LimitedIP` 
	do 
		if [ $SAME_BANDWIDTH == '1' ]; then
			echo "All User has same BandWidth" 
			UploadLimitUser=`uci get nodogsplash.trafficcontrol.UploadLimitUser`
			DownloadLimitUser=`uci get nodogsplash.trafficcontrol.DownloadLimitUser`
		else if [ $SAME_BANDWIDTH == '0' ]; then
				echo "Different user has different bandwidth" 
				USER_DOWNLIMIT=`grep "$INET$i" /var/tc/client | awk -F ';' '{print $2}'`
				echo $USER_DOWNLIMIT
				DownloadLimitUser=$USER_DOWNLIMIT 
				[ -z $DownloadLimitUser ] && DownloadLimitUser=$USER_DOWNLIMIT_DEF
				USER_UPLIMIT=`grep "$INET$i" /var/tc/client | awk -F ';' '{print $3}'`
				UploadLimitUser=$USER_UPLIMIT
				[ -z $UploadLimitUser ] && UploadLimitUser=$USER_UPLIMIT_DEF
			fi 
		fi
		echo $INET$i $DownloadLimitUser$Unit $UploadLimitUser$Unit
		#####Control DOWNLINK
		/usr/sbin/tc class add dev $IN parent 1:1 classid 1:1$i htb rate $DownloadLimitUser$Unit
		/usr/sbin/tc qdisc add dev $IN parent 1:1$i sfq perturb 10
		/usr/sbin/tc filter add dev $IN protocol ip parent 1: prio 50 u32 match ip dst $INET$i flowid 1:1$i
		#####Control UPLOAD
		/usr/sbin/tc class add dev $OUT parent 1:1 classid 1:1$i htb rate $UploadLimitUser$Unit
		/usr/sbin/tc qdisc add dev $OUT parent 1:1$i sfq perturb 10
		/usr/sbin/tc filter add dev $OUT protocol ip parent 1: prio 50 u32 match ip src $INET$i flowid 1:1$i
		/usr/sbin/tc filter add dev br-lan parent ffff: protocol ip u32 match ip src $INET$i action mirred egress redirect dev ifb0
	done 
	
    #Other traffic
    #/usr/sbin/tc filter add dev $IN protocol ip parent 1: prio 2 u32 match ip dst ${INET}254 flowid 1:1
}


#show status
status() {
    echo "1.show qdisc $IN:----------------------------------------------"
    /usr/sbin/tc -s qdisc show dev $IN
    echo "2.show class $IN:----------------------------------------------"
    N1=`/usr/sbin/tc class show dev $IN | wc -l`
    if [ $N1 == 0 ];then
        echo "NULL, OFF Limiting "
    else
        /usr/sbin/tc -s class show dev $IN
        echo "It work"
    fi
    echo "3.show qdisc $OUT:----------------------------------------------"
    /usr/sbin/tc -s qdisc show dev $OUT
    echo "4.show class $OUT:----------------------------------------------"
    N1=`/usr/sbin/tc class show dev $OUT | wc -l`
    if [ $N1 == 0 ];then
        echo "NULL, OFF Limiting "
    else
        /usr/sbin/tc -s class show dev $OUT
        echo "It work"
    fi
}

#stop TC
stop(){
    echo -n "(Delete all qdisc......)"
	echo ""
    (/usr/sbin/tc qdisc del dev $IN root 2>/dev/null && echo "ok.Delete Download Limit sucessfully!") || echo "error."
	(/usr/sbin/tc qdisc del dev $OUT root 2>/dev/null && echo "ok.Delete Upload Limit sucessfully!") || echo "error."
}

while getopts 'o:i:d:u:h' OPTION
do
	case $OPTION in
	o)	MODE="$OPTARG"
		;;
	i)	
		USER_IP="$OPTARG"
		;;

	d)	USER_DOWNLIMIT="$OPTARG"
		;;

	u)	USER_UPLIMIT="$OPTARG"
		;;


	h|?)
		printf "Traffic Control Script \n\n"
		printf "Usage: %s [-o <Operation Mode>] [-i <IP to be controlled>]  [-d <Download Rate>] [-u <Upload Rate>] \n" $(basename $0) >&2
		printf "	-o: Operation Mode: 0)Stop TC; 1) Start TC; 2) Show Status\n"
		printf "	-i: Specify IP to be controlled\n"
		printf "	-d: Specify Download Rate. Unit: kbps\n"
		printf "	-u: Specify Upload Rate. Unit: kbps\n"
		printf "	-h: This help\n"
		printf "\n"
		exit 1
		;;
	esac
done

shift $(($OPTIND - 1))

######################################
##show traffic control status and quit
if [ $MODE -eq 2 ];then
	status
	exit 1
fi

######################################
##Stop traffic control status and quit
if [ $MODE -eq 0 ];then
	stop
	exit 1
fi

######################################
####Start Traffic Control#############
######################################
if [ $GLOBAL_TRAFFIC_CONTROL == '0' ]; then
	echo "Traffic Control is disable"
	exit 0
fi

( start && echo "Flow Control! TC started!" ) || echo "error."
exit 1
