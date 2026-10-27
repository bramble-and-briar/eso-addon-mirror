local RH = RestyleHelper
local L = RH.L
local WM = WINDOW_MANAGER

RH.ui = { checks = {}, selectedPreset = nil }

---------------------------------------------------------------------------
-- 部品
---------------------------------------------------------------------------
function RH.AttachTip(ctl, text)
    if not ctl or not text then return end
    local function show(self)
        pcall(function()
            InitializeTooltip(InformationTooltip, self, RIGHT, -8, 0, LEFT)
            InformationTooltip:AddLine(text, "", 1, 1, 1, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_LEFT, true)
        end)
    end
    local function hide() pcall(ClearTooltip, InformationTooltip) end
    ctl:SetMouseEnabled(true)
    ZO_PostHookHandler(ctl, "OnMouseEnter", show)
    ZO_PostHookHandler(ctl, "OnMouseExit", hide)
end

local function BuildGrip(win, name, posKey)
    -- 右下の三角マーク: ドラッグでウィンドウの大きさ(表示倍率は変えない)を変更 / ダブルクリックで初期サイズ
    local grip = WM:CreateControl(name .. "Grip", win, CT_BUTTON)
    grip:SetDimensions(26, 26)
    grip:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -1, -1)
    grip:SetMouseEnabled(true)
    grip:SetDrawLevel(100)
    local pieces = {}
    local function Line(i, x1, y1, x2, y2)
        local t = WM:CreateControl(name .. "GripL" .. i, grip, CT_LINE)
        t:SetThickness(2)
        t:SetAnchor(TOPLEFT, grip, TOPLEFT, x1, y1)
        t:SetAnchor(BOTTOMRIGHT, grip, TOPLEFT, x2, y2)
        t:SetDrawLevel(101)
        pcall(t.SetColor, t, 1, 0.8, 0.1, 1)
        pieces[#pieces + 1] = t
    end
    -- 右下が直角の三角形(ふち取り + 斜線のしま)
    Line(1, 3, 21, 21, 21)      -- 下辺
    Line(2, 21, 3, 21, 21)      -- 右辺
    Line(3, 7, 21, 21, 7)       -- 斜線
    Line(4, 12, 21, 21, 12)
    Line(5, 17, 21, 21, 17)
    local function Tint(r, g, b)
        for _, t in ipairs(pieces) do pcall(t.SetColor, t, r, g, b, 1) end
    end
    local function ApplySize(nw, nh, save)
        local base = win.rhBase
        nw = math.max(base.w, nw); nh = math.max(base.h, nh)
        local dw, dh = nw - base.w, nh - base.h
        win:SetDimensions(nw, nh)
        for _, fn in ipairs(win.rhLayout) do fn(dw, dh) end
        if save then
            if dw == 0 and dh == 0 then RH.sv.winSize[posKey] = nil else RH.sv.winSize[posKey] = { w = nw, h = nh } end
        end
    end
    win.rhApplySize = ApplySize
    local lastClick = 0
    grip:SetHandler("OnMouseEnter", function() Tint(1, 1, 1) end)
    grip:SetHandler("OnMouseExit", function() Tint(1, 0.8, 0.1) end)
    grip:SetHandler("OnMouseDown", function(self, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local now = GetFrameTimeMilliseconds()
        if now - lastClick < 350 then ApplySize(0, 0, true); lastClick = 0; return end
        lastClick = now
        self.dragging = true
        win:SetMovable(false)
        self:SetHandler("OnUpdate", function()
            if not self.dragging then return end
            if IsMouseButtonDown and not IsMouseButtonDown(MOUSE_BUTTON_INDEX_LEFT) then
                self.dragging = false; self:SetHandler("OnUpdate", nil); win:SetMovable(true); return
            end
            local mx, my = GetUIMousePosition()
            local rootW, rootH = GuiRoot:GetDimensions()
            local nw = math.min(mx - win:GetLeft() + 10, rootW - win:GetLeft())
            local nh = math.min(my - win:GetTop() + 10, rootH - win:GetTop())
            ApplySize(math.floor(nw), math.floor(nh), true)
        end)
    end)
    grip:SetHandler("OnMouseUp", function(self)
        self.dragging = false
        self:SetHandler("OnUpdate", nil)
        win:SetMovable(true)
    end)
    RH.AttachTip(grip, L.TIP_resize)
    win.rhGrip = grip
end

local function CreateWindow(name, w, h, titleText, posKey, defX, defY)
    local win = WM:CreateTopLevelWindow(name)
    win:SetDimensions(w, h)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetDrawTier(DT_HIGH)
    win:SetHidden(true)
    win:ClearAnchors()
    local pos = RH.sv[posKey]
    RH.sv.winSize = RH.sv.winSize or {}
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos and pos.x or defX, pos and pos.y or defY)
    win:SetHandler("OnMoveStop", function(self)
        RH.sv[posKey] = { x = self:GetLeft(), y = self:GetTop() }
    end)
    win.rhLayout = {}
    win.rhBase = { w = w, h = h }


    local bg = WM:CreateControlFromVirtual(name .. "BG", win, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(win)

    local title = WM:CreateControl(name .. "Title", win, CT_LABEL)
    title:SetFont("ZoFontWinH4")
    title:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
    title:SetText(titleText)
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 12, 8)

    local close = WM:CreateControlFromVirtual(name .. "Close", win, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -6, 6)
    close:SetHandler("OnClicked", function() win:SetHidden(true) end)
    BuildGrip(win, name, posKey)
    return win
end

-- ウィンドウを広げたとき追従させる部品を登録する(x,y,w,h は初期値。mx,my,mw,mh は増加分に掛ける係数)
local function Track(win, ctl, x, y, w, h, mx, my, mw, mh)
    table.insert(win.rhLayout, function(dw, dh)
        if (mx or 0) ~= 0 or (my or 0) ~= 0 then
            ctl:ClearAnchors()
            ctl:SetAnchor(TOPLEFT, win, TOPLEFT, x + (mx or 0) * dw, y + (my or 0) * dh)
        end
        if (mw or 0) ~= 0 or (mh or 0) ~= 0 then
            ctl:SetDimensions(w + (mw or 0) * dw, h + (mh or 0) * dh)
        end
    end)
end

-- 構築完了: 高さを確定し、それを最小サイズにして、保存済みのサイズを復元する
local function FinishWindow(win, posKey, y)
    win:SetHeight(y)
    win.rhBase.h = y
    local sz = RH.sv.winSize and RH.sv.winSize[posKey]
    if sz and win.rhApplySize then win.rhApplySize(sz.w or 0, sz.h or 0, false) end
end

local function Label(parent, name, text, x, y, font, color)
    local l = WM:CreateControl(parent:GetName() .. name, parent, CT_LABEL)
    l:SetFont(font or "ZoFontGameSmall")
    l:SetColor((color or ZO_NORMAL_TEXT):UnpackRGBA())
    l:SetText(text)
    l:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    return l
end

local function Button(parent, name, text, x, y, w, onClick)
    local b = WM:CreateControlFromVirtual(parent:GetName() .. name, parent, "ZO_DefaultButton")
    b:SetDimensions(w, 28)
    b:SetText(text)
    b:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    b:SetHandler("OnClicked", onClick)
    return b
end

local function TintButton(b, r, g, bl)
    pcall(function()
        b:SetNormalFontColor(r, g, bl, 1)
        b:SetMouseOverFontColor(math.min(1, r + 0.25), math.min(1, g + 0.25), math.min(1, bl + 0.25), 1)
        b:SetPressedFontColor(r * 0.8, g * 0.8, bl * 0.8, 1)
    end)
end

local function Check(parent, name, text, x, y, getter, setter, labelWidth, tip)
    local c = WM:CreateControlFromVirtual(parent:GetName() .. name, parent, "ZO_CheckButton")
    c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y + 3)
    ZO_CheckButton_SetLabelText(c, text)
    -- ウィンドウ幅からはみ出さないよう幅を制限
    pcall(function()
        local maxW = labelWidth or ((parent:GetWidth() or 300) - x - 12 - 26)
        ZO_CheckButton_SetLabelWrapMode(c, TEXT_WRAP_MODE_ELLIPSIS, maxW)
    end)
    ZO_CheckButton_SetCheckState(c, getter())
    ZO_CheckButton_SetToggleFunction(c, function(_, checked) setter(checked) end)
    table.insert(RH.ui.checks, { control = c, getter = getter })
    if tip then RH.AttachTip(c, tip); pcall(function() RH.AttachTip(ZO_CheckButton_GetLabelControl(c), tip) end) end
    return c
end

local function EditBox(parent, name, x, y, w, h, multi)
    local bd = WM:CreateControlFromVirtual(parent:GetName() .. name .. "BD", parent, "ZO_EditBackdrop")
    bd:SetDimensions(w, h)
    bd:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    local eb = WM:CreateControlFromVirtual(parent:GetName() .. name, bd,
        multi and "ZO_DefaultEditMultiLineForBackdrop" or "ZO_DefaultEditForBackdrop")
    eb:SetMaxInputChars(3000)
    if multi then
        if eb.SetMultiLine then eb:SetMultiLine(true) end
        if eb.SetNewLineEnabled then eb:SetNewLineEnabled(true) end
    end
    eb:SetHandler("OnEscape", function(self) self:LoseFocus() end)
    return eb
end

local function RefreshChecks()
    for _, c in ipairs(RH.ui.checks) do
        if c.refresh then c.refresh() else ZO_CheckButton_SetCheckState(c.control, c.getter()) end
    end
end

---------------------------------------------------------------------------
-- メインパネル
---------------------------------------------------------------------------
local function BuildPanel()
    local W = 360
    local win = CreateWindow("RestyleHelperPanel", W, 100, L.TITLE, "panelPos", 60, 140)
    RH.ui.panel = win
    RH.ui.modeLabel = Label(win, "ModeLbl", L.MODE_PORTABLE, 12, 26, "ZoFontGameSmall", ZO_ERROR_COLOR or ZO_NORMAL_TEXT)
    RH.ui.modeLabel:SetHidden(true)
    local pad, half = 12, (W - 12 * 2 - 8) / 2
    local y = 40

    Button(win, "RandAll",   L.BTN_RANDOM_ALL,   pad,            y, half, function() RH.Randomize("all") end)
    Button(win, "RandTheme", L.BTN_RANDOM_THEME, pad + half + 8, y, half, function() RH.Randomize("theme") end)
    y = y + 32
    Button(win, "RandStyle", L.BTN_RANDOM_STYLE, pad,            y, half, function() RH.Randomize("style") end)
    Button(win, "RandDye",   L.BTN_RANDOM_DYE,   pad + half + 8, y, half, function() RH.Randomize("dye") end)
    y = y + 32
    Button(win, "DyeOrder",  L.BTN_DYE_ORDER,    pad,            y, half, function() RH.ShuffleDyeOrder() end)
    Button(win, "DyeChaos",  L.BTN_DYE_CHAOS,    pad + half + 8, y, half, function() RH.Randomize("chaos") end)
    y = y + 32
    Button(win, "Undo",      L.BTN_UNDO,         pad,            y, W - pad * 2, function() RH.Undo() end)
    y = y + 32
    Button(win, "Colors",    L.BTN_COLORS,       pad,            y, W - pad * 2, function() RH.ShowColorsWindow(not RH.ui.colors or RH.ui.colors:IsHidden()) end)
    y = y + 32
    Button(win, "Preview", L.BTN_PREVIEW, pad, y, W - pad * 2, function() RH.RefreshPreview(RH.GetCurrentOutfitManipulator()) end)
    y = y + 40

    -- スタイル適用状況(部位ごとの ○ / × 表示)
    RH.ui.coverTitle = Label(win, "CoverTitle", L.COVER_TITLE .. "  " .. L.COVER_NONE, pad, y, "ZoFontGameBold", ZO_SELECTED_TEXT)
    RH.ui.coverTitle:SetWidth(W - pad * 2)
    RH.ui.coverTitle:SetMaxLineCount(1)
    y = y + 22
    RH.ui.coverCells = {}
    local cw = (W - pad * 2) / #RH.armorSlots
    for i, slot in ipairs(RH.armorSlots) do
        local nameLbl = WM:CreateControl(win:GetName() .. "CoverName" .. i, win, CT_LABEL)
        nameLbl:SetFont("ZoFontGameSmall")
        nameLbl:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
        nameLbl:SetText(RH.GetSlotName(slot))
        nameLbl:SetDimensions(cw, 16)
        nameLbl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        nameLbl:SetAnchor(TOPLEFT, win, TOPLEFT, pad + (i - 1) * cw, y)

        local mark = WM:CreateControl(win:GetName() .. "CoverMark" .. i, win, CT_LABEL)
        mark:SetFont("ZoFontWinH3")
        mark:SetDimensions(cw, 24)
        mark:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        mark:SetAnchor(TOPLEFT, win, TOPLEFT, pad + (i - 1) * cw, y + 16)
        mark:SetText("-")
        mark:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
        RH.ui.coverCells[slot] = mark

        local wl = WM:CreateControl(win:GetName() .. "CoverWeight" .. i, win, CT_LABEL)
        wl:SetFont("ZoFontGameSmall")
        wl:SetDimensions(cw, 16)
        wl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        wl:SetAnchor(TOPLEFT, win, TOPLEFT, pad + (i - 1) * cw, y + 40)
        wl:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
        wl:SetText("")
        RH.ui.coverWeights = RH.ui.coverWeights or {}
        RH.ui.coverWeights[slot] = wl
    end
    y = y + 58
    Label(win, "CoverLegend", L.COVER_LEGEND, pad, y, "ZoFontGameSmall", ZO_DISABLED_TEXT)
    y = y + 24

    Label(win, "LockHdr", L.HDR_LOCK, pad, y, "ZoFontGameBold", ZO_SELECTED_TEXT)
    y = y + 24
    for i, slot in ipairs(RH.armorSlots) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        Check(win, "Lock" .. slot, RH.GetSlotName(slot), pad + col * (half + 8), y + row * 24,
            function() return RH.sv.locks[slot] == true end,
            function(v) RH.sv.locks[slot] = v or nil end, half - 30)
    end
    y = y + math.ceil(#RH.armorSlots / 2) * 24 + 10

    Label(win, "OptHdr", L.HDR_OPTIONS, pad, y, "ZoFontGameBold", ZO_SELECTED_TEXT)
    y = y + 24
    local opts = {
        { "weaponStyle",    L.OPT_WEAPON_STYLE },
        { "weaponDye",      L.OPT_WEAPON_DYE },
        { "unifyWeight",    L.OPT_UNIFY_WEIGHT },
        { "lockDyes",       L.OPT_LOCK_DYES },
        { "keepDyes",       L.OPT_KEEP_DYES },
        { "preferRobe",     L.OPT_PREFER_ROBE },
        { "portable",       L.OPT_PORTABLE },
        { "orderPerSlot",   L.OPT_ORDER_PER_SLOT },
        { "favoritesOnly",  L.OPT_FAVORITES_ONLY },
        { "hideMissing",    L.OPT_HIDE_MISSING },
        { "previewUnownedStyles", L.OPT_PREVIEW_UNOWNED_STYLE },
        { "previewUnownedDyes",   L.OPT_PREVIEW_UNOWNED_DYE },
        { "shareMessages",  L.OPT_SHARE_MSGS },
    }
    for _, o in ipairs(opts) do
        local key = o[1]
        Check(win, "Opt" .. key, o[2], pad, y,
            function() if key == "shareMessages" or key == "keepDyes" or key == "portable" then return RH.sv[key] ~= false end return RH.sv[key] == true end,
            function(v)
                RH.sv[key] = v
                if key == "previewUnownedStyles" then RH.styleIndex = nil end
                if key == "previewUnownedDyes" and RH.RefreshColorsWindow then RH.RefreshColorsWindow() end
            end, nil, L["TIP_" .. key])
        y = y + 24
    end

    -- スタイル統一の最小部位数(− / + で 1〜7)
    local minLbl = Label(win, "ThemeMinLbl", "", pad, y + 5, "ZoFontGame", ZO_NORMAL_TEXT)
    minLbl:SetMouseEnabled(true)
    RH.AttachTip(minLbl, L.TIP_themeMin)
    local function RefreshMin()
        minLbl:SetText(string.format(L.OPT_THEME_MIN, RH.sv.themeMinSlots or 5))
    end
    Button(win, "ThemeMinDec", "-", W - pad - 64, y, 28, function()
        RH.sv.themeMinSlots = math.max(1, (RH.sv.themeMinSlots or 5) - 1); RefreshMin()
    end)
    Button(win, "ThemeMinInc", "+", W - pad - 28, y, 28, function()
        RH.sv.themeMinSlots = math.min(#RH.armorSlots, (RH.sv.themeMinSlots or 5) + 1); RefreshMin()
    end)
    table.insert(RH.ui.checks, { refresh = RefreshMin })
    RefreshMin()
    y = y + 36

    Track(win, Button(win, "ChestAll", L.BTN_CHEST_TO_ALL, pad, y, W - pad * 2, function() RH.ApplyChestToAll() end), pad, y, W - pad * 2, 28, 0, 0, 1, 0)
    y = y + 32
    local third = math.floor((W - pad * 2 - 16) / 3)
    for i, k in ipairs({ "light", "medium", "heavy" }) do
        Button(win, "Weight" .. k, L["WEIGHT_" .. k], pad + (i - 1) * (third + 8), y, third, function() RH.SwitchWeight(k) end)
    end
    y = y + 32
    Track(win, Button(win, "FavCur", L.BTN_FAV_CURRENT, pad, y, W - pad * 2, function() RH.FavoriteCurrent() end), pad, y, W - pad * 2, 28, 0, 0, 1, 0)
    y = y + 32
    RH.ui.unownedLabel = Label(win, "UnownedLbl", L.WARN_UNOWNED, pad, y, "ZoFontGameSmall", ZO_ERROR_COLOR)
    RH.ui.unownedLabel:SetWidth(W - pad * 2)
    RH.ui.unownedLabel:SetMaxLineCount(2)
    RH.ui.unownedLabel:SetHidden(true)
    y = y + 34
    Button(win, "Fav",      L.BTN_FAVORITES,    pad,            y, half, function() RH.ShowFavoritesWindow(true) end)
    Button(win, "Share",    L.BTN_SHARE,        pad + half + 8, y, half, function() RH.ShowShareWindow(true) end)
    y = y + 38
    local hint = Label(win, "ChLockHint", L.HINT_CHANNEL_LOCK, pad, y, "ZoFontGameSmall", ZO_DISABLED_TEXT)
    hint:SetWidth(W - pad * 2)
    y = y + 24

    FinishWindow(win, 'panelPos', y)
end

local COVER_MARKS = {
    ok      = { L.COVER_M_OK, 0.45, 0.9, 0.45 },
    sub     = { L.COVER_M_SUB, 0.95, 0.8, 0.3 },
    missing = { L.COVER_M_MISS, 1.0, 0.3, 0.3 },
    hidden  = { L.COVER_HIDDEN_MARK, 1.0, 0.2, 0.2 },
}

function RH.RefreshCoverage()
    local ui = RH.ui
    if not ui.coverCells then return end
    local cov = RH.coverage
    if cov then
        ui.coverTitle:SetText(L.COVER_TITLE .. ": " .. tostring(cov.name))
    else
        ui.coverTitle:SetText(L.COVER_TITLE .. "  " .. L.COVER_NONE)
    end
    -- 各部位の防具の重さ(軽/中/重)を四角の下に表示
    local om = RH.GetCurrentOutfitManipulator and RH.GetCurrentOutfitManipulator()
    for slot, wl in pairs(ui.coverWeights or {}) do
        local txt = ""
        local sm = om and RH.GetSlotManip(om, slot)
        local st = sm and RH.GetSlotState(sm)
        if st and st.id ~= 0 and GetOutfitStyleVisualArmorType then
            local refId = GetCollectibleReferenceId and GetCollectibleReferenceId(st.id) or st.id
            local at = GetOutfitStyleVisualArmorType(refId)
            at = RH.NormWeight(at)
            if at ~= 0 then txt = L["WSHORT_" .. at] or "" end
        end
        wl:SetText(txt)
    end
    for slot, mark in pairs(ui.coverCells) do
        local st = cov and cov.states[slot]
        local def = st and COVER_MARKS[st]
        -- 緑 = 所持している / 赤 = 未所持のスタイルを使っている
        if def and (st == "ok" or st == "sub") and RH.unownedSlots and RH.unownedSlots[slot] then
            def = COVER_MARKS.missing
        end
        if def then
            mark:SetText(def[1])
            mark:SetColor(def[2], def[3], def[4], 1)
        else
            mark:SetText("-")
            mark:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
        end
    end
end

function RH.ShowPanel(show)
    if not RH.ui.panel then return end
    RH.ui.panel:SetHidden(not show)
    if show then
        if RH.ui.modeLabel then RH.ui.modeLabel:SetHidden(RH.stationOpen and true or false) end
        RefreshChecks()
    end
end

function RH.TogglePanel()
    if not RH.ui.panel then return end
    local show = RH.ui.panel:IsHidden()
    RH.ShowPanel(show)
    RH.sv.showPanel = show
end

---------------------------------------------------------------------------
-- 共有 / プリセットウィンドウ
---------------------------------------------------------------------------
local function RefreshPresetCombo()
    local combo = RH.ui.combo
    if not combo then return end
    combo:ClearItems()
    RH.ui.selectedPreset = nil
    for i, p in ipairs(RH.sv.presets) do
        local entry = combo:CreateItemEntry(p.name, function() RH.ui.selectedPreset = i end)
        combo:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
    end
    if #RH.sv.presets > 0 then
        combo:SelectItemByIndex(#RH.sv.presets)
        RH.ui.selectedPreset = #RH.sv.presets
    else
        combo:SetSelectedItemText(L.NO_PRESET)
    end
end
RH.RefreshPresetList = RefreshPresetCombo

local function GetSelectedPreset()
    local p = RH.ui.selectedPreset and RH.sv.presets[RH.ui.selectedPreset]
    if not p then RH.Msg(L.MSG_SELECT_PRESET) end
    return p
end

local function ShowString(str)
    local eb = RH.ui.stringEdit
    eb:SetText(str)
    eb:TakeFocus()
    eb:SelectAll()
end

function RH.SetImportText(str, name)
    if not RH.ui.stringEdit then return end
    RH.ui.stringEdit:SetText(str or "")
    if name and name ~= "" then RH.ui.nameEdit:SetText(name) end
end

local function ParseFromEdit()
    local name, body, entries = RH.ParseShareText(RH.ui.stringEdit:GetText())
    if not entries then RH.Msg(L.MSG_PARSE_ERROR) end
    return name, body, entries
end

local function BuildShareWindow()
    local W = 480
    local win = CreateWindow("RestyleHelperShare", W, 100, L.SHARE_TITLE, "sharePos", 420, 140)
    RH.ui.share = win
    local pad = 12
    local y = 40
    local bw = (W - pad * 2 - 8 * 2) / 3

    -- プリセット
    Label(win, "PresetLbl", L.LBL_PRESETS, pad, y, "ZoFontGameBold", ZO_SELECTED_TEXT)
    y = y + 24
    local comboCtrl = WM:CreateControlFromVirtual(win:GetName() .. "Combo", win, "ZO_ComboBox")
    comboCtrl:SetDimensions(W - pad * 2, 28)
    comboCtrl:SetAnchor(TOPLEFT, win, TOPLEFT, pad, y)
    Track(win, comboCtrl, pad, y, W - pad * 2, 28, 0, 0, 1, 0)
    RH.ui.combo = ZO_ComboBox_ObjectFromContainer(comboCtrl)
    RH.ui.combo:SetSortsItems(false)
    y = y + 34

    local applyBtn = Button(win, "PApply", L.BTN_APPLY, pad, y, bw, function()
        local p = GetSelectedPreset()
        if p then
            local entries = RH.DecodeBody(p.body)
            if entries then RH.ApplyEntries(entries, p.name) else RH.Msg(L.MSG_PARSE_ERROR) end
        end
    end)
    Button(win, "PChat", L.BTN_TO_CHAT, pad + bw + 8, y, bw, function()
        local p = GetSelectedPreset()
        if p and not RH.PostToChat(p.name, p.body) then ShowString(RH.FormatForExternal(p.name, p.body)) end
    end)
    Button(win, "PString", L.BTN_SHOW_STRING, pad + (bw + 8) * 2, y, bw, function()
        local p = GetSelectedPreset()
        if p then
            ShowString(RH.FormatForExternal(p.name, p.body))
            RH.ui.nameEdit:SetText(p.name)
            RH.Msg(L.MSG_EXPORTED)
        end
    end)
    y = y + 32
    Button(win, "PInspect", L.BTN_INSPECT, pad, y, bw, function()
        local p = GetSelectedPreset()
        local entries = p and RH.DecodeBody(p.body)
        if entries then RH.InspectEntries(entries, p.name) end
    end)
    Button(win, "POverwrite", L.BTN_OVERWRITE, pad + bw + 8, y, bw, function()
        local idx = RH.ui.selectedPreset
        if not (idx and RH.sv.presets[idx]) then RH.Msg(L.MSG_SELECT_PRESET); return end
        local entries = RH.CaptureCurrent()
        if entries and RH.OverwritePreset(idx, RH.EncodeEntries(entries)) then
            RefreshPresetCombo()
            RH.ui.combo:SelectItemByIndex(idx)
            RH.ui.selectedPreset = idx
        end
    end)
    local deleteBtn = Button(win, "PDelete", L.BTN_DELETE, pad + (bw + 8) * 2, y, bw, function()
        if RH.ui.selectedPreset and RH.sv.presets[RH.ui.selectedPreset] then
            RH.DeletePreset(RH.ui.selectedPreset)
            RefreshPresetCombo()
        else
            RH.Msg(L.MSG_SELECT_PRESET)
        end
    end)
    TintButton(applyBtn, 0.45, 0.9, 0.45)
    TintButton(deleteBtn, 1.0, 0.4, 0.4)
    y = y + 44

    -- 名前 + 保存
    Label(win, "NameLbl", L.LBL_NAME, pad, y + 4, "ZoFontGame")
    RH.ui.nameEdit = EditBox(win, "NameEdit", pad + 50, y, W - pad * 2 - 50 - bw - 8, 28, false)
    Track(win, RH.ui.nameEdit:GetParent(), pad + 50, y, W - pad * 2 - 50 - bw - 8, 28, 0, 0, 1, 0)
    -- 日本語は1文字が複数バイトのため、入力欄は余裕を持たせ、文字数の制限は保存時(UTF-8文字単位)で行う
    RH.ui.nameEdit:SetMaxInputChars(80)
    pcall(function() RH.ui.nameEdit:SetFont("ZoFontGame") end)
    local saveCurBtn = Button(win, "SaveCur", L.BTN_SAVE_CURRENT, W - pad - bw, y, bw, function()
        local entries = RH.CaptureCurrent()
        if entries then
            RH.SavePreset(RH.ui.nameEdit:GetText(), RH.EncodeEntries(entries))
            RefreshPresetCombo()
        end
    end)
    Track(win, saveCurBtn, W - pad - bw, y, bw, 28, 1, 0, 0, 0)
    y = y + 40

    -- 共有文字列
    local strLbl = Label(win, "StrLbl", L.LBL_STRING, pad, y, "ZoFontGameSmall")
    strLbl:SetWidth(W - pad * 2)
    y = y + 38
    RH.ui.stringEdit = EditBox(win, "StrEdit", pad, y, W - pad * 2, 140, true)
    Track(win, RH.ui.stringEdit:GetParent(), pad, y, W - pad * 2, 140, 0, 0, 1, 1)
    y = y + 148

    local bottomBtns = {}
    bottomBtns[#bottomBtns + 1] = { Button(win, "ImpApply", L.BTN_IMPORT_APPLY, pad, y, bw, function()
        local name, _, entries = ParseFromEdit()
        if entries then RH.ApplyEntries(entries, name) end
    end), pad, y }
    bottomBtns[#bottomBtns + 1] = { Button(win, "ImpSave", L.BTN_IMPORT_SAVE, pad + bw + 8, y, bw, function()
        local name, body, entries = ParseFromEdit()
        if entries then
            -- テキスト内のタイトルを優先。無ければ名前欄の入力を使う
            local typed = RH.ui.nameEdit:GetText()
            local useName = (name and name ~= "") and name or typed
            RH.SavePreset(useName, body)
            RefreshPresetCombo()
        end
    end), pad + bw + 8, y }
    bottomBtns[#bottomBtns + 1] = { Button(win, "ImpInspect", L.BTN_INSPECT_TEXT, pad + (bw + 8) * 2, y, bw, function()
        local name, _, entries = ParseFromEdit()
        if entries then RH.InspectEntries(entries, name) end
    end), pad + (bw + 8) * 2, y }
    for _, b in ipairs(bottomBtns) do Track(win, b[1], b[2], b[3], bw, 28, 0, 1, 0, 0) end
    y = y + 40

    FinishWindow(win, 'sharePos', y)
end

function RH.ShowShareWindow(show)
    if not RH.ui.share then return end
    if show then RefreshPresetCombo() end
    RH.ui.share:SetHidden(not show)
end

---------------------------------------------------------------------------
-- お気に入りウィンドウ
---------------------------------------------------------------------------
local FAV_PAGE_SIZE = 10
local FAV_ROW_H = 28

function RH.RefreshFavoritesWindow()
    local ui = RH.ui
    if not ui.fav or ui.fav:IsHidden() then return end
    local list = RH.GetFavoriteList()
    local pages = math.max(1, math.ceil(#list / FAV_PAGE_SIZE))
    ui.favPage = zo_clamp(ui.favPage or 1, 1, pages)
    local first = (ui.favPage - 1) * FAV_PAGE_SIZE
    for i, row in ipairs(ui.favRows) do
        local item = list[first + i]
        row.item = item
        row:SetHidden(item == nil)
        if item then
            local name = RH.GetCollectibleDisplayName(item.id)
            if not RH.IsUnlocked(item.id) then name = "|c888888" .. name .. "|r" end
            row.name:SetText(name)
            row.detail:SetText(RH.GetFavoriteDetail(item.id))
        end
    end
    ui.favEmpty:SetHidden(#list > 0)
    ui.favPageLabel:SetText(string.format(L.FAV_PAGE, ui.favPage, pages, #list))
end

local function BuildFavoritesWindow()
    local W = 540
    local win = CreateWindow("RestyleHelperFav", W, 100, L.FAV_TITLE, "favPos", 380, 140)
    RH.ui.fav = win
    RH.ui.favRows = {}
    local pad = 12
    local y = 40

    for i = 1, FAV_PAGE_SIZE do
        local row = WM:CreateControl(win:GetName() .. "Row" .. i, win, CT_CONTROL)
        row:SetDimensions(W - pad * 2, FAV_ROW_H)
        row:SetAnchor(TOPLEFT, win, TOPLEFT, pad, y)

        row.name = WM:CreateControl(row:GetName() .. "Name", row, CT_LABEL)
        row.name:SetFont("ZoFontGame")
        row.name:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
        row.name:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
        row.name:SetDimensions(190, 18)
        row.name:SetMaxLineCount(1)

        row.detail = WM:CreateControl(row:GetName() .. "Detail", row, CT_LABEL)
        row.detail:SetFont("ZoFontGameSmall")
        row.detail:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
        row.detail:SetAnchor(TOPLEFT, row, TOPLEFT, 198, 2)
        row.detail:SetDimensions(150, 16)
        row.detail:SetMaxLineCount(1)

        local bx = W - pad * 2
        local rm = Button(row, "Remove", L.FAV_BTN_REMOVE, bx - 30, 0, 30, function()
            if row.item then RH.ToggleFavorite(row.item.id) end
        end)
        local all = Button(row, "All", L.FAV_BTN_ALL, bx - 30 - 4 - 56, 0, 56, function()
            if row.item then RH.ApplyStyleToAll(row.item.id, false) end
        end)
        local wear = Button(row, "Wear", L.FAV_BTN_WEAR, bx - 30 - 4 - 56 - 4 - 64, 0, 64, function()
            if row.item then RH.ApplyFavoriteToSlot(row.item.id) end
        end)
        rm:SetHeight(24); all:SetHeight(24); wear:SetHeight(24)
        -- ウィンドウを広げたら、名前欄を広げて、詳細とボタンを右へ動かす
        local offs = { rm = bx - 30, all = bx - 30 - 4 - 56, wear = bx - 30 - 4 - 56 - 4 - 64 }
        table.insert(win.rhLayout, function(dw)
            row:SetWidth(W - pad * 2 + dw)
            row.name:SetWidth(190 + dw * 0.6)
            row.detail:ClearAnchors()
            row.detail:SetAnchor(TOPLEFT, row, TOPLEFT, 198 + dw * 0.6, 2)
            row.detail:SetWidth(150 + dw * 0.4)
            for k, ctl in pairs({ rm = rm, all = all, wear = wear }) do
                ctl:ClearAnchors()
                ctl:SetAnchor(TOPLEFT, row, TOPLEFT, offs[k] + dw, 0)
            end
        end)

        RH.ui.favRows[i] = row
        y = y + FAV_ROW_H + 2
    end

    RH.ui.favEmpty = Label(win, "Empty", L.FAV_EMPTY, pad, 48, "ZoFontGame")

    y = y + 8
    Button(win, "Prev", "<", pad, y, 40, function()
        RH.ui.favPage = (RH.ui.favPage or 1) - 1
        RH.RefreshFavoritesWindow()
    end)
    RH.ui.favPageLabel = Label(win, "PageLbl", "", pad + 52, y + 4, "ZoFontGame")
    local nextBtn = Button(win, "Next", ">", W - pad - 40, y, 40, function()
        RH.ui.favPage = (RH.ui.favPage or 1) + 1
        RH.RefreshFavoritesWindow()
    end)
    Track(win, nextBtn, W - pad - 40, y, 40, 28, 1, 0, 0, 0)
    y = y + 40
    FinishWindow(win, 'favPos', y)
end

function RH.ShowFavoritesWindow(show)
    if not RH.ui.fav then return end
    RH.ui.fav:SetHidden(not show)
    if show then RH.RefreshFavoritesWindow() end
end

---------------------------------------------------------------------------
-- 色の設定ウィンドウ(使う色の系統 / 必ず使う色)
---------------------------------------------------------------------------
local COLS, ROWS, SW = 12, 6, 28
local function BuildColorsWindow()
    local W = COLS * (SW + 4) + 24
    local win = CreateWindow("RestyleHelperColors", W, 100, L.COLORS_TITLE, "colorsPos", 420, 140)
    RH.ui.colors = win
    local pad = 12
    local y = 40

    Label(win, "FamHdr", L.COLORS_FAMILY_HDR, pad, y, "ZoFontGameBold", ZO_SELECTED_TEXT)
    y = y + 24
    local famChecks = {}
    local perRow = 4
    local cw = (W - pad * 2) / perRow
    for i, fam in ipairs(RH.FAMILIES) do
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        local c = Check(win, "Fam" .. fam, L["FAM_" .. fam], pad + col * cw, y + row * 24,
            function() return RH.sv.colorFamilies[fam] == true end,
            function(v)
                RH.sv.colorFamilies[fam] = v or nil
                RH.RefreshColorsWindow()
            end, cw - 30)
        famChecks[#famChecks + 1] = c
    end
    y = y + math.ceil(#RH.FAMILIES / perRow) * 24 + 4
    Button(win, "FamClear", L.COLORS_NO_FAMILY, pad, y, 180, function()
        RH.sv.colorFamilies = {}
        RefreshChecks()
        RH.RefreshColorsWindow()
    end)
    y = y + 38

    Label(win, "ReqHdr", L.COLORS_REQUIRED_HDR, pad, y, "ZoFontGameBold", ZO_SELECTED_TEXT)
    RH.ui.reqCount = Label(win, "ReqCnt", "", W - pad - 130, y + 2, "ZoFontGameSmall", ZO_NORMAL_TEXT)
    y = y + 26

    RH.ui.swatches = {}
    for i = 1, COLS * ROWS do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local name = win:GetName() .. "Sw" .. i
        -- クリック判定用の透明なコントロール(色や枠は兄弟ではなく子として重ねる)
        local hit = WM:CreateControl(name, win, CT_CONTROL)
        hit:SetDimensions(SW, SW)
        hit:SetAnchor(TOPLEFT, win, TOPLEFT, pad + col * (SW + 4), y + row * (SW + 4))
        hit:SetMouseEnabled(true)
        hit:SetHidden(true)
        local frame = WM:CreateControl(name .. "Frame", hit, CT_TEXTURE)
        frame:SetAnchorFill(hit)
        frame:SetColor(1, 1, 1, 1)
        frame:SetHidden(true)
        local inner = WM:CreateControl(name .. "Color", hit, CT_TEXTURE)
        inner:SetAnchor(TOPLEFT, hit, TOPLEFT, 3, 3)
        inner:SetAnchor(BOTTOMRIGHT, hit, BOTTOMRIGHT, -3, -3)
        inner:SetColor(0, 0, 0, 1)
        local xmark = WM:CreateControl(name .. "X", hit, CT_LABEL)
        xmark:SetFont("ZoFontWinH2")
        xmark:SetColor(1, 0.15, 0.15, 1)
        xmark:SetText("×")
        xmark:SetAnchorFill(hit)
        xmark:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        xmark:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        xmark:SetHidden(true)
        local function Toggle(ctl)
            local id = ctl.dyeId
            if not id then return end
            local set = RH.sv.requiredDyes
            RH.sv.excludedDyes[id] = nil
            if set[id] then set[id] = nil else set[id] = true end
            RH.RefreshColorsWindow()
        end
        local function ToggleExclude(ctl)
            local id = ctl.dyeId
            if not id then return end
            local ex = RH.sv.excludedDyes
            if ex[id] then ex[id] = nil else ex[id] = true; RH.sv.requiredDyes[id] = nil end
            RH.RefreshColorsWindow()
        end
        hit:SetHandler("OnMouseDown", function(ctl, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then Toggle(ctl)
            elseif button == MOUSE_BUTTON_INDEX_RIGHT then ToggleExclude(ctl) end
        end)
        hit:SetHandler("OnMouseEnter", function(ctl)
            if ctl.dyeId then
                InitializeTooltip(InformationTooltip, ctl, BOTTOM, 0, 4)
                SetTooltipText(InformationTooltip, RH.GetDyeName(ctl.dyeId))
            end
        end)
        hit:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
        RH.ui.swatches[i] = { hit = hit, frame = frame, inner = inner, xmark = xmark }
    end
    y = y + ROWS * (SW + 4) + 6

    RH.ui.colorPage = 1
    Button(win, "Prev", "<", pad, y, 40, function() RH.ui.colorPage = RH.ui.colorPage - 1; RH.RefreshColorsWindow() end)
    Button(win, "Next", ">", pad + 48, y, 40, function() RH.ui.colorPage = RH.ui.colorPage + 1; RH.RefreshColorsWindow() end)
    RH.ui.colorPageLbl = Label(win, "PageLbl", "", pad + 100, y + 6, "ZoFontGameSmall", ZO_NORMAL_TEXT)
    -- 件数表示はヘッダと重ならないよう、ページ切替と同じ行の右端へ
    RH.ui.reqCount:ClearAnchors()
    RH.ui.reqCount:SetAnchor(TOPRIGHT, win, TOPLEFT, W - pad, y + 6)
    y = y + 34
    Button(win, "ReqClear", L.COLORS_CLEAR, pad, y, 170, function()
        RH.sv.requiredDyes = {}
        RH.RefreshColorsWindow()
    end)
    Button(win, "ExcClear", L.COLORS_CLEAR_EXC, pad + 178, y, 170, function()
        RH.sv.excludedDyes = {}
        RH.RefreshColorsWindow()
    end)
    y = y + 40
    FinishWindow(win, 'colorsPos', y)
end

function RH.RefreshColorsWindow()
    local ui = RH.ui
    if not ui.swatches then return end
    local list = RH.GetKnownDyes()
    local fams = RH.sv.colorFamilies
    local any = next(fams) ~= nil
    local shown = {}
    for _, id in ipairs(list) do
        local info = RH.dyeInfo[id]
        if not any or (info and fams[info.family]) or RH.sv.requiredDyes[id] or RH.sv.excludedDyes[id] then
            shown[#shown + 1] = id
        end
    end
    -- 系統 → 元の並び順
    local famOrder = {}
    for i, f in ipairs(RH.FAMILIES) do famOrder[f] = i end
    table.sort(shown, function(a, b)
        local ia, ib = RH.dyeInfo[a], RH.dyeInfo[b]
        local fa, fb = famOrder[ia and ia.family or "grey"] or 99, famOrder[ib and ib.family or "grey"] or 99
        if fa ~= fb then return fa < fb end
        return (ia and ia.order or 0) < (ib and ib.order or 0)
    end)
    local per = COLS * ROWS
    local pages = math.max(1, math.ceil(#shown / per))
    ui.colorPage = math.max(1, math.min(ui.colorPage or 1, pages))
    local first = (ui.colorPage - 1) * per
    for i, sw in ipairs(ui.swatches) do
        local id = shown[first + i]
        local info = id and RH.dyeInfo[id]
        if id and info then
            sw.hit.dyeId = id
            local ex = RH.sv.excludedDyes[id]
            local k = ex and 0.35 or 1
            sw.inner:SetColor((info.r or 0) * k, (info.g or 0) * k, (info.b or 0) * k, 1)
            sw.xmark:SetHidden(not ex)
            sw.frame:SetHidden(not RH.sv.requiredDyes[id])
            sw.hit:SetHidden(false)
        else
            sw.hit.dyeId = nil
            sw.hit:SetHidden(true)
        end
    end
    local n, m = 0, 0
    for _ in pairs(RH.sv.requiredDyes) do n = n + 1 end
    for _ in pairs(RH.sv.excludedDyes) do m = m + 1 end
    ui.reqCount:SetText(string.format(L.COLORS_REQUIRED_CNT, n, m))
    ui.colorPageLbl:SetText(string.format(L.COLORS_PAGE, ui.colorPage, pages))
end

function RH.ShowColorsWindow(show)
    if not RH.ui.colors then return end
    RH.ui.colors:SetHidden(not show)
    if show then RH.RefreshColorsWindow() end
end

function RH.InitUI()
    BuildPanel()
    BuildShareWindow()
    BuildFavoritesWindow()
    BuildColorsWindow()
end

---------------------------------------------------------------------------
-- チャットリンクの表示パネル(部位ごとのスタイル名と染料の色)
---------------------------------------------------------------------------
local LINKVIEW_W = 560
local LINKVIEW_ROW_H = 26

local function BuildLinkView()
    local win = CreateWindow("RestyleHelperLinkView", LINKVIEW_W, 100, L.LINKVIEW_TITLE, "linkViewPos", 500, 160)
    RH.ui.linkView = win
    local pad = 12
    win.nameLbl = Label(win, "Name", "", pad, 38, "ZoFontGameBold", ZO_SELECTED_TEXT)
    win.rows = {}
    for i, slot in ipairs(RH.allSlots) do
        local y = 66 + (i - 1) * LINKVIEW_ROW_H
        local row = {}
        row.slot = Label(win, "Slot" .. i, "", pad, y + 3, "ZoFontGameSmall", ZO_NORMAL_TEXT)
        row.slot:SetWidth(78)
        row.slot:SetMaxLineCount(1)
        row.style = Label(win, "Style" .. i, "", pad + 82, y + 3, "ZoFontGameSmall", ZO_SELECTED_TEXT)
        row.style:SetWidth(240)
        row.style:SetMaxLineCount(1)
        row.sw = {}
        for c = 1, 3 do
            local hit = WM:CreateControl(win:GetName() .. "Sw" .. i .. "_" .. c, win, CT_CONTROL)
            hit:SetDimensions(20, 20)
            hit:SetAnchor(TOPLEFT, win, TOPLEFT, pad + 330 + (c - 1) * 24, y)
            hit:SetMouseEnabled(true)
            local frame = WM:CreateControl(hit:GetName() .. "F", hit, CT_TEXTURE)
            frame:SetAnchorFill(hit)
            frame:SetColor(0.6, 0.6, 0.6, 1)
            local inner = WM:CreateControl(hit:GetName() .. "C", hit, CT_TEXTURE)
            inner:SetAnchor(TOPLEFT, hit, TOPLEFT, 2, 2)
            inner:SetAnchor(BOTTOMRIGHT, hit, BOTTOMRIGHT, -2, -2)
            inner:SetColor(0, 0, 0, 1)
            hit.inner = inner
            hit:SetHandler("OnMouseEnter", function(self)
                if self.tipText then InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4); SetTooltipText(InformationTooltip, self.tipText) end
            end)
            hit:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
            row.sw[c] = hit
        end
        row.dyes = Label(win, "Dyes" .. i, "", pad + 408, y + 3, "ZoFontGameSmall", ZO_NORMAL_TEXT)
        row.dyes:SetWidth(LINKVIEW_W - pad * 2 - 408)
        row.dyes:SetMaxLineCount(1)
        win.rows[i] = row
    end
    local by = 66 + #RH.allSlots * LINKVIEW_ROW_H + 8
    win.importBtn = Button(win, "Import", L.BTN_LINK_IMPORT, pad, by, 220, function()
        if not win.body then return end
        RH.ShowShareWindow(true)
        RH.SetImportText(RH.MakeShareString(win.name or "", win.body), win.name)
    end)
    win.applyBtn = Button(win, "Apply", L.BTN_LINK_APPLY, pad + 228, by, 140, function()
        if win.entries then RH.ApplyEntries(win.entries, win.name) end
    end)
    TintButton(win.applyBtn, 0.45, 0.9, 0.45)
    FinishWindow(win, "linkViewPos", by + 40)
end

-- メニュー(シーン)が切り替わったら、リンクから開いたパネルを閉じる(HUD と HUD+UI は同じ扱い)
local function SceneGroup(name)
    if name == "hud" or name == "hudui" then return "hud" end
    return name
end

local function CurrentSceneGroup()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
    return scene and SceneGroup(scene:GetName()) or nil
end

local linkViewHooked = false
local function HookLinkViewScene()
    if linkViewHooked or not SCENE_MANAGER or not SCENE_MANAGER.RegisterCallback then return end
    linkViewHooked = true
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
        local win = RH.ui.linkView
        if not win or win:IsHidden() or newState ~= SCENE_SHOWN then return end
        if SceneGroup(scene:GetName()) ~= win.openScene then win:SetHidden(true) end
    end)
end

function RH.ShowLinkView(name, body, entries)
    if not RH.ui.linkView then BuildLinkView() end
    HookLinkViewScene()
    local win = RH.ui.linkView
    win.openScene = CurrentSceneGroup()
    win.name, win.body, win.entries = name, body, entries
    win.nameLbl:SetText(string.format(L.LINKVIEW_NAME, name ~= "" and name or L.EXT_NONAME))
    local bySlot = {}
    for _, e in ipairs(entries) do bySlot[e.slot] = e end
    for i, slot in ipairs(RH.allSlots) do
        local row, e = win.rows[i], bySlot[slot]
        row.slot:SetText(RH.GetSlotName(slot))
        if e and e.id and e.id ~= 0 then
            local nm = RH.GetCollectibleDisplayName(e.id)
            if not RH.IsUnlocked(e.id) then nm = "|cFF6666" .. nm .. "|r" end
            row.style:SetText(nm)
            local names = {}
            for c, dyeId in ipairs({ e.p, e.s, e.a }) do
                local sw = row.sw[c]
                local r, g, b = 0, 0, 0
                if dyeId and dyeId ~= 0 and GetDyeInfoById then
                    local dn, _, _, _, _, rr, gg, bb = GetDyeInfoById(dyeId)
                    if rr then r, g, b = rr, gg, bb end
                    sw.tipText = RH.GetDyeName(dyeId)
                    sw.inner:SetColor(r, g, b, 1)
                else
                    sw.tipText = nil
                    sw.inner:SetColor(0.12, 0.12, 0.12, 1)
                end
                sw:SetHidden(false)
                names[#names + 1] = RH.GetDyeName(dyeId)
            end
            row.dyes:SetText(table.concat(names, " / "))
        else
            row.style:SetText("-")
            for c = 1, 3 do row.sw[c]:SetHidden(true) end
            row.dyes:SetText("")
        end
    end
    win:SetHidden(false)
end
