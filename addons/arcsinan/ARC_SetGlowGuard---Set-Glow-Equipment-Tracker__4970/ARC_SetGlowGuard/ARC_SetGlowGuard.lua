-- ARC_SetGlowGuard - Set Glow & Equipment Tracker for Elder Scrolls Online
-- Author: @arcsinan
-- Version: 1.0.1

ARC_SetGlowGuard = ARC_SetGlowGuard or {}
local ASGG = ARC_SetGlowGuard

ASGG.name = "ARC_SetGlowGuard"
ASGG.version = "1.0.2"
ASGG.author = "@arcsinan"

-- Cached scene and fragment references
local invScene
local charFragm
local hookedLists = {}

-- Default settings
ASGG.defaults = {
    language = "en",
    enabled = true,
    autoShowCharacterOnInventory = true,
    highlightBackpack = true,
    highlightEquipment = true,
    highlightBank = true,
    highlightDeconstruction = true,
    showIncompleteWarning = true,
    showRowBar = true,
    glowIntensity = 0.85,
    glowTexture = "EsoUI/Art/ActionBar/actionBar_mouseOver.dds",
    colors = {
        [1] = { 0.0, 0.83, 1.0, 1.0 },   -- Set 1: Vibrant Cyan
        [2] = { 1.0, 0.70, 0.0, 1.0 },   -- Set 2: Warm Amber Gold
        [3] = { 0.74, 0.0, 1.0, 1.0 },   -- Set 3: Neon Purple / Monster
        [4] = { 0.0, 0.90, 0.46, 1.0 },  -- Set 4: Emerald Green
        [5] = { 1.0, 0.20, 0.40, 1.0 },  -- Set 5: Coral Crimson
        [6] = { 1.0, 0.43, 0.0, 1.0 },   -- Set 6: Vivid Orange
        mythic = { 1.0, 0.35, 0.0, 1.0 }, -- Mythic Item: Deep Mythic Amber
        warning = { 1.0, 0.15, 0.15, 1.0 }, -- Incomplete Set Alert: Warning Red
    }
}

-- Equipment slots to scan and highlight
ASGG.EQUIP_SLOTS = {
    EQUIP_SLOT_HEAD,
    EQUIP_SLOT_NECK,
    EQUIP_SLOT_CHEST,
    EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_MAIN_HAND,
    EQUIP_SLOT_OFF_HAND,
    EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET,
    EQUIP_SLOT_RING1,
    EQUIP_SLOT_RING2,
    EQUIP_SLOT_HAND,
    EQUIP_SLOT_BACKUP_MAIN,
    EQUIP_SLOT_BACKUP_OFF,
}

-- Mapping between equipment slot constants and UI controls on the Character sheet
ASGG.SLOT_CONTROLS = {
    [EQUIP_SLOT_HEAD]           = "ZO_CharacterEquipmentSlotsHead",
    [EQUIP_SLOT_NECK]           = "ZO_CharacterEquipmentSlotsNeck",
    [EQUIP_SLOT_CHEST]          = "ZO_CharacterEquipmentSlotsChest",
    [EQUIP_SLOT_SHOULDERS]      = "ZO_CharacterEquipmentSlotsShoulder",
    [EQUIP_SLOT_MAIN_HAND]      = "ZO_CharacterEquipmentSlotsMainHand",
    [EQUIP_SLOT_OFF_HAND]       = "ZO_CharacterEquipmentSlotsOffHand",
    [EQUIP_SLOT_WAIST]          = "ZO_CharacterEquipmentSlotsBelt",
    [EQUIP_SLOT_LEGS]           = "ZO_CharacterEquipmentSlotsLeg",
    [EQUIP_SLOT_FEET]           = "ZO_CharacterEquipmentSlotsFoot",
    [EQUIP_SLOT_RING1]          = "ZO_CharacterEquipmentSlotsRing1",
    [EQUIP_SLOT_RING2]          = "ZO_CharacterEquipmentSlotsRing2",
    [EQUIP_SLOT_HAND]           = "ZO_CharacterEquipmentSlotsGlove",
    [EQUIP_SLOT_BACKUP_MAIN]    = "ZO_CharacterEquipmentSlotsBackupMain",
    [EQUIP_SLOT_BACKUP_OFF]     = "ZO_CharacterEquipmentSlotsBackupOff",
}

-- State tables
ASGG.equippedSets = {}
ASGG.slotSetMap = {}
ASGG.numEquippedSets = 0

--------------------------------------------------------------------------------
-- Equipment & Set Scanning
--------------------------------------------------------------------------------

function ASGG.UpdateEquippedSets()
    ASGG.equippedSets = {}
    ASGG.slotSetMap = {}
    ASGG.numEquippedSets = 0

    local setOrder = {}

    for _, slotId in ipairs(ASGG.EQUIP_SLOTS) do
        local link = GetItemLink(BAG_WORN, slotId)
        if link and link ~= "" then
            local hasSet, setName, _, numEquipped, maxEquipped, setId = GetItemLinkSetInfo(link, true)
            local isMythic = (GetItemLinkDisplayQuality and GetItemLinkDisplayQuality(link) >= ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE) or false

            if hasSet and setId and setId > 0 then
                if not ASGG.equippedSets[setId] then
                    ASGG.numEquippedSets = ASGG.numEquippedSets + 1
                    local colorsList = (ASGG.vars and ASGG.vars.colors) or ASGG.defaults.colors
                    local colorIdx = ((ASGG.numEquippedSets - 1) % #colorsList) + 1
                    local color = isMythic and colorsList.mythic or colorsList[colorIdx]

                    ASGG.equippedSets[setId] = {
                        id = setId,
                        name = setName,
                        maxEquipped = maxEquipped or 5,
                        numEquipped = numEquipped or 1,
                        color = color,
                        isMythic = isMythic,
                        slots = { slotId },
                    }
                    table.insert(setOrder, setId)
                else
                    table.insert(ASGG.equippedSets[setId].slots, slotId)
                end
                ASGG.slotSetMap[slotId] = setId
            end
        end
    end

    -- Flag incomplete sets (e.g. 4/5 or 1/2) so player knows an item is missing
    for _, setId in ipairs(setOrder) do
        local setData = ASGG.equippedSets[setId]
        if setData and not setData.isMythic and setData.numEquipped < setData.maxEquipped then
            setData.isIncomplete = true
        end
    end
end

--------------------------------------------------------------------------------
-- Character Sheet Glow Controls
--------------------------------------------------------------------------------

function ASGG.UpdateEquipmentGlows()
    local vars = ASGG.vars or ASGG.defaults
    for slotId, controlName in pairs(ASGG.SLOT_CONTROLS) do
        local slotControl = _G[controlName]
        if slotControl then
            local glow = slotControl:GetNamedChild("ARC_SetGlowGuardGlow")
            if not glow then
                glow = WINDOW_MANAGER:CreateControl(slotControl:GetName() .. "ARC_SetGlowGuardGlow", slotControl, CT_TEXTURE)
                glow:SetAnchor(TOPLEFT, slotControl, TOPLEFT, -4, -4)
                glow:SetAnchor(BOTTOMRIGHT, slotControl, BOTTOMRIGHT, 4, 4)
                glow:SetTexture(vars.glowTexture)
                glow:SetBlendMode(TEX_BLEND_MODE_ADD)
                glow:SetDrawTier(DT_HIGH)
                glow:SetDrawLayer(DL_OVERLAY)
            end

            local badge = slotControl:GetNamedChild("ARC_SetGlowGuardBadge")
            if not badge then
                badge = WINDOW_MANAGER:CreateControl(slotControl:GetName() .. "ARC_SetGlowGuardBadge", slotControl, CT_LABEL)
                badge:SetFont("ZoFontGameBold")
                badge:SetAnchor(BOTTOMRIGHT, slotControl, BOTTOMRIGHT, -2, -2)
                badge:SetDrawTier(DT_HIGH)
                badge:SetDrawLayer(DL_OVERLAY)
            end

            local setId = ASGG.slotSetMap[slotId]
            if vars.enabled and vars.highlightEquipment and setId and ASGG.equippedSets[setId] then
                local setData = ASGG.equippedSets[setId]
                local color = setData.color
                glow:SetTexture(vars.glowTexture)
                glow:SetColor(color[1], color[2], color[3], vars.glowIntensity)
                glow:SetHidden(false)

                if setData.isIncomplete and vars.showIncompleteWarning then
                    badge:SetText(string.format("%d/%d", setData.numEquipped, setData.maxEquipped))
                    local wc = vars.colors.warning
                    badge:SetColor(wc[1], wc[2], wc[3], 1.0)
                    badge:SetHidden(false)
                else
                    badge:SetHidden(true)
                end
            else
                glow:SetHidden(true)
                badge:SetHidden(true)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Inventory List Hooking (Backpack, Bank, Deconstruction, etc.)
--------------------------------------------------------------------------------

local function ProcessRowMark(rowControl, slotData)
    if not rowControl or not slotData then return end

    local vars = ASGG.vars or ASGG.defaults
    local button = rowControl:GetNamedChild("Button")
    local iconGlow = button and button:GetNamedChild("ARC_SetGlowGuardGlow")
    local rowBar = rowControl:GetNamedChild("ARC_SetGlowGuardBar")

    if not vars.enabled or not vars.highlightBackpack then
        if iconGlow then iconGlow:SetHidden(true) end
        if rowBar then rowBar:SetHidden(true) end
        return
    end

    local link = slotData.itemLink or (slotData.bagId and slotData.slotIndex and GetItemLink(slotData.bagId, slotData.slotIndex))
    if not link or link == "" then
        if iconGlow then iconGlow:SetHidden(true) end
        if rowBar then rowBar:SetHidden(true) end
        return
    end

    local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(link, false)
    if hasSet and setId and ASGG.equippedSets[setId] then
        local setData = ASGG.equippedSets[setId]
        local color = setData.color

        if button then
            if not iconGlow then
                iconGlow = WINDOW_MANAGER:CreateControl(button:GetName() .. "ARC_SetGlowGuardGlow", button, CT_TEXTURE)
                iconGlow:SetAnchor(TOPLEFT, button, TOPLEFT, -3, -3)
                iconGlow:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, 3, 3)
                iconGlow:SetTexture(vars.glowTexture)
                iconGlow:SetBlendMode(TEX_BLEND_MODE_ADD)
                iconGlow:SetDrawTier(DT_HIGH)
                iconGlow:SetDrawLayer(DL_OVERLAY)
            end
            iconGlow:SetTexture(vars.glowTexture)
            iconGlow:SetColor(color[1], color[2], color[3], vars.glowIntensity)
            iconGlow:SetHidden(false)
        end

        if vars.showRowBar then
            if not rowBar then
                rowBar = WINDOW_MANAGER:CreateControl(rowControl:GetName() .. "ARC_SetGlowGuardBar", rowControl, CT_TEXTURE)
                rowBar:SetAnchor(TOPLEFT, rowControl, TOPLEFT, 2, 2)
                rowBar:SetAnchor(BOTTOMLEFT, rowControl, BOTTOMLEFT, 2, -2)
                rowBar:SetWidth(4)
                rowBar:SetDrawTier(DT_HIGH)
                rowBar:SetDrawLayer(DL_OVERLAY)
            end
            rowBar:SetColor(color[1], color[2], color[3], 0.95)
            rowBar:SetHidden(false)
        elseif rowBar then
            rowBar:SetHidden(true)
        end
    else
        if iconGlow then iconGlow:SetHidden(true) end
        if rowBar then rowBar:SetHidden(true) end
    end
end

function ASGG.HookScrollList(scrollList)
    if not scrollList or hookedLists[scrollList] then return end
    hookedLists[scrollList] = true

    if scrollList.dataTypes then
        for dataTypeId, dataTypeTable in pairs(scrollList.dataTypes) do
            if dataTypeTable and dataTypeTable.setupCallback then
                SecurePostHook(dataTypeTable, "setupCallback", function(rowControl, slotData)
                    ProcessRowMark(rowControl, slotData)
                end)
            end
        end
    end
end

function ASGG.HookAllItemLists()
    local targetLists = {
        ZO_PlayerInventoryList,
        ZO_PlayerBankBackpack,
        ZO_GuildBankBackpack,
        ZO_HouseBankBackpack,
        ZO_SmithingTopLevelDeconstructionPanelInventoryBackpack,
        ZO_SmithingTopLevelImprovementPanelInventoryBackpack,
        ZO_UniversalDeconstructionTopLevel_KeyboardPanelInventoryBackpack,
    }

    for _, listCtrl in ipairs(targetLists) do
        if listCtrl then
            ASGG.HookScrollList(listCtrl)
        end
    end
end

--------------------------------------------------------------------------------
-- Inventory ('I') & Character Sheet Integration
--------------------------------------------------------------------------------

function ASGG.UpdateInventoryAttachment()
    invScene = invScene or SCENE_MANAGER:GetScene("inventory")
    charFragm = charFragm or CHARACTER_WINDOW_FRAGMENT
    if not invScene or not charFragm then return end

    local vars = ASGG.vars or ASGG.defaults
    if vars.autoShowCharacterOnInventory then
        if not invScene:HasFragment(charFragm) then
            invScene:AddFragment(charFragm)
        end
    else
        if invScene:HasFragment(charFragm) then
            invScene:RemoveFragment(charFragm)
        end
    end
end

--------------------------------------------------------------------------------
-- Full Refresh Trigger
--------------------------------------------------------------------------------

function ASGG.Refresh()
    ASGG.UpdateEquippedSets()
    ASGG.UpdateEquipmentGlows()
    ASGG.UpdateInventoryAttachment()

    if not ZO_PlayerInventoryList:IsHidden() then
        ZO_ScrollList_RefreshVisible(ZO_PlayerInventoryList)
    end
end

--------------------------------------------------------------------------------
-- Gold Donation to @arcsinan
--------------------------------------------------------------------------------

function ASGG.DonateGold(amount)
    local world = GetWorldName()
    if world ~= "" and not string.find(string.lower(world), "eu") then
        local warnFmt = GetString(SI_ARC_SGG_CHAT_SERVER_WARN)
        d(string.format(warnFmt, tostring(world)))
    end

    local goldAmount = tonumber(amount) or 5000

    SCENE_MANAGER:Show("mailSend")
    zo_callLater(function()
        if ZO_MailSendToField then
            ZO_MailSendToField:SetText("@arcsinan")
        end
        if ZO_MailSendSubjectField then
            ZO_MailSendSubjectField:SetText("ARC_SetGlowGuard Donation")
        end
        if ZO_MailSendBodyField then
            local mailBody = GetString(SI_ARC_SGG_MAIL_BODY)
            ZO_MailSendBodyField:SetText(mailBody)
            ZO_MailSendBodyField:TakeFocus()
        end
        if goldAmount > 0 and QueueMoneyAttachment then
            QueueMoneyAttachment(goldAmount)
            if ZO_MailSendSendCurrency and ZO_MailSendSendCurrency.OnBeginInput then
                ZO_MailSendSendCurrency:OnBeginInput()
            end
        end
    end, 250)
end

--------------------------------------------------------------------------------
-- Initialization & Event Handling
--------------------------------------------------------------------------------

local function OnInventorySlotUpdate(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason)
    ASGG.Refresh()
end

local function OnActiveWeaponPairChanged(eventCode, activeWeaponPair)
    zo_callLater(function() ASGG.Refresh() end, 100)
end

local function OnPlayerActivated(eventCode)
    EVENT_MANAGER:UnregisterForEvent(ASGG.name .. "_Activated", EVENT_PLAYER_ACTIVATED)

    ASGG.HookAllItemLists()
    ASGG.Refresh()

    INVENTORY_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_FRAGMENT_SHOWING or newState == SCENE_FRAGMENT_SHOWN then
            ASGG.Refresh()
        end
    end)

    local statsScene = SCENE_MANAGER:GetScene("stats")
    if statsScene then
        statsScene:RegisterCallback("StateChange", function(oldState, newState)
            if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                ASGG.Refresh()
            end
        end)
    end
end

local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= ASGG.name then return end

    EVENT_MANAGER:UnregisterForEvent(ASGG.name, EVENT_ADD_ON_LOADED)

    local worldName = GetWorldName()
    ASGG.vars = ZO_SavedVars:NewAccountWide("ARC_SetGlowGuard_SavedVariables", 1, worldName, ASGG.defaults, nil, nil)

    if ASGG.vars.language == "tr" and ASGG.ApplyTurkishStrings then
        ASGG.ApplyTurkishStrings()
    end

    if ASGG.InitSettings then
        ASGG.InitSettings()
    end

    -- Register Slash Commands inside OnAddOnLoaded to ensure SavedVars are ready
    SLASH_COMMANDS["/sgg"] = function(args)
        if args == "settings" or args == "menu" then
            if LibAddonMenu2 and LibAddonMenu2.OpenToPanel and ASGG.settingsPanel then
                LibAddonMenu2:OpenToPanel(ASGG.settingsPanel)
            end
        else
            ASGG.Refresh()
            local refreshFmt = GetString(SI_ARC_SGG_CHAT_REFRESHED)
            d(string.format(refreshFmt, tonumber(ASGG.numEquippedSets) or 0))
            for setId, setData in pairs(ASGG.equippedSets) do
                local statusStr
                if setData.isIncomplete then
                    local incFmt = GetString(SI_ARC_SGG_CHAT_INCOMPLETE)
                    statusStr = string.format(incFmt, setData.numEquipped, setData.maxEquipped)
                else
                    local compFmt = GetString(SI_ARC_SGG_CHAT_COMPLETE)
                    statusStr = string.format(compFmt, setData.numEquipped, setData.maxEquipped)
                end
                d(string.format("  - %s %s", setData.name, statusStr))
            end
        end
    end
    SLASH_COMMANDS["/setglow"] = SLASH_COMMANDS["/sgg"]

    -- Engine-level event filters to prevent unnecessary calls on durability/charge changes
    EVENT_MANAGER:RegisterForEvent(ASGG.name .. "_SlotWorn", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotUpdate)
    EVENT_MANAGER:AddFilterForEvent(ASGG.name .. "_SlotWorn", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    EVENT_MANAGER:AddFilterForEvent(ASGG.name .. "_SlotWorn", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)

    EVENT_MANAGER:RegisterForEvent(ASGG.name .. "_SlotBag", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotUpdate)
    EVENT_MANAGER:AddFilterForEvent(ASGG.name .. "_SlotBag", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    EVENT_MANAGER:AddFilterForEvent(ASGG.name .. "_SlotBag", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)

    EVENT_MANAGER:RegisterForEvent(ASGG.name .. "_FullUpdate", EVENT_INVENTORY_FULL_UPDATE, function() ASGG.Refresh() end)
    EVENT_MANAGER:RegisterForEvent(ASGG.name .. "_WeaponSwap", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnActiveWeaponPairChanged)
    EVENT_MANAGER:RegisterForEvent(ASGG.name .. "_Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    if IsPlayerActivated and IsPlayerActivated() then
        zo_callLater(function()
            ASGG.HookAllItemLists()
            ASGG.Refresh()
        end, 200)
    end
end

EVENT_MANAGER:RegisterForEvent(ASGG.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
