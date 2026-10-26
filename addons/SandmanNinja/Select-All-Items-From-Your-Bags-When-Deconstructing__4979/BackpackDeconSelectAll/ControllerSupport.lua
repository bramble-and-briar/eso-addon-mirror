-- Native controller Options checkbox. Uses ESO's layout and input navigation.
local A = BackpackDeconSelectAll
local WARNING = "Select All?  WARNING! THIS WILL SELECT EVERYTHING THAT IS NOT LOCKED!"
local panels = {}
local changing = false
local hooked = false

function A.ResetController()
    for _, state in pairs(panels) do state.filter.checked = false end
end

local function Attach(panel, universal, scene)
    if not panel or panels[panel] then return end
    local state = {
        universal = universal,
        scene = scene,
        filter = {
            filterName = "Select All?  (v" .. A.version .. ")",
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

function A.InitializeController()
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
                            A.Select(panel, state.universal, function(checked)
                                state.filter.checked = checked
                            end)
                        else
                            panel:ClearSelections()
                            state.filter.checked = false
                        end
                        changing = false
                    else
                        -- SaveFilters refreshes the panel even without a user change.
                        -- Restore the tick only if every eligible item is still selected.
                        state.filter.checked = requested and A.IsSelectionComplete(panel, state.universal)
                    end
                end
                break
            end
        end
        -- A pre-hook must never consume ESO's ShowOptionsDialog call.
        return false
    end)
end

-- All event registration lives in the main file's single startup handler.
