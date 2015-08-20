--[[
   Copyright (C) 2014 Seamus Tuohy
   Copyright (C) 2014 Dan Staples
   Copyright (C) 2015 Edwin Chen
   
   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program. If not, see <http://www.gnu.org/licenses/>.
]]--

local datatypes = require "luci.cbi.datatypes"
local uci = require "luci.model.uci"

local io, pairs, ipairs, table, string = io, pairs, ipairs, table, string

local NDSConfig = {}

NDSConfig.parsed = {}
NDSConfig.confFile = "/etc/nodogsplash/nodogsplash.conf"

function NDSConfig:parseConfig()

   --reload config
   NDSConfig.parsed = {}
   local config = self:load()
   
   -- String Matching tables
   local mac = "%x%x:%x%x:%x%x:%x%x:%x%x:%x%x"
   local s = "^%s*"
   local fw = {
	  set = "FirewallRuleSet%s(.-)%s{",
	  rule = "FirewallRule",
   }
   local function match (line, regex)
	  return line:match(s..regex)
   end
   local function splitMac (line, regex)
	  macs = {}
	  local list = line:match(s..regex)
	  for mac in string.gmatch(list, mac) do
		 table.insert(macs, mac)
	  end
	  return macs
   end
   local values = {
	  MaxClients = {match, "MaxClients%s(%d*)"},
	  ClientIdleTimeout = {match, "ClientIdleTimeout%s(%d*)"},
	  ClientForceTimeout = {match, "ClientForceTimeout%s(%d*)"},
	  TrustedMACList = {splitMac, "TrustedMACList%s(.*)$"},
	  BlockedMACList = {splitMac, "BlockedMACList%s(.*)$"},
	  AuthenticateImmediately = {match, "AuthenticateImmediately%s(.-)%s?"},
	  RedirectURL = {match, "RedirectURL%s(.-)%s?"},
	  EmptyRuleSetPolicy = {match, "EmptyRuleSetPolicy%s([%w%-]*)%s(%w*)"},
	  GatewayName = {match, "GatewayName%s(.-)%s?"}
   }
   --Parsing Logic
   local set = false
   for _,line in ipairs(config) do
	  if set ~= false and line:match("^}$") then
		 set = false
	  end
	  if not line:match(s.."#") and not line:match("^[\n\r]$") then
		 if line:match(fw.set) then
			set = line:match(fw.set)
			NDSConfig.parsed[set] = {}
		 elseif line:match(fw.rule) and set ~= false then
			local _rule = self:parseRule(line)
			table.insert(NDSConfig.parsed[set], _rule)
		 else
			for name, value in pairs(values) do
			   if line:match(s..value[2]) then
				  NDSConfig.parsed[name] = value[1](line, value[2])
			   end
			end
		 end
	  end
   end
end


function NDSConfig:getUci(uciConfig)
   local config = {}
   local uci = uci.cursor()
   if not uciConfig then
	  uciConfig = "nodogsplash"
   end
   table.insert(config, "#======================================================================")
   table.insert(config, "#This config AUTOMATICALLY written. Please edit /etc/config/nodogsplash")
   table.insert(config, "#======================================================================")
   table.insert(config, "\n")
   -- get Firewall Rule Sets
   uci:foreach(uciConfig, "FirewallRuleSet",
			   function(s)
				  --create firewall set header
				  local name = string.gsub(s['.name'], "_", "-") 
				  table.insert(config, s['.type'].." "..name.." {")
				  --Add default firewall rules
				  if s.FirewallRule and next(s.FirewallRule) then
					 for _,rule in ipairs(s.FirewallRule) do
						table.insert(config, "  FirewallRule "..rule)
					 end
				  end
				  --Add user created firewall rules
				  if s.UsrFirewallRule and next(s.UsrFirewallRule) then
					 for _,rule in ipairs(s.UsrFirewallRule) do
						table.insert(config, "  FirewallRule allow "..rule)
					 end
				  end
				  --close firewall set
				  table.insert(config, "}")
				  table.insert(config, "\n")
			   end
   )
   -- get whitelists
   local wlist = uci:get_list(uciConfig, "whitelist", "mac")
   wMacs = table.concat(wlist, ",")
   if wMacs ~= ''then
	  table.insert(config, "TrustedMACList "..wMacs)
	  table.insert(config, "\n")
   end
   -- get blacklists
   local blist = uci:get_list(uciConfig, "blacklist", "mac")
   bMacs = table.concat(blist, ",")
   if bMacs ~= '' then
	  table.insert(config, "BlockedMACList "..bMacs)
	  table.insert(config, "\n")
   end
   -- get interfaces
   local iface = uci:get(uciConfig, "settings", "interfaces")
   table.insert(config, "GatewayInterface "..iface)
   table.insert(config, "GatewayName Free WiFi")
   table.insert(config, "\n")
   -- get settings
   local maxCli = uci:get(uciConfig, "settings", "MaxClients")
   table.insert(config, "MaxClients "..maxCli)
   table.insert(config, "\n")
   
   if uci:get(uciConfig, "settings", "redirect") == '1' then
	  local rUrl = uci:get(uciConfig, "settings", "redirecturl")
	  table.insert(config, "RedirectURL "..rUrl)
	  table.insert(config, "\n")
   end
   
   local ideltimeout = uci:get(uciConfig, "settings", "ClientIdleTimeout")
   table.insert(config, "ClientIdleTimeout "..ideltimeout)  
   local forcetimeout = uci:get(uciConfig, "settings", "ClientForceTimeout")
   table.insert(config, "ClientForceTimeout "..forcetimeout)
   table.insert(config, "\n")
   
 --  local tc_enable = uci:get(uciConfig, "trafficcontrol", "enable")
 --	table.insert(config, "TrafficControl ".. tc_enable)
 --  local dl = uci:get(uciConfig, "trafficcontrol", "DownloadLimit")
 --	table.insert(config, "DownloadLimit ".. dl)
 -- local ul = uci:get(uciConfig, "trafficcontrol", "UploadLimit")
 --	table.insert(config, "UploadLimit ".. ul)
 --	table.insert(config, "\n")		
 
   
   if uci:get(uciConfig, "settings", "autoauth") == '1' then
	  table.insert(config, "AuthenticateImmediately yes")
	  table.insert(config, "\n")
   end
   return config
end

function NDSConfig:load()
   local config = {}
   for line in io.lines(self.confFile) do
	  table.insert(config, line)
   end
   return config
end

function NDSConfig:write(config)
   local file = io.open(self.confFile, "w+")
   for _,line in ipairs(config) do
	  file:write(line.."\n")
   end
   file:close()
end

function NDSConfig:deleteSet(setName, config)
   if config == nil then
	  config = self.loadRaw()
   end
   local start = nil
   local range = nil
   for i,line in ipairs(config) do
	  if line:match("%s*FirewallRuleSet%s"..setName.."%s{") then
		 start = i
	  elseif start ~= nil then
		 if line:match("%s*}%s*") then
			range = {start, i}
			start = nil
			break
		 end
	  end
   end
   if range then
	  local start = range[1]
	  local top = range[2]
	  local cur = top
	  while cur >= start do
		 table.remove(config, cur)
		 top = top - 1
	  end
   end
   self.write(config)
end

--! @brief Parses a firewall rule passed to it and returns a parsed firewall dictionary
function NDSConfig:parseRule(str)
   --FirewallRule permission [protocol [port portrange]] [to ip]
   local rule = {}
   local str = string.gsub(str, "^%s*FirewallRule%s*", "")
   --permission is required and must be either allow or block. 
   local permission = string.match(str, "^%s*%w+")
   if permission == "allow" or permission == "block" then
	  str = string.gsub(str, "^%s*%w+", function(s) rule['permission'] = s; return "" end, 1)
   end
   --protocol is optional. If present must be tcp, udp, icmp, or all. Defaults to all.
   local proto = string.match(str, "^%s-(%w%w%w%w?)%s*")
   local allowed_proto = {"tcp", "udp", "icmp", "all"} 
   for _,ap in ipairs(allowed_proto) do
	  if proto == ap and proto ~= "from" then
		 str = string.gsub(str, "^%s-(%w%w%w%w?)%s*", function(s) rule['proto'] = s; return "" end, 1)
	  end
   end
   print(str)
   if not rule['proto'] then rule['proto'] = "all" end
   --port portrange is optional. If present, protocol must be tcp or udp. portrange can be a single integer port number, or a colon-separated port range, e.g. 1024:1028. Defaults to all ports.
   if rule['proto'] == 'tcp' or rule['proto'] == 'udp' then
	  local port, range = string.match(str, "^%s*port%s*(%d+):?(%d-)")
	  if datatypes.port(port) then
		 rule['port'] = port
	  end
	  if datatypes.port(range) then
		 rule['portRange'] = range
	  end
   end
   -- to ip is optional. If present, ip must be a decimal dotted-quad IP address with optional mask. Defaults to 0.0.0.0/0, i.e. all addresses.
   local direction, ip = string.match(str, "^%s*(%w*)%s*(%d*%..*%d)")
   if datatypes.ipaddr(ip) then
	  rule['ipaddr'] = ip
	  rule['ipDirection'] = direction
   end
   return rule
end

return NDSConfig
