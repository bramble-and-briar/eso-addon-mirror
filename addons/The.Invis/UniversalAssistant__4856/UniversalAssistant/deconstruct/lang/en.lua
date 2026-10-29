local moduleStrings = {
    DECONSTRUCT = "Deconstructor",
    DECONSTRUCT_TOOLTIP = "Enables automatic and mass deconstruction of configured items at crafting stations.",
    DECONSTRUCTOR_PANEL = "Universal Assistant Deconstructor",
}

local strings = {

    WEAPON = "Weapons",
    WEAPON_TOOLTIP = "Weapon deconstruction settings.",

    CLOTHING = "Armor",
    CLOTHING_TOOLTIP = "Armor deconstruction settings.",

    JEWELRY = "Jewelry",
    JEWELRY_TOOLTIP = "Jewelry deconstruction settings.",

    ENCHANTING = "Glyphs",
    ENCHANTING_TOOLTIP = "Finished glyph deconstruction settings.",

    QUALITY_NORMAL = "Normal",
    QUALITY_FINE = "Fine",
    QUALITY_SUPERIOR = "Superior",
    QUALITY_EPIC = "Epic",
    QUALITY_LEGENDARY = "Legendary",

    CHAT_NO_ITEMS = "No items match the current filters.",
    CHAT_DECONSTRUCTED_ITEMS = "Items deconstructed: %d.",
    CHAT_OPEN_STATION = "Open a deconstruction station first.",
    CHAT_SLOT_OCCUPIED = "An item is already in the deconstruction slot.",

    CHAT_MESSAGES = "Show chat messages",
    CHAT_MESSAGES_TOOLTIP = "Shows UADeconstructor results and status messages in chat.",

    WEAPON_SETTINGS = {
        ENABLE = "Allow weapon deconstruction",
        ENABLE_TOOLTIP = "Enable weapon deconstruction.",

        MAX_QUALITY = "Maximum weapon quality",
        MAX_QUALITY_TOOLTIP = "Deconstructs weapons of the selected quality and lower.",

        NO_TRAIT = "Deconstruct weapons without a trait",
        NO_TRAIT_TOOLTIP = "Allows weapons without a trait to be deconstructed.",

        CRAFTED = "Deconstruct crafted weapons",
        CRAFTED_TOOLTIP = "Allows player-crafted weapons to be deconstructed.",

        ORNATE = "Deconstruct Ornate weapons",
        ORNATE_TOOLTIP = "Ornate items have increased sell value at NPC merchants. Enable this to deconstruct these weapons instead of keeping them for sale.",

        INTRICATE = "Deconstruct Intricate weapons",
        INTRICATE_TOOLTIP = "Intricate items grant increased Inspiration for the related crafting skill when deconstructed. Enable this to include these weapons.",

        RECONSTRUCTED = "Deconstruct reconstructed weapons",
        RECONSTRUCTED_TOOLTIP = "Allows weapons reconstructed at a transmutation station to be deconstructed.",

        TRADABLE = "Deconstruct temporarily tradable weapons",
        TRADABLE_TOOLTIP = "Allows temporarily group-tradable weapons from dungeons and trials to be deconstructed (blue double-arrow icon).",

        FROM_BANK = "Deconstruct weapons from bank",
        FROM_BANK_TOOLTIP = "Allows deconstruct weapons from bank.",

        NIRNHONED = "Deconstruct Nirnhoned weapons",
        NIRNHONED_TOOLTIP = "Allows weapons with the Nirnhoned trait to be deconstructed. When disabled, research rules cannot deconstruct them.",

        RESEARCH_MODE = "Weapon research deconstruction mode",
        RESEARCH_MODE_TOOLTIP = "Controls how weapons with researchable traits are handled.",

        RESEARCH_NONE = "Do not deconstruct",
        RESEARCH_ALL = "Deconstruct all",
        RESEARCH_KEEP_LOWEST = "Deconstruct except unresearched traits",
        RESEARCH_KEEP_LOWEST_TOOLTIP = "For identical unresearched traits, keeps the lowest-quality weapon and deconstructs higher-quality duplicates.",
    },

    CLOTHING_SETTINGS = {
        ENABLE = "Allow clothing deconstruction",
        ENABLE_TOOLTIP = "Enable clothing deconstruction.",

        MAX_QUALITY = "Maximum clothing quality",
        MAX_QUALITY_TOOLTIP = "Deconstructs clothing of the selected quality and lower.",

        NO_TRAIT = "Deconstruct clothing without a trait",
        NO_TRAIT_TOOLTIP = "Allows clothing without a trait to be deconstructed.",

        CRAFTED = "Deconstruct crafted clothing",
        CRAFTED_TOOLTIP = "Allows player-crafted clothing to be deconstructed.",

        ORNATE = "Deconstruct Ornate clothing",
        ORNATE_TOOLTIP = "Ornate items have increased sell value at NPC merchants. Enable this to deconstruct this armor instead of keeping it for sale.",

        INTRICATE = "Deconstruct Intricate clothing",
        INTRICATE_TOOLTIP = "Intricate items grant increased Inspiration for the related crafting skill when deconstructed. Enable this to include this armor.",

        RECONSTRUCTED = "Deconstruct reconstructed clothing",
        RECONSTRUCTED_TOOLTIP = "Allows clothing reconstructed at a transmutation station to be deconstructed.",

        TRADABLE = "Deconstruct temporarily tradable clothing",
        TRADABLE_TOOLTIP = "Allows temporarily group-tradable clothing from dungeons and trials to be deconstructed (blue double-arrow icon).",

        FROM_BANK = "Deconstruct clothing from bank",
        FROM_BANK_TOOLTIP = "Allows deconstruct clothing from the bank.",

        NIRNHONED = "Deconstruct Nirnhoned clothing",
        NIRNHONED_TOOLTIP = "Allows clothing with the Nirnhoned trait to be deconstructed. When disabled, research rules cannot deconstruct it.",

        RESEARCH_MODE = "Clothing research deconstruction mode",
        RESEARCH_MODE_TOOLTIP = "Controls how clothing with researchable traits is handled.",

        RESEARCH_NONE = "Do not deconstruct",
        RESEARCH_ALL = "Deconstruct all",
        RESEARCH_KEEP_LOWEST = "Deconstruct except unresearched traits",
        RESEARCH_KEEP_LOWEST_TOOLTIP = "For identical unresearched traits, keeps the lowest-quality item and deconstructs higher-quality duplicates.",
    },

    JEWELRY_SETTINGS = {
        ENABLE = "Allow jewelry deconstruction",
        ENABLE_TOOLTIP = "Enable jewelry deconstruction.",

        MAX_QUALITY = "Maximum jewelry quality",
        MAX_QUALITY_TOOLTIP = "Deconstructs jewelry of the selected quality and lower.",

        NO_TRAIT = "Deconstruct jewelry without a trait",
        NO_TRAIT_TOOLTIP = "Allows jewelry without a trait to be deconstructed.",

        CRAFTED = "Deconstruct crafted jewelry",
        CRAFTED_TOOLTIP = "Allows player-crafted jewelry to be deconstructed.",

        ORNATE = "Deconstruct Ornate jewelry",
        ORNATE_TOOLTIP = "Ornate items have increased sell value at NPC merchants. Enable this to deconstruct this jewelry instead of keeping it for sale.",

        INTRICATE = "Deconstruct Intricate jewelry",
        INTRICATE_TOOLTIP = "Intricate items grant increased Jewelry Crafting Inspiration when deconstructed. Enable this to include this jewelry.",

        RECONSTRUCTED = "Deconstruct reconstructed jewelry",
        RECONSTRUCTED_TOOLTIP = "Allows jewelry reconstructed at a transmutation station to be deconstructed.",

        TRADABLE = "Deconstruct temporarily tradable jewelry",
        TRADABLE_TOOLTIP = "Allows temporarily group-tradable jewelry from dungeons and trials to be deconstructed (blue double-arrow icon).",

        FROM_BANK = "Deconstruct jewelry from bank",
        FROM_BANK_TOOLTIP = "Allows deconstruct jewelry from bank.",

        RESEARCH_MODE = "Jewelry research deconstruction mode",
        RESEARCH_MODE_TOOLTIP = "Controls how jewelry with researchable traits is handled.",

        RESEARCH_NONE = "Do not deconstruct",
        RESEARCH_ALL = "Deconstruct all",
        RESEARCH_BASIC = "Deconstruct items with basic traits",
        RESEARCH_KEEP_LOWEST = "Deconstruct except unresearched traits",
        RESEARCH_KEEP_LOWEST_TOOLTIP = "For identical unresearched traits, keeps the lowest-quality item and deconstructs higher-quality duplicates.",
    },

    ENCHANTING_SETTINGS = {
        ENABLE = "Allow glyph deconstruction",
        ENABLE_TOOLTIP = "Enable finished glyph deconstruction.",

        MAX_QUALITY = "Maximum glyph quality",
        MAX_QUALITY_TOOLTIP = "Deconstructs glyphs of the selected quality and lower.",

        CRAFTED = "Deconstruct crafted glyphs",
        CRAFTED_TOOLTIP = "Allows player-crafted glyphs to be deconstructed.",

        FROM_BANK = "Deconstruct glyphs from bank",
        FROM_BANK_TOOLTIP = "Allows deconstruct glyphs from the bank.",
    },
}

local ua = UAssistant
ua.AddLanguageStrings("en", moduleStrings)
ua.AddLanguageStrings("en", strings, "DECONSTRUCT")
