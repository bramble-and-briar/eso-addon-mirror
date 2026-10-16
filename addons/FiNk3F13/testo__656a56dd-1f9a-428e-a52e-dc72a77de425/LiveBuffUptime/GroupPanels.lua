local Panels = {}
LiveBuffUptimeGroupPanels = Panels

local function setText(control, value, cache, key)
    if cache[key] ~= value then control:SetText(value); cache[key] = value end
end

function Panels.Config(tracker)
    local config = tracker.config
    if type(config.groupPanel) ~= "table" then
        config.groupPanel = { enabled = false, scale = 1, x = 40,
            y = 80 + ((config.key - 1) % 3) * 190,
            target = config.unit == "reticleover" and "enemies" or "group" }
    end
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
    window:SetDimensions(420, 172)
    window:SetClampedToScreen(true)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetMouseEnabled(false)
    window:SetMovable(false)
    window:SetHidden(true)
    local panel = {window = window, config = config, rows = {}, owner = tracker}
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
    panel.title = label(window, prefix .. "Title", 28, 0, 392, 24, "ZoFontGamepad22")
    panel.title:SetText(name)
    for index = 1, 12 do
        local x = math.floor((index - 1) / 6) * 216
        local y = 30 + ((index - 1) % 6) * 24
        local row = {}
        row.tint = WINDOW_MANAGER:CreateControl(prefix .. "Tint" .. index, window, CT_BACKDROP)
        row.tint:SetAnchor(TOPLEFT, window, TOPLEFT, x, y)
        row.tint:SetDimensions(204, 22)
        row.tint:SetCenterColor(0, 0, 0, 0)
        row.tint:SetEdgeColor(0, 0, 0, 0)
        row.role = WINDOW_MANAGER:CreateControl(prefix .. "Role" .. index, window, CT_TEXTURE)
        row.role:SetAnchor(TOPLEFT, window, TOPLEFT, x + 4, y + 3)
        row.role:SetDimensions(16, 16)
        row.name = label(window, prefix .. "Name" .. index, x + 26, y, 130, 22, "ZoFontGamepad18")
        row.timer = label(window, prefix .. "Timer" .. index, x + 162, y, 38, 22, "ZoFontGamepad18")
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
    if tracker.config.unit == "group" and tracker.config.groupRole == "damage"
        and tracker.config.groupPanel.target ~= "enemies" then
        local damageDealers = {}
        for _, member in ipairs(members) do
            if LFG_ROLE_DPS ~= nil and member.role == LFG_ROLE_DPS then damageDealers[#damageDealers + 1] = member end
        end
        members = damageDealers
    end
    local panel = Panels.Create(tracker, name)
    if panel.moving ~= moving then
        panel.window:SetMouseEnabled(moving)
        panel.window:SetMovable(moving)
        panel.border:SetHidden(not moving)
        panel.border:SetEdgeColor(0.8, 0.9, 1, moving and 1 or 0)
    end
    panel.moving = moving
    panel.window:SetHidden(not (visible or moving))
    for index = 1, 12 do
        local member, row = members[index], panel.rows[index]
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
        if member and member.dead then text, r, g, b = "Tot", 0.6, 0.63, 0.65
        elseif not online then text, r, g, b = "-", 0.6, 0.63, 0.65
        elseif hasBuff then
            local remaining = effect.ends - now
            text = effect.ends == 0 and "Aktiv" or (string.format("%.1f", math.max(0, remaining)):gsub("%.", ","))
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
