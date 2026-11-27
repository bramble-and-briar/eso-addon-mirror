-- =========================================================
-- Companion Dashboard
-- Version 1.5.4
-- =========================================================

local ADDON_NAME = "CompanionDashboard"
local MOVEMENT_UPDATE = ADDON_NAME .. "Movement"

local Dashboard = {
    window = nil,
    visible = false,
    inCombat = false,
    debugCombat = false,
    combat = {
        damage = 0,
        healing = 0,
        firstEventMS = nil,
        lastEventMS = nil,
        matchedEvents = 0,
    },
}

-- Combat results supported by EVENT_COMBAT_EVENT.
-- Separate event registrations let ESO filter these results before Lua runs.
local DAMAGE_RESULTS = {
    ACTION_RESULT_DAMAGE,
    ACTION_RESULT_CRITICAL_DAMAGE,
    ACTION_RESULT_DOT_TICK,
    ACTION_RESULT_DOT_TICK_CRITICAL,
    ACTION_RESULT_BLOCKED_DAMAGE,
}

local HEAL_RESULTS = {
    ACTION_RESULT_HEAL,
    ACTION_RESULT_CRITICAL_HEAL,
    ACTION_RESULT_HOT_TICK,
    ACTION_RESULT_HOT_TICK_CRITICAL,
}

local DAMAGE_RESULT_LOOKUP = {}
local HEAL_RESULT_LOOKUP = {}

for _, result in ipairs(DAMAGE_RESULTS) do
    DAMAGE_RESULT_LOOKUP[result] = true
end

for _, result in ipairs(HEAL_RESULTS) do
    HEAL_RESULT_LOOKUP[result] = true
end

-- =========================================================
-- EQUIPMENT SLOT DEFINITIONS
-- =========================================================

local EQUIPMENT_SLOTS = {
    { EQUIP_SLOT_HEAD, "Head" },
    { EQUIP_SLOT_SHOULDERS, "Shoulders" },
    { EQUIP_SLOT_CHEST, "Chest" },
    { EQUIP_SLOT_HAND, "Hands" },
    { EQUIP_SLOT_WAIST, "Waist" },
    { EQUIP_SLOT_LEGS, "Legs" },
    { EQUIP_SLOT_FEET, "Feet" },
    { EQUIP_SLOT_NECK, "Neck" },
    { EQUIP_SLOT_RING1, "Ring 1" },
    { EQUIP_SLOT_RING2, "Ring 2" },
    { EQUIP_SLOT_MAIN_HAND, "Main Hand" },
    { EQUIP_SLOT_OFF_HAND, "Off Hand" },
}

-- Companion traits exist as separate armor, jewelry, and weapon trait types.
-- Map all three item categories to one summary entry per companion trait.
local COMPANION_TRAIT_NAMES = {
    "AGGRESSIVE",
    "AUGMENTED",
    "BOLSTERED",
    "FOCUSED",
    "PROLIFIC",
    "QUICKENED",
    "SHATTERING",
    "SOOTHING",
    "VIGOROUS",
}

local COMPANION_TRAIT_TYPES = {}

for _, traitName in ipairs(COMPANION_TRAIT_NAMES) do
    for _, itemCategory in ipairs({ "ARMOR", "JEWELRY", "WEAPON" }) do
        local traitType = _G["ITEM_TRAIT_TYPE_" .. itemCategory .. "_" .. traitName]
        if traitType then
            COMPANION_TRAIT_TYPES[traitType] = traitName
        end
    end
end

local COMPANION_TRAIT_ORDER = {
    "AGGRESSIVE", "AUGMENTED", "BOLSTERED", "FOCUSED", "PROLIFIC",
    "QUICKENED", "SHATTERING", "SOOTHING", "VIGOROUS",
}

local COMPANION_TRAIT_DISPLAY_NAMES = {
    AGGRESSIVE = "Aggressive",
    AUGMENTED = "Augmented",
    BOLSTERED = "Bolstered",
    FOCUSED = "Focused",
    PROLIFIC = "Prolific",
    QUICKENED = "Quickened",
    SHATTERING = "Shattering",
    SOOTHING = "Soothing",
    VIGOROUS = "Vigorous",
}

-- Get the numeric magnitude from ESO's own item-trait description. This
-- avoids hard-coding trait values by item quality and supports mixed-quality
-- gear. ESO descriptions commonly use commas for thousands; decimal commas
-- are also handled for clients using that number format.
local function GetTraitDescriptionValue(description)
    if not description then return nil, false end

    local numberText = description:match("([%d][%d%.,]*)")
    if not numberText then return nil, false end

    if numberText:find("%.") and numberText:find(",") then
        numberText = numberText:gsub(",", "")
    elseif numberText:find(",") then
        local trailingDigits = numberText:match(",(%d+)$")
        if trailingDigits and #trailingDigits == 3 then
            numberText = numberText:gsub(",", "")
        else
            numberText = numberText:gsub(",", ".")
        end
    end

    return tonumber(numberText), description:find("%%") ~= nil
end

-- =========================================================
-- LABEL CREATION
-- =========================================================

local function CreateLabel(parent, name, text, x, y, width, height)

    local label = WINDOW_MANAGER:CreateControl(
        name,
        parent,
        CT_LABEL
    )

    label:SetAnchor(
        TOPLEFT,
        parent,
        TOPLEFT,
        x,
        y
    )

    label:SetDimensions(width, height)
    if name == "CompanionDashboardName" then
	label:SetFont("ZoFontGameBold")
    else
	label:SetFont("ZoFontGame")
    end
    label:SetText(text)

    return label

end

-- =========================================================
-- EQUIPMENT
-- =========================================================

function Dashboard:RefreshEquipment()

    if not self.equipmentLabels then return end

    for i, slot in ipairs(EQUIPMENT_SLOTS) do

        local slotId = slot[1]
        local slotName = slot[2]

        local itemName = ""
        local armourType = ""

        if HasActiveCompanion() then

            itemName = GetItemName(
                BAG_COMPANION_WORN,
                slotId
            ) or ""

            local armour = GetItemArmorType(BAG_COMPANION_WORN, slotId)

	    if armour == ARMORTYPE_LIGHT then
    		armourType = "(L)"
	    elseif armour == ARMORTYPE_MEDIUM then
		armourType = "(M)"
	    elseif armour == ARMORTYPE_HEAVY then
		armourType = "(H)"
	end

        end

        local slotLabel = self.equipmentLabels[i].slot
        local itemLabel = self.equipmentLabels[i].item

        -- Slot name always uses default color
        slotLabel:SetText(slotName .. ":")
        slotLabel:SetColor(
            ZO_NORMAL_TEXT:UnpackRGBA()
        )

        if itemName ~= "" then

            local itemLink = GetItemLink(
                BAG_COMPANION_WORN,
                slotId
            )

            local cleanItemName = itemName:gsub(
                "Companion's ",
                ""
            )

            local labelColor = ZO_NORMAL_TEXT
            local traitName = ""

            if itemLink and itemLink ~= "" then

                -- Item quality color
                local quality = GetItemLinkQuality(itemLink)

                if quality then
                    labelColor = GetItemQualityColor(quality)
                end

                -- Item trait
                local traitType = GetItemLinkTraitType(itemLink)

                if traitType
                    and traitType ~= ITEM_TRAIT_TYPE_NONE then

                    traitName = GetString(
                        "SI_ITEMTRAITTYPE",
                        traitType
                    )

                end

            end

            -- Build item text
            local itemText = cleanItemName .. armourType

            if traitName ~= "" then

                itemText = itemText ..
                    " (" .. traitName .. ")"

            end

            -- Apply item quality color
            itemLabel:SetText(itemText)

            itemLabel:SetColor(
                labelColor:UnpackRGBA()
            )

        else

            -- Empty equipment slot
            itemLabel:SetText("Empty")

            itemLabel:SetColor(
                ZO_NORMAL_TEXT:UnpackRGBA()
            )

        end

    end

end

-- =========================================================
-- COMPANION TRAIT BONUS SUMMARY
-- =========================================================

function Dashboard:RefreshTraitBonuses()

    if not self.traitBonusLabels then return end

    local totals = {}

    if HasActiveCompanion() then
        for _, slot in ipairs(EQUIPMENT_SLOTS) do
            local itemLink = GetItemLink(BAG_COMPANION_WORN, slot[1])

            if itemLink and itemLink ~= "" then
                local traitType, traitDescription = GetItemLinkTraitInfo(itemLink)
                local traitKey = COMPANION_TRAIT_TYPES[traitType]

                if traitKey then
                    local value, isPercentage = GetTraitDescriptionValue(traitDescription)

                    if value then
                        if not totals[traitKey] then
                            totals[traitKey] = { value = 0, isPercentage = isPercentage }
                        end

                        totals[traitKey].value = totals[traitKey].value + value
                    end
                end
            end
        end
    end

    local visibleIndex = 0

    for _, traitKey in ipairs(COMPANION_TRAIT_ORDER) do
        local total = totals[traitKey]

        if total then
            visibleIndex = visibleIndex + 1
            local column = (visibleIndex - 1) % 2
            local row = math.floor((visibleIndex - 1) / 2)
            local label = self.traitBonusLabels[visibleIndex]

            if label then
                local valueText
                if total.isPercentage then
                    valueText = string.format("%.1f%%", total.value)
                else
                    valueText = string.format("%.0f", total.value)
                end

                label:ClearAnchors()
                label:SetAnchor(TOPLEFT, self.window, TOPLEFT,
                    15 + (column * 170), 410 + (row * 19))
                label:SetText(COMPANION_TRAIT_DISPLAY_NAMES[traitKey] .. ": +" .. valueText)
                label:SetHidden(false)
            end
        end
    end

    for i = visibleIndex + 1, #self.traitBonusLabels do
        self.traitBonusLabels[i]:SetText("")
        self.traitBonusLabels[i]:SetHidden(true)
    end

end

-- =========================================================
-- COMPANION SKILLS
-- =========================================================

function Dashboard:RefreshSkills()

    if not self.skillsLabels then return end

    local skillSlots = {
        ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1,
        ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 2,
        ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 3,
        ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 4,
        ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 5,
        ACTION_BAR_ULTIMATE_SLOT_INDEX + 1,
    }

    for i = 1, 6 do

        local slotIndex = skillSlots[i]
        local abilityId = 0
        local iconTexture = nil

        if HasActiveCompanion() then

            abilityId = GetSlotBoundId(
                slotIndex,
                HOTBAR_CATEGORY_COMPANION
            ) or 0

            if abilityId > 0 then
                iconTexture = GetAbilityIcon(abilityId)
            end

        end

        local controls = self.skillsLabels[i]

        -- Store ability ID directly on the hoverable frame and icon
	controls.frame.abilityId = abilityId
	controls.icon.abilityId = abilityId

        if iconTexture and iconTexture ~= "" then
            controls.icon:SetTexture(iconTexture)
            controls.icon:SetHidden(false)
        else
	    controls.icon:SetTexture("")
            controls.icon:SetHidden(true)
        end

        controls.label:SetText(
            i == 6 and "ULT" or tostring(i)
        )

    end

end

-- =========================================================
-- COMBAT TRACKING
-- =========================================================

function Dashboard:RefreshCombat()

    if not self.combatLabel then return end

    local combat = self.combat
    local elapsedMS = 0

    if combat.firstEventMS and combat.lastEventMS then
        elapsedMS = combat.lastEventMS - combat.firstEventMS
    end

    -- Avoid division by zero and show rates over the observed combat interval.
    local elapsedSeconds = math.max(elapsedMS / 1000, 1)
    local dps = combat.damage / elapsedSeconds
    local hps = combat.healing / elapsedSeconds
    local dtps = combat.damageTaken / elapsedSeconds

    if combat.matchedEvents > 0 then
        self.combatLabel:SetText(string.format(
            "DPS: %.1f    HPS: %.1f    DTPS: %.1f",
            dps,
            hps,
	    dtps
        ))
        self.totalTopLabel:SetText(string.format(
            "Damage: %d    Healing: %d",
            combat.damage,
            combat.healing
        ))
	self.totalBottomLabel:SetText(string.format(
            "Damage Taken: %d",
            combat.damageTaken
        ))
        self.combatStatusLabel:SetText(string.format(
            "Name-matched companion events: %d",
            combat.matchedEvents
        ))
    else
        self.combatLabel:SetText("DPS: --    HPS: --    DTPS: --")
        self.totalTopLabel:SetText(string.format(
            "Damage: %d    Healing: %d",
            combat.damage,
            combat.healing
        ))
	self.totalBottomLabel:SetText(string.format(
            "Damage Taken: %d",
            combat.damageTaken
        ))

        if not HasActiveCompanion() then
            self.combatStatusLabel:SetText("No active companion")
        elseif IsUnitGrouped("player") then
            self.combatStatusLabel:SetText(
                "Grouped: name-only attribution is disabled"
            )
        else
            self.combatStatusLabel:SetText(
                "Waiting for name-matched companion combat events"
            )
        end
    end

end

function Dashboard:ResetCombat()

    self.combat.damage = 0
    self.combat.healing = 0
    self.combat.damageTaken = 0
    self.combat.firstEventMS = nil
    self.combat.lastEventMS = nil
    self.combat.matchedEvents = 0

    self:RefreshCombat()

end

function Dashboard:OnCombatEvent(
    eventCode,
    result,
    isError,
    abilityName,
    abilityGraphic,
    abilityActionSlotType,
    sourceName,
    sourceType,
    targetName,
    targetType,
    hitValue,
    powerType,
    damageType,
    log,
    sourceUnitId,
    targetUnitId,
    abilityId,
    overflow
)

    if isError or not hitValue or hitValue <= 0 then return end

    local isDamage = DAMAGE_RESULT_LOOKUP[result]
    local isHealing = HEAL_RESULT_LOOKUP[result]

    if not isDamage and not isHealing then return end

    -- ESO's public UI API does not expose a function that returns the
    -- companion's unit ID. Some combat events also omit sourceName entirely.
    -- Therefore the only available best-effort check is an exact source-name
    -- match against the active companion. In grouped content, another player's
    -- companion can have the same name, so we deliberately do not attribute
    -- name-only matches while grouped.
    local companionName = ""

    if HasActiveCompanion() then
        companionName = zo_strformat("<<1>>", GetUnitName("companion") or "")
    end

    local normalizedSourceName = zo_strformat("<<1>>", sourceName or "")
    local normalizedTargetName = zo_strformat("<<1>>", targetName or "")

    if self.debugCombat then
        d(string.format(
            "[CompanionDashboard] result=%s ability=%s source=%s sourceType=%s sourceUnitId=%s target=%s value=%s",
            tostring(result),
            tostring(abilityName),
            tostring(sourceName),
            tostring(sourceType),
            tostring(sourceUnitId),
            tostring(targetName),
            tostring(hitValue)
        ))
    end

    if companionName == ""
        or normalizedSourceName == ""
        or IsUnitGrouped("player") then
        return
    end

    local combat = self.combat
    local now = GetGameTimeMilliseconds()

    -- Damage events targeting your companion
    if isDamage and normalizedTargetName == companionName then
	combat.damageTaken = combat.damageTaken + hitValue
    end

    -- Events sourced from your companion
    if normalizedSourceName ~= companionName then
        return
    end

    if not combat.firstEventMS then
        combat.firstEventMS = now
    end

    combat.lastEventMS = now
    combat.matchedEvents = combat.matchedEvents + 1

    if isDamage then
        combat.damage = combat.damage + hitValue
    elseif isHealing then
        combat.healing = combat.healing + hitValue
    end

    self:RefreshCombat()

end

function Dashboard:OnPlayerCombatState(inCombat)

    local wasInCombat = self.inCombat
    self.inCombat = inCombat

    -- Keep the completed encounter visible after combat ends.
    -- Clear the previous totals only when a new combat encounter begins.
    if inCombat and not wasInCombat then
        self:ResetCombat()
    end

end

function Dashboard:RegisterCombatEvents()

    local eventResults = {}

    for _, result in ipairs(DAMAGE_RESULTS) do
        eventResults[#eventResults + 1] = result
    end

    for _, result in ipairs(HEAL_RESULTS) do
        eventResults[#eventResults + 1] = result
    end

    for index, result in ipairs(eventResults) do

        local eventName = ADDON_NAME .. "CombatEvent" .. index

        EVENT_MANAGER:RegisterForEvent(
            eventName,
            EVENT_COMBAT_EVENT,
            function(...)
                self:OnCombatEvent(...)
            end
        )

        EVENT_MANAGER:AddFilterForEvent(
            eventName,
            EVENT_COMBAT_EVENT,
            REGISTER_FILTER_IS_ERROR,
            false,
            REGISTER_FILTER_COMBAT_RESULT,
            result
        )

    end

end


-- =========================================================
-- COMPANION INFORMATION
-- =========================================================

function Dashboard:Refresh()

    if not self.window then return end

    local companionName = "No active Companion"
    local companionLevel = ""
    local companionRapport = ""

    if HasActiveCompanion() then

        companionName = GetUnitName("companion")
            or "Companion"

	local level, curXp, totalXp, isMaxLevel = ZO_COMPANION_MANAGER:GetLevelInfo()

        if isMaxLevel then
            companionLevel = "Level " .. level
	elseif level and level > 0 then
	    companionLevel = string.format("Level %d: %d / %d XP", level, curXp, totalXp)
        end

	local curRap = GetActiveCompanionRapport()
	local curRapLevel = GetActiveCompanionRapportLevel()
	local curRapDesc = GetString("SI_COMPANIONRAPPORTLEVEL", curRapLevel)
	companionRapport = string.format("Rapport: %d (%s)", curRap, curRapDesc)

    end

    self.nameLabel:SetText(companionName)
    self.rappLabel:SetText(companionRapport)
    self.levelLabel:SetText(companionLevel)

    self:RefreshEquipment()
    self:RefreshTraitBonuses()
    self:RefreshSkills()

end

-- =========================================================
-- MOVEMENT DETECTION
-- =========================================================

function Dashboard:StopMovementCheck()

    EVENT_MANAGER:UnregisterForUpdate(
        MOVEMENT_UPDATE
    )

end

function Dashboard:StartMovementCheck()

    self:StopMovementCheck()

    EVENT_MANAGER:RegisterForUpdate(
        MOVEMENT_UPDATE,
        100,
        function()

            if not self.visible then

                self:StopMovementCheck()
                return

            end

            if IsPlayerMoving() then

                self:Hide()

            end

        end
    )

end

-- =========================================================
-- WINDOW VISIBILITY
-- =========================================================

function Dashboard:Hide()

    self.visible = false

    if self.window then

        self.window:SetHidden(true)

    end

    self:StopMovementCheck()

end

function Dashboard:Toggle()

    if not self.window then return end

    if self.visible then

        self:Hide()

    else

        self.visible = true

        self.window:SetHidden(false)

        self:Refresh()
        self:StartMovementCheck()

    end

end

-- =========================================================
-- CREATE DASHBOARD WINDOW
-- =========================================================

function Dashboard:CreateWindow()

    local wm = WINDOW_MANAGER

    local window = wm:CreateTopLevelWindow(
        "CompanionDashboardWindow"
    )

    window:SetDimensions(360, 745)

    window:SetAnchor(
        CENTER,
        GuiRoot,
        CENTER,
        0,
        0
    )

    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetClampedToScreen(true)
    window:SetHidden(true)

    -- Background
    local background = wm:CreateControl(
        nil,
        window,
        CT_BACKDROP
    )

    background:SetAnchorFill(window)

    background:SetCenterColor(
        0.08, 0.08, 0.10, 0.96
    )

    background:SetEdgeColor(
        0.65, 0.55, 0.30, 1
    )

    background:SetEdgeTexture(
        "EsoUI/Art/Tooltips/UI-Border.dds",
        8,
        2
    )

    -- =====================================================
    -- HEADER
    -- =====================================================

    local title = CreateLabel(
        window,
        "CompanionDashboardTitle",
        "COMPANION DASHBOARD",
        15, 12, 330, 25
    )

    title:SetFont("ZoFontWinH2")

    -- =====================================================
    -- COMPANION INFORMATION
    -- =====================================================

    self.nameLabel = CreateLabel(
        window,
        "CompanionDashboardName",
        "No active Companion",
        15, 45, 330, 25
    )

    self.rappLabel = CreateLabel(
        window,
        "CompanionDashboardRapport",
        "No active Companion",
        15, 65, 330, 25
    )

    self.levelLabel = CreateLabel(
        window,
        "CompanionDashboardLevel",
        "",
        15, 85, 330, 22
    )

    -- =====================================================
    -- EQUIPMENT
    -- =====================================================

    CreateLabel(
        window,
        "CompanionDashboardEquipment",
        "EQUIPMENT",
        15, 110, 330, 22
    )

    self.equipmentLabels = {}

    for i, slot in ipairs(EQUIPMENT_SLOTS) do

        local y = 135 + ((i - 1) * 20)

        -- Slot name
        local slotLabel = CreateLabel(
            window,
            "CompanionDashboardEquipmentSlot" .. i,
            slot[2] .. ":",
            15, y, 90, 20
        )

        slotLabel:SetColor(
            ZO_NORMAL_TEXT:UnpackRGBA()
        )

        -- Item name and trait
        local itemLabel = CreateLabel(
            window,
            "CompanionDashboardEquipmentItem" .. i,
            "Empty",
            105, y, 240, 20
        )

        itemLabel:SetColor(
            ZO_NORMAL_TEXT:UnpackRGBA()
        )

        self.equipmentLabels[i] = {
            slot = slotLabel,
            item = itemLabel
        }

    end

    -- =====================================================
    -- TRAIT BONUSES
    -- =====================================================

    CreateLabel(
        window,
        "CompanionDashboardTraitBonuses",
        "TRAIT BONUSES",
        15, 380, 330, 22
    )

    self.traitBonusLabels = {}

    for i = 1, 9 do
        local traitLabel = CreateLabel(
            window,
            "CompanionDashboardTraitBonus" .. i,
            "",
            15 + (((i - 1) % 2) * 170),
            410 + (math.floor((i - 1) / 2) * 19),
            165,
            19
        )
        traitLabel:SetHidden(true)
        self.traitBonusLabels[i] = traitLabel
    end

    -- =====================================================
    -- SKILLS
    -- =====================================================

CreateLabel(
    window,
    "CompanionDashboardSkills",
    "SKILLS",
    15, 510, 330, 22
)

self.skillsLabels = {}

for i = 1, 6 do

    local x = 18 + ((i - 1) * 55)

    -- Interactive skill button
    local button = wm:CreateControl(
        "CompanionDashboardSkillButton" .. i,
        window,
        CT_BUTTON
    )

    button:SetAnchor(
        TOPLEFT,
        window,
        TOPLEFT,
        x,
        540
    )

    button:SetDimensions(48, 48)
    button:SetMouseEnabled(true)

    -- Ability icon
    local icon = wm:CreateControl(
        nil,
        button,
        CT_TEXTURE
    )

    icon:SetAnchorFill(button)
    icon:SetDimensions(44, 44)
    icon:SetMouseEnabled(false)

    -- Ultimate gets a gold background
    if i == 6 then
        button:SetNormalTexture(
            "EsoUI/Art/ActionBar/actionBar_slot_bg.dds"
        )
    end

    -- Skill number / ultimate label
    local label = CreateLabel(
        window,
        "CompanionDashboardSkillLabel" .. i,
        i == 6 and "ULT" or tostring(i),
        x,
        590,
        48,
        18
    )

    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    if i == 6 then
        label:SetColor(0.85, 0.65, 0.25, 1)
    end

    -- Mouse diagnostics and tooltip
    button:SetHandler(
        "OnMouseEnter",
        function(control)

            local abilityId = control.abilityId

            if abilityId and abilityId > 0 then

                InitializeTooltip(
                    AbilityTooltip,
                    control,
                    RIGHT,
                    5,
                    0
                )

                AbilityTooltip:SetAbilityId(abilityId)

            end

        end
    )

    button:SetHandler(
        "OnMouseExit",
        function()
            ClearTooltip(AbilityTooltip)
        end
    )

    self.skillsLabels[i] = {
        frame = button,
        icon = icon,
        label = label,
        abilityId = 0,
    }

end

    -- =====================================================
    -- COMBAT STATISTICS
    -- =====================================================

    CreateLabel(
        window,
        "CompanionDashboardCombat",
        "COMBAT STATISTICS",
        15, 620, 330, 22
    )

    self.combatLabel = CreateLabel(
        window,
        "CompanionDashboardCombatInfo",
        "DPS: --    HPS: --    DTPS: --",
        15, 645, 330, 22
    )

    self.totalTopLabel = CreateLabel(
        window,
        "CompanionDashboardTotalTop",
        "Damage: 0    Healing: 0",
        15, 670, 330, 22
    )

    self.totalBottomLabel = CreateLabel(
        window,
        "CompanionDashboardTotalBottom",
        "Damage Taken: 0",
        15, 695, 330, 22
    )

    self.combatStatusLabel = CreateLabel(
        window,
        "CompanionDashboardCombatStatus",
        "Waiting for name-matched companion combat events",
        15, 720, 330, 22
    )

    self.window = window
    self:RefreshTraitBonuses()
    self:RefreshCombat()

end

-- =========================================================
-- ADD-ON INITIALIZATION
-- =========================================================

local function OnAddOnLoaded(eventCode, addonName)

    if addonName ~= ADDON_NAME then return end

    EVENT_MANAGER:UnregisterForEvent(
        ADDON_NAME,
        EVENT_ADD_ON_LOADED
    )

    -- Create dashboard
    Dashboard:ResetCombat()
    Dashboard:CreateWindow()

    -- Slash commands
    SLASH_COMMANDS["/cdash"] = function()

        Dashboard:Toggle()

    end

    SLASH_COMMANDS["/cd"] = function()

        Dashboard:Toggle()

    end

    SLASH_COMMANDS["/cdd"] = function()
        Dashboard.debugCombat = not Dashboard.debugCombat

        local state = Dashboard.debugCombat and "ON" or "OFF"
        d("CompanionDashboard combat diagnostics: " .. state)
    end

    -- Combat tracking
    Dashboard:RegisterCombatEvents()

    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME,
        EVENT_PLAYER_COMBAT_STATE,
        function(eventCode, inCombat)
            Dashboard:OnPlayerCombatState(inCombat)
        end
    )

    Dashboard.inCombat = IsUnitInCombat("player")

    -- Companion changes
    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME,
        EVENT_ACTIVE_COMPANION_STATE_CHANGED,
        function()

            Dashboard:Refresh()
            Dashboard:RefreshCombat()

        end
    )

    -- Inventory updates
    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME,
        EVENT_INVENTORY_FULL_UPDATE,
        function()

            Dashboard:RefreshEquipment()
            Dashboard:RefreshTraitBonuses()

        end
    )

    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME,
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function(eventCode, bagId)

            Dashboard:RefreshEquipment()
            Dashboard:RefreshTraitBonuses()

        end
    )

    EVENT_MANAGER:AddFilterForEvent(
        ADDON_NAME,
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID,
        BAG_COMPANION_WORN
    )

    -- Player activation
    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME,
        EVENT_PLAYER_ACTIVATED,
        function()

            Dashboard:Refresh()

        end
    )

    -- Companion skill bar updates
    ACTION_BAR_ASSIGNMENT_MANAGER:RegisterCallback(
        "SlotUpdated",
        function(hotbarCategory, slotId)

            if hotbarCategory == HOTBAR_CATEGORY_COMPANION then

                Dashboard:RefreshSkills()

            end

        end
    )

end

-- =========================================================
-- REGISTER ADD-ON
-- =========================================================

EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME,
    EVENT_ADD_ON_LOADED,
    OnAddOnLoaded
)
