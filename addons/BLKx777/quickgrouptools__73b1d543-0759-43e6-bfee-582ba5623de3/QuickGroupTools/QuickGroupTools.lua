local ADDON = "QuickGroupTools"
local TITLE = "Quick Group Tools"
local DEFAULTS = { instanceEnabled = true, groupEnabled = true }
local saved

local function LeaveInstance()
    if not saved.instanceEnabled then return end
    if type(CanExitInstanceImmediately) == "function" and not CanExitInstanceImmediately() then return end
    ExitInstanceImmediately()
end

local function LeaveGroup()
    if not saved.groupEnabled or not IsUnitGrouped("player") then return end
    GroupLeave()
end

local function CreateSettings()
    local lib = LibHarvensAddonSettings
    local panel = lib:AddAddon(TITLE)
    if not panel then return end
    panel:AddSetting({
        type = lib.ST_CHECKBOX,
        label = "Enable Leave Instance",
        tooltip = "Immediately requests an instance exit when selected. Turning this off blocks the action without changing its wheel assignment.",
        default = true,
        getFunction = function() return saved.instanceEnabled end,
        setFunction = function(value) saved.instanceEnabled = value == true end,
    })
    panel:AddSetting({
        type = lib.ST_CHECKBOX,
        label = "Enable Leave Group",
        tooltip = "Immediately leaves the current group when selected. Turning this off blocks the action without changing its wheel assignment.",
        default = true,
        getFunction = function() return saved.groupEnabled end,
        setFunction = function(value) saved.groupEnabled = value == true end,
    })
    panel:AddSetting({
        type = lib.ST_SECTION,
        label = "Quickslot positions",
    })
    panel:AddSetting({
        type = lib.ST_LABEL,
        label = "Open Add-Ons > Lib Radial Menu > Assign Slots. Set Number of Slots to 8 and Wheel Location above 0. Assign Quick Group Tools actions to any free position. Suggested: Leave Instance at S, Leave Group at SE. Unassign an action there to remove its icon.",
    })
end

local function OnLoaded(_, addonName)
    if addonName ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    saved = ZO_SavedVars:NewAccountWide("QuickGroupToolsSavedVariables", 1, nil, DEFAULTS)
    LibRadialMenu:RegisterAddon(ADDON, TITLE)
    LibRadialMenu:RegisterEntry(ADDON, "Leave Instance", "leaveInstance", "QuickGroupTools/icons/leave_instance.dds", LeaveInstance, "Immediately request an instance exit without leaving the group.")
    LibRadialMenu:RegisterEntry(ADDON, "Leave Group", "leaveGroup", "QuickGroupTools/icons/leave_group.dds", LeaveGroup, "Immediately leave your current group.")
    CreateSettings()
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnLoaded)
