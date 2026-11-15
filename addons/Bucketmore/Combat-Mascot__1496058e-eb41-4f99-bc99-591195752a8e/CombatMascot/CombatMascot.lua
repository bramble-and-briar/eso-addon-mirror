-- CombatMascot v0.2.0 (stage 1)
-- Independent addon (no dependency on PlayerMascotHealth; LibAddonMenu-2.0 is OPTIONAL: without it the
-- defaults are used and the mascot works as usual). Event driven: no OnUpdate, no polling, textures are loaded
-- once and reused. One timer per reaction (token-guarded). While a reaction is playing, new in-game events are
-- ignored (no queue, no interrupt: priorities come later). The waiting picture (idle) is NOT implemented yet.

local ADDON    = "CombatMascot"
local PATH     = "CombatMascot/"
local VERSION  = "0.2.0-stage1"
local SV_NAME, SV_VERSION = "CombatMascot_SV", 1

------------------------------------------------------------------
-- Constants
------------------------------------------------------------------
local FPS       = 8                       -- 4 frames -> 0.5 s of animation
local ANIM_MS   = 500                     -- frames / FPS
local HOLD_MS   = 800                     -- last frame is held this long, then the reaction ends
local TOTAL_MS  = ANIM_MS + HOLD_MS       -- 1.3 s per reaction

local SIZE_MIN, SIZE_MAX, SIZE_STEP = 128, 768, 8   -- displayed height in UI px (cell is square)

-- every sheet: 512x512 = 2 x 2 cells of 256x256, 4 frames, left->right, top->bottom
local SHEETS = {
    attack = { file = "CM_ATTACK.dds", cols = 2, rows = 2 },
    skill  = { file = "CM_SKILL.dds",  cols = 2, rows = 2 },
    ult    = { file = "CM_ULT.dds",    cols = 2, rows = 2 },
    hit    = { file = "CM_HIT.dds",    cols = 2, rows = 2 },
    kill   = { file = "CM_KILL.dds",   cols = 2, rows = 2 },
}
local ORDER = { "attack", "skill", "ult", "hit", "kill" }

------------------------------------------------------------------
-- Saved settings (own data only)
------------------------------------------------------------------
local function ScreenSize()
    local sw, sh = 1920, 1080
    pcall(function()
        local w, h = GuiRoot:GetWidth(), GuiRoot:GetHeight()
        if type(w) == "number" and w > 0 then sw = w end
        if type(h) == "number" and h > 0 then sh = h end
    end)
    return sw, sh
end

local DEFAULTS
do
    local sw, sh = ScreenSize()
    DEFAULTS = {
        enabled = true,
        size    = 256,
        x       = math.max(0, math.floor(sw - 256 - 120)),   -- right side (PlayerMascotHealth sits at the left)
        y       = math.floor(sh * 0.35),
    }
end

local sv = {}                   -- saved variables (sanitized); a plain table copy of DEFAULTS if saving is unavailable

local function Num(v, lo, hi, fallback)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return fallback end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function Sanitize()
    if type(sv) ~= "table" then sv = {} end
    if type(sv.enabled) ~= "boolean" then sv.enabled = DEFAULTS.enabled end
    sv.x    = Num(sv.x, 0, 8000, DEFAULTS.x)
    sv.y    = Num(sv.y, 0, 8000, DEFAULTS.y)
    sv.size = Num(sv.size, SIZE_MIN, SIZE_MAX, DEFAULTS.size)
end

------------------------------------------------------------------
-- Display: one top-level window; every reaction texture fills it (common position / size)
------------------------------------------------------------------
local tlw                       -- top-level window
local E = {}                    -- E[key] = { ctrl, tl, cols, rows }
local hudFragment               -- shows the window on the HUD only (nil if it could not be created)
local preview = false           -- runtime only, never saved: keep visible in menus
local busyUntil = 0             -- game time (ms) until which a reaction is playing
local cur                       -- key of the reaction playing now
local token = 0                 -- play counter: a stale end-timer / stale OnStop is ignored

local function ApplyLayout()
    if not tlw then return end
    local h = sv.size
    local w = h                                           -- square 256x256 cells
    local x, y = sv.x, sv.y
    local sw, sh = ScreenSize()
    x = math.min(x, math.max(0, sw - w))
    y = math.min(y, math.max(0, sh - h))
    pcall(function()
        tlw:ClearAnchors()
        tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
        tlw:SetDimensions(w, h)
    end)
end

local function FirstCell(e)
    pcall(e.ctrl.SetTextureCoords, e.ctrl, 0, 1 / e.cols, 0, 1 / e.rows)
end

-- one-shot finished: keep showing the LAST cell (never the whole sheet, never blank)
local function HoldLastFrame(e)
    pcall(e.ctrl.SetTextureCoords, e.ctrl, (e.cols - 1) / e.cols, 1, (e.rows - 1) / e.rows, 1)
end

-- Provisional preview picture (until the waiting picture exists): first frame of the attack sheet.
local function ShowPlaceholder()
    local e = E.attack
    if not e or cur ~= nil or not preview or not sv.enabled then return end
    FirstCell(e)
    pcall(e.ctrl.SetHidden, e.ctrl, false)
end

local function EndReaction()
    local k = cur
    cur = nil
    busyUntil = 0
    if k then
        local e = E[k]
        if e then
            pcall(e.tl.Stop, e.tl)
            pcall(e.ctrl.SetHidden, e.ctrl, true)
        end
    end
    ShowPlaceholder()
end

local function HidePlaceholder()
    local e = E.attack
    if e and cur == nil then pcall(e.ctrl.SetHidden, e.ctrl, true) end
end

local function Build(key)
    local sh = SHEETS[key]
    local ok = pcall(function()
        local c = WINDOW_MANAGER:CreateControl("CM_Tex_" .. key, tlw, CT_TEXTURE)
        c:SetAnchorFill(tlw)
        c:SetTexture(PATH .. sh.file)                     -- loaded once, reused for every play
        c:SetHidden(true)
        local tl = ANIMATION_MANAGER:CreateTimeline()
        local anim = tl:InsertAnimation(ANIMATION_TEXTURE, c, 0)
        anim:SetImageData(sh.cols, sh.rows)
        anim:SetFramerate(FPS)
        anim:SetDuration(ANIM_MS)
        local e = { ctrl = c, tl = tl, cols = sh.cols, rows = sh.rows }
        tl:SetHandler("OnStop", function(_, completedPlaying)
            if cur ~= key or completedPlaying == false then return end   -- stopped by us, not finished
            HoldLastFrame(e)
        end)
        E[key] = e
    end)
    return ok
end

-- force = true: used by the settings test play (replaces a reaction that is playing)
local function Play(key, force)
    local e = E[key]
    if not e or not sv.enabled then return end
    local now = GetGameTimeMilliseconds()
    if not force and now < busyUntil then return end      -- playing: ignore (no queue)
    if cur then                                           -- forced replacement
        local old = E[cur]
        if old then
            pcall(old.tl.Stop, old.tl)
            pcall(old.ctrl.SetHidden, old.ctrl, true)
        end
        cur = nil
    end
    if key ~= "attack" then                               -- the provisional preview picture shares the attack control
        local pe = E.attack
        if pe then pcall(pe.ctrl.SetHidden, pe.ctrl, true) end
    end
    token = token + 1
    local my = token
    cur = key
    busyUntil = now + TOTAL_MS
    local ok = pcall(function()
        FirstCell(e)
        e.ctrl:SetHidden(false)
        e.tl:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT)
        e.tl:PlayFromStart()
    end)
    if not ok then EndReaction() return end
    zo_callLater(function() if my == token then EndReaction() end end, TOTAL_MS)
end

------------------------------------------------------------------
-- Events (UNCHANGED from v0.1.0)
------------------------------------------------------------------
local ULT_SLOT = 8
if ACTION_BAR_ULTIMATE_SLOT_INDEX ~= nil then
    ULT_SLOT = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1         -- read at run time (PS5: constant 7 -> slot 8)
end

-- slot 1/2 = weapon attack input (light/heavy mapping not confirmed; shared reaction),
-- slots 3 .. ULT_SLOT-1 = skills, ULT_SLOT = ultimate
local function OnSlotUsed(_, slotNum)
    if slotNum == 1 or slotNum == 2 then Play("attack") return end
    if slotNum == ULT_SLOT then Play("ult") return end
    if slotNum ~= nil and slotNum >= 3 and slotNum < ULT_SLOT then Play("skill") end
end

-- Damage taken: direct damage whose source is not the player. DoT / shield absorption are NOT connected
-- (unverified). Self events reach this registration as well, so source == player is excluded.
local function OnCombat(_, result, isError, _, _, _, _, sourceType)
    if isError then return end
    if result ~= ACTION_RESULT_DAMAGE and result ~= ACTION_RESULT_CRITICAL_DAMAGE then return end
    if sourceType == COMBAT_UNIT_TYPE_PLAYER then return end
    Play("hit")
end

local function RegisterEvents()
    pcall(function()
        EVENT_MANAGER:RegisterForEvent(ADDON .. "_Slot", EVENT_ACTION_SLOT_ABILITY_USED, OnSlotUsed)
    end)
    if REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE ~= nil and COMBAT_UNIT_TYPE_PLAYER ~= nil then
        pcall(function()
            EVENT_MANAGER:RegisterForEvent(ADDON .. "_Hit", EVENT_COMBAT_EVENT, OnCombat)
            EVENT_MANAGER:AddFilterForEvent(ADDON .. "_Hit", EVENT_COMBAT_EVENT,
                REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        end)
    end
    -- Enemy kill: detection method not decided yet -> no event is connected (asset + Play("kill") are ready).
end

------------------------------------------------------------------
-- Preview (runtime only): the window stays visible in menus so position / size can be adjusted
------------------------------------------------------------------
local function SetPreview(on)
    preview = on and true or false
    if hudFragment and tlw then
        pcall(function()
            if preview then
                HUD_SCENE:RemoveFragment(hudFragment)
                HUD_UI_SCENE:RemoveFragment(hudFragment)
                tlw:SetHidden(false)
            else
                HUD_SCENE:AddFragment(hudFragment)
                HUD_UI_SCENE:AddFragment(hudFragment)
                local inHud = SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
                tlw:SetHidden(not inHud)
            end
        end)
    end
    if preview then ShowPlaceholder() else HidePlaceholder() end
end

------------------------------------------------------------------
-- Settings panel (LibAddonMenu-2.0 is OPTIONAL)
------------------------------------------------------------------
local function ResetToDefaults()
    sv.enabled, sv.x, sv.y, sv.size = DEFAULTS.enabled, DEFAULTS.x, DEFAULTS.y, DEFAULTS.size
    ApplyLayout()
end

local TEST_CHOICES = {
    "-",
    "えいっ！ (Attack)",
    "魔法発動！ (Skill)",
    "どっか〜ん！ (Ultimate)",
    "ふぎゃっ！ (Hit)",
    "やったね！ (Kill)",
}
local TEST_KEY = {
    [TEST_CHOICES[2]] = "attack", [TEST_CHOICES[3]] = "skill", [TEST_CHOICES[4]] = "ult",
    [TEST_CHOICES[5]] = "hit",    [TEST_CHOICES[6]] = "kill",
}

local function BuildSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end                            -- no LAM: defaults are used, nothing else to do

    local panelName = ADDON .. "_Panel"
    local panel = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "CombatMascot",
        displayName = "CombatMascot",
        author = "CombatMascot project",
        version = VERSION,
    })

    local function Refresh()
        pcall(function() CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel) end)
    end

    local sw, sh = ScreenSize()
    sw, sh = math.max(200, math.floor(sw)), math.max(200, math.floor(sh))

    LAM:RegisterOptionControls(panelName, {
        {
            type = "checkbox", name = "Show Mascot (表示)",
            getFunc = function() return sv.enabled end,
            setFunc = function(v) sv.enabled = v and true or false; ApplyLayout() end,
            default = DEFAULTS.enabled,
        },
        {
            type = "checkbox", name = "Preview while in menus (プレビュー表示)",
            tooltip = "ON: the mascot stays visible while this settings screen is open, so you can place it. Turns OFF again at the next login.",
            getFunc = function() return preview end,
            setFunc = function(v) SetPreview(v) end,
            default = false,
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
            type = "button", name = "Reset to defaults (初期値に戻す)",
            tooltip = "Resets show / position / size to the default values.",
            func = function() ResetToDefaults(); Refresh() end,
        },
        {
            type = "dropdown", name = "Test play (演出テスト再生)",
            tooltip = "Plays the chosen reaction once (the preview is switched on automatically so it is visible here).",
            choices = TEST_CHOICES,
            getFunc = function() return TEST_CHOICES[1] end,
            setFunc = function(choice)
                local key = TEST_KEY[choice]
                if key then
                    SetPreview(true)
                    Play(key, true)
                end
                Refresh()
            end,
            default = TEST_CHOICES[1],
        },
    })
end

------------------------------------------------------------------
-- Start-up
------------------------------------------------------------------
local started = false

local function BuildUI()
    local ok = pcall(function()
        tlw = WINDOW_MANAGER:CreateTopLevelWindow("CM_TLW")
        tlw:SetMouseEnabled(false)
        tlw:SetMovable(false)
    end)
    if not ok or not tlw then tlw = nil return false end
    ApplyLayout()
    for _, key in ipairs(ORDER) do Build(key) end         -- one failing sheet does not stop the others
    -- Show only on the HUD (hide in menus). If this fails the window simply stays visible everywhere.
    pcall(function()
        hudFragment = ZO_SimpleSceneFragment:New(tlw)
        HUD_SCENE:AddFragment(hudFragment)
        HUD_UI_SCENE:AddFragment(hudFragment)
    end)
    return true
end

local function OnPlayerActivated()
    if started then return end
    started = true
    EVENT_MANAGER:UnregisterForEvent(ADDON .. "_Act", EVENT_PLAYER_ACTIVATED)
    if not BuildUI() then return end
    RegisterEvents()
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON .. "_Load", EVENT_ADD_ON_LOADED)

    -- saved settings: any failure or invalid value falls back to the defaults
    local ok = pcall(function()
        local namespace = GetWorldName and GetWorldName() or nil
        sv = ZO_SavedVars:NewAccountWide(SV_NAME, SV_VERSION, namespace, DEFAULTS)
    end)
    if not ok or type(sv) ~= "table" then
        sv = { enabled = DEFAULTS.enabled, x = DEFAULTS.x, y = DEFAULTS.y, size = DEFAULTS.size }
    end
    Sanitize()

    EVENT_MANAGER:RegisterForEvent(ADDON .. "_Act", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    pcall(BuildSettings)                                  -- a settings failure never stops the mascot
end

EVENT_MANAGER:RegisterForEvent(ADDON .. "_Load", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
