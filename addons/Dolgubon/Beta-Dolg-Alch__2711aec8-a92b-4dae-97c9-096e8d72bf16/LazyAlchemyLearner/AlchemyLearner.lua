LazyLearner.AlchemyLearner = LazyLearner.AlchemyLearner or {}
local Utils = LazyLearner.Utils
local EnchantingLearner = LazyLearner.EnchantingLearner
local AlchemyLearner = LazyLearner.AlchemyLearner
local timingStart

-- rules for negative trait learning

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
    zo_callLater(function()
        if LibPrice then
            for k, v in pairs(defaultPrices) do
                local price, source = LibPrice.ItemLinkToPriceGold(Utils.getItemLinkFromItemId(k))
                if source ~= "npc" and price and price>0 then
                    defaultPrices[k] = price
                end
            end
        end
    end, 1000)
    EVENT_MANAGER:UnregisterForEvent(LazyLearner.name.."AlchemyPricePopulation", EVENT_PLAYER_ACTIVATED)
end

EVENT_MANAGER:RegisterForEvent(LazyLearner.name.."AlchemyPricePopulation", EVENT_PLAYER_ACTIVATED, populatePrices)

local expectedKnown = {}
local function populateExpectedKnownTraits()
    ZO_ClearTable(expectedKnown)
    local workingTable = expectedKnown
    local itemLink
    for k, v in pairs(AlchemyLearner.reagentTraits) do
        workingTable[k] = {}
        itemLink = Utils.getItemLinkFromItemId(k)
        for i = 1, 4 do
            workingTable[k][v[i]] = GetItemLinkReagentTraitInfo(itemLink, i)
        end
    end
    return workingTable
end


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


local function anyExpectedUnknown(itemId)
    for k, v in pairs(expectedKnown[itemId]) do
        if not v then
            return true
        end
    end
    return false
end
local calcOverlapEffects = {}
local function calcOverlap(r1,r2, r3)
    local reagentItemId1 = r1[1]
    local reagentItemId2 = r2[1]
    local reagentItemId3 = r3 and r3[1] or nil
    local reagentEffects1 = AlchemyLearner.reagentTraits[reagentItemId1]
    local reagentEffects2 = AlchemyLearner.reagentTraits[reagentItemId2]
    local reagentEffects3 = AlchemyLearner.reagentTraits[reagentItemId3]
    ZO_ClearTable(calcOverlapEffects)
    for i =1, 4 do
        calcOverlapEffects[reagentEffects1[i]] = (calcOverlapEffects[reagentEffects1[i]] or 0 ) + 1
        calcOverlapEffects[reagentEffects2[i]] = (calcOverlapEffects[reagentEffects2[i]] or 0 ) + 1
        if r3 then
            calcOverlapEffects[reagentEffects3[i]] = (calcOverlapEffects[reagentEffects3[i]] or 0 ) + 1
        end
    end
    for positiveName, positiveAmount in pairs(calcOverlapEffects) do
        local negativeName = AlchemyLearner.negativeTraits[positiveName]
        if calcOverlapEffects[negativeName] then
            -- negativeAmount = calcOverlapEffects[negativeName]
            -- if negativeAmount == 2 or positiveAmount == 2 then
            --     -- potential minor improvement (see rules on negative trait learning)
            -- end
            calcOverlapEffects[positiveName] = nil
            calcOverlapEffects[negativeName] = nil
        end
        if positiveAmount==1 then
            calcOverlapEffects[positiveName] = nil
        end
    end
    if next(calcOverlapEffects)==nil then return nil, 0, true end
    local output
    local totalLearnable = 0
    local learningReagent1 = false
    local learningReagent2 = false
    local learningReagent3 = reagentItemId3 == nil or false
    local expectedKnown1
    local expectedKnown2
    local expectedKnown3
    local expectedAll1 = expectedKnown[reagentItemId1]
    local expectedAll2 = expectedKnown[reagentItemId2]
    local expectedAll3 = expectedKnown[reagentItemId3]
    for k , v in pairs(calcOverlapEffects) do
        output = output or {} -- skips table creation if there's no overlap
        table.insert(output, k)
        expectedKnown1 = expectedAll1[k]
        if expectedKnown1 == false then
            totalLearnable = totalLearnable + 1
        end
        expectedKnown2 = expectedAll2[k]
        if expectedKnown2 == false then
            totalLearnable = totalLearnable + 1
        end
        if r3 then
            expectedKnown3 = expectedAll3[k]
            if expectedKnown3 == false then
                totalLearnable = totalLearnable + 1
            end
        end
        learningReagent1 = learningReagent1 or (expectedKnown1 ~= nil)
        learningReagent2 = learningReagent2 or (expectedKnown2 ~= nil)
        learningReagent3 = learningReagent3 or (expectedKnown3 ~= nil)
    end
    return output, totalLearnable, not (learningReagent1 and learningReagent2 and learningReagent3)
end

local function updateOverlap(learning, r1, r2, r3)
    if true then
        -- return calcOverlap(r1, r2,r3)
    end
    local reagentItemId1 = r1[1]
    local reagentItemId2 = r2[1]
    local reagentItemId3 = r3 and r3[1] or nil
    local totalLearnable = 0
    local learningReagent1 = false
    local learningReagent2 = false
    local learningReagent3 = reagentItemId3 == nil or false
    local expectedKnown1
    local expectedKnown2
    local expectedKnown3
    local expectedAll1 = expectedKnown[reagentItemId1]
    local expectedAll2 = expectedKnown[reagentItemId2]
    local expectedAll3 = expectedKnown[reagentItemId3]
    for i = 1, #learning do
        k=learning[i]
        expectedKnown1 = expectedAll1[k]
        if expectedKnown1 == false then
            totalLearnable = totalLearnable + 1
        end
        expectedKnown2 = expectedAll2[k]
        if expectedKnown2 == false then
            totalLearnable = totalLearnable + 1
        end
        if r3 then
            expectedKnown3 = expectedAll3[k]
            if expectedKnown3 == false then
                totalLearnable = totalLearnable + 1
            end
        end
        learningReagent1 = learningReagent1 or (expectedKnown1 ~= nil)
        learningReagent2 = learningReagent2 or (expectedKnown2 ~= nil)
        learningReagent3 = learningReagent3 or (expectedKnown3 ~= nil)
    end
    
    return learning, totalLearnable, not (learningReagent1 and learningReagent2 and learningReagent3)
end

local function comboSort(a,b)
    if a.expectedLearnable == b.expectedLearnable then
        return a.price < b.price
    end
    return a.expectedLearnable < b.expectedLearnable
end

local function ennumerateAllCombos(reagentList)
    local ms = GetGameTimeMilliseconds()
    local reagent1
    local reagent2
    local reagent3
    local potionCombos = {}
    for i = 1, #reagentList-1 do
        for j = i+1, #reagentList do
            reagent1 = reagentList[i]
            reagent2 = reagentList[j]
            local learning, totalLearnable = calcOverlap(reagent1, reagent2)
            local price = reagent1[3] + reagent2[3]
            -- d("{"..a[k][i][1]..","..a[k][j][1].."} -- "..a[k][i][2].." and "..a[k][j][2].." learning "..table.concat(learning, " and ").." "..price.."g")
            if totalLearnable > 0 then
                local comboTable = {reagent1, reagent2, price=price, learning=learning, expectedLearnable = totalLearnable}
                table.insert(potionCombos, comboTable)
            end
        end
    end
    d("ennumeration "..( GetGameTimeMilliseconds()-ms))
    --45555
    local _,_,_,_,_,canUseThreeReagents = GetSkillAbilityInfo(8,1,5)
    if not canUseThreeReagents then
        return potionCombos
    end
    local possibleCombos = 0
    for i = 1, #reagentList-2 do
        reagent1 = reagentList[i]
        for j = i+1, #reagentList-1 do
            reagent2 = reagentList[j]
            for k = j+1, #reagentList do
                possibleCombos = possibleCombos + 1
                reagent3 = reagentList[k]

                local learning, totalLearnable, extraReagent = calcOverlap(reagent1, reagent2,reagent3)
                -- d("{"..a[k][i][1]..","..a[k][j][1].."} -- "..a[k][i][2].." and "..a[k][j][2].." learning "..table.concat(learning, " and ").." "..price.."g")
                if totalLearnable > 0 and not extraReagent then
                    local price = reagent1[3] + reagent2[3] + reagent3[3]
                    local comboTable = {reagent1, reagent2,reagent3, price=price, learning=learning, expectedLearnable = totalLearnable}
                    table.insert(potionCombos, comboTable)
                end
            end
        end
    end
    -- d(#potionCombos)
    d("ennumeration "..( GetGameTimeMilliseconds()-ms))
    d("Real combos: "..(#potionCombos))
    d("Excess combos: "..(possibleCombos-#potionCombos))
    return potionCombos
end

-- /script 
local function runAlchSearch(useDLC)
    useDLC = (useDLC==nil) and false or useDLC
    local reagentsByEffect = {}
    local reagentList = {}
    for itemId, effects in pairs(AlchemyLearner.reagentTraits) do
        local itemLink = Utils.getItemLinkFromItemId(itemId)
        local bag, bank, craftBag, houseBank = GetItemLinkStacks(itemLink)
        local storedAmount = bag + bank + craftBag + houseBank

        AlchemyLearner.reagentTraits[itemId].expectedAmount = storedAmount

        if (useDLC or not AlchemyLearner.dlcReagents[itemId]) and storedAmount > 0 then
            table.insert(reagentList, {itemId, GetItemLinkName(itemLink) , defaultPrices[itemId]})
        elseif storedAmount == 0 and (useDLC or not AlchemyLearner.dlcReagents[itemId]) and anyExpectedUnknown(itemId) then
            Utils.sendChatMessage("You do not have any "..itemLink.." - cannot learn traits for this reagent"
                ,Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
        else
            -- d(Utils.getItemLinkFromItemId(itemId))
        end
    end
    local potionCombos = {}
    potionCombos = ennumerateAllCombos(reagentList)
    return potionCombos
end

local function checkReagentOverlap(comboA, comboB)
    for i = 1, #comboA do
        for j = 1, #comboB do
            if comboA[i] == comboB[j] then
                return true
            end
        end
    end
    return false
end

local function recalculateEffectLearnables(potionCombos, removedCombo)
    for j = #potionCombos, 1, -1 do
        local combo = potionCombos[j]
        if checkReagentOverlap(combo, removedCombo) then
            local learning, newLearnable, extraReagent = updateOverlap(combo.learning, combo[1], combo[2], combo[3])
            combo.expectedLearnable = newLearnable
            if newLearnable == 0 then
                table.remove(potionCombos, j)
            elseif extraReagent then
                table.remove(potionCombos, j)
            elseif newLearnable == 1 and combo[3] then
                table.remove(potionCombos, j)
            end
        end
    end
end
-- AlchemyLearner.reagentTraits[itemId].expectedAmount
local warnedIDs = {}
local combinePotionCombos ={}

local function singlePass(potionCombos)
    table.sort(potionCombos, comboSort)
    local comboToAdd = potionCombos[#potionCombos]
    local reagentItemId1
    local reagentItemId2
    local reagentItemId3
    local missingAny = true -- we want first loop
    while missingAny do
        if not comboToAdd then
            return
        end
        reagentItemId1 = comboToAdd[1][1]
        reagentItemId2 = comboToAdd[2][1]
        reagentItemId3 = comboToAdd[3] and comboToAdd[3][1] or nil
        missingAny = false
        if comboToAdd.expectedLearnable == 0 then
            missingAny = true
        end
        if not missingAny then
            if AlchemyLearner.reagentTraits[reagentItemId1].expectedAmount < 1 then
                if not warnedIDs[reagentItemId1] then
                    Utils.sendChatMessage(zo_strformat(LazyLearner.L("LL_NOT_ENOUGH_REAGENTS"),
                        Utils.getItemLinkFromItemId(reagentItemId1)), Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
                    warnedIDs[reagentItemId1] = true
                end
                missingAny = true
            end
            if AlchemyLearner.reagentTraits[reagentItemId2].expectedAmount < 1 then
                if not warnedIDs[reagentItemId2] then
                    Utils.sendChatMessage(zo_strformat(LazyLearner.L("LL_NOT_ENOUGH_REAGENTS"),
                        Utils.getItemLinkFromItemId(reagentItemId2)), Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
                    warnedIDs[reagentItemId2] = true
                end
                missingAny = true
            end
            if comboToAdd[3] and AlchemyLearner.reagentTraits[reagentItemId3].expectedAmount < 1 then
                if not warnedIDs[reagentItemId3] then
                    Utils.sendChatMessage(zo_strformat(LazyLearner.L("LL_NOT_ENOUGH_REAGENTS"),
                        Utils.getItemLinkFromItemId(reagentItemId3)), Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
                    warnedIDs[reagentItemId3] = true
                end
                missingAny = true
            end
        end
       
        if missingAny or comboToAdd.expectedLearnable == 0 then
            table.remove(potionCombos, #potionCombos)
            comboToAdd = potionCombos[#potionCombos]
        end
        if not comboToAdd then
            return
        end
    end
    for i = 1, #comboToAdd.learning do

        expectedKnown[reagentItemId1] [comboToAdd.learning[i]] = (expectedKnown[reagentItemId1] [comboToAdd.learning[i]] ~= nil) and true or nil
        expectedKnown[reagentItemId2] [comboToAdd.learning[i]] = (expectedKnown[reagentItemId2] [comboToAdd.learning[i]] ~= nil) and true or nil
        AlchemyLearner.reagentTraits[reagentItemId1].expectedAmount = AlchemyLearner.reagentTraits[reagentItemId1].expectedAmount - 1
        AlchemyLearner.reagentTraits[reagentItemId2].expectedAmount = AlchemyLearner.reagentTraits[reagentItemId2].expectedAmount - 1
        if comboToAdd[3] then
            expectedKnown[reagentItemId3] [comboToAdd.learning[i]] = (expectedKnown[reagentItemId3] [comboToAdd.learning[i]] ~= nil) and true or nil
            AlchemyLearner.reagentTraits[reagentItemId3].expectedAmount = AlchemyLearner.reagentTraits[reagentItemId3].expectedAmount - 1
        end
    end
    -- d(comboToAdd.expectedLearnable.." Learned from "..Utils.getItemLinkFromItemId(comboToAdd[1][1]).. Utils.getItemLinkFromItemId(comboToAdd[2][1])..( comboToAdd[3] and Utils.getItemLinkFromItemId(comboToAdd[3][1]) or ""))
    
    local removedCombo = table.remove(potionCombos, #potionCombos)
    recalculateEffectLearnables(potionCombos, removedCombo)
    -- recalculateLearnables(potionCombos, comboToAdd)
    return comboToAdd
end

local function calculateCombos(useDLC)
    ZO_ClearTable(warnedIDs)
    -- populatePrices()
    expectedKnown = populateExpectedKnownTraits()
    local potionCombos = runAlchSearch(useDLC)
    local combosToCraft = {}
    local added = 0
    while next(potionCombos) do
        local comboToAdd = singlePass(potionCombos)
        if comboToAdd then
            combosToCraft[#combosToCraft+1] = comboToAdd
        end
        added = #combosToCraft
    end
    if GetDisplayName() == "@Dolgubon" then
        d(#combosToCraft.." Expecting to make")
    end
    if #combosToCraft > 200 then
        return {}
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

local oneWayNegativeTraits =
{
    ["Restore Health"] = "Ravage Health",
    ["Restore Magicka"] = "Ravage Magicka",
    ["Restore Stamina"] = "Ravage Stamina",
    ["Increase Power"] = "Cowardice",
    ["Force"] = "Enervation",
    ["Critical"] = "Uncertainty",
    ["Lingering Health"] = "Gradual Ravage Health",
    ["Speed"] = "Hindrance",
    ["Protection"] = "Vulnerability",
    ["Increase Armor"] = "Fracture",
    ["Increase Spell Resist"] = "Breach",
    ["Vitality"] = "Defile",
    ["Detection"] = "Invisible",
    ["Unstoppable"] = "Entrapment",
    ["Heroism"] = "Timidity",
    ["Mending"] = "Vexation",
    ["Damage Shield"] = "Heal Absorption",
}
AlchemyLearner.negativeTraits = {}
for k, v in pairs(oneWayNegativeTraits) do
    AlchemyLearner.negativeTraits[v] = k
    AlchemyLearner.negativeTraits[k] = v
end

oneWayNegativeTraits = nil

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

local function threeReagentMatchingTraits(reagent1, reagent2, reagent3)
    local traits1 = AlchemyLearner.reagentTraits[reagent1]
    local traits2 = AlchemyLearner.reagentTraits[reagent2]
    local traits3 = AlchemyLearner.reagentTraits[reagent3]
    local negativeTraits = AlchemyLearner.negativeTraits

    local traitCount = {}
    for i = 1, 4 do
        traitCount[traits1[i]] = (traitCount[traits1[i]] or 0) + 1
        traitCount[traits2[i]] = (traitCount[traits2[i]] or 0) + 1

        traitCount[negativeTraits[traits1[i]]] = (traitCount[negativeTraits[traits1[i]]] or 0) - 1
        traitCount[negativeTraits[traits2[i]]] = (traitCount[negativeTraits[traits2[i]]] or 0) - 1
        if reagent3 then
            traitCount[traits3[i]] = (traitCount[traits3[i]] or 0) + 1
            traitCount[negativeTraits[traits3[i]]] = (traitCount[negativeTraits[traits3[i]]] or 0) - 1
        end
    end
    local matchingTraits = {}
    for k, v in pairs(traitCount) do
        if v > 1 then
            table.insert(matchingTraits, k)
        end
    end
    return matchingTraits
end

--- Find the matching traits between two reagents.
--- @param reagent1 The item ID of the first reagent.
--- @param reagent2 The item ID of the second reagent.
--- @return A table containing the matching traits.
function AlchemyLearner.GetMatchingTraits(reagent1, reagent2, reagent3)
    local traits1 = AlchemyLearner.reagentTraits[reagent1]
    local traits2 = AlchemyLearner.reagentTraits[reagent2]
    if reagent3 then
        return threeReagentMatchingTraits(reagent1, reagent2, reagent3)
    end
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
    AlchemyLearner.reagentAmounts = {}

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
        local reagentItemId3 = combos[i][3] and combos[i][3][1] or nil

        -- we check what traits between the two reagents are matching
        local theoreticalMatchingTraits = AlchemyLearner.GetMatchingTraits(reagentItemId1, reagentItemId2, reagentItemId3)
        local amountMatchingReagant1 = 0
        local amountMatchingReagant2 = 0
        local amountMatchingReagant3 = 0
        for j = 1, 4 do

            --[[
				k = known status of the reagant's trait {true/false}
				n = name of the trait, currently the name wil be nil if the trait is unknown
			--]]
            local k1 = GetItemLinkReagentTraitInfo(Utils.getItemLinkFromItemId(reagentItemId1), j)
            local k2 = GetItemLinkReagentTraitInfo(Utils.getItemLinkFromItemId(reagentItemId2), j)
            local k3 = GetItemLinkReagentTraitInfo(Utils.getItemLinkFromItemId(reagentItemId3), j)
            local n1 = AlchemyLearner.reagentTraits[reagentItemId1][j]
            local n2 = AlchemyLearner.reagentTraits[reagentItemId2][j]
            local n3 = reagentItemId3 and AlchemyLearner.reagentTraits[reagentItemId3][j] or nil
            -- as a precaution, we'll set the name of the trait to nil if it's not known, since this is the behaviour we expect in the next step
            if not k1 then
                n1 = nil
            end

            if not k2 then
                n2 = nil
            end
             if not k3 then
                n3 = nil
            end

            -- we count the amount of known matching traits of each reagant
            if Utils.Contains(theoreticalMatchingTraits, n1) then
                amountMatchingReagant1 = amountMatchingReagant1 + 1
            end

            if Utils.Contains(theoreticalMatchingTraits, n2) then
                amountMatchingReagant2 = amountMatchingReagant2 + 1
            end
             if Utils.Contains(theoreticalMatchingTraits, n3) then
                amountMatchingReagant3 = amountMatchingReagant3 + 1
            end
        end

        -- if the amount of actual known, matching traits is not the same as the theoretical amount of matching traits known will be false
        known = amountMatchingReagant1 == #theoreticalMatchingTraits and amountMatchingReagant2 ==
                    #theoreticalMatchingTraits and ( not reagentItemId3 or (amountMatchingReagant3 == #theoreticalMatchingTraits))


        -- Leaving this here for debug purposes for now
        local reagantName1 = GetItemLinkName(Utils.getItemLinkFromItemId(reagentItemId1))
        local reagantName2 = GetItemLinkName(Utils.getItemLinkFromItemId(reagentItemId2))
        local reagantName3 = GetItemLinkName(Utils.getItemLinkFromItemId(reagentItemId3))

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

            if reagentItemId3 and not AlchemyLearner.reagentAmounts[reagentItemId3] then
                AlchemyLearner.reagentAmounts[reagentItemId3] = Utils.GetNumberOfAvailableItems(reagentItemId3)
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
            if reagentItemId3 and (AlchemyLearner.reagentAmounts[reagentItemId3] == 0) then
                -- skip this potion
                canCraftPotion = false
                missingMaterialReagents[reagentItemId3] = reagantName3
            end

            if canCraftPotion then
                AlchemyLearner.reagentAmounts[reagentItemId1] = AlchemyLearner.reagentAmounts[reagentItemId1] - 1
                AlchemyLearner.reagentAmounts[reagentItemId2] = AlchemyLearner.reagentAmounts[reagentItemId2] - 1
                if reagentItemId3 then
                    AlchemyLearner.reagentAmounts[reagentItemId3] = AlchemyLearner.reagentAmounts[reagentItemId3] - 1
                end
                queued = queued + 1

                LLC:CraftAlchemyItemId(solvent, reagentItemId1, reagentItemId2, reagentItemId3, 1, true, '1')
                if LazyLearner.savedVars.extensiveReporting then
                    Utils.sendChatMessage(string.format(LazyLearner.L("LL_QUEUED_ITEM"),
                        Utils.getItemLinkFromItemId(solvent), Utils.getItemLinkFromItemId(reagentItemId1),
                        Utils.getItemLinkFromItemId(reagentItemId3) or "", Utils.getItemLinkFromItemId(reagentItemId2)))
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
    local start = GetGameTimeMilliseconds()
    timingStart = GetGameTimeMilliseconds()
    -- First clear the current alchemy queue to ensure there is nothing left from previous attempt
    LazyLearner.LLC:cancelItem(CRAFTING_TYPE_ALCHEMY)
    local combosToCraft = calculateCombos(includeDlc)
    local threeReagentTest = {{{30160},
{30164},
{30163},}}
    local queued = AlchemyLearner.alchemyQueuer( combosToCraft)
    
    local freeSlots = GetNumBagFreeSlots(BAG_BACKPACK)
    if queued > freeSlots then
        Utils.sendChatMessage(string.format(LazyLearner.L("LL_BAG_WARNING"), queued, freeSlots),
            Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
    end
    if GetDisplayName() == "@Dolgubon" then
        d(#craftingQueue['LazyAlchemyLearner'][4].. " queued (Properly hidden debug message)")
        assert(#craftingQueue['LazyAlchemyLearner'][4] == 34)
    end
        local _,_,_,_,_,canUseThreeReagents = GetSkillAbilityInfo (8,1,5)
    if queued > 0 and not canUseThreeReagents then
        Utils.sendChatMessage("Note: Only using potions with two reagents. To save materials, level to alchemy level 15 and purchase Laboratory use. If you wish to unqueue everything, go to the settings menu or type /lazylearn cancel",
            Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
    end
    d("approx ms used: "..(GetGameTimeMilliseconds() - start))
    return queued > 0
end
