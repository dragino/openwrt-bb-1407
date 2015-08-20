#!/usr/bin/lua 

--[[

    a server socket for QuaiKe

    Copyright (C) 2014 Dragino Technology Co., Limited

]]--
local socket = require('socket')
local utility = require('dragino.utility')
local luci_fs = require('luci.fs')
local luci_util = require('luci.util')
local uci = require('luci.model.uci')
uci = uci.cursor()
local logger = utility.logger
local LISTEN_PORT = 9000
local USERLIST='/tmp/ulist'
local ICCID_FILE = '/var/3G_ICCID'
local datatypes  = require("luci.cbi.datatypes")

local server = assert(socket.bind("*", LISTEN_PORT))

-- print a message informing what's up
logger("QuaiKe Connection Socket starts at port" .. LISTEN_PORT)

function AddUser(u)
	local t = {}
    t.IP = string.match(u,'IP="([%d]+\.[%d]+\.[%d]+\.[%d]+)"')  
    t.MAC = string.match(u,'MAC="(%x%x:%x%x:%x%x:%x%x:%x%x:%x%x)"')  
    t.TYPE = string.match(u,'TYPE="([%d])"')  
    t.PHONE = string.match(u,'PHONE="([%d]+)"') 

    if nil==t then return "invalid format" end
    if (not t.IP) or (not t.MAC) or (not t.TYPE) then 
      return "invalid format"
    end
 
    return updateUSERLIST(t)
end

function ReturnMAC(ip)
	local ip_addr = string.match(ip,'IP="([%d]+\.[%d]+\.[%d]+\.[%d]+)"')
    if ip_addr == nil then
      return "invalid IP address"
    end
	local mac
	if ip_addr == uci:get('network','lan','ipaddr') then 
		mac = luci_util.trim(luci_util.exec('ifconfig br-lan | grep "br-lan" | awk \'{print $5}\''))
	else
		mac = luci_util.trim(luci_util.exec('cat /proc/net/arp | grep '.. ip_addr ..' | awk \'{print $4}\''))
	end
    return mac == "" and "no such IP" or mac
end

function ReturnICCID()
    if not luci_fs.isfile(ICCID_FILE) then
	return "no ICCID"
    end
    return luci_util.exec('cat ' .. ICCID_FILE)
end

function ChangeServerIP(h)
	local server = string.match(h,'SERVER=\"(.+)\"')
	if datatypes.host(server) then
		uci:set('foxconn','general','server',server)
		uci:commit('foxconn')
		return "set upload server to ".. server
	else 
		server = uci:get('foxconn','general','server')
		return "invalid hostname or ip address,current server is " .. server
	end
end

function ReturnSN()
	return luci_util.exec("get_qksn")
end

function ReturnClientState(para)
    local mac = string.match(para,'MAC=\"(%x%x:%x%x:%x%x:%x%x:%x%x:%x%x)\"')
    if mac == nil then
      return "invalid MAC"
    end
    local rel = luci_util.trim(luci_util.exec('ndsctl status | grep -A 6 '.. mac .. ' | grep "State" | awk \'{print $2}\''))
    if rel == "Preauthenticated" then 
      return 0
    elseif rel == "Authenticated" then
      return 1
    else
      return 2
    end
end

--Decode data and execute related commands. 
--@CMD1=IP="192.168.10.8"MAC="78:1f:db:b7:35:c0"TYPE="1"PHONE="18565640639"
--@CMD2=IP="192.168.10.8"  => return MAC of this IP
--@CMD3=ICCID  => return device ICCID
--@CMD4=SN   ==> return device SN: xxxxxxxxxxxx
--@CMD5=MAC="A8:40:41:12:34:56"  ==> return MAC internet status: 0: no_internet_access, 1: has_internet_access, 2: not in control list
--@CMD6=SERVER="123.157.208.109"
local cmd_table={['CMD1']=AddUser,
				 ['CMD2']=ReturnMAC, 
				 ['CMD3']=ReturnICCID,  	
				 ['CMD4']=ReturnSN,  
				 ['CMD5']=ReturnClientState, 
				 ['CMD6']=ChangeServerIP
				}


function cmdParse(raw)
	if raw == nil or luci_util.trim(raw) == "" then return end    -- return if raw invalid. 
  
	--check if it is a valid command format [xxxx]
	local cmd = string.match(raw,'(CMD%d)=')
	if nil == cmd then return "No command found" end

	--check commands;
	if cmd_table[cmd] == nil then return "unknown command" end
	local para = string.match(raw,cmd..'=(.+)')  -- parse parameter
	local res = cmd_table[cmd](para)    -- execute command
	return res
end

--Update Local ulist
--@user_table {IP,MAC,TYPE,PHONE}
--@return
function updateUSERLIST(user_table)
  if not luci_fs.isfile(USERLIST) then
	os.execute('touch '..USERLIST)
  end
  os.execute('sed -i \'/'..user_table.MAC..'/d\' ' ..USERLIST)
  os.execute('echo "'..user_table.MAC .. '|'..user_table.TYPE .. '" >> '.. USERLIST)
  os.execute('ndsctl deauth '.. user_table.IP) 
  os.execute('/usr/bin/traffic_control.sh') 
  return luci_util.exec('ndsctl auth '.. user_table.IP)
end

-- loop forever waiting for clients
while 1 do
  -- wait for a connection from any client
  local client = server:accept()
  -- make sure we don't block waiting for this client's line
  client:settimeout(10)
  -- receive the line
  local line, err = client:receive('*l')

  if not err then 
	local res = cmdParse(line)
  	client:send(res .. "\n")
  	client:close()
  else 
  	logger("Socket Connection Error From Client" .. err)  
  	client:send(err .. "\n")
 
  	client:close()
  end	  
end