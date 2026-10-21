local s = PBS_COMPASS_STRINGS
local jp = {
	note = "画面中央のレティクルの周りに、半透明のコンパスリングを表示します。N・E・S・W はカメラの向きに合わせて回ります。パーティーメンバーは、自分から見た方向のリングの内側に小さなマーカーで表示され、近いほど中心に寄ります。下で設定した距離より遠いメンバーは、リングの縁に薄く表示されます。マーカーは位置の目安であり、正確な測定ではありません。リングの外にはみ出すこともありません。この設定画面を開いている間は、サンプルのメンバーつきでコンパスを画面の前面に表示するので、変更をその場で確認できます。",
	enabled = "コンパスを表示",
	preview = "設定調整中にも表示",
	opacity = "不透明度（%）",
	radius = "リングの半径（px）",
	x = "横位置のずらし（px）",
	y = "縦位置のずらし（px）",
	range = "リングの縁にあたる距離（m）",
	markerSize = "メンバーマーカーの大きさ",
	letterSize = "文字の大きさ",
	small = "小",
	medium = "中",
	large = "大",
	rotate = "リングが回る基準",
	camera = "カメラ（正面が上）",
	north = "回さない（北が上）",
	names = "メンバーの PSN ID を表示",
	ring = "細いガイドリングを表示",
	reset = "設定を初期化",
	resetButton = "初期化",
	bannerLine = "%s を読み込みました。/pbcompass status で読み取り状況を確認できます。",
	help = "/pbcompass on | off | reset | status | test | retry\n/pbcompass radius 200 | range 50 | opacity 60 | x 0 | y 0 | size 22\n/pbcompass letters small | medium | large | rotate camera | north | names on | ring on",
	testOn = "サンプルのメンバーを20秒間表示します。",
	retried = "位置取得の呼び出しについて覚えていた結果を消しました。次回また確認します。",
}
for key, value in pairs(jp) do
	s[key] = value
end
