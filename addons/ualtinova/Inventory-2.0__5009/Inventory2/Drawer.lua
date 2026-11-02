InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- Drawers: the panels that open in the empty strip to the left of the bag.
--
-- A drawer is not a category and has nothing to do with the list. It is a page of its own --
-- what your money did, what you are carrying that is not an item, what you are looking for --
-- that opens beside the bag without moving it a pixel. The bag is where the player's eye
-- already is and the ground to the left of it is empty on every screen this game runs on.
--
-- Four of them, and adding a fifth is one row of the table below: a key, a name, a mark and
-- the function that fills the body -- and the body may be left out, which is what a drawer with
-- nothing written for it yet does. The row was the whole of adding the fourth: the strip grew a
-- mark, the name beside the bag dropped by one, and nothing was told about either, because both
-- are measured from how many rows there are. Everything else here -- the strip of marks down the side,
-- the head with the close cross on it, what Escape does, which one comes back when
-- the bag is opened again -- is written once for all of them and knows nothing about any one.
--
-- Where it all lives is worth saying plainly. Nothing here is a child of the bag window, though
-- everything here is hung off it: a control standing outside its own parent's rectangle is
-- clipped there and stops taking the mouse (HANDOFF, the four things learned the hard way), and
-- every one of these controls stands outside the bag on purpose. So they are GuiRoot's, anchored
-- to the window, and shown and hidden with it by hand.

local DRAWER_TIP_DELAY = 120

---------------------------------------------------------------------------
-- The drawers there are
---------------------------------------------------------------------------

-- build(body) is called once, the first time a drawer is opened, and is handed the control its
-- contents go in. refresh(body), if it is given, is called every time the drawer is shown again
-- and whenever what it draws has changed underneath it.
--
-- The functions are looked up when they are called rather than written in here, because the
-- files that hold them are read after this one.
--
-- Every mark is one of the game's own art paths and not one of ours, and each one was taken
-- from an addon already installed that draws it: the guild history ledger from AdvancedFilters
-- and AwesomeGuildStore, the bank's own gold tab from Inventory Insight, the map's filter
-- funnel from SetTracker and BeamMeUp, the smithing armour set from SetTracker. A path that is
-- not there does not complain -- it draws nothing at all, and a mark that draws nothing is a
-- box that reads as empty rather than as broken.
--
-- All four are the game's flat tab signs, drawn the same weight at the same scale inside their
-- own textures, which is what makes four boxes of one size read as four marks of one size.
--
-- color is the drawer's accent: the outline of its lit box, the plate behind it when it is open,
-- the frame round its name, and the line standing between its box and its open panel. Purple
-- for the sets, gold for the money, coral for AUTOMATE, pink for MODULES. Top to bottom in the
-- strip in the order written here.
IG.DRAWERS = {
    {
        key = "equippedSets",
        label = "EQUIPPED SETS",
        color = "B47AEA",
        -- The smithing tab's own armour-set mark, which the addon already draws elsewhere and
        -- SetTracker draws too: the one mark in the game that means a set rather than a piece.
        icon = "EsoUI/Art/Crafting/smithing_tabIcon_armorset_up.dds",
        -- The page for this one is written (EquippedDrawer.lua) and this row never named it, so
        -- the drawer opened on "Coming soon" every time. Neither half was broken; they were
        -- simply never joined.
        build = function(body) return IG.BuildEquippedDrawer(body) end,
        refresh = function(body) return IG.RefreshEquippedDrawer(body) end,
    },
    {
        key = "gold",
        label = "GOLD TRACKER",
        color = "FFD84A",
        -- The bank's own gold tab. The coin from the currency art stood here first and was the
        -- one thing in the strip that was a rendered object rather than a drawn sign -- filled,
        -- lit, painted out to the edges of its own texture -- so it read as bigger than its
        -- neighbours although every box is the same box. This is the money sign in the same
        -- hand as the rest of them, which is what the strip is short of, not the meaning.
        icon = "EsoUI/Art/Bank/bank_tabIcon_gold_up.dds",
        build = function(body) return IG.BuildGoldDrawer(body) end,
        refresh = function(body) return IG.RefreshGoldDrawer(body) end,
    },
    {
        key = "automate",
        label = "AUTOMATE",
        -- Coral: apart from the gold and purple beside it, and from SELL's orange.
        color = "FF6F61",
        -- The inventory's own junk tab mark, a flat tab sign like the rest; PersonalAssistant
        -- draws it for its own junk rules (PersonalAssistant/Utilities/XML/RulesWindow.lua:180).
        icon = "EsoUI/Art/Inventory/inventory_tabIcon_junk_up.dds",
        build = function(body) return IG.BuildAutomateDrawer(body) end,
        refresh = function(body) return IG.RefreshAutomateDrawer(body) end,
    },
    {
        key = "modules",
        label = "MODULES",
        -- Pink: apart from the three beside it and from every module colour it lists.
        color = "FF7AD9",
        -- The main menu's skills mark, a flat sign of the same family; the addon already draws
        -- it for CLASS SETS and SKILL LINE SCROLLS (Colors.lua).
        icon = "EsoUI/Art/MainMenu/menuBar_skills_up.dds",
        build = function(body) return IG.BuildModulesDrawer(body) end,
        refresh = function(body) return IG.RefreshAutomateDrawer(body) end,
    },
}

local DRAWER_BY_KEY = {}
for _, drawer in ipairs(IG.DRAWERS) do DRAWER_BY_KEY[drawer.key] = drawer end

---------------------------------------------------------------------------
-- How it is drawn
---------------------------------------------------------------------------

-- The marks down the side. Each one is a small box with a thin outline, which is the box the
-- control panel on the bottom bar is drawn in said again -- the addon has one way of drawing a
-- mark you can press and this is it.
-- The box and the air inside it. Both moved together to get a bigger mark: the mark is what is
-- left of the box once the padding is taken off all four sides, so it grew by the box growing
-- and by the padding shrinking, 18 across to 24. Nothing else was touched to do it -- how far
-- down the column the strip reaches, where it hangs off the window, and how far left of it the
-- panel stops are all worked out from these two numbers rather than written down again.
-- Air on either side of the box, inside the column it stands in. One number spent twice: the
-- gap between the box and the list to the right of it is the gap between the box and the ground
-- to the left of it, which is what makes the boxes read as standing in a column of their own
-- rather than leaning on the list. The box was flush against the list before this and looked it.
local STRIP_EDGE_PAD = 8
local STRIP_BOX = 28          -- the box itself, across and down
local STRIP_PAD = 4           -- between the outline and the mark inside it
local STRIP_GAP = 6           -- between one box and the next
local STRIP_TAIL = 10         -- between the last box and whatever stands under the strip
-- Between a box and the frame round the name that appears beside it. It has to clear the
-- padding below, or the frame is drawn into the gap and the name leans on the box.
local STRIP_NAME_GAP = 16
-- Between the writing and the frame drawn round it. Wider across than down, because the border
-- is drawn on all four sides at one weight and a line of writing is a wide, short thing: equal
-- padding round it leaves the ends looking pinched.
local STRIP_NAME_PAD_X = 10
local STRIP_NAME_PAD_Y = 5
local STRIP_NAME_FONT = "$(MEDIUM_FONT)|16|soft-shadow-thin"
-- How far the boxes stand out from the bag's own left edge. Centred on the name's column they
-- were hung half a box further out than the window reaches, which put them clear of the bag's
-- border with nothing behind them -- loose on the screen rather than standing beside the list.
-- Then their right edge stood on the window's edge, which is the line the list's own rows begin
-- on, and the boxes were flush against them. They stop one pad short of it, which is the same
-- pad that stands on the other side of them. The name below them keeps its own inset and is not
-- moved: the two share a column top to bottom, not left to right, and the name is the one of
-- them that may run out into the open ground.
local STRIP_INSET = -STRIP_EDGE_PAD
local ICON_ALPHA = 0.85       -- at rest, so coming up to full is what the mouse says
local ICON_PRESS = 0.45
-- Every box is a button: a dark ground, a tint and an outline in its drawer's colour, so the
-- strip reads as four things to press rather than four loose signs. Stronger under the mouse,
-- strongest for the drawer that is open. Strength by SetAlpha: an untextured texture ignores the
-- alpha handed to SetColor.
local GROUND_ALPHA = 0.6
local TINT_REST, TINT_HOVER = 0.10, 0.20
local EDGE_REST, EDGE_LIT = 0.55, 1
-- A brief sparkle in the drawers' own colours, together with the wordmark (IG.FlashWordmark,
-- Toolbar.lua), every time the bag opens -- so a strip nobody has pressed yet still catches the
-- eye, open drawer or none.
local FLASH_DURATION_MS = 900
local FLASH_PEAK = 0.45
local FLASH_STEP_MS = 40
local FLASH_UPDATE = "InventoryGroupingDrawerFlash"
-- The plate behind the mark whose drawer is open. Faint: it is there to be told apart from the
-- three beside it at a glance, not to be read on its own, and the mark standing on it has to
-- stay the thing the eye lands on.
local OPEN_PLATE_ALPHA = 0.32

-- The panel. Half the bag's width, the bag's own height, and standing clear of its left edge:
-- the bag does not move for it and never has to be found again in a new place.
--
-- Clear of the edge and not against it. The ground immediately left of the window is not empty
-- -- the marks stand there and the name runs down it -- and a panel anchored to the window's
-- own edge covers the column it was opened from, which is the one thing on the screen that says
-- where it came from. So it stops short of the column and leaves a little air after it.
local PANEL_SHARE = 0.5
-- Between the panel's right edge and the column beside the bag. Widened from a dozen: the marks
-- stay on screen now for as long as the drawer is open, so this is no longer the gap between a
-- panel and an empty strip of ground -- it is the gap between a panel and four things you are
-- meant to be able to press, and they read as being pressed on at a dozen pixels.
-- Brought in to the gap the boxes keep from the list on their other side, so that box, panel
-- and list read as one column and not as a panel parked off in the open ground. Counted from the
-- panel's painted edge, which is its rectangle now (panelArtEdge below).
-- Three parts: air, the accent line, air (ACCENT_LINE_AIR on each side of the line).
local PANEL_GAP = 9
-- The line between the open box and its panel, in that drawer's accent. It stands in that gap,
-- clear of the panel's painted edge and of the box, and is as tall as the box it was opened from.
local ACCENT_LINE_WIDTH = 3
local ACCENT_LINE_AIR = 3
-- How far the bag's painted background reaches past the left edge of the control we measure.
-- Written down because it took finding and is worth knowing, but NOT spent in the clearance
-- below: this is the reach of a soft-edged painting and not the edge of anything, the column the
-- drawer's marks and name stand in is inside it already, and counting it pushed the panel a
-- clear sixty-five pixels further left than the player wanted it. The overlap it was added to
-- cure was the slide, not this.
--
-- This is the whole of why the panel kept coming up on top of the bag however far left it was
-- pushed. ZO_PlayerInventory is anchored to ZO_SharedRightPanelBackground with no offset across
-- (inventory.xml:97-99), so the window's own left edge is that background's left edge -- but
-- what the player sees is not that rectangle. The background is a ZO_RightPanelBG, 575 wide,
-- whose only art is a 1024-square texture hung at its top left corner with offsetX="-65"
-- (windowtemplates.xml:358-365). So the bag is painted 65 pixels further left than the control
-- we were measuring against, and every clearance worked out from that edge was 65 short. The
-- panel was clear of the numbers and underneath the picture.
local PANEL_ART_OVERHANG = 65
-- Floors, so that no arithmetic in here can end in a panel too small to see. A drawer that
-- opens somewhere wrong is a bug report; a drawer nought wide is indistinguishable from one
-- that never opened, and this file has now cost three rounds of exactly that.
local PANEL_MIN_WIDTH = 240
local PANEL_MIN_HEIGHT = 200
-- The ground and the frame. Not ZO_DefaultBackdrop any more, which is the game's own tooltip
-- chrome and draws a border sixteen pixels thick straddling the rectangle it is given: at that
-- weight the panel reads as a tooltip that will not go away rather than as a page.
--
-- This is the frame the rest of this author's addons are drawn in -- the map's own frame edge
-- over a flat dark middle, which is what XPBar's window uses (its UI.lua:41-43 and 218-221)
-- and what TomesTracker's panel uses (TomesTracker_UI.xml:224-226).
-- Taken from them rather than matched by eye, and drawn thinner than either: the corner is cut
-- to half the edge file's own height, which is the one number that sets how heavy the line
-- looks. The names beside the marks are drawn in the same frame at the same weight, so a name
-- and the panel it names read as one thing said twice rather than as two windows.
local FRAME_EDGE = "EsoUI/Art/WorldMap/worldmap_frame_edge.dds"
local FRAME_EDGE_WIDTH = 128
local FRAME_EDGE_HEIGHT = 16
local FRAME_LINE = 8          -- the corner, and so how thick the drawn line reads
local FRAME_CENTER_ALPHA = 0.88
-- The panel's own ground is not that frame any more: it is the bag's, the same two pieces of art
-- the game paints its side panels with, so the thin line and the thin black that fade out at the
-- top and the bottom are the game's and not an imitation of them. ZO_LeftPanelBG
-- (esoui/libraries/zo_templates/windowtemplates.xml:367-379) is centerscreen_left.dds, 1024
-- square, with the 64 wide centerscreen_right.dds as its right hand end hung 65 past the
-- control's right edge and 75 above its top; ZO_RightPanelBG, which the bag stands on, is the
-- same left piece at the same 75 up. Only the width differs from the bag's, so the left piece is
-- cut to the panel's width rather than stretched, and the line keeps the game's own weight.
local PANEL_ART_LEFT = "EsoUI/Art/Miscellaneous/centerscreen_left.dds"
local PANEL_ART_RIGHT = "EsoUI/Art/Miscellaneous/centerscreen_right.dds"
local PANEL_ART_SIZE = 1024
local PANEL_ART_CAP = 64
local PANEL_ART_TOP = 75
-- Where the art's painting actually stops, which is not where its textures stop. The first cut
-- hung the end piece 65 past the panel's right edge, as ZO_LeftPanelBG does, and took that as the
-- visible edge; in game the dark ground ended a long way short of it, with most of a hundred
-- pixels of empty air between it and the accent line. The end piece and the right of the left
-- piece are a fade, and ZO_LeftPanelBG gets away with it only because it stands against the
-- screen's edge. So the panel's rectangle is now the visible ground: its right edge is on the
-- accent line, and the art is hung this far past it so that its painting ends there too.
-- Neither number can be read off the dds from here. They are no longer tuned by hand in game:
-- the player moves and sizes the panel itself now (see the lock on its head), and the art
-- follows the rectangle wherever it is put, so these two only say how the art hangs off it.
-- Brought in from 95: at 95 the painted ground ran some 35 past the rectangle, and the accent
-- line stood inside it (in-game screenshot). Still an estimate, tune with the debug command.
local panelArtEdge = 60
-- How far above the panel's top the art's texture starts, so that the painted top is level with
-- the top of the first box rather than the faded head of the texture standing above it.
-- Only used when the bag's background cannot be found; normally the art hangs from it (ArtTop).
local panelArtTop = 45
-- How far in from the left piece's own left edge its painting starts. The piece used to be cut
-- PANEL_ART_OVERHANG wider than the panel, as the bag's is, which painted ground some 52 pixels
-- left of the rectangle and left the page off-centre on it (in-game screenshot: 62 of air on the
-- left, 13 on the right). Cut to this instead, the painted left edge is the rectangle's left edge,
-- so the rectangle is the visible ground on both sides and the page is laid out against it alone.
-- 13 left the visible ground starting about SIDE_PAD inside the rectangle (in-game screenshot:
-- 0-2 of air on the left against SIDE_PAD on the right), so the fade is SIDE_PAD wider than that.
local PANEL_ART_LEFT_FADE = 29
-- The bag's art is ZO_SharedRightPanelBackground's left piece, hung 75 above that control's top
-- (windowtemplates.xml:358-365, ZO_RightPanelBG). The panel's art hangs from the same control at
-- the same 75, so both grounds start, and fade out, at the same heights wherever the panel is
-- dragged up or down. ZO_PlayerInventory's top is that background's top less 20
-- (inventory.xml:97-98), which is the fallback when the background is not there.
local BAG_ART_TOP = 75
local BAG_WINDOW_ABOVE_BG = 20
-- The saved geometry's meaning; a save of another version is dropped and the default is used.
-- 3: the art no longer reaches the bag's 65 past the rectangle's left, so the old sizes are too wide.
local GEOMETRY_VERSION = 3
-- The line under the head is the game's own rule, the one its lists and panes are ruled with.
local RULE_TEXTURE = "EsoUI/Art/Miscellaneous/horizontalDivider.dds"
local RULE_HEIGHT = 4
local HEAD_HEIGHT = 34
local HEAD_PAD = 8
local HEAD_ICON = 20
local HEAD_FONT = "$(BOLD_FONT)|18|soft-shadow-thin"
local CLOSE_SIZE = 18
local CLOSE_ICON = "EsoUI/Art/Buttons/decline_up.dds"
-- The two beside the cross, right to left: the lock that says whether the panel may be moved and
-- sized, and the gear that opens this drawer's own settings. All game art, taken from addons that
-- draw them already: the padlocks from XPBar (its UI.lua:72-73) and
-- TomesTracker (TomesTracker.lua:195-196), the gear from this addon's own toolbar (Toolbar.lua,
-- PANEL_SETTINGS_ICON) and DynamicCP's windows.
local HEAD_BUTTON_GAP = 6
local LOCKED_ICON = "EsoUI/Art/Miscellaneous/locked_up.dds"
local UNLOCKED_ICON = "EsoUI/Art/Miscellaneous/unlocked_up.dds"
local GEAR_ICON = "EsoUI/Art/ChatWindow/chat_options_up.dds"
-- The chat gear sits small inside its texture, so only its middle is drawn: a square cut, the same
-- inset on every side, so it is scaled up evenly and never stretched. Tune by eye.
local GEAR_INSET = 0.15
-- Reset, between the lock and the cross: puts the panel back where it stood before it was moved.
-- The Group Finder's refresh arrows (GroupFinderPlus/GroupFinderPlus_UI.lua:128).
local RESET_ICON = "EsoUI/Art/LFG/lfg_groupfinder_refreshsearch_up.dds"
-- How far in from its edges the panel can be taken hold of to size it, once it is unlocked.
local RESIZE_HANDLE = 8
-- A width change smaller than this is the float arithmetic talking, not the panel changing size,
-- and the art is not cut again for it.
local GEOMETRY_TOLERANCE = 0.5
-- Air between the visible ground's sides and the page, head and body alike, so both are centred.
local SIDE_PAD = 16
local BODY_PAD = 10
local SOON_FONT = "$(MEDIUM_FONT)|17|soft-shadow-thin"

local strip, panel, openKey
local bagWindow
local SettleStrip

---------------------------------------------------------------------------
-- The strip
---------------------------------------------------------------------------

-- How far down the column the strip reaches, for the name that starts under it. Asked rather
-- than worked out by the caller: how many marks there are is this file's business.
function IG.DrawerStripLength()
    local count = #IG.DRAWERS
    if count == 0 then return 0 end
    return count * STRIP_BOX + (count - 1) * STRIP_GAP + STRIP_TAIL
end

-- The mark is lit when the mouse is on it and lit when its own drawer is open, and the two are
-- not told apart by how brightly it burns -- one of them is a thing you are doing and the other
-- is where you are, and a strip that says both with the same brightness says neither. So the
-- open one is lit and stands on a plate of its own colour, which is the one thing in the strip
-- that is filled rather than drawn, and there is never more than one of them.
--
-- Whether the mouse is on it is kept on the mark rather than passed in. The strip no longer
-- goes away when a drawer opens, so it is repainted while the pointer is still sitting on it,
-- and a pass that had to be told about the hover would paint it away every time.
-- The one frame, put behind whatever is handed to it, reaching the given padding outside it.
-- Written once so that the panel and the names beside the marks cannot drift apart: they are
-- the same border at the same weight because they are the same four lines of code.
local function AddFrame(control, padX, padY)
    local frame = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    frame:SetAnchor(TOPLEFT, control, TOPLEFT, -(padX or 0), -(padY or 0))
    frame:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, padX or 0, padY or 0)
    frame:SetEdgeTexture(FRAME_EDGE, FRAME_EDGE_WIDTH, FRAME_EDGE_HEIGHT, FRAME_LINE, 0)
    frame:SetCenterColor(0, 0, 0, FRAME_CENTER_ALPHA)
    frame:SetMouseEnabled(false)
    frame:SetDrawLayer(DL_BACKGROUND)
    return frame
end

local function PaintMark(mark, pressed)
    local open = openKey ~= nil and mark.igKey == openKey
    local lit = mark.igHovered or open
    local r, g, b = IG.HexToRGB(lit and "FFFFFF" or IG.DEFAULT_ICON_COLOR)
    mark.art:SetColor(r, g, b, 1)
    mark.art:SetAlpha(pressed and ICON_PRESS or (lit and 1 or ICON_ALPHA))
    local er, eg, eb = IG.HexToRGB(mark.igColor)
    for _, edge in ipairs(mark.edges) do
        edge:SetColor(er, eg, eb, 1)
        edge:SetAlpha(lit and EDGE_LIT or EDGE_REST)
    end
    mark.plate:SetColor(er, eg, eb, 1)
    mark.plate:SetAlpha(open and OPEN_PLATE_ALPHA or (mark.igHovered and TINT_HOVER or TINT_REST))
    mark.plate:SetHidden(false)
    -- The name is the mouse's alone. The open drawer says its own name across its head, and
    -- saying it twice on one screen leaves the strip looking as though two are open.
    mark.name:SetHidden(not mark.igHovered)
end

-- All four, which is what a change of which drawer is open asks for: the one that was lit goes
-- out in the same pass as the one that comes on.
local function PaintStrip()
    if not strip then return end
    local line, lineMark = strip.igAccent, nil
    for _, mark in ipairs(strip.igMarks) do
        PaintMark(mark)
        if openKey ~= nil and mark.igKey == openKey then lineMark = mark end
    end
    -- The accent line goes with the open box: level with it, the box's height, in its colour,
    -- and standing on the panel's edge on the far side of the air between them.
    -- The line takes its height from the box and its place across from the panel, one anchor for
    -- each, so that a panel the player has moved keeps it on its own right edge.
    if line then
        if lineMark and panel then
            line:ClearAnchors()
            line:SetAnchor(TOP, lineMark, TOP, 0, 0, ANCHOR_CONSTRAINS_Y)
            line:SetAnchor(LEFT, panel, RIGHT, ACCENT_LINE_AIR, 0, ANCHOR_CONSTRAINS_X)
            local r, g, b = IG.HexToRGB(lineMark.igColor)
            line:SetColor(r, g, b, 1)
            line:SetAlpha(1)
        end
        line:SetHidden(lineMark == nil)
    end
end

-- One pass of the sparkle: up over the first third, down over the rest -- felt rather than
-- watched -- then off. Doing nothing while the strip is off the screen.
local flashStart

local function StopFlash()
    EVENT_MANAGER:UnregisterForUpdate(FLASH_UPDATE)
    if strip then
        for _, mark in ipairs(strip.igMarks) do mark.pulse:SetHidden(true) end
    end
    if IG.FlashWordmark then IG.FlashWordmark(0) end
end

local function FlashStep()
    if not strip or strip:IsHidden() then return StopFlash() end
    local elapsed = GetFrameTimeMilliseconds() - flashStart
    if elapsed >= FLASH_DURATION_MS then return StopFlash() end
    local phase = elapsed / FLASH_DURATION_MS
    local level = phase < 0.3 and (phase / 0.3) or (1 - (phase - 0.3) / 0.7)
    for _, mark in ipairs(strip.igMarks) do
        mark.pulse:SetHidden(false)
        mark.pulse:SetAlpha(FLASH_PEAK * level)
    end
    if IG.FlashWordmark then IG.FlashWordmark(level) end
end

-- Held back a moment: fired the instant the bag opens, the sparkle ran its whole course while
-- the window was still sliding into place and nobody caught it. This is how long the window's
-- own opening takes to settle.
local FLASH_START_DELAY_MS = 150

-- Every bag opening, not only the first: the strip asks to be noticed the same way each time,
-- whether or not a drawer happens to be open (IG.InitDrawers).
function IG.FlashDrawerStrip()
    zo_callLater(function()
        -- The bag the delay was waiting for may have been shut again by the time it fires.
        if not strip or strip:IsHidden() then return end
        flashStart = GetFrameTimeMilliseconds()
        EVENT_MANAGER:UnregisterForUpdate(FLASH_UPDATE)
        EVENT_MANAGER:RegisterForUpdate(FLASH_UPDATE, FLASH_STEP_MS, FlashStep)
    end, FLASH_START_DELAY_MS)
end

-- The name appears to the right of the mark, written flat, out over the bag's list. It is only
-- there while the mouse is on the box, so covering a few rows for that long costs nothing. It
-- belongs to the strip, so it goes away when the strip does, and stands outside the strip's
-- rectangle: a control is not clipped by its parent, and the name takes no mouse, so being
-- outside costs it nothing either. The strip is a top level control at a high draw tier, which
-- is what keeps the name drawn over the list rather than under it.
local function AddName(mark, drawer)
    local name = WINDOW_MANAGER:CreateControl(nil, mark:GetParent(), CT_LABEL)
    name:SetFont(STRIP_NAME_FONT)
    name:SetColor(IG.HexToRGB(drawer.color))
    name:SetText(drawer.label)
    name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    name:SetMouseEnabled(false)
    name:SetDrawTier(DT_HIGH)
    name:SetAnchor(LEFT, mark, RIGHT, STRIP_NAME_GAP, 0)
    name:SetHidden(true)
    -- The same ground and the same border as the panel, reaching a little past the writing on
    -- every side. A child of the label rather than a control standing beside it, so that it is
    -- shown and hidden with the name by the one line that already does that and cannot be left
    -- behind on the screen when the pointer moves on. Behind it, so the writing stays on top.
    -- Its line in the drawer's accent, so the name says which box it belongs to in colour too.
    local frame = AddFrame(name, STRIP_NAME_PAD_X, STRIP_NAME_PAD_Y)
    local fr, fg, fb = IG.HexToRGB(drawer.color)
    frame:SetEdgeColor(fr, fg, fb, 1)
    mark.name = name
end

-- A top level control rather than a plain one hung off GuiRoot, which is what the first try
-- made and what never came up on the screen. Every addon on this machine that draws something
-- of its own out beside the game's windows makes it top level -- Srendarr's bar, Action
-- Duration Reminder's -- while the two that do hang a plain control off GuiRoot use it to
-- measure text with and never show it. A plain control there draws in GuiRoot's own layer,
-- under the windows the game puts up, and a draw tier does not lift it out of there.
local function CreateStrip()
    local control = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_TOPLEVELCONTROL)
    control:SetDrawTier(DT_HIGH)
    control:SetHidden(true)
    control.igMarks = {}

    local previous
    for _, drawer in ipairs(IG.DRAWERS) do
        local mark = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
        mark:SetMouseEnabled(true)
        mark:SetDimensions(STRIP_BOX, STRIP_BOX)
        mark.igColor = drawer.color
        mark.igKey = drawer.key
        -- One under the other, the strip no wider than they are.
        if previous then
            mark:SetAnchor(TOP, previous, BOTTOM, 0, STRIP_GAP)
        else
            mark:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
        end

        -- Under everything else in the box, so the mark and its outline are drawn on top: a dark
        -- ground, the drawer's tint over it (PaintMark), and the pulse a new player sees.
        mark.ground = WINDOW_MANAGER:CreateControl(nil, mark, CT_TEXTURE)
        mark.ground:SetAnchorFill(mark)
        mark.ground:SetDrawLayer(DL_BACKGROUND)
        mark.ground:SetDrawLevel(0)
        mark.ground:SetColor(0, 0, 0, 1)
        mark.ground:SetAlpha(GROUND_ALPHA)
        mark.ground:SetMouseEnabled(false)

        mark.plate = WINDOW_MANAGER:CreateControl(nil, mark, CT_TEXTURE)
        mark.plate:SetAnchorFill(mark)
        mark.plate:SetDrawLayer(DL_BACKGROUND)
        mark.plate:SetDrawLevel(1)
        mark.plate:SetMouseEnabled(false)

        -- On DL_OVERLAY, over the icon and its outline rather than only in the padding round
        -- them (DL_BACKGROUND sits under the icon, which left the pulse all but invisible) --
        -- and additive (TEX_BLEND_MODE_ADD), so it brightens what is under it into a glow rather
        -- than painting over it and hiding the mark.
        mark.pulse = WINDOW_MANAGER:CreateControl(nil, mark, CT_TEXTURE)
        mark.pulse:SetAnchorFill(mark)
        mark.pulse:SetDrawLayer(DL_OVERLAY)
        mark.pulse:SetBlendMode(TEX_BLEND_MODE_ADD)
        mark.pulse:SetColor(IG.HexToRGB(drawer.color))
        mark.pulse:SetMouseEnabled(false)
        mark.pulse:SetHidden(true)

        mark.art = WINDOW_MANAGER:CreateControl(nil, mark, CT_TEXTURE)
        mark.art:SetTexture(drawer.icon)
        mark.art:SetAnchor(TOPLEFT, mark, TOPLEFT, STRIP_PAD, STRIP_PAD)
        mark.art:SetAnchor(BOTTOMRIGHT, mark, BOTTOMRIGHT, -STRIP_PAD, -STRIP_PAD)
        mark.art:SetDrawLayer(DL_CONTROLS)

        IG.AddEdges(mark)
        AddName(mark, drawer)

        mark:SetHandler("OnMouseEnter", function(self)
            self.igHovered = true
            PaintMark(self)
        end)
        mark:SetHandler("OnMouseExit", function(self)
            self.igHovered = false
            PaintMark(self)
        end)
        mark:SetHandler("OnMouseDown", function(self) PaintMark(self, true) end)
        mark:SetHandler("OnMouseUp", function(self, _, upInside)
            self.igHovered = upInside
            -- The drawer first and the paint after it: which mark is lit is read off which
            -- drawer is open, so painting before the toggle paints the answer it is replacing.
            if upInside then IG.ToggleDrawer(drawer.key) end
            PaintMark(self)
        end)
        PaintMark(mark)

        control.igMarks[#control.igMarks + 1] = mark
        previous = mark
    end

    -- One line for whichever drawer is open, moved to its box by PaintStrip. Untextured, so its
    -- colour is SetColor and its strength is SetAlpha.
    local accent = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    accent:SetDimensions(ACCENT_LINE_WIDTH, STRIP_BOX)
    accent:SetMouseEnabled(false)
    accent:SetDrawLayer(DL_CONTROLS)
    accent:SetHidden(true)
    control.igAccent = accent

    control:SetDimensions(STRIP_BOX, IG.DrawerStripLength())
    return control
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------

local function CurrentDrawer()
    return openKey and DRAWER_BY_KEY[openKey] or nil
end

-- One body per drawer, built the first time it is asked for and kept: a drawer that has been
-- opened once is a page that has already been laid out, and laying it out again on every visit
-- would throw away everything it worked out about its own size.
local function BodyFor(drawer)
    local body = panel.igBodies[drawer.key]
    if body then return body end
    body = WINDOW_MANAGER:CreateControl(nil, panel, CT_CONTROL)
    body:SetAnchor(TOPLEFT, panel, TOPLEFT, SIDE_PAD, HEAD_HEIGHT + BODY_PAD)
    body:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -SIDE_PAD, -BODY_PAD)
    body.igDrawer = drawer
    panel.igBodies[drawer.key] = body

    -- The build is tried and its failure is survived. A drawer's body is filled by the file
    -- that owns it, that file is read after this one, and a fault in it -- or its simply not
    -- being there -- must not be the thing that stops the panel opening. It opens on the line
    -- below instead, which says the page is not there far more honestly than a drawer that
    -- refuses to come out at all.
    local built = false
    if drawer.build then
        built = pcall(drawer.build, body)
        if not built then
            d("Inventory 2.0: the " .. tostring(drawer.key) .. " drawer could not be filled.")
        end
    end
    if not built then
        -- A drawer with nothing in it yet says so in one line in the middle of its own page,
        -- rather than opening on an empty rectangle that reads as something having gone wrong.
        local soon = WINDOW_MANAGER:CreateControl(nil, body, CT_LABEL)
        soon:SetFont(SOON_FONT)
        soon:SetColor(IG.HexToRGB(IG.DEFAULT_ICON_COLOR))
        soon:SetAlpha(0.6)
        soon:SetAnchor(CENTER, body, CENTER, 0, 0)
        soon:SetText("Coming soon")
    end
    return body
end

-- What changes between one drawer and the next, and nothing else. The ground, the frame and
-- the rule are the game's own and are painted by nobody -- not by a theme, not by the switch
-- that colours the groups, not by this file -- so a drawer looks the same whichever it is and
-- whatever the list beside it has been set to. That is the whole point of it: a drawer is one
-- place with four pages in it, and four grounds would make it four places.
--
-- What a drawer puts inside its own body is its own business and is untouched by this.
local function PaintPanel()
    local drawer = CurrentDrawer()
    if not (panel and drawer) then return end
    local r, g, b = IG.HexToRGB(IG.DEFAULT_ICON_COLOR)
    panel.title:SetText(drawer.label)
    panel.title:SetColor(r, g, b, 1)
    panel.icon:SetTexture(drawer.icon)
    panel.icon:SetColor(r, g, b, 1)
end

-- How far left of the bag's own left edge the panel's right edge has to stop, so that nothing
-- standing in the column beside the bag is underneath it.
--
-- Two things stand there and the panel has to clear the further out of them, so both are worked
-- out from the numbers they are each placed with rather than written down a second time here --
-- change a box size or an inset and the panel moves with it:
--
--   the marks, whose right edge is STRIP_INSET out from the bag's left edge and which are
--   STRIP_BOX across, so the strip reaches STRIP_BOX - STRIP_INSET out;
--   the name under them, hung about its own inset with half a box either side of it.
--
-- The strip control itself is not asked where it is: the numbers it is placed with say the same
-- thing, without waiting for it to be drawn.
--
-- Then the edge the backdrop draws outside its own rectangle, and then air. The air is what the
-- player asked for twice: at a dozen pixels the panel's frame and the marks read as touching,
-- whatever the arithmetic says they are.
local function ColumnClearance()
    local marks = STRIP_BOX - STRIP_INSET
    -- The names stand to the right of their box now, over the list, so only the boxes are cleared.
    -- The panel's rectangle is its painted ground now (panelArtEdge), so the air is counted from
    -- the rectangle and nothing is added for the art.
    return marks + PANEL_GAP
end

-- The left piece of the art is cut to the panel's width, never stretched (see PANEL_ART_LEFT).
-- Asked again whenever the width changes, which now includes the player dragging an edge, and so
-- guarded three ways: a width it has already cut for is not cut again (to within the float
-- tolerance), a call made while one is running is dropped, and it only ever touches the panel's
-- own children -- never the panel, so nothing it does can size anything above it.
local fittingArt
-- Across, the art hangs off the panel's right edge; down, off the bag's own background, so the
-- two grounds are one pair (BAG_ART_TOP). One anchor for each axis.
local function HangArt(control)
    control.artRight:ClearAnchors()
    control.artRight:SetAnchor(TOPRIGHT, control, TOPRIGHT, panelArtEdge, 0, ANCHOR_CONSTRAINS_X)
    local bagBG = ZO_SharedRightPanelBackground
    if bagBG then
        control.artRight:SetAnchor(TOPRIGHT, bagBG, TOPRIGHT, 0, -BAG_ART_TOP, ANCHOR_CONSTRAINS_Y)
    elseif bagWindow then
        control.artRight:SetAnchor(TOPRIGHT, bagWindow, TOPRIGHT, 0, BAG_WINDOW_ABOVE_BG - BAG_ART_TOP, ANCHOR_CONSTRAINS_Y)
    else
        control.artRight:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, -panelArtTop, ANCHOR_CONSTRAINS_Y)
    end
end

local function FitArt(width)
    if not panel or fittingArt then return end
    if not width or width <= 0 then return end
    if panel.igArtWidth and math.abs(panel.igArtWidth - width) < GEOMETRY_TOLERANCE then return end
    fittingArt = true
    panel.igArtWidth = width
    HangArt(panel)
    local artWide = width + PANEL_ART_LEFT_FADE + panelArtEdge - PANEL_ART_CAP
    if artWide > PANEL_ART_SIZE then artWide = PANEL_ART_SIZE end
    panel.artLeft:SetWidth(artWide)
    -- Cut from the art's left, which carries the bag's own left hand line; its right is the even
    -- middle, where the end piece joins it without a seam.
    panel.artLeft:SetTextureCoords(0, artWide / PANEL_ART_SIZE, 0, 1)
    fittingArt = false
end

-- The panel's size is the bag's, halved across and matched down it, and the bag is a window
-- whose size is not known until it has been drawn. So it is asked again every time the drawer
-- is shown rather than once when it is built, with nothing remembered between passes: the bag
-- is not always the same size or in the same place.
--
-- It is hung off the bag, as an offset from the bag's own left edge, and not given a place in
-- the screen's numbers. The screen's numbers were tried and they are what put the drawer in the
-- top left corner of the screen: the bag's measured left edge, read as a coordinate to anchor
-- against GuiRoot, came out small enough that the clamp meant to keep the panel on the screen
-- pushed it hard against the left margin -- and there it was, at the far left, the size it was
-- told to be, nowhere near the bag. The reason that rewrite was made does not survive either:
-- the offset it replaced was said to be one "nothing was obliged to honour", but the offset was
-- correct and was simply only ever written once, because the pass guarded it on a number that
-- never changes. An offset honoured every pass is the answer to both.
--
-- Anchored to the bag rather than to GuiRoot, there is no second coordinate space to be wrong
-- about and no clamp: where the bag is, the panel is, and half the bag's width is a width that
-- cannot be off the screen if the bag is on it.
local function SettlePanel()
    if not (panel and bagWindow) then return end
    local bagWide, bagHigh = bagWindow:GetWidth(), bagWindow:GetHeight()
    -- Not yet drawn, so there is nothing to measure against. It keeps the place it already had,
    -- which is beside the bag: the anchor it is built with is the same anchor this pass writes,
    -- so an unsettled panel is in roughly the right place rather than in the screen's corner.
    if bagWide <= 0 or bagHigh <= 0 then return end

    local width = zo_round(bagWide * PANEL_SHARE)
    if width < PANEL_MIN_WIDTH then width = PANEL_MIN_WIDTH end
    -- Top and bottom on the bag window's own, so the panel is the bag's height beside it.
    local height = zo_round(bagHigh)
    if height < PANEL_MIN_HEIGHT then height = PANEL_MIN_HEIGHT end

    local offsetX, offsetY = -ColumnClearance(), 0
    -- Where the player put it, if they have: the same anchor, hung off the bag, with their
    -- numbers in it. Saved in the panel's own units (SaveGeometry), so they go straight back in.
    local saved = IG.sv and IG.sv.drawerPanel
    if saved and saved.v == GEOMETRY_VERSION and saved.width and saved.height and saved.x and saved.y then
        width = zo_max(saved.width, PANEL_MIN_WIDTH)
        height = zo_max(saved.height, PANEL_MIN_HEIGHT)
        offsetX, offsetY = saved.x, saved.y
    end

    panel:SetDimensions(width, height)
    FitArt(width)
    -- Cleared and written again in the same breath, every pass, with nothing cached between
    -- them. Both halves of that matter and both have been got wrong here. Cached, the anchor is
    -- written once and never again -- the number it is guarded on is a constant, so the guard is
    -- true exactly once -- and the bag moving or changing size after that leaves the panel
    -- behind. Cleared without being written, the control has no anchor at all, and a control
    -- with no anchor sits in the corner of the screen, which is where the player last saw it.
    panel:ClearAnchors()
    panel:SetAnchor(TOPRIGHT, bagWindow, TOPLEFT, offsetX, offsetY)
    panel.igWidth = width
end

-- Where the player left the panel, kept as the anchor SettlePanel writes: the offset of its top
-- right corner from the bag's top left, and its size. All four in the panel's own units -- the
-- positions the game reads back are scaled and SetAnchor and SetDimensions are not, so every
-- reading is divided by the scale before it is kept. One geometry for every drawer: they are
-- four pages of one panel, and a panel that jumped about as the page was turned would be four.
--
-- Only ever called from the end of a drag or a resize the player started (see the handlers in
-- CreatePanel), never from a pass that merely laid the panel out: a save from there would write
-- the factory size over the player's own.
local function SaveGeometry()
    if not (panel and bagWindow and IG.sv) or panel:IsHidden() or bagWindow:IsHidden() then return end
    local scale = panel:GetScale()
    if not scale or scale <= 0 then scale = 1 end
    local width, height = panel:GetWidth() / scale, panel:GetHeight() / scale
    if width <= 0 or height <= 0 then return end
    IG.sv.drawerPanel = {
        v = GEOMETRY_VERSION,
        x = zo_round((panel:GetRight() - bagWindow:GetLeft()) / scale),
        y = zo_round((panel:GetTop() - bagWindow:GetTop()) / scale),
        width = zo_round(width),
        height = zo_round(height),
    }
end

function IG.ResetDrawerPanel()
    if IG.sv then IG.sv.drawerPanel = nil end
    if panel and not panel:IsHidden() then SettlePanel() end
end

-- There is no slide any more, and this is where it used to be. It is worth saying why, because
-- it is the whole of the fault that took three rounds to find and none of those rounds looked
-- here: the drawer was opening in two different places on the screen off one correct anchor.
--
-- The panel slid out from under the bag's edge, and it slid only on the first opening -- the pass
-- was told to animate when no drawer was open yet, and told not to when one was, so that stepping
-- from one page to the next did not throw the whole panel about. That made the first opening a
-- panel translated the width of itself to the right of where its anchor put it, and the second
-- opening a panel standing exactly on that anchor. Two placements, and neither of them was the
-- anchor being wrong: on the way out it read as the drawer sitting on top of the bag, and on the
-- way back as the drawer flung off to the left, and every round of this widened or narrowed the
-- clearance to chase one of those two and moved the other one by exactly as much.
--
-- So the position is a pure answer to the anchor now, the same on the first opening as on the
-- twentieth, and nothing between the anchor and the screen is allowed to move it.

-- Top level for the reason the strip is, and for the same reason it is not the window's child.
local function CreatePanel(window)
    local control = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_TOPLEVELCONTROL)
    control:SetDrawTier(DT_HIGH)
    control:SetMouseEnabled(true)   -- so a click inside the drawer is not a click on the world
    control:SetHidden(true)
    -- The same anchor SettlePanel writes, so that a panel that has not been settled yet is
    -- beside the bag and only the wrong size, rather than in the corner of the screen. The
    -- corner is what GuiRoot's own top left gave, and a control standing there reads as a
    -- second window having opened somewhere else rather than as this one being unmeasured.
    control:SetAnchor(TOPRIGHT, window, TOPLEFT, -ColumnClearance(), 0)
    control.igBodies = {}

    -- Ground and frame in one, the same one the names beside the marks are drawn in. Nothing
    -- here paints it afterwards, which is what keeps it out of reach of the themes.
    -- The game's own side-panel ground, laid out as ZO_LeftPanelBG lays it out but hung by
    -- panelArtEdge and panelArtTop rather than its 65 and 75, the left piece against it. Both reach outside
    -- the panel's rectangle, which is fine -- a control does not clip its children.
    control.artRight = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    control.artRight:SetTexture(PANEL_ART_RIGHT)
    control.artRight:SetDimensions(PANEL_ART_CAP, PANEL_ART_SIZE)
    control.artRight:SetDrawLayer(DL_BACKGROUND)
    control.artRight:SetMouseEnabled(false)
    control.artLeft = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    control.artLeft:SetTexture(PANEL_ART_LEFT)
    control.artLeft:SetDimensions(PANEL_ART_SIZE, PANEL_ART_SIZE)
    control.artLeft:SetAnchor(TOPRIGHT, control.artRight, TOPLEFT, 0, 0)
    control.artLeft:SetDrawLayer(DL_BACKGROUND)
    control.artLeft:SetMouseEnabled(false)
    HangArt(control)

    -- The rule under the head, which is the only line the panel draws: it is the game's own
    -- and it is left the colour it came in.
    control.rule = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    control.rule:SetTexture(RULE_TEXTURE)
    control.rule:SetHeight(RULE_HEIGHT)
    control.rule:SetAnchor(TOPLEFT, control, TOPLEFT, SIDE_PAD, HEAD_HEIGHT - RULE_HEIGHT / 2)
    control.rule:SetAnchor(TOPRIGHT, control, TOPRIGHT, -SIDE_PAD, HEAD_HEIGHT - RULE_HEIGHT / 2)
    control.rule:SetDrawLayer(DL_CONTROLS)

    control.icon = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    control.icon:SetDimensions(HEAD_ICON, HEAD_ICON)
    control.icon:SetAnchor(LEFT, control, TOPLEFT, SIDE_PAD, HEAD_HEIGHT / 2)
    control.icon:SetDrawLayer(DL_CONTROLS)
    -- The mark on the head is the same mark that was pressed to get here, and pressing it again
    -- is one of the four ways back out.
    local iconButton = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
    iconButton:SetMouseEnabled(true)
    iconButton:SetAnchor(TOPLEFT, control.icon, TOPLEFT, -2, -2)
    iconButton:SetAnchor(BOTTOMRIGHT, control.icon, BOTTOMRIGHT, 2, 2)
    iconButton:SetHandler("OnMouseUp", function(_, _, upInside)
        if upInside then IG.CloseDrawer() end
    end)

    control.title = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    control.title:SetFont(HEAD_FONT)
    control.title:SetAnchor(LEFT, control.icon, RIGHT, HEAD_PAD, 0)
    control.title:SetDrawLayer(DL_CONTROLS)

    local close = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
    close:SetMouseEnabled(true)
    close:SetDimensions(CLOSE_SIZE, CLOSE_SIZE)
    close:SetAnchor(RIGHT, control, TOPRIGHT, -SIDE_PAD, HEAD_HEIGHT / 2)
    close.art = WINDOW_MANAGER:CreateControl(nil, close, CT_TEXTURE)
    close.art:SetTexture(CLOSE_ICON)
    close.art:SetAnchorFill(close)
    close.art:SetDrawLayer(DL_CONTROLS)
    close.art:SetAlpha(ICON_ALPHA)
    close:SetHandler("OnMouseEnter", function() close.art:SetAlpha(1) end)
    close:SetHandler("OnMouseExit", function() close.art:SetAlpha(ICON_ALPHA) end)
    close:SetHandler("OnMouseUp", function(_, _, upInside)
        if upInside then IG.CloseDrawer() end
    end)

    -- The lock, then the gear, each standing left of the one before it. Same size and same rest
    -- and hover alpha as the cross, so the three read as one row of buttons.
    local function HeadButton(anchorTo, texture, tip, onPress)
        local button = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
        button:SetMouseEnabled(true)
        button:SetDimensions(CLOSE_SIZE, CLOSE_SIZE)
        button:SetAnchor(RIGHT, anchorTo, LEFT, -HEAD_BUTTON_GAP, 0)
        button.art = WINDOW_MANAGER:CreateControl(nil, button, CT_TEXTURE)
        button.art:SetTexture(texture)
        button.art:SetAnchorFill(button)
        button.art:SetDrawLayer(DL_CONTROLS)
        button.art:SetAlpha(ICON_ALPHA)
        button.igTip = tip
        button:SetHandler("OnMouseEnter", function(self)
            self.art:SetAlpha(1)
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4)
            SetTooltipText(InformationTooltip, type(self.igTip) == "function" and self.igTip() or self.igTip)
        end)
        button:SetHandler("OnMouseExit", function(self)
            self.art:SetAlpha(ICON_ALPHA)
            ClearTooltip(InformationTooltip)
        end)
        button:SetHandler("OnMouseUp", function(self, _, upInside)
            if upInside then onPress(self) end
        end)
        return button
    end

    -- The same path as the settings' Reset Drawer Position.
    local reset = HeadButton(close, RESET_ICON, "Reset position", function()
        PlaySound(SOUNDS.DEFAULT_CLICK)
        if IG.ResetDrawerPanel then IG.ResetDrawerPanel() end
    end)

    local lock
    lock = HeadButton(reset, LOCKED_ICON, function()
        return (IG.sv and IG.sv.drawerPanelUnlocked) and "Lock the panel in place"
            or "Unlock the panel to move and resize it"
    end, function(self)
        if not IG.sv then return end
        IG.sv.drawerPanelUnlocked = not IG.sv.drawerPanelUnlocked
        PlaySound(SOUNDS.DEFAULT_CLICK)
        control.igApplyLock()
        -- Said again under the pointer, which has not left the button.
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4)
        SetTooltipText(InformationTooltip, self.igTip())
    end)
    control.lock = lock

    local gear = HeadButton(lock, GEAR_ICON, "Settings for this drawer", function()
        local key = openKey
        ClearTooltip(InformationTooltip)
        if IG.OpenDrawerSettings then IG.OpenDrawerSettings(key)
        elseif IG.OpenSettings then IG.OpenSettings() end
    end)
    gear.art:SetTextureCoords(GEAR_INSET, 1 - GEAR_INSET, GEAR_INSET, 1 - GEAR_INSET)

    -- Locked, the panel stands where it is put and takes no hold on its edges. Unlocked, the
    -- whole of it is a handle to drag by -- the head, the ground, anything a page has not taken
    -- the mouse for itself -- and its edges are handles to size it by.
    control:SetDimensionConstraints(PANEL_MIN_WIDTH, PANEL_MIN_HEIGHT, 0, 0)
    control:SetClampedToScreen(true)
    function control.igApplyLock()
        local unlocked = IG.sv and IG.sv.drawerPanelUnlocked == true
        control:SetMovable(unlocked)
        if control.SetResizeHandleSize then
            control:SetResizeHandleSize(unlocked and RESIZE_HANDLE or 0)
        end
        lock.art:SetTexture(unlocked and UNLOCKED_ICON or LOCKED_ICON)
    end
    control.igApplyLock()

    -- Saved only at the end of something the player started. The start handlers are the gate:
    -- a stop with no start in front of it is the engine laying things out, not a choice.
    control:SetHandler("OnMoveStart", function() control.igDragging = true end)
    control:SetHandler("OnMoveStop", function()
        if not control.igDragging then return end
        control.igDragging = false
        SaveGeometry()
        -- The drag left the panel on whatever anchor the engine gave it; it goes back on the
        -- bag's, with the numbers just saved in it.
        SettlePanel()
    end)
    control:SetHandler("OnResizeStart", function() control.igSizing = true end)
    control:SetHandler("OnResizeStop", function()
        if not control.igSizing then return end
        control.igSizing = false
        SaveGeometry()
        SettlePanel()
    end)
    -- The art follows the edge while it is being dragged, not only once it is let go. Deferred
    -- to a one-shot timer rather than done inside the rect change, with one pending at a time,
    -- and FitArt itself guarded besides: resizing from inside a rect change is what froze the
    -- game at the load screen once already.
    control:SetHandler("OnRectChanged", function()
        if control.igArtPending then return end
        control.igArtPending = true
        zo_callLater(function()
            control.igArtPending = false
            local scale = control:GetScale()
            if not scale or scale <= 0 then scale = 1 end
            FitArt(control:GetWidth() / scale)
        end, 0)
    end)

    return control
end

---------------------------------------------------------------------------
-- Opening and closing
---------------------------------------------------------------------------

-- Whether the drawers belong on the screen at all right now: the addon running, the bag open,
-- and the bag on its own rather than in one of the scenes a sale is made in or beside a bank.
local function BagIsOurs()
    if not (IG.IsEnabled and IG.IsEnabled()) then return false end
    if not (bagWindow and not bagWindow:IsHidden()) then return false end
    -- And the bag's fragment showing or shown, not on its way out. Closing the guild store, the
    -- bag is still on screen fading out after the trading scene has stopped being the current
    -- one, so for a few frames it read as "the bag on its own" and the drawer remembered open
    -- was put up -- the Equipped page built from nothing on the way out (a 185-212 ms frame).
    if INVENTORY_FRAGMENT and not INVENTORY_FRAGMENT:IsShowing() then return false end
    return IG.sv ~= nil and IG.BagOnItsOwn ~= nil and IG.BagOnItsOwn()
end

-- A pass that may fail, run so that its failing is said out loud. Swallowed instead, which is
-- how the last round of this went out, a drawer that gives up halfway through being placed comes
-- up somewhere wrong with nothing anywhere to say which half of the placing it got through.
local function Try(what, fn, arg)
    local ok, result = pcall(fn, arg)
    if ok then return result end
    d("Inventory 2.0: the drawer's " .. what .. " failed -- " .. tostring(result))
    return nil
end

-- What is on screen, said in one place: the strip is there whenever the bag is ours to draw
-- beside, the panel as well when a drawer is open, and neither when it is not.
-- A drawer brought back by the bag opening (not by a click) is shown two frames later, once the
-- bag and its list are on screen, so the page fill is not part of the opening's hitch. Cancelled
-- if the bag goes away first. Each page is refreshed once per opening; changes while it is open
-- come in through RefreshOpenDrawer.
local REOPEN_NAME = "Inventory2DrawerDeferredReopen"
local REOPEN_FRAMES = 2
local reopenFrames = nil

local function CancelReopen()
    if reopenFrames then
        EVENT_MANAGER:UnregisterForUpdate(REOPEN_NAME)
        reopenFrames = nil
    end
end

local Show

local function OnReopenFrame()
    reopenFrames = (reopenFrames or 0) + 1
    if reopenFrames < REOPEN_FRAMES then return end
    CancelReopen()
    if BagIsOurs() and openKey then Show(true) end
end

local function ScheduleReopen()
    if reopenFrames then return end
    reopenFrames = 0
    EVENT_MANAGER:RegisterForUpdate(REOPEN_NAME, 0, OnReopenFrame)
end

function Show(immediate)
    -- Put where it belongs first. The column's head is a measurement of a window that has been
    -- drawn, and this runs when that window is shown, which is the first pass that can answer.
    SettleStrip()
    local live = BagIsOurs()

    -- The marks come and go with the bag and with nothing else. They used to go away for as long
    -- as a drawer was open, which left no way back to the other three without shutting the one
    -- you were in first, and nothing on screen saying there were others. They stay, and the one
    -- whose drawer is open is lit and plated (PaintMark).
    --
    -- A mark taken off the screen from under the pointer never gets its leaving, so the hover it
    -- was holding is dropped by hand rather than left standing for the next time the bag opens.
    if strip then
        strip:SetHidden(not (live and strip.igMeasured))
        if not live then
            for _, mark in ipairs(strip.igMarks) do
                mark.igHovered = false
                mark.name:SetHidden(true)
            end
        end
    end
    PaintStrip()

    if not panel then return end
    if not live or not openKey then
        CancelReopen()
        -- The next opening fills the page again.
        if not live then
            for _, other in pairs(panel.igBodies) do other.igFreshThisOpening = nil end
        end
        panel:SetHidden(true)
        return
    end

    -- Hidden and not asked for by a click: the bag is opening, so it waits (ScheduleReopen).
    if panel:IsHidden() and not immediate then
        ScheduleReopen()
        return
    end
    CancelReopen()

    -- Every pass that can fail is survived on its own, and says so if it does. None of them may
    -- keep the panel shut: a drawer that gives up halfway through being placed still opens, in
    -- whatever place it got as far as, because a drawer that is somewhere wrong can be pointed
    -- at and a drawer that never came can only be guessed about.
    Try("placement", SettlePanel)
    local drawer = CurrentDrawer()
    if not drawer then
        panel:SetHidden(true)
        return
    end
    local body = Try("page", BodyFor, drawer)
    for key, other in pairs(panel.igBodies) do other:SetHidden(key ~= drawer.key) end
    Try("head", PaintPanel)
    -- Full alpha before it is shown, whatever the slide is about to do with it: see Slide.
    panel:SetAlpha(1)
    -- On screen first, and filled in afterwards. Drawing a page again is the one thing in here
    -- that runs somebody else's code, and it used to run before the panel was ever unhidden:
    -- anything that went wrong in it took the opening with it, and the drawer stayed shut with
    -- nothing on screen to say why. The panel opening is not that code's to decide.
    panel:SetHidden(false)
    if body and drawer.refresh and not body.igFreshThisOpening then
        body.igFreshThisOpening = true
        pcall(drawer.refresh, body)
    end
end

function IG.OpenDrawer(key)
    if not DRAWER_BY_KEY[key] then return end
    openKey = key
    if IG.sv then IG.sv.drawerOpen = key end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    Show(true)
end

function IG.CloseDrawer()
    if not openKey then return false end
    openKey = nil
    if IG.sv then IG.sv.drawerOpen = nil end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    Show()
    return true
end

function IG.ToggleDrawer(key)
    if openKey == key then return IG.CloseDrawer() end
    IG.OpenDrawer(key)
end

-- The drawer on screen draws itself again, if it is the kind that can change while it is being
-- looked at. Nothing is rebuilt and nothing is measured: this runs on an event.
function IG.RefreshOpenDrawer()
    if not (panel and openKey) or panel:IsHidden() then return end
    local drawer = CurrentDrawer()
    local body = panel.igBodies[openKey]
    if drawer and drawer.refresh and body then drawer.refresh(body) end
end

---------------------------------------------------------------------------
-- Where the strip stands
---------------------------------------------------------------------------

-- In the name's own column, starting at the line the name starts from: the marks take the head
-- of the column and the name begins under them (Toolbar.lua, SettleWordmark). One anchor for
-- both directions -- a control is allowed two and this spends one.
--
-- And if that column has not been measured yet, the strip goes to the very top of the window
-- rather than waiting for an answer. Waiting means the strip is never anchored at all, and a
-- control with no anchor does not stay where it was built -- it sits in the corner of the
-- screen, which from the bag reads as the strip not existing. That is how the first try at
-- this went out: nothing was in the wrong place because nothing was anywhere. Marks standing
-- level with the window's top edge say at a glance which of the two happened.
function SettleStrip()
    if not (strip and bagWindow) then return end
    local head = IG.WordmarkHead and IG.WordmarkHead()
    local measured = head ~= nil and bagWindow:GetHeight() > 0
    -- No name column at all (Toolbar not built): nothing will ever measure, so the top edge it is.
    if not IG.WordmarkHead then head, measured = bagWindow:GetTop(), true end
    -- Unmeasured, the strip is kept hidden (Show) rather than drawn at the window's top for a
    -- frame; Toolbar.lua asks again next frame and falls back to a visible top edge in the end.
    strip.igMeasured = measured
    if not measured then return end
    local drop = zo_round(head - bagWindow:GetTop())
    if strip.igDrop == drop then return end
    strip.igDrop = drop
    strip:ClearAnchors()
    strip:SetAnchor(TOPRIGHT, bagWindow, TOPLEFT, STRIP_INSET, drop)
end

function IG.SettleDrawerStrip()
    SettleStrip()
    Show()
end

-- Set when the bag window's OnEffectivelyShown ran the toolbar pass for this opening.
local shownPassDone = false

function IG.CreateDrawers(window)
    if strip then return end
    bagWindow = window
    strip = CreateStrip()
    panel = CreatePanel(window)

    -- The strip stands beside this window and comes and goes with it, so it listens to the
    -- window itself rather than only to the fragment that shows it. The two are not the same
    -- moment: the fragment says it is showing while the control it shows is still hidden, and
    -- the question asked here -- is the bag on screen -- is asked of that control. Asked on the
    -- fragment's word alone it can be asked one pass too early, answer no, and leave the strip
    -- put away for the whole time the bag is open with nothing on screen to say why.
    --
    -- The whole toolbar pass on the way in rather than this file's own, for the reason the
    -- fragment's own hook gives below: where these stand is measured off the name beside them
    -- and the name is measured off a window that has been drawn. On the way out there is
    -- nothing left to measure, so that one only puts things away.
    ZO_PreHookHandler(window, "OnEffectivelyShown", function()
        shownPassDone = true
        if IG.RepaintToolbar then IG.RepaintToolbar() else Show() end
        -- The bag has just come on screen: the one reliable "it just opened" signal in this
        -- file (the fragment's own SCENE_FRAGMENT_SHOWN fires too, but only on the first of a
        -- run of them -- this hook is what shownPassDone itself is set from).
        if IG.FlashDrawerStrip then IG.FlashDrawerStrip() end
    end)
    ZO_PreHookHandler(window, "OnEffectivelyHidden", function() Show() end)

    SettleStrip()
    -- What was open when the bag was last shut is open again. Read here rather than at load:
    -- this is the first moment there is anything to open.
    local saved = IG.sv and IG.sv.drawerOpen
    if saved and DRAWER_BY_KEY[saved] then openKey = saved end
    Show()
end

-- Escape shuts the bag and the drawer goes with it, in one press. The drawer used to take the
-- first press for itself, which left the bag needing a second. Shutting the bag only hides the
-- panel (Show): the drawer that was open stays open in openKey and in drawerOpen, so the bag
-- brings it back the next time it opens, however it was shut. Only the cross or its mark
-- (CloseDrawer) forgets it. The marked pieces still take Escape first (Select.lua).
function IG.InitDrawers()
    if not IG.IsEnabled() then return end
    if INVENTORY_FRAGMENT then
        INVENTORY_FRAGMENT:RegisterCallback("StateChange", function(_, newState)
            -- The window's own OnEffectivelyShown has already run the whole pass for this
            -- opening (it comes between SHOWING and SHOWN), so SHOWN would only do the same
            -- work -- the drawer page drawn again included -- a second time.
            if newState == SCENE_FRAGMENT_HIDDEN then
                shownPassDone = false
            elseif newState == SCENE_FRAGMENT_SHOWN and shownPassDone then
                return
            end
            -- Put on screen or taken off it with the window, and measured again while we are
            -- here: the bag is not always the size it was last time it was open.
            --
            -- The whole toolbar pass rather than this file's own, because the column these
            -- stand in is measured off a window that has been drawn, and the moment the window
            -- is shown is the first pass that can answer -- for the name down the side as much
            -- as for the strip beside it. It runs on opening and closing a bag and nowhere else.
            if IG.RepaintToolbar then IG.RepaintToolbar() else Show() end
        end)
    end
end

---------------------------------------------------------------------------
-- The AUTOMATE drawer's page
---------------------------------------------------------------------------

-- The switches of IG.AUTOMATE_ACTIONS and IG.AUTOMATE_LAYOUT (Classify.lua), one line each: the
-- name and its answer, the whole line the button, the explanation on hover. The settings page
-- draws the same table (Settings.lua, AutomateSettingsPage), and both write through
-- IG.SetAutomate, so a pair turns its other half off wherever it was pressed.
local AUTO_HEAD_FONT = "$(BOLD_FONT)|16|soft-shadow-thin"
local AUTO_ROW_FONT = "$(MEDIUM_FONT)|15|soft-shadow-thin"
local AUTO_TEXT = "F2F2F2"
local AUTO_ON = "2CFF3C"
local AUTO_OFF = "9A9AA2"
local AUTO_ROW_HEIGHT = 24
local AUTO_HEAD_GAP = 12
-- The page: the explanation on top, then three tabs, one shown at a time, each a framed button;
-- the lit one wears the drawer's accent. The tabs shrink their font until every name fits its box.
local AUTO_TAB_FONTS = { 14, 13, 12, 11, 10 }
local AUTO_TAB_FONT = "$(BOLD_FONT)|%d|soft-shadow-thin"
local AUTO_TAB_HEIGHT = 26
local AUTO_TAB_SPACING = 4    -- between two tab boxes
-- The explanation on top: a card in the drawer's accent.
local AUTO_INFO_HEIGHT = 100
local AUTO_INFO_INSET = 10
local AUTO_INFO_TITLE_FONT = "$(BOLD_FONT)|15|soft-shadow-thin"
local AUTO_INFO_FONT = "$(MEDIUM_FONT)|13|soft-shadow-thin"
local AUTO_INFO_TEXT_TOP = 30 -- the text starts under the title
-- The two action buttons under the sorting tabs.
local AUTO_ACTION_HEIGHT = 30
local AUTO_ACTION_GAP = 6
local AUTO_ACTION_FONT = "$(BOLD_FONT)|15|soft-shadow-thin"
local AUTO_ACTION_STATE_FONT = "$(BOLD_FONT)|13|soft-shadow-thin"
local AUTO_SECTION_FONT = "$(BOLD_FONT)|13|soft-shadow-thin"
local AUTO_SECTION_HEIGHT = 18
local AUTO_SECTION_GAP = 14   -- above a section heading (the first one sits at the top)
local AUTO_RULE_ALPHA = 0.35  -- the heading's thin rule; alpha by SetAlpha (untextured texture)
-- The warning over the two action buttons: the game's own heavy condensed face (the one its big
-- callouts are set in), red, and nothing round it.
local AUTO_WARN_FONT = "EsoUI/Common/Fonts/FTN87.slug|24|soft-shadow-thick"
local AUTO_WARN_COLOR = "FF4A3A"
local AUTO_WARN_HEIGHT = 30
-- By what the piece is: setless gear, everything else, and the repairs. A save still holding one
-- of the old tab keys (SELL, DECON) opens on the first tab (ActiveAutoTab).
local AUTO_TABS = {
    { key = "GEAR", label = "SETLESS GEAR" },
    { key = "ITEMS", label = "ITEMS" },
    { key = "REPAIR", label = "REPAIRING" },
}

local function AutoLabel(parent, font)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(font)
    label:SetMouseEnabled(false)
    return label
end

-- A rule may bring its own get/set (REPAIRING, Repair.lua) and a pick = { values, labels } for a
-- line with more than two answers; pressing it takes the next answer.
local function RuleValue(rule)
    if rule.get then return rule.get() end
    return IG.AutomateOn(rule.key)
end

local function RuleText(rule)
    local value = RuleValue(rule)
    if rule.pick then
        for index, answer in ipairs(rule.pick.values) do
            if answer == value then return rule.pick.labels[index], true end
        end
        return rule.pick.labels[1], true
    end
    return value and "ON" or "OFF", value
end

-- A pick with an offValue reads that answer as off (the paired rules' Off).
local function RuleLit(rule)
    if rule.pick and rule.pick.offValue ~= nil then
        return RuleValue(rule) ~= rule.pick.offValue
    end
    local _, on = RuleText(rule)
    return on
end

local function AutoRow(body, rule)
    local row = WINDOW_MANAGER:CreateControl(nil, body, CT_CONTROL)
    row:SetHeight(AUTO_ROW_HEIGHT)
    row:SetMouseEnabled(true)

    local hover = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    hover:SetAnchorFill(row)
    hover:SetColor(1, 1, 1, 0.06)
    hover:SetHidden(true)

    row.name = AutoLabel(row, AUTO_ROW_FONT)
    -- A line may carry a mark before its name (the MODULES drawer's lines do).
    local nameLeft = 4
    if rule.icon then
        row.icon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
        row.icon:SetDimensions(AUTO_ROW_HEIGHT - 4, AUTO_ROW_HEIGHT - 4)
        row.icon:SetAnchor(LEFT, row, LEFT, 4, 0)
        row.icon:SetTexture(rule.icon)
        if rule.color then row.icon:SetColor(IG.HexToRGB(rule.color)) end
        nameLeft = AUTO_ROW_HEIGHT + 6
    end
    row.name:SetAnchor(LEFT, row, LEFT, nameLeft, 0)
    row.name:SetColor(IG.HexToRGB(AUTO_TEXT))
    row.name:SetText(rule.name)
    row.state = AutoLabel(row, AUTO_ROW_FONT)
    row.state:SetAnchor(RIGHT, row, RIGHT, -4, 0)

    row:SetHandler("OnMouseEnter", function(self)
        hover:SetHidden(false)
        InitializeTooltip(InformationTooltip, self, RIGHT, -8, 0)
        SetTooltipText(InformationTooltip, rule.description)
    end)
    row:SetHandler("OnMouseExit", function()
        hover:SetHidden(true)
        ClearTooltip(InformationTooltip)
    end)
    row:SetHandler("OnMouseUp", function(_, _, upInside)
        if not upInside or not IG.sv then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        if rule.pick then
            local values, at = rule.pick.values, 1
            for index, answer in ipairs(values) do
                if answer == RuleValue(rule) then at = index end
            end
            rule.set(values[at % #values + 1])
        elseif rule.set then
            rule.set(not RuleValue(rule))
        else
            IG.SetAutomate(rule.key, not IG.AutomateOn(rule.key))
        end
        IG.RefreshAutomateDrawer(body)
        -- The normal path: the lists are rebuilt by the game (RefreshLists marks them dirty).
        IG.RefreshLists()
        if IG.RefreshSettingsPanel then IG.RefreshSettingsPanel() end
    end)
    row.igRule = rule
    return row
end

local function ActiveAutoTab()
    local key = IG.sv and IG.sv.automateTab
    for _, tab in ipairs(AUTO_TABS) do
        if tab.key == key then return key end
    end
    return AUTO_TABS[1].key
end

local function AutoAccent()
    return DRAWER_BY_KEY.automate and DRAWER_BY_KEY.automate.color or AUTO_TEXT
end

-- The tabs: three framed boxes sharing the bar's width, each a button. Laid out on every show and
-- refresh, because the bar's width is only known once the drawer has been drawn; the font is
-- the largest at which every name fits its own box. Asked here rather than from a size handler
-- (a resize from inside OnRectChanged can hang the client).
local function FitAutoTabs(body)
    local bar = body.igAutoTabBar
    local width = bar and bar:GetWidth() or 0
    if width <= 0 then return end
    local tabs = body.igAutoTabs
    local boxWidth = (width - AUTO_TAB_SPACING * (#tabs - 1)) / #tabs
    for index, tab in ipairs(tabs) do
        tab:ClearAnchors()
        tab:SetDimensions(zo_round(boxWidth), AUTO_TAB_HEIGHT)
        tab:SetAnchor(TOPLEFT, bar, TOPLEFT, zo_round((boxWidth + AUTO_TAB_SPACING) * (index - 1)), 0)
    end
    for _, size in ipairs(AUTO_TAB_FONTS) do
        local fits = true
        for _, tab in ipairs(tabs) do
            tab.label:SetFont(string.format(AUTO_TAB_FONT, size))
            if tab.label:GetTextWidth() > boxWidth - 8 then fits = false end
        end
        if fits then return end
    end
end

-- A framed box painted one of three ways: lit in a colour, at rest, or under the mouse.
local function PaintBox(box, hex, fillAlpha, edgeAlpha)
    local r, g, b = IG.HexToRGB(hex)
    box.fill:SetColor(r, g, b, 1)
    box.fill:SetAlpha(fillAlpha)
    for _, edge in ipairs(box.edges) do
        edge:SetColor(r, g, b, 1)
        edge:SetAlpha(edgeAlpha)
    end
end

local function PaintAutoTabs(body)
    local active = ActiveAutoTab()
    local accent = AutoAccent()
    for _, tab in ipairs(body.igAutoTabs) do
        if tab.igTab == active then
            PaintBox(tab, accent, 0.22, 0.9)
            tab.label:SetColor(IG.HexToRGB(AUTO_TEXT))
        else
            PaintBox(tab, tab.igHovered and AUTO_TEXT or AUTO_OFF, tab.igHovered and 0.10 or 0.06, 0.4)
            tab.label:SetColor(IG.HexToRGB(tab.igHovered and AUTO_TEXT or AUTO_OFF))
        end
    end
end

-- The two action buttons: lit in their answer's colour, amber for Ask First and red for On.
local ACTION_STATE = { off = "OFF", ask = "ASK FIRST", auto = "ON" }
local function PaintActionButtons(body)
    for _, button in ipairs(body.igActionButtons or {}) do
        local mode = IG.ActionMode(button.igWhich)
        local color = IG.ACTION_PICK.colors[mode] or AUTO_OFF
        if mode == "off" then
            PaintBox(button, button.igHovered and AUTO_TEXT or AUTO_OFF, button.igHovered and 0.10 or 0.06, 0.4)
            button.name:SetColor(IG.HexToRGB(button.igHovered and AUTO_TEXT or AUTO_OFF))
        else
            PaintBox(button, color, button.igHovered and 0.32 or 0.24, 0.95)
            button.name:SetColor(IG.HexToRGB(AUTO_TEXT))
        end
        button.state:SetText(ACTION_STATE[mode])
        button.state:SetColor(IG.HexToRGB(mode == "off" and AUTO_OFF or color))
    end
end

-- The explanation on top hangs from the top; the tab bar below it; then only the lit tab's lines,
-- one under the other, and under the sorting tabs the warning and the two action buttons. The
-- rest are hidden and let go of their anchors, so they take no room.
local function ShowAutoTab(body)
    local active = ActiveAutoTab()
    local withActions = active ~= "REPAIR"
    for key, page in pairs(body.igAutoPages) do
        for _, item in ipairs(page) do
            item.control:ClearAnchors()
            item.control:SetHidden(key ~= active and key ~= "TOP" and not (key == "BOTTOM" and withActions))
        end
    end
    local bar = body.igAutoTabBar
    bar:ClearAnchors()
    local previous
    local function Hang(control, gap)
        if previous then
            control:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, gap)
            control:SetAnchor(TOPRIGHT, previous, BOTTOMRIGHT, 0, gap)
        else
            control:SetAnchor(TOPLEFT, body, TOPLEFT, 0, 0)
            control:SetAnchor(TOPRIGHT, body, TOPRIGHT, 0, 0)
        end
        previous = control
    end
    for _, item in ipairs(body.igAutoPages.TOP or {}) do Hang(item.control, item.gap) end
    Hang(bar, AUTO_HEAD_GAP)
    for index, item in ipairs(body.igAutoPages[active] or {}) do
        Hang(item.control, index == 1 and AUTO_HEAD_GAP or item.gap)
    end
    if withActions then
        for _, item in ipairs(body.igAutoPages.BOTTOM or {}) do Hang(item.control, item.gap) end
    end
    FitAutoTabs(body)
    PaintAutoTabs(body)
end

-- A framed box: a ground and a thin outline, the toolbar's own four lines (IG.AddEdges).
local function AutoBox(parent)
    local box = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    box:SetMouseEnabled(true)
    box.fill = WINDOW_MANAGER:CreateControl(nil, box, CT_TEXTURE)
    box.fill:SetAnchorFill(box)
    box.fill:SetMouseEnabled(false)
    IG.AddEdges(box)
    return box
end

function IG.BuildAutomateDrawer(body)
    body.igAutoRows = {}
    body.igAutoPages = {}
    body.igAutoTabs = {}
    body.igActionButtons = {}

    local function Add(pageKey, control, gap)
        body.igAutoPages[pageKey] = body.igAutoPages[pageKey] or {}
        local page = body.igAutoPages[pageKey]
        page[#page + 1] = { control = control, gap = gap }
    end

    -- On top: what this page does, and what it does not do.
    local info = WINDOW_MANAGER:CreateControl(nil, body, CT_CONTROL)
    info:SetHeight(AUTO_INFO_HEIGHT)
    info:SetMouseEnabled(false)
    local infoFill = WINDOW_MANAGER:CreateControl(nil, info, CT_TEXTURE)
    infoFill:SetAnchorFill(info)
    infoFill:SetColor(IG.HexToRGB(AutoAccent()))
    infoFill:SetAlpha(0.10)
    infoFill:SetMouseEnabled(false)
    IG.AddEdges(info)
    for _, edge in ipairs(info.edges) do
        edge:SetColor(IG.HexToRGB(AutoAccent()))
        edge:SetAlpha(0.6)
    end
    local infoTitle = AutoLabel(info, AUTO_INFO_TITLE_FONT)
    infoTitle:SetColor(IG.HexToRGB(AutoAccent()))
    infoTitle:SetText("AUTOMATIC SORTING")
    infoTitle:SetAnchor(TOP, info, TOP, 0, 7)
    infoTitle:SetDrawLayer(DL_CONTROLS)
    local infoText = AutoLabel(info, AUTO_INFO_FONT)
    infoText:SetColor(IG.HexToRGB(AUTO_TEXT))
    infoText:SetText("Sorts kinds of items into SELL or DECONSTRUCT. Nothing is sold or broken "
        .. "down until you turn on the buttons below.")
    infoText:SetAnchor(TOPLEFT, info, TOPLEFT, AUTO_INFO_INSET, AUTO_INFO_TEXT_TOP)
    infoText:SetAnchor(BOTTOMRIGHT, info, BOTTOMRIGHT, -AUTO_INFO_INSET, -6)
    infoText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    infoText:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    infoText:SetMaxLineCount(4)
    infoText:SetDrawLayer(DL_CONTROLS)
    Add("TOP", info, 0)

    -- The tab bar: SETLESS GEAR | ITEMS | REPAIRING, each a framed button (laid out by FitAutoTabs).
    local bar = WINDOW_MANAGER:CreateControl(nil, body, CT_CONTROL)
    bar:SetHeight(AUTO_TAB_HEIGHT)
    body.igAutoTabBar = bar
    for _, entry in ipairs(AUTO_TABS) do
        local tab = AutoBox(bar)
        tab.label = AutoLabel(tab, string.format(AUTO_TAB_FONT, AUTO_TAB_FONTS[1]))
        tab.label:SetText(entry.label)
        tab.label:SetAnchor(CENTER, tab, CENTER, 0, 0)
        tab.label:SetDrawLayer(DL_CONTROLS)
        tab.igTab = entry.key
        tab:SetHandler("OnMouseEnter", function(self)
            self.igHovered = true
            PaintAutoTabs(body)
        end)
        tab:SetHandler("OnMouseExit", function(self)
            self.igHovered = false
            PaintAutoTabs(body)
        end)
        tab:SetHandler("OnMouseUp", function(_, _, upInside)
            if not upInside or not IG.sv then return end
            PlaySound(SOUNDS.DEFAULT_CLICK)
            IG.sv.automateTab = entry.key
            ShowAutoTab(body)
        end)
        body.igAutoTabs[#body.igAutoTabs + 1] = tab
    end

    -- A section heading: small uppercase label in the accent, a thin rule running to the right edge.
    local function Section(pageKey, text, first)
        local head = WINDOW_MANAGER:CreateControl(nil, body, CT_CONTROL)
        head:SetHeight(AUTO_SECTION_HEIGHT)
        head:SetMouseEnabled(false)
        local label = AutoLabel(head, AUTO_SECTION_FONT)
        label:SetAnchor(LEFT, head, LEFT, 4, 0)
        label:SetColor(IG.HexToRGB(AutoAccent()))
        label:SetText(zo_strupper(text))
        local rule = WINDOW_MANAGER:CreateControl(nil, head, CT_TEXTURE)
        rule:SetHeight(1)
        rule:SetAnchor(LEFT, label, RIGHT, 8, 1)
        rule:SetAnchor(RIGHT, head, RIGHT, -4, 1)
        rule:SetColor(IG.HexToRGB(AutoAccent()))
        rule:SetAlpha(AUTO_RULE_ALPHA)
        rule:SetMouseEnabled(false)
        Add(pageKey, head, first and 0 or AUTO_SECTION_GAP)
    end
    local function Rows(pageKey, list)
        for _, rule in ipairs(list) do
            local row = AutoRow(body, rule)
            Add(pageKey, row, 2)
            body.igAutoRows[#body.igAutoRows + 1] = row
        end
    end

    -- SETLESS GEAR and ITEMS, section by section (IG.AUTOMATE_LAYOUT, Classify.lua).
    for _, tab in ipairs({ "GEAR", "ITEMS" }) do
        for index, section in ipairs(IG.AutomateSections and IG.AutomateSections(tab) or {}) do
            Section(tab, section.title, index == 1)
            Rows(tab, section.lines)
        end
    end
    if IG.AUTOMATE_REPAIR then
        local repair = {}
        for _, rule in ipairs(IG.AUTOMATE_REPAIR) do
            local key = rule.key
            repair[#repair + 1] = {
                key = key, name = rule.name, description = rule.description, pick = rule.pick,
                get = function() return IG.RepairGet(key) end,
                set = function(value) IG.RepairSet(key, value) end,
            }
        end
        Rows("REPAIR", repair)
    end

    -- Under the sorting tabs: the warning, plain red words, and the two buttons that do something
    -- to your items (IG.AUTOMATE_ACTIONS, Classify.lua). A press takes the next answer: Off, Ask
    -- First, On.
    local warn = AutoLabel(body, AUTO_WARN_FONT)
    warn:SetColor(IG.HexToRGB(AUTO_WARN_COLOR))
    warn:SetText("USE AT YOUR OWN RISK")
    warn:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    warn:SetHeight(AUTO_WARN_HEIGHT)
    Add("BOTTOM", warn, AUTO_SECTION_GAP + 6)

    for index, action in ipairs(IG.AUTOMATE_ACTIONS or {}) do
        local key, which = action.key, action.which
        local button = AutoBox(body)
        button:SetHeight(AUTO_ACTION_HEIGHT)
        button.name = AutoLabel(button, AUTO_ACTION_FONT)
        button.name:SetText(action.button)
        button.name:SetAnchor(LEFT, button, LEFT, 10, 0)
        button.name:SetDrawLayer(DL_CONTROLS)
        button.state = AutoLabel(button, AUTO_ACTION_STATE_FONT)
        button.state:SetAnchor(RIGHT, button, RIGHT, -10, 0)
        button.state:SetDrawLayer(DL_CONTROLS)
        button.igWhich = which
        button:SetHandler("OnMouseEnter", function(self)
            self.igHovered = true
            PaintActionButtons(body)
            InitializeTooltip(InformationTooltip, self, RIGHT, -8, 0)
            SetTooltipText(InformationTooltip, action.description)
        end)
        button:SetHandler("OnMouseExit", function(self)
            self.igHovered = false
            PaintActionButtons(body)
            ClearTooltip(InformationTooltip)
        end)
        button:SetHandler("OnMouseUp", function(_, _, upInside)
            if not upInside or not IG.sv then return end
            PlaySound(SOUNDS.DEFAULT_CLICK)
            local values, at = IG.ACTION_PICK.values, 1
            for position, answer in ipairs(values) do
                if answer == IG.ActionMode(which) then at = position end
            end
            IG.sv[key] = values[at % #values + 1]
            PaintActionButtons(body)
            -- SELL and DECONSTRUCT carry a tag while their action is on.
            IG.RefreshLists()
            if IG.RefreshSettingsPanel then IG.RefreshSettingsPanel() end
        end)
        body.igActionButtons[#body.igActionButtons + 1] = button
        Add("BOTTOM", button, index == 1 and 4 or AUTO_ACTION_GAP)
    end

    ShowAutoTab(body)
    IG.RefreshAutomateDrawer(body)
end

function IG.RefreshAutomateDrawer(body)
    if not (body and body.igAutoRows) then return end
    -- The drawer's width is only known once it is laid out; fit the tabs again on each refresh.
    if body.igAutoTabs then
        FitAutoTabs(body)
        PaintAutoTabs(body)
    end
    PaintActionButtons(body)
    for _, row in ipairs(body.igAutoRows) do
        local rule = row.igRule
        local text = RuleText(rule)
        row.state:SetText(text)
        row.state:SetColor(IG.HexToRGB(RuleLit(rule) and AUTO_ON or AUTO_OFF))
    end
end

---------------------------------------------------------------------------
-- The MODULES drawer's page
---------------------------------------------------------------------------

-- Every module with a switch of its own, in the order the categories stand in (IG.GROUPS), read
-- from IG.MODULE_GROUPS rather than written out here, so a new module is a line without more.
-- LOCKED is left out: its answer is per list (the padlock on each list's toolbar), not one switch.
function IG.ModuleSwitches()
    local list = {}
    local flags = IG.MODULE_GROUPS or {}
    for _, group in ipairs(IG.GROUPS or {}) do
        local flag = flags[group.key]
        if flag and group.key ~= "LOCKED" then
            list[#list + 1] = { key = group.key, flag = flag }
        end
    end
    return list
end

-- A module that listens to the game all session long (IG.MODULE_APPLY: [sv flag] = function(on))
-- registers itself here instead of registering unconditionally at load -- so a switch left off
-- is not still paying for events it throws away inside its own callback. Called once at load
-- (IG.ApplyAllModuleEvents, after the Global Switch's own check) and again every time the switch
-- itself moves, below.
function IG.ApplyAllModuleEvents()
    if not (IG.sv and IG.MODULE_APPLY) then return end
    for flag, apply in pairs(IG.MODULE_APPLY) do
        apply(IG.sv[flag] == true)
    end
end

-- The one way a module is switched from the drawer and from its settings category alike: the
-- saved flag, the classify cache emptied, the lists rebuilt, the other page caught up.
function IG.SetModuleEnabled(flag, value)
    if not IG.sv then return end
    IG.sv[flag] = value == true
    if IG.MODULE_APPLY and IG.MODULE_APPLY[flag] and IG.IsEnabled() then
        IG.MODULE_APPLY[flag](IG.sv[flag])
    end
    IG.ClearClassifyCache()
    IG.RefreshLists()
    if IG.RefreshSettingsPanel then IG.RefreshSettingsPanel() end
    if IG.RefreshOpenDrawer then IG.RefreshOpenDrawer() end
end

-- A switch that does something other than turn its module off says so in its own words.
local SWITCH_NOTES = {
    TOBANK = "Shows or hides the TO BANK button. Marking pieces from the right click menu and "
        .. "putting them in the bank when it opens work either way.",
}

function IG.BuildModulesDrawer(body)
    body.igAutoRows = {}
    local previous
    for _, module in ipairs(IG.ModuleSwitches()) do
        local key, flag = module.key, module.flag
        local label = IG.GetGroupLabel(key)
        local group = IG.GROUP_BY_KEY[key]
        local row = AutoRow(body, {
            name = label,
            description = SWITCH_NOTES[key] or ("Switches the " .. label .. " module on or off. "
                .. "The same switch as its category under Modules in the settings."),
            icon = (IG.MODULE_ICONS and IG.MODULE_ICONS[key]) or (group and group.icon),
            color = IG.GetGroupColor(key),
            get = function() return IG.sv and IG.sv[flag] == true end,
            set = function(value) IG.SetModuleEnabled(flag, value) end,
        })
        if previous then
            row:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 2)
            row:SetAnchor(TOPRIGHT, previous, BOTTOMRIGHT, 0, 2)
        else
            row:SetAnchor(TOPLEFT, body, TOPLEFT, 0, 0)
            row:SetAnchor(TOPRIGHT, body, TOPRIGHT, 0, 0)
        end
        previous = row
        body.igAutoRows[#body.igAutoRows + 1] = row
    end
    IG.RefreshAutomateDrawer(body)
end
