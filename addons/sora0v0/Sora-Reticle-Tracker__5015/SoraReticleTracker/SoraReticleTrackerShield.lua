-- Player damage shield timer: largest REMAINING DURATION among real shield buffs.
-- Independent of skill language, source player, class, or scribing choice.
-- Prototype: ABILITY_TYPE_DAMAGESHIELD coverage must be confirmed in game.
SoraReticleTracker = SoraReticleTracker or {}
local SRT = SoraReticleTracker
SRT.Shield = SRT.Shield or {}
local Shield = SRT.Shield
local PREFIX = "SoraReticleTrackerShield"
local MIN_INTERVAL = 0.15
local nextCheck = 0
local lastDuration = 0
local lastShield = 0
local lastAbilityId = 0
local brokenUntil = 0
local BROKEN_INDICATOR_SECONDS = 0.8

-- Attribute visualizer records current shielding magnitude. It does not tell
-- the expiry of each independently applied shield; for that read player buffs.
local function ReadShieldValue()
    if not GetUnitAttributeVisualizerEffectInfo
        or not ATTRIBUTE_VISUAL_POWER_SHIELDING
        or not STAT_MITIGATION or not ATTRIBUTE_HEALTH or not POWERTYPE_HEALTH then
        return nil
    end
    local ok, value = pcall(GetUnitAttributeVisualizerEffectInfo,
        "player", ATTRIBUTE_VISUAL_POWER_SHIELDING,
        STAT_MITIGATION, ATTRIBUTE_HEALTH, POWERTYPE_HEALTH)
    if not ok then return nil end
    return tonumber(value) or 0
end

local function FindLongestShieldBuff(now)
    local longest, selectedId = 0, 0
    if not GetNumBuffs or not GetUnitBuffInfo or not ABILITY_TYPE_DAMAGESHIELD then
        return longest, selectedId
    end
    local n = GetNumBuffs("player") or 0
    for index = 1, n do
        local _, _, ending, _, _, _, _, _, abilityType, _, abilityId = GetUnitBuffInfo("player", index)
        local remaining = (tonumber(ending) or 0) - now
        if abilityType == ABILITY_TYPE_DAMAGESHIELD and remaining > longest then
            longest, selectedId = remaining, abilityId or 0
        end
    end
    return longest, selectedId
end

local function FormatDuration(seconds)
    if seconds < 3 then return string.format("%.1f", math.max(0, seconds)) end
    return tostring(math.ceil(seconds))
end

local function SetShieldLabelStyle(isBroken)
    if not SRT.shieldLabel or not SRT.sv then return end
    local normalSize = tonumber(SRT.sv.shieldTextSize) or 35
    if isBroken then
        local breakSize = zo_round(normalSize * 1.35)
        SRT.shieldLabel:SetDimensions(breakSize + 34, breakSize + 34)
        SRT.shieldLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", breakSize))
    else
        SRT.shieldLabel:SetDimensions((tonumber(SRT.sv.shieldIconSize) or 78) + 24, (tonumber(SRT.sv.shieldIconSize) or 78) + 24)
        SRT.shieldLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", zo_round(normalSize)))
    end
end

function Shield.ApplyPosition()
    local window = SRT.shieldWindow
    if not window or not SRT.sv then return end
    window:ClearAnchors()
    window:SetAnchor(CENTER, GuiRoot, CENTER,
        SRT.sv.shieldOffsetX or -60, SRT.sv.shieldOffsetY or 150)
end

function Shield.Preview()
    if not SRT.shieldWindow then return end
    SetShieldLabelStyle(false)
    SRT.shieldWindow:SetHidden(false)
    SRT.shieldLabel:SetText("12")
    SRT.shieldLabel:SetColor(1, 1, 1, 1)
end

function Shield.Invalidate()
    nextCheck = 0
end

function Shield.Update(now)
    if not SRT.shieldWindow or not SRT.sv then return end
    if SRT.moveTarget == "shield" then
        Shield.Preview()
        return
    end
    if not SRT.sv.shieldEnabled then
        brokenUntil = 0
        SRT.shieldWindow:SetHidden(true)
        return
    end
    now = now or GetFrameTimeSeconds()
    if now >= nextCheck then
        nextCheck = now + MIN_INTERVAL
        local value = ReadShieldValue()
        if value ~= nil then
            if lastShield > 0 and value <= 0 and (Shield.lastEnd or 0) > now + 0.25 then
                -- Shield capacity vanished before the tracked effect's natural expiry.
                -- Trigger once at complete loss, never for partial shield damage.
                brokenUntil = now + BROKEN_INDICATOR_SECONDS
            elseif value > 0 then
                brokenUntil = 0 -- a new shield replaces any old break warning
            end
            lastShield = value
        end
        if lastShield > 0 then
            lastDuration, lastAbilityId = FindLongestShieldBuff(now)
        else
            lastDuration, lastAbilityId = 0, 0
        end
    end
    if lastShield <= 0 or lastDuration <= 0 then
        if now < brokenUntil and SRT.sv.shieldEnabled then
            SetShieldLabelStyle(true)
            SRT.shieldWindow:SetHidden(false)
            SRT.shieldLabel:SetText("×")
            SRT.shieldLabel:SetColor(1.0, 0.12, 0.10, 1)
        else
            SRT.shieldWindow:SetHidden(true)
        end
        return
    end
    -- End times are absolute; after caching still count down every HUD tick.
    local endTime = Shield.lastEnd or 0
    if Shield.lastId ~= lastAbilityId or Shield.lastSample ~= nextCheck then
        Shield.lastEnd = now + lastDuration
        Shield.lastId = lastAbilityId
        Shield.lastSample = nextCheck
        endTime = Shield.lastEnd
    end
    local remaining = endTime - now
    if remaining <= 0 then
        SRT.shieldWindow:SetHidden(true)
        return
    end
    SetShieldLabelStyle(false)
    SRT.shieldWindow:SetHidden(false)
    SRT.shieldLabel:SetText(FormatDuration(remaining))
    if remaining < 1.6 then
        SRT.shieldLabel:SetColor(1.0, 0.25, 0.18, 1)
    elseif remaining <= 3 then
        SRT.shieldLabel:SetColor(1.0, 0.82, 0.18, 1)
    else
        SRT.shieldLabel:SetColor(1, 1, 1, 1)
    end
end

function Shield.Initialize()
    Shield.Invalidate()
    -- Events invalidate the cached result. Display timer is throttled in Update().
    EVENT_MANAGER:RegisterForEvent(PREFIX .. "Buff", EVENT_EFFECT_CHANGED,
        function(_, _, _, _, unitTag) if unitTag == "player" then Shield.Invalidate() end end)
    EVENT_MANAGER:AddFilterForEvent(PREFIX .. "Buff", EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG, "player")
    for _, eventId in ipairs({ EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED,
                                 EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED,
                                 EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED }) do
        if eventId then
            EVENT_MANAGER:RegisterForEvent(PREFIX .. tostring(eventId), eventId,
                function(_, unitTag, visualType)
                    if unitTag == "player" and visualType == ATTRIBUTE_VISUAL_POWER_SHIELDING then
                        Shield.Invalidate()
                    end
                end)
            EVENT_MANAGER:AddFilterForEvent(PREFIX .. tostring(eventId), eventId,
                REGISTER_FILTER_UNIT_TAG, "player")
        end
    end
end
