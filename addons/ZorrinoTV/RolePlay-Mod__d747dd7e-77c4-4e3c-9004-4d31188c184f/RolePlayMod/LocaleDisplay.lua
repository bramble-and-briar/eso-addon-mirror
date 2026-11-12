-- Translation is restricted to this addon's controls and messages.
local L=RPM_LOCALE
if not L.english then return end
local cache,cacheSize={},0
local buckets,templates={},{}
local function word(byte) return byte and (byte>=128 or byte>=65 and byte<=90 or byte>=97 and byte<=122 or byte>=48 and byte<=57 or byte==95) end
local function add(source,target)
    if source==target or #source<2 then return end
    local key=source:sub(1,8)
    buckets[key]=buckets[key] or {}
    buckets[key][#buckets[key]+1]={source=source,value=target}
end
local function escape(s) return (s:gsub('([%%%^%$%(%)%.%[%]%*%+%-%?])','%%%1')) end
local function template(source,target)
    if not source:find('%%') and not source:find('{name}',1,true) then return end
    local chunks,types={},{};local pos=1
    while pos<=#source do
        local a,b,spec=source:find('(%%[-+0 #]*%d*%.?%d*[cdeEfgGiouqsxX%%])',pos)
        local na,nb=source:find('{name}',pos,true)
        if na and (not a or na<a) then a,b,spec=na,nb,'name' end
        if not a then chunks[#chunks+1]=escape(source:sub(pos));break end
        chunks[#chunks+1]=escape(source:sub(pos,a-1))
        if spec=='%%' then chunks[#chunks+1]='%%'
        else
            types[#types+1]=spec
            chunks[#chunks+1]=(spec=='name' or spec:sub(-1)=='s') and '(.-)' or '([%+%-]?[%d%.]+)'
            if spec=='name' then chunks[#chunks]='(.-)' end
        end
        pos=b+1
    end
    if #types>0 then templates[#templates+1]={pattern='^'..table.concat(chunks)..'$',target=target,types=types,length=#source} end
end
for source,target in pairs(L.names) do if not L.authored[source] then add(source,target) end end
for source,target in pairs(L.authored) do add(source,target);template(source,target) end
table.sort(templates,function(a,b) return a.length>b.length end)
for _,bucket in pairs(buckets) do table.sort(bucket,function(a,b) return #a.source>#b.source end) end
local function replace(text)
    local out={};local i=1
    while i<=#text do
        local best,stop,bestLength
        for size=math.min(8,#text-i+1),2,-1 do
            local candidates=buckets[text:sub(i,i+size-1)]
            for _,entry in ipairs(candidates or {}) do
                local n=#entry.source
                if (not bestLength or n>bestLength) and text:sub(i,i+n-1)==entry.source
                    and (not word(text:byte(i)) or not word(text:byte(i-1)))
                    and (not word(text:byte(i+n-1)) or not word(text:byte(i+n))) then
                    best=entry.value;stop=i+n;bestLength=n;break
                end
            end
        end
        if best then out[#out+1]=best;i=stop else out[#out+1]=text:sub(i,i);i=i+1 end
    end
    return table.concat(out)
end
local function translate(text,depth)
    if type(text)~='string' or text=='' then return text end
    local exact=(L.dynamic and L.dynamic[text]) or L.authored[text] or L.forward[text]
    if exact then return exact end
    for source,target in pairs(L.dynamic or {}) do
        if #source>3 and text:sub(1,#source)==source and text:sub(#source+1):find('^[ %[%·]') then
            return target..L.Text(text:sub(#source+1))
        end
    end
    if cache[text] then return cache[text] end
    local result
    if (depth or 0)<4 then
        for _,entry in ipairs(templates) do
            local captures={text:match(entry.pattern)}
            if captures[1]~=nil then
                local args={};local name
                for i,spec in ipairs(entry.types) do
                    if spec=='name' then name=translate(captures[i],(depth or 0)+1)
                    elseif spec:sub(-1)=='s' or spec:sub(-1)=='q' then args[#args+1]=translate(captures[i],(depth or 0)+1)
                    else args[#args+1]=tonumber(captures[i]) or 0 end
                end
                local target=entry.target
                if name then target=target:gsub('{name}',function() return name end) end
                local ok,value=pcall(string.format,target,unpack(args))
                if ok then result=value;break end
            end
        end
    end
    result=result or replace(text)
    -- French articles around dynamic names are consumed by the phrase table.
    result=result:gsub('«%s*','“'):gsub('%s*»','”'):gsub(' %?','?'):gsub(' !','!'):gsub(' :',':')
    if cacheSize>2048 then cache={};cacheSize=0 end
    cache[text]=result;cacheSize=cacheSize+1
    return result
end
L.Text=translate
local owned=setmetatable({}, {__mode='k'})
local function ownName(name)
    return type(name)=='string' and (name:find('^RPM') or name:find('^RPN') or name:find('^IHR') or name:find('^IHeardARumor') or name:find('^RolePlayMod') or name:find('^RolePlayNeeds') or name:find('^MyFakeRadial'))
end
function L.Adopt(control,parent,name)
    if not control or owned[control] or not (owned[parent] or ownName(name)) then return control end
    owned[control]=true
    if type(control.SetText)=='function' then
        local set=control.SetText
        control.SetText=function(self,text,...) return set(self,L.Text(text),...) end
        if type(control.GetText)=='function' then local text=control:GetText();if text and text~='' then control:SetText(text) end end
    end
    if type(control.GetNumChildren)=='function' and type(control.GetChild)=='function' then
        for i=1,control:GetNumChildren() do L.Adopt(control:GetChild(i),control) end
    end
    return control
end
-- Keep the native manager and its methods untouched. Only addon chunks using
-- L.environment see this view; native UI and other addons never enter our code.
local nativeManager=WINDOW_MANAGER
local manager=setmetatable({}, {__index=function(self,key)
    local original=nativeManager[key]
    if type(original)~='function' then return original end
    local fn
    if key=='CreateTopLevelWindow' or key=='CreateControl' or key=='CreateControlFromVirtual' then
        fn=function(_,name,parent,...)
            return L.Adopt(original(nativeManager,name,parent,...),parent,name)
        end
    else fn=function(_,...) return original(nativeManager,...) end end
    rawset(self,key,fn)
    return fn
end})
function L.Metadata(data)
    if type(data)~='table' then return data end
    for _,key in ipairs({'name','displayName','text','tooltip','warning','description'}) do
        local v=data[key]
        if type(v)=='string' then data[key]=L.Text(v)
        elseif type(v)=='function' then local fn=v;data[key]=function(...) return L.Text(fn(...)) end end
    end
    -- choicesValues carry stable identifiers; display labels alone are translated.
    if data.choices and data.choicesValues then for i,v in ipairs(data.choices) do data.choices[i]=L.Text(v) end end
    for _,child in ipairs(data.controls or data) do if type(child)=='table' then L.Metadata(child) end end
    return data
end
local function message(fn,position)
    return function(...)
        local args={n=select('#',...),...};args[position]=L.Text(args[position])
        return fn(unpack(args,1,args.n))
    end
end
local lookup=getmetatable(L.environment).__index
getmetatable(L.environment).__index=function(env,key)
    if key=='WINDOW_MANAGER' then return manager end
    local fn=lookup(env,key)
    if type(fn)=='function' then
        if key=='d' then return message(fn,1)
        elseif key=='ZO_Alert' then return message(fn,3)
        elseif key=='ZO_CreateStringId' then return message(fn,2) end
    end
    return fn
end
