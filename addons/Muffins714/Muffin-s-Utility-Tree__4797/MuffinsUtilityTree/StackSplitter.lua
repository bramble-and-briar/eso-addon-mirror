-- Create a local shortcut for global
local MUT = MuffinsUtilityTree
--TODO Add a timer to prevent booted from server
---------------------------------------------------------------------------------------------
-- Multi Split
---------------------------------------------------------------------------------------------
-- StackSplitterDialog.xml creates the control
local MUT_MULTI_SPLIT_DIALOG = "MUT_GAMEPAD_MULTI_SPLIT"

local multiSplitSelector = nil

-- Single split
local function ExecuteSingleSplit(bagId, slotIndex, splitSize)
    if not splitSize or splitSize <= 0 then return end

    local startingStackSize = GetSlotStackSize(bagId, slotIndex)
    if not startingStackSize or startingStackSize <= splitSize then return end

    -- Find exactly one empty slot to hold the new stack
    local destSlot = nil
    for i = 0, GetBagSize(bagId) - 1 do
        if i ~= slotIndex and not GetItemInstanceId(bagId, i) then
            destSlot = i
            break
        end
    end

    if not destSlot then
        local errorStringId = (bagId == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL or
            SI_INVENTORY_ERROR_BANK_FULL
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, errorStringId)
        return
    end

    CallSecureProtected("PickupInventoryItem", bagId, slotIndex, splitSize)
    CallSecureProtected("PlaceInInventory", bagId, destSlot)
end

-- Split stack into multiple
local function ExecuteSingleStackMultiSplit(bagId, slotIndex, splitSize)
    if not splitSize or splitSize <= 0 then return end

    local startingStackSize = GetSlotStackSize(bagId, slotIndex)
    if not startingStackSize or startingStackSize <= splitSize then return end
    local numSplits = 1
    -- Compute splits
    numSplits = zo_floor(startingStackSize / splitSize)
    -- Leave at least 1 item in the original stack
    if startingStackSize % splitSize == 0 then
        numSplits = numSplits - 1
    end

    -- Reserve empty slots first so each split goes to a different slot
    local destSlots = {}
    for i = 0, GetBagSize(bagId) - 1 do
        if #destSlots >= numSplits then break end
        if i ~= slotIndex and not GetItemInstanceId(bagId, i) then
            destSlots[#destSlots + 1] = i
        end
    end
    if #destSlots < numSplits then
        d(string.format(GetString(MUT_MULTI_SPLITTER_ERROR),
            #destSlots, numSplits))
        numSplits = #destSlots
    end

    for i = 1, numSplits do
        CallSecureProtected("PickupInventoryItem", bagId, slotIndex, splitSize)
        CallSecureProtected("PlaceInInventory", bagId, destSlots[i])
    end
end

-- Split multiple stacks of the same item into multiple
local function ExecuteAllStacksMultiSplit(bagId, slotIndex, splitSize)
    if not splitSize or splitSize <= 0 then return end

    local itemId = GetItemId(bagId, slotIndex)
    if not itemId or itemId == 0 then return end

    local numBagSlots = GetBagSize(bagId)

    -- Find every stack of this same item in the bag
    local sourceStacks = {}
    local emptySlots = {}

    for i = 0, numBagSlots - 1 do
        if not GetItemInstanceId(bagId, i) then
            emptySlots[#emptySlots + 1] = i
        elseif GetItemId(bagId, i) == itemId then
            local size = GetSlotStackSize(bagId, i)
            if size and size > splitSize then
                sourceStacks[#sourceStacks + 1] = { slotIndex = i, stackSize = size }
            end
        end
    end

    if #sourceStacks == 0 then return end

    -- Figure out total splits needed first so we can trim once before touching any items
    local totalSplitsNeeded = 0
    for _, stack in ipairs(sourceStacks) do
        local numSplits = zo_floor(stack.stackSize / splitSize)
        if stack.stackSize % splitSize == 0 then
            numSplits = numSplits - 1
        end
        stack.numSplits = numSplits
        totalSplitsNeeded = totalSplitsNeeded + numSplits
    end

    if #emptySlots < totalSplitsNeeded then
        d(string.format(GetString(MUT_MULTI_SPLITTER_ERROR),
            #emptySlots, totalSplitsNeeded))
    end

    local destSlotActive = 1
    for _, stack in ipairs(sourceStacks) do
        for i = 1, stack.numSplits do
            if destSlotActive > #emptySlots then break end
            CallSecureProtected("PickupInventoryItem", bagId, stack.slotIndex, splitSize)
            CallSecureProtected("PlaceInInventory", bagId, emptySlots[destSlotActive])
            destSlotActive = destSlotActive + 1
        end
    end
end

function MUT.MultiSplitDialog_Gamepad_OnInitialized(self)
    ZO_GenericGamepadDialog_OnInitialized(self)

    local selectorControl = self:GetNamedChild("Selector")
    if not selectorControl then
        return
    end

    multiSplitSelector = ZO_CurrencySelector_Gamepad:New(selectorControl)
    -- Currency type is only used to keep narration safe but this isnt money
    multiSplitSelector:SetCurrencyType(CURT_MONEY)
    multiSplitSelector:SetClampValues(true)

    -- Real split cap changes per item, clamp manually because display max stays 199
    local currentItemMaxSplitSize = 199
    local isClampingValue = false

    multiSplitSelector:RegisterCallback("OnValueChanged", function()
        if isClampingValue then return end
        local value = multiSplitSelector:GetValue()
        if value > currentItemMaxSplitSize then
            isClampingValue = true
            multiSplitSelector:SetValue(currentItemMaxSplitSize)
            isClampingValue = false
        end
    end)

    ZO_Dialogs_RegisterCustomDialog(MUT_MULTI_SPLIT_DIALOG,
        {
            customControl = self,
            canQueue = true,
            gamepadInfo =
            {
                dialogType = GAMEPAD_DIALOGS.CUSTOM,
            },
            setup = function(dialog, data)
                -- Fixed max keeps the selector at 3 digits for every item because we only get 200 stack size
                multiSplitSelector:SetMaxValue(199)
                currentItemMaxSplitSize = data.sliderMax
                multiSplitSelector:SetValue(data.sliderStartValue)
                multiSplitSelector:Activate()
                dialog:setupFunc()
            end,
            finishedCallback = function(dialog)
                multiSplitSelector:Deactivate()
            end,
            title =
            {
                text = MUT_MULTI_SPLITTER_TITLE,
            },
            mainText =
            {
                text = MUT_MULTI_SPLITTER_PROMPT,
            },
            buttons =
            {
                {
                    keybind = "DIALOG_NEGATIVE",
                    text = GetString(SI_DIALOG_CANCEL),
                },
                {
                    keybind = "DIALOG_PRIMARY",
                    -- text = GetString(SI_GAMEPAD_SELECT_OPTION),
                    name = "Split Once",
                    callback = function(dialog)
                        local dialogData = dialog.data
                        local splitSize = multiSplitSelector:GetValue()
                        ExecuteSingleSplit(dialogData.bagId, dialogData.slotIndex, splitSize)
                    end,
                },
                {
                    -- keybind = "UI_SHORTCUT_QUATERNARY",
                    keybind = "DIALOG_SECONDARY",
                    name = "Multi Split Stack",
                    callback = function(dialog)
                        local dialogData = dialog.data
                        local splitSize = multiSplitSelector:GetValue()

                        ExecuteSingleStackMultiSplit(dialogData.bagId, dialogData.slotIndex, splitSize)
                    end,
                },
                {
                    -- keybind = "UI_SHORTCUT_TERTIARY",
                    keybind = "DIALOG_TERTIARY",
                    name = "Multi Split All Stacks",
                    callback = function(dialog)
                        local dialogData = dialog.data
                        local splitSize = multiSplitSelector:GetValue()

                        ExecuteAllStacksMultiSplit(dialogData.bagId, dialogData.slotIndex, splitSize)
                    end,
                },
            }
        })
end

---------------------------------------------------------------------------------------------
-- Slot action hook
---------------------------------------------------------------------------------------------
-- Adds the Multi Split action after the game's normal item actions
local function OnDiscoverSlotActions(inventorySlot, slotActions)
    if not IsInGamepadPreferredMode() then return end

    local settings = MUT.GetSettings()
    if not settings.splitterEnabled then return end

    if not ZO_InventorySlot_IsSplittableType(inventorySlot) then return end
    if not ZO_InventorySlot_CanSplitItemStack(inventorySlot) then return end

    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    local stackSize = GetSlotStackSize(bagId, slotIndex)
    if not stackSize or stackSize <= 1 then return end

    slotActions:AddSlotAction(
        MUT_MULTI_SPLITTER_ACTION_NAME,
        function()
            ZO_Dialogs_ShowGamepadDialog(MUT_MULTI_SPLIT_DIALOG, {
                bagId = bagId,
                slotIndex = slotIndex,
                stackSize = stackSize,
                -- Cap at stack at -1 and 199, start at 0 so the player picks the size
                sliderMax = zo_min(stackSize - 1, 199),
                sliderStartValue = 0,
            })
        end,
        "secondary"
    )
end

---------------------------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------------------------
function MUT.Initialize_MultiSplitter()
    SecurePostHook("ZO_InventorySlot_DiscoverSlotActionsFromActionList", OnDiscoverSlotActions)
end
