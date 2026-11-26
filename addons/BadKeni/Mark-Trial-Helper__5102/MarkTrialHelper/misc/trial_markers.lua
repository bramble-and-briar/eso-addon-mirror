local AH = _G.MarkTrialHelper
ZO_CreateStringId("SI_BINDING_NAME_MARKTRIALHELPER_ADD_PRIORITY_MOB", "Добавить моба в автометки")
ZO_CreateStringId("SI_BINDING_NAME_MARKTRIALHELPER_DEL_PRIORITY_MOB", "Удалить моба из автометок")

local MARKER_LABELS = { "1 - Квадрат", "2 - Крест", "3 - Звезда", "4 - Полумесяц", "5 - Треугольник", "6 - Круг", "7 - Спираль", "8 - Череп" }
local FALLBACK_ORDER = { 8, 2, 3, 4, 5, 6, 1, 7 }

function AH.GetMarkerDisplay(id)
    local icon = ZO_GetPlatformTargetMarkerIcon and ZO_GetPlatformTargetMarkerIcon(id)
    local label = MARKER_LABELS[id] or tostring(id)
    return icon and (zo_iconFormat(icon, 20, 20) .. " " .. label) or label
end

AH.DEFAULT_TRIAL_MOBS = {
    ["Пламенный заклинатель"] = 8, ["Flamecaller"] = 8, ["Неугасимый"] = 2, ["Unquenchable"] = 2,
    ["Руинах"] = 3, ["Ruinach"] = 3, ["Переливающийся"] = 4, ["Lucent"] = 4,
    ["Граф Райлаз"] = 8, ["Count Ryelaz"] = 8, ["Зорин"] = 8, ["Xoryn"] = 8,
    ["Яндир Мясник"] = 8, ["Yandir the Butcher"] = 8, ["Капитан Врол"] = 8, ["Captain Vrol"] = 8,
    ["Лорд Фалгравн"] = 8, ["Lord Falgravn"] = 8, ["Буревестниц"] = 8, ["Stormweaver"] = 8,
    ["Буревестник"] = 8, ["Полувеликан"] = 4, ["Half-Giant"] = 4, ["Рыцарь крови"] = 2,
    ["Bloodknight"] = 2, ["Насыщатель"] = 3, ["Infuser"] = 3, ["Аптекарь"] = 5,
    ["Apothecary"] = 5, ["Морская гадюка"] = 1, ["Sea Adder"] = 1,
    ["Дремора-инферналист"] = 8, ["Dremora Infernalist"] = 8, ["Вамасу"] = 2, ["Wamasu"] = 2,
    ["Шрапнельный атронах"] = 3, ["Shrapnel Atronach"] = 3, ["Экзарх Ясела"] = 8, ["Exarchanic Yaseyla"] = 8,
    ["Архимаг Твильвик"] = 8, ["Archwizard Twelvane"] = 8, ["Ансуул"] = 8, ["Ansuul"] = 8,
    ["Волнолом"] = 8, ["Tidebreaker"] = 8, ["Пиромант"] = 2, ["Pyromancer"] = 2,
    ["Криомант"] = 3, ["Cryomancer"] = 3, ["Маг-громовержец"] = 4, ["Stormcaster"] = 4,
    ["Рифовый страж"] = 8, ["Reef Guardian"] = 8, ["Талерия"] = 8, ["Taleria"] = 8,
    ["Сул-Зан"] = 8, ["Sul-Xan"] = 8, ["Бегемот"] = 2, ["Behemoth"] = 2,
    ["Разрушитель"] = 3, ["Havocrel"] = 3, ["Жнец душ"] = 4, ["Soulweaver"] = 4,
    ["Оаксильцо"] = 8, ["Oaxiltso"] = 8, ["Басей"] = 8, ["Bahsei"] = 8, ["Залвакка"] = 8, ["Xalvakka"] = 8,
    ["Укротитель огня"] = 8, ["Fire-Tamer"] = 8, ["Вельва"] = 2, ["Welwa"] = 2,
    ["Локкестиз"] = 8, ["Lokkestiiz"] = 8, ["Йольнакрин"] = 8, ["Yolnahkriin"] = 8, ["Навинтас"] = 8, ["Nahviintaas"] = 8,
    ["Зарма"] = 8, ["Z'Maja"] = 8, ["Грозовой атронах"] = 2, ["Storm Atronach"] = 2,
    ["Ползун"] = 3, ["Creeper"] = 3, ["Иагра"] = 4, ["Yaghra"] = 4,
    ["Сфера-разрушитель"] = 8, ["Factotum"] = 8, ["Динамо-сфера"] = 2, ["Ruined Factotum"] = 2,
    ["Сборочный генерал"] = 8, ["Assembly General"] = 8, ["Дро-м'Атра-палач"] = 8, ["Dro-m'Athra"] = 8,
    ["Котолюд-тенелом"] = 2, ["Shadowguard"] = 2, ["Раккат"] = 8, ["Rakkhat"] = 8,
    ["Призывательниц"] = 8, ["Conjurer"] = 8, ["Горгулья"] = 2, ["Gargoyle"] = 2,
    ["Тролль"] = 3, ["Troll"] = 3, ["Мантикора"] = 8, ["Manticora"] = 8,
    ["Каменный рыцарь"] = 8, ["Stone Knight"] = 8, ["Алхимик"] = 2, ["Alchemist"] = 2,
    ["Некромант"] = 8, ["Necromancer"] = 8, ["Кровавый рыцарь"] = 2, ["Blood Knight"] = 2,
    ["Маг-осквернитель"] = 8, ["Defiler"] = 8, ["Костяной колосс"] = 8, ["Bone Colossus"] = 8,
    ["Призыватель"] = 8, ["Summoner"] = 8, ["Палач"] = 8, ["Executioner"] = 8,
}

local resolvedCache, activeCombatMarks, lastHostileName = {}, {}, nil
function AH.ClearMarkerCache() resolvedCache = {} end

function AH.LoadDefaultTrialMobs(overwrite)
    if not AH.Vars then return 0 end
    AH.Vars.CustomMarkers = AH.Vars.CustomMarkers or {}
    local added = 0
    for mobName, id in pairs(AH.DEFAULT_TRIAL_MOBS) do
        if overwrite or AH.Vars.CustomMarkers[mobName] == nil then
            AH.Vars.CustomMarkers[mobName] = id
            added = added + 1
        end
    end
    AH.Vars.PresetV6Loaded = true
    AH.ClearMarkerCache()
    return added
end

local function UpdateLastHostile()
    local tag = DoesUnitExist("reticleover") and "reticleover" or (DoesUnitExist("reticleovertarget") and "reticleovertarget" or nil)
    if tag and not IsUnitPlayer(tag) and IsUnitAttackable(tag) and GetUnitReaction(tag) == UNIT_REACTION_HOSTILE and not IsUnitDead(tag) then
        local raw = GetRawUnitName(tag)
        if not raw or raw == "" then raw = GetUnitName(tag) end
        if raw and raw ~= "" then lastHostileName = zo_strformat("<<1>>", raw) end
    end
end

local function GetCleanTargetName()
    UpdateLastHostile()
    local tag = DoesUnitExist("reticleover") and "reticleover" or (DoesUnitExist("reticleovertarget") and "reticleovertarget" or nil)
    if tag then
        local raw = GetRawUnitName(tag)
        if not raw or raw == "" then raw = GetUnitName(tag) end
        if raw and raw ~= "" then return zo_strformat("<<1>>", raw), tag end
    end
    return lastHostileName, nil
end

local function ResolveMarkerId(rawName)
    local cached = resolvedCache[rawName]
    if cached ~= nil then return cached or nil end
    local clean = zo_strformat("<<1>>", rawName)
    local id = AH.Vars.CustomMarkers[clean]
    if not id then
        local lower = zo_strlower(clean)
        for key, val in pairs(AH.Vars.CustomMarkers) do
            if lower:find(zo_strlower(key), 1, true) then id = val break end
        end
    end
    resolvedCache[rawName] = id or false
    return id
end

local function PickNonJumpingMarker(preferredId)
    local now = GetGameTimeMilliseconds()
    if not activeCombatMarks[preferredId] or (now - activeCombatMarks[preferredId]) > 12000 then
        activeCombatMarks[preferredId] = now
        return preferredId
    end
    for _, altId in ipairs(FALLBACK_ORDER) do
        if not activeCombatMarks[altId] or (now - activeCombatMarks[altId]) > 12000 then
            activeCombatMarks[altId] = now
            return altId
        end
    end
    activeCombatMarks[preferredId] = now
    return preferredId
end

function AH.AddPriorityMob(markerId, customName)
    if not AH.Vars then return end
    AH.Vars.CustomMarkers = AH.Vars.CustomMarkers or {}
    local name, tag = customName, nil
    if not name or name == "" then name, tag = GetCleanTargetName() end
    if not name or name == "" then d("|cff9900[Mark Trial Helper]|r Наведите прицел или выделите моба через Tab!") return end
    local id = tonumber(markerId) or AH.Vars.DefaultTrialMarker or 8
    if id < 1 or id > 8 then id = 8 end
    AH.Vars.CustomMarkers[name] = id
    AH.ClearMarkerCache()
    if tag == "reticleover" and GetUnitTargetMarkerType("reticleover") ~= id then AssignTargetMarkerToReticleTarget(id) end
    d(string.format("|cff9900[Mark Trial Helper]|r Добавлен: |c00ff00%s|r -> %s", name, AH.GetMarkerDisplay(id)))
end

function AH.RemovePriorityMob()
    if not AH.Vars or not AH.Vars.CustomMarkers then return end
    local name, tag = GetCleanTargetName()
    if not name then d("|cff9900[Mark Trial Helper]|r Наведите прицел или выделите моба через Tab!") return end
    if AH.Vars.CustomMarkers[name] then
        AH.Vars.CustomMarkers[name] = nil
        AH.ClearMarkerCache()
        if tag == "reticleover" then
            local cur = GetUnitTargetMarkerType("reticleover")
            if cur ~= TARGET_MARKER_TYPE_NONE then AssignTargetMarkerToReticleTarget(cur) end
        end
        d(string.format("|cff9900[Mark Trial Helper]|r Удалён: |cffff55%s|r", name))
    end
end

function AH.GetPriorityMobsText()
    if not AH.Vars or not AH.Vars.CustomMarkers then return "Список пуст." end
    local lines = {}
    for mobName, id in pairs(AH.Vars.CustomMarkers) do
        table.insert(lines, string.format("• %s — %s", mobName, AH.GetMarkerDisplay(id)))
    end
    table.sort(lines)
    return #lines > 0 and table.concat(lines, "\n") or "Список пуст."
end

function AH.ListPriorityMobs()
    d("|cff9900[Mark Trial Helper]|r Список автометок:\n" .. AH.GetPriorityMobsText())
end

local function TryMarkReticle()
    if IsInstanceEndlessDungeon() then return end
    UpdateLastHostile()
    if not AH.Vars then return end
    if not AH.Vars.PresetV6Loaded then AH.LoadDefaultTrialMobs(true) end
    if AH.Vars.EnableTrialMarkers == false or not AH.Vars.CustomMarkers then return end
    if GetGroupSize() > 0 and not IsUnitGroupLeader("player") then return end
    if not DoesUnitExist("reticleover") or IsUnitPlayer("reticleover") or not IsUnitAttackable("reticleover") or GetUnitReaction("reticleover") ~= UNIT_REACTION_HOSTILE then return end
    local existing = GetUnitTargetMarkerType("reticleover")
    if IsUnitDead("reticleover") then
        if existing ~= TARGET_MARKER_TYPE_NONE then activeCombatMarks[existing] = nil end
        return
    end
    if existing ~= TARGET_MARKER_TYPE_NONE then activeCombatMarks[existing] = GetGameTimeMilliseconds() return end
    local raw = GetRawUnitName("reticleover")
    if not raw or raw == "" then return end
    local preferredId = ResolveMarkerId(raw)
    if preferredId then AssignTargetMarkerToReticleTarget(PickNonJumpingMarker(preferredId)) end
end

local function OnCombatStateChanged(_, inCombat)
    activeCombatMarks = {}
    if inCombat then
        TryMarkReticle()
        EVENT_MANAGER:RegisterForUpdate(AH.Name .. "_FastReticle", 80, TryMarkReticle)
    else
        EVENT_MANAGER:UnregisterForUpdate(AH.Name .. "_FastReticle")
    end
end

EVENT_MANAGER:RegisterForEvent(AH.Name .. "_TrialMarkers", EVENT_RETICLE_TARGET_CHANGED, TryMarkReticle)
EVENT_MANAGER:RegisterForEvent(AH.Name .. "_TrialCombat", EVENT_PLAYER_COMBAT_STATE_CHANGED, OnCombatStateChanged)
SLASH_COMMANDS["/madd"]  = function(arg) AH.AddPriorityMob(arg) end
SLASH_COMMANDS["/mdel"]  = function() AH.RemovePriorityMob() end
SLASH_COMMANDS["/mlist"] = function() AH.ListPriorityMobs() end
