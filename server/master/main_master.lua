local skynet = require "skynet"

skynet.start(function()
	skynet.error("master server start")

	--local console = skynet.newservice("console")
	--skynet.newservice("debug_console",8000)
	

	skynet.exit()
end)
