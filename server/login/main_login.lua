local skynet = require "skynet"
--require("functions")
skynet.start(function()
	skynet.error("login server start")
	local loginserver = skynet.newservice("logind")
	

	--[[
	local gate = skynet.newservice("gated", loginserver)
	skynet.call(gate, "lua", "open" , {
		port = 8888,
		maxclient = 256,
		servername = "s1",
	})
	--]]
end)
