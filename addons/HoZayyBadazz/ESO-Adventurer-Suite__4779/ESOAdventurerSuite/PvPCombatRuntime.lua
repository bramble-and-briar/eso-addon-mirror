-- ESO Adventurer Suite
-- PvP Combat Runtime
-- Role-neutral combat awareness, group status, encounter history, duels, and PvP statistics.
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.

local EPC = ESOProgressionCoach
if not EPC or not EPC.PvP then return end
local P = EPC.PvP

if P._combatRuntimeLoaded029754 then return end
P._combatRuntimeLoaded029754 = true

local defaults = EPC.defaults or {}
local extraDefaults = {
    pvpAwarenessLeft029754 = -1,
    pvpAwarenessTop029754 = -1,
    pvpGroupLeft029754 = -1,
    pvpGroupTop029754 = -1,
    pvpCombatStats029754 = true,
    pvpCombatStatsDamage029754 = true,
    pvpCombatStatsHealing029754 = true,
    pvpCombatStatsCrowdControl029754 = true,
}
for k, v in pairs(extraDefaults) do
    if defaults[k] == nil then defaults[k] = v end
end

P.recentDamageTargets = P.recentDamageTargets or {}
P.recentHealTargets = P.recentHealTargets or {}
P.hostileActors = P.hostileActors or {}
P.battleLocations = P.battleLocations or {}
P.alertCooldowns = P.alertCooldowns or {}
P._killDedup029754 = P._killDedup029754 or {}
P._assistDedup029754 = P._assistDedup029754 or {}
P._duel029754 = P._duel029754 or nil
P._lastCombatEventKey029754 = P._lastCombatEventKey029754 or ""
P._lastCombatEventAt029754 = P._lastCombatEventAt029754 or 0

local function sv()
    return EPC.saved or defaults
end

local function nowMs()
    if type(GetGameTimeMilliseconds) == "function" then return GetGameTimeMilliseconds() end
    if type(GetFrameTimeMilliseconds) == "function" then return GetFrameTimeMilliseconds() end
    return math.floor((type(GetFrameTimeSeconds) == "function" and GetFrameTimeSeconds() or 0) * 1000)
end

local function call(name, fallback, ...)
    local fn = rawget(_G, name)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if not ok then return fallback end
    if a == nil then return fallback end
    return a, b, c, d, e, f, g, h
end

local function cleanName(name)
    name = tostring(name or "")
    if name == "" then return "" end
    if type(zo_strformat) == "function" then
        local ok, result = pcall(zo_strformat, "<<C:1>>", name)
        if ok and result and result ~= "" then return result end
    end
    return name
end

local function pct(current, maximum)
    current, maximum = tonumber(current) or 0, tonumber(maximum) or 0
    if maximum <= 0 then return 0 end
    return math.floor((current / maximum) * 100 + 0.5)
end

local function boundedPush(list, entry, limit)
    list[#list + 1] = entry
    limit = math.max(10, tonumber(limit) or 250)
    while #list > limit do table.remove(list, 1) end
end

local function sameIdentity(displayName, characterName, unitTag)
    if not unitTag or call("DoesUnitExist", false, unitTag) ~= true then return false end
    local ud = tostring(call("GetUnitDisplayName", "", unitTag) or "")
    local uc = tostring(call("GetUnitName", "", unitTag) or "")
    return (displayName ~= "" and displayName == ud) or (characterName ~= "" and characterName == uc)
end

local function playerIdentity()
    return tostring(call("GetDisplayName", "") or ""), tostring(call("GetUnitName", "", "player") or "")
end

local function isLocalPlayer(displayName, characterName)
    local d, c = playerIdentity()
    return (displayName ~= "" and displayName == d) or (characterName ~= "" and characterName == c)
end

local function getGroupSize()
    return math.max(0, tonumber((call("GetGroupSize", 0))) or 0)
end

local function isGroupIdentity(displayName, characterName)
    local size = getGroupSize()
    for i = 1, size do
        local tag = "group" .. tostring(i)
        if sameIdentity(displayName, characterName, tag) then return true, tag end
    end
    return false, nil
end

local function encounterKey(displayName, characterName)
    if displayName and displayName ~= "" then return displayName end
    if characterName and characterName ~= "" then return characterName end
    return nil
end

function P:GetEncounterProfile029754(displayName, characterName, create)
    local key = encounterKey(displayName, characterName)
    if not key then return nil, nil end
    local store = sv().pvpEncounterPlayers029753
    if type(store) ~= "table" then
        if not create then return nil, key end
        store = {}
        sv().pvpEncounterPlayers029753 = store
    end
    local profile = store[key]
    if create and type(profile) ~= "table" then
        profile = {
            displayName = displayName or "",
            characterName = characterName or "",
            encounters = 0,
            kills = 0,
            deaths = 0,
            assists = 0,
            lastSeen = 0,
            alliance = 0,
            rank = 0,
            classId = 0,
            notes = "",
            label = "",
        }
        store[key] = profile
    end
    return profile, key
end

function P:TouchEncounter029754(displayName, characterName, alliance, rank, classId)
    local profile = self:GetEncounterProfile029754(displayName, characterName, true)
    if not profile then return end
    if displayName and displayName ~= "" then profile.displayName = displayName end
    if characterName and characterName ~= "" then profile.characterName = characterName end
    profile.lastSeen = type(GetTimeStamp) == "function" and GetTimeStamp() or 0
    profile.encounters = math.max(1, tonumber(profile.encounters) or 0)
    if tonumber(alliance) and tonumber(alliance) > 0 then profile.alliance = tonumber(alliance) end
    if tonumber(rank) and tonumber(rank) > 0 then profile.rank = tonumber(rank) end
    if tonumber(classId) and tonumber(classId) > 0 then profile.classId = tonumber(classId) end
end

function P:GetWatchLabel029754(displayName, characterName)
    local watch = sv().pvpWatchPlayers029753
    if type(watch) ~= "table" then return nil end
    return watch[displayName] or watch[characterName]
end

function P:SetWatchLabel029754(name, label, note)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false end
    local watch = sv().pvpWatchPlayers029753
    if type(watch) ~= "table" then watch = {}; sv().pvpWatchPlayers029753 = watch end
    if label == nil or label == "" or label == "NONE" then
        watch[name] = nil
    else
        watch[name] = { label = tostring(label), note = tostring(note or ""), updatedAt = type(GetTimeStamp) == "function" and GetTimeStamp() or 0 }
    end
    return true
end

function P:MaybeWatchAlert029754(displayName, characterName)
    local cfg = self:GetWatchLabel029754(displayName, characterName)
    if type(cfg) ~= "table" then return end
    local key = "watch:" .. tostring(displayName ~= "" and displayName or characterName)
    local t = nowMs()
    if t - (tonumber(self.alertCooldowns[key]) or 0) < 15000 then return end
    self.alertCooldowns[key] = t
    if sv().pvpNotifyWatch029753 ~= false then
        local label = tostring(cfg.label or "WATCH")
        local name = characterName ~= "" and characterName or displayName
        self:Alert(label .. " • " .. tostring(name), label == "RIVAL")
    end
end

local DAMAGE_RESULTS = {}
local HEAL_RESULTS = {}
for _, name in ipairs({ "ACTION_RESULT_DAMAGE", "ACTION_RESULT_CRITICAL_DAMAGE", "ACTION_RESULT_DOT_TICK", "ACTION_RESULT_DOT_TICK_CRITICAL" }) do
    local v = rawget(_G, name)
    if v ~= nil then DAMAGE_RESULTS[v] = true end
end
for _, name in ipairs({ "ACTION_RESULT_HEAL", "ACTION_RESULT_CRITICAL_HEAL", "ACTION_RESULT_HOT_TICK", "ACTION_RESULT_HOT_TICK_CRITICAL" }) do
    local v = rawget(_G, name)
    if v ~= nil then HEAL_RESULTS[v] = true end
end

local CC_RESULTS = {}
local function addCC(globalName, label)
    local v = rawget(_G, globalName)
    if v ~= nil then CC_RESULTS[v] = label end
end
addCC("ACTION_RESULT_STUNNED", "STUN")
addCC("ACTION_RESULT_KNOCKBACK", "KNOCKBACK")
addCC("ACTION_RESULT_FEARED", "FEAR")
addCC("ACTION_RESULT_SILENCED", "SILENCE")
addCC("ACTION_RESULT_DISORIENTED", "DISORIENT")
addCC("ACTION_RESULT_ROOTED", "ROOT")
addCC("ACTION_RESULT_OFFBALANCE", "OFF BALANCE")

local function getPlayerPower(powerType)
    local current, maximum = call("GetUnitPower", 0, "player", powerType)
    return tonumber(current) or 0, tonumber(maximum) or 0
end

function P:AlertCooldown029754(key, cooldownMs, text, important)
    local t = nowMs()
    local last = tonumber(self.alertCooldowns[key]) or 0
    if t - last < (tonumber(cooldownMs) or 2500) then return false end
    self.alertCooldowns[key] = t
    self:Alert(text, important == true)
    return true
end

function P:FlashScreen029754()
    if sv().pvpAlertScreenFlash029753 ~= true or sv().pvpReduceAnimations029753 == true or not WINDOW_MANAGER or not GuiRoot then return end
    if not self.flash029754 then
        local flash = WINDOW_MANAGER:CreateTopLevelWindow("EAS_PvPScreenFlash029754")
        flash:SetAnchorFill(GuiRoot)
        flash:SetDrawTier(DT_HIGH)
        flash:SetDrawLevel(5000)
        flash:SetMouseEnabled(false)
        flash:SetHidden(true)
        local tex = WINDOW_MANAGER:CreateControl(nil, flash, CT_TEXTURE)
        tex:SetAnchorFill(flash)
        tex:SetTexture("EsoUI/Art/Miscellaneous/white.dds")
        tex:SetColor(1, 0.05, 0.02, 0.10)
        flash.texture = tex
        self.flash029754 = flash
    end
    self.flash029754:SetHidden(false)
    local key = EPC.name .. "_PvPFlash029754"
    EPC.Runtime:UnregisterUpdate("PvPCombatRuntime", key)
    EPC.Runtime:RegisterUpdate("PvPCombatRuntime", key, 130, function()
        EPC.Runtime:UnregisterUpdate("PvPCombatRuntime", key)
        if P.flash029754 then P.flash029754:SetHidden(true) end
    end)
end

function P:IsUltimateAbility029754(abilityId)
    abilityId = tonumber(abilityId) or 0
    if abilityId <= 0 then return false end
    local fn = rawget(_G, "GetAbilityUltimateCost")
    if type(fn) == "function" then
        local ok, cost = pcall(fn, abilityId)
        if ok and tonumber(cost) and tonumber(cost) > 0 then return true end
    end
    return false
end

function P:IsLikelySiegeAbility029754(abilityId, abilityName)
    local icon = tostring(call("GetAbilityIcon", "", tonumber(abilityId) or 0) or ""):lower()
    if icon:find("siege", 1, true) or icon:find("/ava/", 1, true) then return true end
    local name = tostring(abilityName or ""):lower()
    return name:find("ballista", 1, true) or name:find("trebuchet", 1, true)
        or name:find("catapult", 1, true) or name:find("ram", 1, true)
end

function P:RecordRecentDamageTarget029754(targetName, targetUnitId, abilityName, abilityId, amount)
    targetName = tostring(targetName or "")
    if targetName == "" then return end
    self.recentDamageTargets[targetName] = {
        at = nowMs(),
        unitId = targetUnitId,
        abilityName = tostring(abilityName or ""),
        abilityId = tonumber(abilityId) or 0,
        amount = tonumber(amount) or 0,
    }
end

function P:RecordCombatTimeline029754(entry)
    if sv().pvpDeathRecap029753 == false then return end
    self.combatTimeline029754 = self.combatTimeline029754 or {}
    entry.at = nowMs()
    boundedPush(self.combatTimeline029754, entry, 30)
end

function P:OnCombatEvent029754(_, result, isError, abilityName, abilityGraphic, abilityActionSlotType,
    sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log,
    sourceUnitId, targetUnitId, abilityId)

    if not self:IsEnabled() or not self:IsPvPContext() then return end

    local t = nowMs()
    local dedup = table.concat({
        tostring(sourceUnitId or 0), tostring(targetUnitId or 0), tostring(abilityId or 0),
        tostring(result or 0), tostring(hitValue or 0), tostring(math.floor(t / 20))
    }, ":")
    if dedup == self._lastCombatEventKey029754 and t - (self._lastCombatEventAt029754 or 0) < 30 then return end
    self._lastCombatEventKey029754, self._lastCombatEventAt029754 = dedup, t

    sourceName = tostring(sourceName or "")
    targetName = tostring(targetName or "")
    abilityName = tostring(abilityName or "")
    local playerName = tostring(call("GetUnitName", "", "player") or "")
    local sourceIsMe = sourceName ~= "" and sourceName == playerName
    local targetIsMe = targetName ~= "" and targetName == playerName
    local amount = math.max(0, tonumber(hitValue) or 0)
    local isDamage = DAMAGE_RESULTS[result] == true
    local isHeal = HEAL_RESULTS[result] == true

    if not self.session.startedMs then self:ResetSession("combat") end
    self.session.damageDone = tonumber(self.session.damageDone) or 0
    self.session.damageTaken = tonumber(self.session.damageTaken) or 0
    self.session.healingDone = tonumber(self.session.healingDone) or 0
    self.session.healingTaken = tonumber(self.session.healingTaken) or 0
    self.session.biggestHit = tonumber(self.session.biggestHit) or 0
    self.session.biggestIncoming = tonumber(self.session.biggestIncoming) or 0
    self.session.ccReceived = tonumber(self.session.ccReceived) or 0
    self.session.ccApplied = tonumber(self.session.ccApplied) or 0

    if isDamage and sourceIsMe and not targetIsMe then
        self.session.damageDone = self.session.damageDone + amount
        self.session.biggestHit = math.max(self.session.biggestHit, amount)
        self:RecordRecentDamageTarget029754(targetName, targetUnitId, abilityName, abilityId, amount)
        self:RecordCombatTimeline029754({ direction = "OUT", kind = "DAMAGE", name = targetName, ability = abilityName, value = amount })
    elseif isDamage and targetIsMe and not sourceIsMe then
        self.session.damageTaken = self.session.damageTaken + amount
        self.session.biggestIncoming = math.max(self.session.biggestIncoming, amount)
        self.hostileActors[sourceName ~= "" and sourceName or tostring(sourceUnitId or "?")] = t
        self.recentAttackers[sourceName ~= "" and sourceName or tostring(sourceUnitId or "?")] = t
        self:RecordCombatTimeline029754({ direction = "IN", kind = "DAMAGE", name = sourceName, ability = abilityName, value = amount })

        if sv().pvpCombatAlerts029753 ~= false then
            local hp, hpMax = getPlayerPower(POWERTYPE_HEALTH)
            local hpPct = pct(hp, hpMax)
            if sv().pvpAlertExecute029753 ~= false and hpPct <= 30 and amount >= math.max(1000, hpMax * 0.06) then
                self:AlertCooldown029754("execute", 2300, "EXECUTE PRESSURE • " .. (abilityName ~= "" and abilityName or "Incoming damage"), true)
                self:FlashScreen029754()
            end
            local heavyType = rawget(_G, "ACTION_SLOT_TYPE_HEAVY_ATTACK")
            local beginResult = rawget(_G, "ACTION_RESULT_BEGIN")
            if sv().pvpAlertIncomingHeavy029753 ~= false and ((heavyType and abilityActionSlotType == heavyType) or (beginResult and result == beginResult)) then
                self:AlertCooldown029754("heavy:" .. tostring(abilityId), 1800, "HEAVY ATTACK • " .. (abilityName ~= "" and abilityName or "Incoming"), true)
            end
            if sv().pvpAlertUltimate029753 ~= false and self:IsUltimateAbility029754(abilityId) then
                self:AlertCooldown029754("ult:" .. tostring(abilityId), 3500, "HOSTILE ULTIMATE • " .. (abilityName ~= "" and abilityName or "Ultimate"), true)
                self:FlashScreen029754()
            end
            if sv().pvpAlertSiege029753 ~= false and self:IsLikelySiegeAbility029754(abilityId, abilityName) then
                self:AlertCooldown029754("siege:" .. tostring(abilityId), 2500, "SIEGE HIT • " .. (abilityName ~= "" and abilityName or "Incoming siege"), true)
            end
        end
    elseif isHeal and sourceIsMe then
        self.session.healingDone = self.session.healingDone + amount
        self.recentHealTargets[targetName ~= "" and targetName or tostring(targetUnitId or "?")] = { at = t, amount = amount, ability = abilityName }
    elseif isHeal and targetIsMe then
        self.session.healingTaken = self.session.healingTaken + amount
    end

    local cc = CC_RESULTS[result]
    if cc then
        if targetIsMe and not sourceIsMe then
            self.session.ccReceived = self.session.ccReceived + 1
            if sv().pvpCombatAlerts029753 ~= false and sv().pvpAlertCrowdControl029753 ~= false then
                self:AlertCooldown029754("cc:" .. cc, 900, cc .. (abilityName ~= "" and (" • " .. abilityName) or ""), true)
            end
        elseif sourceIsMe then
            self.session.ccApplied = self.session.ccApplied + 1
        end
    end
end

function P:RefreshResourceAlerts029754()
    if not self:IsPvPContext() or sv().pvpCombatAlerts029753 == false then return end
    local hp, hpMax = getPlayerPower(POWERTYPE_HEALTH)
    if sv().pvpAlertLowHealth029753 ~= false and hpMax > 0 and hp / hpMax <= 0.25 then
        self:AlertCooldown029754("lowhp", 4500, "LOW HEALTH • " .. tostring(pct(hp, hpMax)) .. "%", true)
    end
    if sv().pvpAlertLowResources029753 ~= false then
        local mag, magMax = getPlayerPower(POWERTYPE_MAGICKA)
        local stam, stamMax = getPlayerPower(POWERTYPE_STAMINA)
        if magMax > 0 and mag / magMax <= 0.12 then
            self:AlertCooldown029754("lowmag", 5500, "LOW MAGICKA • " .. tostring(pct(mag, magMax)) .. "%", false)
        end
        if stamMax > 0 and stam / stamMax <= 0.12 then
            self:AlertCooldown029754("lowstam", 5500, "LOW STAMINA • " .. tostring(pct(stam, stamMax)) .. "%", false)
        end
    end
end

function P:CountPlayerDebuffs029754(unitTag)
    local num = tonumber((call("GetNumBuffs", 0, unitTag))) or 0
    local count = 0
    local debuffType = rawget(_G, "BUFF_EFFECT_TYPE_DEBUFF")
    if not debuffType then return 0 end
    for i = 1, math.min(num, 40) do
        local ok, _, _, _, _, _, _, buffType, effectType = pcall(GetUnitBuffInfo, unitTag, i)
        if ok and (buffType == debuffType or effectType == debuffType) then count = count + 1 end
    end
    return count
end

function P:RefreshPurgeAlert029754()
    if not self:IsPvPContext() or sv().pvpCombatAlerts029753 == false or sv().pvpAlertPurge029753 == false then return end
    local count = self:CountPlayerDebuffs029754("player")
    local old = tonumber(self._lastDebuffCount029754) or 0
    self._lastDebuffCount029754 = count
    if count >= 3 and count > old then
        self:AlertCooldown029754("purge", 4500, "NEGATIVE EFFECTS • " .. tostring(count) .. " active", false)
    end
end

function P:GetClassName029754(classId)
    classId = tonumber(classId) or 0
    local name = tostring(call("GetClassName", "", rawget(_G, "GENDER_MALE") or 2, classId) or "")
    if name ~= "" then return cleanName(name) end
    return EPC.Data and EPC.Data.classNames and EPC.Data.classNames[classId] or ("Class " .. tostring(classId))
end

function P:GetAllianceShort029754(alliance)
    alliance = tonumber(alliance) or 0
    if alliance == rawget(_G, "ALLIANCE_ALDMERI_DOMINION") then return "AD" end
    if alliance == rawget(_G, "ALLIANCE_DAGGERFALL_COVENANT") then return "DC" end
    if alliance == rawget(_G, "ALLIANCE_EBONHEART_PACT") then return "EP" end
    return "—"
end

local function makePanel(name, width, height, anchor, relative, relativePoint, x, y, titleText)
    if not WINDOW_MANAGER or not GuiRoot then return nil, nil end
    local root = WINDOW_MANAGER:CreateTopLevelWindow(name)
    root:SetDimensions(width, height)
    root:SetAnchor(anchor, relative or GuiRoot, relativePoint or anchor, x or 0, y or 0)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(true)
    root:SetMovable(true)

    local bg = WINDOW_MANAGER:CreateControl(nil, root, CT_BACKDROP)
    bg:SetAnchorFill(root)
    bg:SetCenterColor(0.012, 0.018, 0.028, 0.91)
    bg:SetEdgeColor(0.70, 0.50, 0.12, 0.92)

    local title = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
    title:SetAnchor(TOPLEFT, root, TOPLEFT, 8, 7)
    title:SetAnchor(TOPRIGHT, root, TOPRIGHT, -8, 7)
    title:SetFont("ZoFontWinH4")
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetText("|cE8B347" .. titleText .. "|r")

    local body = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
    body:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 2, 6)
    body:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, -8, -7)
    body:SetFont("ZoFontGame")
    body:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    body:SetVerticalAlignment(TEXT_ALIGN_TOP)
    body:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return root, body
end

function P:AttachMovable029754(control, xKey, yKey)
    if not control then return end
    control:SetHandler("OnMouseDown", function(c, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and EPC.unitFramesMoveMode then c:StartMoving() end
    end)
    control:SetHandler("OnMouseUp", function(c, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and EPC.unitFramesMoveMode and type(c.StopMovingOrResizing) == "function" then c:StopMovingOrResizing() end
    end)
    control:SetHandler("OnMoveStop", function(c)
        if EPC.saved then EPC.saved[xKey], EPC.saved[yKey] = c:GetLeft(), c:GetTop() end
    end)
end

function P:RestoreAdvancedPosition029754(control, xKey, yKey, anchor, x, y)
    if not control then return end
    control:ClearAnchors()
    local left, top = tonumber(sv()[xKey]) or -1, tonumber(sv()[yKey]) or -1
    if left >= 0 and top >= 0 then
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        control:SetAnchor(anchor or TOPLEFT, GuiRoot, anchor or TOPLEFT, x or 0, y or 0)
    end
end

function P:EnsureAwarenessPanel029754()
    if self.awarenessPanel029754 then return end
    local root, body = makePanel("EAS_PvPAwareness029754", 390, 152, TOPLEFT, GuiRoot, TOPLEFT, 24, 210, "PLAYER & TARGET AWARENESS")
    self.awarenessPanel029754, self.awarenessBody029754 = root, body
    self:AttachMovable029754(root, "pvpAwarenessLeft029754", "pvpAwarenessTop029754")
    self:RestoreAdvancedPosition029754(root, "pvpAwarenessLeft029754", "pvpAwarenessTop029754", TOPLEFT, 24, 210)
end

function P:EnsureGroupPanel029754()
    if self.groupPanel029754 then return end
    local root, body = makePanel("EAS_PvPGroup029754", 430, 305, TOPLEFT, GuiRoot, TOPLEFT, 24, 370, "GROUP AWARENESS")
    self.groupPanel029754, self.groupBody029754 = root, body
    self:AttachMovable029754(root, "pvpGroupLeft029754", "pvpGroupTop029754")
    self:RestoreAdvancedPosition029754(root, "pvpGroupLeft029754", "pvpGroupTop029754", TOPLEFT, 24, 370)
end

function P:GetActiveThreatCount029754()
    local t = nowMs()
    local count = 0
    local limit = math.max(16, tonumber(sv().pvpMaxTrackedPlayers029753) or 64)
    for key, seenAt in pairs(self.hostileActors) do
        if t - (tonumber(seenAt) or 0) <= 12000 then
            count = count + 1
            if count >= limit then break end
        elseif t - (tonumber(seenAt) or 0) > 60000 then
            self.hostileActors[key] = nil
        end
    end
    return count
end

function P:RefreshAwareness029754()
    self:EnsureAwarenessPanel029754()
    local panel = self.awarenessPanel029754
    if not panel then return end
    if EPC and EPC.unitFramesMoveMode then
        panel:SetHidden(false)
        return
    end
    local s = sv()
    if not self:ShouldDisplay() or s.pvpPlayerAwareness029753 == false then
        panel:SetHidden(true)
        return
    end

    local lines = {}
    if s.pvpEnemyCount029753 ~= false then
        lines[#lines + 1] = "Active threats: |cFFB14E" .. tostring(self:GetActiveThreatCount029754()) .. "|r"
    end

    if call("DoesUnitExist", false, "reticleover") and call("IsUnitPlayer", false, "reticleover") then
        local display = tostring(call("GetUnitDisplayName", "", "reticleover") or "")
        local char = cleanName(call("GetUnitName", "", "reticleover") or "")
        local classId = tonumber((call("GetUnitClassId", 0, "reticleover"))) or 0
        local alliance = tonumber((call("GetUnitAlliance", 0, "reticleover"))) or 0
        local rank = tonumber((call("GetUnitAvARank", 0, "reticleover"))) or 0
        self:TouchEncounter029754(display, char, alliance, rank, classId)
        self:MaybeWatchAlert029754(display, char)

        if s.pvpTargetIntelligence029753 ~= false then
            local profile = self:GetEncounterProfile029754(display, char, false) or {}
            lines[#lines + 1] = "|cFFFFFF" .. (char ~= "" and char or display) .. "|r  " .. self:GetAllianceShort029754(alliance) .. "  " .. self:GetClassName029754(classId)
            lines[#lines + 1] = string.format("Against you: %d kills • %d deaths • %d assists", tonumber(profile.kills) or 0, tonumber(profile.deaths) or 0, tonumber(profile.assists) or 0)
            if display ~= "" then lines[#lines + 1] = display end
            local watch = self:GetWatchLabel029754(display, char)
            if type(watch) == "table" then
                lines[#lines + 1] = "|cFFD45A" .. tostring(watch.label or "WATCH") .. "|r" .. ((watch.note and watch.note ~= "") and (" • " .. watch.note) or "")
            end
        end
    else
        if s.pvpRecentAttackers029753 ~= false then
            local recent = {}
            local t = nowMs()
            for name, seenAt in pairs(self.recentAttackers) do
                if t - (tonumber(seenAt) or 0) <= 12000 then recent[#recent + 1] = tostring(name) end
            end
            table.sort(recent)
            if #recent > 0 then
                lines[#lines + 1] = "Recent attackers: " .. table.concat(recent, ", ")
            else
                lines[#lines + 1] = "Aim at a player for target intelligence."
            end
        else
            lines[#lines + 1] = "Aim at a player for target intelligence."
        end
    end

    self.awarenessBody029754:SetText(table.concat(lines, "\n"))
    panel:SetHidden(false)
end

function P:GetGroupDebuffCount029754(unitTag)
    if sv().pvpGroupBuffs029753 == false then return 0 end
    return self:CountPlayerDebuffs029754(unitTag)
end

function P:RefreshGroupAwareness029754()
    self:EnsureGroupPanel029754()
    local panel = self.groupPanel029754
    if not panel then return end
    if EPC and EPC.unitFramesMoveMode then
        panel:SetHidden(false)
        return
    end
    local s = sv()
    local groupSize = getGroupSize()
    if not self:ShouldDisplay() or s.pvpGroupAwareness029753 == false or groupSize <= 0 then
        panel:SetHidden(true)
        return
    end

    local lines = {}
    local maxRows = math.min(groupSize, math.max(1, tonumber(s.pvpMaxTrackedPlayers029753) or 64), 12)
    local pressureCount, deadCount = 0, 0
    for i = 1, maxRows do
        local tag = "group" .. tostring(i)
        if call("DoesUnitExist", false, tag) then
            local name = cleanName(call("GetUnitName", tag, tag) or tag)
            local hp, hpMax = call("GetUnitPower", 0, tag, POWERTYPE_HEALTH)
            local hpPct = pct(hp, hpMax)
            local dead = call("IsUnitDead", false, tag) == true
            local leader = call("IsUnitGroupLeader", false, tag) == true
            local inRange = call("IsUnitInGroupSupportRange", true, tag) ~= false
            local prefix = leader and "|cFFD45A★|r " or ""
            local hpColor = hpPct <= 30 and "|cFF5555" or (hpPct <= 60 and "|cFFD45A" or "|c77FF77")
            local status = dead and "|cFF5555DEAD|r" or (hpColor .. tostring(hpPct) .. "%|r")
            if dead then deadCount = deadCount + 1 end
            if not dead and hpPct <= 45 then pressureCount = pressureCount + 1 end

            local extras = {}
            if s.pvpGroupRange029753 ~= false and not inRange then extras[#extras + 1] = "OUT" end
            if s.pvpGroupResurrection029753 ~= false and dead then
                if call("IsUnitBeingResurrected", false, tag) == true then
                    extras[#extras + 1] = "REVIVING"
                elseif call("DoesUnitHaveResurrectPending", false, tag) == true then
                    extras[#extras + 1] = "RES PENDING"
                end
            end
            if s.pvpGroupUltimate029753 ~= false and POWERTYPE_ULTIMATE ~= nil then
                local ult, ultMax = call("GetUnitPower", 0, tag, POWERTYPE_ULTIMATE)
                ult, ultMax = tonumber(ult) or 0, tonumber(ultMax) or 0
                if ultMax > 0 then extras[#extras + 1] = "U:" .. tostring(pct(ult, ultMax)) .. "%" end
            end
            if s.pvpGroupBuffs029753 ~= false then
                local debuffs = self:GetGroupDebuffCount029754(tag)
                if debuffs > 0 then extras[#extras + 1] = "D:" .. tostring(debuffs) end
            end
            lines[#lines + 1] = prefix .. name .. "  " .. status .. (#extras > 0 and ("  [" .. table.concat(extras, " • ") .. "]") or "")
        end
    end

    if s.pvpGroupHealthPressure029753 ~= false and pressureCount >= 2 then
        table.insert(lines, 1, "|cFFB14EGROUP PRESSURE: " .. tostring(pressureCount) .. " low|r")
    end
    if s.pvpGroupDeaths029753 ~= false and deadCount > 0 then
        table.insert(lines, 1, "|cFF5555DOWN: " .. tostring(deadCount) .. "|r")
    end

    self.groupBody029754:SetText(table.concat(lines, "\n"))
    panel:SetHidden(false)
end

function P:RecordKill029754(killLocation, killerDisplay, killerCharacter, killerAlliance, killerRank, victimDisplay, victimCharacter, victimAlliance, victimRank)
    killerDisplay, killerCharacter = tostring(killerDisplay or ""), cleanName(killerCharacter)
    victimDisplay, victimCharacter = tostring(victimDisplay or ""), cleanName(victimCharacter)
    killLocation = cleanName(killLocation)

    local t = nowMs()
    local dedupKey = table.concat({ killLocation, killerDisplay, killerCharacter, victimDisplay, victimCharacter }, "|")
    local last = tonumber(self._killDedup029754[dedupKey]) or 0
    if t - last < 1800 then return end
    self._killDedup029754[dedupKey] = t

    local killerIsMe = isLocalPlayer(killerDisplay, killerCharacter)
    local victimIsMe = isLocalPlayer(victimDisplay, victimCharacter)
    local killerIsGroup = isGroupIdentity(killerDisplay, killerCharacter)
    local recent = self.recentDamageTargets[victimCharacter] or self.recentDamageTargets[victimDisplay]
    local abilityName = type(recent) == "table" and tostring(recent.abilityName or "") or ""
    local life = sv().pvpLifetime029753 or {}

    self:TouchEncounter029754(killerDisplay, killerCharacter, killerAlliance, killerRank)
    self:TouchEncounter029754(victimDisplay, victimCharacter, victimAlliance, victimRank)
    self:MaybeWatchAlert029754(killerDisplay, killerCharacter)
    self:MaybeWatchAlert029754(victimDisplay, victimCharacter)

    local killerProfile = self:GetEncounterProfile029754(killerDisplay, killerCharacter, true)
    local victimProfile = self:GetEncounterProfile029754(victimDisplay, victimCharacter, true)

    if killerIsMe and not victimIsMe then
        self.session.kills = (tonumber(self.session.kills) or 0) + 1
        self.session.streak = (tonumber(self.session.streak) or 0) + 1
        self.session.bestStreak = math.max(tonumber(self.session.bestStreak) or 0, self.session.streak)
        local previousBestStreak = tonumber(life.bestStreak) or 0
        local previousBestMulti = tonumber(life.bestMultiKill) or 0
        life.kills = (tonumber(life.kills) or 0) + 1
        life.bestStreak = math.max(previousBestStreak, self.session.bestStreak)
        if victimProfile then victimProfile.deaths = (tonumber(victimProfile.deaths) or 0) + 1 end
        if sv().pvpClassBreakdown029753 ~= false and victimProfile and tonumber(victimProfile.classId) and tonumber(victimProfile.classId) > 0 then
            life.classKills = life.classKills or {}
            local classKey = tostring(victimProfile.classId)
            life.classKills[classKey] = (tonumber(life.classKills[classKey]) or 0) + 1
        end

        if t - (tonumber(self.session.lastKillMs) or 0) <= 5500 then
            self.session.multiKill = (tonumber(self.session.multiKill) or 0) + 1
        else
            self.session.multiKill = 1
        end
        self.session.lastKillMs = t
        self.session.bestMultiKill = math.max(tonumber(self.session.bestMultiKill) or 0, self.session.multiKill)
        life.bestMultiKill = math.max(tonumber(life.bestMultiKill) or 0, self.session.bestMultiKill)
        if sv().pvpPersonalRecords029753 ~= false and sv().pvpNotifications029753 ~= false and sv().pvpNotifyRecord029753 ~= false then
            if self.session.bestStreak > previousBestStreak and self.session.bestStreak >= 3 then
                self:AddFeed("|cFFD45ANEW RECORD|r  Kill Streak " .. tostring(self.session.bestStreak))
            end
            if self.session.bestMultiKill > previousBestMulti and self.session.bestMultiKill >= 2 then
                self:AddFeed("|cFFD45ANEW RECORD|r  Multi-Kill x" .. tostring(self.session.bestMultiKill))
            end
        end

        if sv().pvpKillFeed029753 ~= false and sv().pvpKillFeedSelf029753 ~= false then
            local victim = victimCharacter ~= "" and victimCharacter or victimDisplay
            local suffix = (sv().pvpKillFeedAbility029753 ~= false and abilityName ~= "") and (" • " .. abilityName) or ""
            local loc = killLocation ~= "" and ("  |c999999" .. killLocation .. "|r") or ""
            self:AddFeed("|c77FF77KILL|r  " .. victim .. suffix .. loc)
        end

        if sv().pvpStreaks029753 ~= false and self.session.streak > 0 and self.session.streak % 5 == 0 then
            self:Alert("KILL STREAK • " .. tostring(self.session.streak), true)
        end
        if sv().pvpMultiKills029753 ~= false and self.session.multiKill >= 2 then
            local labels = { [2] = "DOUBLE KILL", [3] = "TRIPLE KILL", [4] = "QUAD KILL", [5] = "PENTA KILL" }
            self:Alert(labels[self.session.multiKill] or ("MULTI KILL x" .. tostring(self.session.multiKill)), true)
            if sv().pvpBombTracker029753 ~= false then
                self.session.bestBomb = math.max(tonumber(self.session.bestBomb) or 0, self.session.multiKill)
            end
        end
    elseif victimIsMe then
        self.session.deaths = (tonumber(self.session.deaths) or 0) + 1
        self.session.streak, self.session.multiKill = 0, 0
        life.deaths = (tonumber(life.deaths) or 0) + 1
        if killerProfile then killerProfile.kills = (tonumber(killerProfile.kills) or 0) + 1 end
        if sv().pvpClassBreakdown029753 ~= false and killerProfile and tonumber(killerProfile.classId) and tonumber(killerProfile.classId) > 0 then
            life.classDeaths = life.classDeaths or {}
            local classKey = tostring(killerProfile.classId)
            life.classDeaths[classKey] = (tonumber(life.classDeaths[classKey]) or 0) + 1
        end
        if sv().pvpKillFeed029753 ~= false and sv().pvpKillFeedSelf029753 ~= false then
            local killer = killerCharacter ~= "" and killerCharacter or killerDisplay
            local loc = killLocation ~= "" and ("  |c999999" .. killLocation .. "|r") or ""
            self:AddFeed("|cFF7777DEATH|r  " .. killer .. loc)
        end
        self._lastDeathRecorded029753 = t
        if sv().pvpDeathRecap029753 ~= false then self:ShowDeathRecap029754(killerCharacter ~= "" and killerCharacter or killerDisplay) end
    else
        if recent and t - (tonumber(recent.at) or 0) <= 12000 then
            local assistKey = victimDisplay ~= "" and victimDisplay or victimCharacter
            if t - (tonumber(self._assistDedup029754[assistKey]) or 0) > 1500 then
                self._assistDedup029754[assistKey] = t
                self.session.assists = (tonumber(self.session.assists) or 0) + 1
                life.assists = (tonumber(life.assists) or 0) + 1
                if victimProfile then victimProfile.assists = (tonumber(victimProfile.assists) or 0) + 1 end
            end
        end
        if sv().pvpKillFeed029753 ~= false then
            if killerIsGroup and sv().pvpKillFeedGroup029753 ~= false then
                self:AddFeed("|c66CCFFGROUP|r  " .. (killerCharacter ~= "" and killerCharacter or killerDisplay) .. "  >  " .. (victimCharacter ~= "" and victimCharacter or victimDisplay))
            elseif sv().pvpKillFeedEveryone029753 == true then
                self:AddFeed((killerCharacter ~= "" and killerCharacter or killerDisplay) .. "  >  " .. (victimCharacter ~= "" and victimCharacter or victimDisplay))
            end
        end
    end

    if killLocation ~= "" then
        local battle = self.battleLocations[killLocation]
        if type(battle) ~= "table" then battle = { total = 0, allianceKills = {}, lastAt = t }; self.battleLocations[killLocation] = battle end
        battle.total = (tonumber(battle.total) or 0) + 1
        battle.lastAt = t
        killerAlliance = tonumber(killerAlliance) or 0
        battle.allianceKills[killerAlliance] = (tonumber(battle.allianceKills[killerAlliance]) or 0) + 1
    end

    sv().pvpLifetime029753 = life
    self:RefreshAll()
end

function P:OnPvPKillFeed029754(killLocation, killerPlayerDisplayName, killerPlayerCharacterName, killerPlayerAlliance, killerPlayerRank,
    victimPlayerDisplayName, victimPlayerCharacterName, victimPlayerAlliance, victimPlayerRank)
    self:RecordKill029754(killLocation, killerPlayerDisplayName, killerPlayerCharacterName, killerPlayerAlliance, killerPlayerRank,
        victimPlayerDisplayName, victimPlayerCharacterName, victimPlayerAlliance, victimPlayerRank)
end

function P:GetDeathRecapText029754(killer)
    local lines = { "|cFF7777DEFEATED BY|r  " .. tostring(killer or "Unknown") }
    local timeline = self.combatTimeline029754 or {}
    local added = 0
    for i = #timeline, 1, -1 do
        local e = timeline[i]
        if e.direction == "IN" and e.kind == "DAMAGE" and nowMs() - (tonumber(e.at) or 0) <= 12000 then
            lines[#lines + 1] = string.format("%s  %d", e.ability ~= "" and e.ability or "Damage", tonumber(e.value) or 0)
            added = added + 1
            if added >= 6 then break end
        end
    end
    if added == 0 then lines[#lines + 1] = "No recent incoming-damage timeline was available." end
    return table.concat(lines, "\n")
end

function P:ShowDeathRecap029754(killer)
    if sv().pvpDeathRecap029753 == false then return end
    self:Alert(self:GetDeathRecapText029754(killer), false)
end

function P:OnDuelStarted029754()
    if sv().pvpDuels029753 == false then return end
    local _, opponentCharacter, opponentDisplay = call("GetDuelInfo", rawget(_G, "DUEL_STATE_IDLE") or 0)
    self._duel029754 = {
        startedAt = type(GetTimeStamp) == "function" and GetTimeStamp() or 0,
        startedMs = nowMs(),
        opponentCharacter = cleanName(opponentCharacter),
        opponentDisplay = tostring(opponentDisplay or ""),
    }
end

function P:OnDuelFinished029754(duelResult, wasLocalPlayersResult, opponentCharacterName, opponentDisplayName, opponentAlliance, opponentGender, opponentClassId, opponentRaceId)
    if sv().pvpDuels029753 == false then return end
    local won = false
    local wonResult = rawget(_G, "DUEL_RESULT_WON")
    local forfeitResult = rawget(_G, "DUEL_RESULT_FORFEIT")
    if duelResult == wonResult then won = wasLocalPlayersResult == true
    elseif duelResult == forfeitResult then won = wasLocalPlayersResult ~= true end

    local history = sv().pvpDuelHistoryData029753
    if type(history) ~= "table" then history = {}; sv().pvpDuelHistoryData029753 = history end
    local duel = self._duel029754 or {}
    local elapsed = duel.startedMs and math.max(0, nowMs() - duel.startedMs) or 0
    local entry = {
        at = type(GetTimeStamp) == "function" and GetTimeStamp() or 0,
        opponentCharacter = cleanName(opponentCharacterName ~= "" and opponentCharacterName or duel.opponentCharacter),
        opponentDisplay = tostring(opponentDisplayName ~= "" and opponentDisplayName or duel.opponentDisplay or ""),
        alliance = tonumber(opponentAlliance) or 0,
        classId = tonumber(opponentClassId) or 0,
        raceId = tonumber(opponentRaceId) or 0,
        won = won,
        durationMs = elapsed,
    }
    if sv().pvpDuelHistory029753 ~= false then boundedPush(history, entry, sv().pvpHistoryLimit029753) end
    self._duel029754 = nil

    if sv().pvpDuelOpponent029753 ~= false then
        local wins, losses = 0, 0
        local key = entry.opponentDisplay ~= "" and entry.opponentDisplay or entry.opponentCharacter
        for _, item in ipairs(history) do
            local itemKey = item.opponentDisplay ~= "" and item.opponentDisplay or item.opponentCharacter
            if itemKey == key then if item.won then wins = wins + 1 else losses = losses + 1 end end
        end
        self:Alert((won and "DUEL WIN" or "DUEL LOSS") .. " • " .. tostring(entry.opponentCharacter ~= "" and entry.opponentCharacter or entry.opponentDisplay) .. " • Record " .. wins .. "-" .. losses, won)
    end
end

function P:RefreshCombatStatusText029754()
    if not self.statusHud or self.statusHud:IsHidden() then return end
    -- v0.29.760: each metric owns a fixed-width column.
    -- Refresh values only; never move, resize, or reflow the HUD here.
    if type(self.RefreshStatusColumns029760) == "function" then
        self:RefreshStatusColumns029760()
    end
end

function P:CleanupCombatCaches029754()
    local t = nowMs()
    for key, value in pairs(self.recentDamageTargets) do
        if type(value) ~= "table" or t - (tonumber(value.at) or 0) > 20000 then self.recentDamageTargets[key] = nil end
    end
    for key, value in pairs(self.recentHealTargets) do
        if type(value) ~= "table" or t - (tonumber(value.at) or 0) > 20000 then self.recentHealTargets[key] = nil end
    end
    for key, seenAt in pairs(self._killDedup029754) do
        if t - (tonumber(seenAt) or 0) > 15000 then self._killDedup029754[key] = nil end
    end
    for key, battle in pairs(self.battleLocations) do
        if type(battle) ~= "table" or t - (tonumber(battle.lastAt) or 0) > 300000 then self.battleLocations[key] = nil end
    end
end

function P:InstallCombatRuntime029754()
    if self._combatRuntimeInstalled029754 then return end
    self._combatRuntimeInstalled029754 = true

    -- Replace the foundation handlers with the current API-aware implementations.
    self.OnPvPKillFeed = function(_, ...) return P:OnPvPKillFeed029754(...) end
    self.OnCombatEvent = function(_, ...) return P:OnCombatEvent029754(...) end

    self:EnsureAwarenessPanel029754()
    self:EnsureGroupPanel029754()

    self:RegisterEvent("EVENT_DUEL_STARTED", function() P:OnDuelStarted029754() end)
    self:RegisterEvent("EVENT_DUEL_FINISHED", function(_, ...) P:OnDuelFinished029754(...) end)

    local key = EPC.name .. "_PvPCombatRuntime029754"
    EPC.Runtime:UnregisterUpdate("PvPCombatRuntime", key)
    EPC.Runtime:RegisterUpdate("PvPCombatRuntime", key, 500, function()
        if EPC and EPC.unitFramesMoveMode then
            if P.awarenessPanel029754 then P.awarenessPanel029754:SetHidden(false) end
            if P.groupPanel029754 then P.groupPanel029754:SetHidden(false) end
            return
        end
        if not P:IsEnabled() then
            if P.awarenessPanel029754 then P.awarenessPanel029754:SetHidden(true) end
            if P.groupPanel029754 then P.groupPanel029754:SetHidden(true) end
            return
        end
        if P:IsPvPContext() then
            local t = nowMs()
            local interval = 500
            if sv().pvpPerformance029753 ~= false and sv().pvpAdaptiveRefresh029753 ~= false
                and sv().pvpLargeBattleMode029753 ~= false and P:GetActiveThreatCount029754() >= 16 then
                interval = 1000
            end
            if t - (P._lastCombatPanelRefresh029754 or 0) >= interval then
                P._lastCombatPanelRefresh029754 = t
                P:RefreshResourceAlerts029754()
                P:RefreshPurgeAlert029754()
                P:RefreshAwareness029754()
                P:RefreshGroupAwareness029754()
                P:RefreshCombatStatusText029754()
            end
        else
            if P.awarenessPanel029754 then P.awarenessPanel029754:SetHidden(true) end
            if P.groupPanel029754 then P.groupPanel029754:SetHidden(true) end
        end
        P:CleanupCombatCaches029754()
    end)

    if not self._layoutCombatWrapped029754 and type(EPC.RaiseLayoutOverlays) == "function" then
        self._layoutCombatWrapped029754 = true
        local original = EPC.RaiseLayoutOverlays
        EPC.RaiseLayoutOverlays = function(core, ...)
            local result = original(core, ...)
            for _, control in ipairs({ P.awarenessPanel029754, P.groupPanel029754 }) do
                if control and core.unitFramesMoveMode then
                    -- Shared HUD Layout owns z-order now. Only keep the preview
                    -- visible here; repeated restacking caused panel flashing.
                    control:SetHidden(false)
                    if core.EnsureSingleClickLayoutDrag029763 then
                        core:EnsureSingleClickLayoutDrag029763(control)
                    end
                end
            end
            return result
        end
    end

    SLASH_COMMANDS = SLASH_COMMANDS or {}
    SLASH_COMMANDS["/easpvp"] = function(text)
        local command, rest = tostring(text or ""):match("^%s*(%S*)%s*(.-)%s*$")
        command = string.lower(command or "")
        if command == "watch" or command == "rival" or command == "friendly" then
            if rest == "" then EPC:Print("Usage: /easpvp " .. command .. " @Name") return end
            local label = command == "rival" and "RIVAL" or (command == "friendly" and "FRIENDLY" or "WATCH")
            P:SetWatchLabel029754(rest, label, "")
            EPC:Print("PvP " .. label .. ": " .. rest)
        elseif command == "unwatch" then
            if rest ~= "" then P:SetWatchLabel029754(rest, nil) EPC:Print("PvP watch removed: " .. rest) end
        elseif command == "session" then
            EPC:Print(string.format("PvP session K/D/A %d/%d/%d • AP %d", tonumber(P.session.kills) or 0, tonumber(P.session.deaths) or 0, tonumber(P.session.assists) or 0, tonumber(P.session.ap) or 0))
        else
            EPC:Print("PvP commands: /easpvp watch @Name, rival @Name, friendly @Name, unwatch @Name, session")
        end
    end
end

local baseInitialize = P.Initialize
function P:Initialize(...)
    local result
    if type(baseInitialize) == "function" then result = baseInitialize(self, ...) end
    self:InstallCombatRuntime029754()
    return result
end
