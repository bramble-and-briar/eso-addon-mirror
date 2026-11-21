local PP = PocketCritters

local CELL, LEDGE = 512, 240
local PEEK_CELL_COL, PEEK_CELL_ROW = 1, 1
local PEEK_BOTTOM = 256
local PEEK_TOP = { hellwuff = 117, tsardarashi = 111, hisani = 107, azsu = 152, tsaji = 147, brown = 139 }
local MAIN_TEX = "PocketCritters/textures/critter_%s%s.dds"
local PERCH_TEX = "PocketCritters/textures/critter_%s_perch%s.dds"
local HD_ABOVE = 128
local PEEK_ROOM = 0.55
local MIN_PEEK_SIZE = 40

local TARGETS = {
    { name = "Inventory", control = "ZO_PlayerInventory" },
}

local RISE = 0.4

local layer, tex
local peek = nil

local function Say(msg) d("|cFF8FC8[Pocket Critters]|r " .. msg) end
local function Now() return GetFrameTimeSeconds() end
local function Ease(p) return 1 - (1 - p) * (1 - p) end
local function Lerp(a, b, p) return a + (b - a) * p end
local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function Settings() return PP.GetSettings and PP.GetSettings() end
local function Skin() local sv = Settings() return (sv and sv.skin) or "hellwuff" end
local function HomeSize() return PP.GetPixelSize() end

local function DrawMain(row, col, x, y, flip, s, clipL, clipR)
    local left, right = x - s / 2, x + s / 2
    local a, b = math.max(left, clipL or left), math.min(right, clipR or right)
    if b - a < 1 then tex:SetHidden(true) return end
    tex:SetTexture(string.format(MAIN_TEX, Skin(), s > HD_ABOVE and "_hd" or ""))
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
    tex:SetTexture(string.format(PERCH_TEX, Skin(), s > HD_ABOVE and "_hd" or ""))
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
    local w = PocketCrittersWindow
    local x, y = w and w:GetLeft(), w and w:GetTop()
    if not x or not y then return GuiRoot:GetWidth() - 280 - s / 2, GuiRoot:GetHeight() - 170 end
    return x + s / 2, y + s
end

local function ControlRect(ctrl)
    local l, t, r, b = ctrl:GetLeft(), ctrl:GetTop(), ctrl:GetRight(), ctrl.GetBottom and ctrl:GetBottom()
    if type(l) ~= "number" or type(t) ~= "number" or type(r) ~= "number" or r - l < 1 then return nil end
    if type(b) ~= "number" or b <= t then b = GuiRoot:GetHeight() end
    return l, t, r, b
end

local function VisualTop(ctrl, l, t, r)
    local top = t
    local function Scan(c, depth)
        local n = c.GetNumChildren and c:GetNumChildren()
        if type(n) ~= "number" or depth > 3 then return end
        for i = 1, n do
            local ch = c:GetChild(i)
            if ch and not ch:IsHidden() then
                local cl, ct, cr = ch:GetLeft(), ch:GetTop(), ch:GetRight()
                if type(ct) == "number" and type(cl) == "number" and type(cr) == "number"
                    and cr - cl > 8 and ct < top and ct >= t - 200 and cr > l and cl < r then
                    top = ct
                end
                Scan(ch, depth + 1)
            end
        end
    end
    Scan(ctrl, 1)
    return top
end

local function UserLift() local sv = Settings() return (sv and sv.peekLift) or 0 end
local function UserShift() local sv = Settings() return (sv and sv.peekShift) or 0 end

local function LiftFor(ctrl, l, t, r)
    return (t - VisualTop(ctrl, l, t, r)) + UserLift()
end

local function TargetRect(p)
    local ctrl = _G[p.target.control]
    if ctrl then
        local l, t, r, b = ControlRect(ctrl)
        if l then p.L, p.T, p.R, p.B = l, t - p.tabLift - UserLift(), r, b end
    end
    return p.L, p.T, p.R, p.B
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

local function FindTarget()
    local s = HomeSize()
    for _, t in ipairs(TARGETS) do
        local ctrl = _G[t.control]
        if ctrl and not ctrl:IsHidden() then
            local l, _, r = ControlRect(ctrl)
            if l and r - l >= s * 1.2 then return t end
        end
    end
    return nil
end

local function HudShowing()
    if not SCENE_MANAGER or not SCENE_MANAGER.IsShowing then return true end
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

local function Start(target)
    local ctrl = _G[target.control]
    local L, T, R, B = ControlRect(ctrl)
    if not L then return false end
    local tabLift = T - VisualTop(ctrl, L, T, R)
    local lift = tabLift + UserLift()
    if PP.IsFetchMode and PP.IsFetchMode() then PP.StopFetchMode() end
    local hx, hy = HomeFeet()
    local full = HomeSize()
    local p = { target = target, L = L, T = T - lift, R = R, B = B, tabLift = tabLift, hx = hx, hy = hy, full = full }
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
    return true
end

local function BeginExit()
    local p = peek
    if not p or p.phase == "runhome" then return end
    if not HudShowing() or p.inside then Finish() return end
    p.phase, p.t0 = "runhome", Now()
end

local function Update()
    local p = peek
    if not p then return end
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
        local slide = (PEEK_BOTTOM - (PEEK_TOP[Skin()] or 110)) * k
        DrawPeek(p.px - s, topUp + (1 - up) * slide, cut, s)

    elseif p.phase == "runhome" then
        local q = math.min(1, t / p.runTime)
        local bob = (math.floor(t * 10) % 2 == 1) and -3 or 0
        DrawMain(4, math.floor(t * 10) % 4, Lerp(p.px, p.hx, Ease(q)), p.hy + bob, p.hx < p.px, p.full)
        if q >= 1 then Finish() end
    end
end

local function Poll()
    local sv = Settings()
    if not sv or not layer then return end
    if not sv.peek or sv.hidden then
        if peek then Finish() end
        return
    end
    local found = FindTarget()
    if peek then
        if found ~= peek.target then BeginExit() end
        if not peek and found then Start(found) end
    elseif found then
        Start(found)
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
    if not sv then return end
    sv.peek = on and true or false
    if not sv.peek then Finish() end
    if PP.RefreshSettings then PP.RefreshSettings() end
end

function PP.PeekSlash(val, arg2)
    local sv = Settings()
    if not sv then return end
    if val == "debug" then
        Say("Peeking is " .. (sv.peek and "on" or "off") .. ", critter " .. HomeSize() .. " px, extra height " ..
            (sv.peekLift or 0) .. ", moved across " .. (sv.peekShift or 0) .. ", screen " .. math.floor(GuiRoot:GetWidth()) .. " x " .. math.floor(GuiRoot:GetHeight()) ..
            (peek and (", now: " .. peek.phase) or ""))
        for _, t in ipairs(TARGETS) do
            local ctrl = _G[t.control]
            local status
            if not ctrl then status = "not found"
            elseif ctrl:IsHidden() then status = "closed"
            else
                local l, top, r = ControlRect(ctrl)
                if l then
                    local edge = top - LiftFor(ctrl, l, top, r)
                    local fs = FitAbove(edge)
                    status = string.format("OPEN at left %d, top %d, width %d, peeks at %d", l, top, r - l, edge) ..
                        (fs and string.format(" - peeks at %d px", fs) or " - no room above, hides behind it")
                else status = "open, no size" end
            end
            d("  " .. t.name .. ": " .. status)
        end
        return
    end
    if val == "higher" or val == "lower" or val == "height" or val == "left" or val == "right" or val == "across" then
        PP.PeekNudge(val, tonumber(arg2 or "") or 0)
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
    else PP.SetPeek(not sv.peek) end
    Say("Peeking over the inventory is " .. (sv.peek and "on" or "off") .. ".")
end

local STEP = 10
function PP.PeekNudge(kind, value)
    local sv = Settings()
    if not sv then return end
    if kind == "higher" then sv.peekLift = (sv.peekLift or 0) + STEP
    elseif kind == "lower" then sv.peekLift = (sv.peekLift or 0) - STEP
    elseif kind == "height" then sv.peekLift = value or 0
    elseif kind == "left" then sv.peekShift = (sv.peekShift or 0) - STEP
    elseif kind == "right" then sv.peekShift = (sv.peekShift or 0) + STEP
    elseif kind == "across" then sv.peekShift = value or 0
    elseif kind == "reset" then sv.peekLift, sv.peekShift = 0, 0 end
    sv.peekLift = Clamp(math.floor((sv.peekLift or 0) + 0.5), -100, 200)
    sv.peekShift = Clamp(math.floor((sv.peekShift or 0) + 0.5), -600, 600)
    if PP.RefreshSettings then PP.RefreshSettings() end
end

function PP.PeekSpotText()
    local sv = Settings()
    local lift, shift = (sv and sv.peekLift) or 0, (sv and sv.peekShift) or 0
    local parts = {}
    if lift ~= 0 then table.insert(parts, math.abs(lift) .. " px " .. (lift > 0 and "higher" or "lower")) end
    if shift ~= 0 then table.insert(parts, math.abs(shift) .. " px further " .. (shift < 0 and "left" or "right")) end
    if #parts == 0 then return "at the normal spot" end
    return table.concat(parts, " and ")
end

function PP.InitPeek()
    if layer then return end
    CreateLayer()
    EVENT_MANAGER:RegisterForUpdate(PP.name .. "PeekPoll", 100, Poll)
end
