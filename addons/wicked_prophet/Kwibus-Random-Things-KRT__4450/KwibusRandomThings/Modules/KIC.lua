KwibusRandomThings = KwibusRandomThings or {}
local KRT = KwibusRandomThings
local EM = EVENT_MANAGER
local ADDON_NAME = KRT.name

local DEFAULTS = { kic = {
    enabled = true,
    offsetX = 0,
    offsetY = -100,
    fontScale = 1.0,
    enableReposition = false,
    enterText = "IN COMBAT",
    exitText = "WOW ENEMY DIED",
    durationMs = 3000,
    enterColor = { r = 1, g = 0, b = 0 },
    exitColor = { r = 0, g = 1, b = 0 },
} }

KRT.KIC = {
    id = "kic",
    defaults = DEFAULTS.kic,
    hideTimerId = nil,
}

local FALLBACK_COLOR = { r = 1, g = 1, b = 1 } -- PERFORMANCE FIX

function KRT.KIC:SV()
    return KRT.GetModuleSV(self.id, self.defaults)
end
local function SV() return KRT.KIC:SV() end

local function KIC_CancelHide()
    if KRT.KIC.hideTimerId ~= nil then
        zo_removeCallLater(KRT.KIC.hideTimerId)
        KRT.KIC.hideTimerId = nil
    end
end

function KRT.KIC:ApplyAnchor()
    KRT.ApplyCenterAnchor(KwibusInCombat_UI, self:SV(), DEFAULTS.kic.offsetY)
end

function KRT.KIC:ApplyFontScale()
    local sv = self:SV()
    if not (KwibusInCombat_UIText and sv) then return end
    KwibusInCombat_UIText:SetScale(sv.fontScale or 1.0)
end

function KRT.KIC:EnableDragging(enable)
    local sv = self:SV()
    local ui = KwibusInCombat_UI
    local bg = KwibusInCombat_UIDragBG
    local label = KwibusInCombat_UIText
    if bg then
        bg:SetHidden(not enable)
        bg:SetMouseEnabled(false)
    end
    KRT.EnableDragging(ui, label, sv, enable, function() self:ApplyAnchor() end)
end

function KRT.KIC:ShowMessage(text, color, durationMs)
    local sv = self:SV()
    if not (sv and sv.enabled) then return end
    if not (KwibusInCombat_UI and KwibusInCombat_UIText) then return end

    KIC_CancelHide()

    KwibusInCombat_UIText:SetText(text or "")
    local c = color or FALLBACK_COLOR
    KwibusInCombat_UIText:SetColor(c.r or 1, c.g or 1, c.b or 1, 1)

    KwibusInCombat_UI:SetHidden(false)

    self.hideTimerId = zo_callLater(function()
        local sv2 = self:SV()
        if not (sv2 and sv2.enableReposition) then
            KwibusInCombat_UI:SetHidden(true)
        end
        self.hideTimerId = nil
    end, durationMs or 3000)
end

function KRT.KIC:OnCombatStateChanged(inCombat)
    local sv = self:SV()
    if not (sv and sv.enabled) then return end
    if sv.enableReposition then return end
    if inCombat then
        self:ShowMessage(sv.enterText, sv.enterColor, sv.durationMs)
    else
        self:ShowMessage(sv.exitText, sv.exitColor, sv.durationMs)
    end
end

function KRT.KIC:RegisterSlashCommands()
    SLASH_COMMANDS["/kic"] = function(arg)
        arg = (arg or ""):lower()
        if arg == "test" then
            local sv = self:SV()
            if not sv then return end
            local prevMove = sv.enableReposition
            sv.enableReposition = false
            self:EnableDragging(false)
            self:ShowMessage(sv.enterText, sv.enterColor, sv.durationMs)
            zo_callLater(function()
                self:ShowMessage(sv.exitText, sv.exitColor, sv.durationMs)
                sv.enableReposition = prevMove
                self:EnableDragging(prevMove)
            end, (sv.durationMs or 3000) + 500)
        else
            d("[KRT] /kic test")
        end
    end
end

function KRT.KIC:Initialize()
    local sv = self:SV()
    if not sv then return end

    self:ApplyAnchor()
    self:ApplyFontScale()
    self:EnableDragging(sv.enableReposition)

    if sv.enableReposition then
        KIC_CancelHide()
        self:ShowMessage("move me", { r = 1, g = 1, b = 1 }, 9999999)
    end

    EM:RegisterForEvent(ADDON_NAME .. "_KIC_Combat", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        self:OnCombatStateChanged(inCombat)
    end)

    self:RegisterSlashCommands()
end

function KRT.KIC:GetLAMSubmenu()
    return {
        type = "submenu",
        name = "Kwibus In Combat",
        controls = {
            {
                type = "checkbox",
                name = "Enable Module",
                getFunc = function() return SV().enabled end,
                setFunc = function(v)
                    SV().enabled = v
                    if not v then
                        KIC_CancelHide()
                        self:EnableDragging(false)
                        if KwibusInCombat_UI then KwibusInCombat_UI:SetHidden(true) end
                    end
                end,
                width = "full",
            },
            {
                type = "checkbox",
                name = "Enable Repositioning (Drag)",
                tooltip = "Shows a drag box and a move me message.",
                getFunc = function() return SV().enableReposition end,
                setFunc = function(v)
                    SV().enableReposition = v
                    KRT.KIC:EnableDragging(v)
                    KRT.KIC:ApplyAnchor()
                    if v then
                        KIC_CancelHide()
                        KRT.KIC:ShowMessage("move me", { r = 1, g = 1, b = 1 }, 9999999)
                    else
                        if KwibusInCombat_UI then KwibusInCombat_UI:SetHidden(true) end
                    end
                end,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "button",
                name = "Reset Horizontal Position",
                func = function() SV().offsetX = 0; KRT.KIC:ApplyAnchor() end,
                disabled = function() return not SV().enabled or not SV().enableReposition end,
                width = "half",
            },
            {
                type = "button",
                name = "Reset Vertical Position",
                func = function() SV().offsetY = DEFAULTS.kic.offsetY; KRT.KIC:ApplyAnchor() end,
                disabled = function() return not SV().enabled or not SV().enableReposition end,
                width = "half",
            },
            {
                type = "editbox",
                name = "Enter Combat Text",
                isMultiline = false,
                getFunc = function() return SV().enterText end,
                setFunc = function(v) SV().enterText = v end,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "editbox",
                name = "Exit Combat Text",
                isMultiline = false,
                getFunc = function() return SV().exitText end,
                setFunc = function(v) SV().exitText = v end,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "slider",
                name = "Text Scale",
                min = 0.5,
                max = 2.0,
                step = 0.05,
                getFunc = function() return SV().fontScale end,
                setFunc = function(v) SV().fontScale = v; KRT.KIC:ApplyFontScale() end,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "slider",
                name = "Duration (ms)",
                min = 500,
                max = 8000,
                step = 100,
                getFunc = function() return SV().durationMs end,
                setFunc = function(v) SV().durationMs = v end,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
        }
    }
end

KRT:RegisterModule(KRT.KIC)