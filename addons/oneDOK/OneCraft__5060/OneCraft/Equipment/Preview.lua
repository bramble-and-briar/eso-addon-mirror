local O, P = OneCraft, OneCraft.Equipment
local cache = {}

-- Link subtype encodes the level tier and quality; traits belong to item IDs.
local function subtype(cp, level, quality)
    if not cp then return (level == 1 and 29 or level == 4 and 24 or 19) + quality, level end
    if level <= 100 then return 114 + quality * 10 + level / 10, 50 end
    if level < 160 then return 217 + 18 * (level - 100) / 10 + quality, 50 end
    return 365 + quality, 50
end

local function link(id, sub, level, style, enchant, enchantSub, enchantLevel)
    return string.format("|H1:item:%d:%d:%d:%d:%d:%d:0:0:0:0:0:0:0:0:0:%d:0:0:0:10000:0|h|h",
        id, sub, level, enchant or 0, enchantSub or 0, enchantLevel or 0, style)
end

local function indexSet(set)
    if cache[set] then return cache[set] end
    local index = {}
    for _, range in ipairs(P.itemRanges[set] or {}) do
        for id = range[1], range[1] + range[2] do
            local value = link(id, 370, 50, 1)
            local _, _, _, _, _, actualSet = GetItemLinkSetInfo(value, false)
            if (actualSet or 0) == set then
                local trait = GetItemLinkTraitInfo(value)
                local key = table.concat({GetItemLinkEquipType(value), GetItemLinkArmorType(value),
                    GetItemLinkWeaponType(value), trait}, ":")
                index[key] = id
            end
        end
    end
    cache[set] = index
    return index
end

function P.PreviewLink(pattern, cp, level, style, trait, station, set, quality, potency, essence, aspect)
    local kind
    for _, candidate in ipairs(P.typeOrder) do
        if candidate.station == station and candidate.pattern == pattern then kind = candidate; break end
    end
    if not kind then return end
    local key = table.concat({kind.equip, kind.weight or ARMORTYPE_NONE, kind.weaponType or WEAPONTYPE_NONE, trait}, ":")
    local id = indexSet(set)[key]
    if not id then return end
    local enchant, enchantSub, enchantLevel
    if potency then
        local glyphTier, effect, glyphQuality
        for _, tier in ipairs(O.Enchanting.levels) do
            if tier.positive == potency or tier.negative == potency then glyphTier = tier; break end
        end
        for _, candidate in ipairs(O.Enchanting.effectList) do
            if candidate.essence == essence and glyphTier and glyphTier[candidate.polarity] == potency then effect = candidate; break end
        end
        for q, rune in ipairs(O.Enchanting.aspects) do if rune == aspect then glyphQuality = q; break end end
        if not glyphTier or not effect or not glyphQuality then return end
        enchant = effect.itemId
        if glyphTier.cp then
            local bases = {[10] = 125, [30] = 127, [50] = 129, [70] = 131, [100] = 272, [150] = 308, [160] = 366}
            enchantSub = bases[glyphTier.cp] + (glyphTier.cp < 100 and (glyphQuality - 1) * 10 or glyphQuality - 1)
            enchantLevel = 50
        else enchantSub, enchantLevel = 19 + glyphQuality, math.floor(glyphTier.level / 5) * 5 + 5 end
    end
    local sub, resultLevel = subtype(cp, level, quality)
    return link(id, sub, resultLevel, style, enchant, enchantSub, enchantLevel)
end
