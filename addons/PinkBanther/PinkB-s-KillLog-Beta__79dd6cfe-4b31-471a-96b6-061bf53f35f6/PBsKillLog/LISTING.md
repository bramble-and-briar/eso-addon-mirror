# Store listing copy

Text for the Bethesda.net / ZOS Console AddOn Uploader entry. Plain text, no markdown —
paste as-is. The **name** field is what the in-game add-on browser shows, so it must read
`PB's KillLog` there; `## Title` in the manifest does not reach that screen.

---

## Name

PB's KillLog

## Overview (JP)

シロディールのPvPでプレイヤー同士のキルが起きた時のキルログだけを、専用のウィンドウに表示します。
ゲーム本体の「PvPキルフィード」（チャットへの出力）をオフにしていても表示されるので、
チャットを汚さずに戦況を確認できます。ウィンドウの位置・大きさ・文字サイズ・前後関係を
自由に変えられ、自分がキルした時にはテイルズ・オブ・トリビュートでカードを倒した時の
効果音を鳴らすこともできます。設定中はプレビュー枠で仕上がりを確認できます。

## Overview (EN)

Shows only the PvP player kill feed in Cyrodiil, in a window of its own. It works even when the game's
"PvP Kill Feed" option (kills in the chat) is turned off, so you can follow the fight without
filling the chat. Move and resize the window, change its text size and where it sits among the
other UI, and have the Tales of Tribute "card knocked out" sound play when the kill is yours. A
preview frame shows the result while you adjust it.

---

## Description (JP)

PvPで近くのプレイヤーが倒されると、ゲーム本体はそのキルフィードをチャットに流します。
このアドオンは、シロディールでのそのキルログだけを専用のウィンドウに表示します。チャットとは別に
表示できるため、キルログをチャットに出さない設定のままでも、戦況を一目で確認できます。

■ 表示

・シロディールで、プレイヤー同士のキルを表示します。
　帝都とバトルグラウンドのキルは表示しません（ゲーム本体のキルフィードはそこでも流れますが、
　このアドオンは無視します）。シロディール以外では、ウィンドウの文字も隠れます。
　文面・色・ランクアイコンはゲーム本体のキルフィードと同じで、言語設定に従います。
・ゲーム本体の「PvPキルフィード」の設定に関係なく動作します。
　このアドオンは、その設定を読むことも変更することもありません。
・同じキルが二重に通知された場合は、1行にまとめます。
・ウィンドウはHUDと、カーソルが使える画面（チャット入力中など）に表示され、マップや
　インベントリなどの全画面メニューでは隠れます。
　入力は一切受け取らないため、ゲームのボタン操作を邪魔しません。

■ 位置と大きさ

・位置 X / Y（画面の左上からの距離）
・幅（160〜画面の幅）
・高さ（48〜画面の高さ）
　いずれも5刻みで、コントローラーでも動かしやすくしています。

■ 文字

・フォントサイズ（12〜64）
　ランクアイコンも文字に合わせて変わります。書体はゲーム標準のものを使います。

■ レイヤー

・描画ティア（低／中／高）
　高いほど手前に描かれます。他のUIとウィンドウが重なる場合に選んでください。
・描画レベル（0〜100）
　同じティア内での前後関係の微調整です。

■ サウンド

・自分がキルした時に効果音を鳴らす（初期値はオン）
　キルフィードの撃破者が自分だった時に、テイルズ・オブ・トリビュートでカード
　（エージェント）の体力が0になった時の効果音を鳴らします。
　他のプレイヤーのキルや、自分が倒された時には鳴りません。シロディール以外でも鳴りません。
　オンにした時に一度鳴らして、音を確認できます。

■ 特徴

・設定画面ではプレビューを表示します。
　キルログはHUD上でしか表示されないため、設定中はピンクの枠とサンプルのキルで、
　ウィンドウの位置・大きさ・文字サイズをその場で確認できます。
・設定画面のメニューは、日本語クライアントでは日本語、それ以外では英語で表示されます。
・テストキルの追加とログの消去ができ、見た目を確認できます。
・ゲーム本体の設定やチャットには手を加えません。

■ チャットコマンド

/pbkl test　テストキルを追加
/pbkl clear　ログを消去
/pbkl reset　ウィンドウの位置・大きさ・文字・レイヤーを初期値に戻す
/pbkl preview　プレビュー枠の表示／非表示（HUD上でも使えます）
/pbkl sound [on|off]　キル効果音のオン／オフ（引数なしで切り替え）
/pbkl unlock　/pbkl lock　マウスでの移動・サイズ変更（マウスが使える環境のみ）

※設定画面の表示には LibHarvensAddonSettings が必要です。無くてもキルログは表示され、
　チャットコマンドで操作できます。

## Description (EN)

When a nearby player is killed in PvP, the game puts the kill in the chat. This add-on shows
only that kill feed from Cyrodiil, in a window of its own. Because it is separate from the chat, you can keep
the kill feed out of the chat and still see how the fight is going at a glance.

■ Showing

- Shows player kills in Cyrodiil. Kills in the Imperial City and in Battlegrounds are not shown
  (the game's own kill feed reports them too, but this add-on ignores them), and outside Cyrodiil
  the window's text is hidden. The wording, colours and rank icons are the game's own kill feed,
  in your language.
- It works whatever the game's "PvP Kill Feed" option is set to. The add-on neither reads nor
  changes that option.
- A kill that is announced twice is shown once.
- The window is drawn on the HUD and wherever the cursor is free (while typing in the chat, for
  example), and is hidden in full-screen menus such as the map and the inventory. It takes no
  input at all, so it never gets in the way of the game's buttons.

■ Position and size

- Position X / Y: distance from the top left of the screen.
- Width from 160 to the width of the screen, height from 48 to the height of the screen.
  Everything moves in steps of five, which is easier on a controller.

■ Text

- Font size from 12 to 64. The rank icons grow with the text. The typeface is the game's own.

■ Layer

- Draw tier: low, medium or high. Higher is drawn in front. Pick it if the window and another
  piece of the UI overlap.
- Draw level (0 to 100): fine adjustment within the same tier.

■ Sound

- Play a sound when you get the kill (on by default): when the killer in the kill feed is you,
  the Tales of Tribute sound for a card (agent) running out of health plays. It does not play
  for other players' kills, when you are the one defeated, or outside Cyrodiil. Switching it on plays the sound once
  so you can hear it.

■ Also

- A preview in the settings panel: the kill log is only drawn on the HUD, so a pink frame with
  sample kills shows where the window will be and how big the text is while you adjust it.
- The settings menu is in Japanese on a Japanese client and in English otherwise.
- Add a test kill or clear the log to see how it looks.
- The game's own settings and the chat are left alone.

■ Chat commands

/pbkl test — add a test kill
/pbkl clear — clear the log
/pbkl reset — put the window's place, size, text and layer back to the defaults
/pbkl preview — show or hide the preview frame (works on the HUD too)
/pbkl sound [on|off] — kill sound on or off (no argument flips it)
/pbkl unlock, /pbkl lock — move and resize with the mouse (only where a mouse is available)

The settings panel needs LibHarvensAddonSettings. Without it the kill log still shows and can be
controlled with the chat commands.
