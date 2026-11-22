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
local GROUP_PREFIXES = {
    { "dungeonsHide",       "hidePlayers" },
    { "dungeonsSortFinder", "dungeonFinder" },
    { "trialTimer",         "trialTimer" },
    { "groupFinder",        "groupFinder" },
}

local function GroupFor(key)
    for i = 1, #GROUP_PREFIXES do
        local prefix = GROUP_PREFIXES[i][1]
        if string.sub(key, 1, #prefix) == prefix then return GROUP_PREFIXES[i][2] end
    end
    return nil
end

local baseDefaults = DT.defaults
local scope = ME:NewScope("dungeonsCharSettings", "dungeonsUseCharacter")
DT.scope = scope
DT.defaults = scope.defaults
scope:AddDefaults(baseDefaults, GroupFor)

function DT:UsesCharacterSettings(group)
    return scope:UsesCharacter(group)
end

local function SV()
    return scope:Settings()
end

function DT:Settings()
    return SV()
end

function DT:AddDefaults(list)
    scope:AddDefaults(list, GroupFor)
end

function DT:RefreshAll()
    self:Apply()
    self:HookFinder()
    if ME.TrialTimer then ME.TrialTimer:Refresh() end
    if ME.GroupFinder then ME.GroupFinder:Refresh(false) end
end

function DT:CharacterOption(group)
    return ME:CharacterOption(scope, group, function() DT:RefreshAll() end)
end

function DT:SavedTip(group)
    return ME:SavedTip(scope, group)
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
local function AddCharacterOption(submenu, group)
    if not submenu or type(submenu.options) ~= "table" then return submenu end
    local position = 1
    if submenu.options[1] and submenu.options[1].name == "Enabled" then position = 2 end
    table.insert(submenu.options, position, DT:CharacterOption(group))
    local description = submenu.tooltip
    submenu.tooltip = function()
        local text = type(description) == "function" and description() or description or ""
        return text .. "\n\n" .. DT:SavedTip(group)
    end
    return submenu
end

local function Page(name, group, description, options)
    return AddCharacterOption({
        type    = "submenu",
        name    = name,
        tooltip = description,
        options = options,
    }, group)
end

function DT:GetOptions()
    local defaults = self.defaults

    local function IsOff() return not IsOn() end

    local hidePlayers = {
        {
            type    = "toggle",
            name    = "Enabled",
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
    }

    local dungeonFinder = {
        {
            type    = "toggle",
            name    = "Sort Alphabetically",
            preset  = "YES_NO",
            default = defaults.dungeonsSortFinder,
            tooltip = "Lists the dungeons in the Dungeon Finder alphabetically.",
            getFunc = function() return SV().dungeonsSortFinder end,
            setFunc = function(val)
                SV().dungeonsSortFinder = val
                DT:HookFinder()
            end,
        },
    }

    local options = {}
    if ME.GroupFinder then options[#options + 1] = AddCharacterOption(ME.GroupFinder:SubmenuOption(), "groupFinder") end
    options[#options + 1] = Page("Hide Players", "hidePlayers", "Hides your group's characters in dungeons and trials.", hidePlayers)
    options[#options + 1] = Page("Dungeon Finder", "dungeonFinder", "Sorts the Dungeon Finder.", dungeonFinder)
    if ME.TrialTimer then options[#options + 1] = AddCharacterOption(ME.TrialTimer:SubmenuOption(), "trialTimer") end

    return {
        {
            type    = "submenu",
            name    = "Dungeons & Trials",
            icon    = SUBMENU_ICON,
            tooltip = "Checks the Group Finder for you, hides other players in dungeons and trials, "
                   .. "sorts the Dungeon Finder and times your trials.",
            options = options,
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
    return scope:ResetSkipKeys()
end

function DT:OnReset()
    scope:ResetCharacter()
    self:RefreshAll()
end

ME:RegisterFeature(DT)
