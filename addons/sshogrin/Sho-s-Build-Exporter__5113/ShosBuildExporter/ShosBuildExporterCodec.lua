ShosBuildExporter = ShosBuildExporter or {}
local SBE = ShosBuildExporter

-- ============================================================================
-- NUMERIC ID TABLES & COMPACT CHAT / SAVEDVARIABLES CODEC
-- ============================================================================

SBE.EQUIP_SLOTS = {
    { slot = EQUIP_SLOT_HEAD,        name = "Head",             code = "HD" },
    { slot = EQUIP_SLOT_SHOULDERS,   name = "Shoulders",        code = "SH" },
    { slot = EQUIP_SLOT_CHEST,       name = "Chest",            code = "CH" },
    { slot = EQUIP_SLOT_HAND,        name = "Hands",            code = "HA" },
    { slot = EQUIP_SLOT_WAIST,       name = "Waist",            code = "WA" },
    { slot = EQUIP_SLOT_LEGS,        name = "Legs",             code = "LE" },
    { slot = EQUIP_SLOT_FEET,        name = "Feet",             code = "FE" },
    { slot = EQUIP_SLOT_NECK,        name = "Necklace",         code = "NE" },
    { slot = EQUIP_SLOT_RING1,       name = "Ring 1",           code = "R1" },
    { slot = EQUIP_SLOT_RING2,       name = "Ring 2",           code = "R2" },
    { slot = EQUIP_SLOT_MAIN_HAND,   name = "Main Hand",        code = "MH" },
    { slot = EQUIP_SLOT_OFF_HAND,    name = "Off Hand",         code = "OH" },
    { slot = EQUIP_SLOT_BACKUP_MAIN, name = "Backup Main Hand", code = "BM" },
    { slot = EQUIP_SLOT_BACKUP_OFF,  name = "Backup Off Hand",  code = "BO" },
}

SBE.SLOT_NAME_TO_ENUM  = {}
SBE.SLOT_CODE_TO_INFO  = {}
SBE.SLOT_INDEX_TO_INFO = {}

for idx, entry in ipairs(SBE.EQUIP_SLOTS) do
    SBE.SLOT_NAME_TO_ENUM[entry.name:lower()] = entry.slot
    SBE.SLOT_CODE_TO_INFO[entry.code]         = entry
    SBE.SLOT_INDEX_TO_INFO[idx]               = entry
end

SBE.MUNDUS_ABILITIES = {
    ["13940"] = "The Warrior",
    ["13941"] = "The Mage",
    ["13942"] = "The Serpent",
    ["13943"] = "The Thief",
    ["13944"] = "The Lady",
    ["13945"] = "The Steed",
    ["13946"] = "The Lord",
    ["13947"] = "The Apprentice",
    ["13948"] = "The Ritual",
    ["13949"] = "The Lover",
    ["13950"] = "The Atronach",
    ["13951"] = "The Shadow",
    ["13952"] = "The Tower",
}

SBE.MUNDUS_NAME_TO_ID = {
    ["the warrior"]    = 13940,
    ["the mage"]       = 13941,
    ["the serpent"]    = 13942,
    ["the thief"]      = 13943,
    ["the lady"]       = 13944,
    ["the steed"]      = 13945,
    ["the lord"]       = 13946,
    ["the apprentice"] = 13947,
    ["the ritual"]     = 13948,
    ["the lover"]      = 13949,
    ["the atronach"]   = 13950,
    ["the shadow"]     = 13951,
    ["the tower"]      = 13952,
}

function SBE.CleanName(str)
    if not str or str == "" then return "" end
    return zo_strformat("<<1>>", str)
end

function SBE.Trim(str)
    if not str then return "" end
    return str:match("^%s*(.-)%s*$")
end

local function EscapePattern(sep)
    return sep:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

local function SplitDelimited(str, sep)
    local out = {}
    local pat = "(.-)" .. EscapePattern(sep)
    for part in (str .. sep):gmatch(pat) do
        table.insert(out, part)
    end
    return out
end

-- Base36 compact numeric encoder/decoder
local B36_CHARS = "0123456789abcdefghijklmnopqrstuvwxyz"

function SBE.ToBase36(num)
    num = math.floor(tonumber(num) or 0)
    if num <= 0 then return "0" end
    local res = {}
    while num > 0 do
        local rem = (num % 36) + 1
        table.insert(res, 1, B36_CHARS:sub(rem, rem))
        num = math.floor(num / 36)
    end
    return table.concat(res)
end

function SBE.FromBase36(str)
    if not str or str == "" then return 0 end
    return tonumber(str, 36) or 0
end

function SBE.FindAbilityIdByName(targetName)
    if not targetName or targetName == "" or targetName == "[Empty]" then return nil, false end
    local lowerTarget = targetName:lower()

    if GetNumCraftedAbilities then
        for i = 1, GetNumCraftedAbilities() do
            local craftedId = GetCraftedAbilityIdAtIndex(i)
            local abilityId = GetAbilityIdForCraftedAbilityId(craftedId)
            if SBE.CleanName(GetAbilityName(abilityId)):lower() == lowerTarget then
                return craftedId, true
            end
        end
    end

    for skillType = 1, GetNumSkillTypes() do
        for skillLineIndex = 1, GetNumSkillLines(skillType) do
            for skillIndex = 1, GetNumSkillAbilities(skillType, skillLineIndex) do
                local abilityId = GetSkillAbilityId(skillType, skillLineIndex, skillIndex, false)
                if abilityId and abilityId > 0 and SBE.CleanName(GetAbilityName(abilityId)):lower() == lowerTarget then
                    return abilityId, false
                end
            end
        end
    end
    return nil, false
end

function SBE.FindChampionSkillIdByName(cpName)
    local lowerTarget = SBE.Trim(cpName):lower()
    for dIdx = 1, GetNumChampionDisciplines() do
        local dId = GetChampionDisciplineId(dIdx)
        for sIdx = 1, GetNumChampionDisciplineSkills(dId) do
            local sId = GetChampionSkillId(dId, sIdx)
            if SBE.CleanName(GetChampionSkillName(sId)):lower() == lowerTarget then
                return sId
            end
        end
    end
    return nil
end

-- Populate deduplicated ID -> Name lookup tables inside SavedVariables so external viewers show exact names
function SBE.RecordLookupNames(svRoot, record)
    if not svRoot or not record then return end
    svRoot.names = svRoot.names or {
        sets      = {},
        enchants  = {},
        abilities = {},
        scripts   = {},
        cp        = {},
    }
    local n = svRoot.names

    for _, g in ipairs(record.gear or {}) do
        if g.setId and g.setId > 0 and g.set and g.set ~= "" then
            n.sets[tostring(g.setId)] = g.set
        end
        if g.enchantId and g.enchantId > 0 and g.enchantment and g.enchantment ~= "" then
            n.enchants[tostring(g.enchantId)] = g.enchantment
        end
    end

    local function recordBar(barList)
        for _, s in ipairs(barList or {}) do
            if s.isScribed and s.craftedAbilityId and s.craftedAbilityId > 0 then
                n.abilities["c" .. tostring(s.craftedAbilityId)] = s.name
                local sc = s.scriptIds or {}
                local sn = s.scripts or {}
                if sc.focus and sc.focus > 0 and sn.focus then n.scripts[tostring(sc.focus)] = sn.focus end
                if sc.signature and sc.signature > 0 and sn.signature then n.scripts[tostring(sc.signature)] = sn.signature end
                if sc.affix and sc.affix > 0 and sn.affix then n.scripts[tostring(sc.affix)] = sn.affix end
            elseif s.abilityId and s.abilityId > 0 and s.name and s.name ~= "[Empty]" then
                n.abilities[tostring(s.abilityId)] = s.name
            end
        end
    end

    recordBar(record.skills and record.skills.frontBar)
    recordBar(record.skills and record.skills.backBar)

    for _, lineEntry in ipairs(record.passives or {}) do
        for _, p in ipairs(lineEntry.passives or {}) do
            if p.abilityId and p.abilityId > 0 and p.name then
                n.abilities[tostring(p.abilityId)] = p.name
            end
        end
    end

    for _, c in ipairs(record.championPoints or {}) do
        if c.skillId and c.skillId > 0 and c.name then
            n.cp[tostring(c.skillId)] = c.name
        end
    end
end

-- Encode a build record into a single-line Base36 code
function SBE.BuildSingleLineChatCode(record)
    local attr = record.attributes or {}
    local attrCode = string.format("%s.%s.%s",
        SBE.ToBase36(attr.Magicka or 0),
        SBE.ToBase36(attr.Health or 0),
        SBE.ToBase36(attr.Stamina or 0)
    )

    local mIds = {}
    for _, id in ipairs(record.mundusIds or {}) do
        table.insert(mIds, SBE.ToBase36(id))
    end
    local mundusCode = (#mIds > 0) and table.concat(mIds, ".") or "0"

    local gearTokens = {}
    for idx = 1, #SBE.EQUIP_SLOTS do
        local g = record.gear and record.gear[idx]
        if g and g.item and g.item ~= "[Empty]" then
            table.insert(gearTokens, string.format("%s.%s.%s.%s",
                SBE.ToBase36(g.setId or 0),
                SBE.ToBase36(g.subTypeId or 0),
                SBE.ToBase36(g.traitId or 0),
                SBE.ToBase36(g.enchantId or 0)
            ))
        else
            table.insert(gearTokens, "-")
        end
    end

    local function encodeBar(barList)
        local tokens = {}
        for i = 1, 6 do
            local s = barList and barList[i]
            if not s or s.name == "[Empty]" then
                table.insert(tokens, "-")
            elseif s.isScribed and s.craftedAbilityId then
                local sc = s.scriptIds or {}
                table.insert(tokens, string.format("c%s.%s.%s.%s",
                    SBE.ToBase36(s.craftedAbilityId),
                    SBE.ToBase36(sc.focus or 0),
                    SBE.ToBase36(sc.signature or 0),
                    SBE.ToBase36(sc.affix or 0)
                ))
            else
                table.insert(tokens, SBE.ToBase36(s.abilityId or 0))
            end
        end
        return table.concat(tokens, ",")
    end

    local cpBySlot = {}
    for _, c in ipairs(record.championPoints or {}) do
        if c.slot and c.skillId then
            cpBySlot[c.slot] = SBE.ToBase36(c.skillId)
        end
    end
    local cpTokens = {}
    for slot = 1, 12 do
        table.insert(cpTokens, cpBySlot[slot] or "-")
    end
    local passiveGroups = {}
    for _, lineEntry in ipairs(record.passives or {}) do
        local pIds = {}
        for _, p in ipairs(lineEntry.passives or {}) do
            if p.abilityId and p.abilityId > 0 then
                table.insert(pIds, SBE.ToBase36(p.abilityId))
            end
        end
        if #pIds > 0 then
            local cleanLine = (lineEntry.skillLine or "Passives"):gsub("[|;:%[%]]", "")
            table.insert(passiveGroups, string.format("%s:%s", cleanLine, table.concat(pIds, ",")))
        end
    end
    local passivesCode = table.concat(passiveGroups, ";")

    local safeBuildName = (record.buildName or "Build"):gsub("[|%[%]]", "")
    local clsShort = (record.character and record.character.class or "?"):sub(1, 3)

    local char = record.character or {}
    local safeCharName = (char.name or ""):gsub("[|.%[%]]", "")
    local safeRace     = (char.race or ""):gsub("[|.%[%]]", "")
    local lvlB36       = SBE.ToBase36(char.level or 0)
    local cpB36        = SBE.ToBase36(char.cp or char.championPoints or 0)

    local lineTokens = {}
    for _, line in ipairs(record.classLines or {}) do
        if type(line) == "table" then
            if line.skillLineId and line.skillLineId > 0 then
                table.insert(lineTokens, SBE.ToBase36(line.skillLineId))
            elseif line.id and line.id > 0 then
                table.insert(lineTokens, SBE.ToBase36(line.id))
            elseif line.name then
                table.insert(lineTokens, line.name:gsub("[|.,%[%]]", ""))
            end
        elseif type(line) == "number" and line > 0 then
            table.insert(lineTokens, SBE.ToBase36(line))
        elseif type(line) == "string" and line ~= "" then
            table.insert(lineTokens, line:gsub("[|.,%[%]]", ""))
        end
    end

    local charMetaCode = string.format("%s.%s.%s.%s.%s",
        safeCharName,
        safeRace,
        lvlB36,
        cpB36,
        table.concat(lineTokens, ",")
    )

    return string.format(
        "[SBE2|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s]",
        clsShort,
        safeBuildName,
        attrCode,
        mundusCode,
        table.concat(gearTokens, ","),
        encodeBar(record.skills and record.skills.frontBar),
        encodeBar(record.skills and record.skills.backBar),
        table.concat(cpTokens, ","),
        passivesCode,
        charMetaCode
    )

end

local passiveAbilityCache = nil

local function GetPassiveMetaByAbilityId(targetId)
    if not passiveAbilityCache then
        passiveAbilityCache = {}
        for skillType = 1, GetNumSkillTypes() do
            for skillLineIdx = 1, GetNumSkillLines(skillType) do
                local lineName = SBE.CleanName(GetSkillLineInfo(skillType, skillLineIdx))
                for skillIdx = 1, GetNumSkillAbilities(skillType, skillLineIdx) do
                    local isPassive = select(3, GetSkillAbilityInfo(skillType, skillLineIdx, skillIdx))
                    if isPassive then
                        -- Check all ranks (1 to 4) of this passive so any rank matches
                        for rank = 1, 4 do
                            local aId = GetSpecificSkillAbilityInfo(skillType, skillLineIdx, skillIdx, 0, rank)
                            if aId and aId > 0 then
                                passiveAbilityCache[aId] = {
                                    skillLine = lineName,
                                    rank      = rank,
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    return passiveAbilityCache[targetId]
end

local function ExpandClassShortName(shortCode)
    if not shortCode or shortCode == "" or shortCode == "?" then
        return "?"
    end
    local target = shortCode:lower()
    if GetNumClasses and GetClassInfo and GetClassName then
        for i = 1, GetNumClasses() do
            local classId = GetClassInfo(i)
            local fullName = SBE.CleanName(GetClassName(GENDER_MALE, classId))
            if fullName ~= "" and fullName:sub(1, #target):lower() == target then
                return fullName
            end
        end
    end
    return shortCode
end

-- Decode either a Base36 [SBE2|...] code OR a full multi-line sheet into structured data
function SBE.ParseBuildText(rawText)
    local trimmed = SBE.Trim(rawText)
    local parsed = {
        buildName = "Imported Build",
        character = {},
        attributes = { Magicka = 0, Health = 0, Stamina = 0 },
        mundus = {},
        gear = {},
        skills = { frontBar = {}, backBar = {} },
        championPoints = {},
    }

    local sbe2Body = trimmed:match("%[SBE2|+(.-)%]")
    if sbe2Body then
        sbe2Body = sbe2Body:gsub("||", "|")
        local fields = SplitDelimited(sbe2Body, "|")
        local clsShort, bName, attrStr, mundusStr, gearStr, fbStr, bbStr, cpStr, passivesStr, charMetaStr = unpack(fields)

        parsed.buildName = bName or "Imported Build"
        parsed.character.class = ExpandClassShortName(clsShort)
        parsed.classLines = {}

        if charMetaStr and charMetaStr ~= "" then
            local cName, cRace, lvlB36, cpB36, linesStr = unpack(SplitDelimited(charMetaStr, "."))
            parsed.character.name  = (cName and cName ~= "") and cName or nil
            parsed.character.race  = (cRace and cRace ~= "") and cRace or nil
            parsed.character.level = (lvlB36 and lvlB36 ~= "") and SBE.FromBase36(lvlB36) or nil
            parsed.character.cp    = (cpB36 and cpB36 ~= "") and SBE.FromBase36(cpB36) or nil

            if linesStr and linesStr ~= "" then
                for _, tok in ipairs(SplitDelimited(linesStr, ",")) do
                    local id = SBE.FromBase36(tok)
                    local lineName = (id > 0 and GetSkillLineNameById)
                        and SBE.CleanName(GetSkillLineNameById(id))
                        or tok
                    if lineName and lineName ~= "" then
                        local isSubclass = false
                        local sourceClass = ""
                        if id > 0 and GetSkillLineIndicesFromSkillLineId and GetSkillLineClassId then
                            local sType, sIdx = GetSkillLineIndicesFromSkillLineId(id)
                            if sType and sIdx then
                                local lineClassId = GetSkillLineClassId(sType, sIdx)
                                local lineClassName = lineClassId and lineClassId > 0
                                    and SBE.CleanName(GetClassName(GENDER_MALE, lineClassId))
                                    or ""
                                if lineClassName ~= "" and lineClassName:sub(1, 3):lower() ~= (clsShort or ""):lower() then
                                    isSubclass = true
                                    sourceClass = lineClassName
                                end
                            end
                        end
                        table.insert(parsed.classLines, {
                            name        = lineName,
                            skillLineId = id,
                            isSubclass  = isSubclass,
                            sourceClass = sourceClass,
                        })
                    end
                end
            end
        end

        if attrStr and attrStr ~= "" then
            local mB36, hB36, sB36 = unpack(SplitDelimited(attrStr, "."))
            parsed.attributes = {
                Magicka = SBE.FromBase36(mB36),
                Health  = SBE.FromBase36(hB36),
                Stamina = SBE.FromBase36(sB36),
            }
        end

        if mundusStr and mundusStr ~= "" and mundusStr ~= "0" then
            for _, mB36 in ipairs(SplitDelimited(mundusStr, ".")) do
                local mId = SBE.FromBase36(mB36)
                local mName = SBE.MUNDUS_ABILITIES[tostring(mId)]
                if mName then
                    table.insert(parsed.mundus, mName)
                end
            end
        end

        if gearStr and gearStr ~= "" then
            local gTokens = SplitDelimited(gearStr, ",")
            for idx, tok in ipairs(gTokens) do
                local slotMeta = SBE.SLOT_INDEX_TO_INFO[idx]
                if slotMeta and tok ~= "" and tok ~= "-" then
                    local setB36, subB36, traitB36, enchB36 = unpack(SplitDelimited(tok, "."))
                    local setId     = SBE.FromBase36(setB36)
                    local subTypeId = SBE.FromBase36(subB36)
                    local traitId   = SBE.FromBase36(traitB36)
                    local enchantId = SBE.FromBase36(enchB36)

                    local setName = (setId > 0 and GetItemSetName)
                        and SBE.CleanName(GetItemSetName(setId))
                        or "No Set"

                    local weightOrType = ""
                    if subTypeId >= 100 then
                        weightOrType = SBE.CleanName(GetString("SI_WEAPONTYPE", subTypeId - 100))
                    elseif subTypeId > 0 then
                        weightOrType = SBE.CleanName(GetString("SI_ARMORTYPE", subTypeId))
                    end

                    local traitName = (traitId > 0)
                        and SBE.CleanName(GetString("SI_ITEMTRAITTYPE", traitId))
                        or "No Trait"

                    local enchantName = "No Enchant"
                    if enchantId > 0 then
                        local cat = GetEnchantSearchCategoryType(enchantId)
                        if cat and cat ~= ENCHANTMENT_SEARCH_CATEGORY_NONE then
                            enchantName = SBE.CleanName(GetString("SI_ENCHANTMENTSEARCHCATEGORYTYPE", cat))
                        end
                    end

                    table.insert(parsed.gear, {
                        slot         = slotMeta.name,
                        slotCode     = slotMeta.code,
                        equipSlot    = slotMeta.slot,
                        set          = setName,
                        setId        = setId,
                        subTypeId    = subTypeId,
                        weightOrType = weightOrType,
                        traitId      = traitId,
                        trait        = traitName,
                        enchantId    = enchantId,
                        enchantment  = enchantName,
                    })
                end
            end
        end

        local function decodeBar(barStr, targetList)
            if not barStr or barStr == "" then return end
            local tokens = SplitDelimited(barStr, ",")
            for i = 1, 6 do
                local tok = SBE.Trim(tokens[i] or "")
                local slotIndex = i + 2
                local slotLabel = (slotIndex == 8) and "Ultimate" or ("Slot " .. i)
                if tok ~= "" and tok ~= "-" then
                    if tok:sub(1, 1) == "c" then
                        local cB36, focusB36, sigB36, affixB36 = unpack(SplitDelimited(tok:sub(2), "."))
                        local cId = SBE.FromBase36(cB36)
                        local aId = GetAbilityIdForCraftedAbilityId(cId)
                        local fId = SBE.FromBase36(focusB36)
                        local sId = SBE.FromBase36(sigB36)
                        local afId = SBE.FromBase36(affixB36)
                        table.insert(targetList, {
                            slotIndex        = slotIndex,
                            slot             = slotLabel,
                            name             = SBE.CleanName(GetAbilityName(aId)),
                            isScribed        = true,
                            craftedAbilityId = cId,
                            abilityId        = aId,
                            scriptIds        = { focus = fId, signature = sId, affix = afId },
                            scripts          = {
                                focus     = (fId > 0) and SBE.CleanName(GetCraftedAbilityScriptDisplayName(fId)) or "None",
                                signature = (sId > 0) and SBE.CleanName(GetCraftedAbilityScriptDisplayName(sId)) or "None",
                                affix     = (afId > 0) and SBE.CleanName(GetCraftedAbilityScriptDisplayName(afId)) or "None",
                            },
                        })
                    else
                        local aId = SBE.FromBase36(tok)
                        table.insert(targetList, {
                            slotIndex = slotIndex,
                            slot      = slotLabel,
                            name      = SBE.CleanName(GetAbilityName(aId)),
                            abilityId = aId,
                            isScribed = false,
                        })
                    end
                else
                    table.insert(targetList, {
                        slotIndex = slotIndex,
                        slot      = slotLabel,
                        name      = "[Empty]",
                        isScribed = false,
                    })
                end
            end
        end

        decodeBar(fbStr, parsed.skills.frontBar)
        decodeBar(bbStr, parsed.skills.backBar)

        if cpStr and cpStr ~= "" then
            local cpTokens = SplitDelimited(cpStr, ",")
            for slotNum = 1, 12 do
                local tok = SBE.Trim(cpTokens[slotNum] or "")
                if tok ~= "" and tok ~= "-" then
                    local sId = SBE.FromBase36(tok)
                    if sId > 0 then
                        local dId = GetRequiredChampionDisciplineIdForSlot(slotNum, HOTBAR_CATEGORY_CHAMPION)
                        table.insert(parsed.championPoints, {
                            slot       = slotNum,
                            skillId    = sId,
                            discipline = (dId and dId > 0) and SBE.CleanName(GetChampionDisciplineName(dId)) or "CP",
                            name       = SBE.CleanName(GetChampionSkillName(sId)),
                        })
                    end
                end
            end
        end

                parsed.passives = {}
        if passivesStr and passivesStr ~= "" then
            local byLine = {}
            local lineOrder = {}

            local function addPassive(lineName, aId)
                if aId <= 0 then return end
                local meta = GetPassiveMetaByAbilityId and GetPassiveMetaByAbilityId(aId) or nil
                local resolvedLine = (lineName and lineName ~= "") and lineName or (meta and meta.skillLine) or "Passives"
                local rank = meta and meta.rank or nil

                if not byLine[resolvedLine] then
                    byLine[resolvedLine] = { skillLine = resolvedLine, passives = {} }
                    table.insert(lineOrder, resolvedLine)
                end

                table.insert(byLine[resolvedLine].passives, {
                    abilityId = aId,
                    name      = SBE.CleanName(GetAbilityName(aId)),
                    rank      = rank,
                })
            end

            if passivesStr:find(":") then
                -- Grouped format: "Aedric Spear:xzi,yi9;Dawn's Wrath:yvy,yw0"
                for _, group in ipairs(SplitDelimited(passivesStr, ";")) do
                    local lineName, idsCsv = group:match("^([^:]+):(.+)$")
                    if lineName and idsCsv then
                        for _, pB36 in ipairs(SplitDelimited(idsCsv, ",")) do
                            addPassive(SBE.Trim(lineName), SBE.FromBase36(SBE.Trim(pB36)))
                        end
                    end
                end
            else
                -- Legacy flat format fallback: "yqb,yqc,yqn"
                for _, pB36 in ipairs(SplitDelimited(passivesStr, ",")) do
                    addPassive(nil, SBE.FromBase36(SBE.Trim(pB36)))
                end
            end

            for _, lineName in ipairs(lineOrder) do
                table.insert(parsed.passives, byLine[lineName])
            end
        end

        return parsed
    end

    -- Case B: Full Multi-Line Build Sheet
    local section = ""
    for line in trimmed:gmatch("[^\r\n]+") do
        local bHeader = line:match("^=== BUILD:%s*(.-)%s*===$")
        if bHeader then
            parsed.buildName = bHeader
        elseif line:find("=== EQUIPPED GEAR ===") then
            section = "GEAR"
        elseif line:find("=== FRONT BAR ===") then
            section = "FRONT"
        elseif line:find("=== BACK BAR ===") then
            section = "BACK"
        elseif line:find("=== CHAMPION POINTS") then
            section = "CP"
        elseif line:find("^===") then
            section = ""
        elseif section == "GEAR" then
            local slotStr, rest = line:match("^(.-):%s*(.+)$")
            if slotStr and rest and rest ~= "[Empty]" then
                local equipSlot = SBE.SLOT_NAME_TO_ENUM[SBE.Trim(slotStr):lower()]
                if equipSlot then
                    local itemPart, setPart, traitPart, enchPart =
                        rest:match("^(.-)%s*|%s*Set:%s*(.-)%s*|%s*Trait:%s*(.-)%s*|%s*Enchant:%s*(.+)$")
                    if itemPart then
                        local cleanItem = itemPart:gsub("%s*%b()$", "")
                        local weight = itemPart:match("%((.-)%)$") or ""
                        table.insert(parsed.gear, {
                            slot         = SBE.Trim(slotStr),
                            equipSlot    = equipSlot,
                            item         = SBE.Trim(cleanItem),
                            weightOrType = SBE.Trim(weight),
                            set          = SBE.Trim(setPart),
                            trait        = SBE.Trim(traitPart),
                            enchantment  = SBE.Trim(enchPart),
                        })
                    end
                end
            end
        elseif section == "FRONT" or section == "BACK" then
            local slotStr, rest = line:match("^(.-):%s*(.+)$")
            if slotStr and rest then
                local slotIndex = (slotStr == "Ultimate") and 8 or (tonumber(slotStr:match("Slot (%d+)")) + 2)
                local skillName = rest:match("^(.-)%s*%[Scribed%]") or rest
                local targetBar = (section == "FRONT") and parsed.skills.frontBar or parsed.skills.backBar
                table.insert(targetBar, {
                    slotIndex = slotIndex,
                    slot      = slotStr,
                    name      = SBE.Trim(skillName),
                })
            end
        elseif section == "CP" then
            local slotNum, cpName = line:match("^Slot (%d+)%s*%[.-%]:%s*(.-)%s*%(")
            if slotNum and cpName then
                local sId = SBE.FindChampionSkillIdByName(cpName)
                if sId then
                    table.insert(parsed.championPoints, {
                        slot    = tonumber(slotNum),
                        skillId = sId,
                        name    = cpName,
                    })
                end
            end
        end
    end

    return parsed
end

-- Reconstruct a readable build sheet from a compact saved record or [SBE2|...] code
function SBE.DecodeToFullText(svEntry)
    local code = type(svEntry) == "table" and svEntry.code or svEntry
    local parsed = SBE.ParseBuildText(code)
    local pChar = parsed.character or {}

    local bName     = (type(svEntry) == "table" and svEntry.name) or parsed.buildName or "Build"
    local charName  = pChar.name or (type(svEntry) == "table" and svEntry.char) or "Shared"
    local raceName  = (pChar.race and pChar.race ~= "") and pChar.race or ((type(svEntry) == "table" and svEntry.race) or "")
    local className = (pChar.class and pChar.class ~= "" and pChar.class ~= "?") and pChar.class or ((type(svEntry) == "table" and svEntry.class) or "")
    local lvl       = pChar.level or (type(svEntry) == "table" and svEntry.level)
    local cp        = pChar.cp or (type(svEntry) == "table" and svEntry.cp)

    -- Preserve all character metadata on the returned parsed table
    parsed.buildName = bName
    parsed.character = {
        name  = charName,
        race  = raceName,
        class = className,
        level = lvl,
        cp    = cp,
    }

    local headerLine = string.format("Character: %s | Race: %s | Class: %s", charName, raceName, className)
    if lvl and lvl > 0 then
        if cp and cp > 0 then
            headerLine = headerLine .. string.format(" | Level: %d (CP %d)", lvl, cp)
        else
            headerLine = headerLine .. string.format(" | Level: %d", lvl)
        end
    end

    local lineDisplay = {}
    for _, line in ipairs(parsed.classLines or {}) do
        if line.isSubclass and line.sourceClass and line.sourceClass ~= "" then
            table.insert(lineDisplay, string.format("%s [Subclass: %s]", line.name, line.sourceClass))
        elseif line.name and line.name ~= "" then
            table.insert(lineDisplay, line.name)
        end
    end
    local classLinesText = (#lineDisplay > 0) and table.concat(lineDisplay, " | ") or "None"

    local out = {
        string.format("=== BUILD: %s ===", bName),
        headerLine,
        "",
        "=== CLASS / SUBCLASS SKILL LINES ===",
        classLinesText,
        "",
        "=== ATTRIBUTES ===",
        string.format("Magicka: %d | Health: %d | Stamina: %d",
            parsed.attributes.Magicka or 0,
            parsed.attributes.Health or 0,
            parsed.attributes.Stamina or 0
        ),
        "",
        "=== MUNDUS STONE ===",
        (#parsed.mundus > 0) and table.concat(parsed.mundus, ", ") or "None",
        "",
        "=== EQUIPPED GEAR ===",
    }

    local gearBySlot = {}
    for _, g in ipairs(parsed.gear) do
        gearBySlot[g.slot] = g
    end
    for _, slotMeta in ipairs(SBE.EQUIP_SLOTS) do
        local g = gearBySlot[slotMeta.name]
        if g then
            local suffix = (g.weightOrType and g.weightOrType ~= "") and (" (" .. g.weightOrType .. ")") or ""
            table.insert(out, string.format("%s: %s%s | Trait: %s | Enchant: %s",
                slotMeta.name, g.set or "No Set", suffix, g.trait or "No Trait", g.enchantment or "No Enchant"
            ))
        else
            table.insert(out, string.format("%s: [Empty]", slotMeta.name))
        end
    end

    table.insert(out, "")
    table.insert(out, "=== CHAMPION POINTS (SLOTTABLES) ===")
    if #parsed.championPoints > 0 then
        for _, cpEntry in ipairs(parsed.championPoints) do
            table.insert(out, string.format("Slot %d: %s", cpEntry.slot, cpEntry.name))
        end
    else
        table.insert(out, "No CP slottables assigned.")
    end

    local function appendBar(label, barList)
        table.insert(out, "")
        table.insert(out, string.format("=== %s ===", label))
        for _, s in ipairs(barList) do
            if s.isScribed and s.scripts then
                table.insert(out, string.format("%s: %s [Scribed] -> Focus: %s | Signature: %s | Affix: %s",
                    s.slot, s.name, s.scripts.focus, s.scripts.signature, s.scripts.affix
                ))
            else
                table.insert(out, string.format("%s: %s", s.slot, s.name))
            end
        end
    end

    appendBar("FRONT BAR", parsed.skills.frontBar)
    appendBar("BACK BAR", parsed.skills.backBar)

    table.insert(out, "")
    table.insert(out, "=== COMBAT PASSIVES ===")
    if parsed.passives and #parsed.passives > 0 then
        for _, lineEntry in ipairs(parsed.passives) do
            local names = {}
            for _, p in ipairs(lineEntry.passives or {}) do
                local label = (p.rank and p.rank > 0) and string.format("%s (%d)", p.name, p.rank) or p.name
                table.insert(names, label)
            end
            if #names > 0 then
                table.insert(out, string.format("%s: %s", lineEntry.skillLine, table.concat(names, ", ")))
            end
        end
    else
        table.insert(out, "No passives recorded.")
    end

    table.insert(out, "")
    table.insert(out, "=== SHARE CODE ===")
    table.insert(out, code)

    return table.concat(out, "\n"), parsed
end
