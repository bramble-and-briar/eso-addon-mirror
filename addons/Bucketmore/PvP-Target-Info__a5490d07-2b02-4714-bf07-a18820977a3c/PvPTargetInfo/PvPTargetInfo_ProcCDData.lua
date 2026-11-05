--[[
    PvPTargetInfo_ProcCDData.lua  (v2.3.0: detect区分を整理)

    UI④ Self Proc CD の「内部クールダウン(ICD)定義表」。独自作成の表。

    ■ 情報源とライセンスの扱い
      ・ICD秒数は「ゲーム内のセット効果説明文」に書かれている事実(例: 「This effect can occur once
        every 8 seconds」)を、説明文を転載している公開資料(ESO-Hub / eso-sets.com、UESP)で
        2026-11-05に確認した値。表の構造・コードは本アドオン独自で、他アドオンのコード/データ表は
        コピーしていない。
      ・Srendarr 2.5.52 のソースを読んだ(調査のみ)。そのライセンスは「個人利用のみ許可。改変・統合・
        再配布は許可しない」であるため、Srendarrのコード・データ表(AbilityId、秒数、構造)は
        一切取り込んでいない。参考にしたのは、イベントの使い方という「考え方」だけで、実装は独自。
      ・Ability IDは「確認できたものだけ」登録する方針。今回の資料からは確認できなかったため
        ids は全て空。IDは実機で /pti cd learn で採取して /pti cd add で登録する。

    ■ status
      DOCUMENTED … ゲーム内説明文の転載資料で確認(PS5実機・日本語クライアントでの秒数照合は未実施)
      VERIFIED   … 実機で実測(ユーザー登録 /pti cd add のみ)
      UNKNOWN    … ICD秒数を確認できていない(cd = nil。表示しない)
      NOICD      … 資料上、ICDの記載が無い(表示しない)

    ■ detect(検知方式の見込み。説明文からの推定で、PS5実機では全て未検証)
      BUFF        … 自分にバフ/ダメージシールド等が付くと説明文に書かれている → バフ走査(UI③と同じ方式)
      COMBAT      … ダメージ・召喚・敵への効果が主で自分のバフ欄に残らない → 戦闘イベント方式の候補
                    (自分発のEVENT_COMBAT_EVENTで、能力名がセット名と一致した時に検知する。
                     一致するかはセットごとに未確認。ICDが5秒未満のセットは名前一致では検知しない)
      TARGET      … 対象ごとにCDがあるため、単一のタイマーでは正確に表示できない(非対応)
      UNVERIFIED  … 自分に効果が付くか説明文から判断できない(バフ走査で名前が一致すれば検知)
      NONE        … ICDの記載が無く、検知対象外
      ※ いずれもAbilityIdは未確認。名前が一致しない場合は /pti cd probe → addev / learn → add で登録する。

    ■ 項目
      key        重複登録を防ぐ一意キー(英数字)
      names      セット名の候補(英語/日本語)。/pti cd alias <key> <セット名> で日本語名を後から追加可
      ids        発動時に付くバフのAbilityId(確認できたものだけ)
      cd         ICD秒数(数値)。未確認はnil
      origin     CDの起点。省略=バフが付いた時(GAIN) / "STACKMAX"=最大スタック到達時または
                 効果終了時のどちらか早い方 / "FADE"=効果終了時
      maxStacks  STACKMAXの最大スタック数
      buffNames  セット名と異なるバフ名の候補
      trigger    発動条件(日本語の要約)
      note       補足
--]]

PvPTargetInfo = PvPTargetInfo or {}
local PTI = PvPTargetInfo

local entries, byKey = {}, {}
PTI.CDData = { entries = entries, byKey = byKey }

local function D(key, names, cd, detect, trigger, extra)
    local e = {
        key = key, names = names, ids = {}, cd = cd,
        status = (cd and "DOCUMENTED") or "UNKNOWN",
        detect = detect, trigger = trigger,
    }
    if extra then for k, v in pairs(extra) do e[k] = v end end
    entries[#entries + 1] = e
    byKey[key] = e
end

-- ===== PvP優先セット =====
D("orpheon", { "Orpheon the Tactician", "モンマス戦術家", "戦術家オルフェオン" }, 8, "COMBAT",
  "戦闘中、地面に効果を残すスキルを使うと触手が出現(ダメージ+スタン)", { note = "自分にバフが付かないため検知不可" })
D("mechanicalacuity", { "Mechanical Acuity", "機械的精度" }, 25, "BUFF",
  "非クリティカルダメージで最大5スタック(1秒に1回)。最大スタック到達または効果終了後25秒は再発動しない",
  { origin = "STACKMAX", maxStacks = 5, buffNames = { "Mechanical Acuity", "機械的精度" },
    note = "「1秒に1回」はスタック間隔でありICDではない。ICD起点は最大スタック到達か効果終了" })
D("soulcleaver", { "Soulcleaver", "ソウルクリーバー" }, nil, "NONE",
  "戦闘中、シフォン系スキルのダメージ/回復+15%、コスト-15%。使用でアルティメット1消費・与ダメージ増加(20秒)",
  { status = "NOICD", note = "5ピース効果にICDの記載なし(効果時間20秒のみ)。ICDとして表示しない" })
D("viciousdeath", { "Vicious Death", "残忍な死" }, nil, "UNVERIFIED", "", { note = "ICD秒数を資料で確認できなかった" })
D("nocturnalsploy", { "Nocturnal's Ploy" }, nil, "UNVERIFIED", "",
  { note = "PTS時点のフォーラム投稿に2秒との記載があるが、現行値の確認が取れていないため未登録" })
D("pillarofnirn", { "Pillar of Nirn" }, 10, "COMBAT", "4ピース: ダメージ+出血付与(自分バフ無し)")
D("blooddrinker", { "Blood Drinker" }, nil, "UNVERIFIED", "", { note = "ICD秒数を資料で確認できなかった" })
D("venomoussmite", { "Venomous Smite" }, nil, "UNVERIFIED", "", { note = "ICD秒数を資料で確認できなかった" })
D("overwhelmingsurge", { "Overwhelming Surge" }, nil, "UNVERIFIED", "", { note = "ICD秒数を資料で確認できなかった" })

-- ===== モンスターヘルム/ショルダー =====
D("anthelmirs", { "Anthelmir's Construct" }, 10, "COMBAT", "フルチャージ強攻撃で斧を投擲(命中済みの斧を拾うとCD-5秒)")
D("archdruid", { "Archdruid Devyric" }, 15, "COMBAT", "強攻撃の1.2秒後に雷ダメージ+メジャー脆弱")
D("barsakka", { "Bar-Sakka" }, 10, "BUFF", "戦闘中ロールダッジで血の池+ダメージシールド")
D("baronthirsk", { "Baron Thirsk" }, 25, "COMBAT", "範囲直接ダメージで対象をマーク→爆発スキャンプ")
D("blackgem", { "Black Gem Monstrosity" }, 6, "COMBAT", "戦闘中ソウルマジック使用でソウルジェム消費")
D("bloodspawn", { "Bloodspawn" }, 5, "BUFF", "被ダメージ時6%でアルティメット13+耐性上昇5秒")
D("chokethorn", { "Chokethorn" }, 10, "COMBAT", "コスト付き回復スキルで33%、絞殺の苗木を召喚")
D("domihaus", { "Domihaus" }, 15, "UNVERIFIED", "ダメージを与えると溶岩の輪(輪の中で武器/スペルダメージ+300)")
D("earthgore", { "Earthgore" }, 20, "COMBAT", "HP50%未満の味方を回復すると血の池")
D("encratis", { "Encratis's Behemoth" }, 15, "BUFF", "炎ダメージでBehemoth's Aura(12秒)")
D("engineguardian", { "Engine Guardian" }, 10, "COMBAT", "コスト付きスキルで25%、ドワーフ自動人形を召喚")
D("euphotic", { "Euphotic Gatekeeper" }, 20, "COMBAT", "ロールダッジ後にハドリッドの殻を生成")
D("glitteringgoad", { "Glittering Goad" }, 8, "COMBAT", "バッシュ/強攻撃で敵に凍結ダメージ")
D("grothdarr", { "Grothdarr" }, 10, "COMBAT", "8m以内の敵へダメージで10%、溶岩だまり")
D("grundwulf", { "Grundwulf" }, 5, "COMBAT", "クリティカルダメージでマジカ/スタミナ回復")
D("iceheart", { "Iceheart" }, 6, "BUFF", "クリティカルダメージで20%、ダメージシールド(6秒)")
D("ilambris", { "Ilambris" }, 8, "COMBAT", "炎/雷ダメージで33%、流星群")
D("immolatorcharr", { "Immolator Charr" }, 40, "BUFF", "HP50%未満で被ダメージ時、拘束/スネア/CC免疫(10秒)")
D("infernalguardian", { "Infernal Guardian" }, 6, "COMBAT", "ダメージシールド付与時50%で迫撃砲")
D("kargaeda", { "Kargaeda" }, 20, "UNVERIFIED", "強攻撃で旋風を生成(グループのコスト-10%)")
D("ladymalygda", { "Lady Malygda" }, 15, "COMBAT", "12m以内への直接ダメージで範囲攻撃+マイナーエナベーション")
D("ladythorn", { "Lady Thorn" }, 10, "COMBAT", "HPコストのスキルで血の玉(シナジー)")
D("lordwarden", { "Lord Warden" }, 10, "UNVERIFIED", "被ダメージ時50%で影の宝珠(周囲の耐性上昇10秒)")
D("maarselok", { "Maarselok" }, 10, "COMBAT", "近接強攻撃で腐敗の噴射")
D("magmaincarnate", { "Magma Incarnate" }, 15, "UNVERIFIED", "単体回復スキルで最低HPのグループメンバーにマイナー効果")
D("mawinfernal", { "Maw of the Infernal" }, 15, "COMBAT", "軽/強攻撃で33%、ダエドロスを召喚")
D("molagkena", { "Molag Kena" }, 6, "BUFF", "軽攻撃を連続2回でOverkill(6秒)", { buffNames = { "Overkill" } })
D("motherciannait", { "Mother Ciannait" }, 7, "BUFF", "戦闘中、詠唱/チャネリングでダメージシールド(6秒)")
D("mylenne", { "Mylenne Moon-Caller" }, 10, "COMBAT", "クラススキル/ウェアウルフ攻撃の直接ダメージで出血")
D("nazaray", { "Nazaray" }, 30, "TARGET", "アルティメット使用で敵のデバフ延長(対象ごとに30秒)", { note = "対象ごとのCDのため単一タイマーでは不正確" })
D("nerieneth", { "Nerien'eth" }, 3, "COMBAT", "直接ダメージで15%、リッチの結晶")
D("nightflame", { "Nightflame" }, 10, "COMBAT", "回復時20%、癒しのトーテム")
D("nunatak", { "Nunatak" }, 15, "COMBAT", "冷気ダメージで凍結エリア")
D("piratesskeleton", { "Pirate Skeleton" }, 20, "BUFF", "被ダメージ時、スケルトン化(メジャープロテクション+マイナーデファイル15秒)")
D("priorthierric", { "Prior Thierric" }, 15, "COMBAT", "範囲直接ダメージで影の旋風")
D("scourgeharvester", { "Scourge Harvester" }, 6, "BUFF", "被ダメージ時10%、敵と鎖でつながる(メジャーヴァイタリティ)")
D("selene", { "Selene" }, 6, "COMBAT", "近接の武技ダメージで精霊の攻撃")
D("sellistrix", { "Sellistrix" }, 6, "COMBAT", "ダメージで敵の足元に地震(スタン)")
D("sentinelrkugamz", { "Sentinel of Rkugamz" }, 15, "COMBAT", "回復時、ドワーフスパイダーを召喚")
D("shadowrend", { "Shadowrend" }, 15, "COMBAT", "被ダメージ時、クランフィアを召喚")
D("spawnmephala", { "Spawn of Mephala" }, 10, "COMBAT", "フルチャージ強攻撃で足元に蜘蛛の巣")
D("squall", { "Squall of Retribution" }, 4.5, "BUFF", "被ダメージ時、ランダム効果(プロテクション/シールド/継続回復)6秒")
D("stonehusk", { "Stone Husk" }, 10, "UNVERIFIED", "強攻撃で敵と鎖でつながる(Husk Drain)")
D("stonekeeper", { "Stonekeeper" }, 14, "UNVERIFIED", "ブロックでチャージ。6チャージで解放→以後14秒チャージ不可", { note = "CD起点は解放後" })
D("stormfist", { "Stormfist" }, 8, "COMBAT", "ダメージで10%、雷の拳")
D("swarmmother", { "Swarm Mother" }, 1, "COMBAT", "8〜22mの敵をブロックで引き寄せ・挑発")
D("symphonyblades", { "Symphony of Blades" }, 18, "TARGET", "HP50%未満の味方の回復で付与(対象ごと)", { note = "対象ごとのCDのため単一タイマーでは不正確" })
D("tarcyr", { "Tarcyr" }, 0.5, "COMBAT", "バトルスピリット無効時の被ダメージで攻撃者を恐怖/メジャーコワード")
D("theblind", { "The Blind" }, 6, "TARGET", "クリティカル回復で対象にシールド(対象ごと)", { note = "対象ごとのCDのため単一タイマーでは不正確" })
D("thurvokun", { "Thurvokun" }, 16, "COMBAT", "近くの敵から被ダメージで汚染された胆汁")
D("tremorscale", { "Tremorscale" }, 10, "COMBAT", "挑発スキルで砂の化け物が出現")
D("valkynskoria", { "Valkyn Skoria" }, 5, "COMBAT", "継続ダメージで8%、隕石")
D("velidreth", { "Velidreth" }, 8, "COMBAT", "ダメージで20%、病原胞子")
D("vykosa", { "Vykosa" }, 15, "COMBAT", "挑発した敵をバッシュで恐怖(メジャーコワード)")
D("zaan", { "Zaan" }, 20, "COMBAT", "軽/強攻撃のクリティカルで33%、敵と鎖でつながる")

-- ===== クラフトセット/その他 =====
D("ashengrip", { "Ashen Grip" }, 4, "COMBAT", "近接の武技ダメージで炎のブレス")
D("coldharbourfavorite", { "Coldharbour's Favorite" }, 10, "COMBAT", "回復/ダメージで出現して爆発")
D("daringcorsair", { "Daring Corsair" }, 8, "BUFF", "武器スキル使用でマイナーヒロイズム(8秒)")
D("dauntlesscombatant", { "Dauntless Combatant" }, 21, "BUFF", "行動不能効果を受けると自動でブレイクフリー→Winded(21秒)", { note = "ICDは「Winded」の間" })
D("deadlandsdemolisher", { "Deadlands Demolisher" }, 2, "COMBAT", "バッシュで円錐ダメージ")
D("deathswind", { "Death's Wind" }, 15, "COMBAT", "HP35%未満で近接被ダメージ時、ノックバック+スタン")
D("morkuldin", { "Morkuldin" }, 15, "COMBAT", "軽/強攻撃で武器を召喚")
D("nagashaman", { "Naga Shaman" }, 6, "BUFF", "ダメージシールド付与でマイナーメンディング+マイナーヴァイタリティ")
D("noblesconquest", { "Noble's Conquest" }, 10, "COMBAT", "バッシュで継続回復+マイナー脆弱(回復部分のCD)")
D("nocturnalsfavor", { "Nocturnal's Favor" }, 5, "UNVERIFIED", "ダッジ成功で継続回復")
D("sloadssemblance", { "Sload's Semblance" }, 6, "COMBAT", "ダメージで10%、シャドウパール")
D("songoflamae", { "Song of Lamae" }, 3, "COMBAT", "HP30%未満の被ダメージ時に反撃")
D("spectreseye", { "Spectre's Eye" }, 30, "BUFF", "戦闘中のマジカスキルでメジャーイベイジョン(30秒)")
D("tavasfavor", { "Tava's Favor" }, 3, "UNVERIFIED", "ダッジ時にアルティメット12を3秒かけて生成")
D("tharrikers", { "Tharriker's Strike" }, 1, "BUFF", "フルチャージ強攻撃でメジャーベルセルク(4秒)")
D("unchainedaggressor", { "Unchained Aggressor" }, 14, "BUFF", "ブレイクフリー後メジャーベルセルク(12秒)")
D("varenslegacy", { "Varen's Legacy" }, 2, "UNVERIFIED", "ブロック後5秒以内の範囲直接ダメージが追加ダメージ")
D("whitestrakes", { "Whitestrake's Retribution" }, 15, "BUFF", "HP30%未満の被ダメージ時、ダメージシールド(6秒)")
