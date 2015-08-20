#! /usr/bin/env lua
local socket = require('socket')
local server = '192.168.1.254'
local port = '8888'

client = socket.connect(server, port)
if client then
	client:send('extsd')
	local sd_info=client:receive('*a')
	if sd_info then
		os.execute('echo "'.. sd_info..'" > /var/3G/SD_INFO')
	end
end

client = socket.connect(server, port)
if client then
	client:send('gps')
	local gps_info=client:receive('*a')
	if gps_info then
		os.execute('echo "'.. gps_info.. '" > /var/3G/GPS_INFO')
	end
end



