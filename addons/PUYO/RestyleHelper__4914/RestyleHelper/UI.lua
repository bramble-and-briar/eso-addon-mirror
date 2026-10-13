local RH = RestyleHelper
local L = RH.L
local WM = WINDOW_MANAGER

RH.ui = { checks = {}, selectedPreset = nil }

---------------------------------------------------------------------------
-- 部品
---------------------------------------------------------------------------
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
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos and pos.x or defX, pos and pos.y or defY)
    win:SetHandler("OnMoveStop", function(self)
        RH.sv[posKey] = { x = self:GetLeft(), y = self:GetTop() }
    end)

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
    return win
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

local function Check(parent, name, text, x, y, getter, setter, labelWidth)
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
        nameLbl:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
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
    end
    y = y + 42
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
        { "orderPerSlot",   L.OPT_ORDER_PER_SLOT },
        { "favoritesOnly",  L.OPT_FAVORITES_ONLY },
        { "hideMissing",    L.OPT_HIDE_MISSING },
        { "shareMessages",  L.OPT_SHARE_MSGS },
    }
    for _, o in ipairs(opts) do
        local key = o[1]
        Check(win, "Opt" .. key, o[2], pad, y,
            function() if key == "shareMessages" then return RH.sv[key] ~= false end return RH.sv[key] == true end,
            function(v) RH.sv[key] = v end)
        y = y + 24
    end

    -- スタイル統一の最小部位数(− / + で 1〜7)
    local minLbl = Label(win, "ThemeMinLbl", "", pad, y + 5, "ZoFontGame", ZO_NORMAL_TEXT)
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

    Button(win, "ChestAll", L.BTN_CHEST_TO_ALL, pad, y, W - pad * 2, function() RH.ApplyChestToAll() end)
    y = y + 32
    Button(win, "Fav",      L.BTN_FAVORITES,    pad,            y, half, function() RH.ShowFavoritesWindow(true) end)
    Button(win, "Share",    L.BTN_SHARE,        pad + half + 8, y, half, function() RH.ShowShareWindow(true) end)
    y = y + 38
    local hint = Label(win, "ChLockHint", L.HINT_CHANNEL_LOCK, pad, y, "ZoFontGameSmall", ZO_DISABLED_TEXT)
    hint:SetWidth(W - pad * 2)
    y = y + 24

    win:SetHeight(y)
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
    for slot, mark in pairs(ui.coverCells) do
        local st = cov and cov.states[slot]
        local def = st and COVER_MARKS[st]
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
    if show then RefreshChecks() end
    RH.ui.panel:SetHidden(not show)
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
    RH.ui.combo = ZO_ComboBox_ObjectFromContainer(comboCtrl)
    RH.ui.combo:SetSortsItems(false)
    y = y + 34

    Button(win, "PApply", L.BTN_APPLY, pad, y, bw, function()
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
    Button(win, "PDelete", L.BTN_DELETE, pad + (bw + 8) * 2, y, bw, function()
        if RH.ui.selectedPreset and RH.sv.presets[RH.ui.selectedPreset] then
            RH.DeletePreset(RH.ui.selectedPreset)
            RefreshPresetCombo()
        else
            RH.Msg(L.MSG_SELECT_PRESET)
        end
    end)
    y = y + 44

    -- 名前 + 保存
    Label(win, "NameLbl", L.LBL_NAME, pad, y + 4, "ZoFontGame")
    RH.ui.nameEdit = EditBox(win, "NameEdit", pad + 50, y, W - pad * 2 - 50 - bw - 8, 28, false)
    -- 日本語は1文字が複数バイトのため、入力欄は余裕を持たせ、文字数の制限は保存時(UTF-8文字単位)で行う
    RH.ui.nameEdit:SetMaxInputChars(80)
    pcall(function() RH.ui.nameEdit:SetFont("ZoFontGame") end)
    Button(win, "SaveCur", L.BTN_SAVE_CURRENT, W - pad - bw, y, bw, function()
        local entries = RH.CaptureCurrent()
        if entries then
            RH.SavePreset(RH.ui.nameEdit:GetText(), RH.EncodeEntries(entries))
            RefreshPresetCombo()
        end
    end)
    y = y + 40

    -- 共有文字列
    local strLbl = Label(win, "StrLbl", L.LBL_STRING, pad, y, "ZoFontGameSmall")
    strLbl:SetWidth(W - pad * 2)
    y = y + 38
    RH.ui.stringEdit = EditBox(win, "StrEdit", pad, y, W - pad * 2, 140, true)
    y = y + 148

    Button(win, "Export", L.BTN_EXPORT, pad, y, bw, function()
        local str = RH.ExportCurrent(RH.ui.nameEdit:GetText())
        if str then
            ShowString(str)
            RH.Msg(L.MSG_EXPORTED)
        end
    end)
    Button(win, "ImpApply", L.BTN_IMPORT_APPLY, pad + bw + 8, y, bw, function()
        local name, _, entries = ParseFromEdit()
        if entries then RH.ApplyEntries(entries, name) end
    end)
    Button(win, "ImpSave", L.BTN_IMPORT_SAVE, pad + (bw + 8) * 2, y, bw, function()
        local name, body, entries = ParseFromEdit()
        if entries then
            local typed = RH.ui.nameEdit:GetText()
            RH.SavePreset((typed ~= "" and typed) or name, body)
            RefreshPresetCombo()
        end
    end)
    y = y + 32
    Button(win, "ImpInspect", L.BTN_INSPECT, pad, y, bw, function()
        local name, _, entries = ParseFromEdit()
        if entries then RH.InspectEntries(entries, name) end
    end)
    y = y + 40

    win:SetHeight(y)
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
        row.detail:SetColor(ZO_DISABLED_TEXT:UnpackRGBA())
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
    Button(win, "Next", ">", W - pad - 40, y, 40, function()
        RH.ui.favPage = (RH.ui.favPage or 1) + 1
        RH.RefreshFavoritesWindow()
    end)
    y = y + 40
    win:SetHeight(y)
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
    win:SetHeight(y)
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
