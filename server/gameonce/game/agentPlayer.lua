local skynet = require "skynet"
--local netpack = require "netpack"
local socket = require "socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local datacenter = require "datacenter"
require "functions"
--local sproto_core = require "sproto.core"

local WATCHDOG
local game_root
local host
local packMsg

local CMD = {}
local REQUEST = {}



local STATE = {}
--uuid, registerTime, signNum, censerNum, sutraNum, jingtuNum, lotusNum, phoneType, userData
local playerInfo = {
	uuid = "",
	totalRank = 0,
	registerTime = 0,
	signNum = 0,
	censerNum = 0,
	sutraNum = 0,
	jingtuGroup = "",
	lotusNum = 0,
	phoneType = "",
	signLine = 0,
	mouth = 0,
	fohaoGroup = "",
	first = false,
}


function REQUEST:totalPush()
	local r = skynet.call("db_service", "lua", "getUserBaseData", self.uuid)
	if r then
		--uuid, registerTime, signNum, censerNum, sutraNum, jingtuGroup, lotusNum, phoneType, userData
		playerInfo.uuid = r.uuid
		playerInfo.registerTime = r.registerTime
		playerInfo.signNum = r.signNum
		playerInfo.censerNum = r.censerNum
		playerInfo.sutraNum = r.sutraNum
		playerInfo.jingtuGroup = r.jingtuGroup
		playerInfo.lotusNum = r.lotusNum
		playerInfo.phoneType = r.phoneType
	end
	
	r = skynet.call("db_service", "lua", "getUserMonthCollect", self.uuid)
	if r then
		--signLine, mouth, fohaoGroup
		playerInfo.signLine = r.signLine
		playerInfo.mouth = r.mouth
		playerInfo.fohaoGroup = r.fohaoGroup
	end
	
	return res
end

function REQUEST:updateUserData()
	if not playerInfo[self.type] then
		return {errCode = 1, desc = "cant find this type : " .. self.type}
	end
	
	playerInfo[self.type] = self.data
	return {errCode = 0, desc = ""}
end




function REQUEST:quit()
	skynet.call(WATCHDOG, "lua", "close", m_player_info.fd)
end

local function request(name, args, response)
	print("agent.request.name", name)
	local f = assert(REQUEST[name])
	local r = f(args)

	if response then
		return response(r)
	end
end

local function send_package(pack)
	local package = string.pack(">s2", pack)
	socket.write(m_player_info.fd, package)
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		--local bin = sproto_core.unpack(msg, sz)
		print("agent.unpack.msg",msg,sz)
		return host:dispatch(msg, sz)
	end,
	dispatch = function (_, _, type, ...)
		if type == "REQUEST" then
			local ok, result  = pcall(request, ...)
			if ok then
				if result then
					send_package(result)
				end
			else
				skynet.error(result)
			end
		else
			assert(type == "RESPONSE")
			error "This example doesn't support request client"
		end
	end
}

function CMD.pushUserData(type, data)
	send_package(packMsg("pushUserData", {type=type, data=data}))
end





function CMD.start(conf)
	local fd = conf.client
	local gate = conf.gate
	game_root = conf.gameRoot
	WATCHDOG = conf.watchdog
	m_player_info.fd = fd
	m_player_info.agent = skynet.self()
	
	-- slot 1,2 set at main.lua
	host = sprotoloader.load(1):host "package"
	packMsg = host:attach(sprotoloader.load(2))
  
  
	skynet.fork(function()
		while true do
			send_package(packMsg "heartbeat")
			skynet.sleep(500)
		end
	end)
  
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.disconnect()
	-- todo: do something before exit
	if m_player_info.state ~= 0 and m_roomAgent then
		skynet.call(game_root, "lua", "playerExitRoom", m_player_info.site, m_roomLevel, m_roomID, m_player_info.state == STATE.playing)
	end

	if m_player_info.uid > 0 then
		local r = skynet.call("loginserver", "lua", "logOut", m_player_info.uid)
	end
	skynet.exit()
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		print("agent dispatch lua:", command)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
