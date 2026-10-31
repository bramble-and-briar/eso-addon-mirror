-- Tamriel Collections - Archive Style Pages v0.1.12
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
            stylePageFastTravelNodes[#stylePageFastTravelNodes + 1] = {
                nodeIndex = nodeIndex,
                name = zo_strformat(name),
                normalizedName = Normalize(name),
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

local function ResolveCuratedStylePageHub(hubKey)
    if hubKey == 'NEW_LIFE' then
        return MakeExactNodeTarget('Kynesgrove Wayshrine',
            "New Life Festival - Breda's tent north of Kynesgrove Wayshrine", 'event')
    elseif hubKey == 'BELKARTH_FESTIVAL' or hubKey == 'BELKARTH_IMPRESARIO' then
        -- Belkarth Festival Grounds is a real event-hub POI on the Craglorn map.
        -- Prefer that exact POI; fall back to a fixed Craglorn coordinate derived
        -- from the festival-grounds map location rather than the Belkarth city map.
        return MakeExactPoiTargetInZones('Belkarth Festival Grounds', { 'Craglorn' },
            'Impresario / Event Exchange - Belkarth Festival Grounds', 'event')
            or MakeExactPoiTargetInZones('Balkarth Festival Grounds', { 'Craglorn' },
                'Impresario / Event Exchange - Belkarth Festival Grounds', 'event')
            or MakeCoordinateTarget('Craglorn', 0.4630859375, 0.4032552083,
                'Impresario / Event Exchange - Belkarth Festival Grounds', 'event')
    elseif hubKey == 'GLENUMBRA_IMPRESARIO' then
        return MakeCoordinateTarget('Glenumbra', 0.3396363258, 0.7399688363,
            'Impresario / Event Exchange - Glenumbra', 'event')
    elseif hubKey == 'GONFALON' then
        return MakeExactPoiTargetInZones('Gonfalon Gaming Hall',
            { 'Gonfalon Bay', 'High Isle and Amenos' },
            'Gonfalon Gaming Hall', 'activity')
            or MakeExactNodeOrPoiTarget('Gonfalon Palace Wayshrine',
                'Gonfalon Gaming Hall - nearest wayshrine', 'activity')
    elseif hubKey == 'NIGHT_MARKET' then
        return MakeExactNodeOrPoiTarget('Starlit Plaza Wayshrine',
            'Night Market - Fargrave / Starlit Plaza Wayshrine', 'event')
            or MakeZoneTarget(FindZoneByExactName('Fargrave City District'),
                'Night Market - Fargrave', 'event')
            or MakeZoneTarget(FindZoneByExactName('Fargrave'),
                'Night Market - Fargrave', 'event')
    elseif hubKey == 'WITCHES' then
        return MakeExactNodeTarget('Crosswych Wayshrine',
            "Witches Festival - Olyve's Brewery (nearest wayshrine)", 'event')
    elseif hubKey == 'BATTLEGROUNDS' then
        -- Use ESO's own Gladiator's Quarters POI instead of a guessed city-map
        -- coordinate.  The Alinor/Summerset location is the user-selected hub.
        return MakeExactPoiTargetInZones("Gladiator's Quarters",
            { 'Alinor', 'Summerset' },
            "Battlegrounds - Gladiator's Quarters, Alinor", 'activity')
            or MakeZoneTarget(FindZoneByExactName('Summerset'),
                "Battlegrounds - Gladiator's Quarters, Alinor", 'activity')
    elseif hubKey == 'UNDAUNTED_WAYREST' then
        -- Resolve the real Undaunted Enclave POI outside Wayrest.  This avoids
        -- fragile city-map coordinates.
        return MakeExactPoiTargetInZones('Undaunted Enclave',
            { 'Wayrest', 'Stormhaven' },
            'Undaunted Enclave - Wayrest', 'activity')
            or MakeZoneTarget(FindZoneByExactName('Stormhaven'),
                'Undaunted Enclave - Wayrest', 'activity')
    elseif hubKey == 'INFINITE_ARCHIVE' then
        -- Infinite Archive is exposed as its own map icon in Apocrypha.
        -- Prefer that exact POI, then an exact fast-travel node if available.
        return MakeExactPoiTarget('Infinite Archive', 'Apocrypha',
            'Infinite Archive', 'activity')
            or MakeExactNodeOrPoiTarget('Infinite Archive', 'Infinite Archive', 'activity')
            or MakeExactNodeOrPoiTarget('Speiran Tarn Wayshrine',
                'Infinite Archive - entrance north of Speiran Tarn Wayshrine', 'activity')
    end

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

local function ResolveStylePageMapTarget(family)
    if not family then return nil end

    local source = GetStylePageSourceOverride(family)
    if not source then
        -- Unknown/new Style Pages may still display ESO's source text, but they
        -- never receive a guessed map target.
        family._tcsMapResolved = true
        family._tcsMapTarget = false
        return nil
    end

    local mapType = source.mapType or 'NONE'
    local progressSensitive = mapType == 'DREAD_AURELIAN'
    if not progressSensitive and family._tcsMapResolved then
        return family._tcsMapTarget ~= false and family._tcsMapTarget or nil
    end

    local target = nil
    if mapType == 'NODE' and source.nodeName then
        target = MakeExactNodeOrPoiTarget(source.nodeName, source.location or source.nodeName, 'source')
    elseif mapType == 'POI' and source.poiName then
        target = MakeExactPoiTarget(source.poiName, source.zoneName, source.location or source.poiName, 'source')
    elseif mapType == 'COORD' and source.mapName and source.x and source.y then
        target = MakeCoordinateTarget(source.mapName, source.x, source.y, source.location or source.mapName, 'source')
    elseif mapType == 'ZONE' and source.zoneName then
        target = MakeZoneTarget(FindZoneByExactName(source.zoneName), source.location or source.zoneName, 'zone')
    elseif mapType == 'WORLD' then
        target = MakeWorldTarget(source.location or 'World Map')
    elseif mapType == 'HUB' and source.hub then
        target = ResolveCuratedStylePageHub(source.hub)
    elseif mapType == 'DREAD_AURELIAN' then
        target = ResolveDreadAurelianTarget(family)
    elseif mapType == 'NONE' then
        target = nil
    end

    if not progressSensitive then
        family._tcsMapTarget = target or false
        family._tcsMapResolved = true
    end
    return target
end

local function ShowStylePageFamilyOnMap(screen)
    local data = screen.styleList and screen.styleList:GetTargetData() or nil
    local family = data and data.style or nil
    local target = ResolveStylePageMapTarget(family)
    if not target then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, 'No exact map location is available for this Style Page set yet.')
        return
    end
    if WORLD_MAP_MANAGER and not WORLD_MAP_MANAGER:IsMapChangingAllowed() then return end

    screen.returnToMotifsAfterMap = true
    screen.returnMotifSelectedIndex = screen.styleList:GetSelectedIndex()
    ZO_WorldMap_ShowWorldMap()

    if target.kind == 'world' then
        return
    end

    local mapId = target.mapId or FindMapIdForStylePageZone(target.zoneIndex)
    local mapIndex = target.mapIndex or FindMapIndexForStylePageZone(target.zoneIndex)

    if mapId and WORLD_MAP_MANAGER.SetMapById then
        WORLD_MAP_MANAGER:SetMapById(mapId)
    elseif mapIndex then
        WORLD_MAP_MANAGER:SetMapByIndex(mapIndex)
    else
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, 'The Style Page source could not be opened on the map.')
        return
    end

    -- Zone-level sources (antiquities, portals, multi-location events, etc.)
    -- intentionally open the correct zone without inventing a fake pin.
    if target.kind == 'zone' and not target.nodeIndex and not target.poiIndex then
        return
    end

    local attempts = 0
    local function PlacePing()
        attempts = attempts + 1
        local mapReady = false
        if mapId and GetCurrentMapId then
            mapReady = GetCurrentMapId() == mapId
        elseif mapIndex and GetCurrentMapIndex then
            mapReady = GetCurrentMapIndex() == mapIndex
        end
        if not mapReady then
            if attempts < 30 then zo_callLater(PlacePing, 50) end
            return
        end

        local x, y = target.x, target.y
        if (not x or not y) and (target.kind == 'node' or target.nodeIndex) then
            local _, _, nx, ny, _, _, _, shown = GetFastTravelNodeInfo(target.nodeIndex)
            if shown then x, y = nx, ny end
        end
        if (not x or not y or x <= 0 or y <= 0 or x >= 1 or y >= 1) and target.zoneIndex and target.poiIndex and GetPOIMapInfo then
            local px, py, _, _, shown = GetPOIMapInfo(target.zoneIndex, target.poiIndex)
            if shown then x, y = px, py end
        end
        if not x or not y or x <= 0 or y <= 0 or x >= 1 or y >= 1 then
            if attempts < 20 then zo_callLater(PlacePing, 50) end
            return
        end

        local pinManager = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager() or nil
        local panAndZoom = ZO_WorldMap_GetPanAndZoom and ZO_WorldMap_GetPanAndZoom() or nil
        if not pinManager or not panAndZoom then return end
        pinManager:RemovePins('pings', MAP_PIN_TYPE_QUEST_PING)
        local pin = pinManager:CreatePin(MAP_PIN_TYPE_QUEST_PING, 'TCS_STYLE_PAGE_SOURCE', x, y)
        if pin then panAndZoom:JumpToPin(pin) end
    end
    zo_callLater(PlacePing, 150)
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
                    return data and data.style and ResolveStylePageMapTarget(data.style) ~= nil
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

local function InstallScreenHooks(screen)
    if screen._tcsStylePagesHooksInstalled then return end
    screen._tcsStylePagesHooksInstalled = true
    InstallStylePageMapKeybind(screen)

    screen._tcsOriginalShowStyle = screen.ShowStyle
    screen.ShowStyle = function(self, data)
        if self.activeModuleId ~= 'stylePages' then
            return self:_TCSCallOriginalShowStyle(data)
        end

        if not (data and data.style) then return end
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
            local status = page.unlocked and (GREEN .. 'Collected|r') or (RED .. 'Not collected|r')
            local pageTitle = page.displayName or page.name or 'Style Page'
            local entry = ZO_GamepadEntryData:New(string.format('%s  —  %s', pageTitle, status))
            entry.page = page
            entry.collectibleId = page.collectibleId
            entry.isKnown = page.unlocked
            self.detailList:AddEntry('ZO_QuestJournal_Gamepad_MenuEntryTemplate', entry)
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

local function PopulateStylePageFamilyList(screen)
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
    screen.styles = BuildStylePageFamiliesFromNativeCollections()
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
    version = 109,
    icon = STYLE_PAGES_ICON,
    supportsSearch = true,
    onCategoryFocus = ShowStylePagesCategory,
    open = OpenStylePages,
    activateSearch = function(screen)
        screen:ActivateMotifSearch()
    end,
})
