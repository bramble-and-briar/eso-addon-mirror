PocketCritters = PocketCritters or {}
local PP = PocketCritters

PP.name = "PocketCritters"
PP.version = "3.0.4"

local TEXTURE_PATH = "PocketCritters/textures/critter_%s%s.dds"
local HD_ABOVE = 128
local SHEET_COLS, SHEET_ROWS = 4, 8
local SKINS = { "hellwuff", "tsardarashi", "hisani", "azsu", "tsaji", "brown" }
local SKIN_LABELS = { hellwuff = "Hellwuff", tsardarashi = "Tsardarashi", hisani = "Hisani", azsu = "Azsu", tsaji = "Tsaji", brown = "Cocoa" }
local SKIN_ALIASES = { cocoa = "brown" }
local BASE_SIZE = 96
local MIN_SCALE, MAX_SCALE = 50, 300

local DEFAULTS = {
    skin = "hellwuff",
    scale = 100,
    x = nil,
    y = nil,
    locked = false,
    hidden = false,
    quiet = false,
    sleepAfter = 120,
    pats = 0,
    fetches = 0,
    peek = true,
    peekLift = 0,
    peekShift = 0,
}

local ANIMS = {
    idle  = { row = 0, frames = { 0, 1, 2, 1, 0, 1, 2, 1, 0, 3 }, fps = 3 },
    wag   = { row = 1, frames = { 0, 1, 2, 3 }, fps = 8 },
    sleep = { row = 2, frames = { 0, 1, 2, 3 }, fps = 1.5 },
    hide  = { row = 3, frames = { 0, 1, 0, 1, 0, 1, 0, 1, 2, 2, 2, 3 }, fps = 6 },
    run   = { row = 4, frames = { 0, 1, 2, 3 }, fps = 10 },
    sad   = { row = 5, frames = { 0, 1, 2, 3 }, fps = 2 },
    alert = { row = 6, frames = { 0, 1, 2, 3 }, fps = 4 },
    pat   = { row = 7, frames = { 2, 3 }, fps = 4 },
}

local REACTIONS = {
    wag     = { anim = "wag",   duration = 2.5 },
    zoomies = { anim = "run",   duration = 3.5, zoom = true, sparkle = true },
    pat     = { anim = "pat",   duration = 1.8, heart = true },
    wake    = { anim = "alert", duration = 1.2 },
}

local state = {
    inCombat = false,
    isDead = false,
    bossNearby = false,
    lastActive = 0,
    lastPos = nil,
    reaction = nil,
    reactionEnd = 0,
    reactionStart = 0,
    anim = nil,
    animStart = 0,
    mouseDownX = nil,
    mouseDownY = nil,
    nextSlowCheck = 0,
    forceMood = nil,
    forceUntil = 0,
}

local sv
local window, pupTex, heartTex, sparkleTex, ballTex, fragment

local function Say(msg)
    d("|cFF8FC8[Pocket Critters]|r " .. msg)
end

local function Now()
    return GetFrameTimeSeconds()
end

local function SetFrame(tex, row, col, flip)
    local left = col / SHEET_COLS
    local right = (col + 1) / SHEET_COLS
    local top = row / SHEET_ROWS
    local bottom = (row + 1) / SHEET_ROWS
    if flip then
        tex:SetTextureCoords(right, left, top, bottom)
    else
        tex:SetTextureCoords(left, right, top, bottom)
    end
end

local function IsValidSkin(name)
    for _, skin in ipairs(SKINS) do
        if skin == name then return true end
    end
    return false
end

local function GetPlayerPos()
    if GetUnitRawWorldPosition then
        local zoneId, x, y, z = GetUnitRawWorldPosition("player")
        if x then return zoneId, x, y, z end
    end
    local x, y = GetMapPlayerPosition("player")
    return 0, (x or 0) * 100000, 0, (y or 0) * 100000
end

local function MarkActive()
    state.lastActive = Now()
end

local function CurrentMood()
    local t = Now()
    if state.forceMood then
        if t < state.forceUntil then return state.forceMood end
        state.forceMood = nil
        MarkActive()
    end
    if state.isDead then return "sad" end
    if state.bossNearby then return "hide" end
    if state.reaction and t < state.reactionEnd then
        return REACTIONS[state.reaction].anim, state.reaction
    end
    state.reaction = nil
    if state.inCombat then return "alert" end
    if sv and (t - state.lastActive) >= sv.sleepAfter then return "sleep" end
    return "idle"
end

function PP.React(name)
    local r = REACTIONS[name]
    if not r then return end
    local t = Now()
    state.reaction = name
    state.reactionStart = t
    state.reactionEnd = t + r.duration
end

local function CheckBosses()
    local found = false
    for i = 1, (MAX_BOSSES or 6) do
        local tag = "boss" .. i
        if DoesUnitExist(tag) and not IsUnitDead(tag) then
            found = true
            break
        end
    end
    state.bossNearby = found
end

local function CheckMovement()
    local zoneId, x, y, z = GetPlayerPos()
    local last = state.lastPos
    if last then
        local moved = zoneId ~= last[1]
            or math.abs(x - last[2]) > 50
            or math.abs(y - last[3]) > 50
            or math.abs(z - last[4]) > 50
        if moved then
            local wasAsleep = (Now() - state.lastActive) >= sv.sleepAfter
            MarkActive()
            if wasAsleep and not state.inCombat and not state.isDead then
                PP.React("wake")
            end
        end
    end
    state.lastPos = { zoneId, x, y, z }
end

local MOUTH = {
    hellwuff = { 0.333, 0.457 }, tsardarashi = { 0.387, 0.336 }, hisani = { 0.365, 0.383 },
    azsu = { 0.349, 0.364 }, tsaji = { 0.368, 0.399 }, brown = { 0, 0.42 },
}
local FETCH_FLIGHT = 0.8
local FETCH_WAIT = 0.35
local FETCH_SPEED = 5
local FETCH_GRAB = 0.35
local FETCH_PROUD = 2.2
local BALL_SIZE = 0.16

local function FetchUnsafe()
    return state.isDead or state.bossNearby or state.inCombat
end

local function EndFetch()
    state.fetch = nil
    if ballTex then ballTex:SetHidden(true) end
end

local GROUND_BALL = 0.027 + BALL_SIZE / 2

local function Launch(ballU, ballV, side)
    local mouth = MOUTH[sv.skin] or { 0, 0.42 }
    local stopU = ballU - side * mouth[1]
    local stopV = ballV + GROUND_BALL
    local runTime = math.max(0.4, math.sqrt(stopU * stopU + stopV * stopV) / FETCH_SPEED)
    local t0 = Now()
    local f = { t0 = t0, ballU = ballU, ballV = ballV, stopU = stopU, stopV = stopV, side = side, mouth = mouth }
    f.tChase = t0 + FETCH_WAIT
    f.tGrab = f.tChase + runTime
    f.tCarry = f.tGrab + FETCH_GRAB
    f.tHome = f.tCarry + runTime
    f.tEnd = f.tHome + FETCH_PROUD
    state.fetch = f
    state.reaction = nil
    state.forceMood = nil
    MarkActive()
    if SOUNDS and SOUNDS.DEFAULT_CLICK then PlaySound(SOUNDS.DEFAULT_CLICK) end
    return true
end

local function CanThrow()
    if not sv or not window then return false end
    if state.fetch then return false end
    if sv.hidden then
        Say("Your critter is hidden. Tick \"Show my critter\" to play!")
        return false
    end
    if FetchUnsafe() then
        Say("Not now, it's not safe!")
        return false
    end
    return true
end

local function ScreenSize()
    return (GuiRoot.GetWidth and GuiRoot:GetWidth()) or 1920, (GuiRoot.GetHeight and GuiRoot:GetHeight()) or 1080
end

function PP.ThrowBall()
    if not CanThrow() then return false end
    local size = PP.GetPixelSize()
    local centre = (window:GetLeft() or 0) + size / 2
    local screenW = ScreenSize()
    local dir = (centre < screenW / 2) and 1 or -1
    local target = centre + dir * size * (2 + math.random() * 1.6)
    local margin = size * 0.6
    target = math.max(margin, math.min(screenW - margin, target))
    local ballU = (target - centre) / size
    if math.abs(ballU) < 1 then ballU = dir end
    return Launch(ballU, -GROUND_BALL, ballU > 0 and 1 or -1)
end

function PP.ThrowBallAt(x, y)
    if not CanThrow() then return false end
    local size = PP.GetPixelSize()
    local homeX = (window:GetLeft() or 0) + size / 2
    local homeY = (window:GetTop() or 0) + size
    local screenW, screenH = ScreenSize()
    local side = (x >= homeX) and 1 or -1
    local mouth = MOUTH[sv.skin] or { 0, 0.42 }

    local feetX = math.max(size / 2, math.min(screenW - size / 2, x - side * mouth[1] * size))
    local feetY = math.max(size, math.min(screenH, y + GROUND_BALL * size))
    local ballX = feetX + side * mouth[1] * size
    local ballY = feetY - GROUND_BALL * size
    return Launch((ballX - homeX) / size, (ballY - homeY) / size, side)
end

local function Ease(p) return 1 - (1 - p) * (1 - p) end

local function UpdateFetch(t)
    local f = state.fetch
    if FetchUnsafe() then
        EndFetch()
        return nil
    end
    MarkActive()
    local size = PP.GetPixelSize()
    local ballSize = size * BALL_SIZE
    local restX, restY = f.ballU * size, f.ballV * size
    local anim, cx, cy, flip, heart = "alert", 0, 0, f.side < 0, nil
    local bx, by = restX, restY

    local ft = t - f.t0
    if ft < FETCH_FLIGHT then
        local p = ft / FETCH_FLIGHT
        local sx, sy = f.side * 0.3 * size, -0.5 * size
        bx = sx + (restX - sx) * p
        by = sy + (restY - sy) * p - math.sin(p * math.pi) * size * 1.2
    else
        local bt = ft - FETCH_FLIGHT
        if bt < 0.3 then
            by = restY - math.sin(bt / 0.3 * math.pi) * size * 0.3
        elseif bt < 0.5 then
            by = restY - math.sin((bt - 0.3) / 0.2 * math.pi) * size * 0.1
        end
    end

    if t < f.tChase then
        anim = "alert"
    elseif t < f.tGrab then
        local e = Ease((t - f.tChase) / (f.tGrab - f.tChase))
        anim, cx, cy, flip = "run", f.stopU * size * e, f.stopV * size * e, f.side < 0
    elseif t < f.tCarry then
        anim, cx, cy, flip = "wag", f.stopU * size, f.stopV * size, false
    elseif t < f.tHome then
        local e = 1 - Ease((t - f.tCarry) / (f.tHome - f.tCarry))
        anim, cx, cy, flip = "run", f.stopU * size * e, f.stopV * size * e, f.side > 0
        local facing = flip and -1 or 1
        bx = cx + facing * f.mouth[1] * size
        by = cy - f.mouth[2] * size
    elseif t < f.tEnd then
        anim = "wag"
        bx, by = f.side * size * 0.55, -GROUND_BALL * size
        heart = (t - f.tHome) / FETCH_PROUD
        if not f.counted then
            f.counted = true
            sv.fetches = (sv.fetches or 0) + 1
            if PP.RefreshSettings then PP.RefreshSettings() end
        end
    else
        EndFetch()
        return nil
    end

    ballTex:SetHidden(false)
    ballTex:SetDimensions(ballSize, ballSize)
    ballTex:ClearAnchors()
    ballTex:SetAnchor(CENTER, window, BOTTOM, bx, by)
    return anim, cx, cy, flip, heart
end

local banner, bannerFragment

local function ClickedEmptySpace()
    local over = WINDOW_MANAGER:GetMouseOverControl()
    return over == nil or over == GuiRoot
end

local function OnGlobalMouseUp(_, button)
    if not state.fetchMode then return end
    if SCENE_MANAGER.IsInUIMode and not SCENE_MANAGER:IsInUIMode() then return end
    if not ClickedEmptySpace() then return end
    if button == MOUSE_BUTTON_INDEX_RIGHT then
        PP.StopFetchMode()
    elseif button == MOUSE_BUTTON_INDEX_LEFT then
        local x, y = GetUIMousePosition()
        PP.ThrowBallAt(x, y)
    end
end

function PP.PlaceFetchBanner()
    if not banner then return end
    banner:ClearAnchors()
    if sv.bannerX and sv.bannerY then
        banner:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.bannerX, sv.bannerY)
    else
        banner:SetAnchor(TOP, GuiRoot, TOP, 0, 70)
    end
end

local function CreateFetchMode()
    local wm = WINDOW_MANAGER

    banner = wm:CreateTopLevelWindow("PocketCrittersFetchBanner")
    banner:SetDimensions(440, 56)
    banner:SetMouseEnabled(true)
    banner:SetMovable(true)
    banner:SetClampedToScreen(true)
    banner:SetHidden(true)
    PP.PlaceFetchBanner()
    banner:SetHandler("OnMoveStop", function(self)
        sv.bannerX, sv.bannerY = self:GetLeft(), self:GetTop()
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.bannerX, sv.bannerY)
    end)
    local bg = wm:CreateControl("PocketCrittersFetchBannerBG", banner, CT_TEXTURE)
    bg:SetTexture("PocketCritters/textures/banner.dds")
    bg:SetAnchorFill(banner)
    bg:SetDrawLayer(DL_BACKGROUND)
    local text = wm:CreateControl("PocketCrittersFetchBannerText", banner, CT_LABEL)
    text:SetFont("ZoFontGame")
    text:SetColor(1, 0.94, 0.9, 1)
    text:SetText("Fetch mode! Click to throw")
    text:SetAnchor(LEFT, banner, LEFT, 22, -7)
    text:SetDrawLayer(DL_TEXT)
    local hint = wm:CreateControl("PocketCrittersFetchBannerHint", banner, CT_LABEL)
    hint:SetFont("ZoFontGameSmall")
    hint:SetColor(0.86, 0.76, 0.86, 1)
    hint:SetText("(right-click anywhere to stop, drag me to move)")
    hint:SetAnchor(LEFT, banner, LEFT, 22, 12)
    hint:SetDrawLayer(DL_TEXT)
    local stop = wm:CreateControlFromVirtual("PocketCrittersFetchStop", banner, "ZO_DefaultButton")
    stop:SetDimensions(110, 28)
    stop:SetText("Stop fetch")
    stop:SetAnchor(RIGHT, banner, RIGHT, -16, 0)
    stop:SetHandler("OnClicked", function() PP.StopFetchMode() end)
    bannerFragment = ZO_HUDFadeSceneFragment:New(banner)
end

function PP.IsFetchMode() return state.fetchMode == true end

function PP.StartFetchMode()
    if state.fetchMode then return true end
    if not sv or not window then return false end
    if sv.hidden then
        Say("Your critter is hidden. Tick \"Show my critter\" to play!")
        return false
    end
    if FetchUnsafe() then
        Say("Not now, it's not safe!")
        return false
    end
    if not EVENT_GLOBAL_MOUSE_UP then
        Say("Sorry, fetch mode doesn't work in this game version. Right-click your critter for a quick throw!")
        return false
    end
    if not banner then CreateFetchMode() end
    state.fetchMode = true
    EVENT_MANAGER:RegisterForEvent(PP.name .. "Fetch", EVENT_GLOBAL_MOUSE_UP, OnGlobalMouseUp)
    HUD_SCENE:AddFragment(bannerFragment)
    HUD_UI_SCENE:AddFragment(bannerFragment)
    SCENE_MANAGER:SetInUIMode(true)
    local scene = SCENE_MANAGER:GetCurrentScene()
    if scene == HUD_SCENE or scene == HUD_UI_SCENE then
        banner:SetHidden(false)
    end
    Say("Fetch mode on! Click anywhere to throw. Right-click to stop.")
    if PP.RefreshSettings then PP.RefreshSettings() end
    return true
end

function PP.StopFetchMode(reason)
    if not state.fetchMode then return end
    state.fetchMode = false
    EVENT_MANAGER:UnregisterForEvent(PP.name .. "Fetch", EVENT_GLOBAL_MOUSE_UP)
    HUD_SCENE:RemoveFragment(bannerFragment)
    HUD_UI_SCENE:RemoveFragment(bannerFragment)
    banner:SetHidden(true)
    Say(reason or "Fetch mode off. Good game!")
    if PP.RefreshSettings then PP.RefreshSettings() end
end

function PP.ToggleFetchMode()
    if state.fetchMode then PP.StopFetchMode() else PP.StartFetchMode() end
end

local function OnUpdate()
    if not sv then return end
    local t = Now()

    if t >= state.nextSlowCheck then
        state.nextSlowCheck = t + 1
        CheckMovement()
        CheckBosses()
        if state.inCombat then MarkActive() end
    end

    if state.fetchMode and FetchUnsafe() then
        PP.StopFetchMode("Danger! Fetch mode off.")
    end
    local animName, reactionName, fetchX, fetchY, fetchFlip, fetchHeart
    if state.fetch then
        animName, fetchX, fetchY, fetchFlip, fetchHeart = UpdateFetch(t)
    end
    if not animName then
        animName, reactionName = CurrentMood()
    end
    if animName ~= state.anim then
        state.anim = animName
        state.animStart = t
    end

    local anim = ANIMS[animName]
    local elapsed = t - state.animStart
    local idx = (math.floor(elapsed * anim.fps) % #anim.frames) + 1
    local col = anim.frames[idx]

    local reaction = reactionName and REACTIONS[reactionName]
    local size = PP.GetPixelSize()
    local offsetX, offsetY, flip = 0, 0, false

    if fetchX then
        offsetX, offsetY, flip = fetchX, fetchY, fetchFlip
    elseif reaction and reaction.zoom then
        local rt = t - state.reactionStart
        offsetX = math.sin(rt * 3.2) * size * 0.8
        flip = math.cos(rt * 3.2) < 0
    end

    pupTex:ClearAnchors()
    pupTex:SetAnchor(BOTTOM, window, BOTTOM, offsetX, offsetY)
    SetFrame(pupTex, anim.row, col, flip)
    pupTex:SetHidden(PP.peekHidesHome == true)

    local heartP = fetchHeart
    if not heartP and reaction and reaction.heart then
        heartP = (t - state.reactionStart) / reaction.duration
    end
    if heartP and heartP <= 1 then
        local p = heartP
        heartTex:SetHidden(false)
        heartTex:ClearAnchors()
        heartTex:SetAnchor(BOTTOM, window, TOP, size * 0.25, size * 0.35 - p * size * 0.5)
        heartTex:SetAlpha(1 - p * p)
    else
        heartTex:SetHidden(true)
    end

    if reaction and reaction.sparkle then
        local rt = t - state.reactionStart
        sparkleTex:SetHidden(false)
        sparkleTex:SetAlpha(0.55 + 0.45 * math.sin(rt * 10))
    else
        sparkleTex:SetHidden(true)
    end
end

local function SavePosition()
    sv.x, sv.y = window:GetLeft(), window:GetTop()
    window:ClearAnchors()
    window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.x, sv.y)
end

local function ApplyPosition()
    window:ClearAnchors()
    if sv.x and sv.y then
        window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.x, sv.y)
    else
        window:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, -280, -170)
    end
end

local function ApplySkin()
    local hd = PP.GetPixelSize() > HD_ABOVE
    local path = string.format(TEXTURE_PATH, sv.skin, hd and "_hd" or "")
    pupTex:SetTexture(path)
    sparkleTex:SetTexture(path)

    heartTex:SetTexture(string.format(TEXTURE_PATH, sv.skin, ""))
    SetFrame(heartTex, 7, 0)
    SetFrame(sparkleTex, 7, 1)
end

local function ApplySize()
    local s = PP.GetPixelSize()
    window:SetDimensions(s, s)
    pupTex:SetDimensions(s, s)
    heartTex:SetDimensions(s * 0.35, s * 0.35)
    sparkleTex:SetDimensions(s * 0.9, s * 0.9)
    sparkleTex:ClearAnchors()
    sparkleTex:SetAnchor(CENTER, window, CENTER, 0, -s * 0.15)
    ApplySkin()
end

local function ApplyVisibility()
    if sv.hidden then
        HUD_SCENE:RemoveFragment(fragment)
        HUD_UI_SCENE:RemoveFragment(fragment)
        window:SetHidden(true)
    else
        HUD_SCENE:AddFragment(fragment)
        HUD_UI_SCENE:AddFragment(fragment)
        local scene = SCENE_MANAGER:GetCurrentScene()
        if scene == HUD_SCENE or scene == HUD_UI_SCENE then
            window:SetHidden(false)
        end
    end
end

function PP.Pat()
    sv.pats = (sv.pats or 0) + 1
    MarkActive()
    PP.React("pat")
    if SOUNDS and SOUNDS.DEFAULT_CLICK then PlaySound(SOUNDS.DEFAULT_CLICK) end
    if PP.RefreshSettings then PP.RefreshSettings() end
    if sv.pats % 100 == 0 then
        Say(string.format("%d pats! Your critter loves you so much %s", sv.pats, "<3"))
    end
end

local function CreateWindow()
    local wm = WINDOW_MANAGER
    window = wm:CreateTopLevelWindow("PocketCrittersWindow")
    window:SetClampedToScreen(true)
    window:SetMouseEnabled(true)
    window:SetMovable(not sv.locked)
    window:SetDrawLayer(DL_OVERLAY)

    pupTex = wm:CreateControl("PocketCrittersTexture", window, CT_TEXTURE)
    pupTex:SetDrawLevel(1)
    ballTex = wm:CreateControl("PocketCrittersBall", window, CT_TEXTURE)
    ballTex:SetTexture("PocketCritters/textures/ball.dds")
    ballTex:SetDrawLevel(3)
    ballTex:SetHidden(true)
    sparkleTex = wm:CreateControl("PocketCrittersSparkle", window, CT_TEXTURE)
    sparkleTex:SetHidden(true)
    heartTex = wm:CreateControl("PocketCrittersHeart", window, CT_TEXTURE)
    heartTex:SetHidden(true)

    ApplySize()
    ApplySkin()
    ApplyPosition()

    window:SetHandler("OnMoveStop", SavePosition)
    window:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            state.mouseDownX, state.mouseDownY = GetUIMousePosition()
        end
    end)
    window:SetHandler("OnMouseUp", function(_, button, upInside)
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            if upInside then
                if state.fetchMode then PP.StopFetchMode() else PP.ThrowBall() end
            end
            return
        end
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not upInside or not state.mouseDownX then return end
        local x, y = GetUIMousePosition()
        local dist = math.abs(x - state.mouseDownX) + math.abs(y - state.mouseDownY)
        state.mouseDownX = nil
        if dist < 5 then PP.Pat() end
    end)
    window:SetHandler("OnUpdate", OnUpdate)

    fragment = ZO_HUDFadeSceneFragment:New(window)
    ApplyVisibility()
end

local function OnLoot(_, _, _, _, _, _, isSelf)
    if isSelf and not sv.quiet then
        MarkActive()
        PP.React("wag")
    end
end

local function OnCombatState(_, inCombat)
    state.inCombat = inCombat
    if inCombat then MarkActive() end
end

local function OnDead()
    state.isDead = true
end

local function OnAlive()
    state.isDead = false
    MarkActive()
end

local function OnBigMoment()
    MarkActive()
    PP.React("zoomies")
end

local function OnLevelUp(_, unitTag)
    if unitTag == "player" then OnBigMoment() end
end

local function OnPlayerActivated()
    state.inCombat = IsUnitInCombat("player")
    state.isDead = IsUnitDead("player")
    state.lastPos = nil
    MarkActive()
    CheckBosses()
end

local function RegisterEvents()
    local function Reg(event, fn)

        if event then EVENT_MANAGER:RegisterForEvent(PP.name, event, fn) end
    end
    Reg(EVENT_LOOT_RECEIVED, OnLoot)
    Reg(EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    Reg(EVENT_PLAYER_DEAD, OnDead)
    Reg(EVENT_PLAYER_ALIVE, OnAlive)
    Reg(EVENT_PLAYER_REINCARNATED, OnAlive)
    Reg(EVENT_LEVEL_UPDATE, OnLevelUp)
    Reg(EVENT_CHAMPION_POINT_GAINED, OnBigMoment)
    Reg(EVENT_ACHIEVEMENT_AWARDED, OnBigMoment)
    Reg(EVENT_BOSSES_CHANGED, CheckBosses)
    Reg(EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

local TEST_MOODS = { idle = true, wag = true, zoomies = true, pat = true, sleep = true,
                     hide = true, sad = true, alert = true }

local function ShowHelp()
    Say("Type /critter to open my settings. Chat shortcuts:")
    d("  /critter skin <name>  - hellwuff, tsardarashi, hisani, azsu, tsaji or cocoa")
    d("  /critter scale <50-300> - size in percent (now " .. sv.scale .. "%)")
    d("  /critter lock  or  /critter unlock  - stop or allow dragging")
    d("  /critter hide  or  /critter show")
    d("  /critter reset          - move me back to the default spot")
    d("  /critter quiet          - toggle wagging at loot (now " .. (sv.quiet and "quiet" or "wagging") .. ")")
    d("  /critter nap <seconds>  - idle time before I nap (now " .. sv.sleepAfter .. ")")
    d("  Fetch mode: press Start fetch in the /critter settings, then click anywhere to throw")
    d("  Right-click your critter for a quick throw")
    d("  /critter pats           - how many pats I've had")
    d("  /critter test <mood>    - idle, wag, zoomies, pat, sleep, hide, sad, alert")
    d("  /critter peek           - peeking over the inventory on or off. Also: /critter peek higher, lower, left, right, reset")
end

function PP.TestMood(mood)
    if state.fetch then EndFetch() end
    if state.fetchMode then PP.StopFetchMode() end
    if REACTIONS[mood] then
        state.forceMood = nil
        PP.React(mood)
    else

        state.reaction = nil
        state.forceMood = mood
        state.forceUntil = Now() + 5
    end
end

local function OnSlash(text)
    local args = {}
    for word in string.gmatch(string.lower(text or ""), "%S+") do
        table.insert(args, word)
    end
    local cmd, val = args[1], args[2]

    if not cmd or cmd == "settings" then
        if PP.ToggleSettings then PP.ToggleSettings() else ShowHelp() end
        return
    elseif cmd == "help" then
        ShowHelp()
    elseif cmd == "skin" then
        if val then val = SKIN_ALIASES[val] or val end
        if val and IsValidSkin(val) then
            sv.skin = val
            ApplySkin()
            Say("New look: " .. SKIN_LABELS[val] .. "!")
        else
            Say("Critters: hellwuff, tsardarashi, hisani, azsu, tsaji or cocoa")
        end
    elseif cmd == "scale" or cmd == "size" then
        local n = tonumber((val or ""):gsub("%%", ""), 10)
        if n then
            PP.SetScale(n)
            Say("Scale set to " .. sv.scale .. "%")
        else
            Say("Try /critter scale 150")
        end
    elseif cmd == "lock" or cmd == "unlock" then
        sv.locked = (cmd == "lock")
        window:SetMovable(not sv.locked)
        Say(sv.locked and "I'll stay right here." or "You can drag me around now.")
    elseif cmd == "hide" or cmd == "show" then
        sv.hidden = (cmd == "hide")
        ApplyVisibility()
        if not sv.hidden then Say("I'm back! *wag wag*") end
    elseif cmd == "reset" then
        sv.x, sv.y = nil, nil
        ApplyPosition()
        Say("Back to my usual spot.")
    elseif cmd == "quiet" then
        sv.quiet = not sv.quiet
        Say(sv.quiet and "Okay, I'll only get excited for big moments." or "I'll wag for every bit of loot again!")
    elseif cmd == "nap" then
        local n = tonumber(val)
        if n then
            sv.sleepAfter = math.max(10, math.floor(n))
            Say("I'll nap after " .. sv.sleepAfter .. " seconds of stillness.")
        else
            Say("Try /critter nap 120")
        end
    elseif cmd == "peek" then
        if PP.PeekSlash then PP.PeekSlash(val, args[3])
        else Say("The peeking part didn't load. Please quit ESO completely and start it again - a /reloadui doesn't pick up new addon files.") end
    elseif cmd == "pats" then
        Say(string.format("I've been patted %d times. More please! <3", sv.pats or 0))
    elseif cmd == "test" then
        if val and TEST_MOODS[val] then
            PP.TestMood(val)
        else
            Say("Moods: idle, wag, zoomies, pat, sleep, hide, sad, alert")
        end
    else
        ShowHelp()
    end
    if PP.RefreshSettings then PP.RefreshSettings() end
end

PP.SKINS = SKINS

function PP.GetSettings() return sv end

function PP.SetSkin(name)
    if IsValidSkin(name) then
        sv.skin = name
        ApplySkin()
    end
end

function PP.GetPixelSize()
    return math.floor(BASE_SIZE * sv.scale / 100 + 0.5)
end

function PP.SetScale(percent)
    sv.scale = math.max(MIN_SCALE, math.min(MAX_SCALE, math.floor(percent + 0.5)))
    ApplySize()
end

function PP.SetNap(seconds)
    sv.sleepAfter = math.max(10, math.floor(seconds + 0.5))
    MarkActive()
end

function PP.SetLocked(locked)
    sv.locked = locked
    window:SetMovable(not locked)
end

function PP.SetShown(shown)
    sv.hidden = not shown
    ApplyVisibility()
end

function PP.SetQuiet(quiet)
    sv.quiet = quiet
end

function PP.ResetPosition()
    sv.x, sv.y = nil, nil
    ApplyPosition()
    sv.bannerX, sv.bannerY = nil, nil
    PP.PlaceFetchBanner()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= PP.name then return end
    EVENT_MANAGER:UnregisterForEvent(PP.name, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("PocketCritters_SV", 1, nil, DEFAULTS)
    if not IsValidSkin(sv.skin) then sv.skin = DEFAULTS.skin end
    MarkActive()
    CreateWindow()
    RegisterEvents()

    SLASH_COMMANDS["/critter"] = OnSlash
    if PP.InitPeek then PP.InitPeek() end
end

ZO_CreateStringId("SI_BINDING_NAME_POCKETCRITTERS_TOGGLE_SETTINGS", "Open Pocket Critters settings")
ZO_CreateStringId("SI_BINDING_NAME_POCKETCRITTERS_PAT", "Pat my critter")

function PP.KeybindToggleSettings()
    if sv and PP.ToggleSettings then PP.ToggleSettings() end
end

function PP.KeybindPat()
    if sv then PP.Pat() end
end

EVENT_MANAGER:RegisterForEvent(PP.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
