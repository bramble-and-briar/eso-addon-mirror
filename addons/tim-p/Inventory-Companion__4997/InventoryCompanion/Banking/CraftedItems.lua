-- Banking/InventoryCompanion_CraftedItems.lua
InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

this.TargetItems = this.TargetItems or {
    ------------------------------------------------------------------
    -- CLOTHING (Ancestor Silk)
    ------------------------------------------------------------------
    ["Ancestor Silk Breeches"] = true,
    ["Ancestor Silk Epaulets"] = true,
    ["Ancestor Silk Hat"]      = true,
    ["Ancestor Silk Robe"]     = true,
    ["Ancestor Silk Shoes"]    = true,
    ["Ancestor Silk Gloves"]   = true,
    ["Ancestor Silk Sash"]     = true,

    ------------------------------------------------------------------
    -- MEDIUM ARMOR (Rubedo Leather)
    ------------------------------------------------------------------
    ["Rubedo Leather Helmet"]   = true,
    ["Rubedo Leather Jack"]     = true,
    ["Rubedo Leather Boots"]    = true,
    ["Rubedo Leather Bracers"]  = true,
    ["Rubedo Leather Guards"]   = true,
    ["Rubedo Leather Arm Cops"] = true,
    ["Rubedo Leather Belt"]     = true,

    ------------------------------------------------------------------
    -- BLACKSMITHING (Rubedite)
    ------------------------------------------------------------------
    ["Rubedite Helm"]      = true,
    ["Rubedite Cuirass"]   = true,
    ["Rubedite Greaves"]   = true,
    ["Rubedite Gauntlets"] = true,
    ["Rubedite Sabatons"]  = true,
    ["Rubedite Pauldron"]  = true,
    ["Rubedite Girdle"]    = true,

    ["Rubedite Sword"]      = true,
    ["Rubedite Greatsword"] = true,
    ["Rubedite Mace"]       = true,
    ["Rubedite Maul"]       = true,
    ["Rubedite Dagger"]     = true,
    ["Rubedite Battle Axe"] = true,
    ["Rubedite Axe"]        = true,

    ------------------------------------------------------------------
    -- WOODWORKING (Ruby Ash)
    ------------------------------------------------------------------
    ["Ruby Ash Shield"]            = true,
    ["Ruby Ash Bow"]               = true,
    ["Ruby Ash Inferno Staff"]     = true,
    ["Ruby Ash Ice Staff"]         = true,
    ["Ruby Ash Lightning Staff"]   = true,
    ["Ruby Ash Restoration Staff"] = true,

    ------------------------------------------------------------------
    -- JEWELRY (Platinum)
    ------------------------------------------------------------------
    ["Platinum Necklace"] = true,
    ["Platinum Ring"]     = true,

    ------------------------------------------------------------------
    -- GLYPHS (Superb)   
    ------------------------------------------------------------------
    ["Superb Glyph of Stamina"] = false,
    ["Superb Glyph of Health"]  = false,
    ["Superb Glyph of Magicka"] = false,
}