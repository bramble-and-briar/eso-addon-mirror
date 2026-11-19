-- TTC Motif Prices 0.4.2. ESO PC addon; price and motif APIs verified against
-- TTC's public API description and LibCharacterKnowledge's developer reference.
local addon = TTCMotifPrices
local ADDON_NAME = "TTC_Motif_Prices"
local LCK = LibCharacterKnowledge
local VERSION = "0.4.2"
local function Text(en, ru)
    return GetCVar and GetCVar("language.2") == "ru" and ru or en
end

local function Normalize(name)
    name = type(name) == "string" and name or ""
    if zo_strformat and SI_TOOLTIP_ITEM_NAME then name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name) end
    return zo_strlower(name):gsub("%^[%a]+", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local styleNames, styleCache = nil, {}
local function ContainsName(name, style)
    local startAt = 1
    while true do
        local first, last = name:find(style, startAt, true)
        if not first then return false end
        local before, after = name:sub(first - 1, first - 1), name:sub(last + 1, last + 1)
        if (first == 1 or before:match("[%s%p]")) and (last == #name or after:match("[%s%p]")) then return true end
        startAt = last + 1
    end
end

local function ResolveMotifStyle(data)
    if not data or not LCK or type(LCK.GetMotifStyles) ~= "function"
        or type(LCK.GetMotifItemsFromStyle) ~= "function" then
        return nil, "LCK unavailable"
    end

    local directId = data.GetOutfitStyleItemStyleId and data:GetOutfitStyleItemStyleId()
    if type(directId) == "number" and directId > 0
        and type(LCK.GetMotifItemsFromStyle(directId)) == "table" then
        return directId, "ESO style ID", GetItemStyleName and GetItemStyleName(directId)
    end

    -- Some outfit collectibles return 0 from GetOutfitStyleItemStyleId even
    -- when their localized name is a motif chapter (for example, "... Hat").
    -- Prefer the longest prefix; elsewhere accept only a unique style name.
    local collectibleName = data.GetName and data:GetName() or data.name
    if type(collectibleName) ~= "string" or collectibleName == "" then
        return nil, "collectible name unavailable"
    end
    local normalizedName = Normalize(collectibleName)
    if not styleNames then
        local ids = LCK.GetMotifStyles()
        if not ids or #ids == 0 then return nil, "LCK motif data not ready" end
        styleNames = {}
        for _, styleId in ipairs(ids) do
            local name = GetItemStyleName and GetItemStyleName(styleId)
            if name and name ~= "" and type(LCK.GetMotifItemsFromStyle(styleId)) == "table" then
                styleNames[#styleNames + 1] = { id = styleId, name = name, normalized = Normalize(name) }
            end
        end
    end
    local cached = styleCache[normalizedName]
    if cached ~= nil then
        if cached then return cached.id, "localized name match", cached.name end
        return nil, "no unambiguous LCK motif style matches collectible name"
    end
    local bestId, bestLength, ambiguous, bestEntry
    local prefixEntry, prefixLength, prefixAmbiguous, matchCount = nil, 0, false, 0
    for _, entry in ipairs(styleNames) do
        local length = #entry.normalized
        if length > 0 and ContainsName(normalizedName, entry.normalized) then
            matchCount = matchCount + 1
            if normalizedName:sub(1, length) == entry.normalized then
                if length > prefixLength then prefixEntry, prefixLength, prefixAmbiguous = entry, length, false
                elseif length == prefixLength and prefixEntry.id ~= entry.id then prefixAmbiguous = true end
            end
            if not bestLength or length > bestLength then
                bestId, bestLength, ambiguous, bestEntry = entry.id, length, false, entry
            elseif length == bestLength and entry.id ~= bestId then ambiguous = true end
        end
    end
    if prefixEntry then
        bestEntry = prefixEntry
        bestId = not prefixAmbiguous and prefixEntry.id or nil
    elseif ambiguous or matchCount ~= 1 then bestId = nil end
    styleCache[normalizedName] = bestId and bestEntry or false
    if bestId then
        local styleName = GetItemStyleName and GetItemStyleName(bestId)
        return bestId, "localized name match", styleName
    end
    return nil, "no LCK motif style matches collectible name"
end

local function CanonicalChapterName(name)
    local value = zo_strlower(name or "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "hat" or value == "hats" or value == "helm" or value == "helms"
        or value == "helmet" or value == "helmets" then
        return "helmet"
    end
    if value == "staff" or value == "staves" or value == "staffs" then
        return "staff"
    end
    if value == "maul" then return "mace" end
    if value == "greatsword" or value == "great sword" or value == "longsword" then return "sword" end
    if value:sub(-3) == "ies" then
        return value:sub(1, -4) .. "y"
    end
    if value:sub(-1) == "s" then
        return value:sub(1, -2)
    end
    return value
end

local function ResolveMotifChapter(data, styleName)
    if not data then return nil end
    -- Slots and weapon models are stable across client languages and armor weights.
    local slots = {
        { OUTFIT_SLOT_HEAD, ITEM_STYLE_CHAPTER_HELMETS },
        { OUTFIT_SLOT_CHEST, ITEM_STYLE_CHAPTER_CHESTS },
        { OUTFIT_SLOT_SHOULDERS, ITEM_STYLE_CHAPTER_SHOULDERS },
        { OUTFIT_SLOT_HANDS, ITEM_STYLE_CHAPTER_GLOVES },
        { OUTFIT_SLOT_WAIST, ITEM_STYLE_CHAPTER_BELTS },
        { OUTFIT_SLOT_LEGS, ITEM_STYLE_CHAPTER_LEGS },
        { OUTFIT_SLOT_FEET, ITEM_STYLE_CHAPTER_BOOTS },
    }
    local collectibleId = data.GetId and data:GetId() or data.collectibleId
    if collectibleId and GetEligibleOutfitSlotsForCollectible then
        for _, slot in ipairs({ GetEligibleOutfitSlotsForCollectible(collectibleId) }) do
            for _, mapping in ipairs(slots) do
                if mapping[1] and slot == mapping[1] then return mapping[2] end
            end
        end
    end
    local model = data.GetWeaponModelType and data:GetWeaponModelType()
    local models = {
        { WEAPON_MODEL_TYPE_AXE, ITEM_STYLE_CHAPTER_AXES },
        { WEAPON_MODEL_TYPE_HAMMER, ITEM_STYLE_CHAPTER_MACES },
        { WEAPON_MODEL_TYPE_SWORD, ITEM_STYLE_CHAPTER_SWORDS },
        { WEAPON_MODEL_TYPE_DAGGER, ITEM_STYLE_CHAPTER_DAGGERS },
        { WEAPON_MODEL_TYPE_BOW, ITEM_STYLE_CHAPTER_BOWS },
        { WEAPON_MODEL_TYPE_STAFF, ITEM_STYLE_CHAPTER_STAVES },
        { WEAPON_MODEL_TYPE_SHIELD, ITEM_STYLE_CHAPTER_SHIELDS },
    }
    for _, mapping in ipairs(models) do
        if mapping[1] and model == mapping[1] then return mapping[2] end
    end
    local itemName = data and (data.GetName and data:GetName() or data.name)
    if type(itemName) ~= "string" or type(styleName) ~= "string" or styleName == "" then
        return nil
    end
    if zo_strlower(itemName:sub(1, #styleName)) ~= zo_strlower(styleName) then
        return nil
    end
    local suffix = itemName:sub(#styleName + 1):gsub("^%s+", ""):gsub("%s+$", "")
    local itemChapter = CanonicalChapterName(suffix)
    local lastWord = suffix:match("([^%s%-]+)$")
    local terminalChapter = CanonicalChapterName(lastWord)
    for _, chapter in ipairs(LCK.GetMotifChapterNames and LCK.GetMotifChapterNames() or {}) do
        local chapterName = CanonicalChapterName(chapter.name)
        if chapterName == itemChapter or chapterName == terminalChapter then
            return chapter.id, chapter.name
        end
    end
    return nil
end

local function Print(message)
    d("|c66CCFF[TTC Motif Prices]|r " .. tostring(message))
end

local function FormatGold(value)
    if type(value) ~= "number" or value < 0 then return "—" end
    return ZO_CommaDelimitNumber(math.floor(value + 0.5)) .. "g"
end

local function BuildItemLink(itemId)
    if type(itemId) ~= "number" or itemId <= 0 then return nil end
    local link
    if LCK and type(LCK.GetItemLinkFromItemId) == "function" then
        link = LCK.GetItemLinkFromItemId(itemId, LINK_STYLE_DEFAULT)
    end
    if type(link) ~= "string" or link == "" or type(GetItemLinkItemId) ~= "function"
        or GetItemLinkItemId(link) ~= itemId then
        return nil
    end
    return link
end

-- Only verified bind-on-pickup metadata proves that this item cannot be listed
-- in guild stores. Missing TTC data or a missing item link does not prove it.
local function CannotGuildTrade(itemId)
    local link = BuildItemLink(itemId)
    if not link or type(GetItemLinkBindType) ~= "function" then return false end
    local bindType = GetItemLinkBindType(link)
    return (BIND_TYPE_ON_PICKUP ~= nil and bindType == BIND_TYPE_ON_PICKUP)
        or (BIND_TYPE_ON_PICKUP_BACKPACK ~= nil and bindType == BIND_TYPE_ON_PICKUP_BACKPACK)
end

-- Preserve all source facts, including later paragraphs and long conditions.
local function CleanAcquisitionText(value)
    if type(value) ~= "string" then return nil end
    value = value:gsub("|[cC]%x%x%x%x%x%x", ""):gsub("|[rR]", "")
    value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return value ~= "" and value or nil
end

local function AddBodyLine(tooltip, text, font)
    local r, g, b = ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB()
    tooltip:AddLine(text, font or "ZoFontGameMedium", r, g, b)
end

local function GetAcquisitionInfo(collectibleId)
    local result = { collectibleId = collectibleId }
    if type(collectibleId) ~= "number" or collectibleId <= 0 then return result end
    result.description = GetCollectibleDescription and CleanAcquisitionText(GetCollectibleDescription(collectibleId))
    result.hint = GetCollectibleHint and CleanAcquisitionText(GetCollectibleHint(collectibleId))
    local achievementId = GetCollectibleLinkedAchievement and GetCollectibleLinkedAchievement(collectibleId)
    if type(achievementId) == "number" and achievementId > 0 and GetAchievementInfo then
        result.achievementId = achievementId
        local name, description = GetAchievementInfo(achievementId)
        result.achievementName = CleanAcquisitionText(name)
        result.achievementDescription = CleanAcquisitionText(description)
    end
    -- Raw native fields are retained for diagnostics, never printed as flavor text.
    result.hasText = not not (result.description or result.hint or result.achievementName or result.achievementDescription)
    local catalog = addon.AcquisitionData
    local index = catalog and catalog.byCollectible and catalog.byCollectible[collectibleId]
    local entry = index and catalog.records and catalog.records[index]
    result.sourceStatus = entry and entry.status or "unconfirmed"
    result.source = entry and Text(entry.en, entry.ru or entry.en)
    result.sourceReferences = entry and entry.references
    return result
end

local function AddAcquisitionHelp(tooltip, collectibleId)
    local info = GetAcquisitionInfo(collectibleId)
    if info.sourceStatus == "control" then return end
    AddBodyLine(tooltip, Text("Source: ", "Источник: ") .. (info.source or Text(
        "Acquisition source not confirmed.", "Источник получения пока не подтверждён.")))
end

-- Inspect all outfit-style collectibles exposed by ESO, including locked styles.
-- Save only public catalog text, never account/character ownership information.
local function AuditAcquisition()
    if not COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE or not GetTotalCollectiblesByCategoryType
        or not GetCollectibleIdFromType then
        Print(Text("Outfit-style catalog API unavailable.", "API каталога стилей недоступен."))
        return
    end
    local report = { version = VERSION, api = GetAPIVersion and GetAPIVersion(),
        language = GetCVar and GetCVar("language.2"), timestamp = GetTimeStamp and GetTimeStamp(),
        entries = {}, missing = {}, descriptionOnly = {}, total = 0, invalidIndices = {},
        missingSources = {}, sourceCounts = {} }
    local count = GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE)
    for index = 1, count do
        local id = GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE, index)
        if type(id) == "number" and id > 0 then
            if not report.entries[id] then
                local info = GetAcquisitionInfo(id)
                info.name = GetCollectibleName and GetCollectibleName(id)
                report.entries[id] = info
                report.total = report.total + 1
                report.sourceCounts[info.sourceStatus] = (report.sourceCounts[info.sourceStatus] or 0) + 1
                if not info.source and info.sourceStatus ~= "control" then
                    report.missingSources[#report.missingSources + 1] = id
                end
                if not info.hasText then report.missing[#report.missing + 1] = id
                elseif info.description and not info.hint and not info.achievementName and not info.achievementDescription then
                    report.descriptionOnly[#report.descriptionOnly + 1] = id
                end
            end
        else
            report.invalidIndices[#report.invalidIndices + 1] = index
        end
    end
    report.catalogCount = count
    TTCMotifPricesSaved = TTCMotifPricesSaved or {}
    TTCMotifPricesSaved.acquisitionAudit = report
    Print(Text("Style catalog entries: ", "Записей каталога стилей: ") .. report.total
        .. Text("; source not confirmed: ", "; источник не подтверждён: ") .. #report.missingSources
        .. Text("; invalid catalog indices: ", "; недоступных записей: ") .. #report.invalidIndices)
    Print(Text("Native sources and researched sources are counted separately. Full report: TTCMotifPricesSaved.acquisitionAudit; /reloadui to save to disk.",
        "Игровые и дополненные источники подсчитаны отдельно. Полный отчёт: TTCMotifPricesSaved.acquisitionAudit; /reloadui для сохранения на диск."))
end

local function GetPrice(itemId)
    if not TamrielTradeCentrePrice or type(TamrielTradeCentrePrice.GetPriceInfo) ~= "function" then
        return nil, "TTC price API unavailable"
    end
    local link = BuildItemLink(itemId)
    if not link then return nil, "Could not build a verified item link for " .. tostring(itemId) end
    local info = TamrielTradeCentrePrice:GetPriceInfo(link)
    if type(info) ~= "table" then return nil, "TTC has no price data" end
    return info
end

local pageIndex, pageIndexSource
local function GetNamedTTCPrice(itemName)
    local source = TamrielTradeCentre and TamrielTradeCentre.ItemLookUpTable
    if type(itemName) ~= "string" or itemName == "" or type(source) ~= "table"
        or not TamrielTradeCentrePrice or type(TamrielTradeCentrePrice.GetPriceInfo) ~= "function" then
        return nil
    end
    if pageIndexSource ~= source then
        pageIndex, pageIndexSource = {}, source
        local function AddName(name, itemId)
            name = Normalize(name)
            if name == "" then return end
            local previous = pageIndex[name]
            if previous == nil then pageIndex[name] = itemId
            elseif previous ~= itemId then pageIndex[name] = false end
        end
        for name, types in pairs(source) do
            if type(types) == "table" then
                for specializedType, itemId in pairs(types) do
                    if (SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE and specializedType == SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE)
                        or (SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE and specializedType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE) then
                        AddName(name, itemId)
                        -- The localized item prefix precedes a colon in TTC data.
                        local suffix = name:match("^[^:]+:%s*(.+)$")
                        if suffix then AddName(suffix, itemId) end
                    end
                end
            end
        end
    end
    local itemId = pageIndex[Normalize(itemName)]
    if not itemId or not TamrielTradeCentrePrice.PriceTable
        or type(TamrielTradeCentrePrice.PriceTable.Data) ~= "table" then return nil, itemId end
    local itemData = TamrielTradeCentrePrice.PriceTable.Data[itemId]
    if type(itemData) ~= "table" then return nil, itemId end
    local bestInfo, lowestPrice
    for qualityId, levelData in pairs(itemData) do
        if type(levelData) == "table" then
            for level, traitData in pairs(levelData) do
                if type(traitData) == "table" then
                    for traitId in pairs(traitData) do
                        local info = TamrielTradeCentrePrice:GetPriceInfo({
                            ID = itemId, QualityID = qualityId, Level = level, TraitID = traitId,
                        })
                        if type(info) == "table" then
                            local price = tonumber(info.Min)
                            if price and price >= 0 and (not lowestPrice or price < lowestPrice) then
                                bestInfo, lowestPrice = info, price
                            end
                        end
                    end
                end
            end
        end
    end
    return bestInfo, itemId
end

local function PrintPrice(label, itemId)
    local info, err = GetPrice(itemId)
    if not info then
        Print(label .. " [item " .. tostring(itemId) .. "]: " .. tostring(err))
        return
    end
    Print(string.format("%s: Min %s | Avg %s | Listings %s", label,
        FormatGold(info.Min), FormatGold(info.Avg), tostring(info.EntryCount or 0)))
end

local function InspectStyle(styleId)
    styleId = tonumber(styleId)
    if not styleId then Print("Usage: /ttcmp style <itemStyleId>"); return end
    if not LCK or type(LCK.GetMotifItemsFromStyle) ~= "function" then
        Print("LibCharacterKnowledge is unavailable or too old."); return
    end
    local motif = LCK.GetMotifItemsFromStyle(styleId)
    if type(motif) ~= "table" then Print("No craftable motif for style ID " .. styleId); return end
    local styleName = GetItemStyleName and GetItemStyleName(styleId) or ("Style " .. styleId)
    Print("Style: " .. tostring(styleName) .. " (ID " .. styleId .. ")")
    if motif.books and motif.books[1] then PrintPrice("Full motif book", motif.books[1]) end
    local names = {}
    if type(LCK.GetMotifChapterNames) == "function" then
        for _, entry in ipairs(LCK.GetMotifChapterNames() or {}) do names[entry.id] = entry.name end
    end
    local count = 0
    for chapterId, itemId in pairs(motif.chapters or {}) do
        count = count + 1
        PrintPrice(names[chapterId] or ("Chapter " .. tostring(chapterId)), itemId)
    end
    if count == 0 then Print("This motif has no chapter item IDs.") end
end

local function ListStyles()
    if not LCK or type(LCK.GetMotifStyles) ~= "function" then
        Print("LibCharacterKnowledge.GetMotifStyles unavailable."); return
    end
    local styles = LCK.GetMotifStyles() or {}
    Print("Craftable motif styles: " .. tostring(#styles))
    for _, styleId in ipairs(styles) do
        local name = GetItemStyleName and GetItemStyleName(styleId) or ("Style " .. tostring(styleId))
        Print(tostring(styleId) .. " — " .. tostring(name))
    end
end

local function Diagnostics()
    Print("TTC price API: " .. tostring(TamrielTradeCentrePrice ~= nil
        and type(TamrielTradeCentrePrice.GetPriceInfo) == "function"))
    Print("LibCharacterKnowledge: " .. tostring(LCK ~= nil
        and type(LCK.GetMotifItemsFromStyle) == "function"))
    Print("ESO API version: " .. tostring(GetAPIVersion and GetAPIVersion() or "unknown"))
    Print("Hover integration: Outfit Styles MouseTargetChanged callback " .. tostring(ZO_OUTFIT_STYLES_PANEL_KEYBOARD ~= nil))
    local priceTable = TamrielTradeCentrePrice and TamrielTradeCentrePrice.PriceTable
    local timestamp = priceTable and priceTable.TimeStamp
    if type(timestamp) == "number" then
        local age = GetTimeStamp and math.max(0, math.floor((GetTimeStamp() - timestamp) / 86400))
        local date = GetDateStringFromTimestamp and GetDateStringFromTimestamp(timestamp) or tostring(timestamp)
        Print(Text("TTC table date: ", "Дата таблицы TTC: ") .. tostring(date)
            .. (age and Text("; age in days: ", "; возраст в днях: ") .. tostring(age) or ""))
    else
        Print(Text("TTC price table missing", "Таблица цен TTC отсутствует"))
    end
    Print(Text("Update TTC prices with its client, then /reloadui. No data does not mean zero price.",
        "Обновите цены клиентом TTC, затем /reloadui. Нет данных не означает нулевую цену."))
end

local function FindTrader(kind)
    local panel = ZO_OUTFIT_STYLES_PANEL_KEYBOARD
    local entry = panel and panel:GetMouseOverEntryData()
    local data = entry and entry.data
    if not data or data.isEmptyCell or data.clearAction then
        Print(Text("Hover an Outfit Style, then use /ttcmp buy.", "Наведите курсор на стиль и введите /ttcmp buy."))
        return
    end
    local styleId, _, styleName = ResolveMotifStyle(data)
    local chapter = ResolveMotifChapter(data, styleName)
    local motif = styleId and LCK and LCK.GetMotifItemsFromStyle(styleId)
    local itemId, ttcId
    if motif then
        itemId = kind ~= "book" and chapter and motif.chapters and motif.chapters[chapter]
        if not itemId and (kind == "book" or not next(motif.chapters or {})) then
            local lowest
            for _, bookId in ipairs(motif.books or {}) do
                if not CannotGuildTrade(bookId) then
                    local info = GetPrice(bookId)
                    local price = info and tonumber(info.Min)
                    if not itemId or (price and (not lowest or price < lowest)) then
                        itemId, lowest = bookId, price
                    end
                end
            end
        end
        if itemId and not CannotGuildTrade(itemId) and TamrielTradeCentre_ItemInfo
            and type(TamrielTradeCentre_ItemInfo.New) == "function" then
            local link = BuildItemLink(itemId)
            local info = link and TamrielTradeCentre_ItemInfo:New(link)
            ttcId = info and info.ID
        end
    else
        local name = data.GetName and data:GetName() or data.name
        local _
        _, ttcId = GetNamedTTCPrice(name)
    end
    if type(ttcId) ~= "number" or ttcId <= 0 or not RequestOpenUnsafeURL then
        Print(Text("No tradable item identified for this style.", "Для этого стиля не определён торгуемый предмет."))
        return
    end
    local region = TamrielTradeCentre and TamrielTradeCentre.GetCurrentServerRegion
        and TamrielTradeCentre:GetCurrentServerRegion()
    if region ~= "NA" and region ~= "EU" then
        Print(Text("TTC server region is unknown.", "TTC не определил регион сервера."))
        return
    end
    RequestOpenUnsafeURL("https://" .. (region == "NA" and "us" or "eu")
        .. ".tamrieltradecentre.com/pc/Trade/SearchResult?ItemID=" .. tostring(ttcId)
        .. "&SortBy=Price&Order=asc")
end

local function HandleCommand(args)
    local command, value = zo_strsplit(" ", args or "")
    command = string.lower(command or "help")
    if command == "audit" then
        AuditAcquisition()
    elseif command == "diag" then
        Diagnostics()
    elseif command == "styles" then
        ListStyles()
    elseif command == "style" then
        InspectStyle(value)
    elseif command == "buy" then
        FindTrader(value)
    elseif command == "hover" then
        local panel = ZO_OUTFIT_STYLES_PANEL_KEYBOARD
        local entry = panel and panel:GetMouseOverEntryData()
        local data = entry and entry.data
        if not data then
            Print("No hovered Outfit Style. Keep pointer over a card and run /ttcmp hover.")
            return
        end
        local rawStyleId = data.GetOutfitStyleItemStyleId and data:GetOutfitStyleItemStyleId()
        local styleId, source, styleName = ResolveMotifStyle(data)
        local chapterId, chapterName = ResolveMotifChapter(data, styleName)
        local name = data.GetName and data:GetName() or data.name
        local collectibleId = data.GetId and data:GetId() or data.collectibleId
        Print("Hovered " .. tostring(name) .. "; collectible=" .. tostring(collectibleId)
            .. "; reference=" .. tostring(data.referenceId) .. "; ESO styleId=" .. tostring(rawStyleId)
            .. "; resolved=" .. tostring(styleId) .. " (" .. tostring(source) .. ")"
            .. "; chapter=" .. tostring(chapterName or chapterId))
        if type(styleId) == "number" and styleId > 0 and LCK then
            local motif = LCK.GetMotifItemsFromStyle(styleId)
            local chapterCount, bookCount = 0, 0
            for _ in pairs(motif and motif.chapters or {}) do chapterCount = chapterCount + 1 end
            for _ in pairs(motif and motif.books or {}) do bookCount = bookCount + 1 end
            Print("LCK motif=" .. tostring(motif ~= nil) .. "; chapters=" .. chapterCount .. "; books=" .. bookCount)
        end
    else
        Print("Commands: /ttcmp audit | /ttcmp diag | /ttcmp hover | /ttcmp styles | /ttcmp style <itemStyleId> | /ttcmp buy [book]")
    end
end

local function OnAddonLoaded(_, loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    TTCMotifPricesSaved = TTCMotifPricesSaved or {}
    SLASH_COMMANDS["/ttcmp"] = HandleCommand
    if ZO_OUTFIT_STYLES_PANEL_KEYBOARD
        and type(ZO_OUTFIT_STYLES_PANEL_KEYBOARD.RegisterCallback) == "function" then
        ZO_OUTFIT_STYLES_PANEL_KEYBOARD:RegisterCallback("MouseTargetChanged", function()
            local panel = ZO_OUTFIT_STYLES_PANEL_KEYBOARD
            local entry = panel:GetMouseOverEntryData()
            local data = entry and entry.data
            if not data or data.isEmptyCell or data.clearAction then return end
            local styleId, _, styleName = ResolveMotifStyle(data)
            local chapterId = ResolveMotifChapter(data, styleName)
            local collectibleName = data and (data.GetName and data:GetName() or data.name)
            local collectibleId = data.GetId and data:GetId() or data.collectibleId
            TTCMotifPrices.ShowStylePrices(ItemTooltip, styleId, chapterId, collectibleName, collectibleId)
        end)
    else
        Print("Outfit Styles hover callback unavailable; prices will not show.")
    end
    Print("v" .. VERSION .. " loaded. Use /ttcmp diag")
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)

-- Public renderer used by the Outfit Styles MouseTargetChanged callback above.
local function AddPriceRow(tooltip, label, info)
    local average = info and tonumber(info.Avg)
    if not average or average < 0 then return end
    local amount = FormatGold(average)
    if ZO_Currency_FormatKeyboard then
        amount = ZO_Currency_FormatKeyboard(CURT_MONEY, math.floor(average + 0.5), ZO_CURRENCY_FORMAT_AMOUNT_ICON,
            { color = ZO_SELECTED_TEXT })
    elseif ZO_SELECTED_TEXT and ZO_SELECTED_TEXT.Colorize then
        amount = ZO_SELECTED_TEXT:Colorize(amount)
    end
    AddBodyLine(tooltip, label .. Text(" — average: ", " — средняя: ") .. amount)
end

addon.GetPrice = GetPrice
addon.ShowStylePrices = function(tooltip, itemStyleId, chapterFilter, collectibleName, collectibleId)
        if not tooltip then return false end
        AddAcquisitionHelp(tooltip, collectibleId)
        if type(itemStyleId) ~= "number" or itemStyleId <= 0 then
            if type(collectibleName) ~= "string" or collectibleName == "" then return false end
            local info = GetNamedTTCPrice(collectibleName)
            if info then
                AddPriceRow(tooltip, Text("Style page", "Страница стиля"), info)
            end
            return info ~= nil
        end
        local motif = LCK and type(LCK.GetMotifItemsFromStyle) == "function" and LCK.GetMotifItemsFromStyle(itemStyleId)
        if type(motif) ~= "table" then
            return false
        end
        local selectedChapter = chapterFilter and motif.chapters and motif.chapters[chapterFilter]
        local onlyBoundBooks = #(motif.books or {}) > 0
        for _, itemId in ipairs(motif.books or {}) do
            if not CannotGuildTrade(itemId) then onlyBoundBooks = false; break end
        end
        -- A bound selected part gets acquisition help only, including no book
        -- price distraction. Book-only styles follow the same rule.
        if (selectedChapter and CannotGuildTrade(selectedChapter))
            or (not next(motif.chapters or {}) and onlyBoundBooks) then
            return true
        end
        if chapterFilter then
            local itemId = motif.chapters and motif.chapters[chapterFilter]
            if itemId then
                local chapterName
                for _, entry in ipairs(LCK.GetMotifChapterNames and LCK.GetMotifChapterNames() or {}) do
                    if entry.id == chapterFilter then chapterName = entry.name; break end
                end
                local label = Text("Chapter", "Глава") .. (chapterName and " · " .. chapterName or "")
                if CannotGuildTrade(itemId) then
                    tooltip:AddLine(label .. Text(": not sold in guild stores (binds on pickup)",
                        ": нельзя купить в гильдейских магазинах (привязка при получении)"), "ZoFontGame")
                else
                    local info = GetPrice(itemId)
                    AddPriceRow(tooltip, label, info)
                end
            end
        elseif next(motif.chapters or {}) then
            tooltip:AddLine(Text("Chapter could not be identified", "Не удалось определить главу"), "ZoFontGame")
        end
        local selectedBookInfo
        local hasBook = false
        local allBooksBound = true
        for _, itemId in ipairs(motif.books or {}) do
            hasBook = true
            if not CannotGuildTrade(itemId) then
                allBooksBound = false
                local info = GetPrice(itemId)
                local price = info and tonumber(info.Min)
                if price and price >= 0 and (not selectedBookInfo or price < tonumber(selectedBookInfo.Min)) then
                    selectedBookInfo = info
                end
            end
        end
        if hasBook then
            if not allBooksBound then
                AddPriceRow(tooltip, Text("Full book", "Полная книга"), selectedBookInfo)
            end
        end
        return true
    end
