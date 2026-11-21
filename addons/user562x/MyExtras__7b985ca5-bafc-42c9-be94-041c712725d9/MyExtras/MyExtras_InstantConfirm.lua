local ME = MyExtras
local QoL = ME.QualityOfLife
local IC = {}
ME.InstantConfirm = IC

--------------------------------------------------
-- Config
--------------------------------------------------
local DEFAULTS = {
    qolInstantConfirm = false,
}
QoL:AddDefaults(DEFAULTS)

local TYPED_DIALOGS = {
    CONFIRM_DESTROY_ITEM_PROMPT        = true,
    CONFIRM_DESTROY_ARMORY_ITEM_PROMPT = true,
}

local hookedStrip  = false
local hookedDialog = false

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return QoL:Settings()
end

local function IsOn()
    return SV().qolInstantConfirm == true
end

--------------------------------------------------
-- Hooks
--------------------------------------------------
local function HookStrip()
    if hookedStrip or not (KEYBIND_STRIP and KEYBIND_STRIP.TriggerCooldown) then return end
    hookedStrip = true
    ZO_PreHook(KEYBIND_STRIP, "TriggerCooldown", function()
        return IsOn()
    end)
end

local function FillTyped(name)
    zo_callLater(function()
        if not IsOn() or not ZO_Dialogs_IsShowing(name) then return end
        local edit = rawget(_G, "ZO_Dialog1EditBox")
        if not edit then return end
        edit:SetText(GetString(SI_DESTROY_ITEM_CONFIRMATION))
        edit:LoseFocus()
    end, 10)
end

local function HookDialog()
    if hookedDialog then return end
    hookedDialog = true
    SecurePostHook("ZO_Dialogs_ShowDialog", function(name)
        if IsOn() and TYPED_DIALOGS[name] then FillTyped(name) end
    end)
end

--------------------------------------------------
-- Apply
--------------------------------------------------
function IC:Refresh()
    if IsOn() then
        HookStrip()
        HookDialog()
    end
end

--------------------------------------------------
-- Menu
--------------------------------------------------
function IC:Option()
    return {
        type    = "toggle",
        name    = "Instant Confirm",
        preset  = "YES_NO",
        default = DEFAULTS.qolInstantConfirm,
        tooltip = "Skips the countdown before you can press Yes on a confirmation, like when you delete a gold item, "
               .. "send mail or change your armory. You still press Yes once.",
        getFunc = function() return SV().qolInstantConfirm end,
        setFunc = function(val)
            SV().qolInstantConfirm = val
            IC:Refresh()
        end,
    }
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function IC:Init()
    self:Refresh()
end

function IC:OnPlayerActivated()
    self:Refresh()
end

function IC:OnReset()
    self:Refresh()
end

ME:RegisterFeature(IC)
