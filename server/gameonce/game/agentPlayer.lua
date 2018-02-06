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



function REQUEST:totalPush()
	local r = skynet.call("db_service", "lua", "getUserBaseData", self.uuid)
	print("REQUEST:totalPush.getUserBaseData")
	printTable(r)
	
	if r then
		pinfo.uuid = r.uuid
		pinfo.registerTime = r.registerTime
		pinfo.jingtuGroup = r.jingtuGroup
		pinfo.lotusNum = r.lotusNum
		pinfo.phoneType = r.phoneType
	end
	
	r = skynet.call("db_service", "lua", "getUserUpdateData", self.uuid)
	print("REQUEST:totalPush.getUserUpdateData")
	printTable(r)
	if r then
		pinfo.signNum = r.signNum
		pinfo.censerNum = r.censerNum
		pinfo.sutraNum = r.sutraNum
		pinfo.signRank = r.signRank
		pinfo.censerRank = r.censerRank
		pinfo.sutraRank = r.sutraRank
		pinfo.totalRank = r.totalRank
		pinfo.incenseLastTime = r.incenseLastTime
		pinfo.sutraLastTime = r.sutraLastTime
	end
	
	r = skynet.call("db_service", "lua", "getUserMonthCollect", self.uuid)
	print("REQUEST:totalPush.getUserMonthCollect")
	printTable(r)
	if r then
		--signLine, mouth, fohaoGroup
		pinfo.signLine = r.signLine
		pinfo.mouth = r.mouth
		pinfo.fohaoGroup = r.fohaoGroup
		local scores = split(r.fohaoGroup, ",")
		for k,v in pairs(scores) do
			local s = split(v, ":")
			pinfo.musicScore[s[1]] = tonumber(s[2])
		end
	end
	
	pinfo.ostime = os.time()
	
	local ret = {incenseLastTime=pinfo.incenseLastTime, sutraLastTime=pinfo.sutraLastTime, totalRank=pinfo.totalRank, 
			signNum=pinfo.signNum, signRank=pinfo.signRank,
			censerNum=pinfo.censerNum, censerRank=pinfo.censerRank, sutraNum=pinfo.sutraNum,
			sutraRank=pinfo.sutraRank, jingtuGroup=pinfo.jingtuGroup, lotusNum=pinfo.lotusNum,
			signLine=pinfo.signLine, serverTime=pinfo.ostime, fohaoGroup=pinfo.fohaoGroup}
			
	printTable(ret)
	
	return ret
end

function REQUEST:updateUserData()
	if not pinfo[self.type] then
		return {errCode = 1, desc = "cant find this type : " .. self.type}
	end

	if self.ostime ~= pinfo.ostime then
		return {errCode=1, desc="err ostime"}
	end
	
	if "signLine" == self.type then
		pinfo.signLine = tonumber(self.data)
		skynet.call("db_service", "lua", "updateMonthCollect", pinfo.uuid, "signLine", pinfo.signLine)
	end
	if "censerNum" == self.type then
		local ser = getDayByTime(pinfo.ostime)
		local last = getDayByTime(pinfo.incenseLastTime)
		if ser.year ~= last.year or ser.month ~= last.month or ser.day ~= last.day then
			pinfo.censerNum = pinfo.censerNum + 1
			pinfo.incenseLastTime = pinfo.ostime
			
			CMD.pushUserData("censerNum", pinfo.censerNum)
			skynet.call("db_service", "lua", "updateUserUpdate", pinfo.uuid, "censerNum", pinfo.censerNum)
			skynet.call("db_service", "lua", "updateUserUpdate", pinfo.uuid, "incenseLastTime", pinfo.incenseLastTime)
		else
			return {errCode=1, desc="today already senserd"}
		end
	end
	if "songScore" == self.type then
		local s = split(self.data, ":")
		if not pinfo.musicScore[s[1]] then
			return {errCode=1, desc="cant find the song ", s[1]}
		end
		
		local addScore = tonumber(s[2])
		local lastScore = pinfo.musicScore[s[1]]
		pinfo.musicScore[s[1]] = pinfo.musicScore[s[1]] + addScore
		local fh = ""
		for k,v in pairs(pinfo.musicScore) do
			fh = fh .. "k" .. ":" .. v .. ","
		end
		if string.len(fh) > 0 then
			pinfo.fohaoGroup = string.sub(fh, 1, -2)
		end
		CMD.pushUserData("fohaoGroup", pinfo.fohaoGroup)
		skynet.call("db_service", "lua", "updateMonthCollect", pinfo.uuid, "fohaoGroup", pinfo.fohaoGroup)
		
		local totalScore = 0
		local songList, jingtu = skynet.call(game_root, "lua", "getJingtuListIdWithSongId", tonumber(s[1]))
		if songList then
			for k,v in pairs(songList) do
				if pinfo.musicScore[v] then
					totalScore = totalScore + pinfo.musicScore[v]
				end
			end
		end
		--敲击了3W下
		if totalScore - addScore < 30000 then
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
