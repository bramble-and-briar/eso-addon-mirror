local PP = PocketCritters

local CELL, LEDGE = 512, 240
local PEEK_CELL_COL, PEEK_CELL_ROW = 1, 1
local PEEK_BOTTOM = 256
local PEEK_TOP = { hellwuff = 117, tsardarashi = 111, hisani = 107, azsu = 152, tsaji = 147, brown = 139 }
local PERCH_TEX = "PocketCritters/textures/critter_%s_perch%s.dds"
local PEEK_ROOM = 0.55
local MIN_PEEK_SIZE = 40

local RISE = 0.4
local LEAVE_WAIT = 0.15

local layer, tex
local peek

local Say, Now, Ease = PP.Say, PP.Now, PP.Ease
local function Lerp(a, b, p) return a + (b - a) * p end
local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function Settings() return PP.GetSettings() end
local function Skin() return Settings().skin end
local function HomeSize() return PP.GetPixelSize() end

local function DrawMain(row, col, x, y, flip, s, clipL, clipR)
    local left, right = x - s / 2, x + s / 2
    local a, b = math.max(left, clipL or left), math.min(right, clipR or right)
    if b - a < 1 then tex:SetHidden(true) return end
    tex:SetTexture(string.format(PP.TEXTURE_PATH, Skin(), s > PP.HD_ABOVE and "_hd" or ""))
    local l, r = col / 4, (col + 1) / 4
    if flip then l, r = r, l end
    local fa, fb = (a - left) / s, (b - left) / s
    tex:SetTextureCoords(Lerp(l, r, fa), Lerp(l, r, fb), row / 8, (row + 1) / 8)
    tex:SetDimensions(b - a, s)
    tex:ClearAnchors()
    tex:SetAnchor(TOPLEFT, layer, TOPLEFT, a, y - s)
    tex:SetHidden(false)
end

local function DrawPeek(left, top, cut, s)
    local C = s * 2
    local h = math.min(cut - top, PEEK_BOTTOM / CELL * C)
    if h < 1 then tex:SetHidden(true) return end
    tex:SetTexture(string.format(PERCH_TEX, Skin(), s > PP.HD_ABOVE and "_hd" or ""))
    local l = PEEK_CELL_COL / 4
    local t0 = PEEK_CELL_ROW / 2
    tex:SetTextureCoords(l, l + 0.25, t0, t0 + 0.5 * (h / C))
    tex:SetDimensions(C, h)
    tex:ClearAnchors()
    tex:SetAnchor(TOPLEFT, layer, TOPLEFT, left, top)
    tex:SetHidden(false)
end

local function HomeFeet()
    local s = HomeSize()
    return PP.window:GetLeft() + s / 2, PP.window:GetTop() + s
end

local function ControlRect(ctrl)
    local l, t, r = ctrl:GetLeft(), ctrl:GetTop(), ctrl:GetRight()
    if r - l < 1 then return nil end
    return l, t, r
end

local function VisualTop(ctrl, l, t, r)
    local top = t
    local function Scan(c, depth)
        local n = c:GetNumChildren()
        if depth > 3 then return end
        for i = 1, n do
            local ch = c:GetChild(i)
            if ch and not ch:IsHidden() then
                local cl, ct, cr = ch:GetLeft(), ch:GetTop(), ch:GetRight()
                if cr - cl > 8 and ct < top and ct >= t - 200 and cr > l and cl < r then
                    top = ct
                end
                Scan(ch, depth + 1)
            end
        end
    end
    Scan(ctrl, 1)
    return top
end

local function UserLift() return Settings().peekLift end
local function UserShift() return Settings().peekShift end

local function TargetRect(p)
    local l, t, r = ControlRect(ZO_PlayerInventory)
    if l then p.L, p.T, p.R = l, t - p.tabLift - UserLift(), r end
    return p.L, p.T, p.R
end

local function PeekX(p)
    local L, _, R = TargetRect(p)
    local s = p.s
    local x
    if p.inside then x = p.hx
    else x = (p.dir > 0) and (L + s * 0.6) or (R - s * 0.6) end
    x = x + UserShift()
    return Clamp(x, L + s * 0.36, R - s * 0.36)
end

local function HudShowing()
    return SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
end

local function Finish()
    peek = nil
    PP.peekHidesHome = false
    if layer then layer:SetHidden(true) end
end

local function FitAbove(T)
    local s = math.min(HomeSize(), math.floor(T / PEEK_ROOM))
    if s < MIN_PEEK_SIZE then return nil end
    return s
end

local function Start()
    local ctrl = ZO_PlayerInventory
    local L, T, R = ControlRect(ctrl)
    if not L or R - L < HomeSize() * 1.2 then return end
    local tabLift = T - VisualTop(ctrl, L, T, R)
    local lift = tabLift + UserLift()
    if PP.IsFetchMode() then PP.StopFetchMode() end
    local hx, hy = HomeFeet()
    local full = HomeSize()
    local p = { L = L, T = T - lift, R = R, tabLift = tabLift, hx = hx, hy = hy, full = full }
    p.fit = FitAbove(p.T)
    p.s = p.fit or full

    p.inside = hx > L and hx < R and hy > p.T
    p.dir = (hx <= (L + R) / 2) and 1 or -1
    p.px = PeekX(p)
    local dist = math.abs(p.px - hx)
    p.runTime = Clamp(dist / (full * 6), 0.35, 1.4)
    p.phase, p.t0 = p.inside and "hide" or "notice", Now()
    peek = p
    PP.peekHidesHome = true
    layer:SetHidden(false)
end

local function TryStart()
    local sv = Settings()
    if peek or not sv.peek or sv.hidden or not INVENTORY_FRAGMENT:IsShowing() then return end
    Start()
end

local function Update()
    local p = peek
    if not p then return end

    if p.leaving and p.phase ~= "runhome" then
        if p.inside then Finish() return end
        if HudShowing() then p.phase, p.t0 = "runhome", Now()
        elseif Now() - p.leaving > LEAVE_WAIT then Finish() return end
    end
    local t = Now() - p.t0
    local L, T, R = TargetRect(p)
    p.px = PeekX(p)

    local clipL, clipR
    if p.phase ~= "runhome" and p.hy > T then
        if p.dir > 0 then clipR = L else clipL = R end
    end

    if p.phase == "notice" then
        DrawMain(6, math.floor(t * 4) % 4, p.hx, p.hy, p.dir < 0, p.full)
        if t >= 0.4 then p.phase, p.t0 = "run", Now() end

    elseif p.phase == "run" then
        local q = math.min(1, t / p.runTime)
        local bob = (math.floor(t * 10) % 2 == 1) and -3 or 0
        DrawMain(4, math.floor(t * 10) % 4, Lerp(p.hx, p.px, Ease(q)), p.hy + bob, p.dir < 0, p.full, clipL, clipR)
        if q >= 1 then p.phase, p.t0 = "hide", Now() end

    elseif p.phase == "hide" then
        tex:SetHidden(true)
        if t >= 0.35 then p.phase, p.t0 = "peek", Now() end

    elseif p.phase == "peek" then
        p.fit = FitAbove(T)
        if not p.fit then tex:SetHidden(true) return end
        local s = p.fit
        p.s = s
        local k = s * 2 / CELL
        local up = Ease(math.min(1, t / RISE))
        local cut = T + 2 + (PEEK_BOTTOM - LEDGE) * k
        local topUp = T + 2 - LEDGE * k
        local slide = (PEEK_BOTTOM - PEEK_TOP[Skin()]) * k
        DrawPeek(p.px - s, topUp + (1 - up) * slide, cut, s)

    elseif p.phase == "runhome" then
        local q = math.min(1, t / p.runTime)
        local bob = (math.floor(t * 10) % 2 == 1) and -3 or 0
        DrawMain(4, math.floor(t * 10) % 4, Lerp(p.px, p.hx, Ease(q)), p.hy + bob, p.hx < p.px, p.full)
        if q >= 1 then
            Finish()
            TryStart()
        end
    end
end

local function OnInventoryStateChange(_, newState)
    if newState == SCENE_FRAGMENT_SHOWN then
        if peek then peek.leaving = nil else TryStart() end
    elseif newState == SCENE_FRAGMENT_HIDDEN and peek then
        peek.leaving = Now()
    end
end

local function CreateLayer()
    layer = WINDOW_MANAGER:CreateTopLevelWindow("PocketCrittersPeekLayer")
    layer:SetAnchorFill(GuiRoot)
    layer:SetDrawTier(DT_HIGH)
    layer:SetMouseEnabled(false)
    layer:SetHidden(true)
    tex = WINDOW_MANAGER:CreateControl("PocketCrittersPeekTexture", layer, CT_TEXTURE)
    tex:SetMouseEnabled(false)
    layer:SetHandler("OnUpdate", Update)
end

function PP.SetPeek(on)
    local sv = Settings()
    sv.peek = on
    PP.PeekRefresh()
    PP.RefreshSettings()
end

function PP.PeekSlash(val, arg2)
    local sv = Settings()
    if val == "higher" or val == "lower" or val == "height" or val == "left" or val == "right" or val == "across" then
        PP.PeekNudge(val, tonumber(arg2) or 0)
        Say("Your critter now peeks " .. PP.PeekSpotText() ..
            ". Try /critter peek higher, lower, left or right (or the buttons in /critter), or /critter peek reset.")
        return
    end
    if val == "reset" then
        PP.PeekNudge("reset")
        Say("Your critter now peeks at the normal spot.")
        return
    end
    if val == "on" then PP.SetPeek(true)
    elseif val == "off" then PP.SetPeek(false)
    elseif val == nil then PP.SetPeek(not sv.peek)
    else
        Say("Try /critter peek on, off, higher, lower, left, right or reset.")
        return
    end
    Say("Peeking over the inventory is " .. (sv.peek and "on" or "off") .. ".")
end

local STEP = 10
function PP.PeekNudge(kind, value)
    local sv = Settings()
    if kind == "higher" then sv.peekLift = sv.peekLift + STEP
    elseif kind == "lower" then sv.peekLift = sv.peekLift - STEP
    elseif kind == "height" then sv.peekLift = value
    elseif kind == "left" then sv.peekShift = sv.peekShift - STEP
    elseif kind == "right" then sv.peekShift = sv.peekShift + STEP
    elseif kind == "across" then sv.peekShift = value
    elseif kind == "reset" then sv.peekLift, sv.peekShift = 0, 0 end
    sv.peekLift = Clamp(math.floor(sv.peekLift + 0.5), -100, 200)
    sv.peekShift = Clamp(math.floor(sv.peekShift + 0.5), -600, 600)
    PP.RefreshSettings()
end

function PP.PeekSpotText()
    local sv = Settings()
    local lift, shift = sv.peekLift, sv.peekShift
    local parts = {}
    if lift ~= 0 then table.insert(parts, math.abs(lift) .. " px " .. (lift > 0 and "higher" or "lower")) end
    if shift ~= 0 then table.insert(parts, math.abs(shift) .. " px further " .. (shift < 0 and "left" or "right")) end
    if #parts == 0 then return "at the normal spot" end
    return table.concat(parts, " and ")
end

function PP.PeekRefresh()
    local sv = Settings()
    if peek and (not sv.peek or sv.hidden) then Finish() else TryStart() end
end

function PP.InitPeek()
    CreateLayer()
    INVENTORY_FRAGMENT:RegisterCallback("StateChange", OnInventoryStateChange)
end
