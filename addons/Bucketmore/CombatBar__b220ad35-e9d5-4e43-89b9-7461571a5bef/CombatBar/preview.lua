-- Combat Bar : 設定画面プレビュー(ダミー表示)
-- 実際のスキル効果追跡・イベント・更新ループとは一切つながらない。
-- 更新は「設定画面を開いている間に設定が変わった時」だけ。閉じたら非表示にして何も動かさない。
local CB = CombatBar
local WM = WINDOW_MANAGER

local win
local panelBg, title
local resHolders, resBars = {}, {}
local backSlots, frontSlots = {}, {}
local ultBox, qsBox, gcdBox, widgetBox
local backLabel
local sceneHooked = false

CB.previewActive = false

local function Font(size)
    return string.format("$(BOLD_FONT)|%d|soft-shadow-thick", size or 18)
end

local function Col(c, a)
    return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or a or 1
end

-- 小さな枠付きボックス(スロット代わり)
local function MakeBox(name)
    local box = { ctl = WM:CreateControl(name, win, CT_CONTROL) }
    box.fill = WM:CreateControl(name .. "F", box.ctl, CT_TEXTURE)
    box.fill:SetAnchorFill(box.ctl)
    box.fill:SetColor(0.12, 0.14, 0.2, 1)
    box.hl = WM:CreateControl(name .. "H", box.ctl, CT_TEXTURE)
    box.hl:SetAnchorFill(box.ctl)
    box.hl:SetHidden(true)
    box.frame = WM:CreateControl(name .. "R", box.ctl, CT_BACKDROP)
    box.frame:SetAnchorFill(box.ctl)
    box.frame:SetCenterColor(0, 0, 0, 0)
    box.timer = WM:CreateControl(name .. "T", box.ctl, CT_LABEL)
    box.timer:SetAnchor(CENTER, box.ctl, CENTER, 0, 0)
    box.stack = WM:CreateControl(name .. "S", box.ctl, CT_LABEL)
    box.stack:SetAnchor(BOTTOMRIGHT, box.ctl, BOTTOMRIGHT, -2, -2)
    return box
end

local function Build()
    if win then return end
    win = WM:CreateTopLevelWindow("CB_Preview")
    win:SetMouseEnabled(false)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetDrawTier(DT_HIGH)
    win:SetHidden(true)

    panelBg = WM:CreateControl("CB_PvBg", win, CT_BACKDROP)
    panelBg:SetAnchorFill(win)
    panelBg:SetCenterColor(0.03, 0.04, 0.07, 0.88)

    title = WM:CreateControl("CB_PvTitle", win, CT_LABEL)
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 12, 8)

    for _, kind in ipairs(CB.ResourceKinds) do
        local holder = WM:CreateControl("CB_PvRes_" .. kind, win, CT_CONTROL)
        resHolders[kind] = holder
        resBars[kind] = CB.BuildBarControls(holder, "CB_PvRes_" .. kind)
    end

    for i = 1, 5 do
        backSlots[i] = MakeBox("CB_PvBack" .. i)
        frontSlots[i] = MakeBox("CB_PvFront" .. i)
    end
    backLabel = WM:CreateControl("CB_PvBackLabel", win, CT_LABEL)

    ultBox = MakeBox("CB_PvUlt")
    ultBox.value = WM:CreateControl("CB_PvUltV", ultBox.ctl, CT_LABEL)
    ultBox.value:SetAnchor(BOTTOM, ultBox.ctl, BOTTOM, 0, 4)
    qsBox = MakeBox("CB_PvQs")

    gcdBox = {}
    gcdBox.ctl = WM:CreateControl("CB_PvGcd", win, CT_BACKDROP)
    gcdBox.ctl:SetCenterColor(0, 0, 0, 0.35)
    gcdBox.fill = WM:CreateControl("CB_PvGcdFill", win, CT_TEXTURE)
    gcdBox.fill:SetAnchor(BOTTOMLEFT, gcdBox.ctl, BOTTOMLEFT, 0, 0)

    widgetBox = MakeBox("CB_PvWidget")
end

local function SetBoxFrame(box, sv)
    CB.SetFrame(box.frame, sv.designFrame, CB.Theme.gold, 1)
end

local function SetBox(box, sv, size, timerText, timerColor, stackText, hlColor, alpha)
    box.ctl:SetDimensions(size, size)
    box.ctl:SetAlpha(alpha or 1)
    SetBoxFrame(box, sv)
    local fs = zo_max(10, zo_floor(size * 0.42))
    box.timer:SetFont(Font(fs))
    box.stack:SetFont(Font(zo_max(10, zo_floor(size * 0.34))))
    if timerText then
        box.timer:SetText(timerText)
        box.timer:SetColor(Col(timerColor, 1))
        box.timer:SetHidden(false)
    else
        box.timer:SetHidden(true)
    end
    if stackText then
        box.stack:SetText(stackText)
        box.stack:SetColor(Col(sv.stackColor, 1))
        box.stack:SetHidden(false)
    else
        box.stack:SetHidden(true)
    end
    if hlColor then
        box.hl:SetColor(hlColor[1], hlColor[2], hlColor[3], (hlColor[4] or 0.7) * 0.5)
        box.hl:SetHidden(false)
    else
        box.hl:SetHidden(true)
    end
end

-- 設定値に合わせて全体を描き直す(開いている間の設定変更時だけ呼ばれる)
local function Refresh()
    local sv = CB.sv
    if not win or not sv then return end

    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.previewX, sv.previewY)
    title:SetFont(Font(16))
    title:SetText(CB.T("PREVIEW_TITLE"))
    title:SetColor(Col(CB.Theme.gold, 1))
    CB.SetFrame(panelBg, sv.designFrame, CB.Theme.gold, 1)

    -- HP・MP・STバー(ダミー値)
    local sample = { hp = { 28500, 30000 }, mp = { 18000, 20000 }, st = { 15000, 18000 } }
    local y = 34
    local maxW = 0
    for _, kind in ipairs(CB.ResourceKinds) do
        local cfg = sv.resources[kind]
        local holder = resHolders[kind]
        local b = resBars[kind]
        holder:ClearAnchors()
        holder:SetAnchor(TOPLEFT, win, TOPLEFT, 16, y)
        CB.StyleBar(b, cfg, holder, CB.ResourceLabel[kind])
        CB.SetBarValues(b, cfg, sample[kind][1], sample[kind][2])
        b.body:SetHidden(not cfg.enabled)
        if cfg.enabled then
            y = y + cfg.h + 6
            if cfg.w > maxW then maxW = cfg.w end
        end
    end
    y = y + 8

    -- アクションバー(もう一方のバー → 標準バーの順)
    local slotSize = 48
    local gap = 8
    local scale = (sv.backScale or 80) / 100
    local backSize = zo_floor(slotSize * scale)
    local invAlpha = (sv.inactiveAlpha or 60) / 100

    backLabel:SetFont(Font(14))
    backLabel:SetText(CB.T("PREVIEW_BACK"))
    backLabel:SetColor(Col(CB.Theme.cyan, 1))
    backLabel:ClearAnchors()
    backLabel:SetAnchor(TOPLEFT, win, TOPLEFT, 16, y)
    backLabel:SetHidden(not sv.showBack)
    y = y + 18

    local rowW = 5 * slotSize + 4 * gap
    for i = 1, 5 do
        local x = 16 + (i - 1) * (slotSize + gap)
        local box = backSlots[i]
        box.ctl:ClearAnchors()
        box.ctl:SetAnchor(TOPLEFT, win, TOPLEFT, x + (slotSize - backSize) / 2, y)
        local timerText, timerColor
        if i == 1 then timerText, timerColor = CB.FormatRemain(20) end
        SetBox(box, sv, backSize, timerText, timerColor, nil, nil, invAlpha)
        box.ctl:SetHidden(not sv.showBack)
    end
    if sv.showBack then y = y + backSize + 10 end

    for i = 1, 5 do
        local x = 16 + (i - 1) * (slotSize + gap)
        local box = frontSlots[i]
        box.ctl:ClearAnchors()
        box.ctl:SetAnchor(TOPLEFT, win, TOPLEFT, x, y)
        local timerText, timerColor, stackText, hl
        if i == 1 then
            timerText, timerColor = CB.FormatRemain(12)
            if sv.showHighlight then hl = sv.highlightColor end
        elseif i == 2 then
            timerText, timerColor = CB.FormatRemain(1.5)
            if sv.showHighlight then hl = (sv.highlightExpire and sv.expireStart >= 1.5) and sv.highlightExpireColor or sv.highlightColor end
        elseif i == 3 then
            timerText, timerColor = CB.FormatRemain(8)
            if sv.showStacks then stackText = "3" end
            if sv.showHighlight then hl = sv.highlightColor end
        elseif i == 4 and sv.showCast then
            timerText, timerColor = "1.2", sv.castColor
        end
        SetBox(box, sv, slotSize, timerText, timerColor, stackText, hl, 1)
        box.ctl:SetHidden(false)
    end

    -- ULT / ポーション・アイテム
    local ux = 16 + rowW + 16
    ultBox.ctl:ClearAnchors()
    ultBox.ctl:SetAnchor(TOPLEFT, win, TOPLEFT, ux, y - 4)
    local ultTimer, ultTimerColor
    if sv.ultShowDuration then ultTimer, ultTimerColor = CB.FormatRemain(9) end
    SetBox(ultBox, sv, 56, ultTimer, ultTimerColor, nil, nil, 1)
    ultBox.value:SetFont(Font(sv.ultSize))
    if sv.ultShowValue then
        local text, color = CB.FormatUlt(187, 250)
        ultBox.value:SetText(text)
        ultBox.value:SetColor(Col(color, 1))
        ultBox.value:SetHidden(false)
    else
        ultBox.value:SetHidden(true)
    end

    qsBox.ctl:ClearAnchors()
    qsBox.ctl:SetAnchor(TOPLEFT, win, TOPLEFT, ux + 64, y - 4)
    SetBox(qsBox, sv, 56, sv.qsShowTimer and "45" or nil, sv.timerColor, sv.qsShowCount and "3" or nil, nil, 1)
    qsBox.timer:SetFont(Font(sv.qsSize))
    qsBox.stack:SetFont(Font(sv.qsSize))
    y = y + slotSize + 14

    -- パネル全体の大きさ
    local width = zo_max(16 + rowW + 16 + 64 + 56 + 16, 16 + maxW + 16)
    width = zo_max(width, 420) + 90
    win:SetDimensions(width, y + 6)

    -- GCDゲージ(右側)
    local gh = zo_min(sv.gcdH, 150)
    gcdBox.ctl:ClearAnchors()
    gcdBox.ctl:SetAnchor(TOPRIGHT, win, TOPRIGHT, -20, 34)
    gcdBox.ctl:SetDimensions(sv.gcdW, gh)
    CB.SetFrame(gcdBox.ctl, sv.designFrame, CB.Theme.gold, 1)
    gcdBox.fill:SetDimensions(sv.gcdW, gh * 0.5)
    gcdBox.fill:SetColor(Col(sv.gcdColor, 0.85))
    gcdBox.ctl:SetHidden(not sv.gcdEnabled)
    gcdBox.fill:SetHidden(not sv.gcdEnabled)

    -- 個別表示ウィジェットの見本(登録がある時だけ)
    local hasWidget = next(sv.widgets) ~= nil
    widgetBox.ctl:ClearAnchors()
    widgetBox.ctl:SetAnchor(TOPRIGHT, win, TOPRIGHT, -20 - sv.gcdW - 16, 34)
    local tText, tColor = CB.FormatRemain(8)
    SetBox(widgetBox, sv, 56, tText, tColor, nil, nil, 1)
    widgetBox.ctl:SetHidden(not hasWidget)
end

function CB.RefreshPreview()
    if CB.previewActive then Refresh() end
end

function CB.PreviewShow()
    Build()
    -- 実HUDに戻ったら必ず消す(閉じ検知が働かない場合の保険)
    if not sceneHooked and HUD_SCENE and SCENE_SHOWN then
        sceneHooked = true
        pcall(function()
            HUD_SCENE:RegisterCallback("StateChange", function(_, newState)
                if newState == SCENE_SHOWN then CB.PreviewHide() end
            end)
        end)
    end
    CB.previewActive = true
    Refresh()
    win:SetHidden(false)
end

function CB.PreviewHide()
    CB.previewActive = false
    if win then win:SetHidden(true) end
end
