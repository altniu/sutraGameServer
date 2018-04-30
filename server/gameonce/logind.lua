local login = require "snax.loginserver"
local crypt = require "skynet.crypt"
local skynet = require "skynet"
--local datacenter = require "skynet.datacenter"
require "functions"

require "skynet.manager"
--require "functions"

local server = {
	host = "47.91.176.170",
	port = 8001,
	multilogin = false,	-- disallow multilogin
	name = "login_master",
}

local server_list = {}
local user_online = {}
local user_cacheTable = {}
--datacenter.set("user_online_list", uid, true)

function server.auth_handler(token)
	print("server.auth_handler.token:" .. token)
	-- the token is base64(user)@base64(server):base64(password)
	local uuid, phone = token:match("([^@]+)@([^:]+)")
	uuid = crypt.base64decode(uuid)
	phone = crypt.base64decode(phone)
	
	if user_cacheTable[uuid] then
		return true
	end
	
	local data = skynet.call("db_service", "lua", "getUserBaseData", uuid)
	if data then
		print("user login, uuid = " .. uuid)
	
	else
		print("new user login, uuid = " .. uuid .. ",size=" .. string.len(uuid) .. ", phone = " .. phone)
		skynet.call("db_service", "lua", "register", uuid, phone)
		skynet.call("rankService", "lua", "addNewUUID", uuid)
	end
	user_cacheTable[uuid] = true
	
	return true
end

function server.reg_handler(userdata)
	local u = string.split(userdata, ",")
	local user,password = (u[1] or ""), (u[2] or "")
	local r, code = skynet.call("db_service", "lua", "register", user, password)
	return r, code
end

function server.login_handler(uuid)
	print(string.format("%s is login", uuid))
	--print(string.format("%s is login", uuid, server, crypt.hexencode(secret)))
	--local gameserver = assert(server_list[server], "Unknown server")
	-- only one can login, because disallow multilogin
	
	if not user_cacheTable[uuid] then
		return false
	end
	
	local last = user_online[uuid]
	--datacenter.set("user_online", uuid, true)
	
	user_online[uuid] = true
	
	if last then
		--skynet.call(last.address, "lua", "kick", uuid, last.subid)
	end
	if user_online[uuid] then
		--error(string.format("user %s is already online", uuid))
	end
	return true
	--local subid = tostring(skynet.call(gameserver, "lua", "login", uuid, secret))
	--user_online[uuid] = { address = gameserver, subid = subid , server = server}
	--return subid
end
function server.registered_handler()
	return ""
end

local CMD = {}

function CMD.register_gate(server, address)
	server_list[server] = address

	--test code
	--local r = skynet.call(".G_DB_SERVICE", "lua", "get_userID", "root", "psd")
	--print("r:" .. r)
end

function CMD.logOut(uuid)
	print("logind: logout uuid="..uuid)
	local u = user_online[uuid]
	if u then
		print(string.format("%s@%s is logout", uuid, u.server))
		user_online[uuid] = nil
		--datacenter.set("user_online", uuid, nil)
	end
end

function server.command_handler(command, ...)
	local f = assert(CMD[command])
	return f(...)
end

login(server)
