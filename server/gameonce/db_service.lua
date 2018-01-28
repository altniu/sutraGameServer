local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local mysql = require "skynet.db.mysql"
local db = nil



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

--lua对象深度拷贝
function DeepCopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

local userIDSerial = 0
local tbl_monthCollect = "monthCollect"
local tbl_userBaseData = "userBaseData"
local CMD = setmetatable({}, { __gc = function() netpack.clear(queue) end })



function CMD.open( source, conf )
end

function CMD.close()
end

function CMD.getUserBaseData(uuid)
	if not uuid or "string" ~= type(uuid) then 
		return false
	end
	
	local sql = "select * from " .. tbl_userBaseData .. " where uuid = \'" .. uuid .. "\'"
	res = db:query(sql)
	local data = nil
	for k,v in pairs(res) do
		if v["uuid"] == uuid then
			data = DeepCopy(v)
			break
		end
	end
	return data
end

function CMD.updateUserBaseData(uuid, key, value)
	local sql = "update " .. tbl_userBaseData .. " set " .. key .. " = \'" .. value .. "\'" .. " where uuid = \'" .. uuid .. "\'"
	res = db:query(sql)
	
	return res and true or false
end

function CMD.getUserMonthCollect(uuid)
	if not uuid or "string" ~= type(uuid) then 
		return false
	end
	
	local sql = "select * from " .. tbl_monthCollect .. " where uuid = \'" .. uuid .. "\'"
	res = db:query(sql)
	local data = {}
	for k,v in pairs(res) do
		if v["uuid"] == uuid then
			data = DeepCopy(v)
			break
		end
	end
	return data
end

function CMD.updateMonthCollect(uuid, key, value)
	local sql = "update " .. tbl_monthCollect .. " set " .. key .. " = \'" .. value .. "\'" .. " where uuid = \'" .. uuid .. "\'"
	res = db:query(sql)
	
	return res and true or false
end


function CMD.register(uuid, phone, userData)
	if not uuid or "string" ~= type(uuid) then 
		return false
	end

	print("new user ："..uuid .. ", size=" .. string.len(uuid))
	local res
	
	
	--uuid, registerTime, signNum, censerNum, sutraNum, jingtuGroup, lotusNum, phoneType, userData
	local sql = string.format([[insert into %s(uuid, registerTime, signNum, censerNum, sutraNum, jingtuGroup, lotusNum, phoneType, userData) 
								values('%s', %d, %d, %d, %d, '%s', %d, '%s', '%s');]], 
				tbl_userBaseData, uuid, os.time(), 0, 0, 0, "", 0, phone or "", userData or "")
	print(sql)
	
	res = db:query(sql)
	dump(res)
	
	--uuid, signLine, mouth, fohaoGroup
	sql = string.format("insert into %s(uuid, signLine, mouth, fohaoGroup) values('%s',%d, %d, '%s');", 
				tbl_monthCollect, uuid, 0, 0, "")
	print(sql)
	
	res = db:query(sql)
	dump(res)
	return true
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
		database="sutraGameDB",
		user="root",
		password="root",
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
