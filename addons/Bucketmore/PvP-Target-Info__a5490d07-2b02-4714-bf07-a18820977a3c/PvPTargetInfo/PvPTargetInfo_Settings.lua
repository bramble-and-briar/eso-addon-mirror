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
    LAM:RegisterAddonPanel("PTI_LAM_Panel", panelData)

    local optionsTable = {
        { type = "header", name = "PvPTargetInfo" },
        {
            type = "description",
            text = "①敵の重要バフ ②敵の重要デバフ ③自分のCondition(セットProc+自分へのデバフ自動検知)、の3つの独立したパネルを画面に表示します。下のサブメニューを開いて、それぞれのパネルの位置・大きさ・登録内容を設定してください。",
        },
        {
            type = "checkbox",
            name = "アドオンを有効にする",
            tooltip = "OFFにすると3つのパネルすべてが非表示になります。",
            getFunc = function() return PTI.sv.enabled end,
            setFunc = function(value)
                PTI.sv.enabled = value
                PTI.UI.RefreshVisibility()
            end,
        },
        {
            type = "checkbox",
            name = "プレビュー表示(サンプルデータで位置・大きさを確認)",
            tooltip = "ONにすると、実際のターゲットが居なくても3つのパネルにサンプルデータが表示されます。位置・大きさ・文字サイズ・強調色を確認しながら調整したいときにONにし、終わったらOFFに戻してください。",
            getFunc = function() return PTI.sv.previewMode end,
            setFunc = function(value)
                PTI.sv.previewMode = value
                PTI.UI.RefreshVisibility()
            end,
        },
        {
            type = "slider",
            name = "ターゲット解除後にパネルを保持する秒数 (0.1秒単位)",
            tooltip = "敵からカーソルが外れた後も、指定した秒数だけ直前の情報を表示し続けます。動きの激しいPvPでパネルがチラつくのを防ぐための設定です。",
            min = 0, max = 50, step = 1,
            getFunc = function() return zo_round((PTI.sv.holdDuration or 1.0) * 10) end,
            setFunc = function(value) PTI.sv.holdDuration = value / 10 end,
            width = "full",
        },
    }

    ----------------------------------------------------------------------
    -- 検知方式(自動検知 / 全表示)
    ----------------------------------------------------------------------
    table.insert(optionsTable, { type = "header", name = "バフ/デバフの検知方式" })
    table.insert(optionsTable, {
        type = "description",
        text = "◆自動検知(既定)\n"
            .. "状態異常(CC)とMajor/Minor系の効果だけを判定して表示します。\n"
            .. "  メリット: PvPで今すぐ反応すべき情報だけに絞られ、瞬時に判断しやすい。食事バフ等で画面が埋まらない。\n"
            .. "  デメリット: CC・Major/Minorのどちらにも当てはまらない特殊な効果(セット効果由来のユニークバフ等)は、手動登録しない限り表示されない。\n\n"
            .. "◆全表示\n"
            .. "判定条件に関わらず、ターゲットの効果をほぼ全て表示します(食事バフ・マウント速度・ギルドバフのような、常時付いていて今更確認する必要のない背景バフだけは自動的に除外します)。\n"
            .. "  メリット: 見落としが原理的に起こらない。CC・Major/Minorに当てはまらない特殊な効果も含め、相手の状態を漏れなく把握できる。\n"
            .. "  デメリット: 表示件数が増え、パネルが縦に伸びやすい。重要な情報とそうでない情報が混在するため、見分けは自分の目で行う必要がある(ただし表示順は自動検知時と同じ優先順位ルールに従うため、重要なものは常に上位に来る)。",
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
        type = "slider",
        name = "全表示モード: これより長い(秒)バフ/デバフは背景バフとして除外",
        tooltip = "食事バフ・マウント速度バフのような長時間・無期限バフを、全表示モードの時だけ自動的に除外するための閾値です。状態異常(CC)やMajor/Minor系の効果は、この設定に関わらず必ず表示されます(見逃し防止のため除外対象になりません)。",
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
    -- 自動検知(共通設定)
    ----------------------------------------------------------------------
    table.insert(optionsTable, { type = "header", name = "重要バフ/デバフの自動検知" })
    table.insert(optionsTable, {
        type = "description",
        text = "上の「検知方式」が自動検知の場合のみ有効な設定です。ON(既定)の場合、スタン・サイレンス・根絶やし・移動速度低下・よろめき等の「状態異常」と、「Major/Minor」(日本語版では「(強)」「(弱)」)を含む効果を、登録なしで自動的に重要バフ/デバフとして表示します。OFFにすると、下のUI①・UI②で個別に登録した効果だけを表示します。",
    })
    table.insert(optionsTable, {
        type = "checkbox",
        name = "自動検知を有効にする",
        getFunc = function() return PTI.sv.autoDetect.enabled end,
        setFunc = function(value)
            PTI.sv.autoDetect.enabled = value
            if PTI.Target and PTI.Target.ForceRefresh then PTI.Target.ForceRefresh() end
        end,
        disabled = function() return PTI.sv.detectionMode == "all" end,
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
    -- 学習モード(敵バフ/デバフ側)は、UI①・UI②どちらの候補にも影響するため
    -- トップレベルに置いておく(サブメニューが違っても同じ1つのスイッチ)。
    ----------------------------------------------------------------------
    table.insert(optionsTable, { type = "header", name = "AbilityId学習モード(上級者向け)" })
    table.insert(optionsTable, {
        type = "description",
        text = "表示させたい敵のバフ/デバフのAbilityIdを特定するためのモードです。ONにするとチャットに生データが表示されます。自動検知が既定でONのため、通常は使う必要はありません。",
    })
    table.insert(optionsTable, {
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
    table.insert(optionsTable, { type = "header", name = "検知パイプラインのデバッグログ(開発者向け)" })
    table.insert(optionsTable, {
        type = "description",
        text = "ONにすると、敵の効果を検知するたびに「対象取得→重要判定→表示データ登録→UI描画」の各段階をチャットに1行ずつ出力します。自動検知が効いているのにUIに表示されない場合の原因切り分け専用です。既定はOFFで、実戦中は必ずOFFに戻してください。",
    })
    table.insert(optionsTable, {
        type = "checkbox",
        name = "検知パイプラインのデバッグログを有効にする",
        getFunc = function() return PTI.sv.debug.pipelineTrace end,
        setFunc = function(value) PTI.sv.debug.pipelineTrace = value end,
    })

    LAM:RegisterOptionControls("PTI_LAM_Panel", optionsTable)
end
