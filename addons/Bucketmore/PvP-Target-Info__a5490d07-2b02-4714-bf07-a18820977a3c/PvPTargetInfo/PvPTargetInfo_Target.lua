--[[
    PvPTargetInfo_Target.lua

    担当は「敵の重要バフ(UI①)」「敵の重要デバフ(UI②)」の検出・表示。
    HP表示、処刑ライン警告、自分のバフ/デバフ表示、HPによる各種判定は廃止
    (自身のProc表示だけはPvPTargetInfo_Procs.luaが担当)。

    修正改定3: 「重要」の判定方式を変更。
      これまでは手動で登録(sv.watchedBuffs / sv.watchedDebuffs)した
      AbilityIdだけを表示する方式だったが、毎回の登録作業が煩わしいという
      要望を受け、以下の2階建てに変更した。

      ① 自動検知(既定でON, sv.autoDetect.enabled)
         ・デバフ側: ゲームエンジンが分類する状態異常の種類(statusEffectType)が
           スタン/サイレンス/根絶やし/移動速度低下/恐怖/幻惑/よろめき(Off Balance)
           などの「行動阻害系(CC)」に該当するものを自動的に重要デバフとして表示する。
           これはAbilityId(スキルごとに異なる番号)ではなく効果の種類そのもので
           判定しているため、新しいスキルやパッチでID体系が変わっても影響を受けにくい。
         ・バフ/デバフ共通: 効果名に "Major"/"Minor"(英語版)または
           日本語版の語尾表記 "(強)"/"(弱)" が含まれるものを自動的に
           重要として表示する(名前のどこにあってもよい部分一致判定。
           自動検知が有効な間はこの4語すべてを常に対象にする。個別に
           英語/日本語をON/OFFする案もv1.4.11で一度試したが、意味が
           ないとのことでv1.4.12で単純な1つのON/OFFに戻した)。
      ② 手動登録(任意, sv.watchedBuffs / sv.watchedDebuffs)
         自動検知では拾えない特定の効果(セット効果由来の特殊なバフ等)を
         追加で表示したい場合のための、あくまで補助的な機能として残している。

      内部的にはstatusEffectTypeの定数名をゲーム側の実際の定義から動的に
      引いているため(_G[定数名])、該当する定数が存在しない/名前が違う場合は
      単にその判定条件が働かないだけで、エラーにはならない安全な作りにしている。
      実機で意図通りに拾えているかは /pti learn target で確認できる。

    v1.4.1で修正:
      - パネルは「重要バフ/デバフが実際にある時だけ表示」だったのを、
        「有効になっている限り常時表示」に変更(中身が空なら案内を表示)。
      - 設定画面を開いたことを自動検知してプレビュー表示に切り替える仕組みは
        廃止し、sv.previewMode (設定画面のチェックボックス)で手動切替する
        方式にした。

    v1.4.3で追加(修正改定4): 表示順を「登場順/検出順」ではなく、
    戦闘上の重要度カテゴリ順に変更した。
      バフ: ①防御・ダメージ軽減 → ②回復・生存 → ③攻撃力・与ダメージ強化
            → ④クリティカル関連 → ⑤機動力・CC耐性 → ⑥その他の戦闘系
      デバフ: ①防御低下・被ダメージ増加 → ②回復阻害 → ③攻撃力・与ダメージ低下
              → ④CC・行動阻害 → ⑤強力なDoT → ⑥その他の戦闘系
      ただし残り時間がURGENT_REMAINING_THRESHOLD秒以下のものは、カテゴリに
      関わらず最優先で上位表示する(消える寸前の効果を見逃さないため)。
      分類は効果名のキーワード一致で行うため、ゲーム内表示言語が英語以外の
      場合はBUFF_CATEGORY_ORDER/DEBUFF_CATEGORY_ORDERのキーワードを
      書き換える必要がある(自動検知キーワードと同様の考え方)。

    v1.4.4で追加(修正改定6): 検出方式を全面的に見直した。
      ① プレイヤー判定を最優先にした。
         IsUnitPlayer("reticleover") でプレイヤーかどうかを最初に判定し、
         NPC・モンスター・衛兵や、壁・扉・通用口などのオブジェクトは
         一切反応しない(そもそも効果の収集自体を行わない)。
         ターゲットが変わるたびに EVENT_RETICLE_TARGET_CHANGED で再判定し、
         プレイヤー以外になった瞬間にUIへの反映を止める(表示自体は
         sv.holdDurationの間だけ直前のプレイヤー情報を保持する、③の
         「表示安定性」と同じ考え方)。
      ② (v2.0.3で置き換え。下記参照)

    v2.0.3で変更(検出方式の置き換え。判定ロジック自体は無変更):
      v1.4.5〜v1.4.25までは、ターゲット変更時に1回だけGetUnitBuffInfoで
      読み、以後はEVENT_EFFECT_CHANGED(reticleoverにフィルタ)の差分更新に
      任せる方式だった。しかし敵プレイヤーに対してこのイベントが安定して
      飛んでこないケースがあり、「敵のBUFFだけが一切表示されない」という
      不具合の原因になっていた(詳しい切り分け経緯は本体areaメモ参照)。

      そこで、EVENT_EFFECT_CHANGEDへの依存を完全に廃止し、
      GetNumBuffs("reticleover")→GetUnitBuffInfo("reticleover", i)による
      直接スキャンだけに統一した。スキャンを行うタイミングは2つだけ:
        ① EVENT_RETICLE_TARGET_CHANGEDでターゲットが変わった瞬間に即時スキャン
        ② ターゲット中は一定間隔(既定250ms)の定期スキャン
      毎フレーム・高頻度のポーリングは行わない。ターゲットが存在しない、
      またはプレイヤーでない間はAPI自体を呼ばない。

      ・同じAbilityIdのエントリはtargetEffects[abilityId]という
        テーブルに1つしか存在できない構造にしているため、同じ効果が
        重複して表示されることはない(変更なし)。
      ・自動検知/手動登録の判定(重要かどうか)、GetUnitBuffInfoの
        戻り値の取得順序は、v1.4.25から一切変更していない。
      ・自動検知キーワードや手動登録リストを設定画面で変更した場合は、
        PTI.Target.ForceRefresh()経由でtargetEffectsを再スキャンし、
        変更を即座に反映する(変更なし)。
      ・学習モード(/pti learn target)の候補収集は、従来は
        EVENT_EFFECT_CHANGEDのGAINEDイベントの中で行っていたが、
        定期直接スキャンのループの中から行う形に合わせた
        (収集ロジック自体・ログ内容は変更していない)。

    v2.0.4で追加: 敵バフ/デバフ検知の個別ON/OFFと、消えた効果の「残像」表示。
      ・(v2.0.7で個別検知ON/OFF=sv.enemyBuffDetect/enemyDebuffDetectは撤去。
        代わりにパネル表示OFFの種類はスキャンしない: IsKindScanNeeded参照。)
      ・「すぐ消える」原因は、①スキャンごとにtargetEffectsを全消去して作り直す、
        ②endTime超過・API消失で即削除される、③保持中(holdDuration)のキャッシュが
        残り時間マイナスのまま描画される、の3点だった。①②に対し、直前まで
        有効だった効果がスキャンから消えた時に、sv.lingerDuration秒だけ
        「残像(ghost)」として灰色・「終了」「消失」表記で残す。残像は残り時間を
        表示せず、有効な効果より必ず下に並べるため、現在有効な効果とは
        誤認されない。③は残り時間が尽きた古いキャッシュを残像扱いにして解消。
      ・残像はターゲットが同一プレイヤーの間だけ作る(別ターゲットへ切替・
        設定変更による再判定では作らない)。タイマーは追加せず、既存の250ms
        再スキャンとターゲット変更時スキャンの中だけで処理する。

    ターゲット解除後は、直前の情報を sv.holdDuration 秒だけ保持してから
    非表示にする(PvPの激しい動きでカーソルが一瞬外れても消えないように)。
    新しい敵をターゲットしたら保持中でも即座に新しい情報へ切り替える。
--]]

PvPTargetInfo = PvPTargetInfo or {}
local PTI = PvPTargetInfo
PTI.Target = PTI.Target or {}

local UPDATE_NAME = "PTI_TargetUpdate"
local UPDATE_INTERVAL_MS = 100 -- 残り時間による強調の切り替わりを見逃さないよう短めの間隔にしている

--------------------------------------------------------------------------
-- 検知パイプラインのデバッグログ(v1.4.6で追加)
--
-- sv.debug.pipelineTrace が true の間だけチャットに1行ずつ出力する。
-- 既定はOFFで、通常プレイでは呼び出されても何も起こらない
-- (dは一切呼ばれない)ため、実戦中にログでチャットが埋まる心配はない。
-- 学習モード(sv.procs.debugLearnModeTarget)とは完全に独立していて、
-- こちらは候補登録を一切行わない、純粋な経路確認用のログ。
--------------------------------------------------------------------------
local function DebugTrace(fmt, ...)
    if PTI.sv.debug and PTI.sv.debug.pipelineTrace then
        d("|c888888[PTI Debug]|r " .. string.format(fmt, ...))
    end
end

local function CountTable(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

--------------------------------------------------------------------------
-- 自動検知①: 状態異常(CC)の種類による判定
--
-- ゲームバージョンによって定数の有無・名前が変わる可能性があるため、
-- 存在しない定数名は_G参照がnilになるだけで安全にスキップされる
-- (比較対象がnilになるだけで、エラーにはならない)。
--------------------------------------------------------------------------
local CC_STATUS_EFFECT_TYPES = {}
local function RegisterCCStatusType(constantName)
    local value = _G[constantName]
    if value ~= nil then
        CC_STATUS_EFFECT_TYPES[value] = true
    end
end
local CC_STATUS_EFFECT_TYPE_NAMES = {
    "STATUS_EFFECT_TYPE_STUN",
    "STATUS_EFFECT_TYPE_SNARE",
    "STATUS_EFFECT_TYPE_ROOT",
    "STATUS_EFFECT_TYPE_SILENCE",
    "STATUS_EFFECT_TYPE_FEAR",
    "STATUS_EFFECT_TYPE_CHARM",
    "STATUS_EFFECT_TYPE_DISORIENT",
    "STATUS_EFFECT_TYPE_STAGGER",
    "STATUS_EFFECT_TYPE_OFFBALANCE",
    "STATUS_EFFECT_TYPE_UNSTABLE",
    "STATUS_EFFECT_TYPE_TRAPPED",
}
local ccUnresolvedNames = {}
for _, constantName in ipairs(CC_STATUS_EFFECT_TYPE_NAMES) do
    RegisterCCStatusType(constantName)
    if _G[constantName] == nil then
        table.insert(ccUnresolvedNames, constantName)
    end
end

--------------------------------------------------------------------------
-- 自動検知②: 効果名のキーワードによる判定
--
-- v1.4.7で修正(重要バグ修正): 日本語版ESOでは「Major/Minor」に相当する
-- 表示が英語版のような語頭(例: "Major Brutality")ではなく、
-- 「残忍(強)」「強固(弱)」のように語尾の "(強)"/"(弱)" になる。
-- これまでは前方一致(name:find(kw,1,true)==1、＝先頭からの一致のみ)で
-- 判定していたため、日本語表示では絶対に一致せず、自動検知が
-- 実質的に機能していなかった。部分一致(先頭に限らず、名前のどこかに
-- キーワードが含まれていればOK)に変更し、既定キーワードにも
-- 日本語版の "(強)"/"(弱)" を追加した。
--------------------------------------------------------------------------
-- v1.4.12で修正: 英語表記/日本語表記を個別にON/OFFできるようにしていたが、
-- 「意味がない」とのことで単純な固定リストに戻した。自動検知が有効な間は
-- 常にこの4語(英語版Major/Minor、日本語版(強)/(弱))すべてを対象にする。
local AUTO_DETECT_KEYWORDS = { "Major", "Minor", "(強)", "(弱)" }
local function GetAutoDetectKeywords()
    return AUTO_DETECT_KEYWORDS
end

-- 部分一致で判定する(plain=trueでパターンではなく単純文字列として比較)。
-- 英語版の "Major Brutality"(先頭一致)、日本語版の "残忍(強)"(末尾一致)の
-- どちらにも対応できるよう、名前中のどこかにキーワードが含まれていれば
-- 一致とみなす。
local function NameMatchesKeyword(name, keywords)
    for _, kw in ipairs(keywords) do
        if name:find(kw, 1, true) then return true end
    end
    return false
end

local function IsAutoImportant(kind, buffName, statusEffectType, keywords)
    if kind == "debuff" and CC_STATUS_EFFECT_TYPES[statusEffectType] then
        return true
    end
    return NameMatchesKeyword(buffName, keywords)
end

-- v1.4.23で追加: PvPTargetInfo_Procs.lua(Condition/旧Procパネル)から、
-- 「敵のDEBUFF自動検知と全く同じ判定方法」を使って、自分に付いている
-- デバフを検知できるようにするための公開ラッパー。
-- 判定基準(CC系statusEffectType、またはMajor/Minor・(強)/(弱)の
-- キーワード一致)は敵デバフの自動検知(①②)と完全に同一のロジックを
-- そのまま再利用している(判定式を重複実装しない)。
function PTI.Target.IsAutoImportantDebuff(buffName, statusEffectType)
    if type(buffName) ~= "string" or buffName == "" then return false end
    return IsAutoImportant("debuff", buffName, statusEffectType, GetAutoDetectKeywords())
end

--------------------------------------------------------------------------
-- 表示優先順位: カテゴリ分類(修正改定4)
--
-- 「基本は重要度(カテゴリ)順、ただし残り時間が短いものは優先して上位に
-- 表示する」という表示ルールを実現するための分類テーブル。
--
-- 判定は効果名の部分一致で行う。Major版とMinor版は数値が違うだけで
-- カテゴリは同じなので、接頭辞(Major/Minor)を含めず効果ファミリー名
-- (Resolve, Breachなど)だけをキーワードにしている。
--
-- 既定値は英語表記("Major"/"Minor"や日本語版の(強)/(弱)を自動検知する
-- 既定キーワードとは別物で、こちらはカテゴリ分類専用のキーワード)。日本語
-- 表示等、別のゲーム内表示言語でプレイしている場合は、下記キーワードを
-- 実際に表示される効果名に合わせて書き換えないと、表示自体はされるが
-- 並び順が「その他」扱いになる(表示の可否には影響しない)。
--------------------------------------------------------------------------

-- バフ側: 数字が小さいほど優先度が高い(上位表示)
-- v1.4.7で修正: ESOのシステムアップデートにより、以前は物理耐性(Resolve)と
-- 呪文耐性(Ward)に分かれていた防御バフが、現在は「Resolve」に統合され、
-- 物理・呪文の両方の耐性が同時に上がる仕様になった。単体の"Ward"という
-- 効果はもう存在しないためキーワードから外し、日本語版での呼び名
-- "不屈"(Resolve)を追加した。
local BUFF_CATEGORY_ORDER = {
    -- ① 防御・ダメージ軽減
    { rank = 1, keywords = { "Resolve", "不屈", "Evasion", "Protection" } },
    -- ② 回復・生存
    { rank = 2, keywords = { "Vitality", "Mending", "Fortitude", "Endurance", "Intellect", "Lifesteal", "Toughness" } },
    -- ③ 攻撃力・与ダメージ強化
    { rank = 3, keywords = { "Brutality", "Sorcery", "Berserk", "Courage", "Slayer", "Empower" } },
    -- ④ クリティカル関連
    { rank = 4, keywords = { "Prophecy", "Savagery", "Force" } },
    -- ⑤ 機動力・CC耐性
    { rank = 5, keywords = { "Expedition", "Gallop", "Heroism" } },
}
local BUFF_OTHER_RANK = 6 -- ⑥ その他の戦闘系(上記に該当しない重要バフ)

-- デバフ側: 数字が小さいほど優先度が高い(上位表示)
-- 「CC・行動阻害」(rank=4)は効果名ではなく既存のCC_STATUS_EFFECT_TYPES
-- (statusEffectType)で判定するため、このテーブルには含めていない。
local DEBUFF_CATEGORY_ORDER = {
    -- ① 防御低下・被ダメージ増加
    { rank = 1, keywords = { "Breach", "Vulnerability", "Brittle" } },
    -- ② 回復阻害
    { rank = 2, keywords = { "Defile" } },
    -- ③ 攻撃力・与ダメージ低下
    { rank = 3, keywords = { "Maim", "Cowardice", "Uncertainty" } },
    -- ⑤ 強力なDoT
    { rank = 5, keywords = { "Poison", "Disease", "Burning", "Bleed", "Deep Wound", "Sundered" } },
}
local DEBUFF_CC_RANK = 4    -- ④ CC・行動阻害(statusEffectTypeで判定)
local DEBUFF_OTHER_RANK = 6 -- ⑥ その他の戦闘系(上記に該当しない重要デバフ)

-- 残り時間がこの秒数以下になったら、カテゴリ順位に関わらず上位表示する。
-- UI①・UI②の強調色ティア(黄色以上、残り5秒以内)と揃えてある。
local URGENT_REMAINING_THRESHOLD = 5

local function LookupCategoryRank(order, name)
    for _, group in ipairs(order) do
        for _, kw in ipairs(group.keywords) do
            if name:find(kw, 1, true) then
                return group.rank
            end
        end
    end
    return nil
end

-- 表示中の1件について、表示優先度用のカテゴリ順位を返す(数字が小さいほど上位)。
-- 手動登録した効果も、名前が上記キーワードに一致すれば同様に分類され、
-- 一致しなければ「その他の戦闘系」として最下位カテゴリに入る
-- (表示すること自体は登録時点で保証されているため、順位が最下位でも
-- 表示対象から外れることはない)。
local function GetCategoryRank(kind, buffName, statusEffectType)
    if kind == "debuff" and CC_STATUS_EFFECT_TYPES[statusEffectType] then
        return DEBUFF_CC_RANK
    end
    local order = (kind == "debuff") and DEBUFF_CATEGORY_ORDER or BUFF_CATEGORY_ORDER
    return LookupCategoryRank(order, buffName) or ((kind == "debuff") and DEBUFF_OTHER_RANK or BUFF_OTHER_RANK)
end

--------------------------------------------------------------------------
-- 手動登録リスト(任意)
-- 形式: sv.watchedBuffs[abilityId] = { name = "表示名", enabled = true }
--       sv.watchedDebuffs[abilityId] = { name = "表示名", enabled = true }
-- enabled=false のエントリは「登録はされているが今は非表示」の状態になる。
--------------------------------------------------------------------------

local function GetWatchTable(kind)
    return kind == "debuff" and PTI.sv.watchedDebuffs or PTI.sv.watchedBuffs
end

function PTI.Target.AddWatch(kind, abilityId, name)
    abilityId = tonumber(abilityId)
    if not abilityId then return false end
    local t = GetWatchTable(kind)
    t[abilityId] = { name = name or ("ability " .. tostring(abilityId)), enabled = true }
    if PTI.Target.ForceRefresh then PTI.Target.ForceRefresh() end
    return true
end

function PTI.Target.RemoveWatch(kind, abilityId)
    abilityId = tonumber(abilityId)
    if not abilityId then return false end
    local t = GetWatchTable(kind)
    if not t[abilityId] then return false end
    t[abilityId] = nil
    if PTI.Target.ForceRefresh then PTI.Target.ForceRefresh() end
    return true
end

function PTI.Target.SetWatchEnabled(kind, abilityId, enabled)
    abilityId = tonumber(abilityId)
    local t = GetWatchTable(kind)
    if not t or not t[abilityId] then return false end
    t[abilityId].enabled = enabled
    if PTI.Target.ForceRefresh then PTI.Target.ForceRefresh() end
    return true
end

function PTI.Target.ClearWatch(kind)
    ZO_ClearTable(GetWatchTable(kind))
    if PTI.Target.ForceRefresh then PTI.Target.ForceRefresh() end
end

function PTI.Target.IsWatchListEmpty(kind)
    return next(GetWatchTable(kind)) == nil
end

-- LAM2の手動編集欄・チャットコマンドのlist表示用に、abilityIdでソートした配列で取得する。
function PTI.Target.GetWatchListSorted(kind)
    local t = GetWatchTable(kind)
    local ids = {}
    for id in pairs(t) do table.insert(ids, id) end
    table.sort(ids)
    local list = {}
    for _, id in ipairs(ids) do
        table.insert(list, { id = id, name = t[id].name, enabled = t[id].enabled })
    end
    return list
end

--------------------------------------------------------------------------
-- ① プレイヤー判定
--
-- reticleoverが「存在し、かつプレイヤーである」場合だけ有効な対象として
-- 扱う。NPC・モンスター・衛兵は当然IsUnitPlayerがfalseになるため除外され、
-- 通用口・壁・扉・篝火などの相互作用可能なオブジェクトはそもそも
-- reticleoverのユニットとして存在しない(DoesUnitExistがfalse)か、
-- 存在してもプレイヤーではないため、いずれにせよここで弾かれる。
--------------------------------------------------------------------------
--
-- v2.0.6: 「敵プレイヤーのみ」をアドオン全体の固定仕様にした。判定はこの1か所
-- (GetReticleVerdict)に集約し、UI①②(このファイル)と UI④(Pen.lua) の両方が
-- PTI.Target.IsEnemyPlayerTarget() を使う。設定でOFFにすることはできない。
--
-- 判定手順(どれか1つでも確認できなければ「敵ではない」=表示しない側に倒す):
--   1. reticleoverが存在し、IsUnitPlayer==true(NPC・モンスター・オブジェクトを除外)
--   2. バトルグラウンド内(IsActiveWorldBattleground)
--        → GetUnitBattlegroundAlliance を自分と相手で比較し、両方が有効値で
--          かつ「異なる」ときだけ敵。BGではゲームがランダムに割り当てる専用
--          チームが敵味方の実体で、GetUnitReaction/AreUnitsCurrentlyAllied が
--          見る元のアライアンス(AD/EP/DC)とは別物のため(過去の実機ログで確認)。
--   3. それ以外(シロディール・帝都・決闘など)
--        → GetUnitReaction("reticleover") == UNIT_REACTION_HOSTILE のときだけ敵。
--          PvEゾーンの他プレイヤーはPLAYER_ALLY(味方)になるので表示されない。
-- 注意: 決闘相手がHOSTILEを返すかは未確認(返さなければ表示されない)。
--------------------------------------------------------------------------
-- v2.0.7(任意変更): 決闘中の相手。GetDuelInfo()はZOSのUpdate 12 APIパッチノート
-- (API 100017)に「GetDuelInfo() - DUEL_STATE, partnerCharacterName,
-- partnerDisplayName」と記載のある関数で、DUEL_STATE_DUELING定数も同ノートに
-- 記載がある。決闘はPvEの屋外ゾーンのみで行われる(BG/Cyrodiilでは起きない)ため、
-- BG判定の後ろ・非BG側でだけ使う。reticleoverの表示名(@名)と相手の表示名が
-- 一致した時だけ「決闘相手=敵」とみなし、API無し・取得失敗・不一致はすべて
-- 「敵ではない」(従来どおり非表示)側に倒す。PS5実機では未検証。
local function IsDuelOpponentTarget()
    if not GetDuelInfo or DUEL_STATE_DUELING == nil then return false end
    local ok, state, _, partnerDisplayName = pcall(GetDuelInfo)
    if not ok or state ~= DUEL_STATE_DUELING then return false end
    if type(partnerDisplayName) ~= "string" or partnerDisplayName == "" then return false end
    local name = GetUnitDisplayName("reticleover")
    return type(name) == "string" and name ~= "" and name == partnerDisplayName
end

local function GetReticleVerdict()
    if not DoesUnitExist("reticleover") then return false, "対象なし" end
    if not IsUnitPlayer("reticleover") then return false, "プレイヤーではない(NPC等)" end

    if IsActiveWorldBattleground and IsActiveWorldBattleground() then
        if not GetUnitBattlegroundAlliance then return false, "BG判定APIなし" end
        local mine = GetUnitBattlegroundAlliance("player")
        local theirs = GetUnitBattlegroundAlliance("reticleover")
        local none = BATTLEGROUND_ALLIANCE_NONE or 0
        if type(mine) ~= "number" or type(theirs) ~= "number" or mine == none or theirs == none then
            return false, "BG: チーム不明"
        end
        if mine ~= theirs then return true, "BG: 別チーム(敵)" end
        return false, "BG: 同じチーム(味方)"
    end

    if not GetUnitReaction or UNIT_REACTION_HOSTILE == nil then return false, "反応判定APIなし" end
    if GetUnitReaction("reticleover") == UNIT_REACTION_HOSTILE then return true, "敵対(HOSTILE)" end
    if IsDuelOpponentTarget() then return true, "決闘相手" end
    return false, "敵対ではない(味方/中立)"
end

function PTI.Target.IsEnemyPlayerTarget()
    return (GetReticleVerdict())
end

local IsValidEnemyTarget = PTI.Target.IsEnemyPlayerTarget

-- /pti enemy : 現在のターゲットについて、判定に使う各値と最終判定を表示する(診断用)。
function PTI.Target.PrintEnemyDiagnostics()
    local function say(fmt, ...) d("|c55CCFF[PvPTargetInfo]|r " .. string.format(fmt, ...)) end
    local function safe(fn, ...)
        if not fn then return "API無し" end
        local ok, v = pcall(fn, ...)
        return ok and tostring(v) or "エラー"
    end
    if not DoesUnitExist("reticleover") then
        say("対象なし。プレイヤーにカーソルを合わせて実行してください。")
        return
    end
    say("IsUnitPlayer=%s / GetUnitReaction=%s (HOSTILE=%s) / AreUnitsCurrentlyAllied=%s",
        safe(IsUnitPlayer, "reticleover"), safe(GetUnitReaction, "reticleover"),
        tostring(UNIT_REACTION_HOSTILE), safe(AreUnitsCurrentlyAllied, "player", "reticleover"))
    say("BG内=%s / BGチーム 自分=%s 相手=%s / 元アライアンス 自分=%s 相手=%s",
        safe(IsActiveWorldBattleground), safe(GetUnitBattlegroundAlliance, "player"),
        safe(GetUnitBattlegroundAlliance, "reticleover"), safe(GetUnitAlliance, "player"),
        safe(GetUnitAlliance, "reticleover"))
    local duelOk, duelState, _, duelPartner = false, nil, nil, nil
    if GetDuelInfo then duelOk, duelState, _, duelPartner = pcall(GetDuelInfo) end
    say("決闘: 状態=%s (DUELING=%s) / 相手の表示名=%s / reticleoverの表示名=%s",
        duelOk and tostring(duelState) or "API無し/エラー", tostring(DUEL_STATE_DUELING),
        tostring(duelPartner), safe(GetUnitDisplayName, "reticleover"))
    local verdict, reason = GetReticleVerdict()
    say("最終判定: %s (%s)", verdict and "敵プレイヤー=表示する" or "表示しない", reason)
end

--------------------------------------------------------------------------
-- ② 効果キャッシュ(修正改定6)
--
-- targetEffects[abilityId] = { kind=, name=, stackCount=, endTime=, categoryRank= }
-- 「現在ターゲット中のプレイヤーが持つ、重要と判定された効果」だけを
-- 保持する。キーがAbilityIdなので同じ効果が重複して入ることはない。
--------------------------------------------------------------------------
local effectsA, effectsB = {}, {}
local targetEffects = effectsA -- スキャンごとにA/Bを交互に使い、直前の内容(prev)を残像判定に使う

-- v2.0.4: 直前まで有効だったが消えた効果の「残像」。ghostEffects[abilityId] = 効果エントリ
-- (ghostUntil=残像の表示期限ゲーム時刻, ghostLabel="終了"/"消失")。
local ghostEffects = {}
local lastScanTargetKey = nil
local GHOST_NATURAL_END_MARGIN = 0.5 -- endTimeまでこの秒数以内に消えた場合は自然終了とみなす
local DEFAULT_LINGER_SECONDS = 2.0

-- v2.0.7: 個別の検知ON/OFFは撤去した。敵と確認できたら一律に検知する。
-- ここで決めるのは「検知するか」ではなく「そのパネルが表示対象のとき、無駄な
-- スキャンをしない」ための条件だけ:
--   ・アドオン全体がOFF、またはその種類のパネル(UI①=buffUI / UI②=debuffUI)が
--     OFFのとき → その種類のスキャンはしない
--   ・敵バフ/デバフの学習モード(debugLearnModeTarget)中は、候補収集のため
--     パネルがOFFでもスキャンする
-- Condition(Procs.lua)・PEN(Pen.lua)の処理には関係しない。
local function IsKindScanNeeded(kind)
    local sv = PTI.sv
    if not sv.enabled then return false end
    local ui = (kind == "debuff") and sv.debuffUI or sv.buffUI
    if ui and ui.enabled ~= false then return true end
    return sv.procs ~= nil and sv.procs.debugLearnModeTarget == true
end

local function GetLingerSeconds()
    local v = PTI.sv.lingerDuration
    if type(v) ~= "number" then return DEFAULT_LINGER_SECONDS end
    if v < 0 then return 0 end
    return v
end

-- 効果1件について、現在の設定(自動検知/手動登録)で重要と判定されるかどうかを返す。
-- 重要でなくなった場合(手動登録が削除された等)も呼び出し元でtargetEffectsから
-- 除去できるよう、判定結果だけを返す純粋な関数にしてある。
-- v1.4.14で修正: 従来は「重要かどうか(isManual or isAuto)」がそのまま
-- 「表示するかどうか」だったが、全表示モードのために両者を分離した。
-- 戻り値はisImportant(自動検知/手動登録で重要と判定されたか)とdisplayName。
-- 「表示するかどうか」の最終判定はUpsertTargetEffect側で行う
-- (全表示モードでは、重要でなくても背景バフでなければ表示する)。
local function EvaluateEffect(kind, abilityId, buffName, statusEffectType)
    local watch = GetWatchTable(kind)[abilityId]
    local isManual = watch ~= nil and watch.enabled
    local isAuto = (not isManual) and PTI.sv.autoDetect.enabled
        and IsAutoImportant(kind, buffName, statusEffectType, GetAutoDetectKeywords())
    local isImportant = isManual or isAuto
    local displayName = buffName
    if isManual and watch.name ~= "" then displayName = watch.name end
    return isImportant, displayName
end

-- v1.4.14で追加: 全表示モードで、食事バフ・マウント速度・ギルドバフのような
-- 「常時付いていて今更確認する必要のない」背景バフを除外するための判定。
-- duration(効果の全長、秒)がnil(=無期限・永続効果)、または設定した
-- 閾値(既定120秒)を超える場合に「背景バフ」とみなす。
-- APIの想定外の戻り値(durationが数値でない等)にも安全側(背景バフ扱い=除外)
-- で倒すようにしている。
local function IsBackgroundBuff(duration)
    if type(duration) ~= "number" then return true end
    local threshold = (PTI.sv.showAll and PTI.sv.showAll.hideLongerThan) or 120
    if type(threshold) ~= "number" or threshold <= 0 then threshold = 120 end
    return duration > threshold
end

-- 効果1件をtargetEffectsへ反映する(重要でなければ削除、重要なら追加/更新)。
-- EVENT_EFFECT_CHANGEDのGAINED、および初期スキャンの両方から呼ばれる共通処理。
--
-- v1.4.9で追加: beginTimeを受け取り、endTimeとの差からduration(効果の
-- 全長)を算出してキャッシュする。UI側の残り時間バー(下部の薄いバー)を
-- 「remaining / duration」で描画するために必要(beginTimeまたはendTimeが
-- 無効/取得できない場合はduration=nilとし、バーは常時満タン表示になる)。
local function UpsertTargetEffect(kind, abilityId, buffName, statusEffectType, beginTime, endTime, stackCount)
    -- APIの更新が1ティック遅れて「終了時刻は過ぎているのにまだ返ってくる」
    -- 端境期のデータは、消える直前に一瞬古い表示へ戻るのを防ぐため除外する。
    local isStaleExpired = type(endTime) == "number" and endTime > 0
        and (endTime - GetGameTimeSeconds()) <= 0
    if isStaleExpired then
        targetEffects[abilityId] = nil
        return
    end

    local isImportant, displayName = EvaluateEffect(kind, abilityId, buffName, statusEffectType)

    local duration = nil
    if type(beginTime) == "number" and type(endTime) == "number" and endTime > beginTime then
        duration = endTime - beginTime
    end

    -- v1.4.14で追加: 検知方式が「全表示」の場合、重要でない効果も
    -- 背景バフ(食事バフ・マウント速度等)でない限り表示対象にする。
    -- 重要と判定された効果(CC/Major-Minor/手動登録)は、全表示モードでも
    -- 通常モードでも、背景バフ判定に関わらず必ず表示する(見逃し防止)。
    local matters
    if isImportant then
        matters = true
    elseif PTI.sv.detectionMode == "all" then
        matters = not IsBackgroundBuff(duration)
    else
        matters = false
    end

    if not matters then
        targetEffects[abilityId] = nil
        return
    end

    targetEffects[abilityId] = {
        kind = kind,
        name = displayName,
        stackCount = stackCount,
        endTime = (type(endTime) == "number" and endTime > 0) and endTime or nil,
        duration = duration,
        -- 分類は手動登録時の表示名(displayName)ではなく、ゲーム側の
        -- 実際の効果名(buffName)で判定する(表示名だとキーワードが
        -- 含まれず「その他」に落ちてしまうため)。優先順位ルールは
        -- 全表示モードでも自動検知モードと完全に同じものを使う。
        categoryRank = GetCategoryRank(kind, buffName, statusEffectType),
    }
end

--------------------------------------------------------------------------
-- 学習モード(/pti learn target)の候補収集
--
-- v2.0.3で変更: 以前はEVENT_EFFECT_CHANGEDのGAINEDイベントの中で候補を
-- 集めていたが、効果検知そのものを定期直接スキャン方式に変更したため、
-- 候補収集もスキャンループの中から行う形に合わせた。ロジック自体
-- (未発見のAbilityIdをログ+候補リストに積む)は変更していない。
--------------------------------------------------------------------------
local seenTargetAbilityIds = {}
PTI.Target.seenTargetAbilityIds = seenTargetAbilityIds -- 学習モードON時にリセットできるよう公開

-- 学習モードで見つかった登録候補。バフ/デバフでリストを分けておくことで、
-- LAM2の設定パネルからもそれぞれ独立して選択・登録できるようにする。
local pendingCandidates = {
    buff = {},   -- 配列: { {id=, name=}, ... }
    debuff = {},
}
local pendingIndexById = {
    buff = {},   -- abilityId -> pendingCandidates[kind]内のindex
    debuff = {},
}

local function RefreshPendingUI()
    if PTI.Settings and PTI.Settings.RefreshWatchPendingDropdowns then
        PTI.Settings.RefreshWatchPendingDropdowns()
    end
end

-- LAM2のドロップダウン用: 表示ラベルの配列とAbilityIdの配列を返す
function PTI.Target.GetPendingChoices(kind)
    local labels, values = {}, {}
    for _, entry in ipairs(pendingCandidates[kind]) do
        table.insert(labels, string.format("%s (%d)", entry.name, entry.id))
        table.insert(values, entry.id)
    end
    return labels, values
end

-- 候補リストからAbilityIdを指定して手動登録する(名前の入力は不要)
function PTI.Target.RegisterPendingById(kind, abilityId)
    abilityId = tonumber(abilityId)
    local index = abilityId and pendingIndexById[kind][abilityId]
    if not index then return false end
    local entry = pendingCandidates[kind][index]

    PTI.Target.AddWatch(kind, entry.id, entry.name)

    table.remove(pendingCandidates[kind], index)
    pendingIndexById[kind][abilityId] = nil
    -- 削除した要素より後ろのインデックスを詰め直す
    for i = index, #pendingCandidates[kind] do
        pendingIndexById[kind][pendingCandidates[kind][i].id] = i
    end
    RefreshPendingUI()
    return true, entry.name
end

function PTI.Target.ClearPendingCandidates()
    ZO_ClearTable(pendingCandidates.buff)
    ZO_ClearTable(pendingCandidates.debuff)
    ZO_ClearTable(pendingIndexById.buff)
    ZO_ClearTable(pendingIndexById.debuff)
    RefreshPendingUI()
end

-- 学習モードがONの時だけ、未発見のAbilityIdについてログ出力+候補登録を行う。
-- 表示自体(targetEffects)には一切影響しない副次的な処理。
local function MaybeLearnFromEffect(kind, abilityId, buffName, statusEffectType, beginTime, endTime)
    if not (PTI.sv.procs.debugLearnModeTarget and type(abilityId) == "number" and not seenTargetAbilityIds[abilityId]) then
        return
    end
    seenTargetAbilityIds[abilityId] = true

    local alreadyAuto = PTI.sv.autoDetect.enabled
        and IsAutoImportant(kind, buffName or "", statusEffectType, GetAutoDetectKeywords())

    local duration = 0
    if type(beginTime) == "number" and type(endTime) == "number" then
        duration = endTime - beginTime
    end

    d(string.format("|c55CCFF[PTI Learn:Target]|r [%s] %s / abilityId=%s / statusEffectType=%s / duration=%.1fs / 自動検知=%s",
        kind, buffName or "?", tostring(abilityId), tostring(statusEffectType),
        duration, alreadyAuto and "対象(登録不要)" or "対象外"))

    if not alreadyAuto then
        d(string.format("|c55CCFF[PTI Learn:Target]|r 追加で表示したい場合: /pti watch %s use %s (または設定パネルの候補から選択)",
            kind, tostring(abilityId)))

        if not pendingIndexById[kind][abilityId] then
            table.insert(pendingCandidates[kind], { id = abilityId, name = buffName or ("ability " .. tostring(abilityId)) })
            pendingIndexById[kind][abilityId] = #pendingCandidates[kind]
            RefreshPendingUI()
        end
    end
end

-- ターゲットを変更した直後、および定期スキャンのたびに呼ばれる。
-- v2.0.3で変更: 以前は「ターゲット変更時に1回だけ読み、以後は
-- EVENT_EFFECT_CHANGEDの差分更新に任せる」方式だったが、イベントの
-- 取りこぼしに左右されないよう、GetUnitBuffInfoで現在の全バフを毎回
-- 読み直してtargetEffectsを作り直す方式に統一した(詳細はファイル冒頭)。
-- 値の取得順序・重要判定(UpsertTargetEffect/EvaluateEffect)は無変更。
local lastScanDebugSignature = nil

local function RescanCurrentTargetEffects(suppressGhosts)
    local prev = targetEffects
    local nextEffects = (prev == effectsA) and effectsB or effectsA
    ZO_ClearTable(nextEffects)
    targetEffects = nextEffects

    -- v2.0.7: 表示対象の種類が1つも無い(パネルが両方OFF等)ときは、敵判定も
    -- GetNumBuffs/GetUnitBuffInfoも呼ばずに終了する。
    local buffOn = IsKindScanNeeded("buff")
    local debuffOn = IsKindScanNeeded("debuff")
    if not buffOn and not debuffOn then
        ZO_ClearTable(ghostEffects)
        lastScanTargetKey = nil
        lastScanDebugSignature = "none"
        return
    end

    if not IsValidEnemyTarget() then
        -- v2.0.6: 味方・NPC等「敵ではないユニット」にカーソルが移ったときは、直前の
        -- 敵の残像も即座に破棄する(カーソルが何も指していない場合は従来通り保持)。
        if DoesUnitExist("reticleover") then
            ZO_ClearTable(ghostEffects)
            lastScanTargetKey = nil
        end
        if lastScanDebugSignature ~= "none" then
            lastScanDebugSignature = "none"
            DebugTrace("①対象取得: reticleoverが無効(NPC/オブジェクト/対象なし) → スキャンしない")
        end
        return
    end

    -- 同一プレイヤーを見続けている間だけ残像を作る(別ターゲットへ切り替わったら破棄)。
    local targetKey = GetUnitDisplayName("reticleover")
    if not targetKey or targetKey == "" then targetKey = GetUnitName("reticleover") or "?" end
    local sameTarget = (targetKey == lastScanTargetKey)
    if not sameTarget then
        ZO_ClearTable(ghostEffects)
        lastScanTargetKey = targetKey
    end

    local numBuffs = 0
    if buffOn or debuffOn then
        numBuffs = GetNumBuffs("reticleover")
        for i = 1, numBuffs do
            local buffName, startTime, endTime, buffSlot, stackCount, iconFile,
                  buffType, effectType, abilityType, statusEffectType, abilityId,
                  canClickOff = GetUnitBuffInfo("reticleover", i)

            if type(abilityId) == "number" and buffName and buffName ~= "" then
                local kind = (effectType == BUFF_EFFECT_TYPE_DEBUFF) and "debuff" or "buff"
                if (kind == "debuff" and debuffOn) or (kind == "buff" and buffOn) then
                    UpsertTargetEffect(kind, abilityId, buffName, statusEffectType, startTime, endTime, stackCount)
                    MaybeLearnFromEffect(kind, abilityId, buffName, statusEffectType, startTime, endTime)
                end
            end
        end
    end

    -- 残像の更新。再び有効になった効果の残像は消し、直前まで有効だったのに
    -- 今回のスキャンから消えた効果だけを新たに残像にする。
    local now = GetGameTimeSeconds()
    for abilityId in pairs(targetEffects) do
        ghostEffects[abilityId] = nil
    end
    local linger = GetLingerSeconds()
    if sameTarget and not suppressGhosts and linger > 0 then
        for abilityId, e in pairs(prev) do
            if targetEffects[abilityId] == nil and ghostEffects[abilityId] == nil
                and ((e.kind == "debuff" and debuffOn) or (e.kind ~= "debuff" and buffOn)) then
                e.ghostUntil = now + linger
                -- 終了時刻の手前で消えた(解除・上書き・取得ずれ等)ものは「消失」、
                -- 時間切れで消えたものは「終了」。
                if e.endTime and (e.endTime - now) > GHOST_NATURAL_END_MARGIN then
                    e.ghostLabel = "消失"
                else
                    e.ghostLabel = "終了"
                end
                ghostEffects[abilityId] = e
            end
        end
    end
    for abilityId, e in pairs(ghostEffects) do
        if now > e.ghostUntil then ghostEffects[abilityId] = nil end
    end

    -- 内容が変わった時だけログを出す(250msごとに毎回出すとチャットが埋まるため)。
    local sig = string.format("%s|%d|%d|%d", targetKey, numBuffs, CountTable(targetEffects), CountTable(ghostEffects))
    if sig ~= lastScanDebugSignature then
        lastScanDebugSignature = sig
        DebugTrace("①対象取得: %s をプレイヤーとして確認 → スキャン完了(全%d件の効果中、重要%d件を表示データに反映、残像%d件)",
            targetKey, numBuffs, CountTable(targetEffects), CountTable(ghostEffects))
    end
end

-- targetEffectsから、UI描画用のbuff配列/debuff配列を組み立てる。
local function BuildEntryArrays()
    local buffEntries, debuffEntries = {}, {}
    local now = GetGameTimeSeconds()
    local function AddEntry(abilityId, e)
        local entry = {
            abilityId = abilityId,
            name = e.name,
            stackCount = e.stackCount,
            endTime = e.endTime,
            duration = e.duration,
            categoryRank = e.categoryRank,
            ghostUntil = e.ghostUntil,
            ghostLabel = e.ghostLabel,
        }
        if e.kind == "debuff" then
            table.insert(debuffEntries, entry)
        else
            table.insert(buffEntries, entry)
        end
    end
    for abilityId, e in pairs(targetEffects) do
        AddEntry(abilityId, e)
    end
    for abilityId, e in pairs(ghostEffects) do
        if targetEffects[abilityId] == nil and now <= e.ghostUntil then
            AddEntry(abilityId, e)
        end
    end
    return buffEntries, debuffEntries
end

-- 表示順のルール:
--   1. 残り時間がURGENT_REMAINING_THRESHOLD秒以下の「緊急」枠は、カテゴリに
--      関わらず最優先で上位に来る。緊急枠同士は残り時間が短い順。
--   2. 緊急枠でないものは、カテゴリ順位(categoryRank、小さいほど上位)の順。
--   3. 同じカテゴリ内では、残り時間が短いものほど先。残り時間不明
--      (永続等)は一番後ろに回す。
local function SortEntries(entries)
    local now = GetGameTimeSeconds()
    table.sort(entries, function(a, b)
        -- v2.0.4: 残像(消えた効果)は、現在有効な効果より必ず下に並べる。
        local ga, gb = (a.ghostUntil ~= nil), (b.ghostUntil ~= nil)
        if ga ~= gb then
            return gb
        end
        if ga then
            local ka, kb = a.categoryRank or math.huge, b.categoryRank or math.huge
            if ka ~= kb then return ka < kb end
            return (a.abilityId or 0) < (b.abilityId or 0)
        end
        local ra = a.endTime and (a.endTime - now) or math.huge
        local rb = b.endTime and (b.endTime - now) or math.huge
        local aUrgent = ra <= URGENT_REMAINING_THRESHOLD
        local bUrgent = rb <= URGENT_REMAINING_THRESHOLD

        if aUrgent ~= bUrgent then
            return aUrgent
        end
        if aUrgent then
            -- 緊急枠同士: 残り時間が短い順
            return ra < rb
        end
        -- 通常枠: カテゴリ順位 → 残り時間の順
        local rankA, rankB = a.categoryRank or math.huge, b.categoryRank or math.huge
        if rankA ~= rankB then
            return rankA < rankB
        end
        return ra < rb
    end)
end

-- 「自動検知OFF」かつ「手動登録も0件」の場合だけ表示する案内行。
-- 自動検知ONの状態は、今その瞬間に該当する効果が無いだけの正常な状態なので
-- ヒントは出さない(常時ヒントが出ているとかえって邪魔になるため)。
local function HintEntry(kind)
    local label = (kind == "debuff") and "DEBUFF" or "BUFF"
    return { isHint = true, name = string.format("(%s: 自動検知OFF・登録なし。設定で有効にしてください)", label) }
end

local function RenderEntries(key, entries)
    local sv = (key == "buff") and PTI.sv.buffUI or PTI.sv.debuffUI
    local maxRows = sv.maxRows or 6
    local now = GetGameTimeSeconds()
    local index = 0

    local linger = PTI.sv.lingerDuration
    if type(linger) ~= "number" then linger = DEFAULT_LINGER_SECONDS end

    for _, entry in ipairs(entries) do
        if index >= maxRows then break end

        -- v2.0.4: 残像(消えた効果)の判定。
        --   ・entry.ghostUntilあり: 表示期限内だけ残像として表示
        --   ・ghostUntilなしでendTimeが過ぎている(ターゲット解除後の保持中キャッシュ、
        --     または終了〜次回スキャンまでの間): 残り時間がマイナスの「有効な効果」
        --     として出さず、残像と同じ扱い(linger=0なら出さない)
        local isGhost, ghostLabel, skip = false, nil, false
        if not entry.isHint then
            if entry.ghostUntil then
                if now > entry.ghostUntil then
                    skip = true
                else
                    isGhost, ghostLabel = true, entry.ghostLabel or "終了"
                end
            elseif entry.endTime and (entry.endTime - now) <= 0 then
                if linger > 0 then
                    isGhost, ghostLabel = true, "終了"
                else
                    skip = true
                end
            end
        end

        if not skip then
            index = index + 1
            local row = PTI.UI.AcquireRow(key, index)

            if entry.isHint then
                row.nameLabel:SetFont(PTI.UI.RowFont(key))
                row.nameLabel:SetColor(0.55, 0.57, 0.6, 1)
                row.nameLabel:SetText(entry.name)
                row.timeLabel:SetFont(PTI.UI.RowFont(key))
                row.timeLabel:SetText("")
                PTI.UI.SetRowBar(row, nil) -- 案内行には残り時間バーを出さない
            elseif isGhost then
                -- 残像: 灰色・通常フォント・残り時間なし・バーなし。名前の後ろにも
                -- 「(終了)」「(消失)」を付け、現在有効な効果と見分けられるようにする。
                row.nameLabel:SetFont(PTI.UI.RowFont(key))
                row.nameLabel:SetText(string.format("%s (%s)", entry.name, ghostLabel))
                row.nameLabel:SetColor(0.5, 0.5, 0.52, 1)
                row.timeLabel:SetFont(PTI.UI.RowFont(key))
                row.timeLabel:SetColor(0.5, 0.5, 0.52, 1)
                row.timeLabel:SetText(ghostLabel)
                PTI.UI.SetRowBar(row, nil)
            else
                local remaining = entry.endTime and (entry.endTime - now) or nil
                local displaySeconds = remaining and zo_ceil(remaining) or nil
                local tier = PTI.UI.GetImportantTier(key, displaySeconds)
                local font = PTI.UI.BuildTierFont(key, tier.sizeDelta, tier.outline)

                local displayName = tier.prefix .. entry.name
                if type(entry.stackCount) == "number" and entry.stackCount > 1 then
                    displayName = string.format("%s x%d", displayName, entry.stackCount)
                end

                row.nameLabel:SetFont(font)
                row.nameLabel:SetText(displayName)
                row.nameLabel:SetColor(tier.color[1], tier.color[2], tier.color[3], tier.color[4])

                row.timeLabel:SetFont(font)
                row.timeLabel:SetColor(tier.color[1], tier.color[2], tier.color[3], tier.color[4])
                row.timeLabel:SetText(displaySeconds and (displaySeconds .. "s") or "")

                -- v1.4.9で追加: 下部の残り時間バー。durationが分かる効果は
                -- 「remaining / duration」の比率で減っていく。durationが
                -- 不明(永続効果、または初回付与時にbeginTimeが取れなかった等)の
                -- 場合は満タンのまま固定表示にする。
                local percent = 1
                if remaining and entry.duration and entry.duration > 0 then
                    percent = remaining / entry.duration
                end
                PTI.UI.SetRowBar(row, percent, tier.color)
            end
        end
    end

    PTI.UI.ReleaseUnusedRows(key, index + 1)
    return index
end

--------------------------------------------------------------------------
-- プレビューモード(sv.previewMode)用のダミーデータ
-- 設定画面の「プレビュー表示」をONにすると、実際のターゲットが無くても
-- UI①・UI②の位置・大きさ・強調色の見え方を確認できる。8秒周期でティア
-- (色)が一巡するサンプル行を出す。
--------------------------------------------------------------------------
local function BuildPreviewEntries(nameA, nameB, nameC)
    local now = GetGameTimeSeconds()
    local function fakeRemaining(phaseOffset)
        return 8 - ((now + phaseOffset) % 8)
    end
    return {
        { name = nameA, stackCount = nil, endTime = now + fakeRemaining(0), duration = 8 },
        { name = nameB, stackCount = 2,   endTime = now + fakeRemaining(3), duration = 8 },
        { name = nameC, stackCount = nil, endTime = now + fakeRemaining(6), duration = 8 },
    }
end

--------------------------------------------------------------------------
-- ③ 表示安定性(ホールド表示用キャッシュ)
--
-- reticleoverが一瞬外れただけ(あるいは一瞬だけNPCに重なった等)で
-- パネルが消えたり中身が空になったりしないよう、有効なプレイヤーを
-- 最後に見ていた時点のスナップショットをsv.holdDuration秒だけ保持する。
-- targetEffects自体はターゲット変更のたびに作り直されるため、この
-- スナップショット(cachedBuffEntries/cachedDebuffEntries)を別に
-- 持っておくことで、保持中も直前の表示内容が維持される。
--------------------------------------------------------------------------
local lastTargetSeenTime = nil   -- 有効なプレイヤーが最後に対象だったゲーム内時刻
local cachedTargetName = "---"
local cachedBuffEntries = {}
local cachedDebuffEntries = {}

-- ⑥UI描画のデバッグログ用。OnUpdateは0.1秒ごとに走るため、内容が変わって
-- いない限りログを出さないようにして、デバッグON中でもチャットが埋まり
-- すぎないようにする。
local lastRenderDebugSignature = nil

local function OnUpdate()
    if not PTI.sv.enabled then
        PTI.UI.SetWindowVisible("buff")
        PTI.UI.SetWindowVisible("debuff")
        return
    end

    local buffWin = PTI.UI.GetWindow("buff")
    local debuffWin = PTI.UI.GetWindow("debuff")

    if PTI.sv.previewMode then
        buffWin.titleLabel:SetText("BUFF (プレビュー)")
        debuffWin.titleLabel:SetText("DEBUFF (プレビュー)")
        RenderEntries("buff", BuildPreviewEntries("勇気の炎", "集中攻撃", "不屈の意志"))
        RenderEntries("debuff", BuildPreviewEntries("よろめき", "出血", "束縛"))
        PTI.UI.SetWindowVisible("buff")
        PTI.UI.SetWindowVisible("debuff")
        return
    end

    -- v2.0.7: 表示対象の種類が無い(パネルが両方OFF等)ときは、敵判定・描画データの
    -- 組み立てをせず、表示状態の反映だけ行って終わる(スキャン側と同じ条件)。
    if not IsKindScanNeeded("buff") and not IsKindScanNeeded("debuff") then
        cachedBuffEntries, cachedDebuffEntries, cachedTargetName = {}, {}, "---"
        lastTargetSeenTime = nil
        PTI.UI.SetWindowVisible("buff")
        PTI.UI.SetWindowVisible("debuff")
        return
    end

    local now = GetGameTimeSeconds()
    -- ①プレイヤー判定: NPC・モンスター・衛兵・オブジェクトはここで弾かれる
    local hasTarget = IsValidEnemyTarget()

    if hasTarget then
        lastTargetSeenTime = now

        -- v1.4.3で修正: キャラクター名ではなく、オンラインID(@表示名)を表示する。
        -- ターゲットダミー等、表示名を持たないユニットの場合は空文字が返るため、
        -- その場合だけキャラクター名にフォールバックする。
        local targetName = GetUnitDisplayName("reticleover")
        if not targetName or targetName == "" then
            targetName = GetUnitName("reticleover")
        end
        cachedTargetName = targetName

        cachedBuffEntries, cachedDebuffEntries = BuildEntryArrays()
        SortEntries(cachedBuffEntries)
        SortEntries(cachedDebuffEntries)
    end

    local holdSec = PTI.sv.holdDuration or 1.0
    -- v2.0.6: 保持(holdDuration)は「カーソルが何も指していない」間だけ働く。味方・NPC等の
    -- 敵ではないユニットにカーソルが移った場合は、直前の敵の情報を残さず即座に消す。
    if (not hasTarget) and DoesUnitExist("reticleover") then
        lastTargetSeenTime = nil
    end
    local withinHold = (not hasTarget) and lastTargetSeenTime and ((now - lastTargetSeenTime) <= holdSec)
    local shouldKeepShowing = hasTarget or withinHold

    if not shouldKeepShowing then
        -- 保持時間も過ぎたので、次にターゲットし直したときに古い情報が
        -- 一瞬だけ表示されてしまわないようキャッシュを空にする。
        cachedBuffEntries, cachedDebuffEntries, cachedTargetName = {}, {}, "---"
        lastTargetSeenTime = nil
    end

    buffWin.titleLabel:SetText((cachedTargetName ~= "---") and ("BUFF: " .. cachedTargetName) or "BUFF")
    debuffWin.titleLabel:SetText((cachedTargetName ~= "---") and ("DEBUFF: " .. cachedTargetName) or "DEBUFF")

    local buffCount = RenderEntries("buff", cachedBuffEntries)
    if buffCount == 0 and IsKindScanNeeded("buff") and PTI.sv.detectionMode ~= "all" and not PTI.sv.autoDetect.enabled and PTI.Target.IsWatchListEmpty("buff") then
        RenderEntries("buff", { HintEntry("buff") })
    end

    local debuffCount = RenderEntries("debuff", cachedDebuffEntries)
    if debuffCount == 0 and IsKindScanNeeded("debuff") and PTI.sv.detectionMode ~= "all" and not PTI.sv.autoDetect.enabled and PTI.Target.IsWatchListEmpty("debuff") then
        RenderEntries("debuff", { HintEntry("debuff") })
    end

    -- ⑥UI描画: 表示データ(cachedBuffEntries/cachedDebuffEntries)が実際に
    -- 何件UIへ渡ったかを確認する。内容が変わった時だけ出力する。
    if PTI.sv.debug and PTI.sv.debug.pipelineTrace then
        local sig = string.format("%s|%d|%d|%s|%s", cachedTargetName, buffCount, debuffCount,
            PTI.sv.enabled and "enabled" or "disabled", PTI.sv.buffUI.enabled ~= false and PTI.sv.debuffUI.enabled ~= false and "win_on" or "win_off")
        if sig ~= lastRenderDebugSignature then
            lastRenderDebugSignature = sig
            DebugTrace("⑥UI描画: 対象=%s → UI①(buff)=%d件 / UI②(debuff)=%d件 をパネルに反映(アドオン有効=%s)",
                cachedTargetName, buffCount, debuffCount, tostring(PTI.sv.enabled))
        end
    end

    -- パネルは中身の有無に関わらず、有効になっている限り常に表示する
    PTI.UI.SetWindowVisible("buff")
    PTI.UI.SetWindowVisible("debuff")
end

-- 設定変更直後など、次のティックを待たずに即座に再評価したい場合に使う。
-- 自動検知キーワードや手動登録リストの変更は、現在ターゲット中の
-- 効果の重要度判定を変えうるため、表示更新の前に必ず初期スキャンを
-- やり直して targetEffects を最新の判定基準で作り直す。
function PTI.Target.ForceRefresh()
    -- v2.0.4: 設定変更で「重要でなくなった/検知OFFになった」効果を残像にしてしまわないよう、
    -- 残像を全破棄し、この再スキャンでは残像を作らない。
    ZO_ClearTable(ghostEffects)
    RescanCurrentTargetEffects(true)
    OnUpdate()
end

function PTI.Target.RefreshFonts(key)
    PTI.UI.RefreshRowLayout(key)
end

--------------------------------------------------------------------------
-- ② 定期直接スキャン + ターゲット変更時の即時スキャン(v2.0.3)
--
-- v1.4.25まではEVENT_EFFECT_CHANGEDの差分更新に頼っていたが、イベントの
-- 取りこぼしに左右されないよう、GetNumBuffs+GetUnitBuffInfoによる直接
-- スキャン(RescanCurrentTargetEffects、上で定義済み)を次の2つの
-- タイミングだけで呼ぶ方式に統一した。
--   ① EVENT_RETICLE_TARGET_CHANGED でターゲットが変わった瞬間に即時スキャン
--   ② ターゲット中は一定間隔(既定250ms)の定期スキャン
-- EVENT_EFFECT_CHANGEDの購読自体を廃止したため、効果の取りこぼしという
-- 構造的な弱点が無くなった。値の取得順序・重要判定・学習モードの
-- ロジックはすべて上のRescanCurrentTargetEffects/MaybeLearnFromEffectに
-- 統一され、ここでは変更していない。
--------------------------------------------------------------------------
local SCAN_UPDATE_NAME = "PTI_TargetScan"
local SCAN_INTERVAL_MS = 250 -- 目安200〜300ms

-- ①ターゲット変更時の再判定。
-- reticleoverが変わるたびに発火するので、即座に新しい対象をスキャンする。
local function OnReticleTargetChanged()
    RescanCurrentTargetEffects()
end

-- RegisterForUpdateのコールバック引数が残像抑止フラグと誤解釈されないよう、
-- 引数を渡さないラッパーを介して呼ぶ。
local function OnScanTick()
    RescanCurrentTargetEffects()
end

function PTI.Target.Initialize()
    -- 状態異常(CC)の定数が実際にいくつ解決できたかを起動時に1回だけ報告する。
    -- ここが0件だと「Major/Minor」以外のCC系デバフの自動検知が丸ごと
    -- 機能しなくなるため、実戦ログでチャットが埋まる心配がない起動時のみ、
    -- デバッグ設定に関わらず常に表示する(検知不良の切り分けに直結するため)。
    local resolvedCount = CountTable(CC_STATUS_EFFECT_TYPES)
    if resolvedCount < #CC_STATUS_EFFECT_TYPE_NAMES then
        d(string.format(
            "|cFFAA00[PvPTargetInfo]|r 状態異常(CC)の自動検知: %d/%d 種類のみ認識できました(未解決: %s)。これらはMajor/Minorキーワードにも一致しない限り自動検知の対象外になります。",
            resolvedCount, #CC_STATUS_EFFECT_TYPE_NAMES, table.concat(ccUnresolvedNames, ", ")))
    end

    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, UPDATE_INTERVAL_MS, OnUpdate)

    -- 定期直接スキャン(既定250ms)。EVENT_EFFECT_CHANGEDは使用しない。
    EVENT_MANAGER:RegisterForUpdate(SCAN_UPDATE_NAME, SCAN_INTERVAL_MS, OnScanTick)

    local targetChangedEventName = PTI.name .. "ReticleTargetChanged"
    EVENT_MANAGER:RegisterForEvent(targetChangedEventName, EVENT_RETICLE_TARGET_CHANGED, OnReticleTargetChanged)

    -- 起動直後、既にreticleover上にプレイヤーが乗っている状態(UIリロード直後等)
    -- にも対応できるよう、初期化時にも一度スキャンしておく。
    RescanCurrentTargetEffects()
end
