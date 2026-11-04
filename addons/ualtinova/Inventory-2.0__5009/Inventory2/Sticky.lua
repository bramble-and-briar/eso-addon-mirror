InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- The category you are inside, kept at the top of the list.
--
-- Open a long category and scroll into it and its header leaves the screen, so the rows you are
-- reading stop saying what they are rows of. A button at the end of the category would only be
-- reachable after scrolling further into it -- past the point where the question is still being
-- asked. So the header itself stays: while any row of a category is on screen and its own header
-- is not, a copy of that header sits against the top edge, and clicking it takes you back to
-- where the real one stands.
--
-- It is the real header in every other way: the same template the list uses, dressed by the same
-- code, so it says what the row it stands for would say -- name, count, colour, icon and all.

local STICKY_LEVEL = 20      -- over the rows it covers
local POLL_MS = 40           -- how often the scroll position is asked for
-- A plate of its own under the header, so what it covers does not read through it at all. It is
-- standing over the list and the rows behind it are not its business; the fade as it comes and
-- goes is what says it is standing there rather than sitting in it.
local STICKY_BACK_ALPHA = 1
-- The plate does not stop, it runs out. A hard edge across the row underneath reads as a lid
-- shut on the list; a short run of the same black, spent by the time it reaches the middle of
-- that row, reads as the row coming out from under it.
-- Steps rather than a gradient. A corner-to-corner fade on a textureless piece is what the rest
-- of this addon draws its fading lines with, and here it came out as a flat black band twice
-- over; a handful of thin strips, each one solid at its own strength, cannot come out as
-- anything else. Read top to bottom, they are the fade.
-- Long and gentle rather than short and steep. The list behind it is dark already, so the top
-- of a steep ramp is indistinguishable from the plate above it and the whole thing reads as one
-- black band with an edge; starting lower and running twice as far is what makes it a fade.
local STICKY_TAIL = { 0.62, 0.55, 0.48, 0.41, 0.34, 0.28, 0.22, 0.17, 0.12, 0.08, 0.05, 0.02 }
local STICKY_STEP = 3
-- Below this the fade is not worth drawing, and the control is put away instead.
local FADE_FLOOR = 0.04
-- A category rarely begins at its own header: the white heading over a run of categories, and
-- the gap under the one before, stand there first and belong to it. Clicking brings those back
-- as well, up to this much of them -- enough for a heading and its gap, and not so much that a
-- category with a long tail above it is scrolled past.
local LEAD_ROOM = 70
-- The second one: the sub-category you are inside, standing under the category you are inside.
-- Three quarters of the height, and the sizes of the level below it, so the two together read
-- as one category with something open in it rather than as two categories.
local SUB_STICKY_SCALE = 0.75
local SUB_STICKY_LOOK = 3
local sticky = {}            -- [inventoryType] = control
local stickySub = {}         -- [inventoryType] = the smaller one standing under it
-- What CategoryAbove found, read straight after it answers. One table, reused: this runs on a
-- timer and nothing keeps the answer.
local above = {}

-- How tall a row really is. Not data.rowHeight: that is ours, and the rows the game builds --
-- every item row in the list -- do not carry it, so counting with it counted an item as nothing
-- and put the top of the view hundreds of pixels from where it is. The list positions rows by
-- the height registered for their type, so that is the one to ask.
local function RowHeight(list, entry)
    local dataType = entry.typeId and ZO_ScrollList_GetDataTypeTable(list, entry.typeId)
    if dataType and dataType.height then return dataType.height end
    return (entry.data and entry.data.rowHeight) or 0
end

-- A row that opens a top-level category. Spacers and headings carry no depth, and nothing else
-- in the list is drawn at depth 1. Under a Chips/Tiles section the open category has no header
-- row of its own: the light heading under the buttons (ModuleStrip.lua) stands in its place and
-- carries the header it would have been, which is what the sticky is dressed as.
local function IsCategoryRow(data)
    if data ~= nil and data.isStripHeading then return data.header ~= nil end
    return data ~= nil and data.depth == 1 and data.key ~= nil
end

-- A row that opens a sub-category inside one. Sets and places stand at this level too and
-- neither sticks: a set is read by its own look wherever it is, and a place is a line rather
-- than a button -- there is nothing to be inside.
local function IsSubCategoryRow(data)
    return data ~= nil and data.depth == 2 and data.key ~= nil
        and not data.isSet and not data.isRule
end

-- The last category to have started above the top of the view, where its header stands, and
-- where the next category begins. That last one is what the way out is measured against: a
-- header leaving is only half of it, and the half that was missing is the next one arriving.
-- The same question is asked one level down on the way past: which sub-category's own heading
-- has gone under the header now standing at the top, and where its last row is.
local function CategoryAbove(list, offset)
    local rows = ZO_ScrollList_GetDataList(list)
    local y, runTop = 0, nil
    above.data, above.top, above.height, above.nextTop, above.lead = nil, 0, 0, nil, 0
    above.strip = nil
    above.sub, above.subTop, above.subHeight, above.subNext = nil, 0, 0, nil
    for _, entry in ipairs(rows) do
        local data = entry.data
        local height = RowHeight(list, entry)
        -- Rows we drew ourselves carry their height; the item rows the game draws do not. A
        -- heading and the gap under the category before it are ours, so the run of our own rows
        -- ending at a header is exactly what stands in front of that header.
        if data and data.rowHeight then
            if runTop == nil then runTop = y end
        else
            runTop = nil
        end
        if IsCategoryRow(data) then
            if y <= offset then
                above.data, above.top, above.height = data.header or data, y, height
                above.strip = data.isStripHeading and data or nil
                above.lead = zo_max(runTop or y, y - LEAD_ROOM)
                -- Whatever was open inside the category before is not inside this one.
                above.sub, above.subTop, above.subHeight, above.subNext = nil, 0, 0, nil
            else
                above.nextTop = y
                break
            end
        elseif data and data.depth == 2 then
            -- Everything at the second level ends what stood there before it: the next heading,
            -- or the gap and the foot our own rows leave where one of them closed. What is
            -- hidden is what the header at the top covers, so that is what is measured against.
            local covered = offset + (above.data and above.data.rowHeight or 0)
            if y <= covered then
                above.sub, above.subTop, above.subHeight = nil, 0, 0
                if IsSubCategoryRow(data) and data.expanded and (data.count or 0) > 1 then
                    above.sub, above.subTop, above.subHeight = data, y, height
                end
            elseif above.sub and not above.subNext then
                above.subNext = y
            end
        end
        y = y + height
    end
    return above
end

local function HideSub(inventoryType)
    local control = stickySub[inventoryType]
    if control then control:SetHidden(true) end
end

-- The tail is not the header's child, so it is shown, hidden and faded with it by hand.
local function Hide(inventoryType)
    HideSub(inventoryType)
    local control = sticky[inventoryType]
    if not control then return end
    control:SetHidden(true)
    for _, step in ipairs(control.igStickyTail or {}) do step:SetHidden(true) end
end

-- Back to where the real header stands, and to what stands in front of it.
local function ScrollTo(control)
    if not (control.igStickyTop and control.igStickyList) then return end
    local bar = control.igStickyList.scrollbar
    local lowest, highest = 0, 0
    if bar then lowest, highest = bar:GetMinMax() end
    ZO_ScrollList_ScrollAbsolute(control.igStickyList, zo_clamp(control.igStickyTop, lowest, highest))
end

-- Both stickies are built from this: the same template, the same plate, the same two handlers.
-- Only the big one runs out into a tail, and only it stands at the very top -- the small one is
-- anchored again on every pass, under whatever height the big one turns out to have.
local function Control(store, name, inventoryType, list, withTail)
    local control = store[inventoryType]
    if control then return control end

    control = WINDOW_MANAGER:CreateControlFromVirtual(
        name .. inventoryType, list, "InventoryGrouping_HeaderRow")
    control:SetAnchor(TOPLEFT, list, TOPLEFT, 0, 0)
    control:SetAnchor(TOPRIGHT, list, TOPRIGHT, 0, 0)
    -- A tier, not a layer. Children do not inherit a layer, so the plate below went under the
    -- rows instead of over them and the header was left showing through its own glass. A tier
    -- carries the whole of this control over everything the list draws, and the order inside it
    -- -- plate at the bottom, header on top -- is then its own business.
    control:SetDrawTier(DT_HIGH)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawLevel(STICKY_LEVEL)
    control:SetMouseEnabled(true)

    -- Its height is set when the header is dressed, not taken from the control: what the
    -- template does about its own extents is the template's business, and a plate that followed
    -- it hung below the header as a black band of its own.
    local back = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    back:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    back:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
    back:SetColor(0, 0, 0, STICKY_BACK_ALPHA)
    back:SetDrawTier(DT_HIGH)
    back:SetDrawLayer(DL_BACKGROUND)
    back:SetDrawLevel(0)
    control.igStickyBack = back

    -- Hung off the list rather than off the header: they lie entirely below it, and a child that
    -- lies outside its parent is at the mercy of whatever the template does about its extents.
    control.igStickyTail = withTail and {} or nil
    for index, alpha in ipairs(withTail and STICKY_TAIL or {}) do
        local step = WINDOW_MANAGER:CreateControl(nil, list, CT_TEXTURE)
        step:SetHeight(STICKY_STEP)
        step:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
        step:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
        -- Black, and opaque as far as the colour is concerned: on a piece with no texture the
        -- alpha handed to SetColor is not what decides. The control is stood down to its own
        -- strength below instead, which is what makes these twelve a fade rather than a band.
        step:SetColor(0, 0, 0, 1)
        step.igStickyFade = alpha
        step:SetDrawTier(DT_HIGH)
        step:SetDrawLayer(DL_BACKGROUND)
        step:SetDrawLevel(0)
        step:SetHidden(true)
        control.igStickyTail[index] = step
    end
    -- The template comes with the bag's own handlers: one of them opens and closes the category,
    -- which is not what a click on this means. It means "show me the header this stands for".
    control:SetHandler("OnMouseEnter", function(self)
        IG.SetHeaderSurface(self, self.igHoverColor)
    end)
    control:SetHandler("OnMouseExit", function(self)
        IG.SetHeaderSurface(self, self.igBgColor)
    end)
    -- A click goes back to the real header and nothing else: the category stays open, and the
    -- list only travels as far up as that header (reported 2026-11-04 -- it used to close the
    -- category on the way, which is what the mark on the left is for, below).
    control:SetHandler("OnMouseUp", function(self, _, upInside)
        if not upInside then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        ScrollTo(self)
    end)

    -- The mark on the left closes the category as well as going back to it, which is what it
    -- does on the real header. Closing is measured from above the view, so the rows in front of
    -- the header do not move and the same landing place still holds afterwards.
    local marker = control:GetNamedChild("Marker")
    if marker then
        marker:SetMouseEnabled(true)
        marker:SetHandler("OnMouseUp", function(_, _, upInside)
            if not upInside then return end
            local strip = control.igStickyStrip
            if strip and strip.strip and strip.chip then
                IG.ToggleModuleStrip(strip.strip.invKey, strip.strip.inventoryType, strip.chip.key,
                    strip.strip.section)
                return ScrollTo(control)
            end
            local data = control.igData
            if not data then return end
            PlaySound(SOUNDS.DEFAULT_CLICK)
            IG.CloseCategory(data.inventoryType, data.invKey, data.key)
            ScrollTo(control)
        end)
    end

    store[inventoryType] = control
    return control
end

-- The sub-category you are inside, under the category you are inside. It never stands on its
-- own: a heading with nothing over it saying what it is a heading inside of is worse than no
-- heading at all. Returns how much of it is showing, which is where the tail then starts.
local function UpdateSub(inventoryType, list, found, bigHeight, bigShown, offset)
    local data = found.sub
    if not data then return HideSub(inventoryType) end
    local height = zo_round(bigHeight * SUB_STICKY_SCALE)
    if height <= 0 then return HideSub(inventoryType) end

    -- It arrives as its own heading goes under the one above it, and leaves as its last row
    -- does -- both measured from under that header, since that is where this one stands.
    local arriving = zo_clamp((offset + bigHeight - found.subTop) / height, 0, 1)
    local leaving = found.subNext
        and zo_clamp((found.subNext - offset - bigHeight) / height, 0, 1) or 1
    local shown = zo_min(arriving, leaving) * bigShown
    if shown <= FADE_FLOOR then return HideSub(inventoryType) end

    local control = Control(stickySub, "InventoryGroupingStickySub", inventoryType, list, false)
    control.igStickyList = list
    -- Back to where its own heading stands, clear of the header standing over it.
    control.igStickyTop = found.subTop - bigHeight
    if control.igStickyKey ~= data.key or control.igStickyHeight ~= height or control:IsHidden() then
        control.igStickyKey, control.igStickyHeight = data.key, height
        -- The row's own data, drawn shorter and with the sizes of the level below it. Both are
        -- the header they stand for in every other way, and which of the two is the category
        -- is never a question.
        IG.DressHeaderRow(control, setmetatable({ rowHeight = height, look = SUB_STICKY_LOOK },
            { __index = data }))
        control:SetHidden(false)
    end
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, list, TOPLEFT, 0, bigHeight)
    control:SetAnchor(TOPRIGHT, list, TOPRIGHT, 0, bigHeight)
    control:SetAlpha(shown)
    if control.igStickyBack then control.igStickyBack:SetHeight(height) end
    return height * shown
end

-- One list, if it is on screen and has a category to stand for.
local function UpdateOne(inventoryType)
    local inventory = PLAYER_INVENTORY and PLAYER_INVENTORY.inventories[inventoryType]
    local list = inventory and inventory.listView
    if not list or list:IsHidden() then return Hide(inventoryType) end

    local offset = list.scrollbar and list.scrollbar:GetValue() or 0
    local found = CategoryAbove(list, offset)
    local data, top, height, nextTop, lead =
        found.data, found.top, found.height, found.nextTop, found.lead
    -- Only ever stands in for a category you are inside. A closed one has nothing under it, so
    -- scrolling past a run of them would otherwise flicker a new header in and out at every
    -- name -- headers being the only thing in that run.
    if not data or not data.expanded or height <= 0 then return Hide(inventoryType) end
    -- One row under it is read whole wherever it is: there is nothing to lose sight of, and a
    -- header standing in for a single line is more in the way than the line is.
    if (data.count or 0) <= 1 then return Hide(inventoryType) end

    -- It arrives exactly as the real one leaves: the ramp is the header's own height, so the
    -- further the real header has gone, the more of this one there is.
    --
    -- And it leaves as the next category arrives, on a ramp of the same length measured against
    -- where that one begins. The next header takes over at nothing and climbs from there, so the
    -- two cross rather than one of them blinking out -- which is what happens whether the next
    -- category is open or shut, and is the whole of the handover when several are open at once.
    local arriving = zo_clamp((offset - top) / height, 0, 1)
    local leaving = nextTop and zo_clamp((nextTop - offset) / height, 0, 1) or 1
    local shown = zo_min(arriving, leaving)
    if shown <= FADE_FLOOR then return Hide(inventoryType) end

    local control = Control(sticky, "InventoryGroupingSticky", inventoryType, list, true)
    control.igStickyList = list
    control.igStickyTop = lead or top
    control.igStickyStrip = found.strip
    -- Dressing a header is not free, and the answer only changes when you cross one.
    if control.igStickyKey ~= data.key or control:IsHidden() then
        control.igStickyKey = data.key
        IG.DressHeaderRow(control, data)
        control:SetHidden(false)
    end
    control:SetAlpha(shown)

    -- The plate is exactly as tall as the header it is under, and the steps start where it
    -- ends -- below the smaller header as well, while one is standing under this one. It slides
    -- down with that one as it fades in, rather than jumping the moment it appears.
    local rowHeight = data.rowHeight or control:GetHeight()
    if control.igStickyBack then control.igStickyBack:SetHeight(rowHeight) end
    local tailTop = rowHeight + (UpdateSub(inventoryType, list, found, rowHeight, shown, offset) or 0)
    for index, step in ipairs(control.igStickyTail or {}) do
        step:ClearAnchors()
        step:SetAnchor(TOPLEFT, control, TOPLEFT, 0, tailTop + (index - 1) * STICKY_STEP)
        step:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, tailTop + (index - 1) * STICKY_STEP)
        step:SetHidden(false)
        step:SetAlpha((step.igStickyFade or 1) * shown)
    end
end

-- Every grouped list, not just the one that answers first: standing at a bank, the bag and the
-- bank are both on screen and each is somewhere different in its own list.
local function Update()
    for _, inventoryType in ipairs(IG.GROUPED_LISTS or {}) do UpdateOne(inventoryType) end
end

function IG.StartSticky()
    EVENT_MANAGER:RegisterForUpdate("InventoryGroupingSticky", POLL_MS, Update)
end
