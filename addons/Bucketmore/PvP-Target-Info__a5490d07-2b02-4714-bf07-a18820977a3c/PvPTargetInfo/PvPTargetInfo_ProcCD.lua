--[[
    PvPTargetInfo_ProcCD.lua  (v2.2.0)

    UI④ Self Proc CD: 自分の装備セットProc発動後、再発動可能になるまでの
    残り時間を縦並びで表示する。

    ■ 仕組み(独自実装。他アドオンのコード・データ表は複写していない)
      1. 装備セットの自動判別 … 装備スロットを走査しGetItemLinkSetInfoでセット(setId優先)を得る。
         装備変更時にだけ再取得する(常時走査しない)。
      2. Proc発動の検知 … UI③と同じ「自分のバフをGetUnitBuffInfoで走査する方式」。
         EVENT_EFFECT_CHANGED等はPS5で届かない報告(PCL診断)があるため使わない。
         ダメージ・召喚だけで自分にバフが付かないProcは検知できない(定義表のdetect=NONE)。
      3. 内部CDの追跡 … 発動時刻+ICD秒数=終了時刻。CD中の再検知は再起動しない。
         起点が特殊なセット(機械的精度など)は定義表のoriginに従う。
      4. ICD秒数の出所: ①/pti cd addの実測(VERIFIED) ②定義表(DOCUMENTED) ③セット説明文の自動解析
         (「N秒に1回」等が1種類だけ書かれている場合のみ。PS5実機未検証)。どれも無ければ表示しない。
      5. Procバフの特定: ①AbilityId一致 ②バフ名=装備中セット名 ③定義表のbuffNames(装備中のセットのみ)。

    ■ v2.3.0 追加: 自分にバフが付かないProc向けの「戦闘イベント方式」(PS5実機未検証・既定ON)
      Srendarrの調査で得た考え方(コードもデータ表も複写していない独自実装):
        ・Procの"きっかけ"のAbilityIdは、バフのIdと別で、能力名がセット名と一致することが多い
        ・EVENT_COMBAT_EVENTは頻発するため、発生源を自分に絞り、AbilityId一致/セット名一致の時だけ処理する
        ・ダメージのティック(DoT)等で同じProcを再検知しないよう、結果コードを限定しCD中は再起動しない
        ・バフ走査と戦闘イベントの両方で同じProcを数えても、同じkeyに畳んで二重計測しない
      ※ 戦闘イベントがPS5で届くか、能力名がセット名と一致するかは未確認。/pti cd probe で
        1回の実機テストで確かめられる。届かない・一致しない場合は従来のバフ走査だけで動く。
    ■ v2.4.0 追加
      1) Procの自動学習(既定ON。/pti cd auto): 戦闘中の自分発イベントを観察し、装備中でICDが確定している
         セットに紐づくAbilityIdを学習する。通常スキル・DoT・ペットを誤登録しないよう、
         「発生間隔がICD以上に揃う」「同一発動の複数ヒットを1回に数える」「セット名/説明文との一致」
         「複数回・複数戦闘での再現」が揃った時だけ自動登録(AUTO)し、足りない場合は候補(CAND)として
         保存するだけで検知には使わない。候補は /pti cd auto accept <番号> で本登録できる。
      2) 表示モード(UI④): 常時表示 / 戦闘終了後は非表示。判定はEVENT_PLAYER_COMBAT_STATE(イベント駆動)+
         猶予時間。非表示中もCD計測と学習は継続し、表示の更新だけを止める。
    ■ 説明文の取得(/pti cd text)とICD候補の分析(/pti cd icd)は別処理。
      textは「秒」の有無に関係なく全ボーナスの全文を出す(固定文字数での切り捨てなし)。

    ■ 軽量化
      パネルON中だけ100msの1本のTickを動かす(バフ走査は200msごと、表示更新は変化時のみ)。
      パネルOFFまたはアドオンOFFの間は、Tick・イベントを全て解除する。
      チャット出力は1tickあたり最大6行に分けて流す(一度に大量のd()を呼ばない)。
--]]

PvPTargetInfo = PvPTargetInfo or {}
local PTI = PvPTargetInfo
PTI.ProcCD = PTI.ProcCD or {}
local CD = PTI.ProcCD

local TICK_MS = 100
local SCAN_EVERY = 2 -- 100ms x 2 = 200msごとにバフ走査
local READY_TEXT = "READY"
local LINE_CHARS = 56   -- チャット1行あたりの最大文字数(全角1文字=1)
local OUT_PER_TICK = 6  -- チャットへ1回に流す行数
local OUT_MAX = 700     -- 出力キューの上限

local EVT = (PTI.name or "PvPTargetInfo") .. "CD"
local TAG = "|c55CCFF[PvPTargetInfo]|r "

-- 標準配色(固定。設定では変更しない)
local COLOR_WHITE  = { 0.949, 0.949, 0.949, 1 } -- #F2F2F2 パネルタイトル・セット名
local COLOR_YELLOW = { 1.000, 0.761, 0.278, 1 } -- #FFC247 CD残り秒数
local COLOR_GREEN  = { 0.333, 0.839, 0.545, 1 } -- #55D68B READY

local running = false
local equippedDirty = true
local tickCount = 0
local lastHasContent = nil
local indexBuilt = false
local baselineNext = false

local equippedSets = {}  -- 正規化セット名 -> { name, cd(説明文から。無ければnil), defKey }
local equippedDefs = {}  -- 定義表key -> true(装備中)
local entryById = {}     -- AbilityId -> { key, name, cd, status, origin, maxStacks }
local entryByName = {}   -- 正規化名 -> 定義表の項目(cd未確認も含む)
local entryByBuff = {}   -- 正規化バフ名 -> 定義表の項目
local states = {}        -- key -> { name, cd, startAt, endAt, ready, byName, defKey }
local pending = {}       -- key -> 起点がバフ終了/最大スタックのProc(CD開始待ち)
local baselineKeys = {}  -- ログイン時点で既に付いていたバフ(新規発動として扱わない)
local presentPrev, presentNow = {}, {}
local list, listCount = {}, 0

local LEARN_MIN_CD = 3           -- 自動学習の対象にするICDの最小秒数(DoT/通常攻撃の誤学習防止)
local CMB_GRACE = 6               -- 戦闘終了後、UI④を隠すまでの猶予秒数(戦闘状態のちらつき対策)
local LEARN_CAP = 120            -- 保存する学習記録の上限
local fightId, inCombatNow = 0, false
local hideToken = 0
local learnSets = {}             -- 学習対象: 装備中でICDが確定しているセット
local learnTargets = false
local learnActive = false
local barNames, barKnown = {}, false
local obs, obsN, ignoredIds = {}, 0, {}
local SyncCombat                 -- 前方宣言(戦闘イベントの登録/解除)
local combatTargets = false      -- 名前一致で戦闘イベント検知する対象セットが装備中か
local MIN_CD_NAME = 5            -- 名前一致の戦闘検知は、ICDがこの秒数未満のセットでは行わない(DoT再検知防止)
local VALID_RESULT = nil         -- 戦闘イベントの有効な結果コード(Startで1回だけ作る)
local combatOn = false           -- 名前一致方式で登録中か
local idRegs = {}                -- AbilityId指定の戦闘イベント登録: id -> true
local evCount, evWindow = 0, 0
local nameCache, nameCacheN = {}, 0

-- 学習モード(セッション限り。保存しない)
local learning, learned, learnBase, learnCount = false, {}, {}, 0

local function NormName(text)
    if type(text) ~= "string" or text == "" then return "" end
    return zo_strlower(zo_strformat("<<t:1>>", text))
end

--------------------------------------------------------------------------
-- チャット出力(キュー+ペーシング)
--------------------------------------------------------------------------
local outQueue, outHead, outTail = {}, 1, 0

local function FlushOut()
    for _ = 1, OUT_PER_TICK do
        if outHead > outTail then break end
        local line = outQueue[outHead]
        outQueue[outHead] = nil
        outHead = outHead + 1
        d(line)
    end
    if outHead > outTail then
        outQueue, outHead, outTail = {}, 1, 0
        EVENT_MANAGER:UnregisterForUpdate(EVT .. "Out")
    end
end

local function Out(line)
    if outTail - outHead >= OUT_MAX then return end
    local idle = outHead > outTail
    outTail = outTail + 1
    outQueue[outTail] = line
    if idle then EVENT_MANAGER:RegisterForUpdate(EVT .. "Out", 80, FlushOut) end
end

--------------------------------------------------------------------------
-- 文字列ユーティリティ(UTF-8を壊さない)
--------------------------------------------------------------------------
local function Utf8Len(b)
    if not b or b < 0x80 then return 1 end
    if b >= 0xF0 then return 4 end
    if b >= 0xE0 then return 3 end
    if b >= 0xC0 then return 2 end
    return 1
end

local function CharCount(s)
    local i, n, c = 1, #s, 0
    while i <= n do i = i + Utf8Len(s:byte(i)); c = c + 1 end
    return c
end

local function SplitByChars(s, maxChars)
    local out, i, n = {}, 1, #s
    while i <= n do
        local j, count = i, 0
        while j <= n and count < maxChars do j = j + Utf8Len(s:byte(j)); count = count + 1 end
        out[#out + 1] = s:sub(i, j - 1)
        i = j
    end
    return out
end

-- 色コード・改行を除去(チャットの制御文字 "|" を壊さないため、表示直前にChatEscを通す)
local function CleanDesc(text)
    if type(text) ~= "string" then return "" end
    local t = text:gsub("|c%x%x%x%x%x%x", "")
    t = t:gsub("|r", "")
    t = t:gsub("[\r\n]+", " ")
    return t
end

local function ChatEsc(s)
    local t = s:gsub("|", "||")
    return t
end

-- 文(日本語は「。」、英語は「. 」)に分割。「1.5 seconds」のような小数点では切らない
local function SplitSentences(text)
    local t = text:gsub("。", "。\1")
    t = t:gsub("(%a)%.(%s)", "%1.\1%2")
    t = t:gsub("(%d)%.(%s+%u)", "%1.\1%2")
    local out = {}
    for piece in t:gmatch("[^\1]+") do
        local p = piece:gsub("^%s+", "")
        p = p:gsub("%s+$", "")
        if p ~= "" then out[#out + 1] = p end
    end
    return out
end

-- 文を行にまとめる(1行LINE_CHARS文字まで。長い文は文字数で分割)
local function WrapText(text)
    local lines, cur, curLen = {}, "", 0
    for _, sent in ipairs(SplitSentences(text)) do
        local len = CharCount(sent)
        if len > LINE_CHARS then
            if cur ~= "" then lines[#lines + 1] = cur; cur, curLen = "", 0 end
            for _, part in ipairs(SplitByChars(sent, LINE_CHARS)) do lines[#lines + 1] = part end
        elseif curLen + len > LINE_CHARS and cur ~= "" then
            lines[#lines + 1] = cur
            cur, curLen = sent, len
        else
            cur = cur .. sent
            curLen = curLen + len
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    if #lines == 0 then lines[1] = "" end
    return lines
end

--------------------------------------------------------------------------
-- ICD候補の分析(説明文の取得とは別処理)
--   ICD      … 内部クールダウン候補(「N秒に1回」「once every N seconds」「N秒間は再発動しない」等)
--   INTERVAL … スタック間隔など(「up to once every N seconds」。ICDとして採用しない)
--   TICK     … 周期効果(「N秒ごとに」「every N seconds」)
--   DURATION … 効果時間・持続時間(「N秒間」「for N seconds」)
--   DELAY    … 遅延(「N秒後」「after N seconds」)
--   TIME     … 秒数があるが分類できない
-- 時間の数字があるだけではICDと断定しない。
--------------------------------------------------------------------------
local KIND_LABEL = {
    ICD = "内部CD候補", INTERVAL = "発動間隔(要確認)", TICK = "周期効果",
    DURATION = "効果時間", DELAY = "遅延", TIME = "時間(分類不明)",
}
local KIND_ORDER = { "ICD", "INTERVAL", "TICK", "DURATION", "DELAY", "TIME" }

local function ClassifyEN(s, a, b)
    local before = s:sub(math.max(1, a - 48), a - 1)
    local after = s:sub(b + 1, b + 30)
    if before:find("up to once every%s*$") or before:find("up to once per%s*$") then return "INTERVAL" end
    if before:find("once every%s*$") or before:find("once per%s*$") or before:find("can occur every%s*$")
        or before:find("occur again for%s*$") or before:find("cooldown of%s*$")
        or before:find("cannot regain[^%.]*for%s*$") or before:find("cannot gain[^%.]*for%s*$")
        or before:find("summoned once every%s*$") then
        return "ICD"
    end
    if after:find("^%s*cooldown") then return "ICD" end
    if before:find("every%s*$") then return "TICK" end
    if before:find("for%s*$") or before:find("over%s*$") or before:find("lasts?%s*$") then return "DURATION" end
    if before:find("after%s*$") or before:find("within%s*$") then return "DELAY" end
    return "TIME"
end

local JP_ICD_START = { "に1回", "に1度", "に一度", "に一回", "間に1回", "間に1度", "間に一度", "ごとに1回", "ごとに1度", "毎に1回" }
local JP_ICD_WORDS = { "再発動", "再び発動", "再度発動", "発動しない", "発生しない", "発動できない", "発生できない" }

local function StartsWithAny(s, list)
    for _, p in ipairs(list) do
        if s:sub(1, #p) == p then return true end
    end
    return false
end

local function ContainsAny(s, list)
    for _, p in ipairs(list) do
        if s:find(p, 1, true) then return true end
    end
    return false
end

local function ClassifyJP(s, a, b)
    local after = s:sub(b + 1, b + 45):gsub("^%s+", "")
    local before = s:sub(math.max(1, a - 60), a - 1)
    if StartsWithAny(after, JP_ICD_START) then return "ICD" end
    if before:find("クールダウン", 1, true) or after:find("クールダウン", 1, true) then return "ICD" end
    if after:sub(1, 3) == "間" and ContainsAny(after, JP_ICD_WORDS) then return "ICD" end
    if ContainsAny(after:sub(1, 30), JP_ICD_WORDS) then return "ICD" end
    if after:sub(1, 6) == "ごと" or after:sub(1, 6) == "おき" then return "TICK" end
    if after:sub(1, 3) == "間" or after:sub(1, 9) == "かけて" then return "DURATION" end
    if after:sub(1, 3) == "後" or after:sub(1, 6) == "以内" then return "DELAY" end
    return "TIME"
end

local function AnalyzeDesc(desc)
    local items = {}
    for _, sent in ipairs(SplitSentences(CleanDesc(desc))) do
        local low = zo_strlower(sent)
        local pos = 1
        while true do
            local a, b, num = low:find("([%d%.]+)%s*seconds?", pos)
            if not a then break end
            local n = tonumber(num)
            if n then items[#items + 1] = { kind = ClassifyEN(low, a, b), sec = n, text = sent } end
            pos = b + 1
        end
        pos = 1
        while true do
            local a, b, num = sent:find("([%d%.]+)%s*秒", pos)
            if not a then break end
            local n = tonumber(num)
            if n then items[#items + 1] = { kind = ClassifyJP(sent, a, b), sec = n, text = sent } end
            pos = b + 1
        end
    end
    return items
end

-- 全ボーナスのitemsから採用するICDを1つ選ぶ(異なる値が複数あれば曖昧として採用しない)
local function PickIcd(items)
    local seen, count, first = {}, 0, nil
    for _, it in ipairs(items) do
        if it.kind == "ICD" and it.sec > 0 and it.sec <= 120 and not seen[it.sec] then
            seen[it.sec] = true
            count = count + 1
            first = it.sec
        end
    end
    if count == 1 then return first, "採用" end
    if count > 1 then return nil, "曖昧(異なるICD候補が複数)" end
    return nil, "ICD候補なし"
end

--------------------------------------------------------------------------
-- 装備セットと説明文の取得
--------------------------------------------------------------------------
local function CollectSets()
    local result, byKey = {}, {}
    if not (GetBagSize and GetItemLink and GetItemLinkSetInfo) then return result end
    local size = GetBagSize(BAG_WORN) or 0
    for slot = 0, size - 1 do
        local link = GetItemLink(BAG_WORN, slot)
        if link and link ~= "" then
            local hasSet, setName, numBonuses, _, _, setId = GetItemLinkSetInfo(link, true)
            if hasSet and type(setName) == "string" and setName ~= "" then
                local key
                if type(setId) == "number" and setId > 0 then key = "id:" .. setId else key = "n:" .. NormName(setName) end
                if not byKey[key] then
                    local s = {
                        key = key, setId = (type(setId) == "number") and setId or nil,
                        name = zo_strformat("<<t:1>>", setName), norm = NormName(setName),
                        link = link, numBonuses = numBonuses,
                    }
                    byKey[key] = s
                    result[#result + 1] = s
                end
            end
        end
    end
    return result
end

-- 戻り値: bonuses = { {idx, req, desc} }, fails = { {idx, reason} }
local function FetchBonuses(set)
    local bonuses, fails = {}, {}
    if not GetItemLinkSetBonusInfo then
        fails[1] = { idx = 0, reason = "GetItemLinkSetBonusInfoが存在しない" }
        return bonuses, fails
    end
    local n = set.numBonuses
    if type(n) ~= "number" then
        fails[1] = { idx = 0, reason = "ボーナス数(numBonuses)を取得できない" }
        return bonuses, fails
    end
    for i = 1, n do
        local ok, req, desc = pcall(GetItemLinkSetBonusInfo, set.link, true, i)
        if not ok then
            fails[#fails + 1] = { idx = i, reason = "API呼び出しでエラー" }
        elseif type(desc) ~= "string" or desc == "" then
            fails[#fails + 1] = { idx = i, reason = "説明文が空、または文字列ではない" }
        else
            bonuses[#bonuses + 1] = { idx = i, req = tonumber(req) or i, desc = desc }
        end
    end
    return bonuses, fails
end

--------------------------------------------------------------------------
-- 定義の索引(定義表 + ユーザー登録 + 日本語名の別名)
--------------------------------------------------------------------------
local function RebuildIndex()
    indexBuilt = true
    ZO_ClearTable(entryById)
    ZO_ClearTable(entryByName)
    ZO_ClearTable(entryByBuff)
    local data = PTI.CDData and PTI.CDData.entries or {}
    for _, e in ipairs(data) do
        for _, nm in ipairs(e.names or {}) do entryByName[NormName(nm)] = e end
        for _, nm in ipairs(e.buffNames or {}) do entryByBuff[NormName(nm)] = e end
        if type(e.cd) == "number" and e.cd > 0 then
            for _, id in ipairs(e.ids or {}) do
                entryById[id] = { key = "d:" .. e.key, name = nil, cd = e.cd, status = e.status, origin = e.origin, maxStacks = e.maxStacks }
            end
        end
    end
    local sv = PTI.sv
    local alias = sv and sv.cd and sv.cd.alias or {}
    for name, key in pairs(alias) do
        local e = PTI.CDData and PTI.CDData.byKey and PTI.CDData.byKey[key]
        if e and type(name) == "string" then entryByName[NormName(name)] = e end
    end
    local learned = sv and sv.cd and sv.cd.learned or {}
    for id, r in pairs(learned) do
        local n = tonumber(id)
        if n and type(r) == "table" and (r.conf == "AUTO" or r.conf == "ACCEPTED")
            and type(r.cd) == "number" and r.cd > 0 and type(r.setKey) == "string" then
            local gateDef, gateName
            if r.setKey:sub(1, 2) == "d:" then gateDef = r.setKey:sub(3) else gateName = r.setKey:sub(3) end
            entryById[n] = { key = r.setKey, name = r.setName, cd = r.cd, status = "LEARNED", byId = true,
                             gateDef = gateDef, gateName = gateName }
        end
    end
    local userEv = sv and sv.cd and sv.cd.userEv or {}
    for id, u in pairs(userEv) do
        local n = tonumber(id)
        if n and type(u) == "table" and type(u.cd) == "number" and u.cd > 0 then
            entryById[n] = { key = "u:" .. n, name = u.name, cd = u.cd, status = "VERIFIED" }
        end
    end
    local user = sv and sv.cd and sv.cd.user or {}
    for id, u in pairs(user) do
        local n = tonumber(id)
        if n and type(u) == "table" and type(u.cd) == "number" and u.cd > 0 then
            entryById[n] = { key = "u:" .. n, name = u.name, cd = u.cd, status = "VERIFIED" }
        end
    end
end

local function EnsureIndex()
    if not indexBuilt then RebuildIndex() end
end

-- 現在のアクションバーに入っているスキル名(通常スキルを候補から除外するため)
local function BuildBarNames()
    ZO_ClearTable(barNames)
    barKnown = false
    if not (GetSlotBoundId and HOTBAR_CATEGORY_PRIMARY and HOTBAR_CATEGORY_BACKUP) then return end
    for _, cat in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        for slot = 3, 8 do
            local ok, id = pcall(GetSlotBoundId, slot, cat)
            if ok and type(id) == "number" and id > 0 then
                local nm = NormName(GetAbilityName(id))
                if nm ~= "" then barNames[nm] = true; barKnown = true end
            end
        end
    end
end

local function RescanEquipped()
    equippedDirty = false
    ZO_ClearTable(equippedSets)
    ZO_ClearTable(equippedDefs)
    combatTargets = false
    ZO_ClearTable(learnSets)
    BuildBarNames()
    for _, s in ipairs(CollectSets()) do
        local bonuses = FetchBonuses(s)
        local items = {}
        for _, b in ipairs(bonuses) do
            for _, it in ipairs(AnalyzeDesc(b.desc)) do items[#items + 1] = it end
        end
        local def = entryByName[s.norm]
        if def then equippedDefs[def.key] = true end
        if not equippedSets[s.norm] then
            local cd = PickIcd(items)
            equippedSets[s.norm] = { name = s.name, cd = cd, defKey = def and def.key or nil }
            local useCd = (def and type(def.cd) == "number") and def.cd or cd
            if useCd and useCd >= MIN_CD_NAME and not (def and def.origin) then combatTargets = true end
            if useCd and useCd >= LEARN_MIN_CD and not (def and def.origin) then
                local parts = {}
                for _, b in ipairs(bonuses) do parts[#parts + 1] = b.desc end
                learnSets[#learnSets + 1] = {
                    key = def and ("d:" .. def.key) or ("n:" .. s.norm), name = s.name, norm = s.norm, cd = useCd,
                    descNorm = zo_strlower(CleanDesc(table.concat(parts, " "))),
                }
            end
        end
    end
    learnTargets = #learnSets > 0
    -- 外したセットの行は消す(AbilityId登録分は残す)
    for key, st in pairs(states) do
        if st.defKey then
            if not equippedDefs[st.defKey] then states[key] = nil end
        elseif st.byName and not equippedSets[st.byName] then
            states[key] = nil
        end
    end
    for key, p in pairs(pending) do
        if p.defKey and not equippedDefs[p.defKey] then pending[key] = nil end
    end
    SyncCombat()
end

--------------------------------------------------------------------------
-- バフ -> Proc特定
-- 戻り値: key, info(name, cd, byName, defKey, origin, maxStacks)
--------------------------------------------------------------------------
local function Resolve(buffName, abilityId, nmPre)
    local e = entryById[abilityId]
    if e then
        -- 自動学習の記録は、そのセットを装備している間だけ有効
        if e.gateDef and not equippedDefs[e.gateDef] then return nil end
        if e.gateName and not equippedSets[e.gateName] then return nil end
        return e.key, { name = e.name or buffName, cd = e.cd, origin = e.origin, maxStacks = e.maxStacks, byId = true,
                        defKey = e.gateDef, byName = e.gateName }
    end
    local nm = nmPre or NormName(buffName)
    local set = equippedSets[nm]
    local def = set and entryByName[nm] or nil
    if not def then
        local bd = entryByBuff[nm]
        if bd and equippedDefs[bd.key] then def = bd end
    end
    local cd
    if def and type(def.cd) == "number" and def.cd > 0 then
        cd = def.cd
    elseif set and set.cd then
        cd = set.cd
    end
    if not cd then return nil end
    if def and type(def.cd) == "number" then
        return "d:" .. def.key, { name = buffName, cd = cd, defKey = def.key, origin = def.origin, maxStacks = def.maxStacks }
    end
    return "n:" .. nm, { name = buffName, cd = cd, byName = nm }
end

local function StartCd(key, info, startAt)
    states[key] = {
        name = info.name, cd = info.cd, byName = info.byName, defKey = info.defKey,
        startAt = startAt, endAt = startAt + info.cd, ready = false,
    }
end

local function OnProc(key, info, startTime, now)
    local st = states[key]
    if st and now < st.endAt then return end -- CD中の再検知は再起動しない
    local startAt = startTime
    if type(startAt) ~= "number" or startAt <= 0 or startAt > now then startAt = now end
    if now - startAt >= info.cd then return end -- 既にCD経過済みの古いバフ(ログイン時等)は対象外
    StartCd(key, info, startAt)
end

local function LearnObserve(buffName, startTime, endTime, stacks, abilityId, now)
    if type(abilityId) ~= "number" or abilityId == 0 or learnBase[abilityId] then return end
    local l = learned[abilityId]
    if not l then
        if learnCount >= 40 then return end
        l = { name = buffName, dur = 0, maxStack = 0, seen = 0, last = -1 }
        learned[abilityId] = l
        learnCount = learnCount + 1
    end
    if type(startTime) == "number" and type(endTime) == "number" and endTime > startTime then l.dur = endTime - startTime end
    if type(stacks) == "number" and stacks > l.maxStack then l.maxStack = stacks end
    local stamp = (type(startTime) == "number") and startTime or now
    if l.last ~= stamp then l.seen = l.seen + 1; l.last = stamp end
end

local function ScanBuffs(now)
    local baseline = baselineNext
    baselineNext = false
    ZO_ClearTable(presentNow)
    local numBuffs = GetNumBuffs("player") or 0
    for i = 1, numBuffs do
        -- 戻り値: buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId
        local buffName, startTime, endTime, _, stackCount, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if type(buffName) == "string" and buffName ~= "" then
            if learning then LearnObserve(buffName, startTime, endTime, stackCount, abilityId, now) end
            local key, info = Resolve(buffName, abilityId)
            if key and not presentNow[key] then
                local stamp = (type(startTime) == "number") and startTime or now
                presentNow[key] = stamp
                if info.origin == "STACKMAX" or info.origin == "FADE" then
                    -- CD起点がバフの出現ではないProc: 最大スタック到達/効果終了でCD開始
                    if baseline then baselineKeys[key] = true end
                    if not baselineKeys[key] then
                        local p = pending[key]
                        local st = states[key]
                        if not p and not (st and now < st.endAt) then
                            p = { info = info }
                            pending[key] = p
                        end
                        if p and info.origin == "STACKMAX" and type(info.maxStacks) == "number"
                            and type(stackCount) == "number" and stackCount >= info.maxStacks then
                            StartCd(key, info, now)
                            pending[key] = nil
                        end
                    end
                else
                    local prev = presentPrev[key]
                    -- 新規出現、またはバフの開始時刻が更新された(再発動)時だけProcとして扱う
                    if prev == nil or zo_abs(stamp - prev) > 0.05 then
                        OnProc(key, info, stamp, now)
                    end
                end
            end
        end
    end
    -- 効果が終了したProc(起点=効果終了)のCD開始
    for key, p in pairs(pending) do
        if not presentNow[key] then
            StartCd(key, p.info, now)
            pending[key] = nil
        end
    end
    for key in pairs(baselineKeys) do
        if not presentNow[key] then baselineKeys[key] = nil end
    end
    presentPrev, presentNow = presentNow, presentPrev
end

--------------------------------------------------------------------------
-- 戦闘イベント方式(自分にバフが付かないProc向け。PS5実機未検証)
--   ・発生源を自分(COMBAT_UNIT_TYPE_PLAYER)に絞って登録する
--   ・AbilityId一致、またはセット名と能力名が一致した時だけProcとして扱う
--   ・DoTのティック等は結果コードで除外し、CD中の再検知はOnProcが無視する(二重計測しない)
--   ・起点が特殊なセット(STACKMAX/FADE)はバフ走査側に任せる
--------------------------------------------------------------------------
local VALID_NAMES = {
    "ACTION_RESULT_DAMAGE", "ACTION_RESULT_CRITICAL_DAMAGE", "ACTION_RESULT_HEAL", "ACTION_RESULT_CRITICAL_HEAL",
    "ACTION_RESULT_EFFECT_GAINED", "ACTION_RESULT_EFFECT_GAINED_DURATION", "ACTION_RESULT_POWER_ENERGIZE",
}

local function BuildValidResults()
    if VALID_RESULT then return end
    VALID_RESULT = {}
    for _, nm in ipairs(VALID_NAMES) do
        local v = _G[nm]
        if v ~= nil then VALID_RESULT[v] = true end
    end
end

local function CachedNorm(raw)
    local nm = nameCache[raw]
    if nm == nil then
        if nameCacheN >= 300 then nameCache, nameCacheN = {}, 0 end
        nm = NormName(raw)
        nameCache[raw] = nm
        nameCacheN = nameCacheN + 1
    end
    return nm
end

--------------------------------------------------------------------------
-- Procの自動学習(装備中でICDが確定しているセットに、AbilityIdを紐づける)
--   観察: 自分発の戦闘イベントを、同一発動(0.6秒以内の複数ヒット)として1回に数え、発動間隔を記録
--   判定: 間隔が全てICD以上(誤差0.7秒)であること。通常攻撃・DoT・連発スキルはここで落ちる
--   自動登録(AUTO)の条件: 間隔がICD付近に揃う発動が確認され、能力名がセット名か説明文と一致し、
--     5回以上・2戦闘以上で再現し、アクションバーのスキル名ではないこと
--   上記を満たさないものは候補(CAND)として保存するだけで、検知には使わない
--------------------------------------------------------------------------
local function LearnedTable()
    local sv = PTI.sv
    if type(sv.cd.learned) ~= "table" then sv.cd.learned = {} end
    return sv.cd.learned
end

local function LearnedCount()
    local n = 0
    for _ in pairs(LearnedTable()) do n = n + 1 end
    return n
end

-- 1つのイベント履歴を、装備中の各セットに照らして最も妥当なものを返す。条件を満たさなければnil
local function ScoreFor(o, S, tightSeen)
    for _, g in ipairs(o.gaps) do
        if g < S.cd - 0.7 then return nil, true end -- ICDより短い間隔がある = ICDの発動ではない
    end
    local tight = tightSeen or false
    for _, g in ipairs(o.gaps) do
        if g <= S.cd + 1.5 then tight = true end
    end
    local nameMatch = (o.norm == S.norm)
    local inDesc = (#o.norm >= 9) and (S.descNorm:find(o.norm, 1, true) ~= nil)
    if barNames[o.norm] and not nameMatch then return nil, false end -- アクションバーのスキル
    local score = 0
    if nameMatch or inDesc then score = score + 3 end
    if nameMatch and inDesc then score = score + 1 end
    if tight then score = score + 2 end
    return score, false, tight, (nameMatch or inDesc)
end

local function Confidence(rec)
    if rec.conf == "AUTO" or rec.conf == "ACCEPTED" then return "高" end
    if (rec.score or 0) >= 4 then return "中" end
    return "低"
end

local function EvaluateObs(id, o)
    local ign = PTI.sv.cd.learnIgnore
    if ign and ign[id] then return end
    local L = LearnedTable()
    local rec = L[id]
    if rec and rec.conf == "ACCEPTED" then return end -- 手動で確定したものは触らない
    local best, bestS, bestTight, bestName
    local violated = false
    for _, S in ipairs(learnSets) do
        local sc, viol, tight, nameEv = ScoreFor(o, S, rec and rec.tight)
        if viol then violated = true end
        if sc and (not best or sc > best) then best, bestS, bestTight, bestName = sc, S, tight, nameEv end
    end
    if not best then
        -- ICDより短い間隔で起きた = 自動登録済みでも根拠が崩れたので候補へ戻す
        if violated and rec and rec.conf == "AUTO" then
            rec.conf = "CAND"
            rec.demoted = (rec.demoted or 0) + 1
            RebuildIndex()
        end
        return
    end
    if not rec then
        if LearnedCount() >= LEARN_CAP then return end
        rec = { n = o.n, fights = o.fights, conf = "CAND" }
        L[id] = rec
    else
        rec.n = (rec.n or 0) + 1
        if o.fightCounted ~= fightId then
            rec.fights = (rec.fights or 0) + 1
        end
    end
    o.fightCounted = fightId
    rec.name, rec.setName, rec.setKey, rec.cd = o.name, bestS.name, bestS.key, bestS.cd
    rec.score = best
    rec.tight = rec.tight or bestTight or false
    rec.nameEv = rec.nameEv or bestName or false
    if rec.conf ~= "AUTO" and rec.nameEv and rec.tight and (rec.n or 0) >= 5 and (rec.fights or 0) >= 2 then
        rec.conf = "AUTO"
        RebuildIndex()
    end
end

local function ObserveCombat(aName, abilityId, now)
    if ignoredIds[abilityId] then return end
    local ign = PTI.sv.cd.learnIgnore
    if ign and ign[abilityId] then return end
    local o = obs[abilityId]
    if not o then
        if obsN >= 80 then return end
        local norm = CachedNorm(aName)
        if norm == "" then return end
        obs[abilityId] = { name = aName, norm = norm, last = now, lastOcc = now, n = 1, gaps = {}, fights = 1, fightMark = fightId }
        obsN = obsN + 1
        return
    end
    if now - o.last < 0.6 then o.last = now; return end -- 同じ発動の複数ヒット
    local gap = now - o.lastOcc
    o.last, o.lastOcc = now, now
    o.n = o.n + 1
    if #o.gaps >= 12 then table.remove(o.gaps, 1) end
    o.gaps[#o.gaps + 1] = gap
    if o.fightMark ~= fightId then o.fightMark = fightId; o.fights = o.fights + 1 end
    if o.n >= 8 then
        -- 短い間隔で何度も起きる(通常攻撃・DoT・連打スキル)は以後観察しない
        local mn = gap
        for _, g in ipairs(o.gaps) do if g < mn then mn = g end end
        if mn < LEARN_MIN_CD * 0.5 then
            ignoredIds[abilityId] = true
            obs[abilityId] = nil
            obsN = obsN - 1
            return
        end
    end
    if o.n >= 3 then EvaluateObs(abilityId, o) end
end

local function OnCombatEvent(_, result, _, aName, _, _, _, sType, _, _, _, _, _, _, _, _, abilityId)
    if sType ~= (COMBAT_UNIT_TYPE_PLAYER or 1) then return end
    if not VALID_RESULT[result] then return end
    -- 安全弁: 短時間に大量のイベントが来る場合は自動で停止する(軽量性の保証)
    evCount = evCount + 1
    if evCount >= 300 then
        local t = GetGameTimeSeconds()
        if t - evWindow < 2 then
            PTI.sv.cd.combatDetect = false
            PTI.sv.cd.autoLearn = false
            SyncCombat()
            d(TAG .. "戦闘イベントが多すぎるため、戦闘イベント方式と自動学習を自動でOFFにしました (/pti cd combat on, /pti cd auto on で再開)")
            return
        end
        evCount, evWindow = 0, t
    end
    if learnActive and type(abilityId) == "number" and type(aName) == "string" and aName ~= "" then
        ObserveCombat(aName, abilityId, GetGameTimeSeconds())
    end
    if PTI.sv.cd.combatDetect == false then return end
    local key, info = Resolve(aName, abilityId, (type(aName) == "string") and CachedNorm(aName) or "")
    if not key then return end
    if info.origin then return end
    if not info.byId and info.cd < MIN_CD_NAME then return end
    local now = GetGameTimeSeconds()
    OnProc(key, info, now, now)
end

local function UnregisterCombat()
    if combatOn then
        EVENT_MANAGER:UnregisterForEvent(EVT .. "Combat", EVENT_COMBAT_EVENT)
        combatOn = false
    end
    for id in pairs(idRegs) do
        EVENT_MANAGER:UnregisterForEvent(EVT .. "Ev" .. id, EVENT_COMBAT_EVENT)
        idRegs[id] = nil
    end
end

SyncCombat = function()
    local sv = PTI.sv
    local detect = running and sv and sv.cd and sv.cd.combatDetect ~= false
    local learn = running and sv and sv.cd and sv.cd.autoLearn ~= false and learnTargets
    learnActive = learn and true or false
    if not detect and not learn then UnregisterCombat(); return end
    BuildValidResults()
    local userIds = {}
    for id in pairs(sv.cd.userEv or {}) do
        local n = tonumber(id)
        if n then userIds[n] = true end
    end
    if learn or (detect and combatTargets) then
        -- 1本の登録で全て処理(名前一致・学習。AbilityId指定の登録は不要)
        for id in pairs(idRegs) do
            EVENT_MANAGER:UnregisterForEvent(EVT .. "Ev" .. id, EVENT_COMBAT_EVENT)
            idRegs[id] = nil
        end
        if not combatOn then
            combatOn = true
            evCount, evWindow = 0, GetGameTimeSeconds()
            EVENT_MANAGER:RegisterForEvent(EVT .. "Combat", EVENT_COMBAT_EVENT, OnCombatEvent)
            if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE then
                EVENT_MANAGER:AddFilterForEvent(EVT .. "Combat", EVENT_COMBAT_EVENT,
                    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
            end
        end
    else
        if combatOn then
            EVENT_MANAGER:UnregisterForEvent(EVT .. "Combat", EVENT_COMBAT_EVENT)
            combatOn = false
        end
        -- AbilityId指定の登録(登録IDだけがハンドラに届く)
        for id in pairs(idRegs) do
            if not userIds[id] then
                EVENT_MANAGER:UnregisterForEvent(EVT .. "Ev" .. id, EVENT_COMBAT_EVENT)
                idRegs[id] = nil
            end
        end
        for id in pairs(userIds) do
            if not idRegs[id] then
                idRegs[id] = true
                EVENT_MANAGER:RegisterForEvent(EVT .. "Ev" .. id, EVENT_COMBAT_EVENT, OnCombatEvent)
                EVENT_MANAGER:AddFilterForEvent(EVT .. "Ev" .. id, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, id)
                if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE then
                    EVENT_MANAGER:AddFilterForEvent(EVT .. "Ev" .. id, EVENT_COMBAT_EVENT,
                        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
                end
            end
        end
    end
end

--------------------------------------------------------------------------
-- 実機診断 /pti cd probe: PS5でイベントが届くか、能力名がセット名と一致するかを確かめる
--   一時的にだけイベントを登録し、既定60秒(最大180秒)で自動停止する。保存はしない。
--------------------------------------------------------------------------
local probe = { on = false, token = 0, combat = 0, effect = 0, cById = {}, cN = 0, eById = {}, eN = 0, nameHits = {} }

local function ProbeCombat(_, result, _, aName, _, _, _, sType, _, _, _, _, _, _, _, _, abilityId)
    probe.combat = probe.combat + 1
    if type(abilityId) ~= "number" then return end
    local r = probe.cById[abilityId]
    if not r then
        if probe.cN >= 80 then return end
        probe.cN = probe.cN + 1
        r = { name = aName, count = 0, result = result, sType = sType }
        probe.cById[abilityId] = r
    end
    r.count = r.count + 1
    if type(aName) == "string" then
        local nm = CachedNorm(aName)
        if equippedSets[nm] then probe.nameHits[nm] = (probe.nameHits[nm] or 0) + 1 end
    end
end

local function ProbeEffect(_, change, _, auraName, _, _, _, _, _, _, _, _, _, _, _, abilityId)
    probe.effect = probe.effect + 1
    if type(abilityId) ~= "number" then return end
    local r = probe.eById[abilityId]
    if not r then
        if probe.eN >= 60 then return end
        probe.eN = probe.eN + 1
        r = { name = auraName, count = 0 }
        probe.eById[abilityId] = r
    end
    r.count = r.count + 1
end

local function StopProbe()
    if not probe.on then return end
    probe.on = false
    EVENT_MANAGER:UnregisterForEvent(EVT .. "ProbeC", EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForEvent(EVT .. "ProbeE", EVENT_EFFECT_CHANGED)
end

local function StartProbe(seconds)
    StopProbe()
    if equippedDirty then RescanEquipped() end
    probe.combat, probe.effect, probe.cN, probe.eN = 0, 0, 0, 0
    probe.cById, probe.eById, probe.nameHits = {}, {}, {}
    probe.on = true
    probe.token = probe.token + 1
    local tk = probe.token
    EVENT_MANAGER:RegisterForEvent(EVT .. "ProbeC", EVENT_COMBAT_EVENT, ProbeCombat)
    if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE then
        EVENT_MANAGER:AddFilterForEvent(EVT .. "ProbeC", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    end
    EVENT_MANAGER:RegisterForEvent(EVT .. "ProbeE", EVENT_EFFECT_CHANGED, ProbeEffect)
    if REGISTER_FILTER_UNIT_TAG then
        EVENT_MANAGER:AddFilterForEvent(EVT .. "ProbeE", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    end
    zo_callLater(function()
        if probe.on and probe.token == tk then
            StopProbe()
            d(TAG .. "診断を終了しました。/pti cd probe show で結果を確認してください。")
        end
    end, seconds * 1000)
end

--------------------------------------------------------------------------
-- 表示
--------------------------------------------------------------------------
local function SortList(a, b)
    if a.ready ~= b.ready then return not a.ready end
    if not a.ready then return a.remain < b.remain end
    return a.name < b.name
end

local function SetRow(row, name, timeText, isReady)
    local mode = isReady and 2 or 1
    if row.cdMode ~= mode or not row.cdInit then
        row.nameLabel:SetFont(PTI.UI.RowFont("cd"))
        row.timeLabel:SetFont(PTI.UI.RowFont("cd"))
        PTI.UI.ApplyOutline(row.nameLabel)
        PTI.UI.ApplyOutline(row.timeLabel)
        row.nameLabel:SetColor(COLOR_WHITE[1], COLOR_WHITE[2], COLOR_WHITE[3], 1)
        local c = isReady and COLOR_GREEN or COLOR_YELLOW
        row.timeLabel:SetColor(c[1], c[2], c[3], 1)
        row.cdMode, row.cdInit = mode, true
    end
    if row.cdName ~= name then row.nameLabel:SetText(name); row.cdName = name end
    if row.cdTime ~= timeText then row.timeLabel:SetText(timeText); row.cdTime = timeText end
end

local function Render(now)
    local sv = PTI.sv.cdUI
    local maxRows = sv.maxRows or 6
    local showReady = PTI.sv.cd.showReady ~= false
    local index = 0

    if PTI.sv.previewMode then
        -- 位置確認用サンプル(実際のCD値ではない)
        local samples = {
            { "サンプルA", "12.4", false }, { "サンプルB", "5.8", false }, { "サンプルC", READY_TEXT, true },
        }
        for _, s in ipairs(samples) do
            if index < maxRows then
                index = index + 1
                SetRow(PTI.UI.AcquireRow("cd", index), s[1], s[2], s[3])
            end
        end
    else
        listCount = 0
        for key, st in pairs(states) do
            local remain = st.endAt - now
            if remain <= 0 then st.ready = true end
            if st.ready and not showReady then
                states[key] = nil
            else
                listCount = listCount + 1
                local item = list[listCount]
                if not item then item = {}; list[listCount] = item end
                item.name, item.ready, item.remain = st.name, st.ready, remain
            end
        end
        for i = listCount + 1, #list do list[i] = nil end
        if listCount > 1 then table.sort(list, SortList) end
        for i = 1, listCount do
            if index < maxRows then
                index = index + 1
                local item = list[i]
                local row = PTI.UI.AcquireRow("cd", index)
                if item.ready then
                    SetRow(row, item.name, READY_TEXT, true)
                else
                    SetRow(row, item.name, string.format("%.1f", item.remain), false)
                end
            end
        end
    end

    PTI.UI.ReleaseUnusedRows("cd", index + 1)
    local has = index > 0
    PTI.UI.cdHasContent = has
    if has ~= lastHasContent then
        lastHasContent = has
        PTI.UI.SetWindowVisible("cd")
    end
end

--------------------------------------------------------------------------
-- 表示モード: "always"(常時表示・既定) / "combat"(戦闘終了後は非表示)
--   戦闘の出入りはEVENT_PLAYER_COMBAT_STATE(イベント駆動)で判定する。
--   戦闘終了から猶予(CMB_GRACE秒)の間に再戦闘すれば隠さない。隠すのは表示だけで、
--   CD計測・学習・検知は止めない。隠れている間は行の更新(Render)を行わない。
--------------------------------------------------------------------------
local function SetCdHidden(flag)
    flag = flag and true or false
    if (PTI.UI.cdHiddenAfterCombat and true or false) == flag then return end
    PTI.UI.cdHiddenAfterCombat = flag
    lastHasContent = nil
    PTI.UI.SetWindowVisible("cd")
    if not flag and running then Render(GetGameTimeSeconds()) end
end

local function CurrentInCombat()
    if IsUnitInCombat then return IsUnitInCombat("player") and true or false end
    return inCombatNow
end

local function ApplyCdMode()
    local mode = PTI.sv and PTI.sv.cdUI and PTI.sv.cdUI.displayMode
    hideToken = hideToken + 1
    if running and mode == "combat" and not PTI.sv.previewMode and not CurrentInCombat() then
        SetCdHidden(true)
    else
        SetCdHidden(false)
    end
end

local function OnCombatState(_, inCombat)
    inCombatNow = inCombat and true or false
    if inCombatNow then
        fightId = fightId + 1
        hideToken = hideToken + 1
        if PTI.UI.cdHiddenAfterCombat then SetCdHidden(false) end
    elseif PTI.sv.cdUI.displayMode == "combat" then
        hideToken = hideToken + 1
        local tk = hideToken
        zo_callLater(function()
            if tk == hideToken and running and not CurrentInCombat() and PTI.sv.cdUI.displayMode == "combat"
                and not PTI.sv.previewMode then
                SetCdHidden(true)
            end
        end, CMB_GRACE * 1000)
    end
end

local function OnTick()
    local now = GetGameTimeSeconds()
    if equippedDirty then RescanEquipped() end
    tickCount = tickCount + 1
    if tickCount % SCAN_EVERY == 0 and not PTI.sv.previewMode then ScanBuffs(now) end
    if PTI.UI.cdHiddenAfterCombat and not PTI.sv.previewMode then return end -- 非表示中は表示更新しない
    if listCount > 0 or next(states) ~= nil or PTI.sv.previewMode or lastHasContent then
        Render(now)
    end
end

local function OnEquipEvent()
    equippedDirty = true
end

local function OnActivated()
    equippedDirty = true
    baselineNext = true
    ZO_ClearTable(pending)
    inCombatNow = CurrentInCombat()
    ApplyCdMode()
end

--------------------------------------------------------------------------
-- 開始・停止(パネルOFF/アドオンOFFの間は全て解除して負荷ゼロにする)
--------------------------------------------------------------------------
local function Start()
    if running then return end
    running = true
    RebuildIndex()
    equippedDirty = true
    baselineNext = true
    tickCount = 0
    lastHasContent = nil
    EVENT_MANAGER:RegisterForEvent(EVT .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnEquipEvent)
    EVENT_MANAGER:AddFilterForEvent(EVT .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    EVENT_MANAGER:RegisterForEvent(EVT .. "Act", EVENT_PLAYER_ACTIVATED, OnActivated)
    if EVENT_ARMORY_BUILD_RESTORE_RESPONSE then -- 存在未確認のため有る時だけ登録
        EVENT_MANAGER:RegisterForEvent(EVT .. "Armory", EVENT_ARMORY_BUILD_RESTORE_RESPONSE, OnEquipEvent)
    end
    EVENT_MANAGER:RegisterForEvent(EVT .. "Cmb", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    inCombatNow = CurrentInCombat()
    EVENT_MANAGER:RegisterForUpdate(EVT .. "Tick", TICK_MS, OnTick)
    SyncCombat()
    ApplyCdMode()
end

local function Stop()
    if not running then return end
    running = false
    EVENT_MANAGER:UnregisterForUpdate(EVT .. "Tick")
    EVENT_MANAGER:UnregisterForEvent(EVT .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(EVT .. "Act", EVENT_PLAYER_ACTIVATED)
    if EVENT_ARMORY_BUILD_RESTORE_RESPONSE then
        EVENT_MANAGER:UnregisterForEvent(EVT .. "Armory", EVENT_ARMORY_BUILD_RESTORE_RESPONSE)
    end
    EVENT_MANAGER:UnregisterForEvent(EVT .. "Cmb", EVENT_PLAYER_COMBAT_STATE)
    hideToken = hideToken + 1
    PTI.UI.cdHiddenAfterCombat = false
    UnregisterCombat()
    StopProbe()
    learnActive, learnTargets = false, false
    ZO_ClearTable(obs); obsN = 0
    ZO_ClearTable(ignoredIds)
    combatTargets = false
    ZO_ClearTable(states)
    ZO_ClearTable(pending)
    ZO_ClearTable(baselineKeys)
    ZO_ClearTable(presentPrev)
    ZO_ClearTable(presentNow)
    learning = false
    listCount = 0
    lastHasContent = false
    PTI.UI.cdHasContent = false
    if PTI.UI.GetWindow("cd") then PTI.UI.ReleaseUnusedRows("cd", 1) end
end

-- 全体ON/OFFとUI④のON/OFFから現在の状態へ合わせる(何度呼んでも安全)
function CD.Sync()
    local sv = PTI.sv
    local want = sv and sv.enabled and sv.cdUI and sv.cdUI.enabled ~= false
    if want then Start() else Stop() end
end

function CD.ApplyDisplayMode() if running then ApplyCdMode() end end
function CD.SyncCombat() SyncCombat() end

function CD.Initialize()
    if PTI.sv and PTI.sv.cd then
        if type(PTI.sv.cd.alias) ~= "table" then PTI.sv.cd.alias = {} end
        if type(PTI.sv.cd.userEv) ~= "table" then PTI.sv.cd.userEv = {} end
        if type(PTI.sv.cd.learned) ~= "table" then PTI.sv.cd.learned = {} end
        if type(PTI.sv.cd.learnIgnore) ~= "table" then PTI.sv.cd.learnIgnore = {} end
    end
    CD.Sync()
end

--------------------------------------------------------------------------
-- チャットコマンド /pti cd ...
--------------------------------------------------------------------------
local function SetsForCommand(filter)
    local sets = CollectSets()
    for i, s in ipairs(sets) do s.idx = i end
    if not filter or filter == "" then return sets end
    local n = tonumber(filter)
    local out = {}
    if n then
        if sets[n] then out[1] = sets[n] end
    else
        local f = zo_strlower(filter)
        for _, s in ipairs(sets) do
            if s.norm:find(f, 1, true) then out[#out + 1] = s end
        end
    end
    return out
end

-- /pti cd text [番号|セット名]: 装備中の全セットの全ボーナス説明文を全文表示(ICD判定とは無関係)
local function CmdText(filter)
    local sets = SetsForCommand(filter)
    if #sets == 0 then
        Out(TAG .. "対象の装備セットが見つかりません。/pti cd sets で番号を確認してください。")
        return
    end
    local okTotal, failTotal = 0, 0
    local failLines = {}
    Out(TAG .. string.format("装備セットの説明文 (対象 %d セット)", #sets))
    for _, s in ipairs(sets) do
        Out("[" .. ChatEsc(s.name) .. "]  #" .. s.idx)
        local bonuses, fails = FetchBonuses(s)
        okTotal = okTotal + #bonuses
        failTotal = failTotal + #fails
        if #bonuses == 0 and #fails == 0 then Out("  (ボーナスなし)") end
        for _, b in ipairs(bonuses) do
            local label = string.format("%dアイテム：", b.req)
            local lines = WrapText(CleanDesc(b.desc))
            for k, ln in ipairs(lines) do
                Out((k == 1 and label or "　　") .. ChatEsc(ln))
            end
        end
        for _, f in ipairs(fails) do
            local where = (f.idx > 0) and string.format("ボーナス#%d", f.idx) or "全体"
            local line = string.format("  ※取得失敗 %s: %s", where, f.reason)
            Out(line)
            failLines[#failLines + 1] = string.format("%s / %s / %s", ChatEsc(s.name), where, f.reason)
        end
    end
    Out(TAG .. string.format("説明文 取得成功 %d件 / 取得失敗 %d件", okTotal, failTotal))
    for _, l in ipairs(failLines) do Out("  失敗: " .. l) end
end

-- /pti cd icd [番号|セット名]: 説明文からICD候補を分析(取得とは別処理)
local function CmdIcd(filter)
    local sets = SetsForCommand(filter)
    if #sets == 0 then
        Out(TAG .. "対象の装備セットが見つかりません。/pti cd sets で番号を確認してください。")
        return
    end
    EnsureIndex()
    Out(TAG .. "ICD候補の分析 (数字があるだけではICDと断定しません)")
    for _, s in ipairs(sets) do
        Out("[" .. ChatEsc(s.name) .. "]  #" .. s.idx)
        local bonuses, fails = FetchBonuses(s)
        local all, counts = {}, {}
        for _, b in ipairs(bonuses) do
            for _, it in ipairs(AnalyzeDesc(b.desc)) do
                all[#all + 1] = it
                counts[it.kind] = counts[it.kind] or {}
                counts[it.kind][#counts[it.kind] + 1] = it
                if it.kind == "ICD" or it.kind == "INTERVAL" then
                    local lines = WrapText(it.text)
                    local label = string.format("  %dアイテム %s %s秒：", b.req, KIND_LABEL[it.kind], tostring(it.sec))
                    for k, ln in ipairs(lines) do Out((k == 1 and label or "　　") .. ChatEsc(ln)) end
                end
            end
        end
        local others = {}
        for _, kind in ipairs(KIND_ORDER) do
            if kind ~= "ICD" and kind ~= "INTERVAL" and counts[kind] then
                local secs = {}
                for _, it in ipairs(counts[kind]) do secs[#secs + 1] = tostring(it.sec) end
                others[#others + 1] = KIND_LABEL[kind] .. " " .. table.concat(secs, "/") .. "秒"
            end
        end
        if #others > 0 then Out("  その他の時間: " .. table.concat(others, " , ")) end
        local v, why = PickIcd(all)
        local def = entryByName[s.norm]
        local dbText = ""
        if def then
            dbText = def.cd and string.format(" / 定義表 %.1f秒[%s]", def.cd, def.status) or string.format(" / 定義表 %s", def.status)
        end
        Out(string.format("  判定: %s%s%s", v and (tostring(v) .. "秒(" .. why .. ")") or why, dbText, (#fails > 0) and " / 説明文取得失敗あり" or ""))
    end
end

local DETECT_LABEL = {
    BUFF = "バフ走査(バフ名/IDが一致すれば可)",
    COMBAT = "戦闘イベント名一致(PS5未検証)",
    TARGET = "対象ごとCDのため不可",
    NONE = "対象外",
    UNVERIFIED = "不明",
}

local function CmdSets()
    EnsureIndex()
    local sets = SetsForCommand(nil)
    if #sets == 0 then Out(TAG .. "装備中のセットが見つかりません。"); return end
    Out(TAG .. string.format("装備中のセット %d 件", #sets))
    for _, s in ipairs(sets) do
        local def = entryByName[s.norm]
        local bonuses = FetchBonuses(s)
        local items = {}
        for _, b in ipairs(bonuses) do for _, it in ipairs(AnalyzeDesc(b.desc)) do items[#items + 1] = it end end
        local tipCd, why = PickIcd(items)
        local src
        if def and type(def.cd) == "number" then
            src = string.format("%.1f秒 [%s] key=%s 検知:%s", def.cd, def.status, def.key, DETECT_LABEL[def.detect or ""] or "?")
        elseif def then
            src = string.format("定義あり[%s] key=%s (定義表のICDなし)", def.status, def.key)
        else
            src = "定義表に該当なし"
        end
        if tipCd then src = src .. string.format(" / 説明文解析 %.1f秒(PS5実機未検証)", tipCd) else src = src .. " / 説明文解析: " .. why end
        Out(string.format(" #%d %s : %s", s.idx, ChatEsc(s.name), src))
    end
end

local function CmdBuffs()
    local n = GetNumBuffs("player") or 0
    Out(TAG .. string.format("自分のバフ %d 件 (名前 / AbilityId / 持続 / スタック)", n))
    for i = 1, math.min(n, 40) do
        local name, st, et, _, stacks, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
        if type(name) == "string" and name ~= "" then
            local dur = (type(st) == "number" and type(et) == "number" and et > st) and string.format("%.1f秒", et - st) or "-"
            Out(string.format(" %s / %s / %s / x%s", ChatEsc(zo_strformat("<<t:1>>", name)), tostring(id), dur, tostring(stacks or 0)))
        end
    end
end

local function CmdLearn(arg)
    arg = (arg or ""):lower()
    if arg == "on" then
        if not running then
            Out(TAG .. "UI④がOFFのため学習できません。/pti cd on にしてください。")
            return
        end
        learning = true
        ZO_ClearTable(learned); ZO_ClearTable(learnBase); learnCount = 0
        for i = 1, (GetNumBuffs("player") or 0) do
            local _, _, _, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
            if type(id) == "number" then learnBase[id] = true end
        end
        Out(TAG .. "学習モードON。今付いているバフは除外し、新しく付いたバフを記録します(最大40件・ログアウトで消えます)。")
        Out("  Procが発動したら /pti cd learn show で確認し、/pti cd add <AbilityId> <ICD秒> で登録できます。")
    elseif arg == "off" then
        learning = false
        Out(TAG .. "学習モードOFF (記録は /pti cd learn show で確認できます)")
    elseif arg == "clear" then
        ZO_ClearTable(learned); learnCount = 0
        Out(TAG .. "学習記録を消去しました。")
    elseif arg == "show" then
        local ids = {}
        for id in pairs(learned) do ids[#ids + 1] = id end
        table.sort(ids)
        Out(TAG .. string.format("学習記録 %d 件 (AbilityId / 名前 / 持続 / 最大スタック / 更新回数)", #ids))
        for _, id in ipairs(ids) do
            local l = learned[id]
            Out(string.format(" %d / %s / %s / x%d / %d回", id, ChatEsc(zo_strformat("<<t:1>>", l.name)),
                (l.dur > 0) and string.format("%.1f秒", l.dur) or "-", l.maxStack, l.seen))
        end
        Out("  装備セットのICD候補は /pti cd icd で確認できます。")
    else
        Out(TAG .. "/pti cd learn on||off||show||clear  - 新しく付いた自分のバフのAbilityIdを記録")
    end
end


--------------------------------------------------------------------------
-- 自動学習の状況表示とコマンド /pti cd auto ...
--------------------------------------------------------------------------
local function SortedCandidates()
    local list = {}
    for id, r in pairs(LearnedTable()) do
        if type(r) == "table" and r.conf == "CAND" then list[#list + 1] = { id = tonumber(id) or 0, r = r } end
    end
    table.sort(list, function(a, b)
        if (a.r.score or 0) ~= (b.r.score or 0) then return (a.r.score or 0) > (b.r.score or 0) end
        if (a.r.n or 0) ~= (b.r.n or 0) then return (a.r.n or 0) > (b.r.n or 0) end
        return a.id < b.id
    end)
    return list
end

function CD.PrintAutoStatus()
    local sets, ids, cands = {}, 0, 0
    local nSets = 0
    for _, r in pairs(LearnedTable()) do
        if type(r) == "table" then
            if r.conf == "AUTO" or r.conf == "ACCEPTED" then
                ids = ids + 1
                if r.setKey and not sets[r.setKey] then sets[r.setKey] = true; nSets = nSets + 1 end
            elseif r.conf == "CAND" then
                cands = cands + 1
            end
        end
    end
    Out(TAG .. string.format("自動学習: %s / 監視: %s", (PTI.sv.cd.autoLearn ~= false) and "ON" or "OFF", learnActive and "動作中" or "停止"))
    Out(string.format("  学習済みセット %d / 学習済みAbilityId %d / 未確認の候補 %d", nSets, ids, cands))
    Out(string.format("  現在の学習対象セット(装備中でICD確定) %d 件 / アクションバー判定: %s", #learnSets, barKnown and "可" or "不可(PS5未確認のAPI)"))
    Out("  詳細: /pti cd auto list  候補を確定: /pti cd auto accept <番号>")
end

local function CmdAuto(args)
    local sub, rest = args:match("^(%S*)%s*(.-)$")
    sub = (sub or ""):lower()
    if sub == "on" or sub == "off" then
        PTI.sv.cd.autoLearn = (sub == "on")
        SyncCombat()
        Out(TAG .. "自動学習: " .. sub:upper() .. "  (PS5実機未検証)")
    elseif sub == "list" then
        local autos = {}
        for id, r in pairs(LearnedTable()) do
            if type(r) == "table" and (r.conf == "AUTO" or r.conf == "ACCEPTED") then autos[#autos + 1] = { id = tonumber(id) or 0, r = r } end
        end
        table.sort(autos, function(a, b) return a.id < b.id end)
        Out(TAG .. string.format("学習済み(検知に使用) %d 件", #autos))
        for i = 1, math.min(#autos, 12) do
            local r = autos[i].r
            Out(string.format(" [%s] %d / %s -> %s / %.1f秒 / 信頼度%s / %d回・%d戦闘", r.conf == "AUTO" and "自動" or "確定",
                autos[i].id, ChatEsc(zo_strformat("<<t:1>>", r.name or "")), ChatEsc(r.setName or "?"), r.cd or 0, Confidence(r), r.n or 0, r.fights or 0))
        end
        local cands = SortedCandidates()
        Out(TAG .. string.format("候補(検知には使っていません) %d 件", #cands))
        for i = 1, math.min(#cands, 12) do
            local r = cands[i].r
            Out(string.format(" #%d %d / %s -> %s / %.1f秒 / 信頼度%s / %d回・%d戦闘 / 一致:%s", i,
                cands[i].id, ChatEsc(zo_strformat("<<t:1>>", r.name or "")), ChatEsc(r.setName or "?"), r.cd or 0, Confidence(r),
                r.n or 0, r.fights or 0, r.nameEv and "あり" or "なし"))
        end
    elseif sub == "accept" or sub == "reject" then
        local n = tonumber(rest)
        local cands = SortedCandidates()
        local c = n and cands[n]
        if not c then
            Out(TAG .. "候補の番号を /pti cd auto list で確認してください。例: /pti cd auto " .. sub .. " 1")
        elseif sub == "accept" then
            c.r.conf = "ACCEPTED"
            RebuildIndex()
            Out(TAG .. string.format("確定しました: %d %s -> %s", c.id, ChatEsc(zo_strformat("<<t:1>>", c.r.name or "")), ChatEsc(c.r.setName or "?")))
        else
            LearnedTable()[c.id] = nil
            PTI.sv.cd.learnIgnore[c.id] = true
            obs[c.id] = nil
            Out(TAG .. string.format("候補を除外しました(今後学習しません): %d", c.id))
        end
    elseif sub == "clear" then
        ZO_ClearTable(LearnedTable())
        ZO_ClearTable(PTI.sv.cd.learnIgnore)
        ZO_ClearTable(obs); obsN = 0
        ZO_ClearTable(ignoredIds)
        RebuildIndex()
        Out(TAG .. "学習記録を全て消去しました(手動登録・定義表は残ります)。")
    else
        CD.PrintAutoStatus()
    end
end

function CD.HandleCommand(rest)
    rest = rest or ""
    local sub, args = rest:match("^(%S*)%s*(.-)$")
    sub = (sub or ""):lower()

    if sub == "on" or sub == "off" then
        PTI.sv.cdUI.enabled = (sub == "on")
        CD.Sync()
        PTI.UI.RefreshVisibility()
        Out(TAG .. "UI④(Proc CD): " .. sub:upper())
    elseif sub == "sets" then
        CmdSets()
    elseif sub == "text" then
        CmdText(args)
    elseif sub == "icd" then
        CmdIcd(args)
    elseif sub == "buffs" then
        CmdBuffs()
    elseif sub == "learn" then
        CmdLearn(args)
    elseif sub == "alias" then
        local key, name = args:match("^(%S+)%s+(.+)$")
        local byKey = PTI.CDData and PTI.CDData.byKey or {}
        if args:match("^del%s+") then
            local nm = args:match("^del%s+(.+)$")
            if nm and PTI.sv.cd.alias[nm] then
                PTI.sv.cd.alias[nm] = nil
                RebuildIndex()
                Out(TAG .. "別名を削除しました: " .. ChatEsc(nm))
            else
                Out(TAG .. "例: /pti cd alias del 機械的精度")
            end
        elseif key and name and byKey[key] then
            PTI.sv.cd.alias[name] = key
            RebuildIndex()
            equippedDirty = true
            Out(TAG .. string.format("セット名「%s」を定義 %s に対応付けました。", ChatEsc(name), key))
        else
            Out(TAG .. "例: /pti cd alias <key> <日本語セット名>   (key は /pti cd list で確認)")
            for nm, k in pairs(PTI.sv.cd.alias) do Out(string.format(" - %s -> %s", ChatEsc(nm), tostring(k))) end
        end
    elseif sub == "auto" then
        CmdAuto(args)
    elseif sub == "combat" then
        local a = args:lower()
        if a == "on" or a == "off" then
            PTI.sv.cd.combatDetect = (a == "on")
            SyncCombat()
            Out(TAG .. "戦闘イベント方式: " .. a:upper() .. "  (PS5実機未検証。/pti cd probe で確認できます)")
        else
            Out(TAG .. string.format("戦闘イベント方式: %s / 登録中: %s  例: /pti cd combat on||off",
                (PTI.sv.cd.combatDetect ~= false) and "ON" or "OFF", (combatOn or next(idRegs)) and "はい" or "いいえ"))
        end
    elseif sub == "probe" then
        local a = args:lower()
        if a == "show" then
            Out(TAG .. string.format("診断結果 (%s): 戦闘イベント(自分発) %d件 / エフェクトイベント(自分) %d件",
                probe.on and "計測中" or "停止", probe.combat, probe.effect))
            if probe.combat == 0 then Out("  戦闘イベント: 届いていません(戦闘して技を使った後に確認してください)") end
            if probe.effect == 0 then Out("  エフェクトイベント: 届いていません(バフが付く行動をした後に確認してください)") end
            local ids = {}
            for id in pairs(probe.cById) do ids[#ids + 1] = id end
            table.sort(ids, function(x, y) return probe.cById[x].count > probe.cById[y].count end)
            for i = 1, math.min(#ids, 12) do
                local r = probe.cById[ids[i]]
                Out(string.format("  [戦] %d / %s / %d回 / 結果コード%s", ids[i], ChatEsc(zo_strformat("<<t:1>>", r.name or "")), r.count, tostring(r.result)))
            end
            local eids = {}
            for id in pairs(probe.eById) do eids[#eids + 1] = id end
            table.sort(eids, function(x, y) return probe.eById[x].count > probe.eById[y].count end)
            for i = 1, math.min(#eids, 6) do
                local r = probe.eById[eids[i]]
                Out(string.format("  [効] %d / %s / %d回", eids[i], ChatEsc(zo_strformat("<<t:1>>", r.name or "")), r.count))
            end
            local any = false
            for nm, c in pairs(probe.nameHits) do
                any = true
                Out(string.format("  セット名と一致した戦闘イベント: %s %d件", ChatEsc(equippedSets[nm] and equippedSets[nm].name or nm), c))
            end
            if not any then Out("  セット名と一致した戦闘イベント: なし(Procが発動していない、または名前が一致しない)") end
        elseif a == "off" then
            StopProbe()
            Out(TAG .. "診断を停止しました。")
        else
            if not running then
                Out(TAG .. "UI④がOFFのため診断できません。/pti cd on にしてください。")
            else
                local sec = tonumber(a) or 60
                if sec < 10 then sec = 10 elseif sec > 180 then sec = 180 end
                StartProbe(sec)
                Out(TAG .. string.format("診断開始(%d秒で自動停止)。装備セットのProcが出る戦闘をしてから /pti cd probe show を実行してください。", sec))
            end
        end
    elseif sub == "addev" then
        local idStr, secStr, name = args:match("^(%d+)%s+([%d%.]+)%s*(.-)$")
        local id, sec = tonumber(idStr), tonumber(secStr)
        if id and sec and sec > 0 and sec <= 300 then
            PTI.sv.cd.userEv[id] = { cd = sec, name = (name ~= "" and name) or nil }
            RebuildIndex()
            SyncCombat()
            Out(TAG .. string.format("戦闘イベントのAbilityId %d = %.1f秒 を登録(自分発の戦闘イベントでCD開始)", id, sec))
        else
            Out(TAG .. "例: /pti cd addev 12345 8 セット名  (probeの[戦]で出たAbilityId・ICD秒数・表示名)")
        end
    elseif sub == "delev" then
        local id = tonumber(args)
        if id and PTI.sv.cd.userEv[id] then
            PTI.sv.cd.userEv[id] = nil
            RebuildIndex()
            SyncCombat()
            Out(TAG .. "削除しました: " .. id)
        else
            Out(TAG .. "例: /pti cd delev 12345")
        end
    elseif sub == "add" then
        local idStr, secStr, name = args:match("^(%d+)%s+([%d%.]+)%s*(.-)$")
        local id, sec = tonumber(idStr), tonumber(secStr)
        if id and sec and sec > 0 and sec <= 300 then
            PTI.sv.cd.user[id] = { cd = sec, name = (name ~= "" and name) or nil }
            RebuildIndex()
            Out(TAG .. string.format("Proc CDを登録: AbilityId %d = %.1f秒 (実測値として扱います)", id, sec))
        else
            Out(TAG .. "例: /pti cd add 12345 8 セット名  (AbilityId・ICD秒数・表示名(省略可)。ICDは実際に測った秒数)")
        end
    elseif sub == "del" then
        local id = tonumber(args)
        if id and PTI.sv.cd.user[id] then
            PTI.sv.cd.user[id] = nil
            RebuildIndex()
            Out(TAG .. "削除しました: " .. id)
        else
            Out(TAG .. "例: /pti cd del 12345")
        end
    elseif sub == "list" then
        local n = 0
        for id, u in pairs(PTI.sv.cd.user) do
            n = n + 1
            Out(TAG .. string.format(" - [登録] %s / AbilityId %s / %.1f秒", ChatEsc(tostring(u.name or GetAbilityName(tonumber(id)) or "?")), tostring(id), u.cd or 0))
        end
        for id, u in pairs(PTI.sv.cd.userEv) do
            n = n + 1
            Out(TAG .. string.format(" - [登録・戦闘] %s / AbilityId %s / %.1f秒", ChatEsc(tostring(u.name or GetAbilityName(tonumber(id)) or "?")), tostring(id), u.cd or 0))
        end
        local entries = PTI.CDData and PTI.CDData.entries or {}
        Out(TAG .. string.format("定義表 %d 件 (key / セット名 / ICD / 状態 / 検知見込み)", #entries))
        for _, e in ipairs(entries) do
            n = n + 1
            local cdText = (type(e.cd) == "number") and string.format("%.1f秒", e.cd) or "未確認"
            Out(string.format(" - %s / %s / %s [%s] %s", e.key, e.names and e.names[1] or "?", cdText, e.status or "UNKNOWN", e.detect or ""))
        end
    elseif sub == "reset" then
        ZO_ClearTable(states)
        ZO_ClearTable(pending)
        Out(TAG .. "表示中のProc CDをリセットしました。")
    else
        Out(TAG .. "/pti cd on||off  - UI④(Proc CD)のON/OFF")
        Out(TAG .. "/pti cd sets     - 装備中セットとICDの出所")
        Out(TAG .. "/pti cd text [番号か名前] - 装備セットの全ボーナス説明文を全文表示(取得成功/失敗数つき)")
        Out(TAG .. "/pti cd icd [番号か名前]  - 説明文からICD候補を分析")
        Out(TAG .. "/pti cd buffs    - 今付いている自分のバフ一覧(AbilityId付き)")
        Out(TAG .. "/pti cd learn on||off||show||clear - 新しく付いたバフのAbilityIdを記録")
        Out(TAG .. "/pti cd probe [秒] / probe show - 戦闘/エフェクトイベントがPS5で届くかの診断(自動停止)")
        Out(TAG .. "/pti cd auto [on||off||list||accept N||reject N||clear] - Procの自動学習の状況・操作")
        Out(TAG .. "/pti cd combat on||off - 戦闘イベント方式(バフが付かないProc向け)")
        Out(TAG .. "/pti cd add <AbilityId> <秒> [名前] / del <AbilityId> / list - 実測ICDの登録(バフ)")
        Out(TAG .. "/pti cd addev <AbilityId> <秒> [名前] / delev <AbilityId> - 戦闘イベント側の登録")
        Out(TAG .. "/pti cd alias <key> <日本語セット名> - 定義表と日本語セット名の対応付け")
        Out(TAG .. "/pti cd reset    - 表示中のCDをリセット")
    end
end

-- テスト用に内部関数を公開(ゲーム動作には影響しない)
CD._test = {
    AnalyzeDesc = AnalyzeDesc, PickIcd = PickIcd, WrapText = WrapText, SplitSentences = SplitSentences,
    CharCount = CharCount, CollectSets = CollectSets, FetchBonuses = FetchBonuses, ScanBuffs = ScanBuffs,
    RebuildIndex = RebuildIndex, RescanEquipped = RescanEquipped, states = states, pending = pending,
    FlushOut = FlushOut, ObserveCombat = ObserveCombat, learnSets = learnSets, obs = obs,
    SetFight = function(n) fightId = n end, GetFight = function() return fightId end,
    OnCombatState = OnCombatState, SyncCombat = function() SyncCombat() end,
    OnCombatEventForTest = function(...) return OnCombatEvent(...) end,
}
