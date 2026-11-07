InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- Taking back the last thing you said about your bag.
--
-- What this undoes is our own decisions and nothing else: where a piece is filed, the junk
-- mark, what a pile is waiting for, what a heading is called and coloured and where it stands,
-- how a category is broken up and how its sets are drawn. Every one of those is a value in our
-- own saved settings, so putting it back is writing the old value where the new one went.
--
-- What it deliberately does not undo is anything the game owns: a sale, a binding, a lock, the
-- distributing of a run. Those are not ours to put back -- the coins are spent, the piece is
-- bound -- and a key that took some of them back and not others would be worse than no key at
-- all, because you would have to remember which.
--
-- The stack is kept for this session only and never saved. It holds bag slots and the values
-- that were in them a moment ago, and neither of those survives a logout with any meaning: the
-- slot a piece sat in is somebody else's by then, and a saved stack would go on growing for a
-- promise it could not keep. A selection is a sentence you are halfway through saying and is
-- dropped the same way; this is the sentence before it, and it is dropped when you log out.

-- Twenty steps back. Far enough to cover a tidying session, short enough that the far end of it
-- is still something you remember doing.
local DEPTH = 20

local stack = {}
-- The step being filled right now. Notes are only taken while one is open, which is what keeps
-- the load migrations and the cleanup pass -- which go through the same setters -- out of the
-- stack entirely: nothing opens a step for them.
local open = nil
-- While a step is being put back, the setters it goes through must not write a step of their
-- own: undoing is not a thing to undo.
local replaying = false

-- One piece or several, said the way a sentence says it.
function IG.UndoPieces(count)
    return string.format("%d %s", count, count == 1 and "piece" or "pieces")
end

---------------------------------------------------------------------------
-- Taking notes
---------------------------------------------------------------------------

-- One slot of our saved settings, as it stands before it is written over. The table and the key
-- are what a setter already has in hand, so every setter can take this note in one line.
--
-- Only the first note about a slot is kept. A step that writes the same slot twice -- naming a
-- reason and then clearing it -- has to hand back what was there before the step, not what was
-- there halfway through it.
function IG.NoteSaved(container, key)
    if not (open and container and key ~= nil) then return end
    for _, note in ipairs(open.notes) do
        if note.container == container and note.key == key then return end
    end
    open.notes[#open.notes + 1] = { container = container, key = key, value = container[key] }
end

-- The junk mark, which is the game's and not ours: it is read off the slot rather than out of
-- our settings, so it is noted by the piece it belongs to. The id is what says the slot still
-- holds the same piece when the time comes to put the mark back.
function IG.NoteJunk(bagId, slotIndex)
    if not open then return end
    local pieceId = IG.PieceId(bagId, slotIndex)
    if not pieceId then return end
    for _, note in ipairs(open.notes) do
        if note.pieceId == pieceId then return end
    end
    open.notes[#open.notes + 1] = {
        pieceId = pieceId, bagId = bagId, slotIndex = slotIndex,
        junk = IsItemJunk(bagId, slotIndex) == true,
    }
end

---------------------------------------------------------------------------
-- One step
---------------------------------------------------------------------------

-- Everything one press of yours changed, gathered under one line, so twelve pieces sent to SELL
-- come back with one press rather than twelve. The work is handed in as a function so the step
-- opens and closes around it and no caller can leave one open; where the line needs a number
-- that is only known while the work is being done, the function hands the line back instead.
--
-- Nesting joins rather than stacks: a line that calls another line's work is still one press.
function IG.UndoStep(label, work)
    if open or replaying then return work() end
    open = { label = label, notes = {} }
    local ok, said = pcall(work)
    local step = open
    open = nil
    if not ok then error(said, 0) end
    if type(said) == "string" then step.label = said end
    -- A press that changed nothing leaves nothing behind: a step with no notes in it would
    -- answer a later ctrl+z with a message about something that never happened.
    if #step.notes == 0 or not step.label then return end
    stack[#stack + 1] = step
    if #stack > DEPTH then table.remove(stack, 1) end
end

---------------------------------------------------------------------------
-- Putting one back
---------------------------------------------------------------------------

-- The junk mark goes back on the piece that was noted and on no other. A slot is only a number,
-- and between the press and the undo the piece may have been sold, spent or moved; where the id
-- under the slot is not the one that was noted, that note is quietly passed over and the rest of
-- the step still lands. The mark itself goes down the careful road every other place in the
-- addon uses (Junk.lua).
local function RestoreJunk(note)
    if IG.PieceId(note.bagId, note.slotIndex) ~= note.pieceId then return end
    if IsItemJunk(note.bagId, note.slotIndex) == note.junk then return end
    if note.junk then
        if CanItemBeMarkedAsJunk and not CanItemBeMarkedAsJunk(note.bagId, note.slotIndex) then return end
        IG.MarkItemAsJunk(note.bagId, note.slotIndex)
    else
        IG.UnmarkItemAsJunk(note.bagId, note.slotIndex)
    end
end

-- Backwards through the notes, because a step may have written the same slot more than once and
-- the earliest note is the one that was true before the press.
local function Replay(step)
    local touchedSaved = false
    replaying = true
    for index = #step.notes, 1, -1 do
        local note = step.notes[index]
        if note.container then
            note.container[note.key] = note.value
            touchedSaved = true
        else
            RestoreJunk(note)
        end
    end
    replaying = false
    return touchedSaved
end

---------------------------------------------------------------------------
-- The key
---------------------------------------------------------------------------

-- Said where the game says everything else that happened and then stopped mattering: the alert
-- run, top of the screen, which fades on its own. No sound of its own -- the press was yours and
-- you are watching the list it changes.
local function Say(text)
    if ZO_Alert then ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, text) end
end

-- Only while one of our lists is on screen. Everything on the stack is about rows in that list,
-- and a key that rearranged your bag from horseback would be a key pressed by accident. The same
-- question the rest of the addon asks about which list is in front.
local function InventoryShowing()
    return IG.VisibleList ~= nil and IG.VisibleList() ~= nil
end

function IG.Undo()
    if not InventoryShowing() then return end
    local step = table.remove(stack)
    if not step then
        Say(IG.S("UNDO_NOTHING"))
        return
    end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    local touchedSaved = Replay(step)
    Say(string.format(IG.S("UNDO_UNDONE"), step.label))
    -- The same road a piece moved by hand travels home, and the only one: the rows say something
    -- else about themselves now and the list is built again to say it. Nothing here commits one
    -- and nothing here is put off with zo_callLater -- a later frame of ours is still ours (see
    -- HANDOFF section 5).
    --
    -- A step that only moved junk marks about asks for nothing: taking the mark off a piece puts
    -- it back on every other tab, so the game rebuilds after the mark itself.
    if touchedSaved then IG.RefreshLists() end
end

-- What is waiting, for anything that wants to know whether the key has anything to say.
function IG.UndoDepth()
    return #stack
end
