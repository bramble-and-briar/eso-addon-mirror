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
      name = T("推測位置を表示する最大距離 (m)", "Max distance for guessed positions (m)"),
      tooltip = T("線の交点が求まらず、地面との交点で推測した位置は、これより遠いと表示しません。標準 36。", "When the position could not be triangulated and is only guessed from the ground plane, it is not shown if farther than this. Default 36."),
      min = 10, max = 80, step = 1,
      getFunc = function() return sv.maxShowDist or 36 end,
      setFunc = function(v) sv.maxShowDist = v end,
      default = df.maxShowDist,
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
      name = T("アイコンを上下に動かす", "Bob the icon up and down"),
      getFunc = function() return sv.bob end,
      setFunc = function(v) sv.bob = v end,
      default = df.bob,
    },
    {
      type = "slider",
      name = T("魂の位置が取れない時の画面表示のサイズ", "On-screen display size when the soul position is unavailable"),
      tooltip = T("魂の位置が取れない時の画面表示と、残り時間の表示に使います。", "Used for the on-screen display when no soul position is available."),
      min = 32, max = 256, step = 4,
      getFunc = function() return sv.size2D end,
      setFunc = function(v) sv.size2D = v; PSM.ApplyLayout() end,
      default = df.size2D,
    },
    {
      type = "checkbox",
      name = T("魂の位置が取れない時の画面表示の位置を移動する（ドラッグ）", "Move the on-screen display when the soul position is unavailable (drag)"),
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
