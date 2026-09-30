-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

local EPC = ESOProgressionCoach
EPC.RepairCostOverlay = EPC.RepairCostOverlay or {}
local R = EPC.RepairCostOverlay
local wm = WINDOW_MANAGER

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok,a,b,c,d,e,f = pcall(fn,...)
    if not ok then return fallback end
    return a,b,c,d,e,f
end

local function moneyText(value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    if type(ZO_CommaDelimitNumber) == "function" then
        return tostring(ZO_CommaDelimitNumber(value)) .. "g"
    end
    return tostring(value) .. "g"
end

local function cleanItemName(name)
    name = tostring(name or "")
    if name == "" then return "Equipped item" end
    if type(zo_strformat) == "function" and SI_TOOLTIP_ITEM_NAME then
        local ok, formatted = pcall(zo_strformat, SI_TOOLTIP_ITEM_NAME, name)
        if ok and formatted and formatted ~= "" then return formatted end
    end
    return name
end

local function setDrawOrder(control, tier, layer, level)
    if not control then return end
    pcall(function()
        if control.SetDrawTier and tier ~= nil then control:SetDrawTier(tier) end
        if control.SetDrawLayer and layer ~= nil then control:SetDrawLayer(layer) end
        if control.SetDrawLevel and level ~= nil then control:SetDrawLevel(level) end
    end)
end

local function itemName(slot)
    if BAG_WORN == nil then return "" end
    local link = safe(GetItemLink, "", BAG_WORN, slot, LINK_STYLE_DEFAULT or 0)
    if link and link ~= "" and type(GetItemLinkName) == "function" then
        return cleanItemName(safe(GetItemLinkName, "", link))
    end
    return ""
end

function R:GetSlots()
    local slots = {}
    local function add(slot, label)
        if slot ~= nil then slots[#slots + 1] = {slot = slot, label = label} end
    end
    add(EQUIP_SLOT_HEAD, "HEAD")
    add(EQUIP_SLOT_SHOULDERS, "SHOULDERS")
    add(EQUIP_SLOT_CHEST, "CHEST")
    add(EQUIP_SLOT_HAND, "HANDS")
    add(EQUIP_SLOT_WAIST, "WAIST")
    add(EQUIP_SLOT_LEGS, "LEGS")
    add(EQUIP_SLOT_FEET, "FEET")
    add(EQUIP_SLOT_MAIN_HAND, "MAIN HAND")
    add(EQUIP_SLOT_OFF_HAND, "OFF HAND")
    add(EQUIP_SLOT_BACKUP_MAIN, "BACK MAIN")
    add(EQUIP_SLOT_BACKUP_OFF, "BACK OFF")
    return slots
end

function R:Anchor()
    if not self.frame then return end
    self.frame:ClearAnchors()
    local left = tonumber(EPC.saved and EPC.saved.repairCostLeft) or -1
    local top = tonumber(EPC.saved and EPC.saved.repairCostTop) or -1
    if left >= 0 and top >= 0 then
        self.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        self.frame:SetAnchor(RIGHT, GuiRoot, RIGHT, -32, 35)
    end
end

function R:AnchorCompact()
    if not self.compactFrame then return end
    self.compactFrame:ClearAnchors()
    local left = tonumber(EPC.saved and EPC.saved.repairCostCompactLeft) or -1
    local top = tonumber(EPC.saved and EPC.saved.repairCostCompactTop) or -1
    local rootW = GuiRoot and tonumber(GuiRoot:GetWidth()) or 0
    local rootH = GuiRoot and tonumber(GuiRoot:GetHeight()) or 0
    local savedOnScreen = left >= 0 and top >= 0
        and (rootW <= 0 or left <= rootW - 40)
        and (rootH <= 0 or top <= rootH - 24)
    if savedOnScreen then
        self.compactFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        if EPC.saved then
            EPC.saved.repairCostCompactLeft = -1
            EPC.saved.repairCostCompactTop = -1
        end
        self.compactFrame:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -38, 92)
    end
end

function R:Create()
    local frame = wm:CreateTopLevelWindow("EAS_RepairCostOverlay")
    local detailWidth = math.max(320, math.min(800, tonumber(EPC.saved and EPC.saved.repairCostWidth) or 410))
    frame:SetDimensions(detailWidth, 98)
    if frame.SetDimensionConstraints then frame:SetDimensionConstraints(320, 98, 800, 420) end
    if frame.SetResizeHandleSize then frame:SetResizeHandleSize(0) end
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)

    local bg = wm:CreateControl("EAS_RepairCostOverlay_BG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0.012, 0.015, 0.022, 0.88)
    bg:SetEdgeColor(0.67, 0.51, 0.24, 0.95)
    bg:SetEdgeTexture(nil, 1, 1, 1)

    local title = wm:CreateControl("EAS_RepairCostOverlay_Title", frame, CT_LABEL)
    title:SetAnchor(TOPLEFT, frame, TOPLEFT, 10, 7)
    title:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -10, 7)
    title:SetHeight(22)
    title:SetFont("ZoFontGameBold")
    title:SetColor(0.94, 0.82, 0.44, 1)
    title:SetText("REPAIR / RECHARGE ESTIMATE")

    local subtitle = wm:CreateControl("EAS_RepairCostOverlay_Subtitle", frame, CT_LABEL)
    subtitle:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 0)
    subtitle:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 0)
    subtitle:SetHeight(17)
    subtitle:SetFont("ZoFontGameSmall")
    subtitle:SetColor(0.70, 0.74, 0.80, 1)
    subtitle:SetText("Vendor gold cost by equipped item; weapons recharge with soul gems.")

    local rows = {}
    for i = 1, 11 do
        local row = wm:CreateControl("EAS_RepairCostOverlay_Row" .. tostring(i), frame, CT_CONTROL)
        row:SetAnchor(TOPLEFT, frame, TOPLEFT, 10, 45 + ((i - 1) * 20))
        row:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -10, 45 + ((i - 1) * 20))
        row:SetHeight(19)
        row:SetHidden(true)

        local left = wm:CreateControl("EAS_RepairCostOverlay_Row" .. tostring(i) .. "Left", row, CT_LABEL)
        left:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
        left:SetAnchor(TOPRIGHT, row, TOPRIGHT, -116, 0)
        left:SetHeight(19)
        left:SetFont("ZoFontGameSmall")
        left:SetColor(0.91, 0.92, 0.94, 1)
        left:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        local right = wm:CreateControl("EAS_RepairCostOverlay_Row" .. tostring(i) .. "Right", row, CT_LABEL)
        right:SetAnchor(TOPRIGHT, row, TOPRIGHT, 0, 0)
        right:SetDimensions(110, 19)
        right:SetFont("ZoFontGameSmall")
        right:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        right:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        right:SetColor(0.94, 0.82, 0.44, 1)

        row.epcLeft, row.epcRight = left, right
        rows[i] = row
    end

    local total = wm:CreateControl("EAS_RepairCostOverlay_Total", frame, CT_LABEL)
    total:SetFont("ZoFontGameBold")
    total:SetColor(0.94, 0.82, 0.44, 1)
    total:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    local wallet = wm:CreateControl("EAS_RepairCostOverlay_Wallet", frame, CT_LABEL)
    wallet:SetFont("ZoFontGameSmall")
    wallet:SetColor(0.70, 0.74, 0.80, 1)

    local hint = wm:CreateControl("EAS_RepairCostOverlay_Hint", frame, CT_LABEL)
    hint:SetFont("ZoFontGameSmall")
    hint:SetColor(0.94, 0.82, 0.44, 1)
    hint:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    hint:SetText("DRAG TO MOVE - EDGES TO RESIZE")
    hint:SetHidden(true)

    frame:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            EPC.saved.repairCostLeft = control:GetLeft()
            EPC.saved.repairCostTop = control:GetTop()
        end
    end)

    frame:SetHandler("OnResizeStart", function() R.detailResizing = true end)
    frame:SetHandler("OnResizeStop", function(control)
        R.detailResizing = false
        if EPC.saved then
            EPC.saved.repairCostWidth = math.floor(math.max(320, math.min(800, tonumber(control:GetWidth()) or 410)) + 0.5)
            EPC.saved.repairCostLeft = control:GetLeft()
            EPC.saved.repairCostTop = control:GetTop()
        end
        R:Refresh()
    end)

    -- The ALWAYS presentation is intentionally a separate, text-only HUD item.
    -- The detailed repair/recharge card remains exclusive to Inventory Only.
    local compactFrame = wm:CreateTopLevelWindow("EAS_RepairCostCompactOverlay")
    local compactW = math.max(150, math.min(600, tonumber(EPC.saved and EPC.saved.repairCostCompactWidth) or 260))
    local compactH = math.max(24, math.min(90, tonumber(EPC.saved and EPC.saved.repairCostCompactHeight) or 34))
    compactFrame:SetDimensions(compactW, compactH)
    if compactFrame.SetDimensionConstraints then compactFrame:SetDimensionConstraints(150, 24, 600, 90) end
    if compactFrame.SetResizeHandleSize then compactFrame:SetResizeHandleSize(0) end
    compactFrame:SetClampedToScreen(true)
    compactFrame:SetMouseEnabled(false)
    compactFrame:SetMovable(false)
    compactFrame:SetHidden(true)

    local compactLabel = wm:CreateControl("EAS_RepairCostCompactOverlay_Label", compactFrame, CT_LABEL)
    compactLabel:SetAnchorFill(compactFrame)
    compactLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", math.max(14, math.min(42, math.floor(compactH * 0.53 + 0.5)))))
    compactLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    compactLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    compactLabel:SetColor(0.94, 0.82, 0.44, 1)
    compactLabel:SetText("Repair: 0g")

    compactFrame:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            EPC.saved.repairCostCompactLeft = control:GetLeft()
            EPC.saved.repairCostCompactTop = control:GetTop()
        end
    end)

    compactFrame:SetHandler("OnResizeStart", function() R.compactResizing = true end)
    compactFrame:SetHandler("OnResizeStop", function(control)
        R.compactResizing = false
        if EPC.saved then
            EPC.saved.repairCostCompactWidth = math.floor(math.max(150, math.min(600, tonumber(control:GetWidth()) or 260)) + 0.5)
            EPC.saved.repairCostCompactHeight = math.floor(math.max(24, math.min(90, tonumber(control:GetHeight()) or 34)) + 0.5)
            EPC.saved.repairCostCompactLeft = control:GetLeft()
            EPC.saved.repairCostCompactTop = control:GetTop()
        end
        if R.compactLabel then
            local h = tonumber(control:GetHeight()) or 34
            R.compactLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", math.max(14, math.min(42, math.floor(h * 0.53 + 0.5)))))
        end
        R:Refresh()
    end)

    self.compactFrame, self.compactLabel = compactFrame, compactLabel
    self.compactHudFragment029125 = EPC.CreateHudFadeFragment and EPC:CreateHudFadeFragment(compactFrame) or nil
    self.frame, self.bg, self.title, self.subtitle = frame, bg, title, subtitle
    self.rows, self.total, self.wallet, self.hint = rows, total, wallet, hint
    self:Anchor()
    self:AnchorCompact()
    self:ApplyNormalDrawOrder()
end

function R:BuildRows()
    local result = {}
    local totalCost = 0
    if BAG_WORN == nil then return result, totalCost end

    for _, entry in ipairs(self:GetSlots()) do
        local slot = entry.slot
        local exists = safe(HasItemInSlot, false, BAG_WORN, slot) == true
        if not exists then
            local link = safe(GetItemLink, "", BAG_WORN, slot, LINK_STYLE_DEFAULT or 0)
            exists = link ~= nil and link ~= ""
        end
        if exists then
            local name = itemName(slot)
            local hasDurability = safe(DoesItemHaveDurability, false, BAG_WORN, slot) == true
            local chargeable = safe(IsItemChargeable, false, BAG_WORN, slot) == true
            local condition = hasDurability and (tonumber(safe(GetItemCondition, 100, BAG_WORN, slot)) or 100) or nil
            local repairCost = hasDurability and (tonumber(safe(GetItemRepairCost, 0, BAG_WORN, slot)) or 0) or 0
            if repairCost < 0 then repairCost = 0 end
            totalCost = totalCost + repairCost

            local status = nil
            if hasDurability then
                status = string.format("%d%%  %s", math.max(0, math.min(100, math.floor(condition + 0.5))), moneyText(repairCost))
            elseif chargeable then
                local charge, maxCharge = safe(GetChargeInfoForItem, 0, BAG_WORN, slot)
                charge, maxCharge = tonumber(charge) or 0, tonumber(maxCharge) or 0
                local pct = maxCharge > 0 and math.floor((charge / maxCharge) * 100 + 0.5) or 0
                status = string.format("CHARGE %d%%", math.max(0, math.min(100, pct)))
            else
                -- Keep the overlay focused on repairable armor, shields, and charged weapons.
                status = "0g"
            end

            result[#result + 1] = {
                label = entry.label .. "  " .. (name ~= "" and name or "Equipped item"),
                status = status,
                cost = repairCost,
                durability = hasDurability,
                chargeable = chargeable,
            }
        end
    end

    return result, totalCost
end

function R:IsInventoryOpen()
    if not SCENE_MANAGER or type(SCENE_MANAGER.IsShowing) ~= "function" then return false end
    local scenes = { "inventory", }
    for i = 1, #scenes do
        local ok, showing = pcall(SCENE_MANAGER.IsShowing, SCENE_MANAGER, scenes[i])
        if ok and showing == true then return true end
    end
    return false
end

function R:IsPauseMenuOpen()
    if not SCENE_MANAGER or type(SCENE_MANAGER.IsShowing) ~= "function" then return false end
    -- Always HUD is gameplay information and should not sit on top of Pause.
    local scenes = { "gameMenuInGame", "gameMenu", }
    for i = 1, #scenes do
        local ok, showing = pcall(SCENE_MANAGER.IsShowing, SCENE_MANAGER, scenes[i])
        if ok and showing == true then return true end
        if type(SCENE_MANAGER.GetScene) == "function" then
            local okScene, scene = pcall(SCENE_MANAGER.GetScene, SCENE_MANAGER, scenes[i])
            if okScene and scene and type(scene.GetState) == "function" then
                local okState, state = pcall(scene.GetState, scene)
                if okState and ((SCENE_SHOWING ~= nil and state == SCENE_SHOWING) or (SCENE_SHOWN ~= nil and state == SCENE_SHOWN)) then return true end
            end
        end
    end
    return false
end



function R:ShouldShowCompactHUD()
    if not EPC.saved or EPC.saved.enabled == false or EPC.saved.showRepairCostOverlay == false then return false end
    if (EPC.saved.repairCostVisibility or "INVENTORY") ~= "ALWAYS" then return false end
    if self.layoutMode then return true end
    return not (EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() == true)
end

function R:ApplyCompactHudReason(showRequested)
    showRequested = showRequested == true
    if self.compactHudFragment029125 and type(self.compactHudFragment029125.SetHiddenForReason) == "function" then
        pcall(self.compactHudFragment029125.SetHiddenForReason, self.compactHudFragment029125, "EAS_REPAIR_DISABLED", not showRequested)
    elseif self.compactFrame then
        self.compactFrame:SetHidden(not showRequested)
    end
end

function R:Refresh()
    if not self.frame or not self.compactFrame or not EPC.saved then return end

    local enabled = EPC.saved.showRepairCostOverlay ~= false
    local mode = EPC.saved.repairCostVisibility or "INVENTORY"

    -- Persisted HUD-layout sizing. Height of the detailed card remains content-driven,
    -- while its width is user-resizable. The compact HUD can be resized freely.
    local detailWidth = math.max(320, math.min(800, tonumber(EPC.saved.repairCostWidth) or 410))
    if self.detailResizing ~= true then self.frame:SetWidth(detailWidth) end
    local compactW = math.max(150, math.min(600, tonumber(EPC.saved.repairCostCompactWidth) or 260))
    local compactH = math.max(24, math.min(90, tonumber(EPC.saved.repairCostCompactHeight) or 34))
    if self.compactResizing ~= true then self.compactFrame:SetDimensions(compactW, compactH) end
    if self.compactLabel then
        self.compactLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", math.max(14, math.min(42, math.floor(compactH * 0.53 + 0.5)))))
    end

    local showDetail = false
    local showCompact = false

    if enabled then
        if mode == "ALWAYS" then
            showCompact = self:ShouldShowCompactHUD()
        else
            showDetail = self:IsInventoryOpen()
        end
    end

    -- HUD Layout Mode previews only the presentation selected by the user.
    if self.layoutMode then
        showDetail = enabled and mode ~= "ALWAYS"
        showCompact = enabled and mode == "ALWAYS"
    end

    self.frame:SetHidden(not showDetail)
    self:ApplyCompactHudReason(showCompact)
    if showCompact and not self.layoutMode then
        -- Match the working Suite FPS overlay: do not re-promote or bring the
        -- control to the top on every refresh. ESO's ZO_HUDFadeSceneFragment
        -- must remain the sole owner of idle fade/show state during gameplay.
        pcall(function()
            if self.compactFrame.SetDrawTier and DT_HIGH then self.compactFrame:SetDrawTier(DT_HIGH) end
            if self.compactFrame.SetDrawLayer and DL_OVERLAY then self.compactFrame:SetDrawLayer(DL_OVERLAY) end
            if self.compactFrame.SetDrawLevel then self.compactFrame:SetDrawLevel(940) end
        end)
    end

    if not showDetail and not showCompact then return end

    local data, totalCost = self:BuildRows()
    if showCompact then
        self.compactLabel:SetText("Repair: " .. moneyText(totalCost))
        self.compactFrame:SetScale(tonumber(EPC.saved.repairCostScale) or 1.0)
    end

    if not showDetail then return end

    for i,row in ipairs(self.rows or {}) do
        local item = data[i]
        row:SetHidden(item == nil)
        if item then
            row.epcLeft:SetText(item.label)
            row.epcRight:SetText(item.status)
            if item.cost > 0 then row.epcRight:SetColor(0.94, 0.72, 0.30, 1)
            elseif item.chargeable and not item.durability then row.epcRight:SetColor(0.58, 0.72, 0.96, 1)
            else row.epcRight:SetColor(0.68, 0.76, 0.68, 1) end
        end
    end

    local rowCount = math.max(1, #data)
    local totalY = 45 + (rowCount * 20) + 4
    self.total:ClearAnchors()
    self.total:SetAnchor(TOPRIGHT, self.frame, TOPRIGHT, -10, totalY)
    self.total:SetDimensions(205, 20)
    self.total:SetText("TOTAL REPAIR: " .. moneyText(totalCost))

    local gold = 0
    if CURT_MONEY ~= nil and CURRENCY_LOCATION_CHARACTER ~= nil then
        gold = tonumber(safe(GetCurrencyAmount, 0, CURT_MONEY, CURRENCY_LOCATION_CHARACTER)) or 0
    end
    self.wallet:ClearAnchors()
    self.wallet:SetAnchor(TOPLEFT, self.frame, TOPLEFT, 10, totalY + 1)
    self.wallet:SetDimensions(175, 18)
    self.wallet:SetText("ON HAND: " .. moneyText(gold))

    self.hint:ClearAnchors()
    self.hint:SetAnchor(TOPRIGHT, self.frame, TOPRIGHT, -10, totalY + 22)
    self.hint:SetDimensions(160, 18)

    local height = totalY + 43
    self.frame:SetHeight(math.max(108, height))
    self.frame:SetScale(tonumber(EPC.saved.repairCostScale) or 1.0)

    if self.layoutMode and #data == 0 then
        self.rows[1]:SetHidden(false)
        self.rows[1].epcLeft:SetText("EQUIPPED GEAR")
        self.rows[1].epcRight:SetText("PREVIEW")
    end
end

function R:ApplyNormalDrawOrder()
    if not self.frame then return end
    local tier = DT_MEDIUM or DT_LOW
    local layer = DL_CONTROLS or DL_OVERLAY
    setDrawOrder(self.frame, tier, layer, 40)
    setDrawOrder(self.bg, tier, layer, 41)
    setDrawOrder(self.title, tier, layer, 50)
    setDrawOrder(self.subtitle, tier, layer, 50)
    for _, row in ipairs(self.rows or {}) do
        setDrawOrder(row, tier, layer, 48)
        setDrawOrder(row.epcLeft, tier, layer, 50)
        setDrawOrder(row.epcRight, tier, layer, 50)
    end
    setDrawOrder(self.total, tier, layer, 50)
    setDrawOrder(self.wallet, tier, layer, 50)
    setDrawOrder(self.hint, tier, layer, 50)
    if self.compactFrame then
        -- Normal gameplay must stay under ESO's HUD-fade ownership. Promoting
        -- this control to an always-on top-level window can keep it visible
        -- after the rest of the gameplay HUD fades. Layout mode raises it only
        -- while the user is actively positioning overlays.
        pcall(function()
            if self.compactFrame.SetDrawTier and DT_HIGH then self.compactFrame:SetDrawTier(DT_HIGH) end
            if self.compactFrame.SetDrawLayer and DL_OVERLAY then self.compactFrame:SetDrawLayer(DL_OVERLAY) end
            if self.compactFrame.SetDrawLevel then self.compactFrame:SetDrawLevel(940) end
        end)
        setDrawOrder(self.compactLabel, DT_HIGH or tier, DL_OVERLAY or layer, 950)
    end
end

function R:RaiseForLayout()
    if not self.frame then return end

    -- Raise the top-level window as one unit, then give its contents explicit
    -- levels. Previously every child was forced to level 1000, which made the
    -- backdrop and labels ambiguous and could render the text underneath it.
    pcall(function()
        if self.frame.SetTopLevel then self.frame:SetTopLevel(true) end
        if self.frame.SetDrawTier and DT_HIGH then self.frame:SetDrawTier(DT_HIGH) end
        if self.frame.SetDrawLayer and DL_OVERLAY then self.frame:SetDrawLayer(DL_OVERLAY) end
        if self.frame.SetDrawLevel then self.frame:SetDrawLevel(900) end
        if self.frame.BringWindowToTop then self.frame:BringWindowToTop() end
    end)

    local tier = DT_HIGH or DT_MEDIUM
    local layer = DL_OVERLAY or DL_CONTROLS
    setDrawOrder(self.bg, tier, layer, 901)
    setDrawOrder(self.title, tier, layer, 920)
    setDrawOrder(self.subtitle, tier, layer, 920)
    for _, row in ipairs(self.rows or {}) do
        setDrawOrder(row, tier, layer, 910)
        setDrawOrder(row.epcLeft, tier, layer, 920)
        setDrawOrder(row.epcRight, tier, layer, 920)
    end
    setDrawOrder(self.total, tier, layer, 920)
    setDrawOrder(self.wallet, tier, layer, 920)
    setDrawOrder(self.hint, tier, layer, 925)
    if self.compactFrame then
        pcall(function()
            if self.compactFrame.SetTopLevel then self.compactFrame:SetTopLevel(true) end
            if self.compactFrame.SetDrawTier and DT_HIGH then self.compactFrame:SetDrawTier(DT_HIGH) end
            if self.compactFrame.SetDrawLayer and DL_OVERLAY then self.compactFrame:SetDrawLayer(DL_OVERLAY) end
            if self.compactFrame.SetDrawLevel then self.compactFrame:SetDrawLevel(940) end
            if self.compactFrame.BringWindowToTop then self.compactFrame:BringWindowToTop() end
        end)
        setDrawOrder(self.compactLabel, tier, layer, 950)
    end
end

function R:SetLayoutMode(active)
    self.layoutMode = active == true
    if not self.frame or not self.compactFrame then return end
    local mode = EPC.saved and EPC.saved.repairCostVisibility or "INVENTORY"
    local detailMove = self.layoutMode and mode ~= "ALWAYS"
    local compactMove = self.layoutMode and mode == "ALWAYS"
    self.frame:SetMouseEnabled(detailMove)
    self.frame:SetMovable(detailMove)
    if self.frame.SetResizeHandleSize then self.frame:SetResizeHandleSize(detailMove and 18 or 0) end
    self.compactFrame:SetMouseEnabled(compactMove)
    self.compactFrame:SetMovable(compactMove)
    if self.compactFrame.SetResizeHandleSize then self.compactFrame:SetResizeHandleSize(compactMove and 18 or 0) end
    if self.hint then self.hint:SetHidden(not detailMove) end
    self:Refresh()
    if self.layoutMode then
        self:RaiseForLayout()
    else
        self:ApplyNormalDrawOrder()
    end
end

function R:ResetPosition()
    if not EPC.saved then return end
    EPC.saved.repairCostLeft, EPC.saved.repairCostTop = -1, -1
    EPC.saved.repairCostCompactLeft, EPC.saved.repairCostCompactTop = -1, -1
    self:Anchor()
    self:AnchorCompact()
end

function R:GetGameplayHudReferenceAlpha029134()
    if self.layoutMode then return 1 end
    if EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() == true then return 0 end

    -- The Suite FPS/Latency overlay is already proven to follow the exact HUD
    -- fade state requested by the user. Mirror its real rendered alpha when it
    -- exists, so Repair: <gold> can never remain visible after FPS has faded.
    local perf = EPC.PerformanceOverlay and EPC.PerformanceOverlay.frame or nil
    if perf and EPC.saved and EPC.saved.showPerformanceOverlay ~= false then
        if type(perf.IsHidden) == "function" then
            local okHidden, hidden = pcall(perf.IsHidden, perf)
            if okHidden and hidden == true then return 0 end
        end
        if type(perf.GetAlpha) == "function" then
            local okAlpha, alpha = pcall(perf.GetAlpha, perf)
            if okAlpha and tonumber(alpha) then return math.max(0, math.min(1, tonumber(alpha))) end
        end
    end

    -- Fallback to ESO's own action bar HUD fade if the Suite performance meter
    -- is disabled. This is only an alpha read; no expensive scans or polling.
    local candidates = { ZO_ActionBar1, ZO_PlayerAttributeHealth, ZO_PlayerAttributeMagicka, ZO_PlayerAttributeStamina }
    for i = 1, #candidates do
        local c = candidates[i]
        if c and type(c.GetAlpha) == "function" then
            local hidden = false
            if type(c.IsHidden) == "function" then
                local okHidden, value = pcall(c.IsHidden, c)
                hidden = okHidden and value == true
            end
            if not hidden then
                local okAlpha, alpha = pcall(c.GetAlpha, c)
                if okAlpha and tonumber(alpha) then return math.max(0, math.min(1, tonumber(alpha))) end
            end
        end
    end
    return 1
end

function R:SyncCompactHudAlpha029134()
    if not self.compactFrame or not EPC.saved then return end
    local enabled = EPC.saved.showRepairCostOverlay ~= false
        and (EPC.saved.repairCostVisibility or "INVENTORY") == "ALWAYS"
    if not enabled then return end
    local alpha = self:GetGameplayHudReferenceAlpha029134()
    if type(self.compactFrame.SetAlpha) == "function" then
        self.compactFrame:SetAlpha(self.layoutMode and 1 or alpha)
    end
end

function R:Initialize()
    self.layoutMode = false
    self:Create()
    local prefix = EPC.name .. "_RepairCostOverlay"
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        local slotRegistration = prefix .. "_Slot"
        EVENT_MANAGER:RegisterForEvent(slotRegistration, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
            self:Refresh()
        end)
        if REGISTER_FILTER_BAG_ID and BAG_WORN then
            EVENT_MANAGER:AddFilterForEvent(slotRegistration, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
        end
    end
    if EVENT_INVENTORY_FULL_UPDATE then EVENT_MANAGER:RegisterForEvent(prefix .. "_Inventory", EVENT_INVENTORY_FULL_UPDATE, function() self:Refresh() end) end
    if EVENT_MONEY_UPDATE then EVENT_MANAGER:RegisterForEvent(prefix .. "_Money", EVENT_MONEY_UPDATE, function() self:Refresh() end) end
    if EVENT_PLAYER_COMBAT_STATE then EVENT_MANAGER:RegisterForEvent(prefix .. "_Combat", EVENT_PLAYER_COMBAT_STATE, function() self:Refresh() end) end
    if EVENT_PLAYER_ACTIVATED then EVENT_MANAGER:RegisterForEvent(prefix .. "_Activated", EVENT_PLAYER_ACTIVATED, function() self:Refresh() end) end


    -- Inventory update events do not necessarily fire when the scene itself closes.
    -- hides immediately when Inventory is dismissed.
    if SCENE_MANAGER and type(SCENE_MANAGER.GetScene) == "function" then
        for _, sceneName in ipairs({"inventory", "gameMenuInGame", "gameMenu",}) do
            local ok, scene = pcall(SCENE_MANAGER.GetScene, SCENE_MANAGER, sceneName)
            if ok and scene and type(scene.RegisterCallback) == "function" then
                scene:RegisterCallback("StateChange", function()
                    self:Refresh()
                end)
            end
        end
    end
    EVENT_MANAGER:UnregisterForUpdate(prefix .. "_HudAlphaSync029134")
    EVENT_MANAGER:RegisterForUpdate(prefix .. "_HudAlphaSync029134", 900, function()
        if R and R.SyncCompactHudAlpha029134 then R:SyncCompactHudAlpha029134() end
    end)
    self:Refresh()
    self:SyncCompactHudAlpha029134()
end


-- BEGIN ABSORBED: RepairButtonPresentationFix.lua
-- ESO Adventurer Suite
-- v0.29.505 - Repair is inventory-button-only; darker panel; tabs shifted left.

local EPC = ESOProgressionCoach
if not EPC then return end

local R = EPC.RepairCostOverlay
local T = EPC.InventoryRepairTab
if not R or not T then return end

local UPDATE_NAME = (EPC.name or "ESOAdventurerSuite") .. "_RepairButtonPresentation029505"

local function DarkenRepairPanel029505()
    if not R.bg then return end
    -- Strong near-black background so the repair information is readable over
    -- bright character/world scenes while keeping the Suite gold edge.
    if R.bg.SetCenterColor then
        pcall(R.bg.SetCenterColor, R.bg, 0.004, 0.005, 0.008, 0.985)
    end
    if R.bg.SetEdgeColor then
        pcall(R.bg.SetEdgeColor, R.bg, 0.82, 0.62, 0.26, 1)
    end
end

local function ShiftInventoryTabsLeft029505()
    local tabs = rawget(_G, "ZO_PlayerInventoryTabs")
    if not tabs or not tabs.ClearAnchors or not tabs.SetAnchor then return end
    local parent = tabs.GetParent and tabs:GetParent() or rawget(_G, "ZO_PlayerInventory")
    if not parent then return end

    -- ESO defaults this bar near TOPRIGHT at roughly -33px. Pull the entire
    -- icon row farther left while preserving its original vertical position.
    pcall(tabs.ClearAnchors, tabs)
    pcall(tabs.SetAnchor, tabs, TOPRIGHT, parent, TOPRIGHT, -105, 14)
end

local originalRefresh029505 = R.Refresh
if type(originalRefresh029505) == "function" and not R._easButtonOnlyRefresh029505 then
    R._easButtonOnlyRefresh029505 = originalRefresh029505

    R.Refresh = function(self, ...)
        -- Let the existing module calculate rows, totals, condition, charge and
        -- wallet data first. We only take ownership of presentation/visibility.
        local ok, a, b, c, d = pcall(originalRefresh029505, self, ...)

        DarkenRepairPanel029505()

        -- The old compact/always Repair HUD is redundant now that Repair has a
        -- dedicated inventory button. Keep it hidden regardless of old settings.
        if self.compactFrame then
            pcall(self.compactFrame.SetHidden, self.compactFrame, true)
        end
        if self.compactHudFragment029125 and type(self.compactHudFragment029125.SetHiddenForReason) == "function" then
            pcall(self.compactHudFragment029125.SetHiddenForReason, self.compactHudFragment029125, "EAS_REPAIR_BUTTON_ONLY_029505", true)
        end

        -- Detailed card is visible only while the Repair button itself is active.
        local selected = EPC.InventoryRepairTab and EPC.InventoryRepairTab.selected == true
        if self.frame then
            if selected then
                if EPC.InventoryRepairTab and type(EPC.InventoryRepairTab.AnchorRepairPanel) == "function" then
                    pcall(EPC.InventoryRepairTab.AnchorRepairPanel, EPC.InventoryRepairTab)
                end
                pcall(self.frame.SetHidden, self.frame, false)
            else
                pcall(self.frame.SetHidden, self.frame, true)
            end
        end

        if not ok then return nil end
        return a, b, c, d
    end
end

-- The old RestoreRepairPanel path re-anchors/re-shows according to the previous
-- Inventory/Always setting. In button-only mode closing Repair should simply hide it.
T.RestoreRepairPanel = function(self)
    local repair = EPC.RepairCostOverlay
    if type(self.GetRepairModule) == "function" then
        local ok, value = pcall(self.GetRepairModule, self)
        if ok and value then repair = value end
    end
    if repair and repair.frame then
        pcall(repair.frame.SetHidden, repair.frame, true)
    end
    if repair and repair.compactFrame then
        pcall(repair.compactFrame.SetHidden, repair.compactFrame, true)
    end
end

local function Apply029505()
    DarkenRepairPanel029505()
    ShiftInventoryTabsLeft029505()

    if R.compactFrame then R.compactFrame:SetHidden(true) end

    if T.selected then
        if type(T.ShowRepairPanel) == "function" then pcall(T.ShowRepairPanel, T) end
        DarkenRepairPanel029505()
    elseif R.frame then
        R.frame:SetHidden(true)
    end
end

EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 250, Apply029505)

if type(zo_callLater) == "function" then
    zo_callLater(Apply029505, 300)
    zo_callLater(Apply029505, 1000)
else
    Apply029505()
end
-- END ABSORBED: RepairButtonPresentationFix.lua
