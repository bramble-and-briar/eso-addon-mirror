-- The pop-ups in the middle of the screen:
--   * What's New: the add-on's name, version and highlights from ReleaseNotes.lua. It shows once, the first time a
--     player logs in after updating to a version listed there, then fades out after ten seconds. Release Notes in
--     the settings menu shows it again.
--   * Feedback: a QR code for the bug report and question form in Support.lua, shown from Feedback in the settings
--     menu for long enough to scan it with a phone.
-- They take no input: on console there is no pointer to close a window with, so they simply fade out.
--
-- Also the shared pieces of the Supporters part of the settings: the donation link and the thank-you line.

local addon = SlayansBossTimer
local Settings = addon.Settings
local Util = addon.Util

local Popup = {}
addon.Popup = Popup

local WHATS_NEW_SECONDS = 10 -- How long What's New stays on screen: long enough to read five highlights.
local FEEDBACK_SECONDS = 15 -- How long the Feedback QR code stays on screen: long enough to scan it with a phone.
local LOGIN_DELAY_MS = 2000 -- Waits for the loading screen to fade before showing What's New.
local FADE_MS = 500

local WHATS_NEW_WIDTH = 960 -- Wide enough for a typical highlight on one line.
local FEEDBACK_WIDTH = 640
local PADDING = 40
local QR_SIZE = 240
local QR_MARGIN = 16 -- White border round the QR code; phone cameras need it to find the code.
local SPACING = 14
local HEADING_SPACING = 24 -- Between "What's New?" and the first highlight.
local HIGHLIGHT_SPACING = 6
local BULLET_SIZE = 16
-- Wrapped lines of a highlight start under its text, not under the bullet: the bullet and the space after it.
local HIGHLIGHT_INDENT = BULLET_SIZE + 8

local TITLE_FONT = "$(GAMEPAD_BOLD_FONT)|$(GP_42)|soft-shadow-thick"
local HEADING_FONT = "$(GAMEPAD_BOLD_FONT)|$(GP_34)|soft-shadow-thick"
local BODY_FONT = "$(GAMEPAD_MEDIUM_FONT)|$(GP_27)|soft-shadow-thin"
local BULLET_ICON = "EsoUI/Art/Miscellaneous/Gamepad/gp_bullet.dds"
-- The thank-you ends with the gold favourite star of the game's gamepad lists (common/gamepad), in its own colour.
local THANKS_ICON = "EsoUI/Art/Collections/Favorite_StarOnly.dds"
local THANKS_ICON_SIZE = 28

local GREY = ZO_ColorDef:New("C5C5C5")

---------------------------------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------------------------------

-- Returns the release notes for a version from ReleaseNotes.lua, or nil if it has none.
function Popup.GetReleaseNotes(version)
    for _, notes in ipairs(addon.releaseNotes or {}) do
        if notes.version == version then
            return notes
        end
    end
    return nil
end

-- Returns this version's release notes, or the newest ones if this version has none.
function Popup.GetLatestReleaseNotes()
    return Popup.GetReleaseNotes(addon.version) or (addon.releaseNotes and addon.releaseNotes[1])
end

-- Returns "Thank you for your support!" followed by a gold star.
function Popup.FormatThanks()
    return string.format("%s %s", GetString(SI_SBT_THANK_YOU), zo_iconFormat(THANKS_ICON, THANKS_ICON_SIZE,
        THANKS_ICON_SIZE))
end

-- Returns a web address from Support.lua, or nil if it is empty.
local function GetSupportLink(key)
    local link = addon.support and addon.support[key]
    if type(link) == "string" and link ~= "" then
        return link
    end
    return nil
end

function Popup.GetDonationLink()
    return GetSupportLink("donationLink")
end

function Popup.GetFeedbackLink()
    return GetSupportLink("feedbackLink")
end

---------------------------------------------------------------------------------------------------
-- Windows
---------------------------------------------------------------------------------------------------

-- A pop-up is a top-level window with the game's gamepad backdrop and a column of rows, centred on the screen.
local function CreatePopup(name, width)
    local window = WINDOW_MANAGER:CreateTopLevelWindow(name)
    window:SetHidden(true)
    window:SetMouseEnabled(false)
    window:SetDrawTier(DT_HIGH)
    window:SetWidth(width)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(name .. "Backdrop", window, "ZO_DefaultBackdrop_Gamepad")
    backdrop:SetDrawLevel(0)

    local popup = { name = name, window = window, width = width, rows = {} }

    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local fade = timeline:InsertAnimation(ANIMATION_ALPHA, window, 0)
    fade:SetAlphaValues(1, 0)
    fade:SetDuration(FADE_MS)
    timeline:SetHandler("OnStop", function(_, completedPlaying)
        if completedPlaying then
            window:SetHidden(true)
            local onHidden = popup.onHidden
            popup.onHidden = nil
            if onHidden then
                onHidden()
            end
        end
    end)
    popup.fadeOut = timeline
    return popup
end

local function AddLabel(popup, key, font, spacing)
    local label = WINDOW_MANAGER:CreateControl(popup.name .. key, popup.window, CT_LABEL)
    label:SetFont(font)
    label:SetWidth(popup.width - 2 * PADDING)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(ZO_WHITE:UnpackRGBA())
    label:SetDrawLevel(2)
    table.insert(popup.rows, { control = label, isLabel = true, spacing = spacing })
    return label
end

-- Adds a row that isn't text, such as the QR code's white square; the layout uses its height.
local function AddBox(popup, control)
    table.insert(popup.rows, { control = control })
    return control
end

-- Stacks the visible rows from the top and sizes the window to fit them. This runs while the window is still hidden,
-- so it asks each row whether it is hidden itself (IsControlHidden); IsHidden would also count the hidden window and
-- skip every row, leaving them unanchored in the screen's top-left corner.
local function Layout(popup)
    local offsetY = PADDING
    local first = true
    for _, row in ipairs(popup.rows) do
        local control = row.control
        if not control:IsControlHidden() then
            if not first then
                offsetY = offsetY + (row.spacing or SPACING)
            end
            first = false
            control:ClearAnchors()
            control:SetAnchor(TOP, popup.window, TOP, 0, offsetY)
            local height = row.isLabel and control:GetTextHeight() or control:GetHeight()
            offsetY = offsetY + height
        end
    end
    popup.window:SetHeight(offsetY + PADDING)
end

-- Shows a pop-up for a number of seconds, then fades it out and calls onHidden.
local function ShowFor(popup, seconds, onHidden)
    popup.fadeOut:Stop()
    popup.showCount = (popup.showCount or 0) + 1
    local showCount = popup.showCount
    popup.onHidden = onHidden
    Layout(popup)
    popup.window:SetAlpha(1)
    popup.window:SetHidden(false)
    zo_callLater(function()
        -- A newer ShowFor has taken over this pop-up; its own timer will fade it.
        if popup.showCount == showCount then
            popup.fadeOut:PlayFromStart()
        end
    end, seconds * 1000)
end

-- Hides a pop-up at once, so two never cover each other. Its timer finds a newer showCount and does nothing.
local function HideNow(popup)
    if popup and not popup.window:IsControlHidden() then
        popup.showCount = (popup.showCount or 0) + 1
        popup.fadeOut:Stop()
        popup.window:SetHidden(true)
    end
end

local whatsNew, feedback

---------------------------------------------------------------------------------------------------
-- What's New
---------------------------------------------------------------------------------------------------

local function GetWhatsNew()
    if not whatsNew then
        whatsNew = CreatePopup("SlayansBossTimerWhatsNew", WHATS_NEW_WIDTH)
        whatsNew.title = AddLabel(whatsNew, "Title", TITLE_FONT)
        whatsNew.version = AddLabel(whatsNew, "Version", BODY_FONT)
        whatsNew.heading = AddLabel(whatsNew, "Heading", HEADING_FONT)
        whatsNew.version:SetColor(GREY:UnpackRGBA())
        whatsNew.highlights = {}
    end
    return whatsNew
end

-- Returns the label for the nth highlight, creating it the first time. Each highlight has its own label, so a long one
-- wraps with its second line indented under the text.
local function GetHighlightLabel(popup, index)
    local label = popup.highlights[index]
    if not label then
        label = AddLabel(popup, "Highlight" .. index, BODY_FONT, index == 1 and HEADING_SPACING or HIGHLIGHT_SPACING)
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        label:SetNewLineX(HIGHLIGHT_INDENT)
        popup.highlights[index] = label
    end
    return label
end

-- Returns the highlights as lines, each with a bullet.
function Popup.FormatHighlights(highlights)
    local lines = {}
    for _, highlight in ipairs(highlights or {}) do
        table.insert(lines, zo_iconTextFormat(BULLET_ICON, BULLET_SIZE, BULLET_SIZE, highlight))
    end
    return table.concat(lines, "\n")
end

-- Shows What's New for this version (or the newest notes there are). onHidden runs once it has faded out.
function Popup.ShowWhatsNew(onHidden)
    local notes = Popup.GetLatestReleaseNotes()
    if not notes then
        return false
    end
    local popup = GetWhatsNew()
    popup.title:SetText(Util.FallGradient(GetString(SI_SBT_POPUP_TITLE)))
    popup.version:SetText(zo_strformat(SI_SBT_POPUP_VERSION, notes.version))
    popup.heading:SetText(GetString(SI_SBT_POPUP_WHATS_NEW))
    local highlights = notes.highlights or {}
    for index, highlight in ipairs(highlights) do
        local label = GetHighlightLabel(popup, index)
        label:SetText(Popup.FormatHighlights({ highlight }))
        label:SetHidden(false)
    end
    for index = #highlights + 1, #popup.highlights do
        popup.highlights[index]:SetHidden(true)
    end
    HideNow(feedback)
    ShowFor(popup, WHATS_NEW_SECONDS, onHidden)
    return true
end

---------------------------------------------------------------------------------------------------
-- Feedback
---------------------------------------------------------------------------------------------------

local function GetFeedback()
    if not feedback then
        feedback = CreatePopup("SlayansBossTimerFeedback", FEEDBACK_WIDTH)
        feedback.title = AddLabel(feedback, "Title", HEADING_FONT)

        -- LibQRCode draws dark squares only, so the code sits on a white square.
        local qrBackground = WINDOW_MANAGER:CreateControl(feedback.name .. "QRBackground", feedback.window, CT_BACKDROP)
        qrBackground:SetDimensions(QR_SIZE + 2 * QR_MARGIN, QR_SIZE + 2 * QR_MARGIN)
        qrBackground:SetCenterColor(1, 1, 1, 1)
        qrBackground:SetEdgeColor(1, 1, 1, 0)
        qrBackground:SetDrawLevel(1)
        feedback.qrCode = WINDOW_MANAGER:CreateControl(feedback.name .. "QRCode", qrBackground, CT_TEXTURE)
        feedback.qrCode:SetDimensions(QR_SIZE, QR_SIZE)
        feedback.qrCode:SetAnchor(CENTER, qrBackground, CENTER, 0, 0)
        feedback.qrCode:SetDrawLevel(2)
        feedback.qrBackground = AddBox(feedback, qrBackground)

        feedback.caption = AddLabel(feedback, "Caption", BODY_FONT)
    end
    return feedback
end

-- Shows the QR code for the bug report and question form. LibQRCode is a required library; if it is somehow missing,
-- the web address is written out instead.
function Popup.ShowFeedback()
    local link = Popup.GetFeedbackLink()
    if not link then
        return false
    end
    local popup = GetFeedback()
    popup.title:SetText(Util.FallGradient(GetString(SI_SBT_POPUP_FEEDBACK_TITLE)))
    local hasQRCode = LibQRCode ~= nil and type(LibQRCode.DrawQRCode) == "function"
    popup.qrBackground:SetHidden(not hasQRCode)
    if hasQRCode then
        LibQRCode.DrawQRCode(popup.qrCode, link)
        popup.caption:SetText(GetString(SI_SBT_POPUP_FEEDBACK_SCAN))
    else
        popup.caption:SetText(link)
    end
    HideNow(whatsNew)
    ShowFor(popup, FEEDBACK_SECONDS)
    return true
end

---------------------------------------------------------------------------------------------------
-- After an update
---------------------------------------------------------------------------------------------------

-- Shows What's New if this is the first login since updating to a version with release notes.
-- Called once per session, when the player first arrives in the world.
function Popup.ShowAfterUpdate()
    if Settings.Get("lastSeenVersion") == addon.version then
        return
    end
    Settings.Set("lastSeenVersion", addon.version)
    if not Popup.GetReleaseNotes(addon.version) then
        return
    end
    zo_callLater(function()
        Popup.ShowWhatsNew()
    end, LOGIN_DELAY_MS)
end
