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
local send_request

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
local m_roomLevel = 0

function REQUEST:totalPush()
	local isonline = datacenter.get("user_online", self.uid)
	if not isonline then
		skynet.call(WATCHDOG, "lua", "close", m_player_info.fd)
		return { code=1, coin=0, level  = 0, score = 0, gold = 0, name = "" }
	end

	local r = skynet.call("db_service", "lua", "getPlayerData", self.uid)
	local res = { code=0, coin=r.coin, level  = r.level, score = r.score, gold = r.gold, name = r.name }
	m_player_info.uid = self.uid
	m_player_info.name = res.name
	m_player_info.gold = res.gold
	return res
end

function REQUEST:enterRoom()
	local roomAgent, roomID, site, otherPlayers = skynet.call(game_root, "lua", "playerEnterRoom", self.level, m_player_info)
	m_roomID = roomID
	m_roomAgent  = roomAgent
	m_roomLevel = self.level
	
  m_player_info.site = site
  m_player_info.state = STATE.unready
  
	print("player enter room, roomid="..roomID..",site="..site..",playerCount="..#otherPlayers)

	local res = {}
	res.roomID = roomID
	
  for i=1,3 do
		res["p_gold_"..i] = 0
		res["p_icon_"..i] = 0
		res["p_name_"..i] = 0
		res["p_site_"..i] = 0
		res["p_state_"..i] = 0
		res["p_uid_"..i] = 0
	end
  
  local index = 1
	for k,v in pairs(otherPlayers) do
		res["p_gold_"..index] = v.gold
		res["p_icon_"..index] = v.icon
		res["p_name_"..index] = v.name
		res["p_site_"..index] = v.site
		res["p_state_"..index] = v.state
		res["p_uid_"..index] = v.uid
		index=index+1
	end
	return res
end

function REQUEST:ready()
  if self.uid ~= m_player_info.uid then
    return {code=100}
  end
  
  skynet.call(m_roomAgent, "lua", "playerReady", m_roomID, m_player_info.uid, self.ready)
  m_player_info.state = self.ready and STATE.ready or STATE.unready
  
  return {code=0}
end

function REQUEST:selfPayPoke()
	print("agent player pay pokes:", self.pokes)
	local code, pokeType = skynet.call(m_roomAgent, "lua", "playerPayPoke", m_player_info.site, self.pokes)
	return {code = code or 2}
end

function REQUEST:exitRoom()
	local code = skynet.call(game_root, "lua", "playerExitRoom", m_player_info.site, m_roomLevel, m_roomID, m_player_info.state == STATE.playing)
	m_player_info.site = 0
	m_player_info.state = STATE.unready
	m_roomAgent = nil
end

function REQUEST:selfJiaodizhut()
	print("agent.selfJiaodizhu.value", self.value)
	skynet.call(m_roomAgent, "lua", "playerJiaodizhu", m_player_info.site, self.value == 0)
end

function REQUEST:selfQiangdizhu()
	print("agent.selfQiangdizhu.value", self.value)
	skynet.call(m_roomAgent, "lua", "playerQiangdizhu", m_player_info.site, self.value == 0)
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

function CMD.readyNotify(uid, isready)
	send_package(send_request("playerReady", {uid=uid, isready=isready}))
end

function CMD.startGameNotify(pokes, secretPokes, jiaodizhuSite)
	m_player_info.state = STATE.playing
	print("m_player_info.state", m_player_info.state)
	send_package(send_request("startGame", {pokes=pokes, secretpokes=secretPokes, jiaodizhuSite=jiaodizhuSite}))
end

function CMD.jiaodizhuNotify(site, isjiaodizhu)
	print("agent.jiaodizhuNotify.site.isjaodizhu", site, isjiaodizhu)
	send_package(send_request("jiaodizhu", {site=site, isjiaodizhu=isjiaodizhu and "0" or "1"}))
end

function CMD.qiangdizhuNotify(site, isqiangdizhu)
	send_package(send_request("qiangdizhu", {site=site, isqiangdizhu=isqiangdizhu and "0" or "1"}))
end

function CMD.payPokeNotify(site, pokes, roundWinSite)
	send_package(send_request("payPoke", {site=site, pokes=pokes, roundWinSite=roundWinSite}))
end


function CMD.playerEnterRoomNotify(playerInfo)
	send_package(send_request("playerEnterRoom", {p_name=playerInfo.name, p_gold=playerInfo.gold, p_icon=playerInfo.icon, p_site=playerInfo.site, p_uid=playerInfo.site, p_uid=playerInfo.uid} ) )
end
function CMD.playerExitRoomNotify(site)
	m_player_info.state = STATE.unready--游戏期间有玩家退出即宣告gameover
	send_package(send_request("playerExitRoom", {site=site}))
end
function CMD.gameOverNotify(winSite, score)
	m_player_info.state = TATE.unready
	send_package(send_request("gameOver", {winSite=winSite, score=score}))
end
function CMD.startPayPokeNotify(dizhuSite)
	send_package(send_request("startPayPoke", {dizhuSite=dizhuSite}))
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
	send_request = host:attach(sprotoloader.load(2))
  
  --[[
	skynet.fork(function()
		while true do
			--send_package(send_request "heartbeat")
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
		print("agent dispatch lua:", command)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
