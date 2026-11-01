# SetCooldownTracker v1.0.3

ESO PS5 / Console版（Update 51 / API 101051 向け）の、装備セットProc「内部クールダウン」表示アドオンです。PvPTargetInfo等とは完全に独立しており、他アドオンのファイル・SavedVariablesには触れません。

## v1.0.3 変更点

- アップロード時に日本語ファイル名が拒否されたため、ファイル名を英数字に変更（対応セット一覧→`Supported_Sets.md`、Ability ID一覧→`AbilityID_List.md`、CDデータベース→`CD_Database.csv`）。コードの変更はありません。

## v1.0.2 変更点

- マニフェストを `SetCooldownTracker.txt` から `SetCooldownTracker.addon` に変更（コンソール向けアップロードで「`<AddOnName>/` の下に .addon ファイルが1つだけ必要」というエラーが出たため）。コードの変更はありません。

## v1.0.1 変更点

- `EQUIPTYPE_TWO_HAND` → `EQUIP_TYPE_TWO_HAND` に修正（旧名はnilとなり、両手武器の判定でエラーになる恐れがありました）
- `ACTION_RESULT_EFFECT_FADED` は実在する定数のため `IGNORED_RESULTS` から削除せず維持。`EFFECT_RESULT_FADED`（EVENT_EFFECT_CHANGED用）とは別物として扱っています。未定義の定数があってもロード時にエラーとならないよう、nilを無視する登録方式に変更
- 武器バー判定を、存在を確認できた `ACTIVE_WEAPON_PAIR_MAIN` 基準に変更
- `REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE` が未定義の場合でも引数エラーにならないよう保護（送信元チェックはコールバック内でも実施済み）
- パネル表示: シーンのフラグメントがShow時にパネル本体を再表示するため、対象なし時はパネル本体ではなく中身（背景・文字）を隠す方式に変更
- バージョン表記を1.0.1へ更新

### 再確認の結果（コールバック引数・API）

| 項目 | 結果 |
|---|---|
| EVENT_EFFECT_CHANGED の引数順 | 公開コード例と一致。`changeType`=2番目、`unitTag`=5番目、`abilityId`=16番目、`sourceType`=17番目 |
| EVENT_COMBAT_EVENT の引数順 | 公開コード例と一致。`result`=2、`isError`=3、`sourceType`=8、`abilityId`=17番目 |
| GetItemLinkSetInfo の戻り値 | `hasSet, setName, numBonuses, numNormalEquipped, maxEquipped, setId, ...`（setIdは6番目）と一致 |
| ACTION_RESULT_EFFECT_FADED / DOT_TICK(_CRITICAL) | 公開コードで使用を確認 |
| EFFECT_RESULT_GAINED / UPDATED | 公開コードで使用を確認 |
| GetActiveWeaponPairInfo / ACTIVE_WEAPON_PAIR_MAIN / HasItemInSlot / EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED | 公開コード・パッチノートで確認 |
| ACTION_RESULT_HOT_TICK(_CRITICAL)、GetItemLinkSetBonusInfo、REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE | 公開資料では直接確認できず（上記のとおりnil保護あり。GetItemLinkSetBonusInfoは類似の公式API形状から想定） |

上記の確認は公開資料との突き合わせであり、Update 51のAPIドキュメント原文やPS5実機での確認ではありません。

## ⚠ 必ずお読みください（完成度の正直な申告）

| 項目 | 状態 |
|---|---|
| PS5実機での動作確認 | **未実施**（この環境にはLua実行環境もESOクライアントもありません） |
| Luaの構文確認 | ブロック・括弧の対応のみ簡易チェック済み。Luaインタープリタでの実行確認は**未実施** |
| 使用API | 既知のESO公式APIのみ使用。ただしUpdate 51のAPIドキュメント原文との**突き合わせは未実施** |
| 対応セット（検知可能） | **4セット**（下記）。いずれもID/CDは第三者アドオンの設定値であり、**実機検証(VERIFIED)は0件** |
| 上記以外のセット | 名前のみ把握（約70件）。**Ability ID未確認のため検知できません（UNKNOWN）** |
| 日本語ツールチップのCD解析 | パターンは想定表現であり**実機未確認**（英語表記の解析は想定通りの文言の場合のみ有効） |

「可能な限り多くのセットに対応」は、Ability IDを裏付ける資料を入手できた範囲に限られました。IDを推測で埋めると誤検知・誤表示の原因になるため、未確認セットは意図的に空欄(UNKNOWN)にしています。

また、先行診断アドオン(PCL_ProcCDLog)では、PS5でProcのGAINED/UPDATED/FADEDが記録されない不具合が報告されています。本アドオンは「EVENT_EFFECT_CHANGED」と「EVENT_COMBAT_EVENT」の**両方**を（自分起因のみ・Ability ID指定で）監視して取りこぼしを減らしていますが、**PS5で実際に検知できるかは未確認**です。検知できなかった場合、その原因はAbility ID不一致またはPS5側のイベント仕様の可能性があります。

## 機能

- 装備中（アクティブバーの武器のみ）のセットを自動判定し、対象セットのProcを検知
- 内部CDを計測し、残り時間を0.1秒単位で表示（残りが短い順）
- 複数セット同時管理、READY表示（ON/OFF・表示時間）
- Ability ID基準の識別。日本語クライアントではセット名はゲームの日本語名を表示
- 自分起因のイベントのみ処理（敵・味方・NPCのイベントは登録時のフィルタと送信元種別チェックで除外）
- CD中の再イベントは**無視**（CDの延長・再起動をしない）
- DoT/HoTの継続ティックはProc発動として扱わない
- イベント駆動。パネルOFF時は全イベント登録とタイマーを解除。100msタイマーはCD/READY表示が必要な間のみ稼働

## 表示例

```
SET COOLDOWN
Set A    12.4s
Set B     5.2s
Set C     READY
```

- `5.2s*` … DB未登録のCDをツールチップ記載値で補助表示（* = DB値ではない）
- `+12.3s ?` / `ICD ?` … 内部CD不明。推測せず、最後の発動からの経過時間だけ表示

## 導入方法

1. `SetCooldownTracker` フォルダをアドオンフォルダ（`AddOns`）に配置します。
2. 設定画面を使う場合は **LibAddonMenu-2.0** も導入します（無くても既定値で動作します）。
3. ゲーム起動後、アドオン一覧で SetCooldownTracker を有効化します。
4. コンソール版へのアドオン反映手順はお使いの環境の既存手順に従ってください（本アドオン固有の特別な手順はありません）。

## 設定方法（LibAddonMenu-2.0 導入時）

設定 → アドオン → SetCooldownTracker

| 項目 | 内容 |
|---|---|
| パネルを有効にする | OFFで全処理を停止 |
| 表示位置の確認 | 15秒間サンプル表示（位置調整用） |
| READY表示 / 表示時間 | 0秒＝装備中は常時READY表示。1以上＝CD終了後その秒数だけ表示 |
| ICD不明セットの経過時間表示 | 不明セットの扱いを切り替え |
| ツールチップ記載のCDを補助利用 | DBにCDが無い場合のみ有効 |
| 死亡/ゾーン移動時にCDリセット | 実機未確認の挙動。既定は死亡のみON |
| 位置 X/Y（%）・パネル幅・拡大率・文字サイズ・背景の濃さ | 見た目の調整（背景0%で透明） |

コンソールではドラッグ移動ができないため、位置はスライダーで調整します。

## データベースへの追加方法

`SCT_Database.lua` の `SCT.DB` に1件追加します。

```lua
{
    key = "SetKey", nameEn = "Set Name",
    setIds = { 123 },            -- アイテムセットID（言語非依存）
    abilityIds = { 456789 },     -- Procのアビリティ（バフ/ダメージ等）のID
    icd = 10,                    -- 内部CD秒。不明なら nil
    status = "VERIFIED",         -- VERIFIED / DOCUMENTED / UNKNOWN
    cond = "発動条件の説明",
    trigger = "ANY",             -- "EFFECT" / "COMBAT" / "ANY"
    minPieces = 5,               -- 任意。省略時はツールチップ解析値、無ければ5
    source = "出典",
}
```

`SCT.PENDING` の名前を移動して使えます。

## 既知の制約

- 内部CDと効果持続時間は別管理の設計ですが、DBに持続時間の項目は未収録です（`ignored`カウントによりCD中の再イベントは無視）。
- DoTがCD終了後も残る場合、DoTの直接ダメージ以外のイベントが同じAbility IDで来る場合の誤検知はあり得ます。
- 武器交換・装備変更後は最大約0.25秒の遅延で再判定します。ログイン/ゾーン移行直後は1.5秒後と4秒後の2回判定します。
- 「Proc発動」の判定はAbility ID単位のイベントです。同一Ability IDが別目的で発火するセットでは `trigger` の調整が必要です。

## ファイル構成

`SetCooldownTracker.addon`(マニフェスト) / `SCT_Database.lua` / `SCT_UI.lua` / `SCT_Core.lua` / `SCT_Settings.lua` / `README_JP.md` / `Supported_Sets.md` / `AbilityID_List.md` / `CD_Database.csv`
