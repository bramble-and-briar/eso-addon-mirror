-- Ramaladni effect lookup: search is independent of the UI and combat tracker.
-- The installed U52 group data is authored by the Ramaladni project.
-- No online requests, external libraries or dynamic ability-ID discovery.
local M=RamaladniMastery
local ipairs = ipairs
local math = math
local pairs = pairs
local string = string
local table = table
local tonumber = tonumber
local tostring = tostring
local S = {}
M.EffectSearch = S

-- Search synonyms only: never shown as ID labels and never used to merge unrelated effects.
-- Hemorrhaging (bleed status) differs from the Nightblade Hemorrhage passive.
local ALIASES={
  buff={
    ["Minor Berserk"]="Малое неистовство Малая ярость",
    ["Major Berserk"]="Великое неистовство Великая ярость",
    ["Major Aegis"]="Великий эгид Великая эгида",
    ["Gallop"]="Великий галоп Езда Mounted Speed",
    ["Empower"]="Усиление Силовые атаки Heavy Attacks",
    ["Minor Savagery"]="Кровоизлияние Hemorrhage Ночной клинок",
  },
  debuff={
    ["Hemorrhaging"]="Кровотечение Bleeding",
    ["Concussed"]="Concussion Concussed Сотрясение Контузия",
    ["Chilled"]="Охлаждение Охлаждённый Обморожение",
    ["Diseased"]="Заражение Болезнь",
    ["Sundered"]="Раскол Расколотый",
    ["Overcharged"]="Перегрузка Перезаряд",
    ["Heat Shock"]="Тепловой шок Пошатывание Stagger",
  },
}

-- ESO's Lua 5.1 string.lower only knows ASCII; fold Cyrillic UTF-8 here.
function S.Fold(value)
  local s=tostring(value or ''):lower()
  return (s:gsub('[\208\209][\128-\191]',function(pair)
    local a,b=pair:byte(1,2)
    if a==208 and b==129 then return string.char(209,145) end -- Ё -> ё
    if a==208 and b>=144 and b<=159 then return string.char(208,b+32) end -- А-П
    if a==208 and b>=160 and b<=175 then return string.char(209,b-32) end -- Р-Я
    return pair
  end):gsub('^%s+',''):gsub('%s+$',''))
end

local function Put(catalog,kind,entry)
  if not entry or not entry.id or not entry.title then return end
  local key=entry.groupKey or (kind..':single:'..entry.id)
  if catalog.keys[key] then return end
  entry.key=key
  entry.normalized=S.Fold(entry.title..' '..(entry.en or '')..' '..(entry.ru or '')..' '..((ALIASES[kind] or {})[entry.en] or ''))
  catalog.keys[key]=entry
  catalog.list[#catalog.list+1]=entry
  local ids=entry.ids or {entry.id}
  for _,id in ipairs(ids) do catalog.byId[id]=entry end
end

-- Strict search catalog: only classified U52 groups and verified special presets.
-- Target ownership and GetAbilityName do not establish buff/debuff polarity.
function S.Build(kind,groups,ru,verified,presets)
  local catalog={list={},byId={},keys={}}
  local groupEntries={}
  for key,ids in pairs(groups.groups or {}) do
    if key:sub(1,#kind+1)==kind..':' and #ids>0 then
      local en=groups.Name(key)
      local preferred=verified[en]
      if not (preferred and groups.Contains(key,preferred)) then preferred=ids[1] end
      local russian=ru[en] or en
      groupEntries[#groupEntries+1]={id=preferred,ids=ids,groupKey=key,
        en=en,ru=russian,title=russian..' / '..en}
    end
  end
  table.sort(groupEntries,function(a,b) return a.en<b.en end)
  for _,entry in ipairs(groupEntries) do Put(catalog,kind,entry) end

  -- Group presets are already represented by the full group above. The remaining
  -- presets are the four explicitly classified special debuffs.
  for _,preset in ipairs(presets or {}) do
    local id=preset.id
    if not catalog.byId[id] then
      local english=preset.name:match('/%s*(.+)$')
      local russian=ru[english] or preset.name:match('^(.-)%s*/')
      local members={id}
      for _,extra in ipairs(preset.aliases or {}) do
        if extra~=id and not catalog.byId[extra] then members[#members+1]=extra end
      end
      Put(catalog,kind,{id=id,ids=members,en=english,ru=russian,title=russian..' / '..english})
    end
  end
  table.sort(catalog.list,function(a,b) return a.normalized<b.normalized end)
  return catalog
end

function S.Match(catalog,text,limit)
  local query=S.Fold(text)
  local found={}
  if query=='' then return found end
  local num=tonumber(query)
  if num and num>0 and num==math.floor(num) then
    local exact=catalog.byId[num]
    if exact then return {exact} end
    return found -- no unclassified numeric-ID fallback
  end
  for _,entry in ipairs(catalog.list) do
    if entry.normalized:find(query,1,true) then
      found[#found+1]=entry
      if #found>=(limit or 6) then break end
    end
  end
  return found
end
