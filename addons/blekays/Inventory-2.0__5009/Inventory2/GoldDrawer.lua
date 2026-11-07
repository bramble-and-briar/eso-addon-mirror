InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- The GOLD TRACKER drawer: what the numbers in Gold.lua look like.
--
-- Read from the top down it is one sentence getting narrower. Which purse (the purse cards),
-- over what stretch of time (the four ranges), how much came in (one large figure, because that
-- is the answer the drawer was opened for), and then where from and where to, in two cards one
-- under the other rather than in two columns side by side: earning and spending are the same
-- list asked twice, and a table read down is read faster than a table read across.
--
-- Every part stands in a card of its own -- a dark ground and a thin outline -- so that nothing
-- floats on the panel's art, and every figure is measured before it is written: one too wide for
-- its place is written short (3.59M) and given in full when the mouse is on it, never laid over
-- its neighbour.
--
-- Nothing in here asks the game anything. Every figure is one the tracker already wrote down.

local PAD = 8                  -- inside every card
local CARD_GAP = 8             -- between one card and the next
local CURRENCY_HEIGHT = 30
local CURRENCY_GAP = 4
local CURRENCY_ICON = 18
local CURRENCY_ICON_GAP = 5
local RANGE_HEIGHT = 22
local CAPTION_HEIGHT = 16
local BIG_HEIGHT = 34
local LINE_HEIGHT = 18
local RULE_GAP = 6
local HEAD_HEIGHT = 24         -- the title strip across the top of EARNED and SPENT
local SUMMARY_HEIGHT = PAD + CAPTION_HEIGHT + BIG_HEIGHT + RULE_GAP + 1 + RULE_GAP
    + LINE_HEIGHT * 2 + PAD

local BIG_FONT = "$(BOLD_FONT)|30|soft-shadow-thin"
local CAPTION_FONT = "$(BOLD_FONT)|12|soft-shadow-thin"
local SMALL_FONT = "$(MEDIUM_FONT)|14|soft-shadow-thin"
local TAB_FONT = "$(MEDIUM_FONT)|14|soft-shadow-thin"
local BLOCK_FONT = "$(BOLD_FONT)|15|soft-shadow-thin"
local ROW_FONT = "$(MEDIUM_FONT)|14|soft-shadow-thin"

local ROW_HEIGHT = 19
local ROW_ICON = 15
local ROW_LABEL = 78          -- the name of the source, before the bar
local ROW_AMOUNT = 72         -- the figure at the end of the line, right against the edge
local ROW_GAP = 5
local BAR_HEIGHT = 9
-- Faint on purpose. The bar is there to be compared with the bar under it at a glance and
-- nothing else; drawn at full strength, eight of them are a chart shouting over the figures
-- that are the actual answer.
local BAR_ALPHA = 0.32
local BAR_BACK_ALPHA = 0.10

local EARNED_COLOR = "5CE07A"
local SPENT_COLOR = "FF6B6B"
local GOLD_COLOR = "FFD84A"   -- the drawer's own accent (Drawer.lua): the chosen purse
local DIM = "9A9AA2"
local FILL_ALPHA = 0.35       -- a card's dark ground
local EDGE_ALPHA = 0.22       -- a card's outline at rest
local CHOSEN_EDGE_ALPHA = 0.85
local TINT_ALPHA = 0.14       -- a coloured ground: the chosen purse, the chosen range, a title strip
local RULE_ALPHA = 0.35
local MAX_LINES = 8           -- per block; what is past it is folded into the last line

-- Draw levels inside the controls layer, so the cards are over the panel's art and the writing
-- is over the cards.
local LEVEL_FILL, LEVEL_TINT, LEVEL_BAR, LEVEL_EDGE, LEVEL_TEXT = 0, 1, 2, 3, 4

local RANGES = {
    { key = "today", label = "Today", days = 1 },
    { key = "week",  label = "7 days", days = 7 },
    { key = "month", label = "30 days", days = 30 },
    { key = "all",   label = "All", days = nil },
}

local function Hex(hex, text)
    return string.format("|c%s%s|r", hex, text)
end

local function Number(amount)
    return ZO_CommaDelimitNumber(amount or 0)
end

-- The same figure in a few characters, for a place too narrow for every digit of it.
local function Short(amount)
    amount = amount or 0
    local sign = amount < 0 and "-" or ""
    local size = zo_abs(amount)
    if size >= 1000000000 then return string.format("%s%.2fB", sign, size / 1000000000) end
    if size >= 1000000 then return string.format("%s%.2fM", sign, size / 1000000) end
    if size >= 10000 then return string.format("%s%.1fK", sign, size / 1000) end
    return sign .. Number(size)
end

-- Which purse and which stretch of time are being looked at. Kept in the settings rather than
-- in the control: a drawer that comes back open should come back reading what it was reading.
local function CurrencyKey()
    local wanted = IG.sv and IG.sv.goldCurrency
    for _, currency in ipairs(IG.CURRENCIES) do
        if currency.key == wanted and IG.CurrencyShown(currency.key) then return currency.key end
    end
    for _, currency in ipairs(IG.CURRENCIES) do
        if IG.CurrencyShown(currency.key) then return currency.key end
    end
end

local function RangeIndex()
    local wanted = IG.sv and IG.sv.goldRange
    for index, range in ipairs(RANGES) do
        if range.key == wanted then return index end
    end
    return 1
end

-- Whether a currency has a card at all. A player who has never set foot in Cyrodiil has no use
-- for a card that will read nought for ever, and says so on the drawers page.
function IG.CurrencyShown(key)
    local shown = IG.sv and IG.sv.drawerCurrencies
    return shown == nil or shown[key] ~= false
end

---------------------------------------------------------------------------
-- The pieces
---------------------------------------------------------------------------

local function Label(parent, font, color)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(font)
    label.igFont = font
    label:SetColor(IG.HexToRGB(color or "F2F2F2"))
    label:SetMouseEnabled(false)
    label:SetDrawLayer(DL_CONTROLS)
    label:SetDrawLevel(LEVEL_TEXT)
    return label
end

-- A plain texture painted one colour. Its strength is set with SetAlpha: a texture with no art
-- ignores the alpha handed to SetColor.
local function Paint(parent, level)
    local texture = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    texture:SetDrawLayer(DL_CONTROLS)
    texture:SetDrawLevel(level)
    texture:SetMouseEnabled(false)
    return texture
end

local function Colour(texture, hex, alpha)
    local r, g, b = IG.HexToRGB(hex)
    texture:SetColor(r, g, b, 1)
    texture:SetAlpha(alpha)
end

local function PaintEdges(card, hex, alpha)
    for _, edge in ipairs(card.edges) do Colour(edge, hex, alpha) end
end

-- A card: a dark ground with a thin outline round it, the same four lines the toolbar's buttons
-- and the drawer strip wear (IG.AddEdges, Toolbar.lua).
local function Card(parent)
    local card = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    card.fill = Paint(card, LEVEL_FILL)
    card.fill:SetAnchorFill(card)
    Colour(card.fill, "000000", FILL_ALPHA)
    card.tint = Paint(card, LEVEL_TINT)
    card.tint:SetAnchorFill(card)
    card.tint:SetHidden(true)
    IG.AddEdges(card)
    for _, edge in ipairs(card.edges) do edge:SetDrawLevel(LEVEL_EDGE) end
    PaintEdges(card, "FFFFFF", EDGE_ALPHA)
    return card
end

-- A one pixel line across a card.
local function Rule(parent, hex)
    local rule = Paint(parent, LEVEL_EDGE)
    rule:SetHeight(1)
    Colour(rule, hex or "FFFFFF", RULE_ALPHA)
    return rule
end

-- Writes a figure into a label, short if every digit of it would not fit in room. wrap, when
-- given, turns the figure into the whole text (a sign, a word before it), and the whole text is
-- what is measured. Answers whether it had to be shortened.
local function Fit(body, label, amount, room, wrap)
    local full = Number(amount)
    local text = wrap and wrap(full) or full
    local measure = body.igMeasure
    measure:SetFont(label.igFont)
    measure:SetText(text)
    local short = false
    if room and room > 0 and measure:GetTextWidth() > room then
        local brief = Short(amount)
        text = wrap and wrap(brief) or brief
        short = true
    end
    label:SetText(text)
    return short
end

local function ShowTip(control, text)
    if not text or text == "" then return end
    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -4)
    SetTooltipText(InformationTooltip, text)
end

local function HideTip()
    ClearTooltip(InformationTooltip)
end

-- One line of a block: the game's own mark for where the money went, the name of it, a bar as
-- full as that line's share of its own block, and the figure. Clickable only where the source
-- has a category in the bag to stand for it.
local function Line(parent)
    local row = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    row:SetHeight(ROW_HEIGHT)

    row.icon = Paint(row, LEVEL_TEXT)
    row.icon:SetDimensions(ROW_ICON, ROW_ICON)
    row.icon:SetAnchor(LEFT, row, LEFT, 0, 0)

    row.label = Label(row, ROW_FONT)
    row.label:SetAnchor(LEFT, row.icon, RIGHT, ROW_GAP, 0)
    row.label:SetWidth(ROW_LABEL)
    row.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.label:SetMaxLineCount(1)

    row.amount = Label(row, ROW_FONT)
    row.amount:SetAnchor(RIGHT, row, RIGHT, 0, 0)
    row.amount:SetWidth(ROW_AMOUNT)
    row.amount:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    row.back = Paint(row, LEVEL_BAR)
    row.back:SetHeight(BAR_HEIGHT)
    row.back:SetAnchor(LEFT, row.label, RIGHT, ROW_GAP, 0)
    row.back:SetAnchor(RIGHT, row.amount, LEFT, -ROW_GAP, 0)

    -- The filled part is hung off the back's left edge and given a width, rather than being
    -- anchored at both ends: how full it is is a number, not a place.
    row.bar = Paint(row, LEVEL_BAR)
    row.bar:SetHeight(BAR_HEIGHT)
    row.bar:SetAnchor(LEFT, row.back, LEFT, 0, 0)

    row.hover = Paint(row, LEVEL_TINT)
    row.hover:SetAnchorFill(row)
    Colour(row.hover, "FFFFFF", 0.06)
    row.hover:SetHidden(true)

    row:SetHandler("OnMouseEnter", function(self)
        if self.igGroup then self.hover:SetHidden(false) end
        ShowTip(self, self.igTip)
    end)
    row:SetHandler("OnMouseExit", function(self)
        self.hover:SetHidden(true)
        HideTip()
    end)
    row:SetHandler("OnMouseUp", function(self, _, upInside)
        if upInside and self.igGroup then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            IG.RevealGroup(self.igGroup)
        end
    end)
    return row
end

-- A block is a card with a coloured title strip across its top and a run of lines under it.
-- Both blocks are built the same way and differ only in what they are called and what colour
-- they are.
local function Block(parent, title, color)
    local block = { color = color, rows = {} }
    block.control = Card(parent)

    block.head = Paint(block.control, LEVEL_TINT)
    block.head:SetAnchor(TOPLEFT, block.control, TOPLEFT, 0, 0)
    block.head:SetAnchor(TOPRIGHT, block.control, TOPRIGHT, 0, 0)
    block.head:SetHeight(HEAD_HEIGHT)
    Colour(block.head, color, TINT_ALPHA)

    block.rule = Rule(block.control, color)
    block.rule:SetAnchor(TOPLEFT, block.control, TOPLEFT, 0, HEAD_HEIGHT)
    block.rule:SetAnchor(TOPRIGHT, block.control, TOPRIGHT, 0, HEAD_HEIGHT)

    block.title = Label(block.control, BLOCK_FONT, color)
    block.title:SetText(title)
    block.title:SetAnchor(LEFT, block.control, TOPLEFT, PAD, HEAD_HEIGHT / 2)

    block.total = Label(block.control, BLOCK_FONT, color)
    block.total:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    block.total:SetAnchor(RIGHT, block.control, TOPRIGHT, -PAD, HEAD_HEIGHT / 2)

    -- What a block with no lines says, so an empty card does not read as one still loading.
    block.empty = Label(block.control, ROW_FONT, DIM)
    block.empty:SetText("Nothing in this stretch")
    block.empty:SetAnchor(TOPLEFT, block.control, TOPLEFT, PAD, HEAD_HEIGHT + PAD)
    block.empty:SetHidden(true)

    block.control:SetMouseEnabled(true)
    block.control:SetHandler("OnMouseEnter", function(self) ShowTip(self, block.tip) end)
    block.control:SetHandler("OnMouseExit", HideTip)
    return block
end

local function FillBlock(body, block, lines, total, width)
    local inner = width - PAD * 2
    local shown = 0
    for index, line in ipairs(lines) do
        if index > MAX_LINES then break end
        shown = index
        local row = block.rows[index]
        if not row then
            row = Line(block.control)
            block.rows[index] = row
        end
        row:ClearAnchors()
        row:SetWidth(inner)
        row:SetAnchor(TOPLEFT, block.control, TOPLEFT, PAD,
            HEAD_HEIGHT + PAD + (index - 1) * (ROW_HEIGHT + ROW_GAP))
        row.icon:SetTexture(IG.GOLD_SOURCE_BY_KEY[line.key]
            and IG.GOLD_SOURCE_BY_KEY[line.key].icon or "")
        row.label:SetText(line.label)
        row.amount:SetColor(IG.HexToRGB(block.color))
        local short = Fit(body, row.amount, line.amount, ROW_AMOUNT)
        -- The full figure on the mouse whenever the line had to shorten it.
        row.igTip = short and (line.label .. ": " .. Number(line.amount)) or nil

        Colour(row.back, block.color, BAR_BACK_ALPHA)
        Colour(row.bar, block.color, BAR_ALPHA)
        -- Worked out rather than measured: the run between the name and the figure is a
        -- subtraction, and asking the control for it answers nothing until the drawer has been
        -- laid out once -- which is exactly the pass that draws the bars for the first time.
        local run = zo_max(0, inner - ROW_ICON - ROW_LABEL - ROW_AMOUNT - ROW_GAP * 3)
        row.bar:SetWidth(zo_max(1, zo_round(run * line.share)))

        -- Only a line the bag has a category for takes the mouse for a click; a line that had to
        -- shorten its figure takes it too, for the tooltip.
        row.igGroup = line.group
        row.hover:SetHidden(true)
        row:SetMouseEnabled(line.group ~= nil or short)
        row:SetHidden(false)
    end
    for index = shown + 1, #block.rows do block.rows[index]:SetHidden(true) end
    block.empty:SetHidden(shown > 0)

    local totalShort = Fit(body, block.total, total, inner / 2)
    block.tip = totalShort and (block.title:GetText() .. ": " .. Number(total)) or nil

    local listHeight = shown > 0 and (shown * (ROW_HEIGHT + ROW_GAP) - ROW_GAP) or ROW_HEIGHT
    local height = HEAD_HEIGHT + PAD + listHeight + PAD
    block.control:SetDimensions(width, height)
    return height
end

---------------------------------------------------------------------------
-- The drawer itself
---------------------------------------------------------------------------

function IG.BuildGoldDrawer(body)
    local width = body:GetWidth()

    -- Never seen: the label every figure is measured on before it is written anywhere.
    body.igMeasure = Label(body, SMALL_FONT)
    body.igMeasure:SetAnchor(TOPLEFT, body, TOPLEFT, 0, 0)
    body.igMeasure:SetAlpha(0)

    -- The purses, each a card of its own reading what is in it right now.
    body.igCurrencyCards = {}
    for _, currency in ipairs(IG.CURRENCIES) do
        local key = currency.key
        local card = Card(body)
        card:SetMouseEnabled(true)
        card.icon = Paint(card, LEVEL_TEXT)
        card.icon:SetTexture(currency.icon)
        card.icon:SetDimensions(CURRENCY_ICON, CURRENCY_ICON)
        card.icon:SetAnchor(LEFT, card, LEFT, PAD, 0)
        card.text = Label(card, TAB_FONT)
        card.text:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        card.text:SetAnchor(RIGHT, card, RIGHT, -PAD, 0)
        card.igCurrency = currency
        card:SetHandler("OnMouseUp", function(_, _, upInside)
            if not upInside then return end
            PlaySound(SOUNDS.DEFAULT_CLICK)
            if IG.sv then IG.sv.goldCurrency = key end
            IG.RefreshOpenDrawer()
        end)
        card:SetHandler("OnMouseEnter", function(self)
            ShowTip(self, currency.label .. ": " .. Number(IG.CurrencyAmount(currency)))
        end)
        card:SetHandler("OnMouseExit", HideTip)
        body.igCurrencyCards[#body.igCurrencyCards + 1] = card
    end

    -- The four stretches of time, one bar cut into four.
    body.igRangeBar = Card(body)
    body.igRangeTabs = {}
    for index, range in ipairs(RANGES) do
        local tab = WINDOW_MANAGER:CreateControl(nil, body.igRangeBar, CT_CONTROL)
        tab:SetMouseEnabled(true)
        tab.tint = Paint(tab, LEVEL_TINT)
        tab.tint:SetAnchorFill(tab)
        tab.text = Label(tab, TAB_FONT)
        tab.text:SetText(range.label)
        tab.text:SetAnchor(CENTER, tab, CENTER, 0, 0)
        if index > 1 then
            tab.divider = Paint(tab, LEVEL_EDGE)
            tab.divider:SetWidth(1)
            tab.divider:SetAnchor(TOPLEFT, tab, TOPLEFT, 0, 0)
            tab.divider:SetAnchor(BOTTOMLEFT, tab, BOTTOMLEFT, 0, 0)
            Colour(tab.divider, "FFFFFF", EDGE_ALPHA)
        end
        tab:SetHandler("OnMouseUp", function(_, _, upInside)
            if not upInside then return end
            PlaySound(SOUNDS.DEFAULT_CLICK)
            if IG.sv then IG.sv.goldRange = range.key end
            IG.RefreshOpenDrawer()
        end)
        body.igRangeTabs[index] = tab
    end

    -- The answer, large, and the figures that qualify it, in one card.
    local summary = Card(body)
    summary:SetMouseEnabled(true)
    summary:SetHandler("OnMouseEnter", function(self) ShowTip(self, body.igSummaryTip) end)
    summary:SetHandler("OnMouseExit", HideTip)
    body.igSummary = summary

    body.igCaption = Label(summary, CAPTION_FONT, DIM)
    body.igCaption:SetAnchor(TOPLEFT, summary, TOPLEFT, PAD, PAD)
    body.igCaption:SetHeight(CAPTION_HEIGHT)

    body.igEarned = Label(summary, BIG_FONT, EARNED_COLOR)
    body.igEarned:SetAnchor(TOPLEFT, summary, TOPLEFT, PAD, PAD + CAPTION_HEIGHT)
    body.igEarned:SetHeight(BIG_HEIGHT)

    local ruleY = PAD + CAPTION_HEIGHT + BIG_HEIGHT + RULE_GAP
    body.igSummaryRule = Rule(summary)
    body.igSummaryRule:SetAnchor(TOPLEFT, summary, TOPLEFT, PAD, ruleY)
    body.igSummaryRule:SetAnchor(TOPRIGHT, summary, TOPRIGHT, -PAD, ruleY)

    local lineY = ruleY + 1 + RULE_GAP
    body.igNet = Label(summary, SMALL_FONT, DIM)
    body.igNet:SetAnchor(TOPLEFT, summary, TOPLEFT, PAD, lineY)
    body.igNet:SetHeight(LINE_HEIGHT)
    body.igSpent = Label(summary, SMALL_FONT, DIM)
    body.igSpent:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    body.igSpent:SetAnchor(TOPRIGHT, summary, TOPRIGHT, -PAD, lineY)
    body.igSpent:SetHeight(LINE_HEIGHT)

    body.igBest = Label(summary, SMALL_FONT, DIM)
    body.igBest:SetAnchor(TOPLEFT, summary, TOPLEFT, PAD, lineY + LINE_HEIGHT)
    body.igBest:SetHeight(LINE_HEIGHT)
    body.igBest:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    body.igBest:SetMaxLineCount(1)

    body.igEarnedBlock = Block(body, "EARNED", EARNED_COLOR)
    body.igSpentBlock = Block(body, "SPENT", SPENT_COLOR)

    body.igWidth = width
    IG.RefreshGoldDrawer(body)
end

function IG.RefreshGoldDrawer(body)
    if not body.igCurrencyCards then return end
    local width = body:GetWidth()
    local inner = width - PAD * 2
    local y = 0

    -- The purses that are wanted, two to a row (one row when there are only one or two). Done on
    -- every pass because the settings page can take one away while the drawer is open.
    local shown = {}
    for _, card in ipairs(body.igCurrencyCards) do
        local live = IG.CurrencyShown(card.igCurrency.key)
        card:SetHidden(not live)
        if live then shown[#shown + 1] = card end
    end

    local currencyKey = CurrencyKey()
    if #shown > 0 then
        local columns = zo_min(#shown, 2)
        local cardWidth = (width - CURRENCY_GAP * (columns - 1)) / columns
        local room = cardWidth - PAD * 2 - CURRENCY_ICON - CURRENCY_ICON_GAP
        for index, card in ipairs(shown) do
            local column = (index - 1) % columns
            local row = zo_floor((index - 1) / columns)
            card:ClearAnchors()
            card:SetDimensions(zo_round(cardWidth), CURRENCY_HEIGHT)
            card:SetAnchor(TOPLEFT, body, TOPLEFT, zo_round(column * (cardWidth + CURRENCY_GAP)),
                y + row * (CURRENCY_HEIGHT + CURRENCY_GAP))
            card.text:SetWidth(room)
            Fit(body, card.text, IG.CurrencyAmount(card.igCurrency), room)

            local chosen = card.igCurrency.key == currencyKey
            PaintEdges(card, chosen and GOLD_COLOR or "FFFFFF", chosen and CHOSEN_EDGE_ALPHA or EDGE_ALPHA)
            Colour(card.tint, GOLD_COLOR, TINT_ALPHA)
            card.tint:SetHidden(not chosen)
            card.text:SetColor(IG.HexToRGB(chosen and "FFFFFF" or DIM))
            card.icon:SetAlpha(chosen and 1 or 0.6)
        end
        local rows = zo_ceil(#shown / columns)
        y = y + rows * CURRENCY_HEIGHT + (rows - 1) * CURRENCY_GAP + CARD_GAP
    end

    -- The ranges.
    local rangeIndex = RangeIndex()
    body.igRangeBar:ClearAnchors()
    body.igRangeBar:SetDimensions(width, RANGE_HEIGHT)
    body.igRangeBar:SetAnchor(TOPLEFT, body, TOPLEFT, 0, y)
    local rangeStep = width / #RANGES
    for index, tab in ipairs(body.igRangeTabs) do
        local left = zo_round(rangeStep * (index - 1))
        local right = zo_round(rangeStep * index)
        tab:ClearAnchors()
        tab:SetDimensions(right - left, RANGE_HEIGHT)
        tab:SetAnchor(TOPLEFT, body.igRangeBar, TOPLEFT, left, 0)
        local chosen = index == rangeIndex
        Colour(tab.tint, EARNED_COLOR, TINT_ALPHA)
        tab.tint:SetHidden(not chosen)
        tab.text:SetColor(IG.HexToRGB(chosen and EARNED_COLOR or DIM))
        tab.text:SetAlpha(chosen and 1 or 0.85)
    end
    y = y + RANGE_HEIGHT + CARD_GAP

    -- The summary card.
    local summaryCard = body.igSummary
    summaryCard:ClearAnchors()
    summaryCard:SetDimensions(width, SUMMARY_HEIGHT)
    summaryCard:SetAnchor(TOPLEFT, body, TOPLEFT, 0, y)
    body.igEarned:SetWidth(inner)
    body.igNet:SetWidth(inner / 2)
    body.igSpent:SetWidth(inner / 2)
    body.igBest:SetWidth(inner)
    y = y + SUMMARY_HEIGHT + CARD_GAP

    local earnedBlock, spentBlock = body.igEarnedBlock, body.igSpentBlock
    earnedBlock.control:ClearAnchors()
    earnedBlock.control:SetAnchor(TOPLEFT, body, TOPLEFT, 0, y)

    body.igCaption:SetText("EARNED  -  " .. zo_strupper(RANGES[rangeIndex].label))

    -- No purse to show at all: every one of them has been switched off on the settings page.
    if not currencyKey then
        body.igEarned:SetText("--")
        body.igNet:SetText(Hex(DIM, "No currency is switched on"))
        body.igSpent:SetText("")
        body.igBest:SetText("")
        body.igSummaryTip = nil
        local height = FillBlock(body, earnedBlock, {}, 0, width)
        spentBlock.control:ClearAnchors()
        spentBlock.control:SetAnchor(TOPLEFT, body, TOPLEFT, 0, y + height + CARD_GAP)
        FillBlock(body, spentBlock, {}, 0, width)
        return
    end

    local summary = IG.GoldSummary(currencyKey, RANGES[rangeIndex].days)
    local tips = {}

    if Fit(body, body.igEarned, summary.earnedTotal, inner) then
        tips[#tips + 1] = "Earned: " .. Number(summary.earnedTotal)
    end

    local netColor = summary.net >= 0 and EARNED_COLOR or SPENT_COLOR
    local netSign = summary.net >= 0 and "+" or "-"
    if Fit(body, body.igNet, zo_abs(summary.net), inner / 2, function(figure)
        return Hex(DIM, "Net ") .. Hex(netColor, netSign .. figure)
    end) then
        tips[#tips + 1] = "Net: " .. netSign .. Number(zo_abs(summary.net))
    end
    if Fit(body, body.igSpent, summary.spentTotal, inner / 2, function(figure)
        return Hex(DIM, "Spent ") .. Hex(SPENT_COLOR, figure)
    end) then
        tips[#tips + 1] = "Spent: " .. Number(summary.spentTotal)
    end

    if summary.bestDate then
        -- Over "All" the best day can only be one of the days still kept, and a figure that
        -- quietly means something narrower than the range above it has to say so.
        local within = summary.partialBest and " (last 30 days)" or ""
        local best = string.format("Best day: %s -- %s%s", IG.GoldDayName(summary.bestDate),
            Number(summary.bestAmount), within)
        body.igBest:SetText(Hex(DIM, best))
        tips[#tips + 1] = best
    else
        body.igBest:SetText(Hex(DIM, "Nothing earned yet in this stretch"))
    end
    body.igSummaryTip = #tips > 0 and table.concat(tips, "\n") or nil

    local earnedHeight = FillBlock(body, earnedBlock,
        IG.GoldLines(summary.earned, summary.earnedTotal), summary.earnedTotal, width)
    spentBlock.control:ClearAnchors()
    spentBlock.control:SetAnchor(TOPLEFT, body, TOPLEFT, 0, y + earnedHeight + CARD_GAP)
    FillBlock(body, spentBlock,
        IG.GoldLines(summary.spent, summary.spentTotal), summary.spentTotal, width)
end
