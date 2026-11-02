InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- Look of the grouped list: dark glassy header surfaces with a thin colored outline and accent,
-- drawn piece by piece on each list row. A top-level group's header draws the top edge of its
-- frame, rows inside draw the sides (plus a faint tinted surface), and its last row the bottom edge.

local THICKNESS = 1
local FRAME_ALPHA = 0.5            -- top-level group outline
local NESTED_FRAME_ALPHA = 0.35    -- outlines of sub-groups and sets
local FRAME_COLOR_STRENGTH = 0.75  -- outline color: this much group color, the rest dark surface
local ACCENT_WIDTH = 3              -- colored strip on the left of a header
local TOP_ACCENT_EXPANDED = 6       -- open top-level group: strip runs down the whole group
-- An open sub-group's strip (down its left and along its foot). Kept thinner than the top-level
-- one: it belongs to a smaller thing, so it must not out-shout the group it lives in.
local SUB_ACCENT_EXPANDED = 4
local ACCENT_GAP = 4                -- space between the thickest strip and the +/- marker
local SUB_INDENT = 14               -- how far each sub-level header is pushed in
local LEAF_EXTRA_INDENT = 68        -- set headers are pushed in this much more; up to three role markers sit in the gap
local WIDE_EXTRA_INDENT = 34        -- the other deepest headers (house chests, Armory loadouts, "Poisons"...)
local ROLE_AREA_GAP = 3             -- air between the accent bar, the role markers and the set name
local SUB_VERTICAL_GAP = 3          -- empty space above and below every sub-level header surface,
                                    -- so the space between any two of them is always twice this
local OUTLINE_GAP = 2               -- every outline keeps this much air around what it wraps, on all sides
local NESTED_RIGHT_INSET = 3        -- nested frames sit just inside the top-level frame on the right
local CONTENT_TINT = 0.16           -- how much of the group color tints the surface inside an open group
local CONTENT_ALPHA = 0.69 -- the ground inside an open group, a touch stronger than it was

-- Neutral dark surfaces the group colors are mixed into.
local SURFACE_TOP = { 0.07, 0.075, 0.09 }
local SURFACE_SUB = { 0.11, 0.115, 0.13 }

-- "Black surfaces": ink instead of tinted glass. Not quite black, and not quite opaque, so the
-- world behind still shows as a shadow rather than disappearing behind a flat panel.
local INK = { 0.017, 0.017, 0.024 }
local INK_LIFT = 0.12 -- an open group's surface is lifted this much of its tint, so open still reads as open

-- One of the Visuals switches. Anything not written yet counts as on, so a fresh save looks the
-- way the addon always has.
local function On(key)
    return not IG.sv or IG.sv[key] ~= false
end

-- For switches that are off until someone turns them on.
local function Enabled(key)
    return IG.sv ~= nil and IG.sv[key] == true
end

local function Mix(color, surface, amount)
    local r, g, b = IG.HexToRGB(color)
    return surface[1] + (r - surface[1]) * amount,
           surface[2] + (g - surface[2]) * amount,
           surface[3] + (b - surface[3]) * amount
end

-- Strips (the colored bars down the left of a group and along its foot) all carry their group's
-- color, but those colors are nowhere near equally bright: the same width of gold reads as a lit
-- line where purple reads as an edge. Worse, the game scales the interface up, and a bright edge
-- against a dark one overshoots -- gold overshoots past white and leaves a pale halo running down
-- the strip. Holding every strip to one weight keeps the colors and loses the halo.
local STRIP_LUMA = 0.65

local function StripColor(hex)
    local r, g, b = IG.HexToRGB(hex)
    local luma = 0.299 * r + 0.587 * g + 0.114 * b
    if luma <= STRIP_LUMA then return r, g, b end
    local scale = STRIP_LUMA / luma
    return r * scale, g * scale, b * scale
end

local function NewTexture(parent, drawLevel)
    local texture = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    texture:SetDrawLevel(drawLevel)
    texture:SetHidden(true)
    return texture
end

-- Surfaces (group fill, header fill, role area) go on the background layer, under text, icons
-- and lines.
local function NewSurface(parent, drawLevel)
    local texture = NewTexture(parent, drawLevel)
    texture:SetDrawLayer(DL_BACKGROUND)
    return texture
end

---------------------------------------------------------------------------
-- Header surface
---------------------------------------------------------------------------

-- tint: how much of the group color goes into the surface. base: optional { r, g, b } surface
-- to mix into instead of the default dark blue-grey.
function IG.GetHeaderSurfaceColor(depth, color, tint, alpha, base)
    if Enabled("blackSurfaces") then
        local lift = tint * INK_LIFT
        return { INK[1] + lift, INK[2] + lift, INK[3] + lift, alpha }
    end
    local r, g, b = Mix(color, base or (depth > 1 and SURFACE_SUB or SURFACE_TOP), tint)
    return { r, g, b, alpha }
end

-- How far a header's surface is pushed in from the row's left edge. kind: "set" reserves the
-- strip the role markers live in, "wide" is the smaller step the innermost sub-groups share
-- (house chests, Armory loadouts, "Poisons" and the like), nil is a plain sub-group.
local function HeaderIndent(depth, kind)
    if depth == 1 then return THICKNESS end
    local extra = 0
    if kind == "set" then extra = LEAF_EXTRA_INDENT
    elseif kind == "wide" then extra = WIDE_EXTRA_INDENT end
    return THICKNESS + (depth - 1) * SUB_INDENT + extra
end
IG.HeaderIndent = HeaderIndent

local function ExpandedAccentWidth(depth)
    return depth == 1 and TOP_ACCENT_EXPANDED or SUB_ACCENT_EXPANDED
end

-- How wide the colored strip on a header's left is. Sets keep the thin one whatever happens:
-- their whole surface already carries their color, and three strips of three depths beside each
-- other is noise. The others grow when they are open.
local function AccentWidth(depth, isSet, expanded)
    if isSet then return ACCENT_WIDTH end
    return expanded and ExpandedAccentWidth(depth) or ACCENT_WIDTH
end

-- The room a header always keeps for its strip, open or closed, so its content never shifts.
local function AccentReserve(depth, isSet)
    return isSet and ACCENT_WIDTH or ExpandedAccentWidth(depth)
end

-- Paints one texture with a left-to-right blend between two colors (one color: a flat fill).
local function PaintSpan(texture, left, right)
    texture:SetVertexColors(VERTEX_POINTS_TOPLEFT, unpack(left))
    texture:SetVertexColors(VERTEX_POINTS_BOTTOMLEFT, unpack(left))
    texture:SetVertexColors(VERTEX_POINTS_TOPRIGHT, unpack(right))
    texture:SetVertexColors(VERTEX_POINTS_BOTTOMRIGHT, unpack(right))
end

-- A header with several colors gives each one an equal stretch of its width and hands over in a
-- short band between them, instead of blending the whole way across. A long blend washes every
-- color out, and with three of them nothing is left to recognise.
-- BLEND_SHARE is how much of one color's stretch the hand-over takes.
local BLEND_SHARE = 0.55

-- The pieces of a surface with N colors: a flat block per color, a blend band between each pair.
-- Each piece is { from, to } in 0..1 of the surface width, plus the stops it blends between.
local function SurfaceLayout(count)
    if count < 2 then return { { from = 0, to = 1, left = 1, right = 1 } } end
    local layout = {}
    local share = 1 / count
    local half = share * BLEND_SHARE / 2
    for i = 1, count do
        local blockFrom = (i == 1) and 0 or ((i - 1) * share + half)
        local blockTo = (i == count) and 1 or (i * share - half)
        layout[#layout + 1] = { from = blockFrom, to = blockTo, left = i, right = i }
        if i < count then
            layout[#layout + 1] = { from = i * share - half, to = i * share + half, left = i, right = i + 1 }
        end
    end
    return layout
end

-- Repaints the surface in the given colors, keeping the layout the header was built with.
function IG.SetHeaderSurface(row, stops)
    local bg = row.igBg
    if not bg or not stops or not bg.layout then return end
    row.igStops = stops
    for i, piece in ipairs(bg.layout) do
        local fill = bg.fills[i]
        if fill then
            PaintSpan(fill, stops[piece.left] or stops[1], stops[piece.right] or stops[1])
        end
    end
end

-- How far a top-level header's surface stops short of the row's right edge. The section strip
-- (ModuleStrip.lua) lines its buttons up with the same two edges.
IG.TOP_PLATE_RIGHT_INSET = THICKNESS

-- left: where the header's surface starts, from IG.HeaderIndent.
-- drawDepth: the level it is drawn at when that is not its own (a top-level right edge at 1).
function IG.ApplyHeaderBackground(row, depth, isLeaf, isSet, left, stops, accentColor, expanded, drawDepth)
    local bg = row.igBg
    if not bg then
        bg = { fills = { NewSurface(row, 1) }, accent = NewTexture(row, 2) }
        bg.fill = bg.fills[1] -- the first piece is also the anchor for the accent bar
        row.igBg = bg
    end
    -- One piece per flat block and one per hand-over band; only made when a header first needs it.
    local layout = SurfaceLayout(#stops)
    bg.layout = layout
    for i = #bg.fills + 1, #layout do bg.fills[i] = NewSurface(row, 1) end
    local right = -IG.TOP_PLATE_RIGHT_INSET
    if (drawDepth or depth) > 1 then
        -- Every depth ends on the same line: nested surfaces stepping in a few pixels each made
        -- the right edge look like a staircase.
        local _, frameRight = IG.FrameSides(2) -- defined further down with the frame code
        right = frameRight - THICKNESS - OUTLINE_GAP
    end
    -- The same gap above and below every sub-level surface. The strip on the left is anchored
    -- separately and still runs to the row's bottom when the group is open.
    local bottom = depth > 1 and -SUB_VERTICAL_GAP or 0

    local top = depth > 1 and SUB_VERTICAL_GAP or THICKNESS
    local width = row:GetWidth() + right - left
    local surfacesOn = On("headerSurfaces")
    for i, fill in ipairs(bg.fills) do
        local piece = layout[i]
        if piece then
            fill:ClearAnchors()
            fill:SetAnchor(TOPLEFT, row, TOPLEFT, left + zo_round(piece.from * width), top)
            if piece.to >= 1 then
                fill:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, right, bottom)
            else
                fill:SetAnchor(BOTTOMRIGHT, row, BOTTOMLEFT, left + zo_round(piece.to * width), bottom)
            end
        end
        fill:SetHidden(piece == nil or not surfacesOn)
    end

    bg.accent:ClearAnchors()
    bg.accent:SetAnchor(TOPLEFT, bg.fill, TOPLEFT)
    -- An open non-set sub-group's strip runs to the row's bottom, joining the strip below it.
    if expanded and depth > 1 and not isLeaf then
        bg.accent:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, left, 0)
    else
        bg.accent:SetAnchor(BOTTOMLEFT, bg.fill, BOTTOMLEFT)
    end
    bg.accent:SetWidth(AccentWidth(depth, isSet, expanded))
    bg.accent:SetColor(StripColor(accentColor))
    bg.accent:SetHidden(not On("accentStrips"))

    IG.SetHeaderSurface(row, stops)
end

-- The area left of a set header, where its role markers sit. bgColor nil hides it.
function IG.ApplyRoleBackground(row, depth, bgColor, expanded)
    local roleBg = row.igRoleBg
    if not bgColor or not On("headerSurfaces") then
        if roleBg then roleBg:SetHidden(true) end
        return
    end
    if not roleBg then
        roleBg = NewSurface(row, 1)
        row.igRoleBg = roleBg
    end
    roleBg:ClearAnchors()
    roleBg:SetAnchor(TOPLEFT, row, TOPLEFT, HeaderIndent(depth), SUB_VERTICAL_GAP)
    -- Same gap as the surface it belongs to, open or closed.
    roleBg:SetAnchor(BOTTOMRIGHT, row, BOTTOMLEFT, HeaderIndent(depth, "set"), -SUB_VERTICAL_GAP)
    roleBg:SetColor(unpack(bgColor))
    roleBg:SetHidden(false)
end



-- Left edge of a header's content (marker), matching its surface.
function IG.HeaderContentOffset(depth, left, isSet)
    return left + AccentReserve(depth, isSet) + ACCENT_GAP
end

---------------------------------------------------------------------------
-- Group frames: every header is outlined, and an open group's outline runs down around
-- everything inside it. Each row draws its own piece of every frame it belongs to:
-- the group's header row the top edge, rows inside the sides, the group's last row the bottom.
---------------------------------------------------------------------------

local MAX_FRAMES = 3
local BOLD_THICKNESS = 2         -- outline of an open set
-- One nesting step: a child frame sits this far inside its parent's frame (gap + line),
-- on the right and at the bottom, matching the gap below the parent's header.
local NEST_STEP = OUTLINE_GAP + THICKNESS
local NESTED_BOTTOM_STEP = NEST_STEP

-- Horizontal extent of a group's frame (offsets from the row's left and right edges).
local function FrameSides(depth)
    if depth == 1 then return 0, 0 end
    return HeaderIndent(depth) - OUTLINE_GAP - THICKNESS, -(NESTED_RIGHT_INSET + (depth - 2) * NEST_STEP)
end
IG.FrameSides = FrameSides

-- A closing group can end its frame inside the small spacer row that follows it, a few pixels
-- down from the spacer's top, which leaves a gap before the next header.
local SPACER_BOTTOM_LINE_Y = 0

-- Left edge (and width) of the strip that runs down an open non-set sub-group.
local function SubBarLeft(depth)
    return HeaderIndent(depth)
end

-- The four edges are made up front; the extra pieces (lower halves around a status icon, the open
-- sub-group strip) only when a row first needs them, to keep list scrolling light.
local function CreateFramePieces(row)
    local pieces = { row = row }
    for _, name in ipairs({ "left", "right", "top", "bottom" }) do
        pieces[name] = NewTexture(row, 10)
    end
    return pieces
end

local function Piece(pieces, name)
    local texture = pieces[name]
    if not texture then
        texture = NewTexture(pieces.row, name:find("bar") and 2 or 10)
        pieces[name] = texture
    end
    return texture
end

local function HidePieces(pieces)
    for name, texture in pairs(pieces) do
        if name ~= "row" then texture:SetHidden(true) end
    end
end

-- Draws a vertical strip from topY to bottomY (bottomY measured up from the row's bottom).
-- If it runs through the gap box, it's drawn as two halves: above the box and below it.
local function DrawVertical(row, pieces, upperName, lowerName, x, width, topY, bottomY, gap)
    local upper = Piece(pieces, upperName)
    local lower = pieces[lowerName]
    upper:ClearAnchors()
    upper:SetWidth(width)
    upper:SetHidden(false)
    local splits = gap and x + width > gap.left and x < gap.right
        and topY < gap.top and row:GetHeight() - bottomY > gap.bottom
    if splits then
        lower = Piece(pieces, lowerName)
        upper:SetAnchor(TOPLEFT, row, TOPLEFT, x, topY)
        upper:SetAnchor(BOTTOMLEFT, row, TOPLEFT, x, gap.top)
        lower:ClearAnchors()
        lower:SetWidth(width)
        lower:SetAnchor(TOPLEFT, row, TOPLEFT, x, gap.bottom)
        lower:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, x, -bottomY)
        lower:SetHidden(false)
    else
        upper:SetAnchor(TOPLEFT, row, TOPLEFT, x, topY)
        upper:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, x, -bottomY)
        if lower then lower:SetHidden(true) end
    end
end

-- An open sub-group ends in a foot: its thick left strip turns the corner and runs along the
-- bottom of the group, solid at first and fading out before it reaches the right edge.
-- The foot has a row of its own, whose height comes from the density setting.
local FOOT_SOLID_SHARE = 0.35   -- how much of the foot's length is drawn solid before it fades

local function DrawFoot(row, pieces, info, x, right, bottomY)
    local solid, fade = Piece(pieces, "barFoot"), Piece(pieces, "barFootFade")
    local span = row:GetWidth() + right - x
    local solidWidth = zo_round(span * FOOT_SOLID_SHARE)
    local r, g, b = StripColor(info.color)

    solid:ClearAnchors()
    solid:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, x, -bottomY)
    solid:SetDimensions(solidWidth, SUB_ACCENT_EXPANDED)
    solid:SetColor(r, g, b, 1)
    solid:SetHidden(false)

    fade:ClearAnchors()
    fade:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, x + solidWidth, -bottomY)
    fade:SetDimensions(span - solidWidth, SUB_ACCENT_EXPANDED)
    fade:SetVertexColors(VERTEX_POINTS_TOPLEFT, r, g, b, 1)
    fade:SetVertexColors(VERTEX_POINTS_BOTTOMLEFT, r, g, b, 1)
    fade:SetVertexColors(VERTEX_POINTS_TOPRIGHT, r, g, b, 0)
    fade:SetVertexColors(VERTEX_POINTS_BOTTOMRIGHT, r, g, b, 0)
    fade:SetHidden(false)
end

local function HideFoot(pieces)
    if pieces.barFoot then pieces.barFoot:SetHidden(true) end
    if pieces.barFootFade then pieces.barFootFade:SetHidden(true) end
end

local function thicknessFor(info)
    return info.bold and BOLD_THICKNESS or THICKNESS
end

-- info: { depth, color, top = this row is the group's header, bottom = the group ends on this row,
--         bottomInSpacer = it ends inside this spacer row, showBar = draw the open sub-group strip }
local function DrawFrame(row, pieces, info, gap)
    local framesOn, stripsOn = On("frames"), On("accentStrips")
    local depth = info.depth
    local left, right = FrameSides(depth)
    local rowHeight = row:GetHeight()

    -- Sub-level headers leave a small gap above and below their surface; the outline hugs it.
    local headerGap = depth > 1 and (SUB_VERTICAL_GAP - OUTLINE_GAP - THICKNESS) or 0
    local topY = info.top and headerGap or 0
    local bottomY = 0
    if info.bottomInSpacer then
        bottomY = rowHeight - SPACER_BOTTOM_LINE_Y - thicknessFor(info)
    elseif info.bottom and info.closesBeforeSpacer then
        -- Its parent ends just below, in the spacer: leave the usual gap above the parent's line.
        bottomY = OUTLINE_GAP + info.closesBeforeSpacer * NEST_STEP
    elseif info.bottom then
        bottomY = info.top and headerGap or (depth - 1) * NESTED_BOTTOM_STEP
    end

    -- A soft tone of the group color: blended toward the surface and kept translucent,
    -- so outlines read as a quiet edge rather than a drawn box. Nested frames are quieter still.
    local r, g, b = Mix(info.color, SURFACE_TOP, FRAME_COLOR_STRENGTH)
    local alpha = depth == 1 and FRAME_ALPHA or NESTED_FRAME_ALPHA
    local thickness = info.bold and BOLD_THICKNESS or THICKNESS
    -- A group can give its header row its own outline (see HEADER_STYLES).
    local style = info.top and info.style
    if style then
        r, g, b, alpha = unpack(style.outline)
        thickness = style.outlineThickness
    end
    for name, texture in pairs(pieces) do
        if name == "row" then
            -- not a texture
        elseif name:find("bar") then
            texture:SetColor(StripColor(info.color))
        else
            texture:SetColor(r, g, b, alpha)
        end
    end

    DrawVertical(row, pieces, "left", "leftLow", left, thickness, topY, bottomY, gap)
    if pieces.leftLow then pieces.leftLow:SetColor(r, g, b, alpha) end
    if not framesOn then
        pieces.left:SetHidden(true)
        if pieces.leftLow then pieces.leftLow:SetHidden(true) end
    end

    pieces.right:ClearAnchors()
    pieces.right:SetWidth(thickness)
    pieces.right:SetAnchor(TOPRIGHT, row, TOPRIGHT, right, topY)
    pieces.right:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, right, -bottomY)
    pieces.right:SetHidden(not framesOn)

    pieces.top:ClearAnchors()
    pieces.top:SetHeight(thickness)
    pieces.top:SetAnchor(TOPLEFT, row, TOPLEFT, left, topY)
    pieces.top:SetAnchor(TOPRIGHT, row, TOPRIGHT, right, topY)
    pieces.top:SetHidden(not (info.top and framesOn))

    pieces.bottom:ClearAnchors()
    pieces.bottom:SetHeight(thickness)
    pieces.bottom:SetAnchor(TOPLEFT, row, BOTTOMLEFT, left, -bottomY - thickness)
    pieces.bottom:SetAnchor(TOPRIGHT, row, BOTTOMRIGHT, right, -bottomY - thickness)
    pieces.bottom:SetHidden(not (info.bottom and framesOn))

    -- An open sub-group (not a set) keeps its thick left strip running down to its last row.
    if info.showBar and not info.top and stripsOn then
        -- On the foot row the strip stops a gap above the group's bottom line, where it turns.
        local barBottom = bottomY
        if info.foot then barBottom = bottomY + (info.bottom and thickness or 0) + OUTLINE_GAP end
        DrawVertical(row, pieces, "bar", "barLow", SubBarLeft(depth), SUB_ACCENT_EXPANDED, 0, barBottom, gap)
        -- New pieces are made white; give them the strip color.
        pieces.bar:SetColor(StripColor(info.color))
        if pieces.barLow then pieces.barLow:SetColor(StripColor(info.color)) end
        if info.foot then
            DrawFoot(row, pieces, info, SubBarLeft(depth) + SUB_ACCENT_EXPANDED,
                right - thickness - OUTLINE_GAP, barBottom)
        else
            HideFoot(pieces)
        end
    else
        if pieces.bar then pieces.bar:SetHidden(true) end
        if pieces.barLow then pieces.barLow:SetHidden(true) end
        HideFoot(pieces)
    end
end

-- Boxes around things on an item row (status icon, trait/transmute icon, price...): a bolder
-- outline than the group frames, in the tone of the innermost group.
local BOX_THICKNESS = 2
local BOX_ALPHA = 0.55

-- A box is a container with four edges inside it. The side edges stop short of the top and
-- bottom edges, so corners aren't drawn twice (overlapping translucent edges look solid).
local function CreateBox(parent)
    local box = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    box.edges = {}
    for i = 1, 4 do
        box.edges[i] = WINDOW_MANAGER:CreateControl(nil, box, CT_TEXTURE)
        box.edges[i]:SetDrawLevel(10)
    end
    local top, bottom, left, right = unpack(box.edges)
    top:SetAnchor(TOPLEFT, box, TOPLEFT)
    top:SetAnchor(TOPRIGHT, box, TOPRIGHT)
    top:SetHeight(BOX_THICKNESS)
    bottom:SetAnchor(BOTTOMLEFT, box, BOTTOMLEFT)
    bottom:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT)
    bottom:SetHeight(BOX_THICKNESS)
    left:SetAnchor(TOPLEFT, box, TOPLEFT, 0, BOX_THICKNESS)
    left:SetAnchor(BOTTOMLEFT, box, BOTTOMLEFT, 0, -BOX_THICKNESS)
    left:SetWidth(BOX_THICKNESS)
    right:SetAnchor(TOPRIGHT, box, TOPRIGHT, 0, BOX_THICKNESS)
    right:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT, 0, -BOX_THICKNESS)
    right:SetWidth(BOX_THICKNESS)
    return box
end

local function ShowBox(box, info)
    local r, g, b = Mix(info.color, SURFACE_TOP, FRAME_COLOR_STRENGTH)
    for _, edge in ipairs(box.edges) do edge:SetColor(r, g, b, BOX_ALPHA) end
    box:SetHidden(false)
end

-- Box filling the gap bounds (row pixels), where the frame lines were cut.
local function DrawGapBox(row, gap, info)
    local box = row.igGapBox
    if not gap or not info then
        if box then box:SetHidden(true) end
        return
    end
    if not box then
        box = CreateBox(row)
        row.igGapBox = box
    end
    box:ClearAnchors()
    box:SetAnchor(TOPLEFT, row, TOPLEFT, gap.left, gap.top)
    box:SetDimensions(gap.right - gap.left, gap.bottom - gap.top)
    ShowBox(box, info)
end

-- frames: the frames this row is part of, outermost first.
-- withFill: rows below an open top-level group's header get its tinted surface and left strip.
-- gap: optional { left, top, right, bottom } box (in row pixels) that vertical lines step around.
function IG.ApplyFrames(row, frames, withFill, gap)
    row.igFramePieces = row.igFramePieces or {}
    local crossesGap = false
    for i = 1, MAX_FRAMES do
        local info = frames and frames[i]
        local pieces = row.igFramePieces[i]
        if info then
            if not pieces then
                pieces = CreateFramePieces(row)
                row.igFramePieces[i] = pieces
            end
            DrawFrame(row, pieces, info, gap)
            if gap and info.depth > 1 then crossesGap = true end
        elseif pieces then
            HidePieces(pieces)
        end
    end
    -- Only frame the gap when some line actually had to step around it.
    DrawGapBox(row, crossesGap and gap or nil, On("frames") and IG.GetBoxFrame(frames) or nil)

    -- Top-level group extras: tinted surface and the continuous left strip.
    local outer = frames and frames[1]
    -- The first row under a Chips/Tiles row carries the block's top edge but is inside it.
    local inside = outer and outer.depth == 1 and (not outer.top or outer.stripTop)
    if not row.igGroupSurface then
        row.igGroupSurface = { fill = NewSurface(row, 0), bar = NewTexture(row, 2) }
        row.igGroupSurface.fill:SetAnchorFill(row)
        row.igGroupSurface.bar:SetAnchor(TOPLEFT, row, TOPLEFT, THICKNESS, 0)
        row.igGroupSurface.bar:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, THICKNESS, 0)
        row.igGroupSurface.bar:SetWidth(TOP_ACCENT_EXPANDED)
    end
    local surface = row.igGroupSurface
    if inside then
        local fr, fg, fb = Mix(outer.color, SURFACE_TOP, CONTENT_TINT)
        if Enabled("blackSurfaces") then fr, fg, fb = INK[1], INK[2], INK[3] end
        surface.fill:SetColor(fr, fg, fb, CONTENT_ALPHA)
        surface.bar:SetColor(StripColor(outer.color))
    end
    surface.fill:SetHidden(not (inside and withFill and On("groupSurface")))
    surface.bar:SetHidden(not (inside and On("accentStrips")))
end

-- A Chips/Tiles row with an open button: the open block's left strip starts here, level with
-- the top of the open button, at the x and width the rows below draw it, and runs to the row's
-- bottom so it joins the first row under the buttons. A thin line of the same colour ties the
-- strip to the open button's left edge. topY and chipLeft are row pixels; nil color hides both.
-- linkY: where the link to the open button runs (defaults to topY).
function IG.ApplyStripRail(row, color, topY, chipLeft, linkY)
    local rail = row.igStripRail
    if not rail then
        rail = { bar = NewTexture(row, 2), link = NewTexture(row, 2) }
        row.igStripRail = rail
    end
    if not color or not On("accentStrips") then
        rail.bar:SetHidden(true)
        rail.link:SetHidden(true)
        return
    end
    local r, g, b = StripColor(color)
    rail.bar:ClearAnchors()
    rail.bar:SetAnchor(TOPLEFT, row, TOPLEFT, THICKNESS, topY)
    rail.bar:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, THICKNESS, 0)
    rail.bar:SetWidth(TOP_ACCENT_EXPANDED)
    rail.bar:SetColor(r, g, b, 1)
    rail.bar:SetHidden(false)
    local linkLeft = THICKNESS + TOP_ACCENT_EXPANDED
    local linkWidth = chipLeft - linkLeft
    rail.link:ClearAnchors()
    rail.link:SetAnchor(TOPLEFT, row, TOPLEFT, linkLeft, linkY or topY)
    rail.link:SetDimensions(zo_max(linkWidth, 0), 2)
    rail.link:SetColor(r, g, b, 0.6)
    rail.link:SetHidden(linkWidth <= 0)
end

-- Where the item row's status icon (lock, equipped, new...) goes, and the box lines step around.
-- The box (padding + thickness on each side) fits between the group's left strip and the item icon.
local STATUS_ICON_SIZE = 32
local STATUS_ICON_TOP = 10
local GAP_PADDING = 1
local GAP_OUTSET = GAP_PADDING + BOX_THICKNESS
IG.STATUS_ICON_LEFT = THICKNESS + TOP_ACCENT_EXPANDED + 2 + GAP_OUTSET

local STATUS_ICON_GAP = {
    left = IG.STATUS_ICON_LEFT - GAP_OUTSET,
    top = STATUS_ICON_TOP - GAP_OUTSET,
    right = IG.STATUS_ICON_LEFT + STATUS_ICON_SIZE + GAP_OUTSET,
    bottom = STATUS_ICON_TOP + STATUS_ICON_SIZE + GAP_OUTSET,
}

function IG.GetStatusIconGap()
    return STATUS_ICON_GAP
end

-- Height shared by every box on an item row.
IG.BOX_HEIGHT = STATUS_ICON_SIZE + GAP_OUTSET * 2
-- Boxes on item rows take the color of the middle group (e.g. "DLC Dungeon Sets"), or the
-- top-level group when there is no middle one.
function IG.GetBoxFrame(frames)
    return frames and (frames[2] or frames[1])
end

-- A small text label in a thin outlined box, like a tooltip (the Shift hint, "saved ... ago").
local TEXT_BOX_PADDING_X = 6
local TEXT_BOX_PADDING_Y = 3

function IG.CreateTextBox(parent, color, font)
    local box = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    box:SetDrawLevel(20)
    box.label = WINDOW_MANAGER:CreateControl(nil, box, CT_LABEL)
    box.label:SetFont(font)
    box.label:SetAnchor(CENTER, box, CENTER)
    box.label:SetDrawLevel(21)
    box.edges = {}
    for _, points in ipairs({ { TOPLEFT, TOPRIGHT }, { BOTTOMLEFT, BOTTOMRIGHT }, { TOPLEFT, BOTTOMLEFT }, { TOPRIGHT, BOTTOMRIGHT } }) do
        local edge = WINDOW_MANAGER:CreateControl(nil, box, CT_TEXTURE)
        edge:SetAnchor(points[1], box, points[1])
        edge:SetAnchor(points[2], box, points[2])
        edge:SetDrawLevel(21)
        box.edges[#box.edges + 1] = edge
    end
    box.edges[1]:SetHeight(1); box.edges[2]:SetHeight(1); box.edges[3]:SetWidth(1); box.edges[4]:SetWidth(1)
    local r, g, b = unpack(color)
    box.label:SetColor(r, g, b, 1)
    for _, edge in ipairs(box.edges) do edge:SetColor(r, g, b, 0.8) end
    return box
end

function IG.SetTextBoxText(box, text)
    box.label:SetText(text)
    box:SetDimensions(box.label:GetTextWidth() + TEXT_BOX_PADDING_X * 2, box.label:GetTextHeight() + TEXT_BOX_PADDING_Y * 2)
end

-- Middle of the extra gap to the left of the deepest headers, where set role icons go.
-- The strip a set's role markers live in: left edge past the header's accent bar (so they never
-- sit on it, open or closed), right edge just before the name. Returns left and width.
function IG.RoleArea(depth)
    local left = HeaderIndent(depth) + AccentReserve(depth, true) + ROLE_AREA_GAP
    return left, HeaderIndent(depth, "set") - ROLE_AREA_GAP - left
end


---------------------------------------------------------------------------
-- Light sweep animation (driven per frame, so it survives list refreshes)
---------------------------------------------------------------------------

local SHIMMER_WIDTH = 230
local SWEEP_MS = 2000
local CYCLE_MS = 3800
local SHIMMER_ALPHA = 0.55
-- Pulse fills the header and breathes; Trace sends a short light around its edge.
local PULSE_MS = 2600
local TRACE_MS = 3400
local TRACE_LENGTH = 70
local TRACE_THICKNESS = 3
-- How much longer a cycle takes at each speed.
local SPEED_FACTOR = { slow = 1.8, normal = 1, fast = 0.6 }
-- The game's soft round glow (used to flash inventory tabs); stretched sideways it becomes
-- a light band whose edges already fade out on their own.
local SHIMMER_TEXTURE = "EsoUI/Art/Miscellaneous/icon_highlight_pulse.dds"

local function CreateShimmer(row)
    local band = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    band:SetTexture(SHIMMER_TEXTURE)
    -- Only a thin horizontal strip through the middle of the round glow: it still fades out
    -- to the left and right, but stays evenly bright from top to bottom.
    band:SetTextureCoords(0, 1, 0.47, 0.53)
    band:SetDimensions(SHIMMER_WIDTH, 10)
    band:SetBlendMode(TEX_BLEND_MODE_ADD)
    -- The glow art has its own greenish-gold tint; strip it so the group color decides the hue.
    band:SetDesaturation(1)
    band:SetDrawLevel(5)
    return { band = band }
end

local function EaseInOut(t)
    return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2
end

local function Phase(period)
    return (GetFrameTimeMilliseconds() % period) / period
end

-- Every frame the band's position and visibility are recomputed from the clock alone,
-- so a row that gets rebuilt mid-cycle never keeps a stale band on screen.
local function UpdateShimmer(row)
    local shimmer = row.igShimmer
    local band = shimmer.band
    local t = (GetFrameTimeMilliseconds() % shimmer.cycle) / shimmer.sweep
    if t >= 1 then
        band:SetHidden(true)
        return
    end
    local travel = row:GetWidth() - SHIMMER_WIDTH - THICKNESS * 2
    band:ClearAnchors()
    band:SetAnchor(TOPLEFT, row, TOPLEFT, THICKNESS + travel * EaseInOut(t), THICKNESS)
    band:SetAlpha(math.sin(math.pi * t))
    band:SetHidden(false)
end

-- The whole header breathes in place: no travel, just light coming up and going again.
local function UpdatePulse(row)
    local shimmer = row.igShimmer
    local band = shimmer.band
    band:ClearAnchors()
    band:SetAnchor(TOPLEFT, row, TOPLEFT, THICKNESS, THICKNESS)
    band:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -THICKNESS, -THICKNESS)
    -- Never fully out: a header that keeps disappearing reads as a fault rather than a signal.
    band:SetAlpha(0.15 + 0.85 * (0.5 - 0.5 * math.cos(Phase(shimmer.cycle) * 2 * math.pi)))
    band:SetHidden(false)
end

-- A short light running around the header's edge, one side at a time.
local function UpdateTrace(row)
    local shimmer = row.igShimmer
    local band = shimmer.band
    local width = row:GetWidth() - THICKNESS * 2
    local height = row:GetHeight() - THICKNESS * 2
    if width <= TRACE_LENGTH or height <= 0 then
        band:SetHidden(true)
        return
    end
    local travelled = Phase(shimmer.cycle) * (width + height) * 2
    local x, y, w, h
    if travelled < width then
        x, y, w, h = travelled, 0, TRACE_LENGTH, TRACE_THICKNESS
    elseif travelled < width + height then
        x, y, w, h = width - TRACE_THICKNESS, travelled - width, TRACE_THICKNESS, TRACE_LENGTH
    elseif travelled < width * 2 + height then
        x = width - (travelled - width - height) - TRACE_LENGTH
        y, w, h = height - TRACE_THICKNESS, TRACE_LENGTH, TRACE_THICKNESS
    else
        y = height - (travelled - width * 2 - height) - TRACE_LENGTH
        x, w, h = 0, TRACE_THICKNESS, TRACE_LENGTH
    end
    band:ClearAnchors()
    band:SetDimensions(w, h)
    band:SetAnchor(TOPLEFT, row, TOPLEFT, THICKNESS + x, THICKNESS + y)
    band:SetAlpha(1)
    band:SetHidden(false)
end

local UPDATE_STYLE = { shift = UpdateShimmer, pulse = UpdatePulse, trace = UpdateTrace }

---------------------------------------------------------------------------
-- Per-row animations share one OnUpdate handler
---------------------------------------------------------------------------

local function RunRowAnimations(row)
    for _, animate in pairs(row.igAnimations) do
        animate(row)
    end
end

-- Registers (or with nil removes) a named per-frame animation on a row.
function IG.SetRowAnimation(row, name, animate)
    row.igAnimations = row.igAnimations or {}
    row.igAnimations[name] = animate
    row:SetHandler("OnUpdate", next(row.igAnimations) and RunRowAnimations or nil)
end

-- style: "shift", "pulse" or "trace". speed: "slow", "normal" or "fast". No color, no style, or a
-- style we don't know: the header sits still.
function IG.SetHeaderAnimation(row, color, style, speed)
    local shimmer = row.igShimmer
    local update = style and UPDATE_STYLE[style]
    if not color or not update then
        if shimmer then shimmer.band:SetHidden(true) end
        IG.SetRowAnimation(row, "shimmer", nil)
        return
    end
    if not shimmer then
        shimmer = CreateShimmer(row)
        row.igShimmer = shimmer
    end

    local factor = SPEED_FACTOR[speed] or 1
    shimmer.sweep = SWEEP_MS * factor
    shimmer.cycle = (style == "shift" and CYCLE_MS or style == "pulse" and PULSE_MS or TRACE_MS) * factor

    local r, g, b = IG.HexToRGB(color)
    shimmer.band:SetColor(r, g, b, SHIMMER_ALPHA)
    if style == "shift" then
        shimmer.band:SetDimensions(SHIMMER_WIDTH, row:GetHeight() - THICKNESS * 2)
    end
    update(row)
    IG.SetRowAnimation(row, "shimmer", update)
end

---------------------------------------------------------------------------
-- One flash over part of a list
---------------------------------------------------------------------------
-- Being told where a piece went is one thing; watching it arrive is another. A wash of light
-- over the whole category and a brighter one over the row itself, coming up once and going out.
-- Added light rather than paint, and the same round glow the headers shimmer with, so nothing
-- under it is hidden and it is the light this addon already uses.
--
-- Measured down the built list rather than hung off the rows: a row inside a list is a control
-- out of a pool that the next rebuild hands to something else, and half a second is long enough
-- for that to happen. The scroll position is read every frame, so it stays over its rows while
-- the list moves under it.
local FLASH_TIMER = "InventoryGroupingFlash"
local FLASH_MS = 1300
local FLASH_RISE = 0.35        -- of the whole, spent coming up; the rest is the way out
local FLASH_LEVEL = 10
local washes = {}              -- [list] = { texture, ... }
local flash                    -- the one that is running, if any

local function Washes(list, count)
    local made = washes[list]
    if not made then
        made = {}
        washes[list] = made
    end
    for index = 1, count do
        if not made[index] then
            local wash = WINDOW_MANAGER:CreateControl(nil, list, CT_TEXTURE)
            wash:SetTexture(SHIMMER_TEXTURE)
            -- The same strip through the middle of the glow the shimmer uses: even from top to
            -- bottom, fading out to the left and right, so the wash has no edges of its own.
            wash:SetTextureCoords(0, 1, 0.47, 0.53)
            wash:SetBlendMode(TEX_BLEND_MODE_ADD)
            wash:SetDesaturation(1)
            wash:SetDrawLayer(DL_OVERLAY)
            wash:SetDrawLevel(FLASH_LEVEL)
            wash:SetMouseEnabled(false)
            wash:SetHidden(true)
            made[index] = wash
        end
    end
    return made
end

local function StopFlash()
    EVENT_MANAGER:UnregisterForUpdate(FLASH_TIMER)
    if not flash then return end
    for _, wash in ipairs(washes[flash.list] or {}) do wash:SetHidden(true) end
    flash = nil
end

local function UpdateFlash()
    if not flash or flash.list:IsHidden() then return StopFlash() end
    local elapsed = GetFrameTimeMilliseconds() - flash.startedAt
    if elapsed >= FLASH_MS then return StopFlash() end
    local t = elapsed / FLASH_MS
    local strength = t < FLASH_RISE and EaseInOut(t / FLASH_RISE)
        or EaseInOut(1 - (t - FLASH_RISE) / (1 - FLASH_RISE))

    local list = flash.list
    local scroll = list.scrollbar and list.scrollbar:GetValue() or 0
    local listHeight = list:GetHeight()
    for index, span in ipairs(flash.spans) do
        local wash = flash.washes[index]
        local top, height = span.top - scroll, span.height
        -- Kept inside the list. A control standing outside its own parent is not clipped by it,
        -- and a category taller than the window would light up whatever the list stands on.
        if top < 0 then top, height = 0, height + top end
        if top + height > listHeight then height = listHeight - top end
        if height <= 0 then
            wash:SetHidden(true)
        else
            wash:ClearAnchors()
            wash:SetAnchor(TOPLEFT, list, TOPLEFT, 0, top)
            wash:SetAnchor(TOPRIGHT, list, TOPRIGHT, 0, top)
            wash:SetHeight(height)
            wash:SetAlpha(strength * (span.strength or 1))
            wash:SetHidden(false)
        end
    end
end

-- spans: { { top, height, color, strength }, ... }, measured down the built list. Only one
-- flash runs at a time: two of them at once is a light show rather than an answer.
function IG.FlashSpans(list, spans)
    StopFlash()
    if not (list and spans and spans[1]) then return end
    local made = Washes(list, #spans)
    for index, span in ipairs(spans) do
        local r, g, b = IG.HexToRGB(span.color or "FFFFFF")
        -- The alpha here is not listened to on its own; the control's is what fades it.
        made[index]:SetColor(r, g, b, 1)
    end
    flash = { list = list, spans = spans, washes = made, startedAt = GetFrameTimeMilliseconds() }
    UpdateFlash()
    EVENT_MANAGER:RegisterForUpdate(FLASH_TIMER, 0, UpdateFlash)
end
