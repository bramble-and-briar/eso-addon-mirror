local strings = {
	SI_PBSQTFC_EXPLANATION = "HUD右上に縦に並ぶトラッカーは通常のUIラベルで作られているため、フォントを直接変更できます（UIの再読み込みは発生せず、設定がセッションを越えて残ることもありません）。以下、画面に出る順番で、それぞれ別々に設定します。",

	-- ---- クエストトラッカー ------------------------------------------------------------
	SI_PBSQTFC_SECTION_QUEST = "クエストトラッカー",
	SI_PBSQTFC_SECTION_QUEST_NOTE = "画面右上に出る追跡中のクエスト（クエスト名・ステップ説明・目標行）です。ゲーム側でこの3つには別々のサイズが割り当てられているため、スライダーも分けてあります。",

	SI_PBSQTFC_QUEST_ENABLED = "クエストトラッカーのフォントを変更",
	SI_PBSQTFC_QUEST_ENABLED_TOOLTIP = "以下の設定をクエストトラッカーに適用します。オフにするとゲーム本来のフォントに戻ります。この欄の設定がすべてゲーム標準と同じ間は、そもそも何も書き込みません。",

	SI_PBSQTFC_SIZE_QUEST_NAME = "クエスト名の大きさ",
	SI_PBSQTFC_SIZE_QUEST_NAME_TOOLTIP = "トラッカー最上段のクエスト名の文字サイズです。初期値はゲームが実際に描画しているサイズを実測した値です。",
	SI_PBSQTFC_SIZE_QUEST_STEP = "ステップ説明の大きさ",
	SI_PBSQTFC_SIZE_QUEST_STEP_TOOLTIP = "クエスト名の下に出る、その段階の説明文の文字サイズです。すべてのクエストで表示されるわけではありません。",
	SI_PBSQTFC_SIZE_QUEST_GOAL = "目標行の大きさ",
	SI_PBSQTFC_SIZE_QUEST_GOAL_TOOLTIP = "実際にやるべきこと（および達成数）を示す行の文字サイズです。コンソール表示ではゲーム側がクエスト名より大きく描画しています。それがゲーム本来の設計で、変えたい場合はこのスライダーで調整します。",

	SI_PBSQTFC_POS_X = "横位置",
	SI_PBSQTFC_POS_X_TOOLTIP = "トラッカーの列をゲーム標準の位置から左右にずらします。0でそのままです。プラスが右方向。ゲームはクエスト・黄金の追跡・ハウス情報などすべてのトラッカーを1つの列にまとめているため、全部が一緒に移動し、並び順は保たれます。PCでは、ゲーム本体の「HUD編集」で位置を設定している場合そちらが優先されます。",
	SI_PBSQTFC_POS_Y = "縦位置",
	SI_PBSQTFC_POS_Y_TOOLTIP = "トラッカーの列をゲーム標準の位置から上下にずらします。0でそのままです。プラスが下方向。列は画面下端に収まらない分がスクロールになるため、下へずらすほど一度に見える量は減ります。",
	SI_PBSQTFC_SCALE = "表示倍率",
	SI_PBSQTFC_SCALE_TOOLTIP = "クエストトラッカー全体を拡大縮小します。文字・アイコン・キーバインド表示が比率を保ったまま変わります。対象はクエストトラッカーのみで、その下のパネルは大きさを変えずに新しい高さに合わせて並びます。100%がゲーム標準です。拡大縮小はクライアントにフォントを構築させないため、コンソールでもコストがかかりません。パネルは右上を基準に拡大縮小されます（そこがアンカー位置のため）。",

	SI_PBSQTFC_QUEST_FACE = "クエストトラッカーの書体",
	SI_PBSQTFC_QUEST_STYLE = "クエストトラッカーの縁取り",

	-- ---- 黄金の追跡 --------------------------------------------------------------------
	SI_PBSQTFC_SECTION_PURSUIT = "黄金の追跡",
	SI_PBSQTFC_SECTION_PURSUIT_NOTE = "クエストトラッカーとハウス情報の間に出るパネルです。追跡中の「黄金の追跡」の課題と、その進行状況のバーが表示されます。同じパネルが「タムリエルの書」やピン留めした実績にも使われるため、この設定はそれらすべてに適用されます。",

	SI_PBSQTFC_PURSUIT_ENABLED = "黄金の追跡のフォントを変更",
	SI_PBSQTFC_PURSUIT_ENABLED_TOOLTIP = "以下の設定を「黄金の追跡」パネルに適用します。オフにするとゲーム本来のフォントに戻ります。この欄の設定がすべてゲーム標準と同じ間は、そもそも何も書き込みません。",

	SI_PBSQTFC_SIZE_PURSUIT_NAME = "見出しの大きさ",
	SI_PBSQTFC_SIZE_PURSUIT_NAME_TOOLTIP = "アイコンの横に出る見出し行（「黄金の追跡」、追跡対象によっては「タムリエルの書」）の文字サイズです。",
	SI_PBSQTFC_SIZE_PURSUIT_DETAIL = "課題名の大きさ",
	SI_PBSQTFC_SIZE_PURSUIT_DETAIL_TOOLTIP = "見出しの下に出る、追跡中の課題名の文字サイズです。",
	SI_PBSQTFC_SIZE_PURSUIT_PROGRESS = "進行状況の大きさ",
	SI_PBSQTFC_SIZE_PURSUIT_PROGRESS_TOOLTIP = "進行状況バーの中に出る数字の文字サイズです。バー自体の大きさは変わらないため、大きくしすぎるとバーからはみ出します。",

	SI_PBSQTFC_PURSUIT_FACE = "黄金の追跡の書体",
	SI_PBSQTFC_PURSUIT_STYLE = "黄金の追跡の縁取り",

	-- ---- ハウストラッカー --------------------------------------------------------------
	SI_PBSQTFC_SECTION_HOUSE = "ハウス情報（ホームツアー）",
	SI_PBSQTFC_SECTION_HOUSE_NOTE = "家の中にいる間、クエストトラッカーの下に出るパネルです（自分の家でも、ホームツアーで訪れた他人の家でも表示されます）。家の名前、愛称と所有者、中にいる人数、ホームツアーのタグが並びます。",

	SI_PBSQTFC_HOUSE_ENABLED = "ハウス情報のフォントを変更",
	SI_PBSQTFC_HOUSE_ENABLED_TOOLTIP = "以下の設定をハウス情報パネルに適用します。オフにするとゲーム本来のフォントに戻ります。この欄の設定がすべてゲーム標準と同じ間は、そもそも何も書き込みません。",

	SI_PBSQTFC_SIZE_HOUSE_NAME = "家の名前の大きさ",
	SI_PBSQTFC_SIZE_HOUSE_NAME_TOOLTIP = "パネル最上段の家の名前の文字サイズです。",
	SI_PBSQTFC_SIZE_HOUSE_DETAIL = "詳細行の大きさ",
	SI_PBSQTFC_SIZE_HOUSE_DETAIL_TOOLTIP = "家の名前の下に並ぶすべて（愛称と所有者・人数・ホームツアーのタグ）の文字サイズです。ゲーム側がこの3つを同じフォントで描画しているため、スライダーも1本にまとめてあります。",

	SI_PBSQTFC_HOUSE_FACE = "ハウス情報の書体",
	SI_PBSQTFC_HOUSE_STYLE = "ハウス情報の縁取り",

	-- ---- 共通 --------------------------------------------------------------------------
	SI_PBSQTFC_FACE_TOOLTIP_COMMON = "ゲームが持っている書体から選び、このトラッカーの全部分に適用します。「デフォルト」はゲームが各部分に割り当てた書体のまま（コンソール表示では最上段の名前は太字、その下は標準）で、どの言語でも一番安全です。選択肢はUIが既に読み込んでいる書体のみです。それ以外は設定時にクライアントが構築する必要があり、コンソールではアドオン共有メモリに計上されて落ちるため、石版・手書き・アンティーク・チャットは選択肢から外してあります。日本語版では一部が同じフォントに解決されます（UI標準／UI太字／コンソール細字＝同じゴシック）。コンソール標準・太字は英数字だけが専用書体になり、日本語部分はゴシックになります。",
	SI_PBSQTFC_FACE_DEFAULT = "デフォルト",
	SI_PBSQTFC_FACE_GAMEPAD_MEDIUM = "コンソール（標準）",
	SI_PBSQTFC_FACE_GAMEPAD_BOLD = "コンソール（太字）",
	SI_PBSQTFC_FACE_GAMEPAD_LIGHT = "コンソール（細字）",
	SI_PBSQTFC_FACE_MEDIUM = "UI（標準）",
	SI_PBSQTFC_FACE_BOLD = "UI（太字）",

	SI_PBSQTFC_STYLE_TOOLTIP_COMMON = "背景から文字を浮き立たせる方法で、このトラッカーの全部分に適用します。明るい場所では縁を太くすると読みやすくなります。【注意】縁取り系を選ぶとクライアントが縁取り用の字形を生成します。ゲーム本体のソースによると日本語フォントではこれに約100MBかかり、コンソールのアドオン共有メモリ（100MB）と同規模です。動作が不安定になる場合は「デフォルト」のままにしてください。",
	SI_PBSQTFC_STYLE_DEFAULT = "デフォルト",
	SI_PBSQTFC_STYLE_NORMAL = "なし",
	SI_PBSQTFC_STYLE_SHADOW = "影",
	SI_PBSQTFC_STYLE_SOFT_SHADOW_THIN = "やわらかい影（細）",
	SI_PBSQTFC_STYLE_SOFT_SHADOW_THICK = "やわらかい影（太）",
	SI_PBSQTFC_STYLE_OUTLINE_THICK = "縁取り（太）",

	SI_PBSQTFC_SECTION_GENERAL = "すべてに共通",
	SI_PBSQTFC_RESET = "初期設定に戻す",
	SI_PBSQTFC_RESET_TOOLTIP = "上のすべての欄を、ゲーム本来のフォントに戻します。",
	SI_PBSQTFC_RESET_BUTTON = "戻す",

	SI_PBSQTFC_GAME_SETTINGS_HINT = "各トラッカーを表示するかどうかはゲーム本体の設定です（設定 > インターフェース）。アドオンからは変更できないため、そちらで設定してください。",
}

strings.SI_PBSQTFC_QUEST_FACE_TOOLTIP = strings.SI_PBSQTFC_FACE_TOOLTIP_COMMON
strings.SI_PBSQTFC_PURSUIT_FACE_TOOLTIP = strings.SI_PBSQTFC_FACE_TOOLTIP_COMMON
strings.SI_PBSQTFC_HOUSE_FACE_TOOLTIP = strings.SI_PBSQTFC_FACE_TOOLTIP_COMMON
strings.SI_PBSQTFC_QUEST_STYLE_TOOLTIP = strings.SI_PBSQTFC_STYLE_TOOLTIP_COMMON
strings.SI_PBSQTFC_PURSUIT_STYLE_TOOLTIP = strings.SI_PBSQTFC_STYLE_TOOLTIP_COMMON
strings.SI_PBSQTFC_HOUSE_STYLE_TOOLTIP = strings.SI_PBSQTFC_STYLE_TOOLTIP_COMMON

for stringId, stringValue in pairs(strings) do
	SafeAddString(_G[stringId], stringValue, 2)
end
