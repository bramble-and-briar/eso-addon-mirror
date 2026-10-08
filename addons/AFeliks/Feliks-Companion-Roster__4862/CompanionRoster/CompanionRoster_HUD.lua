CompanionRoster = CompanionRoster or {}
local CompanionRoster = CompanionRoster -- local reference, faster than repeated _G lookups

-- The always-visible Companion Info line for the currently summoned
-- companion, e.g. "Bastian Lv:16 (94938/116000) 81% [+0] Rap:6 [0] (3247)".
-- Positioned with the base game's Edit HUD (HUD_MANAGER), which also saves
-- the position, so no position code lives here.
CompanionRoster.HUD = {}
local HUD = CompanionRoster.HUD

local FONT_REGULAR = "ZoFontGame"
local FONT_BOLD = "ZoFontGameBold"
local TEXT_PADDING = 6
local EMPTY_WIDTH = 200 -- editor box width when there's no text to measure

-- Default spot: the top-left corner, in the free strip above the buff boxes
-- and left of the compass (the bottom-left spot ran into the ability bar once
-- the line got long). Anchored to the corner so it holds up across screen sizes.
local DEFAULT_OFFSET_X = 9
local DEFAULT_OFFSET_Y = 6

local frame, textLabel, backdrop
local element -- the HUD_MANAGER element, nil if registration failed
local editorShowing = false
local inGameMenu = false -- the game menu (Settings, Add-Ons, etc.) is the current scene
local settingsPanelOpen = false -- this addon's own LibAddonMenu panel is the page being viewed
local registrationError = nil

-- The most recent single change (not a running total). Not stored: it only means something
-- relative to what just happened, and start at 0 like the reference layout.
local lastXpGain = 0
local lastRapportChange = 0

local function SignedNumber(value)
    if value > 0 then
        return "+" .. value
    end
    return tostring(value)
end

-- Builds the line from the enabled parts, or returns nil if no companion is out.
local function BuildText()
    if not HasActiveCompanion() then
        return nil
    end
    local companionId = GetActiveCompanionDefId()
    if companionId == nil or companionId == 0 then
        return nil
    end

    local Data = CompanionRoster.Data
    -- First word only ("Bastian Hallix" -> "Bastian"); names with no space,
    -- like "Sharp-as-Night", come through whole.
    local fullName = zo_strformat("<<1>>", GetCompanionName(companionId))
    local parts = { fullName:match("^%S+") or fullName }

    local level, currentXp = GetActiveCompanionLevelInfo()
    if Data.GetHudOption("level") then
        table.insert(parts, "Lv:" .. level)
    end

    -- Same max-level test the base game's companion manager uses: no XP
    -- needed for the next level means there is no next level.
    local xpForLevel = GetNumExperiencePointsInCompanionLevel(level + 1) or 0
    if xpForLevel > 0 then
        if Data.GetHudOption("xpRaw") then
            table.insert(parts, string.format("(%d/%d)", currentXp, xpForLevel))
        end
        if Data.GetHudOption("xpPercent") then
            table.insert(parts, string.format("%d%%", zo_floor(currentXp / xpForLevel * 100)))
        end
        if Data.GetHudOption("xpGain") then
            table.insert(parts, string.format("[%s]", SignedNumber(lastXpGain)))
        end
    end

    if Data.GetHudOption("rapportLevel") then
        table.insert(parts, "Rap:" .. GetActiveCompanionRapportLevel())
    end
    if Data.GetHudOption("rapportChange") then
        table.insert(parts, string.format("[%s]", SignedNumber(lastRapportChange)))
    end
    if Data.GetHudOption("rapportNumber") then
        table.insert(parts, string.format("(%d)", GetActiveCompanionRapport()))
    end

    return table.concat(parts, " ")
end

function HUD.Refresh()
    if not frame then
        return
    end

    local Data = CompanionRoster.Data
    textLabel:SetFont(Data.GetHudOption("bold") and FONT_BOLD or FONT_REGULAR)
    textLabel:SetColor(Data.GetHudColor())

    local text = Data.GetHudOption("enabled") and BuildText()

    if text then
        textLabel:SetText(text)
        frame:SetWidth(textLabel:GetTextWidth() + TEXT_PADDING * 2)
    elseif not editorShowing then
        frame:SetWidth(EMPTY_WIDTH)
    end

    -- Inside Edit HUD every element is just a named box, so the live text and
    -- background are hidden there. The frame itself stays shown so its box
    -- has a size even when no companion is out.
    -- In the game menu it only shows on this addon's own settings page, so
    -- setting changes can be watched live without it sitting over every menu.
    local hiddenByScene = editorShowing or (inGameMenu and not settingsPanelOpen)
    local showContent = text ~= nil and text ~= false and not hiddenByScene
    textLabel:SetHidden(not showContent)
    backdrop:SetHidden(not showContent)
end

-- Scenes the frame is added to. HUD_FRAGMENT_GROUP in the base game's
-- hudscene.lua is a local, so it can't be reused; the editor scene is
-- included so the frame has a size there, and the game menu scene (where
-- this addon's settings panel lives) so setting changes can be watched live.
local SCENES_TO_ATTACH = { "HUD_SCENE", "HUD_UI_SCENE", "HUD_EDITOR_SCENE_KEYBOARD", "GAME_MENU_SCENE" }
local attachedScenes = {}
local fragment

-- Scenes whose showing/hidden state changes what the frame displays.
local SCENE_FLAG_SETTERS = {
    HUD_EDITOR_SCENE_KEYBOARD = function(isShowing) editorShowing = isShowing end,
    GAME_MENU_SCENE = function(isShowing) inGameMenu = isShowing end,
}

local function AttachScenes()
    if not frame then
        return
    end
    fragment = fragment or ZO_SimpleSceneFragment:New(frame)
    for _, sceneName in ipairs(SCENES_TO_ATTACH) do
        local scene = _G[sceneName]
        if scene and not attachedScenes[sceneName] then
            scene:AddFragment(fragment)
            attachedScenes[sceneName] = true
            local setFlag = SCENE_FLAG_SETTERS[sceneName]
            if setFlag then
                scene:RegisterCallback("StateChange", function(_, newState)
                    if newState == SCENE_SHOWING then
                        setFlag(true)
                        HUD.Refresh()
                    elseif newState == SCENE_HIDDEN then
                        setFlag(false)
                        HUD.Refresh()
                    end
                end)
            end
        end
    end
end

local function OnExperienceGain(_, companionId, previousLevel, previousExperience, currentExperience)
    if companionId == GetActiveCompanionDefId() then
        lastXpGain = currentExperience - previousExperience
    end
    HUD.Refresh()
end

local function OnRapportUpdate(_, companionId, previousRapport, currentRapport)
    if companionId == GetActiveCompanionDefId() then
        lastRapportChange = currentRapport - previousRapport
    end
    HUD.Refresh()
end

local function OnCompanionChanged()
    lastXpGain = 0
    lastRapportChange = 0
    HUD.Refresh()
end

local function OnPlayerActivated()
    AttachScenes() -- picks up any scene that didn't exist yet at addon load
    if registrationError then
        d("Feliks' Companion Roster: the Companion Info frame could not be set up for Edit HUD (" .. registrationError .. ").")
        registrationError = nil
    end
    HUD.Refresh()
end

local function OnAddOnLoaded(_, addOnName)
    if addOnName ~= CompanionRoster.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent("CompanionRoster_HUD", EVENT_ADD_ON_LOADED)

    frame = CompanionRosterHUD
    textLabel = frame:GetNamedChild("Text")
    backdrop = frame:GetNamedChild("BG")

    if HUD_MANAGER then
        local ok, result = pcall(function()
            return HUD_MANAGER:RegisterKeyboardElement(frame, "Companion Info",
                {
                    defaultAnchor = ZO_Anchor:New(TOPLEFT, nil, TOPLEFT, DEFAULT_OFFSET_X, DEFAULT_OFFSET_Y),
                    -- Turning the frame off in settings also removes its box from Edit HUD.
                    isValid = function() return CompanionRoster.Data.GetHudOption("enabled") end,
                })
        end)
        if ok then
            element = result
            element:RevertOffsetModifications()
        else
            registrationError = tostring(result)
        end
    else
        registrationError = "HUD_MANAGER not found"
    end

    AttachScenes()

    -- LibAddonMenu fires these as its panel's page is shown or left; the
    -- panel object is the one RegisterAddonPanel returned (see Settings.lua).
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
        if panel == CompanionRoster.settingsPanel then
            settingsPanelOpen = true
            HUD.Refresh()
        end
    end)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if panel == CompanionRoster.settingsPanel then
            settingsPanelOpen = false
            HUD.Refresh()
        end
    end)

    EVENT_MANAGER:RegisterForEvent("CompanionRoster_HUD", EVENT_COMPANION_ACTIVATED, OnCompanionChanged)
    EVENT_MANAGER:RegisterForEvent("CompanionRoster_HUD", EVENT_COMPANION_DEACTIVATED, OnCompanionChanged)
    EVENT_MANAGER:RegisterForEvent("CompanionRoster_HUD", EVENT_COMPANION_EXPERIENCE_GAIN, OnExperienceGain)
    EVENT_MANAGER:RegisterForEvent("CompanionRoster_HUD", EVENT_COMPANION_RAPPORT_UPDATE, OnRapportUpdate)
    EVENT_MANAGER:RegisterForEvent("CompanionRoster_HUD", EVENT_COMPANION_SKILLS_FULL_UPDATE, HUD.Refresh)
    EVENT_MANAGER:RegisterForEvent("CompanionRoster_HUD", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    HUD.Refresh()
end

EVENT_MANAGER:RegisterForEvent("CompanionRoster_HUD", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
