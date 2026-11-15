-- Editor widget kit. Every widget is built once and bound to getter/setter closures; the editor
-- re-runs all refreshers when anything changes. Nothing is ever destroyed (ESO can't free controls):
-- dynamic lists reuse pooled rows.

local DT = DebuffTracker
local W = {}
DT.UI.W = W
local U = DT.Util
local C = DT.Const
local WM = WINDOW_MANAGER

W.refreshers = {}
local nameCounter = 0
local function UniqueName(prefix)
    nameCounter = nameCounter + 1
    return string.format("DebuffTracker5_%s%d", prefix, nameCounter)
end

W.UniqueName = UniqueName

-- Every scroll container we create, so the editor can make them re-measure their content.
W.scrolls = {}
function W.ScrollContainer(name, parent)
    local scroll = WM:CreateControlFromVirtual(name, parent, "ZO_ScrollContainer")
    W.scrolls[#W.scrolls + 1] = scroll
    return scroll
end
function W.UpdateScrolls()
    if type(ZO_Scroll_OnExtentsChanged) ~= "function" then return end
    for _, s in ipairs(W.scrolls) do ZO_Scroll_OnExtentsChanged(s) end
end

-- label names the widget in the (one-time) chat report if its refresh ever fails: one broken widget
-- must never stop the rest of the editor from refreshing.
function W.Register(fn, label)
    local n = #W.refreshers + 1
    W.refreshers[n] = { fn = fn, key = "editor: " .. ((label and label ~= "") and label or ("widget #" .. n)) }
end

function W.RefreshAll()
    for _, r in ipairs(W.refreshers) do U.SafeCall(r.key, r.fn) end
end

local GOLD, GOLD_DIM, GOLD_BG = C.GOLD, C.GOLD_DIM, C.GOLD_BG

------------------------------------------------------------------------------
-- Primitives
------------------------------------------------------------------------------

function W.Backdrop(parent, center, edge, edgeSize)
    local b = WM:CreateControl(nil, parent, CT_BACKDROP)
    b:SetCenterColor(center[1], center[2], center[3], center[4])
    b:SetEdgeColor(edge[1], edge[2], edge[3], edge[4])
    local f = (edgeSize == 2 or edgeSize == 4) and edgeSize or 1     -- must be a power of two above zero
    b:SetEdgeTexture(nil, f, f, 1)
    return b
end

function W.Label(parent, text, font, color, align)
    local l = WM:CreateControl(nil, parent, CT_LABEL)
    l:SetFont(font or "ZoFontGame")
    if color then l:SetColor(color[1], color[2], color[3], color[4] or 1) end
    l:SetText(text or "")
    l:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return l
end

function W.Texture(parent, path, w, h)
    local t = WM:CreateControl(nil, parent, CT_TEXTURE)
    t:SetDimensions(w, h)
    if path then t:SetTexture(path) end
    return t
end

-- A tooltip on a widget and every part of it the mouse can rest on (its label, the edit box inside
-- its frame, a combo box's arrow...). Mouse-capturing children swallow hover events, so a tooltip only
-- on the frame showed on its border alone. Moving between the parts re-shows it without flicker.
local function Tooltip(control, text, anchorTo, ...)
    if not text or text == "" then return end
    local function Enter()
        InitializeTooltip(InformationTooltip, anchorTo or control, RIGHT, 0, 0)
        SetTooltipText(InformationTooltip, text)
    end
    local function Exit() ClearTooltip(InformationTooltip) end
    for _, c in ipairs({ control, ... }) do
        if c then
            if c.GetType and CT_LABEL and c:GetType() == CT_LABEL then c:SetMouseEnabled(true) end
            c:SetHandler("OnMouseEnter", Enter, "DT5Tip")
            c:SetHandler("OnMouseExit", Exit, "DT5Tip")
        end
    end
end
W.Tooltip = Tooltip

-- A plain clickable button (ZO_DefaultButton look).
function W.Button(parent, width, text, onClick, tooltip, height)
    local b = WM:CreateControlFromVirtual(UniqueName("Btn"), parent, "ZO_DefaultButton")
    b:SetDimensions(width, height or 28)
    b:SetText(text)
    b:SetClickSound(SOUNDS.DEFAULT_CLICK)
    b:SetHandler("OnClicked", function() onClick() end)
    Tooltip(b, tooltip)
    return b
end

-- A small flat text button (for list rows: "x", "▲", "Track"...).
function W.FlatButton(parent, width, height, text, onClick, tooltip, color)
    local b = WM:CreateControl(nil, parent, CT_BUTTON)
    b:SetDimensions(width, height)
    b:SetMouseEnabled(true)
    local bg = W.Backdrop(b, { 0.12, 0.13, 0.15, 1 }, { 0.32, 0.34, 0.38, 1 }, 1)
    bg:SetAnchorFill()
    local l = W.Label(b, text, "ZoFontGameSmall", color or { 0.9, 0.9, 0.9, 1 }, TEXT_ALIGN_CENTER)
    l:SetAnchorFill()
    b.label, b.bg = l, bg
    b:SetHandler("OnMouseEnter", function()
        bg:SetEdgeColor(GOLD[1], GOLD[2], GOLD[3], 1)
        if tooltip then InitializeTooltip(InformationTooltip, b, TOP, 0, 0); SetTooltipText(InformationTooltip, tooltip) end
    end)
    b:SetHandler("OnMouseExit", function() bg:SetEdgeColor(0.32, 0.34, 0.38, 1); ClearTooltip(InformationTooltip) end)
    b:SetHandler("OnClicked", function() PlaySound(SOUNDS.DEFAULT_CLICK); onClick() end)
    return b
end

-- A flat button showing a game texture instead of text (the game fonts have no arrow/shape glyphs).
function W.IconButton(parent, width, height, texture, onClick, tooltip, iconSize)
    local b = W.FlatButton(parent, width, height, "", onClick, tooltip)
    local size = iconSize or math.min(width, height) - 6
    local icon = W.Texture(b, texture, size, size)
    icon:SetAnchor(CENTER, b, CENTER, 0, 0)
    b.icon = icon
    return b
end
W.ARROW_UP = "EsoUI/Art/Buttons/scrollbox_upArrow_up.dds"
W.ARROW_DOWN = "EsoUI/Art/Buttons/scrollbox_downArrow_up.dds"

------------------------------------------------------------------------------
-- Rows (label + control), each returns row, height
------------------------------------------------------------------------------

function W.Section(parent, width, text)
    local row = WM:CreateControl(nil, parent, CT_CONTROL)
    row:SetDimensions(width, 30)
    local l = W.Label(row, text, "ZoFontWinH4", { 0.85, 0.75, 0.45, 1 })
    l:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 4)
    local rule = W.Backdrop(row, { GOLD_DIM[1], GOLD_DIM[2], GOLD_DIM[3], 0.6 }, { 0, 0, 0, 0 }, 1)
    rule:SetDimensions(width, 1)
    rule:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, -2)
    row.label = l
    return row, 30
end

-- Height a wrapped text needs at a given width. Uses the game's own measurement when it can (label
-- already holds the text and width), and a conservative estimate otherwise -- never less.
local FONT_METRICS = { small = { px = 6.6, line = 18 }, game = { px = 7.8, line = 22 } }
function W.TextHeight(text, width, size, label)
    local m = FONT_METRICS[size or "small"] or FONT_METRICS.small
    local perLine = math.max(10, math.floor((width - 4) / m.px))
    local lines = 0
    for part in (tostring(text or "") .. "\n"):gmatch("([^\n]*)\n") do
        local len = #part:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
        lines = lines + math.max(1, math.ceil(len / perLine))
    end
    local h = lines * m.line
    if label and label.GetTextHeight then
        local real = label:GetTextHeight()
        if type(real) == "number" and real > h then h = real end
    end
    return math.ceil(h)
end

-- Grey help text that wraps; its row grows to fit the text (never cut off).
-- text: a string, or a function returning one (re-read whenever the editor refreshes)
function W.Note(parent, width, text, height)
    local dynamic = type(text) == "function"
    local l = W.Label(parent, dynamic and "" or text, "ZoFontGameSmall", { 0.62, 0.62, 0.62, 1 })
    l:SetVerticalAlignment(TEXT_ALIGN_TOP)
    local function Fit()
        if dynamic then l:SetText(text() or "") end
        local h = math.max(height or 18, W.TextHeight(l:GetText(), width, "small", l))
        l:SetDimensions(width, h)
        return h
    end
    l.autoHeight = Fit
    if dynamic then W.Register(Fit, "note") end
    Fit()
    return l, Fit
end

function W.Checkbox(parent, width, text, get, set, tooltip, disabled)
    local row = WM:CreateControl(nil, parent, CT_CONTROL)
    row:SetDimensions(width, 26)
    local box = WM:CreateControl(nil, row, CT_BUTTON)
    box:SetDimensions(18, 18)
    box:SetAnchor(LEFT, row, LEFT, 0, 0)
    box:SetMouseEnabled(true)
    local bg = W.Backdrop(box, { 0.08, 0.08, 0.08, 0.95 }, { 0.5, 0.5, 0.5, 1 }, 1)
    bg:SetAnchorFill()
    local check = W.Backdrop(box, GOLD, { 0, 0, 0, 0 }, 1)
    check:SetAnchor(TOPLEFT, box, TOPLEFT, 4, 4)
    check:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT, -4, -4)
    local label = W.Label(row, text, "ZoFontGame")
    label:SetAnchor(LEFT, box, RIGHT, 8, 0)
    label:SetAnchor(RIGHT, row, RIGHT, 0, 0)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    local function Refresh()
        local off = disabled and disabled() or false
        check:SetHidden(not get())
        row:SetAlpha(off and 0.4 or 1)
        box:SetMouseEnabled(not off)
    end
    box:SetHandler("OnMouseEnter", function()
        bg:SetEdgeColor(GOLD[1], GOLD[2], GOLD[3], 1)
        if tooltip then InitializeTooltip(InformationTooltip, row, RIGHT, 0, 0); SetTooltipText(InformationTooltip, tooltip) end
    end)
    box:SetHandler("OnMouseExit", function() bg:SetEdgeColor(0.5, 0.5, 0.5, 1); ClearTooltip(InformationTooltip) end)
    local function Toggle()
        if disabled and disabled() then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        set(not get())
        Refresh()
        DT.UI.Changed()
    end
    box:SetHandler("OnClicked", Toggle)
    -- the label toggles too (bigger click target, like every settings panel in the game)
    label:SetMouseEnabled(true)
    label:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then Toggle() end
    end)
    label:SetHandler("OnMouseEnter", function() box:GetHandler("OnMouseEnter")() end)
    label:SetHandler("OnMouseExit", function() box:GetHandler("OnMouseExit")() end)
    W.Register(Refresh, text)
    Refresh()
    return row, 26
end

-- Native CT_SLIDER over our own track (drag applies live; release refreshes the editor).
function W.Slider(parent, width, text, minV, maxV, step, get, set, fmt, tooltip, disabled)
    local row = WM:CreateControl(nil, parent, CT_CONTROL)
    row:SetDimensions(width, 44)
    local label = W.Label(row, text, "ZoFontGame")
    label:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    label:SetDimensions(width - 80, 18)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    local value = W.Label(row, "", "ZoFontGameBold", nil, TEXT_ALIGN_RIGHT)
    value:SetAnchor(TOPRIGHT, row, TOPRIGHT, 0, 0)
    value:SetDimensions(80, 18)
    local function Step(text2) return W.FlatButton(row, 20, 20, text2, function() end) end
    local minus, plus = Step("-"), Step("+")
    minus:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, 4)
    plus:SetAnchor(TOPRIGHT, value, BOTTOMRIGHT, 0, 4)
    local trackW = width - 52
    local track = W.Backdrop(row, { 0.12, 0.12, 0.12, 1 }, { 0.45, 0.45, 0.45, 1 }, 1)
    track:SetDimensions(trackW, 8)
    track:SetAnchor(LEFT, minus, RIGHT, 6, 0)
    local fill = W.Backdrop(track, GOLD_DIM, { 0, 0, 0, 0 }, 1)
    fill:SetAnchor(TOPLEFT, track, TOPLEFT, 0, 0)
    fill:SetHeight(8)
    local slider = WM:CreateControl(nil, row, CT_SLIDER)
    slider:SetDimensions(trackW, 20)
    slider:SetAnchor(CENTER, track, CENTER, 0, 0)
    slider:SetMouseEnabled(true)
    slider:SetOrientation(ORIENTATION_HORIZONTAL)
    slider:SetThumbTexture("EsoUI/Art/Miscellaneous/scrollbox_elevator.dds", "EsoUI/Art/Miscellaneous/scrollbox_elevator_disabled.dds", nil, 10, 20)
    slider:SetMinMax(minV, maxV)
    slider:SetValueStep(step)

    local function Snap(v)
        v = U.Clamp(v, minV, maxV)
        v = minV + math.floor((v - minV) / step + 0.5) * step
        v = U.Clamp(v, minV, maxV)
        if step < 1 then v = tonumber(string.format("%.3f", v)) end
        return v
    end
    local function Show(v)
        local pct = (maxV > minV) and U.Clamp((v - minV) / (maxV - minV), 0, 1) or 0
        fill:SetWidth(math.max(1, pct * trackW))
        value:SetText(fmt and fmt(v) or tostring(v))
    end
    local function Refresh()
        local v = tonumber(get()) or minV
        slider:SetValue(v)
        Show(v)
        local off = disabled and disabled() or false
        row:SetAlpha(off and 0.4 or 1)
        slider:SetMouseEnabled(not off)
    end
    local last
    slider:SetHandler("OnValueChanged", function(_, v, reason)
        if reason == EVENT_REASON_SOFTWARE then return end
        if disabled and disabled() then return end
        v = Snap(v)
        Show(v)
        if v ~= last then last = v; set(v); DT.UI.Changed(true) end
    end)
    slider:SetHandler("OnSliderReleased", function() last = nil; DT.UI.Changed() end)
    Tooltip(slider, tooltip, row, label, value)
    minus:SetHandler("OnClicked", function()
        if disabled and disabled() then return end
        set(Snap((tonumber(get()) or minV) - step)); Refresh(); DT.UI.Changed()
    end)
    plus:SetHandler("OnClicked", function()
        if disabled and disabled() then return end
        set(Snap((tonumber(get()) or minV) + step)); Refresh(); DT.UI.Changed()
    end)
    W.Register(Refresh, text)
    Refresh()
    return row, 44
end

-- Single-line text input; commits on Enter or focus loss.
function W.Edit(parent, width, text, get, set, tooltip, opts)
    opts = opts or {}
    local row = WM:CreateControl(nil, parent, CT_CONTROL)
    local labelH = (text and text ~= "") and 20 or 0
    local boxH = opts.multiline and (opts.boxHeight or 90) or 28
    row:SetDimensions(width, labelH + boxH)
    local label
    if labelH > 0 then
        label = W.Label(row, text, "ZoFontGame")
        label:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
        label:SetDimensions(width, 18)
    end
    local bg = W.Backdrop(row, { 0.08, 0.08, 0.08, 0.95 }, { 0.45, 0.45, 0.45, 1 }, 1)
    bg:SetDimensions(opts.boxWidth or width, boxH)
    bg:SetAnchor(TOPLEFT, row, TOPLEFT, 0, labelH)
    local edit = WM:CreateControlFromVirtual(UniqueName("Edit"), bg, "ZO_DefaultEdit")
    edit:SetAnchor(TOPLEFT, bg, TOPLEFT, 6, 4)
    edit:SetAnchor(BOTTOMRIGHT, bg, BOTTOMRIGHT, -6, -4)
    edit:SetMaxInputChars(opts.maxChars or 1000)
    if opts.multiline then edit:SetMultiLine(true) end
    local editing = false
    -- grey hint text while the box is empty and not focused
    local hint
    if opts.placeholder then
        hint = W.Label(bg, opts.placeholder, "ZoFontGameSmall", { 0.45, 0.45, 0.45, 1 })
        hint:SetAnchor(LEFT, bg, LEFT, 8, 0)
    end
    local function UpdateHint()
        if hint then hint:SetHidden(editing or edit:GetText() ~= "") end
    end
    local lastOff
    local function Refresh()
        if editing then return end
        local v = get()
        edit:SetText(v ~= nil and tostring(v) or "")
        UpdateHint()
        local off = opts.disabled and opts.disabled() or false
        if off ~= lastOff then
            lastOff = off
            row:SetAlpha(off and 0.4 or 1)
            edit:SetEditEnabled(not off)
        end
    end
    edit:SetHandler("OnFocusGained", function() editing = true; UpdateHint() end)
    edit:SetHandler("OnFocusLost", function()
        editing = false
        -- Fields with a setter save, then show the saved (cleaned-up) value. Boxes without one (the
        -- dialogs' text boxes) keep what was typed: in the game the box loses focus BEFORE the OK /
        -- Import button's click runs, and resetting it here threw the typed text away (5.9.0).
        if set then
            set(edit:GetText()); DT.UI.Changed()
            Refresh()
        end
        UpdateHint()
    end)
    if not opts.multiline then
        edit:SetHandler("OnEnter", function() edit:LoseFocus() end)
    end
    edit:SetHandler("OnTextChanged", function()
        UpdateHint()
        if opts.onChange and editing then opts.onChange(edit:GetText()) end
    end)
    -- hover anywhere on the field (frame or the text inside it) or its label: gold frame + tooltip
    bg:SetMouseEnabled(true)
    for _, c in ipairs({ bg, edit }) do
        c:SetHandler("OnMouseEnter", function() bg:SetEdgeColor(GOLD[1], GOLD[2], GOLD[3], 1) end, "DT5Edge")
        c:SetHandler("OnMouseExit", function() bg:SetEdgeColor(0.45, 0.45, 0.45, 1) end, "DT5Edge")
    end
    Tooltip(bg, tooltip, row, edit, label)
    if not opts.noRefresh then W.Register(Refresh, text or tooltip) end
    Refresh()
    row.edit = edit
    return row, labelH + boxH
end

-- Dropdown on the game's ZO_ComboBox. options: list of {value, label} or a function returning one.
function W.Dropdown(parent, width, text, options, get, set, tooltip, disabled, comboWidth)
    local row = WM:CreateControl(nil, parent, CT_CONTROL)
    local labelW = (text and text ~= "") and math.floor(width * 0.42) or 0
    row:SetDimensions(width, 30)
    local label
    if labelW > 0 then
        label = W.Label(row, text, "ZoFontGame")
        label:SetAnchor(LEFT, row, LEFT, 0, 0)
        label:SetDimensions(labelW - 8, 26)
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    local container = WM:CreateControlFromVirtual(UniqueName("Combo"), row, "ZO_ComboBox")
    container:SetDimensions(comboWidth or (width - labelW), 28)
    container:SetAnchor(LEFT, row, LEFT, labelW, 0)
    local combo = ZO_ComboBox_ObjectFromContainer(container)
    combo:SetSortsItems(false)
    local lastOptions, lastOff
    local function Options() return type(options) == "function" and options() or options end
    local function Fill()
        local opts = Options()
        lastOptions = opts
        combo:ClearItems()
        for _, o in ipairs(opts) do
            local value = o[1]
            combo:AddItem(combo:CreateItemEntry(o[2], function()
                set(value)
                DT.UI.Changed()
            end), ZO_COMBOBOX_SUPPRESS_UPDATE)
        end
        if combo.UpdateItems then combo:UpdateItems() end
    end
    local function SameOptions(a, b)
        if a == b then return true end
        if not a or not b or #a ~= #b then return false end
        for i = 1, #a do if a[i][1] ~= b[i][1] or a[i][2] ~= b[i][2] then return false end end
        return true
    end
    local function Refresh()
        local opts = Options()
        if not SameOptions(opts, lastOptions) then Fill() end
        local v = get()
        local labelText = ""
        for _, o in ipairs(opts) do if o[1] == v then labelText = o[2]; break end end
        combo:SetSelectedItemText(labelText)
        local off = disabled and disabled() or false
        if off ~= lastOff then
            -- only on change: SetEnabled also closes the dropdown list
            lastOff = off
            row:SetAlpha(off and 0.4 or 1)
            combo:SetEnabled(not off)
        end
    end
    Fill()
    Tooltip(container, tooltip, row, label, container.GetNamedChild and container:GetNamedChild("OpenDropdown"))
    W.Register(Refresh, text)
    Refresh()
    row.combo = combo
    return row, 30
end

-- Row of mutually exclusive buttons.
function W.Segmented(parent, width, text, options, get, set, disabled)
    local row = WM:CreateControl(nil, parent, CT_CONTROL)
    local labelH = (text and text ~= "") and 22 or 0
    local gap = 6
    -- many options (the trigger types): two rows rather than buttons too narrow for their names
    local perRow = #options
    if (width - (perRow - 1) * gap) / perRow < 80 then perRow = math.ceil(#options / 2) end
    local rows = math.ceil(#options / perRow)
    row:SetDimensions(width, labelH + rows * 28 + (rows - 1) * 4)
    row.segRows = rows
    if labelH > 0 then
        local label = W.Label(row, text, "ZoFontGame")
        label:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    end
    local segW = (width - (perRow - 1) * gap) / perRow
    local buttons = {}
    for i, o in ipairs(options) do
        local b = WM:CreateControl(nil, row, CT_BUTTON)
        b:SetDimensions(segW, 28)
        local col, line = (i - 1) % perRow, math.floor((i - 1) / perRow)
        b:SetAnchor(TOPLEFT, row, TOPLEFT, col * (segW + gap), labelH + line * 32)
        b:SetMouseEnabled(true)
        local bg = W.Backdrop(b, { 0.1, 0.1, 0.1, 0.9 }, { 0.4, 0.4, 0.4, 1 }, 1)
        bg:SetAnchorFill()
        local l = W.Label(b, o[2], "ZoFontGameSmall", nil, TEXT_ALIGN_CENTER)
        l:SetAnchorFill()
        buttons[i] = { control = b, bg = bg, value = o[1] }
    end
    local function Refresh()
        local v = get()
        for _, b in ipairs(buttons) do
            if b.value == v then
                b.bg:SetCenterColor(GOLD_BG[1], GOLD_BG[2], GOLD_BG[3], 1)
                b.bg:SetEdgeColor(GOLD[1], GOLD[2], GOLD[3], 1)
            else
                b.bg:SetCenterColor(0.1, 0.1, 0.1, 0.9)
                b.bg:SetEdgeColor(0.4, 0.4, 0.4, 1)
            end
        end
        local off = disabled and disabled() or false
        row:SetAlpha(off and 0.4 or 1)
    end
    for _, b in ipairs(buttons) do
        b.control:SetHandler("OnMouseEnter", function() if b.value ~= get() then b.bg:SetEdgeColor(1, 1, 1, 1) end end)
        b.control:SetHandler("OnMouseExit", Refresh)
        b.control:SetHandler("OnClicked", function()
            if disabled and disabled() then return end
            PlaySound(SOUNDS.DEFAULT_CLICK)
            set(b.value); Refresh(); DT.UI.Changed()
        end)
    end
    W.Register(Refresh, text)
    Refresh()
    return row, labelH + rows * 28 + (rows - 1) * 4
end

-- Color swatch (opens the game's color picker) + hex input.
function W.Color(parent, width, text, get, set, disabled)
    local row = WM:CreateControl(nil, parent, CT_CONTROL)
    row:SetDimensions(width, 30)
    local label = W.Label(row, text, "ZoFontGame")
    label:SetAnchor(LEFT, row, LEFT, 0, 0)
    label:SetDimensions(width - 190, 26)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    local swatch = WM:CreateControl(nil, row, CT_BUTTON)
    swatch:SetDimensions(56, 24)
    swatch:SetAnchor(LEFT, row, LEFT, width - 180, 0)
    swatch:SetMouseEnabled(true)
    local checker = W.Backdrop(swatch, { 0.2, 0.2, 0.2, 1 }, { 0.5, 0.5, 0.5, 1 }, 1)
    checker:SetAnchorFill()
    local fillC = W.Backdrop(swatch, { 1, 1, 1, 1 }, { 0, 0, 0, 0 }, 1)
    fillC:SetAnchor(TOPLEFT, swatch, TOPLEFT, 2, 2)
    fillC:SetAnchor(BOTTOMRIGHT, swatch, BOTTOMRIGHT, -2, -2)
    local hexRow = W.Edit(row, 110, nil, function() return U.ColorToHex(get()) end, function(v)
        local c = U.HexToColor(v)
        if c then set(c) end
    end, DT.L("RRGGBB or RRGGBBAA"), { noRefresh = true })
    hexRow:SetAnchor(LEFT, swatch, RIGHT, 10, 0)
    local function Refresh()
        local c = get() or { 1, 1, 1, 1 }
        fillC:SetCenterColor(c[1], c[2], c[3], c[4] or 1)
        hexRow.edit:SetText(U.ColorToHex(c))
        local off = disabled and disabled() or false
        row:SetAlpha(off and 0.4 or 1)
    end
    swatch:SetHandler("OnClicked", function()
        if disabled and disabled() then return end
        local c = get() or { 1, 1, 1, 1 }
        if COLOR_PICKER and COLOR_PICKER.Show then
            COLOR_PICKER:Show(function(r, g, b, a)
                set({ r, g, b, a or 1 }); Refresh(); DT.UI.Changed(true)
            end, c[1], c[2], c[3], c[4] or 1, text)
        end
    end)
    swatch:SetHandler("OnMouseEnter", function() checker:SetEdgeColor(GOLD[1], GOLD[2], GOLD[3], 1) end)
    swatch:SetHandler("OnMouseExit", function() checker:SetEdgeColor(0.5, 0.5, 0.5, 1) end)
    W.Register(Refresh, text)
    Refresh()
    return row, 30
end

-- Texture picker: real previews of the bundled bar textures.
function W.TextureSwatches(parent, width, text, get, set)
    local row = WM:CreateControl(nil, parent, CT_CONTROL)
    row:SetDimensions(width, 22 + 26)
    local label = W.Label(row, text, "ZoFontGame")
    label:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    local n = #C.BAR_TEXTURES
    local gap = 8
    local sw = math.min(120, (width - (n - 1) * gap) / n)
    local swatches = {}
    for i, o in ipairs(C.BAR_TEXTURES) do
        local b = WM:CreateControl(nil, row, CT_BUTTON)
        b:SetDimensions(sw, 24)
        b:SetAnchor(TOPLEFT, row, TOPLEFT, (i - 1) * (sw + gap), 22)
        b:SetMouseEnabled(true)
        -- drawn exactly like a tracker's bars (a full status bar with that texture), so the preview
        -- shows what the bars will look like (a plain texture control here stayed empty in game)
        local bar = WM:CreateControl(nil, b, CT_STATUSBAR)
        bar:SetAnchor(TOPLEFT, b, TOPLEFT, 1, 1)
        bar:SetAnchor(BOTTOMRIGHT, b, BOTTOMRIGHT, -1, -1)
        bar:SetTexture(o[1])
        bar:SetMinMax(0, 1)
        bar:SetValue(1)
        bar:SetColor(C.TEAL[1], C.TEAL[2], C.TEAL[3], 1)
        bar:SetDrawLevel(1)
        local edge = W.Backdrop(b, { 0, 0, 0, 0 }, { 0.4, 0.4, 0.4, 1 }, 1)
        edge:SetAnchorFill()
        edge:SetDrawLevel(2)
        Tooltip(b, o[2])
        swatches[i] = { control = b, edge = edge, value = o[1] }
    end
    local function Refresh()
        local v = get()
        for _, s in ipairs(swatches) do
            if s.value == v then
                s.edge:SetEdgeColor(GOLD[1], GOLD[2], GOLD[3], 1); s.edge:SetEdgeTexture(nil, 2, 2, 1)
            else
                s.edge:SetEdgeColor(0.4, 0.4, 0.4, 1); s.edge:SetEdgeTexture(nil, 1, 1, 1)
            end
        end
    end
    for _, s in ipairs(swatches) do
        s.control:SetHandler("OnClicked", function() set(s.value); Refresh(); DT.UI.Changed() end)
    end
    W.Register(Refresh, text)
    Refresh()
    return row, 48
end

------------------------------------------------------------------------------
-- Layout helpers
------------------------------------------------------------------------------

-- A page/tab body: a scroll container plus an ordered list of entries.
-- entry = { control, height (number or function), visible (function or nil), indent }
function W.NewPanel(parent, width, name)
    local scroll = W.ScrollContainer(name or UniqueName("Scroll"), parent)
    local content = scroll:GetNamedChild("ScrollChild")
    content:SetWidth(width)
    local panel = { scroll = scroll, content = content, width = width, entries = {} }
    function panel:Add(control, height, visible, indent)
        self.entries[#self.entries + 1] = { control, height, visible, indent or 0 }
        return control
    end
    function panel:Gap(h)
        local spacer = WM:CreateControl(nil, self.content, CT_CONTROL)
        spacer:SetDimensions(1, h)
        return self:Add(spacer, h)
    end
    function panel:Layout()
        local y = 0
        for _, e in ipairs(self.entries) do
            local control, height, visible, indent = e[1], e[2], e[3], e[4]
            local show = visible == nil or visible()
            control:SetHidden(not show)
            if show then
                local h = type(height) == "function" and height() or height
                if control.autoHeight then h = math.max(h, control.autoHeight()) end
                control:ClearAnchors()
                control:SetAnchor(TOPLEFT, self.content, TOPLEFT, indent, y)
                y = y + h + 8
            end
        end
        self.content:SetHeight(math.max(1, y + 20))
    end
    return panel
end

-- Pooled list rows: rows are created on demand and reused; extra rows are hidden.
-- rowHeight: a number, or function(item) for rows of different heights
function W.NewList(parent, width, rowHeight, factory)
    local list = { rows = {}, count = 0, rowHeight = rowHeight, total = 1 }
    local container = WM:CreateControl(nil, parent, CT_CONTROL)
    container:SetDimensions(width, 1)
    list.control = container
    function list:Set(items, setup)
        local y = 0
        for i, item in ipairs(items) do
            local r = self.rows[i]
            if not r then
                r = factory(container, i)
                self.rows[i] = r
            end
            r.control:SetHidden(false)
            r.control:ClearAnchors()
            r.control:SetAnchor(TOPLEFT, container, TOPLEFT, 0, y)
            setup(r, item, i)
            y = y + (type(rowHeight) == "function" and rowHeight(item) or rowHeight)
        end
        for i = #items + 1, #self.rows do self.rows[i].control:SetHidden(true) end
        self.count = #items
        self.total = math.max(1, y)
        container:SetHeight(self.total)
    end
    function list:Height() return self.total end
    return list
end
