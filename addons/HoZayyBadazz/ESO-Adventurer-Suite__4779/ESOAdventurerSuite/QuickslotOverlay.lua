-- ESO Adventurer Suite
-- Movable quickslot overlay: shows the currently selected item/food/potion.
local EPC = ESOProgressionCoach
EPC.QuickslotOverlay = EPC.QuickslotOverlay or {}
local Q = EPC.QuickslotOverlay
local wm = WINDOW_MANAGER

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c = pcall(fn, ...)
    if not ok then return fallback end
    return a,b,c
end

function Q:InvalidateBinding029199()
    self.bindingText029199 = nil
end

function Q:GetUseBinding029199()
    if self.bindingText029199 == nil then
        if EPC.ControllerSupport and type(EPC.ControllerSupport.GetActionBindingMarkup029761) == "function" then
            self.bindingText029199 = EPC.ControllerSupport:GetActionBindingMarkup029761("ACTION_BUTTON_9", 125)
        else
            self.bindingText029199 = EPC.GetActionBindingMarkup029199 and EPC:GetActionBindingMarkup029199("ACTION_BUTTON_9", 19) or ""
        end
    end
    return self.bindingText029199 or ""
end

function Q:GetPosition()
    local left = tonumber(EPC.saved and EPC.saved.quickslotOverlayLeft) or -1
    local top = tonumber(EPC.saved and EPC.saved.quickslotOverlayTop) or -1
    return left, top
end

function Q:Anchor()
    if not self.frame then return end
    local left, top = self:GetPosition()
    self.frame:ClearAnchors()
    if left >= 0 and top >= 0 then
        self.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        self.frame:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, -170, -135)
    end
end

local CreateImplArch

function Q:Create(...)

    return CreateImplArch(self, ...)

end

CreateImplArch = function(self)
    if self.frame then return self.frame end
    local frame = wm:CreateTopLevelWindow("EAS_QuickslotOverlay")
    frame:SetDimensions(76, 112)
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)
    if frame.SetDrawLayer and DL_OVERLAY then frame:SetDrawLayer(DL_OVERLAY) end
    if frame.SetDrawTier and DT_HIGH then frame:SetDrawTier(DT_HIGH) end
    if frame.SetDrawLevel then frame:SetDrawLevel(1000) end
    if frame.SetTopLevel then frame:SetTopLevel(true) end

    local bg = wm:CreateControl("EAS_QuickslotOverlayBG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0.012,0.015,0.022,0.88)
    bg:SetEdgeColor(0.67,0.51,0.24,0.95)
    bg:SetEdgeTexture(nil,1,1,1)

    local icon = wm:CreateControl("EAS_QuickslotOverlayIcon", frame, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, frame, TOPLEFT, 8, 8)
    icon:SetDimensions(60,60)

    local count = wm:CreateControl("EAS_QuickslotOverlayCount", frame, CT_LABEL)
    count:SetAnchor(BOTTOMRIGHT, frame, TOPLEFT, 68, 70)
    count:SetDimensions(42,20)
    count:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
    count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    count:SetColor(1,1,1,1)

    local name = wm:CreateControl("EAS_QuickslotOverlayName", frame, CT_LABEL)
    name:SetAnchor(TOPLEFT, frame, TOPLEFT, 3, 69)
    name:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -3, 69)
    name:SetDimensions(70,22)
    name:SetFont("ZoFontGameSmall")
    name:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    name:SetColor(0.95,0.82,0.42,1)

    local binding = wm:CreateControl("EAS_QuickslotOverlayBinding029199", frame, CT_LABEL)
    binding:SetAnchor(TOPLEFT, frame, TOPLEFT, 3, 91)
    binding:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -3, 91)
    binding:SetDimensions(70,18)
    binding:SetFont("$(BOLD_FONT)|15|soft-shadow-thick")
    binding:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    binding:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    binding:SetColor(0.90,0.92,0.97,1)

    local hint = wm:CreateControl("EAS_QuickslotOverlayHint", frame, CT_LABEL)
    hint:SetAnchor(TOP, frame, BOTTOM, 0, 2)
    hint:SetDimensions(100,18)
    hint:SetFont("ZoFontGameSmall")
    hint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    hint:SetColor(0.95,0.82,0.42,1)
    hint:SetText("DRAG")
    hint:SetHidden(true)

    frame:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            EPC.saved.quickslotOverlayLeft = control:GetLeft()
            EPC.saved.quickslotOverlayTop = control:GetTop()
        end
    end)
    self.frame,self.icon,self.count,self.name,self.binding,self.hint = frame,icon,count,name,binding,hint
    self:Anchor()
    return frame
end

-- ESO's GetSlot* APIs need the quickslot hotbar category.  Without it,
-- the same numeric slot can be read from the active ability bar and display
-- the wrong icon/name/count.
function Q:GetSelectedQuickslotData()
    local slot = tonumber(safe(GetCurrentQuickslot, 1)) or 1
    local category = HOTBAR_CATEGORY_QUICKSLOT_WHEEL

    local texture, itemName, count, used
    if category ~= nil then
        texture = safe(GetSlotTexture, "", slot, category)
        itemName = safe(GetSlotName, "", slot, category)
        count = tonumber(safe(GetSlotItemCount, 0, slot, category)) or 0
        used = safe(IsSlotUsed, false, slot, category) == true
    else
        -- Compatibility fallback for very old API versions.
        texture = safe(GetSlotTexture, "", slot)
        itemName = safe(GetSlotName, "", slot)
        count = tonumber(safe(GetSlotItemCount, 0, slot)) or 0
        used = safe(IsSlotUsed, false, slot) == true
    end

    -- Some ESO versions briefly report IsSlotUsed=false for the selected
    -- quickslot even though the icon/name are valid. Treat real slot content
    -- as authoritative so the Quick Potion / Quickslot overlay does not vanish.
    texture = texture or ""
    itemName = itemName or ""
    if texture == "" and HOTBAR_CATEGORY_QUICKSLOT_WHEEL ~= nil then
        local fallbackTexture = safe(GetSlotTexture, "", slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        local fallbackName = safe(GetSlotName, "", slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        local fallbackCount = tonumber(safe(GetSlotItemCount, 0, slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)) or 0
        if fallbackTexture ~= "" or fallbackName ~= "" then
            texture, itemName, count = fallbackTexture or "", fallbackName or "", fallbackCount
        end
    end
    used = used == true or texture ~= "" or itemName ~= ""
    return slot, texture, itemName, count, used
end

function Q:HasAttackableReticleTarget()
    if safe(DoesUnitExist, false, "reticleover") ~= true then return false end
    if safe(IsUnitAttackable, false, "reticleover") ~= true then return false end
    if type(IsUnitDead) == "function" and safe(IsUnitDead, false, "reticleover") == true then return false end
    return true
end

-- Quickslot visibility has a special "before combat" meaning.  It should not
-- be visible during normal roaming.  An attackable reticle target is treated
-- as the preparation window immediately before combat.  Once combat starts it
-- stays visible, and when combat ends it is forced hidden again until the
-- player moves the reticle off the old target and lines up another enemy.
function Q:VisibilityAllows()
    local mode = EPC.saved and EPC.saved.quickslotOverlayVisibility or "BEFORE_AND_DURING"
    if mode == "BEFORE_COMBAT" then
        mode = "BEFORE_AND_DURING"
        if EPC.saved then EPC.saved.quickslotOverlayVisibility = mode end
    elseif mode == "OUT_OF_COMBAT" then
        mode = "BEFORE_ONLY"
        if EPC.saved then EPC.saved.quickslotOverlayVisibility = mode end
    end

    -- ALWAYS is a true persistent gameplay mode. The master checkbox and
    -- gameplay-HUD suppression are still respected by Refresh().
    if mode == "ALWAYS" then
        return true
    end

    local inCombat = safe(IsUnitInCombat, false, "player") == true
    local attackable = self:HasAttackableReticleTarget()

    -- Detect combat ending even if the event was missed.
    if self.lastCombatState == true and not inCombat then
        self.postCombatNeedsTargetClear = true
    end
    self.lastCombatState = inCombat

    if mode == "COMBAT" then
        return inCombat
    elseif mode == "BEFORE_ONLY" then
        return (not inCombat) and attackable
    elseif mode == "BEFORE_AND_DURING" then
        if inCombat then return true end

        -- After combat, do not instantly re-open just because the defeated or
        -- disengaged target is still under the reticle.  Re-arm only after the
        -- player looks away; the next attackable target will show the overlay.
        if self.postCombatNeedsTargetClear then
            if not attackable then
                self.postCombatNeedsTargetClear = false
            end
            return false
        end
        return attackable
    end

    return false
end

local RefreshImplArch

function Q:Refresh(...)

    return RefreshImplArch(self, ...)

end

RefreshImplArch = function(self)
    self:Create()
    local show = EPC.saved and EPC.saved.showQuickslotOverlay ~= false
    if not self.layoutMode then
        show = show and self:VisibilityAllows()
    end
    if not self.layoutMode and EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then
        show = false
    end

    local slot, texture, itemName, count, used = self:GetSelectedQuickslotData()
    show = show and (used or itemName ~= "" or texture ~= "") and texture ~= ""
    self.frame:SetHidden(not show)
    if not show then return end

    self.icon:SetTexture(texture)
    self.name:SetText(itemName ~= "" and itemName or ("Quickslot " .. tostring(slot)))
    self.count:SetText(count > 0 and tostring(count) or "")
    if self.binding then
        local bindingText = self:GetUseBinding029199()
        self.binding:SetText(bindingText)
        local usesMarkup = bindingText:find("|k", 1, true) ~= nil
            or bindingText:find("|u", 1, true) ~= nil
            or bindingText:find("|t", 1, true) ~= nil
        self.binding:SetFont(usesMarkup and "$(BOLD_FONT)|15|soft-shadow-thick" or "ZoFontGameSmall")
    end
end

function Q:SetLayoutMode(active)
    self.layoutMode = active == true
    self:Create()
    self.frame:SetMouseEnabled(self.layoutMode)
    self.frame:SetMovable(self.layoutMode)
    self.hint:SetHidden(not self.layoutMode)
    if self.layoutMode then
        -- Always expose the selected quickslot during editing, even if empty.
        self.frame:SetHidden(false)
        local slot, texture, itemName = self:GetSelectedQuickslotData()
        self.icon:SetTexture(texture or "")
        self.name:SetText(itemName ~= "" and itemName or ("Quickslot " .. tostring(slot)))
    end
    self:Refresh()
    if self.layoutMode then self.frame:SetHidden(false) end
end

function Q:ResetPosition()
    if not EPC.saved then return end
    EPC.saved.quickslotOverlayLeft = -1
    EPC.saved.quickslotOverlayTop = -1
    self:Anchor()
end

local InitializeImplArch

function Q:Initialize(...)

    return InitializeImplArch(self, ...)

end

InitializeImplArch = function(self)
    self.layoutMode = false
    self.lastCombatState = safe(IsUnitInCombat, false, "player") == true
    self.postCombatNeedsTargetClear = false
    self:Create()
    local prefix = EPC.name .. "_QuickslotOverlay"
    if EVENT_PLAYER_ACTIVATED then
        EPC.Runtime:RegisterEvent("QuickslotOverlay","Activated",EVENT_PLAYER_ACTIVATED, function() self:Refresh() end)
    end
    if EVENT_PLAYER_COMBAT_STATE then
        EPC.Runtime:RegisterEvent("QuickslotOverlay","Combat",EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
            if inCombat == false and self.lastCombatState == true then
                self.postCombatNeedsTargetClear = true
            end
            self.lastCombatState = inCombat == true
            self:Refresh()
        end)
    end
    if EVENT_RETICLE_TARGET_CHANGED then
        EPC.Runtime:RegisterEvent("QuickslotOverlay","ReticleTarget",EVENT_RETICLE_TARGET_CHANGED, function() self:Refresh() end)
    end
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        EPC.Runtime:RegisterEvent("QuickslotOverlay","Inventory",EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function() self:Refresh() end)
    end
    if EVENT_ACTIVE_QUICKSLOT_CHANGED then
        EPC.Runtime:RegisterEvent("QuickslotOverlay","ActiveQuickslot",EVENT_ACTIVE_QUICKSLOT_CHANGED, function() self:Refresh() end)
    end
    if EVENT_KEYBINDINGS_LOADED then
        EPC.Runtime:RegisterEvent("QuickslotOverlay","BindingsLoaded",EVENT_KEYBINDINGS_LOADED, function() self:InvalidateBinding029199() self:Refresh() end)
    end
    if EVENT_KEYBINDING_SET then
        EPC.Runtime:RegisterEvent("QuickslotOverlay","BindingSet",EVENT_KEYBINDING_SET, function() self:InvalidateBinding029199() self:Refresh() end)
    end
    if EVENT_KEYBINDING_CLEARED then
        EPC.Runtime:RegisterEvent("QuickslotOverlay","BindingCleared",EVENT_KEYBINDING_CLEARED, function() self:InvalidateBinding029199() self:Refresh() end)
    end
    if EVENT_HOTBAR_SLOT_UPDATED then
        EPC.Runtime:RegisterEvent("QuickslotOverlay","HotbarSlot",EVENT_HOTBAR_SLOT_UPDATED, function() self:Refresh() end)
    end
    EPC.Runtime:RegisterUpdate("QuickslotOverlay","Tick",650, function()
        if self.layoutMode == true or (self.frame and not self.frame:IsHidden()) then self:Refresh() end
    end)
    self:Refresh()
end

-- v0.29.380 - hide Quickslot overlay on the scene transition frame rather than
-- waiting for its 650ms polling refresh.
local EAS_Q_InitializeBase029380 = InitializeImplArch
local function EAS_Q_RegisterSceneCallbacks029380(self)
    if self.sceneVisibilityHooks029380 or not SCENE_MANAGER or type(SCENE_MANAGER.GetScene) ~= "function" then return end
    self.sceneVisibilityHooks029380 = true
    local names = {
        "gameMenuInGame", "gameMenu", "inventory", "character", "skills", "championPerks",
        "journal", "collectionsBook", "groupMenu", "groupList", "groupFinderKeyboard",
        "contacts", "friendsList", "friendsListKeyboard", "guildHome", "guildRoster",
        "mailInbox", "mailSend", "bank", "guildBank", "store", "tradingHouse",
        "crafting", "smithing", "alchemy", "enchanting", "provisioner", "settings",
        "worldMap", "achievements", "loreLibrary", "housingEditor",
    }
    for i = 1, #names do
        local ok, scene = pcall(SCENE_MANAGER.GetScene, SCENE_MANAGER, names[i])
        if ok and scene and type(scene.RegisterCallback) == "function" then
            scene:RegisterCallback("StateChange", function(_, newState)
                if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                    if self.frame and self.layoutMode ~= true then self.frame:SetHidden(true) end
                elseif newState == SCENE_HIDDEN then
                    if type(zo_callLater) == "function" then zo_callLater(function() if EPC and EPC.QuickslotOverlay then EPC.QuickslotOverlay:Refresh() end end, 0)
                    else self:Refresh() end
                end
            end)
        end
    end
end
InitializeImplArch = function(self)
    local result = EAS_Q_InitializeBase029380(self)
    EAS_Q_RegisterSceneCallbacks029380(self)
    return result
end


-- BEGIN ABSORBED: QuickslotCooldownFix.lua
-- ESO Adventurer Suite
-- v0.29.667 - Quickslot potion cooldown presentation.
-- Uses ESO's native GetSlotCooldownInfo() and the existing Quickslot refresh pulse.

local EPC = ESOProgressionCoach
local Q = EPC and EPC.QuickslotOverlay
local wm = WINDOW_MANAGER
if not EPC or not Q or not wm then return end
if Q._easCooldownFix029667 then return end
Q._easCooldownFix029667 = true

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d
end

local function formatCooldown(ms)
    ms = tonumber(ms) or 0
    if ms <= 0 then return "" end
    local seconds = ms / 1000
    if seconds >= 10 then return tostring(math.ceil(seconds)) end
    return string.format("%.1f", seconds)
end

local baseCreate = CreateImplArch
CreateImplArch = function(self, ...)
    local frame = baseCreate(self, ...)
    if not frame then return frame end
    if not self.cooldownShade029667 then
        local shade = wm:CreateControl("EAS_QuickslotCooldownShade029667", frame, CT_BACKDROP)
        shade:SetAnchor(TOPLEFT, self.icon, TOPLEFT, 0, 0)
        shade:SetAnchor(BOTTOMRIGHT, self.icon, BOTTOMRIGHT, 0, 0)
        shade:SetCenterColor(0, 0, 0, 0.48)
        shade:SetEdgeColor(0, 0, 0, 0)
        shade:SetHidden(true)

        local label = wm:CreateControl("EAS_QuickslotCooldownLabel029667", frame, CT_LABEL)
        label:SetAnchor(TOPLEFT, self.icon, TOPLEFT, 0, 0)
        label:SetAnchor(BOTTOMRIGHT, self.icon, BOTTOMRIGHT, 0, 0)
        label:SetFont("$(BOLD_FONT)|25|soft-shadow-thick")
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetColor(1.00, 0.82, 0.24, 1.00)
        label:SetText("")
        label:SetHidden(true)

        self.cooldownShade029667 = shade
        self.cooldownLabel029667 = label
    end
    return frame
end

local RefreshCooldownPresentation029667ImplArch

function Q:RefreshCooldownPresentation029667(...)

    return RefreshCooldownPresentation029667ImplArch(self, ...)

end

RefreshCooldownPresentation029667ImplArch = function(self, slot)
    self:Create()
    if not self.icon then return end

    local category = rawget(_G, "HOTBAR_CATEGORY_QUICKSLOT_WHEEL")
    local remaining, duration = 0, 0
    if type(GetSlotCooldownInfo) == "function" then
        remaining, duration = safe(GetSlotCooldownInfo, 0, slot, category)
        remaining = tonumber(remaining) or 0
        duration = tonumber(duration) or 0
    end

    local cooling = remaining > 0 and duration > 0
    if type(self.icon.SetDesaturation) == "function" then
        self.icon:SetDesaturation(cooling and 1 or 0)
    end
    if type(self.icon.SetColor) == "function" then
        if cooling then self.icon:SetColor(0.62, 0.62, 0.62, 1)
        else self.icon:SetColor(1, 1, 1, 1) end
    end

    if self.cooldownShade029667 then self.cooldownShade029667:SetHidden(not cooling) end
    if self.cooldownLabel029667 then
        self.cooldownLabel029667:SetText(cooling and formatCooldown(remaining) or "")
        self.cooldownLabel029667:SetHidden(not cooling)
    end
    self.quickslotCooldownActive029667 = cooling
    self.quickslotCooldownRemaining029667 = remaining
end

local baseRefresh = RefreshImplArch
RefreshImplArch = function(self, ...)
    local result = baseRefresh(self, ...)
    local slot = tonumber(safe(GetCurrentQuickslot, 1)) or 1
    if self.frame and not self.frame:IsHidden() then
        self:RefreshCooldownPresentation029667(slot)
    else
        if self.icon and type(self.icon.SetDesaturation) == "function" then self.icon:SetDesaturation(0) end
        if self.icon and type(self.icon.SetColor) == "function" then self.icon:SetColor(1, 1, 1, 1) end
        if self.cooldownShade029667 then self.cooldownShade029667:SetHidden(true) end
        if self.cooldownLabel029667 then self.cooldownLabel029667:SetHidden(true) end
    end
    return result
end

-- Refresh immediately when ESO reports quickslot state/cooldown changes. The
-- existing 650ms visible-overlay pulse remains the fallback countdown owner.
local prefix = (EPC.name or "ESOAdventurerSuite") .. "_QuickslotCooldown029667"
for _, eventName in ipairs({ "EVENT_ACTION_SLOT_STATE_UPDATED", "EVENT_ACTION_SLOT_UPDATED", "EVENT_HOTBAR_SLOT_UPDATED" }) do
    local eventId = rawget(_G, eventName)
    if eventId and EVENT_MANAGER then
        EPC.Runtime:RegisterEvent("QuickslotCooldown",eventName,eventId, function()
            if EPC and EPC.QuickslotOverlay then EPC.QuickslotOverlay:Refresh() end
        end)
    end
end

-- END ABSORBED: QuickslotCooldownFix.lua


-- BEGIN ABSORBED: QuickslotOverlayPolishFix.lua
-- ESO Adventurer Suite
-- v0.29.697 development: resizable quickslot overlay + responsive cooldown presentation.
-- Keeps normal gameplay event-driven. A short 100ms pulse exists only while a visible
-- quickslot is actively cooling down, then unregisters itself immediately.

local EPC = ESOProgressionCoach
local Q = EPC and EPC.QuickslotOverlay
local WM = WINDOW_MANAGER
if not EPC or not Q or not WM or not EVENT_MANAGER then return end
if Q._easQuickslotPolish029697 then return end
Q._easQuickslotPolish029697 = true

local EM = EVENT_MANAGER
local NAME = (EPC.name or "ESOAdventurerSuite") .. "_QuickslotPolish029697"
local OLD_TICK = (EPC.name or "ESOAdventurerSuite") .. "_QuickslotOverlay_Tick"

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c
end

function Q:GetScale029697()
    local saved = EPC.saved and tonumber(EPC.saved.quickslotOverlayScale029697)
    if not saved then saved = 1.0 end
    return clamp(saved, 0.60, 1.80)
end

function Q:SetScale029697(value)
    value = clamp(value, 0.60, 1.80)
    if EPC.saved then EPC.saved.quickslotOverlayScale029697 = value end
    self:Create()
    if self.frame and type(self.frame.SetScale) == "function" then
        self.frame:SetScale(value)
    end
    self:Anchor()
    self:Refresh()
end

local baseCreate = CreateImplArch
CreateImplArch = function(self, ...)
    local frame = baseCreate(self, ...)
    if not frame then return frame end

    if type(frame.SetScale) == "function" then
        frame:SetScale(self:GetScale029697())
    end

    if not self.cooldownProgressBG029697 and self.icon then
        local bg = WM:CreateControl("EAS_QuickslotCooldownProgressBG029697", frame, CT_BACKDROP)
        bg:SetAnchor(BOTTOMLEFT, self.icon, BOTTOMLEFT, 2, -1)
        bg:SetDimensions(56, 5)
        bg:SetCenterColor(0.02, 0.02, 0.02, 0.88)
        bg:SetEdgeColor(0, 0, 0, 0)
        bg:SetHidden(true)

        local fill = WM:CreateControl("EAS_QuickslotCooldownProgressFill029697", bg, CT_BACKDROP)
        fill:SetAnchor(LEFT, bg, LEFT, 0, 0)
        fill:SetDimensions(1, 5)
        fill:SetCenterColor(1.00, 0.72, 0.12, 0.96)
        fill:SetEdgeColor(0, 0, 0, 0)
        fill:SetHidden(true)

        self.cooldownProgressBG029697 = bg
        self.cooldownProgressFill029697 = fill
    end

    return frame
end

function Q:StopCooldownPulse029697()
    EM:UnregisterForUpdate(NAME .. "_CooldownPulse")
    self.cooldownPulse029697 = false
end

function Q:StartCooldownPulse029697()
    if self.cooldownPulse029697 then return end
    self.cooldownPulse029697 = true
    EM:RegisterForUpdate(NAME .. "_CooldownPulse", 100, function()
        if not Q or not Q.frame or Q.frame:IsHidden() then
            Q:StopCooldownPulse029697()
            return
        end
        local slot = tonumber(safe(GetCurrentQuickslot, 1)) or 1
        Q:RefreshCooldownPresentation029667(slot)
        if not Q.quickslotCooldownActive029667 then
            Q:StopCooldownPulse029697()
        end
    end)
end

local baseCooldown = RefreshCooldownPresentation029667ImplArch
if type(baseCooldown) == "function" then
    RefreshCooldownPresentation029667ImplArch = function(self, slot, ...)
        local result = baseCooldown(self, slot, ...)
        local category = rawget(_G, "HOTBAR_CATEGORY_QUICKSLOT_WHEEL")
        local remaining, duration = 0, 0
        if type(GetSlotCooldownInfo) == "function" then
            remaining, duration = safe(GetSlotCooldownInfo, 0, slot, category)
            remaining = tonumber(remaining) or 0
            duration = tonumber(duration) or 0
        end

        local cooling = remaining > 0 and duration > 0
        if self.cooldownProgressBG029697 then
            self.cooldownProgressBG029697:SetHidden(not cooling)
        end
        if self.cooldownProgressFill029697 then
            if cooling then
                local elapsed = 1 - clamp(remaining / math.max(duration, 1), 0, 1)
                self.cooldownProgressFill029697:SetDimensions(math.max(1, math.floor(56 * elapsed + 0.5)), 5)
                self.cooldownProgressFill029697:SetHidden(false)
            else
                self.cooldownProgressFill029697:SetHidden(true)
            end
        end

        if cooling and self.frame and not self.frame:IsHidden() then
            self:StartCooldownPulse029697()
        elseif not cooling then
            self:StopCooldownPulse029697()
        end
        return result
    end
end

local baseRefresh = RefreshImplArch
RefreshImplArch = function(self, ...)
    local result = baseRefresh(self, ...)
    if self.frame and type(self.frame.SetScale) == "function" then
        self.frame:SetScale(self:GetScale029697())
    end
    if self.frame and self.frame:IsHidden() then
        self:StopCooldownPulse029697()
        if self.cooldownProgressBG029697 then self.cooldownProgressBG029697:SetHidden(true) end
        if self.cooldownProgressFill029697 then self.cooldownProgressFill029697:SetHidden(true) end
    end
    return result
end

-- The original overlay used a permanent 650ms refresh pulse whenever visible.
-- Replace it after initialization. All non-cooldown state is already covered by
-- ESO events; cooldown countdown gets the short-lived 100ms pulse above.
local baseInitialize = InitializeImplArch
InitializeImplArch = function(self, ...)
    local result = baseInitialize(self, ...)
    EM:UnregisterForUpdate(OLD_TICK)
    EM:UnregisterForUpdate((EPC.name or "ESOAdventurerSuite") .. "_QuickslotOverlay_Tick")
    self:Refresh()
    return result
end

EPC.quickslotOverlayPolish029697 = true

-- END ABSORBED: QuickslotOverlayPolishFix.lua


-- BEGIN ABSORBED: QuickslotOverlaySettingsFix.lua
-- ESO Adventurer Suite
-- v0.29.697 development: inject Quickslot Overlay size control into existing Suite settings.

local EPC = ESOProgressionCoach
if not EPC or not EPC.Settings then return end
local S = EPC.Settings
if S._quickslotSettings029697 then return end
S._quickslotSettings029697 = true

local baseInitialize = S.Initialize

local function injectIntoControls(options)
    if type(options) ~= "table" then return false end
    for i = 1, #options do
        local option = options[i]
        if type(option) == "table" then
            if option.type == "header" and option.name == "Quickslot Overlay" then
                -- Do not duplicate if another wrapper or future core version already added it.
                local nextOption = options[i + 1]
                if type(nextOption) == "table" and nextOption.reference == "EAS_QUICKSLOT_SCALE_029697" then return true end
                table.insert(options, i + 1, {
                    type = "slider",
                    name = "Quickslot overlay size",
                    tooltip = "Resizes the entire Quickslot Overlay, including icon, item name, binding, cooldown timer, and cooldown progress indicator.",
                    min = 60,
                    max = 180,
                    step = 5,
                    getFunc = function()
                        return math.floor(((tonumber(EPC.saved and EPC.saved.quickslotOverlayScale029697) or 1.0) * 100) + 0.5)
                    end,
                    setFunc = function(v)
                        local scale = math.max(0.60, math.min(1.80, (tonumber(v) or 100) / 100))
                        if EPC.saved then EPC.saved.quickslotOverlayScale029697 = scale end
                        if EPC.QuickslotOverlay and EPC.QuickslotOverlay.SetScale029697 then
                            EPC.QuickslotOverlay:SetScale029697(scale)
                        end
                    end,
                    default = 100,
                    reference = "EAS_QUICKSLOT_SCALE_029697",
                })
                return true
            end
            if type(option.controls) == "table" and injectIntoControls(option.controls) then return true end
        end
    end
    return false
end

function S:Initialize(...)
    local LAM = LibAddonMenu2
    if not LAM or type(LAM.RegisterOptionControls) ~= "function" then
        return baseInitialize(self, ...)
    end

    local previous = LAM.RegisterOptionControls
    LAM.RegisterOptionControls = function(lam, panelName, options, ...)
        if panelName == "ESOProgressionCoachSettings" and type(options) == "table" then
            injectIntoControls(options)
        end
        return previous(lam, panelName, options, ...)
    end

    local ok, result = pcall(baseInitialize, self, ...)
    LAM.RegisterOptionControls = previous
    if not ok then
        if EPC and type(EPC.Print) == "function" then EPC:Print("Quickslot settings integration failed: " .. tostring(result)) end
        return nil
    end
    return result
end

EPC.quickslotOverlaySettings029697 = true

-- END ABSORBED: QuickslotOverlaySettingsFix.lua
