-- Sul-Xan's marker: 設定メニュー (LibAddonMenu-2.0 が入っている場合のみ)
local PSM = SulXansMarker

function PSM.CreateSettings()
  local LAM = LibAddonMenu2
  if not LAM then return end

  local sv = PSM.sv
  local df = PSM.defaults

  -- 日本語クライアントなら日本語、それ以外は英語
  local isJa = PSM.IsJa()
  local function T(ja, en) if isJa then return ja end return en end

  LAM:RegisterAddonPanel(PSM.name .. "_Panel", {
    type = "panel",
    name = "Sul-Xan's marker",
    displayName = "Sul-Xan's marker",
    author = "PUYO",
    version = PSM.version,
    registerForRefresh = true,
  })

  LAM:RegisterOptionControls(PSM.name .. "_Panel", {
    {
      type = "description",
      text = T("Sul-Xan's Torment の魂がドロップした位置に ↓ を表示します。魂を拾う、または時間切れで消えます。", "Shows a ↓ where a Sul-Xan's Torment soul drops. It disappears when you pick the soul up or when it times out."),
    },
    {
      type = "checkbox",
      name = T("有効", "Enabled"),
      getFunc = function() return sv.enabled end,
      setFunc = function(v) sv.enabled = v; if not v then PSM.Hide() end end,
      default = df.enabled,
    },
    {
      type = "checkbox",
      name = T("魂の位置(ワールド)に表示", "Show at the soul's position (in the world)"),
      tooltip = T("OFF、または位置が取れない場合は、画面上に ↓ を表示します。", "When OFF, or when no position is available, a ↓ is shown on screen instead."),
      getFunc = function() return sv.use3D end,
      setFunc = function(v) sv.use3D = v end,
      default = df.use3D,
    },
    {
      type = "slider",
      name = T("ワールド表示のサイズ (cm)", "World marker size (cm)"),
      min = 50, max = 500, step = 10,
      getFunc = function() return sv.size3D end,
      setFunc = function(v) sv.size3D = v end,
      default = df.size3D,
    },
    {
      type = "slider",
      name = T("ワールド表示の高さ (cm)", "World marker height (cm)"),
      min = 0, max = 600, step = 10,
      getFunc = function() return sv.height end,
      setFunc = function(v) sv.height = v end,
      default = df.height,
    },
    {
      type = "colorpicker",
      name = T("アイコンの色", "Icon color"),
      getFunc = function() return unpack(sv.color) end,
      setFunc = function(r, g, b, a) sv.color = { r, g, b, a }; PSM.ApplyLayout() end,
      default = { r = df.color[1], g = df.color[2], b = df.color[3], a = df.color[4] },
    },
    {
      type = "checkbox",
      name = T("位置が不確かな時は色を変える (オレンジ)", "Change color when position is uncertain (orange)"),
      tooltip = T("同名の敵が同時に複数倒れた時や、ほとんど動かずに倒して位置を正確に求められなかった時は、矢印がオレンジになります。", "The arrow turns orange when several enemies of the same name died together, or when the position could not be determined accurately (e.g. you barely moved)."),
      getFunc = function() return sv.markUncertain end,
      setFunc = function(v) sv.markUncertain = v end,
      default = df.markUncertain,
    },
    {
      type = "slider",
      name = T("新しい照準線の重視度 (減衰時間 秒)", "Weight of newest aim lines (decay time, s)"),
      tooltip = T("小さいほど、死亡直前の線だけを重く見ます(動く敵向き)。大きいほど、古い線も同じくらい使います(止まっている敵向き)。標準 1.5。", "Smaller: only the newest lines count (good for moving enemies). Larger: older lines count almost as much (good for standing enemies). Default 1.5."),
      min = 0.5, max = 4, step = 0.1, decimals = 1,
      getFunc = function() return sv.weightTau or 1.5 end,
      setFunc = function(v) sv.weightTau = v end,
      default = df.weightTau,
    },
    {
      type = "slider",
      name = T("敵が止まっている時に使う線の長さ (秒)", "Line history used when the enemy stands still (s)"),
      tooltip = T("線の食い違いが小さい(敵が動いていない)時だけ、通常の4秒より長い範囲の線も使います。4 にすると使いません。標準 4(使わない)。実験的な機能です。", "When the aim lines agree well (enemy is not moving), lines older than the normal 4 s are also used, up to this length. 4 = off. Default 4 (off). Experimental."),
      min = 4, max = 8, step = 0.5, decimals = 1,
      getFunc = function() return sv.extWindow or 4 end,
      setFunc = function(v) sv.extWindow = v end,
      default = df.extWindow,
    },
    {
      type = "slider",
      name = T("推測位置を表示する最大距離 (m)", "Max distance for guessed positions (m)"),
      tooltip = T("線の交点が求まらず、地面との交点で推測した位置は、これより遠いと表示しません。標準 36。", "When the position could not be triangulated and is only guessed from the ground plane, it is not shown if farther than this. Default 36."),
      min = 10, max = 80, step = 1,
      getFunc = function() return sv.maxShowDist or 36 end,
      setFunc = function(v) sv.maxShowDist = v end,
      default = df.maxShowDist,
    },
    {
      type = "checkbox",
      name = T("地面の高さを位置の推定に使う", "Use ground height in position estimate"),
      tooltip = T("線がほぼ平行で奥行きが決まらない時に、地面の高さを補助にして、位置が遠くへずれるのを抑えます。坂や段差でずれる場合はOFFにしてください。", "Uses the ground height as a weak extra constraint so the estimate does not fly far away when aim lines are nearly parallel. Turn OFF if it misbehaves on slopes or ledges."),
      getFunc = function() return sv.useGround ~= false end,
      setFunc = function(v) sv.useGround = v end,
      default = df.useGround,
    },
    {
      type = "checkbox",
      name = T("位置が全く取れない時は表示しない", "Hide when no position is available"),
      tooltip = T("OFF(標準): 位置が取れない時は、画面上に ↓ と残り秒数を表示します。\nON: 何も表示しません。", "OFF (default): when no position is available, a ↓ with the countdown is shown on screen.\nON: nothing is shown."),
      getFunc = function() return sv.hideWhenNoPos end,
      setFunc = function(v) sv.hideWhenNoPos = v end,
      default = df.hideWhenNoPos,
    },
    {
      type = "checkbox",
      name = T("不確かな時、他の候補の矢印も表示", "Also show other candidate arrows when uncertain"),
      tooltip = T("OFF(標準): 矢印は常に1つだけ表示します。\nON: 種類の違う敵が同時に倒れた時、他の敵の位置にもオレンジの矢印を追加で表示します。", "OFF (default): only one arrow is shown.\nON: when different enemy types die at the same time, extra orange arrows are shown at the other positions."),
      getFunc = function() return sv.showCandidates end,
      setFunc = function(v) sv.showCandidates = v end,
      default = df.showCandidates,
    },
    {
      type = "checkbox",
      name = T("アイコンを上下に動かす", "Bob the icon up and down"),
      getFunc = function() return sv.bob end,
      setFunc = function(v) sv.bob = v end,
      default = df.bob,
    },
    {
      type = "checkbox",
      name = T("魂を拾ったらすぐ消す", "Hide immediately when the soul is picked up"),
      getFunc = function() return sv.hideOnPickup end,
      setFunc = function(v) sv.hideOnPickup = v end,
      default = df.hideOnPickup,
    },
    {
      type = "checkbox",
      name = T("矢印の中に残り秒数を表示", "Show remaining seconds inside the arrow"),
      tooltip = T("魂を拾える残り秒数を、矢印の中に整数で表示します。", "Shows the seconds left to pick up the soul, as a whole number inside the arrow."),
      getFunc = function() return sv.showCountdown end,
      setFunc = function(v) sv.showCountdown = v end,
      default = df.showCountdown,
    },
    {
      type = "slider",
      name = T("画面表示のサイズ", "On-screen icon size"),
      tooltip = T("魂の位置が取れない時の画面表示と、残り時間の表示に使います。", "Used for the on-screen display when no soul position is available."),
      min = 32, max = 256, step = 4,
      getFunc = function() return sv.size2D end,
      setFunc = function(v) sv.size2D = v; PSM.ApplyLayout() end,
      default = df.size2D,
    },
    {
      type = "checkbox",
      name = T("画面表示の位置を移動する (ドラッグ)", "Move the on-screen icon (drag)"),
      tooltip = T("ONの間は画面表示が常時出ます。ドラッグして好きな位置へ。", "While ON, the on-screen icon is always shown. Drag it where you like."),
      getFunc = function() return PSM.unlocked end,
      setFunc = function(v) PSM.SetUnlocked(v) end,
      default = false,
    },
    {
      type = "button",
      name = T("表示テスト (8秒)", "Display test (8 s)"),
      tooltip = T("敵を照準していればその位置、なければ自分の頭上に表示します。", "Shown at the targeted enemy if any, otherwise above yourself."),
      func = function() PSM.Test() end,
    },
    {
      type = "button",
      name = T("画面表示の位置をリセット", "Reset on-screen icon position"),
      func = function()
        sv.offsetX = df.offsetX
        sv.offsetY = df.offsetY
        PSM.ApplyLayout()
      end,
    },
  })
end
