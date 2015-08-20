#!/bin/sh

#Check if there is network
OPKG_HOST='www.dragino.com'
MAX_WARN=5
CUR_WARN=1
while [ -z "`fping -e $OPKG_HOST | grep alive`" ]
do
	if [ $CUR_WARN -le $MAX_WARN ];then
		logger 'Fail To Connect to Auto Update Server'
		CUR_WARN=`expr $CUR_WARN + 1`
	fi
	sleep 10
done

logger 'Detect Auto Update Server , Check if we need auto update'
opkg update
opkg upgrade foxconn-bus-lan 