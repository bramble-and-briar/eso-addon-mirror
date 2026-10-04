if SPT == nil then SPT = {} end

-- Native icon basenames identify scripts independently of the client language.
-- Historical records: MapOfManyRiches c0189c8, build/LibTreasure.data.lua.
-- Map context and pickup positions checked against the corresponding ESO-Hub
-- script map links on 2026-10-03. Do not reuse the old zone/city duplicates.
SPT.ScribingLocations = {
    scribing_primary_physical = { mapId = 243, x = 0.205, y = 0.505,
        directions = "SPT_GUI_PICKUP_PHYSICAL" },
    scribing_primary_stunned = { mapId = 63, x = 0.478, y = 0.397,
        directions = "SPT_GUI_PICKUP_STUN" },
    scribing_primary_damageshield = { mapId = 24, x = 0.514, y = 0.425,
        directions = "SPT_GUI_PICKUP_SHIELD" },
    scribing_secondary_resourcerestore = { mapId = 33, x = 0.577, y = 0.474,
        directions = "SPT_GUI_PICKUP_DRUID" },
    scribing_secondary_opportunism = { mapId = 449, x = 0.406, y = 0.555,
        directions = "SPT_GUI_PICKUP_WARRIOR" },
    scribing_secondary_snare = { mapId = 205, x = 0.379, y = 0.564,
        directions = "SPT_GUI_PICKUP_HUNTER" },
    scribing_tertiary_vulnerability = { mapId = 84, x = 0.656, y = 0.439,
        directions = "SPT_GUI_PICKUP_VULNERABILITY" },
    scribing_tertiary_vitality = { mapId = 312, x = 0.749, y = 0.422,
        directions = "SPT_GUI_PICKUP_VITALITY" },
    scribing_tertiary_maim = { mapId = 198, x = 0.767, y = 0.651,
        directions = "SPT_GUI_PICKUP_MAIM" },
}
