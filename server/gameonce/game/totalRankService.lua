local skynet = require "skynet"
--local netpack = require "netpack"
--local sproto_core = require "sproto.core"

local CMD = {}
local infoDB = {}

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


function CMD.disconnect()
	-- todo: do something before exit
	if pinfo.uuid ~= "" then
		local r = skynet.call("loginserver", "lua", "logOut", pinfo.uuid)
	end
	skynet.exit()
end

local function init()
	r = skynet.call("db_service", "lua", "getUserUpdateData")
	for k,v in pairs(r) do
		infoDB[k] = {sutraNum=v.sutraNum, fohaoNum=v.sutraNum, signNum=v.signNum, censerNum=v.censerNum}
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		print("agent dispatch lua:", command)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
	
	skynet.register("totalRankService")
	init()
	
	print("totalRank service started")
end)
