--斗地主逻辑
local skynet = require "skynet"
package.path = "./server/game/?.lua;" .. package.path
require("DDZ_Define")
require "functions"
DDZGame = {}

local STATE = {unready=1, ready=2, playing=3}

--args:
--userKey :玩家key
function DDZGame:init(roomID, agent)
    self.id = roomID
    self.agent = agent
    self.playerList = {{player=nil,pokes={}}, {player=nil,pokes={}}, {player=nil,pokes={}}}
    self.gameState = nil
    self.playerCount = 0
    self.reallyCount = 0
    self.dizhuSite = 0                      --地主位置
    self.secretpoke = {}                      --低牌
    self.lastPokes = {}                    
    self.lastPokes = {}      --上次出的牌,一定是按顺序排好
    self.dizhuIsWin = false
    self.winCode = 0

    self.jiaodizhu = {site=1, count=0, last=0}--叫地主位置
    self.qiangdizhu = {site=1, count=0, last=0}--抢地主位置

    self.step = 0
    self.currentPayPokeSite = 0             --当前出牌的玩家位置
    self.roundWinSite = 0 --当前回合胜利者

    self.lastPayType = paypoke_type.none
    self.lastCheckPayType = self.lastPayType

    self:setPlayState(DDZ_Define.play_state.playWaitStart)
end

function DDZGame:getPlayerCount()
        return self.playerCount
end

--玩家进入
function DDZGame:addPlayer(player)
  for k,v in pairs(self.playerList) do
      if not self.playerList[k].player then
        player.site = k
        player.state = STATE.unready
        self.playerList[k].player = player
        self.playerCount=self.playerCount+1
        break
      end
  end
  return player
end

--玩家准备
function DDZGame:playerReady(uid, isReady)
        for k,v in pairs(self.playerList) do
                if v.player and v.player.uid == uid then
                  v.player.state = isReady and STATE.ready or STATE.unready
                  self.reallyCount=self.reallyCount + (isReady and 1 or -1)
                  break
                end
        end
end

--玩家退出
function DDZGame:playerExit(site)
    for k,v in pairs(self.playerList) do
        if v.player and v.player.site == site then
            self.playerList[k].player = nil 
            self.playerCount = math.max(0, self.playerCount - 1)
            break
        end
    end

    if self:isPlaying() then
        self:gameOver(1)
    end
end

function DDZGame:canStartGame()
        if not self:isPlaying() and self.playerCount == DDZ_Define.play_MaxCount and self.reallyCount == DDZ_Define.play_MaxCount then
                return true
        end
        return false
end

function DDZGame:startGame()
    if self:canStartGame() then
        self:initGame()
    end    
end

--开始游戏
function DDZGame:initGame()
    local pokePool = {}
    local function initGameData()
        self.playerList[1].pokes = {}
        self.playerList[2].pokes = {}
        self.playerList[3].pokes = {}

        self.lastPokes = {}
        self.lastPokes = {}
        self.jiaodizhu = {site=math.random(1,DDZ_Define.play_MaxCount), count=0, last=0}
        self:setDizhuBySite(self.jiaodizhu.site)
        self.qiangdizhu = {site=0, count=0, last=0}
        self.step = 0
        self.lastPayType = paypoke_type.none
        self.lastCheckPayType = self.lastPayType
        self.roundWinSite = 0
    end
    local function initPokePool()
        for k,v in pairs(poke_value) do
            if v <= poke_value.p_2 then
                for kk,vv in pairs(poke_color) do
                    if vv <= poke_color.heitao then
                        local p = {value=v, color=vv}
                        table.insert(pokePool, p)
                    end
                end
            end
        end
        local pw = {value=poke_value.p_W, color=poke_color.wang}
        table.insert(pokePool, pw)
        local pww = {value=poke_value.p_WW, color=poke_color.wang}
        table.insert(pokePool, pww)


        local tmp = nil
        local num = #pokePool
        for i=1, num do
            local j = math.random(i, num)
            local tvalue, tcolor = pokePool[j].value, pokePool[j].color
            pokePool[j].value = pokePool[i].value
            pokePool[j].color = pokePool[i].color
            pokePool[i].value = tvalue
            pokePool[i].color = tcolor
        end
        for t=1, num do
            local j = math.random(1, num-t+1)
            local i = num-t+1
            local tvalue, tcolor = pokePool[j].value, pokePool[j].color
            pokePool[j].value = pokePool[i].value
            pokePool[j].color = pokePool[i].color
            pokePool[i].value = tvalue
            pokePool[i].color = tcolor
        end
    end
    local function allocPoke()
        local num = #pokePool
        for i=1,num-3 do
            self:addPokeToPlayerWithSite(i%DDZ_Define.play_MaxCount+1, pokePool[i])
        end
        for i=num-2,num do
            table.insert(self.secretpoke, pokePool[i])
        end

    end

    initGameData()
    initPokePool()
    allocPoke()

    
    self:setPlayState(DDZ_Define.play_state.playing_dealDZ)
end


--给玩家加牌
function DDZGame:addPokeToPlayerWithSite(site, poke)
    if not self.playerList[site].pokes[poke.value] then self.playerList[site].pokes[poke.value] = {} end
    table.insert(self.playerList[site].pokes[poke.value], poke)
end

function DDZGame:getSecretPoke()
    return self.secretpoke
end
function DDZGame:getJiaoDizhuSite()
    return self.jiaodizhu.site
end
function DDZGame:getQiangDizhuSite()
    return self.qiangdizhu.site
end

--设置地主
function DDZGame:setDizhuBySite(st)
    self.dizhuSite = st
end
function DDZGame:getDizhuBySite()
    return self.dizhuSite
end

--抢地主
function DDZGame:qiangdizhuFunc(isqiangdizhu)
    if self.qiangdizhu.count < DDZ_Define.play_MaxCount then
        local lastqiangdizhuSite = self.qiangdizhu.site
        if isqiangdizhu then
            local gap = self.qiangdizhu.count - self.qiangdizhu.last
            self.qiangdizhu.site = math.max(1, (self.qiangdizhu.site+gap)%(DDZ_Define.play_MaxCount+1))
            self:setDizhuBySite(self.qiangdizhu.site)
            self.qiangdizhu.last = self.qiangdizhu.count
        end
        self.qiangdizhu.count = self.qiangdizhu.count + 1
        
        if self.qiangdizhu.count >= DDZ_Define.play_MaxCount then
                for k,v in pairs(self.secretpoke) do
                        self:addPokeToPlayerWithSite(self:getDizhuBySite() ,v)
                end
                self.currentPayPokeSite = self:getDizhuBySite()
                self.roundWinSite = self.currentPayPokeSite
                self:setPlayState(DDZ_Define.play_state.playing_play)
        end

        local function printLogInfo()
            local str = "上次qiang地主者："
            str = str .. self.playerList[lastqiangdizhuSite].player.name
            local gap = self.qiangdizhu.count - 1 - self.qiangdizhu.last
            local site = math.max(1, (self.qiangdizhu.site+gap)%(DDZ_Define.play_MaxCount+1))
            str = str .. "本次响应者：" .. self.playerList[site].player.name .. "，本次是否qiang地主" .. (isqiangdizhu and "true" or "false")
            print(str)
        end
        printLogInfo()
    end
end

--叫地主
function DDZGame:jiaodizhuFunc(isJiaodizhu)
    if self.jiaodizhu.count < DDZ_Define.play_MaxCount then
        
        local lastJiaodizhuSite = self.jiaodizhu.site
        if isJiaodizhu then
            local gap = self.jiaodizhu.count - self.jiaodizhu.last
            self.jiaodizhu.site = math.max(1, (self.jiaodizhu.site+gap)%(DDZ_Define.play_MaxCount+1))
            self:setDizhuBySite(self.jiaodizhu.site)
            self.jiaodizhu.last = self.jiaodizhu.count
        end
        self.jiaodizhu.count = self.jiaodizhu.count + 1

        if self.jiaodizhu.count >= DDZ_Define.play_MaxCount then
                self.qiangdizhu.site = math.max(1, (self.jiaodizhu.site+1)%(DDZ_Define.play_MaxCount+1))
                self:setPlayState(DDZ_Define.play_state.playing_robDZ)
        end

        local function printLogInfo()
            local str = "上次叫地主者："
            str = str .. self.playerList[lastJiaodizhuSite].player.name
            local gap = self.jiaodizhu.count - 1 - self.jiaodizhu.last
            local site = math.max(1, (self.jiaodizhu.site+gap)%(DDZ_Define.play_MaxCount+1))
            str = str .. "本次响应者：" .. self.playerList[site].player.name .. "，本次是否叫地主" .. (isJiaodizhu and "true" or "false")
            print(str)
        end
        printLogInfo()
    end
end

--给玩家减牌
function DDZGame:subPokeToPlayerWithSite(site, pokes)
    for k,v in pairs(pokes) do 
        if self.playerList[site].pokes[v.value] then
            for kk,vv in pairs(self.playerList[site].pokes[v.value]) do
                if vv.color == v.color then
                    table.remove(self.playerList[site].pokes[v.value],kk)
                    break
                end
            end
        end
    end
end

function DDZGame:checkPayPoke(site, pokes)
        local function printLogInfo()
            local str = "上回出牌者: "
            
            local lastSite = self.currentPayPokeSite - 1
            lastSite = lastSite <= 0 and 3 or lastSite
            str = str .. self.playerList[lastSite].player.name .. "(" .. lastSite .. ")" .. "出牌类型: " .. self.lastPayType .. "  , 出牌: \n"
            for k,v in pairs(self.lastPokes) do
                    str = str .. v.value .. ", "
            end
            print(str)

            str = "最后结算者：" .. self.playerList[self.roundWinSite].player.name .. "(" .. self.roundWinSite .. ")" .. ""
            print(str)

            str = "本次出牌者: "
            str = str .. self.playerList[site].player.name .. "(" .. site .. ")" .. "  , 出牌: \n"
            for k,v in pairs(pokes) do
                    str = str .. v.value .. ", "
            end
            print(str)
        end
        printLogInfo()
        local payType = self:payPokeValid(pokes, self.lastPayType)
        if payType and payType ~= paypoke_type.none then self.lastCheckPayType = payType end
        return payType and true or false
end
--出牌
function DDZGame:payPoke(site, pokes)
   local res = 2
   local isWin = false
   local roundWinSite = 0
   if self.gameState == DDZ_Define.play_state.playing_play and self.currentPayPokeSite == site and self:checkPlayerHavePokes(site, pokes)  then
        --local valid, payType = self:payPokeValid(pokes, self.lastPayType)
        --if valid then
            self.lastPayType = self.lastCheckPayType
            self:subPokeToPlayerWithSite(site, pokes)
            res = 0
   end
   print("payPoke.res", res)
   if res == 0 then
        if self:checkGameOver(self.currentPayPokeSite) then
            self:gameOver(0, self.currentPayPokeSite)
            isWin = true

        else
            self.lastPokes = DeepCopy(pokes)
            local nextPaySite = math.max(1, (self.currentPayPokeSite+1)%(DDZ_Define.play_MaxCount+1))
            print("pokes 1")
            print_lua_table(pokes)
            print("pokes 2")
            print(self.roundWinSite ,nextPaySite)

            if #pokes > 0 then
                    self.roundWinSite = self.currentPayPokeSite
                    self.lastPokes = DeepCopy(pokes)
            else
                    if self.roundWinSite == nextPaySite then
                            self.currentPayPokeSite = self.roundWinSite
                            roundWinSite = self.roundWinSite
                            self.lastPokes = {}
                            self.lastPayType = paypoke_type.none
                            self.lastCheckPayType = paypoke_type.none
                    end
            end
            print("self.lastPayType ", self.lastPayType )
            self.currentPayPokeSite = nextPaySite
        end
    end
   return res, roundWinSite, isWin, self.lastPayType
end

--检测玩家是否有牌
function DDZGame:checkPlayerHavePokes(site,pokes)
   local pcnt = {}
   for k,v in pairs(pokes) do
        if not pcnt[v.value] then pcnt[v.value] = 0 end
        pcnt[v.value] = pcnt[v.value] + 1
   end
   for k,v in pairs(pcnt) do
        if not self.playerList[site].pokes[k] or #self.playerList[site].pokes[k] < v then
            return false
        end
   end
   return true
end

function DDZGame:gameOver(code, site)
    local idzhuIsExist = false
     for k,v in pairs(self.playerList) do
        if v.player then
            v.player.state = STATE.unready
            if v.player.site == self.dizhuSite then idzhuIsExist = true end
        end
    end

    if code == 0 then--正常比赛结束
        self.dizhuIsWin = site == self.dizhuSite

    elseif code == 1 then--比赛中玩家退出比赛结束
        self.dizhuIsWin = site ~= self.dizhuSite
    end

    self:setPlayState(DDZ_Define.play_state.gameover)
    self.winCode = code

    for k,v in pairs(self.playerList) do
            if v.player then v.player.state = STATE.unready end
    end
    self.reallyCount = 0

    for k,v in pairs(self.playerList) do
            v.pokes = {}
    end
    self.secretpoke = {}
end

function DDZGame:isGameOver()
    return DDZ_Define.play_state.gameover == self.gameState
end

function DDZGame:getCurrentPaySite()
    return self.currentPayPokeSite
end

function DDZGame:getPlayerWithSite(site)
    return self.playerList[site].player
end

function DDZGame:getLastPokes()
    return self.lastPokes
end

--检测结果,返回胜利者site
function DDZGame:checkGameOver(site)
    if site and self.playerList[site] then
        for k,v in pairs(self.playerList[site].pokes) do
            if #v > 0 then return nil end
        end
        return true
    end
end

function DDZGame:isPlaying()
    return self.gameState == DDZ_Define.play_state.playing_dealDZ or 
            self.gameState == DDZ_Define.play_state.playing_robDZ or 
            self.gameState == DDZ_Define.play_state.playing_play or 
            self.gameState == DDZ_Define.play_state.playing_dispatchPoke
end

function DDZGame:setPlayState(st)
    self.gameState = st
end
function DDZGame:getPlayState()
    return self.gameState
end



--检测要出的牌是否合法
function DDZGame:payPokeValid(pokelist, lastPayType)
    --单张
    local function danzhang(pokes)
        if pokes and #pokes == 1 then
            return pokes[1].value
        end
    end
    local function check_danzhang()
        local danzhangValueA = danzhang(pokelist)
        local danzhangValueB = danzhang(self.lastPokes)
        if danzhangValueA and danzhangValueB and danzhangValueA > danzhangValueB then
            return paypoke_type.danzhang
        end
    end
	local function is_danzhang()
        local danzhangValueA = danzhang(pokelist)
        if danzhangValueA then
            return paypoke_type.danzhang
        end
    end
	
    --一对
    local function yidui(pokes)
        if #pokes == 2 then --一对
            if pokes[1].value == pokes[2].value then
                    return pokes[1].value
            end
        end
    end
    local function check_yidui()
        local yiduiValueA = yidui(pokelist)
        local yiduiValueB = yidui(self.lastPokes)
        if yiduiValueA and yiduiValueB and yiduiValueA > yiduiValueB then
            return paypoke_type.yidui
        end
    end
	local function is_yidui()
        local yiduiValueA = yidui(pokelist)
        if yiduiValueA then
            return paypoke_type.yidui
        end
    end
	
    --双顺，连对：三对或更多的连续对牌（如：334455、88991010JJ）。不包括2和大、小王。
    local function shuangShun(pokes)
        local res = {}
        if #pokes < 6 or #pokes%2 ~= 0 then
            return res
        end
        
        local valid = true
        local value = pokes[1].value - 1
        local index = 1
        

        for i=1,#pokes do
            if index%2 ~= 0 then
                if (value+1) == pokes[i].value and pokes[i].value ~= poke_value.p_2 and pokes[i].value ~= poke_value.p_W and pokes[i].value ~= poke_value.p_WW then
                    value = pokes[i].value
                else
                    valid = false
                    break
                end
            else
                if value == pokes[i].value and value ~= poke_value.p_2 and value ~= poke_value.p_W and value ~= poke_value.p_WW then
                    table.insert(res, value)
                else
                    valid = false
                    break
                end
            end
            index = index + 1
        end

        if false == valid then
            return nil
        end
        if #res * 2 ~= #pokes then
            return nil
        end
		
		table.sort(res, function(a,b) return a<b end)
        return res
    end
    local function check_shuangshun()        
        local ssOther = shuangShun(self.lastPokes)
        local ssMy = shuangShun(pokelist)
        if ssOther and ssMy and #ssOther >= 3 and #ssOther == #ssMy and ssMy[1] > ssOther[1] then
            return paypoke_type.shuangshun
        end
    end
	local function is_shuangshun()
        local ssMy = shuangShun(pokelist)
        if ssMy and 3 <= #ssMy then
            return paypoke_type.shuangshun
        end
    end
	
    --三张牌：三张牌点相同的牌。
    --三顺：二个或更多连续的三张牌。例如：333444、444555666777。不包括2和大、小王。
    --飞机带翅膀：三顺＋同数量的对牌。例如：333444555+667799
    local function sanZhang(pokes)
        local threeList = {}
        local oneList = {}
        local twoList = {}

        if #pokes < 3 then
            return threeList, twoList, oneList
        end

        local i = 1
        local count = #pokes
        local lastValue = pokes[1].value
        while i <= count do
            if lastValue >= poke_value.p_W then
                threeList = {}
                twoList = {}
                oneList = {}
                break

            elseif lastValue == pokes[i].value and pokes[i+1] and lastValue == pokes[i+1].value and pokes[i+2] and lastValue == pokes[i+2].value then
                i = i + 2
                table.insert(threeList, lastValue)                

            elseif lastValue == pokes[i].value and pokes[i+1] and lastValue == pokes[i+1].value then
                i = i + 1
                table.insert(twoList, lastValue)                

            elseif lastValue == pokes[i].value and pokes[i+1] and lastValue ~= pokes[i+1].value then
                table.insert(oneList, lastValue)

            elseif lastValue == pokes[i].value and not pokes[i+1] then
                table.insert(oneList, lastValue)
            end
            i=i+1
            if pokes[i] then lastValue = pokes[i].value end
        end

        table.sort(threeList, function(a,b) return a<b end)
        table.sort(twoList, function(a,b) return a<b end)
        table.sort(oneList, function(a,b) return a<b end)
        return threeList, twoList, oneList
    end
    local function check_sanzhang()
        local szOtherThree, szOtherTwo, szOtherOne = sanZhang(self.lastPokes)
        local szMyThree, szMyTwo, szMyOne = sanZhang(pokelist)
        if #szOtherThree > 0 and #szOtherThree == #szMyThree and szMyThree[1] > szOtherThree[1] and #szOtherTwo == #szMyTwo and #szOtherOne == #szMyOne then
			if szMyThree[1] - szOtherThree[1] < 1 or #szMyThree ~= # szOtherThree or #szMyTwo ~= # szOtherTwo or #szMyOne ~= #szOtherOne then return false end
			
			local myValue = szMyThree[1]
			for i=2, #szMyThree do
				if (myValue+1) ~= szMyThree[i] then return false end
				myValue = myValue + 1
			end
			
			if #szMyThree == 1 and (#szMyTwo+#szMyOne) == 1 then
				return paypoke_type.sandaiyi
			end
			if #szMyThree == 1 and (#szMyTwo+#szMyOne) == 0 then
				return paypoke_type.sanzhang
			end
			
			if #szMyThree > 1 and (#szMyTwo+#szMyOne) == 0 then
				return paypoke_type.sanshun
			end
			if #szMyThree > 1 and (#szMyThree == #szMyTwo or #szMyThree == #szMyOne) then
				return paypoke_type.feiji
			end
        end
    end
	local function is_sanzhang()
        local szMyThree, szMyTwo, szMyOne = sanZhang(pokelist)        
		if 0 < #szMyThree then 
			local myValue = szMyThree[1]
			for i=2, #szMyThree do
				if (myValue+1) ~= szMyThree[i] then return false end
				myValue = myValue + 1
			end
			
			if #szMyThree == 1 and (#szMyTwo+#szMyOne) == 1 then
				return paypoke_type.sandaiyi
			end
			if #szMyThree == 1 and (#szMyTwo+#szMyOne) == 0 then
				return paypoke_type.sanzhang
			end
			
			if #szMyThree > 1 and (#szMyTwo+#szMyOne) == 0 then
				return paypoke_type.sanshun
			end
			if #szMyThree > 1 and (#szMyThree == #szMyTwo or #szMyThree == #szMyOne) then
				return paypoke_type.feiji
			end
        end
    end
	
    --炸弹, 炸弹带牌
    local function zhadan(pokes)
        local fourList = {}
        local oneList = {}
        local twoList = {}

        local i = 1
        local count = #pokes
        local lastValue = pokes[i].value
        while i <= count do
            if lastValue == poke_value.p_W and pokes[i+1] and pokes[i+1] == poke_value.p_WW then
                table.insert(fourList, lastValue)
                i = i + 1
                if pokes[i+1] then lastValue = pokes[i+1].value end       

            elseif lastValue == pokes[i].value and pokes[i+1] and lastValue == pokes[i+1].value and pokes[i+2] and lastValue == pokes[i+2].value and pokes[i+3] and lastValue == pokes[i+3].value then
                table.insert(fourList, lastValue)
                i = i + 3
                if pokes[i+1] then lastValue = pokes[i+1].value end                

            elseif lastValue == pokes[i].value and pokes[i+1] and lastValue == pokes[i+1].value then
                i = i + 1
                if pokes[i+1] then lastValue = pokes[i+1].value end
                table.insert(twoList, lastValue)                

            elseif lastValue == pokes[i].value and pokes[i+1] and lastValue ~= pokes[i+1].value then
                if pokes[i+1] then lastValue = pokes[i+1].value end
                table.insert(oneList, lastValue)

            elseif lastValue == pokes[i].value and not pokes[i+1] then
                table.insert(oneList, lastValue)
            end
            i=i+1
        end

        table.sort(fourList, function(a,b) return a<b end)
        table.sort(twoList, function(a,b) return a<b end)
        table.sort(oneList, function(a,b) return a<b end)
        return fourList, twoList, oneList
    end
    local function check_zhadan()
        local zdOther4, zdOther2, zdOther1 = zhadan(self.lastPokes)
        local zdMy4, zdMy2, zdMy1 = zhadan(pokelist)
		if not zdMy4 or zdOther4[1] >= zdMy4[1] or #zdMy4 ~= 1 or #zdOther2 ~= #zdMy2 or #zdOther1 ~= zdMy1 then return false end
	
		local m = #zdMy2 + #zdMy1
		if m == 0 then
			return zdMy4[1] == poke_value.p_W and paypoke_type.shuangwang or paypoke_type.zhadan
		elseif m == 2 then
			return paypoke_type.sidaier
		end
    end
	local function is_zhadan()
        local zdMy4, zdMy2, zdMy1 = zhadan(pokelist)
		if zdMy4 and #zdMy4 == 1 then		
			local m = #zdMy2 + #zdMy1
			if m == 0 then
				return zdMy4[1] == poke_value.p_W and paypoke_type.shuangwang or paypoke_type.zhadan
			elseif m == 2 then
				return paypoke_type.sidaier
			end
		end
    end
	

    --顺子
    local function shunzi(pokes)
        local pokesCount = #pokes
        if pokesCount < 5 then
                return nil
        end

        local value = pokes[1].value
        for i=2,pokesCount do
                if pokes[i].value ~= (value + 1) then
                    return nil
                end
                value = value + 1
        end
        return pokes[1].value, pokesCount
    end
    local function check_shunzi()
        local myValue, myCount = shunzi(pokelist)
        local otherValue, otherCount = shunzi(self.lastPokes)

        if otherValue and myValue and myValue > otherValue and myCount == otherCount then
            return paypoke_type.shunzi
        end
    end
	local function is_shunzi()
        local myValue, myCount = shunzi(pokelist)
        if myValue and myCount >= 5 then
            return paypoke_type.shunzi
        end
    end
	
	------------------------------------------------------------------------
	
	if lastPayType == paypoke_type.none then
		local danzhangType = is_danzhang()
		if danzhangType then return danzhangType end
		
		local yiduiType = is_yidui()
		if yiduiType then return yiduiType end
		
		local shuangshunType = is_shuangshun()
		if shuangshunType then return shuangshunType end
		
		local sanzhangType = is_sanzhang()
		if sanzhangType then return sanzhangType end
		
		local zhadanType = is_zhadan()
		if zhadanType then return zhadanType end
		
		local shunziType = is_shunzi()
		if shunziType then return shunziType end
		
	elseif lastPayType == paypoke_type.danzhang then
		return check_danzhang()
	
	elseif lastPayType == paypoke_type.yidui then
		return check_yidui()
	
	elseif lastPayType == paypoke_type.shuangshun then
		return check_shuangshun()
				
	elseif lastPayType == paypoke_type.sandaiyi or lastPayType == paypoke_type.sanzhang or lastPayType == paypoke_type.sanshun or lastPayType == paypoke_type.feiji then
		return check_sanzhang()
		
	elseif lastPayType == paypoke_type.zhadan or lastPayType == paypoke_type.shuangwang or lastPayType == paypoke_type.sidaier then
		return check_zhadan()
		
	elseif lastPayType == paypoke_type.shunzi then
		return check_shunzi()
	end
end
return DDZGame