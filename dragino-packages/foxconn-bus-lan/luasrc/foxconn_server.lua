#! /usr/bin/env lua
--[[

    foxconn_server.lua - Lua Script to communicate with foxconn server 
	ver:0.1

    Copyright (C) 2014 Dragino Technology Co., Limited

    Package required: luci-lib-json,luasocket

]]--

local modname = ...
local M = {}
_G[modname] = M

local json = require 'luci.json'
local http = require 'socket.http'
local http_protocol = require 'luci.http.protocol'
local ltn12 = require 'ltn12'
local print,tostring,string,io = print,tostring,string,io
local table = table
local uci = require("luci.model.uci")

local utility = require 'dragino.utility'
local luci_util = require('luci.util')
local QuaiKeUserList='/tmp/ulist'

setfenv(1,M)

uci = uci.cursor()
local HOST = uci:get('foxconn','general','server')
local TOP_URL = 'http://'..HOST..':8080/BusAp/'
local PORT = '8080'
--local debug = service.debug
--debug = tonumber(debug)
local logger = utility.logger

--upload data
--@param data_stream  :JSON format data
--@return code return code
function post_data(data_stream)
	local chunks = {}
	data_stream = http_protocol.urlencode(data_stream)
	local body = 'content='..data_stream
	ret, code, head = http.request(
		{ ['url'] = TOP_URL..'post_log.do',
			method = 'POST',
			headers = {
				["Content-Type"] = "application/x-www-form-urlencoded",
				["Content-Length"] = tostring(body:len()),
				["Connection"] = "Keep-Alive",
				["HOST"] = HOST..':'..PORT,
			},
			source = ltn12.source.string(body),
			sink = ltn12.sink.table(chunks)
		}
	)

	--if debug >= 1 then 
		if  chunks and chunks[1] then
			logger('Upload Data to Foxconn Server:'..HOST..': chunks[1]='..string.gsub(string.gsub(json.encode(chunks[1]),'\\u000a',''),'\\u0022',''))
		end
		--if ret then print('Upload Data to Foxconn Server:  ret='..ret) end
		--print('Upload Data to Foxconn Server: body='..body)
		--print('Upload Data to Foxconn Server: return code='..code)
		--print(tostring(body:len()))
	--end

	return code
end

--check update info
--@param data_stream  :JSON format data
--@return table includes the update require info.
--@update_avail_table
--{
--  "result": true or false 
--  "message": "has update." or "has no update."
--  "firmware_info": {
--    "version": "2.1.1",
--    "release_date": "2014-08-14 18:39:46",
--    "description": "test firmware zzz",
--    "file_name": "test_firmware_2.bin",
--    "file_length": 3634309,
--    "file_md5": "97ea5379fc830c3bec466d62d0dc4bcd",
--    "download_url": "http://xxx.xxx.xxx.xxx/BusAp/firmware.do?action=download&itemId=***"    
--  }
--}
function check_firmware_update_status(model,firmware_ver)
	local  update_avail_table = {}
	local chunks = {}
	ret, code, head = http.request(
		{ ['url'] = TOP_URL..'firmware.do?action=CheckUpdate&model='..model..'&currentVersion='..firmware_ver,
			method = 'GET',
			headers = {
				--["Content-Type"] = "application/x-www-form-urlencoded",
				--["Content-Length"] = tostring(body:len()),
				["HOST"] = HOST..':'..PORT,
				["Connection"] = "Keep-Alive",
			},
			--source = ltn12.source.string(body),
			sink = ltn12.sink.table(chunks)
		}
	)

	--if debug >= 1 then 
		if  chunks and chunks[1] then
			--logger('Upload Data to Foxconn Server: chunks[1]='..string.gsub(string.gsub(json.encode(chunks[1]),'\\u000a',''),'\\u0022',''))
			--print('chunks[1]='..string.gsub(string.gsub(json.encode(chunks[1]),'\\u000a',''),'\\u0022',''))
		end
		--if ret then print('Upload Data to Foxconn Server:  ret='..ret) end
		--print('Upload Data to Foxconn Server: body='..body)
		--print('Upload Data to Foxconn Server: return code='..code)
		--print(tostring(body:len()))
	--end

	return code, json.decode(chunks[1])

end

--Return Nodogsplash Current Client Tables
function getClientsList()
	luci_util.exec('ndsctl clients > /tmp/client_status')
	local client_table={}
	local id='-1'
	for line in io.lines('/tmp/client_status') do
		if string.find(line,'client_id') then
			id = string.match(line,'client_id=(%d+)')
			client_table[id]={}
		end
		if string.find(line,'ip=') then
			client_table[id].ip=string.match(line,'ip=([%d%.%d]+)')
		end	
		if string.find(line,'mac=') then
			client_table[id].mac=string.match(line,'mac=([%w:%w]+)')
		end	
		if string.find(line,'added=') then
			client_table[id].added=string.match(line,'added=([%d]+)')
		end	
		if string.find(line,'active=') then
			client_table[id].active=string.match(line,'active=([%d]+)')
		end	
		if string.find(line,'duration=') then
			client_table[id].duration=string.match(line,'duration=([%d]+)')
		end		
		if string.find(line,'token=') then
			client_table[id].token=string.match(line,'token=([%w]+)')
		end	
		if string.find(line,'state=') then
			client_table[id].state=string.match(line,'state=([%w]+)')
		end		
		if string.find(line,'downloaded') then
			client_table[id].downloaded=string.match(line,'downloaded=([%d]+)')
		end	
		if string.find(line,'avg_down_speed=') then
			client_table[id].avg_down_speed=string.match(line,'avg_down_speed=([%d]+)')
		end	
		if string.find(line,'uploaded=') then
			client_table[id].uploaded=string.match(line,'uploaded=([%d]+)')
		end	
		if string.find(line,'avg_up_speed=') then
			client_table[id].avg_up_speed=string.match(line,'avg_up_speed=([%d]+)')
		end			
	end
	return client_table
end

--Return Quaike Client Control List
function getQuaiKeUserList()
	local quaike_control_table={}
	local file = io.open(QuaiKeUserList,r)
	if file == nil then return quaike_control_table end 
	for line in file:lines() do 
		if string.find(line,'(%x%x:%x%x:%x%x:%x%x:%x%x:%x%x)') then
			local i = #quaike_control_table + 1
			quaike_control_table[i]={}
			quaike_control_table[i].mac = string.match(line,'(%x%x:%x%x:%x%x:%x%x:%x%x:%x%x)')
			quaike_control_table[i].type = string.match(line,'|(%d+)')
		end
	end
	return quaike_control_table
end

return M