InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- EQUIPMENT SETUPS, the part you touch: the menus (EQUIPPED header, setup headers, item right
-- click, the Ctrl selection menu), the small question panel, and Equip All. The data and the
-- list side are Setups.lua.

local PREFIX = "|cFFFFFF%s:|r %s"
local function MenuLabel(text) return string.format(PREFIX, IG.SHORT_NAME or "INV2.0", text) end

local function Say(text)
    if ZO_Alert then ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, text) end
end

local function SetupMenuName(setup)
    return IG.SetupColoredName(setup)
end

local function ItemName(link)
    if not link or link == "" then return "?" end
    return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(link))
end

---------------------------------------------------------------------------
-- Changing the saved setups (every change is one Ctrl+Z step)
---------------------------------------------------------------------------

local function Store() return IG.SetupStore and IG.SetupStore() end

local function Changed()
    if IG.SetupsChanged then IG.SetupsChanged() end
    IG.RefreshLists()
end

-- The setup is replaced by an edited copy, so undo puts the old table back whole.
local function Mutate(id, label, edit)
    local store = Store()
    if not (store and store.list[id]) then return end
    IG.UndoStep(label, function()
        IG.NoteSaved(store.list, id)
        local copy = ZO_DeepTableCopy(store.list[id])
        copy.gear, copy.quick = copy.gear or {}, copy.quick or {}
        edit(copy)
        store.list[id] = copy
    end)
    Changed()
end

-- What you wear now, the quickslot wheel and the food on you.
local function Snapshot()
    local gear, quick, food = {}, {}, nil
    for _, info in ipairs(IG.SETUP_SLOTS) do
        local link = GetItemLink(BAG_WORN, info.slot)
        local piece = link ~= "" and IG.PieceId(BAG_WORN, info.slot)
        if piece then gear[info.slot] = { piece = piece, link = link } end
    end
    if HOTBAR_CATEGORY_QUICKSLOT_WHEEL and ACTION_BAR_UTILITY_BAR_SIZE then
        for wheel = 1, ACTION_BAR_UTILITY_BAR_SIZE do
            if GetSlotType(wheel, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) == ACTION_TYPE_ITEM then
                local link = GetSlotItemLink(wheel, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                local itemId = link and link ~= "" and GetItemLinkItemId(link) or 0
                if itemId ~= 0 then quick[wheel] = { itemId = itemId, link = link } end
            end
        end
    end
    -- Food: the item ids the buff on you comes from (Equipped.lua); the one in the bag if any.
    local wanted = IG.EquippedConsumables and IG.EquippedConsumables()
    if wanted then
        local foodIds = {}
        for itemId, place in pairs(wanted) do
            if place >= 100 then foodIds[itemId] = true end
        end
        local bag = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
        for _, slotData in pairs(bag or {}) do
            if type(slotData) == "table" and slotData.slotIndex then
                local itemId = GetItemId(BAG_BACKPACK, slotData.slotIndex)
                if foodIds[itemId] then
                    food = { itemId = itemId, link = GetItemLink(BAG_BACKPACK, slotData.slotIndex) }
                    break
                end
            end
        end
        if not food then
            local itemId = next(foodIds)
            -- Not in the bag: the plain link form, only for the name and the tooltip.
            if itemId then food = { itemId = itemId, link = string.format("|H1:item:%d:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId) } end
        end
    end
    return gear, quick, food
end

function IG.SaveEquippedAsSetup()
    local store = Store()
    if not store then return end
    local gear, quick, food = Snapshot()
    if not next(gear) then Say("Nothing equipped to save") return end
    local id = store.nextId
    IG.UndoStep("a new equipment setup", function()
        IG.NoteSaved(store, "nextId")
        IG.NoteSaved(store.list, id)
        store.nextId = id + 1
        store.list[id] = { id = id, order = id, gear = gear, quick = quick, food = food }
    end)
    Changed()
end

function IG.UpdateSetupFromEquipped(id)
    local gear, quick, food = Snapshot()
    if not next(gear) then Say("Nothing equipped to save") return end
    local setup = IG.GetSetup(id)
    Mutate(id, string.format("%s updated", SetupMenuName(setup)), function(copy)
        copy.gear, copy.quick, copy.food = gear, quick, food
    end)
end

function IG.DeleteSetup(id)
    local store, setup = Store(), IG.GetSetup(id)
    if not setup then return end
    IG.UndoStep(string.format("%s deleted", SetupMenuName(setup)), function()
        IG.NoteSaved(store.list, id)
        store.list[id] = nil
    end)
    Changed()
end

-- From the rename dialog (InventoryGrouping.lua): true when the key was a setup's.
function IG.RenameSetup(key, name)
    local id = IG.SetupIdOfKey(key)
    local setup = id and IG.GetSetup(id)
    if not setup then return false end
    Mutate(id, string.format("the name of %s", SetupMenuName(setup)), function(copy)
        copy.name = name ~= "" and zo_strupper(name) or nil
    end)
    return true
end

-- What the dialog opens with: the name alone, without "SETUP: ".
function IG.SetupRenameText(key)
    local id = IG.SetupIdOfKey(key)
    local setup = id and IG.GetSetup(id)
    return setup and IG.SetupName(setup) or nil
end

local function RemovePiece(id, pieceId)
    Mutate(id, string.format("%s taken out of %s", IG.UndoPieces(1), SetupMenuName(IG.GetSetup(id))),
        function(copy)
            for slot, gear in pairs(copy.gear) do
                if gear.piece == pieceId then copy.gear[slot] = nil end
            end
        end)
end

local function RemoveSlot(id, slot)
    Mutate(id, string.format("%s taken out of %s", IG.UndoPieces(1), SetupMenuName(IG.GetSetup(id))),
        function(copy) copy.gear[slot] = nil end)
end

local function RemovePieces(id, pieceIds)
    local wanted = {}
    for _, pieceId in ipairs(pieceIds) do wanted[pieceId] = true end
    Mutate(id, string.format("%s taken out of %s", IG.UndoPieces(#pieceIds), SetupMenuName(IG.GetSetup(id))),
        function(copy)
            for slot, gear in pairs(copy.gear) do
                if wanted[gear.piece] then copy.gear[slot] = nil end
            end
        end)
end

---------------------------------------------------------------------------
-- The question panel: a title, some lines, a row of buttons. Own art (Repair.lua's panel):
-- dark backdrop, the drawer frame edge, an accent stripe. Centered; one at a time.
---------------------------------------------------------------------------

local PANEL_NAME = "Inventory2SetupsPanel"
local PANEL_WIDTH = 480
local PANEL_EDGE = "EsoUI/Art/WorldMap/worldmap_frame_edge.dds"
local ACCENT = "E8C872"
local MAX_BUTTONS = 6
local BUTTON_WIDTH, BUTTON_HEIGHT, BUTTON_GAP = 138, 28, 8
local LINE_HEIGHT = 20
local panel

local function BuildPanel()
    if panel then return panel end
    local window = WINDOW_MANAGER:CreateTopLevelWindow(PANEL_NAME)
    if not window then return nil end
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, -120)
    window:SetMouseEnabled(true)
    window:SetClampedToScreen(true)
    window:SetHidden(true)

    local bg = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
    bg:SetAnchorFill(window)
    bg:SetEdgeTexture(PANEL_EDGE, 128, 16, 8, 0)
    bg:SetCenterColor(0, 0, 0, 0.92)
    local r, g, b = IG.HexToRGB(ACCENT)
    bg:SetEdgeColor(r, g, b, 1)

    local stripe = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    stripe:SetHeight(2)
    stripe:SetAnchor(TOPLEFT, window, TOPLEFT, 8, 4)
    stripe:SetAnchor(TOPRIGHT, window, TOPRIGHT, -8, 4)
    stripe:SetColor(r, g, b)
    stripe:SetAlpha(0.8)

    local title = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    title:SetFont("$(BOLD_FONT)|20|soft-shadow-thin")
    title:SetColor(r, g, b)
    title:SetAnchor(TOP, window, TOP, 0, 16)
    title:SetDimensionConstraints(0, 0, PANEL_WIDTH - 40, 0)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local body = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    body:SetFont("$(MEDIUM_FONT)|16|soft-shadow-thin")
    body:SetColor(IG.HexToRGB("F2F2F2"))
    body:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    body:SetAnchor(TOP, title, BOTTOM, 0, 10)
    body:SetWidth(PANEL_WIDTH - 40)

    local buttons = {}
    for index = 1, MAX_BUTTONS do
        -- Created once under fixed names: a second CreateControlFromVirtual with the same name
        -- answers nil (HANDOFF section 5).
        local button = WINDOW_MANAGER:CreateControlFromVirtual(PANEL_NAME .. "Button" .. index, window, "ZO_DefaultButton")
        if button then
            button:SetDimensions(BUTTON_WIDTH, BUTTON_HEIGHT)
            button:SetHidden(true)
        end
        buttons[index] = button
    end
    panel = { window = window, title = title, body = body, buttons = buttons }
    return panel
end

function IG.HideSetupPanel()
    if panel then panel.window:SetHidden(true) end
end

-- spec = { title, lines = { ... }, buttons = { { text, callback }, ... } }. A button closes the
-- panel first, then runs its callback (which may open the panel again with a new question).
function IG.ShowSetupPanel(spec)
    local p = BuildPanel()
    if not p then return end
    p.title:SetText(spec.title or "")
    local lines = spec.lines or {}
    p.body:SetText(table.concat(lines, "\n"))
    p.body:SetHidden(#lines == 0)
    local shown = {}
    for index, button in ipairs(p.buttons) do
        local wanted = spec.buttons and spec.buttons[index]
        if button then
            button:SetHidden(wanted == nil)
            if wanted then
                button:SetText(wanted[1])
                button:SetHandler("OnClicked", function()
                    p.window:SetHidden(true)
                    if wanted[2] then wanted[2]() end
                end)
                shown[#shown + 1] = button
            end
        end
    end
    -- Buttons in rows of three, centred.
    local perRow = 3
    local rows = math.ceil(#shown / perRow)
    local bodyHeight = #lines > 0 and (#lines * LINE_HEIGHT + 10) or 0
    local height = 16 + 26 + bodyHeight + 18 + rows * (BUTTON_HEIGHT + BUTTON_GAP) + 12
    p.window:SetDimensions(PANEL_WIDTH, height)
    for index, button in ipairs(shown) do
        local row = zo_floor((index - 1) / perRow)
        local inRow = zo_min(perRow, #shown - row * perRow)
        local col = (index - 1) % perRow
        local rowWidth = inRow * BUTTON_WIDTH + (inRow - 1) * BUTTON_GAP
        local x = -rowWidth / 2 + col * (BUTTON_WIDTH + BUTTON_GAP)
        local y = -12 - (rows - 1 - row) * (BUTTON_HEIGHT + BUTTON_GAP)
        button:ClearAnchors()
        button:SetAnchor(BOTTOMLEFT, p.window, BOTTOM, x, y)
    end
    p.window:SetHidden(false)
end

---------------------------------------------------------------------------
-- Adding pieces
---------------------------------------------------------------------------

-- pieces = { { bagId, slotIndex }, ... }. Rings and weapons always ask which slot; a slot that
-- already holds another piece asks once, for all of them, whether to replace it.
function IG.AddPiecesToSetup(id, pieces)
    local setup = IG.GetSetup(id)
    if not setup then return end
    local queue = {}
    for _, where in ipairs(pieces) do
        local link = GetItemLink(where.bagId, where.slotIndex)
        local slots = IG.SetupSlotsForLink(link)
        local pieceId = IG.PieceId(where.bagId, where.slotIndex)
        if slots and pieceId then
            queue[#queue + 1] = { piece = pieceId, link = link, slots = slots }
        end
    end
    if #queue == 0 then Say("Only equippable gear can go in a setup") return end

    local function Apply(chosen)
        Mutate(id, string.format("%s added to %s", IG.UndoPieces(#chosen), SetupMenuName(setup)), function(copy)
            for _, pick in ipairs(chosen) do
                for slot, gear in pairs(copy.gear) do
                    if gear.piece == pick.piece then copy.gear[slot] = nil end
                end
                copy.gear[pick.slot] = { piece = pick.piece, link = pick.link }
            end
        end)
    end

    local function Conflicts(chosen)
        local current = IG.GetSetup(id)
        if not current then return end
        local clashes, clean, all = {}, {}, {}
        for _, pick in ipairs(chosen) do
            local old = current.gear and current.gear[pick.slot]
            if old and old.piece ~= pick.piece then
                clashes[#clashes + 1] = string.format("%s: %s  ->  %s", IG.SetupSlotName(pick.slot),
                    ItemName(old.link), ItemName(pick.link))
            else
                clean[#clean + 1] = pick
            end
            all[#all + 1] = pick
        end
        if #clashes == 0 then return Apply(all) end
        IG.ShowSetupPanel({
            title = #clashes == 1 and "Replace this piece?" or "Replace these pieces?",
            lines = clashes,
            buttons = {
                { "Yes", function() Apply(all) end },
                { "No", function() if #clean > 0 then Apply(clean) end end },
            },
        })
    end

    local chosen, index = {}, 0
    local function Next()
        index = index + 1
        local item = queue[index]
        if not item then return Conflicts(chosen) end
        if #item.slots == 1 then
            chosen[#chosen + 1] = { piece = item.piece, link = item.link, slot = item.slots[1] }
            return Next()
        end
        local buttons = {}
        for _, slot in ipairs(item.slots) do
            buttons[#buttons + 1] = { IG.SetupSlotName(slot), function()
                chosen[#chosen + 1] = { piece = item.piece, link = item.link, slot = slot }
                Next()
            end }
        end
        buttons[#buttons + 1] = { "Cancel", nil }
        IG.ShowSetupPanel({ title = "Which slot?", lines = { ItemName(item.link) }, buttons = buttons })
    end
    Next()
end

---------------------------------------------------------------------------
-- Menus
---------------------------------------------------------------------------

-- Header right click (InventoryGrouping.lua, right after ClearMenu).
function IG.AddSetupHeaderMenu(data)
    if not data or not data.key then return end
    if data.depth == 1 and data.key == "EQUIPPED" then
        AddMenuItem("Save as Setup", function() IG.SaveEquippedAsSetup() end)
        return
    end
    -- The SETUPS module's own heading.
    if data.depth == 1 and data.key == IG.SETUPS_KEY then
        AddMenuItem("Save Current as Setup", function() IG.SaveEquippedAsSetup() end)
        return
    end
    -- A setup is a sub-category of SETUPS: its heading key is "SETUPS/SETUP_<id>".
    if data.depth ~= 2 then return end
    local id = IG.SetupIdOfKey(data.key)
    if not (id and IG.GetSetup(id)) then return end
    if IG.EquipSetup then AddMenuItem("Equip All", function() IG.EquipSetup(id) end) end
    AddMenuItem("Rename Setup", function() IG.RenameGroup(data.key) end)
    -- The name's colour: the category colour wheel (InventoryGrouping.lua, PickColor), one
    -- Ctrl+Z step each, written into the setup itself.
    local shown = IG.SetupNameColor(IG.GetSetup(id))
    if IG.PickColor then
        AddMenuItem(string.format("|c%sName Color...|r", shown), function()
            IG.PickColor(shown, function(hex)
                Mutate(id, string.format("the name colour of %s", SetupMenuName(IG.GetSetup(id))),
                    function(copy) copy.nameColor = hex end)
            end)
        end)
    end
    if IG.GetSetup(id).nameColor then
        AddMenuItem(string.format("|c%sReset Name Color|r", shown), function()
            Mutate(id, string.format("the name colour of %s", SetupMenuName(IG.GetSetup(id))),
                function(copy) copy.nameColor = nil end)
        end)
    end
    -- How the setup lays out its gear (Setups.lua, IG.SetSetupView); the one in force is green.
    if IG.SetSetupView then
        local current = IG.SetupView(IG.GetSetup(id))
        local views = {}
        for _, view in ipairs({ { "type", "By Type" }, { "set", "By Set" }, { "slot", "By Slot" } }) do
            local key, label = view[1], view[2]
            views[#views + 1] = { label = key == current and ("|c5CE05C" .. label .. "|r") or label,
                callback = function() IG.SetSetupView(id, key) end }
        end
        if AddCustomSubMenuItem then
            AddCustomSubMenuItem("Show as", views)
        else
            for _, entry in ipairs(views) do AddMenuItem("Show as " .. entry.label, entry.callback) end
        end
    end
    AddMenuItem("Update from Equipped", function() IG.UpdateSetupFromEquipped(id) end)
    AddMenuItem("|cFF5C5CDelete Setup|r", function() IG.DeleteSetup(id) end)
end

local function SetupEntries(make)
    local entries = {}
    for _, setup in ipairs(IG.OrderedSetups()) do
        local entry = make(setup)
        if entry then entries[#entries + 1] = entry end
    end
    return entries
end

-- A single item's right click (LibCustomMenu).
local function AddItemEntries(inventorySlot)
    if not (AddCustomSubMenuItem and IG.OrderedSetups) then return end
    if IG.SelectionCount and IG.SelectionCount() > 0 then return end
    local ok, bagId, slotIndex = pcall(ZO_Inventory_GetBagAndIndex, inventorySlot)
    if not (ok and bagId and slotIndex) then return end
    local link = GetItemLink(bagId, slotIndex)
    local pieceId = link ~= "" and IG.PieceId(bagId, slotIndex)
    if not pieceId or not IG.SetupSlotsForLink(link) then return end
    if not next(IG.OrderedSetups()) then return end
    local adds = SetupEntries(function(setup)
        return { label = SetupMenuName(setup), callback = function()
            IG.AddPiecesToSetup(setup.id, { { bagId = bagId, slotIndex = slotIndex } })
        end }
    end)
    AddCustomSubMenuItem(MenuLabel("Add to Setup"), adds)
    local ids = IG.SetupsOfPiece(pieceId)
    if ids and ids[1] then
        local removes = {}
        for _, id in ipairs(ids) do
            local setup = IG.GetSetup(id)
            if setup then
                removes[#removes + 1] = { label = SetupMenuName(setup), callback = function() RemovePiece(id, pieceId) end }
            end
        end
        AddCustomSubMenuItem(MenuLabel("Remove from Setup"), removes)
    end
end

-- The Ctrl selection menu (Overrides.lua, before Cancel).
function IG.AddSetupSelectionMenu()
    if not (AddCustomSubMenuItem and IG.SelectedPieces) then return end
    if not next(IG.OrderedSetups()) then return end
    local gear, pieceIds = {}, {}
    for _, where in ipairs(IG.SelectedPieces()) do
        if IG.SetupSlotsForLink(GetItemLink(where.bagId, where.slotIndex)) then
            gear[#gear + 1] = where
            pieceIds[#pieceIds + 1] = where.id
        end
    end
    if #gear == 0 then return end
    AddCustomSubMenuItem(MenuLabel(string.format("Add %d selected to Setup", #gear)), SetupEntries(function(setup)
        return { label = SetupMenuName(setup), callback = function()
            IG.AddPiecesToSetup(setup.id, gear)
            if IG.ClearSelection then IG.ClearSelection() end
        end }
    end))
    local removes = SetupEntries(function(setup)
        local inIt = {}
        for _, pieceId in ipairs(pieceIds) do
            if IG.SetupSlotOfPiece(setup.id, pieceId) then inIt[#inIt + 1] = pieceId end
        end
        if #inIt == 0 then return nil end
        return { label = string.format("%s (%d)", SetupMenuName(setup), #inIt), callback = function()
            RemovePieces(setup.id, inIt)
            if IG.ClearSelection then IG.ClearSelection() end
        end }
    end)
    if #removes > 0 then
        AddCustomSubMenuItem(MenuLabel("Remove selected from Setup"), removes)
    end
end

-- A setup's faded line (missing, in bank, none in bag): right click takes a gear slot out.
function InventoryGrouping.OnStoredRowMouseUp(control, button, upInside)
    if not upInside or button ~= MOUSE_BUTTON_INDEX_RIGHT then return end
    local data = control and control.igData
    if not (data and data.igSetupId and data.igSetupSlot) then return end
    local id, slot = data.igSetupId, data.igSetupSlot
    ClearMenu()
    AddMenuItem("Remove from Setup", function() RemoveSlot(id, slot) end)
    AddMenuItem(IG.CANCEL_LABEL or "Cancel", function() end)
    ShowMenu(control)
end

-- At the first activation, when the saved settings are read and the Global Switch is known.
local function OnLoaded()
    EVENT_MANAGER:UnregisterForEvent("Inventory2SetupsUI", EVENT_PLAYER_ACTIVATED)
    if not (IG.IsEnabled and IG.IsEnabled()) then return end
    if LibCustomMenu and LibCustomMenu.RegisterContextMenu then
        LibCustomMenu:RegisterContextMenu(AddItemEntries, LibCustomMenu.CATEGORY_SECONDARY)
    end
end
EVENT_MANAGER:RegisterForEvent("Inventory2SetupsUI", EVENT_PLAYER_ACTIVATED, OnLoaded)

---------------------------------------------------------------------------
-- Equip All
---------------------------------------------------------------------------
-- Gear: RequestEquipItem(bagId, slotIndex, BAG_WORN, equipSlot) -- not protected
-- (ESOUIDocumentation.txt:13349; EquipItem is its compatibility alias,
-- addoncompatibilityaliases.lua:1019). Quickslots: SelectSlotItem is *protected*
-- (ESOUIDocumentation.txt:12806), so it goes through CallSecureProtected (doc line 11) the way
-- LarvalTear does (modules/quickslot_apply.lua:162). Out of combat only; food is never eaten.
-- Speed follows LarvalTear's equipment pass (modules/equipment_change.lua ApplyEquipment: every
-- slot is requested in one loop in the same frame, then BeginFinalVerifyWait polls BAG_WORN every
-- 150 ms up to 20 tries). We do the same, re-request pieces still in the backpack every other
-- poll, and put the mythic on as soon as a BAG_WORN slot update says the old one is off.

local POLL_MS = 150
local MAX_POLLS = 20   -- x POLL_MS = 3 s at most, normally done in a few polls
local RETRY_EVERY = 2  -- re-request a piece still in the backpack every 2nd poll
local EQUIP_EVENT = "Inventory2_EquipSetup"
local equipping = false

local function FindPiece(pieceId)
    for _, bagId in ipairs({ BAG_BACKPACK, BAG_WORN }) do
        local cache = SHARED_INVENTORY:GetOrCreateBagCache(bagId)
        for _, slotData in pairs(cache or {}) do
            if type(slotData) == "table" and slotData.slotIndex
                and IG.PieceId(bagId, slotData.slotIndex) == pieceId then
                return bagId, slotData.slotIndex
            end
        end
    end
    return nil
end

local function FindItemId(itemId)
    local cache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
    for _, slotData in pairs(cache or {}) do
        if type(slotData) == "table" and slotData.slotIndex
            and GetItemId(BAG_BACKPACK, slotData.slotIndex) == itemId then
            return slotData.slotIndex
        end
    end
    return nil
end

-- Mythic check by display quality (GetItemDisplayQuality, ESOUIDocumentation.txt:18798),
-- the same test LarvalTear uses (modules/equipment_change.lua:333).
local function IsMythicAt(bagId, slotIndex)
    return ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE ~= nil
        and GetItemDisplayQuality(bagId, slotIndex) == ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE
end

-- A worn mythic in any slot other than exceptSlot (a same-slot swap needs no clearing).
local function WornMythicSlot(exceptSlot)
    for _, info in ipairs(IG.SETUP_SLOTS) do
        if info.slot ~= exceptSlot and GetItemId(BAG_WORN, info.slot) ~= 0
            and IsMythicAt(BAG_WORN, info.slot) then
            return info.slot
        end
    end
    return nil
end

local function ShowUnchanged(unchanged, setup)
    if #unchanged == 0 then return end
    IG.ShowSetupPanel({
        title = string.format("These slots were not changed by %s:", SetupMenuName(setup)),
        lines = { table.concat(unchanged, ", ") },
        buttons = { { "OK", nil } },
    })
end

function IG.EquipSetup(id)
    local setup = IG.GetSetup(id)
    if not setup or equipping then return end
    if IsUnitInCombat("player") then Say("Not while in combat") return end
    equipping = true
    local pending, unchanged = {}, {}
    local mythicTask = nil
    for _, info in ipairs(IG.SETUP_SLOTS) do
        local gear = setup.gear and setup.gear[info.slot]
        if not gear then
            unchanged[#unchanged + 1] = info.name
        else
            local task = { name = info.name, slot = info.slot, piece = gear.piece }
            local startBag, startSlot = FindPiece(task.piece)
            -- Only one mythic may be worn: the setup's mythic waits until no other mythic is on.
            if startBag ~= nil and IsMythicAt(startBag, startSlot) and not mythicTask then
                mythicTask = task
            else
                pending[#pending + 1] = task
            end
        end
    end

    -- "done" = already on, "fail" = cannot be put on (bank, gone, worn elsewhere), "sent" = asked.
    local function TryEquip(task)
        local bagId, slotIndex = FindPiece(task.piece)
        if bagId == BAG_WORN and slotIndex == task.slot then return "done" end
        if bagId ~= BAG_BACKPACK then return "fail" end -- worn to worn is refused
        local ok = pcall(RequestEquipItem, bagId, slotIndex, BAG_WORN, task.slot)
        return ok and "sent" or "fail"
    end
    local function IsOn(task)
        local bagId, slotIndex = FindPiece(task.piece)
        return bagId == BAG_WORN and slotIndex == task.slot
    end
    -- Asks for every pending piece at once; drops the ones already on or impossible.
    local function RequestPending()
        for i = #pending, 1, -1 do
            local result = TryEquip(pending[i])
            if result ~= "sent" then
                if result == "fail" then unchanged[#unchanged + 1] = pending[i].name end
                table.remove(pending, i)
            end
        end
    end

    -- Every non-mythic piece is requested now, in this frame.
    RequestPending()
    -- Quick slots are client side; all set now as well.
    for wheel, item in pairs(setup.quick or {}) do
        local current = GetSlotItemLink(wheel, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if not (current and current ~= "" and GetItemLinkItemId(current) == item.itemId) then
            local slotIndex = FindItemId(item.itemId)
            local ok, result = false, false
            if slotIndex then
                ok, result = pcall(CallSecureProtected, "SelectSlotItem", BAG_BACKPACK, slotIndex,
                    wheel, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
            end
            if not (ok and result ~= false) then
                unchanged[#unchanged + 1] = "Quick Slot " .. wheel
            end
        end
    end

    local finished, polls, mythicSent, mythicCleared = false, 0, false, false
    local function Finish(message)
        if finished then return end
        finished = true
        equipping = false
        EVENT_MANAGER:UnregisterForEvent(EQUIP_EVENT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        for _, task in ipairs(pending) do unchanged[#unchanged + 1] = task.name end
        if mythicTask then unchanged[#unchanged + 1] = mythicTask.name .. " (mythic)" end
        if message then Say(message) end
        ShowUnchanged(unchanged, setup)
    end

    -- The old mythic leaves by itself when a pending piece takes its slot; only when no pending
    -- piece is headed there is it taken off. The new mythic is asked for once no other is worn.
    local function StepMythic()
        if not mythicTask or mythicSent then return end
        local other = WornMythicSlot(mythicTask.slot)
        if other then
            for _, task in ipairs(pending) do
                if task.slot == other then return end
            end
            if not mythicCleared then
                mythicCleared = true
                pcall(RequestUnequipItem, BAG_WORN, other)
            end
            return
        end
        local result = TryEquip(mythicTask)
        if result == "sent" then
            mythicSent = true
        else
            if result == "fail" then unchanged[#unchanged + 1] = mythicTask.name .. " (mythic)" end
            mythicTask = nil
        end
    end

    -- Cheap (at most 14 slots) and only while an Equip All runs.
    local function Check()
        if finished then return end
        for i = #pending, 1, -1 do
            if IsOn(pending[i]) then table.remove(pending, i) end
        end
        if mythicTask and mythicSent and IsOn(mythicTask) then mythicTask = nil end
        StepMythic()
        if #pending == 0 and not mythicTask then Finish() end
    end

    -- Event driven: each BAG_WORN change is checked at once (the mythic goes on right after).
    EVENT_MANAGER:RegisterForEvent(EQUIP_EVENT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
        Check()
    end)
    EVENT_MANAGER:AddFilterForEvent(EQUIP_EVENT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_WORN)

    -- Poll fallback: a lost request is asked again; gives up after MAX_POLLS.
    local function Poll()
        if finished then return end
        if IsUnitInCombat("player") then
            Finish("Equip All stopped: combat")
            return
        end
        polls = polls + 1
        Check()
        if finished then return end
        if polls % RETRY_EVERY == 0 then
            RequestPending()
            mythicSent = false -- StepMythic asks again if it is still not on
            Check()
            if finished then return end
        end
        if polls >= MAX_POLLS then Finish() return end
        zo_callLater(Poll, POLL_MS)
    end
    Check()
    if not finished then zo_callLater(Poll, POLL_MS) end
end
