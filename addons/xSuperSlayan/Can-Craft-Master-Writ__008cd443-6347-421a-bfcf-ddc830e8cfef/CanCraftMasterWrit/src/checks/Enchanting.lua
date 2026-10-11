-- Enchanting master writs: one glyph at CP150 or CP160.
-- Works out the potency, essence and aspect runes from LibLazyCrafting's glyph tables (the same data behind
-- its CraftEnchantingGlyphDesiredResult, read directly so nothing is added to its craft queue), then checks
-- the Potency and Aspect Improvement ranks and the runes in stock.

local addon = CanCraftMasterWrit
local Data = addon.Data
local Util = addon.Util
local Result = addon.Result

local Enchanting = {}
addon.checks[Data.KIND_ENCHANTING] = Enchanting

-- Returns the potency, essence and aspect rune item IDs for a glyph, or nil if the glyph isn't known.
function Enchanting.GetRunes(glyphItemId, championPoints, quality)
    local glyphRows = LibLazyCrafting.glyphEssenceIdInfo
    local potencyRows = LibLazyCrafting.enchantPotencyLevelInfo
    if not glyphRows or not potencyRows or not championPoints then
        return nil
    end

    -- Glyph rows: [3] subtractive glyph item ID, [4] additive glyph item ID, [9] essence rune item ID.
    local parity, essenceId
    for _, row in ipairs(glyphRows) do
        if row[3] == glyphItemId then
            parity, essenceId = -1, row[9]
            break
        elseif row[4] == glyphItemId then
            parity, essenceId = 1, row[9]
            break
        end
    end
    if not essenceId then
        return nil
    end

    -- Potency rows: [1] parity, [2] potency rune item ID, cp = champion point level.
    local potencyId
    for _, row in ipairs(potencyRows) do
        if row.cp == championPoints and row[1] == parity then
            potencyId = row[2]
            break
        end
    end

    local aspectId = Data.ASPECT_RUNES[quality]
    if not potencyId or not aspectId then
        return nil
    end
    return potencyId, essenceId, aspectId
end

function Enchanting.Evaluate(writ, result)
    local potencyId, essenceId, aspectId = Enchanting.GetRunes(writ.glyphItemId, writ.championPoints, writ.quality)
    if not potencyId then
        result:Unknown(Result.CATEGORY_RUNES, GetString(SI_CCMW_GLYPH_UNKNOWN))
        return
    end
    local potencyLink = Util.ItemLink(potencyId)
    local essenceLink = Util.ItemLink(essenceId)
    local aspectLink = Util.ItemLink(aspectId)

    local runeNames = { Util.ItemName(potencyLink), Util.ItemName(essenceLink), Util.ItemName(aspectLink) }
    result:Info(Result.CATEGORY_RUNES, GetString(SI_CCMW_RUNES), table.concat(runeNames, " + "))

    result:AddSkills({
        {
            name = Util.LevelPassiveName(CRAFTING_TYPE_ENCHANTING),
            required = GetItemLinkRequiredCraftingSkillRank(potencyLink),
            current = GetNonCombatBonus(NON_COMBAT_BONUS_ENCHANTING_LEVEL),
        },
        {
            name = Util.AbilityName(Data.ASPECT_IMPROVEMENT_PASSIVE, GetString(SI_CCMW_ASPECT_IMPROVEMENT)),
            required = GetItemLinkRequiredCraftingSkillRank(aspectLink),
            current = GetNonCombatBonus(NON_COMBAT_BONUS_ENCHANTING_RARITY_LEVEL),
        },
    })

    result:AddMaterials({
        { link = potencyLink, needed = 1 },
        { link = essenceLink, needed = 1 },
        { link = aspectLink, needed = 1 },
    })
end
