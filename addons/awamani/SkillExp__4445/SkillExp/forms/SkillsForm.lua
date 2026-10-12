local ADDON_NAME = "SkillExp"

-- ─────────────────────────────────────────────────────────────────────────────
-- Constants
-- ─────────────────────────────────────────────────────────────────────────────
local FORM_WIDTH = 200
local ROW_HEIGHT = 26
local ROW_GAP = -2
local PADDING = 8
local TEXT_INSET = 6
local TITLE_HEIGHT = 22
local SECTION_GAP = 2
local SECTION_HEADER = 18

local SKILL_FIRST = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1 -- slot 3
local SKILL_LAST = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 -- slot 8
local NUM_SLOTS = SKILL_LAST - SKILL_FIRST + 1 -- 6

local RANK_WIDTH = 22
local PCT_WIDTH = 34
local BAR_WIDTH = FORM_WIDTH - PADDING * 2

local COLOR_BAR_MAX = {
    0.15,
    0.4,
    0.15,
    1
 }
local COLOR_BY_RANK = {
    [0] = {
        0.55,
        0.40,
        0.70,
        1
     }, -- rank 0/unknown: lightest purple
    [1] = {
        0.50,
        0.35,
        0.65,
        1
     }, -- rank I: light purple
    [2] = {
        0.45,
        0.28,
        0.60,
        1
     }, -- rank II: medium purple
    [3] = {
        0.40,
        0.20,
        0.58,
        1
     }, -- rank III: darker purple
    [4] = {
        0.35,
        0.15,
        0.55,
        1
     } -- rank IV: darkest purple
 }
local COLOR_TEXT = {
    1,
    1,
    1,
    1
 }
local COLOR_DIM = {
    0.5,
    0.5,
    0.5,
    0.6
 }
local COLOR_SKILL_LINE = {
    0.25,
    0.45,
    0.65,
    1
 }
local COLOR_SKILL_LINE_MAX = {
    0.15,
    0.4,
    0.15,
    1
 }

local SL_ROW_HEIGHT = 22
local SL_ROW_GAP = -2
local MAX_SKILL_LINES = 12

local PIN_TEXTURE = "EsoUI/Art/Buttons/Gamepad/gp_trackingPin.dds"
local PIN_SIZE = 18

local RANK_NUMERAL = {
    [0] = "",
    "I",
    "II",
    "III",
    "IV"
 }

-- ─────────────────────────────────────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────────────────────────────────────
local form
local frontRows = {}
local backRows = {}
local frontHeader
local backHeader
local skillLineRows = {}
local skillLineHeader
local visibleSkillLineCount = 0
local trackedSkillLines = {} -- key -> {skillType, skillLineIndex}, added on XP gain

-- ─────────────────────────────────────────────────────────────────────────────
-- Skill info lookup
-- ─────────────────────────────────────────────────────────────────────────────
local function GetSkillInfoForSlot(actionSlot, hotbarCategory)
    if not IsSlotUsed(actionSlot, hotbarCategory) then
        return nil
    end

    local abilityId = GetSlotBoundId(actionSlot, hotbarCategory)
    if not abilityId or abilityId == 0 then
        return nil
    end

    local skillName = GetSlotName(actionSlot, hotbarCategory)
    local rank = 0
    local progress = 0
    local isMaxed = false
    local currentXP = nil
    local progressionIndex = nil
    local canMorph = false
    local tooltipText = skillName

    -- Get ability progression XP directly from ability ID (bypasses skillIndex lookup)
    local hasProgression, progIdx, lastRankXP, nextRankXP, atMorph
    hasProgression, progIdx, lastRankXP, nextRankXP, currentXP, atMorph = GetAbilityProgressionXPInfoFromAbilityId(abilityId)

    if hasProgression and progIdx then
        progressionIndex = progIdx
        local _, morph, abilityRank = GetAbilityProgressionInfo(progressionIndex)
        rank = abilityRank or 0

        canMorph = atMorph or false
        local maxed = canMorph or (nextRankXP == 0) or (nextRankXP == lastRankXP)

        if maxed then
            isMaxed = true
            progress = 1
        elseif (nextRankXP - lastRankXP) > 0 then
            progress = (currentXP - lastRankXP) / (nextRankXP - lastRankXP)
            progress = math.min(math.max(progress, 0), 1)
        end

        -- Skill line name for tooltip
        local skillType, skillLineIndex = GetSpecificSkillAbilityKeysByAbilityId(abilityId)
        local lineName = ""
        if skillType then
            local skillLineData = SKILLS_DATA_MANAGER:GetSkillLineDataByIndices(skillType, skillLineIndex)
            lineName = skillLineData and skillLineData:GetName() or ""
        end

        if isMaxed then
            tooltipText = zo_strformat("<<1>>\n<<2>> — Rank <<3>> (MAX)", skillName, lineName, rank)
        else
            local xpInRank = currentXP - lastRankXP
            local xpNeeded = nextRankXP - lastRankXP
            tooltipText = zo_strformat(
                "<<1>>\n<<2>> — Rank <<3>>\n<<4>> / <<5>> XP (<<6>>%)", skillName, lineName, rank, ZO_CommaDelimitNumber(xpInRank),
                ZO_CommaDelimitNumber(xpNeeded), math.floor(progress * 100))
        end
    end

    local isNonLevelable = isMaxed or not hasProgression

    return {
        name = skillName,
        rank = rank,
        progress = progress,
        isMaxed = isMaxed,
        isNonLevelable = isNonLevelable,
        tooltip = tooltipText,
        currentXP = currentXP,
        progressionIndex = progressionIndex,
        canMorph = canMorph or false
     }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Skill line info
-- ─────────────────────────────────────────────────────────────────────────────
local function GetSkillLineInfo(skillType, skillLineIndex)
    local rank, _, isActive, isDiscovered = GetSkillLineDynamicInfo(skillType, skillLineIndex)
    if not isDiscovered then
        return nil
    end

    local lastRankXP, nextRankXP, currentXP = GetSkillLineXPInfo(skillType, skillLineIndex)
    local skillLineId = GetSkillLineId(skillType, skillLineIndex)
    local name = GetSkillLineNameById(skillLineId)

    local isMaxed = (nextRankXP == 0) or (nextRankXP == lastRankXP)
    local progress = 0
    if isMaxed then
        progress = 1
    elseif (nextRankXP - lastRankXP) > 0 then
        progress = (currentXP - lastRankXP) / (nextRankXP - lastRankXP)
        progress = math.min(math.max(progress, 0), 1)
    end

    -- Skill line at 100% with no further rank available is truly maxed
    if not isMaxed and progress >= 1 then
        local _, nextStartXP = GetSkillLineRankXPExtents(skillType, skillLineIndex, rank + 1)
        if not nextStartXP then
            isMaxed = true
        end
    end

    local isNonLevelable = isMaxed or not isActive

    local tooltipText
    if isMaxed then
        tooltipText = zo_strformat("<<1>> — Rank <<2>> (MAX)", name, rank)
    else
        local xpInRank = currentXP - lastRankXP
        local xpNeeded = nextRankXP - lastRankXP
        tooltipText = zo_strformat(
            "<<1>> — Rank <<2>>\n<<3>> / <<4>> XP (<<5>>%)", name, rank, ZO_CommaDelimitNumber(xpInRank), ZO_CommaDelimitNumber(xpNeeded),
            math.floor(progress * 100))
    end

    return {
        name = name,
        rank = rank,
        progress = progress,
        isMaxed = isMaxed,
        isActive = isActive,
        isNonLevelable = isNonLevelable,
        tooltip = tooltipText,
        currentXP = currentXP,
        skillLineId = skillLineId,
        isPinned = SkillExp.config.pinnedSkillLines[skillLineId] == true,
        key = skillType .. "_" .. skillLineIndex
     }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Pinned skill lines (saved per character, removed once the line is maxed)
-- ─────────────────────────────────────────────────────────────────────────────
function SkillExp_IsSkillLinePinned(skillLineId)
    return SkillExp.config.pinnedSkillLines[skillLineId] == true
end

-- Only discovered, active, non-maxed skill lines can be pinned
function SkillExp_CanPinSkillLine(skillLineId)
    local skillType, skillLineIndex = GetSkillLineIndicesFromSkillLineId(skillLineId)
    if not skillType then
        return false
    end
    local info = GetSkillLineInfo(skillType, skillLineIndex)
    return info ~= nil and not info.isNonLevelable
end

function SkillExp_ToggleSkillLinePin(skillLineId)
    local pinned = SkillExp.config.pinnedSkillLines
    if pinned[skillLineId] then
        pinned[skillLineId] = nil
    elseif SkillExp_CanPinSkillLine(skillLineId) then
        pinned[skillLineId] = true
    else
        return
    end
    CALLBACK_MANAGER:FireCallbacks("OnSkillExpPinsChanged")
end

-- Returns true if the pin was removed
local function UnpinIfMaxed(skillType, skillLineIndex)
    local skillLineId = GetSkillLineId(skillType, skillLineIndex)
    if not SkillExp_IsSkillLinePinned(skillLineId) then
        return false
    end
    local info = GetSkillLineInfo(skillType, skillLineIndex)
    if info and info.isActive and info.isMaxed then
        SkillExp.config.pinnedSkillLines[skillLineId] = nil
        return true
    end
    return false
end

local function PruneMaxedPins()
    local removed = false
    for skillLineId in pairs(SkillExp.config.pinnedSkillLines) do
        local skillType, skillLineIndex = GetSkillLineIndicesFromSkillLineId(skillLineId)
        if skillType and UnpinIfMaxed(skillType, skillLineIndex) then
            removed = true
        end
    end
    if removed then
        CALLBACK_MANAGER:FireCallbacks("OnSkillExpPinsChanged")
    end
end

local function CollectUniqueSkillLines()
    local seen = {}
    local lines = {}

    local function processSlots(hotbarCategory)
        for i = SKILL_FIRST, SKILL_LAST do
            if IsSlotUsed(i, hotbarCategory) then
                local abilityId = GetSlotBoundId(i, hotbarCategory)
                if abilityId and abilityId ~= 0 then
                    local skillType, skillLineIndex = GetSpecificSkillAbilityKeysByAbilityId(abilityId)
                    if skillType then
                        local key = skillType .. "_" .. skillLineIndex
                        if not seen[key] then
                            seen[key] = true
                            local info = GetSkillLineInfo(skillType, skillLineIndex)
                            if info and not (SkillExp.config.hideNonLevelable and info.isNonLevelable) then
                                table.insert(lines, info)
                            end
                        end
                    end
                end
            end
        end
    end

    processSlots(HOTBAR_CATEGORY_PRIMARY)
    processSlots(HOTBAR_CATEGORY_BACKUP)

    -- Include pinned skill lines
    for skillLineId in pairs(SkillExp.config.pinnedSkillLines) do
        local skillType, skillLineIndex = GetSkillLineIndicesFromSkillLineId(skillLineId)
        if skillType then
            local key = skillType .. "_" .. skillLineIndex
            if not seen[key] then
                seen[key] = true
                local info = GetSkillLineInfo(skillType, skillLineIndex)
                if info and not (SkillExp.config.hideNonLevelable and info.isNonLevelable) then
                    table.insert(lines, info)
                end
            end
        end
    end

    -- Include skill lines that received XP this session
    if SkillExp.config.trackSkillLineXP then
        for key, entry in pairs(trackedSkillLines) do
            if not seen[key] then
                seen[key] = true
                local info = GetSkillLineInfo(entry.skillType, entry.skillLineIndex)
                if info and not (SkillExp.config.hideNonLevelable and info.isNonLevelable) then
                    table.insert(lines, info)
                end
            end
        end
    else
        trackedSkillLines = {}
    end

    -- Pinned lines first so they are never cut off by MAX_SKILL_LINES
    table.sort(
        lines, function(a, b)
            if a.isPinned ~= b.isPinned then
                return a.isPinned
            end
            return a.name < b.name
        end)
    return lines
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Row creation
-- ─────────────────────────────────────────────────────────────────────────────
local function CreateSkillRow(name, parent, actionSlot, hotbarCategory)
    local row = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    row:SetDimensions(BAR_WIDTH, ROW_HEIGHT)
    row:SetMouseEnabled(true)

    -- Progress bar (fills the row)
    local bar = WINDOW_MANAGER:CreateControlFromVirtual(name .. "Bar", row, "ZO_ArrowStatusBar")
    bar:ClearAnchors()
    bar:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    bar:SetDimensions(BAR_WIDTH, ROW_HEIGHT)

    -- Rank label (floats to the left of the bar)
    local rankLabel = WINDOW_MANAGER:CreateControl(name .. "Rank", row, CT_LABEL)
    rankLabel:SetFont("$(BOLD_FONT)|15|outline")
    rankLabel:SetColor(unpack(COLOR_TEXT))
    rankLabel:SetDimensions(RANK_WIDTH, ROW_HEIGHT)
    rankLabel:SetAnchor(RIGHT, bar, LEFT, -6, 0)
    rankLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    rankLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    -- Percent label (floats to the left of the rank)
    local pctLabel = WINDOW_MANAGER:CreateControl(name .. "Pct", row, CT_LABEL)
    pctLabel:SetFont("$(BOLD_FONT)|14|outline")
    pctLabel:SetColor(unpack(COLOR_TEXT))
    pctLabel:SetDimensions(PCT_WIDTH, ROW_HEIGHT)
    pctLabel:SetAnchor(RIGHT, rankLabel, LEFT, 2, 0)
    pctLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    pctLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    bar:SetMinMax(0, 1)
    bar:SetValue(0)
    bar:SetColor(unpack(COLOR_BY_RANK[0]))

    -- Skill name label (inside bar, vertically centered)
    local label = WINDOW_MANAGER:CreateControl(name .. "Name", row, CT_LABEL)
    label:SetFont("$(BOLD_FONT)|15|outline")
    label:SetColor(unpack(COLOR_TEXT))
    label:SetAnchor(LEFT, bar, LEFT, TEXT_INSET, 0)
    label:SetDimensionConstraints(0, 0, BAR_WIDTH - 10, ROW_HEIGHT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    -- Tooltip
    row:SetHandler(
        "OnMouseEnter", function(self)
            if self.tooltipText then
                ZO_Tooltips_ShowTextTooltip(self, RIGHT, self.tooltipText)
            end
        end)
    row:SetHandler(
        "OnMouseExit", function()
            ZO_Tooltips_HideTextTooltip()
        end)

    -- XP flash label (anchored to the right of the bar)
    local flashLabel = WINDOW_MANAGER:CreateControl(name .. "Flash", row, CT_LABEL)
    flashLabel:SetFont("$(BOLD_FONT)|14|soft-shadow-thick")
    flashLabel:SetColor(0.3, 1, 0.3, 1)
    flashLabel:SetAnchor(LEFT, bar, RIGHT, 4, 0)
    flashLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    flashLabel:SetHidden(true)

    -- Morph badge (shown when ability can be morphed)
    local morphBadge = WINDOW_MANAGER:CreateControl(name .. "Morph", row, CT_TEXTURE)
    morphBadge:SetTexture("EsoUI/Art/Progression/morph_disabled.dds")
    morphBadge:SetDimensions(28, 28)
    morphBadge:SetAnchor(LEFT, bar, RIGHT, 2, 0)
    morphBadge:SetDrawLayer(DL_OVERLAY)
    morphBadge:SetHidden(true)

    return {
        control = row,
        bar = bar,
        label = label,
        rankLabel = rankLabel,
        pctLabel = pctLabel,
        flashLabel = flashLabel,
        morphBadge = morphBadge,
        actionSlot = actionSlot,
        hotbar = hotbarCategory,
        lastXP = nil,
        progressionIndex = nil,
        flashCallId = nil
     }
end

local function CreateSkillLineRow(name, parent, index)
    local row = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    row:SetDimensions(BAR_WIDTH, SL_ROW_HEIGHT)
    row:SetMouseEnabled(true)

    local bar = WINDOW_MANAGER:CreateControlFromVirtual(name .. "Bar", row, "ZO_ArrowStatusBar")
    bar:ClearAnchors()
    bar:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    bar:SetDimensions(BAR_WIDTH, SL_ROW_HEIGHT)
    bar:SetMinMax(0, 1)
    bar:SetValue(0)
    bar:SetColor(unpack(COLOR_SKILL_LINE))

    local rankLabel = WINDOW_MANAGER:CreateControl(name .. "Rank", row, CT_LABEL)
    rankLabel:SetFont("$(BOLD_FONT)|13|outline")
    rankLabel:SetColor(unpack(COLOR_TEXT))
    rankLabel:SetDimensions(RANK_WIDTH, SL_ROW_HEIGHT)
    rankLabel:SetAnchor(RIGHT, bar, LEFT, -6, 0)
    rankLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    rankLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local pctLabel = WINDOW_MANAGER:CreateControl(name .. "Pct", row, CT_LABEL)
    pctLabel:SetFont("$(BOLD_FONT)|13|outline")
    pctLabel:SetColor(unpack(COLOR_TEXT))
    pctLabel:SetDimensions(PCT_WIDTH, SL_ROW_HEIGHT)
    pctLabel:SetAnchor(RIGHT, rankLabel, LEFT, 2, 0)
    pctLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    pctLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local label = WINDOW_MANAGER:CreateControl(name .. "Name", row, CT_LABEL)
    label:SetFont("$(BOLD_FONT)|14|outline")
    label:SetColor(unpack(COLOR_TEXT))
    label:SetAnchor(LEFT, bar, LEFT, TEXT_INSET, 0)
    label:SetDimensionConstraints(0, 0, BAR_WIDTH - 10, SL_ROW_HEIGHT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    row:SetHandler(
        "OnMouseEnter", function(self)
            if self.tooltipText then
                ZO_Tooltips_ShowTextTooltip(self, RIGHT, self.tooltipText)
            end
        end)
    row:SetHandler(
        "OnMouseExit", function()
            ZO_Tooltips_HideTextTooltip()
        end)
    -- Right-click toggles pin
    row:SetHandler(
        "OnMouseUp", function(self, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_RIGHT and self.skillLineId then
                ZO_Tooltips_HideTextTooltip()
                SkillExp_ToggleSkillLinePin(self.skillLineId)
            end
        end)

    local flashLabel = WINDOW_MANAGER:CreateControl(name .. "Flash", row, CT_LABEL)
    flashLabel:SetFont("$(BOLD_FONT)|14|soft-shadow-thick")
    flashLabel:SetColor(0.3, 1, 0.3, 1)
    flashLabel:SetAnchor(LEFT, bar, RIGHT, 4, 0)
    flashLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    flashLabel:SetHidden(true)

    -- Pin icon (inside bar, right edge)
    local pinIcon = WINDOW_MANAGER:CreateControl(name .. "Pin", row, CT_TEXTURE)
    pinIcon:SetTexture(PIN_TEXTURE)
    pinIcon:SetDimensions(PIN_SIZE, PIN_SIZE)
    pinIcon:SetAnchor(RIGHT, bar, RIGHT, -2, 0)
    pinIcon:SetDrawLayer(DL_OVERLAY)
    pinIcon:SetHidden(true)

    return {
        control = row,
        bar = bar,
        label = label,
        rankLabel = rankLabel,
        pctLabel = pctLabel,
        flashLabel = flashLabel,
        pinIcon = pinIcon,
        index = index,
        lastXP = nil,
        flashCallId = nil
     }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Row update
-- ─────────────────────────────────────────────────────────────────────────────
local function UpdateSkillRow(row)
    local info = GetSkillInfoForSlot(row.actionSlot, row.hotbar)

    if info then
        -- Hide maxed/non-levelable bars if setting enabled
        if SkillExp.config.hideNonLevelable and info.isNonLevelable then
            row.hasSkill = false
            row.control:SetHidden(true)
            row.progressionIndex = info.progressionIndex
            return
        end

        row.label:SetText(info.name)
        row.label:SetColor(unpack(COLOR_TEXT))

        local rankText = ""
        if info.rank and info.rank > 0 then
            rankText = RANK_NUMERAL[info.rank] or tostring(info.rank)
        end
        row.rankLabel:SetText(rankText)

        if info.isMaxed then
            row.bar:SetColor(unpack(COLOR_BAR_MAX))
            row.rankLabel:SetColor(unpack(COLOR_BAR_MAX))
        else
            local rankColor = COLOR_BY_RANK[info.rank] or COLOR_BY_RANK[0]
            row.bar:SetColor(unpack(rankColor))
            row.rankLabel:SetColor(unpack(COLOR_TEXT))
        end

        row.bar:SetValue(info.progress)
        if not SkillExp.config.showPercent or info.isMaxed or info.progress == 0 then
            row.pctLabel:SetText("")
        else
            row.pctLabel:SetText(math.floor(info.progress * 100) .. "%")
        end
        row.control.tooltipText = info.tooltip
        row.morphBadge:SetHidden(not info.canMorph)

        row.progressionIndex = info.progressionIndex
        row.hasSkill = true
    else
        row.hasSkill = false
        row.control:SetHidden(true)
        row.progressionIndex = nil
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Refresh
-- ─────────────────────────────────────────────────────────────────────────────
local function LayoutBarRows(rows, y)
    local count = 0
    for _, row in ipairs(rows) do
        if row.hasSkill then
            row.control:ClearAnchors()
            row.control:SetAnchor(TOPLEFT, form, TOPLEFT, PADDING, y)
            row.control:SetHidden(false)
            y = y + ROW_HEIGHT + ROW_GAP
            count = count + 1
        end
    end
    if count > 0 then
        y = y - ROW_GAP
    end
    return y, count
end

local function ApplyLayout()
    if not form then
        return
    end

    local y = 0
    local showBack = SkillExp.config.showBackBar

    -- ── Front bar ──
    frontHeader:SetHidden(true)
    for _, row in ipairs(frontRows) do
        if not row.hasSkill then
            row.control:SetHidden(true)
        end
    end
    local frontCount = 0
    for _, row in ipairs(frontRows) do
        if row.hasSkill then
            frontCount = frontCount + 1
        end
    end
    if frontCount > 0 then
        frontHeader:ClearAnchors()
        frontHeader:SetAnchor(TOPLEFT, form, TOPLEFT, PADDING, y)
        frontHeader:SetHidden(false)
        y = y + SECTION_HEADER
        y = LayoutBarRows(frontRows, y)
    end

    -- ── Back bar ──
    backHeader:SetHidden(true)
    for _, row in ipairs(backRows) do
        row.control:SetHidden(true)
    end
    if showBack then
        local backCount = 0
        for _, row in ipairs(backRows) do
            if row.hasSkill then
                backCount = backCount + 1
            end
        end
        if backCount > 0 then
            y = y + SECTION_GAP
            backHeader:ClearAnchors()
            backHeader:SetAnchor(TOPLEFT, form, TOPLEFT, PADDING, y)
            backHeader:SetHidden(false)
            y = y + SECTION_HEADER
            y = LayoutBarRows(backRows, y)
        end
    end

    -- ── Skill lines ──
    local showLines = SkillExp.config.showSkillLines
    local lines = showLines and CollectUniqueSkillLines() or {}
    visibleSkillLineCount = #lines

    if skillLineHeader then
        skillLineHeader:SetHidden(true)
    end
    for _, slRow in ipairs(skillLineRows) do
        slRow.control:SetHidden(true)
    end

    if visibleSkillLineCount > 0 then
        y = y + SECTION_GAP
        skillLineHeader:ClearAnchors()
        skillLineHeader:SetAnchor(TOPLEFT, form, TOPLEFT, PADDING, y)
        skillLineHeader:SetHidden(false)
        y = y + SECTION_HEADER

        for i, slRow in ipairs(skillLineRows) do
            if i <= visibleSkillLineCount then
                local info = lines[i]
                slRow.label:SetText(info.name)
                slRow.label:SetDimensionConstraints(0, 0, BAR_WIDTH - 10 - (info.isPinned and PIN_SIZE or 0), SL_ROW_HEIGHT)
                slRow.pinIcon:SetHidden(not info.isPinned)
                slRow.rankLabel:SetText(tostring(info.rank))
                if info.isMaxed then
                    slRow.bar:SetColor(unpack(COLOR_SKILL_LINE_MAX))
                    slRow.rankLabel:SetColor(unpack(COLOR_SKILL_LINE_MAX))
                else
                    slRow.bar:SetColor(unpack(COLOR_SKILL_LINE))
                    slRow.rankLabel:SetColor(unpack(COLOR_TEXT))
                end
                slRow.bar:SetValue(info.progress)
                if not SkillExp.config.showPercent or info.isMaxed or info.progress == 0 then
                    slRow.pctLabel:SetText("")
                else
                    slRow.pctLabel:SetText(math.floor(info.progress * 100) .. "%")
                end
                if info.isPinned then
                    slRow.control.tooltipText = info.tooltip .. "\n|c888888Right-click to unpin|r"
                elseif not info.isNonLevelable then
                    slRow.control.tooltipText = info.tooltip .. "\n|c888888Right-click to pin|r"
                else
                    slRow.control.tooltipText = info.tooltip
                end
                slRow.control.skillLineId = info.skillLineId

                -- XP flash
                if not info.isMaxed and info.currentXP and slRow.lastXP and slRow.lineKey == info.key and info.currentXP > slRow.lastXP then
                    local delta = info.currentXP - slRow.lastXP
                    slRow.flashLabel:SetText("+" .. ZO_CommaDelimitNumber(delta))
                    slRow.flashLabel:SetHidden(false)
                    if slRow.flashCallId then
                        zo_removeCallLater(slRow.flashCallId)
                    end
                    slRow.flashCallId = zo_callLater(
                        function()
                            slRow.flashLabel:SetHidden(true)
                            slRow.flashCallId = nil
                        end, 1500)
                end
                slRow.lineKey = info.key
                if not info.isMaxed then
                    slRow.lastXP = info.currentXP
                end

                slRow.control:ClearAnchors()
                slRow.control:SetAnchor(TOPLEFT, form, TOPLEFT, PADDING, y)
                slRow.control:SetHidden(false)
                y = y + SL_ROW_HEIGHT + SL_ROW_GAP
            else
                slRow.lineKey = nil
                slRow.lastXP = nil
                slRow.control.skillLineId = nil
            end
        end
        y = y - SL_ROW_GAP
    end

    form:SetHeight(y)
end

local function RefreshAll()
    if not form or form:IsHidden() then
        return
    end
    for _, row in ipairs(frontRows) do
        UpdateSkillRow(row)
    end
    for _, row in ipairs(backRows) do
        UpdateSkillRow(row)
    end
    ApplyLayout()
end

local function FreshLoad()
    for _, row in ipairs(frontRows) do
        row.lastXP = nil
        UpdateSkillRow(row)
        -- Store initial XP for flash delta detection
        local info = GetSkillInfoForSlot(row.actionSlot, row.hotbar)
        if info then
            row.lastXP = info.currentXP
        end
    end
    for _, row in ipairs(backRows) do
        row.lastXP = nil
        UpdateSkillRow(row)
        local info = GetSkillInfoForSlot(row.actionSlot, row.hotbar)
        if info then
            row.lastXP = info.currentXP
        end
    end
    ApplyLayout()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Toggle
-- ─────────────────────────────────────────────────────────────────────────────
function SkillExp_ToggleSkillsForm()
    if not form then
        return
    end
    local willOpen = form:IsHidden()
    form:SetHidden(not willOpen)
    SkillExp.config.formShown = willOpen
    if willOpen then
        FreshLoad()
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Form creation
-- ─────────────────────────────────────────────────────────────────────────────
local function CreateSkillsForm()
    -- Main form
    form = WINDOW_MANAGER:CreateControl("SkillExpSkillsForm", SkillExpContainer, CT_CONTROL)
    form:SetDimensions(FORM_WIDTH, SECTION_HEADER)
    form:SetMouseEnabled(true)
    form:SetMovable(true)
    form:SetClampedToScreen(true)
    form:SetHidden(true)

    -- TEST: always-visible morph icon at top of form
    -- Restore saved position
    local pos = SkillExp.config.formPos
    if pos then
        form:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    else
        form:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end

    -- Save position on drag
    form:SetHandler(
        "OnMoveStop", function(self)
            SkillExp.config.formPos = {
                x = self:GetLeft(),
                y = self:GetTop()
             }
        end)

    local y = 0

    -- ── Front Bar ────────────────────────────────────────────────────────────
    frontHeader = WINDOW_MANAGER:CreateControl("SkillExpFrontHeader", form, CT_LABEL)
    frontHeader:SetFont("$(BOLD_FONT)|14|soft-shadow-thin")
    frontHeader:SetColor(0.9, 0.8, 0.5, 1)
    frontHeader:SetText("Front Bar")
    frontHeader:SetAnchor(TOPLEFT, form, TOPLEFT, PADDING, y)
    y = y + SECTION_HEADER

    for i = SKILL_FIRST, SKILL_LAST do
        local idx = i - SKILL_FIRST
        local row = CreateSkillRow("SkillExpFront" .. idx, form, i, HOTBAR_CATEGORY_PRIMARY)
        row.control:SetAnchor(TOPLEFT, form, TOPLEFT, PADDING, y)
        table.insert(frontRows, row)
        y = y + ROW_HEIGHT + ROW_GAP
    end

    y = y - ROW_GAP + SECTION_GAP

    -- ── Back Bar ─────────────────────────────────────────────────────────────
    backHeader = WINDOW_MANAGER:CreateControl("SkillExpBackHeader", form, CT_LABEL)
    backHeader:SetFont("$(BOLD_FONT)|14|soft-shadow-thin")
    backHeader:SetColor(0.9, 0.8, 0.5, 1)
    backHeader:SetText("Back Bar")
    backHeader:SetAnchor(TOPLEFT, form, TOPLEFT, PADDING, y)
    y = y + SECTION_HEADER

    for i = SKILL_FIRST, SKILL_LAST do
        local idx = i - SKILL_FIRST
        local row = CreateSkillRow("SkillExpBack" .. idx, form, i, HOTBAR_CATEGORY_BACKUP)
        row.control:SetAnchor(TOPLEFT, form, TOPLEFT, PADDING, y)
        table.insert(backRows, row)
        y = y + ROW_HEIGHT + ROW_GAP
    end

    -- ── Skill Lines ──────────────────────────────────────────────────────────
    skillLineHeader = WINDOW_MANAGER:CreateControl("SkillExpLineHeader", form, CT_LABEL)
    skillLineHeader:SetFont("$(BOLD_FONT)|14|soft-shadow-thin")
    skillLineHeader:SetColor(0.9, 0.8, 0.5, 1)
    skillLineHeader:SetText("Skill Lines")
    skillLineHeader:SetAnchor(TOPLEFT, form, TOPLEFT, PADDING, y)
    skillLineHeader:SetHidden(true)

    for i = 1, MAX_SKILL_LINES do
        local slRow = CreateSkillLineRow("SkillExpLine" .. i, form, i)
        slRow.control:SetHidden(true)
        table.insert(skillLineRows, slRow)
    end

    -- Store reference
    SkillExp.skillsForm = form

    -- Fresh data load when HUD scene returns (e.g. after closing Skills window)
    local function onSceneStateChange(oldState, newState)
        if newState == SCENE_SHOWN then
            if form and SkillExp.config.formShown then
                FreshLoad()
            end
        end
    end
    SCENE_MANAGER:GetScene("hud"):RegisterCallback("StateChange", onSceneStateChange)
    SCENE_MANAGER:GetScene("hudui"):RegisterCallback("StateChange", onSceneStateChange)

    -- Apply back bar visibility
    ApplyLayout()

    -- Restore visibility from saved setting
    if SkillExp.config.formShown then
        form:SetHidden(false)
        -- Data populated by EVENT_PLAYER_ACTIVATED handler below
    end

    -- ── Events ───────────────────────────────────────────────────────────────
    local function ResetAndRefresh()
        for _, row in ipairs(frontRows) do
            row.lastXP = nil
        end
        for _, row in ipairs(backRows) do
            row.lastXP = nil
        end
        RefreshAll()
    end

    -- Settings changed → refresh visibility of percent labels
    CALLBACK_MANAGER:RegisterCallback("OnSkillExpSettingChanged", RefreshAll)
    CALLBACK_MANAGER:RegisterCallback("OnSkillExpPinsChanged", RefreshAll)

    -- Skill data is reliable only after activation; drop pins of lines that maxed meanwhile
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_PinPrune", EVENT_PLAYER_ACTIVATED, PruneMaxedPins)

    local function OnSkillLineChanged(skillType, skillLineIndex)
        if UnpinIfMaxed(skillType, skillLineIndex) then
            CALLBACK_MANAGER:FireCallbacks("OnSkillExpPinsChanged")
        else
            RefreshAll()
        end
    end

    -- Core events (proven to work — registered FIRST)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_SlotUpdate", EVENT_ACTION_SLOT_UPDATED, RefreshAll)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_HotbarsUpdate", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, RefreshAll)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_WeaponSwap", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, ResetAndRefresh)
    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_SkillRank", EVENT_SKILL_RANK_UPDATE, function(eventCode, skillType, skillLineIndex)
            OnSkillLineChanged(skillType, skillLineIndex)
        end)
    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_SkillXP", EVENT_SKILL_XP_UPDATE, function(eventCode, skillType, skillLineIndex, reason, rank, previousXP, currentXP)
            if SkillExp.config.trackSkillLineXP then
                local key = skillType .. "_" .. skillLineIndex
                trackedSkillLines[key] = {
                    skillType = skillType,
                    skillLineIndex = skillLineIndex
                 }
            end
            OnSkillLineChanged(skillType, skillLineIndex)
        end)

    -- Ability progression XP update (rank I→IV per ability)
    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_AbilityXP", EVENT_ABILITY_PROGRESSION_XP_UPDATE,
        function(eventCode, progressionIndex, lastRankXP, nextRankXP, currentXP, atMorph)
            if not form then
                return
            end
            local isMaxed = atMorph or (nextRankXP == 0) or (nextRankXP == lastRankXP)

            local function updateRows(rows)
                for _, row in ipairs(rows) do
                    if row.progressionIndex == progressionIndex then
                        -- Flash: delta from stored lastXP (skip for maxed — bogus XP values)
                        if not isMaxed and currentXP and row.lastXP and currentXP > row.lastXP then
                            local delta = currentXP - row.lastXP
                            row.flashLabel:SetText("+" .. ZO_CommaDelimitNumber(delta))
                            row.flashLabel:SetHidden(false)
                            if row.flashCallId then
                                zo_removeCallLater(row.flashCallId)
                            end
                            row.flashCallId = zo_callLater(
                                function()
                                    row.flashLabel:SetHidden(true)
                                    row.flashCallId = nil
                                end, 1500)
                        end
                        if not isMaxed then
                            row.lastXP = currentXP
                        end
                        -- Refresh bar/tooltip (always — updates progress to 100% and shows morph badge)
                        UpdateSkillRow(row)
                    end
                end
            end
            updateRows(frontRows)
            updateRows(backRows)
            ApplyLayout()
        end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Init
-- ─────────────────────────────────────────────────────────────────────────────
CALLBACK_MANAGER:RegisterCallback("OnSkillExpInitialized", CreateSkillsForm)
