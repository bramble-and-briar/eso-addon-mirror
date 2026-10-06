--[[
    PvPTargetInfo_UI.lua (2.0.0 完成版)

    ENEMY BUFF(buff) / ENEMY DEBUFF(debuff) の2つの独立したトップレベル
    ウィンドウだけを持つ。位置・アイコンサイズ・最大表示件数・表示ON/OFFを
    個別に設定できる。固定フォント(フォントサイズ設定は持たない)。

    各行は [アイコン] [効果名] [残り秒数(+スタック数)] の3要素。

    表示/非表示の方針:
    - sv.enabled が false、またはそのパネル自身の enabled が false なら隠す。
    - 通常プレイ画面(hud/hudui)以外のシーン(メニュー・マップ等)を
      開いている間は隠す(previewMode中は例外)。
    - 中身が0件(表示する効果が無い)の時も隠す。ターゲットなし/NPC/
      重要な効果が何も無い時にパネルだけ残り続けるのを防ぐため。
      ただしpreviewMode中は位置確認のため常に表示する。
--]]

PvPTargetInfo = PvPTargetInfo or {}
local PTI = PvPTargetInfo
PTI.UI = PTI.UI or {}

local WM = WINDOW_MANAGER

local SV_KEY = {
    buff   = "buffUI",
    debuff = "debuffUI",
}

local WINDOW_TITLES = {
    buff   = "ENEMY BUFF",
    debuff = "ENEMY DEBUFF",
}

local TITLE_COLORS = {
    buff   = { 0.55, 1.00, 0.55 }, -- 明るい緑
    debuff = { 1.00, 0.40, 0.40 }, -- 明るい赤
}

local ROW_FONT = "$(BOLD_FONT)|16|soft-shadow-thin"
local TITLE_FONT = "$(BOLD_FONT)|18|soft-shadow-thin"
local ROW_GAP = 4

PTI.UI.windows = PTI.UI.windows or {}
PTI.UI.hasContent = PTI.UI.hasContent or {}

local function SVFor(key)
    return PTI.sv[SV_KEY[key]]
end

local function IconSize(key)
    local sv = SVFor(key)
    return (sv and sv.iconSize) or 20
end

local function RowHeight(key)
    return zo_max(IconSize(key), 18) + ROW_GAP
end

--------------------------------------------------------------------------
-- ウィンドウ生成
--------------------------------------------------------------------------
function PTI.UI.CreateWindow(key)
    local win = WM:CreateTopLevelWindow("PTI_Window_" .. key)
    win:SetDimensions(260, 40)
    win:SetMouseEnabled(false) -- PS5はマウス操作不可。移動は/ptiコマンドか設定画面で行う
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    -- アドオン設定画面(LAM2)は描画順が高いオーバーレイのため、手前に描画する。
    win:SetDrawTier(DT_HIGH)

    local titleLabel = WM:CreateControl("PTI_Title_" .. key, win, CT_LABEL)
    titleLabel:SetFont(TITLE_FONT)
    titleLabel:SetAnchor(TOPLEFT, win, TOPLEFT, 4, 0)
    local tc = TITLE_COLORS[key] or { 1, 1, 1 }
    titleLabel:SetColor(tc[1], tc[2], tc[3], 1)
    titleLabel:SetText(WINDOW_TITLES[key])

    local container = WM:CreateControl("PTI_Rows_" .. key, win, CT_CONTROL)
    container:SetAnchor(TOPLEFT, titleLabel, BOTTOMLEFT, -4, 6)
    container:SetDimensions(260, 200)

    local entry = {
        window = win,
        titleLabel = titleLabel,
        container = container,
        rowPool = {},
        key = key,
    }
    PTI.UI.windows[key] = entry
    return entry
end

function PTI.UI.GetWindow(key)
    return PTI.UI.windows[key]
end

--------------------------------------------------------------------------
-- 行プール(アイコン+名前+残り時間)
--------------------------------------------------------------------------
function PTI.UI.AcquireRow(key, index)
    local entry = PTI.UI.windows[key]
    local rowPool = entry.rowPool
    local row = rowPool[index]
    if not row then
        local rowHeight = RowHeight(key)
        local size = IconSize(key)

        local icon = WM:CreateControl("PTI_RowIcon_" .. key .. index, entry.container, CT_TEXTURE)
        icon:SetDimensions(size, size)
        icon:SetAnchor(TOPLEFT, entry.container, TOPLEFT, 0, (index - 1) * rowHeight)

        local nameLabel = WM:CreateControl("PTI_RowName_" .. key .. index, entry.container, CT_LABEL)
        nameLabel:SetFont(ROW_FONT)
        nameLabel:SetAnchor(TOPLEFT, icon, TOPRIGHT, 4, 0)
        nameLabel:SetAnchor(BOTTOMLEFT, icon, BOTTOMRIGHT, 4, 0)

        local timeLabel = WM:CreateControl("PTI_RowTime_" .. key .. index, entry.container, CT_LABEL)
        timeLabel:SetFont(ROW_FONT)
        timeLabel:SetAnchor(TOPRIGHT, entry.container, TOPRIGHT, 0, (index - 1) * rowHeight)

        row = { icon = icon, nameLabel = nameLabel, timeLabel = timeLabel }
        rowPool[index] = row
    end
    row.icon:SetHidden(false)
    row.nameLabel:SetHidden(false)
    row.timeLabel:SetHidden(false)
    return row
end

function PTI.UI.ReleaseUnusedRows(key, fromIndex)
    local entry = PTI.UI.windows[key]
    if not entry then return end
    local rowPool = entry.rowPool
    for i = fromIndex, #rowPool do
        rowPool[i].icon:SetHidden(true)
        rowPool[i].nameLabel:SetHidden(true)
        rowPool[i].timeLabel:SetHidden(true)
    end
end

-- アイコンサイズ変更時、既存の行のサイズ・位置を再配置する
function PTI.UI.RefreshRowLayout(key)
    local entry = PTI.UI.windows[key]
    if not entry then return end
    local rowHeight = RowHeight(key)
    local size = IconSize(key)
    for i, row in ipairs(entry.rowPool) do
        row.icon:SetDimensions(size, size)
        row.icon:ClearAnchors()
        row.icon:SetAnchor(TOPLEFT, entry.container, TOPLEFT, 0, (i - 1) * rowHeight)
        row.nameLabel:ClearAnchors()
        row.nameLabel:SetAnchor(TOPLEFT, row.icon, TOPRIGHT, 4, 0)
        row.nameLabel:SetAnchor(BOTTOMLEFT, row.icon, BOTTOMRIGHT, 4, 0)
        row.timeLabel:ClearAnchors()
        row.timeLabel:SetAnchor(TOPRIGHT, entry.container, TOPRIGHT, 0, (i - 1) * rowHeight)
    end
end

--------------------------------------------------------------------------
-- 位置・表示制御
--------------------------------------------------------------------------
function PTI.UI.ApplyPosition(key)
    local entry = PTI.UI.windows[key]
    local sv = SVFor(key)
    if not entry or not sv then return end

    if type(sv.point) ~= "number" then sv.point = CENTER end
    if type(sv.relPoint) ~= "number" then sv.relPoint = CENTER end

    entry.window:ClearAnchors()
    entry.window:SetAnchor(sv.point, GuiRoot, sv.relPoint, sv.x, sv.y)
end

function PTI.UI.ApplyAllPositions()
    PTI.UI.ApplyPosition("buff")
    PTI.UI.ApplyPosition("debuff")
end

-- key のウィンドウを、全体の有効設定・パネル自身の有効設定・現在のシーン・
-- 中身の有無だけで表示/非表示にする。previewMode中はシーン判定と中身判定の
-- 両方を無視して常時表示する(位置調整用)。
function PTI.UI.SetWindowVisible(key)
    local entry = PTI.UI.windows[key]
    local sv = SVFor(key)
    if not entry or not sv then return end

    local previewing = PTI.sv.previewMode
    local hiddenByScene = PTI.UI.hiddenByScene and not previewing
    local hiddenByEmpty = (not previewing) and not PTI.UI.hasContent[key]

    local shouldShow = PTI.sv.enabled and sv.enabled ~= false and not hiddenByScene and not hiddenByEmpty
    entry.window:SetHidden(not shouldShow)
end

function PTI.UI.RefreshVisibility()
    for key in pairs(PTI.UI.windows) do
        PTI.UI.SetWindowVisible(key)
    end
end

function PTI.UI.Initialize()
    PTI.UI.CreateWindow("buff")
    PTI.UI.CreateWindow("debuff")

    PTI.UI.ApplyAllPositions()
    PTI.UI.hasContent.buff = false
    PTI.UI.hasContent.debuff = false
    PTI.UI.RefreshVisibility()

    -- 通常プレイ画面(hud/hudui)以外のシーン(マップ・メニュー等)が
    -- 表示されている間は全パネルを隠す。previewMode中は例外。
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
        if newState ~= SCENE_SHOWING and newState ~= SCENE_SHOWN then return end
        local sceneName = scene and scene.GetName and scene:GetName()
        local isGameplayScene = (sceneName == "hud" or sceneName == "hudui")

        PTI.UI.hiddenByScene = not isGameplayScene
        PTI.UI.RefreshVisibility()
    end)
end
