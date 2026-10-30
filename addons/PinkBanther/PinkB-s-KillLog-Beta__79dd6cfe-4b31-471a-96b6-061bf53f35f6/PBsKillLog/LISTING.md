# Store listing copy

Text for the Bethesda.net / ZOS Console AddOn Uploader entry. Plain text, no markdown —
paste as-is. The **name** field is what the in-game add-on browser shows, so it must read
`PB's KillLog` there; `## Title` in the manifest does not reach that screen.

---

## Name

PB's KillLog

## Overview (JP)

シロディールと帝都のPvPでプレイヤー同士のキルが起きた時のキルログだけを、専用のウィンドウに表示します。
ゲーム本体の「PvPキルフィード」（チャットへの出力）をオフにしていても表示されるので、
チャットを汚さずに戦況を確認できます。ウィンドウの位置・大きさ・文字サイズ・前後関係を
自由に変えられ、自分がキルした時にはテイルズ・オブ・トリビュートでカードを倒した時の
効果音を鳴らすこともできます。自分のキル数と死亡数を日毎に記録し、合計バトル数と勝率から
軍隊の階級を出します。
殺したスキル・殺されたスキル・殺したプレイヤー・殺されたプレイヤーを、日毎・月毎・全期間の
ランキングで見られます。

## Overview (EN)

Shows only the PvP player kill feed in Cyrodiil and the Imperial City, in a window of its own. It works even when the game's
"PvP Kill Feed" option (kills in the chat) is turned off, so you can follow the fight without
filling the chat. Move and resize the window, change its text size and where it sits among the
other UI, and have the Tales of Tribute "card knocked out" sound play when the kill is yours. It also
counts your kills and deaths per day and gives you an army rank from your battles and win rate, and a ranking window lists the
skills you killed with, the skills that killed you, the players you killed and the players who killed
you, for a day, a month or all time.

---

## Description (JP)

PvPで近くのプレイヤーが倒されると、ゲーム本体はそのキルフィードをチャットに流します。
このアドオンは、シロディールと帝都でのそのキルログだけを専用のウィンドウに表示します。チャットとは別に
表示できるため、キルログをチャットに出さない設定のままでも、戦況を一目で確認できます。
さらに、自分のキルと死亡を日毎に記録して、階級とランキングで振り返れます。

■ 表示

・シロディールと帝都（帝都キャンペーンを含む）で、プレイヤー同士のキルを表示します。
　バトルグラウンドのキルは表示しません（ゲーム本体のキルフィードはそこでも流れますが、
　このアドオンは無視します）。それ以外の場所では、ウィンドウの文字も隠れます。
　文面・色・ランクアイコンはゲーム本体のキルフィードと同じで、言語設定に従います。
・ゲーム本体の「PvPキルフィード」の設定に関係なく動作します。
　このアドオンは、その設定を読むことも変更することもありません。
・同じキルが二重に通知された場合は、1行にまとめます。
・ウィンドウはHUDと、カーソルが使える画面（チャット入力中など）に表示され、マップや
　インベントリなどの全画面メニューでは隠れます。
　入力は一切受け取らないため、ゲームのボタン操作を邪魔しません。

■ 日毎の記録

・自分がキルした回数と、自分が倒された回数を、日毎に記録します（シロディールと帝都のみ）。
　日付が変わる時刻は、お使いの機器の時計の0時です。
・設定画面で、記録のある日ごとのキル数・死亡数を新しい順に見られます。
・キルに使った攻撃と、死亡の原因になった攻撃を記録します。設定画面で、全期間または
　1日を選んで、上位5件を見られます。攻撃が取得できなかった場合も、回数は数えます。
・倒した相手と、自分を倒した相手も、あわせて記録します。
・記録が溜まったら、設定画面から消去できます。消去の前に確認が出ます。
　「日別の記録を消去」では累計と階級を残し、「累計と階級もリセット」ではすべてゼロに戻します。

■ 階級

・軍隊の階級（二等兵から元帥までの18段階）を、1種類だけ表示します。
　合計バトル数（キル＋死亡）と勝率（キル÷バトル数）から決まります。
　1バトルは、勝率0%なら0.5点、100%なら1.5点として数え、その合計点で階級が上がります。
　戦うほど、勝つほど、早く上がります。
・設定画面には、階級のほか、合計バトル数・勝率と、次の階級まで今の勝率であと何戦かが出ます。
　累計は日別の記録とは別に持っているので、日別の記録を消去しても階級は残ります。

■ ランキングウィンドウ

・別ウィンドウに、次の4つの上位10件を並べます。
　殺されたスキル／殺したスキル／殺されたプレイヤー／殺したプレイヤー
・期間は、全期間・日毎・月毎から選べます。日毎は今日か記録のある過去の日、
　月毎は今月か記録のある過去の月です。「今日」「今月」は、日付が変わると自動で切り替わります。
・設定画面から表示でき、設定画面の上にも重ねて表示します。HUD上では /pbkl ranking で出し入れします。
　入力は受け取らないため、ゲームのボタン操作を邪魔しません。

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
　他のプレイヤーのキルや、自分が倒された時には鳴りません。シロディールと帝都以外でも鳴りません。
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
/pbkl ranking [day|month|all]　ランキングウィンドウの表示／非表示。day=今日、month=今月、all=全期間
/pbkl stats　今日のキル・死亡と、階級、合計バトル数・勝率をチャットに表示
/pbkl sound [on|off]　キル効果音のオン／オフ（引数なしで切り替え）
/pbkl unlock　/pbkl lock　マウスでの移動・サイズ変更（マウスが使える環境のみ）

※設定画面の表示には LibHarvensAddonSettings が必要です。無くてもキルログは表示され、
　チャットコマンドで操作できます（記録の閲覧は /pbkl stats と /pbkl ranking で行えます）。

## Description (EN)

When a nearby player is killed in PvP, the game puts the kill in the chat. This add-on shows
only that kill feed from Cyrodiil and the Imperial City, in a window of its own. Because it is separate from the chat, you can keep
the kill feed out of the chat and still see how the fight is going at a glance. It also records your
own kills and deaths day by day, and lets you look back on them as ranks and rankings.

■ Showing

- Shows player kills in Cyrodiil and the Imperial City (Imperial City campaigns included). Kills in
  Battlegrounds are not shown (the game's own kill feed reports them too, but this add-on ignores
  them), and everywhere else the window's text is hidden. The wording, colours and rank icons are
  the game's own kill feed, in your language.
- It works whatever the game's "PvP Kill Feed" option is set to. The add-on neither reads nor
  changes that option.
- A kill that is announced twice is shown once.
- The window is drawn on the HUD and wherever the cursor is free (while typing in the chat, for
  example), and is hidden in full-screen menus such as the map and the inventory. It takes no
  input at all, so it never gets in the way of the game's buttons.

■ Daily records

- Counts the kills you get and the times you are killed, day by day (Cyrodiil and the Imperial City only). A new day
  starts at midnight on your own device's clock.
- The settings panel lists each recorded day's kills and deaths, newest first.
- Records the skill you killed with and the skill that killed you. In the settings panel pick all
  time or one day to see the top five of each. When the skill cannot be read the kill or death is
  still counted.
- Records the players you killed and the players who killed you too.
- When the records pile up, clear them from the settings panel; you are asked first. "Clear the
  daily records" keeps your totals and ranks, "Reset totals and ranks too" sets everything to zero.

■ Rank

- One army rank, one of eighteen from private to marshal, worked out from your total battles
  (kills + deaths) and your win rate (kills / battles). A battle counts for 0.5 points at a 0% win
  rate and up to 1.5 points at 100%, and the ranks are measured in those points, so you climb with
  every fight and faster the more of them you win.
- The settings panel shows the rank, the battles and win rate behind it, and how many more battles
  the next rank takes at your current win rate. The totals are kept apart from the daily records,
  so clearing those leaves the rank alone.

■ Ranking window

- A window of its own with four top-ten lists: skills that killed you, skills you killed with,
  players who killed you, players you killed.
- Over a period you choose: all time, one day, or one month. A day is today or a past day that has
  records, a month is this month or a past month that has records. "Today" and "this month" follow
  the calendar by themselves.
- Open it from the settings panel, where it is drawn over the panel too, or with /pbkl ranking on
  the HUD. It takes no input, so it never gets in the way of the game's buttons.

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
  for other players' kills, when you are the one defeated, or outside Cyrodiil and the Imperial City. Switching it on plays the sound once
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
/pbkl ranking [day|month|all] — show or hide the ranking window; day = today, month = this month, all = all time
/pbkl stats — print today's kills and deaths, your rank, and the battles and win rate behind it in the chat
/pbkl sound [on|off] — kill sound on or off (no argument flips it)
/pbkl unlock, /pbkl lock — move and resize with the mouse (only where a mouse is available)

The settings panel needs LibHarvensAddonSettings. Without it the kill log still shows and can be
controlled with the chat commands (the records can be looked at with /pbkl stats and /pbkl ranking).
