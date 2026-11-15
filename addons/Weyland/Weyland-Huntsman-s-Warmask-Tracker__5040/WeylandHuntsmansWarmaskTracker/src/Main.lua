--[[
    Weyland Huntsman's Warmask Tracker
    Tracks the player-side Huntsman's Warmask effect that mirrors an active Mark of Hircine.

    Design:
      * Mark tracking is active only while the mask is worn.
      * The mask is re-checked on every worn-slot change (boss gear swaps, Armory).

    Main: saved variables, migration and event registration.
]]

local ADDON = "WeylandHuntsmansWarmaskTracker"
local HMK = _G[ADDON]
local EM = EVENT_MANAGER
local T, Msg = HMK.T, HMK.Msg
local ICONS, SOUND_CANDIDATES, DEFAULTS = HMK.ICONS, HMK.SOUND_CANDIDATES, HMK.DEFAULTS
local HasId, DeepCopy = HMK.HasId, HMK.DeepCopy
local ui = HMK.ui
local SavePosition, ApplyMarkStyle = HMK.SavePosition, HMK.ApplyMarkStyle
local SyncPlayerWarmaskEffect, RefreshMask = HMK.SyncPlayerWarmaskEffect, HMK.RefreshMask
local CreateUI, BuildMenu, OnSlash = HMK.CreateUI, HMK.BuildMenu, HMK.OnSlash

local function OnSlotUpdate()
    RefreshMask()
end

local function OnPlayerDeactivated()
    -- Do not turn the fresh-install centre default into a saved position.
    if HMK.sv and HMK.sv.mark and HMK.sv.mark.positionValid == true then
        SavePosition(ui.mark, HMK.sv.mark)
    end
end

local function OnPlayerActivated()
    HMK.ClearMark()
    ApplyMarkStyle()
    RefreshMask()
    if HMK.active then SyncPlayerWarmaskEffect() end   -- mask stayed on: pick up a running buff again
end

local SAVED_VARS_NAME = "WeylandHuntsmansWarmaskTrackerSavedVars"


-- Version 1.0.0 stored settings in the shared "Default" profile, so NA, EU and PTS
-- used the same data. Settings are now stored per megaserver (GetWorldName()).
-- The first time a megaserver is used, copy the old shared settings into it.
-- The old "Default" data stays untouched so other megaservers can migrate too.
local function MigrateSharedSavedVars()
    local raw = _G[SAVED_VARS_NAME]
    if type(raw) ~= "table" then return end

    local world, account = GetWorldName(), GetDisplayName()
    local worldData = raw[world]
    if type(worldData) == "table" and type(worldData[account]) == "table" then return end

    local old = raw["Default"]
    old = type(old) == "table" and old[account] or nil
    old = type(old) == "table" and old["$AccountWide"] or nil
    if type(old) ~= "table" then return end

    raw[world] = type(worldData) == "table" and worldData or {}
    raw[world][account] = { ["$AccountWide"] = DeepCopy(old) }
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON then return end
    EM:UnregisterForEvent(ADDON .. "_Load", EVENT_ADD_ON_LOADED)

    MigrateSharedSavedVars()
    HMK.sv = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, 1, nil, DEFAULTS, GetWorldName())

    -- Discard the unused range preferences saved by previous versions.
    HMK.sv.range = nil

    -- v0.3.2: the old pictures are gone and the timer sits on the icon's bottom edge.
    local mk = HMK.sv.mark
    mk.size = math.max(32, math.min(120, tonumber(mk.size) or DEFAULTS.mark.size))
    mk.recolor = nil
    mk.enabled = nil
    mk.ownOnly = nil -- mark tracking is always restricted to effects cast by this player
    mk.scope = nil -- visibility is fixed: keep the marker shown until the mark ends or its target dies
    if rawget(mk, "soundRepeat") ~= nil then          -- v0.3.8 checkbox -> v0.3.9 interval
        mk.soundInterval = mk.soundRepeat and 1 or 0
        mk.soundRepeat = nil
    end
    if mk.soundInterval ~= 0 and mk.soundInterval ~= 1 and mk.soundInterval ~= 2 then mk.soundInterval = DEFAULTS.mark.soundInterval end
    if not HasId(SOUND_CANDIDATES, mk.sound) then mk.sound = DEFAULTS.mark.sound end   -- old sounds were removed
    if not HasId(ICONS, mk.icon) then mk.icon = DEFAULTS.mark.icon end
    if (rawget(HMK.sv, "layoutVersion") or 0) < 2 then
        mk.timerMode = "edge"     -- applied once; it can be changed back in the settings
        HMK.sv.layoutVersion = 2
    elseif mk.timerMode == "below" then
        mk.timerMode = "edge"
    end

    CreateUI()
    ApplyMarkStyle()
    BuildMenu()

    SLASH_COMMANDS["/hmark"] = OnSlash
    if not LibAddonMenu2 then
        SLASH_COMMANDS["/hmarkmenu"] = function()
            Msg(T("MISSING_LAM"))
        end
    end

    -- Standby listeners: the only things alive while the mask is NOT worn.
    EM:RegisterForEvent(ADDON .. "_Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)
    EM:AddFilterForEvent(ADDON .. "_Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_WORN,
        REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    EM:RegisterForEvent(ADDON .. "_Full", EVENT_INVENTORY_FULL_UPDATE, OnSlotUpdate)
    EM:RegisterForEvent(ADDON .. "_Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EM:RegisterForEvent(ADDON .. "_Deactivated", EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)
end

EM:RegisterForEvent(ADDON .. "_Load", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
