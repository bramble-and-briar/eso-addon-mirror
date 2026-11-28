-- Combat Bar : 名前空間・初期設定・共通関数
CombatBar = CombatBar or {}
local CB = CombatBar

CB.name = "CombatBar"
CB.version = "1.1.0"
CB.svName = "CombatBarSV"
CB.svVersion = 1

-- ROYAL CYBER テーマ色
CB.Theme =
{
    gold = { 0.85, 0.68, 0.25, 0.95 },
    cyan = { 0.25, 0.85, 1, 1 },
    white = { 1, 1, 1, 1 },
}

local function ResDefault(y, color)
    return {
        enabled = true, x = -24, y = y, w = 220, h = 22,
        color = color, bgColor = { 0, 0, 0, 0.6 }, alpha = 100,
        showValue = true, showPercent = true, showLabel = true, fontSize = 18,
    }
end

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
    expireColor = { 1, 0.82, 0.2 },
    timerColor = { 1, 1, 1 },
    showStacks = true,
    stackSize = 18,
    stackColor = { 0.9, 0.75, 0.3 },

    -- ハイライト
    showHighlight = true,
    highlightColor = { 0.25, 0.85, 1, 0.7 },
    highlightExpire = true,
    highlightExpireColor = { 1, 0.45, 0.1, 0.7 },

    -- ULT
    ultShowValue = true,
    ultValueMode = 1,
    ultSize = 20,
    ultColor = { 1, 1, 1 },
    ultUsableColor = { 0.25, 0.85, 1 },
    ultShowDuration = true,

    -- クイックスロット
    qsShowTimer = true,
    qsShowCount = true,
    qsSize = 20,

    -- キャスト/チャネル
    showCast = true,
    castColor = { 0.25, 0.85, 1 },

    -- デザイン(ROYAL CYBER)
    designFrame = true,
    designGlow = 30,

    -- 設定画面プレビューの位置
    previewX = 40,
    previewY = 40,

    -- HP・MP・STバー(アクションバー左側に縦並び。各バー独立)
    resources =
    {
        hp = ResDefault(0, { 0.85, 0.2, 0.25 }),
        mp = ResDefault(28, { 0.2, 0.5, 1 }),
        st = ResDefault(56, { 0.3, 0.85, 0.4 }),
    },

    -- GCDトラッカー
    gcdEnabled = false,
    gcdX = 900,
    gcdY = 700,
    gcdW = 8,
    gcdH = 100,
    gcdColor = { 0.9, 0.75, 0.3, 0.85 },

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

-- 保存データに足りない項目だけを初期値で補う(既存の値は変更しない)
function CB.FillDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = CB.DeepCopy(v)
        elseif type(v) == "table" and type(dst[k]) == "table" and k ~= "widgets" and k ~= "effectOverride" then
            CB.FillDefaults(dst[k], v)
        end
    end
end
