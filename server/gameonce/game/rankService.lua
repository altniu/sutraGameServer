local skynet = require "skynet"
require "skynet.manager"
--local netpack = require "netpack"
--local sproto_core = require "sproto.core"

local CMD = {}
local m_sutraRank = {}
local m_sutraMap = {}
local m_fohaoRank = {}
local m_fohaoMap = {}
local m_signRank = {}
local m_signMap = {}
local m_censerRank = {}
local m_censerMap = {}
local m_totalRank = {}
local m_totalMap = {}

local rankCount = 4


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


local function init()
	r = skynet.call("db_service", "lua", "getUserUpdateData")
	for k,v in pairs(r) do
		m_sutraRank[#m_sutraRank+1] = {v.uuid, v.sutraNum}
		m_fohaoRank[#m_fohaoRank+1] = {v.uuid, v.fohaoNum}
		m_signRank[#m_signRank+1] = {v.uuid, v.signNum}
		m_censerRank[#m_censerRank+1] = {v.uuid, v.censerNum}
		m_totalRank[#m_totalRank+1] = {v.uuid, v.sutraNum, v.fohaoNum, v.signNum, v.censerNum}
	end
	
	table.sort(m_sutraRank, function (a, b) return a[2] > b[2] end)
	table.sort(m_fohaoRank, function (a, b) return a[2] > b[2] end)
	table.sort(m_signRank, function (a, b) return a[2] > b[2] end)
	table.sort(m_censerRank, function (a, b) return a[2] > b[2] end)
	table.sort(m_totalRank, function (a, b)
		if a[2] > b[2] then
			return true
		elseif a[2] < b[2] then
			return false
		else
			if a[3] > b[3] then
				return true
			elseif a[3] < b[3] then
				return false
			else
				if a[4] > b[4] then
					return true
				elseif a[4] < b[4] then
					return false
				else
					if a[5] > b[5] then
						return true
					elseif a[5] < b[5] then
						return false
					else
						return false
					end
				end
			end
		end
	end)
	
	for i=1, #m_sutraRank do m_sutraMap[m_sutraRank[i][1]] = i end
	for i=1, #m_fohaoRank do m_fohaoMap[m_fohaoRank[i][1]] = i end
	for i=1, #m_signRank do m_signMap[m_signRank[i][1]] = i end
	for i=1, #m_censerRank do m_censerMap[m_censerRank[i][1]] = i end
	for i=1, #m_totalRank do m_totalMap[m_totalRank[i][1]] = i end	
	
	local function printRank()
		print("-------------m_sutraRank-------------")
		printTable(m_sutraRank)
		printTable(m_sutraMap)
		print("-------------m_fohaoRank-------------")
		printTable(m_fohaoRank)
		printTable(m_fohaoMap)
		print("-------------m_signRank-------------")
		printTable(m_signRank)
		printTable(m_signMap)
		print("-------------m_censerRank-------------")
		printTable(m_censerRank)
		printTable(m_censerMap)
		print("-------------m_totalRank-------------")
		printTable(m_totalRank)
		printTable(m_totalMap)
	end
	
	printRank()
end

local function updateRank(uuid, num, rankMap, rank)
	local srcIndex = rankMap[uuid]
	if not srcIndex or not rank[srcIndex] then
		return
	end

	if num > rank[srcIndex][2] then
		local t = srcIndex-1
		while t >= 1 do
			if rank[t][2] > rank[srcIndex][2] then
				break
			end
			t = t-1
		end
		t = t+1
		if t < srcIndex then
			for i=srcIndex, t+1, -1 do
				rank[i][1] = rank[i-1][1]
				rank[i][2] = rank[i-1][2]
				rankMap[rank[i-1][1]] = i
			end
			rank[t][1] = uuid
			rank[t][2] = num
			rankMap[uuid] = t
		end
	end
end

local function updateTotalRank(uuid, num, matchIndex)
	local srcIndex = m_totalMap[uuid]
	if not srcIndex or matchIndex > rankCount or matchIndex < 2 then
		return
	end
	
	m_totalRank[srcIndex][matchIndex] = num
	
	local t = srcIndex-1
	while t>=1 do
		local bigger = false
		for i=1, matchIndex do
			if m_totalRank[t][i] > m_totalRank[srcIndex][i] then
				bigger = true
				break
			end
		end
		if bigger then
			break
		end
		
		for i=matchIndex+1, rankCount do
			if m_totalRank[t][i] > m_totalRank[srcIndex][i] then
				bigger = true
				break
			end
		end
		if bigger then
			break
		end
		
		t = t-1
	end
	t = t+1
	
	if t < srcIndex then
		local srcCopy = {}
		for i=1, rankCount do srcCopy[i] = m_totalRank[srcIndex][i] end
		
		for i=srcIndex, t+1, -1 do
			for j=1, rankCount do
				m_totalRank[i][j] = m_totalRank[i-1][j]
			end
			m_totalMap[m_totalRank[i][1]] = i
		end
		
		for j=1, rankCount do
			m_totalRank[t][j] = srcCopy[j]			
		end
		m_totalMap[m_totalRank[t][1]] = t
	end
end

function CMD.updateSutra(uuid, num)
	print("rankService.updateSutra:", uuid, num)
	updateRank(uuid, num, m_sutraMap, m_sutraRank)
	printTable(m_sutraMap)
	printTable(m_sutraRank)
	updateTotalRank(uuid, num, 2)
end
function CMD.getSutraRank(uuid)
	return m_sutraMap[uuid] or 0
end

function CMD.updateFohao(uuid, num)
	updateRank(uuid, num, m_fohaoMap, m_fohaoRank)
	updateTotalRank(uuid, num, 3)
end
function CMD.getFohaoRank(uuid)
	return m_fohaoMap[uuid] or 0
end

function CMD.updateSign(uuid, num)
	updateRank(uuid, num, m_signMap, m_signRank)
	updateTotalRank(uuid, num, 4)
end
function CMD.getSignRank(uuid)
	return m_signMap[uuid] or 0
end

function CMD.updateCenser(uuid, num)
	updateRank(uuid, num, m_censerMap, m_censerRank)
	updateTotalRank(uuid, num, 5)
end
function CMD.getCenserRank(uuid)
	return m_censerMap[uuid] or 0
end

function CMD.getTotalRank(uuid)
	print("getTotalRank", uuid)
	printTable(m_totalMap)
	return m_totalMap[uuid] or 0
	--[[local sutraRank = m_sutraMap[uuid]
	local sutraParal = {}
	if sutraRank then
		local sutraNum = m_sutraRank[uuid][2]		
		local n = sutraRank-1
		while n >= 1 do
			if m_sutraRank[n][2] == sutraNum then
				sutraParal[#sutraParal+1] = m_sutraRank[n][1]
				n=n-1
			else
				break
			end
		end
		local n = sutraRank+1
		while n <= #m_sutraRank do
			if m_sutraRank[n][2] == sutraNum then
				sutraParal[#sutraParal+1] = m_sutraRank[n][1]
				n=n+1
			else
				break
			end
		end
		if #sutraParal == 0 then
			return sutraRank
		end
	else
		return 0
	end
	
	local fohaoParal = {}
	local maxFohaoRank
	for i=1, #sutraParal do
		if 
	end--]]
end

skynet.start(function()
	print("rankService start")
	
	skynet.dispatch("lua", function(_,_, command, ...)
		print("agent dispatch lua:", command)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
	
	init()
	
	skynet.register("rankService")
end)
