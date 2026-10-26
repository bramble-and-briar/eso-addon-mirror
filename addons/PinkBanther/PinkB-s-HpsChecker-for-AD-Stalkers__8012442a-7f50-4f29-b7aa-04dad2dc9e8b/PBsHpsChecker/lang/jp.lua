-- 日本語。lang/strings.lua のあとに読み込まれ、同じIDを上書きします。
local strings = {
	-- 日付
	SI_PBSHPS_WEEKDAYS = "日,月,火,水,木,金,土",
	SI_PBSHPS_MONTH_FORMAT = "%d年%d月",

	-- 期間
	SI_PBSHPS_SCOPE_TODAY = "今日",
	SI_PBSHPS_SCOPE_THISMONTH = "今月",
	SI_PBSHPS_SCOPE_ALL = "全期間 (直近%d日)",

	-- 概要の行
	SI_PBSHPS_NONE = "まだ記録がありません",
	SI_PBSHPS_ROW_HEAL = "回復量  %s",
	SI_PBSHPS_ROW_HPS = "HPS  %s",
	SI_PBSHPS_ROW_FIGHTS = "戦闘  %s回   回復時間  %s",
	SI_PBSHPS_ROW_BEST = "最高HPS  %s   最大の1回復  %s",
	SI_PBSHPS_ROW_CRIT = "クリティカル率  %s",
	SI_PBSHPS_ROW_OVER = "オーバーヒール  %s  (%s)",
	SI_PBSHPS_ROW_GROUP = "パーティーへ  %s  %s  %s人",
	SI_PBSHPS_ROW_OTHER = "パーティー外へ  %s  %s  %s人",
	SI_PBSHPS_ROW_SELF = "自分へ  %s  %s",
	SI_PBSHPS_ROW_PT_SHARE = "パーティーが受けた回復のうち自分の分  %s",
	SI_PBSHPS_PT_UNKNOWN = "-",
	SI_PBSHPS_TAG_PARTY_SHARE = "[PT %s]",
	SI_PBSHPS_TAG_PARTY = "[PT]",

	-- HUDメーター
	SI_PBSHPS_HUD_HPS = "HPS  %s",
	SI_PBSHPS_HUD_RECENT = "直近%d秒  %s",
	SI_PBSHPS_HUD_ENDED = "戦闘終了",
	SI_PBSHPS_HUD_TOTAL = "回復量  %s   %s   %d人",
	SI_PBSHPS_HUD_SHARE = "パーティー %d%%  パーティー外 %d%%  自分 %d%%",
	SI_PBSHPS_HUD_PT_SHARE = "パーティーが受けた回復のうち自分の分  %s",

	-- 統計ウィンドウ
	SI_PBSHPS_WINDOW_TITLE = "PB's HPS Checker  -  %s",
	SI_PBSHPS_BLOCK_SUMMARY = "概要",
	SI_PBSHPS_BLOCK_TARGETS = "回復した相手 上位10  [PT 72%]＝自分の分",
	SI_PBSHPS_BLOCK_SKILLS = "回復スキル 上位10",
	SI_PBSHPS_BLOCK_FIGHTS = "直近10戦",

	-- 設定画面
	SI_PBSHPS_EXPLANATION = "PvPでの回復量を記録して、統計として表示します。ゲームのイベントを読み取るだけで、代わりに操作することはありません。",
	SI_PBSHPS_SECTION_STATS = "統計",
	SI_PBSHPS_STATS_BUTTON = "統計ウィンドウ",
	SI_PBSHPS_STATS_BUTTON_TIP = "統計ウィンドウを表示・非表示します。設定画面を開いている間は画面の上に重ねて出し、閉じたあとも HUD の上に残ります。",
	SI_PBSHPS_STATS_BUTTON_TEXT = "表示 / 非表示",
	SI_PBSHPS_PERIOD = "期間",
	SI_PBSHPS_PERIOD_TIP = "下の統計とウィンドウの集計範囲です。今日・今月・保存されている全期間・過去の月・過去の日から選べます。",
	SI_PBSHPS_SHOW_PSN = "ランキングの名前をPSN IDにする",
	SI_PBSHPS_SHOW_PSN_TIP = "回復した相手の名前を、PSN IDで表示します。ゲームの戦闘イベントが知らせるのはキャラクター名だけなので、PSN IDは、パーティーメンバー、照準を合わせたプレイヤー、キルフィード（倒した人と倒された人の両方の名前が出ます）から覚えます。そのどれにも当てはまらない相手は、キャラクター名のままです。オフにすると、すべてキャラクター名で表示します。",

	SI_PBSHPS_SECTION_HUD = "HPSメーター",
	SI_PBSHPS_HUD = "メーターを表示",
	SI_PBSHPS_HUD_TIP = "いまの戦闘のHPS、回復量、回復先の内訳を出す小さな枠です。最初の回復で出てきます。この設定画面を開いている間は、位置を決められるようにサンプルの数字で表示します。",
	SI_PBSHPS_HUD_SIZE = "メーターの大きさ",
	SI_PBSHPS_HUD_SIZE_TIP = "1が最小、7が最大で、4が標準です。文字の大きさが段階的に変わり、枠も合わせて広がります。コンソールが読み込み済みの文字だけを使うため、滑らかには変わらず、これ以上は大きくできません。設定画面を開いている間は、サンプルの数字で確認できます。",
	SI_PBSHPS_HUD_CUSTOM = "枠の大きさをpxで指定する",
	SI_PBSHPS_HUD_CUSTOM_TIP = "オフのときは、文字に合わせた大きさになります。オンにすると、下の幅と高さ(スライダーに出るpxの値)ちょうどの枠になり、文字がそれに収まるかは問いません。幅が足りない行は末尾が「…」で省略され、高さが足りないと下の行が枠の外にはみ出します。オンにした時点では、今の枠の大きさから始まります。",
	SI_PBSHPS_HUD_WIDTH = "枠の幅 (px)",
	SI_PBSHPS_HUD_WIDTH_TIP = "「枠の大きさをpxで指定する」がオンのときだけ使います。文字の大きさは、上の「メーターの大きさ」で決めます。",
	SI_PBSHPS_HUD_HEIGHT = "枠の高さ (px)",
	SI_PBSHPS_HUD_HEIGHT_TIP = "「枠の大きさをpxで指定する」がオンのときだけ使います。標準の文字の大きさで、5行が収まるのは200px前後です。",
	SI_PBSHPS_HUD_HOLD = "戦闘後に残す時間 (秒)",
	SI_PBSHPS_HUD_HOLD_TIP = "戦闘が終わったあと、結果を読めるようにメーターを画面に残しておく時間です。",
	SI_PBSHPS_HUD_LEFT = "横位置",
	SI_PBSHPS_HUD_LEFT_TIP = "画面の左端からメーターまでの距離です。",
	SI_PBSHPS_HUD_TOP = "縦位置",
	SI_PBSHPS_HUD_TOP_TIP = "画面の上端からメーターまでの距離です。",

	SI_PBSHPS_SECTION_RECORD = "記録",
	SI_PBSHPS_ENABLED = "回復量を記録する",
	SI_PBSHPS_ENABLED_TIP = "オフにすると何も数えません。",
	SI_PBSHPS_OTHERS = "他のヒーラーの回復も数える",
	SI_PBSHPS_OTHERS_TIP = "パーティーメンバーが受けた回復のうち自分の分を出すために、他のヒーラーがパーティーメンバーに行った回復も数えます。オフにすると自分の回復だけを数えるので、その割合は100%になります。他のヒーラーの回復が1つも届かないときも同じです。大きな戦闘ではすべてのヒーラーの回復が対象になるので、動作が重く感じたらオフにしてください。",
	SI_PBSHPS_ZONES = "記録する場所",
	SI_PBSHPS_ZONES_TIP = "シロディールのみ (初期値)、すべてのPvPゾーン (シロディール・帝都・バトルグラウンド)、PvEも含めてどこでも、から選びます。",
	SI_PBSHPS_ZONE_CYRODIIL = "シロディールのみ",
	SI_PBSHPS_ZONE_PVP = "すべてのPvPゾーン",
	SI_PBSHPS_ZONE_ALL = "どこでも",
	SI_PBSHPS_GAP = "戦闘とみなす途切れ時間 (秒)",
	SI_PBSHPS_GAP_TIP = "この秒数のあいだ回復がなければ、その戦闘は終わりとします。HPSは、戦闘の最初の回復から最後の回復までの時間で回復量を割った値です。",

	SI_PBSHPS_SECTION_DATA = "データ",
	SI_PBSHPS_CLEAR = "記録をすべて消去",
	SI_PBSHPS_CLEAR_TIP = "記録された日・戦闘・スキルをすべて消します。先に確認が出ます。",
	SI_PBSHPS_BUTTON_RUN = "実行",
	SI_PBSHPS_ERR_NO_DIALOG = "確認を出せなかったため、何も消していません。",
	SI_PBSHPS_DIALOG_CLEAR_TITLE = "記録をすべて消去しますか？",
	SI_PBSHPS_DIALOG_CLEAR_TEXT = "保存されている回復量の統計を、すべての日について消去します。元に戻せません。",

	-- チャット
	SI_PBSHPS_LOADED = "PB's HPS Checker %s を読み込みました。/hps でコマンド一覧を表示します。",
	SI_PBSHPS_HELP = "/hps today | month | all -- 統計をチャットに出す\n/hps stats [today | month | all] -- 統計ウィンドウの表示・非表示\n/hps hud -- HPSメーターの表示・非表示\n/hps on | off -- 記録の開始・停止\n/hps status -- ここまでに数えたもの\n/hps probe -- ゲームがアドオンに届ける回復の種類を計測する (2分間)\n/hps debug -- 次の回復を、ゲームが報告したままの値で出す",
	SI_PBSHPS_CMD_SCOPE_HEADING = "[HPS] %s",
	SI_PBSHPS_CMD_TOP_TARGETS = "[HPS] 回復した相手 上位10",
	SI_PBSHPS_CMD_TOP_SKILLS = "[HPS] 回復に使ったスキル 上位10",
	SI_PBSHPS_CMD_ON = "HPS Checker の記録を開始しました。",
	SI_PBSHPS_CMD_OFF = "HPS Checker の記録を停止しました。",
	SI_PBSHPS_CMD_HUD_ON = "HPSメーターをオンにしました。",
	SI_PBSHPS_CMD_HUD_OFF = "HPSメーターをオフにしました。",
	SI_PBSHPS_CMD_DEBUG_ON = "デバッグをオンにしました。次の%d回の回復を出力します。",
	SI_PBSHPS_CMD_DEBUG_OFF = "デバッグをオフにしました。",
	SI_PBSHPS_DEBUG_FULL = "[HPS] デバッグの行数の上限に達しました。/hps debug でもう一度始められます。",
	-- 計測 (/hps probe)
	SI_PBSHPS_PROBE_START = "計測を開始しました。%d秒間、誰が誰を回復したかを問わず、ゲームから届く回復をすべて数えます。他のヒーラーが回復している場所にいてください。もう一度 /hps probe で途中で止めて結果を出せます。",
	SI_PBSHPS_PROBE_RUNNING = "[HPS] 計測中です。あと%d秒。",
	SI_PBSHPS_PROBE_HEADING = "[HPS] 計測結果 (%d秒)。ゲームから届いた回復を「発生源 > 相手」で分けたものです:",
	SI_PBSHPS_PROBE_NONE = "回復は1つも届きませんでした。",
	SI_PBSHPS_PROBE_LINE = "  %s > %s  %d回  %s  (発生源%d人)  例: %s",
	SI_PBSHPS_PROBE_LEGEND = "[HPS] 届いたか？ (PLAYER=自分、GROUP=パーティーメンバー、OTHER=それ以外)",
	SI_PBSHPS_PROBE_Q_SELF_GROUP = "自分 > パーティーメンバー",
	SI_PBSHPS_PROBE_Q_SELF_OTHER = "自分 > パーティー外",
	SI_PBSHPS_PROBE_Q_GROUP_GROUP = "パーティーメンバー > パーティーメンバー",
	SI_PBSHPS_PROBE_Q_OTHER_GROUP = "パーティー外 > パーティーメンバー",
	SI_PBSHPS_PROBE_Q_OTHER_OTHER = "パーティー外 > パーティー外",
	SI_PBSHPS_PROBE_YES = "○ 届いた (%d回)",
	SI_PBSHPS_PROBE_NO = "× 届かなかった",
	SI_PBSHPS_PROBE_CAVEAT = "[HPS] × は、計測中にその場面が無かっただけの可能性もあります。他のヒーラーが近くで回復している場面で、最初の2行は自分の回復も必要です。",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
