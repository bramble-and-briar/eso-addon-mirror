# Store listing copy

Text for the Bethesda.net / ZOS Console AddOn Uploader entry. Plain text, no markdown —
paste as-is. The **name** field is what the in-game add-on browser shows, so it must read
`PB's CyrodiilAlert` there; `## Title` in the manifest does not reach that screen.

---

## Name

PB's CyrodiilAlert

## Overview (JP)

シロディールの自陣営の拠点を見張り、攻撃を受けたらチャット欄に赤文字で知らせます。
攻撃を凌いだら青、奪われたら黄色。拠点名は必ず入ります。画面上への表示（書体・サイズ・
位置を調整可）と、拠点数・得点・攻撃中の数をまとめた戦況表示も任意で出せます。

## Overview (EN)

Watches your alliance's holdings in Cyrodiil and says so in chat, in red, when one comes
under attack — blue when the attack is beaten off, yellow when it is lost, always with the
name of the holding. Alerts can also be drawn on screen, and a rough campaign summary kept
in a corner.

---

## Description (JP)

シロディールは砦が攻撃されていることを知っていますが、それを教えてくれるのはマップ上の
交差した剣のピンだけです。移動中、資源を回している最中、別の砦で戦っている最中——
自分の本拠が落とされる攻城戦は、たいてい静かに始まって静かに終わります。
このアドオンは、マップが表示に使っているのと同じデータを一定周期で読み、それをチャット欄
（と、必要なら画面）に出します。

■ 4種類の通知

・赤　攻撃を受けている。攻撃が続いている間は一定時間ごとに再通知します。
・青　攻撃が止み、まだ自陣営のもの＝防衛成功。
・黄　所有者が変わった＝防衛失敗。奪った陣営名も出ます。
・緑　他陣営の拠点で戦闘が始まった（任意・初期はオフ）。自陣営のものになれば青で
　　　「占領しました」。

「奪われた」の判定は攻撃フラグではなく所有陣営を見ています。落ちた直後の拠点は味方が
すぐ殴り返すため攻撃中のままなのが普通で、攻撃が止むのを待つと通知が出ないか大きく
遅れるためです。

■ 出力ウィンドウ

このアドオンの出力（通知もコマンドの応答もすべて）は、初期状態では専用のウィンドウに出ます。
チャット欄が埋まって会話が流れてしまうのを防ぐためです。コンソールにはタブによる振り分けが
ありません。

・出力先はウィンドウ／チャット欄／両方から選べます。
・幅・高さ・文字サイズ・保持行数・背景の濃さ・表示位置・重なり順（最前面／標準／最背面）を
　設定できます。重なり順は戦況表示とは別に持ちます。
・新しい行が上に入ります（折り返しが起きても新しい行が切られない唯一の並びです）。
・ウィンドウはクリックもドラッグもできません。下のゲームからクリックを奪わないためで、
　大きさと位置をドラッグではなく設定で決めているのも同じ理由です。
・シロディールと帝都の外では、ウィンドウは非表示になります（空になるのではなく消えます）。
　その間の出力はチャット欄に出るので、見落とすことはありません。再入場時は空の状態で出ます。
・ウィンドウを作成できないクライアントでは、すべてチャット欄に出ます。アドオンが自分の
　出力を黙って捨てることはありません。

■ 監視

・監視周期は1〜60秒（初期値5秒）。1回の走査はクライアントが既に持っている値を数十個
　読むだけで、サーバー通信は発生しません。
・攻撃が続いている拠点の再通知は15〜600秒（初期値60秒）。長い攻城戦でも通知が
　途切れず、かといって毎周期うるさくなることもありません。
・監視対象は種類ごとに選べます。砦・前哨（初期オン）、村（初期オン）、資源（初期オフ）、
　帝都の地区（初期オフ）。資源は取り合いが頻繁すぎて、オンにすると誰も応援に行かない
　通知でチャット欄が埋まります。
・橋・関門・巻物の門は常に対象外です。占領できる拠点ではなく構造物のためです。

■ 誰が攻撃しているかについて

クライアントは「その拠点が攻撃を受けている」ことしか教えてくれません。攻撃している陣営を
返すAPIは存在しないため、緑の通知は「戦闘が始まりました」であって「自陣営が攻撃を
開始しました」ではありません。3陣営のキャンペーンでは、残り2陣営同士の衝突であることも
あるからです。

唯一の手掛かりとして、ゲームが攻城兵器の数を持っている拠点では、自陣営の攻城兵器が
何基立っているかを併記します。自陣営が所有していない拠点に自陣営の攻城兵器があるなら、
それは自陣営の攻めです。ただし攻城兵器を使わない攻撃もあるため、断定はせず数字のまま
出しています。

初期設定では、この条件を満たす拠点だけを通知します（「自陣営の攻城兵器がある拠点だけ」）。
「自陣営が攻めている戦闘だけ知りたい」に、クライアントが最も近づける形です。代わりに、
攻城兵器を使わない攻撃と、攻城兵器を置く前の攻撃開始直後は通知されません。資源・村・地区は
ゲームが攻城兵器の数を持たないため、この設定がオンの間は通知対象になりません。
オフにすると、他陣営の拠点での戦闘をすべて通知します（誰の攻撃かは分からないまま）。

なおこれは通知を抑えるだけで、監視は続けています。その拠点が自陣営のものになれば
「占領しました」は出ますし、後から自陣営の攻城兵器が立てば、その時点で通知します。

■ エルダースクロール（巻物）

巻物が動いたとき、誰が動かしたかを名前つきで通知します。

　だれか（アルドメリ・ドミニオン）が ガルトーク を チャルマン砦 から奪いました

奪取・拾得・確保・返還・落下と、時間切れによる自動返還（これだけは実行者がいないので
名前は出ません）に対応しています。1キャンペーンに6本しかなく持ち主も頻繁には変わらない
ため通知量はごくわずかですが、1行ごとが部隊の向きを変える価値のある情報です。初期オンです。

これは監視ではなくイベントで届くので、監視周期の設定は関係ありません。名前はコンソールでは
表示名、PCではキャラクター名を使います（ゲーム本体のアナウンスと同じ切り替えです）。

■ 画面表示（任意・初期はオフ）

チャット欄は後から遡れる記録ですが、移動中に気づけるのは画面の方です。同じ通知を、
一瞬で読める長さに短くして画面に描きます。

・書体（5種）、サイズ（14〜64）、縁取り（4種＋なし）
・表示位置（上中央・中央・下中央・左上・右上）＋左右・上下のオフセット
・1行を表示し続ける時間（2〜30秒）。同時3行まで、4行目が来ると一番古い行が消えます。
・どの通知を画面に出すかは種類ごとに選べます（初期は「攻撃中」と「陥落」）。
・テストボタンで、攻城戦を待たずに5種類を1回ずつ出して見た目を確認できます。

書体は、コンソールのUIがすでに読み込んでいるものだけを候補にしています。UIが他で
使っていない書体は使用時に構築が走り、コンソールではアドオン共通のメモリを消費します。

ウィンドウはマウス無効です。下のゲームからクリックを奪うことは決してありません。
位置をドラッグではなく設定で決めているのも同じ理由です。

■ 戦況表示（任意・初期はオフ）

画面の隅に、キャンペーンの要約を常時表示できます。

　Chalman
　> エボンハート・パクト  拠点 8  得点 12,345  攻撃中 2  人口 中
　　 アルドメリ・ドミニオン  拠点 5  得点 9,000  攻撃中 0  人口 高
　　 ダガーフォール・カバナント  拠点 2  得点 3,000  攻撃中 0  人口 低
　　 ヴォレルドルング: アルドメリ・ドミニオン
　　 皇帝: Someone（アルドメリ・ドミニオン）

各行は陣営色、自陣営には > が付き、得点順に並びます。オン／オフ、表示位置、サイズ、
そして重なり順（最前面／標準／最背面）を個別に設定できます。置きたい隅を他のUIが
すでに使っている場合は、最背面にすればそちらを隠しません（代わりに隠されます）。
書体と縁取りは通知表示と共用です。

人口は、シロディール入場時のキャンペーン選択画面に出るものと同じ推定値です（低・中・高・満杯の
4段階で、**人数ではありません**。ゲームは実数を公開していません）。表示にはゲーム自身の
キャンペーンブラウザのアイコンをそのまま使います（設定で文字表示にも切り替えられます）。サーバーへの問い合わせで
得られるデータなので、戦況表示がオンの間、5分に1回だけ取得し直します。取得できるまでは
「-」と表示します。

ヴォレルドルングは出現している間だけ、所持している陣営を表示します（誰も持っていなければ
「未所持」、自分が持っていればその旨）。**所持プレイヤーの名前は表示できません。**
ゲームがその情報をアドオンに渡しておらず、ゲーム自身も表示していないためです（巻物とは
異なり、陣営までが限界です）。

ヴォレルドルングには経過時間と目安も表示します。

　ヴォレルドルング: 使い手を探している（6:20経過 / 公開まで目安 4〜9分）
　ヴォレルドルング: アルドメリ・ドミニオン（公開から 22:10 / 消滅まで目安 約8分）
　ヴォレルドルング: オブリビオンに戻った（1:04:30経過）

ゲームは出現・消滅の時刻を公開しておらず、アナウンスにも時間は入っていません。そのため
アナウンスを受けた時刻をアドオンが記録し、コミュニティの観察値（出現から10〜15分で公開、
公開から約30分で消滅）を「目安」として添えています。公式の数値ではありません。次の出現時刻は
不定なので予測しません。入場前から出ていた場合は「経過不明」になります。自分が所持している
間は、飢餓メーターの残量も表示します。

拠点数と得点はゲームのキャンペーン画面が使っているものと同じ数字です。得点は累計で、
キャンペーンの勝敗を決めるスコアです（累計なので、いまの勢力より遅れて動きます）。
「攻撃中」の列だけは対応するAPIが無いため、このアドオン自身の走査で数えています。
マップを開かずに画面へ出す価値があるのは、この列です。

帝都のキャンペーンでは、拠点・得点・攻撃中の3列を表示しません。帝都に砦は無く、地区で
争われるため、その3つはゼロが並ぶだけだからです（陣営と混雑度は表示します）。

シロディールの外や監視オフのときは表示を消します。得点だけ正しくて「攻撃中」が
止まったまま残るのが一番良くない状態だからです。

■ 全体マップ（任意・初期はオフ）

シロディール全体の地図を画面の隅に表示できます。

・砦・前哨・村・巻物神殿・国境砦を、ゲーム自身のピンの絵で所有陣営の色に表示します。
　持ち主が替われば色も替わります。
・攻撃を受けている拠点には、ワールドマップと同じ攻撃マークを背後に表示します。
・巻物とヴォレルドルングを今ある場所に、自分の位置をカメラの向きの矢印で表示します。
・大きさ・ピンの大きさ・不透明度・表示位置・重なり順を設定できます。

ゲームのワールドマップは借りず、地図のタイルとピンから自前で組み立てています。そのため
ミニマップ系のアドオンと同時に使っても、互いの表示を奪い合いません。表示はシロディールに
いるときだけで、メニューを開いている間は隠れます。

■ 色

通知5種類それぞれの色を設定できます。初期状態では画面表示もチャット欄と同じ色を使うため、
管理する色は1組だけです（チャット欄側を変えると画面表示も追従します）。

別々にすることもできます。チャット欄は暗い背景の上、画面表示はそのとき見ている景色の上に
出るため、片方で読める色がもう片方で消えることがあるからです。「画面表示の色」の行を操作
すると、その時点で追従はオフになります（それが「別にしたい」という意思表示のため）。
/pbalert colour follow on で、選んだ色を保持したまま元の追従状態に戻せます。

設定パネルは12色から選択、チャットコマンドでは16進コードも指定できます。

■ 動作の特徴

・読むだけです。何も送信せず、ゲーム側の状態も一切書き換えません。アドオンを外せば
　完全に元通りです。
・シロディールの外では何も動きません。走査が空振りするのではなく、タイマー自体を
　停止します（ゾーン移動のたびに判定し、戻れば再開します）。セッションの大半は
　シロディールの外なので、その間このアドオンのコストはゼロです。
・分からないときは黙ります。拠点APIが無いクライアントではタイマーを起動せず、
　ゾーン外では監視状態を破棄し（戻ってきたら読み直します）、一覧から消えた拠点は
　終了通知を出さずに忘れます。どう終わったか分からないものに答えを作らないためです。
・いま自分がいるキャンペーンの拠点だけを見ます。クライアントは同じ拠点を「いるところ」
　と「ホーム設定」の2件で報告してくるため、ここを絞らないと通知が2重になり、
　自分がいないキャンペーンの攻城戦まで流れてきます。
・画面表示の作成に失敗しても、通知はチャット欄に出続けます。/pbalert がその旨を
　表示します。

■ 注意

・経過時間は「アドオンが攻撃を見つけてから」の時間です。攻撃中の拠点があるところへ
　入場した場合、「3:20経過」は監視して3分20秒という意味になります。
・攻撃している人数や誰かは分かりません。ゲームがその情報を出していません。

■ 設定

設定 → アドオン設定 → PB's CyrodiilAlert
（LibHarvensAddonSettings があれば表示されます。無くてもアドオンは動作し、
　チャットコマンドですべて操作できます）

チャットコマンド
　/pbalert                          監視状況と通知件数
　/pbalert list                     報告されている拠点の一覧（所有陣営・攻撃状態つき）
　/pbalert on | off                 全体スイッチ
　/pbalert every <秒>               監視周期（1〜60）
　/pbalert repeat <秒>              攻撃継続中の再通知まで（15〜600）
　/pbalert keeps | towns | resources | districts  on | off   監視対象
　/pbalert offense on | off         敵拠点での戦闘も通知
　/pbalert offense ours on | off    自陣営の攻城兵器がある拠点だけ通知
　/pbalert scrolls on | off         巻物の受け渡しを通知
　/pbalert log window|chat|both     アドオンの出力先
　/pbalert log front|normal|back    出力ウィンドウの重なり順
　/pbalert log clear                出力ウィンドウを空にする
　/pbalert hud on | off             画面表示
　/pbalert hud <通知> on | off      その通知を画面に出すか
　/pbalert colour <通知> chat | hud <色名または RRGGBB>       色の変更
　/pbalert colour follow on | off   画面表示にチャット欄の色を使うか
　/pbalert map on | off             全体マップ
　/pbalert map probe                全体マップが使っている値を表示
　/pbalert board                    戦況をチャット欄に表示
　/pbalert board on | off           戦況を画面に表示
　/pbalert board front|normal|back  戦況表示の重なり順
　/pbalert board pop icon | text    人口をアイコンで出すか文字で出すか
　/pbalert test                     各通知を1回ずつ表示（見た目の確認）
　/pbalert ava on | off             AvAゾーンにいるときだけ監視
　/pbalert existing on | off        入場時にすでに攻撃中の拠点も通知
　/pbalert banner on | off          ログイン時に状態を表示
　/pbalert forget                   監視状態を破棄してやり直す
　/pbalert reset                    設定をすべて初期化
　（/pbca でも同じ）

## Description (EN)

Cyrodiil already knows a keep is being attacked, and tells you by putting crossed swords on
the campaign map — which you have to open to see. If you are riding, farming a resource or
fighting two keeps away, the siege that takes your home keep starts and finishes in silence.
This add-on reads the same data the map draws from, on a timer, and says it in chat — and on
screen if you want it there.

■ Four alerts

- Red: one of your holdings is under attack, repeated at your chosen interval while it lasts.
- Blue: the attack is over and the holding is still yours — defended.
- Yellow: it changed hands — lost, and which alliance took it.
- Green: a fight has started at a holding another alliance owns (optional, off by default).
  If it becomes yours, blue again — taken.

Lost is read off the owning alliance, not off the attack flag. A keep that has just been
flipped is normally still under attack, because the side that lost it is already hitting it
back; waiting for the flag to clear would report the loss late or not at all.

■ Its own window

Everything the add-on says goes into a window of its own by default -- alerts, command replies,
all of it -- so it never fills your chat window. Console has no tabs to sort it into.

- Window, chat window, or both.
- Width, height, text size, lines kept, background darkness, position and draw order (in front
  of everything, normal, behind everything) are all settings, separate from the summary's.
- Newest line at the top: the one arrangement a wrapped line cannot push out of the window.
- The window has no mouse, so it can never take a click away from the game. That is also why
  its size and place are settings rather than a drag handle.
- Outside Cyrodiil and the Imperial City the window is hidden, not merely empty, and comes back
  empty. Output goes to chat while it is away.
- If the window cannot be created, everything goes to chat instead. The add-on will not swallow
  its own output.

■ The watch

- Checks every 1–60 seconds (5 by default). One pass reads a few dozen values the client
  already holds, with no server traffic.
- A standing attack is repeated after 15–600 seconds (60 by default), so a long siege does not
  fall silent and a short one does not become noise.
- Choose what to watch: keeps and outposts (on), towns (on), resources (off), Imperial City
  districts (off). Resources are flipped constantly by single players and would bury the
  alerts worth riding for.
- Bridges, milegates and scroll gates are never watched. They are structures inside the fight,
  not holdings that can be owned.

■ About who is attacking

The client only says that a holding is under attack. There is no API that returns the
attacking alliance, so the green line says a fight has started — not that you started it. In a
three-way campaign it may well be the other two going at each other.

Where the game keeps a siege count, the line also says how many siege weapons your own
alliance has standing there. Your siege at a holding you do not own is a push of yours. It is
evidence rather than proof — an attack does not need siege at all — so it is reported as the
count it is.

By default only holdings that pass that test are reported, which is as close as the client can
be made to get to "only the fights my alliance started". The cost: an attack pressed without
siege is never reported, nothing is said in the first moments of a push before the siege goes
down, and resources, towns and districts — which the game keeps no siege count for — are never
reported at all while it is on. Switch it off and every fight at an enemy holding is reported,
without any claim about whose it is.

It filters the line, not the watch. The holding becoming yours is still reported, and a fight
that becomes yours later gets its line the moment your siege goes up.

■ Elder Scrolls

When a scroll moves, the line says who moved it:

  Someone (Aldmeri Dominion) has taken Ghartok from Chalman Keep.

Taken, picked up, captured, returned, dropped, and returned by the timer -- which names nobody,
because nobody did it. Six scrolls in a campaign and they change hands rarely, so it is quiet;
each line is one of the few things in Cyrodiil worth turning a raid around for. On by default.

These arrive as events rather than from the watch, so the checking interval does not apply. The
name is the display name on console and the character name on PC -- the same choice the game
makes for its own announcements.

■ On screen (optional, off by default)

Chat is a record you can scroll back through; the screen is where you notice something while
you are riding. The same alerts, shortened to what can be read at a glance.

- Typeface (five), size (14–64), outline (four, or none).
- Position (top centre, middle, bottom centre, top left, top right) plus a sideways and an
  up/down offset.
- How long each line stays (2–30 s). Three at once; a fourth pushes the oldest off.
- One switch per alert for whether it appears there (under attack and lost by default).
- A test button puts one of each up with made-up names, so the look can be judged without
  waiting for a siege.

Only faces the console UI already has loaded are offered: a face nothing else is drawing with
has to be built when it is used, and on console that build comes out of the memory every
add-on shares.

The window has the mouse switched off. It can never take a click away from the game
underneath it, which is also why the position is set from the panel rather than by dragging.

■ The campaign at a glance (optional, off by default)

A standing summary in a corner of the screen:

  Chalman
  > Ebonheart Pact  keeps 8  score 12,345  under attack 2  pop Medium
    Aldmeri Dominion  keeps 5  score 9,000  under attack 0  pop High
    Daggerfall Covenant  keeps 2  score 3,000  under attack 0  pop Low
    Volendrung: Aldmeri Dominion
    Emperor: Someone (Aldmeri Dominion)

Each line in its alliance's colour, yours marked, in score order. Its own switch, position, size
and draw order — in front of everything, normal, or behind everything, for when the corner you
want is one something else is already using. The typeface is shared with the alerts.

The population is the campaign selection screen's own estimate -- Low, Medium, High, Full, not a
headcount; the game publishes no player numbers. It is drawn as the game's own campaign-browser
icon, with a setting to show the word instead. It arrives from a server request, so it is
refreshed every five minutes while the summary is up, and reads "-" until the first answer.

Volendrung is listed while it is out, with the alliance holding it -- unclaimed if nobody does,
and said plainly if it is you. **The player carrying it cannot be named:** the game does not
hand that to an add-on and does not show it itself. The scrolls are the exception, not the rule.

Volendrung also gets a clock: how long since it spawned, was revealed or left, with a forecast
from the community's observed figures (revealed 10-15 min after spawning, gone about 30 min
later) marked "about". The game publishes no times and its announcements carry none, so these
are the add-on's own stopwatch -- and "time unknown" if it was already out when you arrived. The
next spawn is at no fixed time and is not forecast. While you carry it, the hunger meter's
remainder is shown.

Holdings and scores are the campaign's own numbers, the ones the game's campaign screen shows.
The score is cumulative — it is what decides the campaign, so it lags the current situation.
The under-attack column has no API behind it and is counted off this add-on's own pass; it is
the column that makes the summary worth having on screen instead of opening the map.

In an Imperial City campaign the keeps, score and under-attack columns are dropped -- there are
no keeps there and the campaign is scored on districts, so all three would read zero. The
alliance and how busy it is are what remain.

Outside Cyrodiil, or with the watch switched off, it takes itself down: correct scores beside a
frozen under-attack column is the worst of the three possible states.

■ The whole of Cyrodiil (optional, off by default)

An overview map in a corner: every keep, outpost, town, scroll temple and border keep in the
game's own pin art for its owner, the attack burst behind any keep under attack, the scrolls and
Volendrung where they are, and you, facing where the camera faces. Size, pin size, opacity,
position and draw order are settings.

It does not borrow the game's world map -- it is drawn from the map's own tiles and pins -- so it
runs alongside a minimap add-on instead of taking the world map away from it. Cyrodiil only,
and hidden whenever a menu is up.

■ Colours

Every alert's colour can be set. By default the screen uses the chat colours, so there is one
set to keep: recolour an alert for chat and the on-screen line follows. They can be split —
chat sits on a dark window and the screen sits on whatever you are looking at, so a shade that
reads well on one can vanish on the other. Choosing a screen colour is how you ask for that, and
it switches the following off. Twelve in the panel, or any hex code through the chat command.

■ How it behaves

- It only reads. Nothing is sent, nothing in the world is changed, and removing the add-on is
  a complete undo.
- Outside Cyrodiil nothing runs. Not an idle timer -- no timer. It is stopped on the way out and
  started on the way back in, so the add-on costs nothing for the part of a session spent
  anywhere else.
- When it cannot be sure, it says nothing. No keep API: the timer never starts. The watch is
  cleared when it stops, so coming back re-reads reality. A holding that drops out of the keep
  list: forgotten without an ending, because there is nothing left to report on.
- It watches the campaign you are standing in. The client reports the same keep twice, once
  for that campaign and once for the one you are homed to; without filtering, every alert
  would arrive twice and sieges in a campaign you are not in would arrive at all.
- If the on-screen window cannot be created, alerts still go to chat and /pbalert says so.

■ Notes

- The clock on an alert starts when the add-on first saw the attack, not when the attack
  began. Zone in on a siege in progress and "3:20 so far" means three minutes twenty of
  watching.
- It cannot tell you who is attacking or how many. The game does not offer that.

■ Settings

Settings → Add-On Settings → PB's CyrodiilAlert
(shown if LibHarvensAddonSettings is installed; without it the add-on still works and the chat
command does everything)

Chat commands:
  /pbalert                          what is watched, and what it has alerted on
  /pbalert list                     every holding reported, with owner and attack state
  /pbalert on | off                 master switch
  /pbalert every <seconds>          how often to check (1-60)
  /pbalert repeat <seconds>         before a standing attack is said again (15-600)
  /pbalert keeps | towns | resources | districts  on | off
  /pbalert offense on | off         also report fights at enemy holdings
  /pbalert offense ours on | off    only where your own siege is standing
  /pbalert scrolls on | off         report Elder Scrolls being carried
  /pbalert log window|chat|both     where the add-on says things
  /pbalert log front|normal|back    where the output window sits in the stack
  /pbalert log clear                empty the output window
  /pbalert hud on | off             the on-screen display
  /pbalert hud <alert> on | off     whether that alert appears on screen
  /pbalert colour <alert> chat | hud <name or RRGGBB>
  /pbalert colour follow on | off   whether the screen uses the chat colours
  /pbalert map on | off             the overview map
  /pbalert map probe                what the map is working with
  /pbalert board                    print the campaign summary in chat
  /pbalert board on | off           keep it on screen
  /pbalert board front|normal|back  where it sits in the stack
  /pbalert board pop icon | text    population as an icon or as a word
  /pbalert test                     one of each alert, to judge the look
  /pbalert ava on | off             check only while in an AvA zone
  /pbalert existing on | off        report attacks already in progress when you zone in
  /pbalert banner on | off          print the state at login
  /pbalert forget                   forget what is being watched and start again
  /pbalert reset                    every setting back to default
  (/pbca is the same command)
