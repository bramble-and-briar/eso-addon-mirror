-- Compact damage-only group meter. Healing metrics are deliberately absent.
local panel = {}
SimpleGroupDPS_DPSPanel = panel
local function getLayout(options)
    options = type(options) == "table" and options or {}
    local width = math.max(280, math.min(400, tonumber(options.dpsWidth) or 400))
    local font = math.floor(math.max(14, math.min(30, tonumber(options.dpsFontSize) or 22)))
    local spacing = math.max(0, math.min(16, tonumber(options.dpsRowSpacing) or 8))
    local valueFont = tonumber(options.dpsValueFontSize)
    if valueFont then valueFont = math.floor(math.max(14, math.min(32, valueFont))) end
    return width, font, math.max(font + 2, font + spacing, valueFont and valueFont + 2 or 0), valueFont
end

local function layoutRow(row, header, width, font, rowHeight, requestedValueFont)
    local valueWidth = header and 96 or math.floor((width - 48) * (requestedValueFont and 0.56 or 0.49))
    local nameWidth = header and (width - 124) or (width - 48 - valueWidth)
    row:SetDimensions(nameWidth, rowHeight)
    local nameFont = header and math.max(14, math.min(font, math.floor(nameWidth / 15))) or font
    row:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", nameFont))
    row:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.swtDPSValue:ClearAnchors()
    row.swtDPSValue:SetAnchor(TOPLEFT, row, TOPRIGHT, header and 0 or 4, 0)
    row.swtDPSValue:SetDimensions(valueWidth, rowHeight)
    local valueFont = header and font or requestedValueFont or math.min(font + 2, rowHeight - 2, math.floor(valueWidth / 9.5))
    row.swtDPSValue:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", valueFont))
    row.swtDPSValue.requestedFontSize = valueFont
    row.swtDPSValue.availableWidth = valueWidth
    row.swtDPSValue:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    if not header then
        row.swtBar:SetDimensions(width - 16, rowHeight - 1)
        local iconSize = math.min(28, rowHeight - 2)
        row.swtIcon:SetDimensions(iconSize, iconSize)
        row.swtIcon:ClearAnchors()
        row.swtIcon:SetAnchor(TOPLEFT, row, TOPLEFT, -28, (rowHeight - iconSize) / 2)
    end
end
local function setValue(control, text)
    control:SetText(text)
    local size = control.requestedFontSize
    local textWidth = control.GetTextWidth and control:GetTextWidth()
    if type(textWidth) == "number" and textWidth > control.availableWidth then
        size = math.max(10, math.floor(size * control.availableWidth / textWidth))
        control:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", size))
    end
end
local function formatValue(value)
    if value == nil then return "" end
    if value == math.huge then return ">1,048 Mio." end
    if ZO_AbbreviateAndLocalizeNumber then
        return ZO_AbbreviateAndLocalizeNumber(value, 1, false)
    end
    if value >= 1000000 then return (string.format("%.1f Mio.", value / 1000000):gsub("%.", ",", 1)) end
    if value >= 1000 then return (string.format("%.1f Tsd.", value / 1000):gsub("%.", ",", 1)) end
    return tostring(math.floor(math.max(0, value) + 0.5))
end

local function formatMetrics(member, bossFight)
    if bossFight and member.bossDPS == nil then return "(" .. formatValue(member.dps) .. ")" end
    if bossFight then return formatValue(member.bossDPS) .. " (" .. formatValue(member.dps) .. ")" end
    return formatValue(member.dps)
end

local function createRow(parent, header)
    local wm = WINDOW_MANAGER
    local row = wm:CreateControl(nil, parent, CT_LABEL)
    row:SetFont("$(BOLD_FONT)|22|soft-shadow-thin")
    row:SetMaxLineCount(1)
    if TEXT_WRAP_MODE_ELLIPSIS then row:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
    row:SetDrawLayer(DL_CONTROLS)

    local value = wm:CreateControl(nil, row, CT_LABEL)
    value:SetAnchor(TOPLEFT, row, TOPRIGHT, header and 0 or 4, 0)
    value:SetFont("$(BOLD_FONT)|22|soft-shadow-thin")
    value:SetMaxLineCount(1)
    if TEXT_WRAP_MODE_ELLIPSIS then value:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
    value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    value:SetDrawLayer(DL_CONTROLS)
    row.swtDPSValue = value

    if not header then
        local bar = wm:CreateControl(nil, row, CT_STATUSBAR)
        bar:SetAnchor(TOPLEFT, row, TOPLEFT, -28, 0)
        bar:SetTexture("EsoUI/Art/Miscellaneous/centerscreen_left.dds")
        bar:SetMinMax(0, 1)
        bar:SetDrawLayer(DL_BACKGROUND)
        bar:SetDrawLevel(1)
        row.swtBar = bar

        local icon = wm:CreateControl(nil, row, CT_TEXTURE)
        icon:SetDimensions(24, 24)
        icon:SetAnchor(TOPLEFT, row, TOPLEFT, -28, 2)
        icon:SetTexture("EsoUI/Art/LFG/LFG_icon_dps.dds")
        row.swtIcon = icon
    end
    return row
end

function panel:Render(parent, members, bossFight, durationMS, options, localTotals)
    local width, font, rowHeight, valueFont = getLayout(options)
    local rows = parent.swtGroupDPSLabels
    if not rows then rows = {}; parent.swtGroupDPSLabels = rows end
    for _, row in pairs(rows) do row:SetHidden(true) end
    if #members == 0 then return 0 end

    local values = {}
    for i, member in ipairs(members) do
        values[i] = member
    end
    members = values
    table.sort(members, function(a, b)
        local aValue, bValue = a.dps, b.dps
        if bossFight then aValue, bValue = a.bossDPS or -1, b.bossDPS or -1 end
        if aValue ~= bValue then return aValue > bValue end
        if a.dps ~= b.dps then return a.dps > b.dps end
        return a.name < b.name
    end)

    if not rows.backdrop then
        rows.backdrop = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
        rows.backdrop:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
        rows.backdrop:SetCenterColor(0.015, 0.02, 0.025, 0.72)
        rows.backdrop:SetEdgeColor(0, 0, 0, 0)
        rows.backdrop:SetDrawLayer(DL_BACKGROUND)
        rows.backdrop:SetDrawLevel(0)
    end
    local height = (#members + 2) * rowHeight + 8
    rows.backdrop:SetDimensions(width, height)
    rows.backdrop:SetHidden(false)

    local header = rows[0] or createRow(parent, true)
    rows[0] = header
    layoutRow(header, true, width, font, rowHeight)
    header:ClearAnchors()
    header:SetAnchor(TOPLEFT, parent, TOPLEFT, 12, 4)
    header:SetText(bossFight and "Boss-Schaden (Gesamtschaden)" or "Gesamtschaden")
    header:SetColor(0.9, 0.96, 1, 1)
    local seconds = math.floor(math.max(0, durationMS or 0) / 1000)
    -- Show completed seconds explicitly; the formatter must not round 5.1s up to 6s.
    local durationText = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    setValue(header.swtDPSValue, durationText)
    header.swtDPSValue:SetColor(0.9, 0.96, 1, 1)
    header:SetHidden(false)

    local maximum, sum, bossSum, unknownBoss = 0, 0, 0, false
    for _, member in ipairs(members) do
        local metric = member.dps
        if bossFight then metric = member.bossDPS end
        maximum = math.max(maximum, math.min(metric or 0, 1048576))
        sum = sum + member.dps
        if member.bossDPS ~= nil then bossSum = bossSum + member.bossDPS else unknownBoss = true end
    end
    for i, member in ipairs(members) do
        local row = rows[i] or createRow(parent, false)
        rows[i] = row
        layoutRow(row, false, width, font, rowHeight, valueFont)
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, parent, TOPLEFT, 36, 4 + i * rowHeight)
        row:SetText((member.name:gsub("^@", "")))
        setValue(row.swtDPSValue, formatMetrics(member, bossFight))
        if member.isPlayer then
            row:SetColor(1, 0.82, 0.35, 1)
        else
            row:SetColor(0.88, 0.97, 1, 1)
        end
        row.swtDPSValue:SetColor(0.88, 0.97, 1, member.stale and 0.55 or 1)
        row.swtIcon:SetHidden(false)
        local metric = member.dps
        if bossFight then metric = member.bossDPS end
        row.swtBar:SetValue(maximum > 0 and math.min(metric or 0, 1048576) / maximum or 0)
        row.swtBar:SetColor(member.isPlayer and 0.1 or 0.25, member.isPlayer and 0.85 or 0.4, 0.35, member.isPlayer and 0.6 or 0.14)
        row:SetHidden(false)
    end

    -- Prefer the local encounter; received member DPS can use unrelated fight clocks.
    if localTotals and localTotals.groupDPS ~= nil then
        sum = localTotals.groupDPS
        bossSum = localTotals.groupBossDPS
        unknownBoss = bossSum == nil
    end
    local summary = rows.summary or createRow(parent, false)
    rows.summary = summary
    layoutRow(summary, false, width, font, rowHeight, valueFont)
    summary:ClearAnchors()
    summary:SetAnchor(TOPLEFT, parent, TOPLEFT, 36, 4 + (#members + 1) * rowHeight)
    summary:SetText("Summe")
    setValue(summary.swtDPSValue, formatMetrics({ dps = sum, bossDPS = not unknownBoss and bossSum or nil }, bossFight))
    summary:SetColor(0.9, 0.96, 1, 1)
    summary.swtDPSValue:SetColor(0.9, 0.96, 1, 1)
    summary.swtIcon:SetHidden(true)
    summary.swtBar:SetValue(1)
    summary.swtBar:SetColor(0.35, 0.35, 0.35, 0.25)
    summary:SetHidden(false)
    return height
end

function panel:GetWidth(options) return (getLayout(options)) end

function panel:GetValueFontSize(options)
    local width, font, rowHeight, valueFont = getLayout(options)
    return valueFont or math.min(font + 2, rowHeight - 2, math.floor(math.floor((width - 48) * 0.49) / 9.5))
end
