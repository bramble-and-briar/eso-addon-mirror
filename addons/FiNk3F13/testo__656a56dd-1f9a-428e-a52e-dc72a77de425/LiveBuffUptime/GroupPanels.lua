local L = LiveBuffUptimeLocalization and LiveBuffUptimeLocalization.Text or function(text) return text end
local Panels = {}
LiveBuffUptimeGroupPanels = Panels

local function panelColumns(config)
    return config.width < 420 and 1 or 2
end

local function layoutWidth(config, columns)
    if columns == 2 then return config.width end
    -- Keep every slider step effective while matching row widths at the wrap point.
    local minimum, wrapWidth = 120, 420
    local wrapRowWidth = (wrapWidth - 12) / 2
    local progress = (config.width - minimum) / (wrapWidth - minimum)
    return minimum + progress * (wrapRowWidth - minimum)
end

local function setText(control, value, cache, key)
    if cache[key] ~= value then control:SetText(value); cache[key] = value end
end

function Panels.Config(tracker)
    local config = tracker.config
    if type(config.groupPanel) ~= "table" then
        config.groupPanel = { enabled = false, scale = 1, x = 40,
            y = 80 + ((config.key - 1) % 3) * 190 }
    end
    config.groupPanel.target = "group"
    config.groupPanel.width = math.max(120, math.min(600, tonumber(config.groupPanel.width) or 420))
    config.groupPanel.scale = math.max(0.5, math.min(1.5, tonumber(config.groupPanel.scale) or 1))
    config.groupPanel.columns = nil
    return config.groupPanel
end

function Panels.Enabled(tracker)
    return tracker.config.enabled ~= false and type(tracker.config.groupPanel) == "table"
        and tracker.config.groupPanel.enabled == true
end

local function label(parent, name, x, y, width, height, font)
    local control = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    control:SetDimensions(width, height)
    control:SetFont(font or "ZoFontGamepad27")
    control:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control:SetMaxLineCount(1)
    if TEXT_WRAP_MODE_ELLIPSIS then control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
    return control
end

function Panels.Create(tracker, name)
    if tracker.groupPanel then return tracker.groupPanel end
    local config = Panels.Config(tracker)
    local prefix = "LiveBuffUptimeGroupPanel" .. tracker.config.key
    local window = WINDOW_MANAGER:CreateTopLevelWindow(prefix)
    local columns = panelColumns(config)
    local width = layoutWidth(config, columns)
    local columnWidth = columns == 1 and width or (width - 12) / 2
    local rowsPerColumn = columns == 1 and 12 or 6
    window:SetDimensions(width, columns == 1 and 316 or 172)
    window:SetClampedToScreen(true)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetMouseEnabled(false)
    window:SetMovable(false)
    window:SetHidden(true)
    local panel = {window = window, config = config, rows = {}, owner = tracker,
        lastWidth = config.width, lastColumns = columns}
    tracker.groupPanel = panel
    panel.border = WINDOW_MANAGER:CreateControl(prefix .. "Frame", window, CT_BACKDROP)
    panel.border:SetAnchorFill(window)
    panel.border:SetCenterColor(0, 0, 0, 0)
    panel.border:SetEdgeColor(0, 0, 0, 0)
    panel.border:SetHidden(true)
    panel.icon = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    panel.icon:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
    panel.icon:SetDimensions(22, 22)
    panel.icon:SetTexture(GetAbilityIcon(tracker.config.id))
    panel.title = label(window, prefix .. "Title", 28, 0, width - 28, 24, "ZoFontGamepad22")
    panel.title:SetText(name)
    for index = 1, 12 do
        local x = math.floor((index - 1) / rowsPerColumn) * (columnWidth + 12)
        local y = 30 + ((index - 1) % rowsPerColumn) * 24
        local row = {}
        row.tint = WINDOW_MANAGER:CreateControl(prefix .. "Tint" .. index, window, CT_BACKDROP)
        row.tint:SetAnchor(TOPLEFT, window, TOPLEFT, x, y)
        row.tint:SetDimensions(columnWidth, 22)
        row.tint:SetCenterColor(0, 0, 0, 0)
        row.tint:SetEdgeColor(0, 0, 0, 0)
        row.role = WINDOW_MANAGER:CreateControl(prefix .. "Role" .. index, window, CT_TEXTURE)
        row.role:SetAnchor(TOPLEFT, window, TOPLEFT, x + 4, y + 3)
        row.role:SetDimensions(16, 16)
        row.name = label(window, prefix .. "Name" .. index, x + 26, y, columnWidth - 74, 22, "ZoFontGamepad18")
        row.timer = label(window, prefix .. "Timer" .. index, x + columnWidth - 42, y, 38, 22, "ZoFontGamepad18")
        row.timer:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        panel.rows[index] = row
    end
    local function save()
        config.x, config.y = window:GetLeft(), window:GetTop()
    end
    window:SetHandler("OnMoveStop", save)
    window:SetHandler("OnMouseDown", function(control, button)
        if panel.moving and button == MOUSE_BUTTON_INDEX_LEFT then control:StartMoving() end
    end)
    window:SetHandler("OnMouseUp", function(control, button)
        if panel.moving and button == MOUSE_BUTTON_INDEX_LEFT then control:StopMovingOrResizing(); save() end
    end)
    window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, config.x, config.y)
    window:SetScale(config.scale)
    return panel
end

local function roleIcon(role)
    if role ~= nil and role == LFG_ROLE_DPS then return "EsoUI/Art/LFG/Gamepad/lfg_roleicon_dps.dds" end
    if role ~= nil and role == LFG_ROLE_HEAL then return "EsoUI/Art/LFG/Gamepad/lfg_roleicon_healer.dds" end
    if role ~= nil and role == LFG_ROLE_TANK then return "EsoUI/Art/LFG/Gamepad/lfg_roleicon_tank.dds" end
end

function Panels.Render(tracker, members, effects, now, visible, moving, match, name)
    if not Panels.Enabled(tracker) then
        if tracker.groupPanel then tracker.groupPanel.window:SetHidden(true) end
        return
    end
    if tracker.config.unit == "group" and tracker.config.groupRole == "damage" then
        local damageDealers = {}
        for _, member in ipairs(members) do
            if LFG_ROLE_DPS ~= nil and member.role == LFG_ROLE_DPS then damageDealers[#damageDealers + 1] = member end
        end
        members = damageDealers
    end
    local panel = Panels.Create(tracker, name)
    setText(panel.title, name, panel, "lastTitle")
    local width = panel.config.width
    local columns = panelColumns(panel.config)
    local frameWidth = layoutWidth(panel.config, columns)
    local columnWidth = columns == 1 and frameWidth or (frameWidth - 12) / 2
    if panel.lastWidth ~= width or panel.lastColumns ~= columns then
        panel.window:SetDimensions(frameWidth, columns == 1 and 316 or 172)
        panel.title:SetDimensions(frameWidth - 28, 24)
        panel.lastWidth, panel.lastColumns = width, columns
    end
    panel.window:SetDrawTier(moving and DT_HIGH or DT_LOW)
    panel.window:SetDrawLevel(moving and 100 or 0)
    if panel.moving ~= moving then
        panel.window:SetMouseEnabled(moving)
        panel.window:SetMovable(moving)
        panel.border:SetHidden(not moving)
        panel.border:SetEdgeColor(0.8, 0.9, 1, moving and 1 or 0)
    end
    panel.moving = moving
    panel.window:SetHidden(not (visible or moving))
    local count = math.min(12, #members)
    local rowsPerColumn = columns == 1 and 12 or (count > 6 and math.ceil(count / 2) or 6)
    for index = 1, 12 do
        local member, row = members[index], panel.rows[index]
        if member then
            local x = math.floor((index - 1) / rowsPerColumn) * (columnWidth + 12)
            local y = 30 + ((index - 1) % rowsPerColumn) * 24
            if row.lastX ~= x or row.lastY ~= y or row.lastWidth ~= width or row.lastColumns ~= columns then
                row.tint:ClearAnchors()
                row.tint:SetAnchor(TOPLEFT, panel.window, TOPLEFT, x, y)
                row.tint:SetDimensions(columnWidth, 22)
                row.role:ClearAnchors()
                row.role:SetAnchor(TOPLEFT, panel.window, TOPLEFT, x + 4, y + 3)
                row.name:ClearAnchors()
                row.name:SetAnchor(TOPLEFT, panel.window, TOPLEFT, x + 26, y)
                row.name:SetDimensions(columnWidth - 74, 22)
                row.timer:ClearAnchors()
                row.timer:SetAnchor(TOPLEFT, panel.window, TOPLEFT, x + columnWidth - 42, y)
                row.lastX, row.lastY, row.lastWidth, row.lastColumns = x, y, width, columns
            end
        end
        local effect = member and match(tracker.config, effects[member.tag] or {}, member)
        local online = member and member.available ~= false
        local hasBuff = online and not member.dead and effect and (effect.ends == 0 or effect.ends > now)
        setText(row.name, member and member.name or "", row, "lastName")
        row.name:SetHidden(not member)
        row.timer:SetHidden(not member)
        row.tint:SetHidden(not member)
        local icon = member and roleIcon(member.role)
        row.role:SetHidden(not icon)
        if icon then row.role:SetTexture(icon) end
        local text, r, g, b = "-", 0.9, 0.5, 0.5
        if member and member.dead then text, r, g, b = L("Tot"), 0.6, 0.63, 0.65
        elseif not online then text, r, g, b = "-", 0.6, 0.63, 0.65
        elseif hasBuff then
            local remaining = effect.ends - now
            if effect.ends == 0 then text = L("Aktiv")
            elseif LiveBuffUptimeLocalization then text = LiveBuffUptimeLocalization.Decimal(math.max(0, remaining), "%.1f")
            else text = (string.format("%.1f", math.max(0, remaining)):gsub("%.", ",")) end
            r, g, b = 0.55, 0.95, 0.7
            if effect.ends > 0 and remaining <= 3 then r, g, b = 1, 0.8, 0.35 end
        end
        local distant = online and not (member and member.dead) and member.distant == true
        if distant then r, g, b = 0.65, 0.68, 0.7 end
        setText(row.timer, text, row, "lastTimer")
        local state = tostring(r) .. ":" .. tostring(g) .. ":" .. tostring(b) .. ":" .. tostring(online) .. ":" .. tostring(member and member.dead) .. ":" .. tostring(distant)
        if row.lastColor ~= state then
            row.lastColor = state
            local alpha = distant and 0.65 or 1
            row.timer:SetColor(r, g, b, alpha)
            row.name:SetColor(r, g, b, alpha)
            row.role:SetColor(distant and 0.7 or 1, distant and 0.7 or 1, distant and 0.7 or 1, alpha)
            row.tint:SetCenterColor(r, g, b, distant and 0.04 or online and not (member and member.dead) and 0.13 or 0.06)
        end
    end
end
