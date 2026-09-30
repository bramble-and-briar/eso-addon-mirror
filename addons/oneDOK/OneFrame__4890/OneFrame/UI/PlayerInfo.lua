local A = OneFrame
local P = {}
A.PlayerInfo = P
function P:Alpha(frame)
    local bar = frame.healthBar.barControls[1]
    return bar.GetAlpha and bar:GetAlpha() or (IsUnitInGroupSupportRange(frame.unitTag) and 1 or 0.3)
end
function P:Name(frame, data)
    local label = frame.nameLabel
    if not label then return end
    local text, font = label:GetText(), label:GetFont()
    local width = label:GetWidth()
    if width ~= data.nameWidth then data.nativeNameWidth = width end
    if text ~= data.decoratedName then data.nativeName = text end
    if font ~= data.decoratedFont then data.nativeFont = font end
    local name = data.nativeName or text
    local decorate = A.active and DoesUnitExist(frame.unitTag) and IsUnitOnline(frame.unitTag)
    if decorate then
        if A.sv.account then name = GetUnitDisplayName(frame.unitTag) end
        if frame.style == "ZO_RaidUnitFrame" then
            local prefix = name:sub(1, 1) == "@" and "@" or ""
            local characters = {}
            local limit = IsUnitGroupLeader(frame.unitTag) and 5 or 7
            for character in name:sub(#prefix + 1):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                characters[#characters + 1] = character
                if #characters == limit then break end
            end
            name = prefix .. table.concat(characters)
        end
        if A.sv.class then
            local icon = ZO_GetClassIcon(GetUnitClassId(frame.unitTag))
            if icon then name = zo_iconFormat(icon, 16, 16) .. " " .. name end
        end
    end
    local wantedFont = decorate
        and "$(BOLD_FONT)|16|soft-shadow-thin" or data.nativeFont
    label:SetText(name)
    if wantedFont then label:SetFont(wantedFont) end
    local wantedWidth = data.nativeNameWidth
    if decorate and data.info and data.info:GetText() ~= "" then
        local bar = frame.healthBar.barControls[1]
        wantedWidth = math.max(20, bar:GetWidth() - data.info:GetTextWidth() - 8)
    end
    label:SetWidth(wantedWidth)
    data.nameWidth = wantedWidth
    data.decoratedName, data.decoratedFont = name, wantedFont
end
function P:Create(frame)
    local parent = frame.frame
    local data = {}
    for _, key in ipairs({ "info", "stats", "statsCaption", "health" }) do
        local label = WINDOW_MANAGER:CreateControl(parent:GetName() .. "OneFrame" .. key, parent, CT_LABEL)
        label:SetMouseEnabled(false)
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        label:SetColor(1, 1, 1, 1)
        label:SetDrawLayer(DL_TEXT)
        data[key] = label
    end
    data.ultimate = A.UltimateUI:Create(frame)
    return data
end
function P:Layout(frame, data)
    local raid = frame.style == "ZO_RaidUnitFrame"
    local bar = frame.healthBar.barControls[1]
    local width = bar:GetWidth()
    for _, label in ipairs({ data.info, data.stats }) do
        label:ClearAnchors()
        label:SetFont(raid and "$(BOLD_FONT)|12|soft-shadow-thin" or "ZoFontGameSmall")
        -- A fixed 12/16px box can be shorter than ESO's localized font line and
        -- suppress the entire line. Measure the font, including Cyrillic fallback.
        label:SetDimensions(math.max(0, width - (raid and 8 or 0)), label:GetFontHeight() + 2)
        label:SetAlpha(self:Alpha(frame))
    end
    if raid then
        data.info:SetAnchor(TOPRIGHT, bar, TOPRIGHT, -3, 3)
        data.stats:SetAnchor(BOTTOMLEFT, bar, BOTTOMLEFT, 3, 0)
    else
        -- The native small-group control is much wider than its visible health bar.
        -- Keep metadata inside the bar's right edge and immediately above it.
        data.info:SetAnchor(BOTTOMRIGHT, bar, TOPRIGHT, 0, -4)
        data.stats:SetAnchor(TOPLEFT, bar, BOTTOMLEFT, 0, 4)
    end
    data.info:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    data.stats:SetFont("$(BOLD_FONT)|16|soft-shadow-thin")
    data.stats:SetHeight(data.stats:GetFontHeight() + 2)
    if data.statsCaption then
        local caption = data.statsCaption
        caption:ClearAnchors()
        caption:SetFont(raid and "$(MEDIUM_FONT)|9|soft-shadow-thin" or "$(MEDIUM_FONT)|10|soft-shadow-thin")
        caption:SetDimensions(raid and 21 or 27, caption:GetFontHeight() + 2)
        caption:SetAnchor(raid and BOTTOMLEFT or TOPLEFT, bar, BOTTOMLEFT, raid and 3 or 0, raid and -2 or 5)
        caption:SetAlpha(self:Alpha(frame))
        data.stats:ClearAnchors()
        data.stats:SetAnchor(raid and BOTTOMLEFT or TOPLEFT, bar, BOTTOMLEFT, raid and 26 or 30, raid and 0 or 1)
    end
    if data.health then
        local health = data.health
        health:ClearAnchors()
        health:SetFont("$(BOLD_FONT)|14|soft-shadow-thin")
        health:SetDimensions(48, health:GetFontHeight() + 2)
        health:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        health:SetAnchor(raid and BOTTOMRIGHT or TOPRIGHT, bar, BOTTOMRIGHT, -7, raid and 0 or 1)
    end
end
function P:CanShow(frame)
    return A.active and DoesUnitExist(frame.unitTag) and IsUnitOnline(frame.unitTag)

end
function P:Update(frame, data)
    self:Layout(frame, data)
    local tag, pieces = frame.unitTag, {}
    if IsUnitChampion(tag) then
        if A.sv.cp then pieces[#pieces + 1] = tostring(GetUnitChampionPoints(tag)) end
    elseif A.sv.level then
        pieces[#pieces + 1] = tostring(GetUnitLevel(tag))
    end
    -- Class/account belong to the native name line; this row contains level only.
    data.info:SetText(table.concat(pieces, "  "))
    if IsUnitChampion(tag) then data.info:SetColor(1, 1, 1, 1)
    else data.info:SetColor(0.3, 1, 0.3, 1) end
    data.info:SetWidth(data.info:GetTextWidth() + 2)
    self:Name(frame, data)
    data.info:SetHidden(not self:CanShow(frame) or #pieces == 0)
    self:Stats(frame, data)
end
function P:Format(value)
    if value == nil then return GetString(ONEFRAME_UNAVAILABLE) end
    if value >= 1000000 then return string.format(GetString(ONEFRAME_MILLION), value / 1000000) end
    if value >= 1000 then return string.format(GetString(ONEFRAME_KILO), value / 1000) end
    return tostring(math.floor(value + 0.5))
end
function P:Stats(frame, data)
    local identity = DoesUnitExist(frame.unitTag)
        and (GetUnitDisplayName(frame.unitTag) .. ":" .. GetUnitName(frame.unitTag)) or nil
    if data.statsIdentity ~= identity then
        data.statsIdentity, data.lastRates = identity, {}
    end
    data.lastRates = data.lastRates or {}
    if not DoesUnitExist(frame.unitTag) or not IsUnitOnline(frame.unitTag) then
        data.lastRates = {}
        if data.ultimate then data.ultimate.lastPoints = nil end
        self:Name(frame, data)
        for _, key in ipairs({"info", "stats", "statsCaption", "health"}) do
            if data[key] then data[key]:SetHidden(true) end
        end
        for _, edge in ipairs(data.leaderBorder or {}) do edge:SetHidden(true) end
        A.UltimateUI:Hide(data.ultimate)
        return
    end
    local dps, hps = A.CombatStats:Values(frame.unitTag)
    -- Presentation retains only values previously validated for this occupant.
    if not A.active or not A.sv.hodor then data.lastRates = {} end
    if dps ~= nil then data.lastRates.dps = dps else dps = data.lastRates.dps end
    if hps ~= nil then data.lastRates.hps = hps else hps = data.lastRates.hps end
    local caption, value
    local role = GetGroupMemberSelectedRole(frame.unitTag)
    local selected = A:RoleStatistic(role)
    if selected == "dps" then caption, value = GetString(ONEFRAME_DPS_LABEL), dps end
    if selected == "hps" then caption, value = GetString(ONEFRAME_HPS_LABEL), hps end
    local hidden = not self:CanShow(frame) or not caption or value == nil
    data.stats:SetText(caption and self:Format(value) or "")
    data.stats:SetHidden(hidden)
    if data.statsCaption then
        data.statsCaption:SetText(caption and caption .. ":" or "")
        data.statsCaption:SetHidden(hidden)
    end
    A.UltimateUI:Update(frame, data)
    local alpha = self:Alpha(frame)
    for _, key in ipairs({"info", "stats", "statsCaption", "health"}) do
        if data[key] then data[key]:SetAlpha(alpha) end
    end
    if data.health then
        local hp = GetUnitPower(frame.unitTag, COMBAT_MECHANIC_FLAGS_HEALTH)
        data.health:SetText(type(hp) == "number" and string.format(GetString(ONEFRAME_HEALTH_THOUSANDS), hp / 1000) or "")
        data.health:SetHidden(not self:CanShow(frame) or IsUnitDead(frame.unitTag) or type(hp) ~= "number")
        local raid = frame.style == "ZO_RaidUnitFrame"
        local width = frame.healthBar.barControls[1]:GetWidth()
        -- Reserve only the rendered health text, not a fixed 48px column.
        local healthWidth = data.health.GetTextWidth and math.ceil(data.health:GetTextWidth()) or 48
        data.health:SetWidth(healthWidth)
        local statsLeft = data.statsCaption and (raid and 26 or 30) or (raid and 3 or 0)
        data.stats:SetWidth(math.max(0, width - 7 - healthWidth - 3 - statsLeft))
    end
end
