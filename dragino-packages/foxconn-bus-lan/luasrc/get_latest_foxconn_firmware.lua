#!/usr/bin/lua 

--[[

    Update Script for FOXCONN Firmware. 

    Copyright (C) 2014 Dragino Technology Co., Limited

]]--

local foxconn=require('dragino.foxconn_server')
local utility = require('dragino.utility')
local luci_util = require('luci.util')

local model='BL01'
local cur_version=luci_util.trim(luci_util.exec('sed \'s/foxconn-//g\' /etc/banner | grep "BusLAN" | awk \'{print $3}\''))

--get latest firmware version
local code, chunk = foxconn.check_firmware_update_status(model,cur_version)

if code == 200 then
  --utility.tabledump(chunk)  
  --have new firmware
  if chunk.result then
    local step = 0 -- no file
	local retry_count = 0
    while step ~=1 and retry_count < 3 do
	  print('Downloading.....  Try count: '..retry_count+1)
      local download_status = os.execute('wget "'..chunk.firmware_info.download_url.. '" -O /var/image.tmp')
	  local md5sum = luci_util.trim(luci_util.exec('md5sum /var/image.tmp | awk \'{print $1}\''))
	  if md5sum == chunk.firmware_info.file_md5 then
	    step = 1
		print('md5sum check match,firmware download done')
	  end
	  retry_count = retry_count + 1
	  if retry_count == 3 then
	    print('Download FAIL \n\r\n\r')
	  end
	  print('\n\r')
	end
	
	if step == 1 then
	  -- update firmware
	  print('WARNING:  process upgrade, please don\'t power off the device during upgrade\n\r')
	  os.execute('cd /var/ ; /sbin/sysupgrade -n image.tmp')
	end
  end
end

