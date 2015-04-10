#!/bin/sh
#script to check 3G status


FIRST_UPLOAP_DONED=0
MODEL=""
MODEL_MW3200=`cat /etc/banner | grep '\-MW3200\-'`

if [ ! -z "$MODEL_MW3200" ]; then
	MODEL='MW3200'
fi

if [ ! -d  /var/3G ]; then
  mkdir /var/3G
fi


while [ 1 ]
do
#Check ICCID from logread, use command AT+ICCID
if [ ! -f /var/3G_ICCID ]; then
        ICCID=`logread | grep "ICCID:" | tail -n 1 | awk '{gsub(/\^M/,"")}{print $8}'`
        if [ ! -z $ICCID ]; then   
                echo $ICCID > /var/3G_ICCID
                logger 'write ICCID to /var/3G_ICCID'
        fi
fi

#Check SIM IMSI from logread, use command AT+CIMI
#For MW3200, it is AT+IMSI
if [ ! -f /var/3G/IMSI ]; then
		if [ $MODEL = "MW3200" ]; then
			IMSI=`logread | grep " AT+IMSI" -A 1 | tail -n 1 | awk '{gsub(/\^M/,"")}{print $7}'`
		else
			IMSI=`logread | grep " AT+CIMI" -A 1 | tail -n 1 | awk '{gsub(/\^M/,"")}{print $7}'`
		fi
        
        if [ ! -z $IMSI ]; then   
                echo $IMSI > /var/3G/IMSI
                logger 'writing IMSI to /var/3G/IMSI'
        fi
fi

#check and save MEID
if [ ! -f /var/3G/MEID ];then
	if [ $MODEL = "MW3200" ]; then
		MEID=`logread | grep " AT^MEID" -A 1 | tail -n 1 | awk '{gsub(/\^M/,"")}{print $7}'`
	fi
fi

if [ $MODEL != "MW3200" ]; then
	#Check IMEI from logread, use command AT+EGMI=0,7
	if [ ! -f /var/3G/IMEI ]; then
        IMEI=`logread | grep "EGMR:" | tail -n 1 | awk '{gsub(/\^M/,"")}{gsub(/\"/,"")}{print $8}'`
        if [ ! -z $IMEI ]; then   
                echo $IMEI > /var/3G/IMEI
                logger 'write IMEI to /var/3G/IMEI'
        fi
	fi
fi

#3G Ready LED
IP_3G=`ifconfig | grep -A 1 3g | grep "inet addr"| awk '{/addr:/,""}{print $2}'`
if [ ! -z $IP_3G ]; then
	echo 1 > /sys/devices/platform/leds-gpio/leds/dragino2:red:system/brightness
	if [ $FIRST_UPLOAP_DONED -eq 0 ];then
		lua /usr/bin/update_status_foxconn
		FIRST_UPLOAP_DONED=1
	fi
	if [ ! -z `grep 'address=/#/' /etc/dnsmasq.conf`  ];then
		sed '/address=\/#\//d' /etc/dnsmasq.conf -i
		/etc/init.d/dnsmasq restart
	fi
else
	echo 0 > /sys/devices/platform/leds-gpio/leds/dragino2:red:system/brightness
	if [ -z `grep 'address=/#/' /etc/dnsmasq.conf` ];then
		echo 'address=/#/192.168.10.1' >> /etc/dnsmasq.conf
		/etc/init.d/dnsmasq restart
	fi	
	
	# Detect if we need to disconnect serial connection
	# MESS_CODE=`logread | grep 'chat' | grep -e 'ATDT#777' -e '~^?' | tail -1 | grep '~^?'`
	DIALUP_FAIL=`logread | grep 'chat' | grep -e 'ATDT#777' -e 'Failed' | tail -1 | grep 'Failed'`
	if [ ! -z "$DIALUP_FAIL" ]; then
		lua /usr/bin/send_AT_command ATH0 /dev/ttyUSB3
		sleep 10
	fi
fi

#Detect if the 3G connection is a fake 

sleep 5

done