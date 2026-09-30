-- ESO Adventurer Suite
-- v0.29.745 - authoritative off-bar timer state + Ultimate display alignment
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

local EPC = ESOProgressionCoach
EPC.AbilityOverlays = EPC.AbilityOverlays or {}
local A = EPC.AbilityOverlays
local refreshAbilityUltimate029668
local wm = WINDOW_MANAGER

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok,a,b,c,d,e = pcall(fn,...)
    if not ok then return fallback end
    return a,b,c,d,e
end

local function nowMS()
    if type(GetFrameTimeMilliseconds) == "function" then return GetFrameTimeMilliseconds() end
    if type(GetGameTimeMilliseconds) == "function" then return GetGameTimeMilliseconds() end
    return 0
end

local function formatMS(ms)
    ms = tonumber(ms) or 0
    if ms <= 0 then return "" end
    local s = ms / 1000
    if s >= 10 then return tostring(math.ceil(s)) end
    return string.format("%.1f", s)
end

local function bindingKeyText(keyCode)
    keyCode = tonumber(keyCode)
    if not keyCode or (KEY_INVALID ~= nil and keyCode == KEY_INVALID) then return "" end
    local text = ""
    if type(ZO_Keybindings_GetKeyText) == "function" then
        text = tostring(safe(ZO_Keybindings_GetKeyText, "", keyCode) or "")
    end
    if text == "" and type(GetKeyName) == "function" then
        text = tostring(safe(GetKeyName, "", keyCode) or "")
    end
    return text
end

local function compactBindingText(text)
    text = tostring(text or "")
    if text == "" then return text end
    -- Keep the overlay readable for uncommon mouse/numpad bindings without
    -- changing what key the player actually configured.
    text = text:gsub("MOUSE BUTTON ", "M")
    text = text:gsub("MOUSEBUTTON", "M")
    text = text:gsub("NUMPAD ", "N")
    text = text:gsub("NUMPAD", "N")
    text = text:gsub("CONTROL", "CTRL")
    text = text:gsub("COMMAND", "CMD")
    return text
end

function A:GetActionBindingName(slot)
    slot = tonumber(slot)
    if not slot then return nil end
    if slot >= 3 and slot <= 8 then
        -- The player-facing keyboard binding lives on ACTION_BUTTON_n.
        return "ACTION_BUTTON_" .. tostring(slot)
    end
    return nil
end

function A:GetBindingTextForAction(actionName)
    if not actionName or actionName == "" then return "" end

    if EPC.ControllerSupport and type(EPC.ControllerSupport.GetActionBindingMarkup029761) == "function" then
        local markup = EPC.ControllerSupport:GetActionBindingMarkup029761(actionName, 120)
        if markup and markup ~= "" then return tostring(markup) end
    end

    local key, mod1, mod2, mod3, mod4
    if type(GetHighestPriorityActionBindingInfoFromName) == "function" then
        key, mod1, mod2, mod3, mod4 = safe(GetHighestPriorityActionBindingInfoFromName, nil, actionName, false)
    end

    local parts = {}
    local seen = {}
    for _, code in ipairs({mod1, mod2, mod3, mod4}) do
        local n = tonumber(code)
        if n and (KEY_INVALID == nil or n ~= KEY_INVALID) and not seen[n] then
            local t = compactBindingText(bindingKeyText(n))
            if t ~= "" then parts[#parts + 1] = t; seen[n] = true end
        end
    end
    local keyText = compactBindingText(bindingKeyText(key))
    if keyText ~= "" then parts[#parts + 1] = keyText end

    local result = table.concat(parts, "+")
    if result == "" and type(ZO_Keybindings_GetBindingStringFromAction) == "function" then
        local textOptions = KEYBIND_TEXT_OPTIONS_ABBREVIATED_NAME or 1
        local textureOptions = KEYBIND_TEXTURE_OPTIONS_NONE or 1
        local maxBindings = tonumber(safe(GetMaxBindingsPerAction, 2)) or 2
        for bindingIndex = 1, math.max(1, math.min(4, maxBindings)) do
            local candidate = tostring(safe(ZO_Keybindings_GetBindingStringFromAction, "", actionName, textOptions, textureOptions, bindingIndex) or "")
            if candidate ~= "" then result = compactBindingText(candidate); break end
        end
    end
    return result
end

function A:GetBindingTextForSlot(slot)
    self.bindingTextCache = self.bindingTextCache or {}
    local cached = self.bindingTextCache[slot]
    if cached ~= nil then return cached end
    local actionName = self:GetActionBindingName(slot)
    if not actionName then return "" end

    local result = self:GetBindingTextForAction(actionName)
    self.bindingTextCache[slot] = result
    return result
end

function A:InvalidateBindingText()
    self.bindingTextCache = {}
end

function A:GetSlots()
    -- ESO's exported action-bar constants are base indices; the live ZOS
    -- action bar addresses the five normal ability buttons and Ultimate at
    -- constant + 1. Keep the same physical-slot convention here so the
    -- overlays match skills 1-5 in order and the actual Ultimate slot.
    local firstBase = tonumber(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX)
    local ultimateBase = tonumber(ACTION_BAR_ULTIMATE_SLOT_INDEX)
    local first = firstBase and (firstBase + 1) or 3
    local ultimate = ultimateBase and (ultimateBase + 1) or (first + 5)
    local slots = {}
    for offset = 0, 4 do
        slots[#slots + 1] = first + offset
    end
    slots[#slots + 1] = ultimate
    return slots
end

function A:GetPositionKeys(slot)
    return "abilitySlot" .. tostring(slot) .. "Left", "abilitySlot" .. tostring(slot) .. "Top"
end

function A:EnsureRoot029707()
    if self.root029707 then return self.root029707 end

    -- One top-level surface owns the complete six-slot Ability Overlay.
    -- Slots are lightweight child controls, matching the architecture that
    -- already performs smoothly in the Dual Action Bar.
    local root = wm:CreateTopLevelWindow("EAS_AbilityOverlayRoot029707")
    root:SetAnchorFill(GuiRoot)
    root:SetMouseEnabled(false)
    root:SetHidden(false)
    if root.SetDrawLayer and DL_OVERLAY then root:SetDrawLayer(DL_OVERLAY) end
    if root.SetDrawTier and DT_HIGH then root:SetDrawTier(DT_HIGH) end
    if root.SetDrawLevel then root:SetDrawLevel(1000) end
    self.root029707 = root
    return root
end


-- Single-bar mode only. Dual Action Bar is intentionally untouched.
function A:IsUnifiedSingleBar029734()
    return not EPC.saved or EPC.saved.showDualActionBar029189 ~= true
end

function A:EnsureSingleBarGroup029734()
    if self.singleBarGroup029734 then return self.singleBarGroup029734 end
    local root=self:EnsureRoot029707()

    local group=wm:CreateControl("EAS_AbilityOverlayUnifiedBar029734",root,CT_CONTROL)
    group:SetMouseEnabled(false)
    group:SetMovable(false)
    group:SetHidden(false)
    if group.SetDrawLayer and DL_OVERLAY then group:SetDrawLayer(DL_OVERLAY) end
    if group.SetDrawLevel then group:SetDrawLevel(990) end

    local back=wm:CreateControl("EAS_AbilityOverlayUnifiedBarBG029734",group,CT_BACKDROP)
    back:SetAnchorFill(group)
    back:SetCenterColor(0.010,0.013,0.020,0.90)
    back:SetEdgeColor(0.67,0.51,0.24,0.98)
    back:SetEdgeTexture(nil,2,2,2)
    back:SetMouseEnabled(false)

    self.singleBarGroup029734=group
    self.singleBarGroupBG029734=back
    return group
end

function A:GetOtherHotbar029734(active)
    local primary=rawget(_G,"HOTBAR_CATEGORY_PRIMARY")
    local backup=rawget(_G,"HOTBAR_CATEGORY_BACKUP")
    if active==primary then return backup end
    if active==backup then return primary end
    return nil
end

function A:EnsureOffBarReadyStrip029734(widget)
    if not widget or widget.epcOffReady029734 then return end

    local holder=wm:CreateControl(nil,widget,CT_BACKDROP)
    holder:SetDimensions(42,5)
    holder:SetAnchor(BOTTOM,widget,TOP,0,-3)
    holder:SetCenterColor(0.03,0.04,0.05,0.98)
    holder:SetEdgeColor(0.20,0.22,0.26,1)
    holder:SetEdgeTexture(nil,1,1,1)
    holder:SetMouseEnabled(false)
    if holder.SetDrawLayer and DL_OVERLAY then holder:SetDrawLayer(DL_OVERLAY) end
    if holder.SetDrawLevel then holder:SetDrawLevel(2600) end

    local fill=wm:CreateControl(nil,holder,CT_TEXTURE)
    fill:SetAnchor(LEFT,holder,LEFT,1,0)
    fill:SetDimensions(1,3)
    fill:SetColor(0.36,0.96,0.42,1)
    fill:SetMouseEnabled(false)

    local timer=wm:CreateControl(nil,holder,CT_LABEL)
    timer:SetAnchor(BOTTOM,holder,TOP,0,-1)
    timer:SetDimensions(42,12)
    timer:SetFont("$(BOLD_FONT)|11|soft-shadow-thick")
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    timer:SetColor(1,1,1,1)
    timer:SetText("")
    timer:SetMouseEnabled(false)

    widget.epcOffReady029734=holder
    widget.epcOffReadyFill029734=fill
    widget.epcOffReadyTimer029740=timer
end

function A:GetOffBarEffectRemaining029745(slot,category)
    slot=tonumber(slot)
    if not slot then return 0 end

    -- First use ESO's slot-aware timer if it exposes the inactive bar state.
    local direct=tonumber((safe(GetActionSlotEffectTimeRemaining,0,slot,category))) or 0
    if direct>0 then return direct end

    -- Some abilities do not report an inactive-hotbar timer through
    -- GetActionSlotEffectTimeRemaining. Resolve the actual slotted ability and
    -- fall back to live player/target effects so the header reflects whether
    -- that off-bar ability's effect is really still running.
    local abilityId=tonumber((safe(GetSlotBoundId,0,slot,category))) or 0
    if abilityId<=0 then return 0 end

    local abilityName=tostring(safe(GetAbilityName,"",abilityId) or "")
    if abilityName=="" then return 0 end

    local nowSec=0
    if type(GetFrameTimeSeconds)=="function" then
        nowSec=tonumber((safe(GetFrameTimeSeconds,0))) or 0
    elseif type(GetGameTimeMilliseconds)=="function" then
        nowSec=(tonumber((safe(GetGameTimeMilliseconds,0))) or 0)/1000
    end

    local function scanUnit(unitTag)
        if type(GetNumBuffs)~="function" or type(GetUnitBuffInfo)~="function" then return 0 end
        local count=tonumber((safe(GetNumBuffs,0,unitTag))) or 0
        local best=0
        for i=1,count do
            local name,timeStarted,timeEnding,_,_,_,_,_,_,_,_,_,effectAbilityId =
                safe(GetUnitBuffInfo,nil,unitTag,i)
            if name~=nil then
                local sameId=tonumber(effectAbilityId)==abilityId
                local sameName=tostring(name or "")==abilityName
                if sameId or sameName then
                    local ending=tonumber(timeEnding) or 0
                    local remain=ending>0 and math.max(0,(ending-nowSec)*1000) or 0
                    if remain>best then best=remain end
                end
            end
        end
        return best
    end

    local playerRemain=scanUnit("player")
    local targetRemain=scanUnit("reticleover")
    return math.max(playerRemain,targetRemain)
end

function A:RefreshOffBarReadyStrip029734(widget,activeCategory)
    if not widget then return end
    self:EnsureOffBarReadyStrip029734(widget)

    local holder=widget.epcOffReady029734
    local fill=widget.epcOffReadyFill029734
    local timer=widget.epcOffReadyTimer029740
    local single=self:IsUnifiedSingleBar029734()
    if not single or widget:IsHidden() then
        holder:SetHidden(true)
        if timer then timer:SetText("") end
        return
    end

    local other=self:GetOtherHotbar029734(activeCategory)
    if other==nil then
        holder:SetHidden(true)
        if timer then timer:SetText("") end
        return
    end

    local slot=widget.epcSlot
    local used=safe(IsSlotUsed,false,slot,other)==true
    holder:SetHidden(false)

    local width=math.max(8,(tonumber(widget:GetWidth()) or 56)-6)
    holder:SetDimensions(width,5)
    if timer then timer:SetDimensions(width,12) end

    if not used then
        fill:SetDimensions(1,3)
        fill:SetColor(0.12,0.12,0.14,1)
        holder:SetCenterColor(0.015,0.015,0.018,1)
        holder:SetEdgeColor(0.16,0.16,0.18,1)
        if timer then timer:SetText("") end
        return
    end

    local usable=safe(IsSlotUsable,true,slot,other)~=false
    local remain,duration,isGlobal=safe(GetSlotCooldownInfo,0,slot,other)
    remain=tonumber(remain) or 0
    duration=tonumber(duration) or 0
    local effectRemaining=self:GetOffBarEffectRemaining029745(slot,other)

    local ready=true
    local ratio=1
    local timerText=""

    local isUltimate=widget.epcOrdinal==#(self.widgets or {})
    if isUltimate and COMBAT_MECHANIC_FLAGS_ULTIMATE then
        -- safe() can return multiple ESO API values. Wrap the call so tonumber()
        -- receives only the first result; otherwise Lua treats the second return
        -- as tonumber's optional base argument ("base out of range").
        local current=tonumber((safe(GetUnitPower,0,"player",COMBAT_MECHANIC_FLAGS_ULTIMATE))) or 0
        local cost=tonumber((safe(GetSlotAbilityCost,0,slot,other)))
            or tonumber((safe(GetSlotAbilityCost,0,slot)))
            or 0
        ready=cost>0 and current>=cost
        ratio=cost>0 and math.max(0,math.min(1,current/cost)) or 0
        -- Match the visible Ultimate overlay: ESO stores a 0..500 Ultimate
        -- pool. The header shows that real pool value instead of a misleading
        -- percent-of-cost value (e.g. 62% while the slot below says 66%).
        local pool=math.max(0,math.min(500,math.floor(current+0.5)))
        timerText=tostring(pool).."%"
    elseif effectRemaining>0 then
        -- Most ESO abilities are duration-driven rather than true cooldowns.
        -- Treat an active off-bar effect as "not due yet" and show the actual
        -- remaining duration directly above the matching active-bar slot.
        ready=false
        ratio=1
        timerText=formatMS(effectRemaining)
    elseif remain>0 and duration>0 and not isGlobal then
        ready=false
        ratio=math.max(0,math.min(1,1-(remain/duration)))
        timerText=formatMS(remain)
    elseif not usable then
        ready=false
        ratio=1
        timerText="NO"
    else
        timerText="RDY"
    end

    local inner=math.max(1,width-2)
    fill:SetDimensions(math.max(1,inner*ratio),3)

    if ready then
        -- Bright full green = immediately ready on the other bar.
        fill:SetDimensions(inner,3)
        fill:SetColor(0.10,1.00,0.18,1)
        holder:SetCenterColor(0.02,0.20,0.04,1)
        holder:SetEdgeColor(0.18,1.00,0.26,1)
        if timer then timer:SetColor(0.92,1.00,0.92,1) end
    elseif effectRemaining>0 then
        -- Blue = an off-bar duration is still active; numeric text is time left.
        fill:SetDimensions(inner,3)
        fill:SetColor(0.10,0.58,1.00,1)
        holder:SetCenterColor(0.015,0.08,0.18,1)
        holder:SetEdgeColor(0.16,0.68,1.00,1)
        if timer then timer:SetColor(1,1,1,1) end
    elseif remain>0 and duration>0 and not isGlobal then
        -- Dark red track + amber progress = still recovering.
        fill:SetColor(1.00,0.62,0.04,1)
        holder:SetCenterColor(0.24,0.025,0.015,1)
        holder:SetEdgeColor(1.00,0.28,0.08,1)
        if timer then timer:SetColor(1.00,0.96,0.82,1) end
    else
        -- Solid red = slotted but currently cannot be used.
        fill:SetDimensions(inner,3)
        fill:SetColor(0.92,0.08,0.06,1)
        holder:SetCenterColor(0.20,0.015,0.015,1)
        holder:SetEdgeColor(1.00,0.14,0.10,1)
        if timer then timer:SetColor(1,0.92,0.90,1) end
    end
    if timer then timer:SetText(timerText) end
end

function A:LayoutUnifiedSingleBar029734()
    local group=self:EnsureSingleBarGroup029734()
    local single=self:IsUnifiedSingleBar029734()
    group:SetHidden(not single)
    if not single then return end

    local size=math.max(40,math.min(90,tonumber(EPC.saved and EPC.saved.abilityOverlaySize) or 56))
    local scale=tonumber(EPC.saved and EPC.saved.abilityOverlayScale) or 1.0
    local count=#(self.widgets or {})
    local gap=1
    local scaledSize=size*scale
    local width=(count*scaledSize)+((count-1)*gap)+8
    local readyHeaderH=18
    local height=scaledSize+readyHeaderH+8

    group:SetScale(1)
    group:SetDimensions(width,height)

    -- Do not re-anchor the unified bar while the user is dragging it. Refresh()
    -- runs repeatedly in HUD Layout and used to clear/reapply the bottom anchor,
    -- which made the bar feel like it was fighting the mouse.
    if not group.epcDragging029737 then
        group:ClearAnchors()

        -- Preserve the legacy overall location by using slot 1's saved/default position
        -- as the group's origin, but keep all six slots locked together.
        local first=self.widgets and self.widgets[1]
        local anchored=false
        if first and EPC.saved then
            local lk,tk=self:GetPositionKeys(first.epcSlot)
            local left=tonumber(EPC.saved[lk]) or -1
            local top=tonumber(EPC.saved[tk]) or -1
            if left>=0 and top>=0 then
                group:SetAnchor(TOPLEFT,self.root029707 or GuiRoot,TOPLEFT,left-4,top-4)
                anchored=true
            end
        end
        if not anchored then
            group:SetAnchor(BOTTOM,self.root029707 or GuiRoot,BOTTOM,0,-122)
        end
    end

    local x=4
    for ordinal,widget in ipairs(self.widgets or {}) do
        widget:ClearAnchors()
        widget:SetScale(scale)
        widget:SetDimensions(size,size)
        widget:SetAnchor(TOPLEFT,group,TOPLEFT,x,22)
        x=x+scaledSize+gap

        -- Unified outer frame owns the border in single-bar mode.
        if widget.epcBG then
            widget.epcBG:SetCenterColor(0.012,0.015,0.022,0.72)
            widget.epcBG:SetEdgeColor(0.12,0.13,0.16,0.55)
            widget.epcBG:SetEdgeTexture(nil,1,1,1)
        end
        if widget.epcIcon then
            widget.epcIcon:ClearAnchors()
            widget.epcIcon:SetAnchor(TOPLEFT,widget,TOPLEFT,2,2)
            widget.epcIcon:SetAnchor(BOTTOMRIGHT,widget,BOTTOMRIGHT,-2,-2)
        end
        self:EnsureOffBarReadyStrip029734(widget)
    end
end

function A:AnchorWidget(widget, ordinal)
    if not widget then return end
    widget:ClearAnchors()
    local anchorRoot = self.root029707 or GuiRoot
    local leftKey,topKey = self:GetPositionKeys(widget.epcSlot)
    local left = tonumber(EPC.saved and EPC.saved[leftKey]) or -1
    local top = tonumber(EPC.saved and EPC.saved[topKey]) or -1
    if left >= 0 and top >= 0 then
        widget:SetAnchor(TOPLEFT, anchorRoot, TOPLEFT, left, top)
    else
        local offset = (ordinal - 3.5) * 68
        widget:SetAnchor(BOTTOM, anchorRoot, BOTTOM, offset, -118)
    end
end

function A:CreateWidget(slot, ordinal)
    local size = tonumber(EPC.saved and EPC.saved.abilityOverlaySize) or 56
    local name = "EAS_AbilityOverlay_" .. tostring(slot)
    local parent = self:EnsureRoot029707()
    local frame = wm:CreateControl(name, parent, CT_CONTROL)
    frame:SetDimensions(size,size)
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    if frame.SetDrawLayer and DL_OVERLAY then frame:SetDrawLayer(DL_OVERLAY) end
    if frame.SetDrawLevel then frame:SetDrawLevel(1000 + ordinal) end
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)
    frame.epcSlot = slot
    frame.epcOrdinal = ordinal

    local bg = wm:CreateControl(name .. "BG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0.012,0.015,0.022,0.78)
    bg:SetEdgeColor(0.67,0.51,0.24,0.95)
    bg:SetEdgeTexture(nil,1,1,1)

    local icon = wm:CreateControl(name .. "Icon", frame, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, frame, TOPLEFT, 3,3)
    icon:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -3,-3)

    -- Smart Combat Advisor recommendation highlight. Keep every layer parented
    -- to the exact Suite ability frame so it can never drift away from the
    -- visible ability box. v0.29.320 uses a steady soft-gold highlight instead
    -- of a pulsing/flashing animation.
    local smartGlowOuter = wm:CreateControl(name .. "SmartGlowOuter029168", frame, CT_BACKDROP)
    smartGlowOuter:SetAnchor(TOPLEFT, frame, TOPLEFT, -8, -8)
    smartGlowOuter:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 8, 8)
    smartGlowOuter:SetMouseEnabled(false)
    smartGlowOuter:SetCenterColor(1.00, 0.62, 0.02, 0.018)
    smartGlowOuter:SetEdgeColor(1.00, 0.62, 0.08, 0.42)
    smartGlowOuter:SetEdgeTexture(nil, 8, 8, 8)
    if smartGlowOuter.SetDrawLayer and DL_OVERLAY then smartGlowOuter:SetDrawLayer(DL_OVERLAY) end
    if smartGlowOuter.SetDrawLevel then smartGlowOuter:SetDrawLevel(2498) end
    smartGlowOuter:SetHidden(true)

    local smartGlowMid = wm:CreateControl(name .. "SmartGlowMid029168", frame, CT_BACKDROP)
    smartGlowMid:SetAnchor(TOPLEFT, frame, TOPLEFT, -4, -4)
    smartGlowMid:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 4, 4)
    smartGlowMid:SetMouseEnabled(false)
    smartGlowMid:SetCenterColor(1.00, 0.72, 0.05, 0.035)
    smartGlowMid:SetEdgeColor(1.00, 0.78, 0.12, 0.72)
    smartGlowMid:SetEdgeTexture(nil, 4, 4, 4)
    if smartGlowMid.SetDrawLayer and DL_OVERLAY then smartGlowMid:SetDrawLayer(DL_OVERLAY) end
    if smartGlowMid.SetDrawLevel then smartGlowMid:SetDrawLevel(2499) end
    smartGlowMid:SetHidden(true)

    local smartHighlight = wm:CreateControl(name .. "SmartHighlight029167", frame, CT_BACKDROP)
    smartHighlight:SetAnchorFill(frame)
    smartHighlight:SetMouseEnabled(false)
    smartHighlight:SetCenterColor(1.00, 0.82, 0.10, 0.08)
    smartHighlight:SetEdgeColor(1.00, 0.96, 0.32, 1.00)
    smartHighlight:SetEdgeTexture(nil, 4, 4, 4)
    if smartHighlight.SetDrawLayer and DL_OVERLAY then smartHighlight:SetDrawLayer(DL_OVERLAY) end
    if smartHighlight.SetDrawLevel then smartHighlight:SetDrawLevel(2500) end
    smartHighlight:SetHidden(true)

    local shade = wm:CreateControl(name .. "Shade", frame, CT_BACKDROP)
    shade:SetAnchorFill(icon)
    shade:SetCenterColor(0,0,0,0)
    shade:SetEdgeColor(0,0,0,0)

    -- High-contrast timer plate keeps countdowns readable over bright ability artwork.
    local timerBack = wm:CreateControl(name .. "TimerBack", frame, CT_BACKDROP)
    timerBack:SetAnchor(CENTER, frame, CENTER, 0, 0)
    timerBack:SetDimensions(54, 34)
    timerBack:SetCenterColor(0, 0, 0, 0.94)
    timerBack:SetEdgeColor(0, 0, 0, 1.00)
    timerBack:SetEdgeTexture(nil, 1, 1, 1)
    timerBack:SetHidden(true)

    local cooldown = wm:CreateControl(name .. "Cooldown", frame, CT_LABEL)
    cooldown:SetAnchorFill(frame)
    cooldown:SetFont("$(BOLD_FONT)|24|soft-shadow-thick")
    cooldown:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    cooldown:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    -- Red cooldown timer for stronger separation from active-duration timers and skill art.
    cooldown:SetColor(1.00, 0.20, 0.20, 1)

    local effect = wm:CreateControl(name .. "Effect", frame, CT_LABEL)
    -- Active ability duration: centered, larger, and high contrast.
    effect:SetAnchorFill(frame)
    effect:SetFont("$(BOLD_FONT)|24|soft-shadow-thick")
    effect:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    effect:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    -- Use the same bright orange as cooldowns: one consistent, high-contrast timer color.
    effect:SetColor(1.00, 0.64, 0.16, 1)

    local slotLabel = wm:CreateControl(name .. "Slot", frame, CT_LABEL)
    slotLabel:SetAnchor(TOPLEFT, frame, TOPLEFT, 3,1)
    slotLabel:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -3,1)
    slotLabel:SetHeight(24)
    slotLabel:SetFont("$(BOLD_FONT)|14|soft-shadow-thick")
    slotLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    slotLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    slotLabel:SetColor(0.95,0.82,0.42,1)
    slotLabel:SetText("")

    local ultimatePct = wm:CreateControl(name .. "UltimatePct", frame, CT_LABEL)
    -- Keep Ultimate charge readable without covering the ability artwork.
    -- A compact lower-right label leaves the center of the icon unobstructed.
    ultimatePct:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -3, -2)
    ultimatePct:SetDimensions(34, 14)
    ultimatePct:SetFont("ZoFontGameSmall")
    ultimatePct:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    ultimatePct:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    ultimatePct:SetColor(1.00,0.86,0.36,1)
    ultimatePct:SetText("")
    ultimatePct:SetHidden(true)

    local hint = wm:CreateControl(name .. "Hint", frame, CT_LABEL)
    hint:SetAnchor(TOP, frame, BOTTOM, 0, 2)
    hint:SetDimensions(90,18)
    hint:SetFont("ZoFontGameSmall")
    hint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    hint:SetColor(0.95,0.82,0.42,1)
    hint:SetText("DRAG")
    hint:SetHidden(true)

    frame:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            local lk,tk = A:GetPositionKeys(control.epcSlot)
            EPC.saved[lk] = control:GetLeft()
            EPC.saved[tk] = control:GetTop()
        end
    end)

    frame.epcBG,frame.epcIcon,frame.epcShade,frame.epcTimerBack = bg,icon,shade,timerBack
    frame.epcCooldown,frame.epcEffect,frame.epcSlotLabel,frame.epcHint,frame.epcUltimatePct = cooldown,effect,slotLabel,hint,ultimatePct
    frame.epcSmartGlowOuter029168 = smartGlowOuter
    frame.epcSmartGlowMid029168 = smartGlowMid
    frame.epcSmartHighlight029167 = smartHighlight
    self:AnchorWidget(frame, ordinal)
    return frame
end

function A:ApplySize()
    local size = math.max(40, math.min(90, tonumber(EPC.saved and EPC.saved.abilityOverlaySize) or 56))
    if self:IsUnifiedSingleBar029734() then
        self:LayoutUnifiedSingleBar029734()
        return
    end
    if self.singleBarGroup029734 then self.singleBarGroup029734:SetHidden(true) end
    for i,widget in ipairs(self.widgets or {}) do
        widget:SetScale(tonumber(EPC.saved and EPC.saved.abilityOverlayScale) or 1.0)
        widget:SetDimensions(size,size)
        self:AnchorWidget(widget,i)
        if widget.epcBG then
            widget.epcBG:SetCenterColor(0.012,0.015,0.022,0.78)
            widget.epcBG:SetEdgeColor(0.67,0.51,0.24,0.95)
            widget.epcBG:SetEdgeTexture(nil,1,1,1)
        end
        if widget.epcOffReady029734 then widget.epcOffReady029734:SetHidden(true) end
    end
end

local function RefreshWidgetBase(self, widget, category)
    if not widget then return end
    category = category ~= nil and category or safe(GetActiveHotbarCategory, nil)
    local slot = widget.epcSlot
    local used = safe(IsSlotUsed, false, slot, category) == true
    local texture = safe(GetSlotTexture, "", slot, category)
    local abilityName = safe(GetSlotName, "", slot, category)
    local show = EPC.saved and EPC.saved.showAbilityOverlays ~= false
    if not self.layoutMode and EPC.OverlayModeAllows then show = show and EPC:OverlayModeAllows("abilityOverlayVisibility") end
    if not self.layoutMode and EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then show = false end
    if not self.layoutMode and not used then show = false end
    widget:SetHidden(not show)
    if not show then return end

    if texture and texture ~= "" then
        widget.epcIcon:SetTexture(texture)
        widget.epcIcon:SetHidden(false)
    else
        widget.epcIcon:SetHidden(true)
    end

    local usable = safe(IsSlotUsable, true, slot, category) ~= false
    widget.epcShade:SetCenterColor(0,0,0,usable and 0 or 0.48)

    local remain,duration,isGlobal = safe(GetSlotCooldownInfo, 0, slot, category)
    remain,duration = tonumber(remain) or 0, tonumber(duration) or 0
    -- Do not spam the normal global cooldown. Only show a real slot cooldown.
    if remain > 0 and duration > 0 and not isGlobal then
        widget.epcCooldown:SetText(formatMS(remain))
    else
        widget.epcCooldown:SetText("")
    end

    local effectRemaining = tonumber(safe(GetActionSlotEffectTimeRemaining, 0, slot, category)) or 0
    widget.epcEffect:SetText(effectRemaining > 0 and formatMS(effectRemaining) or "")
    -- Avoid stacking two countdowns in the center. Active effect duration takes priority;
    -- once it ends, the normal slot cooldown can use the same central area.
    if effectRemaining > 0 then
        widget.epcCooldown:SetText("")
    end
    if widget.epcTimerBack then
        local timerVisible = effectRemaining > 0 or (remain > 0 and duration > 0 and not isGlobal)
        widget.epcTimerBack:SetHidden(not timerVisible)
        if timerVisible then
            local timerLabel = effectRemaining > 0 and widget.epcEffect or widget.epcCooldown
            local textWidth, textHeight = 0, 0
            if timerLabel and type(timerLabel.GetTextDimensions) == "function" then
                textWidth, textHeight = timerLabel:GetTextDimensions()
            end
            textWidth = tonumber(textWidth) or 0
            textHeight = tonumber(textHeight) or 0
            widget.epcTimerBack:SetDimensions(math.max(32, textWidth + 18), math.max(28, textHeight + 10))
        end
    end
    if not self:IsUnifiedSingleBar029734() then
        widget:SetScale(tonumber(EPC.saved.abilityOverlayScale) or 1.0)
    end
    local isUltimate = widget.epcOrdinal == #self.widgets
    -- Display the player's real ESO Controls binding for this action slot.
    -- Skills 1-5 are ACTION_BUTTON_3..7 and Ultimate is ACTION_BUTTON_8;
    -- never hardcode 1-5/U because every player may rebind these controls.
    local bindingText = self:GetBindingTextForSlot(slot)
    if bindingText == "" then bindingText = "—" end
    if widget.epcBindingText ~= bindingText or widget.epcBindingWasUltimate029182 ~= isUltimate then
        widget.epcBindingText = bindingText
        widget.epcBindingWasUltimate029182 = isUltimate
        widget.epcSlotLabel:ClearAnchors()
        if isUltimate then
            -- Ultimate commonly uses a two-button chord (L1+R1). Give that wide
            -- glyph the full top edge and center it instead of squeezing it into
            -- the single-button top-left treatment used by skills 1-5.
            widget.epcSlotLabel:SetAnchor(TOPLEFT, widget, TOPLEFT, 2, 0)
            widget.epcSlotLabel:SetAnchor(TOPRIGHT, widget, TOPRIGHT, -2, 0)
            widget.epcSlotLabel:SetHeight(24)
            widget.epcSlotLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        else
            widget.epcSlotLabel:SetAnchor(TOPLEFT, widget, TOPLEFT, 3, 1)
            widget.epcSlotLabel:SetAnchor(TOPRIGHT, widget, TOPRIGHT, -3, 1)
            widget.epcSlotLabel:SetHeight(24)
            widget.epcSlotLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        end
        widget.epcSlotLabel:SetText(bindingText)
        local usesMarkup = bindingText:find("|k", 1, true) ~= nil
            or bindingText:find("|u", 1, true) ~= nil
            or bindingText:find("|t", 1, true) ~= nil
        local chars = #bindingText
        local fontSize = usesMarkup and 14 or (chars <= 4 and 14 or (chars <= 7 and 12 or 10))
        widget.epcSlotLabel:SetFont("$(BOLD_FONT)|" .. tostring(fontSize) .. "|soft-shadow-thick")
    end
    if widget.epcUltimatePct then
        if isUltimate and used and COMBAT_MECHANIC_FLAGS_ULTIMATE then
            local current = safe(GetUnitPower, 0, "player", COMBAT_MECHANIC_FLAGS_ULTIMATE)
            current = tonumber(current) or 0
            -- ESO stores Ultimate as a 0..500 point pool. Show that stored
            -- pool directly as 0%..500% instead of converting the equipped
            -- Ultimate's cost into a 0..100 readiness percentage. Readiness is
            -- still determined from the real slotted Ultimate cost below, so
            -- the meter can continue charging after the ability is usable.
            local cost = tonumber(safe(GetSlotAbilityCost, 0, slot)) or 0
            -- Current ESO Ultimate storage is capped at 500. Keep a defensive
            -- upper bound here so a transient/bad API value cannot overflow UI.
            local pct = math.max(0, math.min(500, math.floor(current + 0.5)))
            local ready = cost > 0 and current >= cost
            widget.epcUltimatePct:SetText(tostring(pct) .. "%")
            widget.epcUltimatePct:SetColor(ready and 1.00 or 0.93, ready and 0.76 or 0.86, ready and 0.18 or 0.36, 1)
            widget.epcUltimatePct:SetHidden(false)
        else
            widget.epcUltimatePct:SetHidden(true)
        end
    end

    if self.layoutMode and (not abilityName or abilityName == "") then
        widget.epcCooldown:SetText(widget.epcOrdinal == #self.widgets and "ULT" or tostring(widget.epcOrdinal))
        if widget.epcTimerBack then widget.epcTimerBack:SetHidden(false) end
    end
    self:RefreshOffBarReadyStrip029734(widget,category)
end

-- v0.29.167 - Smart Combat Advisor highlight on Suite ability overlays.
local function SetSmartRecommendationBase029167(self, slot, category, pulseAlpha)
    self.smartRecommendedSlot029161 = tonumber(slot)
    self.smartRecommendedCategory029161 = category
    local activeCategory = safe(GetActiveHotbarCategory, nil)
    local shown = false
    -- pulseAlpha is retained for API compatibility, but intentionally ignored.
    for _, widget in ipairs(self.widgets or {}) do
        local highlight = widget and widget.epcSmartHighlight029167
        local mid = widget and widget.epcSmartGlowMid029168
        local outer = widget and widget.epcSmartGlowOuter029168
        if highlight then
            local match = self.smartRecommendedSlot029161 ~= nil
                and tonumber(widget.epcSlot) == self.smartRecommendedSlot029161
                and (category == nil or category == activeCategory)
                and not widget:IsHidden()
            highlight:SetHidden(not match)
            if mid then mid:SetHidden(not match) end
            if outer then outer:SetHidden(not match) end
            if match then
                -- Steady recommendation: readable at a glance without flashing.
                highlight:SetAlpha(1.00)
                if mid then mid:SetAlpha(0.72) end
                if outer then outer:SetAlpha(0.42) end
                shown = true
            end
        end
    end
    return shown
end

local function ClearSmartRecommendationBase029167(self)
    self.smartRecommendedSlot029161 = nil
    self.smartRecommendedCategory029161 = nil
    for _, widget in ipairs(self.widgets or {}) do
        if widget and widget.epcSmartHighlight029167 then
            widget.epcSmartHighlight029167:SetHidden(true)
        end
        if widget and widget.epcSmartGlowMid029168 then
            widget.epcSmartGlowMid029168:SetHidden(true)
        end
        if widget and widget.epcSmartGlowOuter029168 then
            widget.epcSmartGlowOuter029168:SetHidden(true)
        end
    end
end

function A:Refresh()
    self:ApplySize()
    local category = safe(GetActiveHotbarCategory, nil)
    local anyVisible029736 = false
    for _,widget in ipairs(self.widgets or {}) do
        self:RefreshWidget(widget, category)
        if widget and not widget:IsHidden() then anyVisible029736 = true end
    end

    -- The unified single-bar backdrop is a separate parent control. The slots
    -- correctly hide in pause/menu scenes, but the parent background must also
    -- follow that final visibility state or it leaves an empty black rectangle.
    if self.singleBarGroup029734 and self:IsUnifiedSingleBar029734() then
        local showGroup029736 = anyVisible029736
        if not self.layoutMode and EPC.saved and EPC.saved.showAbilityOverlays == false then
            showGroup029736 = false
        end
        if not self.layoutMode and EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then
            showGroup029736 = false
        end
        if not self.layoutMode and EPC.OverlayModeAllows then
            showGroup029736 = showGroup029736 and EPC:OverlayModeAllows("abilityOverlayVisibility")
        end
        self.singleBarGroup029734:SetHidden(not showGroup029736)
    end

    if self.smartRecommendedSlot029161 then
        self:SetSmartRecommendation029167(self.smartRecommendedSlot029161, self.smartRecommendedCategory029161, 1.0)
    else
        self:ClearSmartRecommendation029167()
    end
end

function A:SetLayoutMode(active)
    self.layoutMode = active == true
    local unified=self:IsUnifiedSingleBar029734()
    local group=self:EnsureSingleBarGroup029734()

    group:SetMouseEnabled(self.layoutMode and unified)
    group:SetMovable(self.layoutMode and unified)

    if not group.epcMoveHook029734 then
        group.epcMoveHook029734=true
        group:SetClampedToScreen(true)

        local function saveUnifiedPosition029737(control)
            if not EPC.saved or not A.widgets or not A.widgets[1] then return end
            local first=A.widgets[1]
            local lk,tk=A:GetPositionKeys(first.epcSlot)
            EPC.saved[lk]=control:GetLeft()+4
            EPC.saved[tk]=control:GetTop()+4
        end

        group:SetHandler("OnMouseDown",function(control,button)
            if button~=MOUSE_BUTTON_INDEX_LEFT or not A.layoutMode or not A:IsUnifiedSingleBar029734() then return end
            control.epcDragging029737=true
            control:StartMoving()
        end)

        group:SetHandler("OnMouseUp",function(control,button,upInside)
            if button~=MOUSE_BUTTON_INDEX_LEFT or not control.epcDragging029737 then return end
            control:StopMovingOrResizing()
            saveUnifiedPosition029737(control)
            control.epcDragging029737=false
        end)

        group:SetHandler("OnMoveStop",function(control)
            saveUnifiedPosition029737(control)
            control.epcDragging029737=false
        end)
    end

    for _,widget in ipairs(self.widgets or {}) do
        if unified then
            -- In unified single-bar HUD Layout, every visible slot forwards the
            -- first left mouse-down to the shared bar. This removes the
            -- select-first / drag-second feeling.
            widget:SetMouseEnabled(self.layoutMode)
            widget:SetMovable(false)

            if not widget.epcUnifiedMoveForward029738 then
                widget.epcUnifiedMoveForward029738=true
                widget:SetHandler("OnMouseDown",function(control,button)
                    if button~=MOUSE_BUTTON_INDEX_LEFT or not A.layoutMode or not A:IsUnifiedSingleBar029734() then return end
                    local bar=A.singleBarGroup029734
                    if not bar then return end
                    bar.epcDragging029737=true
                    bar:StartMoving()
                end)
                widget:SetHandler("OnMouseUp",function(control,button,upInside)
                    if button~=MOUSE_BUTTON_INDEX_LEFT then return end
                    local bar=A.singleBarGroup029734
                    if not bar or not bar.epcDragging029737 then return end
                    bar:StopMovingOrResizing()
                    if EPC.saved and A.widgets and A.widgets[1] then
                        local first=A.widgets[1]
                        local lk,tk=A:GetPositionKeys(first.epcSlot)
                        EPC.saved[lk]=bar:GetLeft()+4
                        EPC.saved[tk]=bar:GetTop()+4
                    end
                    bar.epcDragging029737=false
                end)
            end
        else
            widget:SetMouseEnabled(self.layoutMode)
            widget:SetMovable(self.layoutMode)
        end
        widget.epcHint:SetHidden(not self.layoutMode)
    end
    self:Refresh()
end

function A:ResetPositions()
    if not EPC.saved then return end
    for i,widget in ipairs(self.widgets or {}) do
        local lk,tk = self:GetPositionKeys(widget.epcSlot)
        EPC.saved[lk],EPC.saved[tk] = -1,-1
        if not self:IsUnifiedSingleBar029734() then self:AnchorWidget(widget,i) end
    end
    if self:IsUnifiedSingleBar029734() then self:LayoutUnifiedSingleBar029734() end
end

local function InitializeBase(self)
    self.layoutMode = false
    self:EnsureRoot029707()
    self.widgets = {}
    local slots = self:GetSlots()
    for i,slot in ipairs(slots) do self.widgets[i] = self:CreateWidget(slot,i) end
    local prefix = EPC.name .. "_AbilityOverlays"
    if EVENT_ACTION_SLOT_UPDATED then EPC.Runtime:RegisterEvent("AbilityOverlays","Slot",EVENT_ACTION_SLOT_UPDATED, function() self:Refresh() end) end
    if EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED then EPC.Runtime:RegisterEvent("AbilityOverlays","Bar",EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, function() self:Refresh() end) end
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then EPC.Runtime:RegisterEvent("AbilityOverlays","Weapon",EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function() self:Refresh() end) end
    if EVENT_PLAYER_COMBAT_STATE then EPC.Runtime:RegisterEvent("AbilityOverlays","Combat",EVENT_PLAYER_COMBAT_STATE, function() self:Refresh() end) end
    if EVENT_PLAYER_ACTIVATED then EPC.Runtime:RegisterEvent("AbilityOverlays","Activated",EVENT_PLAYER_ACTIVATED, function() self:InvalidateBindingText() self:Refresh() end) end
    if EVENT_KEYBINDINGS_LOADED then EPC.Runtime:RegisterEvent("AbilityOverlays","BindingsLoaded",EVENT_KEYBINDINGS_LOADED, function() self:InvalidateBindingText() self:Refresh() end) end
    if EVENT_KEYBINDING_SET then EPC.Runtime:RegisterEvent("AbilityOverlays","BindingSet",EVENT_KEYBINDING_SET, function() self:InvalidateBindingText() self:Refresh() end) end
    if EVENT_KEYBINDING_CLEARED then EPC.Runtime:RegisterEvent("AbilityOverlays","BindingCleared",EVENT_KEYBINDING_CLEARED, function() self:InvalidateBindingText() self:Refresh() end) end
    EPC.Runtime:RegisterUpdate("AbilityOverlays","Tick",125, function()
        local nowValue = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
        local inCombat = type(IsUnitInCombat) == "function" and safe(IsUnitInCombat, false, "player") == true
        local gap = inCombat and 250 or 1000
        if self.layoutMode or not self.lastTickRefresh029312 or (nowValue - self.lastTickRefresh029312) >= gap then
            self.lastTickRefresh029312 = nowValue
            self:Refresh()
        end
    end)
    self:InvalidateBindingText()
    self:Refresh()
end

-- v0.29.171 - Make the moment-to-moment recommendation unmistakable on the
-- Suite ability row. The existing three-layer glow remains unchanged; this
-- adds a small NEXT badge above only the recommended visible slot.
function A:EnsureSmartNextBadges029171()
    for _, widget in ipairs(self.widgets or {}) do
        if widget and not widget.epcSmartNext029171 then
            local badge = wm:CreateControl(nil, widget, CT_LABEL)
            badge:SetAnchor(BOTTOM, widget, TOP, 0, -5)
            badge:SetDimensions(84, 20)
            badge:SetFont("$(BOLD_FONT)|15|soft-shadow-thick")
            badge:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            badge:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            badge:SetColor(1.00, 0.92, 0.30, 1.00)
            badge:SetText("NEXT")
            if badge.SetDrawLayer and DL_OVERLAY then badge:SetDrawLayer(DL_OVERLAY) end
            if badge.SetDrawLevel then badge:SetDrawLevel(2600) end
            badge:SetHidden(true)
            widget.epcSmartNext029171 = badge
        end
    end
end

function A:SetSmartRecommendation029167(slot, category, pulseAlpha)
    self:EnsureSmartNextBadges029171()
    local shown = SetSmartRecommendationBase029167(self, slot, category, pulseAlpha)
    local activeCategory = safe(GetActiveHotbarCategory, nil)
    for _, widget in ipairs(self.widgets or {}) do
        local badge = widget and widget.epcSmartNext029171
        if badge then
            local match = shown
                and tonumber(widget.epcSlot) == tonumber(slot)
                and (category == nil or category == activeCategory)
                and not widget:IsHidden()
            badge:SetHidden(not match)
            if match then
                badge:SetAlpha(1.00)
            end
        end
    end
    return shown
end

function A:ClearSmartRecommendation029167()
    ClearSmartRecommendationBase029167(self)
    for _, widget in ipairs(self.widgets or {}) do
        if widget and widget.epcSmartNext029171 then widget.epcSmartNext029171:SetHidden(true) end
    end
end


-- ============================================================================
-- v0.29.365 - API-driven proc/Ultimate readiness alerts.
-- ============================================================================
local function EAS_OverlayNow029365()
    if type(GetFrameTimeMilliseconds)=="function" then return tonumber(safe(GetFrameTimeMilliseconds,0)) or 0 end
    return 0
end
function A:EnsureReadyGlow029365(widget)
    if not widget or widget.epcReadyGlow029365 then return end
    local glow=wm:CreateControl(nil,widget,CT_BACKDROP); glow:SetAnchorFill(widget); glow:SetMouseEnabled(false)
    glow:SetCenterColor(1.00,0.68,0.05,0.06); glow:SetEdgeColor(1.00,0.88,0.20,1.00); glow:SetEdgeTexture(nil,8,8,5)
    if glow.SetDrawLayer and DL_OVERLAY then glow:SetDrawLayer(DL_OVERLAY) end; if glow.SetDrawLevel then glow:SetDrawLevel(2550) end
    glow:SetHidden(true); widget.epcReadyGlow029365=glow
end
function A:GetSlotStateSignature029365(slot,category)
    local base=tonumber((safe(GetSlotBoundId,0,slot,category))) or 0
    local effective=base
    if base>0 and type(GetEffectiveAbilityIdForAbilityOnHotbar)=="function" then effective=tonumber((safe(GetEffectiveAbilityIdForAbilityOnHotbar,base,base,category))) or base end
    local texture=tostring(safe(GetSlotTexture,"",slot,category) or "")
    return tostring(base)..":"..tostring(effective)..":"..texture,base,effective
end
local function RefreshWidgetReady029365(self, widget, category)
    RefreshWidgetBase(self, widget, category)
    if not widget then return end
    self:EnsureReadyGlow029365(widget)
    local glow=widget.epcReadyGlow029365; if not glow then return end
    category=category ~= nil and category or safe(GetActiveHotbarCategory,nil); local slot=widget.epcSlot
    local nowMs=EAS_OverlayNow029365(); local isUltimate=widget.epcOrdinal==#(self.widgets or {})
    local sig,base,effective=self:GetSlotStateSignature029365(slot,category)
    local prior=widget.epcStateSignature029365
    local suppressUntil=tonumber(self.readyBaselineUntil029365) or 0
    local procActive = not isUltimate and base > 0 and effective > 0 and effective ~= base
    if procActive and widget.epcProcActiveWas029365 ~= true and prior and nowMs > suppressUntil then
        local sound=SOUNDS and (rawget(SOUNDS,"ABILITY_SLOTTED") or rawget(SOUNDS,"DEFAULT_CLICK"))
        if sound and type(PlaySound)=="function" then pcall(PlaySound,sound) end
    end
    widget.epcProcActiveWas029365 = procActive
    widget.epcStateSignature029365=sig
    local ultimateReady=false
    if isUltimate and base>0 and COMBAT_MECHANIC_FLAGS_ULTIMATE then
        local current=tonumber((safe(GetUnitPower,0,"player",COMBAT_MECHANIC_FLAGS_ULTIMATE))) or 0
        local cost=tonumber((safe(GetSlotAbilityCost,0,slot))) or 0
        ultimateReady=cost>0 and current>=cost
        if ultimateReady and widget.epcUltimateWasReady029365~=true then
            local sound=SOUNDS and rawget(SOUNDS,"ABILITY_ULTIMATE_READY")
            if sound and type(PlaySound)=="function" then pcall(PlaySound,sound) end
        end
        widget.epcUltimateWasReady029365=ultimateReady
    end
    local procReady=procActive
    glow:SetHidden(not (ultimateReady or procReady) or widget:IsHidden())
    if not glow:IsHidden() then
        local phase=(nowMs%700)/700; local alpha=0.55+0.45*math.abs(phase*2-1)
        glow:SetAlpha(alpha)
    end
end
function A:Initialize()
    InitializeBase(self)
    self.readyBaselineUntil029365=EAS_OverlayNow029365()+600
    local prefix=(EPC.name or "ESOAdventurerSuite").."_ReadyAlerts029365"
    local function resetBaseline() self.readyBaselineUntil029365=EAS_OverlayNow029365()+350; for _,w in ipairs(self.widgets or {}) do w.epcStateSignature029365=nil end; self:Refresh() end
    if EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED then EPC.Runtime:RegisterEvent("AbilityOverlays","ReadyBar",EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED,function() resetBaseline() end) end
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then EPC.Runtime:RegisterEvent("AbilityOverlays","ReadyWeapon",EVENT_ACTIVE_WEAPON_PAIR_CHANGED,function() resetBaseline() end) end
end



-- Absorbed passive ability correction layers

-- BEGIN ABSORBED: AbilityAvailabilityFix.lua
-- ESO Adventurer Suite
-- v0.29.513 - lightweight native action-bar availability feedback.
-- Makes Suite ability icons clearly grey/dim whenever ESO considers the slot
-- unusable (target/range/state/resource/etc.) without forcing native button
-- refresh work on every Suite repaint.

local EPC = ESOProgressionCoach
if not EPC then return end

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d
end

local function GetSlotAvailability029513(slot, category)
    slot = tonumber(slot)
    if not slot then return true end

    local activeCategory = safe(GetActiveHotbarCategory, nil)

    -- Inactive weapon-bar icons already have their own dim/desaturation state.
    -- Do not run active-useability work on those slots every dynamic tick.
    if category ~= activeCategory then return true end

    local usable = safe(IsSlotUsable, true, slot, category) ~= false

    -- ESO's own ActionButton already refreshes its live failure state when the
    -- player casts, targets, moves in/out of range, etc. Read that state only;
    -- do NOT call UpdateUseFailure() from addon code on every Suite repaint.
    if type(ZO_ActionBar_GetButton) == "function" then
        local button = safe(ZO_ActionBar_GetButton, nil, slot, category)
        if button then
            if button.useFailure == true then
                usable = false
            elseif button.usable ~= nil then
                usable = button.usable == true
            end
        end
    end

    return usable
end

local function ApplyAvailabilityVisual029513(icon, shade, usable, baseDesaturation)
    if not icon then return end
    local unavailable = usable == false
    baseDesaturation = tonumber(baseDesaturation) or 0

    if icon.SetDesaturation then
        icon:SetDesaturation(unavailable and 1 or baseDesaturation)
    end
    if icon.SetAlpha then
        icon:SetAlpha(unavailable and 0.42 or 1.0)
    end
    if shade then
        shade:SetHidden(false)
        shade:SetCenterColor(0, 0, 0, unavailable and 0.62 or 0)
        shade:SetEdgeColor(0, 0, 0, 0)
    end
end

-- Single-row Ability Overlays -------------------------------------------------
function A:RefreshWidget(widget, ...)
    local result = RefreshWidgetReady029365(self, widget, ...)
    if not widget or widget:IsHidden() or self.layoutMode then return result end

    local category = safe(GetActiveHotbarCategory, nil)
    local slot = widget.epcSlot
    if safe(IsSlotUsed, false, slot, category) == true then
        local usable = GetSlotAvailability029513(slot, category)
        ApplyAvailabilityVisual029513(widget.epcIcon, widget.epcShade, usable, 0)
        widget.epcUnavailable029513 = not usable
    end

    if refreshAbilityUltimate029668 and self.widgets and widget == self.widgets[#self.widgets] then
        refreshAbilityUltimate029668()
    end
    return result
end

-- Dual Action Bar availability is owned by DualActionBar.lua.

-- END ABSORBED: AbilityAvailabilityFix.lua

-- BEGIN ABSORBED: AbilityCastPerformanceFix.lua
-- ESO Adventurer Suite
-- v0.29.646 - cast-time UI performance guard + hard weapon-swap bypass fix.
-- Coalesces duplicate action-bar/advisor refreshes that can arrive together
-- when an ability is used. Keeps gameplay totals and ESO input untouched.
-- Delayed closures are explicitly swap-aware so they cannot bypass the later
-- RuntimePerformanceCoreOwnership outer gate by calling a captured base method.

local EPC = ESOProgressionCoach
if not EPC then return end

local function nowMS()
    if type(GetFrameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetFrameTimeMilliseconds)
        if ok then return tonumber(value) or 0 end
    end
    if type(GetGameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetGameTimeMilliseconds)
        if ok then return tonumber(value) or 0 end
    end
    return 0
end

local function inCombat()
    if type(IsUnitInCombat) ~= "function" then return false end
    local ok, value = pcall(IsUnitInCombat, "player")
    return ok and value == true
end

local function weaponSwapBlocked()
    local now = nowMS()
    local untilMs = tonumber(EPC.weaponSwapBroadRefreshUntil029636)
        or tonumber(EPC.weaponSwapSettlingUntil029636)
        or tonumber(EPC.weaponSwapSettlingUntil029635)
        or 0
    return now > 0 and now < untilMs
end

local function wrapRefresh(object, methodName, stateKey, minGap)
    if type(object) ~= "table" or type(object[methodName]) ~= "function" then return end
    local wrappedKey = "_easCastPerfWrapped_" .. stateKey
    if object[wrappedKey] then return end
    object[wrappedKey] = true

    local base = object[methodName]
    local lastKey = "_easCastPerfLast_" .. stateKey
    local pendingKey = "_easCastPerfPending_" .. stateKey

    object[methodName] = function(self, ...)
        -- Layout/editing actions should remain immediate.
        if self and self.layoutMode == true then
            self[lastKey] = nowMS()
            self[pendingKey] = false
            return base(self, ...)
        end

        -- Critical: a normal Primary/Backup swap owns this frame. Drop all
        -- cast/proc/advisor presentation work. Controlled timers reconcile later.
        if weaponSwapBlocked() then
            if self then self[pendingKey] = false end
            return nil
        end

        if not inCombat() then
            self[lastKey] = nowMS()
            self[pendingKey] = false
            return base(self, ...)
        end

        local now = nowMS()
        local last = tonumber(self[lastKey]) or 0
        local gap = now - last
        if last == 0 or gap >= minGap then
            self[lastKey] = now
            self[pendingKey] = false
            return base(self, ...)
        end

        -- One pending refresh is enough for a burst of slot/cooldown/proc events.
        if self[pendingKey] ~= true and type(zo_callLater) == "function" then
            self[pendingKey] = true
            local delay = math.max(1, math.floor(minGap - gap + 0.5))
            zo_callLater(function()
                if not self then return end
                self[pendingKey] = false

                -- base is a captured pre-wrapper method. Without this explicit
                -- guard it bypasses every later outer weapon-swap wrapper.
                if self.layoutMode ~= true and weaponSwapBlocked() then return end

                self[lastKey] = nowMS()
                base(self)
            end, delay)
        end
        return nil
    end
end

-- AbilityOverlays already has a periodic live tick. Slot-updated events can
-- otherwise force the same six-widget rebuild several times around one cast.
wrapRefresh(EPC.AbilityOverlays, "Refresh", "AbilityOverlays029513", 100)

-- Smart Combat Advisor can receive slot updates at the same time as its own
-- timer tick. Keep recommendation response fast but never rebuild repeatedly in
-- the same cast burst.
wrapRefresh(EPC.RotationAssistant, "Refresh", "RotationAssistant029513", 120)

-- END ABSORBED: AbilityCastPerformanceFix.lua

-- Live effective ability state is owned by DualActionBar.lua.


-- BEGIN ABSORBED: UltimatePercentFix.lua
-- ESO Adventurer Suite
-- v0.29.668 - authoritative 0..500 Ultimate pool presentation.
-- The Suite displays ESO's stored Ultimate points directly with a percent sign.
-- This file owns one lightweight pulse and final-write guards on the two Suite
-- Ultimate renderers so no later refresh can collapse 500% back to 100%.

local EPC = ESOProgressionCoach
if not EPC or not EVENT_MANAGER then return end
local A = EPC.AbilityOverlays
local EM = EVENT_MANAGER
local NAME = (EPC.name or "ESOAdventurerSuite") .. "_UltimatePresentation029668"
local POST_SWAP_COOLDOWN_MS = 1200
local MAX_ULTIMATE_DISPLAY = 500

local function safe1(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a
end

local function nowMs()
    if type(GetFrameTimeMilliseconds) == "function" then return tonumber(GetFrameTimeMilliseconds()) or 0 end
    if type(GetGameTimeMilliseconds) == "function" then return tonumber(GetGameTimeMilliseconds()) or 0 end
    return 0
end

local function swapPresentationBlocked()
    local stamp = nowMs()
    local untilMs = tonumber(EPC.weaponSwapBroadRefreshUntil029636)
        or tonumber(EPC.weaponSwapSettlingUntil029636) or 0
    return stamp > 0 and untilMs > 0 and stamp < (untilMs + POST_SWAP_COOLDOWN_MS)
end

local function activeCategory()
    return safe1(GetActiveHotbarCategory, nil)
end

local function ultimateSlot()
    local D = GetDualActionBar029647()
    local base = tonumber(rawget(_G, "ACTION_BAR_ULTIMATE_SLOT_INDEX"))
    if base ~= nil then return base + 1 end
    return 8
end

local COST_CACHE = {}
local function invalidateCostCache()
    COST_CACHE = {}
    local W = EPC.WorldUltimateReadiness029640
    if W and type(W.Invalidate029647) == "function" then W:Invalidate029647() end
end

local function getUltimateCost(slot, category)
    slot = tonumber(slot) or ultimateSlot()
    local key = tostring(category) .. ":" .. tostring(slot)
    local cached = COST_CACHE[key]
    if cached ~= nil then return cached end
    local cost = tonumber(safe1(GetSlotAbilityCost, 0, slot, category)) or 0
    if cost <= 0 then
        local abilityId = tonumber(safe1(GetSlotBoundId, 0, slot, category)) or 0
        local flag = rawget(_G, "COMBAT_MECHANIC_FLAGS_ULTIMATE")
        if abilityId > 0 and flag ~= nil and type(GetAbilityCost) == "function" then
            cost = tonumber(safe1(GetAbilityCost, 0, abilityId, flag, nil, "player")) or 0
        end
    end
    cost = math.max(0, cost)
    COST_CACHE[key] = cost
    return cost
end

-- ESO stores Ultimate as a 0..500 resource pool. The on-icon percentage is
-- intentionally that pool value with a percent sign: 100 Ultimate = 100%,
-- 250 Ultimate = 250%, and a full pool = 500%.
local function getUltimatePercent(slot, category)
    local flag = rawget(_G, "COMBAT_MECHANIC_FLAGS_ULTIMATE")
    if flag == nil then return 0, false, 0, 0 end
    local current = tonumber(safe1(GetUnitPower, 0, "player", flag)) or 0
    local cost = getUltimateCost(slot, category)
    local pct = math.floor(current + 0.5)
    pct = math.max(0, math.min(MAX_ULTIMATE_DISPLAY, pct))
    return pct, cost > 0 and current >= cost, current, cost
end

local function setPctLabel(label, pct, ready)
    if not label then return end
    label:SetText(tostring(pct) .. "%")
    if label.SetColor then
        if ready then label:SetColor(1.00, 0.78, 0.18, 1.00)
        else label:SetColor(0.93, 0.86, 0.36, 1.00) end
    end
end

refreshAbilityUltimate029668 = function()
    if not A or not A.widgets or #A.widgets == 0 or not EPC.saved or EPC.saved.showAbilityOverlays == false then return end
    local widget = A.widgets[#A.widgets]
    if not widget or not widget.epcUltimatePct then return end
    local category = activeCategory()
    local slot = widget.epcSlot or ultimateSlot()
    if safe1(IsSlotUsed, false, slot, category) ~= true then
        widget.epcUltimatePct:SetHidden(true)
        return
    end
    local pct, ready = getUltimatePercent(slot, category)
    setPctLabel(widget.epcUltimatePct, pct, ready)
    widget.epcUltimatePct:SetHidden(false)
end

local function refreshDualUltimates()
    local D = EPC.DualActionBar
    if not D or not D.rows or not EPC.saved or EPC.saved.showDualActionBar029189 ~= true then return end
    local ultOrdinal = #(D.slots or {})
    if ultOrdinal <= 0 then return end
    local slot = D.slots[ultOrdinal] or ultimateSlot()
    for _, row in ipairs(D.rows) do
        local category = row.epcCategory
        local frame = row.slots and row.slots[ultOrdinal]
        if frame and frame.epcUltimate then
            if safe1(IsSlotUsed, false, slot, category) == true then
                local pct, ready = getUltimatePercent(slot, category)
                setPctLabel(frame.epcUltimate, pct, ready)
                -- Keep the Dual Action Bar's text cache synchronized too. If
                -- another dynamic refresh uses the cached setter, it now sees
                -- the same authoritative 0..500 text rather than an old 100%.
                frame.ultimateText029311 = tostring(pct) .. "%"
            else
                frame.epcUltimate:SetText("")
                frame.ultimateText029311 = ""
            end
        end
    end
end

local function refreshPresentation()
    if swapPresentationBlocked() then return end
    local W = EPC.WorldUltimateReadiness029640
    if W and type(W.RefreshPresentation029647) == "function" then
        W:RefreshPresentation029647()
    end
    refreshAbilityUltimate029668()
    refreshDualUltimates()
end

-- Final-write guards. Both base renderers are already running for other HUD
-- work, so these add only a tiny Ultimate label correction after those normal
-- refreshes; no new high-frequency polling loop is introduced.
local function installAuthoritativeRefreshGuards()
    -- Ability overlay final-write handling is integrated directly; Dual Action Bar owns its own renderer.
end

local function installPulse()
    EM:UnregisterForUpdate(NAME .. "_Pulse")
    EM:RegisterForUpdate(NAME .. "_Pulse", 500, refreshPresentation)
end

if rawget(_G, "EVENT_ACTION_SLOT_UPDATED") then
    EM:RegisterForEvent(NAME .. "_Slot", EVENT_ACTION_SLOT_UPDATED, invalidateCostCache)
end
if rawget(_G, "EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED") then
    EM:RegisterForEvent(NAME .. "_Bars", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, invalidateCostCache)
end
if rawget(_G, "EVENT_POWER_UPDATE") then
    local eventName = NAME .. "_Power"
    EM:RegisterForEvent(eventName, EVENT_POWER_UPDATE, function(_, unitTag, powerIndex, powerType)
        if unitTag == "player" and (powerType == rawget(_G, "POWERTYPE_ULTIMATE") or powerType == rawget(_G, "COMBAT_MECHANIC_FLAGS_ULTIMATE")) then
            -- Defer one frame so any ESO/Suite power-event refresh completes
            -- first, then make the displayed pool value the final write.
            if type(zo_callLater) == "function" then zo_callLater(refreshPresentation, 0)
            else refreshPresentation() end
        end
    end)
    if rawget(_G, "REGISTER_FILTER_UNIT_TAG") then
        EM:AddFilterForEvent(eventName, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
    end
    if rawget(_G, "REGISTER_FILTER_POWER_TYPE") and rawget(_G, "POWERTYPE_ULTIMATE") ~= nil then
        EM:AddFilterForEvent(eventName, EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, POWERTYPE_ULTIMATE)
    end
end
if rawget(_G, "EVENT_PLAYER_ACTIVATED") then
    EM:RegisterForEvent(NAME .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
        invalidateCostCache()
        installAuthoritativeRefreshGuards()
        if type(zo_callLater) == "function" then zo_callLater(refreshPresentation, 350) end
        installPulse()
    end)
end

installAuthoritativeRefreshGuards()
installPulse()

SLASH_COMMANDS = SLASH_COMMANDS or {}
SLASH_COMMANDS["/easultimate"] = function()
    local category = activeCategory()
    local slot = ultimateSlot()
    local pct, ready, current, cost = getUltimatePercent(slot, category)
    local text = string.format("EAS Ultimate | points=%d cost=%d display=%d%% ready=%s",
        math.floor(current + 0.5), math.floor(cost + 0.5), pct, ready and "yes" or "no")
    if type(d) == "function" then d(text) elseif EPC.Print then EPC:Print(text) end
end

-- END ABSORBED: UltimatePercentFix.lua


-- BEGIN ABSORBED: WorldAbilityReadinessFix.lua
-- ESO Adventurer Suite
-- v0.29.647 - World Ultimate readiness, detached from the Dual Action Bar chain.
-- No RefreshDynamic/AbilityOverlay wrapper is installed. Ultimate presentation is
-- refreshed by UltimatePercentFix's lightweight 500ms two-slot pulse instead.

local EPC = ESOProgressionCoach
if not EPC then return end

local A = EPC.AbilityOverlays
local WM = WINDOW_MANAGER
local function GetDualActionBar029647() return EPC.DualActionBar end

EPC.WorldUltimateReadiness029640 = EPC.WorldUltimateReadiness029640 or {}
local W = EPC.WorldUltimateReadiness029640
local POST_SWAP_COOLDOWN_MS = 1200

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a
end

local function nowMs()
    if type(GetFrameTimeMilliseconds) == "function" then return tonumber(GetFrameTimeMilliseconds()) or 0 end
    if type(GetGameTimeMilliseconds) == "function" then return tonumber(GetGameTimeMilliseconds()) or 0 end
    return 0
end

local function swapPresentationBlocked()
    local stamp = nowMs()
    local untilMs = tonumber(EPC.weaponSwapBroadRefreshUntil029636)
        or tonumber(EPC.weaponSwapSettlingUntil029636) or 0
    return stamp > 0 and untilMs > 0 and stamp < (untilMs + POST_SWAP_COOLDOWN_MS)
end

local function normalCategories()
    local primary = rawget(_G, "HOTBAR_CATEGORY_PRIMARY")
    local backup = rawget(_G, "HOTBAR_CATEGORY_BACKUP")
    if primary == nil then primary = 0 end
    if backup == nil then backup = 1 end
    return primary, backup
end

local function activeCategory()
    return safe(GetActiveHotbarCategory, nil)
end

local function ultimateSlot()
    local base = tonumber(rawget(_G, "ACTION_BAR_ULTIMATE_SLOT_INDEX"))
    if base ~= nil then return base + 1 end
    if D and type(D.slots) == "table" and #D.slots > 0 then return D.slots[#D.slots] end
    return 8
end

local function inSpecialHotbar()
    local D = GetDualActionBar029647()
    local category = activeCategory()
    local primary, backup = normalCategories()
    if category == nil or category == primary or category == backup then return false end
    if D and type(D.IsSingleTransformedHotbar029554) == "function" then
        local ok, transformed = pcall(D.IsSingleTransformedHotbar029554, D, category)
        if ok then return transformed == true end
    end
    return true
end

W.worldAbilityCache = W.worldAbilityCache or {}
W.slotCache029647 = W.slotCache029647 or {}

function W:Invalidate029647()
    self.slotCache029647 = {}
end

local function isWorldAbility(abilityId)
    abilityId = tonumber(abilityId) or 0
    if abilityId <= 0 then return false end
    local cached = W.worldAbilityCache[abilityId]
    if cached ~= nil then return cached == true end
    local worldType = rawget(_G, "SKILL_TYPE_WORLD")
    local result = false
    if worldType ~= nil and type(GetSpecificSkillAbilityKeysByAbilityId) == "function" then
        result = safe(GetSpecificSkillAbilityKeysByAbilityId, nil, abilityId) == worldType
    end
    W.worldAbilityCache[abilityId] = result
    return result
end

local function getUltimateCost(slot, category, abilityId)
    local cost = tonumber(safe(GetSlotAbilityCost, 0, slot, category)) or 0
    if cost <= 0 and type(GetAbilityCost) == "function" and rawget(_G, "COMBAT_MECHANIC_FLAGS_ULTIMATE") ~= nil then
        cost = tonumber(safe(GetAbilityCost, 0, abilityId, COMBAT_MECHANIC_FLAGS_ULTIMATE, nil, "player")) or 0
    end
    return math.max(0, cost)
end

local function getStatic(category)
    if category == nil then return nil end
    local cached = W.slotCache029647[category]
    if cached ~= nil then return cached ~= false and cached or nil end
    local slot = ultimateSlot()
    if safe(IsSlotUsed, false, slot, category) ~= true then
        W.slotCache029647[category] = false
        return nil
    end
    local abilityId = tonumber(safe(GetSlotBoundId, 0, slot, category)) or 0
    if abilityId <= 0 or not isWorldAbility(abilityId) then
        W.slotCache029647[category] = false
        return nil
    end
    local info = {
        category = category,
        slot = slot,
        abilityId = abilityId,
        icon = tostring(safe(GetSlotTexture, "", slot, category) or ""),
        name = tostring(safe(GetSlotName, "", slot, category) or ""),
        cost = getUltimateCost(slot, category, abilityId),
    }
    W.slotCache029647[category] = info
    return info
end

local function readWorldUltimate(category)
    local static = getStatic(category)
    if not static then return nil end
    local flag = rawget(_G, "COMBAT_MECHANIC_FLAGS_ULTIMATE")
    if flag == nil then return nil end
    local current = tonumber(safe(GetUnitPower, 0, "player", flag)) or 0
    return {
        category = static.category, slot = static.slot, abilityId = static.abilityId,
        icon = static.icon, name = static.name, cost = static.cost, current = current,
        ready = static.cost > 0 and current >= static.cost,
    }
end

local function worldUltimates()
    if inSpecialHotbar() then return nil, nil end
    local primary, backup = normalCategories()
    return readWorldUltimate(primary), readWorldUltimate(backup)
end

local function readyInactive()
    local current = activeCategory()
    local a, b = worldUltimates()
    if a and a.ready and a.category ~= current then return a end
    if b and b.ready and b.category ~= current then return b end
    return nil
end

local function readyKey(info)
    if not info or not info.ready then return nil end
    return tostring(info.category) .. ":" .. tostring(info.abilityId)
end

local function playReadyOnce(info)
    local key = readyKey(info)
    if not key or W.lastReadySoundKey == key then return end
    W.lastReadySoundKey = key
    local sound = SOUNDS and rawget(SOUNDS, "ABILITY_ULTIMATE_READY")
    if sound and type(PlaySound) == "function" then pcall(PlaySound, sound) end
end

local function ensureBadge(widget)
    if not widget or not WM or not GuiRoot then return nil end
    if widget.epcWorldReadyBadge029640 then return widget.epcWorldReadyBadge029640 end
    local badge = WM:CreateControl(nil, GuiRoot, CT_CONTROL)
    badge:SetDimensions(42, 42)
    badge:SetAnchor(LEFT, widget, RIGHT, 7, 0)
    badge:SetMouseEnabled(false)
    badge:SetHidden(true)
    local bg = WM:CreateControl(nil, badge, CT_BACKDROP)
    bg:SetAnchorFill(badge)
    bg:SetCenterColor(0.02, 0.025, 0.04, 0.94)
    bg:SetEdgeColor(1.00, 0.78, 0.16, 1.00)
    bg:SetEdgeTexture(nil, 4, 4, 4)
    local icon = WM:CreateControl(nil, badge, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, badge, TOPLEFT, 3, 3)
    icon:SetAnchor(BOTTOMRIGHT, badge, BOTTOMRIGHT, -3, -3)
    local ready = WM:CreateControl(nil, badge, CT_LABEL)
    ready:SetAnchor(BOTTOMLEFT, badge, BOTTOMLEFT, -7, 2)
    ready:SetAnchor(BOTTOMRIGHT, badge, BOTTOMRIGHT, 7, 2)
    ready:SetHeight(16)
    ready:SetFont("$(BOLD_FONT)|11|soft-shadow-thick")
    ready:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    ready:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    ready:SetColor(1.00, 0.86, 0.30, 1.00)
    ready:SetText("SWAP")
    if badge.SetDrawLayer and DL_OVERLAY then badge:SetDrawLayer(DL_OVERLAY) end
    if badge.SetDrawTier and DT_HIGH then badge:SetDrawTier(DT_HIGH) end
    if badge.SetDrawLevel then badge:SetDrawLevel(2600) end
    badge.epcIcon = icon
    badge.epcReady = ready
    widget.epcWorldReadyBadge029640 = badge
    return badge
end

local function refreshAbility()
    if not A or not A.widgets or #A.widgets == 0 then return end
    local widget = A.widgets[#A.widgets]
    local badge = ensureBadge(widget)
    if not badge then return end
    local info = readyInactive()
    local show = info ~= nil and EPC.saved and EPC.saved.showAbilityOverlays ~= false
        and A.layoutMode ~= true
        and not (EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed())
    badge:SetHidden(not show)
    if not show then widget.epcWorldReadyKey029640 = nil return end
    if type(widget.GetScale) == "function" and type(badge.SetScale) == "function" then
        badge:SetScale(tonumber(safe(widget.GetScale, 1, widget)) or 1)
    end
    local key = readyKey(info)
    if widget.epcWorldReadyKey029640 ~= key then
        widget.epcWorldReadyKey029640 = key
        badge.epcIcon:SetTexture(info.icon or "")
    end
    playReadyOnce(info)
end

local function refreshDual()
    local D = GetDualActionBar029647()
    if not D or not D.rows or inSpecialHotbar() then return end
    local current = activeCategory()
    local ultOrdinal = #(D.slots or {})
    if ultOrdinal <= 0 then return end
    local a, b = worldUltimates()
    local byCategory = {}
    if a then byCategory[a.category] = a end
    if b then byCategory[b.category] = b end
    local anyReady = false
    for _, row in ipairs(D.rows) do
        local category = row.epcCategory
        local frame = row.slots and row.slots[ultOrdinal]
        local info = byCategory[category]
        local ready = info and info.ready == true
        local inactive = category ~= current
        if ready then anyReady = true end
        if frame then
            if frame.epcReadyGlow029365 and ready then
                frame.epcReadyGlow029365:SetHidden(false)
                frame.epcReadyGlow029365:SetAlpha(inactive and 1.0 or 0.92)
            end
            if frame.epcSwap then
                if ready and inactive then
                    frame.epcSwap:SetText("SWAP")
                    frame.epcSwap:SetHidden(false)
                elseif not (D.smartNeedsSwap029189 == true and D.smartCategory029189 == category) then
                    frame.epcSwap:SetHidden(true)
                end
            end
            if ready and inactive and row.SetAlpha then
                local alpha = math.max(0.10, math.min(1.0,
                    (tonumber(EPC.saved and EPC.saved.dualActionBarInactiveAlpha029189) or 45) / 100))
                row:SetAlpha(math.max(alpha, 0.78))
            end
        end
        if ready and inactive then playReadyOnce(info) end
    end
    if not anyReady then W.lastReadySoundKey = nil end
end

function W:RefreshPresentation029647()
    if swapPresentationBlocked() then return end
    refreshAbility()
    refreshDual()
end

if EVENT_MANAGER then
    local prefix = (EPC.name or "ESOAdventurerSuite") .. "_WorldReadyCache029647"
    local function invalidate() W:Invalidate029647() end
    if rawget(_G, "EVENT_ACTION_SLOT_UPDATED") then
        EPC.Runtime:RegisterEvent("WorldAbilityReadiness","Slot",EVENT_ACTION_SLOT_UPDATED, invalidate)
    end
    if rawget(_G, "EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED") then
        EPC.Runtime:RegisterEvent("WorldAbilityReadiness","Bars",EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, invalidate)
    end
end

SLASH_COMMANDS = SLASH_COMMANDS or {}
SLASH_COMMANDS["/easworldready"] = function()
    local active = activeCategory()
    local a, b = worldUltimates()
    local function describe(info)
        if not info then return "none" end
        return string.format("%s id=%d cost=%d ult=%d ready=%s",
            info.name ~= "" and info.name or "World Ultimate", info.abilityId,
            math.floor(info.cost + 0.5), math.floor(info.current + 0.5),
            info.ready and "yes" or "no")
    end
    local text = "EAS World Ready | active=" .. tostring(active)
        .. " | primary=" .. describe(a) .. " | backup=" .. describe(b)
    if type(d) == "function" then d(text) end
end

-- END ABSORBED: WorldAbilityReadinessFix.lua
