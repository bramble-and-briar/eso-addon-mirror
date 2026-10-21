# Store listing copy

Text for the Bethesda.net / ZOS Console AddOn Uploader entry. Plain text, no markdown —
paste as-is. The **name** field is what the in-game add-on browser shows, so it must read
`PB's TargetPlayer for AD Stalkers` there; `## Title` in the manifest does not reach that screen.

---

## Name

PB's TargetPlayer for AD Stalkers

## Overview (JP)

PvPで探したいプレイヤーに、ゲーム標準のターゲットマーカーを自動で付けます。登録したプレイヤーに
レティクルを合わせると、ネームプレートの上にマークが表示されます。

## Overview (EN)

Puts the game's own target marker on the players you pick. Look at a registered player and the
marker shows above their nameplate.

---

## Description (JP)

PvPで「あの人がいる」と気付きやすくするアドオンです。

■ できること

・最大20人まで登録できます。プレイヤーは @アカウント名、コンソールのID、キャラクター名の
　どれで入力してもかまいません（大文字小文字は区別せず、先頭の@は省略できます）。
・登録したプレイヤーにレティクルを合わせると、ゲーム標準のターゲットマーカーがそのプレイヤーに付き、
　ネームプレートの上に表示されます。ターゲット枠やグループ枠の名前の前にも、同じアイコンが出ます。
・マーカーは8種類から選べます（初期設定は赤い交差した剣）。全員共通の1種類です。
・登録したプレイヤーがフレンドかギルドメンバーなら、いまどこにいるか（ゾーン）を /pbtarget where と
　設定画面の「現在地」で確認でき、シロディールに入ったとき（またはシロディールでオンラインになったとき）に
　メッセージと音でお知らせします。ゲームが教えるのはゾーンまでで、どの砦かは分かりません。
　フレンドでもギルド仲間でもない相手は名簿に載らないため、いまの居場所は分かりません。代わりに、
　キルフィード（砦の名前つき）・戦闘・/say・/yell・エモート・ゾーンチャット・レティクルで見かけた
　最後の場所と時間を表示します。
・レティクルの先にいない、近くにいるだけのプレイヤーについては、キルフィードや戦闘に登場したとき、
　画面上部のメッセージと音でお知らせします。キルフィードでは場所（砦の名前）も分かります。
・登録の追加・削除は設定画面から、またはチャットコマンド /pbtarget でできます。

■ できないこと（ご注意ください）

・ゲームの仕様で、アドオンがマーカーを付けられるのは「レティクルを合わせている相手」だけです。
　視界に入っただけのプレイヤーにマーカーを付けることはできないため、各プレイヤーを最初に一度は
　見る必要があります。一度付いたあとの表示はゲームが行います。
・マーカーは同時に1人にしか付きません。複数人を登録している場合は、最後に見た人に移ります。
・すでに別のマーカーが付いている相手には付け直しません。
・通知は「近くにいる」ことを知らせるもので、位置を指し示すことはできません。戦闘での通知は、
　キャラクター名しか届かないため、@アカウント名やコンソールIDで登録した場合は、一度見たあとに有効になります。
・キャラクターの頭上の名前（ネームプレート）の色を変えたり、枠で囲んだりはできません。
　ゲーム本体が描画しているためです。

■ 設定

・設定 > アドオン > PB's TargetPlayer for AD Stalkers
・設定画面がなくても、/pbtarget add <ID> で登録、/pbtarget で一覧表示できます。
・動作しないときは /pbtarget status で、ゲームがマーカーの付与を許したかどうかなどを確認できます。

## Description (EN)

Spot the player you are looking for in PvP.

What it does

- Register up to twenty players by @account name, console ID or character name. Case does not
  matter and the @ is optional.
- When you put the reticle on a registered player, the game's own target marker is set on them and
  shows above their nameplate. The same icon appears in front of their name in the target frame
  and the group frames.
- Pick the marker from the game's eight (the default is the red crossed swords). It is one marker
  for everyone.
- Add and delete players from the settings panel or with /pbtarget.
- For a registered friend or guild member, /pbtarget where and the Location row in the settings panel say
  which zone they are in (or when they were last online), and a message and a sound say when they enter
  Cyrodiil. The game reports the zone, not the position. A player who is neither a friend nor in a shared
  guild cannot be located.
- For a registered player who is merely around, a message across the top of the screen and a sound say
  so when they turn up in the Cyrodiil kill feed (with the place) or in a fight with you or your group.

What it cannot do

- The game lets an add-on mark only the player under the reticle, so a player who has merely come
  into view cannot be marked: look at each registered player once. After that the game shows the
  marker.
- A marker sits on one player at a time; with several registered players it follows the one you
  looked at last.
- A player who already carries another marker is left alone.
- The name floating above a character's head is drawn by the game engine; an add-on cannot recolour
  or box it.

Settings: Settings > Add-Ons > PB's TargetPlayer for AD Stalkers. Without the settings library, /pbtarget add <ID>
registers a player and /pbtarget lists the commands. /pbtarget status shows whether the game let the
add-on set a marker.

---

## Notes for the uploader form

- **Restricted use.** The add-on runs only for two PSN IDs (see README, "Who may use it"). Anyone
  else sees 「あなたはこのアドオンを使用できません」 in chat after login and the add-on does nothing.
  If it is uploaded for general download, say so in the description.
- Folder / add-on name: PBsTargetPlayer (case-sensitive on PlayStation).
- Optional dependency: LibHarvensAddonSettings (the settings panel). Everything works without it
  through /pbtarget.
- API version: 101050 101051.
