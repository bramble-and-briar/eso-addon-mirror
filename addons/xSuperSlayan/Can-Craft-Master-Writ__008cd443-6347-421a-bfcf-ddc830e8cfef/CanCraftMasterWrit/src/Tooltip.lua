-- Adds the check results to the game's gamepad item tooltip (used on console and in gamepad mode on PC).
--
-- Every master writ tooltip is drawn by ZO_Tooltip:LayoutMasterWritItem, whether the writ is in the bags,
-- the bank, a guild trader, the mail or a chat link, so that is the one place we hook:
--   * The overall status (CRAFTABLE) goes at the right end of the top row, the row with the bag count above
--     "Quest Starter". The game builds that row in AddTopLinesToTopSection and hands it to the top section with
--     AddSectionEvenIfEmpty; we add our line just before that hand-over.
--   * The individual checks go in a section at the bottom, after the game's own text.
--
-- ZO_Tooltip copies its functions into each tooltip when the tooltip is first set up, so we hook ZO_Tooltip itself
-- (for tooltips set up later) and every gamepad tooltip that already exists.

local addon = CanCraftMasterWrit
local Result = addon.Result
local Evaluator = addon.Evaluator
local Settings = addon.Settings

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
    [Result.CATEGORY_SKILLS] = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_skills.dds",
    [Result.CATEGORY_MATERIALS] = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_materials.dds",
}
Tooltip.CATEGORY_ICON = CATEGORY_ICON

local STATUS_TEXT = {
    [Result.STATUS_CRAFTABLE] = SI_CCMW_STATUS_CRAFTABLE,
    [Result.STATUS_NOT_CRAFTABLE] = SI_CCMW_STATUS_NOT_CRAFTABLE,
    [Result.STATUS_UNKNOWN] = SI_CCMW_STATUS_UNKNOWN,
}

-- The status is drawn in capitals (CRAFTABLE), like the rest of the top section. The game does the capitals, so the
-- text stays in normal case for chat and screen narration, and works in every language.
local STATUS_STYLE = {
    [Result.STATUS_CRAFTABLE] = { fontColorField = GAMEPAD_TOOLTIP_COLOR_SUCCEEDED, uppercase = true },
    [Result.STATUS_NOT_CRAFTABLE] = { fontColorField = GAMEPAD_TOOLTIP_COLOR_FAILED, uppercase = true },
    [Result.STATUS_UNKNOWN] = { fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_2, uppercase = true },
}

-- Below this width the status isn't pushed right; it just follows the bag count like any other line.
local MIN_STATUS_WIDTH = 200

local LINE_SPACING = 4   -- Between lines in a group (the section's childSpacing).
local GROUP_SPACING = 30 -- Above the first line of a new group.

-- About two blank lines separate the game's own text (the writ's description) from ours, with a divider line in the
-- middle: the game's own divider (as between the sets of a set box in itemtooltips.lua), at half its usual opacity.
local DIVIDER_GAP = 35

local DIVIDER_SECTION_STYLE = {
    customSpacing = DIVIDER_GAP,
    widthPercent = 100,
}

local DIVIDER_STYLE = {
    -- The game's "dividerLine" style (tooltipstyles.lua).
    textureCoordinateLeft = 0.25,
    textureCoordinateRight = 0.75,
    textureCoordinateTop = 0.25,
    textureCoordinateBottom = 0.75,
    widthPercent = 100,
    height = 8,
    color = ZO_ColorDef:New(1, 1, 1, 0.5), -- The picture's own colour, half transparent.
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

-- Lines are grouped, with a gap between groups: what you know (motif, or runes, reagents or recipe), then trait and
-- set, then skills, then materials. Lines in the same group sit together.
local CATEGORY_GROUP = {
    [Result.CATEGORY_GENERAL] = 0,
    [Result.CATEGORY_MOTIF] = 1,
    [Result.CATEGORY_RUNES] = 1,
    [Result.CATEGORY_REAGENTS] = 1,
    [Result.CATEGORY_RECIPE] = 1,
    [Result.CATEGORY_TRAIT] = 2,
    [Result.CATEGORY_SET] = 2,
    [Result.CATEGORY_SKILLS] = 3,
    [Result.CATEGORY_MATERIALS] = 4,
}

-- Lines whose value goes on its own line under the label, because it is long (a motif's full name).
local VALUE_ON_NEW_LINE = {
    [Result.CATEGORY_MOTIF] = true,
}

local function CheckStyle(state, startsGroup)
    return {
        fontColorField = STATE_COLOR[state],
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

---------------------------------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------------------------------

function Tooltip.GetStatusText(result)
    return GetString(STATUS_TEXT[result.status])
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
    row:AddLine(Tooltip.GetStatusText(result), style)
end

local function AddDetailsSection(tooltip, result)
    local section = tooltip:AcquireSection(DETAILS_SECTION_STYLE)
    local previousGroup
    for _, check in ipairs(result.checks) do
        if Settings.IsStateShown(check.state) then
            local group = CATEGORY_GROUP[check.category] or 0
            local startsGroup = previousGroup ~= nil and group ~= previousGroup
            if not previousGroup then
                -- The divider goes in only when there is at least one line to show under it.
                local divider = tooltip:AcquireSection(DIVIDER_SECTION_STYLE)
                divider:AddTexture(ZO_GAMEPAD_HEADER_DIVIDER_TEXTURE, DIVIDER_STYLE)
                tooltip:AddSection(divider)
            end
            previousGroup = group
            -- The plain text is given as narration so screen narration doesn't read out the icon and colour markup.
            section:AddLineWithCustomNarration(Tooltip.FormatCheck(check), check.text, CheckStyle(check.state, startsGroup))
            if #check.details > 0 then
                local detailList = section:AcquireSection(DETAIL_LIST_STYLE)
                for _, detail in ipairs(check.details) do
                    detailList:AddLineWithCustomNarration(Tooltip.FormatLabelValue(detail.label, detail.value),
                        detail.text, DETAIL_STYLE)
                end
                section:AddSection(detailList)
            end
        end
    end
    tooltip:AddSection(section)
end

---------------------------------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------------------------------

-- The top section waiting for our status line, and its own AddSectionEvenIfEmpty, so it can always be put back.
-- Sections are pooled and reused for other items, so a leftover wrapper would print our status on them.
local pendingSection, pendingOriginal

local function RestorePendingSection()
    if pendingSection then
        pendingSection.AddSectionEvenIfEmpty = pendingOriginal
        pendingSection, pendingOriginal = nil, nil
    end
end

local function OnAddTopLinesToTopSection(_, topSection, itemLink)
    RestorePendingSection()
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
    ZO_PreHook(tooltipObject, "AddTopLinesToTopSection", OnAddTopLinesToTopSection)
    -- SecurePostHook keeps our code from tainting the game's own call; ZO_PostHook is the plain Lua fallback.
    local PostHook = SecurePostHook or ZO_PostHook
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
