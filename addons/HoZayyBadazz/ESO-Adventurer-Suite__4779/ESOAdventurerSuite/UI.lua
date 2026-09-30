-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

local EPC = ESOProgressionCoach
EPC.UI = EPC.UI or {}
local U = EPC.UI

local wm = WINDOW_MANAGER
local EXPANDED_HEIGHT = 735
local ENDGAME_BUILD_HEIGHT = 875
local MAP_EXPANDED_HEIGHT = 820
local ACTIVITY_EXPANDED_HEIGHT = 850
local TOOLS_EXPANDED_HEIGHT = 865
local QUEST_EXPANDED_HEIGHT = 930
local GEAR_EXPANDED_HEIGHT = 900
local MINIMIZED_HEIGHT = 72
local MINIMUM_WIDTH = 760
local MAXIMUM_WIDTH = 940
local TAB_GAP = 4
local STAT_ROWS = 4
local LIST_ROWS = 3
local TRAVEL_ROWS = 4
local ACTIVITY_ROWS = 4
local TOOLS_ROWS = 5
local QUEST_ROWS = 8
local SET_ROWS = 6

local C = {
    bg = {0.020, 0.024, 0.034, 0.97},
    panel = {0.042, 0.050, 0.067, 0.98},
    panel2 = {0.055, 0.064, 0.084, 0.98},
    edge = {0.17, 0.20, 0.27, 0.95},
    edgeSoft = {0.11, 0.13, 0.18, 0.9},
    gold = {0.91, 0.70, 0.28, 1},
    goldSoft = {0.55, 0.39, 0.14, 1},
    blue = {0.38, 0.68, 0.94, 1},
    purple = {0.54, 0.42, 0.88, 1},
    white = {0.95, 0.96, 0.98, 1},
    text = {0.76, 0.80, 0.86, 1},
    muted = {0.52, 0.57, 0.65, 1},
    green = {0.47, 0.83, 0.60, 1},
    orange = {0.95, 0.61, 0.25, 1},
    red = {0.92, 0.38, 0.36, 1},
}

local WRAP_TRUNCATE = TEXT_WRAP_MODE_TRUNCATE or TEXT_WRAP_MODE_ELLIPSIS
local WRAP_ELLIPSIS = TEXT_WRAP_MODE_ELLIPSIS or TEXT_WRAP_MODE_TRUNCATE

local function makeBackdrop(parent, name, centerColor, edgeColor)
    local control = wm:CreateControl(name, parent, CT_BACKDROP)
    control:SetCenterColor(unpack(centerColor or C.panel))
    control:SetEdgeColor(unpack(edgeColor or C.edge))
    control:SetEdgeTexture(nil, 1, 1, 1)
    return control
end

local function makeLabel(parent, name, font, color, options)
    options = options or {}
    local label = wm:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font)
    label:SetColor(unpack(color or C.white))
    if label.SetHorizontalAlignment then
        label:SetHorizontalAlignment(options.horizontalAlignment or TEXT_ALIGN_LEFT)
    end
    if label.SetVerticalAlignment then
        label:SetVerticalAlignment(options.verticalAlignment or TEXT_ALIGN_TOP)
    end
    if label.SetWrapMode then
        label:SetWrapMode(options.wrapped and WRAP_TRUNCATE or WRAP_ELLIPSIS)
    end
    if label.SetMaxLineCount then
        label:SetMaxLineCount(options.maxLines or (options.wrapped and 0 or 1))
    end
    if options.lineSpacing and label.SetLineSpacing then
        label:SetLineSpacing(options.lineSpacing)
    end
    label.epcWrapped = options.wrapped == true
    label.epcMaxLines = options.maxLines
    return label
end

local function makeButton(parent, name, text, width, height, handler)
    local button = wm:CreateControl(name, parent, CT_BUTTON)
    button:SetDimensions(width, height)
    button:SetFont("ZoFontGameBold")
    button:SetText(text)
    if button.SetHorizontalAlignment then button:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    if button.SetVerticalAlignment then button:SetVerticalAlignment(TEXT_ALIGN_CENTER) end
    button:SetNormalFontColor(unpack(C.text))
    if button.SetMouseOverFontColor then button:SetMouseOverFontColor(unpack(C.gold)) end
    if button.SetPressedFontColor then button:SetPressedFontColor(unpack(C.white)) end
    if button.SetMouseEnabled then button:SetMouseEnabled(true) end
    local border = wm:CreateControl(name .. "Border", button, CT_BACKDROP)
    border:SetAnchor(TOPLEFT, button, TOPLEFT, 1, 1)
    border:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, -1, -1)
    border:SetCenterColor(0.035,0.050,0.072,0.55)
    border:SetEdgeColor(0.24,0.36,0.54,0.92)
    border:SetEdgeTexture(nil,1,1,1)
    if border.SetDrawLevel then border:SetDrawLevel(0) end
    button.easBorder = border
    button:SetHandler("OnClicked", handler)
    return button
end

local function getStringWidth(label, text)
    if label and type(label.GetStringWidth) == "function" then
        local ok, width = pcall(label.GetStringWidth, label, text)
        if ok and type(width) == "number" then return width end
    end
    return string.len(text or "") * 8
end

local function fitWithEllipsis(label, text, maxWidth)
    local suffix = "..."
    local fitted = tostring(text or "")
    while fitted ~= "" and getStringWidth(label, fitted .. suffix) > maxWidth do
        fitted = string.sub(fitted, 1, -2)
    end
    return fitted .. suffix
end

local function fitSingleLine(control, text, maxWidth)
    text = tostring(text or "")
    if getStringWidth(control, text) <= maxWidth then return text end
    return fitWithEllipsis(control, text, maxWidth)
end

-- UI-local number formatter used by the compact combat HUD.
-- Keep this local so UI.lua does not depend on private helpers from other modules.
local function formatNumber(value)
    local number = math.floor(tonumber(value) or 0)
    local sign = number < 0 and "-" or ""
    local digits = tostring(math.abs(number))
    local parts = {}

    while #digits > 3 do
        table.insert(parts, 1, string.sub(digits, -3))
        digits = string.sub(digits, 1, -4)
    end
    table.insert(parts, 1, digits)
    return sign .. table.concat(parts, ",")
end

local function wrapText(label, text)
    text = tostring(text or "")
    text = string.gsub(text, "[\r\n\t]+", " ")
    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    if text == "" or not label or not label.epcWrapped then return text end

    local maxWidth = tonumber(label.epcWrapWidth)
    if not maxWidth or maxWidth <= 0 then
        if type(label.GetWidth) == "function" then
            local ok, width = pcall(label.GetWidth, label)
            if ok then maxWidth = tonumber(width) end
        end
    end
    if not maxWidth or maxWidth <= 0 then return text end

    local lines, current = {}, ""
    for word in string.gmatch(text, "%S+") do
        local candidate = current == "" and word or (current .. " " .. word)
        if current == "" or getStringWidth(label, candidate) <= maxWidth then
            current = candidate
        else
            lines[#lines + 1] = current
            current = word
        end
    end
    if current ~= "" then lines[#lines + 1] = current end

    local maxLines = tonumber(label.epcMaxLines)
    if maxLines and maxLines > 0 and #lines > maxLines then
        local visible = {}
        for i = 1, maxLines - 1 do visible[i] = lines[i] end
        local overflow = {}
        for i = maxLines, #lines do overflow[#overflow + 1] = lines[i] end
        visible[maxLines] = fitWithEllipsis(label, table.concat(overflow, " "), maxWidth)
        lines = visible
    end
    return table.concat(lines, "\n")
end

local function setWrappedText(label, text)
    label:SetText(wrapText(label, text))
end

local function setButtonEnabled(button, enabled)
    if button.SetEnabled then button:SetEnabled(enabled) end
    if button.SetMouseEnabled then button:SetMouseEnabled(enabled) end
    button:SetNormalFontColor(unpack(enabled and C.text or C.muted))
end

local function setCardStyle(card, state)
    if not card then return end
    if state == "selected" then
        card:SetCenterColor(0.10, 0.085, 0.045, 0.98)
        card:SetEdgeColor(unpack(C.gold))
    elseif state == "featured" then
        card:SetCenterColor(0.065, 0.055, 0.035, 0.98)
        card:SetEdgeColor(unpack(C.goldSoft))
    elseif state == "disabled" then
        card:SetCenterColor(0.030, 0.034, 0.043, 0.92)
        card:SetEdgeColor(unpack(C.edgeSoft))
    else
        card:SetCenterColor(unpack(C.panel2))
        card:SetEdgeColor(unpack(C.edge))
    end
end

function U:CreateCombatHUD()
    local saved = EPC.saved
    local hud = wm:CreateTopLevelWindow("EPC_CombatHUD")
    hud:SetDimensions(640, 116)
    local savedHudLeft = tonumber(saved.combatHudLeft)
    local savedHudTop = tonumber(saved.combatHudTop)
    if savedHudLeft and savedHudLeft >= 0 and savedHudTop and savedHudTop >= 0 then
        hud:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, savedHudLeft, savedHudTop)
    else
        hud:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -42, 165)
    end
    hud:SetScale(tonumber(saved.combatHudScale) or 1.0)
    hud:SetAlpha(tonumber(saved.combatHudAlpha) or 0.94)
    hud:SetClampedToScreen(true)
    hud:SetMouseEnabled(false)
    hud:SetMovable(false)
    hud:SetHidden(true)
    hud:SetHandler("OnMoveStop", function(control)
        EPC.saved.combatHudLeft = control:GetLeft()
        EPC.saved.combatHudTop = control:GetTop()
    end)

    local bg = makeBackdrop(hud, "EPC_CombatHUD_BG", {0.018, 0.022, 0.030, 0.94}, C.edge)
    bg:SetAnchorFill(hud)
    local accent = wm:CreateControl("EPC_CombatHUD_Accent", hud, CT_BACKDROP)
    accent:SetAnchor(TOPLEFT, hud, TOPLEFT, 0, 0)
    accent:SetAnchor(BOTTOMLEFT, hud, BOTTOMLEFT, 0, 0)
    accent:SetWidth(3)
    accent:SetCenterColor(unpack(C.gold))
    accent:SetEdgeColor(0, 0, 0, 0)

    local title = makeLabel(hud, "EPC_CombatHUD_Title", "ZoFontGameBold", C.gold)
    title:SetAnchor(TOPLEFT, hud, TOPLEFT, 12, 6)
    title:SetDimensions(260, 20)
    local status = makeLabel(hud, "EPC_CombatHUD_Status", "ZoFontGameSmall", C.muted, { horizontalAlignment = TEXT_ALIGN_RIGHT })
    status:SetAnchor(TOPRIGHT, hud, TOPRIGHT, -10, 7)
    status:SetDimensions(310, 18)

    local divider = wm:CreateControl("EPC_CombatHUD_Divider", hud, CT_BACKDROP)
    divider:SetAnchor(TOPLEFT, hud, TOPLEFT, 10, 27)
    divider:SetAnchor(TOPRIGHT, hud, TOPRIGHT, -10, 27)
    divider:SetHeight(1)
    divider:SetCenterColor(unpack(C.edgeSoft))
    divider:SetEdgeColor(0, 0, 0, 0)

    local columns = { 12, 166, 320, 474 }
    local rows = { 34, 60, 86 }
    local metricNames = {
        { "DPS", "DMG", "CRIT", "HITS" },
        { "HPS", "HEAL", "CRIT_HEAL", "HEALS" },
        { "DTPS", "TAKEN", "BLOCK", "IN_HITS" },
    }
    local metrics = {}
    for row = 1, 3 do
        for col = 1, 4 do
            local key = metricNames[row][col]
            local label = makeLabel(hud, "EPC_CombatHUD_" .. key, "ZoFontGameSmall", C.muted)
            label:SetAnchor(TOPLEFT, hud, TOPLEFT, columns[col], rows[row])
            label:SetDimensions(col == 4 and 152 or 146, 22)
            metrics[key] = label
        end
    end

    self.combatHud = hud
    self.combatHudBackground = bg
    self.combatHudAccent = accent
    self.combatHudTitle = title
    self.combatHudStatus = status
    self.combatHudMetrics = metrics
    self.combatHudMoveMode = false
end

function U:ApplyCombatHUDRoleTheme(role)
    if not self.combatHudMetrics then return end
    local row1 = { self.combatHudMetrics.DPS, self.combatHudMetrics.DMG, self.combatHudMetrics.CRIT, self.combatHudMetrics.HITS }
    local row2 = { self.combatHudMetrics.HPS, self.combatHudMetrics.HEAL, self.combatHudMetrics.CRIT_HEAL, self.combatHudMetrics.HEALS }
    local row3 = { self.combatHudMetrics.DTPS, self.combatHudMetrics.TAKEN, self.combatHudMetrics.BLOCK, self.combatHudMetrics.IN_HITS }
    local function colorRow(row, color)
        for i = 1, #row do if row[i] then row[i]:SetColor(unpack(color)) end end
    end
    colorRow(row1, C.muted)
    colorRow(row2, C.muted)
    colorRow(row3, C.muted)
    local accent = C.gold
    if role == "HEALER" then
        colorRow(row2, C.green)
        accent = C.green
    elseif role == "TANK" then
        colorRow(row3, C.orange)
        accent = C.orange
    else
        colorRow(row1, C.white)
        if self.combatHudMetrics.CRIT then self.combatHudMetrics.CRIT:SetColor(unpack(C.gold)) end
    end
    if self.combatHudAccent then self.combatHudAccent:SetCenterColor(unpack(accent)) end
    if self.combatHudTitle then self.combatHudTitle:SetColor(unpack(accent)) end
end

function U:SetCombatHUDMoveMode(active)
    if not self.combatHud then return end
    active = active == true
    self.combatHudMoveMode = active
    self.combatHud:SetMouseEnabled(active)
    self.combatHud:SetMovable(active)
    if self.combatHudBackground then
        self.combatHudBackground:SetEdgeColor(unpack(active and C.gold or C.edge))
    end
    if active then
        local summary = EPC.Combat and EPC.Combat:GetHUDSummary() or nil
        self:UpdateCombatHUD(summary)
    else
        self:UpdateCombatHUD(EPC.Combat and EPC.Combat:GetHUDSummary() or nil)
    end
end

function U:ResetCombatHUDPosition()
    if not self.combatHud then return end
    self.combatHud:ClearAnchors()
    self.combatHud:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -42, 165)
    EPC.saved.combatHudLeft = -1
    EPC.saved.combatHudTop = -1
end

local function setTextIfChanged029769(control, value)
    if not control then return end
    value = tostring(value or "")
    if control.easLastText029769 ~= value then
        control.easLastText029769 = value
        control:SetText(value)
    end
end

function U:UpdateCombatHUD(summary)
    if not self.combatHud or not EPC.saved then return end
    local movePreview = self.combatHudMoveMode == true or EPC.combatHudMoveMode == true or EPC.unitFramesMoveMode == true
    local hudSuppressed = not movePreview and EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() == true
    local modeAllowed = not EPC.OverlayModeAllows or EPC:OverlayModeAllows("combatHudVisibility")
    local alwaysMode = EPC.saved and string.upper(tostring(EPC.saved.combatHudVisibility or "COMBAT")) == "ALWAYS"
    local shouldShow = not hudSuppressed and (movePreview or (EPC.saved.showCombatHud ~= false and modeAllowed and (summary ~= nil or alwaysMode)))
    self.combatHud:SetHidden(not shouldShow)
    if not shouldShow then return end

    summary = summary or {
        active = false, duration = 0, dps = 0, totalDamage = 0, hits = 0, criticalHits = 0,
        hps = 0, totalHealing = 0, healEvents = 0, criticalHeals = 0,
        criticalEventPercent = 0, criticalHealPercent = 0,
        dtps = 0, incomingDamage = 0, incomingHits = 0, blockedHits = 0, blockPercent = 0,
        role = EPC.Role and EPC.Role:GetRole() or "DAMAGE",
    }

    local role = summary.role or (EPC.Role and EPC.Role:GetRole()) or "DAMAGE"
    self:ApplyCombatHUDRoleTheme(role)
    setTextIfChanged029769(self.combatHudTitle, string.format("COMBAT  •  %s", role))
    if movePreview then
        setTextIfChanged029769(self.combatHudStatus, "DRAG TO MOVE  •  /esosuite hud lock")
    elseif summary.active then
        if (summary.petDamage or 0) > 0 or (summary.companionDamage or 0) > 0 then
            setTextIfChanged029769(self.combatHudStatus, string.format("LIVE  %.1fs  •  ALL %s DPS", summary.duration or 0, formatNumber(summary.combinedDps or summary.dps or 0)))
        else
            setTextIfChanged029769(self.combatHudStatus, string.format("LIVE  %.1fs", summary.duration or 0))
        end
    else
        if (summary.petDamage or 0) > 0 or (summary.companionDamage or 0) > 0 then
            setTextIfChanged029769(self.combatHudStatus, string.format("LAST %.1fs  •  ALL %s DPS", summary.duration or 0, formatNumber(summary.combinedDps or summary.dps or 0)))
        else
            setTextIfChanged029769(self.combatHudStatus, string.format("LAST FIGHT  %.1fs", summary.duration or 0))
        end
    end

    local m = self.combatHudMetrics
    setTextIfChanged029769(m.DPS, string.format("DPS  %s", formatNumber(summary.dps or 0)))
    setTextIfChanged029769(m.DMG, string.format("DMG  %s", formatNumber(summary.totalDamage or 0)))
    setTextIfChanged029769(m.CRIT, string.format("CRIT  %.1f%%", summary.criticalEventPercent or 0))
    setTextIfChanged029769(m.HITS, string.format("CRITS  %s/%s", formatNumber(summary.criticalHits or 0), formatNumber(summary.hits or 0)))

    setTextIfChanged029769(m.HPS, string.format("HPS  %s", formatNumber(summary.hps or 0)))
    setTextIfChanged029769(m.HEAL, string.format("HEAL  %s", formatNumber(summary.totalHealing or 0)))
    setTextIfChanged029769(m.CRIT_HEAL, string.format("CRIT HEAL  %.1f%%", summary.criticalHealPercent or 0))
    setTextIfChanged029769(m.HEALS, string.format("C-HEALS  %s/%s", formatNumber(summary.criticalHeals or 0), formatNumber(summary.healEvents or 0)))

    setTextIfChanged029769(m.DTPS, string.format("DTPS  %s", formatNumber(summary.dtps or 0)))
    setTextIfChanged029769(m.TAKEN, string.format("TAKEN  %s", formatNumber(summary.incomingDamage or 0)))
    setTextIfChanged029769(m.BLOCK, string.format("BLOCK  %.1f%%", summary.blockPercent or 0))
    setTextIfChanged029769(m.IN_HITS, string.format("BLOCKS  %s/%s", formatNumber(summary.blockedHits or 0), formatNumber(summary.incomingHits or 0)))
end

function U:Create()
    local saved = EPC.saved
    saved.width = EPC:Clamp(saved.width, MINIMUM_WIDTH, MAXIMUM_WIDTH)

    local root = wm:CreateTopLevelWindow("EPC_MainWindow")
    root:SetDimensions(saved.width, EXPANDED_HEIGHT)
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, saved.left, saved.top)
    root:SetScale(saved.scale)
    root:SetAlpha(saved.alpha)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(true)
    root:SetMovable(true)
    root:SetHidden(true) -- v0.19.4: legacy standalone menu removed; Codex is the only main UI
    root:SetHandler("OnMoveStop", function(control)
        EPC.saved.left = control:GetLeft()
        EPC.saved.top = control:GetTop()
    end)

    self.shadow = makeBackdrop(root, "EPC_Shadow", {0, 0, 0, 0.42}, {0, 0, 0, 0})
    self.shadow:SetAnchor(TOPLEFT, root, TOPLEFT, 5, 6)
    self.shadow:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, 5, 6)

    self.background = makeBackdrop(root, "EPC_Background", C.bg, C.edge)
    self.background:SetAnchorFill(root)

    self.topAccent = wm:CreateControl("EPC_TopAccent", root, CT_BACKDROP)
    self.topAccent:SetAnchor(TOPLEFT, root, TOPLEFT, 1, 1)
    self.topAccent:SetAnchor(TOPRIGHT, root, TOPRIGHT, -1, 1)
    self.topAccent:SetHeight(3)
    self.topAccent:SetCenterColor(unpack(C.gold))
    self.topAccent:SetEdgeColor(0, 0, 0, 0)

    self.header = makeBackdrop(root, "EPC_Header", {0.030, 0.036, 0.050, 0.99}, {0, 0, 0, 0})
    self.header:SetAnchor(TOPLEFT, root, TOPLEFT, 1, 4)
    self.header:SetAnchor(TOPRIGHT, root, TOPRIGHT, -1, 4)
    self.header:SetHeight(68)

    self.classBadge = makeBackdrop(self.header, "EPC_ClassBadge", {0.10, 0.075, 0.16, 1}, C.purple)
    self.classBadge:SetDimensions(44, 44)
    self.classBadge:SetAnchor(LEFT, self.header, LEFT, 12, 0)

    self.classBadgeText = makeLabel(self.classBadge, "EPC_ClassBadgeText", "ZoFontWinH2", C.white, {
        horizontalAlignment = TEXT_ALIGN_CENTER,
        verticalAlignment = TEXT_ALIGN_CENTER,
    })
    self.classBadgeText:SetAnchorFill(self.classBadge)
    self.classBadgeText:SetText("E")

    self.title = makeLabel(self.header, "EPC_Title", "ZoFontWinH2", C.white)
    self.title:SetAnchor(TOPLEFT, self.header, TOPLEFT, 68, 10)
    self.title:SetDimensions(saved.width - 220, 28)

    self.subtitle = makeLabel(self.header, "EPC_Subtitle", "ZoFontGame", C.text)
    self.subtitle:SetAnchor(TOPLEFT, self.title, BOTTOMLEFT, 0, 0)
    self.subtitle:SetDimensions(saved.width - 220, 22)

    self.modePill = makeBackdrop(self.header, "EPC_ModePill", {0.04, 0.09, 0.12, 1}, C.blue)
    self.modePill:SetDimensions(92, 26)
    self.modePill:SetAnchor(RIGHT, self.header, RIGHT, -50, -7)
    self.modePillText = makeLabel(self.modePill, "EPC_ModePillText", "ZoFontGameBold", C.blue, {
        horizontalAlignment = TEXT_ALIGN_CENTER,
        verticalAlignment = TEXT_ALIGN_CENTER,
    })
    self.modePillText:SetAnchorFill(self.modePill)
    self.modePillText:SetText("SUITE")

    self.minBtn = makeButton(self.header, "EPC_MinimizeButton", "-", 30, 30, function()
        self:ToggleMinimized()
    end)
    self.minBtn:SetAnchor(RIGHT, self.header, RIGHT, -10, 0)
    self.minBtn:SetFont("ZoFontWinH3")

    self.body = wm:CreateControl("EPC_Body", root, CT_CONTROL)
    self.body:SetAnchor(TOPLEFT, root, TOPLEFT, 16, 84)
    self.body:SetAnchor(TOPRIGHT, root, TOPRIGHT, -16, 84)
    self.body:SetHeight(760)

    local contentWidth = saved.width - 32

    self.primaryCard = makeBackdrop(self.body, "EPC_PrimaryCard", C.panel, C.edge)
    self.primaryCard:SetAnchor(TOPLEFT, self.body, TOPLEFT, 0, 0)
    self.primaryCard:SetDimensions(contentWidth, 160)

    self.primaryAccent = wm:CreateControl("EPC_PrimaryAccent", self.primaryCard, CT_BACKDROP)
    self.primaryAccent:SetAnchor(TOPLEFT, self.primaryCard, TOPLEFT, 0, 0)
    self.primaryAccent:SetAnchor(BOTTOMLEFT, self.primaryCard, BOTTOMLEFT, 0, 0)
    self.primaryAccent:SetWidth(4)
    self.primaryAccent:SetCenterColor(unpack(C.gold))
    self.primaryAccent:SetEdgeColor(0, 0, 0, 0)

    self.sectionHeader = makeLabel(self.primaryCard, "EPC_SectionHeader", "ZoFontGameBold", C.gold)
    self.sectionHeader:SetAnchor(TOPLEFT, self.primaryCard, TOPLEFT, 16, 12)
    self.sectionHeader:SetDimensions(contentWidth - 140, 22)

    self.priorityBadge = makeBackdrop(self.primaryCard, "EPC_PriorityBadge", {0.12, 0.085, 0.03, 1}, C.goldSoft)
    self.priorityBadge:SetDimensions(92, 24)
    self.priorityBadge:SetAnchor(TOPRIGHT, self.primaryCard, TOPRIGHT, -12, 10)
    self.priorityBadgeText = makeLabel(self.priorityBadge, "EPC_PriorityBadgeText", "ZoFontGameBold", C.gold, {
        horizontalAlignment = TEXT_ALIGN_CENTER,
        verticalAlignment = TEXT_ALIGN_CENTER,
    })
    self.priorityBadgeText:SetAnchorFill(self.priorityBadge)
    self.priorityBadgeText:SetText("ADVISOR")

    self.primaryTitle = makeLabel(self.primaryCard, "EPC_PrimaryTitle", "ZoFontWinH2", C.white, {
        wrapped = true,
        maxLines = 2,
        lineSpacing = 1,
    })
    self.primaryTitle:SetAnchor(TOPLEFT, self.primaryCard, TOPLEFT, 16, 39)
    self.primaryTitle:SetDimensions(contentWidth - 32, 52)
    self.primaryTitle.epcWrapWidth = contentWidth - 32

    self.description = makeLabel(self.primaryCard, "EPC_Description", "ZoFontGame", C.text, {
        wrapped = true,
        maxLines = 4,
        lineSpacing = 1,
    })
    self.description:SetAnchor(TOPLEFT, self.primaryTitle, BOTTOMLEFT, 0, 4)
    self.description:SetDimensions(contentWidth - 32, 60)
    self.description.epcWrapWidth = contentWidth - 32

    self.statsArea = wm:CreateControl("EPC_StatsArea", self.body, CT_CONTROL)
    self.statsArea:SetAnchor(TOPLEFT, self.primaryCard, BOTTOMLEFT, 0, 10)
    self.statsArea:SetDimensions(contentWidth, 126)

    self.statCards, self.statLabels, self.statValues = {}, {}, {}
    local statGap = 8
    local statWidth = math.floor((contentWidth - statGap) / 2)
    for i = 1, STAT_ROWS do
        local row = math.floor((i - 1) / 2)
        local col = (i - 1) % 2
        local card = makeBackdrop(self.statsArea, "EPC_StatCard_" .. tostring(i), C.panel2, C.edgeSoft)
        card:SetDimensions(statWidth, 58)
        card:SetAnchor(TOPLEFT, self.statsArea, TOPLEFT, col * (statWidth + statGap), row * 66)

        local label = makeLabel(card, "EPC_StatLabel_" .. tostring(i), "ZoFontGameSmall", C.muted)
        label:SetAnchor(TOPLEFT, card, TOPLEFT, 9, 7)
        label:SetDimensions(statWidth - 18, 18)

        local value = makeLabel(card, "EPC_StatValue_" .. tostring(i), "ZoFontGameBold", C.white)
        value:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, 1)
        value:SetDimensions(statWidth - 18, 25)

        self.statCards[i], self.statLabels[i], self.statValues[i] = card, label, value
    end

    -- Endgame focus selector. It appears only on BUILD for level-50 characters.
    self.focusPanel = wm:CreateControl("EPC_FocusPanel", self.body, CT_CONTROL)
    self.focusPanel:SetAnchor(TOPLEFT, self.statsArea, BOTTOMLEFT, 0, 10)
    self.focusPanel:SetDimensions(contentWidth, 120)
    self.focusPanel:SetHidden(true)

    self.focusHeader = makeLabel(self.focusPanel, "EPC_FocusHeader", "ZoFontGameBold", C.blue)
    self.focusHeader:SetAnchor(TOPLEFT, self.focusPanel, TOPLEFT, 0, 0)
    self.focusHeader:SetDimensions(contentWidth, 18)
    self.focusHeader:SetText("WHAT DO YOU WANT TO OPTIMIZE?")

    self.focusNames = {"AUTO", "DPS", "GOLD", "XP_CP", "GEAR", "DUNGEONS", "TRIALS", "SOLO", "QUESTING"}
    self.focusButtons = {}
    local focusGap = 5
    local focusWidth = math.floor((contentWidth - (focusGap * 2)) / 3)
    for i = 1, #self.focusNames do
        local focusName = self.focusNames[i]
        local label = EPC.Endgame and EPC.Endgame:GetFocusLabel(focusName) or focusName
        local button = makeButton(self.focusPanel, "EPC_Focus_" .. focusName, label, focusWidth, 27, function()
            if EPC.Endgame then EPC.Endgame:SetFocus(focusName) end
        end)
        local row = math.floor((i - 1) / 3)
        local col = (i - 1) % 3
        button:SetAnchor(TOPLEFT, self.focusPanel, TOPLEFT, col * (focusWidth + focusGap), 22 + row * 31)
        self.focusButtons[i] = button
    end

    self.listArea = wm:CreateControl("EPC_ListArea", self.body, CT_CONTROL)
    self.listArea:SetAnchor(TOPLEFT, self.statsArea, BOTTOMLEFT, 0, 12)
    self.listArea:SetDimensions(contentWidth, 248)

    self.listHeader = makeLabel(self.listArea, "EPC_ListHeader", "ZoFontGameBold", C.blue)
    self.listHeader:SetAnchor(TOPLEFT, self.listArea, TOPLEFT, 0, 0)
    self.listHeader:SetDimensions(contentWidth, 22)

    self.listRows = {}
    for i = 1, LIST_ROWS do
        local card = makeBackdrop(self.listArea, "EPC_ListCard_" .. tostring(i), C.panel2, C.edgeSoft)
        card:SetDimensions(contentWidth, 66)
        card:SetAnchor(TOPLEFT, self.listArea, TOPLEFT, 0, 28 + ((i - 1) * 72))

        local number = makeBackdrop(card, "EPC_ListNumberBox_" .. tostring(i), {0.07, 0.085, 0.11, 1}, C.blue)
        number:SetDimensions(32, 32)
        number:SetAnchor(LEFT, card, LEFT, 10, 0)
        local numberText = makeLabel(number, "EPC_ListNumber_" .. tostring(i), "ZoFontGameBold", C.blue, {
            horizontalAlignment = TEXT_ALIGN_CENTER,
            verticalAlignment = TEXT_ALIGN_CENTER,
        })
        numberText:SetAnchorFill(number)
        numberText:SetText(tostring(i))

        local text = makeLabel(card, "EPC_ListText_" .. tostring(i), "ZoFontGame", C.text, {
            wrapped = true,
            maxLines = 3,
            lineSpacing = 1,
            verticalAlignment = TEXT_ALIGN_CENTER,
        })
        text:SetAnchor(TOPLEFT, card, TOPLEFT, 52, 7)
        text:SetDimensions(contentWidth - 66, 52)
        text.epcWrapWidth = contentWidth - 66

        self.listRows[i] = { card = card, text = text }
    end

    -- Travel module
    self.travelPanel = wm:CreateControl("EPC_TravelPanel", self.body, CT_CONTROL)
    self.travelPanel:SetAnchor(TOPLEFT, self.statsArea, BOTTOMLEFT, 0, 12)
    self.travelPanel:SetDimensions(contentWidth, 366)
    self.travelPanel:SetHidden(true)

    self.travelHeader = makeLabel(self.travelPanel, "EPC_TravelHeader", "ZoFontGameBold", C.blue)
    self.travelHeader:SetAnchor(TOPLEFT, self.travelPanel, TOPLEFT, 0, 0)
    self.travelHeader:SetDimensions(contentWidth, 22)

    self.travelModeButtons = {}
    self.travelModeNames = {"SHRINES", "FRIENDS", "GUILD", "GROUP"}
    local modeGap = 5
    local modeWidth = math.floor((contentWidth - (modeGap * 3)) / 4)
    for i = 1, #self.travelModeNames do
        local modeName = self.travelModeNames[i]
        local button = makeButton(self.travelPanel, "EPC_TravelMode_" .. modeName, modeName, modeWidth, 28, function()
            if EPC.Travel then EPC.Travel:SetMode(modeName) end
        end)
        if i == 1 then button:SetAnchor(TOPLEFT, self.travelHeader, BOTTOMLEFT, 0, 4)
        else button:SetAnchor(LEFT, self.travelModeButtons[i - 1], RIGHT, modeGap, 0) end
        self.travelModeButtons[i] = button
    end

    self.travelRows = {}
    for i = 1, TRAVEL_ROWS do
        local rowIndex = i
        local card = makeBackdrop(self.travelPanel, "EPC_TravelCard_" .. tostring(i), C.panel2, C.edgeSoft)
        card:SetDimensions(contentWidth, 50)
        card:SetAnchor(TOPLEFT, self.travelPanel, TOPLEFT, 0, 58 + ((i - 1) * 55))
        card:SetMouseEnabled(false)

        local hit = wm:CreateControl("EPC_TravelHit_" .. tostring(i), card, CT_BUTTON)
        hit:SetAnchorFill(card)
        if hit.SetMouseEnabled then hit:SetMouseEnabled(true) end
        hit:SetHandler("OnClicked", function()
            if EPC.Travel then EPC.Travel:SelectVisibleRow(rowIndex) end
        end)

        local title = makeLabel(card, "EPC_TravelTitle_" .. tostring(i), "ZoFontGameBold", C.white)
        title:SetAnchor(TOPLEFT, card, TOPLEFT, 11, 6)
        title:SetDimensions(contentWidth - 22, 20)
        local detail = makeLabel(card, "EPC_TravelDetail_" .. tostring(i), "ZoFontGameSmall", C.muted)
        detail:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 1)
        detail:SetDimensions(contentWidth - 22, 18)
        self.travelRows[i] = { card = card, hit = hit, title = title, detail = detail }
    end

    self.travelFooter = wm:CreateControl("EPC_TravelFooter", self.travelPanel, CT_CONTROL)
    self.travelFooter:SetAnchor(TOPLEFT, self.travelPanel, TOPLEFT, 0, 282)
    self.travelFooter:SetDimensions(contentWidth, 32)

    self.travelPrev = makeButton(self.travelFooter, "EPC_TravelPrev", "PREV", 62, 30, function()
        if EPC.Travel then EPC.Travel:ChangePage(-1) end
    end)
    self.travelPrev:SetAnchor(LEFT, self.travelFooter, LEFT, 0, 0)
    self.travelNext = makeButton(self.travelFooter, "EPC_TravelNext", "NEXT", 62, 30, function()
        if EPC.Travel then EPC.Travel:ChangePage(1) end
    end)
    self.travelNext:SetAnchor(LEFT, self.travelPrev, RIGHT, 4, 0)

    self.travelPage = makeLabel(self.travelFooter, "EPC_TravelPage", "ZoFontGame", C.muted, {
        horizontalAlignment = TEXT_ALIGN_CENTER,
        verticalAlignment = TEXT_ALIGN_CENTER,
    })
    self.travelPage:SetAnchor(LEFT, self.travelNext, RIGHT, 6, 0)
    self.travelPage:SetDimensions(105, 30)

    self.travelAction = makeButton(self.travelFooter, "EPC_TravelAction", "TRAVEL", 128, 30, function()
        if EPC.Travel then EPC.Travel:TravelSelected() end
    end)
    self.travelAction:SetAnchor(RIGHT, self.travelFooter, RIGHT, 0, 0)
    self.travelAction:SetNormalFontColor(unpack(C.gold))

    self.travelHint = makeLabel(self.travelPanel, "EPC_TravelHint", "ZoFontGameSmall", C.muted, {
        wrapped = true,
        maxLines = 3,
        lineSpacing = 1,
    })
    self.travelHint:SetAnchor(TOPLEFT, self.travelFooter, BOTTOMLEFT, 0, 4)
    self.travelHint:SetDimensions(contentWidth, 46)
    self.travelHint.epcWrapWidth = contentWidth


    -- Quest discovery browser
    self.questPanel = wm:CreateControl("EPC_QuestPanel", self.body, CT_CONTROL)
    self.questPanel:SetAnchor(TOPLEFT, self.statsArea, BOTTOMLEFT, 0, 12)
    -- Keep enough vertical room for all eight quest rows plus the quest hint/action footer.
    -- The Quest tab also uses a taller root window (QUEST_EXPANDED_HEIGHT) so this
    -- panel ends above the global footer hint and bottom navigation tabs.
    self.questPanel:SetDimensions(contentWidth, 450)
    self.questPanel:SetHidden(true)
    self.questPanel:SetMouseEnabled(true)
    self.questPanel:SetHandler("OnMouseWheel", function(_, delta) if EPC.QuestFinder then EPC.QuestFinder:Scroll(delta > 0 and -1 or 1) end end)

    self.questFilters = {}
    local filters = {{"NOT_STARTED","NOT STARTED"},{"ACTIVE","ACTIVE"},{"ALL","ALL"}}
    local fw = math.floor((contentWidth - 10)/3)
    for i=1,#filters do
        local key,label=filters[i][1],filters[i][2]
        local b=makeButton(self.questPanel,"EPC_QuestFilter_"..key,label,fw,27,function()
            if EPC.QuestFinder and EPC.QuestFinder:SetFilter(key) then EPC.UI:RenderQuest(EPC.QuestFinder:BuildView()) end
        end)
        if b.SetFont then b:SetFont("ZoFontGame") end
        if i==1 then b:SetAnchor(TOPLEFT,self.questPanel,TOPLEFT,0,0) else b:SetAnchor(LEFT,self.questFilters[i-1],RIGHT,5,0) end
        self.questFilters[i]=b
    end

    self.questRows={}
    for i=1,QUEST_ROWS do
        local idx=i
        local card=makeBackdrop(self.questPanel,"EPC_QuestCard_"..i,C.panel2,C.edgeSoft)
        card:SetDimensions(contentWidth,43)
        card:SetAnchor(TOPLEFT,self.questPanel,TOPLEFT,0,34+((i-1)*47))
        local hit=wm:CreateControl("EPC_QuestHit_"..i,card,CT_BUTTON)
        hit:SetAnchorFill(card)
        hit:SetHandler("OnClicked",function() if EPC.QuestFinder then EPC.QuestFinder:SelectRow(idx) end end)
        local title=makeLabel(card,"EPC_QuestTitle_"..i,"ZoFontGameBold",C.white)
        -- Reserve a real gutter between the quest title and right-aligned status label.
        -- The previous widths overlapped by ~6px at the minimum window width.
        title:SetAnchor(TOPLEFT,card,TOPLEFT,8,3) title:SetDimensions(contentWidth-194,19)
        local meta=makeLabel(card,"EPC_QuestMeta_"..i,"ZoFontGameSmall",C.muted,{horizontalAlignment=TEXT_ALIGN_RIGHT})
        meta:SetAnchor(TOPRIGHT,card,TOPRIGHT,-8,3) meta:SetDimensions(160,19)
        local detail=makeLabel(card,"EPC_QuestDetail_"..i,"ZoFontGameSmall",C.muted)
        detail:SetAnchor(BOTTOMLEFT,card,BOTTOMLEFT,8,-3) detail:SetDimensions(contentWidth-16,17)
        self.questRows[i]={card=card,title=title,meta=meta,detail=detail}
    end
    self.questRoute=makeButton(self.questPanel,"EPC_QuestRoute","ROUTE TO STARTER",190,30,function() if EPC.QuestFinder then EPC.QuestFinder:RouteSelected() end end)
    self.questRoute:SetAnchor(BOTTOMRIGHT,self.questPanel,BOTTOMRIGHT,0,-34)
    self.questTravelNearest=makeButton(self.questPanel,"EPC_QuestTravelNearest","TRAVEL TO NEAREST WAYSHRINE",190,30,function() if EPC.QuestFinder and EPC.QuestFinder.TravelNearestWayshrineSelected then EPC.QuestFinder:TravelNearestWayshrineSelected() end end)
    self.questTravelNearest:SetAnchor(BOTTOMRIGHT,self.questPanel,BOTTOMRIGHT,0,0)
    self.questHint=makeLabel(self.questPanel,"EPC_QuestHint","ZoFontGameSmall",C.muted,{wrapped=true,maxLines=2})
    self.questHint:SetAnchor(BOTTOMLEFT,self.questPanel,BOTTOMLEFT,0,0) self.questHint:SetDimensions(contentWidth-185,34)

    -- Equipment set journal (GEAR tab)
    self.gearPanel = wm:CreateControl("EPC_GearJournalPanel", self.body, CT_CONTROL)
    self.gearPanel:SetAnchor(TOPLEFT, self.statsArea, BOTTOMLEFT, 0, 12)
    self.gearPanel:SetDimensions(contentWidth, 420)
    self.gearPanel:SetHidden(true)
    self.gearPanel:SetMouseEnabled(true)

    self.gearFilters = {}
    local gearKeys = {"ALL", "OVERLAND", "DUNGEON", "TRIAL"}
    local gearGap = 5
    local gearButtonWidth = math.floor((contentWidth - (gearGap * 5)) / 6)
    for i = 1, #gearKeys do
        local key = gearKeys[i]
        local b = makeButton(self.gearPanel, "EPC_GearFilter_" .. key, key, gearButtonWidth, 28, function()
            if EPC.SetJournal then EPC.SetJournal:SetFilter(key) end
        end)
        if i == 1 then b:SetAnchor(TOPLEFT, self.gearPanel, TOPLEFT, 0, 0)
        else b:SetAnchor(LEFT, self.gearFilters[i - 1], RIGHT, gearGap, 0) end
        self.gearFilters[i] = b
    end
    self.gearSearch = makeButton(self.gearPanel, "EPC_GearSearch", "SEARCH", gearButtonWidth, 28, function()
        if EPC.SetJournal then EPC.SetJournal:PromptSearch() end
    end)
    self.gearSearch:SetAnchor(LEFT, self.gearFilters[#self.gearFilters], RIGHT, gearGap, 0)
    self.gearClear = makeButton(self.gearPanel, "EPC_GearClear", "CLEAR", gearButtonWidth, 28, function()
        if EPC.SetJournal then EPC.SetJournal:ClearSearch() end
    end)
    self.gearClear:SetAnchor(LEFT, self.gearSearch, RIGHT, gearGap, 0)

    self.gearRows = {}
    for i = 1, SET_ROWS do
        local idx = i
        local card = makeBackdrop(self.gearPanel, "EPC_GearJournalCard_" .. i, C.panel2, C.edgeSoft)
        card:SetDimensions(contentWidth, 43)
        card:SetAnchor(TOPLEFT, self.gearPanel, TOPLEFT, 0, 35 + ((i - 1) * 46))
        local hit = wm:CreateControl("EPC_GearJournalHit_" .. i, card, CT_BUTTON)
        hit:SetAnchorFill(card)
        hit:SetHandler("OnClicked", function() if EPC.SetJournal then EPC.SetJournal:SelectRow(idx) end end)
        local title = makeLabel(card, "EPC_GearJournalTitle_" .. i, "ZoFontGameBold", C.white)
        title:SetAnchor(TOPLEFT, card, TOPLEFT, 8, 4)
        title:SetDimensions(contentWidth - 190, 19)
        local progress = makeLabel(card, "EPC_GearJournalProgress_" .. i, "ZoFontGameSmall", C.muted, {horizontalAlignment=TEXT_ALIGN_RIGHT})
        progress:SetAnchor(TOPRIGHT, card, TOPRIGHT, -8, 4)
        progress:SetDimensions(165, 19)
        local detail = makeLabel(card, "EPC_GearJournalDetail_" .. i, "ZoFontGameSmall", C.muted)
        detail:SetAnchor(BOTTOMLEFT, card, BOTTOMLEFT, 8, -4)
        detail:SetDimensions(contentWidth - 16, 18)
        self.gearRows[i] = {card=card, title=title, progress=progress, detail=detail}
    end

    self.gearPrev = makeButton(self.gearPanel, "EPC_GearJournalPrev", "< PREV", 72, 28, function()
        if EPC.SetJournal then EPC.SetJournal:ChangePage(-1) end
    end)
    self.gearPrev:SetAnchor(BOTTOMLEFT, self.gearPanel, BOTTOMLEFT, 0, 0)
    self.gearPage = makeLabel(self.gearPanel, "EPC_GearJournalPage", "ZoFontGameSmall", C.muted, {horizontalAlignment=TEXT_ALIGN_CENTER, verticalAlignment=TEXT_ALIGN_CENTER})
    self.gearPage:SetAnchor(LEFT, self.gearPrev, RIGHT, 4, 0)
    self.gearPage:SetDimensions(92, 28)
    self.gearNext = makeButton(self.gearPanel, "EPC_GearJournalNext", "NEXT >", 72, 28, function()
        if EPC.SetJournal then EPC.SetJournal:ChangePage(1) end
    end)
    self.gearNext:SetAnchor(LEFT, self.gearPage, RIGHT, 4, 0)

    self.gearEquipBest = makeButton(self.gearPanel, "EPC_GearEquipBest", "EQUIP BEST", 138, 30, function()
        if EPC.GearOptimizer then EPC.GearOptimizer:EquipBestRecommended() end
    end)
    -- Put the recommendation action on its own visible row. The previous build
    -- placed it between the left pagination controls and the right travel buttons,
    -- where it could be covered at normal Codex widths.
    self.gearEquipBest:SetAnchor(TOPLEFT, self.gearPanel, TOPLEFT, 0, 316)
    self.gearEquipBest:SetNormalFontColor(unpack(C.gold))
    self.gearEquipBest:SetDrawLayer(DL_OVERLAY)
    self.gearEquipBest:SetDrawLevel(120)

    self.gearSourceQuests = makeButton(self.gearPanel, "EPC_GearJournalQuests", "ZONE QUESTS", 125, 30, function()
        if EPC.SetJournal then EPC.SetJournal:OpenSourceQuests() end
    end)
    self.gearSourceQuests:SetAnchor(BOTTOMRIGHT, self.gearPanel, BOTTOMRIGHT, 0, 0)
    self.gearRoute = makeButton(self.gearPanel, "EPC_GearJournalRoute", "ROUTE SOURCE", 130, 30, function()
        if EPC.SetJournal then EPC.SetJournal:RouteSelected() end
    end)
    self.gearRoute:SetAnchor(RIGHT, self.gearSourceQuests, LEFT, -5, 0)
    self.gearFastTravel = makeButton(self.gearPanel, "EPC_GearJournalFastTravel", "FAST TRAVEL", 120, 30, function()
        if EPC.SetJournal then EPC.SetJournal:FastTravelSelected() end
    end)
    self.gearFastTravel:SetAnchor(RIGHT, self.gearRoute, LEFT, -5, 0)
    self.gearHint = makeLabel(self.gearPanel, "EPC_GearJournalHint", "ZoFontGameSmall", C.muted, {wrapped=true, maxLines=2})
    self.gearHint:SetAnchor(LEFT, self.gearEquipBest, RIGHT, 10, 0)
    self.gearHint:SetDimensions(math.max(120, contentWidth - 148), 30)

    -- Activity planner module
    self.activityPanel = wm:CreateControl("EPC_ActivityPanel", self.body, CT_CONTROL)
    self.activityPanel:SetAnchor(TOPLEFT, self.statsArea, BOTTOMLEFT, 0, 12)
    self.activityPanel:SetDimensions(contentWidth, 410)
    self.activityPanel:SetHidden(true)

    self.activityHeader = makeLabel(self.activityPanel, "EPC_ActivityHeader", "ZoFontGameBold", C.blue)
    self.activityHeader:SetAnchor(TOPLEFT, self.activityPanel, TOPLEFT, 0, 0)
    self.activityHeader:SetDimensions(contentWidth, 22)
    self.activityHeader:SetText("PLANNER GOAL")

    self.activityGoalNames = {"XP", "GOLD", "BALANCED"}
    self.activityGoalButtons = {}
    local goalWidth = math.floor((contentWidth - 10) / 3)
    for i = 1, #self.activityGoalNames do
        local goal = self.activityGoalNames[i]
        local button = makeButton(self.activityPanel, "EPC_ActivityGoal_" .. goal, goal, goalWidth, 28, function()
            if EPC.Activities then EPC.Activities:SetGoal(goal) end
        end)
        if i == 1 then button:SetAnchor(TOPLEFT, self.activityHeader, BOTTOMLEFT, 0, 4)
        else button:SetAnchor(LEFT, self.activityGoalButtons[i - 1], RIGHT, 5, 0) end
        self.activityGoalButtons[i] = button
    end

    self.sessionHeader = makeLabel(self.activityPanel, "EPC_SessionHeader", "ZoFontGameSmall", C.muted)
    self.sessionHeader:SetAnchor(TOPLEFT, self.activityPanel, TOPLEFT, 0, 58)
    self.sessionHeader:SetDimensions(contentWidth, 18)
    self.sessionHeader:SetText("SESSION PLAN")
    self.sessionButtons = {}
    self.sessionNames = {"CONTINUOUS", 30, 60, 120, "CUSTOM"}
    local sessionWidth = math.floor((contentWidth - 20) / 5)
    for i = 1, #self.sessionNames do
        local option = self.sessionNames[i]
        local label = option == "CONTINUOUS" and "CONT" or (option == "CUSTOM" and "CUSTOM" or (tostring(option) .. " MIN"))
        local button = makeButton(self.activityPanel, "EPC_Session_" .. tostring(option), label, sessionWidth, 25, function()
            if not EPC.Advisor then return end
            if option == "CONTINUOUS" then EPC.Advisor:SetSessionMode("CONTINUOUS")
            elseif option == "CUSTOM" then EPC.Advisor:SetSessionMode("CUSTOM")
            else EPC.Advisor:SetSessionMinutes(option) end
        end)
        if i == 1 then button:SetAnchor(TOPLEFT, self.sessionHeader, BOTTOMLEFT, 0, 2)
        else button:SetAnchor(LEFT, self.sessionButtons[i - 1], RIGHT, 5, 0) end
        self.sessionButtons[i] = button
    end

    self.activityRows = {}
    for i = 1, ACTIVITY_ROWS do
        local rowIndex = i
        local card = makeBackdrop(self.activityPanel, "EPC_ActivityCard_" .. tostring(i), C.panel2, C.edgeSoft)
        card:SetDimensions(contentWidth, 57)
        card:SetAnchor(TOPLEFT, self.activityPanel, TOPLEFT, 0, 108 + ((i - 1) * 62))
        card:SetMouseEnabled(false)

        local hit = wm:CreateControl("EPC_ActivityHit_" .. tostring(i), card, CT_BUTTON)
        hit:SetAnchorFill(card)
        if hit.SetMouseEnabled then hit:SetMouseEnabled(true) end
        hit:SetHandler("OnClicked", function()
            if EPC.Activities then EPC.Activities:SelectVisibleRow(rowIndex) end
        end)

        local rank = makeLabel(card, "EPC_ActivityRank_" .. tostring(i), "ZoFontWinH3", C.gold, {
            horizontalAlignment = TEXT_ALIGN_CENTER,
            verticalAlignment = TEXT_ALIGN_CENTER,
        })
        rank:SetAnchor(LEFT, card, LEFT, 8, 0)
        rank:SetDimensions(30, 50)
        rank:SetText(tostring(i))

        local title = makeLabel(card, "EPC_ActivityTitle_" .. tostring(i), "ZoFontGameBold", C.white)
        title:SetAnchor(TOPLEFT, card, TOPLEFT, 47, 7)
        title:SetDimensions(contentWidth - 58, 20)
        local detail = makeLabel(card, "EPC_ActivityDetail_" .. tostring(i), "ZoFontGameSmall", C.muted)
        detail:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 1)
        detail:SetDimensions(contentWidth - 58, 18)
        self.activityRows[i] = { card = card, hit = hit, rank = rank, title = title, detail = detail }
    end

    self.activityFooter = wm:CreateControl("EPC_ActivityFooter", self.activityPanel, CT_CONTROL)
    self.activityFooter:SetAnchor(TOPLEFT, self.activityPanel, TOPLEFT, 0, 361)
    self.activityFooter:SetDimensions(contentWidth, 32)
    self.activityHint = makeLabel(self.activityFooter, "EPC_ActivityHint", "ZoFontGameSmall", C.muted, {
        wrapped = true,
        maxLines = 2,
        lineSpacing = 1,
    })
    self.activityHint:SetAnchor(LEFT, self.activityFooter, LEFT, 0, 0)
    self.activityHint:SetDimensions(contentWidth, 32)
    self.activityHint.epcWrapWidth = contentWidth

    -- Adaptive utility command center. This consolidates the high-value non-combat
    -- workflows without turning the coach into a permanent wall of panels.
    self.toolsPanel = wm:CreateControl("EPC_ToolsPanel", self.body, CT_CONTROL)
    self.toolsPanel:SetAnchor(TOPLEFT, self.statsArea, BOTTOMLEFT, 0, 12)
    self.toolsPanel:SetDimensions(contentWidth, 420)
    self.toolsPanel:SetHidden(true)

    self.toolsHeader = makeLabel(self.toolsPanel, "EPC_ToolsHeader", "ZoFontGameBold", C.blue)
    self.toolsHeader:SetAnchor(TOPLEFT, self.toolsPanel, TOPLEFT, 0, 0)
    self.toolsHeader:SetDimensions(contentWidth, 22)
    self.toolsHeader:SetText("UTILITY COMMAND CENTER")

    self.toolsModeNames = {"OVERVIEW", "INVENTORY", "RESEARCH", "COLLECTIONS", "DAILIES"}
    self.toolsModeButtons = {}
    local toolsGap = 5
    local toolsWidth = math.floor((contentWidth - (toolsGap * 4)) / 5)
    for i = 1, #self.toolsModeNames do
        local modeName = self.toolsModeNames[i]
        local button = makeButton(self.toolsPanel, "EPC_ToolsMode_" .. modeName, modeName, toolsWidth, 28, function()
            if EPC.UtilitySuite then EPC.UtilitySuite:SetMode(modeName) end
        end)
        if i == 1 then button:SetAnchor(TOPLEFT, self.toolsHeader, BOTTOMLEFT, 0, 4)
        else button:SetAnchor(LEFT, self.toolsModeButtons[i - 1], RIGHT, toolsGap, 0) end
        self.toolsModeButtons[i] = button
    end

    self.toolsRows = {}
    for i = 1, TOOLS_ROWS do
        local card = makeBackdrop(self.toolsPanel, "EPC_ToolsCard_" .. tostring(i), C.panel2, C.edgeSoft)
        card:SetDimensions(contentWidth, 54)
        card:SetAnchor(TOPLEFT, self.toolsPanel, TOPLEFT, 0, 62 + ((i - 1) * 59))

        local marker = makeBackdrop(card, "EPC_ToolsMarkerBox_" .. tostring(i), {0.055, 0.085, 0.11, 1}, C.blue)
        marker:SetDimensions(30, 30)
        marker:SetAnchor(LEFT, card, LEFT, 10, 0)
        local markerText = makeLabel(marker, "EPC_ToolsMarker_" .. tostring(i), "ZoFontGameBold", C.blue, {
            horizontalAlignment = TEXT_ALIGN_CENTER,
            verticalAlignment = TEXT_ALIGN_CENTER,
        })
        markerText:SetAnchorFill(marker)
        markerText:SetText(tostring(i))

        local text = makeLabel(card, "EPC_ToolsText_" .. tostring(i), "ZoFontGame", C.text, {
            wrapped = true,
            maxLines = 2,
            lineSpacing = 1,
            verticalAlignment = TEXT_ALIGN_CENTER,
        })
        text:SetAnchor(TOPLEFT, card, TOPLEFT, 50, 6)
        text:SetDimensions(contentWidth - 62, 42)
        text.epcWrapWidth = contentWidth - 62
        self.toolsRows[i] = { card=card, marker=marker, markerText=markerText, text=text }
    end

    self.toolsHint = makeLabel(self.toolsPanel, "EPC_ToolsHint", "ZoFontGameSmall", C.muted, {
        wrapped = true,
        maxLines = 3,
        lineSpacing = 1,
    })
    self.toolsHint:SetAnchor(TOPLEFT, self.toolsPanel, TOPLEFT, 0, 365)
    self.toolsHint:SetDimensions(contentWidth, 48)
    self.toolsHint.epcWrapWidth = contentWidth

    self.footerHint = makeLabel(root, "EPC_FooterHint", "ZoFontGameSmall", C.muted, {
        horizontalAlignment = TEXT_ALIGN_CENTER,
    })
    self.footerHint:SetAnchor(BOTTOMLEFT, root, BOTTOMLEFT, 12, -48)
    self.footerHint:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, -12, -48)
    self.footerHint:SetHeight(18)

    self.tabs = wm:CreateControl("EPC_Tabs", root, CT_CONTROL)
    self.tabs:SetAnchor(BOTTOMLEFT, root, BOTTOMLEFT, 10, -9)
    self.tabs:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, -10, -9)
    self.tabs:SetHeight(34)

    local names = {"BUILD", "GEAR", "SKILLS", "COMBAT", "ACTIVITY", "QUESTS", "MAP", "TOOLS"}
    local availableTabWidth = saved.width - 20 - (TAB_GAP * (#names - 1))
    local tabWidth = math.floor(availableTabWidth / #names)
    self.tabNames, self.validTabs, self.tabButtons, self.tabUnderlines = names, {}, {}, {}

    for i = 1, #names do
        local tabName = names[i]
        local button = makeButton(self.tabs, "EPC_Tab_" .. tabName, tabName, tabWidth, 30, function()
            EPC.saved.activeTab = tabName
            EPC:RefreshNow("tab")
        end)
        if i == 1 then button:SetAnchor(LEFT, self.tabs, LEFT, 0, 0)
        else button:SetAnchor(LEFT, self.tabButtons[i - 1], RIGHT, TAB_GAP, 0) end

        local underline = wm:CreateControl("EPC_TabLine_" .. tabName, button, CT_BACKDROP)
        underline:SetAnchor(BOTTOMLEFT, button, BOTTOMLEFT, 4, 0)
        underline:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, -4, 0)
        underline:SetHeight(2)
        underline:SetCenterColor(unpack(C.gold))
        underline:SetEdgeColor(0, 0, 0, 0)
        underline:SetHidden(true)

        self.validTabs[tabName] = true
        self.tabButtons[i] = button
        self.tabUnderlines[i] = underline
    end

    self.root = root
    self:CreateCombatHUD()
    self.expandedHeight = EXPANDED_HEIGHT
    self:ApplyInteractionState()
    self:ApplyInteractionMode(false)
    self:ApplyMinimizedState()
end

function U:ApplyInteractionState()
    if self.root then self.root:SetMovable(not EPC.saved.locked) end
end

function U:ApplyInteractionMode(active)
    active = active == true or EPC.interactionMode == true
    if not self.background or not self.modePill then return end
    if active then
        self.background:SetEdgeColor(unpack(C.gold))
        self.modePill:SetCenterColor(0.14, 0.095, 0.025, 1)
        self.modePill:SetEdgeColor(unpack(C.gold))
        self.modePillText:SetColor(unpack(C.gold))
        self.modePillText:SetText("INTERACT")
        self.footerHint:SetText("INTERACT MODE - click the Suite now; press Esc to return to camera control")
    else
        self.background:SetEdgeColor(unpack(C.edge))
        self.modePill:SetCenterColor(0.04, 0.09, 0.12, 1)
        self.modePill:SetEdgeColor(unpack(C.blue))
        self.modePillText:SetColor(unpack(C.blue))
        self.modePillText:SetText("SUITE")
        self.footerHint:SetText("Suite controls are available from the Codex and HUD layout tools")
    end
end

function U:SetVisible(visible)
    -- The old tabbed menu is retired. Keep its root permanently hidden while
    -- retaining this module for the combat HUD and shared rendering helpers.
    if self.root then self.root:SetHidden(true) end
    if EPC.Combat and self.UpdateCombatHUD then
        self:UpdateCombatHUD(EPC.Combat:GetHUDSummary())
    end
end

function U:ResetPosition()
    EPC.saved.left = EPC.defaults.left
    EPC.saved.top = EPC.defaults.top
    self.root:ClearAnchors()
    self.root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, EPC.saved.left, EPC.saved.top)
    EPC:Print("Position reset.")
end

function U:ToggleMinimized()
    EPC.saved.minimized = not EPC.saved.minimized
    self:ApplyMinimizedState()
end

function U:ApplyMinimizedState()
    if not self.root then return end
    if EPC.saved.minimized then
        self.root:SetHeight(MINIMIZED_HEIGHT)
        self.body:SetHidden(true)
        self.tabs:SetHidden(true)
        self.footerHint:SetHidden(true)
        self.minBtn:SetText("+")
    else
        self.root:SetHeight(self.expandedHeight or EXPANDED_HEIGHT)
        self.body:SetHidden(false)
        self.tabs:SetHidden(false)
        self.footerHint:SetHidden(false)
        self.minBtn:SetText("-")
    end
end

function U:ApplyRoleTheme(role)
    role = string.upper(tostring(role or "DAMAGE"))
    local accent = C.purple
    local secondary = C.gold
    local badgeCenter = {0.10, 0.075, 0.16, 1}
    if role == "HEALER" then
        accent = C.green
        secondary = C.blue
        badgeCenter = {0.035, 0.105, 0.075, 1}
    elseif role == "TANK" then
        accent = C.blue
        secondary = C.orange
        badgeCenter = {0.035, 0.075, 0.12, 1}
    end
    if self.topAccent then self.topAccent:SetCenterColor(unpack(accent)) end
    if self.primaryAccent then self.primaryAccent:SetCenterColor(unpack(secondary)) end
    if self.classBadge then
        self.classBadge:SetCenterColor(unpack(badgeCenter))
        self.classBadge:SetEdgeColor(unpack(accent))
    end
end

function U:RenderTools(tools)
    tools = tools or { mode="OVERVIEW", modeLabel="OVERVIEW", rows={}, hint="Utility data unavailable." }
    self.toolsHeader:SetText("UTILITY COMMAND CENTER  /  " .. string.upper(tools.modeLabel or tools.mode or "OVERVIEW"))
    for i = 1, #self.toolsModeButtons do
        local active = self.toolsModeNames[i] == tools.mode
        self.toolsModeButtons[i]:SetNormalFontColor(unpack(active and C.gold or C.text))
    end
    local rows = tools.rows or tools.items or {}
    for i = 1, TOOLS_ROWS do
        local row = self.toolsRows[i]
        local text = rows[i]
        if text and text ~= "" then
            row.card:SetHidden(false)
            setWrappedText(row.text, text)
            if i == 1 then setCardStyle(row.card, "featured") else setCardStyle(row.card, "normal") end
        else
            row.card:SetHidden(true)
        end
    end
    setWrappedText(self.toolsHint, tools.hint or "The command center is advisory and does not automate inventory, crafting, rewards, or travel.")
end

function U:RenderTravel(travel)
    travel = travel or {
        mode = "SHRINES", modeLabel = "Wayshrines", rows = {}, page = 1, pageCount = 1,
        actionEnabled = false, emptyText = "Travel data is unavailable.", hint = "Reload the UI and try again.",
    }
    self.travelHeader:SetText("TRAVEL DESTINATIONS  /  " .. string.upper(travel.modeLabel or "Wayshrines"))

    for i = 1, #self.travelModeButtons do
        local active = self.travelModeNames[i] == travel.mode
        self.travelModeButtons[i]:SetNormalFontColor(unpack(active and C.gold or C.text))
    end

    local selectedKey = travel.selected and travel.selected.key or nil
    for i = 1, TRAVEL_ROWS do
        local row = self.travelRows[i]
        local entry = travel.rows and travel.rows[i] or nil
        if entry then
            row.card:SetHidden(false)
            row.title:SetText(fitSingleLine(row.title, entry.name or "Destination", (EPC.saved.width or 620) - 58))
            local detail = string.format("%s  |  %s  |  %s", entry.zoneName or "Unknown zone", entry.costText or "", entry.statusText or "")
            if entry.isQuestBest then detail = "QUEST BEST  |  " .. detail end
            row.detail:SetText(fitSingleLine(row.detail, detail, (EPC.saved.width or 620) - 58))
            if entry.key == selectedKey then setCardStyle(row.card, "selected")
            elseif entry.isQuestBest then setCardStyle(row.card, "featured")
            elseif entry.canTravel then setCardStyle(row.card, "normal")
            else setCardStyle(row.card, "disabled") end
            row.title:SetColor(unpack(entry.canTravel and C.white or C.muted))
        else
            row.card:SetHidden(true)
        end
    end

    self.travelPage:SetText(string.format("Page %d / %d", travel.page or 1, travel.pageCount or 1))
    setButtonEnabled(self.travelPrev, travel.canPageBack == true)
    setButtonEnabled(self.travelNext, travel.canPageForward == true)
    setButtonEnabled(self.travelAction, travel.actionEnabled == true)
    if travel.actionEnabled then self.travelAction:SetNormalFontColor(unpack(C.gold)) end
    self.travelAction:SetText(travel.actionText or "TRAVEL")

    local hint = travel.hint or "Select a destination, then press TRAVEL."
    if not travel.rows or #travel.rows == 0 then hint = travel.emptyText or hint end
    if travel.explorationHint and travel.explorationHint ~= "" then hint = hint .. "  " .. travel.explorationHint end
    setWrappedText(self.travelHint, hint)
end

function U:RefreshSessionControls()
    if not self.sessionButtons or not EPC.Advisor then return end
    if self.sessionHeader then
        self.sessionHeader:SetText("SESSION PLAN  /  " .. EPC.Advisor:GetSessionStatusLabel())
    end
    local mode = EPC.Advisor:GetSessionMode()
    local activeMinutes = EPC.Advisor:GetSessionMinutes()
    local customMinutes = EPC.Advisor:GetCustomSessionMinutes()
    for i, option in ipairs(self.sessionNames or {}) do
        local active = false
        if option == "CONTINUOUS" then active = mode == "CONTINUOUS"
        elseif option == "CUSTOM" then active = mode == "CUSTOM"
        else active = mode == "TIMED" and activeMinutes == option end
        if self.sessionButtons[i] then
            self.sessionButtons[i]:SetNormalFontColor(unpack(active and C.gold or C.text))
            if option == "CUSTOM" then self.sessionButtons[i]:SetText("CUSTOM " .. tostring(customMinutes)) end
        end
    end
end

function U:RenderActivity(activity)
    activity = activity or { goal = "BALANCED", rows = {}, actionEnabled = false, hint = "Planner data unavailable." }
    for i = 1, #self.activityGoalButtons do
        local active = self.activityGoalNames[i] == activity.goal
        self.activityGoalButtons[i]:SetNormalFontColor(unpack(active and C.gold or C.text))
    end

    local selectedKey = activity.selected and activity.selected.key or nil
    for i = 1, ACTIVITY_ROWS do
        local row = self.activityRows[i]
        local entry = activity.rows and activity.rows[i] or nil
        if entry then
            row.card:SetHidden(false)
            row.title:SetText(fitSingleLine(row.title, entry.name or "Activity", (EPC.saved.width or 620) - 95))
            row.detail:SetText(fitSingleLine(row.detail, entry.detailText or entry.location or "", (EPC.saved.width or 620) - 95))
            if entry.key == selectedKey then setCardStyle(row.card, "selected")
            elseif i == 1 then setCardStyle(row.card, "featured")
            else setCardStyle(row.card, "normal") end
        else
            row.card:SetHidden(true)
        end
    end

    self:RefreshSessionControls()
    local hint = activity.hint or "Select an activity to view details."
    if not activity.selected and EPC.Advisor and EPC.lastSnapshot then
        local plan = EPC.Advisor:BuildSessionPlan(EPC.lastSnapshot)
        if #plan > 0 then
            if EPC.Advisor:IsContinuous() then
                hint = "Continuous plan: " .. table.concat(plan, "  >  ")
            else
                local remaining = EPC.Advisor:GetSessionRemainingMinutes() or EPC.Advisor:GetSessionMinutes()
                hint = tostring(remaining) .. "m remaining: " .. table.concat(plan, "  >  ")
            end
        end
    end
    setWrappedText(self.activityHint, hint)
end


function U:RenderSetJournal(j)
    j = j or {rows={}, filter="ALL", total=0, page=1, pageCount=1}
    local keys = {"ALL", "OVERLAND", "DUNGEON", "TRIAL"}
    if self.gearFilters then
        for i = 1, #self.gearFilters do
            self.gearFilters[i]:SetNormalFontColor(unpack(keys[i] == j.filter and C.gold or C.text))
        end
    end
    if self.gearSearch then
        self.gearSearch:SetNormalFontColor(unpack((j.searchText and j.searchText ~= "") and C.gold or C.text))
    end
    for i = 1, SET_ROWS do
        local row = self.gearRows[i]
        local e = j.rows and j.rows[i]
        if e then
            row.card:SetHidden(false)
            local selected = j.selected and j.selected.setId == e.setId
            setCardStyle(row.card, selected and "selected" or "default")
            row.title:SetColor(unpack(selected and C.gold or C.white))
            row.title:SetText(fitSingleLine(row.title, e.name or "Item Set", math.max(140, (EPC.saved.width or MINIMUM_WIDTH) - 225)))
            row.progress:SetText(string.format("COLLECTED %d/%d", e.unlocked or 0, e.total or 0))
            row.progress:SetColor(unpack(selected and C.gold or C.muted))
            local detail = (e.sourceText or "Unknown source") .. "  |  " .. (e.kindText or "Set pieces")
            row.detail:SetText(fitSingleLine(row.detail, detail, (EPC.saved.width or MINIMUM_WIDTH) - 70))
            row.detail:SetColor(unpack(selected and C.text or C.muted))
        else
            setCardStyle(row.card, "default")
            row.card:SetHidden(true)
        end
    end
    if self.gearPage then self.gearPage:SetText(string.format("PAGE %d/%d", j.page or 1, j.pageCount or 1)) end
    setButtonEnabled(self.gearPrev, (j.page or 1) > 1)
    setButtonEnabled(self.gearNext, (j.page or 1) < (j.pageCount or 1))
    local selected = j.selected
    if selected then
        self.gearHint:SetText("Source: " .. tostring(selected.sourceText or "Unknown"))
        setButtonEnabled(self.gearFastTravel, true)
        setButtonEnabled(self.gearRoute, true)
        setButtonEnabled(self.gearSourceQuests, true)
    else
        local search = (j.searchText and j.searchText ~= "") and (" | search: " .. j.searchText) or ""
        self.gearHint:SetText(string.format("%d sets%s | SEARCH opens /esosuite set <name>", j.total or 0, search))
        setButtonEnabled(self.gearFastTravel, false)
        setButtonEnabled(self.gearRoute, false)
        setButtonEnabled(self.gearSourceQuests, false)
    end
end

function U:RenderQuest(q)
    q=q or {rows={},filter="NOT_STARTED",total=0,offset=0}
    if self.questFilters then
        local keys={"NOT_STARTED","ACTIVE","ALL"}
        for i=1,#self.questFilters do self.questFilters[i]:SetNormalFontColor(unpack(keys[i]==q.filter and C.gold or C.text)) end
    end
    for i=1,QUEST_ROWS do
        local row=self.questRows[i]
        local e=q.rows and q.rows[i]
        if e then
            row.card:SetHidden(false)
            local isSelected = q.selected and q.selected.key == e.key
            setCardStyle(row.card, isSelected and "selected" or "default")
            row.title:SetColor(unpack(isSelected and C.gold or C.white))
            row.detail:SetColor(unpack(isSelected and C.text or C.muted))
            row.title:SetText(fitSingleLine(row.title,e.name or "Quest",math.max(120,(EPC.saved.width or MINIMUM_WIDTH)-226)))
            row.meta:SetText(e.dlc and "DLC / CHAPTER" or (e.status or ""))
            row.meta:SetColor(unpack(e.dlc and C.orange or (isSelected and C.gold or C.muted)))
            local detail=(e.zone or "Unknown zone").."  |  "..(e.type or "Quest")
            if e.requires then detail=detail.."  |  Requires: "..e.requires end
            row.detail:SetText(fitSingleLine(row.detail,detail,(EPC.saved.width or MINIMUM_WIDTH)-70))
        else
            setCardStyle(row.card, "default")
            row.card:SetHidden(true)
        end
    end
    local sel=q.selected
    if sel then
        local access=sel.access or "Unknown access"
        self.questHint:SetText((sel.starter or "Starter location unknown").."  |  "..access)
        setButtonEnabled(self.questRoute,true)
        if self.questTravelNearest then setButtonEnabled(self.questTravelNearest,true) end
    else
        self.questHint:SetText(string.format("%d matches | %s | mouse-wheel | /esosuite quest <name/zone>", q.total or 0, q.scanProgress or "INDEX"))
        setButtonEnabled(self.questRoute,false)
        if self.questTravelNearest then setButtonEnabled(self.questTravelNearest,false) end
    end
end

function U:Render(model)
    if not self.root or not model then return end
    local snapshot = model.snapshot
    local activeTab = EPC.saved.activeTab
    if not self.validTabs[activeTab] then activeTab = "BUILD" EPC.saved.activeTab = activeTab end

    local views = model.tabs or {}
    local view = views[activeTab] or views.BUILD or {
        header = activeTab, title = "Suite data unavailable", description = "Reload the UI and report the first ESO UI error if this persists.", stats = {}, items = {},
    }
    local travel = activeTab == "MAP" and model.travel or nil
    local activity = activeTab == "ACTIVITY" and model.activity or nil
    local tools = activeTab == "TOOLS" and model.tools or nil
    local questFinder = activeTab == "QUESTS" and model.questFinder or nil
    local setJournal = activeTab == "GEAR" and model.setJournal or nil
    if travel then view = travel elseif activity then view = activity elseif questFinder then view = questFinder elseif setJournal then view = setJournal elseif tools then view = tools end

    self.root:SetAlpha(EPC.saved.alpha)
    self.root:SetScale(EPC.saved.scale)
    self:ApplyRoleTheme(snapshot.combatRole or (EPC.Role and EPC.Role:GetRole()) or "DAMAGE")

    local characterName = snapshot.characterName and snapshot.characterName ~= "" and snapshot.characterName or "Player"
    self.title:SetText(fitSingleLine(self.title, characterName, (EPC.saved.width or 620) - 220))
    self.classBadgeText:SetText(string.upper(string.sub(snapshot.className or "A", 1, 1)))
    if snapshot.level >= 50 then
        self.subtitle:SetText(string.format("%s  /  %s  /  CP %d  /  %s", snapshot.raceName, snapshot.className, snapshot.championPoints, snapshot.roleLabel))
    else
        self.subtitle:SetText(string.format("%s  /  %s  /  Level %d  /  %s", snapshot.raceName, snapshot.className, snapshot.level, snapshot.roleLabel))
    end

    self.sectionHeader:SetText(view.header or activeTab)
    setWrappedText(self.primaryTitle, view.title or "")
    local description = view.description or ""
    if activeTab ~= "MAP" and activeTab ~= "ACTIVITY" and activeTab ~= "QUESTS" and activeTab ~= "GEAR" and activeTab ~= "TOOLS" and EPC.saved.showReasons == false then
        description = "Recommendation explanations are hidden in add-on settings."
    end
    setWrappedText(self.description, description)

    if activeTab == "MAP" then self.priorityBadgeText:SetText("TRAVEL")
    elseif activeTab == "ACTIVITY" then self.priorityBadgeText:SetText((activity and activity.goalLabel) or "PLAN")
    elseif activeTab == "QUESTS" then self.priorityBadgeText:SetText("FIND")
    elseif activeTab == "GEAR" then self.priorityBadgeText:SetText("JOURNAL")
    elseif activeTab == "TOOLS" then self.priorityBadgeText:SetText("COMMAND")
    elseif activeTab == "COMBAT" then self.priorityBadgeText:SetText("ANALYZE")
    elseif activeTab == "BUILD" and model.nextBestMove then self.priorityBadgeText:SetText("NEXT")
    else self.priorityBadgeText:SetText("ADVISOR") end

    local stats = view.stats or {}
    for i = 1, STAT_ROWS do
        local stat = stats[i]
        self.statLabels[i]:SetText(stat and stat.label or "")
        local value = stat and tostring(stat.value or "") or ""
        self.statValues[i]:SetText(fitSingleLine(self.statValues[i], value, math.floor(((EPC.saved.width or 620) - 32 - 8) / 2) - 18))
    end

    local showFocus = activeTab == "BUILD" and snapshot.level >= 50 and self.focusPanel ~= nil
    if self.focusPanel then self.focusPanel:SetHidden(not showFocus) end
    if self.listArea then
        self.listArea:ClearAnchors()
        if showFocus then
            self.listArea:SetAnchor(TOPLEFT, self.focusPanel, BOTTOMLEFT, 0, 10)
        else
            self.listArea:SetAnchor(TOPLEFT, self.statsArea, BOTTOMLEFT, 0, 12)
        end
    end
    if self.focusButtons then
        local activeFocus = EPC.Endgame and EPC.Endgame:GetFocus() or "DPS"
        for i = 1, #self.focusButtons do
            self.focusButtons[i]:SetNormalFontColor(unpack(self.focusNames[i] == activeFocus and C.gold or C.text))
        end
    end

    self.listArea:SetHidden(activeTab == "MAP" or activeTab == "ACTIVITY" or activeTab == "QUESTS" or activeTab == "GEAR" or activeTab == "TOOLS")
    self.travelPanel:SetHidden(activeTab ~= "MAP")
    self.activityPanel:SetHidden(activeTab ~= "ACTIVITY")
    self.questPanel:SetHidden(activeTab ~= "QUESTS")
    self.gearPanel:SetHidden(activeTab ~= "GEAR")
    self.toolsPanel:SetHidden(activeTab ~= "TOOLS")

    if activeTab == "MAP" then
        self:RenderTravel(travel)
        self.expandedHeight = MAP_EXPANDED_HEIGHT
    elseif activeTab == "ACTIVITY" then
        self:RenderActivity(activity)
        self.expandedHeight = ACTIVITY_EXPANDED_HEIGHT
    elseif activeTab == "QUESTS" then
        self:RenderQuest(questFinder)
        self.expandedHeight = QUEST_EXPANDED_HEIGHT
    elseif activeTab == "GEAR" then
        self:RenderSetJournal(setJournal)
        self.expandedHeight = GEAR_EXPANDED_HEIGHT
    elseif activeTab == "TOOLS" then
        self:RenderTools(tools)
        self.expandedHeight = TOOLS_EXPANDED_HEIGHT
    else
        self.listHeader:SetText(view.listHeader or "PRIORITIES")
        local items = view.items or {}
        for i = 1, LIST_ROWS do
            local row = self.listRows[i]
            local text = items[i]
            if text and text ~= "" then
                row.card:SetHidden(false)
                setWrappedText(row.text, text)
            else
                row.card:SetHidden(true)
            end
        end
        self.expandedHeight = showFocus and ENDGAME_BUILD_HEIGHT or EXPANDED_HEIGHT
    end

    if not EPC.saved.minimized then self.root:SetHeight(self.expandedHeight) end

    for i = 1, #self.tabButtons do
        local active = self.tabNames[i] == activeTab
        self.tabButtons[i]:SetNormalFontColor(unpack(active and C.gold or C.text))
        self.tabUnderlines[i]:SetHidden(not active)
    end

    self:ApplyInteractionMode(EPC.interactionMode)
end
