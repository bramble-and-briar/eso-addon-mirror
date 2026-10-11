-- Resolve base skill, both morphs, all four ranks, and chained casts from ESO.
-- Explicit auxiliary IDs supplement progression data. Names are display-only.
local CT = CorpseTracker
local ids, thirds = {}, { [123704] = true }
local castIds = {}
local seeds = { skull = 117624, yard = 117850, siphon = 118763,
    skeletal = 118680, bones = 117690 }

local function Add(id, family, morph, rank)
    if not id or id == 0 then return end
    ids[id] = { family = family, morph = morph, rank = rank }
    if rank or id == seeds[family] then castIds[id] = family end
end

-- Rank-IV IDs and auxiliary effects from the client's resolved variants and
-- recorded tests. Only actual cast IDs belong in the cast registry.
local explicitCasts = {
    skull = {114108,117624,117637}, yard = {115252,117805,117850},
    siphon = {115924,118008,118763}, skeletal = {114317,118680,118726},
    bones = {114860,117330,117690,117693,117749,117773},
}
local auxiliary = {
    skull = {117629,123683,123685,123699,123704,123718,123719,220102},
    yard = {117852,117853,117854,117855,117860},
    siphon = {118764,124003,123088}, skeletal = {118681,122377},
    bones = {117691,117692,117715},
}

function CT.DiscoverAbilities()
    ids, thirds = {}, { [123704] = true }
    castIds = {}
    CT.variants = {}
    for family, list in pairs(explicitCasts) do
        for _, id in ipairs(list) do Add(id, family); castIds[id] = family end
    end
    for family, list in pairs(auxiliary) do
        for _, id in ipairs(list) do Add(id, family) end
    end
    local slots = { MORPH_SLOT_BASE, MORPH_SLOT_MORPH_1, MORPH_SLOT_MORPH_2 }
    for family, seed in pairs(seeds) do
        Add(seed, family)
        local skillType, line, skill = GetSpecificSkillAbilityKeysByAbilityId(seed)
        if skillType and line and skill then
            local progression = GetProgressionSkillProgressionId(skillType, line, skill)
            local chains, thirdIndex, venomSlot = {}
            for morph = 0, 2 do
                for rank = 1, 4 do
                    local id = GetSpecificSkillAbilityInfo(skillType, line, skill, morph, rank)
                    Add(id, family, morph, rank)
                end
                chains[morph + 1] = { GetProgressionSkillMorphSlotChainedAbilityIds(progression, slots[morph + 1]) }
                for index, id in ipairs(chains[morph + 1]) do
                    Add(id, family, morph, nil)
                    -- Anchor the enhanced cast using Venom Skull observed in the log.
                    -- Do not assume a chain order when the anchor is absent.
                    if family == "skull" and id == 123704 then
                        thirdIndex, venomSlot = index, morph
                    end
                end
            end
            if family == "skull" and thirdIndex then
                for _, chain in ipairs(chains) do
                    if #chain == #chains[venomSlot + 1] and chain[thirdIndex] then
                        thirds[chain[thirdIndex]] = true
                    end
                end
            end
        end
    end
    for id, data in pairs(ids) do
        CT.variants[#CT.variants + 1] = { ability = id, name = GetAbilityName(id),
            family = data.family, morph = data.morph, rank = data.rank,
            third = thirds[id] == true }
    end
    table.sort(CT.variants, function(a,b) return a.ability < b.ability end)
end

function CT.AbilityFamily(id)
    return ids[id] and ids[id].family
end

function CT.IsThirdSkull(id) return thirds[id] == true end

-- Auxiliary effects such as 123088 never identify a corpse application.
function CT.IsSiphonApplication(id) return castIds[id] == "siphon" end

function CT.IsYardActivation(id)
    return castIds[id] == "yard" or id == 117852
end
