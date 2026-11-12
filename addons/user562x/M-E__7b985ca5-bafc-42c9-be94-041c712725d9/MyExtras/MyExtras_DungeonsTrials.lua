local ME = MyExtras
local DT = {}
ME.DungeonsTrials = DT

--------------------------------------------------
-- Config
--------------------------------------------------
local SUBMENU_ICON = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_trials.dds"

local HUD_SCENES   = { hud = true, hudui = true }
local CRATE_SCENES = { crownCrateGamepad = true, crownCrateKeyboard = true }

local FIRST_SLOT        = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
local SLOT_COUNT        = 5
local GRAVE_LORD_LINE   = 131
local LIVING_DEATH_LINE = 133
local SPECIFIC_ENTRIES  = 3
local SIPHON_IDS = { [115924] = true, [118008] = true, [118763] = true }
local TETHER_IDS = { [115926] = true, [118070] = true, [118122] = true }

local PLACE_KEYS = {
    dungeons = "dungeonsHideDungeons",
    trials   = "dungeonsHideTrials",
}

DT.charDefaults = {
    dungeonsUseCharacter = false,
}

DT.defaults = {
    dungeonsHidePlayers  = false,
    dungeonsHideDungeons = true,
    dungeonsHideTrials   = true,
    dungeonsSortFinder   = false,
}

DT.placeChoices = {
    { name = "Dungeons", value = "dungeons" },
    { name = "Trials",   value = "trials"   },
}

local hiding       = false
local corpseShown  = false
local paused       = false
local finderHooked = false

--------------------------------------------------
-- Helpers
--------------------------------------------------
local charFilled = false

local function CopyValue(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = v end
    return copy
end

local function CharSettings()
    local cv = ME.charVariables
    if not cv then return nil end
    if type(cv.dungeonsCharSettings) ~= "table" then cv.dungeonsCharSettings = {} end
    local settings = cv.dungeonsCharSettings
    if not settings.seeded then
        local account = ME.savedVariables
        for key, value in pairs(DT.defaults) do
            local current = account and account[key]
            if current == nil then current = value end
            settings[key] = CopyValue(current)
        end
        settings.seeded = true
        charFilled = true
    elseif not charFilled then
        for key, value in pairs(DT.defaults) do
            if settings[key] == nil then settings[key] = CopyValue(value) end
        end
        charFilled = true
    end
    return settings
end

function DT:UsesCharacterSettings()
    return ME.charVariables ~= nil and ME.charVariables.dungeonsUseCharacter == true
end

local function SV()
    if DT:UsesCharacterSettings() then
        return CharSettings() or ME.savedVariables
    end
    return ME.savedVariables
end

local function SavedTip()
    if DT:UsesCharacterSettings() then return ME.SAVED_CHARACTER_TIP end
    return ME.SAVED_ACCOUNT_TIP
end

function DT:Settings()
    return SV()
end

function DT:AddDefaults(list)
    for key, value in pairs(list) do
        self.defaults[key] = value
        ME.defaults[key] = value
    end
    charFilled = false
end

function DT:SetUseCharacterSettings(value)
    local cv = ME.charVariables
    if not cv then return end
    value = value == true
    if (cv.dungeonsUseCharacter == true) == value then return end
    cv.dungeonsUseCharacter = value
    self:Apply()
    if ME.TrialTimer then ME.TrialTimer:Refresh() end
    local panel = ME.settingsPanel
    if panel and panel.Refresh then panel:Refresh() end
end

local function IsOn()
    local sv = SV()
    return sv ~= nil and sv.dungeonsHidePlayers == true
end

local function CurrentPlace()
    if IsActiveWorldBattleground() or IsPlayerInAvAWorld() then return nil end
    if IsPlayerInRaid() then return "trials" end
    if IsInstanceEndlessDungeon() then return "dungeons" end
    if IsUnitInDungeon("player") and GetCurrentZoneDungeonDifficulty() ~= DUNGEON_DIFFICULTY_NONE then
        return "dungeons"
    end
    return nil
end

local function LineActive(skillLineId)
    if not (SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER.GetSkillLineDataById) then return false end
    local data = SKILLS_DATA_MANAGER:GetSkillLineDataById(skillLineId)
    return data ~= nil and data:IsActive() == true
end

local function Slotted(ids)
    for i = 0, SLOT_COUNT - 1 do
        local slot = FIRST_SLOT + i
        if ids[GetSlotBoundId(slot, HOTBAR_CATEGORY_PRIMARY)] or ids[GetSlotBoundId(slot, HOTBAR_CATEGORY_BACKUP)] then
            return true
        end
    end
    return false
end

local function UsesCorpses()
    return (LineActive(GRAVE_LORD_LINE) and Slotted(SIPHON_IDS))
        or (LineActive(LIVING_DEATH_LINE) and Slotted(TETHER_IDS))
end

local function SetPlayersHidden(hide)
    if type(SetCrownCrateNPCVisible) ~= "function" then return end
    pcall(SetCrownCrateNPCVisible, hide == true)
end

local function InHud()
    return SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
end

local function SwitchOn()
    if InHud() then
        paused = false
        SetPlayersHidden(true)
    else
        paused = true
        SetPlayersHidden(false)
    end
end

--------------------------------------------------
-- Hide Players
--------------------------------------------------
function DT:ShouldHide()
    if not IsOn() then return false end
    local place = CurrentPlace()
    if not place then return false end
    return SV()[PLACE_KEYS[place]] == true
end

function DT:Apply(force)
    if self:ShouldHide() then
        if corpseShown and not force then return end
        if IsUnitInCombat("player") and UsesCorpses() then return end
        corpseShown = false
        if force or not hiding then SwitchOn() end
        hiding = true
    elseif hiding then
        SetPlayersHidden(false)
        hiding = false
        paused = false
    end
end

function DT:OnCombatState(inCombat)
    if not (inCombat and hiding) then return end
    if not UsesCorpses() then return end
    SetPlayersHidden(false)
    hiding = false
    paused = false
    corpseShown = true
end

function DT:OnSceneChanged(scene, newState)
    if not hiding then return end
    local name = scene:GetName()
    if HUD_SCENES[name] then
        if newState == SCENE_SHOWN and paused then SwitchOn() end
    elseif CRATE_SCENES[name] then
        if newState == SCENE_SHOWING then paused = true end
    elseif newState == SCENE_SHOWING and not paused then
        paused = true
        SetPlayersHidden(false)
    end
end

--------------------------------------------------
-- Dungeon Finder
--------------------------------------------------
local function FinderName(entry)
    local location = entry and entry.data
    if type(location) ~= "table" or type(location.GetNameGamepad) ~= "function" then return nil end
    return zo_strlower(location:GetNameGamepad() or "")
end

local function FinderId(entry)
    local location = entry.data
    if type(location.GetId) == "function" then return location:GetId() or 0 end
    return 0
end

local function CompareFinder(a, b)
    local aName, bName = FinderName(a), FinderName(b)
    if not aName or not bName then
        return aName == nil and bName ~= nil
    end
    if aName ~= bName then return aName < bName end
    return FinderId(a) < FinderId(b)
end

function DT:HookFinder()
    if finderHooked then return end
    local finder = rawget(_G, "DUNGEON_FINDER_GAMEPAD")
    if not (finder and type(finder.RefreshView) == "function") then return end
    ZO_PreHook(finder, "RefreshView", function(self)
        local list = self.entryList
        if not (list and list.SetSortFunction) then return end
        local sort = SV().dungeonsSortFinder == true and self.navigationMode == SPECIFIC_ENTRIES
        list:SetSortFunction(sort and CompareFinder or nil)
    end)
    finderHooked = true
end

--------------------------------------------------
-- Settings
--------------------------------------------------
function DT:GetOptions()
    local defaults = self.defaults

    local function IsOff() return not IsOn() end

    return {
        {
            type    = "submenu",
            name    = "Dungeons & Trials",
            icon    = SUBMENU_ICON,
            tooltip = function()
                return "Hides other players in dungeons and trials, sorts the Dungeon Finder and times your trials.\n\n" .. SavedTip()
            end,
            options = {
                {
                    type    = "toggle",
                    name    = "Character Settings",
                    tooltip = "Off uses the same settings for the whole account. On gives this character its own settings, "
                           .. "copied from the account settings the first time you turn it on.",
                    details = function()
                        if DT:UsesCharacterSettings() then
                            return "This character has its own settings."
                        end
                        return "All your characters share the same settings."
                    end,
                    getFunc = function() return DT:UsesCharacterSettings() end,
                    setFunc = function(val) DT:SetUseCharacterSettings(val) end,
                },
                {
                    type    = "toggle",
                    name    = "Hide Players",
                    preset  = "YES_NO",
                    default = defaults.dungeonsHidePlayers,
                    tooltip = "Hides your group's characters so you only see yourself. "
                           .. "They reappear after loading screens, respawns and menus, and disappear again "
                           .. "when they bar swap or do something that updates their character.\n\n"
                           .. "If you have a Necromancer Siphon or Tether skill slotted, they show again "
                           .. "when you enter combat so you can use corpses.",
                    getFunc = function() return SV().dungeonsHidePlayers end,
                    setFunc = function(val)
                        SV().dungeonsHidePlayers = val
                        DT:Apply()
                    end,
                },
                {
                    type     = "checklist",
                    name     = "Hide In",
                    choices  = self.placeChoices,
                    default  = { "dungeons", "trials" },
                    tooltip  = "Where it hides players.",
                    disabled = IsOff,
                    getFunc  = function()
                        local sv = SV()
                        local values = {}
                        for i = 1, #DT.placeChoices do
                            local value = DT.placeChoices[i].value
                            if sv[PLACE_KEYS[value]] then values[#values + 1] = value end
                        end
                        return values
                    end,
                    setFunc  = function(values)
                        local sv = SV()
                        local set = {}
                        if type(values) == "table" then
                            for i = 1, #values do set[values[i]] = true end
                        end
                        for value, key in pairs(PLACE_KEYS) do
                            sv[key] = set[value] == true
                        end
                        DT:Apply()
                    end,
                },
                {
                    type    = "toggle",
                    name    = "Sort Dungeon Finder",
                    preset  = "YES_NO",
                    default = defaults.dungeonsSortFinder,
                    tooltip = "Lists the dungeons in the Dungeon Finder alphabetically.",
                    getFunc = function() return SV().dungeonsSortFinder end,
                    setFunc = function(val)
                        SV().dungeonsSortFinder = val
                        DT:HookFinder()
                    end,
                },
                ME.TrialTimer and ME.TrialTimer:SubmenuOption() or nil,
            },
        },
    }
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function DT:Init()
    self:HookFinder()
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
        DT:OnSceneChanged(scene, newState)
    end)
    EVENT_MANAGER:RegisterForEvent(ME.name .. "_DungeonsTrials", EVENT_PLAYER_COMBAT_STATE,
        function(_, inCombat) DT:OnCombatState(inCombat) end)
end

function DT:OnPlayerActivated()
    self:HookFinder()
    self:Apply(true)
end

function DT:ResetSkipKeys()
    local keys = {}
    if self:UsesCharacterSettings() then
        for key in pairs(self.defaults) do keys[#keys + 1] = key end
    end
    return keys
end

function DT:OnReset()
    if self:UsesCharacterSettings() then
        local settings = CharSettings()
        if settings then
            for key, value in pairs(self.defaults) do
                settings[key] = CopyValue(value)
            end
            settings.seeded = true
        end
    end
    self:Apply()
end

ME:RegisterFeature(DT)
