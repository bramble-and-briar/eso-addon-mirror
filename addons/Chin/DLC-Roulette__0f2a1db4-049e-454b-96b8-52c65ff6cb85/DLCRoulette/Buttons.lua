-- DLC Roulette. Copyright (c) 2026 -chin. All rights reserved: no copying, sharing, changes or reuse.
-- Buttons: two entries added to the gamepad Dungeon Finder's button strip, so they show on its first page and
-- on the Random and Specific lists alike. Triangle (Y) queues Veteran, L3 Normal. The game uses Triangle there
-- only in Battlegrounds and Tales of Tribute, and L3 not at all.
local DR = DLCRoulette
local L = DR.L
local Buttons = {}
DR.Buttons = Buttons

local function Button(name, keybind, activityType)
    return {
        name = name,
        keybind = keybind,
        callback = function() DR.Dungeons.Queue(activityType) end,
        visible = DR.Dungeons.CanQueue,
    }
end

function Buttons.Init()
    local descriptor = DUNGEON_FINDER_GAMEPAD and DUNGEON_FINDER_GAMEPAD.keybindStripDescriptor
    if not descriptor then
        return
    end
    table.insert(descriptor, Button(L.BUTTON_VET, "UI_SHORTCUT_TERTIARY", LFG_ACTIVITY_MASTER_DUNGEON))
    table.insert(descriptor, Button(L.BUTTON_NORMAL, "UI_SHORTCUT_LEFT_STICK", LFG_ACTIVITY_DUNGEON))
end
