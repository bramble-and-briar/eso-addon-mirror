-- Lethal PVP Insights - its own entry in the game's Settings menu (Settings > Lethal PVP Insights),
-- like Bandits UI: no LibAddonMenu needed. A numbered section list on the left, the chosen section's
-- options on the right (header, description, checkbox, dropdown, slider, button, editbox,
-- colorpicker, submenu), drawn with the game's own controls.
local PDI = PVPDataInsight
local P = {}
PDI.SettingsPanel = P

local WM = WINDOW_MANAGER
P.COLOR = "E0694F"                          -- the esopvp.com orange
local W = 620                               -- width of the option list
local LABEL_W = 300                         -- left column (names); controls start after it
local NAV_W = 235                           -- section list on the left
local ROW_H = 34
local NAME = "LPISettingsWindow"

local function val(v) if type(v) == "function" then return v() end return v end
local uidN = 0
local function uid(kind) uidN = uidN + 1; return NAME .. kind .. uidN end      -- unique control names

local function tooltip(control, text, warning)
    if not text and not warning then return end
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", function(c)
        local t = val(text) or ""
        if warning then t = t .. (t ~= "" and "\n\n" or "") .. "|cFF6655" .. val(warning) .. "|r" end
        InitializeTooltip(InformationTooltip, c, BOTTOMLEFT, 0, -6, TOPLEFT)
        SetTooltipText(InformationTooltip, t)
    end)
    control:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
end

local function isOff(o) return val(o.disabled) == true end

local function label(parent, font, color)
    local l = WM:CreateControl(nil, parent, CT_LABEL)
    l:SetFont(font or "ZoFontWinH4")
    l:SetColor(unpack(color or { 0.77, 0.76, 0.62, 1 }))
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return l
end

-- ---------------------------------------------------------------- one row per option
local BUILD = {}

function BUILD.header(row, o)
    local l = label(row, "ZoFontWinH2", { 1, 1, 1, 1 })
    l:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
    l:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, -8)
    local d = WM:CreateControlFromVirtual(uid("Div"), row, "ZO_Options_Divider")
    d:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, 0)
    row.h = 52
    row.refresh = function() l:SetText(val(o.name) or "") end
end

function BUILD.description(row, o)
    local t = o.title and label(row, "ZoFontWinH4", { 1, 1, 1, 1 }) or nil
    local l = label(row, "ZoFontGame", { 0.85, 0.85, 0.8, 1 })
    l:SetWidth(W)
    l:SetVerticalAlignment(TEXT_ALIGN_TOP)
    if t then t:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 4); l:SetAnchor(TOPLEFT, t, BOTTOMLEFT, 0, 2)
    else l:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 4) end
    row.refresh = function()
        if t then t:SetText(val(o.title) or "") end
        l:SetText(val(o.text) or "")
        row.h = l:GetTextHeight() + (t and 30 or 0) + 12
    end
end

local function nameLabel(row, o, indent)
    local l = label(row)
    l:SetAnchor(LEFT, row, LEFT, indent or 0, 0)
    l:SetDimensions(LABEL_W - (indent or 0), ROW_H)
    tooltip(l, o.tooltip, o.warning)
    return l
end

function BUILD.checkbox(row, o, indent)
    local l = nameLabel(row, o, indent)
    local cb = WM:CreateControlFromVirtual(uid("Check"), row, "ZO_CheckButton")
    cb:SetAnchor(LEFT, row, LEFT, LABEL_W + 4, 0)
    local state = label(row, "ZoFontWinH4", { 1, 1, 1, 1 })
    state:SetAnchor(LEFT, cb, RIGHT, 10, 0)
    local busy = false
    ZO_CheckButton_SetToggleFunction(cb, function(_, checked)
        if busy then return end
        o.setFunc(checked)
        P:Refresh()
    end)
    row.refresh = function()
        l:SetText(val(o.name) or "")
        local on = o.getFunc() == true
        busy = true
        ZO_CheckButton_SetCheckState(cb, on)
        busy = false
        state:SetText(on and "ON" or "OFF")
        local off = val(o.disabled) == true
        ZO_CheckButton_SetEnableState(cb, not off)
        row:SetAlpha(off and 0.5 or 1)
    end
end

function BUILD.dropdown(row, o, indent)
    local l = nameLabel(row, o, indent)
    local ctrl = WM:CreateControlFromVirtual(uid("Combo"), row, "ZO_ComboBox")
    ctrl:SetDimensions(W - LABEL_W, 30)
    ctrl:SetAnchor(LEFT, row, LEFT, LABEL_W, 0)
    local combo = ZO_ComboBox_ObjectFromContainer(ctrl)
    combo:SetSortsItems(false)
    local shown                                   -- the choice list currently in the box
    local function fill(choices, values)
        combo:ClearItems()
        for i, text in ipairs(choices) do
            combo:AddItem(combo:CreateItemEntry(text, function()
                if isOff(o) then return end
                o.setFunc(values[i]); P:Refresh()
            end), ZO_COMBOBOX_SUPPRESS_UPDATE)
        end
        if combo.UpdateItems then combo:UpdateItems() end
    end
    row.refresh = function()
        l:SetText(val(o.name) or "")
        local choices = val(o.choices) or {}
        local values = val(o.choicesValues) or choices
        local key = table.concat(choices, "\1")
        if key ~= shown then shown = key; fill(choices, values) end
        local cur, found = o.getFunc(), false
        for i, v in ipairs(values) do
            if v == cur then
                found = true
                if combo.SetSelectedItemText then combo:SetSelectedItemText(choices[i]) else combo:SetSelectedItem(choices[i]) end
            end
        end
        if not found then
            if combo.SetSelectedItemText then combo:SetSelectedItemText(val(o.placeholder) or "") else combo:SetSelectedItem(val(o.placeholder) or "") end
        end
        local off = isOff(o)
        if combo.SetEnabled then combo:SetEnabled(not off) end
        row:SetAlpha(off and 0.5 or 1)
    end
end

function BUILD.slider(row, o, indent)
    local l = nameLabel(row, o, indent)
    local s = WM:CreateControl(nil, row, CT_SLIDER)
    s:SetDimensions(220, 14)
    s:SetAnchor(LEFT, row, LEFT, LABEL_W + 4, 0)
    s:SetMouseEnabled(true)
    s:SetOrientation(ORIENTATION_HORIZONTAL)
    s:SetThumbTexture("EsoUI/Art/Miscellaneous/scrollbox_elevator.dds", "EsoUI/Art/Miscellaneous/scrollbox_elevator_disabled.dds", nil, 8, 16)
    s:SetMinMax(o.min, o.max)
    s:SetValueStep(o.step or 1)
    local bg = WM:CreateControl(nil, s, CT_BACKDROP)
    bg:SetCenterColor(0, 0, 0)
    bg:SetAnchor(TOPLEFT, s, TOPLEFT, 0, 4)
    bg:SetAnchor(BOTTOMRIGHT, s, BOTTOMRIGHT, 0, -4)
    bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-SliderBackdrop.dds", 32, 4)
    local v = label(row, "ZoFontWinH4", { 1, 1, 1, 1 })
    v:SetAnchor(LEFT, s, RIGHT, 12, 0)
    local busy = false
    local step = o.step or 1
    local function fmt(value)
        if step >= 1 then return tostring(math.floor(value + 0.5)) end
        local dec = step >= 0.1 and 1 or 2
        return string.format("%." .. dec .. "f", value)
    end
    s:SetHandler("OnValueChanged", function(_, value)
        value = math.floor(value / step + 0.5) * step
        if step < 1 then value = tonumber(fmt(value)) end
        v:SetText(fmt(value))
        if not busy and not isOff(o) then o.setFunc(value) end
    end)
    row.refresh = function()
        l:SetText(val(o.name) or "")
        busy = true
        s:SetValue(o.getFunc() or o.min)
        busy = false
        v:SetText(fmt(o.getFunc() or o.min))
        local off = isOff(o)
        s:SetEnabled(not off)
        row:SetAlpha(off and 0.5 or 1)
    end
end

function BUILD.button(row, o)
    local b = WM:CreateControlFromVirtual(uid("Button"), row, "ZO_DefaultButton")
    b:SetWidth(280)
    b:SetAnchor(LEFT, row, LEFT, row.halfRight and (W / 2) or 0, 0)
    tooltip(b, o.tooltip, o.warning)
    local armedUntil = 0
    b:SetHandler("OnClicked", function()
        if o.isDangerous then
            -- dangerous ones need a second click within 4 seconds
            local now = GetFrameTimeMilliseconds()
            if now > armedUntil then
                armedUntil = now + 4000
                b:SetText("|cFF6655Click again to confirm|r")
                zo_callLater(function() if GetFrameTimeMilliseconds() >= armedUntil then b:SetText(val(o.name)) end end, 4100)
                return
            end
            armedUntil = 0
            b:SetText(val(o.name))
        end
        if isOff(o) then return end
        o.func()
        P:Refresh()
    end)
    row.refresh = function()
        b:SetText(val(o.name) or "")
        b:SetEnabled(not isOff(o))
    end
end

function BUILD.editbox(row, o, indent)
    local l = nameLabel(row, o, indent)
    local multi = o.isMultiline == true
    local bd = WM:CreateControlFromVirtual(uid("EditBg"), row, "ZO_EditBackdrop")
    local e = WM:CreateControlFromVirtual(uid("Edit"), bd, multi and "ZO_DefaultEditMultiLineForBackdrop" or "ZO_DefaultEditForBackdrop")
    e:SetMaxInputChars(o.maxChars or 3000)
    if multi then
        -- name above, a tall box across the full width below
        l:ClearAnchors(); l:SetAnchor(TOPLEFT, row, TOPLEFT, indent or 0, 0); l:SetHeight(28)
        bd:SetDimensions(W - (indent or 0), 140)
        bd:SetAnchor(TOPLEFT, row, TOPLEFT, indent or 0, 30)
        row.h = 176
    else
        bd:SetDimensions(W - LABEL_W, 28)
        bd:SetAnchor(LEFT, row, LEFT, LABEL_W, 0)
    end
    local function save() if not isOff(o) then o.setFunc(e:GetText()) end end
    if not multi then e:SetHandler("OnEnter", function(c) save(); c:LoseFocus() end) end
    e:SetHandler("OnFocusLost", save)
    row.refresh = function()
        l:SetText(val(o.name) or ""); e:SetText(o.getFunc() or "")
        local off = isOff(o)
        e:SetMouseEnabled(not off)
        row:SetAlpha(off and 0.5 or 1)
    end
end

function BUILD.colorpicker(row, o, indent)
    local l = nameLabel(row, o, indent)
    local bd = WM:CreateControl(nil, row, CT_BACKDROP)
    bd:SetDimensions(60, 24)
    bd:SetAnchor(LEFT, row, LEFT, LABEL_W + 4, 0)
    bd:SetCenterColor(0, 0, 0, 1)
    bd:SetEdgeColor(0.6, 0.6, 0.6, 1)
    bd:SetEdgeTexture("", 1, 1, 1)
    local sw = WM:CreateControl(nil, bd, CT_TEXTURE)
    sw:SetAnchor(TOPLEFT, bd, TOPLEFT, 2, 2)
    sw:SetAnchor(BOTTOMRIGHT, bd, BOTTOMRIGHT, -2, -2)
    bd:SetMouseEnabled(true)
    tooltip(bd, o.tooltip, o.warning)
    bd:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT or isOff(o) then return end
        local r, g, b, a = o.getFunc()
        COLOR_PICKER:Show(function(nr, ng, nb, na)
            o.setFunc(nr, ng, nb, na)
            P:Refresh()
        end, r or 1, g or 1, b or 1, a or 1, val(o.name))
    end)
    row.refresh = function()
        l:SetText(val(o.name) or "")
        local r, g, b, a = o.getFunc()
        sw:SetColor(r or 1, g or 1, b or 1, a or 1)
        local off = isOff(o)
        row:SetAlpha(off and 0.5 or 1)
    end
end

-- ---------------------------------------------------------------- the panel
-- sections = { { name = "Alerts", icon = "...", options = { ... } }, ... }
function P:AddRow(sec, o, indent)
    local row = WM:CreateControl(uid("Row"), sec.box, CT_CONTROL)
    row:SetDimensions(W, ROW_H)
    row.h = ROW_H
    if o.type == "button" and o.width == "half" then
        -- two half-width buttons share a row
        local prev = sec.rows[#sec.rows]
        if prev and prev.halfOpen then
            prev.halfOpen = false
            row:SetParent(prev)
            row:SetAnchor(TOPLEFT, prev, TOPLEFT, 0, 0)
            row.halfRight, row.inline = true, true
            BUILD.button(row, o)
            prev.children = prev.children or {}
            prev.children[#prev.children + 1] = row
            return
        end
        row.halfOpen = true
    end
    if o.type == "submenu" then
        local hr = row
        local t = label(hr, "ZoFontWinH4", { 1, 1, 1, 1 })
        t:SetAnchor(LEFT, hr, LEFT, 0, 4)
        tooltip(t, o.tooltip)
        hr.h = 36
        hr.refresh = function() t:SetText(val(o.name) or "") end
        sec.rows[#sec.rows + 1] = hr
        for _, c in ipairs(o.controls or {}) do self:AddRow(sec, c, 24) end
        return
    end
    local build = BUILD[o.type]
    if not build then row:SetHidden(true); return end
    build(row, o, indent)
    sec.rows[#sec.rows + 1] = row
end

function P:Layout(sec)
    local y = 0
    for _, row in ipairs(sec.rows) do
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, sec.box, TOPLEFT, 0, y)
        row:SetHeight(row.h or ROW_H)
        y = y + (row.h or ROW_H) + 4
    end
    sec.box:SetHeight(y + 20)
    self.child:SetHeight(y + 20)
end

function P:Refresh()
    local sec = self.sections and self.sections[self.current]
    if not sec then return end
    if not sec.built then
        sec.built = true
        for _, o in ipairs(val(sec.options) or {}) do self:AddRow(sec, o) end
    end
    for _, row in ipairs(sec.rows) do
        pcall(row.refresh)
        for _, c in ipairs(row.children or {}) do pcall(c.refresh) end
    end
    self:Layout(sec)
end

local NAV_NORMAL = { 0.77, 0.76, 0.62, 1 }
local NAV_HOVER = { 1, 1, 1, 1 }

function P:Select(i)
    if not self.sections[i] then i = 1 end
    self.current = i
    for k, sec in ipairs(self.sections) do
        sec.box:SetHidden(k ~= i)
        sec.nav.sel:SetHidden(k ~= i)
        sec.nav.text:SetColor(unpack(k == i and NAV_HOVER or NAV_NORMAL))
    end
    local sec = self.sections[i]
    self.secTitle:SetText(string.format("%d.  %s%s", i, sec.icon and zo_iconFormat(sec.icon, 32, 32) .. " " or "", sec.name))
    self:Refresh()
    ZO_Scroll_ResetToTop(self.scroll)
    if PDI.sv and PDI.sv.settings then PDI.sv.settings.settingsSection = i end
end

local function navEntry(parent, i, sec, anchorTo)
    local row = WM:CreateControl(uid("Nav"), parent, CT_CONTROL)
    row:SetDimensions(NAV_W, 28)
    if anchorTo then row:SetAnchor(TOPLEFT, anchorTo, BOTTOMLEFT, 0, 2) else row:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0) end
    local sel = WM:CreateControl(nil, row, CT_TEXTURE)
    sel:SetTexture("EsoUI/Art/Miscellaneous/listItem_highlight.dds")
    sel:SetColor(0.88, 0.41, 0.31, 0.55)
    sel:SetAnchorFill(row)
    sel:SetHidden(true)
    local num = label(row, "ZoFontWinH4", NAV_NORMAL)
    num:SetAnchor(LEFT, row, LEFT, 4, 0)
    num:SetText(i .. ".")
    local ic = WM:CreateControl(nil, row, CT_TEXTURE)
    ic:SetDimensions(24, 24)
    ic:SetAnchor(LEFT, row, LEFT, 30, 0)
    if sec.icon then ic:SetTexture(sec.icon) end
    local text = label(row, "ZoFontWinH4", NAV_NORMAL)
    text:SetAnchor(LEFT, ic, RIGHT, 6, 0)
    text:SetText(sec.name)
    row:SetMouseEnabled(true)
    row:SetHandler("OnMouseEnter", function() if P.current ~= i then text:SetColor(unpack(NAV_HOVER)) end end)
    row:SetHandler("OnMouseExit", function() if P.current ~= i then text:SetColor(unpack(NAV_NORMAL)) end end)
    row:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then PlaySound(SOUNDS.DEFAULT_CLICK); P:Select(i) end
    end)
    return { row = row, sel = sel, text = text }
end

local function window(sections)
    local tlw = WM:CreateTopLevelWindow(NAME)
    tlw:SetHidden(true)
    tlw:SetDimensions(1010, 914)                 -- the game's own settings window size
    ZO_ReanchorControlForLeftSidePanel(tlw)
    local function tex(file, w, h, anchorTo, point, relPoint)
        local t = WM:CreateControl(nil, tlw, CT_TEXTURE)
        t:SetTexture(file); t:SetDimensions(w, h)
        t:SetAnchor(point or TOPLEFT, anchorTo, relPoint or TOPLEFT)
        t:SetDrawLayer(DL_BACKGROUND)
        t:SetExcludeFromResizeToFitExtents(true)
        return t
    end
    local left = tex("EsoUI/Art/Miscellaneous/centerscreen_left.dds", 1024, 1024, tlw)
    tex("EsoUI/Art/Miscellaneous/centerscreen_right.dds", 64, 1024, left, TOPLEFT, TOPRIGHT)
    local title = WM:CreateControl(NAME .. "Title", tlw, CT_LABEL)
    title:SetAnchor(TOPLEFT, tlw, TOPLEFT, 65, 70)
    title:SetFont("ZoFontWinH1")
    title:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
    title:SetText(string.format("|c%sLethal|r PVP Insights  |c999999%s|r", P.COLOR, PDI.version))
    local div = WM:CreateControlFromVirtual(NAME .. "Divider", tlw, "ZO_Options_Divider")
    div:SetAnchor(TOPLEFT, tlw, TOPLEFT, 65, 108)
    -- section list
    local nav = WM:CreateControl(NAME .. "Nav", tlw, CT_CONTROL)
    nav:SetAnchor(TOPLEFT, tlw, TOPLEFT, 65, 128)
    nav:SetDimensions(NAV_W, 600)
    local prev
    for i, sec in ipairs(sections) do
        sec.nav = navEntry(nav, i, sec, prev)
        prev = sec.nav.row
    end
    -- the chosen section
    local x = 65 + NAV_W + 20
    P.secTitle = WM:CreateControl(NAME .. "SecTitle", tlw, CT_LABEL)
    P.secTitle:SetAnchor(TOPLEFT, tlw, TOPLEFT, x, 122)
    P.secTitle:SetFont("ZoFontWinH2")
    P.secTitle:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
    local scroll = WM:CreateControlFromVirtual(NAME .. "Scroll", tlw, "ZO_ScrollContainer")
    scroll:SetAnchor(TOPLEFT, tlw, TOPLEFT, x, 165)
    scroll:SetDimensions(W + 30, 720)
    P.scroll = scroll
    P.child = scroll:GetNamedChild("ScrollChild")
    P.child:SetResizeToFitDescendents(false)
    P.child:SetWidth(W)
    for _, sec in ipairs(sections) do
        sec.box = WM:CreateControl(uid("Sec"), P.child, CT_CONTROL)
        sec.box:SetAnchor(TOPLEFT, P.child, TOPLEFT, 0, 0)
        sec.box:SetWidth(W)
        sec.box:SetHidden(true)
        sec.rows = {}
    end
    return tlw
end

-- Settings > Lethal PVP Insights in the game menu
function P:Create(sections)
    if self.created or not (ZO_GameMenu_AddSettingPanel and KEYBOARD_OPTIONS) then return self.created end
    self.created = true
    self.sections = sections
    self.win = window(sections)
    self.fragment = ZO_FadeSceneFragment:New(self.win)
    local panelData = { id = KEYBOARD_OPTIONS.currentPanelId,
                        name = string.format("|c%sLethal|r PVP Insights", self.COLOR) }
    KEYBOARD_OPTIONS.currentPanelId = panelData.id + 1
    KEYBOARD_OPTIONS.panelNames[panelData.id] = panelData.name
    KEYBOARD_OPTIONS.controlTable[panelData.id] = {}
    self.panelId = panelData.id
    function panelData.callback()
        SCENE_MANAGER:AddFragment(self.fragment)
        KEYBOARD_OPTIONS:ChangePanels(self.panelId)
        self:Select(self.current or (PDI.sv and PDI.sv.settings and PDI.sv.settings.settingsSection) or 1)
    end
    function panelData.unselectedCallback()
        SCENE_MANAGER:RemoveFragment(self.fragment)
    end
    ZO_GameMenu_AddSettingPanel(panelData)
    return true
end

-- opens the game menu at Settings > Lethal PVP Insights (optionally at a section)
function P:Open(section)
    if not self.panelId then return false end
    if section then self.current = section end
    local function select()
        local menu = ZO_GameMenu_InGame and ZO_GameMenu_InGame.gameMenu
        local settings = menu and menu.headerControls and menu.headerControls[GetString(SI_GAME_MENU_SETTINGS)]
        for _, node in ipairs(settings and settings:GetChildren() or {}) do
            local d = node:GetData()
            if d and d.id == self.panelId then node:GetTree():SelectNode(node); return end
        end
    end
    if SCENE_MANAGER:GetScene("gameMenuInGame"):GetState() == SCENE_SHOWN then
        select()
        if section and self.sections then self:Select(section) end
    else
        SCENE_MANAGER:CallWhen("gameMenuInGame", SCENE_SHOWN, select)
        SCENE_MANAGER:Show("gameMenuInGame")
    end
    return true
end
