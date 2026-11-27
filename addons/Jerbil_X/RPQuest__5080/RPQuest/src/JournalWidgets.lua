-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalWidgets = {}
local Widgets = Addon.JournalWidgets

Widgets.PANEL_NAME = "RPQuest_JournalPanel"

function Widgets.CreateStyledButton(name, parent, width, height, text, onClick)
    local btn = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    btn:SetDimensions(width, height)
    btn:SetMouseEnabled(true)
    btn:SetFont("ZoFontGameBold")
    btn:SetNormalFontColor(0.91, 0.83, 0.63, 1)
    btn:SetMouseOverFontColor(1, 1, 1, 1)

    local bg = WINDOW_MANAGER:CreateControl(name .. "_Bg", btn, CT_BACKDROP)
    bg:SetDimensions(width, height)
    bg:SetAnchor(TOPLEFT, btn, TOPLEFT, 0, 0)
    bg:SetCenterColor(0.08, 0.08, 0.08, 0.78)
    bg:SetEdgeColor(0.65, 0.56, 0.34, 0.85)
    btn._bg = bg

    btn:SetText(text or "")
    btn:SetHandler("OnClicked", function()
        PlaySound(SOUNDS.DEFAULT_CLICK)
        if onClick then onClick() end
    end)
    return btn
end

function Widgets.CreateEditBoxWithBackdrop(name, parent, width, height, maxChars, isMultiLine, onTextChanged, selectAllOnFocus)
    local bg = WINDOW_MANAGER:CreateControl(name .. "_Bg", parent, CT_BACKDROP)
    bg:SetDimensions(width, height)
    bg:SetMouseEnabled(true)
    bg:SetCenterColor(0.04, 0.04, 0.04, 0.82)
    bg:SetEdgeColor(0.68, 0.58, 0.36, 0.80)

    local edit = WINDOW_MANAGER:CreateControl(name, bg, CT_EDITBOX)
    edit._bg = bg
    local editWidth = isMultiLine and (width - 24) or (width - 12)
    edit:SetDimensions(editWidth, height - 8)
    edit:SetAnchor(TOPLEFT, bg, TOPLEFT, 6, 4)
    edit:SetMouseEnabled(true)
    edit:SetEditEnabled(true)
    edit:SetFont("ZoFontGame")
    edit:SetColor(1, 1, 1, 1)
    edit:SetMaxInputChars(maxChars or 256)
    edit:SetMultiLine(isMultiLine)
    edit:SetNewLineEnabled(isMultiLine)
    if selectAllOnFocus and edit.SetSelectAllOnFocus then
        edit:SetSelectAllOnFocus(true)
    end
    edit:SetText("")

    local scrollbar
    local syncingScroll = false
    local function UpdateScrollbar()
        if not scrollbar then return end
        local extents = edit.GetScrollExtents and edit:GetScrollExtents() or 0
        local hasOverflow = extents > 0
        scrollbar:SetHidden(not hasOverflow)
        if hasOverflow then
            scrollbar:SetMinMax(1, extents + 1)
            local topLine = edit.GetTopLineIndex and edit:GetTopLineIndex() or 1
            local clamped = math.max(1, math.min(extents + 1, topLine))
            syncingScroll = true
            scrollbar:SetValue(clamped)
            syncingScroll = false
        end
    end

    if isMultiLine then
        scrollbar = WINDOW_MANAGER:CreateControlFromVirtual(name .. "_ScrollBar", bg, "ZO_VerticalScrollbarBase")
        if scrollbar then
            scrollbar:SetAnchor(TOPRIGHT, bg, TOPRIGHT, -4, 20)
            scrollbar:SetAnchor(BOTTOMRIGHT, bg, BOTTOMRIGHT, -4, -20)
            scrollbar:SetHidden(true)
            scrollbar:SetHandler("OnValueChanged", function(_, value)
                if syncingScroll then return end
                local extents = edit.GetScrollExtents and edit:GetScrollExtents() or 0
                local targetLine = math.max(1, math.min(extents + 1, math.floor(value + 0.5)))
                if edit.SetTopLineIndex then
                    edit:SetTopLineIndex(targetLine)
                end
            end)
        end
        edit._scrollbar = scrollbar
        edit._updateScrollbar = UpdateScrollbar

        edit:SetHandler("OnMouseWheel", function(ctrl, delta, _, _, shift)
            if not ctrl.GetTopLineIndex or not ctrl.SetTopLineIndex or not ctrl.GetScrollExtents then
                return
            end
            local step = shift and (delta * 10) or delta
            local extents = ctrl:GetScrollExtents()
            local nextLine = math.max(1, math.min(extents + 1, ctrl:GetTopLineIndex() - step))
            ctrl:SetTopLineIndex(nextLine)
            UpdateScrollbar()
        end)
    end

    local function FocusEditBox()
        if edit._disabled then return end
        edit:SetEditEnabled(true)
        edit:TakeFocus()
    end

    bg:SetHandler("OnMouseDown", FocusEditBox)
    edit:SetHandler("OnMouseDown", FocusEditBox)
    edit:SetHandler("OnEscape", function(ctrl)
        ctrl:LoseFocus()
    end)
    if not isMultiLine then
        edit:SetHandler("OnEnter", function(ctrl)
            ctrl:LoseFocus()
        end)
    end
    edit:SetHandler("OnFocusGained", function()
        edit._focused = true
        bg:SetEdgeColor(0.95, 0.85, 0.50, 1.0)
        if selectAllOnFocus and edit.SelectAll then
            edit:SelectAll()
        end
        PlaySound(SOUNDS.EDIT_CLICK)
    end)
    edit:SetHandler("OnFocusLost", function()
        edit._focused = false
        if edit._hasWarning then
            bg:SetEdgeColor(0.95, 0.28, 0.28, 1.0)
        else
            bg:SetEdgeColor(0.68, 0.58, 0.36, 0.80)
        end
    end)
    if onTextChanged or isMultiLine then
        edit:SetHandler("OnTextChanged", function(ctrl)
            UpdateScrollbar()
            if onTextChanged then
                onTextChanged(ctrl:GetText())
            end
        end)
    end

    return bg, edit
end

function Widgets.CycleIndex(currentIndex, totalCount, delta)
    if totalCount <= 0 then return nil end
    local cur = currentIndex or 1
    if delta < 0 then
        return (cur > 1) and (cur - 1) or totalCount
    end
    return (cur < totalCount) and (cur + 1) or 1
end

function Widgets.SetEditBoxEnabled(bg, edit, enabled)
    local isEnabled = (enabled ~= false)
    if edit then
        edit._disabled = not isEnabled
        if edit.SetEditEnabled then edit:SetEditEnabled(isEnabled) end
        if edit.SetMouseEnabled then edit:SetMouseEnabled(isEnabled) end
        if not isEnabled and edit._focused and edit.LoseFocus then
            edit:LoseFocus()
        end
    end
    if bg then
        if bg.SetMouseEnabled then bg:SetMouseEnabled(isEnabled) end
        if bg.SetAlpha then bg:SetAlpha(isEnabled and 1 or 0.45) end
    end
end

local function IsControlOrAncestorHidden(ctrl)
    local current = ctrl
    while current do
        if current.IsHidden and current:IsHidden() then
            return true
        end
        current = current.GetParent and current:GetParent() or nil
    end
    return false
end

local function FindNextFocusableEditBox(editBoxes, startIndex, direction)
    local count = #editBoxes
    if count == 0 then return nil end
    local idx = startIndex
    for _ = 1, count do
        idx = Widgets.CycleIndex(idx, count, direction)
        local candidate = editBoxes[idx]
        if candidate and not IsControlOrAncestorHidden(candidate) and candidate._disabled ~= true then
            return candidate
        end
    end
    return nil
end

function Widgets.RegisterTabChain(editBoxes, scrollContainer)
    if type(editBoxes) ~= "table" or #editBoxes == 0 then return end
    local count = #editBoxes
    for i = 1, count do
        local edit = editBoxes[i]
        if edit then
            edit:SetHandler("OnTab", function(ctrl)
                local direction = IsShiftKeyDown() and -1 or 1
                local target = FindNextFocusableEditBox(editBoxes, i, direction)
                if not target or target == ctrl then return end
                target:TakeFocus()
                if scrollContainer then
                    local scrollTarget = target._bg or target
                    if not ZO_Scroll_IsControlFullyInView(scrollContainer, scrollTarget) then
                        ZO_Scroll_ScrollControlIntoCentralView(scrollContainer, scrollTarget, false)
                    end
                end
            end)
        end
    end
end

function Widgets.CreateIconButton(name, parent, size, normalTex, downTex, overTex, disabledTex, tooltipText, onClick)
    local btn = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    btn:SetDimensions(size, size)
    btn:SetMouseEnabled(true)
    if normalTex and btn.SetNormalTexture then btn:SetNormalTexture(normalTex) end
    if downTex and btn.SetPressedTexture then btn:SetPressedTexture(downTex) end
    if overTex and btn.SetMouseOverTexture then btn:SetMouseOverTexture(overTex) end
    if disabledTex and btn.SetDisabledTexture then btn:SetDisabledTexture(disabledTex) end

    btn:SetHandler("OnMouseEnter", function(ctrl)
        if tooltipText and tooltipText ~= "" then
            ZO_Tooltips_ShowTextTooltip(ctrl, TOP, tooltipText)
        end
    end)
    btn:SetHandler("OnMouseExit", function()
        ZO_Tooltips_HideTextTooltip()
    end)
    btn:SetHandler("OnClicked", function()
        PlaySound(SOUNDS.DEFAULT_CLICK)
        if onClick then onClick() end
    end)
    return btn
end

function Widgets.CreateCheckButton(name, parent, labelText, onToggle)
    local btn = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_CheckButton")
    btn:SetDimensions(20, 20)
    ZO_CheckButton_SetLabelText(btn, labelText or "")
    ZO_CheckButton_SetToggleFunction(btn, function(_, isChecked)
        if onToggle then onToggle(isChecked == true) end
    end)
    return btn
end
