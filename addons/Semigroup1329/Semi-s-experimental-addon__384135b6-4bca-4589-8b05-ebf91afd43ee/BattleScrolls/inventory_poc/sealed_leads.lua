if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocSealedLeads
local leads = {}
BattleScrolls.inventoryPocSealedLeads = leads

-- Sealed item -> antiquity IDs verified against Loot Log 4.10.6.
-- Source and achievement lookup details: docs/inventory-addon/research.md.
local ANTIQUITIES = {
    [226994] = 250, -- Void-Crystal Anomaly
    [227049] = 251, -- Branch of Falinesti
    [227050] = 253, -- Rune-Carved Mammoth Skull
    [227051] = 254, -- Nest of Shadows
    [227052] = 258, -- Sorcerer-King's Blade
    [227053] = 256, -- Remnant of the False Tower
    [227054] = 255, -- Prismatic Sunbird Feather
    [227055] = 264, -- Font of Auri-El
    [227056] = 263, -- Warcaller's Painted Drum
    [227057] = 262, -- Kingmaker's Trove
    [227058] = 269, -- Moons-Blessed Ceremonial Pool
    [227059] = 268, -- St. Nerevar, Moon-and-Star
    [227060] = 266, -- Mnemonic Star-Sphere
    [227061] = 265, -- Echoes of Aldmeris
    [227062] = 274, -- Coil of Satakal
    [227063] = 273, -- Brazier of Frozen Flame
    [227064] = 279, -- St. Alessia, Paravant
    [227065] = 277, -- Golden Idol of Morihaus
    [227066] = 284, -- Moonlight Mirror
    [227067] = 283, -- Cat's Eye Prism
    [227068] = 281, -- Beacon of Tower Zero
    [227069] = 280, -- Blessed Dais of Almalexia
    [227070] = 289, -- Meridian Sconce
    [227071] = 288, -- Stained Glass of Lunar Phases
    [227072] = 287, -- Carved Whale Totem
    [227073] = 295, -- Shrine of Boethra
    [227074] = 302, -- Morwha's Blessing
    [227075] = 308, -- Altar of Celestial Convergence
    [227076] = 307, -- Dwemer Star Chart
    [227077] = 354, -- Vampiric Stained Glass
    [227078] = 376, -- Kothringi Tidal Canoe
    [227079] = 434, -- Dagon's Scalding Gibbet
    [227080] = 511, -- Sea Elf Galleon Helm
    [227081] = 612, -- Umbral Frame
    [227082] = 613, -- Liminal Glass
    [227083] = 614, -- Runic Legs
    [227084] = 652, -- Apocrypha Tentacle Carving
    [227085] = 653, -- Apocrypha Stone Base
    [227086] = 654, -- Hermaeus Mora Eye Engraving
    [227087] = 656, -- Infinite Table of Contents
    [227088] = 655, -- Infinite Tome Cover
    [227089] = 657, -- Infinite Tome Manuscript
    [227090] = 658, -- Archival Light Diffuser, Large
    [227091] = 661, -- Archival Light Diffuser, Small
    [227092] = 662, -- Forged Black Book
    [227093] = 660, -- Petrified Watcher
    [227094] = 659, -- Scrying Brazier, Short
    [227095] = 663, -- Scrying Brazier, Tall
    [227096] = 664, -- Watchful Light
    [227097] = 665, -- Apocrypha Fossil, Ribcage
    [227098] = 666, -- Apocrypha Fossil, Slug
    [227099] = 668, -- Apocrypha Fossil, Tree
    [227100] = 667, -- Apocrypha Fossil, Wall Beast
    [227101] = 767, -- Stone-Nest Gazebo
    [227102] = 768, -- Stone-Nest Pillar, Temple
    [227103] = 779, -- Imperial Titan Slayer
    [227104] = 780, -- Bearer of Fargrave, Broken Skull
    [227105] = 781, -- Valenwood Skull Blocks
    [227106] = 782, -- Bearer of Fargrave, Skeletal Jaw
    [227179] = 249, -- Anvil of Old Orsinium
    [227180] = 433, -- Spell-Scorched Table
    [227181] = 452, -- Daedric Enchanting Apparatus
    [227182] = 453, -- Unhallowed Runic Tome
    [227184] = 537, -- Storm-Weathered Drafting Top
    [227185] = 548, -- Admiral's Carved Trestle Base
    [227186] = 549, -- Tool Grooved Wooden Tray
    [227187] = 647, -- Structural Tentacle Arch
    [227188] = 648, -- Fated Loom Threads
    [227189] = 649, -- Writhing Tendril Harness
    [227190] = 650, -- Carved Mora Treadles
    [227191] = 651, -- Endless Apocryphal Light
    [227192] = 699, -- Heartland Basalt Base
    [227193] = 700, -- Ruin-Carved Smithing Stand
    [227194] = 701, -- Wildsmith Anointing Decoction
    [227195] = 702, -- Dynarian Legacy Bracing
    [227196] = 703, -- Wildsmithed Anvil
    [227197] = 709, -- Perpetual Spinning Wheel
    [227198] = 710, -- Refracting Stone Crucible
    [227199] = 711, -- Vented Potbelly Stove
    [227200] = 712, -- Lapidary Grinding Wheels
    [227201] = 713, -- Tentacled Tool Rack
    [227202] = 714, -- Twisted Shelving Pedestal
    [227203] = 715, -- Entangled Brass Legs
    [227204] = 716, -- Cold Stone Tabletop
    [227205] = 717, -- Ornate Gem Holder
    [227206] = 718, -- Twinned Jade Insets
    [227207] = 759, -- Writhing Wagon Wheel
    [227208] = 760, -- Cultsmith's Water Trough
    [227209] = 761, -- Daedric Anvil
    [227210] = 762, -- Ossified Lantern
    [227211] = 763, -- Worm Cult Wagon Bed
    [227212] = 784, -- Wooden Display Board
    [227213] = 785, -- Surreptitious Cabinet
    [227214] = 786, -- Antique Lockpicking Kit
    [227215] = 787, -- Camouflaged Hood
    [227216] = 788, -- Brigand's Dagger
    [227317] = 804, -- Sea Serpent Skin Scrollcase
    [227318] = 805, -- Coral-Encrusted Cogs
    [227319] = 806, -- Thrassian Compass
    [227320] = 807, -- Pearl-Inlaid Navigation Chart
    [227321] = 808, -- Xirkn-Zel Chamberpot
    [227322] = 809, -- Polwygle Maturation Creche
    [227323] = 810, -- Mixed-Era Coin Cache
    [227324] = 811, -- Louse-Whisperer Ritual Totem
    [227325] = 812, -- Shattered Animunculi Schematic
    [227348] = 813, -- All Flags Navy Astrolabe
}

-- A representative fragment identifies each furnishing assembly.
local ASSEMBLIES = { 433, 537, 612, 647, 652, 655, 699, 709, 759, 784 }
local VERIFIED_ACHIEVEMENTS = { [433] = 3871, [537] = 3872, [699] = 4085, [784] = 4659 }
---@type table<number, number>
local achievements = {}
---@type table<number, boolean>
local assemblies = {}
local prepared, preparing = false, false

---@param name string
---@return string
local function normalizedName(name)
    return (zo_strlower(zo_strformat(SI_TOOLTIP_ITEM_NAME, name)):gsub('|c%x%x%x%x%x%x', ''):gsub('|r', ''))
end

local function prepare()
    if prepared or preparing then return end
    preparing = true
    LibEffect.Async(function()
        LibEffect.Yield():Await()
        ---@type table<string, number>
        local names = {}
        for _, antiquityId in ipairs(ASSEMBLIES) do
            local setId = GetAntiquitySetId(antiquityId)
            if setId > 0 then
                assemblies[setId] = true
                if VERIFIED_ACHIEVEMENTS[antiquityId] then
                    achievements[setId] = VERIFIED_ACHIEVEMENTS[antiquityId]
                else
                    names[normalizedName(GetAntiquitySetName(setId))] = setId
                    local rewardId = GetAntiquitySetRewardId(setId)
                    if rewardId > 0 and GetRewardType(rewardId) == REWARD_ENTRY_TYPE_ITEM then
                        local link = GetItemRewardItemLink(rewardId, 1, 0, LINK_STYLE_DEFAULT)
                        if link ~= '' then names[normalizedName(GetItemLinkName(link))] = setId end
                    end
                end
            end
        end
        names[''] = nil
        local checked = 0
        local function check(category, subcategory, count)
            for index = 1, count do
                local id = GetAchievementId(category, subcategory, index)
                -- Assembly achievements have one completion criterion. Matching
                -- the localized assembly/reward name also covers localized clients.
                if GetAchievementNumCriteria(id) == 1 then
                    local setId = names[normalizedName(GetAchievementName(id))]
                        or names[normalizedName(GetAchievementCriterion(id, 1))]
                    if setId then achievements[setId] = id end
                end
                checked = checked + 1
                if checked % 20 == 0 then LibEffect.Yield():Await() end
            end
        end
        for category = 1, GetNumAchievementCategories() do
            local _, subcategories, count = GetAchievementCategoryInfo(category)
            check(category, nil, count)
            for subcategory = 1, subcategories do
                local _, subcount = GetAchievementSubCategoryInfo(category, subcategory)
                check(category, subcategory, subcount)
            end
        end
        prepared, preparing = true, false
        local poc = BattleScrolls.inventoryPoc
        if poc and poc.enabled then poc.wake() end
    end):Ensure(function() preparing = false end):Run()
end

---@class InventoryPocLeadKeeper
---@field bag number
---@field slot number
---@field uniqueId string
---@type table<number, InventoryPocLeadKeeper>
local keepers = {}

---@param itemId number
---@param keeper InventoryPocLeadKeeper|nil
---@return boolean
local function validKeeper(itemId, keeper)
    return keeper ~= nil and GetItemId(keeper.bag, keeper.slot) == itemId
        and Id64ToString(GetItemUniqueId(keeper.bag, keeper.slot)) == keeper.uniqueId
end

---@param item InventoryPocItem
---@return InventoryPocLeadKeeper
local function keeperFor(item)
    local keeper = keepers[item.itemId]
    local valid = validKeeper(item.itemId, keeper)
    if valid and (keeper.bag ~= BAG_BACKPACK or not IsBankOpen()) then return keeper end
    -- Prefer a banked copy. Retain the selected backpack stack while trader
    -- splitting creates new stacks in lower-numbered slots.
    for _, bag in ipairs({ BAG_BANK, BAG_SUBSCRIBER_BANK }) do
        for slot = 0, GetBagSize(bag) - 1 do
            if GetItemId(bag, slot) == item.itemId then
                keeper = { bag = bag, slot = slot, uniqueId = Id64ToString(GetItemUniqueId(bag, slot)) }
                keepers[item.itemId] = keeper
                return keeper
            end
        end
    end
    if not valid then
        keeper = { bag = item.bag, slot = item.slot, uniqueId = item.uniqueId }
        keepers[item.itemId] = keeper
    end
    return keeper
end

---@param item InventoryPocItem
function leads.apply(item)
    local antiquityId = ANTIQUITIES[item.itemId]
    if item.kind ~= 'sealedContainer' or not antiquityId then return end
    item.kind, item.antiquityId, item.keepQuantity = 'sealedLead', antiquityId, 0
    if DoesAntiquityHaveLead(antiquityId) or GetNumAntiquitiesRecovered(antiquityId) > 0 then return end
    local setId = GetAntiquitySetId(antiquityId)
    if setId == 0 then return end
    prepare()
    local achievementId = achievements[setId]
    if achievementId and IsAchievementComplete(achievementId) then return end
    if prepared and not assemblies[setId] then return end
    -- A known assembly whose translated achievement has not been resolved
    -- retains one copy while its surplus can still be sold.
    local keeper = keeperFor(item)
    if keeper.bag == item.bag and keeper.slot == item.slot and keeper.uniqueId == item.uniqueId then
        item.keepQuantity = 1
    end
end
