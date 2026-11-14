-- KelaPadUI gamepad group rally-point control.
-- Adds a keybind to the gamepad world map so a group leader can set or remove
-- the group rally point at the map cursor. The keybind group is active for the
-- whole map scene, so it also remains available while the map options are open.

local KELA_MAP_RALLY_KEYBINDS = nil
local KELA_MAP_RALLY_KEYBINDS_SHOWN = false
local KELA_MAP_RALLY_TOLERANCE = 0.005

function KelaMapRally_GetCursorNormalizedPosition()
    local x, y = ZO_WorldMapScroll:GetCenter()
    return NormalizePointToControl(x, y, ZO_WorldMapContainer)
end

function KelaMapRally_IsAtRallyPoint(x, y)
    local rallyX, rallyY = GetMapRallyPoint()
    if not rallyX or not rallyY then
        return false
    end
    if rallyX == 0 and rallyY == 0 then
        return false
    end
    return math.abs(rallyX - x) <= KELA_MAP_RALLY_TOLERANCE and math.abs(rallyY - y) <= KELA_MAP_RALLY_TOLERANCE
end

function KelaMapRally_IsVisible()
    return IsUnitGrouped("player") and IsUnitGroupLeader("player") and GetMapType() ~= MAPTYPE_COSMIC
end

function KelaMapRally_GetLabel()
    local x, y = KelaMapRally_GetCursorNormalizedPosition()
    if x and y and KelaMapRally_IsAtRallyPoint(x, y) then
        return GetString(SI_WORLD_MAP_ACTION_REMOVE_RALLY_POINT)
    end
    return GetString(SI_TOOLTIP_UNIT_MAP_RALLY_POINT)
end

function KelaMapRally_Toggle()
    if not KelaMapRally_IsVisible() then
        return
    end

    local x, y = KelaMapRally_GetCursorNormalizedPosition()
    if not x or not y or not ZO_WorldMap_IsNormalizedPointInsideMapBounds(x, y) then
        return
    end

    if KelaMapRally_IsAtRallyPoint(x, y) then
        RemoveRallyPoint()
    else
        PingMap(MAP_PIN_TYPE_RALLY_POINT, MAP_TYPE_LOCATION_CENTERED, x, y)
    end

    if KELA_MAP_RALLY_KEYBINDS then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(KELA_MAP_RALLY_KEYBINDS)
    end
end

function KelaMapRally_ShowKeybind()
    if not KELA_MAP_RALLY_KEYBINDS then
        KELA_MAP_RALLY_KEYBINDS =
        {
            alignment = KEYBIND_STRIP_ALIGN_CENTER,
            {
                name = KelaMapRally_GetLabel,
                -- UI_SHORTCUT_QUINARY is free on the world map. For a hold
                -- binding, use "UI_SHORTCUT_RIGHT_STICK" with handlesKeyUp = true.
                keybind = "UI_SHORTCUT_QUINARY",
                visible = KelaMapRally_IsVisible,
                callback = KelaMapRally_Toggle,
                sound = SOUNDS.GAMEPAD_MENU_FORWARD,
            },
        }
    end

    if not KELA_MAP_RALLY_KEYBINDS_SHOWN then
        KEYBIND_STRIP:AddKeybindButtonGroup(KELA_MAP_RALLY_KEYBINDS)
        KELA_MAP_RALLY_KEYBINDS_SHOWN = true
    end
end

function KelaMapRally_HideKeybind()
    if KELA_MAP_RALLY_KEYBINDS and KELA_MAP_RALLY_KEYBINDS_SHOWN then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(KELA_MAP_RALLY_KEYBINDS)
        KELA_MAP_RALLY_KEYBINDS_SHOWN = false
    end
end

function KelaSetupMapRally()
    if KelaPadUI.KelaMapRallyInitialized then
        return
    end

    if not GAMEPAD_WORLD_MAP_SCENE then
        zo_callLater(KelaSetupMapRally, 1000)
        return
    end

    KelaPadUI.KelaMapRallyInitialized = true

    GAMEPAD_WORLD_MAP_SCENE:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            KelaMapRally_ShowKeybind()
        elseif newState == SCENE_HIDING then
            KelaMapRally_HideKeybind()
        end
    end)

    if GAMEPAD_WORLD_MAP_SCENE:IsShowing() then
        KelaMapRally_ShowKeybind()
    end
end
