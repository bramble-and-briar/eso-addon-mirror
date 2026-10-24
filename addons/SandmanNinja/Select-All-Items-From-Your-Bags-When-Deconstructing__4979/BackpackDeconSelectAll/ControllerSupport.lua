-- Native controller Options checkbox. Uses ESO's layout and input navigation.
local NAME = "BackpackDeconSelectAllController"
local WARNING = "Select All?  WARNING! THIS WILL SELECT EVERYTHING THAT IS NOT LOCKED!"
local panels = {}
local changing = false
local hooked = false

local function Reset()
    for _, state in pairs(panels) do state.filter.checked = false end
end

local function Attach(panel, universal, scene)
    if not panel or panels[panel] then return end
    local state = {
        universal = universal,
        scene = scene,
        filter = {
            filterName = "Select All?",
            filterTooltip = WARNING .. "\n\nSelects eligible unlocked backpack items when you close Options. Untick to clear selections. Banked and equipped items are excluded. You still confirm deconstruction yourself.",
            checked = false,
        },
    }
    panels[panel] = state
    local function ResetPanel()
        if not changing then state.filter.checked = false end
    end
    ZO_PostHook(panel, "OnSlotChanged", ResetPanel)
    ZO_PostHook(panel, "ClearSelections", ResetPanel)
    ZO_PostHook(panel, "SetFilterType", ResetPanel)
    if scene then
        scene:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING or newState == SCENE_HIDDEN then ResetPanel() end
        end)
    end
end

local function Initialize()
    Attach(SMITHING_GAMEPAD and SMITHING_GAMEPAD.deconstructionPanel, false, GAMEPAD_SMITHING_DECONSTRUCT_SCENE)
    Attach(UNIVERSAL_DECONSTRUCTION_GAMEPAD and UNIVERSAL_DECONSTRUCTION_GAMEPAD.deconstructionPanel,
        true, UNIVERSAL_DECONSTRUCTION_GAMEPAD_SCENE)
    if hooked or not ZO_CraftingOptionsDialogGamepad then return end
    hooked = true
    ZO_PreHook(ZO_CraftingOptionsDialogGamepad, "ShowOptionsDialog", function(_, dialogData)
        if not IsInGamepadPreferredMode() then return end
        for panel, state in pairs(panels) do
            if dialogData.itemActions == panel.itemActions and state.scene and state.scene:IsShowing() then
                -- Copy only the array so ESO's original filter objects still save normally.
                local filters = {}
                for _, filter in ipairs(dialogData.filters or {}) do filters[#filters + 1] = filter end
                filters[#filters + 1] = state.filter
                dialogData.filters = filters
                local initiallyChecked = state.filter.checked
                local finished = dialogData.finishedCallback
                dialogData.finishedCallback = function(dialog)
                    local requested = state.filter.checked
                    -- ESO must apply crafting-type/bank filters before we build a selection.
                    if finished then finished(dialog) end
                    if not IsInGamepadPreferredMode() or not state.scene:IsShowing()
                        or ZO_CraftingUtils_IsPerformingCraftProcess() then
                        state.filter.checked = false
                        return
                    end
                    if requested ~= initiallyChecked then
                        changing = true
                        if requested then
                            BackpackDeconSelectAll.Select(panel, state.universal, function(checked)
                                state.filter.checked = checked
                            end)
                        else
                            panel:ClearSelections()
                            state.filter.checked = false
                        end
                        changing = false
                    end
                end
                break
            end
        end
        -- A pre-hook must never consume ESO's ShowOptionsDialog call.
        return false
    end)
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= "BackpackDeconSelectAll" then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    Initialize()
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, Initialize)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_CRAFTING_STATION_INTERACT, function() Initialize() Reset() end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_END_CRAFTING_STATION_INTERACT, Reset)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, Reset)
    CALLBACK_MANAGER:RegisterCallback("BackpackDeconSelectAllReset", Reset)
    CALLBACK_MANAGER:RegisterCallback("CraftingAnimationsStarted", Reset)
end)
