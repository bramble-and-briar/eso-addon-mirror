AureoleRange = {}

-- Local references at top of file
local ADDON_NAME                         = "AureoleRange"
local EM                                 = EVENT_MANAGER
local WM                                 = WINDOW_MANAGER
local SM                                 = SCENE_MANAGER
local LAM                                = LibAddonMenu2
local getUnitRawWorldPosition            = GetUnitRawWorldPosition
local worldPositionToGuiRender3DPosition = WorldPositionToGuiRender3DPosition

-- ===== ВКЛЮЧЕНИЕ ПОДДЕРЖКИ МОДИФИКАТОРОВ (Ctrl, Shift, Alt) =====
if KEYBINDINGS_MANAGER and KEYBINDINGS_MANAGER.SetChordingEnabled then
    KEYBINDINGS_MANAGER:SetChordingEnabled(true)
end

-- ===== Defaults =====
AureoleRange.defaults = {
    enabled = true,
    heightOffset     = 0.03,
    stackingStep     = 0.004,
    updateIntervalMs = 20,
    texture        = "AureoleRange/textures/aura_circle.dds",
    useDepthBuffer = true,
    pulse = {
        enabled  = false,
        periodMs = 900,
        minMul   = 0.60,
        maxMul   = 1.35,
    },
    presets = {
        { name = "8m",  enabled = false, radiusMeters = 8,  color = {r=0.20,g=1.00,b=0.20}, intensity = 0.55 },
        { name = "12m", enabled = false, radiusMeters = 12, color = {r=0.20,g=0.80,b=1.00}, intensity = 0.55 },
        { name = "22m", enabled = false, radiusMeters = 22, color = {r=1.00,g=0.80,b=0.20}, intensity = 0.55 },
        { name = "28m", enabled = true,  radiusMeters = 28, color = {r=1.00,g=0.25,b=0.25}, intensity = 0.55 },
        { name = "35m", enabled = false, radiusMeters = 35, color = {r=0.80,g=0.40,b=1.00}, intensity = 0.55 },
    },
    activeRingSet = 1,
    ringSets = {
        { name = "Set 1 (default)",     rings = { 4 } },
        { name = "Set 2 (example 1+5)", rings = { 1, 5 } },
    },
}

-- ===== Local helpers =====
local function Clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function Clamp(x, a, b)
    if x < a then return a end
    if x > b then return b end
    return x
end

local function NormalizeRingsList(rings, maxIndex)
    if type(rings) ~= "table" then return {} end
    local seen, out = {}, {}
    for _, v in ipairs(rings) do
        local i = tonumber(v)
        if i and i >= 1 and i <= maxIndex and not seen[i] then
            seen[i] = true
            out[#out + 1] = i
        end
    end
    table.sort(out)
    return out
end

-- ===== Settings open =====
function AureoleRange.OpenSettingsPanel()
    local panel = AureoleRange_Settings.panel or AureoleRange_Settings.panelId
    if not panel then return end
    if SM then SM:Show("gameMenuInGame") end
    LAM:OpenToPanel(panel)
    local handle = ADDON_NAME .. "_OpenPanelDelay"
    EM:UnregisterForUpdate(handle)
    EM:RegisterForUpdate(handle, 10, function()
        EM:UnregisterForUpdate(handle)
        LAM:OpenToPanel(panel)
    end)
end

-- ===== Pulse =====
function AureoleRange.GetPulseAlpha(baseAlpha)
    local sv = AureoleRange.sv
    baseAlpha = Clamp01(baseAlpha)
    if not sv.pulse.enabled then return baseAlpha end
    local now    = GetGameTimeMilliseconds()
    local period = tonumber(sv.pulse.periodMs) or 900
    if period < 50 then period = 50 end
    local t     = (now - (AureoleRange.pulseStartMs or now)) % period
    local phase = (t / period) * 2 * math.pi
    local s     = (math.sin(phase) + 1) * 0.5
    local minMul = tonumber(sv.pulse.minMul) or 0.60
    local maxMul = tonumber(sv.pulse.maxMul) or 1.35
    if maxMul < minMul then maxMul = minMul end
    return Clamp01(baseAlpha * (minMul + (maxMul - minMul) * s))
end

-- ===== Ring sets =====
function AureoleRange.EnsureRingSets()
    local sv = AureoleRange.sv
    if type(sv.ringSets) ~= "table" then sv.ringSets = {} end
    if #sv.ringSets == 0 then
        table.insert(sv.ringSets, { name = "Set 1", rings = { 4 } })
    end
    if type(sv.activeRingSet) ~= "number" then sv.activeRingSet = 1 end
    if sv.activeRingSet < 1 then sv.activeRingSet = 1 end
    if sv.activeRingSet > #sv.ringSets then sv.activeRingSet = #sv.ringSets end
end

function AureoleRange.GetEnabledRingsList()
    local list = {}
    for i, p in ipairs(AureoleRange.sv.presets) do
        if p.enabled then list[#list + 1] = i end
    end
    return list
end

function AureoleRange.SetEnabledRingsList(list)
    local sv       = AureoleRange.sv
    local maxIndex = #sv.presets
    list = NormalizeRingsList(list, maxIndex)
    for _, p in ipairs(sv.presets) do p.enabled = false end
    for _, i in ipairs(list) do sv.presets[i].enabled = true end
end

function AureoleRange.SaveCurrentSelectionToRingSet(setIndex)
    AureoleRange.EnsureRingSets()
    local set = AureoleRange.sv.ringSets[setIndex]
    if not set then return end
    set.rings = AureoleRange.GetEnabledRingsList()
end

function AureoleRange.LoadRingSet(setIndex)
    AureoleRange.EnsureRingSets()
    local set = AureoleRange.sv.ringSets[setIndex]
    if not set then return end
    AureoleRange.SetEnabledRingsList(set.rings)
end

function AureoleRange.CreateRingSet(name)
    AureoleRange.EnsureRingSets()
    name = tostring(name or "New set")
    table.insert(AureoleRange.sv.ringSets, {
        name  = name,
        rings = AureoleRange.GetEnabledRingsList()
    })
    AureoleRange.sv.activeRingSet = #AureoleRange.sv.ringSets
end

function AureoleRange.DeleteRingSet(setIndex)
    AureoleRange.EnsureRingSets()
    local sv = AureoleRange.sv
    if #sv.ringSets <= 1 then return end
    table.remove(sv.ringSets, setIndex)
    if sv.activeRingSet > #sv.ringSets then
        sv.activeRingSet = #sv.ringSets
    end
end

function AureoleRange.AddCurrentSelectionToRingSet(setIndex)
    AureoleRange.EnsureRingSets()
    local set = AureoleRange.sv.ringSets[setIndex]
    if not set then return end
    local maxIndex = #AureoleRange.sv.presets
    local a        = NormalizeRingsList(set.rings, maxIndex)
    local b        = NormalizeRingsList(AureoleRange.GetEnabledRingsList(), maxIndex)
    local seen = {}
    for _, i in ipairs(a) do seen[i] = true end
    for _, i in ipairs(b) do seen[i] = true end
    local out = {}
    for i = 1, maxIndex do
        if seen[i] then out[#out + 1] = i end
    end
    set.rings = out
end

function AureoleRange.RemoveCurrentSelectionFromRingSet(setIndex)
    AureoleRange.EnsureRingSets()
    local set = AureoleRange.sv.ringSets[setIndex]
    if not set then return end
    local maxIndex = #AureoleRange.sv.presets
    local a        = NormalizeRingsList(set.rings, maxIndex)
    local b        = NormalizeRingsList(AureoleRange.GetEnabledRingsList(), maxIndex)
    local remove = {}
    for _, i in ipairs(b) do remove[i] = true end
    local out = {}
    for _, i in ipairs(a) do
        if not remove[i] then out[#out + 1] = i end
    end
    set.rings = out
end

-- ===== 3D ring controls =====
function AureoleRange.EnsureItems()
    local sv    = AureoleRange.sv
    local items = AureoleRange.items
    if #items >= #sv.presets then return end
    if not AureoleRangeRoot then return end
    for i = #items + 1, #sv.presets do
        local id      = "AureoleRangeWorldAura_" .. tostring(i)
        local control = WM:CreateControl(id, AureoleRangeRoot, CT_TEXTURE)
        control:Create3DRenderSpace()
        control:Set3DRenderSpaceOrigin(0, 0, 0)
        control:Set3DRenderSpaceUsesDepthBuffer(sv.useDepthBuffer == true)
        control:Set3DRenderSpaceOrientation(math.pi / 2, 0, 0)
        control:SetTexture(sv.texture)
        control:SetHidden(true)
        items[i] = control
    end
end

function AureoleRange.ApplyVisibility()
    local sv    = AureoleRange.sv
    local items = AureoleRange.items
    AureoleRange.EnsureItems()
    for i, p in ipairs(sv.presets) do
        local c = items[i]
        if c then
            c:SetHidden(not (sv.enabled and p.enabled))
        end
    end
end

function AureoleRange.ApplyAppearance()
    local sv    = AureoleRange.sv
    local items = AureoleRange.items
    AureoleRange.EnsureItems()
    for i, p in ipairs(sv.presets) do
        local c = items[i]
        if c and sv.enabled and p.enabled then
            c:SetTexture(sv.texture)
            c:Set3DRenderSpaceUsesDepthBuffer(sv.useDepthBuffer == true)
            local rM            = Clamp(tonumber(p.radiusMeters) or 28, 1, 200)
            local diameterUnits = rM * 2
            c:Set3DLocalDimensions(diameterUnits, diameterUnits)
            local col   = p.color or {r=1,g=1,b=1}
            local baseA = tonumber(p.intensity) or 0.55
            local a     = AureoleRange.GetPulseAlpha(baseA)
            c:SetColor(col.r or 1, col.g or 1, col.b or 1, a)
        end
    end
end

function AureoleRange.UpdatePosition()
    local sv    = AureoleRange.sv
    local items = AureoleRange.items
    if not sv.enabled then return end
    if not (getUnitRawWorldPosition and worldPositionToGuiRender3DPosition) then return end
    local _, wx, wy, wz = getUnitRawWorldPosition("player")
    if not wx then return end
    local gx, gy, gz = worldPositionToGuiRender3DPosition(wx, wy, wz)
    if not gx then return end
    local baseH = tonumber(sv.heightOffset) or 0.03
    local step  = tonumber(sv.stackingStep) or 0.004
    for i, p in ipairs(sv.presets) do
        local c = items[i]
        if c and p.enabled then
            c:Set3DRenderSpaceOrigin(gx, gy + baseH + (i - 1) * step, gz)
        end
    end
end

function AureoleRange.StartUpdate()
    EM:UnregisterForUpdate(ADDON_NAME .. "_Update")
    if not AureoleRange.sv.enabled then return end
    local interval = tonumber(AureoleRange.sv.updateIntervalMs) or 20
    if interval < 10 then interval = 10 end
    EM:RegisterForUpdate(ADDON_NAME .. "_Update", interval, function()
        AureoleRange.UpdatePosition()
        if AureoleRange.sv.pulse.enabled then
            AureoleRange.ApplyAppearance()
        end
    end)
end

function AureoleRange.StopUpdate()
    EM:UnregisterForUpdate(ADDON_NAME .. "_Update")
end

function AureoleRange.ApplyAll()
    AureoleRange.ApplyVisibility()
    if not AureoleRange.sv.enabled then
        AureoleRange.StopUpdate()
        return
    end
    AureoleRange.ApplyAppearance()
    AureoleRange.UpdatePosition()
    AureoleRange.StartUpdate()
end

-- ===== Keybind Toggle Function =====
function AureoleRange.ToggleVisibility()
    AureoleRange.sv.enabled = not AureoleRange.sv.enabled
    d("|c00ff00[AureoleRange]|r " .. (AureoleRange.sv.enabled and "ВКЛ" or "ВЫКЛ"))
    AureoleRange.ApplyAll()
end

-- ===== Initialize =====
local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    
    AureoleRange.sv = ZO_SavedVars:NewAccountWide(
        "AureoleRange_SV", 1, nil, AureoleRange.defaults, GetWorldName()
    )
    AureoleRange.pulseStartMs = GetGameTimeMilliseconds()
    AureoleRange.items        = {}
    AureoleRange.EnsureRingSets()
    
    local fragment = ZO_SimpleSceneFragment:New(AureoleRangeRoot)
    SM:GetScene("hud"):AddFragment(fragment)
    SM:GetScene("hudui"):AddFragment(fragment)
    
    AureoleRange_Settings.BuildMenu()
    SLASH_COMMANDS["/aureolerange"] = function() AureoleRange.OpenSettingsPanel() end
    SLASH_COMMANDS["/arsettings"]   = function() AureoleRange.OpenSettingsPanel() end
    
    AureoleRange.ApplyAll()
end

EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)