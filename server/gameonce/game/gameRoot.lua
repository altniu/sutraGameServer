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

function CMD.playerEnterRoom(level, player)
	if not players[player.fd] then
		skynet.error(" gameRoot : enterRoom, player is not online, uid="..player.uid)
		return 0
	end
	if not rooms[level] then rooms[level] = {} end
	local roomlist = rooms[level]
	
	
	local roomAgent = nil
	local roomID = 0
	local site = 0
	local otherPlayers = {}
	for k,v in pairs(roomlist) do
		if v.num > 0 then
			roomID, site, otherPlayers = skynet.call(v.room, "lua", "playerEnter", player)
			roomAgent = v.room
			v.num = math.max(v.num - 1, 0)
			break
		end
	end
	if roomID == 0 then
		local room = skynet.newservice ("roomAgent")
		roomID = skynet.call(room, "lua", "init", level, skynet.self())

		roomID, site, otherPlayers = skynet.call(room, "lua", "playerEnter", player)
		roomAgent = room
		roomlist[roomID] = {room = room, num = max_people-1}
	end

	return roomAgent, roomID, site, otherPlayers
end

function CMD.playerExitRoom(site, level, roomID, isPlaying)
	local roomLevel = rooms[level]
	if roomLevel[roomID] then
		local roomInfo = roomLevel[roomID]
		skynet.call( roomInfo.room, "lua", "playerExitRoom", site)
		roomInfo.num = roomInfo.num + 1
		if roomInfo.num == max_people then
			skynet.send(roomInfo.room, "lua", "exit")
			roomLevel[roomID] = nil
		end
	end	
end


function init()
	datacenter.set("serial_pid", "pid", 10001)
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
