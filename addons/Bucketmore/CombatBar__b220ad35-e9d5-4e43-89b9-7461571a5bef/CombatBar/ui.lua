-- Combat Bar : 表示層(標準バー上のオーバーレイ・もう一方のバー・ULT・クイックスロット・GCD・浮遊ウィジェット)
local CB = CombatBar
local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER

local FIRST_SLOT, LAST_SLOT, ULT_SLOT = CB.FIRST_SLOT, CB.LAST_SLOT, CB.ULT_SLOT
local HB_FRONT, HB_BACK = CB.HB_FRONT, CB.HB_BACK

local FRAME_TEX = "EsoUI/Art/ActionBar/abilityFrame64_up.dds"
local SV

local root, widgetsRoot, gcdWin
local frontOv, backOv = {}, {}
local ultOv, qsOv
local widgetCtl = {}
local ticking = false
local gcdActive = false
local dirty = false

local TICK_NAME = "CombatBarTick"
local GCD_NAME = "CombatBarGCD"
local QS_NAME = "CombatBarQuickslot"

function CB.SetUISV(sv) SV = sv end

local function Font(size)
    return string.format("$(BOLD_FONT)|%d|soft-shadow-thick", size or 20)
end

local function ColorOf(c, defaultA)
    return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or defaultA or 1
end

-- 時間表示の整形。 戻り値: 文字列, 色テーブル
local function FormatRemain(remain)
    local text
    if SV.decimalBelow > 0 and remain < SV.decimalBelow then
        text = string.format("%.1f", remain)
    elseif remain >= 3600 then
        text = string.format("%dh", zo_floor(remain / 3600))
    elseif remain >= 60 then
        text = string.format("%d:%02d", zo_floor(remain / 60), zo_floor(remain % 60))
    else
        text = string.format("%d", zo_ceil(remain))
    end
    local color = (SV.expireStart > 0 and remain <= SV.expireStart) and SV.expireColor or SV.timerColor
    return text, color
end

CB.FormatRemain = FormatRemain

-- 枠線(ROYAL CYBER: 細い金のメタリック枠)
function CB.SetFrame(bd, on, color, thickness)
    local t = thickness or 1
    bd:SetEdgeTexture("", t, t, t)
    local c = color or CB.Theme.gold
    bd:SetEdgeColor(c[1], c[2], c[3], on and (c[4] or 1) or 0)
end

-- ULT蓄積量の文字列と色(実HUDとプレビューで共通)
function CB.FormatUlt(value, cost)
    local mode = SV.ultValueMode
    local text
    if mode == 1 then
        text = tostring(value)
    elseif mode == 3 then
        text = value .. "/" .. cost
    else
        text = (value >= cost) and tostring(value) or (value .. "/" .. cost)
    end
    local usable = cost > 0 and value >= cost
    return text, usable and SV.ultUsableColor or SV.ultColor
end

local function FormatLong(remainMs)
    -- クイックスロット用(長いクールダウン)
    local s = remainMs / 1000
    if s >= 86400 then return string.format("%dd", zo_floor(s / 86400)) end
    if s >= 6000 then return string.format("%dh", zo_floor(s / 3600)) end
    if s >= 600 then return string.format("%dm", zo_floor(s / 60)) end
    if s >= 60 then return string.format("%d:%02d", zo_floor(s / 60), zo_floor(s % 60)) end
    return string.format("%d", zo_ceil(s))
end

---------------------------------------------------------------
-- コントロール生成
---------------------------------------------------------------
local function MakeLabel(name, parent, anchorPoint, relPoint, x, y)
    local l = WM:CreateControl(name, parent, CT_LABEL)
    l:SetAnchor(anchorPoint, parent, relPoint or anchorPoint, x or 0, y or 0)
    l:SetFont(Font(20))
    l:SetHidden(true)
    return l
end

local function MakeFrame(name, parent)
    local t = WM:CreateControl(name, parent, CT_TEXTURE)
    t:SetAnchorFill(parent)
    t:SetTexture(FRAME_TEX)
    t:SetHidden(true)
    return t
end

local function MakeFrontOverlay(slot)
    local btn = GetControl("ActionButton" .. slot)
    if not btn then return nil end
    local c = WM:CreateControl("CB_Front" .. slot, root, CT_CONTROL)
    c:SetAnchorFill(btn)
    local ov = { ctl = c }
    ov.hl = MakeFrame(c:GetName() .. "HL", c)
    ov.timer = MakeLabel(c:GetName() .. "T", c, CENTER)
    ov.stack = MakeLabel(c:GetName() .. "S", c, BOTTOMRIGHT, BOTTOMRIGHT, -2, -2)
    return ov
end

local function MakeBackOverlay(slot)
    local btn = GetControl("ActionButton" .. slot)
    if not btn then return nil end
    local c = WM:CreateControl("CB_Back" .. slot, root, CT_CONTROL)
    local ov = { ctl = c, anchorBtn = btn }
    ov.icon = WM:CreateControl(c:GetName() .. "Icon", c, CT_TEXTURE)
    ov.icon:SetAnchorFill(c)
    ov.frame = WM:CreateControl(c:GetName() .. "Frame", c, CT_TEXTURE)
    ov.frame:SetAnchorFill(c)
    ov.frame:SetTexture(FRAME_TEX)
    ov.hl = MakeFrame(c:GetName() .. "HL", c)
    ov.timer = MakeLabel(c:GetName() .. "T", c, CENTER)
    ov.stack = MakeLabel(c:GetName() .. "S", c, BOTTOMRIGHT, BOTTOMRIGHT, -2, -2)
    return ov
end

local function MakeUltOverlay()
    local btn = GetControl("ActionButton" .. ULT_SLOT)
    if not btn then return nil end
    local c = WM:CreateControl("CB_Ult", root, CT_CONTROL)
    c:SetAnchorFill(btn)
    local ov = { ctl = c }
    ov.timer = MakeLabel("CB_UltT", c, CENTER)
    ov.value = MakeLabel("CB_UltV", c, BOTTOM, BOTTOM, 0, 4)
    return ov
end

local function MakeQuickslotOverlay()
    local btn = GetControl("QuickslotButton")
    if not btn then return nil end
    local c = WM:CreateControl("CB_Qs", root, CT_CONTROL)
    c:SetAnchorFill(btn)
    local ov = { ctl = c }
    ov.timer = MakeLabel("CB_QsT", c, CENTER)
    ov.count = MakeLabel("CB_QsC", c, BOTTOMRIGHT, BOTTOMRIGHT, -2, -2)
    return ov
end

local function MakeGCD()
    gcdWin = WM:CreateTopLevelWindow("CB_GCD")
    gcdWin:SetMouseEnabled(false)
    gcdWin:SetMovable(false)
    local bg = WM:CreateControl("CB_GCDBG", gcdWin, CT_BACKDROP)
    bg:SetAnchorFill(gcdWin)
    bg:SetCenterColor(0, 0, 0, 0.35)
    bg:SetEdgeColor(0, 0, 0, 0)
    bg:SetHidden(true)
    gcdWin.bg = bg
    local fill = WM:CreateControl("CB_GCDFill", gcdWin, CT_TEXTURE)
    fill:SetAnchor(BOTTOMLEFT, gcdWin, BOTTOMLEFT, 0, 0)
    fill:SetColor(1, 1, 1, 0.8)
    fill:SetHidden(true)
    gcdWin.fill = fill
end

-- HUD表示に連動させる(メニュー表示中は隠れる)
local function AttachToHud(ctl)
    if ZO_HUDFadeSceneFragment and HUD_SCENE and HUD_UI_SCENE then
        local ok = pcall(function()
            local frag = ZO_HUDFadeSceneFragment:New(ctl)
            HUD_SCENE:AddFragment(frag)
            HUD_UI_SCENE:AddFragment(frag)
        end)
        return ok
    end
    return false
end
CB.AttachToHud = AttachToHud

function CB.CreateControls()
    if root then return end
    local parent = GetControl("ZO_ActionBar1")
    if not parent then return end
    root = WM:CreateControl("CB_Root", parent, CT_CONTROL)
    root:SetAnchorFill(parent)

    for slot = FIRST_SLOT, LAST_SLOT do
        frontOv[slot] = MakeFrontOverlay(slot)
        backOv[slot] = MakeBackOverlay(slot)
    end
    ultOv = MakeUltOverlay()
    qsOv = MakeQuickslotOverlay()

    widgetsRoot = WM:CreateTopLevelWindow("CB_WidgetsRoot")
    widgetsRoot:SetMouseEnabled(false)
    widgetsRoot:SetDimensions(1, 1)
    widgetsRoot:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
    AttachToHud(widgetsRoot)

    MakeGCD()
    AttachToHud(gcdWin)
end

---------------------------------------------------------------
-- レイアウト(設定変更・UI切替時にだけ実行)
---------------------------------------------------------------
function CB.ApplyLayout()
    if not root then return end
    local scale = (SV.backScale or 80) / 100
    for slot = FIRST_SLOT, LAST_SLOT do
        local ov = backOv[slot]
        if ov then
            local w = ov.anchorBtn:GetWidth()
            local h = ov.anchorBtn:GetHeight()
            if w <= 0 then w = 50 end
            if h <= 0 then h = 50 end
            ov.ctl:ClearAnchors()
            ov.ctl:SetDimensions(w * scale, h * scale)
            ov.ctl:SetAnchor(BOTTOM, ov.anchorBtn, TOP, SV.backOffsetX, SV.backOffsetY)
        end
        local f = frontOv[slot]
        if f then
            f.timer:SetFont(Font(SV.timerSize))
            f.stack:SetFont(Font(SV.stackSize))
        end
        if ov then
            ov.timer:SetFont(Font(zo_max(10, zo_floor(SV.timerSize * scale))))
            ov.stack:SetFont(Font(zo_max(10, zo_floor(SV.stackSize * scale))))
        end
    end
    if ultOv then
        ultOv.timer:SetFont(Font(SV.timerSize))
        ultOv.value:SetFont(Font(SV.ultSize))
    end
    if qsOv then
        qsOv.timer:SetFont(Font(SV.qsSize))
        qsOv.count:SetFont(Font(SV.qsSize))
    end
    if gcdWin then
        gcdWin:ClearAnchors()
        gcdWin:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SV.gcdX, SV.gcdY)
        gcdWin:SetDimensions(SV.gcdW, SV.gcdH)
        gcdWin.fill:SetWidth(SV.gcdW)
        gcdWin.fill:SetColor(ColorOf(SV.gcdColor, 0.8))
        local gcdOn = SV.enabled and SV.gcdEnabled
        CB.SetFrame(gcdWin.bg, SV.designFrame)
        gcdWin.bg:SetHidden(not gcdOn)
        if not gcdOn then gcdWin.fill:SetHidden(true) end
    end
    root:SetHidden(not SV.enabled)
    CB.ApplyStandardBarPosition()
    CB.RefreshIcons()
    if CB.ApplyResources then CB.ApplyResources() end
end

-- 標準バーの移動(有効時のみ。元の位置を覚えて差分を足す)
local origAnchor
function CB.ApplyStandardBarPosition()
    local bar = GetControl("ZO_ActionBar1")
    if not bar then return end
    if not origAnchor then
        local isValid, point, relTo, relPoint, x, y = bar:GetAnchor(0)
        if isValid then origAnchor = { point, relTo, relPoint, x, y } end
    end
    if not origAnchor then return end
    if SV.enabled and SV.manageStandardBar then
        bar:ClearAnchors()
        bar:SetAnchor(origAnchor[1], origAnchor[2], origAnchor[3], origAnchor[4] + SV.stdOffsetX, origAnchor[5] + SV.stdOffsetY)
    elseif CB.stdMoved then
        bar:ClearAnchors()
        bar:SetAnchor(origAnchor[1], origAnchor[2], origAnchor[3], origAnchor[4], origAnchor[5])
    end
    CB.stdMoved = SV.manageStandardBar and true or false
end

---------------------------------------------------------------
-- アイコン(スロット変更時・バー切替時)
---------------------------------------------------------------
function CB.RefreshIcons()
    if not root then return end
    local active = GetActiveHotbarCategory()
    local inactive = (active == HB_FRONT) and HB_BACK or HB_FRONT
    local alpha = (SV.inactiveAlpha or 60) / 100
    local desat = (SV.inactiveDesat or 0) / 100
    for slot = FIRST_SLOT, LAST_SLOT do
        local ov = backOv[slot]
        if ov then
            local id = CB.slotIds[inactive][slot] or 0
            if SV.enabled and SV.showBack and id > 0 then
                ov.icon:SetTexture(GetAbilityIcon(id))
                ov.icon:SetAlpha(alpha)
                ov.icon:SetDesaturation(desat)
                ov.frame:SetAlpha(alpha)
                ov.ctl:SetHidden(false)
            else
                ov.ctl:SetHidden(true)
            end
        end
    end
    CB.UpdateDisplay()
end

---------------------------------------------------------------
-- 表示更新
---------------------------------------------------------------
local function PaintSlot(ov, abilityId, hotbar, slot, t, isBack)
    if not ov then return end
    local showTimer = false
    local timerText, timerColor
    local hlColor
    local stackText

    if abilityId and abilityId > 0 then
        local remain, stacks = CB.GetEffectInfo(abilityId, t)
        local cast = CB.cast
        if cast and cast.hotbar == hotbar and cast.slot == slot and cast.endTime > t then
            -- キャスト/チャネル中はそれを優先して表示
            timerText = string.format("%.1f", cast.endTime - t)
            timerColor = SV.castColor
            showTimer = true
        elseif remain and remain > 0 then
            timerText, timerColor = FormatRemain(remain)
            showTimer = true
        end
        if remain then
            if SV.showHighlight then
                if SV.highlightExpire and remain > 0 and SV.expireStart > 0 and remain <= SV.expireStart then
                    hlColor = SV.highlightExpireColor
                else
                    hlColor = SV.highlightColor
                end
            end
            if SV.showStacks and stacks and stacks > 1 then stackText = tostring(stacks) end
        end
    end

    if showTimer then
        ov.timer:SetText(timerText)
        ov.timer:SetColor(ColorOf(timerColor, 1))
        ov.timer:SetHidden(false)
    else
        ov.timer:SetHidden(true)
    end
    if stackText then
        ov.stack:SetText(stackText)
        ov.stack:SetColor(ColorOf(SV.stackColor, 1))
        ov.stack:SetHidden(false)
    else
        ov.stack:SetHidden(true)
    end
    if hlColor then
        ov.hl:SetColor(ColorOf(hlColor, 0.7))
        ov.hl:SetHidden(false)
    else
        ov.hl:SetHidden(true)
    end
end

local function UpdateUlt(t)
    if not ultOv then return end
    local active = GetActiveHotbarCategory()
    local id = CB.slotIds[active][ULT_SLOT] or 0
    -- 効果時間
    local showTimer = false
    if SV.ultShowDuration and id > 0 then
        local remain = CB.GetEffectInfo(id, t)
        if remain and remain > 0 then
            local text, color = FormatRemain(remain)
            ultOv.timer:SetText(text)
            ultOv.timer:SetColor(ColorOf(color, 1))
            showTimer = true
        end
    end
    ultOv.timer:SetHidden(not showTimer)
    -- 蓄積量
    if SV.ultShowValue and id > 0 then
        local value = CB.GetUltValue()
        local cost = CB.GetUltCost(active)
        local text, color = CB.FormatUlt(value, cost)
        ultOv.value:SetText(text)
        ultOv.value:SetColor(ColorOf(color, 1))
        ultOv.value:SetHidden(false)
    else
        ultOv.value:SetHidden(true)
    end
end

local function UpdateWidgets(t)
    if not widgetsRoot then return end
    for abilityId, cfg in pairs(SV.widgets) do
        local w = widgetCtl[abilityId]
        if w then
            local remain, stacks = CB.GetEffectInfo(abilityId, t)
            if remain then
                w.ctl:SetAlpha(1)
                if remain > 0 then
                    local text, color = FormatRemain(remain)
                    w.timer:SetText(text)
                    w.timer:SetColor(ColorOf(color, 1))
                else
                    w.timer:SetText("")
                end
            else
                w.ctl:SetAlpha((cfg.inactiveAlpha or 0) / 100)
                w.timer:SetText("")
            end
            if SV.showStacks and stacks and stacks > 1 then
                w.stack:SetText(tostring(stacks))
            else
                w.stack:SetText("")
            end
        end
    end
end

function CB.UpdateDisplay()
    if not root or not SV.enabled then return end
    local t = CB.Now()
    local active = GetActiveHotbarCategory()
    local inactive = (active == HB_FRONT) and HB_BACK or HB_FRONT
    for slot = FIRST_SLOT, LAST_SLOT do
        if SV.showFront then
            PaintSlot(frontOv[slot], CB.slotIds[active][slot], active, slot, t, false)
        elseif frontOv[slot] then
            frontOv[slot].timer:SetHidden(true)
            frontOv[slot].stack:SetHidden(true)
            frontOv[slot].hl:SetHidden(true)
        end
        if SV.showBack and backOv[slot] and not backOv[slot].ctl:IsHidden() then
            PaintSlot(backOv[slot], CB.slotIds[inactive][slot], inactive, slot, t, true)
        end
    end
    UpdateUlt(t)
    UpdateWidgets(t)
    local cast = CB.cast
    if cast and cast.endTime <= t then CB.cast = nil end
end

---------------------------------------------------------------
-- 更新ループ: 時間付きの効果かキャストがある間だけ動かす
---------------------------------------------------------------
local function Tick()
    CB.UpdateDisplay()
    local t = CB.Now()
    if not (CB.HasTimedEffect(t) or (CB.cast and CB.cast.endTime > t)) then
        EM:UnregisterForUpdate(TICK_NAME)
        ticking = false
    end
end

function CB.EnsureTicker()
    if ticking then return end
    ticking = true
    EM:RegisterForUpdate(TICK_NAME, SV.tickMs or 100, Tick)
end

-- データ変更の通知を受ける
function CB.MarkChanged(needTick)
    if not root then return end
    CB.UpdateDisplay()
    if needTick then
        local t = CB.Now()
        if CB.HasTimedEffect(t) or (CB.cast and CB.cast.endTime > t) then CB.EnsureTicker() end
    end
end

---------------------------------------------------------------
-- クイックスロット(クールダウンが無い間は何もしない)
---------------------------------------------------------------
function CB.UpdateQuickslot()
    if not qsOv or not SV.enabled then return end
    local slotIndex = GetCurrentQuickslot()
    local remain, duration = GetSlotCooldownInfo(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    remain = remain or 0
    duration = duration or 0
    if SV.qsShowTimer and duration > 5000 and remain > 0 then
        qsOv.timer:SetText(FormatLong(remain))
        qsOv.timer:SetColor(ColorOf(SV.timerColor, 1))
        qsOv.timer:SetHidden(false)
        if not CB.qsPolling then
            CB.qsPolling = true
            EM:RegisterForUpdate(QS_NAME, 500, CB.UpdateQuickslot)
        end
    else
        qsOv.timer:SetHidden(true)
        if CB.qsPolling then
            CB.qsPolling = false
            EM:UnregisterForUpdate(QS_NAME)
        end
    end
    -- 残数(APIがある場合のみ)
    if SV.qsShowCount and GetSlotItemCount then
        local count = GetSlotItemCount(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if count and count > 0 then
            qsOv.count:SetText(tostring(count))
            qsOv.count:SetColor(1, 1, 1, 1)
            qsOv.count:SetHidden(false)
        else
            qsOv.count:SetHidden(true)
        end
    else
        qsOv.count:SetHidden(true)
    end
end

---------------------------------------------------------------
-- GCDトラッカー(GCD中だけ20ms更新)
---------------------------------------------------------------
local function GcdTick()
    local hb = GetActiveHotbarCategory()
    local c1, d1 = GetSlotCooldownInfo(FIRST_SLOT, hb)
    local c2, d2 = GetSlotCooldownInfo(FIRST_SLOT + 1, hb)
    c1, d1, c2, d2 = c1 or 0, d1 or 0, c2 or 0, d2 or 0
    local cooldown, duration = c1, d1
    if c2 > c1 or d2 > d1 then cooldown, duration = c2, d2 end
    if duration <= 1 then duration = 1 end
    local h = (cooldown / duration) * SV.gcdH
    if h <= 0 then
        gcdWin.fill:SetHidden(true)
        EM:UnregisterForUpdate(GCD_NAME)
        gcdActive = false
    else
        gcdWin.fill:SetHeight(h)
        gcdWin.fill:SetHidden(false)
    end
end

function CB.StartGCD()
    if not gcdWin or not SV.enabled or not SV.gcdEnabled or gcdActive then return end
    gcdActive = true
    EM:RegisterForUpdate(GCD_NAME, 20, GcdTick)
end

---------------------------------------------------------------
-- 浮遊エフェクトウィジェット
---------------------------------------------------------------
local function BuildWidget(abilityId, cfg)
    local c = WM:CreateControl("CB_Widget" .. abilityId, widgetsRoot, CT_CONTROL)
    c:SetDimensions(cfg.size, cfg.size)
    c:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, cfg.x, cfg.y)
    local icon = WM:CreateControl(c:GetName() .. "Icon", c, CT_TEXTURE)
    icon:SetAnchorFill(c)
    icon:SetTexture(GetAbilityIcon(abilityId))
    local frame = WM:CreateControl(c:GetName() .. "Frame", c, CT_BACKDROP)
    frame:SetAnchorFill(c)
    frame:SetCenterColor(0, 0, 0, 0)
    CB.SetFrame(frame, SV.designFrame)
    local timer = WM:CreateControl(c:GetName() .. "T", c, CT_LABEL)
    timer:SetAnchor(CENTER, c, CENTER, 0, 0)
    timer:SetFont(Font(zo_max(12, zo_floor(cfg.size * 0.4))))
    local stack = WM:CreateControl(c:GetName() .. "S", c, CT_LABEL)
    stack:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -2, -2)
    stack:SetFont(Font(zo_max(10, zo_floor(cfg.size * 0.3))))
    stack:SetColor(ColorOf(SV.stackColor, 1))
    c:SetHidden(not SV.enabled)
    widgetCtl[abilityId] = { ctl = c, icon = icon, frame = frame, timer = timer, stack = stack }
end

-- 全ウィジェットを作り直す(追加・削除・位置変更後)
function CB.RebuildWidgets()
    if not widgetsRoot then return end
    for id, w in pairs(widgetCtl) do
        if not SV.widgets[id] or not SV.enabled then
            w.ctl:SetHidden(true)
        end
    end
    for abilityId, cfg in pairs(SV.widgets) do
        local w = widgetCtl[abilityId]
        if not w then
            BuildWidget(abilityId, cfg)
        else
            w.ctl:SetHidden(not SV.enabled)
            CB.SetFrame(w.frame, SV.designFrame)
            w.ctl:SetDimensions(cfg.size, cfg.size)
            w.ctl:ClearAnchors()
            w.ctl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, cfg.x, cfg.y)
            w.timer:SetFont(Font(zo_max(12, zo_floor(cfg.size * 0.4))))
            w.stack:SetFont(Font(zo_max(10, zo_floor(cfg.size * 0.3))))
        end
    end
    CB.RefreshSlots()
    CB.UpdateDisplay()
end

-- UIモード切替後に標準バーの元位置を取り直す
local function ForgetAnchor()
    origAnchor = nil
    CB.stdMoved = false
end
function CB.ForgetStandardAnchor() ForgetAnchor() end

-- ULTだけを軽く更新(ULT量変化の頻繁なイベント用)
function CB.UpdateUltimate()
    if root and SV.enabled then UpdateUlt(CB.Now()) end
end
