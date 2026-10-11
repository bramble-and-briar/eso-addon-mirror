local BA = BuildAdvisor
-- Popups: a native gamepad dialog (closes on Circle), with PullCard's timed card as the
-- fallback when the dialog can't be shown. Both are created in Lua (no XML on console).
BA.Popup = {}
local Popup = BA.Popup

-- Explicit sizes so the card stays readable on console (TV distance).
local FONT_TITLE = "$(GAMEPAD_BOLD_FONT)|32|soft-shadow-thick"
-- Body sizes tried in order until the card fits on screen.
local BODY_SIZES = { 25, 22, 20 }
local function BodyFont(size)
    return "$(GAMEPAD_MEDIUM_FONT)|" .. size .. "|soft-shadow-thick"
end
local CARD_WIDTH = 960
local CARD_PADDING = 18
local SECTION_GAP = 12
local MAX_SCREEN_SHARE = 0.9
local TEXT_WIDTH = CARD_WIDTH - 2 * CARD_PADDING

-- Text height is estimated from the text itself (GetTextHeight reports a single line on
-- console). Factors calibrated in-game for PullCard: ~0.35 x font size per character
-- (0.40 errs toward extra space), line height ~1.3 x font size.
local CHAR_WIDTH_FACTOR = 0.40
local LINE_HEIGHT_FACTOR = 1.3

-- Long cards stay up long enough to read: ~3.5 words a second at TV distance.
-- The popup display time setting is the minimum; capped so nothing lingers forever.
local READING_WORDS_PER_SECOND = 3.5
local MAX_DISPLAY_SECONDS = 60
local COUNTDOWN_NAME = "BuildAdvisorPopupCountdown"

local function EstimateTextHeight(text, size)
    if not text or text == "" then return 0 end
    local charsPerLine = math.max(1, math.floor(TEXT_WIDTH / (size * CHAR_WIDTH_FACTOR)))
    local lines = 0
    for paragraph in (text .. "\n"):gmatch("(.-)\n") do
        lines = lines + math.max(1, math.ceil(#paragraph / charsPerLine))
    end
    return math.ceil(lines * size * LINE_HEIGHT_FACTOR)
end

function Popup:Create()
    local wm = WINDOW_MANAGER

    local top = wm:CreateTopLevelWindow("BuildAdvisorPopup")
    self.window = top
    top:SetDimensions(CARD_WIDTH, 400)
    top:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    top:SetClampedToScreen(true)
    top:SetHidden(true)

    local bg = wm:CreateControl(nil, top, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0.05, 0.05, 0.05, 0.94)
    bg:SetEdgeColor(0.5, 0.5, 0.5, 0.9)
    bg:SetEdgeTexture("", 1, 1, 1)

    local timer = wm:CreateControl(nil, top, CT_LABEL)
    self.timer = timer
    timer:SetFont(FONT_TITLE)
    timer:SetColor(0.8, 0.8, 0.8, 1)
    timer:SetDimensions(70, 40)
    timer:SetAnchor(TOPRIGHT, top, TOPRIGHT, -CARD_PADDING, CARD_PADDING)
    timer:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    local title = wm:CreateControl(nil, top, CT_LABEL)
    self.title = title
    title:SetFont(FONT_TITLE)
    title:SetAnchor(TOPLEFT, top, TOPLEFT, CARD_PADDING, CARD_PADDING)
    title:SetAnchor(TOPRIGHT, timer, TOPLEFT, -10, 0)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    local body = wm:CreateControl(nil, top, CT_LABEL)
    self.body = body
    body:SetFont(BodyFont(BODY_SIZES[1]))
    -- Starts with a real height (a label with no height draws as one unwrapped line);
    -- Layout resizes it.
    body:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, SECTION_GAP)
    body:SetAnchor(TOPRIGHT, timer, BOTTOMRIGHT, 0, SECTION_GAP)
    body:SetHeight(250)
    body:SetVerticalAlignment(TEXT_ALIGN_TOP)
end

-- Fits the card's height to its text, shrinking the body font if needed so it never
-- runs off screen. Uses our own copy of the text: reading it back from a label isn't
-- reliable on console.
function Popup:Layout()
    local maxHeight = GuiRoot:GetHeight() * MAX_SCREEN_SHARE
    local titleH = math.ceil(32 * LINE_HEIGHT_FACTOR)

    local total, bodyH
    for _, size in ipairs(BODY_SIZES) do
        bodyH = math.max(EstimateTextHeight(self.bodyText, size), math.ceil(size * LINE_HEIGHT_FACTOR))
        total = CARD_PADDING + titleH + SECTION_GAP + bodyH + CARD_PADDING
        self.body:SetFont(BodyFont(size))
        if total <= maxHeight then break end
    end

    -- Still too tall at the smallest font: the body gives up the overflow.
    if total > maxHeight then
        bodyH = math.max(bodyH - (total - maxHeight), 0)
        total = maxHeight
    end

    self.body:SetHeight(bodyH)
    self.window:SetHeight(total)
end

function Popup:GetDisplaySeconds()
    local words = 0
    for _ in self.bodyText:gmatch("%S+") do words = words + 1 end
    local readingSeconds = math.ceil(words / READING_WORDS_PER_SECOND)
    local minimum = BA.saved and BA.saved.popupSeconds or BA.defaults.popupSeconds
    return math.min(math.max(minimum, readingSeconds), MAX_DISPLAY_SECONDS)
end

function Popup:UpdateCountdown()
    local remainingMs = self.closeAtMs - GetFrameTimeMilliseconds()
    if remainingMs <= 0 then
        self:Hide()
        return
    end
    self.timer:SetText(string.format("%ds", math.ceil(remainingMs / 1000)))
end

-- Native gamepad dialog (UNTESTED on console). The game's own dialog system owns its input,
-- so Circle closes it without us capturing buttons. Pushing the UIShortcuts layer plus a
-- KEYBIND_STRIP group was tried first and Circle did nothing.
-- Dialog templates ship with the game, so this needs no XML: we only register a data table.
local DIALOG_NAME = "BUILDADVISOR_INFO"
local dialogRegistered = false

local function RegisterDialog()
    if dialogRegistered then return true end
    if not (ZO_Dialogs_RegisterCustomDialog and ZO_Dialogs_ShowGamepadDialog and GAMEPAD_DIALOGS) then
        return false
    end
    ZO_Dialogs_RegisterCustomDialog(DIALOG_NAME, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = "<<1>>" },
        mainText = { text = "<<1>>" },
        buttons = {
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CLOSE or "Close", callback = function() end },
        },
    })
    dialogRegistered = true
    return true
end

-- Shows the dialog; falls back to the timed card if the dialog can't be shown.
function Popup:Show(title, body)
    title = title or "Build Advisor"
    body = body or ""
    if RegisterDialog() then
        ZO_Dialogs_ReleaseDialog(DIALOG_NAME)
        local ok = pcall(ZO_Dialogs_ShowGamepadDialog, DIALOG_NAME, nil, { titleParams = { title }, mainTextParams = { body } })
        if ok then return end
    end
    self:ShowCard(title, body)
end

function Popup:ShowCard(title, body)
    if not self.window then self:Create() end
    self.title:SetText(title)
    self.bodyText = body
    self.body:SetText(self.bodyText)
    self:Layout()
    self.window:SetHidden(false)

    self.closeAtMs = GetFrameTimeMilliseconds() + self:GetDisplaySeconds() * 1000
    EVENT_MANAGER:UnregisterForUpdate(COUNTDOWN_NAME)
    EVENT_MANAGER:RegisterForUpdate(COUNTDOWN_NAME, 200, function() Popup:UpdateCountdown() end)
    self:UpdateCountdown()
end

function Popup:Hide()
    if dialogRegistered then ZO_Dialogs_ReleaseDialog(DIALOG_NAME) end
    EVENT_MANAGER:UnregisterForUpdate(COUNTDOWN_NAME)
    if self.window then self.window:SetHidden(true) end
end
