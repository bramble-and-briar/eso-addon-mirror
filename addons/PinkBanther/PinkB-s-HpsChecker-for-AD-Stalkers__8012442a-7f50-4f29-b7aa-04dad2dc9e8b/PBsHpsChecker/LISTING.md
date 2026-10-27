# Store listing copy

Text for the Bethesda.net / ZOS Console AddOn Uploader entry. Plain text, no markdown --
paste as-is. The **name** field is what the in-game add-on browser shows, so it must read
`PB's HPS Checker` there; `## Title` in the manifest does not reach that screen.

"It only reads game events" is near the top of both Descriptions on purpose: players read an
add-on that touches combat with that question in mind.

The two things not yet measured on console (what target type a heal on a player outside the
party arrives with, and whether the heal amount already excludes overheal) are listed under
"Known limitations", with the command that settles each.

---

## Name

PB's HPS Checker

## Overview (JP)

PvPでの自分の回復量を、統計として見られるようにするアドオンです。回復量の合計とHPS、回復した
相手の名前と量、使ったスキル、そして回復がパーティーメンバー・パーティー外・自分自身にそれぞれ
何%行ったかを、今日・今月・過去の日ごとに表示します。戦闘中は小さなHPSメーターも出ます。
ゲームの出来事を読むだけで、操作は代行しません。

## Overview (EN)

See how much you heal in PvP as statistics: total healing and HPS, the players you healed and how
much, the skills you used, and what share of your healing went to your party, to everybody else
and to yourself -- per day, per month, or overall. A small HPS meter shows the fight you are in.
It only reads game events; it never presses anything for you.

---

## Description (JP)

ヒーラーの方が、PvP（シロディール）で自分がどれだけ回復で貢献しているかを数字で見られるように
するためのアドオンです。

■ このアドオンがしないこと

　ボタン入力は一切行いません。アドオンは、ゲームが知らせる回復の出来事を読んで、数えて、表示する
　だけです。

■ 使用できる方

　このアドオンは、PSN ID が PinkBanther と Yukiblack1123 の方だけが使用できます。それ以外の方が入れても、
　何も記録せず、ログイン後に「あなたはこのアドオンを使用できません」と表示するだけです。

■ 数えるもの

　自分が行った回復（回復・クリティカル回復・継続回復）を、1回ごとに次のように数えます。

　　・合計の回復量とHPS（1秒あたりの回復量）
　　・回復した相手のプレイヤー名（PSN ID）ごとの回復量と、全体に占める割合
　　・回復に使ったスキルごとの回復量
　　・回復先の内訳：パーティーメンバー／パーティー外／自分自身、それぞれの回復量と比率（パーティーと
　　　パーティー外は、回復した人数つき）
　　・パーティーメンバーが受けた回復のうち、自分の分が何%か（全体と、メンバーごと。他のヒーラーの回復が
　　　アドオンに届く場合）
　　・戦闘の回数、回復していた時間、最高の戦闘HPS、最大の1回復、クリティカル率、オーバーヒール
　　・直近の戦闘の履歴（日時・時間・HPS・回復量）

　初期設定ではシロディールの中だけを数えます（帝都とバトルグラウンドは数えません）。設定で、すべての
　PvPゾーン、またはPvEを含めてどこでも、に変えられます。自分のペットとコンパニオンへの回復は数えません。

■ HPSメーター

　回復を始めると、画面に小さな枠が出ます。

　　HPS　8,420
　　直近10秒　9,100
　　回復量　456,789　3:12　14人
　　パーティー 62%　パーティー外 31%　自分 7%
　　パーティーが受けた回復のうち自分の分　72%

　戦闘が終わると「戦闘終了」に変わり、少し（初期値10秒）残ってから消えます。設定画面を開いている間は、
　位置を決められるようにサンプルの数字で表示します。

■ 統計画面（メインメニュー）

　メインメニューに「ヒール統計」の項目が入ります（「ステータス超詳細」があればその次、なければキャラクター
　の次）。選ぶと、画面の中央に、背景の透けない統計画面が開きます。設定画面のボタンや /hps stats からも
　開けます。3ページあり、LB / RB で切り替えます。

　　統計　　　　　1つの期間の統計（概要・回復した相手の上位10人・スキルの上位10件・直近10戦）。← → で
　　　　　　　　　前後の期間に切り替えます
　　期間の一覧　　過去の履歴の目次。今日・今月・全期間・過去の月・過去の日（保存されている60日ぶん）を
　　　　　　　　　1行ずつ並べ、回復量・HPS・戦闘回数・比率を出します。選んでAで、その期間の統計を開きます
　　戦闘の履歴　　最新40戦。日時・時間・HPS・回復量・人数・パーティーへの比率・いちばん回復した相手

　Xで今日に戻り、Bで戻ります。

■ HPSの数え方

　HPSは、回復量 ÷ 回復していた時間です。回復していた時間は、戦闘の最初の回復から最後の回復までに1秒を
　足したものです。回復が設定した秒数（初期値10秒）途切れると、その戦闘は終わりです。最高の戦闘HPSは、
　10秒以上続いた戦闘の中での値です。

■ 保存

　アカウント単位で、直近60日分を保存します。1日あたり、回復した相手は回復量の多い順に60人、スキルは
　40件まで一覧に残ります（それを超えた分も、その日の合計には入っています）。記録は設定画面からまとめて
　消せます（確認が出ます）。

■ コマンド

　　/hps today | month | all　　統計をチャットに出す
　　/hps stats [today | month | all]　統計画面を開く
　　/hps hud　　HPSメーターの表示・非表示
　　/hps on | off　　記録の開始・停止
　　/hps status　　数えた回復の数と、相手の種類ごとの内訳
　　/hps probe　　ゲームがアドオンに届ける回復の種類を2分間計測する（計測用）
　　/hps debug　　次の200回の回復を、ゲームが報告したままの値で出す

■ 設定

　設定パネルには LibHarvensAddonSettings が必要です。

　　統計画面（ボタン）
　　HPSメーター：表示（初期値：オン）／文字の大きさ（1〜7、初期値：4）／枠の大きさをpxで指定（初期値：オフ、
　　幅・高さは600 / 220）／戦闘後に残す時間（10秒）／横位置・縦位置（60 / 560）
　　回復量を記録する（初期値：オン）
　　記録する場所（初期値：シロディールのみ）
　　戦闘とみなす途切れ時間（初期値：10秒、5〜30）
　　他のヒーラーの回復も数える（初期値：オン）
　　記録をすべて消去

■ 既知の制限

　・「パーティーメンバーが受けた回復のうち自分の分」は、他のヒーラーがパーティーメンバーに行った回復が
　　アドオンに届くことが前提です。届くかどうかは実機で確認中で、届いていない間は、自分の回復だけで数える
　　ので100%と表示します（100%は「全部自分」と「他の回復が届いていない」の両方で出ます）。/hps status と
　　/hps probe で確かめられます。パーティー外の方が受ける回復は、自分が行った分しか
　　届かない見込みなので、割合は出ません。
　・パーティー外のプレイヤーへの回復が、どの種類の相手として届くかは、コンソールの実機で確認中です。
　　グループのメンバー＝パーティー、それ以外＝パーティー外と読んでいます。/hps status に相手の種類ごとの
　　件数が出るので、パーティー外の方を回復したときに「OTHER」が増えているか確認できます。
　・回復量にオーバーヒールが含まれるかどうかも確認中です。/hps debug が、ゲームの報告した回復量
　　（hit）と上限を超えた分（over）を出します。
　・回復のイベントが知らせるのはキャラクター名だけなので、PSN IDは、パーティーメンバー、照準を合わせた
　　プレイヤー、キルフィード（倒した人と倒された人の両方の名前が出ます）から覚えています。そのどれにも当て
　　はまらない相手は、キャラクター名のままです。設定でキャラクター名の表示に切り替えられます。

必須ライブラリはありません。LibHarvensAddonSettings があれば設定パネルが追加されます。なくても記録と
HPSメーターは動き、/hps コマンドで統計を見られます。

## Description (EN)

For healers: see how much you contribute in PvP (Cyrodiil) as numbers.

■ What it does not do

　It never presses anything. The add-on reads the heal events the game reports, counts them and
　shows them.

■ Who can use it

　Only players whose PSN ID is PinkBanther or Yukiblack1123 can use this add-on. For anyone else it
　records nothing and shows one line after login saying they cannot use it (in Japanese).

■ What it counts

　Every heal you do (heals, critical heals and heal-over-time ticks), one by one:

　　- total healing and HPS (healing per second)
　　- healing per player you healed (by PSN ID where it is known), and each player's share of the total
　　- healing per skill
　　- who it went to: party members / everybody outside the party / yourself, with the amount
　　  and the ratio of each (and how many players, for the party and for everybody else)
　　- your share of what party members received from every healer (overall, and per member), when other
　　  healers' heals on party members reach the add-on
　　- number of fights, time spent healing, best fight HPS, biggest single heal, critical rate,
　　  overheal
　　- a history of your latest fights (date and time, length, HPS, amount)

　By default only Cyrodiil itself is counted (not the Imperial City or Battlegrounds). A setting
　widens that to every PvP zone, or to everywhere including PvE. Heals on your own pets and
　companions are not counted.

■ HPS meter

　A small box comes up when you start healing:

　　HPS  8,420
　　Last 10 s  9,100
　　Healed  456,789   3:12   14 players
　　Party 62%  Others 31%  You 7%
　　Your share of party healing  72%

　When the fight ends it reads "Fight over" and stays a little while (10 seconds by default). While
　the settings panel is open it is shown with sample numbers so that you can place it.

■ Statistics screen (main menu)

　The main menu gets a "Healing Stats" entry (right after "ステータス超詳細" / PB's Ultra Detailed Stats if it
　is there, else after Character). It opens a statistics screen in the middle of the screen on an opaque
　background; the panel button and /hps stats open it too. Three pages, turned with LB / RB:

　　Statistics  one period's statistics (summary, top 10 players healed, top 10 skills, latest 10 fights);
　　              left / right go to the previous / next period
　　Periods      the history, indexed: today, this month, all, past months and past days (every one of the
　　              60 days that are kept), one row each with amount, HPS, fights and shares; A opens the
　　              chosen period's statistics
　　Fights       the latest 40 fights: when, length, HPS, amount, players, share to the party, healed most

　X goes back to today, B goes back.

■ How HPS is worked out

　HPS is the amount healed divided by the time spent healing: the time from the first heal of a
　fight to its last, plus one second. A fight ends when no heal has come for the set time (10
　seconds by default). Best fight HPS is the best among fights that lasted 10 seconds or more.

■ Saving

　Saved per account for the last 60 days. Each day keeps its 60 biggest healed players and 40
　biggest skills in the lists (what falls off is still in the day's totals). All records can be
　deleted from the settings panel (you are asked first).

■ Commands

　　/hps today | month | all　　print the statistics to chat
　　/hps stats [today | month | all]　open the statistics screen
　　/hps hud　　show or hide the HPS meter
　　/hps on | off　　start or stop recording
　　/hps status　　how many heals were counted, by target type
　　/hps probe　　measure for 2 minutes which heals the game sends to the add-on (a measurement)
　　/hps debug　　print the next 200 heals as the game reports them

■ Settings

　The settings panel needs LibHarvensAddonSettings.

　　Statistics screen (button)
　　HPS meter: show (default: on) / text size (1-7, default 4) / set the box size in pixels (default: off; width and
　　height 600 / 220) / keep it up after a fight (10 s) / position (60 / 560)
　　Record healing (default: on)
　　Where to count (default: Cyrodiil only)
　　Fight ends after (default: 10 s, 5-30)
　　Count other healers' heals (default: on)
　　Delete all records

■ Known limitations

　- "Your share of what party members received" needs the heals other healers do to party members to reach
　　the add-on. Whether they do is still being confirmed on console; until they do the share counts only
　　your own heals and reads 100% (so 100% means either "all of it was yours" or "theirs do not arrive").
　　/hps status and /hps probe check it. What players outside your party receive cannot be shown:
　　only the part you healed reaches the add-on.
　- What target type a heal on a player outside your party arrives with is still being confirmed on
　　console. Group members are read as the party and everybody else as outside it. /hps status lists
　　heals by target type, so you can check that "OTHER" goes up when you heal someone outside your
　　party.
　- Whether the reported heal amount already leaves out overheal is also being confirmed. /hps debug
　　prints the amount the game reported (hit) and the amount beyond full health (over).
　- A heal event gives only the character name, so PSN IDs are learned from your party members, players you
　　point the reticle at, and the kill feed (a line names both players). A player who has been none of those
　　stays a character name. A setting switches back to character names.

No required libraries. LibHarvensAddonSettings adds the settings panel if you have it; without it
recording and the HPS meter still work, and /hps shows the statistics.
