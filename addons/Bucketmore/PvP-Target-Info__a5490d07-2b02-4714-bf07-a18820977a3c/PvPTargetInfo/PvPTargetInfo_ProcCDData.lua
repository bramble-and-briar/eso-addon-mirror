--[[
    PvPTargetInfo_ProcCDData.lua  (v2.1.0 新規)

    UI④ Self Proc CD の「内部クールダウン(ICD)定義表」。
    Srendarrのコード・データ表は参照・複写していない、独自作成の表。

    ■ 3種類の情報の区別
      A. APIから直接取れる: 装備セット名/ID(GetItemLinkSetInfo)、バフ名・AbilityId・開始/終了時刻
         (GetUnitBuffInfo)、セット効果の説明文(GetItemLinkSetBonusInfo)。
      B. 検知してアドオン側で管理: 「いつ発動したか」(バフ出現/更新の検知)と残りCD。
      C. 定義が必要: ICD秒数。ESOのAPIにはICD秒数を返す関数が無い。
         → 下の表(確認済みのみ)、または装備セット説明文からの自動読み取り(TOOLTIP)で得る。
         → どちらでも得られないProcは「UNKNOWN」とし、推測値では表示しない。

    ■ status の意味
      VERIFIED   … 実機で発動間隔を実測して確認した値。
      DOCUMENTED … ゲーム内のセット効果説明文など、資料で確認した値。
      UNKNOWN    … ICD秒数を確認できていない。cd = nil のままにする(表示しない)。
      ※ ICD秒数と「バフの持続時間」は別物。cdには必ずICD(再発動までの秒数)だけを入れる。

    ■ 項目
      key    … 重複登録を防ぐ一意キー(英数字)
      names  … このセットの名前の候補(英語/日本語)。装備中セット名・バフ名との照合に使う(大文字小文字無視)
      ids    … 発動時に付くバフのAbilityId(確認できたものだけ)。空でもよい(名前照合で検知する)
      cd     … ICD秒数(数値)。未確認はnil
      status … 上記

    ■ 追加方法
      PS5はLuaファイルを直接編集できないため、通常は設定を介さず
      チャットコマンド /pti cd add <AbilityId> <秒数> [名前] で追加する
      (保存データ sv.cd.user に残る。VERIFIED扱い=自分で実測した値)。
      このファイルに足す場合は、下のentriesへ1件ずつ追加するだけでよい。

    ■ 初期データについて(重要)
      確認できていない秒数は登録しない方針のため、初期のcdは全てnil(UNKNOWN)。
      優先セットは「名前の候補だけ」を置いてあり、cdが確認できた時点で埋める。
      実際のICDは起動時にセット説明文から自動で読み取る(PS5実機では未検証)。
--]]

PvPTargetInfo = PvPTargetInfo or {}
local PTI = PvPTargetInfo

PTI.CDData = {
    entries = {
        -- PvP優先セット(cd未確認のため UNKNOWN。確認でき次第 cd と status を埋める)
        { key = "orpheon",        names = { "Orpheon the Tactician", "モンマス戦術家", "戦術家オルフェオン" }, ids = {}, cd = nil, status = "UNKNOWN" },
        { key = "mechanicalacuity", names = { "Mechanical Acuity", "機械的精度" },        ids = {}, cd = nil, status = "UNKNOWN" },
        { key = "soulcleaver",    names = { "Soulcleaver", "ソウルクリーバー" },                              ids = {}, cd = nil, status = "UNKNOWN" },
        { key = "viciousdeath",   names = { "Vicious Death", "残忍な死" },                            ids = {}, cd = nil, status = "UNKNOWN" },
        { key = "nocturnalsploy", names = { "Nocturnal's Ploy" },                         ids = {}, cd = nil, status = "UNKNOWN" },
        { key = "pillarofnirn",   names = { "Pillar of Nirn" },                           ids = {}, cd = nil, status = "UNKNOWN" },
        { key = "blooddrinker",   names = { "Blood Drinker" },                            ids = {}, cd = nil, status = "UNKNOWN" },
        { key = "venomoussmite",  names = { "Venomous Smite" },                           ids = {}, cd = nil, status = "UNKNOWN" },
        { key = "overwhelmingsurge", names = { "Overwhelming Surge" },                    ids = {}, cd = nil, status = "UNKNOWN" },
    },
}
