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
}

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

function REQUEST:totalPush()
	local r = skynet.call("db_service", "lua", "getUserBaseData", self.uuid)
	print("REQUEST:totalPush", r)
	if r then
		pinfo.uuid = r.uuid
		pinfo.registerTime = r.registerTime
		pinfo.jingtuGroup = r.jingtuGroup
		pinfo.lotusNum = r.lotusNum
		pinfo.phoneType = r.phoneType
	end
	
	r = skynet.call("db_service", "lua", "getUserUpdateData", self.uuid)
	if r then
		pinfo.signNum = r.signNum
		pinfo.censerNum = r.censerNum
		pinfo.sutraNum = r.sutraNum
		pinfo.signRank = r.signRank
		pinfo.censerRank = r.censerRank
		pinfo.sutraRank = r.sutraRank
		pinfo.totalRank = r.totalRank
		pinfo.incenseLastTime = r.incenseLastTime
	end
	
	r = skynet.call("db_service", "lua", "getUserMonthCollect", self.uuid)
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
	
	return {incenseLastTime=pinfo.incenseLastTime, totalRank=pinfo.totalRank, signNum=pinfo.signNum, signRank=pinfo.signRank,
			censerNum=pinfo.censerNum, censerRank=pinfo.censerRank, sutraNum=pinfo.sutraNum,
			sutraRank=pinfo.sutraRank, jingtuGroup=pinfo.jingtuGroup, lotusNum=pinfo.lotusNum,
			signLine=pinfo.signLine, serverTime=pinfo.ostime, fohaoGroup=pinfo.fohaoGroup}
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
	end
	if "incenseLastTime" == self.type then
		pinfo.incenseLastTime = tonumber(self.data)
	end
	if "songScore" == self.type then
		local s = split(self.data, ":")
		if not pinfo.musicScore[s[1]] then
			return {errCode=1, desc="cant find the song ", s[1]}
		end
		pinfo.musicScore[s[1]] = tonumber(s[2])
		local fh = ""
		for k,v in pairs(pinfo.musicScore) do
			fh = fh .. "k" .. ":" .. v .. ","
		end
		if string.len(fh) > 0 then
			pinfo.fohaoGroup = string.sub(fh, 1, -2)
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
	send_package(packMsg("pushUserData", {type=type, data=data}))
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
