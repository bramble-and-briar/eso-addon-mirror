--[[
    PvPTargetInfo_UI.lua

    v1.4.1で修正: パネルが「中身がある時だけ表示」になっていたため、監視リストが
    空の初期状態では何も表示されずユーザーがパネルの位置すら確認できない不具合が
    あった。この版からは、有効になっているパネルは中身の有無に関わらず常時表示し、
    空の時は「登録なし」等のヒントを出す方式に変更している(Target.lua/Procs.lua側)。

    また、設定画面の開閉をOnShow/OnHideイベントで自動検知してプレビュー表示に
    切り替える仕組みは、確実に発火する保証がなく機能していなかったため廃止した。
    代わりに sv.previewMode という単純なON/OFF設定(設定画面のチェックボックス)で
    ユーザーが明示的にプレビューを切り替える方式にしている。単純な設定値の
    ON/OFFなので、動作しない余地がない。

    3つの独立したトップレベルウィンドウを持つ。

        buff   … UI①: 敵の重要バフ
        debuff … UI②: 敵の重要デバフ
        proc   … UI③: 自分のセットProc表示

    3つは互いに完全に独立していて、位置・大きさ(文字サイズ)・表示ON/OFFを
    個別に設定できる。片方を動かしてももう片方には一切影響しない。

    v1.4.11では各行に色付きバッジ(先頭1文字)を試したが、「カッコ悪い」との
    ことでv1.4.12で撤去した。v1.4.12〜v1.4.15では代わりにヘッダー部分を
    役割ごとに色分けした背景バー(「デザイン版」設定)を試したが、暗い背景の
    上では色の変化に気付きにくく改善もできなかったため、v1.4.16で背景バーの
    仕組みごと廃止した。代わりに、タイトル文字そのものの色をBUFF=明るい緑/
    DEBUFF=明るい赤/Proc=水色に固定し、切り替え設定は持たない(常時この配色)。
    背景バーより実装がシンプルになり、視認性の問題も原理的に起こらない。
--]]

PvPTargetInfo = PvPTargetInfo or {}
local PTI = PvPTargetInfo
PTI.UI = PTI.UI or {}

local WM = WINDOW_MANAGER

-- ウィンドウキーとSavedVariables上のサブテーブル名の対応
local SV_KEY = {
    buff   = "buffUI",
    debuff = "debuffUI",
    proc   = "procUI",
}

-- v1.4.3で修正: 「重要バフ」「重要デバフ」の表記を廃止し、シンプルに
-- "BUFF" / "DEBUFF" とだけ表示する方式に変更した。
-- v1.4.23で修正: UI③の表示名を「PROC」から「CONDITION」に変更した
-- (内部の変数名・関数名(PTI.Procs等)はそのまま。表示上の名称のみ変更)。
local WINDOW_TITLES = {
    buff   = "BUFF",
    debuff = "DEBUFF",
    proc   = "CONDITION",
}

-- v1.4.16で追加: ヘッダー背景バー方式(「デザイン版」設定)を廃止した代わりに、
-- タイトル文字そのものの色を役割ごとに固定した。設定項目は持たず常時この配色。
local TITLE_COLORS = {
    buff   = { 0.55, 1.00, 0.55 }, -- 明るい緑(BUFF)
    debuff = { 1.00, 0.40, 0.40 }, -- 明るい赤(DEBUFF)
    proc   = { 0.45, 0.85, 1.00 }, -- 水色(Proc)
}

PTI.UI.windows = PTI.UI.windows or {}

local function SVFor(key)
    return PTI.sv[SV_KEY[key]]
end

function PTI.UI.GetFontSize(key)
    local sv = SVFor(key)
    return (sv and sv.fontSize) or 16
end

function PTI.UI.RowFont(key)
    return string.format("$(BOLD_FONT)|%d|soft-shadow-thin", PTI.UI.GetFontSize(key))
end

function PTI.UI.TitleFont(key)
    return string.format("$(BOLD_FONT)|%d|soft-shadow-thin", PTI.UI.GetFontSize(key) + 4)
end

-- v1.4.9で追加: UI①・UI②の各行の下に残り時間バーを敷くための寸法。
local ROW_BAR_HEIGHT = 3
local ROW_BAR_GAP = 4
local ROW_WIDTH = 260 -- containerのSetDimensionsと合わせてある(バーの全幅の基準)

function PTI.UI.RowHeight(key)
    -- 重要バフ/デバフは残り時間が短くなるほど文字が大きくなる(最大+6px)ため、
    -- 行の高さにも余裕を持たせて隣の行と重ならないようにする。
    local base = PTI.UI.GetFontSize(key) + 14
    if key == "buff" or key == "debuff" then
        base = base + ROW_BAR_GAP + ROW_BAR_HEIGHT
    end
    return base
end

--------------------------------------------------------------------------

-- 残り時間による強調ティア(UI①・UI②で共通利用)
--
-- 判定は「画面に表示している秒数(zo_ceilで丸めた整数)」を基準にする。
-- 生の小数値で判定すると、表示上の秒数と強調色が食い違うことがあるため。
-- 色・フォントは呼び出しのたびに毎回SetColor/SetFontし直し、アルファ値も
-- 必ず1.0で明示指定する(前回値との差分チェックによる更新省略はしない)。
--
-- v1.4.9で変更: 残り6秒以上(ベース表示)の色を、UI①/UI②で固定の役割色に
-- 分けた(BUFF=緑系, DEBUFF=赤系)。これにより「今どちらのパネルを見て
-- いるか」ではなく「バフかデバフか」が色そのもので即座に分かるようにした。
-- 残り5秒以下の緊急枠(黄→オレンジ→赤)は従来通りBUFF/DEBUFF共通の
-- エスカレーション色で、役割色より優先して上書きする。
--------------------------------------------------------------------------
local BASE_COLORS = {
    buff   = { 0.35, 0.85, 0.45, 1 }, -- 緑系(BUFF)
    debuff = { 0.95, 0.35, 0.35, 1 }, -- 赤系(DEBUFF)
}

local IMPORTANT_TIERS = {
    { maxSeconds = 1,         color = { 1, 0.15, 0.15, 1 }, sizeDelta = 6, outline = true,  prefix = "!!! " }, -- 残り1秒以下: 最大強調
    { maxSeconds = 3,         color = { 1, 0.45, 0.10, 1 }, sizeDelta = 4, outline = true,  prefix = "!! " },  -- 残り2〜3秒: オレンジ+強調
    { maxSeconds = 5,         color = { 1, 0.92, 0.25, 1 }, sizeDelta = 2, outline = false, prefix = "! " },   -- 残り4〜5秒: 黄色(アンバー)
    { maxSeconds = math.huge, color = nil,                  sizeDelta = 0, outline = false, prefix = "" },     -- 残り6秒以上・不明(永続等): BASE_COLORS[key]を使う
}

-- displaySecondsがnil(残り時間不明・永続系)の場合は「6秒以上」と同じ扱いにする。
-- keyには"buff"または"debuff"を渡す(ベース色の役割分けに使う)。
function PTI.UI.GetImportantTier(key, displaySeconds)
    local s = displaySeconds or math.huge
    for _, tier in ipairs(IMPORTANT_TIERS) do
        if s <= tier.maxSeconds then
            if tier.color then return tier end
            local base = BASE_COLORS[key] or { 0.75, 0.75, 0.8, 1 }
            return { maxSeconds = tier.maxSeconds, color = base, sizeDelta = tier.sizeDelta, outline = tier.outline, prefix = tier.prefix }
        end
    end
    return IMPORTANT_TIERS[#IMPORTANT_TIERS]
end

function PTI.UI.BuildTierFont(key, sizeDelta, outline)
    local size = PTI.UI.GetFontSize(key) + (sizeDelta or 0)
    return string.format("$(BOLD_FONT)|%d|%s", size, outline and "thick-outline" or "soft-shadow-thin")
end

--------------------------------------------------------------------------
-- ウィンドウ生成(UI①・UI②・UI③で共通のファクトリ)
--------------------------------------------------------------------------
function PTI.UI.CreateWindow(key)
    local win = WM:CreateTopLevelWindow("PTI_Window_" .. key)
    win:SetDimensions(260, 40)
    win:SetMouseEnabled(false) -- PS5はマウス操作不可(移動は/ptiコマンドか設定画面のスライダーで行う)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    -- アドオン設定画面(LAM2パネル)は描画順(DrawTier)が高いオーバーレイのため、
    -- SetHiddenされていなくても裏に隠れて見えなくなる。DT_HIGHで手前に描画する。
    win:SetDrawTier(DT_HIGH)

    -- v1.4.16で修正: 背景バー方式の「デザイン版」ヘッダーは廃止した。
    -- タイトル文字そのものを役割色(TITLE_COLORS)で固定表示するだけの、
    -- 背景テクスチャを持たないシンプルな構成にした。
    local titleLabel = WM:CreateControl("PTI_Title_" .. key, win, CT_LABEL)
    titleLabel:SetFont(PTI.UI.TitleFont(key))
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

-- key の行プールから index 番目の行を取得(無ければ生成)する共通ヘルパー。
-- Target.lua / Procs.lua の両方から呼ばれる。
function PTI.UI.AcquireRow(key, index)
    local entry = PTI.UI.windows[key]
    local rowPool = entry.rowPool
    local row = rowPool[index]
    if not row then
        local rowHeight = PTI.UI.RowHeight(key)
        local nameLabel = WM:CreateControl("PTI_RowName_" .. key .. index, entry.container, CT_LABEL)
        nameLabel:SetFont(PTI.UI.RowFont(key))
        nameLabel:SetAnchor(TOPLEFT, entry.container, TOPLEFT, 0, (index - 1) * rowHeight)

        local timeLabel = WM:CreateControl("PTI_RowTime_" .. key .. index, entry.container, CT_LABEL)
        timeLabel:SetFont(PTI.UI.RowFont(key))
        timeLabel:SetAnchor(TOPRIGHT, entry.container, TOPRIGHT, 0, (index - 1) * rowHeight)

        row = { nameLabel = nameLabel, timeLabel = timeLabel }

        -- v1.4.9で追加: UI①(buff)・UI②(debuff)だけ、行の下端に残り時間バーを敷く。
        -- UI③(proc)は残り時間の概念を扱わないため生成しない。
        if key == "buff" or key == "debuff" then
            local barY = index * rowHeight - ROW_BAR_HEIGHT
            local barBG = WM:CreateControl("PTI_RowBarBG_" .. key .. index, entry.container, CT_TEXTURE)
            barBG:SetTexture("EsoUI/Art/Miscellaneous/blank.dds")
            barBG:SetColor(1, 1, 1, 0.12)
            barBG:SetHeight(ROW_BAR_HEIGHT)
            barBG:SetAnchor(TOPLEFT, entry.container, TOPLEFT, 0, barY)
            barBG:SetWidth(ROW_WIDTH)

            local barFill = WM:CreateControl("PTI_RowBarFill_" .. key .. index, entry.container, CT_TEXTURE)
            barFill:SetTexture("EsoUI/Art/Miscellaneous/blank.dds")
            barFill:SetHeight(ROW_BAR_HEIGHT)
            barFill:SetAnchor(TOPLEFT, entry.container, TOPLEFT, 0, barY)
            barFill:SetWidth(ROW_WIDTH)

            row.barBG = barBG
            row.barFill = barFill
        end

        rowPool[index] = row
    end
    row.nameLabel:SetHidden(false)
    row.timeLabel:SetHidden(false)
    if row.barBG then row.barBG:SetHidden(false) end
    if row.barFill then row.barFill:SetHidden(false) end
    return row
end

function PTI.UI.ReleaseUnusedRows(key, fromIndex)
    local entry = PTI.UI.windows[key]
    local rowPool = entry.rowPool
    for i = fromIndex, #rowPool do
        rowPool[i].nameLabel:SetHidden(true)
        rowPool[i].timeLabel:SetHidden(true)
        if rowPool[i].barBG then rowPool[i].barBG:SetHidden(true) end
        if rowPool[i].barFill then rowPool[i].barFill:SetHidden(true) end
    end
end

-- 行の下の残り時間バーを更新する。percentがnilの場合はバーごと隠す
-- (案内行など、残り時間の概念がないケース用)。
function PTI.UI.SetRowBar(row, percent, color)
    if not row.barFill or not row.barBG then return end
    if not percent then
        row.barBG:SetHidden(true)
        row.barFill:SetHidden(true)
        return
    end
    if percent < 0 then percent = 0 elseif percent > 1 then percent = 1 end
    row.barBG:SetHidden(false)
    row.barFill:SetHidden(false)
    row.barFill:SetWidth(zo_max(1, ROW_WIDTH * percent))
    row.barFill:SetColor(color[1], color[2], color[3], 1)
end

-- 文字サイズ変更時、既存の行の位置・フォントを新しいサイズに合わせて更新する
function PTI.UI.RefreshRowLayout(key)
    local entry = PTI.UI.windows[key]
    if not entry then return end
    local rowHeight = PTI.UI.RowHeight(key)
    entry.titleLabel:SetFont(PTI.UI.TitleFont(key))
    for i, row in ipairs(entry.rowPool) do
        row.nameLabel:SetFont(PTI.UI.RowFont(key))
        row.timeLabel:SetFont(PTI.UI.RowFont(key))
        row.nameLabel:ClearAnchors()
        row.nameLabel:SetAnchor(TOPLEFT, entry.container, TOPLEFT, 0, (i - 1) * rowHeight)
        row.timeLabel:ClearAnchors()
        row.timeLabel:SetAnchor(TOPRIGHT, entry.container, TOPRIGHT, 0, (i - 1) * rowHeight)

        if row.barBG and row.barFill then
            local barY = i * rowHeight - ROW_BAR_HEIGHT
            row.barBG:ClearAnchors()
            row.barBG:SetAnchor(TOPLEFT, entry.container, TOPLEFT, 0, barY)
            row.barFill:ClearAnchors()
            row.barFill:SetAnchor(TOPLEFT, entry.container, TOPLEFT, 0, barY)
        end
    end
end

--------------------------------------------------------------------------
-- 位置・表示制御
--------------------------------------------------------------------------
function PTI.UI.ApplyPosition(key)
    local entry = PTI.UI.windows[key]
    local sv = SVFor(key)
    if not entry or not sv then return end

    -- 過去バージョンの不具合で point/relPoint に文字列が保存されてしまう
    -- ケースを自動修復する(SetAnchorは数値定数を要求するため)。
    if type(sv.point) ~= "number" then sv.point = CENTER end
    if type(sv.relPoint) ~= "number" then sv.relPoint = CENTER end

    entry.window:ClearAnchors()
    entry.window:SetAnchor(sv.point, GuiRoot, sv.relPoint, sv.x, sv.y)
    entry.window:SetScale(sv.scale or 1.0)
end

function PTI.UI.ApplyAllPositions()
    PTI.UI.ApplyPosition("buff")
    PTI.UI.ApplyPosition("debuff")
    PTI.UI.ApplyPosition("proc")
end

function PTI.UI.ApplyFontSize(key)
    PTI.UI.RefreshRowLayout(key)
    if key == "buff" or key == "debuff" then
        if PTI.Target and PTI.Target.RefreshFonts then PTI.Target.RefreshFonts(key) end
    elseif key == "proc" then
        if PTI.Procs and PTI.Procs.RefreshFonts then PTI.Procs.RefreshFonts() end
    end
end

-- key のウィンドウを、全体の有効設定・そのウィンドウ自身の有効設定・
-- 現在のシーン(メニュー/マップが開いているか)だけで表示/非表示にする。
-- 中身(登録済みバフの有無等)は一切条件にしない — 空の時はTarget.lua/
-- Procs.lua側がヒント行を表示するため、パネル自体は常に見える
-- (ユーザーが位置を見失わないようにするため)。
--
-- v1.4.9で修正: sv.previewMode(位置調整用のプレビュー表示)がONの間だけは、
-- メニュー/マップが開いていても隠さない例外にした。これにより「設定画面を
-- 開いたまま位置を微調整したい」という用途はプレビューONの時に限って
-- 引き続き可能にしつつ、通常プレイ中(プレビューOFF)はメニュー/マップを
-- 開いたら確実にパネルが隠れるようにしている。
--
-- STEP5で追加: UI①(buff)・UI②(debuff)のみ、戦闘状態(PTI.UI.hiddenByCombat)を
-- 表示条件に追加した。UI③(proc/Condition)には一切影響しない。previewMode中は
-- この新条件も無視して従来通り表示する(位置調整のため)。
--
-- STEP6で追加: UI③(proc/Condition)は戦闘状態と完全に無関係に、「実際に表示
-- する行があるか(=登録したConditionが発動している、またはプレビュー中)」
-- だけを条件にした(PTI.UI.procHasContent。Procs.lua側のRefreshProcUIが
-- 毎ティック更新する)。UI①②の表示状態には一切依存しないし、UI③の表示状態も
-- UI①②には一切影響しない。previewMode中はこの新条件も無視して従来通り表示する。
function PTI.UI.SetWindowVisible(key)
    local entry = PTI.UI.windows[key]
    local sv = SVFor(key)
    if not entry or not sv then return end

    local hiddenByScene = PTI.UI.hiddenByScene and not PTI.sv.previewMode

    local hiddenByCombat = false
    if key == "buff" or key == "debuff" then
        hiddenByCombat = PTI.UI.hiddenByCombat and not PTI.sv.previewMode
    end

    local hiddenByEmptyProc = false
    if key == "proc" then
        hiddenByEmptyProc = (not PTI.sv.previewMode) and not PTI.UI.procHasContent
    end

    local shouldShow = PTI.sv.enabled and not hiddenByScene and not hiddenByCombat
        and not hiddenByEmptyProc and sv.enabled ~= false
    entry.window:SetHidden(not shouldShow)
end

function PTI.UI.RefreshVisibility()
    for key in pairs(PTI.UI.windows) do
        PTI.UI.SetWindowVisible(key)
    end
end

-- STEP5で追加: EVENT_PLAYER_COMBAT_STATEのハンドラ。ESO本体が戦闘に入った/
-- 抜けた瞬間にだけ1回発火する標準イベントで、常時ポーリングは発生しない
-- (PS5/CS向けの軽量方針に合致)。UI①②の表示だけを切り替え、検知ロジック・
-- UI③には一切触れない。
function PTI.UI.OnCombatStateChanged(_, inCombat)
    PTI.UI.hiddenByCombat = not inCombat
    PTI.UI.RefreshVisibility()
end

function PTI.UI.Initialize()
    PTI.UI.CreateWindow("buff")
    PTI.UI.CreateWindow("debuff")
    PTI.UI.CreateWindow("proc")

    PTI.UI.ApplyAllPositions()
    PTI.UI.RefreshRowLayout("buff")
    PTI.UI.RefreshRowLayout("debuff")
    PTI.UI.RefreshRowLayout("proc")

    -- STEP5で追加: リロードUI等で既に戦闘中の場合に備え、IsUnitInCombatで
    -- 初期値を正しく設定してからRefreshVisibility()する(以後はイベント駆動)。
    PTI.UI.hiddenByCombat = not IsUnitInCombat("player")

    -- STEP6で追加: procHasContentはProcs.lua側の最初のTickが来るまではfalse
    -- (=非表示)としておく(「発動していない時は勝手に表示しない」仕様のため)。
    PTI.UI.procHasContent = false

    PTI.UI.RefreshVisibility()

    EVENT_MANAGER:RegisterForEvent(PTI.name .. "UICombat", EVENT_PLAYER_COMBAT_STATE, PTI.UI.OnCombatStateChanged)

    -- v1.4.9で修正: 以前は「ワールドマップを開いた時だけ」自動的に隠す
    -- 作りだったため、インベントリ・キャラクターシート・クラフト・
    -- ギルドストア等の一般的なメニューを開いてもパネルが残ったままに
    -- なる不具合があった。判定を「ワールドマップかどうか」ではなく
    -- 「現在表示中のシーンが通常プレイ画面(hud/hudui)かどうか」に一般化し、
    -- それ以外のシーン(マップ・メニュー・会話・クラフト台UI等、種類を
    -- 問わず)が表示されている間は全パネルを隠すようにした。
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
        if newState ~= SCENE_SHOWING and newState ~= SCENE_SHOWN then return end
        local sceneName = scene and scene.GetName and scene:GetName()
        local isGameplayScene = (sceneName == "hud" or sceneName == "hudui")

        PTI.UI.hiddenByScene = not isGameplayScene
        PTI.UI.RefreshVisibility()
    end)
end
