# Store listing copy

Text for the Bethesda.net / ZOS Console AddOn Uploader entry. Plain text, no markdown —
paste as-is. The **name** field is what the in-game add-on browser shows, so it must read
`PB's ChatWindowCustomizer` there; `## Title` in the manifest does not reach that screen.

---

## Name

PB's ChatWindowCustomizer

## Overview (JP)

HUDのチャットウィンドウの位置・大きさ・文字サイズを変更します。右下に固定されている
ウィンドウを好きな場所へ動かし、幅と高さを自由に変え、メッセージの文字サイズを
10〜48の間で細かく調整できます。20秒で消えないよう常に表示させることも、
メニュー中も表示させることもでき、他のUIとの前後関係も選べます。設定中はプレビュー枠で仕上がりを確認できます。

## Overview (EN)

Moves and resizes the HUD chat window and changes the size of its text. Put the window anywhere
on screen, make it as wide or tall as you like, and set the message text size anywhere from 10 to
48. It can also stay on screen instead of fading out after 20 seconds, show in menus as well as on
the HUD, and be drawn under or over the rest of the interface. A preview frame shows the result while you adjust it.

---

## Description (JP)

コンソール版のHUDチャットウィンドウは、画面右下に固定された位置と大きさで表示され、
文字サイズも小／中／大の3段階しか選べません。このアドオンは、それらを自由に調整できる
ようにします。

■ 位置

・基準の角（左上／右上／左下／右下）
　位置をどの角から測るかを選びます。ウィンドウも同じ角で固定されるため、大きさを変えた
　ときの伸びる方向もこれで決まります。右下（ゲーム標準）なら、高さを増やすとウィンドウは
　上へ伸び、入力欄の位置は変わりません。
　角を切り替えてもウィンドウ自体は動きません。
・左右の端からの距離／上下の端からの距離

■ 大きさ

・幅（200〜画面の幅）
・高さ（100〜画面の高さ）
　ゲーム本体の制限（幅300〜550、高さ170〜380）を超えて設定できます。

■ 文字

・メッセージの文字サイズ（10〜48）
　初期値は、ゲームの小／中／大の設定で実際に描画されているサイズを実測した値です。
　入力欄は枠の高さが固定されているため、ゲーム本来のサイズのままです。

■ 表示

・ウィンドウを常に表示する
　ゲーム本体は最後の発言から20秒でチャットを最小化しますが、オンにするとHUD表示中は
　出続けます。入力欄も、チャットが動いている間にゲーム本体が出している状態と同じく表示されます。
　オフに戻すと、ゲーム本体の20秒のタイマーに任せます。
・メニュー中も表示する
　ゲーム本体はHUD上にしかチャットを描画しませんが、オンにするとマップやインベントリ
　などを開いている間も表示され、チャットを読めます（メニュー中の入力はできません）。
　「常に表示する」も一緒にオンになります。
・描画の階層（UIの後ろ／標準／UIの前）と、同じ階層内での順序（0〜200）
　ゲーム本体はHUDより前、操作ガイドやツールチップより後ろに描いています。
　何かがチャットに被る場合は「UIの前」を選んでください。

■ 特徴

・設定画面ではプレビューを表示します。
　チャットはHUD上でしか表示されないため、設定中はピンクの枠とサンプルのチャットで、
　ウィンドウの位置・大きさ・文字サイズをその場で確認できます。
・すべての項目はゲーム本来の値から始まります。
　動かすまでは一切変更を加えないため、入れただけの状態は入れていない状態と同じです。
・「初期設定に戻す」またはオフにすると、ゲーム本来の位置・大きさ・文字にそのまま戻ります。
・チャット機能そのものには手を加えません。
　ウィンドウの位置・大きさと文字の設定だけを書き換え、メッセージの送受信には一切
　関与しません。

■ チャットコマンド

/pbchatwin status　現在の設定と、実際の表示状態を表示
/pbchatwin pos 横 縦　位置
/pbchatwin size 幅 高さ　大きさ
/pbchatwin font サイズ　文字サイズ
/pbchatwin always on|off　常に表示
/pbchatwin menus on|off　メニュー中も表示
/pbchatwin tier low|medium|high　描画の階層
/pbchatwin level 数値　同じ階層内での順序
/pbchatwin reset　ゲーム本来の状態に戻す
（/pbcw でも同じです）

※設定画面の表示には LibHarvensAddonSettings が必要です。

## Description (EN)

On console the HUD chat window sits in the bottom right at one fixed size, and its text comes in
Small, Medium or Large. This add-on makes all of that adjustable.

■ Position

- Measured from: top left, top right, bottom left or bottom right. The window is held by that
  corner, so it also decides which way the window grows — from the bottom right (the game's
  own), a taller window grows upwards and the input line stays put. Switching the corner does
  not move the window.
- Distance from the side, and from the top or bottom.

■ Size

- Width from 200 to the width of the screen, height from 100 to the height of the screen — past
  the game's own limits of 300–550 by 170–380.

■ Text

- Message text size from 10 to 48. Starts at the size the game really draws for your Small /
  Medium / Large setting, measured. The input line keeps the game's size: its box is a fixed
  height.

■ Showing

- Keep the window on screen: the game minimises the chat 20 seconds after the last message; with
  this on it stays up while you are on the HUD, input line included. Switching it off
  hands the window back to the game's own timer.
- Show it in menus too: the game draws the chat on the HUD only; with this on it stays up in the
  map, the inventory and any other menu, for reading (not typing). Keeping the window on screen
  comes with it.
- Draw order: behind the interface, normal (the game's own), or in front of it, plus the order
  within that layer (0-200). The game draws the chat over the HUD but under keybind strips and
  tooltips, so pick "in front" if something covers it.

■ Also

- A preview in the settings panel: the chat is only drawn on the HUD, so a pink frame with
  sample chat shows where the window will be and how big the text is while you adjust it.
- Every setting starts at the game's own value, and nothing is changed until you move
  something.
- Reset, or switching it off, puts the game's own position, size and text straight back.
- The chat itself is not touched: only the window's place, size and text size are written, never
  anything to do with sending or receiving messages.

Chat commands: /pbchatwin (or /pbcw) status | pos <x> <y> | size <w> <h> | font <n> |
always on|off | menus on|off | tier low|medium|high | level <n> | reset

The settings panel needs LibHarvensAddonSettings.
