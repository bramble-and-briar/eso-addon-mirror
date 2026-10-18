# Store listing copy

Text for the Bethesda.net / ZOS Console AddOn Uploader entry. Plain text, no markdown -- paste as-is.
The **name** field is what the in-game add-on browser shows, so it must read `PB's FurnitureEditor`
there; `## Title` in the manifest does not reach that screen.

---

## Name

PB's FurnitureEditor

## Overview (JP)

ハウジングで「リンクされた家具」を、ほかの自分の家へコピー／移動します。編集画面でリンク家具に照準を
合わせて ○ でコピー、□ でカット。あとは自分のどの家でも、クイックスロットのホイールに出る
「ペースト」「ムーブ」を選ぶだけで、カーソルが指している床の位置に、リンクごと置き直せます。

## Overview (EN)

Copies or moves linked furnishings from one of your houses into another. In the housing editor, aim at
a linked furnishing and press circle to copy or square to cut. Then, in any house of yours, pick Paste
or Move on the quickslot wheel and the whole group, links included, is set down on the floor where
your cursor points.

---

## Description (JP)

リンクで組んだ家具（テーブルとその上の小物、本棚と本、噴水のまるごと）は、作るのに時間がかかる
のに、ほかの家へ持っていく方法がゲームにありません。このアドオンは、リンクされた家具のまとまりを
読み取り、別の家で同じ構成を置き直して、リンクも付け直します。

■ 使い方（コントローラーのみで操作できます）

1. 家の編集画面で、リンクされた家具に照準を合わせます。パレット（× 編集 / △ 精密編集 / L3 リンク
   が出ている場所）に「○ コピー」と「□ カット」が増えます。
2. ○ でコピー。リンクのまとまり全体がクリップボードに入ります。
   □ でカット。同じことをして、その家からは家具がなくなります（家具は手持ちのバッグに戻ります）。
3. 編集画面を出て、自分のどの家でも構いません。移動先の家を指定する必要はありません。
4. クイックスロットのボタンを長押しすると、ホイールの末尾に「ペースト」（コピーの場合）または
   「ムーブ」（カットの場合）が増えています。選んでボタンを離すと実行されます。
5. 実行が終わるとホイールの項目は消え、元のゲームのホイールに戻ります。

注意：□ は編集画面では元々「ブラウズ」のボタンです。同じキーに2つのボタンは置けないため、
リンク家具に照準を合わせている間だけ「カット」になり、それ以外のときは今までどおり「ブラウズ」です。
ブラウズを使うときは、壁やリンクされていない家具を見てください。

■ 置く位置

/pbfe position で切り替えます。
・aim（既定）：カーソルが指している床の位置。ホイールのボタンを離した瞬間に確定します。
・here：立っている場所。
・same：元の座標。家ごとに座標が違うため、元の家へ戻す（カットの取り消し）ときや、間取りが同じ家の
　ときだけ正確です。
カーソルが床を指していない（水平・上向き・遠すぎる）などで読み取れないときは、自動で「立っている
場所」に置き、その旨をチャットに表示します。何も起きずに終わることはありません。
高さは up 50（センチ）で上げられます。置いたあとは、グループ全体がリンクされているので、根元の
家具を動かせば全体が動きます。

■ 家具について（コピーは「増やす」操作ではありません）

家具は置くとバッグから消えます。コピーして貼るには、同じ家具が手元に必要です。
バックパック、銀行、サブスクリプション銀行、ハウス倉庫、家具保管庫の中から探します。盗品は
数えません。足りないときは「どの家具があといくつ足りないか」を表示し、全体は置かずに止まります
（force を付けると、置ける分だけ置きます）。コレクティブル家具はバッグではなく所持コレクション
から置きます。
カットは、家具をバッグに戻したあとに貼る操作です。実行前にバッグの空きを（積み重ねを考慮して
スロット数で）確認し、確実に入らない場合は始めません。まだ見たことのない種類の積み重ね数だけは
分からないため、その場合は「最低○〜最大○スロット」と幅で表示し、途中でバッグが満杯になったら安全に
止まって（失われるものはありません）、空きを作ってから、残っている家具に□（カット）をもう一度押す
（または「cut resume go」）と続きから取り出せます。積み重ならない家具は、コピー時にアイテムリンクから
判定し、1個につき1スロットとして正確に数えます。カットの完了・中断・拒否や貼り付けの結果は、チャットの
ほかに画面にも表示します（エディタ画面ではチャットが見えないため）。
カットしたものを貼り終わるまでは、エディタからの新しいコピー／カットは受け付けません
（家具の行き先の記録が、そのクリップボードだけになるため）。
ペーストでクリップボードの家具をすべて置き終えると、クリップボードは自動で空になります
（使い終わったコピーが残って、うっかり貼ってしまうことを防ぐため）。置けなかったものがある場合は
残り、何個置けなかったかを表示します。同じものを何度も貼りたいときは、「/pbfe save 名前」で保存して
おき、貼る前に「/pbfe load 名前」で呼び出してください。

■ 安全のために

・貼り付けは、まず確認だけを表示します（/pbfe paste）。置く家具・足りない家具・リンクの数が出て、
　何も置きません。go を付けて初めて実行します。
・/pbfe undo で、直前の貼り付けで置いた家具を取り戻せます。/pbfe stop でいつでも止められます。
　途中で止めても、置いた分は記録されるので undo できます。
・各家具は、置いたあとに位置を読み戻し、ずれていれば1回だけ補正します。リンクは全部置いてから
　付け、付いたかどうかを確認します。
・カットが途中で止まっても、元に戻せます（/pbfe paste same go で、外した分だけ元の位置に戻す）。
・サーバーの返事を1件ずつ待ちながら進めます（/pbfe speed で間隔を調整）。戦闘中や、家具数の
　上限などサーバーが拒否する場合は、ゲーム自身の文言を表示して止まります。

■ クイックスロットのホイールについて

ホイールに足す項目は、貼り付け待ちがあるときだけ、自分の家の中だけ、戦闘中以外だけです。
最大2項目（ペースト／ムーブ）で、他のホイール（エモート・メメント・ツール）は触りません。
ゲームの関数を横取りするフック（ZO_PreHook / ZO_PostHook）は使っていません。ホイールの項目の
追加にだけ、ゲームが用意している SecurePostHook を使い、最初に待機項目ができたときに一度だけ
設定します。
SecurePostHook が使えない場合や、内部で例外が出た場合は、その場で自分を止めて理由を表示し、
ホイールは元のゲームのものに戻ります。/pbfe menu off でいつでも止められます。
編集画面の ○ コピーは、ゲームのボタン一覧にデータを1つ足しているだけです。□ は、ブラウズの
ボタンの名前と処理を差し替えて、リンク家具に照準を合わせているときだけカットとして動かします
（それ以外では元の処理をそのまま呼びます）。/pbfe editor off で取り除くと、ブラウズは完全に元へ
戻ります。

■ 予約と、コマンドでの操作

・/pbfe reserve copy 1 to 2 aim go ：「家2に入ったら、これを貼る」を事前に決めておけます
　（複数可）。go を付けると、入って10秒後に自動で始まります（/pbfe stop で中止）。
・/pbfe paste to 2 same go ：家2へ移動して、そのまま貼ります。
・/pbfe houses で、自分の家の一覧（番号つき）が出ます。

■ 制限

・コピーできるのは、自分が編集できる家だけです。貼り付けとカットは、自分が所有する家だけです。
・特別家具・課金（コレクティブル）家具・木枠箱の家具・設計図で作った家具が混在したグループも扱えます。
　家具は「通常／特別／コレクティブル／特別コレクティブル」の4つの上限のどれかに数えられ、プランに
　それぞれの上限と必要数が表示されます。ある種類の上限に達しても、貼り付けは止まらず、その種類だけを
　置かずに、ほかの家具は置き続けます（実機では未検証です）。
・動く家具の「経路データ」はコピーされません（家具そのものはコピーされます）。
・リンクの数が多いグループ（1つの家具に最大50個の子、子にもさらに子を付けられます）は、数百回の
　リクエストになります。失敗した配置・リンク・取り外しは自動で数回やり直し、サーバーの応答が遅れて
　届いた家具は二重に置かずに取り込みます。1つの家具が子を受け付けなくなった場合は、その家具が
　すでに持っている兄弟の家具の下にリンクして、グループは一つのまま保ちます（この動作は実機では
　未検証です）。
・回転（rot 90）は、先に /pbfe calib で、ゲームの回転の向きを家具の実測から調べます。調べて
　いないあいだは、回転つきの貼り付けは拒否されます。
・床の高さは「立っている階」です。テーブルの上のような高さは、up で指定します。
・コンソール専用に作っていますが、ゲームパッドのインターフェースで使う機能です。

■ 進捗バー

カット・ムーブ・ペースト・取り消しの進み具合を、画面の前面にバーで表示します（初期位置は上中央）。
編集画面ではチャットが見えないためです。「確認できたぶん」（取り出せた・置けた・リンクできた数）で
進み、失敗があればバーは満タンにならず、終わりに「完了（失敗 3）」と赤で表示します。ある程度進むと
残り時間の目安も出ます。「/pbfe progress on|off」で切り替え、「top|center|bottom」で位置、「test」で
見た目の確認ができます。設定メニューにもスイッチとテストボタンがあります（実機では未確認です）。

■ 設定メニュー

LibHarvensAddonSettings（任意）があると、設定メニューに「PB's FurnitureEditor」の項目が出ます。
「コピー／カットをクリア」「すべての状態をクリア」「実行中の処理を止める」「保持している内容を表示」
のボタンがあり、アドオンが保持しているコピー・カットの状態を、コマンドを打たずに忘れさせられます。
まだ貼り付けていないカットは、家具の行き先の記録がクリップボードだけなので、10秒以内にもう一度
押すまで消しません。家やバッグの家具、保存したクリップボードには触れません。
ライブラリがなくても、/pbfe reset で同じことができます。

■ 現在の状態について（試験版です）

読み取り（リンクの検出）、編集画面の ○ コピー表示は実機で確認済みです。家具の配置・リンクの
設定・取り外し・家への移動・ホイールへの項目追加・カーソル位置の読み取りは、ゲームが用意している
関数を使っていますが、動作の確認を進めている段階です。うまく動かない場合は、/pbfe api と
/pbfe state の結果、画面に出たメッセージをお知らせください。診断用に /pbfe probe place、
/pbfe probe link、/pbfe aim、/pbfe kind があります。

■ チャットコマンド

/pbfe                              コマンド一覧
/pbfe list                         この家のリンクのまとまり（近い順）
/pbfe copy <n>|near|sel|all        コピー（カットは /pbfe cut）
/pbfe cut <n>|near|sel|all|resume [go]  コピーして、この家から外す（確認のあと go）
/pbfe show / clear                 クリップボードの内容／空にする
/pbfe reset [all] [force]          コピー／カットの状態を忘れる（all: 取り消し用の記録・予約・移動も）
/pbfe save|load|drop <名前> , saved  名前を付けて保存・呼び出し
/pbfe paste [to N] [aim|here|same] [rot 90] [up 20] [force] [go]  確認、go で実行
/pbfe undo / stop                  取り消し／中断
/pbfe position [aim|here|same]     ホイールの貼り付け位置
/pbfe houses                       自分の家の一覧
/pbfe reserve copy|cut … to <h> …  貼り付けの予約
/pbfe reservations [run|drop|load|retry]  予約の一覧と操作
/pbfe menu [on|off]                クイックスロットのホイールの項目
/pbfe editor [on|off]              編集画面の ○ コピー／□ カット
/pbfe api                          必要な関数が使えるかの確認
/pbfe state / where / aim / kind / items  状態・位置・カーソル位置・種類・手持ち家具の診断
/pbfe calib                        回転の向きを調べる（回転つき貼り付けの前に）
/pbfe probe place|link <枠>        1個だけ置いて外す／2個を置いてリンクして外す（試験用）
/pbfe speed <ms>                   リクエストの間隔（既定450）

---

## Description (EN)

A build made of linked furnishings (a table with everything on it, a bookcase with its books, a whole
fountain) takes an evening to make, and the game has no way to carry it to another house. This add-on
reads a group of linked furnishings, sets the same arrangement down in another house, and links it
again.

HOW TO USE (controller only)

1. In the housing editor, aim at a linked furnishing. The palette beside the reticle (where x Edit,
   triangle Precision Edit and L3 Link appear) gains "circle Copy" and "square Cut".
2. Circle copies: the whole link group goes on the clipboard. Square cuts: the same, and the group
   leaves this house (the furnishings go back into your bag).
3. Leave the editor and go to any house of yours. There is no destination to choose.
4. Hold the quickslot button. The wheel has gained Paste (after a copy) or Move (after a cut) at its
   end. Point at it and let go.
5. When it is done the entry disappears and the wheel is the game's again.

Note: square is already "Browse" in the editor, and the game keeps only one button per key. So square
is Cut only while a linked furnishing is in the reticle; at any other time it is Browse, as before. To
browse, look at a wall or an unlinked piece. Cut is drawn on the palette beside Copy only: the button bar
along the bottom of the screen shows no "Cut", and Browse's button there is back when you look at something else.

WHERE IT LANDS

/pbfe position chooses:
- aim (the default): the floor point where the cursor points, taken the moment you let go of the button.
- here: where you stand.
- same: the original coordinates. Coordinates differ from house to house, so this is exact only in the
  house the group came from (putting a cut back) or in a house with the same layout.
If the cursor cannot be read (pointing at the horizon, upward, or too far), the group is placed where
you stand instead and the chat says so. A pick never ends in "nothing happened". "up 50" (centimetres)
lifts the group; once it is down, moving its root with the editor moves all of it, since it is linked.

FURNISHINGS (A COPY IS NOT A DUPLICATE)

Placing a furnishing takes it out of a bag, so a paste needs the items in hand. They are looked for in
your backpack, bank, subscriber bank, house chests and the furnishing vault. Stolen items do not count.
When something is short, it says which and how many, and places nothing (add "force" to place what can
be placed). Collectible furnishings are placed from your collection, not from a bag.
A cut puts the furnishings in your bag first, then pastes them. It counts the bag's free slots before it
starts, allowing for stacking (a piece joins a stack of its kind that has space), and will not start if it
is certain not to fit. A kind the add-on has never seen has an unknown stack size, so the preview shows a
range; if the bag does fill, the cut stops safely (nothing is lost) and `cut resume go` finishes it once
you have made room. Until a cut has been pasted, further copies and cuts from the
editor are refused, because that clipboard is the only record of where its furnishings go.
A cut that stopped part way (usually a full bag) carries on when you press Cut again on a furnishing still
standing; items that do not stack are counted one slot each, read from the item link when copied; and the
headlines (cut done, stopped, refused, paste result) are also shown on the screen, since the chat is not in
view in the editor.
When a paste has placed everything on the clipboard, the clipboard is emptied, so a used copy does not
sit there to be pasted by mistake. If something could not be placed it stays, and the message says how
many were left. To paste the same thing again and again, save it under a name (/pbfe save <name>) and
load it (/pbfe load <name>) before each paste.

PROGRESS BAR

A bar over the screen shows how far a cut, move, paste or undo has got (top centre by default), because the chat is
not in view in the housing editor. It counts what has been confirmed (out of the house, placed, linked), so a failure
leaves it short of full, and the end says "done, 3 failed" in red. A rough time left appears once there is something
to go on. /pbfe progress on|off, top|center|bottom, test. The add-on settings have a switch and a test button. Not
yet checked on a console.

SETTINGS MENU

With LibHarvensAddonSettings (optional) there is a "PB's FurnitureEditor" page in the add-on settings with
buttons to clear the copy/cut the add-on is holding, clear everything it holds for a paste (also the undo
record, reservations and a started trip), stop what is running, and show what is held. A cut that has not
been pasted is asked twice, because its clipboard is the only record of where its furnishings go. Nothing
touches furnishings in a house or a bag, or saved clipboards. Without the library, /pbfe reset does the same.

SAFETY

- A group can mix kinds (crafted items, crate items, special furnishings, Crown Store collectibles). The
  plan shows each of the house's four limits against what the group needs, and a "no room" answer stops
  only that kind, not the paste. Not yet checked on a console.
- Big link groups (ESO allows 50 children per furnishing, and children can have children) are hundreds of
  requests. What fails for a reason that may pass is asked for again, in rounds; an answer that arrives late
  is taken in rather than placed twice; and if a furnishing will take no more children, the rest are
  linked under a sibling so the group stays one tree. Not yet checked on a console.
- A paste shows its plan first (/pbfe paste): what would be placed, what is short, how many links.
  Nothing is placed until you add "go".
- /pbfe undo takes back what the last paste placed; /pbfe stop stops at any time. What was placed
  before a stop is recorded, so it can still be undone.
- Each furnishing is read back after it is placed and nudged once if it landed off its mark. Links are
  made after everything is placed, and each is checked.
- A cut that stops half way can be put back (/pbfe paste same go places only what was taken out) or
  finished (/pbfe cut resume go).
- Requests go to the server one at a time, with a pause between them (/pbfe speed). If the server
  refuses (combat, a furnishing limit, a bad position), it stops with the game's own words.

THE QUICKSLOT WHEEL

Entries are added only while a paste is waiting, only in a house you own, and never in combat: at
most two (Paste, Move). The emote, memento and tool wheels are left alone. It does not use the
hooks that intercept the game's functions (ZO_PreHook / ZO_PostHook); the only hook is SecurePostHook,
the game's own, installed once when the first paste is waiting. If it is not available, or anything unexpected happens inside it, the add-on
stops itself, says why, and the wheel is the game's again. /pbfe menu off switches it off.
In the editor, Copy is one entry added to the game's button list. Square works by wrapping the
Browse button's action so that it cuts only while a linked furnishing is in the reticle (at any other time it
calls the original, unchanged); its label is not changed. /pbfe editor off removes both and Browse is exactly
as it was.

RESERVATIONS AND COMMANDS

- /pbfe reserve copy 1 to 2 aim go: decide now that group 1 is pasted when you enter house 2 (several
  can wait). With "go" it starts by itself ten seconds after you arrive (/pbfe stop cancels it).
- /pbfe paste to 2 same go: travel to house 2 and paste there.
- /pbfe houses lists your houses, numbered.

LIMITS

- You can copy only from a house you can edit; you can paste and cut only in a house you own.
- Path data (furnishings that follow a path) is not copied; the furnishing is.
- Turning a group (rot 90) needs /pbfe calib first, which works out the game's rotation order from
  the furnishings already placed. Until then a turned paste is refused.
- The floor is the level you stand on; use "up" for a height such as a table top.
- Built for the console; the editor buttons and the wheel are for the gamepad interface.

STATE OF THE ADD-ON (A TEST BUILD)

Reading the house (including links) and the circle Copy button in the editor have been checked on a
real console. Placing, linking and removing furnishings, travelling to a house, adding the wheel
entries and reading the cursor position use functions the game provides, but they are still being
checked. If something does not work, please send the results of /pbfe api and /pbfe state and the
message that appeared. For diagnosis there are /pbfe probe place, /pbfe probe link, /pbfe aim and
/pbfe kind.

CHAT COMMANDS

/pbfe                              list the commands
/pbfe list                         the linked groups in this house, nearest first
/pbfe copy <n>|near|sel|all        copy (cut is /pbfe cut)
/pbfe cut <n>|near|sel|all|resume [go]  copy, then take it out of this house (a preview, then go)
/pbfe show / clear                 what is on the clipboard / empty it
/pbfe reset [all] [force]          forget the copy/cut (all: also the undo record, reservations, a trip)
/pbfe save|load|drop <name>, saved keep clipboards under a name
/pbfe paste [to N] [aim|here|same] [rot 90] [up 20] [force] [go]  plan; "go" does it
/pbfe undo / stop                  take back the last paste / stop what is running
/pbfe position [aim|here|same]     where the wheel pastes
/pbfe houses                       your houses, numbered
/pbfe reserve copy|cut ... to <h> ...  decide a paste now, do it on arrival
/pbfe reservations [run|drop|load|retry]  what is waiting
/pbfe menu [on|off]                the quickslot wheel entries
/pbfe editor [on|off]              circle Copy / square Cut in the editor
/pbfe api                          do the functions this add-on needs exist, and are they public
/pbfe state / where / aim / kind / items  diagnostics: state, position, cursor point, item or collectible, what you hold
/pbfe calib                        work out the rotation order (before a turned paste)
/pbfe probe place|link <slot>      place one item and take it back / place two, link, unlink, take back
/pbfe speed <ms>                   pause between requests (default 450)
