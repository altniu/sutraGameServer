local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local table = table
local string = string
local assert = assert

--[[

Protocol:

	line (\n) based text protocol

	1. Server->Client : base64(8bytes random challenge)
	2. Client->Server : base64(8bytes handshake client key)
	3. Server: Gen a 8bytes handshake server key
	4. Server->Client : base64(DH-Exchange(server key))
	5. Server/Client secret := DH-Secret(client key/server key)
	6. Client->Server : base64(HMAC(challenge, secret))
	7. Client->Server : DES(secret, base64(token))
	8. Server : call auth_handler(token) -> server, uid (A user defined method)
	9. Server : call login_handler(server, uid, secret) ->subid (A user defined method)
	10. Server->Client : 200 base64(subid)

Error Code:
	400 Bad Request . challenge failed
	401 Unauthorized . unauthorized by auth_handler
	403 Forbidden . login_handler failed
	406 Not Acceptable . already in login (disallow multi login)

Success:
	200 base64(subid)
]]

local socket_error = {}
local function assert_socket(service, v, fd)
	if v then
		return v
	else
		skynet.error(string.format("%s failed: socket (fd = %d) closed", service, fd))
		error(socket_error)
	end
end

local function write(service, fd, text)
	assert_socket(service, socket.write(fd, text), fd)
end

local function launch_slave(auth_handler, register_handler, login_handler)
	local function auth(fd, addr)
		-- set socket buffer limit (8K)
		-- If the attacker send large package, close the socket
		socket.limit(fd, 8192)

		local opcode = assert_socket("auth", socket.readline(fd), fd)
		opcode = crypt.base64decode(opcode)
		print("auth.recv.opcode:" .. opcode)
		if opcode == "r" then
			local regmsg = assert_socket("auth", socket.readline(fd), fd)
			local _, ok, code =  pcall(register_handler,crypt.base64decode(regmsg))
			return _ and ok, code
			
		elseif opcode == "a" then
			local challenge = crypt.randomkey()
			--print("challenge", crypt.base64encode(challenge))
			write("auth", fd, crypt.base64encode(challenge).."\n")

			local handshake = assert_socket("auth", socket.readline(fd), fd)
			local clientkey = crypt.base64decode(handshake)
			if #clientkey ~= 8 then
				error "Invalid client key"
			end
			--print("clientkey", handshake)
			
			local serverkey = crypt.randomkey()
			serverkey = crypt.dhexchange(serverkey)
			--print("serverkey", crypt.base64encode(serverkey))
			write("auth", fd, crypt.base64encode(serverkey).."\n")

			local secret = crypt.dhsecret(clientkey, serverkey)			
			--print("secret", crypts.base64encode(secret))

			local response = assert_socket("auth", socket.readline(fd), fd)
			--print("client response", response)
			response = crypt.base64decode(response)			
			local hmac = crypt.hmac64(challenge, secret)
			print("hmac", crypt.base64encode(hmac))
			if hmac ~= response then
				print "200 challenge failed"
				return false, 200
			else
				write("auth", fd, crypt.base64encode("0") .. "\n")
			end
			
			local etoken = assert_socket("auth", socket.readline(fd),fd)
			print("etoken", etoken)
			local token = crypt.desdecode(secret, crypt.base64decode(etoken))
			print("token", token)
			local _, ok, uid =  pcall(auth_handler,token)
			ok = _ and ok
			local resc = ok and 0 or 300
			
			return ok, resc, uid
			
		elseif opcode == "l" then
			write("auth", fd, "")
			print("user l")
			local uuid = assert_socket("auth", socket.readline(fd), fd)
			uuid = crypt.base64decode(uuid)
			print("user l", uuid)
			local _, ok, uid =  pcall(login_handler, uuid)
			ok = _ and ok
			local resc = ok and 0 or 300
			
			return ok, resc, uid
			
		end
		
		return false, 404
	end

	local function ret_pack(ok, err, ...)
		if ok then
			return skynet.pack(err, ...)
		else
			if err == socket_error then
				return skynet.pack(nil, "socket error")
			else
				return skynet.pack(false, err)
			end
		end
	end

	local function auth_fd(fd, addr)
		skynet.error(string.format("connect from %s (fd = %d)", addr, fd))
		socket.start(fd)	-- may raise error here
		local msg, len = ret_pack(pcall(auth, fd, addr))
		socket.abandon(fd)	-- never raise error here
		return msg, len
	end

	skynet.dispatch("lua", function(_,_,...)
		local ok, msg, len = pcall(auth_fd, ...)
		if ok then
			skynet.ret(msg,len)
		else
			skynet.ret(skynet.pack(false, msg))
		end
	end)
end


local function accept(conf, s, fd, addr)
	-- call slave auth
	local ok, code, data = skynet.call(s, "lua",  fd, addr)
	print("*******", ok, code, data)
	local msg = code .. "," .. (data or "")
	
	write("accept result", fd, crypt.base64encode(msg).."\n")
	
	return ok, code
end

local function launch_master(conf)
	local instance = conf.instance or 8
	assert(instance > 0)
	local host = conf.host or "0.0.0.0"
	local port = assert(tonumber(conf.port))
	local slave = {}
	local balance = 1

	skynet.dispatch("lua", function(_,source,command, ...)
		skynet.ret(skynet.pack(conf.command_handler(command, ...)))
	end)

	for i=1,instance do
		table.insert(slave, skynet.newservice(SERVICE_NAME))
	end

	skynet.error(string.format("login server listen at : %s %d", host, port))
	local id = socket.listen(host, port)
	socket.start(id , function(fd, addr)
		local s = slave[balance]
		balance = balance + 1
		if balance > #slave then
			balance = 1
		end
		local ok, err = pcall(accept, conf, s, fd, addr)
		if not ok then
			if err ~= socket_error then
				skynet.error(string.format("invalid client (fd = %d) error = %s", fd, err))
			end
		end
		socket.close_fd(fd)	-- We haven't call socket.start, so use socket.close_fd rather than socket.close.
	end)
end

local function login(conf)
	local name = "." .. (conf.name or "login")
	skynet.start(function()
		local loginmaster = skynet.localname(name)
		if loginmaster then
			local auth_handler = assert(conf.auth_handler)
			local register_handler = assert(conf.reg_handler)
			local login_handler = assert(conf.login_handler)
			launch_master = nil
			conf = nil
			launch_slave(auth_handler, register_handler, login_handler)
			
		else
			launch_slave = nil
			conf.auth_handler = nil
			conf.reg_handler = nil
			assert(conf.login_handler)
			assert(conf.command_handler)
			skynet.register(name)
			launch_master(conf)
		end
	end)
end

return login
