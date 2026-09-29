Scrollkeeper = Scrollkeeper or {}
Scrollkeeper.Localization = Scrollkeeper.Localization or {}

--------------------------------------------------------------------------------
-- FRAMEWORK CORE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperFramework"] = {
  FRAMEWORK_LOADED = "Scrollkeeperフレームワークが正常に読み込まれました",
  CRITICAL_ERROR = "致命的エラー：設定パネルを作成できませんでした！",
  ERROR_REGISTERING = "設定の登録中にエラーが発生しました",
  LAM2_UNAVAILABLE = "LibAddonMenu2が利用できません！",
  ALREADY_INITIALIZED = "既に初期化されています。スキップします...",
  CHAT_BUTTONS_DISABLED = "LibChatMenuButtonが利用できません - チャットボタンが無効化されました",
  HEADER_DESC = "拡張ライブラリ統合を備えたScrollkeeper Guild Toolsのコアフレームワーク。個々のモジュールには独自の設定があり、リロードは不要です。",
  DONATE_BUTTON = "開発を支援",
  DONATE_TOOLTIP = "PC/NAの@WolfStar07に寄付を送り、継続的な開発を支援してください",
  OPEN_ALL_WINDOWS = "すべてのScrollkeeperウィンドウを開く",
  OPEN_SETTINGS = "Scrollkeeper設定を開く",
  DISPLAY_NAME = "|cF5DA81Scrollkeeper Guild Tools|r",
}

--------------------------------------------------------------------------------
-- COLOR THEMES
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperColorThemes"] = {
  -- Main
  SUBMENU_NAME = "カラーテーマ",
  DESCRIPTION = "Scrollkeeperのインターフェース要素用の事前定義されたカラーテーマから選択します。",
  ACTIVE_THEME = "アクティブテーマ",
  ACTIVE_THEME_TOOLTIP = "Scrollkeeperインターフェース要素に適用するカラーテーマを選択します。",
  CURRENT_THEME = "現在のテーマ：%s",
  
  -- Preview Section
  PREVIEW_HEADER = "カラープレビュー：",
  BORDER_COLOR = "境界線の色",
  BORDER_DESC = "ウィンドウの境界線とエッジ",
  HEADER_COLOR = "ヘッダーの色",
  HEADER_DESC = "タイトルバーと列ヘッダー",
  TEXT_COLOR = "テキストの色", 
  TEXT_DESC = "主要テキストとラベル",
  ACCENT_COLOR = "アクセントカラー",
  ACCENT_DESC = "ハイライトされたボタンと選択",
  NOTE = "注：テーマの変更は、開いているすべてのScrollkeeperウィンドウに即座に適用されます。",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperColorThemes]|r エラー：ScrollkeeperFrameworkが見つかりません！",
  
  -- Theme Names
  THEME_EMBER = "残り火",
  THEME_FORGE = "鍛冶場",
  THEME_OCEAN = "海洋",
  THEME_SKY = "空",
  THEME_REGALIA = "レガリア",
  THEME_BRIAR = "ブライアー",
  THEME_JUNGLE = "ジャングル",
  
  -- Status Messages
  STATUS_UNKNOWN = "不明",
}

--------------------------------------------------------------------------------
-- PROVISIONAL MEMBER TRACKING
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperProvisionMember"] = {
  SUBMENU_NAME = "仮メンバー追跡",
  DESCRIPTION = "試用ランクのギルドメンバーと寄付要件を満たしていないメンバーを追跡します。|cFFD700/sgtprovision|rを使用して管理ウィンドウを開きます。",
  MASTER_ENABLE = "仮メンバー追跡を有効化（マスター）",
  MASTER_ENABLE_TIP = "すべての仮メンバー追跡機能のマスタースイッチ。",
  OPEN_ADMIN = "管理ウィンドウを開く",
  OPEN_ADMIN_TIP = "仮メンバー管理ウィンドウを開く",
  CLEAR_SCAN = "不正なデータをクリアしてスキャン",
  CLEAR_SCAN_TIP = "誤って追跡されたメンバーをクリアし、新しいメンバーをスキャンします",
  RESET_GOLD = "ゴールド削除をリセット",
  RESET_GOLD_TIP = "すべてのゴールドベースの削除フラグをクリアし、メンバーをゴールド追跡のために再評価できるようにします",
  STATUS_TRACKING = "現在追跡中：%d名のアクティブな仮メンバー",
  STATUS_RANK_REMOVED = "永久削除（ランク）：%d名のメンバー",
  STATUS_GOLD_REMOVED = "一時削除（ゴールド）：%d名のメンバー",
  WINDOW_OPENED_MESSAGE = "ウィンドウが開きました。|cFFFFFFスキャン|rボタンを使用して、追跡が必要なメンバーを確認してください。",
    
  -- Window UI
  WINDOW_TITLE = "仮メンバー管理",
  SELECT_GUILD = "ギルドを選択：",
  FILTER_LABEL = "フィルター：",
  MEMBER_NAME = "メンバー名",
  DAYS = "日数",
  STATUS = "追跡状態",
  NOTES = "メモ",
  ACTIONS = "アクション",
    
  -- Guild Settings
  ENABLE_FOR_GUILD = "%sを有効化",
  ENABLE_FOR_GUILD_TIP = "このギルドの仮メンバー追跡を有効にします。",
  AUTO_TAG = "新しいメンバーを自動タグ",
  AUTO_TAG_TIP = "追跡基準を満たすメンバーを自動的にタグ付けします。",
  NOTIFY_JOIN = "メンバー加入時に通知",
  NOTIFY_JOIN_TIP = "このギルドの新しいメンバーの通知を表示します。",
  PROBATION_DAYS = "試用期間（日数）",
  PROBATION_DAYS_TIP = "メンバーが昇格前に試用状態にとどまる日数。",
    
  -- Gold Tracking
  GOLD_HEADER = "ゴールド要件の追跡",
  INACTIVITY_HEADER = "非アクティブ追跡",
  DONOR_HEADER = "寄付者の認識",
  GOLD_ENABLE = "ゴールド寄付フィルターを有効化",
  GOLD_ENABLE_TIP = "寄付要件を満たしていないメンバーを追跡します。",
  GOLD_AMOUNT = "必要な寄付額",
  GOLD_AMOUNT_TIP = "メンバーが期間内に寄付する必要があるゴールドの量（例：5k会費の場合は5000）。",
  GOLD_PERIOD = "期間（日数）",
  GOLD_PERIOD_TIP = "寄付を確認する日数（例：月次会費の場合は30、週次の場合は7）。",
  STATUS_PENDING_DONATION = "寄付待ち",
  SOURCE_MANUAL = "手動",
  TIP_DAYS_MANUAL = "^ = 手動寄付記録を含む",
    
  -- Statistics
  GUILD_STATS = "ギルド統計",
  NO_MEMBERS = "このギルドで現在追跡されている仮メンバーはいません",
  STATS_FORMAT = "%d名のメンバーを追跡中：%d名がアクティブ、%d名が期限超過、%d名が昇格",
  RECENT_ADDITIONS = "最近の追加（過去7日間）：%d名",
  
  -- Integration Status
  INTEGRATION_HEADER = "加入時間データソースと統合",
  AMT_AVAILABLE = "Advanced Member Tooltip - 最も正確な加入時間が利用可能",
  AMT_UNAVAILABLE = "Advanced Member Tooltip - インストールされていません",
  AMT_INSTALL = "インストール先：esoui.com/downloads/info2351",
  AMT_DESC = "最も正確なギルド加入時間追跡を提供します",
  LH_READY = "LibHistoire - 準備完了でギルド履歴を処理中",
  LH_MISSING = "LibHistoire - 見つかりません（必須の依存関係）",
  DATA_AVAILABLE = "データモジュール - ゴールド寄付追跡が有効",
  DATA_UNAVAILABLE = "データモジュール - ゴールドフィルタリングが利用不可",
    
  -- Symbol Legend
  SYMBOL_LEGEND = "日数列のシンボル：",
  SYMBOL_AMT = "* = AMTデータ（最も正確）",
  SYMBOL_HISTOIRE = "~ = LibHistoireギルド履歴",
  SYMBOL_DONATION = "? = 最初の寄付推定",
  SYMBOL_TAGGED = "! = 追跡開始時刻",
  SYMBOL_VALIDATED = "（シンボルなし）= 検証済み保存データ",
  SYMBOL_UNKNOWN = "不明 = 不明/信頼できないソース",
  SYMBOL_FOOTER = "日数値にカーソルを合わせると、詳細なソース情報が表示されます。",
  TIP_SORT_NAME = "クリックして名前で並べ替え",
  TIP_SORT_DAYS = "クリックして参加日数で並べ替え",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "[ScrollkeeperProvisionMember] エラー：フレームワークが見つかりません！",
  ERROR_NO_GUILD_SELECTED = "ギルドが選択されていません",
  ERROR_MAIL_UNAVAILABLE = "ScrollkeeperNotebookMailが利用できません",
  ERROR_NO_MEMBERS_TO_MAIL = "メールを送信するメンバーがいません",
  ERROR_MAIL_WINDOW_FAILED = "メールウィンドウへのアクセスに失敗しました",
  ERROR_SETTINGS_UNAVAILABLE = "設定が利用できません",
  ERROR_NO_GUILDS = "利用可能なギルドがありません。ギルドごとの設定を構成するには、ギルドに参加してください。",
   
  -- Success Messages
  SUCCESS_AMT_DETECTED = "Advanced Member Tooltipが検出されました - 拡張追跡が有効化されました",
  SUCCESS_HISTOIRE_READY = "LibHistoire統合が準備完了 - 正確な加入時間が利用可能",
  SUCCESS_REMOVED = "%sを追跡から削除しました",
  SUCCESS_BULK_REMOVED = "%d名のメンバーを追跡から一括削除しました",
  SUCCESS_CLEARED_DATA = "%sの追跡データをクリアしました",
  SUCCESS_CLEARED_GOLD = "%d個のゴールドベースの削除フラグをクリアしました",
  SUCCESS_MAIL_OPENED = "%sから%d名の仮メンバーでメールウィンドウを開きました",
  
  -- Status Messages
  STATUS_DISABLED = "仮追跡が無効になっています",
  STATUS_NO_DATA = "データが利用できません",
  STATUS_NO_TRACKING = "追跡データが利用できません",
  STATUS_SELECT_GUILD = "統計を表示するにはギルドを選択してください",
  STATUS_NO_FILTER_MATCH = "現在のフィルター基準に一致するメンバーはいません。",
  STATUS_NO_SELECTED = "昇格用に選択されたメンバーはいません",
  STATUS_NO_SELECTED_REMOVE = "削除用に選択されたメンバーはいません",
  
  -- Notes column - color coding descriptions (for tooltip if needed)
  NOTES_COLOR_DONATION = "緑：寄付情報",
  NOTES_COLOR_OFFLINE = "オレンジ：オフライン情報",
  NOTES_COLOR_NO_DONATION = "赤：寄付が見つかりません",
  
  -- Button Labels
  BTN_REFRESH = "更新",
  BTN_REFRESH_TIP = "ギルドデータとメンバーリストを更新",
  BTN_EXPORT = "エクスポート",
  BTN_EXPORT_TIP = "メンバーデータをコピー可能なテキストウィンドウにエクスポート",
  BTN_SCAN = "スキャン",
  BTN_SCAN_TIP = "新しい仮メンバーのギルドリストをスキャン",
  BTN_VIEW_SELECTED = "選択を表示",
  BTN_VIEW_ALL = "すべて表示",
  BTN_VIEW_SELECTED_TIP = "すべてのメンバーと選択されたメンバーのみの表示を切り替え",
  BTN_PROMOTE_ALL = "すべて昇格",
  BTN_PROMOTE_ALL_TIP = "ハイライトされたメンバーを昇格するためにギルドリストを開く。",
  BTN_REMOVE_ALL = "すべて削除",
  BTN_REMOVE_ALL_TIP = "選択されたすべてのメンバーを追跡から削除",
  BTN_MAIL_SELECTED = "選択者にメール",
  BTN_MAIL_SELECTED_TIP_HIGHLIGHTED = "選択されたメンバーでメールウィンドウを開く（%d名）",
  BTN_MAIL_SELECTED_TIP_FILTERED = "フィルターされたメンバーでメールウィンドウを開く",
  BTN_SELECT_ALL = "すべて選択",
  BTN_CLOSE = "閉じる",
  
  -- Filter Labels
  FILTER_ALL = "すべて",
  FILTER_PROBATION_ICON_TIP = "試用メンバーでフィルター",
  FILTER_GOLD_ICON_TIP = "緑：寄付情報",
  NOTES_COLOR_OFFLINE = "オレンジ：オフライン情報",
  NOTES_COLOR_NO_DONATION = "赤：寄付が見つかりません",
  
  -- Export Window
  EXPORT_TITLE = "データエクスポート - テキストを選択してコピー",
  EXPORT_INSTRUCTION = "「すべて選択」をクリックしてからCtrl+Cを使用してクリップボードにコピー",
  EXPORT_REPORT_HEADER = "%sの仮メンバーレポート",
  EXPORT_GENERATED = "生成：%s",
  EXPORT_FILTER = "フィルター：%s",
  EXPORT_VIEW_SELECTED = "表示：選択されたメンバーのみ",
  EXPORT_FILTER_ALL = "すべてのメンバー",
  EXPORT_FILTER_RANK = "試用メンバー",
  EXPORT_FILTER_GOLD = "ゴールド寄付メンバー",
  EXPORT_FILTER_CUSTOM = "フィルターされたメンバー",
  EXPORT_FORMAT = "%s | ステータス：%s | ギルド内日数：%s | 理由：%s | メモ：%s",
  EXPORT_DAYS_NA = "N/A（ゴールドフィルター）",
  EXPORT_DAYS_FORMAT = "%d（%s）",
  EXPORT_DAYS_ACTUAL = "実際",
  EXPORT_DAYS_ESTIMATED = "推定",
  EXPORT_FILTER_INACTIVE = "非アクティブメンバー",
  EXPORT_FILTER_DONOR = "アクティブな寄付者",
  
  -- Tooltips
  TIP_OPEN_ROSTER = "%sのギルド名簿を開く",
  TIP_REMOVE = "%sを追跡から削除",
  TIP_DAYS_HEADER = "ギルド加入からの日数\n\n",
  TIP_DAYS_OFFLINE_HEADER = "オフライン日数",
  TIP_DAYS_OFFLINE_DESC = "このメンバーがオフラインだった日数を表示します。\n数値が高いほど、非アクティブ期間が長いことを示します。",
  TIP_DAYS_AMT = "* = Advanced Member Tooltip（最も正確）",
  TIP_DAYS_HISTOIRE = "~ = LibHistoireギルド履歴",
  TIP_DAYS_DONATION = "? = 最初の寄付推定",
  TIP_DAYS_TAGGED = "! = 追跡開始時刻",
  TIP_DAYS_UNKNOWN = "（不明 - 信頼できるデータソースなし）",
  TIP_DAYS_GOLD = "（ゴールドフィルターメンバー）",
  TIP_DAYS_VALIDATED = "（保存データから検証済み）",
  TIP_INSTALL_AMT = "より正確な加入時間のために\nAdvanced Member Tooltipをインストール",
  TIP_REVIEW_KICK = TIP_REVIEW_KICK = "%sを確認/キックするために名簿を開く（非アクティブメンバー）",
  TIP_REVIEW_PROMOTE = "%sを確認/キックするために名簿を開く（試用期間メンバー）",
  TIP_REVIEW_DONATION = "%sを確認するために名簿を開く（保留中の寄付）",
  TIP_PROMOTE_DONOR = "%sを昇格するために名簿を開く（貴重な貢献者）",
  FILTER_INACTIVE_TIP = "設定された期間オフラインだったメンバーを表示",
  FILTER_DONOR_TIP = "最小寄付要件を満たすメンバーを表示",
  
  -- Logging Messages
  LOG_STARTING_SCAN = "手動スキャンを開始しています...",
  LOG_SCAN_COMPLETE = "手動スキャン完了 - %d個の不正なエントリをクリア、%d名の新しいメンバーを発見",
  LOG_REFRESHED = "表示が更新されました",
  LOG_NEW_MEMBER = "新しいメンバーが%sに加入しました：%s",
  LOG_OPENING_ROSTER_PROMOTE = "昇格のためにリストを開いています：%s",
  LOG_OPENING_ROSTER_BULK = "リストを開いています - これらの%d名のメンバーを昇格：%s",
  LOG_NO_GUILD_ID = "ギルドIDが見つかりませんでした：%s",
  LOG_NO_GUILD_ID_SIMPLE = "ギルドIDが見つかりませんでした",
  LOG_FILTER_MODE = "%sモード - %d名のメンバーが選択されました",
  LOG_INITIALIZING = "初期化中 - %s",
  ERROR_DATA_NOT_READY = "ギルド履歴データはまだ準備ができていません。しばらく待ってから再試行してください。",
  LOG_SCAN_COMPLETE_SHORT = "スキャン完了！",
  
  -- Mail Integration
  MAIL_SUBJECT_GOLD = "ギルド会費リマインダー - %s",
  MAIL_RECIPIENT_COUNT = "仮受信者：%d名",
  MAIL_STATUS = "ステータス：%d名の仮メンバーがメール送信準備完了",
  
  -- Stats Display
  STATS_FORMAT_FULL = "ギルド：%s | 合計：%d | アクティブ：%d | 期限超過：%d | 昇格：%d | 試用：%d | ゴールド：%d",
  STATS_LH_READY = "準備完了",
  STATS_LH_LOADING = "読み込み中",
  
  -- Auto-tag Messages
  AUTO_TAG_SCAN = "自動タグ（スキャン）",
  AUTO_TAG_LOGIN = "自動タグ（ログインスキャン）",
  AUTO_TAG_ONLINE = "自動タグ（オンライン加入）",
  ACTIVE_DONOR = "アクティブな寄付者",
  
  -- Dropdown Messages
  DROPDOWN_NO_GUILDS = "追跡用に構成されたギルドがありません",
  
  -- Status Values
  STATUS_PROVISIONAL = "仮",
  STATUS_PROMOTED = "昇格",
  
  -- Reason Values
  REASON_RANK = "ランク",
  REASON_GOLD = "ゴールド",
  REASON_INACTIVE = "非アクティブ",
  REASON_DONOR = "寄付者",
  
  -- Integration Status (detailed)
  INTEGRATION_AMT_INSTALL_URL = "esoui.com/downloads/info2351",
  INTEGRATION_STATUS = "統合されたアドオンとデータソースのステータス：",
  
  -- Member Count Status
  MEMBER_COUNT_STATUS = "メンバー数ステータス",
  MEMBER_COUNT_FORMAT = "現在追跡中：%d名のアクティブな仮メンバー\n永久削除（ランク）：%d名のメンバー\n一時削除（ゴールド）：%d名のメンバー",
  
  -- Sources
  SOURCE_AMT = "amt",
  SOURCE_HISTOIRE = "histoire",
  SOURCE_DONATION = "寄付",
  SOURCE_TAGGED = "タグ付き",
  SOURCE_STORED = "保存済み",
  SOURCE_UNKNOWN = "不明",
  SOURCE_DATA = "データ",
  
  -- Days display values
  DAYS_UNKNOWN = "不明",
  DAYS_ERROR = "エラー",
  DAYS_NA = "-",
    
  -- Inactivity Filter Settings
  INACTIVITY_ENABLE = "非アクティブメンバーを追跡",
  INACTIVITY_ENABLE_TIP = "長期間オフラインだったメンバーを自動的に追跡",
  INACTIVITY_DAYS = "非アクティブまでの日数",
  INACTIVITY_DAYS_TIP = "この日数ログインしていない場合、メンバーを非アクティブと見なす",
  
  -- Settings - Donor Filter
  DONOR_ENABLE = "アクティブな寄付者を追跡",
  DONOR_ENABLE_TIP = "最小寄付要件を満たすか超えるメンバーを追跡（貢献者を認識するのに便利）",
  DONOR_AMOUNT = "最小寄付額",
  DONOR_AMOUNT_TIP = "アクティブな寄付者と見なされるために必要なゴールド額",
  DONOR_PERIOD = "期間（日数）",
  DONOR_PERIOD_TIP = "過去X日間の寄付を確認",
  MANUAL_SCAN_NOTE = "注：メンバー追跡には手動スキャンが必要です。暫定メンバーウィンドウを開き、スキャンボタンをクリックして追跡が必要なメンバーを確認してください。",
}

--------------------------------------------------------------------------------
-- GUILD MAIL
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperNotebookMail"] = {
  SUBMENU_NAME = "ギルドメール",
  DESCRIPTION = "テンプレート統合による一括メール作成。メール送信は自動的に3.1秒間隔に制限されます。|cFFD700/sgtmail|rを使用してメールウィンドウを開きます。",
  ENABLE_MAIL = "ギルドメールを有効化",
  ENABLE_MAIL_TIP = "ギルドメール機能をオン/オフに切り替えます。",
  OPEN_MAIL = "メールウィンドウを開く",
  OPEN_MAIL_TIP = "クリックしてメール作成ウィンドウを開きます。",
    
  -- Window UI
  WINDOW_TITLE = "Scrollkeeperギルドメール",
  MAIL_TEMPLATES = "メールテンプレート：",
  SELECT_TEMPLATE = "-- テンプレートを選択 --",
  GUILD_LABEL = "ギルド：",
  RANK_FILTER = "ランクフィルター：",
  ALL_RANKS = "すべてのランク",
  PROVISIONAL_LABEL = "仮メンバー：",
  ALL_PROVISIONAL = "すべての仮",
  GOLD_ONLY = "ゴールドフィルターのみ",
  RANK_ONLY = "ランクフィルターのみ",
  USE_PROVISIONAL = "仮リストを使用",
  KICK_AFTER_MAIL = "メール送信後に削除:",
  KICK_NO = "削除しない",
  KICK_YES = "メール送信後に削除",
  KICK_NO_PERMISSION = "このギルドからメンバーを削除する権限がありません",
  MEMBER_KICKED = "キック済み: %s",
  MEMBER_NOT_FOUND = "ギルド名簿でメンバー %s が見つかりませんでした",
  PREVIEW_TITLE = "メールプレビュー",
  PREVIEW_MAIL = "プレビュー",
    
  -- Composition
  SUBJECT_LABEL = "件名：",
  BODY_LABEL = "メッセージ本文：",
  READY_TO_SEND = "送信準備完了",
  STATUS_READY = "ステータス：準備完了",
  RECIPIENTS = "受信者：%d名",
    
  -- Buttons
  SAVE_TEMPLATE = "テンプレートを保存",
  PREVIEW_RECIPIENTS = "受信者をプレビュー",
  SEND_MAIL = "メールを送信",
  PAUSE = "一時停止",
  RESUME = "再開",
    
  -- Status Messages
  NO_GUILD = "ステータス：最初にギルドを選択してください",
  NO_SUBJECT = "ステータス：件名を入力してください",
  NO_BODY = "ステータス：メッセージ本文を入力してください",
  NO_RECIPIENTS = "ステータス：受信者が見つかりません",
  STARTING = "ステータス：メール送信を開始しています...",
  SENDING = "送信中 %d/%d",
  SENDING_TO = "宛先：%s",
  SUCCESS = "ステータス：メールが正常に送信されました",
  FAILED = "ステータス：失敗 - %s",
  PAUSED = "ステータス：一時停止中",
  COMPLETED = "完了：%d件送信、%d件失敗",
  TEMPLATE_SAVED = "ステータス：テンプレートが保存されました",
  TEMPLATE_FAILED = "ステータス：テンプレートの保存に失敗しました",
  NEED_SUBJECT_BODY = "ステータス：件名と本文を入力してください",
  RECIPIENTS_FOUND = "ステータス：%d名の受信者が見つかりました",
  NO_MATCH_FILTERS = "ステータス：フィルターに一致する受信者はいません",
  PROVISIONAL_SELECTED = "ステータス：%d名の仮メンバーが選択されました",
  NO_PROVISIONAL = "ステータス：仮メンバーが見つかりません",
  USING_PROVISIONAL = "ステータス：仮メンバーリストを使用しています...",
    
  -- Failure Reasons
  RECIPIENT_NOT_FOUND = "受信者が見つかりません",
  MAILBOX_FULL = "メールボックスがいっぱいです",
  IGNORED = "受信者がメールを無視しています",
  BLANK_MAIL = "空のメールは許可されていません",
  UNKNOWN_ERROR = "不明なエラー",
  
  -- Character count display
  CHAR_COUNT = "%d/%d",
  
  -- Provisional member filter type display
  PROVISION_FILTER_ALL = "すべて",
  PROVISION_FILTER_GOLD = "ゴールド", 
  PROVISION_FILTER_RANK = "ランク",
  
  -- Auto-generated subject for gold filter
  DUES_REMINDER_SUBJECT = "ギルド会費リマインダー - %s",
  
  -- Failure log content
  FAILURE_LOG_TITLE = "メール送信失敗レポート",
  FAILURE_LOG_DATE = "日付：%s",
  FAILURE_LOG_SUBJECT_LINE = "件名：%s",
  FAILURE_LOG_TOTAL_SENT = "送信総数：%d",
  FAILURE_LOG_TOTAL_FAILED = "失敗総数：%d",
  FAILURE_LOG_FAILED_LIST = "失敗した受信者：",
  FAILURE_LOG_SEPARATOR = string.rep("-", 50),
  FAILURE_LOG_BODY_HEADER = "元のメッセージ本文：",
  FAILURE_LOG_SAVED = "失敗ログがノートブックに保存されました：「%s」",
  FAILURE_LOG_SAVE_FAILED = "ノートブックへの失敗ログの保存に失敗しました",
  FAILURE_LOG_NO_NOTEBOOK = "失敗ログを保存できません - ノートブックが利用できません",
  
  -- Mail tags
  TAG_MAIL = "メール",
  TAG_TEMPLATE = "テンプレート",
  TAG_MAIL_LOG = "メールログ",
  TAG_FAILURES = "失敗",

  -- Failure log
  FAILURE_LOG_TITLE_FORMAT = "メール送信失敗 - %s",
}

--------------------------------------------------------------------------------
-- NOTEBOOK
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperNotebook"] = {
  -- Main
  SUBMENU_NAME = "ノートブック設定",
  WINDOW_TITLE = "Scrollkeeperノートブック",
    
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperNotebook]|r エラー：ScrollkeeperFrameworkが見つかりません！",
  ERROR_ALREADY_INIT = "|cFFD700[ScrollkeeperNotebook]|r 既に初期化されています。スキップします...",
  ERROR_WINDOW_EXISTS = "|cFFD700[ScrollkeeperNotebook]|r ウィンドウは既に存在します。既存のものを返します",
  ERROR_DROPDOWN_FAILED = "|cFFD700[ScrollkeeperNotebook]|r 警告：ドロップダウンを作成できませんでした",
  ERROR_WINDOW_NOT_INIT = "ノートブックウィンドウが初期化されていません。",
  ERROR_NO_NOTE_ENTRY = "%sのノートエントリがありません。",
  ERROR_DISABLED = "|cFFD700[ScrollkeeperNotebook]|r ノートブックが無効になっています",
  ERROR_NO_TITLE = "|cFFD700[ScrollkeeperNotebook]|r ノートのタイトルを入力してください",
  ERROR_SAVE_FAILED = "|cFFD700[ScrollkeeperNotebook]|r ノートの保存に失敗しました",
  ERROR_TEMPLATE_NO_TITLE = "|cFFD700[ScrollkeeperNotebook]|r テンプレートのタイトルを入力してください",
    
  -- Success Messages
  SUCCESS_NOTE_SAVED = "|cFFD700[ScrollkeeperNotebook]|r ノートが保存されました：%s",
  SUCCESS_TEMPLATE_SAVED = "|cFFD700[ScrollkeeperNotebook]|r メールテンプレートが保存されました：%s",
    
  -- Window Labels
  LABEL_SEARCH = "検索：",
  LABEL_CATEGORY = "カテゴリ：",
  LABEL_SAVED_NOTES = "保存されたノート：",
  LABEL_NOTE_TITLE = "ノートタイトル：",
  LABEL_TAGS = "タグ（カンマ区切り）：",
  LABEL_NOTE_CONTENT = "ノート内容：",
  LABEL_NOTES_COUNT = "ノート：%d/%d",
  LABEL_NOTES_SIMPLE = "ノート：%d",
    
  -- Character Counts
  CHAR_COUNT_TITLE = "%d/100",
  CHAR_COUNT_BODY = "%d/5000",
    
  -- Dropdown Options
  DROPDOWN_SELECT = "-- ノートを選択 --",
  DROPDOWN_NO_MATCHES = "-- 一致するものが見つかりません --",
    
  -- Default Text
  DEFAULT_NOTE_TITLE = "新しいノート",
  DEFAULT_NOTE_BODY = "ここにノートを入力してください...",
    
  -- Button Labels
  BTN_SAVE = "保存",
  BTN_NEW = "新規",
  BTN_DELETE = "削除",
  BTN_SAVE_MAIL = "メールを保存",
  BTN_OPEN_NOTEBOOK = "ノートブックを開く",
    
  -- Button Tooltips
  TIP_OPEN_NOTEBOOK = "クリックしてノートブックウィンドウを開きます（/sgtnoteコマンドと同じ）。",
    
  -- Settings
  SETTING_ENABLE = "ノートブックモジュールを有効化",
  SETTING_ENABLE_TIP = "ノートブック機能をオン/オフに切り替えます。",
  SETTING_SEARCH = "検索フィルターを有効化",
  SETTING_SEARCH_TIP = "検索用語によるノートのフィルタリングを許可します。",
  SETTING_DEFAULT_CATEGORY = "デフォルトカテゴリ",
  SETTING_DEFAULT_CATEGORY_TIP = "新しいノートのデフォルトカテゴリ。メールテンプレートには「メール」を使用してください。",
    
  -- Descriptions
  DESC_MAIN = "検索、カテゴリ、タグ付け機能を備えたフル機能のゲーム内メモ帳。|cFFD700/sgtnote|rを使用してノートブックウィンドウを開きます。",
  DESC_MAIL_TEMPLATES = "メールテンプレート：「メール」カテゴリにノートを保存すると、ネイティブメールクライアントとギルドメールシステムの両方でテンプレートとして使用できます。",
    
  -- Mail Integration
  MAIL_LABEL_TEMPLATES = "メールテンプレート：",
  MAIL_DROPDOWN_SELECT = "-- テンプレートを選択 --",
    
  -- Categories
  CAT_GENERAL = "一般",
  CAT_MAIL = "メール",
  CAT_EVENTS = "イベント",
  CAT_ALL_CATEGORIES = "すべてのカテゴリ",

  ERROR_MAX_TOTAL_NOTES = "ノートを作成できません：最大総ノート数（%d）に達しました。最初にいくつかのノートを削除してください。",
  ERROR_MAX_CATEGORY_NOTES = "ノートを作成できません：カテゴリ'%s'の最大ノート数（%d）に達しました。",
  ERROR_NOTE_TOO_LARGE = "ノートが大きすぎます（%d文字）。最大は%d文字です。",
  STATS_HEADER = "Scrollkeeperノートブックストレージ統計",
  STATS_TOTAL = "総ノート数：%d / %d",
  STATS_CATEGORY = " %s：%d / %dノート（〜%.1f KB）",
  BTN_PREVIEW_MAIL = "プレビュー",
  PREVIEW_TITLE = "メールプレビュー",
  ERROR_NO_BODY = "本文にテキストを入力してください",
  
  -- Guild Tools Integration
  GUILDMAIL_NO_TEMPLATES   = "(テンプレートを追加するには、ノートブックで「メールとして保存」を使用してください)",
  SETTING_GUILDMAIL_INJECT = "ギルドメール作成画面にテンプレート選択欄を表示",
  SETTING_GUILDMAIL_INJECT_TIP = "ギルドメール作成ウィンドウに、ノートブックのメールテンプレート選択欄を表示します。",
}

--------------------------------------------------------------------------------
-- HISTORY
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperHistory"] = {
  -- Main
  SUBMENU_NAME = "ギルド履歴検索",
  WINDOW_TITLE = "ギルド履歴検索",
    
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperHistory]|r エラー：ScrollkeeperFrameworkが見つかりません！",
  ERROR_WINDOW_FAILED = "|cFFD700[ScrollkeeperHistory]|r ウィンドウの作成に失敗しました",
  ERROR_NO_EXPORT = "|cFFD700[ScrollkeeperHistory]|r エクスポートするイベントがありません",
    
  -- Success Messages
  SUCCESS_READY = "|cFFD700[ScrollkeeperHistory]|r 準備完了 - /sgthistoryを使用してください",
    
  -- Log Messages
  LOG_LOADING = "|cFFD700[ScrollkeeperHistory]|r 読み込み中... SF.Dataが存在します：%s",
  LOG_DATA_GETEVENTS = "|cFFD700[ScrollkeeperHistory]|r 読み込み時のSF.Data.getEvents：%s",
  LOG_DATA_UNAVAILABLE = "|cFFD700[ScrollkeeperHistory]|r SF.Data.getEventsが利用できません",
  LOG_FALLBACK_INIT = "|cFFD700[ScrollkeeperHistory]|r フォールバック初期化がトリガーされました",
    
  -- Window Labels
  LABEL_GUILD = "ギルド：",
  LABEL_CATEGORY = "カテゴリ：",
  LABEL_SEARCH = "検索：",
  LABEL_EVENTS_COUNT = "イベント：%d",
  LABEL_REFRESH = "更新",
  LABEL_EXPORT = "エクスポート",
    
  -- Status Messages
  STATUS_READY = "準備完了",
  STATUS_READY_LOADED = "準備完了 - %d件のイベントが読み込まれました",
  STATUS_NO_GUILD = "ギルドが選択されていません",
  STATUS_DATA_NOT_READY = "データモジュールの準備ができていません",
  STATUS_NO_EVENTS_CACHE = "イベントが見つかりません - キャッシュがまだ構築中の可能性があります。LibHistoireでカテゴリがアクティブであることを確認してください。",
  STATUS_WAITING_LH = "LibHistoireの初期化を待っています...",
  STATUS_ENABLE_GUILDS = "履歴設定でギルドを有効にしてください",
    
  -- Column Headers
  HEADER_TIME = "時間",
  HEADER_CATEGORY = "カテゴリ",
  HEADER_EVENT = "イベント",
  HEADER_MEMBER = "メンバー",
  HEADER_DETAILS = "詳細",
    
  -- Category Names
  CAT_ALL = "すべてのイベント",
  CAT_ROSTER = "リスト",
  CAT_BANK_GOLD = "銀行ゴールド",
  CAT_BANK_ITEMS = "銀行アイテム",
  CAT_SALES = "販売",
    
  -- Event Type Names - Roster
  EVENT_INVITED = "招待済み",
  EVENT_JOINED = "加入",
  EVENT_PROMOTED = "昇格",
  EVENT_DEMOTED = "降格",
  EVENT_LEFT = "退会",
  EVENT_KICKED = "除名",
  EVENT_APP_ACCEPTED = "申請承認済み",
    
  -- Event Type Names - Bank Gold
  EVENT_GOLD_DEPOSITED = "ゴールド預け入れ",
  EVENT_GOLD_WITHDRAWN = "ゴールド引き出し",
  EVENT_TRADER_BID = "トレーダー入札",
  EVENT_BID_RETURNED = "入札返却",
    
  -- Event Type Names - Bank Items
  EVENT_ITEM_DEPOSITED = "アイテム預け入れ",
  EVENT_ITEM_WITHDRAWN = "アイテム引き出し",
    
  -- Event Type Names - Sales
  EVENT_ITEM_SOLD = "アイテム販売",
    
  -- Unknown Event
  EVENT_UNKNOWN = "不明（%s）",
    
  -- Time Formatting
  TIME_JUST_NOW = "たった今",
  TIME_MINUTES_AGO = "%d分前",
  TIME_HOURS_AGO = "%d時間前",
  TIME_DAYS_AGO = "%d日前",
  TIME_MONTHS_AGO = "%dヶ月前",
    
  -- Export Window
  EXPORT_TITLE = "データエクスポート - テキストを選択してコピー",
  EXPORT_INSTRUCTION = "「すべて選択」をクリックしてからCtrl+Cを使用してクリップボードにコピー",
  EXPORT_SELECT_ALL = "すべて選択",
  EXPORT_HEADER = "%sのギルド履歴エクスポート",
  EXPORT_GENERATED = "生成：%s",
  EXPORT_CATEGORY = "カテゴリ：%s",
  EXPORT_TOTAL = "合計イベント数：%d",
  EXPORT_FORMAT = "%s | %s | %s | %s | %s",
    
  -- Tooltips
  TIP_REFRESH = "ギルドリストとイベントデータを更新",
  TIP_EXPORT = "表示されているイベントをテキストにエクスポート",
  TIP_FULL_TIMESTAMP = "完全なタイムスタンプ",
  TIP_FULL_DETAILS = "完全な詳細",
    
  -- Settings - Main
  SETTINGS_DESC = "キャッシュされたギルド履歴イベントを検索します。|cFFD700/sgthistory|rを使用して検索ウィンドウを開きます。\n\nデータはScrollkeeperDataによってすべてのギルドに対して自動的にキャッシュされます。ここでは、検索ウィンドウに表示するギルドとカテゴリを制御します。",
  SETTINGS_DISPLAY = "表示設定",
  SETTINGS_MAX_EVENTS = "最大イベント数",
  SETTINGS_MAX_EVENTS_TIP = "一度に読み込む最大イベント数",
  SETTINGS_SEARCH_DELAY = "検索遅延（ミリ秒）",
  SETTINGS_SEARCH_DELAY_TIP = "入力中に検索が実行されるまでの遅延",
  SETTINGS_COLOR_CODING = "カラーコーディングを有効化",
  SETTINGS_COLOR_CODING_TIP = "イベントをタイプ別に色分けする",
    
  -- Settings - Per Guild
  SETTINGS_SHOW_GUILD = "履歴ウィンドウに表示",
  SETTINGS_SHOW_GUILD_TIP = "このギルドを履歴検索ウィンドウに表示する",
  SETTINGS_CATEGORIES = "表示するイベントカテゴリ",
  SETTINGS_ROSTER_EVENTS = "リストイベント",
  SETTINGS_ROSTER_EVENTS_TIP = "メンバーの加入、退会、昇格、除名を表示",
  SETTINGS_BANK_GOLD_EVENTS = "銀行ゴールドイベント",
  SETTINGS_BANK_GOLD_EVENTS_TIP = "ゴールドの預け入れ、引き出し、トレーダー入札を表示",
  SETTINGS_BANK_ITEMS_EVENTS = "銀行アイテムイベント",
  SETTINGS_BANK_ITEMS_EVENTS_TIP = "アイテムの預け入れと引き出しを表示",
  SETTINGS_SALES_EVENTS = "販売イベント",
  SETTINGS_SALES_EVENTS_TIP = "ギルドストアの販売を表示",
    
  -- Dropdown
  DROPDOWN_NO_GUILDS = "有効なギルドがありません - 設定を確認してください",
    
  -- Formatting
  FORMAT_GOLD = "%sゴールド",
  FORMAT_QUANTITY_ITEM = "%dx %s",
  FORMAT_SOLD_TO = "%sに",
  FORMAT_RANK_ARROW = "→",
  MANUAL_ENTRY_TOOLTIP = "これは手動で記録された寄付です",
  NOTES_LABEL = "メモ",
  DELETE_MANUAL_ENTRY = "この手動エントリを削除",
  SUCCESS_DELETED_ENTRY = "手動エントリが正常に削除されました",
  ERROR_DELETE_FAILED = "エントリの削除に失敗しました",
    
  -- Member Names
  MEMBER_UNKNOWN = "不明",
    
  LOG_LIBSCROLL_NOT_FOUND = "|cFFD700[ScrollkeeperHistory]|r LibScrollが見つかりません - 基本スクロールを使用します",
}

--------------------------------------------------------------------------------
-- ROSTER
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperRoster"] = {
  -- Main
  SUBMENU_NAME = "リスト拡張",
    
  -- Settings
  SETTING_TRADER_TIMER = "トレーダー入れ替えタイマーを表示",
  SETTING_TRADER_TIMER_TIP = "次のギルドトレーダー入れ替えまでの時間を示すカウントダウンタイマーを表示します。\n\n" ..
                              "タイマーの色は緊急度を示します：\n" ..
                              "• |c00FF0024時間以上|r- 安全\n" ..
                              "• |cFFFF006-24時間|r- 事前計画\n" ..
                              "• |cFF88002-6時間|r- すぐに行動\n" ..
                              "• |cFF00002時間未満|r- 緊急！",
  
  -- Timer Display
  TIMER_LABEL = "トレーダー入れ替え：%s",
  TIMER_FLIPPING = "現在入れ替え中",
  TIMER_FORMAT = "%d時間%d分",
    
  -- Full tooltip
  TOOLTIP_FULL = "ギルドトレーダー入れ替えまでの時間\n\n" ..
                 "色は緊急度を示します：\n" ..
                 "|c00FF0024時間以上|r - 安全\n" ..
                 "|cFFFF006-24時間|r - 事前計画\n" ..
                 "|cFF88002-6時間|r - すぐに行動\n" ..
                 "|cFF00002時間未満|r - 緊急！",
				   
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperRoster]|r エラー：ScrollkeeperFrameworkが見つかりません！",
  
  -- Tasks
  TASKS_HEADER = "タスクリマインダー",
  TASKS_DESCRIPTION = "タスクリマインダーは以下でギルドごとに設定されます。リマインダーが必要な各ギルドで「名簿にタスクを表示」を有効にしてください。",
  CUSTOM_TASKS = "カスタムタスク",
  CUSTOM_TASKS_DESC = "カスタムタスクを追加して設定します。設定パネルはリロードするまで更新されませんが、タスクはリアルタイムで追加または削除されます。",
  ADD_CUSTOM_TASK = "カスタムタスクを追加",
  REMOVE = "削除",

  -- Per-guild task toggle
  GUILD_TASKS_ENABLE = "名簿にタスクを表示",
  GUILD_TASKS_ENABLE_TIP = "このギルドの名簿ページのタスクリマインダーを有効にする",

  -- Guild configuration header
  GUILD_CONFIG_DESC = "%sのタスクリマインダーを設定",

  -- Preset tasks section
  PRESET_TASKS_HEADER = "プリセットタスク",

  -- Frequency settings
  FREQUENCY_NUMBER = "頻度（数値）",
  FREQUENCY_NUMBER_TIP = "時間単位の数を入力してください",
  FREQUENCY_UNIT = "単位",

  -- Task window
  TASK_WINDOW_TITLE = "カスタムタスクを追加",
  TASK_WINDOW_NAME_LABEL = "タスク名：",
  TASK_WINDOW_FREQ_LABEL = "頻度：",
  TASK_WINDOW_GUILD_LABEL = "ギルド（複数選択または「すべて」）：",
  TASK_WINDOW_ADD = "タスクを追加",
  TASK_WINDOW_CANCEL = "キャンセル",

  -- Task window validation messages
  ERROR_NO_TASK_NAME = "タスク名を入力してください",
  ERROR_INVALID_FREQ_NUMBER = "頻度に有効な数値を入力してください",
  ERROR_NO_FREQ_UNIT = "頻度の単位を選択してください",

  -- Task completion messages
  TASK_COMPLETED = "タスク完了：%s",
  TASK_ADDED = "タスク追加：%s（ギルド：%s、有効：true、カスタム：true）",
  TASK_REMOVED = "タスク削除：%s",
  ERROR_PRESET_REMOVE = "プリセットタスクは削除できません。代わりに設定で無効にしてください。",

  -- Task list display
  TASK_STATUS_OVERDUE = "期限切れ",

  -- Tooltip for task labels
  TASK_TOOLTIP_LEFT = "左クリック：タスクを完了",
  TASK_TOOLTIP_RIGHT = "右クリック：タスクを削除",

  PRESET_REVIEW_APPLICATIONS = "申請を確認",
  PRESET_CHECK_BANK_DEPOSITS = "銀行預金を確認",
  PRESET_UPDATE_MOTD = "今日のメッセージを更新",
  PRESET_PROMOTE_PROBATIONARY = "試用メンバーを昇格",
  PRESET_REVIEW_INACTIVES = "非アクティブメンバーを確認",

  TASK_COLOR_LEGEND = "色の凡例 - 残り時間：\n|c00FF00>25%|r - 安全\n|cFFFF0010-25%|r - 事前計画\n|cFF88005-10%|r - すぐに行動\n|cFF0000<5%または期限切れ|r - 緊急！",
    
  -- Remove Button
  REMOVE_CUSTOM_TASK = "カスタムタスクを削除",
  REMOVE_CUSTOM_TASK_TIP = "完全に削除するカスタムタスクを選択",
  REMOVE_WARNING = "警告：削除は永久的です！タスクを復元するには、手動で再度追加する必要があります。",
  REMOVE_INSTRUCTION = "削除するタスクを以下からクリックしてください：",
  REMOVE_WINDOW_CANCEL = "キャンセル",
}

--------------------------------------------------------------------------------
-- CONTEXT MENU
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperContextMenu"] = {
  SUBMENU_NAME = "コンテキストメニューオプション",
  DESCRIPTION = "すべての右クリックコンテキストメニューに新しいメール、ギルド招待、チャット招待のエントリを追加します。",
  MASTER_ENABLE = "コンテキストメニュー機能を有効化",
  MASTER_ENABLE_TIP = "すべてのコンテキストメニュー拡張のマスタースイッチ。",
  SF_UNAVAILABLE = "エラー：ScrollkeeperFrameworkが見つかりません！",
    
  -- Headers
  SCROLLKEEPER_TOOLS = "Scrollkeeperツール",
  CHAT_HEADER = "チャットオプション",
  ROSTER_HEADER = "ギルドリストオプション",
    
  -- Options
  NEW_MAIL = "新しいメール",
  NEW_MAIL_TIP = "チャットコンテキストメニューに「新しいメール」オプションを追加。",
  GUILD_INVITE = "ギルド招待",
  GUILD_INVITE_TIP = "チャットコンテキストメニューにギルド招待オプションを追加。",
  ROSTER_DESC = "ギルドリストの右クリックメニューにノートブック統合を追加します。",
  NOTEBOOK_CONTEXT = "ノートブックコンテキストメニューを有効化",
  NOTEBOOK_CONTEXT_TIP = "ギルドメンバーを右クリックしてノートブックエントリを開くか作成します。",
  ROSTER_INVITE = "リストからギルド招待",
  ROSTER_INVITE_TIP = "ギルドリストコンテキストメニューにギルド招待オプションを追加。",
    
  -- Context Menu Items
  INVITE_TO = "%sに招待",
  GO_TO_NOTEBOOK = "ノートブックエントリに移動",
  MAKE_NOTE = "ノートブックノートを作成",
    
  -- Messages
  NOTEBOOK_NOT_FOUND = "ノートブックモジュールが見つかりません。",
  NOTE_EXISTS = "%sのノートは既に存在します。",
  NOTE_CREATED = "%sのノートがノートブックに作成されました。",
  OPEN_NOTE = "ノートブックエントリを開く",
  CREATE_NOTE = "ノートブックノートを作成",
  LOG_CONVERSATION = "最近のチャットを記録",
  CONVERSATION_LOGGED = "%sとの最近の%d件のメッセージを「チャット」カテゴリのノートブックに記録しました",
  NO_CONVERSATION = "最後の100メッセージで%sに関する最近のチャットが見つかりませんでした。",
  LOG_CONVERSATIONS = "会話ログを有効化",
  LOG_CONVERSATIONS_TIP = "チャット会話をノートブックに記録します（pChatアドオンが必要）。",
  PCHAT_WARNING = "pChatアドオンが検出されませんでした - この機能は動作しません",
    
  -- Mail Items
  LOG_DONATION = "寄付を記録",
  LOG_DONATION_TIP = "このプレイヤーの寄付を手動で記録する",
  DONATION_WINDOW_TITLE = "手動寄付の記録",
  DONATION_PLAYER = "プレイヤー",
  DONATION_GUILD = "ギルド",
  DONATION_VALUE_LABEL = "ゴールド価値",
  DONATION_VALUE_TIP = "この寄付のゴールド価値を入力してください（アイテムの場合は推定価値を入力）",
  DONATION_NOTES_LABEL = "メモ（任意）",
  DONATION_NOTES_TIP = "「ドラウグワックス50個をメールで送信」や「12月25日にゴールド送信」などの追加詳細",
  DONATION_TYPE_LABEL = "寄付タイプ",
  DONATION_TYPE_GOLD = "ゴールド（メール）",
  DONATION_TYPE_ITEMS = "アイテム（評価済み）",
  BTN_RECORD_DONATION = "寄付を記録",
  BTN_CANCEL = "キャンセル",
  SUCCESS_DONATION_LOGGED = "%sに%dゴールドの寄付を記録しました",
  ERROR_INVALID_AMOUNT = "有効なゴールド金額を入力してください",
}

--------------------------------------------------------------------------------
-- DATA MODULE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperData"] = {
  -- Module Info
  DESCRIPTION = "LibHistoireを使用したギルド履歴データのバックグラウンドキャッシングサービス。",
    
  -- Status Messages
  HISTOIRE_READY = "LibHistoire準備完了 - すべてのギルド履歴をキャッシング中",
  CACHE_STATUS = "=== イベントキャッシュステータス ===",
  NO_CACHED_DATA = "キャッシュされたデータが見つかりません",
  CACHE_EMPTY = "キャッシュが空です - 初回読み込み時は数分かかる場合があります",
  WAITING_FOR_HISTOIRE = "LibHistoireの初期化を待っています...",
    
  -- Log Messages
  EVENTS_CACHED = "%s/%s：%d件のイベントがキャッシュされました",
  STARTED_CACHING = "%d個のギルドのキャッシングを開始しました",
  MODULE_LOADED = "|cFFD700[ScrollkeeperData]|r 読み込み完了 - バックグラウンドキャッシングサービス",
  LOG_MANUAL_DONATION = "%s - %dゴールドを手動で記録",
  MANUAL_DONATION_SOURCE = "手動入力",
    
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperData]|r エラー：ScrollkeeperFrameworkが見つかりません！",
  ERROR_DATA_NOT_TABLE = "|cFFD700[ScrollkeeperData]|r 重大：SF.Dataがテーブルではありません！",
  ERROR_HISTOIRE_NOT_FOUND = "|cFFD700[ScrollkeeperData]|r エラー：LibHistoireが見つかりません！",
    
  -- Cache Display
  GUILD_HEADER = "%s：",
  CATEGORY_LINE = "  %s：%d件のイベント",
  HISTOIRE_STATUS = "LibHistoire準備完了：%s",
    
  -- Category Names (for display)
  CAT_ROSTER = "リスト",
  CAT_BANKED_GOLD = "銀行ゴールド",
  CAT_BANKED_ITEMS = "銀行アイテム",
  CAT_SALES = "販売",
  
  -- Manual donation logging
  LOG_MANUAL_DONATION = "|cFFD700[ScrollkeeperData]|r 記録済み：%sから%sへ%dゴールド",
  
  -- Delete entry messages
  ERROR_DELETE_MISSING_PARAMS = "|cFFD700[ScrollkeeperData]|r deleteManualEntry：必須パラメータが不足しています",
  SUCCESS_DELETE_ENTRY = "|cFFD700[ScrollkeeperData]|r 手動エントリをキャッシュとストレージから正常に削除しました",
  ERROR_DELETE_NOT_FOUND = "|cFFD700[ScrollkeeperData]|r deleteManualEntry：エントリが見つかりません",
  
  -- Debug cache messages
  DEBUG_NO_GUILD = "[データデバッグ] ギルドが指定されていません",
  DEBUG_NO_CACHE_FOR_GUILD = "[データデバッグ] ギルドのキャッシュがありません：%s",
  DEBUG_AVAILABLE_GUILDS = "[データデバッグ] 利用可能なギルド：",
  DEBUG_GUILD_LIST_ITEM = "  - %s",
  DEBUG_CACHE_FOR_GUILD = "[データデバッグ] %sのキャッシュ：",
  DEBUG_BANKED_GOLD_COUNT = "  bankedGold：%dイベント",
  DEBUG_RECENT_DEPOSITS = "  最近の入金：",
  DEBUG_NO_DEPOSITS = "  入金が見つかりません",
  DEBUG_BANKED_GOLD_MISSING = "  bankedGold：存在しません",
  DEBUG_ROSTER_COUNT = "  roster：%dイベント",
  DEBUG_ROSTER_MISSING = "  roster：存在しません",
  
  -- Slash command messages
  ERROR_DATA_MODULE_UNAVAILABLE = "データモジュールまたはチェック機能が利用できません",
  CMD_CHECKGOLD_USAGE = "使用法：/sgtcheckgold ギルド名|@表示名|日数",
  CMD_CHECKGOLD_EXAMPLE = "例：/sgtcheckgold Dragon's Nest Thievery Co|@あなたの名前|14",
  CMD_CHECKGOLD_RESULT = "%sは過去%d日間に%dゴールドを寄付しました（%s）",
  
  -- Initialization
  ERROR_LIBHISTOIRE_MISSING = "|cFFD700[ScrollkeeperData]|r エラー：LibHistoireが見つかりません",
}

--------------------------------------------------------------------------------
-- WELCOME MESSAGES
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperWelcome"] = {
  SUBMENU_NAME = "ウェルカムメッセージ",
  DESCRIPTION = "ギルドメンバーへのウェルカムメッセージを設定します。プレイヤー名には%1、ギルド名には%2を使用してください。複数の申請を受け入れる際、またはテキストフィールドがアクティブな場合、メッセージはキューに入ります。",
  MASTER_ENABLE = "ウェルカムメッセージを有効化",
  MASTER_ENABLE_TIP = "すべてのウェルカムメッセージをオン/オフに切り替えます。",
  LOG_MEMBER_JOINED = "|cFFD700[ScrollkeeperWelcome]|r %sが%sに%sとして参加しました",
    
  -- Template
  TEMPLATE_HEADER = "テンプレート変数",
  VAR_PLAYER = "%1 - プレイヤー名",
  VAR_GUILD = "%2 - ギルド名",
    
  -- Guild Settings
  ENABLE_FOR_GUILD = "このギルドで有効化",
  MESSAGE_TEMPLATE = "メッセージテンプレート",
  PREVIEW = "プレビュー：%s",
  DEFAULT_MESSAGE = "ようこそ%1さん、%2へ",
}

--------------------------------------------------------------------------------
-- STANDARD COMMANDS
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperStandardCommands"] = {
  -- Main
  SUBMENU_NAME = "チャットコマンドとユーティリティ",
  DESCRIPTION = "Scrollkeeper用の追加ユーティリティコマンドとキーバインドサポート。",
    
  -- Headers
  COMMANDS_HEADER = "利用可能なコマンド",
  UTILITY_HEADER = "ユーティリティコマンド",
  STATUS_HEADER = "ステータスコマンド",
  MODULE_HEADER = "モジュールコマンド",
  DEBUG_HEADER = "デバッグコマンド",
    
  -- Command Documentation
  CMD_SKDEBUG = "|cf3ebd1/skdebug|r - システムデバッグ情報を表示",
  CMD_SKTEST = "|cf3ebd1/sktest <オプション>|r - モジュールテストを実行（オプション：context、settings、notebook、mail、data）",
  CMD_SGTNOTE = "|cf3ebd1/sgtnote|r - ノートブックウィンドウを切り替え",
  CMD_SGTMAIL = "|cf3ebd1/sgtmail|r - メールウィンドウを開く",
  CMD_SGTHISTORY = "|cf3ebd1/sgthistory|r - 履歴検索ウィンドウを開く",
  CMD_SGTPROVISION = "|cf3ebd1/sgtprovision|r - 仮メンバーウィンドウを開く",
  CMD_SGTCACHE = "|cf3ebd1/sgtcache|r - イベントキャッシュステータスを表示",
  CMD_ROLL = "|cf3ebd1/roll <数字>|r - サイコロを振る（例：/roll 20）",
  CMD_DICE = "|cf3ebd1/dice <数字>|r - /rollと同じ",
  CMD_RL = "|cf3ebd1/rl|r - UIをリロード",
  CMD_ON = "|cf3ebd1/on|r - ステータスをオンラインに設定",
  CMD_OFF = "|cf3ebd1/off|r - ステータスをオフラインに設定",
  CMD_AFK = "|cf3ebd1/afk|r - ステータスを離席中に設定",
  CMD_DND = "|cf3ebd1/dnd|r - ステータスを取り込み中に設定",
  CMD_OFFL = "|cf3ebd1/offl|r - オンライン/オフラインを切り替え",
    
  -- Full command list
  COMMAND_LIST = "|cf3ebd1/sgtnote|r - ノートブックウィンドウを切り替え\n" ..
                "|cf3ebd1/sgtmail|r - メールウィンドウを開く\n" ..
                "|cf3ebd1/sgthistory|r - 履歴検索を開く\n" ..
                "|cf3ebd1/sgtprovision|r - 仮メンバーウィンドウを開く\n" ..
                "|cf3ebd1/roll <数字>|r - サイコロを振る\n" ..
                "|cf3ebd1/rl|r - UIをリロード\n" ..
                "|cf3ebd1/on /off /afk /dnd|r - プレイヤーステータスを設定\n" ..
                "|cf3ebd1/offl|r - オフラインを切り替え\n" ..
                "|cf3ebd1/skdebug|r - デバッグ情報を表示\n" ..
                "|cf3ebd1/sgtcache|r - キャッシュステータスを表示",
				"|cf3ebd1/sgtcheckpm ギルド名|@表示名|r - 特定メンバーのゴールド寄付チェックのデバッグ\n" ..
				"|cf3ebd1/sgtattendance start [イベント名]|r - 追跡を開始\n" ..
				"|cf3ebd1/sgtattendance stop|r - 停止してレポートを保存\n" ..
				"|cf3ebd1/sgtattendance status|r - 現在のセッション情報を表示" ..
				"|cf3ebd1/sgttask add <名前>|<頻度>|<ギルド>|rを使用してカスタムタスクを追加" ..
				"|cf3ebd1/sgttask list|r - すべてのタスクをステータス付きで表示" ..
				"|cf3ebd1/sgttask complete <番号>|r - タスクを完了としてマーク",
  
  -- Buttons
  TEST_BUTTON = "すべてのシステムをテスト",
  TEST_BUTTON_TIP = "すべてのScrollkeeperモジュールの包括的なテストを実行",
    
  -- Status Messages
  STATUS_ONLINE = "ステータスがオンラインに設定されました",
  STATUS_OFFLINE = "ステータスがオフラインに設定されました",
  STATUS_DND = "ステータスが取り込み中に設定されました",
  STATUS_AWAY = "ステータスが離席中に設定されました",
  STATUS_CHANGED = "Scrollkeeper：ステータスが%sに設定されました",
  STATUS_TOGGLED = "ノートブックウィンドウが切り替えられました",
    
  -- Roll Messages
  ROLL_USAGE = "使用法：/roll <最大値>",
  ROLL_EXAMPLE = "例：/roll 20",
  ROLL_INVALID = "無効な数字：%s",
  ROLL_OUTPUT = "%d（1-%d）を出しました",
    
  -- Debug Messages
  DEBUG_HEADER = "=== Scrollkeeperデバッグ情報 ===",
  DEBUG_FRAMEWORK = "フレームワーク読み込み済み：%s",
  DEBUG_SETTINGS = "設定テーブル：%s",
  DEBUG_LAM = "LAM2利用可能：%s",
  DEBUG_FUNC = "SF.func利用可能：%s",
  DEBUG_GET_SETTINGS = "SF.getModuleSettings：%s",
  DEBUG_PANEL = "パネル登録済み：%s",
  DEBUG_MODULE = "モジュール：%s - コントロール：%d - アイコン：%s",
  DEBUG_TOTAL_MODULES = "登録されたモジュール総数：%d",
  DEBUG_NO_MODULES = "モジュール設定が見つかりません",
  DEBUG_CONTEXT = "コンテキストメニュー有効：%s",
  DEBUG_NOTEBOOK = "ノートブックモジュール：%s",
  DEBUG_DATA = "データモジュール：%s",
  DEBUG_HISTOIRE = "LibHistoire：%s",
  DEBUG_DATETIME = "LibDateTime：%s",
    
  -- Test Messages
  TEST_HEADER = "=== Scrollkeeperテストコマンド ===",
  TEST_USAGE = "使用法：/sktest <オプション>",
  TEST_OPTIONS = "オプション：context、settings、notebook、mail、data、attendance",
  TEST_RUNNING = "包括的なシステムテストを実行中...",
  TEST_UNKNOWN = "不明なテストオプション：%s",
  TEST_AVAILABLE = "利用可能なオプション：context、settings、notebook、mail、data、attendance",
    
  -- Test: Context
  TEST_CONTEXT_HEADER = "=== コンテキストメニューテスト ===",
  TEST_CONTEXT_ACTIVE = "コンテキストメニューフックがアクティブです",
  TEST_CONTEXT_ENABLED = "設定でコンテキストメニューが有効：%s",
  TEST_CONTEXT_MAIL = "チャット新規メールオプション：%s",
  TEST_CONTEXT_INVITE = "チャット招待オプション：%s",
  TEST_CONTEXT_NOT_LOADED = "ScrollkeeperContextMenuモジュールが読み込まれていません",
  TEST_CONTEXT_FAILED = "コンテキストメニューフック失敗 - CHAT_SYSTEMが利用できません",
    
  -- Test: Settings
  TEST_SETTINGS_HEADER = "=== 設定テスト ===",
  TEST_SETTINGS_ACCESSIBLE = "%s設定アクセス可能：%s",
  TEST_SETTINGS_PANEL = "設定パネルが登録されています",
  TEST_SETTINGS_NO_PANEL = "設定パネルが登録されていません",
  TEST_SETTINGS_NO_ACCESS = "モジュール設定にアクセスできません - フレームワークの問題",
    
  -- Test: Notebook
  TEST_NOTEBOOK_HEADER = "=== ノートブックテスト ===",
  TEST_NOTEBOOK_LOADED = "ノートブックモジュール読み込み済み",
  TEST_NOTEBOOK_ENABLED = "有効：%s",
  TEST_NOTEBOOK_WINDOW = "ノートブックウィンドウ存在：%s",
  TEST_NOTEBOOK_SAVE = "ノート保存テスト：%s",
  TEST_NOTEBOOK_NOT_LOADED = "ノートブックモジュールが読み込まれていません",
    
  -- Test: Mail
  TEST_MAIL_HEADER = "=== メールモジュールテスト ===",
  TEST_MAIL_LOADED = "メールモジュール読み込み済み",
  TEST_MAIL_ENABLED = "有効：%s",
  TEST_MAIL_WINDOW = "メールウィンドウ存在：%s",
  TEST_MAIL_COMMAND = "/sgtmailコマンド登録済み",
  TEST_MAIL_NO_COMMAND = "/sgtmailコマンドが登録されていません",
  TEST_MAIL_NOT_LOADED = "メールモジュールが読み込まれていません",
    
  -- Test: Data
  TEST_DATA_HEADER = "=== データモジュールテスト ===",
  TEST_DATA_LOADED = "データモジュール読み込み済み",
  TEST_DATA_LH_AVAILABLE = "LibHistoire利用可能",
  TEST_DATA_CACHE_ACCESSIBLE = "イベントキャッシュアクセス可能：%s",
  TEST_DATA_RECORDS = "キャッシュされたイベントレコード総数：%d",
  TEST_DATA_NO_FUNCTIONS = "データ関数が利用できません",
  TEST_DATA_NO_LH = "LibHistoireが利用できません",
  TEST_DATA_NOT_LOADED = "データモジュールが読み込まれていません",
    
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperStandardCommands]|r エラー：ScrollkeeperFrameworkが見つかりません！",
  ERROR_NOTEBOOK_DISABLED = "ノートブックが設定で無効になっています",
  ERROR_NOTEBOOK_NO_WINDOW = "ノートブックウィンドウが利用できません",
  ERROR_NOTEBOOK_NOT_LOADED = "ノートブックモジュールが読み込まれていません",
    
  -- Log Messages
  LOG_REGISTERING = "|cFFD700[ScrollkeeperStandardCommands]|r スラッシュコマンドを登録中...",
  LOG_REGISTERED = "|cFFD700[ScrollkeeperStandardCommands]|r スラッシュコマンド登録済み",
  LOG_INITIALIZING = "|cFFD700[ScrollkeeperStandardCommands]|r 初期化中...",
  LOG_COMPLETE = "|cFFD700[ScrollkeeperStandardCommands]|r 初期化完了",
}

--------------------------------------------------------------------------------
-- ATTENDANCE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperAttendance"] = {
  -- Module info
  SUBMENU_NAME = "イベント出席",
  
  -- Description
  DESCRIPTION = "遅刻/早退の自動検出でイベント出席を追跡します。",
  
  -- Settings
  MASTER_ENABLE = "イベント出席追跡を有効化",
  MASTER_ENABLE_TIP = "出席追跡機能とコマンドを有効化",
  
  -- Headers
  HEADER_COMMANDS = "コマンドと使用法",
  HEADER_HISTORY = "セッション履歴",
  
  -- Command help
  COMMANDS_DESC = "/sgtattendance start [名前] - 追跡を開始\n/sgtattendance stop - 終了して保存\n/sgtattendance status - 現在のセッションを確認",
  
  -- Help text (for /attendance help)
  HELP_HEADER = "=== 出席追跡コマンド ===",
  HELP_START = "/sgtattendance start [イベント名] - 追跡を開始",
  HELP_STOP = "/sgtattendance stop - 停止してレポートを保存",
  HELP_STATUS = "/sgtattendance status - 現在のセッション情報を表示",
  
  -- Success messages
  SUCCESS_TRACKING_STARTED = "追跡を開始しました：%s（%d人のメンバーが出席）",
  SUCCESS_TRACKING_STOPPED = "追跡を停止しました：%s",
  SUCCESS_SAVED_TO_NOTEBOOK = "出席レポートをノートブックの「イベント」カテゴリに「%s」として保存しました",
  SUCCESS_HISTORY_CLEARED = "出席履歴をクリアしました",
  
  -- Error messages
  ERROR_ALREADY_TRACKING = "既にイベントを追跡しています！最初に /sgtattendance stop を使用してください。",
  ERROR_NO_ACTIVE_SESSION = "アクティブな追跡セッションがありません",
  ERROR_UNKNOWN_COMMAND = "不明なコマンドです。/sgtattendance help を使用してください",
  ERROR_NOT_SAVED = "警告：ノートブックに保存できませんでした",
  ERROR_NOTEBOOK_DISABLED = "ノートブックが利用できません - レポートは出席履歴のみに保存されました",
  
  -- Status messages
  STATUS_NO_SESSION = "アクティブな追跡セッションがありません",
  STATUS_ACTIVE = "追跡中：%s | 期間：%d分 | 出席者：%d",
  
  -- Real-time log messages
  LOG_MEMBER_JOINED = "%sがイベントに参加しました（%d分遅刻）",
  LOG_MEMBER_LEFT = "%sがイベントを退出しました（%d分間出席）",
  
  -- Report sections
  REPORT_HEADER = "出席レポート：%s",
  REPORT_TIME = "時間：%sから%sまで",
  REPORT_SUMMARY = "合計出席者：%d | 完全出席：%d | 遅刻：%d | 早退：%d",
  
  SECTION_FULL_ATTENDANCE = "完全出席",
  SECTION_ON_TIME = "時間通り",
  SECTION_LATE = "遅刻",
  SECTION_LEFT_EARLY = "早退",
  
  -- History display
  NO_SESSIONS = "まだ追跡されたセッションがありません",
  SESSIONS_COUNT = "追跡されたセッション：%d",
  
  -- Settings buttons
  BTN_CLEAR_HISTORY = "履歴をクリア",
  BTN_CLEAR_HISTORY_TIP = "保存されたすべての出席セッションを削除",
  WARNING_CLEAR_HISTORY = "これにより、すべての出席記録が永久に削除されます！",
}

--------------------------------------------------------------------------------
-- APPLICATIONS
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperApplications"] = {
  -- Module info
  SUBMENU_NAME = "ギルド申請",
  DESCRIPTION = "ギルド申請を自動的にノートブックに記録して記録を保管します。申請は申請者のメッセージを含む完全な詳細とともに保存されます。",
  
  -- Settings
  MASTER_ENABLE = "申請記録を有効化",
  MASTER_ENABLE_TIP = "申請記録機能のマスタースイッチ",
  AUTO_LOG = "新しい申請を自動的に記録",
  AUTO_LOG_TIP = "有効にすると、新しいギルド申請が自動的にノートブックに保存されます",
  SHOW_NOTIFICATIONS = "チャット通知を表示",
  SHOW_NOTIFICATIONS_TIP = "申請が記録されたときにチャットにメッセージを表示",
  
  -- Guild settings
  HEADER_GUILDS = "ギルドごとの設定",
  GUILDS_DESC = "申請を記録するギルドを選択：",
  GUILD_TOGGLE_TIP = "%sの申請を記録",
  
  -- Errors
  ERROR_NOTEBOOK_UNAVAILABLE = "|cFFD700[ScrollkeeperApplications]|r ノートブックモジュールが利用できません。申請を記録できません。",
  WARNING_NOTEBOOK_MISSING = "|cFFD700[ScrollkeeperApplications]|r 警告：ノートブックモジュールが読み込まれていません。申請記録は機能しません。",
  
  SUCCESS_LOGGED_SINGLE = "|cFFD700[ScrollkeeperApplications]|r |cFFD700%s|rから|cFFD700%s|rへの応募を記録しました",
  ERROR_SAVE_FAILED = "|cFF5555[ScrollkeeperApplications]|r %sの応募の保存に失敗しました",
  SUCCESS_LOGGED_MULTIPLE = "|cFFD700[ScrollkeeperApplications]|r |cFFD700%s|rの応募を%d件記録しました",
}
-- Backward compatibility (DEPRECATED)
_G.Scrollkeeper.Localization = Scrollkeeper.Localization