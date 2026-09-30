-- Enchant+ integration adapted from the user-supplied EnchantPlus.lua.
-- Shared by Suite grid cells and native backpack/equipped-item context menus.
-- v0.29.517 - direct backpack glyph scan + native Enchant row/height collapse.
EASEnchantPlus = {}
local EP = EASEnchantPlus
local eventName = "EAS_EnchantPlus"

local function ItemIdentity(bag, slot)
    return Id64ToString(GetItemUniqueId(bag, slot))
end

local function SameItem(bag, slot, uniqueId)
    return ItemIdentity(bag, slot) == uniqueId
end

local function SupportsTarget(bag, slot)
    return (bag == BAG_BACKPACK or bag == BAG_WORN)
        and slot ~= nil and IsItemEnchantable(bag, slot)
end

function EP.ClearGlyphTooltip(owner)
    if owner and EP.tooltipOwner ~= owner then return end
    EP.tooltipOwner = nil
    EP.tooltipSerial = (EP.tooltipSerial or 0) + 1
    if ItemTooltip then
        ClearTooltip(ItemTooltip)
        ItemTooltip:SetScale(1)
    end
end

function EP.ClearInventoryTooltips()
    EP.ClearGlyphTooltip()
    if ComparativeTooltip1 then ClearTooltip(ComparativeTooltip1) end
    if ComparativeTooltip2 then ClearTooltip(ComparativeTooltip2) end
end

function EP.TooltipPlacement(left, top, right, bottom, width, height, screenW, screenH)
    local gap, margin = 12, 8
    local spaces = {
        {x=right+gap, y=margin, w=screenW-margin-right-gap, h=screenH-2*margin},
        {x=margin, y=margin, w=left-gap-margin, h=screenH-2*margin},
        {x=margin, y=bottom+gap, w=screenW-2*margin, h=screenH-margin-bottom-gap},
        {x=margin, y=margin, w=screenW-2*margin, h=top-gap-margin},
    }
    local best, scale = nil, 0
    for _, area in ipairs(spaces) do
        if area.w > 0 and area.h > 0 then
            local fit = math.min(1, area.w / math.max(1, width), area.h / math.max(1, height))
            if fit > scale then best, scale = area, fit end
        end
    end
    if not best then return nil end
    local x = math.max(best.x, math.min(left, best.x + best.w - width*scale))
    local y = math.max(best.y, math.min(top, best.y + best.h - height*scale))
    return x, y, scale
end

function EP.PositionGlyphTooltip(control)
    if EP.tooltipOwner ~= control then return end
    local left, top, right, bottom = control:GetLeft(), control:GetTop(), control:GetRight(), control:GetBottom()
    local function include(panel)
        if panel and not panel:IsHidden() then
            left = math.min(left, panel:GetLeft())
            top = math.min(top, panel:GetTop())
            right = math.max(right, panel:GetRight())
            bottom = math.max(bottom, panel:GetBottom())
        end
    end
    include(ZO_Menu)
    include(rawget(_G, "LibCustomMenuSubmenu"))
    local parent = control:GetParent()
    if parent and parent ~= GuiRoot and parent ~= ZO_Menu then include(parent) end
    local tip = ItemTooltip
    tip:SetScale(1)
    local x, y, scale = EP.TooltipPlacement(left, top, right, bottom,
        tip:GetWidth(), tip:GetHeight(), GuiRoot:GetWidth(), GuiRoot:GetHeight())
    if not x then EP.ClearGlyphTooltip(control); return end
    tip:SetScale(scale)
    tip:ClearAnchors()
    tip:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

function EP.ShowGlyphTooltip(control, link)
    EP.ClearInventoryTooltips()
    EP.tooltipOwner = control
    InitializeTooltip(ItemTooltip, GuiRoot, TOPLEFT, 0, 0, TOPLEFT)
    ItemTooltip:SetLink(link)
    EP.PositionGlyphTooltip(control)
    local serial = EP.tooltipSerial
    zo_callLater(function()
        if EP.tooltipOwner == control and EP.tooltipSerial == serial then
            EP.PositionGlyphTooltip(control)
        end
    end, 0)
end

local function AddGlyphCandidate(glyphs, seen, targetBag, targetSlot, glyphBag, glyphSlot)
    if glyphBag == nil or glyphSlot == nil then return end
    if type(CanItemTakeEnchantment) ~= "function" then return end
    local ok, compatible = pcall(CanItemTakeEnchantment, targetBag, targetSlot, glyphBag, glyphSlot)
    if not ok or compatible ~= true then return end

    local uniqueId = ItemIdentity(glyphBag, glyphSlot)
    local key = tostring(glyphBag) .. ":" .. tostring(glyphSlot) .. ":" .. tostring(uniqueId)
    if seen[key] then return end
    seen[key] = true

    glyphs[#glyphs + 1] = {
        bag = glyphBag,
        slot = glyphSlot,
        link = GetItemLink(glyphBag, glyphSlot),
        name = GetItemName(glyphBag, glyphSlot),
        id = uniqueId,
        quality = GetItemDisplayQuality(glyphBag, glyphSlot),
    }
end

function EP.BuildGlyphEntries(bag, index)
    if not SupportsTarget(bag, index) then return {} end
    local targetId = ItemIdentity(bag, index)
    local glyphs, seen = {}, {}

    if type(GetBagSize) == "function" then
        local bagSize = tonumber(GetBagSize(BAG_BACKPACK)) or 0
        for glyphSlot = 0, math.max(0, bagSize - 1) do
            AddGlyphCandidate(glyphs, seen, bag, index, BAG_BACKPACK, glyphSlot)
        end
    end

    if PLAYER_INVENTORY and type(PLAYER_INVENTORY.GenerateListOfVirtualStackedItems) == "function" then
        local ok, itemList = pcall(PLAYER_INVENTORY.GenerateListOfVirtualStackedItems,
            PLAYER_INVENTORY,
            INVENTORY_BACKPACK,
            function(glyphBag, glyphSlot)
                local valid, compatible = pcall(CanItemTakeEnchantment, bag, index, glyphBag, glyphSlot)
                return valid and compatible == true
            end)
        if ok then
            for _, itemInfo in pairs(itemList or {}) do
                AddGlyphCandidate(glyphs, seen, bag, index, itemInfo.bag, itemInfo.index)
            end
        end
    end

    table.sort(glyphs, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.name ~= b.name then return a.name < b.name end
        return a.link < b.link
    end)

    local entries = {}
    for _, glyph in ipairs(glyphs) do
        local entry = glyph
        local function StillValid()
            return SameItem(bag, index, targetId)
                and SameItem(entry.bag, entry.slot, entry.id)
                and CanItemTakeEnchantment(bag, index, entry.bag, entry.slot)
        end
        local function DoEnchant()
            if not StillValid() then return end
            if type(IsProtectedFunction) == "function" and IsProtectedFunction("EnchantItem") then
                CallSecureProtected("EnchantItem", bag, index, entry.bag, entry.slot)
            else
                EnchantItem(bag, index, entry.bag, entry.slot)
            end
        end
        local rarity = GetString("SI_ITEMDISPLAYQUALITY", entry.quality)
        local color = GetItemQualityColor(entry.quality)
        local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, entry.name)
        entries[#entries + 1] = {
            label = color:Colorize(name .. " (" .. rarity .. ")"),
            normalColor = color,
            tooltip = function(control, inside)
                if inside then EP.ShowGlyphTooltip(control, entry.link)
                else EP.ClearGlyphTooltip(control) end
            end,
            callback = function()
                EP.ClearGlyphTooltip()
                if not StillValid() then return end
                if IsItemPlayerLocked(bag, index) then
                    ZO_Dialogs_ShowPlatformDialog("CONFIRM_ENCHANT_LOCKED_ITEM",
                        { onAcceptCallback = DoEnchant },
                        { mainTextParams = { GetString(SI_PERFORM_ACTION_CONFIRMATION) } })
                else
                    DoEnchant()
                end
            end,
        }
    end
    return entries
end

function EP.AddMenu(bag, index)
    if not SupportsTarget(bag, index) or type(AddCustomSubMenuItem) ~= "function" then return false end
    local entries = EP.BuildGlyphEntries(bag, index)
    if #entries == 0 then
        entries[1] = { label = "No compatible backpack glyphs", disabled = true, callback = function() end }
    end
    entries[#entries + 1] = {
        label = "Find Runestones (Map + 3D)",
        callback = function()
            if ESOProgressionCoach and ESOProgressionCoach.CraftingMaterialHunt
                and ESOProgressionCoach.CraftingMaterialHunt.StartEnchanting029763 then
                ESOProgressionCoach.CraftingMaterialHunt:StartEnchanting029763(true)
            end
        end,
    }
    EP.ClearInventoryTooltips()
    AddCustomSubMenuItem("Enchant+", entries)
    return true
end

-- Hide only ESO's plain Enchant row and remove its contribution from the menu's
-- stored height. ESO's ShowMenu() later adds menu.height + spacing*(#items-1),
-- so compensate for both the removed row and its otherwise-still-counted gap.
-- The entry remains in the table, preserving every other native/addon callback
-- and index; the adjustment is marked so the deferred pass cannot subtract twice.
function EP.SuppressNativeEnchantEntry()
    local menu = rawget(_G, "ZO_Menu")
    if not menu or type(menu.items) ~= "table" then return end
    local enchantName = type(GetString) == "function" and GetString(SI_ITEM_ACTION_ENCHANT) or "Enchant"
    for _, entry in ipairs(menu.items) do
        local item = entry and entry.item
        local label = item and item.nameLabel
        local text = label and type(label.GetText) == "function" and label:GetText() or nil
        if text == enchantName then
            if not entry._easEnchantCollapsed029517 then
                local originalHeight = tonumber(item.storedHeight)
                if not originalHeight and type(item.GetHeight) == "function" then
                    originalHeight = tonumber(item:GetHeight())
                end
                originalHeight = math.max(0, originalHeight or 0)
                local originalPad = math.max(0, tonumber(entry.itemYPad) or 0)
                local spacing = math.max(0, tonumber(menu.spacing) or 0)

                -- UpdateMenuDimensions already added row height + itemYPad.
                -- Because the hidden entry stays in #menu.items, ShowMenu will
                -- also count one extra spacing interval; remove that here too.
                menu.height = math.max(0, (tonumber(menu.height) or 0) - originalHeight - originalPad - spacing)
                entry._easEnchantCollapsed029517 = true
            end

            if item.SetHidden then item:SetHidden(true) end
            if item.SetMouseEnabled then item:SetMouseEnabled(false) end
            if item.SetHeight then item:SetHeight(0) end
            item.storedHeight = 0
            entry.itemYPad = 0
            if entry.checkbox then
                if entry.checkbox.SetHidden then entry.checkbox:SetHidden(true) end
                if entry.checkbox.SetMouseEnabled then entry.checkbox:SetMouseEnabled(false) end
                if entry.checkbox.SetHeight then entry.checkbox:SetHeight(0) end
            end
        end
    end
end

function EP.ContextMenuCallback(inventorySlot)
    if not inventorySlot then return end
    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if EP.AddMenu(bag, index) then
        EP.SuppressNativeEnchantEntry()
        if type(zo_callLater) == "function" then
            zo_callLater(function() EP.SuppressNativeEnchantEntry() end, 0)
        end
    end
end

function EP.OnAddonLoaded(_, addonName)
    if addonName ~= "ESOAdventurerSuite" then return end
    EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_ADD_ON_LOADED)
    if EP.initialized then return end
    if not LibCustomMenu or type(LibCustomMenu.RegisterContextMenu) ~= "function" then return end
    LibCustomMenu:RegisterContextMenu(EP.ContextMenuCallback, LibCustomMenu.CATEGORY_LATE)
    EP.initialized = true
    SecurePostHook("ClearMenu", function()
        if EP.tooltipOwner then EP.ClearGlyphTooltip() end
    end)
end

EVENT_MANAGER:RegisterForEvent(eventName, EVENT_ADD_ON_LOADED, EP.OnAddonLoaded)
