--[[
    PvPTargetInfo_Target.lua (2.0.0 完成版)

    検出方式(最重要・v1.4.x系からの方針転換):
      EVENT_EFFECT_CHANGEDのキャッシュ更新には依存しない。
      現在のターゲット(reticleover)に対して GetNumBuffs → GetUnitBuffInfo を
      直接呼び、"今その瞬間に実際に付いている効果" をそのまま読み取る。

      スキャンのタイミングは2つだけ:
        ① EVENT_RETICLE_TARGET_CHANGED でターゲットが変わった瞬間に即時スキャン
        ② ターゲット中は一定間隔(既定250ms)の定期スキャン
           非戦闘中はさらに間引いて実質2倍の間隔にする(負荷軽減)
      ターゲットが存在しない間、またはNPC/自分自身などプレイヤーでない間は
      スキャン自体を行わない(GetNumBuffs等のAPIを一切呼ばない)。

    GetUnitBuffInfoの戻り値順序は、"PvPTargetInfo_forSubmission"版で実機
    検証済みとされる以下の並びをそのまま採用している(推測で変更しない)。

        buffName, iconFile, startTime, endTime, buffSlot, stackCount,
        _iconFile2, effectType, abilityType, statusEffectType, abilityId,
        canClickOff, castByPlayer = GetUnitBuffInfo(unitTag, i)

      ただし値はすべて型チェックしてから使用し、想定外の型が来ても
      エラーにならないようにしている。
--]]

PvPTargetInfo = PvPTargetInfo or {}
local PTI = PvPTargetInfo
PTI.Target = PTI.Target or {}

local SCAN_UPDATE_NAME = "PTI_Scan"
local SCAN_INTERVAL_MS = 250 -- 目安200〜300ms

--------------------------------------------------------------------------
-- デバッグログ(sv.debug が true の間だけ出力。既定OFF)
--------------------------------------------------------------------------
local function DebugTrace(fmt, ...)
    if PTI.sv and PTI.sv.debug then
        d("|c888888[PTI Debug]|r " .. string.format(fmt, ...))
    end
end

--------------------------------------------------------------------------
-- 自動検知①: 状態異常(CC)の種類による判定(デバフ専用)
-- ゲームバージョンによって定数の有無が変わっても安全なように、
-- 存在しない定数名は_G参照がnilになるだけでスキップされる。
--------------------------------------------------------------------------
local CC_STATUS_EFFECT_TYPES = {}
local function RegisterCCStatusType(constantName)
    local value = _G[constantName]
    if value ~= nil then
        CC_STATUS_EFFECT_TYPES[value] = true
    end
end
for _, constantName in ipairs({
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
}) do
    RegisterCCStatusType(constantName)
end

--------------------------------------------------------------------------
-- 自動検知②: 効果名のキーワードによる判定
--
-- "Major"/"Minor"(英語版)と日本語版語尾表記"(強)"/"(弱)"は、これまでの
-- 検証でMajor/Minor系(攻撃力・防御力・クリティカル・耐性・機動力等)の
-- ほぼ全てを正しく拾えることが確認済みの方式なのでそのまま踏襲する。
-- "シールド"/"盾"は、Major/Minorのタグが付かないダメージシールド系スキル
-- (Hardened Ward、Igneous Shield等)を名前ヒューリスティックで補足するために
-- 追加した(特定のAbilityIdを推測で決め打ちしない代わりの対応)。
--------------------------------------------------------------------------
local AUTO_DETECT_KEYWORDS = { "Major", "Minor", "(強)", "(弱)", "シールド", "盾" }

local function NameMatchesKeyword(name, keywords)
    for _, kw in ipairs(keywords) do
        if name:find(kw, 1, true) then return true end
    end
    return false
end

-- 自動検知では拾えない効果を追加するための手動AbilityId登録
-- (sv.importantIdsText、カンマ区切り)。設定画面・/pti コマンドから変更可能。
local manualIds = {}
local function RebuildManualIds()
    ZO_ClearTable(manualIds)
    local text = (PTI.sv and PTI.sv.importantIdsText) or ""
    for idStr in string.gmatch(text, "[^,%s]+") do
        local id = tonumber(idStr)
        if id then manualIds[id] = true end
    end
end
PTI.Target.RebuildManualIds = RebuildManualIds

local function IsImportant(kind, buffName, statusEffectType, abilityId)
    if type(abilityId) == "number" and manualIds[abilityId] then
        return true
    end
    if kind == "debuff" and CC_STATUS_EFFECT_TYPES[statusEffectType] then
        return true
    end
    if type(buffName) == "string" and buffName ~= "" then
        return NameMatchesKeyword(buffName, AUTO_DETECT_KEYWORDS)
    end
    return false
end

--------------------------------------------------------------------------
-- 表示優先順位(カテゴリ分類)。判定は効果名の部分一致。
-- 数字が小さいほど優先度が高い(上位表示)。
--------------------------------------------------------------------------
local BUFF_CATEGORY_ORDER = {
    { rank = 1, keywords = { "Resolve", "不屈", "Evasion", "Protection" } },            -- 防御・ダメージ軽減
    { rank = 2, keywords = { "Vitality", "Mending", "Fortitude", "Endurance", "Intellect", "Lifesteal", "Toughness" } }, -- 回復・生存
    { rank = 3, keywords = { "Brutality", "Sorcery", "Berserk", "Courage", "Slayer", "Empower" } }, -- 攻撃力強化
    { rank = 4, keywords = { "Prophecy", "Savagery", "Force" } },                       -- クリティカル
    { rank = 5, keywords = { "Expedition", "Gallop", "Heroism" } },                     -- 機動力・CC耐性
    { rank = 6, keywords = { "シールド", "盾", "Ward", "Shield" } },                    -- シールド
}
local BUFF_OTHER_RANK = 7

local DEBUFF_CATEGORY_ORDER = {
    { rank = 1, keywords = { "Breach", "Vulnerability", "Brittle" } },        -- 防御低下
    { rank = 2, keywords = { "Defile" } },                                   -- 回復阻害
    { rank = 3, keywords = { "Maim", "Cowardice", "Uncertainty" } },         -- 攻撃力低下
    { rank = 5, keywords = { "Poison", "Disease", "Burning", "Bleed", "Deep Wound", "Sundered" } }, -- DoT
}
local DEBUFF_CC_RANK = 4
local DEBUFF_OTHER_RANK = 6

local URGENT_REMAINING_THRESHOLD = 5

local function LookupCategoryRank(order, name)
    if type(name) ~= "string" then return nil end
    for _, group in ipairs(order) do
        for _, kw in ipairs(group.keywords) do
            if name:find(kw, 1, true) then return group.rank end
        end
    end
    return nil
end

--------------------------------------------------------------------------
-- スキャン本体
--------------------------------------------------------------------------
local now = 0

local function ClassifyAndCollect()
    local buffList, debuffList = {}, {}
    local seen = {}

    local numBuffs = GetNumBuffs("reticleover")
    if type(numBuffs) ~= "number" or numBuffs <= 0 then
        return buffList, debuffList
    end

    for i = 1, numBuffs do
        -- forSubmission版で実機検証済みの戻り値順序をそのまま使用。
        local buffName, iconFile, startTime, endTime, buffSlot, stackCount,
              _iconFile2, effectType, abilityType, statusEffectType, abilityId,
              canClickOff, castByPlayer = GetUnitBuffInfo("reticleover", i)

        if type(buffName) == "string" and buffName ~= "" then
            local dedupeKey = (type(abilityId) == "number") and abilityId or buffName
            if not seen[dedupeKey] then
                local kind = (effectType == BUFF_EFFECT_TYPE_DEBUFF) and "debuff" or "buff"

                if IsImportant(kind, buffName, statusEffectType, abilityId) then
                    seen[dedupeKey] = true

                    local validEnd = (type(endTime) == "number" and endTime > 0) and endTime or nil
                    local remaining = validEnd and (validEnd - now) or nil

                    -- 既に期限切れのものは即座に除外する(表示から消す)。
                    if not validEnd or remaining > 0 then
                        local entry = {
                            name = buffName,
                            icon = (type(iconFile) == "string" and iconFile ~= "") and iconFile or nil,
                            remaining = remaining,
                            stackCount = (type(stackCount) == "number" and stackCount > 1) and stackCount or nil,
                            statusEffectType = statusEffectType,
                        }
                        if kind == "debuff" then
                            table.insert(debuffList, entry)
                        else
                            table.insert(buffList, entry)
                        end
                    end
                end
            end
        end
    end

    return buffList, debuffList
end

local function SortList(list, order, otherRank, ccRank)
    for _, e in ipairs(list) do
        if ccRank and CC_STATUS_EFFECT_TYPES[e.statusEffectType] then
            e.rank = ccRank
        else
            e.rank = LookupCategoryRank(order, e.name) or otherRank
        end
        e.urgent = (e.remaining ~= nil) and (e.remaining <= URGENT_REMAINING_THRESHOLD)
    end
    table.sort(list, function(a, b)
        if a.urgent ~= b.urgent then return a.urgent end
        if a.rank ~= b.rank then return a.rank < b.rank end
        local ar = a.remaining or math.huge
        local br = b.remaining or math.huge
        return ar < br
    end)
end

--------------------------------------------------------------------------
-- 描画
--------------------------------------------------------------------------
local function FormatTime(remaining, stackCount)
    local parts = {}
    if remaining ~= nil then
        table.insert(parts, string.format("%.1f", remaining))
    end
    if stackCount then
        table.insert(parts, string.format("x%d", stackCount))
    end
    return table.concat(parts, " ")
end

local function RenderList(key, list)
    local sv = (key == "buff") and PTI.sv.buffUI or PTI.sv.debuffUI
    local maxRows = sv.maxRows or 6
    local index = 0

    for _, e in ipairs(list) do
        if index >= maxRows then break end
        index = index + 1
        local row = PTI.UI.AcquireRow(key, index)

        if e.icon then
            row.icon:SetTexture(e.icon)
            row.icon:SetHidden(false)
        else
            row.icon:SetHidden(true)
        end

        row.nameLabel:SetText(e.name)
        row.timeLabel:SetText(FormatTime(e.remaining, e.stackCount))

        if e.urgent then
            row.nameLabel:SetColor(1, 0.85, 0.2, 1)
            row.timeLabel:SetColor(1, 0.85, 0.2, 1)
        elseif key == "debuff" then
            row.nameLabel:SetColor(1, 0.55, 0.5, 1)
            row.timeLabel:SetColor(0.85, 0.7, 0.68, 1)
        else
            row.nameLabel:SetColor(0.55, 0.95, 0.6, 1)
            row.timeLabel:SetColor(0.75, 0.85, 0.78, 1)
        end
    end

    PTI.UI.ReleaseUnusedRows(key, index + 1)
    PTI.UI.hasContent[key] = (index > 0)
    return index
end

local function RenderPreview()
    local buffRow = PTI.UI.AcquireRow("buff", 1)
    buffRow.icon:SetHidden(true)
    buffRow.nameLabel:SetText("残忍(強)")
    buffRow.nameLabel:SetColor(0.55, 0.95, 0.6, 1)
    buffRow.timeLabel:SetText("8.4")
    buffRow.timeLabel:SetColor(0.75, 0.85, 0.78, 1)
    PTI.UI.ReleaseUnusedRows("buff", 2)
    PTI.UI.hasContent.buff = true

    local debuffRow = PTI.UI.AcquireRow("debuff", 1)
    debuffRow.icon:SetHidden(true)
    debuffRow.nameLabel:SetText("侵害(弱)")
    debuffRow.nameLabel:SetColor(1, 0.55, 0.5, 1)
    debuffRow.timeLabel:SetText("5.1")
    debuffRow.timeLabel:SetColor(0.85, 0.7, 0.68, 1)
    PTI.UI.ReleaseUnusedRows("debuff", 2)
    PTI.UI.hasContent.debuff = true
end

local function RenderEmpty()
    PTI.UI.ReleaseUnusedRows("buff", 1)
    PTI.UI.ReleaseUnusedRows("debuff", 1)
    PTI.UI.hasContent.buff = false
    PTI.UI.hasContent.debuff = false
end

--------------------------------------------------------------------------
-- メインループ
--------------------------------------------------------------------------
local outOfCombatCounter = 0

-- 想定外のAPI戻り値等で例外が起きても、以後のプレイに影響しないよう
-- スキャン本体はpcallで保護する。
local function SafeScanAndRender()
    local ok, buffList, debuffList = pcall(ClassifyAndCollect)
    if not ok then
        DebugTrace("スキャンでエラー: %s", tostring(buffList))
        RenderEmpty()
        return
    end

    SortList(buffList, BUFF_CATEGORY_ORDER, BUFF_OTHER_RANK, nil)
    SortList(debuffList, DEBUFF_CATEGORY_ORDER, DEBUFF_OTHER_RANK, DEBUFF_CC_RANK)

    local buffCount = RenderList("buff", buffList)
    local debuffCount = RenderList("debuff", debuffList)

    DebugTrace("対象=%s BUFF=%d件 DEBUFF=%d件", tostring(GetUnitName("reticleover")), buffCount, debuffCount)
end

local function OnScanTick()
    now = GetGameTimeSeconds()

    if not PTI.sv.enabled then
        return
    end

    if PTI.sv.previewMode then
        RenderPreview()
        return
    end

    if not DoesUnitExist("reticleover") or not IsUnitPlayer("reticleover") then
        -- ターゲットなし/NPC/自分自身: スキャンせず何も表示しない
        if PTI.UI.hasContent.buff or PTI.UI.hasContent.debuff then
            RenderEmpty()
            PTI.UI.RefreshVisibility()
        end
        outOfCombatCounter = 0
        return
    end

    -- 非戦闘中は間引いて実質2倍の間隔にする(負荷軽減)。
    if not IsUnitInCombat("player") then
        outOfCombatCounter = outOfCombatCounter + 1
        if outOfCombatCounter % 2 ~= 0 then
            return
        end
    else
        outOfCombatCounter = 0
    end

    SafeScanAndRender()
    PTI.UI.RefreshVisibility()
end

local function OnTargetChanged()
    -- ターゲットが変わった瞬間、前の対象の情報を即座に消してから
    -- 新しい対象を即時スキャンする(保険の遅延スキャンは不要な設計:
    -- 定期スキャンが250ms以内に必ず追従するため)。
    outOfCombatCounter = 0
    now = GetGameTimeSeconds()

    if not PTI.sv.enabled or PTI.sv.previewMode then return end

    if not DoesUnitExist("reticleover") or not IsUnitPlayer("reticleover") then
        RenderEmpty()
        PTI.UI.RefreshVisibility()
        return
    end

    SafeScanAndRender()
    PTI.UI.RefreshVisibility()
end

function PTI.Target.Initialize()
    RebuildManualIds()

    EVENT_MANAGER:RegisterForUpdate(SCAN_UPDATE_NAME, SCAN_INTERVAL_MS, OnScanTick)

    EVENT_MANAGER:RegisterForEvent(PTI.name .. "TargetChanged", EVENT_RETICLE_TARGET_CHANGED, OnTargetChanged)
end
