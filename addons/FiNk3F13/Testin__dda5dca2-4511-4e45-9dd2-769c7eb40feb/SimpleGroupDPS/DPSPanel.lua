-- Compact damage-only group meter. Healing metrics are deliberately absent.
local panel = {}
SimpleGroupDPS_DPSPanel = panel
local function getLayout(options)
    options = type(options) == "table" and options or {}
    local width = math.max(420, math.min(800, tonumber(options.dpsWidth) or 520))
    local font = math.floor(math.max(14, math.min(30, tonumber(options.dpsFontSize) or 22)))
    local spacing = math.max(0, math.min(16, tonumber(options.dpsRowSpacing) or 8))
    return width, font, math.max(font + 2, font + spacing)
end

local function layoutRow(row, header, width, font, rowHeight)
    local valueWidth = header and 96 or math.floor((width - 48) * 0.49)
    local nameWidth = header and (width - 124) or (width - 48 - valueWidth)
    row:SetDimensions(nameWidth, rowHeight)
    local nameFont = header and math.min(font, math.floor(nameWidth / 15)) or font
    row:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", nameFont))
    row:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.swtDPSValue:ClearAnchors()
    row.swtDPSValue:SetAnchor(TOPLEFT, row, TOPRIGHT, header and 0 or 4, 0)
    row.swtDPSValue:SetDimensions(valueWidth, rowHeight)
    local valueFont = header and font or math.min(font, math.floor(valueWidth / 10.5))
    row.swtDPSValue:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", valueFont))
    row.swtDPSValue:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    if not header then
        row.swtBar:SetDimensions(width - 16, rowHeight - 1)
        local iconSize = math.min(28, rowHeight - 2)
        row.swtIcon:SetDimensions(iconSize, iconSize)
        row.swtIcon:ClearAnchors()
        row.swtIcon:SetAnchor(TOPLEFT, row, TOPLEFT, -28, (rowHeight - iconSize) / 2)
    end
end
local function formatValue(value)
    if value == nil then return "--" end
    if value == math.huge then return ">1,048 Mio." end
    if ZO_AbbreviateAndLocalizeNumber then
        return ZO_AbbreviateAndLocalizeNumber(value, 1, false)
    end
    if value >= 1000000 then return (string.format("%.1f Mio.", value / 1000000):gsub("%.", ",", 1)) end
    if value >= 1000 then return (string.format("%.1f Tsd.", value / 1000):gsub("%.", ",", 1)) end
    return tostring(math.floor(math.max(0, value) + 0.5))
end

local function formatMetrics(member, bossFight)
    local function metric(value)
        return (not member.isPlayer and value ~= nil and value < math.huge and "~" or "") .. formatValue(value)
    end
    if bossFight then return metric(member.bossDPS) .. " / " .. metric(member.dps) end
    return metric(member.dps)
end

local function createRow(parent, header)
    local wm = WINDOW_MANAGER
    local row = wm:CreateControl(nil, parent, CT_LABEL)
    row:SetFont("$(BOLD_FONT)|22|soft-shadow-thin")
    row:SetMaxLineCount(1)
    row:SetDrawLayer(DL_CONTROLS)

    local value = wm:CreateControl(nil, row, CT_LABEL)
    value:SetAnchor(TOPLEFT, row, TOPRIGHT, header and 0 or 4, 0)
    value:SetFont("$(BOLD_FONT)|22|soft-shadow-thin")
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

function panel:Render(parent, members, bossFight, durationMS, options)
    local width, font, rowHeight = getLayout(options)
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
    header:SetText(bossFight and "Boss-Schaden / Gesamtschaden" or "Gesamtschaden")
    header:SetColor(0.9, 0.96, 1, 1)
    local seconds = math.floor(math.max(0, durationMS or 0) / 1000)
    header.swtDPSValue:SetText(string.format("%d:%02d", math.floor(seconds / 60), seconds % 60))
    header.swtDPSValue:SetColor(0.9, 0.96, 1, 1)
    header:SetHidden(false)

    local maximum, sum, bossSum, unknownBoss, approximate = 0, 0, 0, false, false
    for _, member in ipairs(members) do
        local metric = member.dps
        if bossFight then metric = member.bossDPS end
        maximum = math.max(maximum, math.min(metric or 0, 1048576))
        sum = sum + member.dps
        if member.bossDPS ~= nil then bossSum = bossSum + member.bossDPS else unknownBoss = true end
        approximate = approximate or not member.isPlayer
    end
    for i, member in ipairs(members) do
        local row = rows[i] or createRow(parent, false)
        rows[i] = row
        layoutRow(row, false, width, font, rowHeight)
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, parent, TOPLEFT, 36, 4 + i * rowHeight)
        row:SetText((member.name:gsub("^@", "")))
        row.swtDPSValue:SetText(formatMetrics(member, bossFight))
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

    local summary = rows.summary or createRow(parent, false)
    rows.summary = summary
    layoutRow(summary, false, width, font, rowHeight)
    summary:ClearAnchors()
    summary:SetAnchor(TOPLEFT, parent, TOPLEFT, 36, 4 + (#members + 1) * rowHeight)
    summary:SetText("Summe (angezeigt)")
    summary.swtDPSValue:SetText(formatMetrics({ dps = sum, bossDPS = not unknownBoss and bossSum or nil,
        isPlayer = not approximate }, bossFight))
    summary:SetColor(0.9, 0.96, 1, 1)
    summary.swtDPSValue:SetColor(0.9, 0.96, 1, 1)
    summary.swtIcon:SetHidden(true)
    summary.swtBar:SetValue(1)
    summary.swtBar:SetColor(0.35, 0.35, 0.35, 0.25)
    summary:SetHidden(false)
    return height
end

function panel:GetWidth(options) return (getLayout(options)) end
