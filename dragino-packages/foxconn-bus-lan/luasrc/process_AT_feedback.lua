#! /usr/bin/env lua

--Usage /usr/bin/lua process_AT_feedback.lua MI660 [1|0]
local nixio = require 'nixio'
local luci_fs = require 'luci.fs'
local uci = require("luci.model.uci")
uci = uci.cursor()

LOCAL_RECORD_FILE='/var/3G/tmpinfo'

local usb_model=arg[1]
local debug=arg[2]

local AT_port
if usb_model == 'MI660' then
	AT_port = '/dev/ttyUSB3'
end

local serialin=nixio.open(AT_port,"r")   --open serial port and prepare to read data from Arduino	
local datain=nil

function process_at_data(dta)				--record in a local file. 
	if debug == '1' then
		os.execute('echo `date` >> '..LOCAL_RECORD_FILE)
		local f = io.open(LOCAL_RECORD_FILE, "r")
		os.execute("echo '"..dta.. "' >> " .. LOCAL_RECORD_FILE)	
		os.execute("echo ############################ >> "..LOCAL_RECORD_FILE)
	end

	local ICCID=string.match(dta,"+ICCID:(%w+)")
	if ICCID ~= nil then
		os.execute('echo '..ICCID..' > /var/3G_ICCID')
		os.execute('echo '..ICCID..' > /var/3G/ICCID')
		return 
	end
	
	local IMSI=string.match(dta,"+IMSI:(460%w+)")
	if IMSI ~= nil then
		os.execute('echo '..IMSI..' > /var/3G/IMSI')
		return 
	end
	
	local MEID=string.match(dta,"(%x%x%x%x%x%x%x%x%x%x%x%x%x%x)")
	if MEID ~= nil then
		os.execute('echo '..MEID..' > /var/3G/MEID')
		return 
	end
	
	local SYSINFO=string.match(dta,"SYSINFO:([%d,]+)")
	if SYSINFO ~= nil then
		os.execute('sed "/SYSINFO/d" /var/3G/status -i && echo "SYSINFO:'..SYSINFO..'" >> /var/3G/status')
		return 
	end

	local HDRCSQ=string.match(dta,"HDRCSQ:([%d]+)")
	if HDRCSQ ~= nil then
		os.execute('sed "/HDRCSQ/d" /var/3G/status -i && echo "HDRCSQ:'..HDRCSQ..'" >> /var/3G/status')
		return 
	end

	local CSQ=string.match(dta,"+CSQ:([%d,]+)")
	if CSQ ~= nil then
		os.execute('sed "/^CSQ/d" /var/3G/status -i && echo "CSQ:'..CSQ..'" >> /var/3G/status')
		return 
	end
	
	
	

end


while true do
	while datain==nil do        -- read data from serial.          	
		datain=serialin:read(1000)          	
		--serialin:flush()	
	end	
	
	process_at_data(datain)
	
	datain=nil
end

	