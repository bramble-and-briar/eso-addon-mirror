-- Trial Tagger: the screenshot panel and the achievement-id harvest view.
--
-- Built in Lua rather than XML on purpose. Console manifests are case-sensitive
-- on PS5 and XML path casing is the most common reason an addon loads on Xbox
-- but not PlayStation; generating controls in code removes that whole class of
-- bug.
--
-- Layout choices here exist to serve OCR, not looks:
--   * a pure black, fully opaque backdrop with a white border, so the bot can
--     find the panel as the one large high-contrast rectangle in a screenshot
--     that is otherwise full of game world;
--   * the code rendered white, large, and on its own line, because text height
--     is what survives the downscaling that console share features apply;
--   * soft-shadow-thin for the font style, which is a black shadow on a black
--     background and therefore invisible, but keeps the font string in the
--     three-part form the client parses most reliably.

TrialTagger = TrialTagger or {}
local TT = TrialTagger
local UI = {}
TT.UI = UI

local wm = GetWindowManager()

local FONT_PATH_BOLD = "EsoUI/Common/Fonts/univers67.otf"
local FONT_PATH_BOOK = "EsoUI/Common/Fonts/univers57.otf"

local FONT_TITLE = FONT_PATH_BOLD .. "|30|soft-shadow-thin"
local FONT_CODE = FONT_PATH_BOLD .. "|40|soft-shadow-thin"
local FONT_BODY = FONT_PATH_BOOK .. "|22|soft-shadow-thin"
local FONT_SMALL = FONT_PATH_BOOK .. "|18|soft-shadow-thin"

local WHITE = { 1, 1, 1, 1 }
local DIM = { 0.45, 0.45, 0.45, 1 }
local GREEN = { 0.35, 0.90, 0.40, 1 }
local AMBER = { 1.00, 0.78, 0.20, 1 }

-- Geometry comes from the generated catalog, which the bot reads too. Keeping
-- one copy means the OCR crop cannot drift away from where the code is drawn.
local PANEL = TrialTagger.Catalog.panel
local PANEL_WIDTH = PANEL.width
local PANEL_HEIGHT = PANEL.height
local PAD = PANEL.padding
local ROW_HEIGHT = 30
local SLOT_COLUMN_WIDTH = 110

local HARVEST_ROWS = 18

local function makeBackdrop(name, parent, edgeSize)
    local backdrop = wm:CreateControl(name, parent, CT_BACKDROP)
    backdrop:SetCenterColor(0, 0, 0, 1)
    backdrop:SetEdgeColor(1, 1, 1, 1)
    backdrop:SetEdgeTexture("", 8, 1, edgeSize or 2, 0)
    backdrop:SetInsets(0, 0, 0, 0)
    return backdrop
end

local function makeLabel(name, parent, font, color, align)
    local label = wm:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font)
    label:SetColor(unpack(color or WHITE))
    label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end

----------------------------------------------------------------------------
-- Proof panel
----------------------------------------------------------------------------

function UI.BuildPanel()
    if UI.panel then return UI.panel end

    local panel = wm:CreateTopLevelWindow("TrialTaggerPanel")
    panel:SetDimensions(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    panel:SetHidden(true)
    panel:SetMouseEnabled(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    UI.panel = panel

    local backdrop = makeBackdrop("TrialTaggerPanelBG", panel, 3)
    backdrop:SetAnchorFill(panel)

    local title = makeLabel("TrialTaggerTitle", panel, FONT_TITLE, WHITE)
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, PAD, PAD)
    title:SetText("TRIAL TAGGER")

    local version = makeLabel("TrialTaggerVersion", panel, FONT_SMALL, DIM, TEXT_ALIGN_RIGHT)
    version:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -PAD, PAD + 8)
    version:SetText("v" .. (TT.version or "?"))

    -- Anchored absolutely rather than under the title, because the bot crops
    -- this line at a fixed offset to cross-check the account hash.
    local account = makeLabel("TrialTaggerAccount", panel, FONT_BODY, WHITE)
    account:SetAnchor(TOPLEFT, panel, TOPLEFT, PAD, PANEL.accountTop)
    account:SetHeight(PANEL.accountHeight)
    UI.accountLabel = account

    -- The code gets its own bordered strip. It gives the bot a second, smaller
    -- target to lock onto when the full panel is partially cropped.
    local strip = makeBackdrop("TrialTaggerCodeStrip", panel, 2)
    strip:SetAnchor(TOPLEFT, panel, TOPLEFT, PAD, PANEL.stripTop)
    strip:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -PAD, PANEL.stripTop)
    strip:SetHeight(PANEL.stripHeight)

    local code = makeLabel("TrialTaggerCode", panel, FONT_CODE, WHITE, TEXT_ALIGN_CENTER)
    code:SetAnchorFill(strip)
    UI.codeLabel = code

    local hint = makeLabel("TrialTaggerHint", panel, FONT_SMALL, DIM, TEXT_ALIGN_CENTER)
    hint:SetAnchor(TOP, strip, BOTTOM, 0, 6)
    hint:SetWidth(PANEL_WIDTH - PAD * 2)
    hint:SetText("Screenshot this panel and post it in Discord, tagging the bot.")

    UI.BuildTable(panel, hint)

    local footer = makeLabel("TrialTaggerFooter", panel, FONT_SMALL, DIM, TEXT_ALIGN_CENTER)
    footer:SetAnchor(BOTTOM, panel, BOTTOM, 0, -10)
    footer:SetWidth(PANEL_WIDTH - PAD * 2)
    UI.footerLabel = footer

    UI.ArmAutoHide()

    return panel
end

--- One row per trial, one cell per slot.
--
-- The columns are deliberately not labelled in the header: trials no longer
-- share a tier set, so column 2 is "+1" for Cloudrest and "HM Lokkestiiz" for
-- Sunspire and there is no honest heading for it. Each cell carries its own
-- slot's short label instead, and the colour says whether it was earned.
function UI.BuildTable(panel, anchorAbove)
    local catalog = TT.Catalog
    local nameColumnWidth = PANEL_WIDTH - PAD * 2 - SLOT_COLUMN_WIDTH * catalog.maxSlots

    local header = wm:CreateControl("TrialTaggerHeader", panel, CT_CONTROL)
    header:SetAnchor(TOPLEFT, anchorAbove, BOTTOMLEFT, 0, 18)
    header:SetDimensions(PANEL_WIDTH - PAD * 2, ROW_HEIGHT)

    local headerName = makeLabel("TrialTaggerHeaderName", header, FONT_SMALL, DIM)
    headerName:SetAnchor(LEFT, header, LEFT, 0, 0)
    headerName:SetWidth(nameColumnWidth)
    headerName:SetText("TRIAL")

    local headerHint = makeLabel("TrialTaggerHeaderHint", header, FONT_SMALL, DIM)
    headerHint:SetAnchor(LEFT, header, LEFT, nameColumnWidth, 0)
    headerHint:SetWidth(SLOT_COLUMN_WIDTH * catalog.maxSlots)
    headerHint:SetText("EARNED")

    UI.rows = {}
    local previous = header
    for rowIndex, trial in ipairs(catalog.trials) do
        local row = wm:CreateControl("TrialTaggerRow" .. rowIndex, panel, CT_CONTROL)
        row:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 0)
        row:SetDimensions(PANEL_WIDTH - PAD * 2, ROW_HEIGHT)

        local name = makeLabel("TrialTaggerRow" .. rowIndex .. "Name", row, FONT_BODY, WHITE)
        name:SetAnchor(LEFT, row, LEFT, 0, 0)
        name:SetWidth(nameColumnWidth)
        name:SetText(trial.abbr .. "  " .. trial.name)

        local cells = {}
        for i, slot in ipairs(trial.slots) do
            local cell = makeLabel(
                "TrialTaggerRow" .. rowIndex .. "Slot" .. i, row, FONT_BODY, DIM, TEXT_ALIGN_CENTER
            )
            cell:SetAnchor(LEFT, row, LEFT, nameColumnWidth + SLOT_COLUMN_WIDTH * (i - 1), 0)
            cell:SetWidth(SLOT_COLUMN_WIDTH)
            cells[slot.key] = cell
        end

        UI.rows[trial.key] = { control = row, cells = cells }
        previous = row
    end
end

--- Recompute achievements and repaint. Called every time the panel is shown so
--- the code's timestamp is fresh and the bot's staleness check passes.
function UI.Refresh()
    UI.BuildPanel()

    local displayName = GetDisplayName()
    local values, widths, grid = TT.Scanner.Evaluate()

    local code = TT.Codec.Encode(
        values,
        displayName,
        TT.Catalog.payloadVersion,
        TT.Catalog.catalogVersion,
        widths,
        TT.Catalog.trialBytes
    )

    UI.accountLabel:SetText(displayName .. "   |   " .. GetUnitName("player"))
    UI.codeLabel:SetText("TT1 " .. table.concat(TT.Codec.Group(code, 5), " "))

    local unconfigured, total = 0, 0
    for _, trial in ipairs(TT.Catalog.trials) do
        local row = UI.rows[trial.key]
        for _, slot in ipairs(trial.slots) do
            local state = grid[trial.key][slot.key]
            local cell = row.cells[slot.key]
            total = total + 1
            if not state.configured then
                cell:SetText("?")
                cell:SetColor(unpack(AMBER))
                unconfigured = unconfigured + 1
            elseif state.earned then
                cell:SetText(slot.short)
                cell:SetColor(unpack(GREEN))
            else
                cell:SetText("-")
                cell:SetColor(unpack(DIM))
            end
        end
    end

    if unconfigured > 0 then
        UI.footerLabel:SetText(
            string.format(
                "%d of %d roles have no achievement ids configured (shown as ?) and will never be granted.",
                unconfigured, total
            )
        )
        UI.footerLabel:SetColor(unpack(AMBER))
    else
        UI.footerLabel:SetText(
            "This code expires. Re-open the panel for a fresh one. Open any menu to dismiss."
        )
        UI.footerLabel:SetColor(unpack(DIM))
    end
end

function UI.Show()
    UI.BuildPanel()
    UI.HideHarvest()
    UI.Refresh()
    UI.panel:SetHidden(false)
end

function UI.Hide()
    if UI.panel then UI.panel:SetHidden(true) end
end

function UI.Toggle()
    UI.BuildPanel()
    if UI.panel:IsHidden() then UI.Show() else UI.Hide() end
end

--- Show the panel from the Settings menu.
-- The menu is a full-screen scene drawn over the world, so a panel shown while
-- it is open sits behind it and cannot be screenshotted. Dropping back to the
-- base scene first fixes that; the panel follows a moment later so the scene
-- transition has finished and will not hide it again on the way out.
function UI.ShowFromMenu()
    if SCENE_MANAGER then
        SCENE_MANAGER:ShowBaseScene()
    end
    zo_callLater(function() UI.Show() end, 200)
end

function UI.ShowHarvestFromMenu()
    if SCENE_MANAGER then
        SCENE_MANAGER:ShowBaseScene()
    end
    zo_callLater(function()
        UI.Hide()
        UI.BuildHarvest()
        UI.RefreshHarvest()
        UI.harvest:SetHidden(false)
    end, 200)
end

--- Dismiss both windows whenever the player opens a menu.
-- With no keybind and no cursor on a controller, there is nothing to click a
-- close button with, so the windows have to dismiss themselves. Leaving the
-- HUD scene is the signal: it is what happens the moment the player opens
-- anything, and it is also how they got to the Settings entry in the first
-- place.
function UI.ArmAutoHide()
    if UI.autoHideArmed then return end
    local scene = HUD_SCENE
    if not scene or not scene.RegisterCallback then return end

    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_HIDDEN then
            UI.Hide()
            UI.HideHarvest()
        end
    end)
    UI.autoHideArmed = true
end

----------------------------------------------------------------------------
-- Harvest view: read achievement ids straight off the screen.
----------------------------------------------------------------------------

function UI.BuildHarvest()
    if UI.harvest then return UI.harvest end

    local window = wm:CreateTopLevelWindow("TrialTaggerHarvest")
    window:SetDimensions(PANEL_WIDTH, PANEL_HEIGHT)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetHidden(true)
    window:SetMouseEnabled(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    -- Paging used to be a keybind. The wheel replaces it on PC, which is where
    -- this view is actually used, since filling the catalog means editing JSON
    -- on the same machine. /trialtag next and /trialtag prev also work.
    window:SetHandler("OnMouseWheel", function(_, delta)
        UI.StepHarvest(delta > 0 and -1 or 1)
    end)
    UI.harvest = window

    local backdrop = makeBackdrop("TrialTaggerHarvestBG", window, 3)
    backdrop:SetAnchorFill(window)

    local title = makeLabel("TrialTaggerHarvestTitle", window, FONT_TITLE, WHITE)
    title:SetAnchor(TOPLEFT, window, TOPLEFT, PAD, PAD)
    UI.harvestTitle = title

    local subtitle = makeLabel("TrialTaggerHarvestSub", window, FONT_SMALL, DIM)
    subtitle:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 4)
    UI.harvestSubtitle = subtitle

    UI.harvestRows = {}
    local previous = subtitle
    for i = 1, HARVEST_ROWS do
        local row = makeLabel("TrialTaggerHarvestRow" .. i, window, FONT_BODY, WHITE)
        row:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, i == 1 and 14 or 0)
        row:SetDimensions(PANEL_WIDTH - PAD * 2, ROW_HEIGHT)
        UI.harvestRows[i] = row
        previous = row
    end

    local footer = makeLabel("TrialTaggerHarvestFooter", window, FONT_SMALL, AMBER, TEXT_ALIGN_CENTER)
    footer:SetAnchor(BOTTOM, window, BOTTOM, 0, -10)
    footer:SetWidth(PANEL_WIDTH - PAD * 2)
    UI.harvestFooter = footer

    return window
end

function UI.RefreshHarvest()
    UI.BuildHarvest()

    local pages = UI.harvestPages
    if not pages then
        pages = TT.Scanner.BuildHarvestPages()
        UI.harvestPages = pages
        UI.harvestPage = 1
        UI.harvestOffset = 0
    end

    local page = pages[UI.harvestPage]
    if not page then return end

    local entries = TT.Scanner.GetAchievementsIn(page.categoryIndex, page.subCategoryIndex, page.count)
    local totalScreens = math.max(1, math.ceil(#entries / HARVEST_ROWS))
    local screen = math.floor(UI.harvestOffset / HARVEST_ROWS) + 1

    UI.harvestTitle:SetText(page.title)
    UI.harvestSubtitle:SetText(string.format(
        "Category %d/%d   screen %d/%d   %d achievements",
        UI.harvestPage, #pages, screen, totalScreens, #entries
    ))

    for i = 1, HARVEST_ROWS do
        local entry = entries[UI.harvestOffset + i]
        local row = UI.harvestRows[i]
        if entry then
            row:SetText(string.format("%7d  %s  %s", entry.id, entry.completed and "[X]" or "[ ]", entry.name))
            row:SetColor(unpack(entry.completed and GREEN or WHITE))
        else
            row:SetText("")
        end
    end

    UI.harvestFooter:SetText(
        "Mouse wheel or /trialtag next | prev to page. Copy the ids you need into " ..
        "shared/trials.json, then run tools/gen_addon_catalog.py"
    )
end

function UI.StepHarvest(delta)
    if not UI.harvestPages then return end
    UI.harvestOffset = UI.harvestOffset + delta * HARVEST_ROWS
    if UI.harvestOffset < 0 then
        UI.harvestPage = UI.harvestPage - 1
        if UI.harvestPage < 1 then UI.harvestPage = #UI.harvestPages end
        UI.harvestOffset = 0
    elseif UI.harvestOffset >= UI.harvestPages[UI.harvestPage].count then
        UI.harvestPage = UI.harvestPage + 1
        if UI.harvestPage > #UI.harvestPages then UI.harvestPage = 1 end
        UI.harvestOffset = 0
    end
    UI.RefreshHarvest()
end

function UI.HideHarvest()
    if UI.harvest then UI.harvest:SetHidden(true) end
end

function UI.ToggleHarvest()
    UI.BuildHarvest()
    if UI.harvest:IsHidden() then
        if UI.panel then UI.panel:SetHidden(true) end
        UI.RefreshHarvest()
        UI.harvest:SetHidden(false)
    else
        UI.harvest:SetHidden(true)
    end
end
