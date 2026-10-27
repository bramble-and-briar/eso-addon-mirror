-- PreviewAnywhereSlotPreviewActions.lua: the 3D item preview for bag slots on gamepad screens
-- that lack it, driven the way each host screen expects:
--   * interaction scenes without a preview fragment (bank, house bank, Furnishing Vault, guild
--     bank, vendor Sell / Buyback / Repair tabs) use the vendor Buy-screen pattern:
--     ITEM_PREVIEW_GAMEPAD:SetInteractionCameraPreviewEnabled(...) then PreviewInventoryItem;
--     re-preview as the selection moves; drop out when the tab or scene goes away.
--   * the inventory root scene already embeds the preview fragment, so we call the inventory's
--     own PreviewInventoryItem (same thing its stock "hold Square" keybind does).
--
-- Entry points: R3 (UI_SHORTCUT_RIGHT_STICK, as on the vendor Buy tab) and a Preview / End Preview
-- entry in the Actions menu, added through a SecurePostHook on the global slot-action builder.
--
-- Hard-won console rules (see references/console-facts.md in the eso-console-debugging skill):
--   * only SecurePostHook; ZO_PostHook taints every closure the game creates during the call and
--     the stock Deposit/Withdraw then fails on the protected PickupInventoryItem.
--   * never ask the game to rebuild slot actions / keybinds from our stack (same taint); only
--     KEYBIND_STRIP:UpdateKeybindButtonGroup.
--   * never register a keybind the scene already uses (the strip evicts the other button): the
--     player bank's R3 "Upgrade bank" descriptor is wrapped instead of duplicated.
--   * hooks must never throw into game code; targets are nil while a scene hides.
local PA = PreviewAnywhere
local ProbeUtils = PA.ProbeUtils

local SlotPreview = {}

local INVENTORY_SCENE = "gamepad_inventory_root"

local FRAMING_TARGET_FRAGMENT, FRAMING_FRAGMENT, OPTIONS_FRAGMENT -- resolved in Initialize

-- Interaction camera preview state (one at a time, whichever host owns the current scene).
local camPreview = {
    active = false,
    targetKey = nil, -- identity of the target currently previewed
}

-- A preview target is either a bag slot { bagId=, slotIndex= } or a bare item link { link= }
-- (vendor buyback rows have no bag slot; PreviewItemLink renders them, 0.2.8 field test).

local function TargetKey(target)
    if not target then
        return nil
    end
    if target.link then
        return "link:" .. target.link
    end
    return PA.Fmt("slot:%s:%s", tostring(target.bagId), tostring(target.slotIndex))
end

local function TargetName(target)
    if not target then
        return "nil"
    end
    if target.link then
        return tostring(GetItemLinkName(target.link))
    end
    return tostring(GetItemName(target.bagId, target.slotIndex))
end

---@param target table|nil
---@return boolean
local function CanPreviewTarget(target)
    if not target then
        return false
    end
    if target.link then
        return ProbeUtils.CanPreviewLink(target.link)
    end
    if not (target.bagId and target.slotIndex) then
        return false
    end
    local ok, can = pcall(CanInventoryItemBePreviewed, target.bagId, target.slotIndex)
    return ok and can == true
end

local function IsInteractionPreviewOn()
    return ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled()
end

local function IsCamPreviewing()
    return camPreview.active or IsInteractionPreviewOn()
end

---@param bagId integer|nil
---@param slotIndex integer|nil
---@return boolean
local function CanPreviewSlot(bagId, slotIndex)
    return CanPreviewTarget({ bagId = bagId, slotIndex = slotIndex })
end

---Availability context, logged whenever a preview is attempted.
local function AvailabilityLine()
    local function Try(fn, ...)
        if not fn then return "n/a" end
        local ok, v = pcall(fn, ...)
        return ok and tostring(v) or ("ERR " .. tostring(v))
    end
    return PA.Fmt("available=%s mounted=%s combat=%s interaction=%s interactCam=%s houseId=%s bankingBag=%s",
        Try(IsCharacterPreviewingAvailable), Try(IsMounted), Try(IsUnitInCombat, "player"),
        Try(GetInteractionType), Try(IsInteractionUsingInteractCamera), Try(GetCurrentZoneHouseId), Try(GetBankingBag))
end

-- Hosts ----------------------------------------------------------------------
-- A host describes one interaction scene: how to read the selected bag slot and which keybind
-- group carries our R3 button (so its label can be refreshed), plus whether the scene carries the
-- quadrant-3 blur fragment permanently (bank scenes do; the vendor adds it only on its Buy tab).

local STORE_PREVIEW_MODES = {} -- filled in Initialize once the ZO_MODE_STORE_* constants are known

local HOSTS = {}

HOSTS.gamepad_banking = {
    sceneName = "gamepad_banking",
    label = "bank",
    hasPermanentBlur = true,
    GetObject = function() return rawget(_G, "GAMEPAD_BANKING") end,
    GetTarget = function(self)
        local banking = self.GetObject()
        local targetData = banking and banking:GetTargetData()
        if not targetData or ZO_GamepadBanking.IsEntryDataCurrencyRelated(targetData) then
            return nil
        end
        local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(targetData)
        if not (bagId and slotIndex) then
            return nil
        end
        return { bagId = bagId, slotIndex = slotIndex }
    end,
    GetKeybindGroup = function(self)
        local banking = self.GetObject()
        return banking and (banking.mainKeybindStripDescriptor or banking.currentKeybindStripDescriptor)
    end,
}

HOSTS.gamepad_guild_bank = {
    sceneName = "gamepad_guild_bank",
    label = "guild bank",
    hasPermanentBlur = true,
    GetObject = function() return rawget(_G, "GAMEPAD_GUILD_BANK") end,
    GetTarget = HOSTS.gamepad_banking.GetTarget,
    GetKeybindGroup = function(self)
        local guildBank = self.GetObject()
        return guildBank and guildBank.currentKeybindStripDescriptor
    end,
}

HOSTS.gamepad_store = {
    sceneName = "gamepad_store",
    label = "vendor",
    hasPermanentBlur = false,
    GetObject = function() return rawget(_G, "STORE_WINDOW_GAMEPAD") end,
    ---Only the tabs that list the player's own items (Sell, Buyback, Repair, fence Sell/Launder);
    ---the Buy tab has the game's own R3 preview. Buyback rows are store entries, not bag slots, so
    ---they are previewed through their item link.
    GetTarget = function(self)
        local store = self.GetObject()
        local component = store and store:GetActiveComponent()
        if not (component and component.list and STORE_PREVIEW_MODES[component:GetStoreMode()]) then
            return nil
        end
        local data = component.list:GetTargetData()
        if not data then
            return nil
        end
        if component:GetStoreMode() == ZO_MODE_STORE_BUY_BACK then
            local index = data.slotIndex
            local ok, link = pcall(GetBuybackItemLink, index)
            if ok and link and link ~= "" then
                return { link = link }
            end
            return nil
        end
        local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(data)
        if not (bagId and slotIndex) then
            return nil
        end
        return { bagId = bagId, slotIndex = slotIndex }
    end,
    GetKeybindGroup = function(self)
        local store = self.GetObject()
        local component = store and store:GetActiveComponent()
        if component and STORE_PREVIEW_MODES[component:GetStoreMode()] then
            return component.keybindStripDescriptor
        end
        return nil
    end,
}

---@return table|nil host The host owning the current scene
local function GetCurrentHost()
    return HOSTS[ProbeUtils.CurrentSceneName()]
end

-- Interaction camera preview ------------------------------------------------------

---Bank scenes carry FRAME_TARGET_BLUR_QUADRANT_3_GAMEPAD_FRAGMENT permanently, so we pull it out of
---the scene's own fragment list while the preview renders and put it back afterwards (always
---restored on scene hidden so the scene definition is never left altered). The vendor adds the
---same blur as a temporary fragment (its Buy tab leaves it behind when you switch tabs), which
---the scene manager's temporary-fragment API handles.
local function SetHostBlurActive(host, active)
    local blur = FRAME_TARGET_BLUR_QUADRANT_3_GAMEPAD_FRAGMENT
    local scene = host and SCENE_MANAGER:GetScene(host.sceneName)
    if not (blur and scene) then
        return
    end
    if host.hasPermanentBlur then
        if active then
            if not scene:HasFragment(blur) then
                scene:AddFragment(blur)
            end
        elseif scene:HasFragment(blur) then
            scene:RemoveFragment(blur)
        end
    else
        if active then
            if camPreview.restoreTemporaryBlur and scene:GetState() == SCENE_SHOWN then
                SCENE_MANAGER:AddFragment(blur)
            end
            camPreview.restoreTemporaryBlur = nil
        elseif scene:HasFragment(blur) then
            camPreview.restoreTemporaryBlur = true
            SCENE_MANAGER:RemoveFragmentImmediately(blur)
        end
    end
end

local function SetCamPreviewEnabled(host, enabled)
    if enabled == IsInteractionPreviewOn() then
        camPreview.active = enabled
        return
    end
    PA.Log("%s camera preview -> %s | %s", host and host.label or "?", tostring(enabled), ProbeUtils.PreviewStateLine())
    PA.SafeCall("SetHostBlurActive", SetHostBlurActive, host, not enabled)
    PA.SafeCall("SetInteractionCameraPreviewEnabled", function()
        ITEM_PREVIEW_GAMEPAD:SetInteractionCameraPreviewEnabled(enabled, FRAMING_TARGET_FRAGMENT, FRAMING_FRAGMENT, OPTIONS_FRAGMENT)
    end)
    camPreview.active = enabled
    if not enabled then
        camPreview.targetKey = nil
    end
    PA.DebugLater(300, "  +300ms: %s")
end

local function PreviewCamTarget(target)
    local key = TargetKey(target)
    if camPreview.targetKey == key then
        return
    end
    camPreview.targetKey = key
    PA.Debug("preview %s '%s'", key, TargetName(target))
    PA.SafeCall("PreviewTarget", function()
        ITEM_PREVIEW_GAMEPAD:ClearPreviewCollection()
        if target.link then
            ITEM_PREVIEW_GAMEPAD:SharedPreviewSetup(PA.LinkPreview.PREVIEW_TYPE, target.link)
        else
            ITEM_PREVIEW_GAMEPAD:PreviewInventoryItem(target.bagId, target.slotIndex)
        end
    end)
    PA.DebugLater(500, "  +500ms: %s")
end

---Re-evaluate the R3 label right away (the game only does so on selection change). Only when the
---scene is fully shown, and only the strip: see the rules at the top of the file.
local function RefreshHostKeybinds(host)
    if not host then
        return
    end
    local scene = SCENE_MANAGER:GetScene(host.sceneName)
    if not scene or scene:GetState() ~= SCENE_SHOWN then
        PA.Debug("skip %s keybind refresh (scene state %s)", host.label, tostring(scene and scene:GetState()))
        return
    end
    local ok, group = pcall(host.GetKeybindGroup, host)
    if ok and group and KEYBIND_STRIP:HasKeybindButtonGroup(group) then
        PA.SafeCall("UpdateKeybindButtonGroup", function() KEYBIND_STRIP:UpdateKeybindButtonGroup(group) end)
    end
end

local function StartCamPreview(host, target)
    PA.Count("camPreviewStarts")
    PA.Log("start %s preview '%s': %s", host and host.label or "?", TargetName(target), AvailabilityLine())
    SetCamPreviewEnabled(host, true)
    PreviewCamTarget(target)
    RefreshHostKeybinds(host)
end

local function StopCamPreview(host)
    PA.Count("camPreviewStops")
    PA.SafeCall("EndCurrentPreview", function() ITEM_PREVIEW_GAMEPAD:EndCurrentPreview() end)
    SetCamPreviewEnabled(host, false)
    RefreshHostKeybinds(host)
end

---Toggle from the R3 keybind: preview the selected row, or end the running preview.
local function ToggleCamPreview()
    local host = GetCurrentHost()
    if IsCamPreviewing() then
        PA.Log("R3: End Preview (%s)", host and host.label or "?")
        StopCamPreview(host)
        return
    end
    if not host then
        PA.Log("R3: no preview host for scene %s", ProbeUtils.CurrentSceneName())
        return
    end
    local ok, target = pcall(host.GetTarget, host)
    if ok and CanPreviewTarget(target) then
        PA.Log("R3: Preview (%s) %s", host.label, TargetKey(target))
        StartCamPreview(host, target)
    else
        PA.Log("R3: nothing previewable selected (%s)", host.label)
    end
end

---Whether our R3 Preview should show for the current selection.
local function IsCamPreviewKeybindVisible()
    if not PA.state.savedVars.enabled then
        return false
    end
    if IsCamPreviewing() then
        return true
    end
    local host = GetCurrentHost()
    if not host then
        return false
    end
    local ok, target = pcall(host.GetTarget, host)
    return ok and CanPreviewTarget(target)
end

local function CamPreviewKeybindName()
    if IsCamPreviewing() then
        return GetString(SI_CRAFTING_EXIT_PREVIEW_MODE)
    end
    return GetString(SI_CRAFTING_ENTER_PREVIEW_MODE)
end

---Follow the selection while previewing: re-preview the new row or end when it is not previewable.
---Called from secure post-hooks with whatever the host's selection is now.
local function OnHostSelectionChanged(host)
    if GetCurrentHost() ~= host then
        return
    end
    -- The vendor's Sell/Buyback/Repair tabs never refresh their keybind group on selection change
    -- (their stock buttons do not depend on the row), so our R3 label/visibility would only update
    -- by accident. Refresh it here (strip only; see the rules at the top of the file).
    if host == HOSTS.gamepad_store then
        RefreshHostKeybinds(host)
    end
    if not camPreview.active then
        return
    end
    local ok, target = pcall(host.GetTarget, host)
    if ok and CanPreviewTarget(target) then
        PreviewCamTarget(target)
    else
        PA.Debug("%s selection not previewable; ending preview", host.label)
        StopCamPreview(host)
    end
end

local function OnHostSceneStateChange(host, newState)
    PA.Debug("%s state %s | %s", host.sceneName, tostring(newState), ProbeUtils.PreviewStateLine())
    if newState == SCENE_HIDING and IsCamPreviewing() then
        -- Restore the interact camera before the interaction tears down (store buy does the same).
        PA.Log("%s hiding while previewing; ending preview", host.sceneName)
        StopCamPreview(host)
    elseif newState == SCENE_HIDDEN then
        camPreview.active = false
        camPreview.targetKey = nil
        PA.SafeCall("RestoreBlur", SetHostBlurActive, host, true)
    end
end

-- R3 keybind installation -------------------------------------------------------

local function NewR3Descriptor()
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        keybind = "UI_SHORTCUT_RIGHT_STICK",
        name = CamPreviewKeybindName,
        visible = IsCamPreviewKeybindVisible,
        callback = function() PA.SafeCall("ToggleCamPreview", ToggleCamPreview) end,
    }
end

---Append our R3 descriptor to a keybind group table once.
local function AddR3ToGroup(group, label)
    if type(group) ~= "table" or group.previewAnywhereAdded then
        return false
    end
    for _, descriptor in ipairs(group) do
        if descriptor.keybind == "UI_SHORTCUT_RIGHT_STICK" then
            PA.Log("%s: R3 already taken; preview keybind not added", label)
            return false
        end
    end
    group.previewAnywhereAdded = true
    table.insert(group, NewR3Descriptor())
    PA.Debug("%s: R3 preview added", label)
    return true
end

---Player bank: wrap the existing R3 "Upgrade bank" descriptor so it doubles as Preview whenever
---the upgrade button would not be shown (house banks, Furnishing Vault, maxed bank).
local function WrapBankUpgradeKeybind(banking)
    local group = banking and banking.mainKeybindStripDescriptor
    if type(group) ~= "table" then
        PA.Log("bank keybind group missing; R3 preview not installed")
        return false
    end
    for _, descriptor in ipairs(group) do
        if descriptor.keybind == "UI_SHORTCUT_RIGHT_STICK" then
            if descriptor.previewAnywhereWrapped then
                return true
            end
            descriptor.previewAnywhereWrapped = true
            local origName, origVisible, origEnabled, origCallback, origNarration =
                descriptor.name, descriptor.visible, descriptor.enabled, descriptor.callback, descriptor.narrationOverrideName
            local function UpgradeApplies()
                if origVisible == nil then
                    return true
                end
                local ok, visible = pcall(origVisible)
                return ok and visible == true
            end
            descriptor.name = function()
                if UpgradeApplies() then
                    return type(origName) == "function" and origName() or origName
                end
                return CamPreviewKeybindName()
            end
            descriptor.narrationOverrideName = function()
                if UpgradeApplies() then
                    if type(origNarration) == "function" then return origNarration() end
                    return origNarration
                end
                return nil
            end
            descriptor.visible = function()
                if UpgradeApplies() then
                    return true
                end
                return IsCamPreviewKeybindVisible()
            end
            descriptor.enabled = function()
                if UpgradeApplies() then
                    if origEnabled == nil then return true end
                    if type(origEnabled) == "function" then return origEnabled() end
                    return origEnabled
                end
                return true
            end
            descriptor.callback = function(...)
                if UpgradeApplies() then
                    return origCallback(...)
                end
                PA.SafeCall("ToggleCamPreview", ToggleCamPreview)
            end
            PA.Debug("wrapped bank R3 (upgrade) keybind")
            return true
        end
    end
    PA.Log("bank R3 keybind not found in group; R3 preview not installed")
    return false
end

---Guild bank: no R3 button exists, so add our own to both the withdraw and deposit groups.
local function AddGuildBankKeybind(guildBank)
    if not guildBank then
        return
    end
    for _, groupName in ipairs({ "withdrawKeybindStripDescriptor", "depositKeybindStripDescriptor" }) do
        AddR3ToGroup(guildBank[groupName], "guild bank " .. groupName)
    end
end

---Vendor: add R3 to the Sell / Buyback / Repair (and vengeance sell) tab groups. The Buy tab keeps
---the game's own R3 preview.
local function AddStoreKeybinds(store)
    if not (store and store.components) then
        PA.Log("store components missing; vendor R3 preview not installed")
        return
    end
    for mode, component in pairs(store.components) do
        if STORE_PREVIEW_MODES[mode] then
            AddR3ToGroup(component.keybindStripDescriptor, "vendor mode " .. tostring(mode))
        end
    end
end

-- Inventory -------------------------------------------------------------------

local function RefreshInventoryKeybinds()
    local group = GAMEPAD_INVENTORY.keybindStripDescriptor
    if group and KEYBIND_STRIP:HasKeybindButtonGroup(group) then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(group)
    end
end

local function StartInventoryPreview(bagId, slotIndex)
    PA.Count("inventoryPreviewStarts")
    PA.Log("inventory PreviewInventoryItem(%d, %d) '%s' | %s", bagId, slotIndex, tostring(GetItemName(bagId, slotIndex)), ProbeUtils.PreviewStateLine())
    PA.SafeCall("GAMEPAD_INVENTORY:PreviewInventoryItem", function()
        GAMEPAD_INVENTORY:PreviewInventoryItem(bagId, slotIndex)
        RefreshInventoryKeybinds() -- not RefreshKeybinds(): that rebuilds slot actions on our stack
    end)
    PA.DebugLater(500, "  +500ms: %s")
end

local function StopInventoryPreview()
    PA.Count("inventoryPreviewStops")
    PA.SafeCall("GAMEPAD_INVENTORY:EndPreview", function()
        GAMEPAD_INVENTORY:EndPreview()
        RefreshInventoryKeybinds()
    end)
end

-- Actions menu hook -----------------------------------------------------------

local discoveryLogs = 0
local lastDiscoveryKey = nil

---Secure post-hook for ZO_InventorySlot_DiscoverSlotActionsFromActionList: runs every time the
---game (re)builds the slot actions for the selected row; the gamepad Actions dialog lists every
---action we add, so only add when it applies.
local function AddPreviewSlotAction(inventorySlot, slotActions)
    if not inventorySlot or not PA.state.savedVars.enabled or not IsInGamepadPreferredMode() then
        return
    end
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not (bagId and slotIndex) then
        return
    end
    local sceneName = ProbeUtils.CurrentSceneName()
    PA.Count("discover:" .. sceneName)
    local discoveryKey = sceneName .. ":" .. tostring(bagId) .. ":" .. tostring(slotIndex)
    if discoveryLogs < 30 and discoveryKey ~= lastDiscoveryKey then
        lastDiscoveryKey = discoveryKey
        discoveryLogs = discoveryLogs + 1
        PA.Debug("discover #%d scene=%s bag=%s slot=%s '%s' canPreview=%s camPreview=%s | %s",
            discoveryLogs, sceneName, tostring(bagId), tostring(slotIndex), tostring(GetItemName(bagId, slotIndex)),
            tostring(CanPreviewSlot(bagId, slotIndex)), tostring(IsInteractionPreviewOn()), AvailabilityLine())
    end

    local host = HOSTS[sceneName]
    if host then
        if IsCamPreviewing() then
            slotActions:AddSlotAction(SI_CRAFTING_EXIT_PREVIEW_MODE, function()
                PA.Log("Actions: End Preview (%s)", host.label)
                StopCamPreview(host)
            end)
        elseif CanPreviewSlot(bagId, slotIndex) then
            slotActions:AddSlotAction(SI_ITEM_ACTION_PREVIEW, function()
                PA.Log("Actions: Preview (%s) bag %d slot %d", host.label, bagId, slotIndex)
                -- Let the dialog finish closing before we swap camera fragments.
                zo_callLater(function() StartCamPreview(host, { bagId = bagId, slotIndex = slotIndex }) end, 100)
            end)
        end
    elseif sceneName == INVENTORY_SCENE and rawget(_G, "GAMEPAD_INVENTORY") then
        if IsCurrentlyPreviewing() then
            slotActions:AddSlotAction(SI_CRAFTING_EXIT_PREVIEW_MODE, function()
                PA.Log("Actions: End Preview (inventory)")
                StopInventoryPreview()
            end)
        elseif CanPreviewSlot(bagId, slotIndex) then
            slotActions:AddSlotAction(SI_ITEM_ACTION_PREVIEW, function()
                PA.Log("Actions: Preview (inventory) bag %d slot %d | %s", bagId, slotIndex, AvailabilityLine())
                zo_callLater(function() StartInventoryPreview(bagId, slotIndex) end, 100)
            end)
        end
    end
end

-- Initialize --------------------------------------------------------------------

function SlotPreview.Initialize()
    -- Vendor Buy-screen layout: list in quadrant 1, item tooltip in quadrant 2, preview in 3-4,
    -- so the info panel does not sit on top of the furnishing.
    FRAMING_TARGET_FRAGMENT = FRAME_TARGET_STORE_GAMEPAD_FRAGMENT
    FRAMING_FRAGMENT = FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT
    OPTIONS_FRAGMENT = GAMEPAD_NAV_QUADRANT_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT
    assert(FRAMING_TARGET_FRAGMENT and FRAMING_FRAGMENT and OPTIONS_FRAGMENT, "preview framing fragments missing")
    assert(ITEM_PREVIEW_GAMEPAD.SetInteractionCameraPreviewEnabled, "SetInteractionCameraPreviewEnabled missing")

    for _, modeName in ipairs({ "ZO_MODE_STORE_SELL", "ZO_MODE_STORE_BUY_BACK", "ZO_MODE_STORE_REPAIR", "ZO_MODE_STORE_SELL_VENGEANCE", "ZO_MODE_STORE_SELL_STOLEN", "ZO_MODE_STORE_LAUNDER" }) do
        local mode = rawget(_G, modeName)
        if mode then
            STORE_PREVIEW_MODES[mode] = true
        end
    end

    -- Actions menu entry (all hosts + inventory).
    PA.SecureHook(_G, "ZO_InventorySlot_DiscoverSlotActionsFromActionList", PA.Guard("AddPreviewSlotAction", AddPreviewSlotAction))

    -- Selection following.
    PA.SecureHook(ZO_BankingCommon_Gamepad, "OnTargetChanged", PA.Guard("OnBankTargetChanged", function(banking)
        OnHostSelectionChanged(HOSTS[banking == rawget(_G, "GAMEPAD_GUILD_BANK") and "gamepad_guild_bank" or "gamepad_banking"])
    end))
    for _, className in ipairs({ "ZO_GamepadStoreSell", "ZO_GamepadStoreBuyback", "ZO_GamepadStoreRepair", "ZO_GamepadStoreSellVengeance", "ZO_GamepadFenceComponent" }) do
        local class = rawget(_G, className)
        if class and class.OnSelectedItemChanged then
            PA.SecureHook(class, "OnSelectedItemChanged", PA.Guard(className .. ".OnSelectedItemChanged", function()
                OnHostSelectionChanged(HOSTS.gamepad_store)
            end))
        end
    end
    -- Switching vendor tabs hides the component: end our preview (the Buy tab has its own).
    if rawget(_G, "ZO_GamepadStoreComponent") then
        PA.SecureHook(ZO_GamepadStoreComponent, "Hide", PA.Guard("StoreComponentHide", function()
            if IsCamPreviewing() and GetCurrentHost() == HOSTS.gamepad_store then
                PA.Log("vendor tab hidden while previewing; ending preview")
                StopCamPreview(HOSTS.gamepad_store)
            end
        end))
    end

    -- R3 keybinds. Descriptors are built in each screen's Initialize (before addons load); the
    -- post-hooks cover a deferred rebuild should the game ever re-create them.
    PA.SafeCall("WrapBankUpgradeKeybind", WrapBankUpgradeKeybind, rawget(_G, "GAMEPAD_BANKING"))
    PA.SecureHook(ZO_GamepadBanking, "InitializeKeybindStripDescriptors", PA.Guard("WrapBankUpgradeKeybind", function(self) WrapBankUpgradeKeybind(self) end))
    PA.SafeCall("AddGuildBankKeybind", AddGuildBankKeybind, rawget(_G, "GAMEPAD_GUILD_BANK"))
    if rawget(_G, "ZO_GuildBank_Gamepad") then
        PA.SecureHook(ZO_GuildBank_Gamepad, "InitializeKeybindStripDescriptors", PA.Guard("AddGuildBankKeybind", function(self) AddGuildBankKeybind(self) end))
    end
    PA.SafeCall("AddStoreKeybinds", AddStoreKeybinds, rawget(_G, "STORE_WINDOW_GAMEPAD"))
    if rawget(_G, "ZO_GamepadStoreManager") and ZO_GamepadStoreManager.AddComponent then
        PA.SecureHook(ZO_GamepadStoreManager, "AddComponent", PA.Guard("AddStoreKeybinds", function(self) AddStoreKeybinds(self) end))
    end

    -- Tracing (debug mode only; the fragment state is the clearest sign the engine took a preview).
    ITEM_PREVIEW_GAMEPAD:GetFragment():RegisterCallback("StateChange", function(_old, newState)
        if PA.IsDebug() then
            PA.Debug("preview fragment %s | %s", tostring(newState), ProbeUtils.PreviewStateLine())
        end
    end)

    for sceneName, host in pairs(HOSTS) do
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            scene:RegisterCallback("StateChange", PA.Guard("OnHostSceneStateChange", function(_old, newState) OnHostSceneStateChange(host, newState) end))
        else
            PA.Log("scene %s not found; no auto-exit for it", sceneName)
        end
    end
end

---Hosts the hover module must leave alone (they have R3 + Actions-menu preview already).
function SlotPreview.IsHostScene(sceneName)
    return HOSTS[sceneName] ~= nil
end

PA.SlotPreview = SlotPreview
