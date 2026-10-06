--[[
    PvPTargetInfo_Settings.lua (2.0.0)

    LibAddonMenu-2.0(LAM2)を使った設定パネル。ゲームパッド操作に対応して
    いるため、PS5でもコントローラーでそのまま調整できる
    (チャットコマンド /pti ... も引き続き使用可能)。

    本バージョンでの変更点(検出ロジック・スキャン方式・UI描画処理には
    一切触れていない。変更したのはこの設定画面と、その設定値の保存/
    読み込みだけ):
      v1.4.25の設定画面の構成・文言・操作感に戻した。LAM2の「サブメニュー」
      機能で①敵の重要バフパネル・②敵の重要デバフパネルごとに折りたたみ
      セクションへ再編し、それぞれに「パネル設定(表示・位置・大きさ)」と
      「任意登録(自動検知で拾えない効果の追加)」をまとめて置いている。

      ただし、v1.4.25にあった以下の項目は、v2.0.0の検出・UI処理では
      そもそも使われていない(対応する内部機能が存在しない)ため、ここでは
      意図的に復活させていない。無効な設定を増やして混乱させないためで、
      いずれも元のGetNumBuffs+GetUnitBuffInfo直接スキャン方式や表示処理を
      変更すれば追加できるが、それは別途の変更範囲になる。
        - 検知方式(自動検知/全表示)の切替、全表示モードの除外秒数
          → v2.0.0は常に「キーワード+CC+手動AbilityId」判定のみ
        - ターゲット解除後の保持秒数(holdDuration)
          → v2.0.0はターゲット変更で即座に描画し直す方式のため
        - フォントサイズ・表示倍率(%)
          → v2.0.0はアイコン付き固定フォントのため、代わりに
            「アイコンサイズ」で見た目の大きさを調整する
        - AbilityId学習モード・候補ドロップダウン
          → v2.0.0のスキャンは候補収集を行っていないため、
            AbilityIdを直接入力する一つのテキスト欄に簡略化している
        - ③自分のCondition(セットProc)パネル
          → v2.0.0は敵BUFF/DEBUFF表示に特化しており、この機能自体を
            持っていない
--]]

PvPTargetInfo = PvPTargetInfo or {}
local PTI = PvPTargetInfo
PTI.Settings = PTI.Settings or {}

--------------------------------------------------------------------------
-- UI①・UI②共通の「パネル設定(表示・位置・大きさ)」を組み立てるヘルパー
-- (v1.4.25のBuildPanelControlsと同じ構成・文言。スライダーの対象だけ
--  v2.0.0の実際の設定キー(アイコンサイズ等)に合わせている)
--------------------------------------------------------------------------
local function BuildPanelControls(controls, key, svKey, defaultPos)
    table.insert(controls, {
        type = "checkbox",
        name = "このパネルを表示する",
        tooltip = "OFFにするとこのパネルだけ非表示にできます。",
        getFunc = function() return PTI.sv[svKey].enabled end,
        setFunc = function(value)
            PTI.sv[svKey].enabled = value
            PTI.UI.RefreshVisibility()
        end,
    })
    table.insert(controls, {
        type = "slider",
        name = "横位置 (X)",
        tooltip = "マイナスで画面左へ、プラスで画面右へ動きます。",
        min = -1000, max = 1000, step = 5,
        getFunc = function() return PTI.sv[svKey].x end,
        setFunc = function(value)
            PTI.sv[svKey].x = value
            PTI.UI.ApplyPosition(key)
        end,
        width = "full",
    })
    table.insert(controls, {
        type = "slider",
        name = "縦位置 (Y)",
        tooltip = "マイナスで画面上へ、プラスで画面下へ動きます。",
        min = -1000, max = 1000, step = 5,
        getFunc = function() return PTI.sv[svKey].y end,
        setFunc = function(value)
            PTI.sv[svKey].y = value
            PTI.UI.ApplyPosition(key)
        end,
        width = "full",
    })
    table.insert(controls, {
        type = "slider",
        name = "アイコンサイズ",
        tooltip = "v1.4.25の「表示倍率(%)」に相当する、見た目の大きさの調整です。",
        min = 8, max = 64, step = 1,
        getFunc = function() return PTI.sv[svKey].iconSize end,
        setFunc = function(value)
            PTI.sv[svKey].iconSize = value
            PTI.UI.RefreshRowLayout(key)
        end,
        width = "full",
    })
    table.insert(controls, {
        type = "slider",
        name = "最大表示件数",
        min = 1, max = 12, step = 1,
        getFunc = function() return PTI.sv[svKey].maxRows end,
        setFunc = function(value) PTI.sv[svKey].maxRows = value end,
        width = "full",
    })
    table.insert(controls, {
        type = "button",
        name = "位置をリセット",
        func = function()
            PTI.sv[svKey].point = CENTER
            PTI.sv[svKey].relPoint = CENTER
            PTI.sv[svKey].x = defaultPos.x
            PTI.sv[svKey].y = defaultPos.y
            PTI.UI.ApplyPosition(key)
        end,
    })
end

--------------------------------------------------------------------------
-- UI①・UI②共通の「任意登録(自動検知で拾えない効果を追加)」セクション。
-- v1.4.25は各kind(buff/debuff)別の学習モード+候補ドロップダウン+
-- 登録リストを持っていたが、v2.0.0のスキャンは候補収集機能を持たない
-- ため、AbilityIdを直接入力する一つのテキスト欄に簡略化している。
-- バフ・デバフどちらの欄から入力しても同じ1つのリストに追加され、
-- 実際にどちらのパネルに出るかは効果自体のBUFF/DEBUFF種別で自動的に
-- 決まる(スキャン側の分類処理には一切触れていない)。
--------------------------------------------------------------------------
local function BuildRegistrationControls(controls, kindLabel)
    table.insert(controls, { type = "header", name = "任意登録(自動検知で拾えない効果を追加したい場合のみ)" })
    table.insert(controls, {
        type = "description",
        text = string.format(
            "Major/Minor系・状態異常(CC)・シールド系の名前ヒューリスティックで拾えない%sを追加したい場合に使います。下のデバッグログでAbilityIdを確認し、カンマ区切りで入力してください。普段は空欄のままで問題ありません。バフ・デバフどちらの欄に入力しても同じ1つのリストに追加され、実際の表示先(①バフ/②デバフ)は効果自体の種別で自動的に決まります。",
            kindLabel),
    })
    table.insert(controls, {
        type = "editbox",
        name = "追加AbilityId (カンマ区切り)",
        getFunc = function() return PTI.sv.importantIdsText end,
        setFunc = function(value)
            PTI.sv.importantIdsText = value or ""
            if PTI.Target and PTI.Target.RebuildManualIds then
                PTI.Target.RebuildManualIds()
            end
        end,
        isMultiline = true,
        width = "full",
    })
    table.insert(controls, {
        type = "button",
        name = "登録リストを全て削除",
        func = function()
            PTI.sv.importantIdsText = ""
            if PTI.Target and PTI.Target.RebuildManualIds then
                PTI.Target.RebuildManualIds()
            end
        end,
    })
end

function PTI.Settings.Initialize()
    -- LibAddonMenu-2.0が読み込まれていない場合は何もしない
    -- (万一ライブラリ側に問題があっても本体機能は動き続けるようにするため)
    local LAM = LibAddonMenu2
    if not LAM then
        d("|cFF5555[PvPTargetInfo]|r LibAddonMenu-2.0が見つからないため、設定パネルは利用できません。/pti コマンドで設定してください。")
        return
    end

    local panelData = {
        type = "panel",
        name = "PvPTargetInfo",
        displayName = "PvPTargetInfo",
        author = "Bucketmore",
        version = PTI.version,
        slashCommand = "/pti",
        registerForRefresh = true,
        registerForDefaults = false,
    }
    LAM:RegisterAddonPanel("PTI_LAM_Panel", panelData)

    local optionsTable = {
        { type = "header", name = "PvPTargetInfo" },
        {
            type = "description",
            text = "敵プレイヤーをターゲットすると、①敵の重要バフ・②敵の重要デバフの2つの独立したパネルを画面に表示します。下のサブメニューを開いて、それぞれのパネルの位置・大きさ・登録内容を設定してください。",
        },
        {
            type = "checkbox",
            name = "アドオンを有効にする",
            tooltip = "OFFにすると両方のパネルが非表示になります。",
            getFunc = function() return PTI.sv.enabled end,
            setFunc = function(value)
                PTI.sv.enabled = value
                PTI.UI.RefreshVisibility()
            end,
        },
        {
            type = "checkbox",
            name = "プレビュー表示(サンプルデータで位置・大きさを確認)",
            tooltip = "ONにすると、実際のターゲットが居なくても両方のパネルにサンプルデータが表示されます。位置・アイコンサイズを確認しながら調整したいときにONにし、終わったらOFFに戻してください。",
            getFunc = function() return PTI.sv.previewMode end,
            setFunc = function(value)
                PTI.sv.previewMode = value
                PTI.UI.RefreshVisibility()
            end,
        },
    }

    ----------------------------------------------------------------------
    -- 重要バフ/デバフの自動検知(共通説明。v1.4.25の該当見出しに相当)
    ----------------------------------------------------------------------
    table.insert(optionsTable, { type = "header", name = "重要バフ/デバフの自動検知" })
    table.insert(optionsTable, {
        type = "description",
        text = "状態異常(CC)と「Major/Minor」(日本語版では「(強)」「(弱)」)、およびダメージシールド系の効果を、登録なしで自動的に重要バフ/デバフとして表示します。それでも拾えない効果は、各パネルの「任意登録」からAbilityIdを追加してください。",
    })

    ----------------------------------------------------------------------
    -- サブメニュー①: 敵の重要バフ
    ----------------------------------------------------------------------
    local buffControls = {}
    table.insert(buffControls, {
        type = "description",
        text = "敵にかかっている「重要なバフ」を表示するパネルです。",
    })
    BuildPanelControls(buffControls, "buff", "buffUI", { x = -220, y = -140 })
    BuildRegistrationControls(buffControls, "敵のバフ")
    table.insert(optionsTable, {
        type = "submenu",
        name = "① 敵の重要バフパネル",
        controls = buffControls,
    })

    ----------------------------------------------------------------------
    -- サブメニュー②: 敵の重要デバフ
    ----------------------------------------------------------------------
    local debuffControls = {}
    table.insert(debuffControls, {
        type = "description",
        text = "敵にかかっている「重要なデバフ(状態異常等)」を表示するパネルです。",
    })
    BuildPanelControls(debuffControls, "debuff", "debuffUI", { x = 220, y = -140 })
    BuildRegistrationControls(debuffControls, "敵のデバフ")
    table.insert(optionsTable, {
        type = "submenu",
        name = "② 敵の重要デバフパネル",
        controls = debuffControls,
    })

    ----------------------------------------------------------------------
    -- デバッグログ
    ----------------------------------------------------------------------
    table.insert(optionsTable, { type = "header", name = "検知パイプラインのデバッグログ(開発者向け)" })
    table.insert(optionsTable, {
        type = "description",
        text = "ONにすると、スキャンのたびに対象名・BUFF/DEBUFF件数と、スキャンエラー発生時の内容をチャットに出力します。実戦中は必ずOFFのままにしてください。",
    })
    table.insert(optionsTable, {
        type = "checkbox",
        name = "デバッグログを有効にする",
        getFunc = function() return PTI.sv.debug end,
        setFunc = function(value) PTI.sv.debug = value end,
    })

    LAM:RegisterOptionControls("PTI_LAM_Panel", optionsTable)
end
