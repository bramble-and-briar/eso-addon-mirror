-- 日本語。マニフェストの lang/$(language).lua で、日本語クライアントのときだけ読み込まれ、
-- lang/strings.lua の同じIDを上書きします。クライアントの言語コードは "ja" ではなく "jp" です
-- （クライアント本体の言語ファイルも jp_client.lua）。1.1.0 まではここを "ja" と比較して
-- いたため、日本語クライアントでも英語のまま表示されていました。
local strings = {
    SI_PBSSMS_SCENE_FAILED = "スクリーンショットモードを開始できませんでした: %s",
    SI_PBSSMS_BOTH_FAILED = "UIを非表示にできませんでした: %s",
    SI_PBSSMS_FELL_BACK = "代わりにUIを非表示にします: %s",
    SI_PBSSMS_TURNED_ON = "有効にしました。L2を押したまま十字キー左を押してください。",
    SI_PBSSMS_TURNED_OFF = "無効にしました。",
    SI_PBSSMS_MODE_SET = "動作モード: %s",
    SI_PBSSMS_ERROR_MODE = "/pbshot mode auto、scene、gui のいずれかを指定してください。",
    SI_PBSSMS_RESET = "設定を初期化しました。",
    SI_PBSSMS_ERROR_UNKNOWN = "不明なコマンド: %s。/pbshot help を参照してください。",
    SI_PBSSMS_HELP_HEADER = "ゲームパッドで通常画面のL2を押したまま十字キー左を押してください。",
    SI_PBSSMS_HELP_STATUS = "/pbshot status — 動作状態を表示",
    SI_PBSSMS_HELP_NOW = "/pbshot now — 動作確認（UI非表示中は復帰）",
    SI_PBSSMS_HELP_MODE = "/pbshot mode auto|scene|gui — 動作モードを選択",
    SI_PBSSMS_HELP_BINDS = "/pbshot binds — ボタン割り当てを確認",
    SI_PBSSMS_HELP_MASTER = "/pbshot on|off — 有効／無効",
    SI_PBSSMS_HELP_RESET = "/pbshot reset — 設定を初期化",
    SI_PBSSMS_HELP_QUICK = "/pbshot quick on|off — クイックショットモード",
    SI_PBSSMS_HELP_HOLD = "/pbshot hold 1|3|5|10 — UIを隠す秒数",

    SI_PBSSMS_QUICK_ON = "クイックショットモードを有効にしました。同時押しでUIを数秒間隠し、自動で戻します。その間に本体のキャプチャーボタンで撮影してください。",
    SI_PBSSMS_QUICK_OFF = "クイックショットモードを無効にしました。同時押しでスクリーンショットモードを開きます。",
    SI_PBSSMS_HOLD_SET = "UIを隠す時間を%g秒にしました。",
    SI_PBSSMS_ERROR_HOLD = "/pbshot hold 1、3、5、10 のいずれかを指定してください。",
    SI_PBSSMS_ERROR_ON_OR_OFF = "on または off を指定してください。",

    -- ---- 設定パネル --------------------------------------------------------------------
    SI_PBSSMS_EXPLANATION = "ゲームパッドの通常画面でL2を押したまま十字キー左を押します。通常はESO標準のスクリーンショットモードが開き、UIが消えてカメラ操作ができます。クイックショットモードはその代わりに、UIを数秒間だけ隠して自動で戻します。今やっていることを中断しません。撮影は本体のキャプチャーボタンで行ってください。クライアントの撮影機能はアドオンからは使えません。",
    SI_PBSSMS_SECTION_SHORTCUT = "ショートカット",
    SI_PBSSMS_SECTION_QUICK = "クイックショットモード",
    SI_PBSSMS_ENABLED = "ショートカットを有効にする",
    SI_PBSSMS_ENABLED_TOOLTIP = "オフにすると入力を監視せず、十字キー左には一切触れません。",
    SI_PBSSMS_MODE = "同時押しで開くもの",
    SI_PBSSMS_MODE_TOOLTIP = "「スクリーンショットモード」はESO標準の機能です。「UI非表示」は標準モードが開けない場合の代替で、もう一度同時押しするまでUIを隠したままにします。クイックショットモードが有効な間は参照しません。",
    SI_PBSSMS_MODE_AUTO = "標準モード、失敗時はUI非表示",
    SI_PBSSMS_MODE_SCENE = "標準モードのみ",
    SI_PBSSMS_MODE_GUI = "UI非表示のみ",
    SI_PBSSMS_QUICK = "クイックショットモードを使う",
    SI_PBSSMS_QUICK_TOOLTIP = "有効にすると、同時押しでスクリーンショットモードを開く代わりに、UIを数秒間隠して自動で戻します。隠れている間に本体のキャプチャーボタンで撮影してください。",
    SI_PBSSMS_HOLD = "UIを隠す時間",
    SI_PBSSMS_HOLD_TOOLTIP = "UIを隠しておく時間です。この間に本体のキャプチャーボタンを押します。もう一度同時押しするか、通常画面から離れた場合は、待たずに戻ります。",
    SI_PBSSMS_HOLD_ITEM = "%g秒",
    SI_PBSSMS_RUN_NOW = "今すぐ試す",
    SI_PBSSMS_RUN_NOW_TOOLTIP = "同時押しと同じ動作をします。通常画面でないと何も起きないので、パネルを閉じてから確認してください。",
    SI_PBSSMS_RUN_NOW_BUTTON = "実行",
    SI_PBSSMS_RESET_ROW = "設定を初期化",
    SI_PBSSMS_RESET_ROW_TOOLTIP = "すべての設定を初期値に戻します。",
    SI_PBSSMS_RESET_BUTTON = "初期化",
}
for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
