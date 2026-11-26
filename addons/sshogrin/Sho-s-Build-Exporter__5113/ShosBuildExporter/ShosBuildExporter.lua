ShosBuildExporter = ShosBuildExporter or {}
local SBE = ShosBuildExporter

-- ============================================================================
-- ADDON METADATA CONFIGURATION (Edit these values to update everywhere)
-- ============================================================================
SBE.name      = "ShosBuildExporter"
SBE.title     = "Sho's Build Exporter"
SBE.author    = "sshogrin"
SBE.version   = "1.0.0"
SBE.colorHex  = "2046e5"
-- ============================================================================

local COLOR_PREFIX   = "|c" .. SBE.colorHex
local COLOR_SUFFIX   = "|r"
local COLORED_TITLE  = COLOR_PREFIX .. SBE.title .. COLOR_SUFFIX
local COLORED_AUTHOR = COLOR_PREFIX .. SBE.author .. COLOR_SUFFIX
local CHAT_TAG       = COLOR_PREFIX .. "[" .. SBE.title .. "]" .. COLOR_SUFFIX

local CleanName = SBE.CleanName
local Trim      = SBE.Trim

local mainWindow, editBox, nameEditBox, charDropdown, applyBtn, deleteBtn
local selectedBuildData = nil
local selectedBuildKey  = nil
local pendingDeleteKey  = nil
local recentChatBuilds  = {}

local function ResetDeleteState()
    pendingDeleteKey = nil
    if deleteBtn then
        deleteBtn:SetText("Delete Build")
    end
end

-- Helper: Extract standardized gear info (names + numeric IDs) from any itemLink
local function InspectItemLink(itemLink)
    local itemName = CleanName(GetItemLinkName(itemLink))
    local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)
    setName = hasSet and CleanName(setName) or "No Set"
    setId   = hasSet and (setId or 0) or 0

    local itemType = GetItemLinkItemType(itemLink)
    local weightOrType = ""
    local subTypeId = 0
    if itemType == ITEMTYPE_ARMOR then
        local armorType = GetItemLinkArmorType(itemLink)
        if armorType ~= ARMORTYPE_NONE then
            subTypeId = armorType
            weightOrType = CleanName(GetString("SI_ARMORTYPE", armorType))
        end
    elseif itemType == ITEMTYPE_WEAPON then
        local weaponType = GetItemLinkWeaponType(itemLink)
        if weaponType ~= WEAPONTYPE_NONE then
            subTypeId = 100 + weaponType
            weightOrType = CleanName(GetString("SI_WEAPONTYPE", weaponType))
        end
    end

    local traitType = GetItemLinkTraitInfo(itemLink) or ITEM_TRAIT_TYPE_NONE
    local traitName = (traitType ~= ITEM_TRAIT_TYPE_NONE)
        and CleanName(GetString("SI_ITEMTRAITTYPE", traitType))
        or "No Trait"

    local enchantId = GetItemLinkFinalEnchantId(itemLink) or 0
    local enchantName = "No Enchant"
    if enchantId > 0 then
        local searchCat = GetEnchantSearchCategoryType(enchantId)
        if searchCat and searchCat ~= ENCHANTMENT_SEARCH_CATEGORY_NONE then
            enchantName = CleanName(GetString("SI_ENCHANTMENTSEARCHCATEGORYTYPE", searchCat))
        else
            local hasEnchant, header = GetItemLinkEnchantInfo(itemLink)
            if hasEnchant and header and header ~= "" then
                enchantName = CleanName(header)
            end
        end
    end

    return {
        item         = itemName,
        set          = setName,
        setId        = setId,
        subTypeId    = subTypeId,
        weightOrType = weightOrType,
        traitId      = traitType,
        trait        = traitName,
        enchantId    = enchantId,
        enchantment  = enchantName,
    }
end

-- 1. Export Character Info
local function GetCharacterData(buildName)
    local charName  = CleanName(GetUnitName("player"))
    local raceName  = CleanName(GetUnitRace("player"))
    local className = CleanName(GetUnitClass("player"))
    local level     = GetUnitLevel("player")
    local cp        = GetUnitChampionPoints("player")

    local levelText = (level >= 50)
        and string.format("Level %d (CP %d)", level, cp)
        or string.format("Level %d", level)

    local lines = {
        string.format("=== BUILD: %s ===", buildName),
        string.format("Character: %s | Race: %s | Class: %s | %s", charName, raceName, className, levelText),
    }

    return {
        buildName      = buildName,
        name           = charName,
        race           = raceName,
        class          = className,
        level          = level,
        championPoints = cp,
    }, table.concat(lines, "\n")
end

-- 1b. Export Active Class & Subclass Skill Lines
local function GetClassSkillLinesData()
    local lineList = {}
    local displayParts = {}
    local playerClassId = GetUnitClassId("player")

    local numClassLines = GetNumSkillLines(SKILL_TYPE_CLASS)
    for skillLineIndex = 1, numClassLines do
        local lineName, _, discovered, skillLineId, _, _, active =
            GetSkillLineInfo(SKILL_TYPE_CLASS, skillLineIndex)

        -- Include active class/subclass lines (active is true for equipped lines, or fallback to discovered)
        local isEquipped = (active == nil) and discovered or active
        if isEquipped and lineName and lineName ~= "" then
            local cleanLine = CleanName(lineName)
            local sourceClass = ""
            local isSubclass = false

            if GetSkillLineClassId then
                local lineClassId = GetSkillLineClassId(SKILL_TYPE_CLASS, skillLineIndex)
                if lineClassId and lineClassId > 0 and lineClassId ~= playerClassId then
                    isSubclass = true
                    sourceClass = CleanName(GetClassName(GENDER_MALE, lineClassId))
                end
            end

            table.insert(lineList, {
                name        = cleanLine,
                skillLineId = skillLineId or 0,
                isSubclass  = isSubclass,
                sourceClass = sourceClass,
            })

            if isSubclass and sourceClass ~= "" then
                table.insert(displayParts, string.format("%s [Subclass: %s]", cleanLine, sourceClass))
            else
                table.insert(displayParts, cleanLine)
            end
        end
    end

    local text = (#displayParts > 0) and table.concat(displayParts, " | ") or "None"
    return lineList, "=== CLASS / SUBCLASS SKILL LINES ===\n" .. text
end

-- 2. Export Attributes
local function GetAttributesData()
    local mag  = GetAttributeSpentPoints(ATTRIBUTE_MAGICKA)
    local hp   = GetAttributeSpentPoints(ATTRIBUTE_HEALTH)
    local stam = GetAttributeSpentPoints(ATTRIBUTE_STAMINA)

    local lines = {
        "=== ATTRIBUTES ===",
        string.format("Magicka: %d | Health: %d | Stamina: %d", mag, hp, stam),
    }
    return { Magicka = mag, Health = hp, Stamina = stam }, table.concat(lines, "\n")
end

-- 3. Export Mundus Stone(s)
local function GetMundusData()
    local mundusList = {}
    local mundusIds  = {}

    for i = 1, GetNumBuffs("player") do
        local rawName, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        local cleanBuff = CleanName(rawName)
        local strippedName = cleanBuff:match("^Boon:%s*(.+)$")
        local lookupKey = (strippedName or cleanBuff):lower()

        if strippedName or (abilityId and SBE.MUNDUS_ABILITIES[tostring(abilityId)]) then
            local displayName = strippedName or cleanBuff
            local canonicalId = SBE.MUNDUS_NAME_TO_ID[lookupKey] or abilityId or 0
            table.insert(mundusList, displayName)
            table.insert(mundusIds, canonicalId)
        end
    end

    local text = (#mundusList > 0) and table.concat(mundusList, ", ") or "None"
    return mundusList, "=== MUNDUS STONE ===\n" .. text, mundusIds
end

-- 4. Export Equipped Gear
local function GetGearData()
    local gearList = {}
    local lines = { "=== EQUIPPED GEAR ===" }

    for _, entry in ipairs(SBE.EQUIP_SLOTS) do
        local itemLink = GetItemLink(BAG_WORN, entry.slot, LINK_STYLE_DEFAULT)
        if itemLink and itemLink ~= "" then
            local info = InspectItemLink(itemLink)
            info.slot      = entry.name
            info.slotCode  = entry.code
            info.equipSlot = entry.slot
            table.insert(gearList, info)

            local suffix = (info.weightOrType ~= "") and (" (" .. info.weightOrType .. ")") or ""
            table.insert(lines, string.format(
                "%s: %s%s | Set: %s | Trait: %s | Enchant: %s",
                entry.name, info.item, suffix, info.set, info.trait, info.enchantment
            ))
        else
            table.insert(gearList, {
                slot         = entry.name,
                slotCode     = entry.code,
                equipSlot    = entry.slot,
                item         = "[Empty]",
                set          = "",
                setId        = 0,
                subTypeId    = 0,
                weightOrType = "",
                traitId      = 0,
                trait        = "",
                enchantId    = 0,
                enchantment  = "",
            })
            table.insert(lines, string.format("%s: [Empty]", entry.name))
        end
    end

    return gearList, table.concat(lines, "\n")
end

-- 5. Export Champion Points
local function GetChampionData()
    local cpList = {}
    local lines = { "=== CHAMPION POINTS (SLOTTABLES) ===" }

    for slotIndex = 1, 12 do
        local skillId = GetSlotBoundId(slotIndex, HOTBAR_CATEGORY_CHAMPION)
        if skillId and skillId > 0 then
            local skillName = CleanName(GetChampionSkillName(skillId))
            local points = GetNumPointsSpentOnChampionSkill(skillId)
            local disciplineId = GetRequiredChampionDisciplineIdForSlot(slotIndex, HOTBAR_CATEGORY_CHAMPION)
            local disciplineName = (disciplineId and disciplineId > 0)
                and CleanName(GetChampionDisciplineName(disciplineId))
                or "Unknown"

            table.insert(cpList, {
                slot       = slotIndex,
                skillId    = skillId,
                discipline = disciplineName,
                name       = skillName,
                points     = points,
            })

            table.insert(lines, string.format(
                "Slot %d [%s]: %s (%d pts)",
                slotIndex, disciplineName, skillName, points
            ))
        end
    end

    if #cpList == 0 then
        table.insert(lines, "No CP slottables assigned.")
    end

    return cpList, table.concat(lines, "\n")
end

-- 6. Export Active Skill Bars & Scribed Scripts
local function ExportActionBar(barCategory, barLabel)
    local barList = {}
    local lines = { string.format("=== %s ===", barLabel) }

    for slotIndex = 3, 8 do
        local slotLabel = (slotIndex == 8) and "Ultimate" or ("Slot " .. (slotIndex - 2))
        local actionType = GetSlotType(slotIndex, barCategory)
        local boundId = GetSlotBoundId(slotIndex, barCategory)

        if boundId and boundId > 0 then
            if actionType == ACTION_TYPE_CRAFTED_ABILITY then
                local abilityId = GetAbilityIdForCraftedAbilityId(boundId)
                local abilityName = CleanName(GetAbilityName(abilityId))
                local focusId, sigId, affixId = GetCraftedAbilityActiveScriptIds(boundId)

                local focusName = (focusId and focusId > 0) and CleanName(GetCraftedAbilityScriptDisplayName(focusId)) or "None"
                local sigName   = (sigId and sigId > 0) and CleanName(GetCraftedAbilityScriptDisplayName(sigId)) or "None"
                local affixName = (affixId and affixId > 0) and CleanName(GetCraftedAbilityScriptDisplayName(affixId)) or "None"

                table.insert(barList, {
                    slotIndex        = slotIndex,
                    slot             = slotLabel,
                    name             = abilityName,
                    isScribed        = true,
                    craftedAbilityId = boundId,
                    abilityId        = abilityId,
                    scriptIds        = { focus = focusId or 0, signature = sigId or 0, affix = affixId or 0 },
                    scripts          = {
                        focus     = focusName,
                        signature = sigName,
                        affix     = affixName,
                    },
                })

                table.insert(lines, string.format(
                    "%s: %s [Scribed] -> Focus: %s | Signature: %s | Affix: %s",
                    slotLabel, abilityName, focusName, sigName, affixName
                ))
            else
                local abilityName = CleanName(GetAbilityName(boundId))
                table.insert(barList, {
                    slotIndex = slotIndex,
                    slot      = slotLabel,
                    name      = abilityName,
                    abilityId = boundId,
                    isScribed = false,
                })

                table.insert(lines, string.format("%s: %s", slotLabel, abilityName))
            end
        else
            table.insert(barList, {
                slotIndex = slotIndex,
                slot      = slotLabel,
                name      = "[Empty]",
                isScribed = false,
            })
            table.insert(lines, string.format("%s: [Empty]", slotLabel))
        end
    end

    return barList, table.concat(lines, "\n")
end

-- 7. Export Unlocked Passive Skills
local function GetPassivesData()
    local passivesByLine = {}
    local lines = { "=== UNLOCKED PASSIVES ===" }

    for skillType = 1, GetNumSkillTypes() do
        if skillType ~= SKILL_TYPE_TRADESKILL then
            for skillLineIndex = 1, GetNumSkillLines(skillType) do
                local lineName, _, discovered, _, _, _, active = GetSkillLineInfo(skillType, skillLineIndex)
                local isLineActive = (skillType ~= SKILL_TYPE_CLASS) or ((active == nil) and discovered or active)

                if discovered and isLineActive then
                    local cleanLine = CleanName(lineName)
                    local upperLine = cleanLine:upper()
                    local isNonCombat = upperLine:find("SCRY") or upperLine:find("EXCAVAT")
                        or upperLine:find("LEGERDEMAIN") or upperLine:find("THIEVES")
                        or upperLine:find("DARK BROTHERHOOD")

                    if not isNonCombat then
                        local unlockedInLine = {}
                        local textParts = {}

                        for skillIndex = 1, GetNumSkillAbilities(skillType, skillLineIndex) do
                            local abilityName, _, _, isPassive, _, purchased, _, rank =
                                GetSkillAbilityInfo(skillType, skillLineIndex, skillIndex)

                            if isPassive and purchased then
                                local cleanAbility = CleanName(abilityName)
                                local abilityId = GetSkillAbilityId(skillType, skillLineIndex, skillIndex, false) or 0
                                local maxRank = GetNumPassiveSkillRanks(skillType, skillLineIndex, skillIndex)
                                local curRank = rank or 1
                                local totalRank = maxRank or 1

                                table.insert(unlockedInLine, {
                                    name      = cleanAbility,
                                    abilityId = abilityId,
                                    rank      = curRank,
                                    maxRank   = totalRank,
                                })

                                local r = (totalRank > 1)
                                    and string.format("%s (%d/%d)", cleanAbility, curRank, totalRank)
                                    or cleanAbility
                                table.insert(textParts, r)
                            end
                        end

                        if #unlockedInLine > 0 then
                            table.insert(passivesByLine, {
                                skillLine = cleanLine,
                                passives  = unlockedInLine,
                            })
                            table.insert(lines, string.format("%s: %s", cleanLine, table.concat(textParts, ", ")))
                        end
                    end
                end
            end
        end
    end

    if #passivesByLine == 0 then
        table.insert(lines, "No passives unlocked.")
    end

    return passivesByLine, table.concat(lines, "\n")
end

-- Auto-equip matching gear pieces from BAG_BACKPACK
local function AutoEquipGearFromBackpack(gearList)
    if not gearList or #gearList == 0 then return 0 end

    local usedBagSlots = {}
    local equippedCount = 0

    for _, target in ipairs(gearList) do
        local equipSlot = target.equipSlot or (target.slot and SBE.SLOT_NAME_TO_ENUM[target.slot:lower()])
        local hasTargetSetId = target.setId and target.setId > 0
        local hasTargetItem  = target.item and target.item ~= "" and target.item ~= "[Empty]"
        local hasTargetSet   = target.set and target.set ~= "" and target.set ~= "No Set"

        if equipSlot and (hasTargetSetId or hasTargetItem or hasTargetSet) then
            local wornLink = GetItemLink(BAG_WORN, equipSlot, LINK_STYLE_DEFAULT)
            local alreadyWearing = false
            if wornLink and wornLink ~= "" then
                local wornInfo = InspectItemLink(wornLink)
                local setMatch = hasTargetSetId
                    and (wornInfo.setId == target.setId)
                    or (wornInfo.set:lower() == (target.set or ""):lower())
                local weightMatch = (target.weightOrType == "" or wornInfo.weightOrType:lower() == target.weightOrType:lower())
                local traitMatch = (target.traitId and target.traitId > 0)
                    and (wornInfo.traitId == target.traitId)
                    or (wornInfo.trait:lower() == (target.trait or ""):lower())
                if setMatch and weightMatch and traitMatch then
                    alreadyWearing = true
                end
            end

            if not alreadyWearing then
                local bestBagSlot = nil
                local bestScore = 0
                local bagSize = GetBagSize(BAG_BACKPACK)

                for bagSlot = 0, bagSize - 1 do
                    if not usedBagSlots[bagSlot] and CanEquipItem(BAG_BACKPACK, bagSlot, equipSlot) then
                        local link = GetItemLink(BAG_BACKPACK, bagSlot, LINK_STYLE_DEFAULT)
                        if link and link ~= "" then
                            local info = InspectItemLink(link)
                            local matchesPrimary = false
                            if hasTargetSetId and info.setId == target.setId then
                                matchesPrimary = true
                            elseif hasTargetSet and info.set:lower() == target.set:lower() then
                                matchesPrimary = true
                            elseif hasTargetItem and info.item:lower() == target.item:lower() then
                                matchesPrimary = true
                            end

                            if matchesPrimary then
                                local score = 1
                                if target.weightOrType ~= "" and info.weightOrType:lower() == target.weightOrType:lower() then
                                    score = score + 2
                                end
                                if (target.traitId and target.traitId > 0 and info.traitId == target.traitId)
                                    or (target.trait ~= "" and info.trait:lower() == target.trait:lower()) then
                                    score = score + 2
                                end
                                if (target.enchantId and target.enchantId > 0 and info.enchantId == target.enchantId)
                                    or (target.enchantment and target.enchantment ~= "" and info.enchantment:lower() == target.enchantment:lower()) then
                                    score = score + 1
                                end
                                if score > bestScore then
                                    bestScore = score
                                    bestBagSlot = bagSlot
                                end
                            end
                        end
                    end
                end

                if bestBagSlot ~= nil then
                    usedBagSlots[bestBagSlot] = true
                    EquipItem(BAG_BACKPACK, bestBagSlot, equipSlot)
                    equippedCount = equippedCount + 1
                end
            end
        end
    end

    return equippedCount
end

-- Apply Gear, Skills & Champion Points
function SBE.ApplyBuild()
    ResetDeleteState()

    if IsUnitInCombat("player") then
        d(CHAT_TAG .. " Cannot apply build while in combat.")
        return
    end

    local build = selectedBuildData
    local currentText = editBox and editBox:GetText() or ""
    if not build or (build.formattedText and build.formattedText ~= currentText) then
        build = SBE.ParseBuildText(currentText)
    end

    local gearApplied   = AutoEquipGearFromBackpack(build.gear)
    local skillsApplied = 0
    local cpApplied     = 0

    local bars = {
        { category = HOTBAR_CATEGORY_PRIMARY, list = build.skills and build.skills.frontBar or {} },
        { category = HOTBAR_CATEGORY_BACKUP,  list = build.skills and build.skills.backBar or {} },
    }

    for _, bar in ipairs(bars) do
        for _, entry in ipairs(bar.list) do
            if entry.name and entry.name ~= "[Empty]" and entry.slotIndex then
                if entry.isScribed and entry.craftedAbilityId then
                    SelectSlotCraftedAbility(entry.craftedAbilityId, entry.slotIndex, bar.category)
                    skillsApplied = skillsApplied + 1
                elseif entry.abilityId then
                    SelectSlotAbility(entry.abilityId, entry.slotIndex, bar.category)
                    skillsApplied = skillsApplied + 1
                else
                    local foundId, isCrafted = SBE.FindAbilityIdByName(entry.name)
                    if foundId then
                        if isCrafted then
                            SelectSlotCraftedAbility(foundId, entry.slotIndex, bar.category)
                        else
                            SelectSlotAbility(foundId, entry.slotIndex, bar.category)
                        end
                        skillsApplied = skillsApplied + 1
                    end
                end
            end
        end
    end

    if build.championPoints and #build.championPoints > 0 then
        PrepareChampionPurchaseRequest(false)
        for _, cp in ipairs(build.championPoints) do
            if cp.slot and cp.skillId then
                AddHotbarSlotToChampionPurchaseRequest(cp.slot, cp.skillId)
                cpApplied = cpApplied + 1
            end
        end
        SendChampionPurchaseRequest()
    end

    d(string.format("%s Equipped %d gear items, %d skills, and %d CP slottables.", CHAT_TAG, gearApplied, skillsApplied, cpApplied))
end

-- Helper: Get the raw underlying SavedVariables table so pairs() always sees every saved build
local function GetBuildsTable()
    if ShosBuildExporterSV
        and ShosBuildExporterSV["Default"]
        and ShosBuildExporterSV["Default"][GetDisplayName()]
        and ShosBuildExporterSV["Default"][GetDisplayName()]["$AccountWide"] then
        return ShosBuildExporterSV["Default"][GetDisplayName()]["$AccountWide"]
    end
    return SBE.savedVariables
end

local function SetBuildBoxText(text)
    if not editBox then return end
    editBox:SetText(text or "")
    editBox:SetCursorPosition(0)
    if mainWindow and mainWindow.scrollContainer then
        -- Defer one frame so GetTextHeight() has updated before resetting to top
        zo_callLater(function()
            if mainWindow and mainWindow.scrollContainer then
                ZO_Scroll_UpdateScrollBar(mainWindow.scrollContainer)
                ZO_Scroll_ResetToTop(mainWindow.scrollContainer)
            end
        end, 10)
    end
end

local function RefreshDropdown()
    if not charDropdown then return end
    charDropdown:ClearItems()

    local count = 0
    local currentAccount = GetDisplayName()
    local server         = GetWorldName()
    local selectedEntryData = nil

    -- Helper to add a build entry to the dropdown
    local function addBuildEntry(buildKey, data, ownerAccount, ownerTable)
        if buildKey == "version" or type(data) ~= "table" then return end

        local codeStr = data.code or data.chatString
        local fullStr = data.formattedText
        if not (codeStr or fullStr) then return end

        count = count + 1
        local bName = data.name or data.buildName or "Default"
        -- Show (@Account) tag on builds from other accounts
        local label = (ownerAccount and ownerAccount ~= currentAccount)
            and string.format("%s (%s)", bName, ownerAccount)
            or bName

        if selectedBuildKey == buildKey then
            selectedEntryData = data
        end

        local entry = charDropdown:CreateItemEntry(label, function()
            ResetDeleteState()
            selectedBuildKey   = buildKey
            selectedBuildTable = ownerTable -- Optional: lets Delete know which table owns it

            if codeStr then
                local decodedText, parsedBuild = SBE.DecodeToFullText(data)
                parsedBuild.formattedText = decodedText
                parsedBuild.chatString    = codeStr
                selectedBuildData         = parsedBuild
                SetBuildBoxText(decodedText)
            else
                local parsedBuild = SBE.ParseBuildText(fullStr)
                parsedBuild.formattedText = fullStr
                parsedBuild.chatString    = data.chatString
                selectedBuildData         = parsedBuild
                SetBuildBoxText(fullStr)
            end

            if nameEditBox then
                nameEditBox:SetText(bName)
            end
        end)
        charDropdown:AddItem(entry)
    end

    -- 1. All Accounts' Saved Builds in ShosBuildExporterSV
    local rawDefault = ShosBuildExporterSV and ShosBuildExporterSV["Default"]
    if type(rawDefault) == "table" then
        for accountName, accountData in pairs(rawDefault) do
            local acctWide = type(accountData) == "table" and accountData["$AccountWide"]
            if type(acctWide) == "table" then
                for buildKey, data in pairs(acctWide) do
                    addBuildEntry(buildKey, data, accountName, acctWide)
                end
            end
        end
    else
        -- Fallback to single-account GetBuildsTable()
        local buildsTbl = GetBuildsTable()
        if type(buildsTbl) == "table" then
            for buildKey, data in pairs(buildsTbl) do
                addBuildEntry(buildKey, data, currentAccount, buildsTbl)
            end
        end
    end

        -- 2. Recent Builds Captured from In-Game Chat (Temporary — not saved to disk)
    for idx = #recentChatBuilds, 1, -1 do
        local chatEntry = recentChatBuilds[idx]
        count = count + 1
        local rawName = chatEntry.name or "Shared Build"
        local label = string.format("[Chat - Unsaved] %s (%s)", rawName, chatEntry.sender or "?")

        local item = charDropdown:CreateItemEntry(label, function()
            ResetDeleteState()
            selectedBuildKey   = nil
            selectedBuildTable = nil
            local decodedText, parsedBuild = SBE.DecodeToFullText(chatEntry)
            parsedBuild.formattedText = decodedText
            parsedBuild.chatString    = chatEntry.code
            selectedBuildData         = parsedBuild

            SetBuildBoxText(decodedText)
            if nameEditBox then
                nameEditBox:SetText(parsedBuild.buildName or chatEntry.name or "")
            end

        end)
        charDropdown:AddItem(item)
    end

    if count == 0 then
        charDropdown:SetSelectedItemText("No saved builds yet")
    elseif selectedEntryData then
        charDropdown:SetSelectedItemText(selectedEntryData.name or selectedEntryData.buildName or selectedBuildKey)
    else
        charDropdown:SetSelectedItemText(string.format("Select a build (%d available)...", count))
    end
end

-- Register the overwrite confirmation dialog once (e.g., inside OnAddonLoaded)
ZO_Dialogs_RegisterCustomDialog("SBE_CONFIRM_OVERWRITE", {
    gamepadInfo = {
        dialogType = GAMEPAD_DIALOGS.BASIC,
    },
    title = {
        text = "Overwrite Saved Build?",
    },
    mainText = {
        text = "A build named '<<1>>' already exists. Do you want to overwrite it?",
    },
    buttons = {
        {
            text = SI_DIALOG_YES,
            callback = function(dialog)
                if dialog.data and dialog.data.onConfirm then
                    dialog.data.onConfirm()
                end
            end,
        },
        {
            text = SI_DIALOG_NO,
        },
    },
})

local function ExecuteSaveBuild(storageKey, buildName, charName, raceName, className, compactCode, parsedForNames)
    local lookupData = parsedForNames or selectedBuildData or SBE.ParseBuildText(compactCode)
    SBE.RecordLookupNames(GetBuildsTable(), lookupData)

    SBE.savedVariables[storageKey] = {
        ts    = GetTimeStamp(),
        name  = buildName,
        char  = charName,
        race  = raceName,
        class = className,
        code  = compactCode,
    }

    selectedBuildKey = storageKey
    RefreshDropdown()
    d(string.format("%s Saved '%s' (%d bytes) to SavedVariables.", CHAT_TAG, storageKey, #compactCode))
end

-- Save current exported or pasted build compactly to SavedVariables
function SBE.SaveCurrentBuild()
    ResetDeleteState()

    local buildName = SBE.Trim(nameEditBox and nameEditBox:GetText() or "")
    if buildName == "" then
        d(CHAT_TAG .. " Please enter a build name before clicking Save Build.")
        if nameEditBox then
            nameEditBox:TakeFocus()
        end
        return
    end

    local currentText = editBox and Trim(editBox:GetText()) or ""
    if currentText == "" then
        d(CHAT_TAG .. " Nothing to save. Click 'Export Current' or paste a build first.")
        return
    end

    -- Default to current player ONLY if the build doesn't already carry character metadata
    local charName  = CleanName(GetUnitName("player"))
    local raceName  = CleanName(GetUnitRace("player"))
    local className = CleanName(GetUnitClass("player"))

    local compactCode = currentText:match("(%[SBE2%|.-%])")
    local parsedForNames = nil

    if selectedBuildData and selectedBuildData.formattedText == currentText and selectedBuildData.chatString then
        compactCode = selectedBuildData.chatString
        parsedForNames = selectedBuildData
        if selectedBuildData.character then
            charName  = selectedBuildData.character.name or charName
            raceName  = selectedBuildData.character.race or raceName
            className = selectedBuildData.character.class or className
        end
    elseif compactCode then
        parsedForNames = SBE.ParseBuildText(compactCode)
        if parsedForNames and parsedForNames.character then
            charName  = parsedForNames.character.name or charName
            raceName  = parsedForNames.character.race or raceName
            className = parsedForNames.character.class or className
        end
    else
        local parsed = SBE.ParseBuildText(currentText)
        parsed.buildName = buildName

        -- Preserve character info from the loaded build or parsed text before falling back to current player
        local origChar = (parsed.character and parsed.character.name and parsed.character)
                      or (selectedBuildData and selectedBuildData.character)

        if origChar then
            charName  = origChar.name or charName
            raceName  = origChar.race or raceName
            className = origChar.class or className
        end

        parsed.character = { name = charName, race = raceName, class = className }
        compactCode = SBE.BuildSingleLineChatCode(parsed)
        parsedForNames = parsed
    end

    -- Ensure the 2nd pipe field inside compactCode ([SBE2|Class|<BuildName>|...]) matches buildName
    if compactCode then
        local safeName = buildName:gsub("[|%[%]]", "")
        compactCode = compactCode:gsub("^(%[SBE2|[^|]+|)[^|]*(|)", "%1" .. safeName .. "%2", 1)
    end
    if parsedForNames then
        parsedForNames.buildName  = buildName
        parsedForNames.chatString = compactCode
    end

    -- Save using ONLY the exact build name entered in the text box
    local storageKey = buildName
    local buildsTbl  = GetBuildsTable()

    if buildsTbl and buildsTbl[storageKey] then
        ZO_Dialogs_ShowDialog("SBE_CONFIRM_OVERWRITE", {
            onConfirm = function()
                ExecuteSaveBuild(storageKey, buildName, charName, raceName, className, compactCode, parsedForNames)
            end,
        }, {
            mainTextParams = { buildName },
        })
    else
        ExecuteSaveBuild(storageKey, buildName, charName, raceName, className, compactCode, parsedForNames)
    end
end

function SBE.DeleteSelectedBuild()
    local buildsTbl = GetBuildsTable()
    local exists = selectedBuildKey and (
        (buildsTbl and buildsTbl[selectedBuildKey] ~= nil)
        or (SBE.savedVariables and SBE.savedVariables[selectedBuildKey] ~= nil)
    )

    if not exists then
        d(CHAT_TAG .. " Select a saved build from the dropdown first to delete it.")
        return
    end

    if pendingDeleteKey ~= selectedBuildKey then
        pendingDeleteKey = selectedBuildKey
        if deleteBtn then
            deleteBtn:SetText("|cff4444Confirm Delete?|r")
        end
        d(string.format("%s Click 'Confirm Delete?' again to permanently delete '%s'.", CHAT_TAG, selectedBuildKey))
        return
    end

    local deletedName = selectedBuildKey
    if buildsTbl then buildsTbl[deletedName] = nil end
    if SBE.savedVariables then SBE.savedVariables[deletedName] = nil end

    selectedBuildKey  = nil
    selectedBuildData = nil
    ResetDeleteState()
    if editBox then editBox:SetText("") end
    RefreshDropdown()

    d(string.format("%s Deleted saved build '%s'.", CHAT_TAG, deletedName))
end

local function CloseBuildWindow()
    ResetDeleteState()
    if mainWindow then
        mainWindow:SetHidden(true)
    end
    SetGameCameraUIMode(false)
end

local function ShowBuildWindow(initialText, initialBuild)
    if not mainWindow then
        local wm = WINDOW_MANAGER
        mainWindow = wm:CreateTopLevelWindow("ShosBuildExporterWindow")
        mainWindow:SetDimensions(780, 670)
        mainWindow:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        mainWindow:SetMovable(true)
        mainWindow:SetMouseEnabled(true)
        mainWindow:SetClampedToScreen(true)

        local bg = wm:CreateControlFromVirtual("$(parent)BG", mainWindow, "ZO_DefaultBackdrop")
        bg:SetAnchorFill()

        -- Top Header: Addon Title (colored) + Author (colored) + Version
        local title = wm:CreateControl("$(parent)Title", mainWindow, CT_LABEL)
        title:SetFont("ZoFontWinH2")
        title:SetText(COLORED_TITLE)
        title:SetAnchor(TOPLEFT, mainWindow, TOPLEFT, 16, 10)

        local metaLabel = wm:CreateControl("$(parent)Meta", mainWindow, CT_LABEL)
        metaLabel:SetFont("ZoFontGameSmall")
        metaLabel:SetText(string.format("Author: %s  |  Version: %s", COLORED_AUTHOR, SBE.version))
        metaLabel:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 2)

        local closeBtn = wm:CreateControlFromVirtual("$(parent)Close", mainWindow, "ZO_CloseButton")
        closeBtn:SetAnchor(TOPRIGHT, mainWindow, TOPRIGHT, -12, 12)
        closeBtn:SetHandler("OnClicked", CloseBuildWindow)

        -- Row 1: Saved Builds Dropdown + Delete Build Button
        local dropLabel = wm:CreateControl("$(parent)DropLabel", mainWindow, CT_LABEL)
        dropLabel:SetFont("ZoFontGameBold")
        dropLabel:SetText("Saved Builds:")
        dropLabel:SetAnchor(TOPLEFT, mainWindow, TOPLEFT, 16, 62)

        local dropControl = wm:CreateControlFromVirtual("$(parent)Dropdown", mainWindow, "ZO_ComboBox")
        dropControl:SetDimensions(450, 28)
        dropControl:SetAnchor(LEFT, dropLabel, RIGHT, 10, 0)
        charDropdown = ZO_ComboBox_ObjectFromContainer(dropControl)
        charDropdown:SetSortsItems(false)

        deleteBtn = wm:CreateControlFromVirtual("$(parent)DeleteBtn", mainWindow, "ZO_DefaultButton")
        deleteBtn:SetDimensions(150, 28)
        deleteBtn:SetText("Delete Build")
        deleteBtn:SetAnchor(LEFT, dropControl, RIGHT, 12, 0)
        deleteBtn:SetHandler("OnClicked", function() SBE.DeleteSelectedBuild() end)

        -- Row 2: Custom Build Name Input + Export Current Button
        local nameLabel = wm:CreateControl("$(parent)NameLabel", mainWindow, CT_LABEL)
        nameLabel:SetFont("ZoFontGameBold")
        nameLabel:SetText("Build Name:")
        nameLabel:SetAnchor(TOPLEFT, mainWindow, TOPLEFT, 16, 100)

        local nameBackdrop = wm:CreateControlFromVirtual("$(parent)NameBG", mainWindow, "ZO_EditBackdrop")
        nameBackdrop:SetDimensions(450, 28)
        nameBackdrop:SetAnchor(LEFT, nameLabel, RIGHT, 20, 0)

        nameEditBox = wm:CreateControlFromVirtual("$(parent)NameBox", nameBackdrop, "ZO_DefaultEditForBackdrop")
        nameEditBox:SetMaxInputChars(60)
        nameEditBox:SetText("")
        nameEditBox:SetAnchorFill()

        local exportBtn = wm:CreateControlFromVirtual("$(parent)ExportBtn", mainWindow, "ZO_DefaultButton")
        exportBtn:SetDimensions(150, 28)
        exportBtn:SetText("Export Current")
        exportBtn:SetAnchor(LEFT, nameBackdrop, RIGHT, 12, 0)
        exportBtn:SetHandler("OnClicked", function()
            SBE.ExportBuild(nameEditBox:GetText())
        end)

        -- Scrollable Build Checklist / Paste Box (Full clean box)
        local editBackdrop = wm:CreateControlFromVirtual("$(parent)EditBG", mainWindow, "ZO_EditBackdrop")
        editBackdrop:SetAnchor(TOPLEFT, mainWindow, TOPLEFT, 16, 138)
        editBackdrop:SetAnchor(BOTTOMRIGHT, mainWindow, BOTTOMRIGHT, -16, -72)

        editBox = wm:CreateControlFromVirtual("$(parent)EditBox", editBackdrop, "ZO_DefaultEditMultiLineForBackdrop")
        editBox:SetMaxInputChars(25000)
        editBox:SetAnchor(TOPLEFT, editBackdrop, TOPLEFT, 8, 8)
        editBox:SetAnchor(BOTTOMRIGHT, editBackdrop, BOTTOMRIGHT, -8, -8)
        editBox:SetHandler("OnTextChanged", function(self)
            local txt = self:GetText() or ""
            local pastedName = txt:match("%[SBE2|[^|]+|([^|%]]+)|")
                            or txt:match("=== BUILD:%s*(.-)%s*===")

            if pastedName and SBE.Trim(pastedName) ~= "" and nameEditBox then
                local currentName = SBE.Trim(nameEditBox:GetText() or "")
                if currentName == "" then
                    nameEditBox:SetText(SBE.Trim(pastedName))
                end
            end
        end)

        -- Bottom Action Bar: Save Build | Apply Build | Send to Chat | Select All | Clear
        local saveBtn = wm:CreateControlFromVirtual("$(parent)SaveBtn", mainWindow, "ZO_DefaultButton")
        saveBtn:SetDimensions(135, 30)
        saveBtn:SetText("Save Build")
        saveBtn:SetAnchor(BOTTOMLEFT, mainWindow, BOTTOMLEFT, 16, -32)
        saveBtn:SetHandler("OnClicked", function() SBE.SaveCurrentBuild() end)

        applyBtn = wm:CreateControlFromVirtual("$(parent)ApplyBtn", mainWindow, "ZO_DefaultButton")
        applyBtn:SetDimensions(135, 30)
        applyBtn:SetText("Apply Build")
        applyBtn:SetAnchor(LEFT, saveBtn, RIGHT, 10, 0)
        applyBtn:SetHandler("OnClicked", function() SBE.ApplyBuild() end)

        local chatShareBtn = wm:CreateControlFromVirtual("$(parent)ChatShareBtn", mainWindow, "ZO_DefaultButton")
        chatShareBtn:SetDimensions(145, 30)
        chatShareBtn:SetText("Send to Chat")
        chatShareBtn:SetAnchor(LEFT, applyBtn, RIGHT, 10, 0)
        chatShareBtn:SetHandler("OnClicked", function()
            ResetDeleteState()
            if selectedBuildData and selectedBuildData.chatString then
                local customName = SBE.Trim(nameEditBox and nameEditBox:GetText() or "")
                local activeName = (customName ~= "" and customName) or selectedBuildData.buildName or "Build"
                local safeName   = activeName:gsub("[|%[%]]", "")

                local code = selectedBuildData.chatString:gsub("^(%[SBE2|[^|]+|)[^|]*(|)", "%1" .. safeName .. "%2", 1)
                selectedBuildData.chatString = code
                selectedBuildData.buildName  = activeName

                SBE.SendBuildToChat(code)
            else
                d(CHAT_TAG .. " Export or select a saved build first to send to chat.")
            end
        end)

        local selectAllBtn = wm:CreateControlFromVirtual("$(parent)SelectAllBtn", mainWindow, "ZO_DefaultButton")
        selectAllBtn:SetDimensions(135, 30)
        selectAllBtn:SetText("Select All")
        selectAllBtn:SetAnchor(LEFT, chatShareBtn, RIGHT, 10, 0)
        selectAllBtn:SetHandler("OnClicked", function()
            ResetDeleteState()
            editBox:TakeFocus()
            editBox:SelectAll()
        end)

        local clearBtn = wm:CreateControlFromVirtual("$(parent)ClearBtn", mainWindow, "ZO_DefaultButton")
        clearBtn:SetDimensions(135, 30)
        clearBtn:SetText("Clear")
        clearBtn:SetAnchor(LEFT, selectAllBtn, RIGHT, 10, 0)
        clearBtn:SetHandler("OnClicked", function()
            ResetDeleteState()
            selectedBuildData = nil
            selectedBuildKey  = nil
            SetBuildBoxText("")
            if nameEditBox then
                nameEditBox:SetText("")
            end
            editBox:TakeFocus()
        end)

        -- Bottom Footer Hint
        local hintLabel = wm:CreateControl("$(parent)ClipboardHint", mainWindow, CT_LABEL)
        hintLabel:SetFont("ZoFontGameSmall")
        hintLabel:SetColor(0.7, 0.7, 0.7, 1)
        hintLabel:SetText("Note: Use Ctrl+C to copy and Ctrl+V to paste inside the build field.")
        hintLabel:SetAnchor(BOTTOMLEFT, mainWindow, BOTTOMLEFT, 18, -10)
    end

    ResetDeleteState()
    RefreshDropdown()

        if initialText then
        selectedBuildData = initialBuild
        selectedBuildKey  = nil
        SetBuildBoxText(initialText)
    end

    mainWindow:SetHidden(false)
    SetGameCameraUIMode(true)
end

local pendingChatChunks = {}
local MAX_CHAT_LEN = 260 -- Safe margin under ESO's 350-character chat box cap

function SBE.SendBuildToChat(fullCode)
    pendingChatChunks = {}

    -- Strip outer brackets [SBE2|...] -> body
    local body = fullCode:match("^%[SBE2|(.+)%]$")
    if not body or #fullCode <= MAX_CHAT_LEN then
        StartChatInput(fullCode)
        return
    end

    local chunkSize = MAX_CHAT_LEN - 15
    local rawParts = {}
    for i = 1, #body, chunkSize do
        table.insert(rawParts, body:sub(i, i + chunkSize - 1))
    end

    local total = #rawParts
    for idx, partBody in ipairs(rawParts) do
        table.insert(pendingChatChunks, string.format("[SBE2:%d/%d|%s]", idx, total, partBody))
    end

    -- Load Part 1 into chat input box with the preserved channel and target
    local firstChunk = table.remove(pendingChatChunks, 1)
    StartChatInput(firstChunk)
    d(string.format("%s Build split into %d chat parts. Press Enter to send Part 1/%d!", CHAT_TAG, total, total))
end

-- === 2. Step 2 (incomingMultipart + updated OnChatMessage) goes right below it ===
local incomingMultipart = {} -- Keyed by sender display name

local function OnChatMessage(_, channelType, fromName, text, isCustomerService, fromDisplayName)
    if not text then return end
    local sender = CleanName(fromDisplayName ~= "" and fromDisplayName or fromName)

    -- Normalize ESO's escaped double-pipes ("||" -> "|") before matching
    local cleanText = text:gsub("||", "|")

    -- Identify if this message was sent by YOU (handles both whispers and normal channels)
    local isOwnMessage = (channelType == CHAT_CHANNEL_WHISPER_SENT) or (sender == CleanName(GetDisplayName()))

        if isOwnMessage then
        -- 1. If we just sent a chunk from our own queue, load the next chunk into the chat box
        if #pendingChatChunks > 0 and cleanText:find("%[SBE2:") then
            local nextChunk = table.remove(pendingChatChunks, 1)
            local replyChannel = (channelType == CHAT_CHANNEL_WHISPER_SENT) and CHAT_CHANNEL_WHISPER or channelType
            local replyTarget  = (channelType == CHAT_CHANNEL_WHISPER_SENT) and sender or nil

            zo_callLater(function()
                StartChatInput(nextChunk, replyChannel, replyTarget)
                d(string.format("%s Next part ready — press Enter to send! (%d remaining)", CHAT_TAG, #pendingChatChunks))
            end, 150)
        end
        -- Always stop here so we never receive/import our own sent messages
        return
    end

    -- 2. Check for multi-part packet from OTHER players: [SBE2:part/total|body]
    local partStr, totalStr, partBody = cleanText:match("%[SBE2:(%d+)/(%d+)%|(.-)%]")
    if not partStr then
        partStr, totalStr, partBody = cleanText:match("%[SBE2:(%d+)/(%d+)%|(.+)")
    end

    local completeCode = nil

    if partStr and totalStr and partBody then
        local part  = tonumber(partStr)
        local total = tonumber(totalStr)

        if part == 1 or not incomingMultipart[sender] or incomingMultipart[sender].total ~= total then
            incomingMultipart[sender] = { total = total, parts = {}, received = 0 }
        end

        local buffer = incomingMultipart[sender]
        if not buffer.parts[part] then
            buffer.parts[part] = partBody
            buffer.received = buffer.received + 1
        end

        if buffer.received < total then
            d(string.format("%s Received build part %d/%d from %s — waiting for remaining part(s)...", CHAT_TAG, buffer.received, total, sender))
            return
        end

        -- All parts received: stitch back into standard [SBE2|...] format
        local ordered = {}
        for i = 1, total do
            table.insert(ordered, buffer.parts[i] or "")
        end
        completeCode = "[SBE2|" .. table.concat(ordered, "") .. "]"
        incomingMultipart[sender] = nil
    else
        -- 3. Standard single-part [SBE2|...] code
        completeCode = cleanText:match("(%[SBE2%|.-%])") or cleanText:match("(%[SBE2%|.+)")
        if completeCode and completeCode:sub(-1) ~= "]" then
            completeCode = completeCode .. "]"
        end
    end

    if not completeCode then return end

    local parsed = SBE.ParseBuildText(completeCode)
    local bName  = parsed.buildName or "Shared Build"
    local cls    = (parsed.character and parsed.character.class) or "?"

    if #recentChatBuilds > 0 and recentChatBuilds[#recentChatBuilds].code == completeCode then
        return
    end

    table.insert(recentChatBuilds, {
        sender = sender,
        name   = bName,
        class  = cls,
        char   = (parsed.character and parsed.character.name) or sender,
        race   = (parsed.character and parsed.character.race) or "",
        level  = parsed.character and parsed.character.level or nil,
        cp     = parsed.character and parsed.character.cp or nil,
        code   = completeCode,
    })

    if #recentChatBuilds > 15 then
        table.remove(recentChatBuilds, 1)
    end

    if mainWindow and not mainWindow:IsHidden() then
        RefreshDropdown()
    end

    d(string.format("%s Captured build '%s' (%s) from %s! Type /shoimport to load or apply it.", CHAT_TAG, bName, cls, sender))
end

function SBE.ExportBuild(argText)
    local buildName = Trim(argText)
    if buildName == "" and nameEditBox then
        buildName = Trim(nameEditBox:GetText())
    end
    if buildName == "" then
        buildName = "Default"
    end

    local charData, charText             = GetCharacterData(buildName)
    local classLinesData, classLinesText = GetClassSkillLinesData()
    local attrData, attrText             = GetAttributesData()
    local mundusData, mundusText, mIds   = GetMundusData()
    local gearData, gearText             = GetGearData()
    local cpData, cpText                 = GetChampionData()
    local frontData, frontText           = ExportActionBar(HOTBAR_CATEGORY_PRIMARY, "FRONT BAR")
    local backData, backText             = ExportActionBar(HOTBAR_CATEGORY_BACKUP, "BACK BAR")
    local passData, passText             = GetPassivesData()

    local fullText = table.concat({
        charText,
        classLinesText,
        attrText,
        mundusText,
        gearText,
        cpText,
        frontText,
        backText,
        passText,
    }, "\n\n")

    local buildRecord = {
        timestamp      = GetTimeStamp(),
        buildName      = buildName,
        character      = charData,
        classLines     = classLinesData,
        attributes     = attrData,
        mundus         = mundusData,
        mundusIds      = mIds,
        gear           = gearData,
        championPoints = cpData,
        skills         = {
            frontBar = frontData,
            backBar  = backData,
        },
        passives      = passData,
        formattedText = fullText,
    }
    buildRecord.chatString = SBE.BuildSingleLineChatCode(buildRecord)

    ShowBuildWindow(fullText, buildRecord)
    if nameEditBox then nameEditBox:SetText(buildName) end
end

function SBE.OpenImporter()
    if #recentChatBuilds > 0 then
        local latest = recentChatBuilds[#recentChatBuilds]
        local decodedText, parsed = SBE.DecodeToFullText(latest)
        parsed.formattedText = decodedText
        parsed.chatString    = latest.code
        ShowBuildWindow(decodedText, parsed)
        if nameEditBox and parsed.buildName and parsed.buildName ~= "" then
            nameEditBox:SetText(parsed.buildName)
        end
    else
        ShowBuildWindow()
    end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= SBE.name then return end
    EVENT_MANAGER:UnregisterForEvent(SBE.name, EVENT_ADD_ON_LOADED)

    SBE.savedVariables = ZO_SavedVars:NewAccountWide("ShosBuildExporterSV", 1, nil, {})
    EVENT_MANAGER:RegisterForEvent(SBE.name, EVENT_CHAT_MESSAGE_CHANNEL, OnChatMessage)

    SLASH_COMMANDS["/shoexport"]    = SBE.ExportBuild
    SLASH_COMMANDS["/shoimport"]    = SBE.OpenImporter
    SLASH_COMMANDS["/shoshowbuild"] = SBE.OpenImporter
end

EVENT_MANAGER:RegisterForEvent(SBE.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
