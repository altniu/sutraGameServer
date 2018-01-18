local sprotoparser = require "sprotoparser"

local proto = {}




proto.c2s = sprotoparser.parse [[
.package {
	type 0 : integer
	session 1 : integer
}

totalPush 1 {
	request {
		uid 0 : integer
	}
	response {
        code 0  : integer
		coin 1  : integer
		level 2 : integer
		score 3 : integer
		gold 4 : integer
		name 5 : string
	}
}

enterRoom 2 {
	request {
		level 0 : integer
	}
	response {
		p_name_1 0 : string
		p_gold_1 1 : integer
		p_icon_1 2 : integer
		p_site_1 3 : integer
		p_name_2 4 : string
		p_gold_2 5 : integer
		p_icon_2 6 : integer
		p_site_2 7 : integer
		p_name_3 8 : string
		p_gold_3 9 : integer
		p_icon_3 10 : integer
		p_site_3 11 : integer
		p_state_1 12 : integer
		p_state_2 13 : integer
		p_state_3 14 : integer
		p_uid_1 15 : integer
		p_uid_2 16 : integer
		p_uid_3 17 : integer
		roomID 18 : integer
	}
}

ready 3 {
	request {
        uid 0 : integer
        ready 1 : boolean
	}
    response {
		code 0 : integer
	}
}

selfJiaodizhu 4 {
	request     {
		value 0 : integer
	}
}

selfQiangdizhu 5 {
	request     {
		value 0 : integer
	}
}

selfPayPoke 6 {
	request     {
		pokes 0 : string
	}
	response {
		code 0 : integer
	}
}


selfJiaodizhut 7 {
	request     {
		value 0 : integer
	}
}

]]

proto.s2c = sprotoparser.parse [[
.package {
	type 0 : integer
	session 1 : integer
}

playerReady 1 {
	request     {
        uid 0 : integer
		isready 1 : boolean
	}
}

startGame 2 {
	request     {
		pokes 0 : string
		secretpokes 1 : string
		jiaodizhuSite 2 : integer
	}
}

jiaodizhu 3 {
	request     {
		site 0 : integer
		isjiaodizhu 1 : string
	}
}

qiangdizhu 4 {
	request     {
		site 0 : integer
		isqiangdizhu 1 : string
	}
}

payPoke 5 {
	request     {
		site 0 : integer
		pokes 1 : string
		roundWinSite 2 : integer
	}
}

playerEnterRoom 6 {
	request     {
		p_name 0 : string
		p_gold 1 : integer
		p_icon 2 : integer
		p_site 3 : integer
		p_uid 4 : integer
        p_state 5 : integer
	}
}

playerExitRoom 7 {
	request     {
		site 0 : integer
	}
}

gameOver 8 {
	request     {
		winSite 0 : integer
		score 1 : string
	}
}

startPayPoke 9 {
	request     {
		dizhuSite 0 : integer
	}
}

]]

return proto
