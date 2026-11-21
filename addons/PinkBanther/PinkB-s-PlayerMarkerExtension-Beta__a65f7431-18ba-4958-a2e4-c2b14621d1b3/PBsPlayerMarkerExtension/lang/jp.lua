-- Japanese strings (the game's language code for Japanese is "jp"). Only what differs from lang/strings.lua.
local S = PBS_PME_STRINGS

S.banner = "%s を読み込みました。"
S.notReady = "起動できなかった部分があります: %s"

S.notInGroup = "追加マーカーはグループのメンバーにだけ付けられます。あなたはグループに入っていません。"
S.notMember = "追加マーカーはグループのメンバーにだけ付けられます。先にグループメンバーを見てください。"
S.notMemberSelf = "追加マーカーはグループのメンバーか自分にだけ付けられます。グループメンバーを見るか、何も見ずに選ぶと自分に付きます。"
S.placed = "%s: マーカー「%s」を付けました。"
S.taken = "%s: マーカーを外しました。"
S.cleared = "すべてのマーカーを外しました。"
S.wheelClear = "マーカーを外す"
S.texturesMissing = "マーカーの画像 %d/%d 枚を読み込めませんでした（最初の1枚: %s）。そのため表示されません。アドオンのフォルダーに assets フォルダーが入っているか確認してください。詳しくは /pbpme status で分かります。"
S.engineStays = "%s にはゲーム標準のマーカーが付いていて、外せませんでした。先に標準のマーカーを外してから、追加マーカーを付けてください。"
S.engineWon = "%s: ゲーム標準のマーカーが付いたので、追加マーカーを外しました（マーカーは1人に1つだけです）。"
S.testOn = "しばらくの間、目の前にテスト用のマーカーを表示します。"
S.testNoPosition = "テスト用マーカーを出せません。位置が分かりません (%s)。"
S.texturesChecking = "マーカーの画像が読み込めるか確認します。数秒後に /pbpme status で結果が分かります。"
S.texturesBusy = "画像の確認はすでに実行中です。"
S.retried = "ゲーム関数について覚えたことを忘れました。もう一度確かめます。"
S.markUsage = "使い方: /pbpme mark <アイコン番号 1-%d>"
S.compassSet = "コンパスバー: 方角の取り方を %d 番に固定しました（/pbpme compass auto で、また自動で学習します）。"
S.compassAuto = "コンパスバー: 方角の取り方を、狙ったグループメンバーから自動で学習します（いまは %d 番）。"
S.compassUsage = "使い方: /pbpme compass 1|2|3|4|auto（バーのテスト用マーカーが、ゲームの N・E・S・W の文字の下に来るものが正解です）"

S.note = "グループメンバーを見ながら（何も見ていなければ自分に）マーカーホイール（十字キー右の長押し）を開くと、標準の8個の後ろに追加マーカーが並びます。"
S.enabled = "追加マーカー（ホイール・表示・共有）"
S.wheelSlots = "ホイールに並べる追加マーカーの数"
S.slot = "ホイールのマーカー %d"
S.shareSend = "自分が付けたマーカーをグループに送る"
S.shareReceive = "グループのマーカーを表示する"
S.markSelf = "何も見ていないときは自分にマーカーを付ける"
S.showSelf = "他の人が自分に付けたマーカーも表示する"
S.frameMarks = "グループ枠（左上の名前）にもマーカーを表示する"
S.compassMarks = "画面上部のコンパスバーにもマーカーを表示する"
S.compassFov = "コンパスバーが映す角度（度。標準マーカーとずれるときだけ変える）"
S.compassSize = "コンパスのマーカーの大きさ (%)"
S.throughWalls = "壁越しにマーカーを表示する"
S.size = "マーカーの大きさ (%)"
S.height = "マーカーの高さ：足元から下端まで (cm)"
S.heightPerMetre = "距離1mごとの追加の高さ (cm)"
S.facingOffset = "マーカーの向きの補正（度。絵が裏返しに見えるときだけ変える）"
S.opacity = "不透明度 (%)"
S.sound = "効果音"
S.chat = "チャットにメッセージを出す"
S.test = "テスト用マーカーを表示"
S.testButton = "テスト"
S.clear = "すべてのマーカーを外す"
S.clearButton = "外す"
S.reset = "初期値に戻す"
S.resetButton = "初期値"

S.icons = {
	"ハート", "ダイヤ", "矢印", "感嘆符", "疑問符", "稲妻", "炎", "しずく",
	"盾", "剣", "十字", "バツ", "チェック", "六角形", "王冠", "目",
	"雪の結晶", "葉", "太陽", "的", "旗", "爆弾", "進入禁止", "渦",
	"アカレンジャー", "アオレンジャー", "キレンジャー", "ミドリレンジャー", "ピンクレンジャー", "クロレンジャー",
	"紺レンジャー", "紫レンジャー", "シロレンジャー", "オレンジレンジャー", "シルバーレンジャー",
}

PBS_PME.MARK("jp")
