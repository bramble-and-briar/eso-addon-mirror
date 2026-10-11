-- Reads a master writ's requirements from its item link. The link carries every requirement as a number,
-- so nothing depends on the tooltip text or the game language.
--
-- Link data fields after the item ID (see Util.ParseWritLink), by writ type:
--   Smithing:     1 item template, 2 material, 3 quality, 4 set ID, 5 trait type, 6 style ID
--   Enchanting:   1 glyph item ID, 2 level (207 = CP150, 225 = CP160), 3 quality
--   Alchemy:      1 base (199 = potion, 239 = poison), 2 to 4 the three required effects
--   Provisioning: 1 item ID of the dish

local addon = CanCraftMasterWrit
local Data = addon.Data
local Util = addon.Util
local WritParser = {}
addon.WritParser = WritParser

local writTypesByName = {}

function WritParser.Initialize()
    for _, sample in ipairs(Data.SAMPLE_WRITS) do
        local name = GetItemLinkName(Util.ItemLink(sample.itemId))
        if name ~= "" then
            writTypesByName[name] = sample
        end
    end
end

function WritParser.IsMasterWrit(itemLink)
    return type(itemLink) == "string" and itemLink ~= "" and GetItemLinkItemType(itemLink) == ITEMTYPE_MASTER_WRIT
end

-- Works out the writ type from the link's numbers, for writs whose name isn't in Data.SAMPLE_WRITS.
local function GuessWritType(fields)
    if GetRecipeInfoFromItemId(fields[1]) then
        return { kind = Data.KIND_PROVISIONING, craftType = CRAFTING_TYPE_PROVISIONING }
    elseif fields[1] == Data.ALCHEMY_POTION_BASE or fields[1] == Data.ALCHEMY_POISON_BASE then
        return { kind = Data.KIND_ALCHEMY, craftType = CRAFTING_TYPE_ALCHEMY }
    elseif Data.GLYPH_LEVEL_TO_CHAMPION_POINTS[fields[2]] then
        return { kind = Data.KIND_ENCHANTING, craftType = CRAFTING_TYPE_ENCHANTING }
    end
    return nil
end

-- Returns a table describing the writ, or nil if the link isn't a master writ.
-- A writ whose type couldn't be worked out has no kind.
function WritParser.Parse(itemLink)
    if not WritParser.IsMasterWrit(itemLink) then
        return nil
    end
    local itemId, fields = Util.ParseWritLink(itemLink)
    if not itemId then
        return nil
    end

    local writ = { link = itemLink, itemId = itemId, fields = fields }
    local writType = writTypesByName[GetItemLinkName(itemLink)] or GuessWritType(fields)
    if not writType then
        return writ
    end
    writ.kind = writType.kind
    writ.craftType = writType.craftType
    writ.event = writType.event

    if writ.kind == Data.KIND_SMITHING then
        writ.templateId = fields[1]
        writ.quality = fields[3]
        writ.setId = fields[4]
        writ.traitType = fields[5]
        writ.styleId = fields[6]
    elseif writ.kind == Data.KIND_ENCHANTING then
        writ.glyphItemId = fields[1]
        writ.championPoints = Data.GLYPH_LEVEL_TO_CHAMPION_POINTS[fields[2]]
        writ.quality = fields[3]
    elseif writ.kind == Data.KIND_ALCHEMY then
        writ.isPoison = fields[1] == Data.ALCHEMY_POISON_BASE
        writ.effects = { fields[2], fields[3], fields[4] }
    elseif writ.kind == Data.KIND_PROVISIONING then
        writ.resultItemId = fields[1]
    end
    return writ
end
