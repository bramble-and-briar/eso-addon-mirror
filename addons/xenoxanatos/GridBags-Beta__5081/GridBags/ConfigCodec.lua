-- Length-prefixed data, hex transport and a checksum. Import never executes Lua.
GridBagsConfig = {}
local C = GridBagsConfig
local function Whole(n)
    n = tonumber(n)
    if n and n >= 0 and n <= 9007199254740991 and n == math.floor(n) then return n end
end
local function Text(s, maximum)
    return type(s) == "string" and #s > 0 and #s <= maximum and not s:find("[%c]")
end
local function Checksum(s)
    local a,b=1,0
    for i=1,#s do a=(a+s:byte(i))%65521;b=(b+a)%65521 end
    return b*65536+a
end

function C:Encode(value)
    local nodes=0
    local function Write(v,depth)
        nodes=nodes+1;if nodes>20000 or depth>12 then error("Configuration exceeds export limits") end
        if type(v)=="boolean" then return v and "B1" or "B0"
        elseif type(v)=="number" then
            if v~=v or math.abs(v)>9007199254740991 then error("Invalid configuration number") end
            return "N"..string.format("%.17g",v)..";"
        elseif type(v)=="string" then
            if #v>4096 then error("Configuration string too long") end
            return "S"..#v..":"..v
        elseif type(v)=="table" then
            local keys={};for k in pairs(v) do
                if type(k)~="string" and type(k)~="number" then error("Invalid configuration key") end
                keys[#keys+1]=k
            end
            table.sort(keys,function(a,b)if type(a)~=type(b)then return type(a)<type(b)end;return a<b end)
            local parts={"T"..#keys..":"}
            for _,k in ipairs(keys)do parts[#parts+1]=Write(k,depth+1);parts[#parts+1]=Write(v[k],depth+1)end
            return table.concat(parts)
        end
        error("Unsupported configuration value")
    end
    local ok,raw=pcall(Write,value,0)
    if not ok then return nil,tostring(raw) end
    if #raw>90000 then return nil,"Configuration is too large to export in one text block." end
    local hex=raw:gsub(".",function(ch)return string.format("%02x",ch:byte())end)
    return "GB1:"..hex..":"..string.format("%.0f",Checksum(raw))
end

function C:Decode(input)
    if type(input)~="string" or #input>200000 then return nil,"Import text is missing or too large." end
    local text=input:gsub("%s","")
    local hex,sum=text:match("^GB1:([0-9a-fA-F]+):(%d+)$")
    if not hex or #hex%2~=0 or #hex>180000 then return nil,"Not a supported GridBags configuration export." end
    local raw=hex:gsub("..",function(pair)return string.char(tonumber(pair,16))end)
    if Checksum(raw)~=tonumber(sum)then return nil,"Configuration checksum failed; copy the complete export again." end
    local pos,nodes=1,0
    local function Count()
        local first,last=raw:find("%d+:",pos)
        if first~=pos then error("Invalid length")end
        local n=tonumber(raw:sub(first,last-1));pos=last+1
        if not n or n>20000 then error("Length exceeds limit")end
        return n
    end
    local function Read(depth)
        nodes=nodes+1;if nodes>20000 or depth>12 then error("Configuration nesting exceeds limit")end
        local tag=raw:sub(pos,pos);pos=pos+1
        if tag=="B" then local v=raw:sub(pos,pos);pos=pos+1;if v~="0" and v~="1"then error("Bad boolean")end;return v=="1"
        elseif tag=="N"then
            local last=raw:find(";",pos,true);if not last or last-pos>40 then error("Bad number")end
            local n=tonumber(raw:sub(pos,last-1));pos=last+1
            if not n or n~=n or math.abs(n)>9007199254740991 then error("Invalid number")end
            return n
        elseif tag=="S"then
            local n=Count();if n>4096 or pos+n-1>#raw then error("Bad string length")end
            local s=raw:sub(pos,pos+n-1);pos=pos+n;return s
        elseif tag=="T"then
            local n=Count();local result={}
            for _=1,n do
                local k=Read(depth+1)
                if type(k)~="string" and type(k)~="number"then error("Bad key")end
                if result[k]~=nil then error("Duplicate key")end
                result[k]=Read(depth+1)
            end
            return result
        end
        error("Unknown data tag")
    end
    local ok,value=pcall(Read,0)
    if not ok or pos~=#raw+1 then return nil,"Malformed configuration data; nothing imported." end
    if type(value)~="table" or value.schema~=1 then return nil,"Unsupported configuration schema." end
    return value
end

function C:Mappings(payload)
    local map={}
    if type(payload.characters)~="table"then return map end
    if payload.world==GetWorldName()then
        for id in pairs(payload.characters)do
            if id==GetCurrentCharacterId()or GridBagsSnapshots.records[id]then map[id]=id end
        end
    end
    return map
end

function C:Prepare(payload,mappings)
    local R,Gold=GridBagsRouting,GridBagsGold
    local ok,result=pcall(function()
        if type(payload)~="table"or payload.schema~=1 or not Text(payload.world,100)then error("Unsupported configuration")end
        for _,key in ipairs({"characters","rules","roles","protections","gold","view"})do if type(payload[key])~="table"then error("Missing configuration section: "..key)end end
        local used={}
        for id,name in pairs(payload.characters)do
            if not Text(id,100)or not Text(name,200)then error("Invalid character definition")end
            local target=mappings[id]
            if target~="@skip"then
                if not target or (target~=R.character and not GridBagsSnapshots.records[target])then error("Map or skip every imported character first")end
                if used[target]then error("Map each imported character to a different character, or skip it")end
                used[target]=true
            end
        end
        local function Map(id,bank,learners)
            if bank and not learners and id==R.ANY then return id end
            if bank and id==R.BANK then return id end
            if learners and id=="@learners"then return id end
            if learners and id=="@best-crafter"then return id end
            if not payload.characters[id]then error("Unknown source/destination character")end
            local target=mappings[id];if target=="@skip"then return nil end;return target
        end
        local p={rules={},roles={},protections={},gold={},view={},skipped=0}
        if not Whole(payload.bankReserve)then error("Invalid bank reserve")end;p.bankReserve=Whole(payload.bankReserve)
        local ruleCount=0
        for key in pairs(payload.rules)do ruleCount=ruleCount+1;if type(key)~="number"or key<1 or key~=math.floor(key)then error("Invalid rule list")end end
        if ruleCount>500 or ruleCount~=#payload.rules then error("Rule list exceeds limits or has gaps")end
        for _,original in ipairs(payload.rules)do
            if type(original)~="table"or not Text(original.link,4096)or not Text(original.name,1024)or not Whole(original.maxStack)or original.maxStack<1 then error("Invalid item rule")end
            local spec=GridBagsTransferTools:Clone(original)
            spec.source=Map(original.source,true,false);spec.dest=Map(original.dest,true,true)
            if not spec.source or not spec.dest then p.skipped=p.skipped+1
            else
                if spec.smart then
                    if type(spec.smart)~="table"or (spec.smart.kind~="recipe"and spec.smart.kind~="research"and spec.smart.kind~="craft"and spec.smart.kind~="materials"and spec.smart.kind~="deconstruct")then error("Unsupported smart condition")end
                    if spec.smart.kind=="deconstruct"and not ({[1]=true,[2]=true,[3]=true,[6]=true,[7]=true})[spec.smart.craft]then error("Invalid deconstruction profession")end
                    if spec.smart.profileResearch~=nil and (spec.smart.kind~="research"or spec.smart.profileResearch~=true or not ({[1]=true,[2]=true,[6]=true,[7]=true})[spec.smart.craft])then error("Invalid researcher profile condition")end
                    if spec.smart.kind=="materials"and(not Whole(spec.smart.craft)or spec.smart.craft<1 or spec.smart.craft>7 or(spec.smart.scope~="known"and spec.smart.scope~="usable"))then error("Invalid material qualification")end
                    if spec.smart.kind=="craft"and(not Whole(spec.smart.craft)or spec.smart.craft<1 or spec.smart.craft>7 or not Whole(spec.smart.tier)or spec.smart.tier<1 or spec.smart.tier>100)then error("Invalid crafting condition")end
                end
                local rule,err=R:BuildRule(spec);if not rule then error(err)end
                spec.mode="ask";spec.enabled=false;p.rules[#p.rules+1]=spec
            end
        end
        for id,role in pairs(payload.roles)do
            local target=Map(id,false,false)
            if target then
                if type(role)~="table"or not Whole(role.priority or 100)or(role.priority or 100)>10000 then error("Invalid role profile")end
                local copy={priority=role.priority or 100}
                for _,key in ipairs({"crafter","researcher","learner","overflow"})do
                    if role[key]~=nil and type(role[key])~="boolean"then error("Invalid role flag")end;copy[key]=role[key]==true
                end
                if role.crafts ~= nil then
                    if type(role.crafts)~="table" then error("Invalid profession roles") end
                    copy.crafts={}
                    for craft,settings in pairs(role.crafts)do
                        if not Whole(craft)or craft<1 or craft>7 or type(settings)~="table"or not Whole(settings.priority or 100)or(settings.priority or 100)>10000 then error("Invalid profession role")end
                        local entry={priority=settings.priority or 100}
                        for _,key in ipairs({"crafter","researcher","learner"})do
                            if settings[key]~=nil and type(settings[key])~="boolean"then error("Invalid profession role flag")end
                            entry[key]=settings[key]==true
                        end
                        copy.crafts[craft]=entry
                    end
                end
                p.roles[target]=copy
            end
        end
        for id,rules in pairs(payload.protections)do
            local target=Map(id,true,false)
            if target then
                if type(rules)~="table"then error("Invalid protection list")end
                p.protections[target]={}
                for link,guard in pairs(rules)do
                    if not Text(link,4096)or type(guard)~="table"or type(guard.blocked)~="boolean"or not Whole(guard.keep)then error("Invalid source protection")end
                    p.protections[target][link]={blocked=guard.blocked,keep=guard.keep}
                end
            end
        end
        for id,profile in pairs(payload.gold)do
            local target=Map(id,false,false)
            if target then
                local validated,err=Gold:ValidateProfile(profile);if not validated then error(err)end
                validated.mode="ask";validated.enabled=false;p.gold[target]=validated
            end
        end
        local v=payload.view
        if v.columns~=nil then if not Whole(v.columns)or v.columns<6 or v.columns>12 then error("Invalid columns")end;p.view.columns=v.columns end
        if v.size~=nil then if not Whole(v.size)or v.size<36 or v.size>64 then error("Invalid icon size")end;p.view.size=v.size end
        local sorts={name=true,quality=true,type=true,stack=true,slot=true}
        if v.sort~=nil then if not sorts[v.sort]then error("Invalid display sort")end;p.view.sort=v.sort end
        for _,key in ipairs({"showGold","externalFilters","embeddedFilters"})do if v[key]~=nil then if type(v[key])~="boolean"then error("Invalid display flag")end;p.view[key]=v[key]end end
        if v.layouts~=nil then
            if type(v.layouts)~="table"then error("Invalid layouts")end;p.view.layouts={}
            for _,mode in ipairs({"inventory","bank"})do
                local layout=v.layouts[mode]
                if layout then
                    if type(layout)~="table"then error("Invalid layout")end
                    for _,key in ipairs({"x","y"})do if layout[key]~=nil and(type(layout[key])~="number"or layout[key]~=layout[key]or layout[key]<0 or layout[key]>1)then error("Invalid saved position")end end
                    if(layout.x==nil)~=(layout.y==nil)then error("Incomplete saved position")end
                    p.view.layouts[mode]={x=layout.x,y=layout.y,locked=true}
                end
            end
        end
        return p
    end)
    if not ok then return nil,"Import validation failed: "..tostring(result)end
    return result
end

function C:Apply(payload,mappings)
    local R,Gold,A=GridBagsRouting,GridBagsGold,GridBagsActivity
    if R.pending or Gold.pending then return nil,"Wait for the current transfer to settle before restoring configuration."end
    local prepared,err=self:Prepare(payload,mappings)
    if not prepared then return nil,err end
    GridBagsTransferTools:Backup("Before configuration restore/import")
    A:SetPaused(true)
    local ids={};for _,rule in ipairs(R.data.rules)do ids[#ids+1]=rule.id end
    for _,id in ipairs(ids)do R:DeleteRule(id)end
    for _,spec in ipairs(prepared.rules)do
        local rule=assert(R:AddRule(spec));rule.enabled=false
    end
    for id,role in pairs(prepared.roles)do R.data.profiles[id]=role end
    for id,guards in pairs(prepared.protections)do
        for link,guard in pairs(guards)do
            local old=R:Protection(id,link)
            R:SetProtection(id,link,old.blocked or guard.blocked,math.max(old.keep or 0,guard.keep))
        end
    end
    for _,p in pairs(Gold.data.profiles)do p.enabled=false;p.mode="ask";p.revision=(p.revision or 0)+1 end
    for id,p in pairs(prepared.gold)do
        local old=Gold:Profile(id)
        p.min=math.max(old.min or 0,p.min)
        if p.max and p.max<p.min then p.max=p.min end
        p.revision=(old.revision or 0)+1;Gold.data.profiles[id]=p
    end
    Gold.data.bankReserve=math.max(Gold.data.bankReserve or 0,prepared.bankReserve)
    if Gold.data.visit and Gold.data.visit.open then Gold.data.visit.state="changed";Gold.current=nil end
    for key,value in pairs(prepared.view)do GridBags.saved[key]=value end
    A:Append({kind="control",outcome="control",code="CONFIG_IMPORTED",reason="Configuration imported paused; rules disabled/Ask; existing custody and stronger protections preserved"})
    GridBags:Refresh();R:Notify();Gold:Notify()
    return prepared
end
