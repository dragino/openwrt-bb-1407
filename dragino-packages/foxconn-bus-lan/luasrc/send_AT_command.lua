#! /usr/bin/env lua

local nixio = require 'nixio'
 
function DataToUART(message,tty)
	local	serialout=nixio.open(tty,"w")      --open uart interface
	serialout:write(message .. '\r\n')
	serialout:close()
end
 
msg = arg[1]      -- Get string from command line
tty_dev = arg[2]
DataToUART(msg,tty_dev)   --send string to uart tx