-- Gamepad.lua
-- Adds console/gamepad inventory features:
--   1. Junk badge in the cycling statusIndicator alongside ornate/intricate/stolen/new
--   2. Hold Y (UI_SHORTCUT_QUINARY / Triangle on PS) to toggle junk status
--      Only shown for non-stolen items in BAG_BACKPACK.
--   3. Hold Y in the merchant Sell tab to sell all junk items at once.

if not ASJ then ASJ = {} end

-- Replace with a ~32x32 white monochrome DDS to match the other status badge icons.
-- Gamepad badge style reference: EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_*.dds
local JUNK_ICON_TEXTURE = "AbahsAppraiser/icons/junk_gp.dds"
local GP_NAMESPACE = (ASJ.addOnName or "AbahsAppraiser") .. "_GP"
local PRE_PREFIX = "|cE5C07BASJ|r "

local inJunkSetup = false

local function OnGamepadEntrySetup(control, data)
    if inJunkSetup then return end
    local bagId = data and data.bagId
    local slotIndex = data and data.slotIndex
    if bagId == nil or slotIndex == nil then return end
    local statusIndicator = control.statusIndicator
    if not statusIndicator then return end
    if IsItemJunk(bagId, slotIndex) then
        inJunkSetup = true
        statusIndicator:AddIcon(JUNK_ICON_TEXTURE)
        statusIndicator:Hide()
        statusIndicator:Show()
        inJunkSetup = false
    end
end

-- Inserts the Hold-Y junk-toggle keybind into the item filter descriptor after
-- GAMEPAD_INVENTORY has finished its deferred initialisation.
-- UI_SHORTCUT_QUINARY is the Hold Y / Triangle button (same pattern as
-- UI_SHORTCUT_QUATERNARY = Hold X used by MapOfManyRiches).
local function SetupJunkKeybind(self)
    if not self.itemFilterKeybindStripDescriptor then return end

    table.insert(self.itemFilterKeybindStripDescriptor, {
        alignment = KEYBIND_STRIP_ALIGN_RIGHT,
        keybind = "UI_SHORTCUT_QUINARY",
        order = 600,

        -- Static name and no visible function: addon function closures on these
        -- fields get called by UpdateAnchorsInternal for every button in the group
        -- during keybind strip layout, which can occur within the A-button press
        -- callchain and taints it, blocking UseItem on containers.
        -- Guard logic lives only in callback (runs only when Hold-Y is pressed).
        name = "Junk",

        callback = function()
            local targetData = self.itemList:GetTargetData()
            if not targetData or targetData.bagId ~= BAG_BACKPACK
                    or targetData.slotIndex == nil then
                return
            end
            if not CanItemBeMarkedAsJunk(targetData.bagId, targetData.slotIndex) then
                return
            end
            local itemLink = GetItemLink(targetData.bagId, targetData.slotIndex)
            if GetItemLinkSellInformation(itemLink) == ITEM_SELL_INFORMATION_CANNOT_SELL then
                return
            end
            local isItemJunk = IsItemJunk(targetData.bagId, targetData.slotIndex)
            SetItemIsJunk(targetData.bagId, targetData.slotIndex, not isItemJunk)
            PlaySound(isItemJunk and SOUNDS.INVENTORY_ITEM_UNJUNKED or SOUNDS.INVENTORY_ITEM_JUNKED)
            self.itemList:RefreshVisible()
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.itemFilterKeybindStripDescriptor)
        end,
    })
end

-- Inserts the Hold-Y sell-all-junk keybind into the gamepad merchant Sell tab.
-- STORE_WINDOW_GAMEPAD and its components are created from XML OnInitialized,
-- which fires before EVENT_ADD_ON_LOADED, so the descriptor already exists here.
local function SetupSellJunkKeybind()
    if not STORE_WINDOW_GAMEPAD or not STORE_WINDOW_GAMEPAD.components then return end
    local sellComponent = STORE_WINDOW_GAMEPAD.components[ZO_MODE_STORE_SELL]
    if not sellComponent or not sellComponent.keybindStripDescriptor then return end

    table.insert(sellComponent.keybindStripDescriptor, {
        alignment = KEYBIND_STRIP_ALIGN_RIGHT,
        keybind = "UI_SHORTCUT_QUINARY",
        order = 600,
        name = "Sell Junk",

        visible = function()
            local sv = ASJ and (ASJ.savedVars or ASJ.defaults)
            local companionThreshold = sv and sv.asjCompanionItemsQualityThreshold or -1
            local bagSize = GetBagSize(BAG_BACKPACK)
            for i = 0, bagSize - 1 do
                if companionThreshold ~= -1
                        and GetItemActorCategory(BAG_BACKPACK, i) == GAMEPLAY_ACTOR_CATEGORY_COMPANION
                        and GetItemFunctionalQuality(BAG_BACKPACK, i) <= companionThreshold then
                    return true
                end
                if IsItemJunk(BAG_BACKPACK, i) and not IsItemStolen(BAG_BACKPACK, i) then
                    local itemLink = GetItemLink(BAG_BACKPACK, i)
                    if itemLink ~= "" and
                            GetItemLinkSellInformation(itemLink) ~= ITEM_SELL_INFORMATION_CANNOT_SELL then
                        return true
                    end
                end
            end
            return false
        end,

        callback = function()
            if ASJ.ScanBackpackForJunk then ASJ.ScanBackpackForJunk(true, false) end
            SellAllJunk()
            d(PRE_PREFIX .. "Sold junk items.")
            KEYBIND_STRIP:UpdateKeybindButtonGroup(sellComponent.keybindStripDescriptor)
        end,
    })
end

local function OnAddonLoaded(eventCode, name)
    if name ~= (ASJ.addOnName or "AbahsAppraiser") then return end
    EVENT_MANAGER:UnregisterForEvent(GP_NAMESPACE, EVENT_ADD_ON_LOADED)

    -- Hook the global setup function before the inventory is first opened.
    -- ZO_GamepadInventory:InitializeItemList() runs inside OnDeferredInitialize
    -- (lazy, on first open) and stores a direct function reference via AddDataTemplate.
    -- We must patch the global before that reference is captured, so hooking here
    -- (at addon load, before any inventory open) guarantees we're in place in time.
    -- SecurePostHook on _G avoids writing an addon closure onto any game object.
    if ZO_SharedGamepadEntry_OnSetup then
        SecurePostHook(_G, "ZO_SharedGamepadEntry_OnSetup", OnGamepadEntrySetup)
    end

    -- Hook deferred init to append the Hold-Y junk-toggle keybind once
    -- itemFilterKeybindStripDescriptor has been created.
    if GAMEPAD_INVENTORY then
        SecurePostHook(GAMEPAD_INVENTORY, "OnDeferredInitialize", SetupJunkKeybind)
    end

    SetupSellJunkKeybind()
end

EVENT_MANAGER:RegisterForEvent(GP_NAMESPACE, EVENT_ADD_ON_LOADED, OnAddonLoaded)
