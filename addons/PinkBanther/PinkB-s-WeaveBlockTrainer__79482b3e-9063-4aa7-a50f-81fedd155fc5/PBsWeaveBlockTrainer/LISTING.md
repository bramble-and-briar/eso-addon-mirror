# Store listing copy

Text for the Bethesda.net / ZOS Console AddOn Uploader entry. Plain text, no markdown --
paste as-is. The **name** field is what the in-game add-on browser shows, so it must read
`PB's Weave & Block Trainer` there; `## Title` in the manifest does not reach that screen.

The "does not press anything" paragraph is near the top of both Descriptions on purpose.
Players read an add-on that touches combat with that question in mind, and the answer should
be there before they install rather than after.

---

## Name

PB's Weave & Block Trainer

## Overview (JP)

軽攻撃ウィーブと防御キャンセルのタイミングを、画面のバーと音で練習するアドオンです。1秒の
リズムに合わせて「今、軽攻撃してからスキル」を知らせ、スキル直後には防御キャンセルの受付を
光らせます。軽攻撃→スキル→ブロックがつながると「エクセレント！」と、その時間を表示します。
入力は代行せず、操作はすべてご自身のボタンで行います。

## Overview (EN)

Practice light-attack weaving and block cancelling with an on-screen bar and sound. A
1-second rhythm bar tells you when to light attack and then cast, a flash right after a skill
shows the block-cancel window, and a complete light attack > skill > block chain earns
EXCELLENT! with the times. It only shows timing -- you press every button yourself.

---

## Description (JP)

ESOの与ダメージ回しの土台になる二つの動作、「軽攻撃ウィーブ」と「防御キャンセル」のタイミングを、
画面のバーと音で練習するためのアドオンです。

■ このアドオンがしないこと

　ボタン入力は一切行いません。軽攻撃・スキル・ブロックは、すべてご自身のボタンで操作します。
　アドオンは、ゲームが知らせる出来事を読んで、バーと文字を表示するだけです。

■ ウィーブ・メトロノーム

　最後にスキルを使った瞬間から、1サイクル（初期値は1秒）でいっぱいになるバーを、画面中央の
　少し下に出します。バーの末尾にある明るい区間（初期値は最後の250ms）に入ると、「軽攻撃 →
　スキル」の文字が黄色くなり、短い音が鳴ります。そこで軽攻撃をして、続けてスキルを使います。
　スキルを使い損ねても、バーは同じリズムで進み続けます。

　スキルを使うたびに、バーの下に結果が出ます。

　　軽攻撃 → スキル　144 ms　（緑）前のスキルのあと、このスキルの1サイクル以内に軽攻撃が
　　　　　　　　　　　　　　　　　入っていた。軽攻撃からスキルまでの時間です
　　軽攻撃なし　　　　　　　　（灰）軽攻撃が入っていなかった

■ 防御キャンセルの受付表示

　詠唱のないスキルを使った直後に、黄色い「ブロック」の枠を300ms（初期値）だけ出します。その間に
　ブロックすると、緑の「OK」に変わり、スキルからブロックまでの時間が枠の下に出ます。

　　スキル → ブロック　64 ms

　スキルより前からブロックを押しっぱなしにしていた場合は、キャンセルとは数えません。数えるのは、
　枠が出たあとに新しく押したブロックだけです。チャネリングや詠唱のあるスキルは、ブロックすると
　中断されてしまうため、枠を出しません。

■ エクセレント！

　軽攻撃 → スキル → ブロックが全部つながると、枠がピンクの「エクセレント！」に変わります。
　枠の下には、スキルからブロックまでの時間と、軽攻撃からブロックまでの合計時間が出ます。

　　スキル → ブロック　64 ms
　　合計　208 ms

　OKは約0.8秒、エクセレントは約1.5秒表示します。次のスキルを使うと、その時点で消えます。

■ 表示される時間について

　時間は、画面の1コマごと（約16ms刻み）にゲームの状態を見て測った値です。ゲームやネットワークの
　遅れも含まれるので、ボタンを押した瞬間の値ではなく、目安としてお使いください。

■ 表示する場面

　初期設定では、戦闘中だけ表示します。「戦闘中のみ」をオフにすると、戦闘外でスキルを使ったあとも
　約4サイクルのあいだバーが動くので、木人での練習に使えます。メニューやマップを開いている間は
　表示しません。

■ コマンド

　　/weave on | off　　表示のオン・オフ
　　/weave debug　　　スキル・軽攻撃・ブロックの記録をチャットに出す（打つたびにオン・オフ）

■ 設定

　設定パネルには LibHarvensAddonSettings が必要です。

　　メトロノームを表示　　　　　　　初期値：オン
　　区間の開始で音を鳴らす　　　　　初期値：オン
　　サイクルの長さ (ms)　　　　　　　初期値：1000（900〜1200）
　　軽攻撃の区間 (ms)　　　　　　　　初期値：250（100〜500）
　　戦闘中のみ　　　　　　　　　　　初期値：オン
　　スキル直後に光らせる　　　　　　初期値：オン
　　受付時間 (ms)　　　　　　　　　　初期値：300（100〜800）
　　横位置・縦位置　　　　　　　　　初期値：0 ・ 180
　　設定をすべて初期値に戻す

　サイクルの長さは、スキルの共通クールダウン（約1秒）に合わせてあります。通信の遅れでバーが
　ゲームより先に進んで見えるときは、少し長くしてください。

■ 既知の制限

　軽攻撃には専用のイベントがないため、戦闘ログに記録された自分の軽攻撃から検出しています。
　ログが届かない環境では、軽攻撃をしても「軽攻撃なし」と表示され、エクセレントも出ません。
　/weave debug をオンにして軽攻撃とスキルを使うと、チャットに「light attack result」で始まる
　行が出るので、検出できているかどうかを確認できます。

必須ライブラリはありません。LibHarvensAddonSettings があれば設定パネルが追加されます。
なくても初期設定のまま動き、/weave on | off で表示を切り替えられます。

## Description (EN)

A timing aid for the two habits every damage rotation is built on: light-attack weaving and
block cancelling. It shows the rhythm on a bar and plays a tick, so you can practise until the
timing is yours.

■ What it does not do

　It never presses anything. Every light attack, skill and block is your own button press.
　The add-on reads what the game reports and draws a bar and some text, nothing more.

■ Weave metronome

　A bar a little below the middle of the screen fills over one cycle (1 second by default),
　counted from the moment of your last skill. When it enters the bright zone at its end (the
　last 250 ms by default), the "LA > Skill" text turns yellow and a short tick plays. That is
　when to light attack, then cast. If you miss a cast the bar keeps counting the same rhythm.

　After every skill a result appears under the bar:

　　LA > Skill  144 ms　(green) a light attack came after the previous skill and within one
　　　　　　　　　　　　　　　 cycle of this one. The time is light attack to skill
　　No light attack　　　(grey)  there was none

■ Block-cancel window

　Right after an instant skill, a yellow BLOCK box appears for 300 ms (by default). Block
　inside that window and it turns into a green OK, with the time from the skill to the block
　under it:

　　Skill > Block  64 ms

　A block you were already holding when the skill went off does not count. Only a fresh block
　pressed after the box appears does. Channelled and cast-time skills get no box, because
　blocking would interrupt them.

■ EXCELLENT!

　When light attack, skill and block all connect, the box turns pink and says EXCELLENT!.
　Under it: the time from skill to block, and the total from the light attack to the block.

　　Skill > Block  64 ms
　　Total  208 ms

　OK stays up for about 0.8 s and EXCELLENT! for about 1.5 s. The next skill clears either.

■ About the times

　Times are measured by looking at the game once per frame (about 16 ms steps), and they
　include the game's and the network's delay. Read them as a guide rather than as the instant
　you pressed the button.

■ When it shows

　By default it shows in combat only. Turn "Only in combat" off and the bar keeps running for
　about four cycles after a skill used out of combat, for practice on a target dummy. It is
　hidden while a menu or the map is open.

■ Commands

　　/weave on | off　　show or hide everything
　　/weave debug　　　log skill, light attack and block events to chat (toggles)

■ Settings

　The settings panel needs LibHarvensAddonSettings.

　　Show the metronome　　　　　　　default: on
　　Tick when the zone starts　　　　default: on
　　Cycle length (ms)　　　　　　　　default: 1000 (900-1200)
　　Light-attack zone (ms)　　　　　 default: 250 (100-500)
　　Only in combat　　　　　　　　　 default: on
　　Flash after a skill　　　　　　　default: on
　　Window (ms)　　　　　　　　　　　default: 300 (100-800)
　　Horizontal / vertical offset　　 default: 0 / 180
　　Reset all settings

　The cycle length matches the skill global cooldown (about 1 second). If your ping makes the
　bar look ahead of the game, lengthen it a little.

■ Known limitation

　Light attacks have no event of their own, so they are picked up from your own light attacks
　in the combat log. Where those entries do not arrive, a light attack still reads "No light
　attack" and EXCELLENT! cannot appear. Switch /weave debug on, light attack and cast, and a
　line starting "light attack result" in chat tells you whether they are being seen.

No required libraries. LibHarvensAddonSettings adds the settings panel if you have it; without
it the add-on runs on its defaults, and /weave on | off shows or hides it.
