#!/bin/sh
#script to check 3G status


FIRST_UPLOAP_DONED=0
LOCAL_IP=`uci get network.lan.ipaddr`
HOST1="8.8.8.8"
HOST2="www.163.com"
COUNT=10
COUNT1=0

VID=`uci get secn.modem.vendor`
PID=`uci get secn.modem.product`
if [ $VID == "19f5" ] && [ $PID == "9909" ]; then
	USB_MODEL="MI660"
elif [ $VID == "0e8d" ] && [ $PID == "00a5" ]; then
	USB_MODEL="UW980"
fi

[ ! -d  /var/3G ] &&  mkdir /var/3G

while [ 1 ]
do
	if [ $USB_MODEL == "MI660" ]; then
		#Get GPS and SD Card info from Media Server
		if [ $COUNT1 -eq 5 ];then
			lua /usr/bin/gps
			COUNT1=0
		fi
		COUNT1=`expr $COUNT1 + 1`
		
		#Get IMSI and ICCID from 3G Modem		
		if [ $COUNT -eq 20 ];then
			HAS_AT=`ps | grep "process_AT" | grep -v grep`
			if [ -z "$HAS_AT" ];then
				/usr/bin/lua /usr/bin/process_AT_feedback MI660 0 &
			fi
			lua /usr/bin/update_usb_modem_info $USB_MODEL
			COUNT=0
		fi
		COUNT=`expr $COUNT + 1`
		
	fi



	#Check if internet is ready
	#first check if there is 3G connection, if not , see if it is ok to ping some hosts in the internet, 
	#so this script can still works in a ETH1 WAN connection
	HAS_INTERNET=`ifconfig | grep -A 1 3g | grep "inet addr"| awk '{/addr:/,""}{print $2}'` 
	if [ -z "$HAS_INTERNET" ];then 
			HAS_INTERNET=`fping -e $HOST1 | grep alive`
		if [ -z "$HAS_INTERNET" ];then 
			HAS_INTERNET=`fping -e $HOST2 | grep alive`
		fi
	fi
	
	#echo "result $HAS_INTERNET"
	#echo $USB_MODEL
	
	
	if [ ! -z "$HAS_INTERNET" ]; then
		#echo "Has Internet Connection"	
		echo 1 > /sys/devices/platform/leds-gpio/leds/dragino2:red:system/brightness
		#if [ $FIRST_UPLOAP_DONED -eq 0 ];then
			#lua /usr/bin/update_status_foxconn
			#FIRST_UPLOAP_DONED=1
		#fi

		if [ ! -z `grep 'address=/#/' /etc/dnsmasq.conf` ];then
			sed '/address=\/#\//d' /etc/dnsmasq.conf -i
			/etc/init.d/dnsmasq restart
		fi
	else
		#echo "No Internet Connection"
		echo 0 > /sys/devices/platform/leds-gpio/leds/dragino2:red:system/brightness
		if [ -z `grep 'address=/#/' /etc/dnsmasq.conf` ];then
			echo address=/#/$LOCAL_IP >> /etc/dnsmasq.conf
			/etc/init.d/dnsmasq restart
		fi	
	
		# There is not internet connection. do something. 
		# Detect if we need to disconnect serial connection
		if [ $USB_MODEL == "MI660" ];then
			# MESS_CODE=`logread | grep 'chat' | grep -e 'ATDT#777' -e '~^?' | tail -1 | grep '~^?'`
			DIALUP_FAIL=`logread | grep 'chat' | grep -e 'ATDT#777' -e 'Failed' | tail -1 | grep 'Failed'`
			if [ ! -z "$DIALUP_FAIL" ]; then
				lua /usr/bin/send_AT_command ATH0 /dev/ttyUSB3
				#echo 0 > /sys/class/gpio/gpio19/value
				#sleep 1
				#echo 1 > /sys/class/gpio/gpio19/value
				#sleep 10
			fi
		fi
	fi
	
	# Check if the SMSD is running for UW980
	if [ $USB_MODEL == "UW980" ]; then
		smsd_thread_line=`ps | grep "smsd" | grep -v grep | grep /usr/sbin/smsd -c`
		if [ $smsd_thread_line -ne 2 ];then
			/etc/init.d/smstools3 stop
			/etc/init.d/smstools3 start
		fi
	fi 
	

#Detect if the 3G connection is a fake 

sleep 5

done