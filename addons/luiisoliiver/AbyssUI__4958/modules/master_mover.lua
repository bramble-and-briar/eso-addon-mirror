--[[
    Registro no Edit HUD nativo (HUD_MANAGER).
    A posicao e salva pelo ESO. NUNCA chamar RevertOffsetModifications
    enquanto o usuario estiver no editor (isso "puxa de volta" o elemento).
]]

local ADDON_NAME = "AbyssUI"
NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI

local MasterMover = {}
NAGA_UI.MasterMover = MasterMover

local REGISTERED = {}

local ELEMENTS = {
    { "NAGA_UI_ResourceBarsRoot", "HUD DE PERSONAGEM",     CENTER, 0, -120 },
    { "NAGA_UI_TargetFrameRoot", "NAGA - Target Frame",    TOP, 0, 88 },
    { "NAGA_UI_CastBarRoot",     "NAGA - Cast Bar",        BOTTOM, 0, -180 },
    { "NAGA_UI_GroupFramesRoot", "NAGA - Group Frames",    TOPLEFT, 28, 100 },
    { "NAGA_CompanionFrameRoot",  "NAGA - Companion Frame", TOPLEFT, 250, 280 },
    { "NAGA_BuffsPassiveRoot",    "NAGA - Passive Buffs",   BOTTOMRIGHT, 0, 0 },
    { "NAGA_BuffsCustomRoot",     "NAGA - Custom Buffs",    CENTER, 0, 300 },
    { "NAGA_BuffsSynergyRoot",    "NAGA - Synergy CD",      CENTER, -300, 200 },
    { "NAGA_BuffsWidgetsRoot",    "NAGA - Widgets",         CENTER, 400, 350 },
    { "NAGA_InfoPanel",           "NAGA - Info Panel",      TOPRIGHT, -24, 20 },
    { "NAGA_Statistics_Report",  "NAGA - Estatística de Dano", TOP, 0, 28 },
    { "NAGA_Statistics_MiniMeter", "NAGA - Minimedidor DPS", TOPRIGHT, -400, 0 },
}

local function IsEditHUDShowing()
    if not SCENE_MANAGER or not SCENE_MANAGER.IsShowing then return false end
    return SCENE_MANAGER:IsShowing("hud_editor_keyboard")
        or SCENE_MANAGER:IsShowing("hud_editor_gamepad")
end

local function ApplySavedPosition(control)
    if not control or not HUD_MANAGER then return end
    -- NUNCA reverter enquanto o editor esta aberto — causa o "snap back".
    if IsEditHUDShowing() then return end

    local element
    if IsInGamepadPreferredMode and IsInGamepadPreferredMode() then
        element = HUD_MANAGER:GetGamepadElementForControl(control)
    else
        element = HUD_MANAGER:GetKeyboardElementForControl(control)
    end
    if element and element.RevertOffsetModifications then
        pcall(function()
            element:RevertOffsetModifications()
        end)
    end
end

local function RegisterOne(entry)
    local name, displayName = entry[1], entry[2]
    local control = _G[name]
    if not control or REGISTERED[name] or not HUD_MANAGER or not ZO_Anchor then
        return REGISTERED[name] == true
    end

    control.hudElementRef = control

    local defaultAnchor = ZO_Anchor:New(entry[3], nil, entry[3], entry[4], entry[5])
    local options = { defaultAnchor = defaultAnchor }

    local ok = pcall(function()
        HUD_MANAGER:RegisterKeyboardElement(control, displayName, options, COMPASS_OPTIONS)
        HUD_MANAGER:RegisterGamepadElement(control, displayName, options, COMPASS_OPTIONS)
    end)

    if not ok then
        return false
    end

    REGISTERED[name] = true
    control.nagaNativeEditHUD = true
    control.nagaNativeEditHUDName = displayName
    control.hudManaged = true

    -- Fora do Edit HUD, estes elementos devem ser completamente pass-through.
    -- O ESO habilita mouse/movimento durante o editor nativo.
    -- NUNCA habilitar drag do addon durante o jogo normal.
    pcall(function() control:SetHandler("OnMouseUp", nil) end)
    pcall(function() control:SetHandler("OnMoveStop", nil) end)
    pcall(function() control:SetHandler("OnMoveStart", nil) end)
    control:SetMovable(false)
    control:SetMouseEnabled(false)
    control:SetClampedToScreen(true)

    -- Restaura posicao salva pelo ESO (so fora do editor).
    ApplySavedPosition(control)
    return true
end

function MasterMover:RegisterAll()
    if not HUD_MANAGER then return 0 end
    local count = 0
    for _, entry in ipairs(ELEMENTS) do
        if RegisterOne(entry) then
            count = count + 1
        end
    end
    return count
end

function MasterMover:RestoreAllSavedPositions()
    if IsEditHUDShowing() then return end
    for name in pairs(REGISTERED) do
        local control = _G[name]
        if control then
            ApplySavedPosition(control)
        end
    end
end


function MasterMover:IsEditHUDShowing()
    return IsEditHUDShowing()
end

function MasterMover:SetActive(_) self:RegisterAll() end
function MasterMover:IsActive() return next(REGISTERED) ~= nil end

NAGA_UI.OnAddonLoaded(function()
    MasterMover:RegisterAll()
end)

EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_HUDRegAct", EVENT_PLAYER_ACTIVATED, function()
    -- Registrar uma vez apos login (elementos XML ja existem).
    -- NAO ficar reaplicando posicao em loop — isso causa snap-back.
    zo_callLater(function()
        MasterMover:RegisterAll()
        MasterMover:RestoreAllSavedPositions()
    end, 500)
    zo_callLater(function()
        MasterMover:RegisterAll()
    end, 2000)
end)
