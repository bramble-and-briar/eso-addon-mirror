-- The settings menu, for the console interface only (consoles, and the console simulation on PC): built directly with
-- LibHarvensAddonSettings (LHAS), the library behind the main menu's Addons entry. The PC keyboard interface gets no
-- menu; the add-on is made for consoles. The main list has these rows:
--   Supporters        opens a page: the QR code box, the supporters (one "GT: gamertag" line each), the thank-you
--   Timer Settings    opens a page: the timer's settings, Countdown Position (which opens a page of its own, with
--                     where the countdown sits and the two sliders for Custom), and Reset Boss Timers
--   Release Notes     shows the What's New pop-up (only while ReleaseNotes.lua lists a version)
--   Feedback          shows the bug report form's QR code in a pop-up
-- In LHAS an ST_SECTION row opens a page holding the rows after it, up to the next section, and other rows are
-- buttons. LHAS draws the two kinds differently (see "The main list" below), so all the main rows are buttons drawn
-- by this file, and the three pages are sections that draw no row of their own. LHAS rows can't hold a picture, so the
-- QR code box is drawn by this file under the menu's header, and shown only while the Supporters page is open (LHAS
-- rebuilds its list in AddonSettings:CreateControls each time a page opens or closes; see its Settings.lua). Each row
-- starts with an icon, written into its text.

local addon = SlayansBossTimer
local Settings = addon.Settings
local Popup = addon.Popup
local Util = addon.Util
local Timers = addon.Timers
local Countdown = addon.Countdown

local Menu = {}
addon.Menu = Menu

local QR_SIZE = 200
local QR_MARGIN = 12 -- White border round the code; phone cameras need it to find the code.

-- The icon at the start of each row. All are used by the game's shared or gamepad UI code, so they exist on console.
Menu.ICON = {
    supporters = "EsoUI/Art/Collections/Favorite_StarOnly.dds",
    settings = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_settings.dds",
    releaseNotes = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_journal.dds",
    feedback = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_help.dds",
    countdown = "EsoUI/Art/Miscellaneous/Gamepad/gp_icon_timer32.dds", -- Gamepad smithing research.
    fontSize = "EsoUI/Art/Options/Gamepad/gp_options_video.dds", -- The screen, from the gamepad settings' Video page.
    position = "EsoUI/Art/Buttons/Gamepad/gp_trackingPin.dds", -- Gamepad timed activities.
    alert = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_notifications.dds",
    chat = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_textChat.dds",
}
local ICON = Menu.ICON
-- Icons drawn in their own colours. The others take the colour of the row's text, as the game's menus do.
local KEEPS_ITS_COLOUR = {
    [ICON.supporters] = true, -- The gold star.
}
-- Icon sizes are a share of the text's height, so each icon is slightly bigger than the text beside it whatever the
-- font. The star fills only about half of its picture, so it is drawn bigger to match the others.
local ICON_SIZE = "120%"
local ICON_SIZE_FOR = {
    [ICON.supporters] = "160%",
}

-- The on/off settings on the Timer Settings page, in menu order: saved setting (with its default in
-- Settings.DEFAULTS), label, the description when on and when off, and icon. Font Size and the Countdown Position
-- button follow Show Countdown, and Reset Boss Timers comes last.
Menu.SETTINGS = {
    { "showCountdown", SI_SBT_MENU_SHOW_COUNTDOWN, SI_SBT_MENU_SHOW_COUNTDOWN_ON, SI_SBT_MENU_SHOW_COUNTDOWN_OFF,
        ICON.countdown },
    { "showAlert", SI_SBT_MENU_SHOW_ALERT, SI_SBT_MENU_SHOW_ALERT_ON, SI_SBT_MENU_SHOW_ALERT_OFF, ICON.alert },
    { "showChat", SI_SBT_MENU_SHOW_CHAT, SI_SBT_MENU_SHOW_CHAT_ON, SI_SBT_MENU_SHOW_CHAT_OFF, ICON.chat },
}

-- Returns a row's text with its icon in front.
local function WithIcon(icon, text)
    local size = ICON_SIZE_FOR[icon] or ICON_SIZE
    return zo_iconTextFormat(icon, size, size, text, not KEEPS_ITS_COLOUR[icon], true)
end

local function Label(icon, stringId)
    return WithIcon(icon, GetString(stringId))
end

-- Returns a setting's description for its current value.
local function SettingDescription(setting)
    return GetString(Settings.Get(setting[1]) and setting[3] or setting[4])
end

-- Returns one "GT: gamertag" line per supporter, or "Be the first!" while there are none.
local function SupporterLines()
    local supporters = addon.support and addon.support.supporters or {}
    local lines = {}
    for _, gamertag in ipairs(supporters) do
        table.insert(lines, zo_strformat(SI_SBT_GAMERTAG, gamertag))
    end
    if #lines == 0 then
        table.insert(lines, GetString(SI_SBT_MENU_SUPPORTERS_NONE))
    end
    return lines
end

local function ShowReleaseNotes()
    Popup.ShowWhatsNew()
end

local function ShowFeedback()
    Popup.ShowFeedback()
end

---------------------------------------------------------------------------------------------------
-- The QR code box on the Supporters page
---------------------------------------------------------------------------------------------------

local BOX_WIDTH = ZO_GAMEPAD_CONTENT_WIDTH
local BOX_TITLE_FONT = "$(GAMEPAD_BOLD_FONT)|$(GP_27)|soft-shadow-thick"
local BOX_BODY_FONT = "$(GAMEPAD_MEDIUM_FONT)|$(GP_22)|soft-shadow-thin"
local BOX_SPACING = 8
-- The box sits between the header's "By:" line and the first supporter row, centred, at least this far from each.
-- The QR code shrinks to fit that space (in Can Craft Master Writ 1.0.1 the full size didn't fit, and the row covered
-- the code), in whole tens, so a row that moves a little doesn't redraw it each time, but never below the smallest size.
local BOX_GAP = 12
local MIN_QR_SIZE = 120
local QR_SIZE_STEP = 10
local BOX_BOTTOM_GAP = 24 -- Between the box and the first row, if the header can't be found.
local WATCH_NAME = "SlayansBossTimerSupportBox"
local WATCH_INTERVAL_MS = 100

-- The settings objects LHAS made for our pages and rows, set when the menu is built: the three pages, the button on
-- the Timer Settings page that opens the Countdown Position page, and the first supporter row (boxRow), which the box
-- shows with; it is nil without a donation link.
local supportSection, settingsSection, positionSection, positionButton, boxRow
local supportBox, watching, supportBoxHooked

local function AddBoxLabel(box, key, font, anchorTo)
    local label = WINDOW_MANAGER:CreateControl(box:GetName() .. key, box, CT_LABEL)
    label:SetFont(font)
    label:SetWidth(BOX_WIDTH)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(ZO_WHITE:UnpackRGBA())
    label:SetAnchor(TOP, anchorTo, anchorTo == box and TOP or BOTTOM, 0, anchorTo == box and 0 or BOX_SPACING)
    return label
end

-- The QR code box: title, the code on a white square and "Scan With Your Phone to Donate". The thank-you is the row
-- under the supporters. LibQRCode.DrawQRCode needs a texture control; it paints it white and draws the code on top.
local function GetSupportBox()
    if supportBox then
        return supportBox
    end
    local box = WINDOW_MANAGER:CreateControl("SlayansBossTimerMenuSupportBox", GuiRoot, CT_CONTROL)
    box:SetHidden(true)
    box:SetWidth(BOX_WIDTH)
    box:SetResizeToFitDescendents(true)
    box.title = AddBoxLabel(box, "Title", BOX_TITLE_FONT, box)
    box.title:SetText(Util.FallGradient(GetString(SI_SBT_POPUP_SUPPORT_TITLE)))
    local background = WINDOW_MANAGER:CreateControl(box:GetName() .. "QRBackground", box, CT_BACKDROP)
    background:SetAnchor(TOP, box.title, BOTTOM, 0, BOX_SPACING)
    background:SetCenterColor(1, 1, 1, 1)
    background:SetEdgeColor(1, 1, 1, 0)
    box.qrBackground = background
    box.qrCode = WINDOW_MANAGER:CreateControl(box:GetName() .. "QRCode", background, CT_TEXTURE)
    box.qrCode:SetAnchor(CENTER, background, CENTER, 0, 0)
    box.caption = AddBoxLabel(box, "Caption", BOX_BODY_FONT, background)
    box.caption:SetText(GetString(SI_SBT_POPUP_SUPPORT_SCAN))
    supportBox = box
    return box
end

-- Draws the box's QR code at a size, on its white square. LibQRCode works out the code's squares from the texture's
-- size when it draws, so a new size means drawing the code again.
local function SetQRCodeSize(box, size)
    if box.qrSize == size then
        return
    end
    box.qrSize = size
    box.qrBackground:SetDimensions(size + 2 * QR_MARGIN, size + 2 * QR_MARGIN)
    box.qrCode:SetDimensions(size, size)
    if LibQRCode then
        LibQRCode.DrawQRCode(box.qrCode, Popup.GetDonationLink())
    end
end

-- Returns the box's height with a QR code of the given size.
local function GetBoxHeight(box, qrSize)
    return box.title:GetTextHeight() + BOX_SPACING + qrSize + 2 * QR_MARGIN + BOX_SPACING + box.caption:GetTextHeight()
end

-- Returns the biggest QR code size that leaves the box BOX_GAP from the header and the row, and the gap above the
-- box that centres it, or nil if the two aren't laid out yet.
local function FitSupportBox(box, message, row)
    local messageBottom, rowTop = message:GetBottom(), row:GetTop()
    if type(messageBottom) ~= "number" or type(rowTop) ~= "number" or rowTop <= messageBottom then
        return nil
    end
    local space = rowTop - messageBottom
    local qrSize = zo_floor((space - 2 * BOX_GAP - GetBoxHeight(box, 0)) / QR_SIZE_STEP) * QR_SIZE_STEP
    qrSize = zo_clamp(qrSize, MIN_QR_SIZE, QR_SIZE)
    return qrSize, zo_max(0, zo_floor((space - GetBoxHeight(box, qrSize)) / 2))
end

-- The header line under the add-on's name and version ("By: xSuperSlayan"), from the game's gamepad header.
local function GetHeaderMessage()
    local scrollList = LibHarvensAddonSettings.scrollList
    local header = scrollList and scrollList.header
    return header and header:GetNamedChild("Message") or nil
end

-- Anchors the box once, or again when the place changes.
local function AnchorSupportBox(parent, point, relativeTo, relativePoint, offsetY)
    if supportBox.anchoredTo == relativeTo and supportBox.anchorOffset == offsetY then
        return
    end
    supportBox:ClearAnchors()
    supportBox:SetParent(parent)
    supportBox:SetAnchor(point, relativeTo, relativePoint, 0, offsetY)
    supportBox.anchoredTo, supportBox.anchorOffset = relativeTo, offsetY
end

-- Shows the box while the Support page is open, and hides it otherwise. The list keeps its selected row about halfway
-- down the screen, and the first supporter row is selected on this page, so the space above it is free: the box goes
-- there, between the header and that row, with the QR code sized to fit. Runs whenever LHAS rebuilds its list and,
-- while the settings are on screen, every tenth of a second, since list rows are pooled controls that can change as
-- the list moves.
local function UpdateSupportBox()
    if not supportBox then
        return
    end
    local list = LibHarvensAddonSettings.list
    local row = boxRow and boxRow.control
    local onSupportPage = Menu.panel and Menu.panel.selected and list and list.currentSection == supportSection
    if not onSupportPage or not row or row:IsHidden() then
        supportBox:SetHidden(true)
        return
    end
    local message = GetHeaderMessage()
    if message then
        local qrSize, offsetY = FitSupportBox(supportBox, message, row)
        if not qrSize then
            supportBox:SetHidden(true)
            return
        end
        SetQRCodeSize(supportBox, qrSize)
        AnchorSupportBox(message:GetOwningWindow(), TOP, message, BOTTOM, offsetY)
    else
        SetQRCodeSize(supportBox, QR_SIZE)
        AnchorSupportBox(row:GetParent(), BOTTOM, row, TOP, -BOX_BOTTOM_GAP)
    end
    supportBox:SetHidden(false)
end

local function StopWatching()
    watching = false
    EVENT_MANAGER:UnregisterForUpdate(WATCH_NAME)
    if supportBox then
        supportBox:SetHidden(true)
    end
end

local function StartWatching()
    if not watching then
        watching = true
        EVENT_MANAGER:RegisterForUpdate(WATCH_NAME, WATCH_INTERVAL_MS, UpdateSupportBox)
    end
end

-- Hooks LHAS so the box appears with the Support page. LHAS creates its scene the first time the main menu opens, so
-- the scene callback is added the first time a page is built.
local function HookSupportBox(LHAS)
    if supportBoxHooked then
        return
    end
    supportBoxHooked = true
    local sceneHooked = false
    ZO_PostHook(LHAS.AddonSettings, "CreateControls", function(addonSettings)
        if not sceneHooked and LHAS.scene then
            sceneHooked = true
            LHAS.scene:RegisterCallback("StateChange", function(_, newState)
                if newState == SCENE_SHOWN then
                    StartWatching()
                elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                    StopWatching()
                end
            end)
        end
        if addonSettings == Menu.panel then
            StartWatching()
        end
        UpdateSupportBox()
    end)
end

-- LHAS draws the selected row's description in the side panel only when the selection changes, so after a setting is
-- switched (or reset) the panel is drawn again with the description for its new value, the way LHAS draws it.
local function RefreshSidePanel()
    local list = LibHarvensAddonSettings.list
    local data = list and list.GetSelectedData and list:GetSelectedData()
    if data and type(data.tooltipText) == "function" and GAMEPAD_TOOLTIPS then
        GAMEPAD_TOOLTIPS:LayoutSettingTooltip(GAMEPAD_LEFT_TOOLTIP, data:tooltipText(), "")
    end
end

---------------------------------------------------------------------------------------------------
-- The main list
---------------------------------------------------------------------------------------------------

-- LHAS draws a page row (ST_SECTION) left-aligned and always white, with an arrow, and a button centred and grey until
-- selected, with an empty row needed between the two kinds; with icons the rows didn't line up. So the main rows are
-- LHAS buttons that this file adds to LHAS's list itself, with one of the game's own list row templates
-- (common/gamepad/zo_gamepadtemplatescommon.xml): left-aligned, in a bigger font than LHAS's rows, grey until selected
-- and white when selected, as the game's menus do. LHAS still handles everything else: selecting a row runs its
-- clickHandler, and the side panel shows its tooltip. If LHAS's list ever lacks what this needs, the rows fall back to
-- LHAS's own buttons.
local MAIN_ROW_TEMPLATE = "ZO_GamepadFullWidthLeftLabelEntryTemplate"
local MAIN_ROW_POOL = "SlayansBossTimerMenuRow"
local MAIN_ROW_FONT = "ZoFontGamepad42" -- LHAS's rows use ZoFontGamepad34.

local function DrawMainRow(control, setting, selected)
    local label = control.label or control:GetNamedChild("Label")
    if not label then
        return
    end
    label:SetFont(MAIN_ROW_FONT)
    label:SetText(setting:GetString(setting:GetValueOrCallback(setting.labelText)))
    label:SetColor(ZO_GamepadMenuEntryTemplate_GetLabelColor(selected, setting:IsDisabled()):UnpackRGB())
end

-- The list's setup function: runs when the row is drawn and whenever the selection moves to or from it.
local function SetUpMainRow(control, setting, selected)
    setting.control = control
    control.data = setting
    DrawMainRow(control, setting, selected)
end

local function ResetMainRow(control)
    if control.data then
        control.data.control = nil
        control.data = nil
    end
end

-- Replaces a main row's CreateControl, which LHAS calls for each row of the page it is building.
local function AddMainRow(setting)
    local list = LibHarvensAddonSettings.list
    if not (list and list.HasDataTemplate and list.AddDataTemplate and list.AddEntry) then
        setting.UpdateControl = nil
        return LibHarvensAddonSettings.AddonSettingsControl.CreateControl(setting)
    end
    if not list:HasDataTemplate(MAIN_ROW_TEMPLATE) then
        list:AddDataTemplate(MAIN_ROW_TEMPLATE, SetUpMainRow, ZO_GamepadMenuEntryTemplateParametricListFunction, nil,
            MAIN_ROW_POOL, ResetMainRow)
    end
    list:AddEntry(MAIN_ROW_TEMPLATE, setting)
end

-- Replaces a main row's UpdateControl: LHAS's own expects its button template.
local function UpdateMainRow(setting)
    local control = setting.control
    if control then
        local list = LibHarvensAddonSettings.list
        DrawMainRow(control, setting, list and list.GetSelectedControl and list:GetSelectedControl() == control)
    end
end

local function DrawNothing()
end

---------------------------------------------------------------------------------------------------
-- The rows on the Timer Settings and Countdown Position pages
---------------------------------------------------------------------------------------------------

-- The on/off rows are LHAS's checkbox rows, the game's ZO_GamepadOptionsCheckboxRow
-- (pregameandingame/zo_options/gamepad/zo_options_gamepad.xml): the name centred in ZoFontGamepad34, with ON and OFF
-- centred under it. Ours are drawn smaller, with the name from the left and ON and OFF at the right end of the same
-- line (the owner's choice for Can Craft Master Writ). The row's GetHeight, which the list spaces rows by, then counts
-- the name's line only. The drop-downs (Font Size, Countdown Position) are the game's ZO_GamepadHorizontalListRow
-- (common/gamepad/zo_gamepadtemplatescommon.xml), with the value and its arrows on a line under the name; ours show
-- only the value, between the game's left and right arrows, at the right end of the name's line where ON and OFF go
-- (the owner's choice, 18 October 2026). The game's list of values stays there unseen (alpha 0, not hidden, since the
-- game's directional input skips hidden controls), so left and right still change the value. The other rows (the
-- sliders, the buttons) get the same smaller name from the left, and the button that opens the Countdown Position page
-- gets an arrow at its right end. LHAS calls SetEnabled on each row as its list draws it, so that is where ours are
-- restyled. The row controls are pooled and shared with every other add-on's LHAS settings, so each restyled row gets
-- its own look back before LHAS builds any page.
local ROW_NAME_FONT = "ZoFontGamepad27" -- The size of ON and OFF beside it.
local CHECKBOX_ON_OFF_GAP = 16
-- The game's arrow on rows that open a page, at the game's size (ZO_GamepadMenuEntryTemplateWithArrow in
-- ingame/mainmenu/gamepad/zo_mainmenu_gamepad.xml, which LHAS's own page rows use).
local PAGE_ARROW = "EsoUI/Art/Buttons/Gamepad/gp_menu_rightArrow.dds"
local PAGE_ARROW_SIZE = 32
-- The arrows either side of a drop-down's value, as the game's list of values has them
-- (ZO_GamepadHorizontalListTemplate in common/gamepad/zo_gamepadtemplatescommon.xml): one texture pointing right,
-- mirrored for the left.
local VALUE_ARROW = "EsoUI/Art/Buttons/Gamepad/gp_spinnerLR.dds"
local VALUE_ARROW_WIDTH, VALUE_ARROW_HEIGHT = 24, 48
local VALUE_ARROW_GAP = 4

-- Restyled row controls, each with what it looked like before.
local restyledRows = {}
-- The arrow made for each pooled row control that has opened a page, shown only while it does.
local arrows = {}
local arrowCount = 0
-- The value label made for each pooled drop-down row control, shown only while it draws one of ours.
local values = {}
local valueCount = 0

-- A control's anchors (it can have two), to put back later.
local function SaveAnchors(control)
    local anchors = {}
    for index = 0, 1 do
        local isValid, point, relativeTo, relativePoint, offsetX, offsetY = control:GetAnchor(index)
        if isValid then
            table.insert(anchors, { point, relativeTo, relativePoint, offsetX, offsetY })
        end
    end
    return anchors
end

local function RestoreAnchors(control, anchors)
    if not anchors or #anchors == 0 then
        return
    end
    control:ClearAnchors()
    for _, anchor in ipairs(anchors) do
        control:SetAnchor(unpack(anchor))
    end
end

local function GetArrow(control)
    local arrow = arrows[control]
    if not arrow then
        arrowCount = arrowCount + 1
        arrow = WINDOW_MANAGER:CreateControl("SlayansBossTimerMenuArrow" .. arrowCount, control, CT_TEXTURE)
        arrow:SetTexture(PAGE_ARROW)
        arrow:SetDimensions(PAGE_ARROW_SIZE, PAGE_ARROW_SIZE)
        arrows[control] = arrow
    end
    return arrow
end

-- A drop-down's value, in the same font and case as ON and OFF (ZO_GamepadOptionsCheckboxRow).
local function GetValueLabel(control)
    local value = values[control]
    if not value then
        valueCount = valueCount + 1
        local name = "SlayansBossTimerMenuValue" .. valueCount
        value = WINDOW_MANAGER:CreateControl(name, control, CT_LABEL)
        value:SetFont(ROW_NAME_FONT)
        value:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
        value.leftArrow = WINDOW_MANAGER:CreateControl(name .. "LeftArrow", control, CT_TEXTURE)
        value.rightArrow = WINDOW_MANAGER:CreateControl(name .. "RightArrow", control, CT_TEXTURE)
        for _, arrow in ipairs({ value.leftArrow, value.rightArrow }) do
            arrow:SetTexture(VALUE_ARROW)
            arrow:SetDimensions(VALUE_ARROW_WIDTH, VALUE_ARROW_HEIGHT)
        end
        value.leftArrow:SetTextureCoords(1, 0, 0, 1)
        value.rightArrow:SetTextureCoords(0, 1, 0, 1)
        values[control] = value
    end
    return value
end

local function SetValueHidden(value, hidden)
    value:SetHidden(hidden)
    value.leftArrow:SetHidden(hidden)
    value.rightArrow:SetHidden(hidden)
end

-- Shows a drop-down's new value as soon as it changes.
local function ShowRowValue(control, text)
    if control and values[control] and text then
        values[control]:SetText(text)
    end
end

-- Restyles a row as LHAS draws it: with the arrow if it opens a page, and with its value if it is a drop-down. A
-- pooled row can be drawn again for another row of the page, so the arrow and value are shown or hidden each time.
local function RestyleRow(control, opensPage, valueText)
    local name, on, off = control:GetNamedChild("Name"), control:GetNamedChild("On"), control:GetNamedChild("Off")
    local list = control:GetNamedChild("HorizontalList")
    if not name then
        return
    end
    if not restyledRows[control] then
        restyledRows[control] = {
            font = name:GetFont(),
            alignment = name:GetHorizontalAlignment(),
            onAnchors = on and SaveAnchors(on),
            offAnchors = off and SaveAnchors(off),
            listAlpha = list and list:GetAlpha(),
            getHeight = control.GetHeight,
        }
    end
    name:SetFont(ROW_NAME_FONT)
    name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    if on and off then
        -- The name spans the row, so its right end is the row's.
        off:ClearAnchors()
        off:SetAnchor(RIGHT, name, RIGHT, 0, 0)
        on:ClearAnchors()
        on:SetAnchor(RIGHT, off, LEFT, -CHECKBOX_ON_OFF_GAP, 0)
        control.GetHeight = function()
            return zo_max(name:GetTextHeight(), on:GetTextHeight())
        end
    end
    if opensPage then
        local arrow = GetArrow(control)
        arrow:ClearAnchors()
        arrow:SetAnchor(RIGHT, name, RIGHT, 0, 0)
        arrow:SetHidden(false)
    elseif arrows[control] then
        arrows[control]:SetHidden(true)
    end
    if valueText and list then
        list:SetAlpha(0)
        local value = GetValueLabel(control)
        value.rightArrow:ClearAnchors()
        value.rightArrow:SetAnchor(RIGHT, name, RIGHT, 0, 0)
        value:ClearAnchors()
        value:SetAnchor(RIGHT, value.rightArrow, LEFT, -VALUE_ARROW_GAP, 0)
        value.leftArrow:ClearAnchors()
        value.leftArrow:SetAnchor(RIGHT, value, LEFT, -VALUE_ARROW_GAP, 0)
        value:SetText(valueText)
        SetValueHidden(value, false)
        control.GetHeight = function()
            return zo_max(name:GetTextHeight(), value:GetTextHeight())
        end
    elseif values[control] then
        SetValueHidden(values[control], true)
    end
end

local function RestoreRestyledRows()
    for control, original in pairs(restyledRows) do
        local name = control:GetNamedChild("Name")
        if original.font and original.font ~= "" then
            name:SetFont(original.font)
        end
        if original.alignment then
            name:SetHorizontalAlignment(original.alignment)
        end
        if original.onAnchors then
            RestoreAnchors(control:GetNamedChild("On"), original.onAnchors)
        end
        if original.offAnchors then
            RestoreAnchors(control:GetNamedChild("Off"), original.offAnchors)
        end
        if original.listAlpha then
            control:GetNamedChild("HorizontalList"):SetAlpha(original.listAlpha)
        end
        control.GetHeight = original.getHeight
        if arrows[control] then
            arrows[control]:SetHidden(true)
        end
        if values[control] then
            SetValueHidden(values[control], true)
        end
    end
    ZO_ClearTable(restyledRows)
end

-- Replaces the SetEnabled of each row on the pages, which LHAS's list calls each time it draws the row.
local function SetTimerRowEnabled(setting, enabled, ...)
    local control = setting.control
    local opensPage = setting == positionButton
    local item = setting.type == LibHarvensAddonSettings.ST_DROPDOWN and setting.getFunction()
    if control then
        RestyleRow(control, opensPage, item and item.name)
    end
    LibHarvensAddonSettings.AddonSettingsControl.SetEnabled(setting, enabled, ...)
    -- The arrow takes the colour LHAS has just given the name: grey until selected, darker while greyed out.
    local name = control and control:GetNamedChild("Name")
    if opensPage and name and arrows[control] then
        arrows[control]:SetColor(name:GetColor())
    end
    -- The value is coloured like ON when it's chosen, and like OFF when it isn't while the row is greyed out. Its
    -- arrows take the name's colour, like the page arrow.
    local value = item and values[control]
    if value then
        local color = enabled and ZO_DEFAULT_ENABLED_COLOR or ZO_DEFAULT_DISABLED_COLOR
        value:SetColor(color:UnpackRGB())
        value.leftArrow:SetColor(name:GetColor())
        value.rightArrow:SetColor(name:GetColor())
    end
end

local timerRowsHooked = false
local function HookTimerRows(LHAS)
    if not timerRowsHooked then
        timerRowsHooked = true
        ZO_PreHook(LHAS.AddonSettings, "CreateControls", RestoreRestyledRows)
    end
end

---------------------------------------------------------------------------------------------------
-- Placing the countdown
---------------------------------------------------------------------------------------------------

local function IsCountdownOff()
    return not Settings.Get("showCountdown")
end

local function FindItem(items, key)
    for _, item in ipairs(items) do
        if item.data == key then
            return item
        end
    end
end

-- A drop-down row for one of the countdown's saved choices: one item per key, each with its name, made once, since
-- LHAS finds the chosen item by identity. A saved key it doesn't know shows as the default. It is greyed out while the
-- countdown is off.
local function AddChoiceRow(LHAS, options, key, icon, labelId, tooltipId, keys, names)
    local items = {}
    for _, itemKey in ipairs(keys) do
        table.insert(items, { name = GetString(names[itemKey]), data = itemKey })
    end
    local function ItemFor(value)
        return FindItem(items, value) or FindItem(items, Settings.DEFAULTS[key])
    end
    table.insert(options, {
        type = LHAS.ST_DROPDOWN,
        label = Label(icon, labelId),
        tooltip = GetString(tooltipId),
        items = items,
        default = ItemFor(Settings.DEFAULTS[key]).name,
        getFunction = function()
            return ItemFor(Settings.Get(key))
        end,
        setFunction = function(control, _, item)
            Settings.Set(key, item and item.data or Settings.DEFAULTS[key])
            ShowRowValue(control, item and item.name)
            Countdown.Refresh()
        end,
        disable = IsCountdownOff,
    })
end

local function IsCustomOff()
    return IsCountdownOff() or Countdown.GetPosition() ~= "free"
end

-- A console has no pointer to drag the countdown with, so for Custom two sliders place it: left and right on the D-pad
-- move it, and it moves on screen as they change (the owner's choice, 15 October 2026; a "Move Countdown" mode with
-- the left stick may come later).
local function AddPositionSlider(LHAS, options, key, stringId, tooltipId)
    table.insert(options, {
        type = LHAS.ST_SLIDER,
        label = Label(ICON.position, stringId),
        tooltip = GetString(tooltipId),
        min = 0,
        max = 100,
        step = 1,
        format = "%d",
        default = Settings.DEFAULTS[key],
        getFunction = function()
            return Settings.Get(key)
        end,
        setFunction = function(value)
            Settings.Set(key, value)
            Countdown.Refresh()
        end,
        disable = IsCustomOff,
    })
end

-- The Countdown Position page's rows: where the countdown sits, then the two sliders for Custom. They are greyed out
-- while the countdown is off, and the sliders unless it goes where the player puts it.
local function AddPositionRows(LHAS, options)
    AddChoiceRow(LHAS, options, "countdownPosition", ICON.position, SI_SBT_MENU_POSITION, SI_SBT_MENU_POSITION_TOOLTIP,
        Countdown.POSITIONS, Countdown.POSITION_NAMES)
    AddPositionSlider(LHAS, options, "countdownX", SI_SBT_MENU_POSITION_X, SI_SBT_MENU_POSITION_X_TOOLTIP)
    AddPositionSlider(LHAS, options, "countdownY", SI_SBT_MENU_POSITION_Y, SI_SBT_MENU_POSITION_Y_TOOLTIP)
end

-- While the Timer Settings or Countdown Position page is open, the countdown shows where it will be, so players can
-- place it. LHAS rebuilds its list whenever a page opens or closes (AddonSettings:CreateControls), and its scene hides
-- when the menu closes.
local function UpdateCountdownPreview()
    local list = LibHarvensAddonSettings.list
    local page = list and list.currentSection
    Countdown.SetPreview(Menu.panel ~= nil and Menu.panel.selected and page ~= nil
        and (page == settingsSection or page == positionSection))
end

local previewHooked = false
local function HookCountdownPreview(LHAS)
    if previewHooked then
        return
    end
    previewHooked = true
    local sceneHooked = false
    ZO_PostHook(LHAS.AddonSettings, "CreateControls", function()
        if not sceneHooked and LHAS.scene then
            sceneHooked = true
            LHAS.scene:RegisterCallback("StateChange", function(_, newState)
                if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                    Countdown.SetPreview(false)
                end
            end)
        end
        UpdateCountdownPreview()
    end)
end

---------------------------------------------------------------------------------------------------
-- The add-on's name in the Addons list
---------------------------------------------------------------------------------------------------

-- LHAS reads a name like "Slayan's Boss Timer" as an author and a name, and its Addons list and header show only
-- "Boss Timer" (CreateAddonSettingsPanel in its Settings.lua, which builds the list the first time the main menu
-- opens). This puts the full name back in both and sorts the list again, keeping the version and author lines.
local function FindAddonsEntry()
    if type(ZO_MENU_ENTRIES) ~= "table" then
        return nil
    end
    for _, entry in ipairs(ZO_MENU_ENTRIES) do
        if entry.id == "LibHarvensAddonSettings" and type(entry.subMenu) == "table" then
            return entry
        end
    end
end

function Menu.RestoreFullName(LHAS)
    local addonsEntry, panel = FindAddonsEntry(), Menu.panel
    if not addonsEntry or not panel then
        return
    end
    local fullName = GetString(SI_SBT_MENU_NAME)
    for _, entry in ipairs(addonsEntry.subMenu) do
        local data = entry.data
        if data and data.addon == panel and data.name ~= fullName then
            data.name = fullName
            entry:SetText(fullName)
            local activated = data.activatedCallback
            data.activatedCallback = function(...)
                activated(...)
                if LHAS.scrollList and LHAS.scrollList.header then
                    ZO_GamepadGenericHeader_RefreshData(LHAS.scrollList.header, {
                        titleText = fullName,
                        subtitleText = panel.version,
                        messageText = panel.author and zo_strformat(GetString(SI_ADD_ON_AUTHOR_LINE), panel.author),
                    })
                end
            end
        end
    end
    table.sort(addonsEntry.subMenu, function(a, b)
        return tostring(a.text) < tostring(b.text)
    end)
end

local nameHooked = false
local function HookFullName(LHAS)
    if not nameHooked then
        nameHooked = true
        ZO_PostHook(LHAS, "CreateAddonSettingsPanel", function()
            Menu.RestoreFullName(LHAS)
        end)
    end
    -- In case the list was already built.
    Menu.RestoreFullName(LHAS)
end

---------------------------------------------------------------------------------------------------
-- Building the menu
---------------------------------------------------------------------------------------------------

-- Opens a page the way LHAS's own page rows do (their Activate in its Settings.lua), with the given row selected, if
-- any, the way LHAS selects a row again (AddonSettings:RefreshSelection). Returns whether it could.
local function OpenPage(section, selectedRow)
    local scrollList = LibHarvensAddonSettings.scrollList
    local list = scrollList and scrollList.GetList and scrollList:GetList("Section")
    if not list or not Menu.panel then
        return false
    end
    list.currentSection = section
    scrollList:SetCurrentList(list)
    Menu.panel:CreateControls()
    -- The pages share one list, which keeps the row number selected on the page before (the Countdown Position
    -- button's would select Top to Bottom), so the page opens on the given row, or else on its first, as LHAS does.
    Menu.panel.lastSelectedRow = selectedRow
    Menu.panel:RefreshSelection()
    return true
end

-- LHAS's pages go one level deep: a section's page holds the rows after it, up to the next section, and Back from any
-- page returns to the main list (its GoBack, which the menu's Back button calls). So the Countdown Position page is a
-- third section, after the Timer Settings page's rows, and a button on that page opens it (the owner's choice, 18
-- October 2026: the place and its two sliders on a page of their own). Back from it returns to Timer Settings, with
-- that button selected.
local backHooked = false
local function HookBack(LHAS)
    if backHooked then
        return
    end
    backHooked = true
    ZO_PreHook(LHAS, "GoBack", function()
        local list = LibHarvensAddonSettings.list
        if positionSection and list and list.currentSection == positionSection
            and OpenPage(settingsSection, positionButton) then
            PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
            return true
        end
    end)
end

local function BuildConsoleMenu(LHAS)
    local panel = LHAS:AddAddon(GetString(SI_SBT_MENU_NAME), { allowDefaults = true, allowRefresh = true })
    if not panel then
        return
    end
    panel.author = addon.author
    panel.version = addon.version

    -- The main list. Rows before the first page belong to it.
    local options = {}
    local mainRows = {}
    local function AddButton(icon, stringId, tooltip, clickHandler)
        table.insert(options, {
            type = LHAS.ST_BUTTON,
            label = Label(icon, stringId),
            tooltip = tooltip,
            clickHandler = clickHandler,
        })
        table.insert(mainRows, #options)
    end
    AddButton(ICON.supporters, SI_SBT_MENU_SUPPORT, nil, function()
        OpenPage(supportSection)
    end)
    AddButton(ICON.settings, SI_SBT_MENU_SETTINGS, nil, function()
        OpenPage(settingsSection)
    end)
    if Popup.GetLatestReleaseNotes() then
        AddButton(ICON.releaseNotes, SI_SBT_MENU_RELEASE_NOTES, GetString(SI_SBT_MENU_RELEASE_NOTES_TOOLTIP),
            ShowReleaseNotes)
    end
    if Popup.GetFeedbackLink() then
        AddButton(ICON.feedback, SI_SBT_MENU_FEEDBACK, GetString(SI_SBT_MENU_FEEDBACK_TOOLTIP), ShowFeedback)
    end

    -- The Supporters page.
    local hasQRCode = Popup.GetDonationLink() ~= nil
    local supportIndex = #options + 1
    table.insert(options, { type = LHAS.ST_SECTION, label = Label(ICON.supporters, SI_SBT_MENU_SUPPORT) })
    if not hasQRCode then
        table.insert(options, { type = LHAS.ST_LABEL, label = GetString(SI_SBT_MENU_DONATE_NOT_SET), canSelect = false })
    end
    -- The first supporter row is the only one that can be selected, so it is selected when the page opens and its
    -- tooltip (the support message) shows in the side panel.
    local firstRowIndex = #options + 1
    for index, line in ipairs(SupporterLines()) do
        table.insert(options, {
            type = LHAS.ST_LABEL,
            label = line,
            tooltip = index == 1 and GetString(SI_SBT_MENU_DONATE_TOOLTIP) or nil,
            canSelect = index == 1,
        })
    end
    table.insert(options, { type = LHAS.ST_LABEL, label = Popup.FormatThanks(), canSelect = false })

    -- The Timer Settings page: the on/off settings, with Font Size and the Countdown Position button after Show
    -- Countdown, and Reset Boss Timers.
    local settingsIndex = #options + 1
    local buttonIndex
    table.insert(options, { type = LHAS.ST_SECTION, label = Label(ICON.settings, SI_SBT_MENU_SETTINGS) })
    for _, setting in ipairs(Menu.SETTINGS) do
        local key = setting[1]
        table.insert(options, {
            type = LHAS.ST_CHECKBOX,
            label = Label(setting[5], setting[2]),
            tooltip = function()
                return SettingDescription(setting)
            end,
            default = Settings.DEFAULTS[key],
            getFunction = function()
                return Settings.Get(key)
            end,
            setFunction = function(value)
                Settings.Set(key, value)
                RefreshSidePanel()
                Countdown.Refresh()
            end,
        })
        if key == "showCountdown" then
            AddChoiceRow(LHAS, options, "fontSize", ICON.fontSize, SI_SBT_MENU_FONT_SIZE, SI_SBT_MENU_FONT_SIZE_TOOLTIP,
                Countdown.FONT_SIZES, Countdown.FONT_SIZE_NAMES)
            table.insert(options, {
                type = LHAS.ST_BUTTON,
                label = Label(ICON.position, SI_SBT_MENU_POSITION),
                tooltip = GetString(SI_SBT_MENU_POSITION_PAGE_TOOLTIP),
                clickHandler = function()
                    OpenPage(positionSection)
                end,
                disable = IsCountdownOff,
            })
            buttonIndex = #options
        end
    end
    table.insert(options, {
        type = LHAS.ST_BUTTON,
        label = Label(ICON.countdown, SI_SBT_MENU_RESET),
        tooltip = GetString(SI_SBT_MENU_RESET_TOOLTIP),
        clickHandler = function()
            Timers.Reset()
        end,
    })

    -- The Countdown Position page (see HookBack above).
    local positionIndex = #options + 1
    table.insert(options, { type = LHAS.ST_SECTION, label = Label(ICON.position, SI_SBT_MENU_POSITION) })
    AddPositionRows(LHAS, options)

    local settings = panel:AddSettings(options)
    for _, index in ipairs(mainRows) do
        settings[index].CreateControl = AddMainRow
        settings[index].UpdateControl = UpdateMainRow
    end
    for index = settingsIndex + 1, #settings do
        if index ~= positionIndex then
            settings[index].SetEnabled = SetTimerRowEnabled
        end
    end
    HookTimerRows(LHAS)
    HookCountdownPreview(LHAS)
    HookBack(LHAS)
    -- The pages' own rows would repeat the main list's Supporters and Timer Settings and the Countdown Position
    -- button, so they draw nothing.
    supportSection, settingsSection = settings[supportIndex], settings[settingsIndex]
    positionSection, positionButton = settings[positionIndex], settings[buttonIndex]
    for _, section in ipairs({ supportSection, settingsSection, positionSection }) do
        section.CreateControl = DrawNothing
    end
    boxRow = hasQRCode and settings[firstRowIndex] or nil
    if boxRow then
        GetSupportBox()
        HookSupportBox(LHAS)
    end
    Menu.panel = panel
    HookFullName(LHAS)
end

function Menu.Initialize()
    -- The console interface only: consoles, and the console simulation on PC. The rows use the game's gamepad
    -- templates, which the keyboard interface doesn't draw.
    if not IsKeyboardUISupported() and LibHarvensAddonSettings then
        BuildConsoleMenu(LibHarvensAddonSettings)
    end
end
