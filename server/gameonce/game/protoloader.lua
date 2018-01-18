-- module proto as examples/proto.lua
package.path = "./server/game/?.lua;" .. package.path

local skynet = require "skynet"
local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"
local proto = require "proto"

skynet.start(function()
	sprotoloader.save(proto.c2s, 1)
	sprotoloader.save(proto.s2c, 2)
	--sprotoloader.register("./test/spProto1.sp", 1)
	--sprotoloader.register("./test/spProto2.sp", 1)
	-- don't call skynet.exit() , because sproto.core may unload and the global slot become invalid
end)
