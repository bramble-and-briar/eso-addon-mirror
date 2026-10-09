-- =====================================================================
--  Team Shadows Buffs - Catalogue d'effets
-- ---------------------------------------------------------------------
--  Donnée brute (catégories / noms / ids / couleurs / cible / méta),
--  normalisée pour le reste de l'addon :
--    color {r,g,b,a} tableau  ->  { r=, g=, b=, a= }
--    target "Yourself"/"Current Target"  ->  targetType "player"/"target"
--  Les champs maxStacks et cooldown sont conservés comme métadonnées
--  (affichés dans l'UI ; le décompte en combat n'est pas encore géré).
--
--  Charger AVANT modules/MajorEffects.lua dans le .txt :
--      TeamShadowsBuffsCatalog.lua
--      modules/MajorEffects.lua
-- =====================================================================

TeamShadowsBuffs = TeamShadowsBuffs or {}
local TSB = TeamShadowsBuffs

-- Catégories d'origine : activées par défaut (comportement historique).
-- Toutes les autres : désactivées par défaut (sinon l'écran serait noyé).
-- Tous les trackers sont désactivés par défaut : l'utilisateur active ce qu'il veut
-- (ou importe une config partagée). Aucune catégorie n'est activée d'office.
local CORE_CATEGORIES = {}

local rawCategories = {
    {
        key = "major_buffs", name = "Buffs majeurs du joueur", nameEn = "Major Player Buffs",
        entries = {
            { key = "major_slayer", shortName = "TM", name = "Tueur majeur", ids = { 93109, 93120, 93442 }, color = { 0.20, 0.72, 0.32, 1 }, target = "Yourself" },
            { key = "major_courage", shortName = "CM", name = "Courage majeur", ids = { 109966 }, color = { 0.22, 0.56, 0.96, 1 }, target = "Yourself" },
            { key = "major_force", shortName = "FM", name = "Force majeure", ids = { 46539, 61747, 40224 }, icon = "/esoui/art/icons/ability_buff_major_force.dds", color = { 0.88, 0.72, 0.20, 1 }, target = "Yourself" },
            { key = "major_berserk", shortName = "BK", name = "Berserk majeur", ids = { 62195 }, color = { 0.80, 0.20, 0.24, 1 }, target = "Yourself" },
            { key = "major_brutality", shortName = "BR", name = "Brutalité majeure", ids = { 61665, 61687, 92507, 92503, 92512 }, color = { 0.80, 0.32, 0.10, 1 }, target = "Yourself" },
            { key = "major_savagery", shortName = "SV", name = "Sauvagerie majeure", ids = { 61667, 61689 }, color = { 0.10, 0.72, 0.48, 1 }, target = "Yourself" },
            { key = "major_resolve", shortName = "RS", name = "Résolution majeure", ids = { 61694, 86224, 88758, 88761 }, color = { 0.64, 0.64, 0.72, 1 }, target = "Yourself" },
            { key = "major_heroism", shortName = "HE", name = "Héroïsme majeur", ids = { 61709 }, color = { 0.95, 0.55, 0.18, 1 }, target = "Yourself" },
            { key = "major_expedition", shortName = "EX", name = "Expédition majeure", ids = { 61736, 101161, 101169, 101178 }, color = { 0.18, 0.76, 0.86, 1 }, target = "Yourself" },
        },
    },
    {
        key = "class_masteries", name = "Maîtrises de classe", nameEn = "Class Masteries",
        entries = {
            -- Arcaniste
            { key = "mastery_arcanist_abyssal_emergence", shortName = "ARC1", name = "Abyssal Emergence", ids = { 263316 }, procIds = { 263369 }, procDuration = 15, color = { 0.20, 0.82, 0.70, 1 }, target = "Yourself" },
            { key = "mastery_arcanist_fate_realigned", shortName = "ARC2", name = "Fate Realigned", ids = { 263398 }, procIds = { 268372 }, procDuration = 25, color = { 0.20, 0.82, 0.70, 1 }, target = "Yourself" },
            { key = "mastery_arcanist_unbound_potential", shortName = "ARC3", name = "Unbound Potential", ids = { 263410 }, procIds = { 263411 }, color = { 0.20, 0.82, 0.70, 1 }, target = "Yourself" },
            { key = "mastery_arcanist_erudites_rigor", shortName = "ARC4", name = "Erudite's Rigor", ids = { 263412 }, color = { 0.20, 0.82, 0.70, 1 }, target = "Yourself" },
            { key = "mastery_arcanist_ink_scribes_verve", shortName = "ARC5", name = "Ink-Scribe's Verve", ids = { 263416 }, procIds = { 263419 }, color = { 0.20, 0.82, 0.70, 1 }, target = "Yourself" },

            -- Chevalier-dragon
            { key = "mastery_dragonknight_inexorable_descent", shortName = "DK1", name = "Inexorable Descent", ids = { 238232 }, procIds = { 263197 }, maxStacks = 5, color = { 0.92, 0.34, 0.12, 1 }, target = "Yourself" },
            { key = "mastery_dragonknight_booming_voice", shortName = "DK2", name = "Booming Voice", ids = { 240268 }, procIds = { 270020 }, procDuration = 10, color = { 0.92, 0.34, 0.12, 1 }, target = "Yourself" },
            { key = "mastery_dragonknight_wildfire_embers", shortName = "DK3", name = "Wildfire Embers", ids = { 259224 }, procIds = { 263208 }, procDuration = 12, procTarget = "boss", maxStacks = 12, color = { 0.92, 0.34, 0.12, 1 }, target = "Yourself" },
            { key = "mastery_dragonknight_resolute_defense", shortName = "DK4", name = "Resolute Defense", ids = { 263220 }, procIds = { 263230 }, maxStacks = 5, color = { 0.92, 0.34, 0.12, 1 }, target = "Yourself" },
            { key = "mastery_dragonknight_lead_from_front", shortName = "DK5", name = "Lead from the Front", ids = { 263247 }, procIds = { 263306 }, procTarget = "friendly", color = { 0.92, 0.34, 0.12, 1 }, target = "Yourself" },

            -- Necromancien
            { key = "mastery_necromancer_nothing_wasted", shortName = "NEC1", name = "Nothing Wasted", ids = { 263448 }, procIds = { 263461 }, procDuration = 10, maxStacks = 10, color = { 0.46, 0.72, 0.30, 1 }, target = "Yourself" },
            { key = "mastery_necromancer_malevolent_promise", shortName = "NEC2", name = "Malevolent Promise", ids = { 263465 }, procIds = { 263468 }, procDuration = 6, procTarget = "boss", color = { 0.46, 0.72, 0.30, 1 }, target = "Yourself" },
            { key = "mastery_necromancer_cycle_unending", shortName = "NEC3", name = "Cycle Unending", ids = { 263509 }, procIds = { 263532 }, procDuration = 25, color = { 0.46, 0.72, 0.30, 1 }, target = "Yourself" },
            { key = "mastery_necromancer_pound_of_flesh", shortName = "NEC4", name = "Pound of Flesh", ids = { 263549 }, color = { 0.46, 0.72, 0.30, 1 }, target = "Yourself" },
            { key = "mastery_necromancer_veils_forfeit", shortName = "NEC5", name = "Veil's Forfeit", ids = { 263554 }, color = { 0.46, 0.72, 0.30, 1 }, target = "Yourself" },

            -- Gardien
            { key = "mastery_warden_tundras_maw", shortName = "WAR1", name = "Tundra's Maw", ids = { 263519 }, procIds = { 263825 }, procDuration = 2, procTarget = "boss", color = { 0.28, 0.68, 0.90, 1 }, target = "Yourself" },
            { key = "mastery_warden_wild_adaptation", shortName = "WAR2", name = "Wild Adaptation", ids = { 263520 }, color = { 0.28, 0.68, 0.90, 1 }, target = "Yourself" },
            { key = "mastery_warden_glacial_obstinance", shortName = "WAR3", name = "Glacial Obstinance", ids = { 263521 }, procIds = { 267305 }, procDuration = 10, color = { 0.28, 0.68, 0.90, 1 }, target = "Yourself" },
            { key = "mastery_warden_green_keepers_hide", shortName = "WAR4", name = "Green-Keeper's Hide", ids = { 263522 }, color = { 0.28, 0.68, 0.90, 1 }, target = "Yourself" },
            { key = "mastery_warden_bountiful_harvest", shortName = "WAR5", name = "Bountiful Harvest", ids = { 263523 }, procIds = { 268257 }, procDuration = 3, procTarget = "friendly", color = { 0.28, 0.68, 0.90, 1 }, target = "Yourself" },

            -- Templier
            { key = "mastery_templar_bastion_of_light", shortName = "TEM1", name = "Bastion of Light", ids = { 263585 }, color = { 0.94, 0.76, 0.22, 1 }, target = "Yourself" },
            { key = "mastery_templar_devout_guardian", shortName = "TEM2", name = "Devout Guardian", ids = { 263586 }, procIds = { 263619 }, procDuration = 6, color = { 0.94, 0.76, 0.22, 1 }, target = "Yourself" },
            { key = "mastery_templar_bright_harbinger", shortName = "TEM3", name = "Bright Harbinger", ids = { 263587 }, procIds = { 263672 }, color = { 0.94, 0.76, 0.22, 1 }, target = "Yourself" },
            { key = "mastery_templar_judgments_brand", shortName = "TEM4", name = "Judgment's Brand", ids = { 263588 }, procIds = { 263660 }, procDuration = 3.1, color = { 0.94, 0.76, 0.22, 1 }, target = "Yourself" },
            { key = "mastery_templar_steadfast_candescence", shortName = "TEM5", name = "Steadfast Candescence", ids = { 263589 }, procIds = { 263643 }, color = { 0.94, 0.76, 0.22, 1 }, target = "Yourself" },

            -- Lame noire
            { key = "mastery_nightblade_nocturnal_inspiration", shortName = "NB1", name = "Nocturnal Inspiration", ids = { 263603 }, color = { 0.74, 0.22, 0.42, 1 }, target = "Yourself" },
            { key = "mastery_nightblade_eye_for_exploitation", shortName = "NB2", name = "An Eye for Exploitation", ids = { 263604 }, color = { 0.74, 0.22, 0.42, 1 }, target = "Yourself" },
            { key = "mastery_nightblade_above_and_beyond", shortName = "NB3", name = "Above and Beyond", ids = { 263605 }, color = { 0.74, 0.22, 0.42, 1 }, target = "Yourself" },
            { key = "mastery_nightblade_cutthroats_focus", shortName = "NB4", name = "Cutthroat's Focus", ids = { 263606 }, procIds = { 263685 }, procDuration = 0.3, color = { 0.74, 0.22, 0.42, 1 }, target = "Yourself" },
            { key = "mastery_nightblade_share_the_spoils", shortName = "NB5", name = "Share the Spoils", ids = { 263607 }, color = { 0.74, 0.22, 0.42, 1 }, target = "Yourself" },

            -- Sorcier
            { key = "mastery_sorcerer_conservation_of_energy", shortName = "SOR1", name = "Conservation of Energy", ids = { 263870 }, color = { 0.48, 0.34, 0.92, 1 }, target = "Yourself" },
            { key = "mastery_sorcerer_font_of_power", shortName = "SOR2", name = "Font of Power", ids = { 263871 }, procIds = { 263878 }, procDuration = 10, color = { 0.48, 0.34, 0.92, 1 }, target = "Yourself" },
            { key = "mastery_sorcerer_static_reverberation", shortName = "SOR3", name = "Static Reverberation", ids = { 263872 }, color = { 0.48, 0.34, 0.92, 1 }, target = "Yourself" },
            { key = "mastery_sorcerer_calculated_defense", shortName = "SOR4", name = "Calculated Defense", ids = { 263873 }, procIds = { 264991, 268274 }, color = { 0.48, 0.34, 0.92, 1 }, target = "Yourself" },
            { key = "mastery_sorcerer_sphere_of_influence", shortName = "SOR5", name = "Sphere of Influence", ids = { 263874 }, procIds = { 263915, 268275 }, color = { 0.48, 0.34, 0.92, 1 }, target = "Yourself" },
        },
    },
    {
        key = "boss_debuffs", name = "Débuffs des boss", nameEn = "Boss Debuffs",
        entries = {
            { key = "major_vulnerability", shortName = "VM", name = "Vulnérabilité", ids = { 106754, 122389, 122177 }, color = { 0.82, 0.18, 0.22, 1 }, target = "Current Target" },
            { key = "major_breach", shortName = "BRc", name = "Brèche", ids = { 61743, 53881, 62775, 62787 }, color = { 0.82, 0.34, 0.10, 1 }, target = "Current Target" },
            { key = "major_brittle", shortName = "FG", name = "Fragilité", ids = { 145977 }, color = { 0.62, 0.25, 0.82, 1 }, target = "Current Target" },
            { key = "major_cowardice", shortName = "LC", name = "Lâcheté", ids = { 147643 }, color = { 0.34, 0.45, 0.86, 1 }, target = "Current Target" },
            { key = "major_maim", shortName = "MM", name = "Mutilation", ids = { 133292 }, color = { 0.62, 0.18, 0.18, 1 }, target = "Current Target" },
            { key = "off_balance", shortName = "DE", name = "Déséquilibre", ids = { 39077, 63003, 102771 }, color = { 0.95, 0.86, 0.18, 1 }, target = "Current Target" },
        },
    },
    {
        key = "set_stacks", name = "Sets à stacks", nameEn = "Stacking Sets",
        entries = {
            { key = "twice_fanged_serpent", shortName = "TFS", name = "Serpent à deux crocs", setIds = { 144 }, setNames = { "Serpent à deux crocs", "Twice-Fanged Serpent" }, ids = { 51176 }, maxStacks = 5, color = { 0.24, 0.78, 0.42, 1 }, target = "Yourself" },
            { key = "berserking_warrior", shortName = "AY", name = "Yokeda implacable", setIds = { 137 }, setNames = { "Yokeda implacable", "Advancing Yokeda", "Berserking Warrior" }, ids = { 50978 }, maxStacks = 5, color = { 0.92, 0.38, 0.16, 1 }, target = "Yourself" },
            { key = "siroria_boon", shortName = "SI", name = "Faveur de Siroria", setIds = { 390, 394 }, setNames = { "Manteau de Siroria", "Mantle of Siroria", "Perfected Mantle of Siroria" }, ids = { 110118, 110142 }, maxStacks = 20, color = { 0.92, 0.62, 0.18, 1 }, target = "Yourself" },
            { key = "arms_relequen", shortName = "RL", name = "Relequen - vents nuisibles", setIds = { 389, 393 }, setNames = { "Armes de Relequen", "Arms of Relequen", "Perfected Arms of Relequen" }, ids = { 110504 }, maxStacks = 20, color = { 0.30, 0.72, 0.96, 1 }, target = "Current Target" },
            { key = "tzogvin_precision", shortName = "TZ", name = "Tzogvin - précision", setIds = { 430 }, setNames = { "Bande de guerre de Tzogvin", "Tzogvin's Warband" }, ids = { 116742 }, maxStacks = 10, color = { 0.34, 0.82, 0.92, 1 }, target = "Yourself" },
            { key = "kinras_wrath", shortName = "KI", name = "Courroux de Kinras", setIds = { 570 }, setNames = { "Courroux de Kinras", "Kinras's Wrath" }, ids = { 150750 }, maxStacks = 5, color = { 0.92, 0.24, 0.12, 1 }, target = "Yourself" },
            { key = "zens_redress", shortName = "ZEN", name = "Réparation de Z'en", setIds = { 455 }, setNames = { "Réparation de Z'en", "Z'en's Redress" }, ids = { 126597 }, maxStacks = 5, cooldown = 22, color = { 0.14, 0.56, 0.94, 1 }, target = "Current Target" },
            { key = "elemental_catalyst", shortName = "EC", name = "Catalyseur élémentaire", setIds = { 516 }, setNames = { "Catalyseur élémentaire", "Elemental Catalyst" }, ids = { 142610, 142653, 142652, 181606 }, maxStacks = 3, color = { 0.70, 0.34, 0.94, 1 }, target = "Current Target" },
        },
    },
    {
        key = "set_procs", name = "Sets à proc et cooldown", nameEn = "Proc and Cooldown Sets",
        entries = {
            { key = "burning_spellweave", shortName = "BSW", name = "Toile d'araignée brûlante", setIds = { 160 }, ids = { 61459 }, cooldown = 12, color = { 0.95, 0.28, 0.08, 1 }, target = "Yourself" },
            { key = "scathing_mage", shortName = "SM", name = "Mage cruel", setIds = { 190 }, ids = { 67288 }, cooldown = 5, color = { 0.68, 0.30, 0.92, 1 }, target = "Yourself" },
            { key = "ravager", shortName = "RV", name = "Ravageur", setIds = { 108 }, ids = { 34872 }, maxStacks = 4, color = { 0.82, 0.18, 0.18, 1 }, target = "Yourself" },
            { key = "clever_alchemist", shortName = "CA", name = "Alchimiste astucieux", setNames = { "Alchimiste astucieux", "Clever Alchemist" }, ids = { 75746 }, color = { 0.20, 0.82, 0.54, 1 }, target = "Yourself" },
            { key = "powerful_assault", shortName = "PA", name = "Assaut puissant", setIds = { 180 }, ids = { 61771 }, color = { 0.28, 0.68, 0.96, 1 }, target = "Yourself" },
            { key = "mechanical_acuity", shortName = "MA", name = "Acuité mécanique", setIds = { 353 }, setNames = { "Acuité mécanique", "Mechanical Acuity" }, ids = { 99204 }, cooldown = 29, maxStacks = 5, color = { 0.92, 0.72, 0.24, 1 }, target = "Yourself" },
            { key = "olorime", shortName = "OL", name = "Vêtement d'Olorimé", nameFr = "Vêtement d'Olorimé", nameEn = "Vestment of Olorime", setNames = { "Vêtement d'Olorimé", "Vestment of Olorime" }, setIds = { 391, 395 }, ids = { 107141, 109084, 109994, 110020 }, cooldown = 10, color = { 0.92, 0.78, 0.30, 1 }, target = "Yourself" },
            { key = "hollowfang", shortName = "HF", name = "Soif de la Gueule creuse", setIds = { 452 }, ids = { 126924 }, cooldown = 9, color = { 0.58, 0.18, 0.78, 1 }, target = "Yourself" },
            { key = "maarselok", shortName = "MR", name = "Maarselok", setIds = { 459 }, ids = { 126941 }, cooldown = 10, color = { 0.32, 0.72, 0.24, 1 }, target = "Current Target" },
            { key = "sentinel_rkugamz", shortName = "SR", name = "Sentinelle de Rkugamz", setIds = { 268 }, ids = { 81036 }, cooldown = 15, color = { 0.72, 0.62, 0.26, 1 }, target = "Yourself" },
            { key = "spell_strategist", shortName = "SS", name = "Stratégiste magique", setIds = { 418 }, ids = { 113382 }, cooldown = 4, color = { 0.42, 0.64, 0.96, 1 }, target = "Current Target" },
            { key = "crimson_oath", shortName = "CO", name = "Serment écarlate", setIds = { 602 }, ids = { 159291, 159288 }, cooldown = 12, color = { 0.82, 0.16, 0.18, 1 }, target = "Current Target" },
            { key = "tremorscale", shortName = "TRs", name = "Écaille de Trembleterre", setIds = { 276 }, ids = { 80865, 80866 }, cooldown = 10, color = { 0.72, 0.52, 0.28, 1 }, target = "Current Target" },
            { key = "alkosh", shortName = "AL", name = "Rugissement d'Alkosh", setIds = { 232 }, ids = { 76667, 75753, 120018 }, color = { 0.90, 0.68, 0.22, 1 }, target = "Current Target" },
            { key = "spaulder_ruin", shortName = "SRU", name = "Spallière de ruine", setIds = { 627 }, ids = { 163401 }, equipPieces = 1, color = { 0.70, 0.26, 0.22, 1 }, target = "Yourself" },
        },
    },
    {
        key = "skill_stacks", name = "Compétences à stacks et charges", nameEn = "Stacking and Charge Abilities",
        entries = {
            { key = "arcanist_crux", shortName = "CR", name = "Crux", ids = { 184220 }, maxStacks = 3, color = { 0.18, 0.86, 0.52, 1 }, target = "Yourself" },
            { key = "grim_focus", shortName = "GF", name = "Concentration impitoyable", ids = { 61902, 122585 }, maxStacks = 5, color = { 0.74, 0.18, 0.26, 1 }, target = "Yourself" },
            { key = "merciless_resolve", shortName = "MRc", name = "Résolution impitoyable", ids = { 61919, 122586 }, maxStacks = 5, color = { 0.56, 0.16, 0.78, 1 }, target = "Yourself" },
            { key = "relentless_focus", shortName = "RF", name = "Concentration acharnée", ids = { 61927, 122587 }, maxStacks = 5, color = { 0.24, 0.64, 0.92, 1 }, target = "Yourself" },
            { key = "bound_armaments", shortName = "BA", name = "Armements liés", ids = { 24165, 203447, 130291 }, maxStacks = 4, color = { 0.46, 0.28, 0.86, 1 }, target = "Yourself" },
            { key = "seething_fury", shortName = "SF", name = "Fureur bouillonnante", ids = { 122658 }, maxStacks = 3, color = { 0.94, 0.26, 0.08, 1 }, target = "Yourself" },
            { key = "stone_giant_stagger", shortName = "ST", name = "Chancellement du Géant de pierre", ids = { 134336 }, maxStacks = 3, color = { 0.72, 0.58, 0.34, 1 }, target = "Current Target" },
        },
    },
    {
        key = "skill_procs", name = "Compétences prêtes et procs", nameEn = "Ready Abilities and Procs",
        entries = {
            { key = "assassins_will", shortName = "AW", name = "Volonté de l'assassin", ids = { 61907, 61930 }, color = { 0.76, 0.18, 0.34, 1 }, target = "Yourself" },
            { key = "assassins_scourge", shortName = "AS", name = "Fléau de l'assassin", ids = { 61932 }, color = { 0.28, 0.60, 0.96, 1 }, target = "Yourself" },
            { key = "crystal_fragments_proc", shortName = "CF", name = "Fragments de cristal prêts", ids = { 46327, 114716 }, color = { 0.46, 0.20, 0.92, 1 }, target = "Yourself" },
            { key = "blastbones_stalking", shortName = "BBs", name = "Archer squelette prêt", ids = { 117749, 117773 }, color = { 0.42, 0.72, 0.34, 1 }, target = "Yourself" },
            { key = "blastbones_blighted", shortName = "BBb", name = "Squelette explosif prêt", ids = { 117690, 117693 }, color = { 0.30, 0.68, 0.22, 1 }, target = "Yourself" },
            { key = "misery_knife", shortName = "MK", name = "Couteau de misère", ids = { 217353 }, color = { 0.66, 0.18, 0.70, 1 }, target = "Current Target" },
        },
    },
    {
        key = "support_debuffs", name = "Débuffs de raid et de soutien", nameEn = "Raid and Support Debuffs",
        entries = {
            { key = "minor_breach", shortName = "mBR", name = "Brèche mineure", ids = { 61742 }, color = { 0.92, 0.52, 0.18, 1 }, target = "Current Target" },
            { key = "minor_vulnerability", shortName = "mVM", name = "Vulnérabilité mineure", ids = { 79717 }, color = { 0.82, 0.34, 0.34, 1 }, target = "Current Target" },
            { key = "minor_brittle", shortName = "mFG", name = "Fragilité mineure", ids = { 145975 }, color = { 0.52, 0.30, 0.86, 1 }, target = "Current Target" },
            { key = "crusher", shortName = "CRu", name = "Enchantement écraseur", ids = { 17906, 120007 }, color = { 0.78, 0.54, 0.24, 1 }, target = "Current Target" },
            { key = "engulfing_flames", shortName = "EF", name = "Flammes dévorantes", ids = { 120011, 31102 }, color = { 0.96, 0.26, 0.06, 1 }, target = "Current Target" },
            { key = "minor_magickasteal", shortName = "mMS", name = "Vol de magie mineur", ids = { 88401 }, color = { 0.32, 0.48, 0.94, 1 }, target = "Current Target" },
            { key = "infallible_aether", shortName = "IA", name = "Éther infaillible", ids = { 81519 }, color = { 0.66, 0.46, 0.92, 1 }, target = "Current Target" },
            { key = "crystal_weapon", shortName = "CW", name = "Arme cristalline", ids = { 143808 }, color = { 0.38, 0.72, 0.96, 1 }, target = "Current Target" },
            { key = "runic_sunder", shortName = "RSu", name = "Fracture runique", ids = { 187742 }, color = { 0.20, 0.84, 0.68, 1 }, target = "Current Target" },
        },
    },
    {
        key = "status_effects", name = "Effets de statut", nameEn = "Status Effects",
        entries = {
            { key = "status_overcharged", shortName = "OV", name = "Surcharge", ids = { 178118 }, color = { 0.58, 0.34, 0.94, 1 }, target = "Current Target" },
            { key = "status_burning", shortName = "BU", name = "Brûlure", ids = { 18084 }, color = { 0.96, 0.24, 0.04, 1 }, target = "Current Target" },
            { key = "status_chilled", shortName = "CH", name = "Glace", ids = { 95136 }, color = { 0.30, 0.72, 0.96, 1 }, target = "Current Target" },
            { key = "status_concussed", shortName = "COc", name = "Commotion", ids = { 95134 }, color = { 0.88, 0.76, 0.18, 1 }, target = "Current Target" },
            { key = "status_sundered", shortName = "SU", name = "Fissure", ids = { 178123 }, color = { 0.74, 0.50, 0.28, 1 }, target = "Current Target" },
            { key = "status_poisoned", shortName = "PO", name = "Empoisonnement", ids = { 21929 }, color = { 0.34, 0.76, 0.18, 1 }, target = "Current Target" },
            { key = "status_diseased", shortName = "DI", name = "Maladie", ids = { 178127 }, color = { 0.48, 0.64, 0.20, 1 }, target = "Current Target" },
            { key = "status_hemorrhage", shortName = "HEM", name = "Hémorragie", ids = { 148801 }, color = { 0.78, 0.10, 0.16, 1 }, target = "Current Target" },
        },
    },
    {
        key = "monster_sets", name = "Sets de monstre à proc", nameEn = "Monster Proc Sets",
        entries = {
            { key = "grothdarr", shortName = "GR", name = "Grothdarr", setIds = { 280 }, ids = { 84504 }, cooldown = 10, color = { 0.96, 0.28, 0.06, 1 }, target = "Yourself" },
            { key = "bogdan_nightflame", shortName = "BO", name = "Bogdan la Flamme nocturne", setIds = { 167 }, ids = { 59590 }, cooldown = 10, color = { 0.42, 0.82, 0.34, 1 }, target = "Yourself" },
            { key = "earthgore", shortName = "EG", name = "Sangreterre", setIds = { 341 }, ids = { 97855 }, cooldown = 20, color = { 0.76, 0.18, 0.18, 1 }, target = "Yourself" },
            { key = "infernal_guardian", shortName = "IG", name = "Gardien infernal", setIds = { 272 }, ids = { 83405 }, cooldown = 6, color = { 0.94, 0.32, 0.08, 1 }, target = "Yourself" },
            { key = "iceheart", shortName = "IH", name = "Cœur-de-glace", setIds = { 274 }, ids = { 80562 }, cooldown = 6, color = { 0.28, 0.72, 0.96, 1 }, target = "Yourself" },
            { key = "lady_thorn", shortName = "LT", name = "Dame Ronce", setIds = { 535 }, ids = { 141905, 141971, 141927 }, cooldown = 20, color = { 0.68, 0.18, 0.24, 1 }, target = "Yourself" },
            { key = "sellistrix", shortName = "SE", name = "Sellistrix", setIds = { 271 }, ids = { 80545 }, cooldown = 6, color = { 0.62, 0.48, 0.30, 1 }, target = "Current Target" },
            { key = "encratis", shortName = "EN", name = "Béhémoth d'Encratis", setIds = { 577 }, ids = { 151033 }, cooldown = 15, color = { 0.88, 0.22, 0.10, 1 }, target = "Yourself" },
            { key = "zaan", shortName = "ZA", name = "Zaan", setIds = { 350 }, ids = { 110997, 102136, 102142 }, cooldown = 20, color = { 0.96, 0.30, 0.06, 1 }, target = "Current Target" },
        },
    },
    {
        key = "dungeon_proc_sets", name = "Sets de donjon à proc", nameEn = "Dungeon Proc Sets",
        entries = {
            { key = "caluurion", shortName = "CL", name = "Héritage de Caluurion", setIds = { 343 }, ids = { 102032 }, cooldown = 10, color = { 0.48, 0.34, 0.90, 1 }, target = "Current Target" },
            { key = "hitis_hearth", shortName = "HH", name = "Foyer de Hiti", setIds = { 471 }, ids = { 133210 }, cooldown = 12, color = { 0.34, 0.82, 0.48, 1 }, target = "Yourself" },
            { key = "spell_power_cure", shortName = "SPC", name = "Remède du pouvoir curatif", setIds = { 185 }, ids = { 66902 }, cooldown = 5, color = { 0.90, 0.78, 0.30, 1 }, target = "Yourself" },
            { key = "icy_conjuror", shortName = "IC", name = "Invocateur glacial", setIds = { 431 }, ids = { 117666 }, cooldown = 10, color = { 0.28, 0.66, 0.94, 1 }, target = "Current Target" },
            { key = "drakes_rush", shortName = "DR", name = "Ruée du Drake", setIds = { 571 }, ids = { 150974 }, cooldown = 18, color = { 0.86, 0.38, 0.14, 1 }, target = "Yourself" },
            { key = "crimson_twilight", shortName = "CT", name = "Crépuscule écarlate", setIds = { 515 }, ids = { 141638 }, cooldown = 8, color = { 0.78, 0.12, 0.20, 1 }, target = "Yourself" },
            { key = "plague_slinger", shortName = "PS", name = "Lance-peste", setIds = { 347 }, ids = { 102106 }, cooldown = 8, color = { 0.42, 0.70, 0.20, 1 }, target = "Current Target" },
            { key = "scorions_feast", shortName = "SFe", name = "Festin de Scorion", setIds = { 603 }, ids = { 159237, 159236 }, cooldown = 20, color = { 0.54, 0.26, 0.84, 1 }, target = "Yourself" },
            { key = "rush_of_agony", shortName = "RA", name = "Ruée de l'agonie", setIds = { 604 }, ids = { 159279, 159276, 159277, 159275 }, cooldown = 8, color = { 0.72, 0.18, 0.28, 1 }, target = "Current Target" },
            { key = "thunder_caller", shortName = "TC", name = "Invocateur de tonnerre", setIds = { 606 }, ids = { 159249 }, cooldown = 12, color = { 0.82, 0.72, 0.18, 1 }, target = "Current Target" },
            { key = "turning_tide", shortName = "TT", name = "Marée renversée", setIds = { 622 }, ids = { 167350 }, cooldown = 15, color = { 0.24, 0.68, 0.86, 1 }, target = "Current Target" },
            { key = "glacial_guardian", shortName = "GG", name = "Gardien glacial", setIds = { 621 }, ids = { 167114 }, cooldown = 12, color = { 0.34, 0.74, 0.96, 1 }, target = "Current Target" },
            { key = "gryphons_reprisal", shortName = "GRe", name = "Représailles du griffon", setIds = { 620 }, ids = { 167043 }, cooldown = 20, color = { 0.86, 0.62, 0.24, 1 }, target = "Current Target" },
            { key = "spriggans_vigor", shortName = "SVi", name = "Vigueur du spriggan", setIds = { 624 }, setNames = { "Vigueur du spriggan", "Spriggan's Vigor" }, ids = { 167058 }, maxStacks = 10, color = { 0.24, 0.78, 0.34, 1 }, target = "Yourself" },
            { key = "maligaligs_maelstrom", shortName = "MMa", name = "Maelström de Maligalig", setIds = { 619 }, ids = { 167040, 168019 }, cooldown = 10, color = { 0.24, 0.58, 0.94, 1 }, target = "Current Target" },
        },
    },
    {
        key = "overland_crafted_pvp_procs", name = "Sets de zone, artisanaux et JcJ", nameEn = "Overland, Crafted and PvP Sets",
        entries = {
            { key = "briarheart", shortName = "BH", name = "Roncecœur", setIds = { 212 }, ids = { 71107 }, cooldown = 15, color = { 0.58, 0.18, 0.24, 1 }, target = "Yourself" },
            { key = "venomous_smite", shortName = "VS", name = "Frappe venimeuse", setIds = { 488 }, ids = { 135690 }, cooldown = 15, color = { 0.36, 0.76, 0.16, 1 }, target = "Current Target" },
            { key = "red_mountain", shortName = "RM", name = "Montagne écarlate", setIds = { 49 }, ids = { 97806 }, cooldown = 8, color = { 0.94, 0.30, 0.06, 1 }, target = "Current Target" },
            { key = "mad_tinkerer", shortName = "MT", name = "Bricoleur fou", setIds = { 354 }, ids = { 92982 }, cooldown = 8, color = { 0.62, 0.38, 0.84, 1 }, target = "Current Target" },
            { key = "martial_knowledge", shortName = "MK2", name = "Connaissance martiale", setIds = { 147 }, ids = { 127070 }, cooldown = 8, color = { 0.84, 0.68, 0.22, 1 }, target = "Current Target" },
            { key = "meritorious_service", shortName = "MS", name = "Service méritoire", setIds = { 181 }, ids = { 65706 }, color = { 0.30, 0.68, 0.94, 1 }, target = "Yourself" },
            { key = "dark_convergence", shortName = "DC", name = "Convergence noire", setIds = { 616 }, ids = { 159388, 160317 }, cooldown = 25, color = { 0.54, 0.18, 0.76, 1 }, target = "Current Target" },
            { key = "hrothgars_chill", shortName = "HC", name = "Froid de Hrothgar", setIds = { 618 }, ids = { 159713, 159740, 159793 }, cooldown = 7, color = { 0.30, 0.70, 0.94, 1 }, target = "Current Target" },
            { key = "nunatak", shortName = "NU", name = "Nunatak", setIds = { 634 }, ids = { 167682 }, cooldown = 15, color = { 0.28, 0.74, 0.96, 1 }, target = "Current Target" },
        },
    },
    {
        key = "mythic_stacks", name = "Mythiques à stacks et effets", nameEn = "Mythic Stacks and Effects",
        entries = {
            { key = "thrassian_stranglers", shortName = "TS", name = "Étrangleurs thrassiens", setIds = { 501 }, setNames = { "Étrangleurs thrassiens", "Thrassian Stranglers" }, equipPieces = 1, ids = { 136123 }, maxStacks = 50, color = { 0.38, 0.74, 0.28, 1 }, target = "Yourself" },
            { key = "harpooners_kilt", shortName = "HK", name = "Kilt de pataugeur de Harponneur", setIds = { 594 }, setNames = { "Kilt de pataugeur de Harponneur", "Harpooner's Wading Kilt" }, equipPieces = 1, ids = { 155150 }, maxStacks = 10, color = { 0.24, 0.72, 0.92, 1 }, target = "Yourself" },
            { key = "death_dealers_fete", shortName = "DF", name = "Fête du marchand de mort", setIds = { 596 }, setNames = { "Fête du marchand de mort", "Death Dealer's Fete" }, equipPieces = 1, ids = { 155176 }, maxStacks = 30, color = { 0.82, 0.24, 0.34, 1 }, target = "Yourself" },
            { key = "bloodlords_embrace", shortName = "BE", name = "Étreinte du seigneur de sang", setIds = { 521 }, equipPieces = 1, ids = { 139903 }, color = { 0.72, 0.12, 0.18, 1 }, target = "Current Target" },
            { key = "sea_serpents_coil", shortName = "SC", name = "Spire du serpent de mer", setIds = { 657 }, equipPieces = 1, ids = { 172865 }, cooldown = 10, color = { 0.22, 0.68, 0.78, 1 }, target = "Yourself" },
        },
    },
    {
        key = "trial_proc_sets", name = "Sets d'épreuve à proc", nameEn = "Trial Proc Sets",
        entries = {
            { key = "roaring_opportunist", shortName = "RO", name = "Opportuniste rugissant", setIds = { 496, 497 }, ids = { 135923, 135924, 137985 }, cooldown = 22, color = { 0.08, 0.62, 0.20, 1 }, target = "Yourself" },
            { key = "whorl_depths", shortName = "WD", name = "Tourbillon des profondeurs", setIds = { 646, 653 }, ids = { 172671 }, cooldown = 18, color = { 0.18, 0.58, 0.92, 1 }, target = "Current Target" },
            { key = "pillagers_profit", shortName = "PP", name = "Profit du pillard", setIds = { 649, 650 }, ids = { 172055, 172056 }, cooldown = 45, color = { 0.30, 0.70, 0.96, 1 }, target = "Yourself" },
            { key = "force_overflow", shortName = "FO", name = "Débordement de force", setIds = { 562, 568 }, equipPieces = 2, ids = { 147875 }, cooldown = 10, color = { 0.78, 0.42, 0.90, 1 }, target = "Yourself" },
            { key = "elemental_wrath", shortName = "EW", name = "Courroux élémentaire", setIds = { 561, 567 }, equipPieces = 2, ids = { 147843 }, cooldown = 10, color = { 0.92, 0.36, 0.14, 1 }, target = "Current Target" },
            { key = "void_bash", shortName = "VB", name = "Coup du néant", setIds = { 558, 564 }, equipPieces = 2, ids = { 147747 }, cooldown = 13, color = { 0.42, 0.22, 0.76, 1 }, target = "Current Target" },
            { key = "destructive_impact", shortName = "DIm", name = "Impact destructeur", setIds = { 317, 532 }, equipPieces = 2, ids = { 140334 }, color = { 0.86, 0.32, 0.12, 1 }, target = "Current Target" },
        },
    },
}

local CLASS_MASTERY_NAMES = {
    [263316] = { fr = "Émergence abyssale", en = "Abyssal Emergence" },
    [263398] = { fr = "Destin réaligné", en = "Fate Realigned" },
    [263410] = { fr = "Potentiel délié", en = "Unbound Potential" },
    [263412] = { fr = "Rigueur d'érudit", en = "Erudite's Rigor" },
    [263416] = { fr = "Verve de scribe", en = "Ink-Scribe's Verve" },
    [238232] = { fr = "Descente inexorable", en = "Inexorable Descent" },
    [240268] = { fr = "Voix tonitruante", en = "Booming Voice" },
    [259224] = { fr = "Braises de feu de brousse", en = "Wildfire Embers" },
    [263220] = { fr = "Défense déterminée", en = "Resolute Defense" },
    [263247] = { fr = "Diriger depuis le front", en = "Lead from the Front" },
    [263448] = { fr = "Sans gaspillage", en = "Nothing Wasted" },
    [263465] = { fr = "Promesse malveillante", en = "Malevolent Promise" },
    [263509] = { fr = "Cycle sans fin", en = "Cycle Unending" },
    [263549] = { fr = "Livre de chair", en = "Pound of Flesh" },
    [263554] = { fr = "Renoncement au voile", en = "Veil's Forfeit" },
    [263519] = { fr = "Gueule de la toundra", en = "Tundra's Maw" },
    [263520] = { fr = "Adaptation sauvage", en = "Wild Adaptation" },
    [263521] = { fr = "Obstination glaciale", en = "Glacial Obstinance" },
    [263522] = { fr = "Peau de défense du Vert", en = "Green-Keeper's Hide" },
    [263523] = { fr = "Moisson généreuse", en = "Bountiful Harvest" },
    [263585] = { fr = "Bastion de lumière", en = "Bastion of Light" },
    [263586] = { fr = "Protection dévouée", en = "Devout Guardian" },
    [263587] = { fr = "Héraut lumineux", en = "Bright Harbinger" },
    [263588] = { fr = "Marque du jugement", en = "Judgment's Brand" },
    [263589] = { fr = "Incandescence résolue", en = "Steadfast Candescence" },
    [263603] = { fr = "Inspiration nocturne", en = "Nocturnal Inspiration" },
    [263604] = { fr = "Sens de l'exploitation", en = "An Eye for Exploitation" },
    [263605] = { fr = "Au-dessus et au-delà", en = "Above and Beyond" },
    [263606] = { fr = "Concentration du coupe-gorge", en = "Cutthroat's Focus" },
    [263607] = { fr = "Partager les trésors", en = "Share the Spoils" },
    [263870] = { fr = "Conservation d'énergie", en = "Conservation of Energy" },
    [263871] = { fr = "Fontaine de puissance", en = "Font of Power" },
    [263872] = { fr = "Réverbération statique", en = "Static Reverberation" },
    [263873] = { fr = "Défense calculée", en = "Calculated Defense" },
    [263874] = { fr = "Sphère d'influence", en = "Sphere of Influence" },
}

-- Les maîtrises sont des passifs achetés dans une ligne de compétences, pas des
-- auras temporaires. Ces métadonnées permettent au moteur de lire leur état
-- directement avec GetSkillAbilityInfo.
local CLASS_MASTERY_SKILLS = {
    [238232] = { classId = 1, skillLineId = 351, passiveIndex = 1 },
    [240268] = { classId = 1, skillLineId = 351, passiveIndex = 2 },
    [259224] = { classId = 1, skillLineId = 351, passiveIndex = 3 },
    [263220] = { classId = 1, skillLineId = 351, passiveIndex = 4 },
    [263247] = { classId = 1, skillLineId = 351, passiveIndex = 5 },
    [263870] = { classId = 2, skillLineId = 357, passiveIndex = 1 },
    [263871] = { classId = 2, skillLineId = 357, passiveIndex = 2 },
    [263872] = { classId = 2, skillLineId = 357, passiveIndex = 3 },
    [263873] = { classId = 2, skillLineId = 357, passiveIndex = 4 },
    [263874] = { classId = 2, skillLineId = 357, passiveIndex = 5 },
    [263603] = { classId = 3, skillLineId = 356, passiveIndex = 1 },
    [263604] = { classId = 3, skillLineId = 356, passiveIndex = 2 },
    [263605] = { classId = 3, skillLineId = 356, passiveIndex = 3 },
    [263606] = { classId = 3, skillLineId = 356, passiveIndex = 4 },
    [263607] = { classId = 3, skillLineId = 356, passiveIndex = 5 },
    [263519] = { classId = 4, skillLineId = 354, passiveIndex = 1 },
    [263520] = { classId = 4, skillLineId = 354, passiveIndex = 2 },
    [263521] = { classId = 4, skillLineId = 354, passiveIndex = 3 },
    [263522] = { classId = 4, skillLineId = 354, passiveIndex = 4 },
    [263523] = { classId = 4, skillLineId = 354, passiveIndex = 5 },
    [263448] = { classId = 5, skillLineId = 353, passiveIndex = 1 },
    [263465] = { classId = 5, skillLineId = 353, passiveIndex = 2 },
    [263509] = { classId = 5, skillLineId = 353, passiveIndex = 3 },
    [263549] = { classId = 5, skillLineId = 353, passiveIndex = 4 },
    [263554] = { classId = 5, skillLineId = 353, passiveIndex = 5 },
    [263585] = { classId = 6, skillLineId = 355, passiveIndex = 1 },
    [263586] = { classId = 6, skillLineId = 355, passiveIndex = 2 },
    [263587] = { classId = 6, skillLineId = 355, passiveIndex = 3 },
    [263588] = { classId = 6, skillLineId = 355, passiveIndex = 4 },
    [263589] = { classId = 6, skillLineId = 355, passiveIndex = 5 },
    [263316] = { classId = 117, skillLineId = 352, passiveIndex = 1 },
    [263398] = { classId = 117, skillLineId = 352, passiveIndex = 2 },
    [263410] = { classId = 117, skillLineId = 352, passiveIndex = 3 },
    [263412] = { classId = 117, skillLineId = 352, passiveIndex = 4 },
    [263416] = { classId = 117, skillLineId = 352, passiveIndex = 5 },
}

-- normalisation -------------------------------------------------------
local function NormTarget(t)
    if t == "Current Target" then return "target" end
    return "player"
end

local function NormColor(c)
    c = c or {}
    return { r = c[1] or 1, g = c[2] or 1, b = c[3] or 1, a = c[4] or 1 }
end

local function CleanAbilityName(name)
    name = tostring(name or "")
    if name == "" then return "" end
    if zo_strformat then
        name = zo_strformat(SI_ABILITY_NAME, name)
    end
    return (name:gsub("%^.*", ""))
end

local function OfficialAbilityName(ids, fallback)
    if GetAbilityName then
        for _, abilityId in ipairs(ids or {}) do
            local name = CleanAbilityName(GetAbilityName(abilityId))
            if name ~= "" then return name end
        end
    end
    return fallback
end

local categories, seenKeys = {}, {}
for _, cat in ipairs(rawCategories) do
    local entries = {}
    for _, e in ipairs(cat.entries) do
        -- clé déjà prise ailleurs : on saute pour éviter d'écraser (ids partagés)
        if not seenKeys[e.key] then
            seenKeys[e.key] = true
            local localizedNames = CLASS_MASTERY_NAMES[e.ids and e.ids[1]]
            local mastery = CLASS_MASTERY_SKILLS[e.ids and e.ids[1]]
            entries[#entries + 1] = {
                key = e.key,
                shortName = e.shortName,
                name = OfficialAbilityName(e.ids, e.name),
                fallbackName = e.name,
                ids = e.procIds or e.ids,
                passiveAbilityId = mastery and e.ids and e.ids[1] or nil,
                procIds = e.procIds,
                procDuration = e.procDuration,
                procTargetType = e.procTarget,
                color = NormColor(e.color),
                icon = e.icon,
                targetType = NormTarget(e.target),
                maxStacks = e.maxStacks,
                cooldown = e.cooldown,
                cooldownColor = e.cooldownColor,
                setNames = e.setNames,
                setIds = e.setIds,
                equipPieces = e.equipPieces,
                nameFr = (localizedNames and localizedNames.fr) or e.nameFr or e.name,
                nameEn = (localizedNames and localizedNames.en) or e.nameEn,
                classMastery = mastery ~= nil,
                classId = mastery and mastery.classId,
                skillLineId = mastery and mastery.skillLineId,
                passiveIndex = mastery and mastery.passiveIndex,
                categoryKey = cat.key,
                categoryName = cat.name,
                defaultEnabled = CORE_CATEGORIES[cat.key] == true,
            }
        end
    end
    categories[#categories + 1] = { key = cat.key, name = cat.name, nameEn = cat.nameEn, entries = entries }
end

TSB.effectCatalog = { categories = categories }

function TSB.GetEffectCatalog()
    return TSB.effectCatalog
end

-- Listes à plat groupées par cible (consommées par MajorEffects)
function TSB.CaptureCatalogLanguageNames()
    if not TSB.savedVars then return end
    local lang = ""
    if GetCVar then
        lang = tostring(GetCVar("language.2") or GetCVar("Language.2") or "")
    end
    lang = lang:lower():sub(1, 2)
    if lang ~= "fr" and lang ~= "en" then return end
    TSB.savedVars.catalogNamesByLanguage = TSB.savedVars.catalogNamesByLanguage or {}
    local names = TSB.savedVars.catalogNamesByLanguage[lang] or {}
    TSB.savedVars.catalogNamesByLanguage[lang] = names
    for _, cat in ipairs(categories) do
        for _, e in ipairs(cat.entries) do
            local explicitName = lang == "fr" and e.nameFr or e.nameEn
            if explicitName and explicitName ~= "" then
                names[e.key] = explicitName
            elseif e.name and e.name ~= "" then
                names[e.key] = e.name
            end
        end
    end
end

function TSB.GetCatalogByTarget()
    local player, target = {}, {}
    for _, cat in ipairs(categories) do
        for _, e in ipairs(cat.entries) do
            if e.targetType == "player" then player[#player + 1] = e else target[#target + 1] = e end
        end
    end
    return player, target
end
