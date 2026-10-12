-- Sul-Xan's marker
-- Author: PUYO
-- Sul-Xan's Torment の魂(Soul)がドロップした時に ↓ アイコンを表示する。
--   157738 = 魂(フィールドに出る)  /  154737 = 魂を拾った時のバフ
-- ↓ は LibCombatAlerts の WorldDrawing で、魂が落ちた位置(=倒した敵の位置)の
-- ワールド空間に描画する。位置が取れない場合は画面上の ↓ にフォールバックする。

SulXansMarker = SulXansMarker or {}
local PSM = SulXansMarker

PSM.name    = "SulXansMarker"
PSM.version = "1.28"

local EM  = EVENT_MANAGER
local LCA = LibCombatAlerts

local SOUL_ID        = 157738  -- 魂がドロップした時のイベント
local PICKUP_BUFF_ID = 154737  -- 魂を拾った時のバフ(Sul-Xan's Torment)
local DEFAULT_DURATION_MS = 6000
local PICKUP_GUARD_MS     = 300   -- ドロップ直後の同時イベントで消えないようにする
local POS_MAX_AGE_MS      = 8000  -- 記録した敵位置を使う最大経過時間
local SAMPLE_INTERVAL_MS  = 50
local ARROW_TEXTURE       = "world-pointer-down" -- LibCombatAlerts 標準の下向き矢印
local AIM_PLANE_HEIGHT_CM = 100   -- 照準の延長線と交わらせる高さ(足元からの cm、敵の胸あたり)
local MAX_RAY_CM          = 8000  -- 照準から求める位置の最大距離(cm)

PSM.defaults = {
  extraSetNames = {},
  hideWhenNoPos = false,  -- 位置が全く取れない時は何も表示しない(OFF なら画面上の ↓ と残り秒数を出す)
  showCandidates = false, -- 種類の違う敵が同時に倒れた時、他の候補の矢印(オレンジ)も出す。OFF なら矢印は常に1つ
  enabled      = true,
  use3D        = true,   -- ワールド空間(魂の位置)に表示
  size3D       = 150,    -- cm
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

local UPDATE_NAME = PSM.name .. "_Update"
local SAMPLE_NAME = PSM.name .. "_Sample"
local now = GetGameTimeMilliseconds

local ui                 -- 画面表示用コントロール
local canvas              -- LibCombatAlerts のワールド描画
local markers = {}        -- 表示中の矢印の一覧 { {id, numId, pos, numSec}, ... }(候補が複数のとき複数個)
local lastPos            -- 直近に照準していた敵の位置 { x, y, z, time, src }
local samples = {}       -- 敵の名前ごとの、最後に照準していた位置 { x, y, z, time, src }
local lastDeath          -- 直近に倒した敵 { name, time }
local recentDeaths = {}  -- 直近の死亡の一覧 { name, time, unitId }
local SAMPLE_KEEP_MS   = 30000
local DROP_DELAY_MS     = 250   -- 魂イベントの後、死亡イベントを待つ時間
local GROUND_DY_KEEP_MS    = 60000 -- 高さの差を覚えておく時間
local GROUND_DY_LIMIT_CM   = 1500  -- 高さの差として採用する上限(±)
local FALLBACK_MAX_CM      = 3000  -- 水平面との交点(推測)がこれより遠い時は、ワールド表示にせず画面表示にする
local MAX_EXTRA_CANDIDATES = 2  -- 同時に倒れた別種の敵の候補を、主な矢印のほかに最大いくつ出すか
local DEATH_BEFORE_MS   = 300   -- 魂イベントのこの時間前以降の死亡を「今倒した敵」とみなす

-- ----------------------------------------------------------------------------
-- 位置の取得
-- ----------------------------------------------------------------------------

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
  if GetUnitReaction("reticleover") == UNIT_REACTION_HOSTILE then
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
local MAX_RAYS        = 100
local RAY_WINDOW_MS   = 4000 -- 直近この時間(4秒)の線だけ使う
local MIN_RAYS        = 6
local MIN_BASELINE_CM = 100  -- 線の位置のばらつき(横方向)の最小値
local WEIGHT_TAU_MS    = 1500 -- 線の重み exp(-経過/τ): 最新の線ほど重く、古い線ほど軽く扱う
local HP_JUMP_RATIO     = 0.03 -- 体力がこれ以上増えたら別個体とみなす(最大体力に対する割合)
local LAST_RAY_OFF_CM  = 200  -- 最新の線が交点からこれ以上離れていたら「不確か」
local MAX_RESIDUAL_CM = 120  -- 交点と各線の平均距離がこれ以上なら不採用(敵が動いた等)

-- 線の一覧 l から最小二乗の交点を求める。
-- 戻り値: x, y, z, rx, ry, rz, baseline, resid  (x,y,z は最新の原点 r を基準にした相対座標)
--         失敗時は nil, 理由
local function Solve(l)
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
    local w = math.exp(-(tLast - r[1]) / WEIGHT_TAU_MS)
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

  local det = a11 * (a22 * a33 - a23 * a23) - a12 * (a12 * a33 - a23 * a13) + a13 * (a12 * a23 - a22 * a13)
  if math.abs(det) < 1e-6 * wsum * wsum * wsum then return nil, "singular" end

  local x = (b1 * (a22 * a33 - a23 * a23) - a12 * (b2 * a33 - a23 * b3) + a13 * (b2 * a23 - a22 * b3)) / det
  local y = (a11 * (b2 * a33 - a23 * b3) - b1 * (a12 * a33 - a23 * a13) + a13 * (a12 * b3 - b2 * a13)) / det
  local z = (a11 * (a22 * b3 - b2 * a23) - a12 * (a12 * b3 - b2 * a13) + b1 * (a12 * a23 - a22 * a13)) / det

  local resid = 0
  for i = 1, n do
    local r = l[i]
    local w = math.exp(-(tLast - r[1]) / WEIGHT_TAU_MS)
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
      d(string.format("[Sul-Xan's marker] 別の個体に照準が移りました (%s 体力 %d)", name, hp))
    end
    seg = { list = {}, hp = hp, hpMax = hpMax, last = t, isNew = true }
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

  local l = seg.list
  l[#l + 1] = { t, ox, oy, oz, fx, fy, fz }
  while #l > 0 and (#l > MAX_RAYS or l[1][1] < t - RAY_WINDOW_MS) do
    table.remove(l, 1)
  end
end

-- 倒れた敵の個体を選ぶ。戻り値: 個体, 倒れたと確認できたか, 候補の個体数
-- deathTime: 死亡イベントの時刻。この時刻の前後で体力が 0 になった個体が「倒れた個体」。
-- (体力 0 の別の死体や、生きている同名の敵とは区別する)
local function ChooseSegment(e, deathTime)
  local t = now()
  local dead, deadDiff, recent, cands = nil, nil, nil, 0
  for _, sg in ipairs(e.segs) do
    if #sg.list > 0 and t - sg.last <= DEAD_WINDOW_MS then
      cands = cands + 1
      if deathTime and sg.deadAt then
        local diff = math.abs(sg.deadAt - deathTime)
        if diff <= DEAD_MATCH_MS and (not dead or diff < deadDiff) then dead, deadDiff = sg, diff end
      end
      if not recent or sg.last > recent.last then recent = sg end
    end
  end
  if dead then return dead, true, cands end
  return recent, false, cands
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

-- 戻り値: { x, y, z }, 説明文, 不確かか  /  失敗時は nil, 理由
local function Triangulate(name, deathTime)
  local e = name and rays[name]
  if not e then return nil, "no-rays" end
  local seg, isDead, cands = ChooseSegment(e, deathTime)
  if not seg then return nil, "no-recent-rays" end
  local l, n = seg.list, #seg.list

  local x, y, z, rx, ry, rz, baseline, resid = Solve(l)
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
    local x2, y2, z2, rx2, ry2, rz2, b2, r2 = Solve(keep)
    if not x2 or r2 > MAX_RESIDUAL_CM then return nil, "large-residual(" .. zo_floor(resid) .. ")" end
    trimmed = n - #keep
    l, n = keep, #keep
    x, y, z, rx, ry, rz, baseline, resid = x2, y2, z2, rx2, ry2, rz2, b2, r2
  end

  -- 妥当性チェック: カメラからの距離
  local dist = math.sqrt(x * x + y * y + z * z)
  if dist < 150 or dist > MAX_RAY_CM then return nil, "bad-distance(" .. zo_floor(dist) .. ")" end

  -- 最新の線(死亡直前に狙っていた先)が交点から離れていれば、別の敵を追っている疑いがある
  local lastOff = RayDist(seg.list[#seg.list], x, y, z, rx, ry, rz)
  -- 倒れた個体を体力で確認できない時も不確か
  local doubtful = trimmed > 0 or lastOff > LAST_RAY_OFF_CM or not isDead

  -- 照準は敵の胸あたりに当たっている想定なので、足元の高さに下げる
  -- 敵が動いていても、最新の線(=死亡の直前に照準していた先)の上には必ずいる。
  -- 交点を最新の線の上に落とす: 横方向のずれが消え、奥行きだけが交点の推定になる。
  local ref = l[n]
  local k = x * ref[5] + y * ref[6] + z * ref[7]
  if k < 150 then k = 150 end
  local shift = math.sqrt((x - ref[5] * k) ^ 2 + (y - ref[6] * k) ^ 2 + (z - ref[7] * k) ^ 2)
  x, y, z = ref[5] * k, ref[6] * k, ref[7] * k

  local pos = { x + rx, y + ry - AIM_PLANE_HEIGHT_CM, z + rz }
  return pos, string.format("tri(n=%d,base=%dcm,res=%dcm,dist=%dm,last=%dcm,proj=%dcm,trim=%d,%s%d)",
    n, zo_floor(baseline), zo_floor(resid), zo_floor(dist / 100), zo_floor(lastOff), zo_floor(shift), trimmed,
    isDead and "dead/" or "alive/", cands) .. " segs=" .. SegDiag(e, deathTime), doubtful
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
end

local function SampleTarget()
  sampleTicks = sampleTicks + 1
  if sampleTicks >= 100 then   -- 約5秒ごと
    sampleTicks = 0
    PurgeOld()
  end

  if IsHostileTarget() then
    local x, y, z, src = GetTargetPos()
    if x then
      local t = now()
      lastPos = { x, y, z, t, src }
      local name = ReticleName()
      if name then
        samples[name] = lastPos
        RecordRay(name)
      end
    end
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

local function Place3D(pos, uncertain)
  if not (LCA and LCA.WorldDrawing) then return false end
  local sv = PSM.sv
  local color = (uncertain and sv.markUncertain) and UNCERTAIN_COLOR or sv.color
  local ok, id = pcall(function()
    canvas = canvas or LCA.WorldDrawing:New()
    return canvas:PlaceTexture({
      texture             = ARROW_TEXTURE,
      pos                 = pos,
      size                = sv.size3D,
      elevation           = sv.height,
      playerFacing        = true,
      color               = PackColor(color),
      disableDepthBuffers = true, -- 地形や壁に隠れない
    })
  end)
  if not (ok and id) then return false end

  local m = { id = id, pos = pos }
  markers[#markers + 1] = m

  -- 矢印の中に残り秒数を表示
  if sv.showCountdown then
    local sec = CountdownSec()
    local ok2, id2 = pcall(function()
      return canvas:PlaceTexture({
        texture             = "world-num-" .. sec,
        pos                 = pos,
        size                = sv.size3D * NUM_SCALE,
        elevation           = sv.height + sv.size3D * NUM_Y,
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
  canvas:UpdateTexture(m.numId, "elevation", arrowElev + sv.size3D * NUM_Y + sy)
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
  ui.win:SetAnchor(CENTER, GuiRoot, CENTER, sv.offsetX, sv.offsetY)

  ui.icon:SetDimensions(size, size)
  ui.icon:ClearAnchors()
  ui.icon:SetAnchor(TOP, ui.win, TOP, 0, 0)
  ui.icon:SetColor(unpack(sv.color))

  -- 残り秒数は矢印の中(中心より少し上)に表示する
  ui.label:ClearAnchors()
  ui.label:SetAnchor(CENTER, ui.icon, CENTER, 0, -math.floor(size * NUM_Y))
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
    PSM.Hide()
    return
  end

  -- 残り秒数(整数・切り上げ。6 → 5 → ... → 1)
  local sec = zo_ceil(remain / 1000)
  if sec > 12 then sec = 12 end

  if #markers > 0 and canvas then
    -- ワールド表示: 矢印を上下に動かし、数字をそれに合わせる
    local elev = sv.height
    if sv.bob then
      elev = sv.height + math.sin(t / 140) * sv.size3D * 0.12
    end
    for _, m in ipairs(markers) do
      if sv.bob then canvas:UpdateTexture(m.id, "elevation", elev) end
      UpdateCountdown(m, elev, sec)
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
function PSM.Show(durationMs, pos, uncertain, extras)
  if not ui then return end
  local sv = PSM.sv
  if not sv.enabled then return end

  local t = now()
  PSM.shownAt = t
  PSM.endTime = t + durationMs

  Remove3D()
  local placed = false
  if sv.use3D and pos then
    placed = Place3D(pos, uncertain)
    if placed and extras then
      for _, ep in ipairs(extras) do Place3D(ep, true) end
    end
  end

  ui.icon:ClearAnchors()
  ui.icon:SetAnchor(TOP, ui.win, TOP, 0, 0)
  ApplyScreenVisibility(not placed)
  StartUpdate()
end

function PSM.Hide()
  PSM.endTime = 0
  PSM.testing = false
  Remove3D()
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

function PSM.SetUnlocked(unlocked)
  PSM.unlocked = unlocked and true or false
  if not ui then return end
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

  -- この瞬間の照準を記録しておく(倒された敵の名前は、少し遅れて届く死亡イベントで分かる)
  local snap
  if IsHostileTarget() then
    local x, y, z, s = GetTargetPos()
    if x then snap = { pos = { x, y, z }, name = ReticleName(), src = s } end
  end
  local earlyPos, earlySrc = GetDropPosition()

  PSM.testing = false
  PSM.pending = true

  zo_callLater(function()
    PSM.pending = false
    -- 待っている間にスルザンを外した場合は、何も出さない(完全停止)
    if not PSM.active then return end
    local pos, src = earlyPos, earlySrc

    -- ドロップとほぼ同時に倒された敵の名前が分かれば、その敵の位置を優先する
    -- 種類の違う敵が同時に倒れていた場合は、最初に倒れた敵を採用する
    local chosen
    for _, dd in ipairs(recentDeaths) do
      if dd.time >= t - DEATH_BEFORE_MS then chosen = dd; break end
    end
    if not chosen and lastDeath and lastDeath.time >= t - DEATH_BEFORE_MS then chosen = lastDeath end

    local targetName = snap and snap.name
    if chosen then
      targetName = chosen.name
      local sample = samples[chosen.name]
      if snap and snap.name == chosen.name then
        pos, src = snap.pos, "death+snap(" .. tostring(snap.src) .. ")"
      elseif sample and now() - sample[4] <= SAMPLE_KEEP_MS then
        pos, src = { sample[1], sample[2], sample[3] }, "death+name(" .. tostring(sample[5]) .. ")"
      end
    end

    -- 照準の線の交点が求まれば、それが最も正確(坂道でもずれにくい)
    local e = targetName and rays[targetName]
    local triPos, triInfo, doubtful
    if e and now() - e.last <= SAMPLE_KEEP_MS then
      triPos, triInfo, doubtful = Triangulate(targetName, (chosen and chosen.name == targetName) and chosen.time or nil)
    else
      triInfo = "no-recent-rays"
    end
    if triPos then
      pos, src = triPos, "death+" .. triInfo
    elseif PSM.logEnabled then
      d("[Sul-Xan's marker] triangulation skipped: " .. tostring(triInfo))
    end

    -- 位置が不確かかどうか: 三角測量が使えなかった / 同名の敵が同時に複数倒れた
    local sameNameDeaths, idMatch, otherDeaths = 0, false, 0
    for _, dd in ipairs(recentDeaths) do
      if dd.time >= t - DEATH_BEFORE_MS then
        if dd.name == targetName then sameNameDeaths = sameNameDeaths + 1 else otherDeaths = otherDeaths + 1 end
        if soulTargetId and dd.unitId == soulTargetId then idMatch = true end
      end
    end
    local uncertain = (not triPos) or sameNameDeaths > 1 or otherDeaths > 0 or doubtful == true

    if PSM.logEnabled then
      d(string.format("[Sul-Xan's marker] soul drop: hit=%s pos=%s src=%s death=%s sameNameDeaths=%d otherDeaths=%d idMatch=%s uncertain=%s",
        tostring(hitValue),
        pos and string.format("%d,%d,%d", pos[1], pos[2], pos[3]) or "nil", tostring(src),
        chosen and chosen.name or "nil", sameNameDeaths, otherDeaths, tostring(idMatch), tostring(uncertain)))
    end

    -- 種類の違う敵が同時に倒れていた場合は、魂がどれから出たか分からないので、
    -- そちらの位置も候補として(オレンジで)出す。新しい死亡から最大2種類まで。
    local extras, seen = {}, { [targetName or ""] = true }
    if otherDeaths > 0 and PSM.sv.showCandidates then
      for i = #recentDeaths, 1, -1 do
        local dd = recentDeaths[i]
        if dd.time >= t - DEATH_BEFORE_MS and not seen[dd.name] and #extras < MAX_EXTRA_CANDIDATES then
          seen[dd.name] = true
          local ep, einfo = Triangulate(dd.name, dd.time)
          if not ep then
            local sm = samples[dd.name]
            if sm and now() - sm[4] <= SAMPLE_KEEP_MS then ep = { sm[1], sm[2], sm[3] } end
          end
          if ep then
            extras[#extras + 1] = ep
            if PSM.logEnabled then
              d(string.format("[Sul-Xan's marker] 候補を追加: %s (%s)", dd.name, tostring(einfo or "sample")))
            end
          end
        end
      end
    end

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
        if dist > FALLBACK_MAX_CM then
          if PSM.logEnabled then
            d(string.format("[Sul-Xan's marker] 推測位置が遠すぎる(%dm)ので表示しません", zo_floor(dist / 100)))
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
    if not pos and tooFar then
      PSM.lastDrop = nil
      return   -- 位置が遠すぎる時は、何も表示しない
    end
    if not pos and PSM.sv.hideWhenNoPos then
      PSM.lastDrop = nil
      if PSM.logEnabled then d("[Sul-Xan's marker] 位置が取れないので表示しません(設定)") end
      return
    end

    local all = {}
    if pos then all[1] = pos end
    for _, ep in ipairs(extras) do all[#all + 1] = ep end
    PSM.lastDrop = { pos = pos, all = all, src = src, uncertain = uncertain, sameNameDeaths = sameNameDeaths, name = targetName }
    PSM.Show(math.max(duration - DROP_DELAY_MS, 1000), pos, uncertain, extras)
  end, DROP_DELAY_MS)
end

local function OnSoulPickup(_, result, _, _, _, _, _, sourceType, _, _, hitValue)
  if result ~= ACTION_RESULT_EFFECT_GAINED_DURATION and result ~= ACTION_RESULT_EFFECT_GAINED then
    return
  end
  if not PSM.sv.hideOnPickup then return end
  if PSM.testing then return end
  if now() - PSM.shownAt < PICKUP_GUARD_MS then return end

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
      d(string.format("[Sul-Xan's marker] 拾得: 最も近い矢印(%d/%d番目)との差 水平%dcm 高さ%+dcm (%s / 同名死亡%d / 不確か=%s)",
        bestIdx, #(ld.all or { ld.pos }), zo_floor(bestDh), zo_floor(py - best[2]), (tostring(ld.src):gsub("%(.*", "")),
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
    d(string.format("[Sul-Xan's marker] enemy died: %s (result=%s, unitId=%s) reticle=%s(%s)%s",
      name, tostring(result), tostring(targetUnitId), tostring(rn), hpText,
      (rn and rn ~= name) and (" rawName=" .. tostring(targetName)) or ""))
  end
end

local function ResetState()
  lastPos = nil
  lastDeath = nil
  recentDeaths = {}
  samples = {}
  rays = {}
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
    d("[Sul-Xan's marker] " .. (on and "スルザン装備を検出: 動作開始" or "スルザン装備なし: 完全停止"))
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
  p("装備判定: " .. (PSM.active and "スルザン装備あり(動作中)" or "スルザン装備なし(停止中)"))
  for name, n in pairs(CollectEquippedSets()) do
    p(string.format("  装備中セット: %s x%d%s", (zo_strformat(SI_UNIT_NAME, name)), n, SetNameMatches(name) and "  <- 一致" or ""))
  end
end

local function OnAddOnLoaded(_, addonName)
  if addonName ~= PSM.name then return end
  EM:UnregisterForEvent(PSM.name .. "_Loaded", EVENT_ADD_ON_LOADED)

  PSM.sv = ZO_SavedVars:NewAccountWide("SulXansMarkerVars", 2, nil, PSM.defaults)

  CreateUI()
  PSM.ApplyLayout()
  PSM.RegisterEvents()

  if PSM.CreateSettings then PSM.CreateSettings() end

  local function OnSlashCommand(arg)
    arg = (arg or ""):lower()
    if arg == "test" then
      PSM.Test()
    elseif arg == "unlock" then
      PSM.SetUnlocked(true)
      d("[Sul-Xan's marker] 移動モード ON: アイコンをドラッグして移動。終わったら /sulxan lock")
    elseif arg == "lock" then
      PSM.SetUnlocked(false)
      d("[Sul-Xan's marker] 位置を固定しました")
    elseif arg == "debug" then
      PrintDebug()
    elseif arg == "sets" then
      PrintDebug()
    elseif arg:sub(1, 7) == "setname" then
      local nm = arg:sub(9)
      if nm == "" then
        d("[Sul-Xan's marker] 使い方: /sulxan setname セット名の一部  (/sulxan sets で装備中のセット名を確認)")
      else
        PSM.sv.extraSetNames = PSM.sv.extraSetNames or {}
        table.insert(PSM.sv.extraSetNames, nm)
        d("[Sul-Xan's marker] セット名を追加: " .. nm)
        PSM.UpdateActive()
      end
    elseif arg == "log" then
      PSM.logEnabled = not PSM.logEnabled
      d("[Sul-Xan's marker] ログ " .. (PSM.logEnabled and "ON" or "OFF"))
    else
      d("[Sul-Xan's marker] /sulxan test | unlock | lock | debug | sets | setname <名前> | log")
    end
  end

  SLASH_COMMANDS["/sulxan"]   = OnSlashCommand
  SLASH_COMMANDS["/puyosoul"] = OnSlashCommand  -- 旧名(互換用)
end

EM:RegisterForEvent(PSM.name .. "_Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
