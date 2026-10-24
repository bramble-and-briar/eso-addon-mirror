local LIB = rawget(_G, "LibUser562")
if not (LIB and LIB.IsSupported and LIB.IsSupported() and LIB.RegisterSettings) then return end

--------------------------------------------------
-- Config
--------------------------------------------------
local PANEL_NAME = "WhereIsIt"

local ICON_INVENTORY = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_inventory.dds"
local ICON_BANK      = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_bankAndInventory.dds"
local ICON_CRAFTBAG  = "EsoUI/Art/HUD/Gamepad/gp_lootHistory_icon_craftBag.dds"
local ICON_GUILD     = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_guilds.dds"
local ICON_HOUSE     = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_housing.dds"
local ICON_CURRENCY  = "/esoui/art/currency/gold_mipmap.dds"
local ICON_LIST      = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_activityFinder.dds"
local ICON_COMPANION = "EsoUI/Art/Companion/Gamepad/gp_companion_icon_inventory.dds"
local ICON_SETTINGS  = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_settings.dds"
local ICON_SEARCH    = "EsoUI/Art/Miscellaneous/Gamepad/gp_icon_search_64.dds"

local SAVED_ACCOUNT_TIP = "Account wide: the same on all your characters."

local FRAME_GREY = { r = 0.55, g = 0.55, b = 0.55 }

local DEFAULT_FONT = "EsoUI/Common/Fonts/FTN57.otf"

local FONT_CHOICES = {
    { name = "Gamepad Medium",  value = "EsoUI/Common/Fonts/FTN57.otf" },
    { name = "Gamepad Bold",    value = "EsoUI/Common/Fonts/FTN87.otf" },
    { name = "Gamepad Light",   value = "EsoUI/Common/Fonts/FTN47.otf" },
    { name = "Univers Regular", value = "EsoUI/Common/Fonts/Univers57.otf" },
    { name = "Univers Light",   value = "EsoUI/Common/Fonts/univers55.otf" },
    { name = "Univers Bold",    value = "EsoUI/Common/Fonts/univers67.otf" },
    { name = "Prose Antique",   value = "EsoUI/Common/Fonts/ProseAntiquePSMT.otf" },
    { name = "Trajan Pro",      value = "EsoUI/Common/Fonts/TrajanPro-Regular.otf" },
    { name = "Handwritten",     value = "EsoUI/Common/Fonts/Handwritten_Bold.otf" },
    { name = "Arial Narrow",    value = "EsoUI/Common/Fonts/arialn.ttf" },
    { name = "Consolas",        value = "EsoUI/Common/Fonts/consola.ttf" },
}

local RAINBOW_PALETTE = { "FF2222", "FF9900", "FFEE00", "33DD33", "00CCCC", "3399FF", "BB44EE" }

local WINDOW_DEFAULTS = {
    settingsFontSize       = 30,
    settingsFont           = "EsoUI/Common/Fonts/FTN57.otf",
    settingsOpacity        = 100,
    settingsHighlight      = "Alliance",
    settingsHighlightColor = { r = 1, g = 1, b = 1, a = 1 },
    settingsRemember       = true,
    showPrice              = "average",
}

local UPDATE_CHARACTERS = "Updates when you log in, log out, and any time your inventory changes."
local UPDATE_CURRENCIES = "Updates whenever an amount changes."
local UPDATE_COMPANIONS = "Updates when you summon one."
local UPDATE_CRAFTBAG   = "Updates when you log in, and any time it changes."
local UPDATE_BANK       = "Updates when you open your bank."
local UPDATE_GUILDS     = "Updates when you open one."
local UPDATE_STORAGE    = "Updates when you travel to a house you own, and any time it changes."
local UPDATE_GUILD_ONE  = "Updates when you open this guild's bank."
local UPDATE_COMPANION  = "Updates when you summon them."
local UPDATE_HOUSE_ONE  = "Updates when you travel to this house, and any time it changes."

local panel

local searchQuery   = ""
local searchResults = {}

local MENU_COLOR = "D65AD6"
WHEREISIT_MENU_TITLE_COLORED = "|c" .. MENU_COLOR .. "Where Is It?|r"

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return WhereIsIt and WhereIsIt.savedVariables
end

local function FormatCount(n)
    n = tonumber(n) or 0
    if ZO_CommaDelimitNumber then return ZO_CommaDelimitNumber(n) end
    return tostring(n)
end

local function HasEntries(tbl)
    return type(tbl) == "table" and next(tbl) ~= nil
end

local function RainbowText(text)
    local out = {}
    local idx = 1
    for i = 1, #text do
        local ch = text:sub(i, i)
        if ch == " " then
            out[#out + 1] = ch
        else
            local color = RAINBOW_PALETTE[((idx - 1) % #RAINBOW_PALETTE) + 1]
            out[#out + 1] = "|c" .. color .. ch .. "|r"
            idx = idx + 1
        end
    end
    return table.concat(out)
end

local function PanelCall(method)
    if panel and panel[method] then panel[method](panel) end
end

local function JoinText(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local text = select(i, ...)
        if type(text) == "string" and text ~= "" then parts[#parts + 1] = text end
    end
    return table.concat(parts, "\n\n")
end

--------------------------------------------------
-- Tracked Sources
--------------------------------------------------
local TRACK_CHOICES = {
    { name = "Currencies",  value = "currencies" },
    { name = "Characters",  value = "characters" },
    { name = "Companions",  value = "companions" },
    { name = "Craft Bag",   value = "craftBag"   },
    { name = "Bank",        value = "bank"       },
    { name = "Guild Banks", value = "guildBanks" },
    { name = "Storage",     value = "storage"    },
}

local function IsTracked(key)
    if not (WhereIsIt and WhereIsIt.IsTracked) then return true end
    local ok, result = pcall(WhereIsIt.IsTracked, WhereIsIt, key)
    if not ok then return true end
    return result
end

local function TrackedValues()
    local selected = {}
    for i = 1, #TRACK_CHOICES do
        local key = TRACK_CHOICES[i].value
        if IsTracked(key) then selected[#selected + 1] = key end
    end
    return selected
end

local function SetTrackedValues(selected)
    local sv = SV()
    if not sv then return end

    sv.tracked = sv.tracked or {}

    local wanted = {}
    for i = 1, #(selected or {}) do
        wanted[selected[i]] = true
    end

    for i = 1, #TRACK_CHOICES do
        local key = TRACK_CHOICES[i].value
        local on  = wanted[key] == true
        local was = sv.tracked[key] ~= false

        sv.tracked[key] = on

        if was and not on and WhereIsIt and WhereIsIt.ClearTracked then
            pcall(WhereIsIt.ClearTracked, WhereIsIt, key)
        elseif on and not was and WhereIsIt and WhereIsIt.RescanTracked then
            pcall(WhereIsIt.RescanTracked, WhereIsIt, key)
        end
    end
end

--------------------------------------------------
-- Quality Colour
--------------------------------------------------
local QUALITY_HEX_FALLBACK = {
    [0] = "aaaaaa",
    [1] = "ffffff",
    [2] = "2dc50e",
    [3] = "3a92ff",
    [4] = "a02ee4",
    [5] = "e4c027",
}

local qualityHexCache = {}

local function QualityHex(quality)
    quality = quality or 1

    local cached = qualityHexCache[quality]
    if cached then return cached end

    local hex
    if GetItemQualityColor then
        local color = GetItemQualityColor(quality)
        if color and color.ToHex then
            local ok, result = pcall(color.ToHex, color)
            if ok and type(result) == "string" and result ~= "" then
                hex = result
            end
        end
    end

    hex = hex or QUALITY_HEX_FALLBACK[quality] or "ffffff"
    qualityHexCache[quality] = hex
    return hex
end

--------------------------------------------------
-- Currencies
--------------------------------------------------
local CURRENCIES = {
    {
        key = "gold", label = "Gold", hex = "FFCC00",
        currencyType = CURT_MONEY,
        icon = "/esoui/art/currency/gold_mipmap.dds",
    },
    {
        key = "alliancePoints", label = "Alliance Points", hex = "39FF14",
        currencyType = CURT_ALLIANCE_POINTS,
        icon = "/esoui/art/currency/alliancepoints.dds",
    },
    {
        key = "telVar", label = "Tel Var Stones", hex = "4499FF",
        currencyType = CURT_TELVAR_STONES,
        icon = "/esoui/art/currency/telvar_mipmap.dds",
    },
    {
        key = "writVouchers", label = "Writ Vouchers", hex = "FFFFFF",
        currencyType = CURT_WRIT_VOUCHERS,
        icon = "/esoui/art/icons/icon_writvoucher.dds",
    },
}

local function CurrencyIcon(currency)
    if currency.iconMarkup ~= nil then return currency.iconMarkup end

    local markup = ""
    if currency.icon and zo_iconFormat then
        markup = zo_iconFormat(currency.icon, "100%", "100%")
    end

    currency.iconMarkup = markup
    return markup
end

local function BankCurrencyAmount(currency)
    if not (GetCurrencyAmount and CURRENCY_LOCATION_BANK) then return 0 end
    return GetCurrencyAmount(currency.currencyType, CURRENCY_LOCATION_BANK) or 0
end

--------------------------------------------------
-- Alliance Colour
--------------------------------------------------
local allianceHexCache = {}

local function AllianceHex(alliance)
    if type(alliance) ~= "number" or not GetAllianceColor then return nil end

    local cached = allianceHexCache[alliance]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    local hex
    local color = GetAllianceColor(alliance)
    if color and color.ToHex then
        local ok, result = pcall(color.ToHex, color)
        if ok and type(result) == "string" and result ~= "" then hex = result end
    end

    allianceHexCache[alliance] = hex or false
    return hex
end

local function AllianceColored(text, alliance)
    local hex = AllianceHex(alliance)
    if not hex then return text end
    return string.format("|c%s%s|r", hex, text)
end

local function GuildAlliance(guildId)
    if not GetGuildAlliance then return nil end
    local id = tonumber(guildId)
    if not id or id <= 0 then return nil end
    return GetGuildAlliance(id)
end

--------------------------------------------------
-- Item Collection
--------------------------------------------------
local CATEGORY_FILTER_BY_ORDER = {
    [2]  = ITEMFILTERTYPE_WEAPONS,
    [3]  = ITEMFILTERTYPE_ARMOR,
    [4]  = ITEMFILTERTYPE_CONSUMABLE,
    [5]  = ITEMFILTERTYPE_CRAFTING,
    [6]  = ITEMFILTERTYPE_FURNISHING,
    [7]  = ITEMFILTERTYPE_COMPANION,
    [8]  = ITEMFILTERTYPE_QUEST,
    [9]  = ITEMFILTERTYPE_JUNK,
    [10] = ITEMFILTERTYPE_MISCELLANEOUS,
}

local categoryLabelCache = {}

local function CategoryLabel(order)
    order = order or 10

    local cached = categoryLabelCache[order]
    if cached then return cached end

    local label
    if WhereIsIt and type(WhereIsIt.CategoryLabelForOrder) == "function" then
        local ok, result = pcall(WhereIsIt.CategoryLabelForOrder, order)
        if ok and type(result) == "string" and result ~= "" then
            label = result
        end
    end

    if not label then
        local filterType = CATEGORY_FILTER_BY_ORDER[order]
        if filterType then
            local resolved = GetString("SI_ITEMFILTERTYPE", filterType)
            if resolved and resolved ~= "" then label = resolved end
        end
    end

    label = label or "Miscellaneous"
    categoryLabelCache[order] = label
    return label
end

local WORN_LOCATIONS = {
    ["Worn"] = true,
    ["Companion Worn"] = true,
}

--------------------------------------------------
-- In-Game Groups
--------------------------------------------------
local ICON_PACK        = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds"
local ICON_SUPPLIES    = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds"
local ICON_MATERIALS   = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_materials.dds"
local ICON_SLOTTABLE   = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot.dds"
local ICON_FURNISHINGS = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuIcon_furnishings.dds"
local ICON_COMPANIONS  = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_companionItems.dds"
local ICON_WEAPONS     = "EsoUI/Art/CharacterWindow/gearSlot_mainHand.dds"
local ICON_APPAREL     = "EsoUI/Art/CharacterWindow/gearSlot_chest.dds"
local ICON_ACCESSORIES = "EsoUI/Art/CharacterWindow/gearSlot_neck.dds"

local function Const(name)
    return rawget(_G, name)
end

local function ClientString(stringId, fallback)
    if stringId and type(GetString) == "function" then
        local ok, text = pcall(GetString, stringId)
        if ok and type(text) == "string" and text ~= "" then return text end
    end
    return fallback
end

local function EnumString(prefix, value, fallback)
    if value ~= nil and type(GetString) == "function" then
        local ok, text = pcall(GetString, prefix, value)
        if ok and type(text) == "string" and text ~= "" then return text end
    end
    return fallback
end

local GROUP_PACK        = WhereIsIt.GROUP_PACK        or 1
local GROUP_WEAPONS     = WhereIsIt.GROUP_WEAPONS     or 2
local GROUP_APPAREL     = WhereIsIt.GROUP_APPAREL     or 3
local GROUP_ACCESSORIES = WhereIsIt.GROUP_ACCESSORIES or 4

local PACK_SUPPLIES     = WhereIsIt.PACK_SUPPLIES     or 1
local PACK_MATERIALS    = WhereIsIt.PACK_MATERIALS    or 2
local PACK_SLOTTABLE    = WhereIsIt.PACK_SLOTTABLE    or 3
local PACK_FURNISHINGS  = WhereIsIt.PACK_FURNISHINGS  or 4
local PACK_COMPANION    = WhereIsIt.PACK_COMPANION    or 5

local EQUIP_GROUP_ORDER = { GROUP_WEAPONS, GROUP_APPAREL, GROUP_ACCESSORIES }
local PACK_ORDER        = { PACK_SUPPLIES, PACK_MATERIALS, PACK_SLOTTABLE, PACK_FURNISHINGS, PACK_COMPANION }

local GROUP_VISUAL_CATEGORY = {
    [GROUP_WEAPONS]     = Const("EQUIP_SLOT_VISUAL_CATEGORY_WEAPONS"),
    [GROUP_APPAREL]     = Const("EQUIP_SLOT_VISUAL_CATEGORY_APPAREL"),
    [GROUP_ACCESSORIES] = Const("EQUIP_SLOT_VISUAL_CATEGORY_ACCESSORIES"),
}

local GROUP_FALLBACK_LABEL = {
    [GROUP_WEAPONS]     = "Weapons",
    [GROUP_APPAREL]     = "Apparel",
    [GROUP_ACCESSORIES] = "Accessories",
}

local GROUP_ICON = {
    [GROUP_WEAPONS]     = ICON_WEAPONS,
    [GROUP_APPAREL]     = ICON_APPAREL,
    [GROUP_ACCESSORIES] = ICON_ACCESSORIES,
}

local PACK_FILTER_TYPE = {
    [PACK_MATERIALS]   = ITEMFILTERTYPE_CRAFTING,
    [PACK_SLOTTABLE]   = ITEMFILTERTYPE_QUICKSLOT,
    [PACK_FURNISHINGS] = ITEMFILTERTYPE_FURNISHING,
    [PACK_COMPANION]   = ITEMFILTERTYPE_COMPANION,
}

local PACK_FALLBACK_LABEL = {
    [PACK_SUPPLIES]    = "Supplies",
    [PACK_MATERIALS]   = "Materials",
    [PACK_SLOTTABLE]   = "Slottable Items",
    [PACK_FURNISHINGS] = "Furnishings",
    [PACK_COMPANION]   = "Companion Items",
}

local PACK_ICON = {
    [PACK_SUPPLIES]    = ICON_SUPPLIES,
    [PACK_MATERIALS]   = ICON_MATERIALS,
    [PACK_SLOTTABLE]   = ICON_SLOTTABLE,
    [PACK_FURNISHINGS] = ICON_FURNISHINGS,
    [PACK_COMPANION]   = ICON_COMPANIONS,
}

local groupLabelCache = {}

local function PackLabel()
    if not groupLabelCache.pack then
        groupLabelCache.pack = ClientString(Const("SI_GAMEPAD_INVENTORY_PACK_CATEGORY_HEADER"), "Pack")
    end
    return groupLabelCache.pack
end

local function AllLabel()
    if not groupLabelCache.all then
        groupLabelCache.all = EnumString("SI_ITEMFILTERTYPE", ITEMFILTERTYPE_ALL, "All")
    end
    return groupLabelCache.all
end

local function GroupLabel(group)
    local cached = groupLabelCache[group]
    if cached then return cached end

    local label = EnumString("SI_EQUIPSLOTVISUALCATEGORY",
        GROUP_VISUAL_CATEGORY[group], GROUP_FALLBACK_LABEL[group] or "Items")

    groupLabelCache[group] = label
    return label
end

local packLabelCache = {}

local function PackSubLabel(sub)
    local cached = packLabelCache[sub]
    if cached then return cached end

    local label
    if sub == PACK_SUPPLIES then
        label = ClientString(Const("SI_INVENTORY_SUPPLIES"), PACK_FALLBACK_LABEL[sub])
    else
        label = EnumString("SI_ITEMFILTERTYPE", PACK_FILTER_TYPE[sub], PACK_FALLBACK_LABEL[sub])
    end

    label = label or "Items"
    packLabelCache[sub] = label
    return label
end

local function Classify(item)
    if WhereIsIt and type(WhereIsIt.EnsureClassified) == "function" then
        local ok, group, packSub = pcall(WhereIsIt.EnsureClassified, item)
        if ok then return group, packSub end
    end
    return GROUP_PACK, PACK_SUPPLIES
end

local function EquipGroupFilter(group)
    return function(item)
        return Classify(item) == group
    end
end

local function PackSubFilter(sub)
    return function(item)
        local group, packSub = Classify(item)
        return group == GROUP_PACK and (packSub or PACK_SUPPLIES) == sub
    end
end

local function TallyGroups(tables)
    local tally = {
        packSubs  = {},
        groups    = {},
        hasPack   = false,
        itemCount = 0,
        slotCount = 0,
        wornCount = 0,
    }

    for i = 1, #(tables or {}) do
        local tbl = tables[i]
        if type(tbl) == "table" then
            for _, item in pairs(tbl) do
                local group, packSub = Classify(item)

                if group == GROUP_PACK then
                    tally.hasPack = true
                    tally.packSubs[packSub or PACK_SUPPLIES] = true
                else
                    tally.groups[group] = true
                end

                local slots = tonumber(item.slots) or 1
                tally.itemCount = tally.itemCount + (tonumber(item.count) or 0)
                if WORN_LOCATIONS[item.location or ""] then
                    tally.wornCount = tally.wornCount + slots
                else
                    tally.slotCount = tally.slotCount + slots
                end
            end
        end
    end

    return tally
end

local function ItemSectionName(item)
    if WhereIsIt and type(WhereIsIt.CategoryNameFor) == "function" then
        local ok, name = pcall(WhereIsIt.CategoryNameFor, item)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return CategoryLabel(item.catOrder or 10)
end

local function SortItems(list)
    local sectionCache = {}

    local function Section(item)
        local cached = sectionCache[item]
        if cached == nil then
            cached = ItemSectionName(item) or ""
            sectionCache[item] = cached
        end
        return cached
    end

    table.sort(list, function(a, b)
        local sectionA = zo_strlower(Section(a))
        local sectionB = zo_strlower(Section(b))
        if sectionA ~= sectionB then return sectionA < sectionB end
        local nameA = zo_strlower(a.displayName or "")
        local nameB = zo_strlower(b.displayName or "")
        if nameA ~= nameB then return nameA < nameB end
        return (a.location or "") < (b.location or "")
    end)
end

local function CollectItems(tables, filter)
    local isFunction = type(filter) == "function"

    local list = {}
    for i = 1, #tables do
        local tbl = tables[i]
        if type(tbl) == "table" then
            for _, item in pairs(tbl) do
                local keep
                if isFunction then
                    local ok, result = pcall(filter, item)
                    keep = ok and result
                elseif filter then
                    keep = item.location == filter
                else
                    keep = true
                end

                if keep then list[#list + 1] = item end
            end
        end
    end
    SortItems(list)
    return list
end

--------------------------------------------------
-- Tooltips
--------------------------------------------------
local function AddTooltipLine(parts, text)
    if text and text ~= "" then
        parts[#parts + 1] = text
    end
end

local function BuildItemFallbackTooltip(item)
    local parts = {}

    AddTooltipLine(parts, string.format("|c%s%s|r",
        QualityHex(item.quality),
        item.displayName or ""))

    return table.concat(parts, "\n")
end

--------------------------------------------------
-- Marked Items
--------------------------------------------------
local MARK_PREFIX = "|cFFCC00*|r "

local markedItems = {}
local markedSet   = {}

local MarkStatusMessage

local function IsMarked(item)
    return item ~= nil and markedSet[item] == true
end

local function MarkedCount()
    return #markedItems
end

local function RemoveMark(item)
    if not (item and markedSet[item]) then return end
    markedSet[item] = nil
    for i = 1, #markedItems do
        if markedItems[i] == item then
            table.remove(markedItems, i)
            return
        end
    end
end

local function ToggleMark(item)
    if not item then return end
    if markedSet[item] then
        RemoveMark(item)
    else
        markedSet[item] = true
        markedItems[#markedItems + 1] = item
    end
end

local function ClearMarks()
    if #markedItems == 0 then return end
    markedItems = {}
    markedSet   = {}
end

--------------------------------------------------
-- Lookups
--------------------------------------------------
local function SortedCharacterIds()
    local sv = SV()
    if not sv or not sv.characters then return {} end

    local currentId = tostring(GetCurrentCharacterId and GetCurrentCharacterId() or "")
    local ids = {}
    for charId in pairs(sv.characters) do
        ids[#ids + 1] = charId
    end

    table.sort(ids, function(a, b)
        if a == currentId then return true end
        if b == currentId then return false end
        local nameA = sv.characters[a].name or a
        local nameB = sv.characters[b].name or b
        return zo_strlower(nameA) < zo_strlower(nameB)
    end)

    return ids
end

local function CurrentGuildIds()
    local ids = {}
    if not (GetNumGuilds and GetGuildId) then return ids end
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        if guildId and guildId ~= 0 then
            ids[tostring(guildId)] = true
        end
    end
    return ids
end


--------------------------------------------------
-- Search
--------------------------------------------------
local setNameCache = {}

local function SetNameKey(itemLink)
    if not itemLink or itemLink == "" or not GetItemLinkSetInfo then return nil end

    local cached = setNameCache[itemLink]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end

    local hasSet, setName = GetItemLinkSetInfo(itemLink)
    if hasSet and setName and setName ~= "" then
        if zo_strformat and SI_ITEM_FORMAT_STR_SET_NAME_NO_COUNT then
            setName = zo_strformat(SI_ITEM_FORMAT_STR_SET_NAME_NO_COUNT, setName)
        end
        setName = zo_strlower(setName)
        setNameCache[itemLink] = setName
        return setName
    end

    setNameCache[itemLink] = false
    return nil
end

local function AddMatches(results, tbl, where, query)
    if type(tbl) ~= "table" then return end

    for _, item in pairs(tbl) do
        local name = item.displayName
        local hit  = name ~= nil and zo_strlower(name):find(query, 1, true) ~= nil

        if not hit then
            local setName = SetNameKey(item.itemLink)
            hit = setName ~= nil and setName:find(query, 1, true) ~= nil
        end

        if name and hit then
            results[#results + 1] = {
                displayName = name,
                count       = item.count,
                quality     = item.quality,
                catOrder    = item.catOrder,
                itemLink    = item.itemLink,
                slots       = item.slots,
                location    = where,
                where       = where,
                group       = item.group,
                packSub     = item.packSub,
            }
        end
    end
end

local function RunSearch()
    searchResults = {}

    local query = zo_strlower(searchQuery or "")
    if query == "" then return end

    local sv = SV()
    if not sv then return end

    local ids = SortedCharacterIds()
    for i = 1, #ids do
        local data = sv.characters[ids[i]]
        if data then
            AddMatches(searchResults, data.items, data.name or ("Char " .. ids[i]), query)
        end
    end

    local account = sv.account
    if not account then return end

    for _, companion in pairs(account.companions or {}) do
        AddMatches(searchResults, companion.items, companion.name or "Companion", query)
    end

    AddMatches(searchResults, account.craftBag, "Craft Bag", query)
    AddMatches(searchResults, account.bank, "Bank", query)

    for _, guild in pairs(account.guildBanks or {}) do
        AddMatches(searchResults, guild.items, guild.name or "Guild Bank", query)
    end

    for _, chest in pairs(account.houseChests or {}) do
        local where = chest.name or "Chest"
        if chest.house then where = where .. " - " .. chest.house end
        AddMatches(searchResults, chest.items, where, query)
    end

    AddMatches(searchResults, account.furnitureVault, "Furniture Vault", query)
end

local function SearchResultsLabel()
    if searchQuery == "" then return "Results" end
    return string.format("Results  |c888888(%s)|r", FormatCount(#searchResults))
end

local function SetSearchQuery(text)
    searchQuery = text or ""
    RunSearch()
    PanelCall("RefreshPages")
end

--------------------------------------------------
-- Link to Chat
--------------------------------------------------
local function SelectedItem()
    if not panel then return nil end
    local opt = panel:GetSelectedOption()
    local item = opt and opt.item
    if type(item) ~= "table" then return nil end
    local itemLink = item.itemLink
    if type(itemLink) ~= "string" or itemLink == "" then return nil end
    return item
end

local function CanLinkToChat()
    if type(IsChatSystemAvailableForCurrentPlatform) ~= "function" then return false end
    local ok, available = pcall(IsChatSystemAvailableForCurrentPlatform)
    return ok and available == true
end

local function ChatHudEnabled()
    local settingType = rawget(_G, "SETTING_TYPE_UI")
    local settingId   = rawget(_G, "UI_SETTING_GAMEPAD_CHAT_HUD_ENABLED")
    if not (settingType and settingId) then return nil end
    if type(GetSetting_Bool) ~= "function" then return nil end

    local ok, value = pcall(GetSetting_Bool, settingType, settingId)
    if not ok then return nil end
    return value == true
end

local function PushToChat(text)
    local chatSystem = type(ZO_GetChatSystem) == "function" and ZO_GetChatSystem() or CHAT_SYSTEM

    if ChatHudEnabled() == false then
        if not (chatSystem and type(chatSystem.StartTextEntry) == "function") then return false end

        if type(chatSystem.Maximize) == "function" then
            pcall(chatSystem.Maximize, chatSystem)
        end

        local NO_CHANNEL, NO_TARGET, DONT_SHOW_HUD_WINDOW = nil, nil, true
        return pcall(chatSystem.StartTextEntry, chatSystem, text, NO_CHANNEL, NO_TARGET, DONT_SHOW_HUD_WINDOW)
    end

    if type(StartChatInput) == "function" then
        if pcall(StartChatInput, text) then return true end
    end

    if chatSystem and type(chatSystem.StartTextEntry) == "function" then
        return pcall(chatSystem.StartTextEntry, chatSystem, text)
    end

    return false
end

local function LinkKeybindName()
    local base = "Link to Chat"

    local stringId = rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT")
    if stringId then
        local ok, text = pcall(GetString, stringId)
        if ok and type(text) == "string" and text ~= "" then base = text end
    end

    local count = MarkedCount()
    if count > 0 then return string.format("%s (%d)", base, count) end
    return base
end

local function WithBracketStyle(itemLink)
    local bracketStyle = rawget(_G, "LINK_STYLE_BRACKETS")
    if type(bracketStyle) ~= "number" then return itemLink end

    local converted, replaced = itemLink:gsub("^|H%d+:", "|H" .. bracketStyle .. ":", 1)
    if replaced == 1 then return converted end
    return itemLink
end

local function FormatItemLink(itemLink)
    local formatted = itemLink
    if zo_strformat and SI_TOOLTIP_ITEM_NAME then
        local ok, text = pcall(zo_strformat, SI_TOOLTIP_ITEM_NAME, itemLink)
        if ok and type(text) == "string" and text ~= "" then formatted = text end
    end
    return WithBracketStyle(formatted)
end

local function ChatInputLimit()
    local chatSystem = type(ZO_GetChatSystem) == "function" and ZO_GetChatSystem() or CHAT_SYSTEM
    local textEntry  = chatSystem and chatSystem.textEntry

    if textEntry and type(textEntry.GetEditControl) == "function" then
        local ok, editControl = pcall(textEntry.GetEditControl, textEntry)
        if ok and editControl and type(editControl.GetMaxInputChars) == "function" then
            local gotMax, maxChars = pcall(editControl.GetMaxInputChars, editControl)
            if gotMax and type(maxChars) == "number" and maxChars > 0 then
                return maxChars
            end
        end
    end

    local constant = rawget(_G, "MAX_TEXT_CHAT_INPUT_CHARACTERS")
    if type(constant) == "number" and constant > 0 then return constant end

    return 350
end

local function BuildLinkText()
    local maxChars = ChatInputLimit()

    local source
    if MarkedCount() > 0 then
        source = markedItems
    else
        local item = SelectedItem()
        source = item and { item } or {}
    end

    local parts, sent, length = {}, {}, 0
    for i = 1, #source do
        local item     = source[i]
        local itemLink = item and item.itemLink
        if type(itemLink) == "string" and itemLink ~= "" then
            local formatted = FormatItemLink(itemLink)
            local addition  = (#parts > 0) and (" " .. formatted) or formatted
            if length + #addition > maxChars then break end

            parts[#parts + 1] = formatted
            sent[#sent + 1]   = item
            length = length + #addition
        end
    end

    return table.concat(parts, " "), sent
end

MarkStatusMessage = function()
    local marked = MarkedCount()
    if marked == 0 then return nil end

    local _, fits = BuildLinkText()
    return string.format("|cFFCC00Marked %d - Link %d|r", marked, #fits)
end

--------------------------------------------------
-- Counts
--------------------------------------------------
local function KeepItem(item, filter)
    if type(filter) == "function" then
        local ok, result = pcall(filter, item)
        return ok and result
    elseif filter then
        return item.location == filter
    end
    return true
end

local function CountItems(tables, filter)
    local counts = { slots = 0, worn = 0, items = 0 }
    for i = 1, #(tables or {}) do
        local tbl = tables[i]
        if type(tbl) == "table" then
            for _, item in pairs(tbl) do
                if KeepItem(item, filter) then
                    local slots = tonumber(item.slots) or 1
                    counts.items = counts.items + (tonumber(item.count) or 0)
                    if WORN_LOCATIONS[item.location or ""] then
                        counts.worn = counts.worn + slots
                    else
                        counts.slots = counts.slots + slots
                    end
                end
            end
        end
    end
    return counts
end

local function CountText(counts)
    if not counts then return "" end
    local lines = {}
    if counts.slots > 0 or counts.worn == 0 then
        lines[#lines + 1] = "Slots: " .. FormatCount(counts.slots)
    end
    if counts.worn > 0 then
        lines[#lines + 1] = "Worn: " .. FormatCount(counts.worn)
    end
    lines[#lines + 1] = "Items: " .. FormatCount(counts.items)
    return table.concat(lines, "\n")
end

local function CountTip(getTables, filter, note)
    return function()
        return JoinText(CountText(CountItems(getTables() or {}, filter)), note)
    end
end

--------------------------------------------------
-- Prices
--------------------------------------------------
local PRICE_ICON = "|t24:24:EsoUI/Art/currency/currency_gold.dds|t"

local PRICE_CHOICES = {
    { name = "Off",     value = "off" },
    { name = "Min",     value = "min" },
    { name = "Average", value = "average" },
    { name = "Max",     value = "max" },
}

local PRICE_LABELS = {
    min     = "Min Price",
    average = "Average Price",
    max     = "Max Price",
}

local function PriceMode()
    local sv = SV()
    local mode = sv and sv.showPrice
    if mode == "off" or PRICE_LABELS[mode] then return mode end
    return WINDOW_DEFAULTS.showPrice
end

local function FormatPrice(value)
    if value >= 100 then return ZO_CommaDelimitNumber(zo_round(value)) end
    local rounded = zo_round(value * 100) / 100
    if rounded == math.floor(rounded) then return tostring(math.floor(rounded)) end
    return string.format("%.2f", rounded)
end

local function PriceHeader(opt)
    local mode = PriceMode()
    if mode == "off" then return nil end

    local item = opt and opt.item
    local itemLink = item and item.itemLink
    if type(itemLink) ~= "string" or itemLink == "" then return nil end

    local api = rawget(_G, "TSCPriceDataAPI")
    if type(api) ~= "table" or type(api.GetItemData) ~= "function" then return nil end

    local ok, data = pcall(api.GetItemData, api, itemLink)
    if not ok or type(data) ~= "table" or data == api.LOADING then return nil end

    local value
    if mode == "average" then
        value = tonumber(data.avgPrice)
    elseif mode == "min" then
        value = tonumber(data.commonMin) or tonumber(data.legacyMin)
    else
        value = tonumber(data.commonMax) or tonumber(data.legacyMax)
    end
    if not value then return nil end

    return PRICE_LABELS[mode] .. ": " .. FormatPrice(value) .. " " .. PRICE_ICON
end

--------------------------------------------------
-- Item Rows
--------------------------------------------------
local function MarkPrefix(opt)
    if IsMarked(opt.item) then return MARK_PREFIX end
    return ""
end

local function NextCategory()
    if panel then panel:SelectNextHeader() end
end

local function ItemLabel(item)
    local label = string.format("|c%s%s|r  |c888888x%s|r",
        QualityHex(item.quality),
        item.displayName or "",
        FormatCount(item.count))
    if item.where then
        label = label .. "  |c777777" .. item.where .. "|r"
    end
    return label
end

local function ItemRows(items, emptyText)
    local options = {}
    if #items == 0 then
        options[1] = { type = "button", name = emptyText or "Nothing saved here yet." }
        return options
    end

    local firstSection, mixed = nil, false
    for i = 1, #items do
        local section = ItemSectionName(items[i]) or ""
        if firstSection == nil then
            firstSection = section
        elseif section ~= firstSection then
            mixed = true
            break
        end
    end

    local currentSection
    for i = 1, #items do
        local item = items[i]
        if mixed then
            local section = ItemSectionName(item) or ""
            if section ~= currentSection then
                currentSection = section
                options[#options + 1] = { type = "header", name = section }
            end
        end
        options[#options + 1] = {
            type       = "button",
            name       = ItemLabel(item),
            namePrefix = MarkPrefix,
            itemLink   = item.itemLink,
            itemHeader = PriceHeader,
            item       = item,
            tooltip    = (item.itemLink == nil or item.itemLink == "") and BuildItemFallbackTooltip(item) or nil,
            buttonText = mixed and "Next Category" or nil,
            func       = mixed and NextCategory or nil,
        }
    end
    return options
end

local function ItemPage(name, icon, getTables, filter, label, note)
    return {
        type    = "submenu",
        name    = label or name,
        icon    = icon,
        tooltip = CountTip(getTables, filter, note),
        options = function()
            return ItemRows(CollectItems(getTables() or {}, filter))
        end,
    }
end

--------------------------------------------------
-- Grouped Pages
--------------------------------------------------
local function IsPackItem(item)
    return Classify(item) == GROUP_PACK
end

local function GroupedSource(name, icon, getTables, label, note)
    local tally = TallyGroups(getTables() or {})
    local options = {}

    if tally.hasPack or next(tally.groups) ~= nil then
        options[#options + 1] = ItemPage(AllLabel(), ICON_LIST, getTables, nil)
    end

    if tally.hasPack then
        local packPages = {}
        for i = 1, #PACK_ORDER do
            local sub = PACK_ORDER[i]
            if tally.packSubs[sub] then
                packPages[#packPages + 1] = ItemPage(PackSubLabel(sub), PACK_ICON[sub], getTables, PackSubFilter(sub))
            end
        end
        if #packPages > 0 then
            options[#options + 1] = {
                type    = "submenu",
                name    = PackLabel(),
                icon    = ICON_PACK,
                tooltip = CountTip(getTables, IsPackItem),
                options = packPages,
            }
        end
    end

    for i = 1, #EQUIP_GROUP_ORDER do
        local group = EQUIP_GROUP_ORDER[i]
        if tally.groups[group] then
            options[#options + 1] = ItemPage(GroupLabel(group), GROUP_ICON[group], getTables, EquipGroupFilter(group))
        end
    end

    if #options == 0 then return nil end

    return {
        type    = "submenu",
        name    = label or name,
        icon    = icon,
        tooltip = CountTip(getTables, nil, note),
        options = options,
    }
end

--------------------------------------------------
-- Menu Sections
--------------------------------------------------
local function CurrencyTotal(currency)
    local sv = SV()
    local total = BankCurrencyAmount(currency)
    for _, data in pairs((sv and sv.characters) or {}) do
        total = total + ((data.currencies and data.currencies[currency.key]) or 0)
    end
    return total
end

local function BuildSearchSection()
    return {
        type    = "submenu",
        name    = "Search",
        icon    = ICON_SEARCH,
        tooltip = "Find an item by its name or its set name on all your characters, companions, banks and storage.",
        options = {
            {
                type    = "editbox",
                name    = "Search",
                tooltip = "Type part of an item name or a set name, then open Results.",
                details = function()
                    if searchQuery == "" then return "Nothing searched yet." end
                    return string.format("Searching for \"%s\".", searchQuery)
                end,
                getFunc = function() return searchQuery end,
                setFunc = SetSearchQuery,
            },
            {
                type    = "submenu",
                name    = SearchResultsLabel,
                icon    = ICON_LIST,
                tooltip = function()
                    if searchQuery == "" then return "Search for something first." end
                    return string.format("%s matches for \"%s\".", FormatCount(#searchResults), searchQuery)
                end,
                options = function()
                    local empty = searchQuery == "" and "Search for something first." or "No matches found."
                    return ItemRows(CollectItems({ searchResults }), empty)
                end,
            },
        },
    }
end

local function BuildCurrencySection()
    if not IsTracked("currencies") then return nil end
    local sv = SV()
    if not sv or not sv.characters then return nil end

    local currencySubmenus = {}

    for c = 1, #CURRENCIES do
        local currency = CURRENCIES[c]
        local rows = {}

        if BankCurrencyAmount(currency) > 0 then
            rows[#rows + 1] = {
                type = "button",
                name = function()
                    return string.format("%s |c%s%s|r  Bank",
                        CurrencyIcon(currency),
                        currency.hex,
                        FormatCount(BankCurrencyAmount(currency)))
                end,
            }
        end

        local ids = SortedCharacterIds()
        for i = 1, #ids do
            local charId   = ids[i]
            local data     = sv.characters[charId]
            local charName = data.name or ("Char " .. charId)
            local amount   = (data.currencies and data.currencies[currency.key]) or 0

            if amount > 0 then
                rows[#rows + 1] = {
                    type = "button",
                    name = function()
                        local current = (sv.characters[charId] and sv.characters[charId].currencies
                                         and sv.characters[charId].currencies[currency.key]) or 0
                        return string.format("%s |c%s%s|r  %s",
                            CurrencyIcon(currency),
                            currency.hex,
                            FormatCount(current),
                            charName)
                    end,
                }
            end
        end

        if #rows > 0 then
            currencySubmenus[#currencySubmenus + 1] = {
                type    = "submenu",
                name    = string.format("|c%s%s|r", currency.hex, currency.label),
                icon    = currency.icon,
                tooltip = function()
                    return string.format("Total: |c%s%s|r", currency.hex, FormatCount(CurrencyTotal(currency)))
                end,
                options = rows,
            }
        end
    end

    if #currencySubmenus == 0 then return nil end

    return {
        type    = "submenu",
        name    = "Currencies",
        icon    = ICON_CURRENCY,
        tooltip = JoinText("How much of each currency your characters and your bank have.", UPDATE_CURRENCIES),
        options = currencySubmenus,
    }
end

local function AllCharacterTables()
    local sv = SV()
    local tables = {}
    for _, data in pairs((sv and sv.characters) or {}) do
        if type(data.items) == "table" then tables[#tables + 1] = data.items end
    end
    return tables
end

local function BuildCharacterSection()
    if not IsTracked("characters") then return nil end
    local sv = SV()
    if not sv or not sv.characters then return nil end

    local options = {}
    local ids     = SortedCharacterIds()

    for i = 1, #ids do
        local charId   = ids[i]
        local data     = sv.characters[charId]
        local charName = data.name or ("Char " .. charId)

        if HasEntries(data.items) then
            local section = GroupedSource(
                charName,
                ICON_INVENTORY,
                function()
                    local current = SV() and SV().characters and SV().characters[charId]
                    if not current then return {} end
                    return { current.items }
                end,
                AllianceColored(charName, data.alliance),
                UPDATE_CHARACTERS)

            if section then options[#options + 1] = section end
        end
    end

    if #options == 0 then return nil end

    return {
        type    = "submenu",
        name    = "Characters",
        icon    = ICON_INVENTORY,
        tooltip = function()
            return JoinText("What each of your characters is carrying and wearing.",
                CountText(CountItems(AllCharacterTables())), UPDATE_CHARACTERS)
        end,
        options = options,
    }
end

local function BuildCompanionSection()
    if not IsTracked("companions") then return nil end
    local sv      = SV()
    local account = sv and sv.account
    if not (account and HasEntries(account.companions)) then return nil end

    local keys = {}
    for key in pairs(account.companions) do
        keys[#keys + 1] = key
    end

    table.sort(keys, function(a, b)
        local nameA = account.companions[a].name or a
        local nameB = account.companions[b].name or b
        return zo_strlower(nameA) < zo_strlower(nameB)
    end)

    local options = {}
    for i = 1, #keys do
        local key  = keys[i]
        local data = account.companions[key]
        if HasEntries(data.items) then
            local section = GroupedSource(
                data.name or key,
                ICON_COMPANION,
                function()
                    local current = SV() and SV().account and SV().account.companions
                    current = current and current[key]
                    if not current then return {} end
                    return { current.items }
                end,
                nil,
                UPDATE_COMPANION)

            if section then options[#options + 1] = section end
        end
    end

    if #options == 0 then return nil end

    return {
        type    = "submenu",
        name    = "Companions",
        icon    = ICON_COMPANION,
        tooltip = JoinText("What each of your companions is wearing.", UPDATE_COMPANIONS),
        options = options,
    }
end

local function BuildGuildSection()
    if not IsTracked("guildBanks") then return nil end
    if WhereIsIt and type(WhereIsIt.PruneLeftGuilds) == "function" then
        pcall(WhereIsIt.PruneLeftGuilds, WhereIsIt)
    end

    local sv = SV()
    local guildBanks = sv and sv.account and sv.account.guildBanks
    if not HasEntries(guildBanks) then return nil end

    local currentIds  = CurrentGuildIds()
    local filterStale = next(currentIds) ~= nil

    local guildIds = {}
    for guildId, guild in pairs(guildBanks) do
        if HasEntries(guild.items) and (not filterStale or currentIds[guildId]) then
            guildIds[#guildIds + 1] = guildId
        end
    end

    if #guildIds == 0 then return nil end

    table.sort(guildIds, function(a, b)
        local nameA = guildBanks[a].name or a
        local nameB = guildBanks[b].name or b
        return zo_strlower(nameA) < zo_strlower(nameB)
    end)

    local options = {}
    for i = 1, #guildIds do
        local guildId   = guildIds[i]
        local guildName = guildBanks[guildId].name or "Guild Bank"

        local section = GroupedSource(
            guildName,
            ICON_GUILD,
            function()
                local current = SV() and SV().account and SV().account.guildBanks
                                and SV().account.guildBanks[guildId]
                if not current then return {} end
                return { current.items }
            end,
            AllianceColored(guildName, GuildAlliance(guildId)),
            UPDATE_GUILD_ONE)

        if section then options[#options + 1] = section end
    end

    if #options == 0 then return nil end

    return {
        type    = "submenu",
        name    = "Guild Banks",
        icon    = ICON_GUILD,
        tooltip = JoinText("The guild banks of the guilds you're in.", UPDATE_GUILDS),
        options = options,
    }
end

local function BuildChestPagesByHouse(chests)
    local houses, order = {}, {}

    for key, chest in pairs(chests) do
        if type(chest) == "table" and HasEntries(chest.items) then
            local houseName = chest.house or "Unknown House"
            if not houses[houseName] then
                houses[houseName] = {}
                order[#order + 1] = houseName
            end
            local list = houses[houseName]
            list[#list + 1] = { key = key, name = chest.name or "House Chest" }
        end
    end

    table.sort(order, function(a, b) return zo_strlower(a) < zo_strlower(b) end)

    local houseSubmenus = {}
    for i = 1, #order do
        local houseName = order[i]
        local list = houses[houseName]

        table.sort(list, function(a, b)
            local nameA, nameB = zo_strlower(a.name), zo_strlower(b.name)
            if nameA ~= nameB then return nameA < nameB end
            return a.key < b.key
        end)

        local chestPages = {}
        local chestKeys  = {}
        for j = 1, #list do
            local key = list[j].key
            chestKeys[#chestKeys + 1] = key
            local section = GroupedSource(
                list[j].name,
                ICON_HOUSE,
                function()
                    local current = SV() and SV().account and SV().account.houseChests
                    current = current and current[key]
                    if not current then return {} end
                    return { current.items }
                end,
                nil,
                UPDATE_HOUSE_ONE)

            if section then chestPages[#chestPages + 1] = section end
        end

        if #chestPages > 0 then
            houseSubmenus[#houseSubmenus + 1] = {
                type    = "submenu",
                name    = houseName,
                icon    = ICON_HOUSE,
                tooltip = CountTip(function()
                    local all = SV() and SV().account and SV().account.houseChests
                    local tables = {}
                    for k = 1, #chestKeys do
                        local chest = all and all[chestKeys[k]]
                        if chest and chest.items then tables[#tables + 1] = chest.items end
                    end
                    return tables
                end, nil, UPDATE_HOUSE_ONE),
                options = chestPages,
            }
        end
    end

    return houseSubmenus
end

local function BuildStorageSection()
    if not IsTracked("storage") then return nil end
    local sv = SV()
    local account = sv and sv.account
    if not account then return nil end

    local options = {}

    if HasEntries(account.houseChests) then
        local houseSubmenus = BuildChestPagesByHouse(account.houseChests)
        if #houseSubmenus > 0 then
            options[#options + 1] = {
                type    = "submenu",
                name    = "Storage Chests",
                icon    = ICON_HOUSE,
                tooltip = JoinText("The storage chests in each house you own.", UPDATE_STORAGE),
                options = houseSubmenus,
            }
        end
    end

    if HasEntries(account.furnitureVault) then
        options[#options + 1] = ItemPage(
            "Furniture Vault",
            ICON_HOUSE,
            function() return { SV().account.furnitureVault } end,
            nil, nil, UPDATE_STORAGE)
    end

    if #options == 0 then return nil end

    return {
        type    = "submenu",
        name    = "Storage",
        icon    = ICON_HOUSE,
        tooltip = JoinText("Storage chests and the furniture vault in the houses you own.", UPDATE_STORAGE),
        options = options,
    }
end

--------------------------------------------------
-- Settings
--------------------------------------------------
local ALL_TRACKED = { "currencies", "characters", "companions", "craftBag", "bank", "guildBanks", "storage" }

local function ResetSettings()
    local sv = SV()
    if not sv then return end

    local all = {}
    for i = 1, #ALL_TRACKED do all[i] = ALL_TRACKED[i] end
    SetTrackedValues(all)

    for key, value in pairs(WINDOW_DEFAULTS) do
        if type(value) == "table" then
            local copy = {}
            for k, v in pairs(value) do copy[k] = v end
            sv[key] = copy
        else
            sv[key] = value
        end
    end
    sv.settingsLastPage = nil

    PanelCall("ApplyTextSize")
    PanelCall("ApplyFont")
    PanelCall("ApplyOpacity")
    PanelCall("ApplyAccent")
end

local function Setting(key)
    local sv = SV()
    local value = sv and sv[key]
    if value == nil then return WINDOW_DEFAULTS[key] end
    return value
end

local function SetSetting(key, value)
    local sv = SV()
    if sv then sv[key] = value end
end

local function BuildSettingsSection()
    return {
        type    = "submenu",
        name    = "Settings",
        icon    = ICON_SETTINGS,
        tooltip = SAVED_ACCOUNT_TIP,
        options = {
            {
                type    = "checklist",
                name    = "Track",
                noSelectionText = "None",
                choices = TRACK_CHOICES,
                default = ALL_TRACKED,
                getFunc = TrackedValues,
                setFunc = SetTrackedValues,
                tooltip = "Choose what " .. WHEREISIT_MENU_TITLE_COLORED .. " keeps track of.\n\n"
                       .. "Unticking something stops it being scanned AND deletes what has "
                       .. "already been saved for it, so it disappears from the list.\n\n"
                       .. "Tick it again and it comes back empty. It fills back in the next "
                       .. "time you log in on a character, summon a companion, open the bank, "
                       .. "open a guild bank or visit a house.\n\n"
                       .. "The list updates the next time you open " .. WHEREISIT_MENU_TITLE_COLORED .. ".",
            },
            {
                type    = "button",
                name    = "Info",
                tooltip = "Everything saves itself as you play. This is when each one "
                       .. "happens.\n\n"
                       .. "Characters - logging in, logging out, and any time your "
                       .. "inventory changes.\n\n"
                       .. "Currencies - whenever an amount changes.\n\n"
                       .. "Companions - when you summon one.\n\n"
                       .. "Craft Bag - logging in, and any time it changes.\n\n"
                       .. "Bank - opening it.\n\n"
                       .. "Guild Banks - opening one.\n\n"
                       .. "Storage Chests - traveling to a house you own, and any time it changes.\n\n"
                       .. "Furniture Vault - the same as storage chests.",
            },
            {
                type    = "dropdown",
                name    = "Show Price",
                choices = PRICE_CHOICES,
                default = WINDOW_DEFAULTS.showPrice,
                tooltip = "Shows the selected price above the item in Details, for items that have price data. "
                       .. "Needs TSCPriceFetcher2.\n\nDefault is Average.",
                getFunc = function() return Setting("showPrice") end,
                setFunc = function(val) SetSetting("showPrice", val) end,
            },
            {
                type    = "slider",
                name    = "Font Size",
                min     = 18, max = 44, step = 1,
                default = WINDOW_DEFAULTS.settingsFontSize,
                tooltip = "Default is 30.",
                getFunc = function() return Setting("settingsFontSize") end,
                setFunc = function(val)
                    SetSetting("settingsFontSize", val)
                    PanelCall("ApplyTextSize")
                end,
            },
            {
                type    = "dropdown",
                name    = "Font",
                choices = FONT_CHOICES,
                default = DEFAULT_FONT,
                tooltip = "Some fonts look bigger or smaller than others, so you may need to adjust Font Size.\n\nDefault is Gamepad Medium.",
                getFunc = function() return Setting("settingsFont") end,
                setFunc = function(val)
                    SetSetting("settingsFont", val)
                    PanelCall("ApplyFont")
                end,
            },
            {
                type    = "slider",
                name    = "Opacity",
                min     = 0, max = 100, step = 5,
                default = WINDOW_DEFAULTS.settingsOpacity,
                tooltip = "Default is 100.",
                getFunc = function() return Setting("settingsOpacity") end,
                setFunc = function(val)
                    SetSetting("settingsOpacity", val)
                    PanelCall("ApplyOpacity")
                end,
            },
            {
                type         = "stylecolor",
                name         = RainbowText("Highlight / Slider Color"),
                choices      = { "Alliance", "Custom" },
                customValue  = "Custom",
                default      = WINDOW_DEFAULTS.settingsHighlight,
                colorDefault = { r = 1, g = 1, b = 1 },
                details      = function()
                    if Setting("settingsHighlight") == "Custom" then
                        return "Highlights and sliders use your color."
                    end
                    return "Highlights and sliders use your alliance color."
                end,
                getFunc  = function() return Setting("settingsHighlight") end,
                setFunc  = function(val)
                    SetSetting("settingsHighlight", val)
                    PanelCall("ApplyAccent")
                end,
                getColor = function()
                    local c = Setting("settingsHighlightColor")
                    if type(c) == "table" then return c.r or 1, c.g or 1, c.b or 1 end
                    return 1, 1, 1
                end,
                setColor = function(r, g, b)
                    SetSetting("settingsHighlightColor", { r = r, g = g, b = b, a = 1 })
                    PanelCall("ApplyAccent")
                end,
            },
            {
                type    = "toggle",
                name    = "Remember Last Page",
                preset  = "YES_NO",
                default = WINDOW_DEFAULTS.settingsRemember,
                tooltip = "Reopens the last page where you left off.",
                getFunc = function() return Setting("settingsRemember") end,
                setFunc = function(val) SetSetting("settingsRemember", val) end,
            },
            {
                type       = "button",
                name       = "|cFF3333Reset All|r",
                buttonText = "Reset All",
                tooltip    = function()
                    return "Puts every " .. WHEREISIT_MENU_TITLE_COLORED .. " setting back to its default. Your saved items are kept."
                end,
                confirm    = function()
                    return "Reset every " .. WHEREISIT_MENU_TITLE_COLORED .. " setting to its default? This can't be undone."
                end,
                func       = ResetSettings,
            },
        },
    }
end

local function BuildOptions()
    local sv = SV()
    local account = sv and sv.account
    local options = {}

    local function Append(section)
        if section then options[#options + 1] = section end
    end

    Append(BuildSearchSection())
    Append(BuildCurrencySection())
    Append(BuildCharacterSection())
    Append(BuildCompanionSection())

    if IsTracked("craftBag") and account and HasEntries(account.craftBag) then
        Append(ItemPage("Craft Bag", ICON_CRAFTBAG,
            function() return { SV().account.craftBag } end, nil, nil, UPDATE_CRAFTBAG))
    end

    if IsTracked("bank") and account and HasEntries(account.bank) then
        Append(GroupedSource("Bank", ICON_BANK,
            function() return { SV().account.bank } end, nil, UPDATE_BANK))
    end

    Append(BuildGuildSection())
    Append(BuildStorageSection())
    Append(BuildSettingsSection())

    return options
end

--------------------------------------------------
-- Keybinds
--------------------------------------------------
local function RefreshRowsAndKeybinds()
    PanelCall("Refresh")
    PanelCall("RefreshKeybinds")
end

local function MarkKeybind()
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        keybind   = "UI_SHORTCUT_SECONDARY",
        name      = function()
            if IsMarked(SelectedItem()) then return "Unmark" end
            return "Mark"
        end,
        visible   = function()
            return CanLinkToChat() and SelectedItem() ~= nil
        end,
        callback  = function()
            local item = SelectedItem()
            if not item then return end
            ToggleMark(item)
            RefreshRowsAndKeybinds()
        end,
    }
end

local function LinkKeybind()
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        keybind   = "UI_SHORTCUT_TERTIARY",
        name      = LinkKeybindName,
        visible   = function()
            if not CanLinkToChat() then return false end
            return MarkedCount() > 0 or SelectedItem() ~= nil
        end,
        callback  = function()
            local formatted, sent = BuildLinkText()
            if formatted == "" then return end
            if not PushToChat(formatted) then return end
            for i = 1, #sent do
                RemoveMark(sent[i])
            end
            RefreshRowsAndKeybinds()
        end,
    }
end

--------------------------------------------------
-- Window
--------------------------------------------------
panel = LIB:RegisterSettings({
    name            = PANEL_NAME,
    placement       = "main",
    menuAfter       = "INVENTORY",
    menuTitle       = WHEREISIT_MENU_TITLE_COLORED,
    menuIcon        = ICON_LIST,
    title           = WHEREISIT_MENU_TITLE_COLORED,
    author          = "user|c" .. MENU_COLOR .. "562|r",
    version         = WhereIsIt.version,
    frameColor      = FRAME_GREY,
    titleSuffix     = function() return MarkStatusMessage() end,
    keybinds        = { MarkKeybind(), LinkKeybind() },
    onHidden        = ClearMarks,
    textSize        = function() return Setting("settingsFontSize") end,
    textFont        = function()
        local font = Setting("settingsFont")
        if type(font) ~= "string" or font == "" or font == DEFAULT_FONT then return nil end
        return font
    end,
    windowOpacity   = function() return Setting("settingsOpacity") end,
    rememberPage    = function() return Setting("settingsRemember") == true end,
    lastPage        = function()
        local sv = SV()
        if not sv then return nil end
        if type(sv.settingsLastPage) ~= "table" then sv.settingsLastPage = {} end
        return sv.settingsLastPage
    end,
    accentColor     = function()
        if Setting("settingsHighlight") ~= "Custom" then return nil end
        local c = Setting("settingsHighlightColor")
        if type(c) ~= "table" then return nil end
        return c.r or 1, c.g or 1, c.b or 1
    end,
    options         = BuildOptions,
})

function WhereIsIt.OpenMenu()
    if panel then panel:Open() end
end
