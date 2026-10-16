-- The settings menu.
--
-- Console (and the console simulation on PC): built directly with LibHarvensAddonSettings (LHAS), the library behind
-- the main menu's Addons entry. The main list has four rows:
--   Supporters            opens a page: the QR code box, the supporters (one "GT: gamertag" line each), the thank-you
--   Requirement Filters   opens a page: what is checked and which lines are shown
--   Release Notes         shows the What's New pop-up
--   Feedback              shows the bug report form's QR code in a pop-up
-- In LHAS an ST_SECTION row opens a page holding the rows after it, up to the next section, and other rows are
-- buttons. LHAS draws the two kinds differently (see "The main list" below), so all four rows are buttons drawn by
-- this file, and the two pages are sections that draw no row of their own. LHAS rows can't hold a picture, so the QR
-- code box is drawn by this file under the menu's header, and shown only while the Supporters page is open (LHAS
-- rebuilds its list in AddonSettings:CreateControls each time a page opens or closes; see its Settings.lua). Each row
-- starts with an icon, written into its text.
--
-- PC keyboard interface: a LibAddonMenu-2.0 panel under Settings > Add-Ons, with the same Supporters and Requirement
-- Filters parts and Release Notes and Feedback buttons at the end. The donation QR code is drawn right in the
-- Supporters part, in a LAM custom control.

local addon = CanCraftMasterWrit
local Settings = addon.Settings
local Popup = addon.Popup
local Result = addon.Result
local Util = addon.Util

local Menu = {}
addon.Menu = Menu

-- LAM creates a global control with this name for the panel; it has to be unique among all add-ons.
local PANEL_ID = "CanCraftMasterWritSettingsPanel"

local QR_SIZE = 200
local QR_MARGIN = 12 -- White border round the code; phone cameras need it to find the code.

-- The icon at the start of each row. All are used by the game's shared or gamepad UI code, so they exist on console.
-- The filters use the same icons as their lines in the tooltip; the display filters use the radial menu's accept
-- (known) and cancel (missing) icons.
local CATEGORY_ICON = addon.Tooltip.CATEGORY_ICON
local ICON = {
    supporters = "EsoUI/Art/Collections/Favorite_StarOnly.dds",
    filters = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_settings.dds",
    releaseNotes = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_journal.dds",
    feedback = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_help.dds",
    missing = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_cancel_down.dds",
    known = "EsoUI/Art/HUD/Gamepad/gp_radialIcon_accept_down.dds",
}
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

-- The requirement filters, in menu order: saved setting, label, the description when on and when off, and icon.
local FILTERS = {
    { "checkMaterials", SI_CCMW_MENU_MATERIALS, SI_CCMW_MENU_MATERIALS_ON, SI_CCMW_MENU_MATERIALS_OFF,
        CATEGORY_ICON[Result.CATEGORY_MATERIALS] },
    { "checkSetTraits", SI_CCMW_MENU_SET_TRAITS, SI_CCMW_MENU_SET_TRAITS_ON, SI_CCMW_MENU_SET_TRAITS_OFF,
        CATEGORY_ICON[Result.CATEGORY_SET] },
    { "checkTraitResearch", SI_CCMW_MENU_TRAIT_RESEARCH, SI_CCMW_MENU_TRAIT_RESEARCH_ON,
        SI_CCMW_MENU_TRAIT_RESEARCH_OFF, CATEGORY_ICON[Result.CATEGORY_TRAIT] },
    { "showMissing", SI_CCMW_MENU_SHOW_MISSING, SI_CCMW_MENU_SHOW_MISSING_ON, SI_CCMW_MENU_SHOW_MISSING_OFF,
        ICON.missing },
    { "showKnown", SI_CCMW_MENU_SHOW_KNOWN, SI_CCMW_MENU_SHOW_KNOWN_ON, SI_CCMW_MENU_SHOW_KNOWN_OFF, ICON.known },
}

-- Returns a row's text with its icon in front.
local function WithIcon(icon, text)
    local size = ICON_SIZE_FOR[icon] or ICON_SIZE
    return zo_iconTextFormat(icon, size, size, text, not KEEPS_ITS_COLOUR[icon], true)
end

local function Label(icon, stringId)
    return WithIcon(icon, GetString(stringId))
end

-- Returns a filter's description for its current value.
local function FilterDescription(filter)
    return GetString(Settings.Get(filter[1]) and filter[3] or filter[4])
end

-- Returns one "GT: gamertag" line per supporter, or "Be the first!" while there are none.
local function SupporterLines()
    local supporters = addon.support and addon.support.supporters or {}
    local lines = {}
    for _, gamertag in ipairs(supporters) do
        table.insert(lines, zo_strformat(SI_CCMW_GAMERTAG, gamertag))
    end
    if #lines == 0 then
        table.insert(lines, GetString(SI_CCMW_MENU_SUPPORTERS_NONE))
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
-- Console: LibHarvensAddonSettings
---------------------------------------------------------------------------------------------------

local BOX_WIDTH = ZO_GAMEPAD_CONTENT_WIDTH
local BOX_TITLE_FONT = "$(GAMEPAD_BOLD_FONT)|$(GP_27)|soft-shadow-thick"
local BOX_BODY_FONT = "$(GAMEPAD_MEDIUM_FONT)|$(GP_22)|soft-shadow-thin"
local BOX_SPACING = 8
-- The box sits between the header's "By:" line and the first supporter row, centred, at least this far from each.
-- The QR code shrinks to fit that space (the full size didn't fit, and the row covered the code in 1.0.1), in whole
-- tens, so a row that moves a little doesn't redraw it each time, but never below the smallest size.
local BOX_GAP = 12
local MIN_QR_SIZE = 120
local QR_SIZE_STEP = 10
local BOX_BOTTOM_GAP = 24 -- Between the box and the first row, if the header can't be found.
local WATCH_NAME = "CanCraftMasterWritSupportBox"
local WATCH_INTERVAL_MS = 100

-- The settings objects LHAS made for our pages and rows, set when the menu is built. The box shows with the first
-- supporter row (boxRow), which is nil without a donation link.
local supportSection, filtersSection, boxRow
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
    local box = WINDOW_MANAGER:CreateControl("CanCraftMasterWritMenuSupportBox", GuiRoot, CT_CONTROL)
    box:SetHidden(true)
    box:SetWidth(BOX_WIDTH)
    box:SetResizeToFitDescendents(true)
    box.title = AddBoxLabel(box, "Title", BOX_TITLE_FONT, box)
    box.title:SetText(Util.FallGradient(GetString(SI_CCMW_POPUP_SUPPORT_TITLE)))
    local background = WINDOW_MANAGER:CreateControl(box:GetName() .. "QRBackground", box, CT_BACKDROP)
    background:SetAnchor(TOP, box.title, BOTTOM, 0, BOX_SPACING)
    background:SetCenterColor(1, 1, 1, 1)
    background:SetEdgeColor(1, 1, 1, 0)
    box.qrBackground = background
    box.qrCode = WINDOW_MANAGER:CreateControl(box:GetName() .. "QRCode", background, CT_TEXTURE)
    box.qrCode:SetAnchor(CENTER, background, CENTER, 0, 0)
    box.caption = AddBoxLabel(box, "Caption", BOX_BODY_FONT, background)
    box.caption:SetText(GetString(SI_CCMW_POPUP_SUPPORT_SCAN))
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

-- LHAS draws the selected row's description in the side panel only when the selection changes, so after a filter is
-- switched (or reset) the panel is drawn again with the description for its new value, the way LHAS draws it.
local function RefreshSidePanel()
    local list = LibHarvensAddonSettings.list
    local data = list and list.GetSelectedData and list:GetSelectedData()
    if data and type(data.tooltipText) == "function" and GAMEPAD_TOOLTIPS then
        GAMEPAD_TOOLTIPS:LayoutSettingTooltip(GAMEPAD_LEFT_TOOLTIP, data:tooltipText(), "")
    end
end

-- The main list. LHAS draws a page row (ST_SECTION) left-aligned and always white, with an arrow, and a button
-- centred and grey until selected, with an empty row needed between the two kinds; with icons the rows didn't line
-- up. So the four rows are LHAS buttons that this file adds to LHAS's list itself, with one of the game's own list row
-- templates (common/gamepad/zo_gamepadtemplatescommon.xml): left-aligned, in a bigger font than LHAS's rows, grey
-- until selected and white when selected, as the game's menus do. LHAS still handles everything else: selecting a row
-- runs its clickHandler, and the side panel shows its tooltip. If LHAS's list ever lacks what this needs, the rows
-- fall back to LHAS's own buttons.
local MAIN_ROW_TEMPLATE = "ZO_GamepadFullWidthLeftLabelEntryTemplate"
local MAIN_ROW_POOL = "CanCraftMasterWritMenuRow"
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

-- The Requirement Filters rows are LHAS's checkbox rows, the game's ZO_GamepadOptionsCheckboxRow
-- (pregameandingame/zo_options/gamepad/zo_options_gamepad.xml): the name centred in ZoFontGamepad34, with ON and OFF
-- centred under it. Ours are drawn smaller, with the name from the left and ON and OFF at the right end of the same
-- line. The row's GetHeight, which the list spaces rows by, then counts the name's line only. LHAS calls SetEnabled on
-- each row as its list draws it, so that is where ours are restyled. The row controls are pooled and shared with
-- every other add-on's LHAS settings, so each restyled row gets its own look back before LHAS builds any page.
local FILTER_NAME_FONT = "ZoFontGamepad27" -- The size of ON and OFF beside it.
local FILTER_ON_OFF_GAP = 16

-- Restyled row controls, each with what it looked like before.
local restyledRows = {}

local function SaveAnchor(control)
    local isValid, point, relativeTo, relativePoint, offsetX, offsetY = control:GetAnchor(0)
    if isValid then
        return { point, relativeTo, relativePoint, offsetX, offsetY }
    end
end

local function RestoreAnchor(control, anchor)
    if anchor then
        control:ClearAnchors()
        control:SetAnchor(unpack(anchor))
    end
end

local function RestyleFilterRow(control)
    local name, on, off = control:GetNamedChild("Name"), control:GetNamedChild("On"), control:GetNamedChild("Off")
    if not (name and on and off) then
        return
    end
    if not restyledRows[control] then
        restyledRows[control] = {
            font = name:GetFont(),
            alignment = name:GetHorizontalAlignment(),
            onAnchor = SaveAnchor(on),
            offAnchor = SaveAnchor(off),
            getHeight = control.GetHeight,
        }
    end
    name:SetFont(FILTER_NAME_FONT)
    name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    -- The name spans the row, so its right end is the row's.
    off:ClearAnchors()
    off:SetAnchor(RIGHT, name, RIGHT, 0, 0)
    on:ClearAnchors()
    on:SetAnchor(RIGHT, off, LEFT, -FILTER_ON_OFF_GAP, 0)
    control.GetHeight = function()
        return zo_max(name:GetTextHeight(), on:GetTextHeight())
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
        RestoreAnchor(control:GetNamedChild("On"), original.onAnchor)
        RestoreAnchor(control:GetNamedChild("Off"), original.offAnchor)
        control.GetHeight = original.getHeight
    end
    ZO_ClearTable(restyledRows)
end

-- Replaces a filter row's SetEnabled, which LHAS's list calls each time it draws the row.
local function SetFilterRowEnabled(setting, ...)
    if setting.control then
        RestyleFilterRow(setting.control)
    end
    return LibHarvensAddonSettings.AddonSettingsControl.SetEnabled(setting, ...)
end

local filterRowsHooked = false
local function HookFilterRows(LHAS)
    if not filterRowsHooked then
        filterRowsHooked = true
        ZO_PreHook(LHAS.AddonSettings, "CreateControls", RestoreRestyledRows)
    end
end

-- Opens a page the way LHAS's own page rows do (their Activate in its Settings.lua).
local function OpenPage(section)
    local scrollList = LibHarvensAddonSettings.scrollList
    local list = scrollList and scrollList.GetList and scrollList:GetList("Section")
    if not list or not Menu.panel then
        return
    end
    list.currentSection = section
    scrollList:SetCurrentList(list)
    Menu.panel:CreateControls()
end

local function BuildConsoleMenu(LHAS)
    local panel = LHAS:AddAddon(GetString(SI_CCMW_MENU_NAME), { allowDefaults = true, allowRefresh = true })
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
    AddButton(ICON.supporters, SI_CCMW_MENU_SUPPORT, nil, function()
        OpenPage(supportSection)
    end)
    AddButton(ICON.filters, SI_CCMW_MENU_FILTERS, nil, function()
        OpenPage(filtersSection)
    end)
    if Popup.GetLatestReleaseNotes() then
        AddButton(ICON.releaseNotes, SI_CCMW_MENU_RELEASE_NOTES, GetString(SI_CCMW_MENU_RELEASE_NOTES_TOOLTIP),
            ShowReleaseNotes)
    end
    if Popup.GetFeedbackLink() then
        AddButton(ICON.feedback, SI_CCMW_MENU_FEEDBACK, GetString(SI_CCMW_MENU_FEEDBACK_TOOLTIP), ShowFeedback)
    end

    -- The Supporters page.
    local hasQRCode = Popup.GetDonationLink() ~= nil
    local supportIndex = #options + 1
    table.insert(options, { type = LHAS.ST_SECTION, label = Label(ICON.supporters, SI_CCMW_MENU_SUPPORT) })
    if not hasQRCode then
        table.insert(options, { type = LHAS.ST_LABEL, label = GetString(SI_CCMW_MENU_DONATE_NOT_SET), canSelect = false })
    end
    -- The first supporter row is the only one that can be selected, so it is selected when the page opens and its
    -- tooltip (the support message) shows in the side panel.
    local firstRowIndex = #options + 1
    for index, line in ipairs(SupporterLines()) do
        table.insert(options, {
            type = LHAS.ST_LABEL,
            label = line,
            tooltip = index == 1 and GetString(SI_CCMW_MENU_DONATE_TOOLTIP) or nil,
            canSelect = index == 1,
        })
    end
    table.insert(options, { type = LHAS.ST_LABEL, label = Popup.FormatThanks(), canSelect = false })

    -- The Requirement Filters page.
    local filtersIndex = #options + 1
    table.insert(options, { type = LHAS.ST_SECTION, label = Label(ICON.filters, SI_CCMW_MENU_FILTERS) })
    for _, filter in ipairs(FILTERS) do
        local key = filter[1]
        table.insert(options, {
            type = LHAS.ST_CHECKBOX,
            label = Label(filter[5], filter[2]),
            tooltip = function()
                return FilterDescription(filter)
            end,
            default = Settings.DEFAULTS[key],
            getFunction = function()
                return Settings.Get(key)
            end,
            setFunction = function(value)
                Settings.Set(key, value)
                RefreshSidePanel()
            end,
        })
    end

    local settings = panel:AddSettings(options)
    for _, index in ipairs(mainRows) do
        settings[index].CreateControl = AddMainRow
        settings[index].UpdateControl = UpdateMainRow
    end
    for index = filtersIndex + 1, #settings do
        settings[index].SetEnabled = SetFilterRowEnabled
    end
    HookFilterRows(LHAS)
    -- The pages' own rows would repeat the main list's Supporters and Requirement Filters, so they draw nothing.
    supportSection, filtersSection = settings[supportIndex], settings[filtersIndex]
    supportSection.CreateControl = DrawNothing
    filtersSection.CreateControl = DrawNothing
    boxRow = hasQRCode and settings[firstRowIndex] or nil
    if boxRow then
        GetSupportBox()
        HookSupportBox(LHAS)
    end
    Menu.panel = panel
end

---------------------------------------------------------------------------------------------------
-- PC keyboard interface: LibAddonMenu-2.0
---------------------------------------------------------------------------------------------------

-- Draws the QR code for the donation link inside the LAM custom control: a white square with the code on it.
-- LibQRCode.DrawQRCode needs a texture control; it paints it white and draws the code on top.
local function CreateQRCode(customControl)
    local link = Popup.GetDonationLink()
    if not link or not LibQRCode then
        return
    end
    local background = WINDOW_MANAGER:CreateControl("CanCraftMasterWritMenuQRBackground", customControl, CT_BACKDROP)
    background:SetDimensions(QR_SIZE + 2 * QR_MARGIN, QR_SIZE + 2 * QR_MARGIN)
    background:SetAnchor(TOP, customControl, TOP, 0, 0)
    background:SetCenterColor(1, 1, 1, 1)
    background:SetEdgeColor(1, 1, 1, 0)
    local qrCode = WINDOW_MANAGER:CreateControl("CanCraftMasterWritMenuQRCode", background, CT_TEXTURE)
    qrCode:SetDimensions(QR_SIZE, QR_SIZE)
    qrCode:SetAnchor(CENTER, background, CENTER, 0, 0)
    LibQRCode.DrawQRCode(qrCode, link)
end

local function Text(text, tooltip)
    return { type = "description", text = text, tooltip = tooltip }
end

-- LAM reads a control's tooltip once, when it makes the control, so after a filter is switched (or reset) its
-- description is updated here, and shown again if the pointer is still on it.
local function RefreshKeyboardTooltip(reference, filter)
    local control = _G[reference]
    if not control or not control.data then
        return
    end
    control.data.tooltipText = FilterDescription(filter)
    if WINDOW_MANAGER:GetMouseOverControl() == control and ZO_Options_OnMouseEnter then
        ZO_Options_OnMouseEnter(control)
    end
end

local function BuildKeyboardMenu(LAM)
    LAM:RegisterAddonPanel(PANEL_ID, {
        type = "panel",
        name = GetString(SI_CCMW_MENU_NAME),
        author = addon.author,
        version = addon.version,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local options = {}
    table.insert(options, { type = "header", name = Label(ICON.supporters, SI_CCMW_MENU_SUPPORT) })
    if Popup.GetDonationLink() then
        table.insert(options, Text(GetString(SI_CCMW_POPUP_SUPPORT_SCAN)))
        table.insert(options, {
            type = "custom",
            createFunc = CreateQRCode,
            minHeight = QR_SIZE + 2 * QR_MARGIN,
            maxHeight = QR_SIZE + 2 * QR_MARGIN,
        })
    else
        table.insert(options, Text(GetString(SI_CCMW_MENU_DONATE_NOT_SET)))
    end
    for _, line in ipairs(SupporterLines()) do
        table.insert(options, Text(line))
    end
    table.insert(options, Text(Popup.FormatThanks(), GetString(SI_CCMW_MENU_DONATE_TOOLTIP)))

    table.insert(options, { type = "header", name = Label(ICON.filters, SI_CCMW_MENU_FILTERS) })
    for _, filter in ipairs(FILTERS) do
        local key = filter[1]
        -- A named control (which the game makes global), so the description can be updated when the value changes.
        local reference = "CanCraftMasterWritMenuFilter_" .. key
        table.insert(options, {
            type = "checkbox",
            name = Label(filter[5], filter[2]),
            tooltip = function()
                return FilterDescription(filter)
            end,
            reference = reference,
            default = Settings.DEFAULTS[key],
            getFunc = function()
                return Settings.Get(key)
            end,
            setFunc = function(value)
                Settings.Set(key, value)
                RefreshKeyboardTooltip(reference, filter)
            end,
        })
    end

    if Popup.GetLatestReleaseNotes() then
        table.insert(options, {
            type = "button",
            name = Label(ICON.releaseNotes, SI_CCMW_MENU_RELEASE_NOTES),
            tooltip = GetString(SI_CCMW_MENU_RELEASE_NOTES_TOOLTIP),
            func = ShowReleaseNotes,
        })
    end
    if Popup.GetFeedbackLink() then
        table.insert(options, {
            type = "button",
            name = Label(ICON.feedback, SI_CCMW_MENU_FEEDBACK),
            tooltip = GetString(SI_CCMW_MENU_FEEDBACK_TOOLTIP),
            func = ShowFeedback,
        })
    end

    LAM:RegisterOptionControls(PANEL_ID, options)
    Menu.options = options
end

function Menu.Initialize()
    if IsKeyboardUISupported() then
        if LibAddonMenu2 then
            BuildKeyboardMenu(LibAddonMenu2)
        end
    elseif LibHarvensAddonSettings then
        BuildConsoleMenu(LibHarvensAddonSettings)
    end
end
