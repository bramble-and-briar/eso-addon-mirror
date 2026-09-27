-- DIAhelp dual weapon bar, alabuzya, 2026-09-24. GPL-3.0-or-later.
local rows = {}
local emptyActive = {}
local root, currentStyle
local registered = false
local function OtherBar()
    local active = GetActiveHotbarCategory()
    if active == HOTBAR_CATEGORY_PRIMARY then return HOTBAR_CATEGORY_BACKUP end
    if active == HOTBAR_CATEGORY_BACKUP then return HOTBAR_CATEGORY_PRIMARY end
    return nil -- Werewolf, siege and other special bars are not weapon pairs.
end
local function Refresh()
    if not root then return end
    local other = OtherBar()
    for i, cell in ipairs(rows) do
        local slotIndex = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + i
        local texture = other and GetSlotTexture(slotIndex, other)
        cell.icon:SetTexture(texture or "")
        cell.icon:SetHidden(not texture or texture == "")
        cell:SetHidden(false)
    end
end
function DIAhelp_LayoutDualBar(topLevelCtrl, style)
    root, currentStyle = topLevelCtrl, style
    local container = GetControl(root, "ActionBarContainer")
    local size, gap = style.abilitySlotWidth, style.abilitySlotOffsetX
    local offset = ((size + gap) * 5) / 2
    for i = 1, 5 do
        local button = ZO_ActionBar_GetButton(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + i)
        if button and button.slot then
            if button.timerText then
                local fontSize = math.floor(size * 0.52 + 0.5)
                button.timerText:SetFont("$(BOLD_FONT)|" .. fontSize .. "|thick-outline")
                button.timerText:SetColor(1, 1, 1, 1)
                button.timerText:SetDrawLayer(DL_OVERLAY)
            end
            button.slot:ClearAnchors()
            if i == 6 then
                button.slot:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
            else
                button.slot:SetAnchor(BOTTOMLEFT, container, BOTTOM, -offset + (i - 1) * (size + gap), 0)
            end
            if not rows[i] then
                local cell = WINDOW_MANAGER:CreateControl("DIAhelpInactiveSlot" .. i, root, CT_CONTROL)
                cell:SetMouseEnabled(false)
                cell.bg = WINDOW_MANAGER:CreateControl(nil, cell, CT_BACKDROP)
                cell.bg:SetAnchorFill()
                cell.bg:SetDrawLayer(DL_OVERLAY)
                cell.bg:SetDrawLevel(10)
                cell.bg:SetCenterColor(0.02, 0.02, 0.02, 0.9)
                cell.bg:SetEdgeColor(0.55, 0.48, 0.32, 1)
                cell.bg:SetEdgeTexture(nil, 1, 1, 1)
                cell.icon = WINDOW_MANAGER:CreateControl(nil, cell, CT_TEXTURE)
                cell.icon:SetAnchor(TOPLEFT, cell, TOPLEFT, 3, 3)
                cell.icon:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, -3, -3)
                cell.icon:SetAlpha(0.65)
                cell.icon:SetDrawLayer(DL_OVERLAY)
                cell.icon:SetDrawLevel(11)
                rows[i] = cell
            end
            local cell = rows[i]
            cell:SetDimensions(size, size)
            cell:ClearAnchors()
            cell:SetAnchor(BOTTOMLEFT, container, BOTTOM, -offset + (i - 1) * (size + gap), size + gap)
            if not emptyActive[i] then
                local frame = WINDOW_MANAGER:CreateControl(nil, root, CT_BACKDROP)
                frame:SetMouseEnabled(false)
                frame:SetCenterColor(0.02, 0.02, 0.02, 0.9)
                frame:SetEdgeColor(0.55, 0.48, 0.32, 1)
                frame:SetEdgeTexture(nil, 1, 1, 1)
                frame:SetDrawLayer(DL_OVERLAY)
                frame:SetDrawLevel(10)
                emptyActive[i] = frame
            end
            local frame = emptyActive[i]
            frame:ClearAnchors()
            frame:SetDimensions(size, size)
            frame:SetAnchor(BOTTOMLEFT, container, BOTTOM, -offset + (i - 1) * (size + gap), 0)
            local activeTexture = GetSlotTexture(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + i, GetActiveHotbarCategory())
            frame:SetHidden(activeTexture ~= nil and activeTexture ~= "")
        end
    end
    local quick = ZO_ActionBar_GetButton(1, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    if quick and quick.slot then
        quick.slot:ClearAnchors()
        quick.slot:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, 0, (size + gap) / 2)
    end
    local ultimate = ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1)
    if ultimate and ultimate.slot then
        ultimate.slot:ClearAnchors()
        ultimate.slot:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, (size + gap) / 2)
        if ultimate.timerText then
            ultimate.timerText:SetFont("$(BOLD_FONT)|" .. math.floor(size * 0.52 + 0.5) .. "|thick-outline")
            ultimate.timerText:SetColor(1, 1, 1, 1)
            ultimate.timerText:SetDrawLayer(DL_OVERLAY)
        end
    end
    if not registered then
        registered = true
        local function Update()
            -- Run after the game's own action-bar reanchoring and assignments.
            zo_callLater(function()
                if root then DIAhelp_LayoutDualBar(root, currentStyle) end
            end, 0)
        end
        for _, event in ipairs({EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED,
            EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, EVENT_HOTBAR_SLOT_UPDATED,
            EVENT_ACTIVE_WEAPON_PAIR_CHANGED, EVENT_PLAYER_ACTIVATED}) do
            EVENT_MANAGER:RegisterForEvent("DIAhelpDualBar", event, Update)
        end
    end
    Refresh()
end
