-- Sul-Xan's marker
-- Author: PUYO
-- Sul-Xan's Torment の魂(Soul)がドロップした時に ↓ アイコンを表示する。
--   157738 = 魂(フィールドに出る)  /  154737 = 魂を拾った時のバフ
-- ↓ は LibCombatAlerts の WorldDrawing で、魂が落ちた位置(=倒した敵の位置)の
-- ワールド空間に描画する。位置が取れない場合は画面上の ↓ にフォールバックする。

SulXansMarker = SulXansMarker or {}
local PSM = SulXansMarker

PSM.name    = "SulXansMarker"
PSM.version = "2.6"

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
-- 覚えておいた「敵の足元と自分の足元の高さの差」は、時間が経っていたり、自分がそこから大きく動いたりしていたら使わない
-- (坂や段差のある場所で、前の戦闘の高さの差を使うと、遠い敵ほど大きくずれるため)
local GROUND_DY_MOVE_CM = 1500 -- 学習した場所からこれ以上水平に動いたら無効
local GROUND_DY_RISE_CM = 200  -- 同: 自分の高さがこれ以上変わったら無効
local function KnownGroundDy()
  if not (PSM.groundDy and PSM.groundDyTime and now() - PSM.groundDyTime <= GROUND_DY_KEEP_MS) then return nil end
  local gp = PSM.groundDyPos
  if gp then
    local _, px, py, pz = GetUnitRawWorldPosition("player")
    if not px then return nil end
    if math.sqrt((px - gp[1]) ^ 2 + (pz - gp[3]) ^ 2) > GROUND_DY_MOVE_CM or math.abs(py - gp[2]) > GROUND_DY_RISE_CM then
      return nil
    end
  end
  return PSM.groundDy
end

-- ----------------------------------------------------------------------------
-- 地面の高さの地図(beta1)
-- 自分とグループメンバーの足元の位置(取得できる正確な地面の高さ)を記録し、
-- 照準線を「平らな面」ではなく「実際に誰かが立った地面の高さ」と交差させる。
-- ----------------------------------------------------------------------------
local HM_CELL_CM        = 250    -- 地図の1マスの大きさ
local HM_LEVEL_SEP_CM   = 200    -- 同じマスでこれ以上高さが違えば別の層(橋の上下・段差)
local HM_MAX_LEVELS     = 4
local HM_MAX_CELLS      = 4000   -- 約250m四方。超えたら古いマスから捨てる
local HM_EVICT_RATIO    = 0.1    -- 上限に達した時に、一度に捨てる古いマスの割合
local HM_VSPEED_CM      = 60     -- 0.25秒でこれ以上上下したらジャンプ・落下中とみなして記録しない
local HM_RAY_STEP_CM    = 50     -- 照準線をたどる間隔(胸の高さの近く)
local HM_RAY_STEP_COARSE_CM = 100 -- 照準線をたどる間隔(胸の高さから離れている所)
local HM_FINE_ZONE_CM   = 150    -- 胸の高さとの差がこれ以内なら細かくたどる
local HM_LEVEL_MATCH_CM = 400    -- 照準線の高さからこの範囲の層だけを使う
local HM_MAX_GAP_CM     = 600    -- 地図のない区間がこれより長い時は、交点を決めない
local HM_GRAZE_CM       = 50     -- 交点の後、照準線が胸の高さよりこれ以上上に戻ったら「すれすれ(曖昧)」
local HM_GROUND_TOL_CM  = 50     -- 地面の下に入ったとみなす余裕(地図の高さの誤差分)
local HM_MAX_CROSSINGS  = 8      -- 集める交点の最大数(表示は手前1つと奥2つまで)
local HM_BAND_CM        = 25     -- 照準線が胸の高さのこの範囲を
local HM_BAND_LEN_CM    = 800    -- これ以上の長さ通る時は、その区間の両端も候補にする(階段・坂と平行な照準線)
local HM_TANGENT_CM     = 40     -- 照準線が胸の高さにこれ以下まで近づいてから離れたら、接した(交点)とみなす
local hm = { cells = {}, count = 0, zone = nil }
PSM.hm = hm
local hmPrev = {}

local function HmKey(x, z)
  return (zo_floor(x / HM_CELL_CM) + 50000) * 100000 + (zo_floor(z / HM_CELL_CM) + 50000)
end

-- 層(level)の形: { 中心の高さ, 記録数, 最終時刻, 集計{w,sx,sz,sy,sxx,szz,sxz,sxy,szy}, x方向の傾き, z方向の傾き }
-- マスの中を平面(高さ+傾き)で表す。集計は「マスの中心からのずれ」で持つ。
local HM_SLOPE_MAX     = 1.5     -- 傾きの上限(これより急な地面は扱わない)
local HM_FIT_SPREAD_CM = 30      -- 傾きを求めるのに必要な、位置のばらつき(標準偏差)
local HM_ROUGH_CM      = 50      -- 平面からのずれがこれ以上のマスは、崖の縁などとして扱う
local HM_PTS_PER_LEVEL = 6       -- 層ごとに覚えておく足元の位置の数(新しいものを残す)
local HM_MLS_SIGMA_CM  = 250     -- 周りのマスの記録を使って傾きを求める時の、距離の重みの幅

-- 層(level)の形:
--   [1] 中心の高さ [2] 記録数 [3] 最終時刻 [4] 集計 [5] x方向の傾き [6] z方向の傾き [7] 平面からのずれ(2乗平均)
--   pts = 最近の足元の位置(x,y,z を順に並べた1つの配列。最大 HM_PTS_PER_LEVEL 点)
-- マスの中を平面(高さ+傾き)で表す。傾きは、そのマスと周り8マスの記録から求める(1本の道しか通っていないマスでも、
-- 隣の道の記録から横方向の傾きが分かる)。
local function LvEval(lv, dx, dz)
  return lv[1] + lv[5] * dx + lv[6] * dz
end

-- 重み付きの集計から平面 y = a + b*dx + c*dz を求める(dx, dz は基準点からのずれ)
local function SolvePlane(w, sx, sz, sy, sxx, szz, sxz, sxy, szy, minN)
  if w <= 0 then return nil end
  local mx, mz, my = sx / w, sz / w, sy / w
  local cxx = sxx / w - mx * mx
  local czz = szz / w - mz * mz
  local cxz = sxz / w - mx * mz
  local cxy = sxy / w - mx * my
  local czy = szy / w - mz * my
  local b, c = 0, 0
  local half = (cxx + czz) / 2
  local r = math.sqrt(((cxx - czz) / 2) ^ 2 + cxz * cxz)
  local l1, l2 = half + r, half - r
  local spread2 = HM_FIT_SPREAD_CM * HM_FIT_SPREAD_CM
  if minN >= 4 and l2 > spread2 then
    -- 面として広がって記録されている: 2方向の傾き
    local det = cxx * czz - cxz * cxz
    if det > 0 then
      b = (cxy * czz - czy * cxz) / det
      c = (czy * cxx - cxy * cxz) / det
    end
  elseif minN >= 3 and l1 > spread2 then
    -- 線の上だけ記録されている: 通った方向の傾きだけ
    local ux, uz
    if math.abs(cxz) > 1e-6 then ux, uz = cxz, l1 - cxx else ux, uz = (cxx >= czz) and 1 or 0, (cxx >= czz) and 0 or 1 end
    local len = math.sqrt(ux * ux + uz * uz)
    ux, uz = ux / len, uz / len
    local s = (cxy * ux + czy * uz) / l1
    b, c = s * ux, s * uz
  end
  b = math.max(-HM_SLOPE_MAX, math.min(HM_SLOPE_MAX, b))
  c = math.max(-HM_SLOPE_MAX, math.min(HM_SLOPE_MAX, c))
  return my - b * mx - c * mz, b, c
end

local function LvFit(lv)
  local S = lv[4]
  local a, b, c = SolvePlane(S[1], S[2], S[3], S[4], S[5], S[6], S[7], S[8], S[9], S[1])
  if a then lv[1], lv[5], lv[6] = a, b, c end
end

-- 周り8マスの記録も使った平面(地図が変わるまでキャッシュ)
local function LvPlane(c, lv)
  if lv.mv then return lv.ma, lv.mb, lv.mc end
  local ix, iz = zo_floor(c.cx / HM_CELL_CM), zo_floor(c.cz / HM_CELL_CM)
  local inv2s2 = 1 / (2 * HM_MLS_SIGMA_CM * HM_MLS_SIGMA_CM)
  local w, sx, sz, sy, sxx, szz, sxz, sxy, szy, n = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  for ddx = -1, 1 do
    for ddz = -1, 1 do
      local cc = (ddx == 0 and ddz == 0) and c or hm.cells[HmKey((ix + ddx + 0.5) * HM_CELL_CM, (iz + ddz + 0.5) * HM_CELL_CM)]
      if cc then
        for _, l2 in ipairs(cc) do
          -- 同じ地面(層)とみなせるものだけ使う: 自分の平面を隣のマスの中心まで延ばした高さと比べる
          local same = l2 == lv or math.abs(LvEval(l2, 0, 0) - LvEval(lv, cc.cx - c.cx, cc.cz - c.cz)) < HM_LEVEL_SEP_CM
          local pts = l2.pts
          if same and pts then
            for q = 1, #pts, 3 do
              local py = pts[q + 1]
              local dx, dz = pts[q] - c.cx, pts[q + 2] - c.cz
              local wt = math.exp(-(dx * dx + dz * dz) * inv2s2)
              w = w + wt
              sx, sz, sy = sx + wt * dx, sz + wt * dz, sy + wt * py
              sxx, szz, sxz = sxx + wt * dx * dx, szz + wt * dz * dz, sxz + wt * dx * dz
              sxy, szy = sxy + wt * dx * py, szy + wt * dz * py
              n = n + 1
            end
          end
        end
      end
    end
  end
  local a, b, cc = SolvePlane(w, sx, sz, sy, sxx, szz, sxz, sxy, szy, n)
  if not a then a, b, cc = lv[1], lv[5], lv[6] end
  lv.ma, lv.mb, lv.mc, lv.mv = a, b, cc, true
  return a, b, cc
end

-- (x, z) のマスと周り8マスの、傾きのキャッシュを無効にする(そのマスの記録が変わった時だけ計算し直す)
local function HmInvalidateAround(cx, cz)
  for ddx = -1, 1 do
    for ddz = -1, 1 do
      local cc = hm.cells[HmKey(cx + ddx * HM_CELL_CM, cz + ddz * HM_CELL_CM)]
      if cc then for _, l in ipairs(cc) do l.mv = nil end end
    end
  end
end

-- マス数が上限に達したら、最後に記録した時刻が古いマスから一定割合を捨てる
local function HmEvictOld()
  local list = {}
  for k, c in pairs(hm.cells) do list[#list + 1] = { k, c.t or 0 } end
  table.sort(list, function(a, b) return a[2] < b[2] end)
  local nDrop = math.max(1, zo_floor(#list * HM_EVICT_RATIO))
  for i = 1, nDrop do
    local c = hm.cells[list[i][1]]
    hm.cells[list[i][1]] = nil
    hm.count = hm.count - 1
    if c then HmInvalidateAround(c.cx, c.cz) end
  end
end

local function HmAdd(zone, x, y, z, src)
  if hm.zone ~= zone then hm.cells, hm.count, hm.zone = {}, 0, zone end
  local k = HmKey(x, z)
  local c = hm.cells[k]
  local t = now()
  if not c then
    if hm.count >= HM_MAX_CELLS then HmEvictOld() end
    c = { cx = (zo_floor(x / HM_CELL_CM) + 0.5) * HM_CELL_CM, cz = (zo_floor(z / HM_CELL_CM) + 0.5) * HM_CELL_CM }
    hm.cells[k] = c
    hm.count = hm.count + 1
  end
  c.t = t
  -- 確認用: このマスを誰が記録したか(self / group / comp / pet)
  if src then
    c.by = c.by or {}
    c.by[src] = true
  end
  HmInvalidateAround(c.cx, c.cz)
  local dx, dz = x - c.cx, z - c.cz
  for _, lv in ipairs(c) do
    local pred = LvEval(lv, dx, dz)
    if math.abs(pred - y) < HM_LEVEL_SEP_CM then
      -- 少し浮いた値(小さなジャンプの名残)は混ぜない
      if y <= pred + 50 then
        -- 平面からのずれ(崖の縁など、平面で表せないマスの目安)
        lv[7] = (lv[7] or 0) * 0.9 + (y - pred) ^ 2 * 0.1
        local S = lv[4]
        if S[1] >= 40 then for i = 1, 9 do S[i] = S[i] * 0.5 end end   -- 新しい記録を重視
        S[1] = S[1] + 1
        S[2] = S[2] + dx; S[3] = S[3] + dz; S[4] = S[4] + y
        S[5] = S[5] + dx * dx; S[6] = S[6] + dz * dz; S[7] = S[7] + dx * dz
        S[8] = S[8] + dx * y; S[9] = S[9] + dz * y
        LvFit(lv)
        -- 最近の足元の位置を覚える(古いものから置き換える)
        lv.pi = (lv.pi or 0) % HM_PTS_PER_LEVEL + 1
        local q = (lv.pi - 1) * 3
        local pts = lv.pts
        pts[q + 1], pts[q + 2], pts[q + 3] = x, y, z
      end
      lv[2] = lv[2] + 1
      lv[3] = t
      return
    end
  end
  if #c < HM_MAX_LEVELS then
    c[#c + 1] = { y, 1, t, { 1, dx, dz, y, dx * dx, dz * dz, dx * dz, dx * y, dz * y }, 0, 0, 0, pts = { x, y, z }, pi = 1 }
  end
end

-- (x, z) の地面の高さ。nearY に近い層を選ぶ。マスごとの平面(傾き付き)で求め、周りのマスとなめらかにつなぐ。
-- マスに記録がなければ周りのマスの平面を延ばして平均する(direct=false)
-- 戻り値: 高さ, 確かな地面か(direct), 崖の縁などで平面で表せないか(rough)
local function HmHeight(x, z, nearY)
  if hm.count == 0 then return nil end
  local function pick(c)
    local best, bd, rough
    local dx, dz = x - c.cx, z - c.cz
    for _, lv in ipairs(c) do
      local a, b, cc = LvPlane(c, lv)
      local h = a + b * dx + cc * dz
      local dd = math.abs(h - nearY)
      if dd <= HM_LEVEL_MATCH_CM and (not bd or dd < bd) then best, bd, rough = h, dd, (lv[7] or 0) > HM_ROUGH_CM * HM_ROUGH_CM end
    end
    return best, rough
  end
  local c = hm.cells[HmKey(x, z)]
  local hc, hcRough
  if c then hc, hcRough = pick(c) end
  if hc then
    local gx, gz = x / HM_CELL_CM - 0.5, z / HM_CELL_CM - 0.5
    local ix, iz = zo_floor(gx), zo_floor(gz)
    local wx, wz = gx - ix, gz - iz
    local acc, wsum = 0, 0
    for ddx = 0, 1 do
      for ddz = 0, 1 do
        local w = (ddx == 1 and wx or 1 - wx) * (ddz == 1 and wz or 1 - wz)
        local cc = hm.cells[HmKey((ix + ddx + 0.5) * HM_CELL_CM, (iz + ddz + 0.5) * HM_CELL_CM)]
        local hh = cc and pick(cc)
        if hh and math.abs(hh - hc) < HM_LEVEL_SEP_CM then acc, wsum = acc + hh * w, wsum + w end
      end
    end
    -- 平面で表せないマス(崖の縁など)は「確かな地面」として扱わない
    if wsum > 0.25 then return acc / wsum, not hcRough, hcRough end
    return hc, not hcRough, hcRough
  end
  local sum, n = 0, 0
  for dx = -1, 1 do
    for dz = -1, 1 do
      if dx ~= 0 or dz ~= 0 then
        local cc = hm.cells[HmKey(x + dx * HM_CELL_CM, z + dz * HM_CELL_CM)]
        if cc then
          local h = pick(cc)
          if h then sum, n = sum + h, n + 1 end
        end
      end
    end
  end
  if n > 0 then return sum / n, false end
end

-- 照準線をたどり、「敵の胸の高さ(地面+AIM_PLANE_HEIGHT_CM)」を上から下へ横切る点を集める。
-- 戻り値: 交点の一覧(手前から), 状態
--   "ground": 交点の後、照準線が(実際に記録のあるマスで)地面の下に入った → 交点は1つに決まる
--   "graze" : 交点の後に照準線が胸の高さより上へ戻った(地面すれすれ) → 手前と奥の交点のどれか(曖昧)
--   "open"  : 交点の先の地面の記録がない → 奥にいる可能性を否定できない
local function HmRayScan(ox, oy, oz, fx, fy, fz)
  local list = {}
  if hm.count == 0 or not fy then return list, nil end
  local prevDiff, prevT, below, grazed, lastKnownT = nil, nil, false, false, nil
  local minDiff, minPt, armed = nil, nil, true
  -- 照準線が胸の高さ付近(±HM_BAND_CM)を長く通る区間: その区間のどこに敵がいてもおかしくない
  local bandS, bandE, bandHasCross = nil, nil, false
  local roughCross = false

  local function closeBand()
    if bandS and bandHasCross and bandE and bandE[4] - bandS[4] > HM_BAND_LEN_CM then
      list[#list + 1] = { bandS[1], bandS[2], bandS[3], bandS[4] }
      list[#list + 1] = { bandE[1], bandE[2], bandE[3], bandE[4] }
      grazed = true
    end
    bandS, bandE, bandHasCross = nil, nil, false
  end

  local function finish(status)
    closeBand()
    if #list == 0 then return list, nil end
    table.sort(list, function(a, b) return a[4] < b[4] end)
    -- 近すぎる候補(3m未満)はまとめる
    local merged = {}
    for _, c in ipairs(list) do
      local last = merged[#merged]
      if not last or math.sqrt((c[1] - last[1]) ^ 2 + (c[3] - last[3]) ^ 2) >= 300 then merged[#merged + 1] = c end
    end
    if #merged > 1 then grazed = true end
    if roughCross and status == "ground" then status = "open" end
    -- 交点が多すぎる時(階段など)は、手前の1つと奥の2つだけにする
    if #merged > 3 then merged = { merged[1], merged[#merged - 1], merged[#merged] } end
    if grazed then return merged, "graze" end
    return merged, status
  end

  local t = HM_RAY_STEP_CM
  local step = HM_RAY_STEP_CM
  while t <= MAX_RAY_CM do
    local x, y, z = ox + fx * t, oy + fy * t, oz + fz * t
    local h, direct, rough = HmHeight(x, z, y - AIM_PLANE_HEIGHT_CM)
    if h then
      local diff = y - (h + AIM_PLANE_HEIGHT_CM)
      -- 胸の高さ付近の区間を記録
      if math.abs(diff) <= HM_BAND_CM then
        if not bandS then bandS = { x, h, z, t } end
        bandE = { x, h, z, t }
      else
        closeBand()
      end
      if direct and diff < -AIM_PLANE_HEIGHT_CM - HM_GROUND_TOL_CM then
        -- 照準線が地面の下に入った(ここより奥は見えない)
        return finish("ground")
      end
      if diff <= 0 then
        if not below then
          if prevDiff and t - prevT <= HM_MAX_GAP_CM then
            local tt = prevT + (t - prevT) * prevDiff / (prevDiff - diff)
            list[#list + 1] = { ox + fx * tt, h, oz + fz * tt, tt }
            bandHasCross = true
            -- 崖の縁など、地面の高さが不確かなマスでの交点は、奥にいる可能性も残す
            if rough then roughCross = true end
            if #list >= HM_MAX_CROSSINGS then return finish("graze") end
          end
          below = true
        end
        minDiff, minPt, armed = nil, nil, false
      else
        if below and diff > HM_GRAZE_CM then below, grazed = false, true end
        if not below then
          prevDiff, prevT = diff, t
          -- 胸の高さに接するだけで横切らない(ほぼ水平な照準線)場合も交点として扱う
          if diff > HM_GRAZE_CM then armed = true end
          if armed then
            if not minDiff or diff < minDiff then
              minDiff, minPt = diff, { x, h, z, t }
            elseif minDiff < HM_TANGENT_CM and diff > minDiff + HM_GRAZE_CM then
              list[#list + 1] = minPt
              bandHasCross = true
              minDiff, minPt, armed = nil, nil, false
              if #list >= HM_MAX_CROSSINGS then return finish("graze") end
            end
          end
        end
      end
      if direct then lastKnownT = t end
      -- 胸の高さから離れている所は粗く、近い所は細かくたどる
      step = (diff < HM_FINE_ZONE_CM and diff > -HM_FINE_ZONE_CM) and HM_RAY_STEP_CM or HM_RAY_STEP_COARSE_CM
    elseif #list > 0 and lastKnownT and t - lastKnownT > HM_MAX_GAP_CM then
      return finish("open")
    else
      step = HM_RAY_STEP_COARSE_CM
    end
    t = t + step
  end
  return finish("open")
end

local function HmSampleUnit(tag, zone0)
  local okp, zone, x, y, z = pcall(GetUnitRawWorldPosition, tag)
  if not okp or not x or (x == 0 and y == 0 and z == 0) or zone ~= zone0 then return end
  local t = now()
  local p = hmPrev[tag]
  hmPrev[tag] = { x, y, z, t }
  if not p or t - p[4] > 1000 then return end
  -- ジャンプ・落下中は記録しない(急な坂を歩いている時は記録する: 水平の移動より上下が大きい時だけ除外)
  local dv = math.abs(y - p[2])
  local dh = math.sqrt((x - p[1]) ^ 2 + (z - p[3]) ^ 2)
  if dv > HM_VSPEED_CM and dv > dh then return end
  local src = (tag == "player" and "self")
    or ((tag == "companion" or tag:find("companion", 1, true)) and "comp")
    or (tag:find("^playerpet") and "pet")
    or "group"
  HmAdd(zone, x, y, z, src)
end

local function HmSample()
  local okz, zone0 = pcall(GetUnitRawWorldPosition, "player")
  if not okz or not zone0 or zone0 == 0 then return end
  HmSampleUnit("player", zone0)
  -- 自分のコンパニオンの足元も地図に使う(敵の近くまで走って行くので、遠くの地面が早く埋まる)
  if DoesUnitExist and DoesUnitExist("companion") then HmSampleUnit("companion", zone0) end
  -- 自分の戦闘ペット(ソーサラーの使い魔など)の足元も地図に使う(petprobe で座標が取れることを確認済み)
  if DoesUnitExist then
    for i = 1, 7 do
      local tag = "playerpet" .. i
      if DoesUnitExist(tag) then HmSampleUnit(tag, zone0) end
    end
  end
  if IsUnitGrouped and IsUnitGrouped("player") then
    for i = 1, GetGroupSize() do
      local tag = GetGroupUnitTagByIndex(i)
      if tag and not AreUnitsEqual(tag, "player") then
        HmSampleUnit(tag, zone0)
        -- 仲間のコンパニオン(関数がない版では "groupcompanionN" の名前で探す)
        local ctag
        if GetCompanionUnitTagByGroupUnitTag then
          local okc, c = pcall(GetCompanionUnitTagByGroupUnitTag, tag)
          if okc then ctag = c end
        else
          local n = tag:match("^group(%d+)$")
          if n then ctag = "groupcompanion" .. n end
        end
        if ctag and ctag ~= "" and DoesUnitExist and DoesUnitExist(ctag) then HmSampleUnit(ctag, zone0) end
      end
    end
  end
end
PSM.HmSample, PSM.HmRayScan, PSM.HmHeight = HmSample, HmRayScan, HmHeight

-- 確認用: 向いている方向(カメラの水平方向)に沿って、地図の地面の高さを1mごとにチャットへ出す
-- 階段・坂の地図が取れているかを確かめる(/sulxan hmline [距離m])
function PSM.HmProfile(maxM)
  maxM = math.max(5, math.min(tonumber(maxM) or 20, 50))
  local okp, _, px, py, pz = pcall(GetUnitRawWorldPosition, "player")
  local okc, _, _, _, fx, _, fz = pcall(GetCameraRay)
  if not (okp and px and okc and fx) then
    d("[Sul-Xan's marker] hmline: 位置または向きが取れません")
    return
  end
  local hl = math.sqrt(fx * fx + fz * fz)
  if hl < 0.01 then d("[Sul-Xan's marker] hmline: 真上・真下を向いています") return end
  fx, fz = fx / hl, fz / hl
  d(string.format("[Sul-Xan's marker] hmline: 前方%dmの地面の高さ(自分の足元=0、m) 地図のマス数=%d", maxM, hm.count))
  d("  記号: 数字だけ=記録したマス / ~=周りのマスから推定 / ?=凸凹で平面にならないマス / *=上下に2層以上(橋・2階) / --=記録なし")
  local items, nearY = {}, py
  local have, est, none, lo, hi, maxStep, prevH = 0, 0, 0, nil, nil, 0, nil
  for m = 0, maxM do
    local x, z = px + fx * m * 100, pz + fz * m * 100
    local h, direct, rough = HmHeight(x, z, nearY)
    local c = hm.cells[HmKey(x, z)]
    local lvN = c and #c or 0
    local txt
    if h then
      nearY = h
      local rel = (h - py) / 100
      txt = string.format("%+.1f", rel)
      if not direct then txt = txt .. (rough and "?" or "~") end
      if lvN >= 2 then txt = txt .. "*" end
      if direct then have = have + 1 else est = est + 1 end
      lo = (not lo or rel < lo) and rel or lo
      hi = (not hi or rel > hi) and rel or hi
      if prevH then maxStep = math.max(maxStep, math.abs(h - prevH) / 100) end
      prevH = h
    else
      txt = "--"
      none = none + 1
      prevH = nil
    end
    items[#items + 1] = string.format("%dm:%s", m, txt)
  end
  for i = 1, #items, 7 do
    d("  " .. table.concat(items, "  ", i, math.min(i + 6, #items)))
  end
  d(string.format("  記録 %d点 / 推定 %d点 / なし %d点  高さの範囲 %s〜%s m  1mあたりの最大の高低差 %.1f m",
    have, est, none, lo and string.format("%+.1f", lo) or "-", hi and string.format("%+.1f", hi) or "-", maxStep))
  -- 誰が記録したか(地図全体と、この線上のマス)。1つのマスを複数が記録していれば、それぞれに数える
  local function countBy(cells)
    local n = { self = 0, group = 0, comp = 0, pet = 0, only = { self = 0, group = 0, comp = 0, pet = 0 } }
    for _, c in pairs(cells) do
      if c.by then
        local k1, cnt = nil, 0
        for k in pairs(c.by) do if n[k] then n[k] = n[k] + 1; k1 = k; cnt = cnt + 1 end end
        if cnt == 1 then n.only[k1] = n.only[k1] + 1 end
      end
    end
    return n
  end
  local all = countBy(hm.cells)
  local lineCells, seen = {}, {}
  for m = 0, maxM do
    local k = HmKey(px + fx * m * 100, pz + fz * m * 100)
    if not seen[k] and hm.cells[k] then seen[k] = true; lineCells[#lineCells + 1] = hm.cells[k] end
  end
  local ln = countBy(lineCells)
  d(string.format("  記録者(地図全体 %dマス): 自分 %d(だけ %d) / グループ %d(だけ %d) / コンパニオン %d(だけ %d) / ペット %d(だけ %d)",
    hm.count, all.self, all.only.self, all.group, all.only.group, all.comp, all.only.comp, all.pet, all.only.pet))
  d(string.format("  記録者(この線上 %dマス): 自分 %d / グループ %d / コンパニオン %d / ペット %d",
    #lineCells, ln.self, ln.group, ln.comp, ln.pet))
end

local function RayAimPos()
  local ok, ox, oy, oz, fx, fy, fz = pcall(GetCameraRay)
  if not ok or not ox or not fy then return end
  local _, px, py, pz = GetUnitRawWorldPosition("player")
  if not py then return end
  -- 地面の高さの地図があれば、まずそれと交差させる(上向きの照準でも、上り坂の上の敵と交わる)
  local cr, status = HmRayScan(ox, oy, oz, fx, fy, fz)
  if #cr > 0 then
    local alts
    if status == "graze" and #cr > 1 then
      alts = {}
      for k = 2, #cr do alts[#alts + 1] = cr[k] end
    end
    local method = (status == "ground" and "hm") or (status == "graze" and "amb") or "hmo"
    return cr[1][1], cr[1][2], cr[1][3], method, alts
  end
  if fy > -0.01 then return end                -- 水平〜上向きでは水平面との交点なし
  local ambiguous = false
  -- 直近の三角測量で分かった「敵の足元と自分の足元の高さの差」を、水平面の高さに反映する
  -- (坂道でも、近くの地形はつながっているので、0 と仮定するよりずれにくい)
  local dy = KnownGroundDy() or 0
  local t = ((py + dy + AIM_PLANE_HEIGHT_CM) - oy) / fy
  if t <= 0 or t > MAX_RAY_CM then return end
  return ox + fx * t, py + dy, oz + fz * t, ambiguous and "amb" or "plane"
end

-- 照準中の敵の位置: ユニット座標が取れればそれ、取れなければ照準の延長線から求める
local function GetTargetPos()
  local x, y, z = ReadPos("reticleover")
  if x then return x, y, z, "api" end
  local m, alts
  x, y, z, m, alts = RayAimPos()
  if x then return x, y, z, (m == "hm" or m == "amb" or m == "hmo") and m or "ray", alts end
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
local RAY_WINDOW_MS   = 3000 -- 計算に使う線の保持時間(モック検証で3秒が最適: 古い線が混ざって外れることが減る)
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
local DEPTH_ERR_WARN_CM = 100   -- 奥行き誤差の見積もりがこれ以上なら「不確か」(オレンジ)(v2.6.0 で 4.5m→1m)
local DEPTH_ERR_MAX_CM  = 1000  -- これ以上なら三角測量を採用しない(線がほぼ平行で、奥行きが当てにならない)
local TRI_FAR_WARN_CM   = 4000  -- 三角測量の結果がこれより遠ければ「不確か」
local HEIGHT_UNC_FLAT_CM  = 120  -- 高さの差が未知(平地と仮定)の時の、地面の高さの不確かさ(cm)
local HEIGHT_UNC_KNOWN_CM = 60   -- 高さの差が分かっている時の同(cm)
local HEIGHT_UNC_HM_CM    = 40   -- 地面の高さの地図で確かめられた時の同(cm)
local HEIGHT_UNC_AMB_CM   = 400  -- 照準線が地面すれすれを通り、奥行きが曖昧な時の同(cm)
local GROUND_SHIFT_WARN_CM = 500 -- 仮定の地面の条件で三角測量の答えがこれ以上動いたら不確か
local HEIGHT_ERR_WARN_CM  = 1200 -- 水平方向の誤差の見積もりがこれ以上なら「不確か」(オレンジ)
local HEIGHT_ERR_HIDE_CM  = 3500 -- 同: これ以上なら表示しない
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
PSM.abc = PSM.abc or { A = true, B = true, C = true }   -- beta4: A・B・C を使う
local DOMINANT_ID_RATIO    = 0.75 -- 区間で最多のIDの何割以上当てていれば「主に狙ったID」とみなすか
local DOMINANT_ID_MATCH_MS = 6000 -- 主に狙ったIDを死亡と結び付ける最大時間(仲間がとどめを刺すまでの時間も含む)

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
local function OnPlayerCombatTarget(_, _, _, _, _, _, _, sourceType, targetName, _, hitValue, _, _, _, _, targetUnitId, abilityId)
  if sourceType ~= COMBAT_UNIT_TYPE_PLAYER or not targetUnitId then return end
  if PSM.NoteHitRange then PSM.NoteHitRange(hitValue, abilityId) end
  -- G: 当てた瞬間に照準していた敵の名前を、当てた個体IDごとに覚える
  if hitValue and hitValue > 0 and targetUnitId ~= 0 then
    local hits = PSM.aoeHits
    if hits then
      local aimName = ReticleName()
      hits[targetUnitId] = { t = now(), aimName = aimName, abilityId = abilityId }
      -- 照準中の敵(と同じ名前の個体)に当たった時刻を、スキルごとに覚える
      if aimName and abilityId and abilityId ~= 0 and NormalizeName(targetName) == aimName and PSM.aimAbilityHits then
        local ah = PSM.aimAbilityHits
        ah[abilityId] = ah[abilityId] or {}
        ah[abilityId][targetUnitId] = now()
      end
      hits.n = (hits.n or 0) + 1
      if hits.n > 300 then
        local tt = now()
        for k, v in pairs(hits) do if type(v) == "table" and tt - v.t > 10000 then hits[k] = nil end end
        for aid, list in pairs(PSM.aimAbilityHits) do
          local any = false
          for uid, at in pairs(list) do if tt - at > 10000 then list[uid] = nil else any = true end end
          if not any then PSM.aimAbilityHits[aid] = nil end
        end
        hits.n = 0
      end
    end
  end
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
    -- 照準中に当てた回数を数える(範囲攻撃で同名の別個体のIDが混ざっても、主に狙った個体が最多になる)
    best.unitHits = best.unitHits or {}
    best.unitHits[targetUnitId] = (best.unitHits[targetUnitId] or 0) + 1
  end
end

-- 倒れた敵の個体を選ぶ。戻り値: 個体, 倒れたと確認できたか, 候補の個体数
-- deathTime: 死亡イベントの時刻。この時刻の前後で体力が 0 になった個体が「倒れた個体」。
-- (体力 0 の別の死体や、生きている同名の敵とは区別する)
local SegUsable
-- 線の区間が、この死亡の推定に使えるか
-- ・前の魂の推定に使った区間(consumed)は使わない(同じ個体の魂は1回だけ)
-- ・この死亡より前に体力0になって倒れていた区間は、別の(先に倒れた)個体なので使わない
local SEG_DEAD_BEFORE_MS = 800   -- ゲーム内のログでは、体力0と死亡イベントの差は最大0.53秒
local SEG_ALIVE_AFTER_MS = 150   -- 死亡からこの時間より後に照準で体力を確認できた区間は「生きている」
local SEG_ALIVE_HP_RATIO = 0.1   -- その時の体力がこの割合より多ければ、倒れた個体ではない
SegUsable = function(sg, t, deathTime)
  if #sg.list == 0 or sg.consumed or t - sg.last > DEAD_WINDOW_MS then return false end
  if sg.deadAt and deathTime and sg.deadAt < deathTime - SEG_DEAD_BEFORE_MS then return false end
  -- 死亡の後も照準していて、体力が残っている区間は、倒れた個体ではない
  -- (前の同名の敵を照準中に、背後の同名の敵が範囲攻撃・DoTで倒れた時に、前の敵の位置を使わないため)
  if deathTime and sg.last >= deathTime + SEG_ALIVE_AFTER_MS and sg.hpMax and sg.hpMax > 0
      and sg.hp > sg.hpMax * SEG_ALIVE_HP_RATIO then return false end
  return true
end

local function ChooseSegment(e, deathTime, deathUnitId)
  local t = now()
  local dead, deadDiff, recent, cands = nil, nil, nil, 0
  local idMatch, idMatchAge, idMatchCount = nil, nil, 0
  local domMatch, domAge, domCount = nil, nil, 0
  for _, sg in ipairs(e.segs) do
    if SegUsable(sg, t, deathTime) then
      cands = cands + 1
      local idTime = deathUnitId and sg.unitIds and sg.unitIds[deathUnitId]
      if idTime and deathTime and math.abs(idTime - deathTime) <= UNIT_ID_MATCH_MS then
        idMatchCount = idMatchCount + 1
        idMatch, idMatchAge = sg, math.abs(idTime - deathTime)
      end
      -- その線の区間で最も多く当てたIDが死亡個体のIDなら、その区間が倒れた個体(同名が複数いても使う)
      if deathUnitId and sg.unitHits and sg.unitHits[deathUnitId] then
        local mine, top = sg.unitHits[deathUnitId], 0
        for _, c in pairs(sg.unitHits) do if c > top then top = c end end
        local lastHit = sg.unitIds and sg.unitIds[deathUnitId]
        local isDom = mine >= 2 and mine >= top * DOMINANT_ID_RATIO
        if PSM.abc.B then
          if isDom and lastHit and deathTime and math.abs(lastHit - deathTime) <= DOMINANT_ID_MATCH_MS then
            domCount = domCount + 1
            domMatch, domAge = sg, math.abs(lastHit - deathTime)
          end
        elseif lastHit and deathTime and math.abs(lastHit - deathTime) <= UNIT_ID_MATCH_MS then
          -- Bなし: 当てた回数は見ずに、時間内に当てたIDなら一致とする
          domCount = domCount + 1
          domMatch, domAge = sg, math.abs(lastHit - deathTime)
        end
        sg.domFlag = isDom
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
  -- 従来: 追跡中の候補が1つだけの時のID一致(Bありなら、主に狙ったIDに限る)
  if idMatchCount == 1 and cands == 1 and (not PSM.abc.B or idMatch.domFlag) then return idMatch, true, cands, "unitId", idMatchAge end
  -- A: 候補が複数でも、IDの一致が1区間だけなら採用
  if PSM.abc.A and domCount == 1 then return domMatch, true, cands, PSM.abc.B and "unitId-dom" or "unitId-any", domAge end
  if dead then return dead, true, cands, "hp-time" end
  -- 同名の敵を複数追跡していて死亡個体を特定できない場合、
  -- 最新の線を本命として使うと別個体の位置を採用するおそれがある。
  if cands > 1 then return nil, false, cands, "ambiguous-segments" end
  return recent, false, cands, "recent"
end

-- この名前で最後に照準していた個体が、死亡の後も体力を残して生きているか
-- (生きていれば、魂の瞬間の照準位置や直近の位置サンプルは、倒れた個体の位置ではない)
local function AimedStillAlive(name, deathTime)
  local e = name and rays[name]
  if not e or not deathTime then return false end
  local latest
  for _, sg in ipairs(e.segs) do
    if not latest or sg.last > latest.last then latest = sg end
  end
  return latest ~= nil and latest.last >= deathTime + SEG_ALIVE_AFTER_MS and latest.hpMax and latest.hpMax > 0
    and latest.hp > latest.hpMax * SEG_ALIVE_HP_RATIO
end
PSM.AimedStillAlive = AimedStillAlive

local function RecentSegmentCount(e, t)
  if not e then return 0 end
  t = t or now()
  local count = 0
  for _, sg in ipairs(e.segs) do
    if SegUsable(sg, t, nil) then count = count + 1 end
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
local function TriangulateCore(name, deathTime, deathUnitId)
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
      local known = KnownGroundDy()
      gyWorld = gpy + (known or 0) + AIM_PLANE_HEIGHT_CM
      gwRatio = known and GROUND_W_KNOWN or GROUND_W_UNKNOWN
    end
  end

  -- まず地面の条件なしで解く。奥行きの誤差の見積もりが大きい(線がほぼ平行)時だけ、
  -- 地面の条件を加えて解き直す(奥行きが十分決まる時は、坂などで悪影響が出ないよう使わない)
  local usedGround, hmUsed, groundShift = false, false, 0
  local function SolveAuto(list, tauOverride)
    local tau = tauOverride or tauMs
    local a1, a2, a3, a4, a5, a6, a7, a8 = Solve(list, nil, nil, tau)
    if a1 and gyWorld then
      local dd = math.sqrt(a1 * a1 + a2 * a2 + a3 * a3)
      if dd * dd * AIM_NOISE_RAD / a7 > GROUND_USE_DERR_CM then
        -- 地面の高さの地図があれば、推定位置の実際の地面の高さを使う(強めの条件)
        local gy, gw, useHm = gyWorld, gwRatio, false
        local h = HmHeight(a1 + a4, a3 + a6, a2 + a5 - AIM_PLANE_HEIGHT_CM)
        if h then gy, gw, useHm = h + AIM_PLANE_HEIGHT_CM, GROUND_W_KNOWN, true end
        local b1, b2, b3, b4, b5, b6, b7, b8 = Solve(list, gy, gw, tau)
        if b1 and useHm then
          -- 解き直した位置で地面の高さを引き直し、違えばもう一度解く
          local h2 = HmHeight(b1 + b4, b3 + b6, b2 + b5 - AIM_PLANE_HEIGHT_CM)
          if h2 and math.abs(h2 - h) > 30 then
            local c1, c2, c3, c4, c5, c6, c7, c8 = Solve(list, h2 + AIM_PLANE_HEIGHT_CM, GROUND_W_KNOWN, tau)
            if c1 then b1, b2, b3, b4, b5, b6, b7, b8 = c1, c2, c3, c4, c5, c6, c7, c8 end
          end
        end
        if b1 then
          usedGround = true; hmUsed = useHm
          -- 地面の条件で答えがどれだけ動いたか(平地の仮定で大きく動いたなら、その位置は仮定頼み)
          groundShift = math.sqrt(((b1 + b4) - (a1 + a4)) ^ 2 + ((b3 + b6) - (a3 + a6)) ^ 2)
          return b1, b2, b3, b4, b5, b6, b7, b8
        end
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
    groundShift = usedGround and groundShift or 0,
    groundMode = usedGround and (hmUsed and "hm" or "assumed") or "off",
    seg = seg,
  }
  return pos, string.format("tri(n=%d,base=%d/%dcm,res=%dcm,dist=%dm,derr=%dcm,last=%dcm,proj=%dcm,trim=%d,win=%.1fs,gnd=%s,%s%d)",
    n, zo_floor(baseline), MIN_BASELINE_CM, zo_floor(resid), zo_floor(dist / 100), zo_floor(depthErr), zo_floor(lastOff), zo_floor(shift), trimmed, (l[n][1] - l[1][1]) / 1000, usedGround and (hmUsed and "hm" or (gwRatio >= GROUND_W_KNOWN and "known" or "flat")) or "off",
    isDead and (matchMethod .. "/") or "alive/", cands) .. string.format(" gs=%dcm", zo_floor(usedGround and groundShift or 0)) .. " segs=" .. SegDiag(e, deathTime)
    .. " idms=" .. tostring(unitIdAgeMs or "-"), quality
end

-- 三角測量ができない時(止まったまま攻撃した・敵が動いていた等)でも、倒れた個体の線の区間が特定できていれば、
-- その区間の最後の照準線(とどめ直前に狙っていた方向)を地面の地図と交差させて位置にする。
-- 同名の敵が複数いても、区間を特定できれば使える(従来の照準スナップショットは同名が複数いると使えなかった)。
PSM.def = PSM.def or { D = false, D2 = false, E = false, F = true, F2 = true, G = true, Fnear = 500 }   -- beta4: F2・G を使う(F2 は F の改良なので F も有効)
local LASTRAY_MAX_AGE_MS = 1500   -- E: これより古い最後の線は使わない
local GROUP_RAY_NEAR_CM  = 500    -- F: 照準線からこの距離以内に立っているメンバーを使う(近接スキルの届く距離)
local F2_WINDOW_CM       = 700    -- F2: メンバーの位置からこの範囲の地図の交点を使う

-- F/F2: 照準線の近くに立っている仲間から、敵の位置を決める(beta6 で条件を厳しくした)
-- ・自分のすぐ前(5m未満)にいる仲間は使わない(自分の近くのヒーラー等を敵と間違えないため)
-- ・地図の交点がある時は、仲間の近く(前後7m以内)に交点がある場合だけ、その交点を使う。仲間から離れた交点しかない時は仲間を使わない
-- ・仲間の足元を照準線に投影した点は、仲間が今の推定位置(交点)の前後7m以内か奥にいる時だけ使う(推定位置がない時は照準線から3m以内の仲間に限る。照準線上で離れた2人以上が該当する時は使わない)
local GROUP_MIN_T_CM        = 500
local GROUP_NOMAP_NEAR_CM   = 300
local GROUP_CONFLICT_CM     = 1000
local GROUP_FAR_EST_CM      = 3000  -- 推定位置がこれより遠い時は、ほとんどのスキルの射程(28m)より遠く疑わしいので、手前の仲間を使ってよい
local function GroupRayPick(ox, oy, oz, fx, fy, fz, cr, cur)
  if not (IsUnitGrouped and IsUnitGrouped("player")) then return nil end
  local near = PSM.def.Fnear or GROUP_RAY_NEAR_CM
  local hasMap = cr and #cr > 0
  local found = {}
  for i = 1, GetGroupSize() do
    local tag = GetGroupUnitTagByIndex(i)
    if tag and not AreUnitsEqual(tag, "player") then
      local ok, _, mx, my, mz = pcall(GetUnitRawWorldPosition, tag)
      if ok and mx and not (mx == 0 and mz == 0) then
        local dx, dy, dz = mx - ox, my + AIM_PLANE_HEIGHT_CM - oy, mz - oz
        local tt = dx * fx + dy * fy + dz * fz
        if tt >= GROUP_MIN_T_CM then
          local qx, qy, qz = dx - tt * fx, dy - tt * fy, dz - tt * fz
          local dd = math.sqrt(qx * qx + qy * qy + qz * qz)
          if dd <= ((hasMap or cur) and near or math.min(near, GROUP_NOMAP_NEAR_CM)) then
            found[#found + 1] = { dd = dd, t = tt, p = { ox + fx * tt, my, oz + fz * tt } }
          end
        end
      end
    end
  end
  if #found == 0 then return nil end
  table.sort(found, function(a, b) return a.dd < b.dd end)
  -- 仲間を使ってよいのは、今の推定位置(地図の交点や水平面との交点)の前後7m以内か、それより奥にいる時だけ
  -- (照準線の途中・自分寄りに立っている遠距離の仲間を、敵の位置と間違えないため。
  --  推定位置より奥にいる仲間は、照準線が崖の手前や地図の端で止まって手前に出た時の手がかりになる。
  --  推定位置が30mより遠い時は、推定位置自体が疑わしいので手前の仲間も使う)
  local function RayT(px, pz)
    local hl2 = fx * fx + fz * fz
    if hl2 < 0.0001 then return nil end
    return ((px - ox) * fx + (pz - oz) * fz) / hl2
  end
  local m = found[1]
  if hasMap then
    if not PSM.def.F2 then return nil end
    -- 照準線に一番近い仲間の近くにある地図の交点を使う
    local pick
    for _, c in ipairs(cr) do
      if c[4] and math.abs(c[4] - m.t) <= F2_WINDOW_CM and (not pick or math.abs(c[4] - m.t) < math.abs(pick[4] - m.t)) then pick = c end
    end
    if pick then return { pick[1], pick[2], pick[3] }, "grp+hm" end
    -- 仲間の近くに交点がない: ここに来るのは地図で地面が確定しなかった時(すれすれ・地図の外へ抜けた)なので、
    -- 交点自体が疑わしい。仲間の足元を照準線に投影した点を使う
    return m.p, "grp"
  elseif cur then
    local ct = RayT(cur[1], cur[3])
    local far = (cur[1] - ox) ^ 2 + (cur[3] - oz) ^ 2 > GROUP_FAR_EST_CM ^ 2
    if ct and m.t < ct - F2_WINDOW_CM and not far then return nil end
  end
  -- 照準線上で離れた位置に別の仲間もいるなら、どちらか決められないので使わない
  for k = 2, #found do
    if math.abs(found[k].t - found[1].t) > GROUP_CONFLICT_CM then return nil end
  end
  return found[1].p, "grp"
end
local LASTRAY_REASONS = { ["small-baseline"] = true, ["small-baseline-final"] = true, ["few-rays"] = true,
  ["large-residual"] = true, ["bad-distance"] = true, ["tri-conflict"] = true }
-- 交点の確認: 最後の照準線を地図または水平面と交差させた位置と、交点が離れすぎていたら交点を捨てる
-- (無敵中に移動した敵など、移動前と移動後に向けた線が混ざると、自分の近くに誤った交点ができるため)
PSM.TRI_LASTRAY_CONFLICT_CM = 500
PSM.TRI_RAY_COMPARE_MAX_CM = 1200
local function Triangulate(name, deathTime, deathUnitId)
  local pos, info, quality = TriangulateCore(name, deathTime, deathUnitId)
  if pos and type(quality) == "table" and quality.seg then
    local seg, r = quality.seg, nil
    for k = #seg.list, 1, -1 do
      if not deathTime or seg.list[k][1] <= deathTime + DROP_DELAY_MS then r = seg.list[k]; break end
    end
    if r then
      local ox, oy, oz, fx, fy, fz = r[2], r[3], r[4], r[5], r[6], r[7]
      local cr, status = HmRayScan(ox, oy, oz, fx, fy, fz)
      local lp, lm
      if #cr > 0 then
        lp, lm = cr[1], (status == "ground" and "hm") or (status == "graze" and "amb") or "hmo"
      elseif fy < -0.01 then
        local _, _, py = GetUnitRawWorldPosition("player")
        if py then
          local dy = KnownGroundDy() or 0
          local tt = ((py + dy + AIM_PLANE_HEIGHT_CM) - oy) / fy
          if tt > 0 and tt <= MAX_RAY_CM then lp, lm = { ox + fx * tt, py + dy, oz + fz * tt }, "ray" end
        end
      end
      if lp then
        local dd = math.sqrt((pos[1] - lp[1]) ^ 2 + (pos[3] - lp[3]) ^ 2)
        -- 交点が最後の線の位置より「手前」(自分寄り)にある時だけ捨てる。
        -- 奥にある時は、線が高台の縁などを越えて下へ続いている可能性があるので、交点を使う。
        local hl2 = fx * fx + fz * fz
        local tTri = hl2 > 0.0001 and ((pos[1] - ox) * fx + (pos[3] - oz) * fz) / hl2 or 0
        local tLr = hl2 > 0.0001 and ((lp[1] - ox) * fx + (lp[3] - oz) * fz) / hl2 or 0
        -- 水平面との交点(ray)は、遠いほど少しの高低差で前後に大きくずれるので、12m以内の時だけ比べる相手にする
        local lrFar = false
        if lm == "ray" then
          local okp, _, ppx, _, ppz = pcall(GetUnitRawWorldPosition, "player")
          if okp and ppx then
            lrFar = (lp[1] - ppx) ^ 2 + (lp[3] - ppz) ^ 2 > PSM.TRI_RAY_COMPARE_MAX_CM ^ 2
          end
        end
        if lrFar and PSM.logEnabled and dd > PSM.TRI_LASTRAY_CONFLICT_CM and tTri < tLr then
          d(string.format("[Sul-Xan's marker] tri kept: last ray (ray) is too far to compare (%dm nearer)", zo_floor(dd / 100)))
        end
        if dd > PSM.TRI_LASTRAY_CONFLICT_CM and tTri < tLr and not lrFar then
          if PSM.logEnabled then
            d(string.format("[Sul-Xan's marker] tri rejected: %dm nearer than last ray (%s) tri=%d,%d,%d lastray=%d,%d,%d",
              zo_floor(dd / 100), lm, pos[1], pos[2], pos[3], lp[1], lp[2], lp[3]))
          end
          -- 確認用: 捨てた交点を覚えておき、拾った時に「交点を使っていたら何mずれたか」をログに出す
          if PSM.rejectedTris then
            PSM.rejectedTris[#PSM.rejectedTris + 1] = { tri = { pos[1], pos[2], pos[3] }, lr = { lp[1], lp[2], lp[3] }, method = lm, name = name }
          end
          pos, info, quality = nil, string.format("tri-conflict(%s,%d)", lm, zo_floor(dd)), nil
        end
      end
    end
  end
  if pos or not PSM.abc.C then return pos, info, quality end
  local reason = tostring(info):match("^([%a%-]+)")
  if not LASTRAY_REASONS[reason] then return pos, info, quality end
  local e = name and rays[name]
  if not e then return pos, info, quality end
  local seg, isDead, cands, matchMethod, unitIdAgeMs = ChooseSegment(e, deathTime, deathUnitId)
  if not seg or #seg.list == 0 then return pos, info, quality end
  -- とどめの時刻以前の最後の線
  local r
  for k = #seg.list, 1, -1 do
    if not deathTime or seg.list[k][1] <= deathTime + DROP_DELAY_MS then r = seg.list[k]; break end
  end
  if not r then return pos, info, quality end
  -- E: 最後の線が古い(その後に敵が動いた可能性がある)時は使わない
  local rayAge = deathTime and (deathTime - r[1]) or 0
  if PSM.def.E and rayAge > LASTRAY_MAX_AGE_MS then return pos, info .. "/stale-ray(" .. zo_floor(rayAge) .. ")", quality end
  local ox, oy, oz, fx, fy, fz = r[2], r[3], r[4], r[5], r[6], r[7]
  local cr, status = HmRayScan(ox, oy, oz, fx, fy, fz)
  local p, method, alts
  if #cr > 0 then
    p = { cr[1][1], cr[1][2], cr[1][3] }
    method = (status == "ground" and "hm") or (status == "graze" and "amb") or "hmo"
    if status == "graze" and #cr > 1 then
      alts = {}
      for k = 2, #cr do alts[#alts + 1] = { cr[k][1], cr[k][2], cr[k][3] } end
    end
  elseif fy < -0.01 then
    local _, _, py = GetUnitRawWorldPosition("player")
    if py then
      local dy = KnownGroundDy() or 0
      local tt = ((py + dy + AIM_PLANE_HEIGHT_CM) - oy) / fy
      if tt > 0 and tt <= MAX_RAY_CM then p, method = { ox + fx * tt, py + dy, oz + fz * tt }, "ray" end
    end
  end
  -- F/F2: 地図で地面が確定しない時、照準線の近くに立っている仲間(近接で敵の近くにいる)を手がかりにする
  if PSM.def.F and method ~= "hm" then
    local gp, gm = GroupRayPick(ox, oy, oz, fx, fy, fz, cr, p)
    if gp then p, method, alts = gp, gm, nil end
  end
  -- D: 地図で地面が確定した時(hm)と、グループメンバーで決めた時(grp)だけ使う
  if PSM.def.D and p and method ~= "hm" and method ~= "grp" and method ~= "grp+hm" then p = nil end
  -- D2: 地図と交わらない(水平面で求めた)位置だけ使わない
  if PSM.def.D2 and p and method == "ray" then p = nil end
  if not p then return pos, info, quality end
  return p, string.format("lastray(%s)[%s,%s/%d]", method, reason, tostring(matchMethod), cands), {
    uncertain = true, isDead = isDead, matchMethod = matchMethod, unitIdAgeMs = unitIdAgeMs,
    lastRay = true, alts = alts, trimmed = 0, lastOff = 0, seg = seg,
  }
end


-- ----------------------------------------------------------------------------
-- G: 照準していない敵(自分の範囲攻撃だけが当たって倒れた敵)の位置
-- その敵に当てた瞬間に照準していた敵の位置(=範囲攻撃の中心付近)を、おおよその位置として使う。
-- ----------------------------------------------------------------------------
PSM.aoeHits = PSM.aoeHits or {}
PSM.aimAbilityHits = PSM.aimAbilityHits or {}
local AOE_HIT_KEEP_MS = 4000

-- 1本の照準線から位置を求める(地図 → グループメンバー(F/F2) → 水平面 の順)
local function RayPos(r)
  local ox, oy, oz, fx, fy, fz = r[2], r[3], r[4], r[5], r[6], r[7]
  local cr, status = HmRayScan(ox, oy, oz, fx, fy, fz)
  local p, method
  if #cr > 0 then
    p = { cr[1][1], cr[1][2], cr[1][3] }
    method = (status == "ground" and "hm") or (status == "graze" and "amb") or "hmo"
  elseif fy < -0.01 then
    local _, _, py = GetUnitRawWorldPosition("player")
    if py then
      local dy = KnownGroundDy() or 0
      local tt = ((py + dy + AIM_PLANE_HEIGHT_CM) - oy) / fy
      if tt > 0 and tt <= MAX_RAY_CM then p, method = { ox + fx * tt, py + dy, oz + fz * tt }, "ray" end
    end
  end
  if (PSM.def.F or PSM.def.F2) and method ~= "hm" then
    local gp, gm = GroupRayPick(ox, oy, oz, fx, fy, fz, cr, p)
    if gp then p, method = gp, gm end
  end
  return p, method
end

local AOE_SAME_HIT_MS = 1000
local function AoeEstimate(unitId)
  local h = unitId and PSM.aoeHits[unitId]
  if not h or now() - h.t > AOE_HIT_KEEP_MS or not h.aimName then return nil end
  -- 同じスキルが、ほぼ同時に照準中の敵(倒れた個体とは別の個体)にも当たっている時だけ使う。
  -- (自分中心の範囲攻撃が背後の敵だけに当たった時に、前の敵の位置を出さないため)
  local ah = h.abilityId and PSM.aimAbilityHits[h.abilityId]
  local same = false
  if ah then
    for uid, at in pairs(ah) do
      if uid ~= unitId and math.abs(at - h.t) <= AOE_SAME_HIT_MS then same = true break end
    end
  end
  if not same then
    if PSM.logEnabled then d("[Sul-Xan's marker] aoe estimate skipped: aimed target was not hit by the same skill") end
    return nil
  end
  local e = rays[h.aimName]
  if not e then return nil end
  local best
  for _, sg in ipairs(e.segs) do
    for k = sg.consumed and 0 or #sg.list, 1, -1 do
      local r = sg.list[k]
      if r[1] <= h.t + 100 then
        if not best or r[1] > best[1] then best = r end
        break
      end
    end
  end
  if not best or h.t - best[1] > 1500 then return nil end
  local p, method = RayPos(best)
  if not p then return nil end
  return p, method
end

-- ----------------------------------------------------------------------------
-- 位置候補の絞り込み(検証用。PSM.narrow.range / group / rays で個別にON)
--   range: 自分が当てたスキルの射程より遠い候補を消す
--   group: グループメンバーが近くに立っている候補が1つだけなら、それに絞る
--   rays : とどめ直前の照準線が最もよく通る候補に絞る
-- ----------------------------------------------------------------------------
PSM.narrow = PSM.narrow or { range = false, group = false, rays = true }   -- beta4: 案3(照準線の一致)を使う
local recentHits = {}   -- { 時刻, 自分のx, 自分のz, 射程(cm) }
local RANGE_KEEP_MS  = 4000
local RANGE_SLACK_CM = 300
local GROUP_NEAR_CM  = 400

local function AbilityMaxRange(abilityId)
  if not abilityId or abilityId == 0 or type(GetAbilityRange) ~= "function" then return nil end
  local r = { pcall(GetAbilityRange, abilityId) }
  if not r[1] then return nil end
  local best
  for k = 2, #r do if type(r[k]) == "number" and r[k] > 0 and (not best or r[k] > best) then best = r[k] end end
  return best
end

local function NoteHitRange(hitValue, abilityId)
  if not (hitValue and hitValue > 0) then return end
  local range = AbilityMaxRange(abilityId)
  if not range then return end
  local _, px, _, pz = GetUnitRawWorldPosition("player")
  if not px then return end
  local t = now()
  recentHits[#recentHits + 1] = { t, px, pz, range }
  while #recentHits > 0 and t - recentHits[1][1] > RANGE_KEEP_MS do table.remove(recentHits, 1) end
end
PSM.NoteHitRange = NoteHitRange

local function NarrowCandidates(pos, extras, name, chosen)
  local all = { pos }
  for _, e in ipairs(extras) do all[#all + 1] = e end
  local notes = {}

  -- 案1: 射程
  if PSM.narrow.range and #recentHits > 0 then
    local t = now()
    local keep = {}
    for _, c in ipairs(all) do
      local ok = false
      for _, h in ipairs(recentHits) do
        if t - h[1] <= RANGE_KEEP_MS and math.sqrt((c[1] - h[2]) ^ 2 + (c[3] - h[3]) ^ 2) <= h[4] + RANGE_SLACK_CM then ok = true break end
      end
      if ok then keep[#keep + 1] = c end
    end
    if #keep > 0 and #keep < #all then notes[#notes + 1] = string.format("range %d->%d", #all, #keep); all = keep end
  end

  -- 案2: グループメンバーの近く
  if PSM.narrow.group and #all > 1 and IsUnitGrouped and IsUnitGrouped("player") then
    local members = {}
    for i = 1, GetGroupSize() do
      local tag = GetGroupUnitTagByIndex(i)
      if tag and not AreUnitsEqual(tag, "player") then
        local ok, _, x, y, z = pcall(GetUnitRawWorldPosition, tag)
        if ok and x and not (x == 0 and z == 0) then members[#members + 1] = { x, y, z } end
      end
    end
    local near = {}
    for _, c in ipairs(all) do
      for _, m in ipairs(members) do
        if math.sqrt((c[1] - m[1]) ^ 2 + (c[3] - m[3]) ^ 2) <= GROUP_NEAR_CM then near[#near + 1] = c break end
      end
    end
    if #near == 1 then notes[#notes + 1] = string.format("group %d->1", #all); all = near end
  end

  -- 案3: とどめ直前の照準線との一致
  if PSM.narrow.rays and #all > 1 and name and rays[name] and chosen then
    local seg = ChooseSegment(rays[name], chosen.time, chosen.unitId)
    if seg and #seg.list >= 3 then
      local tLast = seg.list[#seg.list][1]
      local scores = {}
      for ci, c in ipairs(all) do
        local sum, n = 0, 0
        for k = #seg.list, 1, -1 do
          local r = seg.list[k]
          if tLast - r[1] > 1500 then break end
          local dx, dy, dz = c[1] - r[2], c[2] + AIM_PLANE_HEIGHT_CM - r[3], c[3] - r[4]
          local dot = dx * r[5] + dy * r[6] + dz * r[7]
          local qx, qy, qz = dx - dot * r[5], dy - dot * r[6], dz - dot * r[7]
          sum, n = sum + math.sqrt(qx * qx + qy * qy + qz * qz), n + 1
        end
        if n >= 3 then scores[#scores + 1] = { sum / n, ci } end
      end
      if #scores == #all then
        table.sort(scores, function(a, b) return a[1] < b[1] end)
        if scores[1][1] < 200 and scores[1][1] < scores[2][1] * 0.5 then
          notes[#notes + 1] = string.format("rays %d->1 (%dcm vs %dcm)", #all, zo_floor(scores[1][1]), zo_floor(scores[2][1]))
          all = { all[scores[1][2]] }
        end
      end
    end
  end

  if #notes > 0 and PSM.logEnabled then d("[Sul-Xan's marker] narrow: " .. table.concat(notes, ", ")) end
  local p = all[1]
  local rest = {}
  for k = 2, #all do rest[#rest + 1] = all[k] end
  return p, rest, #notes > 0
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

-- 魂を拾った時に消す線: 表示中の魂に使った線(使用済み)と、魂が出てから拾うまでに死亡した敵の線だけ。
-- まだ生きている敵の線は残す(拾った直後にその敵を倒しても、位置を求められるように)。
PSM.ClearUsedRays = function(interval, finish)
  local st = interval and interval.start or nil
  local fin = finish or now()
  local deadNames = {}
  for name, e in pairs(rays) do
    local keep, newest = {}, nil
    for _, sg in ipairs(e.segs or {}) do
      local drop = sg.consumed
      if not drop and st then
        if sg.deadAt and sg.deadAt >= st - DROP_DELAY_MS and sg.deadAt <= fin then drop = true end
        if not drop then
          for _, dd in ipairs(recentDeaths) do
            if dd.name == name and dd.time >= st and dd.time <= fin and dd.unitId and sg.unitIds and sg.unitIds[dd.unitId] then drop = true; break end
          end
        end
      end
      if drop then deadNames[name] = true
      elseif #sg.list > 0 then keep[#keep + 1] = sg; if not newest or sg.last > newest then newest = sg.last end end
    end
    if #keep == 0 then rays[name] = nil else e.segs = keep; e.last = newest end
  end
  if st then for _, dd in ipairs(recentDeaths) do if dd.time >= st and dd.time <= fin then deadNames[dd.name] = true end end end
  for name in pairs(deadNames) do samples[name] = nil end
  lastPos = nil
end

local hmTicks = 0
local function SampleTarget()
  hmTicks = hmTicks + 1
  if hmTicks >= 5 then   -- 約0.25秒ごとに、自分とグループメンバーの足元の高さを記録
    hmTicks = 0
    HmSample()
  end
  sampleTicks = sampleTicks + 1
  if sampleTicks >= 100 then   -- 約5秒ごと
    sampleTicks = 0
    PurgeOld()
  end

  if IsHostileTarget() then
    local x, y, z, src, alts = GetTargetPos()
    local name = ReticleName()
    if x then
      lastPos = { x, y, z, now(), src, alts }
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
PSM.FALLBACK_CIRCLE_SCALE = 0.8   -- 赤い丸の大きさ(矢印に対する割合)
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

  -- 赤い丸(位置不明・プレビュー)は矢印より少し小さく(80%)。中心の位置と数字の大きさは変えない
  local iconSize = useFallbackStyle and math.floor(size * PSM.FALLBACK_CIRCLE_SCALE) or size
  ui.icon:SetDimensions(iconSize, iconSize)
  ui.icon:ClearAnchors()
  ui.icon:SetAnchor(TOP, ui.win, TOP, 0, math.floor((size - iconSize) / 2))
  -- LibCombatAlerts のテクスチャIDは、LCA.SetTexture でパスと切り出し座標に変換して設定する
  LCA.SetTexture(ui.icon, useFallbackStyle and FALLBACK_TEXTURE or ARROW_TEXTURE)
  ui.icon:SetColor(unpack(useFallbackStyle and FALLBACK_COLOR or sv.color))

  -- 残り秒数: 矢印の時は中心より少し上、赤い丸(位置不明・プレビュー)の時は丸の中央に表示する
  ui.label:ClearAnchors()
  ui.label:SetAnchor(CENTER, ui.icon, CENTER, 0, useFallbackStyle and 0 or -math.floor(size * NUM_Y))
  ui.label:SetDimensions(size, math.floor(size * 0.5))
  ui.label:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", math.max(12, zo_floor(size * 0.34))))
  -- 残り秒数の色: 赤い丸(位置不明・プレビュー)の時は白、矢印の時は黒
  if useFallbackStyle then ui.label:SetColor(1, 1, 1, 1) else ui.label:SetColor(0, 0, 0, 1) end
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

  -- 魂は同時に1つしか出ない。表示中(拾うまで)に来た追加イベントでは位置を動かさない
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
  -- 開始は、死亡イベントが遅れて届く待ち時間(DROP_DELAY_MS)の後にする。
  -- (魂のイベントの直後に届いた、この魂自身の死亡を「魂の出現中の死亡」として除外しないため)
  activeSoulInterval = { start = t + DROP_DELAY_MS, expectedFinish = t + duration }
  soulDeathIntervals[#soulDeathIntervals + 1] = activeSoulInterval
  while #soulDeathIntervals > 0 and soulDeathIntervals[1].expectedFinish < t - 5000 do
    table.remove(soulDeathIntervals, 1)
  end
  local intervalsForThisDrop = soulDeathIntervals

  -- この瞬間の照準を記録しておく(倒された敵の名前は、少し遅れて届く死亡イベントで分かる)
  local snap
  if IsHostileTarget() then
    local x, y, z, s, alts = GetTargetPos()
    -- 照準線が地面すれすれで奥行きが曖昧な時は、奥の交点も候補として持っておく(alts)
    if x then snap = { pos = { x, y, z }, name = ReticleName(), src = s, alts = alts } end
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
    PSM.rejectedTris = {}
    local pos, src = earlyPos, earlySrc
    local posAlts = nil
    local consumedSegs = {}

    -- 魂イベントが敵のUnitIdを示す場合は、時刻よりID一致を優先する。
    -- 自分自身を対象とするバフイベントのIDは敵IDとして使わない。
    local playerType = _G["COMBAT_UNIT_TYPE_PLAYER"]
    local usableSoulTargetId = soulTargetId and soulTargetId ~= sourceUnitId
      and (not playerType or targetType ~= playerType)
    local candidateDeaths = {}
    for i = #recentDeaths, 1, -1 do
      local dd = recentDeaths[i]
      if dd.time >= t - CANDIDATE_DEATH_WINDOW_MS and dd.time <= t + DROP_DELAY_MS
          and not dd.usedForSoul
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
        if dd.time >= t - DEATH_BEFORE_MS and dd.time <= t + DROP_DELAY_MS
            and not dd.usedForSoul
            and not IsDeathInsideSoulInterval(dd.time, intervalsForThisDrop) then
          chosen = dd
          chosenReason = "recent-death-time"
          break
        end
      end
    end
    if not chosen and lastDeath and not lastDeath.usedForSoul and lastDeath.time >= t - DEATH_BEFORE_MS and lastDeath.time <= t + DROP_DELAY_MS
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
      local aimedAlive = AimedStillAlive(chosen.name, chosen.time)
      if aimedAlive then
        if PSM.logEnabled then d("[Sul-Xan's marker] aimed same-name enemy is still alive; reticle position not used") end
      elseif activeTracks <= 1 and snap and snap.name == chosen.name then
        pos, src = snap.pos, "death+snap(" .. tostring(snap.src) .. ")"
        posAlts = snap.alts
      elseif activeTracks <= 1 and sample and now() - sample[4] <= CANDIDATE_DEATH_WINDOW_MS then
        pos, src = { sample[1], sample[2], sample[3] }, "death+name(" .. tostring(sample[5]) .. ")"
        posAlts = sample[6]
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
      if type(triQuality) == "table" and triQuality.alts then posAlts = triQuality.alts end
    elseif PSM.logEnabled then
      d("[Sul-Xan's marker] triangulation skipped: " .. tostring(triInfo))
    end
    local ambiguousTrack = triInfo == "ambiguous-segments"

    -- 位置が不確かかどうか: 三角測量が使えなかった / 同名の敵が同時に複数倒れた
    local sameNameDeaths, idMatch, otherDeaths = 0, matchedDeath ~= nil, 0
    for _, dd in ipairs(recentDeaths) do
      if dd.time >= t - DEATH_BEFORE_MS and dd.time <= t + DROP_DELAY_MS
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
        -- 平地などの仮定の地面で答えが大きく動いた時は、位置が仮定頼みなので不確か
        or (triQuality.groundMode == "assumed" and (tonumber(triQuality.groundShift) or 0) > GROUND_SHIFT_WARN_CM)
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
        if not ep and einfo ~= "ambiguous-segments" and uniqueNameTrack and snap and snap.name == dd.name
            and not AimedStillAlive(dd.name, dd.time) then
          ep, positionMethod = snap.pos, "snap"
        end
        if not ep then
          local sample = samples[dd.name]
          if einfo ~= "ambiguous-segments" and uniqueNameTrack and sample and now() - sample[4] <= CANDIDATE_DEATH_WINDOW_MS
              and not AimedStillAlive(dd.name, dd.time) then
            ep = { sample[1], sample[2], sample[3] }
            positionMethod = "sample(" .. tostring(sample[5]) .. ")"
          end
        end
        if not ep and PSM.def.G then
          local gp, gm = AoeEstimate(dd.unitId)
          if gp then ep, positionMethod = gp, "aoe(" .. tostring(gm) .. ")" end
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
            if type(quality) == "table" and quality.seg then consumedSegs[#consumedSegs + 1] = quality.seg end
            dd.usedForSoul = true
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
          if dd.time >= t - DEATH_BEFORE_MS and dd.time <= t + DROP_DELAY_MS
              and not IsDeathInsideSoulInterval(dd.time, intervalsForThisDrop) then
            if dd.name == targetName then sameNameDeaths = sameNameDeaths + 1
            else otherDeaths = otherDeaths + 1 end
          end
        end
      end
      uncertain = true
      if not pos then
        -- 候補位置を1つも計算できない時も、位置不明(赤い丸)で表示する(下の共通処理へ)
        if PSM.logEnabled then d(L("[Sul-Xan's marker] 候補位置を計算できないため位置不明(赤い丸)で表示します", "[Sul-Xan's marker] No candidate positions could be calculated; showing the no-position marker")) end
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
      local lpx, py, lpz = ReadPos("player")
      if py then
        PSM.groundDy = math.max(-GROUND_DY_LIMIT_CM, math.min(GROUND_DY_LIMIT_CM, triPos[2] - py))
        PSM.groundDyTime = now()
        PSM.groundDyPos = { lpx, py, lpz }
      end
    end

    -- 三角測量できず、水平面との交点(推測)が遠すぎる時は、表示しない
    local tooFar = false
    if pos and (not triPos or (type(triQuality) == "table" and triQuality.lastRay)) then
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
    -- 照準線が地面すれすれで曖昧な時は、奥の交点も小さい候補として出す
    if pos and posAlts and #posAlts > 0 and tostring(src):find("(amb)", 1, true) then
      local apx, _, apz = ReadPos("player")
      for _, a in ipairs(posAlts) do
        local far = apx and math.sqrt((a[1] - apx) ^ 2 + (a[3] - apz) ^ 2) > (PSM.sv.maxShowDist or 36) * 100
        if not far and math.sqrt((a[1] - pos[1]) ^ 2 + (a[3] - pos[3]) ^ 2) >= 300 then
          extras[#extras + 1] = a
          if PSM.logEnabled then
            d(string.format("[Sul-Xan's marker] graze candidate: (%d,%d,%d)", a[1], a[2], a[3]))
          end
        end
      end
      uncertain = true
    end
    -- 地面の高さを仮定して求めた位置は、遠いほど・視線が水平に近いほど、高低差の見積もり違いで大きくずれる。
    -- 水平方向の誤差の見積もり = 距離 × 高さの不確かさ ÷ (カメラと敵の胸の高さの差)
    if pos and not tooFar then
      local groundDependent = true
      if triPos and pos == triPos and tostring(src):find("gnd=off", 1, true) then groundDependent = false end
      if groundDependent then
        local okC, _, coy = pcall(GetCameraRay)
        local ppx, _, ppz = ReadPos("player")
        if okC and coy and ppx then
          local D = math.sqrt((pos[1] - ppx) ^ 2 + (pos[3] - ppz) ^ 2)
          local H = math.max(coy - (pos[2] + AIM_PLANE_HEIGHT_CM), 100)
          local unc = KnownGroundDy() and HEIGHT_UNC_KNOWN_CM or HEIGHT_UNC_FLAT_CM
          -- 地面の高さの地図と交差させて求めた位置は不確かさを小さく、
          -- 照準線が地面すれすれで奥行きが曖昧な位置は大きくする
          local ssrc = tostring(src)
          local isAmb = ssrc:find("(amb)", 1, true) ~= nil
          if isAmb then
            unc = HEIGHT_UNC_AMB_CM
          elseif ssrc:find("(hmo)", 1, true) then
            unc = HEIGHT_UNC_FLAT_CM
          elseif ssrc:find("(hm)", 1, true) or ssrc:find("gnd=hm", 1, true) then
            unc = HEIGHT_UNC_HM_CM
          end
          local herr = D * unc / H
          if PSM.logEnabled then
            d(string.format("[Sul-Xan's marker] height-risk: dist=%dm camH=%dcm err~%dm", zo_floor(D / 100), zo_floor(H), zo_floor(herr / 100)))
          end
          -- 曖昧(amb)な時は候補をすべて出しているので、消さずに「不確か」にする
          if herr > HEIGHT_ERR_HIDE_CM and not isAmb then
            pos = nil
            tooFar = true
            if PSM.logEnabled then
              d(L("[Sul-Xan's marker] 高低差の不確かさによる誤差が大きすぎるため表示しません", "[Sul-Xan's marker] Not shown: height uncertainty makes the estimate too unreliable"))
            end
          elseif herr > HEIGHT_ERR_WARN_CM or isAmb then
            uncertain = true
          end
        end
      end
    end
    -- G: 照準していない敵(範囲攻撃で倒れた敵)は、当てた時に照準していた敵の位置を使う
    if not pos and PSM.def.G and chosen and chosen.unitId then
      local gp, gm = AoeEstimate(chosen.unitId)
      if gp then
        pos, src, uncertain = gp, "death+aoe(" .. tostring(gm) .. ")", true
        ambiguousTrack = false
      end
    end
    if not pos and #extras > 0 then
      pos = table.remove(extras, 1)
      uncertain = true
    end
    -- 位置が決められない時(個体追跡が曖昧・遠すぎる・高低差で誤差が大きい)は、
    -- 地面のマーカーは出さず、画面上の赤い丸(位置不明)を出す
    if not pos and ambiguousTrack and PSM.logEnabled then
      d(L("[Sul-Xan's marker] 個体追跡が曖昧なため位置不明(赤い丸)で表示します", "[Sul-Xan's marker] Target tracking is ambiguous; showing the no-position marker"))
    end
    if not pos and tooFar and PSM.logEnabled then
      d(L("[Sul-Xan's marker] 推測位置が使えないため位置不明(赤い丸)で表示します", "[Sul-Xan's marker] Estimate unusable; showing the no-position marker"))
    end
    if not pos and PSM.sv.hideWhenNoPos then
      PSM.lastDrop = nil
      if PSM.logEnabled then d(L("[Sul-Xan's marker] 位置が取れないので表示しません(設定)", "[Sul-Xan's marker] No position available; not shown (setting)")) end
      return
    end

    -- 位置に使った線の区間は「使用済み」にして、次の魂の推定に残さない
    if pos and type(triQuality) == "table" and triQuality.seg and pos == triPos then triQuality.seg.consumed = true end
    for _, cs in ipairs(consumedSegs) do cs.consumed = true end
    -- 前の魂に使った死亡は、次の魂の候補にしない
    if chosen then chosen.usedForSoul = true end
    if chosen and lastDeath and lastDeath.time == chosen.time and lastDeath.name == chosen.name then lastDeath.usedForSoul = true end
    -- 候補が複数ある時の絞り込み(検証用)
    if pos and #extras > 0 then
      local np, nx, changed = NarrowCandidates(pos, extras, targetName, chosen)
      if changed then pos, extras = np, nx end
    end
    local all = {}
    if pos then all[1] = pos end
    for _, ep in ipairs(extras) do all[#all + 1] = ep end
    PSM.lastDrop = { pos = pos, all = all, src = src, uncertain = uncertain, sameNameDeaths = sameNameDeaths, name = targetName,
      rejected = PSM.rejectedTris }
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
      PSM.ClearUsedRays(activeSoulInterval, pickupTime)
    end, DROP_DELAY_MS + 100)
  else
    PSM.ClearUsedRays(activeSoulInterval, pickupTime)
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
  -- 確認用: 捨てた交点との差(交点を使っていたら、どれだけずれていたか)
  if PSM.logEnabled and ld and ld.rejected and #ld.rejected > 0 and PSM.endTime > now() then
    local px, py, pz = ReadPos("player")
    if px then
      for i, rj in ipairs(ld.rejected) do
        local dt = math.sqrt((px - rj.tri[1]) ^ 2 + (pz - rj.tri[3]) ^ 2)
        local dl = math.sqrt((px - rj.lr[1]) ^ 2 + (pz - rj.lr[3]) ^ 2)
        d(string.format(L("[Sul-Xan's marker] 拾得: 捨てた交点との差 水平%dcm 高さ%+dcm / 代わりに使った最後の線(%s)との差 水平%dcm → %s (%s)",
          "[Sul-Xan's marker] Pickup: rejected tri delta horizontal %dcm height %+dcm / last ray (%s) used instead delta %dcm -> %s (%s)"),
          zo_floor(dt), zo_floor(py - rj.tri[2]), rj.method, zo_floor(dl),
          dt < dl and L("交点の方が近い", "tri was closer") or L("最後の線の方が近い", "last ray was closer"), tostring(rj.name)))
      end
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
    elseif arg:match("^hmline") then
      PSM.HmProfile(arg:match("^hmline%s+(%d+)"))
    elseif arg == "petprobe" then
      -- 調査用: ペット・コンパニオン・照準先の座標が取れるかを表示する
      -- (非戦闘ペットを照準した状態でも実行して、reticleover の結果を確認する)
      local _, px, py, pz = GetUnitRawWorldPosition("player")
      d("[Sul-Xan's marker] petprobe: 自分 " .. string.format("(%d,%d,%d)", px or 0, py or 0, pz or 0))
      local tags = { "companion", "reticleover", "reticleoverplayer", "interact" }
      for i = 1, 7 do tags[#tags + 1] = "playerpet" .. i end
      for _, tag in ipairs(tags) do
        local okE, ex = pcall(DoesUnitExist, tag)
        local okN, nm = pcall(GetUnitName, tag)
        local okP, zone, x, y, z = pcall(GetUnitRawWorldPosition, tag)
        local okW, wz, wx, wy, wzz = pcall(GetUnitWorldPosition, tag)
        local dist = (okP and x and px and not (x == 0 and z == 0)) and math.sqrt((x - px) ^ 2 + (z - pz) ^ 2) / 100 or nil
        d(string.format("  %-18s exist=%s name=%s raw=%s world=%s%s", tag, tostring(okE and ex),
          tostring(okN and nm or "-"),
          okP and string.format("(%s,%s,%s)", tostring(x), tostring(y), tostring(z)) or "err",
          okW and string.format("(%s,%s,%s)", tostring(wx), tostring(wy), tostring(wzz)) or "err",
          dist and string.format(" 距離%.1fm", dist) or ""))
      end
    elseif arg == "hm" then
      local _, px, py, pz = GetUnitRawWorldPosition("player")
      d(string.format("[Sul-Xan's marker] heightmap: zone=%s cells=%d", tostring(hm.zone), hm.count))
      if px then
        local h, direct = HmHeight(px, pz, py)
        d(string.format("  here: ground=%s (%s) player y=%d", h and tostring(zo_floor(h)) or "-", direct and "cell" or "near", py))
        local okc, ox, oy, oz, fx, fy, fz = pcall(GetCameraRay)
        if okc and ox then
          local cr, status = HmRayScan(ox, oy, oz, fx, fy, fz)
          if #cr > 0 then
            for k, c in ipairs(cr) do
              d(string.format("  aim hit %d/%d (%s): (%d,%d,%d) dist=%.1fm dy=%dcm", k, #cr, tostring(status), c[1], c[2], c[3], math.sqrt((c[1] - px) ^ 2 + (c[3] - pz) ^ 2) / 100, c[2] - py))
            end
          else
            d("  aim hit: none")
          end
        end
      end
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
      d("[Sul-Xan's marker] /sulxan test | unlock | lock | debug | probe | dump | sets | setname <name> | lang | log | hm")
    end
  end

  SLASH_COMMANDS["/sulxan"]   = OnSlashCommand
  SLASH_COMMANDS["/puyosoul"] = OnSlashCommand  -- 旧名(互換用)
end

EM:RegisterForEvent(PSM.name .. "_Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
