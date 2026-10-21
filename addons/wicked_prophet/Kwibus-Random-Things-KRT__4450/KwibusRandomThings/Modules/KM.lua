KwibusRandomThings = KwibusRandomThings or {}
local KRT = KwibusRandomThings
local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local ADDON_NAME = KRT.name

local EnsureTable = KRT.EnsureTable
local IsNonEmptyString = KRT.IsNonEmptyString

local LSB = LibSkillBlocker
local DEFAULTS = { km = {
    enabled = true,
    blockFlare = true,
    timeout = 20,
    text = "ARCHDRUID READY",
    showStaticLabel = true,
    labelScale = 1.8,
    debugEnabled = false,
    blockedAbilityIds = { [61489] = true },
    offsetX = 0,
    offsetY = -200,
    enableReposition = false,
} }

KRT.KM = {
    id = "km",
    defaults = DEFAULTS.km,
    ARCHDRUID_ABILITY_ID = 176816,
    DEFAULT_FLARE_ID = 61489,
    MIN_PIECES = 2,
    SLOTS = { EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS },
    HARD_COOLDOWN = 15,

    lastArchdruidTime = 0,
    _lastArchdruidCount = nil,
    _hasTwoPieces = false,

    warningWindow = nil,
    warningLabel = nil,
    registeredBlocks = {},
    _loopsRegistered = false,
    _updateRegistered = false,
}

function KRT.KM:SV()
    return KRT.GetModuleSV(self.id, self.defaults)
end

function KRT.KM:Debug(msg, ...)
    local sv = self:SV()
    if not (sv and sv.debugEnabled) then return end
    if select("#", ...) > 0 then
        d(string.format("[KM] " .. msg, ...))
    else
        d("[KM] " .. tostring(msg))
    end
end

function KRT.KM:HasLibSkillBlocker()
    return LSB ~= nil
end

local function IsArchdruidSetName(setName)
    if not IsNonEmptyString(setName) then return false end
    local lower = zo_strlower(setName)
    if string.find(lower, "archdruid", 1, true) == 1 then return true end
    if string.find(lower, "архидруид", 1, true) == 1 then return true end
    return false
end

function KRT.KM:_ComputeArchdruidPieceCount()
    local count = 0
    for _, slot in ipairs(self.SLOTS) do
        local link = GetItemLink(BAG_WORN, slot)
        if IsNonEmptyString(link) then
            local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(link, false)
            if hasSet and (setId == 666 or IsArchdruidSetName(setName)) then
                count = count + 1
            end
        end
    end

    if count ~= self._lastArchdruidCount then
        self._lastArchdruidCount = count
        self:Debug("Archdruid pieces equipped: %d", count)
    end
    return count
end

function KRT.KM:UpdateEquippedPieces()
    self._hasTwoPieces = (self:_ComputeArchdruidPieceCount() >= self.MIN_PIECES)
    self:UpdateLoopState()
end

function KRT.KM:HasTwoPieces()
    return self._hasTwoPieces == true
end

function KRT.KM:GetCooldownRemaining()
    local elapsed = GetGameTimeSeconds() - (self.lastArchdruidTime or 0)
    local remaining = (self.HARD_COOLDOWN or 15) - elapsed
    return (remaining > 0) and remaining or 0
end

function KRT.KM:IsOnCooldown()
    return self:GetCooldownRemaining() > 0
end

function KRT.KM:CreateWarningWindow()
    if self.warningWindow then return end

    local win = WM:CreateTopLevelWindow("KwibusKromitorMomentWarningWindow")
    win:SetDimensions(120, 40)
    win:SetHidden(true)
    win:SetMouseEnabled(false)
    win:SetMovable(false)
    win:SetClampedToScreen(true)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLevel(9999)

    local label = WM:CreateControl("$(parent)Label", win, CT_LABEL)
    label:SetAnchor(CENTER, win, CENTER, 0, 0)
    label:SetFont("ZoFontAnnounceLarge")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(1, 0.1, 0.1, 1)

    self.warningWindow = win
    self.warningLabel = label
    self:UpdateWarningText()
end

function KRT.KM:UpdateWarningText()
    local win, label = self.warningWindow, self.warningLabel
    if not (win and label) then return end

    local sv = self:SV()
    if not sv then return end

    local scale = sv.labelScale or DEFAULTS.km.labelScale
    local text = IsNonEmptyString(sv.text) and sv.text or DEFAULTS.km.text

    label:SetText(text)
    label:SetScale(scale)

    KRT.ResizeTextHitbox("KM_Resize", win, label, scale, 60, 30)
end

function KRT.KM:ApplyAnchor()
    KRT.ApplyCenterAnchor(self.warningWindow, self:SV(), DEFAULTS.km.offsetY)
end

function KRT.KM:EnableDragging(enable)
    local sv = self:SV()
    KRT.EnableDragging(self.warningWindow, self.warningLabel, sv, enable, function() self:ApplyAnchor() end, function()
        self:UpdateLoopState()
        self:OnUpdate()
    end)
end

function KRT.KM:OnCombatEvent(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
    if self:IsOnCooldown() then
        self:Debug("Archdruid proc ignored: hard cooldown active (%.1fs remaining)", self:GetCooldownRemaining())
        return
    end

    self.lastArchdruidTime = GetGameTimeSeconds()
    self:Debug("Archdruid proc detected. 15s hard cooldown started.")

    local sv = self:SV()
    if self.warningWindow and sv and not sv.enableReposition then
        self.warningWindow:SetHidden(true)
    end
end

function KRT.KM:UpdateLoopState()
    local sv = self:SV()
    local shouldRun = sv and sv.enabled and (sv.enableReposition or (IsUnitInCombat("player") and self._hasTwoPieces))
    if shouldRun then
        if not self._updateRegistered then
            EM:RegisterForUpdate(ADDON_NAME .. "_KM_Update", 250, function()
                self:OnUpdate()
            end)
            self._updateRegistered = true
        end
    else
        if self._updateRegistered then
            EM:UnregisterForUpdate(ADDON_NAME .. "_KM_Update")
            self._updateRegistered = false
        end
        if self.warningWindow and sv and not sv.enableReposition then
            self.warningWindow:SetHidden(true)
        end
    end
end

function KRT.KM:ToggleBackgroundLoops(enable)
    if enable and not self._loopsRegistered then
        EM:RegisterForEvent(ADDON_NAME .. "_KM_Archdruid", EVENT_COMBAT_EVENT, function(...)
            self:OnCombatEvent(...)
        end)
        EM:AddFilterForEvent(ADDON_NAME .. "_KM_Archdruid", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, self.ARCHDRUID_ABILITY_ID)
        EM:AddFilterForEvent(ADDON_NAME .. "_KM_Archdruid", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

        EM:RegisterForEvent(ADDON_NAME .. "_KM_Inv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bagId, slotId)
            if slotId == EQUIP_SLOT_HEAD or slotId == EQUIP_SLOT_SHOULDERS then
                self:UpdateEquippedPieces()
            end
        end)
        EM:AddFilterForEvent(ADDON_NAME .. "_KM_Inv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
        EM:AddFilterForEvent(ADDON_NAME .. "_KM_Inv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)

        self._loopsRegistered = true
        self:UpdateEquippedPieces()
    elseif not enable and self._loopsRegistered then
        EM:UnregisterForEvent(ADDON_NAME .. "_KM_Archdruid", EVENT_COMBAT_EVENT)
        EM:UnregisterForEvent(ADDON_NAME .. "_KM_Inv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
        self._loopsRegistered = false
        self:UpdateLoopState()
    end
end

function KRT.KM:OnUpdate()
    local sv = self:SV()
    if not (sv and self.warningWindow) then return end

    if sv.enableReposition then
        self.warningWindow:SetHidden(false)
        return
    end

    if not IsUnitInCombat("player") then
        self.warningWindow:SetHidden(true)
        return
    end

    if not self:HasTwoPieces() then
        self.warningWindow:SetHidden(true)
        return
    end

    if self:IsOnCooldown() then
        self.warningWindow:SetHidden(true)
        return
    end

    local elapsed = GetGameTimeSeconds() - (self.lastArchdruidTime or 0)
    local timeout = sv.timeout or DEFAULTS.km.timeout
    local show = (elapsed >= timeout) and sv.showStaticLabel
    self.warningWindow:SetHidden(not show)
end

function KRT.KM:_EnsureSkillBlockRegistered(abilityId)
    if self.registeredBlocks[abilityId] then return end
    if not LSB then return end

    self.registeredBlocks[abilityId] = true
    local idForClosure = abilityId

    LSB.RegisterSkillBlock(ADDON_NAME, idForClosure, function()
        local sv = KRT.KM:SV()
        return sv and sv.enabled and sv.blockFlare and sv.blockedAbilityIds and sv.blockedAbilityIds[idForClosure]
    end, true)
end

function KRT.KM:SetupSkillBlocking()
    local sv = self:SV()
    if not sv then return end

    if not self:HasLibSkillBlocker() then
        if sv.blockFlare then
            sv.blockFlare = false
        end
        self:Debug("LibSkillBlocker not found - forcing blockFlare off")
        return
    end

    sv.blockedAbilityIds = EnsureTable(sv.blockedAbilityIds)
    if sv.blockedAbilityIds[self.DEFAULT_FLARE_ID] == nil then
        sv.blockedAbilityIds[self.DEFAULT_FLARE_ID] = true
    end

    for id, _ in pairs(sv.blockedAbilityIds) do
        self:_EnsureSkillBlockRegistered(id)
    end
end

function KRT.KM:GetBlockedAbilityListText()
    local sv = self:SV()
    if not sv then return "None" end

    local lines = {}
    for abilityId, enabled in pairs(sv.blockedAbilityIds or {}) do
        if enabled then
            local name = GetAbilityName(abilityId)
            if IsNonEmptyString(name) then
                table.insert(lines, string.format("%d (%s)", abilityId, name))
            else
                table.insert(lines, tostring(abilityId))
            end
        end
    end

    if #lines == 0 then return "None" end
    table.sort(lines)
    return table.concat(lines, "\n")
end

function KRT.KM:AddBlockedAbilityIdFromString(str)
    local sv = self:SV()
    if not sv then return end

    local id = tonumber(str)
    if not id then return end

    sv.blockedAbilityIds = EnsureTable(sv.blockedAbilityIds)
    sv.blockedAbilityIds[id] = true
    self:_EnsureSkillBlockRegistered(id)
end

function KRT.KM:RemoveBlockedAbilityIdFromString(str)
    local sv = self:SV()
    if not sv then return end

    local id = tonumber(str)
    if not id then return end

    if sv.blockedAbilityIds then
        sv.blockedAbilityIds[id] = nil
    end
end

function KRT.KM:RegisterSlashCommands()
    SLASH_COMMANDS["/kmtest"] = function()
        if self.warningWindow then
            self.warningWindow:SetHidden(false)
        end
    end
end

function KRT.KM:Initialize()
    local sv = self:SV()
    if not sv then return end

    sv.blockedAbilityIds = EnsureTable(sv.blockedAbilityIds)
    if sv.blockedAbilityIds[self.DEFAULT_FLARE_ID] == nil then
        sv.blockedAbilityIds[self.DEFAULT_FLARE_ID] = true
    end

    if not self:HasLibSkillBlocker() then
        sv.blockFlare = false
    end

    local timeout = math.max(self.HARD_COOLDOWN, sv.timeout or DEFAULTS.km.timeout)
    self.lastArchdruidTime = GetGameTimeSeconds() - timeout

    self:CreateWarningWindow()
    self:ApplyAnchor()
    self:EnableDragging(sv.enableReposition)
    self:SetupSkillBlocking()
    self:RegisterSlashCommands()

    EM:RegisterForEvent(ADDON_NAME .. "_KM_CombatState", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        local sv2 = self:SV()
        if not (sv2 and sv2.enabled) then return end
        self:UpdateLoopState()
        if inCombat then
            self:OnUpdate()
        end
    end)

    if sv.enabled then
        self:ToggleBackgroundLoops(true)
    end
end

local function SV()
    return KRT.KM:SV()
end

function KRT.KM:GetLAMSubmenu()
    return {
        type = "submenu",
        name = "Kromitor Moment",
        controls = {
            {
                type = "checkbox",
                name = "Enable Module",
                getFunc = function()
                    return SV().enabled
                end,
                setFunc = function(v)
                    SV().enabled = v
                    if not v then
                        KRT.KM:EnableDragging(false)
                        if KRT.KM.warningWindow then
                            KRT.KM.warningWindow:SetHidden(true)
                        end
                        KRT.KM:ToggleBackgroundLoops(false)
                        KRT.KM:UpdateLoopState()
                    else
                        KRT.KM:ToggleBackgroundLoops(true)
                        KRT.KM:UpdateLoopState()
                    end
                end,
                width = "full",
            },
            {
                type = "checkbox",
                name = "Enable Repositioning (Drag)",
                tooltip = "Allows you to drag and reposition the warning overlay.",
                getFunc = function()
                    return SV().enableReposition
                end,
                setFunc = function(v)
                    SV().enableReposition = v
                    KRT.KM:EnableDragging(v)
                    KRT.KM:ApplyAnchor()
                end,
                width = "full",
                disabled = function()
                    return not SV().enabled
                end,
            },
            {
                type = "button",
                name = "Reset Horizontal Position",
                func = function()
                    SV().offsetX = 0
                    KRT.KM:ApplyAnchor()
                end,
                disabled = function()
                    return not SV().enabled or not SV().enableReposition
                end,
                width = "half",
            },
            {
                type = "button",
                name = "Reset Vertical Position",
                func = function()
                    SV().offsetY = DEFAULTS.km.offsetY
                    KRT.KM:ApplyAnchor()
                end,
                disabled = function()
                    return not SV().enabled or not SV().enableReposition
                end,
                width = "half",
            },
            {
                type = "editbox",
                name = "Warning Text",
                isMultiline = false,
                getFunc = function()
                    return SV().text
                end,
                setFunc = function(v)
                    SV().text = IsNonEmptyString(v) and v or DEFAULTS.km.text
                    KRT.KM:UpdateWarningText()
                end,
                width = "full",
                disabled = function()
                    return not SV().enabled
                end,
            },
            {
                type = "slider",
                name = "Text Scale",
                min = 0.5,
                max = 3.0,
                step = 0.1,
                getFunc = function()
                    return SV().labelScale
                end,
                setFunc = function(v)
                    SV().labelScale = v
                    KRT.KM:UpdateWarningText()
                end,
                width = "full",
                disabled = function()
                    return not SV().enabled
                end,
            },
            {
                type = "checkbox",
                name = "Show Static Label When Missing Proc",
                getFunc = function()
                    return SV().showStaticLabel
                end,
                setFunc = function(v)
                    SV().showStaticLabel = v
                end,
                width = "full",
                disabled = function()
                    return not SV().enabled
                end,
            },
            {
                type = "slider",
                name = "Archdruid Timeout (Seconds)",
                tooltip = "Seconds after a proc before warning you. Archdruid has a hard 15-second cooldown.",
                min = 15,
                max = 60,
                step = 1,
                getFunc = function()
                    local val = SV().timeout or DEFAULTS.km.timeout
                    return math.max(KRT.KM.HARD_COOLDOWN, val)
                end,
                setFunc = function(v)
                    SV().timeout = math.max(KRT.KM.HARD_COOLDOWN, v)
                end,
                width = "full",
                disabled = function()
                    return not SV().enabled
                end,
            },
            {
                type = "checkbox",
                name = "Block Configured Skills (LibSkillBlocker)",
                getFunc = function()
                    if not KRT.KM:HasLibSkillBlocker() then
                        return false
                    end
                    return SV().blockFlare
                end,
                setFunc = function(v)
                    if not KRT.KM:HasLibSkillBlocker() then
                        SV().blockFlare = false
                        return
                    end
                    SV().blockFlare = v
                end,
                width = "full",
                disabled = function()
                    return not SV().enabled or not KRT.KM:HasLibSkillBlocker()
                end,
                warning = function()
                    if not KRT.KM:HasLibSkillBlocker() then
                        return "|cFF0000libskillblocker is missing or turned off|r"
                    end
                    return nil
                end,
            },
            {
                type = "description",
                title = "Blocked Ability IDs",
                text = function()
                    return KRT.KM:GetBlockedAbilityListText()
                end,
                width = "full",
            },
            {
                type = "editbox",
                name = "Add Ability ID to Block",
                isMultiline = false,
                getFunc = function()
                    return ""
                end,
                setFunc = function(value)
                    KRT.KM:AddBlockedAbilityIdFromString(value)
                    KRT.KM:SetupSkillBlocking()
                end,
                width = "full",
                disabled = function()
                    return not SV().enabled
                end,
            },
            {
                type = "editbox",
                name = "Remove Ability ID from Block List",
                isMultiline = false,
                getFunc = function()
                    return ""
                end,
                setFunc = function(value)
                    KRT.KM:RemoveBlockedAbilityIdFromString(value)
                end,
                width = "full",
                disabled = function()
                    return not SV().enabled
                end,
            },
            {
                type = "checkbox",
                name = "Enable Debug Logging",
                getFunc = function()
                    return SV().debugEnabled
                end,
                setFunc = function(v)
                    SV().debugEnabled = v
                end,
                width = "full",
                disabled = function()
                    return not SV().enabled
                end,
            },
        },
    }
end

KRT:RegisterModule(KRT.KM)