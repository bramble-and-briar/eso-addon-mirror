BETABars = BETABars or {}
local T = BETABars

local ADDON = "BETABarsUI"
local SEGMENTS = 10
local ORB_SLICES = 16
local TAIL_MS = 260
local FILL = "EsoUI/Art/Miscellaneous/progressbar_genericFill.dds"
local NUM_W = 150
local PCT_W = 70
local READ_GAP = 10

local FLAG_H = COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH
local FLAG_M = COMBAT_MECHANIC_FLAGS_MAGICKA or POWERTYPE_MAGICKA
local FLAG_S = COMBAT_MECHANIC_FLAGS_STAMINA or POWERTYPE_STAMINA

local root
local rows = {}
local tailToken = 0
local tailShown = false
local lastHealth = nil
local rollCost = 0
local magCost = 0
local inCombat = false
local stockHooked = false
local fragmentGone = false

local function Vars()
    return T.savedVars
end

local function ColorOf(key, d1, d2, d3)
    local v = Vars()
    local tbl = v and v[key]
    if type(tbl) ~= "table" then
        return d1, d2, d3, 1
    end
    return tonumber(tbl[1]) or d1, tonumber(tbl[2]) or d2, tonumber(tbl[3]) or d3, tonumber(tbl[4]) or 1
end

local function Style()
    local v = Vars()
    local s = v and v.style or "thin"
    if s == "segments" or s == "classic" or s == "orbs" then
        return s
    end
    return "thin"
end

local function HudOpen()
    local function showing(scene)
        return scene and scene.IsShowing and scene:IsShowing()
    end
    if HUD_SCENE or HUD_UI_SCENE then
        return showing(HUD_SCENE) or showing(HUD_UI_SCENE)
    end
    return true
end

local function Werewolf()
    if type(IsWerewolf) ~= "function" then return false end
    local ok, v = pcall(IsWerewolf)
    return ok and v and true or false
end

local function Power(flag)
    if type(GetUnitPower) ~= "function" or not flag then
        return 0, 1
    end
    local ok, cur, mx = pcall(GetUnitPower, "player", flag)
    if not ok or type(cur) ~= "number" then
        return 0, 1
    end
    mx = tonumber(mx) or 1
    if mx < 1 then mx = 1 end
    if cur < 0 then cur = 0 end
    if cur > mx then cur = mx end
    return cur, mx
end

local function ShieldAmount()
    if type(GetUnitAttributeVisualizerEffectInfo) ~= "function" then
        return 0
    end
    local stat = STAT_MITIGATION
    local attr = ATTRIBUTE_HEALTH
    local ok, value = pcall(GetUnitAttributeVisualizerEffectInfo, "player", ATTRIBUTE_VISUAL_POWER_SHIELDING, stat, attr, FLAG_H)
    if ok and type(value) == "number" and value > 0 then
        return value
    end
    if POWERTYPE_HEALTH and POWERTYPE_HEALTH ~= FLAG_H then
        ok, value = pcall(GetUnitAttributeVisualizerEffectInfo, "player", ATTRIBUTE_VISUAL_POWER_SHIELDING, stat, attr, POWERTYPE_HEALTH)
        if ok and type(value) == "number" and value > 0 then
            return value
        end
    end
    return 0
end

local function ActiveHotbar()
    if type(GetActiveHotbarCategory) == "function" then
        local ok, cat = pcall(GetActiveHotbarCategory)
        if ok and type(cat) == "number" then
            return cat
        end
    end
    return HOTBAR_CATEGORY_PRIMARY
end

local function SlotCost(slot, mechanic, hotbar)
    if type(GetSlotAbilityCost) ~= "function" then
        return 0
    end
    local ok, cost = pcall(GetSlotAbilityCost, slot, mechanic, hotbar)
    if ok and type(cost) == "number" and cost > 0 then
        return cost
    end
    return 0
end

local function RefreshCosts()
    local hotbar = ActiveHotbar()
    local best = 0
    for slot = 3, 7 do
        local cost = SlotCost(slot, FLAG_M, hotbar)
        if cost > best then best = cost end
    end
    magCost = best

    local found = 0
    if type(GetAbilityCost) == "function" then
        local ids = { 28549, 69143, 163056 }
        for i = 1, #ids do
            local ok, cost, mech = pcall(GetAbilityCost, ids[i])
            if ok and type(cost) == "number" and cost > 0 then
                if mech == nil or mech == FLAG_S or mech == POWERTYPE_STAMINA then
                    found = cost
                    break
                end
            end
            ok, cost = pcall(GetAbilityCost, ids[i], FLAG_S)
            if ok and type(cost) == "number" and cost > 0 then
                found = cost
                break
            end
        end
    end
    rollCost = found
end

local function MakeBar(parent, name)
    local c = WINDOW_MANAGER:CreateControl(name, parent, CT_STATUSBAR)
    if c.SetTexture then
        pcall(c.SetTexture, c, FILL)
    end
    c:SetMinMax(0, 1000)
    c:SetValue(0)
    c:SetColor(1, 1, 1, 1)
    return c
end

local function MakeLabel(parent, name)
    local c = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    c:SetFont("ZoFontGamepad22")
    c:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    c:SetColor(1, 1, 1, 0.92)
    c:SetText("")
    return c
end

local function Solid(bar, r, g, b, a)
    bar:SetMinMax(0, 1000)
    bar:SetValue(1000)
    bar:SetColor(r, g, b, a or 1)
end

local function Empty(bar)
    bar:SetValue(0)
    bar:SetColor(0, 0, 0, 0)
end

local function WantHideStock()
    local v = Vars()
    if not v or v.enabled == false or v.hideStock == false then
        return false
    end
    if Werewolf() then
        return false
    end
    return true
end

local function StockControl()
    return ZO_PlayerAttributeBars
end

local function EachScene(fn)
    if HUD_SCENE then fn(HUD_SCENE) end
    if HUD_UI_SCENE then fn(HUD_UI_SCENE) end
end

function T.SyncStock(hide)
    local c = StockControl()
    local frag = PLAYER_ATTRIBUTE_BARS_FRAGMENT
    if hide then
        if frag and not fragmentGone then
            EachScene(function(scene)
                if scene.RemoveFragment then
                    pcall(scene.RemoveFragment, scene, frag)
                end
            end)
            fragmentGone = true
        end
        if c then
            c:SetAlpha(0)
            c:SetHidden(true)
            if not stockHooked and ZO_PreHookHandler then
                stockHooked = true
                ZO_PreHookHandler(c, "OnShow", function(control)
                    if WantHideStock() then
                        control:SetAlpha(0)
                        control:SetHidden(true)
                    end
                end)
            end
        end
    else
        if frag and fragmentGone then
            EachScene(function(scene)
                if scene.AddFragment then
                    pcall(scene.AddFragment, scene, frag)
                end
            end)
            fragmentGone = false
        end
        if c then
            c:SetAlpha(1)
            c:SetHidden(false)
        end
    end
end

local function BuildRow(key)
    local holder = WINDOW_MANAGER:CreateControl(ADDON .. key, root, CT_CONTROL)
    holder:SetMouseEnabled(false)

    local track = MakeBar(holder, ADDON .. key .. "Track")
    local ghost = MakeBar(holder, ADDON .. key .. "Ghost")
    local fill = MakeBar(holder, ADDON .. key .. "Fill")

    local segs = {}
    for i = 1, SEGMENTS do
        segs[i] = MakeBar(holder, ADDON .. key .. "Seg" .. i)
    end

    local slices = {}
    for i = 1, ORB_SLICES do
        slices[i] = MakeBar(holder, ADDON .. key .. "Slice" .. i)
    end

    local notch = MakeBar(holder, ADDON .. key .. "Notch")
    notch:SetHidden(true)

    local rim = MakeBar(holder, ADDON .. key .. "Rim")
    rim:SetHidden(true)

    local value = MakeLabel(holder, ADDON .. key .. "Value")
    local pct = MakeLabel(holder, ADDON .. key .. "Pct")
    pct:SetColor(1, 1, 1, 0.7)

    rows[key] = {
        holder = holder,
        track = track,
        ghost = ghost,
        fill = fill,
        segs = segs,
        slices = slices,
        notch = notch,
        rim = rim,
        value = value,
        pct = pct,
        valueText = "",
        pctText = "",
    }
end

function T.Build()
    if root then return end
    root = WINDOW_MANAGER:CreateTopLevelWindow(ADDON .. "Root")
    root:SetMouseEnabled(false)
    root:SetMovable(false)
    root:SetClampedToScreen(true)
    root:SetDrawTier(DT_HIGH)
    root:SetDrawLayer(DL_OVERLAY)
    root:SetHidden(true)

    BuildRow("H")
    BuildRow("M")
    BuildRow("S")

    local function OnHud(_, newState)
        if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
            T.Apply()
        end
    end
    if HUD_SCENE and HUD_SCENE.RegisterCallback then
        HUD_SCENE:RegisterCallback("StateChange", OnHud)
    end
    if HUD_UI_SCENE and HUD_UI_SCENE.RegisterCallback then
        HUD_UI_SCENE:RegisterCallback("StateChange", OnHud)
    end

    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED, function()
        inCombat = IsUnitInCombat and IsUnitInCombat("player") and true or false
        RefreshCosts()
        lastHealth = nil
        zo_callLater(function() T.Apply() end, 400)
        zo_callLater(function() T.Apply() end, 1500)
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_POWER_UPDATE, function(_, unitTag)
        if unitTag == "player" then T.Apply() end
    end)
    EVENT_MANAGER:AddFilterForEvent(ADDON, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(ADDON .. "Vis", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, function(_, unitTag)
        if unitTag == "player" then T.Apply() end
    end)
    EVENT_MANAGER:AddFilterForEvent(ADDON .. "Vis", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(ADDON .. "VisU", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, function(_, unitTag)
        if unitTag == "player" then T.Apply() end
    end)
    EVENT_MANAGER:AddFilterForEvent(ADDON .. "VisU", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(ADDON .. "VisR", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, function(_, unitTag)
        if unitTag == "player" then T.Apply() end
    end)
    EVENT_MANAGER:AddFilterForEvent(ADDON .. "VisR", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(ADDON .. "Combat", EVENT_PLAYER_COMBAT_STATE, function(_, fighting)
        inCombat = fighting and true or false
        local v = Vars()
        if inCombat and v then v.preview = false end
        T.Apply()
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON .. "Bar", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, function()
        RefreshCosts()
        T.Apply()
    end)
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
        EVENT_MANAGER:RegisterForEvent(ADDON .. "Swap", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function()
            RefreshCosts()
            T.Apply()
        end)
    end

    RefreshCosts()
    T.Apply()
end

local function LayoutRow(row, style, width, height, x, y)
    local holder = row.holder
    local readW = NUM_W + PCT_W
    holder:ClearAnchors()
    holder:SetAnchor(TOPLEFT, root, TOPLEFT, x, y)
    holder:SetDimensions(width + READ_GAP + readW, height)

    local orb = style == "orbs"
    local segs = style == "segments"

    row.track:SetHidden(orb or segs)
    row.fill:SetHidden(orb or segs)
    row.ghost:SetHidden(orb or segs)
    for i = 1, SEGMENTS do
        row.segs[i]:SetHidden(not segs)
    end
    for i = 1, ORB_SLICES do
        row.slices[i]:SetHidden(not orb)
    end

    row.track:ClearAnchors()
    row.track:SetAnchor(TOPLEFT, holder, TOPLEFT, 0, 0)
    row.track:SetDimensions(width, height)
    row.ghost:ClearAnchors()
    row.ghost:SetAnchor(TOPLEFT, holder, TOPLEFT, 0, 0)
    row.ghost:SetDimensions(width, height)
    row.fill:ClearAnchors()
    row.fill:SetAnchor(TOPLEFT, holder, TOPLEFT, 0, 0)
    row.fill:SetDimensions(width, height)

    if segs then
        local gap = 3
        local cell = math.floor((width - gap * (SEGMENTS - 1)) / SEGMENTS)
        if cell < 6 then cell = 6 end
        for i = 1, SEGMENTS do
            local s = row.segs[i]
            s:ClearAnchors()
            s:SetDimensions(cell, height)
            s:SetAnchor(TOPLEFT, holder, TOPLEFT, (i - 1) * (cell + gap), 0)
        end
    end

    if orb then
        local n = ORB_SLICES
        local sliceH = math.max(2, math.floor(height / n))
        for i = 1, n do
            local yNorm = ((i - 0.5) / n) * 2 - 1
            local half = math.sqrt(math.max(0, 1 - yNorm * yNorm))
            local w = math.max(4, math.floor(half * width))
            local s = row.slices[i]
            s:ClearAnchors()
            s:SetDimensions(w, sliceH)
            s:SetAnchor(BOTTOM, holder, BOTTOMLEFT, math.floor(width * 0.5), -((i - 1) * sliceH))
        end
    end

    row.value:ClearAnchors()
    row.value:SetAnchor(LEFT, holder, TOPLEFT, width + READ_GAP, math.floor(height * 0.5))
    row.value:SetDimensions(NUM_W, height + 8)
    row.pct:ClearAnchors()
    row.pct:SetAnchor(LEFT, holder, TOPLEFT, width + READ_GAP + NUM_W, math.floor(height * 0.5))
    row.pct:SetDimensions(PCT_W, height + 8)
end

local function PaintFill(row, pct, r, g, b, ghostPct)
    Solid(row.track, 0.05, 0.05, 0.05, 0.9)
    if ghostPct and ghostPct > pct then
        row.ghost:SetHidden(false)
        row.ghost:SetMinMax(0, 1000)
        row.ghost:SetValue(math.floor(ghostPct * 1000 + 0.5))
        row.ghost:SetColor(r * 0.4, g * 0.15, b * 0.15, 0.9)
    else
        Empty(row.ghost)
    end
    row.fill:SetMinMax(0, 1000)
    row.fill:SetValue(math.floor(pct * 1000 + 0.5))
    row.fill:SetColor(r, g, b, 1)
end

local function PaintSegs(row, pct, r, g, b, ghostPct)
    local filled = math.floor(pct * SEGMENTS + 0.001)
    if pct > 0 and filled < 1 then filled = 1 end
    local ghostN = 0
    if ghostPct and ghostPct > pct then
        ghostN = math.floor(ghostPct * SEGMENTS + 0.001)
    end
    for i = 1, SEGMENTS do
        local s = row.segs[i]
        s:SetMinMax(0, 1000)
        s:SetValue(1000)
        if i <= filled then
            s:SetColor(r, g, b, 1)
        elseif i <= ghostN then
            s:SetColor(r * 0.4, g * 0.15, b * 0.15, 0.9)
        else
            s:SetColor(0.10, 0.10, 0.10, 0.9)
        end
    end
end

local function PaintOrb(row, pct, r, g, b)
    local n = ORB_SLICES
    local filled = math.floor(pct * n + 0.001)
    if pct > 0 and filled < 1 then filled = 1 end
    for i = 1, n do
        local s = row.slices[i]
        s:SetMinMax(0, 1000)
        s:SetValue(1000)
        if i <= filled then
            s:SetColor(r, g, b, 1)
        else
            s:SetColor(0.07, 0.07, 0.07, 0.92)
        end
    end
end

local function PlaceNotch(row, frac, width, height)
    local notch = row.notch
    if not frac or frac <= 0.02 or frac >= 0.98 then
        notch:SetHidden(true)
        return
    end
    notch:SetHidden(false)
    notch:ClearAnchors()
    notch:SetDimensions(3, height)
    notch:SetAnchor(TOPLEFT, row.holder, TOPLEFT, math.floor(frac * width) - 1, 0)
    Solid(notch, 1, 0.86, 0.25, 0.95)
end

local function SetReadout(label, cacheKey, row, text)
    if row[cacheKey] == text then return end
    row[cacheKey] = text
    label:SetText(text)
end

local function Sample()
    return {
        H = { cur = 18600, mx = 30000, shield = 6400, notch = 0 },
        M = { cur = 16800, mx = 20000, shield = 0, notch = 0.22 },
        S = { cur = 8200, mx = 20000, shield = 0, notch = 0.20 },
    }
end

function T.Apply()
    if not root then return end
    local v = Vars()
    T.SyncStock(WantHideStock())
    if not v or v.enabled == false or Werewolf() then
        root:SetHidden(true)
        return
    end
    if not HudOpen() and not v.preview then
        root:SetHidden(true)
        return
    end

    local preview = v.preview == true and not inCombat
    local data
    if preview then
        data = Sample()
    else
        local hc, hm = Power(FLAG_H)
        local mc, mm = Power(FLAG_M)
        local sc, sm = Power(FLAG_S)
        data = {
            H = { cur = hc, mx = hm, shield = ShieldAmount(), notch = 0 },
            M = { cur = mc, mx = mm, shield = 0, notch = (mm > 0 and magCost > 0) and (magCost / mm) or 0 },
            S = { cur = sc, mx = sm, shield = 0, notch = (sm > 0 and rollCost > 0) and (rollCost / sm) or 0 },
        }
    end

    local full = data.H.cur >= data.H.mx and data.M.cur >= data.M.mx and data.S.cur >= data.S.mx
    if v.hideFull ~= false and full and not inCombat and not preview then
        root:SetHidden(true)
        return
    end

    local style = Style()
    local scale = (tonumber(v.scale) or 100) / 100
    if scale < 0.5 then scale = 0.5 end
    if scale > 1.5 then scale = 1.5 end
    root:ClearAnchors()
    root:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(v.offsetX) or 0, tonumber(v.offsetY) or 220)
    root:SetScale(scale)

    local width, height, gap, across
    if style == "orbs" then
        width, height, gap, across = 84, 84, 16, true
    elseif style == "classic" then
        width, height, gap, across = 300, 22, 10, false
    elseif style == "segments" then
        width, height, gap, across = 300, 16, 10, false
    else
        width, height, gap, across = 280, 8, 8, false
    end
    local readW = NUM_W + PCT_W + READ_GAP
    local totalW = (across and (width * 3 + gap * 2) or width) + readW
    local totalH = across and height or (height * 3 + gap * 2)
    root:SetDimensions(totalW, totalH)

    local hr, hg, hb = ColorOf("colorH", 0.80, 0.18, 0.16)
    local mr, mg, mb = ColorOf("colorM", 0.22, 0.48, 0.95)
    local sr, sg, sb = ColorOf("colorS", 0.28, 0.72, 0.34)
    local colors = { H = { hr, hg, hb }, M = { mr, mg, mb }, S = { sr, sg, sb } }

    local hp = data.H.cur / data.H.mx
    if lastHealth and v.damageTail ~= false and style ~= "orbs" and hp + 0.015 < lastHealth then
        tailShown = true
        tailToken = tailToken + 1
        local token = tailToken
        rows.H.ghostPct = lastHealth
        zo_callLater(function()
            if token ~= tailToken then return end
            tailShown = false
            if rows.H then rows.H.ghostPct = nil end
            T.Apply()
        end, TAIL_MS)
    end
    if not tailShown then
        rows.H.ghostPct = nil
    end
    lastHealth = hp

    local order = { "H", "M", "S" }
    for i = 1, 3 do
        local key = order[i]
        local row = rows[key]
        local x = across and ((i - 1) * (width + gap)) or 0
        local y = across and 0 or ((i - 1) * (height + gap))
        LayoutRow(row, style, width, height, x, y)

        local pct = data[key].cur / data[key].mx
        if pct < 0 then pct = 0 end
        if pct > 1 then pct = 1 end
        local r, g, b = colors[key][1], colors[key][2], colors[key][3]
        local ghostPct = (key == "H") and row.ghostPct or nil
        if preview and key == "H" then ghostPct = 0.82 end

        if style == "orbs" then
            PaintOrb(row, pct, r, g, b)
        elseif style == "segments" then
            PaintSegs(row, pct, r, g, b, ghostPct)
        else
            PaintFill(row, pct, r, g, b, ghostPct)
        end

        local wantNotch = v.notches ~= false and style ~= "orbs" and data[key].notch and data[key].notch > 0
        if wantNotch then
            PlaceNotch(row, data[key].notch, width, height)
        else
            row.notch:SetHidden(true)
        end

        local shielded = key == "H" and v.shieldRim ~= false and data.H.shield > 0
        row.rim:SetHidden(not shielded)
        if shielded then
            row.rim:ClearAnchors()
            if style == "orbs" then
                row.rim:SetAnchor(BOTTOM, row.holder, BOTTOMLEFT, math.floor(width * 0.5), 2)
                row.rim:SetDimensions(width + 6, 3)
            else
                row.rim:SetAnchor(TOPLEFT, row.holder, TOPLEFT, 0, height + 2)
                row.rim:SetDimensions(width, 3)
            end
            Solid(row.rim, 0.75, 0.90, 1, 0.95)
        end

        if v.showNumbers then
            SetReadout(row.value, "valueText", row, zo_strformat("<<1>>", math.floor(data[key].cur + 0.5)))
            row.value:SetHidden(false)
        else
            SetReadout(row.value, "valueText", row, "")
            row.value:SetHidden(true)
        end
        if v.showPercent then
            SetReadout(row.pct, "pctText", row, zo_strformat("<<1>>%", math.floor(pct * 100 + 0.5)))
            row.pct:SetHidden(false)
        else
            SetReadout(row.pct, "pctText", row, "")
            row.pct:SetHidden(true)
        end
    end

    root:SetHidden(false)
end
