--[[
    PvPTargetInfo_Settings.lua

    LibAddonMenu-2.0(LAM2)を使った設定パネル。

    修正版での変更点:
      - 「設定画面を開いたら自動でプレビュー表示に切り替える」仕組み(OnShow/OnHide
        イベントフック)は、確実に発火する保証がなく機能していなかったため廃止。
        代わりに「プレビュー表示」チェックボックス(sv.previewMode)を手動で
        ON/OFFする方式にした。単純な設定値のON/OFFなので動作しない余地がない。
      - オプション項目が大量に並んで分かりにくかったため、LAM2の「サブメニュー」
        機能でUI①・UI②・UI③ごとに折りたたみセクションへ再編。それぞれのセクションに
        「パネル設定」と「登録(表示するバフ/デバフ)」をまとめて置き、
        どの設定が何のためのものか一目で分かるようにした。
      - 重要バフ/デバフの個別ON/OFFを40個のチェックボックスで並べる方式は撤去し、
        1つの手動編集欄(id:名前:1/0)にまとめて、UIの見た目をすっきりさせた。
      - 修正改定3: 手動登録は必須ではなくなり、「自動検知」設定を追加。
        既定でON。状態異常(スタン等)とMajor/Minor系の効果は登録なしで
        自動的に重要バフ/デバフとして表示される。手動登録は、それでも
        拾えない効果を追加したい場合の任意機能という位置づけに変更した。

    ESOの「設定 → アドオン」メニューはゲームパッド操作に対応しているため、
    PS5でもコントローラーでこの画面から調整できる。
    (チャットコマンド /pti ... も引き続き使用可能)
--]]

PvPTargetInfo = PvPTargetInfo or {}
local PTI = PvPTargetInfo
PTI.Settings = PTI.Settings or {}

--------------------------------------------------------------------------
-- 監視リストのシリアライズ(手動編集欄用)
-- 形式: "id:名前:1" (1=表示ON, 0=表示OFF) をカンマ区切りで並べたもの
--------------------------------------------------------------------------
local function SerializeWatchList(kind)
    local list = PTI.Target.GetWatchListSorted(kind)
    local parts = {}
    for _, e in ipairs(list) do
        table.insert(parts, string.format("%d:%s:%s", e.id, e.name, e.enabled and "1" or "0"))
    end
    return table.concat(parts, ",")
end

local function DeserializeWatchList(kind, text)
    PTI.Target.ClearWatch(kind)
    for entry in string.gmatch(text or "", "[^,]+") do
        local idStr, name, enabledStr = entry:match("^%s*(%d+)%s*:%s*(.-)%s*:%s*([01])%s*$")
        local id = tonumber(idStr)
        if id and name and name ~= "" then
            PTI.Target.AddWatch(kind, id, name)
            PTI.Target.SetWatchEnabled(kind, id, enabledStr == "1")
        end
    end
end

--------------------------------------------------------------------------
-- 学習モードの候補ドロップダウンを最新の状態に更新する
--------------------------------------------------------------------------
function PTI.Settings.RefreshProcPendingDropdown()
    local dd = _G["PTI_ProcPendingDropdown"]
    if not dd or not dd.UpdateChoices then return end
    if not (PTI.Procs and PTI.Procs.GetPendingChoices) then return end
    local labels, values = PTI.Procs.GetPendingChoices()
    if #labels == 0 then labels, values = { "(候補なし。学習モードON後にセット効果を発動させてください)" }, { "" } end
    pcall(function() dd:UpdateChoices(labels, values) end)
end

--------------------------------------------------------------------------
-- v2.5.0: Proc CD設定(手動登録・履歴)の表示を最新にする
--------------------------------------------------------------------------
PTI.Settings.cdForm = PTI.Settings.cdForm or { setKey = "", id = "", cd = "", name = "", reg = "", editCd = "", msg = nil }

function PTI.Settings.RefreshCdUI()
    local CD = PTI.ProcCD
    if not CD then return end
    local dd = _G["PTI_CD_ManualSetDd"]
    if dd and dd.UpdateChoices and CD.GetSetChoices then
        local labels, values = CD.GetSetChoices()
        pcall(function() dd:UpdateChoices(labels, values) end)
    end
    local rd = _G["PTI_CD_RegDd"]
    if rd and rd.UpdateChoices and CD.GetRegChoices then
        local labels, values = CD.GetRegChoices()
        pcall(function() rd:UpdateChoices(labels, values) end)
    end
    for _, ref in ipairs({ "PTI_CD_Status", "PTI_CD_ManualPreview", "PTI_CD_RegDetail", "PTI_CD_History", "PTI_CD_Health", "PTI_CD_IdList" }) do
        local c = _G[ref]
        if c and c.UpdateValue then pcall(function() c:UpdateValue() end) end
    end
end

function PTI.Settings.RefreshWatchPendingDropdowns()
    local buffDd = _G["PTI_BuffPendingDropdown"]
    if buffDd and buffDd.UpdateChoices and PTI.Target and PTI.Target.GetPendingChoices then
        local labels, values = PTI.Target.GetPendingChoices("buff")
        if #labels == 0 then labels, values = { "(候補なし。学習モードON後に敵のバフを表示させてください)" }, { "" } end
        pcall(function() buffDd:UpdateChoices(labels, values) end)
    end

    local debuffDd = _G["PTI_DebuffPendingDropdown"]
    if debuffDd and debuffDd.UpdateChoices and PTI.Target and PTI.Target.GetPendingChoices then
        local labels, values = PTI.Target.GetPendingChoices("debuff")
        if #labels == 0 then labels, values = { "(候補なし。学習モードON後に敵のデバフを表示させてください)" }, { "" } end
        pcall(function() debuffDd:UpdateChoices(labels, values) end)
    end
end

--------------------------------------------------------------------------
-- UI①/UI②/UI③共通の「パネル設定(表示・位置・大きさ)」を組み立てるヘルパー
--------------------------------------------------------------------------
local function BuildPanelControls(controls, key, svKey, defaultPos)
    table.insert(controls, {
        type = "checkbox",
        name = "このパネルを表示する",
        tooltip = "OFFにするとこのパネルだけ非表示にできます。",
        getFunc = function() return PTI.sv[svKey].enabled end,
        setFunc = function(value)
            PTI.sv[svKey].enabled = value
            -- v2.0.7: パネルOFF中は①②のスキャンを止めるため、ON/OFF直後に再評価して
            -- 即座に再開/停止する(ConditionはUI側の既存処理で整合する)。
            if (key == "buff" or key == "debuff") and PTI.Target and PTI.Target.ForceRefresh then
                PTI.Target.ForceRefresh()
            end
            -- v2.1.0: UI④をOFFにしたらProc CDの監視(Tick・イベント)も止める
            if key == "cd" and PTI.ProcCD and PTI.ProcCD.Sync then PTI.ProcCD.Sync() end
            PTI.UI.RefreshVisibility()
        end,
    })
    table.insert(controls, {
        type = "slider",
        name = "横位置 (X)",
        tooltip = "マイナスで画面左へ、プラスで画面右へ動きます。",
        min = -800, max = 800, step = 5,
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
        min = -800, max = 800, step = 5,
        getFunc = function() return PTI.sv[svKey].y end,
        setFunc = function(value)
            PTI.sv[svKey].y = value
            PTI.UI.ApplyPosition(key)
        end,
        width = "full",
    })
    table.insert(controls, {
        type = "slider",
        name = "大きさ (%)",
        min = 50, max = 200, step = 5,
        getFunc = function() return zo_round(PTI.sv[svKey].scale * 100) end,
        setFunc = function(value)
            PTI.sv[svKey].scale = value / 100
            PTI.UI.ApplyPosition(key)
        end,
        width = "full",
    })
    table.insert(controls, {
        type = "slider",
        name = "文字サイズ",
        min = 10, max = 32, step = 1,
        getFunc = function() return PTI.sv[svKey].fontSize end,
        setFunc = function(value)
            PTI.sv[svKey].fontSize = value
            PTI.UI.ApplyFontSize(key)
        end,
        width = "full",
    })
    table.insert(controls, {
        type = "slider",
        name = "最大表示件数",
        tooltip = "このパネルに同時に並べる項目数の上限です。",
        min = 1, max = 10, step = 1,
        getFunc = function() return PTI.sv[svKey].maxRows end,
        setFunc = function(value) PTI.sv[svKey].maxRows = value end,
        width = "full",
    })
    table.insert(controls, {
        type = "button",
        name = "位置・大きさをリセット",
        func = function()
            PTI.sv[svKey].point = CENTER
            PTI.sv[svKey].relPoint = CENTER
            PTI.sv[svKey].x = defaultPos.x
            PTI.sv[svKey].y = defaultPos.y
            PTI.sv[svKey].scale = 1.0
            PTI.UI.ApplyPosition(key)
        end,
    })
end

--------------------------------------------------------------------------
-- UI①・UI②共通の「登録(表示するバフ/デバフ)」セクションを組み立てるヘルパー
--------------------------------------------------------------------------
local function BuildWatchControls(controls, kind, pendingReference)
    local kindLabel = (kind == "debuff") and "デバフ" or "バフ"

    table.insert(controls, { type = "header", name = "任意登録(自動検知で拾えない効果を追加したい場合のみ)" })
    table.insert(controls, {
        type = "description",
        text = string.format(
            "手順: ①上の「敵のバフ/デバフを学習」をONにする ②戦闘や模擬戦で敵に%sを見せてもらう ③少し待つと下のドロップダウンに候補が出るので選ぶだけで登録完了。",
            kindLabel),
    })
    table.insert(controls, {
        type = "dropdown",
        name = "検出された候補から選んで登録",
        choices = { "(候補なし。学習モードON後に対象の効果を表示させてください)" },
        choicesValues = { "" },
        getFunc = function() return "" end,
        setFunc = function(value)
            if value == "" or value == nil then return end
            if PTI.Target and PTI.Target.RegisterPendingById then
                local ok, name = PTI.Target.RegisterPendingById(kind, value)
                if ok then
                    d(string.format("|c55CCFF[PvPTargetInfo]|r \"%s\" を登録しました。", name))
                end
            end
        end,
        reference = pendingReference,
        width = "full",
    })
    table.insert(controls, {
        type = "editbox",
        name = "登録リスト (id:名前:1,id:名前:0,...) ※1=表示ON/0=OFF、削除もここで行う",
        getFunc = function() return SerializeWatchList(kind) end,
        setFunc = function(value) DeserializeWatchList(kind, value) end,
        isMultiline = true,
        width = "full",
    })
    table.insert(controls, {
        type = "button",
        name = "登録リストを全て削除",
        func = function() PTI.Target.ClearWatch(kind) end,
    })
end

function PTI.Settings.Initialize()
    -- LibAddonMenu-2.0が読み込まれていない場合は何もしない
    -- (万一ライブラリ側の問題があっても本体機能は動き続けるようにするため)
    local LAM = LibAddonMenu2
    if not LAM then
        d("|cFF5555[PvPTargetInfo]|r LibAddonMenu-2.0が見つからないため、設定パネルは利用できません。/pti コマンドで設定してください。")
        return
    end

    local panelData = {
        type = "panel",
        name = "PvPTargetInfo",
        displayName = "PvPTargetInfo",
        author = "YourName",
        version = PTI.version,
        slashCommand = "/pti",
        registerForRefresh = true,
        registerForDefaults = false,
    }
    local lamPanel = LAM:RegisterAddonPanel("PTI_LAM_Panel", panelData)
    -- v2.5.0: 設定画面を開いた時に、Proc CDの登録一覧・履歴表示を最新にする
    if CALLBACK_MANAGER and CALLBACK_MANAGER.RegisterCallback then
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
            if panel == lamPanel and PTI.Settings.RefreshCdUI then PTI.Settings.RefreshCdUI() end
        end)
    end

    -- v2.0.7: 設定画面を「基本 → 検知 → 表示の残し方 → パネル①〜④ → 詳細設定」の順に整理。
    -- 設定キー・保存値は従来のまま(並びと説明文だけ変更)。
    local optionsTable = {
        { type = "header", name = "基本設定" },
        {
            type = "description",
            text = "①敵のバフ ②敵のデバフ ③自分のCondition ④自分のProc CD の4つのパネルを表示します。",
        },
        {
            type = "checkbox",
            name = "アドオンを有効にする",
            tooltip = "OFFにするとすべてのパネルが非表示になります。",
            getFunc = function() return PTI.sv.enabled end,
            setFunc = function(value)
                PTI.sv.enabled = value
                if PTI.Target and PTI.Target.ForceRefresh then PTI.Target.ForceRefresh() end
                if PTI.ProcCD and PTI.ProcCD.Sync then PTI.ProcCD.Sync() end
                PTI.UI.RefreshVisibility()
            end,
        },
        {
            type = "checkbox",
            name = "プレビュー表示(サンプルデータで位置・大きさを確認)",
            tooltip = "ONにすると、ターゲットが居なくてもパネルにサンプルデータが表示されます。位置・大きさの調整が終わったらOFFに戻してください。",
            getFunc = function() return PTI.sv.previewMode end,
            setFunc = function(value)
                PTI.sv.previewMode = value
                PTI.UI.RefreshVisibility()
            end,
        },
    }

    ----------------------------------------------------------------------
    -- 検知設定
    ----------------------------------------------------------------------
    table.insert(optionsTable, { type = "header", name = "検知設定" })
    table.insert(optionsTable, {
        type = "description",
        text = "敵プレイヤーのみ検知します(固定)。味方・NPCは表示しません。\n"
            .. "◆自動検知: 状態異常(CC)とMajor/Minor(強/弱)系の重要な効果だけ表示\n"
            .. "◆全表示: 食事・マウント等の背景バフ以外をほぼ全て表示(件数が増えます)",
    })
    table.insert(optionsTable, {
        type = "dropdown",
        name = "検知方式",
        choices = { "自動検知(既定)", "全表示" },
        choicesValues = { "auto", "all" },
        getFunc = function() return PTI.sv.detectionMode or "auto" end,
        setFunc = function(value)
            PTI.sv.detectionMode = value
            if PTI.Target and PTI.Target.ForceRefresh then PTI.Target.ForceRefresh() end
        end,
    })
    table.insert(optionsTable, {
        type = "checkbox",
        name = "自動検知を有効にする",
        tooltip = "自動検知モードのときだけ有効です。OFFにすると、①②パネルで登録した効果だけを表示します。",
        getFunc = function() return PTI.sv.autoDetect.enabled end,
        setFunc = function(value)
            PTI.sv.autoDetect.enabled = value
            if PTI.Target and PTI.Target.ForceRefresh then PTI.Target.ForceRefresh() end
        end,
        disabled = function() return PTI.sv.detectionMode == "all" end,
    })
    table.insert(optionsTable, {
        type = "slider",
        name = "全表示モード: これより長い(秒)効果は背景バフとして除外",
        tooltip = "全表示モードのときだけ使う、食事・マウント速度等の長時間バフを除外する秒数です。状態異常(CC)とMajor/Minor系は、この設定に関係なく必ず表示します。",
        min = 30, max = 600, step = 10,
        getFunc = function() return (PTI.sv.showAll and PTI.sv.showAll.hideLongerThan) or 120 end,
        setFunc = function(value)
            PTI.sv.showAll = PTI.sv.showAll or {}
            PTI.sv.showAll.hideLongerThan = value
            if PTI.Target and PTI.Target.ForceRefresh then PTI.Target.ForceRefresh() end
        end,
        width = "full",
    })

    ----------------------------------------------------------------------
    -- 表示の残し方
    ----------------------------------------------------------------------
    table.insert(optionsTable, { type = "header", name = "表示の残し方" })
    table.insert(optionsTable, {
        type = "slider",
        name = "ターゲット解除後にパネルを保持する秒数 (0.1秒単位)",
        tooltip = "敵からカーソルが外れた後も、指定した秒数だけ直前の情報を表示し続けます。PvPでパネルがチラつくのを防ぎます。",
        min = 0, max = 50, step = 1,
        getFunc = function() return zo_round((PTI.sv.holdDuration or 1.0) * 10) end,
        setFunc = function(value) PTI.sv.holdDuration = value / 10 end,
        width = "full",
    })
    table.insert(optionsTable, {
        type = "slider",
        name = "消えた効果を残す秒数 (0.1秒単位、0=残さない)",
        tooltip = "効果が終了・解除された直後、その行を灰色の「(終了)」「(消失)」で指定秒数だけ残します。残り時間は表示せず、有効な効果より下に並びます。",
        min = 0, max = 100, step = 5,
        getFunc = function() return zo_round((PTI.sv.lingerDuration or 2.0) * 10) end,
        setFunc = function(value)
            PTI.sv.lingerDuration = value / 10
            if PTI.Target and PTI.Target.ForceRefresh then PTI.Target.ForceRefresh() end
        end,
        width = "full",
    })

    ----------------------------------------------------------------------
    -- パネル設定(サブメニュー①〜④。各パネルの表示ON/OFF・位置・大きさ)
    ----------------------------------------------------------------------
    table.insert(optionsTable, { type = "header", name = "パネル設定" })
    table.insert(optionsTable, {
        type = "description",
        text = "各パネルの表示ON/OFF・位置・大きさを設定します。パネルをOFFにすると、その検知処理も止まります。",
    })

    ----------------------------------------------------------------------
    -- サブメニュー①: 敵の重要バフ
    ----------------------------------------------------------------------
    local buffControls = {}
    table.insert(buffControls, {
        type = "description",
        text = "敵にかかっている「重要なバフ」を表示するパネルです。",
    })
    BuildPanelControls(buffControls, "buff", "buffUI", { x = -180, y = -250 })
    -- v2.1.0: 敵BUFF表示に関する注意書き(文言はv2.0.8から不変。表示のみで検知ロジック・設定値には無関係)。
    -- 暗く読みにくかったため、明るい白(#F2F2F2)の色コードで囲み、設定項目より上
    -- (説明文の直後)へ移動した。直後に空行の説明を1つ挟み、設定項目との余白を確保する。
    table.insert(buffControls, 2, {
        type = "description",
        text = "|cF2F2F2" .. "【ご注意】敵プレイヤーのBUFF情報は、ゲーム側のAPI制限や取得仕様により、表示できる環境が制限される場合があります。\n\n現在の確認では、決闘(Duel)では表示されますが、バトルグラウンド(BG)およびシロディール(Cyrodiil)では表示されないことを確認しています。\n\nゲーム側の仕様変更により、今後動作が変わる可能性があります。" .. "|r",
        width = "full",
    })
    table.insert(buffControls, 3, { type = "description", text = " ", width = "full" })
    BuildWatchControls(buffControls, "buff", "PTI_BuffPendingDropdown")
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
    BuildPanelControls(debuffControls, "debuff", "debuffUI", { x = 180, y = -250 })
    BuildWatchControls(debuffControls, "debuff", "PTI_DebuffPendingDropdown")
    table.insert(optionsTable, {
        type = "submenu",
        name = "② 敵の重要デバフパネル",
        controls = debuffControls,
    })

    ----------------------------------------------------------------------
    -- サブメニュー③: 自分のCondition(旧称Proc)
    ----------------------------------------------------------------------
    local procControls = {}
    table.insert(procControls, {
        type = "description",
        text = "自分が使っているセット効果(発動型Proc)の発動状態・残り時間に加えて、自分に付与されたデバフ(敵のデバフ自動検知と同じ判定方法)も自動で表示するパネルです。",
    })
    BuildPanelControls(procControls, "proc", "procUI", { x = 0, y = -80 })

    table.insert(procControls, { type = "header", name = "登録(セット効果Proc)" })
    table.insert(procControls, {
        type = "description",
        text = "自分へのデバフは登録不要で自動的に表示されます。セット効果Proc等を追加で表示したい場合は、一番下の「登録するCondition」欄にAbilityIdの番号を入力するだけで登録完了です。AbilityIdが分からない場合は、下の学習モードをONにして戦闘でセット効果を1回発動させると、チャットや候補ドロップダウンにIDが表示されます。",
    })
    table.insert(procControls, {
        type = "checkbox",
        name = "自分のバフを学習(Condition特定用)",
        getFunc = function() return PTI.sv.procs.debugLearnMode end,
        setFunc = function(value)
            PTI.sv.procs.debugLearnMode = value
            if value and PTI.Procs and PTI.Procs.seenProcAbilityIds then
                ZO_ClearTable(PTI.Procs.seenProcAbilityIds)
            end
        end,
    })
    table.insert(procControls, {
        type = "dropdown",
        name = "検出された候補から選んで登録",
        choices = { "(候補なし。学習モードON後にセット効果を発動させてください)" },
        choicesValues = { "" },
        getFunc = function() return "" end,
        setFunc = function(value)
            if value == "" or value == nil then return end
            if PTI.Procs and PTI.Procs.RegisterPendingById then
                local ok, name = PTI.Procs.RegisterPendingById(value)
                if ok then
                    d(string.format("|c55CCFF[PvPTargetInfo]|r Condition \"%s\" を登録しました。", name))
                end
            end
        end,
        reference = "PTI_ProcPendingDropdown",
        width = "full",
    })
    table.insert(procControls, {
        type = "description",
        text = "AbilityIdの番号を入力するだけで登録完了です(カンマ区切りで複数登録可、例: 61906,12345)。名前は自動で取得されるため入力不要です。登録後は欄の表示が「番号:名前」に変わり、何を登録したか一目で分かるようになります。",
    })
    table.insert(procControls, {
        type = "editbox",
        name = "登録するCondition AbilityId (カンマ区切り)",
        -- v1.4.15で修正: 以前は番号だけを表示していたため、何を登録したのか
        -- 見返しても分からないという報告があった。保存形式(番号だけの
        -- カンマ区切り)自体は変更せず、表示するときだけGetAbilityNameで
        -- 名前を引いて「番号:名前」の形に整形する。
        getFunc = function()
            local text = PTI.sv.procConfig.idsText or ""
            local parts = {}
            for idStr in string.gmatch(text, "[^,]+") do
                local id = tonumber((idStr:match("^%s*(%d+)%s*$")))
                if id then
                    local name = GetAbilityName(id)
                    if not name or name == "" then name = "?" end
                    table.insert(parts, string.format("%d:%s", id, name))
                end
            end
            return table.concat(parts, ",")
        end,
        -- 保存時は「番号:名前」で入力されても番号部分だけを取り出して保存する。
        -- 名前部分は常にGetAbilityNameで再取得するため、入力された名前の
        -- 綴りは無視してよい(番号さえ合っていれば動作する)。
        setFunc = function(value)
            local ids = {}
            for token in string.gmatch(value or "", "[^,]+") do
                local idStr = token:match("(%d+)")
                if idStr then table.insert(ids, idStr) end
            end
            PTI.sv.procConfig.idsText = table.concat(ids, ",")
            if PTI.Procs and PTI.Procs.RebuildKnownProcs then PTI.Procs.RebuildKnownProcs() end
        end,
        isMultiline = true,
        width = "full",
    })
    table.insert(optionsTable, {
        type = "submenu",
        name = "③ 自分のConditionパネル",
        controls = procControls,
    })

    ----------------------------------------------------------------------
    -- サブメニュー④: 自分のProc CD(v2.5.0で整理)
    --   ① 表示設定 → ② 自動学習 → ③ 手動登録(折りたたみ) → ④ 詳細情報・履歴(折りたたみ)
    ----------------------------------------------------------------------
    local GRAY = "|cDDDDDD"
    local cdControls = {}
    local form = PTI.Settings.cdForm
    local function refreshCd() if PTI.Settings.RefreshCdUI then PTI.Settings.RefreshCdUI() end end
    local function CDCall(fn, ...)
        local CD = PTI.ProcCD
        if CD and CD[fn] then return CD[fn](...) end
        return false, "Proc CD機能が読み込まれていません。"
    end

    -- ① 表示設定
    table.insert(cdControls, { type = "header", name = "① Proc CD 表示設定" })
    table.insert(cdControls, {
        type = "description",
        text = GRAY .. "装備セットのProc発動後、再発動できるまでの時間を表示します。ICD秒数が確認できないProcは表示しません。|r",
    })
    BuildPanelControls(cdControls, "cd", "cdUI", { x = 0, y = -450 })
    table.insert(cdControls, {
        type = "dropdown",
        name = "表示モード",
        tooltip = "常時表示: 戦闘外でも表示します。戦闘終了後は非表示: 戦闘終了の数秒後にパネルを隠し、次の戦闘開始で再表示します。隠れている間もCDの計測は続きます。",
        choices = { "常時表示(既定)", "戦闘終了後は非表示" },
        choicesValues = { "always", "combat" },
        getFunc = function() return PTI.sv.cdUI.displayMode or "always" end,
        setFunc = function(value)
            PTI.sv.cdUI.displayMode = value
            if PTI.ProcCD and PTI.ProcCD.ApplyDisplayMode then PTI.ProcCD.ApplyDisplayMode() end
        end,
    })
    table.insert(cdControls, {
        type = "slider",
        name = "表示間隔",
        tooltip = "行と行の間の余白です。",
        min = 0, max = 20, step = 1,
        getFunc = function() return PTI.sv.cdUI.rowGap or 0 end,
        setFunc = function(value)
            PTI.sv.cdUI.rowGap = value
            PTI.UI.ApplyFontSize("cd")
        end,
        width = "full",
    })
    table.insert(cdControls, {
        type = "checkbox",
        name = "READY表示",
        tooltip = "ONにすると、CD終了後に「READY」を表示します。OFFにするとCD終了後は非表示になります。",
        getFunc = function() return PTI.sv.cd.showReady ~= false end,
        setFunc = function(value) PTI.sv.cd.showReady = value end,
    })

    -- ② 自動学習
    table.insert(cdControls, { type = "header", name = "② 自動学習" })
    table.insert(cdControls, {
        type = "checkbox",
        name = "|c55D68BAUTO|r学習を使う",
        tooltip = "通常の戦闘中にProcのAbility IDを観察し、根拠が十分に揃ったものだけ自動登録します。足りないものは候補として保存するだけで、検知には使いません。(PS5実機未検証)",
        getFunc = function() return PTI.sv.cd.autoLearn ~= false end,
        setFunc = function(value)
            PTI.sv.cd.autoLearn = value
            if PTI.ProcCD and PTI.ProcCD.SyncCombat then PTI.ProcCD.SyncCombat() end
            refreshCd()
        end,
    })
    table.insert(cdControls, {
        type = "editbox",
        name = "現在の学習状態",
        reference = "PTI_CD_Status",
        isMultiline = true,
        isExtraWide = true,
        readOnly = true,
        getFunc = function() return CDCall("FormatStatus") or "" end,
        setFunc = function() end,
        width = "full",
    })

    -- ③ 手動登録(折りたたみ)
    local manualControls = {}
    table.insert(manualControls, {
        type = "description",
        text = "|cFFC247【手動登録とは】|r\n" .. GRAY .. "手動登録は、セット効果の発動を検知するAbility IDと再発動までの待ち時間（ICD）を指定する機能です。Ability IDが正しくない場合やICDが実際の効果と異なる場合、Proc CDは正しく表示されません。|r",
    })
    table.insert(manualControls, {
        type = "description",
        text = "|cFFC247【Ability IDの確認方法】|r\n" .. GRAY .. "Ability IDはゲーム内の戦闘ログや診断機能などで確認した数値を入力してください。スキルのIDとセット効果のIDは異なる場合があります。|r",
    })
    table.insert(manualControls, { type = "header", name = "新規登録" })
    table.insert(manualControls, {
        type = "dropdown",
        name = "1. セット名を選択",
        tooltip = "装備中のセットが先頭に並びます。装備を変えた後は「選択肢を更新」を押してください。",
        reference = "PTI_CD_ManualSetDd",
        choices = { "(選択肢を更新してください)" },
        choicesValues = { "" },
        getFunc = function() return form.setKey or "" end,
        setFunc = function(value) form.setKey = value; form.msg = nil; refreshCd() end,
        width = "full",
    })
    table.insert(manualControls, {
        type = "button",
        name = "選択肢を更新(装備中のセット)",
        func = function() refreshCd() end,
        width = "full",
    })
    table.insert(manualControls, {
        type = "editbox",
        name = "2. Ability ID(数字)",
        getFunc = function() return form.id or "" end,
        setFunc = function(text) form.id = text; form.msg = nil; refreshCd() end,
        width = "half",
    })
    table.insert(manualControls, {
        type = "editbox",
        name = "3. ICD(秒)",
        getFunc = function() return form.cd or "" end,
        setFunc = function(text) form.cd = text; form.msg = nil; refreshCd() end,
        width = "half",
    })
    table.insert(manualControls, {
        type = "editbox",
        name = "Ability名(任意。空欄なら自動取得を試みます)",
        getFunc = function() return form.name or "" end,
        setFunc = function(text) form.name = text; form.msg = nil; refreshCd() end,
        width = "full",
    })
    table.insert(manualControls, {
        type = "editbox",
        name = "入力内容の確認",
        reference = "PTI_CD_ManualPreview",
        isMultiline = true,
        isExtraWide = true,
        readOnly = true,
        getFunc = function()
            if form.msg then return form.msg end
            return CDCall("ManualPreview", form.setKey, form.id, form.cd, form.name) or ""
        end,
        setFunc = function() end,
        width = "full",
    })
    table.insert(manualControls, {
        type = "button",
        name = "|c55D68B4. 登録する|r",
        tooltip = "上の「入力内容の確認」が「登録できます」になっている時に登録できます。",
        func = function()
            local ok, msg = CDCall("ManualRegister", form.setKey, form.id, form.cd, form.name)
            if ok then form.id, form.cd, form.name = "", "", "" end
            form.msg = (ok and "○ " or "× ") .. tostring(msg)
            refreshCd()
        end,
        width = "full",
    })
    table.insert(manualControls, { type = "header", name = "登録済みの一覧・編集・削除" })
    table.insert(manualControls, {
        type = "dropdown",
        name = "登録を選択 ([AUTO]=自動 / [MANUAL]=手動)",
        reference = "PTI_CD_RegDd",
        choices = { "(登録なし)" },
        choicesValues = { "" },
        getFunc = function() return form.reg or "" end,
        setFunc = function(value) form.reg = value; refreshCd() end,
        width = "full",
    })
    table.insert(manualControls, {
        type = "editbox",
        name = "選択中の登録の内容",
        reference = "PTI_CD_RegDetail",
        isMultiline = true,
        isExtraWide = true,
        readOnly = true,
        getFunc = function() return CDCall("FormatRegDetail", form.reg) or "" end,
        setFunc = function() end,
        width = "full",
    })
    table.insert(manualControls, {
        type = "editbox",
        name = "ICDを変更(MANUALのみ・秒)",
        getFunc = function() return form.editCd or "" end,
        setFunc = function(text) form.editCd = text end,
        width = "half",
    })
    table.insert(manualControls, {
        type = "button",
        name = "ICDを更新",
        func = function()
            local ok, msg = CDCall("ManualUpdateCd", form.reg, form.editCd)
            d("[PvPTargetInfo] " .. tostring(msg))
            if ok then form.editCd = "" end
            refreshCd()
        end,
        width = "half",
    })
    table.insert(manualControls, {
        type = "button",
        name = "無効化(記録は残す)",
        tooltip = "この登録を検知に使わなくします。記録は削除されません。",
        func = function()
            local _, msg = CDCall("RegSetDisabled", form.reg, true)
            d("[PvPTargetInfo] " .. tostring(msg)); refreshCd()
        end,
        width = "half",
    })
    table.insert(manualControls, {
        type = "button",
        name = "再有効化",
        tooltip = "無効になっている登録を、検知に使うよう戻します(観測回数をリセット)。",
        func = function()
            local _, msg = CDCall("RegSetDisabled", form.reg, false)
            d("[PvPTargetInfo] " .. tostring(msg)); refreshCd()
        end,
        width = "half",
    })
    table.insert(manualControls, {
        type = "button",
        name = "|cFF6B6BMANUAL登録を削除|r",
        tooltip = "選択中のMANUAL登録を削除します。AUTO登録は削除できません(無効化で止められます)。",
        isDangerous = true,
        warning = "選択中のMANUAL登録を削除します。元に戻せません。",
        func = function()
            local ok, msg = CDCall("ManualDelete", form.reg)
            if ok then form.reg = "" end
            d("[PvPTargetInfo] " .. tostring(msg)); refreshCd()
        end,
        width = "full",
    })
    table.insert(cdControls, {
        type = "submenu",
        name = "③ 手動登録(Ability IDとICDを指定)",
        controls = manualControls,
    })

    -- ④ 詳細情報(折りたたみ)
    local detailCd = {}
    local function roText(name, ref, fn)
        table.insert(detailCd, {
            type = "editbox",
            name = name,
            reference = ref,
            isMultiline = true,
            isExtraWide = true,
            readOnly = true,
            getFunc = function() return CDCall(fn) or "" end,
            setFunc = function() end,
            width = "full",
        })
    end
    roText("AUTO登録履歴(登録時の内容・新しい順)", "PTI_CD_History", "FormatHistory")
    roText("誤検知・要確認の履歴", "PTI_CD_Health", "FormatHealth")
    roText("Ability ID一覧", "PTI_CD_IdList", "FormatIdList")
    table.insert(detailCd, {
        type = "description",
        text = GRAY .. "|c55D68B正常|r=問題なし / |cFFC247要確認|r=ICDと合わない発動などを複数回検出 / |cFF6B6B無効候補|r=誤検知の可能性が高く、AUTO登録は検知を停止(記録は残ります)。1回の例外では変わりません。|r",
    })
    table.insert(detailCd, {
        type = "button",
        name = "候補の一覧をチャットに表示",
        tooltip = "未確認の候補を表示します。確定は /pti cd auto accept <番号> です。",
        func = function() if PTI.ProcCD then PTI.ProcCD.HandleCommand("auto list") end end,
        width = "full",
    })
    table.insert(cdControls, {
        type = "submenu",
        name = "④ 学習履歴・詳細情報",
        controls = detailCd,
    })

    table.insert(optionsTable, {
        type = "submenu",
        name = "④ 自分のProc CDパネル",
        controls = cdControls,
    })

    ----------------------------------------------------------------------
    -- 詳細設定(学習モード・デバッグ)。通常は触らなくてよい項目を
    -- 1つのサブメニューにまとめた(v2.0.7)。
    ----------------------------------------------------------------------
    local detailControls = {}
    ----------------------------------------------------------------------
    -- 学習モード(敵バフ/デバフ側)は、UI①・UI②どちらの候補にも影響するため
    -- トップレベルに置いておく(サブメニューが違っても同じ1つのスイッチ)。
    ----------------------------------------------------------------------
    table.insert(detailControls, { type = "header", name = "AbilityId学習モード(上級者向け)" })
    table.insert(detailControls, {
        type = "description",
        text = "表示させたい敵のバフ/デバフのAbilityIdを特定するモードです。ONにするとチャットに生データが出ます。自動検知が既定でONなので、通常は不要です。",
    })
    table.insert(detailControls, {
        type = "checkbox",
        name = "敵のバフ/デバフを学習(任意登録の候補作成用)",
        getFunc = function() return PTI.sv.procs.debugLearnModeTarget end,
        setFunc = function(value)
            PTI.sv.procs.debugLearnModeTarget = value
            if value and PTI.Target and PTI.Target.seenTargetAbilityIds then
                ZO_ClearTable(PTI.Target.seenTargetAbilityIds)
            end
        end,
    })

    ----------------------------------------------------------------------
    -- v1.4.6で追加: 検知パイプラインのデバッグログ
    -- 学習モード(上記)は「登録候補を探す」ためのものだが、こちらは
    -- 「自動検知が実際にUIまで正しく届いているか」を1件ずつ確認するための
    -- 純粋なデバッグ表示。既定OFFで、通常プレイでは一切ログを出さない。
    ----------------------------------------------------------------------
    table.insert(detailControls, { type = "header", name = "検知パイプラインのデバッグログ(開発者向け)" })
    table.insert(detailControls, {
        type = "description",
        text = "ONにすると、検知の各段階(対象取得→重要判定→表示データ登録→UI描画)をチャットに出力します。表示されない原因の切り分け専用です。実戦中は必ずOFFにしてください。",
    })
    table.insert(detailControls, {
        type = "checkbox",
        name = "検知パイプラインのデバッグログを有効にする",
        getFunc = function() return PTI.sv.debug.pipelineTrace end,
        setFunc = function(value) PTI.sv.debug.pipelineTrace = value end,
    })

    table.insert(optionsTable, {
        type = "submenu",
        name = "詳細設定(学習・デバッグ)",
        controls = detailControls,
    })

    LAM:RegisterOptionControls("PTI_LAM_Panel", optionsTable)
end
