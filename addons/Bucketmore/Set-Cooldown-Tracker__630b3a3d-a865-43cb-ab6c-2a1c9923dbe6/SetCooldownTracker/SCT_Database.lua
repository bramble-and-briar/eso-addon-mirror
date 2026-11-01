-- SetCooldownTracker v1.0.0 : データベース
-- 追加方法は README_JP.md の「データベースへの追加方法」を参照。
-- status: VERIFIED=実機検証済み / DOCUMENTED=資料確認済み / UNKNOWN=未確認
-- icd は秒。nil の場合は推測せず、ツールチップ解析値(使える場合のみ)を使う。
-- abilityIds が空のエントリは「検知不可(ID未確認)」として扱い、画面には表示しない。

SetCooldownTracker = SetCooldownTracker or {}
local SCT = SetCooldownTracker

SCT.DB = {
    {
        key = "UmbralEdge", nameEn = "Umbral Edge",
        setIds = { 778 }, abilityIds = { 226384 },
        icd = 6, status = "DOCUMENTED",
        cond = "未確認(資料に記載なし)", trigger = "ANY",
        source = "ExoY's ProcSet Timer の設定値 (ESOUIコメント掲載, 2026-04)",
    },
    {
        key = "Sentry", nameEn = "Sentry",
        setIds = { 89 }, abilityIds = { 117391 },
        icd = 30, status = "DOCUMENTED",
        cond = "未確認(資料に記載なし)", trigger = "ANY",
        source = "ExoY's ProcSet Timer の設定値 (ESOUIコメント掲載, 2025-03)",
    },
    {
        key = "OrpheonTheTactician", nameEn = "Orpheon the Tactician",
        setIds = { 801 }, abilityIds = { 236654 },
        icd = 8, status = "DOCUMENTED",
        cond = "未確認(資料に記載なし)", trigger = "ANY",
        source = "ExoY's ProcSet Timer の設定値 (ESOUIコメント掲載, 2026-03)",
    },
    {
        key = "HuntsmansWarmask", nameEn = "Huntsman's Warmask",
        setIds = { 845 }, abilityIds = { 252048 },
        icd = 60, status = "DOCUMENTED",
        cond = "未確認(資料に記載なし)", trigger = "ANY",
        source = "ExoY's ProcSet Timer の設定値 (ESOUIコメント掲載, 2026-03)",
    },
}

-- 名前のみ把握していて Ability ID / 内部CD が未確認のセット(検知対象外・UNKNOWN)。
-- 出典: ExoY's ProcSet Timer の対応セット一覧。IDが判明したら上の SCT.DB に移す。
SCT.PENDING = {
    "Destructive Impact", "Wrath of Elements", "Void Bash", "Force Overflow", "Winterborn",
    "Clever Alchemist", "Mechanical Acuity", "Spectre's Eye",
    "Bani's Torment", "Burning Spellweave", "Crimson Twilight", "Drake's Rush", "Hiti's Hearth",
    "Hollowfang Thirst", "Icy Conjuror", "Kinras's Wrath", "Plague Slinger", "Scathing Mage",
    "Tzogvin's Warband", "Z'en's Redress",
    "Briarheart", "Mad Tinkerer", "Martial Knowledge", "Shadow of the Red Mountain",
    "Venomous Smite", "Winter's Respite",
    "Meritorious Service", "Powerful Assault",
    "Bahsei's Mania", "Berserking Warrior", "Kyne's Wind", "Lunar Bastion", "Mantle of Siroria",
    "Olorime", "Roaring Opportunist", "Stone-Talker's Oath", "Sun-Xal Tormenter",
    "Vrol's Command", "Yolnahkriin",
    "Earthgore", "Encratis's Behemoth", "Iceheart", "Grothdarr", "Lady Thorn", "Nightflame",
    "Sellistrix", "Sentinel of Rkugamz", "Tremorscale", "Vykosa", "Zaan",
    "Death Dealer's Fete", "Harpooner's Wading Kilt", "Thrassian Stranglers",
    "Spaulder of Ruins", "Bloodlord's Embrace",
    "Alkosh", "Rallying Cry", "Sergeant's Mail", "Gorethief", "Stonehulk Domination",
    "Jerensi's Bladestorm", "Lucilla's Windshield", "Vandorallen's Resonance",
    "Fledgling's Nest", "Noxious Boulder", "Crimson Oath's Rive",
}
