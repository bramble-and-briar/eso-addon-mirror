-- Ramaladni effect lookup: search is independent of the UI and combat tracker.
-- The installed U52 group data is authored by the Ramaladni project.
-- No online requests, external libraries or dynamic ability-ID discovery.
RamaladniEffectSearch = {}
local S = RamaladniEffectSearch

-- Search synonyms only: never shown as ID labels and never used to merge unrelated effects.
-- Hemorrhaging (bleed status) differs from the Nightblade Hemorrhage passive.
local ALIASES={
  buff={
    ["Minor Berserk"]="Малое неистовство Малая ярость",
    ["Major Berserk"]="Великое неистовство Великая ярость",
    ["Gallop"]="Великий галоп Езда Mounted Speed",
    ["Empower"]="Усиление Силовые атаки Heavy Attacks",
    ["Minor Savagery"]="Кровоизлияние Hemorrhage Ночной клинок",
  },
  debuff={
    ["Hemorrhaging"]="Кровоизлияние Кровотечение Hemorrhage Bleeding",
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

-- All entries are real ID matches from the U52 group dictionary, verified
-- special effects, or effects the game has actually reported to the player.
function S.Build(kind,groups,ru,verified,presets,learned,observed)
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

  local function AddSingle(id,name,aliases)
    id=tonumber(id)
    if not id or id<1 or catalog.byId[id] then return end
    local english=(name or ''):match('/%s*(.+)$') or name or ''
    local russian=(name or ''):match('^(.-)%s*/') or name or ''
    if english:match('^ID%s+%d+$') then english='';russian='' end
    if english=='' and type(GetAbilityName)=='function' then english=GetAbilityName(id) or '' end
    if russian=='' then russian=english end
    if english=='' then english='Неизвестный эффект';russian=english end
    local members={id}
    if type(aliases)=='table' then
      for _,extra in ipairs(aliases) do
        if extra~=id and not catalog.byId[extra] then members[#members+1]=extra end
      end
    end
    local display=(russian==english) and russian or (russian..' / '..english)
    Put(catalog,kind,{id=id,ids=members,en=english,ru=russian,title=display})
  end

  for _,preset in ipairs(presets or {}) do AddSingle(preset.id,preset.name,preset.aliases) end
  for en,id in pairs(verified or {}) do
    AddSingle(id,(ru[en] or en)..' / '..en)
  end
  -- Save the language reported by ESO as one more searchable alias, without
  -- pretending a translation is known for unclassified, player-seen skills.
  for _,source in ipairs({learned or {},observed or {}}) do
    for id,info in pairs(source) do
      if type(info)=='table' then AddSingle(id,info.name) end
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
  end
  for _,entry in ipairs(catalog.list) do
    if entry.normalized:find(query,1,true) then
      found[#found+1]=entry
      if #found>=(limit or 6) then break end
    end
  end
  return found
end
