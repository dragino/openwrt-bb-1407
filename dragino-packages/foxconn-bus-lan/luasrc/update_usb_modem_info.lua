#! /usr/bin/env lua
--This script is to update the USB modem info for WiFiShare Project. 

local nixio = require 'nixio'
local luci_fs = require 'luci.fs'
local uci = require("luci.model.uci")
uci = uci.cursor()

--Get USB model model info and general model info 
local usb_model=arg[1]
local AT_port
if usb_model == 'MI660' then
	AT_port = '/dev/ttyUSB3'
end

function ATCommand(message,tty)
	local	serialout=nixio.open(tty,"w")      --open uart interface
	serialout:write(message .. '\r\n')
	serialout:close()
end

os.execute('logger "Update 3G ICCID & IMSI & MEID & SYSINFO"')

--Get and save ICCID
if luci_fs.isfile('/var/3G_ICCID') == false then
	ATCommand('AT+ICCID',AT_port)		
end
os.execute('sleep 1')

--Get and save IMEI
if luci_fs.isfile('/var/3G/IMSI') == false then
	ATCommand('AT+IMSI',AT_port)
end
os.execute('sleep 1')

--Get and save MEID
if luci_fs.isfile('/var/3G/MEID') == false then
	ATCommand('AT^MEID',AT_port)
end
os.execute('sleep 1')

--Get sysinfo, determine if we are at 2G or 3G. 
--^SYSINFO: 2,3,0,8,1   //8: means we are in CDMA/HDR HYBRID network
--^SYSINFO: 2,3,0,2,1   //2: means we are in CDMA network
	ATCommand('AT^SYSINFO',AT_port)
os.execute('sleep 2')
ATCommand('AT^HDRCSQ?',AT_port)
os.execute('sleep 2')
ATCommand('AT+CSQ',AT_port)