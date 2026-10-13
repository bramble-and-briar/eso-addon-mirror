-- BuffDebuffBar+ by BLKx777
-- Console-only ESO addon. No chat commands.
-- v1.2.5: adds visible stack count numbers inside buff/debuff icons.

buffdebuffbarplus = buffdebuffbarplus or {}

local ADDON = buffdebuffbarplus
ADDON.name = "buffdebuffbarplus"
ADDON.title = "buffdebuffbarplus"
ADDON.author = "BLKx777"
ADDON.version = "1.2.5"
ADDON.settingsRegistered = false
ADDON.effects = {}
ADDON.sortedEffects = {}
ADDON.nativeControls = {}

local defaults = {
    enabled = true,
    customTracker = true,
    splitMode = false,
    hideNativeAttempt = false,
    maxIcons = 12,
    splitIconsPerRow = 6,
    rowSpacing = 4,
    durationTextScale = 125,
    stackCountTextScale = 135,

    combinedX = 0,
    combinedY = -190,
    combinedScale = 100,
    combinedPreview = false,

    buffsX = -260,
    buffsY = -190,
    buffsScale = 100,
    buffsPreview = false,

    debuffsX = 260,
    debuffsY = -190,
    debuffsScale = 100,
    debuffsPreview = false,
}
ADDON.defaults = defaults

local function SV()
    return ADDON.saved or defaults
end

local function TryControl(name)
    local c = _G[name]
    if c and c.ClearAnchors and c.SetAnchor then return c end
    return nil
end

local function MoveControl(control, x, y, scalePercent)
    if not control then return false end
    if control.ClearAnchors then control:ClearAnchors() end
    if control.SetAnchor then control:SetAnchor(CENTER, GuiRoot, CENTER, x or 0, y or 0) end
    if control.SetScale then control:SetScale((scalePercent or 100) / 100) end
    return true
end

local function EnsureTopLevel(name)
    local c = _G[name]
    if not c then
        c = WINDOW_MANAGER:CreateTopLevelWindow(name)
        c:SetMouseEnabled(false)
        c:SetMovable(false)
        c:SetClampedToScreen(false)
        c:SetDrawLayer(DL_OVERLAY)
        c:SetDrawTier(DT_HIGH)
        c:SetHidden(true)
    end
    return c
end

local function EffectIsDebuff(effectType, buffType)
    if BUFF_EFFECT_TYPE_DEBUFF and effectType == BUFF_EFFECT_TYPE_DEBUFF then return true end
    if BUFF_TYPE_DEBUFF and buffType == BUFF_TYPE_DEBUFF then return true end
    return false
end

local function EffectIsBuff(effectType, buffType)
    if BUFF_EFFECT_TYPE_BUFF and effectType == BUFF_EFFECT_TYPE_BUFF then return true end
    if BUFF_TYPE_BUFF and buffType == BUFF_TYPE_BUFF then return true end
    return not EffectIsDebuff(effectType, buffType)
end

local function FormatTime(seconds)
    if not seconds or seconds <= 0 then return "" end
    if seconds > 3600 then return "" end
    if seconds >= 60 then
        return tostring(math.floor((seconds / 60) + 0.5)) .. "m"
    end
    return tostring(math.floor(seconds + 0.5)) .. "s"
end

local function MakeSlot(parent, name, index)
    local slot = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    slot:SetDimensions(46, 74)
    slot:SetAnchor(LEFT, parent, LEFT, (index - 1) * 42, 0)

    local bg = WINDOW_MANAGER:CreateControl(name .. "Bg", slot, CT_BACKDROP)
    bg:SetDimensions(34, 34)
    bg:SetAnchor(TOP, slot, TOP, 0, 0)
    bg:SetCenterColor(0, 0, 0, 0.45)
    bg:SetEdgeColor(0, 0, 0, 1)
    bg:SetEdgeTexture(nil, 1, 1, 1)

    local icon = WINDOW_MANAGER:CreateControl(name .. "Icon", bg, CT_TEXTURE)
    icon:SetDimensions(30, 30)
    icon:SetAnchor(CENTER, bg, CENTER, 0, 0)

    local countBg = WINDOW_MANAGER:CreateControl(name .. "CountBg", bg, CT_BACKDROP)
    countBg:SetDimensions(18, 18)
    countBg:SetAnchor(TOPRIGHT, bg, TOPRIGHT, -1, 1)
    countBg:SetCenterColor(0, 0, 0, 0.72)
    countBg:SetEdgeColor(0, 0, 0, 1)
    countBg:SetEdgeTexture(nil, 1, 1, 1)
    countBg:SetHidden(true)

    local count = WINDOW_MANAGER:CreateControl(name .. "Count", countBg, CT_LABEL)
    count:SetFont("$(BOLD_FONT)|16|soft-shadow-thick")
    count:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    count:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    count:SetDimensions(18, 18)
    count:SetAnchor(CENTER, countBg, CENTER, 0, 0)
    count:SetColor(1, 1, 1, 1)

    local time = WINDOW_MANAGER:CreateControl(name .. "Time", slot, CT_LABEL)
    time:SetFont("$(BOLD_FONT)|40|soft-shadow-thick")
    time:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    time:SetVerticalAlignment(TEXT_ALIGN_TOP)
    time:SetDimensions(70, 34)
    time:SetAnchor(TOP, bg, BOTTOM, 0, 0)
    time:SetColor(1, 1, 1, 1)

    slot.bg = bg
    slot.icon = icon
    slot.countBg = countBg
    slot.count = count
    slot.time = time
    return slot
end

local function EnsureTracker(key, labelText, r, g, b)
    local name = "buffdebuffbarplus" .. key .. "Tracker"
    local c = EnsureTopLevel(name)
    if c.created then return c end
    c.created = true
    c:SetDimensions(780, 78)

    -- Header labels intentionally removed for clean console HUD presentation.
    c.label = nil
    c.slots = {}
    for i = 1, 36 do
        c.slots[i] = MakeSlot(c, name .. "Slot" .. i, i)
    end
    return c
end

function ADDON:EnsureTrackers()
    self.combinedTracker = self.combinedTracker or EnsureTracker("Combined", "buffdebuffbarplus", 0.95, 0.82, 0.35)
    self.buffsTracker = self.buffsTracker or EnsureTracker("Buffs", "Buffs", 0.25, 0.9, 0.25)
    self.debuffsTracker = self.debuffsTracker or EnsureTracker("Debuffs", "Debuffs", 0.95, 0.2, 0.2)
end

local menuSceneNames = {
    "gameMenuInGame",
    "gameMenuInGamepad",
    "gamepad_menu_root",
    "gamepad_inventory_root",
    "gamepad_skills_root",
    "gamepad_championPerks",
    "gamepad_map_root",
    "gamepad_quest_journal",
    "gamepad_social_root",
    "gamepad_addons",
    "gamepad_options_root",
}

function ADDON:IsMenuUiOpen()
    if IsGameCameraUIModeActive and IsGameCameraUIModeActive() then return true end

    if SCENE_MANAGER then
        if SCENE_MANAGER.IsInUIMode then
            local ok, result = pcall(function() return SCENE_MANAGER:IsInUIMode() end)
            if ok and result then return true end
        end

        if SCENE_MANAGER.IsShowing then
            for _, sceneName in ipairs(menuSceneNames) do
                local ok, showing = pcall(function() return SCENE_MANAGER:IsShowing(sceneName) end)
                if ok and showing then return true end
            end
        end
    end

    return false
end

function ADDON:UpdateTracker(control, list, preview, maxIcons)
    if not control or not control.slots then return end
    maxIcons = maxIcons or 12

    local sv = SV()
    local wrapMax = control.wrapMax or maxIcons
    if wrapMax < 1 then wrapMax = 1 end

    local rowSpacing = sv.rowSpacing or 4
    local durationFontSize = math.max(10, math.floor(14 * ((sv.durationTextScale or 125) / 100)))
    local durationFont = "$(BOLD_FONT)|" .. tostring(durationFontSize) .. "|soft-shadow-thick"
    local stackFontSize = math.max(10, math.floor(12 * ((sv.stackCountTextScale or 135) / 100)))
    local stackFont = "$(BOLD_FONT)|" .. tostring(stackFontSize) .. "|soft-shadow-thick"
    local stackBoxSize = math.max(18, stackFontSize + 8)
    local slotSpacingX = 42
    local slotSpacingY = math.max(62, 42 + durationFontSize + rowSpacing)
    local now = GetFrameTimeSeconds and GetFrameTimeSeconds() or 0

    local visibleCount = 0
    if list then visibleCount = math.min(#list, maxIcons) end
    if preview and visibleCount < 6 then visibleCount = math.min(6, maxIcons) end

    local rows = math.max(1, math.ceil(visibleCount / wrapMax))
    if control.SetDimensions then
        control:SetDimensions(math.max(48, wrapMax * slotSpacingX), math.max(78, rows * slotSpacingY))
    end

    for i = 1, #control.slots do
        local slot = control.slots[i]
        local effect = list and list[i] or nil
        local shouldShowEffect = i <= maxIcons and effect ~= nil
        local shouldShowPreview = (not shouldShowEffect) and preview and i <= math.min(6, maxIcons)

        if shouldShowEffect or shouldShowPreview then
            local col = (i - 1) % wrapMax
            local row = math.floor((i - 1) / wrapMax)
            slot:ClearAnchors()
            slot:SetAnchor(TOPLEFT, control, TOPLEFT, col * slotSpacingX, row * slotSpacingY)
        end

        if shouldShowEffect then
            slot.icon:SetTexture(effect.icon or "/esoui/art/icons/icon_missing.dds")
            local stackCount = tonumber(effect.stackCount) or 0
            local showStack = stackCount > 1
            slot.countBg:SetDimensions(stackBoxSize, stackBoxSize)
            slot.count:SetDimensions(stackBoxSize, stackBoxSize)
            slot.count:SetFont(stackFont)
            slot.count:SetText(showStack and tostring(stackCount) or "")
            slot.countBg:SetHidden(not showStack)
            slot.time:SetFont(durationFont)
            slot.time:SetText(FormatTime((effect.endTime or 0) - now))
            slot:SetHidden(false)
        elseif shouldShowPreview then
            slot.icon:SetTexture("/esoui/art/icons/ability_mage_065.dds")
            local previewStack = (i == 3 and "2") or (i == 5 and "4") or ""
            slot.countBg:SetDimensions(stackBoxSize, stackBoxSize)
            slot.count:SetDimensions(stackBoxSize, stackBoxSize)
            slot.count:SetFont(stackFont)
            slot.count:SetText(previewStack)
            slot.countBg:SetHidden(previewStack == "")
            slot.time:SetFont(durationFont)
            slot.time:SetText(tostring(7 + i) .. "s")
            slot:SetHidden(false)
        else
            if slot.countBg then slot.countBg:SetHidden(true) end
            slot:SetHidden(true)
        end
    end
end

function ADDON:BuildSortedEffects()
    local now = GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
    local buffs, debuffs, combined = {}, {}, {}

    for _, e in pairs(self.effects) do
        if e and e.name and e.name ~= "" then
            if not e.endTime or e.endTime == 0 or e.endTime > now then
                table.insert(combined, e)
                if e.isDebuff then table.insert(debuffs, e) else table.insert(buffs, e) end
            end
        end
    end

    local sorter = function(a, b)
        local ae = a.endTime or 0
        local be = b.endTime or 0
        if ae == 0 and be ~= 0 then return false end
        if be == 0 and ae ~= 0 then return true end
        return ae < be
    end
    table.sort(combined, sorter)
    table.sort(buffs, sorter)
    table.sort(debuffs, sorter)

    self.sortedEffects.combined = combined
    self.sortedEffects.buffs = buffs
    self.sortedEffects.debuffs = debuffs
end

function ADDON:RefreshCustomTrackers()
    local sv = SV()
    self:EnsureTrackers()
    self:BuildSortedEffects()

    local showCustom = sv.enabled
    local combinedPreview = sv.combinedPreview and not sv.splitMode
    local buffsPreview = sv.buffsPreview and sv.splitMode
    local debuffsPreview = sv.debuffsPreview and sv.splitMode

    MoveControl(self.combinedTracker, sv.combinedX, sv.combinedY, sv.combinedScale)
    MoveControl(self.buffsTracker, sv.buffsX, sv.buffsY, sv.buffsScale)
    MoveControl(self.debuffsTracker, sv.debuffsX, sv.debuffsY, sv.debuffsScale)

    self.combinedTracker.wrapMax = sv.maxIcons or 12
    self.buffsTracker.wrapMax = sv.splitIconsPerRow or 6
    self.debuffsTracker.wrapMax = sv.splitIconsPerRow or 6

    self:UpdateTracker(self.combinedTracker, self.sortedEffects.combined, combinedPreview, sv.maxIcons or 12)
    self:UpdateTracker(self.buffsTracker, self.sortedEffects.buffs, buffsPreview, #self.buffsTracker.slots)
    self:UpdateTracker(self.debuffsTracker, self.sortedEffects.debuffs, debuffsPreview, #self.debuffsTracker.slots)

    local hasCombined = (#self.sortedEffects.combined > 0) or combinedPreview
    local hasBuffs = (#self.sortedEffects.buffs > 0) or buffsPreview
    local hasDebuffs = (#self.sortedEffects.debuffs > 0) or debuffsPreview

    if self:IsMenuUiOpen() then
        self.combinedTracker:SetHidden(true)
        self.buffsTracker:SetHidden(true)
        self.debuffsTracker:SetHidden(true)
        return
    end

    self.combinedTracker:SetHidden(not (showCustom and not sv.splitMode and hasCombined))
    self.buffsTracker:SetHidden(not (showCustom and sv.splitMode and hasBuffs))
    self.debuffsTracker:SetHidden(not (showCustom and sv.splitMode and hasDebuffs))
end

function ADDON:FindNativeControls()
    self.nativeControls = {
        TryControl("ZO_PlayerBuffs"),
        TryControl("ZO_PlayerBuffsTopLevel"),
        TryControl("ZO_PlayerBuffsContainer"),
        TryControl("ZO_PlayerAttributeBuffs"),
        TryControl("ZO_PlayerAttributeBuffsContainer"),
        TryControl("ZO_BuffTracker"),
        TryControl("ZO_BuffDebuffContainer"),
        TryControl("ZO_PlayerAttribute_Buffs"),
        TryControl("ZO_PlayerAttributeBuffTracker"),
        TryControl("ZO_UnitFrames_PlayerBuffs"),
        TryControl("ZO_UnitFrames_PlayerBuffsContainer"),
        TryControl("ZO_PlayerDebuffs"),
        TryControl("ZO_PlayerDebuffsTopLevel"),
        TryControl("ZO_PlayerAttributeDebuffs"),
        TryControl("ZO_PlayerAttributeDebuffTracker"),
        TryControl("ZO_UnitFrames_PlayerDebuffs"),
        TryControl("ZO_UnitFrames_PlayerDebuffsContainer"),
    }
end

function ADDON:ApplyNativeVisibility()
    local sv = SV()
    self:FindNativeControls()
    for _, c in ipairs(self.nativeControls or {}) do
        if c and c.SetHidden then c:SetHidden(sv.enabled and sv.customTracker and sv.hideNativeAttempt) end
    end
end

function ADDON:OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
    if unitTag ~= "player" or not effectSlot then return end

    if changeType == EFFECT_RESULT_FADED then
        self.effects[effectSlot] = nil
    else
        self.effects[effectSlot] = {
            slot = effectSlot,
            name = effectName,
            beginTime = beginTime,
            endTime = endTime,
            stackCount = stackCount or 0,
            icon = iconName,
            buffType = buffType,
            effectType = effectType,
            abilityId = abilityId,
            isDebuff = EffectIsDebuff(effectType, buffType),
        }
    end
    self:RefreshCustomTrackers()
end

function ADDON:FullEffectScan()
    self.effects = {}
    if not GetNumBuffs or not GetUnitBuffInfo then return end

    local count = GetNumBuffs("player") or 0
    for i = 1, count do
        local name, beginTime, endTime, buffSlot, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, abilityId = GetUnitBuffInfo("player", i)
        if name and name ~= "" then
            self.effects[buffSlot or i] = {
                slot = buffSlot or i,
                name = name,
                beginTime = beginTime,
                endTime = endTime,
                stackCount = stackCount or 0,
                icon = iconName,
                buffType = buffType,
                effectType = effectType,
                abilityId = abilityId,
                isDebuff = EffectIsDebuff(effectType, buffType),
            }
        end
    end
    self:RefreshCustomTrackers()
end

function ADDON:ApplyLayout()
    self:EnsureTrackers()
    self:RefreshCustomTrackers()
    self:ApplyNativeVisibility()
end

local function AddSection(panel, text)
    panel:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = text })
end

local function AddLabel(panel, text)
    panel:AddSetting({ type = LibHarvensAddonSettings.ST_LABEL, label = text })
end

local function AddCheckbox(panel, label, tooltip, key, disabledFunction)
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = label,
        tooltip = tooltip,
        default = defaults[key],
        getFunction = function() return SV()[key] end,
        setFunction = function(value)
            SV()[key] = value and true or false
            ADDON:ApplyLayout()
        end,
        disable = disabledFunction,
    })
end

local function AddSlider(panel, label, tooltip, key, minValue, maxValue, disabledFunction)
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = label,
        tooltip = tooltip,
        min = minValue,
        max = maxValue,
        step = 1,
        format = "%d",
        default = defaults[key],
        getFunction = function() return SV()[key] end,
        setFunction = function(value)
            SV()[key] = tonumber(value) or defaults[key]
            ADDON:ApplyLayout()
        end,
        disable = disabledFunction,
    })
end

function ADDON:SaveCurrentPosition(forceReload)
    local sv = SV()

    sv.splitMode = sv.splitMode and true or false

    sv.combinedX = tonumber(sv.combinedX) or defaults.combinedX
    sv.combinedY = tonumber(sv.combinedY) or defaults.combinedY
    sv.combinedScale = tonumber(sv.combinedScale) or defaults.combinedScale

    sv.buffsX = tonumber(sv.buffsX) or defaults.buffsX
    sv.buffsY = tonumber(sv.buffsY) or defaults.buffsY
    sv.buffsScale = tonumber(sv.buffsScale) or defaults.buffsScale

    sv.debuffsX = tonumber(sv.debuffsX) or defaults.debuffsX
    sv.debuffsY = tonumber(sv.debuffsY) or defaults.debuffsY
    sv.debuffsScale = tonumber(sv.debuffsScale) or defaults.debuffsScale

    sv.splitIconsPerRow = tonumber(sv.splitIconsPerRow) or defaults.splitIconsPerRow
    sv.rowSpacing = tonumber(sv.rowSpacing) or defaults.rowSpacing
    sv.durationTextScale = tonumber(sv.durationTextScale) or defaults.durationTextScale
    sv.stackCountTextScale = tonumber(sv.stackCountTextScale) or defaults.stackCountTextScale

    sv.positionSaved = true

    self:ApplyLayout()

    -- ESO writes SavedVariables to disk on UI reload/logout. Reload here makes Save Position an actual persistent save action.
    if forceReload and ReloadUI then
        ReloadUI()
    end
end

function ADDON:RegisterSettings()
    if self.settingsRegistered then return end
    if not LibHarvensAddonSettings then return end

    local panel = LibHarvensAddonSettings:AddAddon(self.title, { allowDefaults = true, allowRefresh = true })
    if not panel then return end
    self.settingsRegistered = true

    AddSection(panel, "BuffDebuffBar+ by BLKx777")

    AddSection(panel, "General")
    AddCheckbox(panel, "Enable buffdebuffbarplus", "Enable or disable buffdebuffbarplus.", "enabled")
    AddCheckbox(panel, "Split Buffs / Debuffs", "OFF shows one combined bar. ON shows positive buffs and negative debuffs separately.", "splitMode")
    AddSlider(panel, "Combined Maximum Icons", "Maximum icons shown in combined mode.", "maxIcons", 4, 16)
    AddSlider(panel, "Split Icons Per Row", "In split mode, buffs and debuffs wrap after this many icons per row. Default is 6.", "splitIconsPerRow", 3, 10)
    AddSlider(panel, "Row Spacing", "Vertical spacing between adaptive buff/debuff rows. Lower values create a tighter stack.", "rowSpacing", -8, 30)
    AddSlider(panel, "Duration Text Size", "Resize the timer text under each icon. This scales with the tracker size slider. Default is 125%.", "durationTextScale", 75, 250)
    AddSlider(panel, "Stack Count Text Size", "Resize the stack number shown inside icons when a buff or debuff has multiple stacks. Default is 135%.", "stackCountTextScale", 75, 250)

    AddSection(panel, "Combined Mode")
    AddCheckbox(panel, "Combined Preview", "Show a test combined bar even without active effects.", "combinedPreview", function() return SV().splitMode end)
    AddSlider(panel, "Combined X", "Move combined tracker left or right.", "combinedX", -1000, 1000, function() return SV().splitMode end)
    AddSlider(panel, "Combined Y", "Move combined tracker up or down.", "combinedY", -700, 700, function() return SV().splitMode end)
    AddSlider(panel, "Combined Size", "Resize combined tracker.", "combinedScale", 50, 200, function() return SV().splitMode end)

    AddSection(panel, "Buffs")
    AddCheckbox(panel, "Buffs Preview", "Show a test buffs bar even without active effects.", "buffsPreview", function() return not SV().splitMode end)
    AddSlider(panel, "Buffs X", "Move buffs left or right.", "buffsX", -1000, 1000, function() return not SV().splitMode end)
    AddSlider(panel, "Buffs Y", "Move buffs up or down.", "buffsY", -700, 700, function() return not SV().splitMode end)
    AddSlider(panel, "Buffs Size", "Resize buffs.", "buffsScale", 50, 200, function() return not SV().splitMode end)

    AddSection(panel, "Debuffs")
    AddCheckbox(panel, "Debuffs Preview", "Show a test debuffs bar even without active effects.", "debuffsPreview", function() return not SV().splitMode end)
    AddSlider(panel, "Debuffs X", "Move debuffs left or right.", "debuffsX", -1000, 1000, function() return not SV().splitMode end)
    AddSlider(panel, "Debuffs Y", "Move debuffs up or down.", "debuffsY", -700, 700, function() return not SV().splitMode end)
    AddSlider(panel, "Debuffs Size", "Resize debuffs.", "debuffsScale", 50, 200, function() return not SV().splitMode end)

    AddSection(panel, "Save")
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = "Save Position",
        buttonText = "Save",
        tooltip = "Save the current split setting, X/Y positions, sizes, row layout, and timer size. This reloads UI so ESO writes the saved position.",
        clickHandler = function()
            ADDON:SaveCurrentPosition(true)
        end,
    })

    AddSection(panel, "Reset")
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = "Reset All Settings",
        buttonText = "Reset",
        tooltip = "Restore buffdebuffbarplus defaults.",
        clickHandler = function()
            for k, v in pairs(defaults) do SV()[k] = v end
            ADDON:ApplyLayout()
        end,
    })
end

function ADDON:OnPlayerActivated()
    self:RegisterSettings()
    self:EnsureTrackers()
    self:FullEffectScan()
    self:ApplyLayout()
end

function ADDON:OnAddOnLoaded(eventCode, addonName)
    if addonName ~= self.name then return end
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)
    self.saved = ZO_SavedVars:NewAccountWide("buffdebuffbarplusSavedVariables", 1, nil, defaults)

    -- Do not overwrite user placement. Only add missing keys so positions and split mode persist.
    for key, value in pairs(defaults) do
        if self.saved[key] == nil then
            self.saved[key] = value
        end
    end

    -- v1.1.2 migration: older test builds used 400% timer text, which is too large on console.
    -- Reset only over-sized saved values so existing positions and split settings remain untouched.
    if (self.saved.durationTextScale or defaults.durationTextScale) > 250 then
        self.saved.durationTextScale = defaults.durationTextScale
    elseif (self.saved.durationTextScale or defaults.durationTextScale) < 75 then
        self.saved.durationTextScale = defaults.durationTextScale
    end
    if (self.saved.stackCountTextScale or defaults.stackCountTextScale) > 250 then
        self.saved.stackCountTextScale = defaults.stackCountTextScale
    elseif (self.saved.stackCountTextScale or defaults.stackCountTextScale) < 75 then
        self.saved.stackCountTextScale = defaults.stackCountTextScale
    end

    -- v1.1.3 migration: old default row spacing was too open for split rows.
    if self.saved.rowSpacing == nil or self.saved.rowSpacing == 12 then
        self.saved.rowSpacing = defaults.rowSpacing
    end

    -- v1.1.4: these options were removed from the settings menu.
    self.saved.customTracker = true
    self.saved.hideNativeAttempt = false

    EVENT_MANAGER:RegisterForEvent(self.name .. "PlayerActivated", EVENT_PLAYER_ACTIVATED, function() ADDON:OnPlayerActivated() end)
    EVENT_MANAGER:RegisterForEvent(self.name .. "EffectChanged", EVENT_EFFECT_CHANGED, function(...) ADDON:OnEffectChanged(...) end)
    EVENT_MANAGER:AddFilterForEvent(self.name .. "EffectChanged", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForUpdate(self.name .. "Ticker", 500, function()
        ADDON:RefreshCustomTrackers()
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED, function(...) ADDON:OnAddOnLoaded(...) end)
