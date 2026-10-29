local appName = "AutoImproveGear"

local keybindActive = false
local initialized = false
local keybindDescriptor

--selection screen state
local selectionItems = {}
local selectionScreen
local selectionFragment
local selectionControl
local selectionKeybindStateIndex
local restoreAutoImproveKeybind

--equipment names for each crafting station
local equipmentTypes = {
    [CRAFTING_TYPE_BLACKSMITHING] = {
        "cuirass", "sabatons", "gauntlets", "helm",
        "greaves", "pauldron", "girdle", "axe",
        "mace", "sword", "battle axe", "maul",
        "greatsword", "dagger",
    },
    [CRAFTING_TYPE_CLOTHIER] = {
        "robe", "shirt", "shoes", "gloves", "hat",
        "breeches", "epaulets", "sash", "jack",
        "boots", "bracers", "helmet", "guards",
        "arm cops", "belt",
    },
    [CRAFTING_TYPE_WOODWORKING] = {
        "shield", "bow", "inferno staff", "ice staff",
        "lightning staff", "restoration staff",
    },
    [CRAFTING_TYPE_JEWELRYCRAFTING] = {
        "ring", "necklace",
    },
}

--print a message to chat
local function printMessage(msg)
    local chat = LibChatMessage(appName, "MA")
    chat:Print(msg)
end

--check whether an item name matches the station list
local function isRelevantItem(itemName, craftingType)
    if not itemName or not equipmentTypes[craftingType] then
        return false
    end

    local lowerName = string.lower(itemName)

    for _, equipmentName in ipairs(equipmentTypes[craftingType]) do
        local startPosition = 1

        while true do
            local first, last = string.find(lowerName, equipmentName, startPosition, true)

            if not first then
                break
            end

            local before = first == 1 and "" or lowerName:sub(first - 1, first - 1)
            local after = last == #lowerName and "" or lowerName:sub(last + 1, last + 1)

            local beforeIsBoundary = before == "" or before:match("[^%a]") ~= nil
            local afterIsBoundary = after == "" or after:match("[^%a]") ~= nil

            if beforeIsBoundary and afterIsBoundary then
                return true
            end

            startPosition = first + 1
        end
    end

    return false
end

--find unlocked matching items in the backpack
local function scanBackpack(craftingType)
    local items = {}

    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if GetSlotStackSize(BAG_BACKPACK, slotIndex) > 0
            and not IsItemPlayerLocked(BAG_BACKPACK, slotIndex) then

            local itemName = GetItemName(BAG_BACKPACK, slotIndex)

            --remove the trailing eso name-format suffix
            if itemName and #itemName >= 2 then
                local suffix = itemName:sub(-2)

                if suffix:sub(1, 1) == "^" then
                    itemName = itemName:sub(1, -3)
                end
            end

            if isRelevantItem(itemName, craftingType) then
                table.insert(items, {
                    slotIndex = slotIndex,
                    itemName = itemName,
                })
            end
        end
    end

    return items
end

--create the custom selection screen class
local AutoImproveGearSelectionScreen = ZO_Gamepad_ParametricList_Screen:Subclass()

function AutoImproveGearSelectionScreen:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = "Select / Deselect",
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                local list = self:GetMainList()
                local entryData = list:GetSelectedData()

                if entryData and entryData.item then
                    entryData.item.selected = not entryData.item.selected
                    self:Update()
                end
            end,
        },
        {
            name = "Confirm Selection",
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function()
                local selectedCount = 0

                for _, item in ipairs(selectionItems) do
                    if item.selected then
                        selectedCount = selectedCount + 1
                        printMessage(item.itemName)
                    end
                end

                if selectedCount == 0 then
                    printMessage("No items selected")
                else
                    printMessage("Confirmed " .. tostring(selectedCount) .. " selected item(s)")
                end
            end,
        },
        {
            name = GetString(SI_GAMEPAD_BACK_OPTION),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function()
                if selectionFragment then
                    SCENE_MANAGER:RemoveFragment(selectionFragment)
                end

                if selectionKeybindStateIndex then
                    KEYBIND_STRIP:RemoveKeybindButtonGroup(
                        selectionScreen.keybindStripDescriptor,
                        selectionKeybindStateIndex
                    )
                    KEYBIND_STRIP:PopKeybindGroupState()
                    selectionKeybindStateIndex = nil
                end

                --restore the auto improve button after returning from the overlay
                if restoreAutoImproveKeybind then
                    restoreAutoImproveKeybind()
                end
            end,
        },
    }
end

function AutoImproveGearSelectionScreen:PerformUpdate()
    local list = self:GetMainList()
    list:Clear()

    local selectedCount = 0

    for _, item in ipairs(selectionItems) do
        local entryName = item.selected and ("[X] " .. item.itemName) or "[ ] " .. item.itemName
        local entryData = ZO_GamepadEntryData:New(entryName)
        entryData.item = item
        list:AddEntry("ZO_GamepadMenuEntryTemplate", entryData)

        if item.selected then
            selectedCount = selectedCount + 1
        end
    end

    list:Commit()

    self.headerData = {
        titleText = "Available Items (" .. tostring(selectedCount) .. " selected)",
    }

    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
    self.dirty = false
end

--create the overlay selection screen
local function createSelectionScreen()
    if selectionScreen then
        return
    end

    selectionControl = WINDOW_MANAGER:CreateControlFromVirtual(
        "AutoImproveGearGamepad",
        GuiRoot,
        "AutoImproveGearGamepadControl"
    )

    --position the list to the right of screen centre
    selectionControl:ClearAnchors()
    selectionControl:SetDimensions(650, 700)
    selectionControl:SetAnchor(CENTER, GuiRoot, CENTER, 250, 0)

    --add a shaded panel behind the list
    local background = WINDOW_MANAGER:CreateControl(
        "AutoImproveGearGamepadBackground",
        selectionControl,
        CT_BACKDROP
    )
    background:SetAnchorFill(selectionControl)
    background:SetDrawLayer(DL_BACKGROUND)
    background:SetCenterColor(0, 0, 0, 0.95)
    background:SetEdgeColor(0.45, 0.45, 0.45, 1)

    selectionScreen = AutoImproveGearSelectionScreen:New(
        selectionControl,
        false,
        true
    )

    selectionFragment = ZO_FadeSceneFragment:New(selectionControl)

    --connect the gamepad list to the overlay fragment for it owns navigation
    selectionScreen:SetParentFragment(selectionFragment)
end

--show the item list over the current crafting scene
local function showSelectionScreen(items)
    selectionItems = items
    selectionScreen:Update()

    --show the overlay before replacing the improvement screen keybinds
    SCENE_MANAGER:AddFragment(selectionFragment)

    --isolate the overlay keybinds from the improvement screen
    if not selectionKeybindStateIndex then
        selectionKeybindStateIndex = KEYBIND_STRIP:PushKeybindGroupState()
        KEYBIND_STRIP:AddKeybindButtonGroup(
            selectionScreen.keybindStripDescriptor,
            selectionKeybindStateIndex
        )
    end
end

--open the item list from R1
local function onAutoImprovePressed()
    local craftingType = GetCraftingInteractionType()

    if not craftingType or not equipmentTypes[craftingType] then
        printMessage("Unable to identify the current crafting station")
        return
    end

    local items = scanBackpack(craftingType)

    if #items == 0 then
        printMessage("No matching unlocked items found")
        return
    end

    createSelectionScreen()
    showSelectionScreen(items)
end

--initialize the addon
local function initialize()
    if initialized then
        return
    end

    if not KEYBIND_STRIP then
        return
    end

    local improvementScenes = {
        GAMEPAD_SMITHING_IMPROVEMENT_SCENE,
        GAMEPAD_JEWELRY_IMPROVEMENT_SCENE,
    }

    keybindDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            name = "Auto Improve",
            callback = onAutoImprovePressed,
            visible = function()
                for _, scene in ipairs(improvementScenes) do
                    if scene and scene:IsShowing() then
                        return true
                    end
                end

                return false
            end,
        },
    }

    restoreAutoImproveKeybind = function()
        if not keybindDescriptor or selectionKeybindStateIndex then
            return
        end

        local anySceneShowing = false

        for _, scene in ipairs(improvementScenes) do
            if scene and scene:IsShowing() then
                anySceneShowing = true
                break
            end
        end

        if not anySceneShowing then
            return
        end

        --remove and readd the group to force the keybind strip to refresh
        if KEYBIND_STRIP:HasKeybindButtonGroup(keybindDescriptor) then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(keybindDescriptor)
        end

        KEYBIND_STRIP:AddKeybindButtonGroup(keybindDescriptor)
        keybindActive = true
    end

    local function onSceneStateChange(oldState, newState)
        if newState == SCENE_SHOWING then
            if not keybindActive then
                KEYBIND_STRIP:AddKeybindButtonGroup(keybindDescriptor)
                keybindActive = true
            end
        elseif newState == SCENE_HIDDEN then
            local anySceneShowing = false

            for _, scene in ipairs(improvementScenes) do
                if scene and scene:IsShowing() then
                    anySceneShowing = true
                    break
                end
            end

            if not anySceneShowing and keybindActive then
                KEYBIND_STRIP:RemoveKeybindButtonGroup(keybindDescriptor)
                keybindActive = false
            end
        end
    end

    for _, scene in ipairs(improvementScenes) do
        if scene then
            scene:RegisterCallback("StateChange", onSceneStateChange)
        end
    end

    --restore the keybind when another scene closes over the improvement screen
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
        local sceneName = scene and scene.GetName and scene:GetName() or "unknown"
        local lowerSceneName = string.lower(tostring(sceneName))

        --log only crafting-related scene transitions to keep chat output short
        if string.find(lowerSceneName, "craft", 1, true)
            or string.find(lowerSceneName, "smith", 1, true)
            or string.find(lowerSceneName, "jewel", 1, true)
            or string.find(lowerSceneName, "improv", 1, true) then
            local groupRegistered = keybindDescriptor
                and KEYBIND_STRIP:HasKeybindButtonGroup(keybindDescriptor) or false

            printMessage("DBG " .. tostring(sceneName)
                .. " " .. tostring(oldState) .. ">" .. tostring(newState)
                .. " g" .. tostring(groupRegistered)
                .. " a" .. tostring(keybindActive))
        end

        if newState == SCENE_HIDDEN then
            --wait until the closing scene has finished updating the keybind strip
            zo_callLater(function()
                restoreAutoImproveKeybind()
            end, 100)
        end
    end)

    initialized = true
    printMessage("Auto Improve Gear: improvement hooks registered")
end

--handle addon loading
local function OnAddonLoaded(eventCode, name)
    --if not this app return
    if name ~= appName then return end
    --unregister for add-on loading notifications
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)
    --start process
    initialize()
end

EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, OnAddonLoaded)