local ADK = AntiDK2
local M   = {}
ADK.UI.Stuns = M

local PANEL_W   = 480
local SLOT_H    = 52
local MAX_SLOTS = 4
local ROLL_DELAY_MS = 700   -- how long "AVOID" shows before swapping to "ROLL NOW"
local WIN       = ADK.WINDOWS.avoid

local panel
local slots = {}

local function SavePos()
    local sv = ADK.savedVars
    sv[WIN.x] = panel:GetLeft() + panel:GetWidth()  / 2 - GuiRoot:GetWidth()  / 2
    sv[WIN.y] = panel:GetTop()  + panel:GetHeight() / 2 - GuiRoot:GetHeight() / 2
end

local function AnyVisible()
    for _, sl in ipairs(slots) do
        if sl.visible then return true end
    end
    return false
end

local function CurrentFont()
    return ADK.PresetFont(WIN.fontGroup, ADK.Get(WIN.font))
end

local function AvoidText(abilityName)
    local c = ADK.COLORS
    return ADK.Colorize(c.WHITE, abilityName) .. "  " .. ADK.Colorize(c.DANGER, "AVOID")
end

local function RollText(abilityName)
    local c = ADK.COLORS
    return ADK.Colorize(c.WHITE, abilityName) .. "  " .. ADK.Colorize(c.ROLL, "ROLL NOW")
end

local function ClearSlot(slot)
    slot.fadeHandle = ADK.CancelTimer(slot.fadeHandle)
    slot.rollHandle = ADK.CancelTimer(slot.rollHandle)
    slot.visible    = false
    slot.lbl:SetText("")
    slot.lbl:SetHidden(true)
end

-- First free slot, or slot 1 (recycled) when all are busy.
local function AcquireSlot()
    for i = 1, MAX_SLOTS do
        if not slots[i].visible then return slots[i] end
    end
    ClearSlot(slots[1])
    return slots[1]
end

-- Show `text` in a slot and schedule it to hide after the configured duration.
local function Present(slot, text)
    slot.lbl:SetText(text)
    slot.lbl:SetHidden(false)
    slot.visible = true
    panel:SetHidden(false)

    slot.fadeHandle = zo_callLater(function()
        slot.fadeHandle = nil
        ClearSlot(slot)
        if not AnyVisible() then panel:SetHidden(true) end
    end, ADK.Get("avoidFadeDelay") * 1000)
end

function M.Init()
    local c = ADK.COLORS

    panel = WINDOW_MANAGER:CreateTopLevelWindow(WIN.control)
    panel:SetDimensions(PANEL_W, MAX_SLOTS * SLOT_H)
    panel:SetAnchor(WIN.anchor, GuiRoot, WIN.anchor, ADK.Get(WIN.x), ADK.Get(WIN.y))
    panel:SetMovable(true)
    panel:SetMouseEnabled(true)
    panel:SetClampedToScreen(true)
    panel:SetHidden(true)
    panel:SetScale(ADK.Get(WIN.scale))
    panel:SetHandler("OnMoveStop", SavePos)

    -- No backdrop - pure floating text labels, one per slot
    local font = CurrentFont()
    for i = 1, MAX_SLOTS do
        local lbl = ADK.UI.MakeLabel("AntiDK2StunLbl" .. i, panel, font, c.DANGER)
        lbl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        lbl:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, (i - 1) * SLOT_H)
        lbl:SetDimensions(PANEL_W, SLOT_H)
        lbl:SetHidden(true)
        lbl:SetText("")

        slots[i] = { lbl = lbl, visible = false, fadeHandle = nil, rollHandle = nil }
    end
end

--- Apply a font string to every slot label.
function M.ApplyFont(font)
    for _, sl in ipairs(slots) do
        sl.lbl:SetFont(font)
    end
end

--- "<ability>  AVOID" for the configured duration.
function M.ShowAvoid(abilityName)
    Present(AcquireSlot(), AvoidText(abilityName))
end

--- "<ability>  AVOID", swapping to "ROLL NOW" after ROLL_DELAY_MS.
function M.ShowAvoidWithRoll(abilityName)
    local slot = AcquireSlot()
    Present(slot, AvoidText(abilityName))

    slot.rollHandle = zo_callLater(function()
        slot.rollHandle = nil
        if slot.visible then
            slot.lbl:SetText(RollText(abilityName))
        end
    end, ROLL_DELAY_MS)
end

function M.Reset()
    for _, sl in ipairs(slots) do
        ClearSlot(sl)
    end
    panel:SetHidden(true)
end

function M.GetPanel() return panel end
