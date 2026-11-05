local L = SimpleGroupDPS_Translate or function(text) return text end
-- Damage and received healing are separate sections; only damage enters the DPS sum.
local panel = {}
SimpleGroupDPS_DPSPanel = panel
local function isHealing(member)
    if LFG_ROLE_HEAL ~= nil and member.role == LFG_ROLE_HEAL then return true end
    if (LFG_ROLE_DPS ~= nil and member.role == LFG_ROLE_DPS)
        or (LFG_ROLE_TANK ~= nil and member.role == LFG_ROLE_TANK) then return false end
    return (member.displayType or member.messageType) == "healing"
end
local function getLayout(options)
    options = type(options) == "table" and options or {}
    local width = math.max(280, math.min(400, tonumber(options.dpsWidth) or 400))
    local font = math.floor(math.max(14, math.min(30, tonumber(options.dpsFontSize) or 22)))
    local spacing = math.max(0, math.min(16, tonumber(options.dpsRowSpacing) or 8))
    local valueFont = tonumber(options.dpsValueFontSize)
    if valueFont then valueFont = math.floor(math.max(14, math.min(32, valueFont))) end
    return width, font, math.max(font + 2, font + spacing, valueFont and valueFont + 2 or 0), valueFont
end

local function layoutRow(row, header, width, font, rowHeight, requestedValueFont, classColumn)
    local valueWidth = header and 96 or math.floor((width - 48) * (requestedValueFont and 0.56 or 0.49))
    local nameWidth = header and (width - 124) or (width - 48 - valueWidth - (classColumn and 32 or 0))
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
        row.swtBar:ClearAnchors()
        row.swtBar:SetAnchor(TOPLEFT, row, TOPLEFT, classColumn and -60 or -28, 0)
        local iconSize = math.min(28, rowHeight - 2)
        row.swtIcon:SetDimensions(iconSize, iconSize)
        row.swtIcon:ClearAnchors()
        row.swtIcon:SetAnchor(TOPLEFT, row, TOPLEFT, -28, (rowHeight - iconSize) / 2)
        row.swtClassIcon:SetDimensions(iconSize, iconSize)
        row.swtClassIcon:ClearAnchors()
        row.swtClassIcon:SetAnchor(TOPLEFT, row, TOPLEFT, -60, (rowHeight - iconSize) / 2)
    end
end
local function setValue(control, text)
    control:SetText(text)
    local size = control.requestedFontSize
    local textWidth = control.GetTextWidth and control:GetTextWidth()
    if type(textWidth) == "number" and textWidth > control.availableWidth then
        size = math.max(10, math.floor(size * control.availableWidth / textWidth))
        control:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", size))
        -- Font metrics need not scale exactly proportionally; verify the result.
        while size > 10 and control:GetTextWidth() > control.availableWidth do
            size = size - 1
            control:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", size))
        end
    end
end
local function formatValue(value)
    if value == nil then return "" end
    if SimpleGroupDPS_Language and SimpleGroupDPS_Language.english then
        if value == math.huge then return ">1.048M" end
        if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
        if value >= 1000 then return string.format("%.1fk", value / 1000) end
        return tostring(math.floor(math.max(0, value) + 0.5))
    end
    if value == math.huge then return ">1,048 Mio." end
    if value < 1000 then return tostring(math.floor(math.max(0, value) + 0.5)) end
    -- Keep the requested German unit even when ESO localizes thousands as "T.".
    if value < 1000000 then return (string.format("%.1f Tsd.", value / 1000):gsub("%.", ",", 1)) end
    if ZO_AbbreviateAndLocalizeNumber then
        return ZO_AbbreviateAndLocalizeNumber(value, 1, false)
    end
    if value >= 1000000 then return (string.format("%.1f Mio.", value / 1000000):gsub("%.", ",", 1)) end
    if value >= 1000 then return (string.format("%.1f Tsd.", value / 1000):gsub("%.", ",", 1)) end
    return tostring(math.floor(math.max(0, value) + 0.5))
end

local function formatMetrics(member, bossFight)
    if isHealing(member) then
        if member.rawHPS == nil then return L("Keine HPS-Daten") end
        return formatValue(member.effectiveHPS) .. " (" .. formatValue(member.rawHPS) .. ")"
    end
    if member.dps == nil then return L("Keine DPS-Daten") end
    if bossFight and member.bossDPS == nil then return "(" .. formatValue(member.dps) .. ")" end
    if bossFight then return formatValue(member.bossDPS) .. " (" .. formatValue(member.dps) .. ")" end
    return formatValue(member.dps)
end

local function roleIcon(member)
    if LFG_ROLE_TANK and member.role == LFG_ROLE_TANK then return "EsoUI/Art/LFG/Gamepad/lfg_roleicon_tank.dds" end
    if isHealing(member) then
        return "EsoUI/Art/LFG/Gamepad/lfg_roleicon_healer.dds"
    end
    return "EsoUI/Art/LFG/LFG_icon_dps.dds"
end

local classTextures = {}
local function classIcon(classId)
    if type(classId) ~= "number" or classId <= 0 or not GetClassIndexById or not GetClassInfo then return nil end
    if classTextures[classId] then return classTextures[classId] end
    local index = GetClassIndexById(classId)
    if not index then return nil end
    local id, _, _, _, _, _, texture = GetClassInfo(index)
    if id == classId and type(texture) == "string" and texture ~= "" then
        classTextures[classId] = texture
        return texture
    end
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
        local class = wm:CreateControl(nil, row, CT_TEXTURE)
        -- Magnify the class glyph inside its existing role-sized cell.
        class:SetTextureCoords(0.125, 0.875, 0.125, 0.875)
        class:SetHidden(true)
        row.swtClassIcon = class
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
        local aHealing, bHealing = isHealing(a), isHealing(b)
        if aHealing ~= bHealing then return not aHealing end
        local aValue, bValue = (aHealing and a.rawHPS or (not aHealing and a.dps)) or -1,
            (bHealing and b.rawHPS or (not bHealing and b.dps)) or -1
        if bossFight and not aHealing then aValue, bValue = a.bossDPS or -1, b.bossDPS or -1 end
        if aValue ~= bValue then return aValue > bValue end
        if not aHealing and a.dps ~= b.dps then return (a.dps or -1) > (b.dps or -1) end
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
    local damageCount, healingCount = 0, 0
    for _, member in ipairs(members) do
        if isHealing(member) then healingCount = healingCount + 1 else damageCount = damageCount + 1 end
    end
    local damageRows = damageCount > 0 and damageCount + 2 or 0
    local totalRows = damageRows + (healingCount > 0 and healingCount + 1 or 0)
    local hasStale = false
    for _, member in ipairs(members) do
        local metric
        if isHealing(member) then metric = member.rawHPS else metric = member.dps end
        if member.stale and metric ~= nil then hasStale = true; break end
    end
    local height = totalRows * rowHeight + 8 + (hasStale and 22 or 0)
    rows.backdrop:SetDimensions(width, height)
    rows.backdrop:SetHidden(false)

    local header = rows[0] or createRow(parent, true)
    rows[0] = header
    layoutRow(header, true, width, font, rowHeight)
    header:ClearAnchors()
    header:SetAnchor(TOPLEFT, parent, TOPLEFT, 12, 4)
    header:SetText(bossFight and L("Boss-Schaden (Gesamtschaden)") or L("Gesamtschaden"))
    header:SetColor(0.9, 0.96, 1, 1)
    -- Show completed whole seconds; preserve full precision in the meter.
    local seconds = math.floor(math.max(0, durationMS or 0) / 1000)
    local durationText = string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    setValue(header.swtDPSValue, durationText)
    header.swtDPSValue:SetColor(0.9, 0.96, 1, 1)
    header:SetHidden(damageCount == 0)

    if healingCount > 0 then
        local healingHeader = rows.healingHeader or createRow(parent, true)
        rows.healingHeader = healingHeader
        layoutRow(healingHeader, true, width, font, rowHeight)
        healingHeader:ClearAnchors()
        healingHeader:SetAnchor(TOPLEFT, parent, TOPLEFT, 12, 4 + damageRows * rowHeight)
        healingHeader:SetText(L("Heilung (HPS)"))
        setValue(healingHeader.swtDPSValue, "")
        healingHeader:SetColor(0.55, 0.95, 0.7, 1)
        healingHeader:SetHidden(false)
    end

    local maximum, healingMaximum, sum, bossSum, unknownBoss = 0, 0, 0, 0, false
    for _, member in ipairs(members) do
        if isHealing(member) then
            healingMaximum = math.max(healingMaximum, math.min(member.rawHPS or 0, 1048576))
        else
            local metric = member.dps
            if bossFight then metric = member.bossDPS end
            maximum = math.max(maximum, math.min(metric or 0, 1048576))
            sum = sum + (member.dps or 0)
            if member.bossDPS ~= nil then bossSum = bossSum + member.bossDPS else unknownBoss = true end
        end
    end
    for i, member in ipairs(members) do
        local row = rows[i] or createRow(parent, false)
        rows[i] = row
        layoutRow(row, false, width, font, rowHeight, valueFont, true)
        row:ClearAnchors()
        local healing = isHealing(member)
        local line = healing and (damageRows + i - damageCount) or i
        row:SetAnchor(TOPLEFT, parent, TOPLEFT, 68, 4 + line * rowHeight)
        row:SetText((member.name:gsub("^@", "")))
        setValue(row.swtDPSValue, formatMetrics(member, bossFight))
        if member.isPlayer then
            row:SetColor(1, 0.82, 0.35, 1)
        else
            row:SetColor(0.88, 0.97, 1, 1)
        end
        local missing = (healing and member.rawHPS == nil) or (not healing and member.dps == nil)
        if missing then row.swtDPSValue:SetColor(0.65, 0.7, 0.75, 1)
        elseif member.stale then row.swtDPSValue:SetColor(1, 0.75, 0.3, 1)
        else row.swtDPSValue:SetColor(0.88, 0.97, 1, 1) end
        row.swtIcon:SetHidden(false)
        row.swtIcon:SetTexture(roleIcon(member))
        local texture = classIcon(member.classId)
        if texture then row.swtClassIcon:SetTexture(texture) end
        row.swtClassIcon:SetHidden(texture == nil)
        local metric
        if healing then metric = member.rawHPS else metric = member.dps end
        if bossFight and not healing then metric = member.bossDPS end
        local barMaximum = healing and healingMaximum or maximum
        row.swtBar:SetValue(barMaximum > 0 and math.min(metric or 0, 1048576) / barMaximum or 0)
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
    summary:SetAnchor(TOPLEFT, parent, TOPLEFT, 36, 4 + (damageCount + 1) * rowHeight)
    summary:SetText(L("Summe"))
    setValue(summary.swtDPSValue, formatMetrics({ dps = sum, bossDPS = not unknownBoss and bossSum or nil }, bossFight))
    summary:SetColor(0.9, 0.96, 1, 1)
    summary.swtDPSValue:SetColor(0.9, 0.96, 1, 1)
    summary.swtIcon:SetHidden(true)
    summary.swtClassIcon:SetHidden(true)
    summary.swtBar:SetValue(1)
    summary.swtBar:SetColor(0.35, 0.35, 0.35, 0.25)
    summary:SetHidden(damageCount == 0)
    if hasStale then
        local status = rows.status
        if not status then
            status = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
            status:SetMaxLineCount(1)
            rows.status = status
        end
        status:ClearAnchors()
        status:SetAnchor(TOPLEFT, parent, TOPLEFT, 12, 4 + totalRows * rowHeight)
        status:SetDimensions(width - 24, 20)
        status:SetFont("$(BOLD_FONT)|14|soft-shadow-thin")
        status:SetColor(1, 0.75, 0.3, 1)
        status:SetText(L("Gelb: Wert älter als 15 s"))
        status:SetHidden(false)
    end
    return height
end

function panel:GetWidth(options) return (getLayout(options)) end
function panel:FormatValue(value) return formatValue(value) end

function panel:GetValueFontSize(options)
    local width, font, rowHeight, valueFont = getLayout(options)
    return valueFont or math.min(font + 2, rowHeight - 2, math.floor(math.floor((width - 48) * 0.49) / 9.5))
end
