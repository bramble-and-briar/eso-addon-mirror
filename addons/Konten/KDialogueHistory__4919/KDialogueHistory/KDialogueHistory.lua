local ADDON = "KDialogueHistory"
local ADDON_VERSION = "1.0.0"

--------------------------------------------------------------------------------
-- Saved variables
--------------------------------------------------------------------------------

local defaults = {
    subtitles = {
        chatEnabled  = true,
        hideOnScreen = true,
        showSpeaker  = true,
        speakerColor = "FFD966",
        textColor    = "FFFFFF",
    },
    history = {
        enabled    = true,
        maxVisible = 10,
        bgAlpha    = 0.85,
        lineWidth  = 520,
    },
}

local sv

local function Print(msg)
    CHAT_ROUTER:AddSystemMessage(msg)
end

local function HexToRGB(hex)
    return ZO_ColorDef:New(hex):UnpackRGB()
end

local function RGBToHex(r, g, b)
    return ZO_ColorDef:New(r, g, b):ToHex()
end

--------------------------------------------------------------------------------
-- Part 1: NPC subtitles -> chat
--------------------------------------------------------------------------------

local lastSpeaker, lastText, lastTime = nil, nil, 0
local DUPLICATE_WINDOW_SECONDS = 2

local function FormatSubtitle(speakerName, text)
    local s = sv.subtitles
    local formattedText = zo_strformat("<<1>>", text)
    if s.showSpeaker and speakerName and speakerName ~= "" then
        local formattedSpeaker = zo_strformat("<<1>>", speakerName)
        return string.format("|c%s%s:|r |c%s%s|r", s.speakerColor, formattedSpeaker, s.textColor, formattedText)
    end
    return string.format("|c%s%s|r", s.textColor, formattedText)
end

-- EVENT_SHOW_SUBTITLE is the same event the base game's ZO_SubtitleManager
-- listens to in order to display the text at the center of the screen.
local function OnShowSubtitle(_, channelType, speakerName, text)
    if not sv.subtitles.chatEnabled then return end
    if not text or text == "" then return end

    local now = GetFrameTimeSeconds()
    if speakerName == lastSpeaker and text == lastText and (now - lastTime) < DUPLICATE_WINDOW_SECONDS then
        return
    end
    lastSpeaker, lastText, lastTime = speakerName, text, now

    Print(FormatSubtitle(speakerName, text))
end

-- Stops the base game from drawing the subtitle at the center of the screen.
-- A pre-hook that returns true skips the original function; the chat handler above is separate.
local onScreenHooked = false
local function TryHookOnScreenSubtitles()
    if onScreenHooked or not ZO_SUBTITLE_MANAGER then return end
    onScreenHooked = true
    ZO_PreHook(ZO_SUBTITLE_MANAGER, "OnShowSubtitle", function()
        return sv.subtitles.hideOnScreen
    end)
end

--------------------------------------------------------------------------------
-- Part 2: Previous dialogue choices (window shown under the NPC options)
--------------------------------------------------------------------------------

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

local SCROLL_STEP   = 1
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
    local bgAlpha = sv.history.bgAlpha

    for k = 1, nIn do
        prev = CreateStrip(ADDON .. "In" .. k, bgAlpha * (k / nIn), prev)
        stripsIn[#stripsIn + 1] = prev
    end

    solid = CreateStrip(ADDON .. "Solid", bgAlpha, prev)
    prev = solid

    for k = 1, nOut do
        prev = CreateStrip(ADDON .. "Out" .. k, bgAlpha * (1 - k / nOut), prev)
        stripsOut[#stripsOut + 1] = prev
    end

    barSolid = CreateBarPiece(ADDON .. "BarSolid", BAR_ALPHA, nil, 10)
    local bprev = barSolid
    for k = 1, nOut do
        bprev = CreateBarPiece(ADDON .. "BarOut" .. k, BAR_ALPHA * (1 - k / nOut), bprev, STRIP_H)
        barOut[#barOut + 1] = bprev
    end
end

-- Re-applies the configured background opacity (used when the slider changes)
local function ApplyBackdropAlpha()
    if not solid then return end
    local a = sv.history.bgAlpha
    local nIn, nOut = #stripsIn, #stripsOut
    for k, s in ipairs(stripsIn) do s:SetColor(0, 0, 0, a * (k / nIn)) end
    solid:SetColor(0, 0, 0, a)
    for k, s in ipairs(stripsOut) do s:SetColor(0, 0, 0, a * (1 - k / nOut)) end
end

-- Re-applies the configured line width (used when the slider changes)
local function ApplyLineWidth()
    if not sbTrack then return end
    local w = sv.history.lineWidth
    for _, l in ipairs(lines) do l:SetWidth(w) end
    sbTrack:ClearAnchors()
    sbTrack:SetAnchor(TOPLEFT, header, BOTTOMLEFT, w + SB_GAP, 4)
end

local function SetBackdropHidden(hidden)
    for _, s in ipairs(stripsIn)  do s:SetHidden(hidden) end
    for _, s in ipairs(stripsOut) do s:SetHidden(hidden) end
    for _, b in ipairs(barOut)    do b:SetHidden(hidden) end
    solid:SetHidden(hidden)
    barSolid:SetHidden(hidden)
end

local function MaxOffset()
    return math.max(0, #history - sv.history.maxVisible)
end

local function OnMouseWheel(_, delta)
    if #history <= sv.history.maxVisible then return end
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
    line:SetWidth(sv.history.lineWidth)
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
    local maxVisible = sv.history.maxVisible
    if count <= maxVisible then
        sbTrack:SetHidden(true)
        sbThumb:SetHidden(true)
        return
    end

    sbTrack:SetHidden(false)
    sbThumb:SetHidden(false)
    sbTrack:SetHeight(listHeight)

    local thumbH = math.max(SB_MIN_THUMB, listHeight * (maxVisible / count))
    local free   = listHeight - thumbH
    local y      = free * (scrollOffset / MaxOffset())

    sbThumb:SetHeight(thumbH)
    sbThumb:ClearAnchors()
    sbThumb:SetAnchor(TOPLEFT, sbTrack, TOPLEFT, 0, y)
end

Refresh = function()
    if not header then return end

    local count = #history
    local maxVisible = sv.history.maxVisible
    header:SetHidden(count == 0)
    SetBackdropHidden(count == 0)

    scrollOffset = math.max(0, math.min(MaxOffset(), scrollOffset))

    if count > maxVisible then
        header:SetText(string.format("Previous choices (%d-%d / %d):",
            scrollOffset + 1, scrollOffset + maxVisible, count))
    else
        header:SetText("Previous choices:")
    end

    local headerH = header:GetTextHeight() + 4
    local listHeight = 0

    for slot = 1, math.max(maxVisible, #lines) do
        local idx = scrollOffset + slot
        local entry = (slot <= maxVisible) and history[idx] or nil
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

local function ClearHistory()
    history = {}
    scrollOffset = 0
    ClearTooltip(InformationTooltip)
    Refresh()
end

local function InitializeHistoryUI()
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
    sbTrack:SetAnchor(TOPLEFT, header, BOTTOMLEFT, sv.history.lineWidth + SB_GAP, 4)
    sbTrack:SetHidden(true)

    sbThumb = WINDOW_MANAGER:CreateControl(ADDON .. "SBThumb", ZO_InteractWindow, CT_TEXTURE)
    sbThumb:SetColor(BAR_COLOR[1], BAR_COLOR[2], BAR_COLOR[3], 0.6)
    sbThumb:SetDrawLayer(DL_CONTROLS)
    sbThumb:SetWidth(SB_W)
    sbThumb:SetHeight(SB_MIN_THUMB)
    sbThumb:SetAnchor(TOPLEFT, sbTrack, TOPLEFT, 0, 0)
    sbThumb:SetHidden(true)

    ZO_PreHook("SelectChatterOption", function(index)
        if not sv.history.enabled then return end
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

    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_CHATTER_END, ClearHistory)
end

--------------------------------------------------------------------------------
-- LibAddonMenu-2.0 settings (optional dependency)
--------------------------------------------------------------------------------

local panel

local function BuildSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = ADDON .. "Panel"
    panel = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = ADDON,
        displayName = ADDON,
        author = "Kan",
        version = ADDON_VERSION,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local d = defaults
    local function ColorDefault(hex)
        local r, g, b = HexToRGB(hex)
        return { r = r, g = g, b = b, a = 1 }
    end

    local options = {
        -- Subtitles ------------------------------------------------------------
        { type = "header", name = "NPC subtitles" },
        {
            type = "checkbox",
            name = "Copy subtitles to chat",
            tooltip = "Copies what NPCs say (the text shown at the middle of the screen) into the chat window.",
            getFunc = function() return sv.subtitles.chatEnabled end,
            setFunc = function(v) sv.subtitles.chatEnabled = v end,
            default = d.subtitles.chatEnabled,
        },
        {
            type = "checkbox",
            name = "Hide on-screen subtitles",
            tooltip = "Hides the subtitle text the game shows at the middle of the screen. The chat copy is not affected.",
            getFunc = function() return sv.subtitles.hideOnScreen end,
            setFunc = function(v) sv.subtitles.hideOnScreen = v end,
            default = d.subtitles.hideOnScreen,
        },
        {
            type = "checkbox",
            name = "Show speaker name",
            getFunc = function() return sv.subtitles.showSpeaker end,
            setFunc = function(v) sv.subtitles.showSpeaker = v end,
            disabled = function() return not sv.subtitles.chatEnabled end,
            default = d.subtitles.showSpeaker,
        },
        {
            type = "colorpicker",
            name = "Speaker name color",
            getFunc = function() local r, g, b = HexToRGB(sv.subtitles.speakerColor) return r, g, b, 1 end,
            setFunc = function(r, g, b) sv.subtitles.speakerColor = RGBToHex(r, g, b) end,
            disabled = function() return not (sv.subtitles.chatEnabled and sv.subtitles.showSpeaker) end,
            default = ColorDefault(d.subtitles.speakerColor),
        },
        {
            type = "colorpicker",
            name = "Subtitle text color",
            getFunc = function() local r, g, b = HexToRGB(sv.subtitles.textColor) return r, g, b, 1 end,
            setFunc = function(r, g, b) sv.subtitles.textColor = RGBToHex(r, g, b) end,
            disabled = function() return not sv.subtitles.chatEnabled end,
            default = ColorDefault(d.subtitles.textColor),
        },
        {
            type = "button",
            name = "Print test line",
            tooltip = "Prints a sample subtitle in chat using the current colors.",
            func = function() Print(FormatSubtitle("Test NPC", "This is a sample subtitle line.")) end,
            width = "half",
        },

        -- Dialogue history -----------------------------------------------------
        { type = "header", name = "Previous dialogue choices" },
        {
            type = "checkbox",
            name = "Show previous choices",
            tooltip = "Keeps the options you already picked visible below the NPC dialogue options.",
            getFunc = function() return sv.history.enabled end,
            setFunc = function(v)
                sv.history.enabled = v
                if not v then ClearHistory() end
            end,
            default = d.history.enabled,
        },
        {
            type = "slider",
            name = "Visible entries",
            tooltip = "How many previous choices are shown before the list becomes scrollable.",
            min = 3, max = 20, step = 1,
            getFunc = function() return sv.history.maxVisible end,
            setFunc = function(v) sv.history.maxVisible = v Refresh() end,
            disabled = function() return not sv.history.enabled end,
            default = d.history.maxVisible,
        },
        {
            type = "slider",
            name = "Line width",
            min = 300, max = 900, step = 10,
            getFunc = function() return sv.history.lineWidth end,
            setFunc = function(v) sv.history.lineWidth = v ApplyLineWidth() Refresh() end,
            disabled = function() return not sv.history.enabled end,
            default = d.history.lineWidth,
        },
        {
            type = "slider",
            name = "Background opacity",
            min = 0, max = 1, step = 0.05, decimals = 2,
            getFunc = function() return sv.history.bgAlpha end,
            setFunc = function(v) sv.history.bgAlpha = v ApplyBackdropAlpha() end,
            disabled = function() return not sv.history.enabled end,
            default = d.history.bgAlpha,
        },
    }

    LAM:RegisterOptionControls(panelName, options)
end

--------------------------------------------------------------------------------
-- Slash command (works with or without LibAddonMenu)
--------------------------------------------------------------------------------

local function OnSlashCommand(args)
    args = (args or ""):lower()
    local s = sv.subtitles
    if args == "hide" then
        s.hideOnScreen = not s.hideOnScreen
        Print(string.format("[%s] Hide on-screen subtitles: %s", ADDON, s.hideOnScreen and "ON" or "OFF"))
    elseif args == "speaker" then
        s.showSpeaker = not s.showSpeaker
        Print(string.format("[%s] Speaker name: %s", ADDON, s.showSpeaker and "ON" or "OFF"))
    elseif args == "history" then
        sv.history.enabled = not sv.history.enabled
        if not sv.history.enabled then ClearHistory() end
        Print(string.format("[%s] Previous choices: %s", ADDON, sv.history.enabled and "ON" or "OFF"))
    elseif args == "menu" or args == "settings" then
        if panel and LibAddonMenu2 then
            LibAddonMenu2:OpenToPanel(panel)
        else
            Print(string.format("[%s] LibAddonMenu-2.0 is not installed.", ADDON))
        end
    elseif args == "on" or args == "off" then
        s.chatEnabled = (args == "on")
        Print(string.format("[%s] Subtitles in chat: %s", ADDON, s.chatEnabled and "ON" or "OFF"))
    else
        s.chatEnabled = not s.chatEnabled
        Print(string.format("[%s] Subtitles in chat: %s  (/knpc on | off | speaker | hide | history | menu)",
            ADDON, s.chatEnabled and "ON" or "OFF"))
    end
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

local function OnAddOnLoaded(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("KDialogueHistorySV", 1, nil, defaults)

    -- subtitles
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_SHOW_SUBTITLE, OnShowSubtitle)
    TryHookOnScreenSubtitles()
    -- fallback in case the subtitle manager did not exist yet when addons loaded
    EVENT_MANAGER:RegisterForEvent(ADDON .. "Activated", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(ADDON .. "Activated", EVENT_PLAYER_ACTIVATED)
        TryHookOnScreenSubtitles()
    end)

    -- dialogue history
    InitializeHistoryUI()

    BuildSettingsMenu()

    SLASH_COMMANDS["/knpc"] = OnSlashCommand
    SLASH_COMMANDS["/knpcsub"] = OnSlashCommand
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
