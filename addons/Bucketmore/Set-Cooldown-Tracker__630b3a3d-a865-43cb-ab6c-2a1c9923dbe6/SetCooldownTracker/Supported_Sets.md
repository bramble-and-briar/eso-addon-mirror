# 対応セット一覧（v1.0.1）

PS5実機での検証は未実施です。検証状態の「DOCUMENTED」は第三者アドオン（ExoY's ProcSet Timer）の設定値に基づく資料確認で、本アドオン作者による実機確認ではありません。Update 51での変更は未確認です。

## 検知可能（Ability ID登録済み）

| セット | セットID | Ability ID | 内部CD | 検証状態 | 発動条件 |
|---|---|---|---|---|---|
| Umbral Edge | 778 | 226384 | 6秒 | DOCUMENTED | 未確認 |
| Sentry | 89 | 117391 | 30秒 | DOCUMENTED | 未確認 |
| Orpheon the Tactician | 801 | 236654 | 8秒 | DOCUMENTED | 未確認 |
| Huntsman's Warmask | 845 | 252048 | 60秒 | DOCUMENTED | 未確認 |

## 名前のみ把握・検知不可（UNKNOWN）

Ability ID・内部CD・発動条件が未確認のため、現状は表示も検知もしません。IDが判明したら `SCT_Database.lua` へ追記してください。

- アリーナ: Destructive Impact / Wrath of Elements / Void Bash / Force Overflow / Winterborn
- クラフト: Clever Alchemist / Mechanical Acuity / Spectre's Eye
- ダンジョン: Bani's Torment / Burning Spellweave / Crimson Twilight / Drake's Rush / Hiti's Hearth / Hollowfang Thirst / Icy Conjuror / Kinras's Wrath / Plague Slinger / Scathing Mage / Tzogvin's Warband / Z'en's Redress / Jerensi's Bladestorm / Lucilla's Windshield / Vandorallen's Resonance / Fledgling's Nest / Noxious Boulder / Crimson Oath's Rive / Gorethief
- 世界: Briarheart / Mad Tinkerer / Martial Knowledge / Shadow of the Red Mountain / Venomous Smite / Winter's Respite
- PvP: Meritorious Service / Powerful Assault / Rallying Cry / Sergeant's Mail
- トライアル: Bahsei's Mania / Berserking Warrior / Kyne's Wind / Lunar Bastion / Mantle of Siroria / Olorime / Roaring Opportunist / Stone-Talker's Oath / Sun-Xal Tormenter / Vrol's Command / Yolnahkriin / Alkosh
- アンドーンテッド: Earthgore / Encratis's Behemoth / Iceheart / Grothdarr / Lady Thorn / Nightflame / Sellistrix / Sentinel of Rkugamz / Tremorscale / Vykosa / Zaan / Stonehulk Domination
- ミスティカル: Death Dealer's Fete / Harpooner's Wading Kilt / Thrassian Stranglers / Spaulder of Ruins / Bloodlord's Embrace

注: 一部は「CDではなくスタック/条件型」でそもそも単純な内部CD表示に向かない可能性があります（例: Alkoshは、ESOUI上のCooldownsアドオンの説明では通常のCDが無いとされています）。
