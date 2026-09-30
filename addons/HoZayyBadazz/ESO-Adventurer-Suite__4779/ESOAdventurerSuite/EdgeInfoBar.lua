-- ESO Adventurer Suite
-- Edge Info Bar (v0.29.763)
-- Optional screen-edge currency / inventory strip inspired by compact MMO info bars.

local EPC = ESOProgressionCoach
if not EPC then return end

EPC.EdgeInfoBar = EPC.EdgeInfoBar or {}
local B = EPC.EdgeInfoBar
local WM = WINDOW_MANAGER

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a,b,c,d
end

local function fmt(value)
    value = math.floor(tonumber(value) or 0)
    if type(ZO_CommaDelimitNumber) == "function" then
        local ok, text = pcall(ZO_CommaDelimitNumber, value)
        if ok and text then return tostring(text) end
    end
    return tostring(value)
end

local function nowText()
    local format = EPC.saved and tostring(EPC.saved.edgeInfoBarClockFormat029770 or "12H") or "12H"
    local seconds = tonumber((safe(GetSecondsSinceMidnight, nil)))
    if seconds then
        local h = math.floor(seconds / 3600) % 24
        local m = math.floor((seconds % 3600) / 60)
        if format == "24H" then
            return string.format("%02d:%02d", h, m)
        end
        local suffix = h >= 12 and "PM" or "AM"
        local h12 = h % 12
        if h12 == 0 then h12 = 12 end
        return string.format("%d:%02d %s", h12, m, suffix)
    end
    if type(GetTimeString) == "function" then
        local ok, text = pcall(GetTimeString)
        if ok and text and text ~= "" then return tostring(text) end
    end
    return ""
end

local function stableText()
    if type(GetTimeUntilCanBeTrained) ~= "function" then return "--" end
    if EPC.StableTimer and type(EPC.StableTimer.IsMaxed) == "function" then
        local ok, maxed = pcall(EPC.StableTimer.IsMaxed, EPC.StableTimer)
        if ok and maxed then return "MAX" end
    end
    local ms = tonumber((safe(GetTimeUntilCanBeTrained, 0))) or 0
    if ms <= 0 then return "READY" end
    local total = math.max(0, math.ceil(ms / 1000))
    local h = math.floor(total / 3600)
    local m = math.floor((total % 3600) / 60)
    local s = total % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%02d:%02d", m, s)
end

local function performanceEntries()
    local fps = math.max(0, math.floor((tonumber((safe(GetFramerate, 0))) or 0) + 0.5))
    local ping = math.max(0, math.floor((tonumber((safe(GetLatency, 0))) or 0) + 0.5))
    return "FPS " .. tostring(fps), "PING " .. tostring(ping) .. " ms"
end

local function performanceText()
    local fpsText, pingText = performanceEntries()
    return fpsText .. "   •   " .. pingText
end

function B:Create()
    if self.frame or not WM or not GuiRoot then return end
    local root = WM:CreateTopLevelWindow("EAS_EdgeInfoBar029763")
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)
    root:SetMouseEnabled(false)
    if root.SetTopLevel then root:SetTopLevel(true) end

    local bg = WM:CreateControl(nil, root, CT_BACKDROP)
    bg:SetAnchorFill(root)
    bg:SetCenterColor(0.005,0.008,0.012,0.90)
    bg:SetEdgeColor(0.22,0.22,0.22,0.92)
    bg:SetEdgeTexture(nil,1,1,1)

    local function makeSection()
        local label = WM:CreateControl(nil, root, CT_LABEL)
        label:SetFont("ZoFontGameSmall")
        label:SetColor(0.92,0.92,0.92,1)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        return label
    end

    local left = makeSection()
    local center = makeSection()
    local right = makeSection()
    left:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    center:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    right:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    self.frame = root
    self.leftLabel029772 = left
    self.centerLabel029772 = center
    self.rightLabel029772 = right
    self.segmentLabels029776 = {}
    -- Compatibility alias for older code that only checked for a label.
    self.label = center
end

function B:GetCurrencyEntries()
    local entries = {}
    local beginValue = tonumber(rawget(_G,"CURT_ITERATION_BEGIN"))
    local endValue = tonumber(rawget(_G,"CURT_ITERATION_END"))
    if not beginValue or not endValue or type(GetCurrencyAmount) ~= "function" then return entries end

    local showZero = EPC.saved and EPC.saved.edgeInfoBarShowZero029763 == true
    for currencyType = beginValue, endValue do
        local location = rawget(_G,"CURRENCY_LOCATION_CHARACTER")
        if type(GetCurrencyPlayerStoredLocation) == "function" then
            location = safe(GetCurrencyPlayerStoredLocation, location, currencyType)
        end
        local amount = tonumber((safe(GetCurrencyAmount, 0, currencyType, location))) or 0
        if showZero or amount > 0 then
            local icon = ""
            if type(ZO_Currency_GetKeyboardFormattedCurrencyIcon) == "function" then
                icon = tostring(safe(ZO_Currency_GetKeyboardFormattedCurrencyIcon, "", currencyType, 16, true) or "")
            end
            if icon ~= "" then
                entries[#entries+1] = icon .. " " .. fmt(amount)
            else
                entries[#entries+1] = fmt(amount)
            end
        end
    end
    return entries
end

function B:BuildSections029772()
    local left, center, right = {}, {}, {}
    local sep = "   •   "

    if not EPC.saved or EPC.saved.edgeInfoBarClock029763 ~= false then
        local t = nowText()
        if t ~= "" then left[#left+1] = t end
    end

    if not EPC.saved or EPC.saved.edgeInfoBarBag029763 ~= false then
        local used = tonumber((safe(GetNumBagUsedSlots, 0, BAG_BACKPACK))) or 0
        local total = tonumber((safe(GetBagSize, 0, BAG_BACKPACK))) or 0
        if total > 0 then
            left[#left+1] = "|t16:16:EsoUI/Art/Inventory/inventory_tabIcon_items_up.dds|t " .. tostring(used) .. "/" .. tostring(total)
        end
    end

    for _,entry in ipairs(self:GetCurrencyEntries()) do center[#center+1] = entry end

    if EPC.saved and EPC.saved.edgeInfoBarStable029770 ~= false then
        right[#right+1] = "STABLE " .. stableText()
    end

    if EPC.saved and EPC.saved.edgeInfoBarPerformance029770 ~= false then
        right[#right+1] = performanceText()
    end

    return table.concat(left, sep), table.concat(center, sep), table.concat(right, sep)
end

function B:BuildEntries()
    local entries = {}
    if not EPC.saved or EPC.saved.edgeInfoBarClock029763 ~= false then
        local t = nowText()
        if t ~= "" then entries[#entries+1] = t end
    end

    if not EPC.saved or EPC.saved.edgeInfoBarBag029763 ~= false then
        local used = tonumber((safe(GetNumBagUsedSlots, 0, BAG_BACKPACK))) or 0
        local total = tonumber((safe(GetBagSize, 0, BAG_BACKPACK))) or 0
        if total > 0 then
            entries[#entries+1] = "|t16:16:EsoUI/Art/Inventory/inventory_tabIcon_items_up.dds|t " .. tostring(used) .. "/" .. tostring(total)
        end
    end

    for _,entry in ipairs(self:GetCurrencyEntries()) do entries[#entries+1] = entry end

    if EPC.saved and EPC.saved.edgeInfoBarStable029770 ~= false then
        entries[#entries+1] = "STABLE " .. stableText()
    end

    if EPC.saved and EPC.saved.edgeInfoBarPerformance029770 ~= false then
        entries[#entries+1] = performanceText()
    end
    return entries
end

function B:GetHorizontalEntries029776()
    local entries = {}

    if not EPC.saved or EPC.saved.edgeInfoBarClock029763 ~= false then
        local t = nowText()
        if t ~= "" then entries[#entries+1] = t end
    end

    if not EPC.saved or EPC.saved.edgeInfoBarBag029763 ~= false then
        local used = tonumber((safe(GetNumBagUsedSlots, 0, BAG_BACKPACK))) or 0
        local total = tonumber((safe(GetBagSize, 0, BAG_BACKPACK))) or 0
        if total > 0 then
            entries[#entries+1] = "|t16:16:EsoUI/Art/Inventory/inventory_tabIcon_items_up.dds|t " .. tostring(used) .. "/" .. tostring(total)
        end
    end

    for _,entry in ipairs(self:GetCurrencyEntries()) do
        entries[#entries+1] = entry
    end

    if EPC.saved and EPC.saved.edgeInfoBarStable029770 ~= false then
        entries[#entries+1] = "STABLE " .. stableText()
    end

    if EPC.saved and EPC.saved.edgeInfoBarPerformance029770 ~= false then
        local fpsText, pingText = performanceEntries()
        entries[#entries+1] = fpsText
        entries[#entries+1] = pingText
    end

    return entries
end

function B:EnsureSegmentLabels029776(count)
    self.segmentLabels029776 = self.segmentLabels029776 or {}
    for i = #self.segmentLabels029776 + 1, count do
        local label = WM:CreateControl(nil, self.frame, CT_LABEL)
        label:SetFont("ZoFontGameSmall")
        label:SetColor(0.92,0.92,0.92,1)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        self.segmentLabels029776[i] = label
    end
end

function B:LayoutHorizontalSegments029776(barHeight)
    local entries = self:GetHorizontalEntries029776()
    self:EnsureSegmentLabels029776(#entries)

    local count = #entries
    local screenW = tonumber(GuiRoot:GetWidth()) or 1920
    local padding = 6
    local usableW = math.max(1, screenW - (padding * 2))
    local slotW = count > 0 and (usableW / count) or usableW

    for i, label in ipairs(self.segmentLabels029776 or {}) do
        label:ClearAnchors()
        if i <= count then
            label:SetHidden(false)
            local x = padding + ((i - 1) * slotW)
            label:SetAnchor(TOPLEFT, self.frame, TOPLEFT, x, 0)
            label:SetDimensions(slotW, barHeight)
            if i == 1 then
                label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            elseif i == count then
                label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            else
                label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            end
            local text = tostring(entries[i] or "")
            if label.easLastText029776 ~= text then
                label.easLastText029776 = text
                label:SetText(text)
            end
        else
            label:SetHidden(true)
            label:SetText("")
            label.easLastText029776 = ""
        end
    end
end

function B:ApplyDock()
    self:Create()
    if not self.frame then return end
    local edge = tostring(EPC.saved and EPC.saved.edgeInfoBarEdge029763 or "TOP")
    local scale = tonumber(EPC.saved and EPC.saved.edgeInfoBarScale029763) or 1
    local alpha = tonumber(EPC.saved and EPC.saved.edgeInfoBarAlpha029763) or 0.94

    self.frame:SetScale(1)
    self.frame:SetAlpha(alpha)
    self.frame:ClearAnchors()

    local screenW = tonumber(GuiRoot:GetWidth()) or 1920
    local screenH = tonumber(GuiRoot:GetHeight()) or 1080
    local left = self.leftLabel029772
    local center = self.centerLabel029772
    local right = self.rightLabel029772

    for _,label in ipairs({left, center, right}) do
        if label then
            label:ClearAnchors()
            label:SetHidden(false)
            label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        end
    end

    if edge == "LEFT" or edge == "RIGHT" then
        self.frame:SetDimensions(math.max(140, math.floor(220 * scale + 0.5)), screenH)
        if edge == "LEFT" then
            self.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
        else
            self.frame:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, 0, 0)
        end

        -- Vertical docks use one full-height stacked label so every item uses
        -- the edge instead of being squeezed into horizontal columns.
        for _,segment in ipairs(self.segmentLabels029776 or {}) do segment:SetHidden(true) end
        if left then left:SetHidden(true) end
        if right then right:SetHidden(true) end
        if center then
            center:SetHidden(false)
            center:SetAnchor(TOPLEFT, self.frame, TOPLEFT, 10, 10)
            center:SetAnchor(BOTTOMRIGHT, self.frame, BOTTOMRIGHT, -10, -10)
            center:SetHorizontalAlignment(edge == "RIGHT" and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT)
            center:SetVerticalAlignment(TEXT_ALIGN_TOP)
        end
    else
        local barHeight = math.max(18, math.floor(28 * scale + 0.5))
        self.frame:SetDimensions(screenW, barHeight)
        if edge == "BOTTOM" then
            self.frame:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 0, 0)
        else
            self.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
        end

        -- Horizontal docks distribute every visible entry into an equal-width
        -- slot across the entire screen. Text length no longer bunches currencies
        -- together in the middle or leaves oversized empty gaps.
        if left then left:SetHidden(true) end
        if center then center:SetHidden(true) end
        if right then right:SetHidden(true) end
        self:LayoutHorizontalSegments029776(barHeight)
    end
end

function B:Refresh()
    self:Create()
    if not self.frame then return end
    local show = EPC.saved and EPC.saved.showEdgeInfoBar029763 == true
    if self.layoutMode029770 == true then
        show = true
    elseif show and EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then
        show = false
    end
    self.frame:SetHidden(not show)
    if not show then return end

    self:ApplyDock()
    local edge = tostring(EPC.saved and EPC.saved.edgeInfoBarEdge029763 or "TOP")
    local leftText, centerText, rightText = self:BuildSections029772()

    if edge == "LEFT" or edge == "RIGHT" then
        local verticalText = table.concat(self:BuildEntries(), "\n")
        if self.lastCenterText029772 ~= verticalText then
            self.lastCenterText029772 = verticalText
            self.centerLabel029772:SetText(verticalText)
        end
    else
        -- ApplyDock already laid out and refreshed the equal-width horizontal
        -- segment labels. Keep the legacy three labels hidden for compatibility.
        if self.leftLabel029772 then self.leftLabel029772:SetHidden(true) end
        if self.centerLabel029772 then self.centerLabel029772:SetHidden(true) end
        if self.rightLabel029772 then self.rightLabel029772:SetHidden(true) end
    end
end

function B:SetLayoutMode(active)
    self.layoutMode029770 = active == true
    self:Refresh()
end

function B:Initialize()
    self:Create()
    local prefix=(EPC.name or "EAS").."_EdgeInfoBar029763"
    local events={
        rawget(_G,"EVENT_PLAYER_ACTIVATED"),
        rawget(_G,"EVENT_CURRENCY_UPDATE"),
        rawget(_G,"EVENT_INVENTORY_FULL_UPDATE"),
        rawget(_G,"EVENT_INVENTORY_SINGLE_SLOT_UPDATE"),
    }
    for i,eventId in ipairs(events) do
        if eventId and EVENT_MANAGER then
            EPC.Runtime:RegisterEvent("EdgeInfoBar","Event"..tostring(i),eventId,function() B:Refresh() end)
        end
    end
    if EPC.Runtime then
        EPC.Runtime:RegisterUpdate("EdgeInfoBar","Clock",1000,function()
            if not EPC.saved then return end
            if EPC.saved.showEdgeInfoBar029763 == true or B.layoutMode029770 == true then
                B:Refresh()
            end
        end)
    end

    -- Scene transitions are the authoritative moment to hide/restore edge HUD.
    -- Refresh immediately and once after ESO finishes the scene transition so
    -- Inventory/Settings/Map closing cannot leave the bar stuck hidden.
    if EPC.HudVisibility then
        EPC.HudVisibility:Register("EdgeInfoBar", function() B:Refresh() end)
    end

    self:Refresh()
end

if EVENT_MANAGER and rawget(_G,"EVENT_ADD_ON_LOADED") then
    EVENT_MANAGER:RegisterForEvent((EPC.name or "EAS").."_EdgeInfoBarLoad029763",EVENT_ADD_ON_LOADED,function(_,addonName)
        if addonName ~= EPC.name then return end
        EVENT_MANAGER:UnregisterForEvent((EPC.name or "EAS").."_EdgeInfoBarLoad029763",EVENT_ADD_ON_LOADED)
        B:Initialize()
    end)
end
