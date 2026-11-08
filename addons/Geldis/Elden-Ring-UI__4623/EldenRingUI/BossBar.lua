EldenRingUI = EldenRingUI or {}
local ERUI = EldenRingUI

ERUI.name = "EldenRingUI"
ERUI.dummyMode = false

local BOSS_TAGS = { "boss1", "boss2", "boss3", "boss4", "boss5", "boss6" }

local IGNORED_BOSSES = {
    ["Defense Prism"] = true,
}

local ALWAYS_COMBINED = {
    ["Reef Guardian"] = "Reef Guardian",
    ["Shaper of Flesh"] = "Hall of Fleshcraft",
}

local entries = {}
local entryByTag = {}
local peakCount = 0
local presentCount = 0

local function FormatHealth(value)
    if value >= 1000000 then
        return string.format("%.1fm  ", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.0fk  ", value / 1000)
    elseif value == 0 then
        return "0  "
    end
    return tostring(value)
end

local function IsBossInvulnerable(unitTag)
    if not DoesUnitExist(unitTag) then return false end

    local _, invulnMax = GetUnitAttributeVisualizerEffectInfo(
        unitTag,
        ATTRIBUTE_VISUAL_UNWAVERING_POWER,
        STAT_MITIGATION,
        ATTRIBUTE_HEALTH,
        COMBAT_MECHANIC_FLAGS_HEALTH
    )
    return invulnMax ~= nil
end

local function ResetFight()
    entries = {}
    entryByTag = {}
    peakCount = 0
    presentCount = 0
end

local function ScanBosses()
    local units = {}
    for _, unitTag in ipairs(BOSS_TAGS) do
        if DoesUnitExist(unitTag) then
            local name = GetUnitName(unitTag)
            if name and name ~= "" and not IGNORED_BOSSES[name] then
                local cur, max = GetUnitPower(unitTag, COMBAT_MECHANIC_FLAGS_HEALTH)
                table.insert(units, {
                    tag = unitTag,
                    name = name,
                    cur = cur,
                    max = max,
                    invulnerable = IsBossInvulnerable(unitTag),
                })
            end
        end
    end
    return units
end

local function SyncFight()
    local units = ScanBosses()
    local matched = {}
    local newByTag = {}

    local function Assign(unit, entry)
        entry.cur = unit.cur
        entry.max = math.max(entry.max, unit.max)
        entry.invulnerable = unit.invulnerable
        matched[entry] = true
        newByTag[unit.tag] = entry
    end

    local unassigned = {}
    for _, unit in ipairs(units) do
        local entry = entryByTag[unit.tag]
        if entry and entry.name == unit.name then
            Assign(unit, entry)
        else
            table.insert(unassigned, unit)
        end
    end

    for _, unit in ipairs(unassigned) do
        local entry
        for _, candidate in pairs(entryByTag) do
            if not matched[candidate] and candidate.name == unit.name and candidate.cur > 0 then
                entry = candidate
                break
            end
        end

        if not entry then
            entry = { name = unit.name, cur = 0, max = 0, invulnerable = false }
            table.insert(entries, entry)
        end

        Assign(unit, entry)
    end

    for _, entry in pairs(entryByTag) do
        if not matched[entry] then
            entry.cur = 0
            entry.invulnerable = false
        end
    end

    entryByTag = newByTag
    presentCount = #units
    peakCount = math.max(peakCount, presentCount)
end

local function IsCombinedFight()
    if peakCount >= 3 then return true end

    for _, entry in ipairs(entries) do
        if ALWAYS_COMBINED[entry.name] then return true end
    end
    return false
end

local function GetCombinedName()
    local names = {}
    local seen = {}
    for _, entry in ipairs(entries) do
        if ALWAYS_COMBINED[entry.name] then
            return ALWAYS_COMBINED[entry.name]
        end
        if not seen[entry.name] then
            seen[entry.name] = true
            table.insert(names, entry.name)
        end
    end

    if #names <= 1 then
        return names[1] or ""
    end

    local last = table.remove(names)
    return table.concat(names, ", ") .. " & " .. last
end

local function UpdateBarVisuals(bar, powerValue, powerMax, isInvulnerable)
    if powerMax <= 0 then return end

    ZO_StatusBar_SmoothTransition(bar, powerValue, powerMax)

    local percentLabel = bar:GetNamedChild("Percent")
    percentLabel:SetText(math.floor(powerValue * 100 / powerMax) .. "%")
    percentLabel:SetColor(0.9, 0.9, 0.9, 0.9)

    local healthLabel = bar:GetNamedChild("HealthValue")
    healthLabel:SetText(FormatHealth(powerValue))
    healthLabel:SetColor(0.9, 0.9, 0.9, 0.9)

    if isInvulnerable then
        bar:SetTexture("EldenRingUI/Textures/ERShieldBarBoss.dds")
    else
        bar:SetTexture("EldenRingUI/Textures/ERHealthBarBoss.dds")
    end
end

local function GetOrCreateBar(index)
    local bar = ERUI_Container:GetNamedChild("Bar" .. index)
    if bar then return bar end

    bar = CreateControlFromVirtual("$(parent)Bar" .. index, ERUI_Container, "ERUI_BarTemplate")
    bar:SetAnchor(BOTTOMLEFT, ERUI_Container, BOTTOMLEFT, 0, 0)
    bar:SetTexture("EldenRingUI/Textures/ERHealthBarBoss.dds")

    local barWidth = bar:GetWidth()
    local texRight = barWidth / 2048

    local yellowLine = WINDOW_MANAGER:CreateControl(bar:GetName() .. "YellowLine", bar, CT_TEXTURE)
    yellowLine:SetTexture("EldenRingUI/Textures/lowline.dds")
    yellowLine:SetAnchor(BOTTOMLEFT, bar, BOTTOMLEFT, 0, 0)
    yellowLine:SetAnchor(BOTTOMRIGHT, bar, BOTTOMRIGHT, 0, 0)
    yellowLine:SetHeight(12)
    yellowLine:SetTextureCoords(0, texRight, 0, 1)
    yellowLine:SetDrawTier(DT_MEDIUM)
    yellowLine:SetDrawLayer(DL_CONTROLS)
    yellowLine:SetDrawLevel(3)

    local backdrop = bar:GetNamedChild("Backdrop")
    if backdrop and type(backdrop.SetTextureCoords) == "function" then
        backdrop:SetTextureCoords(0, texRight, 0, 1)
    end

    local icon = bar:GetNamedChild("Icon")
    if icon then
        icon:SetDrawLayer(DL_CONTROLS)
        icon:SetDrawLevel(4)
    end

    local currentHPIcon = bar:GetNamedChild("CurrentHPIcon")
    if currentHPIcon then
        local lastPercent = -1
        bar:SetHandler("OnUpdate", function(self)
            local _, max = self:GetMinMax()
            if not max or max <= 0 then return end

            local percent = self:GetValue() / max
            if percent ~= lastPercent then
                currentHPIcon:ClearAnchors()
                currentHPIcon:SetAnchor(CENTER, self, LEFT, barWidth * percent - 13, -2)
                lastPercent = percent
            end
        end)
    end

    return bar
end

local function ShowBar(index, name, cur, max, isInvulnerable)
    local bar = GetOrCreateBar(index)
    bar:ClearAnchors()
    bar:SetAnchor(BOTTOMLEFT, ERUI_Container, BOTTOMLEFT, 0, -(index - 1) * 45)
    bar:SetHidden(false)

    local nameLabel = bar:GetNamedChild("BossName")
    nameLabel:SetText(name)
    nameLabel:SetColor(0.9, 0.9, 0.9, 0.9)

    UpdateBarVisuals(bar, cur, max, isInvulnerable)
end

local function HideBarsFrom(first)
    for i = first, #BOSS_TAGS do
        local bar = ERUI_Container:GetNamedChild("Bar" .. i)
        if bar then bar:SetHidden(true) end
    end
end

local function ShowDummyBar()
    if not ERUI.dummyMode or not DoesUnitExist("reticleover") then return false end

    local cur, max = GetUnitPower("reticleover", COMBAT_MECHANIC_FLAGS_HEALTH)
    if max < 20000000 or cur <= 1 then return false end

    ShowBar(1, GetUnitName("reticleover"), cur, max, IsBossInvulnerable("reticleover"))
    HideBarsFrom(2)
    return true
end

local function RenderBars()
    if presentCount == 0 then
        if not ShowDummyBar() then
            HideBarsFrom(1)
        end
        return
    end

    local totalCur, totalMax = 0, 0
    local allInvulnerable = true
    for _, entry in ipairs(entries) do
        totalCur = totalCur + entry.cur
        totalMax = totalMax + entry.max
        if entry.cur > 0 and not entry.invulnerable then
            allInvulnerable = false
        end
    end

    if totalCur <= 0 then
        HideBarsFrom(1)
        return
    end

    if IsCombinedFight() then
        ShowBar(1, GetCombinedName(), totalCur, totalMax, allInvulnerable)
        HideBarsFrom(2)
        return
    end

    local barCount = math.min(#entries, #BOSS_TAGS)
    for i = 1, barCount do
        local entry = entries[i]
        ShowBar(i, entry.name, entry.cur, entry.max, entry.invulnerable)
    end
    HideBarsFrom(barCount + 1)
end

local function Refresh()
    SyncFight()
    RenderBars()
end

local function OnPowerUpdate(_, unitTag)
    if unitTag == "reticleover" then
        if presentCount == 0 then RenderBars() end
        return
    end
    Refresh()
end

local function OnBossesChanged(_, forceReset)
    if forceReset then ResetFight() end
    Refresh()
end

local function OnPlayerActivated()
    ResetFight()
    Refresh()
end

local function OnCombatStateChanged(_, inCombat)
    if not inCombat and presentCount == 0 then
        ResetFight()
        RenderBars()
    end
end

local function OnVisualChanged(_, _, unitAttributeVisual)
    if unitAttributeVisual == ATTRIBUTE_VISUAL_UNWAVERING_POWER then
        Refresh()
    end
end

SLASH_COMMANDS["/dummyboss"] = function()
    ERUI.dummyMode = not ERUI.dummyMode

    local state = ERUI.dummyMode and "|c00FF00Enabled|r" or "|cFF0000Disabled|r"
    d("Elden Ring Boss Bar: Dummy Mode is now " .. state)

    if ERUI.dummyMode then
        EVENT_MANAGER:RegisterForEvent(ERUI.name .. "Reticle", EVENT_POWER_UPDATE, OnPowerUpdate)
        EVENT_MANAGER:AddFilterForEvent(ERUI.name .. "Reticle", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "reticleover", REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_HEALTH)
    else
        EVENT_MANAGER:UnregisterForEvent(ERUI.name .. "Reticle", EVENT_POWER_UPDATE)
    end

    Refresh()
    CALLBACK_MANAGER:FireCallbacks("ERUI_DummyModeChanged", ERUI.dummyMode)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ERUI.name then return end
    EVENT_MANAGER:UnregisterForEvent(ERUI.name, EVENT_ADD_ON_LOADED)

    local bossFragment = ZO_SimpleSceneFragment:New(ERUI_Container)
    HUD_SCENE:AddFragment(bossFragment)
    HUD_UI_SCENE:AddFragment(bossFragment)

    ZO_TargetUnitFramereticleover:SetHidden(true)
    ZO_PreHookHandler(ZO_TargetUnitFramereticleover, "OnShow", function()
        ZO_TargetUnitFramereticleover:SetHidden(true)
        return true
    end)

    EVENT_MANAGER:RegisterForEvent(ERUI.name .. "Reset", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ERUI.name .. "Bosses", EVENT_BOSSES_CHANGED, OnBossesChanged)
    EVENT_MANAGER:RegisterForEvent(ERUI.name .. "Combat", EVENT_PLAYER_COMBAT_STATE, OnCombatStateChanged)
    EVENT_MANAGER:RegisterForEvent(ERUI.name .. "ReticleTarget", EVENT_RETICLE_TARGET_CHANGED, function()
        if ERUI.dummyMode then RenderBars() end
    end)

    EVENT_MANAGER:RegisterForEvent(ERUI.name .. "Power", EVENT_POWER_UPDATE, OnPowerUpdate)
    EVENT_MANAGER:AddFilterForEvent(ERUI.name .. "Power", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG_PREFIX, "boss", REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_HEALTH)

    local visualEvents = {
        VisualAdded = EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED,
        VisualRemoved = EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED,
        VisualUpdated = EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED,
    }
    for suffix, event in pairs(visualEvents) do
        EVENT_MANAGER:RegisterForEvent(ERUI.name .. suffix, event, OnVisualChanged)
        EVENT_MANAGER:AddFilterForEvent(ERUI.name .. suffix, event, REGISTER_FILTER_UNIT_TAG_PREFIX, "boss")
    end

    Refresh()
end

EVENT_MANAGER:RegisterForEvent(ERUI.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)