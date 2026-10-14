local AE = AtlasAddon

AE.Translations.jp = {
    NAME = "Atlas",
    ADDON_DESCRIPTION = "The Elder Scrolls Online 向けの Torfason × Atlas アドオン。タムリエルの探索に応じてワールドマップを明らかにします。",
    PREFIX = "|cD8B36A[Atlas]|r ",
    LOADED = "を読み込みました。コマンド一覧は /atlas help で確認できます。",
    HELP = [[
|cD8B36AAtlas – コマンド|r
/atlas – Atlas の設定を開く
/atlas help – このヘルプを表示
/atlas on – Atlas を有効にする
/atlas off – Atlas を無効にする
/atlas reveal – 現在のマップをすべて開示
/atlas forget – 現在のマップの探索データを削除
/atlas import – 現在のキャラクターの TrueExploration データを読み込む
/atlas importall – 見つかったすべての TrueExploration プロファイルを統合
/atlas status – 現在のマップ情報を表示
/atlas archive – Atlas のマップ記録を開く
/atlas settings – 設定を開く
/atlas style <1-6> – 未探索マップのデザインを選択
/atlas radius <1-8> – 開示半径をマス数で設定
/atlas opacity <10-100> – 未探索部分の不透明度（%）を設定
/ae も短縮コマンドとして使えます。

ドイツ語のコマンドも使えます（例：/atlas hilfe、/atlas an、/atlas aufdecken）。
]],
    ENABLED = "Atlas を有効にしました。",
    DISABLED = "Atlas を無効にしました。",
    CURRENT_MAP_REVEALED = "現在のマップをすべて開示しました。",
    CURRENT_MAP_CLEARED = "現在のマップの探索データを削除しました。",
    NO_MAP = "利用可能なマップ領域を検出できませんでした。",
    STATUS = "マップ：%s | 探索済み：%d / %d マス（%.1f%%）| デザイン：%s",
    STYLE_SET = "未探索マップのデザイン：%s",
    RADIUS_SET = "開示半径：%d マス。",
    OPACITY_SET = "不透明度：%d%%。",
    BAD_VALUE = "値が正しくありません。/atlas help を確認してください。",
    ARCHIVE_TITLE = "マップ記録",
    ARCHIVE_SUBTITLE = "Atlas が探索状況を記録したすべてのマップ。",
    ARCHIVE_COUNT = "保存されたマップ：%d 件",
    ARCHIVE_EMPTY = "探索済みのマップはまだ保存されていません。",
    ARCHIVE_PAGE = "%d / %d ページ",
    ARCHIVE_PREV = "前へ",
    ARCHIVE_NEXT = "次へ",
    ARCHIVE_VARIANT_LABEL = "マップ %d · ID %s",
    ARCHIVE_GROUP_EXPAND_HINT = "クリックして各マップや階層を表示します。",
    ARCHIVE_GROUP_COLLAPSE_HINT = "クリックしてマップのグループを閉じます。",
    ARCHIVE_FORGET = "マップを忘れる",
    ARCHIVE_FORGET_HINT = "このマップの Atlas 探索記録だけを消去します。確認画面が表示されます。",
    ARCHIVE_MAP_CLEARED = "「%s」の探索記録を消去しました。",
    ARCHIVE_OPEN_HINT = "左クリック：マップを開く。右クリック：全開示またはマップを忘れる。",
    ARCHIVE_REVEAL = "マップを全開示",
    ARCHIVE_MAP_REVEALED = "「%s」をすべて開示しました。",
    ARCHIVE_MENU_UNAVAILABLE = "マップメニューを使用できません。データは変更されていません。",
    ARCHIVE_OPEN_FAILED = "ESO の仕様により、ここから直接マップを開けません。記録は Atlas に保持されます。",
    ARCHIVE_UNRESOLVED = "このマップの記録はありますが、ESO のマップ ID とまだ一致していません。次に訪れたとき自動で関連付けます。",
    ARCHIVE_RESOLVING = "古いマップ記録を ESO のマップ ID とバックグラウンドで照合しています…",
    ARCHIVE_PATH = "保存名：%s",
    ARCHIVE_UNKNOWN_MAP = "不明なマップ",
    IMPORT_NO_TE = "TrueExploration のデータが読み込まれていません。Atlas と一緒に TrueExploration を有効にし、UI を再読み込みしてから再試行してください。",
    IMPORT_START = "TrueExploration のインポートを確認中…",
    IMPORT_DONE = "インポート完了：検出 %d マップ、統合 %d マップ、追加 %d マス、未認識 %d 件。",
    IMPORT_NONE = "現在のキャラクターの TrueExploration プロファイルが見つかりません。Atlas と TrueExploration を有効にして UI を再読み込みしてください。",
    IMPORT_NONE_ALL = "TE_SavedVars に TrueExploration のマップテーブルが見つかりません。",
    IMPORT_ALL_WARNING = "見つかったすべての TrueExploration プロファイルを現在のキャラクターに統合します。",
    STYLE_NAMES = { "羊皮紙", "明るい紙", "暗い羊皮紙", "灰色の霧", "木炭", "漆黒" },
    STYLE_VALUES = AE.LanguageStyleValues,
    STYLE_TOOLTIPS = {
        "羊皮紙 – 色あせた羅針盤と航路の図柄がある古い探検地図",
        "明るい紙 – 細かな測量線と目盛りが描かれた地図用紙",
        "暗い羊皮紙 – 海岸線と折り目が薄れた古い海図",
        "灰色の霧 – かすかな等高線と柔らかな霧に包まれた地図",
        "木炭 – 手描きの道と古い目印が残る粗い木炭紙",
        "漆黒 – 控えめな星と航海図案が浮かぶ神秘的な夜の地図",
    },
    OPTION_LANGUAGE = "言語",
    OPTION_LANGUAGE_TT = "Atlas の表示言語だけを変更します。自動の場合は ESO に合わせます。ESO や他のアドオンの言語は変更しません。",
    LANGUAGE_AUTO = "自動（ESO に合わせる）",
    SETTINGS_VERSION = "バージョン %s",
    SETTINGS_TITLE = "Atlas - 設定",
    SETTINGS_GENERAL_HEADER = "一般",
    SETTINGS_APPEARANCE_HEADER = "外観",
    SETTINGS_EXPLORATION_HEADER = "探索",
    SETTINGS_DEFAULTS = "初期設定に戻す",
    SETTINGS_DEFAULTS_TT = "Atlas の設定を初期値に戻します。保存済みの探索進行状況は保持されます。",
    SETTINGS_CLOSE = "閉じる",
    SETTINGS_CLOSE_SHORT = "X",
    SETTINGS_GEAR_TOOLTIP = "Atlas の設定を開く",
    SETTINGS_SELECTED_STYLE = "%s：%s",
    OPTION_DESCRIPTION = "ワールドマップは未探索の状態から始まり、キャラクターが訪れた場所だけが見えるようになります。探索状況はキャラクターごとに、表示設定はアカウント共通で保存されます。",
    OPTION_ENABLED = "Atlas を有効にする",
    OPTION_ENABLED_TT = "未探索のマップ部分を覆い、旅の途中で訪れた場所を開示します。",
    OPTION_STYLE = "未探索マップのデザイン – プレビュー",
    OPTION_STYLE_TT = "プレビューをクリックして、すべてのデザインから選択できます。",
    OPTION_SELECTED = "選択中",
    OPTION_OPACITY = "未探索部分の不透明度",
    OPTION_OPACITY_TT = "100% では元のマップが完全に隠れます。値を下げるとうっすら見えるようになります。",
    OPTION_RADIUS = "開示半径 – 広域マップ",
    OPTION_RADIUS_TT = "48×48 のマス目のうち、キャラクターの周囲で表示されるマス数です。",
    OPTION_SUBZONES = "街・ダンジョン・小規模マップも探索する",
    OPTION_SUBZONES_TT = "有効にすると、小規模マップも未探索の状態から始まります。",
    OPTION_SUBRADIUS = "開示半径 – 小規模マップ",
    OPTION_SUBRADIUS_TT = "小規模マップは狭いため、広域マップより大きな開示半径を個別に設定できます。",
    OPTION_CURRENT_HEADER = "現在のマップ",
    OPTION_REVEAL = "現在のマップをすべて開示",
    OPTION_REVEAL_TT = "表示中のマップをすべて探索済みにします。",
    OPTION_CLEAR = "現在のマップを忘れる",
    OPTION_CLEAR_TT = "表示中のマップについて、Atlas の探索進行状況だけを削除します。",
    CONFIRM_CLEAR_TITLE = "マップの探索記録を忘れますか？",
    CONFIRM_CLEAR_TEXT = "「<<1>>」の Atlas 探索記録をすべて消去しますか？この操作は取り消せません。",
    CONFIRM_CLEAR_ACCEPT = "マップを忘れる",
    CONFIRM_CLEAR_CANCEL = "キャンセル",
    CONFIRM_CLEAR_UNAVAILABLE = "確認画面を表示できませんでした。探索データは削除されていません。",

    OPTION_IMPORT_HEADER = "TrueExploration インポート",
    OPTION_IMPORT_DESC = "インポートは TrueExploration のデータを読み取るだけで、変更しません。現在のキャラクターを取り込むには、TrueExploration と Atlas を有効にして UI を再読み込みしてください。Atlas は 48×48 グリッドの 31 ビット保存形式に対応し、大文字と小文字だけが異なるパスを統合します。",
    OPTION_IMPORT_CURRENT = "現在のキャラクターをインポート",
    OPTION_IMPORT_CURRENT_TT = "推奨：ログイン中のキャラクターの TrueExploration データだけを読み込みます。",
    OPTION_IMPORT_ALL = "古いプロファイルをすべて統合",
    OPTION_IMPORT_ALL_TT = "見つかったすべての TrueExploration マップを現在のキャラクターに統合します。既存の Atlas のマスは削除しません。",
    OPTION_COMMANDS_HEADER = "チャットコマンド",
    OPTION_COMMANDS = "/atlas   /atlas help   /atlas reveal   /atlas forget   /atlas import   /atlas status\n/atlas style 1-6   /atlas radius 1-8   /atlas opacity 10-100",
}
