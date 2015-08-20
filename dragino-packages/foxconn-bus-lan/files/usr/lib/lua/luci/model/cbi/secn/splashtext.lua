--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>
Copyright 2010 Manuel Munz <freifunk@somakoma.de>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0
]]--

local fs = require "nixio.fs"

local splashtextfile = "/usr/lib/lua/luci/view/commotion-splash/splashtext.htm"

f = SimpleForm("splashtext", translate("Edit Splash text"),
        translate("You can enter your own text that is displayed to clients here.<br /><br />" ..
	"It is possible to use the following markers:<br />" ..
	"$gatewayname: The value of GatewayName as set in nodogsplash.conf.<br />" ..
	"$authtarget: A URL which encodes a unique token and the URL of the user's original web request.<br />" ..
	"$imagesdir: The directory in nodogsplash's web hierarchy where images to be displayed in the splash page must be located.<br />"))

t = f:field(TextValue, "text")
t.rmempty = true
t.rows = 30
function t.cfgvalue()
        return fs.readfile(splashtextfile) or ""
end

function f.handle(self, state, data)
        if state == FORM_VALID then
                if data.text then
                        fs.writefile(splashtextfile, data.text:gsub("\r\n", "\n"))
                else
                        fs.unlink(splashtextfile)
                end
        end
        return true
end

return f
