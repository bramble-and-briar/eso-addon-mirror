PBsKillLog = PBsKillLog or {}

local STRINGS = {
    en = {
        EXPLANATION         = "Shows only PvP player kills in a window of its own. It works even when the \"PvP Kill Feed\" setting in the social options is turned off. While this panel is open, a pink frame shows where the window will be.",

        PREVIEW             = "Show a preview here",
        PREVIEW_TIP         = "The window is only drawn on the HUD, so it cannot be seen from this menu. While this is on, a pink frame with a few sample kills is drawn where the window will be, at the text size you chose.",
        PREVIEW_CAPTION     = "PB's KillLog preview",

        UNLOCK              = "Unlock window",
        UNLOCK_TIP          = "While unlocked, the window can be dragged to move and dragged by its edges to resize. It always returns to locked after a reload.",

        SECTION_WINDOW      = "Window",
        POS_X               = "Position X",
        POS_X_TIP           = "Distance from the left edge of the screen.",
        POS_Y               = "Position Y",
        POS_Y_TIP           = "Distance from the top edge of the screen.",
        WIDTH               = "Width",
        WIDTH_TIP           = "Width of the window.",
        HEIGHT              = "Height",
        HEIGHT_TIP          = "Height of the window.",

        SECTION_TEXT        = "Text",
        FONT_SIZE           = "Font size",
        FONT_SIZE_TIP       = "Size of the kill log text. The rank icons follow it.",

        SECTION_LAYER       = "Layer",
        DRAW_TIER           = "Layer (draw tier)",
        DRAW_TIER_TIP       = "Which group the window is drawn in. Higher tiers are drawn in front of lower tiers.",
        TIER_LOW            = "Low (back)",
        TIER_MEDIUM         = "Medium",
        TIER_HIGH           = "High (front)",
        DRAW_LEVEL          = "Layer (draw level)",
        DRAW_LEVEL_TIP      = "Fine adjustment inside the same draw tier. A larger value is drawn in front.",

        SECTION_SOUND       = "Sound",
        KILL_SOUND          = "Play a sound when you get the kill",
        KILL_SOUND_TIP      = "Plays the Tales of Tribute \"agent knocked out\" sound whenever the kill in the kill feed is yours. Duplicate kill feed messages play it once.",

        SECTION_LOG         = "Log",
        TEST                = "Add a test kill",
        TEST_TIP            = "Adds a made-up kill to the log, to see how it looks.",
        CLEAR               = "Clear the log",
        CLEAR_TIP           = "Removes every line from the window.",
        BUTTON_RUN          = "Do it",

        TEST_KILLER         = "TestKiller",
        TEST_VICTIM         = "TestVictim",
        TEST_LOCATION       = "Test Keep",

        CMD_HELP            = "/pbkl unlock|lock|test|clear|reset|preview|sound [on|off]",
        CMD_UNLOCKED        = "Window unlocked.",
        CMD_NO_CURSOR       = "The window can only be unlocked where a mouse is available. Use the settings sliders instead.",
        CMD_LOCKED          = "Window locked.",
        CMD_CLEARED         = "Log cleared.",
        CMD_SOUND_ON        = "Kill sound on.",
        CMD_SOUND_OFF       = "Kill sound off.",
        CMD_PREVIEW_ON      = "Preview shown.",
        CMD_PREVIEW_OFF     = "Preview hidden.",
        CMD_RESET           = "Window settings reset.",
    },
    ja = {
        EXPLANATION         = "PvPでのプレイヤー間のキルだけを専用ウィンドウに表示します。ソーシャル設定の「PvPキルフィード」がオフでも動作します。この画面を開いている間、ウィンドウが表示される場所にピンクの枠が表示されます。",

        PREVIEW             = "ここにプレビューを表示",
        PREVIEW_TIP         = "ウィンドウはHUDにしか描かれないため、このメニューからは見えません。オンの間、ウィンドウが表示される場所に、選んだ文字サイズでサンプルのキルを入れたピンクの枠を描きます。",
        PREVIEW_CAPTION     = "PB's KillLog プレビュー",

        UNLOCK              = "ウィンドウのロックを解除",
        UNLOCK_TIP          = "解除中はドラッグで移動、縁をドラッグでサイズ変更ができます。リロードすると必ずロック状態に戻ります。",

        SECTION_WINDOW      = "ウィンドウ",
        POS_X               = "位置 X",
        POS_X_TIP           = "画面の左端からの距離です。",
        POS_Y               = "位置 Y",
        POS_Y_TIP           = "画面の上端からの距離です。",
        WIDTH               = "幅",
        WIDTH_TIP           = "ウィンドウの幅です。",
        HEIGHT              = "高さ",
        HEIGHT_TIP          = "ウィンドウの高さです。",

        SECTION_TEXT        = "文字",
        FONT_SIZE           = "フォントサイズ",
        FONT_SIZE_TIP       = "キルログの文字の大きさです。ランクアイコンも合わせて変わります。",

        SECTION_LAYER       = "レイヤー",
        DRAW_TIER           = "レイヤー（描画ティア）",
        DRAW_TIER_TIP       = "ウィンドウを描画するグループです。上位のティアは下位のティアより手前に表示されます。",
        TIER_LOW            = "低（奥）",
        TIER_MEDIUM         = "中",
        TIER_HIGH           = "高（手前）",
        DRAW_LEVEL          = "レイヤー（描画レベル）",
        DRAW_LEVEL_TIP      = "同じ描画ティア内での微調整です。値が大きいほど手前に表示されます。",

        SECTION_SOUND       = "サウンド",
        KILL_SOUND          = "自分がキルした時に効果音を鳴らす",
        KILL_SOUND_TIP      = "キルフィードのキルが自分のものだった時に、テイルズ・オブ・トリビュートでカードを倒した（体力が0になった）時の効果音を鳴らします。同じキルの重複通知では1回だけ鳴ります。",

        SECTION_LOG         = "ログ",
        TEST                = "テストキルを追加",
        TEST_TIP            = "見た目を確認するために、架空のキルをログに追加します。",
        CLEAR               = "ログを消去",
        CLEAR_TIP           = "ウィンドウの表示をすべて消します。",
        BUTTON_RUN          = "実行",

        TEST_KILLER         = "テスト撃破者",
        TEST_VICTIM         = "テスト被撃破者",
        TEST_LOCATION       = "テスト砦",

        CMD_HELP            = "/pbkl unlock|lock|test|clear|reset|preview|sound [on|off]",
        CMD_UNLOCKED        = "ウィンドウのロックを解除しました。",
        CMD_NO_CURSOR       = "ロック解除はマウスが使える環境でのみ可能です。設定のスライダーを使ってください。",
        CMD_LOCKED          = "ウィンドウをロックしました。",
        CMD_CLEARED         = "ログを消去しました。",
        CMD_SOUND_ON        = "キル効果音をオンにしました。",
        CMD_SOUND_OFF       = "キル効果音をオフにしました。",
        CMD_PREVIEW_ON      = "プレビューを表示しました。",
        CMD_PREVIEW_OFF     = "プレビューを隠しました。",
        CMD_RESET           = "ウィンドウ設定をリセットしました。",
    },
}

-- The client reports Japanese as "jp" (the name of its lang folder); some tools say "ja". Both are
-- Japanese here. Any other language falls back to English.
local code = GetCVar("language.2")
local language = (code == "jp" or code == "ja") and "ja" or code
local strings = STRINGS[language] or STRINGS.en

-- Falls back to English, then to the key itself, so a missing translation never errors.
function PBsKillLog.L(key)
    return strings[key] or STRINGS.en[key] or key
end
