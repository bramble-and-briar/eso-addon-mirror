-- ESO Adventurer Suite
-- Dual Action Bar HUD
-- Displays both weapon bars at once with active-bar marking, Skill Style icons,
-- effect timers, stack counters, hotkeys, Ultimate charge, and Smart Combat
-- Advisor highlighting. UI-only: never casts abilities or sends combat input.

local EPC = ESOProgressionCoach
EPC.DualActionBar = EPC.DualActionBar or {}
local D = EPC.DualActionBar
local WM = WINDOW_MANAGER

-- ESO can expose some slotted abilities through runtime variants that are not
-- the progression ability id used by Skill Style collectibles. Normalize the
-- known elemental Destruction Staff variants and Arcanist resource variants
-- before asking the progression/collectible APIs for the selected style.
local SKILL_STYLE_ABILITY_ALIAS_029189 = {
    [28807]=28858, [28849]=28858, [28854]=28858,
    [39012]=39011, [39028]=39011, [39018]=39011,
    [39053]=39052, [39067]=39052, [39073]=39052,
    [29073]=29091, [29078]=29091, [29089]=29091,
    [38944]=38937, [38970]=38937, [38978]=38937,
    [38985]=38984, [38989]=38984, [38993]=38984,
    [28794]=28800, [28798]=28800, [28799]=28800,
    [39145]=39143, [39146]=39143, [39147]=39143,
    [39162]=39161, [39163]=39161, [39167]=39161,
    [83625]=83619, [83628]=83619, [83630]=83619,
    [83682]=83642, [83684]=83642, [83686]=83642,
    [85126]=84434, [85128]=84434, [85130]=84434,
    [193331]=185805, [193398]=186366, [193397]=183122,
    [198282]=183261, [198288]=186189, [198292]=186191,
    [188658]=185794, [188780]=182977, [188787]=185803,
}

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d,e,f = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a,b,c,d,e,f
end

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function nowMS()
    return tonumber(safe(GetFrameTimeMilliseconds, 0)) or tonumber(safe(GetGameTimeMilliseconds, 0)) or 0
end

local function formatMS(ms)
    ms = tonumber(ms) or 0
    if ms <= 0 then return "" end
    local s = ms / 1000
    if s >= 10 then return tostring(math.ceil(s)) end
    return string.format("%.1f", s)
end

local function getSlots()
    local firstBase = tonumber(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX)
    local ultBase = tonumber(ACTION_BAR_ULTIMATE_SLOT_INDEX)
    local first = firstBase and (firstBase + 1) or 3
    local ult = ultBase and (ultBase + 1) or (first + 5)
    local out = {}
    for i = 0, 4 do out[#out + 1] = first + i end
    out[#out + 1] = ult
    return out
end

function D:GetCategories()
    local primary = rawget(_G, "HOTBAR_CATEGORY_PRIMARY")
    local backup = rawget(_G, "HOTBAR_CATEGORY_BACKUP")
    if primary == nil then primary = 0 end
    if backup == nil then backup = 1 end
    return primary, backup
end

function D:GetBoundAbilityId(slot, category)
    local id = tonumber((safe(GetSlotBoundId, 0, slot, category))) or 0
    local actionType = safe(GetSlotType, nil, slot, category)
    if actionType == rawget(_G, "ACTION_TYPE_CRAFTED_ABILITY") and type(GetAbilityIdForCraftedAbilityId) == "function" then
        id = tonumber(safe(GetAbilityIdForCraftedAbilityId, id, id)) or id
    end
    return id
end

-- Get the selected Skill Style artwork without changing ESO's native action bar.
-- If another installed addon exposes the common GetSkillStyleIconForAbilityId
-- helper, use it first for maximum compatibility with special-case abilities.
local GetSkillStyleIconImpl
function D:GetSkillStyleIcon(...)
    return GetSkillStyleIconImpl(self, ...)
end
GetSkillStyleIconImpl = function(self, abilityId, fallbackIcon)
    if not EPC.saved or EPC.saved.dualActionBarSkillStyles029189 == false then
        return fallbackIcon or ""
    end
    abilityId = tonumber(abilityId) or 0
    if abilityId <= 0 then return fallbackIcon or "" end
    self.styleIconCache029189 = self.styleIconCache029189 or {}
    local cached = self.styleIconCache029189[abilityId]
    if cached ~= nil then
        return cached ~= false and cached or (fallbackIcon or "")
    end

    local external = rawget(_G, "GetSkillStyleIconForAbilityId")
    if type(external) == "function" then
        local icon = safe(external, nil, abilityId)
        if icon and icon ~= "" then
            self.styleIconCache029189[abilityId] = icon
            return icon
        end
    end

    abilityId = SKILL_STYLE_ABILITY_ALIAS_029189[abilityId] or abilityId

    if type(GetSpecificSkillAbilityKeysByAbilityId) == "function"
        and type(GetProgressionSkillProgressionId) == "function"
        and type(GetActiveProgressionSkillAbilityFxOverrideCollectibleId) == "function"
        and type(GetCollectibleIcon) == "function" then
        local skillType, skillLineIndex, skillIndex = safe(GetSpecificSkillAbilityKeysByAbilityId, nil, abilityId)
        if skillType ~= nil and skillLineIndex ~= nil and skillIndex ~= nil then
            local progressionId = tonumber(safe(GetProgressionSkillProgressionId, 0, skillType, skillLineIndex, skillIndex)) or 0
            if progressionId > 0 then
                local collectibleId = tonumber(safe(GetActiveProgressionSkillAbilityFxOverrideCollectibleId, 0, progressionId)) or 0
                if collectibleId > 0 then
                    local icon = tostring(safe(GetCollectibleIcon, "", collectibleId) or "")
                    if icon ~= "" then
                        self.styleIconCache029189[abilityId] = icon
                        return icon
                    end
                end
            end
        end
    end
    self.styleIconCache029189[abilityId] = false
    return fallbackIcon or ""
end

function D:InvalidateStyleCache029189()
    self.styleIconCache029189 = {}
end

function D:GetBindingMarkup(slot)
    if not EPC.saved or EPC.saved.dualActionBarShowHotkeys029189 == false then return "" end
    local overlays = EPC.AbilityOverlays
    if overlays and type(overlays.GetBindingTextForSlot) == "function" then
        return tostring(overlays:GetBindingTextForSlot(slot) or "")
    end
    return ""
end

function D:GetAbilityData(category)
    local rotation = EPC.RotationAssistant
    if rotation and type(rotation.GetBarAbilities029161) == "function" then
        local ok, data = pcall(rotation.GetBarAbilities029161, rotation, category)
        if ok and type(data) == "table" then return data end
    end

    local out = {}
    local slots = self.slots or getSlots()
    for ordinal, slot in ipairs(slots) do
        local remain, duration, global = safe(GetSlotCooldownInfo, 0, slot, category)
        out[#out + 1] = {
            slot = slot,
            ordinal = ordinal,
            category = category,
            abilityId = self:GetBoundAbilityId(slot, category),
            name = tostring(safe(GetSlotName, "", slot, category) or ""),
            icon = tostring(safe(GetSlotTexture, "", slot, category) or ""),
            used = safe(IsSlotUsed, false, slot, category) == true,
            remain = tonumber(remain) or 0,
            duration = tonumber(duration) or 0,
            global = global == true,
            effect = tonumber(safe(GetActionSlotEffectTimeRemaining, 0, slot, category)) or 0,
            isUltimate = ordinal == #slots,
        }
    end
    return out
end

function D:GetTrackedState(ability)
    local remaining = math.max(0, tonumber(ability and ability.effect) or 0)
    local stacks = 0
    local threshold = 0
    local rotation = EPC.RotationAssistant
    if rotation and ability and type(rotation.ClassifyAbility029161) == "function"
        and type(rotation.GetAbilityEffectState029170) == "function" then
        local okClass, cls = pcall(rotation.ClassifyAbility029161, rotation, ability)
        if okClass and cls then
            local okState, state = pcall(rotation.GetAbilityEffectState029170, rotation, ability, cls)
            if okState and type(state) == "table" then
                remaining = math.max(remaining, tonumber(state.remaining) or 0)
                stacks = math.max(0, tonumber(state.stacks) or 0)
                threshold = math.max(0, tonumber(state.stackThreshold) or 0)
            end
        end
    end
    return remaining, stacks, threshold
end

function D:CreateSlot(parent, rowIndex, ordinal)
    local size = clamp(EPC.saved and EPC.saved.dualActionBarIconSize029189, 42, 78)
    local name = "EAS_DualActionBar_R" .. tostring(rowIndex) .. "_S" .. tostring(ordinal)
    local frame = WM:CreateControl(name, parent, CT_CONTROL)
    frame:SetDimensions(size, size)

    local bg = WM:CreateControl(name .. "BG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0.01, 0.015, 0.025, 0.82)
    bg:SetEdgeColor(0.18, 0.20, 0.26, 0.95)
    bg:SetEdgeTexture(nil, 2, 2, 2)

    local icon = WM:CreateControl(name .. "Icon", frame, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, frame, TOPLEFT, 3, 3)
    icon:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -3, -3)

    local shade = WM:CreateControl(name .. "Shade", frame, CT_BACKDROP)
    shade:SetAnchorFill(icon)
    shade:SetCenterColor(0,0,0,0)
    shade:SetEdgeColor(0,0,0,0)

    local timer = WM:CreateControl(name .. "Timer", frame, CT_LABEL)
    timer:SetAnchor(CENTER, frame, CENTER, 0, 4)
    timer:SetDimensions(size - 4, 24)
    timer:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timer:SetColor(1.00, 0.78, 0.20, 1)

    local stack = WM:CreateControl(name .. "Stack", frame, CT_LABEL)
    stack:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -3, 1)
    stack:SetDimensions(32, 20)
    stack:SetFont("$(BOLD_FONT)|16|soft-shadow-thick")
    stack:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    stack:SetColor(0.98, 0.95, 0.76, 1)

    local hotkey = WM:CreateControl(name .. "Hotkey", frame, CT_LABEL)
    hotkey:SetAnchor(TOPLEFT, frame, TOPLEFT, 3, 1)
    hotkey:SetDimensions(size - 6, 20)
    hotkey:SetFont("$(BOLD_FONT)|13|soft-shadow-thick")
    hotkey:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    hotkey:SetColor(0.96, 0.88, 0.60, 1)

    local ultimate = WM:CreateControl(name .. "Ultimate", frame, CT_LABEL)
    ultimate:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -3, -1)
    ultimate:SetDimensions(40, 18)
    ultimate:SetFont("ZoFontGameSmall")
    ultimate:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    ultimate:SetColor(1.00, 0.84, 0.30, 1)

    local smart = WM:CreateControl(name .. "Smart", frame, CT_BACKDROP)
    smart:SetAnchor(TOPLEFT, frame, TOPLEFT, -4, -4)
    smart:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 4, 4)
    smart:SetCenterColor(1.00, 0.66, 0.05, 0.06)
    smart:SetEdgeColor(1.00, 0.86, 0.16, 1)
    smart:SetEdgeTexture(nil, 4, 4, 4)
    smart:SetHidden(true)
    smart:SetMouseEnabled(false)
    if smart.SetDrawLayer and DL_OVERLAY then smart:SetDrawLayer(DL_OVERLAY) end
    if smart.SetDrawLevel then smart:SetDrawLevel(1500) end

    local swap = WM:CreateControl(name .. "Swap", frame, CT_LABEL)
    swap:SetAnchor(BOTTOM, frame, TOP, 0, -1)
    swap:SetDimensions(size + 20, 18)
    swap:SetFont("$(BOLD_FONT)|12|soft-shadow-thick")
    swap:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    swap:SetColor(1.00, 0.74, 0.12, 1)
    swap:SetText("SWAP")
    swap:SetHidden(true)

    frame.epcBG = bg
    frame.epcIcon = icon
    frame.epcShade = shade
    frame.epcTimer = timer
    frame.epcStack = stack
    frame.epcHotkey = hotkey
    frame.epcUltimate = ultimate
    frame.epcSmart = smart
    frame.epcSwap = swap
    frame.epcOrdinal = ordinal
    return frame
end

function D:CreateRow(parent, rowIndex, category, barNumber)
    local row = WM:CreateControl("EAS_DualActionBar_Row" .. tostring(rowIndex), parent, CT_CONTROL)
    row.epcCategory = category
    row.epcBarNumber = barNumber
    row.slots = {}

    local marker = WM:CreateControl("EAS_DualActionBar_Row" .. tostring(rowIndex) .. "Marker", row, CT_BACKDROP)
    marker:SetDimensions(54, 34)
    marker:SetCenterColor(0.02, 0.025, 0.04, 0.90)
    marker:SetEdgeColor(0.30, 0.32, 0.38, 0.95)
    marker:SetEdgeTexture(nil, 2, 2, 2)

    -- Texture-only ESO weapons icon. Do NOT inherit the weapon-swap button
    -- virtual here: that control also renders the player's weapon-swap keybind
    -- (for example G), which is not wanted as an active-bar indicator.
    local markerIcon = WM:CreateControl("EAS_DualActionBar_Row" .. tostring(rowIndex) .. "MarkerIcon", marker, CT_TEXTURE)
    markerIcon:SetDimensions(28, 28)
    markerIcon:SetMouseEnabled(false)
    markerIcon:SetHidden(true)
    local markerTexture = ""
    local itemFilterUtils = rawget(_G, "ZO_ItemFilterUtils")
    local weaponsCategory = rawget(_G, "ITEM_TYPE_DISPLAY_CATEGORY_WEAPONS")
    if itemFilterUtils and type(itemFilterUtils.GetItemTypeDisplayCategoryFilterDisplayInfo) == "function" and weaponsCategory ~= nil then
        local ok, filterData = pcall(itemFilterUtils.GetItemTypeDisplayCategoryFilterDisplayInfo, weaponsCategory)
        if ok and type(filterData) == "table" and type(filterData.icons) == "table" then
            markerTexture = tostring(filterData.icons.up or filterData.icons.down or filterData.icons.over or "")
        end
    end
    -- Defensive fallback to ESO's stock inventory weapons-tab artwork path.
    if markerTexture == "" then markerTexture = "EsoUI/Art/Inventory/inventory_tabIcon_weapons_up.dds" end
    markerIcon:SetTexture(markerTexture)

    local markerText = WM:CreateControl("EAS_DualActionBar_Row" .. tostring(rowIndex) .. "MarkerText", marker, CT_LABEL)
    markerText:SetAnchorFill(marker)
    markerText:SetFont("$(BOLD_FONT)|16|soft-shadow-thick")
    markerText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    markerText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    markerText:SetColor(0.75, 0.77, 0.82, 1)

    row.marker = marker
    row.markerIcon = markerIcon
    row.markerText = markerText
    return row
end

function D:GetBarOrder()
    local primary, backup = self:GetCategories()
    if EPC.saved and EPC.saved.dualActionBarPrimaryOnTop029189 == true then
        return {
            { category = primary, number = 1 },
            { category = backup, number = 2 },
        }
    end
    return {
        { category = backup, number = 2 },
        { category = primary, number = 1 },
    }
end

function D:ApplyDimensions(force)
    if not self.window then return end
    local size = clamp(EPC.saved and EPC.saved.dualActionBarIconSize029189, 42, 78)
    local gap = clamp(EPC.saved and EPC.saved.dualActionBarButtonGap029189, 0, 18)
    local rowGap = clamp(EPC.saved and EPC.saved.dualActionBarRowGap029189, 0, 24)
    local scale = clamp(EPC.saved and EPC.saved.dualActionBarScale029189, 0.65, 1.80)
    local primaryOnTop = EPC.saved and EPC.saved.dualActionBarPrimaryOnTop029189 == true
    local signature = table.concat({ tostring(size), tostring(gap), tostring(rowGap), tostring(scale), tostring(primaryOnTop) }, ":")
    if force ~= true and self.dimensionSignature029189 == signature then return end
    self.dimensionSignature029189 = signature
    local markerWidth = 58
    local width = markerWidth + (#self.slots * size) + ((#self.slots - 1) * gap) + 8
    local height = (size * 2) + rowGap + 8
    self.window:SetDimensions(width, height)

    local order = self:GetBarOrder()
    for rowIndex, row in ipairs(self.rows or {}) do
        local entry = order[rowIndex]
        row.epcCategory = entry.category
        row.epcBarNumber = entry.number
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, self.window, TOPLEFT, 0, (rowIndex - 1) * (size + rowGap))
        row:SetDimensions(width, size)
        row.marker:ClearAnchors()
        row.marker:SetAnchor(LEFT, row, LEFT, 0, 0)
        for ordinal, frame in ipairs(row.slots) do
            frame:SetDimensions(size, size)
            frame:ClearAnchors()
            local x = markerWidth + (ordinal - 1) * (size + gap)
            frame:SetAnchor(LEFT, row, LEFT, x, 0)
            frame.epcTimer:SetDimensions(size - 4, 24)
            frame.epcHotkey:SetDimensions(size - 6, 20)
            frame.epcSwap:SetDimensions(size + 20, 18)
        end
    end
    self.window:SetScale(scale)
end

function D:AnchorWindow()
    if not self.window then return end
    self.window:ClearAnchors()
    local left = tonumber(EPC.saved and EPC.saved.dualActionBarLeft029189) or -1
    local top = tonumber(EPC.saved and EPC.saved.dualActionBarTop029189) or -1
    if left >= 0 and top >= 0 then
        self.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        self.window:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -150)
    end
end

local CreateUIImpl

function D:CreateUI(...)

    return CreateUIImpl(self, ...)

end

CreateUIImpl = function(self)
    if self.window then return end
    self.slots = getSlots()
    local window = WM:CreateTopLevelWindow("EAS_DualActionBarHUD029189")
    window:SetClampedToScreen(true)
    window:SetMouseEnabled(false)
    window:SetMovable(false)
    window:SetHidden(true)
    if window.SetDrawLayer and DL_OVERLAY then window:SetDrawLayer(DL_OVERLAY) end
    if window.SetDrawTier and DT_HIGH then window:SetDrawTier(DT_HIGH) end
    if window.SetDrawLevel then window:SetDrawLevel(920) end

    window:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            EPC.saved.dualActionBarLeft029189 = control:GetLeft()
            EPC.saved.dualActionBarTop029189 = control:GetTop()
        end
    end)

    self.window = window
    self.rows = {}
    local order = self:GetBarOrder()
    for rowIndex = 1, 2 do
        local entry = order[rowIndex]
        local row = self:CreateRow(window, rowIndex, entry.category, entry.number)
        for ordinal = 1, #self.slots do
            row.slots[ordinal] = self:CreateSlot(row, rowIndex, ordinal)
        end
        self.rows[rowIndex] = row
    end
    self:ApplyDimensions(true)
    self:AnchorWindow()
end

function D:GetMarkerMode029191()
    local mode = tostring(EPC.saved and EPC.saved.dualActionBarMarkerStyle029189 or "ICON_GLOW")
    -- Migrate older styles without forcing users to reset saved vars.
    if mode == "ARROW_NUMBER" then mode = "ICON_GLOW" end
    if mode == "ARROW" then mode = "ICON" end
    if mode == "ICON_NUMBER" then mode = "ICON_GLOW" end
    return mode
end

function D:RefreshMarker029191(row, active)
    local mode = self:GetMarkerMode029191()
    local icon = row.markerIcon
    local text = row.markerText
    if icon then
        icon:ClearAnchors()
        icon:SetHidden(not active or mode == "NUMBER")
        if active and mode ~= "NUMBER" then
            icon:SetAnchor(CENTER, row.marker, CENTER, 0, 0)
            icon:SetAlpha(1)
        end
    end

    text:ClearAnchors()
    if mode == "NUMBER" then
        text:SetText(tostring(row.epcBarNumber))
        text:SetAnchorFill(row.marker)
        text:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    else
        text:SetText("")
        text:SetAnchorFill(row.marker)
        text:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
end

function D:RefreshRow(row, activeCategory)
    local category = row.epcCategory
    local active = category == activeCategory
    local inactiveAlpha = clamp((EPC.saved and EPC.saved.dualActionBarInactiveAlpha029189 or 45) / 100, 0.10, 1.0)
    local inactiveDesaturation = clamp((EPC.saved and EPC.saved.dualActionBarInactiveDesaturation029189 or 45) / 100, 0, 1)

    local recommendedOnRow = self.smartCategory029189 == category and self.smartSlot029189 ~= nil
    row:SetAlpha(active and 1.0 or (recommendedOnRow and math.max(inactiveAlpha, 0.78) or inactiveAlpha))
    self:RefreshMarker029191(row, active)
    local markerMode = self:GetMarkerMode029191()
    if active then
        if markerMode == "ICON_GLOW" then
            row.marker:SetCenterColor(0.20, 0.14, 0.03, 0.20)
            row.marker:SetEdgeColor(1.00, 0.74, 0.18, 0.72)
        else
            row.marker:SetCenterColor(0.05, 0.055, 0.08, 0.16)
            row.marker:SetEdgeColor(0.86, 0.72, 0.30, 0.46)
        end
        row.markerText:SetColor(1.00, 0.86, 0.36, 1)
    else
        if markerMode == "NUMBER" then
            row.marker:SetCenterColor(0.02, 0.025, 0.04, 0.88)
            row.marker:SetEdgeColor(0.30, 0.32, 0.38, 0.90)
        else
            row.marker:SetCenterColor(0, 0, 0, 0)
            row.marker:SetEdgeColor(0, 0, 0, 0)
        end
        row.markerText:SetColor(0.72, 0.74, 0.80, 1)
    end

    local bySlot = {}
    for _, ability in ipairs(self:GetAbilityData(category)) do
        bySlot[tonumber(ability.slot)] = ability
    end

    for ordinal, frame in ipairs(row.slots) do
        local slot = self.slots[ordinal]
        local ability = bySlot[slot] or {
            slot = slot, ordinal = ordinal, category = category,
            abilityId = self:GetBoundAbilityId(slot, category),
            name = tostring(safe(GetSlotName, "", slot, category) or ""),
            icon = tostring(safe(GetSlotTexture, "", slot, category) or ""),
            used = safe(IsSlotUsed, false, slot, category) == true,
            effect = tonumber(safe(GetActionSlotEffectTimeRemaining, 0, slot, category)) or 0,
            isUltimate = ordinal == #self.slots,
        }
        local used = ability.used == true
        local fallbackIcon = tostring(ability.icon or "")
        local abilityId = self:GetBoundAbilityId(slot, category)
        if abilityId <= 0 then abilityId = tonumber(ability.abilityId) or 0 end
        local icon = self:GetSkillStyleIcon(abilityId, fallbackIcon)
        frame.epcIcon:SetTexture(icon or "")
        frame.epcIcon:SetHidden(not used or icon == "")
        frame.epcShade:SetHidden(not used)
        if frame.epcIcon.SetDesaturation then
            frame.epcIcon:SetDesaturation(active and 0 or inactiveDesaturation)
        end

        if active then
            frame.epcBG:SetEdgeColor(0.38, 0.30, 0.12, 0.98)
        else
            frame.epcBG:SetEdgeColor(0.16, 0.18, 0.22, 0.90)
        end

        local remaining, stacks, threshold = self:GetTrackedState(ability)
        local showTimers = EPC.saved and EPC.saved.dualActionBarShowTimers029189 ~= false
        local timerText = ""
        if used and showTimers then
            if remaining > 0 then
                timerText = formatMS(remaining)
            else
                local remain = tonumber(ability.remain) or 0
                local duration = tonumber(ability.duration) or 0
                if remain > 0 and duration > 0 and ability.global ~= true then timerText = formatMS(remain) end
            end
        end
        frame.epcTimer:SetText(timerText)

        local showStacks = EPC.saved and EPC.saved.dualActionBarShowStacks029189 ~= false
        if used and showStacks and stacks > 0 then
            if threshold > 0 then
                frame.epcStack:SetText(tostring(math.floor(stacks + 0.5)) .. "/" .. tostring(math.floor(threshold + 0.5)))
            else
                frame.epcStack:SetText(tostring(math.floor(stacks + 0.5)))
            end
        else
            frame.epcStack:SetText("")
        end

        local bind = used and self:GetBindingMarkup(slot) or ""
        frame.epcHotkey:SetText(bind)
        local usesMarkup = bind:find("|k", 1, true) ~= nil
            or bind:find("|u", 1, true) ~= nil
            or bind:find("|t", 1, true) ~= nil
        frame.epcHotkey:SetFont(usesMarkup and "$(BOLD_FONT)|14|soft-shadow-thick" or "$(BOLD_FONT)|13|soft-shadow-thick")

        local isUltimate = ordinal == #self.slots
        if used and isUltimate and COMBAT_MECHANIC_FLAGS_ULTIMATE then
            local current = tonumber((safe(GetUnitPower, 0, "player", COMBAT_MECHANIC_FLAGS_ULTIMATE))) or 0
            frame.epcUltimate:SetText(tostring(math.max(0, math.floor(current + 0.5))) .. "%")
        else
            frame.epcUltimate:SetText("")
        end

        local smartMatch = self.smartSlot029189 ~= nil
            and tonumber(self.smartSlot029189) == tonumber(slot)
            and self.smartCategory029189 == category
        frame.epcSmart:SetHidden(not smartMatch)
        frame.epcSwap:SetHidden(not (smartMatch and self.smartNeedsSwap029189 == true))
        if smartMatch then
            frame.epcSmart:SetAlpha(0.92)
        end

        if self.layoutMode and not used then
            frame.epcIcon:SetHidden(true)
            frame.epcTimer:SetText(isUltimate and "ULT" or tostring(ordinal))
            frame.epcHotkey:SetText("")
            frame.epcBG:SetCenterColor(0.02, 0.025, 0.04, 0.88)
        end
    end
end

-- v0.29.341: obsolete pre-0.29.311 full Refresh implementation removed.

local SetSmartRecommendationImpl

function D:SetSmartRecommendation029189(...)

    return SetSmartRecommendationImpl(self, ...)

end

SetSmartRecommendationImpl = function(self, slot, category, pulse, needsSwap)
    self.smartSlot029189 = tonumber(slot)
    self.smartCategory029189 = category
    self.smartPulse029189 = tonumber(pulse)
    self.smartNeedsSwap029189 = needsSwap == true
    return self.smartSlot029189 ~= nil
end

local ClearSmartRecommendationImpl

function D:ClearSmartRecommendation029189(...)

    return ClearSmartRecommendationImpl(self, ...)

end

ClearSmartRecommendationImpl = function(self)
    self.smartSlot029189 = nil
    self.smartCategory029189 = nil
    self.smartPulse029189 = nil
    self.smartNeedsSwap029189 = false
end

function D:SetLayoutMode(active)
    self:CreateUI()
    self.layoutMode = active == true
    self.window:SetMouseEnabled(self.layoutMode)
    self.window:SetMovable(self.layoutMode)
    if self.layoutMode and self.window.SetDrawLevel then self.window:SetDrawLevel(1200) end
    self:Refresh()
end

function D:RaiseForLayout()
    if not self.window or not self.layoutMode then return end
    if self.window.SetTopLevel then self.window:SetTopLevel(true) end
    if self.window.SetDrawLayer and DL_OVERLAY then self.window:SetDrawLayer(DL_OVERLAY) end
    if self.window.SetDrawTier and DT_HIGH then self.window:SetDrawTier(DT_HIGH) end
    if self.window.SetDrawLevel then self.window:SetDrawLevel(1200) end
    if self.window.BringWindowToTop then self.window:BringWindowToTop() end
end

function D:ResetPosition()
    if EPC.saved then
        EPC.saved.dualActionBarLeft029189 = -1
        EPC.saved.dualActionBarTop029189 = -1
    end
    self:AnchorWindow()
end

-- v0.29.341: obsolete 200 ms Dual Action Bar initializer removed; the optimized initializer below is authoritative.

-- ============================================================================
-- v0.29.311 - Dual Action Bar frame-time hotfix
-- The previous 200 ms tick called the Rotation Assistant's full two-bar ability
-- model, which resolves descriptions, runtime metadata, buff types, effective
-- ids, effect classification and tracked-state matching for every slot. That is
-- appropriate for recommendation scoring, not for a HUD renderer. Keep stable
-- slot presentation event-driven and restrict the gameplay tick to cheap live
-- values only.
-- ============================================================================

local function EAS_DAB_Normalize029311(value)
    local text = string.lower(tostring(value or ""))
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[^%w%s%%'%-]", " ")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local function EAS_DAB_SetText029311(control, owner, key, value)
    if not control or not owner then return end
    value = tostring(value or "")
    if owner[key] ~= value then
        owner[key] = value
        control:SetText(value)
    end
end

local function EAS_DAB_SetHidden029311(control, owner, key, hidden)
    if not control or not owner then return end
    hidden = hidden == true
    if owner[key] ~= hidden then
        owner[key] = hidden
        control:SetHidden(hidden)
    end
end

local function EAS_DAB_SetTexture029311(control, owner, key, texture)
    if not control or not owner then return end
    texture = tostring(texture or "")
    if owner[key] ~= texture then
        owner[key] = texture
        control:SetTexture(texture)
    end
end

function D:GetLightAbilityData029311(category)
    local out = {}
    local slots = self.slots or getSlots()
    for ordinal, slot in ipairs(slots) do
        local used = safe(IsSlotUsed, false, slot, category) == true
        local abilityId = self:GetBoundAbilityId(slot, category)
        local effectiveId = 0
        if abilityId > 0 and type(GetEffectiveAbilityIdForAbilityOnHotbar) == "function" then
            effectiveId = tonumber(safe(GetEffectiveAbilityIdForAbilityOnHotbar, 0, abilityId, category)) or 0
        end
        out[#out + 1] = {
            slot = slot,
            ordinal = ordinal,
            category = category,
            abilityId = abilityId,
            effectiveAbilityId029311 = effectiveId,
            name = tostring(safe(GetSlotName, "", slot, category) or ""),
            icon = tostring(safe(GetSlotTexture, "", slot, category) or ""),
            used = used,
            isUltimate = ordinal == #slots,
        }
    end
    return out
end

function D:BuildLightEffectIndex029311()
    local rotation = EPC.RotationAssistant
    local snapshot = rotation and rotation.smartEffects029169
    if type(snapshot) ~= "table" then return nil end
    local age = math.max(0, nowMS() - (tonumber(snapshot.at) or 0))
    if age > 900 then return nil end

    local index = { byId = {}, byName = {} }
    local function absorb(list)
        for _, effect in ipairs(list or {}) do
            local state = {
                remaining = math.max(0, (tonumber(effect.remaining) or 0) - age),
                stacks = math.max(0, tonumber(effect.stacks) or 0),
            }
            local effectId = tonumber(effect.abilityId) or 0
            if effectId > 0 then
                local previous = index.byId[effectId]
                if not previous or state.remaining > previous.remaining or state.stacks > previous.stacks then
                    index.byId[effectId] = state
                end
            end
            local effectName = tostring(effect.normalizedName or "")
            if effectName == "" then effectName = EAS_DAB_Normalize029311(effect.name) end
            if effectName ~= "" then
                local previous = index.byName[effectName]
                if not previous or state.remaining > previous.remaining or state.stacks > previous.stacks then
                    index.byName[effectName] = state
                end
            end
        end
    end
    absorb(snapshot.player)
    absorb(snapshot.target)
    return index
end

function D:GetLightTrackedState029311(ability, slotEffect, effectIndex)
    local remaining = math.max(0, tonumber(slotEffect) or 0)
    local stacks, threshold = 0, 0
    local name = EAS_DAB_Normalize029311(ability and ability.name or "")
    if name:find("bound armaments", 1, true) then threshold = 4
    elseif name:find("merciless resolve", 1, true) or name:find("relentless focus", 1, true) or name:find("grim focus", 1, true) then threshold = 5
    elseif name:find("molten whip", 1, true) then threshold = 3 end
    if type(effectIndex) ~= "table" then return remaining, stacks, threshold end

    local abilityId = tonumber(ability and ability.abilityId) or 0
    local effectiveId = tonumber(ability and ability.effectiveAbilityId029311) or 0
    local function consider(state)
        if state then
            remaining = math.max(remaining, tonumber(state.remaining) or 0)
            stacks = math.max(stacks, tonumber(state.stacks) or 0)
        end
    end
    if abilityId > 0 then consider(effectIndex.byId[abilityId]) end
    if effectiveId > 0 then consider(effectIndex.byId[effectiveId]) end
    if name ~= "" then consider(effectIndex.byName[name]) end
    return remaining, stacks, threshold
end

function D:IsVisibleNow029311()
    self:CreateUI()
    if not self.window or not EPC.saved then return false end
    local show = EPC.saved.showDualActionBar029189 == true
    if self.layoutMode then show = true end
    if show and not self.layoutMode and EPC.OverlayModeAllows then
        show = EPC:OverlayModeAllows(EPC.saved.dualActionBarVisibility029189 or "ALWAYS")
    end
    if show and not self.layoutMode and EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then
        show = false
    end
    EAS_DAB_SetHidden029311(self.window, self, "windowHidden029311", not show)
    return show
end

local RefreshStaticImpl

function D:RefreshStatic029311(...)

    return RefreshStaticImpl(self, ...)

end

RefreshStaticImpl = function(self)
    self:CreateUI()
    if not self.window then return end
    self:ApplyDimensions()
    -- Keep the event-driven slot cache current even while a visibility mode has
    -- the bar hidden, so entering combat never needs a surprise metadata rebuild.
    self:IsVisibleNow029311()

    self.staticAbilityData029311 = self.staticAbilityData029311 or {}
    local activeCategory = safe(GetActiveHotbarCategory, nil)
    self.lastActiveCategory029311 = activeCategory
    local inactiveAlpha = clamp((EPC.saved and EPC.saved.dualActionBarInactiveAlpha029189 or 45) / 100, 0.10, 1.0)
    local inactiveDesaturation = clamp((EPC.saved and EPC.saved.dualActionBarInactiveDesaturation029189 or 45) / 100, 0, 1)

    for _, row in ipairs(self.rows or {}) do
        local category = row.epcCategory
        local active = category == activeCategory
        local recommendedOnRow = self.smartCategory029189 == category and self.smartSlot029189 ~= nil
        row:SetAlpha(active and 1.0 or (recommendedOnRow and math.max(inactiveAlpha, 0.78) or inactiveAlpha))
        self:RefreshMarker029191(row, active)
        local markerMode = self:GetMarkerMode029191()
        if active then
            if markerMode == "ICON_GLOW" then
                row.marker:SetCenterColor(0.20, 0.14, 0.03, 0.20)
                row.marker:SetEdgeColor(1.00, 0.74, 0.18, 0.72)
            else
                row.marker:SetCenterColor(0.05, 0.055, 0.08, 0.16)
                row.marker:SetEdgeColor(0.86, 0.72, 0.30, 0.46)
            end
            row.markerText:SetColor(1.00, 0.86, 0.36, 1)
        else
            if markerMode == "NUMBER" then
                row.marker:SetCenterColor(0.02, 0.025, 0.04, 0.88)
                row.marker:SetEdgeColor(0.30, 0.32, 0.38, 0.90)
            else
                row.marker:SetCenterColor(0, 0, 0, 0)
                row.marker:SetEdgeColor(0, 0, 0, 0)
            end
            row.markerText:SetColor(0.72, 0.74, 0.80, 1)
        end

        local data = self:GetLightAbilityData029311(category)
        self.staticAbilityData029311[category] = data
        for ordinal, frame in ipairs(row.slots or {}) do
            local ability = data[ordinal]
            frame.epcAbility029311 = ability
            local used = ability and ability.used == true
            local fallbackIcon = ability and ability.icon or ""
            local icon = used and self:GetSkillStyleIcon(ability.abilityId, fallbackIcon) or ""
            EAS_DAB_SetTexture029311(frame.epcIcon, frame, "iconTexture029311", icon)
            EAS_DAB_SetHidden029311(frame.epcIcon, frame, "iconHidden029311", not used or icon == "")
            EAS_DAB_SetHidden029311(frame.epcShade, frame, "shadeHidden029311", not used)
            if frame.epcIcon.SetDesaturation then frame.epcIcon:SetDesaturation(active and 0 or inactiveDesaturation) end
            if active then frame.epcBG:SetEdgeColor(0.38, 0.30, 0.12, 0.98)
            else frame.epcBG:SetEdgeColor(0.16, 0.18, 0.22, 0.90) end

            local bind = used and self:GetBindingMarkup(ability.slot) or ""
            EAS_DAB_SetText029311(frame.epcHotkey, frame, "hotkeyText029311", bind)
            local usesMarkup = bind:find("|k", 1, true) ~= nil
            or bind:find("|u", 1, true) ~= nil
            or bind:find("|t", 1, true) ~= nil
            local fontKey = usesMarkup and "markup" or "text"
            if frame.hotkeyFont029311 ~= fontKey then
                frame.hotkeyFont029311 = fontKey
                frame.epcHotkey:SetFont(usesMarkup and "$(BOLD_FONT)|14|soft-shadow-thick" or "$(BOLD_FONT)|13|soft-shadow-thick")
            end

            if self.layoutMode and not used then
                EAS_DAB_SetHidden029311(frame.epcIcon, frame, "iconHidden029311", true)
                EAS_DAB_SetText029311(frame.epcTimer, frame, "timerText029311", ability and ability.isUltimate and "ULT" or tostring(ordinal))
                EAS_DAB_SetText029311(frame.epcHotkey, frame, "hotkeyText029311", "")
                frame.epcBG:SetCenterColor(0.02, 0.025, 0.04, 0.88)
            end
        end
    end
end

local RefreshDynamicImpl

function D:RefreshDynamic029311(...)

    return RefreshDynamicImpl(self, ...)

end

RefreshDynamicImpl = function(self, force)
    if not self:IsVisibleNow029311() then return end
    local nowValue = nowMS()
    local inCombat = type(IsUnitInCombat) == "function" and safe(IsUnitInCombat, false, "player") == true
    local minGap = (inCombat or self.layoutMode or self.smartSlot029189 ~= nil) and 250 or 1250
    if force ~= true and self.lastDynamicAt029311 and nowValue - self.lastDynamicAt029311 < minGap then return end
    self.lastDynamicAt029311 = nowValue

    local activeCategory = safe(GetActiveHotbarCategory, nil)
    if activeCategory ~= self.lastActiveCategory029311 then
        self:RefreshStatic029311()
        activeCategory = safe(GetActiveHotbarCategory, nil)
    end

    local ultimatePower = 0
    if COMBAT_MECHANIC_FLAGS_ULTIMATE then
        ultimatePower = tonumber((safe(GetUnitPower, 0, "player", COMBAT_MECHANIC_FLAGS_ULTIMATE))) or 0
    end
    local effectIndex = self:BuildLightEffectIndex029311()

    for _, row in ipairs(self.rows or {}) do
        local category = row.epcCategory
        local active = category == activeCategory
        local recommendedOnRow = self.smartCategory029189 == category and self.smartSlot029189 ~= nil
        local inactiveAlpha = clamp((EPC.saved and EPC.saved.dualActionBarInactiveAlpha029189 or 45) / 100, 0.10, 1.0)
        row:SetAlpha(active and 1.0 or (recommendedOnRow and math.max(inactiveAlpha, 0.78) or inactiveAlpha))

        for ordinal, frame in ipairs(row.slots or {}) do
            local ability = frame.epcAbility029311
            local used = ability and ability.used == true
            if used then
                local remain, duration, global = safe(GetSlotCooldownInfo, 0, ability.slot, category)
                local slotEffect = tonumber(safe(GetActionSlotEffectTimeRemaining, 0, ability.slot, category)) or 0
                local remaining, stacks, threshold = self:GetLightTrackedState029311(ability, slotEffect, effectIndex)
                local timerText = ""
                if EPC.saved.dualActionBarShowTimers029189 ~= false then
                    if remaining > 0 then
                        timerText = formatMS(remaining)
                    else
                        remain, duration = tonumber(remain) or 0, tonumber(duration) or 0
                        if remain > 0 and duration > 0 and global ~= true then timerText = formatMS(remain) end
                    end
                end
                EAS_DAB_SetText029311(frame.epcTimer, frame, "timerText029311", timerText)

                local stackText = ""
                if EPC.saved.dualActionBarShowStacks029189 ~= false and stacks > 0 then
                    if threshold > 0 then stackText = tostring(math.floor(stacks + 0.5)) .. "/" .. tostring(math.floor(threshold + 0.5))
                    else stackText = tostring(math.floor(stacks + 0.5)) end
                end
                EAS_DAB_SetText029311(frame.epcStack, frame, "stackText029311", stackText)

                if ability.isUltimate and COMBAT_MECHANIC_FLAGS_ULTIMATE then
                    EAS_DAB_SetText029311(frame.epcUltimate, frame, "ultimateText029311", tostring(math.max(0, math.floor(ultimatePower + 0.5))) .. "%")
                else
                    EAS_DAB_SetText029311(frame.epcUltimate, frame, "ultimateText029311", "")
                end
            elseif not self.layoutMode then
                EAS_DAB_SetText029311(frame.epcTimer, frame, "timerText029311", "")
                EAS_DAB_SetText029311(frame.epcStack, frame, "stackText029311", "")
                EAS_DAB_SetText029311(frame.epcUltimate, frame, "ultimateText029311", "")
            end

            local smartMatch = self.smartSlot029189 ~= nil
                and ability ~= nil
                and tonumber(self.smartSlot029189) == tonumber(ability.slot)
                and self.smartCategory029189 == category
            EAS_DAB_SetHidden029311(frame.epcSmart, frame, "smartHidden029311", not smartMatch)
            EAS_DAB_SetHidden029311(frame.epcSwap, frame, "swapHidden029311", not (smartMatch and self.smartNeedsSwap029189 == true))
            if smartMatch then
                frame.epcSmart:SetAlpha(0.92)
            end
        end
    end
end

function D:Refresh()
    self:RefreshStatic029311()
    self:RefreshDynamic029311(true)
end

local EAS_DAB_SetSmartBase029311 = SetSmartRecommendationImpl
SetSmartRecommendationImpl = function(self, slot, category, pulse, needsSwap)
    local result = EAS_DAB_SetSmartBase029311(self, slot, category, pulse, needsSwap)
    return result
end

local EAS_DAB_ClearSmartBase029311 = ClearSmartRecommendationImpl
ClearSmartRecommendationImpl = function(self)
    EAS_DAB_ClearSmartBase029311(self)
    -- Clear stale glow immediately without rebuilding any ability data.
    if self.rows then
        for _, row in ipairs(self.rows) do
            for _, frame in ipairs(row.slots or {}) do
                EAS_DAB_SetHidden029311(frame.epcSmart, frame, "smartHidden029311", true)
                EAS_DAB_SetHidden029311(frame.epcSwap, frame, "swapHidden029311", true)
            end
        end
    end
end

local InitializeImpl

function D:Initialize(...)

    return InitializeImpl(self, ...)

end

InitializeImpl = function(self)
    self:CreateUI()
    local prefix = EPC.name .. "_DualActionBar029189"
    if EVENT_PLAYER_ACTIVATED then
        EPC.Runtime:RegisterEvent("DualActionBar","Activated",EVENT_PLAYER_ACTIVATED, function() self:Refresh() end)
    end
    if EVENT_ACTION_SLOT_UPDATED then
        EPC.Runtime:RegisterEvent("DualActionBar","Slot",EVENT_ACTION_SLOT_UPDATED, function()
            self:InvalidateStyleCache029189()
            self:Refresh()
        end)
    end
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
        EPC.Runtime:RegisterEvent("DualActionBar","Bar",EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function() self:Refresh() end)
    end
    if EVENT_COLLECTIBLE_UPDATED then
        EPC.Runtime:RegisterEvent("DualActionBar","Collectible",EVENT_COLLECTIBLE_UPDATED, function()
            self:InvalidateStyleCache029189()
            self:Refresh()
        end)
    end
    if EVENT_PLAYER_COMBAT_STATE then
        EPC.Runtime:RegisterEvent("DualActionBar","Combat",EVENT_PLAYER_COMBAT_STATE, function()
            self:RefreshDynamic029311(true)
        end)
    end
    if EVENT_POWER_UPDATE then
        local powerRegistration = prefix .. "_Power"
        EPC.Runtime:RegisterEvent("DualActionBar","Power",EVENT_POWER_UPDATE,function(_, unitTag, powerIndex, powerType)
            if unitTag == "player" and (powerType == COMBAT_MECHANIC_FLAGS_ULTIMATE or powerType == POWERTYPE_ULTIMATE) then
                self:RefreshDynamic029311(false)
            end
        end, {
            {REGISTER_FILTER_UNIT_TAG, "player"},
            {REGISTER_FILTER_POWER_TYPE, POWERTYPE_ULTIMATE},
        })
    end

    EPC.Runtime:UnregisterUpdate("DualActionBar","Tick")
    EPC.Runtime:RegisterUpdate("DualActionBar","Tick",125, function()
        if not EPC.saved or EPC.saved.showDualActionBar029189 ~= true then return end
        local nowValue = type(GetFrameTimeMilliseconds) == "function" and (tonumber(GetFrameTimeMilliseconds()) or 0) or 0
        local inCombat = type(IsUnitInCombat) == "function" and safe(IsUnitInCombat, false, "player") == true
        local gap = inCombat and 250 or 1000
        if not self.lastDynamicTick029315 or (nowValue - self.lastDynamicTick029315) >= gap then
            self.lastDynamicTick029315 = nowValue
            self:RefreshDynamic029311(false)
        end
    end)
    self:Refresh()
end


-- v0.29.321 - Keep the Dual Weapon Bar recommendation visually stable.
-- RotationAssistant intentionally clears generic guidance before selecting the
-- current render target.  Because the Dual Bar is then selected again in the
-- same recommendation pass, the old immediate clear caused the gold border to
-- be hidden and re-shown every scoring refresh.  That looks like a flash even
-- though the highlight alpha itself is no longer animated.
--
-- Defer a real clear for a very short grace window. A same-pass Set cancels the
-- pending clear, so an unchanged recommendation remains continuously visible.
-- A genuine HideActionGuidance still clears normally after the grace window.
local EAS_DAB_ClearSmartImmediate029321 = ClearSmartRecommendationImpl
local EAS_DAB_SetSmartImmediate029321 = SetSmartRecommendationImpl

function D:ApplySmartHighlightOnly029321()
    if not self.rows then return end
    local activeCategory = safe(GetActiveHotbarCategory, nil)
    local inactiveAlpha = clamp((EPC.saved and EPC.saved.dualActionBarInactiveAlpha029189 or 45) / 100, 0.10, 1.0)

    for _, row in ipairs(self.rows) do
        local category = row.epcCategory
        local recommendedOnRow = self.smartCategory029189 == category and self.smartSlot029189 ~= nil
        local active = category == activeCategory
        row:SetAlpha(active and 1.0 or (recommendedOnRow and math.max(inactiveAlpha, 0.78) or inactiveAlpha))

        for ordinal, frame in ipairs(row.slots or {}) do
            local ability = frame.epcAbility029311
            local slot = ability and ability.slot or self.slots[ordinal]
            local smartMatch = self.smartSlot029189 ~= nil
                and tonumber(self.smartSlot029189) == tonumber(slot)
                and self.smartCategory029189 == category

            if EAS_DAB_SetHidden029311 then
                EAS_DAB_SetHidden029311(frame.epcSmart, frame, "smartHidden029311", not smartMatch)
                EAS_DAB_SetHidden029311(frame.epcSwap, frame, "swapHidden029311", not (smartMatch and self.smartNeedsSwap029189 == true))
            else
                frame.epcSmart:SetHidden(not smartMatch)
                frame.epcSwap:SetHidden(not (smartMatch and self.smartNeedsSwap029189 == true))
            end
            if smartMatch then frame.epcSmart:SetAlpha(0.92) end
        end
    end
end

SetSmartRecommendationImpl = function(self, slot, category, pulse, needsSwap)
    -- Cancel any clear queued by the beginning of this same advisor pass.
    self.smartClearGeneration029321 = (tonumber(self.smartClearGeneration029321) or 0) + 1

    local newSlot = tonumber(slot)
    local newNeedsSwap = needsSwap == true
    local unchanged = self.smartSlot029189 == newSlot
        and self.smartCategory029189 == category
        and self.smartNeedsSwap029189 == newNeedsSwap

    local result = EAS_DAB_SetSmartImmediate029321(self, slot, category, 1.00, needsSwap)

    -- No animation and no metadata rebuild: just keep the 12 lightweight visual
    -- states correct. Reapplying an unchanged recommendation does not hide it.
    self:ApplySmartHighlightOnly029321()
    if unchanged then return result end
    return result
end

ClearSmartRecommendationImpl = function(self)
    self.smartClearGeneration029321 = (tonumber(self.smartClearGeneration029321) or 0) + 1
    local generation = self.smartClearGeneration029321

    local function reallyClear()
        if self.smartClearGeneration029321 ~= generation then return end
        EAS_DAB_ClearSmartImmediate029321(self)
        self:ApplySmartHighlightOnly029321()
    end

    -- The advisor's ShowActionHighlight clears then sets synchronously. A small
    -- deferred clear prevents that internal handoff from becoming visible.
    if type(zo_callLater) == "function" then
        zo_callLater(reallyClear, 90)
    else
        reallyClear()
    end
end

-- ============================================================================
-- v0.29.365 - proc/Ultimate readiness glow + sound on the dual action bar too.
-- ============================================================================
local EAS_DAB_RefreshDynamicBase029365 = RefreshDynamicImpl
local function EAS_DAB_EnsureReadyGlow029365(frame)
    if not frame or frame.epcReadyGlow029365 then return end
    local glow = WM:CreateControl(nil, frame, CT_BACKDROP)
    glow:SetAnchor(TOPLEFT, frame, TOPLEFT, -4, -4)
    glow:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 4, 4)
    glow:SetMouseEnabled(false)
    glow:SetCenterColor(1.00, 0.68, 0.05, 0.06)
    glow:SetEdgeColor(1.00, 0.90, 0.20, 1.00)
    glow:SetEdgeTexture(nil, 8, 8, 5)
    if glow.SetDrawLayer and DL_OVERLAY then glow:SetDrawLayer(DL_OVERLAY) end
    if glow.SetDrawLevel then glow:SetDrawLevel(1550) end
    glow:SetHidden(true)
    frame.epcReadyGlow029365 = glow
end

local function EAS_DAB_Signature029365(slot, category)
    local base = tonumber((safe(GetSlotBoundId, 0, slot, category))) or 0
    local effective = base
    if base > 0 and type(GetEffectiveAbilityIdForAbilityOnHotbar) == "function" then
        effective = tonumber((safe(GetEffectiveAbilityIdForAbilityOnHotbar, base, base, category))) or base
    end
    local texture = tostring(safe(GetSlotTexture, "", slot, category) or "")
    return tostring(base) .. ":" .. tostring(effective) .. ":" .. texture, base, effective
end

RefreshDynamicImpl = function(self, force)
    EAS_DAB_RefreshDynamicBase029365(self, force)
    if not self.window or self.window:IsHidden() then return end
    local activeCategory = safe(GetActiveHotbarCategory, nil)
    local nowValue = nowMS()
    for _, row in ipairs(self.rows or {}) do
        local category = row.epcCategory
        for ordinal, frame in ipairs(row.slots or {}) do
            EAS_DAB_EnsureReadyGlow029365(frame)
            local glow = frame.epcReadyGlow029365
            local slot = self.slots and self.slots[ordinal]
            if glow and slot then
                local sig, base, effective = EAS_DAB_Signature029365(slot, category)
                local previous = frame.epcReadySignature029365
                local procActive = ordinal < #(self.slots or {}) and base > 0 and effective > 0 and effective ~= base
                if procActive and frame.epcProcActiveWas029365 ~= true and previous and category == activeCategory then
                    local sound = SOUNDS and (rawget(SOUNDS, "ABILITY_SLOTTED") or rawget(SOUNDS, "DEFAULT_CLICK"))
                    if sound and type(PlaySound) == "function" then pcall(PlaySound, sound) end
                end
                frame.epcProcActiveWas029365 = procActive
                frame.epcReadySignature029365 = sig

                local ultimateReady = false
                if ordinal == #(self.slots or {}) and base > 0 and COMBAT_MECHANIC_FLAGS_ULTIMATE then
                    local current = tonumber((safe(GetUnitPower, 0, "player", COMBAT_MECHANIC_FLAGS_ULTIMATE))) or 0
                    local cost = tonumber((safe(GetSlotAbilityCost, 0, slot, category))) or 0
                    ultimateReady = cost > 0 and current >= cost
                    if category == activeCategory and ultimateReady and frame.epcUltimateWasReady029365 ~= true then
                        local sound = SOUNDS and rawget(SOUNDS, "ABILITY_ULTIMATE_READY")
                        if sound and type(PlaySound) == "function" then pcall(PlaySound, sound) end
                    end
                    frame.epcUltimateWasReady029365 = ultimateReady
                end
                local procReady = procActive
                glow:SetHidden(not (ultimateReady or procReady))
                if not glow:IsHidden() then
                    local phase = (nowValue % 700) / 700
                    glow:SetAlpha(0.55 + 0.45 * math.abs(phase * 2 - 1))
                end
            end
        end
    end
end

-- ============================================================================
-- v0.29.376 - action-bar live-state hardening.
--  * keep selected Skill Style artwork stable while a skill enters a proc/stack
--    runtime variant;
--  * never advertise an inactive-bar Ultimate as ready;
--  * refresh newly slotted skills after ESO finishes the slot mutation;
--  * wake stack rendering from effect events and bridge brief snapshot gaps.
-- ============================================================================
local EAS_DAB_RefreshStaticBase029376 = RefreshStaticImpl
local EAS_DAB_RefreshDynamicBase029376 = RefreshDynamicImpl
-- v0.29.386 - combat performance: player EVENT_EFFECT_CHANGED can fire many
-- times in a single frame. Collapse those bursts into one dynamic refresh.
function D:QueueDynamicRefresh029386(force)
    self.pendingDynamicRefreshForce029386 = self.pendingDynamicRefreshForce029386 == true or force == true
    if self.dynamicRefreshQueued029386 == true then return end
    self.dynamicRefreshQueued029386 = true
    local function run()
        local bar = EPC and EPC.DualActionBar
        if not bar then return end
        bar.dynamicRefreshQueued029386 = false
        local doForce = bar.pendingDynamicRefreshForce029386 == true
        bar.pendingDynamicRefreshForce029386 = false
        bar:RefreshDynamic029311(doForce)
    end
    if type(zo_callLater) == "function" then zo_callLater(run, 50) else run() end
end

local EAS_DAB_InitializeBase029376 = InitializeImpl

local function EAS_DAB_ProgressionId029376(abilityId)
    abilityId = tonumber(abilityId) or 0
    if abilityId <= 0 or type(GetSpecificSkillAbilityKeysByAbilityId) ~= "function"
        or type(GetProgressionSkillProgressionId) ~= "function" then return 0 end
    local skillType, skillLineIndex, skillIndex = safe(GetSpecificSkillAbilityKeysByAbilityId, nil, abilityId)
    if skillType == nil or skillLineIndex == nil or skillIndex == nil then return 0 end
    local value = safe(GetProgressionSkillProgressionId, 0, skillType, skillLineIndex, skillIndex)
    return tonumber((value)) or 0
end

RefreshStaticImpl = function(self, ...)
    local result = EAS_DAB_RefreshStaticBase029376(self, ...)
    self.stableStyleBySlot029376 = self.stableStyleBySlot029376 or {}
    for _, row in ipairs(self.rows or {}) do
        local category = row.epcCategory
        for ordinal, frame in ipairs(row.slots or {}) do
            local ability = frame.epcAbility029311
            if ability and ability.used == true then
                local slot = ability.slot or (self.slots and self.slots[ordinal])
                local baseId = tonumber(ability.abilityId) or 0
                local effectiveId = tonumber(ability.effectiveAbilityId029311) or baseId
                local fallback = tostring(ability.icon or "")
                local key = tostring(category) .. ":" .. tostring(slot or ordinal)
                local resolved = tostring(self:GetSkillStyleIcon(baseId, fallback) or "")
                local cached = self.stableStyleBySlot029376[key]
                local progressionId = EAS_DAB_ProgressionId029376(baseId)
                local styled = resolved ~= "" and resolved ~= fallback

                if styled then
                    cached = { abilityId = baseId, progressionId = progressionId, texture = resolved }
                    self.stableStyleBySlot029376[key] = cached
                elseif cached and cached.texture and cached.texture ~= "" then
                    local sameProgression = progressionId > 0 and cached.progressionId and cached.progressionId > 0
                        and progressionId == cached.progressionId
                    local priorEffective = cached.abilityId
                    if cached.abilityId and type(GetEffectiveAbilityIdForAbilityOnHotbar) == "function" then
                        priorEffective = tonumber((safe(GetEffectiveAbilityIdForAbilityOnHotbar, cached.abilityId, cached.abilityId, category))) or cached.abilityId
                    end
                    local runtimeVariant = effectiveId ~= baseId
                        or baseId == tonumber(priorEffective)
                        or effectiveId == tonumber(priorEffective)
                    if sameProgression or runtimeVariant or baseId == tonumber(cached.abilityId) then
                        resolved = cached.texture
                    else
                        self.stableStyleBySlot029376[key] = nil
                    end
                end

                if resolved ~= "" and frame.epcIcon then
                    EAS_DAB_SetTexture029311(frame.epcIcon, frame, "iconTexture029311", resolved)
                end
            end
        end
    end
    return result
end

RefreshDynamicImpl = function(self, force)
    local result = EAS_DAB_RefreshDynamicBase029376(self, force)
    if not self.rows then return result end
    self.stackGrace029376 = self.stackGrace029376 or {}
    local nowValue = nowMS()
    local activeCategory = safe(GetActiveHotbarCategory, nil)

    for _, row in ipairs(self.rows) do
        local category = row.epcCategory
        for ordinal, frame in ipairs(row.slots or {}) do
            local ability = frame.epcAbility029311
            local slot = ability and ability.slot or (self.slots and self.slots[ordinal])
            local key = tostring(category) .. ":" .. tostring(slot or ordinal)

            -- ESO/Rotation snapshots can briefly report zero stacks between the
            -- heavy-attack/effect event and the next effect snapshot. Keep the
            -- last non-zero badge for a short bridge only. Ability use clears it
            -- immediately below, so consumed stacks never linger for the grace.
            if frame.epcStack and frame.epcStack.GetText then
                local text = tostring(frame.epcStack:GetText() or "")
                if text ~= "" then
                    self.stackGrace029376[key] = { text = text, expires = nowValue + 900 }
                else
                    local cached = self.stackGrace029376[key]
                    if cached and nowValue <= (tonumber(cached.expires) or 0) then
                        EAS_DAB_SetText029311(frame.epcStack, frame, "stackText029311", cached.text)
                    elseif cached then
                        self.stackGrace029376[key] = nil
                    end
                end
            end

            -- The player cannot activate the inactive weapon-bar Ultimate. Do
            -- not glow it just because the shared Ultimate pool exceeds that
            -- ability's cost; readiness guidance belongs to the active bar.
            if ordinal == #(self.slots or {}) and frame.epcReadyGlow029365 and category ~= activeCategory then
                frame.epcReadyGlow029365:SetHidden(true)
                frame.epcUltimateWasReady029365 = false
            end
        end
    end
    return result
end

InitializeImpl = function(self)
    local result = EAS_DAB_InitializeBase029376(self)
    local prefix = (EPC.name or "ESOAdventurerSuite") .. "_DualActionBar029376"

    -- EVENT_ACTION_SLOT_UPDATED can fire before the new slot payload is fully
    -- visible to GetSlotBoundId/GetSlotTexture. Re-read on the next short frame
    -- boundary so drag/drop skill changes appear without requiring a bar swap.
    if EVENT_ACTION_SLOT_UPDATED then
        EPC.Runtime:RegisterEvent("DualActionBar","SlotSettled",EVENT_ACTION_SLOT_UPDATED, function()
            local function refreshSettled()
                if EPC and EPC.DualActionBar then
                    EPC.DualActionBar:InvalidateStyleCache029189()
                    EPC.DualActionBar:Refresh()
                end
            end
            if type(zo_callLater) == "function" then
                zo_callLater(refreshSettled, 35)
                zo_callLater(refreshSettled, 120)
            else refreshSettled() end
        end)
    end
    if EVENT_ACTION_SLOTS_FULL_UPDATE then
        EPC.Runtime:RegisterEvent("DualActionBar","SlotsFull",EVENT_ACTION_SLOTS_FULL_UPDATE, function()
            if type(zo_callLater) == "function" then
                zo_callLater(function() if EPC and EPC.DualActionBar then EPC.DualActionBar:Refresh() end end, 30)
            elseif EPC and EPC.DualActionBar then EPC.DualActionBar:Refresh() end
        end)
    end
    if EVENT_ACTION_SLOT_ABILITY_USED then
        EPC.Runtime:RegisterEvent("DualActionBar","Used",EVENT_ACTION_SLOT_ABILITY_USED, function(_, slot)
            local category = safe(GetActiveHotbarCategory, nil)
            if self.stackGrace029376 then self.stackGrace029376[tostring(category) .. ":" .. tostring(slot)] = nil end
            self:RefreshDynamic029311(true)
        end)
    end
    if EVENT_EFFECT_CHANGED then
        local filters = REGISTER_FILTER_UNIT_TAG and {{REGISTER_FILTER_UNIT_TAG, "player"}} or nil
        EPC.Runtime:RegisterEvent("DualActionBar", "Effect", EVENT_EFFECT_CHANGED, function()
            self:QueueDynamicRefresh029386(true)
        end, filters)
    end
    return result
end

-- ============================================================================
-- v0.29.380 - immediate scene visibility + event-driven stack state.
-- Fixes delayed hide/show on menu scene transitions and stale/delayed stack
-- counters (notably Grim Focus-family abilities after heavy attacks/consume).
-- ============================================================================
local EAS_DAB_InitializeBase029380 = InitializeImpl
local EAS_DAB_RefreshDynamicBase029380 = RefreshDynamicImpl

local function EAS_DAB_Now029380()
    if type(GetFrameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetFrameTimeMilliseconds)
        if ok then return tonumber(value) or 0 end
    end
    return 0
end

local function EAS_DAB_HideImmediately029380(self)
    if self and self.window and self.layoutMode ~= true then
        self.window:SetHidden(true)
        self.windowHidden029311 = true
    end
end

local function EAS_DAB_RegisterSceneCallbacks029380(self)
    if self.sceneVisibilityHooks029380 or not SCENE_MANAGER or type(SCENE_MANAGER.GetScene) ~= "function" then return end
    self.sceneVisibilityHooks029380 = true
    local names = {
        "gameMenuInGame", "gameMenu", "inventory", "character", "skills", "championPerks",
        "journal", "collectionsBook", "groupMenu", "groupList", "groupFinderKeyboard",
        "contacts", "friendsList", "friendsListKeyboard", "guildHome", "guildRoster",
        "mailInbox", "mailSend", "bank", "guildBank", "store", "tradingHouse",
        "crafting", "smithing", "alchemy", "enchanting", "provisioner", "settings",
        "worldMap", "achievements", "loreLibrary", "housingEditor",
    }
    for i = 1, #names do
        local ok, scene = pcall(SCENE_MANAGER.GetScene, SCENE_MANAGER, names[i])
        if ok and scene and type(scene.RegisterCallback) == "function" then
            scene:RegisterCallback("StateChange", function(_, newState)
                if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                    EAS_DAB_HideImmediately029380(self)
                elseif newState == SCENE_HIDDEN then
                    if type(zo_callLater) == "function" then
                        zo_callLater(function()
                            if EPC and EPC.DualActionBar then EPC.DualActionBar:IsVisibleNow029311() end
                        end, 0)
                    else
                        self:IsVisibleNow029311()
                    end
                end
            end)
        end
    end
end

RefreshDynamicImpl = function(self, force)
    local result = EAS_DAB_RefreshDynamicBase029380(self, force)
    if not self.rows then return result end
    self.stackDirect029380 = self.stackDirect029380 or { byId = {}, byName = {} }
    self.stackConsumedUntil029380 = self.stackConsumedUntil029380 or {}
    local nowValue = EAS_DAB_Now029380()

    for _, row in ipairs(self.rows) do
        local category = row.epcCategory
        for ordinal, frame in ipairs(row.slots or {}) do
            local ability = frame.epcAbility029311
            if ability and ability.used == true and frame.epcStack then
                local key = tostring(category) .. ":" .. tostring(ability.slot or ordinal)
                local suppressUntil = tonumber(self.stackConsumedUntil029380[key]) or 0
                if suppressUntil > nowValue then
                    EAS_DAB_SetText029311(frame.epcStack, frame, "stackText029311", "")
                    if self.stackGrace029376 then self.stackGrace029376[key] = nil end
                else
                    local best = 0
                    local abilityId = tonumber(ability.abilityId) or 0
                    local effectiveId = tonumber(ability.effectiveAbilityId029311) or 0
                    if abilityId > 0 then best = math.max(best, tonumber(self.stackDirect029380.byId[abilityId]) or 0) end
                    if effectiveId > 0 then best = math.max(best, tonumber(self.stackDirect029380.byId[effectiveId]) or 0) end
                    local normalizedName = EAS_DAB_Normalize029311(ability.name or "")
                    if normalizedName ~= "" then best = math.max(best, tonumber(self.stackDirect029380.byName[normalizedName]) or 0) end
                    if best > 0 then
                        local threshold = 0
                        local current = tostring(frame.epcStack:GetText() or "")
                        threshold = tonumber(current:match("/(%d+)$")) or 0
                        local text = threshold > 0 and (tostring(math.floor(best + 0.5)) .. "/" .. tostring(threshold)) or tostring(math.floor(best + 0.5))
                        EAS_DAB_SetText029311(frame.epcStack, frame, "stackText029311", text)
                        if self.stackGrace029376 then self.stackGrace029376[key] = { text = text, expires = nowValue + 300 } end
                    end
                end
            end
        end
    end
    return result
end

InitializeImpl = function(self)
    local result = EAS_DAB_InitializeBase029380(self)
    EAS_DAB_RegisterSceneCallbacks029380(self)
    local prefix = (EPC.name or "ESOAdventurerSuite") .. "_DualActionBar029380"
    self.stackDirect029380 = self.stackDirect029380 or { byId = {}, byName = {} }
    self.stackConsumedUntil029380 = self.stackConsumedUntil029380 or {}

    if EVENT_EFFECT_CHANGED then
        EPC.Runtime:RegisterEvent("DualActionBar", "Stacks", EVENT_EFFECT_CHANGED,
            function(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName,
                     buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
                local count = math.max(0, tonumber(stackCount) or 0)
                local id = tonumber(abilityId) or 0
                local name = EAS_DAB_Normalize029311(effectName or "")
                if id > 0 then self.stackDirect029380.byId[id] = count end
                if name ~= "" then self.stackDirect029380.byName[name] = count end

                -- A fresh non-zero stack event is authoritative and cancels any
                -- short consume suppression created by the proc spender.
                if count > 0 then
                    self.stackConsumedUntil029380 = {}
                end
                self.lastDynamicAt029311 = nil
                self:QueueDynamicRefresh029386(true)
            end, REGISTER_FILTER_UNIT_TAG and {{REGISTER_FILTER_UNIT_TAG, "player"}} or nil)
    end

    if EVENT_ACTION_SLOT_ABILITY_USED then
        EPC.Runtime:RegisterEvent("DualActionBar","Consume",EVENT_ACTION_SLOT_ABILITY_USED, function(_, slot)
            local category = safe(GetActiveHotbarCategory, nil)
            local key = tostring(category) .. ":" .. tostring(slot)
            self.stackConsumedUntil029380[key] = EAS_DAB_Now029380() + 900
            if self.stackGrace029376 then self.stackGrace029376[key] = nil end
            -- Clear the visible badge immediately; don't wait for ESO's effect
            -- removal snapshot, which can trail the actual proc use.
            for _, row in ipairs(self.rows or {}) do
                if row.epcCategory == category then
                    for _, frame in ipairs(row.slots or {}) do
                        local ability = frame.epcAbility029311
                        if ability and tonumber(ability.slot) == tonumber(slot) and frame.epcStack then
                            EAS_DAB_SetText029311(frame.epcStack, frame, "stackText029311", "")
                        end
                    end
                end
            end
            self.lastDynamicAt029311 = nil
            self:RefreshDynamic029311(true)
        end)
    end

    return result
end


-- ============================================================================
-- v0.29.381 - authoritative hotbar slot refresh.
-- ESO can publish drag/drop slot data over more than one UI frame. Refresh the
-- static bar directly from the hotbar APIs at several settled frame boundaries
-- so a newly moved/replaced skill never waits for a weapon swap.
-- ============================================================================
local EAS_DAB_InitializeBase029381 = InitializeImpl
InitializeImpl = function(self)
    local result = EAS_DAB_InitializeBase029381(self)
    local prefix = (EPC.name or "ESOAdventurerSuite") .. "_DualActionBar029381"
    local function hardRefresh()
        if not EPC or not EPC.DualActionBar then return end
        local bar = EPC.DualActionBar
        bar.staticAbilityData029311 = {}
        if bar.InvalidateStyleCache029189 then bar:InvalidateStyleCache029189() end
        bar.lastDynamicAt029311 = nil
        bar:Refresh()
    end
    local function settle()
        hardRefresh()
        if type(zo_callLater) == "function" then
            zo_callLater(hardRefresh, 16)
            zo_callLater(hardRefresh, 60)
            zo_callLater(hardRefresh, 180)
        end
    end
    if EVENT_ACTION_SLOT_UPDATED then
        EPC.Runtime:RegisterEvent("DualActionBar","Slot",EVENT_ACTION_SLOT_UPDATED, function() settle() end)
    end
    if EVENT_ACTION_SLOTS_FULL_UPDATE then
        EPC.Runtime:RegisterEvent("DualActionBar","Full",EVENT_ACTION_SLOTS_FULL_UPDATE, function() settle() end)
    end
    return result
end

-- ============================================================================
-- v0.29.382 - stack-ready glow + unusable/no-target visual state.
-- Proc-mode glow/sound already exists since v0.29.365.  This layer adds a
-- generic stack-threshold readiness glow (covers Grim Focus when its tracked
-- state reaches 5/5) and dims active-bar skills when ESO says the slot cannot
-- currently be used.  Runtime variants such as Venom Skull at its empowered
-- state continue to use the effective-ability proc glow, so no English skill
-- name matching is required here.
-- ============================================================================
local EAS_DAB_RefreshDynamicBase029382 = RefreshDynamicImpl

local function EAS_DAB_ParseStacks029382(frame)
    if not frame or not frame.epcStack or type(frame.epcStack.GetText) ~= "function" then return 0, 0 end
    local text = tostring(frame.epcStack:GetText() or "")
    local a, b = text:match("^(%d+)%s*/%s*(%d+)$")
    if a then return tonumber(a) or 0, tonumber(b) or 0 end
    return tonumber(text:match("^(%d+)$")) or 0, 0
end

RefreshDynamicImpl = function(self, force)
    local result = EAS_DAB_RefreshDynamicBase029382(self, force)
    if not self.window or self.window:IsHidden() then return result end
    local activeCategory = safe(GetActiveHotbarCategory, nil)
    local nowValue = nowMS()

    for _, row in ipairs(self.rows or {}) do
        local category = row.epcCategory
        for ordinal, frame in ipairs(row.slots or {}) do
            local ability = frame.epcAbility029311
            local slot = ability and ability.slot or (self.slots and self.slots[ordinal])
            if ability and ability.used == true and slot then
                EAS_DAB_EnsureReadyGlow029365(frame)
                local glow = frame.epcReadyGlow029365
                local stacks, threshold = EAS_DAB_ParseStacks029382(frame)
                local stackReady = (threshold > 0 and stacks >= threshold) or (threshold <= 0 and stacks >= 5)

                -- Keep the existing proc/Ultimate readiness state, then add the
                -- stack-spender readiness state.  This makes Grim Focus glow at
                -- 5 stacks without hardcoding its localized name.
                if glow and stackReady then
                    glow:SetHidden(false)
                    local phase = (nowValue % 700) / 700
                    glow:SetAlpha(0.62 + 0.38 * math.abs(phase * 2 - 1))
                end

                -- ESO's native slot-usability result accounts for the current
                -- resource/casting/target restrictions. Only evaluate the active
                -- bar; an inactive bar cannot be activated and should retain the
                -- user's configured inactive-bar appearance instead of being
                -- falsely marked unusable.
                local usable = true
                if category == activeCategory and ordinal < #(self.slots or {}) and type(IsSlotUsable) == "function" then
                    usable = (safe(IsSlotUsable, true, slot, category)) ~= false
                end
                local icon = frame.epcIcon
                if icon and type(icon.SetAlpha) == "function" then
                    icon:SetAlpha(usable and 1.0 or 0.30)
                end
                if frame.epcShade and type(frame.epcShade.SetCenterColor) == "function" then
                    if usable then frame.epcShade:SetCenterColor(0, 0, 0, 0)
                    else frame.epcShade:SetCenterColor(0, 0, 0, 0.48) end
                end
            end
        end
    end
    return result
end

-- ============================================================================
-- v0.29.383 - action-bar interaction/proc/style corrections.
--  * only render Skill Style artwork while ESO reports a style override active;
--  * let runtime proc icons (Crystal Fragments etc.) update from GetSlotTexture;
--  * Venom Skull counter displays 0..2 and clears after the empowered third use;
--  * custom bar slots expose a safe hover description and hardware-event drag/drop.
-- ============================================================================
local function EAS_DAB_GetActiveStyleCollectible029383(abilityId)
    abilityId = tonumber(abilityId) or 0
    if abilityId <= 0 or type(GetSpecificSkillAbilityKeysByAbilityId) ~= "function"
        or type(GetProgressionSkillProgressionId) ~= "function"
        or type(GetActiveProgressionSkillAbilityFxOverrideCollectibleId) ~= "function" then return 0 end
    abilityId = SKILL_STYLE_ABILITY_ALIAS_029189[abilityId] or abilityId
    local skillType, skillLineIndex, skillIndex = safe(GetSpecificSkillAbilityKeysByAbilityId, nil, abilityId)
    if skillType == nil or skillLineIndex == nil or skillIndex == nil then return 0 end
    local progressionId = tonumber(safe(GetProgressionSkillProgressionId, 0, skillType, skillLineIndex, skillIndex)) or 0
    if progressionId <= 0 then return 0 end
    return tonumber(safe(GetActiveProgressionSkillAbilityFxOverrideCollectibleId, 0, progressionId)) or 0
end

local EAS_DAB_GetSkillStyleIconBase029383 = GetSkillStyleIconImpl
GetSkillStyleIconImpl = function(self, abilityId, fallbackIcon)
    if not EPC.saved or EPC.saved.dualActionBarSkillStyles029189 == false then return fallbackIcon or "" end
    -- The previous stable-style cache could keep a formerly selected style after
    -- the player switched back to the default skill appearance. ESO's active
    -- override id is authoritative: zero means render the live native icon.
    if EAS_DAB_GetActiveStyleCollectible029383(abilityId) <= 0 then
        if self.styleIconCache029189 then self.styleIconCache029189[tonumber(abilityId) or 0] = false end
        return fallbackIcon or ""
    end
    return EAS_DAB_GetSkillStyleIconBase029383(self, abilityId, fallbackIcon)
end

local EAS_DAB_RefreshStaticBase029383 = RefreshStaticImpl
RefreshStaticImpl = function(self, ...)
    local result = EAS_DAB_RefreshStaticBase029383(self, ...)
    -- Drop a remembered styled texture immediately when that slot no longer has
    -- an active Skill Style. This deliberately does not disturb an active style
    -- during a proc/runtime ability-id change.
    for _, row in ipairs(self.rows or {}) do
        local category = row.epcCategory
        for ordinal, frame in ipairs(row.slots or {}) do
            local ability = frame.epcAbility029311
            if ability and ability.used == true then
                local key = tostring(category) .. ":" .. tostring(ability.slot or ordinal)
                if EAS_DAB_GetActiveStyleCollectible029383(ability.abilityId) <= 0 and self.stableStyleBySlot029376 then
                    self.stableStyleBySlot029376[key] = nil
                end
            end
        end
    end
    return result
end

local function EAS_DAB_IsVenomSkull029383(ability)
    if not ability then return false end
    local name = EAS_DAB_Normalize029311(ability.name or "")
    if name:find("venom skull", 1, true) then return true end
    -- Name-independent fallback: look for the unique localized mechanic text.
    local id = tonumber(ability.abilityId) or 0
    if id > 0 and type(GetAbilityDescription) == "function" then
        local description = EAS_DAB_Normalize029311(safe(GetAbilityDescription, "", id) or "")
        if description:find("third", 1, true) and description:find("necromancer", 1, true) then return true end
    end
    return false
end

local EAS_DAB_RefreshDynamicBase029383 = RefreshDynamicImpl
RefreshDynamicImpl = function(self, force)
    local result = EAS_DAB_RefreshDynamicBase029383(self, force)
    if not self.rows then return result end

    for _, row in ipairs(self.rows) do
        local category = row.epcCategory
        for ordinal, frame in ipairs(row.slots or {}) do
            local ability = frame.epcAbility029311
            if ability and ability.used == true then
                local slot = ability.slot or (self.slots and self.slots[ordinal])
                if slot then
                    -- If no Skill Style is actually selected, the live hotbar
                    -- texture is the authority. ESO swaps this texture for proc
                    -- states such as Crystal Fragments; update it without waiting
                    -- for a weapon swap/static rebuild.
                    if EAS_DAB_GetActiveStyleCollectible029383(ability.abilityId) <= 0 then
                        local liveTexture = tostring(safe(GetSlotTexture, ability.icon or "", slot, category) or "")
                        if liveTexture ~= "" and frame.epcIcon then
                            EAS_DAB_SetTexture029311(frame.epcIcon, frame, "iconTexture029311", liveTexture)
                        end
                    end

                    -- Venom Skull's third cast is the empowered cast, not a third
                    -- stored stack. Keep the visible counter in the useful 0..2
                    -- range; EVENT_ACTION_SLOT_ABILITY_USED below clears it as
                    -- soon as the empowered skull is consumed.
                    if EAS_DAB_IsVenomSkull029383(ability) and frame.epcStack and frame.epcStack.GetText then
                        local text = tostring(frame.epcStack:GetText() or "")
                        local count = tonumber(text:match("^(%d+)"))
                        if count and count > 2 then
                            EAS_DAB_SetText029311(frame.epcStack, frame, "stackText029311", "2")
                        end
                    end
                end
            end
        end
    end
    return result
end

function D:EnsureHoverTooltip029471()
    if self.hoverTooltip029471 then return self.hoverTooltip029471 end
    local tip = WM:CreateTopLevelWindow("EAS_DualActionBarHoverTooltip029471")
    tip:SetDimensions(420, 120)
    tip:SetMouseEnabled(false)
    tip:SetClampedToScreen(true)
    tip:SetHidden(true)
    if tip.SetDrawLayer and DL_OVERLAY then tip:SetDrawLayer(DL_OVERLAY) end
    if tip.SetDrawTier and DT_HIGH then tip:SetDrawTier(DT_HIGH) end
    if tip.SetDrawLevel then tip:SetDrawLevel(10000) end

    local bg = WM:CreateControl("EAS_DualActionBarHoverTooltip029471BG", tip, CT_BACKDROP)
    bg:SetAnchorFill(tip)
    bg:SetMouseEnabled(false)
    bg:SetCenterTexture("EsoUI/Art/Tooltips/UI-TooltipCenter.dds")
    bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-TooltipBorder.dds", 16, 4, 4)
    bg:SetCenterColor(0.015, 0.015, 0.015, 0.96)
    bg:SetEdgeColor(0.58, 0.46, 0.20, 0.96)
    bg:SetDrawLayer(DL_OVERLAY)
    bg:SetDrawLevel(9998)

    local title = WM:CreateControl("EAS_DualActionBarHoverTooltip029471Title", tip, CT_LABEL)
    title:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
    title:SetColor(1.00, 0.84, 0.32, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    title:SetAnchor(TOPLEFT, tip, TOPLEFT, 12, 10)
    title:SetAnchor(TOPRIGHT, tip, TOPRIGHT, -12, 10)
    title:SetHeight(24)
    title:SetDrawLayer(DL_OVERLAY)
    title:SetDrawLevel(10001)

    local body = WM:CreateControl("EAS_DualActionBarHoverTooltip029471Body", tip, CT_LABEL)
    body:SetFont("$(MEDIUM_FONT)|15|soft-shadow-thin")
    body:SetColor(0.98, 0.98, 0.98, 1)
    body:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    body:SetVerticalAlignment(TEXT_ALIGN_TOP)
    body:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 6)
    body:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 6)
    body:SetDrawLayer(DL_OVERLAY)
    body:SetDrawLevel(10001)
    if body.SetMaxLineCount then body:SetMaxLineCount(12) end

    tip.bg = bg
    tip.title = title
    tip.body = body
    self.hoverTooltip029471 = tip
    return tip
end

function D:ShowHoverTooltip029471(control, abilityId, fallbackName)
    local tip = self:EnsureHoverTooltip029471()
    if not tip then return end
    local name = tostring(safe(GetAbilityName, fallbackName or "", abilityId) or fallbackName or "")
    local description = tostring(safe(GetAbilityDescription, "", abilityId) or "")
    tip.title:SetText(name)
    tip.body:SetText(description)

    local bodyHeight = 26
    if tip.body.GetTextHeight then
        local ok, measured = pcall(tip.body.GetTextHeight, tip.body)
        if ok and tonumber(measured) then bodyHeight = math.max(26, tonumber(measured)) end
    end
    local height = zo_clamp(48 + bodyHeight, 82, 310)
    tip:SetDimensions(420, height)
    tip:ClearAnchors()
    -- Prefer above the slot; clamping keeps it on screen if the bar is near an edge.
    tip:SetAnchor(BOTTOM, control, TOP, 0, -10)
    tip:SetHidden(false)
end

function D:HideHoverTooltip029471()
    if self.hoverTooltip029471 then self.hoverTooltip029471:SetHidden(true) end
end

function D:InstallSlotInteraction029383(frame)
    if not frame or frame.epcInteraction029383 then return end
    frame.epcInteraction029383 = true
    frame:SetMouseEnabled(true)

    frame:SetHandler("OnMouseEnter", function(control)
        local ability = control.epcAbility029311
        if not ability or ability.used ~= true then return end
        local effectiveId = tonumber(ability.effectiveAbilityId029311) or 0
        if effectiveId <= 0 and type(GetEffectiveAbilityIdForAbilityOnHotbar) == "function" then
            effectiveId = tonumber(safe(GetEffectiveAbilityIdForAbilityOnHotbar, 0, ability.abilityId, ability.category)) or 0
        end
        local id = effectiveId > 0 and effectiveId or (tonumber(ability.abilityId) or 0)
        if id <= 0 then return end
        D:ShowHoverTooltip029471(control, id, ability.name)
    end)
    frame:SetHandler("OnMouseExit", function()
        D:HideHoverTooltip029471()
    end)

    frame:SetHandler("OnDragStart", function(control, button)
        if MOUSE_BUTTON_INDEX_LEFT and button and button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if safe(IsUnitInCombat, false, "player") == true then return end
        local ability = control.epcAbility029311
        if not ability or ability.used ~= true then return end
        local slot = tonumber(ability.slot)
        local category = ability.category
        if not slot then return end
        -- Protected action-bar mutation is only attempted directly from this
        -- hardware drag event. Never call it from timers/events.
        if type(CallSecureProtected) == "function" then
            pcall(CallSecureProtected, "PickupAction", slot, category)
        end
    end)

    frame:SetHandler("OnReceiveDrag", function(control)
        if safe(IsUnitInCombat, false, "player") == true then return end
        local ability = control.epcAbility029311
        local slot = tonumber(ability and ability.slot) or tonumber(self.slots and self.slots[control.epcOrdinal])
        local category = ability and ability.category or (control:GetParent() and control:GetParent().epcCategory)
        if not slot then return end
        if type(CallSecureProtected) == "function" then
            local ok, placed = pcall(CallSecureProtected, "PlaceInActionBar", slot, category)
            if ok and placed ~= false then
                self.staticAbilityData029311 = {}
                self:InvalidateStyleCache029189()
                if type(zo_callLater) == "function" then zo_callLater(function() if EPC and EPC.DualActionBar then EPC.DualActionBar:Refresh() end end, 0) end
            end
        end
    end)
end

local EAS_DAB_CreateUIBase029383 = CreateUIImpl
CreateUIImpl = function(self)
    EAS_DAB_CreateUIBase029383(self)
    for _, row in ipairs(self.rows or {}) do
        for _, frame in ipairs(row.slots or {}) do self:InstallSlotInteraction029383(frame) end
    end
end

local EAS_DAB_InitializeBase029383 = InitializeImpl
InitializeImpl = function(self)
    local result = EAS_DAB_InitializeBase029383(self)
    self:CreateUI()
    local prefix = (EPC.name or "ESOAdventurerSuite") .. "_DualActionBar029383"
    if EVENT_ACTION_SLOT_ABILITY_USED then
        EPC.Runtime:RegisterEvent("DualActionBar","VenomConsume",EVENT_ACTION_SLOT_ABILITY_USED, function(_, slot)
            local category = safe(GetActiveHotbarCategory, nil)
            for _, row in ipairs(self.rows or {}) do
                if row.epcCategory == category then
                    for _, frame in ipairs(row.slots or {}) do
                        local ability = frame.epcAbility029311
                        if ability and tonumber(ability.slot) == tonumber(slot) and EAS_DAB_IsVenomSkull029383(ability) then
                            -- The empowered third skull is represented by ESO's
                            -- runtime variant. If it was active at cast time, reset
                            -- the visible count immediately rather than showing 3.
                            local baseId = tonumber(ability.abilityId) or 0
                            local effectiveId = baseId
                            if baseId > 0 and type(GetEffectiveAbilityIdForAbilityOnHotbar) == "function" then
                                effectiveId = tonumber(safe(GetEffectiveAbilityIdForAbilityOnHotbar, baseId, baseId, category)) or baseId
                            end
                            if effectiveId ~= baseId and frame.epcStack then
                                EAS_DAB_SetText029311(frame.epcStack, frame, "stackText029311", "")
                                local key = tostring(category) .. ":" .. tostring(slot)
                                if self.stackGrace029376 then self.stackGrace029376[key] = nil end
                                if self.stackConsumedUntil029380 then self.stackConsumedUntil029380[key] = nowMS() + 900 end
                            end
                        end
                    end
                end
            end
            self.lastDynamicAt029311 = nil
        end)
    end
    return result
end


-- ============================================================================
-- v0.29.384 - Grim Focus release reset + settled slot mutation refresh.
-- ============================================================================
local EAS_DAB_RefreshDynamicBase029384 = RefreshDynamicImpl
local EAS_DAB_InitializeBase029384 = InitializeImpl

local function EAS_DAB_StackNumbers029384(frame)
    if not frame or not frame.epcStack or not frame.epcStack.GetText then return 0, 0 end
    local text = tostring(frame.epcStack:GetText() or "")
    local current, threshold = text:match("^(%d+)%s*/%s*(%d+)$")
    if current then return tonumber(current) or 0, tonumber(threshold) or 0 end
    return tonumber(text:match("^(%d+)$")) or 0, 0
end

RefreshDynamicImpl = function(self, force)
    local result = EAS_DAB_RefreshDynamicBase029384(self, force)
    if not self.rows then return result end
    self.stackReleaseSuppress029384 = self.stackReleaseSuppress029384 or {}
    local nowValue = nowMS()
    for _, row in ipairs(self.rows) do
        local category = row.epcCategory
        for ordinal, frame in ipairs(row.slots or {}) do
            local ability = frame.epcAbility029311
            local slot = ability and ability.slot or (self.slots and self.slots[ordinal])
            local key = tostring(category) .. ":" .. tostring(slot or ordinal)
            local untilMs = tonumber(self.stackReleaseSuppress029384[key]) or 0
            if untilMs > nowValue and frame.epcStack then
                -- A spender used at a full stack threshold is authoritative.  Do
                -- not let a late EFFECT_CHANGED snapshot repaint the old 5/5.
                EAS_DAB_SetText029311(frame.epcStack, frame, "stackText029311", "")
                if self.stackGrace029376 then self.stackGrace029376[key] = nil end
            elseif untilMs > 0 then
                self.stackReleaseSuppress029384[key] = nil
            end
        end
    end
    return result
end

InitializeImpl = function(self)
    local result = EAS_DAB_InitializeBase029384(self)
    local prefix = (EPC.name or "ESOAdventurerSuite") .. "_DualActionBar029384"
    self.stackReleaseSuppress029384 = self.stackReleaseSuppress029384 or {}

    -- Record a full-stack spender before the older stack/event layers have a
    -- chance to repaint a stale snapshot.  This is language-agnostic: it keys
    -- from the visible N/N threshold rather than English ability names.
    if EVENT_ACTION_SLOT_ABILITY_USED then
        EPC.Runtime:RegisterEvent("DualActionBar","FullStackConsume",EVENT_ACTION_SLOT_ABILITY_USED, function(_, usedSlot)
            local category = safe(GetActiveHotbarCategory, nil)
            for _, row in ipairs(self.rows or {}) do
                if row.epcCategory == category then
                    for ordinal, frame in ipairs(row.slots or {}) do
                        local ability = frame.epcAbility029311
                        local slot = ability and ability.slot or (self.slots and self.slots[ordinal])
                        if tonumber(slot) == tonumber(usedSlot) then
                            local current, threshold = EAS_DAB_StackNumbers029384(frame)
                            if threshold > 0 and current >= threshold then
                                local key = tostring(category) .. ":" .. tostring(slot)
                                self.stackReleaseSuppress029384[key] = nowMS() + 1600
                                if self.stackGrace029376 then self.stackGrace029376[key] = nil end
                                if frame.epcStack then EAS_DAB_SetText029311(frame.epcStack, frame, "stackText029311", "") end
                            end
                        end
                    end
                end
            end
        end)
    end

    -- Slot mutation data can settle over several frames, especially when the
    -- drag originated from the Skills UI.  Poll only after slot-change events;
    -- there is no gameplay OnUpdate cost.
    local function settledRefresh()
        if not EPC or not EPC.DualActionBar then return end
        local bar = EPC.DualActionBar
        bar.staticAbilityData029311 = {}
        if bar.InvalidateStyleCache029189 then bar:InvalidateStyleCache029189() end
        bar.lastDynamicAt029311 = nil
        bar:Refresh()
    end
    local function scheduleSettledRefreshes()
        settledRefresh()
        if type(zo_callLater) == "function" then
            zo_callLater(settledRefresh, 40)
            zo_callLater(settledRefresh, 120)
            zo_callLater(settledRefresh, 300)
            zo_callLater(settledRefresh, 650)
        end
    end
    if EVENT_ACTION_SLOT_UPDATED then
        EPC.Runtime:RegisterEvent("DualActionBar","SlotSettle",EVENT_ACTION_SLOT_UPDATED, scheduleSettledRefreshes)
    end
    if EVENT_ACTION_SLOTS_FULL_UPDATE then
        EPC.Runtime:RegisterEvent("DualActionBar","FullSettle",EVENT_ACTION_SLOTS_FULL_UPDATE, scheduleSettledRefreshes)
    end

    return result
end

-- ============================================================================
-- v0.29.385 - Venom Skull readiness + runtime skill-mode cue + usability fade.
--
--  * Venom Skull glows as soon as its visible setup counter reaches 2.
--  * Runtime skill-mode changes (Crystal Fragments proc, Power Whip proc, etc.)
--    glow the slot and play one sound when the changed mode first becomes active.
--    Detection is language-independent: effective ability id and the live ESO
--    hotbar texture are compared with the bound/base ability.
--  * Active-bar skill icons fade whenever ESO reports the slot unusable, which
--    includes resource/casting/target-context restrictions exposed by
--    IsSlotUsable (for example corpse/target dependent abilities).
--
-- This is visual-only. It never mutates ESO's action slots and has no OnUpdate of
-- its own; it rides the DualActionBar's existing lightweight dynamic refresh.
-- ============================================================================
local EAS_DAB_RefreshDynamicBase029385 = RefreshDynamicImpl

local function EAS_DAB_GetLiveModeState029385(ability, slot, category)
    if not ability or not slot then return false, 0, 0, "", "" end

    local boundId = tonumber(safe(GetSlotBoundId, 0, slot, category)) or tonumber(ability.abilityId) or 0
    local effectiveId = boundId
    if boundId > 0 and type(GetEffectiveAbilityIdForAbilityOnHotbar) == "function" then
        effectiveId = tonumber(safe(GetEffectiveAbilityIdForAbilityOnHotbar, boundId, boundId, category)) or boundId
    end

    local liveTexture = tostring(safe(GetSlotTexture, "", slot, category) or "")
    local baseTexture = ""
    if boundId > 0 and type(GetAbilityIcon) == "function" then
        baseTexture = tostring(safe(GetAbilityIcon, "", boundId) or "")
    end
    if baseTexture == "" then baseTexture = tostring(ability.icon or "") end

    -- A selected Skill Style legitimately changes the hotbar artwork; that is
    -- not a proc/mode transition. Only use texture-difference detection when no
    -- Skill Style collectible is actually active for the bound ability.
    local styleActive = false
    if boundId > 0 and type(EAS_DAB_GetActiveStyleCollectible029383) == "function" then
        styleActive = EAS_DAB_GetActiveStyleCollectible029383(boundId) > 0
    end

    local idChanged = boundId > 0 and effectiveId > 0 and effectiveId ~= boundId
    local textureChanged = (not styleActive) and liveTexture ~= "" and baseTexture ~= "" and liveTexture ~= baseTexture
    return idChanged or textureChanged, boundId, effectiveId, liveTexture, baseTexture
end

local function EAS_DAB_PlayProcCue029385()
    if type(PlaySound) ~= "function" or not SOUNDS then return end
    local sound = rawget(SOUNDS, "ABILITY_SLOTTED")
        or rawget(SOUNDS, "ABILITY_READY")
        or rawget(SOUNDS, "DEFAULT_CLICK")
    if sound then pcall(PlaySound, sound) end
end

RefreshDynamicImpl = function(self, force)
    local result = EAS_DAB_RefreshDynamicBase029385(self, force)
    if not self.window or self.window:IsHidden() or not self.rows then return result end

    local activeCategory = safe(GetActiveHotbarCategory, nil)
    local nowValue = nowMS()

    for _, row in ipairs(self.rows) do
        local category = row.epcCategory
        for ordinal, frame in ipairs(row.slots or {}) do
            local ability = frame.epcAbility029311
            local slot = ability and ability.slot or (self.slots and self.slots[ordinal])

            if ability and ability.used == true and slot then
                EAS_DAB_EnsureReadyGlow029365(frame)
                local glow = frame.epcReadyGlow029365

                -- Venom Skull is ready on the NEXT (third) cast once two setup
                -- counts are active, so 2 is the readiness threshold regardless
                -- of whether the generic tracker exposes a /3 threshold.
                local stackCount = EAS_DAB_StackNumbers029384(frame)
                local venomReady = EAS_DAB_IsVenomSkull029383(ability) and stackCount >= 2

                -- Detect ESO runtime ability-mode changes without hardcoded
                -- English proc names. This covers effective-id swaps and clients
                -- where only the live action-slot texture changes.
                local modeActive, boundId, effectiveId, liveTexture = EAS_DAB_GetLiveModeState029385(ability, slot, category)
                local modeKey = tostring(category) .. ":" .. tostring(slot) .. ":" .. tostring(boundId)
                local previousKey = frame.epcModeKey029385
                local wasModeActive = frame.epcModeActive029385 == true and previousKey == modeKey

                -- A newly slotted/replaced ability starts a new baseline and must
                -- not make a proc sound simply because its icon differs from the
                -- control that occupied this slot previously.
                if previousKey ~= nil and previousKey ~= modeKey then
                    wasModeActive = false
                    frame.epcModeActive029385 = false
                end

                if modeActive and not wasModeActive and previousKey == modeKey and category == activeCategory then
                    EAS_DAB_PlayProcCue029385()
                end
                frame.epcModeKey029385 = modeKey
                frame.epcModeActive029385 = modeActive
                frame.epcModeTexture029385 = liveTexture
                frame.epcModeEffectiveId029385 = effectiveId

                if glow and (venomReady or modeActive) then
                    glow:SetHidden(false)
                    local phase = (nowValue % 700) / 700
                    glow:SetAlpha(0.62 + 0.38 * math.abs(phase * 2 - 1))
                end

                -- Re-assert live usability after all older visual layers have run.
                -- Inactive rows retain their configured inactive-alpha treatment;
                -- only ESO's currently active bar is evaluated for target/resource
                -- usability so the back bar isn't permanently dimmed.
                if category == activeCategory and ordinal < #(self.slots or {}) then
                    local usable = true
                    if type(IsSlotUsable) == "function" then
                        usable = safe(IsSlotUsable, true, slot, category) ~= false
                    end
                    if frame.epcIcon and type(frame.epcIcon.SetAlpha) == "function" then
                        frame.epcIcon:SetAlpha(usable and 1.0 or 0.28)
                    end
                    if frame.epcShade and type(frame.epcShade.SetCenterColor) == "function" then
                        if usable then frame.epcShade:SetCenterColor(0, 0, 0, 0)
                        else frame.epcShade:SetCenterColor(0, 0, 0, 0.52) end
                    end
                end
            else
                frame.epcModeKey029385 = nil
                frame.epcModeActive029385 = false
            end
        end
    end

    return result
end


-- Absorbed passive action-bar correction layers

-- BEGIN ABSORBED: DualActionBarActiveIndicatorFix.lua
-- ESO Adventurer Suite
-- v0.29.651 - zero-heavy-work active weapon-bar indicator synchronization.
-- IMPORTANT: this file must never trigger a full Dual Action Bar refresh on a
-- normal weapon swap. GlobalWeaponSwapPerformanceFix.lua remains the sole owner
-- of expensive/structural weapon-swap work.

local EPC = ESOProgressionCoach
if not EPC or not EPC.DualActionBar or not EVENT_MANAGER then return end

local D = EPC.DualActionBar
local EM = EVENT_MANAGER
local NAME = (EPC.name or "ESOAdventurerSuite") .. "_ActiveBarIndicator029651"

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a
end

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function refreshIndicatorOnly()
    local bar = EPC and EPC.DualActionBar
    if not bar or not bar.rows then return end

    local activeCategory = safe(GetActiveHotbarCategory, nil)
    if activeCategory == nil then return end

    bar.lastActiveCategory029311 = activeCategory
    bar._easLiveActiveCategory029638 = activeCategory

    local inactiveAlpha = clamp(((tonumber(EPC.saved and EPC.saved.dualActionBarInactiveAlpha029189) or 45) / 100), 0.10, 1.0)
    local markerMode = type(bar.GetMarkerMode029191) == "function" and bar:GetMarkerMode029191() or "ICON_GLOW"

    for _, row in ipairs(bar.rows) do
        if row then
            local active = row.epcCategory == activeCategory

            if type(row.SetAlpha) == "function" then
                row:SetAlpha(active and 1.0 or inactiveAlpha)
            end

            -- Keep the weapon symbol synchronized without invoking any heavy bar
            -- refresh or ability/cooldown/stack work.
            if type(bar.RefreshMarker029191) == "function" then
                pcall(bar.RefreshMarker029191, bar, row, active)
            end

            -- Keep the marker's gold border/background on the same row as the
            -- active weapon symbol. This mirrors DualActionBar:RefreshRow but is
            -- intentionally visual-only.
            if row.marker and row.marker.SetCenterColor and row.marker.SetEdgeColor then
                if active then
                    if markerMode == "ICON_GLOW" then
                        row.marker:SetCenterColor(0.20, 0.14, 0.03, 0.20)
                        row.marker:SetEdgeColor(1.00, 0.74, 0.18, 0.72)
                    else
                        row.marker:SetCenterColor(0.05, 0.055, 0.08, 0.16)
                        row.marker:SetEdgeColor(0.86, 0.72, 0.30, 0.46)
                    end
                elseif markerMode == "NUMBER" then
                    row.marker:SetCenterColor(0.02, 0.025, 0.04, 0.88)
                    row.marker:SetEdgeColor(0.30, 0.32, 0.38, 0.90)
                else
                    row.marker:SetCenterColor(0, 0, 0, 0)
                    row.marker:SetEdgeColor(0, 0, 0, 0)
                end
            end

            if row.markerText and row.markerText.SetColor then
                if active then
                    row.markerText:SetColor(1.00, 0.86, 0.36, 1)
                else
                    row.markerText:SetColor(0.72, 0.74, 0.80, 1)
                end
            end

            -- The active row's individual ability cells also use a gold border.
            -- Flip those borders here so they cannot remain on the previously
            -- active weapon bar while the symbol has already moved.
            for _, frame in ipairs(row.slots or {}) do
                if frame and frame.epcBG and frame.epcBG.SetEdgeColor then
                    if active then
                        frame.epcBG:SetEdgeColor(0.38, 0.30, 0.12, 0.98)
                    else
                        frame.epcBG:SetEdgeColor(0.16, 0.18, 0.22, 0.90)
                    end
                end
            end
        end
    end
end

-- EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED is the settled hotbar notification.
-- Do visual-state work only: no zo_callLater chain, no static rebuild, no dynamic
-- refresh, no skill/cooldown/stack scan, and no duplicate pair-change listener.
if EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED ~= nil then
    EM:UnregisterForEvent(NAME, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED)
    EM:RegisterForEvent(NAME, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, refreshIndicatorOnly)
end

D.activeBarIndicatorFix029651Installed = true

-- END ABSORBED: DualActionBarActiveIndicatorFix.lua

-- BEGIN ABSORBED: DualActionBarCastPerformanceFix.lua
-- ESO Adventurer Suite
-- v0.29.646 - Dual Action Bar cast-time performance fix + swap-local hard guard.
-- EVENT_ACTION_SLOT_UPDATED can fire during ordinary ability use and in bursts
-- during weapon swaps. Static slot signatures are only scanned when no normal
-- weapon swap is settling, so this file remains safe even if another owner later
-- reinstalls its event handler.

local EPC = ESOProgressionCoach
if not EPC or not EPC.DualActionBar or not EVENT_MANAGER then return end

local D = EPC.DualActionBar
local EM = EVENT_MANAGER

local BASE_PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_DualActionBar029189"
local TRANSFORM_PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_TransformBar029554"
local PERF_PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_DualBarCastPerf029561"

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil then return fallback end
    return value
end

local function nowMs()
    if type(GetFrameTimeMilliseconds) == "function" then
        return tonumber(safe(GetFrameTimeMilliseconds, 0)) or 0
    end
    if type(GetGameTimeMilliseconds) == "function" then
        return tonumber(safe(GetGameTimeMilliseconds, 0)) or 0
    end
    return 0
end

local function weaponSwapBlocked()
    local stamp = nowMs()
    local untilMs = tonumber(EPC.weaponSwapBroadRefreshUntil029636)
        or tonumber(EPC.weaponSwapSettlingUntil029636)
        or tonumber(EPC.weaponSwapSettlingUntil029635)
        or 0
    return stamp > 0 and stamp < untilMs
end

local function slotSignature(slot, category)
    if slot == nil or category == nil then return "" end
    local bound = tonumber(safe(GetSlotBoundId, 0, slot, category)) or 0
    local used = safe(IsSlotUsed, false, slot, category) == true and 1 or 0
    local icon = tostring(safe(GetSlotTexture, "", slot, category) or "")
    return tostring(bound) .. ":" .. tostring(used) .. ":" .. icon
end

function D:CaptureStaticSlotSignatures029561()
    -- Never scan both bars inside ESO's weapon swap transition.
    if weaponSwapBlocked() and self.layoutMode ~= true then return false end

    self.staticSlotSignatures029561 = self.staticSlotSignatures029561 or {}
    local seen = {}
    for _, row in ipairs(self.rows or {}) do
        local category = row and row.epcCategory
        if category ~= nil and not seen[category] then
            seen[category] = true
            local categoryCache = self.staticSlotSignatures029561[category] or {}
            self.staticSlotSignatures029561[category] = categoryCache
            for _, slot in ipairs(self.slots or {}) do
                categoryCache[slot] = slotSignature(slot, category)
            end
        end
    end
    return true
end

function D:DidStaticSlotDataChange029561()
    -- This is the expensive part: two bars x six slots x several ESO API calls.
    -- A weapon swap never changes the configured slots, so there is nothing to
    -- detect here until the transition is over.
    if weaponSwapBlocked() and self.layoutMode ~= true then return false end

    self.staticSlotSignatures029561 = self.staticSlotSignatures029561 or {}
    local changed = false
    local seen = {}
    for _, row in ipairs(self.rows or {}) do
        local category = row and row.epcCategory
        if category ~= nil and not seen[category] then
            seen[category] = true
            local categoryCache = self.staticSlotSignatures029561[category] or {}
            self.staticSlotSignatures029561[category] = categoryCache
            for _, slot in ipairs(self.slots or {}) do
                local signature = slotSignature(slot, category)
                if categoryCache[slot] ~= signature then
                    categoryCache[slot] = signature
                    changed = true
                end
            end
        end
    end
    return changed
end

function D:ScheduleStaticRefresh029561()
    EM:UnregisterForUpdate(PERF_PREFIX .. "_Static")
    EM:RegisterForUpdate(PERF_PREFIX .. "_Static", 35, function()
        EM:UnregisterForUpdate(PERF_PREFIX .. "_Static")
        if not D or (D.layoutMode ~= true and weaponSwapBlocked()) then return end
        if type(D.InvalidateStyleCache029189) == "function" then D:InvalidateStyleCache029189() end
        if type(D.RefreshStatic029311) == "function" then D:RefreshStatic029311() end
        if type(D.CaptureStaticSlotSignatures029561) == "function" then D:CaptureStaticSlotSignatures029561() end
        if type(D.RefreshDynamic029311) == "function" then D:RefreshDynamic029311(false) end
    end)
end

local function installLightSlotHandler()
    if not rawget(_G, "EVENT_ACTION_SLOT_UPDATED") then return end

    -- Remove both previous heavy handlers. The transformation module still keeps
    -- its dedicated active-hotbar and weapon-pair events for actual form changes.
    EM:UnregisterForEvent(BASE_PREFIX .. "_Slot", EVENT_ACTION_SLOT_UPDATED)
    EM:UnregisterForEvent(TRANSFORM_PREFIX .. "_Slot", EVENT_ACTION_SLOT_UPDATED)
    EM:UnregisterForEvent(PERF_PREFIX .. "_Slot", EVENT_ACTION_SLOT_UPDATED)

    EM:RegisterForEvent(PERF_PREFIX .. "_Slot", EVENT_ACTION_SLOT_UPDATED, function()
        if not D or not EPC.saved or EPC.saved.showDualActionBar029189 ~= true then return end

        -- ESO emits a slot-event burst during Primary/Backup swapping. Never scan
        -- signatures or enter dynamic refresh from those events.
        if D.layoutMode ~= true and weaponSwapBlocked() then return end

        if D:DidStaticSlotDataChange029561() then
            -- Dragging/replacing/morphing a skill changed actual slot metadata.
            D:ScheduleStaticRefresh029561()
        elseif type(D.RefreshDynamic029311) == "function" then
            -- Ordinary cast/cooldown/effect update: no icon/style/hotkey rebuild.
            D:RefreshDynamic029311(false)
        end
    end)
end

-- TransformationFix registers its slot listener at file load, so remove it now.
if rawget(_G, "EVENT_ACTION_SLOT_UPDATED") then
    EM:UnregisterForEvent(TRANSFORM_PREFIX .. "_Slot", EVENT_ACTION_SLOT_UPDATED)
end

-- DualActionBar registers its legacy slot listener inside Initialize(). Wrap that
-- initializer so our lightweight handler becomes authoritative immediately after.
if type(D.Initialize) == "function" and not D._castPerfInitializeWrap029561 then
    local baseInitialize = InitializeImpl
    InitializeImpl = function(self, ...)
        local result = baseInitialize(self, ...)
        self:CaptureStaticSlotSignatures029561()
        installLightSlotHandler()
        return result
    end
    D._castPerfInitializeWrap029561 = true
end

-- Safe for reloads/late loads where the Dual Bar has already initialized.
if D.window then
    D:CaptureStaticSlotSignatures029561()
    installLightSlotHandler()
end

-- END ABSORBED: DualActionBarCastPerformanceFix.lua

-- BEGIN ABSORBED: GlobalWeaponSwapPerformanceFix.lua
-- ESO Adventurer Suite
-- v0.29.706 - authoritative shared weapon-swap suppression owner.
-- Normal Primary <-> Backup swaps only flip the already-rendered row alpha after
-- ESO settles. Core-wide refresh/snapshot work, ability models, slot signatures,
-- marker re-anchoring, and static bar rebuilds are excluded from the swap path.
-- Special/transformed hotbars retain one deferred structural refresh.

local EPC = ESOProgressionCoach
if not EPC or not EVENT_MANAGER then return end

local EM = EVENT_MANAGER
local NAME = (EPC.name or "ESOAdventurerSuite") .. "_WeaponSwapOwner029636"
local BASE_PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_DualActionBar029189"
local TRANSFORM_PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_TransformBar029554"
local SWAP_PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_DualBarSwapPerf029567"
local OLD_GLOBAL_PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_GlobalSwapPerf029568"
local OLD_OWNER_PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_WeaponSwapOwner029635"
local ABILITY_PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_AbilityOverlays"
local READY_PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_ReadyAlerts029365"
local ROTATION_PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_RotationAssistant"
local CAST_PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_DualBarCastPerf029561"

local SETTLE_MS = 260
-- ESO can continue emitting slot/effect/hotbar notifications well after the pair
-- event itself. Keep every heavy Suite action-bar system out until the transition
-- is fully over; active-row alpha still changes immediately.
local BROAD_SUPPRESS_MS = 1200
local APPLY_DELAY_MS = 40
local STRUCTURAL_DELAY_MS = 140
local SLOT_COALESCE_MS = 110
local BROAD_REFRESH_DELAY_MS = 180

local function nowMs()
    if type(GetFrameTimeMilliseconds) == "function" then
        return tonumber(GetFrameTimeMilliseconds()) or 0
    end
    if type(GetGameTimeMilliseconds) == "function" then
        return tonumber(GetGameTimeMilliseconds()) or 0
    end
    return 0
end

local function activeCategory()
    if type(GetActiveHotbarCategory) ~= "function" then return nil end
    local ok, value = pcall(GetActiveHotbarCategory)
    return ok and value or nil
end

local function normalCategories()
    local primary = rawget(_G, "HOTBAR_CATEGORY_PRIMARY")
    local backup = rawget(_G, "HOTBAR_CATEGORY_BACKUP")
    if primary == nil then primary = 0 end
    if backup == nil then backup = 1 end
    return primary, backup
end

local function isNormalCategory(category)
    local primary, backup = normalCategories()
    return category == primary or category == backup
end

local function swapSettling()
    local untilMs = tonumber(EPC.weaponSwapSettlingUntil029636)
        or tonumber(EPC.weaponSwapSettlingUntil029635) or 0
    local stamp = nowMs()
    return stamp > 0 and stamp < untilMs
end

local function broadRefreshSuppressed()
    local untilMs = tonumber(EPC.weaponSwapBroadRefreshUntil029636) or 0
    local stamp = nowMs()
    return stamp > 0 and stamp < untilMs
end

local function coreRegistration(eventCode)
    if eventCode == nil then return nil end
    return (EPC.name or "ESOAdventurerSuite") .. "_" .. tostring(eventCode)
end

local function removeEventNames(eventCode, names)
    if eventCode == nil then return end
    for i = 1, #names do
        EM:UnregisterForEvent(names[i], eventCode)
    end
end

local function removeLegacyListeners()
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED ~= nil then
        local coreName = coreRegistration(EVENT_ACTIVE_WEAPON_PAIR_CHANGED)
        local names = {
            BASE_PREFIX .. "_Bar",
            TRANSFORM_PREFIX .. "_Pair",
            SWAP_PREFIX .. "_Pair",
            OLD_GLOBAL_PREFIX .. "_Weapon",
            OLD_OWNER_PREFIX .. "_Pair",
            ABILITY_PREFIX .. "_Weapon",
            READY_PREFIX .. "_Weapon",
            ROTATION_PREFIX .. "_Bar",
        }
        if coreName then names[#names + 1] = coreName end
        removeEventNames(EVENT_ACTIVE_WEAPON_PAIR_CHANGED, names)
    end

    if EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED ~= nil then
        removeEventNames(EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, {
            TRANSFORM_PREFIX .. "_Hotbar",
            SWAP_PREFIX .. "_Hotbar",
            OLD_GLOBAL_PREFIX .. "_Hotbar",
            OLD_OWNER_PREFIX .. "_Hotbar",
            ABILITY_PREFIX .. "_Bar",
            READY_PREFIX .. "_Bar",
        })
    end

    if EVENT_ACTION_SLOT_UPDATED ~= nil then
        removeEventNames(EVENT_ACTION_SLOT_UPDATED, {
            BASE_PREFIX .. "_Slot",
            TRANSFORM_PREFIX .. "_Slot",
            CAST_PREFIX .. "_Slot",
            OLD_OWNER_PREFIX .. "_Slot",
            ABILITY_PREFIX .. "_Slot",
            ROTATION_PREFIX .. "_Slot",
        })
    end

    if EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED ~= nil then
        local coreName = coreRegistration(EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED)
        if coreName then EM:UnregisterForEvent(coreName, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED) end
        EM:UnregisterForEvent(OLD_OWNER_PREFIX .. "_AllHotbars", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED)
    end

    EM:UnregisterForUpdate(OLD_GLOBAL_PREFIX .. "_Ability")
    EM:UnregisterForUpdate(TRANSFORM_PREFIX .. "_Deferred")
    EM:UnregisterForUpdate(OLD_OWNER_PREFIX .. "_Apply")
    EM:UnregisterForUpdate(OLD_OWNER_PREFIX .. "_Structural")
    EM:UnregisterForUpdate(OLD_OWNER_PREFIX .. "_SlotCheck")
end

local function clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

local function applyNormalSwapVisuals(category)
    local D = EPC.DualActionBar
    if not D or not D.rows or category == nil then return end

    D.lastActiveCategory029311 = category
    D._lastSeenHotbar029554 = category
    D._lastLightSwapCategory029567 = category
    D._easLiveActiveCategory029638 = category

    local inactiveAlpha = clamp(
        ((tonumber(EPC.saved and EPC.saved.dualActionBarInactiveAlpha029189) or 45) / 100),
        0.10, 1.0)

    for _, row in ipairs(D.rows) do
        if row and type(row.SetAlpha) == "function" then
            row:SetAlpha(row.epcCategory == category and 1.0 or inactiveAlpha)
        end
    end
end

local function scheduleStructuralRefresh()
    EM:UnregisterForUpdate(NAME .. "_Structural")
    EM:RegisterForUpdate(NAME .. "_Structural", STRUCTURAL_DELAY_MS, function()
        EM:UnregisterForUpdate(NAME .. "_Structural")
        local D = EPC.DualActionBar
        if not D then return end

        if type(D.ApplyTransformedHotbarLayout029554) == "function" then
            pcall(D.ApplyTransformedHotbarLayout029554, D, true)
        end
        if type(D.InvalidateStyleCache029189) == "function" then
            pcall(D.InvalidateStyleCache029189, D)
        end
        if type(D.RefreshStatic029311) == "function" then
            pcall(D.RefreshStatic029311, D, true)
        end
        if type(D.CaptureStaticSlotSignatures029561) == "function" then
            pcall(D.CaptureStaticSlotSignatures029561, D)
        end

        local category = activeCategory()
        D.lastActiveCategory029311 = category
        D._lastSeenHotbar029554 = category
        D._lastLightSwapCategory029567 = category
        D._easLiveActiveCategory029638 = category

        if type(D.RefreshDynamic029311) == "function" then
            pcall(D.RefreshDynamic029311, D, true)
        end
    end)
end

local function processStableSwap()
    local D = EPC.DualActionBar
    if not D then return end

    local category = activeCategory()
    if category == nil then return end

    -- In single-bar mode the native ESO action bar owns the visual swap.
    -- Keep the global suppression window active, but do not touch hidden
    -- Dual Action Bar controls for ordinary Primary/Backup changes.
    if (not EPC.saved or EPC.saved.showDualActionBar029189 ~= true)
        and isNormalCategory(category) then
        return
    end

    local wasTransformed = D._transformed029554 == true
    local transformed = not isNormalCategory(category)
    if type(D.IsSingleTransformedHotbar029554) == "function" then
        local ok, value = pcall(D.IsSingleTransformedHotbar029554, D, category)
        if ok then transformed = value == true end
    end

    if isNormalCategory(category) and not transformed and not wasTransformed then
        applyNormalSwapVisuals(category)
        return
    end

    scheduleStructuralRefresh()
end

local function onSwapNotification()
    local stamp = nowMs()
    EPC.weaponSwapSettlingUntil029636 = stamp + SETTLE_MS
    EPC.weaponSwapSettlingUntil029635 = EPC.weaponSwapSettlingUntil029636
    EPC.weaponSwapBroadRefreshUntil029636 = stamp + BROAD_SUPPRESS_MS

    EM:UnregisterForUpdate(NAME .. "_BroadRefresh")
    EM:UnregisterForUpdate(NAME .. "_SlotCheck")

    -- Kill pending bar-local work that may have been queued just before the
    -- swap event. Those callbacks otherwise execute inside ESO's transition.
    EM:UnregisterForUpdate(CAST_PREFIX .. "_Static")
    EM:UnregisterForUpdate((EPC.name or "ESOAdventurerSuite") .. "_LiveAbilityState029638_Static")
    EM:UnregisterForUpdate(BASE_PREFIX .. "_DynamicRefresh")

    local D = EPC.DualActionBar
    if D then
        D.pendingDynamicRefresh029386 = false
        D.pendingDynamicRefreshForce029386 = false
    end

    EM:UnregisterForUpdate(NAME .. "_Apply")

    -- Single-bar normal swaps need the SAME broad suppression that makes the
    -- Dual Action Bar smooth, but they do not need any delayed Dual-Bar visual
    -- work. The lightweight single-bar icon handoff is owned separately.
    local category = activeCategory()
    if (not EPC.saved or EPC.saved.showDualActionBar029189 ~= true)
        and isNormalCategory(category) then
        return
    end

    EM:RegisterForUpdate(NAME .. "_Apply", APPLY_DELAY_MS, function()
        EM:UnregisterForUpdate(NAME .. "_Apply")
        processStableSwap()
    end)
end

local function onSlotNotification()
    -- Use the full 1.2s suppression window, not only the short pair-settle time.
    if broadRefreshSuppressed() or swapSettling() then return end

    EM:UnregisterForUpdate(NAME .. "_SlotCheck")
    EM:RegisterForUpdate(NAME .. "_SlotCheck", SLOT_COALESCE_MS, function()
        EM:UnregisterForUpdate(NAME .. "_SlotCheck")
        if broadRefreshSuppressed() or swapSettling() then return end

        local D = EPC.DualActionBar
        if not D then return end
        local changed = false
        if type(D.DidStaticSlotDataChange029561) == "function" then
            local ok, value = pcall(D.DidStaticSlotDataChange029561, D)
            changed = ok and value == true
        end

        if changed then
            if type(D.ScheduleStaticRefresh029561) == "function" then
                pcall(D.ScheduleStaticRefresh029561, D)
            elseif type(D.RefreshStatic029311) == "function" then
                pcall(D.RefreshStatic029311, D, true)
            end
        end
    end)
end

local function onAllHotbarsUpdated()
    if broadRefreshSuppressed() or swapSettling() then return end

    EM:UnregisterForUpdate(NAME .. "_BroadRefresh")
    EM:RegisterForUpdate(NAME .. "_BroadRefresh", BROAD_REFRESH_DELAY_MS, function()
        EM:UnregisterForUpdate(NAME .. "_BroadRefresh")
        if broadRefreshSuppressed() or swapSettling() then return end
        if type(EPC.RequestRefresh) == "function" then
            EPC:RequestRefresh("hotbars-updated")
        end
    end)
end

local function installSettlingGuards()
    local D = EPC.DualActionBar
    if D and type(D.RefreshDynamic029311) == "function"
        and not D._easSwapSettlingGuard029635 then
        D._easSwapSettlingGuard029635 = true
        local baseDynamic = RefreshDynamicImpl
        D.RefreshDynamic029311 = function(self, force, ...)
            if self.layoutMode ~= true and broadRefreshSuppressed() then return nil end
            return baseDynamic(self, force, ...)
        end
    end

    local A = EPC.AbilityOverlays
    if A and type(A.Refresh) == "function" and not A._easSwapSettlingGuard029635 then
        A._easSwapSettlingGuard029635 = true
        local baseRefresh = A.Refresh
        A.Refresh = function(self, ...)
            if self.layoutMode ~= true and broadRefreshSuppressed() then return nil end
            return baseRefresh(self, ...)
        end
    end

    local R = EPC.RotationAssistant
    if R and type(R.Refresh) == "function" and not R._easSwapSettlingGuard029635 then
        R._easSwapSettlingGuard029635 = true
        local baseRefresh = R.Refresh
        R.Refresh = function(self, ...)
            if self.layoutMode ~= true and broadRefreshSuppressed() then return nil end
            return baseRefresh(self, ...)
        end
    end
end

local function installOwnership()
    removeLegacyListeners()
    installSettlingGuards()

    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED ~= nil then
        EM:UnregisterForEvent(NAME .. "_Pair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED)
        EM:RegisterForEvent(NAME .. "_Pair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, onSwapNotification)
    end
    if EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED ~= nil then
        EM:UnregisterForEvent(NAME .. "_Hotbar", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED)
        EM:RegisterForEvent(NAME .. "_Hotbar", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, onSwapNotification)
    end
    if EVENT_ACTION_SLOT_UPDATED ~= nil then
        EM:UnregisterForEvent(NAME .. "_Slot", EVENT_ACTION_SLOT_UPDATED)
        EM:RegisterForEvent(NAME .. "_Slot", EVENT_ACTION_SLOT_UPDATED, onSlotNotification)
    end
    if EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED ~= nil then
        EM:UnregisterForEvent(NAME .. "_AllHotbars", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED)
        EM:RegisterForEvent(NAME .. "_AllHotbars", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, onAllHotbarsUpdated)
    end

    EPC.weaponSwapOwner029635 = true
    EPC.weaponSwapOwner029636 = true
end

if EVENT_PLAYER_ACTIVATED ~= nil then
    EM:RegisterForEvent(NAME .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
        installOwnership()
        if type(zo_callLater) == "function" then
            zo_callLater(installOwnership, 250)
            zo_callLater(installOwnership, 900)
        end
    end)
end

if EPC.DualActionBar and EPC.DualActionBar.window then
    installOwnership()
end

SLASH_COMMANDS = SLASH_COMMANDS or {}
SLASH_COMMANDS["/easswapperf"] = function()
    local category = activeCategory()
    local state = EPC.weaponSwapOwner029636 == true and "OWNED" or "WAITING"
    local text = string.format(
        "ESO Adventurer Suite weapon swap: %s | category=%s | settling=%s | broad=%s",
        state, tostring(category), swapSettling() and "yes" or "no",
        broadRefreshSuppressed() and "blocked" or "clear")
    if type(d) == "function" then d(text) end
end

-- END ABSORBED: GlobalWeaponSwapPerformanceFix.lua

-- BEGIN ABSORBED: SingleBarWeaponSwapLatencyFix.lua
-- ESO Adventurer Suite
-- v0.29.706 - single-bar visual handoff using the proven global swap owner.
-- IMPORTANT: Do not unregister the global weapon-swap performance owner here.
-- That owner is what keeps the Dual Action Bar smooth. Single-bar mode now uses
-- the same broad suppression window and performs only a six-icon visual handoff.

local EPC = ESOProgressionCoach
if not EPC or not EVENT_MANAGER then return end

local EM = EVENT_MANAGER
local BASE = EPC.name or "ESOAdventurerSuite"
local NAME = BASE .. "_SingleBarSwap029706"

local function singleBarMode()
    return not EPC.saved or EPC.saved.showDualActionBar029189 ~= true
end

local function activeCategory()
    if type(GetActiveHotbarCategory) ~= "function" then return nil end
    local ok, value = pcall(GetActiveHotbarCategory)
    return ok and value or nil
end

local function removeOldSingleBarRegistrations()
    local old = {
        BASE .. "_SingleBarSwap029699",
        BASE .. "_SingleBarSwap029700",
        BASE .. "_SingleBarSwap029701",
        BASE .. "_SingleBarSwap029702",
        BASE .. "_SingleBarSwap029703",
        BASE .. "_SingleBarSwap029704",
        BASE .. "_SingleBarQuiet029705",
    }

    for i = 1, #old do
        local prefix = old[i]
        if EVENT_ACTIVE_WEAPON_PAIR_CHANGED ~= nil then
            EM:UnregisterForEvent(prefix .. "_Pair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED)
        end
        if EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED ~= nil then
            EM:UnregisterForEvent(prefix .. "_Hotbar", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED)
        end
        if EVENT_ACTION_SLOT_UPDATED ~= nil then
            EM:UnregisterForEvent(prefix .. "_Slot", EVENT_ACTION_SLOT_UPDATED)
        end
        if EVENT_PLAYER_ACTIVATED ~= nil then
            EM:UnregisterForEvent(prefix .. "_Activated", EVENT_PLAYER_ACTIVATED)
        end
        EM:UnregisterForUpdate(prefix .. "_Apply")
    end
end

local function baseOverlayVisible(A)
    if not EPC.saved or EPC.saved.showAbilityOverlays == false then return false end
    if A and A.layoutMode == true then return true end
    if EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then return false end
    if EPC.OverlayModeAllows and EPC:OverlayModeAllows("abilityOverlayVisibility") == false then return false end
    return true
end

local function handoffIcons(category)
    if not singleBarMode() or category == nil then return end

    local A = EPC.AbilityOverlays
    if not A or type(A.widgets) ~= "table" then return end

    local allow = baseOverlayVisible(A)
    for _, widget in ipairs(A.widgets) do
        if widget then
            local slot = widget.epcSlot
            local used = false
            if allow and type(IsSlotUsed) == "function" then
                local ok, value = pcall(IsSlotUsed, slot, category)
                used = ok and value == true
            end

            local show = allow and used
            if widget.SetHidden then widget:SetHidden(not show) end

            if show and widget.epcIcon and type(GetSlotTexture) == "function" then
                local ok, texture = pcall(GetSlotTexture, slot, category)
                if ok and texture and texture ~= "" then
                    widget.epcIcon:SetTexture(texture)
                    if widget.epcIcon.SetHidden then widget.epcIcon:SetHidden(false) end
                elseif widget.epcIcon.SetHidden then
                    widget.epcIcon:SetHidden(true)
                end
            end
        end
    end
end

removeOldSingleBarRegistrations()

local lastCategory = nil

if EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED ~= nil then
    EM:UnregisterForEvent(NAME .. "_Hotbar", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED)
    EM:RegisterForEvent(NAME .. "_Hotbar", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, function()
        if not singleBarMode() then return end

        local category = activeCategory()
        if category == nil or category == lastCategory then return end
        lastCategory = category

        -- The global owner has already opened its broad no-heavy-work window.
        -- This callback does not call Refresh/RefreshWidget/Rotation/Ready-state
        -- code. It only hands the six visible icon textures to the settled bar.
        handoffIcons(category)
    end)
end

if EVENT_PLAYER_ACTIVATED ~= nil then
    EM:UnregisterForEvent(NAME .. "_Activated", EVENT_PLAYER_ACTIVATED)
    EM:RegisterForEvent(NAME .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
        removeOldSingleBarRegistrations()
        if not singleBarMode() then return end
        lastCategory = activeCategory()
        if lastCategory ~= nil then handoffIcons(lastCategory) end
    end)
end

EPC.singleBarWeaponSwapLatencyFix029706 = true

-- END ABSORBED: SingleBarWeaponSwapLatencyFix.lua


-- BEGIN ABSORBED: DualActionBarTransformationFix.lua
-- ESO Adventurer Suite
-- v0.29.646 - transformed/special hotbar support with normal-swap isolation.
-- Werewolf/temporary hotbars still get structural refreshes. Ordinary Primary
-- <-> Backup weapon swaps never use this structural path, even if its listeners
-- survive or are reinstalled later.

local EPC = ESOProgressionCoach
if not EPC or not EPC.DualActionBar then return end

local D = EPC.DualActionBar

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a
end

local function nowMs()
    if type(GetFrameTimeMilliseconds) == "function" then
        return tonumber(safe(GetFrameTimeMilliseconds, 0)) or 0
    end
    if type(GetGameTimeMilliseconds) == "function" then
        return tonumber(safe(GetGameTimeMilliseconds, 0)) or 0
    end
    return 0
end

local function activeCategory()
    return safe(GetActiveHotbarCategory, nil)
end

local function normalCategories()
    local primary = rawget(_G, "HOTBAR_CATEGORY_PRIMARY")
    local backup = rawget(_G, "HOTBAR_CATEGORY_BACKUP")
    if primary == nil then primary = 0 end
    if backup == nil then backup = 1 end
    return primary, backup
end

local function isWerewolfForm()
    local fn = rawget(_G, "IsWerewolf")
    if type(fn) == "function" then
        return safe(fn, false) == true
    end
    return false
end

local function normalWeaponSwapBlocked()
    local stamp = nowMs()
    local untilMs = tonumber(EPC.weaponSwapBroadRefreshUntil029636)
        or tonumber(EPC.weaponSwapSettlingUntil029636)
        or tonumber(EPC.weaponSwapSettlingUntil029635)
        or 0
    if stamp <= 0 or stamp >= untilMs then return false end

    local category = activeCategory()
    local primary, backup = normalCategories()
    if category ~= primary and category ~= backup then return false end
    if isWerewolfForm() then return false end
    return true
end

function D:IsSingleTransformedHotbar029554(category)
    category = category ~= nil and category or activeCategory()
    local primary, backup = normalCategories()

    if category ~= nil and category ~= primary and category ~= backup then
        return true
    end
    return isWerewolfForm()
end

function D:ApplyTransformedHotbarLayout029554(force)
    if not self.window or not self.rows or #self.rows < 2 then return false end

    -- Structural layout changes are never needed for ordinary weapon swapping.
    if self.layoutMode ~= true and normalWeaponSwapBlocked() and self._transformed029554 ~= true then
        return false
    end

    local category = activeCategory()
    local transformed = self:IsSingleTransformedHotbar029554(category)
    local row1, row2 = self.rows[1], self.rows[2]

    if transformed then
        if not self._transformed029554 or self._transformedCategory029554 ~= category or force == true then
            self._transformed029554 = true
            self._transformedCategory029554 = category
            self._normalRowCategories029554 = self._normalRowCategories029554 or {
                row1 and row1.epcCategory,
                row2 and row2.epcCategory,
            }
        end

        if row1 then
            row1.epcCategory = category
            row1.epcBarNumber = 1
            if row1.SetHidden then row1:SetHidden(false) end
            if row1.SetAlpha then row1:SetAlpha(1) end
        end
        if row2 and row2.SetHidden then row2:SetHidden(true) end

        local size = tonumber(EPC.saved and EPC.saved.dualActionBarIconSize029189) or 54
        size = math.max(42, math.min(78, size))
        local oneRowHeight = size + 8
        local currentWidth = self.window.GetWidth and self.window:GetWidth() or 0
        if self.window.SetDimensions and currentWidth and currentWidth > 0 then
            self.window:SetDimensions(currentWidth, oneRowHeight)
        elseif self.window.SetHeight then
            self.window:SetHeight(oneRowHeight)
        end
        return true
    end

    if self._transformed029554 then
        self._transformed029554 = false
        self._transformedCategory029554 = nil

        local order = type(self.GetBarOrder) == "function" and self:GetBarOrder() or nil
        if type(order) == "table" then
            for index, row in ipairs(self.rows) do
                local entry = order[index]
                if entry then
                    row.epcCategory = entry.category
                    row.epcBarNumber = entry.number
                end
                if row.SetHidden then row:SetHidden(false) end
            end
        else
            local primary, backup = normalCategories()
            if row1 then row1.epcCategory = primary row1.epcBarNumber = 1 if row1.SetHidden then row1:SetHidden(false) end end
            if row2 then row2.epcCategory = backup row2.epcBarNumber = 2 if row2.SetHidden then row2:SetHidden(false) end end
        end

        if type(self.ApplyDimensions) == "function" then self:ApplyDimensions(true) end
    end
    return false
end

if type(D.RefreshStatic029311) == "function" and not D._transformedStaticWrap029554 then
    local base = RefreshStaticImpl
    RefreshStaticImpl = function(self, ...)
        if self.layoutMode ~= true and normalWeaponSwapBlocked() and self._transformed029554 ~= true then
            return nil
        end
        self:ApplyTransformedHotbarLayout029554(false)
        local result = base(self, ...)
        self:ApplyTransformedHotbarLayout029554(false)
        return result
    end
    D._transformedStaticWrap029554 = true
end

if type(D.RefreshDynamic029311) == "function" and not D._transformedDynamicWrap029554 then
    local base = RefreshDynamicImpl
    RefreshDynamicImpl = function(self, force)
        if self.layoutMode ~= true and normalWeaponSwapBlocked() and self._transformed029554 ~= true then
            return nil
        end

        local category = activeCategory()
        local changed = category ~= self._lastSeenHotbar029554
        self._lastSeenHotbar029554 = category
        local wasTransformed = self._transformed029554 == true
        local isTransformed = self:IsSingleTransformedHotbar029554(category)

        if changed or wasTransformed ~= isTransformed then
            self:ApplyTransformedHotbarLayout029554(true)
            if type(self.RefreshStatic029311) == "function" then
                self:RefreshStatic029311(true)
            end
            force = true
        else
            self:ApplyTransformedHotbarLayout029554(false)
        end

        return base(self, force)
    end
    D._transformedDynamicWrap029554 = true
end

-- Event response is retained only for genuine transformed/special hotbar state.
-- Ordinary front/back swaps are explicitly ignored here, so this module cannot
-- become a swap hitch even if another file fails to unregister its listeners.
if EVENT_MANAGER then
    local prefix = (EPC.name or "ESOAdventurerSuite") .. "_TransformBar029554"
    local function refreshSoon()
        if not EVENT_MANAGER then return end
        if normalWeaponSwapBlocked() and D._transformed029554 ~= true then return end

        local category = activeCategory()
        local transformedNow = D:IsSingleTransformedHotbar029554(category)
        if not transformedNow and D._transformed029554 ~= true then return end

        EPC.Runtime:UnregisterUpdate("DualActionBarTransformation","Deferred")
        EPC.Runtime:RegisterUpdate("DualActionBarTransformation","Deferred",80, function()
            EPC.Runtime:UnregisterUpdate("DualActionBarTransformation","Deferred")
            if normalWeaponSwapBlocked() and D._transformed029554 ~= true then return end
            if D and D.RefreshStatic029311 then D:RefreshStatic029311(true) end
            if D and D.RefreshDynamic029311 then D:RefreshDynamic029311(true) end
        end)
    end

    if rawget(_G, "EVENT_ACTIVE_WEAPON_PAIR_CHANGED") then
        EPC.Runtime:RegisterEvent("DualActionBarTransformation","Pair",EVENT_ACTIVE_WEAPON_PAIR_CHANGED, refreshSoon)
    end
    if rawget(_G, "EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED") then
        EPC.Runtime:RegisterEvent("DualActionBarTransformation","Hotbar",EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, refreshSoon)
    end
    if rawget(_G, "EVENT_ACTION_SLOT_UPDATED") then
        EPC.Runtime:RegisterEvent("DualActionBarTransformation","Slot",EVENT_ACTION_SLOT_UPDATED, refreshSoon)
    end
end

if D.window then
    D:ApplyTransformedHotbarLayout029554(true)
    if D.RefreshStatic029311 then D:RefreshStatic029311(true) end
    if D.RefreshDynamic029311 then D:RefreshDynamic029311(true) end
end

-- END ABSORBED: DualActionBarTransformationFix.lua
