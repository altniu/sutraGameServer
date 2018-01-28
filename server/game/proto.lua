local sprotoparser = require "sprotoparser"

local proto = {}




proto.c2s = sprotoparser.parse [[

.package {
	type 0 : integer
	session 1 : integer
}

totalPush 1 {
	request {
		uuid 0 : string
	}
	
	response {
		totalRank 0 : integer
		signNum 1 : integer
		signRank 2 : integer
		censerNum 3 : integer
		censerRank 4 : integer
		sutraNum 5 : integer
		sutraRank 6 : integer
		
		jingtuGroup 7 : string
		lotusNum 8 : integer
		
		signLine 9 : integer
		serverTime 10 : integer
		fohaoGroup 11 : string
		
		first 12 : boolean
	}
}

updateUserData 2 {
	request {
		type 0 : string
		data 1 : string
	}
	response {
		errCode 0 : integer
		desc 1 : string
	}
}
]]

proto.s2c = sprotoparser.parse [[
.package {
	type 0 : integer
	session 1 : integer
}

heartbeat 1 {}

pushUserData 2 {
	request {
		type 0 : integer
		data 1 : string
	}
}

]]

return proto
