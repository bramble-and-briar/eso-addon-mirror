# Store listing copy

Text for the Bethesda.net / ZOS Console AddOn Uploader entry. Plain text, no markdown --
paste as-is. The **name** field is what the in-game add-on browser shows, so it must read
`PB's Emote Synchronizer` there; `## Title` in the manifest does not reach that screen.

The "everybody needs it" paragraph is near the top of both Descriptions on purpose: the
add-on does nothing for a group in which the leader has not installed it, and that is the
first thing a player has to know.

Publish only after the PS5 checks in README.md have been done. The text below describes the
add-on as designed; the delay figure is deliberately not quoted because nobody has measured it
on a console yet.

---

## Name

PB's Emote Synchronizer

## Overview (JP)

グループのリーダーがエモートをすると、このアドオンを入れているメンバーも同じエモートをします。
全員でそろって踊る、おじぎをする、といった場面に。リーダーを含む全員にこのアドオンと
LibGroupBroadcast が必要です。持っていないエモートや戦闘中は再生しません。

## Overview (EN)

When the group leader plays an emote, every member who runs this add-on plays the same one.
For dancing, bowing or cheering together. Everybody, the leader included, needs this add-on
and LibGroupBroadcast. Emotes you do not own, and anything in combat, are skipped.

---

## Description (JP)

グループのリーダーが行ったエモートを、このアドオンを入れているメンバーにも同じように再生させる
アドオンです。みんなで同じダンスをする、そろっておじぎをする、といった場面で使えます。

■ 必要なもの

　リーダーを含む、グループの全員にこのアドオンが必要です。ゲームには、他の人がエモートを始めた
　ことを知る方法がありません。リーダーのアドオンが、リーダー自身のエモートを検知して、グループに
　知らせています。リーダーが入れていないと、メンバーには何も起きません。

　通信には LibGroupBroadcast を使います。入っていないと送受信ができません。

■ このアドオンがすること・しないこと

　リーダーがエモート画面、ユーティリティホイール、スラッシュコマンド(/dance など)のどれかで
　エモートをすると、そのエモートのIDがグループに送られます。受け取ったメンバーは、自分のゲームで
　同じエモートを再生します。

　　・メンバーが再生するのは、そのメンバーが自分で再生できるエモートだけです。持っていない
　　　エモートは見送ります。
　　・戦闘中は、送りません(リーダー)。再生もしません(メンバー)。
　　・追従するのは、グループのリーダーのエモートだけです。メンバーのエモートは送られません。
　　・エモートを止める合図は送りません。止めるのは各自です(動けばエモートは解除されます)。
　　・移動やボタン入力の代行はしません。

■ 同時には始まりません

　通信が届くまでの分だけ、メンバーはリーダーより遅れて始まります。LibGroupBroadcast は、静かな
　状態からの最初の送信を約0.5秒待ってから行い、その後もゲームが送信の間隔を空けるため、遅れは
　最低でも0.5秒ほどあります。

　そろえたいときは、設定の「リーダーの再生を遅らせる」を使います。リーダー自身のエモートをその分
　だけ待たせて、全員がほぼ同時に始まるようにします。待ち時間は、次のコマンドで測った往復時間から
　決めます。

　　/emotesync ping　　　グループとの往復時間を測る
　　/emotesync lead auto　直近の往復時間の半分を、待ち時間に設定する

■ コマンド

　　/emotesync on | off　　　　全体のオン・オフ
　　/emotesync status　　　　　役割、通信の状態、送信・受信・再生・失敗の数、見送った理由
　　/emotesync ping　　　　　　このアドオンを入れているメンバー全員との往復時間を測る
　　/emotesync lead <ms | auto>　リーダーの再生を遅らせる(0〜3000ms)
　　/emotesync play <エモート名>　アドオンからエモートを再生する(動作確認用。何も送りません)
　　/emotesync probe　　　　　 エモートの再生が制限されていないか、ゲームに問い合わせる
　　/emotesync debug　　　　　 送受信の記録をチャットに出す(打つたびにオン・オフ)

■ 設定

　設定パネルには LibHarvensAddonSettings が必要です。

　　アドオンを有効にする　　　　　　初期値：オン
　　リーダーのとき自分のエモートを送る　初期値：オン
　　リーダーのエモートに合わせる　　初期値：オン
　　チャットで知らせる　　　　　　　初期値：オン
　　リーダーの再生を遅らせる (ms)　　初期値：0 (0〜3000)
　　グループとの通信の遅れを測る　　(ボタン)
　　設定をすべて初期値に戻す

■ 既知の制限

　エモートが終わったことを知る方法がないため、止めるのは各自です。
　相手を見て行うエモートは、同期しても相手の向きが合いません。
　他のアドオンが同じエモートの呼び出しを置き換えていると、両方が順に動きます。
　見送られたエモートがある場合は、/emotesync status で理由(戦闘中、未所持など)を確認できます。

LibGroupBroadcast が必要です。LibHarvensAddonSettings があれば設定パネルが追加されます。
なくても初期設定のまま動き、/emotesync on | off で切り替えられます。

## Description (EN)

Makes your group play the leader's emotes. When the group leader plays an emote, every member
who runs this add-on plays the same one -- for dancing, bowing or cheering together.

■ What you need

　Everybody in the group needs this add-on, the leader included. The game has no way to tell an
　add-on that somebody else started an emote. The leader's own add-on notices the leader's
　emote and tells the group. If the leader does not have it, nothing happens for the members.

　The messages travel through LibGroupBroadcast. Without it nothing can be sent or received.

■ What it does and does not do

　When the leader plays an emote from the emote menu, the utility wheel or a slash command
　(/dance and so on), the emote's id is sent to the group. Each member's game then plays the
　same emote.

　　- A member only plays emotes they could play themselves. Emotes they do not own are
　　  skipped.
　　- Nothing is sent while the leader is in combat, and nothing is played while a member is.
　　- Only the group leader's emotes are followed. A member's emotes are not sent.
　　- No stop signal is sent. Stopping is up to each player (moving cancels an emote).
　　- It never moves you or presses a button for you.

■ It does not start at exactly the same moment

　Members start later than the leader by the time the message needs to arrive.
　LibGroupBroadcast waits about half a second before the first message after a quiet spell, and
　the game then keeps a gap between messages, so the delay is at least about half a second.

　To line everyone up, use "Leader waits before playing" in the settings. It holds the leader's
　own emote back by that time so the whole group starts together. Pick the value from a
　measurement:

　　/emotesync ping　　　 measure the round trip to the group
　　/emotesync lead auto　set the wait to half of the last round trip

■ Commands

　　/emotesync on | off　　　　show or hide everything
　　/emotesync status　　　　　role, channel state, counters and why emotes were skipped
　　/emotesync ping　　　　　　measure the round trip to every member who runs the add-on
　　/emotesync lead <ms | auto>　hold the leader's own emote back (0-3000 ms)
　　/emotesync play <emote>　　play an emote from the add-on (a check; nothing is sent)
　　/emotesync probe　　　　　 ask the game whether playing emotes is restricted
　　/emotesync debug　　　　　 log what is sent and received (toggles)

■ Settings

　The settings panel needs LibHarvensAddonSettings.

　　Turn the add-on on　　　　　　　　　 default: on
　　Send my emotes when I am the leader　default: on
　　Play the leader's emotes　　　　　　 default: on
　　Tell me in chat　　　　　　　　　　　default: on
　　Leader waits before playing (ms)　　 default: 0 (0-3000)
　　Measure the delay to the group　　　 (button)
　　Reset to defaults

■ Known limitations

　Nothing can see an emote end, so stopping is up to each player.
　Emotes aimed at another player will not line up in direction even when synchronised.
　If another add-on replaces the same emote call, both run in turn.
　When an emote was skipped, /emotesync status says why (combat, not owned and so on).

LibGroupBroadcast is required. With LibHarvensAddonSettings you also get a settings panel;
without it the add-on runs on its defaults and /emotesync on | off switches it.
