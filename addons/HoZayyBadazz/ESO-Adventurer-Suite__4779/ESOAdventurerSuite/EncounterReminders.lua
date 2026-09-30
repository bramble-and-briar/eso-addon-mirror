-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Text-only pre-encounter reminders for equipment repair and potion readiness.
-- Repair and potion reminders are independently movable and resizable.

local EPC = ESOProgressionCoach
EPC.EncounterReminders = EPC.EncounterReminders or {}
local R = EPC.EncounterReminders
local wm = WINDOW_MANAGER

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d
end

local ARMOR_SLOTS = {
    EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST,
    EQUIP_SLOT_HAND, EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET,
}

function R:ArmorNeedsRepair()
    if BAG_WORN == nil then return false end
    for i = 1, #ARMOR_SLOTS do
        local slot = ARMOR_SLOTS[i]
        if slot ~= nil then
            local hasItem = safe(HasItemInSlot, false, BAG_WORN, slot) == true
            if hasItem and safe(DoesItemHaveDurability, false, BAG_WORN, slot) == true then
                local condition = tonumber(safe(GetItemCondition, 100, BAG_WORN, slot)) or 100
                if condition < 100 then return true end
            end
        end
    end
    return false
end

function R:HasAttackableTarget()
    return safe(IsUnitAttackable, false, "reticleover") == true
end

function R:IsEncounterContext()
    -- Being inside a dungeon or raid is not enough by itself.  Pre-encounter
    -- reminders should only appear when the player is actually lining up an
    -- attackable target, with a short grace period after the reticle moves off.
    return self.attackableTarget == true or self.preEncounterGrace == true
end

function R:OnReticleTargetChanged()
    local attackable = self:HasAttackableTarget()
    self.attackableTarget = attackable
    self.reticleGeneration = (tonumber(self.reticleGeneration) or 0) + 1
    local generation = self.reticleGeneration

    if attackable then
        self.preEncounterGrace = true
        self:Refresh()
        return
    end

    if self.preEncounterGrace ~= true then
        self:Refresh()
        return
    end

    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if generation ~= self.reticleGeneration then return end
            if self:HasAttackableTarget() then return end
            self.preEncounterGrace = false
            self:Refresh()
        end, 2500)
    else
        self.preEncounterGrace = false
        self:Refresh()
    end
end

local function anchorWindow(control, leftKey, topKey, presetKey, defaultX, defaultY)
    if not control then return end
    control:ClearAnchors()
    local preset = tostring(EPC.saved and EPC.saved[presetKey] or "CUSTOM")
    local margin = 24
    if preset == "TOPLEFT" then
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, margin, margin)
        return
    elseif preset == "TOPRIGHT" then
        control:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -margin, margin)
        return
    elseif preset == "BOTTOMLEFT" then
        control:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, margin, -margin)
        return
    elseif preset == "BOTTOMRIGHT" then
        control:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, -margin, -margin)
        return
    end

    local left = tonumber(EPC.saved and EPC.saved[leftKey]) or -1
    local top = tonumber(EPC.saved and EPC.saved[topKey]) or -1
    if left >= 0 and top >= 0 then
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        control:SetAnchor(TOP, GuiRoot, TOP, defaultX, defaultY)
    end
end

function R:Anchor()
    anchorWindow(self.repairFrame, "encounterRepairLeft", "encounterRepairTop", "encounterRepairPreset", 0, 145)
    anchorWindow(self.potionFrame, "encounterPotionLeft", "encounterPotionTop", "encounterPotionPreset", 0, 173)
end

local function createReminderWindow(name, text, width, r, g, b, leftKey, topKey, presetKey)
    local frame = wm:CreateTopLevelWindow(name)
    frame:SetDimensions(width, 32)
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)

    local label = wm:CreateControl(name .. "Label", frame, CT_LABEL)
    label:SetAnchorFill(frame)
    label:SetFont("ZoFontGameBold")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(r, g, b, 1)
    label:SetText(text)

    frame:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            EPC.saved[leftKey] = control:GetLeft()
            EPC.saved[topKey] = control:GetTop()
            EPC.saved[presetKey] = "CUSTOM"
        end
    end)
    return frame, label
end

function R:Create()
    self.repairFrame, self.repairLabel = createReminderWindow(
        "EAS_EncounterRepairReminder", "ARMOR NEEDS REPAIR", 250, 1.0, 0.45, 0.30,
        "encounterRepairLeft", "encounterRepairTop", "encounterRepairPreset")
    self.potionFrame, self.potionLabel = createReminderWindow(
        "EAS_EncounterPotionReminder", "DRINK POTION BEFORE NEXT ENCOUNTER", 390, 0.38, 0.90, 1.0,
        "encounterPotionLeft", "encounterPotionTop", "encounterPotionPreset")
    self:Anchor()
end

function R:Refresh()
    if not self.repairFrame or not self.potionFrame or not EPC.saved then return end

    if self.nativeEditHudPreview029780 == true then
        if self.repairLabel then
            self.repairLabel:SetHidden(false)
            self.repairLabel:SetAlpha(1)
            self.repairLabel:SetText("ARMOR NEEDS REPAIR")
        end
        if self.potionLabel then
            self.potionLabel:SetHidden(false)
            self.potionLabel:SetAlpha(1)
            self.potionLabel:SetText("DRINK POTION BEFORE NEXT ENCOUNTER")
        end
        self.repairFrame:SetHidden(false)
        self.potionFrame:SetHidden(false)
        self.repairFrame:SetAlpha(1)
        self.potionFrame:SetAlpha(1)
        self.repairFrame:SetScale(tonumber(EPC.saved.encounterRepairScale) or 1.0)
        self.potionFrame:SetScale(tonumber(EPC.saved.encounterPotionScale) or 1.0)
        return
    end

    local enabled = EPC.saved.showEncounterReminders ~= false
    local inCombat = safe(IsUnitInCombat, false, "player") == true
    local context = self.layoutMode == true or self:IsEncounterContext()
    local ready = enabled and not inCombat and context

    local showRepair = ready and EPC.saved.showEncounterRepairReminder ~= false and (self.layoutMode == true or self:ArmorNeedsRepair())
    local showPotion = ready and EPC.saved.showEncounterPotionReminder ~= false

    self.repairFrame:SetHidden(not showRepair)
    self.potionFrame:SetHidden(not showPotion)
    self.repairFrame:SetScale(tonumber(EPC.saved.encounterRepairScale) or 1.0)
    self.potionFrame:SetScale(tonumber(EPC.saved.encounterPotionScale) or 1.0)
end

function R:SetLayoutMode(active)
    self.layoutMode = active == true
    for _, frame in ipairs({ self.repairFrame, self.potionFrame }) do
        if frame then
            frame:SetMouseEnabled(self.layoutMode)
            frame:SetMovable(self.layoutMode)
        end
    end

    if self.layoutMode then
        if self.repairLabel then self.repairLabel:SetText("ARMOR NEEDS REPAIR") end
        if self.potionLabel then self.potionLabel:SetText("DRINK POTION BEFORE NEXT ENCOUNTER") end
        if self.repairFrame then self.repairFrame:SetHidden(false) end
        if self.potionFrame then self.potionFrame:SetHidden(false) end
        if self.repairFrame and EPC.saved then self.repairFrame:SetScale(tonumber(EPC.saved.encounterRepairScale) or 1.0) end
        if self.potionFrame and EPC.saved then self.potionFrame:SetScale(tonumber(EPC.saved.encounterPotionScale) or 1.0) end
    else
        self:Refresh()
    end
end

function R:SetNativeEditHudPreview(active)
    active = active == true
    self.nativeEditHudPreview029780 = active

    if active then
        if self.repairLabel then
            self.repairLabel:SetHidden(false)
            self.repairLabel:SetAlpha(1)
            self.repairLabel:SetText("ARMOR NEEDS REPAIR")
            if self.repairLabel.SetDrawLayer and DL_OVERLAY then self.repairLabel:SetDrawLayer(DL_OVERLAY) end
            if self.repairLabel.SetDrawLevel then self.repairLabel:SetDrawLevel(410) end
        end
        if self.potionLabel then
            self.potionLabel:SetHidden(false)
            self.potionLabel:SetAlpha(1)
            self.potionLabel:SetText("DRINK POTION BEFORE NEXT ENCOUNTER")
            if self.potionLabel.SetDrawLayer and DL_OVERLAY then self.potionLabel:SetDrawLayer(DL_OVERLAY) end
            if self.potionLabel.SetDrawLevel then self.potionLabel:SetDrawLevel(410) end
        end

        for _, frame in ipairs({ self.repairFrame, self.potionFrame }) do
            if frame then
                frame:SetHidden(false)
                frame:SetAlpha(1)
                frame:SetMouseEnabled(false)
                frame:SetMovable(false)
                if frame.SetTopLevel then frame:SetTopLevel(true) end
                if frame.SetDrawTier and DT_HIGH then frame:SetDrawTier(DT_HIGH) end
                if frame.SetDrawLayer and DL_OVERLAY then frame:SetDrawLayer(DL_OVERLAY) end
                if frame.SetDrawLevel then frame:SetDrawLevel(400) end
            end
        end
        if self.repairFrame and EPC.saved then self.repairFrame:SetScale(tonumber(EPC.saved.encounterRepairScale) or 1.0) end
        if self.potionFrame and EPC.saved then self.potionFrame:SetScale(tonumber(EPC.saved.encounterPotionScale) or 1.0) end
    else
        self:Refresh()
    end
end

function R:SetRepairPreset(preset)
    if not EPC.saved then return end
    EPC.saved.encounterRepairPreset = tostring(preset or "CUSTOM")
    self:Anchor()
end

function R:SetPotionPreset(preset)
    if not EPC.saved then return end
    EPC.saved.encounterPotionPreset = tostring(preset or "CUSTOM")
    self:Anchor()
end

function R:ResetRepairPosition()
    if not EPC.saved then return end
    EPC.saved.encounterRepairLeft = -1
    EPC.saved.encounterRepairTop = -1
    EPC.saved.encounterRepairPreset = "CUSTOM"
    self:Anchor()
end

function R:ResetPotionPosition()
    if not EPC.saved then return end
    EPC.saved.encounterPotionLeft = -1
    EPC.saved.encounterPotionTop = -1
    EPC.saved.encounterPotionPreset = "CUSTOM"
    self:Anchor()
end

function R:ResetPosition()
    self:ResetRepairPosition()
    self:ResetPotionPosition()
end

function R:Initialize()
    self.layoutMode = false
    self.attackableTarget = false
    self.preEncounterGrace = false
    self.reticleGeneration = 0
    self:Create()
    local prefix = EPC.name .. "_EncounterReminders"

    if EVENT_PLAYER_COMBAT_STATE then
        EPC.Runtime:RegisterEvent("EncounterReminders","Combat",EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
            if inCombat == true then
                self.attackableTarget = false
                self.preEncounterGrace = false
                self.reticleGeneration = (tonumber(self.reticleGeneration) or 0) + 1
            end
            self:Refresh()
        end)
    end
    if EVENT_PLAYER_ACTIVATED then
        EPC.Runtime:RegisterEvent("EncounterReminders","Activated",EVENT_PLAYER_ACTIVATED, function() self:Refresh() end)
    end
    if EVENT_RETICLE_TARGET_CHANGED then
        EPC.Runtime:RegisterEvent("EncounterReminders","Reticle",EVENT_RETICLE_TARGET_CHANGED, function() self:OnReticleTargetChanged() end)
    end
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        local filters = nil
        if REGISTER_FILTER_BAG_ID and BAG_WORN then filters = { { REGISTER_FILTER_BAG_ID, BAG_WORN } } end
        EPC.Runtime:RegisterEvent("EncounterReminders", "Worn", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function() self:Refresh() end, filters)
    end
    self:Refresh()
end
