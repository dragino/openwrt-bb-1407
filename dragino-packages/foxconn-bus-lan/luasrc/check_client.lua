#!/usr/bin/lua 

--[[

    check client and drop according to the trail time

    Copyright (C) 2014 Dragino Technology Co., Limited

]]--

local luci_util = require('luci.util')
local drtool = require('dragino.utility')
local check_time = 20
local foxconn_util = require('dragino.foxconn_server')


local user_trail_timeout=tonumber(luci_util.trim(luci_util.exec('cat /kuaike/run.conf | grep user_trail_timeout | awk -F[=] \'{print $2}\'')))

while 1 do
	--Check if client is expired
	os.execute("sleep " .. tonumber(check_time))
	
	local client_list = foxconn_util.getClientsList()
	local control_table = foxconn_util.getQuaiKeUserList()
	for k,v in pairs(client_list) do 
		for i,j in pairs(control_table) do
			if v.mac == j.mac and j.type == "0" then
				if tonumber(v.duration) > user_trail_timeout then
					luci_util.exec('ndsctl deauth '.. v.ip)
				end	
			end
		end
	end

end