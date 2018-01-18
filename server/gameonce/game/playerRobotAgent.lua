local skynet = require "skynet"
local netpack = require "netpack"
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
local m_inRoom = false

local STATE = {unready=1, ready=2, playing=3}
local m_player_info = {
	name = "",
	gold = 0,
	level = 0,
	icon = 0,
	state = STATE.unready,
	site = 0,
	agent = nil,
	fd = 0,
	uid = 0
}
local m_roomID = nil
local m_roomAgent = nil
local m_roomLevel = 1

local handCards={}
local dizhuSite = 0

local function send_package(pack)
	local package = string.pack(">s2", pack)
	socket.write(m_player_info.fd, package)
end

function REQUEST:totalPush()
	local r = skynet.call("db_service", "lua", "getPlayerData", self.uid)
	local id = datacenter.get("serial_pid", "pid") + 1
	datacenter.set("serial_pid", "pid", id)
	m_player_info.uid = id
	m_player_info.name = "id:" .. id
	m_player_info.gold = 10000

	REQUEST:enterRoom()
	REQUEST:ready()
end

function REQUEST:enterRoom()
	local roomAgent, roomID, site, otherPlayers = skynet.call(game_root, "lua", "playerEnterRoom", m_roomLevel, m_player_info)
	m_roomID = roomID
	m_roomAgent  = roomAgent
	
  	m_player_info.site = site
  	m_player_info.state = STATE.unready
  
	print("robotPlayer enter room, roomid="..roomID..",site="..site..",playerCount="..#otherPlayers)

end

function REQUEST:ready()
  
  skynet.call(m_roomAgent, "lua", "playerReady", m_roomID, m_player_info.uid, true)
  m_player_info.state = true
end

function REQUEST:selfPayPoke(pokes)
	local code, pokeType = skynet.call(m_roomAgent, "lua", "playerPayPoke", m_player_info.site, pokes)
end

function REQUEST:exitRoom()
	local code = skynet.call(game_root, "lua", "playerExitRoom", m_player_info.site, m_roomLevel, m_roomID, m_player_info.state == STATE.playing)
	m_player_info.site = 0
	m_player_info.state = STATE.unready
	m_roomAgent = nil
end

function REQUEST:selfJiaodizhu()
	skynet.call(m_roomAgent, "lua", "playerJiaodizhu", m_player_info.site, true)
end

function REQUEST:selfQiangdizhu()
	skynet.call(m_roomAgent, "lua", "playerQiangdizhu", m_player_info.site, true)
end

function REQUEST:quit()
	skynet.call(WATCHDOG, "lua", "close", m_player_info.fd)
end

function REQUEST:notice()
	for k,v in pairs(self.phone) do
		print(v.number .. "," .. v.type)
	end
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

function CMD.readyNotify(uid, isready)

end

function CMD.startGameNotify(pokes, secretPokes, jiaodizhuSite)
	m_player_info.state = STATE.playing

	local pokesdatas = string.split(pokes, ",")
	for k,v in pairs(pokesdatas) do
		local str = string.split(v, "_")
		local data = { cardtype = 1, value = tonumber(str[1]), color = tonumber(str[2]) }
		handCards[#handCards+1] = data
		table.sort(handCards, function(a,b) return a.value<b.value end)
	end

	--send_package(packMsg("startGame", {pokes=pokes, secretpokes=secretPokes, jiaodizhuSite=jiaodizhuSite}))
end

function CMD.jiaodizhuNotify(site, isjiaodizhu)
	skynet.fork(function()
		skynet.sleep(math.random(1,3)*100)
		REQUEST:selfJiaodizhu()
	end)

end

function CMD.qiangdizhuNotify(site, isqiangdizhu)
	skynet.fork(function()
		skynet.sleep(math.random(1,3)*100)
		REQUEST:selfQiangdizhu()
	end)
end

function CMD.payPokeNotify(site, pokes, roundWinSite)
	--send_package(packMsg("payPoke", {site=site, pokes=pokes, roundWinSite=roundWinSite}))
end


function CMD.playerEnterRoomNotify(playerInfo)
	
end
function CMD.playerExitRoomNotify(site)
	print("robotPlayer playerExitRoomNotify")
	m_player_info.state = STATE.unready--游戏期间有玩家退出即宣告gameover
end
function CMD.gameOverNotify(winSite, score)
		print("robotPlayer gameOverNotify")
	m_player_info.state = TATE.unready
end
function CMD.startPayPokeNotify(dzSite)
	dizhuSite = dzSite
	if m_player_info.site == dizhuSite then
		skynet.fork(function()
			skynet.sleep(math.random(1,3)*100)
			local paypokesDesc = ""
			if #handCards > 1 then
				paypokesDesc = handCards[#handCards].value .. "_" .. handCards[#handCards].color
			end
			REQUEST:selfPayPoke(paypokesDesc)
		end)
	end
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
  
  --[[
	skynet.fork(function()
		while true do
			--send_package(packMsg "heartbeat")
			skynet.sleep(500)
		end
	end)
  --]]
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
		print("playerRobotAgent dispatch lua:", command)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
