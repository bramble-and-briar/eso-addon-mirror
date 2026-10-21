KwibusRandomThings = KwibusRandomThings or {}
local KRT = KwibusRandomThings
local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local ADDON_NAME = KRT.name

local IsNonEmptyString = KRT.IsNonEmptyString

local DEFAULTS = { kow = {
    enabled = true,
    text = "overload",
    fontScale = 1.0,
    offsetX = 0,
    offsetY = 0,
    enableReposition = false,
    textSide = "center", -- "left", "center", "right"
    color = { r = 1, g = 0.85, b = 0.2 },
} }

KRT.KOW = {
    id = "kow",
    defaults = DEFAULTS.kow,
    TARGET_BUFF_ID = 24806,

    ui = nil,
    lbl = nil,
}

function KRT.KOW:SV()
    return KRT.GetModuleSV(self.id, self.defaults)
end

function KRT.KOW:HasOverloadBuff()
    local numBuffs = GetNumBuffs("player")
    for i = 1, numBuffs do
        local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if abilityId == self.TARGET_BUFF_ID then
            return true
        end
    end
    return false
end

function KRT.KOW:EnsureOverlay()
    if self.ui then return end
    local sv = self:SV()
    if not sv then return end

    local win = WM:CreateTopLevelWindow("KwibusOverloadWatcher_UI")
    win:SetDimensions(220, 60)
    win:SetHidden(true)
    win:SetMouseEnabled(false)
    win:SetMovable(false)
    win:SetClampedToScreen(true)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLevel(9999)

    local label = WM:CreateControl("KwibusOverloadWatcher_Lbl", win, CT_LABEL)
    label:SetAnchor(CENTER, win, CENTER, 0, 0)
    label:SetFont("ZoFontWinH1")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    self.ui = win
    self.lbl = label

    self:ApplyAnchor()
    self:UpdateTextStyle()
end

function KRT.KOW:UpdateTextStyle()
    local ui, lbl = self.ui, self.lbl
    if not (ui and lbl) then return end
    local sv = self:SV()
    if not sv then return end

    local text = IsNonEmptyString(sv.text) and sv.text or DEFAULTS.kow.text
    local scale = sv.fontScale or DEFAULTS.kow.fontScale
    local c = sv.color or DEFAULTS.kow.color
    local side = sv.textSide or "center"

    lbl:SetText(text)
    lbl:SetScale(scale)
    lbl:SetColor(c.r or 1, c.g or 0.85, c.b or 0.2, 1)

    if side == "left" then
        lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    elseif side == "right" then
        lbl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    else
        lbl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end

    KRT.ResizeTextHitbox("KOW_Resize", ui, lbl, scale, 80, 30)
end

function KRT.KOW:ApplyAnchor()
    KRT.ApplyCenterAnchor(self.ui, self:SV(), DEFAULTS.kow.offsetY)
end

function KRT.KOW:EnableDragging(enable)
    local sv = self:SV()
    KRT.EnableDragging(self.ui, self.lbl, sv, enable, function() self:ApplyAnchor() end, function() self:UpdateDisplay() end)
end

function KRT.KOW:UpdateDisplay(hasBuff)
    local sv = self:SV()
    if not sv then return end
    if not self.ui then return end

    if not sv.enabled then
        self.ui:SetHidden(true)
        return
    end

    if sv.enableReposition then
        self.ui:SetHidden(false)
        return
    end

    if hasBuff == nil then
        hasBuff = self:HasOverloadBuff()
    end

    self.ui:SetHidden(not hasBuff)
end

function KRT.KOW:Initialize()
    local sv = self:SV()
    if not sv then return end

    self:EnsureOverlay()
    self:ApplyAnchor()
    self:UpdateTextStyle()
    self:EnableDragging(sv.enableReposition)

    EM:RegisterForEvent(ADDON_NAME .. "_KOW_Activated", EVENT_PLAYER_ACTIVATED, function()
        local sv2 = self:SV()
        if not (sv2 and sv2.enabled) then return end
        self:UpdateDisplay()
    end)

    EM:RegisterForEvent(ADDON_NAME .. "_KOW_Effect", EVENT_EFFECT_CHANGED, function(_, changeType)
        local sv2 = self:SV()
        if not (sv2 and sv2.enabled) then return end
        if changeType == EFFECT_RESULT_GAINED then
            self:UpdateDisplay(true)
        elseif changeType == EFFECT_RESULT_FADED then
            self:UpdateDisplay(false)
        else
            self:UpdateDisplay()
        end
    end)
    EM:AddFilterForEvent(ADDON_NAME .. "_KOW_Effect", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    EM:AddFilterForEvent(ADDON_NAME .. "_KOW_Effect", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, self.TARGET_BUFF_ID)

    self:UpdateDisplay()
end

local function SV()
    return KRT.KOW:SV()
end

function KRT.KOW:GetLAMSubmenu()
    return {
        type = "submenu",
        name = "Overload Watcher",
        controls = {
            {
                type = "checkbox",
                name = "Enable Module",
                getFunc = function() return SV().enabled end,
                setFunc = function(v)
                    SV().enabled = v
                    if not v then
                        KRT.KOW:EnableDragging(false)
                        if KRT.KOW.ui then KRT.KOW.ui:SetHidden(true) end
                    else
                        KRT.KOW:UpdateDisplay()
                    end
                end,
                width = "full",
            },
            {
                type = "checkbox",
                name = "Enable Repositioning (Drag)",
                tooltip = "Allows you to drag and reposition the reminder overlay.",
                getFunc = function() return SV().enableReposition end,
                setFunc = function(v)
                    SV().enableReposition = v
                    KRT.KOW:EnableDragging(v)
                    KRT.KOW:ApplyAnchor()
                end,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "button",
                name = "Reset Horizontal Position",
                func = function()
                    SV().offsetX = 0
                    KRT.KOW:ApplyAnchor()
                end,
                width = "half",
                disabled = function() return not SV().enabled or not SV().enableReposition end,
            },
            {
                type = "button",
                name = "Reset Vertical Position",
                func = function()
                    SV().offsetY = DEFAULTS.kow.offsetY
                    KRT.KOW:ApplyAnchor()
                end,
                width = "half",
                disabled = function() return not SV().enabled or not SV().enableReposition end,
            },
            {
                type = "editbox",
                name = "Reminder Text",
                isMultiline = false,
                getFunc = function() return SV().text end,
                setFunc = function(v)
                    SV().text = IsNonEmptyString(v) and v or DEFAULTS.kow.text
                    KRT.KOW:UpdateTextStyle()
                    KRT.KOW:UpdateDisplay()
                end,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "slider",
                name = "Text Scale",
                min = 0.5,
                max = 3.0,
                step = 0.1,
                getFunc = function() return SV().fontScale end,
                setFunc = function(v)
                    SV().fontScale = v
                    KRT.KOW:UpdateTextStyle()
                end,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
            {
                type = "dropdown",
                name = "Text Side",
                choices = { "Left", "Center", "Right" },
                choicesValues = { "left", "center", "right" },
                getFunc = function() return SV().textSide end,
                setFunc = function(v)
                    SV().textSide = v
                    KRT.KOW:UpdateTextStyle()
                end,
                width = "full",
                disabled = function() return not SV().enabled end,
            },
        },
    }
end

KRT:RegisterModule(KRT.KOW)