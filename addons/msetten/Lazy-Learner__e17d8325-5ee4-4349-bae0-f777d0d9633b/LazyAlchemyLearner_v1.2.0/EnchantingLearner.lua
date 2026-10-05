LazyLearner.EnchantingLearner = LazyLearner.EnchantingLearner or {}
local Utils = LazyLearner.Utils
local EnchantingLearner = LazyLearner.EnchantingLearner
local AlchemyLearner = LazyLearner.AlchemyLearner

--- List of all potency rune IDs in ESO, sorted by required enchanting proficiency
EnchantingLearner.potency = {
    [45856] = 1, -- Porade
    [45817] = 1, -- Jode
    [45855] = 1, -- Jora
    [45818] = 1, -- Notade
    [45806] = 2, -- Jejora
    [45857] = 2, -- Jera
    [45820] = 2, -- Tade
    [45819] = 2, -- Ode
    [45807] = 3, -- Odra
    [45822] = 3, -- Edode
    [45821] = 3, -- Jayde
    [45808] = 3, -- Pojora
    [45809] = 4, -- Edora
    [45810] = 4, -- Jaera
    [45823] = 4, -- Pojode
    [45824] = 4, -- Rekude
    [45812] = 5, -- Denara
    [45825] = 5, -- Hade
    [45826] = 5, -- Idode
    [45811] = 5, -- Pora
    [45827] = 6, -- Pode
    [45813] = 6, -- Rera
    [45814] = 7, -- Derado
    [45828] = 7, -- Kedeko
    [45815] = 8, -- Rekura
    [45829] = 8, -- Rede
    [45830] = 9, -- Kude
    [45816] = 9, -- Kura
    [68340] = 10, -- Itade
    [64508] = 10, -- Jehade
    [64509] = 10, -- Rejera
    [68341] = 10 -- Repora
}

--- List of all essence rune IDs in ESO
EnchantingLearner.essence = {
    45839, -- Dakeipa
    45833, -- Deni
    45836, -- Denima
    45842, -- Deteri
    68342, -- Hakeijo
    45841, -- Haoko
    166045, -- Indeko
    45849, -- Kaderi
    45837, -- Kuoko
    45848, -- Makderi
    45832, -- Makko
    45835, -- Makkoma
    45840, -- Meip
    45831, -- Oko
    45834, -- Okoma
    45843, -- Okori
    45846, -- Oru
    45838, -- Rakeipa
    45847 -- Taderi
}

--- List of all aspect rune IDs in ESO, sorted by required enchanting proficiency
EnchantingLearner.aspect = {
    [45850] = 1, -- Ta
    [45851] = 1, -- Jejota
    [45852] = 2, -- Denata
    [45853] = 3, -- Rekuta
    [45854] = 4 -- Kuta
}

--- Find an unused rune, or the one with the highest count if all are used
--- @param runeTable table A table of rune IDs and their available amounts.
--- @param usedIds table A table of rune IDs that have already been used.
--- @return runeId Id of the chosen rune to use
local function getNextRune(runeTable, usedIds, instockRunes)
    local excludedBackupRunes = {
        [45854] = 1,
        [166045] = 1,
        [68342] = 1,
    }
    local maxId, maxCount = nil, -1
    for id, count in pairs(instockRunes) do
        -- d("Checking rune: " .. Utils.getItemLinkFromItemId(id))
        if runeTable[id] and not usedIds[id] and count > 0 then
            -- d("Return learnable rune: " .. Utils.getItemLinkFromItemId(id))
            return id
        end
        if count > maxCount and not excludedBackupRunes[id] then
            maxId, maxCount = id, count
        end
    end

    -- If all runes have been used, return the one with the highest count, excluding hakeijo, kuta, and indeko
    if maxId and maxCount > 0 then
        -- d("Return max rune: " .. Utils.getItemLinkFromItemId(maxId))
        return maxId
    end
    return nil
end

-- Craft glyphs to learn as many rune traits as possible and add them to the Lazy Lib Crafter queue
--- @param LLC the LibLazyCrafting instance
--- @param learnablePotencyRunes table of all potency runes that must be learned and their amounts in stock
--- @param learnableEssenceRunes table of all essence runes that must be learned and their amounts in stock
--- @param learnableAspectRunes table of all aspect runes that must be learned and their amounts in stock
--- @return amountQueued number of glyphs queued to craft
--- @return missingPotencyRunes if there was a shortage of potency runes to learn all rune traits
--- @return missingEssenceRunes if there was a shortage of essence runes to learn all rune traits
--- @return missingAspectRunes if there was a shortage of aspect runes to learn all rune traits
local function craftAllCombinations(LLC, learnablePotencyRunes, learnableEssenceRunes, learnableAspectRunes,
    potencyRunesStock, essenceRunesStock, aspectRunesStock)
    local usedPotency, usedEssence, usedAspect = {}, {}, {}
    local potencyIds, essenceIds, aspectIds = {}, {}, {}
    local potencyMissing, essenceMissing, aspectMissing = false, false, false

    for id in pairs(learnablePotencyRunes) do
        table.insert(potencyIds, id)
    end
    for id in pairs(learnableEssenceRunes) do
        table.insert(essenceIds, id)
    end
    for id in pairs(learnableAspectRunes) do
        table.insert(aspectIds, id)
    end

    local amountQueued = 0

    local maxLen = math.max(#potencyIds, #essenceIds, #aspectIds)
    for i = 1, maxLen do
        -- d("Find potency rune")
        local potencyId = getNextRune(learnablePotencyRunes, usedPotency, potencyRunesStock)
        -- d("Find essence rune")
        local essenceId = getNextRune(learnableEssenceRunes, usedEssence, essenceRunesStock)
        -- d("Find aspect rune")
        local aspectId = getNextRune(learnableAspectRunes, usedAspect, aspectRunesStock)

        if not potencyId then
            potencyMissing = true
        end
        if not essenceId then
            essenceMissing = true
        end
        if not aspectId then
            aspectMissing = true
        end

        if potencyId and essenceId and aspectId then
            LLC:CraftEnchantingItemId(potencyId, essenceId, aspectId, true, "", {}, 1)
            amountQueued = amountQueued + 1
            if LazyLearner.savedVars.extensiveReporting then
                Utils.sendChatMessage(string.format(LazyLearner.L("LL_QUEUED_ITEM"),
                    Utils.getItemLinkFromItemId(potencyId), Utils.getItemLinkFromItemId(essenceId),
                    Utils.getItemLinkFromItemId(aspectId)))
            end

            usedPotency[potencyId] = true
            usedEssence[essenceId] = true
            usedAspect[aspectId] = true

            potencyRunesStock[potencyId] = potencyRunesStock[potencyId] - 1
            essenceRunesStock[essenceId] = essenceRunesStock[essenceId] - 1
            aspectRunesStock[aspectId] = aspectRunesStock[aspectId] - 1
        end
    end
    return amountQueued, potencyMissing, essenceMissing, aspectMissing
end

--- Queue learning of enchanting runes based on available runes in inventory
--- @param includeDlc boolean Whether to include DLC runes (Hakeijo and Indeko)
--- @param includeKuta boolean Whether to include Kuta rune 
--- @return boolean true if at least one glyph was queued to craft, false otherwise
function EnchantingLearner.queueLearningEnchanting(includeDlc, includeKuta)
    -- d("queueLearningEnchanting called with includeDlc=" .. tostring(includeDlc) .. " includeKuta=" .. tostring(includeKuta))
    local skilllevel = GetNonCombatBonus(NON_COMBAT_BONUS_ENCHANTING_LEVEL)
    local aspectlevel = GetNonCombatBonus(NON_COMBAT_BONUS_ENCHANTING_RARITY_LEVEL)
    local LLC = LazyLearner.LLC

    -- Clear Enchanting Queue first
    LLC:cancelItem(CRAFTING_TYPE_ENCHANTING)

    -- Count amount of each potency rune stone available
    -- And determine which potency run stones needs to be learned
    local learnablePotencyRunes = {}
    local missingPotencyRunes = {}
    local instockPotencyRunes = {}
    for potency, lvl in pairs(EnchantingLearner.potency) do
        if lvl <= skilllevel then
            local itemLink = Utils.getItemLinkFromItemId(potency)
            local total = Utils.GetNumberOfAvailableItems(potency)
            local known = GetItemLinkEnchantingRuneName(itemLink)
            -- d("Potency rune: " .. itemLink .. " total: " .. total .. " known: " .. tostring(known))
            instockPotencyRunes[potency] = total
            if known == false and total > 0 then
                learnablePotencyRunes[potency] = true
            elseif known == false and total == 0 then
                table.insert(missingPotencyRunes, potency)
            end
        end
    end

    -- Count amount of each aspect rune stone available
    -- And determine which aspect run stones needs to be learned
    local learnableAspectRunes = {}
    local missingAspectRunes = {}
    local instockAspectRunes = {}
    for aspect, lvl in pairs(EnchantingLearner.aspect) do
        if lvl <= aspectlevel then
            local itemLink = Utils.getItemLinkFromItemId(aspect)
            local total = Utils.GetNumberOfAvailableItems(aspect)
            local known = GetItemLinkEnchantingRuneName(itemLink)
            -- d("Aspect rune: " .. itemLink .. " total: " .. total .. " known: " .. tostring(known))
            instockAspectRunes[aspect] = total
            if known == false and total > 0 then
                learnableAspectRunes[aspect] = true
            elseif known == false and total == 0 then
                if includeKuta or (not includeKuta and aspect ~= 45854) then
                    table.insert(missingAspectRunes, aspect)
                end
            end
        end
    end

    -- Count amount of each essence rune stone available
    -- And determine which essence run stones needs to be learned
    local learnableEssenceRunes = {}
    local missingEssenceRunes = {}
    local instockEssenceRunes = {}
    for i, essence in pairs(EnchantingLearner.essence) do
        local itemLink = Utils.getItemLinkFromItemId(essence)
        local total = Utils.GetNumberOfAvailableItems(essence)
        local known = GetItemLinkEnchantingRuneName(itemLink)
        -- d("Essence rune: " .. itemLink .. " total: " .. total .. " known: " .. tostring(known))
        instockEssenceRunes[essence] = total
        if known == false and total > 0 then
            learnableEssenceRunes[essence] = true
        elseif known == false and total == 0 then
            if includeDlc or (not includeDlc and essence ~= 68342 and essence ~= 166045) then
                table.insert(missingEssenceRunes, essence)
            end
        end
    end

    -- Remove Kuta if not allowed
    if not includeKuta then
        learnableAspectRunes[45854] = nil
        instockAspectRunes[45854] = nil
    end

    -- Remove Hakeijo and Indeko if not including DLC runes
    if not includeDlc then
        learnableEssenceRunes[68342] = nil
        learnableEssenceRunes[166045] = nil
        instockEssenceRunes[68342] = nil
        instockEssenceRunes[166045] = nil
    end


    local result = false
    if learnablePotencyRunes or learnableAspectRunes or learnableEssenceRunes then
        local glyphs, potencyMissing, essenceMissing, aspectMissing =
            craftAllCombinations(LLC, learnablePotencyRunes, learnableEssenceRunes, learnableAspectRunes,
                instockPotencyRunes, instockEssenceRunes, instockAspectRunes)
        if potencyMissing then
            Utils.sendChatMessage(LazyLearner.L("LL_ENCHANTING_NOT_ENOUGH_POTENCY"),
                Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
        end

        if essenceMissing then
            Utils.sendChatMessage(LazyLearner.L("LL_ENCHANTING_NOT_ENOUGH_ESSENCE"),
                Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
        end

        if aspectMissing then
            Utils.sendChatMessage(LazyLearner.L("LL_ENCHANTING_NOT_ENOUGH_ASPECT"),
                Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
        end

        if glyphs > 0 then
            local freeSlots = GetNumBagFreeSlots(BAG_BACKPACK)
            if (glyphs > freeSlots) then
                Utils.sendChatMessage(string.format(LazyLearner.L("LL_ENCHANTING_BAGSPACE_WARNING"), freeSlots, glyphs,
                    freeSlots), Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
            else
                Utils.sendChatMessage(string.format(LazyLearner.L("LL_ENCHANTING_GLYPHS_QUEUED"), glyphs))
            end
            result = true
        else
            if #missingPotencyRunes + #missingEssenceRunes + #missingAspectRunes > 0 then
                Utils.sendChatMessage(LazyLearner.L("LL_ENCHANTING_NO_GLYPHS_MISSING_RUNES"))
            else
                Utils.sendChatMessage(LazyLearner.L("LL_NOTHING_QUEUED_ENCHANTING"))
            end
        end
    else
        if #missingPotencyRunes + #missingEssenceRunes + #missingAspectRunes > 0 then
            Utils.sendChatMessage(LazyLearner.L("LL_ENCHANTING_NO_GLYPHS_MISSING_RUNES"))
        else
            Utils.sendChatMessage(LazyLearner.L("LL_NOTHING_QUEUED_ENCHANTING"))
        end
    end

    if #missingPotencyRunes > 0 then
        local missingpotencymsg = LazyLearner.L("LL_ENCHANTING_MISSING_POTENCY")
        for _, potency in ipairs(missingPotencyRunes) do
            missingpotencymsg = missingpotencymsg .. Utils.getItemLinkFromItemId(potency) .. " "
        end
        Utils.sendChatMessage(missingpotencymsg, Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
    end

    if #missingEssenceRunes > 0 then
        local missingessencemsg = LazyLearner.L("LL_ENCHANTING_MISSING_ESSENCE")
        for _, essence in ipairs(missingEssenceRunes) do
            missingessencemsg = missingessencemsg .. Utils.getItemLinkFromItemId(essence) .. " "
        end
        Utils.sendChatMessage(missingessencemsg, Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
    end

    if #missingAspectRunes > 0 then
        local missingaspectmsg = LazyLearner.L("LL_ENCHANTING_MISSING_ASPECT")
        for _, aspect in ipairs(missingAspectRunes) do
            missingaspectmsg = missingaspectmsg .. Utils.getItemLinkFromItemId(aspect) .. " "
        end
        Utils.sendChatMessage(missingaspectmsg, Utils.RGBColorToHex(LazyLearner.savedVars.warningColor))
    end

    return result
end
