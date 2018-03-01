local skynet = require "skynet"
--local sprotoloader = require "sprotoloader"



skynet.start(function()
	print("game server start")

	skynet.uniqueservice("protoloader")
	--local console = skynet.newservice("console")
	--skynet.newservice("debug_console",8000)
	--skynet.newservice("simpledb")

	local gameRoot = skynet.newservice("gameRoot")

	skynet.newservice("debug_console",8000)
	
	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		address="192.168.220.128",
		port = 7001,
		maxclient = 64,
		nodelay = true,
		gameRoot = gameRoot,
	})

	skynet.exit()
end)
