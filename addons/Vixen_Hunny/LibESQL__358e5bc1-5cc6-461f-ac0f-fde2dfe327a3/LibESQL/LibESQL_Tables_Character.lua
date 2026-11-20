-- Tables: character, characters, stats, currencies, quests, completed_quests,
-- achievements, achievement_criteria, collectibles, titles, dyes, emotes,
-- lore_books, antiquities, recipes, guilds, friends, group.

local E = LibESQL
local Try, Clean, Tick, EnumShort = E.Try, E.CleanName, E.Tick, E.EnumShort
local FUNCS = E.SQL.FUNCS

local function bool(v) return v and true or false end
local function nonEmpty(s) if s ~= nil and s ~= "" then return s end end

---------------------------------------------------------------------------
-- character / characters
---------------------------------------------------------------------------
E.RegisterTable({
    name = "character",
    desc = "The character you are logged in on (one row)",
    live = true,
    columns = {
        { "name", "text", "Character name" },
        { "account", "text", "@account" },
        { "character_id", "text", "Character id" },
        { "level", "int", "Level" },
        { "cp", "int", "Champion points earned (account)" },
        { "class", "text", "Class" },
        { "class_id", "int", "Class id" },
        { "race", "text", "Race" },
        { "race_id", "int", "Race id" },
        { "alliance", "text", "Alliance" },
        { "zone", "text", "Current zone" },
        { "zone_id", "int", "Current zone id" },
        { "health_max", "int", "Max health" },
        { "magicka_max", "int", "Max magicka" },
        { "stamina_max", "int", "Max stamina" },
        { "api_version", "int", "Game API version" },
        { "console", "bool", "Running the console UI" },
    },
    build = function(rows)
        local function power(mech)
            local _, max = Try(GetUnitPower, "player", mech)
            return max
        end
        local zoneIndex = Try(GetUnitZoneIndex, "player")
        rows[1] = {
            name = Clean(Try(GetUnitName, "player")),
            account = Try(GetDisplayName),
            character_id = Try(GetCurrentCharacterId),
            level = Try(GetUnitLevel, "player"),
            cp = Try(GetPlayerChampionPointsEarned),
            class = Clean(Try(GetUnitClass, "player")),
            class_id = Try(GetUnitClassId, "player"),
            race = Clean(Try(GetUnitRace, "player")),
            race_id = Try(GetUnitRaceId, "player"),
            alliance = Clean(Try(GetAllianceName, Try(GetUnitAlliance, "player"))),
            zone = Clean(Try(GetUnitZone, "player")),
            zone_id = zoneIndex and Try(GetZoneId, zoneIndex),
            health_max = power(COMBAT_MECHANIC_FLAGS_HEALTH or 32),
            magicka_max = power(COMBAT_MECHANIC_FLAGS_MAGICKA or 1),
            stamina_max = power(COMBAT_MECHANIC_FLAGS_STAMINA or 4),
            api_version = Try(GetAPIVersion),
            console = E.isConsole,
        }
    end,
})

E.RegisterTable({
    name = "characters",
    desc = "Every character on this account and server",
    live = true,
    columns = {
        { "slot", "int", "Character select order" },
        { "name", "text", "Name" },
        { "class", "text", "Class" },
        { "race", "text", "Race" },
        { "level", "int", "Level" },
        { "alliance", "text", "Alliance" },
        { "id", "text", "Character id" },
        { "location", "text", "Last zone" },
    },
    build = function(rows)
        for i = 1, (Try(GetNumCharacters) or 0) do
            Tick()
            local name, gender, level, classId, raceId, alliance, id, locationId = Try(GetCharacterInfo, i)
            if name then
                rows[#rows + 1] = {
                    slot = i, name = Clean(name), level = level, id = id,
                    class = classId and Clean(Try(GetClassName, gender, classId)),
                    race = raceId and Clean(Try(GetRaceName, gender, raceId)),
                    alliance = alliance and Clean(Try(GetAllianceName, alliance)),
                    location = locationId and locationId > 0 and Clean(Try(GetLocationName, locationId)) or nil,
                }
            end
        end
    end,
})

---------------------------------------------------------------------------
-- stats
---------------------------------------------------------------------------
local STATS = {
    "STAT_ARMOR_RATING", "STAT_ATTACK_POWER", "STAT_BLOCK", "STAT_CRITICAL_CHANCE", "STAT_CRITICAL_RESISTANCE",
    "STAT_CRITICAL_STRIKE", "STAT_DAMAGE_RESIST_BLEED", "STAT_DAMAGE_RESIST_COLD", "STAT_DAMAGE_RESIST_DISEASE",
    "STAT_DAMAGE_RESIST_DROWN", "STAT_DAMAGE_RESIST_EARTH", "STAT_DAMAGE_RESIST_FIRE", "STAT_DAMAGE_RESIST_GENERIC",
    "STAT_DAMAGE_RESIST_MAGIC", "STAT_DAMAGE_RESIST_OBLIVION", "STAT_DAMAGE_RESIST_PHYSICAL", "STAT_DAMAGE_RESIST_POISON",
    "STAT_DAMAGE_RESIST_SHOCK", "STAT_DODGE", "STAT_HEALING_DONE", "STAT_HEALING_TAKEN", "STAT_HEALTH_MAX",
    "STAT_HEALTH_REGEN_COMBAT", "STAT_HEALTH_REGEN_IDLE", "STAT_MAGICKA_MAX", "STAT_MAGICKA_REGEN_COMBAT",
    "STAT_MAGICKA_REGEN_IDLE", "STAT_MISS", "STAT_MITIGATION", "STAT_MOUNT_STAMINA_MAX", "STAT_MOUNT_STAMINA_REGEN_COMBAT",
    "STAT_MOUNT_STAMINA_REGEN_MOVING", "STAT_OFFENSIVE_PENETRATION", "STAT_PHYSICAL_PENETRATION", "STAT_PHYSICAL_RESIST",
    "STAT_POWER", "STAT_SPELL_CRITICAL", "STAT_SPELL_MITIGATION", "STAT_SPELL_PENETRATION", "STAT_SPELL_POWER",
    "STAT_SPELL_RESIST", "STAT_STAMINA_MAX", "STAT_STAMINA_REGEN_COMBAT", "STAT_STAMINA_REGEN_IDLE",
    "STAT_WEAPON_AND_SPELL_DAMAGE",
}

E.RegisterTable({
    name = "stats",
    desc = "Your character sheet stats right now",
    live = true,
    columns = {
        { "stat", "text", "Stat name (lower case, without STAT_)" },
        { "stat_id", "int", "DerivedStats enum value" },
        { "value", "int", "Value with bonuses" },
        { "base", "int", "Value without bonuses" },
        { "label", "text", "Display name", function(r) return nonEmpty(Try(GetString, "SI_DERIVEDSTATS", r.stat_id)) end },
    },
    build = function(rows)
        for _, name in ipairs(STATS) do
            Tick()
            local id = _G[name]
            if id then
                rows[#rows + 1] = {
                    stat = name:sub(6):lower(), stat_id = id,
                    value = Try(GetPlayerStat, id, STAT_BONUS_OPTION_APPLY_BONUS or 0),
                    base = Try(GetPlayerStat, id, STAT_BONUS_OPTION_DONT_APPLY_BONUS or 1),
                }
            end
        end
    end,
})

---------------------------------------------------------------------------
-- currencies
---------------------------------------------------------------------------
E.RegisterTable({
    name = "currencies",
    desc = "Gold, AP, Tel Var, writ vouchers, transmute crystals... where you hold them",
    live = true,
    columns = {
        { "currency", "text", "Currency key" },
        { "currency_id", "int", "CurrencyType value" },
        { "name", "text", "Display name" },
        { "carried", "int", "On this character" },
        { "bank", "int", "In the bank" },
        { "account", "int", "Account-wide" },
        { "total", "int", "Sum" },
    },
    build = function(rows)
        local lo, hi = E.EnumRange("CURT_", 1, 30)
        for c = math.max(lo or 1, 1), hi or 30 do
            Tick()
            local key = EnumShort("CURT_", c)
            if key and key ~= "none" then
                local carried = Try(GetCurrencyAmount, c, CURRENCY_LOCATION_CHARACTER or 0) or 0
                local bank = Try(GetCurrencyAmount, c, CURRENCY_LOCATION_BANK or 1) or 0
                local account = Try(GetCurrencyAmount, c, CURRENCY_LOCATION_ACCOUNT or 3) or 0
                rows[#rows + 1] = {
                    currency = key, currency_id = c,
                    name = Clean(Try(GetCurrencyName, c, false, false)),
                    carried = carried, bank = bank, account = account, total = carried + bank + account,
                }
            end
        end
    end,
})

---------------------------------------------------------------------------
-- quests
---------------------------------------------------------------------------
E.RegisterTable({
    name = "quests",
    desc = "Quests in your journal",
    live = true,
    columns = {
        { "journal_index", "int", "Journal index" },
        { "name", "text", "Quest name" },
        { "type", "text", "QuestType" },
        { "level", "int", "Quest level" },
        { "zone", "text", "Zone" },
        { "step", "text", "Current step text" },
        { "background", "text", "Background text" },
        { "tracked", "bool", "Tracked" },
        { "completed", "bool", "Ready to turn in" },
        { "repeat_type", "text", "QuestRepeatableType", function(r)
            local v = Try(GetJournalQuestRepeatType, r.journal_index); return v and EnumShort("QUEST_REPEAT_", v) end },
    },
    build = function(rows)
        local maxQuests = MAX_JOURNAL_QUESTS or 25
        for i = 1, maxQuests do
            Tick()
            if Try(IsValidQuestIndex, i) ~= false then
                local name, background, step, _, _, completed, tracked, level, _, questType = Try(GetJournalQuestInfo, i)
                if name and name ~= "" then
                    local zoneName = Try(GetJournalQuestLocationInfo, i)
                    rows[#rows + 1] = {
                        journal_index = i, name = Clean(name), background = background, step = step,
                        completed = bool(completed), tracked = bool(tracked), level = level,
                        type = questType and EnumShort("QUEST_TYPE_", questType),
                        zone = Clean(zoneName),
                    }
                end
            end
        end
    end,
})

E.RegisterTable({
    name = "completed_quests",
    desc = "Every quest this character has completed",
    key = "id",
    live = true,
    columns = {
        { "id", "int", "Quest id" },
        { "name", "text", "Quest name" },
        { "type", "text", "QuestType" },
        { "zone", "text", "Zone", function(r) return Clean(Try(GetCompletedQuestLocationInfo, r.id)) end },
        { "repeat_type", "text", "QuestRepeatableType", function(r)
            local v = Try(GetQuestRepeatableType, r.id); return v and EnumShort("QUEST_REPEAT_", v) end },
    },
    build = function(rows)
        local id = Try(GetNextCompletedQuestId)
        while id do
            Tick()
            local name, questType = Try(GetCompletedQuestInfo, id)
            rows[#rows + 1] = { id = id, name = Clean(name), type = questType and EnumShort("QUEST_TYPE_", questType) }
            id = Try(GetNextCompletedQuestId, id)
        end
    end,
})

---------------------------------------------------------------------------
-- achievements
---------------------------------------------------------------------------
local function forEachAchievement(fn)
    for top = 1, (Try(GetNumAchievementCategories) or 0) do
        local topName, numSub, numAch = Try(GetAchievementCategoryInfo, top)
        topName = Clean(topName)
        local function walk(subIndex, subName, count)
            for i = 1, (count or 0) do
                local id = Try(GetAchievementId, top, subIndex, i)
                local guard = 0
                while id and id > 0 and guard < 50 do
                    Tick()
                    fn(id, topName, subName)
                    local nextId = Try(GetNextAchievementInLine, id)
                    if nextId == id then break end
                    id = nextId
                    guard = guard + 1
                end
            end
        end
        walk(nil, nil, numAch)
        for s = 1, (numSub or 0) do
            local subName, subCount = Try(GetAchievementSubCategoryInfo, top, s)
            walk(s, Clean(subName), subCount)
        end
    end
end

E.RegisterTable({
    name = "achievements",
    desc = "Every achievement with points, completion and rewards",
    key = "id",
    live = true,
    columns = {
        { "id", "int", "Achievement id" },
        { "name", "text", "Name" },
        { "description", "text", "Description" },
        { "points", "int", "Achievement points" },
        { "completed", "bool", "Completed" },
        { "date", "text", "Completion date" },
        { "category", "text", "Top category" },
        { "subcategory", "text", "Subcategory" },
        { "icon", "text", "Icon" },
        { "num_criteria", "int", "Number of criteria", function(r) return Try(GetAchievementNumCriteria, r.id) end },
        { "reward_title", "text", "Title reward", function(r)
            local has, title = Try(GetAchievementRewardTitle, r.id); if has then return Clean(title) end end },
        { "reward_collectible_id", "int", "Collectible reward", function(r)
            local has, id = Try(GetAchievementRewardCollectible, r.id); if has then return id end end },
        { "reward_dye_id", "int", "Dye reward", function(r)
            local has, id = Try(GetAchievementRewardDye, r.id); if has then return id end end },
        { "reward_item", "text", "Item reward", function(r)
            local has, name = Try(GetAchievementRewardItem, r.id); if has then return Clean(name) end end },
        { "link", "text", "Chat link", function(r) return Try(GetAchievementLink, r.id, LINK_STYLE_BRACKETS or 1) end },
    },
    build = function(rows)
        local seen = {}
        forEachAchievement(function(id, cat, subcat)
            if seen[id] then return end
            seen[id] = true
            local name, desc, points, icon, completed, date = Try(GetAchievementInfo, id)
            rows[#rows + 1] = {
                id = id, name = Clean(name), description = desc, points = points, icon = icon,
                completed = bool(completed), date = nonEmpty(date), category = cat, subcategory = subcat,
            }
        end)
    end,
})

E.RegisterTable({
    name = "achievement_criteria",
    desc = "Progress on each achievement criterion",
    live = true,
    columns = {
        { "achievement_id", "int", "Achievement id" },
        { "achievement", "text", "Achievement name" },
        { "criterion_index", "int", "Criterion number" },
        { "description", "text", "What to do" },
        { "completed", "int", "Progress" },
        { "required", "int", "Needed" },
        { "done", "bool", "Criterion complete" },
    },
    build = function(rows)
        for _, a in ipairs(E.GetRows(E.GetTable("achievements"))) do
            for i = 1, (Try(GetAchievementNumCriteria, a.id) or 0) do
                Tick()
                local desc, done, req = Try(GetAchievementCriterion, a.id, i)
                rows[#rows + 1] = {
                    achievement_id = a.id, achievement = a.name, criterion_index = i,
                    description = desc, completed = done, required = req,
                    done = done ~= nil and req ~= nil and done >= req,
                }
            end
        end
    end,
})

FUNCS.ACHIEVEMENT_NAME = function(id) id = tonumber(id); return id and Clean(Try(GetAchievementName, id)) end

---------------------------------------------------------------------------
-- collectibles
---------------------------------------------------------------------------
E.RegisterTable({
    name = "collectibles",
    desc = "Mounts, pets, costumes, houses, mementos, emotes, skill styles... with unlock state",
    key = "id",
    live = true,
    columns = {
        { "id", "int", "Collectible id" },
        { "name", "text", "Name" },
        { "category_type", "text", "mount, vanity_pet, costume, house, memento, ..." },
        { "category", "text", "Collections category", function(r) return Clean(Try(GetCollectibleCategoryNameByCollectibleId, r.id)) end },
        { "unlocked", "bool", "Unlocked on this account" },
        { "active", "bool", "Active now" },
        { "purchasable", "bool", "Sold in the Crown Store" },
        { "description", "text", "Description", function(r) return Try(GetCollectibleDescription, r.id) end },
        { "hint", "text", "Where to get it", function(r) return nonEmpty(Try(GetCollectibleHint, r.id)) end },
        { "icon", "text", "Icon" },
        { "nickname", "text", "Your nickname", function(r) return nonEmpty(Try(GetCollectibleNickname, r.id)) end },
        { "reference_id", "int", "Referenced id (house id, ...)", function(r) return Try(GetCollectibleReferenceId, r.id) end },
        { "linked_achievement", "int", "Achievement that grants it", function(r)
            local v = Try(GetCollectibleLinkedAchievement, r.id); if v and v > 0 then return v end end },
        { "link", "text", "Chat link", function(r) return Try(GetCollectibleLink, r.id, LINK_STYLE_BRACKETS or 1) end },
    },
    build = function(rows)
        local lo, hi = E.EnumRange("COLLECTIBLE_CATEGORY_TYPE_", 0, 40)
        local seen = {}
        for ct = lo or 0, hi or 40 do
            local catName = EnumShort("COLLECTIBLE_CATEGORY_TYPE_", ct)
            for i = 1, (Try(GetTotalCollectiblesByCategoryType, ct) or 0) do
                Tick()
                local id = Try(GetCollectibleIdFromType, ct, i)
                if id and id > 0 and not seen[id] then
                    seen[id] = true
                    local name, _, icon, _, unlocked, purchasable, active = Try(GetCollectibleInfo, id)
                    rows[#rows + 1] = {
                        id = id, name = Clean(name), category_type = catName, icon = icon,
                        unlocked = bool(unlocked), purchasable = bool(purchasable), active = bool(active),
                    }
                end
            end
        end
    end,
})

FUNCS.COLLECTIBLE_NAME = function(id) id = tonumber(id); return id and Clean(Try(GetCollectibleName, id)) end

---------------------------------------------------------------------------
-- titles / dyes / emotes
---------------------------------------------------------------------------
E.RegisterTable({
    name = "titles",
    desc = "Titles you have earned",
    live = true,
    columns = { { "title_index", "int", "Index" }, { "name", "text", "Title" } },
    build = function(rows)
        for i = 1, (Try(GetNumTitles) or 0) do
            Tick()
            rows[#rows + 1] = { title_index = i, name = Clean(Try(GetTitle, i)) }
        end
    end,
})

E.RegisterTable({
    name = "dyes",
    desc = "Every dye with colour and unlock state",
    key = "id",
    live = true,
    columns = {
        { "id", "int", "Dye id" },
        { "name", "text", "Dye name" },
        { "known", "bool", "Unlocked" },
        { "rarity", "text", "common, uncommon, rare, material..." },
        { "hue", "text", "Hue category" },
        { "achievement_id", "int", "Achievement that unlocks it" },
        { "r", "num", "Red 0-1" }, { "g", "num", "Green 0-1" }, { "b", "num", "Blue 0-1" },
        { "hex", "text", "RRGGBB" },
    },
    build = function(rows)
        for i = 1, (Try(GetNumDyes) or 0) do
            Tick()
            local name, known, rarity, hue, achId, r, g, b, _, dyeId = Try(GetDyeInfo, i)
            if name then
                rows[#rows + 1] = {
                    id = dyeId, name = Clean(name), known = bool(known),
                    rarity = rarity and EnumShort("DYE_RARITY_", rarity),
                    hue = hue and EnumShort("DYE_HUE_CATEGORY_", hue),
                    achievement_id = achId and achId > 0 and achId or nil,
                    r = r, g = g, b = b,
                    hex = r and string.format("%02X%02X%02X", r * 255, g * 255, b * 255),
                }
            end
        end
    end,
})

E.RegisterTable({
    name = "emotes",
    desc = "Every emote with its slash command",
    key = "id",
    columns = {
        { "id", "int", "Emote id" },
        { "emote_index", "int", "Index" },
        { "slash", "text", "Slash command" },
        { "name", "text", "Display name" },
        { "category", "text", "EmoteCategory" },
        { "collectible_id", "int", "Collectible that unlocks it", function(r)
            local v = Try(GetEmoteCollectibleId, r.emote_index); if v and v > 0 then return v end end },
    },
    build = function(rows)
        for i = 1, (Try(GetNumEmotes) or 0) do
            Tick()
            local slash, cat, id, name = Try(GetEmoteInfo, i)
            rows[#rows + 1] = {
                id = id, emote_index = i, slash = slash, name = Clean(name),
                category = cat and EnumShort("EMOTE_CATEGORY_", cat),
            }
        end
    end,
})

---------------------------------------------------------------------------
-- lore books / antiquities / recipes
---------------------------------------------------------------------------
E.RegisterTable({
    name = "lore_books",
    desc = "Lore library books (Eidetic Memory, Shalidor's Library, crafting motifs...)",
    live = true,
    columns = {
        { "book_id", "int", "Book id" },
        { "title", "text", "Title" },
        { "known", "bool", "You have read it" },
        { "category", "text", "Library category" },
        { "collection", "text", "Collection" },
        { "category_index", "int", "Category index" },
        { "collection_index", "int", "Collection index" },
        { "book_index", "int", "Book index" },
        { "icon", "text", "Icon" },
    },
    build = function(rows)
        for c = 1, (Try(GetNumLoreCategories) or 0) do
            local catName, numColl = Try(GetLoreCategoryInfo, c)
            for k = 1, (numColl or 0) do
                local collName, _, _, total = Try(GetLoreCollectionInfo, c, k)
                for b = 1, (total or 0) do
                    Tick()
                    local title, icon, known, bookId = Try(GetLoreBookInfo, c, k, b)
                    if title then
                        rows[#rows + 1] = {
                            book_id = bookId, title = Clean(title), known = bool(known), icon = icon,
                            category = Clean(catName), collection = Clean(collName),
                            category_index = c, collection_index = k, book_index = b,
                        }
                    end
                end
            end
        end
    end,
})

E.RegisterTable({
    name = "antiquities",
    desc = "Antiquities with quality, difficulty, zone and progress",
    key = "id",
    live = true,
    columns = {
        { "id", "int", "Antiquity id" },
        { "name", "text", "Name" },
        { "quality", "text", "AntiquityQuality" },
        { "difficulty", "text", "AntiquityDifficulty" },
        { "zone_id", "int", "Zone id" },
        { "zone", "text", "Zone name" },
        { "set_name", "text", "Antiquity set (mythic, furnishing set...)" },
        { "category", "text", "Category" },
        { "recovered", "int", "Times recovered" },
        { "lore_found", "int", "Lore entries found" },
        { "lore_total", "int", "Lore entries" },
        { "reward_id", "int", "Reward id" },
        { "icon", "text", "Icon" },
    },
    build = function(rows)
        local id = Try(GetNextAntiquityId)
        while id do
            Tick()
            local zoneId = Try(GetAntiquityZoneId, id)
            local setId = Try(GetAntiquitySetId, id)
            local catId = Try(GetAntiquityCategoryId, id)
            local q = Try(GetAntiquityQuality, id)
            local d = Try(GetAntiquityDifficulty, id)
            rows[#rows + 1] = {
                id = id, name = Clean(Try(GetAntiquityName, id)),
                quality = q and EnumShort("ANTIQUITY_QUALITY_", q),
                difficulty = d and EnumShort("ANTIQUITY_DIFFICULTY_", d),
                zone_id = zoneId, zone = zoneId and zoneId > 0 and Clean(Try(GetZoneNameById, zoneId)) or nil,
                set_name = setId and setId > 0 and Clean(Try(GetAntiquitySetName, setId)) or nil,
                category = catId and catId > 0 and Clean(Try(GetAntiquityCategoryName, catId)) or nil,
                recovered = Try(GetNumAntiquitiesRecovered, id),
                lore_found = Try(GetNumAntiquityLoreEntriesAcquired, id),
                lore_total = Try(GetNumAntiquityLoreEntries, id),
                reward_id = Try(GetAntiquityRewardId, id),
                icon = Try(GetAntiquityIcon, id),
            }
            id = Try(GetNextAntiquityId, id)
        end
    end,
})

E.RegisterTable({
    name = "recipes",
    desc = "Provisioning and furnishing recipes with result items and whether you know them",
    live = true,
    columns = {
        { "list", "text", "Recipe list" },
        { "list_index", "int", "List index" },
        { "recipe_index", "int", "Recipe index" },
        { "name", "text", "Recipe name" },
        { "known", "bool", "Known" },
        { "num_ingredients", "int", "Ingredients" },
        { "skill_required", "int", "Provisioner rank needed" },
        { "quality_required", "int", "Recipe quality rank needed" },
        { "station", "text", "Crafting station", },
        { "result_link", "text", "Result item link", function(r)
            return Try(GetRecipeResultItemLink, r.list_index, r.recipe_index, LINK_STYLE_DEFAULT or 0) end },
        { "ingredients", "text", "Ingredients", function(r)
            local parts = {}
            for i = 1, (r.num_ingredients or 0) do
                local name, _, _, qty = Try(GetRecipeIngredientItemInfo, r.list_index, r.recipe_index, i)
                if name then parts[#parts + 1] = (qty and qty > 1 and (qty .. "x ") or "") .. Clean(name) end
            end
            return table.concat(parts, ", ") end },
    },
    build = function(rows)
        for l = 1, (Try(GetNumRecipeLists) or 0) do
            local listName, numRecipes = Try(GetRecipeListInfo, l)
            for i = 1, (numRecipes or 0) do
                Tick()
                local known, name, numIng, skillReq, qualReq, _, station = Try(GetRecipeInfo, l, i)
                rows[#rows + 1] = {
                    list = Clean(listName), list_index = l, recipe_index = i,
                    name = Clean(name), known = bool(known), num_ingredients = numIng,
                    skill_required = skillReq, quality_required = qualReq,
                    station = station and EnumShort("CRAFTING_TYPE_", station),
                }
            end
        end
    end,
})

---------------------------------------------------------------------------
-- social: guilds, friends, group
---------------------------------------------------------------------------
E.RegisterTable({
    name = "guilds",
    desc = "Your guilds",
    live = true,
    columns = {
        { "id", "int", "Guild id" }, { "name", "text", "Guild name" },
        { "members", "int", "Member count" }, { "guild_index", "int", "Index" },
    },
    build = function(rows)
        for i = 1, (Try(GetNumGuilds) or 0) do
            Tick()
            local id = Try(GetGuildId, i)
            rows[#rows + 1] = { id = id, guild_index = i, name = Try(GetGuildName, id), members = Try(GetNumGuildMembers, id) }
        end
    end,
})

E.RegisterTable({
    name = "guild_members",
    desc = "Members of all your guilds",
    live = true,
    columns = {
        { "guild", "text", "Guild name" }, { "guild_id", "int", "Guild id" },
        { "account", "text", "@account" }, { "note", "text", "Member note" },
        { "rank_index", "int", "Guild rank index" }, { "status", "text", "online, away, offline..." },
        { "offline_seconds", "int", "Seconds since last online" },
    },
    build = function(rows)
        for i = 1, (Try(GetNumGuilds) or 0) do
            local gid = Try(GetGuildId, i)
            local gname = Try(GetGuildName, gid)
            for m = 1, (Try(GetNumGuildMembers, gid) or 0) do
                Tick()
                local account, note, rankIndex, status, offline = Try(GetGuildMemberInfo, gid, m)
                rows[#rows + 1] = {
                    guild = gname, guild_id = gid, account = account, note = nonEmpty(note),
                    rank_index = rankIndex, status = status and EnumShort("PLAYER_STATUS_", status), offline_seconds = offline,
                }
            end
        end
    end,
})

E.RegisterTable({
    name = "friends",
    desc = "Your friends list",
    live = true,
    columns = {
        { "account", "text", "@account" }, { "note", "text", "Note" },
        { "status", "text", "online, away, offline..." }, { "offline_seconds", "int", "Seconds since last online" },
    },
    build = function(rows)
        for i = 1, (Try(GetNumFriends) or 0) do
            Tick()
            local account, note, status, offline = Try(GetFriendInfo, i)
            rows[#rows + 1] = { account = account, note = nonEmpty(note), status = status and EnumShort("PLAYER_STATUS_", status), offline_seconds = offline }
        end
    end,
})

E.RegisterTable({
    name = "group_members",
    desc = "Your group members",
    live = true,
    columns = {
        { "unit", "text", "Unit tag" }, { "name", "text", "Character name" }, { "account", "text", "@account" },
        { "class", "text", "Class" }, { "role", "text", "dps, tank, heal" }, { "level", "int", "Level" },
        { "cp", "int", "Champion points" }, { "zone", "text", "Zone" }, { "online", "bool", "Online" },
        { "leader", "bool", "Group leader" }, { "health", "int", "Current health" }, { "health_max", "int", "Max health" },
    },
    build = function(rows)
        for i = 1, (Try(GetGroupSize) or 0) do
            Tick()
            local unit = Try(GetGroupUnitTagByIndex, i) or ("group" .. i)
            local role = Try(GetGroupMemberSelectedRole, unit)
            local hp, hpMax = Try(GetUnitPower, unit, COMBAT_MECHANIC_FLAGS_HEALTH or 32)
            rows[#rows + 1] = {
                unit = unit, name = Clean(Try(GetUnitName, unit)), account = Try(GetUnitDisplayName, unit),
                class = Clean(Try(GetUnitClass, unit)), role = role and EnumShort("LFG_ROLE_", role),
                level = Try(GetUnitLevel, unit), cp = Try(GetUnitChampionPoints, unit), zone = Clean(Try(GetUnitZone, unit)),
                online = bool(Try(IsUnitOnline, unit)), leader = bool(Try(IsUnitGroupLeader, unit)),
                health = hp, health_max = hpMax,
            }
        end
    end,
})
