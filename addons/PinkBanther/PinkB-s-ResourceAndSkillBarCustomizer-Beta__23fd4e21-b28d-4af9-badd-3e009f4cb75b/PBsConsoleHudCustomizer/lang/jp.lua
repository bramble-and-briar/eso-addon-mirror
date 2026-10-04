local strings = {
	SI_PBSCHC_EXPLANATION = "HUDの体力・マジカ・スタミナバーの位置と大きさを変更します。ゲーム本体では3本とも画面下部の固定位置・固定サイズです。以下の項目はすべてゲーム本来の値から始まり、動かすまでは何も変更しません。このパネルを開いている間は、各バーの位置と大きさを色付きの枠で表示します。",

	SI_PBSCHC_ENABLED = "リソースバーを変更する",
	SI_PBSCHC_ENABLED_TOOLTIP = "以下の設定を適用します。オフにすると、3本ともすぐにゲーム本来の位置と大きさに戻します（設定内容は残るので、オンに戻せば再び適用されます）。",

	SI_PBSCHC_PREVIEW = "ここでプレビューを表示",
	SI_PBSCHC_PREVIEW_TOOLTIP = "バーはHUD上でしか描画されないため、このメニューからは見えません。オンの間は、各バーが表示される場所に、そのバーと同じ大きさの枠を表示します。",

	SI_PBSCHC_BAR_HEALTH = "体力",
	SI_PBSCHC_BAR_MAGICKA = "マジカ",
	SI_PBSCHC_BAR_STAMINA = "スタミナ",

	SI_PBSCHC_BAR_SKILLBAR = "スキルバー",

	-- ---- バーの見た目 --------------------------------------------------------------------
	SI_PBSCHC_SECTION_STYLE = "バーの見た目",
	SI_PBSCHC_STYLE = "バーのスタイル",
	SI_PBSCHC_STYLE_TOOLTIP = "「標準」はゲーム本来のバーのままです。「リキッド」は標準の形・枠・光沢を保ったまま、中身をガラス管に入った液体のように見せます。柔らかな光の揺らぎが流れ、量が変わると液面が波打ち、減った分は流れ落ちるように消え、泡が浮き上がり、ガラスに光が走ります。「クリスタル」も同じ形のまま、中身を透き通ったカットクリスタルのように見せます。面ごとに光を順に受けるファセット、明るい稜線、きらめく輝きが入ります。どちらも初期状態ではゲーム本来のバーと同じ不透明度で、下の「不透明度」で透けさせられます。「四角」は各バーを平坦な長方形で描きます（暗いトラックと、そのリソース本来の色で塗られた四角）。大きさはゲーム本来のままで、倍率で調整します。「MURA-HIGE Style」は同じ四角を、下で指定した幅と高さで描きます。「MURA-HIGE NEO Style」は同じ幅・高さの設定で、体力・マジカ・スタミナすべてが左から右へ満ちます。これらのスタイルはゲーム側の矢印型の枠と背景を一時的に非表示にしますが、バー自体はそのまま残して動かしているので、ダメージシールドや防御力変化、瀕死の警告表示は今までどおり上に表示されます。",
	SI_PBSCHC_STYLE_LIQUIDFLOW = "リキッド",
	SI_PBSCHC_STYLE_CRYSTAL = "クリスタル",
	SI_PBSCHC_STYLE_STANDARD = "標準",
	SI_PBSCHC_STYLE_PLAIN = "四角",
	SI_PBSCHC_STYLE_ROUNDED = "MURA-HIGE Style",
	SI_PBSCHC_STYLE_NEO = "MURA-HIGE NEO Style",
	SI_PBSCHC_PLAIN_OPACITY = "不透明度",
	SI_PBSCHC_PLAIN_OPACITY_TOOLTIP = "四角をどれだけ濃く描くかです。100%でゲーム本来の塗りを完全に隠します。下げると下のバーが透けるため、元の見た目を少し残したい場合に使えます。",
	SI_PBSCHC_BORDER_COLOUR = "枠線の色",
	SI_PBSCHC_BORDER_COLOUR_TOOLTIP = "四角・MURA-HIGE Style・MURA-HIGE NEO Styleの枠線の色です。体力・マジカ・スタミナに共通で適用します。「枠線を描く」がオンのときに表示されます。",
	SI_PBSCHC_BORDER_BLACK = "黒（標準）",
	SI_PBSCHC_BORDER_WHITE = "白",
	SI_PBSCHC_BORDER_SILVER = "銀色",
	SI_PBSCHC_BORDER_GOLD = "金色",
	SI_PBSCHC_BORDER_RED = "赤",
	SI_PBSCHC_BORDER_BLUE = "青",
	SI_PBSCHC_RESOURCE_ALIGN = "バー内の文字の配置",
	SI_PBSCHC_RESOURCE_ALIGN_TOOLTIP = "MURA-HIGE StyleとMURA-HIGE NEO Styleのバー内の文字を配置します。体力・マジカ・スタミナに共通で適用します。初期値は左寄せです。",
	SI_PBSCHC_RESOURCE_ALIGN_LEFT = "左寄せ",
	SI_PBSCHC_RESOURCE_ALIGN_RIGHT = "右寄せ",
	SI_PBSCHC_RESOURCE_ALIGN_CENTER = "中央揃え",

	SI_PBSCHC_PLAIN_BORDER = "枠線を描く",
	SI_PBSCHC_PLAIN_BORDER_TOOLTIP = "各バーの周囲に選択した色の細い線を描きます。ゲーム本来の矢印型の枠は、これらのスタイルを選んでいる間は常に非表示になるため（平坦な四角を矢印型の枠に入れても中途半端なため）、枠としてはこれだけになります。オフにすると、線のない色の塊だけになります。",

	-- ---- スキルの網掛け ------------------------------------------------------------------
	SI_PBSCHC_SECTION_SHADE = "使用中スキルの網掛け",
	SI_PBSCHC_SHADE_EXPLANATION = "スキルの効果が続いている間、そのアイコンを暗く網掛けし、残り時間に合わせて上から下へ網掛けが消えていきます。数字を読まなくても残りが分かります。表バー・裏バーの両方で動作し、掃引はゲームエンジン自身が行うため、効果時間とずれることがありません。",
	SI_PBSCHC_SHADE_ENABLED = "効果中のスキルを網掛けする",
	SI_PBSCHC_SHADE_ENABLED_TOOLTIP = "効果が続いているスキルのアイコンを暗くし、カウントダウンに合わせてその暗さを消していきます。",
	SI_PBSCHC_SHADE_DARKNESS = "網掛けの濃さ",
	SI_PBSCHC_SHADE_DARKNESS_TOOLTIP = "効果中にアイコンをどれだけ暗くするかです。0%にするとアイコンはそのままで、動く境界線だけが表示されます。",
	SI_PBSCHC_SHADE_DIRECTION = "消えていく向き",
	SI_PBSCHC_SHADE_DIRECTION_TOOLTIP = "「上から下へ」は、アイコンの上側から網掛けが消えていき、残りが下に沈んでいく見え方です。将来のアップデートで掃引の向きが逆になった場合は、こちらで戻せます。",
	SI_PBSCHC_SHADE_DIRECTION_DOWN = "上から下へ",
	SI_PBSCHC_SHADE_DIRECTION_UP = "下から上へ",
	SI_PBSCHC_SHADE_EDGE = "境界を光らせる",
	SI_PBSCHC_SHADE_EDGE_TOOLTIP = "網掛けの境界に光る線を表示します。ゲーム本体がスキルのクールダウンに使っているものと同じ線です。",
	SI_PBSCHC_SKILLBAR_ENABLED = "スキルバーをこのアドオンで制御する",
	SI_PBSCHC_SKILLBAR_ENABLED_TOOLTIP = "オフにすると、スキルバーをゲーム本体（および他のアドオン）に完全に明け渡します。位置・大きさ・間隔・裏バー・アイコン上の残り時間と対象数・使用中スキルの網掛けをすべて元に戻し、以後何も書き込みません（設定内容は残るので、オンに戻せば再び適用されます）。体力・マジカ・スタミナのバーには影響しません。",
	SI_PBSCHC_BAR_WIDTH = "<<1>>：バーの幅",
	SI_PBSCHC_BAR_WIDTH_TOOLTIP = "バーを描く幅（ピクセル）です。MURA-HIGE StyleとMURA-HIGE NEO Style専用です。このスタイルはバーそのものを描くためサイズを直接指定できます。他のスタイルはゲーム本来のバーを拡大縮小する方式です（それらのコントロールの幅はゲーム側が書き換えるため）。ゲーム本来は224です。",
	SI_PBSCHC_BAR_HEIGHT = "<<1>>：バーの高さ",
	SI_PBSCHC_BAR_HEIGHT_TOOLTIP = "バーを描く高さ（ピクセル）です。MURA-HIGE StyleとMURA-HIGE NEO Style専用です。ゲーム本来は17です。",

	-- ---- スキルバーの間隔 ----------------------------------------------------------------
	SI_PBSCHC_SECTION_GAPS = "スキルバーの間隔",
	SI_PBSCHC_GAPS_EXPLANATION = "各ボタンの横の間隔です。ゲーム本体はアルティメットとアイテムの周りを大きく空けており、さらにアイテムとスキルの間には、コンソールでは描画されない武器切替マーカー（見えないコントロール）が場所を取っています。ここで設定するのは、実際に画面上で見える間隔です。",
	SI_PBSCHC_GAP_SKILL = "スキル同士の間隔",
	SI_PBSCHC_GAP_SKILL_TOOLTIP = "5つのスキルボタンの間隔です。ゲーム本来は10です。",
	SI_PBSCHC_GAP_ULTIMATE = "アルティメットの手前",
	SI_PBSCHC_GAP_ULTIMATE_TOOLTIP = "最後のスキルとアルティメットの間隔です。ゲーム本来は65で、アルティメットが離れて配置されている原因です。",
	SI_PBSCHC_GAP_ITEM = "アイテムの手前",
	SI_PBSCHC_GAP_ITEM_TOOLTIP = "クイックスロット（アイテム）と最初のスキルの間隔です。仲間を連れているときは、アイテムと仲間のアルティメットの間隔にも同じ値を使います。ゲーム本来はここに見えない武器切替マーカーの幅がまるごと入っているため、一番詰められる場所です。",

	-- ---- 裏バー ------------------------------------------------------------------------
	SI_PBSCHC_SECTION_BACKBAR = "裏バー（もう一方の武器セット）",
	SI_PBSCHC_BACKBAR_EXPLANATION = "スキルバーの上に、もう一方の武器セットのスキルを並べて表示します。表バーと同じく、残り時間と対象数もアイコン上に表示します。ゲーム本体にも裏バー表示はありますが、効果が続いているスロットだけが一時的に出るもので、常時表示ではありません。",
	SI_PBSCHC_BACKBAR_ENABLED = "裏バーを表示する",
	SI_PBSCHC_BACKBAR_ENABLED_TOOLTIP = "今使っていない方の武器セットのスキルを、スキルバーの上に表示します。武器を切り替えると表裏も入れ替わります。",
	SI_PBSCHC_BACKBAR_EMPTY = "空きスロットも表示する",
	SI_PBSCHC_BACKBAR_EMPTY_TOOLTIP = "スキルが入っていないスロットの枠も表示し、列の幅を一定に保ちます。オフにすると、スキルが入っているスロットだけを表示します。",
	SI_PBSCHC_BACKBAR_SCALE = "裏バーの大きさ",
	SI_PBSCHC_BACKBAR_SCALE_TOOLTIP = "裏バーのアイコンの倍率です。スキルバー自体の倍率に掛け算されるため、バーを80%にして裏バーも80%にすると、裏バーはさらに小さくなります。",
	SI_PBSCHC_BACKBAR_GAP = "バーとの間隔",
	SI_PBSCHC_BACKBAR_GAP_TOOLTIP = "スキルバーから裏バーまでの距離です。裏バーはスキルバーに追従するため、設定が必要な距離はこれだけです。",

	-- ---- アイコン上の文字 ----------------------------------------------------------------
	SI_PBSCHC_SECTION_TEXT = "スキルバーの文字",
	SI_PBSCHC_TEXT_EXPLANATION = "各スキルの効果が切れるまでの残り時間と、効果がかかっている対象数を、アイコン上に表示します（表バー・裏バーとも）。残り時間はゲーム本体が持っている値そのもので、ゲームのアクションバータイマーと同じ数字です。",
	SI_PBSCHC_TIMER_MODE = "表バーの残り時間",
	SI_PBSCHC_TIMER_MODE_TOOLTIP = "裏バーには常にこのアドオンの残り時間を表示します（ゲーム側は裏バーに数字を出さないため）。表バーについては、ゲーム側の「設定 > インターフェース > アクションバータイマー」がオンのとき、ゲーム側の数字（サイズ変更不可）が出ます。「このアドオン」を選ぶと、ゲーム側の数字を薄く消したうえでこのアドオンの数字を表示するため、下の文字サイズが必ず反映されます。「両方」はゲーム側と並べて表示、「ゲームに任せる」は表バーに手を触れません。",
	SI_PBSCHC_TIMER_MODE_ADDON = "このアドオン",
	SI_PBSCHC_TIMER_MODE_BOTH = "両方",
	SI_PBSCHC_TIMER_MODE_GAME = "ゲームに任せる",
	SI_PBSCHC_TIMER_SIZE = "残り時間の文字サイズ（表バー）",
	SI_PBSCHC_TIMER_SIZE_TOOLTIP = "表バー（今使っている武器セット）の残り時間の文字サイズです。ゲーム本来は27です。",
	SI_PBSCHC_TIMER_SIZE_BACK = "残り時間の文字サイズ（裏バー）",
	SI_PBSCHC_TIMER_SIZE_BACK_TOOLTIP = "裏バー（今使っていない方の武器セット）の残り時間の文字サイズです。裏バーのアイコンは表バーより小さいため、少し小さめの方が収まりが良いことがあります。動かすまでは上の設定に追従します。",
	SI_PBSCHC_COUNT_SIZE_BACK = "対象数の文字サイズ（裏バー）",
	SI_PBSCHC_COUNT_SIZE_BACK_TOOLTIP = "裏バーの対象数の文字サイズです。動かすまでは上の設定に追従します。",
	SI_PBSCHC_TEXT_SIZE_MATCH = "裏バーを表バーに合わせる",
	SI_PBSCHC_TEXT_SIZE_MATCH_TOOLTIP = "裏バー用に設定した文字サイズを破棄し、再び表バーの設定に追従させます。",
	SI_PBSCHC_TIMER_DECIMALS = "10秒未満は小数第1位まで",
	SI_PBSCHC_TIMER_DECIMALS_TOOLTIP = "残り10秒未満のとき、9.4のように小数第1位まで表示します。1分以上は常に「分」で表示します。",
	SI_PBSCHC_COUNT_ENABLED = "対象数を表示する",
	SI_PBSCHC_COUNT_ENABLED_TOOLTIP = "効果がかかっている対象の数をアイコンの角に表示します。自分（および自分のペット）がかけた効果を数え、発動との対応付けで紐付けます。自分自身やペットにかかった効果は数えません（残り時間の表示で分かるため）。",
	SI_PBSCHC_COUNT_SIZE = "対象数の文字サイズ（表バー）",
	SI_PBSCHC_COUNT_SIZE_TOOLTIP = "表バーの対象数の文字サイズです。",
	SI_PBSCHC_COUNT_FROM_ONE = "対象が1体でも表示する",
	SI_PBSCHC_COUNT_FROM_ONE_TOOLTIP = "対象が1体のときにも数字を表示します（初期状態はオン）。オフにすると2体以上のときだけ表示するため、単体スキルに常に1が出ることはありませんが、単体スキルには何も表示されなくなります。",

	SI_PBSCHC_POSITION_X = "<<1>>：左右の位置",
	SI_PBSCHC_POSITION_X_TOOLTIP = "画面中央から、バーの中心までの左右の距離です。0でちょうど中央、マイナスで左、プラスで右へ移動します。",
	SI_PBSCHC_POSITION_Y = "<<1>>：高さ",
	SI_PBSCHC_POSITION_Y_TOOLTIP = "画面下端から、バーの中心までの高さです。ゲーム本来のバーは、スキルバーを避けて下から137の位置にあります。",

	SI_PBSCHC_SCALE = "<<1>>：大きさ",
	SI_PBSCHC_SCALE_TOOLTIP = "ゲーム本来の大きさを100%とした倍率です。枠・背景・バー・数値がすべて同じ比率で拡大縮小し、バーは中心の位置を保ったまま大きさだけが変わります。付属の小さいバー（マジカの上の狼、スタミナの下の騎乗スタミナ、体力の下の攻城兵器）も同じ倍率になります。",

	SI_PBSCHC_RESET_BAR = "<<1>>を初期設定に戻す",
	SI_PBSCHC_RESET_BAR_TOOLTIP = "このバーだけを、ゲーム本来の位置と大きさに戻します。",

	SI_PBSCHC_SECTION_GENERAL = "3本すべて",
	SI_PBSCHC_RESET = "すべて初期設定に戻す",
	SI_PBSCHC_RESET_TOOLTIP = "3本とも、ゲーム本来の位置と大きさに戻します。",
	SI_PBSCHC_RESET_BUTTON = "戻す",

	SI_PBSCHC_SECTION_TRACE = "計測",
	SI_PBSCHC_TRACE_HINT = "スキルのカウントダウンがおかしい原因を調べるための機能です。「開始」を押してから対象のスキルを1回使い、範囲指定スキルなら「設置する」「キャンセルする」を1回ずつ行い、「表示」を押してください。ゲームから届いた情報と、その時刻がチャット欄に出力されます。「開始」を押すまで何も記録せず、「表示」で記録を止めます。画面表示には一切影響しません。",
	SI_PBSCHC_TRACE_START = "使用時の動作を記録する",
	SI_PBSCHC_TRACE_START_TOOLTIP = "これ以降に使用したスキルについて、ボタン入力・範囲指定の円・効果・戦闘イベントをすべて記録します。",
	SI_PBSCHC_TRACE_START_BUTTON = "開始",
	SI_PBSCHC_TRACE_SHOW = "記録を表示する",
	SI_PBSCHC_TRACE_SHOW_TOOLTIP = "記録を止めて、届いた順に時刻付きでチャット欄に出力します。",
	SI_PBSCHC_TRACE_SHOW_BUTTON = "表示",

	SI_PBSCHC_GAME_SETTINGS_HINT = "バーに数値を表示するか、戦闘していないときにバーを薄くするかはゲーム本体の設定です（設定 > インターフェース）。アドオンからは変更できないため、そちらで設定してください。",

	SI_PBSCHC_PREVIEW_CAPTION = "リソースバー（プレビュー）",
}

for stringId, stringValue in pairs(strings) do
	SafeAddString(_G[stringId], stringValue, 2)
end
