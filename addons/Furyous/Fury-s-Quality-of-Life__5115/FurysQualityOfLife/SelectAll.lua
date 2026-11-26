-- Fury's Quality of Life - Select all on the deconstruct screens
-- A button next to the big item slot on every deconstruct screen of the keyboard interface:
-- blacksmithing, clothing, woodworking and jewelry stations, the enchanting table (extraction)
-- and the deconstruct-anything screen that assistants such as Giladil the Ragpicker open. One
-- click puts every item of the list on screen into the slot, through the game's own "add this
-- item" call, so the game's limits and its confirm pop-up stay in charge. It only selects:
-- nothing is deconstructed until the player presses the game's Deconstruct key.

local QOL = FurysQualityOfLife

local QUALITY_NAMES = {
    [ITEM_FUNCTIONAL_QUALITY_NORMAL] = "Normal",
    [ITEM_FUNCTIONAL_QUALITY_MAGIC] = "Fine",
    [ITEM_FUNCTIONAL_QUALITY_ARCANE] = "Superior",
    [ITEM_FUNCTIONAL_QUALITY_ARTIFACT] = "Epic",
    [ITEM_FUNCTIONAL_QUALITY_LEGENDARY] = "Legendary",
}
QOL.QUALITY_NAMES = QUALITY_NAMES

local GLYPH_TYPES = {
    [ITEMTYPE_GLYPH_ARMOR] = true,
    [ITEMTYPE_GLYPH_WEAPON] = true,
    [ITEMTYPE_GLYPH_JEWELRY] = true,
}

-- Why an item is left out, in the order the chat line lists them.
local REASONS = { "locked", "saver", "uncollected", "set", "research", "crafted", "armory", "quality" }

local function Count(n, one, many)
    if n == 1 then return "1 " .. one end
    return n .. " " .. many
end

local function ReasonText(reason, n)
    if reason == "locked" then return Count(n, "locked item", "locked items") end
    if reason == "saver" then return n .. " protected by your item saver addon" end
    if reason == "uncollected" then return Count(n, "set piece", "set pieces") .. " not collected yet" end
    if reason == "set" then return Count(n, "set item", "set items") end
    if reason == "research" then return n .. " with a trait to research" end
    if reason == "crafted" then return Count(n, "crafted item", "crafted items") end
    if reason == "armory" then return n .. " in an Armory build" end
    return n .. " better than " .. QUALITY_NAMES[QOL.SV().maxQuality]
end

-- FCO ItemSaver and Item Saver are other people's addons and may not be installed. Neither is
-- needed: when one is running, what it protects from deconstruction is left alone.
local function SaverProtects(bag, slot, isGlyph)
    if FCOIS ~= nil then
        if isGlyph then
            if FCOIS.IsEnchantingExtractionLocked(bag, slot) then return true end
        elseif FCOIS.IsDeconstructionLocked(bag, slot) then
            return true
        end
    end
    if ItemSaver_IsItemSaved ~= nil and ItemSaver_IsItemSaved(bag, slot) then return true end
    return false
end

-- nil when the item may be selected, else one of REASONS.
local function LeftOutBecause(bag, slot)
    local sv = QOL.SV()
    if IsItemPlayerLocked(bag, slot) then return "locked" end
    local isGlyph = GLYPH_TYPES[GetItemType(bag, slot)] == true
    if SaverProtects(bag, slot, isGlyph) then return "saver" end

    if not isGlyph then
        local link = GetItemLink(bag, slot)
        if GetItemLinkSetInfo(link, false) then
            if not sv.takeUncollected and IsItemLinkSetCollectionPiece(link)
                and not IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(link)) then
                return "uncollected"
            end
            if not sv.takeSets then return "set" end
        end
        if not sv.takeResearch and GetItemTraitInformation(bag, slot) == ITEM_TRAIT_INFORMATION_CAN_BE_RESEARCHED then
            return "research"
        end
        if not sv.takeCrafted and IsItemLinkCrafted(link) then return "crafted" end
        if not sv.takeArmory and IsItemInArmory(bag, slot) then return "armory" end
    end

    if GetItemFunctionalQuality(bag, slot) > sv.maxQuality then return "quality" end
    return nil
end
QOL.LeftOutBecause = LeftOutBecause

------------------------------------------------------------------------------
-- The three places. `panel` is the game's object that owns the list (panel.inventory.list),
-- the big slot (panel.extractionSlot) and AddItemToCraft.
------------------------------------------------------------------------------
local function StationPanel() return SMITHING.deconstructionPanel end
local function AssistantPanel() return UNIVERSAL_DECONSTRUCTION.deconstructionPanel end
local function EnchantingPanel() return ENCHANTING end

local places = {
    { id = "Stations", panel = StationPanel, gap = 40 },
    { id = "Assistant", panel = AssistantPanel, gap = 40 },
    -- the enchanting slot sits in a wide ring of art, so the button stands further left
    { id = "Enchanting", panel = EnchantingPanel, gap = 100 },
}

-- `refill` is true when the slot is filled again by itself after a deconstruct. Returns how
-- many items were added.
local function SelectAll(place, refill)
    if ZO_CraftingUtils_IsPerformingCraftProcess() then return 0 end
    local panel = place.panel()
    local slot = panel.extractionSlot

    -- the list as it is on screen: the tab, the sort order and "include banked items" all count
    local items = {}
    for _, entry in ipairs(ZO_ScrollList_GetDataList(panel.inventory.list)) do
        items[#items + 1] = entry.data
    end

    local inSlot, turns = slot:GetNumItems(), 0
    if inSlot > 0 then turns = slot:GetStackCount() end
    local added, waiting, leftTotal, left = 0, 0, 0, {}

    for _, data in ipairs(items) do
        local bag, index = data.bagId, data.slotIndex
        if not slot:ContainsBagAndSlot(bag, index) then
            local reason = LeftOutBecause(bag, index)
            local stack = zo_max(1, data.stackCount)
            if reason then
                left[reason] = (left[reason] or 0) + 1
                leftTotal = leftTotal + 1
            elseif inSlot >= MAX_ITEM_SLOTS_PER_DECONSTRUCTION then
                waiting = waiting + 1
            elseif inSlot > 0 and turns + stack > MAX_ITERATIONS_PER_DECONSTRUCTION then
                -- the game's own limit on how much one go may hold; a smaller stack may still fit
                waiting = waiting + 1
            else
                panel:AddItemToCraft(bag, index)
                if slot:ContainsBagAndSlot(bag, index) then
                    added = added + 1
                    inSlot = inSlot + 1
                    turns = turns + stack
                else
                    waiting = waiting + 1
                end
            end
        end
    end

    if refill then
        -- a refill only speaks when it put something in the slot
        if added > 0 then
            local more = ""
            if waiting > 0 then more = " " .. waiting .. " more after these." end
            QOL.Msg("Next batch: " .. Count(added, "item", "items") .. " selected." .. more)
        end
        return added
    end

    if added == 0 and waiting == 0 and leftTotal == 0 then
        if inSlot > 0 then
            QOL.Msg("Everything in this list is already selected.")
        else
            QOL.Msg("Nothing to select in this list.")
        end
        return 0
    end

    local text = "Nothing new selected."
    if added > 0 then text = "Selected " .. Count(added, "item", "items") .. "." end
    if leftTotal > 0 then
        local parts = {}
        for _, reason in ipairs(REASONS) do
            if left[reason] then parts[#parts + 1] = ReasonText(reason, left[reason]) end
        end
        text = text .. " Left out " .. leftTotal .. ": " .. table.concat(parts, ", ") .. "."
    end
    if waiting > 0 then
        text = text .. " " .. Count(waiting, "more is", "more are") .. " waiting: the game takes up to "
            .. MAX_ITEM_SLOTS_PER_DECONSTRUCTION .. " at a time, "
        if QOL.SV().keepFilled then
            text = text .. "and the next batch follows when you deconstruct."
        else
            text = text .. "so deconstruct and click Select all again."
        end
    end
    QOL.Msg(text)
    return added
end

-- Keep the slot filled: after Select all, every deconstruct is followed by the next batch,
-- until the list is empty, Select none is clicked or the station is closed.
local keepFilling = nil   -- the place whose slot is being kept filled

local function Refill()
    local place = keepFilling
    if not place or not QOL.SV().keepFilled or place.button:IsHidden() then
        keepFilling = nil
        return
    end
    if place.panel().extractionSlot:GetNumItems() > 0 then return end   -- the deconstruct did not go through
    if SelectAll(place, true) == 0 then keepFilling = nil end
end

local function ClickSelectAll(place)
    local added = SelectAll(place, false)
    if QOL.SV().keepFilled and added > 0 then
        keepFilling = place
    end
end

-- Empties the slot again, the same as the game's own "Remove all" key.
local function SelectNone(place)
    if ZO_CraftingUtils_IsPerformingCraftProcess() then return end
    keepFilling = nil
    place.panel():ClearSelections()
end

------------------------------------------------------------------------------
-- The buttons: Select all and, under it, Select none
------------------------------------------------------------------------------
local NONE_TIP = "Takes every item out of the slot again, and stops keeping the slot filled. Nothing is deconstructed or destroyed."

local function KeepText()
    if QOL.SV().keepFilled then
        return "\n\nKeep the slot filled is on: after each deconstruct the next batch is selected for you. Select none stops it."
    end
    return ""
end

local function TipText()
    local sv = QOL.SV()
    local skips = { "items you locked", "items your item saver addon protects" }
    if not sv.takeSets then
        skips[#skips + 1] = "set items"
    elseif not sv.takeUncollected then
        skips[#skips + 1] = "set pieces you have not collected yet"
    end
    if not sv.takeResearch then skips[#skips + 1] = "gear with a trait you can still research" end
    if not sv.takeCrafted then skips[#skips + 1] = "crafted gear" end
    if not sv.takeArmory then skips[#skips + 1] = "gear in an Armory build" end
    if sv.maxQuality < ITEM_FUNCTIONAL_QUALITY_LEGENDARY then
        skips[#skips + 1] = "anything better than " .. QUALITY_NAMES[sv.maxQuality]
    end
    return "Puts every item of this list into the slot, up to " .. MAX_ITEM_SLOTS_PER_DECONSTRUCTION
        .. " at a time. Nothing is deconstructed until you press the Deconstruct key yourself.\n\nLeaves out: "
        .. table.concat(skips, ", ") .. "." .. KeepText() .. "\n\nChange this with /qol settings."
end

local function MakeButton(place)
    local slotControl = place.panel().extractionSlot.control
    local button = WINDOW_MANAGER:CreateControlFromVirtual("FurysQualityOfLife_SelectAll" .. place.id,
        slotControl:GetParent(), "ZO_DefaultButton")
    button:SetDimensions(150, 30)
    button:SetAnchor(RIGHT, slotControl, LEFT, -place.gap, -18)
    button:SetText("Select all")
    button:SetHandler("OnClicked", function() ClickSelectAll(place) end)
    QOL.Theme.Tip(button, TipText)
    button:SetHidden(true)
    place.button = button

    local none = WINDOW_MANAGER:CreateControlFromVirtual("FurysQualityOfLife_SelectNone" .. place.id,
        slotControl:GetParent(), "ZO_DefaultButton")
    none:SetDimensions(150, 30)
    none:SetAnchor(TOP, button, BOTTOM, 0, 6)
    none:SetText("Select none")
    none:SetHandler("OnClicked", function() SelectNone(place) end)
    QOL.Theme.Tip(none, NONE_TIP)
    none:SetHidden(true)
    place.none = none
end

-- Shows the buttons only while the switch is on.
function QOL.RefreshSelectAll()
    local hidden = not QOL.SV().selectAll
    for _, place in ipairs(places) do
        place.button:SetHidden(hidden)
        place.none:SetHidden(hidden)
    end
end

local function SetButtonsEnabled(enabled)
    for _, place in ipairs(places) do
        place.button:SetEnabled(enabled)
        place.none:SetEnabled(enabled)
    end
end
local function OnCraftStarted() SetButtonsEnabled(false) end
local function OnCraftStopped()
    SetButtonsEnabled(true)
    -- a moment for the game to take the deconstructed items out of the list
    if keepFilling then zo_callLater(Refill, 400) end
end
local function OnStationClosed() keepFilling = nil end

-- The key binding and /qol select: the same as a click on the button that is on screen.
function QOL.SelectAllKey()
    for _, place in ipairs(places) do
        if not place.button:IsHidden() then
            ClickSelectAll(place)
            return
        end
    end
end

function QOL.InitSelectAll()
    for _, place in ipairs(places) do
        MakeButton(place)
    end
    CALLBACK_MANAGER:RegisterCallback("CraftingAnimationsStarted", OnCraftStarted)
    CALLBACK_MANAGER:RegisterCallback("CraftingAnimationsStopped", OnCraftStopped)
    EVENT_MANAGER:RegisterForEvent(QOL.name .. "SelectAll", EVENT_END_CRAFTING_STATION_INTERACT, OnStationClosed)
    QOL.RefreshSelectAll()
end
