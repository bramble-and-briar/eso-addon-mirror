local NAME = "BackpackDeconSelectAll"
local WARNING = "Select All?  WARNING! THIS WILL SELECT EVERYTHING THAT IS NOT LOCKED!"
local checkboxes = {}
local changing = false
BackpackDeconSelectAll = {}

local function Reset()
    for _, checkbox in pairs(checkboxes) do
        ZO_CheckButton_SetCheckState(checkbox, false)
    end
    CALLBACK_MANAGER:FireCallbacks(NAME .. "Reset")
end

local function IsProtected(bag, slot)
    if IsItemPlayerLocked(bag, slot) then return true end
    if FCOIS and FCOIS.IsDeconstructionLocked then
        return FCOIS.IsDeconstructionLocked(bag, slot)
    end
    return false
end

local function SelectBackpack(panel, setChecked, universal)
    if changing or ZO_CraftingUtils_IsPerformingCraftProcess() then
        Reset()
        setChecked(false)
        return
    end
    changing = true
    panel:ClearSelections()
    local eligible, selected = 0, 0
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local canDeconstruct
        if universal then
            local craftingTypes
            if panel.GetSavedCraftingTypeFilters then
                craftingTypes = panel:GetSavedCraftingTypeFilters()
            else
                craftingTypes = panel:GetSelectedCraftingTypeFilters()
            end
            canDeconstruct = ZO_UniversalDeconstructionPanel_Shared.IsDeconstructableBagItem(
                BAG_BACKPACK, slot, craftingTypes)
                and ZO_UniversalDeconstructionPanel_Shared.DoesItemPassFilter(BAG_BACKPACK, slot, nil)
        else
            canDeconstruct = CanItemBeDeconstructed(BAG_BACKPACK, slot, GetCraftingInteractionType())
        end
        if canDeconstruct and not IsProtected(BAG_BACKPACK, slot) then
            eligible = eligible + 1
            local extraction = panel.extractionSlot
            local quantity = math.max(1, panel.inventory:GetStackCount(BAG_BACKPACK, slot))
            if extraction:GetNumItems() < MAX_ITEM_SLOTS_PER_DECONSTRUCTION
                and (not extraction:HasItems()
                    or extraction:GetStackCount() + quantity <= MAX_ITERATIONS_PER_DECONSTRUCTION)
                and panel:CanItemBeAddedToCraft(BAG_BACKPACK, slot) then
                panel:AddItemToCraft(BAG_BACKPACK, slot)
                if panel:IsSlotted(BAG_BACKPACK, slot) then
                    selected = selected + 1
                end
            end
        end
    end
    changing = false
    setChecked(eligible > 0 and selected == eligible)
    if selected < eligible then
        d(string.format("Select All: selected %d of %d eligible backpack slots. ESO's selection limits apply; process this batch and tick again.", selected, eligible))
    elseif eligible == 0 then
        d("Select All: no eligible unlocked backpack items at this station.")
    end
end

BackpackDeconSelectAll.Select = function(panel, universal, setChecked)
    SelectBackpack(panel, setChecked, universal)
end

local function Attach(panel, suffix, universal)
    if not panel or checkboxes[panel] then return end
    local inventory = panel.inventory.control
    local divider = inventory:GetNamedChild("ButtonDivider")
    local checkbox = WINDOW_MANAGER:CreateControlFromVirtual(NAME .. suffix .. "Checkbox", inventory, "ZO_CheckButton")
    checkboxes[panel] = checkbox
    checkbox:SetAnchor(TOPLEFT, inventory:GetNamedChild("IncludeBanked"), BOTTOMLEFT, 0, 14)
    ZO_CheckButton_SetLabelText(checkbox, WARNING)
    local label = checkbox:GetNamedChild("Label")
    label:SetFont("ZoFontGameSmall")
    label:SetWidth(480)
    label:SetHeight(48)
    label:SetColor(1, 0.65, 0.2, 1)
    if divider then
        divider:ClearAnchors()
        divider:SetAnchor(TOPLEFT, checkbox, BOTTOMLEFT, -30, 40)
    end
    ZO_CheckButton_SetToggleFunction(checkbox, function()
        if ZO_CheckButton_IsChecked(checkbox) then
            SelectBackpack(panel, function(checked)
                ZO_CheckButton_SetCheckState(checkbox, checked)
            end, universal)
        elseif not ZO_CraftingUtils_IsPerformingCraftProcess() then
            panel:ClearSelections()
        end
    end)
    ZO_CraftingUtils_ConnectCheckBoxToCraftingProcess(checkbox)
    ZO_PostHook(panel, "OnSlotChanged", function()
        if not changing then Reset() end
    end)
    if panel.SetHidden then ZO_PostHook(panel, "SetHidden", Reset) end
    if panel.OnShown then ZO_PostHook(panel, "OnShown", Reset) end
    ZO_PostHook(panel.inventory, "ChangeFilter", Reset)
    Reset()
end

local function Initialize()
    Attach(SMITHING and SMITHING.deconstructionPanel, "Smithing", false)
    Attach(UNIVERSAL_DECONSTRUCTION and UNIVERSAL_DECONSTRUCTION.deconstructionPanel, "Universal", true)
end

local function RegisterEvents()
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_CRAFTING_STATION_INTERACT, function()
        Initialize()
        Reset()
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_END_CRAFTING_STATION_INTERACT, Reset)
    CALLBACK_MANAGER:RegisterCallback("CraftingAnimationsStarted", Reset)
    Reset()
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    Initialize()
    RegisterEvents()
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, Initialize)
end)
