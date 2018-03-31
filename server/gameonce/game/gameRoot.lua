local skynet = require "skynet"
require "skynet.manager"
local netpack = require "skynet.netpack"
local datacenter = require "skynet.datacenter"
local csvParse = require "csvParse"
--local CMD = setmetatable({}, { __gc = function() netpack.clear(queue) end })
local CMD = {}
local max_people = 3
local players = {}
local rooms = {}
local songCsv = {}


function CMD.playerOnline(agent, fd)
	players[fd] = agent
end
function CMD.playerOffline(agent, fd)
	players[fd] = nil
end

function CMD.getJingtuListIdWithSongId(findId)
	local ret = {}
	local jingtu = ""
	
	local id = tostring(findId)
	for k,v in pairs(songCsv) do
		if v.id == id then
			jingtu = v.jingtuId
			break
		end
	end
	
	for k,v in pairs(songCsv) do
		if v.jingtuId == jingtu then
			ret[#ret+1] = v.id
		end
	end
	return ret, jingtu
end

function CMD.getSongList()
	return songCsv
end

function init()
	songCsv = csvParse.LoadMusicRhythm("server/gameonce/game/songData.csv")
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
