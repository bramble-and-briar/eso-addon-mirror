-- 1vX Helper - extra tools: low health warning, combat timer
local addon = OneVXHelper
local E = {}
addon.Extras = E

local HEALTH = COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH
local NS_HP, NS_CT = "OneVXHelper_LowHP", "OneVXHelper_Combat"

local hpWin, hpLabel, ctWin, ctLabel
local hpRegistered, ctRegistered = false, false
local combatStart, inCombat = 0, false
local lastHpText -- only touch the label when the shown text changes

---------------------------------------------------------------------------
-- Low health warning
---------------------------------------------------------------------------
local function UpdateHealth(current, maxHp)
    local c = addon.sv.lowHealth
    if addon.unlocked then
        lastHpText = false -- preview shown: force a redraw when locked again
        hpLabel:SetText("LOW HEALTH 30%"); hpLabel:SetHidden(false); return
    end
    local text
    if maxHp and maxHp > 0 and current > 0 then
        local pct = current / maxHp * 100
        if pct < c.threshold then text = "LOW HEALTH " .. zo_round(pct) .. "%" end
    end
    if text == lastHpText then return end
    lastHpText = text
    if text then
        hpLabel:SetText(text)
        hpLabel:SetHidden(false)
    else
        hpLabel:SetHidden(true)
    end
end

local function OnPowerUpdate(_, _, _, _, value, _, effectiveMax)
    -- unit tag + power type are filtered by the engine
    UpdateHealth(value, effectiveMax)
end

local function ApplyLowHealth()
    local enabled = addon.sv.lowHealth.enabled
    addon.UI.SetEnabled(hpWin, enabled)
    if enabled and not hpRegistered then
        EVENT_MANAGER:RegisterForEvent(NS_HP, EVENT_POWER_UPDATE, OnPowerUpdate)
        EVENT_MANAGER:AddFilterForEvent(NS_HP, EVENT_POWER_UPDATE,
            REGISTER_FILTER_UNIT_TAG, "player",
            REGISTER_FILTER_POWER_TYPE, HEALTH)
        hpRegistered = true
    elseif not enabled and hpRegistered then
        EVENT_MANAGER:UnregisterForEvent(NS_HP, EVENT_POWER_UPDATE)
        hpRegistered = false
    end
    lastHpText = false -- force a redraw
    local cur, _, effMax = GetUnitPower("player", HEALTH)
    UpdateHealth(cur, effMax)
end

---------------------------------------------------------------------------
-- Combat timer
---------------------------------------------------------------------------
local function FormatTime(ms)
    local s = math.floor(ms / 1000)
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function CombatTick()
    if inCombat then
        ctLabel:SetText("|cFF6060Combat|r " .. FormatTime(addon.Now() - combatStart))
    end
end

local function OnCombatState(_, state)
    if state then
        inCombat = true
        combatStart = addon.Now()
        ctLabel:SetHidden(false)
        CombatTick()
        EVENT_MANAGER:RegisterForUpdate(NS_CT .. "Tick", 1000, CombatTick) -- shows whole seconds
    else
        inCombat = false
        EVENT_MANAGER:UnregisterForUpdate(NS_CT .. "Tick")
        ctLabel:SetText("|c999999Last fight|r " .. FormatTime(addon.Now() - combatStart))
        zo_callLater(function()
            if not inCombat and not addon.unlocked then ctLabel:SetHidden(true) end
        end, 6000)
    end
end

local function ApplyCombatTimer()
    local enabled = addon.sv.combatTimer.enabled
    addon.UI.SetEnabled(ctWin, enabled)
    if enabled and not ctRegistered then
        EVENT_MANAGER:RegisterForEvent(NS_CT, EVENT_PLAYER_COMBAT_STATE, OnCombatState)
        ctRegistered = true
        if IsUnitInCombat("player") then OnCombatState(nil, true) end
    elseif not enabled and ctRegistered then
        EVENT_MANAGER:UnregisterForEvent(NS_CT, EVENT_PLAYER_COMBAT_STATE)
        EVENT_MANAGER:UnregisterForUpdate(NS_CT .. "Tick")
        ctRegistered, inCombat = false, false
    end
end

function E.Apply()
    ApplyLowHealth()
    ApplyCombatTimer()
end

function E.Init()
    hpWin = addon.UI.CreateWindow("LowHealth", 300, 40, 0, -140, { title = "Low Health" })
    hpLabel = addon.UI.Label("OneVXHelper_LowHealthLabel", hpWin.content, addon.UI.Font("BOLD_FONT", 28, "thick-outline"), 1, 0.45, 0.1, 1)
    hpLabel:SetAnchorFill()
    hpLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    hpLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    hpLabel:SetHidden(true)
    hpWin.onPreview = function()
        local cur, _, effMax = GetUnitPower("player", HEALTH)
        UpdateHealth(cur, effMax)
    end

    ctWin = addon.UI.CreateWindow("CombatTimer", 160, 28, 0, 190, { title = "Combat Timer" })
    ctLabel = addon.UI.Label("OneVXHelper_CombatTimerLabel", ctWin.content, addon.UI.Font("MEDIUM_FONT", 18, "soft-shadow-thick"))
    ctLabel:SetAnchorFill()
    ctLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    ctLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    ctLabel:SetHidden(true)
    ctWin.onPreview = function(unlocked)
        if unlocked then
            ctLabel:SetText("|cFF6060Combat|r 0:00"); ctLabel:SetHidden(false)
        elseif not inCombat then
            ctLabel:SetHidden(true)
        end
    end

    E.Apply()
end
