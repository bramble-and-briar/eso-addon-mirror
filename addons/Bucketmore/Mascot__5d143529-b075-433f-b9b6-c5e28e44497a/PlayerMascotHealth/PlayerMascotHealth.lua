-- PlayerMascotHealth v1.0.0
-- Shows one of three PNG images depending on the PLAYER's own HP. Own HP only (no enemy/NPC/target HP).
-- No OnUpdate / no polling: HP is read on EVENT_POWER_UPDATE (player + health only) and a few
-- rare lifecycle events. The texture is only swapped when the state actually changes.

local ADDON      = "PlayerMascotHealth"
local VERSION    = "1.0.0"
local SV_NAME    = "PlayerMascotHealth_SV"
local SV_VERSION = 1

-- Phase 1 (PS5) verified: PNG + alpha display via CT_TEXTURE:SetTexture("<AddOn>/tex/<file>.png")
local TEX_DIR = "PlayerMascotHealth/tex/"
local TEX = {
    NORMAL   = TEX_DIR .. "NORMAL.png",
    CAUTION  = TEX_DIR .. "CAUTION.png",
    CRITICAL = TEX_DIR .. "CRITICAL.png",
}

local ASPECT    = 2                      -- image is 256x512 -> height = width * 2
local SIZE_MIN, SIZE_MAX, SIZE_STEP = 128, 768, 8   -- size = displayed HEIGHT in UI px
local NORMAL_MIN, NORMAL_MAX = 20, 95
local CAUTION_MIN, CAUTION_MAX = 5, 90
local GAP       = 5                      -- cautionStart must stay at least this far below normalStart

local DEFAULTS = {
    enabled     = true,
    x           = 20,
    y           = 240,
    size        = 256,
    normalStart = 70,    -- HP% >= this            -> NORMAL
    cautionStart = 30,   -- HP% >= this (< normal) -> CAUTION, below -> CRITICAL
}

local sv                -- saved variables (sanitized)
local tlw, tex          -- top level window / texture control
local currentState      -- last computed state ("NORMAL"/"CAUTION"/"CRITICAL")
local shownState        -- state whose texture is currently set on the control

---------------------------------------------------------------------------
-- Settings sanitising (bad / old / hand-edited values must never raise errors)
---------------------------------------------------------------------------
local function Num(v, lo, hi, fallback)
    if type(v) ~= "number" or v ~= v then return fallback end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function Sanitize()
    if type(sv.enabled) ~= "boolean" then sv.enabled = DEFAULTS.enabled end
    sv.x    = Num(sv.x, 0, 8000, DEFAULTS.x)
    sv.y    = Num(sv.y, 0, 8000, DEFAULTS.y)
    sv.size = Num(sv.size, SIZE_MIN, SIZE_MAX, DEFAULTS.size)
    sv.normalStart = Num(sv.normalStart, NORMAL_MIN, NORMAL_MAX, DEFAULTS.normalStart)
    local cautionMax = math.min(CAUTION_MAX, sv.normalStart - GAP)
    sv.cautionStart = Num(sv.cautionStart, CAUTION_MIN, cautionMax, math.min(DEFAULTS.cautionStart, cautionMax))
end

---------------------------------------------------------------------------
-- HP state (pure calculation, no UI)
---------------------------------------------------------------------------
-- Integer-safe: compares cur*100 with max*threshold, so 70% / 30% are exact boundaries.
local function CalcState(cur, max)
    if type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then return nil end
    if cur < 0 then cur = 0 end
    local scaled = cur * 100
    if scaled >= max * sv.normalStart  then return "NORMAL"  end
    if scaled >= max * sv.cautionStart then return "CAUTION" end
    return "CRITICAL"
end

---------------------------------------------------------------------------
-- Image switching (no HP logic)
---------------------------------------------------------------------------
local function ApplyTexture()
    if not tex or not currentState then return end
    if shownState == currentState then return end   -- same state: never reload
    shownState = currentState
    tex:SetTexture(TEX[currentState])
end

local function ApplyLayout()
    if not tlw or not tex then return end
    local h = sv.size
    local w = h / ASPECT
    local x, y = sv.x, sv.y
    local sw, sh = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    if sw and sw > 0 then x = math.min(x, math.max(0, sw - w)) end
    if sh and sh > 0 then y = math.min(y, math.max(0, sh - h)) end
    tlw:ClearAnchors()
    tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    tlw:SetDimensions(w, h)
    tex:SetHidden(not sv.enabled)
    if sv.enabled then ApplyTexture() end
end

---------------------------------------------------------------------------
-- HP reading
---------------------------------------------------------------------------
local function UpdateState(cur, max)
    local s = CalcState(cur, max)
    if s and s ~= currentState then
        currentState = s
        if sv.enabled then ApplyTexture() end
    end
end

-- Full re-read: login / zone change / respawn / death / revive (rare events)
local function ReadHealthNow()
    local cur, max, effMax = GetUnitPower("player", POWERTYPE_HEALTH)
    if type(effMax) == "number" and effMax > 0 then max = effMax end
    UpdateState(cur, max)
end

local function OnPowerUpdate(_, _, _, _, powerValue, powerMax, powerEffectiveMax)
    local max = powerMax
    if type(powerEffectiveMax) == "number" and powerEffectiveMax > 0 then max = powerEffectiveMax end
    UpdateState(powerValue, max)
end

local function OnLifecycle()
    ReadHealthNow()
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local function BuildUI()
    tlw = WINDOW_MANAGER:CreateTopLevelWindow(ADDON .. "_TLW")
    tlw:SetMouseEnabled(false)
    tlw:SetMovable(false)

    tex = WINDOW_MANAGER:CreateControl(ADDON .. "_Tex", tlw, CT_TEXTURE)
    tex:SetAnchorFill(tlw)

    -- Show only on the HUD (hide in menus). If this fails the image simply stays visible everywhere.
    pcall(function()
        local fragment = ZO_SimpleSceneFragment:New(tlw)
        HUD_SCENE:AddFragment(fragment)
        HUD_UI_SCENE:AddFragment(fragment)
    end)
end

---------------------------------------------------------------------------
-- Settings panel (LibAddonMenu-2.0 is OPTIONAL: without it the defaults are used)
---------------------------------------------------------------------------
local function BuildSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = ADDON .. "_Panel"
    local panel = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "PlayerMascotHealth",
        displayName = "PlayerMascotHealth",
        author = "PlayerMascotHealth project",
        version = VERSION,
    })

    local function Refresh()
        pcall(function() CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel) end)
    end

    local sw = math.max(200, math.floor(GuiRoot:GetWidth() or 1920))
    local sh = math.max(200, math.floor(GuiRoot:GetHeight() or 1080))

    LAM:RegisterOptionControls(panelName, {
        {
            type = "checkbox", name = "Show Mascot (表示)",
            getFunc = function() return sv.enabled end,
            setFunc = function(v) sv.enabled = v and true or false; ApplyLayout() end,
            default = DEFAULTS.enabled,
        },
        {
            type = "slider", name = "Position X (横位置)", min = 0, max = sw, step = 10,
            getFunc = function() return sv.x end,
            setFunc = function(v) sv.x = Num(v, 0, 8000, DEFAULTS.x); ApplyLayout() end,
            default = DEFAULTS.x,
        },
        {
            type = "slider", name = "Position Y (縦位置)", min = 0, max = sh, step = 10,
            getFunc = function() return sv.y end,
            setFunc = function(v) sv.y = Num(v, 0, 8000, DEFAULTS.y); ApplyLayout() end,
            default = DEFAULTS.y,
        },
        {
            type = "slider", name = "Size (大きさ)", min = SIZE_MIN, max = SIZE_MAX, step = SIZE_STEP,
            getFunc = function() return sv.size end,
            setFunc = function(v) sv.size = Num(v, SIZE_MIN, SIZE_MAX, DEFAULTS.size); ApplyLayout() end,
            default = DEFAULTS.size,
        },
        {
            type = "slider", name = "NORMAL from HP % (通常)", min = NORMAL_MIN, max = NORMAL_MAX, step = 5,
            getFunc = function() return sv.normalStart end,
            setFunc = function(v)
                sv.normalStart = Num(v, NORMAL_MIN, NORMAL_MAX, DEFAULTS.normalStart)
                Sanitize()          -- pulls cautionStart down if it would overlap
                ReadHealthNow(); Refresh()
            end,
            default = DEFAULTS.normalStart,
        },
        {
            type = "slider", name = "CAUTION from HP % (注意)", min = CAUTION_MIN, max = CAUTION_MAX, step = 5,
            getFunc = function() return sv.cautionStart end,
            setFunc = function(v)
                sv.cautionStart = Num(v, CAUTION_MIN, CAUTION_MAX, DEFAULTS.cautionStart)
                Sanitize()          -- keeps cautionStart <= normalStart - GAP
                ReadHealthNow(); Refresh()
            end,
            default = DEFAULTS.cautionStart,
        },
    })
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
local function OnAddOnLoaded(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    local ok, err = pcall(function()
        local namespace = GetWorldName and GetWorldName() or nil
        sv = ZO_SavedVars:NewAccountWide(SV_NAME, SV_VERSION, namespace, DEFAULTS)
        Sanitize()

        BuildUI()
        ApplyLayout()

        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_POWER_UPDATE, OnPowerUpdate)
        EVENT_MANAGER:AddFilterForEvent(ADDON, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
        EVENT_MANAGER:AddFilterForEvent(ADDON, EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, POWERTYPE_HEALTH)

        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED,    OnLifecycle)
        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_DEAD,         OnLifecycle)
        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ALIVE,        OnLifecycle)
        EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_REINCARNATED, OnLifecycle)
    end)
    if not ok then
        d("[PlayerMascotHealth] init error: " .. tostring(err))   -- one line, only on failure
        return
    end

    -- Settings are optional; a failure here must not stop the mascot itself.
    local sok, serr = pcall(BuildSettings)
    if not sok then d("[PlayerMascotHealth] settings unavailable: " .. tostring(serr)) end
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
