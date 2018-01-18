local skynet = require "skynet"


skynet.start(function()
	print("main_db server start ")

	local s = skynet.newservice ("db_service")
	
	--skynet.call(s, "lua", "start", uid, id, secret)
	skynet.exit()
end)
