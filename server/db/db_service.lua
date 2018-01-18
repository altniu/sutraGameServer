local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local mysql = require "mysql"
local db = nil

require "functions"

local function dump(obj)
    local getIndent, quoteStr, wrapKey, wrapVal, dumpObj
    getIndent = function(level)
        return string.rep("\t", level)
    end
    quoteStr = function(str)
        return '"' .. string.gsub(str, '"', '\\"') .. '"'
    end
    wrapKey = function(val)
        if type(val) == "number" then
            return "[" .. val .. "]"
        elseif type(val) == "string" then
            return "[" .. quoteStr(val) .. "]"
        else
            return "[" .. tostring(val) .. "]"
        end
    end
    wrapVal = function(val, level)
        if type(val) == "table" then
            return dumpObj(val, level)
        elseif type(val) == "number" then
            return val
        elseif type(val) == "string" then
            return quoteStr(val)
        else
            return tostring(val)
        end
    end
    dumpObj = function(obj, level)
        if type(obj) ~= "table" then
            return wrapVal(obj)
        end
        level = level + 1
        local tokens = {}
        tokens[#tokens + 1] = "{"
        for k, v in pairs(obj) do
            tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
        end
        tokens[#tokens + 1] = getIndent(level - 1) .. "}"
        return table.concat(tokens, "\n")
    end
    return dumpObj(obj, 0)
end

local function test2( db)
    local i=1
    while true do
        local    res = db:query("select * from cats order by id asc")
        print ( "test2 loop times=" ,i,"\n","query result=",dump( res ) )
        res = db:query("select * from cats order by id asc")
        print ( "test2 loop times=" ,i,"\n","query result=",dump( res ) )

        skynet.sleep(1000)
        i=i+1
    end
end
local function test3(db)
    local i=1
    while true do
        local    res = db:query("select * from cats order by id asc")
        print ( "test3 loop times=" ,i,"\n","query result=",dump( res ) )
        res = db:query("select * from cats order by id asc")
        print ( "test3 loop times=" ,i,"\n","query result=",dump( res ) )
        skynet.sleep(1000)
        i=i+1
    end
end


local userIDSerial = 0
local table_user = "user"
local table_userCollect = "userCollect"
local table_playerdata = "playerData"
local CMD = setmetatable({}, { __gc = function() netpack.clear(queue) end })

local function getMaxUserID()
	if userIDSerial <= 0 then
		local sql = "select * from " .. table_userCollect
		local d = 1000000000
		res = db:query(sql)
		for k,v in pairs(res) do
				d = tonumber(v["maxUserID"] or d)
				break
		end
		userIDSerial = d
	end
	return userIDSerial
end
local function updateMaxUserID(uid)
	if uid > userIDSerial then
		local old = userIDSerial
		userIDSerial = uid
		local sql = "update " .. table_userCollect .. " set maxUserID=" .. userIDSerial .." where maxUserID=" .. old
		db:query(sql)
	end
end

function CMD.open( source, conf )
end

function CMD.close()
end

function CMD.getuid(name, userpassward)
	if not name or 
	not userpassward or 
		"string" ~= type(name) or 
			"string" ~= type(userpassward) then 
			return 0 
	end

	local sql = "select * from " .. table_user .. " where name = \'" .. name .. "\'"
	res = db:query(sql)
	local userid = 0
	for k,v in pairs(res) do
		if v["passward"] == userpassward then
			userid = tonumber(v["uid"])
			break
		else
			userid = -1
			break
		end
	end
	return userid
end
function CMD.register(name, userpassward)
	if not name or 
	not userpassward or 
	"string" ~= type(name) or 
	"string" ~= type(userpassward) then 
		return false 
	end

	local sql = "select * from " .. table_user .. " where name = \'" .. name .. "\'"
	res = db:query(sql)
	
	local userid = 0
	for k,v in pairs(res) do
		if v["name"] == name then
			userid = v["uid"]
			break
		end
	end
	if userid > 0 then
		print("player user id already exist. ", name)
		return false, 300
	end

	local  uid = getMaxUserID() + 1
	sql = "insert into "..table_user.." values('" .. uid .. "','"..name.."','"..userpassward.."');"
	db:query(sql)

	updateMaxUserID(uid)
	print("new user register："..name..", "..userpassward.."，serialid："..getMaxUserID())

	sql = "insert into "..table_playerdata.." values('" .. uid .. "','0','0','0','0','" .. name .. "');"
	db:query(sql)
	return true, 0
end

function CMD.getPlayerData(uid)
	if not uid or "number" ~= type(uid)  then return  "" end
	
	local sql = "select * from " .. table_playerdata .. " where uid = \'" .. uid .. "\'"
	res = db:query(sql)

	local data = {uid=0,coin=0,level=0,score=0,gold=0,name=""}
	
	for k,v in pairs(res) do
		data = v
		break
	end
	return data
end

skynet.start(function()
    print("db_service start")
	--test code
	--table.insert(testTable, 1)

	local function on_connect(db)
		db:query("set charset utf8");
	end
	db=mysql.connect({
		host="127.0.0.1",
		port=3306,
		database="DoudizhuDB",
		user="root",
		password="yu",
		max_packet_size = 1024 * 1024,
		on_connect = on_connect
	})
	if not db then
		skynet.error("failed to connect db")
		assert(false, "failed to connect db")
	end

	print("success to connect to mysql server")
	
	skynet.dispatch("lua", function (session, address, cmd, ...)
                            print("dbService.dispatch.cmd: " .. cmd)
		local f = CMD[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			skynet.ret(skynet.pack(handler.command(cmd, address, ...)))
		end
	end)


	--[[
	local sql = "select * from " .. "class" .. " where class_name = \'" .. "one" .. "\'"
	res = db:query(sql)
	--print ( dump( res ) )
                for k,v in pairs(res) do
                        if type(v) == "table" then
                                print(k)
                                for kk,vv in pairs(v) do
                                        print(kk,vv)
                                end
                        else
                                print(k,v)
                        end
                end
	--]]
                --[[
	res = db:query("insert into cats (name) "
                             .. "values (\'Bob\'),(\'\'),(null)")
	--print ( dump( res ) )

	res = db:query("select * from cats order by id asc")
	--print ( dump( res ) )
                --]]
    -- test in another coroutine
	--skynet.fork( test2, db)
    --skynet.fork( test3, db)
	

	--db:disconnect()
	--skynet.exit()
    skynet.register("db_service")
end)
