local skynet = require "skynet"
require "skynet.manager"    -- import skynet.register
local mysql = require "skynet.db.mysql"
local db = nil
local serviceName = "db_service"




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
local tbl_userUpdateData = "userUpdateData"
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
	--print(sql)
	res = db:query(sql)
	if not res then
		print(serviceName .. ",getUserBaseData uuid = " .. uuid .. " error")
		return false
	end
	
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
	if not res then
		print(serviceName .. ",updateUserBaseData uuid = " .. uuid .. " error")
		return false
	end
	
	return res and true or false
end

function CMD.getUserUpdateData(uuid)
	if not uuid or "string" ~= type(uuid) then 
		local sql = "select * from " .. tbl_userUpdateData
		--print(sql)
		res = db:query(sql)
		assert(res, serviceName .. ",getUserUpdateData")
		--printTable(res)
		return res
	end
	
	local sql = "select * from " .. tbl_userUpdateData .. " where uuid = \'" .. uuid .. "\'"
	--print(sql)
	res = db:query(sql)
	assert(res, serviceName .. ",getUserUpdateData uuid = " .. uuid .. " error")
	--printTable(res)
	
	local data = {}
	for k,v in pairs(res) do
		if v["uuid"] == uuid then
			data = DeepCopy(v)
			break
		end
	end
	return data
end

function CMD.updateUserUpdate(uuid, key, value)
	local sql = "update " .. tbl_userUpdateData .. " set " .. key .. " = \'" .. value .. "\'" .. " where uuid = \'" .. uuid .. "\'"
	res = db:query(sql)
	if not res then
		print(serviceName .. ",updateUserUpdate uuid = " .. uuid .. " error")
		return false
	end
	
	return res and true or false
end

function CMD.getUserMonthCollect(uuid, month)
	if not uuid or "string" ~= type(uuid) then 
		return false
	end
	
	local sql = "select * from " .. tbl_monthCollect .. " where uuid = \'" .. uuid .. "\' and month = " .. month
	res = db:query(sql)
	assert(res, serviceName .. ",getUserMonthCollect uuid = " .. uuid .. " error")

	--月份不存在，新增一条数据
	if #res == 0 then
		sql = string.format("insert into %s(uuid, signLine, month, fohaoGroup) values('%s',%d, %d, '%s');", 
				tbl_monthCollect, uuid, 0, month, "")
		res = db:query(sql)
		res = {uuid=uuid, signLine=0, month=month, fohaoGroup=""}
		return res
	end
	
	local data = {}
	for k,v in pairs(res) do
		if v["uuid"] == uuid then
			data = DeepCopy(v)
			break
		end
	end
	return data
end

function CMD.updateMonthCollect(uuid, month, key, value)
	local sql = "update " .. tbl_monthCollect .. " set " .. key .. " = \'" .. value .. "\'" .. " where uuid = \'" .. uuid .. "\' and month = " .. month
	res = db:query(sql)
	if not res then
		print(serviceName .. ",updateMonthCollect uuid = " .. uuid .. " error, month = " .. month)
		return false
	end
	
	return res and true or false
end




function CMD.register(uuid, phone, userData)
	if not uuid or "string" ~= type(uuid) then 
		return false
	end

	--print("new user ："..uuid .. ", size=" .. string.len(uuid))
	local res
	
	local sql = string.format([[insert into %s(uuid, registerTime, jingtuGroup, lotusNum, phoneType, userData) 
								values('%s', %d, '%s', %d, '%s', '%s');]], 
				tbl_userBaseData, uuid, os.time(), "", 0, phone or "", userData or "")
	--print(sql)	
	res = db:query(sql)
	assert(res, serviceName .. ",register uuid = " .. uuid .. " error "  .. tbl_userBaseData)
	
	sql = string.format([[insert into %s(uuid, incenseLastTime, sutraLastTime, signNum, censerNum, sutraNum, fohaoNum, signRank, censerRank, sutraRank, totalRank) 
								values('%s', %d, %d, %d, %d, %d, %d, %d, %d, %d, %d);]], 
				tbl_userUpdateData, uuid, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
	print(sql)	
	res = db:query(sql)
	assert(res, serviceName .. ",register uuid = " .. uuid .. " error "  .. tbl_userUpdateData)	
	printTable(res)
	
	local dates = os.date("*t", t)
	--uuid, signLine, mouth, fohaoGroup
	sql = string.format("insert into %s(uuid, signLine, month, fohaoGroup) values('%s',%d, %d, '%s');", 
				tbl_monthCollect, uuid, 0, dates.month, "")
	res = db:query(sql)
	assert(res, serviceName .. ",register uuid = " .. uuid .. " error "  .. tbl_monthCollect)
	
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
    skynet.register(serviceName)
end)
