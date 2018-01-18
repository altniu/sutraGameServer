DDZ_Define = {}

DDZ_Define.play_state={
    playWaitReady = 0,--等待准备
    playWaitStart = 1,--等待开始
    playing_dealDZ = 2,--叫地主中
    playing_robDZ = 3,--抢地主中
    playing_play = 4,--游戏中
    playing_dispatchPoke = 5,--发牌中
    gameover = 6,--游戏结束
    setDataUI = 7--更新界面数据
}

DDZ_Define.player_state={
    waitReady = 0,
    waitStart = 1,
    dealDZ = 2,--叫地主中
    robDZ = 3,--抢地主中
    waitChupai = 4,--等待出牌
    chupai = 5,--出牌
    dispatchPoke = 6,--发牌中
    gameover = 7,--游戏结束
}

DDZ_Define.play_MaxCount = 3
DDZ_Define.playerPokeMaxCount = 17
DDZ_Define.PokeMaxCount = 54

DDZ_Define.site = 
{
    leftTop_A = 1,
    rightTop_B = 2,
    centerBottom_C = 3
}

DDZ_Define.pokeGapWidth = 20

------------------------------------------------------
------------------------------------------------------
------------------------------------------------------


poke_value = {
    p_3 = 1,
    P_4 = 2,
    p_5 = 3,
    p_6 = 4,
    p_7 = 5,
    p_8 = 6,
    p_9 = 7,
    p_10 = 8,
    p_J = 9,
    p_Q = 10,
    p_K = 11,
    p_A = 12,
    p_2 = 13,
    p_W = 14,
    p_WW = 15
}

poke_color = {
    meihua = 1,
    fangkuai = 2,
    hongxin = 3,
    heitao = 4,
    wang = 5
}

paypoke_type = {
none = 0,
danzhang = 1,
yidui = 2,
shuangshun = 3,
sanzhang = 4,
zhadan = 5,
shunzi = 6,
shuangwang = 7,
feiji = 8,
sidaier = 9,
sandaiyi = 10,
sanshun = 11,
}