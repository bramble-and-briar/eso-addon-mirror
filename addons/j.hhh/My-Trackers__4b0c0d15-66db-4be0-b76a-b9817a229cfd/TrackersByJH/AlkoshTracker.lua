AlkoshTracker = AlkoshTracker or {}
local AT = AlkoshTracker

AT.name = "AlkoshTracker"
AT.version = "1.7.0-console.1"
AT.setId = 232
AT.abilityId = 75753 -- Line-Breaker / Roar of Alkosh proc used by ExoYs ProcSetTimer 2.14.0
AT.procEnd = 0
AT.hasFivePieces = false

local equipSlots = {
    EQUIP_SLOT_HEAD, EQUIP_SLOT_NECK, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND, EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2, EQUIP_SLOT_HAND,
    EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF,
}

local twoHanders = {
    [WEAPONTYPE_FIRE_STAFF] = true, [WEAPONTYPE_FROST_STAFF] = true,
    [WEAPONTYPE_LIGHTNING_STAFF] = true, [WEAPONTYPE_HEALING_STAFF] = true,
    [WEAPONTYPE_BOW] = true, [WEAPONTYPE_TWO_HANDED_AXE] = true,
    [WEAPONTYPE_TWO_HANDED_HAMMER] = true, [WEAPONTYPE_TWO_HANDED_SWORD] = true,
}

local defaults = {
    left = 600,
    top = 600,
    iconSize = 72,
    onlyWhenFivePieces = true,
    onlyInCombat = false,
    locked = true, -- legacy value; movement is gamepad move-mode only
    gamepadMoveSpeed = 420,
    showDecimal = true,
    timerOffsetY = 0,
}

local function GetSetId(slot)
    local link = GetItemLink(BAG_WORN, slot)
    if not link or link == "" then return 0 end
    local _, _, _, _, _, setId = GetItemLinkSetInfo(link)
    return setId or 0
end

function AT:CountAlkoshPiecesOnBar()
    local count = 0
    -- Armor + jewelry always count.
    local fixed = {
        EQUIP_SLOT_HEAD, EQUIP_SLOT_NECK, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS,
        EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET,
        EQUIP_SLOT_RING1, EQUIP_SLOT_RING2, EQUIP_SLOT_HAND,
    }
    for _, slot in ipairs(fixed) do
        if GetSetId(slot) == self.setId then count = count + 1 end
    end

    -- Count only the currently active weapon bar. A two-hander counts as two set pieces.
    local mainSlot, offSlot
    if GetActiveHotbarCategory() == HOTBAR_CATEGORY_BACKUP then
        mainSlot, offSlot = EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF
    else
        mainSlot, offSlot = EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND
    end

    if GetSetId(mainSlot) == self.setId then
        local wt = GetItemWeaponType(BAG_WORN, mainSlot)
        count = count + (twoHanders[wt] and 2 or 1)
    end
    if GetSetId(offSlot) == self.setId then count = count + 1 end
    return count
end

function AT:RefreshEquipment()
    self.hasFivePieces = self:CountAlkoshPiecesOnBar() >= 5
    self:RefreshVisibility()
end

function AT:IsHudVisible()
    if not SCENE_MANAGER then return true end
    local hud = SCENE_MANAGER:GetScene("hud")
    if not hud then return true end
    local state = hud:GetState()
    return state == SCENE_SHOWING or state == SCENE_SHOWN
end

function AT:RefreshVisibility()
    if not self.control then return end
    if self.isGamepadMoveModeActive then self.control:SetHidden(false); return end
    local wrongEquipment = self.sv.onlyWhenFivePieces and not self.hasFivePieces
    local inMenu = not self:IsHudVisible()
    local outOfCombat = self.sv.onlyInCombat and not IsUnitInCombat("player")
    self.control:SetHidden(wrongEquipment or inMenu or outOfCombat)
end

function AT:CreateUI()
    local wm = WINDOW_MANAGER
    local win = wm:CreateTopLevelWindow("AlkoshTrackerWindow")
    win:SetDimensions(self.sv.iconSize, self.sv.iconSize)
    win:SetClampedToScreen(true)
    win:SetMovable(false)
    win:SetMouseEnabled(false)
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.sv.left, self.sv.top)

    local icon = wm:CreateControl("AlkoshTrackerIcon", win, CT_TEXTURE)
    icon:SetAnchorFill(win)
    icon:SetTexture(GetAbilityIcon(self.abilityId))

    local label = wm:CreateControl("AlkoshTrackerTimer", win, CT_LABEL)
    label:SetAnchor(CENTER, win, CENTER, 0, self.sv.timerOffsetY)
    label:SetDimensions(self.sv.iconSize, self.sv.iconSize)
    label:SetFont("$(BOLD_FONT)|" .. math.floor(self.sv.iconSize * 0.48) .. "|soft-shadow-thick")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(0, 1, 0, 1)

    local inactiveX = wm:CreateControl("AlkoshTrackerInactiveX", win, CT_LABEL)
    inactiveX:SetAnchor(CENTER, win, CENTER, 0, self.sv.timerOffsetY)
    inactiveX:SetDimensions(self.sv.iconSize, self.sv.iconSize)
    inactiveX:SetFont("$(BOLD_FONT)|" .. math.max(12, math.floor(self.sv.iconSize * 0.25)) .. "|soft-shadow-thick")
    inactiveX:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    inactiveX:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    inactiveX:SetColor(1, 1, 1, 1)
    inactiveX:SetText("")

    self.control, self.icon, self.label, self.inactiveX = win, icon, label, inactiveX
    self:UpdateUI()
end

function AT:ApplySettings()
    if not self.control then return end
    self.control:SetDimensions(self.sv.iconSize, self.sv.iconSize)
    self.control:SetMovable(false)
    self.control:SetMouseEnabled(false)
    self.label:ClearAnchors()
    self.label:SetAnchor(CENTER, self.control, CENTER, 0, self.sv.timerOffsetY)
    self.label:SetDimensions(self.sv.iconSize, self.sv.iconSize)
    self.label:SetFont("$(BOLD_FONT)|" .. math.floor(self.sv.iconSize * 0.48) .. "|soft-shadow-thick")
    self.inactiveX:ClearAnchors()
    self.inactiveX:SetAnchor(CENTER, self.control, CENTER, 0, self.sv.timerOffsetY)
    self.inactiveX:SetDimensions(self.sv.iconSize, self.sv.iconSize)
    self.inactiveX:SetFont("$(BOLD_FONT)|" .. math.max(12, math.floor(self.sv.iconSize * 0.25)) .. "|soft-shadow-thick")
    self:RefreshEquipment()
    self:UpdateUI()
end

function AT:UpdateUI()
    if not self.icon then return end
    if self.isGamepadMoveModeActive then
        self.control:SetHidden(false)
        self.label:SetText("MOVE")
        self.inactiveX:SetHidden(true)
        return
    end
    local remaining = math.max(0, self.procEnd - GetGameTimeMilliseconds())
    self.icon:SetAlpha(1)

    if remaining > 0 then
        self.inactiveX:SetHidden(true)
        local seconds = remaining / 1000
        -- Smooth color transition: 10s green -> 5s orange -> 3s red.
        local r, g, b = 0, 1, 0
        if seconds <= 3 then
            r, g, b = 1, 0, 0
        elseif seconds <= 5 then
            -- Interpolate from red at 3s to orange at 5s.
            local t = (seconds - 3) / 2
            r = 1
            g = 0.55 * t
            b = 0
        elseif seconds < 10 then
            -- Interpolate from orange at 5s to green at 10s.
            local t = (seconds - 5) / 5
            r = 1 - t
            g = 0.55 + (0.45 * t)
            b = 0
        end
        self.label:SetColor(r, g, b, 1)

        if remaining < 10000 and self.sv.showDecimal then
            self.label:SetText(string.format("%.1f", seconds))
        else
            self.label:SetText(tostring(math.ceil(seconds)))
        end
    else
        self.procEnd = 0
        self.label:SetText("")
        self.inactiveX:SetHidden(false)
    end
end

function AT.OnCombatEvent(_, result, _, _, _, _, sourceName, sourceType, _, _, _, _, _, _, _, _, abilityId)
    if abilityId ~= AT.abilityId then return end
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    -- The proc event can arrive in several successful result forms; refresh the timer on any matching player event.
    local duration = GetAbilityDuration(AT.abilityId)
    if duration and duration > 0 then
        AT.procEnd = GetGameTimeMilliseconds() + duration
        AT:UpdateUI()
    end
end

function AT:Initialize()
    self.sv = ZO_SavedVars:NewAccountWide("AlkoshTrackerSV", 1, nil, defaults)
    self:CreateUI()
    if self.CreateMenu then self:CreateMenu() end

    EVENT_MANAGER:RegisterForEvent(self.name .. "Combat", EVENT_COMBAT_EVENT, self.OnCombatEvent)
    EVENT_MANAGER:AddFilterForEvent(self.name .. "Combat", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, self.abilityId)
    EVENT_MANAGER:AddFilterForEvent(self.name .. "Combat", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EVENT_MANAGER:RegisterForEvent(self.name .. "Equip", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bagId)
        if bagId == BAG_WORN then zo_callLater(function() self:RefreshEquipment() end, 100) end
    end)
    EVENT_MANAGER:RegisterForEvent(self.name .. "WeaponPair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function()
        zo_callLater(function() self:RefreshEquipment() end, 100)
    end)
    EVENT_MANAGER:RegisterForEvent(self.name .. "CombatState", EVENT_PLAYER_COMBAT_STATE, function()
        self:RefreshVisibility()
    end)
    EVENT_MANAGER:RegisterForEvent(self.name .. "Activated", EVENT_PLAYER_ACTIVATED, function()
        self.procEnd = 0
        zo_callLater(function() self:RefreshEquipment(); self:UpdateUI() end, 300)
    end)
    EVENT_MANAGER:RegisterForUpdate(self.name .. "Update", 100, function() self:UpdateUI() end)

    -- Keep the tracker completely hidden while any menu/scene replaces the normal HUD.
    local hudScene = SCENE_MANAGER and SCENE_MANAGER:GetScene("hud")
    if hudScene then
        hudScene:RegisterCallback("StateChange", function()
            self:RefreshVisibility()
        end)
    end
    local hudUiScene = SCENE_MANAGER and SCENE_MANAGER:GetScene("hudui")
    if hudUiScene then
        hudUiScene:RegisterCallback("StateChange", function()
            self:RefreshVisibility()
        end)
    end

    self:RefreshEquipment()
end


function AT:CreateMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local options = {
        {
            type = "description",
            text = "Positioning: use /atmove or the Move Mode button, move with the left stick, then toggle it again to save.",
        },
        {
            type = "checkbox",
            name = "Only show when 5x Alkosh is active",
            tooltip = "When enabled, the icon is only shown when at least 5 Alkosh set pieces count on the currently active weapon bar. When disabled, the icon remains visible.",
            getFunc = function() return self.sv.onlyWhenFivePieces end,
            setFunc = function(v) self.sv.onlyWhenFivePieces = v; self:RefreshEquipment() end,
            default = true,
        },
        {
            type = "checkbox",
            name = "Only show in combat",
            tooltip = "When enabled, the Alkosh tracker is hidden outside combat. Other display options, such as the 5x Alkosh check, still apply during combat.",
            getFunc = function() return self.sv.onlyInCombat end,
            setFunc = function(v) self.sv.onlyInCombat = v; self:RefreshVisibility() end,
            default = false,
        },
        {
            type = "slider",
            name = "Icon size",
            min = 32, max = 160, step = 2,
            getFunc = function() return self.sv.iconSize end,
            setFunc = function(v) self.sv.iconSize = v; self:ApplySettings() end,
            default = 72,
        },
        {
            type = "slider",
            name = "Timer Y-axis",
            tooltip = "Moves the countdown and the Synergy text vertically together. Negative values move them up, positive values move them down.",
            min = -100, max = 100, step = 1,
            getFunc = function() return self.sv.timerOffsetY end,
            setFunc = function(v) self.sv.timerOffsetY = v; self:ApplySettings() end,
            default = 0,
        },
        {
            type = "checkbox",
            name = "Show decimal below 10 seconds",
            getFunc = function() return self.sv.showDecimal end,
            setFunc = function(v) self.sv.showDecimal = v end,
            default = true,
        },
        {
            type = "header",
            name = "Gamepad positioning",
        },
        {
            type = "slider",
            name = "Gamepad move speed",
            min = 100, max = 1000, step = 25,
            getFunc = function() return self.sv.gamepadMoveSpeed or 420 end,
            setFunc = function(v) self.sv.gamepadMoveSpeed = v end,
            default = 420,
        },
        {
            type = "button",
            name = "Toggle move mode",
            func = function() if AT.ToggleGamepadMoveMode then AT.ToggleGamepadMoveMode() end end,
        },
        {
            type = "button",
            name = "Reset position",
            func = function()
                self.sv.left, self.sv.top = 600, 600
                self.control:ClearAnchors()
                self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.sv.left, self.sv.top)
            end,
        },
    }
    if TrackersByJH_RegisterMenu then TrackersByJH_RegisterMenu("Alkosh Tracker", options) end
end


-- Gamepad movement: intentionally identical in behavior to Warmask.
local isGamepadMoveModeActive = false
AT.isGamepadMoveModeActive = false
local moveLastUpdateMs = 0

local function SavePosition()
    if not AT.control or not AT.sv then return end
    local left, top = AT.control:GetLeft(), AT.control:GetTop()
    if left and top then AT.sv.left, AT.sv.top = left, top end
end

local function RequestSavedVariablesSave()
    local addonManager = GetAddOnManager and GetAddOnManager()
    if addonManager and addonManager.RequestAddOnSavedVariablesPrioritySave then
        addonManager:RequestAddOnSavedVariablesPrioritySave("TrackersByJH")
    end
end

local function ApplyTrackerPosition()
    if not AT.control or not AT.sv then return end
    AT.control:ClearAnchors()
    AT.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, AT.sv.left or 600, AT.sv.top or 600)
end

local function UpdateGamepadMove()
    if not isGamepadMoveModeActive or not AT.control or not AT.sv then return end
    local stickX = GetGamepadLeftStickX and GetGamepadLeftStickX(true) or 0
    local stickY = GetGamepadLeftStickY and GetGamepadLeftStickY(true) or 0
    if math.abs(stickX) < 0.18 then stickX = 0 end
    if math.abs(stickY) < 0.18 then stickY = 0 end
    if stickX == 0 and stickY == 0 then return end
    local now = GetGameTimeMilliseconds()
    local dt = 0.016
    if moveLastUpdateMs > 0 then dt = math.min((now - moveLastUpdateMs) / 1000, 0.05) end
    moveLastUpdateMs = now
    local speed = tonumber(AT.sv.gamepadMoveSpeed) or 420
    AT.sv.left = (AT.sv.left or 600) + (stickX * speed * dt)
    AT.sv.top = (AT.sv.top or 600) - (stickY * speed * dt)
    ApplyTrackerPosition()
end

local function StartGamepadMoveMode()
    if isGamepadMoveModeActive or not AT.control then return end
    isGamepadMoveModeActive = true
    AT.isGamepadMoveModeActive = true
    moveLastUpdateMs = 0
    AT.control:SetHidden(false)
    if AT.label then AT.label:SetText("MOVE") end
    if AT.inactiveX then AT.inactiveX:SetHidden(true) end
    EVENT_MANAGER:RegisterForUpdate(AT.name .. "GamepadMove", 16, UpdateGamepadMove)
    d("|cFFFFFF|c00AAFFAlkosh Tracker|r Move mode: |c00FF00ON|r - move with left stick")
end

local function StopGamepadMoveMode()
    if not isGamepadMoveModeActive then return end
    EVENT_MANAGER:UnregisterForUpdate(AT.name .. "GamepadMove")
    isGamepadMoveModeActive = false
    AT.isGamepadMoveModeActive = false
    moveLastUpdateMs = 0
    SavePosition()
    RequestSavedVariablesSave()
    AT:UpdateUI()
    AT:RefreshVisibility()
    d("|cFFFFFF|c00AAFFAlkosh Tracker|r Move mode: |cFFAA00OFF|r - position saved")
end

local function ToggleGamepadMoveMode()
    if isGamepadMoveModeActive then StopGamepadMoveMode() else StartGamepadMoveMode() end
end
AT.ToggleGamepadMoveMode = ToggleGamepadMoveMode
SLASH_COMMANDS["/atmove"] = ToggleGamepadMoveMode

local function OnAddonLoaded(_, addonName)
    if addonName ~= AT.name and addonName ~= "TrackersByJH" then return end
    EVENT_MANAGER:UnregisterForEvent(AT.name, EVENT_ADD_ON_LOADED)
    AT:Initialize()
end
EVENT_MANAGER:RegisterForEvent(AT.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
