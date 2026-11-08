-- Easy Addon Setting v2.14.0 (author: PUYO)
-- /charaddons : キャラクター一覧とアドオン一覧を1つのウィンドウに表示し、
-- キャラを選んでそのキャラ用のアドオンON/OFFを切り替える。
-- 標準AddOns画面と同じAPI(SetAddOnFilter / SetAddOnEnabled)を使う。
-- フィルターは操作ごとに設定→解除するので、標準画面の挙動には影響しない。

local ADDON_NAME = "EasyAddonSetting"
local VERSION = "2.14.0"

---------------------------------------------------------------------
-- localization (ja / en)  ゲームの言語が日本語なら日本語、それ以外は英語
---------------------------------------------------------------------
local STR = {
    ja = {
        bindToggle    = "ウィンドウ 開閉 (1キーで繰り返し・カーソル付き)",
        bindCursor    = "ウィンドウ カーソル操作 (クリック用・歩けない)",
        hintNoCursor  = "クリックするには「カーソル操作」キーを押す",
        hintDirty     = "変更あり: ログイン中のキャラはUIリロード後に反映 / 他キャラは次回ログイン時に反映",
        hintIdle      = "クリックでON/OFF切替",
        outOfDate     = "期限切れ",
        target        = "対象キャラ: ",
        loggedIn      = "ログイン中",
        title         = "キャラ別アドオン ON/OFF  (タイトル付近をドラッグで移動)",
        characters    = "キャラクター",
        search        = "検索:",
        reload        = "UIリロード",
        hideLibs      = "Lib系を隠す",
        copyBtn       = "キャラ間コピー",
        groupLegend   = "同じ色 = 同じアドオン設定",
        copyTitle     = "キャラ間コピー",
        copySrcHead   = "コピー元 (1人)",
        copyDstHead   = "コピー先 (複数可)",
        allChars      = "全キャラ選択",
        allCharsOff   = "全キャラ解除",
        targetAll     = "対象: 全キャラクター (%d人)",
        allOn         = "全てON",
        allOff        = "全てOFF",
        selectAll     = "全選択",
        selectNone    = "解除",
        execute       = "上書き実行",
        cancel        = "キャンセル",
        summary       = function(src, n) return string.format("%s の設定を %d キャラに上書きします", src, n) end,
        summaryHint   = "コピー元を1人、コピー先を1人以上選んでください",
        needSrc       = "コピー元のキャラクターを選んでください",
        needDst       = "コピー先のキャラクターを選んでください",
        done          = function(src, n, names, total) return string.format("%s の設定を %d キャラに上書きしました (%s / 計%d件変更)", src, n, names, total) end,
        needTwoChars  = "コピーには2人以上のキャラクターが必要です",
        noCharInfo    = "キャラクター情報を取得できませんでした",
        lamWindow     = "ウィンドウ",
        lamDesc       = "キャラクターを選んで、そのキャラ用のアドオンON/OFFを切り替えるウィンドウです。チャットで /charaddons と入力しても開閉できます。「/charaddons 文字列」で一覧をその文字列で絞り込み、「/charaddons -」で解除できます。",
        lamToggle     = "ウィンドウを開く / 閉じる",
        lamListHeader = "アドオン一覧",
        lamHideLibs   = "ライブラリ(Lib系)を一覧から隠す",
        lamHideLibsTT = "ファイル名が Lib で始まるアドオン(LibAddonMenu-2.0 など)を、ウィンドウの一覧に表示しません。隠しても状態は変わりません。",
        lamKeyHeader  = "キー割り当て",
        lamKeyDesc    = "設定 → コントロール → キー割り当て(libAddonKeybinds がある場合は「Addon Keybinds」)の「Easy Addon Setting」にキーを割り当てられます。\n・ウィンドウ 開閉: 1つのキーで、カーソル付きでウィンドウを表示/非表示します(表示中は歩けません。ESCでも閉じます)。",
    },
    en = {
        bindToggle    = "Toggle Window (with mouse cursor)",
        bindCursor    = "Window Mouse Cursor (click mode, no walking)",
        hintNoCursor  = "Press the Mouse Cursor key to click",
        hintDirty     = "Changed: reload UI to apply to the logged-in character. Others apply at next login.",
        hintIdle      = "Click a row to toggle ON/OFF",
        outOfDate     = "out of date",
        target        = "Character: ",
        loggedIn      = "Logged in",
        title         = "Per-Character AddOns ON/OFF  (drag to move)",
        characters    = "Characters",
        search        = "Search:",
        reload        = "Reload UI",
        hideLibs      = "Hide libraries",
        copyBtn       = "Copy Settings",
        groupLegend   = "Same color = same AddOn settings",
        copyTitle     = "Copy Between Characters",
        copySrcHead   = "Source (pick one)",
        copyDstHead   = "Targets (multiple)",
        allChars      = "All Chars",
        allCharsOff   = "Single",
        targetAll     = "Target: All characters (%d)",
        allOn         = "All ON",
        allOff        = "All OFF",
        selectAll     = "All",
        selectNone    = "None",
        execute       = "Overwrite",
        cancel        = "Cancel",
        summary       = function(src, n) return string.format("Overwrite %d character(s) with settings from %s", n, src) end,
        summaryHint   = "Pick one source and at least one target",
        needSrc       = "Please pick a source character",
        needDst       = "Please pick at least one target character",
        done          = function(src, n, names, total) return string.format("Copied settings from %s to %d character(s) (%s / %d change(s))", src, n, names, total) end,
        needTwoChars  = "At least two characters are required to copy settings",
        noCharInfo    = "Could not get character information",
        lamWindow     = "Window",
        lamDesc       = "Pick a character and toggle which AddOns are enabled for that character. You can also open/close this window with /charaddons in chat. \"/charaddons text\" filters the list by that text, and \"/charaddons -\" clears the filter.",
        lamToggle     = "Open / Close Window",
        lamListHeader = "AddOn List",
        lamHideLibs   = "Hide libraries (Lib*) from the list",
        lamHideLibsTT = "Hides AddOns whose file name starts with \"Lib\" (e.g. LibAddonMenu-2.0) from the window's list. Their ON/OFF state is not changed.",
        lamKeyHeader  = "Key Bindings",
        lamKeyDesc    = "Go to Settings > Controls > Keybindings (\"Addon Keybinds\" if libAddonKeybinds is installed) and find \"Easy Addon Setting\".\n- Toggle Window: one key to show/hide the window with the mouse cursor (no walking while open; ESC also closes it).",
    },
}
-- ESOの日本語の言語コードは "jp" (念のため "ja" も日本語として扱う)
local gameLang = GetCVar("Language.2")
local LANG = (gameLang == "jp" or gameLang == "ja") and "ja" or "en"

local function L(key, ...)
    local v = STR[LANG][key] or STR.en[key] or key
    if type(v) == "function" then return v(...) end
    return v
end

-- キー割り当て名 (Bindings.xml の CASW_TOGGLE)
ZO_CreateStringId("SI_BINDING_NAME_CASW_TOGGLE", L("bindToggle"))
ZO_CreateStringId("SI_BINDING_NAME_CASW_CURSOR", L("bindCursor"))

local WIN_W, WIN_H = 700, 680
local LEFT_W       = 200
local CHAR_ROW_H   = 28

local sv
local win, list, search, charRows
local titleTarget, countLabel, hintLabel
local allMode = false      -- true: 全キャラクターを対象に設定する
local allCharBtn
local selectedChar
local hideLibCheck
local RefreshGroups        -- 同じ設定のキャラをグループ化して色分け(後で定義)
local groupColor = {}      -- キャラ名 -> {r,g,b}  (同じ設定のキャラが2人以上いる場合のみ)
local GROUP_PALETTE = {
    { 0.95, 0.40, 0.40 }, { 0.40, 0.75, 0.95 }, { 0.55, 0.90, 0.45 }, { 0.95, 0.75, 0.30 },
    { 0.75, 0.50, 0.95 }, { 0.95, 0.55, 0.80 }, { 0.40, 0.90, 0.85 }, { 0.95, 0.60, 0.30 },
}
local function ApplySwatch(row)
    local gc = groupColor[row.charName]
    if gc then
        row.swatch:SetColor(gc[1], gc[2], gc[3], 1)
        row.swatch:SetHidden(false)
    else
        row.swatch:SetHidden(true)
    end
end
local copyWin
local ShowCopy, HideCopy   -- キャラ間コピー(後で定義)
local allEntries = {}
local dirty = false
local uiModeSet = false

local C_NORMAL   = { 0.85, 0.85, 0.85, 1 }
local C_SELECTED = { 1.0, 0.85, 0.35, 1 }

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function Strip(text)
    text = text:gsub("|c%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

local function Say(msg)
    d("|c66CCFF[CASW]|r " .. tostring(msg))
end

-- characterName に対するフィルターを一時的に設定して fn を実行し、必ず解除する
local function WithFilter(charName, fn)
    local am = GetAddOnManager()
    local ok, err = pcall(function()
        if charName then
            am:SetAddOnFilter(GetUniqueNameForCharacter(charName))
        end
        fn(am)
    end)
    pcall(function() am:RemoveAddOnFilter() end)
    if not ok then Say("error: " .. tostring(err)) end
    return ok
end

local function GetCharacterNames()
    local names = {}
    for i = 1, GetNumCharacters() do
        local name = GetCharacterInfo(i)
        names[#names + 1] = zo_strformat(SI_UNIT_NAME, name)
    end
    return names
end

local function GetCurrentCharName()
    local n = GetUnitName("player")
    if n and n ~= "" then return zo_strformat(SI_UNIT_NAME, n) end
end

---------------------------------------------------------------------
-- addon list data
---------------------------------------------------------------------
local function BuildEntries()
    allEntries = {}
    local am = GetAddOnManager()
    for i = 1, am:GetNumAddOns() do
        local name, title, author = am:GetAddOnInfo(i)
        local plain = Strip(title or name or "")
        allEntries[#allEntries + 1] = {
            index = i,
            file = name,
            plain = plain,
            sortKey = plain:lower(),
        }
    end
    table.sort(allEntries, function(a, b)
        if a.sortKey ~= b.sortKey then return a.sortKey < b.sortKey end
        return a.file < b.file
    end)
end

local function ReadStates()
    WithFilter(selectedChar, function(am)
        for _, e in ipairs(allEntries) do
            local _, _, _, _, enabled, state, isOutOfDate = am:GetAddOnInfo(e.index)
            e.enabled = enabled
            e.state = state
            e.outOfDate = isOutOfDate
        end
    end)
end

-- ライブラリ判定: ファイル名が "Lib" で始まるもの (LibAddonMenu-2.0, libAddonKeybinds など)
local function IsLibrary(e)
    return e.file:lower():sub(1, 3) == "lib"
end

local function IsVisible(e)
    return not (sv.hideLibs and IsLibrary(e))
end

local function UpdateCount()
    local on, total = 0, 0
    for _, e in ipairs(allEntries) do
        if IsVisible(e) then
            total = total + 1
            if e.enabled then on = on + 1 end
        end
    end
    countLabel:SetText(string.format("ON: %d / %d", on, total))
end

local function UpdateHint()
    if not hintLabel then return end
    if dirty then
        hintLabel:SetText(L("hintDirty"))
        hintLabel:SetColor(1, 0.7, 0.3, 1)
    elseif not uiModeSet and not (SCENE_MANAGER and SCENE_MANAGER:IsInUIMode()) then
        hintLabel:SetText(L("hintNoCursor"))
        hintLabel:SetColor(0.6, 0.85, 1, 1)
    else
        hintLabel:SetText(L("hintIdle"))
        hintLabel:SetColor(0.7, 0.7, 0.7, 1)
    end
end

local function FillList()
    local query = (search:GetText() or ""):lower()
    local data = ZO_ScrollList_GetDataList(list)
    ZO_ClearNumericallyIndexedTable(data)
    for _, e in ipairs(allEntries) do
        if IsVisible(e) and (query == "" or e.sortKey:find(query, 1, true) or e.file:lower():find(query, 1, true)) then
            data[#data + 1] = ZO_ScrollList_CreateDataEntry(1, e)
        end
    end
    ZO_ScrollList_Commit(list)
    UpdateCount()
end

local function SetHideLibs(value)
    sv.hideLibs = value and true or false
    if hideLibCheck then
        ZO_CheckButton_SetCheckState(hideLibCheck, sv.hideLibs)
    end
    if win and list then FillList() end
end

-- 設定の書き込み先キャラクター(全キャラ選択中は全員、通常は選択中の1人)
local function TargetChars()
    if allMode then return GetCharacterNames() end
    return { selectedChar }
end

local function OnToggle(data, checked)
    local ok = true
    for _, c in ipairs(TargetChars()) do
        ok = WithFilter(c, function(am)
            am:SetAddOnEnabled(data.index, checked)
        end) and ok
    end
    if ok then dirty = true end
    ReadStates()
    if RefreshGroups then RefreshGroups() end
    ZO_ScrollList_RefreshVisible(list)
    UpdateCount()
    UpdateHint()
end

-- 一覧に表示中のアドオン(検索・Lib非表示を反映)をまとめてON/OFF
local function SetAllVisible(checked)
    local data = ZO_ScrollList_GetDataList(list)
    local ok = true
    for _, c in ipairs(TargetChars()) do
        ok = WithFilter(c, function(am)
            for _, d in ipairs(data) do
                am:SetAddOnEnabled(d.data.index, checked)
            end
        end) and ok
    end
    if ok then dirty = true end
    ReadStates()
    if RefreshGroups then RefreshGroups() end
    ZO_ScrollList_RefreshVisible(list)
    UpdateCount()
    UpdateHint()
end

local function SetupRow(control, data)
    control.data = data
    local check = control:GetNamedChild("Check")
    local label = control:GetNamedChild("Name")

    ZO_CheckButton_SetCheckState(check, data.enabled and true or false)
    ZO_CheckButton_SetToggleFunction(check, function(_, checked) OnToggle(data, checked) end)

    local text = data.plain
    if data.outOfDate then text = text .. " |cFF9900[" .. L("outOfDate") .. "]|r" end
    label:SetText(text)

    if data.enabled and data.state == ADDON_STATE_DEPENDENCIES_DISABLED then
        label:SetColor(1, 0.35, 0.35, 1)       -- 依存アドオンがOFF
    elseif data.enabled then
        label:SetColor(0.95, 0.95, 0.95, 1)
    else
        label:SetColor(0.5, 0.5, 0.5, 1)
    end
end

function CASW_OnRowMouseUp(row, button, upInside)
    if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    local data = row.data
    if not data then return end
    local newState = not data.enabled
    ZO_CheckButton_SetCheckState(row:GetNamedChild("Check"), newState)
    OnToggle(data, newState)
end

---------------------------------------------------------------------
-- character list
---------------------------------------------------------------------
local function RefreshCharRows()
    for _, row in ipairs(charRows) do
        if row.active then
            local on = allMode or (row.charName == selectedChar)
            local c = on and C_SELECTED or C_NORMAL
            row.label:SetColor(c[1], c[2], c[3], c[4])
            row.sel:SetHidden(not on)
            row.bar:SetHidden(not on)
            ApplySwatch(row)
        end
    end
end

local function UpdateTargetTitle()
    if allMode then
        titleTarget:SetText(L("targetAll", #GetCharacterNames()))
    else
        titleTarget:SetText(L("target") .. tostring(selectedChar))
    end
    if allCharBtn then allCharBtn:SetText(allMode and L("allCharsOff") or L("allChars")) end
end

-- 全キャラクター選択モードの切り替え(ONの間、チェック操作は全キャラクターに反映される)
local function SetAllMode(v)
    if HideCopy then HideCopy() end
    allMode = v and true or false
    UpdateTargetTitle()
    RefreshCharRows()
    UpdateHint()
end

local function SelectChar(name)
    if HideCopy then HideCopy() end
    allMode = false
    selectedChar = name
    UpdateTargetTitle()
    RefreshCharRows()
    ReadStates()
    FillList()
    UpdateHint()
end

local function GetCharRow(i)
    local row = charRows[i]
    if row then return row end

    row = WINDOW_MANAGER:CreateControl("CASW_CharRow" .. i, win, CT_CONTROL)
    row:SetDimensions(LEFT_W - 10, CHAR_ROW_H)
    row:SetMouseEnabled(true)
    row:SetAnchor(TOPLEFT, win, TOPLEFT, 10, 70 + (i - 1) * CHAR_ROW_H)

    row.hl = WINDOW_MANAGER:CreateControl("CASW_CharRow" .. i .. "HL", row, CT_TEXTURE)
    row.hl:SetAnchorFill(row)
    row.hl:SetColor(1, 1, 1, 0.12)
    row.hl:SetHidden(true)

    row.label = WINDOW_MANAGER:CreateControl("CASW_CharRow" .. i .. "Label", row, CT_LABEL)
    row.label:SetFont("ZoFontGameMedium")
    row.label:SetAnchor(LEFT, row, LEFT, 26, 0)
    row.label:SetDimensions(LEFT_W - 40 - 64, CHAR_ROW_H)

    -- 同じ設定のキャラを示す色の四角
    row.swatch = WINDOW_MANAGER:CreateControl("CASW_CharRow" .. i .. "Swatch", row, CT_TEXTURE)
    row.swatch:SetDimensions(10, 10)
    row.swatch:SetAnchor(LEFT, row, LEFT, 10, 0)
    row.swatch:SetDrawLevel(2)
    row.swatch:SetHidden(true)
    row.label:SetDrawLevel(3)

    -- 選択中: 薄い背景 + 左のアクセントバー
    row.sel = WINDOW_MANAGER:CreateControl("CASW_CharRow" .. i .. "Sel", row, CT_TEXTURE)
    row.sel:SetAnchorFill(row)
    row.sel:SetColor(1, 0.85, 0.35, 0.10)
    row.sel:SetDrawLevel(0)
    row.sel:SetHidden(true)

    row.bar = WINDOW_MANAGER:CreateControl("CASW_CharRow" .. i .. "Bar", row, CT_TEXTURE)
    row.bar:SetDimensions(3, CHAR_ROW_H - 8)
    row.bar:SetAnchor(LEFT, row, LEFT, 0, 0)
    row.bar:SetColor(1, 0.85, 0.35, 1)
    row.bar:SetDrawLevel(2)
    row.bar:SetHidden(true)

    -- ログイン中バッジ
    row.badge = WINDOW_MANAGER:CreateControl("CASW_CharRow" .. i .. "Badge", row, CT_LABEL)
    row.badge:SetFont("ZoFontGameSmall")
    row.badge:SetColor(0.5, 0.9, 0.6, 1)
    row.badge:SetText(L("loggedIn"))
    row.badge:SetAnchor(RIGHT, row, RIGHT, -8, 0)
    row.badge:SetDrawLevel(3)
    row.badge:SetHidden(true)
    row.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.label:SetMaxLineCount(1)

    row:SetHandler("OnMouseEnter", function(self) self.hl:SetHidden(false) end)
    row:SetHandler("OnMouseExit",  function(self) self.hl:SetHidden(true) end)
    row:SetHandler("OnMouseUp", function(self, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            SelectChar(self.charName)
        end
    end)

    charRows[i] = row
    return row
end

local function BuildCharList()
    local names = GetCharacterNames()
    local current = GetCurrentCharName()
    for i, name in ipairs(names) do
        local row = GetCharRow(i)
        row.charName = name
        row.label:SetText(name)
        row.badge:SetHidden(name ~= current)
        row:SetHidden(false)
        row.active = true
    end
    for i = #names + 1, #charRows do
        charRows[i]:SetHidden(true)
        charRows[i].active = false
    end
    return names, current
end

---------------------------------------------------------------------
-- window
---------------------------------------------------------------------
local function MakeButton(name, parent, text, w)
    local b = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    b:SetDimensions(w, 28)
    b:SetFont("ZoFontGameMedium")
    b:SetNormalFontColor(0.9, 0.9, 0.9, 1)
    b:SetMouseOverFontColor(1, 0.85, 0.35, 1)
    b:SetText(text)
    local bg = WINDOW_MANAGER:CreateControl(name .. "BG", b, CT_TEXTURE)
    bg:SetAnchorFill(b)
    bg:SetColor(1, 1, 1, 0.10)
    bg:SetDrawLevel(0)
    return b
end

-- キャラクターが移動したらウィンドウを閉じる
local MOVE_WATCH     = ADDON_NAME .. "_MoveWatch"
local MOVE_THRESHOLD = 0.0005     -- マップ正規化座標での移動量
local startX, startY

local function StopMoveWatch()
    EVENT_MANAGER:UnregisterForUpdate(MOVE_WATCH)
end

-- カーソルモード(UIモード): クリック操作できるが歩けない
local cursorSince, lastInside, hoverSeen = 0, 0, false

-- Wizard's Wardrobe と同じく、シーンマネージャー経由でカーソルモード(hudui シーン)にする。
-- SetGameCameraUIMode を直接呼ぶ方式は、シーン管理と食い違ってカーソルが出ない/キーが効かない原因になる。
local function EnterCursorMode()
    if SCENE_MANAGER:IsInUIMode() then return end   -- メニュー等で既にカーソルあり
    SCENE_MANAGER:SetInUIMode(true, false)
    uiModeSet = true
    hoverSeen = false
    cursorSince = GetFrameTimeMilliseconds()
    UpdateHint()
end

-- skipSceneCall: 別のメニューシーンに切り替わった時は、シーンを戻さない(メニューを閉じてしまうため)
local function ExitCursorMode(skipSceneCall)
    if search and search:HasFocus() then search:LoseFocus() end
    if uiModeSet then
        uiModeSet = false
        if not skipSceneCall and SCENE_MANAGER:IsInUIMode() then
            SCENE_MANAGER:SetInUIMode(false)
        end
    end
    UpdateHint()
end

local function Hide(skipSceneCall)
    if not win then return end
    StopMoveWatch()
    if HideCopy then HideCopy() end
    win:SetHidden(true)
    ExitCursorMode(skipSceneCall)
end

-- マウスがウィンドウ(メイン/コピー)の上にあるか
local function IsMouseOverOurWindows()
    local c = WINDOW_MANAGER:GetMouseOverControl()
    while c do
        if c == win or (copyWin and c == copyWin) then return true end
        c = c:GetParent()
    end
    return false
end

local function StartMoveWatch()
    StopMoveWatch()
    startX, startY = GetMapPlayerPosition("player")
    EVENT_MANAGER:RegisterForUpdate(MOVE_WATCH, 100, function()
        if not win or win:IsHidden() then
            StopMoveWatch()
            return
        end

        -- ESC等でカーソルモードが解除されたらウィンドウも閉じる (Wizard's Wardrobe と同じ挙動)
        if uiModeSet and not SCENE_MANAGER:IsInUIMode() then
            Hide(true)
            return
        end

        local x, y = GetMapPlayerPosition("player")
        if not (x and startX) then return end
        if math.abs(x - startX) > MOVE_THRESHOLD or math.abs(y - startY) > MOVE_THRESHOLD then
            Hide()
        end
    end)
end

local function CreateWindow()
    if win then return end

    win = WINDOW_MANAGER:CreateTopLevelWindow("CASW_Window")
    win:SetDimensions(WIN_W, WIN_H)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetHandler("OnMoveStop", function()
        sv.x = win:GetLeft()
        sv.y = win:GetTop()
    end)

    local bg = WINDOW_MANAGER:CreateControl("CASW_BG", win, CT_TEXTURE)
    bg:SetAnchorFill(win)
    bg:SetColor(0, 0, 0, 0.88)

    local title = WINDOW_MANAGER:CreateControl("CASW_Title", win, CT_LABEL)
    title:SetFont("ZoFontGameBold")
    title:SetColor(1, 0.85, 0.35, 1)
    title:SetText(L("title"))
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 12, 10)

    local close = MakeButton("CASW_Close", win, "×", 32)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -8, 6)
    close:SetHandler("OnClicked", Hide)

    local charHeader = WINDOW_MANAGER:CreateControl("CASW_CharHeader", win, CT_LABEL)
    charHeader:SetFont("ZoFontGameBold")
    charHeader:SetColor(0.7, 0.7, 0.7, 1)
    charHeader:SetText(L("characters"))
    charHeader:SetAnchor(TOPLEFT, win, TOPLEFT, 12, 44)

    titleTarget = WINDOW_MANAGER:CreateControl("CASW_Target", win, CT_LABEL)
    titleTarget:SetFont("ZoFontGameBold")
    titleTarget:SetColor(1, 1, 1, 1)
    titleTarget:SetAnchor(TOPLEFT, win, TOPLEFT, LEFT_W + 14, 44)

    -- 左の一覧: 全キャラクターをまとめて選択 / 解除
    allCharBtn = MakeButton("CASW_AllChars", win, L("allChars"), 96)
    allCharBtn:SetAnchor(TOPRIGHT, win, TOPLEFT, LEFT_W - 4, 40)
    allCharBtn:SetHandler("OnClicked", function() SetAllMode(not allMode) end)

    countLabel = WINDOW_MANAGER:CreateControl("CASW_Count", win, CT_LABEL)
    countLabel:SetFont("ZoFontGameMedium")
    countLabel:SetColor(0.7, 0.7, 0.7, 1)
    countLabel:SetAnchor(TOPRIGHT, win, TOPRIGHT, -14, 46)

    -- 一覧のアドオンを全てON / 全てOFF
    local allOnBtn = MakeButton("CASW_AllOn", win, L("allOn"), 76)
    allOnBtn:SetAnchor(TOPRIGHT, win, TOPRIGHT, -118, 40)
    allOnBtn:SetHandler("OnClicked", function() SetAllVisible(true) end)
    local allOffBtn = MakeButton("CASW_AllOff", win, L("allOff"), 76)
    allOffBtn:SetAnchor(TOPRIGHT, allOnBtn, TOPLEFT, -6, 0)
    allOffBtn:SetHandler("OnClicked", function() SetAllVisible(false) end)

    -- 検索ボックス
    local sbg = WINDOW_MANAGER:CreateControl("CASW_SearchBG", win, CT_TEXTURE)
    sbg:SetColor(1, 1, 1, 0.10)
    sbg:SetAnchor(TOPLEFT, win, TOPLEFT, LEFT_W + 14, 70)
    sbg:SetAnchor(TOPRIGHT, win, TOPRIGHT, -10, 70)
    sbg:SetHeight(28)

    local sl = WINDOW_MANAGER:CreateControl("CASW_SearchLabel", win, CT_LABEL)
    sl:SetFont("ZoFontGameMedium")
    sl:SetColor(0.7, 0.7, 0.7, 1)
    sl:SetText(L("search"))
    sl:SetAnchor(LEFT, sbg, LEFT, 8, 0)

    -- 入力欄の入れ物 (ESO標準の入力欄テンプレートは親の四隅に合わせて配置される)
    local sbox = WINDOW_MANAGER:CreateControl("CASW_SearchBox", win, CT_CONTROL)
    sbox:SetAnchor(TOPLEFT, sbg, TOPLEFT, 52, 0)
    sbox:SetAnchor(BOTTOMRIGHT, sbg, BOTTOMRIGHT, 0, 0)

    -- まず標準テンプレートで作成(カーソル表示・文字入力が確実)。失敗したら自作にフォールバック
    local okTpl
    okTpl, search = pcall(function()
        return WINDOW_MANAGER:CreateControlFromVirtual("CASW_Search", sbox, "ZO_DefaultEditForBackdrop")
    end)
    if not okTpl or not search then
        search = WINDOW_MANAGER:CreateControl("CASW_Search", sbox, CT_EDITBOX)
        search:SetFont("ZoFontGameMedium")
        search:SetColor(1, 1, 1, 1)
        search:SetAnchor(TOPLEFT, sbox, TOPLEFT, 4, 4)
        search:SetAnchor(BOTTOMRIGHT, sbox, BOTTOMRIGHT, -6, -2)
    end
    search:SetMaxInputChars(64)
    search:SetMouseEnabled(true)
    -- キーボード入力の占有は、入力欄にフォーカスがある間だけ行う
    -- (常時有効にすると、ウィンドウ表示中に歩行などのキー操作が効かなくなる)
    pcall(function() search:SetKeyboardEnabled(false) end)
    search:SetHandler("OnFocusGained", function(self) pcall(function() self:SetKeyboardEnabled(true) end) end)
    search:SetHandler("OnFocusLost",   function(self) pcall(function() self:SetKeyboardEnabled(false) end) end)
    search:SetEditEnabled(true)
    search:SetDrawLevel(10)
    search:SetHandler("OnTextChanged", function() FillList() end)
    search:SetHandler("OnEnter",  function(self) self:LoseFocus() end)
    search:SetHandler("OnEscape", function(self) self:LoseFocus() end)
    search:SetHandler("OnMouseDown", function(self) self:TakeFocus() end)

    -- 検索バーのどこをクリックしても入力欄にフォーカスする
    sbg:SetMouseEnabled(true)
    sbg:SetHandler("OnMouseDown", function() zo_callLater(function() search:TakeFocus() end, 10) end)
    sbox:SetMouseEnabled(true)
    sbox:SetHandler("OnMouseDown", function() zo_callLater(function() search:TakeFocus() end, 10) end)

    -- アドオン一覧
    list = WINDOW_MANAGER:CreateControlFromVirtual("CASW_List", win, "ZO_ScrollList")
    list:SetAnchor(TOPLEFT, win, TOPLEFT, LEFT_W + 14, 106)
    list:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -10, -48)
    ZO_ScrollList_AddDataType(list, 1, "CASW_AddOnRow", 26, SetupRow)

    hintLabel = WINDOW_MANAGER:CreateControl("CASW_Hint", win, CT_LABEL)
    hintLabel:SetFont("ZoFontGameSmall")
    hintLabel:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, LEFT_W + 14, -18)

    local reload = MakeButton("CASW_Reload", win, L("reload"), 110)
    reload:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -10, -10)
    reload:SetHandler("OnClicked", function() ReloadUI("ingame") end)
    -- ヒントがボタンに重ならないよう幅を制限
    hintLabel:SetDimensions(WIN_W - LEFT_W - 14 - 140, 20)
    hintLabel:SetMaxLineCount(1)
    hintLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    -- ライブラリを隠すチェックボックス (左パネル下)
    hideLibCheck = WINDOW_MANAGER:CreateControlFromVirtual("CASW_HideLib", win, "ZO_CheckButton")
    hideLibCheck:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 12, -16)
    ZO_CheckButton_SetCheckState(hideLibCheck, sv.hideLibs and true or false)
    ZO_CheckButton_SetToggleFunction(hideLibCheck, function(_, checked) SetHideLibs(checked) end)

    local hideLibLabel = WINDOW_MANAGER:CreateControl("CASW_HideLibLabel", win, CT_LABEL)
    hideLibLabel:SetFont("ZoFontGameMedium")
    hideLibLabel:SetColor(0.85, 0.85, 0.85, 1)
    hideLibLabel:SetText(L("hideLibs"))
    hideLibLabel:SetMouseEnabled(true)
    hideLibLabel:SetAnchor(LEFT, hideLibCheck, RIGHT, 8, 0)
    hideLibLabel:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then SetHideLibs(not sv.hideLibs) end
    end)

    -- 色分けの凡例 (左パネル下)
    local legend = WINDOW_MANAGER:CreateControl("CASW_Legend", win, CT_LABEL)
    legend:SetFont("ZoFontGameSmall")
    legend:SetColor(0.7, 0.7, 0.7, 1)
    legend:SetText(L("groupLegend"))
    legend:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 12, -86)

    -- キャラ間コピー (左パネル下)
    local copyBtn = MakeButton("CASW_CopyBtn", win, L("copyBtn"), LEFT_W - 12)
    copyBtn:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 12, -52)
    copyBtn:SetHandler("OnClicked", function() ShowCopy() end)

    charRows = {}
end

---------------------------------------------------------------------
-- キャラ間コピー: コピー元(1人)とコピー先(複数可)を同じウィンドウで選択
---------------------------------------------------------------------
local COPY_W      = 520
local COL_W       = 240
local COL_X_SRC   = 12
local COL_X_DST   = 268
local COPY_TOP    = 62

local copySummary
local srcRows, dstRows
local copySrc
local copyTargets = {}
local C_DISABLED = { 0.4, 0.4, 0.4, 1 }

local function CountTargets()
    local n = 0
    for _ in pairs(copyTargets) do n = n + 1 end
    return n
end

-- チェックボックス風の四角を描画 (dot=true: 中を小さな点にしてラジオ風)
local function SetBox(row, picked, disabled, dot)
    -- 枠は常に白(無効時のみ暗いグレー)。選択時は中を金色で塗る
    local v = disabled and 0.35 or 1
    for _, e in ipairs(row.boxEdges) do
        e:SetColor(v, v, v, 1)
    end
    local size = dot and 6 or 8
    row.boxFill:SetDimensions(size, size)
    row.boxFill:SetHidden(not picked or disabled)
end

local function RefreshCopyRows()
    if not srcRows then return end
    for _, row in ipairs(srcRows) do
        if row.active then
            local picked = (row.charName == copySrc)
            row.label:SetText(row.baseText)
            local c = picked and C_SELECTED or C_NORMAL
            row.label:SetColor(c[1], c[2], c[3], c[4])
            row.sel:SetHidden(not picked)
            SetBox(row, picked, false, true)
            ApplySwatch(row)
        end
    end
    for _, row in ipairs(dstRows) do
        if row.active then
            local isSrc = (row.charName == copySrc)
            local picked = copyTargets[row.charName] and true or false
            row.label:SetText(row.baseText)
            local c = isSrc and C_DISABLED or (picked and C_SELECTED or C_NORMAL)
            row.label:SetColor(c[1], c[2], c[3], c[4])
            row.sel:SetHidden(not picked)
            SetBox(row, picked, isSrc, false)
            ApplySwatch(row)
        end
    end
    if copySummary then
        local n = CountTargets()
        if copySrc and n > 0 then
            copySummary:SetText(L("summary", copySrc, n))
            copySummary:SetColor(1, 0.7, 0.3, 1)
        else
            copySummary:SetText(L("summaryHint"))
            copySummary:SetColor(0.7, 0.7, 0.7, 1)
        end
    end
end

HideCopy = function()
    if copyWin then copyWin:SetHidden(true) end
end

-- 指定キャラの全アドオンのON/OFF状態を取得 {index = bool}
local function ReadEnabled(charName)
    local result = {}
    local ok = WithFilter(charName, function(am)
        for _, e in ipairs(allEntries) do
            local _, _, _, _, enabled = am:GetAddOnInfo(e.index)
            result[e.index] = enabled and true or false
        end
    end)
    if ok then return result end
end

-- src の状態を charName に適用し、変更件数を返す
local function ApplyStates(charName, src)
    local cur = ReadEnabled(charName)
    if not cur then return 0 end
    local changed = 0
    WithFilter(charName, function(am)
        for _, e in ipairs(allEntries) do
            local want = src[e.index]
            if want ~= nil and cur[e.index] ~= want then
                am:SetAddOnEnabled(e.index, want)
                changed = changed + 1
            end
        end
    end)
    return changed
end

-- 全キャラのON/OFF状態を比較し、同じ設定のキャラ(2人以上)を同じ色にする
RefreshGroups = function()
    groupColor = {}
    local bySig, order = {}, {}
    for _, name in ipairs(GetCharacterNames()) do
        local r = ReadEnabled(name)
        if r then
            local parts = {}
            for i, e in ipairs(allEntries) do
                parts[i] = r[e.index] and "1" or "0"
            end
            local sig = table.concat(parts)
            if not bySig[sig] then
                bySig[sig] = {}
                order[#order + 1] = sig
            end
            table.insert(bySig[sig], name)
        end
    end
    local ci = 0
    for _, sig in ipairs(order) do
        local members = bySig[sig]
        if #members >= 2 then
            ci = ci + 1
            local c = GROUP_PALETTE[(ci - 1) % #GROUP_PALETTE + 1]
            for _, n in ipairs(members) do groupColor[n] = c end
        end
    end
    RefreshCharRows()
    RefreshCopyRows()
end

local function DoCopy()
    if not copySrc then
        Say(L("needSrc"))
        return
    end
    local targets = {}
    for name in pairs(copyTargets) do
        if name ~= copySrc then targets[#targets + 1] = name end
    end
    if #targets == 0 then
        Say(L("needDst"))
        return
    end
    table.sort(targets)

    local src = ReadEnabled(copySrc)
    if not src then return end

    local total = 0
    for _, t in ipairs(targets) do
        total = total + ApplyStates(t, src)
    end

    if total > 0 then dirty = true end
    ReadStates()
    RefreshGroups()
    ZO_ScrollList_RefreshVisible(list)
    UpdateCount()
    UpdateHint()

    Say(L("done", copySrc, #targets, table.concat(targets, ", "), total))
    HideCopy()
end

local function MakeCopyRow(prefix, i, x)
    local row = WINDOW_MANAGER:CreateControl(prefix .. i, copyWin, CT_CONTROL)
    row:SetDimensions(COL_W, CHAR_ROW_H)
    row:SetMouseEnabled(true)
    row:SetAnchor(TOPLEFT, copyWin, TOPLEFT, x, COPY_TOP + (i - 1) * CHAR_ROW_H)

    row.sel = WINDOW_MANAGER:CreateControl(prefix .. i .. "Sel", row, CT_TEXTURE)
    row.sel:SetAnchorFill(row)
    row.sel:SetColor(1, 0.85, 0.35, 0.10)
    row.sel:SetDrawLevel(0)
    row.sel:SetHidden(true)

    row.hl = WINDOW_MANAGER:CreateControl(prefix .. i .. "HL", row, CT_TEXTURE)
    row.hl:SetAnchorFill(row)
    row.hl:SetColor(1, 1, 1, 0.12)
    row.hl:SetDrawLevel(0)
    row.hl:SetHidden(true)

    -- 四角いボックス: 白い枠線(上下左右の4本)のみ。背景や影は付けない。選択時は中を塗る
    row.box = WINDOW_MANAGER:CreateControl(prefix .. i .. "Box", row, CT_CONTROL)
    row.box:SetDimensions(16, 16)
    row.box:SetAnchor(LEFT, row, LEFT, 8, 0)

    row.boxEdges = {}
    local function Edge(name, p1, p2, w, h)
        local e = WINDOW_MANAGER:CreateControl(prefix .. i .. "Edge" .. name, row.box, CT_TEXTURE)
        e:SetAnchor(p1, row.box, p1, 0, 0)
        e:SetAnchor(p2, row.box, p2, 0, 0)
        if w then e:SetWidth(w) end
        if h then e:SetHeight(h) end
        e:SetColor(1, 1, 1, 1)
        e:SetDrawLevel(2)
        row.boxEdges[#row.boxEdges + 1] = e
    end
    Edge("T", TOPLEFT,    TOPRIGHT,    nil, 2)
    Edge("B", BOTTOMLEFT, BOTTOMRIGHT, nil, 2)
    Edge("L", TOPLEFT,    BOTTOMLEFT,  2,   nil)
    Edge("R", TOPRIGHT,   BOTTOMRIGHT, 2,   nil)

    row.boxFill = WINDOW_MANAGER:CreateControl(prefix .. i .. "BoxF", row.box, CT_TEXTURE)
    row.boxFill:SetDimensions(8, 8)
    row.boxFill:SetAnchor(CENTER, row.box, CENTER, 0, 0)
    row.boxFill:SetColor(1, 0.85, 0.35, 1)
    row.boxFill:SetDrawLevel(3)
    row.boxFill:SetHidden(true)

    row.label = WINDOW_MANAGER:CreateControl(prefix .. i .. "Label", row, CT_LABEL)
    row.label:SetFont("ZoFontGameMedium")
    row.label:SetAnchor(LEFT, row, LEFT, 32, 0)
    row.label:SetDimensions(COL_W - 32 - 80, CHAR_ROW_H)
    row.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.label:SetMaxLineCount(1)
    row.label:SetDrawLevel(3)

    row.badge = WINDOW_MANAGER:CreateControl(prefix .. i .. "Badge", row, CT_LABEL)
    row.badge:SetFont("ZoFontGameSmall")
    row.badge:SetColor(0.5, 0.9, 0.6, 1)
    row.badge:SetText(L("loggedIn"))
    row.badge:SetAnchor(RIGHT, row, RIGHT, -22, 0)
    row.badge:SetDrawLevel(3)
    row.badge:SetHidden(true)

    row.swatch = WINDOW_MANAGER:CreateControl(prefix .. i .. "Swatch", row, CT_TEXTURE)
    row.swatch:SetDimensions(10, 10)
    row.swatch:SetAnchor(RIGHT, row, RIGHT, -6, 0)
    row.swatch:SetDrawLevel(3)
    row.swatch:SetHidden(true)

    row:SetHandler("OnMouseEnter", function(self) self.hl:SetHidden(false) end)
    row:SetHandler("OnMouseExit",  function(self) self.hl:SetHidden(true) end)
    return row
end

local function GetSrcRow(i)
    local row = srcRows[i]
    if row then return row end
    row = MakeCopyRow("CASW_SrcRow", i, COL_X_SRC)
    row:SetHandler("OnMouseUp", function(self, button, upInside)
        if not (upInside and button == MOUSE_BUTTON_INDEX_LEFT) then return end
        copySrc = self.charName
        copyTargets[copySrc] = nil     -- 元と先は同一にできない
        RefreshCopyRows()
    end)
    srcRows[i] = row
    return row
end

local function GetDstRow(i)
    local row = dstRows[i]
    if row then return row end
    row = MakeCopyRow("CASW_DstRow", i, COL_X_DST)
    row:SetHandler("OnMouseUp", function(self, button, upInside)
        if not (upInside and button == MOUSE_BUTTON_INDEX_LEFT) then return end
        if self.charName == copySrc then return end
        copyTargets[self.charName] = (not copyTargets[self.charName]) or nil
        RefreshCopyRows()
    end)
    dstRows[i] = row
    return row
end

local function CreateCopyWindow()
    if copyWin then return end

    copyWin = WINDOW_MANAGER:CreateTopLevelWindow("CASW_CopyWindow")
    copyWin:SetDimensions(COPY_W, 200)
    copyWin:SetMouseEnabled(true)
    copyWin:SetMovable(true)
    copyWin:SetClampedToScreen(true)
    copyWin:SetDrawTier(DT_HIGH)
    copyWin:SetHidden(true)

    local bg = WINDOW_MANAGER:CreateControl("CASW_CopyBG", copyWin, CT_TEXTURE)
    bg:SetAnchorFill(copyWin)
    bg:SetColor(0.05, 0.05, 0.08, 0.97)

    local t = WINDOW_MANAGER:CreateControl("CASW_CopyTitle", copyWin, CT_LABEL)
    t:SetFont("ZoFontGameBold")
    t:SetColor(1, 0.85, 0.35, 1)
    t:SetText(L("copyTitle"))
    t:SetAnchor(TOPLEFT, copyWin, TOPLEFT, 12, 10)

    local hs = WINDOW_MANAGER:CreateControl("CASW_CopyHeadSrc", copyWin, CT_LABEL)
    hs:SetFont("ZoFontGameBold")
    hs:SetColor(0.7, 0.7, 0.7, 1)
    hs:SetText(L("copySrcHead"))
    hs:SetAnchor(TOPLEFT, copyWin, TOPLEFT, COL_X_SRC, 38)

    local hd = WINDOW_MANAGER:CreateControl("CASW_CopyHeadDst", copyWin, CT_LABEL)
    hd:SetFont("ZoFontGameBold")
    hd:SetColor(0.7, 0.7, 0.7, 1)
    hd:SetText(L("copyDstHead"))
    hd:SetAnchor(TOPLEFT, copyWin, TOPLEFT, COL_X_DST, 38)

    local allBtn = MakeButton("CASW_CopyAll", copyWin, L("selectAll"), 56)
    allBtn:SetAnchor(TOPRIGHT, copyWin, TOPRIGHT, -76, 32)
    allBtn:SetHandler("OnClicked", function()
        for _, row in ipairs(dstRows) do
            if row.active and row.charName ~= copySrc then
                copyTargets[row.charName] = true
            end
        end
        RefreshCopyRows()
    end)

    local noneBtn = MakeButton("CASW_CopyNone", copyWin, L("selectNone"), 56)
    noneBtn:SetAnchor(TOPRIGHT, copyWin, TOPRIGHT, -12, 32)
    noneBtn:SetHandler("OnClicked", function()
        copyTargets = {}
        RefreshCopyRows()
    end)

    copySummary = WINDOW_MANAGER:CreateControl("CASW_CopySummary", copyWin, CT_LABEL)
    copySummary:SetFont("ZoFontGameMedium")
    copySummary:SetAnchor(BOTTOMLEFT, copyWin, BOTTOMLEFT, 12, -52)

    local exec = MakeButton("CASW_CopyExec", copyWin, L("execute"), 130)
    exec:SetAnchor(BOTTOMLEFT, copyWin, BOTTOMLEFT, 12, -10)
    exec:SetHandler("OnClicked", DoCopy)

    local cancel = MakeButton("CASW_CopyCancel", copyWin, L("cancel"), 130)
    cancel:SetAnchor(BOTTOMRIGHT, copyWin, BOTTOMRIGHT, -12, -10)
    cancel:SetHandler("OnClicked", HideCopy)

    srcRows, dstRows = {}, {}
end

ShowCopy = function()
    CreateCopyWindow()

    local names = GetCharacterNames()
    local current = GetCurrentCharName()
    if #names < 2 then
        copyWin:SetHidden(true)
        Say(L("needTwoChars"))
        return
    end

    for i, name in ipairs(names) do
        local sr, dr = GetSrcRow(i), GetDstRow(i)
        sr.charName, sr.baseText = name, name
        dr.charName, dr.baseText = name, name
        sr.badge:SetHidden(name ~= current)
        dr.badge:SetHidden(name ~= current)
        sr:SetHidden(false)
        dr:SetHidden(false)
        sr.active, dr.active = true, true
        sr.label:SetText(name)      -- 更新処理を待たずに名前を直接表示
        dr.label:SetText(name)
    end
    for i = #names + 1, #srcRows do
        srcRows[i]:SetHidden(true)
        dstRows[i]:SetHidden(true)
        srcRows[i].active, dstRows[i].active = false, false
    end

    copySrc = selectedChar      -- 初期のコピー元は、ウィンドウで選択中のキャラ
    copyTargets = {}

    copyWin:SetDimensions(COPY_W, COPY_TOP + #names * CHAR_ROW_H + 84)
    copyWin:ClearAnchors()
    -- メインウィンドウの右側に重ならないよう配置(右に入らない時は左側)
    local screenW = GuiRoot:GetWidth()
    local winLeft, winRight = win:GetLeft() or 0, win:GetRight() or 0
    -- ドラッグで飛ばないよう、メインウィンドウ基準ではなく画面(GuiRoot)基準の絶対位置で固定する
    local x
    if winRight + 8 + COPY_W <= screenW or winLeft - 8 - COPY_W < 0 then
        x = winRight + 8
    else
        x = winLeft - 8 - COPY_W
    end
    copyWin:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, win:GetTop() or 0)
    -- 先にウィンドウを表示する。非表示のまま更新すると、親が非表示のため
    -- row:IsHidden() が true になり、名前・選択状態・色が反映されない
    copyWin:SetHidden(false)
    RefreshCopyRows()
end

local function Show(withCursor)
    CreateWindow()

    win:ClearAnchors()
    if sv.x and sv.y then
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.x, sv.y)
    else
        win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end

    BuildEntries()
    local names, current = BuildCharList()
    RefreshGroups()
    search:SetText("")

    win:SetHidden(false)
    if withCursor then EnterCursorMode() end
    StartMoveWatch()
    UpdateHint()

    local first = selectedChar
    local found = false
    for _, n in ipairs(names) do if n == first then found = true end end
    if not found then first = current or names[1] end
    if first then
        SelectChar(first)
    else
        Say(L("noCharInfo"))
    end
end

local function IsOpen()
    return win and not win:IsHidden()
end

-- キー1: 表示/非表示を繰り返す(カーソルなし・歩ける)
local function Toggle()
    if IsOpen() then Hide() else Show(true) end
end

-- チャットコマンド・設定メニューのボタン: 開く時はカーソル操作つきで開く
local function ToggleWithCursor()
    if IsOpen() then Hide() else Show(true) end
end

-- Bindings.xml から呼ばれる
function CASW_Toggle()
    Toggle()
end

-- キー2: カーソル操作(閉じていれば開いてカーソルを出す)
function CASW_Cursor()
    if IsOpen() then EnterCursorMode() else Show(true) end
end

---------------------------------------------------------------------
-- settings menu (LibAddonMenu-2.0 がある場合のみ)
---------------------------------------------------------------------
local function CreateSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = ADDON_NAME .. "Panel"
    LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "Easy Addon Setting",
        displayName = "Easy Addon Setting",
        author = "PUYO",
        version = VERSION,
    })

    LAM:RegisterOptionControls(panelName, {
        {
            type = "header",
            name = L("lamWindow"),
        },
        {
            type = "description",
            text = L("lamDesc"),
        },
        {
            type = "button",
            name = L("lamToggle"),
            func = ToggleWithCursor,
            width = "half",
        },
        {
            type = "header",
            name = L("lamListHeader"),
        },
        {
            type = "checkbox",
            name = L("lamHideLibs"),
            tooltip = L("lamHideLibsTT"),
            getFunc = function() return sv.hideLibs end,
            setFunc = SetHideLibs,
        },
        {
            type = "header",
            name = L("lamKeyHeader"),
        },
        {
            type = "description",
            text = L("lamKeyDesc"),
        },
    })
end

---------------------------------------------------------------------
-- init
---------------------------------------------------------------------
local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    CharAddonSwitcherSV = CharAddonSwitcherSV or {}
    sv = CharAddonSwitcherSV
    if sv.hideLibs == nil then sv.hideLibs = true end

    -- /charaddons          : ウィンドウ開閉
    -- /charaddons 文字列   : ウィンドウを開き、その文字列で一覧を絞り込む (検索窓が使えない時の代替)
    -- /charaddons -        : 絞り込みを解除
    SLASH_COMMANDS["/charaddons"] = function(arg)
        arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
        zo_callLater(function()
            if arg == "" then
                ToggleWithCursor()
                return
            end
            if not IsOpen() then Show(true) end
            if arg == "-" then arg = "" end
            search:SetText(arg)
        end, 150)
    end
    CreateSettingsMenu()

    -- インベントリなど別のメニューを開いたらウィンドウを閉じる
    -- (HUD / カーソル付きHUD / 設定メニューの中では表示を維持)
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
        if newState ~= SCENE_SHOWING or not IsOpen() then return end
        local name = scene:GetName()
        if name ~= "hud" and name ~= "hudui" and name ~= "gameMenuInGame" then
            Hide(true)
        end
    end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
