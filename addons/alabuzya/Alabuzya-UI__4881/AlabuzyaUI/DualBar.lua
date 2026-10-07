local AlabuzyaUI = AlabuzyaUI
AlabuzyaUI.DualBar = {}
-- AlabuzyaUI dual weapon bar, alabuzya, 2026-09-24. GPL-3.0-or-later.
local rows = {}
local emptyActive = {}
local root, currentStyle
local registered = false
local layoutPending = false
local function ScheduleLayout()
    if layoutPending then return end
    layoutPending=true
    zo_callLater(function()
        layoutPending=false
        if root then AlabuzyaUI.DualBar.Layout(root,currentStyle) end
    end,0)
end
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
function AlabuzyaUI.DualBar.Layout(topLevelCtrl, style)
    root, currentStyle = topLevelCtrl, style
    local container = GetControl(root, "ActionBarContainer")
    local size, gap = style.abilitySlotWidth, style.abilitySlotOffsetX
    local iconSize = math.max(1, size - 8)
    local offset = ((size + gap) * 5) / 2
    for i = 1, 5 do
        local button = ZO_ActionBar_GetButton(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + i)
        if button and button.slot then
            button.slot:SetDimensions(iconSize, iconSize)
            if button.icon then
                button.icon:ClearAnchors()
                button.icon:SetAnchor(CENTER,button.slot,CENTER,0,0)
                button.icon:SetDimensions(iconSize,iconSize)
            end
            if button.timerText then
                local fontSize = math.floor(size * 0.52 + 0.5)
                button.timerText:SetFont(AlabuzyaUI.Theme.Font(fontSize,'thick-outline'))
                button.timerText:SetColor(1, 1, 1, 1)
                button.timerText:SetDrawLayer(DL_OVERLAY)
            end
            button.slot:ClearAnchors()
            if i == 6 then
                button.slot:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
            else
                button.slot:SetAnchor(BOTTOMLEFT, container, BOTTOM, -offset + (i - 1) * (size + gap) + 4, 4)
            end
            if not rows[i] then
                local cell = WINDOW_MANAGER:CreateControl("AlabuzyaUIInactiveSlot" .. i, root, CT_CONTROL)
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
    local sideSize=iconSize+12
    local sideX=offset+sideSize/2+8
    local sideY=4-iconSize/2
    if quick and quick.slot then
        quick.slot:SetDimensions(sideSize,sideSize)
        if quick.icon then
            quick.icon:ClearAnchors() quick.icon:SetAnchor(CENTER,quick.slot,CENTER,0,0)
            quick.icon:SetDimensions(sideSize,sideSize)
        end
        if quick.button then quick.button:SetDimensions(sideSize,sideSize) end
        quick.slot:ClearAnchors()
        quick.slot:SetAnchor(CENTER,container,BOTTOM,-sideX,sideY)
    end
    local ultimate = ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX+1)
    if ultimate and ultimate.slot then
        ultimate.slot:SetDimensions(sideSize,sideSize)
        if ultimate.icon then
            ultimate.icon:ClearAnchors() ultimate.icon:SetAnchor(CENTER,ultimate.slot,CENTER,0,0)
            ultimate.icon:SetDimensions(sideSize,sideSize)
        end
        if ultimate.button then ultimate.button:SetDimensions(sideSize,sideSize) end
        if ultimate.status then ultimate.status:SetDimensions(sideSize,sideSize) end
        ultimate.slot:ClearAnchors()
        ultimate.slot:SetAnchor(CENTER,container,BOTTOM,sideX,sideY)
        if ultimate.timerText then
            ultimate.timerText:SetFont(AlabuzyaUI.Theme.Font(math.floor(size * 0.52 + 0.5),'thick-outline'))
            ultimate.timerText:SetColor(1, 1, 1, 1)
            ultimate.timerText:SetDrawLayer(DL_OVERLAY)
        end
    end
    if not registered then
        registered = true
        for _, event in ipairs({EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED,
            EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, EVENT_HOTBAR_SLOT_UPDATED,
            EVENT_ACTIVE_WEAPON_PAIR_CHANGED, EVENT_PLAYER_ACTIVATED}) do
            EVENT_MANAGER:RegisterForEvent("AlabuzyaUIDualBar", event, ScheduleLayout)
        end
        -- Native quickslot refreshes also reanchor without a hotbar event.
        -- Restore our layout after those methods, once per update batch.
        for _,button in ipairs({quick,ultimate}) do
            if ZO_PostHook then
                if button.ApplyAnchor then ZO_PostHook(button,'ApplyAnchor',ScheduleLayout) end
                if button.ApplyStyle then ZO_PostHook(button,'ApplyStyle',ScheduleLayout) end
            end
        end
    end
    Refresh()
end
