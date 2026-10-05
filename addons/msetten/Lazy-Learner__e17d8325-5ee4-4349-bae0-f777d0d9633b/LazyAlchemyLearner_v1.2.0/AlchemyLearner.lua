LazyLearner.AlchemyLearner = LazyLearner.AlchemyLearner or {}
local Utils = LazyLearner.Utils
local EnchantingLearner = LazyLearner.EnchantingLearner
local AlchemyLearner = LazyLearner.AlchemyLearner


-- rules for negative trait learning:
-- Only if it's a 3 reagent potion, with two matching the positive. Then you learn the negative
-- Both positive traits do not need to be known
-- potion has to be created
local defaultPrices = {
    [77583] = 80 ,
    [30157] = 60,
    [30148] = 30,
    [30160] = 200,
    [77585] = 60, -- Butterfly Wing
    [150669] = 380,
    [139020] = 300, 
    [30164] = 900,
    [30161] = 80,
    [150672] = 125, -- Crimson Nirnroot
    [150789] = 99,
    [150731] = 2300,
    [150671] = 2200, -- Dragon Rheum
    [30162] = 60, -- dragonthorn
    [30151] = 60,
    [77587] = 45,
    [30156] = 60,
    [30158] = 60, -- lady's smock
    [30155] = 70,
    [30163] = 160,
    [77591] = 540,
    [30153] = 50,
    [77590] = 80,
    [30165] = 40, -- Nirnroot
    [139019] = 930,
    [77589] = 250,
    [77584] = 60, -- Spider Egg
    [30149] = 70, -- Stinkhorn
    [77581] = 590, -- Torchbug Thorax
    [150670] = 200,
    [30152] = 450, 
    [30166] = 45, -- water hyacinth
    [30154] = 36,
    [30159] = 52, -- Wormwood
    -- new with update 51 - no idea what the prices will be, so we'll just price it out of algo for now
    [224357] = 5000, -- Cultivated Cryptpot
    [224358] = 5000,
    [224359] = 5000,
    [224360] = 5000,
}

local function populatePrices()
    if LibPrice then
        for k, v in pairs(defaultPrices) do
            local price, source = LibPrice.ItemLinkToPriceGold(Utils.getItemLinkFromItemId(k))
            if source ~= "npc" and price and price>0 then
                defaultPrices[k] = price
            end
        end
    end
end

local function populateExpectedKnownTraits()
    local workingTable = {}
    for k, v in pairs(AlchemyLearner.reagentTraits) do
        workingTable[k] = {}
        for i = 1, 4 do
            workingTable[k][v[i]] = GetItemLinkReagentTraitInfo(Utils.getItemLinkFromItemId(k), i)
        end
    end
    return workingTable
end
-- local expectedKnown

local function doesReagentHaveTrait(itemId, traitName)
    local effects = AlchemyLearner.reagentTraits[itemId]
    for i = 1, 4 do
        if effects[i] == traitName then
            return i
        end
    end
    return nil
    -- GetItemLinkReagentTraitInfo(Utils.getItemLinkFromItemId(reagentItemId1), j)
end

local function doesUserKnowReagentTrait(itemId, traitName)
    local traitIndex = doesReagentHaveTrait(itemId, traitName)
    if not traitIndex then return false end

    return GetItemLinkReagentTraitInfo(Utils.getItemLinkFromItemId(itemId), traitIndex)
end

local function isTraitExpectedKnown(itemId, traitName)
    return expectedKnown[itemId][traitName]
end

local function calcOverlap(r1,r2)
    local reagentItemId1 = r1[1]
    local reagentItemId2 = r2[1]
    local effects = {}
    for i =1, 4 do
        effects[AlchemyLearner.reagentTraits[reagentItemId1][i]] = (effects[AlchemyLearner.reagentTraits[reagentItemId1][i]] or 0 ) + 1
        effects[AlchemyLearner.reagentTraits[reagentItemId2][i]] = (effects[AlchemyLearner.reagentTraits[reagentItemId2][i]] or 0 ) + 1
    end
    for k, v in pairs(effects) do
        if v==1 then
            effects[k] = nil
        end
    end
    local output = {}
    local totalLearnable = 0
    for k , v in pairs(effects) do
        output[#output+1] = k
        if not isTraitExpectedKnown(reagentItemId1, k) then
            totalLearnable = totalLearnable + 1
        end
        if not isTraitExpectedKnown(reagentItemId2, k) then
            totalLearnable = totalLearnable + 1
        end
    end
    return output, totalLearnable
end

local function comboSort(a,b)
    if a.expectedLearnable == b.expectedLearnable then
        return a.price > b.price
    end
    return a.expectedLearnable > b.expectedLearnable
end

-- /script 
function runAlchSearch(useDLC)
    useDLC = (useDLC==nil) and false or useDLC
    local reagentsByEffect = {}
    for itemId, effects in pairs(AlchemyLearner.reagentTraits) do
        if useDLC or not AlchemyLearner.dlcReagents[itemId] then
            for i = 1, 4 do
                local effectName = AlchemyLearner.reagentTraits[itemId][i]
                reagentsByEffect[effectName] = reagentsByEffect[effectName] or {}
                reagentsByEffect[effectName][#reagentsByEffect[effectName]+1] = {itemId, GetItemLinkName(getItemLinkFromItemId(itemId)) , defaultPrices[itemId]}
            end
        end
    end
    local a = reagentsByEffect
    local potionCombos = {}
    for k, v in pairs(a) do
        -- d(" -- "..k.." -- ")
        potionCombos[k] = {}
        for i = 1, #a[k]-1 do
            for j = i+1, #a[k] do
                local learning, totalLearnable = calcOverlap(a[k][i],a[k][j])
                local price = defaultPrices[a[k][i][1]] + defaultPrices[a[k][j][1]]
                -- d("{"..a[k][i][1]..","..a[k][j][1].."} -- "..a[k][i][2].." and "..a[k][j][2].." learning "..table.concat(learning, " and ").." "..price.."g")
                if totalLearnable > 0 then
                    comboTable = {a[k][i], a[k][j], price=price, learning=learning, totalLearnable = totalLearnable, expectedLearnable = totalLearnable}
                    potionCombos[k][#potionCombos[k]+1] = comboTable
                    
                end
            end
        end
    end
    for effect, combos in pairs(potionCombos) do
        if #combos == 0 then
            potionCombos[effect] = nil
        end
    end
    return potionCombos
-- d(a)
end

local function recalculateLearnables(potionCombos, comboToAdd)
    local activeReagents = {[comboToAdd[1]] = true, [comboToAdd[2]] = true, }
    for i = 1, #comboToAdd.learning do
        local effectCombos = potionCombos[comboToAdd.learning[i]]
        if effectCombos then
            for j = #effectCombos, 1, -1 do
                if activeReagents[effectCombos[j][1]] or activeReagents[effectCombos[j][2]] then
                    local learning, newLearnable = calcOverlap(effectCombos[j][1], effectCombos[j][2])
                    effectCombos[j].expectedLearnable = newLearnable
                    if newLearnable == 0 then
                        table.remove(effectCombos, j)
                    end
                end
            end
            table.sort(effectCombos, comboSort)
            if #effectCombos == 0 then
                potionCombos[comboToAdd.learning[i]] = nil
            end
        end
    end
end

local function singlePass(potionCombos)
    local effectName, effectCombos = next(potionCombos)
    table.sort(effectCombos, comboSort)
    local comboToAdd = effectCombos[1]
    for i = 1, #comboToAdd.learning do
        expectedKnown[comboToAdd[1][1]] [comboToAdd.learning[i]] = true
        expectedKnown[comboToAdd[2][1]] [comboToAdd.learning[i]] = true
    end
    table.remove(effectCombos, 1)
    recalculateLearnables(potionCombos, comboToAdd)
    return comboToAdd
end

local function calculateCombos(useDLC)
    populatePrices()
    expectedKnown = populateExpectedKnownTraits()
    local potionCombos = runAlchSearch(useDLC)
    local combosToCraft = {}
    while next(potionCombos) do
        local comboToAdd = singlePass(potionCombos)
        combosToCraft[#combosToCraft+1] = comboToAdd
    end
    return combosToCraft
end


AlchemyLearner.dlcReagents =
{
    [150789] = true,
    [150731] = true,
    [224357] = true,
    [224358] = true,
    [224359] = true,
    [224360] = true,
    [139019] = true,
    [139020] = true,
    [150671] = true,
}

--- List of all solvent IDs in ESO with poisons first and potions second, sorted by required alchemy proficiency
AlchemyLearner.solvents = {
75357, -- Grease 3
75358, -- Ichor 10
75359, -- Slime 20
75360, -- Gall 30
75361, -- Terebinthine 40
75362, -- Pitch-Bile cp10
75363, -- Tarblack cp50
75364, -- Night-Oil cp100
75365, -- Alcahest cp150
883, -- Natural Water 3
1187, -- Clear Water 10
4570, -- Pristine Water 20
23265, -- Cleansed Water 30
23266, -- Filtered Water 40
23267, -- Purified Water cp10
23268, -- Cloud Mist cp50
64500, -- Star Dew cp100
64501 -- Lorkhan's Tears cp150
}

-- a static list of all traits of each reagent, will be used to determine what combos still need to be executed
-- /script for k,v in pairs(reagentInfo) do local l=getItemLinkFromItemId(k)local s="["..k..'] = {' for i = 1, 4 do local _,en=GetItemLinkReagentTraitInfo(l,i) s=s..'"'..en..'", ' end d(s.."}, -- "..GetItemLinkName(l)) end
AlchemyLearner.reagentTraits = {
    [30148] = {"Ravage Magicka", "Heal Absorption", "Restore Health", "Invisible", }, -- blue entoloma
    [150789] = {"Heroism", "Vulnerability", "Invisible", "Vitality", }, -- Dragon's Bile
    [30151] = {"Ravage Health", "Ravage Magicka", "Ravage Stamina", "Entrapment", }, -- emetic russula
    [30152] = {"Breach", "Ravage Health", "Increase Power", "Ravage Magicka", }, -- violet coprinus
    [30153] = {"Enervation", "Speed", "Invisible", "Unstoppable", }, -- namira's rot
    [30154] = {"Enervation", "Ravage Magicka", "Increase Spell Resist", "Detection", }, -- white cap
    [150731] = {"Lingering Health", "Restore Stamina", "Heroism", "Defile", }, -- Dragon's Blood
    [30156] = {"Cowardice", "Ravage Stamina", "Increase Armor", "Enervation", }, -- imp stool
    [77581] = {"Fracture", "Uncertainty", "Detection", "Mending", }, -- Torchbug Thorax
    [150670] = {"Timidity", "Ravage Health", "Restore Magicka", "Protection", }, -- Vile Coagulant
    [77583] = {"Breach", "Increase Armor", "Protection", "Vitality", }, -- Beetle Scuttle
    [150672] = {"Timidity", "Force", "Gradual Ravage Health", "Restore Health", }, -- Crimson Nirnroot
    [77585] = {"Restore Health", "Damage Shield", "Lingering Health", "Vitality", }, -- Butterfly Wing
    [30162] = {"Increase Power", "Restore Stamina", "Fracture", "Critical", }, -- dragonthorn
    [30163] = {"Increase Armor", "Restore Health", "Cowardice", "Restore Stamina", }, -- mountain flower
    [30164] = {"Restore Health", "Restore Magicka", "Restore Stamina", "Unstoppable", }, -- columbine
    [30165] = {"Ravage Health", "Uncertainty", "Invisible", "Heal Absorption", }, -- nirnroot
    [30166] = {"Restore Health", "Critical", "Entrapment", "Damage Shield", }, -- water hyacinth
    [77591] = {"Increase Spell Resist", "Increase Armor", "Protection", "Defile", }, -- Mudcrab Chitin
    [224357] = {"Heroism", "Increase Power", "Mending", "Damage Shield", }, -- Cultivated Cryptpods
    [224358] = {"Defile", "Heal Absorption", "Cowardice", "Entrapment", }, -- Daedra-Blood Maggots
    [224359] = {"Heroism", "Restore Stamina", "Force", "Detection", }, -- Fossilized Verminous Bones
    [224360] = {"Vexation", "Heal Absorption", "Defile", "Breach", }, -- Winter's Grave Tongue
    [150669] = {"Timidity", "Ravage Magicka", "Vexation", "Detection", }, -- Chaurus Egg
    [139019] = {"Mending", "Speed", "Vitality", "Protection", }, -- Powdered Mother of Pearl
    [30159] = {"Critical", "Hindrance", "Detection", "Unstoppable", }, -- wormwood
    [30157] = {"Restore Stamina", "Increase Power", "Heal Absorption", "Speed", }, -- blessed thistle
    [30155] = {"Ravage Stamina", "Restore Health", "Hindrance", "Cowardice", }, -- luminous russula
    [77589] = {"Vexation", "Speed", "Vulnerability", "Lingering Health", }, -- Scrib Jelly
    [77584] = {"Hindrance", "Invisible", "Damage Shield", "Defile", }, -- Spider Egg
    [139020] = {"Increase Spell Resist", "Hindrance", "Vulnerability", "Defile", }, -- Clam Gall
    [30160] = {"Increase Spell Resist", "Restore Health", "Mending", "Restore Magicka", }, -- bugloss
    [150671] = {"Restore Magicka", "Uncertainty", "Heroism", "Speed", }, -- Dragon Rheum
    [77590] = {"Ravage Health", "Protection", "Gradual Ravage Health", "Defile", }, -- Nightshade
    [30161] = {"Restore Magicka", "Increase Power", "Ravage Health", "Detection", }, -- corn flower
    [77587] = {"Ravage Stamina", "Vulnerability", "Gradual Ravage Health", "Vitality", }, -- Fleshfly Larva||Fleshfly Larvae
    [30158] = {"Force", "Restore Magicka", "Breach", "Critical", }, -- lady's smock
    [30149] = {"Fracture", "Ravage Health", "Force", "Ravage Stamina", }, -- stinkhorn
}


-- used to store the calculated amount of inventory of each reagent
AlchemyLearner.reagentAmounts = {}

--- Function to get the best available solvent based on alchemy proficiency and starting position in the solvents list
--- @param proficiency The current alchemy proficiency level of the player
--- @param startingPosition The position in the solvents list to start checking from
--- @return availableAmount The amount of the found solvent
--- @return solvent The item ID of the found solvent
--- @return position The position in the solvents list of the found solvent
function AlchemyLearner.getSolvent(proficiency, startingPosition)
    -- Check solvents
    for i = startingPosition, proficiency + 1 do
        -- poisons
        local availableAmount = Utils.GetNumberOfAvailableItems(AlchemyLearner.solvents[i])
        if (availableAmount > 0) then
            return availableAmount, AlchemyLearner.solvents[i], i
        end

        -- potions
        local availableAmount = Utils.GetNumberOfAvailableItems(AlchemyLearner.solvents[i + 9])
        if (availableAmount > 0) then
            return availableAmount, AlchemyLearner.solvents[i + 9], i
        end
    end

    return nil, nil, nil
end

--- Find the matching traits between two reagents.
--- @param reagent1 The item ID of the first reagent.
--- @param reagent2 The item ID of the second reagent.
--- @return A table containing the matching traits.
function AlchemyLearner.GetMatchingTraits(reagent1, reagent2)
    local traits1 = AlchemyLearner.reagentTraits[reagent1]
    local traits2 = AlchemyLearner.reagentTraits[reagent2]
    local matchingTraits = {}

    -- Compare the traits from both reagents
    for _, trait1 in ipairs(traits1) do
        for _, trait2 in ipairs(traits2) do
            if trait1 == trait2 then
                table.insert(matchingTraits, trait1)
            end
        end
    end
    return matchingTraits
end

--- Queues alchemy items to learn unknown traits.
--- @param combos A table of reagent item ID pairs to process
--- @return The number of items queued.
function AlchemyLearner.alchemyQueuer(combos)
    local LLC = LazyLearner.LLC
    local remainingSolvent = 0
    local solvent
    local position = 1
    local queued = 0
    local missingMaterialReagents = {}

    -- I am adding a solvent check here to see if the player has any solvent at all, no need to process anything if nothing will be queued anyway
    remainingSolvent, solvent, position = AlchemyLearner.getSolvent(GetNonCombatBonus(NON_COMBAT_BONUS_ALCHEMY_LEVEL),
        position)

    if (remainingSolvent == nil) then
        Utils.sendChatMessage(LazyLearner.L("LL_NEED_SOLVENTS"), Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
        return queued
    end
    for i = 1, #combos do
        local known = true

        local reagentItemId1 = combos[i][1][1]
        local reagentItemId2 = combos[i][2][1]

        -- we check what traits between the two reagents are matching
        local theoreticalMatchingTraits = AlchemyLearner.GetMatchingTraits(reagentItemId1, reagentItemId2)
        local amountMatchingReagant1 = 0
        local amountMatchingReagant2 = 0
        for j = 1, 4 do

            --[[
				k = known status of the reagant's trait {true/false}
				n = name of the trait, currently the name wil be nil if the trait is unknown
			--]]
            local k1 = GetItemLinkReagentTraitInfo(Utils.getItemLinkFromItemId(reagentItemId1), j)
            local k2 = GetItemLinkReagentTraitInfo(Utils.getItemLinkFromItemId(reagentItemId2), j)
            local n1 = AlchemyLearner.reagentTraits[reagentItemId1][j]
            local n2 = AlchemyLearner.reagentTraits[reagentItemId2][j]
            -- as a precaution, we'll set the name of the trait to nil if it's not known, since this is the behaviour we expect in the next step
            if not k1 then
                n1 = nil
            end

            if not k2 then
                n2 = nil
            end

            -- we count the amount of known matching traits of each reagant
            if Utils.Contains(theoreticalMatchingTraits, n1) then
                amountMatchingReagant1 = amountMatchingReagant1 + 1
            end

            if Utils.Contains(theoreticalMatchingTraits, n2) then
                amountMatchingReagant2 = amountMatchingReagant2 + 1
            end
        end

        -- if the amount of actual known, matching traits is not the same as the theoretical amount of matching traits known will be false
        known = amountMatchingReagant1 == #theoreticalMatchingTraits and amountMatchingReagant2 ==
                    #theoreticalMatchingTraits

        -- Leaving this here for debug purposes for now
        local reagantName1 = GetItemLinkName(Utils.getItemLinkFromItemId(reagentItemId1))
        local reagantName2 = GetItemLinkName(Utils.getItemLinkFromItemId(reagentItemId2))

        -- if unknown traits detected we will attempt to queue a potion
        if not known then
            local canCraftPotion = true
            -- we check if there are any solvents left of the currently selected solvent, if not we automatically get the next best solvent
            if remainingSolvent and (remainingSolvent == 0) then
                -- decide the solvent we are going to use
                remainingSolvent, solvent, position = AlchemyLearner.getSolvent(GetNonCombatBonus(
                    NON_COMBAT_BONUS_ALCHEMY_LEVEL), position)

                if (remainingSolvent == nil) then
                    missingMaterialReagents["Solvents"] = "Solvents"
                    canCraftPotion = false
                end
            elseif not remainingSolvent then
                -- ran out of solvent on a prior loop
                canCraftPotion = false
            end

            -- we reduce the amount of available solvents
            remainingSolvent = remainingSolvent - 1

            -- check availability of reagant 1
            if not AlchemyLearner.reagentAmounts[reagentItemId1] then
                AlchemyLearner.reagentAmounts[reagentItemId1] = Utils.GetNumberOfAvailableItems(reagentItemId1)
            end

            -- check availability of reagant 2
            if not AlchemyLearner.reagentAmounts[reagentItemId2] then
                AlchemyLearner.reagentAmounts[reagentItemId2] = Utils.GetNumberOfAvailableItems(reagentItemId2)
            end

            if AlchemyLearner.reagentAmounts[reagentItemId1] == 0 then
                -- skip this potion
                missingMaterialReagents[reagentItemId1] = reagantName1
                canCraftPotion = false
            end
            if AlchemyLearner.reagentAmounts[reagentItemId2] == 0 then
                -- skip this potion
                canCraftPotion = false
                missingMaterialReagents[reagentItemId2] = reagantName2
            end

            if canCraftPotion then
                AlchemyLearner.reagentAmounts[reagentItemId1] = AlchemyLearner.reagentAmounts[reagentItemId1] - 1
                AlchemyLearner.reagentAmounts[reagentItemId2] = AlchemyLearner.reagentAmounts[reagentItemId2] - 1
                queued = queued + 1

                LLC:CraftAlchemyItemId(solvent, reagentItemId1, reagentItemId2, nil, 1, true, '1')
                if LazyLearner.savedVars.extensiveReporting then
                    Utils.sendChatMessage(string.format(LazyLearner.L("LL_QUEUED_ITEM"),
                        Utils.getItemLinkFromItemId(solvent), Utils.getItemLinkFromItemId(reagentItemId1),
                        Utils.getItemLinkFromItemId(reagentItemId2)))
                end
            end
        end
    end
    for itemId, itemName in pairs(missingMaterialReagents) do
        if type(itemId) == "number" then
            Utils.sendChatMessage(zo_strformat(LazyLearner.L("LL_NOT_ENOUGH_REAGENTS"),
                Utils.getItemLinkFromItemId(itemId)), Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
        end
    end
    if missingMaterialReagents["Solvents"] then
        Utils.sendChatMessage(zo_strformat(LazyLearner.L("LL_NOT_ENOUGH_SOLVENTS"),
            Utils.getItemLinkFromItemId("Solvents")), Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
    end
    return queued
end

--- Queues alchemy items to learn unknown traits.
--- @param includeDlc Boolean indicating whether to include DLC reagents.
--- @return Boolean indicating whether any items were queued.
function AlchemyLearner.queueLearningAlchemy(includeDlc)
    -- First clear the current alchemy queue to ensure there is nothing left from previous attempt
    LazyLearner.LLC:cancelItem(CRAFTING_TYPE_ALCHEMY)
    local combosToCraft = calculateCombos(includeDlc)
    
    local queued = AlchemyLearner.alchemyQueuer(combosToCraft)
    
    local freeSlots = GetNumBagFreeSlots(BAG_BACKPACK)
    if queued > freeSlots then
        Utils.sendChatMessage(string.format(LazyLearner.L("LL_BAG_WARNING"), queued, freeSlots),
            Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
    end
    return queued > 0
end
