-- 日本語。lang/strings.lua のあとに読み込まれ、同じIDを上書きします。
local strings = {
	SI_PBSES_EXPLANATION = "グループのリーダーがエモートをすると、メンバーも同じエモートをします。リーダーを含む全員にこのアドオンが必要です。メンバーは、持っているエモートだけを、戦闘中でないときに再生します。",

	SI_PBSES_SECTION_SYNC = "同期",
	SI_PBSES_ENABLED = "アドオンを有効にする",
	SI_PBSES_ENABLED_TOOLTIP = "オフにすると、送信も再生もしません。",
	SI_PBSES_SEND = "リーダーのとき自分のエモートを送る",
	SI_PBSES_SEND_TOOLTIP = "グループのリーダーである間、自分が行ったエモートをグループに送ります。",
	SI_PBSES_FOLLOW = "リーダーのエモートに合わせる",
	SI_PBSES_FOLLOW_TOOLTIP = "リーダーがエモートをすると、自分も同じエモートをします。持っていないエモートや、戦闘中は見送ります。",
	SI_PBSES_NOTIFY = "チャットで知らせる",
	SI_PBSES_NOTIFY_TOOLTIP = "リーダーに合わせてエモートをしたとき、またはできなかったときに、チャットに1行出します。",
	SI_PBSES_LEAD = "リーダーの再生を遅らせる (ms)",
	SI_PBSES_LEAD_TOOLTIP = "メンバーは、通信が届くまでの時間(最低でも0.5秒ほど)だけリーダーより遅れます。この値を上げると、リーダー自身のエモートをその分だけ待たせて、全員が同時に始まるようにします。0なら自分のエモートはすぐに再生します。先に下のボタンで遅れを測ってください。",

	SI_PBSES_SECTION_TOOLS = "計測",
	SI_PBSES_PING_BUTTON = "グループとの通信の遅れを測る",
	SI_PBSES_PING_BUTTON_TEXT = "測る",
	SI_PBSES_RESET = "初期設定に戻す",
	SI_PBSES_RESET_BUTTON = "リセット",

	SI_PBSES_FOLLOWED = "リーダーに合わせて「%s」をしました。",
	SI_PBSES_FAILED = "「%s」ができませんでした(%s)。",
	SI_PBSES_FAIL_BLACKLISTED = "今は禁止されています",
	SI_PBSES_FAIL_GENERIC = "今はできません",
	SI_PBSES_FAIL_LOCKED = "未解放です",
	SI_PBSES_FAIL_UNKNOWN = "理由 %s",

	SI_PBSES_LOADED = "PB's Emote Synchronizer %s を読み込みました。/emotesync でコマンド一覧を表示します。",
	SI_PBSES_HELP = "/emotesync on | off -- 全体のオン・オフ\n/emotesync status -- 役割、カウンター、見送った理由\n/emotesync ping -- このアドオンを入れているメンバー全員との往復時間を測る\n/emotesync lead <ms | auto> -- リーダー自身の再生を遅らせる(auto = 直近の往復時間の半分)\n/emotesync play <エモート名> -- アドオンからエモートを再生する(動作確認用。何も送りません)\n/emotesync probe -- PlayEmoteByIndex が制限されていないかゲームに問い合わせる\n/emotesync debug -- 送受信の記録をチャットに出す",
	SI_PBSES_ON = "Emote Synchronizer をオンにしました。",
	SI_PBSES_OFF = "Emote Synchronizer をオフにしました。",
	SI_PBSES_DEBUG_ON = "デバッグ記録をオンにしました。",
	SI_PBSES_DEBUG_OFF = "デバッグ記録をオフにしました。",

	SI_PBSES_ROLE_SOLO = "グループに入っていません",
	SI_PBSES_ROLE_LEADER = "リーダー",
	SI_PBSES_ROLE_MEMBER = "メンバー",
	SI_PBSES_STATE_ON = "オン",
	SI_PBSES_STATE_OFF = "オフ",
	SI_PBSES_HOOK_ACTIVE = "設置済み",
	SI_PBSES_HOOK_MISSING = "未設置",
	SI_PBSES_STATUS_ROLE = "役割: %s / アドオン %s (送信 %s・追従 %s) / リーダーの待ち %d ms / エモート検知 %s",
	SI_PBSES_STATUS_COUNTS = "送信 %d / 受信 %d / 再生 %d / 失敗 %d",
	SI_PBSES_STATUS_SKIPPED = "見送り: %s",
	SI_PBSES_STATUS_NONE = "なし",

	SI_PBSES_NO_LIBRARY = "LibGroupBroadcast が入っていないため、送受信できません。",
	SI_PBSES_TRANSPORT_ID_TAKEN = "通信ID %d は、このクライアントの別のアドオンがすでに使用しています。(%s)",
	SI_PBSES_TRANSPORT_FAILED = "通信路を用意できませんでした。(%s)",
	SI_PBSES_TRANSPORT_REPORT = "通信: ID %d / 有効 %s / 送信 %d / 受信 %d (版違い %d)%s",
	SI_PBSES_WHY_LAST = " / 直近の失敗: %s",
	SI_PBSES_WHY_NOT_READY = "通信路が用意されていません",
	SI_PBSES_WHY_DISABLED = "LibGroupBroadcast で、このアドオンの通信が無効になっています",
	SI_PBSES_WHY_REFUSED = "LibGroupBroadcast が送信を受け付けませんでした",
	SI_PBSES_WHY_VERSION = "通信の版が違うメンバーがいます",

	SI_PBSES_PROBE = "PlayEmoteByIndex: private %s / protected %s。エモート数 %d。送信クールダウン残り %d ms。",
	SI_PBSES_PROBE_UNAVAILABLE = "このクライアントには IsPrivateFunction / IsProtectedFunction がありません。",
	SI_PBSES_PLAY_USAGE = "/emotesync play <エモート名>  例: /emotesync play dance",
	SI_PBSES_PLAY_NONE = "「%s」というエモートはありません。",
	SI_PBSES_PLAY_DONE = "「%s」の再生をゲームに依頼しました。",

	SI_PBSES_NOT_GROUPED = "グループに入っていません。",
	SI_PBSES_SEND_FAILED = "送信できませんでした: %s",
	SI_PBSES_PING_SENT = "計測中です。このアドオンを入れているメンバーの返事が下に出ます。",
	SI_PBSES_PING_REPLY = "%s: 往復 %d ms",
	SI_PBSES_PING_SUMMARY = "%d人が返事をしました。往復: 最短 %d / 中央 %d / 最長 %d ms。片道はおよそ %d ms。",
	SI_PBSES_PING_NONE = "返事がありません。メンバーにこのアドオンと LibGroupBroadcast が必要です。",
	SI_PBSES_LEAD_USAGE = "/emotesync lead <0-3000 | auto>",
	SI_PBSES_LEAD_SET = "リーダーの再生を %d ms 遅らせます。",
	SI_PBSES_LEAD_NO_MEASURE = "まだ計測していません。先に /emotesync ping を実行してください。",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
