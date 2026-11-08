--[[
    Group Ultimate Tracker v2.2.3
    Target: ESO Console / PlayStation 5
    Author: Daveemafiaa

    Five fixed unmorphed icon columns:
      1. Sorc      = Negate Magic family
      2. GIB       = Gibbering Shield family
      3. Corrosive = Magma Armor family
      4. Barrier   = Barrier family
      5. Dawnbreaker icon = catch-all for every other ultimate family,
                            including actual Dawnbreaker and its morphs.

    Each player has an independent PSN-labelled bar beneath every category
    represented by one of their two slotted ultimate abilities.

    Settings are registered in the console Settings > Add-ons page through
    LibHarvensAddonSettings. It does not require LibVotans or LibGamepadOptions.

    Ultimate data is supplied by LibGroupCombatStats. Group members must also
    run LibGroupCombatStats and a compatible addon registering {"ULT"}.
]]

local ADDON_NAME = "GroupUltimateReadyTracker"
local SAVED_VARIABLES_NAME = "GroupUltimateReadyTrackerSavedVariables"
local ADDON_VERSION = "2.2.3"

local MAX_GROUP_MEMBERS = 12
local MAX_BARS_PER_COLUMN = 12

local COLUMN_COUNT = 5
local COLUMN_WIDTH = 132
local COLUMN_GAP = 10
local WINDOW_WIDTH = (COLUMN_COUNT * COLUMN_WIDTH) + ((COLUMN_COUNT - 1) * COLUMN_GAP)

local ICON_FRAME_SIZE = 64
local ICON_SIZE = 58
local BAR_TOP = 72
local BAR_WIDTH = 128
local BAR_HEIGHT = 24
local BAR_GAP = 4
local BAR_STEP = BAR_HEIGHT + BAR_GAP
local MAX_WINDOW_HEIGHT = BAR_TOP + (MAX_BARS_PER_COLUMN * BAR_STEP) + 6

local MIN_SCALE = 0.70
local MAX_SCALE = 2.00
local MIN_X = -960
local MAX_X = 960
local MIN_Y = -540
local MAX_Y = 540

local DEFAULTS = {
    xOffset = 0,
    yOffset = 155,
    scale = 1.00,
    hiddenByUser = false,
    corrosiveIcon = "",
}

local COLORS = {
    frame = { 0.015, 0.015, 0.020, 1.00 },
    frameEdge = { 0.34, 0.36, 0.40, 1.00 },
    track = { 0.055, 0.060, 0.070, 0.98 },
    building = { 0.92, 0.42, 0.07, 1.00 },
    ready = { 0.05, 0.72, 0.20, 1.00 },
    noData = { 0.25, 0.27, 0.30, 1.00 },
    text = { 1.00, 1.00, 1.00, 1.00 },
}

-- Fixed unmorphed icon textures. These are the base-skill icons, not morph icons.
-- Keeping these paths static means all five icons are visible even when nobody
-- in the group currently has that ultimate slotted.
local CATEGORIES = {
    {
        key = "sorc",
        title = "Sorc",
        icon = "EsoUI/Art/Icons/ability_sorcerer_monsoon.dds",
    },
    {
        key = "gib",
        title = "GIB",
        icon = "EsoUI/Art/Icons/ability_arcanist_012_b.dds",
    },
    {
        key = "corrosive",
        title = "Corrosive",
        icon = "EsoUI/Art/Icons/ability_dragonknight_018.dds",
    },
    {
        key = "barrier",
        title = "Barrier",
        icon = "EsoUI/Art/Icons/ability_ava_006.dds",
    },
    {
        key = "other",
        title = "Dawnbreaker",
        icon = "EsoUI/Art/Icons/ability_fightersguild_005.dds",
    },
}

-- Classify by the actual slotted ability name. Morphs are mapped to their
-- unmorphed family icon. Anything outside the first four families is "other".
local ABILITY_FAMILY = {
    ["negate magic"] = "sorc",
    ["absorption field"] = "sorc",
    ["suppression field"] = "sorc",

    ["gibbering shield"] = "gib",
    ["gibbering shelter"] = "gib",
    ["sanctum of the abyssal sea"] = "gib",

    ["magma armor"] = "corrosive",
    ["corrosive armor"] = "corrosive",
    ["magma shell"] = "corrosive",

    ["barrier"] = "barrier",
    ["replenishing barrier"] = "barrier",
    ["reviving barrier"] = "barrier",
}

local GURT = {
    vars = nil,
    window = nil,
    columns = {},
    lgcs = nil,
    refreshQueued = false,
    settingsRegistered = false,
    settingsPanel = nil,
}

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c = pcall(fn, ...)
    if ok then
        return a, b, c
    end
    return nil
end

local function NormalizeName(name)
    if type(name) ~= "string" then
        return ""
    end
    name = string.lower(name)
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    name = string.gsub(name, "%s+", " ")
    return name
end

local function GetUnmorphedAbilityInfo(abilityId)
    abilityId = tonumber(abilityId) or 0
    if abilityId <= 0 then
        return nil, nil, nil
    end

    local hasProgression, progressionIndex = SafeCall(
        GetAbilityProgressionXPInfoFromAbilityId,
        abilityId
    )

    if not hasProgression or not progressionIndex then
        return nil, nil, nil
    end

    local baseAbilityId = SafeCall(
        GetAbilityProgressionAbilityId,
        progressionIndex,
        0,
        1
    )

    local baseName = nil
    local baseTexture = nil

    if tonumber(baseAbilityId) and tonumber(baseAbilityId) > 0 then
        baseName = SafeCall(GetAbilityName, baseAbilityId)
        baseTexture = SafeCall(GetAbilityIcon, baseAbilityId)
    end

    if (type(baseName) ~= "string" or baseName == "")
        or (type(baseTexture) ~= "string" or baseTexture == "") then
        local infoName, infoTexture = SafeCall(
            GetAbilityProgressionAbilityInfo,
            progressionIndex,
            0,
            1
        )
        if type(baseName) ~= "string" or baseName == "" then
            baseName = infoName
        end
        if type(baseTexture) ~= "string" or baseTexture == "" then
            baseTexture = infoTexture
        end
    end

    return baseName, baseTexture, baseAbilityId
end

local function ClassifyAbility(abilityId)
    abilityId = tonumber(abilityId) or 0
    if abilityId <= 0 then
        return nil
    end

    local abilityName = SafeCall(GetAbilityName, abilityId)
    local key = NormalizeName(abilityName)
    local category = ABILITY_FAMILY[key]

    -- Morphs are normalized through the real progression API, not just by
    -- localized display-name matching. This is particularly important for
    -- Corrosive Armor -> unmorphed Magma Armor.
    local baseName, baseTexture = GetUnmorphedAbilityInfo(abilityId)
    local baseKey = NormalizeName(baseName)

    if not category then
        category = ABILITY_FAMILY[baseKey]
    end

    if category then
        -- Refresh the icon from ESO's own ability data when this family is seen.
        -- The fixed texture in CATEGORIES remains the initial fallback.
        local column = GURT.columns[category]
        if column and type(baseTexture) == "string" and baseTexture ~= "" then
            column.icon:SetTexture(baseTexture)
            column.icon:SetHidden(false)
            if category == "corrosive" and GURT.vars then
                GURT.vars.corrosiveIcon = baseTexture
            end
        end
        return category, abilityName
    end

    -- Explicitly catch Dawnbreaker and every other non-listed ultimate.
    -- This is intentional: the Dawnbreaker icon is the catch-all column.
    return "other", abilityName
end

local function SetBackdropColor(control, color)
    control:SetCenterColor(color[1], color[2], color[3], color[4])
end

local function SetBackdropEdgeColor(control, color)
    if control and color then
        control:SetEdgeColor(color[1], color[2], color[3], color[4])
    end
end

local function ApplyAnchor()
    if not GURT.window or not GURT.vars then
        return
    end

    GURT.window:ClearAnchors()
    GURT.window:SetAnchor(
        TOP,
        GuiRoot,
        TOP,
        tonumber(GURT.vars.xOffset) or DEFAULTS.xOffset,
        tonumber(GURT.vars.yOffset) or DEFAULTS.yOffset
    )
    GURT.window:SetScale(tonumber(GURT.vars.scale) or DEFAULTS.scale)
end

local function CreateBar(column, rowIndex)
    local wm = WINDOW_MANAGER
    local rootName = "GURT_BarRoot_" .. column.key .. "_" .. rowIndex

    local barRoot = wm:CreateControl(rootName, column.root, CT_CONTROL)
    barRoot:SetDimensions(BAR_WIDTH, BAR_HEIGHT)
    barRoot:SetAnchor(
        TOPLEFT,
        column.root,
        TOPLEFT,
        math.floor((COLUMN_WIDTH - BAR_WIDTH) / 2),
        BAR_TOP + ((rowIndex - 1) * BAR_STEP)
    )
    barRoot:SetHidden(true)

    local track = wm:CreateControl(rootName .. "_Track", barRoot, CT_BACKDROP)
    track:SetDimensions(BAR_WIDTH, BAR_HEIGHT)
    track:SetAnchor(TOPLEFT, barRoot, TOPLEFT, 0, 0)
    SetBackdropColor(track, COLORS.track)

    local fill = wm:CreateControl(rootName .. "_Fill", track, CT_BACKDROP)
    fill:SetDimensions(1, BAR_HEIGHT)
    fill:SetAnchor(TOPLEFT, track, TOPLEFT, 0, 0)
    SetBackdropColor(fill, COLORS.building)
    fill:SetHidden(true)

    local label = wm:CreateControl(rootName .. "_Name", track, CT_LABEL)
    label:SetAnchor(TOPLEFT, track, TOPLEFT, 3, 0)
    label:SetAnchor(BOTTOMRIGHT, track, BOTTOMRIGHT, -3, 0)
    label:SetFont("$(BOLD_FONT)|16|soft-shadow-thin")
    label:SetColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], COLORS.text[4])
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetText("")

    return {
        root = barRoot,
        track = track,
        fill = fill,
        label = label,
    }
end

-- Resolve the real, unmorphed Magma Armor icon directly from the client's
-- skill catalogue, even before the group has a player with Corrosive slotted.
-- This avoids relying only on an unverified hard-coded .dds filename.
local function ResolveCorrosiveIconFromSkillData()
    if not SKILL_TYPE_CLASS then
        return nil
    end

    if type(GetSkillAbilityInfo) ~= "function" then return nil end

    local lines = tonumber(SafeCall(GetNumSkillLines, SKILL_TYPE_CLASS)) or 0
    for lineIndex = 1, math.min(lines, 30) do
        local abilities = tonumber(SafeCall(GetNumSkillAbilities, SKILL_TYPE_CLASS, lineIndex)) or 0
        for abilityIndex = 1, math.min(abilities, 30) do
            -- Capture all seven API return values. SafeCall only returns the
            -- first three, which would silently discard the ultimate flag.
            local ok, name, texture, _, _, isUltimate, _, progressionIndex = pcall(
                GetSkillAbilityInfo, SKILL_TYPE_CLASS, lineIndex, abilityIndex
            )
            local key = NormalizeName(name)
            if ok and isUltimate and (key == "magma armor" or key == "corrosive armor"
                or key == "magma shell") then
                -- Resolve morph 0, rank 1 to get the unmorphed Magma Armor art.
                local baseId = nil
                if type(progressionIndex) == "number" and progressionIndex > 0 then
                    baseId = SafeCall(GetAbilityProgressionAbilityId, progressionIndex, 0, 1)
                end
                if not baseId then
                    baseId = SafeCall(GetSpecificSkillAbilityInfo,
                        SKILL_TYPE_CLASS, lineIndex, abilityIndex, 0, 1)
                end
                local fromBase = nil
                if tonumber(baseId) and tonumber(baseId) > 0 then
                    fromBase = SafeCall(GetAbilityIcon, baseId)
                end
                if type(fromBase) == "string" and fromBase ~= "" then
                    return fromBase
                end
                if key == "magma armor" and type(texture) == "string" and texture ~= "" then
                    return texture
                end
            end
        end
    end
    return nil
end

-- Refresh only the third icon. No HUD layout, group-data, or bar modifications.
local function RefreshCorrosiveIcon()
    local column = GURT.columns.corrosive
    if not column then return end

    local texture = ResolveCorrosiveIconFromSkillData()
    if type(texture) == "string" and texture ~= "" then
        column.icon:SetTexture(texture)
        column.icon:SetHidden(false)
        if GURT.vars then GURT.vars.corrosiveIcon = texture end
    end
end

local function CreateColumn(index, definition)
    local wm = WINDOW_MANAGER
    local root = wm:CreateControl("GURT_Column_" .. definition.key, GURT.window, CT_CONTROL)
    root:SetDimensions(COLUMN_WIDTH, MAX_WINDOW_HEIGHT)
    root:SetAnchor(
        TOPLEFT,
        GURT.window,
        TOPLEFT,
        (index - 1) * (COLUMN_WIDTH + COLUMN_GAP),
        0
    )

    local frame = wm:CreateControl("GURT_IconFrame_" .. definition.key, root, CT_BACKDROP)
    frame:SetDimensions(ICON_FRAME_SIZE, ICON_FRAME_SIZE)
    frame:SetAnchor(TOP, root, TOP, 0, 0)
    frame:SetEdgeTexture("EsoUI/Art/Miscellaneous/Gamepad/gp_emptyFrame_1pixel.dds", 1, 1, 1)
    SetBackdropColor(frame, COLORS.frame)
    SetBackdropEdgeColor(frame, COLORS.frameEdge)

    local initialTexture = definition.icon
    if definition.key == "corrosive" then
        local skillTexture = ResolveCorrosiveIconFromSkillData()
        if type(skillTexture) == "string" and skillTexture ~= "" then
            initialTexture = skillTexture
            if GURT.vars then GURT.vars.corrosiveIcon = skillTexture end
        elseif GURT.vars
            and type(GURT.vars.corrosiveIcon) == "string"
            and GURT.vars.corrosiveIcon ~= "" then
            initialTexture = GURT.vars.corrosiveIcon
        end

        -- If a texture path is invalid or unavailable, the Corrosive box will
        -- still be clearly identifiable rather than completely blank. Once a
        -- valid Magma Armor texture appears it renders over this fallback.
        local fallbackName = wm:CreateControl("GURT_CorrosiveFallback", frame, CT_LABEL)
        fallbackName:SetDimensions(ICON_FRAME_SIZE, ICON_FRAME_SIZE)
        fallbackName:SetAnchor(CENTER, frame, CENTER, 0, 0)
        fallbackName:SetFont("$(BOLD_FONT)|12|soft-shadow-thin")
        fallbackName:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        fallbackName:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        fallbackName:SetColor(1.00, 0.52, 0.12, 1.00)
        fallbackName:SetText("MAGMA")
        fallbackName:SetDrawLayer(DL_BACKGROUND)
    end

    local icon = wm:CreateControl("GURT_Icon_" .. definition.key, frame, CT_TEXTURE)
    icon:SetDimensions(ICON_SIZE, ICON_SIZE)
    icon:SetAnchor(CENTER, frame, CENTER, 0, 0)
    icon:SetDrawLayer(DL_CONTROLS)
    icon:SetTexture(initialTexture)
    icon:SetHidden(false)

    local column = {
        key = definition.key,
        title = definition.title,
        root = root,
        frame = frame,
        icon = icon,
        bars = {},
    }

    for row = 1, MAX_BARS_PER_COLUMN do
        column.bars[row] = CreateBar(column, row)
    end

    GURT.columns[definition.key] = column
end

local function CreateUI()
    GURT.window = WINDOW_MANAGER:CreateTopLevelWindow("GURT_Window")
    GURT.window:SetDimensions(WINDOW_WIDTH, MAX_WINDOW_HEIGHT)
    GURT.window:SetDrawLayer(DL_OVERLAY)
    GURT.window:SetDrawTier(DT_HIGH)
    GURT.window:SetClampedToScreen(true)
    GURT.window:SetMouseEnabled(false)
    GURT.window:SetMovable(false)
    GURT.window:SetHidden(true)

    for index, definition in ipairs(CATEGORIES) do
        CreateColumn(index, definition)
    end

    ApplyAnchor()
end

-- Account/display names are the PSN-facing names supplied by the library.
-- Never fall back to stats.name: that is the character name, not the PSN ID.
local function GetPSNName(unitTag, stats)
    local isLocalPlayer = unitTag == "player" or (stats and stats.tag == "player")
    local displayName

    -- Resolve our own PSN/display name directly from the live player unit.
    -- For remote players, use the account displayName attached to that exact
    -- LibGroupCombatStats record. Never use stats.name (character name).
    if isLocalPlayer then
        displayName = SafeCall(GetUnitDisplayName, "player")
        if type(displayName) ~= "string" or displayName == "" then
            displayName = stats and stats.displayName
        end
        if type(displayName) ~= "string" or displayName == "" then
            displayName = SafeCall(GetDisplayName)
        end
    else
        displayName = stats and stats.displayName
        if type(displayName) ~= "string" or displayName == "" then
            local lookupTag = (stats and stats.tag) or unitTag
            displayName = SafeCall(GetUnitDisplayName, lookupTag)
        end
    end

    if type(displayName) ~= "string" or displayName == "" then
        -- Do not substitute a character name or another member's name.
        return "PSN unavailable"
    end

    if #displayName > 18 then
        displayName = string.sub(displayName, 1, 18)
    end

    return displayName
end

local function GetGroupStatsSnapshot()
    if not GURT.lgcs or type(GURT.lgcs.GetGroupStats) ~= "function" then
        return nil
    end

    local ok, snapshot = pcall(function()
        return GURT.lgcs:GetGroupStats()
    end)

    if ok and type(snapshot) == "table" then
        return snapshot
    end

    return nil
end

local function BuildOrderedMembers(groupStats)
    local members = {}
    local seenCharacterNames = {}
    local byCharacterName = {}
    local byTag = {}

    for unitTag, stats in pairs(groupStats) do
        if type(stats) == "table" then
            local canonicalTag = stats.tag or unitTag
            if type(stats.name) == "string" and stats.name ~= "" then
                byCharacterName[stats.name] = {
                    unitTag = canonicalTag,
                    stats = stats,
                }
            end
            byTag[canonicalTag] = {
                unitTag = canonicalTag,
                stats = stats,
            }
            byTag[unitTag] = {
                unitTag = canonicalTag,
                stats = stats,
            }
        end
    end

    -- First use ESO group order. The library keys data by unitTag and includes
    -- stats.name (character name) solely as a join key; it is never displayed.
    -- IMPORTANT: LibGroupCombatStats stats.isPlayer distinguishes OUR character
    -- (true) from remote group members (false). Never filter on isPlayer here:
    -- that was the cause of all teammate bars disappearing in v2.1.0.
    local groupSize = tonumber(GetGroupSize()) or 0
    for index = 1, math.min(groupSize, MAX_GROUP_MEMBERS) do
        local groupTag = SafeCall(GetGroupUnitTagByIndex, index)
        if groupTag then
            local characterName = SafeCall(GetUnitName, groupTag)
            local entry = characterName and byCharacterName[characterName] or byTag[groupTag]

            if entry and entry.stats then
                local uniqueKey = entry.stats.name or entry.unitTag
                if not seenCharacterNames[uniqueKey] then
                    seenCharacterNames[uniqueKey] = true
                    members[#members + 1] = entry
                end
            end
        end
    end

    -- The local player may be represented by "player" rather than a groupN tag.
    -- Append any library records not matched in the native group-order pass.
    local remaining = {}
    for _, entry in pairs(byTag) do
        local stats = entry.stats
        local uniqueKey = stats and (stats.name or entry.unitTag)
        if stats and not seenCharacterNames[uniqueKey] then
            seenCharacterNames[uniqueKey] = true
            remaining[#remaining + 1] = entry
        end
    end

    table.sort(remaining, function(a, b)
        local aName = GetPSNName(a.unitTag, a.stats)
        local bName = GetPSNName(b.unitTag, b.stats)
        return aName < bName
    end)

    for _, entry in ipairs(remaining) do
        if #members < MAX_GROUP_MEMBERS then
            members[#members + 1] = entry
        end
    end

    return members
end

local function MakeCandidate(name, ultValue, cost, ult, abilityId, category)
    local hasData = tonumber(ult._lastUpdated) ~= nil
        and tonumber(ult._lastUpdated) > 0
        and tonumber(ultValue) ~= nil
        and tonumber(cost) ~= nil
        and tonumber(cost) > 0

    local progress = 0
    if hasData then
        progress = math.max(0, math.min(1, tonumber(ultValue) / tonumber(cost)))
    end

    return {
        name = name,
        category = category,
        abilityId = abilityId,
        cost = tonumber(cost) or 0,
        progress = progress,
        hasData = hasData,
        -- Current ultimate points, not a percentage. Used only to rank the
        -- names within each fixed ultimate column (highest points first).
        ultPoints = hasData and (tonumber(ultValue) or 0) or 0,
    }
end

local function PutBestCandidate(bucket, candidate)
    local current = bucket[candidate.category]
    if not current or candidate.progress > current.progress then
        bucket[candidate.category] = candidate
    end
end

local function BuildMemberCandidates(entry)
    local stats = entry.stats
    local name = GetPSNName(entry.unitTag, stats)
    local ult = stats and stats.ult

    -- A player is part of the native group roster even before their
    -- broadcast packets arrive. Show a grey, unclassified name bar under
    -- the catch-all icon instead of silently hiding their name.
    if type(ult) ~= "table" then
        return {
            other = {
                name = name,
                category = "other",
                abilityId = 0,
                cost = 0,
                progress = 0,
                hasData = false,
                ultPoints = 0,
            },
        }
    end

    local ultValue = tonumber(ult.ultValue)
    local candidates = {}

    local slots = {
        {
            id = tonumber(ult.ult1ID) or 0,
            cost = tonumber(ult.ult1Cost) or 0,
        },
        {
            id = tonumber(ult.ult2ID) or 0,
            cost = tonumber(ult.ult2Cost) or 0,
        },
    }

    for _, slot in ipairs(slots) do
        if slot.id > 0 then
            local category = ClassifyAbility(slot.id)
            if category then
                local candidate = MakeCandidate(
                    name,
                    ultValue,
                    slot.cost,
                    ult,
                    slot.id,
                    category
                )
                PutBestCandidate(candidates, candidate)
            end
        end
    end

    if not next(candidates) then
        -- Unknown slot IDs mean "waiting for type data", NOT a confirmed
        -- Dawnbreaker. Keep the bar grey until a valid ultimate arrives.
        candidates.other = {
            name = name,
            category = "other",
            abilityId = 0,
            cost = 0,
            progress = 0,
            hasData = false,
            ultPoints = 0,
        }
    end

    return candidates
end

local function CollectGroupData()
    local grouped = {
        sorc = {},
        gib = {},
        corrosive = {},
        barrier = {},
        other = {},
    }

    local isGrouped = SafeCall(IsUnitGrouped, "player")
    local nativeGroupSize = tonumber(GetGroupSize()) or 0

    if isGrouped == false or nativeGroupSize < 2 then
        return grouped, 0
    end

    local snapshot = GetGroupStatsSnapshot()
    if not snapshot then
        return grouped, 0
    end

    -- Remote entries are deliberately INCLUDED, whether isPlayer is true
    -- (local player) or false (remote teammate).
    local members = BuildOrderedMembers(snapshot)

    for _, entry in ipairs(members) do
        local candidates = BuildMemberCandidates(entry)
        if candidates then
            for category, candidate in pairs(candidates) do
                local list = grouped[category]
                if #list < MAX_BARS_PER_COLUMN then
                    list[#list + 1] = candidate
                end
            end
        end
    end

    -- Display names below EACH icon are ranked independently by their
    -- CURRENT ultimate points. Players without a usable ULT packet go last.
    -- Use account name for a deterministic tie-breaker to avoid names
    -- jumping around when two players have identical ultimate values.
    for _, list in pairs(grouped) do
        table.sort(list, function(a, b)
            if a.hasData ~= b.hasData then
                return a.hasData == true
            end
            local pointsA = tonumber(a.ultPoints) or 0
            local pointsB = tonumber(b.ultPoints) or 0
            if pointsA ~= pointsB then
                return pointsA > pointsB
            end
            local nameA = NormalizeName(a.name)
            local nameB = NormalizeName(b.name)
            if nameA ~= nameB then
                return nameA < nameB
            end
            return (tonumber(a.abilityId) or 0) < (tonumber(b.abilityId) or 0)
        end)
    end

    return grouped, #members
end

local function UpdateBar(bar, candidate)
    local progress = candidate.hasData and candidate.progress or 0
    local fillWidth = math.floor(BAR_WIDTH * progress)

    if candidate.hasData then
        SetBackdropColor(bar.track, COLORS.track)
        if progress >= 1 then
            SetBackdropColor(bar.fill, COLORS.ready)
        else
            SetBackdropColor(bar.fill, COLORS.building)
        end
    else
        SetBackdropColor(bar.track, COLORS.noData)
        SetBackdropColor(bar.fill, COLORS.noData)
    end

    if fillWidth > 0 and candidate.hasData then
        bar.fill:SetDimensions(fillWidth, BAR_HEIGHT)
        bar.fill:SetHidden(false)
    else
        bar.fill:SetDimensions(1, BAR_HEIGHT)
        bar.fill:SetHidden(true)
    end

    local displayName = candidate.name or "PSN unavailable"
    local length = zo_strlen(displayName)
    if length >= 17 then
        bar.label:SetFont("$(BOLD_FONT)|14|soft-shadow-thin")
    elseif length >= 13 then
        bar.label:SetFont("$(BOLD_FONT)|15|soft-shadow-thin")
    else
        bar.label:SetFont("$(BOLD_FONT)|16|soft-shadow-thin")
    end

    bar.label:SetText(displayName)
    bar.root:SetHidden(false)
end

local function HideUnusedBars(column, usedCount)
    for index = usedCount + 1, MAX_BARS_PER_COLUMN do
        column.bars[index].root:SetHidden(true)
    end
end

local function Refresh()
    if not GURT.window or not GURT.vars then
        return
    end

    if GURT.vars.hiddenByUser then
        GURT.window:SetHidden(true)
        return
    end

    local isGrouped = SafeCall(IsUnitGrouped, "player")
    local nativeGroupSize = tonumber(GetGroupSize()) or 0

    if isGrouped == false or nativeGroupSize < 2 then
        GURT.window:SetHidden(true)
        for _, definition in ipairs(CATEGORIES) do
            HideUnusedBars(GURT.columns[definition.key], 0)
        end
        return
    end

    -- The five fixed icons stay visible even if group ULT data has not arrived.
    local grouped = {
        sorc = {},
        gib = {},
        corrosive = {},
        barrier = {},
        other = {},
    }

    if GURT.lgcs then
        grouped = CollectGroupData()
    end

    local maxRows = 0
    for _, definition in ipairs(CATEGORIES) do
        local column = GURT.columns[definition.key]
        local candidates = grouped[definition.key] or {}

        for index = 1, #candidates do
            UpdateBar(column.bars[index], candidates[index])
        end

        HideUnusedBars(column, #candidates)
        maxRows = math.max(maxRows, #candidates)
    end

    local height = BAR_TOP + (math.max(1, maxRows) * BAR_STEP) + 6
    GURT.window:SetDimensions(WINDOW_WIDTH, height)

    ApplyAnchor()
    GURT.window:SetHidden(false)
end

local function QueueRefresh()
    if GURT.refreshQueued then
        return
    end

    GURT.refreshQueued = true
    zo_callLater(function()
        GURT.refreshQueued = false
        Refresh()
    end, 125)
end

local function SetScale(value)
    local scale = tonumber(value)
    if not scale then
        return false
    end
    GURT.vars.scale = math.max(MIN_SCALE, math.min(MAX_SCALE, scale))
    ApplyAnchor()
    return true
end

local function SetHorizontal(value)
    local x = tonumber(value)
    if not x then
        return false
    end
    GURT.vars.xOffset = math.max(MIN_X, math.min(MAX_X, math.floor(x)))
    ApplyAnchor()
    return true
end

local function SetVertical(value)
    local y = tonumber(value)
    if not y then
        return false
    end
    GURT.vars.yOffset = math.max(MIN_Y, math.min(MAX_Y, math.floor(y)))
    ApplyAnchor()
    return true
end

local function ResetAllSettings()
    GURT.vars.scale = DEFAULTS.scale
    GURT.vars.xOffset = DEFAULTS.xOffset
    GURT.vars.yOffset = DEFAULTS.yOffset
    GURT.vars.hiddenByUser = false
    ApplyAnchor()
    QueueRefresh()
end

local function MoveBy(direction, amount)
    amount = math.max(1, math.min(500, math.abs(tonumber(amount) or 20)))

    if direction == "left" then
        SetHorizontal((tonumber(GURT.vars.xOffset) or 0) - amount)
    elseif direction == "right" then
        SetHorizontal((tonumber(GURT.vars.xOffset) or 0) + amount)
    elseif direction == "up" then
        SetVertical((tonumber(GURT.vars.yOffset) or DEFAULTS.yOffset) - amount)
    elseif direction == "down" then
        SetVertical((tonumber(GURT.vars.yOffset) or DEFAULTS.yOffset) + amount)
    end
end

local function DebugGroupData()
    if not GURT.lgcs then
        d("GURT: LibGroupCombatStats is not registered.")
        return
    end

    local nativeGroupSize = tonumber(SafeCall(GetGroupSize)) or 0
    local snapshot = GetGroupStatsSnapshot()
    local snapshotCount = 0
    if type(snapshot) == "table" then
        for _ in pairs(snapshot) do
            snapshotCount = snapshotCount + 1
        end
    end

    local sharing = SafeCall(GURT.lgcs.GetStatsShared, GURT.lgcs)
    local ultEnabled = type(sharing) == "table" and sharing.ULT == true

    d("GURT v" .. ADDON_VERSION .. " | group roster=" .. tostring(nativeGroupSize)
        .. " | library records=" .. tostring(snapshotCount)
        .. " | local ULT sharing=" .. tostring(ultEnabled))

    -- Walk ESO's ACTUAL native group roster instead of iterating only records
    -- with isPlayer=true. It is false for every REMOTE group member.
    for index = 1, math.min(nativeGroupSize, MAX_GROUP_MEMBERS) do
        local tag = SafeCall(GetGroupUnitTagByIndex, index)
        if tag then
            local name = SafeCall(GetUnitDisplayName, tag)
            if type(name) ~= "string" or name == "" then
                name = "PSN unavailable"
            end

            local stats = SafeCall(GURT.lgcs.GetUnitStats, GURT.lgcs, tag)
            if type(stats) ~= "table" then
                d(tostring(index) .. ". " .. name .. " | library record missing")
            else
                local ult = stats.ult or {}
                local front = tonumber(ult.ult1ID) or 0
                local back = tonumber(ult.ult2ID) or 0
                local stamp = tonumber(ult._lastUpdated) or 0
                local remote = stats.isPlayer == false and "remote" or "local"

                d(tostring(index) .. ". " .. name
                    .. " (" .. remote .. ")"
                    .. " | front=" .. tostring(front)
                    .. " | back=" .. tostring(back)
                    .. " | ult=" .. tostring(ult.ultValue or 0)
                    .. " | updated=" .. tostring(stamp))
            end
        end
    end

    d("GURT: If a teammate is listed with front=0 back=0,")
    d("their PSN can display, but no ultimate type has reached this client.")
end

local function HandleSlashCommand(args)
    local command, value = string.match(args or "", "^(%S+)%s*(.-)$")
    command = string.lower(command or "help")

    if command == "scale" then
        if SetScale(value) then
            d("GURT: scale = " .. tostring(GURT.vars.scale))
        else
            d("Usage: /gurt scale 0.70-2.00")
        end
    elseif command == "x" or command == "horizontal" then
        if SetHorizontal(value) then
            d("GURT: horizontal X = " .. tostring(GURT.vars.xOffset))
        else
            d("Usage: /gurt x <pixels>")
        end
    elseif command == "y" or command == "vertical" then
        if SetVertical(value) then
            d("GURT: vertical Y = " .. tostring(GURT.vars.yOffset))
        else
            d("Usage: /gurt y <pixels>")
        end
    elseif command == "left" or command == "right" or command == "up" or command == "down" then
        MoveBy(command, value)
    elseif command == "move" then
        local x, y = string.match(value or "", "^%s*(-?%d+%.?%d*)%s+(-?%d+%.?%d*)%s*$")
        if x and y then
            SetHorizontal(x)
            SetVertical(y)
        else
            d("Usage: /gurt move <X> <Y>")
        end
    elseif command == "reset" then
        ResetAllSettings()
        d("GURT: position and scale reset.")
    elseif command == "hide" then
        GURT.vars.hiddenByUser = true
        GURT.window:SetHidden(true)
        d("GURT: HUD hidden. Use /gurt show.")
    elseif command == "show" then
        GURT.vars.hiddenByUser = false
        QueueRefresh()
        d("GURT: HUD will show while grouped.")
    elseif command == "debug" then
        DebugGroupData()
    elseif command == "settings" or command == "help" then
        d("GURT: Open Settings > Options > Add-ons > Group Ultimate Tracker.")
        d("/gurt scale 1.20 | /gurt x -100 | /gurt y 180")
        d("/gurt move -100 180 | /gurt left|right|up|down [pixels]")
        d("/gurt reset | hide | show | debug")
    else
        d("GURT: Unknown command. Type /gurt settings.")
    end
end

-- Console settings are registered through LibHarvensAddonSettings.
-- This is the supported Settings > Add-ons integration for gamepad/console.
-- It is declared with ## ConsoleDependsOn in the addon manifest.
local function RegisterSettingsPanel()
    if GURT.settingsRegistered then
        return true
    end

    local library = LibHarvensAddonSettings
    if not library or type(library.AddAddon) ~= "function" then
        d("GURT: LibHarvensAddonSettings is missing. Check that the console dependency is installed and enabled.")
        return false
    end

    local panel = library:AddAddon("Group Ultimate Tracker", {
        allowDefaults = true,
        allowRefresh = true,
        defaultsFunction = function()
            ResetAllSettings()
        end,
    })

    if not panel or type(panel.AddSetting) ~= "function" then
        d("GURT: LibHarvensAddonSettings did not create the settings panel.")
        return false
    end

    panel:AddSetting({
        type = library.ST_SECTION,
        label = "HUD Position and Scale",
    })

    panel:AddSetting({
        type = library.ST_SLIDER,
        label = "HUD Scale",
        tooltip = "Adjust the size of the five-column ultimate tracker.",
        min = MIN_SCALE,
        max = MAX_SCALE,
        step = 0.05,
        format = "%.2f",
        getFunction = function()
            return tonumber(GURT.vars.scale) or DEFAULTS.scale
        end,
        setFunction = function(value)
            SetScale(value)
        end,
        default = DEFAULTS.scale,
    })

    panel:AddSetting({
        type = library.ST_SLIDER,
        label = "Horizontal Position (X)",
        tooltip = "Move the tracker left or right.",
        min = MIN_X,
        max = MAX_X,
        step = 5,
        format = "%.0f",
        getFunction = function()
            return tonumber(GURT.vars.xOffset) or DEFAULTS.xOffset
        end,
        setFunction = function(value)
            SetHorizontal(value)
        end,
        default = DEFAULTS.xOffset,
    })

    panel:AddSetting({
        type = library.ST_SLIDER,
        label = "Vertical Position (Y)",
        tooltip = "Move the tracker up or down.",
        min = MIN_Y,
        max = MAX_Y,
        step = 5,
        format = "%.0f",
        getFunction = function()
            return tonumber(GURT.vars.yOffset) or DEFAULTS.yOffset
        end,
        setFunction = function(value)
            SetVertical(value)
        end,
        default = DEFAULTS.yOffset,
    })

    panel:AddSetting({
        type = library.ST_BUTTON,
        label = "Reset HUD Position and Scale",
        buttonText = "Reset",
        tooltip = "Return the tracker to its default size and position.",
        clickHandler = function()
            ResetAllSettings()
        end,
    })

    GURT.settingsPanel = panel
    GURT.settingsRegistered = true
    d("GURT: Settings registered under Settings > Add-ons.")
    return true
end

local function RegisterLibrary()
    if not LibGroupCombatStats or type(LibGroupCombatStats.RegisterAddon) ~= "function" then
        d("GURT: LibGroupCombatStats is missing. Install/enable it and its console dependencies.")
        return false
    end

    GURT.lgcs = LibGroupCombatStats.RegisterAddon(ADDON_NAME, { "ULT" })
    if not GURT.lgcs then
        d("GURT: LibGroupCombatStats could not register ULT sharing.")
        return false
    end

    if LibGroupCombatStats.EVENT_GROUP_ULT_UPDATE then
        GURT.lgcs:RegisterForEvent(
            LibGroupCombatStats.EVENT_GROUP_ULT_UPDATE,
            QueueRefresh
        )
    end

    if LibGroupCombatStats.EVENT_PLAYER_ULT_UPDATE then
        GURT.lgcs:RegisterForEvent(
            LibGroupCombatStats.EVENT_PLAYER_ULT_UPDATE,
            QueueRefresh
        )
    end

    return true
end

local function OnAddonLoaded(eventCode, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    GURT.vars = ZO_SavedVars:NewAccountWide(
        SAVED_VARIABLES_NAME,
        8,
        nil,
        DEFAULTS
    )

    CreateUI()
    SLASH_COMMANDS["/gurt"] = HandleSlashCommand

    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_GroupJoined",
        EVENT_GROUP_MEMBER_JOINED,
        function()
            zo_callLater(QueueRefresh, 500)
            zo_callLater(QueueRefresh, 1500)
        end
    )
    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_GroupLeft",
        EVENT_GROUP_MEMBER_LEFT,
        QueueRefresh
    )
    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_PlayerActivated",
        EVENT_PLAYER_ACTIVATED,
        function()
            zo_callLater(QueueRefresh, 1000)
            zo_callLater(RefreshCorrosiveIcon, 1200)
            RegisterSettingsPanel()
        end
    )

    if EVENT_GROUP_MEMBER_CONNECTED_STATUS then
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_GroupConnected",
            EVENT_GROUP_MEMBER_CONNECTED_STATUS,
            QueueRefresh
        )
    end

    RegisterLibrary()
    RegisterSettingsPanel()
    zo_callLater(QueueRefresh, 1500)

    d("Group Ultimate Tracker v" .. ADDON_VERSION .. " loaded.")
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
