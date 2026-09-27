RyticTank = RyticTank or {}
local RyticTank = RyticTank

-- Cache core ESO globals/functions used during addon initialization.
local EM = EVENT_MANAGER
local ZO_SavedVars = ZO_SavedVars
local ZO_DeepTableCopy = ZO_DeepTableCopy
local GetWorldName = GetWorldName
RyticTank.name = "RyticTankTools"
RyticTank.version = "3.1.0"

RyticTank.defaults = {
    sets = {
        enabled=true,
        hideOutOfCombat=true,
        locked=true,
        preview=false,
        orientation="VERTICAL",
        iconSize=36,
        spacing=8,
        abbreviateNames=false,
        position={x=661,y=560},
    },
    block = {
        enabled=true,
        locked=true,
        preview=false,
        combatOnly=false,
        scale=1.0,
        position={x=800,y=500},
    },
    resources = {
        enabled=true,
        hideOutOfCombat=false,
        locked=true,
        preview=true,
        scale=0.85,
        warningHealth=20,
        warningStamina=20,
        warningMagicka=20,
        potionAlert=true,
        potionThreshold=30,
        potionHealth=true,
        potionStamina=true,
        potionMagicka=true,
        potionCombatOnly=true,
        potionReadyOnly=true,
        position={x=684,y=444},
    },
    stats = {
        enabled=true,
        savedFights={},
    },
}

local function OnLoaded(_, addonName)
    if addonName ~= RyticTank.name then return end
    EM:UnregisterForEvent("RyticTankToolsLoaded", EVENT_ADD_ON_LOADED)

    RyticTank.saved = ZO_SavedVars:NewAccountWide(
        "RyticTankSavedVariables", 1, GetWorldName(), RyticTank.defaults
    )

    if not RyticTank.saved.resources then
        RyticTank.saved.resources = ZO_DeepTableCopy(RyticTank.defaults.resources)
    end
    if not RyticTank.saved.stats then
        RyticTank.saved.stats = ZO_DeepTableCopy(RyticTank.defaults.stats)
    elseif RyticTank.saved.stats.enabled == nil then
        RyticTank.saved.stats.enabled = true
    end

    -- v3 integration sanity: add only missing fields. Never overwrite the
    -- player's established module settings or positions.
    if not RyticTank.saved.sets then
        RyticTank.saved.sets = ZO_DeepTableCopy(RyticTank.defaults.sets)
    end
    if not RyticTank.saved.block then
        RyticTank.saved.block = ZO_DeepTableCopy(RyticTank.defaults.block)
    end
    if RyticTank.saved.block.enabled == nil then RyticTank.saved.block.enabled = true end
    if RyticTank.saved.block.locked == nil then RyticTank.saved.block.locked = true end
    if RyticTank.saved.block.combatOnly == nil then RyticTank.saved.block.combatOnly = false end
    if RyticTank.saved.block.scale == nil then RyticTank.saved.block.scale = 1.0 end

    -- Default changes must not reset established positions or scales.
    RyticTank.saved.layoutDefaultsVersion=2

    if RyticTank.Settings and RyticTank.Settings.Initialize then
        local ok, err = pcall(RyticTank.Settings.Initialize)
        if not ok then
            d("|cFF3333RyticTankTools Settings error: "..tostring(err).."|r")
        end
    end

    if RyticTank.Sets and RyticTank.Sets.Initialize then
        local ok, err = pcall(RyticTank.Sets.Initialize)
        if not ok then
            d("|cFF3333RyticTankTools Sets error: "..tostring(err).."|r")
        end
    else
        d("|cFFAA00RyticTankTools: Sets module was not loaded.|r")
    end

    if RyticTank.Block and RyticTank.Block.Initialize then
        local ok, err = pcall(RyticTank.Block.Initialize)
        if not ok then
            d("|cFF3333RyticTankTools Block error: "..tostring(err).."|r")
        end
    else
        d("|cFFAA00RyticTankTools: Block module was not loaded.|r")
    end

    if RyticTank.Stats and RyticTank.Stats.Initialize then
        local ok, err = pcall(RyticTank.Stats.Initialize)
        if not ok then
            d("|cFF3333RyticTankTools Stats init error: "..tostring(err).."|r")
        end
    else
        d("|cFFAA00RyticTankTools: Stats module did not load.|r")
    end

    if RyticTank.Resources and RyticTank.Resources.Initialize then
        local ok, err = pcall(RyticTank.Resources.Initialize)
        if ok then
            d("|c00FF00Rytic Combat & Raid Tools v"..tostring(RyticTank.version).." core modules loaded.|r")
        else
            d("|cFF3333RyticTankTools Resource error: "..tostring(err).."|r")
        end
    else
        d("|cFF3333RyticTankTools: Resource module did not load.|r")
    end
end

EM:RegisterForEvent("RyticTankToolsLoaded", EVENT_ADD_ON_LOADED, OnLoaded)
