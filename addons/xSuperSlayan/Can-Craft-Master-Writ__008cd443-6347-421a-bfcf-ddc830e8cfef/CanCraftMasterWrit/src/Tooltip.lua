-- Adds the check results to the game's gamepad item tooltip (used on console and in gamepad mode on PC).
--
-- Every master writ tooltip is drawn by ZO_Tooltip:LayoutMasterWritItem, whether the writ is in the bags,
-- the bank, a guild trader, the mail or a chat link, so that is the one place we hook:
--   * The overall status (CRAFTABLE) goes at the right end of the "Quest Starter" row. The game adds that line to the
--     top section in AddTypeSlotUniqueLine; we put it in a row of its own with the status beside it. If that line
--     can't be found, the status goes at the right end of the row above, with the bag count: the game builds that
--     row in AddTopLinesToTopSection and hands it to the top section with AddSectionEvenIfEmpty, and we add our line
--     just before that hand-over.
--   * The individual checks go in a section at the bottom, after the game's own text.
--
-- ZO_Tooltip copies its functions into each tooltip when the tooltip is first set up, so we hook ZO_Tooltip itself
-- (for tooltips set up later) and every gamepad tooltip that already exists.

local addon = CanCraftMasterWrit
local Result = addon.Result
local Evaluator = addon.Evaluator
local Settings = addon.Settings
local Util = addon.Util

local Tooltip = {}
addon.Tooltip = Tooltip

local ICON_SIZE = 24

-- The game's own icons. Each is used by the game's shared or gamepad UI code, so it exists on console too.
local CATEGORY_ICON = {
    [Result.CATEGORY_GENERAL] = "EsoUI/Art/Miscellaneous/help_icon.dds",
    [Result.CATEGORY_MOTIF] = "EsoUI/Art/TradingHouse/Tradinghouse_Racial_Style_Motif_Chapter_Up.dds",
    [Result.CATEGORY_TRAIT] = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuIcon_research.dds",
    [Result.CATEGORY_SET] = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_itemSetCollections.dds",
    [Result.CATEGORY_RUNES] = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_enchanting_up.dds",
    [Result.CATEGORY_REAGENTS] = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_alchemy_up.dds",
    [Result.CATEGORY_RECIPE] = "EsoUI/Art/Inventory/inventory_tabIcon_recipe_up.dds",
    -- ZO_GAMEPAD_SUBMIT_ENTRY_ICON; Dolgubon's Lazy Writ Crafter also uses it for writs ready to hand in.
    [Result.CATEGORY_ITEM] = "EsoUI/Art/Miscellaneous/Gamepad/gp_submit.dds",
    [Result.CATEGORY_SKILLS] = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_skills.dds",
    [Result.CATEGORY_MATERIALS] = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_materials.dds",
}
Tooltip.CATEGORY_ICON = CATEGORY_ICON

local STATUS_TEXT = {
    [Result.STATUS_CRAFTABLE] = SI_CCMW_STATUS_CRAFTABLE,
    [Result.STATUS_NOT_CRAFTABLE] = SI_CCMW_STATUS_NOT_CRAFTABLE,
    [Result.STATUS_UNKNOWN] = SI_CCMW_STATUS_UNKNOWN,
}

-- The icons shown with or instead of the status (the "Status Display" setting): the radial menu's accept and cancel,
-- which the game's shared UI code uses, so they exist on console. They take the status's colour. Status Unknown has
-- no icon and is always written out.
local STATUS_ICON = {
    [Result.STATUS_CRAFTABLE] = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_accept_down.dds",
    [Result.STATUS_NOT_CRAFTABLE] = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_cancel_down.dds",
}
Tooltip.STATUS_ICON = STATUS_ICON
-- A share of the text's height. The text's height includes room above and below the capitals, so this lines the
-- icon up with the tops and bottoms of the capitals.
local STATUS_ICON_SIZE = "88%"

-- The status is drawn in capitals (CRAFTABLE), like the rest of the top section. The game does the capitals, so the
-- text stays in normal case for chat and screen narration, and works in every language.
local STATUS_STYLE = {
    [Result.STATUS_CRAFTABLE] = { fontColorField = GAMEPAD_TOOLTIP_COLOR_SUCCEEDED, uppercase = true },
    [Result.STATUS_NOT_CRAFTABLE] = { fontColorField = GAMEPAD_TOOLTIP_COLOR_FAILED, uppercase = true },
    [Result.STATUS_UNKNOWN] = { fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_2, uppercase = true },
}

-- Below this width the status isn't pushed right; it just follows the line before it like any other line.
local MIN_STATUS_WIDTH = 200

-- The row holding "Quest Starter" and the status, laid out left to right like the game's bag count row
-- (topSubsectionItemDetails in tooltipstyles.lua). Its lines take the top section's font and colour.
local STATUS_ROW_STYLE = {
    layoutPrimaryDirection = "right",
    layoutSecondaryDirection = "up",
    widthPercent = 100,
    childSpacing = 15,
}

local LINE_SPACING = 4   -- Between lines in a group (the section's childSpacing).
local GROUP_SPACING = 30 -- Above the first line of a new group.

-- About two blank lines separate the game's own text (the writ's description) from ours, with the same faint line as
-- on the settings' Supporters page in the middle.
local DIVIDER_GAP = 38

local DIVIDER_SECTION_STYLE = {
    customSpacing = DIVIDER_GAP,
    widthPercent = 100,
}

-- No picture: the game's map tooltips add a texture without one too (maptooltips.lua), and it draws as a rectangle of
-- its colour.
local DIVIDER_TEXTURE = nil
local DIVIDER_STYLE = {
    widthPercent = 100,
    height = Util.LINE_HEIGHT,
    color = ZO_ColorDef:New(1, 1, 1, Util.LINE_ALPHA),
}

local DETAILS_SECTION_STYLE = {
    customSpacing = DIVIDER_GAP,
    childSpacing = LINE_SPACING,
    widthPercent = 100,
    fontFace = "$(GAMEPAD_MEDIUM_FONT)",
    fontSize = "$(GP_27)",
}

-- Where a line's text starts after its icon. Wrapped lines and the motif name start here too, as do missing items.
local TEXT_INDENT = ICON_SIZE + 8

local STATE_COLOR = {
    [Result.STATE_PASS] = GAMEPAD_TOOLTIP_COLOR_SUCCEEDED,
    [Result.STATE_FAIL] = GAMEPAD_TOOLTIP_COLOR_FAILED,
    [Result.STATE_UNKNOWN] = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_2,
    [Result.STATE_INFO] = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1,
}

-- The alchemy reagents to use are listed one per line under the reagents line, in smaller text. Their label is
-- coloured like any other; the names of the reagents in stock are yellow, and a missing one reads "name: have/need"
-- like any missing item.
local REAGENT_COLOR = ZO_ColorDef:New("FFDD44")

-- Lines are grouped, with a gap between groups: the final item to hand in (provisioning and holiday writs), then
-- what you know (motif, or runes, reagents or recipe), then trait and set, then skills, then materials. Lines in the
-- same group sit together. Requirements already met (green) come last, together, with no gaps between them, so what
-- is missing is read first.
local CATEGORY_GROUP = {
    [Result.CATEGORY_GENERAL] = 0,
    [Result.CATEGORY_ITEM] = 1,
    [Result.CATEGORY_MOTIF] = 2,
    [Result.CATEGORY_RUNES] = 2,
    [Result.CATEGORY_REAGENTS] = 2,
    [Result.CATEGORY_RECIPE] = 2,
    [Result.CATEGORY_TRAIT] = 3,
    [Result.CATEGORY_SET] = 3,
    [Result.CATEGORY_SKILLS] = 4,
    [Result.CATEGORY_MATERIALS] = 5,
}

-- Lines whose value goes on its own line under the label, because it is long (a motif's full name).
local VALUE_ON_NEW_LINE = {
    [Result.CATEGORY_MOTIF] = true,
}

local function IsReagentList(check)
    return check.category == Result.CATEGORY_REAGENTS
end

local function CheckStyle(check, startsGroup)
    return {
        fontColorField = STATE_COLOR[check.state],
        newLineX = TEXT_INDENT,
        customSpacing = startsGroup and GROUP_SPACING or nil,
    }
end

local DETAIL_LIST_STYLE = {
    childSpacing = 2,
    widthPercent = 100,
    paddingLeft = TEXT_INDENT,
}

local DETAIL_STYLE = { fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_3 }

-- About three quarters of the size of the other lines (GP_27).
local REAGENT_LIST_STYLE = {
    childSpacing = 0,
    widthPercent = 100,
    paddingLeft = TEXT_INDENT,
    fontSize = "$(GP_20)",
}

local REAGENT_STYLE = { fontColor = REAGENT_COLOR }

---------------------------------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------------------------------

function Tooltip.GetStatusText(result)
    return GetString(STATUS_TEXT[result.status])
end

-- Returns the status as the tooltip shows it: its icon, its text or both, as the Status Display setting says.
function Tooltip.FormatStatus(result)
    local text = Tooltip.GetStatusText(result)
    local icon = STATUS_ICON[result.status]
    local display = Settings.Get("statusDisplay")
    if not icon or display == "text" then
        return text
    elseif display == "icon" then
        return zo_iconFormatInheritColor(icon, STATUS_ICON_SIZE, STATUS_ICON_SIZE)
    end
    return zo_iconTextFormat(icon, STATUS_ICON_SIZE, STATUS_ICON_SIZE, text, true)
end

-- Returns "Label: value" with the value in white, so the label's colour says pass or fail and the value stands out.
function Tooltip.FormatLabelValue(label, value)
    if value == nil or value == "" then
        return label
    end
    return zo_strformat(SI_CCMW_LABEL_VALUE, label, ZO_WHITE:Colorize(value))
end

function Tooltip.FormatCheck(check)
    local text
    if VALUE_ON_NEW_LINE[check.category] and check.value and check.value ~= "" then
        text = zo_strformat(SI_CCMW_LABEL_VALUE_NEW_LINE, check.label, ZO_WHITE:Colorize(check.value))
    else
        text = Tooltip.FormatLabelValue(check.label, check.value)
    end
    local icon = CATEGORY_ICON[check.category]
    if icon then
        return zo_iconTextFormat(icon, ICON_SIZE, ICON_SIZE, text)
    end
    return text
end

-- Returns the width left at the end of the row the next line would go on, or nil if the row's layout can't be read.
-- ZO_TooltipSection lays a horizontal row out with a cursor (primaryCursor) inside a fixed inner width; see
-- esoui/libraries/zo_tooltip/zo_tooltip.lua.
local function GetRemainingRowWidth(row)
    if type(row.GetInnerPrimaryDimension) ~= "function" or type(row.primaryCursor) ~= "number" then
        return nil
    end
    local innerWidth = row:GetInnerPrimaryDimension()
    if type(innerWidth) ~= "number" then
        return nil
    end
    local spacing = 0
    if not row.firstInLine and type(row.GetProperty) == "function" then
        spacing = row:GetProperty("childSpacing") or 0
    end
    -- One unit less, so rounding can never push the line onto a new row.
    return innerWidth - row.primaryCursor - spacing - 1
end

-- Adds the status as a label that fills the rest of the row with its text aligned right, so it sits at the
-- right end of the row whatever comes before it.
local function AddStatusLine(row, result)
    local style = STATUS_STYLE[result.status]
    local width = GetRemainingRowWidth(row)
    if width and width >= MIN_STATUS_WIDTH then
        style = ZO_ShallowTableCopy(style)
        style.width = width
        style.horizontalAlignment = TEXT_ALIGN_RIGHT
    end
    -- The plain text is given as narration, so screen narration reads the status even when only the icon shows.
    row:AddLineWithCustomNarration(Tooltip.FormatStatus(result), Tooltip.GetStatusText(result), style)
end

local function AddCheckLine(section, check, startsGroup)
    -- The plain text is given as narration so screen narration doesn't read out the icon and colour markup.
    section:AddLineWithCustomNarration(Tooltip.FormatCheck(check), check.text, CheckStyle(check, startsGroup))
    if #check.details > 0 then
        local isReagentList = IsReagentList(check)
        local detailList = section:AcquireSection(isReagentList and REAGENT_LIST_STYLE or DETAIL_LIST_STYLE)
        for _, detail in ipairs(check.details) do
            -- A reagent with a count is missing; the others are in stock.
            local detailStyle = (isReagentList and not detail.value) and REAGENT_STYLE or DETAIL_STYLE
            detailList:AddLineWithCustomNarration(Tooltip.FormatLabelValue(detail.label, detail.value), detail.text,
                detailStyle)
        end
        section:AddSection(detailList)
    end
end

local function AddDetailsSection(tooltip, result)
    local unmet, met = {}, {}
    for _, check in ipairs(result.checks) do
        if Settings.IsStateShown(check.state) then
            table.insert(check.state == Result.STATE_PASS and met or unmet, check)
        end
    end
    -- The divider goes in only when there is at least one line to show under it.
    if #unmet == 0 and #met == 0 then
        return
    end
    local divider = tooltip:AcquireSection(DIVIDER_SECTION_STYLE)
    divider:AddTexture(DIVIDER_TEXTURE, DIVIDER_STYLE)
    tooltip:AddSection(divider)

    local section = tooltip:AcquireSection(DETAILS_SECTION_STYLE)
    local previousGroup
    for _, check in ipairs(unmet) do
        local group = CATEGORY_GROUP[check.category] or 0
        AddCheckLine(section, check, previousGroup ~= nil and group ~= previousGroup)
        previousGroup = group
    end
    -- The met requirements form one block: a gap above it, none inside it.
    for index, check in ipairs(met) do
        AddCheckLine(section, check, index == 1 and #unmet > 0)
    end
    tooltip:AddSection(section)
end

---------------------------------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------------------------------

-- The top section waiting for our status line, and its own AddLine or AddSectionEvenIfEmpty, so they can always be
-- put back. Sections are pooled and reused for other items, so a leftover wrapper would print our status on them.
local pendingLineSection, pendingLineOriginal
local pendingSection, pendingOriginal
-- The top section whose "Quest Starter" row got the status, so the bag count row doesn't get it too.
local statusPlacedIn

local function RestorePendingSection()
    if pendingLineSection then
        pendingLineSection.AddLine = pendingLineOriginal
        pendingLineSection, pendingLineOriginal = nil, nil
    end
    if pendingSection then
        pendingSection.AddSectionEvenIfEmpty = pendingOriginal
        pendingSection, pendingOriginal = nil, nil
    end
end

-- The game adds "Quest Starter" to the top section as a line of its own (AddTypeSlotUniqueLine, itemtooltips.lua).
-- For a master writ, that one line goes in a row with the status beside it instead.
local function OnAddTypeSlotUniqueLine(_, itemLink, _, section, text1, text2)
    RestorePendingSection()
    statusPlacedIn = nil
    if not section or text2 ~= nil or text1 ~= GetString(SI_ITEM_FORMAT_STR_QUEST_STARTER_ITEM) then
        return
    end
    local result = Evaluator.Evaluate(itemLink)
    if not result then
        return
    end

    local lineText = zo_strformat(SI_ITEM_FORMAT_STR_TEXT1, text1)
    local original = section.AddLine
    pendingLineSection, pendingLineOriginal = section, original
    section.AddLine = function(topSection, text, ...)
        if text ~= lineText then
            return original(topSection, text, ...)
        end
        RestorePendingSection()
        local row = topSection:AcquireSection(STATUS_ROW_STYLE)
        row:AddLine(text, ...)
        AddStatusLine(row, result)
        topSection:AddSection(row)
        statusPlacedIn = topSection
    end
end

local function OnAddTopLinesToTopSection(_, topSection, itemLink)
    RestorePendingSection()
    local placed = statusPlacedIn == topSection
    statusPlacedIn = nil
    if placed then
        return
    end
    local result = Evaluator.Evaluate(itemLink)
    if not result then
        return
    end

    local original = topSection.AddSectionEvenIfEmpty
    pendingSection, pendingOriginal = topSection, original
    topSection.AddSectionEvenIfEmpty = function(section, topSubsection, ...)
        RestorePendingSection()
        AddStatusLine(topSubsection, result)
        return original(section, topSubsection, ...)
    end
end

local function OnLayoutMasterWritItem(tooltip, itemLink)
    RestorePendingSection()
    statusPlacedIn = nil
    local result = Evaluator.Evaluate(itemLink)
    if result then
        AddDetailsSection(tooltip, result)
    end
end

local function HookTooltipObject(tooltipObject)
    if type(tooltipObject) ~= "table" and type(tooltipObject) ~= "userdata" then
        return
    end
    if type(tooltipObject.LayoutMasterWritItem) ~= "function" or type(tooltipObject.AddTopLinesToTopSection) ~= "function" then
        return
    end
    -- Tooltips set up after ZO_Tooltip was hooked already carry the hooked functions.
    if tooltipObject ~= ZO_Tooltip and tooltipObject.LayoutMasterWritItem == ZO_Tooltip.LayoutMasterWritItem then
        return
    end
    -- Without it, the status simply goes on the bag count row.
    if type(tooltipObject.AddTypeSlotUniqueLine) == "function" then
        ZO_PreHook(tooltipObject, "AddTypeSlotUniqueLine", OnAddTypeSlotUniqueLine)
    end
    ZO_PreHook(tooltipObject, "AddTopLinesToTopSection", OnAddTopLinesToTopSection)
    -- SecurePostHook keeps our code from tainting the game's own call, but it only takes a table. A tooltip the game
    -- has already set up is a control (userdata), which stopped the add-on loading on console in 1.0, so those get
    -- ZO_PostHook, the plain Lua hook.
    local PostHook = ZO_PostHook
    if SecurePostHook and type(tooltipObject) == "table" then
        PostHook = SecurePostHook
    end
    PostHook(tooltipObject, "LayoutMasterWritItem", OnLayoutMasterWritItem)
end

-- Hooks the gamepad tooltips the game has already set up. Ones not set up yet get the hooks from ZO_Tooltip.
local function HookExistingGamepadTooltips()
    if not GAMEPAD_TOOLTIPS or type(GAMEPAD_TOOLTIPS.tooltips) ~= "table" then
        return
    end
    for _, tooltipInfo in pairs(GAMEPAD_TOOLTIPS.tooltips) do
        local container = tooltipInfo.control and tooltipInfo.control.container
        local tip = container and container.tip
        if tip and tip.initialized and tip.tooltip then
            HookTooltipObject(tip.tooltip)
        end
    end
end

function Tooltip.Initialize()
    HookTooltipObject(ZO_Tooltip)
    HookExistingGamepadTooltips()
end
