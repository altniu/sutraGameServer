local skynet = require "skynet"
require "skynet.manager"
local netpack = require "netpack"
local datacenter = require "datacenter"
--local CMD = setmetatable({}, { __gc = function() netpack.clear(queue) end })
local CMD = {}
local max_people = 3
local players = {}
local rooms = {}

function CMD.playerOnline(agent, fd)
	players[fd] = agent
end
function CMD.playerOffline(agent, fd)
	players[fd] = nil
end




function init()
	datacenter.set("serial_id", "room_id", 1)
end

skynet.start(function()
    print("gameRoot service start")
	skynet.dispatch("lua", function (session, address, cmd, ...)
        print("gameRoot.dispatch.cmd: " .. cmd)
		local f = CMD[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			skynet.ret(skynet.pack(handler.command(cmd, address, ...)))
		end
	end)
  
  init()
  skynet.register("gameRoot")
end)
