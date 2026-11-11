-- -----------------------------------------------------------------------------
-- PvPCooldownTracker
-- Author:  @VixenHunny
-- Edited: 4/15/2026
--
-- Defaults.lua
-- -----------------------------------------------------------------------------
PvPCooldownTracker = PvPCooldownTracker or {}
PvPCooldownTracker.Defaults = {}

local function CloneTable(source)
    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = CloneTable(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local defaults = {
    debugMode = 0,
    sets = {},
    customSetData = {},
    unlocked = true,
    snapToGrid = false,
    cooldown_expired = "FFFF00",
    gridSize = 16,
    showOutsideCombat = true,
    lagCompensation = true,
    -- Recent-proc recorder (ProcCapture.lua)
    procCapture = true,
    procCaptureMode = "standard",
    size = 64,
    set_active = "3CB043",
    labelSize = 1.5,
    labelFont = "$(BOLD_FONT)|18|soft-shadow-thick",
    timerFont = "$(BOLD_FONT)|22|soft-shadow-thick",
    style = {
        -- Colours (the "Ember" theme, see UI.Themes in Interface.lua)
        theme = "Ember",
        labelColor = { 0.96, 0.93, 0.88, 1.0 },
        timerColor = { 1.0, 0.97, 0.91, 1.0 },
        cooldownTint = { 0.62, 0.60, 0.58, 1.0 },
        glowColor = { 1.0, 0.55, 0.20, 1.0 },
        barBackgroundColor = { 0.0, 0.0, 0.0, 0.55 },
        barFillColor = { 0.95, 0.45, 0.15, 1.0 },
        barReadyColor = { 0.36, 0.80, 0.36, 1.0 },
        cardColor = { 0.06, 0.05, 0.05, 0.78 },
        -- Layout: "bar" (icon + name + countdown bar) or "icon" (icon + timer)
        layout = "bar",
        showCard = true,
        showName = true,
        showAnnouncements = true,
    },
    LabelLocation = {
        x = 600,
        y = 300
    },
    TextureLocation = {
        x = 640,
        y = 300
    
    },
    sounds = {
        onProc = {
            enabled = true,
            sound = 'STATS_PURCHASE',
        },
        onReady = {
            enabled = true,
            sound = 'SKILL_LINE_ADDED',
        },
    },
}

local sets = {}

function PvPCooldownTracker.Defaults:Generate()
    for key, set in pairs(PvPCooldownTracker.Data.Sets) do

        -- Populate Sets
        defaults.sets[key] = {
            x = defaults.TextureLocation.x,
            y = defaults.TextureLocation.y,
            labelx = defaults.LabelLocation.x,
            labely = defaults.LabelLocation.y,
            size = defaults.size,
            sounds = CloneTable(defaults.sounds),
        }
        if set.procType == "set" then
            -- Populate Sets
            sets[key] = true
        else
            -- Unsupported procType
        end

    end
end

-- Account-wide
function PvPCooldownTracker.Defaults.Get()
    return defaults
end

-- Account-wide tracking state
function PvPCooldownTracker.Defaults.GetCharacter()
    return {
		["set"] = sets
	}
end

