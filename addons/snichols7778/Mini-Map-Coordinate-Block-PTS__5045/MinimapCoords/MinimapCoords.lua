--[[
  MinimapCoords
  Coordinate readout that anchors to the built-in ESO minimap (PTS).
]]

MinimapCoords = MinimapCoords or {}

local ADDON_NAME = "MinimapCoords"
local UPDATE_INTERVAL_MS = 100

-- PTS built-in minimap top-level is ZO_Minimap_TopLevel.
local ANCHOR_CANDIDATES = {
    "ZO_Minimap_TopLevel",
    "ZO_Minimap",
    "ZO_MinimapFrame",
    "ZO_MinimapContainer",
    "ZO_WorldMapMinimap",
    "ZO_WorldMapMinimapFrame",
    "ZO_WorldMapMinimapContainer",
    "ZO_HUDMinimap",
    "ZO_HUDMinimapFrame",
    "ZO_HUDMinimapContainer",
    "ZO_AccessibleMinimap",
    "ZO_CompassMinimap",
    "ZO_CompassFrame",
}

local defaults = {
    enabled = true,
    decimals = 2,
    offsetX = 0,
    offsetY = 2,
    font = "$(BOLD_FONT)|$(KB_18)|soft-shadow-thin",
    color = { r = 0.9, g = 0.92, b = 0.95, a = 1 },
    anchorPoint = BOTTOM,
    relativePoint = TOP,
    lockedParentName = "ZO_Minimap_TopLevel",
}

local sv
local root
local label
local anchoredTo
local updateHandle

local function Notify(message)
    CHAT_ROUTER:AddSystemMessage(string.format("[%s] %s", ADDON_NAME, message))
end

local function FormatCoords(x, y)
    local decimals = sv.decimals or 2
    local fmt = "%." .. tostring(decimals) .. "f, %." .. tostring(decimals) .. "f"
    return string.format(fmt, x * 100, y * 100)
end

local function GetControlByName(name)
    if not name or name == "" then
        return nil
    end
    return GetControl(name) or _G[name]
end

local function IsOwnControl(control)
    if not control or not control.GetName then
        return false
    end
    local name = control:GetName() or ""
    return name == ADDON_NAME
        or name:sub(1, #ADDON_NAME + 1) == (ADDON_NAME .. "_")
end

local function ControlLooksLikeMinimap(control)
    if not control or not control.GetName or IsOwnControl(control) then
        return false
    end
    local name = string.lower(control:GetName() or "")
    return name:find("minimap", 1, true) ~= nil
end

local function FindMinimapControl()
    if sv.lockedParentName and sv.lockedParentName:sub(1, #ADDON_NAME) ~= ADDON_NAME then
        local locked = GetControlByName(sv.lockedParentName)
        if locked and not IsOwnControl(locked) then
            return locked
        end
    end

    for i = 1, #ANCHOR_CANDIDATES do
        local control = GetControlByName(ANCHOR_CANDIDATES[i])
        if control and not IsOwnControl(control) then
            return control
        end
    end

    -- Scan GuiRoot for anything named like a minimap (covers renamed PTS controls).
    if GuiRoot and GuiRoot.GetNumChildren then
        local count = GuiRoot:GetNumChildren()
        for i = 1, count do
            local child = GuiRoot:GetChild(i)
            if ControlLooksLikeMinimap(child) then
                return child
            end
        end
    end

    return nil
end

local function EnsureControls()
    if root then
        return
    end

    root = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "_Root")
    root:SetMovable(false)
    root:SetMouseEnabled(false)
    root:SetClampedToScreen(true)
    root:SetHidden(false)
    root:SetResizeToFitDescendents(true)
    root:SetDimensions(160, 28)

    label = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "_Label", root, CT_LABEL)
    label:SetAnchor(CENTER, root, CENTER, 0, 0)
    label:SetFont(sv.font or defaults.font)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(sv.color.r, sv.color.g, sv.color.b, sv.color.a)
    label:SetText("—, —")
end

local function ApplyStyle()
    if not label then
        return
    end
    label:SetFont(sv.font or defaults.font)
    label:SetColor(sv.color.r, sv.color.g, sv.color.b, sv.color.a)
end

local function AnchorToMinimap(force)
    EnsureControls()

    local parent = FindMinimapControl()
    if not parent then
        root:ClearAnchors()
        root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 20, 80)
        anchoredTo = nil
        return false
    end

    if not force and anchoredTo == parent then
        return true
    end

    root:ClearAnchors()
    root:SetAnchor(
        sv.anchorPoint or BOTTOM,
        parent,
        sv.relativePoint or TOP,
        sv.offsetX or 0,
        sv.offsetY or 2
    )

    anchoredTo = parent
    if not sv.lockedParentName then
        sv.lockedParentName = parent:GetName()
    end
    return true
end

local function RefreshCoords()
    if not sv.enabled then
        if root then
            root:SetHidden(true)
        end
        return
    end

    EnsureControls()
    AnchorToMinimap(false)

    local parent = anchoredTo
    local parentHidden = parent and parent.IsHidden and parent:IsHidden()
    root:SetHidden(parentHidden == true)

    if root:IsHidden() then
        return
    end

    local x, y = GetMapPlayerPosition("player")
    if not x or not y then
        label:SetText("—, —")
        return
    end

    label:SetText(FormatCoords(x, y))
end

local function StartUpdates()
    if updateHandle then
        return
    end
    updateHandle = true
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_Update", UPDATE_INTERVAL_MS, RefreshCoords)
end

local function StopUpdates()
    if not updateHandle then
        return
    end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_Update")
    updateHandle = nil
end

local function SetEnabled(enabled)
    sv.enabled = enabled and true or false
    if sv.enabled then
        StartUpdates()
        RefreshCoords()
        Notify("enabled")
    else
        StopUpdates()
        if root then
            root:SetHidden(true)
        end
        Notify("disabled")
    end
end

local function PrintStatus()
    local parentName = anchoredTo and anchoredTo:GetName() or (sv.lockedParentName or "none")
    Notify(string.format(
        "parent=%s  enabled=%s  decimals=%d  offset=%d,%d",
        parentName,
        tostring(sv.enabled),
        sv.decimals or 2,
        sv.offsetX or 0,
        sv.offsetY or 0
    ))
end

local function DumpMinimapCandidates()
    Notify("Scanning for minimap-like controls…")
    local found = 0

    for i = 1, #ANCHOR_CANDIDATES do
        local name = ANCHOR_CANDIDATES[i]
        if GetControlByName(name) then
            found = found + 1
            Notify("candidate: " .. name)
        end
    end

    if GuiRoot and GuiRoot.GetNumChildren then
        local count = GuiRoot:GetNumChildren()
        for i = 1, count do
            local child = GuiRoot:GetChild(i)
            if ControlLooksLikeMinimap(child) then
                found = found + 1
                Notify("gui: " .. child:GetName())
            end
        end
    end

    if found == 0 then
        Notify("No minimap controls found yet. Open the minimap HUD, then run /mmc scan again.")
    end
end

local function HandleSlash(args)
    args = string.lower(string.gsub(args or "", "^%s+", ""))
    local cmd, rest = args:match("^(%S+)%s*(.*)$")
    cmd = cmd or "status"

    if cmd == "on" or cmd == "enable" then
        SetEnabled(true)
    elseif cmd == "off" or cmd == "disable" then
        SetEnabled(false)
    elseif cmd == "toggle" then
        SetEnabled(not sv.enabled)
    elseif cmd == "scan" then
        DumpMinimapCandidates()
    elseif cmd == "reattach" or cmd == "attach" then
        sv.lockedParentName = nil
        anchoredTo = nil
        if AnchorToMinimap(true) then
            Notify("attached to " .. (anchoredTo:GetName() or "?"))
        else
            Notify("could not find minimap control; using temporary corner position")
        end
        RefreshCoords()
    elseif cmd == "parent" and rest ~= "" then
        local control = GetControlByName(rest)
        if not control then
            Notify("control not found: " .. rest)
            return
        end
        sv.lockedParentName = control:GetName()
        anchoredTo = nil
        AnchorToMinimap(true)
        RefreshCoords()
        Notify("locked parent to " .. sv.lockedParentName)
    elseif cmd == "decimals" then
        local n = tonumber(rest)
        if not n or n < 0 or n > 4 then
            Notify("usage: /mmc decimals 0-4")
            return
        end
        sv.decimals = math.floor(n)
        RefreshCoords()
        Notify("decimals = " .. sv.decimals)
    elseif cmd == "offset" then
        local x, y = rest:match("^(%-?%d+)%s+(%-?%d+)$")
        if not x then
            Notify("usage: /mmc offset <x> <y>")
            return
        end
        sv.offsetX = tonumber(x)
        sv.offsetY = tonumber(y)
        AnchorToMinimap(true)
        RefreshCoords()
        Notify(string.format("offset = %d, %d", sv.offsetX, sv.offsetY))
    elseif cmd == "help" then
        Notify("/mmc on|off|toggle|status|scan|reattach|parent <Name>|decimals <n>|offset <x> <y>")
    else
        PrintStatus()
    end
end

local function OnPlayerActivated()
    EnsureControls()
    ApplyStyle()
    AnchorToMinimap(true)
    if sv.enabled then
        StartUpdates()
        RefreshCoords()
    end
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON_NAME then
        return
    end

    -- v4: larger coordinate font.
    sv = ZO_SavedVars:NewAccountWide("MinimapCoords_SavedVariables", 4, nil, defaults)
    SLASH_COMMANDS["/mmc"] = HandleSlash
    SLASH_COMMANDS["/minimapcoords"] = HandleSlash

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
