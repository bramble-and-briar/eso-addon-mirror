-- Tamriel Collections - Archive Style Pages v1.1.1
-- Groups individual outfit Style Pages into their ESO item-style families.
local TC = TamrielCollections

local STYLE_PAGES_ICON = 'EsoUI/Art/Inventory/inventory_tabIcon_trophy_up.dds'
local GOLD = '|cFFEBB3'
local GREEN = '|c66CC66'
local RED = '|cE57373'

local function Normalize(text)
    text = zo_strlower(zo_strformat(text or ''))
    -- Normalize common typographic punctuation ESO/localizations may use before
    -- applying Lua's ASCII punctuation class.
    text = text:gsub('’', ' '):gsub('‘', ' '):gsub('–', ' '):gsub('—', ' ')
    text = text:gsub('[%p%c]+', ' ')
    text = text:gsub('%s+', ' ')
    return text:gsub('^%s+', ''):gsub('%s+$', '')
end

local STYLE_PAGE_GEAR_SUFFIXES = {
    -- Weapons
    'Battle Axe', 'Greatsword', 'Bludgeon', 'Dagger', 'Shield', 'Staff', 'Sword', 'Mace', 'Maul', 'Bow', 'Axe',

    -- Standard armour / outfit slots
    'Arm Cops', 'Arm Cop', 'Pauldrons', 'Pauldron', 'Shoulders', 'Shoulder', 'Epaulets',
    'Gauntlets', 'Bracers', 'Gloves', 'Wraps',
    'Cuirass', 'Jerkin', 'Jack', 'Robe', 'Shawl', 'Chest',
    'Breeches', 'Greaves', 'Guards', 'Pants',
    'Sabatons', 'Sandals', 'Shoes', 'Boots',
    'Girdle', 'Waster', 'Sash', 'Belt',
    'Helmet', 'Visage', 'Mask', 'Hood', 'Helm', 'Hat',
}

-- Always test the most specific/longest gear names first.  Without this,
-- "Battle Axe" could be stripped as only "Axe", leaving "Battle" attached
-- to the family name.  The same protection applies to multi-word armour slots.
table.sort(STYLE_PAGE_GEAR_SUFFIXES, function(a, b)
    return #a > #b
end)

local function StripStylePageGearSuffix(name)
    local value = zo_strformat(name or '')
    value = value:gsub('^%s*[Ss]tyle [Pp]age:%s*', '')
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    for _, suffix in ipairs(STYLE_PAGE_GEAR_SUFFIXES) do
        local escaped = suffix:gsub('([^%w])', '%%%1')
        local stripped = value:gsub("['’]s%s+" .. escaped .. '$', '')
        if stripped ~= value then return stripped end
        stripped = value:gsub('%s+' .. escaped .. '$', '')
        if stripped ~= value then return stripped end
    end
    return value
end

local function GetStylePageFamilyName(collectibleData, pageName)
    local rawFamily = collectibleData.GetOutfitStyleItemStyleName and collectibleData:GetOutfitStyleItemStyleName() or ''
    rawFamily = zo_strformat(rawFamily or '')
    local cleaned = StripStylePageGearSuffix(rawFamily)
    if cleaned ~= '' and Normalize(cleaned) ~= Normalize(pageName) then
        return cleaned
    end
    local fromPage = StripStylePageGearSuffix(pageName)
    if fromPage ~= '' then return fromPage end
    return rawFamily ~= '' and rawFamily or pageName
end

local function CleanPageDisplayName(pageName, familyName)
    local page = zo_strformat(pageName or '')
    local family = zo_strformat(familyName or '')
    if page == '' then return 'Style Page' end
    if family == '' then return page end

    -- ESO page names commonly begin with the family name (sometimes possessive)
    -- or place the actual piece name after a colon. Keep only the useful piece name
    -- in the right-hand list while retaining the complete original name in data.
    local lowerPage = zo_strlower(page)
    local lowerFamily = zo_strlower(family)
    if lowerPage:find(lowerFamily, 1, true) == 1 then
        local suffix = page:sub(#family + 1)
        suffix = suffix:gsub("^['’]s%s*", '')
        suffix = suffix:gsub('^%s*[:%-–]%s*', '')
        suffix = suffix:gsub('^%s*[Ss]tyle%s+[Pp]age%s*[:%-–]?%s*', '')
        suffix = suffix:gsub('^%s+', ''):gsub('%s+$', '')
        if suffix ~= '' then return suffix end
    end

    local colonSuffix = page:match(':%s*(.+)$')
    if colonSuffix and colonSuffix ~= '' then return colonSuffix end
    return page
end

local stylePageFamiliesCache = nil

local function RefreshCachedFamilyProgress(result)
    for _, family in ipairs(result or {}) do
        local known = 0
        for _, page in ipairs(family.pages or {}) do
            local unlocked = page.collectibleData and page.collectibleData:IsUnlocked() or false
            page.unlocked = unlocked
            if unlocked then known = known + 1 end
        end
        family.known = known
        family.total = #(family.pages or {})
        family.missing = math.max(0, family.total - family.known)
        family.unlocked = family.total > 0 and family.known == family.total
    end
end

local function SortStylePageFamilies(result)
    for _, family in ipairs(result or {}) do
        for _, page in ipairs(family.pages or {}) do
            page.sortKey = page.sortKey or zo_strlower(page.displayName or page.name or '')
        end
        table.sort(family.pages, function(a, b)
            return (a.sortKey or '') < (b.sortKey or '')
        end)
        family.sortKey = family.sortKey or zo_strlower(family.name or '')
    end

    table.sort(result, function(a, b)
        local aComplete = (a.missing or 0) == 0
        local bComplete = (b.missing or 0) == 0
        if aComplete ~= bComplete then return not aComplete end
        if not aComplete and (a.missing or 0) ~= (b.missing or 0) then
            return (a.missing or 0) < (b.missing or 0)
        end
        return (a.sortKey or '') < (b.sortKey or '')
    end)
end

local function CleanStylePageCollectibleName(name)
    local value = zo_strformat(name or '')
    value = value:gsub('^%s*[Ss]tyle [Pp]age:%s*', '')
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    return value
end

local function CleanFamilyDisplayName(name)
    local value = CleanStylePageCollectibleName(name)
    -- Character/signature pages are often named "Abnur Tharn's Staff" or
    -- "The Maelstrom's Mace".  The family heading should be the actual set
    -- name, not the possessive left behind after the gear word is removed.
    value = value:gsub("['’]s$", '')
    value = value:gsub("['’]$", '')
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    return value
end

local function BuildStylePageFamiliesFromCandidates(candidates)
    local prefixCounts = {}

    -- ESO's itemStyleId is not a Style Page family identifier.  Discover real
    -- families from the collectible names. Count repeated multi-word prefixes
    -- first, then each page chooses its longest repeated prefix.
    for _, candidate in ipairs(candidates or {}) do
        local words = {}
        for word in (candidate.name or ''):gmatch('%S+') do
            words[#words + 1] = word
        end
        candidate._familyWords = words

        -- Some ESO pages append a numeric variant after the gear slot, e.g.
        -- "Gold Road Dragoon Jack 1" and "Gold Road Dragoon Jack 2".  Strip the
        -- numeric qualifier first, then the gear slot, so the repeated-prefix
        -- detector cannot invent a bogus "Gold Road Dragoon Jack" family.
        local nonNumericName = (candidate.name or ''):gsub('%s+%d+$', '')
        local canonicalFamily = CleanFamilyDisplayName(StripStylePageGearSuffix(nonNumericName))
        if canonicalFamily ~= '' and Normalize(canonicalFamily) ~= Normalize(candidate.name or '') then
            candidate._canonicalFamily = canonicalFamily
        end

        for wordCount = 2, #words - 1 do
            local prefix = table.concat(words, ' ', 1, wordCount)
            local key = Normalize(prefix)
            if key ~= '' then
                prefixCounts[key] = (prefixCounts[key] or 0) + 1
            end
        end
    end

    local familiesByName = {}
    local result = {}

    for _, candidate in ipairs(candidates or {}) do
        local words = candidate._familyWords or {}
        local familyName = candidate._canonicalFamily

        for wordCount = #words - 1, 2, -1 do
            if familyName and familyName ~= '' then break end
            local prefix = table.concat(words, ' ', 1, wordCount)
            local key = Normalize(prefix)
            if key ~= '' and (prefixCounts[key] or 0) >= 2 then
                familyName = prefix
                break
            end
        end

        if not familyName or familyName == '' then
            familyName = StripStylePageGearSuffix(candidate.name)
        end
        familyName = CleanFamilyDisplayName(familyName)
        if familyName == '' then familyName = candidate.name end

        local familyKey = Normalize(familyName)
        local family = familiesByName[familyKey]
        if not family then
            local collectibleData = candidate.collectibleData
            family = {
                name = familyName,
                pages = {},
                known = 0,
                total = 0,
                icon = candidate.icon,
                collectibleData = collectibleData,
                description = collectibleData and collectibleData.GetDescription and (collectibleData:GetDescription() or '') or '',
                hint = collectibleData and collectibleData.GetHint and (collectibleData:GetHint() or '') or '',
                sortKey = zo_strlower(familyName),
            }
            familiesByName[familyKey] = family
            result[#result + 1] = family
        end

        local displayName = CleanPageDisplayName(candidate.name, family.name)
        local page = {
            name = candidate.name,
            displayName = displayName,
            sortKey = zo_strlower(displayName or candidate.name or ''),
            icon = candidate.icon,
            collectibleId = candidate.collectibleId,
            collectibleData = candidate.collectibleData,
            unlocked = candidate.unlocked,
            description = candidate.collectibleData and candidate.collectibleData.GetDescription and (candidate.collectibleData:GetDescription() or '') or '',
            hint = candidate.collectibleData and candidate.collectibleData.GetHint and (candidate.collectibleData:GetHint() or '') or '',
        }
        family.pages[#family.pages + 1] = page
        family.total = family.total + 1
        if candidate.unlocked then family.known = family.known + 1 end
    end

    return result
end

local function IsNativeMotifArmorType(visualArmorType)
    return visualArmorType == VISUAL_ARMORTYPE_LIGHT
        or visualArmorType == VISUAL_ARMORTYPE_MEDIUM
        or visualArmorType == VISUAL_ARMORTYPE_HEAVY
end

local function IsNativeStylePageArmorType(visualArmorType)
    return visualArmorType == VISUAL_ARMORTYPE_SIGNATURE
        or visualArmorType == VISUAL_ARMORTYPE_UNDAUNTED
end

local function GetOutfitCategoryContainers()
    local result = {}
    if not (ZO_COLLECTIBLE_DATA_MANAGER and ZO_CollectibleCategoryData and ZO_CollectibleCategoryData.IsOutfitStylesCategory) then
        return result
    end

    for _, categoryData in ZO_COLLECTIBLE_DATA_MANAGER:CategoryIterator({ ZO_CollectibleCategoryData.IsOutfitStylesCategory }) do
        result[#result + 1] = categoryData
        for subcategoryIndex = 1, categoryData:GetNumSubcategories() do
            local subcategoryData = categoryData:GetSubcategoryData(subcategoryIndex)
            if subcategoryData then
                result[#result + 1] = subcategoryData
            end
        end
    end
    return result
end

local function BuildStylePageFamiliesFromNativeCollections()
    if stylePageFamiliesCache then
        RefreshCachedFamilyProgress(stylePageFamiliesCache)
        SortStylePageFamilies(stylePageFamiliesCache)
        return stylePageFamiliesCache
    end

    local categoryContainers = GetOutfitCategoryContainers()
    if #categoryContainers == 0 then
        stylePageFamiliesCache = {}
        return stylePageFamiliesCache
    end

    -- ESO already classified Outfit Style armor as Light / Medium / Heavy /
    -- Signature / Undaunted.  Use those native classifications directly.
    -- We first learn which item-style IDs belong to ordinary crafting motifs
    -- and which belong to Signature/Undaunted pages, without doing any text
    -- formatting.  This replaces the old GetNumValidItemStyles() heuristic,
    -- which also contains many non-motif item styles and excluded real pages.
    local motifStyleIds = {}
    local specialStyleIds = {}
    local allShownOutfitCollectibles = {}
    local seenCollectibles = {}

    for _, categoryData in ipairs(categoryContainers) do
        local numCollectibles = categoryData:GetNumCollectibles()
        for collectibleIndex = 1, numCollectibles do
            local collectibleData = categoryData:GetCollectibleDataByIndex(collectibleIndex)
            if collectibleData
                and collectibleData.IsOutfitStyle and collectibleData:IsOutfitStyle()
                and (not collectibleData.IsShownInCollection or collectibleData:IsShownInCollection()) then

                local collectibleId = collectibleData:GetId()
                if collectibleId and not seenCollectibles[collectibleId] then
                    seenCollectibles[collectibleId] = true
                    allShownOutfitCollectibles[#allShownOutfitCollectibles + 1] = collectibleData

                    if collectibleData.IsArmorStyle and collectibleData:IsArmorStyle() then
                        local itemStyleId = collectibleData.GetOutfitStyleItemStyleId and collectibleData:GetOutfitStyleItemStyleId() or 0
                        if itemStyleId and itemStyleId > 0 then
                            local visualArmorType = collectibleData:GetVisualArmorType()
                            if IsNativeStylePageArmorType(visualArmorType) then
                                specialStyleIds[itemStyleId] = true
                            elseif IsNativeMotifArmorType(visualArmorType) then
                                motifStyleIds[itemStyleId] = true
                            end
                        end
                    end
                end
            end
        end
    end

    local candidates = {}
    for _, collectibleData in ipairs(allShownOutfitCollectibles) do
        local include = false
        local itemStyleId = collectibleData.GetOutfitStyleItemStyleId and collectibleData:GetOutfitStyleItemStyleId() or 0

        if collectibleData.IsArmorStyle and collectibleData:IsArmorStyle() then
            -- This is exactly what the native Collections UI exposes as the
            -- Signature and Undaunted armor sections.
            include = IsNativeStylePageArmorType(collectibleData:GetVisualArmorType())
        elseif collectibleData.IsWeaponStyle and collectibleData:IsWeaponStyle() then
            -- Weapons do not have a Signature visual-armor type. Carry across
            -- IDs proven special by armor. Also retain weapon-only style IDs
            -- that never occur in Light/Medium/Heavy motif armor.
            include = itemStyleId and itemStyleId > 0
                and (specialStyleIds[itemStyleId] or not motifStyleIds[itemStyleId])
        end

        if include then
            local collectibleId = collectibleData:GetId()
            local pageName = CleanStylePageCollectibleName(collectibleData:GetName() or ('Style Page ' .. tostring(collectibleId)))
            if pageName ~= '' then
                candidates[#candidates + 1] = {
                    name = pageName,
                    icon = collectibleData:GetIcon(),
                    collectibleId = collectibleId,
                    collectibleData = collectibleData,
                    unlocked = collectibleData:IsUnlocked(),
                }
            end
        end
    end

    local result = BuildStylePageFamiliesFromCandidates(candidates)
    RefreshCachedFamilyProgress(result)
    SortStylePageFamilies(result)
    stylePageFamiliesCache = result
    return stylePageFamiliesCache
end

local function GetAchievementDisplay(collectibleData)
    if not collectibleData or not collectibleData.GetLinkedAchievement then return nil end
    local achievementId = collectibleData:GetLinkedAchievement()
    if not achievementId or achievementId == 0 or not GetAchievementInfo then return nil end
    local name, description, _, icon, completed = GetAchievementInfo(achievementId)
    return {
        id = achievementId,
        name = zo_strformat(name or ''),
        description = zo_strformat(description or ''),
        icon = icon,
        completed = completed == true,
    }
end

local function FindFamilyAchievement(family)
    for _, page in ipairs((family and family.pages) or {}) do
        local achievement = GetAchievementDisplay(page.collectibleData)
        if achievement then return achievement end
    end
    return nil
end

local function GetFamilyAchievements(family)
    local result, seen = {}, {}
    for _, page in ipairs((family and family.pages) or {}) do
        local achievement = GetAchievementDisplay(page.collectibleData)
        if achievement and achievement.id and not seen[achievement.id] then
            seen[achievement.id] = true
            result[#result + 1] = achievement
        end
    end
    return result
end

local function FindFamilyAchievementByName(family, nameFragment)
    local needle = Normalize(nameFragment)
    for _, achievement in ipairs(GetFamilyAchievements(family)) do
        if Normalize(achievement.name):find(needle, 1, true) then
            return achievement
        end
    end
    return nil
end

local function CleanAcquisitionText(text)
    local value = zo_strformat(text or '')
    if value == '' then return '' end

    value = value:gsub('[Tt]his [Ii]tem [Cc]annot [Bb]e [Dd]yed%.?', '')
    value = value:gsub('[Tt]his [Oo]utfit [Ss]tyle [Cc]annot [Bb]e [Dd]yed%.?', '')
    value = value:gsub('[Tt]his [Cc]ollectible [Cc]annot [Bb]e [Dd]yed%.?', '')
    value = value:gsub('[Tt]his [Ss]tyle [Cc]annot [Bb]e [Dd]yed%.?', '')
    value = value:gsub('[Cc]annot [Bb]e [Dd]yed%.?', '')
    value = value:gsub('[Cc]an not [Bb]e [Dd]yed%.?', '')
    value = value:gsub('[Nn]ot [Dd]yeable%.?', '')
    value = value:gsub('\n+', ' ')
    value = value:gsub('%s+', ' ')
    value = value:gsub('^%s+', ''):gsub('%s+$', '')

    local normalized = Normalize(value)
    local usefulWords = {
        'acquir', 'obtain', 'complete', 'reward', 'drop', 'coffer', 'event',
        'impresario', 'merchant', 'tales of tribute', 'dungeon', 'trial',
        'arena', 'boss', 'achievement', 'portal', 'antiquity', 'dig',
        'wayshrine', 'daily quest', 'dynamic encounter',
    }
    if normalized:find('outfit look', 1, true) then
        local useful = false
        for _, word in ipairs(usefulWords) do
            if normalized:find(word, 1, true) then
                useful = true
                break
            end
        end
        if not useful then return '' end
    end
    return value
end

-- Curated Style Page acquisition database ------------------------------------
-- v0.1.13: source descriptions and map routing live in StylePageSources.lua.
-- ESO remains authoritative for ownership/collectible/achievement state, but
-- acquisition-map destinations are never inferred from arbitrary text.

local curatedStylePageSources = TamrielCollectionsStylePageSources or {}
local curatedStylePageSourceIndex = nil

local function BuildCuratedStylePageSourceIndex()
    if curatedStylePageSourceIndex then return curatedStylePageSourceIndex end
    curatedStylePageSourceIndex = {}
    for familyName, source in pairs(curatedStylePageSources) do
        local key = Normalize(familyName)
        if key ~= '' and type(source) == 'table' then
            curatedStylePageSourceIndex[key] = source
        end
    end
    return curatedStylePageSourceIndex
end

local function GetStylePageSourceOverride(family)
    if not family then return nil end
    return BuildCuratedStylePageSourceIndex()[Normalize(family.name or '')]
end

local function GetFamilyAcquisitionText(family)
    local override = GetStylePageSourceOverride(family)
    if override and override.text then return override.text end

    local values, seen = {}, {}
    local function Add(text)
        local cleaned = CleanAcquisitionText(text)
        local key = Normalize(cleaned)
        if cleaned ~= '' and key ~= '' and not seen[key] then
            seen[key] = true
            values[#values + 1] = cleaned
        end
    end

    Add(family and family.hint or '')
    Add(family and family.description or '')
    for _, page in ipairs((family and family.pages) or {}) do
        Add(page.hint or '')
        Add(page.description or '')
    end

    if #values > 0 then
        return table.concat(values, ' ')
    end

    local achievements = GetFamilyAchievements(family)
    if #achievements > 0 then
        local achievementParts = {}
        for _, achievement in ipairs(achievements) do
            local detail = CleanAcquisitionText(achievement.description or '')
            if detail ~= '' then
                achievementParts[#achievementParts + 1] = string.format('Complete the achievement "%s": %s', achievement.name, detail)
            else
                achievementParts[#achievementParts + 1] = string.format('Complete the achievement "%s".', achievement.name)
            end
        end
        return table.concat(achievementParts, ' ')
    end

    return 'Source not yet verified in Tamriel Collections.'
end


local function GetFamilyAchievementText(family)
    local achievements = GetFamilyAchievements(family)
    if #achievements == 0 then return '' end
    local parts = {}
    for _, achievement in ipairs(achievements) do
        local status = achievement.completed and (GREEN .. 'Completed|r') or (RED .. 'Not completed|r')
        local name = achievement.name or 'Achievement'
        if achievement.icon and achievement.icon ~= '' then
            name = string.format('|t24:24:%s|t %s', achievement.icon, name)
        end
        parts[#parts + 1] = string.format('%s — %s', name, status)
    end
    return table.concat(parts, '\n')
end

-- Style Pages map support ----------------------------------------------------
local stylePageFastTravelNodes = nil
local stylePagePoiIndex = nil

local function BuildStylePageFastTravelNodes()
    if stylePageFastTravelNodes then return stylePageFastTravelNodes end
    stylePageFastTravelNodes = {}
    if not (GetNumFastTravelNodes and GetFastTravelNodeInfo and GetFastTravelNodePOIIndicies) then
        return stylePageFastTravelNodes
    end
    for nodeIndex = 1, GetNumFastTravelNodes() do
        local _, name = GetFastTravelNodeInfo(nodeIndex)
        local zoneIndex, poiIndex = GetFastTravelNodePOIIndicies(nodeIndex)
        if name and name ~= '' and zoneIndex and poiIndex then
            local formattedName = zo_strformat(name)
            stylePageFastTravelNodes[#stylePageFastTravelNodes + 1] = {
                nodeIndex = nodeIndex,
                name = formattedName,
                normalizedName = Normalize(formattedName),
                zoneIndex = zoneIndex,
                poiIndex = poiIndex,
            }
        end
    end
    return stylePageFastTravelNodes
end

local function BuildStylePagePoiIndex()
    if stylePagePoiIndex then return stylePagePoiIndex end
    stylePagePoiIndex = {}
    if not (GetNumZones and GetNumPOIs and GetPOIInfo) then return stylePagePoiIndex end
    for zoneIndex = 1, GetNumZones() do
        for poiIndex = 1, (GetNumPOIs(zoneIndex) or 0) do
            local name = GetPOIInfo(zoneIndex, poiIndex)
            if name and name ~= '' then
                stylePagePoiIndex[#stylePagePoiIndex + 1] = {
                    name = zo_strformat(name),
                    normalizedName = Normalize(name),
                    zoneIndex = zoneIndex,
                    poiIndex = poiIndex,
                }
            end
        end
    end
    return stylePagePoiIndex
end

local function FindMapIndexForStylePageZone(zoneIndex)
    if not zoneIndex then return nil end
    if GetZoneId and GetMapIndexByZoneId then
        local zoneId = GetZoneId(zoneIndex)
        if zoneId then
            local mapIndex = GetMapIndexByZoneId(zoneId)
            if mapIndex and mapIndex > 0 then return mapIndex end
        end
    end
    if GetNumMaps and GetMapInfoByIndex then
        for mapIndex = 1, GetNumMaps() do
            local _, _, _, candidateZoneIndex = GetMapInfoByIndex(mapIndex)
            if candidateZoneIndex == zoneIndex then return mapIndex end
        end
    end
    return nil
end


local function FindMapIdForStylePageZone(zoneIndex)
    if not zoneIndex then return nil end
    if GetZoneId and GetMapIdByZoneId then
        local zoneId = GetZoneId(zoneIndex)
        if zoneId and zoneId > 0 then
            local mapId = GetMapIdByZoneId(zoneId)
            if mapId and mapId > 0 then return mapId end

            -- Some subzones do not have a map-list index but do have a parent
            -- zone map.  Falling back to the parent keeps nested locations usable.
            if GetParentZoneId then
                local parentZoneId = GetParentZoneId(zoneId)
                if parentZoneId and parentZoneId > 0 and parentZoneId ~= zoneId then
                    mapId = GetMapIdByZoneId(parentZoneId)
                    if mapId and mapId > 0 then return mapId end
                end
            end
        end
    end

    local mapIndex = FindMapIndexForStylePageZone(zoneIndex)
    if mapIndex and GetMapIdByIndex then
        local mapId = GetMapIdByIndex(mapIndex)
        if mapId and mapId > 0 then return mapId end
    end
    return nil
end

local function FindMapIndexByExactName(name)
    if not (GetNumMaps and GetMapNameByIndex) then return nil end
    local target = Normalize(name)
    if target == '' then return nil end
    for mapIndex = 1, GetNumMaps() do
        local mapName = zo_strformat(GetMapNameByIndex(mapIndex) or '')
        if Normalize(mapName) == target then
            return mapIndex
        end
    end
    return nil
end

local function FindNodeByExactName(name)
    local target = Normalize(name)
    if target == '' then return nil end
    for _, node in ipairs(BuildStylePageFastTravelNodes()) do
        if node.normalizedName == target then return node end
    end
    return nil
end

local MAP_NODE_GENERIC_WORDS = {
    wayshrine = true,
    dungeon = true,
    trial = true,
    arena = false,
}

local function GetTCMNodeCoreName(name)
    local normalized = Normalize(name)
    local words = {}
    for word in normalized:gmatch('%S+') do
        if not MAP_NODE_GENERIC_WORDS[word] then
            words[#words + 1] = word
        end
    end
    return table.concat(words, ' ')
end

local function FindNodeByTCMTargetName(name)
    local target = Normalize(name)
    if target == '' then return nil end
    local targetCore = GetTCMNodeCoreName(target)

    -- Exact native name first.
    for _, node in ipairs(BuildStylePageFastTravelNodes()) do
        if node.normalizedName == target then
            return node
        end
    end

    -- Then use the same generic-word stripping that TCM uses.  This handles
    -- native names such as "Moongrave Fane Wayshrine" when the curated target
    -- simply says "Moongrave Fane".
    for _, node in ipairs(BuildStylePageFastTravelNodes()) do
        local nodeCore = GetTCMNodeCoreName(node.normalizedName)
        if nodeCore ~= '' and (nodeCore == target or nodeCore == targetCore) then
            return node
        end
    end
    return nil
end

local function ScoreTCMNodeAgainstText(node, sourceText, styleText)
    local score = 0
    local core = GetTCMNodeCoreName(node.normalizedName)
    if core ~= '' and #core >= 4 then
        if sourceText:find(core, 1, true) then
            score = math.max(score, 100 + #core)
        end
        if styleText ~= '' and (core:find(styleText, 1, true) or styleText:find(core, 1, true)) then
            score = math.max(score, 80 + math.min(#core, #styleText))
        end
        for word in core:gmatch('%S+') do
            if #word >= 5 and sourceText:find(word, 1, true) then
                score = math.max(score, 40 + #word)
            end
        end
    end
    return score
end

local function FindTCMNodeFromExplicitSource(family, source)
    if not source then return nil end

    -- Curated nodeName is authoritative.  Try it directly before any scoring.
    if source.nodeName then
        local direct = FindNodeByTCMTargetName(source.nodeName)
        if direct then return direct end
    end

    -- Score only the explicit destination fields.  Do not include the long
    -- acquisition description here; it may mention other legitimate places and
    -- would reintroduce the ambiguous multi-location routing we are removing.
    local sourceText = Normalize(table.concat({
        source.nodeName or '',
        source.location or '',
    }, ' '))
    local styleText = Normalize((family and family.name) or '')
    local bestNode, bestScore = nil, 0

    for _, node in ipairs(BuildStylePageFastTravelNodes()) do
        local score = ScoreTCMNodeAgainstText(node, sourceText, styleText)
        if score > bestScore then
            bestNode, bestScore = node, score
        end
    end

    if bestNode and bestScore >= 45 then
        return bestNode
    end
    return nil
end

local function FindZoneByExactName(name)
    if not (GetNumZones and GetZoneNameByIndex) then return nil end
    local target = Normalize(name)
    if target == '' then return nil end
    for zoneIndex = 1, GetNumZones() do
        local zoneName = zo_strformat(GetZoneNameByIndex(zoneIndex) or '')
        if Normalize(zoneName) == target then
            return { zoneIndex = zoneIndex, name = zoneName }
        end
    end
    return nil
end


local function FindMapIdByExactName(name)
    local mapIndex = FindMapIndexByExactName(name)
    if mapIndex and GetMapIdByIndex then
        local mapId = GetMapIdByIndex(mapIndex)
        if mapId and mapId > 0 then return mapId end
    end

    local zone = FindZoneByExactName(name)
    if zone then
        return FindMapIdForStylePageZone(zone.zoneIndex)
    end
    return nil
end

local stylePageCityMapIds = {}
local function FindStylePageCityMapId(name)
    local key = Normalize(name)
    if stylePageCityMapIds[key] then return stylePageCityMapIds[key] end
    if not (GetNumMaps and GetMapIdByIndex and GetMapNameById) then return nil end

    -- GetNumMaps lists travel/zone maps, not all city maps. Enumerate native
    -- IDs up to the highest loaded zone-map ID, once per requested city.
    -- Alinor and Wayrest predate the current chapter maps; their map IDs are
    -- inside this range. Never substitute a parent zone for an absent city.
    local highestMapId = GetCurrentMapId and GetCurrentMapId() or 0
    for index = 1, GetNumMaps() do
        highestMapId = math.max(highestMapId, GetMapIdByIndex(index) or 0)
    end
    for mapId = 1, highestMapId do
        if Normalize(GetMapNameById(mapId)) == key then
            stylePageCityMapIds[key] = mapId
            return mapId
        end
    end
    return nil
end

local function FindPoiByExactName(name, preferredZoneIndex)
    local target = Normalize(name)
    if target == '' then return nil end

    -- When a zone is known, inspect only that zone.  This avoids rebuilding a
    -- game-wide POI index just to resolve one curated location.
    if preferredZoneIndex and GetNumPOIs and GetPOIInfo then
        for poiIndex = 1, (GetNumPOIs(preferredZoneIndex) or 0) do
            local poiName = GetPOIInfo(preferredZoneIndex, poiIndex)
            if poiName and Normalize(poiName) == target then
                return {
                    name = zo_strformat(poiName),
                    normalizedName = target,
                    zoneIndex = preferredZoneIndex,
                    poiIndex = poiIndex,
                }
            end
        end
        return nil
    end

    for _, poi in ipairs(BuildStylePagePoiIndex()) do
        if poi.normalizedName == target then
            return poi
        end
    end
    return nil
end

local function FindExactPoiFromExplicitSource(source)
    if not source then return nil end

    -- A NODE record may represent a dungeon entrance that ESO exposes as a POI
    -- rather than as a fast-travel node.  Check the same exact curated name as
    -- a POI before allowing any scored fallback.
    local candidates = {}
    local seen = {}
    local function AddCandidate(value)
        value = zo_strformat(value or '')
        local normalized = Normalize(value)
        if normalized ~= '' and not seen[normalized] then
            seen[normalized] = true
            candidates[#candidates + 1] = value
        end
    end

    AddCandidate(source.nodeName)
    AddCandidate(source.poiName)
    AddCandidate(source.location)

    for _, candidate in ipairs(candidates) do
        local poi = FindPoiByExactName(candidate, nil)
        if poi then return poi end
    end
    return nil
end

local function MakeNodeTarget(node, label, kind)
    if not node then return nil end
    return {
        kind = kind or 'node',
        nodeIndex = node.nodeIndex,
        zoneIndex = node.zoneIndex,
        poiIndex = node.poiIndex,
        mapId = FindMapIdForStylePageZone(node.zoneIndex),
        label = label or node.name,
        name = label or node.name,
    }
end

local function MakePoiTarget(poi, label, kind)
    if not poi then return nil end
    return {
        kind = kind or 'poi',
        zoneIndex = poi.zoneIndex,
        poiIndex = poi.poiIndex,
        mapId = FindMapIdForStylePageZone(poi.zoneIndex),
        label = label or poi.name,
        name = label or poi.name,
    }
end

local function MakeZoneTarget(zone, label, kind)
    if not zone then return nil end
    return {
        kind = kind or 'zone',
        zoneIndex = zone.zoneIndex,
        mapId = FindMapIdForStylePageZone(zone.zoneIndex),
        label = label or zone.name,
        name = label or zone.name,
    }
end

local function MakeWorldTarget(label)
    return {
        kind = 'world',
        label = label or 'World Map',
        name = label or 'World Map',
    }
end

local function MakeCoordinateTarget(mapName, x, y, label, kind)
    if not (mapName and x and y) then return nil end
    local mapIndex = FindMapIndexByExactName(mapName)
    local mapId = FindMapIdByExactName(mapName)
    if not mapIndex and not mapId then return nil end
    return {
        kind = kind or 'coord',
        mapIndex = mapIndex,
        mapId = mapId,
        mapName = mapName,
        x = x,
        y = y,
        label = label or mapName,
        name = label or mapName,
    }
end

local function MakeDirectMapTarget(mapName, label, kind)
    if not mapName then return nil end
    local mapIndex = FindMapIndexByExactName(mapName)
    local mapId = FindMapIdByExactName(mapName)
    if not mapIndex and not mapId then return nil end
    return {
        kind = kind or 'zone',
        mapIndex = mapIndex,
        mapId = mapId,
        mapName = mapName,
        label = label or mapName,
        name = label or mapName,
    }
end

local function MakeMapLocationTarget(mapName, locationNames, label, mapId)
    local target
    if mapId and mapId > 0 then
        target = { mapId = mapId, mapName = mapName, label = label, name = label }
    else
        target = MakeDirectMapTarget(mapName, label, 'location')
    end
    if not target then return nil end
    target.kind = 'location'
    target.locationNames = locationNames
    return target
end

local function GetStylePageMapLocationCoordinates(locationNames)
    if not (GetNumMapLocations and GetMapLocationTooltipHeader and GetMapLocationIcon) then
        return nil
    end
    local names = {}
    for _, name in ipairs(locationNames or {}) do names[Normalize(name)] = true end
    for locationIndex = 1, GetNumMapLocations() do
        local matches = names[Normalize(GetMapLocationTooltipHeader(locationIndex))]
        -- Some hubs use a service heading and list the named merchant/club in
        -- the tooltip. These are still exact names on the selected map.
        if not matches and GetNumMapLocationTooltipLines and GetMapLocationTooltipLineInfo then
            for lineIndex = 1, GetNumMapLocationTooltipLines(locationIndex) do
                local _, name = GetMapLocationTooltipLineInfo(locationIndex, lineIndex)
                if names[Normalize(name)] then matches = true; break end
            end
        end
        if matches then
            local _, x, y = GetMapLocationIcon(locationIndex)
            if x and y and x > 0 and y > 0 and x < 1 and y < 1 then return x, y end
        end
    end
    return nil
end

local function MakeExactPoiTarget(poiName, zoneName, label, kind)
    if not poiName then return nil end
    local zone = zoneName and FindZoneByExactName(zoneName) or nil
    local poi = zone and FindPoiByExactName(poiName, zone.zoneIndex) or nil
    return MakePoiTarget(poi, label or poiName, kind or 'source')
end


local function MakeExactPoiTargetInZones(poiName, zoneNames, label, kind)
    for _, zoneName in ipairs(zoneNames or {}) do
        local target = MakeExactPoiTarget(poiName, zoneName, label, kind)
        if target then return target end
    end
    -- Final exact-name lookup without a zone restriction.  This is still an
    -- exact match; it never performs fuzzy text routing.
    local poi = FindPoiByExactName(poiName, nil)
    return MakePoiTarget(poi, label or poiName, kind or 'source')
end

local function GetIncompleteAchievementCriterion(achievement, nameFragments)
    if not (achievement and achievement.id and GetAchievementNumCriteria and GetAchievementCriterion) then return nil end
    local numCriteria = GetAchievementNumCriteria(achievement.id) or 0
    for criterionIndex = 1, numCriteria do
        local description, numCompleted, numRequired = GetAchievementCriterion(achievement.id, criterionIndex)
        local normalized = Normalize(description or '')
        local matches = false
        for _, fragment in ipairs(nameFragments or {}) do
            if normalized:find(Normalize(fragment), 1, true) then
                matches = true
                break
            end
        end
        if matches and (numCompleted or 0) < (numRequired or 0) then
            return description
        end
    end
    return nil
end

local function ResolveDreadAurelianTarget(family)
    local delver = FindFamilyAchievementByName(family, 'Scalebreaker Delver')
    local missing = GetIncompleteAchievementCriterion(delver, { 'Moongrave Fane', 'Lair of Maarselok' })
    local normalizedMissing = Normalize(missing or '')
    if normalizedMissing:find('lair of maarselok', 1, true) then
        return MakeNodeTarget(FindNodeByExactName('Lair of Maarselok'), 'Lair of Maarselok - Veteran', 'achievement')
    elseif normalizedMissing:find('moongrave fane', 1, true) then
        return MakeNodeTarget(FindNodeByExactName('Moongrave Fane'), 'Moongrave Fane - Veteran', 'achievement')
    end
    return MakeNodeTarget(FindNodeByExactName('Moongrave Fane'), 'Moongrave Fane / Lair of Maarselok', 'achievement')
        or MakeNodeTarget(FindNodeByExactName('Lair of Maarselok'), 'Moongrave Fane / Lair of Maarselok', 'achievement')
end

local function GetAllianceStylePageHub()
    local alliance = GetUnitAlliance and GetUnitAlliance('player') or 0
    if alliance == ALLIANCE_ALDMERI_DOMINION then
        return {
            city = 'Vulkhel Guard',
            zoneName = 'Auridon',
            nodeName = 'Vulkhel Guard Wayshrine',
        }
    elseif alliance == ALLIANCE_EBONHEART_PACT then
        return {
            city = "Davon's Watch",
            zoneName = 'Stonefalls',
            nodeName = "Davon's Watch Wayshrine",
        }
    end
    -- Default to Daggerfall Covenant if the alliance API is unavailable.
    return {
        city = 'Daggerfall',
        zoneName = 'Glenumbra',
        nodeName = 'Daggerfall Wayshrine',
    }
end

local function MakeExactNodeTarget(nodeName, label, sourceKind)
    return MakeNodeTarget(FindNodeByExactName(nodeName), label or nodeName, sourceKind or 'source')
end


local function MakeExactNodeOrPoiTarget(name, label, kind)
    return MakeExactNodeTarget(name, label, kind)
        or MakeExactPoiTarget(name, nil, label or name, kind)
end

local function ResolveNamedLocationTarget(name, label, kind)
    if not name then return nil end
    return MakeExactNodeOrPoiTarget(name, label or name, kind or 'source')
        or MakeExactNodeOrPoiTarget(name .. ' Wayshrine', label or name, kind or 'source')
        or MakeZoneTarget(FindZoneByExactName(name), label or name, kind or 'source')
        or MakeDirectMapTarget(name, label or name, kind or 'source')
end

local function ResolveCuratedStylePageHub(hubKey)
    -- IMPORTANT: one hub key = one destination only.
    -- Do not add fallback chains here.  The TCM map code works reliably when
    -- it receives one unambiguous target and lets ESO position the native pin.

    if hubKey == 'NEW_LIFE' then
        return MakeNodeTarget(FindNodeByTCMTargetName('Kynesgrove Wayshrine'),
            "New Life Festival - Breda's tent north of Kynesgrove Wayshrine", 'event')

    elseif hubKey == 'BELKARTH_FESTIVAL' or hubKey == 'BELKARTH_IMPRESARIO' then
        return MakeMapLocationTarget('Craglorn', { 'Belkarth Festival Grounds', 'The Impresario' },
            'Impresario / Event Exchange - Belkarth')

    elseif hubKey == 'GLENUMBRA_IMPRESARIO' then
        return MakeCoordinateTarget('Glenumbra', 0.3396363258, 0.7399688363,
            'Impresario / Event Exchange - Glenumbra', 'event')

    elseif hubKey == 'GONFALON' then
        return MakeMapLocationTarget('Gonfalon Bay',
            { 'Gonfalon Gaming Hall', 'Gonfalon Tribute Club' }, 'Gonfalon Gaming Hall', 2163)

    elseif hubKey == 'WAR_RESEARCHER' then
        local alliance = GetUnitAlliance and GetUnitAlliance('player') or nil
        local gate, merchant = 'Southern High Rock Gate', 'Telfour'
        if alliance == ALLIANCE_ALDMERI_DOMINION then
            gate, merchant = 'Eastern Elsweyr Gate', 'Eanor'
        elseif alliance == ALLIANCE_EBONHEART_PACT then
            gate, merchant = 'Northern Morrowind Gate', 'Llivia Ralas'
        end
        local mapId = FindStylePageCityMapId(gate)
        if not mapId then return nil end
        local target = MakeMapLocationTarget(gate, { 'War Researcher', merchant },
            'War Researcher - ' .. gate, mapId)
        target.forceMapId = true
        target.expectedMapName = gate
        return target

    elseif hubKey == 'SOLSTICE_FELLOWSHIP' then
        -- Use the same native camp wayshrine as the confirmed Motifs route.
        local target = MakeExactNodeTarget('Rampart Camp Wayshrine',
            'Fellowship Camp - Solstice', 'source')
            or MakeExactPoiTarget('Rampart Camp Wayshrine', 'Solstice',
                'Fellowship Camp - Solstice', 'source')
        if target then
            target.preferredLocationNames = { 'Fellowship Camp', 'Stirk Fellowship Camp' }
        end
        return target

    elseif hubKey == 'STIRK_FELLOWSHIP' then
        -- Stirk 572 is the old main-quest island. Zone 1508 is the Fellowship
        -- island; selecting by the shared name alone can choose the old copy.
        local zoneIndex = GetZoneIndex and GetZoneIndex(1508) or nil
        if not zoneIndex or zoneIndex <= 0 then return nil end
        local target
        for _, node in ipairs(BuildStylePageFastTravelNodes()) do
            if node.zoneIndex == zoneIndex and node.normalizedName == Normalize('Stirk Wayshrine') then
                target = MakeNodeTarget(node, 'Stirk Fellowship Camp', 'source')
                break
            end
        end
        if not target then
            local poi = FindPoiByExactName('Stirk Wayshrine', zoneIndex)
            target = MakePoiTarget(poi, 'Stirk Fellowship Camp', 'source')
        end
        if not target then
            target = MakeMapLocationTarget('Stirk', { 'Stirk Fellowship Camp' },
                'Stirk Fellowship Camp', GetMapIdByZoneId and GetMapIdByZoneId(1508))
        end
        if not target then return nil end
        -- A node can have a map-list entry on a broader map. Its coordinates
        -- there are valid, but they are not the detailed Fellowship island.
        target.mapId = GetMapIdByZoneId and GetMapIdByZoneId(1508) or nil
        target.forceMapId = true
        target.expectedMapName = 'Stirk'
        target.expectedZoneId = 1508
        target.preferredLocationNames = { 'Stirk Fellowship Camp' }
        return target

    elseif hubKey == 'NIGHT_MARKET' then
        -- User requested the Fargrave map for Night Market styles.
        local zone = FindZoneByExactName('Fargrave')
        return MakeZoneTarget(zone, 'Night Market - Fargrave', 'event')

    elseif hubKey == 'WITCHES' then
        return MakeNodeTarget(FindNodeByTCMTargetName('Crosswych Wayshrine'),
            "Witches Festival - Olyve's Brewery", 'event')

    elseif hubKey == 'BATTLEGROUNDS' then
        local mapId = FindStylePageCityMapId('Alinor')
        if not mapId then return nil end
        local target = MakeMapLocationTarget('Alinor',
            { "Gladiator's Quarters", 'Battlemaster Rivyn' },
            "Battlegrounds - Gladiator's Quarters, Alinor", mapId)
        target.forceMapId = true
        target.expectedMapName = 'Alinor'
        return target

    elseif hubKey == 'UNDAUNTED_WAYREST' then
        local mapId = FindStylePageCityMapId('Wayrest')
        if not mapId then return nil end
        local target = MakeMapLocationTarget('Wayrest', { 'Undaunted Enclave' },
            'Undaunted Enclave - Wayrest', mapId)
        target.forceMapId = true
        target.expectedMapName = 'Wayrest'
        return target

    elseif hubKey == 'INFINITE_ARCHIVE' then
        local apocrypha = FindZoneByExactName('Apocrypha')
        local poi = apocrypha and FindPoiByExactName('Infinite Archive', apocrypha.zoneIndex) or nil
        return MakePoiTarget(poi, 'Infinite Archive', 'activity')
    end

    -- Generic Impresario/Event Exchange destinations: keep the exact coordinates
    -- that were already working in PS5 testing.  This is still one target only.
    local alliance = GetUnitAlliance and GetUnitAlliance('player') or 0
    if hubKey == 'IMPRESARIO' or hubKey == 'JESTERS' or hubKey == 'WHITESTRAKE' then
        if alliance == ALLIANCE_ALDMERI_DOMINION then
            return MakeCoordinateTarget('Auridon', 0.6316052675, 0.2505004108,
                'Impresario / Event Exchange - Vulkhel Guard', 'event')
        elseif alliance == ALLIANCE_EBONHEART_PACT then
            return MakeCoordinateTarget('Stonefalls', 0.7968216538, 0.7895892859,
                "Impresario / Event Exchange - Davon's Watch", 'event')
        end
        return MakeCoordinateTarget('Glenumbra', 0.3396363258, 0.7399688363,
            'Impresario / Event Exchange - Daggerfall', 'event')
    end

    return nil
end

local function HasStylePageMapDefinition(family)
    if not family then return false end
    local source = GetStylePageSourceOverride(family)
    if not source then return false end
    return (source.mapType or 'NONE') ~= 'NONE'
end

local function ResolveStylePageMapTarget(family)
    if not family then return nil end

    local source = GetStylePageSourceOverride(family)
    if not source then return nil end

    local mapType = source.mapType or 'NONE'

    -- One record -> one destination. Native locations are resolved only on
    -- their specified map; dungeon/node resolution keeps its existing path.
    if mapType == 'NODE' and source.nodeName then
        -- Full TCM-style target resolution.  Some dungeon entrances are exposed
        -- as native fast-travel nodes while others are only usable as POIs on
        -- the parent zone map.  Resolve both before declaring the target absent.
        local node = FindTCMNodeFromExplicitSource(family, source)
        if node then
            return MakeNodeTarget(node, source.location or source.nodeName, 'source')
        end

        local poi = FindExactPoiFromExplicitSource(source)
        if poi then
            return MakePoiTarget(poi, source.location or source.nodeName, 'source')
        end

        return nil

    elseif mapType == 'POI' and source.poiName then
        local preferredZoneIndex = nil
        if source.zoneName then
            local zone = FindZoneByExactName(source.zoneName)
            preferredZoneIndex = zone and zone.zoneIndex or nil
        end
        return MakePoiTarget(
            FindPoiByExactName(source.poiName, preferredZoneIndex),
            source.location or source.poiName,
            'source'
        )

    elseif mapType == 'LOCATION' and source.mapName and source.locationNames then
        return MakeMapLocationTarget(source.mapName, source.locationNames,
            source.location or source.mapName, source.mapId)

    elseif mapType == 'COORD' and source.mapName and source.x and source.y then
        return MakeCoordinateTarget(
            source.mapName,
            source.x,
            source.y,
            source.location or source.mapName,
            'source'
        )

    elseif mapType == 'ZONE' and source.zoneName then
        return MakeZoneTarget(
            FindZoneByExactName(source.zoneName),
            source.location or source.zoneName,
            'zone'
        )

    elseif mapType == 'WORLD' then
        return MakeWorldTarget(source.location or 'World Map')

    elseif mapType == 'HUB' and source.hub then
        return ResolveCuratedStylePageHub(source.hub)

    elseif mapType == 'DREAD_AURELIAN' then
        -- Kept for old source records, although the user correction layer now
        -- explicitly routes Dread-Aurelian to Moongrave Fane as a NODE.
        return ResolveDreadAurelianTarget(family)

    elseif mapType == 'NONE' then
        return nil
    end

    return nil
end

local stylePageMapRequestId = 0
local function ShowStylePageFamilyOnMap(screen)
    local data = screen.styleList and screen.styleList:GetTargetData() or nil
    local family = data and data.style or nil
    local target = ResolveStylePageMapTarget(family)
    if not target then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK,
            'No exact map location is available for this Style Page yet.')
        return
    end

    if WORLD_MAP_MANAGER and not WORLD_MAP_MANAGER:IsMapChangingAllowed() then
        return
    end

    stylePageMapRequestId = stylePageMapRequestId + 1
    local requestId = stylePageMapRequestId
    local oldPinManager = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager() or nil
    if oldPinManager then
        oldPinManager:RemovePins('pings', MAP_PIN_TYPE_QUEST_PING, 'TCS_STYLE_PAGE_SOURCE')
    end

    -- World-only sources intentionally open the world map without a fake pin.
    if target.kind == 'world' then
        screen.returnToMotifsAfterMap = true
        screen.returnMotifSelectedIndex = screen.styleList:GetSelectedIndex()
        ZO_WorldMap_ShowWorldMap()
        return
    end

    -- Keep the working TCM map-index route for existing targets. City and
    -- instance maps without a map-list index use ESO's SetMapById instead.
    local mapIndex
    if not target.forceMapId then
        mapIndex = target.mapIndex or FindMapIndexForStylePageZone(target.zoneIndex)
    end
    local mapId = target.mapId
    if not mapIndex and not (mapId and mapId > 0 and WORLD_MAP_MANAGER.SetMapById) then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK,
            'The Style Page location could not be opened on the map.')
        return
    end

    screen.returnToMotifsAfterMap = true
    screen.returnMotifSelectedIndex = screen.styleList:GetSelectedIndex()

    ZO_WorldMap_ShowWorldMap()
    if mapIndex then
        WORLD_MAP_MANAGER:SetMapByIndex(mapIndex)
    else
        WORLD_MAP_MANAGER:SetMapById(mapId)
    end

    -- Broad zone sources use exactly the TCM map-opening path, but no pin is
    -- invented when the source is intentionally zone-wide.
    if target.kind == 'zone'
        and not target.nodeIndex
        and not target.poiIndex
        and not target.x then
        return
    end

    local attempts = 0
    local function PlaceStylePagePing()
        if requestId ~= stylePageMapRequestId then return end
        attempts = attempts + 1

        local correctMap = mapIndex and GetCurrentMapIndex() == mapIndex
            or (not mapIndex and GetCurrentMapId and GetCurrentMapId() == mapId)
        if not correctMap then
            if attempts < 20 then
                zo_callLater(PlaceStylePagePing, 50)
            else
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK,
                    'The Style Page location map did not become active.')
            end
            return
        end

        -- A pin is meaningful only on the specific city/instance it belongs
        -- to, even if a broader map happens to share its zone or map index.
        if target.expectedMapName and GetMapNameById
            and Normalize(GetMapNameById(GetCurrentMapId())) ~= Normalize(target.expectedMapName) then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK,
                'The exact Style Page location map is unavailable.')
            return
        end
        if target.expectedZoneId and GetCurrentMapZoneIndex and GetZoneId
            and GetZoneId(GetCurrentMapZoneIndex()) ~= target.expectedZoneId then
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK,
                'The Fellowship island map is unavailable.')
            return
        end

        local x, y = target.x, target.y

        if target.preferredLocationNames then
            x, y = GetStylePageMapLocationCoordinates(target.preferredLocationNames)
        end
        if x and y and x > 0 and y > 0 and x < 1 and y < 1 then
            -- Use a native camp marker when the island exposes one.
        elseif target.locationNames then
            x, y = GetStylePageMapLocationCoordinates(target.locationNames)
        -- Existing TCM priority: node coordinates first.
        elseif target.nodeIndex then
            local _, _, nx, ny, _, _, _, isLocatedInCurrentMap =
                GetFastTravelNodeInfo(target.nodeIndex)
            if isLocatedInCurrentMap
                and nx and ny and nx > 0 and ny > 0 and nx < 1 and ny < 1 then
                x, y = nx, ny
            end

            -- TCM fallback for nodes whose fast-travel coordinates are not
            -- exposed until the map has refreshed.
            if (not x or not y or x <= 0 or y <= 0 or x >= 1 or y >= 1)
                and target.zoneIndex and target.poiIndex and GetPOIMapInfo then
                local px, py, _, _, isShownInCurrentMap =
                    GetPOIMapInfo(target.zoneIndex, target.poiIndex)
                if isShownInCurrentMap
                    and px and py and px > 0 and py > 0 and px < 1 and py < 1 then
                    x, y = px, py
                end
            end
        elseif target.zoneIndex and target.poiIndex and GetPOIMapInfo then
            -- Read native POI coordinates only after its map is active.
            local px, py, _, _, isShownInCurrentMap =
                GetPOIMapInfo(target.zoneIndex, target.poiIndex)
            if isShownInCurrentMap
                and px and py and px > 0 and py > 0 and px < 1 and py < 1 then
                x, y = px, py
            end
        end

        if not x or not y or x <= 0 or y <= 0 or x >= 1 or y >= 1 then
            if attempts < 20 then
                zo_callLater(PlaceStylePagePing, 50)
            else
                ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK,
                    'The Style Page location has no usable map coordinates.')
            end
            return
        end

        local pinManager = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager() or nil
        local panAndZoom = ZO_WorldMap_GetPanAndZoom and ZO_WorldMap_GetPanAndZoom() or nil
        if not pinManager or not panAndZoom then
            return
        end

        pinManager:RemovePins('pings', MAP_PIN_TYPE_QUEST_PING, 'TCS_STYLE_PAGE_SOURCE')
        local pin = pinManager:CreatePin(
            MAP_PIN_TYPE_QUEST_PING,
            'TCS_STYLE_PAGE_SOURCE',
            x,
            y
        )
        if not pin then return end

        panAndZoom:JumpToPin(pin)
    end

    zo_callLater(PlaceStylePagePing, 150)
end

local function InstallStylePageMapKeybind(screen)
    if screen._tcsStylePageMapKeybindInstalled then return end
    local descriptors = screen.keybindStripDescriptor
    if type(descriptors) ~= 'table' then return end
    for _, descriptor in ipairs(descriptors) do
        if type(descriptor) == 'table' and descriptor.keybind == 'UI_SHORTCUT_SECONDARY' then
            local originalVisible = descriptor.visible
            local originalCallback = descriptor.callback
            descriptor.visible = function()
                if screen.activeModuleId == 'stylePages' and screen.mode == 'styles' then
                    local data = screen.styleList and screen.styleList:GetTargetData() or nil
                    return data and data.style and HasStylePageMapDefinition(data.style)
                end
                return originalVisible and originalVisible() or false
            end
            descriptor.callback = function()
                if screen.activeModuleId == 'stylePages' and screen.mode == 'styles' then
                    return ShowStylePageFamilyOnMap(screen)
                end
                if originalCallback then return originalCallback() end
            end
            screen._tcsStylePageMapKeybindInstalled = true
            break
        end
    end
end


local function ApplyStylePageDetailLayout(screen)
    if not screen then return end
    -- Keep the divider close to the original Motifs position so the right panel
    -- does not leave a large empty area at the bottom.  Readability comes from
    -- the smaller Style Page font, not from moving the whole block upward.
    if screen.detailBottomLine then
        local parent = screen.rightContent or screen.detailBottomLine:GetParent()
        screen.detailBottomLine:ClearAnchors()
        screen.detailBottomLine:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, -315)
        screen.detailBottomLine:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, -315)
    end
    if screen.detailSource then
        screen.detailSource:SetFont('ZoFontGamepad18')
        screen.detailSource:SetHeight(132)
        screen.detailSource:SetMaxLineCount(7)
    end
    if screen.detailAchievement then
        screen.detailAchievement:SetFont('ZoFontGamepad18')
        screen.detailAchievement:SetHeight(62)
        screen.detailAchievement:SetMaxLineCount(4)
    end
    if screen.detailControl then
        local parent = screen.detailControl:GetParent()
        screen.detailControl:ClearAnchors()
        screen.detailControl:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 53)
        screen.detailControl:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, -335)
    end
end

local function RestoreDefaultDetailLayout(screen)
    if not screen then return end
    local parent = screen.detailControl and screen.detailControl:GetParent() or nil
    if screen.detailBottomLine and parent then
        screen.detailBottomLine:ClearAnchors()
        screen.detailBottomLine:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 0, -285)
        screen.detailBottomLine:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, -285)
    end
    if screen.detailSource then
        screen.detailSource:SetFont('ZoFontGamepad22')
        screen.detailSource:SetHeight(88)
        screen.detailSource:SetMaxLineCount(5)
    end
    if screen.detailAchievement then
        screen.detailAchievement:SetFont('ZoFontGamepad20')
        screen.detailAchievement:SetHeight(58)
        screen.detailAchievement:SetMaxLineCount(3)
    end
    if screen.detailControl and parent then
        screen.detailControl:ClearAnchors()
        screen.detailControl:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 53)
        screen.detailControl:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, -315)
    end
end

local PopulateStylePageFamilyList

local function InstallStylePageCollectorKeybind(screen)
    if screen._tcsCollectorKeybindInstalled then return end
    local group, strip = screen.keybindStripDescriptor, KEYBIND_STRIP
    if type(group) ~= 'table' then return end
    screen._tcsCollectorKeybindInstalled = true
    local registered = strip and strip.HasKeybindButtonGroup and strip:HasKeybindButtonGroup(group)
    if registered then strip:RemoveKeybindButtonGroup(group) end
    table.insert(group, {
        name = function() return screen._tcsShowAll and 'Show Uncollected' or 'Show All' end,
        keybind = 'UI_SHORTCUT_LEFT_STICK',
        alignment = KEYBIND_STRIP_ALIGN_RIGHT,
        visible = function()
            return screen.activeModuleId == 'stylePages'
                and (screen.mode == 'styles' or screen.mode == 'details')
        end,
        callback = function()
            if screen.activeModuleId ~= 'stylePages'
                or (screen.mode ~= 'styles' and screen.mode ~= 'details') then return end
            local target = screen.styleList:GetTargetData()
            local selectedFamily = target and target.style
            local detail = screen.detailList:GetTargetData()
            local selectedPage = detail and detail.page
            local wasDetails = screen.mode == 'details'
            screen._tcsShowAll = not screen._tcsShowAll
            -- Refresh ownership from ESO, keeping the complete native catalogue
            -- separate from the visible families so toggles never lose data.
            screen._tcsAllStylePageFamilies = BuildStylePageFamiliesFromNativeCollections()
            PopulateStylePageFamilyList(screen)
            for index, family in ipairs(screen.styles or {}) do
                if family == selectedFamily then
                    screen.styleList:SetSelectedIndex(index)
                    break
                end
            end
            screen:ShowStyle(screen.styleList:GetTargetData())
            local pageIndex = 0
            target = screen.styleList:GetTargetData()
            for _, page in ipairs(target and target.style.pages or {}) do
                if screen._tcsShowAll or not page.unlocked then
                    pageIndex = pageIndex + 1
                    if page == selectedPage then
                        screen.detailList:SetSelectedIndex(pageIndex)
                        break
                    end
                end
            end
            if wasDetails and not target then screen:ReturnToStyles() end
            if screen.motifSearchRestoreIndex then
                screen.motifSearchRestoreIndex = screen.styleList:GetSelectedIndex()
            end
            screen:RefreshKeybinds()
        end,
    })
    if registered then strip:AddKeybindButtonGroup(group) end
end

local function InstallScreenHooks(screen)
    InstallStylePageCollectorKeybind(screen)
    if screen._tcsStylePagesHooksInstalled then return end
    screen._tcsStylePagesHooksInstalled = true
    InstallStylePageMapKeybind(screen)

    screen._tcsOriginalShowStyle = screen.ShowStyle
    screen.ShowStyle = function(self, data)
        if self.activeModuleId ~= 'stylePages' then
            return self:_TCSCallOriginalShowStyle(data)
        end

        if not (data and data.style) then
            self.detailList:Clear()
            self.detailList:Commit()
            self.detailControl:SetHidden(true)
            self.detailHeading:SetHidden(false)
            self.detailHeading:SetText(self._tcsShowAll and 'No Style Pages found' or 'No uncollected Style Pages')
            self.detailAcquisition:SetHidden(false)
            self.detailAcquisition:SetText('Style Pages')
            for _, name in ipairs({ 'detailWhereTitle', 'detailLocation', 'detailSource', 'detailAchievement' }) do
                self[name]:SetText('')
                self[name]:SetHidden(true)
            end
            self.detailIcon:SetHidden(true)
            return
        end
        local family = data.style
        ApplyStylePageDetailLayout(self)

        self.detailControl:SetHidden(false)
        self.detailHeading:SetHidden(false)
        self.detailAcquisition:SetHidden(false)
        self.detailWhereTitle:SetHidden(false)
        self.detailLocation:SetHidden(false)
        self.detailSource:SetHidden(false)
        self.detailAchievement:SetHidden(false)
        self.detailIcon:SetHidden(true)

        self.detailList:Clear()
        for _, page in ipairs(family.pages or {}) do
            if self._tcsShowAll or not page.unlocked then
                local status = page.unlocked and (GREEN .. 'Collected|r') or (RED .. 'Not collected|r')
                local pageTitle = page.displayName or page.name or 'Style Page'
                local entry = ZO_GamepadEntryData:New(string.format('%s  —  %s', pageTitle, status))
                entry.page = page
                entry.collectibleId = page.collectibleId
                entry.isKnown = page.unlocked
                self.detailList:AddEntry('ZO_QuestJournal_Gamepad_MenuEntryTemplate', entry)
            end
        end
        self.detailList:Commit()

        local heading = string.format('%s%s (%d/%d)|r', GOLD, family.name or 'Style Pages', family.known or 0, family.total or 0)
        if family.icon and family.icon ~= '' then
            heading = string.format('|t28:28:%s|t %s', family.icon, heading)
        end
        self.detailHeading:SetText(heading)
        self.detailAcquisition:SetText('Style Pages')
        self.detailWhereTitle:SetText('Where to obtain:')

        local sourceText = GetFamilyAcquisitionText(family)
        local mapTarget = ResolveStylePageMapTarget(family)
        local sourceOverride = GetStylePageSourceOverride(family)
        local locationText = (sourceOverride and sourceOverride.location)
            or (mapTarget and (mapTarget.label or mapTarget.name or ''))
            or ''
        self.detailLocation:SetText(locationText ~= '' and (GOLD .. locationText .. '|r') or '')
        self.detailSource:SetText(sourceText)

        local achievementText = GetFamilyAchievementText(family)
        if achievementText ~= '' then
            self.detailAchievement:SetText(GOLD .. 'Achievement:|r ' .. achievementText)
        else
            self.detailAchievement:SetText('')
        end
    end

    screen._TCSCallOriginalShowStyle = function(self, data)
        return self._tcsOriginalShowStyle(self, data)
    end

    -- Restore the Motifs search label when moving back to that module.
    if screen.ShowMotifCategory and not screen._tcsOriginalShowMotifCategory then
        screen._tcsOriginalShowMotifCategory = screen.ShowMotifCategory
        screen.ShowMotifCategory = function(self, data)
            RestoreDefaultDetailLayout(self)
            if self.motifSearchFocus and self.motifSearchFocus.GetEditBox then
                self.motifSearchFocus:GetEditBox():SetDefaultText('Search Motifs')
            end
            return self._tcsOriginalShowMotifCategory(self, data)
        end
    end
end

PopulateStylePageFamilyList = function(screen)
    screen.styles = {}
    for _, family in ipairs(screen._tcsAllStylePageFamilies or {}) do
        if screen._tcsShowAll or (family.known or 0) < (family.total or 0) then
            screen.styles[#screen.styles + 1] = family
        end
    end
    screen.styleList:Clear()
    for _, family in ipairs(screen.styles or {}) do
        local title = family.name or 'Unknown Style Page Set'
        if family.icon and family.icon ~= '' then
            title = string.format('|t26:26:%s|t  %s', family.icon, title)
        end
        local entry = ZO_GamepadEntryData:New(title)
        entry.style = family
        screen.styleList:AddEntry('ZO_QuestJournal_Gamepad_MenuEntryTemplate', entry)
    end
    screen.styleList:Commit()
    screen:RefreshKeybinds()
end

local function ShowStylePagesCategory(screen)
    InstallScreenHooks(screen)
    screen:SetMotifContentVisible(true)
    -- Read ESO's already-built native Outfit Style collection data directly.
    -- There is no background discovery pass: the family list is complete before
    -- this category is drawn, so players never see an empty screen slowly fill.
    screen._tcsAllStylePageFamilies = BuildStylePageFamiliesFromNativeCollections()
    PopulateStylePageFamilyList(screen)

    if screen.motifSearchFocus and screen.motifSearchFocus.GetEditBox then
        screen.motifSearchFocus:GetEditBox():SetDefaultText('Search Style Pages')
    end

    screen.middle:SetHidden(false)
    screen.right:SetHidden(false)
    screen.detailList:Clear()
    screen.detailList:Commit()
    screen.detailControl:SetHidden(true)
    screen.detailHeading:SetHidden(true)
    screen.detailAcquisition:SetHidden(true)
    screen.detailWhereTitle:SetHidden(true)
    screen.detailLocation:SetHidden(true)
    screen.detailSource:SetHidden(true)
    screen.detailAchievement:SetHidden(true)
    screen.detailIcon:SetTexture(STYLE_PAGES_ICON)
    screen.detailIcon:SetHidden(false)
end

local function OpenStylePages(screen)
    InstallScreenHooks(screen)
    screen.activeModuleId = 'stylePages'
    screen.mode = 'styles'
    screen:SetCurrentList(screen.styleList)
    screen.middle:SetHidden(false)
    screen.right:SetHidden(false)
    screen:ShowStyle(screen.styleList:GetTargetData())
    screen:RefreshKeybinds()
end

TC:RegisterArchiveModule('stylePages', {
    displayName = 'Style Pages',
    addonName = 'Tamriel Collections - Archive Style Pages',
    assetRoot = 'TamrielCollectionsStylePages',
    screenControl = 'TCSQuestJournalTL',
    version = 1101,
    icon = STYLE_PAGES_ICON,
    supportsSearch = true,
    onCategoryFocus = ShowStylePagesCategory,
    open = OpenStylePages,
    activateSearch = function(screen)
        screen:ActivateMotifSearch()
    end,
})

-- Shared layout: included in every standalone Archive module; initialized once.
do
local TC = TamrielCollections
if not TC.archiveLayout or TC.archiveLayout.version < 1101 then
-- Shared Archives layout derived from the approved Motifs v1.1.1: a separate scene-owned background plane keeps the
-- native masked menus, search controls, emblem and panel rails unobscured.
-- Geometry is measured
-- against GuiRoot because ESO narrows the native scene owner to quadrant 1.
local Pilot = { version = 1101, modules = {} }
TC.archiveLayout = Pilot
local function Current(screen)
    local id
    if screen.mode == 'categories' then
        local data = screen.categoryList and screen.categoryList:GetTargetData()
        id = data and data.categoryKey
    elseif screen.mode == 'styles' or screen.mode == 'details' or screen.mode == 'starter' then
        id = screen.activeModuleId
    end
    return id and Pilot.modules[id]
end
local function IsArchive(screen) return Current(screen) ~= nil end
local function Capture(control)
    local saved = { anchors = {}, width = control:GetWidth(), height = control:GetHeight(), hidden = control:IsHidden(), parent = control:GetParent() }
    for index = 0, control:GetNumAnchors() - 1 do
        local valid, point, relative, relativePoint, x, y, constrains = control:GetAnchor(index)
        if valid then saved.anchors[#saved.anchors + 1] = { point, relative, relativePoint, x, y, constrains } end
    end
    if control.GetAutoRectClipChildren then saved.clip = control:GetAutoRectClipChildren() end
    if control.GetDrawLayer then saved.layer = control:GetDrawLayer() end
    if control.GetDrawLevel then saved.level = control:GetDrawLevel() end
    if control.GetFont then saved.font = control:GetFont() end
    return saved
end
local function RestoreControl(control, saved)
    if saved.parent and control:GetParent() ~= saved.parent then control:SetParent(saved.parent) end
    control:ClearAnchors()
    control:SetDimensions(saved.width, saved.height)
    for _, anchor in ipairs(saved.anchors) do
        control:SetAnchor(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5], anchor[6])
    end
    control:SetHidden(saved.hidden)
    if saved.clip ~= nil and control.SetAutoRectClipChildren then control:SetAutoRectClipChildren(saved.clip) end
    if saved.layer ~= nil then control:SetDrawLayer(saved.layer) end
    if saved.level ~= nil then control:SetDrawLevel(saved.level) end
    if saved.font then control:SetFont(saved.font) end
end
local moved = { 'collectionsHeaderLine', 'collectionsLogoBottomLine', 'collectionsMenuBottomLine',
    'collectionsHeaderLogo', 'detailTopLine', 'detailBottomLine', 'motifSearchLine', 'motifSearchBackdrop',
    'motifSearchControl', 'styleListContainer', 'detailControl', 'detailHeading', 'detailAcquisition',
    'detailWhereTitle', 'detailLocation', 'detailSource', 'detailAchievement', 'detailIcon',
    'moduleUnavailableTitle', 'moduleUnavailableBody' }
local hiddenLines = { 'collectionsHeaderLine', 'collectionsLogoBottomLine', 'collectionsMenuBottomLine',
    'detailTopLine', 'detailBottomLine', 'motifSearchLine', 'motifSearchBackdrop' }
local function Bounds(screen)
    local owner, root = screen.control, GuiRoot or screen.control
    if not owner or not root or not root.GetLeft or not screen.middle or not screen.right then return end
    local left, top, width, height = root:GetLeft(), root:GetTop(), root:GetWidth(), root:GetHeight()
    if not (left and top and width and height and width > 600 and height > 400) then return end
    local middle, right = screen.middle:GetLeft() - left, screen.right:GetLeft() - left
    if not (middle > 100 and right > middle + 100 and right < width - 100) then return end
    local alley = ZO_GAMEPAD_ALLEY_WIDTH or 10
    local panelLeft = math.max(0, middle - screen.right:GetWidth() - alley)
    local panelRight = math.min(width, screen.right.GetRight and screen.right:GetRight() - left or width)
    local middleEnd = math.min(right - alley, screen.middle.GetRight and screen.middle:GetRight() - left or right - alley)
    local texture = ZO_KeybindStripGamepadBackgroundTexture
    local keybindHeight = texture and texture.GetHeight and texture:GetHeight() or ZO_GAMEPAD_KEYBIND_STRIP_BACKGROUND_HEIGHT or 128
    local footer = texture and texture.GetTop and texture:GetTop() - top or height - keybindHeight
    if not footer or footer <= height / 2 or footer > height then footer = height - keybindHeight end
    footer = footer - 16
    -- All columns share a title baseline and two narrow gold rules. Keep the
    -- left menu and chapter-list divider aligned, leaving the middle list open.
    local titleTop = math.max(24, ZO_GAMEPAD_SAFE_ZONE_INSET_Y or 54) + 8
    local first, second = titleTop + 56, titleTop + 216
    local listTop, lower = second + 18, footer - 234
    if lower - listTop < 314 then return end
    return { root = root, owner = owner, width = width, height = height,
        left = panelLeft, leftEnd = middle - alley, middle = middle, middleEnd = middleEnd,
        right = right, edge = panelRight, titleTop = titleTop, first = first,
        second = second, listTop = listTop, lower = lower, footer = footer }
end
local function Place(control, b, left, right, top, height)
    if not control then return end
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, b.root, TOPLEFT, left, top)
    control:SetAnchor(TOPRIGHT, b.root, TOPLEFT, right, top)
    control:SetHeight(height)
end
local function Foreground(control)
    if not control then return end
    control:SetDrawLayer(DL_CONTROLS)
    control:SetDrawLevel(90)
end
local function NewControl(state, name, kind, level)
    local isBackground = name == 'Backdrop' or name == 'FooterFill' or name == 'HeaderShade'
    local parent = isBackground and state.backgroundRoot or state.bounds.owner
    local control = WINDOW_MANAGER:CreateControl('TCArchiveLayout' .. name, parent, kind)
    if DT_LOW then control:SetDrawTier(DT_LOW) end
    control:SetDrawLayer(isBackground and DL_BACKGROUND or DL_CONTROLS)
    control:SetDrawLevel(isBackground and 0 or level)
    control:SetHidden(true)
    return control
end
local function MakeControls(state, screen)
    if state.controls then return end
    local c = {}; state.controls = c
    -- Scroll masks and top-level windows compose their descendants as a group.
    -- Raising a label cannot place it above an opaque sibling in another
    -- composed layer. Keep the paint in a distinct, lower background window.
    local background = WINDOW_MANAGER:CreateTopLevelWindow('TCArchiveBackgroundWindow')
    background:SetHidden(true)
    background:SetMouseEnabled(false)
    background:SetDrawTier(DT_LOW)
    background:SetDrawLayer(DL_BACKGROUND)
    background:SetDrawLevel(0)
    state.backgroundRoot = background
    state.backgroundFragment = ZO_SimpleSceneFragment:New(background)
    state.backgroundFragment:SetConditional(function() return state.active == true and IsArchive(screen) end)
    screen.scene:AddFragment(state.backgroundFragment)
    -- A near-solid tint retains a faint glimpse of the world beneath the
    -- native gamepad panels, while keeping collection text readable.
    c.Backdrop = NewControl(state, 'Backdrop', CT_TEXTURE, 10)
    c.Backdrop:SetColor(32 / 255, 37 / 255, 38 / 255, 0.72)
    c.FooterFill = NewControl(state, 'FooterFill', CT_TEXTURE, 11)
    c.FooterFill:SetColor(36 / 255, 40 / 255, 40 / 255, 1)
    c.FooterRule = NewControl(state, 'FooterRule', CT_TEXTURE, 20)
    c.FooterRule:SetColor(145 / 255, 137 / 255, 112 / 255, 1)
    c.HeaderShade = NewControl(state, 'HeaderShade', CT_TEXTURE, 15)
    c.HeaderShade:SetColor(0.015, 0.02, 0.02, 0.24)
    for _, name in ipairs({ 'TitleRule', 'HeaderRule', 'MenuRule', 'SourceRule' }) do
        local line = NewControl(state, name, CT_TEXTURE, 20)
        -- The native divider fades toward its ends. A solid two-unit rule
        -- spans the exact panel bounds without fading or stretching an image.
        line:SetColor(224 / 255, 191 / 255, 124 / 255, 1)
        c[name] = line
    end
    for _, name in ipairs({ 'ArchivesTitle', 'ModuleTitle', 'DetailsTitle', 'StarterHint' }) do
        local label = NewControl(state, name, CT_LABEL, 90)
        label:SetFont(name == 'StarterHint' and 'ZoFontGamepad25' or 'ZoFontGamepadBold34')
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if name == 'StarterHint' then label:SetColor(0.72, 0.72, 0.68, 1)
        else label:SetColor(244 / 255, 225 / 255, 182 / 255, 1) end
        c[name] = label
    end
    c.ModuleEmblem = NewControl(state, 'ModuleEmblem', CT_TEXTURE, 90)
    c.ModuleEmblem:SetColor(244 / 255, 225 / 255, 182 / 255, 0.45)
    c.ContextHint = NewControl(state, 'ContextHint', CT_LABEL, 90)
    c.ContextHint:SetFont('ZoFontGamepad25')
    c.ContextHint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c.ContextHint:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    c.ContextHint:SetColor(0.72, 0.72, 0.68, 1)
    c.ContextHint:SetText('Collection overview')
    c.ArchivesTitle:SetText('TAMRIEL ARCHIVES')
    c.ModuleTitle:SetText('MOTIFS')
    c.DetailsTitle:SetText('DETAILS')
    c.StarterHint:SetText('Choose a motif to view its chapters,\ncollection progress and sources.')
end
local function HideNative(screen)
    for _, name in ipairs(hiddenLines) do if screen[name] then screen[name]:SetHidden(true) end end
end
function Pilot.Restore(screen)
    local state = screen._tcArchiveLayout
    if not state then return end
    state.generation = (state.generation or 0) + 1
    state.pending, state.attempts = nil, 0
    local wasActive = state.active
    state.active = false
    if state.backgroundFragment then state.backgroundFragment:Refresh() end
    if not wasActive then return end
    for list, offset in pairs(state.listOffsets or {}) do
        list:SetFixedCenterOffset(offset)
    end
    state.listOffsets = nil
    for control, saved in pairs(state.saved) do RestoreControl(control, saved) end
    for _, control in pairs(state.controls or {}) do control:SetHidden(true) end
    if state.ownerLayer ~= nil then screen.control:SetDrawLayer(state.ownerLayer) end
    if ZO_GamepadGenericHeader_Refresh and screen.header then
        ZO_GamepadGenericHeader_Refresh(screen.header, screen.headerData or { titleText = 'TAMRIEL ARCHIVES' })
    end
    state.saved = nil
end
function Pilot.Apply(screen)
    local config = Current(screen)
    if not config or screen._tcArchiveLayoutHidden then return false end
    -- Motifs v1.1.1 owns its approved layout independently. Restore it before
    -- capturing native controls for another module, regardless of load order.
    local motifsState = screen._tcmLayoutPilot
    if motifsState and not motifsState.active and motifsState.saved then
        -- Its list-offset restoration fires keybind callbacks before it has
        -- restored the original parents. The enclosing category change will
        -- apply this layout once that restoration has fully completed.
        return false
    end
    if TC.motifLayoutPreview then TC.motifLayoutPreview.Restore(screen) end
    if screen._tcArchiveLayout and screen._tcArchiveLayout.active
        and screen._tcArchiveLayout.moduleId ~= config.id then Pilot.Restore(screen) end
    local state = screen._tcArchiveLayout
    if not state then state = {}; screen._tcArchiveLayout = state end
    local b = state.active and state.bounds or Bounds(screen)
    if not b then
        if zo_callLater and not state.pending and (state.attempts or 0) < 3 then
            state.pending, state.attempts = true, (state.attempts or 0) + 1
            local generation = state.generation or 0
            zo_callLater(function()
                if (state.generation or 0) ~= generation then return end
                state.pending = nil
                if IsArchive(screen) then Pilot.Apply(screen) end
            end, 33)
        end
        return false
    end
    if not state.active then
        state.bounds, state.saved, state.attempts = b, {}, 0
        state.ownerLayer = screen.control:GetDrawLayer()
        for _, name in ipairs(moved) do
            local control = screen[name]
            if control and control.GetNumAnchors then state.saved[control] = Capture(control) end
        end
        for _, row in ipairs(screen.fixedCategoryRows or {}) do state.saved[row] = Capture(row) end
        MakeControls(state, screen)
        state.active, state.moduleId = true, config.id
    end
    -- Explicitly separate the scene's content plane from its background plane.
    screen.control:SetDrawLayer(DL_CONTROLS)
    local c, starter = state.controls, screen.mode == 'categories' or screen.mode == 'starter'
    c.ModuleTitle:SetText(string.upper(config.name))
    c.StarterHint:SetText(config.hint)
    if not starter then screen:SetMotifContentVisible(true) end
    Place(state.backgroundRoot, b, 0, b.width, 0, b.height)
    Place(c.Backdrop, b, 0, b.width, 0, b.height)
    local keybindTop = b.footer + 16
    Place(c.FooterFill, b, 0, b.width, keybindTop, b.height - keybindTop)
    Place(c.FooterRule, b, 0, b.width, keybindTop, 2)
    Place(c.HeaderShade, b, b.left, b.edge, b.titleTop - 20, b.second - b.titleTop + 20)
    Place(c.TitleRule, b, b.left, b.edge, b.first, 2)
    Place(c.HeaderRule, b, b.left, b.edge, b.second, 2)
    Place(c.MenuRule, b, b.left, b.leftEnd, b.lower, 2)
    Place(c.SourceRule, b, b.right, b.edge, b.lower, 2)
    Place(c.ArchivesTitle, b, b.left + 12, b.leftEnd - 12, b.titleTop, 48)
    Place(c.ModuleTitle, b, b.middle + 12, b.middleEnd - 12, b.titleTop, 48)
    Place(c.DetailsTitle, b, b.right + 12, b.edge - 12, b.titleTop, 48)
    local category = TC.GetArchiveCategory and TC:GetArchiveCategory(config.id)
    local emblem = category and screen:GetCategoryIcon(category)
    if emblem then c.ModuleEmblem:SetTexture(emblem) end
    local emblemSize = math.min(128, b.footer - b.lower - 40)
    Place(c.ModuleEmblem, b, (b.left + b.leftEnd - emblemSize) / 2,
        (b.left + b.leftEnd + emblemSize) / 2, (b.lower + b.footer - emblemSize) / 2, emblemSize)
    Place(c.StarterHint, b, b.right + 28, b.edge - 28, (b.listTop + b.lower) / 2 - 48, 96)
    for _, control in pairs(c) do control:SetHidden(false) end
    c.StarterHint:SetHidden(not starter)
    c.ModuleEmblem:SetHidden(not emblem)
    c.ContextHint:SetHidden(config.search)
    if ZO_GamepadGenericHeader_Refresh and screen.header then
        ZO_GamepadGenericHeader_Refresh(screen.header, { titleText = '' })
    end
    local center = (b.first + b.second) / 2
    Place(c.ContextHint, b, b.middle + 32, b.middleEnd - 32, center - 24, 48)
    if screen.collectionsHeaderLogo then
        -- The native header is a separately animated fragment. Its hidden
        -- state and scroll mask must not hide the fixed Archives artwork.
        screen.collectionsHeaderLogo:SetParent(b.owner)
        screen.collectionsHeaderLogo:SetHidden(false)
        screen.collectionsHeaderLogo:ClearAnchors()
        screen.collectionsHeaderLogo:SetDimensions(100, 100)
        screen.collectionsHeaderLogo:SetAnchor(CENTER, b.root, TOPLEFT, (b.left + b.leftEnd) / 2, center)
        Foreground(screen.collectionsHeaderLogo)
    end
    if screen.detailIcon then
        screen.detailIcon:ClearAnchors()
        screen.detailIcon:SetDimensions(100, 100)
        screen.detailIcon:SetAnchor(CENTER, b.root, TOPLEFT, (b.right + b.edge) / 2, center)
        Foreground(screen.detailIcon)
    end
    if screen.motifSearchControl then
        screen.motifSearchControl:ClearAnchors()
        screen.motifSearchControl:SetAnchor(CENTER, b.root, TOPLEFT, (b.middle + b.middleEnd) / 2, center)
        -- The same native search affordance is visible on the starter. Its
        -- existing Search shortcut opens the selected module and then focuses the edit box.
        screen.motifSearchControl:SetHidden(not config.search)
        Foreground(screen.motifSearchControl)
    end
    Place(screen.styleListContainer, b, b.middle + 8, b.middleEnd - 8, b.listTop, b.footer - b.listTop)
    Place(screen.detailControl, b, b.right + 8, b.edge - 8, b.listTop, b.lower - b.listTop - 12)
    for _, name in ipairs({ 'styleListContainer', 'detailControl' }) do
        if screen[name] and screen[name].SetAutoRectClipChildren then screen[name]:SetAutoRectClipChildren(true) end
    end
    -- Native vertical lists anchor the selected row at their center. Bring
    -- that anchor to the top of the viewport without moving the panel itself.
    state.listOffsets = state.listOffsets or {}
    for _, list in ipairs({ screen.styleList, screen.detailList }) do
        if list.SetFixedCenterOffset and list.GetControl then
            if state.listOffsets[list] == nil then
                state.listOffsets[list] = list.fixedCenterOffset or 0
            end
            list:SetFixedCenterOffset(8 - list:GetControl():GetHeight() / 2)
        end
    end
    Place(screen.detailHeading, b, b.right + 24, b.edge - 24, b.first + 20, 76)
    if screen.detailHeading then screen.detailHeading:SetFont('ZoFontGamepadBold27') end
    Place(screen.detailAcquisition, b, b.right + 24, b.edge - 24, b.first + 110, 30)
    Foreground(screen.detailHeading)
    Foreground(screen.detailAcquisition)
    Place(screen.detailWhereTitle, b, b.right + 24, b.edge - 24, b.lower + 10, 28)
    Place(screen.detailLocation, b, b.right + 24, b.edge - 24, b.lower + 42, 30)
    Place(screen.detailSource, b, b.right + 24, b.edge - 24, b.lower + 76, 88)
    Place(screen.detailAchievement, b, b.right + 24, b.edge - 24, b.lower + 170, 58)
    -- Retain foreground placement without changing native data, row templates,
    -- scrolling, search controls or controller bindings.
    for _, name in ipairs({ 'styleListContainer', 'detailControl', 'detailWhereTitle',
        'detailLocation', 'detailSource', 'detailAchievement',
        'moduleUnavailableTitle', 'moduleUnavailableBody' }) do Foreground(screen[name]) end
    local rows = screen.fixedCategoryRows or {}
    local spacing = #rows > 1 and math.min(80, (b.lower - b.listTop - 90) / (#rows - 1)) or 0
    for index, row in ipairs(rows) do
        -- Keep only the visuals outside the animated header. The invisible
        -- native category list retains all controller input and selection.
        row:SetParent(b.owner)
        row:SetHidden(false)
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, b.root, TOPLEFT, b.left + 44, b.listTop + 14 + (index - 1) * spacing)
        Foreground(row)
    end
    if starter then
        -- A single module heading above the search field identifies this page;
        -- preserve the native press-X prompt without repeating the heading.
        if screen.moduleUnavailableTitle then screen.moduleUnavailableTitle:SetHidden(true) end
        Place(screen.moduleUnavailableBody, b, b.middle + 32, b.middleEnd - 32,
            (b.listTop + b.lower) / 2 - 76, 152)
    end
    HideNative(screen)
    state.backgroundFragment:Refresh()
    return true
end

-- List refreshes can call selection/keybind callbacks synchronously. Keep a
-- single layout pass active and restore the guard even if native code errors.
local rawApply, rawRestore = Pilot.Apply, Pilot.Restore
function Pilot.Apply(screen)
    if screen._tcArchiveLayoutBusy or screen._tcArchiveLayoutPaused then return false end
    screen._tcArchiveLayoutBusy = true
    local ok, result = pcall(rawApply, screen)
    screen._tcArchiveLayoutBusy = nil
    if not ok then error(result) end
    return result
end
function Pilot.Restore(screen)
    local busy = screen._tcArchiveLayoutBusy
    screen._tcArchiveLayoutBusy = true
    local ok, result = pcall(rawRestore, screen)
    screen._tcArchiveLayoutBusy = busy
    if not ok then error(result) end
    return result
end
local function Sync(screen)
    if screen._tcArchiveLayoutBusy or screen._tcArchiveLayoutPaused or screen._tcArchiveLayoutHidden then return end
    if Current(screen) then Pilot.Apply(screen) else Pilot.Restore(screen) end
end
function Pilot.WatchLifecycle(screen)
    -- Modules install their reader/loading hooks on first open. Keep this
    -- observer outside the latest hooks: a reader's resume branch can return
    -- without calling an earlier OnShowing implementation.
    if screen.OnShowing ~= screen._tcArchiveLayoutOnShowing then
        local showing = screen.OnShowing
        local wrapper = function(self, ...)
            self._tcArchiveLayoutHidden = nil
            local result
            if showing then result = showing(self, ...) end
            Sync(self)
            return result
        end
        screen.OnShowing, screen._tcArchiveLayoutOnShowing = wrapper, wrapper
    end
    if screen.OnHiding ~= screen._tcArchiveLayoutOnHiding then
        local hiding = screen.OnHiding
        local wrapper = function(self, ...)
            self._tcArchiveLayoutHidden = true
            Pilot.Restore(self)
            if hiding then return hiding(self, ...) end
        end
        screen.OnHiding, screen._tcArchiveLayoutOnHiding = wrapper, wrapper
    end
end
function Pilot.BeforeShowing(screen)
    screen._tcArchiveLayoutHidden = nil
    Pilot.Install(screen)
    -- A standalone module must open on an installed category, rather than
    -- the disabled Motifs row inherited from the native shared menu.
    local selected = screen.categoryList and screen.categoryList:GetTargetData()
    if selected and TC:IsArchiveModuleInstalled(selected.categoryKey) then return end
    for index, category in ipairs(TC.archiveCategories or {}) do
        if TC:IsArchiveModuleInstalled(category.key) then
            screen.categoryList:SetSelectedIndex(index)
            break
        end
    end
end
function Pilot.Install(screen)
    if screen._tcArchiveLayoutInstalled then Pilot.WatchLifecycle(screen); return end
    screen._tcArchiveLayoutInstalled = true
    local category = screen.ShowCategory
    screen.ShowCategory = function(self, data)
        local state = self._tcArchiveLayout
        if state and state.active and (not data or data.categoryKey ~= state.moduleId) then Pilot.Restore(self) end
        local result = category(self, data)
        Sync(self)
        return result
    end
    local show = screen.ShowStyle
    screen.ShowStyle = function(self, data)
        if not Current(self) then Pilot.Restore(self) end
        local result = show(self, data)
        Sync(self)
        return result
    end
    local refresh = screen.RefreshKeybinds
    screen.RefreshKeybinds = function(self, ...)
        local result = refresh(self, ...)
        Sync(self)
        return result
    end
    Pilot.WatchLifecycle(screen)
end
function Pilot.Prompt(screen, data, config)
    screen:ShowUnavailableCategory(data, TC:GetArchiveCategory(config.id))
    if screen.moduleUnavailableTitle then screen.moduleUnavailableTitle:SetHidden(true) end
    if screen.moduleUnavailableBody then screen.moduleUnavailableBody:SetText(config.intro) end
    if screen.motifSearchFocus and screen.motifSearchFocus.GetEditBox then
        screen.motifSearchFocus:GetEditBox():SetDefaultText('Search ' .. config.name)
    end
    Pilot.Apply(screen)
end
function Pilot.Register(id, config)
    config.id = id
    local module = TC:GetArchiveModule(id)
    if not module then return end
    config.search = module.supportsSearch == true
    Pilot.modules[id] = config
    if module._tcArchiveLayoutWrapped then return end
    module._tcArchiveLayoutWrapped = true
    local focus, open = module.onCategoryFocus, module.open
    module.onCategoryFocus = function(screen, data)
        Pilot.Install(screen)
        Pilot.Prompt(screen, data, config)
    end
    module.open = function(screen)
        Pilot.Install(screen)
        -- Style Pages previously populated on focus. Defer that exact native
        -- catalogue routine to X; the other modules prepare themselves on open.
        local paused = screen._tcArchiveLayoutPaused
        screen._tcArchiveLayoutPaused = true
        local ok, result = pcall(function()
            if config.prepareOnOpen and focus then focus(screen) end
            if open then return open(screen) end
        end)
        screen._tcArchiveLayoutPaused = paused
        if not ok then error(result) end
        Pilot.WatchLifecycle(screen)
        Pilot.Apply(screen)
        return result
    end
end

end
TC.archiveLayout.Register("stylePages", { name = "Style Pages", intro = "Browse outfit styles and track your collection.\nView individual pages and their sources.\n\nPress X to browse Style Pages.", hint = "Choose a style family to view its pages,\ncollection progress and sources.", prepareOnOpen = true })
end
