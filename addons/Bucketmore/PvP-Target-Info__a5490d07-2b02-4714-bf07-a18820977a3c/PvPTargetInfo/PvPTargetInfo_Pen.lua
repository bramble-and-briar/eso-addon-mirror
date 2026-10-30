--[[
    PvPTargetInfo_Pen.lua  (v2.0.5で新規追加 / v2.0.8でAbilityId手動登録を廃止し自動検知へ)

    UI④「貫通・敵耐性低下パネル」。PenTest(Solinur作, Artistic License 2.0)の
    「自分の貫通値はAPIから読み、敵の耐性低下は敵に付いている効果から集計する」
    という考え方だけを参考にした独自実装で、PenTestのコードは一切コピーしていない。

    ■ 取得できるもの / できないもの(PS5/コンソールを前提に、確認できた範囲だけ)
      [自分の貫通]  GetPlayerStat(STAT_PHYSICAL_PENETRATION / STAT_SPELL_PENETRATION,
                    STAT_BONUS_OPTION_APPLY_BONUS) で武器貫通・呪文貫通を別々に読む。
                    存在しない/失敗した場合は「取得不可」と表示し、値を捏造しない。
      [敵の耐性低下] 敵(reticleover)に付いているデバフを GetNumBuffs/GetUnitBuffInfo で
                    読み、そのabilityId(言語に依存しない数値)を下のEFFECT_TABLEと照合する。
                    効果の「残り時間」はAPIのendTimeから算出する実測値。
      [取得できない] ・敵の基礎耐性(装備由来の耐性)や「残り耐性」:取得手段が確認できない
                      ため一切表示しない。
                    ・耐性低下量そのもの:ESOのAPIには「この効果は耐性を何ポイント下げるか」を
                      返す関数が無い(PenTest自身も効果ごとの値を内蔵している)。量は公開
                      データ(ESO-Hub/UESP等、2026年9月のUpdate 51時点でMajor=5948 / Minor=2974)
                      に基づく固定値で、APIから読んだ値ではない。パッチで変わったら
                      EFFECT_TABLEの数値を直す必要がある。
                    ・Crusher/Alkosh:エンチャントの品質等で量が変わり、現行値を一次情報で
                      確認できなかったため、量は表示せず合計にも含めない(「検知のみ」)。

    ■ 判定方法(手動登録なし)
      ① EFFECT_TABLE: Major/Minor Breach等のabilityId(公開IDリスト由来)と一致 → 確定
      ② 補助判定(既定ON): ①に無いデバフの説明文(GetAbilityDescription)に 5948 / 2974 が
         数字として含まれる → 「(推定)」を付けて表示。言語に依存しない数値比較。
         ①で確認できた場合は①を優先し、推定は重複して数えない。
      表示名による判定は言語依存のため行わない。

    ■ 重複ルール(実際のゲーム仕様に従う)
      ・同名の効果(例: Major Breachが複数の味方から付与)は互いに重ならない → 1回分だけ数える
        (残り時間は一番長いもの)。
      ・Major BreachとMinor Breachは別名の効果なので重なる → 両方加算(合計8922)。
      ・Crusher等の別系統の低下もBreachと重なる(本パネルでは量不明のため加算しない)。

    ■ 負荷方針
      ・パネルがOFFの間は250msスキャンもイベント購読も一切登録しない(Sync参照)。
      ・ON時も、メニュー/マップ表示中・敵プレイヤー以外のターゲット中は何も読まない。
      ・スキャン結果は毎回ゼロから作り直す(前の敵の情報が残らない)。
--]]

PvPTargetInfo = PvPTargetInfo or {}
local PTI = PvPTargetInfo
PTI.Pen = PTI.Pen or {}

local SCAN_NAME = "PTI_PenScan"
local RETICLE_EVENT_NAME = "PTI_PenReticle"
local SCAN_INTERVAL_MS = 250

-- 効果表(abilityId→効果)。IDは公開されているESOログ解析用ID一覧
-- (github.com/sheumais/logs wiki "ID Dictionary", 2025-12更新)で確認した値。
-- amount は耐性低下量(固定値。APIから取得した値ではない)。nil は「量を確認できていない
-- ため表示・合計しない」の意味。PS5実機でのID一致は未検証。
local EFFECTS = {
    major   = { label = "Major Breach", amount = 5948 },
    minor   = { label = "Minor Breach", amount = 2974 },
    crusher = { label = "Crusher",      amount = nil  },
    alkosh  = { label = "Alkosh",       amount = nil  },
}
local EFFECT_ORDER = { "major", "minor", "crusher", "alkosh" }
local EFFECT_TABLE = {
    [61743] = "major",    -- Major Breach
    [61742] = "minor",    -- Minor Breach
    [17906] = "crusher",  -- Crusher
    [75753] = "alkosh",   -- Line-Breaker(Roar of Alkosh)
}
-- 補助判定用: 説明文に含まれる数値 → 効果
local DESC_NUMBERS = { { "5948", "major" }, { "2974", "minor" } }

local COLOR_SELF   = { 0.70, 0.90, 1.00 }
local COLOR_EFFECT = { 1.00, 0.55, 0.45 }
local COLOR_URGENT = { 1.00, 0.92, 0.25 }
local COLOR_TOTAL  = { 1.00, 0.85, 0.35 }
local URGENT_SECONDS = 5

local active = false
local classCache = {}   -- abilityId -> 効果キー / false
local estCache = {}     -- abilityId -> true(補助判定による推定)
local classCacheSize = 0
local state = {}        -- 毎スキャン作り直す(present/endTime/estimated)
for _, k in ipairs(EFFECT_ORDER) do state[k] = {} end

local function FormatNumber(n)
    if type(n) ~= "number" then return "取得不可" end
    n = zo_round(n)
    if ZO_CommaDelimitNumber then return ZO_CommaDelimitNumber(n) end
    return tostring(n)
end

--------------------------------------------------------------------------
-- 効果の判定(デバフのみ対象)。結果はAbilityIdごとに1回だけ計算してキャッシュする。
-- 戻り値: 効果キー(またはfalse), 理由(dump用), 推定か(補助判定ならtrue)
--------------------------------------------------------------------------
local function ClassifyUncached(abilityId)
    local key = EFFECT_TABLE[abilityId]
    if key then return key, "ID表", false end

    if PTI.sv.pen.descFallback ~= false then
        local ok, desc = pcall(GetAbilityDescription, abilityId)
        if ok and type(desc) == "string" and desc ~= "" then
            for _, pair in ipairs(DESC_NUMBERS) do
                -- 数字の境界を確認する(12974等の一部一致を拾わない)
                if desc:find("%f[%d]" .. pair[1] .. "%f[%D]") then
                    return pair[2], "説明文の数値(推定)", true
                end
            end
        end
    end
    return false, "該当なし", false
end

local function Classify(abilityId)
    local c = classCache[abilityId]
    if c ~= nil then return c, estCache[abilityId] == true end
    if classCacheSize > 300 then -- 想定外に増え続けないよう上限を設ける
        ZO_ClearTable(classCache)
        ZO_ClearTable(estCache)
        classCacheSize = 0
    end
    local key, _, est = ClassifyUncached(abilityId)
    classCache[abilityId] = key
    if est then estCache[abilityId] = true end
    classCacheSize = classCacheSize + 1
    return key, est
end

--------------------------------------------------------------------------
-- 自分の貫通値
--------------------------------------------------------------------------
local function ReadStat(statConstant)
    if statConstant == nil or STAT_BONUS_OPTION_APPLY_BONUS == nil then return nil end
    local ok, v = pcall(GetPlayerStat, statConstant, STAT_BONUS_OPTION_APPLY_BONUS)
    if ok and type(v) == "number" then return v end
    return nil
end

local function ReadSelfPenetration()
    return ReadStat(STAT_PHYSICAL_PENETRATION), ReadStat(STAT_SPELL_PENETRATION)
end

--------------------------------------------------------------------------
-- 描画
--------------------------------------------------------------------------
-- v2.0.6: 敵プレイヤーのみ。判定はUI①②と共通(PTI.Target.IsEnemyPlayerTarget)。
-- 共通関数が無い場合は「敵と確認できない」扱いで何も表示しない。
local function IsValidTarget()
    return PTI.Target and PTI.Target.IsEnemyPlayerTarget and PTI.Target.IsEnemyPlayerTarget() or false
end

local function RemainingText(endTime, now)
    if not endTime then return "残り不明", false end
    local s = zo_ceil(endTime - now)
    return string.format("残り%d秒", s), (s <= URGENT_SECONDS)
end

local function Render(title, buildRows)
    local win = PTI.UI.GetWindow("pen")
    if not win then return end
    win.titleLabel:SetText(title)

    local maxRows = (PTI.sv.penUI and PTI.sv.penUI.maxRows) or 6
    local index = 0
    local function put(nameText, timeText, color)
        if index >= maxRows then return end
        index = index + 1
        local row = PTI.UI.AcquireRow("pen", index)
        local font = PTI.UI.RowFont("pen")
        row.nameLabel:SetFont(font)
        row.nameLabel:SetText(nameText)
        row.nameLabel:SetColor(color[1], color[2], color[3], 1)
        row.timeLabel:SetFont(font)
        row.timeLabel:SetText(timeText)
        row.timeLabel:SetColor(color[1], color[2], color[3], 1)
    end
    buildRows(put)
    PTI.UI.ReleaseUnusedRows("pen", index + 1)
end

local function RenderLive(title, now)
    local sv = PTI.sv.pen
    Render(title, function(put)
        if sv.showSelfPen ~= false then
            local phys, spell = ReadSelfPenetration()
            put("武器貫通", FormatNumber(phys), COLOR_SELF)
            put("呪文貫通", FormatNumber(spell), COLOR_SELF)
        end
        -- 敵の耐性低下: 検知できた効果だけを表示する(未検知を検知済みに見せない)
        local total, any, unknownAmount = 0, false, false
        for _, key in ipairs(EFFECT_ORDER) do
            local s = state[key]
            if s.present then
                any = true
                local info = EFFECTS[key]
                local text, urgent = RemainingText(s.endTime, now)
                local label = info.label
                if s.estimated then label = label .. "(推定)" end
                if info.amount then
                    total = total + info.amount
                    label = string.format("%s  -%s", label, FormatNumber(info.amount))
                else
                    unknownAmount = true
                    label = label .. "  (量は不明)"
                end
                put(label, text, urgent and COLOR_URGENT or COLOR_EFFECT)
            end
        end
        local totalText
        if not any then
            totalText = "検出なし"
        elseif unknownAmount then
            totalText = "-" .. FormatNumber(total) .. " + 量不明分"
        else
            totalText = "-" .. FormatNumber(total)
        end
        put("確認済み耐性低下合計", totalText, COLOR_TOTAL)
    end)
end

local function RenderPreview()
    local sv = PTI.sv.pen
    Render("PEN (プレビュー・サンプル値)", function(put)
        if sv.showSelfPen ~= false then
            put("武器貫通", "(サンプル)", COLOR_SELF)
            put("呪文貫通", "(サンプル)", COLOR_SELF)
        end
        put(string.format("%s  -%s", EFFECTS.major.label, FormatNumber(EFFECTS.major.amount)), "残り8秒", COLOR_EFFECT)
        put(string.format("%s  -%s", EFFECTS.minor.label, FormatNumber(EFFECTS.minor.amount)), "残り12秒", COLOR_EFFECT)
        put("確認済み耐性低下合計", "-" .. FormatNumber(EFFECTS.major.amount + EFFECTS.minor.amount), COLOR_TOTAL)
    end)
end

--------------------------------------------------------------------------
-- スキャン(250ms周期 + ターゲット変更時。パネルONの間だけ登録される)
--------------------------------------------------------------------------
local function ResetState()
    for _, key in ipairs(EFFECT_ORDER) do
        local s = state[key]
        s.present, s.endTime, s.estimated = false, nil, false
    end
end

local function SetContent(hasContent)
    PTI.UI.penHasContent = hasContent
    PTI.UI.SetWindowVisible("pen")
end

local function OnTick()
    if not active then return end
    if PTI.sv.previewMode then
        RenderPreview()
        SetContent(true)
        return
    end
    -- メニュー/マップ表示中は読まない(どうせ隠れている)
    if PTI.UI.hiddenByScene then return end

    ResetState()
    if not IsValidTarget() then
        SetContent(false)
        return
    end

    local now = GetGameTimeSeconds()
    do -- 敵の耐性低下デバフを走査(パネルOFF中は本関数自体が動かない)
        local numBuffs = GetNumBuffs("reticleover")
        for i = 1, numBuffs do
            -- 戻り値の並びはPvPTargetInfo_Target.luaと同一(12個)
            local buffName, startTime, endTime, buffSlot, stackCount, iconFile,
                  buffType, effectType, abilityType, statusEffectType, abilityId,
                  canClickOff = GetUnitBuffInfo("reticleover", i)
            if type(abilityId) == "number" and effectType == BUFF_EFFECT_TYPE_DEBUFF then
                local key, est = Classify(abilityId)
                if key then
                    local hasEnd = type(endTime) == "number" and endTime > 0
                    -- 終了時刻を過ぎているのにまだ返ってくる古いデータは使わない
                    if not (hasEnd and endTime - now <= 0) then
                        local s = state[key]
                        -- 同名の効果が複数Idで付いていても1回分だけ数える(二重加算防止)。
                        -- 残り時間は一番長いものを採用。ID表で確認できたものは推定より優先。
                        local newEnd = hasEnd and endTime or nil
                        if not s.present then
                            s.present, s.endTime, s.estimated = true, newEnd, est
                        else
                            if not est then s.estimated = false end
                            if newEnd == nil or (s.endTime ~= nil and newEnd > s.endTime) then
                                s.endTime = newEnd
                            end
                        end
                    end
                end
            end
        end
    end

    local name = GetUnitDisplayName("reticleover")
    if not name or name == "" then name = GetUnitName("reticleover") or "" end
    RenderLive("PEN: " .. name, now)
    SetContent(true)
end

--------------------------------------------------------------------------
-- ON/OFFに応じてスキャンとイベント購読を登録/解除する(冪等)。
-- UI.SetWindowVisible("pen")から呼ばれるため、設定画面のチェックボックス・
-- /pti hide・シーン切替など、表示条件が変わる度に自動で整合する。
--------------------------------------------------------------------------
function PTI.Pen.Sync()
    local want = (PTI.sv and PTI.sv.enabled and PTI.sv.penUI and PTI.sv.penUI.enabled) and true or false
    if want == active then return end
    active = want
    if active then
        EVENT_MANAGER:RegisterForUpdate(SCAN_NAME, SCAN_INTERVAL_MS, OnTick)
        EVENT_MANAGER:RegisterForEvent(RETICLE_EVENT_NAME, EVENT_RETICLE_TARGET_CHANGED, OnTick)
        OnTick()
    else
        EVENT_MANAGER:UnregisterForUpdate(SCAN_NAME)
        EVENT_MANAGER:UnregisterForEvent(RETICLE_EVENT_NAME, EVENT_RETICLE_TARGET_CHANGED)
        ResetState()
        PTI.UI.penHasContent = false
        if PTI.UI.GetWindow("pen") then PTI.UI.ReleaseUnusedRows("pen", 1) end
    end
end

-- 設定画面で補助判定を切り替えたとき
function PTI.Pen.OnSettingsChanged()
    ZO_ClearTable(classCache)
    ZO_ClearTable(estCache)
    classCacheSize = 0
    if active then OnTick() end
end

function PTI.Pen.Initialize()
    PTI.Pen.Sync()
end

--------------------------------------------------------------------------
-- /pti pen ...
--------------------------------------------------------------------------
local function Say(fmt, ...)
    d("|c55CCFF[PvPTargetInfo]|r " .. string.format(fmt, ...))
end

-- チャットでは"|"が制御コードとして解釈されるため、説明文中の"|"は置き換える
local function Sanitize(text, maxLen)
    text = tostring(text or ""):gsub("|", "/"):gsub("[\r\n]", " ")
    if #text > maxLen then text = text:sub(1, maxLen) .. "..." end
    return text
end

local function Dump()
    Say("貫通パネル診断 (STAT_PHYSICAL_PENETRATION=%s / STAT_SPELL_PENETRATION=%s / APPLY_BONUS=%s)",
        tostring(STAT_PHYSICAL_PENETRATION ~= nil), tostring(STAT_SPELL_PENETRATION ~= nil),
        tostring(STAT_BONUS_OPTION_APPLY_BONUS ~= nil))
    local phys, spell = ReadSelfPenetration()
    Say("自分の貫通: 武器=%s / 呪文=%s", FormatNumber(phys), FormatNumber(spell))

    if not IsValidTarget() then
        Say("敵プレイヤーをターゲットした状態で実行すると、そのデバフ一覧(Id・名前・判定)を表示します。(味方・NPCは対象外。/pti enemy で判定内容を確認できます)")
        return
    end
    local now = GetGameTimeSeconds()
    local numBuffs = GetNumBuffs("reticleover")
    Say("対象 %s: 効果 %d件 (デバフのみ判定対象。最大30件まで表示)", Sanitize(GetUnitDisplayName("reticleover"), 30), numBuffs)
    local shown = 0
    for i = 1, numBuffs do
        local buffName, startTime, endTime, _, _, _, _, effectType, _, _, abilityId = GetUnitBuffInfo("reticleover", i)
        if type(abilityId) == "number" and effectType == BUFF_EFFECT_TYPE_DEBUFF and shown < 30 then
            shown = shown + 1
            local tier, reason = ClassifyUncached(abilityId)
            local remain = (type(endTime) == "number" and endTime > 0) and string.format("%.1fs", endTime - now) or "不明"
            local okd, desc = pcall(GetAbilityDescription, abilityId)
            Say("id=%d %s / 残り%s / 判定=%s(%s) / 説明: %s", abilityId, Sanitize(buffName, 30), remain,
                tier or "なし", reason, okd and Sanitize(desc, 60) or "取得失敗")
        end
    end
end

function PTI.Pen.HandleCommand(rest)
    local sub = (rest or ""):lower()
    if sub == "on" or sub == "off" then
        PTI.sv.penUI.enabled = (sub == "on")
        PTI.UI.RefreshVisibility()
        Say("UI④(貫通): %s", sub == "on" and "ON" or "OFF")
    elseif sub == "dump" then
        Dump()
    else
        Say("UI④(貫通): %s  (例: /pti pen on||off||dump)", PTI.sv.penUI.enabled and "ON" or "OFF")
    end
end
