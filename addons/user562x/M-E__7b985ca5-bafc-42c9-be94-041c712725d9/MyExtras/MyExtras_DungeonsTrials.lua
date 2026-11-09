local ME = MyExtras
local DT = {}
ME.DungeonsTrials = DT

--------------------------------------------------
-- Config
--------------------------------------------------
local SUBMENU_ICON = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_trials.dds"

local CRATE_SCENES = { "crownCrateGamepad", "crownCrateKeyboard" }

local FIRST_SLOT        = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
local SLOT_COUNT        = 5
local GRAVE_LORD_LINE   = 131
local LIVING_DEATH_LINE = 133
local SIPHON_IDS = { [115924] = true, [118008] = true, [118763] = true }
local TETHER_IDS = { [115926] = true, [118070] = true, [118122] = true }

local PLACE_KEYS = {
    dungeons = "dungeonsHideDungeons",
    trials   = "dungeonsHideTrials",
}

DT.defaults = {
    dungeonsHidePlayers  = false,
    dungeonsHideDungeons = true,
    dungeonsHideTrials   = true,
}

DT.placeChoices = {
    { name = "Dungeons", value = "dungeons" },
    { name = "Trials",   value = "trials"   },
}

local hiding      = false
local corpseShown = false

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return ME.savedVariables
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
        if force or not hiding then SetPlayersHidden(true) end
        hiding = true
    elseif hiding then
        SetPlayersHidden(false)
        hiding = false
    end
end

function DT:OnCombatState(inCombat)
    if not (inCombat and hiding) then return end
    if not UsesCorpses() then return end
    SetPlayersHidden(false)
    hiding = false
    corpseShown = true
end

function DT:RegisterScenes()
    for i = 1, #CRATE_SCENES do
        local scene = SCENE_MANAGER:GetScene(CRATE_SCENES[i])
        if scene then
            scene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_HIDDEN and hiding then
                    DT:Apply(true)
                end
            end)
        end
    end
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
            tooltip = "Hides other players while you're in dungeons and trials.\n\n" .. ME.SAVED_ACCOUNT_TIP,
            options = {
                {
                    type    = "toggle",
                    name    = "Hide Players",
                    preset  = "YES_NO",
                    default = defaults.dungeonsHidePlayers,
                    tooltip = "Hides your group's characters so you only see yourself. "
                           .. "They disappear after they bar swap or after a loading screen.\n\n"
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
            },
        },
    }
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function DT:Init()
    self:RegisterScenes()
    EVENT_MANAGER:RegisterForEvent(ME.name .. "_DungeonsTrials", EVENT_PLAYER_COMBAT_STATE,
        function(_, inCombat) DT:OnCombatState(inCombat) end)
end

function DT:OnPlayerActivated()
    self:Apply(true)
end

function DT:OnReset()
    self:Apply()
end

ME:RegisterFeature(DT)
