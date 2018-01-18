local skynet = require "skynet"
require "skynet.manager"
local netpack = require "netpack"
package.path = "./server/game/?.lua;" .. package.path
require "functions"
local datacenter = require "datacenter"

local CMD = setmetatable({}, { __gc = function() netpack.clear(queue) end })

ROOM_STATUS = {ready=1, playing=2, gameover=3}
ROOM_MAX_PLAYER = 3

local m_roomMgr
local m_roomLevel = 0
local m_gameRoot = nil
local m_allocPoke_time = 100*5

local m_jiaodizhu_time = 100*15
local m_jiaodizhuCount = 0
local m_jiaodizhuIndex = 0

local m_qiangdizhu_time = 100*15
local m_qiangdizhuCount = 0
local m_qiangdizhuIndex = 0
local m_chupai_time = 100*30
local m_chupai_site = 0
local m_chupai_roundWinSite = 0

local m_playerExit_site = 0

local m_roomList = {lack={}, full={}}--分为人满的和人不够的




local function newRoomID()
	local serialid = datacenter.get("serial_id", "room_id")
	serialid = serialid + 1
	datacenter.set("serial_id", "room_id", serialid)
  
	return serialid
end

local function makeRoom()
	local room = require("DDZGame")
	room:init(newRoomID(), skynet:self())
	return room
end


local function gameOverHandle()
	local sleepTime = 0
	local function handleFunc()
		skynet.sleep(100)
		for k,v in pairs(m_roomMgr.playerList) do
			skynet.call(v.player.agent, "lua", "gameOverNotify", m_roomMgr:getCurrentPaySite(), "0")
		end
	end
	skynet.fork(handleFunc)
end

local function pokesLoop()
	local sleepTime = 0
	local function pokes()
		skynet.sleep(100)
		--广播
		local dizhuSite = m_roomMgr:getDizhuBySite()
		for k,v in pairs(m_roomMgr.playerList) do
			skynet.call(v.player.agent, "lua", "startPayPokeNotify", dizhuSite)
		end

		while(true)
		do
			skynet.sleep(100)
			sleepTime = sleepTime + 100

			if sleepTime >= m_chupai_time then
				local paysite = m_roomMgr:getCurrentPaySite()
				local code, roundWinSite, isWin = m_roomMgr:payPoke(paysite, {})
				m_chupai_site = paysite
				m_chupai_roundWinSite = roundWinSite
			end

			if m_chupai_site ~= 0 then
				sleepTime = 0

				--广播
				local lastPokes = m_roomMgr:getLastPokes()
				local pokes = ""
				for ck,cv in pairs(lastPokes) do
					pokes = pokes..tostring(cv.value).."_"..tostring(cv.color)..","
				end
				pokes = string.sub(pokes, 1, -2)
				for k,v in pairs(m_roomMgr.playerList) do
					skynet.call(v.player.agent, "lua", "payPokeNotify", m_chupai_site, pokes, m_chupai_roundWinSite)
				end
				m_chupai_site = 0
				m_chupai_roundWinSite = 0

				--game over广播
				if m_roomMgr:isGameOver() then
					gameOverHandle()
					break
				end
			end

			if m_playerExit_site ~= 0 then
				--广播
				for k,v in pairs(m_roomMgr.playerList) do
					if v.player then
						--local iswin = m_roomMgr:playerIsWinWithSite(v.player.site)
						--skynet.call(v.player.agent, "lua", "playerExitRoomNotify", m_playerExit_site)
						--skynet.call(v.player.agent, "lua", "gameOverNotify", 1, iswin, "")
					end
				end
				m_playerExit_site = 0
				break
			end
		end
	end
	skynet.fork(pokes)
end

local function qiangdizhuLoop()
	local sleepTime = 0
	local function qiangdizhu()
		while(true)
		do
			skynet.sleep(100)
			sleepTime = sleepTime + 100

			if sleepTime >= m_qiangdizhu_time then
				m_qiangdizhuIndex = -1
			end

			if m_qiangdizhuIndex ~= 0 then
				sleepTime = 0
				m_qiangdizhuCount = m_qiangdizhuCount + 1
				
				m_roomMgr:qiangdizhuFunc(m_qiangdizhuIndex > 0)

				--广播
				for k,v in pairs(m_roomMgr.playerList) do
					skynet.call(v.player.agent, "lua", "qiangdizhuNotify", m_roomMgr:getQiangDizhuSite(), m_qiangdizhuIndex > 0)
				end
				m_qiangdizhuIndex = 0
			end

			if m_qiangdizhuCount == DDZ_Define.play_MaxCount then--进入game
				pokesLoop()
				break
			end
		end
	end
	skynet.fork(qiangdizhu)
end

local function jiaodizhuLoop()
	local sleepTime = 0
	local function jiaodizhu()
		while(true)
		do
			skynet.sleep(100)
			sleepTime = sleepTime + 100

			if sleepTime >= m_jiaodizhu_time then
				m_jiaodizhuIndex = -1
			end
			
			if m_jiaodizhuIndex ~= 0 then
				sleepTime = 0
				m_jiaodizhuCount = m_jiaodizhuCount + 1
				m_roomMgr:jiaodizhuFunc(m_jiaodizhuIndex > 0)

				--广播 叫地主
				for k,v in pairs(m_roomMgr.playerList) do
					if v.player then 
						skynet.call(v.player.agent, "lua", "jiaodizhuNotify", m_roomMgr:getJiaoDizhuSite(), m_jiaodizhuIndex > 0)
					end
				end
				m_jiaodizhuIndex = 0
			end

			if m_jiaodizhuCount == DDZ_Define.play_MaxCount then--进入抢地主
				qiangdizhuLoop()
				break
			end
		end
	end
	skynet.fork(jiaodizhu)
end

local function startGame()
	local function startPoke()
		m_jiaodizhuCount = 0
		m_jiaodizhuIndex = 0
		m_qiangdizhuCount = 0
		m_qiangdizhuIndex = 0
		m_chupai_site = 0
		m_playerExit_site = 0

		skynet.sleep(50)

		m_roomMgr:startGame()
		for k,v in pairs(m_roomMgr.playerList) do
			local pokes = ""
			for kv,vv in pairs(v.pokes) do
				for ck,cv in pairs(vv) do
					pokes = pokes..tostring(cv.value).."_"..tostring(cv.color)..","
				end
			end
			pokes =string.sub(pokes, 1, -2)

			local secretPokes = ""
			local roomSecretPoke = m_roomMgr:getSecretPoke()
			for ck,cv in pairs(roomSecretPoke) do
				secretPokes = secretPokes..tostring(cv.value).."_"..tostring(cv.color)..","
			end
			secretPokes =string.sub(secretPokes, 1, -2)
			skynet.call(v.player.agent, "lua", "startGameNotify", pokes, secretPokes, m_roomMgr:getJiaoDizhuSite())
		end

		skynet.sleep(m_allocPoke_time)--发牌等待
		jiaodizhuLoop()
	end
	skynet.fork(startPoke)
end


function CMD.playerEnter(playerTmp)
	local player = {}
	for k,v in pairs(playerTmp)do player[k] = v end

	if m_roomMgr.playerCount >= DDZ_Define.play_MaxCount then
		skynet.error("roomAgent : people is full")
		return 0
	end
	local playerUID = player.uid
	player = m_roomMgr:addPlayer(player)
	local players = {}
	for k, v in pairs(m_roomMgr.playerList) do
		if v.player then
			local pInfo = {}
			pInfo.name = v.player.name
			pInfo.gold = v.player.gold
			pInfo.icon = v.player.icon
			pInfo.state = v.player.state
			pInfo.site = v.player.site
			pInfo.uid = v.player.uid
			table.insert(players, pInfo)

			if v.player.uid ~= playerUID then
				skynet.call(v.player.agent, "lua", "playerEnterRoomNotify", player)
			end
		end
	end
	
	return m_roomMgr.id, player.site, players
end


function CMD.playerReady(roomID, uid, isReady)
	if m_roomMgr.id == roomID then
		m_roomMgr:playerReady(uid, isReady)
		for k,v in pairs(m_roomMgr.playerList) do
			if v.player and v.player.uid ~= uid then
				skynet.call(v.player.agent, "lua", "readyNotify", uid, isReady)
			end
		end

		if m_roomMgr:canStartGame() then
			startGame()
		end
	end
end

function CMD.playerPayPoke(site, pokes)
	local pokesValue = {}
	local pokeList = string.split(pokes, ",")
	for i=1, #pokeList do
		local data = string.split(pokeList[i], "_")
		local p = {value=tonumber(data[1]), color=tonumber(data[2])}
                table.insert(pokesValue, p)
	end
	table.sort(pokesValue, function(a,b) return a.value < b.value end)

	local isvalid = m_roomMgr:checkPayPoke(site, pokesValue)
	if not isvalid then
		return 1
	end

	local code, roundWinSite, isWin, pokeType = m_roomMgr:payPoke(site, pokesValue)
	m_chupai_site = site
	m_chupai_roundWinSite = roundWinSite
	return code, pokeType
end

function CMD.playerExitRoom(site)
	m_playerExit_site = site
	local isPlaying = m_roomMgr:isPlaying()
	m_roomMgr:playerExit(site)

	for k,v in pairs(m_roomMgr.playerList) do
		if v.player then
			skynet.call(v.player.agent, "lua", "playerExitRoomNotify", site)
		end
	end
end

function CMD.playerJiaodizhu(site, isJiaodizhu)
	m_jiaodizhuIndex = isJiaodizhu and 1 or -1
end

function CMD.playerQiangdizhu(site, isQiangdizhu)
	m_qiangdizhuIndex = isQiangdizhu and 1 or -1
end

function CMD.init(level, gameRoot)
	m_roomLevel = level or 0
	m_gameRoot = gameRoot
	m_roomMgr = makeRoom()
	return m_roomMgr.id
end

function CMD.exit()
	skynet.exit()
end

skynet.start(function()
             print("roomAgent service start")
	skynet.dispatch("lua", function (session, address, cmd, ...)
                            print("roomAgent.dispatch.cmd: " .. cmd)
		local f = CMD[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			skynet.ret(skynet.pack(handler.command(cmd, address, ...)))
		end
	end)

    	--skynet.register("roomAgent")
end)
