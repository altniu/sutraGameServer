local skynet = require "skynet"
--local sprotoloader = require "sprotoloader"



skynet.start(function()
	
	--db service
	local dbserver = skynet.newservice ("db_service")
	
	--login service
	local loginserver = skynet.newservice("logind")

	--game service
	skynet.uniqueservice("protoloader")
	local gameRoot = skynet.newservice("gameRoot")
	
	--rank service
	local rankService = skynet.newservice("rankService")
	
	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		address="47.91.176.170",
		port = 7001,
		maxclient = 64,
		nodelay = true,
		gameRoot = gameRoot,
	})

	--skynet.exit()
end)
