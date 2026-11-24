-- Rebuilds the name line of the targeted (reticle) unit frame for players:
--   name [Alliance War rank] [class icon] [champion icon]level
-- The game draws it as: [champion / veterancy icon] level-or-veterancy-rank name[difficulty icon] [rank]
-- NPCs, monsters and objects are left to the game, except for the optional
-- removal of the target marker icon.

TargetFrameLine = {
    name = "TargetFrameLine",
    version = "1.2.1",
}
local TFL = TargetFrameLine

TFL.defaults = {
    showChampionIcon = true,
    showDifficultyIcon = false,
    hideTargetMarker = true,
    iconSize = 115, -- % of the font height
}

local CHAMPION_ICON = "EsoUI/Art/Champion/champion_icon_32.dds"

local frame -- the game's ZO_UnitFrameObject for "reticleover"

local function BuildLine(unitTag)
    local sv = TFL.sv
    local size = sv.iconSize .. "%"
    local parts = {}

    local targetMarker = GetUnitTargetMarkerType(unitTag)
    if targetMarker ~= TARGET_MARKER_TYPE_NONE and not sv.hideTargetMarker then
        parts[#parts + 1] = zo_iconFormat(ZO_GetPlatformTargetMarkerIcon(targetMarker), "100%", "100%")
    end

    local name = ZO_GetPrimaryPlayerNameFromUnitTag(unitTag)
    if sv.showDifficultyIcon then
        local difficulty = GetUnitOverlandDifficulty(unitTag)
        if difficulty > OVERLAND_DIFFICULTY_TYPE_BASEGAME
            and GetOverlandDifficultyDisabledReason() == OVERLAND_DIFFICULTY_DISABLED_REASON_NONE then
            local difficultyIcon = ZO_CHALLENGE_DIFFICULTY_ICONS_GAMEPAD[difficulty]
            if difficultyIcon then
                name = name .. zo_iconFormat(difficultyIcon, "115%", "115%")
            end
        end
    end
    parts[#parts + 1] = name

    local rankIcon = GetAvARankIcon(GetUnitAvARank(unitTag))
    if rankIcon and rankIcon ~= "" then
        local allianceColor = GetAllianceColor(GetUnitAlliance(unitTag))
        parts[#parts + 1] = allianceColor:Colorize(zo_iconFormatInheritColor(rankIcon, size, size))
    end

    local classId = GetUnitClassId(unitTag)
    local classIcon = classId and classId ~= 0 and ZO_GetPlatformClassIcon(classId)
    if classIcon and classIcon ~= "" then
        parts[#parts + 1] = zo_iconFormat(classIcon, size, size)
    end

    local level
    if IsUnitChampion(unitTag) then
        level = tostring(GetUnitEffectiveChampionPoints(unitTag))
        if sv.showChampionIcon then
            level = zo_iconFormat(CHAMPION_ICON, "100%", "100%") .. level
        end
    else
        level = tostring(GetUnitLevel(unitTag))
    end
    parts[#parts + 1] = level

    return table.concat(parts, " ")
end

-- The game appends the marker to the name as zo_iconFormat(icon, "100%", "100%").
local function StripTargetMarker(unitTag)
    local targetMarker = GetUnitTargetMarkerType(unitTag)
    if targetMarker == TARGET_MARKER_TYPE_NONE then return end
    local markup = zo_iconFormat(ZO_GetPlatformTargetMarkerIcon(targetMarker), "100%", "100%")
    local text = frame.nameLabel:GetText()
    local first, last = text:find(markup, 1, true)
    if first then
        frame.nameLabel:SetText(text:sub(1, first - 1) .. text:sub(last + 1))
    end
end

-- Runs after each of the game's UpdateName / UpdateLevel / UpdateRank, so the
-- line stays rebuilt whichever of them the game calls on its own.
local function Apply()
    if not frame or not frame.hasTarget then return end
    local unitTag = frame:GetUnitTag()
    if not IsUnitPlayer(unitTag) then
        if TFL.sv.hideTargetMarker then StripTargetMarker(unitTag) end
        return
    end

    -- Everything goes into the name label; the TextArea centers itself on it.
    frame.levelLabel:SetText("")
    frame.levelLabel:SetHidden(true)
    frame.nameLabel:SetAnchor(TOPLEFT) -- same call the game makes when there's no level
    if frame.championIcon then frame.championIcon:SetHidden(true) end
    if frame.veterancyRankIcon then frame.veterancyRankIcon:SetHidden(true) end
    if frame.rankIcon then frame.rankIcon:SetHidden(true) end

    frame.nameLabel:SetText(BuildLine(unitTag))
end

function TFL.Refresh()
    if frame and frame.hasTarget and not frame.hidden then
        frame:RefreshControls()
    end
end

local function Initialize()
    frame = UNIT_FRAMES:GetFrame("reticleover")

    ZO_PostHook(frame, "UpdateName", Apply)
    ZO_PostHook(frame, "UpdateLevel", Apply)
    ZO_PostHook(frame, "UpdateRank", Apply)
    TFL.Refresh()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= TFL.name then return end
    EVENT_MANAGER:UnregisterForEvent(TFL.name, EVENT_ADD_ON_LOADED)

    TFL.sv = ZO_SavedVars:NewAccountWide("TargetFrameLine_SV", 1, nil, TFL.defaults)
    TFL.InitializeSettings()
    Initialize()
end

EVENT_MANAGER:RegisterForEvent(TFL.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
