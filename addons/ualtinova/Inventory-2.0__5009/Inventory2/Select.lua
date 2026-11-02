InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- Ctrl and a click marks a piece; marking several and right clicking any row offers to do one
-- thing to all of them.
--
-- The mark is kept per piece rather than per row. A row is a control out of a pool that is
-- handed to something else on the next rebuild, and this list rebuilds on every change to the
-- bag -- so what is remembered is the game's own unique id for the piece, the same one the
-- player's own category choices are kept under (IG.PieceId).
--
-- Nothing here is saved. A selection is a sentence you are halfway through saying; closing the
-- window is deciding not to finish it.

local selected = {}   -- [piece id] = { bagId, slotIndex }
local count = 0

-- The colour a marked row wears, and how much of it. Added light rather than paint, at a
-- strength that says "this one" without making the name under it harder to read.
local MARK_COLOR = { 0.36, 0.88, 0.48 }
local MARK_ALPHA = 0.16
-- The hint that says the mark can be made at all, in the empty run a row leaves between what
-- it says about itself and what it is worth.
-- How far it keeps off the price, what a price is taken to be wide when it cannot be measured
-- (five figures and their coin), and where it stands on a row with no price at all. Written
-- small: what it has to fit into is the run between the row's own icons and its price, and on
-- a busy row that run is barely wider than the words.
local HINT_GAP = 6
local HINT_PRICE_ASSUMED = 76
local HINT_ROW_INSET = 104
local HINT_FONT = "$(MEDIUM_FONT)|11|soft-shadow-thin"
local HINT_COLOR = { 0.72, 0.76, 0.82 }
local HINT_ICON_SIZE = 17
local HINT_TEXT = "Multiple"
local HINT_SELECTED = "%d selected"
-- Temporarily off: it sits on top of TTC's magnifier hint. Set to true to bring it back.
local HINT_ENABLED = false

function IG.SelectionCount()
    return count
end

function IG.ClearSelection()
    if count == 0 then return end
    ZO_ClearTable(selected)
    count = 0
    IG.RepaintSelection()
end

-- What is marked right now, as the pieces the game can still find. A piece whose id no longer
-- answers to the slot it was marked in has been moved, split or spent since; it is dropped
-- rather than acted on, because the slot it left is somebody else's now.
function IG.SelectedPieces()
    local pieces = {}
    for id, where in pairs(selected) do
        if IG.PieceId(where.bagId, where.slotIndex) == id then
            pieces[#pieces + 1] = { id = id, bagId = where.bagId, slotIndex = where.slotIndex }
        end
    end
    return pieces
end

function IG.IsSlotSelected(bagId, slotIndex)
    if count == 0 then return false end
    local id = IG.PieceId(bagId, slotIndex)
    return id ~= nil and selected[id] ~= nil
end

function IG.IsPieceSelected(slotData)
    return slotData ~= nil and IG.IsSlotSelected(slotData.bagId, slotData.slotIndex)
end

local function Toggle(slotData)
    local id = slotData and IG.PieceId(slotData.bagId, slotData.slotIndex)
    if not id then return false end
    if selected[id] then
        selected[id] = nil
        count = count - 1
    else
        selected[id] = { bagId = slotData.bagId, slotIndex = slotData.slotIndex }
        count = count + 1
    end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    IG.RepaintSelection()
    return true
end

---------------------------------------------------------------------------
-- What a row shows for it
---------------------------------------------------------------------------

-- A row of the bag rather than any other thing the game calls an inventory slot: the piece it
-- stands for has to be one the game can put a unique id on.
--
-- What the game hands its slot handlers is not always the row: it is whichever part of it the
-- mouse was actually on -- the icon, the name -- so the parents are walked, the same distance
-- the keybind walks them.
local function SlotData(control)
    for _ = 1, 4 do
        if not control then return nil end
        local data = control.dataEntry and control.dataEntry.data
        -- A worn piece is never marked: nothing the marks lead to can be done to it.
        if data and data.bagId and data.slotIndex and not IG.IsWornSlot(data.bagId)
            and IG.PieceId(data.bagId, data.slotIndex) then
            return data, control
        end
        control = control.GetParent and control:GetParent()
    end
end

local function Mark(row)
    if not row.igSelectMark then
        local mark = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
        mark:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
        mark:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, 0, 0)
        mark:SetColor(MARK_COLOR[1], MARK_COLOR[2], MARK_COLOR[3], 1)
        mark:SetAlpha(MARK_ALPHA)
        mark:SetBlendMode(TEX_BLEND_MODE_ADD)
        mark:SetDrawLayer(DL_BACKGROUND)
        mark:SetMouseEnabled(false)
        row.igSelectMark = mark
    end
    return row.igSelectMark
end

-- Ctrl and the left mouse button, one above the other, with what they do written under them.
-- The keyboard mark and the mouse picture are the game's own, so they say whatever the player
-- has those keys set to rather than what we assume.
local function HintText()
    local mouseIcon = KEY_MOUSE_LEFT and GetMouseIconPathForKeyCode and GetMouseIconPathForKeyCode(KEY_MOUSE_LEFT)
    local mouse = mouseIcon and zo_iconFormat(mouseIcon, HINT_ICON_SIZE, HINT_ICON_SIZE) or "Click"
    -- Once something is marked the ctrl is not needed any more and the row says so, and says
    -- how many are marked while it is at it.
    if count > 0 then
        return string.format("%s\n%s", mouse, string.format(HINT_SELECTED, count))
    end
    local key = GetKeyName and GetKeyName(KEY_CTRL)
    local keyText = (key and key ~= "" and ZO_Keybindings_GenerateTextKeyMarkup(key)) or "Ctrl"
    return string.format("%s %s\n%s", keyText, mouse, HINT_TEXT)
end

-- How much of the price column the price is actually using. The control is not a label -- it
-- is the game's own currency piece, with the number written inside it -- so asking it for a
-- text width answers nothing at all, and its box is far wider than what is written in it:
-- anchoring to either end put the hint on the row's icons at one and on the coin at the other.
-- The writing is looked for inside instead, and where it cannot be found a five figure price
-- is assumed, which errs toward leaving too much room rather than too little.
local function PriceWidth(price)
    local width = price.GetTextWidth and price:GetTextWidth() or 0
    if width > 0 then return width end
    for index = 1, (price.GetNumChildren and price:GetNumChildren() or 0) do
        local child = price:GetChild(index)
        local childWidth = child and child.GetTextWidth and child:GetTextWidth() or 0
        if childWidth > width then width = childWidth end
    end
    if width > 0 then return width end
    return HINT_PRICE_ASSUMED
end

-- Beside the price rather than on it, and measured again on every row: the next one's price is
-- a different length. A row with no price of its own keeps a fixed run clear at its right.
local function PlaceHint(row, hint)
    local price = row:GetNamedChild("SellPrice")
    hint:ClearAnchors()
    if price then
        hint:SetAnchor(RIGHT, price, RIGHT, -(PriceWidth(price) + HINT_GAP), 0)
    else
        hint:SetAnchor(RIGHT, row, RIGHT, -HINT_ROW_INSET, 0)
    end
end

local function Hint(row)
    if not row.igSelectHint then
        local hint = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
        hint:SetFont(HINT_FONT)
        hint:SetColor(unpack(HINT_COLOR))
        hint:SetText(HintText())
        hint:SetMaxLineCount(2)
        hint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        hint:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        hint:SetMouseEnabled(false)
        -- A row that has been stood down is still a row you can mark, so what says so is read
        -- at full strength whatever the row behind it is doing.
        hint:SetInheritAlpha(false)
        hint:SetDrawLayer(DL_OVERLAY)
        row.igSelectHint = hint
    end
    -- Said again every time: how many are marked is not what it was a click ago.
    row.igSelectHint:SetText(HintText())
    PlaceHint(row, row.igSelectHint)
    return row.igSelectHint
end

-- Whether the pointer is on this row right now. It is usually on a part of one -- the icon,
-- the name -- so the parents are walked, the same distance the keybind walks them.
-- Headers ask this as well, when one is redrawn while the mouse is still on it.
local function UnderMouse(row)
    local control = WINDOW_MANAGER:GetMouseOverControl()
    for _ = 1, 4 do
        if not control then return false end
        if control == row then return true end
        control = control.GetParent and control:GetParent()
    end
    return false
end

IG.IsUnderMouse = UnderMouse

-- Called for every item row the list draws (InventoryGrouping's row decoration).
function IG.DressSelection(row, data)
    local marked = IG.IsPieceSelected(data)
    if marked or row.igSelectMark then Mark(row):SetHidden(not marked) end
    -- The hint belongs to the mouse rather than to the row, and a row is a control out of a
    -- pool: the one the pointer was on a moment ago may be standing somewhere else now. So it
    -- is put away here unless the pointer is still on this very row -- which it is, every time
    -- a click of yours is what rebuilt the list.
    if HINT_ENABLED and UnderMouse(row) then
        Hint(row):SetHidden(false)  -- and placed again: this row's price is its own length
    elseif row.igSelectHint then
        row.igSelectHint:SetHidden(true)
    end
end

-- Marking a piece changes nothing about the list: not which rows are in it, not their order,
-- not their height, not a single count in a header. Only what the rows already on screen wear.
-- So the list is left exactly where it stands and those rows are dressed again in place --
-- because having the game build a list from inside our own frame is what leaves the row under
-- the mouse unable to be acted on until the mouse moves again (HANDOFF, "the commit is the
-- game's to make"). Nothing here commits, sorts or refreshes anything.
--
-- A scroll list hands out its row controls from a pool and keeps the ones it has drawn in
-- activeControls; anything off screen has no control to dress and will be dressed by the
-- setup callback when it is scrolled to. Every field is asked for rather than assumed: this
-- runs on a click, and a click that errors is worse than a mark drawn a moment late.
local function RepaintList(list)
    local active = list and list.activeControls
    if type(active) ~= "table" then return end
    for _, control in pairs(active) do
        local entry = control and control.dataEntry
        -- Item rows only. Our headers, spacers and rules are data types of their own and
        -- carry no piece to be marked.
        if entry and entry.typeId == 1 and entry.data then
            IG.DressSelection(control, entry.data)
        end
    end
end

-- Both lists a piece can be marked in: the bag, and whichever crafting station is open.
function IG.RepaintSelection()
    local _, list = IG.VisibleList()
    RepaintList(list)
    RepaintList(IG.VisibleCraftList and IG.VisibleCraftList())
end

---------------------------------------------------------------------------
-- The two hooks it all hangs off
---------------------------------------------------------------------------

-- Hooked by name, and only where the name answers: these are the game's own row handlers and
-- asking to hook one that is not there is an error rather than a shrug.
local function Hook(name, hook)
    if _G[name] then ZO_PreHook(name, hook) end
end

function IG.StartSelection()
    -- Ctrl and the left button belong to us; everything else about a row is the game's. The
    -- hook answers true only for that one combination, so nothing the game does with a click
    -- is lost -- and it is asked before the game's own handler runs, so nothing happens twice.
    --
    -- Two handlers because the game has two and only one of them is a click: the first one
    -- that is there takes it, and taking it stops the other ever being reached.
    -- Ctrl starts it. Once something is marked the plain click carries on marking, because
    -- that is what you are doing now and reaching for ctrl between every two rows is not part
    -- of it. Letting go of the last mark ends it, and the click is the game's again.
    local function ClickSelect(control, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return false end
        if not (IsControlKeyDown() or count > 0) then return false end
        return Toggle((SlotData(control)))
    end
    Hook("ZO_InventorySlot_OnMouseUp", function(control, button, upInside)
        return upInside and ClickSelect(control, button) or false
    end)
    Hook("ZO_InventorySlot_OnSlotClicked", ClickSelect)

    -- Escape lets go of the marks before it closes anything. Pressing it while the window is
    -- open is what asks for the base scene, so the first press is spent on the selection and
    -- the second closes the window the way it always did.
    if SCENE_MANAGER and SCENE_MANAGER.ShowBaseScene then
        ZO_PreHook(SCENE_MANAGER, "ShowBaseScene", function()
            if count == 0 then return false end
            IG.ClearSelection()
            return true
        end)
    end

    Hook("ZO_InventorySlot_OnMouseEnter", function(control)
        local _, row = SlotData(control)
        if HINT_ENABLED and row and IG.IsEnabled and IG.IsEnabled() then Hint(row):SetHidden(false) end
        return false
    end)

    Hook("ZO_InventorySlot_OnMouseExit", function(control)
        local _, row = SlotData(control)
        if row and row.igSelectHint then row.igSelectHint:SetHidden(true) end
        return false
    end)
end
