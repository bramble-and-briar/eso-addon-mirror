-- Sul-Xan's marker
-- Author: PUYO
-- Sul-Xan's Torment の魂(Soul)がドロップした時に ↓ アイコンを表示する。
--   157738 = 魂(フィールドに出る)  /  154737 = 魂を拾った時のバフ
-- ↓ は LibCombatAlerts の WorldDrawing で、魂が落ちた位置(=倒した敵の位置)の
-- ワールド空間に描画する。位置が取れない場合は画面上の ↓ にフォールバックする。

SulXansMarker = SulXansMarker or {}
local PSM = SulXansMarker

PSM.name    = "SulXansMarker"
PSM.version = "2.5.18-single-marker-normal-size"

local EM  = EVENT_MANAGER
local LCA = LibCombatAlerts

local SOUL_ID        = 157738  -- 魂がドロップした時のイベント
local PICKUP_BUFF_ID = 154737  -- 魂を拾った時のバフ(Sul-Xan's Torment)
local DEFAULT_DURATION_MS = 6000
local POS_MAX_AGE_MS      = 8000  -- 記録した敵位置を使う最大経過時間
local SAMPLE_INTERVAL_MS  = 50
local ARROW_TEXTURE       = "world-pointer-down" -- LibCombatAlerts 標準の下向き矢印
local FALLBACK_TEXTURE    = "world-circle" -- LibCombatAlerts 標準の丸(白)。SetColor で赤く表示する
local AIM_PLANE_HEIGHT_CM = 100   -- 照準の延長線と交わらせる高さ(足元からの cm、敵の胸あたり)
local MAX_RAY_CM          = 8000  -- 照準から求める位置の最大距離(cm)

PSM.defaults = {
  extraSetNames = {},
  weightTau = 1.5,        -- 新しい線の重視度: 線の重みの減衰時間(秒)。小さいほど新しい線だけを重く見る
  language = "auto",      -- "auto" / "ja" / "en": メッセージと設定画面の言語
  maxShowDist = 36,       -- 三角測量できず推測した位置を表示する最大距離(m)
  useGround = true,       -- 地面の高さを三角測量の追加条件として使う(奥行きの補強)
  hideWhenNoPos = false,  -- 位置が全く取れない時は何も表示しない(OFF なら画面上の ↓ と残り秒数を出す)
  showCandidates = true, -- 同時死亡時は計算できた全候補を小さく表示
  enabled      = true,
  use3D        = true,   -- ワールド空間(魂の位置)に表示
  size3D       = 200,    -- cm
  height       = 200,    -- cm (地面からの高さ)
  size2D       = 96,     -- 画面表示(フォールバック)のサイズ
  showCountdown = true,  -- 矢印の中に残り秒数(整数)を表示
  hideOnPickup = true,
  markUncertain = true,  -- 位置が不確かな時は矢印の色を変える
  bob          = true,
  color        = { 1, 1, 1, 1 },
  offsetX      = 0,
  offsetY      = -140,
}

PSM.sv       = nil
PSM.endTime  = 0
PSM.shownAt  = 0
PSM.unlocked = false
PSM.testing  = false
PSM.pendingPickup = false
PSM.fallbackVisible = false

local UPDATE_NAME = PSM.name .. "_Update"
local SAMPLE_NAME = PSM.name .. "_Sample"
local now = GetGameTimeMilliseconds
local DIAG_LOG_MAX = 40
local diagnosticLog = {}

local function StoreDiagnostic(line)
  if not PSM.logEnabled then return end
  diagnosticLog[#diagnosticLog + 1] = line
  while #diagnosticLog > DIAG_LOG_MAX do table.remove(diagnosticLog, 1) end
end

local function DumpDiagnosticLog()
  if #diagnosticLog == 0 then
    d("[Sul-Xan's marker] No diagnostic log. Turn on /sulxan log, reproduce the issue, then run /sulxan dump.")
    return
  end
  d(string.format("[Sul-Xan's marker] --- diagnostic log (%d lines) ---", #diagnosticLog))
  for _, line in ipairs(diagnosticLog) do d(line) end
  d("[Sul-Xan's marker] --- end diagnostic log ---")
end

-- 日本語クライアントなら日本語、それ以外は英語のメッセージを返す
-- 言語の判定: CVar(大文字小文字の両方を試す) と、ゲームの文字列に日本語が含まれるかの両方で調べる。
-- /sulxan lang ja|en|auto で手動指定もできる(PSM.sv.language)。
local detectedJa = false   -- 日本語と分かったら true で固定。false の間は呼ぶたびに調べ直す(日本語化アドオンの読み込みが遅れる場合があるため)
local function HasKana(v) return type(v) == "string" and v:find("\227[\129-\131]") ~= nil end  -- ひらがな・カタカナ(UTF-8 の E3 81〜83)

-- 言語の手がかりを一覧にする。戻り値: 日本語か, 診断用の文字列一覧
local function ProbeLanguage()
  local ja, lines = false, {}
  local function add(label, v, isJa)
    lines[#lines + 1] = label .. "=" .. tostring(v) .. (isJa and " (ja)" or "")
    if isJa then ja = true end
  end
  if GetCVar then
    for _, key in ipairs({ "language.2", "Language.2" }) do
      local ok, v = pcall(GetCVar, key)
      local lv = (ok and type(v) == "string") and v:lower() or nil
      add(key, ok and v or "err", lv == "ja" or lv == "jp")
    end
  end
  if GetString then
    for _, key in ipairs({ "SI_DIALOG_CANCEL", "SI_DIALOG_ACCEPT", "SI_DIALOG_YES", "SI_DIALOG_NO", "SI_DIALOG_CONFIRM", "SI_DIALOG_CLOSE" }) do
      local id = _G[key]
      if id then
        local ok, v = pcall(GetString, id)
        add(key, ok and v or "err", ok and HasKana(v))
      end
    end
  end
  if GetAbilityName then
    for _, id in ipairs({ 157738, 154737 }) do
      local ok, v = pcall(GetAbilityName, id)
      add("ability" .. id, ok and v or "err", ok and HasKana(v))
    end
  end
  if GetPlayerLocationName then
    local ok, v = pcall(GetPlayerLocationName)
    add("location", ok and v or "err", ok and HasKana(v))
  end
  return ja, lines
end

local function DetectJa()
  if detectedJa then return true end
  local ja = ProbeLanguage()
  if ja then detectedJa = true end
  return ja
end
function PSM.IsJa()
  local o = PSM.sv and PSM.sv.language
  if o == "ja" then return true elseif o == "en" then return false end
  return DetectJa()
end
local function L(ja, en) if PSM.IsJa() then return ja end return en end

local ui                 -- 画面表示用コントロール
local canvas              -- LibCombatAlerts のワールド描画
local markers = {}        -- 表示中の矢印の一覧 { {id, numId, pos, numSec}, ... }(候補が複数のとき複数個)
local lastPos            -- 直近に照準していた敵の位置 { x, y, z, time, src }
local samples = {}       -- 敵の名前ごとの、最後に照準していた位置 { x, y, z, time, src }
local lastDeath          -- 直近に倒した敵 { name, time }
local friendlyNames = {}  -- 照準したことのある味方NPC・ペット等の名前 -> time(敵として扱わない)
local recentDeaths = {}  -- 直近の死亡の一覧 { name, time, unitId }
local soulDeathIntervals = {} -- 魂が存在していた時間帯。後続の候補計算から除外
local activeSoulInterval = nil
local SAMPLE_KEEP_MS   = 30000
local DROP_DELAY_MS     = 250   -- 魂イベントの後、死亡イベントを待つ時間
local EARLY_PICKUP_DISPLAY_MS = 750 -- 表示前に拾得された魂のマーカー表示時間
local EARLY_CANDIDATE_DISPLAY_MS = 2500 -- 候補マーカーは拾得直後も確認できるよう長めに表示
local GROUND_DY_KEEP_MS    = 60000 -- 高さの差を覚えておく時間
local GROUND_DY_LIMIT_CM   = 1500  -- 高さの差として採用する上限(±)
-- 水平面との交点(推測)が maxShowDist(m) より遠い時は、ワールド表示にせず何も出さない(設定で変更可。標準 36m)
local CANDIDATE_MARKER_SCALE = 0.55 -- 複数死亡時の候補矢印サイズ
local MAX_CANDIDATE_MARKERS = 4 -- 候補が多すぎる時の表示上限
local DEATH_BEFORE_MS   = 300   -- 魂イベントのこの時間前以降の死亡を「今倒した敵」とみなす
local CANDIDATE_DEATH_WINDOW_MS = 3000 -- 複数候補の列挙に使う死亡履歴の幅

-- ----------------------------------------------------------------------------
-- 位置の取得
-- ----------------------------------------------------------------------------

local IGNORE_MAX_HP = 1  -- 最大体力がこれ以下(=体力1)の相手は、敵として扱わない

local function ReadPos(unitTag)
  local _, x, y, z = GetUnitRawWorldPosition(unitTag)
  if x and not (x == 0 and y == 0 and z == 0) then
    return x, y, z
  end
end

local function IsHostileTarget()
  if not DoesUnitExist("reticleover") or IsUnitPlayer("reticleover") then
    return false
  end
  local reaction = GetUnitReaction("reticleover")
  -- 最大体力が1の相手(小動物など)は、魂の対象になる敵ではないので対象外
  local okp, _, hpMax = pcall(GetUnitPower, "reticleover", COMBAT_MECHANIC_FLAGS_HEALTH)
  if okp and hpMax and hpMax > 0 and hpMax <= IGNORE_MAX_HP then return false end
  if reaction == UNIT_REACTION_HOSTILE then
    return true
  end
  return IsUnitAttackable ~= nil and IsUnitAttackable("reticleover") == true
end

-- カメラ(画面中央の照準)の位置と向きを取得する
-- (LibCombatAlerts の WorldDrawing と同じ方法)
local camCtrl
local function GetCameraRay()
  if not camCtrl then
    camCtrl = WINDOW_MANAGER:CreateControl(PSM.name .. "_Camera", GuiRoot, CT_CONTROL)
    camCtrl:Create3DRenderSpace()
  end
  Set3DRenderSpaceToCurrentCamera(camCtrl:GetName())
  local fx, fy, fz = camCtrl:Get3DRenderSpaceForward()
  local ox, oy, oz = GuiRender3DPositionToWorldPosition(camCtrl:Get3DRenderSpaceOrigin())
  return ox, oy, oz, fx, fy, fz
end

-- 照準(画面中央)の延長線が「敵の胸の高さ」の水平面と交わる点を求める。
-- 敵ユニットの座標を直接取れないため、照準を合わせている敵の位置をこれで近似する。
-- 戻り値: 敵の足元あたりの座標 x, y(=自分の足元の高さ), z
local function RayAimPos()
  local ok, ox, oy, oz, fx, fy, fz = pcall(GetCameraRay)
  if not ok or not ox or not fy then return end
  local _, px, py, pz = GetUnitRawWorldPosition("player")
  if not py then return end
  if fy > -0.01 then return end                -- 水平〜上向きでは交点なし
  -- 直近の三角測量で分かった「敵の足元と自分の足元の高さの差」を、水平面の高さに反映する
  -- (坂道でも、近くの地形はつながっているので、0 と仮定するよりずれにくい)
  local dy = 0
  if PSM.groundDy and PSM.groundDyTime and now() - PSM.groundDyTime <= GROUND_DY_KEEP_MS then
    dy = PSM.groundDy
  end
  local t = ((py + dy + AIM_PLANE_HEIGHT_CM) - oy) / fy
  if t <= 0 or t > MAX_RAY_CM then return end
  return ox + fx * t, py + dy, oz + fz * t
end

-- 照準中の敵の位置: ユニット座標が取れればそれ、取れなければ照準の延長線から求める
local function GetTargetPos()
  local x, y, z = ReadPos("reticleover")
  if x then return x, y, z, "api" end
  x, y, z = RayAimPos()
  if x then return x, y, z, "ray" end
end

-- 照準中の敵の位置を常に記録しておく(倒した瞬間に照準が外れても位置が分かるように)
-- 名前の表記ゆれ(性別マーカーなど)をそろえる
local function NormalizeName(name)
  if not name or name == "" then return nil end
  return zo_strformat(SI_UNIT_NAME, name)
end

local function ReticleName()
  return NormalizeName(GetUnitName("reticleover"))
end

-- ---- 照準の線(カメラの位置と向き)の記録と、その交点からの位置推定 ----------
-- 水平面との交点だけでは、坂道で奥行きが大きくずれる。
-- プレイヤーが動いて「同じ敵に向けた線」が複数あれば、その交点(最小二乗)で
-- 地形に関係なく位置が決まる。動きが足りない時は使わず、水平面との交点にもどす。

local rays = {}              -- 名前 -> { last, segs = { {list = { {t, ox,oy,oz, fx,fy,fz}, ... }, hp, hpMax, last}, ... } }
local MAX_RAYS        = 170  -- 長い範囲(最大8秒)の線を保存できる本数
local RAY_WINDOW_MS   = 4000 -- 計算に必要な線の数と横移動を確保する
local MIN_RAYS        = 6
local MIN_BASELINE_CM = 100  -- 線の位置のばらつき(横方向)の最小値
local WEIGHT_TAU_MS    = 1500 -- 線の重み exp(-経過/τ): 最新の線ほど重く、古い線ほど軽く扱う
local HP_JUMP_RATIO     = 0.03 -- 体力がこれ以上増えたら別個体とみなす(最大体力に対する割合)
local LAST_RAY_OFF_CM  = 100  -- 最新の線が交点からこれ以上離れていたら「不確か」
local MAX_RESIDUAL_CM = 120  -- 交点と各線の平均距離がこれ以上なら不採用(敵が動いた等)
local GROUND_W_KNOWN    = 0.30 -- 地面の条件の強さ(線の重みの合計に対する割合): 高さの差が分かっている時
local GROUND_W_UNKNOWN  = 0.10 -- 同: 高さの差が未知の時(平地と仮定するので弱め)
local GROUND_USE_DERR_CM  = 300  -- 奥行き誤差の見積もりがこれ以上の時だけ、地面の条件を使う
local GROUND_DERR_FACTOR  = 0.6  -- 地面の条件を使った時の、奥行き誤差の見積もりの補正
local RES_WARN_CM      = 70   -- 交点と各線の平均距離がこれ以上なら「不確か」(敵が動いた・別の個体の線が混ざった疑い)
local AIM_NOISE_RAD     = 0.015 -- 照準のぶれ(ラジアン)。奥行き誤差の見積もりに使う
local DEPTH_ERR_WARN_CM = 450   -- 奥行き誤差の見積もりがこれ以上なら「不確か」(オレンジ)
local DEPTH_ERR_MAX_CM  = 1000  -- これ以上なら三角測量を採用しない(線がほぼ平行で、奥行きが当てにならない)
local TRI_FAR_WARN_CM   = 4000  -- 三角測量の結果がこれより遠ければ「不確か」
local TRI_DY_WARN_CM    = 800   -- 自分との高さの差がこれ以上なら「不確か」

-- 線の一覧 l から最小二乗の交点を求める。
-- 戻り値: x, y, z, rx, ry, rz, baseline, resid  (x,y,z は最新の原点 r を基準にした相対座標)
--         失敗時は nil, 理由
local function Solve(l, gyWorld, gwRatio, tauMs)
  tauMs = tauMs or WEIGHT_TAU_MS
  local n = #l
  if n < MIN_RAYS then return nil, "few-rays(" .. n .. ")" end

  local ref = l[n]
  local rx, ry, rz = ref[2], ref[3], ref[4]   -- 計算を安定させるため最新の原点を基準にする
  local rfx, rfy, rfz = ref[5], ref[6], ref[7]

  -- 横方向の基線長: 各原点が、最新の線からどれだけ離れているか
  local baseline = 0
  for i = 1, n do
    local r = l[i]
    local dx, dy, dz = r[2] - rx, r[3] - ry, r[4] - rz
    local dot = dx * rfx + dy * rfy + dz * rfz
    local px, py, pz = dx - dot * rfx, dy - dot * rfy, dz - dot * rfz
    local d = math.sqrt(px * px + py * py + pz * pz)
    if d > baseline then baseline = d end
  end
  if baseline < MIN_BASELINE_CM then return nil, "small-baseline(" .. zo_floor(baseline) .. ")" end

  -- 法線方程式 A P = b  (A = Σ(I - f fᵀ), b = Σ(I - f fᵀ) o)
  -- 重み付き: 最新の線(=敵が最後にいた位置を向いた線)ほど重くする
  local tLast = ref[1]
  local a11, a12, a13, a22, a23, a33 = 0, 0, 0, 0, 0, 0
  local b1, b2, b3 = 0, 0, 0
  local wsum = 0
  for i = 1, n do
    local r = l[i]
    local w = math.exp(-(tLast - r[1]) / tauMs)
    wsum = wsum + w
    local ox, oy, oz = r[2] - rx, r[3] - ry, r[4] - rz
    local fx, fy, fz = r[5], r[6], r[7]
    local m11, m12, m13 = w * (1 - fx * fx), w * -fx * fy, w * -fx * fz
    local m22, m23, m33 = w * (1 - fy * fy), w * -fy * fz, w * (1 - fz * fz)
    a11 = a11 + m11; a12 = a12 + m12; a13 = a13 + m13
    a22 = a22 + m22; a23 = a23 + m23; a33 = a33 + m33
    b1 = b1 + m11 * ox + m12 * oy + m13 * oz
    b2 = b2 + m12 * ox + m22 * oy + m23 * oz
    b3 = b3 + m13 * ox + m23 * oy + m33 * oz
  end

  -- 地面の高さ(敵の胸の高さの水平面)を、弱い追加条件として加える。
  -- 線がほぼ平行で奥行きが決まらない時に、交点が遠くへ飛ぶのを抑える。
  if gyWorld and gwRatio and gwRatio > 0 then
    local gw = gwRatio * wsum
    a22 = a22 + gw
    b2 = b2 + gw * (gyWorld - ry)
  end

  local det = a11 * (a22 * a33 - a23 * a23) - a12 * (a12 * a33 - a23 * a13) + a13 * (a12 * a23 - a22 * a13)
  if math.abs(det) < 1e-6 * wsum * wsum * wsum then return nil, "singular" end

  local x = (b1 * (a22 * a33 - a23 * a23) - a12 * (b2 * a33 - a23 * b3) + a13 * (b2 * a23 - a22 * b3)) / det
  local y = (a11 * (b2 * a33 - a23 * b3) - b1 * (a12 * a33 - a23 * a13) + a13 * (a12 * b3 - b2 * a13)) / det
  local z = (a11 * (a22 * b3 - b2 * a23) - a12 * (a12 * b3 - b2 * a13) + b1 * (a12 * a23 - a22 * a13)) / det

  local resid = 0
  for i = 1, n do
    local r = l[i]
    local w = math.exp(-(tLast - r[1]) / tauMs)
    local dx, dy, dz = x - (r[2] - rx), y - (r[3] - ry), z - (r[4] - rz)
    local dot = dx * r[5] + dy * r[6] + dz * r[7]
    local px, py, pz = dx - dot * r[5], dy - dot * r[6], dz - dot * r[7]
    resid = resid + w * math.sqrt(px * px + py * py + pz * pz)
  end
  resid = resid / wsum

  return x, y, z, rx, ry, rz, baseline, resid
end

-- 同名の敵が何体もいる時は、体力の連続性で「個体」を見分けて、個体ごとに線を記録する。
--   rays[名前] = { last = time, segs = { { list, hp, hpMax, last }, ... } }
-- 倒れた個体は、照準中に体力が 0 になった個体として特定できる。
local SEG_GAP_MS      = 2500 -- 照準が外れてもこの時間内なら、同じ個体への照準を再開したとみなす
local MAX_SEGS        = 6    -- 名前ごとに覚える個体の数
local DEAD_HP_RATIO   = 0.02 -- 体力がこれ以下なら「倒れた」とみなす(最大体力に対する割合)
local DEAD_WINDOW_MS  = 6000 -- 倒れた個体がいない時に「最近の個体」として使う範囲
local DEAD_MATCH_MS   = 800  -- 死亡イベントとこの時間内に体力が 0 になった個体を「倒れた個体」とみなす
local UNIT_ID_MATCH_MS = 1500 -- 照準線に記録した個体IDを死亡と結び付ける最大時間

local function RecordRay(name)
  local ok, ox, oy, oz, fx, fy, fz = pcall(GetCameraRay)
  if not ok or not ox or not fx then return end
  local t = now()

  local okp, hp, hpMax = pcall(GetUnitPower, "reticleover", COMBAT_MECHANIC_FLAGS_HEALTH)
  if not (okp and hp and hpMax) then hp, hpMax = 0, 0 end

  local e = rays[name]
  if not e then
    e = { segs = {}, last = t }
    rays[name] = e
  end
  e.last = t

  -- 体力の連続性が合う個体を探す(最大体力が同じ・体力が増えていない・最近まで照準していた)。
  -- 複数あれば、体力が最も近いもの、同じなら最後に照準していたものを選ぶ。
  local seg, bestDiff
  for _, sg in ipairs(e.segs) do
    if sg.hpMax == hpMax and t - sg.last <= SEG_GAP_MS and hp <= sg.hp + hpMax * HP_JUMP_RATIO then
      local diff = math.abs(sg.hp - hp)
      if not seg or diff < bestDiff or (diff == bestDiff and sg.last > seg.last) then
        seg, bestDiff = sg, diff
      end
    end
  end

  if not seg then
    if #e.segs > 0 and PSM.logEnabled then
      d(string.format(L("[Sul-Xan's marker] 別の個体に照準が移りました (%s 体力 %d)", "[Sul-Xan's marker] Aim switched to another individual (%s hp %d)"), name, hp))
    end
    seg = { list = {}, hp = hp, hpMax = hpMax, last = t, isNew = true, unitIds = {} }
    e.segs[#e.segs + 1] = seg
    while #e.segs > MAX_SEGS do
      local oldest = 1
      for i = 2, #e.segs do
        if e.segs[i].last < e.segs[oldest].last then oldest = i end
      end
      table.remove(e.segs, oldest)
    end
  end
  -- 体力が「減って 0 になった」瞬間を記録する(最初から体力 0 の死体を照準しただけの場合は除く)
  if hpMax > 0 then
    local dead = hp <= hpMax * DEAD_HP_RATIO
    if dead and not seg.isNew and seg.hp > hpMax * DEAD_HP_RATIO and not seg.deadAt then
      seg.deadAt = t
    end
  end
  seg.isNew = nil
  seg.hp, seg.last = hp, t

  -- A corpse can remain under the reticle and keep returning a valid position.
  -- Keep the health/death bookkeeping above, but never add its camera ray.
  if okp and hp ~= nil and hpMax and hpMax > 0 and hp <= 0 then return end

  local l = seg.list
  l[#l + 1] = { t, ox, oy, oz, fx, fy, fz }
  while #l > 0 and (#l > MAX_RAYS or l[1][1] < t - RAY_WINDOW_MS) do
    table.remove(l, 1)
  end
end

-- Combat events provide a per-instance targetUnitId, while the reticle provides
-- the unitTag needed for position sampling. Join them only when both identify
-- the same currently targeted name; this helps separate simultaneous same-name
-- enemies without assuming the soul proc itself identifies its victim.
local function OnPlayerCombatTarget(_, _, _, _, _, _, _, sourceType, targetName, _, _, _, _, _, _, targetUnitId)
  if sourceType ~= COMBAT_UNIT_TYPE_PLAYER or not targetUnitId then return end
  local name = NormalizeName(targetName)
  if not name or ReticleName() ~= name then return end
  local e = rays[name]
  if not e then return end
  local t = now()
  local best
  for _, sg in ipairs(e.segs) do
    if #sg.list > 0 and t - sg.last <= 300 and (not best or sg.last > best.last) then best = sg end
  end
  if best then
    best.unitIds = best.unitIds or {}
    best.unitIds[targetUnitId] = t
  end
end

-- 倒れた敵の個体を選ぶ。戻り値: 個体, 倒れたと確認できたか, 候補の個体数
-- deathTime: 死亡イベントの時刻。この時刻の前後で体力が 0 になった個体が「倒れた個体」。
-- (体力 0 の別の死体や、生きている同名の敵とは区別する)
local function ChooseSegment(e, deathTime, deathUnitId)
  local t = now()
  local dead, deadDiff, recent, cands = nil, nil, nil, 0
  local idMatch, idMatchAge, idMatchCount = nil, nil, 0
  for _, sg in ipairs(e.segs) do
    if #sg.list > 0 and t - sg.last <= DEAD_WINDOW_MS then
      cands = cands + 1
      local idTime = deathUnitId and sg.unitIds and sg.unitIds[deathUnitId]
      if idTime and deathTime and math.abs(idTime - deathTime) <= UNIT_ID_MATCH_MS then
        idMatchCount = idMatchCount + 1
        idMatch, idMatchAge = sg, math.abs(idTime - deathTime)
      end
      if deathTime and sg.deadAt then
        local diff = math.abs(sg.deadAt - deathTime)
        if diff <= DEAD_MATCH_MS and (not dead or diff < deadDiff) then dead, deadDiff = sg, diff end
      end
      if not recent or sg.last > recent.last then recent = sg end
    end
  end
  -- A unique ID hit is still ambiguous if multiple same-name ray segments are
  -- active: the reticle exposes a name, not the unitId, so the hit could have
  -- belonged to another same-name enemy (for example from an AoE).
  if idMatchCount == 1 and cands == 1 then return idMatch, true, cands, "unitId", idMatchAge end
  if dead then return dead, true, cands, "hp-time" end
  -- 同名の敵を複数追跡していて死亡個体を特定できない場合、
  -- 最新の線を本命として使うと別個体の位置を採用するおそれがある。
  if cands > 1 then return nil, false, cands, "ambiguous-segments" end
  return recent, false, cands, "recent"
end

local function RecentSegmentCount(e, t)
  if not e then return 0 end
  t = t or now()
  local count = 0
  for _, sg in ipairs(e.segs) do
    if #sg.list > 0 and t - sg.last <= DEAD_WINDOW_MS then count = count + 1 end
  end
  return count
end

-- 点(最新の原点基準)と、線 r との距離
local function RayDist(r, x, y, z, rx, ry, rz)
  local dx, dy, dz = x - (r[2] - rx), y - (r[3] - ry), z - (r[4] - rz)
  local dot = dx * r[5] + dy * r[6] + dz * r[7]
  local px, py, pz = dx - dot * r[5], dy - dot * r[6], dz - dot * r[7]
  return math.sqrt(px * px + py * py + pz * pz)
end

-- 診断用: この名前の各個体の「体力%」と、体力が 0 になった時刻と死亡イベントの時刻差
local function SegDiag(e, deathTime)
  local parts = {}
  local t = now()
  for _, sg in ipairs(e.segs) do
    if #sg.list > 0 and t - sg.last <= DEAD_WINDOW_MS then
      local pct = (sg.hpMax and sg.hpMax > 0) and zo_floor(sg.hp * 100 / sg.hpMax) or -1
      local dd = ""
      if sg.deadAt and deathTime then dd = string.format("@%+dms", sg.deadAt - deathTime)
      elseif sg.deadAt then dd = "@dead" end
      parts[#parts + 1] = string.format("%d%%%s", pct, dd)
    end
  end
  return table.concat(parts, "/")
end

-- One compact line per tracked segment: all observed UnitIds, their last link
-- timestamps (game-time milliseconds), and their age at the soul-drop event.
local function SegmentIdDiag(name, eventTime)
  local e = name and rays[name]
  if not e then return "no-tracks" end
  local parts = {}
  local t = now()
  for i, sg in ipairs(e.segs) do
    if #sg.list > 0 and t - sg.last <= DEAD_WINDOW_MS then
      local ids = {}
      for id, linkedAt in pairs(sg.unitIds or {}) do
        ids[#ids + 1] = string.format("%s@%d(age=%d)", tostring(id), linkedAt, math.max(0, eventTime - linkedAt))
      end
      table.sort(ids)
      local deadAt = sg.deadAt and tostring(sg.deadAt) or "-"
      parts[#parts + 1] = string.format("s%d(ray=%d,dead=%s,ids=%s)", i, sg.last, deadAt,
        #ids > 0 and table.concat(ids, "/") or "-")
    end
  end
  return #parts > 0 and table.concat(parts, ";") or "no-recent-tracks"
end

-- 戻り値: { x, y, z }, 説明文, 不確かか  /  失敗時は nil, 理由
local function Triangulate(name, deathTime, deathUnitId)
  local e = name and rays[name]
  if not e then return nil, "no-rays" end
  local seg, isDead, cands, matchMethod, unitIdAgeMs = ChooseSegment(e, deathTime, deathUnitId)
  if not seg then return nil, matchMethod or "no-recent-rays" end
  -- 通常は直近4秒の線を使う(長い範囲の線は、あとで敵が止まっていると確認できた時だけ使う)
  local full = seg.list
  local tLastRay = deathTime or full[#full][1]
  local l = {}
  for _, r in ipairs(full) do
    if r[1] >= tLastRay - RAY_WINDOW_MS and r[1] <= tLastRay then l[#l + 1] = r end
  end
  local n = #l
  local tauMs = ((PSM.sv.weightTau or 1.5) * 1000)

  -- 地面の高さの条件: 直近の三角測量で高さの差が分かっていれば強め、未知(平地と仮定)なら弱めにする
  local gyWorld, gwRatio
  if PSM.sv.useGround ~= false then
    local _, _, gpy = GetUnitRawWorldPosition("player")
    if gpy then
      local known = PSM.groundDy and PSM.groundDyTime and now() - PSM.groundDyTime <= GROUND_DY_KEEP_MS
      gyWorld = gpy + (known and PSM.groundDy or 0) + AIM_PLANE_HEIGHT_CM
      gwRatio = known and GROUND_W_KNOWN or GROUND_W_UNKNOWN
    end
  end

  -- まず地面の条件なしで解く。奥行きの誤差の見積もりが大きい(線がほぼ平行)時だけ、
  -- 地面の条件を加えて解き直す(奥行きが十分決まる時は、坂などで悪影響が出ないよう使わない)
  local usedGround = false
  local function SolveAuto(list, tauOverride)
    local tau = tauOverride or tauMs
    local a1, a2, a3, a4, a5, a6, a7, a8 = Solve(list, nil, nil, tau)
    if a1 and gyWorld then
      local dd = math.sqrt(a1 * a1 + a2 * a2 + a3 * a3)
      if dd * dd * AIM_NOISE_RAD / a7 > GROUND_USE_DERR_CM then
        local b1, b2, b3, b4, b5, b6, b7, b8 = Solve(list, gyWorld, gwRatio, tau)
        if b1 then usedGround = true; return b1, b2, b3, b4, b5, b6, b7, b8 end
      end
    end
    return a1, a2, a3, a4, a5, a6, a7, a8
  end

  local x, y, z, rx, ry, rz, baseline, resid = SolveAuto(l)
  if not x then return nil, y end   -- 失敗時 y に理由が入る

  -- 誤差が大きい時は、外れた線(別の個体や、照準のぶれ)を除いてもう一度解く
  local trimmed = 0
  if resid > MAX_RESIDUAL_CM then
    local keep = {}
    local lim = math.max(resid * 1.5, 80)
    for i = 1, n do
      if RayDist(l[i], x, y, z, rx, ry, rz) <= lim then keep[#keep + 1] = l[i] end
    end
    if #keep < MIN_RAYS or #keep == n then return nil, "large-residual(" .. zo_floor(resid) .. ")" end
    local x2, y2, z2, rx2, ry2, rz2, b2, r2 = SolveAuto(keep)
    if not x2 or r2 > MAX_RESIDUAL_CM then return nil, "large-residual(" .. zo_floor(resid) .. ")" end
    trimmed = n - #keep
    l, n = keep, #keep
    x, y, z, rx, ry, rz, baseline, resid = x2, y2, z2, rx2, ry2, rz2, b2, r2
  end

  -- Defense in depth: even if a future solver path bypasses Solve()'s check,
  -- never emit a successful triangulation below the configured baseline.
  if baseline < MIN_BASELINE_CM then
    return nil, "small-baseline-final(" .. zo_floor(baseline) .. ")"
  end

  -- 妥当性チェック: カメラからの距離
  local dist = math.sqrt(x * x + y * y + z * z)
  if dist < 150 or dist > MAX_RAY_CM then return nil, "bad-distance(" .. zo_floor(dist) .. ")" end

  -- 奥行きの誤差の見積もり: 距離が遠く、自分の横移動(基線長)が小さいほど大きい
  -- (線がほぼ平行だと、交点が遠くへ大きくずれる)
  local depthErr = dist * dist * AIM_NOISE_RAD / baseline
  if usedGround then depthErr = depthErr * GROUND_DERR_FACTOR end  -- 地面の条件で奥行きが補強された分
  if depthErr > DEPTH_ERR_MAX_CM then return nil, "depth-uncertain(" .. zo_floor(depthErr) .. ")" end

  -- 最新の線(死亡直前に狙っていた先)が交点から離れていれば、別の敵を追っている疑いがある
  local lastOff = RayDist(l[#l], x, y, z, rx, ry, rz)
  -- 倒れた個体を体力で確認できない時も不確か
  local doubtful = trimmed > 0 or lastOff > LAST_RAY_OFF_CM or not isDead
                  or depthErr > DEPTH_ERR_WARN_CM or dist > TRI_FAR_WARN_CM or resid > RES_WARN_CM
                  or cands > 1
                  or (matchMethod == "unitId" and unitIdAgeMs and unitIdAgeMs > 500)

  -- 照準は敵の胸あたりに当たっている想定なので、足元の高さに下げる
  -- 敵が動いていても、最新の線(=死亡の直前に照準していた先)の上には必ずいる。
  -- 交点を最新の線の上に落とす: 横方向のずれが消え、奥行きだけが交点の推定になる。
  local ref = l[n]
  local k = x * ref[5] + y * ref[6] + z * ref[7]
  if k < 150 then k = 150 end
  local shift = math.sqrt((x - ref[5] * k) ^ 2 + (y - ref[6] * k) ^ 2 + (z - ref[7] * k) ^ 2)
  x, y, z = ref[5] * k, ref[6] * k, ref[7] * k

  local pos = { x + rx, y + ry - AIM_PLANE_HEIGHT_CM, z + rz }
  -- 自分との高さの差が大きすぎる位置も不確か
  local _, _, ppy = GetUnitRawWorldPosition("player")
  if ppy and math.abs(pos[2] - ppy) > TRI_DY_WARN_CM then doubtful = true end
  local quality = {
    uncertain = doubtful == true or trimmed > 0 or not isDead or lastOff > LAST_RAY_OFF_CM,
    trimmed = trimmed,
    isDead = isDead,
    matchMethod = matchMethod,
    unitIdAgeMs = unitIdAgeMs,
    lastOff = lastOff,
    residual = resid,
    baseline = baseline,
  }
  return pos, string.format("tri(n=%d,base=%d/%dcm,res=%dcm,dist=%dm,derr=%dcm,last=%dcm,proj=%dcm,trim=%d,win=%.1fs,gnd=%s,%s%d)",
    n, zo_floor(baseline), MIN_BASELINE_CM, zo_floor(resid), zo_floor(dist / 100), zo_floor(depthErr), zo_floor(lastOff), zo_floor(shift), trimmed, (l[n][1] - l[1][1]) / 1000, usedGround and (gwRatio >= GROUND_W_KNOWN and "known" or "flat") or "off",
    isDead and (matchMethod .. "/") or "alive/", cands) .. " segs=" .. SegDiag(e, deathTime)
    .. " idms=" .. tostring(unitIdAgeMs or "-"), quality
end

-- 古い記録を定期的に捨てる(同じゾーンに長くいても、メモリが増え続けないように)
local sampleTicks = 0
local function PurgeOld()
  local t = now()
  for name, s in pairs(samples) do
    if t - s[4] > SAMPLE_KEEP_MS then samples[name] = nil end
  end
  for name, e in pairs(rays) do
    if t - e.last > SAMPLE_KEEP_MS then rays[name] = nil end
  end
  for name, ft in pairs(friendlyNames) do
    if t - ft > SAMPLE_KEEP_MS then friendlyNames[name] = nil end
  end
end

-- 魂を拾った時点より前の位置情報を破棄する。
-- preserveAfter を渡す場合は、拾得直後に集められた新しい記録だけ残す。
local function ClearPositionHistory(preserveAfter)
  local cutoff = preserveAfter
  if not cutoff then
    lastPos = nil
    samples = {}
    rays = {}
    return
  end

  if lastPos and lastPos[4] <= cutoff then lastPos = nil end
  for name, sample in pairs(samples) do
    if not sample[4] or sample[4] <= cutoff then samples[name] = nil end
  end

  for name, e in pairs(rays) do
    local keptSegments = {}
    local newest = nil
    for _, seg in ipairs(e.segs or {}) do
      local keptRays = {}
      for _, ray in ipairs(seg.list or {}) do
        if ray[1] > cutoff then keptRays[#keptRays + 1] = ray end
      end
      seg.list = keptRays
      if seg.deadAt and seg.deadAt <= cutoff then seg.deadAt = nil end
      for unitId, time in pairs(seg.unitIds or {}) do
        if time <= cutoff then seg.unitIds[unitId] = nil end
      end
      if #keptRays > 0 then
        seg.last = keptRays[#keptRays][1]
        keptSegments[#keptSegments + 1] = seg
        if not newest or seg.last > newest then newest = seg.last end
      end
    end
    if #keptSegments == 0 then
      rays[name] = nil
    else
      e.segs = keptSegments
      e.last = newest
    end
  end
end

local function SampleTarget()
  sampleTicks = sampleTicks + 1
  if sampleTicks >= 100 then   -- 約5秒ごと
    sampleTicks = 0
    PurgeOld()
  end

  if IsHostileTarget() then
    local x, y, z, src = GetTargetPos()
    local name = ReticleName()
    if x then
      lastPos = { x, y, z, now(), src }
      if name then samples[name] = lastPos end
    end
    -- 照準の線は、水平面との交点が取れない時(敵が自分より高い位置にいて上向きに照準している時)も記録する
    if name then RecordRay(name) end
  elseif DoesUnitExist("reticleover") and not IsUnitPlayer("reticleover") then
    -- 敵ではないNPC・ペット等: 死亡イベントで敵と間違えないよう名前を覚える
    local fname = ReticleName()
    if fname then friendlyNames[fname] = now() end
  end
end

-- 魂が落ちた位置(=倒した敵の位置)の暫定推定。優先順位:
--   1. 今照準している敵の位置
--   2. 直近に照準していた敵の位置
-- (倒した敵の名前が分かる場合の補正は、OnSoulDrop 内で行う)
local function GetDropPosition()
  local t = now()

  if IsHostileTarget() then
    local x, y, z, src = GetTargetPos()
    if x then return { x, y, z }, src end
  end
  if lastPos and t - lastPos[4] <= POS_MAX_AGE_MS then
    return { lastPos[1], lastPos[2], lastPos[3] }, "last(" .. tostring(lastPos[5]) .. ")"
  end
end

-- ----------------------------------------------------------------------------
-- ワールド描画 (LibCombatAlerts)
-- ----------------------------------------------------------------------------

local function PackColor(c)
  local function b(v) return zo_floor((v or 1) * 255 + 0.5) end
  return b(c[1]) * 0x1000000 + b(c[2]) * 0x10000 + b(c[3]) * 0x100 + b(c[4])
end

local function Remove3D()
  if canvas then
    for _, m in ipairs(markers) do
      if m.id then canvas:RemoveElement(m.id) end
      if m.numId then canvas:RemoveElement(m.numId) end
    end
  end
  markers = {}
end

local UNCERTAIN_COLOR = { 1, 0.55, 0.1, 1 }  -- 位置が不確かな時の色(オレンジ)
local FALLBACK_COLOR = { 1, 0, 0, 1 }         -- 位置不明時の画面マーカーは赤
local FALLBACK_LEFT_FACTOR = 1.35            -- キャラクターの中央位置から左へずらす幅(サイズ倍率)

-- 矢印の中の残り秒数(LibCombatAlerts の数字テクスチャ "world-num-0"〜"world-num-12")
local NUM_SCALE             = 0.34       -- 矢印の大きさに対する数字の大きさ
local NUM_Y                 = 0.10       -- 数字を矢印の中心より上にずらす量(矢印の大きさの割合)
local NUM_TOWARD_CAMERA_CM  = 60         -- 矢印より手前に描くため、カメラ側へ寄せる量
local COUNTDOWN_COLOR       = 0x000000FF -- 数字の色(黒)

local function CountdownSec()
  local sec = zo_ceil((PSM.endTime - now()) / 1000)
  if sec < 0 then sec = 0 end
  if sec > 12 then sec = 12 end
  return sec
end

local function Place3D(pos, uncertain, sizeScale)
  if not (LCA and LCA.WorldDrawing) then return false end
  local sv = PSM.sv
  local markerSize = sv.size3D * (sizeScale or 1)
  local color = (uncertain and sv.markUncertain) and UNCERTAIN_COLOR or sv.color
  local ok, id = pcall(function()
    canvas = canvas or LCA.WorldDrawing:New()
    return canvas:PlaceTexture({
      texture             = ARROW_TEXTURE,
      pos                 = pos,
      size                = markerSize,
      elevation           = sv.height,
      playerFacing        = true,
      color               = PackColor(color),
      disableDepthBuffers = true, -- 地形や壁に隠れない
    })
  end)
  if not (ok and id) then return false end

  local m = { id = id, pos = pos, size = markerSize }
  markers[#markers + 1] = m

  -- 矢印の中に残り秒数を表示
  if sv.showCountdown then
    local sec = CountdownSec()
    local ok2, id2 = pcall(function()
      return canvas:PlaceTexture({
        texture             = "world-num-" .. sec,
        pos                 = pos,
        size                = markerSize * NUM_SCALE,
        elevation           = sv.height + markerSize * NUM_Y,
        playerFacing        = true,
        color               = COUNTDOWN_COLOR,
        disableDepthBuffers = true,
      })
    end)
    if ok2 and id2 then
      m.numId = id2
      m.numSec = sec
    end
  end
  return true
end

-- 数字の位置・高さ・秒数を更新する。数字は矢印より手前に描かれるように、
-- カメラ側へ少し寄せる(同じ視線上なので、画面上の位置は変わらない)
local function UpdateCountdown(m, arrowElev, sec)
  if not (canvas and m.numId and m.pos) then return end
  local sv = PSM.sv
  local pos = m.pos
  local sx, sy, sz = 0, 0, 0
  local ok, ox, oy, oz = pcall(GetCameraRay)
  if ok and ox then
    local dx, dy, dz = ox - pos[1], oy - (pos[2] + arrowElev), oz - pos[3]
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len > 1 then
      local k = NUM_TOWARD_CAMERA_CM / len
      sx, sy, sz = dx * k, dy * k, dz * k
    end
  end
  canvas:UpdateTexture(m.numId, "pos", { pos[1] + sx, pos[2], pos[3] + sz })
  canvas:UpdateTexture(m.numId, "elevation", arrowElev + (m.size or sv.size3D) * NUM_Y + sy)
  if sec ~= m.numSec then
    m.numSec = sec
    canvas:UpdateTexture(m.numId, "texture", "world-num-" .. sec)
  end
end

-- ----------------------------------------------------------------------------
-- 画面表示 (フォールバック / 残り時間 / 移動モード)
-- ----------------------------------------------------------------------------

local function CreateUI()
  local wm  = GetWindowManager()
  local win = wm:CreateTopLevelWindow(PSM.name .. "_Window")
  win:SetClampedToScreen(true)
  win:SetMouseEnabled(false)
  win:SetMovable(false)
  win:SetHidden(true)
  win:SetDrawLayer(DL_OVERLAY)
  win:SetDrawTier(DT_HIGH)

  local icon = wm:CreateControl(nil, win, CT_TEXTURE)
  LCA.SetTexture(icon, ARROW_TEXTURE)
  icon:SetAnchor(TOP, win, TOP, 0, 0)

  local label = wm:CreateControl(nil, win, CT_LABEL)
  label:SetFont("$(BOLD_FONT)|28|soft-shadow-thick")
  label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  label:SetColor(1, 1, 1, 1)

  win:SetHandler("OnMoveStop", function(self)
    local sv = PSM.sv
    if not sv then return end
    local cx, cy = self:GetCenter()
    sv.offsetX = math.floor(cx - GuiRoot:GetWidth()  / 2)
    sv.offsetY = math.floor(cy - GuiRoot:GetHeight() / 2)
  end)

  ui = { win = win, icon = icon, label = label }
end

function PSM.ApplyLayout()
  if not ui then return end
  local sv   = PSM.sv
  local size = sv.size2D

  ui.win:SetDimensions(size, size + math.floor(size * 0.35))
  ui.win:ClearAnchors()
  -- 位置が取れない時の画面マーカー、およびドラッグ用プレビューは、常に赤い丸形で表示する
  local useFallbackStyle = PSM.fallbackVisible or PSM.unlocked
  local fallbackOffsetX = useFallbackStyle and -math.floor(size * FALLBACK_LEFT_FACTOR) or 0
  ui.win:SetAnchor(CENTER, GuiRoot, CENTER, sv.offsetX + fallbackOffsetX, sv.offsetY)

  ui.icon:SetDimensions(size, size)
  ui.icon:ClearAnchors()
  ui.icon:SetAnchor(TOP, ui.win, TOP, 0, 0)
  -- LibCombatAlerts のテクスチャIDは、LCA.SetTexture でパスと切り出し座標に変換して設定する
  LCA.SetTexture(ui.icon, useFallbackStyle and FALLBACK_TEXTURE or ARROW_TEXTURE)
  ui.icon:SetColor(unpack(useFallbackStyle and FALLBACK_COLOR or sv.color))

  -- 残り秒数: 矢印の時は中心より少し上、赤い丸(位置不明・プレビュー)の時は丸の中央に表示する
  ui.label:ClearAnchors()
  ui.label:SetAnchor(CENTER, ui.icon, CENTER, 0, useFallbackStyle and 0 or -math.floor(size * NUM_Y))
  ui.label:SetDimensions(size, math.floor(size * 0.5))
  ui.label:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", math.max(12, zo_floor(size * 0.34))))
  ui.label:SetColor(0, 0, 0, 1)
end

-- 画面表示の出し分け: iconVisible = ↓ を画面に出すか
local function ApplyScreenVisibility(iconVisible)
  local sv = PSM.sv
  local show = iconVisible or PSM.unlocked
  ui.icon:SetHidden(not show)
  ui.label:SetHidden(not (show and sv.showCountdown))
  ui.win:SetHidden(not show)
end

-- ----------------------------------------------------------------------------
-- 表示制御
-- ----------------------------------------------------------------------------

local function OnUpdate()
  local sv = PSM.sv
  local t  = now()

  if PSM.unlocked then
    ui.label:SetText("6")   -- 移動モード: サンプル表示
    return
  end

  local remain = PSM.endTime - t
  if remain <= 0 then
    if activeSoulInterval and activeSoulInterval.finish == nil then
      activeSoulInterval.finish = activeSoulInterval.expectedFinish
    end
    PSM.Hide()
    return
  end

  -- 残り秒数(整数・切り上げ。6 → 5 → ... → 1)
  local sec = zo_ceil(remain / 1000)
  if sec > 12 then sec = 12 end

  if #markers > 0 and canvas then
    -- ワールド表示: 矢印を上下に動かし、数字をそれに合わせる
    for _, m in ipairs(markers) do
      local markerElev = sv.height
      if sv.bob then markerElev = sv.height + math.sin(t / 140) * (m.size or sv.size3D) * 0.12 end
      if sv.bob then canvas:UpdateTexture(m.id, "elevation", markerElev) end
      UpdateCountdown(m, markerElev, sec)
    end
  elseif not ui.icon:IsHidden() then
    -- 画面表示(位置が取れなかった時)
    if sv.showCountdown then
      ui.label:SetText(tostring(sec))
    end
    if sv.bob then
      ui.icon:ClearAnchors()
      ui.icon:SetAnchor(TOP, ui.win, TOP, 0, math.sin(t / 140) * sv.size2D * 0.08)
    end
  end
end

local function StartUpdate()
  EM:UnregisterForUpdate(UPDATE_NAME)
  EM:RegisterForUpdate(UPDATE_NAME, 30, OnUpdate)
end

-- extras: 他の候補の位置の一覧 { {x,y,z}, ... }(同時に複数の種類の敵が倒れた時。オレンジで表示)
function PSM.Show(durationMs, pos, uncertain, extras, allAreCandidates)
  if not ui then return end
  local sv = PSM.sv
  if not sv.enabled then return end

  local t = now()
  PSM.shownAt = t
  PSM.endTime = t + durationMs

  Remove3D()
  local placed = false
  if sv.use3D and pos then
    placed = Place3D(pos, uncertain, allAreCandidates and CANDIDATE_MARKER_SCALE or nil)
    if placed and extras then
      for _, ep in ipairs(extras) do
        Place3D(ep, true, allAreCandidates and CANDIDATE_MARKER_SCALE or nil)
      end
    end
  end

  PSM.fallbackVisible = not placed
  PSM.ApplyLayout()
  ApplyScreenVisibility(not placed)
  StartUpdate()
end

function PSM.Hide()
  PSM.endTime = 0
  PSM.testing = false
  PSM.fallbackVisible = false
  Remove3D()
  if ui then PSM.ApplyLayout() end
  if PSM.unlocked then
    ApplyScreenVisibility(true)
    return
  end
  EM:UnregisterForUpdate(UPDATE_NAME)
  if ui then
    ui.icon:ClearAnchors()
    ui.icon:SetAnchor(TOP, ui.win, TOP, 0, 0)
    ui.win:SetHidden(true)
  end
end

local function IsDeathInsideSoulInterval(deathTime, intervals)
  if not deathTime then return false end
  for _, interval in ipairs(intervals or soulDeathIntervals) do
    local finish = interval.finish or interval.expectedFinish
    if deathTime >= interval.start and deathTime <= finish then return true end
  end
  return false
end

function PSM.SetUnlocked(unlocked)
  PSM.unlocked = unlocked and true or false
  if not ui then return end
  if PSM.unlocked then
    -- The drag preview represents the no-position screen marker.
    PSM.fallbackVisible = true
    PSM.ApplyLayout()
  end
  ui.win:SetMouseEnabled(PSM.unlocked)
  ui.win:SetMovable(PSM.unlocked)
  if PSM.unlocked then
    ApplyScreenVisibility(true)
    StartUpdate()
  else
    PSM.Hide()
  end
end

function PSM.Test()
  PSM.testing = true
  local pos = GetDropPosition()
  if not pos then
    local x, y, z = ReadPos("player")
    if x then pos = { x, y, z } end
  end
  PSM.Show(8000, pos)
end

-- ----------------------------------------------------------------------------
-- 戦闘イベント
-- ----------------------------------------------------------------------------

-- (eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType,
--  sourceName, sourceType, targetName, targetType, hitValue, ...)
local function OnSoulDrop(_, result, _, _, _, _, sourceName, sourceType, targetName, targetType, hitValue, _, _, _, sourceUnitId, targetUnitId)
  -- 魂のドロップは GAINED_DURATION(hitValue = 持続時間 約6000ms)。
  -- 直前に来る GAINED(hitValue=1)は持続時間が入っていないので使わない。
  if PSM.logEnabled then
    -- 魂のイベントの対象は自分自身なので、キャラクター名はログに出さない(ログを人に見せても名前が出ないように)
    d(string.format("[Sul-Xan's marker] soul event: result=%s hit=%s targetType=%s unitId src=%s tgt=%s",
      tostring(result), tostring(hitValue), tostring(targetType),
      tostring(sourceUnitId), tostring(targetUnitId)))
  end
  if result ~= ACTION_RESULT_EFFECT_GAINED_DURATION then
    return
  end
  local soulTargetId = targetUnitId
  local t = now()

  -- 魂は同時に1つしか出ない。表示中に来た追加イベントでは位置を動かさない
  -- (動かすと、その時の照準先へ矢印が移ってしまう)
  if (PSM.endTime > t or PSM.pending) and not PSM.testing then
    if PSM.logEnabled then
      d(string.format("[Sul-Xan's marker] soul event ignored (active, %.1fs left, hit=%s)", (PSM.endTime - t) / 1000, tostring(hitValue)))
    end
    return
  end

  local duration = DEFAULT_DURATION_MS
  if hitValue and hitValue >= 1000 then duration = hitValue end

  -- この魂の出現中に記録された死亡は、次回以降の魂位置推定に混ぜない。
  -- 拾得が先に起きた場合は OnSoulPickup で実際の終了時刻に短縮する。
  activeSoulInterval = { start = t, expectedFinish = t + duration }
  soulDeathIntervals[#soulDeathIntervals + 1] = activeSoulInterval
  while #soulDeathIntervals > 0 and soulDeathIntervals[1].expectedFinish < t - 5000 do
    table.remove(soulDeathIntervals, 1)
  end
  local intervalsForThisDrop = soulDeathIntervals

  -- この瞬間の照準を記録しておく(倒された敵の名前は、少し遅れて届く死亡イベントで分かる)
  local snap
  if IsHostileTarget() then
    local x, y, z, s = GetTargetPos()
    if x then snap = { pos = { x, y, z }, name = ReticleName(), src = s } end
  end
  local earlyPos, earlySrc = GetDropPosition()

  PSM.testing = false
  PSM.pending = true
  PSM.pendingPickup = false

  zo_callLater(function()
    PSM.pending = false
    -- 待っている間にスルザンを外した場合は、何も出さない(完全停止)
    if not PSM.active then return end
    -- Show a brief cue if the soul was picked up before this delayed callback.
    local pickedUpBeforeDisplay = PSM.sv.hideOnPickup and PSM.pendingPickup
    PSM.pendingPickup = false
    if pickedUpBeforeDisplay and PSM.logEnabled then
      d(L("[Sul-Xan's marker] 表示前に拾得済みのため、短時間表示します", "[Sul-Xan's marker] Picked up before display; showing marker briefly"))
    end
    local pos, src = earlyPos, earlySrc

    -- 魂イベントが敵のUnitIdを示す場合は、時刻よりID一致を優先する。
    -- 自分自身を対象とするバフイベントのIDは敵IDとして使わない。
    local playerType = _G["COMBAT_UNIT_TYPE_PLAYER"]
    local usableSoulTargetId = soulTargetId and soulTargetId ~= sourceUnitId
      and (not playerType or targetType ~= playerType)
    local candidateDeaths = {}
    for i = #recentDeaths, 1, -1 do
      local dd = recentDeaths[i]
      if dd.time >= t - CANDIDATE_DEATH_WINDOW_MS and dd.time <= t
          and not IsDeathInsideSoulInterval(dd.time, intervalsForThisDrop) then
        candidateDeaths[#candidateDeaths + 1] = dd
      end
    end
    local matchedDeath
    if usableSoulTargetId then
      for _, dd in ipairs(candidateDeaths) do
        if dd.unitId == soulTargetId then matchedDeath = dd; break end
      end
    end
    local chosen = matchedDeath
    local chosenReason = matchedDeath and "soul-unitId" or "none"
    if not chosen then
      for i = #recentDeaths, 1, -1 do
        local dd = recentDeaths[i]
        if dd.time >= t - DEATH_BEFORE_MS and dd.time <= t
            and not IsDeathInsideSoulInterval(dd.time, intervalsForThisDrop) then
          chosen = dd
          chosenReason = "recent-death-time"
          break
        end
      end
    end
    if not chosen and lastDeath and lastDeath.time >= t - DEATH_BEFORE_MS and lastDeath.time <= t
        and not IsDeathInsideSoulInterval(lastDeath.time, intervalsForThisDrop) then
      chosen = lastDeath
      chosenReason = "lastDeath-time"
    end

    local targetName = snap and snap.name
    if chosen then
      targetName = chosen.name
      -- 魂イベント時の照準先が死亡個体と違う場合の位置を持ち越さない。
      -- 死亡個体の線から再計算できない場合は、同名追跡が一意な時だけ補助位置を使う。
      pos, src = nil, nil
      local sample = samples[chosen.name]
      local activeTracks = RecentSegmentCount(rays[chosen.name], now())
      if activeTracks <= 1 and snap and snap.name == chosen.name then
        pos, src = snap.pos, "death+snap(" .. tostring(snap.src) .. ")"
      elseif activeTracks <= 1 and sample and now() - sample[4] <= CANDIDATE_DEATH_WINDOW_MS then
        pos, src = { sample[1], sample[2], sample[3] }, "death+name(" .. tostring(sample[5]) .. ")"
      end
    end

    -- 照準の線の交点が求まれば、それが最も正確(坂道でもずれにくい)
    local e = targetName and rays[targetName]
    local triPos, triInfo, triQuality
    if e and now() - e.last <= SAMPLE_KEEP_MS then
      triPos, triInfo, triQuality = Triangulate(targetName, (chosen and chosen.name == targetName) and chosen.time or nil, (chosen and chosen.name == targetName) and chosen.unitId or nil)
    else
      triInfo = "no-recent-rays"
    end
    if triPos then
      pos, src = triPos, "death+" .. triInfo
    elseif PSM.logEnabled then
      d("[Sul-Xan's marker] triangulation skipped: " .. tostring(triInfo))
    end
    local ambiguousTrack = triInfo == "ambiguous-segments"

    -- 位置が不確かかどうか: 三角測量が使えなかった / 同名の敵が同時に複数倒れた
    local sameNameDeaths, idMatch, otherDeaths = 0, matchedDeath ~= nil, 0
    for _, dd in ipairs(recentDeaths) do
      if dd.time >= t - DEATH_BEFORE_MS and dd.time <= t
          and not IsDeathInsideSoulInterval(dd.time, intervalsForThisDrop) then
        if dd.name == targetName then sameNameDeaths = sameNameDeaths + 1 else otherDeaths = otherDeaths + 1 end
        if usableSoulTargetId and dd.unitId == soulTargetId then idMatch = true end
      end
    end
    -- A successful position is not automatically reliable: retain uncertainty
    -- if quality metadata is absent or contradicts the measurements themselves.
    local triUncertain = true
    if triPos and type(triQuality) == "table" then
      local trimmed = tonumber(triQuality.trimmed)
      local lastOff = tonumber(triQuality.lastOff)
      local unitIdAge = tonumber(triQuality.unitIdAgeMs)
      triUncertain = triQuality.uncertain ~= false
        or not trimmed or trimmed > 0
        or triQuality.isDead ~= true
        or not lastOff or lastOff > LAST_RAY_OFF_CM
        or (triQuality.matchMethod == "unitId" and (not unitIdAge or unitIdAge > 500))
        or false
    end
    local uncertain = (not triPos) or sameNameDeaths > 1 or otherDeaths > 0
      or triUncertain or (usableSoulTargetId and not matchedDeath)

    if PSM.logEnabled then
      StoreDiagnostic(string.format("DROP t=%d soulTarget=%s usableTargetId=%s chosen=%s chosenId=%s chosenT=%s select=%s tri=%s track={%s}",
        t, tostring(soulTargetId), tostring(usableSoulTargetId), tostring(chosen and chosen.name or "nil"),
        tostring(chosen and chosen.unitId or "nil"), tostring(chosen and chosen.time or "nil"),
        chosenReason, tostring(triInfo), SegmentIdDiag(targetName, t)))
      for _, dd in ipairs(candidateDeaths) do
        StoreDiagnostic(string.format("DEATH-CAND t=%d name=%s id=%s deathT=%d age=%d track={%s}",
          t, tostring(dd.name), tostring(dd.unitId), dd.time, t - dd.time, SegmentIdDiag(dd.name, t)))
      end
    end

    local loggedDeathName = chosen and chosen.name or "nil"
    local function LogSoulDrop()
      if not PSM.logEnabled then return end
      d(string.format("[Sul-Xan's marker] soul drop: hit=%s pos=%s src=%s death=%s sameNameDeaths=%d otherDeaths=%d idMatch=%s uncertain=%s",
        tostring(hitValue),
        pos and string.format("%d,%d,%d", pos[1], pos[2], pos[3]) or "nil", tostring(src),
        tostring(loggedDeathName), sameNameDeaths, otherDeaths, tostring(idMatch), tostring(uncertain)))
    end

    -- 複数の死亡が重なった場合、ひとつを本命扱いせず、位置を計算できた
    -- 死亡個体すべてを小さい候補マーカーとして表示する。
    local extras, candidateByDeath, seen = {}, {}, {}
    local dedupedDeaths = {}
    for _, dd in ipairs(candidateDeaths) do
      local key = dd.unitId or (tostring(dd.name) .. ":" .. tostring(dd.time))
      if not seen[key] then
        seen[key] = true
        dedupedDeaths[#dedupedDeaths + 1] = dd
      end
    end
    candidateDeaths = dedupedDeaths
    -- IDで発生元が特定できた場合は、その個体だけを位置候補にする。
    if matchedDeath then candidateDeaths = { matchedDeath } end
    local allAreCandidates = (#candidateDeaths > 1 or ambiguousTrack) and PSM.sv.showCandidates ~= false
    if allAreCandidates then
      local nameCounts = {}
      for _, dd in ipairs(candidateDeaths) do nameCounts[dd.name] = (nameCounts[dd.name] or 0) + 1 end
      for _, dd in ipairs(candidateDeaths) do
        local ep, einfo, quality = Triangulate(dd.name, dd.time, dd.unitId)
        local positionMethod = "tri"
        -- 候補線の幾何が整っていても、死亡個体のHP遷移またはUnitIdで
        -- 照準線との対応を確認できない三角測量は候補に加えない。
        if ep and (type(quality) ~= "table" or quality.isDead ~= true) then
          ep = nil
          einfo = "unverified-death-track"
        end
        -- 三角測量に必要な照準線が足りない場合でも、死亡個体名と一致する
        -- ドロップ時スナップショットか直近の位置サンプルが一意かつ新鮮なら候補に使う。
        local uniqueNameTrack = nameCounts[dd.name] == 1
          and RecentSegmentCount(rays[dd.name], now()) <= 1
        if not ep and einfo ~= "ambiguous-segments" and uniqueNameTrack and snap and snap.name == dd.name then
          ep, positionMethod = snap.pos, "snap"
        end
        if not ep then
          local sample = samples[dd.name]
          if einfo ~= "ambiguous-segments" and uniqueNameTrack and sample and now() - sample[4] <= CANDIDATE_DEATH_WINDOW_MS then
            ep = { sample[1], sample[2], sample[3] }
            positionMethod = "sample(" .. tostring(sample[5]) .. ")"
          end
        end
        if ep then
          local distinct = true
          for _, prior in ipairs(candidateByDeath) do
            local dx, dy, dz = ep[1] - prior.pos[1], ep[2] - prior.pos[2], ep[3] - prior.pos[3]
            if math.sqrt(dx * dx + dy * dy + dz * dz) < 100 then distinct = false; break end
          end
          if distinct and #candidateByDeath < MAX_CANDIDATE_MARKERS then
            candidateByDeath[#candidateByDeath + 1] = {
              pos = ep, name = dd.name, method = positionMethod,
              time = dd.time, unitId = dd.unitId,
            }
            if PSM.logEnabled then
              StoreDiagnostic(string.format("CANDIDATE name=%s id=%s deathT=%d result=shown method=%s detail=%s",
                tostring(dd.name), tostring(dd.unitId), dd.time, tostring(positionMethod), tostring(einfo or "position available")))
              d(string.format(L("[Sul-Xan's marker] 候補を追加: %s (%s; %s)", "[Sul-Xan's marker] Candidate added: %s (%s; %s)"), dd.name, positionMethod, tostring(einfo or "position available")))
            end
          elseif PSM.logEnabled then
            StoreDiagnostic(string.format("CANDIDATE name=%s id=%s deathT=%d result=excluded reason=%s",
              tostring(dd.name), tostring(dd.unitId), dd.time, distinct and "candidate-limit" or "duplicate-position"))
          end
        elseif PSM.logEnabled then
          StoreDiagnostic(string.format("CANDIDATE name=%s id=%s deathT=%d result=excluded reason=%s",
            tostring(dd.name), tostring(dd.unitId), dd.time, tostring(einfo)))
          d(string.format(L("[Sul-Xan's marker] 候補位置を計算できません: %s (%s)", "[Sul-Xan's marker] Candidate position could not be calculated: %s (%s)"), dd.name, tostring(einfo)))
        end
      end
      -- 複数死亡時は、三角測量または新鮮な名前一致スナップショット/座標で
      -- 得られた候補だけを表示する。
      pos = nil
      extras = {}
      for i, candidate in ipairs(candidateByDeath) do
        if i == 1 then
          pos = candidate.pos
          targetName = candidate.name
          loggedDeathName = candidate.name
          src = "candidate:" .. tostring(candidate.name) .. "(" .. tostring(candidate.method) .. ")"
        else
          extras[#extras + 1] = candidate.pos
        end
      end
      if targetName then
        sameNameDeaths, otherDeaths = 0, 0
        for _, dd in ipairs(recentDeaths) do
          if dd.time >= t - DEATH_BEFORE_MS and dd.time <= t
              and not IsDeathInsideSoulInterval(dd.time, intervalsForThisDrop) then
            if dd.name == targetName then sameNameDeaths = sameNameDeaths + 1
            else otherDeaths = otherDeaths + 1 end
          end
        end
      end
      uncertain = true
      if not pos then
        PSM.lastDrop = nil
        LogSoulDrop()
        if PSM.logEnabled then d(L("[Sul-Xan's marker] 候補位置を計算できないため表示しません", "[Sul-Xan's marker] No candidate positions could be calculated; nothing shown")) end
        return
      end
    elseif uncertain then
      -- 死亡が1件なら、既存の曖昧さ表示(必要時の補助候補)を維持する。
      for _, dd in ipairs(candidateDeaths) do
        if dd ~= chosen then
          local ep, einfo = Triangulate(dd.name, dd.time, dd.unitId)
          local distinct = ep ~= nil
          if distinct and pos then
            local dx, dy, dz = ep[1] - pos[1], ep[2] - pos[2], ep[3] - pos[3]
            distinct = math.sqrt(dx * dx + dy * dy + dz * dz) >= 100
          end
          for _, prior in ipairs(extras) do
            if distinct then
              local dx, dy, dz = ep[1] - prior[1], ep[2] - prior[2], ep[3] - prior[3]
              if math.sqrt(dx * dx + dy * dy + dz * dz) < 100 then distinct = false end
            end
          end
          if distinct then
            extras[#extras + 1] = ep
            if PSM.logEnabled then
              d(string.format(L("[Sul-Xan's marker] 候補を追加: %s (%s)", "[Sul-Xan's marker] Candidate added: %s (%s)"), dd.name, tostring(einfo or "triangulation")))
            end
          end
        end
      end
    end

    -- 候補処理で確定した最終状態を記録する。
    LogSoulDrop()

    -- 三角測量できた時は、自分の足元との高さの差を覚えておく
    if triPos then
      local _, py = ReadPos("player")
      if py then
        PSM.groundDy = math.max(-GROUND_DY_LIMIT_CM, math.min(GROUND_DY_LIMIT_CM, triPos[2] - py))
        PSM.groundDyTime = now()
      end
    end

    -- 三角測量できず、水平面との交点(推測)が遠すぎる時は、表示しない
    local tooFar = false
    if pos and not triPos then
      local px, _, pz = ReadPos("player")
      if px then
        local dist = math.sqrt((pos[1] - px) ^ 2 + (pos[3] - pz) ^ 2)
        if dist > (PSM.sv.maxShowDist or 36) * 100 then
          if PSM.logEnabled then
            d(string.format(L("[Sul-Xan's marker] 推測位置が遠すぎる(%dm)ので表示しません", "[Sul-Xan's marker] Estimated position too far (%d m); not shown"), zo_floor(dist / 100)))
          end
          pos = nil
          tooFar = true
        end
      end
    end
    if not pos and #extras > 0 then
      pos = table.remove(extras, 1)
      uncertain = true
    end
    if not pos and ambiguousTrack then
      PSM.lastDrop = nil
      if PSM.logEnabled then d(L("[Sul-Xan's marker] 個体追跡が曖昧なため表示しません", "[Sul-Xan's marker] Not shown: target tracking is ambiguous")) end
      return
    end
    if not pos and tooFar then
      PSM.lastDrop = nil
      return   -- 位置が遠すぎる時は、何も表示しない
    end
    if not pos and PSM.sv.hideWhenNoPos then
      PSM.lastDrop = nil
      if PSM.logEnabled then d(L("[Sul-Xan's marker] 位置が取れないので表示しません(設定)", "[Sul-Xan's marker] No position available; not shown (setting)")) end
      return
    end

    local all = {}
    if pos then all[1] = pos end
    for _, ep in ipairs(extras) do all[#all + 1] = ep end
    PSM.lastDrop = { pos = pos, all = all, src = src, uncertain = uncertain, sameNameDeaths = sameNameDeaths, name = targetName }
    local showDuration = math.max(duration - DROP_DELAY_MS, 1000)
    if pickedUpBeforeDisplay then
      showDuration = (pos ~= nil and #extras > 0) and EARLY_CANDIDATE_DISPLAY_MS or EARLY_PICKUP_DISPLAY_MS
    end
    -- 小さいマーカーは、位置候補が複数ある時だけ。1か所だけなら、不確かでも通常サイズ(色だけオレンジ)で表示する。
    local multipleMarkers = pos ~= nil and #extras > 0
    PSM.Show(showDuration, pos, uncertain, extras, multipleMarkers)
  end, DROP_DELAY_MS)
end

local function OnSoulPickup(_, result, _, _, _, _, _, sourceType, _, _, hitValue)
  if result ~= ACTION_RESULT_EFFECT_GAINED_DURATION and result ~= ACTION_RESULT_EFFECT_GAINED then
    return
  end
  if PSM.testing then return end

  local pickupTime = now()
  if activeSoulInterval and activeSoulInterval.finish == nil then
    activeSoulInterval.finish = pickupTime
  end
  if PSM.pending then
    -- The pending drop callback still needs the old data to finish its own
    -- calculation. Purge all pre-pickup history just after that callback runs,
    -- retaining rays/samples collected after the pickup timestamp.
    zo_callLater(function()
      ClearPositionHistory(pickupTime)
    end, DROP_DELAY_MS + 100)
  else
    ClearPositionHistory()
  end
  if not PSM.sv.hideOnPickup then return end

  -- Pickup may precede the delayed Show() call by a few frames. Remember it
  -- so the callback can display the marker briefly.
  if PSM.pending then
    PSM.pendingPickup = true
    if PSM.logEnabled then d(L("[Sul-Xan's marker] 表示前の拾得を記録（短時間表示）", "[Sul-Xan's marker] Pickup recorded before display (brief marker)")) end
    return
  end

  -- 精度の計測: 拾った瞬間の自分の位置と、表示していた位置との差をログに出す
  local ld = PSM.lastDrop
  if PSM.logEnabled and ld and ld.pos and PSM.endTime > now() then
    local px, py, pz = ReadPos("player")
    if px then
      local best, bestIdx, bestDh = nil, 0, math.huge
      for i, cp in ipairs(ld.all or { ld.pos }) do
        local dx, dz = px - cp[1], pz - cp[3]
        local dh = math.sqrt(dx * dx + dz * dz)
        if dh < bestDh then best, bestIdx, bestDh = cp, i, dh end
      end
      local dx, dz = px - best[1], pz - best[3]
      local dy = py - best[2]
      d(string.format(L("[Sul-Xan's marker] 拾得: 最も近い矢印(%d/%d番目)との差 水平%dcm (dx=%+d,dz=%+d) 基準位置との高さ%+dcm (%s / 同名死亡%d / 不確か=%s)", "[Sul-Xan's marker] Pickup: nearest arrow (%d/%d) delta horizontal %dcm (dx=%+d,dz=%+d) anchor height %+dcm (%s / same-name deaths %d / uncertain=%s)"),
        bestIdx, #(ld.all or { ld.pos }), zo_floor(bestDh), zo_floor(dx), zo_floor(dz), zo_floor(dy), (tostring(ld.src):gsub("%(.*", "")),
        ld.sameNameDeaths or 0, tostring(ld.uncertain)))
    end
  end
  PSM.Hide()
end

-- 敵の死亡: 倒された敵の名前を記録して、魂の位置の特定に使う
-- (eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType,
--  sourceName, sourceType, targetName, targetType, ...)
local NOT_ENEMY_TYPES = {}
for _, k in ipairs({ "COMBAT_UNIT_TYPE_PLAYER", "COMBAT_UNIT_TYPE_PLAYER_PET", "COMBAT_UNIT_TYPE_GROUP",
                     "COMBAT_UNIT_TYPE_PLAYER_COMPANION" }) do
  if _G[k] then NOT_ENEMY_TYPES[_G[k]] = true end
end

local function OnEnemyDied(_, result, _, _, _, _, _, sourceType, targetName, targetType, _, _, _, _, _, targetUnitId)
  -- 自分・ペット・パーティメンバー・コンパニオンの死亡は対象外
  if NOT_ENEMY_TYPES[targetType] then return end
  local name = NormalizeName(targetName)
  if not name then return end
  if not detectedJa and HasKana(name) then detectedJa = true end  -- 敵の名前が日本語なら、日本語クライアントとみなす
  -- 味方NPC・ペット等として照準した名前で、敵として照準した記録がなければ無視する
  if friendlyNames[name] and not samples[name] and not rays[name] then return end
  local t = now()
  lastDeath = { name = name, time = t }

  -- 直近の死亡の一覧(同名の敵が同時に複数倒れたかの判定用)
  recentDeaths[#recentDeaths + 1] = { name = name, time = t, unitId = targetUnitId }
  while #recentDeaths > 0 and (#recentDeaths > 30 or recentDeaths[1].time < t - 5000) do
    table.remove(recentDeaths, 1)
  end

  if PSM.logEnabled then
    local rn = ReticleName()
    local okp, hp, hpMax = pcall(GetUnitPower, "reticleover", COMBAT_MECHANIC_FLAGS_HEALTH)
    local hpText = (okp and hp and hpMax and hpMax > 0) and string.format("%d%%", zo_floor(hp * 100 / hpMax)) or "-"
    StoreDiagnostic(string.format("ENEMY-DIED t=%d name=%s id=%s reticle=%s hp=%s track={%s}",
      t, tostring(name), tostring(targetUnitId), tostring(rn), hpText, SegmentIdDiag(name, t)))
    d(string.format("[Sul-Xan's marker] enemy died: %s (result=%s, unitId=%s) reticle=%s(%s)%s",
      name, tostring(result), tostring(targetUnitId), tostring(rn), hpText,
      (rn and rn ~= name) and (" rawName=" .. tostring(targetName)) or ""))
  end
end

local function ResetState()
  lastPos = nil
  lastDeath = nil
  recentDeaths = {}
  soulDeathIntervals = {}
  activeSoulInterval = nil
  samples = {}
  rays = {}
  friendlyNames = {}
end

-- 戦闘イベントと照準サンプリングの登録 / 解除 (装備していない間は完全に止める)
local combatRegistered = false

local function RegisterCombat()
  if combatRegistered then return end
  combatRegistered = true

  local n1 = PSM.name .. "_SoulDrop"
  local n2 = PSM.name .. "_SoulPickup"

  for i, deathResult in ipairs({ ACTION_RESULT_DIED_XP, ACTION_RESULT_KILLING_BLOW, ACTION_RESULT_DIED }) do
    local nd = PSM.name .. "_Died" .. i
    EM:RegisterForEvent(nd, EVENT_COMBAT_EVENT, OnEnemyDied)
    EM:AddFilterForEvent(nd, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, deathResult)
  end

  EM:RegisterForEvent(n1, EVENT_COMBAT_EVENT, OnSoulDrop)
  EM:AddFilterForEvent(n1, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_ABILITY_ID, SOUL_ID,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

  EM:RegisterForEvent(n2, EVENT_COMBAT_EVENT, OnSoulPickup)
  EM:AddFilterForEvent(n2, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_ABILITY_ID, PICKUP_BUFF_ID,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

  EM:RegisterForEvent(PSM.name .. "_Dead", EVENT_PLAYER_DEAD, function() PSM.Hide() end)

  -- 照準中の敵の位置を記録
  EM:RegisterForUpdate(SAMPLE_NAME, SAMPLE_INTERVAL_MS, SampleTarget)

  -- Map combat target IDs to a ray segment only when its name is also the
  -- current reticle target. The soul-proc event itself targets the player.
  local targetEvent = PSM.name .. "_PlayerTargetId"
  EM:RegisterForEvent(targetEvent, EVENT_COMBAT_EVENT, OnPlayerCombatTarget)
  EM:AddFilterForEvent(targetEvent, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
end

local function UnregisterCombat()
  if not combatRegistered then return end
  combatRegistered = false

  for i = 1, 3 do
    EM:UnregisterForEvent(PSM.name .. "_Died" .. i, EVENT_COMBAT_EVENT)
  end
  EM:UnregisterForEvent(PSM.name .. "_SoulDrop", EVENT_COMBAT_EVENT)
  EM:UnregisterForEvent(PSM.name .. "_SoulPickup", EVENT_COMBAT_EVENT)
  EM:UnregisterForEvent(PSM.name .. "_Dead", EVENT_PLAYER_DEAD)
  EM:UnregisterForEvent(PSM.name .. "_PlayerTargetId", EVENT_COMBAT_EVENT)
  EM:UnregisterForUpdate(SAMPLE_NAME)

  PSM.Hide()
  ResetState()
end

-- ----------------------------------------------------------------------------
-- スルザン装備の判定
-- ----------------------------------------------------------------------------

-- セット名にこの文字列(小文字・部分一致)を含めば対象。言語が違う場合は /sulxan setname で追加できる
local BUILTIN_SET_PATTERNS = { "sul%-xan", "sul‑xan", "スル" }

local function SetNameMatches(name)
  if not name or name == "" then return false end
  local low = zo_strlower(name)
  for _, pat in ipairs(BUILTIN_SET_PATTERNS) do
    if low:find(pat) then return true end
  end
  local extra = PSM.sv and PSM.sv.extraSetNames
  if extra then
    for _, e in ipairs(extra) do
      if e ~= "" and low:find(zo_strlower(e), 1, true) then return true end
    end
  end
  return false
end

-- 装備中のセット名と枚数を集計
local function CollectEquippedSets()
  local counts = {}
  for slot = 0, GetBagSize(BAG_WORN) - 1 do
    local link = GetItemLink(BAG_WORN, slot)
    if link and link ~= "" then
      local hasSet, setName = GetItemLinkSetInfo(link, true)
      if hasSet and setName and setName ~= "" then
        counts[setName] = (counts[setName] or 0) + 1
      end
    end
  end
  return counts
end

function PSM.IsSetEquipped()
  for name in pairs(CollectEquippedSets()) do
    if SetNameMatches(name) then return true end
  end
  return false
end

PSM.active = nil

function PSM.UpdateActive()
  local on = PSM.IsSetEquipped()
  if on == PSM.active then return end
  PSM.active = on
  if on then RegisterCombat() else UnregisterCombat() end
  if PSM.logEnabled then
    d("[Sul-Xan's marker] " .. (on and L("スルザン装備を検出: 動作開始", "Sul-Xan's Torment detected: started") or L("スルザン装備なし: 完全停止", "Sul-Xan's Torment not worn: fully stopped")))
  end
end

local pendingCheck = false
local function ScheduleCheck()
  if pendingCheck then return end
  pendingCheck = true
  zo_callLater(function()
    pendingCheck = false
    PSM.UpdateActive()
  end, 200)
end

function PSM.RegisterEvents()
  -- 常時動かすのは装備変更の監視だけ
  local n = PSM.name .. "_Equip"
  EM:RegisterForEvent(n, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, ScheduleCheck)
  EM:AddFilterForEvent(n, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)

  EM:RegisterForEvent(PSM.name .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
    ResetState()
    PSM.Hide()
    PSM.UpdateActive()
  end)

  PSM.UpdateActive()
end

-- ----------------------------------------------------------------------------
-- 初期化
-- ----------------------------------------------------------------------------

local function PrintDebug()
  local function p(s) d("[Sul-Xan's marker] " .. s) end
  p("version " .. PSM.version)
  p("baseline guard: min=" .. tostring(MIN_BASELINE_CM) .. "cm / final-check=ON")
  p("LibCombatAlerts: " .. ((LCA and LCA.WorldDrawing) and "OK" or "NOT FOUND"))
  p("reticle exists: " .. tostring(DoesUnitExist("reticleover")) .. " / hostile: " .. tostring(IsHostileTarget()))
  local x, y, z = ReadPos("reticleover")
  p(x and string.format("unit pos (API): %d, %d, %d", x, y, z) or "unit pos (API): nil")
  x, y, z = RayAimPos()
  p(x and string.format("aim pos (camera ray): %d, %d, %d", x, y, z) or "aim pos (camera ray): nil")
  if lastPos then
    p(string.format("last pos: %d, %d, %d (%.1fs ago, %s)", lastPos[1], lastPos[2], lastPos[3], (now() - lastPos[4]) / 1000, tostring(lastPos[5])))
  else
    p("last pos: nil")
  end
  local nx, ny = GetMapPlayerPosition("reticleover")
  p(string.format("map pos (reticleover): %s, %s", tostring(nx), tostring(ny)))
  nx, ny = GetMapPlayerPosition("player")
  p(string.format("map pos (player): %s, %s", tostring(nx), tostring(ny)))
  p("reticle name: " .. tostring(ReticleName()) .. " / last death: " .. (lastDeath and (lastDeath.name .. string.format(" (%.1fs ago)", (now() - lastDeath.time) / 1000)) or "nil"))
  p("3D markers: " .. tostring(#markers))
  p(L("装備判定: ", "Equipment check: ") .. (PSM.active and L("スルザン装備あり(動作中)", "set worn (active)") or L("スルザン装備なし(停止中)", "set not worn (stopped)")))
  for name, n in pairs(CollectEquippedSets()) do
    p(string.format(L("  装備中セット: %s x%d%s", "  Worn set: %s x%d%s"), (zo_strformat(SI_UNIT_NAME, name)), n, SetNameMatches(name) and L("  <- 一致", "  <- match") or ""))
  end
end

-- Use while the reticle is directly on the dropped soul. This reports the
-- interaction name and tests whether either unit tag exposes world coordinates.
local function ProbeSoulTarget()
  local function p(s) d("[Sul-Xan's marker] probe: " .. s) end
  local action, name = nil, nil
  if type(GetGameCameraInteractableActionInfo) == "function" then
    local ok, a, n = pcall(GetGameCameraInteractableActionInfo)
    if ok then action, name = a, n else p("interaction API error: " .. tostring(a)) end
  else
    p("GetGameCameraInteractableActionInfo unavailable")
  end
  p("interaction action=" .. tostring(action) .. " name=" .. tostring(name))
  for _, tag in ipairs({ "reticleover", "interact" }) do
    local exists = false
    if type(DoesUnitExist) == "function" then
      local ok, v = pcall(DoesUnitExist, tag)
      exists = ok and v == true
    end
    local ok, zone, x, y, z = pcall(GetUnitRawWorldPosition, tag)
    if ok and x and not (x == 0 and y == 0 and z == 0) then
      p(string.format("%s exists=%s raw=(zone %s, %d, %d, %d)", tag, tostring(exists), tostring(zone), x, y, z))
    else
      p(string.format("%s exists=%s raw position unavailable", tag, tostring(exists)))
    end
  end
  p("Aim at the soul itself, then run /sulxan probe again before picking it up.")
end

local function OnAddOnLoaded(_, addonName)
  if addonName ~= PSM.name then return end
  EM:UnregisterForEvent(PSM.name .. "_Loaded", EVENT_ADD_ON_LOADED)

  PSM.sv = ZO_SavedVars:NewAccountWide("SulXansMarkerVars", 2, nil, PSM.defaults)
  -- These behaviors are fixed on and are no longer user-configurable.
  -- Override older saved values so existing installs receive the same behavior.
  PSM.sv.hideOnPickup = true
  PSM.sv.showCountdown = true
  PSM.sv.useGround = true
  PSM.sv.weightTau = 1.5
  PSM.sv.use3D = true
  PSM.sv.size3D = 200
  PSM.sv.height = 200

  CreateUI()
  PSM.ApplyLayout()
  PSM.RegisterEvents()

  -- 設定画面は、日本語化アドオンなどの読み込みが終わった後(最初のゾーン読み込み後)に作る
  if PSM.CreateSettings then
    local settingsCreated = false
    local function MakeSettings()
      if settingsCreated then return end
      settingsCreated = true
      EM:UnregisterForEvent(PSM.name .. "_SettingsInit", EVENT_PLAYER_ACTIVATED)
      PSM.CreateSettings()
    end
    EM:RegisterForEvent(PSM.name .. "_SettingsInit", EVENT_PLAYER_ACTIVATED, MakeSettings)
  end

  local function OnSlashCommand(arg)
    arg = (arg or ""):lower()
    if arg == "test" then
      PSM.Test()
    elseif arg == "unlock" then
      PSM.SetUnlocked(true)
      d(L("[Sul-Xan's marker] 移動モード ON: アイコンをドラッグして移動。終わったら /sulxan lock", "[Sul-Xan's marker] Move mode ON: drag the icon. Type /sulxan lock when done"))
    elseif arg == "lock" then
      PSM.SetUnlocked(false)
      d(L("[Sul-Xan's marker] 位置を固定しました", "[Sul-Xan's marker] Position locked"))
    elseif arg == "debug" then
      PrintDebug()
    elseif arg == "probe" then
      ProbeSoulTarget()
    elseif arg == "dump" then
      DumpDiagnosticLog()
    elseif arg == "sets" then
      PrintDebug()
    elseif arg:sub(1, 7) == "setname" then
      local nm = arg:sub(9)
      if nm == "" then
        d(L("[Sul-Xan's marker] 使い方: /sulxan setname セット名の一部  (/sulxan sets で装備中のセット名を確認)", "[Sul-Xan's marker] Usage: /sulxan setname <part of set name>  (use /sulxan sets to see worn set names)"))
      else
        PSM.sv.extraSetNames = PSM.sv.extraSetNames or {}
        table.insert(PSM.sv.extraSetNames, nm)
        d(L("[Sul-Xan's marker] セット名を追加: ", "[Sul-Xan's marker] Set name added: ") .. nm)
        PSM.UpdateActive()
      end
    elseif arg:sub(1, 4) == "lang" then
      local v = arg:sub(6)
      if v == "ja" or v == "en" or v == "auto" then
        PSM.sv.language = v
        d("[Sul-Xan's marker] language = " .. v .. L("  (設定画面は /reloadui 後に反映)", "  (settings menu changes after /reloadui)"))
      else
        d("[Sul-Xan's marker] /sulxan lang ja | en | auto   (current: " .. tostring(PSM.sv.language) .. ", detected: " .. (DetectJa() and "ja" or "en") .. ")")
        local _, lines = ProbeLanguage()
        d("[Sul-Xan's marker] probes: " .. table.concat(lines, ", "))
      end
    elseif arg == "log" then
      PSM.logEnabled = not PSM.logEnabled
      d(L("[Sul-Xan's marker] ログ ", "[Sul-Xan's marker] Log ") .. (PSM.logEnabled and "ON" or "OFF"))
    else
      d("[Sul-Xan's marker] /sulxan test | unlock | lock | debug | probe | dump | sets | setname <name> | lang | log")
    end
  end

  SLASH_COMMANDS["/sulxan"]   = OnSlashCommand
  SLASH_COMMANDS["/puyosoul"] = OnSlashCommand  -- 旧名(互換用)
end

EM:RegisterForEvent(PSM.name .. "_Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
