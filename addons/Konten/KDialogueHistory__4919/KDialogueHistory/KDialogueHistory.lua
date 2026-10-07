local ADDON = "KDialogueHistory"

local BG_ALPHA   = 0.85
local FADE_IN_H  = 40
local FADE_OUT_H = 100
local STRIP_H    = 4
local PAD_X      = 12
local PAD_TOP    = 10
local PAD_BOTTOM = 10
local BG_WIDTH   = 3000

local BAR_W      = 2
local BAR_OFFSET = 12
local BAR_UP     = 45
local BAR_COLOR  = { 0.80, 0.76, 0.62 }
local BAR_ALPHA  = 0.15

local MAX_VISIBLE   = 10
local SCROLL_STEP   = 1
local LINE_WIDTH    = 520
local SB_W          = 4
local SB_GAP        = 8
local SB_MIN_THUMB  = 14

local history = {}
local scrollOffset = 0
local header
local lines = {}
local stripsIn, stripsOut, solid = {}, {}, nil
local barSolid, barOut = nil, {}
local sbTrack, sbThumb

local Refresh

local function CreateStrip(name, alpha, prev)
    local s = WINDOW_MANAGER:CreateControl(name, ZO_InteractWindow, CT_TEXTURE)
    s:SetColor(0, 0, 0, alpha)
    s:SetDrawLayer(DL_BACKGROUND)
    s:SetWidth(BG_WIDTH)
    s:SetHeight(STRIP_H)
    if prev then
        s:SetAnchor(TOPLEFT, prev, BOTTOMLEFT, 0, 0)
    else
        s:SetAnchor(TOPLEFT, header, TOPLEFT, -PAD_X, -(PAD_TOP + FADE_IN_H))
    end
    s:SetHidden(true)
    return s
end

local function CreateBarPiece(name, alpha, prev, height)
    local b = WINDOW_MANAGER:CreateControl(name, ZO_InteractWindow, CT_TEXTURE)
    b:SetColor(BAR_COLOR[1], BAR_COLOR[2], BAR_COLOR[3], alpha)
    b:SetDrawLayer(DL_CONTROLS)
    b:SetWidth(BAR_W)
    b:SetHeight(height)
    if prev then
        b:SetAnchor(TOPLEFT, prev, BOTTOMLEFT, 0, 0)
    else
        b:SetAnchor(TOPLEFT, header, TOPLEFT, -BAR_OFFSET, -BAR_UP)
    end
    b:SetHidden(true)
    return b
end

local function CreateBackdrop()
    local prev
    local nIn  = math.floor(FADE_IN_H / STRIP_H)
    local nOut = math.floor(FADE_OUT_H / STRIP_H)

    for k = 1, nIn do
        prev = CreateStrip(ADDON .. "In" .. k, BG_ALPHA * (k / nIn), prev)
        stripsIn[#stripsIn + 1] = prev
    end

    solid = CreateStrip(ADDON .. "Solid", BG_ALPHA, prev)
    prev = solid

    for k = 1, nOut do
        prev = CreateStrip(ADDON .. "Out" .. k, BG_ALPHA * (1 - k / nOut), prev)
        stripsOut[#stripsOut + 1] = prev
    end

    barSolid = CreateBarPiece(ADDON .. "BarSolid", BAR_ALPHA, nil, 10)
    local bprev = barSolid
    for k = 1, nOut do
        bprev = CreateBarPiece(ADDON .. "BarOut" .. k, BAR_ALPHA * (1 - k / nOut), bprev, STRIP_H)
        barOut[#barOut + 1] = bprev
    end
end

local function SetBackdropHidden(hidden)
    for _, s in ipairs(stripsIn)  do s:SetHidden(hidden) end
    for _, s in ipairs(stripsOut) do s:SetHidden(hidden) end
    for _, b in ipairs(barOut)    do b:SetHidden(hidden) end
    solid:SetHidden(hidden)
    barSolid:SetHidden(hidden)
end

local function MaxOffset()
    return math.max(0, #history - MAX_VISIBLE)
end

local function OnMouseWheel(_, delta)
    if #history <= MAX_VISIBLE then return end
    local new = scrollOffset - delta * SCROLL_STEP
    new = math.max(0, math.min(MaxOffset(), new))
    if new ~= scrollOffset then
        scrollOffset = new
        Refresh()
    end
end

local function GetLine(i)
    if lines[i] then return lines[i] end

    local line = WINDOW_MANAGER:CreateControl(ADDON .. "Line" .. i, ZO_InteractWindow, CT_LABEL)
    line:SetFont("ZoFontGame")
    line:SetColor(0.78, 0.78, 0.63, 1)
    line:SetWidth(LINE_WIDTH)
    line:SetMaxLineCount(1)
    line:SetMouseEnabled(true)
    line.entryIndex = nil

    line:SetHandler("OnMouseEnter", function(self)
        local entry = self.entryIndex and history[self.entryIndex]
        if not entry then return end
        self:SetColor(1, 1, 1, 1)
        InitializeTooltip(InformationTooltip, self, LEFT, 15, 0, RIGHT)
        if entry.npc and entry.npc ~= "" then
            InformationTooltip:AddLine(entry.npc, "ZoFontHeader2", 1, 1, 1)
        end
        if entry.body and entry.body ~= "" then
            InformationTooltip:AddLine(entry.body, "ZoFontGame", 0.9, 0.9, 0.8)
        end
    end)

    line:SetHandler("OnMouseExit", function(self)
        self:SetColor(0.78, 0.78, 0.63, 1)
        ClearTooltip(InformationTooltip)
    end)

    line:SetHandler("OnMouseWheel", OnMouseWheel)

    if i == 1 then
        line:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 4)
    else
        line:SetAnchor(TOPLEFT, GetLine(i - 1), BOTTOMLEFT, 0, 2)
    end

    lines[i] = line
    return line
end

local function UpdateScrollbar(listHeight)
    local count = #history
    if count <= MAX_VISIBLE then
        sbTrack:SetHidden(true)
        sbThumb:SetHidden(true)
        return
    end

    sbTrack:SetHidden(false)
    sbThumb:SetHidden(false)
    sbTrack:SetHeight(listHeight)

    local thumbH = math.max(SB_MIN_THUMB, listHeight * (MAX_VISIBLE / count))
    local free   = listHeight - thumbH
    local y      = free * (scrollOffset / MaxOffset())

    sbThumb:SetHeight(thumbH)
    sbThumb:ClearAnchors()
    sbThumb:SetAnchor(TOPLEFT, sbTrack, TOPLEFT, 0, y)
end

Refresh = function()
    local count = #history
    header:SetHidden(count == 0)
    SetBackdropHidden(count == 0)

    scrollOffset = math.max(0, math.min(MaxOffset(), scrollOffset))

    if count > MAX_VISIBLE then
        header:SetText(string.format("Previous choices (%d-%d / %d):",
            scrollOffset + 1, scrollOffset + MAX_VISIBLE, count))
    else
        header:SetText("Previous choices:")
    end

    local headerH = header:GetTextHeight() + 4
    local listHeight = 0

    for slot = 1, math.max(MAX_VISIBLE, #lines) do
        local idx = scrollOffset + slot
        local entry = (slot <= MAX_VISIBLE) and history[idx] or nil
        if entry then
            local line = GetLine(slot)
            line.entryIndex = idx
            line:SetText("> " .. entry.choice)
            line:SetHidden(false)
            listHeight = listHeight + line:GetTextHeight() + 2
        elseif lines[slot] then
            lines[slot].entryIndex = nil
            lines[slot]:SetHidden(true)
        end
    end

    UpdateScrollbar(listHeight)

    if count > 0 then
        local contentHeight = headerH + listHeight
        solid:SetHeight(contentHeight + PAD_TOP + PAD_BOTTOM)
        barSolid:SetHeight(contentHeight + BAR_UP + PAD_BOTTOM)
    end
end

local function SafeGetText(control)
    if control and control.GetText then
        return control:GetText() or ""
    end
    return ""
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    header = WINDOW_MANAGER:CreateControl(ADDON .. "Header", ZO_InteractWindow, CT_LABEL)
    header:SetFont("ZoFontGame")
    header:SetColor(0.62, 0.62, 0.48, 1)
    header:SetText("Previous choices:")
    header:SetAnchor(TOPLEFT, ZO_InteractWindowPlayerAreaOptions, BOTTOMLEFT, 0, 25)
    header:SetMouseEnabled(true)
    header:SetHandler("OnMouseWheel", OnMouseWheel)
    header:SetHidden(true)

    CreateBackdrop()

    sbTrack = WINDOW_MANAGER:CreateControl(ADDON .. "SBTrack", ZO_InteractWindow, CT_TEXTURE)
    sbTrack:SetColor(1, 1, 1, 0.08)
    sbTrack:SetDrawLayer(DL_CONTROLS)
    sbTrack:SetWidth(SB_W)
    sbTrack:SetHeight(10)
    sbTrack:SetAnchor(TOPLEFT, header, BOTTOMLEFT, LINE_WIDTH + SB_GAP, 4)
    sbTrack:SetHidden(true)

    sbThumb = WINDOW_MANAGER:CreateControl(ADDON .. "SBThumb", ZO_InteractWindow, CT_TEXTURE)
    sbThumb:SetColor(BAR_COLOR[1], BAR_COLOR[2], BAR_COLOR[3], 0.6)
    sbThumb:SetDrawLayer(DL_CONTROLS)
    sbThumb:SetWidth(SB_W)
    sbThumb:SetHeight(SB_MIN_THUMB)
    sbThumb:SetAnchor(TOPLEFT, sbTrack, TOPLEFT, 0, 0)
    sbThumb:SetHidden(true)

    ZO_PreHook("SelectChatterOption", function(index)
        local text, optionType = GetChatterOption(index)
        if text and text ~= "" and optionType ~= CHATTER_GOODBYE then
            history[#history + 1] = {
                choice = text,
                npc  = SafeGetText(ZO_InteractWindowTargetAreaTitle),
                body = SafeGetText(ZO_InteractWindowTargetAreaBodyText),
            }
            scrollOffset = MaxOffset()
            Refresh()
        end
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_CHATTER_END, function()
        history = {}
        scrollOffset = 0
        ClearTooltip(InformationTooltip)
        Refresh()
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnAddOnLoaded)