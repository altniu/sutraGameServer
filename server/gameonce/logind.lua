local login = require "snax.loginserver"
local crypt = require "crypt"
local skynet = require "skynet"
local datacenter = require "datacenter"
require "functions"

require "skynet.manager"
--require "functions"

local server = {
	host = "192.168.220.128",
	port = 8001,
	multilogin = false,	-- disallow multilogin
	name = "login_master",
}

local server_list = {}
local user_online = {}


function server.auth_handler(token)
	print("server.auth_handler.token:" .. token)
	-- the token is base64(user)@base64(server):base64(password)
	local user, password = token:match("([^@]+)@([^:]+)")
	user = crypt.base64decode(user)
	password = crypt.base64decode(password)
	
	local uid = skynet.call("db_service", "lua", "getuid", user, password)
	if uid > 0 then
		print("user login success, user = " .. user .. ", uid = " .. uid)
		--local last = user_online[uid]
		datacenter.set("user_online_list", uid, true)
		return true, uid
	end
	return false
end

function server.reg_handler(userdata)
	local u = string.split(userdata, ",")
	local user,password = (u[1] or ""), (u[2] or "")
	local r, code = skynet.call("db_service", "lua", "register", user, password)
	return r, code
end
--[[
function server.login_handler(server, uid, secret)
	print(string.format("%s@%s is login, secret is %s", uid, server, crypt.hexencode(secret)))
	--local gameserver = assert(server_list[server], "Unknown server")
	-- only one can login, because disallow multilogin
	local last = user_online[uid]
	datacenter.set("user_online", uid, true)

	if last then
		--skynet.call(last.address, "lua", "kick", uid, last.subid)
	end
	if user_online[uid] then
		--error(string.format("user %s is already online", uid))
	end
	return uid
	--local subid = tostring(skynet.call(gameserver, "lua", "login", uid, secret))
	--user_online[uid] = { address = gameserver, subid = subid , server = server}
	--return subid
end
function server.registered_handler()
	return ""
end
--]]
local CMD = {}

function CMD.register_gate(server, address)
	server_list[server] = address

	--test code
	--local r = skynet.call(".G_DB_SERVICE", "lua", "get_userID", "root", "psd")
	--print("r:" .. r)
end

function CMD.logOut(uid)
	local u = user_online[uid]
	if u then
		print(string.format("%s@%s is logout", uid, u.server))
		user_online[uid] = nil
		datacenter.set("user_online", uid, nil)
	end
end

function server.command_handler(command, ...)
	local f = assert(CMD[command])
	return f(...)
end

login(server)
