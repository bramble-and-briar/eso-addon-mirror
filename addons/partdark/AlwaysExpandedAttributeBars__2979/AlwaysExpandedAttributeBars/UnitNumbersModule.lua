-- AEAB Module: Unit Frame Full Numbers
-- A sub-addon that can be toggled separately in the settings menu
-- (requires a UI reload). Functionality modeled after ImprovedAttributeBars:
--   * full numbers (current / max / percent) on the player attribute bars
--   * full numbers on the target health bar
--   * damage absorption display ([+N] - power shielding)
--   * heal absorption display ([-N] - trauma)
--   * full numbers on the boss health bar (separate from the target bar)
--   * optional thousands separators (e.g. 27,856 or 12.345.678)

local AEAB = AEAB or {}
AEAB.name = "AlwaysExpandedAttributeBars"

AEAB.modules = AEAB.modules or {}

local module = {}

local HEALTH   = COMBAT_MECHANIC_FLAGS_HEALTH
local MAGICKA  = COMBAT_MECHANIC_FLAGS_MAGICKA
local STAMINA  = COMBAT_MECHANIC_FLAGS_STAMINA

local PLAYER_UNIT_TAG = 'player'
local TARGET_UNIT_TAG = 'reticleover'

-- The target bar hooked by HookTargetBar, used for instant refresh
local hookedTargetBar = nil

function module.IsEnabled()
    return AEAB.savedVars ~= nil and AEAB.savedVars.enableUnitNumbersModule == true
end

----------------------------------------------------------
-- Number formatting
----------------------------------------------------------

-- Insert a thousands separator every 3 digits: 27856 -> 27,856,
-- 12345678 -> 12.345.678. Uses the global separator from the settings,
-- unless an explicit separator is passed ('' = no separator).
local function GroupDigits(value, separator)
    local sv = AEAB.savedVars
    local sep = separator
    if sep == nil then
        sep = (sv and sv.numberSeparator) or ''
    end
    if sep == '' then
        return tostring(value)
    end
    local s = (tostring(value):reverse():gsub('(%d%d%d)', '%1' .. sep)):reverse()
    if s:sub(1, #sep) == sep then
        s = s:sub(#sep + 1)
    end
    return s
end

-- Build the absorption values placed right after the current number,
-- the same layout as ImprovedAttributeBars: "cur [+s] [-t] / max (pct%)"
-- [+N] - damage absorption (shield), [-N] - heal absorption (trauma)
local function AbsorptionsAfterCurrent(shield, trauma, separator)
    local text = ""
    if (shield or 0) > 0 then
        text = text .. string.format(" [+%s]", GroupDigits(shield, separator))
    end
    if (trauma or 0) > 0 then
        text = text .. string.format(" [-%s]", GroupDigits(trauma, separator))
    end
    return text
end

-- style: 'currentmax' | 'currentmaxpercent' | 'current' | 'percent'
-- separator: optional, overrides the global thousands separator
local function FormatNumber(current, maximum, shield, trauma, style, separator)
    if not (maximum and maximum > 0) then
        return ""
    end

    local percent = zo_floor(100 * current / maximum)
    local absorptions = AbsorptionsAfterCurrent(shield, trauma, separator)
    local text

    if style == 'percent' then
        text = string.format("%d%%", percent) .. absorptions
    elseif style == 'current' then
        text = GroupDigits(current, separator) .. absorptions
    elseif style == 'currentmaxpercent' then
        text = GroupDigits(current, separator) .. absorptions .. " / " .. GroupDigits(maximum, separator) .. string.format(" (%d%%)", percent)
    else -- 'currentmax'
        text = GroupDigits(current, separator) .. absorptions .. " / " .. GroupDigits(maximum, separator)
    end

    return text
end

----------------------------------------------------------
-- Shield (damage absorption) and trauma (heal absorption) tracking
----------------------------------------------------------

local function GetCurrentShieldAndTrauma(unitTag)
    local shield = GetUnitAttributeVisualizerEffectInfo(unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION, ATTRIBUTE_HEALTH, HEALTH)
    local trauma = GetUnitAttributeVisualizerEffectInfo(unitTag, ATTRIBUTE_VISUAL_TRAUMA, STAT_MITIGATION, ATTRIBUTE_HEALTH, HEALTH)
    return shield, trauma
end

local function RegisterShieldAndTraumaUpdate(unitTag, callback)
    local name = AEAB.name .. '_UnitNumbers' .. unitTag
    for eventCode = EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED do
        EVENT_MANAGER:RegisterForEvent(name, eventCode, callback)
        EVENT_MANAGER:AddFilterForEvent(name, eventCode, REGISTER_FILTER_UNIT_TAG, unitTag)
    end
end

----------------------------------------------------------
-- Player attribute bars (health / magicka / stamina)
----------------------------------------------------------

local function RefreshPlayerBar(bar)
    local current, _, effectiveMax = GetUnitPower(bar:GetEffectiveUnitTag(), bar.powerType)
    bar:UpdateResourceNumbersLabel(current, effectiveMax)
end

local function HookPlayerBars()
    local sv = AEAB.savedVars

    local hookFunc = function(self, current, maximum)
        local label = self.control.resourceNumbersLabel
        if label then
            local shield, trauma
            if self.powerType == HEALTH then
                shield = self.aebShield
                trauma = self.aebTrauma
                if not sv.numbersShowShield then shield = nil end
                if not sv.numbersShowTrauma then trauma = nil end
            end
            label:SetText(FormatNumber(current, maximum, shield, trauma, sv.playerNumberStyle or 'currentmaxpercent'))
        end
        return true
    end

    for _, bar in ipairs(PLAYER_ATTRIBUTE_BARS.bars) do
        if bar:GetEffectiveUnitTag() == PLAYER_UNIT_TAG and (bar.powerType == HEALTH or bar.powerType == MAGICKA or bar.powerType == STAMINA) then
            ZO_PreHook(bar, 'UpdateResourceNumbersLabel', hookFunc)

            if bar.powerType == HEALTH then
                bar.aebShield, bar.aebTrauma = GetCurrentShieldAndTrauma(PLAYER_UNIT_TAG)
                RegisterShieldAndTraumaUpdate(PLAYER_UNIT_TAG, function(eventCode, _, unitAttributeVisual, _, _, _, value, newValue)
                    if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING or unitAttributeVisual == ATTRIBUTE_VISUAL_TRAUMA then
                        if eventCode == EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED then
                            value = 0
                        elseif eventCode == EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED then
                            value = newValue
                        end
                        if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
                            bar.aebShield = value
                        else
                            bar.aebTrauma = value
                        end
                        RefreshPlayerBar(bar)
                    end
                end)
            end

            RefreshPlayerBar(bar)
        end
    end
end

----------------------------------------------------------
-- Target health bar (full numbers)
----------------------------------------------------------

local function HookTargetBar()
    if not UNIT_FRAMES or not UNIT_FRAMES.GetFrame then return end
    local unitFrame = UNIT_FRAMES:GetFrame(TARGET_UNIT_TAG)
    local bar = unitFrame and unitFrame.healthBar
    local numbersLabel = bar and bar.resourceNumbersLabel
    if not (bar and numbersLabel) then return end

    hookedTargetBar = bar

    -- Keep the numbers visible on top of the bar
    numbersLabel:SetDrawTier(DT_HIGH)
    numbersLabel:SetDrawLayer(DL_OVERLAY)
    numbersLabel:SetDrawLevel(10)

    ZO_PreHook(bar, 'UpdateText', function(self)
        -- Make sure the numbers are never hidden (e.g. for damage-immune NPCs)
        numbersLabel:SetHidden(false)

        local sv = AEAB.savedVars
        if not sv or not sv.targetShowNumbers then
            numbersLabel:SetText("")
            return true
        end

        local shield, trauma
        if sv.numbersShowShield or sv.numbersShowTrauma then
            shield, trauma = GetCurrentShieldAndTrauma(TARGET_UNIT_TAG)
            if not sv.numbersShowShield then shield = nil end
            if not sv.numbersShowTrauma then trauma = nil end
        end
        numbersLabel:SetText(FormatNumber(self.currentValue, self.maxValue, shield, trauma, sv.targetNumberStyle or 'currentmaxpercent'))
        return true
    end)

    RegisterShieldAndTraumaUpdate(TARGET_UNIT_TAG, function(_, _, unitAttributeVisual)
        if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING or unitAttributeVisual == ATTRIBUTE_VISUAL_TRAUMA then
            if hookedTargetBar then
                hookedTargetBar:UpdateText()
            end
        end
    end)

    bar:UpdateText()
end

----------------------------------------------------------
-- Boss health bar (separate from the target bar)
----------------------------------------------------------

local function HookBossBar()
    if not BOSS_BAR then return end

    SecurePostHook(BOSS_BAR, 'RefreshBossHealthBar', function(self)
        local sv = AEAB.savedVars
        if not sv or not sv.bossShowNumbers then
            if self.healthText then
                self.healthText:SetText("")
            end
            return
        end

        local total, totalMax = 0, 0
        for _, bossEntry in pairs(self.bossHealthValues) do
            -- The game stores the values as "health" / "maxHealth"
            -- (see BossBar:RefreshBossHealth in bossbar.lua); they may be
            -- missing while the power update is still being processed,
            -- so guard against nils
            total = total + (bossEntry.health or 0)
            totalMax = totalMax + (bossEntry.maxHealth or 0)
        end

        self.healthText:SetText(FormatNumber(total, totalMax, nil, nil, sv.bossNumberStyle or 'currentmaxpercent', sv.bossNumberSeparator))
    end)

    BOSS_BAR:RefreshBossHealthBar()
end

----------------------------------------------------------
-- Player level / XP bar (current XP / required XP (percent))
----------------------------------------------------------

local function HookXPBar()
    if not PLAYER_PROGRESS_BAR then return end

    -- The game's XP bar has no label inside the bar, so create one,
    -- centered on the bar control
    local barControl = PLAYER_PROGRESS_BAR.barControl
    local label = barControl and WINDOW_MANAGER:CreateControl(nil, barControl, CT_LABEL)
    if label then
        label:SetAnchor(CENTER, barControl, CENTER, 0, 0)
        label:SetDrawLayer(DL_OVERLAY)
        label:SetDrawLevel(10)
    end

    SecurePostHook(PLAYER_PROGRESS_BAR, 'RefreshCurrentBar', function(self)
        if not label then return end

        local sv = AEAB.savedVars
        if not sv or not sv.xpBarShowNumbers then
            label:SetText("")
            return
        end

        -- The bar may not have a type yet (it has never been shown), and
        -- GetMostRecentlyShownInfo -> GetCurrentInfo would error on a nil
        -- bar type, so guard it
        if not self.barType or not self.barMode then
            label:SetText("")
            return
        end

        pcall(function()
            local level, current, levelSize = self:GetMostRecentlyShownInfo()
            if not (levelSize and levelSize > 0) then
                label:SetText("")
                return
            end

            -- Use the same font as the attribute bar numbers
            label:SetFont(string.format('%s|%d|%s',
                sv.fontFace or '$(MEDIUM_FONT)',
                sv.fontSize or 16,
                sv.fontStyle or 'soft-shadow-thick'))
            -- The XP bar always uses a comma thousands separator
            -- (123456 -> 123,456)
            label:SetText(FormatNumber(current, levelSize, nil, nil, 'currentmaxpercent', ','))
        end)
    end)

    -- Initial refresh is safe to call even when the bar has no type yet
    pcall(function() PLAYER_PROGRESS_BAR:RefreshCurrentBar() end)
end

----------------------------------------------------------
-- Public API (used by the settings menu for instant refresh)
----------------------------------------------------------

-- Re-apply the numbers to all hooked bars with the current settings
function module.Refresh()
    if not module.IsEnabled() then return end

    pcall(function()
        if PLAYER_ATTRIBUTE_BARS and PLAYER_ATTRIBUTE_BARS.bars then
            for _, bar in ipairs(PLAYER_ATTRIBUTE_BARS.bars) do
                if bar.GetEffectiveUnitTag and bar:GetEffectiveUnitTag() == PLAYER_UNIT_TAG
                    and bar.powerType and bar.UpdateResourceNumbersLabel then
                    RefreshPlayerBar(bar)
                end
            end
        end

        if hookedTargetBar and hookedTargetBar.UpdateText then
            hookedTargetBar:UpdateText()
        end

        if BOSS_BAR and BOSS_BAR.RefreshBossHealthBar then
            BOSS_BAR:RefreshBossHealthBar()
        end

        if PLAYER_PROGRESS_BAR and PLAYER_PROGRESS_BAR.RefreshCurrentBar then
            PLAYER_PROGRESS_BAR:RefreshCurrentBar()
        end
    end)
end

----------------------------------------------------------
-- Bootstrap
----------------------------------------------------------

local hooksInstalled = false

local function OnPlayerActivated()
    if not module.IsEnabled() then return end
    if hooksInstalled then return end
    hooksInstalled = true

    local ok, err = pcall(function()
        HookPlayerBars()
        HookTargetBar()
        HookBossBar()
        HookXPBar()
    end)
    if not ok then
        d("[AEAB] Unit numbers module error: " .. tostring(err))
    end
end

EVENT_MANAGER:RegisterForEvent(AEAB.name .. '_UnitNumbers_PlayerActivated', EVENT_PLAYER_ACTIVATED, function()
    zo_callLater(OnPlayerActivated, 50)
end)

AEAB.modules.unitNumbers = module
