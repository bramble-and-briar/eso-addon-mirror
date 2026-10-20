------------------------------------------------------------
-- FrankGrinder Mailer (Full Drop-in Replacement)
------------------------------------------------------------

FrankGrinder.mailer = FrankGrinder.mailer or {
    queue = {},
    index = 1,

    attachQueue = {},
    attachIndex = 0,
    attachActive = false,

    uiCreated = false,

    -- GG run state
    active  = false,   -- a GG run is in progress
}

local MAX_ATTACH = 6

------------------------------------------------------------
-- Reset Mailer State
------------------------------------------------------------

function FrankGrinder:ResetMailer()
    local M = self.mailer

    M.queue = {}
    M.index = 1
    M.attachQueue = {}
    M.attachIndex = 0
    M.attachActive = false
    M.active = false

    -- KEYBOARD MODE: clear fields directly
    if MAIL_SEND then
        ClearQueuedMail()

        if MAIL_SEND.to then
            MAIL_SEND.to:SetText("")
        end
        if MAIL_SEND.subject then
            MAIL_SEND.subject:SetText("")
        end
        if MAIL_SEND.body then
            MAIL_SEND.body:SetText("")
        end
    end

    -- GAMEPAD MODE: clear fields directly
    if MAIL_GAMEPAD then
        local send = MAIL_GAMEPAD:GetSend()
        local view = send and send.mailView
        if view then
            view.addressEdit.edit:SetText("")
            view.subjectEdit.edit:SetText("")
            view.bodyEdit.edit:SetText("")
        end
    end
end

------------------------------------------------------------
-- Container ID tables (writ/survey/treasure containers)
------------------------------------------------------------

local UNKNOWN_WRIT_CONTAINER_IDS = {
    [217917] = true,
    [217918] = true,
    [217920] = true,
    [217919] = true,
    [217921] = true,
    [217923] = true,
    [217922] = true,
}

local UNIDENTIFIED_SURVEY_CONTAINER_IDS = {
    [219853] = true,
    [219849] = true,
    [219852] = true,
    [219850] = true,
    [219851] = true,
    [219854] = true,
}

local UNOPENED_TREASURE_CONTAINER_IDS = {
    [224681] = true,
}

function FrankGrinder:IsUnknownWritContainer(itemLink)
    local id = GetItemLinkItemId(itemLink)
    return UNKNOWN_WRIT_CONTAINER_IDS[id] or false
end

function FrankGrinder:IsUnidentifiedSurveyContainer(itemLink)
    local id = GetItemLinkItemId(itemLink)
    return UNIDENTIFIED_SURVEY_CONTAINER_IDS[id] or false
end

function FrankGrinder:IsUnUnopenedTreasureContainer(itemLink)
    local id = GetItemLinkItemId(itemLink)
    return UNOPENED_TREASURE_CONTAINER_IDS[id] or false
end

------------------------------------------------------------
-- Style page detection (no names, collectible category)
------------------------------------------------------------

function FrankGrinder:IsStylePage(itemLink)
    local collectibleId = GetItemLinkContainerCollectibleId(itemLink)
    if collectibleId and collectibleId > 0 then
        local cat = GetCollectibleCategoryType(collectibleId)
        return cat == COLLECTIBLE_CATEGORY_TYPE_APPEARANCE
    end
    return false
end

------------------------------------------------------------
-- Collection status
------------------------------------------------------------

local function GetItemLinkCollectionStatus(itemLink)
    if IsItemLinkSetCollectionPiece(itemLink) then
        local pieceId = GetItemLinkItemId(itemLink)
        if pieceId and IsItemSetCollectionPieceUnlocked(pieceId) then
            return 2
        else
            return 1
        end
    end

    local collectibleId = GetItemLinkContainerCollectibleId(itemLink)
    if collectibleId and collectibleId > 0 then
        if IsCollectibleOwnedByDefId(collectibleId) then
            return 2
        elseif GetCollectibleCategoryType(collectibleId) == COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT
           and not CanCombinationFragmentBeUnlocked(collectibleId) then
            return 2
        else
            return 1
        end
    end

    return 0
end

------------------------------------------------------------
-- BoE set item filter
------------------------------------------------------------

local function IsMailableBoESetItem(bagId, slotIndex)
    if IsItemStolen(bagId, slotIndex) then return false end
    if IsItemBound(bagId, slotIndex) then return false end
    if GetItemBindType(bagId, slotIndex) ~= BIND_TYPE_ON_EQUIP then return false end
    if GetItemEquipType(bagId, slotIndex) == EQUIP_TYPE_INVALID then return false end

    local itemLink = GetItemLink(bagId, slotIndex)
    local hasSet = GetItemLinkSetInfo(itemLink)
    if not hasSet then return false end

    local status = GetItemLinkCollectionStatus(itemLink)
    if status == 1 then return false end

    return true
end

------------------------------------------------------------
-- Unified items filter (recipes + motifs + BoE)
------------------------------------------------------------

local function IsMailableItemsEntry(bagId, slotIndex)
    if IsItemStolen(bagId, slotIndex) then return false end

    local itemType = GetItemType(bagId, slotIndex)
    if itemType == ITEMTYPE_RECIPE or itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
        return true
    end

    return IsMailableBoESetItem(bagId, slotIndex)
end

------------------------------------------------------------
-- Craft bag item filter
------------------------------------------------------------

local CRAFT_BAG_TYPES = {
    [ITEMTYPE_BLACKSMITHING_MATERIAL] = true,
    [ITEMTYPE_BLACKSMITHING_RAW_MATERIAL] = true,
    [ITEMTYPE_BLACKSMITHING_BOOSTER] = true,

    [ITEMTYPE_CLOTHIER_MATERIAL] = true,
    [ITEMTYPE_CLOTHIER_RAW_MATERIAL] = true,
    [ITEMTYPE_CLOTHIER_BOOSTER] = true,

    [ITEMTYPE_WOODWORKING_MATERIAL] = true,
    [ITEMTYPE_WOODWORKING_RAW_MATERIAL] = true,
    [ITEMTYPE_WOODWORKING_BOOSTER] = true,

    [ITEMTYPE_JEWELRYCRAFTING_MATERIAL] = true,
    [ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL] = true,
    [ITEMTYPE_JEWELRYCRAFTING_BOOSTER] = true,
    [ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER] = true,
    [ITEMTYPE_JEWELRY_TRAIT] = true,
    [ITEMTYPE_JEWELRY_RAW_TRAIT] = true,

    [ITEMTYPE_ENCHANTING_RUNE_ASPECT] = true,
    [ITEMTYPE_ENCHANTING_RUNE_ESSENCE] = true,
    [ITEMTYPE_ENCHANTING_RUNE_POTENCY] = true,
    [ITEMTYPE_ENCHANTMENT_BOOSTER] = true,

    [ITEMTYPE_REAGENT] = true,
    [ITEMTYPE_POTION_BASE] = true,
    [ITEMTYPE_POISON_BASE] = true,

    [ITEMTYPE_INGREDIENT] = true,
    [ITEMTYPE_SPICE] = true,
    [ITEMTYPE_FLAVORING] = true,

    [ITEMTYPE_STYLE_MATERIAL] = true,
    [ITEMTYPE_ARMOR_TRAIT] = true,
    [ITEMTYPE_WEAPON_TRAIT] = true,

    [ITEMTYPE_FURNISHING_MATERIAL] = true,

    [ITEMTYPE_SCRIBING_INK] = true,
    [ITEMTYPE_CRAFTED_ABILITY_SCRIPT] = true,

    [ITEMTYPE_RAW_MATERIAL] = true,

    [ITEMTYPE_LURE] = true,
    [ITEMTYPE_FISH] = true,
}

-- Note: "craft bag item" here means "an item type that belongs in the craft
-- bag", matched against the backpack. The craft bag itself (BAG_VIRTUAL) is
-- never iterated - its contents can't be attached to mail at all.
local function IsCraftBagItem(bagId, slotIndex)
    if IsItemStolen(bagId, slotIndex) then return false end
    local itemType = GetItemType(bagId, slotIndex)
    return CRAFT_BAG_TYPES[itemType] or false
end

------------------------------------------------------------
-- Intricate + Glyph helpers
------------------------------------------------------------

local function IsIntricateTrait(bagId, slotIndex)
    local trait = GetItemTrait(bagId, slotIndex)
    return trait == ITEM_TRAIT_TYPE_ARMOR_INTRICATE
        or trait == ITEM_TRAIT_TYPE_WEAPON_INTRICATE
        or trait == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE
end

-- Determine which crafting discipline the intricate item belongs to
-- so we can honour per-craft mailing settings.
local function GetIntricateDiscipline(bagId, slotIndex)
    local trait = GetItemTrait(bagId, slotIndex)

    -- Jewellery is explicit via trait (and/or equip type)
    if trait == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE then
        return "Jewelry"
    end

    local equipType = GetItemEquipType(bagId, slotIndex)
    if equipType == EQUIP_TYPE_NECK or equipType == EQUIP_TYPE_RING then
        return "Jewelry"
    end

    -- Weapons: split between Blacksmithing and Woodworking
    local weaponType = GetItemWeaponType(bagId, slotIndex)
    if weaponType and weaponType ~= WEAPONTYPE_NONE then
        if weaponType == WEAPONTYPE_BOW
            or weaponType == WEAPONTYPE_FIRE_STAFF
            or weaponType == WEAPONTYPE_FROST_STAFF
            or weaponType == WEAPONTYPE_LIGHTNING_STAFF
            or weaponType == WEAPONTYPE_RESTORATION_STAFF
            or weaponType == WEAPONTYPE_SHIELD
        then
            return "Woodworking"
        else
            return "Blacksmithing"
        end
    end

    -- Armour: heavy = Blacksmithing, light/medium = Clothier
    local armorType = GetItemArmorType(bagId, slotIndex)
    if armorType == ARMORTYPE_HEAVY then
        return "Blacksmithing"
    elseif armorType == ARMORTYPE_MEDIUM or armorType == ARMORTYPE_LIGHT then
        return "Clothier"
    end

    return nil
end


local function IsNonLegendaryGlyph(bagId, slotIndex)
    local t = GetItemType(bagId, slotIndex)
    if t ~= ITEMTYPE_GLYPH_ARMOR
       and t ~= ITEMTYPE_GLYPH_WEAPON
       and t ~= ITEMTYPE_GLYPH_JEWELRY then
        return false
    end

    return GetItemQuality(bagId, slotIndex) ~= ITEM_QUALITY_LEGENDARY
end

------------------------------------------------------------
-- Queue helper
------------------------------------------------------------

function FrankGrinder:QueueMail(account, subject, items)
    if not account or account == "" then return end
    if not items or #items == 0 then return end

    table.insert(self.mailer.queue, {
        account = account,
        subject = subject or "",
        items   = items,
    })
end

------------------------------------------------------------
-- Resolve slot by unique ID
------------------------------------------------------------

local function ResolveSlot(entry)
    local bag = BAG_BACKPACK
    local uid = entry.uniqueId

    if not uid then return entry.slot end

    -- uniqueId is an id64: it must be compared with AreId64sEqual, not ==
    for slot = 0, GetBagSize(bag) - 1 do
        local slotUid = GetItemUniqueId(bag, slot)
        if slotUid and AreId64sEqual(slotUid, uid) then
            return slot
        end
    end

    return nil
end

------------------------------------------------------------
-- Unified Item Classifier for Mailing
------------------------------------------------------------

-- An item that can't leave your hands can't be attached to a mail. Queueing
-- one addresses the mail and then silently fails at QueueItemAttachment, so
-- everything that gets classified has to pass this first.
local function CanMailItem(bagId, slotIndex)
    if IsItemStolen(bagId, slotIndex) then return false end
    if IsItemPlayerLocked(bagId, slotIndex) then return false end

    -- Anything already bound (BoP that has been looted, bound crafting
    -- materials such as scribing inks and scripts, character-bound rewards).
    if IsItemBound(bagId, slotIndex) then return false end

    local bindType = GetItemBindType(bagId, slotIndex)
    if bindType == BIND_TYPE_ON_PICKUP then return false end
    if BIND_TYPE_ON_PICKUP_BACKPACK and bindType == BIND_TYPE_ON_PICKUP_BACKPACK then return false end

    return true
end

function FrankGrinder:ClassifyItemForMail(bagId, slot)
    if not HasItemInSlot(bagId, slot) then return nil end
    if not CanMailItem(bagId, slot) then return nil end

    local itemLink = GetItemLink(bagId, slot)
    local itemType = GetItemType(bagId, slot)

    -- 1. Unknown writ containers
    if self:IsUnknownWritContainer(itemLink) then
        if self:GetSettingMailUnknownWrits() then 
            return { bucket = "writ" } 
        else 
            return nil 
        end
    end

    -- 2. Unidentified survey containers
    if self:IsUnidentifiedSurveyContainer(itemLink) then
        if self:GetSettingMailUnknownSurveys() then 
            return { bucket = "survey" }
        else 
            return nil 
        end
    end

    -- 2a. Unopened Treasure Maps containers
    if self:IsUnUnopenedTreasureContainer(itemLink) then
        if self:GetSettingMailUnknownTreasures() then 
            return { bucket = "treasure" }
        else 
            return nil 
        end
    end

    -- 3. Intricate gear
    if IsIntricateTrait(bagId, slot) then
        local discipline = GetIntricateDiscipline(bagId, slot)

        local enabled = true
        if discipline == "Woodworking" then
            enabled = self:GetSettingMailIntricateWoodcrafting()
        elseif discipline == "Clothier" then
            enabled = self:GetSettingMailIntricateClothier()
        elseif discipline == "Blacksmithing" then
            enabled = self:GetSettingMailIntricateBlacksmithing()
        elseif discipline == "Jewelry" then
            enabled = self:GetSettingMailIntricateJewelry()
        end

        if enabled then
            return { bucket = "intricate", discipline = discipline }
        else
            return nil
        end
    end

    -- 4. Glyphs
    if IsNonLegendaryGlyph(bagId, slot) then
        if self:GetSettingMailGlyphs() then 
            return { bucket = "glyph" }
        else 
            return nil 
        end
    end

    -- 5. Crafting Mats
    if IsCraftBagItem(bagId, slot) then
        if self:GetSettingMailCraftingMats() then 
            return { bucket = "mats" }
        else 
            return nil 
        end
    end

    -- 6. BoE Set Items
    if IsMailableBoESetItem(bagId, slot) then
        if self:GetSettingMailBoEItems() then 
            return { bucket = "boe" }
        else 
            return nil 
        end
    end

    -- 7. Recipes
    if itemType == ITEMTYPE_RECIPE then
        local route = self:ResolveRoutingTarget(itemLink)
        return { bucket = "recipe", route = route }
    end

    -- 8. Motifs
    if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
        local route = self:ResolveRoutingTarget(itemLink)
        return { bucket = "motif", route = route }
    end

    -- 9. Style pages (collectible appearance)
    if self:IsStylePage(itemLink) then
        local route = self:ResolveRoutingTarget(itemLink)
        return { bucket = "style", route = route }
    end

    -- 11. Other mailable items (recipes/motifs/BoE)
    if IsMailableItemsEntry(bagId, slot) then
        local route = self:ResolveRoutingTarget(itemLink)
        return { bucket = "items", route = route }
    end

    return nil
end

function FrankGrinder:ResolveMailRecipient(info)
  if not info or not info.bucket then return nil end

  local acctItems = self:GetSettingMailItemsAccount()
  local acctMats  = self:GetSettingMailMatsAccount()

  -- Always-to-items-account buckets
  if info.bucket == "intricate" then return acctItems end
  if info.bucket == "glyph"     then return acctItems end
  if info.bucket == "boe"       then return acctItems end

  -- Knowledge-directed buckets (recipes/motifs/style/general items)
  if info.bucket == "items" or info.bucket == "recipe" or info.bucket == "motif" or info.bucket == "style" then
    if info.route then
      -- Learn-routing: mail only if cross-account; same-account => nil (do not mail)
      if info.route.reason ~= "Sell" then
        return info.route.mailToAccount -- nil when same-account
      end

      -- Sell-routing: always consolidate to Items account
      return acctItems
    end

    -- No routing info => do not mail (safer than leaking learnables into mail)
    return nil
  end

  -- Crafter account (writ/survey/treasure containers)
  if info.bucket == "survey" or info.bucket == "writ" or info.bucket == "treasure" then
    local _, crafterAccount = self:PA_GetCharacterIdCached(self:GetSettingCrafterCharacterName(), "crafter")
    if GetDisplayName() == crafterAccount then
      return nil
    end
    return crafterAccount
  end

  -- Mats account
  if info.bucket == "mats" then
    return acctMats
  end

  return nil
end

function FrankGrinder:BuildQueue_LooseItems()
  local buckets = {}
  local acctItems = self:GetSettingMailItemsAccount()

  local function add(slot)
    if not acctItems or acctItems == "" then return end
    buckets[acctItems] = buckets[acctItems] or {}
    table.insert(buckets[acctItems], {
      slot = slot,
      uniqueId = GetItemUniqueId(BAG_BACKPACK, slot),
    })
  end

  for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
    local info = self:ClassifyItemForMail(BAG_BACKPACK, slot)
    if info then
      if info.bucket == "intricate"
        or info.bucket == "glyph"
        or info.bucket == "boe"
        or (info.route and info.route.reason == "Sell")
      then
        self:DebugMailCandidate("Items", slot, info)
        add(slot)
      end
    end
  end

  for account, items in pairs(buckets) do
    self:QueueMail(account, "GG: Items", items)
  end
end

------------------------------------------------------------
-- BuildQueue_Directed (Directed button)
------------------------------------------------------------

function FrankGrinder:BuildQueue_Directed()
    local buckets = {}

    local function add(account, slot)
        if not account or account == "" then return end
        buckets[account] = buckets[account] or {}
        table.insert(buckets[account], {
            slot = slot,
            uniqueId = GetItemUniqueId(BAG_BACKPACK, slot),
        })
    end

    for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
        local info = self:ClassifyItemForMail(BAG_BACKPACK, slot)
        if info then
            if
                info.bucket == "writ"
                or info.bucket == "survey"
                or info.bucket == "treasure"
                or (info.bucket == "motif"
                    and info.route
                    and info.route.reason ~= "Sell")
                or (info.bucket == "style"
                    and info.route
                    and info.route.reason ~= "Sell")
                or (info.bucket == "recipe"
                    and info.route
                    and info.route.reason ~= "Sell")
                or (info.bucket == "items"
                    and info.route
                    and info.route.reason ~= "Sell")
            then
                self:DebugMailCandidate("Directed", slot, info)
                local account = self:ResolveMailRecipient(info)
                add(account, slot)
            end
        end
    end

    for account, items in pairs(buckets) do
        self:QueueMail(account, "GG: Directed", items)
    end
end

------------------------------------------------------------
-- Debug: report what a build pass picked up and why
------------------------------------------------------------

function FrankGrinder:DebugMailCandidate(queueName, slot, info)
    if not self:IsDebugEnabled() then return end

    self:DebugMsg(string.format("%s: slot %d %s -> bucket=%s route=%s",
        queueName,
        slot,
        tostring(GetItemLink(BAG_BACKPACK, slot)),
        tostring(info and info.bucket),
        tostring(info and info.route and info.route.reason or "none")))
end

------------------------------------------------------------
-- BuildQueue_Mats (Mats button)
------------------------------------------------------------

function FrankGrinder:BuildQueue_Mats()
    local buckets = {}
    local acctMats = self:GetSettingMailMatsAccount()

    local function add(slot)
        if not acctMats or acctMats == "" then return end
        buckets[acctMats] = buckets[acctMats] or {}
        table.insert(buckets[acctMats], {
            slot = slot,
            uniqueId = GetItemUniqueId(BAG_BACKPACK, slot),
        })
    end

    for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
        local info = self:ClassifyItemForMail(BAG_BACKPACK, slot)
        if info and info.bucket == "mats" then
            self:DebugMailCandidate("Mats", slot, info)
            add(slot)
        end
    end

    for account, items in pairs(buckets) do
        self:QueueMail(account, "GG: Mats", items)
    end
end

------------------------------------------------------------
-- Attachment Pipeline
------------------------------------------------------------

local ATTACH_TIMEOUT_MS = 5000

local ProcessNextAttachment

-- If the game never fires EVENT_MAIL_ATTACHMENT_ADDED for the slot we just
-- queued (bag full, item became untradeable, ...) the chain would stall
-- silently with attachActive = true. Abort the run instead.
local function ScheduleAttachWatchdog(slot)
    local M = FrankGrinder.mailer
    local expectedIndex = M.attachIndex
    local itemLink = GetItemLink(BAG_BACKPACK, slot)

    M.attachWatchdogToken = (M.attachWatchdogToken or 0) + 1
    local token = M.attachWatchdogToken

    zo_callLater(function()
        local m = FrankGrinder.mailer
        if not m.attachActive then return end
        if m.attachWatchdogToken ~= token then return end
        if m.attachIndex ~= expectedIndex then return end

        -- Name the item: this almost always means it can't be mailed at all
        FrankGrinder:ChatMsg("|cFF4444Could not attach " .. tostring(itemLink)
            .. " - mailing run cancelled|r")
        FrankGrinder:ResetMailer()
    end, ATTACH_TIMEOUT_MS)
end

ProcessNextAttachment = function()
    local M = FrankGrinder.mailer
    if not M.attachActive then return end

    M.attachIndex = M.attachIndex + 1
    local entry = M.attachQueue[M.attachIndex]

    if not entry then
        M.attachActive = false
        return
    end

    local slot = ResolveSlot(entry)
    if slot then
        QueueItemAttachment(BAG_BACKPACK, slot, M.attachIndex)
        ScheduleAttachWatchdog(slot)
    else
        -- Item moved or was consumed since the queue was built: skip it and
        -- keep going rather than leaving the chain wedged.
        FrankGrinder:ChatMsg("|cFF4444Could not resolve slot for attachment - skipped|r")
        M.attachIndex = M.attachIndex - 1
        table.remove(M.attachQueue, M.attachIndex + 1)
        zo_callLater(ProcessNextAttachment, 10)
    end
end

local function OnAttachmentAdded()
    if FrankGrinder.mailer.attachActive then
        zo_callLater(ProcessNextAttachment, 10)
    end
end

------------------------------------------------------------
-- Prepare next mail in queue
------------------------------------------------------------

function FrankGrinder:PrepareNextMail()
    local M = self.mailer

    -- If run was cancelled, do nothing
    if not M.active then
        return
    end

    local mail = M.queue[M.index]

    if not mail then
        self:ChatMsg("|c00FF00Mailing complete|r")
        self:ResetMailer()
        return
    end

    if not mail.items or #mail.items == 0 then
        M.index = M.index + 1
        self:PrepareNextMail()
        return
    end

    if #mail.items > MAX_ATTACH then
        local remainder = {}
        for i = MAX_ATTACH + 1, #mail.items do
            table.insert(remainder, mail.items[i])
        end

        local first = {}
        for i = 1, MAX_ATTACH do
            table.insert(first, mail.items[i])
        end

        mail.items = first

        table.insert(M.queue, M.index + 1, {
            account = mail.account,
            subject = mail.subject,
            items   = remainder,
        })
    end

    -- Set fields (keyboard or gamepad) WITHOUT calling ClearFields
    if IsInGamepadPreferredMode() and MAIL_GAMEPAD then
        local send = MAIL_GAMEPAD:GetSend()
        local view = send and send.mailView
        if view then
            view.addressEdit.edit:SetText(mail.account)
            view.subjectEdit.edit:SetText(mail.subject)
            view.bodyEdit.edit:SetText("")
        end
    elseif MAIL_SEND then
        ClearQueuedMail()

        if MAIL_SEND.to then
            MAIL_SEND.to:SetText(mail.account)
        end
        if MAIL_SEND.subject then
            MAIL_SEND.subject:SetText(mail.subject)
        end
        if MAIL_SEND.body then
            MAIL_SEND.body:LoseFocus()
            MAIL_SEND.body:SetText("")
        end
    end

    M.attachQueue = mail.items
    M.attachIndex = 0
    M.attachActive = true

    zo_callLater(ProcessNextAttachment, 10)

end

------------------------------------------------------------
-- Mail sent -> continue (only if a GG mail was pending)
------------------------------------------------------------

local function OnMailSendSuccess()
    local M = FrankGrinder.mailer

    -- If no active GG run, ignore this send (manual mail)
    if not M.active then
        return
    end

    -- If mail UI is no longer visible, cancel the run
    local isKeyboard = MAIL_SEND_SCENE and MAIL_SEND_SCENE:IsShowing()
    local isGamepad  = MAIL_GAMEPAD_SCENE and MAIL_GAMEPAD_SCENE:IsShowing()
    if not isKeyboard and not isGamepad then
        FrankGrinder:ResetMailer()
        return
    end

    -- Advance to next mail in queue
    M.index = M.index + 1

    zo_callLater(function()
        if IsInGamepadPreferredMode() and MAIL_GAMEPAD then
            zo_callLater(function()
                MAIL_GAMEPAD:ShowTab(ZO_MAIL_TAB_INDEX.SEND, false)
            end, 50)
        end

        FrankGrinder:PrepareNextMail()
    end, 200)
end

------------------------------------------------------------
-- UI Injection (Send Mail Scene)
------------------------------------------------------------

function FrankGrinder:CreateMailer_Gamepad()
    if not ZO_MailSend_Gamepad or not ZO_MailSend_Gamepad.PopulateMainList then
        return
    end

    -- Only hook once on the class
    if ZO_MailSend_Gamepad._FG_Hooked then return end
    ZO_MailSend_Gamepad._FG_Hooked = true

    local original = ZO_MailSend_Gamepad.PopulateMainList

    ZO_MailSend_Gamepad.PopulateMainList = function(self, ...)
        -- Let the base game build its list first
        original(self, ...)

        -- Respect the setting: the hook is permanent, the entries are not
        if not FrankGrinder:GetSettingMailToOtherAccountEnabled() then
            return
        end

        -- AddMainListEntry(text, header, icon, callback, ...) - the header is
        -- drawn above the entry it is attached to, so it goes on the first of
        -- the group, the same way the base game heads "Attach Items" with
        -- "Items" and "Send" with "Send".
        self:AddMainListEntry("GG Items", FrankGrinder.displayTitle, nil, function()
            FrankGrinder:StartMailing(function()
                FrankGrinder:BuildQueue_LooseItems()
            end)
        end)

        self:AddMainListEntry("GG Directed", nil, nil, function()
            FrankGrinder:StartMailing(function()
                FrankGrinder:BuildQueue_Directed()
            end)
        end)

        self:AddMainListEntry("GG Mats", nil, nil, function()
            FrankGrinder:StartMailing(function()
                FrankGrinder:BuildQueue_Mats()
            end)
        end)

        -- Recommit so A/select works on our entries
        if self.mainList then
            self.mainList:Commit()
        end
    end
end

function FrankGrinder:CreateMailer_Keyboard()
    if self.mailer.uiCreated then return end

    local parent = ZO_MailSend
    if not parent then return end

    local function makeButton(name, text, offsetX, handler)
        local btn = CreateControlFromVirtual(name, parent, "ZO_DefaultButton")
        btn:SetAnchor(TOPLEFT, parent, TOPLEFT, offsetX, 10)
        btn:SetWidth(80)
        btn:SetText(text)
        btn:SetHandler("OnClicked", handler)
        return btn
    end

    makeButton("FrankGrinder_SendItems",    "Items",      0, function() self:StartMailing(function() self:BuildQueue_LooseItems() end) end)
    makeButton("FrankGrinder_SendDirected", "Directed",  90, function() self:StartMailing(function() self:BuildQueue_Directed() end) end)
    makeButton("FrankGrinder_SendMats",     "Mats",     180, function() self:StartMailing(function() self:BuildQueue_Mats() end) end)

    self.mailer.uiCreated = true
end

------------------------------------------------------------
-- Start mailing (shared entry point)
------------------------------------------------------------

function FrankGrinder:StartMailing(buildFn)
    local isKeyboard = MAIL_SEND_SCENE and MAIL_SEND_SCENE:IsShowing()
    local isGamepad  = MAIL_GAMEPAD_SCENE and MAIL_GAMEPAD_SCENE:IsShowing()

    if not isKeyboard and not isGamepad then
        self:ChatMsg("|cFFAA00Open the Send Mail tab first|r")
        return
    end

    -- Fresh run
    self:ResetMailer()
    buildFn()

    if #self.mailer.queue == 0 then
        self:ChatMsg("|cAAAAAANothing to send|r")
        return
    end

    -- Mark that a GG run is now active
    self.mailer.active = true

    self:PrepareNextMail()
end

------------------------------------------------------------
-- Initialization
------------------------------------------------------------

-- Shows/hides the keyboard buttons to match the setting. The gamepad list
-- entries are added by the PopulateMainList hook, which checks the setting
-- itself, so there is nothing to toggle there.
function FrankGrinder:SetMailerButtonsShown(shown)
    for _, name in ipairs({ "FrankGrinder_SendItems", "FrankGrinder_SendDirected", "FrankGrinder_SendMats" }) do
        local btn = _G[name]
        if btn then btn:SetHidden(not shown) end
    end
end

function FrankGrinder:InitializeMailer()
    local enabled = self.GetSettingMailToOtherAccountEnabled
        and self:GetSettingMailToOtherAccountEnabled()

    if not enabled then
        -- Setting may have just been turned off: tear down and cancel any run.
        if self._mailerInstalled then
            EVENT_MANAGER:UnregisterForEvent("FrankGrinderMailerAttach", EVENT_MAIL_ATTACHMENT_ADDED)
            EVENT_MANAGER:UnregisterForEvent("FrankGrinderMailerSent", EVENT_MAIL_SEND_SUCCESS)
            self:ResetMailer()
            self:SetMailerButtonsShown(false)
            self._mailerInstalled = false
        end
        return
    end

    if self._mailerInstalled then
        self:SetMailerButtonsShown(true)
        return
    end

    ------------------------------------------------------------
    -- EVENT HOOKS
    ------------------------------------------------------------

    EVENT_MANAGER:RegisterForEvent("FrankGrinderMailerAttach", EVENT_MAIL_ATTACHMENT_ADDED, OnAttachmentAdded)
    EVENT_MANAGER:RegisterForEvent("FrankGrinderMailerSent", EVENT_MAIL_SEND_SUCCESS, OnMailSendSuccess)

    ------------------------------------------------------------
    -- CANCEL RUN WHEN MAIL UI CLOSES
    -- Registered once for the life of the session: RegisterCallback has no
    -- matching unregister here, so re-registering would stack duplicates.
    ------------------------------------------------------------

    if not self._mailerScenesHooked then
        self._mailerScenesHooked = true

        if MAIL_SEND_SCENE then
            MAIL_SEND_SCENE:RegisterCallback("StateChange", function(_, newState)
                if newState == SCENE_HIDDEN then
                    FrankGrinder:ResetMailer()
                end
            end)
        end

        if MAIL_GAMEPAD_SCENE then
            MAIL_GAMEPAD_SCENE:RegisterCallback("StateChange", function(_, newState)
                if newState == SCENE_HIDDEN then
                    FrankGrinder:ResetMailer()
                end
            end)
        end
    end

    ------------------------------------------------------------
    -- CREATE UI BUTTONS (KEYBOARD + GAMEPAD)
    ------------------------------------------------------------

    self:CreateMailer_Keyboard()
    self:CreateMailer_Gamepad()
    self:SetMailerButtonsShown(true)

    self._mailerInstalled = true
end
