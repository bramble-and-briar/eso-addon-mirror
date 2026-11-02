InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- The buttons on the game's own sort header, in the run it leaves empty between NAME and the
-- columns on the far right. "Top" keeps the gap on the left of NAME, where the sort arrows
-- leave room; the rest stand to the right of it.
--
-- They were on the bottom bar before, squeezed between the free slot counter and the money.
-- That bar is shared with the bank and the guild bank and had no room to spare; the sort header
-- belongs to the list they act on and is right above it.

-- The same two marks every group header wears, so the bar says what a header says.
local COLLAPSE_ICON = "EsoUI/Art/Progression/removePoints_up.dds"
local EXPAND_ICON = "EsoUI/Art/Progression/addPoints_up.dds"
local TO_TOP_ICON = "EsoUI/Art/Miscellaneous/list_sortup.dds"
local SORT_ICON = "EsoUI/Art/Miscellaneous/list_sortdown.dds"
local LOCKED_ICON = "EsoUI/Art/Miscellaneous/status_locked.dds"
-- One mark per answer the locked line can give. It is the only part of that button that moves:
-- the words beside it stay as they are, so stepping through the three neither resizes the
-- button nor shifts the answer written next to it.
-- The lock itself stands for the answer that does nothing to the list -- the piece is locked
-- and that is all; the minus for the one that takes them out of it; the group for the one that
-- gathers them under a heading of their own.
local LOCKED_MODE_ICONS = {
    hidden = "EsoUI/Art/Progression/removePoints_up.dds",
    grouped = "EsoUI/Art/LFG/LFG_indexIcon_group_up.dds",
    asis = LOCKED_ICON,
}

local BUTTON_FONT = "$(MEDIUM_FONT)|15|soft-shadow-thin"
-- The sort header is a short bar with little room to spare, so the buttons are trimmed down.
local ICON_SIZE = 14
local ICON_GAP = 3
local PADDING_X = 5
local PADDING_Y = 2
local SORT_HEADER_GAP = 8  -- between a button and the NAME header it stands beside
local NAME_MIN_WIDTH = 40  -- a header measured before it is drawn comes back at nothing
local BUTTON_GAP = 6       -- between two buttons standing side by side
-- The bottom bar carries two lines, one under the other, and each of them is one thing:
-- "Locked Items: Hidden (34)", written on a single plate, the subject and the answer parted by
-- a colon and by their colour rather than by a gap. Set beside the button the answer read as a
-- second control that could not be pressed; set on it, the whole line is what the press changes.
--
-- The subject keeps whatever colour the plate gives its writing -- cream at rest, white under
-- the mouse -- and the answer carries its own inside the text, which is what a colour written
-- into a string is for.
local LOCKED_BUTTON_TEXT = "Locked Items"
local MOVED_BUTTON_TEXT = "Moved Items"
-- The same two subjects in one word each, for a bar that has not left the room for two. The
-- word that is dropped is the one both lines share and neither needs: what else on an inventory
-- bar would be locked, or moved. The answer after the colon is untouched, because the answer is
-- the part that is read.
local LOCKED_SHORT_TEXT = "Locked"
local MOVED_SHORT_TEXT = "Moved"
-- What each mode is called where the answer is written. "Separate Group" says where the pieces
-- went; "Shown" and "Hidden" say whether they are there at all.
local LOCKED_ANSWERS = { hidden = "Hidden", grouped = "Separate Group", asis = "Shown" }
local LINE_DROP = 3     -- between the first line and the second
local LINE_INSET = 2    -- between the line ruled across the bar and the pair standing under it
-- Long enough that crossing the pair on the way to the money says nothing, short enough that
-- stopping on one of them is answered while the pointer is still there.
local TIP_DELAY = 1000
-- The marks in the box are not on the way anywhere -- they are a control panel and you are
-- standing on one of them because you went there -- so theirs comes up as good as at once.
-- Still a wait rather than none at all: it is what lets sliding along the row of four leave one
-- tip behind rather than four.
local PANEL_TIP_DELAY = 50
local TIP_GAP = 6      -- between the top of the plate and the foot of the tip above it
local TIP_MARK = "· "  -- what every line of the tip opens with, the tooltip's own dot
local TIP_REST = { 0.62, 0.62, 0.58 }   -- a mode that is not the one in force
local BAR_SLOTS_GAP = 14
local BAR_EDGE_GAP = 10   -- between the game's own writing and a plate standing beside it
-- Below this a plate is a box with a letter in it, so a run narrower than this is no run.
local MIN_LINE_WIDTH = PADDING_X * 2 + ICON_SIZE + ICON_GAP + 44

-- Three tones for the three kinds of answer a line can give, so the colour has said what the
-- words say before they are read.
--
-- Something is being kept off the screen: the cream the buttons wear with red mixed into it --
-- enough that the eye catches something being withheld, not so much that a bag full of locked
-- gear is an alarm. Something is moved about but all of it is still there: the plain cream,
-- between the two. Nothing is being done at all: the same cream taken down towards the quiet
-- grey the bar writes its own numbers in, so the ordinary answer sits back into the bar.
local ANSWER_WARN_COLOR = "FF4A4A"
local ANSWER_WARN_SHARE = 0.62
local ANSWER_CALM_FACTOR = 0.72

-- The line under it: whether a piece you sent to SELL, DECONSTRUCT or one of your own is still
-- drawn, stood down, in the category it belongs to. Two answers, written the same way its
-- neighbour's three are, so the pair reads as a table rather than as two unrelated controls.
-- A tick for the copies being shown and a minus for them being taken out, which is the mark its
-- neighbour uses for the same idea.
local MOVED_SHOWN_ICON = "EsoUI/Art/Miscellaneous/check_icon_64.dds"
local MOVED_HIDDEN_ICON = "EsoUI/Art/Progression/removePoints_up.dds"

-- Where the box stands on a window with no bottom bar to go down to: under the search box,
-- which every one of these windows has.
local SWITCH_DROP = 4
-- The box's own size, for a window that has to give it one. On the bottom bar it takes its
-- height from the lines already standing there and SWITCH_WIDTH is only the widest it is
-- allowed to be. Both are given rather than anchored: a control is allowed two anchors and
-- both of those are spoken for.
local SWITCH_HEIGHT = 36
local SWITCH_WIDTH = 150

-- The addon's name down the left edge of the bag, turned on its side and reading from the top
-- of the window to the foot of it. It is a mark and not a control: nothing about it changes,
-- nothing is written under it, and it does not take the mouse -- a name standing in the strip
-- beside the window must never be in front of anything.
--
-- The letters are parted by a space each. A wordmark is read as a shape before it is read as a
-- word, and the run of a long word set solid is a block; spaced out it is a column, which is
-- what a name standing on end wants to be. The 2.0 keeps the same face at a little over half
-- the size, so it reads as the number after a name rather than as part of the word.
local MARK_FACE, MARK_STYLE = "$(MEDIUM_FONT)", "soft-shadow-thin"
local MARK_WORD = "I N V E N T O R Y"
local MARK_TAIL = "2.0"
local MARK_WORD_SIZE = 26
local MARK_TAIL_SHARE = 0.6
local MARK_GAP = 10          -- between the end of the word and the number after it
-- Quiet on purpose: the cream every outline in this addon wears, taken down far enough that it
-- reads as something printed on the frame rather than as a thing on the screen asking to be
-- looked at. The colour is given to the writing and the transparency to the control that holds
-- it, which is the one alpha that is always read.
local MARK_ALPHA = 0.3
local MARK_FLASH_ALPHA = 0.65  -- at the peak of the bag-open sparkle (Drawer.lua, IG.FlashDrawerStrip)
local MARK_INSET = 22        -- from the window's left edge out to the middle of the column

-- The box of marks: an outline and what stands inside it, nothing that lights up and nothing
-- that can be pressed -- the four marks in it are what answer the mouse. It stands on the
-- bottom bar, under the words that count the slots.
--
-- The padding is not the same in both directions. Across the box there is room to spare, so
-- the marks are held well clear of the outline. Down it there is none: the box is one line of
-- the bar tall and every pixel given to the padding comes straight off the marks, which are
-- the whole of what the box is for. One pixel is enough to keep them off the outline, and the
-- marks are half again the size they were with four.
local PANEL_PAD_X = 4
local PANEL_PAD_Y = 1
local PANEL_ICON_MIN = 12
local PANEL_ICON_ALPHA = 0.75   -- at rest, so coming up to full colour is what hovering says
local PANEL_ICON_PRESS = 0.45   -- held down: the mark goes back before it comes forward

local IDLE_ALPHA, HOVER_ALPHA = 0.85, 1
local EDGE_ALPHA = 0.5
-- A button that is answering a switch, and one under the mouse. At rest they wear the cream
-- every outline on a header wears, which is read at paint time rather than kept here.
local ACTIVE_COLOR = "5CE07A"
local HOVER_COLOR = "FFFFFF"

-- Inside the outline: a dark plate carrying a little more light at its top than at its foot, so
-- the button reads as something raised off the bar rather than as a rectangle ruled on it. The
-- warmth is the outline's own cream, taken most of the way down to black.
local FILL_REST = { "3A3730", "16150F" }
local FILL_HOVER = { "55503F", "24221A" }
local FILL_ALPHA, FILL_HOVER_ALPHA = 0.82, 0.92

local function PaintFill(fill, hovered)
    local top, bottom = unpack(hovered and FILL_HOVER or FILL_REST)
    local tr, tg, tb = IG.HexToRGB(top)
    local br, bg, bb = IG.HexToRGB(bottom)
    local alpha = hovered and FILL_HOVER_ALPHA or FILL_ALPHA
    fill:SetVertexColors(VERTEX_POINTS_TOPLEFT, tr, tg, tb, alpha)
    fill:SetVertexColors(VERTEX_POINTS_TOPRIGHT, tr, tg, tb, alpha)
    fill:SetVertexColors(VERTEX_POINTS_BOTTOMLEFT, br, bg, bb, alpha)
    fill:SetVertexColors(VERTEX_POINTS_BOTTOMRIGHT, br, bg, bb, alpha)
end

-- How many pieces each list is holding back, told to us by the list build as it drops them
-- (IG.NoteLockedHidden). Kept here rather than asked for: the answer only exists while a list
-- is being made, and the number is read long after that.
local hiddenCounts = {}

local function WarnColor()
    local r, g, b = IG.HexToRGB(IG.DEFAULT_ICON_COLOR)
    local wr, wg, wb = IG.HexToRGB(ANSWER_WARN_COLOR)
    local share = ANSWER_WARN_SHARE
    return IG.RGBToHex(r + (wr - r) * share, g + (wg - g) * share, b + (wb - b) * share)
end

local function CalmColor()
    return IG.DimColor(IG.DEFAULT_ICON_COLOR, ANSWER_CALM_FACTOR)
end

-- One line in two tones: the name the button carries, then the answer after a colon in a colour
-- of its own. The colour is written into the string because a label is painted in a single
-- colour and this line is not a single thing -- the mark-up outlives the SetColor the plate
-- gives its writing, and the pointer brightening the subject leaves the answer as it was.
local function LineText(name, answer, hex)
    return string.format("%s: |c%s%s|r", name, hex, answer)
end

-- A plate is as wide as what is written on it. Said once here because the sort button's
-- writing is not the writing it was built with: "Sort: Quality" is four letters longer than
-- "Sort: Name", and a plate built for the shorter one has the longer one hanging out of it.
local function FitButton(button)
    button:SetWidth(button.igPadX * 2 + button.igIconSize + ICON_GAP + button.label:GetTextWidth())
end

-- The two lines on the bottom bar are measured together and both given the wider of the two
-- answers. What they say grows and shrinks with the mode now, and a pair that disagrees about
-- its width by a few letters reads as a wobble every time either of them is pressed.
local function FitButtons(button)
    FitButton(button)
    local twin = button.igTwin
    if not twin then return end
    FitButton(twin)
    local width = zo_max(button:GetWidth(), twin:GetWidth())
    -- And never wider than the run the bar has left for them, when the bar has said. A plate
    -- past its parent's edge is clipped there and stops taking the mouse; the writing on it is
    -- cut short instead, which is the lesser of the two and only happens where the wording has
    -- already been taken down to one word a line.
    if button.igMaxWidth then width = zo_min(width, button.igMaxWidth) end
    button:SetWidth(width)
    twin:SetWidth(width)
end

local function Paint(button, hovered)
    local lit = button.active ~= nil and button.active()
    local hex = hovered and HOVER_COLOR or (lit and ACTIVE_COLOR or IG.DEFAULT_ICON_COLOR)
    local r, g, b = IG.HexToRGB(hex)
    local alpha = hovered and HOVER_ALPHA or IDLE_ALPHA
    PaintFill(button.fill, hovered)
    -- A button that steps through answers rather than turning one over wears a different mark
    -- for each of them, and says which it is wearing at paint time the same way it says what it
    -- is called.
    if button.iconFor then button.icon:SetTexture(button.iconFor()) end
    button.icon:SetColor(r, g, b, alpha)
    if button.text then
        button.label:SetText(button.text())
        FitButtons(button)
    end
    button.label:SetColor(r, g, b, alpha)
    for _, edge in ipairs(button.edges) do edge:SetColor(r, g, b, hovered and EDGE_ALPHA * 1.6 or EDGE_ALPHA) end
end

-- The selling layout: the bag while any of the five scenes a sale can happen in is showing --
-- a merchant, a fence, a guild store, a trade and the mail (IG.IsTrading).
local function SellingLayout(inventory)
    return inventory == INVENTORY_BACKPACK and IG.IsTrading ~= nil and IG.IsTrading()
end

-- The box of marks stands on the bottom bar as well now, in the left column under the slot
-- counter, and is put where it belongs by the same pass that puts the pair there. Named here,
-- above that pass, because what it does needs the icon layout that is written further down and
-- a local read from a line above its own is a global as far as Lua is concerned.
local SettleBox

-- What the game has already written on a bar, as a list of runs along it.
--
-- Looked for by measuring and never by name. The controls the game puts on these bars have
-- been searched for by name twice in this addon and both times the name quietly was not there
-- (893858d, 3837b51) -- a name that is wrong fails in silence, while a rectangle either lies
-- over ours or it does not. Only writing is treated as being in the way: a label is what a
-- player reads off this bar, and the plates and backdrops behind it are exactly what our own
-- plates are meant to stand on. A label with nothing written in it is nothing to avoid; the
-- game leaves several of those on a bar it is done with.
--
-- Ours are stepped over whole, plate and writing together, or the pair would be measuring
-- itself and finding no room anywhere.
local function CollectWriting(control, runs, depth)
    for index = 1, control:GetNumChildren() do
        local child = control:GetChild(index)
        if child and not child.igOurs and not child:IsHidden() then
            local text = child.GetText and child:GetText() or nil
            if child:GetType() == CT_LABEL then
                if child:GetWidth() > 0 and text ~= nil and text ~= "" then
                    runs[#runs + 1] = { child:GetLeft(), child:GetRight() }
                end
            elseif depth > 0 then
                CollectWriting(child, runs, depth - 1)
            end
        end
    end
end

-- The widest run of the bar with none of that writing in it, as a left edge and a width.
local function FreeRun(bar)
    local runs = {}
    CollectWriting(bar, runs, 3)
    table.sort(runs, function(a, b) return a[1] < b[1] end)
    local edge, best, bestLeft = bar:GetLeft(), 0, nil
    for _, run in ipairs(runs) do
        if run[1] - edge > best then best, bestLeft = run[1] - edge, edge end
        if run[2] > edge then edge = run[2] end
    end
    if bar:GetRight() - edge > best then best, bestLeft = bar:GetRight() - edge, edge end
    return bestLeft, best
end

-- Both lines say the same thing in fewer words, or go back to saying it in full. Repainted
-- rather than relabelled: painting is what writes a line and measures it, and the two are
-- measured together so the pair keeps one width between them.
local function SetTight(button, tight)
    if button.igTight == tight then return end
    button.igTight = tight
    button.igTwin.igTight = tight
    Paint(button, false)
    Paint(button.igTwin, false)
end

-- How far along the bar the pair starts, and how much it is allowed to say once it is there.
--
-- On the bag, the bank and the two after them the answer is a constant: the bar is that
-- window's own, the counter sits at the left end of it and the run after the counter is empty
-- all the way to the money. The selling layout is handed a bar the game has already filled --
-- a fence writes what the day's fencing has cost and what the haggling is worth across it --
-- and where the room is left there is not something we are told. It is looked for.
--
-- The room found decides the wording, so the wording is settled here and not where the lines
-- are built. Measured again only when the room itself has changed: the pair is written and
-- measured to answer this, and asking it every pass would be rewriting both lines every pass.
local function SettleWidth(button, twin, bar)
    if not SellingLayout(button.igInventory) then
        if button.igRoom ~= nil then
            button.igRoom, button.igMaxWidth, twin.igMaxWidth = nil, nil, nil
            SetTight(button, false)
            Paint(button, false)
            Paint(twin, false)
        end
        return BAR_SLOTS_GAP
    end

    local runLeft, runWidth = FreeRun(bar)
    if not runLeft or runWidth < MIN_LINE_WIDTH + BAR_EDGE_GAP * 2 then
        return button.igGapX or BAR_SLOTS_GAP
    end

    local room = runWidth - BAR_EDGE_GAP * 2
    if button.igRoom ~= room then
        button.igRoom = room
        -- In full if it fits, in one word each if it does not. The cap is what the fitting
        -- reads after that, so the plate stays inside the run whatever either line ends up
        -- saying -- including under the mouse, which writes and measures both again.
        button.igMaxWidth, twin.igMaxWidth = nil, nil
        SetTight(button, false)
        Paint(button, false)
        Paint(twin, false)
        if button:GetWidth() > room then SetTight(button, true) end
        button.igMaxWidth, twin.igMaxWidth = room, room
        Paint(button, false)
        Paint(twin, false)
    end

    -- Read off the same anchor the pair is hung by, so the line it stands on is untouched: the
    -- drop kept on the button is measured from that anchor's own middle.
    local anchor = button.igAnchorTo
    local from = button.igAnchorPoint == RIGHT and anchor:GetRight() or anchor:GetLeft()
    return zo_round(runLeft + BAR_EDGE_GAP - from)
end

-- Where the pair on the bottom bar stands is settled once that bar has been laid out rather
-- than when the buttons are built: the height of the bar and the line ruled across its top are
-- the game's, and asking for either at load time answers nothing. Run after every rebuild it
-- costs a few measurements and does nothing at all once the pair is where it belongs.
--
-- Two things it will not have. The rule across the bar must not cross a plate -- half a button
-- above the line and half below it reads as two broken boxes, which is how the pair first went
-- out. And neither plate may fall outside the bar: a control past its parent's edge is clipped
-- there and stops taking the mouse, which is the whole of what these two are for. When the room
-- between the rule and the foot of the bar is too shallow for both lines, the plates give up
-- their padding rather than the pair giving up a line.
local function SettleLines(button)
    local twin = button.igTwin
    local bar = button:GetParent()
    if not twin or bar:GetHeight() <= 0 or button:GetHeight() <= 0 then return end

    -- Across the bar first. What the pair is allowed to be as wide as decides what it says,
    -- and what it says is settled before either line is put anywhere.
    local gapX = SettleWidth(button, twin, bar)

    local divider = bar:GetNamedChild("Divider")
    local ceiling = LINE_INSET +
        ((divider and not divider:IsHidden()) and divider:GetBottom() or bar:GetTop())
    local floor = bar:GetBottom() - LINE_INSET
    local room = floor - ceiling
    if room <= 0 then return end

    local height = button:GetHeight()
    if height * 2 + LINE_DROP > room then
        height = zo_max(ICON_SIZE + 2, zo_floor((room - LINE_DROP) / 2))
        button:SetHeight(height)
        twin:SetHeight(height)
    end

    local shift = zo_max(0, ceiling - button:GetTop())
    local overhang = twin:GetBottom() + shift - floor
    if overhang > 0 then shift = shift - overhang end
    if zo_abs(shift) >= 1 or button.igGapX ~= gapX then
        button.igDropY = button.igDropY + shift
        button.igGapX = gapX
        button:ClearAnchors()
        button:SetAnchor(LEFT, button.igAnchorTo, button.igAnchorPoint, gapX, button.igDropY)
    end

    -- And the box of marks, which shares this bar and takes its extents from the pair rather
    -- than measuring the bar over again. Run whether or not the pair moved: the box is hung
    -- after the pair is built and has its own first pass to get through. Not on the selling
    -- layout, where there is no box to put anywhere.
    if button.igBox and not SellingLayout(button.igInventory) then SettleBox(button) end
end

-- Every button that has been built, so one that answers a switch can be repainted when the
-- switch moves -- including the copies standing on the other panels' headers.
local buttons = {}
-- The first of the two lines on each bottom bar, by the list it speaks for. The box of marks
-- on that list's window is hung off this bar too and is settled with the pair, so the pass that
-- builds the screens has to be able to find the line that was built for it.
local barLines = {}
-- The box of marks built for each window. Named here, above the pass that repaints them,
-- because a local read from a line above its own is a global as far as Lua is concerned.
local screens = {}
local PaintScreen
-- The name down the side of the bag, and the pass that gives it its size. Named here, above
-- that pass, because a local read from a line above its own is a global as far as Lua is
-- concerned.
local wordmark
local SettleWordmark

-- The first opening after a reload used to show the name and the drawer marks at the top of the
-- window for a frame and then jump them down: the first pass ran before the bag had been laid
-- out, the rule the column starts from answered nothing, and the fallback to the window's top
-- edge was drawn. Now an unanswered pass keeps both hidden and asks again on the next frame, a
-- one-shot timer with one pending at a time, and only after SETTLE_TRIES of those does the
-- visible fallback (the window's top edge) go on screen: late, but never missing.
local SETTLE_TRIES = 20
local settleTries = 0
local settlePending = false

function IG.RepaintToolbar()
    for _, button in ipairs(buttons) do
        -- A button that only belongs on a list we are grouping says so for itself.
        if button.shown then button:SetHidden(not button.shown()) end
        -- And a header one of them stands in place of is put away on its own answer rather
        -- than on that button's. The two are not the same question: the header is dead for as
        -- long as the list under it is ours, while the button is only worth showing where it
        -- says something true. Tying the header to the button left the selling layout with a
        -- header that was shown and did nothing. Asked every time rather than once: the game
        -- shows its own headers again whenever it rebuilds the bar, and this is the pass that
        -- runs after every rebuild of ours.
        if button.covers then button.covers:SetHidden(button.covered()) end
        -- Painted whether or not it can be seen at this moment. A button on a window that is
        -- shut is exactly the one that most needs it: the toolbar is built while every bag is
        -- closed, and skipping those left each switch wearing the wording and the mark it was
        -- built with -- "Shown" written beside a list that was in fact holding pieces back.
        -- Nothing paints when a window opens, so the lie stood until the mouse happened to
        -- cross the button.
        Paint(button, false)
        -- And the pair on the bottom bar is put where that bar's own rule leaves room for it,
        -- which is a question only a bar that has been drawn can answer.
        if button.igFirstLine then SettleLines(button) end
    end
    -- And the marks in each box, for the same reason: a box on a window that is shut is the
    -- one that most needs saying what it says before the mouse has been near it.
    for _, screen in ipairs(screens) do PaintScreen(screen) end
    -- And the name beside the bag, which is measured rather than painted: a font asked for the
    -- width of a word before anything has been drawn answers nothing, so the first pass that
    -- gets a number is the one that sizes it. This is that pass, and it is also the one that
    -- runs before the window has ever been opened, which is what puts the name where it belongs
    -- without the mouse having to go near it.
    local settled = SettleWordmark(settleTries >= SETTLE_TRIES)
    -- And the strip of drawer marks in the same column, which is put where it belongs by the
    -- same measurement and so by the same pass.
    if IG.SettleDrawerStrip then IG.SettleDrawerStrip() end
    -- Not answered yet on an open window: asked again next frame, never from inside this pass.
    local window = wordmark and wordmark.igWindow
    if settled or not window or window:IsHidden() then
        settleTries = 0
    elseif not settlePending then
        settlePending = true
        settleTries = settleTries + 1
        zo_callLater(function()
            settlePending = false
            IG.RepaintToolbar()
        end, 0)
    end
end

-- Only the two lines on the bottom bar carry one of these, and only after the pointer has stood
-- still on one of them for a second: what the rest of the buttons do is written on them.
--
-- The count is what cancels a tip that is no longer wanted. A timer cannot be called back, so
-- every entering and every leaving takes the number up by one and the waiting call finds its
-- own out of date and does nothing -- which covers leaving the plate, and covers crossing
-- straight onto the other line as well.
local tipGeneration = 0

local function HideTip(button)
    tipGeneration = tipGeneration + 1
    if not button.igTipShown then return end
    button.igTipShown = false
    ClearTooltip(InformationTooltip)
end

-- Above the control, or below it for one standing at the top of a window, where there is
-- nothing above it to open into.
local function ShowTipNow(button)
    button.igTipShown = true
    if button.igTipBelow then
        InitializeTooltip(InformationTooltip, button, TOP, 0, TIP_GAP, BOTTOM)
    else
        InitializeTooltip(InformationTooltip, button, BOTTOM, 0, -TIP_GAP, TOP)
    end
    button.igTip()
end

local function ShowTipLater(button)
    if not button.igTip then return end
    tipGeneration = tipGeneration + 1
    local mine = tipGeneration
    zo_callLater(function()
        -- Nothing here reaches a protected function, so the wait costs the list nothing.
        if mine ~= tipGeneration or not MouseIsOver(button) then return end
        ShowTipNow(button)
    end, button.igTipDelay or TIP_DELAY)
end

-- One mode to a line, the one the list is giving now in the colour a lit button wears.
local function TipMode(text, current)
    local r, g, b = TIP_REST[1], TIP_REST[2], TIP_REST[3]
    if current then r, g, b = IG.HexToRGB(ACTIVE_COLOR) end
    InformationTooltip:AddLine(TIP_MARK .. text, "ZoFontGame", r, g, b)
end

-- A line that answers nothing and only says something, in the cream the tip's own head wears.
local function TipLine(text)
    local r, g, b = IG.HexToRGB(IG.DEFAULT_ICON_COLOR)
    InformationTooltip:AddLine(TIP_MARK .. text, "ZoFontGame", r, g, b)
end

local function TipHead(title)
    local r, g, b = IG.HexToRGB(IG.DEFAULT_ICON_COLOR)
    InformationTooltip:AddLine(title, "ZoFontWinH5", r, g, b)
    ZO_Tooltip_AddDivider(InformationTooltip)
end

-- A thin line along each of the four sides, drawn over whatever the control is filled with.
-- Both the buttons and the box below the name wear one, and it is the whole of what the box is.
local function AddEdges(control)
    control.edges = {}
    for _, points in ipairs({ { TOPLEFT, TOPRIGHT }, { BOTTOMLEFT, BOTTOMRIGHT },
                              { TOPLEFT, BOTTOMLEFT }, { TOPRIGHT, BOTTOMRIGHT } }) do
        local edge = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
        edge:SetAnchor(points[1], control, points[1])
        edge:SetAnchor(points[2], control, points[2])
        edge:SetDrawLayer(DL_CONTROLS)
        control.edges[#control.edges + 1] = edge
    end
    control.edges[1]:SetHeight(1); control.edges[2]:SetHeight(1)
    control.edges[3]:SetWidth(1); control.edges[4]:SetWidth(1)
end

-- The same four lines, for the drawers beside the bag: their boxes are the boxes on this bar
-- said again, and two ways of drawing one outline would drift apart the first time either was
-- touched.
IG.AddEdges = AddEdges

-- A plate, an icon, a short label beside it, and a thin outline around all of it, like the hint
-- boxes on the group headers. active, when given, says whether the button is lit: it answers a
-- switch rather than firing and forgetting.
local function CreateButton(parent, iconPath, text, onClick, active)
    local button = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    button:SetMouseEnabled(true)
    button.active = active
    -- Ours, for the pass that looks along a bar for the run the game has left empty: it has to
    -- step over the plates we put there ourselves, writing and all, or it would be measuring
    -- the pair against itself.
    button.igOurs = true

    -- Under everything else, out to the outline on all four sides: the edges are drawn over it.
    button.fill = WINDOW_MANAGER:CreateControl(nil, button, CT_TEXTURE)
    button.fill:SetAnchor(TOPLEFT, button, TOPLEFT)
    button.fill:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT)
    button.fill:SetDrawLayer(DL_BACKGROUND)

    button.icon = WINDOW_MANAGER:CreateControl(nil, button, CT_TEXTURE)
    button.icon:SetTexture(iconPath)
    button.icon:SetDimensions(ICON_SIZE, ICON_SIZE)
    button.icon:SetAnchor(LEFT, button, LEFT, PADDING_X, 0)
    button.icon:SetDrawLayer(DL_CONTROLS)

    button.label = WINDOW_MANAGER:CreateControl(nil, button, CT_LABEL)
    button.label:SetFont(BUTTON_FONT)
    button.label:SetText(text)
    button.label:SetAnchor(LEFT, button.icon, RIGHT, ICON_GAP, 0)
    button.label:SetDrawLayer(DL_CONTROLS)

    AddEdges(button)

    button.igPadX, button.igIconSize = PADDING_X, ICON_SIZE
    button:SetHeight(zo_max(ICON_SIZE, button.label:GetTextHeight()) + PADDING_Y * 2)
    FitButton(button)

    button:SetHandler("OnMouseEnter", function(self) Paint(self, true) ShowTipLater(self) end)
    button:SetHandler("OnMouseExit", function(self) Paint(self, false) HideTip(self) end)
    button:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then onClick() end end)
    Paint(button, false)
    buttons[#buttons + 1] = button
    return button
end

-- Locked pieces gathered at the foot of the list, under a heading of their own. A switch rather
-- than an action, so the button stays lit while it is on -- and one switch per window rather
-- than one for all of them: the bank can hold them mixed in while the bag holds them apart,
-- and walking from one to the other is not a reason to press anything.
local function LockedKey(inventoryType)
    return IG.InventoryKey and IG.InventoryKey(inventoryType) or nil
end

local function LockedMode(inventoryType)
    local key = LockedKey(inventoryType)
    return key and IG.LockedMode(key) or IG.LOCKED_DEFAULT_MODE
end

-- Pressed once and the list gives its next answer, round and round. The one that lights the
-- button green is the one that takes things off the screen: the other two both leave every
-- piece you own somewhere in the list, and only that one has to be noticed from across it.
local function CycleLocked(inventoryType)
    local key = LockedKey(inventoryType)
    if not key then return end
    local mode = IG.NextLockedMode(key)
    IG.SetLockedMode(key, mode)
    -- Stepped onto to be looked at: whatever was remembered about LOCKED being closed is
    -- forgotten, so it opens whether or not this is the first time.
    if mode == "grouped" and IG.OpenGroupEverywhere then IG.OpenGroupEverywhere("LOCKED") end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    IG.RefreshLists()
    IG.RepaintToolbar()
end

local function MovedShown(inventoryType)
    local key = LockedKey(inventoryType)
    return key == nil or IG.MovedShown(key)
end

local function ToggleMoved(inventoryType)
    local key = LockedKey(inventoryType)
    if not key then return end
    IG.SetMovedShown(key, not MovedShown(inventoryType))
    PlaySound(SOUNDS.DEFAULT_CLICK)
    IG.RefreshLists()
    IG.RepaintToolbar()
end

-- The list build counts what it left out and says so here. Nothing is rebuilt for it beyond the
-- writing itself, which is the whole of what the number is for -- and it comes in while a list
-- is being made, which is no time to ask for one.
function IG.NoteLockedHidden(listKey, count)
    if not listKey or hiddenCounts[listKey] == count then return end
    hiddenCounts[listKey] = count
    for _, button in ipairs(buttons) do
        if button.igLine then
            button.label:SetText(button.text())
            FitButtons(button)
        end
    end
end

-- Built at load time, so what each one does is wrapped: the functions they call live in files
-- that have not been read yet.
local HEADER_BUTTONS = {
    { label = "Close All", icon = COLLAPSE_ICON, click = function() IG.CollapseVisible() end },
    { label = "Expand All", icon = EXPAND_ICON, click = function() IG.ExpandVisible() end },
}

-- And the switch, on the bottom bar instead, at the money end of it.
--
-- It stood in the row above with the other two and there was no room left: the run after the
-- word NAME ends at the VALUE column, and the third button was standing on that column's own
-- sort arrow. The bar below has a long empty run in the middle of it.
--
-- One copy, not one per window. That bar is shared by the bag, the bank and the guild bank,
-- which is what sent the other buttons to the sort headers in the first place -- they act on
-- the list in front of you, and a shared bar cannot say which that is. This one does not: it
-- turns one switch that every list then reads.
-- Every window that counts its own slots along the bottom gets one, standing for that window
-- alone. Only the ones this client actually has are used.
local BAR_PANELS = {
    { bar = "ZO_PlayerInventoryInfoBar", inventory = INVENTORY_BACKPACK },
    { bar = "ZO_PlayerBankInfoBar", inventory = INVENTORY_BANK },
    { bar = "ZO_GuildBankInfoBar", inventory = INVENTORY_GUILD_BANK },
    { bar = "ZO_HouseBankInfoBar", inventory = INVENTORY_HOUSE_BANK },
    -- The two smithing benches count their slots along the foot as well: $(parent)InfoBar of
    -- ZO_CraftingInventoryTemplate (craftinginventory.xml), connected as a standard bar in
    -- sharedcraftinginventory.lua. The pair and the box used to stand in the row above the sort
    -- header instead, on top of the Include Banked box and the bench's search box.
    { bar = "ZO_SmithingTopLevelDeconstructionPanelInventoryInfoBar",
      inventoryName = "CRAFT_INVENTORY_TYPE" },
    { bar = "ZO_SmithingTopLevelImprovementPanelInventoryInfoBar",
      inventoryName = "IMPROVE_INVENTORY_TYPE" },
}
-- The two bench types are numbers InventoryGrouping.lua hands out, and that file loads after
-- this one: read here, at the top of the file, they are still nil, and a nil inventory is a nil
-- table key further down. So the benches name theirs and it is looked up when the bars are built.

-- A crafting bench has no bottom bar: there the pair is given the bench's own row to stand in
-- (panel.parent) and stands on one line beside the box of marks (panel.anchorTo), short-worded.
local function AddBarSwitch(panel)
    if panel.inventory == nil then return end
    local bench = panel.parent ~= nil
    local bar = bench and panel.parent or _G[panel.bar]
    if not bar then return end
    local listKey = LockedKey(panel.inventory)

    local locked = CreateButton(bar, LOCKED_ICON, LOCKED_BUTTON_TEXT,
        function() CycleLocked(panel.inventory) end)
    locked.igLockedKey = listKey
    -- The lock on the plate says which of the three answers is in force as well as the writing
    -- beside it does, and it is the same width whichever of the three it is wearing.
    locked.iconFor = function() return LOCKED_MODE_ICONS[LockedMode(panel.inventory)] end
    locked.text = function()
        local mode = LockedMode(panel.inventory)
        -- One word or two, which is the bar's answer rather than this line's: a bar the game
        -- has filled leaves a narrower run than the bag's own does.
        local name = locked.igTight and LOCKED_SHORT_TEXT or LOCKED_BUTTON_TEXT
        if mode == "hidden" then
            -- The number is what is missing from the list, and nothing else on screen says
            -- those pieces are there at all. Nothing locked is not a nought in brackets: there
            -- is then nothing being kept from you and no number to report.
            local count = hiddenCounts[locked.igLockedKey] or 0
            local answer = count > 0 and string.format("%s (%d)", LOCKED_ANSWERS.hidden, count)
                or LOCKED_ANSWERS.hidden
            return LineText(name, answer, WarnColor())
        elseif mode == "grouped" then
            return LineText(name, LOCKED_ANSWERS.grouped, IG.DEFAULT_ICON_COLOR)
        end
        return LineText(name, LOCKED_ANSWERS.asis, CalmColor())
    end

    -- Straight after the slot counter, on its line. Hung off the counter rather than off the
    -- money: the bar carries a second currency as well, which is not always where the gold is,
    -- and the switch came out under it. Anchoring a side to a side is also what lines the two
    -- up: the counter's right edge and the switch's left edge are both at their own middles.
    --
    locked.igTip = function()
        local mode = LockedMode(panel.inventory)
        TipHead("Locked Items")
        TipMode("Shown: locked pieces stay where they belong", mode == "asis")
        TipMode("Separate Group: they gather under LOCKED", mode == "grouped")
        TipMode("Hidden: they are kept out of the list", mode == "hidden")
    end

    -- Lifted by half the pair to begin with, so that the two lines straddle the counter's line
    -- instead of the first standing on it and the second hanging off the bottom of the bar.
    -- Where they end up is SettleLines's answer, which needs a drawn bar to give it; what is
    -- kept here is the anchor it re-hangs them by, since it cannot ask a control what it is
    -- anchored to.
    if bench then
        locked.igTight = true
        locked:SetAnchor(LEFT, panel.anchorTo, RIGHT, BUTTON_GAP, 0)
    else
        local freeSlots = bar:GetNamedChild("FreeSlots")
        locked.igAnchorTo = freeSlots or bar
        locked.igAnchorPoint = freeSlots and RIGHT or LEFT
        -- And the counter's own left edge, which is what the box of marks starts at: the box stands
        -- under the words that count the slots, so the two begin on one line down the bar.
        locked.igBoxAnchor = freeSlots or bar
        locked.igDropY = -zo_round((locked:GetHeight() + LINE_DROP) / 2)
        locked.igGapX = BAR_SLOTS_GAP
        locked:SetAnchor(LEFT, locked.igAnchorTo, locked.igAnchorPoint, locked.igGapX, locked.igDropY)
    end

    -- The second line, directly under the first. Left edge to left edge, which is the whole of
    -- what makes the pair read as a table: the two buttons start together and, because they are
    -- given one width between them below, the two answers start together as well.
    local moved = CreateButton(bar, MOVED_SHOWN_ICON, MOVED_BUTTON_TEXT,
        function() ToggleMoved(panel.inventory) end)
    moved.iconFor = function()
        return MovedShown(panel.inventory) and MOVED_SHOWN_ICON or MOVED_HIDDEN_ICON
    end
    moved.text = function()
        -- Shortened with its neighbour and never on its own: the pair is a table of two rows
        -- and a table that words its two subjects differently is not one.
        local name = moved.igTight and MOVED_SHORT_TEXT or MOVED_BUTTON_TEXT
        if MovedShown(panel.inventory) then
            return LineText(name, LOCKED_ANSWERS.asis, CalmColor())
        end
        return LineText(name, LOCKED_ANSWERS.hidden, WarnColor())
    end
    moved.igTip = function()
        local shown = MovedShown(panel.inventory)
        TipHead("Moved Items")
        TipMode("Shown: what you sent away is still drawn, stood down", shown)
        TipMode("Hidden: those copies are taken out of the list", not shown)
    end
    if bench then
        moved.igTight = true
        moved:SetAnchor(LEFT, locked, RIGHT, BUTTON_GAP, 0)
    else
        moved:SetAnchor(TOPLEFT, locked, BOTTOMLEFT, 0, LINE_DROP)
    end

    -- The pair, told about each other: one width between them whatever either of them is
    -- saying, and the first of the two is the one that answers for where both of them stand.
    locked.igTwin, moved.igTwin = moved, locked
    locked.igLine, moved.igLine = true, true
    -- The bar's own settling pass is for a bar; a bench pair stays where it was hung.
    locked.igFirstLine = not bench
    -- Which list this bar speaks for, for the passes that have only the line to go on and have
    -- to ask what layout that list is drawn in.
    locked.igInventory = panel.inventory
    moved.igInventory = panel.inventory
    if not bench then barLines[panel.inventory] = locked end
    Paint(locked, false)
    Paint(moved, false)
    return locked
end

-- The box the four marks stand in, one for each window this addon groups: it is where that
-- window is told what to do -- off and on again, the settings page, the next ready-made look,
-- and what the keys and the right mouse button are for.
--
-- The box lives on the bottom bar and hangs off none of the rows named here, except on a
-- window that has no bottom bar, where it keeps the row it always had: tabs is the row of
-- filter icons and window is the window itself, both of which are only fallen back on as the
-- thing the box is built in.
local PANELS = {
    { search = "ZO_PlayerInventorySearchBox", sort = "ZO_PlayerInventorySortBy",
      tabs = "ZO_PlayerInventoryTabs", window = "ZO_PlayerInventory",
      inventory = INVENTORY_BACKPACK },
    -- The deconstruction bench. No filter row and no search box of the shape the bag has, so it
    -- takes the last place there is: just above its own sort header.
    { sort = "ZO_SmithingTopLevelDeconstructionPanelInventorySortBy",
      inventoryName = "CRAFT_INVENTORY_TYPE", noSortCover = true, benchSwitch = true },
    -- The improvement bench, the same way, with answers of its own. Its inventory is
    -- $(parent)Inventory of ZO_SmithingTopLevelImprovementPanel (smithing_keyboard.xml,
    -- smithingimprovement_keyboard.xml) and SortBy comes from ZO_CraftingInventoryTemplate.
    { sort = "ZO_SmithingTopLevelImprovementPanelInventorySortBy",
      inventoryName = "IMPROVE_INVENTORY_TYPE", noSortCover = true, benchSwitch = true },
    { search = "ZO_PlayerBankSearchBox", sort = "ZO_PlayerBankSortBy",
      tabs = "ZO_PlayerBankTabs", window = "ZO_PlayerBank", inventory = INVENTORY_BANK },
    { search = "ZO_GuildBankSearchBox", sort = "ZO_GuildBankSortBy",
      tabs = "ZO_GuildBankTabs", window = "ZO_GuildBank", inventory = INVENTORY_GUILD_BANK },
    { search = "ZO_HouseBankSearchBox", sort = "ZO_HouseBankSortBy",
      tabs = "ZO_HouseBankTabs", window = "ZO_HouseBank", inventory = INVENTORY_HOUSE_BANK },
}


local SWITCH_RISE = 6   -- above the sort header, for a window with nothing else to hang off

-- The box the marks stand in. Nothing here takes the mouse: the box is a frame around them
-- and the marks inside it are what answer.
local function CreateBox(parent)
    local box = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    box.igOurs = true   -- stepped over by the pass that measures what the game wrote on a bar
    box:SetDimensions(SWITCH_WIDTH, SWITCH_HEIGHT)
    box.igIcons = {}
    -- Over everything its parent draws, and the marks inside it with it -- a tier carries the
    -- whole of a control, children and all. This is why none of them answered the mouse once:
    -- the game draws its own children above anything added to one of its rows afterwards, and
    -- the marks were under the filter row, which took every press meant for them. It matters
    -- no less on the bottom bar, where the counter and the money are the bar's own children.
    -- The sort button below has wanted the same thing for the same reason.
    box:SetDrawTier(DT_HIGH)
    AddEdges(box)
    -- The outline is all there is of it and it never answers anything, so it is painted once,
    -- in the cream every outline in this addon wears.
    local r, g, b = IG.HexToRGB(IG.DEFAULT_ICON_COLOR)
    for _, edge in ipairs(box.edges) do edge:SetColor(r, g, b, EDGE_ALPHA) end
    return box
end

-- The things this window can be told to do, in the order they are worth reaching for: the page
-- where everything else lives, the next ready-made look, and what the keys and the right mouse
-- button are for. All of it is the game's own art -- our own files come out as white squares.
-- (A list is no longer switched off on its own; the Global Switch is the one way back.)
local PANEL_SETTINGS_ICON = "EsoUI/Art/ChatWindow/chat_options_up.dds"
local PANEL_THEME_ICON = "EsoUI/Art/Dye/dyes_tabicon_costumedye_up.dds"
local PANEL_HELP_ICON = "EsoUI/Art/Miscellaneous/help_icon.dds"

-- The marks are drawn rather than plated: the box round them is the frame, and a frame about
-- each of them again would be four boxes inside a fifth. What they have instead is colour --
-- cream at rest, white under the pointer, and taken back for as long as a press is being held,
-- so the press is felt before it is answered.
local function PaintIcon(icon, hovered, pressed)
    local lit = icon.active ~= nil and icon.active()
    local alpha = pressed and PANEL_ICON_PRESS or (hovered and HOVER_ALPHA or PANEL_ICON_ALPHA)
    local hex = hovered and HOVER_COLOR or (lit and ACTIVE_COLOR or IG.DEFAULT_ICON_COLOR)
    local r, g, b = IG.HexToRGB(hex)
    icon.art:SetColor(r, g, b, alpha)
end

-- A control with its art inside it rather than a bare texture: everything in this addon that
-- answers the mouse is one, and the first of the four has two pieces of art to hold at once.
local function AddPanelIcon(box, texture, onClick, active, tip)
    local icon = WINDOW_MANAGER:CreateControl(nil, box, CT_CONTROL)
    icon:SetMouseEnabled(true)
    icon.active = active
    icon.igTip = tip
    -- The four of them are a control panel and nothing else: there is no crossing them on the
    -- way somewhere, so a tip here is wanted the moment the pointer arrives. The pair on the
    -- bottom bar keeps its second, because that bar is on the way to the money.
    icon.igTipDelay = PANEL_TIP_DELAY
    -- Downwards into the list to begin with, which is right for a box standing at the top of a
    -- window. A box that ends up on the bottom bar is told otherwise once it is hung: there is
    -- nothing below that bar to open into.
    icon.igTipBelow = true

    icon.art = WINDOW_MANAGER:CreateControl(nil, icon, CT_TEXTURE)
    icon.art:SetTexture(texture)
    icon.art:SetAnchor(TOPLEFT, icon, TOPLEFT)
    icon.art:SetAnchor(BOTTOMRIGHT, icon, BOTTOMRIGHT)
    icon.art:SetDrawLayer(DL_CONTROLS)
    icon:SetHandler("OnMouseEnter", function(self) PaintIcon(self, true) ShowTipLater(self) end)
    icon:SetHandler("OnMouseExit", function(self) PaintIcon(self, false) HideTip(self) end)
    icon:SetHandler("OnMouseDown", function(self) PaintIcon(self, true, true) end)
    icon:SetHandler("OnMouseUp", function(self, _, upInside)
        PaintIcon(self, upInside)
        if upInside and onClick then onClick() end
    end)
    PaintIcon(icon, false)
    box.igIcons[#box.igIcons + 1] = icon
    return icon
end

-- As large as the box can hold them: as tall as it is inside its padding, no wider than an even
-- share of the run across it, and what room is over is spread between them rather than left in
-- a lump at one end. The first stands at the padding and the last ends at it.
--
-- All four at one size. The cogwheel was drawn a fifth larger than its neighbours for a while,
-- on the grounds that it is the finest-drawn of them and the one reached for most often; beside
-- three marks that are now as large as the box will take, it only read as a row that could not
-- agree on a size. A control panel of four says more by being four of a kind.
local function LayoutPanelIcons(box)
    local icons = box.igIcons
    local count = #icons
    if count == 0 then return end
    local room = box:GetWidth() - PANEL_PAD_X * 2
    -- Never past the frame: a control over its parent's edge is clipped there and stops taking
    -- the mouse, which is the whole of what these are for. The height inside the padding is
    -- what that comes to, so it is both the size wanted and the size allowed.
    local size = zo_max(PANEL_ICON_MIN,
        zo_min(box:GetHeight() - PANEL_PAD_Y * 2, zo_floor(room / count)))
    local step = count > 1 and (room - size) / (count - 1) or 0
    for index, icon in ipairs(icons) do
        icon:SetDimensions(size, size)
        icon:ClearAnchors()
        icon:SetAnchor(LEFT, box, LEFT, PANEL_PAD_X + zo_round(step * (index - 1)), 0)
    end
end

-- The box of marks on the bottom bar, in the left column, under the words that count the
-- slots. Its left edge is the counter's left edge, so the heading and the box below it begin
-- on one line down the bar, the way the name and the box did while both stood at the top.
--
-- Levelled with the second of the two lines beside it rather than with both of them: the
-- counter is written on the bar's own middle line and a box tall enough to straddle that line
-- would be drawn straight through the words it is supposed to stand under. Top and bottom to
-- the "Moved Items" line, then -- which puts the box clear below the counter and ends it level
-- with the foot of the pair, so the two read as one block rather than as two loose things.
--
-- Nothing here measures the bar for itself. The pair has already been fitted between the rule
-- across the bar and the foot of it, and the box takes its height and its line from the pair,
-- which is what keeps it inside the bar: a control past its parent's edge is clipped there and
-- stops taking the mouse, and the mouse is the whole of what these four marks are for.
function SettleBox(button)
    local twin, box, anchor = button.igTwin, button.igBox, button.igBoxAnchor
    if not (twin and box and anchor) then return end
    local height = twin:GetHeight()
    if height <= 0 or anchor:GetHeight() <= 0 then return end

    -- As wide as the run between the counter's left edge and the pair standing beside it, never
    -- wider than the box was built and never so narrow that the four marks are squeezed out of
    -- it: below that floor they would be drawn over each other rather than shrunk.
    local floor = PANEL_ICON_MIN * #box.igIcons + PANEL_PAD_X * 2
    local width = zo_max(floor,
        zo_min(SWITCH_WIDTH, zo_round(button:GetLeft() - anchor:GetLeft() - BUTTON_GAP)))

    -- One anchor for both directions: a control is allowed two and re-hanging it every pass is
    -- what the pair beside it does. LEFT to LEFT is read at each control's own middle, so what
    -- is given is the distance between those middles.
    local drop = zo_round(twin:GetTop() + height / 2
        - anchor:GetTop() - anchor:GetHeight() / 2)
    if box:GetWidth() == width and box:GetHeight() == height and box.igDrop == drop then return end

    box.igDrop = drop
    box:SetDimensions(width, height)
    box:ClearAnchors()
    box:SetAnchor(LEFT, anchor, LEFT, 0, drop)
    LayoutPanelIcons(box)
end

-- Kept short on purpose: it is the answer to "what else is there", not the manual. What the
-- keys themselves are set to is the player's own business, so it points at where they are set
-- rather than naming keys it cannot promise.
local function HelpTip()
    TipHead("Inventory 2.0")
    TipLine("Right click a row to send that piece, or its whole set, to another category")
    TipLine("Ctrl and left click marks several, and one right click answers for all of them")
    TipLine("E on a category opens it or closes it")
    TipLine("Keys of your own: Controls > Inventory 2.0")
end

local function AddPanelIcons(screen)
    local box = screen.box


    AddPanelIcon(box, PANEL_SETTINGS_ICON, function()
        PlaySound(SOUNDS.DEFAULT_CLICK)
        IG.OpenSettings()
    end, nil, function()
        TipHead("Settings")
        TipLine("Opens this addon's page: colours, what is shown, the groups themselves")
    end)

    AddPanelIcon(box, PANEL_THEME_ICON, function()
        PlaySound(SOUNDS.DEFAULT_CLICK)
        IG.CycleTheme()
    end, nil, function()
        TipHead("Look")
        TipMode(IG.ThemeName(), true)
        TipLine("Press for the next ready-made look")
    end)

    -- Pressed, it says at once what standing on it says after a second: this is the one mark
    -- whose whole answer is the words, and nothing is served by making them wait.
    local help
    help = AddPanelIcon(box, PANEL_HELP_ICON, function() ShowTipNow(help) end, nil, HelpTip)
end

-- The box on a window that has no bottom bar to go down to: the crafting bench counts nothing
-- along its foot, so the box keeps the row it always had, hung off the game's own controls.
-- Cleared and hung again rather than added to: a control is allowed two anchors and both of
-- these are spoken for.
--
-- A box that did go down to the bottom bar is not hung here at all. It belongs to that bar and
-- is settled with the pair of lines already standing on it; hanging it off a row up here as
-- well would be hanging it twice. Nothing about either place is measured, so this is said once
-- when the box is built rather than again after every rebuild.
local function HangBox(screen)
    if screen.igOnBar then return end
    local box = screen.box
    box:ClearAnchors()
    box:SetAnchor(LEFT, screen.sortBy, LEFT, 0, 0, ANCHOR_CONSTRAINS_X)
    box:SetAnchor(screen.boxPoint, screen.boxRef, screen.boxTo, 0, screen.boxY,
        ANCHOR_CONSTRAINS_Y)
end

-- The marks say what they say before the mouse has ever been near them: the toolbar is built
-- while every window is shut, and a switch that is off has to look off the moment it is seen.
function PaintScreen(screen)
    -- Except while the bag is being sold out of. The bottom bar is the game's own and on the
    -- selling layout it is a full one: a fence writes how much of the day's fencing is spent
    -- and what the haggling is worth across the run the box stands in, and the box went out on
    -- top of that writing. So there is no box at all there. Nothing is lost by it -- the four
    -- marks are the bag's own controls and the bag is a keypress away.
    screen.box:SetHidden(SellingLayout(screen.inventory))
    for _, icon in ipairs(screen.box.igIcons) do PaintIcon(icon, false) end
end

local benchWarned = false

local function AddScreen(panel)
    local sortBy = panel.sort and _G[panel.sort]
    if not sortBy then
        -- A bench whose header is not where we looked gets none of its buttons; say so once
        -- rather than leave it looking like the game's own list.
        if panel.benchSwitch and not benchWarned then
            benchWarned = true
            d("|cFF8800Inventory 2.0:|r " .. panel.sort .. " not found; that bench has no buttons.")
        end
        return
    end
    local search = panel.search and _G[panel.search]
    local tabs = panel.tabs and _G[panel.tabs]
    local window = panel.window and _G[panel.window]
    local row = tabs or search or sortBy

    -- The line that counts this window's slots along the bottom, if this window has one. The
    -- box of marks goes down there with it, under the counter -- and is built on that bar,
    -- because a control hung outside its own parent is at the mercy of what that parent does
    -- with its extents, which is what cost the switch this replaces its mouse once already.
    local lines = barLines[panel.inventory]
    local bar = lines and lines:GetParent() or nil
    local screen = {
        box = CreateBox(bar or window or row),
        sortBy = sortBy,
        igOnBar = bar ~= nil,
        inventory = panel.inventory,
    }

    if bar then
        -- Settled with the pair already standing on that bar, by the pass that settles them.
        lines.igBox = screen.box
    elseif search then
        -- No bottom bar of its own -- the crafting bench counts nothing along its foot -- so
        -- the box keeps the place it had, on the row that says what the list is showing.
        screen.boxPoint, screen.boxRef, screen.boxTo, screen.boxY = TOP, search, BOTTOM, SWITCH_DROP
    else
        screen.boxPoint, screen.boxRef, screen.boxTo, screen.boxY = BOTTOM, sortBy, TOP, -SWITCH_RISE
    end

    AddPanelIcons(screen)
    -- Only for a bench whose bottom bar was not found: there the pair falls back to the row
    -- above the sort header, beside the box.
    if panel.benchSwitch and not bar then
        AddBarSwitch({ inventory = panel.inventory, parent = screen.box:GetParent(),
            anchorTo = screen.box })
    end
    -- A box on the bottom bar has nothing under it to open a tip into, so its marks answer
    -- upwards; one still standing at the top of a window opens downwards, into the list.
    for _, icon in ipairs(screen.box.igIcons) do icon.igTipBelow = not screen.igOnBar end
    LayoutPanelIcons(screen.box)
    HangBox(screen)

    screens[#screens + 1] = screen
end

-- The price header does nothing at all while we are grouping the list under it: our sort is
-- the one that runs and the game's never does, so pressing VALUE sorts nothing. Our own sort
-- takes its place -- one button saying what the list is ordered by, stepping to the next way
-- every time it is pressed. Switch the addon off for a list and the two trade places again:
-- the game's header is live then and must be both readable and reachable.
--
-- In its place rather than over it. Lying on top it was still behind: the game draws its own
-- header's writing and arrows above anything put there afterwards, so VALUE read straight
-- through ours, and a lid cut to the header's own box is taller than every other button on the
-- bar. The header is simply put away instead, and ours is the size its neighbours are.
local PRICE_HEADER_NAMES = { "SellPrice", "Price", "Value" }

local function SortText()
    return "Sort: " .. IG.SortLabel()
end

-- A sort header is told from everything else on the bar by the label it carries inside it; the
-- price is the last column, so among those it is the one standing furthest right. Asked by name
-- first, and only measured when this client calls it something we have not met.
local function PriceHeader(sortBy)
    for _, name in ipairs(PRICE_HEADER_NAMES) do
        local header = sortBy:GetNamedChild(name)
        if header then return header end
    end
    local middle = sortBy:GetLeft() + sortBy:GetWidth() / 2
    local found, edge
    for index = 1, sortBy:GetNumChildren() do
        local child = sortBy:GetChild(index)
        local isHeader = child and child.GetNamedChild and child:GetNamedChild("Name") ~= nil
        if isHeader and child:GetLeft() > middle and (not edge or child:GetRight() > edge) then
            found, edge = child, child:GetRight()
        end
    end
    return found
end

local function AddSortButton(panel)
    local sortBy = _G[panel.sort]
    if not sortBy or panel.noSortCover then return end
    local price = PriceHeader(sortBy)
    if not price then return end

    local button = CreateButton(sortBy, SORT_ICON, SortText(), function()
        IG.sv.sortBy = IG.NextSortMethod()
        PlaySound(SOUNDS.DEFAULT_CLICK)
        -- Which rebuilds every list and repaints every copy of this button, wording and all.
        IG.RefreshLists()
        IG.RefreshSettingsPanel()
    end)
    button.text = SortText
    -- Put away for as long as the list under it is ours, and back the moment it is not
    -- (IG.RepaintToolbar). Not for as long as this button stands here: on the selling layout
    -- neither belongs, because we lay those categories out and the game's sort never runs, so
    -- a header left showing there is one more thing that answers nothing when pressed.
    button.covers = price
    button.covered = function() return true end
    button.shown = function()
        -- Not on the selling layout: each of its categories sorts itself its own way and this
        -- does not reach it, and a button that says what the list is doing has to be right.
        return not SellingLayout(panel.inventory)
    end

    -- Over everything the bar draws. A tier rather than a layer: what the game puts on its own
    -- header -- the word and the arrows beside it -- is drawn above whatever is added to that
    -- bar later, and only a tier is above all of it. Belt and braces, since the header is put
    -- away as well; a client that keeps showing it will not show it through this.
    button:SetDrawTier(DT_HIGH)
    -- Where the header stood, at the size the button is: its right edge decides the column,
    -- the middle of it decides the line, and the height is the one every button here has.
    button:SetAnchor(RIGHT, price, RIGHT, 0, 0, ANCHOR_CONSTRAINS_X)
    button:SetAnchor(CENTER, price, CENTER, 0, 0, ANCHOR_CONSTRAINS_Y)
end

-- The sort headers we can reach. Only the ones this client actually has are used.
local SORT_HEADERS = { "ZO_PlayerInventorySortBy", "ZO_PlayerBankSortBy", "ZO_GuildBankSortBy",
    "ZO_HouseBankSortBy", "ZO_SmithingTopLevelDeconstructionPanelInventorySortBy",
    "ZO_SmithingTopLevelImprovementPanelInventorySortBy" }

local built

-- The NAME header is as wide as the column it sorts, so its right edge is halfway across the
-- list and a button hung off it lands on VALUE. What the buttons want is the end of the word,
-- which is the label inside the header measured rather than the box it sits in.
local function AfterTheWord(nameHeader)
    local label = nameHeader:GetNamedChild("Name")
    if not (label and label.GetTextWidth) then return nil end
    return label, zo_max(label:GetTextWidth() or 0, NAME_MIN_WIDTH)
end

-- The game hangs its own sort arrow off the end of that same word, which is the very place the
-- first button was standing: in the bank the triangle beside NAME comes out on top of "Close
-- All". So the row starts after the arrow rather than after the word.
--
-- The arrow is not asked for by name -- every guess at one of these windows' inner names has
-- cost us a turn -- but picked out of the header's own children by what it is: a texture drawn
-- from the game's list sort art. Only its width is taken from it, never its place: nothing on
-- these windows is drawn when the buttons are built, so a measured position comes back as
-- nothing, while a width set in the template is there from the start.
--
-- A header that hands back no arrow at all still gets the room one would have taken, so the
-- buttons clear a triangle we failed to find rather than stand under it.
local SORT_ARROW_WIDTH = 16  -- what the game's own arrow textures are drawn at
local SORT_ARROW_ART = "list_sort"
local function ArrowRoom(nameHeader)
    for index = 1, nameHeader:GetNumChildren() do
        local child = nameHeader:GetChild(index)
        if child and child.GetTextureFileName then
            local art = child:GetTextureFileName()
            if art and zo_strlower(art):find(SORT_ARROW_ART, 1, true) then
                local width = child:GetWidth() or 0
                if width > 0 then return width end
            end
        end
    end
    return SORT_ARROW_WIDTH
end

local function AddHeaderButtons(sortBy)
    local nameHeader = sortBy:GetNamedChild("Name")

    -- Just before the NAME header, in the gap the sort arrows leave.
    local top = CreateButton(sortBy, TO_TOP_ICON, "Top", IG.ScrollVisibleToTop)
    if nameHeader then
        top:SetAnchor(RIGHT, nameHeader, LEFT, -SORT_HEADER_GAP, 0)
    else
        top:SetAnchor(LEFT, sortBy, LEFT, SORT_HEADER_GAP, 0)
    end

    -- And the rest in a row to the right of it, where the header has nothing written.
    local previous
    for _, spec in ipairs(HEADER_BUTTONS) do
        local button = CreateButton(sortBy, spec.icon, spec.label, spec.click, spec.active)
        if previous then
            button:SetAnchor(LEFT, previous, RIGHT, BUTTON_GAP, 0)
        elseif nameHeader then
            -- The word, then the room the game's arrow takes after it, then our own gap.
            local clearance = ArrowRoom(nameHeader) + SORT_HEADER_GAP
            local label, width = AfterTheWord(nameHeader)
            if label then
                button:SetAnchor(LEFT, label, LEFT, width + clearance, 0)
            else
                button:SetAnchor(LEFT, nameHeader, LEFT, NAME_MIN_WIDTH + clearance, 0)
            end
        else
            button:SetAnchor(LEFT, top, RIGHT, BUTTON_GAP, 0)
        end
        previous = button
    end
end

local function MarkFont(size)
    return string.format("%s|%d|%s", MARK_FACE, size, MARK_STYLE)
end

-- What a ruled line looks like, since it is found by looking rather than by being asked for
-- by name. Asking by name is what the first attempt at this did and the name never answered:
-- the window was left with the name standing where it was built, which on screen is a change
-- that was never made. Every guess at one of these windows' inner names has cost us a turn now.
--
-- So: thin, long, and the last such thing above the row it is ruled for.
local MARK_RULE_DEPTH = 3          -- how far into the window's own children to look
local MARK_RULE_THICK = 8          -- taller than this and it is not a line
local MARK_RULE_SHARE = 0.4        -- of the row below it, so a short tick is not mistaken for it

-- The line ruled across the window above its sort header -- the one that fades away towards
-- the left, with "Top" standing under it. Swept for rather than named, and told from everything
-- else by its shape and by where it falls: inside the window, no taller than a rule, as long as
-- a good part of the row below it, and of all of those the one standing lowest -- which is the
-- one directly above that row.
--
-- Nothing here is measured until the window has been drawn, so an undrawn window hands back
-- nothing and the caller is left to say what happens then.
local function RuleAbove(window, row)
    if not (window and row) or row:GetHeight() <= 0 then return nil end
    local ceiling, least = row:GetTop(), row:GetWidth() * MARK_RULE_SHARE
    local found
    local function Sweep(parent, depth)
        for index = 1, parent:GetNumChildren() do
            local child = parent:GetChild(index)
            if child and not child:IsHidden() then
                local height = child:GetHeight()
                if height > 0 and height <= MARK_RULE_THICK and child:GetWidth() >= least
                    and child:GetBottom() <= ceiling + 1
                    and (not found or child:GetBottom() > found:GetBottom()) then
                    found = child
                elseif depth > 1 and child:GetNumChildren() > 0 then
                    Sweep(child, depth - 1)
                end
            end
        end
    end
    Sweep(window, MARK_RULE_DEPTH)
    return found
end

-- The name, written the ordinary way across a box of its own and then turned a quarter turn so
-- that the box stands on end. Turning is the whole of it: a label answers SetTransformRotationZ
-- the same way any other control does (CrutchAlerts turns the writing on its boss bar with it),
-- and a turn given to a control carries its children round with it, which is why the word and
-- the number are laid out side by side in here and never told about the turn themselves.
--
-- Letter by letter down a column was the other way open to us, and it was the worse one: nine
-- labels to keep level with each other, letters that keep standing upright while the word lies
-- on its side, and no way to set the number after the word without measuring every one of them.
--
-- It is built on the window itself and hangs off the window's left edge, out in the strip the
-- game leaves empty beside it. On the window rather than on GuiRoot so that it is shut away
-- with the window and comes back with it, which is something a child is given for nothing.
-- Standing outside its parent's box costs it the mouse -- but this is a name and takes no
-- mouse, so the one price of that place is one we are not paying.
local function CreateWordmark(window)
    local mark = WINDOW_MANAGER:CreateControl(nil, window, CT_CONTROL)
    mark:SetMouseEnabled(false)
    local r, g, b = IG.HexToRGB(IG.DEFAULT_ICON_COLOR)

    mark.word = WINDOW_MANAGER:CreateControl(nil, mark, CT_LABEL)
    mark.word:SetFont(MarkFont(MARK_WORD_SIZE))
    mark.word:SetText(MARK_WORD)
    mark.word:SetColor(r, g, b, 1)
    mark.word:SetAnchor(LEFT, mark, LEFT)
    mark.word:SetDrawLayer(DL_CONTROLS)

    -- Bottom to bottom rather than middle to middle: two sizes on one line are read off the
    -- ground they stand on, not off their own centres.
    mark.tail = WINDOW_MANAGER:CreateControl(nil, mark, CT_LABEL)
    mark.tail:SetFont(MarkFont(zo_round(MARK_WORD_SIZE * MARK_TAIL_SHARE)))
    mark.tail:SetText(MARK_TAIL)
    mark.tail:SetColor(r, g, b, 1)
    mark.tail:SetAnchor(BOTTOMLEFT, mark.word, BOTTOMRIGHT, MARK_GAP, 0)
    mark.tail:SetDrawLayer(DL_CONTROLS)

    mark:SetAlpha(MARK_ALPHA)
    -- A quarter turn, the way that leaves the word reading from the top of the window down to
    -- the foot of it. The turn is taken about the middle of the box, so where the box is hung
    -- is where the middle of the standing column ends up: one anchor, its own middle to the
    -- middle of the window's left edge and then out into the strip beside it. Size is given
    -- rather than anchored -- a control is allowed two anchors and this way it spends one.
    mark:SetTransformRotationZ(-math.pi / 2)
    mark:SetAnchor(CENTER, window, LEFT, -MARK_INSET, 0)
    mark.igWindow = window
    mark.igRow = _G["ZO_PlayerInventorySortBy"]
    return mark
end

-- The wordmark's half of the bag-open sparkle: amount is 0 at rest and 1 at the flash's peak.
-- Driven from Drawer.lua so the two sparkle on the same clock.
function IG.FlashWordmark(amount)
    if not wordmark then return end
    wordmark:SetAlpha(MARK_ALPHA + (MARK_FLASH_ALPHA - MARK_ALPHA) * (amount or 0))
end

-- The size of the box, and then where its middle goes. Two questions rather than one because
-- the second is asked in the answer to the first: turned on its side, the width of the writing
-- is how far down the window the name reaches, so nothing can be placed until it is measured.
--
-- Measured every pass rather than once. A font asked for the width of a word before anything
-- has been drawn answers nothing, and the line the name starts from is the window's own and
-- says nothing either until that window has been laid out. Once both answer, both answers stop
-- changing and the pass comes back having moved nothing.
-- Returns true once the column's head has been measured off an open, laid-out window. Until
-- then the name is kept hidden and igHead is nil, so the strip waits too (Drawer.lua). With
-- force, the window's top edge stands in for a rule that never answered, and it is shown.
function SettleWordmark(force)
    if not wordmark then return false end
    local window = wordmark.igWindow
    -- A shut window's rectangle means nothing; the last good answer stands until it opens.
    if not window or window:IsHidden() then return wordmark.igHead ~= nil end
    local function Pending()
        wordmark.igHead = nil
        wordmark:SetHidden(true)
        return false
    end
    local width = wordmark.word:GetTextWidth() or 0
    if width <= 0 then return Pending() end
    local length = zo_round(width + MARK_GAP + (wordmark.tail:GetTextWidth() or 0))
    local thickness = zo_round(wordmark.word:GetTextHeight() or 0)
    if thickness <= 0 then return Pending() end
    if wordmark:GetWidth() ~= length or wordmark:GetHeight() ~= thickness then
        wordmark:SetDimensions(length, thickness)
    end

    -- The head of the column stands on the line ruled above the sort header, where that line
    -- has faded away to nothing at the left of the window: the name begins where the rule
    -- begins and runs down from it.
    --
    -- And if that line cannot be found, the name goes to the very top of the window instead of
    -- staying where it was built. Falling back to the place it already stood is a failure that
    -- looks exactly like success, which is how the first try at this went out: the line was
    -- never found, nothing moved, and there was no telling the two apart from the screen. A
    -- name starting level with the window's top edge says at a glance which of the two happened.
    if window:GetHeight() <= 0 then return Pending() end
    local rule = RuleAbove(window, wordmark.igRow)

    -- Only a rule that lies inside the window counts; one not laid out yet reads 0 or garbage.
    local ruleBottom = rule and rule:GetBottom() or 0
    local head
    if ruleBottom > window:GetTop() and ruleBottom < window:GetBottom() then
        head = ruleBottom
    elseif force then
        head = window:GetTop()
    else
        return Pending()
    end
    -- Where the column begins, before anything is taken off it: the drawers' strip starts from
    -- this very line, and measuring it twice in two files is two answers waiting to disagree.
    wordmark.igHead = head
    -- The strip of drawer marks stands in this column and begins where the name would have, so
    -- the name gives up the head of the column and starts under the last of them. One column
    -- with two things in it, in the order they are worth reaching for: the marks answer the
    -- mouse and the name answers nothing.
    local strip = IG.DrawerStripLength and IG.DrawerStripLength() or 0
    head = head + strip

    -- Never past the foot of the window, and never back up into the marks. The clamp used to
    -- fall back to the window's own top edge, which on a short bag pulled the name up through
    -- the strip it had just stepped aside for and wrote it across the four marks. Hanging a
    -- little below the window is the lesser of the two: the name answers no mouse and reads
    -- fine against the slot count, while a name across the marks makes both unreadable.
    local floor = window:GetBottom()
    if head + length > floor then head = zo_max(head, floor - length) end

    -- One anchor for both directions, as it was built with. The turn is taken about the middle
    -- of the box, so what is given is where that middle goes: half the length below the head of
    -- the column, measured off the middle of the window's left edge, which is what LEFT means.
    local middle = (window:GetTop() + window:GetBottom()) / 2
    local drop = zo_round(head + length / 2 - middle)
    if wordmark.igDrop ~= drop then
        wordmark.igDrop = drop
        wordmark:ClearAnchors()
        wordmark:SetAnchor(CENTER, window, LEFT, -MARK_INSET, drop)
    end
    wordmark:SetHidden(false)
    return true
end

-- Where the column beside the bag begins, and how far out from the window's edge its middle
-- runs. Both are the name's own measurements, handed over so that the strip of drawer marks
-- stands in one column with it rather than in a column of its own that happens to look close.
-- Nothing is answered until the window has been drawn once, which is what nil says here.
function IG.WordmarkHead()
    return wordmark and wordmark.igHead
end

function IG.WordmarkInset()
    return MARK_INSET
end

-- A small X at the far right inside a search box, shown while the box holds text; a click empties
-- the box. One helper for every box this addon touches (the game's bag, bank, guild bank, house
-- chest, craft bag and store boxes, and our own bench box in Craft.lua) so they all look alike.
--
-- Where it stands: the box's own right edge is the first anchor of the edit control on its
-- right side (the game's edit templates fill the backdrop with a small inset), so the X takes
-- that same reference and that same inset, and the edit control's right edge is pulled in to
-- stop short of the X. Typed text never runs under it, and the X never leaves the box.
local CLEAR_WIDTH = 16
local CLEAR_GAP = 2
local CLEAR_MIN_PAD = 4
local CLEAR_COLOR = "C8C8C8"
local CLEAR_HOVER_COLOR = "FFFFFF"
local CLEAR_DEFAULT_HEIGHT = 24
local clearCount = 0 -- CreateControl answers nil for a name used twice

local RIGHT_POINTS = { [TOPRIGHT] = true, [RIGHT] = true, [BOTTOMRIGHT] = true }
local LEFT_POINTS = { [TOPLEFT] = true, [LEFT] = true, [BOTTOMLEFT] = true }

-- How far across the control's width an anchor's point sits: 0 on the left edge, 1 on the
-- right edge, half way for the middle points (TOP, CENTER, BOTTOM).
local function SideShare(point)
    if LEFT_POINTS[point] then return 0 end
    if RIGHT_POINTS[point] then return 1 end
    return 0.5
end

-- Whether an anchor (as read below) holds the control sideways. One made with
-- ANCHOR_CONSTRAINS_Y only places it up and down, and its x counts for nothing.
local function HoldsSideways(anchor)
    return anchor[6] == nil or anchor[6] ~= ANCHOR_CONSTRAINS_Y
end

-- The edit control inside whatever was handed over: the control itself, or the first edit child
-- of a backdrop.
local function FindEditBox(control)
    if not control then return nil end
    if control.GetText and control.SetText and control.TakeFocus then return control end
    if control.GetNumChildren then
        for i = 1, control:GetNumChildren() do
            local child = control:GetChild(i)
            if child and child.GetType and child:GetType() == CT_EDITBOX then return child end
        end
    end
    return nil
end

function IG.AttachSearchClear(control)
    local edit = FindEditBox(control)
    if not edit or edit.igClearButton then return end
    local host = edit:GetParent()
    if not host then return end

    -- Read the edit control's anchors as they are now (two at most), and note the inset on its
    -- right side: that is the box's real inner edge.
    local anchors = {}
    for i = 0, edit:GetNumAnchors() - 1 do
        local valid, point, relativeTo, relativePoint, x, y, constrains = edit:GetAnchor(i)
        if valid then
            anchors[#anchors + 1] = { point, relativeTo, relativePoint, x, y, constrains }
        end
    end
    local target, pad = host, CLEAR_MIN_PAD
    for _, a in ipairs(anchors) do
        if RIGHT_POINTS[a[1]] and RIGHT_POINTS[a[3]] and a[2] and HoldsSideways(a) then
            target = a[2]
            pad = math.max(CLEAR_MIN_PAD, -a[4])
            break
        end
    end

    clearCount = clearCount + 1
    local clear = WINDOW_MANAGER:CreateControl("InventoryGroupingSearchClear" .. clearCount,
        host, CT_LABEL)
    if not clear then return end
    edit.igClearButton = clear
    local height = edit:GetHeight()
    if not height or height < 8 then height = CLEAR_DEFAULT_HEIGHT end
    clear:SetDimensions(CLEAR_WIDTH, height)
    clear:SetFont("ZoFontGameBold")
    clear:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    clear:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    clear:SetText("|c" .. CLEAR_COLOR .. "X|r")
    clear:SetMouseEnabled(true)
    clear:SetDrawTier(edit:GetDrawTier())
    clear:SetDrawLevel(edit:GetDrawLevel() + 2)
    -- One anchor: the far right of the box, one inset in from its inner edge.
    clear:SetAnchor(RIGHT, target, RIGHT, -pad, 0)

    -- Pull the edit control's right edge in so the text stops before the X. Only the right edge
    -- moves: in every layout the left edge, and so the box as a whole, stays where it was.
    --   How far: with a right anchor, until that edge stands one gap short of the X (an anchor
    --     that sat less than the inset in from the box's inner edge comes in by the rest too);
    --     with none, by the X, the gap and the inset.
    --   How: every anchor goes back with its x moved by the part of that pull its point carries
    --     (SideShare): none for a left point, half for a middle point, all of it for a right
    --     point. An anchor that only places the control up and down goes back as it was.
    --   Width: when the anchors that hold the control sideways pin two different points (the
    --     game's edit templates: a left and a right), the width follows from them and is left
    --     alone. Otherwise the width is the control's own (one anchor, or two on the same
    --     point), so it gives up the pull as well, which is what keeps the left edge in place
    --     after a middle or right point has moved.
    if #anchors > 0 then
        local reserve = CLEAR_WIDTH + CLEAR_GAP
        local width = edit:GetWidth()
        local pull, share
        local ownWidth = true
        for _, a in ipairs(anchors) do
            if HoldsSideways(a) then
                if RIGHT_POINTS[a[1]] then
                    pull = math.max(pull or 0, reserve + math.max(0, a[4] + pad))
                end
                local s = SideShare(a[1])
                if share == nil then
                    share = s
                elseif s ~= share then
                    ownWidth = false
                end
            end
        end
        pull = pull or (reserve + pad)
        edit:ClearAnchors()
        for _, a in ipairs(anchors) do
            local x = a[4]
            if HoldsSideways(a) then x = x - pull * SideShare(a[1]) end
            edit:SetAnchor(a[1], a[2], a[3], x, a[5], a[6])
        end
        if ownWidth then
            edit:SetWidth(math.max(1, width - pull))
        end
    end

    local function Refresh()
        clear:SetHidden((edit:GetText() or "") == "")
    end
    -- Chained after whatever the box already answers to (the game's own search, a bench's
    -- filter), never in place of it.
    local textEvent = false
    ZO_PostHookHandler(edit, "OnTextChanged", function()
        textEvent = true
        Refresh()
    end)

    clear:SetHandler("OnMouseEnter", function(self)
        self:SetText("|c" .. CLEAR_HOVER_COLOR .. "X|r")
    end)
    clear:SetHandler("OnMouseExit", function(self)
        self:SetText("|c" .. CLEAR_COLOR .. "X|r")
    end)
    clear:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        textEvent = false
        edit:SetText("")
        -- SetText is expected to raise OnTextChanged, which is what refreshes the panel's filter
        -- as when the player deletes the text. If it did not, raise it by hand.
        if not textEvent then
            local handler = edit:GetHandler("OnTextChanged")
            if handler then handler(edit) end
        end
        Refresh()
    end)
    Refresh()
end

-- The game's own boxes that sit on the inventory and selling screens. Each is looked up by what
-- the game keeps on its inventory object (the same field AwesomeGuildStore reads for the sell
-- tab); the store box is only probed, so a version without one is simply skipped.
function IG.AttachGameSearchClears()
    local types = { INVENTORY_BACKPACK, INVENTORY_BANK, INVENTORY_GUILD_BANK,
        INVENTORY_HOUSE_BANK, INVENTORY_CRAFT_BAG }
    for _, inventoryType in ipairs(types) do
        local inventory = PLAYER_INVENTORY and PLAYER_INVENTORY.inventories
            and PLAYER_INVENTORY.inventories[inventoryType]
        IG.AttachSearchClear(inventory and inventory.searchBox)
    end
    IG.AttachSearchClear(_G.STORE_WINDOW and _G.STORE_WINDOW.searchBox)
    IG.AttachSearchClear(_G["ZO_StoreWindowSearchBox"])
end

function IG.CreateToolbar()
    if built then return end
    built = true

    -- The benches name their inventory rather than hold it (see BAR_PANELS); both tables are
    -- given the number here, once InventoryGrouping.lua has handed it out.
    for _, list in ipairs({ BAR_PANELS, PANELS }) do
        for _, panel in ipairs(list) do
            if panel.inventoryName then panel.inventory = IG[panel.inventoryName] end
        end
    end
    for _, panel in ipairs(BAR_PANELS) do AddBarSwitch(panel) end
    for _, name in ipairs(SORT_HEADERS) do
        local sortBy = _G[name]
        if sortBy then AddHeaderButtons(sortBy) end
    end
    -- After the bars: the box on each window is hung off the pair of lines standing on its own
    -- bottom bar, and that pair is built by the pass above.
    for _, panel in ipairs(PANELS) do
        AddScreen(panel)
        AddSortButton(panel)
    end
    -- The name goes on the bag alone. It is one word said once: on the bank and the guild bank
    -- the strip beside the window is where the other half of the screen begins, and a bench has
    -- its own craft laid out beside it -- a name standing there would be a name in the way. The
    -- bag is the window this addon is for, and saying it four times says it no better.
    local bag = _G["ZO_PlayerInventory"]
    if bag then wordmark = CreateWordmark(bag) end
    -- And the drawers that open beside that same window, whose strip shares the name's column.
    -- Built after it, because where the strip starts is a measurement the name owns.
    if bag and IG.CreateDrawers then IG.CreateDrawers(bag) end
    IG.RepaintToolbar()
end
