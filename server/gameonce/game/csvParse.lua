csvParse = csvParse or {}
  
-- 去掉字符串左空白  
local function trim_left(s)  
    return string.gsub(s, "^%s+", "");  
end  
  
  
-- 去掉字符串右空白  
local function trim_right(s)  
    return string.gsub(s, "%s+$", "");  
end  
  
-- 解析一行  
local function parseline(line)  
    local ret = {};  
  
    local s = line .. ",";  -- 添加逗号,保证能得到最后一个字段  
  
    while (s ~= "") do  
        --print(0,s);  
        local v = "";  
        local tl = true;  
        local tr = true;  
  
        while(s ~= "" and string.find(s, "^,") == nil) do  
            --print(1,s);  
            if(string.find(s, "^\"")) then  
                local _,_,vx,vz = string.find(s, "^\"(.-)\"(.*)");  
                --print(2,vx,vz);  
                if(vx == nil) then  
                    return nil;  -- 不完整的一行  
                end  
  
                -- 引号开头的不去空白  
                if(v == "") then  
                    tl = false;  
                end  
  
                v = v..vx;  
                s = vz;  
  
                --print(3,v,s);  
  
                while(string.find(s, "^\"")) do  
                    local _,_,vx,vz = string.find(s, "^\"(.-)\"(.*)");  
                    --print(4,vx,vz);  
                    if(vx == nil) then  
                        return nil;  
                    end  
  
                    v = v.."\""..vx;  
                    s = vz;  
                    --print(5,v,s);  
                end  
  
                tr = true;  
            else  
                local _,_,vx,vz = string.find(s, "^(.-)([,\"].*)");  
                --print(6,vx,vz);  
                if(vx~=nil) then  
                    v = v..vx;  
                    s = vz;  
                else  
                    v = v..s;  
                    s = "";  
                end  
                --print(7,v,s);  
  
                tr = false;  
            end  
        end  
  
		
        if(tl) then v = trim_left(v); end  
        if(tr) then v = trim_right(v); end  
		
        ret[table.getn(ret)+1] = v;  
        --print(8,"ret["..table.getn(ret).."]=".."\""..v.."\"");  
  
        if(string.find(s, "^,")) then  
            s = string.gsub(s,"^,", "");  
        end  
  
    end  
  
    return ret;  
end  
  
  
  
--解析csv文件的每一行  
local function getRowContent(file)  
    local content;  
  
    local check = false  
    local count = 0  
    while true do  
        local t = file:read()  
        if not t then  if count==0 then check = true end  break end  
        
        if not content then  
            content = t  
        else  
            content = content..t  
        end  
  
        local i = 1  
        while true do  
            local index = string.find(t, "\"", i)  
            if not index then break end  
            i = index + 1  
            count = count + 1  
        end  
  
        if count % 2 == 0 then check = true break end  
    end  
  
    if not check then  assert(1~=1) end  
    return content  
end  
  
 function split(input, delimiter)
    if not input or input == "" then
        return {}
    end
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter=='') then return false end
    local pos,arr = 0, {}
    -- for each divider found
    for st,sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end 
  
--解析csv文件  
function csvParse.LoadCsv(fileName)  
    
    local sourcePath = fileName

    local targetPlatform = cc.Application:getInstance():getTargetPlatform()
    if (cc.PLATFORM_OS_WINDOWS == targetPlatform) then
        --sourcePath = "../../res/" .. datapath
        --sourcePath = "res/" .. datapath
    elseif (cc.PLATFORM_OS_IPHONE == targetPlatform) or (cc.PLATFORM_OS_IPAD == targetPlatform) or (cc.PLATFORM_OS_ANDROID == targetPlatform)  then
       
       --sourcePath = cc.FileUtils:getInstance():getWritablePath() .. sourcePath
       --Game:initDataBase("res",Constant.DB_NAME)
    end
    print("读取csv文件："..sourcePath)

    local sourcePath = cc.FileUtils:getInstance():getStringFromFile(sourcePath)
    local xx = string.split(sourcePath, "\n")
    
    local  header = parseline(xx[1])
    local ret = {}
  
    local headerCount = #header
    for i=2,#xx do
        local data = {}
        local lineInfo = parseline(xx[i])
        for j=1,headerCount-1 do
            data[header[j]] = lineInfo[j]
        end
        ret[table.getn(ret)+1] = data
    end
    return ret  
end

function csvParse.LoadMusicRhythm(fileName)
	local f = io.open(fileName, "r")
	if not f then
		assert(false, "cant find file " .. fileName)
	end
    local sourcePath = f.read("*")
	log("sourcePath", sourcePath)
    local xx = split(sourcePath, "\n")
    
    local ids = parseline(xx[1])
    local ret = {}
	for i=1, #ids do ret[i] = {} end

	for i=1, #ids do
		ret[i].id = ids[i]
	end
	
	local songNames = parseline(xx[2])	
	for i=1, #songNames do
		ret[i].songName = songNames[i]
	end

	local songIds = parseline(xx[3])
	for i=1, #songIds do
		ret[i].songId = songIds[i]
	end
	
	local buddhaIds = parseline(xx[4])
	for i=1, #buddhaIds do
		ret[i].buddhaId = buddhaIds[i]
	end
	
	local jingtuIds = parseline(xx[5])
	for i=1, #jingtuIds do
		ret[i].jingtuId = jingtuIds[i]
	end
	
	local fojus = parseline(xx[6])
	for i=1, #fojus do
		ret[i].foju = tonumber(fojus[i])
	end
	
	local songTimes = parseline(xx[7])
	for i=1, #songTimes do
		ret[i].songTime = tonumber(songTimes[i])
	end
	
	local clickEffects = parseline(xx[8])
	for i=1, #clickEffects do
		ret[i].clickEffect = clickEffects[i]
	end
	
    for i=9,#xx do
        local lineInfo = parseline(xx[i])
		
		for j=1, #lineInfo do
			if not ret[j].rhythm then ret[j].rhythm = {} end
			if lineInfo[j] ~= "" then
				ret[j].rhythm[#ret[j].rhythm+1] = tonumber(lineInfo[j])
			end
		end
    end

	local res = {}
	for k,v in pairs(ret) do
		res[v.id] = v
	end
    return res
end

return csvParse