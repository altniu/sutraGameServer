local skynet = require "skynet"
--local netpack = require "netpack"
local socket = require "skynet.socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local datacenter = require "skynet.datacenter"
require "functions"
--local sproto_core = require "sproto.core"

local WATCHDOG
local game_root
local host
local packMsg

local CMD = {}
local REQUEST = {}

local STATE = {}
local fd = nil
local agent = nil

local pinfo = {
	uuid = "",
	totalRank = 0,
	registerTime = 0,
	signNum = 0,
	censerNum = 0,
	sutraNum = 0,
	signRank = 0,
	censerRank = 0,
	sutraRank = 0,
	jingtuGroup = "",
	lotusNum = 0,
	fohaoNum = 0,--佛号总数
	fohaoMonthNum = 0,--每月佛号总计
	phoneType = "",
	signLine = 0,
	mouth = 0,
	musicScore = {},
	fohaoGroup = "",
	first = false,
	ostime = 0,
	incenseLastTime = 0,
	sutraLastTime = 0,
}


local function printTable(lua_table, indent)
    if not lua_table then
        return
    end
    indent = indent or 0
    for k, v in pairs(lua_table) do
        if type(k) == "string" then
            k = string.format("%q", k)
        end
        local szSuffix = ""
        if type(v) == "table" then
            szSuffix = "{"
        end
        local szPrefix = string.rep("    ", indent)
        local formatting = szPrefix.."["..k.."]".." = "..szSuffix
        if type(v) == "table" then
            print(formatting)
            printTable(v, indent + 1)
            print(szPrefix.."},")
        else
            local szValue = ""
            if type(v) == "string" then
                szValue = string.format("%q", v)
            else
                szValue = tostring(v)
            end
            print(formatting..szValue..",")
        end
    end
end


local function split(input, delimiter)
    if input == "" then return {} end
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter=='') then return {} end
    local pos,arr = 0, {}
    -- for each divider found
    for st,sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end

local function getDayByTime( t )
	local dates = os.date("*t", t)
	return dates
end



local function updateTotalRank()
	local r = skynet.call("rankService", "lua", "getTotalRank", pinfo.uuid)
	CMD.pushUserData("totalRank", r or 0)
end
local function updateSignRank()
	skynet.call("rankService", "lua", "updateSign", pinfo.uuid, pinfo.signNum)
	local r = skynet.call("rankService", "lua", "getSignRank", pinfo.uuid)
	CMD.pushUserData("signRank", r or 0)
	updateTotalRank()	
end
local function updateCenserRank()
	skynet.call("rankService", "lua", "updateCenser", pinfo.uuid, pinfo.censerNum)
	local r = skynet.call("rankService", "lua", "getCenserRank", pinfo.uuid)
	CMD.pushUserData("censerRank", r or 0)
	updateTotalRank()
end
local function updateSutraRank()
	skynet.call("rankService", "lua", "updateSutra", pinfo.uuid, pinfo.sutraNum)
	local r = skynet.call("rankService", "lua", "getSutraRank", pinfo.uuid)
	CMD.pushUserData("sutraRank", r or 0)
	updateTotalRank()
end
local function updateFohaoRank()
	skynet.call("rankService", "lua", "updateFohao", pinfo.uuid, pinfo.fohaoNum)
	local r = skynet.call("rankService", "lua", "getFohaoRank", pinfo.uuid)
	
	updateTotalRank()
end

function REQUEST:updateUserData()
	print("REQUEST:updateUserData", pinfo.uuid, self.type, self.data)
	
	if self.ostime ~= pinfo.ostime then
		return {errCode=1, desc="err ostime"}
	end
	
	if "signLine" == self.type then
		pinfo.signLine = tonumber(self.data)
		pinfo.signNum = pinfo.signNum + 1
		
		CMD.pushUserData("signNum", pinfo.signNum)
		
		skynet.call("db_service", "lua", "updateMonthCollect", pinfo.uuid, "signLine", pinfo.signLine)
		skynet.call("db_service", "lua", "updateUserUpdate", pinfo.uuid, "signNum", pinfo.signNum)
		updateSignRank()
		
	end
	if "censerNum" == self.type then
		local ser = getDayByTime(pinfo.ostime)
		local last = getDayByTime(pinfo.incenseLastTime)
		if ser.year ~= last.year or ser.month ~= last.month or ser.day ~= last.day then
			pinfo.censerNum = pinfo.censerNum + 1
			pinfo.incenseLastTime = pinfo.ostime
			
			CMD.pushUserData("censerNum", pinfo.censerNum)
			CMD.pushUserData("incenseLastTime", pinfo.incenseLastTime)
			skynet.call("db_service", "lua", "updateUserUpdate", pinfo.uuid, "censerNum", pinfo.censerNum)
			skynet.call("db_service", "lua", "updateUserUpdate", pinfo.uuid, "incenseLastTime", pinfo.incenseLastTime)
			updateCenserRank()
		else
			return {errCode=1, desc="today already senserd"}
		end
	end
	if "songScore" == self.type then
		local s = split(self.data, ":")
		local musicName = s[1]
		local sc = split(s[2], ",")
		local score = tonumber(sc[1]) or 0
		local clickCount = tonumber(sc[2]) or 0
		
		if not pinfo.musicScore[musicName] then
			--return {errCode=1, desc="cant find the song ", musicName}
			pinfo.musicScore[musicName] = 0
		end
		
		--大于100下佛句就算敲成功		
		if clickCount > 99 then
			local ser = getDayByTime(pinfo.ostime)
			local last = getDayByTime(pinfo.sutraLastTime)
		
			if ser.year ~= last.year or ser.month ~= last.month or ser.day ~= last.day then
				pinfo.sutraNum = pinfo.sutraNum + 1
				pinfo.sutraLastTime = pinfo.ostime
				
		
				CMD.pushUserData("sutraNum", pinfo.sutraNum)
				skynet.call("db_service", "lua", "updateUserUpdate", pinfo.uuid, "sutraNum", pinfo.sutraNum)
				
				CMD.pushUserData("sutraLastTime", pinfo.sutraLastTime)
				skynet.call("db_service", "lua", "updateUserUpdate", pinfo.uuid, "sutraLastTime", pinfo.sutraLastTime)
				
				updateSutraRank()
			end
		end
	
		--保存佛句,增加得分
		local addScore = score
		local lastScore = pinfo.musicScore[musicName]
		pinfo.musicScore[musicName] = pinfo.musicScore[musicName] + addScore
		pinfo.fohaoNum = pinfo.fohaoNum + addScore
		pinfo.fohaoMonthNum = pinfo.fohaoMonthNum + addScore
		
		local fh = ""
		for k,v in pairs(pinfo.musicScore) do
			fh = fh .. k .. ":" .. v .. ","
		end
		if string.len(fh) > 0 then
			pinfo.fohaoGroup = string.sub(fh, 1, -2)
		end
		CMD.pushUserData("fohaoGroup", pinfo.fohaoGroup)
		skynet.call("db_service", "lua", "updateMonthCollect", pinfo.uuid, "fohaoGroup", pinfo.fohaoGroup)
		skynet.call("db_service", "lua", "updateUserUpdate", pinfo.uuid, "fohaoNum", pinfo.fohaoNum)
		skynet.call("db_service", "lua", "updateUserUpdate", pinfo.uuid, "fohaoMonthNum", pinfo.fohaoMonthNum)
		CMD.pushUserData("fohaoMonthNum", pinfo.fohaoMonthNum)
		updateFohaoRank()
		
		local totalScore = 0
		local songList, jingtu = skynet.call(game_root, "lua", "getJingtuListIdWithSongId", musicName)
		print("songList, jingtu ", jingtu )
		printTable(songList)
		if songList then
			for k,v in pairs(songList) do
				if pinfo.musicScore[v] then
					totalScore = totalScore + pinfo.musicScore[v]
				end
			end
		end
		
		--一个月内累计敲3万下佛号
		print("totalScore, fohaoMonthNum, addScore", totalScore, pinfo.fohaoMonthNum, addScore)
		if pinfo.fohaoMonthNum > 30000 and pinfo.fohaoMonthNum - addScore < 30000 then
			local s1, s2 = string.find(pinfo.jingtuGroup, jingtu, 1, true)
			s1, s2 = string.find(pinfo.jingtuGroup, ":", s2+1, true)
			local s3 = string.find(pinfo.jingtuGroup, ",", s2+1, true)
			local jtNum = tonumber(string.find(s2+1, s3-1)) + 1
			pinfo.jingtuGroup = string.sub(pinfo.jingtuGroup, 1, s2) .. jtNum .. string.sub(pinfo.jingtuGroup, s2+1, -1)
			CMD.pushUserData("jingtuGroup", pinfo.jingtuGroup)
			
			skynet.call("db_service", "lua", "updateUserBaseData", pinfo.uuid, "jingtuGroup", pinfo.jingtuGroup)
		end
	end
	
	return {errCode = 0, desc = ""}
end

function REQUEST:totalPush()
	pinfo.ostime = os.time()
	print("totalpush pinfo.ostime")
	printTable(os.date("*t", pinfo.ostime))
	local date = getDayByTime(pinfo.ostime )
	
	local r 

	r = skynet.call("db_service", "lua", "getUserBaseData", self.uuid)	
	if r then
		pinfo.uuid = r.uuid
		pinfo.registerTime = r.registerTime
		pinfo.jingtuGroup = r.jingtuGroup
		pinfo.lotusNum = r.lotusNum
		pinfo.phoneType = r.phoneType
	end
	
	r = skynet.call("db_service", "lua", "getUserMonthCollect", self.uuid, date.month+1)
	print("getUserMonthCollect data info")
	printTable(r)
	
	
	if r then
		--signLine, mouth, fohaoGroup
		pinfo.signLine = r.signLine
		pinfo.mouth = r.month
		pinfo.fohaoGroup = r.fohaoGroup
		local scores = split(r.fohaoGroup, ",")
		for k,v in pairs(scores) do
			local s = split(v, ":")
			if #s == 2 then
				pinfo.musicScore[s[1]] = tonumber(s[2])
			end
		end
	end
	
	r = skynet.call("db_service", "lua", "getUserUpdateData", self.uuid)
	if r then
		pinfo.signNum = r.signNum
		pinfo.censerNum = r.censerNum
		pinfo.sutraNum = r.sutraNum
		pinfo.fohaoMonthNum = r.fohaoMonthNum
		pinfo.signRank = r.signRank
		pinfo.censerRank = r.censerRank
		pinfo.sutraRank = r.sutraRank
		pinfo.totalRank = r.totalRank
		pinfo.incenseLastTime = r.incenseLastTime
		pinfo.sutraLastTime = r.sutraLastTime
		pinfo.fohaoNum = r.fohaoNum
		
		print("os.date, r.sutraLastTime")
		printTable(os.date("*t", r.sutraLastTime))
	end
	
	
	
	
	
	local ret = {incenseLastTime=pinfo.incenseLastTime, sutraLastTime=pinfo.sutraLastTime, 
			totalRank=skynet.call("rankService", "lua", "getTotalRank", self.uuid), 
			signNum=pinfo.signNum, 
			signRank=skynet.call("rankService", "lua", "getSignRank", self.uuid), 
			censerNum=pinfo.censerNum, 
			censerRank=skynet.call("rankService", "lua", "getCenserRank", self.uuid), 
			sutraNum=pinfo.sutraNum,
			sutraRank=skynet.call("rankService", "lua", "getSutraRank", self.uuid), 
			jingtuGroup=pinfo.jingtuGroup, lotusNum=pinfo.lotusNum,fohaoMonthNum=pinfo.fohaoMonthNum,
			signLine=pinfo.signLine, serverTime=pinfo.ostime, fohaoGroup=pinfo.fohaoGroup}
	
	printTable(ret)
	
	return ret
end

function REQUEST:quit()
	skynet.call(WATCHDOG, "lua", "close", fd)
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
	socket.write(fd, package)
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
	print("pushUserData", type, data)
	send_package(packMsg("pushUserData", {type=type, data=tostring(data)}))
end

function CMD.sendNoteInfo(noteStr)
	send_package(packMsg("sendNote", {note=noteStr}))
end



function CMD.start(conf)
	fd = conf.client
	local gate = conf.gate
	game_root = conf.gameRoot
	WATCHDOG = conf.watchdog
	agent = skynet.self()
	
	-- slot 1,2 set at main.lua
	host = sprotoloader.load(1):host "package"
	packMsg = host:attach(sprotoloader.load(2))
  
  
	skynet.fork(function()
		while true do
			send_package(packMsg "heartbeat")
			skynet.sleep(1500)
		end
	end)
  
	skynet.call(gate, "lua", "forward", fd)
	
	CMD.sendNoteInfo("欢迎进入彩绘净土世界，请签到后上香，选取经文后开始，敲击木鱼完成功课。")
end

function CMD.disconnect()
	-- todo: do something before exit
	if pinfo.uuid ~= "" then
		local r = skynet.call("loginserver", "lua", "logOut", pinfo.uuid)
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
