local A=AntiquityAtlas
function A.IsResourceSource(part)
    local info=part and A.SourceInfo[part.id]
    return info and type(info.resources)=="table" and #info.resources>0 or false
end
function A.IsBossSource(part)
    local info=part and A.SourceInfo[part.id]
    return info and info.boss==true and A.LeadInstances[part.id]~=nil or false
end
function A.HasBossTargets(part)
    return A.IsBossSource(part) and type(A.BossTargets)=="function" and #A.BossTargets(part)>0
end
function A.SourceModifierAction(part)
    local info=part and A.SourceInfo[part.id]
    if info and info.resources and A.CanShowResources and A.CanShowResources(part) then return "resources" end
    if A.HasBossTargets(part) then return "boss" end
end
function A.ExpandSourceText(text)
    local ru=A.IsRussian()
    local names=ru and {
        GD="Групповое подземелье", PD="Публичное подземелье", WB="Мировой босс",
        D="Вылазка", T="Испытание", BG="Поле сражений", NPC="Персонаж", IC="Имперский город", JC="Ювелирное дело",
        ["EA/IA"]="Бесконечный архив", ["EA"]="Бесконечный архив", ["IA"]="Бесконечный архив",
    } or {
        GD="Group dungeon", PD="Public dungeon", WB="World boss", D="Delve", T="Trial",
        BG="Battleground", NPC="Non-player character", IC="Imperial City", JC="Jewelry crafting", ["EA/IA"]="Infinite Archive", EA="Infinite Archive", IA="Infinite Archive",
    }
    if text=="(EA/IA) Infinite Archive" then return names.EA end
    text=(text or ""):gsub("%(([^)]+)%)",function(tag) return names[tag] and (names[tag]..":") or ("("..tag..")") end)
    for _, tag in ipairs({"GD","PD","WB","BG","NPC","IC","JC","EA","IA"}) do
        text=text:gsub("%f[%a]"..tag.."%f[%A]",names[tag])
    end
    local directions={
        {"SSE","south-southeast","юго-юго-восток"}, {"N-W","northwest","северо-запад"},
        {"S-W","southwest","юго-запад"}, {"S-E","southeast","юго-восток"}, {"N-E","northeast","северо-восток"},
        {"NW","northwest","северо-запад"}, {"SW","southwest","юго-запад"},
        {"SE","southeast","юго-восток"}, {"NE","northeast","северо-восток"},
    }
    for _, item in ipairs(directions) do text=text:gsub("%f[%a]"..item[1]:gsub("%-","%%-").."%f[%A]",item[ru and 3 or 2]) end
    for tag,full in pairs({N="north",S="south",E="east",W="west"}) do
        text=text:gsub("%f[%a]"..tag.."%f[%A](%s+of)",full.."%1")
    end
    text=text:gsub("%f[%a]Mobs%f[%A]",ru and "Противники" or "Enemies"):gsub("%f[%a]mobs%f[%A]",ru and "противники" or "enemies")
    text=text:gsub("%f[%a]Adds%f[%A]",ru and "Дополнительные противники" or "Additional enemies"):gsub("%f[%a]MIN%f[%A]",ru and "мин." or "minutes")
    return text
end
function A.SourceClickHint(part)
    if A.IsResourceSource(part) then
        return A.SourceLabel("LMB: source locations. RMB: dig region.","ЛКМ: места получения. ПКМ: область раскопок.")
    end
    if A.HasBossTargets(part) then
        return A.SourceLabel("LMB: source bosses. RMB: dig region.", "ЛКМ: боссы источника. ПКМ: регион раскопок.")
    end
    local targets=A.ResolveSourceZones(part)
    if #targets==1 and targets[1].worldBoss then
        return A.SourceLabel("LMB: world boss. RMB: dig region.", "ЛКМ: мировой босс. ПКМ: регион раскопок.")
    end
    if #targets>1 then return A.SourceLabel("LMB: choose source. RMB: dig region.","ЛКМ: выбор источника. ПКМ: область раскопок.") end
    if #targets==1 and not targets[1].region then
        if targets[1].poiIndex or targets[1].node or targets[1].poi then
            return A.SourceLabel("LMB: instance entrance. RMB: dig region.","ЛКМ: вход в подземелье. ПКМ: область раскопок.")
        end
        return A.SourceLabel("LMB: instance map. RMB: dig region.","ЛКМ: карта подземелья. ПКМ: область раскопок.")
    end
    if not part.findZoneId or part.findZoneId==101010 or part.findZoneId==101011 or part.findZoneId==101016 then
        return A.SourceLabel("No single source location. RMB: dig region.","Единого места получения нет. ПКМ: область раскопок.")
    end
    return A.SourceLabel("LMB: source region. RMB: dig region.","ЛКМ: область получения. ПКМ: область раскопок.")
end
