SetTracker = SetTracker or {}

local ST = SetTracker
local ADDON_NAME = "SetTracker"
local VERSION = "0.2.11-test13"
local MENU_PREVIEW_SECONDS = 6

local BAR_BOTH = 0
local BAR_FRONT = ACTIVE_WEAPON_PAIR_MAIN or 1
local BAR_BACK = ACTIVE_WEAPON_PAIR_BACKUP or 2

local WORN_SLOTS = {
    EQUIP_SLOT_HEAD,
    EQUIP_SLOT_CHEST,
    EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_HAND,
    EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET,
    EQUIP_SLOT_NECK,
    EQUIP_SLOT_RING1,
    EQUIP_SLOT_RING2,
    EQUIP_SLOT_MAIN_HAND,
    EQUIP_SLOT_OFF_HAND,
    EQUIP_SLOT_BACKUP_MAIN,
    EQUIP_SLOT_BACKUP_OFF,
}

local MAIN_WEAPON_SLOTS = {
    [EQUIP_SLOT_MAIN_HAND] = true,
    [EQUIP_SLOT_OFF_HAND] = true,
}

local BACKUP_WEAPON_SLOTS = {
    [EQUIP_SLOT_BACKUP_MAIN] = true,
    [EQUIP_SLOT_BACKUP_OFF] = true,
}

local DEFAULTS = {
    enabled = true,
    autoDetect = true,
    debug = false,
    hideInMenus = true,
    hideOutOfCombat = true,
    outOfCombatHideDelay = 3,
    sets = {},
}

ST.rows = {}
ST.detected = {}
ST.barSets = {
    [BAR_BOTH] = {},
    [BAR_FRONT] = {},
    [BAR_BACK] = {},
}
ST.effects = {}
ST.buffIcons = {}
ST.runtimeAbilityIds = {}
ST.ignoredSets = {}
ST.menuSections = {}
ST.nextDefaultPosition = 0
ST.activeBar = BAR_FRONT
ST.inCombat = false
ST.gameInCombat = false
ST.combatTransitionId = 0
ST.previewKey = nil
ST.previewUntil = 0

local function Lower(value)
    return zo_strlower(tostring(value or ""))
end

local function NormalizeDescription(description)
    local text = Lower(description)
    text = string.gsub(text, "|c%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "%-", " ")
    text = string.gsub(text, "–", " ")
    text = string.gsub(text, "—", " ")
    text = string.gsub(text, "%s+", " ")
    return text
end

local function TaggedMessage(message, force)
    if d and ST.sv and (force or ST.sv.debug) then
        d(string.format("[%s] %s", ADDON_NAME, tostring(message)))
    end
end

local function BarLabel(barPair)
    if barPair == BAR_FRONT then
        return "Front Bar"
    elseif barPair == BAR_BACK then
        return "Back Bar"
    end
    return "Both Bars"
end

local function SetKey(setId, barPair)
    return string.format("%d:%d", tonumber(setId) or 0, tonumber(barPair) or 0)
end

local function TableCount(tableValue)
    local count = 0
    for _ in pairs(tableValue or {}) do
        count = count + 1
    end
    return count
end

local function GetActiveBar()
    if GetActiveWeaponPairInfo then
        local pair = GetActiveWeaponPairInfo()
        if pair == BAR_FRONT or pair == BAR_BACK then
            return pair
        end
    end
    return BAR_FRONT
end

local function HighestRequiredBonus(itemLink, numberOfBonuses, maximumEquipped)
    local highest = 0
    local finalDescription = ""
    for bonusIndex = 1, tonumber(numberOfBonuses) or 0 do
        local numberRequired, bonusDescription, isPerfected = GetItemLinkSetBonusInfo(itemLink, true, bonusIndex)
        if not isPerfected and tonumber(numberRequired) and numberRequired > highest then
            highest = numberRequired
            finalDescription = bonusDescription or ""
        elseif not isPerfected and tonumber(numberRequired) and numberRequired == highest and bonusDescription then
            finalDescription = bonusDescription
        end
    end

    if highest == 0 then
        highest = tonumber(maximumEquipped) or 0
    end
    return highest, finalDescription
end

local function ExtractCooldownSeconds(description)
    local text = NormalizeDescription(description)

    local cooldownPatterns = {
        "every%s+([%d]+[%.%,]?[%d]*)%s*(seconds?)",
        "every%s+([%d]+[%.%,]?[%d]*)%s*(minutes?)",
        "once%s+per%s+([%d]+[%.%,]?[%d]*)%s*(seconds?)",
        "once%s+per%s+([%d]+[%.%,]?[%d]*)%s*(minutes?)",
    }
    for _, pattern in ipairs(cooldownPatterns) do
        local numberText, unit = string.match(text, pattern)
        local normalizedNumber = numberText and string.gsub(numberText, ",", ".") or nil
        local duration = tonumber(normalizedNumber)
        if duration and duration > 0 then
            if unit and string.find(unit, "minute", 1, true) then
                return duration * 60
            end
            return duration
        end
    end
    return nil
end

local function ExtractEffectDurationSeconds(description)
    local text = NormalizeDescription(description)

    local cooldownClause = string.find(text, "this effect can occur", 1, true)
    if cooldownClause then
        text = string.sub(text, 1, cooldownClause - 1)
    end

    local longest = 0
    local durationPatterns = {
        "for%s+([%d]+[%.%,]?[%d]*)%s*seconds?",
        "over%s+([%d]+[%.%,]?[%d]*)%s*seconds?",
        "lasts%s+([%d]+[%.%,]?[%d]*)%s*seconds?",
        "after%s+([%d]+[%.%,]?[%d]*)%s*seconds?",
    }
    for _, pattern in ipairs(durationPatterns) do
        for numberText in string.gmatch(text, pattern) do
            local normalizedNumber = string.gsub(numberText, ",", ".")
            local seconds = tonumber(normalizedNumber) or 0
            if seconds > longest then
                longest = seconds
            end
        end
    end
    if longest > 0 then
        return longest
    end
    return nil
end

local function ExtractMaxStacks(description)
    local text = NormalizeDescription(description)

    local patterns = {
        "stacks%s+up%s+to%s+(%d+)%s+times",
        "up%s+to%s+(%d+)%s+stacks",
        "maximum%s+of%s+(%d+)%s+stacks",
        "(%d+)%s+stacks%s+max",
    }
    for _, pattern in ipairs(patterns) do
        local maximum = tonumber(string.match(text, pattern))
        if maximum and maximum > 0 then
            return maximum
        end
    end
    return nil
end

local function IsChanceBasedDescription(description)
    local text = NormalizeDescription(description)

    local probabilityPhrases = {
        "chance to",
        "chance of",
        "chance for",
        "has a chance",
        "have a chance",
        "percent chance",
        "probability",
        "random chance",
        "randomly trigger",
        "randomly activate",
        "randomly proc",
        "random major buff",
        "random minor buff",
        "random major/minor buff",
        "random major or minor buff",
        "random minor or major buff",
        "randomly grant",
        "one of the random",
        "of the time",
    }
    for _, phrase in ipairs(probabilityPhrases) do
        if string.find(text, phrase, 1, true) then
            return true
        end
    end
    return string.match(text, "[%d]+[%.%,]?[%d]*%%%s*chance") ~= nil
end

local function HasPlayerControlledTrigger(description)
    local text = NormalizeDescription(description)

    local triggerPhrases = {
        "when you",
        "whenever you",
        "after you",
        "casting",
        "cast an ability",
        "activating",
        "activate a",
        "using an ability",
        "using a ",
        "use an ability",
        "drinking a potion",
        "drink a potion",
        "dealing damage",
        "dealing damage with",
        "deal damage",
        "you damage with",
        "bracing",
        "blocking",
        "bashing",
        "interrupting",
        "dodging",
        "applying a status effect",
        "apply a status effect",
        "when an ally activates your synergy",
        "completing a heavy attack",
        "fully charged heavy attack",
        "your heavy attack",
    }
    for _, phrase in ipairs(triggerPhrases) do
        if string.find(text, phrase, 1, true) then
            return true
        end
    end
    return false
end

local function GetTrackingMode(cooldownSeconds, maxStacks, effectDurationSeconds)
    local hasCooldown = cooldownSeconds ~= nil and cooldownSeconds > 0
    local hasStacks = maxStacks ~= nil and maxStacks > 0
    local hasDuration = effectDurationSeconds ~= nil and effectDurationSeconds > 0
    if hasCooldown and hasStacks then
        return "STACK_COOLDOWN"
    elseif hasStacks then
        return "STACK"
    elseif hasCooldown then
        return "COOLDOWN"
    elseif hasDuration then
        return "DURATION"
    end
    return nil
end

local function GetUserTriggerKind(description)
    local text = NormalizeDescription(description)
    if string.find(text, "heavy attack", 1, true) then
        return "HEAVY_ATTACK"
    elseif string.find(text, "drink", 1, true) and string.find(text, "potion", 1, true) then
        return "POTION"
    elseif string.find(text, "synergy", 1, true) then
        return "SYNERGY"
    elseif string.find(text, "bash", 1, true) then
        return "BASH"
    elseif string.find(text, "block", 1, true) or string.find(text, "bracing", 1, true) then
        return "BLOCK"
    elseif string.find(text, "dodg", 1, true) then
        return "DODGE"
    elseif string.find(text, "interrupt", 1, true) then
        return "INTERRUPT"
    elseif string.find(text, "status effect", 1, true) then
        return "STATUS"
    elseif string.find(text, "cast", 1, true) or string.find(text, "using a", 1, true) then
        return "ABILITY"
    elseif string.find(text, "damage", 1, true) then
        return "DAMAGE"
    end
    return "ACTION"
end

local function IsTrackableProcDescription(description, cooldownSeconds, maxStacks, effectDurationSeconds)
    local text = NormalizeDescription(description)
    if text == "" then
        return false, "UNCLASSIFIED", nil, "no final perk description"
    end
    if IsChanceBasedDescription(text) then
        return false, "RNJESUS", nil, "chance-based activation"
    end
    if not HasPlayerControlledTrigger(text) then
        return false, "UNCLASSIFIED", nil, "no player-controlled activation"
    end

    local trackingMode = GetTrackingMode(cooldownSeconds, maxStacks, effectDurationSeconds)
    if not trackingMode then
        return false, "USER", nil, "no cooldown, duration, or stack counter"
    end
    return true, "USER", trackingMode, nil
end

local function NormalizeName(value)
    return string.gsub(Lower(value), "[^%w]", "")
end

local function NamesMatch(left, right)
    local normalizedLeft = NormalizeName(left)
    local normalizedRight = NormalizeName(right)
    if normalizedLeft == "" or normalizedRight == "" then
        return false
    end
    return normalizedLeft == normalizedRight
        or string.find(normalizedLeft, normalizedRight, 1, true) ~= nil
        or string.find(normalizedRight, normalizedLeft, 1, true) ~= nil
end

local function AbilityAppearsInDescription(abilityName, description)
    local normalizedAbility = NormalizeName(abilityName)
    if string.len(normalizedAbility) < 5 then
        return false
    end
    return string.find(NormalizeName(description), normalizedAbility, 1, true) ~= nil
end

local function GetSlotSetData(slotIndex, equipped)
    local itemLink = GetItemLink(BAG_WORN, slotIndex, LINK_STYLE_DEFAULT)
    if not itemLink or itemLink == "" then
        return nil
    end

    local hasSet, setName, numberOfBonuses, numberEquipped, maximumEquipped, setId, numberPerfectedEquipped =
        GetItemLinkSetInfo(itemLink, equipped == true)
    if not hasSet or not setId or setId == 0 then
        return nil
    end

    return {
        itemLink = itemLink,
        name = setName,
        numberOfBonuses = numberOfBonuses,
        numberEquipped = tonumber(numberEquipped) or 0,
        numberPerfectedEquipped = tonumber(numberPerfectedEquipped) or 0,
        maximumEquipped = tonumber(maximumEquipped) or 0,
        setId = setId,
        icon = GetItemLinkIcon(itemLink),
        slotIndex = slotIndex,
    }
end

local function WeaponItemWeight(itemLink)
    if GetItemLinkEquipType and EQUIP_TYPE_TWO_HAND and GetItemLinkEquipType(itemLink) == EQUIP_TYPE_TWO_HAND then
        return 2
    end
    return 1
end

local function IsActiveWeaponSlot(slotIndex, activeBar)
    if activeBar == BAR_BACK then
        return BACKUP_WEAPON_SLOTS[slotIndex] == true
    end
    return MAIN_WEAPON_SLOTS[slotIndex] == true
end

local function EnsureSetConfig(entry)
    ST.sv.sets = ST.sv.sets or {}
    local config = ST.sv.sets[entry.key]
    if not config then
        local index = ST.nextDefaultPosition
        ST.nextDefaultPosition = index + 1
        config = {
            defaultIndex = index,
            enabled = true,
            x = -460 + ((index % 2) * 500),
            y = -300 + (math.floor(index / 2) * 78),
            scale = 100,
            cooldownSeconds = 30,
        }
        ST.sv.sets[entry.key] = config
    elseif config.defaultIndex == nil then
        config.defaultIndex = ST.nextDefaultPosition
        ST.nextDefaultPosition = ST.nextDefaultPosition + 1
    end
    return config
end

local function IsProwler(entry)
    return string.find(Lower(entry and entry.name), "prowler", 1, true) ~= nil
end

local function IsSergeant(entry)
    return string.find(Lower(entry and entry.name), "sergeant", 1, true) ~= nil
end

local function MenuIsOpen()
    if not ST.sv or not ST.sv.hideInMenus then
        return false
    end

    if SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene then
        local scene = SCENE_MANAGER:GetCurrentScene()
        local sceneName = scene and scene.GetName and scene:GetName()
        if sceneName and sceneName ~= "hud" and sceneName ~= "hudui" then
            return true
        end
    end

    if SCENE_MANAGER and SCENE_MANAGER.IsShowing then
        local showingHud = SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
        if not showingHud then
            return true
        end
    end
    return false
end

local function ApplyRowPosition(entry)
    local row = ST.rows[entry.key]
    if not row then
        return
    end
    local config = EnsureSetConfig(entry)
    local x, y, scale = config.x or 0, config.y or 0, (config.scale or 100) / 100
    if row.positionX == x and row.positionY == y and row.positionScale == scale then return end
    row.positionX, row.positionY, row.positionScale = x, y, scale
    row.window:ClearAnchors()
    row.window:SetAnchor(CENTER, GuiRoot, CENTER, config.x or 0, config.y or 0)
    row.window:SetScale((config.scale or 100) / 100)
end

local function CreateRow(entry)
    if ST.rows[entry.key] then
        return ST.rows[entry.key]
    end

    local safeKey = string.gsub(entry.key, "[^%w]", "_")
    local window = WINDOW_MANAGER:CreateTopLevelWindow("SetTrackerHud_" .. safeKey)
    window:SetDimensions(150, 56)
    window:SetClampedToScreen(true)
    window:SetMouseEnabled(false)
    window:SetDrawLayer(DL_OVERLAY)

    local backdrop = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetCenterColor(0.015, 0.02, 0.03, 0.72)
    backdrop:SetEdgeColor(0.18, 0.52, 0.72, 0.78)
    backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16, 2)

    local icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    icon:SetDimensions(48, 48)
    icon:SetAnchor(LEFT, window, LEFT, 4, 0)
    local initialConfig = EnsureSetConfig(entry)
    icon:SetTexture(initialConfig.buffIcon or entry.icon or "EsoUI/Art/Icons/icon_missing.dds")

    local status = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    status:SetFont("ZoFontGamepadBold34")
    status:SetColor(0.92, 0.72, 0.18, 1)
    status:SetAnchor(LEFT, icon, RIGHT, 7, 0)
    status:SetDimensions(88, 50)
    status:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    status:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    ST.rows[entry.key] = {
        window = window,
        icon = icon,
        status = status,
    }
    ApplyRowPosition(entry)
    return ST.rows[entry.key]
end

local ACTION_PROMPTS = {
            HEAVY_ATTACK = "HA",
            POTION = "POTION",
            SYNERGY = "SYNERGY",
            BASH = "BASH",
            BLOCK = "BLOCK",
            DODGE = "DODGE",
            INTERRUPT = "INT",
            STATUS = "APPLY",
            ABILITY = "CAST",
            DAMAGE = "HIT",
            ACTION = "APPLY",
        }

local function RefreshRow(entry, now)
    local row = CreateRow(entry)
    local config = EnsureSetConfig(entry)
    local menuOpen = MenuIsOpen()
    local previewing = menuOpen
        and ST.previewKey == entry.key
        and (ST.previewUntil or 0) > now
    local shouldShow = ST.sv.enabled
        and ((not menuOpen
            and config.enabled
            and (not ST.sv.hideOutOfCombat or ST.inCombat))
            or previewing)
    row.window:SetHidden(not shouldShow)
    if not shouldShow then
        return
    end

    ApplyRowPosition(entry)
    local effect = ST.effects[entry.key]
    local texture = config.buffIcon or ST.buffIcons[entry.key] or entry.icon or "EsoUI/Art/Icons/icon_missing.dds"
    if row.texture ~= texture then
        row.icon:SetTexture(texture)
        row.texture = texture
    end
    if effect and effect.endTime and effect.endTime > now then
        local remaining = effect.endTime - now
        if effect.isCooldown then
            row.status:SetText(tostring(math.max(1, math.ceil(remaining))))
        elseif entry.maxStacks then
            local stacks = math.max(0, tonumber(effect.stacks) or 0)
            if stacks >= entry.maxStacks then
                row.status:SetText("MAX")
            else
                row.status:SetText(tostring(stacks))
            end
        elseif (effect.stacks or 0) > 0 then
            row.status:SetText(tostring(effect.stacks))
        else
            row.status:SetText(tostring(math.max(1, math.ceil(remaining))))
        end
        if effect.isCooldown then
            row.status:SetColor(0.96, 0.20, 0.16, 1)
        else
            row.status:SetColor(0.25, 0.94, 0.38, 1)
        end
    elseif effect and effect.cooldownEnd and effect.cooldownEnd > now then
        row.status:SetText(tostring(math.max(1, math.ceil(effect.cooldownEnd - now))))
        row.status:SetColor(0.96, 0.20, 0.16, 1)
    elseif entry.maxStacks then
        row.status:SetText("0")
        row.status:SetColor(0.25, 0.94, 0.38, 1)
    elseif entry.trackingMode == "DURATION" then
        row.status:SetText(ACTION_PROMPTS[entry.triggerKind] or "APPLY")
        row.status:SetColor(0.92, 0.72, 0.18, 1)
    else
        row.status:SetText("READY")
        row.status:SetColor(0.92, 0.72, 0.18, 1)
    end
end

local function RefreshAllRows()
    local now = GetFrameTimeSeconds()
    if not MenuIsOpen() then
        ST.previewKey = nil
        ST.previewUntil = 0
    elseif ST.previewKey and (ST.previewUntil or 0) <= now then
        ST.previewKey = nil
    end
    for key, row in pairs(ST.rows) do
        local entry = ST.detected[key]
        if entry then
            RefreshRow(entry, now)
        else
            row.window:SetHidden(true)
        end
    end
end

local function PreviewSet(key)
    ST.previewKey = key
    ST.previewUntil = GetFrameTimeSeconds() + MENU_PREVIEW_SECONDS
    RefreshAllRows()
end

local function ResetSetPosition(entry)
    local config = EnsureSetConfig(entry)
    local index = config.defaultIndex or 0
    config.x = -460 + ((index % 2) * 500)
    config.y = -300 + (math.floor(index / 2) * 78)
    config.scale = 100
    ApplyRowPosition(entry)
end

local function AddSetMenu(entry)
    if not ST.settings or ST.menuSections[entry.key] then
        return
    end
    ST.menuSections[entry.key] = true
    local key = entry.key
    local sectionLabel = string.format("%s — %s", entry.name, BarLabel(entry.barPair))

    ST.settings:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = sectionLabel,
    })
    ST.settings:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Show this HUD",
        tooltip = "Show or hide this set without affecting any other detected set.",
        getFunction = function() return EnsureSetConfig(ST.detected[key] or entry).enabled end,
        setFunction = function(value)
            EnsureSetConfig(ST.detected[key] or entry).enabled = value
            RefreshAllRows()
        end,
        default = true,
    })
    ST.settings:AddSetting({
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Horizontal position",
        min = -900,
        max = 900,
        step = 10,
        getFunction = function() return EnsureSetConfig(ST.detected[key] or entry).x end,
        setFunction = function(value)
            EnsureSetConfig(ST.detected[key] or entry).x = value
            ApplyRowPosition(ST.detected[key] or entry)
            PreviewSet(key)
        end,
        default = 0,
    })
    ST.settings:AddSetting({
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Vertical position",
        min = -500,
        max = 500,
        step = 10,
        getFunction = function() return EnsureSetConfig(ST.detected[key] or entry).y end,
        setFunction = function(value)
            EnsureSetConfig(ST.detected[key] or entry).y = value
            ApplyRowPosition(ST.detected[key] or entry)
            PreviewSet(key)
        end,
        default = 0,
    })
    ST.settings:AddSetting({
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "HUD scale",
        min = 70,
        max = 140,
        step = 5,
        getFunction = function() return EnsureSetConfig(ST.detected[key] or entry).scale end,
        setFunction = function(value)
            EnsureSetConfig(ST.detected[key] or entry).scale = value
            ApplyRowPosition(ST.detected[key] or entry)
            PreviewSet(key)
        end,
        default = 100,
    })
    if IsProwler(entry) then
        ST.settings:AddSetting({
            type = LibHarvensAddonSettings.ST_SLIDER,
            label = "Prowler cooldown",
            tooltip = "Fallback cooldown used after the Prowler effect ends.",
            min = 5,
            max = 60,
            step = 1,
            getFunction = function() return EnsureSetConfig(ST.detected[key] or entry).cooldownSeconds end,
            setFunction = function(value) EnsureSetConfig(ST.detected[key] or entry).cooldownSeconds = value end,
            default = 30,
        })
    end
    ST.settings:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = "Reset this HUD position",
        buttonText = "Reset",
        clickHandler = function()
            ResetSetPosition(ST.detected[key] or entry)
            PreviewSet(key)
        end,
    })

end

local function BuildDetectedUnion()
    local oldDetected = ST.detected
    local newDetected = {}

    for key, entry in pairs(ST.barSets[BAR_BOTH] or {}) do
        newDetected[key] = entry
    end
    for key, entry in pairs(ST.barSets[BAR_FRONT] or {}) do
        newDetected[key] = entry
    end
    for backKey, backEntry in pairs(ST.barSets[BAR_BACK] or {}) do
        local frontKey = SetKey(backEntry.setId, BAR_FRONT)
        local frontEntry = (ST.barSets[BAR_FRONT] or {})[frontKey]
        if frontEntry then
            local sharedEntry = {}
            for field, value in pairs(frontEntry) do
                sharedEntry[field] = value
            end
            sharedEntry.key = frontKey
            sharedEntry.barPair = BAR_BOTH
            sharedEntry.sharedBars = true
            newDetected[frontKey] = sharedEntry

            local frontEffect = ST.effects[frontKey]
            local backEffect = ST.effects[backKey]
            if backEffect then
                local frontDeadline = frontEffect and math.max(tonumber(frontEffect.endTime) or 0, tonumber(frontEffect.cooldownEnd) or 0) or 0
                local backDeadline = math.max(tonumber(backEffect.endTime) or 0, tonumber(backEffect.cooldownEnd) or 0)
                local frontStacks = frontEffect and (tonumber(frontEffect.stacks) or 0) or 0
                local backStacks = tonumber(backEffect.stacks) or 0
                if not frontEffect or backDeadline > frontDeadline or (backDeadline == frontDeadline and backStacks > frontStacks) then
                    ST.effects[frontKey] = backEffect
                end
                ST.effects[backKey] = nil
            end

            if not ST.buffIcons[frontKey] and ST.buffIcons[backKey] then
                ST.buffIcons[frontKey] = ST.buffIcons[backKey]
            end
            local frontConfig = EnsureSetConfig(sharedEntry)
            local backConfig = ST.sv.sets and ST.sv.sets[backKey]
            if backConfig then
                frontConfig.buffIcon = frontConfig.buffIcon or backConfig.buffIcon
                frontConfig.procAbilityId = frontConfig.procAbilityId or backConfig.procAbilityId
            end
            for abilityId, mappedKey in pairs(ST.runtimeAbilityIds) do
                if mappedKey == backKey then
                    ST.runtimeAbilityIds[abilityId] = frontKey
                end
            end
        else
            newDetected[backKey] = backEntry
        end
    end
    ST.detected = newDetected

    for key, entry in pairs(newDetected) do
        EnsureSetConfig(entry)
        CreateRow(entry)
        AddSetMenu(entry)
        if not oldDetected[key] then
            if ST.sv and ST.sv.debug then TaggedMessage(string.format("Detected complete set [%s/%s]: %s (%d/%d, %s)", entry.filterType or "USER", entry.trackingMode or "NONE", entry.name, entry.equipped, entry.required, BarLabel(entry.barPair))) end
        end
    end
    for key, entry in pairs(oldDetected) do
        if not newDetected[key] then
            if ST.sv and ST.sv.debug then TaggedMessage(string.format("No longer complete: %s (%s)", entry.name, BarLabel(entry.barPair))) end
        end
    end
    RefreshAllRows()
end

local function ScanEquippedSets(reason)
    if not ST.sv or not ST.sv.autoDetect then
        return
    end

    local activeBar = GetActiveBar()
    ST.activeBar = activeBar
    local bySetId = {}
    local activeWeaponWeight = {}

    for _, slotIndex in ipairs(WORN_SLOTS) do
        local data = GetSlotSetData(slotIndex, true)
        if data then
            local entry = bySetId[data.setId]
            if not entry then
                local totalEquipped = math.min(data.numberEquipped + data.numberPerfectedEquipped, data.maximumEquipped)
                local required, finalDescription = HighestRequiredBonus(data.itemLink, data.numberOfBonuses, data.maximumEquipped)
                local cooldownSeconds = ExtractCooldownSeconds(finalDescription)
                local maxStacks = ExtractMaxStacks(finalDescription)
                local effectDurationSeconds = ExtractEffectDurationSeconds(finalDescription)
                local trackable, filterType, trackingMode, ignoredReason = IsTrackableProcDescription(finalDescription, cooldownSeconds, maxStacks, effectDurationSeconds)
                entry = {
                    setId = data.setId,
                    name = data.name,
                    normalizedName = NormalizeName(data.name),
                    normalizedDescription = NormalizeName(finalDescription),
                    icon = data.icon,
                    equipped = totalEquipped,
                    required = required,
                    finalDescription = finalDescription,
                    cooldownSeconds = cooldownSeconds,
                    procActivitySeconds = effectDurationSeconds,
                    effectDurationSeconds = effectDurationSeconds,
                    maxStacks = maxStacks,
                    trackable = trackable,
                    filterType = filterType,
                    trackingMode = trackingMode,
                    triggerKind = GetUserTriggerKind(finalDescription),
                    ignoredReason = ignoredReason,
                }
                bySetId[data.setId] = entry
            end

            if IsActiveWeaponSlot(slotIndex, activeBar) then
                activeWeaponWeight[data.setId] = (activeWeaponWeight[data.setId] or 0) + WeaponItemWeight(data.itemLink)
            end
        end
    end

    local newBarSets = {}
    local newBothSets = {}
    for setId, entry in pairs(bySetId) do
        if entry.required > 0 and entry.equipped >= entry.required and entry.trackable then
            local weaponWeight = activeWeaponWeight[setId] or 0
            if weaponWeight > 0 and (entry.equipped - weaponWeight) < entry.required then
                entry.barPair = activeBar
                entry.key = SetKey(setId, activeBar)
                newBarSets[entry.key] = entry
                ST.barSets[BAR_BOTH][SetKey(setId, BAR_BOTH)] = nil
            else
                entry.barPair = BAR_BOTH
                entry.key = SetKey(setId, BAR_BOTH)
                newBothSets[entry.key] = entry
                ST.barSets[BAR_FRONT][SetKey(setId, BAR_FRONT)] = nil
                ST.barSets[BAR_BACK][SetKey(setId, BAR_BACK)] = nil
            end
        elseif entry.required > 0 and entry.equipped >= entry.required and not ST.ignoredSets[setId] then
            ST.ignoredSets[setId] = true
            if ST.sv and ST.sv.debug then TaggedMessage(string.format("Ignored %s [%s/%s]: %s", entry.name, entry.filterType or "UNCLASSIFIED", entry.trackingMode or "NONE", entry.ignoredReason or "not a controllable cooldown or stack perk")) end
        end
    end

    ST.barSets[activeBar] = newBarSets
    ST.barSets[BAR_BOTH] = newBothSets
    BuildDetectedUnion()
    if ST.sv and ST.sv.debug then TaggedMessage(string.format("Scan complete (%s): %d complete set HUD(s)", tostring(reason or "manual"), TableCount(ST.detected))) end
end

local function EffectMatchesEntry(effectName, entry)
    local effectLower = Lower(effectName)
    local setLower = Lower(entry.name)
    if effectLower == "" then
        return false
    end
    if IsProwler(entry) then
        return string.find(effectLower, "prowler", 1, true) ~= nil
            or string.find(effectLower, "invisib", 1, true) ~= nil
    end
    if IsSergeant(entry) then
        return string.find(effectLower, "sergeant", 1, true) ~= nil
            or string.find(effectLower, "focus", 1, true) ~= nil
    end
    return string.find(effectLower, setLower, 1, true) ~= nil
        or string.find(setLower, effectLower, 1, true) ~= nil
end

local function LearnBuffIcon(entry, iconName)
    if not iconName or iconName == "" then
        return
    end

    ST.buffIcons[entry.key] = iconName
    local config = EnsureSetConfig(entry)
    if config.buffIcon ~= iconName then
        config.buffIcon = iconName
        if ST.sv and ST.sv.debug then TaggedMessage(string.format("Learned buff icon for %s from %s: %s", entry.name, BarLabel(entry.barPair), iconName)) end
    end
end

local function MatchEffectToEntries(effectName, abilityId, beginTime, endTime, stackCount, iconName)
    local matched = false
    for key, entry in pairs(ST.detected) do
        if (entry.barPair == BAR_BOTH or entry.barPair == ST.activeBar) and EffectMatchesEntry(effectName, entry) then
            local previous = ST.effects[key] or {}
            local effect = {
                name = effectName,
                beginTime = beginTime or GetFrameTimeSeconds(),
                endTime = endTime or 0,
                stacks = tonumber(stackCount) or 0,
                isCooldown = string.find(Lower(effectName), "cooldown", 1, true) ~= nil
                    or string.find(Lower(effectName), "cannot trigger", 1, true) ~= nil,
            }
            LearnBuffIcon(entry, iconName)
            if IsProwler(entry) and previous.endTime and previous.endTime > 0 and effect.endTime <= GetFrameTimeSeconds() then
                effect.cooldownEnd = GetFrameTimeSeconds() + (EnsureSetConfig(entry).cooldownSeconds or 30)
            else
                effect.cooldownEnd = previous.cooldownEnd
            end
            ST.effects[key] = effect
            if abilityId and abilityId > 0 then
                ST.runtimeAbilityIds[abilityId] = key
            end
            matched = true
            if ST.sv and ST.sv.debug then TaggedMessage(string.format("Effect matched %s: %s (%d)", entry.name, effectName, tonumber(abilityId) or 0)) end
        end
    end
    return matched
end

local function ScanPlayerEffects()
    local now = GetFrameTimeSeconds()
    local previousEffects = ST.effects
    ST.effects = {}
    for key, effect in pairs(previousEffects or {}) do
        if effect.cooldownEnd and effect.cooldownEnd > now then
            ST.effects[key] = effect
        end
    end
    for buffIndex = 1, GetNumBuffs("player") do
        local effectName, beginTime, endTime, _, stackCount, icon, _, _, _, _, abilityId = GetUnitBuffInfo("player", buffIndex)
        MatchEffectToEntries(effectName, abilityId, beginTime, endTime, stackCount, icon)
    end
    RefreshAllRows()
end

local function OnEffectChanged(_, changeType, _, effectName, unitTag, beginTime, endTime, stackCount, iconName, _, _, _, _, _, _, abilityId)
    if unitTag ~= "player" then
        return
    end

    local key = ST.runtimeAbilityIds[abilityId]
    if changeType == EFFECT_RESULT_FADED and key and ST.detected[key] then
        local entry = ST.detected[key]
        local previous = ST.effects[key] or {}
        local isProwlerInvisibility = IsProwler(entry)
            and string.find(Lower(effectName), "invisib", 1, true) ~= nil
        if isProwlerInvisibility then
            previous.cooldownEnd = GetFrameTimeSeconds() + (EnsureSetConfig(entry).cooldownSeconds or 30)
            previous.endTime = 0
            previous.stacks = 0
            ST.effects[key] = previous
            if ST.sv and ST.sv.debug then TaggedMessage(string.format("Prowler invisibility ended; cooldown started for %s", entry.name)) end
        elseif not IsProwler(entry) then
            ST.effects[key] = nil
        end
        if ST.sv and ST.sv.debug then TaggedMessage(string.format("Effect ended for %s: %s (%d)", entry.name, effectName, tonumber(abilityId) or 0)) end
    elseif changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        MatchEffectToEntries(effectName, abilityId, beginTime, endTime, stackCount, iconName)
    end
    RefreshAllRows()
end

local function OnCombatEvent(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
    if isError or not abilityName or abilityName == "" then
        return
    end

    local now = GetFrameTimeSeconds()
    local changed = false
    local normalizedAbility = NormalizeName(abilityName)
    for key, entry in pairs(ST.detected) do
        if entry.barPair == BAR_BOTH or entry.barPair == ST.activeBar then
            local config = EnsureSetConfig(entry)
            local learnedMatch = tonumber(config.procAbilityId) == tonumber(abilityId)
            local normalizedSet = entry.normalizedName or NormalizeName(entry.name)
            local nameMatch = normalizedAbility ~= "" and normalizedSet ~= "" and
                (string.find(normalizedAbility, normalizedSet, 1, true) ~= nil
                or string.find(normalizedSet, normalizedAbility, 1, true) ~= nil)
            local descriptionMatch = #normalizedAbility >= 5 and
                string.find(entry.normalizedDescription or NormalizeName(entry.finalDescription), normalizedAbility, 1, true) ~= nil
            local isEffectApplied = result == ACTION_RESULT_EFFECT_GAINED
                or result == ACTION_RESULT_EFFECT_GAINED_DURATION
            local isHeavyAttackHit = entry.triggerKind == "HEAVY_ATTACK"
                and abilityActionSlotType == ACTION_SLOT_TYPE_HEAVY_ATTACK
                and (tonumber(hitValue) or 0) > 0
            local durationTriggerMatch = entry.trackingMode == "DURATION"
                and descriptionMatch
                and (isEffectApplied or isHeavyAttackHit)

            if durationTriggerMatch then
                local effectDuration = entry.effectDurationSeconds or 0
                if effectDuration > 0 then
                    local effect = ST.effects[key] or {}
                    effect.name = abilityName
                    effect.beginTime = now
                    effect.endTime = now + effectDuration
                    effect.stacks = 0
                    effect.isCooldown = false
                    effect.cooldownEnd = nil
                    ST.effects[key] = effect
                    changed = true
                    if isEffectApplied then
                        config.procAbilityId = abilityId
                        local iconName = GetAbilityIcon and GetAbilityIcon(abilityId) or nil
                        LearnBuffIcon(entry, iconName)
                    end
                    if ST.sv and ST.sv.debug then TaggedMessage(string.format("Duration refreshed for %s: %s (%d), %.1fs", entry.name, abilityName, tonumber(abilityId) or 0, effectDuration)) end
                end
            elseif learnedMatch or nameMatch then
                local duration = entry.cooldownSeconds
                if not duration and GetAbilityCooldown and abilityId and abilityId > 0 then
                    local durationMs = GetAbilityCooldown(abilityId, "player")
                    if durationMs and durationMs > 0 then
                        duration = durationMs / 1000
                    end
                end

                local current = ST.effects[key]
                local cooldownRunning = current and current.cooldownEnd and current.cooldownEnd > now
                if duration and duration > 0 and not cooldownRunning then
                    config.procAbilityId = abilityId
                    local iconName = GetAbilityIcon and GetAbilityIcon(abilityId) or nil
                    LearnBuffIcon(entry, iconName)
                    changed = true
                    local activitySeconds = entry.procActivitySeconds or 0
                    local activityEnd = now + activitySeconds
                    ST.effects[key] = {
                        name = abilityName,
                        endTime = activitySeconds > 0 and activityEnd or 0,
                        stacks = 0,
                        isCooldown = false,
                        cooldownEnd = activityEnd + duration,
                    }
                    if ST.sv and ST.sv.debug then TaggedMessage(string.format("Proc learned for %s: %s (%d), %.1fs active then %.1fs cooldown", entry.name, abilityName, tonumber(abilityId) or 0, activitySeconds, duration)) end
                end
            end
        end
    end
    if changed then RefreshAllRows() end
end

local function QueueScan(reason)
    zo_callLater(function()
        ScanEquippedSets(reason)
        ScanPlayerEffects()
    end, 250)
end

local function OnInventorySlotUpdate(_, bagId)
    if bagId == BAG_WORN then
        QueueScan("equipment changed")
    end
end

local function OnWeaponPairChanged(_, activeWeaponPair)
    if activeWeaponPair == BAR_FRONT or activeWeaponPair == BAR_BACK then
        ST.activeBar = activeWeaponPair
    end
    QueueScan("weapon bar changed")
end

local function OnPlayerCombatState(_, inCombat)
    ST.gameInCombat = inCombat == true
    ST.combatTransitionId = ST.combatTransitionId + 1
    local transitionId = ST.combatTransitionId

    if ST.gameInCombat then
        ST.inCombat = true
        RefreshAllRows()
        return
    end

    local hideDelaySeconds = math.max(0, tonumber(ST.sv.outOfCombatHideDelay) or DEFAULTS.outOfCombatHideDelay)
    if hideDelaySeconds == 0 then
        ST.inCombat = false
        RefreshAllRows()
        TaggedMessage("Combat ended; HUD hidden immediately.")
        return
    end

    if ST.sv and ST.sv.debug then TaggedMessage(string.format("Combat ended; HUD hide delayed by %d second(s).", hideDelaySeconds)) end
    zo_callLater(function()
        if transitionId == ST.combatTransitionId and not ST.gameInCombat then
            ST.inCombat = false
            RefreshAllRows()
            TaggedMessage("Out-of-combat grace period ended; HUD hidden.")
        end
    end, hideDelaySeconds * 1000)
end

local function AddSettings()
    if not LibHarvensAddonSettings then
        TaggedMessage("LibHarvensAddonSettings is not installed; HUD tracking remains available.")
        return
    end

    local settings = LibHarvensAddonSettings:AddAddon(ADDON_NAME, {
        allowDefaults = true,
        allowRefresh = true,
        version = VERSION,
        website = "",
        defaultsFunction = function()
            ST.sv.enabled = DEFAULTS.enabled
            ST.sv.autoDetect = DEFAULTS.autoDetect
            ST.sv.debug = DEFAULTS.debug
            ST.sv.hideInMenus = DEFAULTS.hideInMenus
            ST.sv.hideOutOfCombat = DEFAULTS.hideOutOfCombat
            ST.sv.outOfCombatHideDelay = DEFAULTS.outOfCombatHideDelay
            for _, config in pairs(ST.sv.sets or {}) do
                local index = config.defaultIndex or 0
                config.enabled = true
                config.x = -460 + ((index % 2) * 500)
                config.y = -300 + (math.floor(index / 2) * 78)
                config.scale = 100
                config.cooldownSeconds = 30
            end
            RefreshAllRows()
        end,
    })
    ST.settings = settings

    settings:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Automatic set tracking",
    })
    settings:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Enable SetTracker",
        getFunction = function() return ST.sv.enabled end,
        setFunction = function(value)
            ST.sv.enabled = value
            RefreshAllRows()
        end,
        default = DEFAULTS.enabled,
    })
    settings:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Auto-detect equipped sets",
        tooltip = "Only sets with their final normal bonus active are added. This supports 1-piece mythics, 2-piece monster sets, and sets with other completion totals.",
        getFunction = function() return ST.sv.autoDetect end,
        setFunction = function(value)
            ST.sv.autoDetect = value
            if value then
                QueueScan("auto-detect enabled")
            end
        end,
        default = DEFAULTS.autoDetect,
    })
    settings:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Hide HUD while menus are open",
        tooltip = "Prevents tracker text showing through game and settings menus.",
        getFunction = function() return ST.sv.hideInMenus end,
        setFunction = function(value)
            ST.sv.hideInMenus = value
            RefreshAllRows()
        end,
        default = DEFAULTS.hideInMenus,
    })
    settings:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Hide HUD out of combat",
        tooltip = "Keeps normal exploration clean by showing set trackers only during combat. Menu position previews still appear.",
        getFunction = function() return ST.sv.hideOutOfCombat end,
        setFunction = function(value)
            ST.sv.hideOutOfCombat = value
            RefreshAllRows()
        end,
        default = DEFAULTS.hideOutOfCombat,
    })
    settings:AddSetting({
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Out-of-combat hide delay",
        tooltip = "Seconds to keep the HUD visible after combat ends. Set to 0 to hide immediately. This does not pause or change set timers.",
        min = 0,
        max = 30,
        step = 1,
        getFunction = function() return ST.sv.outOfCombatHideDelay end,
        setFunction = function(value)
            ST.sv.outOfCombatHideDelay = value
        end,
        default = DEFAULTS.outOfCombatHideDelay,
    })
    settings:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Debug chat output",
        tooltip = "Every message begins with [SetTracker] for accessibility-reader identification.",
        getFunction = function() return ST.sv.debug end,
        setFunction = function(value)
            ST.sv.debug = value
            if value then
                ST.ignoredSets = {}
            end
            TaggedMessage(value and "Debug output enabled." or "Debug output disabled.", true)
            if value then
                QueueScan("debug enabled")
            end
        end,
        default = DEFAULTS.debug,
    })
    settings:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = "Scan equipped sets now",
        buttonText = "Scan",
        clickHandler = function()
            ScanEquippedSets("LHAS manual scan")
            ScanPlayerEffects()
        end,
    })
    settings:AddSetting({
        type = LibHarvensAddonSettings.ST_LABEL,
        label = "|cFFD700Built on tea, toast and ADHD – tested live on PS5.|r\n"
            .. "|cB427D3Su|c546D6Aga|c889764Co|cDA34CDma|r\n"
            .. "|cAAAAAArik-sprint.co.uk/contact|r",
    })

    for _, entry in pairs(ST.detected) do
        AddSetMenu(entry)
    end
end

local function Initialize()
    ST.sv = ZO_SavedVars:NewAccountWide("SetTrackerSavedVariables", 2, nil, DEFAULTS)
    ST.sv.sets = ST.sv.sets or {}
    ST.activeBar = GetActiveBar()
    ST.inCombat = IsUnitInCombat and IsUnitInCombat("player") or false
    ST.gameInCombat = ST.inCombat

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotUpdate)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnWeaponPairChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_COMBAT_STATE, OnPlayerCombatState)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Combat", EVENT_COMBAT_EVENT, OnCombatEvent)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "Combat", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "HudUpdate", 100, RefreshAllRows)

    ScanEquippedSets("initial load")
    AddSettings()
    ScanPlayerEffects()
    if ST.sv and ST.sv.debug then TaggedMessage(string.format("Loaded version %s", VERSION)) end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
