#! /usr/bin/env lua

--[[

    update_status to foxconn server

    Copyright (C) 2014 Dragino Technology Co., Limited

]]--

local util = require('luci.util')
local sys = require('luci.sys')
local drtool = require('dragino.utility')
local Model = 'MW3200'
local SN = 'TBD'
local lucijson = require('luci.json')
local server = require('dragino.foxconn_server')


print(util.exec('ndsctl status > /tmp/nd_status'))


local dev_status={}
local netinfo = sys.net.arptable()

dev_status.deviceId=util.trim(util.exec('get_qksn'))
dev_status.deviceName='Foxconn Bus LAN WiFi 3G Router'
dev_status.uptime = util.trim(util.exec('uptime | awk \'{print $3}\''))
dev_status.Model=Model
dev_status.deviceSerialNo=SN
local ver, time = drtool.getVersion()
dev_status.deviceFirmwareVersion=ver .. time
dev_status.deviceHardwareVersion='v0.2'
dev_status.deviceSoftwareVersion=ver .. time
dev_status.MAC = util.trim(util.exec('ifconfig | grep "wlan0" | awk \'{print $5}\''))
dev_status.ICCID = util.trim(util.exec('[ -f /var/3G_ICCID ] && cat /var/3G_ICCID'))
dev_status.IMEI = util.trim(util.exec('[ -f /var/3G/IMEI ] && cat /var/3G/IMEI'))
dev_status.IMSI = util.trim(util.exec('[ -f /var/3G/IMSI ] && cat /var/3G/IMSI'))
dev_status.current_clients=nil
dev_status.total_download_kbytes = 0
dev_status.total_upload_kbytes = 0
dev_status.logTime = util.trim(util.exec('date +"%Y-%m-%d %H:%M:%S"'))
dev_status.clientList={}
local current_client = 0

--Construct The Update data table
for line in io.lines('/tmp/nd_status') do
	if ( dev_status.current_clients == nil ) then
		if string.find(line,'Current clients') then
			dev_status.current_clients = string.match(line,'Current clients: ([%d%d]+)')
			for i = current_client,tonumber(dev_status.current_clients)-1 do
				 dev_status["clientList"]["Client "..i] ={}
			end
		end
	else
		if ( current_client < tonumber(dev_status.current_clients) ) then
			if string.find(line,'Client') then
				current_client = tonumber(string.match(line,'Client ([%d%d]+)'))
			end				 
			if dev_status["clientList"]["Client "..current_client].IP== nil then 
				dev_status["clientList"]["Client "..current_client].IP=string.match(line,'IP: ([%d%.%d]+)')
			end
			if dev_status["clientList"]["Client "..current_client].MAC== nil then 
				local MAC = string.match(line,'MAC: ([%w:%w]+)')
				if MAC ~= nil then
				  dev_status["clientList"]["Client "..current_client].MAC=MAC
				  local authType = util.trim(util.exec('cat /tmp/ulist | grep '.. MAC))
				  if authType ~= nil then 
					authType = string.match(authType,'|(%d)')
				  end
				  dev_status["clientList"]["Client "..current_client].authType = authType
				end
			end
			if dev_status["clientList"]["Client "..current_client].download_byte== nil then 
				dev_status["clientList"]["Client "..current_client].download_byte=string.match(line,'Download:%s+([%d%.%d]+)')
			end
			if dev_status["clientList"]["Client "..current_client].upload_byte== nil then 
				dev_status["clientList"]["Client "..current_client].upload_byte=string.match(line,'Upload:%s+([%d%.%d]+)')
			end
			if dev_status["clientList"]["Client "..current_client].addedTime== nil then 
				dev_status["clientList"]["Client "..current_client].addedTime=string.match(line,'Added:%s+(%w.+%w)')
			end
			if dev_status["clientList"]["Client "..current_client].activeTime== nil then 
				dev_status["clientList"]["Client "..current_client].activeTime=string.match(line,'Active:%s+(%w.+%w)')
			end
			if dev_status["clientList"]["Client "..current_client].addedDuration== nil then 
				dev_status["clientList"]["Client "..current_client].addedDuration=string.match(line,'Added duration:%s+(%w.+%w)')
			end
			if dev_status["clientList"]["Client "..current_client].activeDuration== nil then 
				dev_status["clientList"]["Client "..current_client].activeDuration=string.match(line,'Active duration:%s+(%w.+%w)')
			end
			if dev_status["clientList"]["Client "..current_client].authState== nil then 
				dev_status["clientList"]["Client "..current_client].authState=string.match(line,'State:%s+(%w+)')
			end
			if dev_status["clientList"]["Client "..current_client].token== nil then 
				dev_status["clientList"]["Client "..current_client].token=string.match(line,'Token:%s+(%w+)')
			end
		end		
	end
end

--print('Device Table is:')
--drtool.tabledump(dev_status)

--Calculate the total upload /download bytes in 3g-wan



local info_3g_wan = sys.net.deviceinfo()["3g-wan"] 
if info_3g_wan then
  local txb = info_3g_wan.tx_bytes/1024
  local rxb = info_3g_wan.rx_bytes/1024
  dev_status.total_download_kbytes = rxb - rxb%0.1
  dev_status.total_upload_kbytes = txb - txb%0.1
end

--encode lua table to Json string
local data_stream=lucijson.encode(dev_status)

--adjust json string format
data_stream=string.gsub(data_stream,'"Client %d+":','')
data_stream=string.gsub(data_stream,'{{','[{')
data_stream=string.gsub(data_stream,'}}','}]')
--print(data_stream)

server.post_data(data_stream)