-- Sul-Xan's marker: 設定メニュー (LibAddonMenu-2.0 が入っている場合のみ)
local PSM = SulXansMarker

function PSM.CreateSettings()
  local LAM = LibAddonMenu2
  if not LAM then return end

  local sv = PSM.sv
  local df = PSM.defaults

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
      text = "Sul-Xan's Torment の魂がドロップした位置に ↓ を表示します。魂を拾う、または時間切れで消えます。",
    },
    {
      type = "checkbox",
      name = "有効",
      getFunc = function() return sv.enabled end,
      setFunc = function(v) sv.enabled = v; if not v then PSM.Hide() end end,
      default = df.enabled,
    },
    {
      type = "checkbox",
      name = "魂の位置(ワールド)に表示",
      tooltip = "OFF、または位置が取れない場合は、画面上に ↓ を表示します。",
      getFunc = function() return sv.use3D end,
      setFunc = function(v) sv.use3D = v end,
      default = df.use3D,
    },
    {
      type = "slider",
      name = "ワールド表示のサイズ (cm)",
      min = 50, max = 500, step = 10,
      getFunc = function() return sv.size3D end,
      setFunc = function(v) sv.size3D = v end,
      default = df.size3D,
    },
    {
      type = "slider",
      name = "ワールド表示の高さ (cm)",
      min = 0, max = 600, step = 10,
      getFunc = function() return sv.height end,
      setFunc = function(v) sv.height = v end,
      default = df.height,
    },
    {
      type = "colorpicker",
      name = "アイコンの色",
      getFunc = function() return unpack(sv.color) end,
      setFunc = function(r, g, b, a) sv.color = { r, g, b, a }; PSM.ApplyLayout() end,
      default = { r = df.color[1], g = df.color[2], b = df.color[3], a = df.color[4] },
    },
    {
      type = "checkbox",
      name = "位置が不確かな時は色を変える (オレンジ)",
      tooltip = "同名の敵が同時に複数倒れた時や、ほとんど動かずに倒して位置を正確に求められなかった時は、矢印がオレンジになります。",
      getFunc = function() return sv.markUncertain end,
      setFunc = function(v) sv.markUncertain = v end,
      default = df.markUncertain,
    },
    {
      type = "checkbox",
      name = "アイコンを上下に動かす",
      getFunc = function() return sv.bob end,
      setFunc = function(v) sv.bob = v end,
      default = df.bob,
    },
    {
      type = "checkbox",
      name = "魂を拾ったらすぐ消す",
      getFunc = function() return sv.hideOnPickup end,
      setFunc = function(v) sv.hideOnPickup = v end,
      default = df.hideOnPickup,
    },
    {
      type = "checkbox",
      name = "矢印の中に残り秒数を表示",
      tooltip = "魂を拾える残り秒数を、矢印の中に整数で表示します。",
      getFunc = function() return sv.showCountdown end,
      setFunc = function(v) sv.showCountdown = v end,
      default = df.showCountdown,
    },
    {
      type = "slider",
      name = "画面表示のサイズ",
      tooltip = "魂の位置が取れない時の画面表示と、残り時間の表示に使います。",
      min = 32, max = 256, step = 4,
      getFunc = function() return sv.size2D end,
      setFunc = function(v) sv.size2D = v; PSM.ApplyLayout() end,
      default = df.size2D,
    },
    {
      type = "checkbox",
      name = "画面表示の位置を移動する (ドラッグ)",
      tooltip = "ONの間は画面表示が常時出ます。ドラッグして好きな位置へ。",
      getFunc = function() return PSM.unlocked end,
      setFunc = function(v) PSM.SetUnlocked(v) end,
      default = false,
    },
    {
      type = "button",
      name = "表示テスト (8秒)",
      tooltip = "敵を照準していればその位置、なければ自分の頭上に表示します。",
      func = function() PSM.Test() end,
    },
    {
      type = "button",
      name = "画面表示の位置をリセット",
      func = function()
        sv.offsetX = df.offsetX
        sv.offsetY = df.offsetY
        PSM.ApplyLayout()
      end,
    },
  })
end
