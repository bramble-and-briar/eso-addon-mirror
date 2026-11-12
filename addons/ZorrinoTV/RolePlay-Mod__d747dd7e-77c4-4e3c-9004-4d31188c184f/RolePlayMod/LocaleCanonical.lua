-- Expand official client placeholders before passing text to the French semantic
-- engine. This never grants evidence or changes the game's own journal text.
local L=RPM_LOCALE
if not L.english then return end
local base=L.Canonical
local buckets,cache={},{}
local function escape(text) return (text:gsub('([%%%^%$%(%)%.%[%]%*%+%-%?])','%%%1')) end
for _,row in ipairs(L.clientTemplates or {}) do
    local en,fr=row[1],row[2]
    local parts,indices={},{};local pos=1;local first
    while true do
        local a,b,index=en:find('<<[%a:]*([0-9]+)>>',pos)
        if not a then parts[#parts+1]=escape(en:sub(pos));break end
        if not first then first=en:sub(1,a-1) end
        parts[#parts+1]=escape(en:sub(pos,a-1));parts[#parts+1]='(.+)'
        indices[#indices+1]=tonumber(index);pos=b+1
    end
    if #indices>0 and first and #first>=2 then
        local key=first:sub(1,8)
        buckets[key]=buckets[key] or {}
        buckets[key][#buckets[key]+1]={pattern='^'..table.concat(parts)..'$',fr=fr,indices=indices,literal=#en-#indices*5}
    end
end
for _,list in pairs(buckets) do table.sort(list,function(a,b) return a.literal>b.literal end) end
local function noun(name,at)
    local marker=(L.grammar or {})[name] or ''
    local article=marker:find('d',1,true) and (marker:sub(1,1)=='f' and 'la ' or marker:sub(1,1)=='p' and 'les ' or 'le ') or ''
    if at=='at' then return article=='le ' and ('au '..name) or article=='les ' and ('aux '..name) or ('à '..article..name) end
    if at=='of' then return article=='le ' and ('du '..name) or article=='les ' and ('des '..name) or ('de '..article..name) end
    return article..name
end
local function fill(fr,values)
    fr=fr:gsub('à un <<[%a:]*([0-9]+)>>',function(i) return noun(values[tonumber(i)] or '', 'at') end)
    fr=fr:gsub("d'un <<[%a:]*([0-9]+)>>",function(i) return noun(values[tonumber(i)] or '', 'of') end)
    fr=fr:gsub('un <<[%a:]*([0-9]+)>>',function(i) return noun(values[tonumber(i)] or '') end)
    return (fr:gsub('<<[%a:]*([0-9]+)>>',function(i) return values[tonumber(i)] or '' end))
end
function L.Canonical(text,questId,depth)
    if type(text)~='string' or text=='' then return text end
    local q=questId and L.referenceByQuest and L.referenceByQuest[tostring(questId)]
    if q and q[text] then return q[text] end
    local plain=base(text)
    if plain~=text or L.reverse[text] then return plain end
    local key=tostring(questId or '')..'\n'..text
    if cache[key] then return cache[key] end
    if (depth or 0)>3 then return plain end
    for size=math.min(8,#text),2,-1 do
        for _,row in ipairs(buckets[text:sub(1,size)] or {}) do
            local captures={text:match(row.pattern)}
            if captures[1] then
                local values={}
                for i,index in ipairs(row.indices) do values[index]=L.Canonical(captures[i],nil,(depth or 0)+1) end
                local result=fill(row.fr,values)
                if not result:find('<<',1,true) then cache[key]=result;return result end
            end
        end
    end
    return plain
end
