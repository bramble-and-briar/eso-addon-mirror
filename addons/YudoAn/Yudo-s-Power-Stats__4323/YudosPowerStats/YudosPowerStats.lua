--[[
   Yudo's Power Stats v1.6.2
--]]

-- Localized API functions for high-frequency updates
local GetPlayerStat = GetPlayerStat
local GetCriticalStrikeChance = GetCriticalStrikeChance
local GetAdvancedStatValue = GetAdvancedStatValue
local GetUIMousePosition = GetUIMousePosition

-- Fixed Math/String localizations
local string_format = string.format
local math_floor    = math.floor
-- Optimized constant: avoids recreating string objects in high-frequency loops
local newline       = string.char(10)

-- Constants used in calculations for faster lookup
local STAT_SPELL_POWER             = STAT_SPELL_POWER
local STAT_POWER                   = STAT_POWER
local STAT_SPELL_CRITICAL          = STAT_SPELL_CRITICAL
local STAT_CRITICAL_STRIKE         = STAT_CRITICAL_STRIKE
local STAT_PHYSICAL_RESIST         = STAT_PHYSICAL_RESIST
local STAT_SPELL_RESIST            = STAT_SPELL_RESIST
local STAT_CRITICAL_RESISTANCE     = STAT_CRITICAL_RESISTANCE
local STAT_PHYSICAL_PENETRATION    = STAT_PHYSICAL_PENETRATION
local STAT_SPELL_PENETRATION       = STAT_SPELL_PENETRATION
local STAT_BONUS_OPTION_APPLY_BONUS = STAT_BONUS_OPTION_APPLY_BONUS

-- Table for O(1) lookup to filter relevant stat updates
local RELEVANT_STATS = {
    [STAT_SPELL_POWER] = true,
    [STAT_POWER] = true,
    [STAT_SPELL_CRITICAL] = true,
    [STAT_CRITICAL_STRIKE] = true,
    [STAT_PHYSICAL_RESIST] = true,
    [STAT_SPELL_RESIST] = true,
    [STAT_CRITICAL_RESISTANCE] = true,
    [STAT_PHYSICAL_PENETRATION] = true,
    [STAT_SPELL_PENETRATION] = true,
}

local YPS_addonName = "YudosPowerStats"
local YPS = { name = YPS_addonName }

YPS.isLocked = false
YPS.isInitialized = false

local CRIT_DAMAGE_ID = 23
local BLOCK_MITIGATION_ID = 7

-- Performance Cache: Tables outside the update loop to minimize garbage generation
local tagsCache = {}
local valuesCache = {}

-- Throttling state
local isThrottled = false
local pendingUpdate = false

-- Cache for Gatekeeper optimization
YPS.lastP = 0
YPS.lastPE = 0
YPS.lastC = 0
YPS.lastD = 0
YPS.lastPR = 0
YPS.lastSR = 0
YPS.lastCR = 0
YPS.lastBL = 0

-- Peak tracking state
YPS.CombatData = {
    inCombat = false,
    peaks = { 
        power = 0, 
        pe = 0,
        cc = 0, 
        cd = 0 
    },
    defPeaks = {
        pr = 0,
        sr = 0,
        cr = 0,
        bl = 0
    }
}

local defaults = {
    left = 500,
    top = 500,
    defLeft = 600,
    defTop = 500,
    scale = 1.0,
    locked = false,
    opacity = 50,
    showDamage = true,
    showPE = false,
    showCC = true,
    showCD = true,
    showPeaksOnHover = true,
    thresholdPower = 0,
    thresholdPE = 0,
    thresholdCC = 0,
    thresholdCD = 0,
    -- Defense defaults
    showPR = true,
    showSR = true,
    showCR = true,
    showBL = false,
    showDefPeaksOnHover = true,
    thresholdPR = 0,
    thresholdSR = 0,
    thresholdCR = 0,
    thresholdBL = 0,
}

local function GetValueColor(current, threshold)
    if threshold > 0 and current >= threshold then
        return YPS.goldHex
    end
    return "FFFFFF"
end

function YPS.ShowPeakTooltip(control)
    local isDefense = (control == YPS.defenseControl)
    local showPeaks = YPS.savedVars.showPeaksOnHover
    if isDefense then
        showPeaks = YPS.savedVars.showDefPeaksOnHover
    end
    
    if not showPeaks then return end
    if not YPS.CombatData then return end
    
    local peaks = isDefense and YPS.CombatData.defPeaks or YPS.CombatData.peaks
    if not peaks then return end

    if type(InitializeTooltip) == "function" and InformationTooltip then
        InitializeTooltip(InformationTooltip, control, BOTTOM, 0, 0, TOP)
        
        -- Get the standard ESO "Normal" text color
        local r, g, b = ZO_NORMAL_TEXT:UnpackRGB()

        if isDefense then
            if YPS.savedVars.showSR then
                InformationTooltip:AddLine(string_format("Peak SR: %d", math_floor(peaks.sr)), "ZoFontGame", r, g, b)
            end
            if YPS.savedVars.showPR then
                InformationTooltip:AddLine(string_format("Peak PR: %d", math_floor(peaks.pr)), "ZoFontGame", r, g, b)
            end
            if YPS.savedVars.showCR then
                InformationTooltip:AddLine(string_format("Peak CR: %d", math_floor(peaks.cr)), "ZoFontGame", r, g, b)
            end
            if YPS.savedVars.showBL then
                InformationTooltip:AddLine(string_format("Peak BL: %d%%", peaks.bl), "ZoFontGame", r, g, b)
            end
        else
            if YPS.savedVars.showDamage then
                InformationTooltip:AddLine(string_format("Peak PO: %d", math_floor(peaks.power)), "ZoFontGame", r, g, b)
            end
            if YPS.savedVars.showPE then
                InformationTooltip:AddLine(string_format("Peak PE: %d", math_floor(peaks.pe)), "ZoFontGame", r, g, b)
            end

            if YPS.savedVars.showCC then
                local peakCCFormat = (peaks.cc >= 100) and "Peak CC: %d%%" or "Peak CC: %.1f%%"
                InformationTooltip:AddLine(string_format(peakCCFormat, peaks.cc), "ZoFontGame", r, g, b)
            end

            if YPS.savedVars.showCD then
                InformationTooltip:AddLine(string_format("Peak CD: %d%%", peaks.cd), "ZoFontGame", r, g, b)
            end
        end
    end
end

-- Force redraw by tricking the gatekeeper
function YPS.ForceUpdate()
    YPS.lastP, YPS.lastPE, YPS.lastC, YPS.lastD = -1, -1, -1, -1
    YPS.lastPR, YPS.lastSR, YPS.lastCR, YPS.lastBL = -1, -1, -1, -1
    
    YPS.RequestUpdate()
end

local function OnThrottledUpdate()
    isThrottled = false
    -- 3. If stats changed AGAIN during the 200ms, sync to the final values
    if pendingUpdate then
        pendingUpdate = false
        YPS.RequestUpdate()
    end
end

function YPS.RequestUpdate()
    -- 0. Optimization: If all stats are hidden, stop all logic immediately
    local powerActive = YPS.savedVars.showDamage or YPS.savedVars.showPE or YPS.savedVars.showCC or YPS.savedVars.showCD
    local defenseActive = YPS.savedVars.showPR or YPS.savedVars.showSR or YPS.savedVars.showCR or YPS.savedVars.showBL
    
    if not YPS.savedVars or not (powerActive or defenseActive) then
        return
    end

    -- If we are throttled, just mark that we need a refresh later and exit
    if isThrottled then 
        pendingUpdate = true 
        return 
    end

    -- 1. Run the update IMMEDIATELY (no delay for the first change)
    local didChange = YPS.UpdateDisplay()
    
    -- 2. Only start a cooldown if something actually updated
    if didChange then
        isThrottled = true
        -- Use 200ms: enough to catch "burst" events, but too fast for the eye to see
        zo_callLater(OnThrottledUpdate, 200) 
    end
end

function YPS.Initialize()
    -- ALWAYS Initialize savedVars first to prevent nil errors in later calls
    YPS.savedVars = ZO_SavedVars:NewAccountWide("YudosPowerStatsVars", 1, nil, defaults, GetWorldName())

    local colorDef = GetItemQualityColor(ITEM_DISPLAY_QUALITY_LEGENDARY)
    YPS.goldHex = colorDef:ToHex()

    YPS.control = YudosPowerStatsControl
    YPS.tagsLabel = YudosPowerStatsControlTags
    YPS.valuesLabel = YudosPowerStatsControlValues
    YPS.resizeHandle = YudosPowerStatsControlResizeHandle
    YPS.bg = YudosPowerStatsControlBG

    YPS.defenseControl = YudosDefenseStatsControl
    YPS.defTagsLabel = YudosDefenseStatsControlTags
    YPS.defValuesLabel = YudosDefenseStatsControlValues
    YPS.defResizeHandle = YudosDefenseStatsControlResizeHandle
    YPS.defBg = YudosDefenseStatsControlBG

    YPS.control:SetHandler("OnMoveStop", YPS.OnMoveStop)
    YPS.defenseControl:SetHandler("OnMoveStop", YPS.OnMoveStop)

    YPS.resizeHandle:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then YPS.OnResizeStart() end
    end)
    YPS.defResizeHandle:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then YPS.OnResizeStart() end
    end)

    YPS.control:SetHandler("OnMouseEnter", function(self) YPS.ShowPeakTooltip(self) end)
    YPS.control:SetHandler("OnMouseExit", function() 
        if type(ClearTooltip) == "function" then ClearTooltip(InformationTooltip) end
    end)

    YPS.defenseControl:SetHandler("OnMouseEnter", function(self) YPS.ShowPeakTooltip(self) end)
    YPS.defenseControl:SetHandler("OnMouseExit", function() 
        if type(ClearTooltip) == "function" then ClearTooltip(InformationTooltip) end
    end)

    YPS.powerFragment = ZO_HUDFadeSceneFragment:New(YPS.control)
    SCENE_MANAGER:GetScene("hud"):AddFragment(YPS.powerFragment)
    SCENE_MANAGER:GetScene("hudui"):AddFragment(YPS.powerFragment)

    YPS.defFragment = ZO_HUDFadeSceneFragment:New(YPS.defenseControl)
    SCENE_MANAGER:GetScene("hud"):AddFragment(YPS.defFragment)
    SCENE_MANAGER:GetScene("hudui"):AddFragment(YPS.defFragment)

    YPS.control:ClearAnchors()
    YPS.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, YPS.savedVars.left, YPS.savedVars.top)
    YPS.control:SetScale(YPS.savedVars.scale)

    YPS.defenseControl:ClearAnchors()
    YPS.defenseControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, YPS.savedVars.defLeft, YPS.savedVars.defTop)
    YPS.defenseControl:SetScale(YPS.savedVars.scale)

    YPS.isLocked = YPS.savedVars.locked

    YPS.UpdateLockState()
    YPS.UpdateOpacity()
    YPS.UpdateLayout()
    YPS.InitializeSettings()

    -- 1. Register for Combat State
    EVENT_MANAGER:RegisterForEvent(YPS_addonName, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        YPS.CombatData.inCombat = inCombat
        if inCombat then 
            -- Fetch current live stats to use as the initial peak baseline
            local sd = GetPlayerStat(STAT_SPELL_POWER, STAT_BONUS_OPTION_APPLY_BONUS)
            local wd = GetPlayerStat(STAT_POWER, STAT_BONUS_OPTION_APPLY_BONUS)
            local power = (sd >= wd) and sd or wd
            
            local sp = GetPlayerStat(STAT_SPELL_PENETRATION, STAT_BONUS_OPTION_APPLY_BONUS)
            local wp = GetPlayerStat(STAT_PHYSICAL_PENETRATION, STAT_BONUS_OPTION_APPLY_BONUS)
            local pe = (sp >= wp) and sp or wp
            
            local sc = GetPlayerStat(STAT_SPELL_CRITICAL, STAT_BONUS_OPTION_APPLY_BONUS)
            local wc = GetPlayerStat(STAT_CRITICAL_STRIKE, STAT_BONUS_OPTION_APPLY_BONUS)
            local cc = GetCriticalStrikeChance((sc >= wc) and sc or wc)
            
            local _, _, bonusPct = GetAdvancedStatValue(CRIT_DAMAGE_ID)
            local cd = 50 + (bonusPct or 0)

            local pr = GetPlayerStat(STAT_PHYSICAL_RESIST, STAT_BONUS_OPTION_APPLY_BONUS)
            local sr = GetPlayerStat(STAT_SPELL_RESIST, STAT_BONUS_OPTION_APPLY_BONUS)
            local cr = GetPlayerStat(STAT_CRITICAL_RESISTANCE, STAT_BONUS_OPTION_APPLY_BONUS)
            
            local _, _, blPct = GetAdvancedStatValue(BLOCK_MITIGATION_ID)
            local bl = blPct or 0

            -- Reset peaks to these current values immediately instead of 0
            YPS.CombatData.peaks = { 
                power = power, 
                pe = pe,
                cc = cc, 
                cd = cd 
            }
            YPS.CombatData.defPeaks = {
                pr = pr,
                sr = sr,
                cr = cr,
                bl = bl
            }
        end
        YPS.RequestUpdate() 
    end)

    -- 2. Register for Stat Updates (Filtered for player with StatID check)
    EVENT_MANAGER:RegisterForEvent(YPS_addonName, EVENT_STATS_UPDATED, function(_, unitTag, statId) 
        if not RELEVANT_STATS[statId] then return end
        YPS.RequestUpdate() 
    end)
    EVENT_MANAGER:AddFilterForEvent(YPS_addonName, EVENT_STATS_UPDATED, REGISTER_FILTER_UNIT_TAG, "player")

    -- 3. Register for Effect Changes (Filtered for player - Catching buffs/potions)
    EVENT_MANAGER:RegisterForEvent(YPS_addonName, EVENT_EFFECT_CHANGED, function() YPS.RequestUpdate() end)
    EVENT_MANAGER:AddFilterForEvent(YPS_addonName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    -- 4. Register for Weapon Swap
    EVENT_MANAGER:RegisterForEvent(YPS_addonName, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function() YPS.RequestUpdate() end)

    -- Synchronize visual state immediately. Environment is guaranteed ready by EVENT_PLAYER_ACTIVATED.
    YPS.UpdateDisplay()
end

function YPS.UpdateDisplay()
    -- SAFETY CHECK: If the game hasn't finished loading the savedVars, abort the update.
    if not YPS.savedVars then return false end

    local powerActive = YPS.savedVars.showDamage or YPS.savedVars.showPE or YPS.savedVars.showCC or YPS.savedVars.showCD
    local defenseActive = YPS.savedVars.showPR or YPS.savedVars.showSR or YPS.savedVars.showCR or YPS.savedVars.showBL

    -- 0. Early exit: If everything is hidden, don't even fetch stats (fastest)
    if not (powerActive or defenseActive) then 
        return false
    end

    -- 1. Get the current raw numbers (fast)
    local sd = GetPlayerStat(STAT_SPELL_POWER, STAT_BONUS_OPTION_APPLY_BONUS)
    local wd = GetPlayerStat(STAT_POWER, STAT_BONUS_OPTION_APPLY_BONUS)
    local power = (sd >= wd) and sd or wd

    local sp = GetPlayerStat(STAT_SPELL_PENETRATION, STAT_BONUS_OPTION_APPLY_BONUS)
    local wp = GetPlayerStat(STAT_PHYSICAL_PENETRATION, STAT_BONUS_OPTION_APPLY_BONUS)
    local pe = (sp >= wp) and sp or wp
    
    local sc = GetPlayerStat(STAT_SPELL_CRITICAL, STAT_BONUS_OPTION_APPLY_BONUS)
    local wc = GetPlayerStat(STAT_CRITICAL_STRIKE, STAT_BONUS_OPTION_APPLY_BONUS)
    local ccRaw = GetCriticalStrikeChance((sc >= wc) and sc or wc)
    local cc = math_floor(ccRaw * 10 + 0.5) / 10
    
    local _, _, bonusPct = GetAdvancedStatValue(CRIT_DAMAGE_ID)
    local cd = 50 + (bonusPct or 0)

    local pr = GetPlayerStat(STAT_PHYSICAL_RESIST, STAT_BONUS_OPTION_APPLY_BONUS)
    local sr = GetPlayerStat(STAT_SPELL_RESIST, STAT_BONUS_OPTION_APPLY_BONUS)
    local cr = GetPlayerStat(STAT_CRITICAL_RESISTANCE, STAT_BONUS_OPTION_APPLY_BONUS)
    
    local _, _, blPct = GetAdvancedStatValue(BLOCK_MITIGATION_ID)
    local bl = blPct or 0

    -- 2. THE GATEKEEPER: Only continue if these specific numbers changed
    if power == YPS.lastP and pe == YPS.lastPE and cc == YPS.lastC and cd == YPS.lastD and
       pr == YPS.lastPR and sr == YPS.lastSR and cr == YPS.lastCR and bl == YPS.lastBL then
        return false
    end
    
    -- 3. Update the "last known" values for next time
    YPS.lastP, YPS.lastPE, YPS.lastC, YPS.lastD = power, pe, cc, cd
    YPS.lastPR, YPS.lastSR, YPS.lastCR, YPS.lastBL = pr, sr, cr, bl

    -- 4. Peak tracking (Polished grouped logic)
    if YPS.CombatData.inCombat then
        if YPS.savedVars.showPeaksOnHover then
            local p = YPS.CombatData.peaks
            if power > p.power then p.power = power end
            if pe > p.pe then p.pe = pe end
            if cc > p.cc then p.cc = cc end
            if cd > p.cd then p.cd = cd end
        end
        if YPS.savedVars.showDefPeaksOnHover then
            local p = YPS.CombatData.defPeaks
            if pr > p.pr then p.pr = pr end
            if sr > p.sr then p.sr = sr end
            if cr > p.cr then p.cr = cr end
            if bl > p.bl then p.bl = bl end
        end
    end

    -- Update Power Stats
    if powerActive then
        ZO_ClearTable(tagsCache)
        ZO_ClearTable(valuesCache)
        
        if YPS.savedVars.showDamage then
            local color = GetValueColor(power, YPS.savedVars.thresholdPower)
            table.insert(tagsCache, "PO")
            table.insert(valuesCache, string_format("|c%s%d|r", color, power))
        end

        if YPS.savedVars.showPE then
            local color = GetValueColor(pe, YPS.savedVars.thresholdPE)
            table.insert(tagsCache, "PE")
            table.insert(valuesCache, string_format("|c%s%d|r", color, pe))
        end
        
        if YPS.savedVars.showCC then
            local color = GetValueColor(cc, YPS.savedVars.thresholdCC)
            local formatStr = (cc >= 100) and "|c%s%d%%|r" or "|c%s%.1f%%|r"
            table.insert(tagsCache, "CC")
            table.insert(valuesCache, string_format(formatStr, color, cc))
        end
        
        if YPS.savedVars.showCD then
            local color = GetValueColor(cd, YPS.savedVars.thresholdCD)
            table.insert(tagsCache, "CD")
            table.insert(valuesCache, string_format("|c%s%d%%|r", color, cd))
        end

        YPS.tagsLabel:SetText(table.concat(tagsCache, newline))
        YPS.valuesLabel:SetText(table.concat(valuesCache, newline))
    end

    -- Update Defense Stats
    if defenseActive then
        ZO_ClearTable(tagsCache)
        ZO_ClearTable(valuesCache)
        
        if YPS.savedVars.showSR then
            local color = GetValueColor(sr, YPS.savedVars.thresholdSR)
            table.insert(tagsCache, "SR")
            table.insert(valuesCache, string_format("|c%s%d|r", color, sr))
        end

        if YPS.savedVars.showPR then
            local color = GetValueColor(pr, YPS.savedVars.thresholdPR)
            table.insert(tagsCache, "PR")
            table.insert(valuesCache, string_format("|c%s%d|r", color, pr))
        end
        
        if YPS.savedVars.showCR then
            local color = GetValueColor(cr, YPS.savedVars.thresholdCR)
            table.insert(tagsCache, "CR")
            table.insert(valuesCache, string_format("|c%s%d|r", color, cr))
        end

        if YPS.savedVars.showBL then
            local color = GetValueColor(bl, YPS.savedVars.thresholdBL)
            table.insert(tagsCache, "BL")
            table.insert(valuesCache, string_format("|c%s%d%%|r", color, bl))
        end

        YPS.defTagsLabel:SetText(table.concat(tagsCache, newline))
        YPS.defValuesLabel:SetText(table.concat(valuesCache, newline))
    end
    
    return true -- Labels were actually updated
end

function YPS.InitializeSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "Yudo's Power Stats",
        displayName = "Yudo's Power Stats",
        author = "YudoAn",
        version = "1.6.2",
        website = "https://www.esoui.com/downloads/info4323-YudosPowerStats.html",
        registerForRefresh = true,
    }

    local optionsTable = {
        { type = "header", name = "Display Settings" },
        {
            type = "checkbox",
            name = "Lock UI",
            getFunc = function() return YPS.savedVars.locked end,
            setFunc = function(value) 
                YPS.savedVars.locked = value
                YPS.isLocked = value
                YPS.UpdateLockState()
                YPS.ForceUpdate()
            end,
        },
        {
            type = "slider",
            name = "UI Scale",
            min = 0.5, max = 2.0, step = 0.1, decimals = 1,
            getFunc = function() return YPS.savedVars.scale end,
            setFunc = function(value) 
                YPS.savedVars.scale = value 
                YPS.control:SetScale(value)
                YPS.defenseControl:SetScale(value)
                YPS.ForceUpdate()
            end,
        },
        {
            type = "slider",
            name = "Opacity",
            min = 0, max = 100, step = 1,
            getFunc = function() return YPS.savedVars.opacity end,
            setFunc = function(value) 
                YPS.savedVars.opacity = value 
                YPS.UpdateOpacity()
                YPS.ForceUpdate()
            end,
        },
        {
            type = "submenu",
            name = "Offensive Power",
            controls = {
                {
                    type = "checkbox",
                    name = "Show Power",
                    getFunc = function() return YPS.savedVars.showDamage end,
                    setFunc = function(value) 
                        YPS.savedVars.showDamage = value 
                        YPS.UpdateLayout()
                        YPS.ForceUpdate()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Show Penetration",
                    getFunc = function() return YPS.savedVars.showPE end,
                    setFunc = function(value) 
                        YPS.savedVars.showPE = value 
                        YPS.UpdateLayout()
                        YPS.ForceUpdate()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Show Crit Chance",
                    getFunc = function() return YPS.savedVars.showCC end,
                    setFunc = function(value) 
                        YPS.savedVars.showCC = value 
                        YPS.UpdateLayout()
                        YPS.ForceUpdate()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Show Crit Damage",
                    getFunc = function() return YPS.savedVars.showCD end,
                    setFunc = function(value) 
                        YPS.savedVars.showCD = value 
                        YPS.UpdateLayout()
                        YPS.ForceUpdate()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Show Peaks on Hover",
                    getFunc = function() return YPS.savedVars.showPeaksOnHover end,
                    setFunc = function(value) 
                        YPS.savedVars.showPeaksOnHover = value 
                        YPS.ForceUpdate()
                    end,
                    disabled = function() return not (YPS.savedVars.showDamage or YPS.savedVars.showPE or YPS.savedVars.showCC or YPS.savedVars.showCD) end,
                },
                {
                    type = "description",
                    text = "Crit Damage and Penetration values are based on direct bonuses applied to your character and exclude other conditional modifiers.",
                },
            },
        },
        {
            type = "submenu",
            name = "Offensive Thresholds",
            controls = {
                {
                    type = "description",
                    text = "Stats will turn Gold when reaching these values. Set to 0 to disable.",
                },
                {
                    type = "slider",
                    name = "Power Threshold",
                    min = 0, max = 15000, step = 100,
                    getFunc = function() return YPS.savedVars.thresholdPower end,
                    setFunc = function(value) 
                        YPS.savedVars.thresholdPower = value 
                        YPS.ForceUpdate()
                    end,
                },
                {
                    type = "slider",
                    name = "Penetration Threshold",
                    min = 0, max = 33100, step = 100,
                    getFunc = function() return YPS.savedVars.thresholdPE end,
                    setFunc = function(value) 
                        YPS.savedVars.thresholdPE = value 
                        YPS.ForceUpdate()
                    end,
                },
                {
                    type = "slider",
                    name = "Crit Chance Threshold",
                    min = 0, max = 100, step = 1,
                    getFunc = function() return YPS.savedVars.thresholdCC end,
                    setFunc = function(value) 
                        YPS.savedVars.thresholdCC = value 
                        YPS.ForceUpdate()
                    end,
                },
                {
                    type = "slider",
                    name = "Crit Damage Threshold",
                    min = 0, max = 155, step = 1,
                    getFunc = function() return YPS.savedVars.thresholdCD end,
                    setFunc = function(value) 
                        YPS.savedVars.thresholdCD = value 
                        YPS.ForceUpdate()
                    end,
                },
            },
        },
        {
            type = "submenu",
            name = "Defensive Power",
            controls = {
                {
                    type = "checkbox",
                    name = "Show Spell Resistance",
                    getFunc = function() return YPS.savedVars.showSR end,
                    setFunc = function(value) 
                        YPS.savedVars.showSR = value 
                        YPS.UpdateLayout()
                        YPS.ForceUpdate()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Show Physical Resistance",
                    getFunc = function() return YPS.savedVars.showPR end,
                    setFunc = function(value) 
                        YPS.savedVars.showPR = value 
                        YPS.UpdateLayout()
                        YPS.ForceUpdate()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Show Crit Resistance",
                    getFunc = function() return YPS.savedVars.showCR end,
                    setFunc = function(value) 
                        YPS.savedVars.showCR = value 
                        YPS.UpdateLayout()
                        YPS.ForceUpdate()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Show Block Mitigation",
                    getFunc = function() return YPS.savedVars.showBL end,
                    setFunc = function(value) 
                        YPS.savedVars.showBL = value 
                        YPS.UpdateLayout()
                        YPS.ForceUpdate()
                    end,
                },
                {
                    type = "checkbox",
                    name = "Show Peaks on Hover",
                    getFunc = function() return YPS.savedVars.showDefPeaksOnHover end,
                    setFunc = function(value) 
                        YPS.savedVars.showDefPeaksOnHover = value 
                        YPS.ForceUpdate()
                    end,
                    disabled = function() return not (YPS.savedVars.showPR or YPS.savedVars.showSR or YPS.savedVars.showCR or YPS.savedVars.showBL) end,
                },
            },
        },
        {
            type = "submenu",
            name = "Defensive Thresholds",
            controls = {
                {
                    type = "description",
                    text = "Stats will turn Gold when reaching these values. Set to 0 to disable.",
                },
                {
                    type = "slider",
                    name = "Spell Resistance Threshold",
                    min = 0, max = 33100, step = 100,
                    getFunc = function() return YPS.savedVars.thresholdSR end,
                    setFunc = function(value) 
                        YPS.savedVars.thresholdSR = value 
                        YPS.ForceUpdate()
                    end,
                },
                {
                    type = "slider",
                    name = "Physical Resistance Threshold",
                    min = 0, max = 33100, step = 100,
                    getFunc = function() return YPS.savedVars.thresholdPR end,
                    setFunc = function(value) 
                        YPS.savedVars.thresholdPR = value 
                        YPS.ForceUpdate()
                    end,
                },
                {
                    type = "slider",
                    name = "Crit Resistance Threshold",
                    min = 0, max = 8250, step = 50,
                    getFunc = function() return YPS.savedVars.thresholdCR end,
                    setFunc = function(value) 
                        YPS.savedVars.thresholdCR = value 
                        YPS.ForceUpdate()
                    end,
                },
                {
                    type = "slider",
                    name = "Block Mitigation Threshold",
                    min = 0, max = 90, step = 1,
                    getFunc = function() return YPS.savedVars.thresholdBL end,
                    setFunc = function(value) 
                        YPS.savedVars.thresholdBL = value 
                        YPS.ForceUpdate()
                    end,
                },
            },
        },
    }

    local panel = LAM:RegisterAddonPanel(YPS_addonName .. "Options", panelData)
    LAM:RegisterOptionControls(YPS_addonName .. "Options", optionsTable)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(openedPanel)
        if openedPanel == panel then
            SCENE_MANAGER:GetScene("gameMenuInGame"):AddFragment(YPS.powerFragment)
            SCENE_MANAGER:GetScene("gameMenuInGame"):AddFragment(YPS.defFragment)
        end
    end)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(closedPanel)
        if closedPanel == panel then
            SCENE_MANAGER:GetScene("gameMenuInGame"):RemoveFragment(YPS.powerFragment)
            SCENE_MANAGER:GetScene("gameMenuInGame"):RemoveFragment(YPS.defFragment)
        end
    end)
end

function YPS.UpdateLayout()
    -- Power Stats Layout
    local powerActiveCount = 0
    if YPS.savedVars.showDamage then powerActiveCount = powerActiveCount + 1 end
    if YPS.savedVars.showPE then powerActiveCount = powerActiveCount + 1 end
    if YPS.savedVars.showCC then powerActiveCount = powerActiveCount + 1 end
    if YPS.savedVars.showCD then powerActiveCount = powerActiveCount + 1 end
    
    -- Use the Fragment system to handle visibility. This prevents the window 
    -- from "flickering" back into existence when returning from menus if it's disabled.
    if YPS.powerFragment then
        YPS.powerFragment:SetHiddenForReason("Settings", powerActiveCount == 0)
    end
    
    if powerActiveCount > 0 then
        local targetHeight = 12 + (powerActiveCount * 22)
        YPS.control:SetDimensions(88, targetHeight)
    end

    -- Defense Stats Layout
    local defenseActiveCount = 0
    if YPS.savedVars.showPR then defenseActiveCount = defenseActiveCount + 1 end
    if YPS.savedVars.showSR then defenseActiveCount = defenseActiveCount + 1 end
    if YPS.savedVars.showCR then defenseActiveCount = defenseActiveCount + 1 end
    if YPS.savedVars.showBL then defenseActiveCount = defenseActiveCount + 1 end
    
    if YPS.defFragment then
        YPS.defFragment:SetHiddenForReason("Settings", defenseActiveCount == 0)
    end
    
    if defenseActiveCount > 0 then
        local targetHeight = 12 + (defenseActiveCount * 22)
        YPS.defenseControl:SetDimensions(88, targetHeight)
    end
end

function YPS.UpdateOpacity() 
    YPS.bg:SetAlpha(YPS.savedVars.opacity / 100) 
    YPS.defBg:SetAlpha(YPS.savedVars.opacity / 100)
end

function YPS.OnMoveStop(control) 
    if control == YPS.control then
        YPS.savedVars.left = control:GetLeft() 
        YPS.savedVars.top = control:GetTop() 
    elseif control == YPS.defenseControl then
        YPS.savedVars.defLeft = control:GetLeft()
        YPS.savedVars.defTop = control:GetTop()
    end
end

function YPS.UpdateLockState() 
    YPS.control:SetMovable(not YPS.isLocked) 
    YPS.defenseControl:SetMovable(not YPS.isLocked)
    YPS.resizeHandle:SetHidden(YPS.isLocked) 
    YPS.defResizeHandle:SetHidden(YPS.isLocked)
    YPS.savedVars.locked = YPS.isLocked 
end

function YPS.OnResizeStart()
    if YPS.isLocked then return end
    local mouseX, _ = GetUIMousePosition()
    YPS.resizeStartX = mouseX
    YPS.resizeStartScale = YPS.control:GetScale()
    EVENT_MANAGER:RegisterForUpdate(YPS_addonName .. "Resize", 0, YPS.OnResizeUpdate)
    EVENT_MANAGER:RegisterForEvent(YPS_addonName .. "ResizeStop", EVENT_GLOBAL_MOUSE_UP, YPS.OnResizeStop)
end

function YPS.OnResizeUpdate()
    local mouseX, _ = GetUIMousePosition()
    local deltaX = mouseX - YPS.resizeStartX
    local startWidth = 88 * YPS.resizeStartScale
    local newWidth = startWidth + deltaX
    local newScale = zo_clamp(newWidth / 88, 0.5, 2.0)
    YPS.control:SetScale(newScale)
    YPS.defenseControl:SetScale(newScale)
end

function YPS.OnResizeStop()
    EVENT_MANAGER:UnregisterForUpdate(YPS_addonName .. "Resize")
    EVENT_MANAGER:UnregisterForEvent(YPS_addonName .. "ResizeStop", EVENT_GLOBAL_MOUSE_UP)
    YPS.savedVars.scale = YPS.control:GetScale()
end

-- This fires when the player is actually standing in the world
function YPS.OnPlayerActivated(eventCode, initialCall)
    -- Unregister immediately so zone changes don't re-run initialization
    EVENT_MANAGER:UnregisterForEvent(YPS_addonName, EVENT_PLAYER_ACTIVATED)

    if not YPS.isInitialized then
        YPS.isInitialized = true
        YPS.Initialize()
    end
end

-- This fires when the game loads your files into memory
function YPS.OnAddOnLoaded(eventCode, loadedAddonName)
    -- Security check: only proceed if the addon being loaded is THIS one
    if loadedAddonName ~= YPS_addonName then return end
    
    -- Clean up the loader event
    EVENT_MANAGER:UnregisterForEvent(YPS_addonName, EVENT_ADD_ON_LOADED)

    -- Now that we know our files are loaded, wait for the player to be active
    EVENT_MANAGER:RegisterForEvent(YPS_addonName, EVENT_PLAYER_ACTIVATED, YPS.OnPlayerActivated)
end

-- The only global registration needed to kick things off
EVENT_MANAGER:RegisterForEvent(YPS_addonName, EVENT_ADD_ON_LOADED, YPS.OnAddOnLoaded)