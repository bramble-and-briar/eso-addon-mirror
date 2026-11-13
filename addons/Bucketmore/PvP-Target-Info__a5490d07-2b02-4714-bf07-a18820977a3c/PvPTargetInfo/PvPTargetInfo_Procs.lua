--[[
    PvPTargetInfo_Procs.lua

    「Condition」パネル(UI③、旧称「Proc」パネル)の担当。以下2種類の情報を
    同じパネルにまとめて表示する。
      (a) 自分のセット効果Proc等、AbilityIdを手動登録して表示する方式
          (従来通り。番号は設定パネルの「登録するProc」欄にカンマ区切りで
          入力するだけで、名前はGetAbilityNameで自動取得する)
      (b) 自分に付与されたデバフの自動検知(v1.4.23で追加)。判定方法は
          PvPTargetInfo_Target.luaが敵のDEBUFF自動検知で使っているものと
          完全に同じ(CC系のstatusEffectType、またはMajor/Minor・(強)/(弱)
          のキーワード一致)を、そのままPTI.Target.IsAutoImportantDebuff
          経由で再利用している。

    v1.4.23で全面的に見直した経緯:
      v1.4.16〜v1.4.22にかけて「登録したのに表示されない」「スタック数が
      出ない」「秒数が残り続ける」「重複して表示される」等の不具合報告が
      連続したため、根本原因を洗い直した。
      結果、GetUnitBuffInfoの戻り値をタプルで受け取る際の引数の個数が
      1つ足りておらず(PvPTargetInfo_Target.luaの初期スキャンで使っている
      正しい並び順と比較して判明)、"abilityId"として受け取っていた変数が
      実際にはstatusEffectType(状態異常の種類を表す小さな整数)を指して
      いたことが分かった。これではAbilityId一致判定がほぼ常に失敗するのは
      当然で、v1.4.17で場当たり的に追加した「表示名一致」だけが実質的に
      機能していた状態だった。
      本バージョンで引数の並びをPvPTargetInfo_Target.luaと同じ正しい順序
      (buffName, startTime, endTime, buffSlot, stackCount, iconFile,
      buffType, effectType, abilityType, statusEffectType, abilityId,
      canClickOff)に修正した。これによりAbilityId一致判定が本来の通り
      正しく機能するはずなので、v1.4.19〜v1.4.22で場当たり的に追加した
      endTime除外処理・複数バフ枠マージ処理は撤去し、v1.4.16相当の
      シンプルな構成に戻した(表示名でのキーとID一致判定自体は
      安全側の保険として残す)。
--]]

PvPTargetInfo = PvPTargetInfo or {}
local PTI = PvPTargetInfo
PTI.Procs = PTI.Procs or {}

local activeProcs = {} -- キー(表示名) -> { endTime, stackCount, name, auto }
local knownProcs = {}      -- abilityId -> 表示名 (sv.procConfig.idsTextから構築。手動登録分)
local knownProcNames = {}  -- 表示名 -> true (IDが一致しない場合の名前照合用の保険)

-- v1.4.3で修正(修正改定5): sv.procConfig.idsText はAbilityIdの番号だけを
-- カンマ区切りで並べた形式("12345,67890")に変更した。表示名は保存せず、
-- 毎回 GetAbilityName(abilityId) でゲームから直接取得する(ユーザーが
-- 名前を入力する必要をなくすため)。
local function RebuildKnownProcs()
    ZO_ClearTable(knownProcs)
    ZO_ClearTable(knownProcNames)
    local text = PTI.sv.procConfig.idsText or ""
    for idStr in string.gmatch(text, "[^,]+") do
        local id = tonumber((idStr:match("^%s*(%d+)%s*$")))
        if id then
            local name = GetAbilityName(id)
            if not name or name == "" then name = "ability " .. tostring(id) end
            knownProcs[id] = name
            knownProcNames[name] = true
        end
    end
end
PTI.Procs.RebuildKnownProcs = RebuildKnownProcs
PTI.Procs.GetKnownProcs = function() return knownProcs end

function PTI.Procs.RefreshFonts()
    PTI.UI.RefreshRowLayout("proc")
end

-- 設定画面の「プレビュー表示」ON時: 実際に発動中のConditionが無くても
-- UI③の見た目を確認できるようにするサンプルデータ
local function BuildPreviewEntry()
    local now = GetGameTimeSeconds()
    return { name = "サンプルCondition", stackCount = 1, endTime = now + (6 - (now % 6)) }
end

-- v1.4.23で修正(重要・根本原因): GetUnitBuffInfoの戻り値の並び順を
-- PvPTargetInfo_Target.luaの初期スキャンと同じ正しい順序に修正した
-- (経緯はファイル冒頭のコメント参照)。これにより(a)手動登録した
-- AbilityIdでの一致判定が正しく機能するようになった。
-- あわせて(b)敵デバフの自動検知と同じ判定方法(PTI.Target.
-- IsAutoImportantDebuff)を使い、自分に付与されたデバフも同じループの
-- 中でまとめて検知する(GetNumBuffsの呼び出しを1回にまとめ、軽量に保つ)。
-- ループ自体はGetNumBuffsで件数を先に取得してから境界内だけを回す安全な
-- 書き方(Target.lua/これまでの実装と同じ)で、無限ループの心配はない。
local function ScanActiveProcs()
    ZO_ClearTable(activeProcs)
    local numBuffs = GetNumBuffs("player")
    for i = 1, numBuffs do
        local buffName, _, endTime, _, stackCount, _, _, effectType, _, statusEffectType, abilityId =
            GetUnitBuffInfo("player", i)

        local matchedName = nil

        -- (a) 手動登録(AbilityId直接入力)分。念のため表示名一致も保険として残す。
        if type(abilityId) == "number" and knownProcs[abilityId] then
            matchedName = knownProcs[abilityId]
        elseif type(buffName) == "string" and buffName ~= "" and knownProcNames[buffName] then
            matchedName = buffName
        end

        -- (b) 自動検知: 敵のDEBUFF自動検知と同じ判定方法で、自分のデバフを検知する。
        --     手動登録分と重複しないよう、(a)で未一致の場合のみ判定する。
        if not matchedName and effectType == BUFF_EFFECT_TYPE_DEBUFF
            and type(buffName) == "string" and buffName ~= ""
            and PTI.Target and PTI.Target.IsAutoImportantDebuff
            and PTI.Target.IsAutoImportantDebuff(buffName, statusEffectType) then
            matchedName = buffName
        end

        if matchedName then
            activeProcs[matchedName] = {
                endTime = endTime,
                stackCount = stackCount,
                name = matchedName,
            }
        end
    end
end

-- 診断用。今プレイヤーに付いているバフを、登録の有無に関係なく全件
-- チャットに出す(/pti proc dump)。実際のAbilityId・表示名をその場で
-- 確認するための機能。区切りは"|"を含まない" / "を使っている
-- (ESOのチャットは生の"|"を制御コードの開始として解釈し表示が崩れるため)。
local function DumpActiveBuffs()
    local numBuffs = GetNumBuffs("player")
    d(string.format("|c55CCFF[PvPTargetInfo]|r 現在のバフ %d件:", numBuffs))
    for i = 1, numBuffs do
        local buffName, _, _, _, stackCount, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        d(string.format("|c55CCFF[PvPTargetInfo]|r  - %s / abilityId=%s / stackCount=%s",
            tostring(buffName), tostring(abilityId), tostring(stackCount)))
    end
end
PTI.Procs.DumpActiveBuffs = DumpActiveBuffs

local function RefreshProcUI()
    local now = GetGameTimeSeconds()
    local sv = PTI.sv.procUI
    local maxRows = sv.maxRows or 3
    local index = 0

    if PTI.IsPreview() then
        local preview = BuildPreviewEntry()
        index = 1
        local row = PTI.UI.AcquireRow("proc", 1)
        row.nameLabel:SetFont(PTI.UI.RowFont("proc"))
        row.nameLabel:SetColor(1, 0.85, 0.2, 1)
        row.nameLabel:SetText("● " .. preview.name .. " (プレビュー)")
        row.timeLabel:SetFont(PTI.UI.RowFont("proc"))
        row.timeLabel:SetColor(0.85, 0.92, 1.0, 1)
        row.timeLabel:SetText(string.format("%d秒", zo_ceil(preview.endTime - now)))
    else
        ScanActiveProcs()

        for _, data in pairs(activeProcs) do
            if index < maxRows then
                index = index + 1
                local row = PTI.UI.AcquireRow("proc", index)

                local displayName = "● " .. (data.name or "Condition")
                if data.stackCount and data.stackCount > 1 then
                    displayName = string.format("%s %d", displayName, data.stackCount)
                end
                row.nameLabel:SetFont(PTI.UI.RowFont("proc"))
                row.nameLabel:SetColor(1, 0.85, 0.2, 1)
                row.nameLabel:SetText(displayName)

                row.timeLabel:SetFont(PTI.UI.RowFont("proc"))
                row.timeLabel:SetColor(0.85, 0.92, 1.0, 1)
                if data.endTime and data.endTime > now then
                    row.timeLabel:SetText(string.format("%d秒", zo_ceil(data.endTime - now)))
                else
                    row.timeLabel:SetText("")
                end
            end
        end

        -- STEP6で変更: 以前はここで「登録なし」の案内文をindex=1として
        -- 表示していたが、「Conditionが発動していない時はUI③を勝手に
        -- 表示しない」仕様になったため、案内文の表示自体を廃止した。
        -- indexが0のままなら下のhasContent判定でウィンドウごと隠れる。
    end

    PTI.UI.ReleaseUnusedRows("proc", index + 1)

    -- STEP6で変更: UI③(Condition)はUI①②(戦闘連動)とは完全に独立して、
    -- 「実際に表示する行があるか(=Conditionが発動している、またはプレビュー中)」
    -- だけを表示条件にする。ここではフラグを立てるだけで、実際の表示/非表示の
    -- 判定(previewMode例外や全体enabled等との組み合わせ)はUI.lua側の
    -- SetWindowVisibleに集約している。
    PTI.UI.procHasContent = (index > 0)
    PTI.UI.SetWindowVisible("proc")
end
PTI.Procs.RefreshProcUI = RefreshProcUI

function PTI.Procs.ForceRefresh()
    RefreshProcUI()
end

function PTI.Procs.HasActiveProcs()
    return next(activeProcs) ~= nil
end

-- EVENT_EFFECT_CHANGEDは自キャラが得たバフ(多くのセットProcを含む)に対して発火する
-- チャットが埋め尽くされないよう、同じAbilityIdは学習モード中1回だけ表示する。
local seenProcAbilityIds = {}
PTI.Procs.seenProcAbilityIds = seenProcAbilityIds -- 学習モードON時にリセットできるよう公開

-- 学習モードで見つかった「登録候補」のリスト。名前もここに保存しておくことで、
-- ユーザーはAbilityIdだけで登録でき、名前を手入力しなくて済むようにする。
local pendingProcCandidates = {} -- 配列: { {id=, name=}, ... }
local pendingProcIndexById = {}  -- abilityId -> pendingProcCandidates内のindex

local function RefreshPendingProcUI()
    if PTI.Settings and PTI.Settings.RefreshProcPendingDropdown then
        PTI.Settings.RefreshProcPendingDropdown()
    end
end

-- LAM2のドロップダウン用: 表示ラベルの配列とAbilityIdの配列を返す
function PTI.Procs.GetPendingChoices()
    local labels, values = {}, {}
    for _, entry in ipairs(pendingProcCandidates) do
        table.insert(labels, string.format("%s (%d)", entry.name, entry.id))
        table.insert(values, entry.id)
    end
    return labels, values
end

-- AbilityIdの番号だけを登録リスト(procConfig.idsText)に追加する共通処理。
-- 既に登録済みのIDはそのまま無視する。表示名は保存せず、GetAbilityNameで
-- 都度取得するため、ここでは番号を追加するだけでよい。
function PTI.Procs.AddById(abilityId)
    abilityId = tonumber(abilityId)
    if not abilityId then return false end
    if knownProcs[abilityId] then
        -- 既に登録済み。名前だけ最新化して終了。
        return true, GetAbilityName(abilityId)
    end

    local text = PTI.sv.procConfig.idsText or ""
    PTI.sv.procConfig.idsText = (text == "" and tostring(abilityId) or (text .. "," .. tostring(abilityId)))
    RebuildKnownProcs()
    return true, knownProcs[abilityId]
end

-- 候補リストからAbilityIdを指定してProc登録する(名前の入力は不要)
function PTI.Procs.RegisterPendingById(abilityId)
    abilityId = tonumber(abilityId)
    local index = abilityId and pendingProcIndexById[abilityId]
    if not index then return false end
    local entry = pendingProcCandidates[index]

    local ok, name = PTI.Procs.AddById(entry.id)

    table.remove(pendingProcCandidates, index)
    pendingProcIndexById[abilityId] = nil
    for i = index, #pendingProcCandidates do
        pendingProcIndexById[pendingProcCandidates[i].id] = i
    end
    RefreshPendingProcUI()
    return ok, name
end

function PTI.Procs.ClearPendingCandidates()
    ZO_ClearTable(pendingProcCandidates)
    ZO_ClearTable(pendingProcIndexById)
    RefreshPendingProcUI()
end

-- v1.4.16で修正: 以前はこのイベントハンドラ自身がactiveProcsを直接
-- 書き換えて表示を更新していたが、それが「登録したのにProc欄に出ない」
-- 不具合の原因になっていた(上のScanActiveProcsのコメント参照)。
-- v1.4.16以降、実際の表示更新は200ms Tickごとの全件スキャン
-- (ScanActiveProcs)に一本化したため、このハンドラは学習モード用の
-- ログ出力と候補リスト登録だけを行う(表示への書き込みは一切しない)。
local function OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag,
    beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType,
    statusEffectType, unitName, unitId, abilityId, sourceType)

    if unitTag ~= "player" then return end
    if not PTI.sv.procs.debugLearnMode then return end
    if changeType ~= EFFECT_RESULT_GAINED or seenProcAbilityIds[abilityId] then return end
    seenProcAbilityIds[abilityId] = true

    -- EVENT_EFFECT_CHANGEDのstackCount引数は、効果によってはゲーム側から
    -- 正しく渡されない(常に0/nilになる)既知の癖があるため、ログ表示用に
    -- effectSlotから実際のバフ枠を照会して補正する(取得できなければ
    -- イベント引数のままでよい。ログ用途のみで表示更新には使わない)。
    local loggedStackCount = stackCount
    if effectSlot then
        local _, _, _, _, apiStackCount = GetUnitBuffInfo(unitTag, effectSlot)
        if apiStackCount and apiStackCount > 0 then
            loggedStackCount = apiStackCount
        end
    end

    d(string.format("|c55CCFF[PTI Learn]|r %s / abilityId=%s / duration=%.1fs / stackCount=%s",
        effectName or "?", tostring(abilityId), (endTime or 0) - (beginTime or 0), tostring(loggedStackCount)))
    d(string.format("|c55CCFF[PTI Learn]|r パネルに表示したい場合: /pti proc use %s (または設定パネルの候補から選択)",
        tostring(abilityId)))

    if type(abilityId) == "number" and not knownProcs[abilityId] and not pendingProcIndexById[abilityId] then
        table.insert(pendingProcCandidates, { id = abilityId, name = effectName or ("ability " .. tostring(abilityId)) })
        pendingProcIndexById[abilityId] = #pendingProcCandidates
        RefreshPendingProcUI()
    end
end

function PTI.Procs.Initialize()
    RebuildKnownProcs()
    -- v1.4.16で修正: 発動中Procの検出は200ms Tickごとの全件スキャン
    -- (ScanActiveProcs)に一本化したため、ロード時点の初期スキャンを
    -- 個別に持つ必要がなくなった(最初のTickで自動的に反映される)。

    local eventName = PTI.name .. "Procs"
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForUpdate(PTI.name .. "ProcsTick", 200, RefreshProcUI)
end
