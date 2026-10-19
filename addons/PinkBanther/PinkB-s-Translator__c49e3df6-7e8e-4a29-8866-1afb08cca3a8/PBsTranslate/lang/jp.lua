local strings = {
	SI_PBSTR_ERROR_WORD_BUDGET = "ユーザー辞書の上限は2,000枠（動詞12枠・形容詞6枠・その他1枠）・合計128KiB（英語1件192バイト、訳1件768バイト）です。保存済みの項目は削除していません。不要な項目を削除するか、長い登録内容を短くしてください。",
	SI_PBSTR_ONLY = "訳文のみ表示",
	SI_PBSTR_ONLY_TOOLTIP = "翻訳できた発言の本文を訳文に置き換えます。発言者とチャンネルは残し、翻訳できない場合は原文を表示します。",
	SI_PBSTR_HELP_ONLY = "/pbtr only on | off -- 訳文のみ表示のオン/オフ",
	SI_PBSTR_STATUS_ONLY = "訳文のみ表示: %s",
	SI_PBSTR_REPLACE_UNAVAILABLE = "訳文への置換を登録できません。原文＋訳文で表示します。",

	SI_PBSTR_COLOR = "訳文の文字色",
	SI_PBSTR_COLOR_TOOLTIP = "訳の目印と本文の色です。変更後の訳文に反映します。/pbtr color RRGGBB でも変更できます。",
	SI_PBSTR_HELP_COLOR = "/pbtr color <RRGGBB | default> -- 訳文の文字色",
	SI_PBSTR_ERROR_COLOR = "6桁の16進数（例: /pbtr color FFFF00）または default を指定してください",
	SI_PBSTR_REPLY_COLOR = "訳文の文字色: #%s",
	SI_PBSTR_COLOR_SAMPLE = "翻訳の表示サンプル",

	-- ---- チャット ----------------------------------------------------------------------
	SI_PBSTR_LINE_PREFIX = "[訳]",
	SI_PBSTR_LINE_PREFIX_EN = "[英訳]",

	-- ---- 設定パネル --------------------------------------------------------------------
	SI_PBSTR_EXPLANATION = "英語のチャットの下に日本語訳を1行表示します。アドオンはインターネットに接続できないため、翻訳はアドオン内蔵の辞書と文法規則で行います。語順を入れ替えた直訳調の訳で、自然な翻訳ではありません。",

	SI_PBSTR_DIRECTION = "翻訳の方向",
	SI_PBSTR_DIRECTION_TOOLTIP = "英語→日本語は、英語の発言の下に日本語訳を表示します。日本語→英語は、日本語の発言の下に英訳を表示します。日本語→英語は英語→日本語の辞書を逆引きして訳す直訳で、短い発言ほど正確です。/jp と /en はどちらの設定でも同じように使えます。",
	SI_PBSTR_DIRECTION_TO_JA = "英語→日本語",
	SI_PBSTR_DIRECTION_TO_EN = "日本語→英語",
	SI_PBSTR_STATUS_DIRECTION = "翻訳の方向: %s",
	SI_PBSTR_HELP_DIRECTION = "/pbtr mode en2ja | ja2en -- 翻訳の方向（英語→日本語／日本語→英語）",
	SI_PBSTR_ERROR_DIRECTION = "/pbtr mode en2ja（英語→日本語）か /pbtr mode ja2en（日本語→英語）を指定してください",

	SI_PBSTR_ENABLED = "チャットを翻訳する",
	SI_PBSTR_ENABLED_TOOLTIP = "全体スイッチです。",
	SI_PBSTR_OWN = "自分の発言",
	SI_PBSTR_OWN_TOOLTIP = "自分が入力して送信した発言がチャット欄に表示されたときに翻訳します。訳は自分にだけ表示され、送信した内容は変わりません。",
	SI_PBSTR_OTHERS = "他のプレイヤーの発言",
	SI_PBSTR_OTHERS_TOOLTIP = "他のプレイヤーの発言を翻訳します。",
	SI_PBSTR_ZONE = "ゾーンチャットも翻訳する",
	SI_PBSTR_ZONE_TOOLTIP = "人の多い場所ではゾーンチャットが大半を占めます。オフにすると、say・グループ・ギルド・ウィスパーだけを翻訳します。",
	SI_PBSTR_KNOWN = "辞書にある単語の割合",
	SI_PBSTR_KNOWN_TOOLTIP = "発言のうち、この割合以上の単語が辞書にあるときだけ翻訳します。英語以外の言語・名前・打ち間違いを除外するための設定です。下げると翻訳される行が増え、上げると訳しきれない行が減ります。",

	SI_PBSTR_SECTION_WORDS = "辞書",
	SI_PBSTR_WORDS_NOTE = "内蔵の辞書は%d項目です。下の欄か、チャットコマンドで単語を追加できます。\n/pbtr add english = 日本語\n/pbtr remove english\n/pbtr list\n/jp <英文> で自分だけに訳を表示します。",

	-- ---- 状態表示 ----------------------------------------------------------------------
	SI_PBSTR_WORD_ENGLISH = "英語",
	SI_PBSTR_WORD_ENGLISH_TOOLTIP = "登録する単語や言い回しを、チャットに書かれる形で入力します。大文字と小文字は区別しません。",
	SI_PBSTR_WORD_JAPANESE = "日本語",
	SI_PBSTR_WORD_JAPANESE_TOOLTIP = "訳を入力します。動詞と形容詞は辞書形（走る、静か）で入力してください。",
	SI_PBSTR_WORD_POS = "品詞",
	SI_PBSTR_WORD_POS_TOOLTIP = "動詞や形容詞は品詞を選ぶと、文に合わせて活用します。「そのまま」は入力した日本語をそのまま表示します。",
	SI_PBSTR_POS_X = "そのまま（決まり文句）",
	SI_PBSTR_POS_N = "名詞",
	SI_PBSTR_POS_GODAN = "動詞・五段（走る、話す）",
	SI_PBSTR_POS_ICHIDAN = "動詞・一段（食べる、見る）",
	SI_PBSTR_POS_SURU = "動詞・する（攻撃する）",
	SI_PBSTR_POS_AI = "形容詞・い（強い）",
	SI_PBSTR_POS_ADJ_NA = "形容詞・な（静か）",
	SI_PBSTR_WORD_ADD = "辞書に登録",
	SI_PBSTR_WORD_ADD_TOOLTIP = "上の英語と日本語を登録します。同じ英語がすでに登録されていれば置き換えます。登録した単語は内蔵の辞書より優先されます。",
	SI_PBSTR_WORD_HINT = "英語と日本語を入力して「辞書に登録」を押してください。",
	SI_PBSTR_WORD_LIST = "登録した単語",
	SI_PBSTR_WORD_LIST_TOOLTIP = "登録した単語の一覧です。削除する単語を選びます。",
	SI_PBSTR_WORD_REMOVE = "選んだ単語を削除",
	SI_PBSTR_WORD_REMOVE_TOOLTIP = "「登録した単語」で選んだ単語を削除します。",
	SI_PBSTR_ERROR_WORD_EMPTY = "英語と日本語の両方を入力してください。",
	SI_PBSTR_ERROR_WORD_CHARS = "日本語に / と = は使えません。",

	SI_PBSTR_ON = "オン",
	SI_PBSTR_OFF = "オフ",
	SI_PBSTR_STATUS_NOT_INSTALLED = "チャットの受信処理が登録されていません。翻訳は行われません",
	SI_PBSTR_STATUS_TARGETS = "自分 %s、他の人 %s、ゾーン %s、既知語の割合 %d%%",
	SI_PBSTR_STATUS_DICTIONARY = "辞書: 内蔵 %d項目、追加 %d項目",
	SI_PBSTR_STATUS_COUNTS = "このセッション: 対象 %d件、翻訳 %d件、見送り %d件、エラー %d件",
	SI_PBSTR_STATUS_LAST_ERROR = "直近のエラー: %s",

	SI_PBSTR_REPLY_ADDED = "追加しました: %s = %s",
	SI_PBSTR_REPLY_REMOVED = "削除しました: %s",
	SI_PBSTR_REPLY_NO_WORDS = "追加した単語はありません",
	SI_PBSTR_REPLY_KNOWN = "(%d / %d 語が辞書にありました)",

	SI_PBSTR_ERROR_ADD_FORMAT = "/pbtr add english = 日本語 の形で入力してください（日本語の前に n: v: a: adv: で品詞を指定できます）",
	SI_PBSTR_ERROR_POS = "品詞が不明です: %s（n, v, a, adv, pn, x のいずれか）",
	SI_PBSTR_ERROR_NOT_FOUND = "追加した単語にありません: %s",
	SI_PBSTR_ERROR_ON_OR_OFF = "on か off を指定してください",
	SI_PBSTR_ERROR_PERCENT = "0〜100の数値を指定してください",
	SI_PBSTR_ERROR_UNKNOWN = "不明なコマンドです: %s",

	SI_PBSTR_HELP_TRANSLATE = "/jp <英文> -- 自分だけに訳を表示",
	SI_PBSTR_HELP_STATUS = "/pbtr -- 状態を表示",
	SI_PBSTR_HELP_MASTER = "/pbtr on | off -- 翻訳のオン/オフ",
	SI_PBSTR_HELP_OWN = "/pbtr own on | off -- 自分の発言",
	SI_PBSTR_HELP_OTHERS = "/pbtr others on | off -- 他のプレイヤーの発言",
	SI_PBSTR_HELP_ZONE = "/pbtr zone on | off -- ゾーンチャットを含める",
	SI_PBSTR_HELP_KNOWN = "/pbtr known <0-100> -- 必要な既知語の割合",
	SI_PBSTR_HELP_ADD = "/pbtr add english = 日本語 -- 単語や言い回しを追加",
	SI_PBSTR_HELP_REMOVE = "/pbtr remove english -- 追加した単語を削除",
	SI_PBSTR_HELP_LIST = "/pbtr list -- 追加した単語の一覧",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
