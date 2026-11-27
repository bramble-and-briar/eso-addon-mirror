-- Combat Bar : 名前空間・初期設定・共通関数
CombatBar = CombatBar or {}
local CB = CombatBar

CB.name = "CombatBar"
CB.version = "1.0.0"
CB.svName = "CombatBarSV"
CB.svVersion = 1

CB.defaults =
{
    enabled = true,
    language = "auto",
    tickMs = 100,          -- 効果がある間だけ動く表示更新の間隔(ミリ秒)
    fabHandled = false,    -- Fancy Action Bar+検出時の自動OFFを済ませたか

    -- バー表示
    showFront = true,
    showBack = true,
    manageStandardBar = false,
    stdOffsetX = 0,
    stdOffsetY = 0,
    backOffsetX = 0,
    backOffsetY = -6,
    backScale = 80,

    -- 非アクティブバー
    inactiveAlpha = 60,
    inactiveDesat = 50,

    -- タイマー
    durationMin = 2,
    durationMax = 120,
    timerSize = 22,
    decimalBelow = 2,
    expireStart = 2,
    expireColor = { 1, 1, 0 },
    timerColor = { 1, 1, 1 },
    showStacks = true,
    stackSize = 18,
    stackColor = { 1, 0.8, 0 },

    -- ハイライト
    showHighlight = true,
    highlightColor = { 0, 1, 0, 0.7 },
    highlightExpire = true,
    highlightExpireColor = { 1, 0, 0, 0.7 },

    -- ULT
    ultShowValue = true,
    ultValueMode = 1,
    ultSize = 20,
    ultColor = { 1, 1, 1 },
    ultUsableColor = { 0, 1, 0 },
    ultShowDuration = true,

    -- クイックスロット
    qsShowTimer = true,
    qsShowCount = true,
    qsSize = 20,

    -- キャスト/チャネル
    showCast = true,
    castColor = { 0.4, 0.8, 1 },

    -- GCDトラッカー
    gcdEnabled = false,
    gcdX = 900,
    gcdY = 700,
    gcdW = 8,
    gcdH = 100,
    gcdColor = { 1, 1, 1, 0.8 },

    -- 浮遊エフェクトウィジェット: [abilityId] = { x, y, size, inactiveAlpha }
    widgets = {},

    -- スキル別効果ID: [abilityId] = effectId
    effectOverride = {},
}

-- 初期値の深いコピー
function CB.DeepCopy(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do dst[k] = CB.DeepCopy(v) end
    return dst
end

-- プリセット(上書きする項目だけ)
CB.presets =
{
    pve = { durationMin = 2, decimalBelow = 2, expireStart = 2, showHighlight = true, highlightExpire = true, inactiveAlpha = 60 },
    pvp = { durationMin = 1, decimalBelow = 3, expireStart = 3, showHighlight = true, highlightExpire = true, inactiveAlpha = 80, inactiveDesat = 30 },
}

-- 文字列取得(日本語基本 + 英語フォールバック)
function CB.SelectLanguage(sv)
    local lang = sv and sv.language or "auto"
    if lang == "auto" then
        lang = (GetCVar and GetCVar("language.2") == "jp") and "jp" or "en"
    end
    CB.L = (lang == "jp" and CombatBar.LJP) or CombatBar.LEN
end

function CB.T(key)
    local L = CB.L
    return (L and L[key]) or (CombatBar.LEN and CombatBar.LEN[key]) or key
end
