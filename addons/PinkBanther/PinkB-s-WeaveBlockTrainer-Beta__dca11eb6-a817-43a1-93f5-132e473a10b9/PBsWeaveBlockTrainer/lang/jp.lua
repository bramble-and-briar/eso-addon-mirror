-- 日本語。lang/strings.lua のあとに読み込まれ、同じIDを上書きします。
local strings = {
	SI_PBSWT_CUE = "軽攻撃 → スキル",
	SI_PBSWT_BLOCK = "ブロック",
	SI_PBSWT_BLOCK_OK = "OK",
	SI_PBSWT_BLOCK_TIME = "スキル → ブロック  %d ms",
	SI_PBSWT_TOTAL = "合計  %d ms",
	SI_PBSWT_EXCELLENT = "エクセレント！",
	SI_PBSWT_WOVE = "軽攻撃 → スキル  %d ms",
	SI_PBSWT_NO_LA = "軽攻撃なし",

	SI_PBSWT_EXPLANATION = "タイミングを表示するだけのアドオンです。軽攻撃・スキル・ブロックはすべてご自身のボタン操作で行ってください。代わりに入力することはありません。",

	SI_PBSWT_SECTION_METRONOME = "ウィーブ・メトロノーム",
	SI_PBSWT_METRONOME = "メトロノームを表示",
	SI_PBSWT_METRONOME_TOOLTIP = "最後に使ったスキルから数えて、1サイクルでいっぱいになるバーです。末尾の明るい区間に入ったら、軽攻撃してからスキルを使います。",
	SI_PBSWT_SOUND = "区間の開始で音を鳴らす",
	SI_PBSWT_SOUND_TOOLTIP = "バーが軽攻撃の区間に入ったときに、短い音を鳴らします。",
	SI_PBSWT_CYCLE = "サイクルの長さ (ms)",
	SI_PBSWT_CYCLE_TOOLTIP = "スキルの共通クールダウンは1000msです。通信の遅延でバーがゲームより先に進むときは、少し長くしてください。",
	SI_PBSWT_LEAD = "軽攻撃の区間 (ms)",
	SI_PBSWT_LEAD_TOOLTIP = "サイクルが終わる何ms前から区間を始めるかを決めます。",
	SI_PBSWT_COMBAT_ONLY = "戦闘中のみ",
	SI_PBSWT_COMBAT_ONLY_TOOLTIP = "オフにすると、戦闘外でスキルを使ったあとも数秒間バーが動きます。木人での練習向けです。",

	SI_PBSWT_SECTION_BLOCK = "防御キャンセルの受付表示",
	SI_PBSWT_BLOCKCUE = "スキル直後に光らせる",
	SI_PBSWT_BLOCKCUE_TOOLTIP = "詠唱のないスキルを使った直後に、下で設定した時間だけ「ブロック」を表示します。間に合えば「OK」に変わります。そのスキルの前に軽攻撃が入っていた場合は、「エクセレント！」に変わります(軽攻撃 → スキル → ブロックがすべてつながった状態です)。枠の下に、スキルからブロックまでの時間が出ます。エクセレントのときは、軽攻撃からブロックまでの合計時間も出ます。チャネリングや詠唱のあるスキルは、ブロックで中断されてしまうため表示しません。",
	SI_PBSWT_WINDOW = "受付時間 (ms)",
	SI_PBSWT_WINDOW_TOOLTIP = "スキル使用後、「ブロック」を表示しておく時間です。",

	SI_PBSWT_SECTION_POSITION = "表示位置",
	SI_PBSWT_OFFSET_X = "横位置",
	SI_PBSWT_OFFSET_Y = "縦位置",
	SI_PBSWT_RESET = "設定をすべて初期値に戻す",
	SI_PBSWT_RESET_BUTTON = "リセット",

	SI_PBSWT_LOADED = "PB's Weave & Block Trainer %s を読み込みました。/weave でコマンド一覧を表示します。",
	SI_PBSWT_HELP = "/weave on | off -- 表示のオン・オフ\n/weave debug -- スキル・軽攻撃・ブロックの記録をチャットに出す",
	SI_PBSWT_ON = "Weave & Block Trainer をオンにしました。",
	SI_PBSWT_OFF = "Weave & Block Trainer をオフにしました。",
	SI_PBSWT_DEBUG_ON = "デバッグ記録をオンにしました。",
	SI_PBSWT_DEBUG_OFF = "デバッグ記録をオフにしました。",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
