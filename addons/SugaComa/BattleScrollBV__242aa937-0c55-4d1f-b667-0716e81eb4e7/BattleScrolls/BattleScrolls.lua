-- Battle Scrolls - Build Viewer
-- Original by Semigroup1329 (Vladislav Sheludchenkov).
-- Lightweight fork by Tea & Toast Software (SugaComa).
-- Upstream: https://github.com/vladislavsheludchenkov/BattleScrolls
-- MIT license: see LICENSE.

BattleScrolls = BattleScrolls or {}
BattleScrolls.journal = { renderers = {} }

-- Build viewer translations
do
    ZO_CreateStringId("BATTLESCROLLS_UI_NAME", "Battle Scrolls")
    ZO_CreateStringId("BATTLESCROLLS_LIST_LOADING", "Loading")
    ZO_CreateStringId("BATTLESCROLLS_SETUP_FRONT_BAR", "Front Bar")
    ZO_CreateStringId("BATTLESCROLLS_SETUP_BACK_BAR", "Back Bar")
    ZO_CreateStringId("BATTLESCROLLS_SETUP_GEAR_SETS", "Gear Sets")
    ZO_CreateStringId("BATTLESCROLLS_SETUP_POISONS", "Poisons")
    ZO_CreateStringId("BATTLESCROLLS_SETUP_CHARACTER", "Character")
    ZO_CreateStringId("BATTLESCROLLS_SETUP_PERKS", "Perks")
    ZO_CreateStringId("BATTLESCROLLS_WEAPON_GREATSWORD", "Greatsword")
    ZO_CreateStringId("BATTLESCROLLS_WEAPON_BATTLE_AXE", "Battle Axe")
    ZO_CreateStringId("BATTLESCROLLS_WEAPON_MAUL", "Maul")
    ZO_CreateStringId("BATTLESCROLLS_FOOD_MAX_HEALTH", "Maximum Health")
    ZO_CreateStringId("BATTLESCROLLS_FOOD_MAX_MAGICKA", "Maximum Magicka")
    ZO_CreateStringId("BATTLESCROLLS_FOOD_MAX_STAMINA", "Maximum Stamina")
    ZO_CreateStringId("BATTLESCROLLS_FOOD_MAX_HEALTH_MAGICKA", "Maximum Health and Magicka")
    ZO_CreateStringId("BATTLESCROLLS_FOOD_MAX_HEALTH_STAMINA", "Maximum Health and Stamina")
    ZO_CreateStringId("BATTLESCROLLS_FOOD_MAX_MAGICKA_STAMINA", "Maximum Magicka and Stamina")
    ZO_CreateStringId("BATTLESCROLLS_FOOD_MAX_TRISTAT", "Maximum Health, Magicka, and Stamina")
    ZO_CreateStringId("BATTLESCROLLS_FOOD_HEALTH_RECOVERY", "Health Recovery")
    ZO_CreateStringId("BATTLESCROLLS_FOOD_MAGICKA_RECOVERY", "Magicka Recovery")
    ZO_CreateStringId("BATTLESCROLLS_FOOD_STAMINA_RECOVERY", "Stamina Recovery")
    ZO_CreateStringId("BATTLESCROLLS_FOOD_HEALTH_MAGICKA_RECOVERY", "Health and Magicka Recovery")
    ZO_CreateStringId("BATTLESCROLLS_FOOD_HEALTH_STAMINA_RECOVERY", "Health and Stamina Recovery")
    ZO_CreateStringId("BATTLESCROLLS_FOOD_MAGICKA_STAMINA_RECOVERY", "Magicka and Stamina Recovery")
    ZO_CreateStringId("BATTLESCROLLS_FOOD_RECOVERY_TRISTAT", "Health, Magicka, and Stamina Recovery")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT1", "Restore Health")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT2", "Ravage Health")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT3", "Restore Magicka")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT4", "Ravage Magicka")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT5", "Restore Stamina")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT6", "Ravage Stamina")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT7", "Increase Spell Resist")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT8", "Breach")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT9", "Increase Armor")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT10", "Fracture")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT11", "Increase Spell Power")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT12", "Cowardice")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT13", "Increase Weapon Power")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT14", "Maim")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT15", "Spell Critical")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT16", "Uncertainty")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT17", "Weapon Critical")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT18", "Enervation")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT19", "Unstoppable")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT20", "Entrapment")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT21", "Detection")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT22", "Invisible")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT23", "Speed")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT24", "Hindrance")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT25", "Protection")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT26", "Vulnerability")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT27", "Lingering Health")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT28", "Gradual Ravage Health")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT29", "Vitality")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT30", "Defile")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT31", "Heroism")
    ZO_CreateStringId("BATTLESCROLLS_ALCHEMY_TRAIT32", "Timidity")

    local language = GetCVar("language.2")
    if language == "de" then
        SafeAddString(BATTLESCROLLS_UI_NAME, "Battle Scrolls", 1)
        SafeAddString(BATTLESCROLLS_LIST_LOADING, "Wird geladen...", 1)
        SafeAddString(BATTLESCROLLS_SETUP_FRONT_BAR, "Primärleiste", 1)
        SafeAddString(BATTLESCROLLS_SETUP_BACK_BAR, "Reserveleiste", 1)
        SafeAddString(BATTLESCROLLS_SETUP_GEAR_SETS, "Ausrüstungssets", 1)
        SafeAddString(BATTLESCROLLS_SETUP_POISONS, "Gifte", 1)
        SafeAddString(BATTLESCROLLS_SETUP_CHARACTER, "Charakter", 1)
        SafeAddString(BATTLESCROLLS_SETUP_PERKS, "Signa", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_GREATSWORD, "Großschwert", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_BATTLE_AXE, "Streitaxt", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_MAUL, "Streitkolben", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH, "Maximale Gesundheit", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_MAGICKA, "Maximale Magicka", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_STAMINA, "Maximale Ausdauer", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH_MAGICKA, "Maximale Gesundheit und Magicka", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH_STAMINA, "Maximale Gesundheit und Ausdauer", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_MAGICKA_STAMINA, "Maximale Magicka und Ausdauer", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_TRISTAT, "Maximale Gesundheit, Magicka und Ausdauer", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_RECOVERY, "Gesundheitsregeneration", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAGICKA_RECOVERY, "Magickaregeneration", 1)
        SafeAddString(BATTLESCROLLS_FOOD_STAMINA_RECOVERY, "Ausdauerregeneration", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_MAGICKA_RECOVERY, "Gesundheits- und Magickaregeneration", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_STAMINA_RECOVERY, "Gesundheits- und Ausdauerregeneration", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAGICKA_STAMINA_RECOVERY, "Magicka- und Ausdauerregeneration", 1)
        SafeAddString(BATTLESCROLLS_FOOD_RECOVERY_TRISTAT, "Gesundheits-, Magicka- und Ausdauerregeneration", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT1, "Leben wiederherstellen", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT2, "Lebensverwüstung", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT3, "Magicka wiederherstellen", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT4, "Magickaverwüstung", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT5, "Ausdauer wiederherstellen", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT6, "Ausdauerverwüstung", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT7, "Erhöht Magieresistenz", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT8, "Bruch", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT9, "Erhöht Rüstung", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT10, "Fraktur", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT11, "Erhöht Magiekraft", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT12, "Feigheit", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT13, "Erhöht Waffenkraft", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT14, "Versehren", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT15, "Kritische Magietreffer", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT16, "Ungewissheit", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT17, "Kritische Waffentreffer", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT18, "Schwäche", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT19, "Sicherer Stand", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT20, "Einfangen", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT21, "Detektion", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT22, "Unsichtbarkeit", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT23, "Tempo", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT24, "Einschränken", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT25, "Schutz", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT26, "Verwundbarkeit", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT27, "Beständige Heilung", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT28, "Langsame Lebensverwüstung", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT29, "Vitalität", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT30, "Schänden", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT31, "Heldentum", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT32, "Scheu", 1)
    elseif language == "es" then
        SafeAddString(BATTLESCROLLS_UI_NAME, "Pergaminos de Batalla", 1)
        SafeAddString(BATTLESCROLLS_LIST_LOADING, "Cargando", 1)
        SafeAddString(BATTLESCROLLS_SETUP_FRONT_BAR, "Barra primaria", 1)
        SafeAddString(BATTLESCROLLS_SETUP_BACK_BAR, "Barra secundaria", 1)
        SafeAddString(BATTLESCROLLS_SETUP_GEAR_SETS, "Conjuntos de equipo", 1)
        SafeAddString(BATTLESCROLLS_SETUP_POISONS, "Venenos", 1)
        SafeAddString(BATTLESCROLLS_SETUP_CHARACTER, "Personaje", 1)
        SafeAddString(BATTLESCROLLS_SETUP_PERKS, "Ventajas", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_GREATSWORD, "Mandoble", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_BATTLE_AXE, "Hacha de batalla", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_MAUL, "Maza", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH, "Salud máxima", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_MAGICKA, "Magia máxima", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_STAMINA, "Aguante máximo", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH_MAGICKA, "Salud y magia máximas", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH_STAMINA, "Salud y aguante máximos", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_MAGICKA_STAMINA, "Magia y aguante máximos", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_TRISTAT, "Salud, magia y aguante máximos", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_RECOVERY, "Recuperación de salud", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAGICKA_RECOVERY, "Recuperación de magia", 1)
        SafeAddString(BATTLESCROLLS_FOOD_STAMINA_RECOVERY, "Recuperación de aguante", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_MAGICKA_RECOVERY, "Recuperación de salud y magia", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_STAMINA_RECOVERY, "Recuperación de salud y aguante", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAGICKA_STAMINA_RECOVERY, "Recuperación de magia y aguante", 1)
        SafeAddString(BATTLESCROLLS_FOOD_RECOVERY_TRISTAT, "Recuperación de salud, magia y aguante", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT1, "Restauración de salud", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT2, "Reducción de salud", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT3, "Restauración de magia", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT4, "Reducción de magia", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT5, "Restauración de aguante", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT6, "Reducción de aguante", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT7, "Aumento de resistencia mágica", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT8, "Fisura", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT9, "Aumento de armadura", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT10, "Fractura", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT11, "Aumento de poder mágico", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT12, "Cobardía", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT13, "Aumento del poder físico", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT14, "Mutilación", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT15, "Crítico mágico", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT16, "Incertidumbre", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT17, "Crítico físico", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT18, "Debilitación", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT19, "Imparable", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT20, "Captura", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT21, "Detección", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT22, "Invisible", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT23, "Velocidad", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT24, "Impedimento", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT25, "Protección", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT26, "Vulnerabilidad", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT27, "Salud prolongada", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT28, "Reducción de salud insidiosa", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT29, "Vitalidad", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT30, "Profanación", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT31, "Heroísmo", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT32, "Timidez", 1)
    elseif language == "fr" then
        SafeAddString(BATTLESCROLLS_UI_NAME, "Parchemins de Bataille", 1)
        SafeAddString(BATTLESCROLLS_LIST_LOADING, "Chargement", 1)
        SafeAddString(BATTLESCROLLS_SETUP_FRONT_BAR, "Barre primaire", 1)
        SafeAddString(BATTLESCROLLS_SETUP_BACK_BAR, "Barre secondaire", 1)
        SafeAddString(BATTLESCROLLS_SETUP_GEAR_SETS, "Ensembles d'équipement", 1)
        SafeAddString(BATTLESCROLLS_SETUP_POISONS, "Poisons", 1)
        SafeAddString(BATTLESCROLLS_SETUP_CHARACTER, "Personnage", 1)
        SafeAddString(BATTLESCROLLS_SETUP_PERKS, "Atouts", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_GREATSWORD, "Espadon", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_BATTLE_AXE, "Hache de guerre", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_MAUL, "Masse", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH, "Santé maximale", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_MAGICKA, "Magie maximale", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_STAMINA, "Endurance maximale", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH_MAGICKA, "Santé et magie maximales", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH_STAMINA, "Santé et endurance maximales", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_MAGICKA_STAMINA, "Magie et endurance maximales", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_TRISTAT, "Santé, magie et endurance maximales", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_RECOVERY, "Récupération de santé", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAGICKA_RECOVERY, "Récupération de magie", 1)
        SafeAddString(BATTLESCROLLS_FOOD_STAMINA_RECOVERY, "Récupération d'endurance", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_MAGICKA_RECOVERY, "Récupération de santé et de magie", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_STAMINA_RECOVERY, "Récupération de santé et d'endurance", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAGICKA_STAMINA_RECOVERY, "Récupération de magie et d'endurance", 1)
        SafeAddString(BATTLESCROLLS_FOOD_RECOVERY_TRISTAT, "Récupération de santé, de magie et d'endurance", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT1, "Rend de la Santé", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT2, "Réduit la Santé", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT3, "Rend de la Magie", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT4, "Réduit la Magie", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT5, "Rend de la Vigueur", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT6, "Ravage de Vigueur", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT7, "Augmente la résistance aux sorts", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT8, "Brèche", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT9, "Augmente l'armure", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT10, "Fracture", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT11, "Augmente la puissance des sorts", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT12, "Couardise", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT13, "Augmente la puissance de l'arme", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT14, "Mutilation", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT15, "Critique de sorts", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT16, "Incertitude", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT17, "Critique d'armes", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT18, "Affaiblissement", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT19, "Implacable", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT20, "Capture", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT21, "Détection", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT22, "Invisible", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT23, "Vitesse", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT24, "Entrave", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT25, "Protection", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT26, "Vulnérabilité", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT27, "Santé persistante", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT28, "Ravage de Santé graduel", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT29, "Vitalité", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT30, "Profanation", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT31, "Héroïsme", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT32, "Timidité", 1)
    elseif language == "jp" then
        SafeAddString(BATTLESCROLLS_UI_NAME, "Battle Scrolls", 1)
        SafeAddString(BATTLESCROLLS_LIST_LOADING, "読み込み中", 1)
        SafeAddString(BATTLESCROLLS_SETUP_FRONT_BAR, "主要バー", 1)
        SafeAddString(BATTLESCROLLS_SETUP_BACK_BAR, "予備バー", 1)
        SafeAddString(BATTLESCROLLS_SETUP_GEAR_SETS, "装備セット", 1)
        SafeAddString(BATTLESCROLLS_SETUP_POISONS, "毒", 1)
        SafeAddString(BATTLESCROLLS_SETUP_CHARACTER, "キャラクター", 1)
        SafeAddString(BATTLESCROLLS_SETUP_PERKS, "スキル", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_GREATSWORD, "両手剣", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_BATTLE_AXE, "両手斧", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_MAUL, "両手槌", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH, "最大体力", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_MAGICKA, "最大マジカ", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_STAMINA, "最大スタミナ", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH_MAGICKA, "最大体力・マジカ", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH_STAMINA, "最大体力・スタミナ", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_MAGICKA_STAMINA, "最大マジカ・スタミナ", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_TRISTAT, "最大体力・マジカ・スタミナ", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_RECOVERY, "体力回復", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAGICKA_RECOVERY, "マジカ回復", 1)
        SafeAddString(BATTLESCROLLS_FOOD_STAMINA_RECOVERY, "スタミナ回復", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_MAGICKA_RECOVERY, "体力・マジカ回復", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_STAMINA_RECOVERY, "体力・スタミナ回復", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAGICKA_STAMINA_RECOVERY, "マジカ・スタミナ回復", 1)
        SafeAddString(BATTLESCROLLS_FOOD_RECOVERY_TRISTAT, "体力・マジカ・スタミナ回復", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT1, "体力回復", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT2, "体力減少", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT3, "マジカ回復", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT4, "マジカ減少", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT5, "スタミナ回復", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT6, "スタミナ減少", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT7, "呪文耐性増大", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT8, "侵害", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT9, "防御力増大", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT10, "破砕", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT11, "呪文攻撃力上昇", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT12, "臆病", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT13, "武器攻撃力上昇", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT14, "不自由", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT15, "呪文クリティカル", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT16, "不信", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT17, "武器クリティカル", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT18, "弱体化", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT19, "猪突猛進", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT20, "罠", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT21, "探知", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT22, "透明化", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT23, "加速", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT24, "妨害", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT25, "防護", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT26, "脆弱", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT27, "体力継続", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT28, "体力漸減", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT29, "生命力", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT30, "汚染", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT31, "Heroism", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT32, "Timidity", 1)
    elseif language == "ru" then
        SafeAddString(BATTLESCROLLS_UI_NAME, "Боевые Свитки", 1)
        SafeAddString(BATTLESCROLLS_LIST_LOADING, "Загрузка", 1)
        SafeAddString(BATTLESCROLLS_SETUP_FRONT_BAR, "Основная панель", 1)
        SafeAddString(BATTLESCROLLS_SETUP_BACK_BAR, "Вторая панель", 1)
        SafeAddString(BATTLESCROLLS_SETUP_GEAR_SETS, "Наборы снаряжения", 1)
        SafeAddString(BATTLESCROLLS_SETUP_POISONS, "Яды", 1)
        SafeAddString(BATTLESCROLLS_SETUP_CHARACTER, "Персонаж", 1)
        SafeAddString(BATTLESCROLLS_SETUP_PERKS, "Умения", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_GREATSWORD, "Двуручный меч", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_BATTLE_AXE, "Секира", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_MAUL, "Палица", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH, "Максимальное здоровье", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_MAGICKA, "Максимальная магия", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_STAMINA, "Максимальный запас сил", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH_MAGICKA, "Максимальные здоровье и магия", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH_STAMINA, "Максимальные здоровье и запас сил", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_MAGICKA_STAMINA, "Максимальные магия и запас сил", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_TRISTAT, "Максимальные здоровье, магия и запас сил", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_RECOVERY, "Восстановление здоровья", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAGICKA_RECOVERY, "Восстановление магии", 1)
        SafeAddString(BATTLESCROLLS_FOOD_STAMINA_RECOVERY, "Восстановление запаса сил", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_MAGICKA_RECOVERY, "Восстановление здоровья и магии", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_STAMINA_RECOVERY, "Восстановление здоровья и запаса сил", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAGICKA_STAMINA_RECOVERY, "Восстановление магии и запаса сил", 1)
        SafeAddString(BATTLESCROLLS_FOOD_RECOVERY_TRISTAT, "Восстановление здоровья, магии и запаса сил", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT1, "Восстановление здоровья", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT2, "Опустошение здоровья", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT3, "Восстановление магии", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT4, "Опустошение магии", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT5, "Восстановление запаса сил", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT6, "Опустошение запаса сил", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT7, "Увеличение магической сопротивляемости", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT8, "Прорыв", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT9, "Увеличение показателя брони", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT10, "Перелом", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT11, "Увеличение силы заклинаний", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT12, "Трусость", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT13, "Увеличение силы оружия", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT14, "Травма", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT15, "Крит. рейтинг заклинаний", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT16, "Неуверенность", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT17, "Крит. рейтинг оружия", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT18, "Бессилие", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT19, "Неудержимость", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT20, "Захват", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT21, "Обнаружение", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT22, "Невидимость", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT23, "Скорость", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT24, "Замедление", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT25, "Защита", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT26, "Уязвимость", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT27, "Длительное исцеление", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT28, "Постепенное опустошение здоровья", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT29, "Живучесть", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT30, "Осквернение", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT31, "Героизм", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT32, "Трусливость", 1)
    elseif language == "zh" then
        SafeAddString(BATTLESCROLLS_UI_NAME, "Battle Scrolls", 1)
        SafeAddString(BATTLESCROLLS_LIST_LOADING, "加载中", 1)
        SafeAddString(BATTLESCROLLS_SETUP_FRONT_BAR, "主要栏", 1)
        SafeAddString(BATTLESCROLLS_SETUP_BACK_BAR, "后备栏", 1)
        SafeAddString(BATTLESCROLLS_SETUP_GEAR_SETS, "套装", 1)
        SafeAddString(BATTLESCROLLS_SETUP_POISONS, "毒药", 1)
        SafeAddString(BATTLESCROLLS_SETUP_CHARACTER, "角色", 1)
        SafeAddString(BATTLESCROLLS_SETUP_PERKS, "辅助能力", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_GREATSWORD, "巨剑", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_BATTLE_AXE, "战斧", 1)
        SafeAddString(BATTLESCROLLS_WEAPON_MAUL, "重锤", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH, "最大生命值", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_MAGICKA, "最大魔力", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_STAMINA, "最大耐力", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH_MAGICKA, "最大生命值和魔力", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_HEALTH_STAMINA, "最大生命值和耐力", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_MAGICKA_STAMINA, "最大魔力和耐力", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAX_TRISTAT, "最大生命值、魔力和耐力", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_RECOVERY, "生命恢复", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAGICKA_RECOVERY, "魔力恢复", 1)
        SafeAddString(BATTLESCROLLS_FOOD_STAMINA_RECOVERY, "耐力恢复", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_MAGICKA_RECOVERY, "生命和魔力恢复", 1)
        SafeAddString(BATTLESCROLLS_FOOD_HEALTH_STAMINA_RECOVERY, "生命和耐力恢复", 1)
        SafeAddString(BATTLESCROLLS_FOOD_MAGICKA_STAMINA_RECOVERY, "魔力和耐力恢复", 1)
        SafeAddString(BATTLESCROLLS_FOOD_RECOVERY_TRISTAT, "生命、魔力和耐力恢复", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT1, "生命恢复", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT2, "生命流失", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT3, "魔法恢复", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT4, "魔法流失", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT5, "耐力恢复", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT6, "耐力流失", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT7, "增加法术抗性", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT8, "侵害", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT9, "增加护甲", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT10, "破碎", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT11, "增加法术伤害", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT12, "胆怯", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT13, "增加武器伤害", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT14, "不自由", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT15, "增加法术暴击", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT16, "不确定", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT17, "增加物理暴击", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT18, "弱体化", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT19, "势不可挡", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT20, "诱捕", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT21, "探知", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT22, "隐身", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT23, "增加速度", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT24, "妨害", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT25, "保护", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT26, "脆弱", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT27, "持续生命伤害", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT28, "持续生命流失", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT29, "生命力", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT30, "污染", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT31, "Heroism", 1)
        SafeAddString(BATTLESCROLLS_ALCHEMY_TRAIT32, "Timidity", 1)
    end
end

-- Build data
do
    local constants = {}
    BattleScrolls.constants = constants

    constants.VENGEANCE_LOADOUTS_BY_SKILL_LINE_ID = {
        [339] = { skillLineId = 339, icon = "EsoUI/Art/Icons/Vengeance/loadout_soldier.dds" },
        [340] = { skillLineId = 340, icon = "EsoUI/Art/Icons/Vengeance/loadout_vanguard.dds" },
        [341] = { skillLineId = 341, icon = "EsoUI/Art/Icons/Vengeance/loadout_battlemedic.dds" },
        [342] = { skillLineId = 342, icon = "EsoUI/Art/Icons/Vengeance/loadout_scout.dds" },
    }

    constants.VENGEANCE_PERK_SLOTS = {
        VENGEANCE_PERK_SLOT_RED,
        VENGEANCE_PERK_SLOT_YELLOW,
        VENGEANCE_PERK_SLOT_BLUE,
    }

    constants.raceIcons = {
        [1]  = "EsoUI/Art/CharacterCreate/Gamepad/CharacterCreate_bretonIcon_down.dds",
        [2]  = "EsoUI/Art/CharacterCreate/Gamepad/CharacterCreate_redguardIcon_down.dds",
        [3]  = "EsoUI/Art/CharacterCreate/Gamepad/CharacterCreate_orcIcon_down.dds",
        [4]  = "EsoUI/Art/CharacterCreate/Gamepad/CharacterCreate_dunmerIcon_down.dds",
        [5]  = "EsoUI/Art/CharacterCreate/Gamepad/CharacterCreate_nordIcon_down.dds",
        [6]  = "EsoUI/Art/CharacterCreate/Gamepad/CharacterCreate_argonianIcon_down.dds",
        [7]  = "EsoUI/Art/CharacterCreate/Gamepad/CharacterCreate_altmerIcon_down.dds",
        [8]  = "EsoUI/Art/CharacterCreate/Gamepad/CharacterCreate_bosmerIcon_down.dds",
        [9]  = "EsoUI/Art/CharacterCreate/Gamepad/CharacterCreate_khajiitIcon_down.dds",
        [10] = "EsoUI/Art/CharacterCreate/Gamepad/CharacterCreate_imperialIcon_down.dds",
    }

    constants.FOOD_COMBO_STRINGS = {
        ["1"] = BATTLESCROLLS_FOOD_MAX_HEALTH,
        ["2"] = BATTLESCROLLS_FOOD_MAX_MAGICKA,
        ["3"] = BATTLESCROLLS_FOOD_MAX_STAMINA,
        ["1,2"] = BATTLESCROLLS_FOOD_MAX_HEALTH_MAGICKA,
        ["1,3"] = BATTLESCROLLS_FOOD_MAX_HEALTH_STAMINA,
        ["2,3"] = BATTLESCROLLS_FOOD_MAX_MAGICKA_STAMINA,
        ["1,2,3"] = BATTLESCROLLS_FOOD_MAX_TRISTAT,
        ["4"] = BATTLESCROLLS_FOOD_HEALTH_RECOVERY,
        ["5"] = BATTLESCROLLS_FOOD_MAGICKA_RECOVERY,
        ["6"] = BATTLESCROLLS_FOOD_STAMINA_RECOVERY,
        ["4,5"] = BATTLESCROLLS_FOOD_HEALTH_MAGICKA_RECOVERY,
        ["4,6"] = BATTLESCROLLS_FOOD_HEALTH_STAMINA_RECOVERY,
        ["5,6"] = BATTLESCROLLS_FOOD_MAGICKA_STAMINA_RECOVERY,
        ["4,5,6"] = BATTLESCROLLS_FOOD_RECOVERY_TRISTAT,
    }

    constants.foodAbilityInfo = {
        -- Generic foods (shared ability across many items)
        [61218] = { 1, 2, 3 }, -- Max Health, Max Magicka, Max Stamina
        [61255] = { 1, 3 }, -- Max Health, Max Stamina
        [61257] = { 1, 2 }, -- Max Health, Max Magicka
        [61259] = { 1 }, -- Max Health
        [61260] = { 2 }, -- Max Magicka
        [61261] = { 3 }, -- Max Stamina
        [61294] = { 2, 3 }, -- Max Magicka, Max Stamina
        [61322] = { 4 }, -- Health Recovery
        [61325] = { 5 }, -- Magicka Recovery
        [61328] = { 6 }, -- Stamina Recovery
        [61335] = { 4, 5 }, -- Health Recovery, Magicka Recovery
        [61340] = { 4, 6 }, -- Health Recovery, Stamina Recovery
        [61345] = { 5, 6 }, -- Magicka Recovery, Stamina Recovery
        [61350] = { 4, 5, 6 }, -- Health Recovery, Magicka Recovery, Stamina Recovery
        [66551] = { 1 }, -- Max Health (scaling)
        [66568] = { 2 }, -- Max Magicka (scaling)
        [66576] = { 3 }, -- Max Stamina (scaling)
        [66586] = { 4 }, -- Health Recovery (scaling)
        [66590] = { 5 }, -- Magicka Recovery (scaling)
        [66594] = { 6 }, -- Stamina Recovery (scaling)
        [84678] = { 2 }, -- Max Magicka (event food)
        -- Unique foods (single item per ability)
        [68411] = 64711, -- Crown Fortifying Meal
        [68416] = 64712, -- Crown Refreshing Drink
        [72816] = 71056, -- Orzorga's Red Frothgar
        [72819] = 71057, -- Orzorga's Tripe Trifle Pocket
        [72822] = 71058, -- Orzorga's Blood Price Pie
        [72824] = 71059, -- Orzorga's Smoked Bear Haunch
        [72956] = 71074, -- Cyrodilic Field Tack
        [72959] = 71075, -- Cyrodilic Field Treat
        [72961] = 71076, -- Cyrodilic Field Bar
        [72965] = 71077, -- Cyrodilic Field Brew
        [72968] = 71078, -- Cyrodilic Field Tea
        [72971] = 71079, -- Cyrodilic Field Tonic
        [84681] = 87686, -- Crisp and Crunchy Pumpkin Snack Skewer
        [84700] = 87687, -- Bowl of "Peeled Eyeballs"
        [84704] = 87690, -- Witchmother's Party Punch
        [84709] = 87691, -- Crunchy Spider Skewer
        [84720] = 87695, -- Ghastly Eye Bowl
        [84725] = 87696, -- Frosted Brains
        [84731] = 87697, -- Witchmother's Potent Brew
        [84735] = 87699, -- Purifying Bloody Mara
        [85484] = 94437, -- Crown Crate Fortifying Meal
        [85497] = 94438, -- Crown Crate Refreshing Drink
        [86559] = 101879, -- Hissmir Fish-Eye Rye
        [86673] = 112425, -- Lava Foot Soup-and-Saltrice
        [86677] = 112426, -- Bergama Warning Fire
        [86746] = 112433, -- Betnikh Twice-Spiked Ale
        [86749] = 112434, -- Jagga-Drenched "Mud Ball"
        [86787] = 112438, -- Rajhin's Sugar Claws
        [86789] = 112439, -- Alcaire Festival Sword-Pie
        [86791] = 112440, -- Snow Bear Glow-Wine
        [89955] = 120762, -- Candied Jester's Coins
        [89957] = 120763, -- Dubious Camoran Throne
        [89971] = 120764, -- Jewels of Misrule
        [92433] = 124677, -- Crown Stout Magic Liqueur
        [92435] = 124675, -- Crown Combat Mystic's Stew
        [92474] = 124676, -- Crown Vigorous Ragout
        [92476] = 124678, -- Crown Vigorous Tincture
        [100488] = 133555, -- Spring-Loaded Infusion
        [100498] = 133556, -- Clockwork Citrus Filet
        [100502] = 133554, -- Deregulated Mushroom Stew
        [107748] = 139016, -- Artaeum Pickled Fish Bowl
        [107789] = 139018, -- Artaeum Takeaway Broth
        [127531] = 153625, -- Corrupting Bloody Mara
        [127572] = 153627, -- Pack Leader's Bone Broth
        [127596] = 153629, -- Bewitched Sugar Skulls
        [148633] = 171322, -- Sparkling Mudcrab Apple Cider
        [245302] = 120436, -- Princess's Delight
    }
end

-- Live build capture
do
    ---@class PlayerSetupAbility
    ---@field abilityId number           -- Resolved ability ID (for name/icon). 0 = empty slot.
    ---@field craftedAbilityId number|nil -- Non-nil if crafted (scribing). Base crafted ability ID.
    ---@field scriptIds number[]|nil      -- {primaryScriptId, secondaryScriptId, tertiaryScriptId}

    ---@class PlayerSetupAbilities
    ---@field front PlayerSetupAbility[] -- 6 entries
    ---@field back PlayerSetupAbility[]  -- 6 entries

    ---@class PlayerSetupChampionSkill
    ---@field skillId number
    ---@field disciplineId number

    ---@class PlayerSetupPoison
    ---@field itemLink string  -- Full item link

    ---@class PlayerSetupFood
    ---@field abilityId number -- Food buff ability ID

    ---@class PlayerSetup
    ---@field abilities PlayerSetupAbilities
    ---@field champion PlayerSetupChampionSkill[]
    ---@field equipSlots (string|false)[] -- Item link string or false for empty slot, 14 entries (no poison slots)
    ---@field frontBarDisabled boolean -- true when bar swap locked and front bar is inaccessible
    ---@field backBarDisabled boolean -- true when bar swap locked and back bar is inaccessible
    ---@field frontPoison PlayerSetupPoison|nil
    ---@field backPoison PlayerSetupPoison|nil
    ---@field raceId number
    ---@field classId number
    ---@field classSkillLineIds number[] -- 3 entries (one per class skill line)
    ---@field classMasteryAbilityIds number[]|nil -- Active Class Mastery passive ability IDs (nil when unavailable or none selected)
    ---@field mundusAbilityIds number[]|nil -- 0-2 mundus stone buff ability IDs
    ---@field foods PlayerSetupFood[]|nil -- Top 1-3 food buffs (nil if no food)
    ---@field werewolfAbilities PlayerSetupAbility[]|nil -- Werewolf bar (when available)
    ---@field werewolfTransformed boolean|nil -- true while transformed
    ---@field isVengeance boolean|nil -- true when captured in a Vengeance ruleset
    ---@field loadoutSkillLineId number|nil -- Vengeance loadout skill line ID
    ---@field vengeancePerkDefIds number[]|nil -- {red, yellow, blue} Vengeance perk def IDs; 0 = empty
    ---@field weaponTypes number[]|nil -- {frontMH, frontOH, backMH, backOH}; Vengeance stores weapon types only

    local FOOD_ABILITY_INFO = BattleScrolls.constants.foodAbilityInfo
    local VENGEANCE_LOADOUTS_BY_SKILL_LINE_ID = BattleScrolls.constants.VENGEANCE_LOADOUTS_BY_SKILL_LINE_ID
    local VENGEANCE_PERK_SLOTS = BattleScrolls.constants.VENGEANCE_PERK_SLOTS
    local VENGEANCE_PERK_SCAN_MAX_RANK = 100
    local VENGEANCE_PERK_EMPTY_RANK_RUN_LIMIT = 10

    -- Fixed slot order (no slot IDs stored, position is implicit)
    local EQUIP_SLOTS = {
        EQUIP_SLOT_HEAD,       -- 0
        EQUIP_SLOT_NECK,       -- 1
        EQUIP_SLOT_CHEST,      -- 2
        EQUIP_SLOT_SHOULDERS,  -- 3
        EQUIP_SLOT_MAIN_HAND,  -- 4
        EQUIP_SLOT_OFF_HAND,   -- 5
        EQUIP_SLOT_WAIST,      -- 6
        EQUIP_SLOT_HAND,       -- 16
        EQUIP_SLOT_LEGS,       -- 8
        EQUIP_SLOT_FEET,       -- 9
        EQUIP_SLOT_RING1,      -- 11
        EQUIP_SLOT_RING2,      -- 12
        EQUIP_SLOT_BACKUP_MAIN,-- 20
        EQUIP_SLOT_BACKUP_OFF, -- 21
    }

    ---Checks if the werewolf transformation ultimate is slotted on either weapon bar.
    ---Note: ESO's ACTION_BAR_ASSIGNMENT_MANAGER:IsWerewolfUltimateSlottedOnAnyWeaponBar()
    ---uses ACTION_BAR_ULTIMATE_SLOT_INDEX which points to the wrong slot, so we use
    ---GetAssignableAbilityBarStartAndEndSlots() to find the actual ultimate slot.
    ---@return boolean
    local function isWerewolfUltimateSlotted()
        local _, ultimateSlot = GetAssignableAbilityBarStartAndEndSlots()
        for _, cat in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
            local abilityId = GetSlotBoundId(ultimateSlot, cat)
            if abilityId and abilityId > 0 then
                local progressionData = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(abilityId)
                if progressionData then
                    if progressionData:GetSkillData():GetSkillLineData():IsWerewolf() then
                        return true
                    end
                end
            end
        end
        return false
    end

    ---Captures abilities from a single hotbar category.
    ---@param category HotBarCategory
    ---@return PlayerSetupAbility[]
    local function captureBar(category)
        local result = {}
        local startSlot, endSlot = GetAssignableAbilityBarStartAndEndSlots()
        local emptyEntry = { abilityId = 0 }
        for slot = startSlot, endSlot do
            local slotType = GetSlotType(slot, category)
            ---@type PlayerSetupAbility
            local entry

            if slotType == ACTION_TYPE_CRAFTED_ABILITY then
                local craftedAbilityId = GetSlotBoundId(slot, category)
                local abilityId = GetAbilityIdForCraftedAbilityId(craftedAbilityId)
                local primary, secondary, tertiary = GetCraftedAbilityActiveScriptIds(craftedAbilityId)
                entry = {
                    abilityId = abilityId,
                    craftedAbilityId = craftedAbilityId,
                    scriptIds = { primary, secondary, tertiary },
                }
            elseif slotType == ACTION_TYPE_ABILITY then
                entry = { abilityId = GetSlotBoundId(slot, category) }
            else
                entry = emptyEntry
            end

            result[#result + 1] = entry
        end
        return result
    end

    ---Captures abilities from front and back hotbars.
    ---@return PlayerSetupAbilities
    local function captureAbilities()
        return {
            front = captureBar(HOTBAR_CATEGORY_PRIMARY),
            back = captureBar(HOTBAR_CATEGORY_BACKUP),
        }
    end

    ---Captures werewolf bar abilities. Returns nil if all slots are empty.
    ---@return PlayerSetupAbility[]|nil
    local function captureWerewolfBar()
        local bar = captureBar(HOTBAR_CATEGORY_WEREWOLF)
        for _, ability in ipairs(bar) do
            if ability.abilityId ~= 0 then
                return bar
            end
        end
        return nil
    end

    ---Captures slotted champion stars
    ---@return PlayerSetupChampionSkill[]
    local function captureChampion()
        -- Build skillId → disciplineId lookup (no direct API exists)
        local skillToDiscipline = {}
        for disciplineIndex = 1, GetNumChampionDisciplines() do
            local disciplineId = GetChampionDisciplineId(disciplineIndex)
            for skillIndex = 1, GetNumChampionDisciplineSkills(disciplineIndex) do
                local skillId = GetChampionSkillId(disciplineIndex, skillIndex)
                skillToDiscipline[skillId] = disciplineId
            end
        end

        local result = {}
        local startSlot, endSlot = GetAssignableChampionBarStartAndEndSlots()
        for slot = startSlot, endSlot do
            local skillId = GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION)
            if skillId and skillId > 0 then
                result[#result + 1] = {
                    skillId = skillId,
                    disciplineId = skillToDiscipline[skillId] or 0,
                }
            end
        end
        return result
    end

    ---Captures poison from an equip slot
    ---@param equipSlot number EQUIP_SLOT_POISON or EQUIP_SLOT_BACKUP_POISON
    ---@return PlayerSetupPoison|nil
    local function capturePoison(equipSlot)
        local link = GetItemLink(BAG_WORN, equipSlot, LINK_STYLE_DEFAULT)
        if not link or link == "" then return nil end
        return { itemLink = link }
    end

    ---Captures equipment item links from fixed slots (excludes poisons).
    ---Slots 5-6 are front weapons (MAIN_HAND, OFF_HAND), slots 13-14 are back weapons (BACKUP_MAIN, BACKUP_OFF).
    ---@return (string|false)[]
    local function captureEquipSlots()
        local result = {}
        for i = 1, #EQUIP_SLOTS do
            local link = GetItemLink(BAG_WORN, EQUIP_SLOTS[i], LINK_STYLE_DEFAULT)
            result[i] = (link and link ~= "") and link or false
        end
        return result
    end

    ---@return (string|false)[]
    local function emptyEquipSlots()
        local result = {}
        for i = 1, #EQUIP_SLOTS do
            result[i] = false
        end
        return result
    end

    ---Captures only weapon type IDs from equipment slot links.
    ---@param equipSlots (string|false)[]
    ---@return number[] weaponTypes {frontMH, frontOH, backMH, backOH}
    local function captureWeaponTypes(equipSlots)
        local function weaponType(slotIndex)
            local link = equipSlots[slotIndex]
            if link then
                return GetItemLinkWeaponType(link) or 0
            end
            return 0
        end

        return {
            weaponType(5),
            weaponType(6),
            weaponType(13),
            weaponType(14),
        }
    end

    ---@return boolean
    local function isVengeanceRuleset()
        return type(IsCurrentCampaignVengeanceRuleset) == "function"
            and IsCurrentCampaignVengeanceRuleset() == true
    end

    ---@return number|nil skillLineId
    local function captureVengeanceLoadoutSkillLineId()
        for skillType = SKILL_TYPE_ITERATION_BEGIN, SKILL_TYPE_ITERATION_END do
            for skillLineIndex = 1, GetNumSkillLines(skillType) do
                local skillLineId = GetSkillLineId(skillType, skillLineIndex)
                local loadout = VENGEANCE_LOADOUTS_BY_SKILL_LINE_ID[skillLineId]
                if loadout then
                    local _, _, isActive = GetSkillLineDynamicInfo(skillType, skillLineIndex)
                    if isActive then
                        return skillLineId
                    end
                end
            end
        end

        return nil
    end

    ---@type table<string, number>|nil
    local vengeancePerkDefIdsByName = nil

    ---Builds a lookup from localized perk name to stable perk def ID.
    ---ESO exposes active perk indices for slots, but def IDs are only available from
    ---the Veterancy reward track.
    ---@return table<string, number>
    local function getVengeancePerkDefIdsByName()
        if vengeancePerkDefIdsByName then
            return vengeancePerkDefIdsByName
        end

        local requestParsed = _G["RequestParsedPerkAvailabilityForCurrentSeason"]
        if type(requestParsed) == "function" then
            requestParsed()
        end

        local getNumberOfPerksUnlocked = _G["GetNumberOfPerksUnlockedAtVeterancyRank"]
        local getPerkDefId = _G["GetPerkDefIdForPerkAtVeterancyRank"]
        local getPerkName = _G["GetVengeancePerkName"]
        local result = {}

        if type(getNumberOfPerksUnlocked) == "function"
            and type(getPerkDefId) == "function"
            and type(getPerkName) == "function" then
            local foundPerkRank = false
            local emptyRun = 0
            for rank = 1, VENGEANCE_PERK_SCAN_MAX_RANK do
                local numPerks = getNumberOfPerksUnlocked(rank) or 0
                if numPerks > 0 then
                    foundPerkRank = true
                    emptyRun = 0
                    for unlockIndex = 1, numPerks do
                        local defId = getPerkDefId(rank, unlockIndex)
                        if defId and defId > 0 then
                            local name = getPerkName(defId)
                            if name and name ~= "" then
                                result[name] = defId
                            end
                        end
                    end
                elseif foundPerkRank then
                    emptyRun = emptyRun + 1
                    if emptyRun >= VENGEANCE_PERK_EMPTY_RANK_RUN_LIMIT then
                        break
                    end
                end
            end
        end

        vengeancePerkDefIdsByName = result
        return result
    end

    ---Captures active Vengeance perks as stable def IDs in red/yellow/blue order.
    ---@return number[]|nil
    local function captureVengeancePerks()
        local getIndexInSlot = _G["GetIndexOfPerkInSlotForRole"]
        local getPerkNameAtIndex = _G["GetVengeancePerkNameAtIndex"]
        if type(getIndexInSlot) ~= "function" or type(getPerkNameAtIndex) ~= "function" then
            return nil
        end

        local defIdsByName = getVengeancePerkDefIdsByName()
        local result = { 0, 0, 0 }
        local hasPerk = false

        for i, slotFlag in ipairs(VENGEANCE_PERK_SLOTS) do
            local perkIndex = getIndexInSlot(slotFlag)
            if perkIndex and perkIndex > 0 and perkIndex <= MAX_PERKS_AVAILABLE_PER_LOADOUT then
                local name = getPerkNameAtIndex(perkIndex)
                local defId = name and defIdsByName[name] or nil
                if defId and defId > 0 then
                    result[i] = defId
                    hasPerk = true
                end
            end
        end

        return hasPerk and result or nil
    end

    ---Checks whether a class skill line is a Class Mastery line.
    ---@param skillLineId number
    ---@return boolean
    local function isClassMasterySkillLine(skillLineId)
        return type(IsClassMasterySkillLine) == "function" and IsClassMasterySkillLine(skillLineId) == true
    end

    ---Captures active class skill line IDs (up to 3, may include lines from other classes via subclassing)
    ---@return number[]
    local function captureClassSkillLines()
        local result = {}
        for skillLineIndex = 1, GetNumSkillLines(SKILL_TYPE_CLASS) do
            local skillLineId = GetSkillLineId(SKILL_TYPE_CLASS, skillLineIndex)
            local _, _, isActive = GetSkillLineDynamicInfo(SKILL_TYPE_CLASS, skillLineIndex)
            if isActive and not isClassMasterySkillLine(skillLineId) then
                result[#result + 1] = skillLineId
            end
        end
        return result
    end

    ---Captures active Class Mastery passive ability IDs for the player's class.
    ---Builds with no selected Class Mastery passives keep showing class skill lines.
    ---@return number[]|nil
    local function captureClassMasteryAbilities()
        if type(IsClassMasterySkillLine) ~= "function" then return nil end

        local playerClassId = GetUnitClassId("player")
        local result = {}
        for skillLineIndex = 1, GetNumSkillLines(SKILL_TYPE_CLASS) do
            local skillLineId = GetSkillLineId(SKILL_TYPE_CLASS, skillLineIndex)
            if isClassMasterySkillLine(skillLineId)
                and GetSkillLineClassId(SKILL_TYPE_CLASS, skillLineIndex) == playerClassId then
                for skillIndex = 1, GetNumSkillAbilities(SKILL_TYPE_CLASS, skillLineIndex) do
                    local _, _, _, isPassive, _, isPurchased = GetSkillAbilityInfo(SKILL_TYPE_CLASS, skillLineIndex, skillIndex)
                    if isPassive and isPurchased then
                        local abilityId = GetSkillAbilityId(SKILL_TYPE_CLASS, skillLineIndex, skillIndex, false)
                        if abilityId and abilityId > 0 then
                            result[#result + 1] = abilityId
                        end
                    end
                end
            end
        end

        return #result > 0 and result or nil
    end

    ---Scans active buffs for mundus stone ability IDs (0-2 results)
    ---@return number[]|nil
    local function captureMundus()
        local result = {}
        for i = 1, GetNumBuffs("player") do
            local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
            if GetAbilityMundusStoneType(abilityId) ~= 0 then
                result[#result + 1] = abilityId
            end
        end
        return #result > 0 and result or nil
    end

    ---Scans active buffs for food buff (fallback when effect tracking is off)
    ---@return PlayerSetupFood|nil
    local function captureFoodFromBuffs()
        for i = 1, GetNumBuffs("player") do
            local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
            if FOOD_ABILITY_INFO[abilityId] then
                return { abilityId = abilityId }
            end
        end
        return nil
    end

    ---@return PlayerSetup
    local function captureSetupSnapshot()
        local capturedEquipSlots = captureEquipSlots()
        local isVengeance = isVengeanceRuleset()

        local food = (not isVengeance) and captureFoodFromBuffs() or nil

        ---@type PlayerSetup
        local setup = {
            abilities = captureAbilities(),
            champion = isVengeance and {} or captureChampion(),
            equipSlots = isVengeance and emptyEquipSlots() or capturedEquipSlots,
            frontBarDisabled = false,
            backBarDisabled = false,
            frontPoison = (not isVengeance) and capturePoison(EQUIP_SLOT_POISON) or nil,
            backPoison = (not isVengeance) and capturePoison(EQUIP_SLOT_BACKUP_POISON) or nil,
            raceId = GetUnitRaceId("player"),
            classId = GetUnitClassId("player"),
            classSkillLineIds = isVengeance and {} or captureClassSkillLines(),
            classMasteryAbilityIds = (not isVengeance) and captureClassMasteryAbilities() or nil,
            mundusAbilityIds = (not isVengeance) and captureMundus() or nil,
            foods = food and { food } or nil,
            isVengeance = isVengeance or nil,
            loadoutSkillLineId = isVengeance and captureVengeanceLoadoutSkillLineId() or nil,
            vengeancePerkDefIds = isVengeance and captureVengeancePerks() or nil,
            weaponTypes = isVengeance and captureWeaponTypes(capturedEquipSlots) or nil,
        }

        return setup
    end

    local setupCapture = {}
    BattleScrolls.setupCapture = setupCapture

    local function wipeAbilities(abilities)
        local emptyEntry = { abilityId = 0 }
        for i = 1, #abilities do
            abilities[i] = emptyEntry
        end
    end

    function setupCapture:captureCurrentSetup()
        local setup = captureSetupSnapshot()

        -- Werewolf: show WW bar only if currently transformed or WW ult is slotted
        local werewolfBar = captureWerewolfBar()
        local isWerewolf = werewolfBar and IsPlayerInWerewolfForm()
        if isWerewolf then
            setup.werewolfAbilities = werewolfBar
            setup.werewolfTransformed = true
            wipeAbilities(setup.abilities.front)
            wipeAbilities(setup.abilities.back)
        elseif werewolfBar and isWerewolfUltimateSlotted() then
            setup.werewolfAbilities = werewolfBar
        end

        -- Bar swap lock (one-bar builds): disable the inactive bar
        -- Skip during werewolf — bar swap is locked as a side effect of transformation
        if not isWerewolf then
            local activeWeaponPair, barSwapLocked = GetActiveWeaponPairInfo()
            if barSwapLocked then
                if activeWeaponPair == ACTIVE_WEAPON_PAIR_MAIN then
                    setup.backBarDisabled = true
                    setup.backPoison = nil
                    wipeAbilities(setup.abilities.back)
                    setup.equipSlots[13] = false
                    setup.equipSlots[14] = false
                    if setup.weaponTypes then
                        setup.weaponTypes[3] = 0
                        setup.weaponTypes[4] = 0
                    end
                else
                    setup.frontBarDisabled = true
                    setup.frontPoison = nil
                    wipeAbilities(setup.abilities.front)
                    setup.equipSlots[5] = false
                    setup.equipSlots[6] = false
                    if setup.weaponTypes then
                        setup.weaponTypes[1] = 0
                        setup.weaponTypes[2] = 0
                    end
                end
            end
        end

        return setup
    end
end

-- Equipment analysis
do
    local setupAnalysis = {}
    BattleScrolls.setupAnalysis = setupAnalysis

    -- =============================================================================
    -- CONSTANTS
    -- =============================================================================

    -- 2H weapon types (count as 2 pieces for set bonuses, hide off-hand)
    setupAnalysis.TWO_HANDED_TYPES = {
        [WEAPONTYPE_TWO_HANDED_SWORD] = true,
        [WEAPONTYPE_TWO_HANDED_AXE] = true,
        [WEAPONTYPE_TWO_HANDED_HAMMER] = true,
        [WEAPONTYPE_FIRE_STAFF] = true,
        [WEAPONTYPE_FROST_STAFF] = true,
        [WEAPONTYPE_LIGHTNING_STAFF] = true,
        [WEAPONTYPE_HEALING_STAFF] = true,
        [WEAPONTYPE_BOW] = true,
    }

    -- Shared armor slot indices (for weight counting): HEAD(1), CHEST(3), SHOULDERS(4), WAIST(7), HAND(8), LEGS(9), FEET(10)
    setupAnalysis.ARMOR_SLOT_INDICES = { 1, 3, 4, 7, 8, 9, 10 }

    -- Slot classification for set piece counting
    -- Shared slots contribute to both bars, front/back weapons to their respective bar only
    setupAnalysis.SHARED_SLOT_INDICES = { 1, 2, 3, 4, 7, 8, 9, 10, 11, 12 }
    setupAnalysis.FRONT_WEAPON_INDICES = { 5, 6 }
    setupAnalysis.BACK_WEAPON_INDICES = { 13, 14 }

    -- Main hand slot indices (for 2H detection)
    setupAnalysis.FRONT_MAIN_HAND_INDEX = 5
    setupAnalysis.BACK_MAIN_HAND_INDEX = 13

    -- Slot classification for trait grouping by equipment category
    setupAnalysis.JEWELRY_SLOT_INDICES = { 2, 11, 12 }

    ---@type table<number, number|string>
    setupAnalysis.ENCHANT_OVERRIDES = {
        [179] = 37, -- Prismatic Recovery: broken category, force correct one
        [178] = "|H1:item:166046:370:50:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0:0:0|h|h", -- Prismatic Cost Reduction: no valid category, resolve via glyph link
    }

    -- Local aliases for performance
    local TWO_HANDED_TYPES = setupAnalysis.TWO_HANDED_TYPES
    local ARMOR_SLOT_INDICES = setupAnalysis.ARMOR_SLOT_INDICES
    local SHARED_SLOT_INDICES = setupAnalysis.SHARED_SLOT_INDICES
    local FRONT_WEAPON_INDICES = setupAnalysis.FRONT_WEAPON_INDICES
    local BACK_WEAPON_INDICES = setupAnalysis.BACK_WEAPON_INDICES
    local FRONT_MAIN_HAND_INDEX = setupAnalysis.FRONT_MAIN_HAND_INDEX
    local BACK_MAIN_HAND_INDEX = setupAnalysis.BACK_MAIN_HAND_INDEX
    local ENCHANT_OVERRIDES = setupAnalysis.ENCHANT_OVERRIDES

    -- =============================================================================
    -- HELPERS
    -- =============================================================================

    ---Extracts set ID from an item link, returns 0 if not a set item
    ---@param link string
    ---@return number setId
    local function getSetIdFromLink(link)
        local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(link, true)
        return (hasSet and setId > 0) and setId or 0
    end

    -- =============================================================================
    -- SET DATA
    -- =============================================================================

    ---@class SetBarData
    ---@field frontCount number Piece count on front bar
    ---@field backCount number Piece count on back bar
    ---@field perfectedFrontCount number Perfected piece count on front bar
    ---@field perfectedBackCount number Perfected piece count on back bar
    ---@field frontStep number Highest active bonus threshold for front bar
    ---@field backStep number Highest active bonus threshold for back bar
    ---@field perfectedActiveFront boolean Whether perfected bonus is active on front
    ---@field perfectedActiveBack boolean Whether perfected bonus is active on back
    ---@field perfectedSetId number|nil Raw perfected setId for bonus queries
    ---@field name string Set display name

    ---Computes per-set piece counts and active bonus data across both bars.
    ---Groups by unperfected setId; derives perfected status from raw setIds at display time.
    ---@param equipSlots (string|false)[]
    ---@return table<number, SetBarData> setData Keyed by unperfected setId
    function setupAnalysis.computeSetData(equipSlots)
        local setData = {}

        ---Adds piece contribution to a set for a given bar
        ---@param rawSetId number Raw setId from equipment (may be perfected)
        ---@param bar "front"|"back"
        ---@param count number Pieces to add (1 for normal, 2 for 2H)
        local function addPiece(rawSetId, bar, count)
            if rawSetId == 0 then return end
            local unperfectedId = GetItemSetUnperfectedSetId(rawSetId)
            local isPerfected = unperfectedId > 0
            local groupId = isPerfected and unperfectedId or rawSetId

            if not setData[groupId] then
                setData[groupId] = {
                    frontCount = 0,
                    backCount = 0,
                    perfectedFrontCount = 0,
                    perfectedBackCount = 0,
                    frontStep = 0,
                    backStep = 0,
                    perfectedActiveFront = false,
                    perfectedActiveBack = false,
                    perfectedSetId = nil,
                    name = zo_strformat("<<C:1>>", GetItemSetName(groupId)),
                }
            end
            local data = setData[groupId]
            if isPerfected then data.perfectedSetId = rawSetId end
            if bar == "front" then
                data.frontCount = data.frontCount + count
            else
                data.backCount = data.backCount + count
            end
            if isPerfected then
                if bar == "front" then
                    data.perfectedFrontCount = data.perfectedFrontCount + count
                else
                    data.perfectedBackCount = data.perfectedBackCount + count
                end
            end
        end

        -- Process shared slots (contribute to both bars)
        for _, slotIdx in ipairs(SHARED_SLOT_INDICES) do
            local link = equipSlots[slotIdx]
            if link then
                local setId = getSetIdFromLink(link)
                if setId > 0 then
                    addPiece(setId, "front", 1)
                    addPiece(setId, "back", 1)
                end
            end
        end

        -- Process front weapon slots
        for _, slotIdx in ipairs(FRONT_WEAPON_INDICES) do
            local link = equipSlots[slotIdx]
            if link then
                local setId = getSetIdFromLink(link)
                if setId > 0 then
                    local count = 1
                    if slotIdx == FRONT_MAIN_HAND_INDEX and TWO_HANDED_TYPES[GetItemLinkWeaponType(link)] then
                        count = 2
                    end
                    addPiece(setId, "front", count)
                end
            end
        end

        -- Process back weapon slots
        for _, slotIdx in ipairs(BACK_WEAPON_INDICES) do
            local link = equipSlots[slotIdx]
            if link then
                local setId = getSetIdFromLink(link)
                if setId > 0 then
                    local count = 1
                    if slotIdx == BACK_MAIN_HAND_INDEX and TWO_HANDED_TYPES[GetItemLinkWeaponType(link)] then
                        count = 2
                    end
                    addPiece(setId, "back", count)
                end
            end
        end

        -- Compute active bonus thresholds and perfected status per bar
        for groupId, data in pairs(setData) do
            local querySetId = data.perfectedSetId or groupId
            local _, _, numBonuses = GetItemSetInfo(querySetId)

            for i = 1, numBonuses do
                local numRequired, _, isPerfectedBonus = GetItemSetBonusInfo(querySetId, i)
                if not isPerfectedBonus then
                    if data.frontCount >= numRequired then
                        data.frontStep = math.max(data.frontStep, numRequired)
                    end
                    if data.backCount >= numRequired then
                        data.backStep = math.max(data.backStep, numRequired)
                    end
                else
                    if data.perfectedFrontCount >= numRequired then
                        data.perfectedActiveFront = true
                    end
                    if data.perfectedBackCount >= numRequired then
                        data.perfectedActiveBack = true
                    end
                end
            end
        end

        return setData
    end

    -- =============================================================================
    -- ARMOR WEIGHTS
    -- =============================================================================

    ---Counts armor types across armor slots
    ---@param equipSlots (string|false)[]
    ---@return number light, number medium, number heavy
    function setupAnalysis.countArmorWeights(equipSlots)
        local light, medium, heavy = 0, 0, 0
        for _, slotIdx in ipairs(ARMOR_SLOT_INDICES) do
            local link = equipSlots[slotIdx]
            if link then
                local armorType = GetItemLinkArmorType(link)
                if armorType == ARMORTYPE_LIGHT then
                    light = light + 1
                elseif armorType == ARMORTYPE_MEDIUM then
                    medium = medium + 1
                elseif armorType == ARMORTYPE_HEAVY then
                    heavy = heavy + 1
                end
            end
        end
        return light, medium, heavy
    end

    -- =============================================================================
    -- TRAITS
    -- =============================================================================

    ---Groups and formats traits from equipment slots
    ---@param equipSlots (string|false)[]
    ---@param slotIndices? number[] Specific slot indices to examine (defaults to all slots)
    ---@return string formatted Trait summary (e.g. "4x Divines, 2x Sturdy")
    function setupAnalysis.groupTraits(equipSlots, slotIndices)
        local traitCounts = {}
        local traitOrder = {}
        local indices = slotIndices or {}
        if not slotIndices then
            for i = 1, #equipSlots do
                table.insert(indices, i)
            end
        end
        for _, i in ipairs(indices) do
            local link = equipSlots[i]
            if link then
                local trait = GetItemLinkTraitType(link)
                if trait and trait > 0 then
                    if not traitCounts[trait] then
                        traitCounts[trait] = 0
                        table.insert(traitOrder, trait)
                    end
                    traitCounts[trait] = traitCounts[trait] + 1
                end
            end
        end

        local details = {}
        for _, trait in ipairs(traitOrder) do
            local name = zo_strformat("<<1>>", GetString("SI_ITEMTRAITTYPE", trait))
            table.insert(details, { trait = trait, count = traitCounts[trait], name = name })
        end
        table.sort(details, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.name < b.name
        end)

        local parts = {}
        for _, detail in ipairs(details) do
            table.insert(parts, string.format("%dx %s", detail.count, detail.name))
        end

        return table.concat(parts, ", ")
    end

    -- =============================================================================
    -- ENCHANTS
    -- =============================================================================

    ---Resolves enchant display name from an enchant ID using overrides and category lookup.
    ---Returns nil when the name cannot be resolved (caller decides on fallback).
    ---@param enchantId number
    ---@return string|nil name Short enchant name, or nil if unresolvable
    local function resolveEnchantName(enchantId)
        local override = ENCHANT_OVERRIDES[enchantId]
        if type(override) == "number" then
            local raw = GetString("SI_ENCHANTMENTSEARCHCATEGORYTYPE", override)
            if raw and raw ~= "" then
                return zo_strformat("<<1>>", raw)
            end
        elseif type(override) == "string" then
            -- Item link override for enchants with no valid search category
            local _, header = GetItemLinkEnchantInfo(override)
            if header and header ~= "" then
                return zo_strformat("<<1>>", header)
            end
        elseif override == nil then
            local category = GetEnchantSearchCategoryType(enchantId)
            if not category or category == ENCHANTMENT_SEARCH_CATEGORY_NONE then return nil end
            local raw = GetString("SI_ENCHANTMENTSEARCHCATEGORYTYPE", category)
            if raw and raw ~= "" then
                return zo_strformat("<<1>>", raw)
            end
        end
        return nil
    end

    ---Gets the short enchant category name from an item link.
    ---Uses the enchantment search category (e.g. "Berserker", "Prismatic Defense")
    ---instead of the verbose tooltip header ("Multi-Effect Enchantment").
    ---@param link string Item link
    ---@return string name Short enchant name, or "" if no enchant
    function setupAnalysis.getEnchantName(link)
        local enchantId = GetItemLinkFinalEnchantId(link)
        if not enchantId or enchantId == 0 then return "" end

        local name = resolveEnchantName(enchantId)
        if name then return name end

        -- Fallback: extract name from the equipped item's enchant header
        local _, header = GetItemLinkEnchantInfo(link)
        if header and header ~= "" then
            return zo_strformat("<<1>>", header)
        end
        return ""
    end

    ---Groups and formats enchants from equipment slots (same pattern as groupTraits)
    ---@param equipSlots (string|false)[]
    ---@param slotIndices number[] Specific slot indices to examine
    ---@return string formatted Enchant summary (e.g. "3x Prismatic Defense, 2x Stamina")
    function setupAnalysis.groupEnchants(equipSlots, slotIndices)
        local enchantCounts = {}
        local enchantOrder = {}
        for _, i in ipairs(slotIndices) do
            local link = equipSlots[i]
            if link then
                local name = setupAnalysis.getEnchantName(link)
                if name ~= "" then
                    if not enchantCounts[name] then
                        enchantCounts[name] = 0
                        table.insert(enchantOrder, name)
                    end
                    enchantCounts[name] = enchantCounts[name] + 1
                end
            end
        end

        local details = {}
        for _, name in ipairs(enchantOrder) do
            table.insert(details, { name = name, count = enchantCounts[name] })
        end
        table.sort(details, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.name < b.name
        end)

        local parts = {}
        for _, detail in ipairs(details) do
            table.insert(parts, string.format("%dx %s", detail.count, detail.name))
        end

        return table.concat(parts, ", ")
    end
end

-- Ability names
do
    local utils = {}
    BattleScrolls.utils = utils

    function utils.GetScribeAwareAbilityDisplayName(abilityId)
        local craftedAbilityId = GetAbilityCraftedAbilityId(abilityId)
        if craftedAbilityId and craftedAbilityId ~= 0 then
            local craftedAbilityDisplayName = GetCraftedAbilityDisplayName(craftedAbilityId)
            if craftedAbilityDisplayName and craftedAbilityDisplayName ~= "" then
                return zo_strformat("<<C:1>>", craftedAbilityDisplayName)
            end
        end
        ---@diagnostic disable-next-line: missing-parameter
        return zo_strformat("<<C:1>>", GetAbilityName(abilityId))
    end
end

-- Display styles
do
    local journal = BattleScrolls.journal

    journal.ChampionDisciplineIcons = {
        [CHAMPION_DISCIPLINE_TYPE_COMBAT] = "EsoUI/Art/Champion/Gamepad/gp_quickmenu_combat.dds",
        [CHAMPION_DISCIPLINE_TYPE_CONDITIONING] = "EsoUI/Art/Champion/Gamepad/gp_quickmenu_conditioning.dds",
        [CHAMPION_DISCIPLINE_TYPE_WORLD] = "EsoUI/Art/Champion/Gamepad/gp_quickmenu_world.dds",
    }

    journal.AbilityIconStyle = {
        ICON_SIZE = 46,
        FRAME_INSET = 4,
        ULT_FRAME_INSET = 6,
        ULT_EDGE_COLOR = { 0.93, 0.79, 0.24, 1 },
        EDGE_TEXTURE = "EsoUI/Art/Miscellaneous/Gamepad/edgeframeGamepadBorder.dds",
        CIRCLE_FRAME_TEXTURE = "EsoUI/Art/Miscellaneous/Gamepad/gp_passiveFrame_64.dds",
        NAME_FONT = "ZoFontGamepad34",
        ROW_HEIGHT = 54,
        NAME_OFFSET_X = 68,  -- icon (46) + gap (22)
    }
end

-- Icons
do
    local utils = {}
    BattleScrolls.journal.utils = utils

    local abilityIconAbilityIdOverrides = {
        [201265] = 186370, -- pragmatic fatecarver shield -> damage
        [69118] = 63956, -- radiant glory heal -> damage
        [201275] = 183006, -- cephaliarch's flail heal -> damage
        [45221] = 68401, -- crafted potion heal -> crown potion heal
        [30978] = 30973, -- essence drain rank 1 heal -> essence drain passive
        [45518] = 45517, -- essence drain rank 2 heal -> essence drain passive
        [55606] = 55584, -- undaunted command rank 1 heal -> undaunted command passive
        [55677] = 55676, -- undaunted command rank 2 heal -> undaunted command passive
        [44013] = 26305, -- Purify heal -> Purify synergy
        [41964] = 41963, -- Blood Feast heal -> Blood Feast synergy
        [194645] = 183401, -- Runeguard of Still Waters heal -> Runeguard of Still Waters active ability
        [21908] = 21765, -- Purifying Light heal -> Purifying Light active ability
        [190960] = 108098, -- Harmony trait heal -> lapidary research passive (harmony itself doesn't have an ability with an icon)
        [22225] = 22223, -- Rite of Passage heal -> Rite of Passage ultimate skill
        [22228] = 22226, -- Practiced Incantation heal -> Practiced Incantation ultimate skill
        [22231] = 22229, -- Remembrance heal -> Remembrance ultimate skill
        [39267] = 39266, -- Soul Shatter Rank 1 damage -> Soul Shatter Rank 1 passive
        [45584] = 45583, -- Soul Shatter Rank 2 damage -> Soul Shatter Rank 2 passive
        [107055] = 61919, -- Merciless Resolve heal -> Merciless Resolve active ability
        -- TODO: Grim Focus and Relentless Focus icons
    }

    local EMPTY_VENGEANCE_PERK_ICON = "EsoUI/Art/Vengeance/perk_empty_slot.dds"

    local vengeancePerkFramedIconControlId = 0

    function utils.createVengeancePerkFramedIcon(parent)
        vengeancePerkFramedIconControlId = vengeancePerkFramedIconControlId + 1
        local control = CreateControlFromVirtual(
            "BattleScrollsVengeancePerkIcon" .. vengeancePerkFramedIconControlId,
            parent,
            "ZO_VengeancePerk_FramedIcon")
        control:SetMouseEnabled(false)
        control:SetHidden(true)
        return control
    end

    function utils.getAbilityIcon(abilityId)
        return GetAbilityIcon(abilityIconAbilityIdOverrides[abilityId] or abilityId)
    end

    function utils.isPassiveIcon(abilityIcon)
        if not abilityIcon then return false end
        return string.find(abilityIcon, "passive", 1, true) ~= nil
            or string.find(abilityIcon, "ability_dragonknight_023", 1, true) ~= nil
            or string.find(abilityIcon, "ability_dragonknight_031", 1, true) ~= nil
            or string.find(abilityIcon, "ability_psijic_009", 1, true) ~= nil
            or string.find(abilityIcon, "ability_psijic_010", 1, true) ~= nil
            or string.find(abilityIcon, "ability_sorcerer_026", 1, true) ~= nil
            or string.find(abilityIcon, "ability_sorcerer_047", 1, true) ~= nil
            or string.find(abilityIcon, "ability_sorcerer_054", 1, true) ~= nil
            or string.find(abilityIcon, "ability_templar_003", 1, true) ~= nil
            or string.find(abilityIcon, "ability_templar_012", 1, true) ~= nil
            or string.find(abilityIcon, "ability_templar_013", 1, true) ~= nil
            or string.find(abilityIcon, "ability_templar_014", 1, true) ~= nil
            or string.find(abilityIcon, "ability_templar_028", 1, true) ~= nil
            or string.find(abilityIcon, "ability_weapon_001", 1, true) ~= nil
            or string.find(abilityIcon, "ability_weapon_021", 1, true) ~= nil
            or string.find(abilityIcon, "ability_weapon_027", 1, true) ~= nil
            or string.find(abilityIcon, "ability_weapon_028", 1, true) ~= nil
            or string.find(abilityIcon, "ability_werewolf_010", 1, true) ~= nil
    end

    function utils.setupVengeancePerkFramedIcon(control, slotFlag, icon, iconSize)
        iconSize = iconSize or 52
        local frameSize = iconSize * 2
        local displayIcon = (icon and icon ~= "") and icon or EMPTY_VENGEANCE_PERK_ICON

        control:SetDimensions(iconSize, iconSize)

        local iconControl = control:GetNamedChild("Icon")
        local backgroundControl = control:GetNamedChild("Background")
        local borderControl = control:GetNamedChild("Border")

        if iconControl then
            iconControl:SetDimensions(iconSize, iconSize)
        end
        if backgroundControl then
            backgroundControl:SetDimensions(iconSize, iconSize)
        end
        if borderControl then
            borderControl:SetDimensions(frameSize, frameSize)
        end

        local framedIcon = control.object
        if framedIcon and framedIcon.SetPerkSlot and framedIcon.SetPerkData then
            framedIcon:SetPerkSlot(slotFlag)
            framedIcon:SetPerkData({
                GetIcon = function() return displayIcon end,
            })
            if framedIcon.SetPerkDisabled then
                framedIcon:SetPerkDisabled(false)
            end
        else
            local manager = _G["ZO_VENGEANCE_MANAGER"]
            if iconControl then
                iconControl:SetTexture(displayIcon)
            end
            if backgroundControl and manager and manager.GetPerkBackgroundBySlot then
                backgroundControl:SetTexture(manager:GetPerkBackgroundBySlot(slotFlag))
            end
            if borderControl and manager and manager.GetPerkBorderBySlot then
                borderControl:SetTexture(manager:GetPerkBorderBySlot(slotFlag))
            end
        end

        control:SetHidden(false)
    end
end

-- Control reuse
do
    ---@class ControlPool
    ---@field _controls Control[]
    ---@field _count number Controls in use this render pass
    ---@field _total number Total controls ever created
    ---@field _template string|nil Virtual template name (nil = plain CT_CONTROL)
    ---@field _parent Control Default parent for new controls
    ---@field _prefix string Control name prefix
    ---@field _onInit (fun(control: Control))|nil One-time init callback for new controls
    local ControlPool = {}
    ControlPool.__index = ControlPool

    ---Creates a new control pool.
    ---@param template string|nil XML virtual template name, or nil for plain CT_CONTROL containers
    ---@param parent Control Default parent control
    ---@param prefix string Short name prefix (prepended with "BS_")
    ---@param onInit (fun(control: Control))|nil Called once when a control is first created
    ---@return ControlPool
    function ControlPool.new(template, parent, prefix, onInit)
        return setmetatable({
            _controls = {},
            _count = 0,
            _total = 0,
            _template = template,
            _parent = parent,
            _prefix = "BS_" .. prefix .. "_",
            _onInit = onInit,
        }, ControlPool)
    end

    ---Acquires the next control (returned hidden). The caller or mount() shows it.
    ---Creates a new control if the pool is exhausted.
    ---@return Control
    function ControlPool:Acquire()
        self._count = self._count + 1
        if self._count > #self._controls then
            self._total = self._total + 1
            local control
            if self._template then
                control = CreateControlFromVirtual(
                    self._prefix .. self._total,
                    self._parent,
                    self._template
                )
            else
                control = CreateControl(
                    self._prefix .. self._total,
                    self._parent,
                    CT_CONTROL
                )
            end
            control:SetHidden(true)
            self._controls[#self._controls + 1] = control
            if self._onInit then
                self._onInit(control)
            end
        end
        local control = self._controls[self._count]
        control:SetHidden(true)
        control:ClearAnchors()
        return control
    end

    ---Hides all controls and resets the usage counter for the next render pass.
    function ControlPool:ReleaseAll()
        for i = 1, #self._controls do
            self._controls[i]:SetHidden(true)
            self._controls[i]:ClearAnchors()
        end
        self._count = 0
    end

    BattleScrolls.journal.ControlPool = ControlPool
end

-- Build rows
do
    local ControlPool = BattleScrolls.journal.ControlPool
    local journal = BattleScrolls.journal

    -------------------------
    -- Constants (moved from overview_panel.lua)

    local SECTION_HEADER_HEIGHT = 50
    local CHAMPION_HEADER_HEIGHT = 30

    -- Default gap between children inside a Section
    local DEFAULT_CHILD_GAP = 10

    -- Gap between top-level sections when mounted
    local SECTION_GAP = 15

    -- Icon sizing for horizontal ability rows
    local HORIZONTAL_ICON_SIZE = 46
    local HORIZONTAL_ICON_GAP = 8
    local HORIZONTAL_FRAME_INSET = 4
    local HORIZONTAL_ULT_FRAME_INSET = 6
    local HORIZONTAL_ROW_HEIGHT = 56

    -- Q2 icon text row sizing
    local ICON_TEXT_ICON_SIZE = 28
    local ICON_TEXT_FRAME_INSET = 2
    local ICON_TEXT_LABEL_OFFSET = 38
    local ICON_TEXT_ROW_HEIGHT = 32

    -- Champion row sizing
    local CHAMP_ROW_HEIGHT = 40
    local CHAMP_ICON_SIZE = 32
    local CHAMP_ICON_GAP = 16

    -- Vengeance perk row sizing. Basegame uses a 52px icon/background with a 104px border.
    local VENGEANCE_PERK_ICON_SIZE = 40
    local VENGEANCE_PERK_FRAME_SIZE = VENGEANCE_PERK_ICON_SIZE * 2
    local VENGEANCE_PERK_ROW_HEIGHT = VENGEANCE_PERK_FRAME_SIZE
    local VENGEANCE_PERK_LABEL_GAP = 20

    -- Side-by-side bar positioning
    local BAR_LABEL_HEIGHT = 30
    local SIDE_BY_SIDE_GAP = 40

    -------------------------
    -- Font Cascades

    local SECTION_TITLE_FONTS = {
        { font = "ZoFontGamepadBold34", lineLimit = 1 },
        { font = "ZoFontGamepadBold27", lineLimit = 1 },
        { font = "ZoFontGamepad27", lineLimit = 1, dontUseForAdjusting = true },
    }

    -------------------------
    -- Shared Utility Functions

    ---Initializes a label with font-adjusting for i18n text overflow (one-time)
    ---@param label Control
    ---@param fonts table
    local function initFontAdjusting(label, fonts)
        if not label.fontAdjustingInitialized then
            ZO_FontAdjustingWrapLabel_OnInitialized(label, fonts, TEXT_WRAP_MODE_ELLIPSIS)
            label.fontAdjustingInitialized = true
        end
    end

    ---Populates a horizontal icon container with ability icons.
    ---@param container Control Container with .icons sub-control array
    ---@param abilities PlayerSetupAbility[]
    local function populateHorizontalIcons(container, abilities)
        -- Ensure enough icon sub-controls exist (one per slot, including empty)
        if not container.icons then container.icons = {} end
        local slotCount = #abilities

        while #container.icons < slotCount do
            local idx = #container.icons + 1
            local iconControl = CreateControl(container:GetName() .. "Icon" .. idx, container, CT_TEXTURE)
            iconControl:SetDimensions(HORIZONTAL_ICON_SIZE, HORIZONTAL_ICON_SIZE)
            iconControl:SetHidden(true)

            local edgeFrame = CreateControl(container:GetName() .. "Icon" .. idx .. "Edge", container, CT_BACKDROP)
            edgeFrame:SetEdgeTexture("EsoUI/Art/Miscellaneous/Gamepad/edgeframeGamepadBorder.dds", 128, 16)
            edgeFrame:SetCenterColor(0, 0, 0, 0)
            edgeFrame:SetEdgeColor(ZO_NORMAL_TEXT:UnpackRGBA())
            edgeFrame:SetHidden(true)

            local circleFrame = CreateControl(container:GetName() .. "Icon" .. idx .. "Circle", container, CT_TEXTURE)
            circleFrame:SetTexture("EsoUI/Art/Miscellaneous/Gamepad/gp_passiveFrame_64.dds")
            circleFrame:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
            circleFrame:SetHidden(true)

            container.icons[idx] = { icon = iconControl, edgeFrame = edgeFrame, circleFrame = circleFrame }
        end

        -- Hide all first
        for _, entry in ipairs(container.icons) do
            entry.icon:SetHidden(true)
            entry.edgeFrame:SetHidden(true)
            entry.circleFrame:SetHidden(true)
        end

        -- Populate all slots (including empty ones — empty slots show frame only)
        for i, ability in ipairs(abilities) do
            local entry = container.icons[i]
            local isUltimate = (i == #abilities)
            local isEmpty = ability.abilityId == 0

            local offsetX = HORIZONTAL_FRAME_INSET + (i - 1) * (HORIZONTAL_ICON_SIZE + HORIZONTAL_ICON_GAP)
            entry.icon:ClearAnchors()
            entry.icon:SetAnchor(TOPLEFT, container, TOPLEFT, offsetX, 4)

            if isEmpty then
                entry.icon:SetHidden(true)
            else
                local abilityIcon = journal.utils.getAbilityIcon(ability.abilityId)
                entry.icon:SetTexture(abilityIcon)
                entry.icon:SetHidden(false)
            end

            local isPassive = not isEmpty and journal.utils.isPassiveIcon(journal.utils.getAbilityIcon(ability.abilityId))
            local frameInset = isUltimate and HORIZONTAL_ULT_FRAME_INSET or HORIZONTAL_FRAME_INSET

            entry.edgeFrame:ClearAnchors()
            entry.edgeFrame:SetAnchor(TOPLEFT, entry.icon, TOPLEFT, -frameInset, -frameInset)
            entry.edgeFrame:SetAnchor(BOTTOMRIGHT, entry.icon, BOTTOMRIGHT, frameInset, frameInset)
            if isUltimate then
                entry.edgeFrame:SetEdgeColor(unpack(journal.AbilityIconStyle.ULT_EDGE_COLOR))
            else
                entry.edgeFrame:SetEdgeColor(ZO_NORMAL_TEXT:UnpackRGBA())
            end
            entry.edgeFrame:SetHidden(isPassive)

            entry.circleFrame:ClearAnchors()
            entry.circleFrame:SetAnchor(TOPLEFT, entry.icon, TOPLEFT, -frameInset, -frameInset)
            entry.circleFrame:SetAnchor(BOTTOMRIGHT, entry.icon, BOTTOMRIGHT, frameInset, frameInset)
            entry.circleFrame:SetHidden(not isPassive)
        end
    end

    ---Flattens varargs into a list, filtering out nils and flattening arrays.
    ---Collects varargs into a flat list, skipping nil/false and flattening arrays.
    ---Uses select() to handle nil holes in varargs that ipairs would stop at.
    ---@return Control[]
    local function collectArgs(...)
        local result = {}
        local n = select('#', ...)
        for i = 1, n do
            local arg = select(i, ...)
            if arg then
                if type(arg) == "table" and not arg.GetName then
                    for _, child in ipairs(arg) do
                        if child then result[#result + 1] = child end
                    end
                else
                    result[#result + 1] = arg
                end
            end
        end
        return result
    end

    -------------------------
    -- ComponentFactory

    ---@class ComponentFactory
    ---@field pools table<string, ControlPool>
    local ComponentFactory = {}
    ComponentFactory.__index = ComponentFactory

    ---@class VengeancePerkRowItem
    ---@field slotFlag number
    ---@field icon string
    ---@field name string

    function ComponentFactory.new()
        return setmetatable({ pools = {} }, ComponentFactory)
    end

    function ComponentFactory:Initialize(panel)
        local parent = panel.q2ScrollChild or panel.q2Container
        self.pools = {
            -- Template-based pools
            container       = ControlPool.new(nil, parent, "Container"),
            section         = ControlPool.new("BattleScrolls_OverviewSectionHeader", parent, "Section"),
            subHeader       = ControlPool.new("BattleScrolls_ChampionDisciplineHeader", parent, "SubHdr"),
            -- Programmatic pools (sub-controls created on first use in factories)
            labeledBar      = ControlPool.new(nil, parent, "LabeledBar"),
            sideBySideBars  = ControlPool.new(nil, parent, "SideBars"),
            championRow2Col = ControlPool.new(nil, parent, "Champ2Col"),
            vengeancePerkRow2Col = ControlPool.new(nil, parent, "VengPerk2Col"),
            iconTextRow     = ControlPool.new(nil, parent, "IconText"),
            plainTextRow    = ControlPool.new(nil, parent, "PlainText"),
            horizontalStack = ControlPool.new(nil, parent, "HStack"),
        }
    end

    function ComponentFactory:ReleaseAll()
        for _, pool in pairs(self.pools) do
            pool:ReleaseAll()
        end
    end

    -------------------------
    -- ColumnBuilder

    ---@class ColumnBuilder
    ---@field parent Control ScrollChild to mount into
    ---@field width number Available width
    ---@field pools table<string, ControlPool> Shared pools
    local ColumnBuilder = {}
    ColumnBuilder.__index = ColumnBuilder

    ---Creates a column builder for a scroll child.
    ---@param scrollChild Control
    ---@return ColumnBuilder
    function ComponentFactory:column(scrollChild)
        return setmetatable({
            parent = scrollChild,
            width = scrollChild:GetWidth(),
            pools = self.pools,
        }, ColumnBuilder)
    end

    -------------------------
    -- Leaf Factories

    ---Creates a plain text row (programmatic, no XML template).
    ---@param text string
    ---@param color ZO_ColorDef|table|nil
    ---@param indent number|nil Left indent in pixels
    ---@return Control
    function ColumnBuilder:PlainTextRow(text, color, indent)
        local row = self.pools.plainTextRow:Acquire()
        indent = indent or 0

        -- Lazy init sub-controls
        if not row.label then
            row.label = CreateControl(row:GetName() .. "Label", row, CT_LABEL)
            row.label:SetFont("ZoFontGamepad27")
            row.label:SetVerticalAlignment(TEXT_ALIGN_TOP)
            row.label:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
        end

        row.label:SetWidth(self.width - indent)
        row.label:ClearAnchors()
        row.label:SetAnchor(TOPLEFT, row, TOPLEFT, indent, 0)
        row.label:SetText(text)

        if color then
            if color.UnpackRGBA then
                row.label:SetColor(color:UnpackRGBA())
            else
                row.label:SetColor(unpack(color))
            end
        else
            row.label:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
        end

        local textHeight = row.label:GetTextHeight()
        row:SetHeight(math.max(28, textHeight))
        row.label:SetHidden(false)
        row._topGap = 6
        return row
    end

    ---Creates an icon + text row (small framed icon with label).
    ---@param icon string Texture path
    ---@param text string
    ---@param color ZO_ColorDef|table|nil
    ---@param showFrame boolean|nil Whether to show icon frame (default true)
    ---@return Control
    function ColumnBuilder:IconTextRow(icon, text, color, showFrame)
        local row = self.pools.iconTextRow:Acquire()

        -- Lazy init sub-controls
        if not row.iconCtrl then
            row.iconCtrl = CreateControl(row:GetName() .. "Icon", row, CT_TEXTURE)
            row.iconCtrl:SetDimensions(ICON_TEXT_ICON_SIZE, ICON_TEXT_ICON_SIZE)
            row.iconCtrl:SetAnchor(LEFT, row, LEFT, ICON_TEXT_FRAME_INSET, 0)

            row.frame = CreateControl(row:GetName() .. "Frame", row, CT_BACKDROP)
            row.frame:SetEdgeTexture("EsoUI/Art/Miscellaneous/Gamepad/edgeframeGamepadBorder.dds", 128, 8)
            row.frame:SetCenterColor(0, 0, 0, 0)
            row.frame:SetEdgeColor(ZO_NORMAL_TEXT:UnpackRGBA())
            row.frame:SetDrawLevel(1)
            row.frame:SetAnchor(TOPLEFT, row.iconCtrl, TOPLEFT, -ICON_TEXT_FRAME_INSET, -ICON_TEXT_FRAME_INSET)
            row.frame:SetAnchor(BOTTOMRIGHT, row.iconCtrl, BOTTOMRIGHT, ICON_TEXT_FRAME_INSET, ICON_TEXT_FRAME_INSET)

            row.circleFrame = CreateControl(row:GetName() .. "CircleFrame", row, CT_TEXTURE)
            row.circleFrame:SetTexture("EsoUI/Art/Miscellaneous/Gamepad/gp_passiveFrame_64.dds")
            row.circleFrame:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
            row.circleFrame:SetDrawLevel(1)
            row.circleFrame:SetAnchor(TOPLEFT, row.iconCtrl, TOPLEFT, -ICON_TEXT_FRAME_INSET, -ICON_TEXT_FRAME_INSET)
            row.circleFrame:SetAnchor(BOTTOMRIGHT, row.iconCtrl, BOTTOMRIGHT, ICON_TEXT_FRAME_INSET, ICON_TEXT_FRAME_INSET)

            row.label = CreateControl(row:GetName() .. "Label", row, CT_LABEL)
            row.label:SetFont("ZoFontGamepad27")
            row.label:SetAnchor(LEFT, row, LEFT, ICON_TEXT_LABEL_OFFSET, 0)
            row.label:SetMaxLineCount(1)
            row.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
            row.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

            row._layoutWidth = function(control, width)
                control:SetWidth(width)
                control.label:SetWidth(math.max(0, width - ICON_TEXT_LABEL_OFFSET))
                control.label:SetHeight(ICON_TEXT_ROW_HEIGHT)
            end
            row._measureWidth = function(control)
                return ICON_TEXT_LABEL_OFFSET + control.label:GetTextWidth() + 4
            end
        end

        row:SetHeight(ICON_TEXT_ROW_HEIGHT)
        row._layoutWidth(row, self.width)
        row.iconCtrl:SetTexture(icon)
        row.iconCtrl:SetHidden(false)

        local frameVisible = showFrame ~= false
        local isPassive = frameVisible and journal.utils.isPassiveIcon(icon)
        row.frame:SetHidden(not frameVisible or isPassive)
        row.circleFrame:SetHidden(not frameVisible or not isPassive)

        row.label:SetText(text)

        if color then
            if color.UnpackRGBA then
                row.label:SetColor(color:UnpackRGBA())
            else
                row.label:SetColor(unpack(color))
            end
        else
            row.label:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
        end
        row.label:SetHidden(false)

        row._topGap = 6
        return row
    end

    ---Creates a sub-header (champion discipline header style).
    ---@param text string
    ---@return Control
    function ColumnBuilder:SubHeader(text)
        local header = self.pools.subHeader:Acquire()
        header:GetNamedChild("Label"):SetText(text)
        header:SetHeight(CHAMPION_HEADER_HEIGHT)
        header._topGap = 12
        return header
    end

    -------------------------
    -- Composite Factories

    ---Creates a horizontal stack using each child's measured width.
    ---Accepts controls as varargs or as arrays, matching Section()/mount().
    ---@param gap number Horizontal gap between children
    ---@param ... Control|Control[]|nil Children
    ---@return Control|nil container
    function ColumnBuilder:HorizontalStack(gap, ...)
        local children = collectArgs(...)
        if #children == 0 then return nil end

        local container = self.pools.horizontalStack:Acquire()
        local childCount = #children
        gap = gap or 0
        local totalGap = gap * math.max(0, childCount - 1)
        local availableWidth = math.max(0, self.width - totalGap)
        local childWidths = {}
        local totalChildWidth = 0
        for index, child in ipairs(children) do
            local childWidth = child._measureWidth and child._measureWidth(child) or child:GetWidth()
            childWidth = math.max(0, math.floor(childWidth or 0))
            childWidths[index] = childWidth
            totalChildWidth = totalChildWidth + childWidth
        end

        if totalChildWidth > availableWidth and totalChildWidth > 0 then
            local scale = availableWidth / totalChildWidth
            local scaledTotal = 0
            for index, childWidth in ipairs(childWidths) do
                childWidth = math.max(0, math.floor(childWidth * scale))
                childWidths[index] = childWidth
                scaledTotal = scaledTotal + childWidth
            end
            childWidths[childCount] = childWidths[childCount] + (availableWidth - scaledTotal)
        end

        local offsetX = 0
        local maxHeight = 0

        for index, child in ipairs(children) do
            local childWidth = childWidths[index]
            child:SetParent(container)
            child:ClearAnchors()
            child:SetAnchor(TOPLEFT, container, TOPLEFT, offsetX, 0)
            child:SetWidth(childWidth)
            if child._layoutWidth then
                child._layoutWidth(child, childWidth)
            end
            child:SetHidden(false)

            maxHeight = math.max(maxHeight, child:GetHeight())
            offsetX = offsetX + childWidth + gap
        end

        container:SetHeight(maxHeight)
        container:SetWidth(math.max(0, offsetX - gap))
        container._topGap = children[1]._topGap or DEFAULT_CHILD_GAP
        return container
    end

    ---Creates a section with header and stacked children.
    ---Returns nil if no children (conditional rendering).
    ---@param title string Section header text
    ---@param ... Control|Control[]|nil Children (nils filtered, arrays flattened)
    ---@return Control|nil container Hidden container, or nil if empty
    function ColumnBuilder:Section(title, ...)
        local children = collectArgs(...)
        if #children == 0 then return nil end

        local container = self.pools.container:Acquire()
        local header = self.pools.section:Acquire()

        local titleLabel = header:GetNamedChild("Title")
        initFontAdjusting(titleLabel, SECTION_TITLE_FONTS)
        titleLabel:SetText(title)

        -- Clear any previous timing label
        local timingLabel = header:GetNamedChild("Timing")
        if timingLabel then timingLabel:SetHidden(true) end

        header:SetParent(container)
        header:ClearAnchors()
        header:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
        header:SetAnchor(TOPRIGHT, container, TOPRIGHT, 0, 0)
        header:SetHidden(false)

        local offset = SECTION_HEADER_HEIGHT
        for _, child in ipairs(children) do
            if child then
                local gap = child._topGap or DEFAULT_CHILD_GAP
                offset = offset + gap
                child:SetParent(container)
                child:ClearAnchors()
                child:SetAnchor(TOPLEFT, container, TOPLEFT, 0, offset)
                child:SetAnchor(TOPRIGHT, container, TOPRIGHT, 0, offset)
                child:SetHidden(false)
                offset = offset + child:GetHeight()
            end
        end

        container:SetHeight(offset)
        container:SetWidth(self.width)
        container._header = header
        -- Container stays hidden — mount()/mountFitted() shows it
        return container
    end

    ---Creates a single labeled ability bar (label + icon row).
    ---@param abilities PlayerSetupAbility[]
    ---@param label string
    ---@return Control
    function ColumnBuilder:LabeledBar(abilities, label)
        local wrapper = self.pools.labeledBar:Acquire()

        if not wrapper.label then
            wrapper.label = CreateControl(wrapper:GetName() .. "Label", wrapper, CT_LABEL)
            wrapper.label:SetFont("ZoFontGamepadBold27")
            wrapper.label:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
            wrapper.label:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)

            wrapper.icons = CreateControl(wrapper:GetName() .. "Icons", wrapper, CT_CONTROL)
            wrapper.icons:SetHeight(HORIZONTAL_ROW_HEIGHT)
            wrapper.icons.icons = {}
        end

        wrapper.label:SetText(label)
        wrapper.label:ClearAnchors()
        wrapper.label:SetAnchor(TOPLEFT, wrapper, TOPLEFT, 0, 0)
        wrapper.label:SetWidth(0)
        wrapper.label:SetHeight(BAR_LABEL_HEIGHT)
        wrapper.label:SetHidden(false)

        local barWidth = #abilities * (HORIZONTAL_ICON_SIZE + HORIZONTAL_ICON_GAP) - HORIZONTAL_ICON_GAP
        wrapper.icons:ClearAnchors()
        wrapper.icons:SetAnchor(TOPLEFT, wrapper, TOPLEFT, -1, BAR_LABEL_HEIGHT)
        wrapper.icons:SetWidth(barWidth)
        wrapper.icons:SetHidden(false)
        populateHorizontalIcons(wrapper.icons, abilities)

        wrapper:SetHeight(BAR_LABEL_HEIGHT + HORIZONTAL_ROW_HEIGHT)
        wrapper:SetWidth(self.width)
        return wrapper
    end

    ---Creates a side-by-side ability bar display (front + back bars with labels).
    ---@param frontAbilities PlayerSetupAbility[]
    ---@param backAbilities PlayerSetupAbility[]
    ---@param frontLabel string
    ---@param backLabel string

    ---@return Control
    function ColumnBuilder:SideBySideBars(frontAbilities, backAbilities, frontLabel, backLabel)
        local wrapper = self.pools.sideBySideBars:Acquire()

        -- Lazy init sub-controls
        if not wrapper.frontLabel then
            wrapper.frontLabel = CreateControl(wrapper:GetName() .. "FLabel", wrapper, CT_LABEL)
            wrapper.frontLabel:SetFont("ZoFontGamepadBold27")
            wrapper.frontLabel:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
            wrapper.frontLabel:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)

            wrapper.backLabel = CreateControl(wrapper:GetName() .. "BLabel", wrapper, CT_LABEL)
            wrapper.backLabel:SetFont("ZoFontGamepadBold27")
            wrapper.backLabel:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
            wrapper.backLabel:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)

            wrapper.frontIcons = CreateControl(wrapper:GetName() .. "FIcons", wrapper, CT_CONTROL)
            wrapper.frontIcons:SetHeight(HORIZONTAL_ROW_HEIGHT)
            wrapper.frontIcons.icons = {}

            wrapper.backIcons = CreateControl(wrapper:GetName() .. "BIcons", wrapper, CT_CONTROL)
            wrapper.backIcons:SetHeight(HORIZONTAL_ROW_HEIGHT)
            wrapper.backIcons.icons = {}
        end

        local barWidth = math.max(#frontAbilities, #backAbilities)
            * (HORIZONTAL_ICON_SIZE + HORIZONTAL_ICON_GAP) - HORIZONTAL_ICON_GAP
        local backOffsetX = barWidth + HORIZONTAL_FRAME_INSET + SIDE_BY_SIDE_GAP

        wrapper.frontLabel:SetText(frontLabel)
        wrapper.frontLabel:ClearAnchors()
        wrapper.frontLabel:SetAnchor(TOPLEFT, wrapper, TOPLEFT, 0, 0)
        wrapper.frontLabel:SetWidth(barWidth)
        wrapper.frontLabel:SetHeight(BAR_LABEL_HEIGHT)
        wrapper.frontLabel:SetHidden(false)

        wrapper.backLabel:SetText(backLabel)
        wrapper.backLabel:ClearAnchors()
        wrapper.backLabel:SetAnchor(TOPLEFT, wrapper, TOPLEFT, backOffsetX, 0)
        wrapper.backLabel:SetWidth(barWidth)
        wrapper.backLabel:SetHeight(BAR_LABEL_HEIGHT)
        wrapper.backLabel:SetHidden(false)

        -- Icon containers
        wrapper.frontIcons:ClearAnchors()
        wrapper.frontIcons:SetAnchor(TOPLEFT, wrapper, TOPLEFT, -1, BAR_LABEL_HEIGHT)
        wrapper.frontIcons:SetWidth(barWidth)
        wrapper.frontIcons:SetHidden(false)
        populateHorizontalIcons(wrapper.frontIcons, frontAbilities)

        wrapper.backIcons:ClearAnchors()
        wrapper.backIcons:SetAnchor(TOPLEFT, wrapper, TOPLEFT, backOffsetX - 1, BAR_LABEL_HEIGHT)
        wrapper.backIcons:SetWidth(barWidth)
        wrapper.backIcons:SetHidden(false)
        populateHorizontalIcons(wrapper.backIcons, backAbilities)

        wrapper:SetHeight(BAR_LABEL_HEIGHT + HORIZONTAL_ROW_HEIGHT)
        wrapper:SetWidth(self.width)
        return wrapper
    end

    ---Creates a 2-column champion row (icon + label per column).
    ---@param leftName string
    ---@param leftIcon string
    ---@param rightName string|nil
    ---@param rightIcon string|nil
    ---@return Control
    function ColumnBuilder:ChampionRow2Col(leftName, leftIcon, rightName, rightIcon)
        local row = self.pools.championRow2Col:Acquire()

        -- Lazy init sub-controls
        if not row.leftIcon then
            row.leftIcon = CreateControl(row:GetName() .. "LIcon", row, CT_TEXTURE)
            row.leftIcon:SetDimensions(CHAMP_ICON_SIZE, CHAMP_ICON_SIZE)
            row.leftIcon:SetAnchor(LEFT, row, LEFT, 0, 0)

            row.leftLabel = CreateControl(row:GetName() .. "LLabel", row, CT_LABEL)
            row.leftLabel:SetFont("ZoFontGamepad34")
            row.leftLabel:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
            row.leftLabel:SetMaxLineCount(1)
            row.leftLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
            row.leftLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            row.leftLabel:SetAnchor(LEFT, row.leftIcon, RIGHT, CHAMP_ICON_GAP, 0)
            row.leftLabel:SetHeight(CHAMP_ROW_HEIGHT)

            row.rightIcon = CreateControl(row:GetName() .. "RIcon", row, CT_TEXTURE)
            row.rightIcon:SetDimensions(CHAMP_ICON_SIZE, CHAMP_ICON_SIZE)
            row.rightIcon:SetHidden(true)

            row.rightLabel = CreateControl(row:GetName() .. "RLabel", row, CT_LABEL)
            row.rightLabel:SetFont("ZoFontGamepad34")
            row.rightLabel:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
            row.rightLabel:SetMaxLineCount(1)
            row.rightLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
            row.rightLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            row.rightLabel:SetHeight(CHAMP_ROW_HEIGHT)
            row.rightLabel:SetHidden(true)
        end

        local halfWidth = math.floor(self.width / 2)

        row.leftIcon:SetTexture(leftIcon)
        row.leftIcon:SetHidden(false)
        row.leftLabel:SetText(leftName)
        row.leftLabel:SetWidth(halfWidth - CHAMP_ICON_SIZE - CHAMP_ICON_GAP)
        row.leftLabel:SetHidden(false)

        if rightName and rightIcon then
            row.rightIcon:ClearAnchors()
            row.rightIcon:SetAnchor(LEFT, row, LEFT, halfWidth, 0)
            row.rightIcon:SetTexture(rightIcon)
            row.rightIcon:SetHidden(false)
            row.rightLabel:ClearAnchors()
            row.rightLabel:SetAnchor(LEFT, row.rightIcon, RIGHT, CHAMP_ICON_GAP, 0)
            row.rightLabel:SetText(rightName)
            row.rightLabel:SetWidth(halfWidth - CHAMP_ICON_SIZE - CHAMP_ICON_GAP)
            row.rightLabel:SetHidden(false)
        else
            row.rightIcon:SetHidden(true)
            row.rightLabel:SetHidden(true)
        end

        row:SetHeight(CHAMP_ROW_HEIGHT)
        row:SetWidth(self.width)
        row._topGap = 3
        return row
    end

    ---Ensures a programmatic Vengeance perk row has enough columns.
    ---@param row Control
    ---@param count number
    local function ensureVengeancePerkColumns(row, count)
        if not row.perkCols then row.perkCols = {} end

        while #row.perkCols < count do
            local index = #row.perkCols + 1
            local col = {}

            col.framedIcon = journal.utils.createVengeancePerkFramedIcon(row)

            col.label = CreateControl(row:GetName() .. "C" .. index .. "Label", row, CT_LABEL)
            col.label:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())
            col.label:SetMaxLineCount(1)
            col.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
            col.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

            row.perkCols[index] = col
        end
    end

    ---@param col table
    ---@param item VengeancePerkRowItem|nil
    ---@param row Control
    ---@param offsetX number
    ---@param colWidth number
    ---@param iconSize number
    ---@param frameSize number
    ---@param rowHeight number
    ---@param font string
    local function layoutVengeancePerkColumn(col, item, row, offsetX, colWidth, iconSize, frameSize, rowHeight, font)
        if not item or item.name == "" then
            col.framedIcon:SetHidden(true)
            col.label:SetHidden(true)
            return
        end

        local frameBleed = math.max(0, math.floor((frameSize - iconSize) / 2))
        local iconCenterX = offsetX + frameBleed + math.floor(iconSize / 2)

        journal.utils.setupVengeancePerkFramedIcon(col.framedIcon, item.slotFlag, item.icon, iconSize)
        col.framedIcon:ClearAnchors()
        col.framedIcon:SetAnchor(CENTER, row, LEFT, iconCenterX, 0)

        local labelOffsetX = offsetX + frameBleed + iconSize + VENGEANCE_PERK_LABEL_GAP
        col.label:SetFont(font)
        col.label:SetHeight(rowHeight)
        col.label:ClearAnchors()
        col.label:SetAnchor(LEFT, row, LEFT, labelOffsetX, 0)
        col.label:SetWidth(math.max(0, colWidth - frameBleed - iconSize - VENGEANCE_PERK_LABEL_GAP))
        col.label:SetText(item.name)
        col.label:SetHidden(false)
    end

    ---Creates a 2-column Vengeance perk row with ESO-style framed icons.
    ---@param left VengeancePerkRowItem
    ---@param right VengeancePerkRowItem|nil
    ---@return Control
    function ColumnBuilder:VengeancePerkRow2Col(left, right)
        local row = self.pools.vengeancePerkRow2Col:Acquire()
        ensureVengeancePerkColumns(row, 2)

        local halfWidth = math.floor(self.width / 2)
        layoutVengeancePerkColumn(row.perkCols[1], left, row, 0, halfWidth,
            VENGEANCE_PERK_ICON_SIZE, VENGEANCE_PERK_FRAME_SIZE, VENGEANCE_PERK_ROW_HEIGHT, "ZoFontGamepad34")
        layoutVengeancePerkColumn(row.perkCols[2], right, row, halfWidth, halfWidth,
            VENGEANCE_PERK_ICON_SIZE, VENGEANCE_PERK_FRAME_SIZE, VENGEANCE_PERK_ROW_HEIGHT, "ZoFontGamepad34")

        row:SetHeight(VENGEANCE_PERK_ROW_HEIGHT)
        row:SetWidth(self.width)
        row._topGap = 1
        return row
    end

    -- Mount Methods

    ---Mounts components into the column's scroll child using offset anchoring.
    ---@param gap number Vertical gap between components
    ---@param insetX number Horizontal inset from edges
    ---@param ... Control|Control[]|nil Components to mount
    function ColumnBuilder:mount(gap, insetX, ...)
        local components = collectArgs(...)
        local offset = 0

        for i, control in ipairs(components) do
            if i > 1 then offset = offset + (control._topGap or gap) end
            control:SetParent(self.parent)
            control:ClearAnchors()
            control:SetAnchor(TOPLEFT, self.parent, TOPLEFT, insetX, offset)
            control:SetAnchor(TOPRIGHT, self.parent, TOPRIGHT, -insetX, offset)
            control:SetHidden(false)
            offset = offset + control:GetHeight()
        end
    end

    -------------------------
    -- Exports

    -- Export constants for use by overview_panel.lua and renderers
    journal.SECTION_GAP = SECTION_GAP
    journal.Q3_INSET = 2

    journal.ComponentFactory = ComponentFactory
end

-- Build layout
do
    local journal = BattleScrolls.journal
    local constants = BattleScrolls.constants
    local FOOD_ABILITY_INFO = constants.foodAbilityInfo
    local FOOD_COMBO_STRINGS = constants.FOOD_COMBO_STRINGS
    local RACE_ICONS = constants.raceIcons
    local VENGEANCE_LOADOUTS_BY_SKILL_LINE_ID = constants.VENGEANCE_LOADOUTS_BY_SKILL_LINE_ID
    local VENGEANCE_PERK_SLOTS = constants.VENGEANCE_PERK_SLOTS

    local analysis = BattleScrolls.setupAnalysis

    local setup = {}
    journal.renderers.setup = setup

    ---Extracts the PotionEffect field (field 20) from an item link.
    ---@param itemLink string
    ---@return number potionEffect The packed effect integer (0 if not found)
    local function getPotionEffect(itemLink)
        return tonumber(itemLink:match(":(%d+)|h")) or 0
    end

    ---Returns the localized alchemy trait name for the given effect ID (1-32).
    ---@param effectId number
    ---@return string
    local function getAlchemyTraitName(effectId)
        local stringId = _G["BATTLESCROLLS_ALCHEMY_TRAIT" .. effectId]
        return stringId and GetString(stringId) or ""
    end

    ---Parses effect IDs from a PotionEffect integer (up to 3 packed bytes).
    ---@param potionEffect number The packed PotionEffect integer
    ---@return number[] effectIds Array of 1-based effect IDs (1-32 range)
    local function parsePoisonEffects(potionEffect)
        if potionEffect == 0 then return {} end
        local effects = {}
        local byte3 = zo_floor(potionEffect / 65536) % 128  -- bits 16-22 (mask out 3-reagent flag at bit 23)
        local byte2 = zo_floor(potionEffect / 256) % 256     -- bits 8-15
        local byte1 = potionEffect % 256                      -- bits 0-7
        if byte3 > 0 then effects[#effects + 1] = byte3 end
        if byte2 > 0 then effects[#effects + 1] = byte2 end
        if byte1 > 0 then effects[#effects + 1] = byte1 end
        return effects
    end

    ---Builds a display label for a poison from its item link.
    ---Returns trait names joined with " + " for crafted poisons, or item name for unique poisons.
    ---@param itemLink string
    ---@return string label Display label
    ---@return string icon Icon texture path
    local function getPoisonDisplay(itemLink)
        local potionEffect = getPotionEffect(itemLink)
        local icon = GetItemLinkIcon(itemLink)
        if potionEffect > 0 then
            -- Crafted poison: show trait names
            local effects = parsePoisonEffects(potionEffect)
            local names = {}
            for _, effectId in ipairs(effects) do
                local name = getAlchemyTraitName(effectId)
                if name ~= "" then
                    names[#names + 1] = name
                end
            end
            return table.concat(names, " + "), icon
        else
            -- Unique poison: show item name
            return zo_strformat("<<C:1>>", GetItemLinkName(itemLink)), icon
        end
    end

    -- Import shared constants from setup_analysis
    local TWO_HANDED_TYPES = analysis.TWO_HANDED_TYPES
    local ARMOR_SLOT_INDICES = analysis.ARMOR_SLOT_INDICES
    local FRONT_MAIN_HAND_INDEX = analysis.FRONT_MAIN_HAND_INDEX
    local BACK_MAIN_HAND_INDEX = analysis.BACK_MAIN_HAND_INDEX
    local JEWELRY_SLOT_INDICES = analysis.JEWELRY_SLOT_INDICES

    -- Import shared functions from setup_analysis
    local computeSetData = analysis.computeSetData
    local countArmorWeights = analysis.countArmorWeights
    local groupTraits = analysis.groupTraits
    local getEnchantName = analysis.getEnchantName
    local groupEnchants = analysis.groupEnchants

    -- Warfare → Fitness → Craft (Craft last so it clips first if space is tight)
    local DISCIPLINE_SORT = {
        [CHAMPION_DISCIPLINE_TYPE_COMBAT] = 1,       -- Warfare
        [CHAMPION_DISCIPLINE_TYPE_CONDITIONING] = 2, -- Fitness
        [CHAMPION_DISCIPLINE_TYPE_WORLD] = 3,        -- Craft
    }

    ---Groups champion skills by discipline, sorted Warfare → Fitness → Craft.
    ---@param skills PlayerSetupChampionSkill[]
    ---@return table<number, PlayerSetupChampionSkill[]> disciplines Keyed by disciplineId
    ---@return number[] disciplineOrder Ordered discipline IDs
    local function groupChampionByDiscipline(skills)
        local disciplines = {}
        local disciplineOrder = {}
        for _, skill in ipairs(skills) do
            if not disciplines[skill.disciplineId] then
                disciplines[skill.disciplineId] = {}
                table.insert(disciplineOrder, skill.disciplineId)
            end
            table.insert(disciplines[skill.disciplineId], skill)
        end
        table.sort(disciplineOrder, function(a, b)
            local typeA = GetChampionDisciplineType(a)
            local typeB = GetChampionDisciplineType(b)
            return (DISCIPLINE_SORT[typeA] or 99) < (DISCIPLINE_SORT[typeB] or 99)
        end)
        return disciplines, disciplineOrder
    end

    -- Fallback champion icon
    local CHAMPION_ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_champion.dds"
    local EMPTY_VENGEANCE_PERK_ICON = "EsoUI/Art/Vengeance/perk_empty_slot.dds"

    -- Inline icon size for text rows (race, class, mundus, food, scribing)
    local INLINE_ICON_SIZE = 28
    local CLASS_MASTERY_PASSIVE_GAP = 12

    -- Left indent for Q3 detail lines under sub-headers
    local Q3_INDENT = 16

    -- Custom display names for 2H weapons (ESO's SI_WEAPONTYPE gives generic 1H names)
    local TWO_HANDED_WEAPON_NAMES = {
        [WEAPONTYPE_TWO_HANDED_SWORD] = BATTLESCROLLS_WEAPON_GREATSWORD,
        [WEAPONTYPE_TWO_HANDED_AXE] = BATTLESCROLLS_WEAPON_BATTLE_AXE,
        [WEAPONTYPE_TWO_HANDED_HAMMER] = BATTLESCROLLS_WEAPON_MAUL,
    }

    -------------------------
    -- Set Data Display

    ---Sorts sets by max piece count descending, filters to active, formats each line.
    ---Name is colorized with COLOR_TYPE; count and bar indicator are plain (for COLOR_TRAIT rows).
    ---@param equipSlots (string|false)[]
    ---@return string[] lines Formatted set strings (e.g. "5x |cFFFFFF Pillar of Nirn|r (Back Bar)")
    local function formatActiveSets(equipSlots)
        local sets = computeSetData(equipSlots)

        local sortedSets = {}
        for setId, data in pairs(sets) do
            sortedSets[#sortedSets + 1] = { setId = setId, data = data }
        end
        table.sort(sortedSets, function(a, b)
            local aMax = math.max(a.data.frontCount, a.data.backCount)
            local bMax = math.max(b.data.frontCount, b.data.backCount)
            if aMax ~= bMax then return aMax > bMax end
            return a.data.name < b.data.name
        end)

        local result = {}
        for _, setEntry in ipairs(sortedSets) do
            local data = setEntry.data
            if data.frontStep > 0 or data.backStep > 0 then
                local isPerfected = data.perfectedActiveFront or data.perfectedActiveBack
                local name = (isPerfected and data.perfectedSetId)
                    and zo_strformat("<<C:1>>", GetItemSetName(data.perfectedSetId))
                    or data.name
                local coloredName = ZO_SELECTED_TEXT:Colorize(name)

                local line
                if data.frontStep == data.backStep then
                    line = string.format("%dx %s", data.frontStep, coloredName)
                elseif data.frontStep == 0 then
                    line = string.format("%dx %s (%s)", data.backStep, coloredName,
                        GetString(BATTLESCROLLS_SETUP_BACK_BAR))
                elseif data.backStep == 0 then
                    line = string.format("%dx %s (%s)", data.frontStep, coloredName,
                        GetString(BATTLESCROLLS_SETUP_FRONT_BAR))
                else
                    line = string.format("%dx/%dx %s", data.frontStep, data.backStep, coloredName)
                end

                result[#result + 1] = line
            end
        end
        return result
    end

    ---Resolves race and class display info from IDs.
    ---@param raceId number
    ---@param classId number
    ---@return string raceName, string className, string raceIcon, string classIcon
    local function resolveRaceClass(raceId, classId)
        local gender = GetUnitGender("player")
        local raceName = zo_strformat("<<1>>", GetRaceName(gender, raceId))
        local className = zo_strformat("<<1>>", GetClassName(gender, classId))
        local raceIcon = RACE_ICONS[raceId] or ""
        local classIcon = ""
        local classIndex = GetClassIndexById(classId)
        if classIndex then
            local _, _, _, _, _, _, _, ingameIconGamepad = GetClassInfo(classIndex)
            classIcon = ingameIconGamepad or ""
        end
        return raceName, className, raceIcon, classIcon
    end

    ---Resolves class skill line display info (name + collectible icon).
    ---@param classSkillLineIds number[]
    ---@return { name: string, icon: string }[]
    local function resolveClassSkillLines(classSkillLineIds)
        local result = {}
        for _, skillLineId in ipairs(classSkillLineIds) do
            if skillLineId > 0 then
                local name = GetSkillLineNameById(skillLineId)
                if name and name ~= "" then
                    local formatted = ZO_CachedStrFormat(SI_SKILLS_ENTRY_LINE_NAME_FORMAT, name)
                    local icon = ""
                    local collectibleId = GetSkillLineMasteryCollectibleId(skillLineId)
                    if collectibleId and collectibleId > 0 then
                        icon = GetCollectibleIcon(collectibleId) or ""
                    end
                    result[#result + 1] = { name = formatted, icon = icon }
                end
            end
        end
        return result
    end

    ---Resolves Vengeance loadout display info from its skill line ID.
    ---@param skillLineId number|nil
    ---@return { name: string, icon: string }|nil
    local function resolveVengeanceLoadout(skillLineId)
        if not skillLineId or skillLineId <= 0 then return nil end
        local loadout = VENGEANCE_LOADOUTS_BY_SKILL_LINE_ID[skillLineId]
        if not loadout then return nil end

        local name = GetSkillLineNameById(skillLineId)
        if not name or name == "" then return nil end

        return {
            name = ZO_CachedStrFormat(SI_SKILLS_ENTRY_LINE_NAME_FORMAT, name),
            icon = loadout.icon,
        }
    end

    ---Resolves Class Mastery passive ability display info.
    ---@param classMasteryAbilityIds number[]|nil
    ---@return { abilityId: number, name: string, icon: string }[]
    local function resolveClassMasteryAbilities(classMasteryAbilityIds)
        local result = {}
        if not classMasteryAbilityIds then return result end
        for _, abilityId in ipairs(classMasteryAbilityIds) do
            if abilityId > 0 then
                local name = GetAbilityName(abilityId, "")
                if name and name ~= "" then
                    result[#result + 1] = {
                        abilityId = abilityId,
                        name = zo_strformat("<<C:1>>", name),
                        icon = journal.utils.getAbilityIcon(abilityId) or "",
                    }
                end
            end
        end
        return result
    end

    ---Returns the localized Vengeance perk slot name.
    ---@param slotFlag number VENGEANCE_PERK_SLOT_* flag
    ---@return string
    local function getVengeancePerkSlotName(slotFlag)
        local name = zo_strformat("<<1>>", GetString("SI_VENGEANCEPERKSLOTFLAGS", slotFlag))
        return name ~= "" and name or GetString(BATTLESCROLLS_SETUP_PERKS)
    end

    ---Resolves Vengeance perk display info in fixed red/yellow/blue order.
    ---@param perkDefIds number[]|nil
    ---@return { slotFlag: number, slotName: string, defId: number, name: string, icon: string }[]
    local function resolveVengeancePerkSlots(perkDefIds)
        local result = {}
        local getPerkName = _G["GetVengeancePerkName"]
        local getPerkIcon = _G["GetVengeancePerkIcon"]
        local canResolvePerks = type(getPerkName) == "function" and type(getPerkIcon) == "function"

        for i, slotFlag in ipairs(VENGEANCE_PERK_SLOTS) do
            local defId = perkDefIds and (perkDefIds[i] or 0) or 0
            local name = ""
            local icon = EMPTY_VENGEANCE_PERK_ICON
            if canResolvePerks and defId > 0 then
                local rawName = getPerkName(defId)
                if rawName and rawName ~= "" then
                    name = zo_strformat("<<C:1>>", rawName)
                    icon = getPerkIcon(defId) or EMPTY_VENGEANCE_PERK_ICON
                    if icon == "" then icon = EMPTY_VENGEANCE_PERK_ICON end
                end
            end
            result[#result + 1] = {
                slotFlag = slotFlag,
                slotName = getVengeancePerkSlotName(slotFlag),
                defId = defId,
                name = name,
                icon = icon,
            }
        end

        return result
    end

    ---Resolves food display info from a food entry.
    ---@param food PlayerSetupFood

    ---@return string name, string icon
    local function resolveFoodDisplay(food)
        local info = FOOD_ABILITY_INFO[food.abilityId]
        local itemId = type(info) == "number" and info or nil
        local statIds = type(info) == "table" and info or nil
        local itemLink = itemId
            and string.format("|H1:item:%d:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId)
            or nil
        local name
        if itemLink then
            local rawName = GetItemLinkName(itemLink)
            name = rawName ~= "" and zo_strformat("<<C:1>>", rawName) or ""
        elseif statIds then
            local key = table.concat(statIds, ",")
            local stringId = FOOD_COMBO_STRINGS[key]
            name = stringId and GetString(stringId) or ""
        else
            local rawName = GetAbilityName(food.abilityId, "")
            name = rawName ~= "" and zo_strformat("<<C:1>>", rawName) or ""
        end
        local icon = itemLink
            and GetItemLinkIcon(itemLink)
            or journal.utils.getAbilityIcon(food.abilityId)
        return name or "", icon or ""
    end

    ---Builds inline icon markup for text rows
    ---@param texture string
    ---@return string
    local function inlineIcon(texture)
        return string.format("|t%d:%d:%s|t ", INLINE_ICON_SIZE, INLINE_ICON_SIZE, texture)
    end

    ---Gets the constellation icon for a mundus stone ability (matches ESO character screen).
    ---Falls back to ability icon if lookup fails.
    ---@param abilityId number
    ---@return string icon
    local function getMundusConstellationIcon(abilityId)
        local mundusType = GetAbilityMundusStoneType(abilityId)
        if mundusType and ZO_STAT_MUNDUS_ICONS then
            local icon = ZO_STAT_MUNDUS_ICONS[mundusType]
            if icon then return icon end
        end
        return journal.utils.getAbilityIcon(abilityId)
    end

    ---Builds the CHARACTER section (race/class, skill lines, mundus, food).
    ---@param col ColumnBuilder
    ---@param setupData PlayerSetup

    ---@return Control|nil section
    local function buildCharacterSection(col, setupData)
        local charRows = {}

        -- Race + Class line (with mundus constellation icons)
        -- local log = BattleScrolls.log

        --     tostring(setupData.raceId), tostring(setupData.classId),
        --     setupData.mundusAbilityIds and ("#" .. #setupData.mundusAbilityIds) or "nil"))
        if setupData.raceId and setupData.classId then
            local raceName, className, raceIcon, classIcon = resolveRaceClass(setupData.raceId, setupData.classId)

            --     raceName, className, raceIcon, classIcon))
            if raceName ~= "" and className ~= "" then
                local racePart = raceIcon ~= "" and inlineIcon(raceIcon) .. raceName or raceName
                local classPart = classIcon ~= "" and inlineIcon(classIcon) .. className or className
                local line = racePart .. "  " .. classPart
                if not setupData.isVengeance and setupData.mundusAbilityIds then
                    for _, abilityId in ipairs(setupData.mundusAbilityIds) do
                        local name = zo_strformat("<<C:1>>", GetAbilityName(abilityId, ""))
                        if name ~= "" then
                            line = line .. "  " .. inlineIcon(getMundusConstellationIcon(abilityId)) .. name
                        end
                    end
                end
                charRows[#charRows + 1] = col:PlainTextRow(line, ZO_SELECTED_TEXT)
            end
        end

        if setupData.isVengeance then
            local loadout = resolveVengeanceLoadout(setupData.loadoutSkillLineId)
            if loadout then
                local line = loadout.icon ~= "" and inlineIcon(loadout.icon) .. loadout.name or loadout.name
                charRows[#charRows + 1] = col:PlainTextRow(line, ZO_HIGHLIGHT_TEXT)
            end
        else
            -- Class Mastery passives when available; otherwise class skill lines.
            local classMasteryAbilities = resolveClassMasteryAbilities(setupData.classMasteryAbilityIds)
            if #classMasteryAbilities > 0 then
                local passiveRows = {}
                for _, ability in ipairs(classMasteryAbilities) do
                    passiveRows[#passiveRows + 1] = col:IconTextRow(ability.icon, ability.name, ZO_HIGHLIGHT_TEXT)
                end
                charRows[#charRows + 1] = col:HorizontalStack(CLASS_MASTERY_PASSIVE_GAP, passiveRows)
            elseif setupData.classSkillLineIds then
                local skillLines = resolveClassSkillLines(setupData.classSkillLineIds)
                if #skillLines > 0 then
                    local skillParts = {}
                    for _, sl in ipairs(skillLines) do
                        local part = sl.icon ~= "" and inlineIcon(sl.icon) .. sl.name or sl.name
                        skillParts[#skillParts + 1] = part
                    end
                    charRows[#charRows + 1] = col:PlainTextRow(table.concat(skillParts, "  "), ZO_HIGHLIGHT_TEXT)
                end
            end
        end

        -- Food
        if not setupData.isVengeance and setupData.foods and #setupData.foods > 0 then
            for _, food in ipairs(setupData.foods) do
                local name, icon = resolveFoodDisplay(food)
                if name ~= "" then
                    local line = icon ~= "" and inlineIcon(icon) .. name or name

                    charRows[#charRows + 1] = col:PlainTextRow(line, ZO_HIGHLIGHT_TEXT)
                end
            end
        end

        if #charRows == 0 then return nil end
        return col:Section(GetString(BATTLESCROLLS_SETUP_CHARACTER), charRows)
    end

    ---Collects scribed abilities from both bars (deduplicated).
    ---@param abilities PlayerSetupAbilities
    ---@return { abilityId: number, scripts: string }[]
    local function collectScribedAbilities(abilities)
        local result = {}
        local seen = {}
        for _, bar in ipairs({ abilities.front, abilities.back }) do
            for _, ability in ipairs(bar) do
                if ability.craftedAbilityId and ability.scriptIds
                    and not seen[ability.abilityId] then
                    seen[ability.abilityId] = true
                    local scriptNames = {}
                    for _, scriptId in ipairs(ability.scriptIds) do
                        if scriptId > 0 then
                            scriptNames[#scriptNames + 1] = zo_strformat("<<1>>", GetCraftedAbilityScriptDisplayName(scriptId))
                        end
                    end
                    if #scriptNames > 0 then
                        result[#result + 1] = {
                            abilityId = ability.abilityId,
                            scripts = table.concat(scriptNames, ", "),
                        }
                    end
                end
            end
        end
        return result
    end

    ---Resolves champion data into structured discipline groups with names and icons.
    ---@param champion PlayerSetupChampionSkill[]
    ---@return { name: string, icon: string, skills: { name: string, icon: string }[] }[], number[] disciplineOrder
    local function resolveChampionDisciplines(champion)
        local disciplines, disciplineOrder = groupChampionByDiscipline(champion)

        local resolved = {}
        for _, disciplineId in ipairs(disciplineOrder) do
            local skills = disciplines[disciplineId]
            local disciplineType = GetChampionDisciplineType(disciplineId)
            local disciplineIcon = journal.ChampionDisciplineIcons[disciplineType]
            local disciplineName = ZO_CachedStrFormat(
                SI_CHAMPION_CONSTELLATION_NAME_FORMAT,
                GetChampionDisciplineName(disciplineId))

            local skillList = {}
            for _, skill in ipairs(skills) do
                local name = GetChampionSkillName(skill.skillId)
                if name and name ~= "" then
                    name = ZO_CachedStrFormat(SI_CHAMPION_STAR_NAME, name)
                    skillList[#skillList + 1] = { name = name, icon = disciplineIcon }
                end
            end
            resolved[#resolved + 1] = { name = disciplineName, icon = disciplineIcon, skills = skillList }
        end
        return resolved, disciplineOrder
    end

    -------------------------
    -- Icon Helpers

    ---Gets generic weapon type icon(s) for a bar.
    -------------------------
    -- Armor Weight Helpers (used by overview panel)

    ---Formats armor weight counts with localized names (e.g. "5 Light / 1 Medium / 1 Heavy")
    ---@param light number
    ---@param medium number
    ---@param heavy number
    ---@return string
    local function formatArmorWeights(light, medium, heavy)
        local parts = {}
        if light > 0 then table.insert(parts, string.format("%d %s", light, zo_strformat("<<1>>", GetString("SI_ARMORTYPE", ARMORTYPE_LIGHT)))) end
        if medium > 0 then table.insert(parts, string.format("%d %s", medium, zo_strformat("<<1>>", GetString("SI_ARMORTYPE", ARMORTYPE_MEDIUM)))) end
        if heavy > 0 then table.insert(parts, string.format("%d %s", heavy, zo_strformat("<<1>>", GetString("SI_ARMORTYPE", ARMORTYPE_HEAVY)))) end
        if #parts == 0 then
            return ""
        end
        return table.concat(parts, " / ")
    end

    -------------------------
    -- Trait Helpers (used by overview panel)

    -- Enchant Helpers (used by overview panel)

    -- Off-hand slot indices
    local FRONT_OFF_HAND_INDEX = 6
    local BACK_OFF_HAND_INDEX = 14

    ---Checks if a bar is dual-wield (main hand is not 2H and off-hand has a weapon)
    ---@param equipSlots (string|false)[]
    ---@param mainIdx number Main hand slot index
    ---@param offIdx number Off-hand slot index
    ---@return boolean
    local function isDualWield(equipSlots, mainIdx, offIdx)
        local mainLink = equipSlots[mainIdx]
        if mainLink and TWO_HANDED_TYPES[GetItemLinkWeaponType(mainLink)] then return false end
        local offLink = equipSlots[offIdx]
        return offLink and offLink ~= "" and true or false
    end

    ---Joins main + off values with " + " for DW, combining duplicates as "2x Name"
    ---@param main string
    ---@param off string
    ---@return string
    local function joinBarWeapons(main, off)
        if off ~= "" then
            if main == off then
                return "2x " .. main
            end
            return main .. " + " .. off
        end
        return main
    end

    ---Extracts a property from a weapon slot link
    ---@param link string|false
    ---@param extractor fun(link: string): string
    ---@return string
    local function extractWeaponProp(link, extractor)
        if link then return extractor(link) end
        return ""
    end

    ---Gets enchant names for front and back weapon slots, including off-hand for DW
    ---@param equipSlots (string|false)[]
    ---@return string frontEnchant, string backEnchant
    local function getWeaponEnchants(equipSlots)
        local frontMain = extractWeaponProp(equipSlots[FRONT_MAIN_HAND_INDEX], getEnchantName)
        local backMain = extractWeaponProp(equipSlots[BACK_MAIN_HAND_INDEX], getEnchantName)

        local front = frontMain
        if isDualWield(equipSlots, FRONT_MAIN_HAND_INDEX, FRONT_OFF_HAND_INDEX) then
            front = joinBarWeapons(front, extractWeaponProp(equipSlots[FRONT_OFF_HAND_INDEX], getEnchantName))
        end
        local back = backMain
        if isDualWield(equipSlots, BACK_MAIN_HAND_INDEX, BACK_OFF_HAND_INDEX) then
            back = joinBarWeapons(back, extractWeaponProp(equipSlots[BACK_OFF_HAND_INDEX], getEnchantName))
        end

        return front, back
    end

    ---Gets trait name from item link
    ---@param link string
    ---@return string
    local function getTraitName(link)
        local trait = GetItemLinkTraitType(link)
        if trait and trait > 0 then
            return zo_strformat("<<1>>", GetString("SI_ITEMTRAITTYPE", trait))
        end
        return ""
    end

    ---Gets trait names for front and back weapon slots, including off-hand for DW
    ---@param equipSlots (string|false)[]
    ---@return string frontTrait, string backTrait
    local function getWeaponTraitsByBar(equipSlots)
        local frontMain = extractWeaponProp(equipSlots[FRONT_MAIN_HAND_INDEX], getTraitName)
        local backMain = extractWeaponProp(equipSlots[BACK_MAIN_HAND_INDEX], getTraitName)

        local front = frontMain
        if isDualWield(equipSlots, FRONT_MAIN_HAND_INDEX, FRONT_OFF_HAND_INDEX) then
            front = joinBarWeapons(front, extractWeaponProp(equipSlots[FRONT_OFF_HAND_INDEX], getTraitName))
        end
        local back = backMain
        if isDualWield(equipSlots, BACK_MAIN_HAND_INDEX, BACK_OFF_HAND_INDEX) then
            back = joinBarWeapons(back, extractWeaponProp(equipSlots[BACK_OFF_HAND_INDEX], getTraitName))
        end

        return front, back
    end

    -------------------------
    -- Weapon Type Helpers (used by overview panel)

    ---Gets a readable weapon type name
    ---@param weaponType number WEAPONTYPE_* constant
    ---@return string
    local function getWeaponTypeName(weaponType)
        if weaponType == 0 then return "" end
        local customName = TWO_HANDED_WEAPON_NAMES[weaponType]
        local raw = customName and GetString(customName) or GetString("SI_WEAPONTYPE", weaponType)
        return zo_strformat("<<1>>", raw)
    end

    ---Gets readable weapon type names from fixed front/back MH/OH weapon type IDs.
    ---@param weaponTypes number[]|nil {frontMH, frontOH, backMH, backOH}
    ---@param frontBarDisabled boolean|nil
    ---@param backBarDisabled boolean|nil
    ---@return string frontWeapon, string backWeapon
    local function getWeaponTypesFromIds(weaponTypes, frontBarDisabled, backBarDisabled)
        local disabledText = zo_strformat("<<1>>", GetString(SI_CHECK_BUTTON_DISABLED))
        local emptyText = zo_strformat("<<1>>", GetString(SI_WEAPONCONFIGTYPE11))

        local function barWeaponName(mainType, offType, disabled)
            if disabled then return disabledText end
            mainType = mainType or 0
            offType = offType or 0
            if mainType <= 0 then
                if offType > 0 then
                    return getWeaponTypeName(offType)
                end
                return emptyText
            end

            local main = getWeaponTypeName(mainType)
            if not TWO_HANDED_TYPES[mainType] and offType > 0 then
                local off = getWeaponTypeName(offType)
                if off ~= "" then
                    return joinBarWeapons(main, off)
                end
            end
            return main
        end

        return barWeaponName(weaponTypes and weaponTypes[1], weaponTypes and weaponTypes[2], frontBarDisabled),
            barWeaponName(weaponTypes and weaponTypes[3], weaponTypes and weaponTypes[4], backBarDisabled)
    end

    ---Gets a readable weapon type name from both bars.
    ---Returns localized "Disabled" for a bar that is disabled (bar swap locked).
    ---@param setupData PlayerSetup
    ---@return string frontWeapon, string backWeapon
    local function getWeaponTypes(setupData)
        if setupData.weaponTypes then
            return getWeaponTypesFromIds(setupData.weaponTypes, setupData.frontBarDisabled, setupData.backBarDisabled)
        end

        local equipSlots = setupData.equipSlots
        local disabledText = zo_strformat("<<1>>", GetString(SI_CHECK_BUTTON_DISABLED))

        local function weaponName(slotIdx)
            local link = equipSlots[slotIdx]
            if link then
                local wt = GetItemLinkWeaponType(link)
                if wt > 0 then return getWeaponTypeName(wt) end
            end
            return zo_strformat("<<1>>", GetString(SI_WEAPONCONFIGTYPE11))
        end

        local front
        if setupData.frontBarDisabled then
            front = disabledText
        else
            front = weaponName(FRONT_MAIN_HAND_INDEX)
            if isDualWield(equipSlots, FRONT_MAIN_HAND_INDEX, FRONT_OFF_HAND_INDEX) then
                front = joinBarWeapons(front, weaponName(FRONT_OFF_HAND_INDEX))
            end
        end

        local back
        if setupData.backBarDisabled then
            back = disabledText
        else
            back = weaponName(BACK_MAIN_HAND_INDEX)
            if isDualWield(equipSlots, BACK_MAIN_HAND_INDEX, BACK_OFF_HAND_INDEX) then
                back = joinBarWeapons(back, weaponName(BACK_OFF_HAND_INDEX))
            end
        end

        return front, back
    end

    ---Builds ability bar rows: SideBySideBars + scribed ability details + optional werewolf bar.
    ---@param col ColumnBuilder
    ---@param setupData PlayerSetup

    ---@return Control[]|nil rows Nil if no abilities
    local function buildAbilityRows(col, setupData)
        if not setupData.abilities then return nil end

        local hasWerewolf = setupData.werewolfAbilities ~= nil

        local rows = {}

        -- When transformed, the Werewolf bar is the only active bar.
        if not setupData.werewolfTransformed then
            if #setupData.abilities.front == 0 and #setupData.abilities.back == 0 then return nil end

            rows[#rows + 1] = col:SideBySideBars(
                setupData.abilities.front, setupData.abilities.back,
                GetString(BATTLESCROLLS_SETUP_FRONT_BAR), GetString(BATTLESCROLLS_SETUP_BACK_BAR))

            local allAbilities = collectScribedAbilities(setupData.abilities)
            for _, scribed in ipairs(allAbilities) do
                local icon = journal.utils.getAbilityIcon(scribed.abilityId)
                local name = BattleScrolls.utils.GetScribeAwareAbilityDisplayName(scribed.abilityId)
                local text = ZO_SELECTED_TEXT:Colorize(name) .. ": " .. scribed.scripts
                local row = col:IconTextRow(icon, text, ZO_NORMAL_TEXT)
                row._topGap = 3
                rows[#rows + 1] = row
            end
        end

        -- Werewolf bar (shown below front/back, or alone if normal bars hidden)
        if hasWerewolf then
            local wwRow = col:LabeledBar(setupData.werewolfAbilities, GetString(SI_HOTBARCATEGORY8))
            if #rows > 0 then
                wwRow._topGap = 6
            end
            rows[#rows + 1] = wwRow
        end

        if #rows == 0 then return nil end
        return rows
    end

    ---Builds a 2-column Vengeance perks section.
    ---@param col ColumnBuilder
    ---@param perkDefIds number[]|nil
    ---@return Control|nil section
    local function buildVengeancePerksSection2Col(col, perkDefIds)
        local slots = resolveVengeancePerkSlots(perkDefIds)
        local perks = {}
        for _, slot in ipairs(slots) do
            if slot.name ~= "" then
                perks[#perks + 1] = slot
            end
        end
        if #perks == 0 then return nil end

        local rows = {}
        local i = 1
        while i <= #perks do
            rows[#rows + 1] = col:VengeancePerkRow2Col(perks[i], perks[i + 1])
            i = i + 2
        end

        return col:Section(GetString(BATTLESCROLLS_SETUP_PERKS), rows)
    end

    -------------------------
    -- Public API: Overview Panel

    local SECTION_GAP = journal.SECTION_GAP
    local Q3_INSET = journal.Q3_INSET

    ---Formats a front/back pair. When only one is present, appends "(Front Bar)"/"(Back Bar)".
    ---@param front string
    ---@param back string
    ---@return string
    local function formatFrontBack(front, back)
        if front ~= "" and back ~= "" then
            return front .. " / " .. back
        elseif front ~= "" then
            return string.format("%s (%s)", front, GetString(BATTLESCROLLS_SETUP_FRONT_BAR))
        elseif back ~= "" then
            return string.format("%s (%s)", back, GetString(BATTLESCROLLS_SETUP_BACK_BAR))
        end
        return ""
    end

    ---@class EquipmentCategoryDef
    ---@field category number Visual category enum (EQUIP_SLOT_VISUAL_CATEGORY_*)
    ---@field traitFn fun(): string
    ---@field enchantFn fun(): string
    ---@field typeFn (fun(): string)?
    ---@field weightFn (fun(): string)?

    ---Renders equipment categories from a category definition array into q3Sections.
    ---Each catDef provides closures for type/weight/trait/enchant strings; the loop
    ---handles SubHeader + indented detail rows with consistent color coding.
    ---@param col ColumnBuilder
    ---@param catDefs EquipmentCategoryDef[]
    ---@param q3Sections table
    local function renderEquipmentCategories(col, catDefs, q3Sections)
        for _, catDef in ipairs(catDefs) do
            local typeStr = catDef.typeFn and catDef.typeFn() or ""
            local weightStr = catDef.weightFn and catDef.weightFn() or ""
            local traitStr = catDef.traitFn()
            local enchantStr = catDef.enchantFn()

            if typeStr ~= "" or weightStr ~= "" or traitStr ~= "" or enchantStr ~= "" then
                local categoryName = zo_strformat("<<C:1>>",
                    GetString("SI_EQUIPSLOTVISUALCATEGORY", catDef.category))
                q3Sections[#q3Sections + 1] = col:SubHeader(categoryName)

                if typeStr ~= "" then
                    local row = col:PlainTextRow(typeStr, ZO_SELECTED_TEXT, Q3_INDENT)
                    row._topGap = 3
                    q3Sections[#q3Sections + 1] = row
                end
                if weightStr ~= "" then
                    local row = col:PlainTextRow(weightStr, ZO_SELECTED_TEXT, Q3_INDENT)
                    row._topGap = 3
                    q3Sections[#q3Sections + 1] = row
                end
                if traitStr ~= "" then
                    local row = col:PlainTextRow(traitStr, ZO_HIGHLIGHT_TEXT, Q3_INDENT)
                    row._topGap = 3
                    q3Sections[#q3Sections + 1] = row
                end
                if enchantStr ~= "" then
                    local row = col:PlainTextRow(enchantStr, ZO_NORMAL_TEXT, Q3_INDENT)
                    row._topGap = 3
                    q3Sections[#q3Sections + 1] = row
                end
            end
        end
    end

    ---Builds a PanelSpec for the Setup tab (2-column layout).
    ---Q2 (left, 700px): Character info + Abilities + Champion
    ---Q3 (right, expanded): Gear sets, Equipment summary, Poisons

    ---@return PanelSpec
    function setup.buildSetupPanelSpec(setupData)
        return {
            build = function(q2, q3)
                if not setupData then return end

                -- Row color scheme: types (bright) -> traits (standard)
                -- Enchant color (ZO_NORMAL_TEXT) is handled by renderEquipmentCategories
                local COLOR_TYPE = ZO_SELECTED_TEXT
                local COLOR_TRAIT = ZO_HIGHLIGHT_TEXT

                local col2 = q2

                -------------------------
                -- Q2: Character Info
                -------------------------
                local charSection = buildCharacterSection(col2, setupData)

                -------------------------
                -- Q2: Abilities (side by side) + scribing
                -------------------------
                local abilityItems = buildAbilityRows(col2, setupData) or {}

                -------------------------
                -- Q2: Champion Stars / Vengeance perks (2-column layout)
                -------------------------
                local championSection
                if setupData.isVengeance then
                    championSection = buildVengeancePerksSection2Col(col2, setupData.vengeancePerkDefIds)
                elseif setupData.champion and #setupData.champion > 0 then
                    local champRows = {}
                    local resolvedDisciplines = resolveChampionDisciplines(setupData.champion)

                    for _, disc in ipairs(resolvedDisciplines) do
                        champRows[#champRows + 1] = col2:SubHeader(disc.name)

                        local i = 1
                        while i <= #disc.skills do
                            local left = disc.skills[i]
                            local right = disc.skills[i + 1]
                            if left then
                                champRows[#champRows + 1] = col2:ChampionRow2Col(
                                    left.name, left.icon,
                                    right and right.name or nil, right and right.icon or nil)
                            end
                            i = i + 2
                        end
                    end

                    championSection = col2:Section(GetString(SI_MAIN_MENU_CHAMPION), champRows)
                end

                col2:mount(SECTION_GAP, 0, charSection, abilityItems, championSection)

                return function()
                    -------------------------
                    -- Q3: Gear Sets + Equipment by Category + Poisons
                    -------------------------
                    if setupData.equipSlots then
                        local col3 = q3
                        local q3Sections = {}

                        local setLines = setupData.isVengeance and {} or formatActiveSets(setupData.equipSlots)

                        if #setLines > 0 then
                            local setRows = {}
                            for _, line in ipairs(setLines) do
                                setRows[#setRows + 1] = col3:PlainTextRow(line, COLOR_TRAIT)
                            end
                            q3Sections[#q3Sections + 1] = col3:Section(GetString(BATTLESCROLLS_SETUP_GEAR_SETS), setRows)
                        end

                        -------------------------
                        -- Q3: Equipment by Category
                        -------------------------
                        if setupData.isVengeance then
                            renderEquipmentCategories(col3, {
                                {
                                    category = EQUIP_SLOT_VISUAL_CATEGORY_WEAPONS,
                                    traitFn = function() return "" end,
                                    enchantFn = function() return "" end,
                                    typeFn = function()
                                        local fw, bw = getWeaponTypes(setupData)
                                        return formatFrontBack(fw, bw)
                                    end,
                                },
                            }, q3Sections)
                        else
                            renderEquipmentCategories(col3, {
                                {
                                    category = EQUIP_SLOT_VISUAL_CATEGORY_APPAREL,
                                    traitFn = function() return groupTraits(setupData.equipSlots, ARMOR_SLOT_INDICES) end,
                                    enchantFn = function() return groupEnchants(setupData.equipSlots, ARMOR_SLOT_INDICES) end,
                                    weightFn = function()
                                        local light, medium, heavy = countArmorWeights(setupData.equipSlots)
                                        return formatArmorWeights(light, medium, heavy)
                                    end,
                                },
                                {
                                    category = EQUIP_SLOT_VISUAL_CATEGORY_ACCESSORIES,
                                    traitFn = function() return groupTraits(setupData.equipSlots, JEWELRY_SLOT_INDICES) end,
                                    enchantFn = function() return groupEnchants(setupData.equipSlots, JEWELRY_SLOT_INDICES) end,
                                },
                                {
                                    category = EQUIP_SLOT_VISUAL_CATEGORY_WEAPONS,
                                    traitFn = function()
                                        local ft, bt = getWeaponTraitsByBar(setupData.equipSlots)
                                        return formatFrontBack(ft, bt)
                                    end,
                                    enchantFn = function()
                                        local fe, be = getWeaponEnchants(setupData.equipSlots)
                                        return formatFrontBack(fe, be)
                                    end,
                                    typeFn = function()
                                        local fw, bw = getWeaponTypes(setupData)
                                        return formatFrontBack(fw, bw)
                                    end,
                                },
                            }, q3Sections)
                        end

                        -- Poisons
                        if not setupData.isVengeance and (setupData.frontPoison or setupData.backPoison) then
                            local poisonRows = {}
                            poisonRows[#poisonRows + 1] = col3:SubHeader(GetString(BATTLESCROLLS_SETUP_POISONS))
                            local frontPoisonName = setupData.frontPoison
                                and (getPoisonDisplay(setupData.frontPoison.itemLink)) or ""
                            local backPoisonName = setupData.backPoison
                                and (getPoisonDisplay(setupData.backPoison.itemLink)) or ""
                            local poisonStr = formatFrontBack(frontPoisonName, backPoisonName)
                            if poisonStr ~= "" then
                                local row = col3:PlainTextRow(poisonStr, COLOR_TYPE, Q3_INDENT)
                                row._topGap = 3
                                poisonRows[#poisonRows + 1] = row
                            end
                            for _, row in ipairs(poisonRows) do
                                q3Sections[#q3Sections + 1] = row
                            end
                        end

                        col3:mount(SECTION_GAP, Q3_INSET, q3Sections)
                    end
                end
            end,
        }
    end
end

-- Build pane and XML initialization
do
    local OverviewPanel = ZO_InitializingObject:Subclass()

    function OverviewPanel:Initialize(control)
        self.control = control
        self.left = control:GetNamedChild("Q2Container")
        self.right = control:GetNamedChild("Q3Container")
        self.loading = control:GetNamedChild("LoadingLabel")
        self.loading:SetText(GetString(BATTLESCROLLS_LIST_LOADING))
        for _, container in ipairs({ self.left, self.right }) do
            local indicator = container:GetNamedChild("ScrollIndicator")
            if indicator then ZO_Scroll_Gamepad_SetScrollIndicatorSide(indicator, control, RIGHT) end
        end
        self.q2ScrollChild = self.left:GetNamedChild("ScrollChild")
        self.q3ScrollChild = self.right:GetNamedChild("ScrollChild")
        self.cf = BattleScrolls.journal.ComponentFactory.new()
        self.cf:Initialize(self)
    end

    function OverviewPanel:Clear()
        self.cf:ReleaseAll()
        self.left:ResetToTop()
        self.right:ResetToTop()
    end

    function OverviewPanel:Show()
        self.control:SetHidden(false)
    end

    function OverviewPanel:Hide()
        self.renderToken = nil
        self.loading:SetHidden(true)
        self.control:SetHidden(true)
    end

    function OverviewPanel:Render(spec)
        self:Clear()
        self.loading:SetHidden(false)
        self.left:SetHidden(true)
        self.right:SetHidden(true)
        local token = {}
        self.renderToken = token

        -- Yield between columns so the loading state can draw and closing the page cancels any queued work.
        zo_callLater(function()
            if self.renderToken ~= token then return end
            local makeRight = spec.build(
                self.cf:column(self.q2ScrollChild),
                self.cf:column(self.q3ScrollChild)
            )
            zo_callLater(function()
                if self.renderToken ~= token then return end
                if makeRight then makeRight() end
                self.renderToken = nil
                self.loading:SetHidden(true)
                self.left:SetHidden(false)
                self.right:SetHidden(false)
            end, 1)
        end, 1)
    end

    function BattleScrolls_BuildViewer_OnInitialized(control)
        local pane = control:GetNamedChild("OverviewPane")
        BattleScrolls.buildViewer = { panel = OverviewPanel:New(pane) }
    end
end

-- Character screen integration
do
    local BS_DISPLAY_MODE = 118 -- Custom display mode (ESO uses 1-10)
    local ICON = "EsoUI/Art/TreeIcons/Gamepad/gp_tutorial_idexIcon_combat.dds"

    local characterStats = {}
    BattleScrolls.characterStats = characterStats

    local journal = BattleScrolls.journal

    local setupEntry = nil    ---@type table|nil
    local initialized = false
    local originalParent = nil ---@type Control|nil  -- stashed parent for restore
    local panelShown = false
    local fadeAnimation = nil  ---@type table|nil -- FadeSceneAnimation timeline

    ---Returns the Journal's OverviewPanel (nil if journal not yet initialized).
    ---@return BattleScrolls_Journal_OverviewPanel|nil
    local function getOverviewPanel()
        return BattleScrolls.buildViewer and BattleScrolls.buildViewer.panel or nil
    end

    ---Shows the overview panel in the stats screen by re-parenting to the stats control.
    ---@param statsControl Control The stats screen's top-level control (visible during the scene)
    local function showOverviewPanel(statsControl)
        local panel = getOverviewPanel()
        if not panel then return end
        if panelShown then return end

        local control = panel.control
        if not originalParent then
            originalParent = control:GetParent()
        end
        control:SetParent(statsControl)
        control:SetAlpha(1)

        -- Create fade animation lazily (needs the control to exist)
        if not fadeAnimation then
            fadeAnimation = ANIMATION_MANAGER:CreateTimelineFromVirtual("FadeSceneAnimation", control)
        end

        panelShown = true

        -- Capture current setup and render
        local setupData = BattleScrolls.setupCapture:captureCurrentSetup()
        if not setupData then
            panel:Show()
            return
        end

        local spec = journal.renderers.setup.buildSetupPanelSpec(setupData)
        panel:Show()
        panel:Render(spec)
    end

    ---Hides the overview panel immediately and restores its parent.
    local function hideOverviewPanel()
        if not panelShown then return end
        panelShown = false

        if fadeAnimation then
            fadeAnimation:Stop()
        end

        local panel = getOverviewPanel()
        if not panel then return end

        panel.control:SetAlpha(1)
        panel:Hide()
        panel:Clear()

        if originalParent then
            panel.control:SetParent(originalParent)
            originalParent = nil
        end
    end

    ---Starts fade-out animation on the overview panel (does not hide or clean up).
    local function fadeOutOverviewPanel()
        if panelShown and fadeAnimation then
            fadeAnimation:PlayFromEnd()
        end
    end

    local function createSetupEntry()
        local entry = ZO_GamepadEntryData:New(GetString(BATTLESCROLLS_UI_NAME), ICON)
        entry.displayMode = BS_DISPLAY_MODE
        entry:SetIconTintOnSelection(true)
        entry:SetIconDisabledTintOnSelection(true)
        return entry
    end

    function characterStats:Initialize()
        if initialized then return end
        if not GAMEPAD_STATS then return end
        initialized = true

        setupEntry = createSetupEntry()

        -- Pre-hook Commit on mainList: inject our entry after "Description" (characterEntry)
        -- before the commit runs. This avoids a double-commit which breaks selection state.
        ZO_PreHook(GAMEPAD_STATS.mainList, "Commit", function(list)
            if not GAMEPAD_STATS.characterEntry then return end
            local dataList = list.dataList
            -- Don't inject if already present (guard against nested commits)
            for i = 1, #dataList do
                if dataList[i] == setupEntry then return end
            end
            for i = 1, #dataList do
                if dataList[i] == GAMEPAD_STATS.characterEntry then
                    list:AddEntryAtIndex(i + 1, "ZO_GamepadMenuEntryTemplate", setupEntry)
                    return
                end
            end
        end)

        -- Post-hook UpdateScreenVisibility: handle our custom display mode
        ZO_PostHook(ZO_GamepadStats, "UpdateScreenVisibility", function(stats)
            if stats.displayMode == BS_DISPLAY_MODE then
                -- Hide all stock panels
                stats.characterStatsPanel:SetHidden(true)
                stats.attributesPanel:SetHidden(true)
                stats.characterEffects:SetHidden(true)
                stats.advancedAttributesPanel:SetHidden(true)
                -- Don't show the stats RightPane — we show the Journal's panel instead
                GAMEPAD_STATS_ROOT_SCENE:RemoveFragment(GAMEPAD_NAV_QUADRANT_2_3_BACKGROUND_FRAGMENT)
                GAMEPAD_STATS_ROOT_SCENE:RemoveFragment(GAMEPAD_STATS_CHARACTER_INFO_PANEL_FRAGMENT)
                showOverviewPanel(stats.control)
            else
                hideOverviewPanel()
            end
        end)

        -- Restore panel parent when leaving the stats scene (user may dismiss
        -- without navigating to another entry first)
        GAMEPAD_STATS_ROOT_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_HIDING then
                fadeOutOverviewPanel()
            elseif newState == SCENE_HIDDEN then
                hideOverviewPanel()
            end
        end)
    end
end

-- Addon startup
do
    BattleScrolls.addonName = "BattleScrolls"

    function BattleScrolls.OnAddOnLoaded(_, addonName)
        if addonName ~= BattleScrolls.addonName then return end

        BattleScrolls.characterStats:Initialize()

        EVENT_MANAGER:UnregisterForEvent("BattleScrollsBuildViewer_Main", EVENT_ADD_ON_LOADED)
    end

    EVENT_MANAGER:RegisterForEvent(
        "BattleScrollsBuildViewer_Main",
        EVENT_ADD_ON_LOADED,
        BattleScrolls.OnAddOnLoaded)
end
