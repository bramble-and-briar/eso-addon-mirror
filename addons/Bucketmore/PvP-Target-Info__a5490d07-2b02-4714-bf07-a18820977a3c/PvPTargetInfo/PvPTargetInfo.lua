--[[
    PvPTargetInfo.lua

    メインエントリポイント。名前空間の定義、SavedVariablesの管理、
    スラッシュコマンド(/pti)、他モジュールの初期化呼び出しを行う。

    v1.4.0で大幅仕様変更:
      - HP表示・処刑ライン警告・自分のバフ/デバフ表示を廃止
      - UI①(敵の重要バフ)・UI②(敵の重要デバフ)・UI③(自分のProc)の
        3つの独立したウィンドウに再構築

    v1.4.2で修正・改善:
      - パネルが常に表示されない/設定画面が機能しない不具合を修正
        (詳細は各ファイル冒頭のコメントを参照)
      - 修正改定3: 重要バフ/デバフの「自動検知」を追加。状態異常(CC)と
        Major/Minor系の効果は登録なしで自動的に表示されるようになった。
        手動登録(sv.watchedBuffs/watchedDebuffs)は、それでも拾えない
        効果を追加したい場合のための任意機能という位置づけに変更。

    v1.4.3で追加:
      - 修正改定4: UI①・UI②の表示順を、検出順ではなく戦闘上の重要度
        カテゴリ順(防御・回復・攻撃強化・クリティカル・機動力/CC耐性 等)に
        変更。ただし残り時間が短いものはカテゴリに関わらず優先表示する。
        詳細はPvPTargetInfo_Target.lua冒頭のコメントを参照。

    v1.4.4で追加(修正改定5):
      - UI①・UI②の表記から「重要バフ」「重要デバフ」を廃止し、シンプルに
        "BUFF" / "DEBUFF" とだけ表示するようにした。
      - Proc登録を簡略化。既存の「登録するProc」入力欄にAbilityIdの番号を
        入力するだけで登録完了になり、名前入力や追加のコマンド操作は
        不要になった(表示名はGetAbilityNameで自動取得)。
      - 敵プレイヤーの表示名を、キャラクター名ではなくオンラインID
        (@表示名)にした。表示名を持たないユニット(ターゲットダミー等)は
        キャラクター名にフォールバックする。

    v1.4.5で追加(修正改定6):
      - プレイヤー判定を最優先にした。IsUnitPlayer("reticleover")で
        判定し、NPC・モンスター・衛兵や壁・扉などのオブジェクトには
        一切反応しないようにした。ターゲット変更のたびに再判定する。
      - 効果検知をポーリング(0.1秒ごとの全バフ再取得)からイベント駆動
        (EVENT_EFFECT_CHANGED)に変更。開始・更新・消失を正しく処理し、
        AbilityIdをキーにしたキャッシュ構造にすることで同じ効果の
        重複表示も起こらないようにした。ターゲット変更時は初期スキャンで
        既存の効果を取りこぼさないようにしている。
      - 自動検知キーワードや手動登録リストを設定画面/コマンドで変更した
        際に、現在のターゲットへ即座に再反映されるようにした。

    v1.4.23で対応(根本原因の修正 + 新機能。v1.4.16を土台に立て直し):
      - 【重要・根本原因】v1.4.16〜v1.4.22で繰り返し不具合報告が続いた
        真の原因が判明。PvPTargetInfo_Procs.luaがGetUnitBuffInfoの戻り値を
        受け取る際の変数の個数が1つ足りておらず、"abilityId"として扱って
        いた値が実際にはstatusEffectType(状態異常の種類を表す小さな整数)
        だった。PvPTargetInfo_Target.luaの正しい並び順と比較して発見した。
        これでは番号での一致判定がほぼ常に失敗するのは当然で、これまでの
        「表示名一致」「endTime除外」「複数バフ枠マージ」等の対応は
        すべてこの根本原因に対する場当たり的な後付けだった。
        引数の並びを正しく修正した上で、v1.4.17以降に積み重なった
        endTime関連の除外処理・複雑なマージ処理は撤去し、v1.4.16相当の
        シンプルな構成に戻した。
      - 【新機能】敵のBUFF/DEBUFF自動検知(CC系statusEffectType、または
        Major/Minor・(強)/(弱)のキーワード一致)と全く同じ判定方法を使い、
        自分に付与されたデバフを登録不要で自動検知・表示するようにした
        (PTI.Target.IsAutoImportantDebuffとして判定ロジックを共通化)。
        従来通りのAbilityId手動登録方式(セット効果Proc等)も引き続き
        使える。GetNumBuffsのループは1回にまとめており、追加の負荷はない。
      - パネルの表示名を「PROC」から「CONDITION」に変更した(内部の
        変数名・関数名(PTI.Procs等)やチャットコマンド(/pti proc ...)は
        互換性のためそのまま)。
      - "/pti proc use/add/remove/list/pending"等のコマンド一覧・
        学習ログの文字化け(ESOのチャットが生の"|"を制御コードの開始と
        誤認する問題)は既に修正済みであることを再確認した。
      - Conditionの残り秒数の文字色(明るい水色寄りの白)も維持している。
      - PS5/コンソール向けに、GetNumBuffsで件数を先に取得してから境界内
        だけを回す安全なループ(無限ループ不可)、範囲外や想定外の戻り値
        への型チェック、200ms Tickへの処理集約(1フレームに集中させない)
        を全体にわたって再確認した。

    v1.4.22で修正: 「最大表示件数を増やしたら、今度は同じProcが重複して
      複数行に表示される」との報告への対応。原因は、スタックするタイプの
      効果がESO内部ではスタック毎に別々のバフ枠(GetUnitBuffInfoの
      インデックス)として保持されることがあり、そのうちの一部だけがID
      一致、残りは名前一致フォールバックで拾われるなどして、同じ効果が
      別々のキーとして扱われ2行以上に分かれて表示されていたこと。
      対策として、Proc欄の集計キーをabilityId/buffNameではなく「一致した
      表示名」そのものに統一した(PvPTargetInfo_Procs.luaのScanActiveProcs)。
      これにより、内部的に何個のバフ枠に分かれていようと同じ表示名になる
      限り必ず1行にまとまる。複数のバフ枠がヒットした場合は、残り時間は
      一番新しいもの・スタック数は一番大きいものを採用してマージする。

    v1.4.21で対応: 「鬨の声・ブラッドスポーン・無慈悲な決意の3つが同時に
      発動しているのにUI③には1つしか表示されない(個別なら出る)」という
      報告への対応。表示ロジック自体(RefreshProcUI/ScanActiveProcs)には
      同時複数表示を妨げる要素は見当たらず、最有力候補は設定画面の
      「最大表示件数」スライダー(UI③既定3件)が、過去のバージョンで
      調整した値のままSavedVariablesに保存され続けていること。
      設定画面を開かずその場で確認・変更できるよう /pti maxrows
      <buff|debuff|proc> <1〜10> コマンドを追加した(引数を省略すると
      現在値を表示する)。

    v1.4.20で修正(v1.4.19の回帰修正): v1.4.19で「endTimeを過ぎたらProc欄から
      除外する」対応を入れたところ、「無慈悲な決意」はゲーム内部で常時
      endTimeが過去のまま(または更新されない)扱いになっているらしく、
      発動中も含めて常に期限切れと誤判定され、名前・スタック数ごと
      一切表示されなくなる回帰が発生。表示するかどうかの判定にendTimeを
      使うのをやめ、GetUnitBuffInfoが実際にそのバフを返しているかどうか
      だけで表示対象を決めるように戻した。マイナス秒数がずっと残る問題
      への対応は、秒数表示側だけに絞り、endTimeを過ぎている場合は数字を
      出さず空欄にする形にした(名前・スタック数は常に表示される)。

    v1.4.19で修正: v1.4.18でスタック数・名前が正しく表示されるようになった
      一方、「無慈悲な決意」は戦闘後もGetUnitBuffInfo自体から消えず居座り
      続ける効果で、その効果自身のendTimeだけは過去のまま更新されない
      ため、経過時間がマイナス◯◯秒でずっと増え続けて表示されたままになる
      不具合が発生。ライブAPI上は「まだ付いている」と返ってきていても、
      その効果自身のendTimeを過ぎていれば表示上は期限切れとして扱い、
      Proc欄から外すよう修正した(PvPTargetInfo_Procs.luaのScanActiveProcs)。
      あわせて、秒数表示の色が暗いグレーで見づらいとの指摘のため、
      明るい水色寄りの白に変更した。

    v1.4.18で修正(重要・根本原因の可能性): チャット欄のスクリーンショットで
      「/pti proc use <id>d <id>emove <id>istpending」のように文字が
      欠落して表示される不具合を発見。原因はESOのチャットが"|"を色指定
      などの制御コード開始の合図として解釈するため、区切り文字として
      生の"|"を使っていた箇所(コマンド一覧、学習モードのログ等)が
      軒並み表示崩れを起こしていたこと。
      これが事実だとすると、これまで学習モード(/pti learn proc)の
      チャットログで確認していたAbilityIdの表示自体が欠落・破損して
      いた可能性があり、「残忍な集中力」「無慈悲な決意」が登録しても
      検知できなかった一連の不具合の根本原因はこちらだった疑いが強い。
      コマンド一覧は区切りの"|"を全て"||"(ESOの仕様で1本の"|"として
      表示される正しいエスケープ)に修正し、学習モードのログ・
      /pti proc dumpの出力は"|"依存を避けて" / "区切りに変更した。

    v1.4.17で修正(不具合再調査):
      - v1.4.16で修正したはずのProc不具合が「残忍な集中力」「無慈悲な決意」
        では再発するとの報告。原因候補として、ESOのEVENT_EFFECT_CHANGEDが
        報告するAbilityIdと、GetUnitBuffInfoが実際に報告するAbilityIdが
        一部の効果(CPパッシブのスタック系など)で食い違うケースがあるため、
        学習モードのログで見た番号を登録してもID一致だけでは検知できない
        可能性がある。対策として、ID一致に加えて「表示名の完全一致」でも
        照合するフォールバックを追加した(PvPTargetInfo_Procs.luaの
        ScanActiveProcs)。
      - 診断用に /pti proc dump コマンドを追加。登録の有無に関係なく、
        今プレイヤーに付いている全バフのAbilityId・表示名・スタック数を
        チャットに一覧表示する。今回の2つの効果が実際にどのAbilityId・
        表示名で報告されているかをこれで直接確認できる。

    v1.4.16で修正(このバージョンが以後の起点):
      - ヘッダーの「デザイン版(色付き背景)」設定を、直しても改善しなかった
        ため撤去した。関連するsv.useDesignHeader・設定チェックボックス・
        背景バー用の内部コードも合わせて削除した。代わりに、タイトル文字
        そのものの色を役割ごとに固定した(BUFF=明るい緑/DEBUFF=明るい赤/
        Proc=水色)。切り替え設定は持たず、常時この配色になる。
      - Proc(UI③)登録に関する不具合修正: 学習モードのチャットログには
        スタック数が出るのに、実際にProcとして登録してもUI③のパネルには
        表示されない場合があった。原因は、発動中のProcの検出をイベント
        (EVENT_EFFECT_CHANGED)の差分更新だけに頼っていたこと。効果に
        よってはスタック段階でAbilityIdが変わる、あるいは発動中に登録した
        場合は次にイベントが発火するまで拾えない、といったケースで表示が
        漏れることがあった。200ms Tickのたびに「今実際にプレイヤーに
        付いているバフ」をGetNumBuffs/GetUnitBuffInfoでまっさらに数え直す
        方式(PvPTargetInfo_Procs.luaのScanActiveProcs)に一本化し、確実に
        反映されるようにした。イベントハンドラは学習モードのログ出力・
        候補リスト登録専用に縮小した。
      - 上記修正にあたり、PS5/コンソール環境向けの安全方針(GetNumBuffsで
        件数を先に取得してから境界内だけをループする、範囲外で想定外の
        戻り値が来ても安全側に倒す、新規のwhileループを追加しない、
        1フレームに処理を集中させない)を全ファイルで再確認した。
        Target.lua側の初期スキャンは元々この方針に沿っており変更なし。
        Procs.lua側は上記の通りTarget.lua側と同じ安全な書き方に統一した。

    v1.4.15で修正:
      - 「登録するProc AbilityId」欄が番号だけしか表示せず、後で見返しても
        何を登録したのか分からないという報告への対応。保存形式(番号だけの
        カンマ区切り)自体は変えず、欄に表示するときだけ各番号の後ろに
        GetAbilityNameで引いた名前を付けて「番号:名前」で見せるようにした
        (保存時は番号部分だけを取り出すので、名前部分を書き換えても無害)。
      - ヘッダーの「デザイン版(色付き背景)」の色が暗すぎて、切り替えても
        変化に気付きにくいという報告への対応。同じ配色のまま彩度・明度を
        上げてはっきり視認できるようにした。あわせて、設定画面を開いた
        ままだとシーン判定でパネル自体が非表示になる(プレビュー表示ONの
        時を除く)ため反映されて見えないだけ、というケースを切り分けられる
        よう、切り替え時にチャットへ案内メッセージを出すようにした。

    v1.4.14で追加:
      - 検知方式に「全表示」を追加し、設定画面から「自動検知」「全表示」を
        選べるようにした(既定は自動検知、従来通り)。全表示は、CC/Major-Minor
        判定に関わらずターゲットの効果をほぼ全て表示するv1.3.x的な方式で、
        食事バフ・マウント速度・ギルドバフのような常時付いていて今更確認する
        必要のない背景バフ(無期限、または既定120秒を超える長時間バフ。
        閾値は設定画面のスライダーで変更可能)だけを自動的に除外する。
        ただし状態異常(CC)やMajor/Minor系と判定された効果は、全表示モードでも
        背景バフ扱いにはならず必ず表示する(見逃し防止)。表示順は自動検知
        モードと完全に同じ優先順位ルール(GetCategoryRank)に従うため、
        全表示モードでも重要な効果が上位に来る点は変わらない。
        設定画面には、自動検知/全表示それぞれのメリット・デメリットを
        明記した説明文を追加した。
      - 上記のコード変更は、PS5/コンソール環境を踏まえ、新規ループを
        一切追加しない(既存のGetNumBuffs境界済みループ・イベント駆動の
        1件ずつの判定に機能を追加しただけ)、APIが想定外の型を返しても
        安全側(除外)に倒す、1フレームに処理が集中しないよう軽量な
        判定のみを追加する、という方針で実装した。
      - 作成者名を Bucketmore に変更した。

    v1.4.13で緊急修正: v1.4.12で追加したProcの初期スキャン処理に無限ループの
      不具合があり、アドオンロード時に「CPU time budget of 1000 ms」エラーで
      落ちる致命的な不具合を修正した。原因はGetUnitBuffInfoが範囲外の
      インデックスでnilではなく空文字列を返すことがあり、終了条件
      "if not buffName" が空文字列に対して成立しなかったこと。
      GetNumBuffsで件数を先に取得してからその件数分だけループする、
      Target.lua側と同じ安全な書き方に統一した。

    v1.4.12で修正:
      - v1.4.11で追加した「英語表記/日本語表記の個別ON/OFF」は意味が
        ないとのことで撤回し、単純な自動検知ON/OFFのみに戻した(英語版
        Major/Minorと日本語版(強)/(弱)は常に両方検知する)。
      - v1.4.11で追加した行バッジ(先頭1文字の色付きアイコン)は
        「カッコ悪い」とのことで撤去した。
      - UI①②③のヘッダーを「シンプル版(白文字、既定)」「デザイン版
        (BUFF=緑/DEBUFF=赤/Proc=紺の色付き背景バー)」で切り替えられる
        設定を追加した(全般設定の一番下)。見た目のみの違いで機能は同じ。
      - Proc(UI③)のスタック数が表示されない不具合を修正。
        EVENT_EFFECT_CHANGEDのstackCount引数は効果によってはゲーム側から
        正しく渡されないことがあるため、GetUnitBuffInfoで実際のバフ枠を
        直接照会して取得する方式に変更した(マーシレス等で確認)。
        表示形式も「Proc名 スタック数 残り秒数」(例: マーシレス 5 12秒)
        に変更。あわせて、リロード時点で既に発動中だったProcも初期スキャン
        で即座に拾うようにした。
      - 学習モード(/pti learn proc)のログにstackCountも表示するようにした
        (診断用)。
      - Proc登録はAbilityId番号だけで済み、名前はGetAbilityNameで自動取得
        (取得できない場合は "ability <ID>" にフォールバック)する方式に
        既になっている(v1.4.3で対応済み、変更なし)。

    v1.4.11で修正(v1.4.12で一部撤回。上記参照):
      - 自動検知キーワードの自由入力欄を廃止し、固定チェックボックスに変更した。
      - UI①②③の各行にバッジを追加した。

    v1.4.10で修正(不具合修正): メニュー/マップを開いてもパネルが隠れない
    不具合を修正した。以前はワールドマップシーンだけを監視して隠す作りに
    なっていたため、インベントリ・キャラクターシート・クラフト・
    ギルドストア等の一般的なメニューを開いた際にはパネルが残ったままに
    なっていた。SCENE_MANAGERの"SceneStateChanged"を監視し、現在のシーンが
    通常プレイ画面(hud/hudui)かどうかで判定する方式に一般化した。ただし
    sv.previewMode(位置調整用のプレビュー表示)がONの間は、設定画面等を
    開いたまま位置調整できるよう例外的に隠さない(詳細はPvPTargetInfo_UI.lua
    のPTI.UI.SetWindowVisible/Initializeのコメントを参照)。

    v1.4.9で追加(見た目の改修): UI①(BUFF)・UI②(DEBUFF)を「役割を色で
    固定した」見た目に変更した。
      - 残り6秒以上(通常表示)の文字色を、BUFF=緑系/DEBUFF=赤系の固定色に
        分けた(以前はどちらも同じ青系だった)。どちらのパネルを見ているか
        ではなく「バフかデバフか」が色そのもので即座に分かるようにする狙い。
      - 各行の下端に、残り時間を示す薄いバーを追加した。効果の全長
        (beginTime〜endTime)に対する残り時間の比率でバーが減っていく。
        全長が取得できない効果(永続効果など)は満タン固定表示にする。
      - 残り5秒以下になったら、文字色とバーの色を黄色→オレンジ→赤へと
        エスカレーションさせる(既存のIMPORTANT_TIERS/URGENT_REMAINING_
        THRESHOLDの緊急枠ロジックはそのまま流用。表示優先順位のカテゴリ
        分類・ソート順もv1.4.3から変更していない)。

    v1.4.8で修正(ゲーム仕様変更への追従):
      - ESOのシステムアップデートにより、以前は物理耐性(Resolve)と
        呪文耐性(Ward)に分かれていた防御バフが、現在は「Resolve」に
        統合され、物理・呪文の両方の耐性が同時に上がる仕様に変更された。
        表示優先順位のカテゴリ分類キーワードから存在しなくなった"Ward"を
        外し、日本語版での呼び名"不屈"を追加した(自動検知の可否には
        影響しない。あくまで並び順の分類キーワードの修正)。

    v1.4.7で修正(重要バグ修正・実機報告への対応):
      - 自動検知のキーワード判定が「前方一致」(名前の先頭からの一致)に
        なっていたため、日本語版ESOで実質的に機能していなかった不具合を
        修正した。日本語版はMajor/Minorに相当する表記が「残忍(強)」
        「強固(弱)」のように語尾の "(強)"/"(弱)" になるため、先頭一致
        判定では絶対に一致しなかった。部分一致(名前のどこかにキーワードが
        含まれていればOK)に変更し、既定キーワードにも "(強)"/"(弱)" を
        追加した(英語版のMajor/Minorはそのまま残している)。

    v1.4.6で追加(徹底デバッグ対応):
      - 検知パイプラインのデバッグログ機能を追加。既定OFFで、通常プレイ中は
        自動検知の結果をチャットに一切出力しない。/pti debug または設定画面の
        チェックボックスでONにした時だけ、①対象取得(reticleoverがプレイヤーか)
        ②EVENT_EFFECT_CHANGED発火 ③④⑤重要判定・表示データ登録
        ⑥UI描画(buffUI/debuffUIへの反映件数)を1行ずつ出力し、検知が
        どの段階で止まっているか切り分けられるようにした(学習モードとは
        別物で、こちらは候補登録を行わない純粋な経路確認用)。
      - 状態異常(CC)判定に使う定数(STATUS_EFFECT_TYPE_STUN等)が
        現在のAPIバージョンで解決できているかを起動時に1回だけチェックし、
        未解決のものがあれば警告を表示するようにした(解決できない定数は
        自動検知から静かに除外される仕様のため、原因不明の検知漏れに
        気づけるようにする目的)。

    設定はLibAddonMenu-2.0のパネル(設定→アドオン、ゲームパッド対応)と
    チャットコマンド /pti ... の両方から行える。

    仕様が大きく変わったため、SavedVariablesのバージョンを2に上げて
    v1.3.1以前の設定(HP関連の項目等)を引き継がず、新しいデフォルト値から
    始まるようにしてある(v1.4.2はキー追加のみなのでバージョンは据え置き)。
--]]

PvPTargetInfo = PvPTargetInfo or {}
local PTI = PvPTargetInfo

-- v2.0.8 変更点:
--   ・UI④(PEN)のBreach判定を自動化。AbilityId手動登録(設定欄・保存データ)を廃止し、
--     言語に依存しないabilityId表+説明文の数値による補助判定(推定表示)に変更。
--     詳細はPvPTargetInfo_Pen.lua冒頭参照。UI①〜③・敵判定・スキャン周期は無変更。
-- v2.0.7 変更点:
--   ・敵バフ/敵デバフ/敵Breachの個別検知ON/OFF(enemyBuffDetect, enemyDebuffDetect,
--     pen.showEffects と /pti buffdetect||debuffdetect)を撤去。敵プレイヤーと確認できたら一律に検知する。
--   ・パネル表示がOFFの種類は、その敵バフ/デバフのスキャンを行わない(PENは従来どおりパネルOFFで停止)。
--   ・設定画面を 基本/検知/表示の残し方/パネル/詳細設定 の順に整理(設定キーは変更なし)。
--   ・決闘中の相手(GetDuelInfo)を敵として扱う(任意変更・PS5実機未検証)。
PTI.name = "PvPTargetInfo"
PTI.version = "2.0.8"

local SV_VERSION = 2

-- アカウント全体で共有するデフォルト設定
local defaults = {
    enabled = true,
    previewMode = false, -- ONの間は3パネルにサンプルデータを表示する(設定画面の手動プレビュー)
    holdDuration = 1.0, -- ターゲット解除後にパネルを保持する秒数

    -- v2.0.4で追加: 直前まで有効だった効果が消えた後の「残像」表示秒数(0=残像なし)。
    -- (v2.0.7: 敵バフ/デバフ検知の個別ON/OFF=enemyBuffDetect/enemyDebuffDetectは撤去した)
    lingerDuration = 2.0,

    -- 重要バフ/デバフの自動検知(修正改定3)。既定でON。
    -- v1.4.11で英語/日本語の個別トグルを試したが、意味がないとのことで
    -- v1.4.12で単純なON/OFFのみに戻した。英語表記(Major/Minor)と
    -- 日本語表記((強)/(弱))は常に両方チェック対象になる(コード内に
    -- 直接埋め込み。PvPTargetInfo_Target.luaのAUTO_DETECT_KEYWORDS参照)。
    autoDetect = {
        enabled = true,
    },

    -- v1.4.14で追加: 検知方式そのものを「自動検知」「全表示」で切替可能にした。
    -- 既定は"auto"(従来通り)。"all"にすると、CC/Major-Minorの判定に
    -- 関わらずターゲットの効果をほぼ全て表示する(v1.3.x時代の全表示方式に近い)。
    -- 食事バフ・マウント速度・ギルドバフのような、常時付いていて今更確認する
    -- 必要のない背景バフだけは自動的に除外する(showAll.hideLongerThan参照)。
    detectionMode = "auto", -- "auto" または "all"
    showAll = {
        hideLongerThan = 120, -- 全表示モードで、これより長時間(秒)のバフ/デバフを背景バフとして除外
    },

    -- UI①: 敵の重要バフ
    buffUI = {
        enabled = true,
        point = CENTER, relPoint = CENTER, x = -180, y = -250,
        scale = 1.0,
        fontSize = 16,
        maxRows = 6,
    },
    -- UI②: 敵の重要デバフ
    debuffUI = {
        enabled = true,
        point = CENTER, relPoint = CENTER, x = 180, y = -250,
        scale = 1.0,
        fontSize = 16,
        maxRows = 6,
    },
    -- UI③: 自分のセットProc表示(維持)
    procUI = {
        enabled = true,
        point = CENTER, relPoint = CENTER, x = 0, y = -80,
        scale = 1.0,
        fontSize = 16,
        maxRows = 3,
    },

    procs = {
        debugLearnMode = false,        -- 自分のバフ学習(Proc特定用)
        debugLearnModeTarget = false,  -- 敵のバフ/デバフ学習(重要リスト作成用)
    },

    -- v1.4.6で追加: 自動検知の内部処理を1段階ずつ確認するためのデバッグ機能。
    -- 既定でOFF。通常プレイ中にチャットへ検知ログが流れることは一切ない。
    -- ONにした場合のみ、対象取得→効果検知→重要判定→表示データ登録→UI描画の
    -- 各段階を1行ずつチャットに出す(学習モードとは別物で、候補登録は行わない)。
    debug = {
        pipelineTrace = false,
    },

    -- 重要バフ/デバフの登録リスト。形式: [abilityId] = { name=, enabled= }
    -- 個別にenabledをfalseにすることで、登録は残したまま一時的に非表示にできる。
    watchedBuffs = {},
    watchedDebuffs = {},

    -- v2.0.5で追加: UI④ 貫通・敵耐性低下パネル(既定OFF。ONにするまでスキャンも走らない)
    penUI = {
        enabled = false,
        point = CENTER, relPoint = CENTER, x = 0, y = -450,
        scale = 1.0,
        fontSize = 16,
        maxRows = 6,
    },
    pen = {
        showSelfPen = true,    -- 自分の武器貫通/呪文貫通を表示
        descFallback = true,   -- v2.0.8: ID表に無いデバフを説明文の数値(5948/2974)で補助判定する(「推定」表示)
    },

    procConfig = {
        idsText = "", -- AbilityIdをカンマ区切りで並べた形式("id,id,...")。名前はGetAbilityNameで自動取得する
    },
}

--------------------------------------------------------------------------
-- ウィンドウ操作系コマンドの共通ヘルパー(UI①=buff, UI②=debuff, UI③=proc)
--------------------------------------------------------------------------
local WINDOW_KEYS = { buff = "buffUI", debuff = "debuffUI", proc = "procUI", pen = "penUI" }
local WINDOW_LABELS_JP = { buff = "UI①(重要バフ)", debuff = "UI②(重要デバフ)", proc = "UI③(Condition)", pen = "UI④(貫通)" }

local function ResolveWindowKey(token)
    token = (token or ""):lower()
    if WINDOW_KEYS[token] then return token end
    return nil
end

local function NudgePosition(key, direction, amount)
    amount = tonumber(amount) or 10
    local sv = PTI.sv[WINDOW_KEYS[key]]
    if direction == "up" then
        sv.y = sv.y - amount
    elseif direction == "down" then
        sv.y = sv.y + amount
    elseif direction == "left" then
        sv.x = sv.x - amount
    elseif direction == "right" then
        sv.x = sv.x + amount
    else
        return false
    end
    if PTI.UI and PTI.UI.ApplyPosition then PTI.UI.ApplyPosition(key) end
    return true
end

local function SetAbsolutePosition(key, x, y)
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return false end
    PTI.sv[WINDOW_KEYS[key]].x = x
    PTI.sv[WINDOW_KEYS[key]].y = y
    if PTI.UI and PTI.UI.ApplyPosition then PTI.UI.ApplyPosition(key) end
    return true
end

local function PrintHelp()
    -- v1.4.18で修正: ESOのチャットは"|"を色指定などの制御コードの開始として
    -- 解釈するため、区切り文字として生の"|"を使うとその後の文字が消えて
    -- 表示が壊れる不具合があった(例: "|clear|list"の"|c"部分が色コードの
    -- 開始と誤認され、以降が欠落する)。ESOのチャットで"|"を文字として
    -- そのまま表示するには"||"(2つ重ねる)必要があるため、区切りに使う
    -- 全ての"|"を"||"に修正した。
    d("|c55CCFF[PvPTargetInfo]|r コマンド一覧: (対象は buff=UI①重要バフ / debuff=UI②重要デバフ / proc=UI③Condition)")
    d("  /pti move <buff||debuff||proc||pen> up||down||left||right [px] - パネルを移動 (既定10px)")
    d("  /pti pos <buff||debuff||proc||pen> <x> <y>                   - パネルの位置を絶対座標で指定")
    d("  /pti scale <buff||debuff||proc||pen> <倍率>                  - パネルの拡大縮小 (例: 1.2)")
    d("  /pti fontsize <buff||debuff||proc||pen> <10〜32>              - 文字サイズを変更")
    d("  /pti maxrows <buff||debuff||proc||pen> <1〜10>                - 最大表示件数を変更(省略で現在値を表示)")
    d("  /pti resetpos <buff||debuff||proc||all>                  - 位置・大きさをリセット")
    d("  /pti <buff||debuff||proc||pen> on||off                        - 個別のパネル表示を切替")
    d("  /pti hold <秒>                                        - ターゲット解除後にパネルを保持する秒数")
    d("  /pti enemy                                           - 現在のターゲットの敵味方判定の診断表示")
    d("  /pti pen on||off||dump                               - UI④(貫通・敵耐性低下)のON/OFF、対象のデバフId診断")
    d("  /pti linger <秒>                                      - 消えた効果の残像表示秒数(0〜10、0で残像なし)")
    d("  /pti learn proc                                       - Condition学習モードON/OFF(自分のバフ/デバフ)")
    d("  /pti learn target                                     - 敵バフ/デバフ学習モードON/OFF(重要リスト用)")
    d("  /pti debug                                            - 検知パイプラインのデバッグログON/OFF(開発用、既定OFF)")
    d("  /pti proc pending                                     - Condition学習モードで見つかった候補を確認")
    d("  /pti proc use <id>                                    - Proc候補のAbilityIdを指定して登録")
    d("  /pti proc add <id>                                    - AbilityIdを指定してProcを登録(名前は自動取得)")
    d("  /pti proc remove <id>||clear||list                      - Proc登録の削除/クリア/確認")
    d("  /pti proc dump                                        - 今付いているバフを登録の有無に関係なく全件表示(調査用)")
    d("  /pti watch buff||debuff pending                        - 敵バフ/デバフ学習モードで見つかった候補を確認")
    d("  /pti watch buff||debuff use <id>                       - 候補のAbilityIdを指定して重要リストに登録")
    d("  /pti watch buff||debuff add <id> <名前>                 - 重要リストに手動で登録")
    d("  /pti watch buff||debuff remove <id>                    - 重要リストから削除")
    d("  /pti watch buff||debuff on||off <id>                    - 登録済み項目の表示ON/OFF切替(削除はしない)")
    d("  /pti watch buff||debuff list||clear                     - 重要リストの確認/全削除")
    d("  /pti auto on||off                                      - 重要バフ/デバフの自動検知を切替(既定ON)")
    d("  /pti preview on||off                                   - プレビュー表示(サンプルデータ)を切替")
    d("  /pti show || hide                                      - アドオン全体の表示切替")
end

local function OnWatchCommand(kind, rest)
    local sub, arg = rest:match("^(%S*)%s*(.-)$")
    sub = (sub or ""):lower()
    local kindLabel = (kind == "debuff") and "重要デバフ" or "重要バフ"

    if sub == "add" then
        local id, name = arg:match("^(%d+)%s+(.+)$")
        if not id or not name then
            d(string.format("|c55CCFF[PvPTargetInfo]|r 例: /pti watch %s add 12345 スタン耐性", kind))
        else
            PTI.Target.AddWatch(kind, id, name)
            d(string.format("|c55CCFF[PvPTargetInfo]|r %s \"%s\" (AbilityId %s) を登録しました。", kindLabel, name, id))
        end
    elseif sub == "remove" then
        local id = tonumber(arg)
        if not id then
            d(string.format("|c55CCFF[PvPTargetInfo]|r 例: /pti watch %s remove 12345", kind))
        else
            PTI.Target.RemoveWatch(kind, id)
            d(string.format("|c55CCFF[PvPTargetInfo]|r AbilityId %d を%sリストから削除しました。", id, kindLabel))
        end
    elseif sub == "on" or sub == "off" then
        local id = tonumber(arg)
        if not id then
            d(string.format("|c55CCFF[PvPTargetInfo]|r 例: /pti watch %s on 12345", kind))
        elseif PTI.Target.SetWatchEnabled(kind, id, sub == "on") then
            d(string.format("|c55CCFF[PvPTargetInfo]|r AbilityId %d の表示を %s にしました。", id, sub))
        else
            d(string.format("|c55CCFF[PvPTargetInfo]|r AbilityId %d は登録されていません。", id))
        end
    elseif sub == "clear" then
        PTI.Target.ClearWatch(kind)
        d(string.format("|c55CCFF[PvPTargetInfo]|r %sリストを空にしました。", kindLabel))
    elseif sub == "list" then
        local list = PTI.Target.GetWatchListSorted(kind)
        if #list == 0 then
            d(string.format("|c55CCFF[PvPTargetInfo]|r %sリストは空です。", kindLabel))
        else
            for _, e in ipairs(list) do
                d(string.format("|c55CCFF[PvPTargetInfo]|r  %d: %s (%s)", e.id, e.name, e.enabled and "ON" or "OFF"))
            end
        end
    elseif sub == "use" then
        local id = tonumber(arg)
        if not id then
            d(string.format("|c55CCFF[PvPTargetInfo]|r 例: /pti watch %s use 12345 (学習モードで見つかった候補のAbilityIdを指定)", kind))
        else
            local ok, name = PTI.Target.RegisterPendingById(kind, id)
            if ok then
                d(string.format("|c55CCFF[PvPTargetInfo]|r %s \"%s\" (AbilityId %d) を登録しました。", kindLabel, name, id))
            else
                d(string.format("|c55CCFF[PvPTargetInfo]|r その候補は見つかりません。/pti watch %s pending で確認してください。", kind))
            end
        end
    elseif sub == "pending" then
        local labels = PTI.Target.GetPendingChoices(kind)
        if #labels == 0 then
            d(string.format("|c55CCFF[PvPTargetInfo]|r 候補はまだありません。学習モードをONにして敵の%sを表示させてください。", kindLabel))
        else
            d("|c55CCFF[PvPTargetInfo]|r 登録候補: " .. table.concat(labels, " / "))
        end
    else
        d(string.format("|c55CCFF[PvPTargetInfo]|r /pti watch %s add <id> <名前>||remove <id>||on <id>||off <id>||use <id>||pending||list||clear", kind))
    end
end

local function OnSlashCommand(args)
    args = args or ""
    local cmd, rest = args:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "move" then
        local keyTok, dir, amount = rest:match("^(%S*)%s*(%S*)%s*(.-)$")
        local key = ResolveWindowKey(keyTok)
        if not key or not NudgePosition(key, dir, amount) then
            d("|c55CCFF[PvPTargetInfo]|r 例: /pti move buff up 10 (対象は buff/debuff/proc)")
        end
    elseif cmd == "pos" then
        local keyTok, x, y = rest:match("^(%S*)%s*(%S*)%s*(.-)$")
        local key = ResolveWindowKey(keyTok)
        if not key or not SetAbsolutePosition(key, x, y) then
            d("|c55CCFF[PvPTargetInfo]|r 例: /pti pos buff 0 -250 (対象は buff/debuff/proc)")
        else
            d(string.format("|c55CCFF[PvPTargetInfo]|r %s の位置を (%s, %s) に設定しました。", WINDOW_LABELS_JP[key], x, y))
        end
    elseif cmd == "scale" then
        local keyTok, scaleStr = rest:match("^(%S*)%s*(.-)$")
        local key = ResolveWindowKey(keyTok)
        local scale = tonumber(scaleStr)
        if key and scale and scale > 0.3 and scale < 3 then
            PTI.sv[WINDOW_KEYS[key]].scale = scale
            if PTI.UI and PTI.UI.ApplyPosition then PTI.UI.ApplyPosition(key) end
            d(string.format("|c55CCFF[PvPTargetInfo]|r %s のスケールを %.2f に設定しました。", WINDOW_LABELS_JP[key], scale))
        else
            d("|c55CCFF[PvPTargetInfo]|r 例: /pti scale buff 1.2 (対象は buff/debuff/proc/pen、0.3〜3.0の範囲)")
        end
    elseif cmd == "fontsize" then
        local keyTok, sizeStr = rest:match("^(%S*)%s*(.-)$")
        local key = ResolveWindowKey(keyTok)
        local size = tonumber(sizeStr)
        if key and size and size >= 10 and size <= 32 then
            PTI.sv[WINDOW_KEYS[key]].fontSize = size
            if PTI.UI and PTI.UI.ApplyFontSize then PTI.UI.ApplyFontSize(key) end
            d(string.format("|c55CCFF[PvPTargetInfo]|r %s の文字サイズを %d にしました。", WINDOW_LABELS_JP[key], size))
        else
            d("|c55CCFF[PvPTargetInfo]|r 例: /pti fontsize buff 20 (対象は buff/debuff/proc/pen、10〜32の範囲)")
        end
    elseif cmd == "maxrows" then
        -- v1.4.21で追加: 「発動中のProcが3つあるのに1つしか出ない」等の
        -- 問い合わせに対し、設定画面を開かずその場で確認・変更できるように
        -- した。原因の多くは設定画面の「最大表示件数」スライダーが
        -- 既定(UI③は3件)より少ない値のまま保存されていること。
        local keyTok, nStr = rest:match("^(%S*)%s*(.-)$")
        local key = ResolveWindowKey(keyTok)
        local n = tonumber(nStr)
        if key and n and n >= 1 and n <= 10 then
            PTI.sv[WINDOW_KEYS[key]].maxRows = n
            d(string.format("|c55CCFF[PvPTargetInfo]|r %s の最大表示件数を %d にしました。", WINDOW_LABELS_JP[key], n))
        elseif key then
            d(string.format("|c55CCFF[PvPTargetInfo]|r %s の現在の最大表示件数: %d (例: /pti maxrows %s 5)",
                WINDOW_LABELS_JP[key], PTI.sv[WINDOW_KEYS[key]].maxRows or 0, keyTok))
        else
            d("|c55CCFF[PvPTargetInfo]|r 例: /pti maxrows proc 5 (対象は buff/debuff/proc/pen、1〜10の範囲)")
        end
    elseif cmd == "resetpos" then
        local keyTok = rest:lower()
        local function ResetOne(key)
            local sv = PTI.sv[WINDOW_KEYS[key]]
            local d0 = defaults[WINDOW_KEYS[key]]
            sv.point, sv.relPoint = CENTER, CENTER
            sv.x, sv.y, sv.scale = d0.x, d0.y, d0.scale
            if PTI.UI and PTI.UI.ApplyPosition then PTI.UI.ApplyPosition(key) end
        end
        if keyTok == "all" or keyTok == "" then
            ResetOne("buff"); ResetOne("debuff"); ResetOne("proc"); ResetOne("pen")
            d("|c55CCFF[PvPTargetInfo]|r 全パネルの位置をリセットしました。")
        elseif ResolveWindowKey(keyTok) then
            ResetOne(ResolveWindowKey(keyTok))
            d(string.format("|c55CCFF[PvPTargetInfo]|r %s の位置をリセットしました。", WINDOW_LABELS_JP[ResolveWindowKey(keyTok)]))
        else
            d("|c55CCFF[PvPTargetInfo]|r 例: /pti resetpos all (対象は buff/debuff/proc/pen/all)")
        end
    elseif cmd == "buff" or cmd == "debuff" then
        local sub = rest:lower()
        if sub == "on" then
            PTI.sv[WINDOW_KEYS[cmd]].enabled = true
            if PTI.UI and PTI.UI.RefreshVisibility then PTI.UI.RefreshVisibility() end
            d(string.format("|c55CCFF[PvPTargetInfo]|r %s: ON", WINDOW_LABELS_JP[cmd]))
        elseif sub == "off" then
            PTI.sv[WINDOW_KEYS[cmd]].enabled = false
            if PTI.UI and PTI.UI.RefreshVisibility then PTI.UI.RefreshVisibility() end
            d(string.format("|c55CCFF[PvPTargetInfo]|r %s: OFF", WINDOW_LABELS_JP[cmd]))
        else
            d(string.format("|c55CCFF[PvPTargetInfo]|r 例: /pti %s on||off", cmd))
        end
    elseif cmd == "enemy" then
        -- v2.0.6: 敵プレイヤー判定の診断(現在のターゲットの判定値と最終判定を表示)
        if PTI.Target and PTI.Target.PrintEnemyDiagnostics then PTI.Target.PrintEnemyDiagnostics() end
    elseif cmd == "pen" then
        -- v2.0.5: UI④(貫通・敵耐性低下)。on/off/dump
        if PTI.Pen and PTI.Pen.HandleCommand then PTI.Pen.HandleCommand(rest) end
    elseif cmd == "hold" then
        local sec = tonumber(rest)
        if sec and sec >= 0 then
            PTI.sv.holdDuration = sec
            d(string.format("|c55CCFF[PvPTargetInfo]|r ターゲット解除後の保持時間を %.1f秒 にしました。", sec))
        else
            d("|c55CCFF[PvPTargetInfo]|r 例: /pti hold 1.5")
        end
    elseif cmd == "linger" then
        -- v2.0.4: 消えた効果の残像表示秒数(0=残像なし)
        local sec = tonumber(rest)
        if sec and sec >= 0 and sec <= 10 then
            PTI.sv.lingerDuration = sec
            if PTI.Target and PTI.Target.ForceRefresh then PTI.Target.ForceRefresh() end
            d(string.format("|c55CCFF[PvPTargetInfo]|r 消えた効果の残像表示を %.1f秒 にしました。", sec))
        else
            d(string.format("|c55CCFF[PvPTargetInfo]|r 現在 %.1f秒  (例: /pti linger 2.5  ※0〜10、0で残像なし)", PTI.sv.lingerDuration or 2.0))
        end
    elseif cmd == "learn" then
        local sub = rest:lower()
        if sub == "proc" then
            PTI.sv.procs.debugLearnMode = not PTI.sv.procs.debugLearnMode
            if PTI.sv.procs.debugLearnMode and PTI.Procs and PTI.Procs.seenProcAbilityIds then
                ZO_ClearTable(PTI.Procs.seenProcAbilityIds)
                if PTI.Procs.ClearPendingCandidates then PTI.Procs.ClearPendingCandidates() end
            end
            d("|c55CCFF[PvPTargetInfo]|r Condition学習モード: " .. (PTI.sv.procs.debugLearnMode and "ON" or "OFF"))
        elseif sub == "target" then
            PTI.sv.procs.debugLearnModeTarget = not PTI.sv.procs.debugLearnModeTarget
            if PTI.sv.procs.debugLearnModeTarget and PTI.Target and PTI.Target.seenTargetAbilityIds then
                ZO_ClearTable(PTI.Target.seenTargetAbilityIds)
                if PTI.Target.ClearPendingCandidates then PTI.Target.ClearPendingCandidates() end
            end
            d("|c55CCFF[PvPTargetInfo]|r 敵バフ/デバフ学習モード: " .. (PTI.sv.procs.debugLearnModeTarget and "ON" or "OFF"))
        else
            d("|c55CCFF[PvPTargetInfo]|r 例: /pti learn proc (自分のバフ) または /pti learn target (敵のバフ/デバフ)")
        end
    elseif cmd == "debug" then
        PTI.sv.debug.pipelineTrace = not PTI.sv.debug.pipelineTrace
        d("|c55CCFF[PvPTargetInfo]|r 検知パイプラインのデバッグログ: " .. (PTI.sv.debug.pipelineTrace and "ON (敵の効果を検知するたびにチャットへ内部処理を出力します)" or "OFF"))
    elseif cmd == "watch" then
        local kindTok, watchRest = rest:match("^(%S*)%s*(.-)$")
        kindTok = (kindTok or ""):lower()
        if kindTok == "buff" or kindTok == "debuff" then
            OnWatchCommand(kindTok, watchRest)
        else
            d("|c55CCFF[PvPTargetInfo]|r 例: /pti watch buff add 12345 名前 (対象は buff/debuff)")
        end
    elseif cmd == "proc" then
        local sub, arg = rest:match("^(%S*)%s*(.-)$")
        sub = (sub or ""):lower()
        if sub == "on" then
            PTI.sv.procUI.enabled = true
            if PTI.UI and PTI.UI.RefreshVisibility then PTI.UI.RefreshVisibility() end
            d("|c55CCFF[PvPTargetInfo]|r UI③(Condition): ON")
        elseif sub == "off" then
            PTI.sv.procUI.enabled = false
            if PTI.UI and PTI.UI.RefreshVisibility then PTI.UI.RefreshVisibility() end
            d("|c55CCFF[PvPTargetInfo]|r UI③(Condition): OFF")
        elseif sub == "add" then
            local id = tonumber(arg)
            if not id then
                d("|c55CCFF[PvPTargetInfo]|r 例: /pti proc add 61906 (名前は自動取得されるため入力不要)")
            elseif PTI.Procs and PTI.Procs.AddById then
                local ok, name = PTI.Procs.AddById(id)
                if ok then
                    d(string.format("|c55CCFF[PvPTargetInfo]|r Condition \"%s\" (AbilityId %s) を登録しました。", tostring(name), tostring(id)))
                end
            end
        elseif sub == "remove" then
            local id = tonumber(arg)
            if not id then
                d("|c55CCFF[PvPTargetInfo]|r 例: /pti proc remove 61906")
            else
                local kept = {}
                for entry in string.gmatch(PTI.sv.procConfig.idsText or "", "[^,]+") do
                    local entryId = tonumber((entry:match("^%s*(%d+)%s*$")))
                    if entryId ~= id then table.insert(kept, entry) end
                end
                PTI.sv.procConfig.idsText = table.concat(kept, ",")
                if PTI.Procs and PTI.Procs.RebuildKnownProcs then PTI.Procs.RebuildKnownProcs() end
                d(string.format("|c55CCFF[PvPTargetInfo]|r AbilityId %d を登録解除しました。", id))
            end
        elseif sub == "clear" then
            PTI.sv.procConfig.idsText = ""
            if PTI.Procs and PTI.Procs.RebuildKnownProcs then PTI.Procs.RebuildKnownProcs() end
            d("|c55CCFF[PvPTargetInfo]|r Condition登録リストを空にしました。")
        elseif sub == "list" then
            local known = PTI.Procs and PTI.Procs.GetKnownProcs and PTI.Procs.GetKnownProcs()
            if not known or next(known) == nil then
                d("|c55CCFF[PvPTargetInfo]|r 登録済みCondition: (なし)")
            else
                local parts = {}
                for id, name in pairs(known) do
                    table.insert(parts, string.format("%s(%d)", name, id))
                end
                d("|c55CCFF[PvPTargetInfo]|r 登録済みCondition: " .. table.concat(parts, ", "))
            end
        elseif sub == "use" then
            local id = tonumber(arg)
            if not id then
                d("|c55CCFF[PvPTargetInfo]|r 例: /pti proc use 61906 (学習モードで見つかった候補のAbilityIdを指定、名前の入力は不要)")
            elseif PTI.Procs and PTI.Procs.RegisterPendingById then
                local ok, name = PTI.Procs.RegisterPendingById(id)
                if ok then
                    d(string.format("|c55CCFF[PvPTargetInfo]|r Condition \"%s\" (AbilityId %d) を登録しました。", name, id))
                else
                    d("|c55CCFF[PvPTargetInfo]|r その候補は見つかりません。/pti proc pending で確認してください。")
                end
            end
        elseif sub == "pending" then
            if PTI.Procs and PTI.Procs.GetPendingChoices then
                local labels = PTI.Procs.GetPendingChoices()
                if #labels == 0 then
                    d("|c55CCFF[PvPTargetInfo]|r 候補はまだありません。学習モードをONにしてセット効果を発動させてください。")
                else
                    d("|c55CCFF[PvPTargetInfo]|r 登録候補: " .. table.concat(labels, " / "))
                end
            end
        elseif sub == "dump" then
            if PTI.Procs and PTI.Procs.DumpActiveBuffs then
                PTI.Procs.DumpActiveBuffs()
            end
        else
            d("|c55CCFF[PvPTargetInfo]|r /pti proc use <id>||add <id>||remove <id>||clear||list||pending||dump")
        end
    elseif cmd == "auto" then
        local sub, arg = rest:match("^(%S*)%s*(.-)$")
        sub = (sub or ""):lower()
        if sub == "on" then
            PTI.sv.autoDetect.enabled = true
            if PTI.Target and PTI.Target.ForceRefresh then PTI.Target.ForceRefresh() end
            d("|c55CCFF[PvPTargetInfo]|r 自動検知: ON")
        elseif sub == "off" then
            PTI.sv.autoDetect.enabled = false
            if PTI.Target and PTI.Target.ForceRefresh then PTI.Target.ForceRefresh() end
            d("|c55CCFF[PvPTargetInfo]|r 自動検知: OFF (登録した効果のみ表示します)")
        else
            d("|c55CCFF[PvPTargetInfo]|r 例: /pti auto on||off")
        end
    elseif cmd == "preview" then
        local sub = rest:lower()
        if sub == "on" then
            PTI.sv.previewMode = true
        elseif sub == "off" then
            PTI.sv.previewMode = false
        else
            PTI.sv.previewMode = not PTI.sv.previewMode
        end
        if PTI.UI and PTI.UI.RefreshVisibility then PTI.UI.RefreshVisibility() end
        d("|c55CCFF[PvPTargetInfo]|r プレビュー表示: " .. (PTI.sv.previewMode and "ON" or "OFF"))
    elseif cmd == "show" then
        PTI.sv.enabled = true
        if PTI.UI and PTI.UI.RefreshVisibility then PTI.UI.RefreshVisibility() end
    elseif cmd == "hide" then
        PTI.sv.enabled = false
        if PTI.UI and PTI.UI.RefreshVisibility then PTI.UI.RefreshVisibility() end
    else
        PrintHelp()
    end
end

function PTI.Initialize()
    PTI.sv = ZO_SavedVars:NewAccountWide("PvPTargetInfo_SavedVariables", SV_VERSION, nil, defaults)

    -- v2.0.7: 撤去した個別検知ON/OFFの旧キーを破棄する。コードはもう参照しないため
    -- 旧値(false)が残っていても検知は止まらないが、保存データにも残さない。
    -- 位置・サイズ・表示設定などの他のキーには触れない(SV_VERSIONも据え置き)。
    PTI.sv.enemyBuffDetect = nil
    PTI.sv.enemyDebuffDetect = nil
    if type(PTI.sv.pen) == "table" then
        PTI.sv.pen.showEffects = nil
        -- v2.0.8: AbilityId手動登録(majorIdsText/minorIdsText)と旧補助判定(descMatch)を廃止
        PTI.sv.pen.majorIdsText = nil
        PTI.sv.pen.minorIdsText = nil
        PTI.sv.pen.descMatch = nil
    end

    -- v1.4.7〜v1.4.11で自動検知キーワードの持たせ方を試行錯誤していたが
    -- (自由入力欄→英語/日本語の個別チェックボックス)、最終的にv1.4.12で
    -- 「英語表記(Major/Minor)と日本語表記((強)/(弱))を常に両方検知する」
    -- 固定仕様に落ち着いた。設定項目としては持たなくなったため、過去の
    -- 移行処理は不要になり撤去した(古いsv.autoDetect.keywordsText等の
    -- 残骸データが万一残っていても、参照しなくなったため無害)。

    -- 先にスラッシュコマンドを登録しておく。こうすることで、万一以下の
    -- モジュール初期化でエラーが起きても /pti resetpos 等で復旧できる。
    SLASH_COMMANDS["/pti"] = OnSlashCommand

    -- 各モジュールはpcallで保護し、1つが失敗しても他が巻き込まれて
    -- 止まらないようにする(PS5はファイルを直接触れないため特に重要)。
    local modules = {
        { "UI",       PTI.UI },
        { "Target",   PTI.Target },
        { "Procs",    PTI.Procs },
        { "Pen",      PTI.Pen },
        { "Settings", PTI.Settings },
    }
    for _, entry in ipairs(modules) do
        local label, mod = entry[1], entry[2]
        if mod and mod.Initialize then
            local ok, err = pcall(mod.Initialize)
            if not ok then
                d(string.format("|cFF5555[PvPTargetInfo]|r %s の初期化でエラー: %s", label, tostring(err)))
            end
        end
    end

    d("|c55CCFF[PvPTargetInfo]|r ロード完了 v" .. PTI.version .. "  (/pti でコマンド一覧)")
end

local function OnAddOnLoaded(event, addonName)
    if addonName ~= PTI.name then return end
    EVENT_MANAGER:UnregisterForEvent(PTI.name, EVENT_ADD_ON_LOADED)
    PTI.Initialize()
end

EVENT_MANAGER:RegisterForEvent(PTI.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
