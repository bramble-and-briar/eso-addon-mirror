local addon = BureauOfMaterialWorth
addon.Window = addon.Window or {}

local Window = addon.Window
local private = addon.private

local GetString = GetString
local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local stringformat = string.format
local zo_round = zo_round
local mathabs = math.abs
local mathmax = math.max
local mathsin = math.sin

-- Palette (shared house style; see private.COLOR_* in BureauOfMaterialWorth.lua)
-- ---------------------------------------------------------------------------
local COLOR_ACCENT   = private.COLOR_ACCENT
local COLOR_MUTED    = private.COLOR_MUTED
local COLOR_NAME     = private.COLOR_NAME
local COLOR_GOLD     = private.COLOR_GOLD
local COLOR_WARN     = private.COLOR_WARN
local COLOR_GAIN     = private.COLOR_GAIN
local COLOR_LOSS     = private.COLOR_LOSS

-- Shared fonts, spacing, styling, and tooltip helpers.
local UI = private.UI
local FONT = UI.FONT
local METRIC = UI.METRIC


-- Layout constants
-- ---------------------------------------------------------------------------
-- Content-sized panel beside the Craft Bag, with optional categories and history.
-- Width bounds are shared with Settings; ApplyWidth updates existing controls.
local DEFAULT_WINDOW_WIDTH = 460
local MIN_WINDOW_WIDTH = 460
local MAX_WINDOW_WIDTH = 600
local WINDOW_WIDTH_STEP = 10
local PADDING        = METRIC.PADDING
local ADDON_NAME_HEIGHT = 22
local PROFILE_HEIGHT = 16
local TOTAL_TO_PROFILE_GAP = 5
local PROFILE_TO_SUBTITLE_GAP = 1
local TOTAL_HEIGHT   = 34
local SUBTITLE_HEIGHT = 18
local ROW_HEIGHT     = 30
local DIVIDER_GAP    = 10   -- vertical space a divider occupies
local FOOTER_LINE    = 16
local SECTION_GAP    = 4    -- compact, consistent separation between blocks
local SPARK_TOP_GAP  = 12   -- separation between footer and history caption
local TITLE_TO_TOTAL_GAP = 14
local HEADER_TO_DIVIDER_GAP = 1
local FOOTER_ALPHA   = 0.82
local HEADER_BAND_PAD = METRIC.BAND_PAD
local LEADER_MARKER_WIDTH = 3
-- Accent marker for the leading category; the header underline uses brass.
local LEADER_MARKER_COLOR = { UI.Tone("accent") }
LEADER_MARKER_COLOR[4] = UI.CHROME.ACCENT_MARK


-- Edge-to-edge bars form a value-history area strip with the newest sample highlighted.
-- The header shows the latest value and trend; the scale shows the series range.
local SPARK_HEIGHT     = 32  -- area-strip height in px (head line above, scale below)
local SPARK_MIN_BAR_H  = 2   -- floor height so the minimum sample still draws
local SPARK_SCALE_GAP  = 2   -- gap between the strip and the min/max scale line
local SPARK_MARKER_WIDTH = 6
local SPARK_MARKER_HEIGHT = 4
-- Gain/loss tint follows the overall series direction; emphasize the latest sample.
local SPARK_HISTORY_ALPHA = 0.28
local SPARK_NOW_ALPHA     = 0.92
local function SparkTint(tone, alpha)
    local r, g, b = UI.Tone(tone)
    return { r, g, b, alpha }
end
local SPARK_AREA_UP       = SparkTint("gain", SPARK_HISTORY_ALPHA)
local SPARK_AREA_UP_NOW   = SparkTint("gain", SPARK_NOW_ALPHA)
local SPARK_AREA_DOWN     = SparkTint("loss", SPARK_HISTORY_ALPHA)
local SPARK_AREA_DOWN_NOW = SparkTint("loss", SPARK_NOW_ALPHA)

-- Expose the width bounds so the settings slider stays in sync with the layout.
Window.DEFAULT_WIDTH = DEFAULT_WINDOW_WIDTH
Window.MIN_WIDTH = MIN_WINDOW_WIDTH
Window.MAX_WIDTH = MAX_WINDOW_WIDTH
Window.WIDTH_STEP = WINDOW_WIDTH_STEP

local GOLD_ICON = private.GOLD_ICON

-- Shared fee estimates used by the grand-total tooltip.
local FEE_LISTING_RATE = private.FEE_LISTING_RATE
local FEE_SALES_RATE   = private.FEE_SALES_RATE

-- Up/down arrows for the value-change delta. We use the game's own sort-arrow
-- textures rather than the Unicode ▲/▼ glyphs because the ESO UI font does not
-- render those reliably (they often show as blank or tofu). Inline textures
-- always draw, matching how the gold icon is embedded above.
local ARROW_UP = "|t16:16:EsoUI/Art/Miscellaneous/list_sortUp.dds|t"
local ARROW_DOWN = "|t16:16:EsoUI/Art/Miscellaneous/list_sortDown.dds|t"

-- Profession icons keyed by Valuation's category IDs; Other uses the Craft Bag icon.
local CATEGORY_ICONS = {
    blacksmithing = "esoui/art/icons/mapkey/mapkey_smithy.dds",
    clothier      = "esoui/art/icons/mapkey/mapkey_clothier.dds",
    woodworking   = "esoui/art/icons/mapkey/mapkey_woodworker.dds",
    jewelry       = "esoui/art/icons/mapkey/mapkey_jewelrycrafting.dds",
    alchemy       = "esoui/art/icons/mapkey/mapkey_alchemist.dds",
    enchanting    = "esoui/art/icons/mapkey/mapkey_enchanter.dds",
    provisioning  = "esoui/art/icons/mapkey/mapkey_inn.dds",
    other         = "esoui/art/inventory/inventory_tabicon_craftbag_up.dds",
}

-- Inline icon markup for a category, or empty string when it has none.
local function CategoryIcon(categoryId)
    local path = CATEGORY_ICONS[categoryId]
    if not path then
        return ""
    end
    return "|t18:18:" .. path .. "|t "
end

local Colorize = private.Colorize

-- Choose the gold tint from the highest value threshold met.
local GOLD_SCALE = {
    { floor = 10000000, color = "FFE9A0" },  -- 10M+  : bright warm gold
    { floor =  1000000, color = "F7DA63" },  -- 1M+   : rich gold
    { floor =   100000, color = "F4D03F" },  -- 100k+ : base gold tone
    { floor =    10000, color = "D8BF52" },  -- 10k+  : slightly muted gold
    { floor =        0, color = "B6A668" },  -- <10k  : dim gold
}

local function GoldScaleColor(amount)
    amount = amount or 0
    for i = 1, #GOLD_SCALE do
        if amount >= GOLD_SCALE[i].floor then
            return GOLD_SCALE[i].color
        end
    end
    return COLOR_GOLD
end

-- Shared gold formatter with an optional magnitude-based color override.
local FormatGold = private.FormatGold

-- "How long ago" for the footer, from a game-time-ms stamp to a short localized
-- phrase. Coarse buckets (now / seconds / minutes / hours) -- this is a feel,
-- not a stopwatch.
local function FormatTimeAgo(stampMs)
    if not stampMs then
        return GetString(SI_BMW_TIME_NEVER)
    end

    local deltaMs = GetGameTimeMilliseconds() - stampMs
    local seconds = zo_round(deltaMs / 1000)
    if seconds < 5 then
        return GetString(SI_BMW_TIME_JUST_NOW)
    elseif seconds < 60 then
        return stringformat(GetString(SI_BMW_TIME_SECONDS), seconds)
    elseif seconds < 3600 then
        return stringformat(GetString(SI_BMW_TIME_MINUTES), zo_round(seconds / 60))
    else
        return stringformat(GetString(SI_BMW_TIME_HOURS), zo_round(seconds / 3600))
    end
end

-- Cache account/character identity for the optional line below the total.
local cachedProfileText
local function GetProfileText()
    if cachedProfileText then
        return cachedProfileText
    end
    local account = GetDisplayName() or ""
    local character = zo_strformat(SI_UNIT_NAME, GetUnitName("player")) or ""
    if account ~= "" and character ~= "" then
        cachedProfileText = stringformat(GetString(SI_BMW_PROFILE_ACCOUNT_CHAR), account, character)
    else
        -- Fall back to whichever is available rather than an empty/orphaned "·".
        cachedProfileText = account ~= "" and account or character
    end
    return cachedProfileText
end

-- Runtime control references, created once in Initialize().
local windowControl   -- top-level container
local backdrop        -- background + border fill (toggled by appearance settings)
local headerBand      -- accent wash + underline behind the identity block
local profileLabel    -- account/character identity below the total
local totalLabel      -- prominent grand-total gold figure
local subtitleLabel   -- "<n> slots · <n> stacks · <n> items"
local versionNameLabel -- addon name in the top header
local dividerTop      -- line under the header block
local dividerBottom   -- line above the footer
-- Footer rows are two-column (muted label left, value right), mirroring the
-- category rows above. Each is a { container, label, value } record.
local footerInventoryRow -- "Inventory" -> "<ago>"
local footerPriceRefreshRow -- "Prices" -> "<ago>"
local footerPricesRow   -- "Coverage" -> "<n>/<n> · <source>" (or a warning)
local footerDeltaRow    -- "This visit"/"This session" -> "▲ <gold>" (hidden when none)
local footerGuidanceRow -- one contextual next-step prompt below the footer
-- History labels and pooled bars; refreshes reuse controls rather than recreate them.
local sparkCaption      -- muted "Value history" caption above the strip
local sparkHeadLabel    -- current value + trend arrow, right-aligned on the caption row
local sparkContainer    -- holds the filled strip; anchors the per-sample bars
local sparkScaleLabel   -- "min … max" scale line beneath the strip
local sparkBars = {}    -- pooled CT_BACKDROP bars, index 1..N
local sparkNowMarker    -- compact cap on the newest history sample
local rowPool         -- reusable category rows { container, name, gold, data }

-- Refresh cached footer timestamps/state while visible, without rebuilding the list.
local FOOTER_TICK_MS = 5000
local FOOTER_TIMER_NAME = addon.name .. "_FooterTick"
local PRICE_REFRESH_COMPLETE_HIGHLIGHT_MS = 5000
local TOTAL_GLOW_TICK_MS = 50
local TOTAL_GLOW_TIMER_NAME = addon.name .. "_TotalGlow"
local lastSnapshot  -- cached snapshot so the footer tick can re-read counts/time
local priceRefreshHovered = false

local function IsPriceRefreshRecentlyCompleted(snapshot)
    local completedMs = snapshot and snapshot.priceRefreshCompletedMs
    return completedMs ~= nil
        and GetGameTimeMilliseconds() - completedMs <= PRICE_REFRESH_COMPLETE_HIGHLIGHT_MS
end

local function GetSavedVars()
    return private.savedVars or {}
end

-- Hovering the grand total exposes its sale-fee tooltip. The effect is applied
-- directly to the label, never to a background or the whole header row.
local totalGlowActive = false
local function RenderTotalText()
    if totalLabel and lastSnapshot then
        totalLabel:SetText(FormatGold(lastSnapshot.gold,
            totalGlowActive and "FFE9A0" or nil))
    end
end

local function StopTotalGlow()
    EVENT_MANAGER:UnregisterForUpdate(TOTAL_GLOW_TIMER_NAME)
    totalGlowActive = false
    if totalLabel then
        totalLabel:SetAlpha(1)
        RenderTotalText()
    end
end

local function StartTotalGlow()
    if not totalLabel then
        return
    end

    totalGlowActive = true
    RenderTotalText()
    EVENT_MANAGER:UnregisterForUpdate(TOTAL_GLOW_TIMER_NAME)
    EVENT_MANAGER:RegisterForUpdate(TOTAL_GLOW_TIMER_NAME, TOTAL_GLOW_TICK_MS, function()
        local phase = GetGameTimeMilliseconds() / 700
        totalLabel:SetAlpha(0.92 + (mathsin(phase) + 1) * 0.04)
    end)
end

-- The window anchors to the left edge of the Craft Bag. In the guild store the
-- trading house's own browse pane (ZO_TradingHouseBrowseItemsLeftPane, ~265px)
-- sits in exactly that space, so the panel lands on top of it. When the trading
-- house scene is up we shift the window an extra amount left so it clears that
-- pane: the pane width plus a small gap, on top of the user's configured offset.
local GUILD_STORE_OFFSET_X = -375

local function IsGuildStoreShowing()
    return TRADING_HOUSE_SCENE ~= nil and TRADING_HOUSE_SCENE:IsShowing()
end

-- The configured window width, clamped to the supported range and snapped to the
-- slider step, with a safe fallback when nothing is saved yet. Every
-- width-dependent control reads this so a settings change re-flows consistently.
local function CurrentWidth()
    local width = GetSavedVars().windowWidth or DEFAULT_WINDOW_WIDTH
    if width < MIN_WINDOW_WIDTH then
        width = MIN_WINDOW_WIDTH
    elseif width > MAX_WINDOW_WIDTH then
        width = MAX_WINDOW_WIDTH
    end
    return width
end

-- Height of the header wash: the identity block (addon name + release line) plus
-- its top padding, closed by a little air beneath the last line so the accent
-- underline does not crowd the text it sits under. Derived rather than a constant
-- so a change to either line's height carries the band with it.
local function HeaderBandHeight()
    return PADDING + ADDON_NAME_HEIGHT + HEADER_BAND_PAD
end

-- Both of the panel's rules come from the shared builder, at the two shared
-- weights: STRONG under the header (it closes the identity block), SOFT above the
-- footer (it separates diagnostics from the table without competing with it).
local function CreateDivider(name, weight)
    return UI.CreateRule(name, windowControl, CurrentWidth() - PADDING * 2, weight)
end

-- Build a two-column footer row (muted label left, value right), mirroring the
-- category-row layout so the footer reads as part of the same table. Returns a
-- { container, label, value } record; widths track CurrentWidth() and are
-- re-applied by Window.ApplyWidth().
local function CreateFooterRow(name)
    local container = WINDOW_MANAGER:CreateControl(name, windowControl, CT_CONTROL)
    container:SetWidth(CurrentWidth() - PADDING * 2)
    container:SetHeight(FOOTER_LINE)
    container:SetAlpha(FOOTER_ALPHA)

    local label = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
    label:SetFont(FONT.small)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetAnchor(LEFT, container, LEFT, 0, 0)
    label:SetWidth((CurrentWidth() - PADDING * 2) * 0.42 - METRIC.GAP)
    label:SetMaxLineCount(1)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    local value = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
    value:SetFont(FONT.small)
    value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    value:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    value:SetAnchor(RIGHT, container, RIGHT, 0, 0)
    value:SetWidth((CurrentWidth() - PADDING * 2) * 0.58)
    value:SetMaxLineCount(1)
    value:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    return { container = container, label = label, value = value }
end

-- A single full-width action line appears only when the summary can point to a
-- concrete next step. Its trailing arrow makes it read as a game-style link,
-- not as another diagnostic metric.
local function CreateGuidanceRow(name)
    local container = WINDOW_MANAGER:CreateControl(name, windowControl, CT_CONTROL)
    container:SetWidth(CurrentWidth() - PADDING * 2)
    container:SetHeight(FOOTER_LINE)
    container:SetMouseEnabled(true)
    container:SetHidden(true)
    container:SetAlpha(0.84)

    local label = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
    label:SetFont(FONT.small)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetAnchor(LEFT, container, LEFT, 0, 0)
    label:SetWidth(CurrentWidth() - PADDING * 2 - 16)

    local arrow = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
    arrow:SetFont(FONT.small)
    arrow:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    arrow:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    arrow:SetAnchor(RIGHT, container, RIGHT, 0, 0)
    arrow:SetDimensions(12, FOOTER_LINE)
    arrow:SetText(Colorize(COLOR_ACCENT, ">"))

    return { container = container, label = label, arrow = arrow, action = nil }
end

-- Build (or fetch from the pool) the Nth category row. Each row is a mouse-
-- enabled container with a left name label and a right gold label; the
-- container carries the row's data and shows a detail tooltip on hover. Rows
-- are pooled and reused across renders so a refresh never churns controls.
local function AcquireRow(index)
    local existing = rowPool[index]
    if existing then
        return existing
    end

    local container = WINDOW_MANAGER:CreateControl(
        addon.name .. "_Row" .. index, windowControl, CT_CONTROL)
    container:SetWidth(CurrentWidth() - PADDING * 2)
    container:SetHeight(ROW_HEIGHT)
    container:SetMouseEnabled(true)

    -- Hover wash, created first so it sits behind the row's own labels. The rows
    -- are clickable (they open the detail window), and until now nothing said so
    -- until the tooltip appeared; this is the same accent wash the detail and
    -- withdraw tables use, so a hover means the same thing everywhere.
    local shareFill = UI.CreateFill(nil, container, UI.CHROME.CATEGORY_SHARE)
    shareFill:SetHeight(2)
    shareFill:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, LEADER_MARKER_WIDTH + 5, -1)
    shareFill:SetHidden(true)

    local hoverFill = UI.CreateHoverFill(nil, container)

    local leaderMarker = WINDOW_MANAGER:CreateControl(nil, container, CT_TEXTURE)
    leaderMarker:SetDimensions(LEADER_MARKER_WIDTH, 16)
    leaderMarker:SetAnchor(LEFT, container, LEFT, 0, 0)
    leaderMarker:SetColor(unpack(LEADER_MARKER_COLOR))
    leaderMarker:SetHidden(true)

    local nameLabel = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
    nameLabel:SetFont(FONT.body)
    nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    nameLabel:SetAnchor(LEFT, container, LEFT, LEADER_MARKER_WIDTH + 5, -2)
    nameLabel:SetWidth((CurrentWidth() - PADDING * 2) * 0.60 - LEADER_MARKER_WIDTH - 13)
    nameLabel:SetMaxLineCount(1)
    nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    local goldLabel = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
    goldLabel:SetFont(FONT.body)
    goldLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    goldLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    goldLabel:SetAnchor(RIGHT, container, RIGHT, 0, -2)
    goldLabel:SetWidth((CurrentWidth() - PADDING * 2) * 0.40)
    goldLabel:SetMaxLineCount(1)
    goldLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    local row = {
        container = container,
        name = nameLabel,
        gold = goldLabel,
        leaderMarker = leaderMarker,
        shareFill = shareFill,
        hoverFill = hoverFill,
    }

    -- Hover: a standard InformationTooltip with the per-category detail. Anchored
    -- to the left of the row since the window itself sits left of the craft bag.
    container:SetHandler("OnMouseEnter", function(self)
        local data = row.data
        if not data then
            return
        end
        row.hoverFill:SetHidden(false)
        InitializeTooltip(InformationTooltip, self, TOPRIGHT, -6, 0, BOTTOMRIGHT)
        -- Composed entirely from the shared tooltip voice: an accent title, then
        -- one line per fact whose tone names the KIND of fact it carries (a gold
        -- figure, a take-home figure, a plain count, a warning), and a caption for
        -- the click hint. No colour is decided here.
        UI.TipTitle(InformationTooltip, data.name)
        if data.isPriceTrend then
            UI.TipLine(InformationTooltip, stringformat(
                GetString(SI_BMW_PRICE_TREND_TOOLTIP_WINDOW), data.threshold), "soft")
            UI.TipLine(InformationTooltip, stringformat(
                GetString(SI_BMW_PRICE_TREND_TOOLTIP_GAINS), data.gains), "gain")
            UI.TipLine(InformationTooltip, stringformat(
                GetString(SI_BMW_PRICE_TREND_TOOLTIP_LOSSES), data.losses), "loss")
            UI.TipDivider(InformationTooltip)
            UI.TipCaption(InformationTooltip, GetString(SI_BMW_PRICE_TREND_CLICK_HINT), "accent")
            return
        end
        if row.isLeader then
            UI.TipLine(InformationTooltip, GetString(SI_BMW_TOOLTIP_TOP_CATEGORY), "accent")
            UI.TipDivider(InformationTooltip)
        end
        UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_TOOLTIP_VALUE),
            FormatGold(data.gold)), "gold")
        -- Net if sold through a guild trader (after the 1% + 7% fees). Only shown
        -- when there's a value to net down; the accent tone marks it as the
        -- take-home figure, matching the grand-total hover.
        if data.gold and data.gold > 0 then
            UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_TOOLTIP_NET),
                FormatGold(private.NetAfterFees(data.gold))), "accent")
        end
        UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_TOOLTIP_SLOTS),
            data.slots), "soft")
        UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_TOOLTIP_STACKS),
            ZO_LocalizeDecimalNumber(data.stacks)), "soft")
        UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_TOOLTIP_ITEMS),
            ZO_LocalizeDecimalNumber(data.items)), "soft")
        if data.unpricedSlots > 0 then
            UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_TOOLTIP_UNPRICED),
                data.unpricedSlots), "warn")
        end
        -- Hint that the row is clickable for the full per-material breakdown.
        UI.TipDivider(InformationTooltip)
        UI.TipCaption(InformationTooltip, GetString(SI_BMW_TOOLTIP_CLICK_HINT), "accent")
    end)
    container:SetHandler("OnMouseExit", function()
        row.hoverFill:SetHidden(true)
        ClearTooltip(InformationTooltip)
    end)

    -- Click opens the per-category material detail window. CT_CONTROL containers
    -- don't fire OnClicked, so use OnMouseUp gated on the release landing inside.
    container:SetHandler("OnMouseUp", function(self, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not upInside then
            return
        end
        local data = row.data
        if not data then
            return
        end
        local detail = addon.DetailWindow
        if detail then
            if data.isPriceTrend then
                detail.ShowPriceTrends()
            else
                detail.Show(data.id, data.name)
            end
        end
    end)

    rowPool[index] = row
    return row
end

function Window.Initialize()
    if windowControl then
        return
    end

    ROW_HEIGHT = UI.RowHeight("category")
    rowPool = {}

    windowControl = WINDOW_MANAGER:CreateTopLevelWindow(addon.name .. "_Window")
    windowControl:SetClampedToScreen(true)
    windowControl:SetDimensions(CurrentWidth(), 120)
    windowControl:SetHidden(true)
    -- Make the panel itself opaque to the mouse. The child rows enable the mouse
    -- on their own containers (that is what gives them hover and click), so this
    -- is not what powers the row tooltips -- it is what stops a click on the
    -- panel's own background/padding from falling through to whatever sits
    -- underneath it. Without it the strip between rows is a hole in the window.
    windowControl:SetMouseEnabled(true)

    Window.ApplyAnchor()

    backdrop = WINDOW_MANAGER:CreateControl(addon.name .. "_Backdrop", windowControl, CT_BACKDROP)
    backdrop:SetAnchorFill(windowControl)

    -- The shared letterhead: a brass wash behind the addon name,
    -- closed by a fine rule. Created before those labels so it sits
    -- behind them, and spanning the full window width (not the inner width) so it
    -- reads as a band across the panel rather than a floating rectangle.
    headerBand = UI.CreateHeaderBand(addon.name .. "_HeaderBand", windowControl,
        CurrentWidth(), HeaderBandHeight())
    headerBand:SetAnchor(TOPLEFT, windowControl, TOPLEFT, 0, 0)

    Window.ApplyAppearance()

    versionNameLabel = WINDOW_MANAGER:CreateControl(addon.name .. "_VersionName", windowControl, CT_LABEL)
    versionNameLabel:SetFont(FONT.heading)
    versionNameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    versionNameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    versionNameLabel:SetAlpha(1)
    versionNameLabel:SetWidth(CurrentWidth() - PADDING * 2)
    versionNameLabel:SetHeight(ADDON_NAME_HEIGHT)
    versionNameLabel:SetText(Colorize(UI.HEX.brass, GetString(SI_BMW_WINDOW_ADDON_NAME)))
    versionNameLabel:SetAnchor(TOPLEFT, windowControl, TOPLEFT, PADDING, PADDING)

    -- Account/character identity follows the bag composition line.
    profileLabel = WINDOW_MANAGER:CreateControl(addon.name .. "_Profile", windowControl, CT_LABEL)
    profileLabel:SetFont(FONT.small)
    profileLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    profileLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    profileLabel:SetAlpha(0.78)
    profileLabel:SetMaxLineCount(1)
    profileLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    profileLabel:SetWidth(CurrentWidth() - PADDING * 2)
    profileLabel:SetHeight(PROFILE_HEIGHT)

    totalLabel = WINDOW_MANAGER:CreateControl(addon.name .. "_Total", windowControl, CT_LABEL)
    totalLabel:SetFont(FONT.hero)
    totalLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    totalLabel:SetDimensions(CurrentWidth() - PADDING * 2, TOTAL_HEIGHT)
    totalLabel:SetAnchor(TOPLEFT, versionNameLabel, BOTTOMLEFT, 0, TITLE_TO_TOTAL_GAP)
    -- Hover the grand total for the "net if sold" breakdown: the guild-store
    -- listing fee (1%) and sales tax (7%) itemized, then the gold left after both.
    -- The Craft Bag total is valued at market/list price, so this answers "what
    -- would I actually pocket selling all of this through a guild trader".
    totalLabel:SetMouseEnabled(true)
    totalLabel:SetHandler("OnMouseEnter", function(self)
        StartTotalGlow()
        local gross = lastSnapshot and lastSnapshot.gold or 0
        if gross <= 0 then
            return
        end
        local listing = gross * FEE_LISTING_RATE
        local sales = gross * FEE_SALES_RATE
        local net = private.NetAfterFees(gross)

        InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 6, BOTTOMLEFT)
        UI.TipTitle(InformationTooltip, GetString(SI_BMW_NET_TOOLTIP_TITLE))
        -- Gross (list price), then each fee as a deduction, then the net below a
        -- divider: fees carry the warning tone because they are money leaving, the
        -- net carries the accent because it is the answer the hover exists for.
        UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_NET_TOOLTIP_GROSS),
            FormatGold(gross)), "soft")
        UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_NET_TOOLTIP_LISTING),
            FormatGold(listing)), "warn")
        UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_NET_TOOLTIP_SALES),
            FormatGold(sales)), "warn")
        UI.TipDivider(InformationTooltip)
        UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_NET_TOOLTIP_NET),
            FormatGold(net)), "accent")
        UI.TipDivider(InformationTooltip)
        UI.TipCaption(InformationTooltip, GetString(SI_BMW_NET_TOOLTIP_CLICK), "accent")
    end)
    totalLabel:SetHandler("OnMouseExit", function()
        StopTotalGlow()
        ClearTooltip(InformationTooltip)
    end)
    totalLabel:SetHandler("OnMouseUp", function(_, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not upInside then
            return
        end
        local detail = addon.DetailWindow
        if detail and detail.ShowAll then
            detail.ShowAll()
        end
    end)

    subtitleLabel = WINDOW_MANAGER:CreateControl(addon.name .. "_Subtitle", windowControl, CT_LABEL)
    subtitleLabel:SetFont(FONT.small)
    subtitleLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    subtitleLabel:SetAlpha(0.78)
    subtitleLabel:SetAnchor(TOPLEFT, profileLabel, BOTTOMLEFT, 0, PROFILE_TO_SUBTITLE_GAP)
    subtitleLabel:SetWidth(CurrentWidth() - PADDING * 2)
    profileLabel:SetAnchor(TOPLEFT, totalLabel, BOTTOMLEFT, 0, TOTAL_TO_PROFILE_GAP)

    dividerTop = CreateDivider(addon.name .. "_DividerTop", "strong")
    dividerBottom = CreateDivider(addon.name .. "_DividerBottom", "soft")

    footerInventoryRow = CreateFooterRow(addon.name .. "_FooterInventory")
    footerPriceRefreshRow = CreateFooterRow(addon.name .. "_FooterPriceRefresh")
    footerPricesRow = CreateFooterRow(addon.name .. "_FooterPrices")
    footerDeltaRow = CreateFooterRow(addon.name .. "_FooterDelta")
    footerGuidanceRow = CreateGuidanceRow(addon.name .. "_FooterGuidance")

    -- The prices-age row is the in-panel counterpart of /bmw refresh: a click
    -- clears the session price cache and re-queries LibPrice, which is the usual
    -- next step after MM/TTC finishes importing. Hover explains; the "X ago"
    -- value jumping to "just now" is the completion signal.
    footerPriceRefreshRow.container:SetMouseEnabled(true)
    footerPriceRefreshRow.container:SetHandler("OnMouseUp", function(_, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not upInside then
            return
        end
        if lastSnapshot and lastSnapshot.priceRefreshPending then
            return
        end
        local valuation = addon.Valuation
        if valuation and valuation.ForceRefresh then
            valuation.ForceRefresh()
        end
    end)
    footerPriceRefreshRow.container:SetHandler("OnMouseEnter", function(self)
        priceRefreshHovered = true
        footerPriceRefreshRow.container:SetAlpha(1)
        InitializeTooltip(InformationTooltip, self, TOPRIGHT, -6, 0, BOTTOMRIGHT)
        UI.TipTitle(InformationTooltip, GetString(SI_BMW_FOOTER_PRICES_TOOLTIP_TITLE))
        UI.TipLine(InformationTooltip, GetString(SI_BMW_FOOTER_PRICES_TOOLTIP_BODY), "soft")
        UI.TipCaption(InformationTooltip, GetString(
            lastSnapshot and lastSnapshot.priceRefreshPending
                and SI_BMW_FOOTER_PRICES_TOOLTIP_BUSY
                or SI_BMW_FOOTER_PRICES_TOOLTIP_CLICK), "accent")
    end)
    footerPriceRefreshRow.container:SetHandler("OnMouseExit", function()
        priceRefreshHovered = false
        local highlighted = lastSnapshot and (lastSnapshot.priceRefreshPending
            or IsPriceRefreshRecentlyCompleted(lastSnapshot))
        footerPriceRefreshRow.container:SetAlpha(highlighted and 1 or FOOTER_ALPHA)
        ClearTooltip(InformationTooltip)
    end)

    footerPricesRow.container:SetMouseEnabled(true)
    footerPricesRow.container:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then
            return
        end
        if not lastSnapshot or (lastSnapshot.unpricedSlots or 0) <= 0 then
            return
        end
        local detail = addon.DetailWindow
        if detail and detail.ShowUnpriced then
            detail.ShowUnpriced()
        end
    end)
    footerPricesRow.container:SetHandler("OnMouseEnter", function(self)
        if not lastSnapshot or (lastSnapshot.unpricedSlots or 0) <= 0 then
            return
        end
        InitializeTooltip(InformationTooltip, self, TOPRIGHT, -6, 0, BOTTOMRIGHT)
        UI.TipTitle(InformationTooltip, GetString(SI_BMW_FOOTER_COVERAGE_LABEL))
        UI.TipLine(InformationTooltip, GetString(SI_BMW_FOOTER_COVERAGE_UNPRICED_HINT), "warn")
    end)
    footerPricesRow.container:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    -- The existing visit-delta row doubles as the entry point to its explanation:
    -- hover separates material movement from price revaluation; click opens the
    -- normal detail window with the material movements, not a new UI surface.
    footerDeltaRow.container:SetMouseEnabled(true)
    footerDeltaRow.container:SetHandler("OnMouseUp", function(_, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not upInside then
            return
        end
        local detail = addon.DetailWindow
        local valuation = addon.Valuation
        if detail and detail.ShowVisitDiff and valuation and valuation.GetLastVisitDeltaDetails
            and valuation.GetLastVisitDeltaDetails() then
            detail.ShowVisitDiff()
            if valuation.AcknowledgeVisitDelta then
                valuation.AcknowledgeVisitDelta()
            end
        end
    end)
    footerDeltaRow.container:SetHandler("OnMouseEnter", function(self)
        local valuation = addon.Valuation
        local details = valuation and valuation.GetLastVisitDeltaDetails
            and valuation.GetLastVisitDeltaDetails() or nil
        if not details then
            return
        end
        InitializeTooltip(InformationTooltip, self, TOPRIGHT, -6, 0, BOTTOMRIGHT)
        UI.TipTitle(InformationTooltip, GetString(SI_BMW_FOOTER_DELTA_TOOLTIP_TITLE))
        local function SignedAmount(value)
            local sign = value >= 0 and "+" or "-"
            return sign .. FormatGold(mathabs(value))
        end
        -- The two causes of a change, then the caveat and the call to action: the
        -- explanatory lines drop to captions so the two figures stay the subject.
        UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_FOOTER_DELTA_TOOLTIP_STOCK),
            SignedAmount(details.quantityGold or 0)), "soft")
        UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_FOOTER_DELTA_TOOLTIP_PRICES),
            SignedAmount(details.priceGold or 0)), "soft")
        UI.TipCaption(InformationTooltip, GetString(SI_BMW_FOOTER_DELTA_TOOLTIP_ACCUMULATION))
        UI.TipCaption(InformationTooltip, GetString(SI_BMW_FOOTER_DELTA_TOOLTIP_CLICK), "accent")
    end)
    footerDeltaRow.container:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    footerGuidanceRow.container:SetHandler("OnMouseUp", function(_, button, upInside)
        if button == MOUSE_BUTTON_INDEX_LEFT and upInside and footerGuidanceRow.action then
            footerGuidanceRow.action()
        end
    end)
    footerGuidanceRow.container:SetHandler("OnMouseEnter", function()
        footerGuidanceRow.container:SetAlpha(1)
    end)
    footerGuidanceRow.container:SetHandler("OnMouseExit", function()
        footerGuidanceRow.container:SetAlpha(0.84)
    end)

    -- Value-history area chart: a muted caption with a filled strip beneath it,
    -- a current-value + trend head on the caption row, and a min/max scale line
    -- below. The bars themselves are created lazily by RenderSparkline so the
    -- strip is sized to whatever data exists.
    sparkCaption = WINDOW_MANAGER:CreateControl(addon.name .. "_SparkCaption", windowControl, CT_LABEL)
    sparkCaption:SetFont(FONT.small)
    sparkCaption:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    sparkCaption:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    sparkCaption:SetHeight(FOOTER_LINE)

    -- Current value + trend arrow, right-aligned to sit opposite the caption.
    sparkHeadLabel = WINDOW_MANAGER:CreateControl(addon.name .. "_SparkHead", windowControl, CT_LABEL)
    sparkHeadLabel:SetFont(FONT.small)
    sparkHeadLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    sparkHeadLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    sparkHeadLabel:SetHeight(FOOTER_LINE)

    sparkContainer = WINDOW_MANAGER:CreateControl(addon.name .. "_SparkStrip", windowControl, CT_CONTROL)
    sparkContainer:SetHeight(SPARK_HEIGHT)
    sparkContainer:SetMouseEnabled(true)

    sparkNowMarker = UI.CreateFill(addon.name .. "_SparkNow", sparkContainer, SPARK_AREA_UP_NOW)
    sparkNowMarker:SetDimensions(SPARK_MARKER_WIDTH, SPARK_MARKER_HEIGHT)
    sparkNowMarker:SetDrawLevel(2)
    sparkNowMarker:SetHidden(true)

    -- Min/max scale line beneath the strip: the series value range, centered so
    -- it reads as a caption for the whole silhouette rather than hugging one edge.
    sparkScaleLabel = WINDOW_MANAGER:CreateControl(addon.name .. "_SparkScale", windowControl, CT_LABEL)
    sparkScaleLabel:SetFont(FONT.small)
    sparkScaleLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    sparkScaleLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    -- Hover: summarize the series (oldest -> newest value and the change) so the
    -- bars get exact figures on demand without crowding the strip with text.
    sparkContainer:SetHandler("OnMouseEnter", function(self)
        local valuation = addon.Valuation
        local points = (valuation and valuation.GetValueHistory) and valuation.GetValueHistory() or {}
        if #points < 2 then
            return
        end
        local first, last = points[1], points[#points]
        InitializeTooltip(InformationTooltip, self, TOPRIGHT, -6, 0, BOTTOMRIGHT)
        UI.TipTitle(InformationTooltip, GetString(SI_BMW_FOOTER_HISTORY_LABEL))
        UI.TipLine(InformationTooltip,
            stringformat(GetString(SI_BMW_HISTORY_TOOLTIP_POINTS), #points), "soft")
        UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_HISTORY_TOOLTIP_OLDEST),
            FormatGold(first.gold or 0)), "soft")
        UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_HISTORY_TOOLTIP_NEWEST),
            FormatGold(last.gold or 0)), "gold")
        local change = (last.gold or 0) - (first.gold or 0)
        UI.TipLine(InformationTooltip, stringformat(GetString(SI_BMW_HISTORY_TOOLTIP_CHANGE),
            FormatGold(change)), change < 0 and "loss" or "gain")
    end)
    sparkContainer:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)
end

-- Render just the footer text from the cached snapshot. Split out so the
-- low-frequency tick can refresh the "updated X ago" line without re-laying-out
-- the whole window. Each footer row is two columns: a muted label on the left
-- and the value on the right, matching the category rows above.
local function RenderFooter()
    if not lastSnapshot then
        return
    end

    -- Keep the inventory calculation and the underlying price lookup separate:
    -- a deposit can revalue the bag immediately without making market data newer.
    footerInventoryRow.label:SetText(Colorize(COLOR_MUTED, GetString(SI_BMW_FOOTER_INVENTORY_LABEL)))
    footerInventoryRow.value:SetText(Colorize(COLOR_MUTED,
        FormatTimeAgo(lastSnapshot.lastInventoryUpdateMs)))
    local priceRefreshPending = lastSnapshot.priceRefreshPending == true
    local priceRefreshCompleted = not priceRefreshPending
        and IsPriceRefreshRecentlyCompleted(lastSnapshot)
    local priceRefreshHighlighted = priceRefreshPending or priceRefreshCompleted
    footerPriceRefreshRow.label:SetText(Colorize(
        priceRefreshHighlighted and COLOR_ACCENT or COLOR_MUTED,
        GetString(SI_BMW_FOOTER_PRICES_LABEL)))
    if priceRefreshPending then
        footerPriceRefreshRow.value:SetText(Colorize(COLOR_ACCENT,
            GetString(SI_BMW_FOOTER_PRICES_REFRESHING)))
    elseif priceRefreshCompleted then
        footerPriceRefreshRow.value:SetText(Colorize(COLOR_ACCENT,
            GetString(SI_BMW_FOOTER_PRICES_REFRESHED)))
    else
        footerPriceRefreshRow.value:SetText(Colorize(COLOR_MUTED,
            FormatTimeAgo(lastSnapshot.lastPriceRefreshMs)))
    end
    footerPriceRefreshRow.container:SetAlpha(
        (priceRefreshHovered or priceRefreshHighlighted) and 1 or FOOTER_ALPHA)

    -- Coverage -> "<priced>/<slots> · <source>", or a warning when unpriced.
    -- The source is shown compactly (MM/TTC/ATT) to fit the value column; when
    -- more than half the slots are unpriced the total is unreliable, so the row
    -- turns amber and drops the source as noise.
    local slots = lastSnapshot.slots or 0
    local unpriced = lastSnapshot.unpricedSlots or 0
    local priced = slots - unpriced
    local coveragePercent = slots > 0 and zo_round(priced / slots * 100) or 0
    local coverageText = stringformat(GetString(SI_BMW_ROW_PERCENT), coveragePercent)

    local function SourceSuffix()
        if lastSnapshot.sourceShort then
            local s = " · " .. lastSnapshot.sourceShort
            if lastSnapshot.sourceHasOthers then
                s = s .. "+"
            end
            return s
        end
        return ""
    end

    footerPricesRow.label:SetText(Colorize(COLOR_MUTED, GetString(SI_BMW_FOOTER_COVERAGE_LABEL)))
    if unpriced > 0 and slots > 0 and (unpriced * 2 > slots) then
        -- Low coverage: loud warning in place of the usual count.
        footerPricesRow.value:SetText(Colorize(COLOR_WARN,
            stringformat(GetString(SI_BMW_FOOTER_LOW_COVERAGE), unpriced, slots)
                .. " · " .. coverageText))
    else
        local countColor = unpriced > 0 and COLOR_WARN or COLOR_MUTED
        local countText = stringformat(GetString(SI_BMW_FOOTER_COVERAGE_VALUE), priced, slots)
            .. " · " .. coverageText
        footerPricesRow.value:SetText(
            Colorize(countColor, countText) .. Colorize(COLOR_MUTED, SourceSuffix()))
    end

    -- Value-change delta. Hidden until stock differs from the last acknowledged
    -- state; clicking it opens the breakdown and begins a new accumulation period.
    local delta = lastSnapshot.delta
    -- Show the row for any pending change, including an even material swap whose
    -- gold delta is exactly zero: it still needs to be reviewable so that
    -- clicking it can advance the baseline.
    if lastSnapshot.deltaPending or (delta and delta ~= 0) then
        local amount = delta or 0
        local labelKey = lastSnapshot.deltaMode == "session"
            and SI_BMW_FOOTER_DELTA_LABEL_SESSION or SI_BMW_FOOTER_DELTA_LABEL
        footerDeltaRow.container:SetHidden(false)
        footerDeltaRow.label:SetText(Colorize(COLOR_MUTED, GetString(labelKey)))

        local magnitude = ZO_LocalizeDecimalNumber(zo_round(mathabs(amount)))
        local valueText = stringformat(GetString(SI_BMW_FOOTER_DELTA_VALUE),
            magnitude .. " " .. GOLD_ICON)
        if amount == 0 then
            -- Composition changed but the value did not: no direction to point,
            -- so render it neutral rather than implying a gain or a loss.
            footerDeltaRow.value:SetText(Colorize(COLOR_MUTED, valueText))
        else
            local gain = amount > 0
            local color = gain and COLOR_GAIN or COLOR_LOSS
            local arrow = gain and ARROW_UP or ARROW_DOWN
            -- The arrow texture carries the direction; the number is colored, the
            -- texture left outside Colorize since textures aren't tinted.
            footerDeltaRow.value:SetText(arrow .. " " .. Colorize(color, valueText))
        end
    else
        footerDeltaRow.container:SetHidden(true)
    end
end

-- Reserve the extra guidance row for a condition that compromises the valuation.
-- Ordinary navigation belongs to the category rows and detail window instead.
local function RenderGuidance(snapshot)
    local row = footerGuidanceRow
    row.action = nil

    local unpriced = snapshot.unpricedSlots or 0
    if unpriced > 0 then
        row.label:SetText(Colorize(COLOR_WARN, stringformat(
            GetString(SI_BMW_FOOTER_GUIDANCE_UNPRICED), unpriced)))
        row.arrow:SetText(Colorize(COLOR_WARN, ">"))
        row.action = function()
            local detail = addon.DetailWindow
            if detail and detail.ShowUnpriced then
                detail.ShowUnpriced()
            end
        end
    else
        row.arrow:SetText(Colorize(COLOR_ACCENT, ">"))
    end

    row.container:SetHidden(row.action == nil)
end

-- Acquire (or create) the Nth chart bar, a flat fill bottom-anchored in the strip
-- so its height grows upward. Pooled and reused across renders so a refresh
-- re-points existing bars instead of creating new controls. The bar is the same
-- shared flat-rectangle primitive the bands, rules and washes are built from --
-- it is simply the one whose colour is data rather than chrome, so it is created
-- with the neutral history tint and repainted per render.
local function AcquireSparkBar(index)
    local bar = sparkBars[index]
    if bar then
        return bar
    end

    bar = UI.CreateFill(addon.name .. "_SparkBar" .. index, sparkContainer, SPARK_AREA_UP)
    sparkBars[index] = bar
    return bar
end

-- Draw the value-history area chart from the recorded samples. Each sample is one
-- vertical bar whose height is its gold value normalized between the series
-- min/max; bars are drawn edge-to-edge (no gap) so they read as a filled
-- silhouette rather than separate bars. The whole fill is tinted by the series'
-- overall direction (green when the newest sample is at or above the oldest, red
-- when below), with the newest bar brightened so "now" stands out. The head label
-- (current value + trend arrow) and the min/max scale line are filled here too,
-- so the chart carries scale and direction the old bar strip lacked. Returns the
-- total height consumed (strip + scale line, 0 when hidden or there's nothing
-- meaningful to show) so the caller can advance its layout cursor. A flat series
-- (min == max) draws all bars at full height rather than dividing by zero.
local function RenderSparkline(innerWidth)
    local valuation = addon.Valuation
    local points = (valuation and valuation.GetValueHistory) and valuation.GetValueHistory() or {}

    -- Need at least two points for a trend to mean anything; below that hide the
    -- whole block (caption + head + strip + scale) and report zero consumed height.
    if #points < 2 then
        sparkCaption:SetHidden(true)
        sparkHeadLabel:SetHidden(true)
        sparkContainer:SetHidden(true)
        sparkScaleLabel:SetHidden(true)
        sparkNowMarker:SetHidden(true)
        for i = 1, #sparkBars do
            sparkBars[i]:SetHidden(true)
        end
        return 0
    end

    sparkCaption:SetHidden(false)
    sparkHeadLabel:SetHidden(false)
    sparkContainer:SetHidden(false)
    sparkScaleLabel:SetHidden(false)
    sparkCaption:SetText(Colorize(COLOR_MUTED, GetString(SI_BMW_FOOTER_HISTORY_LABEL)))

    local count = #points

    -- A bar is never narrower than one pixel, so a series with more samples than
    -- the strip has pixels would sum up wider than its container and spill past
    -- the panel edge. VALUE_HISTORY_CAPACITY (90) fits comfortably inside the
    -- narrowest supported panel (MIN_WINDOW_WIDTH 460 minus padding), but nothing
    -- enforced that pairing: raising the capacity or lowering the minimum width
    -- silently broke the layout. Clamp to what fits and drop the oldest samples
    -- beyond it, so the chart degrades to a shorter time window instead.
    local maxBars = zo_round(innerWidth)
    if maxBars < 2 then
        maxBars = 2
    end
    local firstIndex = 1
    if count > maxBars then
        firstIndex = count - maxBars + 1
    end
    local drawn = count - firstIndex + 1

    local minGold, maxGold = points[firstIndex].gold or 0, points[firstIndex].gold or 0
    for i = firstIndex + 1, count do
        local g = points[i].gold or 0
        if g < minGold then minGold = g end
        if g > maxGold then maxGold = g end
    end
    local span = maxGold - minGold

    -- Overall trend across the drawn window decides the fill tint: the newest
    -- sample at or above the oldest reads as a gain (green), below as a loss (red).
    local firstGold = points[firstIndex].gold or 0
    local lastGold = points[count].gold or 0
    local rising = lastGold >= firstGold
    local fillColor = rising and SPARK_AREA_UP or SPARK_AREA_DOWN
    local nowColor = rising and SPARK_AREA_UP_NOW or SPARK_AREA_DOWN_NOW

    -- Bars fill the strip edge-to-edge so the series reads as one shape. Width is
    -- the exact per-sample slot; left edges are placed at rounded slot boundaries
    -- and each bar is widened to meet the next so rounding leaves no seams.
    local slot = innerWidth / drawn

    for i = firstIndex, count do
        local barIndex = i - firstIndex + 1
        local bar = AcquireSparkBar(barIndex)
        local gold = points[i].gold or 0
        -- Normalize 0..1 within the series; a flat series pins to full height.
        local frac = span > 0 and (gold - minGold) / span or 1
        local height = SPARK_MIN_BAR_H + frac * (SPARK_HEIGHT - SPARK_MIN_BAR_H)

        UI.PaintFill(bar, (i == count) and nowColor or fillColor)

        -- Edge-to-edge: this bar spans from its slot boundary to the next, so the
        -- rounded left edges abut with no gap.
        local left = zo_round((barIndex - 1) * slot)
        local right = zo_round(barIndex * slot)
        local barWidth = right - left
        if barWidth < 1 then
            barWidth = 1
        end
        bar:SetWidth(barWidth)
        bar:SetHeight(zo_round(height))
        bar:ClearAnchors()
        -- Bottom-aligned so taller bars rise from a shared baseline.
        bar:SetAnchor(BOTTOMLEFT, sparkContainer, BOTTOMLEFT, left, 0)
        bar:SetHidden(false)
    end

    -- Hide any pooled bars left from a previous (longer) series.
    for i = drawn + 1, #sparkBars do
        sparkBars[i]:SetHidden(true)
    end

    local newestBar = sparkBars[drawn]
    UI.PaintFill(sparkNowMarker, nowColor)
    sparkNowMarker:ClearAnchors()
    sparkNowMarker:SetAnchor(TOPRIGHT, newestBar, TOPRIGHT, 0, 0)
    sparkNowMarker:SetHidden(false)

    -- Head: current value + trend arrow + gold icon, colored by direction. The
    -- arrow and gold icon are textures (left outside Colorize, since textures
    -- aren't tinted); only the number is colored. Matches FormatGold's idiom.
    local headColor = rising and COLOR_GAIN or COLOR_LOSS
    local headArrow = rising and ARROW_UP or ARROW_DOWN
    local trendText = ""
    if firstGold > 0 then
        local trendPercent = mathabs((lastGold - firstGold) / firstGold * 100)
        trendText = " · " .. Colorize(headColor,
            stringformat(GetString(SI_BMW_DETAIL_GROWTH), stringformat("%.1f", trendPercent)))
    end
    sparkHeadLabel:SetText(headArrow .. " " ..
        Colorize(COLOR_MUTED, ZO_LocalizeDecimalNumber(zo_round(lastGold))) .. " "
        .. GOLD_ICON .. trendText)

    -- Scale line: the series value range as "min - max" (plain hyphen), centered
    -- under the strip. Stated as a range rather than edge-pinned labels because
    -- the leftmost/rightmost bars are the oldest/newest samples, not necessarily
    -- the min/max.
    sparkScaleLabel:SetText(Colorize(COLOR_MUTED, stringformat(GetString(SI_BMW_HISTORY_SCALE),
        ZO_LocalizeDecimalNumber(zo_round(minGold)),
        ZO_LocalizeDecimalNumber(zo_round(maxGold)))))

    return SPARK_HEIGHT + SPARK_SCALE_GAP + FOOTER_LINE
end

local function HeaderContentHeight()
    return PADDING + ADDON_NAME_HEIGHT + TITLE_TO_TOTAL_GAP + TOTAL_HEIGHT + TOTAL_TO_PROFILE_GAP
        + PROFILE_HEIGHT + PROFILE_TO_SUBTITLE_GAP + SUBTITLE_HEIGHT
end

-- Re-render the window from the current valuation. Pure presentation: it reads
-- the already-computed snapshot (no scanning here) and lays out only the rows
-- it needs, resizing the window to fit. Cheap enough to call on every coalesced
-- refresh.
function Window.Update()
    if not windowControl then
        return
    end

    local valuation = addon.Valuation
    if not valuation then
        return
    end

    local sv = GetSavedVars()
    local snapshot = valuation.GetSnapshot(sv.sortByValue == true)
    lastSnapshot = snapshot
    RenderGuidance(snapshot)

    -- Header block: prominent total + subtitle counts.
    RenderTotalText()

    -- Account/character identity on the title line (optional). The Craft Bag is
    -- account-wide, so the @account handle names whose bag this is; the character
    -- is profile flavor. Text is cached (stable per session), so this is cheap.
    if sv.showProfile ~= false then
        profileLabel:SetHidden(false)
        profileLabel:SetText(Colorize(COLOR_MUTED, GetProfileText()))
    else
        profileLabel:SetHidden(true)
    end

    if snapshot.slots > 0 then
        subtitleLabel:SetHidden(false)
        subtitleLabel:SetText(Colorize(COLOR_MUTED, stringformat(
            GetString(SI_BMW_WINDOW_SUBTITLE),
            snapshot.slots,
            ZO_LocalizeDecimalNumber(snapshot.stacks),
            ZO_LocalizeDecimalNumber(snapshot.items))))
    else
        subtitleLabel:SetHidden(false)
        subtitleLabel:SetText(Colorize(COLOR_MUTED, GetString(SI_BMW_WINDOW_EMPTY)))
    end

    local y = HeaderContentHeight()

    -- Divider under the header.
    y = y + HEADER_TO_DIVIDER_GAP
    dividerTop:ClearAnchors()
    dividerTop:SetAnchor(TOPLEFT, windowControl, TOPLEFT, PADDING, y)
    y = y + DIVIDER_GAP

    -- Category rows (optional). Each shows name + gold; hover reveals the detail.
    local rowCount = 0
    local showBreakdown = sv.showCategoryBreakdown ~= false
    local showIcons = sv.showCategoryIcons ~= false
    local colorScale = sv.colorScaleGold ~= false
    if showBreakdown then
        local rows = snapshot.categories
        local grandTotal = snapshot.gold
        local leaderCategoryId, leaderGold
        for i = 1, #rows do
            if not leaderCategoryId or rows[i].gold > leaderGold then
                leaderCategoryId = rows[i].id
                leaderGold = rows[i].gold
            end
        end

        -- Price dynamics is analytical rather than a crafting category. Insert
        -- it immediately after Other (regardless of value sorting), with its own
        -- rise/fall summary. If Other is absent, keep the entry at the end so
        -- the feature remains reachable for a non-empty bag.
        local displayRows = {}
        local trendInserted = false
        local threshold = private.GetPriceTrendThreshold and private.GetPriceTrendThreshold() or 20
        local trendGains, trendLosses = addon.Valuation.GetPriceTrendSummary(threshold)
        local trendData = {
            id = "priceTrend",
            name = GetString(SI_BMW_PRICE_TREND_ROW),
            isPriceTrend = true,
            threshold = threshold,
            gains = trendGains,
            losses = trendLosses,
        }
        for i = 1, #rows do
            displayRows[#displayRows + 1] = rows[i]
            if rows[i].id == "other" then
                displayRows[#displayRows + 1] = trendData
                trendInserted = true
            end
        end
        if not trendInserted and snapshot.slots > 0 then
            displayRows[#displayRows + 1] = trendData
        end
        rows = displayRows

        for i = 1, #rows do
            local data = rows[i]
            local row = AcquireRow(i)
            row.data = data
            row.isPriceTrend = data.isPriceTrend == true
            row.isLeader = not row.isPriceTrend and data.id == leaderCategoryId
            row.leaderMarker:SetHidden(not row.isLeader)
            local share = not row.isPriceTrend and grandTotal and grandTotal > 0
                and data.gold / grandTotal or 0
            if share > 0 then
                row.shareFill:SetWidth(mathmax(2,
                    zo_round((CurrentWidth() - PADDING * 2 - LEADER_MARKER_WIDTH - 5) * share)))
                row.shareFill:SetHidden(false)
            else
                row.shareFill:SetHidden(true)
            end
            -- Optional profession icon + name + the category's share of the grand
            -- total, so it reads "[icon] Blacksmithing 42%" at a glance. Guard
            -- against a zero total (an all-unpriced bag) so the share is simply
            -- omitted rather than NaN.
            local nameText = Colorize(row.isPriceTrend and COLOR_ACCENT or COLOR_NAME, data.name)
            if showIcons and not row.isPriceTrend then
                nameText = CategoryIcon(data.id) .. nameText
            end
            if not row.isPriceTrend and grandTotal and grandTotal > 0 then
                local percent = zo_round(data.gold / grandTotal * 100)
                nameText = nameText .. " " .. Colorize(COLOR_MUTED,
                    stringformat(GetString(SI_BMW_ROW_PERCENT), percent))
            elseif row.isPriceTrend then
                nameText = nameText .. " " .. Colorize(COLOR_MUTED,
                    stringformat(GetString(SI_BMW_ROW_PERCENT), data.threshold))
            end
            row.name:ClearAnchors()
            row.name:SetAnchor(LEFT, row.container, LEFT, LEADER_MARKER_WIDTH + 5, -2)
            row.name:SetWidth((CurrentWidth() - PADDING * 2) * 0.60 - LEADER_MARKER_WIDTH - 13)
            row.name:SetText(nameText)
            -- Flag categories that have unpriced slots with a subtle marker so
            -- the total reads honestly at a glance, detail is in the tooltip.
            local goldText
            if row.isPriceTrend then
                goldText = ARROW_UP .. " " .. Colorize(COLOR_GAIN, tostring(data.gains))
                    .. "  " .. ARROW_DOWN .. " " .. Colorize(COLOR_LOSS, tostring(data.losses))
            else
                goldText = FormatGold(data.gold, colorScale and GoldScaleColor(data.gold) or nil)
                if data.unpricedSlots > 0 then
                    goldText = goldText .. " " .. Colorize(COLOR_WARN, "*")
                end
            end
            row.gold:SetText(goldText)
            if row.isPriceTrend then
                y = y + SECTION_GAP * 2
            end
            row.container:ClearAnchors()
            row.container:SetAnchor(TOPLEFT, windowControl, TOPLEFT, PADDING, y)
            row.container:SetHidden(false)
            y = y + ROW_HEIGHT
            rowCount = i
        end
    end

    -- Hide any pooled rows left over from a previous (larger) render.
    --
    -- Clearing `data` and `isLeader` matters as much as hiding the control: the
    -- OnMouseEnter/OnMouseUp handlers close over `row`, not over the render that
    -- filled it, and they only bail on a nil `data`. A leftover row that kept
    -- last render's data would still hold a reference to a category that is no
    -- longer in the bag, and hidden controls can retain a queued mouse-up (the
    -- press landing on a row that this render hides), which would open the
    -- detail window for a stale category. Nil-ing the payload makes the guards
    -- in those handlers actually fire and drops the reference for the GC.
    for i = rowCount + 1, #rowPool do
        rowPool[i].data = nil
        rowPool[i].isLeader = nil
        rowPool[i].isPriceTrend = nil
        rowPool[i].leaderMarker:SetHidden(true)
        rowPool[i].shareFill:SetHidden(true)
        -- Also drop the hover wash: a row hidden while the pointer was over it
        -- would come back from the pool already lit.
        rowPool[i].hoverFill:SetHidden(true)
        rowPool[i].container:SetHidden(true)
    end

    dividerTop:SetHidden(not showBreakdown or rowCount == 0)
    if not showBreakdown or rowCount == 0 then
        -- Collapse the header divider's gap when there is no breakdown to show.
        y = HeaderContentHeight() + HEADER_TO_DIVIDER_GAP
    end

    -- Footer block: bottom divider + the info rows (two-column label -> value).
    y = y + SECTION_GAP
    dividerBottom:ClearAnchors()
    dividerBottom:SetAnchor(TOPLEFT, windowControl, TOPLEFT, PADDING, y)
    y = y + DIVIDER_GAP

    footerInventoryRow.container:ClearAnchors()
    footerInventoryRow.container:SetAnchor(TOPLEFT, windowControl, TOPLEFT, PADDING, y)
    y = y + FOOTER_LINE

    footerPriceRefreshRow.container:ClearAnchors()
    footerPriceRefreshRow.container:SetAnchor(TOPLEFT, windowControl, TOPLEFT, PADDING, y)
    y = y + FOOTER_LINE

    footerPricesRow.container:ClearAnchors()
    footerPricesRow.container:SetAnchor(TOPLEFT, windowControl, TOPLEFT, PADDING, y)
    y = y + FOOTER_LINE

    -- Optional value-change row. Only reserves vertical space when it will
    -- actually be shown, so the panel doesn't grow an empty gap on the first
    -- visit. Must match RenderFooter's visibility test exactly -- including the
    -- zero-delta composition change -- or the layout and the row disagree.
    footerDeltaRow.container:ClearAnchors()
    footerDeltaRow.container:SetAnchor(TOPLEFT, windowControl, TOPLEFT, PADDING, y)
    local delta = snapshot.delta
    if snapshot.deltaPending or (delta and delta ~= 0) then
        y = y + FOOTER_LINE
    end

    footerGuidanceRow.container:ClearAnchors()
    footerGuidanceRow.container:SetAnchor(TOPLEFT, windowControl, TOPLEFT, PADDING, y)
    if not footerGuidanceRow.container:IsHidden() then
        y = y + FOOTER_LINE
    end

    RenderFooter()

    -- Value-history area chart (optional). Sits below the footer rows; the
    -- caption + head + filled strip + scale line only consume space when there's
    -- enough history to draw, and the whole block is skipped when the setting is
    -- off.
    if sv.showValueHistory ~= false then
        y = y + SPARK_TOP_GAP
        local innerWidth = CurrentWidth() - PADDING * 2

        -- Caption (left) and current-value head (right) share one row.
        sparkCaption:ClearAnchors()
        sparkCaption:SetAnchor(TOPLEFT, windowControl, TOPLEFT, PADDING, y)
        sparkHeadLabel:ClearAnchors()
        sparkHeadLabel:SetAnchor(TOPRIGHT, windowControl, TOPRIGHT, -PADDING, y)

        -- Filled strip beneath the caption row.
        sparkContainer:ClearAnchors()
        sparkContainer:SetAnchor(TOPLEFT, windowControl, TOPLEFT, PADDING, y + FOOTER_LINE)
        sparkContainer:SetWidth(innerWidth)

        -- Scale line (min … max) beneath the strip.
        sparkScaleLabel:ClearAnchors()
        sparkScaleLabel:SetAnchor(TOPLEFT, windowControl, TOPLEFT, PADDING,
            y + FOOTER_LINE + SPARK_HEIGHT + SPARK_SCALE_GAP)
        sparkScaleLabel:SetWidth(innerWidth)

        local consumed = RenderSparkline(innerWidth)
        if consumed > 0 then
            y = y + FOOTER_LINE + consumed
        end
    else
        sparkCaption:SetHidden(true)
        sparkHeadLabel:SetHidden(true)
        sparkContainer:SetHidden(true)
        sparkScaleLabel:SetHidden(true)
    end

    windowControl:SetHeight(y + PADDING)
end

local function StopFooterTick()
    EVENT_MANAGER:UnregisterForUpdate(FOOTER_TIMER_NAME)
end

local function StartFooterTick()
    -- Idempotent: Show() (which calls this) also runs on a settings toggle while
    -- the window is already shown, i.e. without an intervening Hide(). Unregister
    -- first so the same timer name is never registered twice (a double
    -- registration warns and leaves the tick interval inconsistent).
    StopFooterTick()
    EVENT_MANAGER:RegisterForUpdate(FOOTER_TIMER_NAME, FOOTER_TICK_MS, function()
        RenderFooter()
    end)
end

function Window.Show()
    if not windowControl then
        return
    end
    -- Only meaningful while the Craft Bag is on screen. The fragment callback
    -- only fires Show() when it is, but the settings toggle also calls Show() to
    -- refresh visibility, and that can happen with the bag closed.
    if not (CRAFT_BAG_FRAGMENT and CRAFT_BAG_FRAGMENT:IsShowing()) then
        Window.Hide()
        return
    end
    -- Suppressed in the guild store when the user has opted out: the panel would
    -- otherwise sit over the trading house UI, and not everyone wants it there.
    if IsGuildStoreShowing() and GetSavedVars().showInGuildStore == false then
        Window.Hide()
        return
    end
    -- Re-anchor on each show: the correct offset depends on whether the guild
    -- store is up, which is only known now (not at Initialize time).
    Window.ApplyAnchor()
    Window.Update()
    windowControl:SetHidden(false)
    StartFooterTick()
end

function Window.Hide()
    if windowControl then
        windowControl:SetHidden(true)
    end
    StopFooterTick()
    StopTotalGlow()
end

-- Re-apply the configured anchor offset after the settings panel changes it.
-- The window hangs off the left edge of the Craft Bag; in the guild store an
-- extra leftward shift keeps it clear of the trading house's browse pane.
function Window.ApplyAnchor()
    if not windowControl then
        return
    end
    local sv = GetSavedVars()
    local offsetX = sv.windowOffsetX or -25
    if IsGuildStoreShowing() then
        offsetX = offsetX + GUILD_STORE_OFFSET_X
    end
    windowControl:ClearAnchors()
    windowControl:SetAnchor(TOPRIGHT, ZO_CraftBag, TOPLEFT,
        offsetX, sv.windowOffsetY or 0)
end

-- Re-apply the configured width to the window and every width-dependent control
-- (dividers + pooled rows and their two columns), then re-lay-out. Called when
-- the width slider changes; safe before Initialize (no-op) and when rows have
-- not been created yet.
function Window.ApplyWidth()
    if not windowControl then
        return
    end

    local width = CurrentWidth()
    windowControl:SetWidth(width)

    local innerWidth = width - PADDING * 2
    -- The band spans the whole panel, so it tracks the outer width; its underline
    -- is anchored to the band's own edges and follows automatically.
    if headerBand then
        headerBand:SetWidth(width)
    end
    if dividerTop then
        dividerTop:SetWidth(innerWidth)
    end
    -- The profile label's width tracks the window so a wider panel gives the handle
    -- more room before it ellipsizes.
    if profileLabel then
        profileLabel:SetWidth(innerWidth)
    end
    if subtitleLabel then
        subtitleLabel:SetWidth(innerWidth)
    end
    if versionNameLabel then
        versionNameLabel:SetWidth(innerWidth)
    end
    if totalLabel then
        totalLabel:SetWidth(innerWidth)
    end
    if dividerBottom then
        dividerBottom:SetWidth(innerWidth)
    end
    -- The sparkline strip spans the inner width; its bars are re-laid-out by the
    -- Window.Update() call at the end of this function.
    if sparkContainer then
        sparkContainer:SetWidth(innerWidth)
    end

    if rowPool then
        for i = 1, #rowPool do
            local row = rowPool[i]
            row.container:SetWidth(innerWidth)
            row.name:SetWidth(innerWidth * 0.60 - LEADER_MARKER_WIDTH - 13)
            row.gold:SetWidth(innerWidth * 0.40)
        end
    end

    -- Footer rows share the same two-column geometry (40/60 split).
    local function ResizeFooterRow(row)
        if not row then
            return
        end
        row.container:SetWidth(innerWidth)
        row.label:SetWidth(innerWidth * 0.42 - METRIC.GAP)
        row.value:SetWidth(innerWidth * 0.58)
    end
    ResizeFooterRow(footerInventoryRow)
    ResizeFooterRow(footerPriceRefreshRow)
    ResizeFooterRow(footerPricesRow)
    ResizeFooterRow(footerDeltaRow)
    if footerGuidanceRow then
        footerGuidanceRow.container:SetWidth(innerWidth)
        footerGuidanceRow.label:SetWidth(innerWidth - 16)
    end

    Window.Update()
end

-- Re-apply the configured background/border appearance. When the background is
-- off the center color is fully transparent; when the border is off the edge
-- color is too, so the panel can be reduced to plain floating text.
function Window.ApplyAppearance()
    if not backdrop then
        return
    end

    local sv = GetSavedVars()
    -- One call: the shared shell decides the ground tint, border tone and insets;
    -- this file only reports which of the two layers the player wants drawn.
    UI.ApplyPanelChrome(backdrop, {
        background = sv.showBackground ~= false,
        border = sv.showBorder ~= false,
    })

    -- The letterhead belongs to the background: with the panel reduced to floating
    -- text there is no surface for a tinted strip to sit on.
    if headerBand then
        headerBand:SetHidden(sv.showBackground == false)
    end
end

