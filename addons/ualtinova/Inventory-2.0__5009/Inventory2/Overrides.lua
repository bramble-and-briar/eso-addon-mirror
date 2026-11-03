InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- Cached once rather than read off _G on every menu build (ESOUI admin review, 2026-11-02).
-- Safe at file load time: LibCustomMenu is a hard ## DependsOn now, so its own file has already
-- set the global by the time this one runs.
local libCustomMenu = LibCustomMenu

-- Right click an item: send it (or its whole set) to whichever group you want.
-- Choices are kept per item id, or per set id when you pick the set, and beat the automatic rules.
-- The same choice for a whole set is also on the set's own header.

-- Putting something back only makes sense once it has been moved, so those two lines are only
-- there when there is something to undo. Green for the one item, yellow for the whole set.
local RESET_ITEM_COLOR = "5CE07A"
local RESET_SET_COLOR = "FFD84A"
-- Its own colour, and nothing else in the menu near it: the line does something to the item
-- rather than to where the item is filed.
local LOCK_BIND_COLOR = "6FD3FF"
-- Each waiting line wears the colour its own half of the words wears on the row, so the line
-- that puts them there and the words themselves are plainly the one thing said twice -- and the
-- two lines are told apart in the menu the same way they are told apart in the list.

-- A line that has a key of its own says so, in a quieter colour than the line: it is telling
-- you the menu can be skipped next time, not asking to be read first.
local KEY_HINT_COLOR = "9A9AA2"
local NO_KEY = KEY_INVALID or 0

-- What is bound to one of our actions right now, written the way the key settings write it.
-- The first binding only: a second one is the same line said twice.
local function BoundKey(action)
    if not (action and GetActionIndicesFromName and GetActionBindingInfo and GetKeyName) then return nil end
    local layerIndex, categoryIndex, actionIndex = GetActionIndicesFromName(action)
    if not layerIndex then return nil end
    local key, mod1, mod2, mod3, mod4 = GetActionBindingInfo(layerIndex, categoryIndex, actionIndex, 1)
    if not key or key == NO_KEY then return nil end
    local text = GetKeyName(key)
    if not text or text == "" then return nil end
    -- Read out the way they are held down: the modifiers first, innermost last.
    local modifiers = { mod4, mod3, mod2, mod1 }
    for index = 1, 4 do
        local modifier = modifiers[index]
        if modifier and modifier ~= NO_KEY then
            local name = GetKeyName(modifier)
            if name and name ~= "" then text = name .. " + " .. text end
        end
    end
    return text
end

local function WithKey(text, action)
    local key = BoundKey(action)
    if not key then return text end
    return string.format("%s  |c%s[%s]|r", text, KEY_HINT_COLOR, key)
end

-- A set's name inside a line wears the set's own colour -- the one it has in the list -- so the
-- line says which set it means at a glance rather than by being read. Asked with the item link
-- it was read off: asking without one would answer "no roles" and keep that answer for the set
-- for the rest of the session. A set with no role of its own gets the cream every button wears.
local function SetNameText(setId, setName, itemLink)
    local color = (itemLink and IG.GetSetLook(setId, itemLink)) or IG.DEFAULT_ICON_COLOR
    return string.format("|c%s%s|r", color, setName)
end

-- Every line is signed the same way: the addon's name in white, then what the line does.
local function MenuLabel(text, color)
    if color then
        return string.format("|cFFFFFF%s:|r |c%s%s|r", IG.SHORT_NAME, color, text)
    end
    return string.format("|cFFFFFF%s:|r %s", IG.SHORT_NAME, text)
end

-- Bind on equip and not worn yet: the only case where binding is a thing that can happen.
local function CanBind(bagId, slotIndex)
    if not (BindItem and GetItemBindType and IsItemBound) then return false end
    return GetItemBindType(bagId, slotIndex) == BIND_TYPE_ON_EQUIP
        and not IsItemBound(bagId, slotIndex)
end

local function CanLock(bagId, slotIndex)
    return SetItemIsPlayerLocked ~= nil and not IsItemPlayerLocked(bagId, slotIndex)
end

-- Lock it so nothing sells or breaks it by accident, and bind it so it stays yours. Two calls
-- rather than one action: each is skipped when it has nothing to do, so the line can be offered
-- whenever either of them does.
--
-- The lock is called the careful way. Nothing installed here calls it, so whether the game
-- counts it among the functions an addon may only reach through a click of yours is not
-- something that can be read off anyone else's code -- and this is such a click either way.
local function LockAndBind(bagId, slotIndex)
    if CanLock(bagId, slotIndex) then
        if IsProtectedFunction and IsProtectedFunction("SetItemIsPlayerLocked") then
            CallSecureProtected("SetItemIsPlayerLocked", bagId, slotIndex, true)
        else
            SetItemIsPlayerLocked(bagId, slotIndex, true)
        end
    end
    if CanBind(bagId, slotIndex) then BindItem(bagId, slotIndex) end
    IG.RefreshLists()
end

-- Binding cannot be undone, so it is asked for first, the way resetting everything is.
local LOCK_BIND_DIALOG = "INVENTORY_GROUPING_LOCK_BIND"
local pendingLockBind

-- The menu is long gone by the time the answer comes back, and a slot is only a number: the
-- piece that was under it may have been moved, split or spent in between. The link is kept and
-- checked, so a yes can only ever bind the piece the question was asked about.
local function RunPendingLockBind()
    local pending = pendingLockBind
    pendingLockBind = nil
    if not pending then return end
    if GetItemLink(pending.bagId, pending.slotIndex) ~= pending.link then return end
    LockAndBind(pending.bagId, pending.slotIndex)
end

ESO_Dialogs[LOCK_BIND_DIALOG] = {
    title = { text = "Lock and bind?" },
    mainText = { text = "" },
    buttons = {
        { text = SI_DIALOG_YES, callback = RunPendingLockBind },
        { text = SI_DIALOG_NO, callback = function() pendingLockBind = nil end },
    },
}

local function ConfirmLockAndBind(bagId, slotIndex, itemLink)
    pendingLockBind = { bagId = bagId, slotIndex = slotIndex, link = itemLink }
    -- Only the half that is going to happen is warned about: a piece already bound, or one that
    -- binds on pickup, has nothing to lose here and should not be told it has.
    local warning = CanBind(bagId, slotIndex)
        and "The lock can come off again whenever you like. The binding cannot: once it is bound "
            .. "it is yours, and it can never be sold, traded or mailed again."
        or "The lock can come off again whenever you like."
    ESO_Dialogs[LOCK_BIND_DIALOG].mainText.text = string.format("%s\n\n%s",
        zo_strformat("<<1>>", GetItemLinkName(itemLink)), warning)
    ZO_Dialogs_ShowDialog(LOCK_BIND_DIALOG)
end

-- Filing a piece somewhere else takes the "awaiting upgrade" mark off it. The mark is a
-- sentence about the guild store pile -- hold this back, do not list it yet -- so out of that
-- pile there is nothing left for it to be about, and the line that would take it off is not
-- offered anywhere else either: left behind it would be a mark nobody could reach.
--
-- Every single filing goes through here, from the menu's short lines, from its long list of
-- categories and from the keys -- so this is the one place the step has to be opened, and the
-- line it is taken back under is written from what was there before and what is going there.
local function SetOverride(scope, id, groupKey)
    IG.UndoStep(nil, function()
        local was = IG.sv.overrides[scope][id]
        IG.NoteSaved(IG.sv.overrides[scope], id)
        IG.sv.overrides[scope][id] = groupKey
        if scope == "items" and groupKey ~= IG.AWAITING_GROUP then
            IG.SetAwaitingReason(id, nil)
        end
        local what = scope == "sets" and "a set"
            or scope == "types" and "every piece of an item" or IG.UndoPieces(1)
        if groupKey then
            return string.format("%s moved to %s", what, IG.MenuGroupName(groupKey))
        end
        if was then return string.format("%s taken out of %s", what, IG.MenuGroupName(was)) end
    end)
    IG.RefreshLists()
    -- Marked while the bank is already open: it goes in now rather than on the next visit.
    if groupKey == "TOBANK" and IG.ToBankCheck then IG.ToBankCheck() end
end

-- The whole list of categories, minus any the piece in hand cannot go to. Left out rather than
-- greyed: a line you cannot press is a line you read, try, and then have to be told about.
local function GroupEntries(scope, id, barred)
    local entries = {}
    for _, group in ipairs(IG.GetOrderedGroups()) do
        -- DISPOSAL only holds its four categories; nothing is sent to it directly. TO BANK is
        -- a mark on one piece that the bank takes off again once the piece is in it, so a whole
        -- set or every piece of an item is never sent there.
        if not (barred and barred[group.key]) and group.key ~= IG.DISPOSAL_KEY
            and not (group.key == "TOBANK" and scope ~= "items") then
            entries[#entries + 1] = {
                label = string.format("|c%s%s|r",
                    IG.GetGroupColor(group.key), IG.GetGroupLabel(group.key)),
                callback = function() SetOverride(scope, id, group.key) end,
            }
        end
    end
    return entries
end

local function ResetSet(setId)
    IG.UndoStep(nil, function()
        local was = IG.sv.overrides.sets[setId]
        IG.NoteSaved(IG.sv.overrides.sets, setId)
        IG.sv.overrides.sets[setId] = nil
        if was then return string.format("a set taken out of %s", IG.MenuGroupName(was)) end
    end)
    IG.RefreshLists()
end

-- The two lines a set gets, wherever they are shown from.
--
-- Nothing is left out of the set's list, SELL [GUILD STORE] included, and that is deliberate: a
-- set is a kind rather than a piece, the sentence is about every copy you have now and every
-- one you pick up later, and among them the bound ones are usually the minority. Barring the
-- line because one piece of the set is worn would take the whole sentence away over that piece.
-- So it is said about the set, and the pieces that cannot be listed quietly stand where they
-- would have stood anyway -- the same thing that happens to a piece bound after it was filed.
local function AddSetEntries(setId, setName, itemLink, flat)
    local name = SetNameText(setId, setName, itemLink)
    AddCustomSubMenuItem(MenuLabel(string.format("Change %s's Category", name)),
        GroupEntries("sets", setId))
    if IG.sv.overrides.sets[setId] then
        local label = MenuLabel(string.format("Reset %s Category To Default", name), RESET_SET_COLOR)
        local callback = function() ResetSet(setId) end
        if flat then flat(label, callback) else AddCustomMenuItem(label, callback) end
    end
end

-- The same two lines, offered to a menu somebody else is building (a set header's, which ends
-- with its colour lines). Both of them go through LibCustomMenu, so without it this adds
-- nothing and the menu around it stands on its own.
function IG.AddSetMenuEntries(setId, setName, itemLink)
    if not libCustomMenu or not setId then return false end
    AddSetEntries(setId, setName, itemLink)
    return true
end

-- The categories a piece is sent aside to, and where there is one, the key that does the same
-- thing. SELL, GUILDSELL and DECON have a key: CUSTOM is named by the player and a binding
-- cannot say what it would do.
local ASIDE = {
    { key = "SELL", action = "INVENTORY_GROUPING_SEND_TO_SELL", takes = function(bagId, slotIndex)
        return IG.CanSellToMerchant == nil or IG.CanSellToMerchant(bagId, slotIndex)
    end },
    -- Straight after its twin, because the choice between the two is the whole question the
    -- moment either of them is the answer: what a merchant pays, or what somebody will. What it
    -- is called can be changed like CUSTOM's, so the line asks rather than says.
    --
    -- The only one of the four that a piece can be refused by. A bound piece has nothing to do
    -- with a guild store and never will, so the line is not offered for it at all -- not shown
    -- and dead, which is a line that has to be pressed to find out it does nothing.
    { key = "GUILDSELL", action = "INVENTORY_GROUPING_SEND_TO_GUILDSELL", takes = function(bagId, slotIndex)
        return IG.CanListOnGuildStore(bagId, slotIndex)
    end },
    -- Only what some station will take apart: a recipe or a potion sent here would stand in a
    -- pile it can never leave. Missing API (never seen) turns nobody away.
    { key = "DECON", action = "INVENTORY_GROUPING_SEND_TO_DECONSTRUCT", takes = function(bagId, slotIndex)
        return CanItemBeDeconstructed == nil or CanItemBeDeconstructed(bagId, slotIndex)
    end },
    -- What this one is called is the player's to change, so the line says whatever it is
    -- called right now rather than a word written here.
    { key = "CUSTOM" },
    -- Put in the bank the next time it is opened (ToBank.lua): only from the backpack, and only
    -- what the bank takes. Its module switch hides the button and nothing else, so the line is
    -- offered whether or not the category is on show (always).
    { key = "TOBANK", always = true, action = "INVENTORY_GROUPING_SEND_TO_BANK", takes = function(bagId, slotIndex)
        return IG.CanDepositToBank(bagId, slotIndex)
    end },
}

-- Every one of them is named the way the heading names itself, and none of them is named here.
-- Two of these lines used to carry a word of their own -- "Sell", "Deconstruct" -- written in a
-- shape the list never uses, which is how one menu came to say "Sell" and another "SELL" about
-- the same category.
local function AsideName(aside)
    return IG.MenuGroupName(aside.key)
end

-- On the list, and standing: a module that is switched off is not a place anything can be
-- sent to, and offering it would send a piece nowhere. And where a category turns pieces away,
-- the piece in hand is asked about too -- named slots only, because with a handful marked
-- there is no one piece to ask and the line counts them instead. A category marked always
-- (TO BANK) is offered with its button hidden as well: hiding it is not switching it off.
local function AsideOffered(aside, bagId, slotIndex)
    if IG.GROUP_BY_KEY[aside.key] == nil then return false end
    if not aside.always and not IG.IsGroupAvailable(aside.key) then return false end
    if aside.takes and bagId and not aside.takes(bagId, slotIndex) then return false end
    return true
end

-- Everything marked with ctrl, junked. Shared with the keybind (INVENTORY_GROUPING_MARK_AS_JUNK,
-- IG.JunkHovered in this file): the key says the same sentence a selection-aware menu line used
-- to, and there is only one right way to say it -- removing the menu line (below) left this as
-- the one surviving way to junk a whole marked handful at once.
function IG.JunkSelection()
    IG.UndoStep(nil, function()
        local marked = 0
        for _, piece in ipairs(IG.SelectedPieces()) do
            -- The game says what it will not have marked -- a quest item, something bound to a
            -- purpose -- and asking it first is cheaper than being told off once per piece.
            local allowed = CanItemBeMarkedAsJunk == nil
                or CanItemBeMarkedAsJunk(piece.bagId, piece.slotIndex)
            if allowed and not IsItemJunk(piece.bagId, piece.slotIndex) then
                IG.MarkItemAsJunk(piece.bagId, piece.slotIndex)
                marked = marked + 1
            end
        end
        if marked > 0 then
            return string.format("%s marked as %s", IG.UndoPieces(marked), IG.MenuGroupName("JUNK"))
        end
    end)
    IG.ClearSelection()
end

local function AddMenuEntries(inventorySlot)
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bagId or not slotIndex then return end
    -- A piece you are wearing gets the game's own lines (Unequip, ...) and none of ours.
    if IG.IsWornSlot(bagId) then return end
    local itemLink = GetItemLink(bagId, slotIndex)
    if itemLink == "" then return end

    -- The piece under the cursor, not everything that looks like it. Every line below says
    -- "this single item", and it is the one thing the decision is made about.
    local pieceId = IG.PieceId(bagId, slotIndex)
    if not pieceId then return end
    local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)

    -- Every line below that is not itself a list of categories is said once, under one
    -- "Automation" line, so the item's own menu is not read through a dozen of ours to find
    -- the game's. What it collects is appended as it goes and shown at the very end.
    local wrapped = {}
    local function Flat(label, callback)
        wrapped[#wrapped + 1] = { label = label, callback = callback }
    end

    -- Straight to one of the two, in its own colour, without opening the list of every category.
    -- No rule fills either of them, so the only way anything reaches one is this line -- and the
    -- only reason a piece is in it. The way out says so in the same words and the same colour
    -- rather than leaving it to the general line about categories below.
    local override = IG.sv.overrides.items[pieceId]
    local toBankLine = false
    for _, aside in ipairs(ASIDE) do
        if AsideOffered(aside, bagId, slotIndex) then
            if aside.key == "TOBANK" then toBankLine = true end
            local name = AsideName(aside)
            if override ~= aside.key then
                Flat(MenuLabel(WithKey(string.format("Move to %s", name), aside.action)),
                    function() SetOverride("items", pieceId, aside.key) end)
            else
                Flat(MenuLabel(WithKey(string.format("Take out of %s", name), aside.action)),
                    function() SetOverride("items", pieceId, nil) end)
            end
        end
    end

    -- One category's line and no other's. A piece in the guild store pile is one you are keeping
    -- for what somebody will pay rather than getting rid of today, so it is the only pile where
    -- "not yet" is a thing to say about a piece -- and the line asks the piece where it is filed
    -- rather than reading the override above, because a whole set can have been sent there and
    -- every piece of it is in the pile just the same. It turns over in place: what puts the
    -- words on the row takes them off again, in the same words and the same colour.
    --
    -- Both reasons are always written, whichever one the piece is holding: the one it has says
    -- how to put it down, and the other says what it could be waiting for instead -- pressing
    -- that one changes its mind rather than giving it a second reason. Leaving the other out
    -- would make changing your mind two clicks and a menu opened twice.
    if IG.sv and IG.sv.awaitingMarksEnabled
        and IG.SetAsideKey({ bagId = bagId, slotIndex = slotIndex }) == IG.AWAITING_GROUP then
        local held = IG.AwaitingReason(pieceId)
        for _, reason in ipairs(IG.AWAITING_REASONS) do
            local label = IG.MenuName(IG.AwaitingLabel(reason.key), reason.color)
            if held == reason.key then
                Flat(MenuLabel(string.format("Unmark %s", label)),
                    function()
                        IG.UndoStep(string.format("%s unmarked as %s", IG.UndoPieces(1), label),
                            function() IG.SetAwaitingReason(pieceId, nil) end)
                        IG.RefreshLists()
                    end)
            else
                Flat(MenuLabel(string.format("Mark as %s", label)),
                    function()
                        IG.UndoStep(string.format("%s marked as %s", IG.UndoPieces(1), label),
                            function() IG.SetAwaitingReason(pieceId, reason.key) end)
                        IG.RefreshLists()
                    end)
            end
        end
    end

    -- Offered only while BOTH halves have something to do. A piece already locked, or already
    -- bound, has had this done to it; a line that would half happen is a line that misleads.
    if CanLock(bagId, slotIndex) and CanBind(bagId, slotIndex) then
        Flat(MenuLabel("Lock And Bind This Item", LOCK_BIND_COLOR),
            function() ConfirmLockAndBind(bagId, slotIndex, itemLink) end)
    end

    -- Only while the run is still claiming it, and in the group's own colour, because that is the
    -- group the line acts on rather than the category the item belongs to.
    if IG.IsSlotInLastRun and IG.IsSlotInLastRun(bagId, slotIndex) then
        Flat(MenuLabel("Distribute This Item", IG.GetGroupColor("LASTRUN")),
            function() IG.DistributeOneFromLastRun(bagId, slotIndex) end)
    end

    -- The long list leaves out whatever the short lines above left out, for the same reason: a
    -- bound piece is not a thing a guild store takes, and the category is no likelier a place
    -- for it when it is reached by scrolling.
    local barred
    for _, aside in ipairs(ASIDE) do
        if aside.takes and not aside.takes(bagId, slotIndex) then
            barred = barred or {}
            barred[aside.key] = true
        end
    end
    AddCustomSubMenuItem(MenuLabel("Change This Single Item's Category"),
        GroupEntries("items", pieceId, barred))
    -- The two above say it in their own words, so it is not said twice. TO BANK too, while its
    -- own line is there; a marked piece that is no longer in the backpack keeps this way out.
    if override and override ~= "SELL" and override ~= "DECON"
        and not (override == "TOBANK" and toBankLine) then
        Flat(MenuLabel("Reset This Single Item's Category To Default", RESET_ITEM_COLOR),
            function()
                IG.UndoStep(string.format("%s taken out of %s", IG.UndoPieces(1),
                    IG.MenuGroupName(override)), function()
                    IG.NoteSaved(IG.sv.overrides.items, pieceId)
                    IG.sv.overrides.items[pieceId] = nil
                end)
                IG.RefreshLists()
            end)
    end
    -- "Always": every piece of this item id, now and any that arrive later. Only DECONSTRUCT is
    -- barred here, for the same reason as above; a bound piece in GUILDSELL falls back on its own.
    local itemId = GetItemLinkItemId and GetItemLinkItemId(itemLink)
    if itemId and itemId ~= 0 then
        IG.sv.overrides.types = IG.sv.overrides.types or {}
        local always = IG.sv.overrides.types[itemId]
        local typeEntries = GroupEntries("types", itemId, barred and barred.DECON and { DECON = true })
        if always then
            table.insert(typeEntries, 1, {
                label = string.format("Stop Always Sending (-> %s)", IG.MenuGroupName(always)),
                callback = function() SetOverride("types", itemId, nil) end,
            })
        end
        AddCustomSubMenuItem(MenuLabel("Always Send This Item To"), typeEntries)
    end
    if hasSet then AddSetEntries(setId, zo_strformat("<<1>>", setName), itemLink, Flat) end

    if #wrapped > 0 then
        AddCustomSubMenuItem(MenuLabel("Automation"), wrapped)
    end
end

-- The piece under the cursor, for the keybind. The mouse is usually over a part of a row rather
-- than the row itself -- the icon, the name -- so the parents are walked until one of them turns
-- out to be a slot. Four is further than any of our rows are deep.
local function SlotUnderMouse()
    local control = WINDOW_MANAGER:GetMouseOverControl()
    for _ = 1, 4 do
        if not control then return nil end
        local data = control.dataEntry and control.dataEntry.data
        -- A worn piece answers to none of our keys.
        if data and data.bagId and data.slotIndex then
            if IG.IsWornSlot(data.bagId) then return nil end
            return data.bagId, data.slotIndex
        end
        -- The game's own helper answers for a slot control that carries no data entry. It is
        -- asked carefully: it is being handed controls that are not slots at all.
        local ok, bagId, slotIndex = pcall(ZO_Inventory_GetBagAndIndex, control)
        if ok and bagId and slotIndex then
            if IG.IsWornSlot(bagId) then return nil end
            return bagId, slotIndex
        end
        control = control.GetParent and control:GetParent()
    end
end

-- The key does what the menu line does, and undoes it when pressed again: a key you have to
-- reach for a menu to take back is a key you stop using.
local function SendHoveredTo(key)
    local bagId, slotIndex = SlotUnderMouse()
    if not (bagId and slotIndex) then return end
    local itemLink = GetItemLink(bagId, slotIndex)
    if itemLink == "" then return end

    local pieceId = IG.PieceId(bagId, slotIndex)
    if not pieceId then return end

    -- The key says what the menu line says: wherever the line is not there, the key refuses the
    -- same piece. Said out loud rather than done silently -- a press that visibly does nothing
    -- reads as the addon not responding, not as the game having a reason.
    local already = IG.sv.overrides.items[pieceId] == key
    if not already then
        for _, aside in ipairs(ASIDE) do
            if aside.key == key and aside.takes and not aside.takes(bagId, slotIndex) then
                PlaySound(SOUNDS.NEGATIVE_CLICK)
                d(string.format("Inventory 2.0: %s can't be moved to %s.",
                    zo_strformat("<<1>>", itemLink), AsideName(aside)))
                return
            end
        end
    end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    SetOverride("items", pieceId, not already and key or nil)
end

-- The junk mark from the key. What is marked with ctrl answers first: while a sentence is half
-- said the cursor is only where the mouse happens to be resting, not what the press is about.
-- A marked handful is junked and never unjunked -- several pieces have no one state between
-- them to turn over, and a press meant to junk them would quietly undo the ones already junked.
-- Under the cursor a single piece does turn over, because a key you have to reach for a menu to
-- take back is a key you stop using. Over nothing, and with nothing marked, it says nothing.
function IG.JunkHovered()
    if IG.SelectionCount() > 0 then
        PlaySound(SOUNDS.DEFAULT_CLICK)
        IG.JunkSelection()
        return
    end

    local bagId, slotIndex = SlotUnderMouse()
    if not (bagId and slotIndex) then return end
    if GetItemLink(bagId, slotIndex) == "" then return end

    if IsItemJunk(bagId, slotIndex) then
        PlaySound(SOUNDS.DEFAULT_CLICK)
        IG.UndoStep(string.format("%s taken out of %s", IG.UndoPieces(1), IG.MenuGroupName("JUNK")),
            function() IG.UnmarkItemAsJunk(bagId, slotIndex) end)
        return
    end
    -- The game says what it will not have marked, and it is asked before the sound rather than
    -- after: a click that is answered with nothing is worse than no click at all.
    if CanItemBeMarkedAsJunk and not CanItemBeMarkedAsJunk(bagId, slotIndex) then return end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    IG.UndoStep(string.format("%s marked as %s", IG.UndoPieces(1), IG.MenuGroupName("JUNK")),
        function() IG.MarkItemAsJunk(bagId, slotIndex) end)
    -- No list is built from here. Junking takes a piece out of every other tab, so the game
    -- rebuilds after the mark itself, and a list built from inside our own frame is the whole
    -- of the insecure callstack trouble (see Junk.lua, and HANDOFF section 5).
end

function IG.SendHoveredToSell() SendHoveredTo("SELL") end
function IG.SendHoveredToDeconstruct() SendHoveredTo("DECON") end
function IG.SendHoveredToGuildSell() SendHoveredTo("GUILDSELL") end
function IG.SendHoveredToBank() SendHoveredTo("TOBANK") end

function IG.CountOverrides()
    local count = 0
    for _, scope in pairs(IG.sv.overrides) do
        for _ in pairs(scope) do count = count + 1 end
    end
    return count
end

-- What the overrides actually say, grouped by where they send things: one line per destination
-- category, what scope moved there (a piece, a whole set, "always" by item id), and how many.
-- Not a list of the pieces themselves -- a piece's own name is only known while it is still
-- sitting in a bag or bank, and a lot of these are not, by the time anyone reads this page.
local SCOPE_WORD = { items = "piece", sets = "set", types = "item type" }
local SCOPE_ORDER = { "items", "sets", "types" }
function IG.OverrideBreakdown()
    local byGroup, order = {}, {}
    for _, scopeKey in ipairs(SCOPE_ORDER) do
        for _, groupKey in pairs(IG.sv.overrides[scopeKey] or {}) do
            local counts = byGroup[groupKey]
            if not counts then
                counts = { items = 0, sets = 0, types = 0 }
                byGroup[groupKey] = counts
                order[#order + 1] = groupKey
            end
            counts[scopeKey] = counts[scopeKey] + 1
        end
    end
    local lines = {}
    for _, groupKey in ipairs(order) do
        local counts, parts = byGroup[groupKey], {}
        for _, scopeKey in ipairs(SCOPE_ORDER) do
            local n = counts[scopeKey]
            if n > 0 then
                parts[#parts + 1] = string.format("%d %s%s", n, SCOPE_WORD[scopeKey], n == 1 and "" or "s")
            end
        end
        lines[#lines + 1] = { groupKey = groupKey, total = counts.items + counts.sets + counts.types,
            text = string.format("%s: %s", IG.MenuGroupName(groupKey), table.concat(parts, ", ")) }
    end
    table.sort(lines, function(a, b) return a.total > b.total end)
    return lines
end

function IG.ClearOverrides()
    ZO_ClearTable(IG.sv.overrides.items)
    ZO_ClearTable(IG.sv.overrides.sets)
    if IG.sv.overrides.types then ZO_ClearTable(IG.sv.overrides.types) end
    IG.RefreshLists()
end

function IG.InitOverrides()
    -- Saves written before the "Always" rules have no table for them.
    IG.sv.overrides.types = IG.sv.overrides.types or {}
    if not IG.IsEnabled() then return end
    -- LibCustomMenu is a hard DependsOn now (Inventory2.txt), so this guard never actually
    -- fires -- kept anyway as a second, independent line of defence (CLAUDE.md: never trust
    -- one safeguard alone) in case a future manifest edit ever loosens it back to optional.
    if not libCustomMenu then return end
    libCustomMenu:RegisterContextMenu(AddMenuEntries, libCustomMenu.CATEGORY_SECONDARY)
    -- A raw ZO_PreHook on ZO_InventorySlot_ShowContextMenu used to stand here: with something
    -- marked, it took the whole context menu over (Move N selected to ..., Mark N selected as
    -- ..., a selection-wide sell offer, adding a marked handful to a setup) so the game's own
    -- menu was never reached for that click. Hooking a protected function that way taints it, so
    -- it is gone -- removed rather than ported, because LibCustomMenu's own public API only ever
    -- ADDS entries through its category registry and has no mechanism to suppress the game's own
    -- default actions or every other addon's additions for a click that answers for several
    -- marked slots at once (see AddMenuEntries below, registered the ordinary way). The one piece
    -- of that menu with a surviving equivalent is junking a selection, which the
    -- INVENTORY_GROUPING_MARK_AS_JUNK keybind (IG.JunkHovered) already covered on its own.
end
