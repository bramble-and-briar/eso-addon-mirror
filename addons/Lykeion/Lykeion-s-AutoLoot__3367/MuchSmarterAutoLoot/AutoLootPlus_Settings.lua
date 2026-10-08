local MSAL = MuchSmarterAutoLoot

MSAL.Settings = {}
local Settings = MSAL.Settings

local LAM2 = LibAddonMenu2
local WM = GetWindowManager()

local db, dbAccount, dbChar
local getDB, setDB
local getIsUsingVanillaAutoLoot, setIsUsingVanillaAutoLoot
local ChatboxLog
local DebugPrint
local ListEntryMatches
local ReorganizeLootWindowButtons
local OnInventoryUpdate
local OnLockpickSuccess
local OnLootClosed
local OnOpenFence
local OnOpenLaunder
local OnOpenStore
local TSCApi
local LCK
local BLIST_TOKEN
local WLIST_TOKEN
local WLIST_JUNK_TOKEN
local MSAL_AUTOLOOT_DISABLE

local function ScheduleContextSettingReload()
    zo_callLater(function()
        ReloadUI("ingame")
    end, GetLatency() + 300)
end

function Settings.SetDB(value)
    db = value
    setDB(value)
end

function Settings.GetIsUsingVanillaAutoLoot()
    return getIsUsingVanillaAutoLoot()
end

function Settings.SetIsUsingVanillaAutoLoot(value)
    setIsUsingVanillaAutoLoot(value)
end

local geodeName = string.gsub(GetItemLinkName("|H1:item:134591:123:1:0:0:0:5:10000:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h"),
    " %(.*%)$", "")

local function trimLastCharUTF8(str)
    if #str == 0 then
        return str
    end

    local multiByte = #str
    while multiByte > 0 do
        local byte = string.byte(str, multiByte)
        if byte < 0x80 or byte > 0xBF then
            return string.sub(str, 1, multiByte - 1)
        end
        multiByte = multiByte - 1
    end
    return ""
end

local function AddDynamicThirdParty(choice, value)
    -- CHAT_ROUTER:AddSystemMessage("ArrayHasItem length "..#arr)
    local resultChoice, resultValue = {}, {}

    for k, v in pairs(choice) do
        resultChoice[k] = v
    end
    for k, v in pairs(value) do
        resultValue[k] = v
    end

    if TamrielTradeCentre then
        table.insert(resultChoice, "TTC")
        table.insert(resultValue, "per ttc")
    end
    if MasterMerchant then
        table.insert(resultChoice, "MM")
        table.insert(resultValue, "per mm")
    end
    if ArkadiusTradeTools then
        table.insert(resultChoice, "ATT")
        table.insert(resultValue, "per att")
    end
    if TSCApi then
        table.insert(resultChoice, "TSC")
        table.insert(resultValue, "per tsc")
    end
    return resultChoice, resultValue
end

local function AddDynamicThirdPartyOption(choice, value)
    -- CHAT_ROUTER:AddSystemMessage("ArrayHasItem length "..#arr)
    local resultChoice, resultValue = {}, {}

    for k, v in pairs(choice) do
        resultChoice[k] = v
    end
    for k, v in pairs(value) do
        resultValue[k] = v
    end

    if TamrielTradeCentre or MasterMerchant or ArkadiusTradeTools or TSCApi then
        table.insert(resultChoice, zo_strformat(GetString(MSAL_USE), GetString(MSAL_THIRD_PARTY)))
        table.insert(resultValue, "per third")
    end
    return resultChoice, resultValue
end

local SV_NAME = 'MSAL_VARS'
local SV_VER = 1

local defaults = {
    latestMajorUpdateVersion = "",
    latestMinorUpdateVersion = nil,
    lastStartup = "",
    never3rdPartyWarning = false,
    enabled = true,
    useAccountWide = true,
    debugMode = false,
    printLootThreshold = 0,
    useIconsInLog = false,
    closeLootWindow = false,
    unwantedItemsDisposer = "none",
    cleanBagContainerLeftovers = false,
    gearDisposer = "none",
    deconThreshold = 0,
    junkThreshold = 0,
    autoSellJunk = false,
    autoLaunder = false,
    skipDialog = false,
    printDisposeThreshold = 0,
    alwaysLootStackable = false,
    autoUnboxContainer = "none",
    autoUnboxUnopened = false,
    autoUnboxFish = false,
    autoUnboxGeode = false,
    loginReminder = true,
    deconLogEnabled = true,
    sellJunkLogEnabled = true,
    stolenRule = "never loot",
    stolenTreasureThreshold = 0,
    autoBind = false,
    autoDisposeAfterBind = false,
    blacklist = {},
    whitelist = {},
    wlistJunk = {},
    hostNativeLootAll = true,
    addDestroyButton = false,
    contextMenuEnabled = true,
    contextJunkingEnabled = false,
    neverAutolootWarning = false,
    aprilFoolsTest = false,
    addJunkingButton = true,
    legacyMode = false,

    filters = {
        set = "always loot",
        unresearched = "always loot",
        rareTrait = "always loot",
        ornate = "loot and junk",
        intricate = "always loot",
        clothingIntricate = "always loot",
        blacksmithingIntricate = "always loot",
        woodworkingIntricate = "always loot",
        jewelryIntricate = "always loot",
        intricateAutoDecon = false,
        companionGears = "always loot",
        craftedGears = "always loot",
        weapons = "never loot",
        armors = "never loot",
        jewelry = "never loot",

        blacksmithingMaterials = "always loot",
        clothingMaterials = "always loot",
        woodworkingMaterials = "always loot",
        jewelryCraftingMaterials = "always loot",
        refineMaterials = "always loot",
        traitMaterials = "always loot",
        styleMaterials = "always loot",
        runes = "always loot",
        alchemy = "always loot",
        ingredients = "always loot",
        furnishingMaterials = "always loot",
        ink = "always loot",

        lootCurrencies = true,

        thirdParty = nil,
        thirdPartyMinValue = 5000,
        recipesAlwaysLootUnknown = true,
        recipesAlwaysLootAnyCharUnknown = true,

        questItems = "always loot",
        crownItems = "always loot",
        containers = "always loot",
        unopened = "always loot",
        writs = "always loot",
        survey = "always loot",
        treasureMaps = "always loot",
        leads = "always loot",
        skillScrolls = "always loot",
        soulGems = "always loot",
        recipes = "always loot",
        glyphs = "always loot",
        treasures = "loot and junk",
        potions = "always loot",
        foodAndDrink = "always loot",
        poisons = "always loot",
        costumes = "always loot",
        fishingBaits = "always loot",
        lockpicks = "always loot",
        repairKits = "always loot",
        tools = "always loot",
        allianceWarConsumables = "always loot",
        furniture = "always loot",
        trophy = "always loot",
        trash = "loot and junk",
        scribing = "always loot",
        scribingAutoMark = false,
        styleMaterials3rd = "use default",
        styleMaterials3rdPriceThreshold = 500,
        styleMaterials3rdGearLooting = false,
        styleMaterials3rdGearAutoDecon = false
    }
}

function Settings.InitializeSavedVariables()
    local legacySV = nil
    local hasLegacySV = false
    local worldName = GetWorldName()
    if MSAL_VARS and MSAL_VARS.converted530 == nil then
        if LibSavedVars ~= nil then
            if MSAL_VARS and MSAL_VARS[worldName] and MSAL_VARS[worldName][GetDisplayName()] and
                MSAL_VARS[worldName][GetDisplayName()]["$AccountWide"] then
                legacySV = MSAL_VARS[worldName][GetDisplayName()]["$AccountWide"]["Account"]
            end
        else
            if MSAL_VARS and MSAL_VARS["Default"] and MSAL_VARS["Default"][GetDisplayName()] and
                MSAL_VARS["Default"][GetDisplayName()]["$AccountWide"] then
                legacySV = MSAL_VARS["Default"][GetDisplayName()]["$AccountWide"]
            end
        end

        if legacySV then
            hasLegacySV = true
        end
    end

    if hasLegacySV then
        legacySV.useAccountWide = true
        dbAccount = ZO_SavedVars:NewAccountWide(SV_NAME, 1, nil, legacySV, worldName)
        dbChar = ZO_SavedVars:NewCharacterIdSettings(SV_NAME, 1, nil, legacySV, worldName)
    else
        dbAccount = ZO_SavedVars:NewAccountWide(SV_NAME, 1, nil, defaults, worldName)
        dbChar = ZO_SavedVars:NewCharacterIdSettings(SV_NAME, 1, nil, defaults, worldName)
    end
    MSAL_VARS.converted530 = true
    -- make sure the account-wide blacklist won't be tainted by char blacklist on load
    dbChar.blacklist = dbAccount.blacklist
    -- ensure new SV fields exist on legacy save data
    dbAccount.wlistJunk = dbAccount.wlistJunk or {}
    dbChar.wlistJunk = dbChar.wlistJunk or {}
    dbAccount.contextJunkingEnabled = dbAccount.contextJunkingEnabled == true
    dbChar.contextJunkingEnabled = dbChar.contextJunkingEnabled == true
    -- carried over from the per-character save so the major update notice does not show again
    if (dbAccount.latestMajorUpdateVersion or "") == "" then
        dbAccount.latestMajorUpdateVersion = dbChar.latestMajorUpdateVersion or ""
    end

    if dbChar.useAccountWide then
        db = dbAccount
    else
        db = dbChar
    end

    return dbAccount, dbChar, db
end

-- the loot path compares numeric options with numbers, but older saves can hold them as strings or nil
function Settings.CoerceNumericDefaults(savedTable)
    local function coerce(saved, defs)
        for key, defaultValue in pairs(defs) do
            local value = saved[key]
            if type(defaultValue) == "table" then
                if type(value) == "table" then
                    coerce(value, defaultValue)
                end
            elseif type(defaultValue) == "number" and type(value) ~= "number" then
                saved[key] = tonumber(value) or defaultValue
            end
        end
    end
    coerce(savedTable, defaults)
end

function Settings.Initialize(args)
    getDB, setDB = args.getDB, args.setDB
    db = args.getDB()
    dbAccount, dbChar = args.dbAccount, args.dbChar
    getIsUsingVanillaAutoLoot, setIsUsingVanillaAutoLoot = args.getIsUsingVanillaAutoLoot, args.setIsUsingVanillaAutoLoot
    ChatboxLog = args.ChatboxLog
    DebugPrint = args.DebugPrint
    ListEntryMatches = args.ListEntryMatches
    ReorganizeLootWindowButtons = args.ReorganizeLootWindowButtons
    OnInventoryUpdate = args.OnInventoryUpdate
    OnLockpickSuccess = args.OnLockpickSuccess
    OnLootClosed = args.OnLootClosed
    OnOpenFence = args.OnOpenFence
    OnOpenLaunder = args.OnOpenLaunder
    OnOpenStore = args.OnOpenStore
    TSCApi = args.TSCApi
    LCK = args.LCK
    BLIST_TOKEN = args.BLIST_TOKEN
    WLIST_TOKEN = args.WLIST_TOKEN
    WLIST_JUNK_TOKEN = args.WLIST_JUNK_TOKEN
    MSAL_AUTOLOOT_DISABLE = args.MSAL_AUTOLOOT_DISABLE

    local panelData = {
        type = "panel",
        name = GetString(MSAL_PANEL_NAME),
        displayName = GetString(MSAL_PANEL_DISPLAYNAME),
        author = "|c215895" .. MSAL.author .. "|r",
        version = "|ccc922f" .. MSAL.version .. "|r",
        slashCommand = "/lal",
        registerForRefresh = true,
        registerForDefaults = true
    }

    local logQualityThresholdChoices = {
        GetItemQualityColor(ITEM_DISPLAY_QUALITY_TRASH):Colorize(GetString(MSAL_NO_LOG)),
        GetItemQualityColor(ITEM_DISPLAY_QUALITY_TRASH):Colorize(GetString(SI_ITEMQUALITY0)),
        GetItemQualityColor(ITEM_DISPLAY_QUALITY_NORMAL):Colorize(GetString(SI_ITEMQUALITY1)),
        GetItemQualityColor(ITEM_DISPLAY_QUALITY_MAGIC):Colorize(GetString(SI_ITEMQUALITY2)),
        GetItemQualityColor(ITEM_DISPLAY_QUALITY_ARCANE):Colorize(GetString(SI_ITEMQUALITY3)),
        GetItemQualityColor(ITEM_DISPLAY_QUALITY_ARTIFACT):Colorize(GetString(SI_ITEMQUALITY4)),
        GetItemQualityColor(ITEM_DISPLAY_QUALITY_LEGENDARY):Colorize(GetString(SI_ITEMQUALITY5))
    }
    local logQualityThresholdChoicesValues = {
        6,
        0,
        1,
        2,
        3,
        4,
        5
    }
    local booleanChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local booleanChoicesValues = {
        "always loot",
        "never loot"
    }
    local junkChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        GetString(SI_INTERACT_OPTION_LOOT) .. " & " .. GetString(SI_ITEM_ACTION_MARK_AS_JUNK),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local junkChoicesValues = {
        "always loot",
        "loot and junk",
        "never loot"
    }
    local materialChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        zo_strformat(GetString(MSAL_ONLY_CP160_AND_RAW), GetString(SI_ITEMTYPE63)),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local materialChoicesValues = {
        "always loot",
        "only cp160 and raw",
        "never loot"
    }
    local styleMatChioces = {
        GetString(MSAL_USE_DEFAULT)
    }
    local styleMatChiocesValues = {
        "use default"
    }
    local deconChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        GetString(SI_INTERACT_OPTION_LOOT) .. " & " .. GetString(MSAL_REGISTER_FOR_DECON),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local deconChoicesValues = {
        "always loot",
        "loot and decon",
        "never loot"
    }
    local stolenChoices = {
        GetString(MSAL_FOLLOW_RULES),
        GetString(MSAL_DONT_STEAL),
        GetString(MSAL_DONT_STEAL_STRICT)
    }
    local stolenChoicesValues = {
        "follow",
        "never loot",
        "never loot strict"
    }
    local unboxChoices = {
        GetString(MSAL_UNBOX_CONTAINER_ALL),
        GetString(MSAL_UNBOX_CONTAINER_BOUND),
        GetString(MSAL_UNBOX_CONTAINER_NONE)
    }
    local unboxChoicesValues = {
        "all",
        "bound",
        "none"
    }
    local disposerChoices = {
        GetString(MSAL_LEAVE_BEHIND),
        GetString(SI_ITEM_ACTION_MARK_AS_JUNK),
        GetString(SI_ITEM_ACTION_DESTROY)
    }
    local disposerChoicesValues = {
        "none",
        "junk",
        "destroy"
    }
    local gearDisposerChoices = {
        GetString(MSAL_LEAVE_BEHIND),
        GetString(SI_ITEM_ACTION_MARK_AS_JUNK),
        GetString(MSAL_REGISTER_FOR_DECON),
        GetString(MSAL_REGISTER_FOR_DECON_AND_JUNK),
        GetString(SI_ITEM_ACTION_DESTROY)
    }
    local gearDisposerChoicesValues = {
        "none",
        "junk",
        "decon",
        "decon and junk",
        "destroy"
    }
    local deconThresholdChoices = {
        GetString(MSAL_DECON_NO_THRESHOLD),
        GetItemQualityColor(ITEM_DISPLAY_QUALITY_MAGIC):Colorize(GetString(SI_ITEMQUALITY2)),
        GetItemQualityColor(ITEM_DISPLAY_QUALITY_ARCANE):Colorize(GetString(SI_ITEMQUALITY3)),
        GetItemQualityColor(ITEM_DISPLAY_QUALITY_ARTIFACT):Colorize(GetString(SI_ITEMQUALITY4)),
        GetItemQualityColor(ITEM_DISPLAY_QUALITY_LEGENDARY):Colorize(GetString(SI_ITEMQUALITY5))
    }
    local deconThresholdChoicesValues = {
        0,
        2,
        3,
        4,
        5
    }
    local setChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        zo_strformat(GetString(MSAL_ONLY), GetString(SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED)),
        GetString(SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED) .. " & " .. GetString(SI_ITEMTYPEDISPLAYCATEGORY3),
        GetString(SI_ITEMTYPEDISPLAYCATEGORY1) .. " & " .. GetString(SI_ITEMTYPEDISPLAYCATEGORY3),
        zo_strformat(GetString(MSAL_ONLY), GetString(SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_UNLOCKED)),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local setChoicesValues = {
        "always loot",
        "only uncollected",
        "uncollected and jewelry",
        "weapon and jewelry",
        "only collected",
        "never loot"
    }
    local unopenedChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        GetString(MSAL_TYPE_BASED),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local unopenedChoicesValues = {
        "always loot",
        "type based",
        "never loot"
    }
    local intricateChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        GetString(SI_INTERACT_OPTION_LOOT) .. " & " .. GetString(MSAL_REGISTER_FOR_DECON),
        GetString(MSAL_TYPE_BASED),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local intricateChoicesValues = {
        "always loot",
        "loot and decon",
        "type based",
        "never loot"
    }
    local styleMaterialsChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        GetString(MSAL_ONLY_NON_RACIAL),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local styleMaterialsChoicesValues = {
        "always loot",
        "only non-racial",
        "never loot"
    }
    local traitMaterialsChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        zo_strformat(GetString(MSAL_ONLY),
            GetString(MSAL_RARE_TRAIT_TOOLTIP) .. GetString(MSAL_SPACE) .. GetString(SI_GAMEPADITEMCATEGORY30)),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local traitMaterialsChoicesValues = {
        "always loot",
        "only nirnhoned",
        "never loot"
    }
    local soulGemsChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        zo_strformat(GetString(MSAL_ONLY), GetString(SI_SOUL_GEM_FILLED)),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local soulGemsChoicesValues = {
        "always loot",
        "only filled",
        "never loot"
    }
    local furnitureChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        zo_strformat(GetString(MSAL_ONLY), GetString(SI_HOUSINGFURNITUREBOUNDFILTER2)),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local furnitureChoicesValues = {
        "always loot",
        "only unbound",
        "never loot"
    }
    local foodChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        GetString(MSAL_ONLY_EXP_BOOSTER),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local foodChoicesValues = {
        "always loot",
        "only exp booster",
        "never loot"
    }
    local ingredientChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        zo_strformat(GetString(MSAL_ONLY_OR_HIGHER),
            GetItemQualityColor(ITEM_DISPLAY_QUALITY_ARTIFACT):Colorize(GetString(SI_ITEMQUALITY4))),
        zo_strformat(GetString(MSAL_ONLY),
            GetItemQualityColor(ITEM_DISPLAY_QUALITY_LEGENDARY):Colorize(GetString(SI_ITEMQUALITY5))),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local ingredientChoicesValues = {
        "always loot",
        "only purple and gold ingredients",
        "only gold ingredients",
        "never loot"
    }
    local enchantingChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        zo_strformat(GetString(MSAL_ONLY),
            GetItemLinkName("|H1:item:45854:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h") .. " & " ..
                GetItemLinkName("|H1:item:68342:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h") .. " & " ..
                GetItemLinkName("|H1:item:166045:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local enchantingChoicesValues = {
        "always loot",
        "only kuta hakeijo",
        "never loot"
    }
    local potionsChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        GetString(MSAL_ONLY_BASTIAN),
        GetString(MSAL_ONLY_NON_BASTIAN),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local potionsChoicesValues = {
        "always loot",
        "only bastian",
        "only non-bastian",
        "never loot"
    }
    local qualityPurpleChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        zo_strformat(GetString(MSAL_ONLY_OR_HIGHER),
            GetItemQualityColor(ITEM_DISPLAY_QUALITY_ARCANE):Colorize(GetString(SI_ITEMQUALITY3))),
        zo_strformat(GetString(MSAL_ONLY_OR_HIGHER),
            GetItemQualityColor(ITEM_DISPLAY_QUALITY_ARTIFACT):Colorize(GetString(SI_ITEMQUALITY4))),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local qualityPurpleChoicesValues = {
        "always loot",
        "only blue",
        "only purple",
        "never loot"
    }
    local qualityBlueToGoldChoices = {
        GetString(MSAL_ALWAYS_LOOT),
        zo_strformat(GetString(MSAL_ONLY_OR_HIGHER),
            GetItemQualityColor(ITEM_DISPLAY_QUALITY_ARCANE):Colorize(GetString(SI_ITEMQUALITY3))),
        zo_strformat(GetString(MSAL_ONLY_OR_HIGHER),
            GetItemQualityColor(ITEM_DISPLAY_QUALITY_ARTIFACT):Colorize(GetString(SI_ITEMQUALITY4))),
        zo_strformat(GetString(MSAL_ONLY),
            GetItemQualityColor(ITEM_DISPLAY_QUALITY_LEGENDARY):Colorize(GetString(SI_ITEMQUALITY5))),
        GetString(MSAL_LEAVE_TO_DISPOSER)
    }
    local qualityBlueToGoldChoicesValues = {
        "always loot",
        "only blue",
        "only purple",
        "only gold",
        "never loot"
    }
    local qualityGreenToPurpleChoices = {
        GetString(MSAL_DECON_NO_THRESHOLD),
        zo_strformat(GetString(MSAL_ONLY_OR_HIGHER),
            GetItemQualityColor(ITEM_DISPLAY_QUALITY_MAGIC):Colorize(GetString(SI_ITEMQUALITY2))),
        zo_strformat(GetString(MSAL_ONLY_OR_HIGHER),
            GetItemQualityColor(ITEM_DISPLAY_QUALITY_ARCANE):Colorize(GetString(SI_ITEMQUALITY3))),
        zo_strformat(GetString(MSAL_ONLY_OR_HIGHER),
            GetItemQualityColor(ITEM_DISPLAY_QUALITY_ARTIFACT):Colorize(GetString(SI_ITEMQUALITY4))),
    }
    local qualityGreenToPurpleChoicesValues = {
        ITEM_DISPLAY_QUALITY_TRASH,
        ITEM_DISPLAY_QUALITY_MAGIC,
        ITEM_DISPLAY_QUALITY_ARCANE,
        ITEM_DISPLAY_QUALITY_ARTIFACT,
    }

    local dynamicBooleanChoices, dynamicBooleanChoicesValues =
        AddDynamicThirdPartyOption(booleanChoices, booleanChoicesValues)
    local dynamicStyleMatChoices, dynamicStyleMatChoicesValues =
        AddDynamicThirdPartyOption(styleMatChioces, styleMatChiocesValues)
    local dynamicfurnitureChoices, dynamicfurnitureChoicesValues =
        AddDynamicThirdPartyOption(furnitureChoices, furnitureChoicesValues)

    local dynamicThirdPartyChoices, dynamicThirdPartyChoicesValues = AddDynamicThirdParty({}, {})

    local function getListChoices(token, includePlaceholder)
        local list, title
        if token == BLIST_TOKEN then
            list = db.blacklist
            title = GetString(MSAL_BLIST)
        elseif token == WLIST_TOKEN then
            list = db.whitelist
            title = GetString(MSAL_WLIST)
        elseif token == WLIST_JUNK_TOKEN then
            list = db.wlistJunk
            title = GetString(MSAL_WLIST) .. " (" .. GetString(SI_ITEM_ACTION_MARK_AS_JUNK) .. ")"
        end

        local temp = {}
        local ids = {}
        if includePlaceholder ~= false then
            table.insert(temp, "-------- " .. title .. " --------")
            table.insert(ids, 0)
        elseif next(list) == nil then
            -- Empty console list: show a placeholder instead of the last removed item.
            table.insert(temp, GetString(MSAL_LIST_EMPTY))
            table.insert(ids, 0)
        end
        for _, entry in pairs(list) do
            table.insert(temp, LocalizeString("<<1>>", GetItemLinkName(entry)))
            table.insert(ids, GetItemLinkItemId(entry))
        end
        return temp, ids
    end

    local function getListConfig(token)
        if token == BLIST_TOKEN then
            return {
                controlName = "MSAL_AddBList",
                removeControlName = "MSAL_RemoveBList",
                listName = GetString(MSAL_BLIST),
                list = db.blacklist or {}
            }
        elseif token == WLIST_TOKEN then
            return {
                controlName = "MSAL_AddWList",
                removeControlName = "MSAL_RemoveWList",
                listName = GetString(MSAL_WLIST),
                list = db.whitelist or {}
            }
        elseif token == WLIST_JUNK_TOKEN then
            return {
                controlName = "MSAL_AddWListJunk",
                removeControlName = "MSAL_RemoveWListJunk",
                listName = GetString(MSAL_WLIST) .. " (" .. GetString(SI_ITEM_ACTION_MARK_AS_JUNK) .. ")",
                list = db.wlistJunk or {}
            }
        end
    end
    
    local function refreshRemoveDropdown(token)
        local ctrl = WM:GetControlByName(getListConfig(token).removeControlName)
        if ctrl then
            local choices, choicesValues = getListChoices(token)
            ctrl:UpdateChoices(choices, choicesValues)
        end
    end

    function MSAL.ContextAddToList(link, token)
        if not link or link == "" or GetItemLinkItemId(link) == 0 then
            if token == WLIST_TOKEN or token == WLIST_JUNK_TOKEN then
                ChatboxLog(GetString(MSAL_CONTEXT_EMPTY_LINK))
            end
            return
        end
        local cfg = getListConfig(token)
        local itemId = GetItemLinkItemId(link)

        local listTokens = {
            BLIST_TOKEN,
            WLIST_TOKEN,
            WLIST_JUNK_TOKEN
        }
        for _, currentToken in ipairs(listTokens) do
            if currentToken ~= token then
                local otherCfg = getListConfig(currentToken)
                for i = #otherCfg.list, 1, -1 do
                    if ListEntryMatches(otherCfg.list[i], link) then
                        local removedLink = otherCfg.list[i]
                        ChatboxLog(string.format(GetString(MSAL_LIST_REMOVE), LocalizeString("<<1>>", GetItemLinkName(removedLink)),
                            otherCfg.listName))
                        table.remove(otherCfg.list, i)
                        local otherCtrl = WM:GetControlByName(otherCfg.removeControlName)
                        refreshRemoveDropdown(currentToken)
                    end
                end
            end
            
        end
        for _, v in pairs(cfg.list) do
            if ListEntryMatches(v, link) then
                ChatboxLog(string.format(GetString(MSAL_LIST_ADD), LocalizeString("<<1>>", GetItemLinkName(link)), cfg.listName))
                return
            end
        end

        table.insert(cfg.list, link)
        ChatboxLog(string.format(GetString(MSAL_LIST_ADD), LocalizeString("<<1>>", GetItemLinkName(link)), cfg.listName))
        if token == BLIST_TOKEN and Settings.GetIsUsingVanillaAutoLoot() then
            local disableLink = ZO_LinkHandler_CreateLinkWithoutBrackets(GetString(MSAL_AUTOLOOT_DISABLE_TEXT), nil,
                MSAL_AUTOLOOT_DISABLE)
            ChatboxLog(zo_strformat(GetString(MSAL_BLIST_AUTOLOOT_WARNING), disableLink))
        end
        refreshRemoveDropdown(token)

        local backpackTouched = false
        for bagSlot = 1, GetBagSize(BAG_BACKPACK) do
            local bagLink = GetItemLink(BAG_BACKPACK, bagSlot)
            if itemId == GetItemLinkItemId(bagLink) then
                if token == WLIST_TOKEN then
                    if IsItemJunk(BAG_BACKPACK, bagSlot) then
                        SetItemIsJunk(BAG_BACKPACK, bagSlot, false)
                        backpackTouched = true
                    end
                elseif token == WLIST_JUNK_TOKEN then
                    if not IsItemJunk(BAG_BACKPACK, bagSlot) and CanItemBeMarkedAsJunk(BAG_BACKPACK, bagSlot) then
                        SetItemIsJunk(BAG_BACKPACK, bagSlot, true)
                        backpackTouched = true
                    end
                end
            end
        end
        if backpackTouched then
            if token == WLIST_TOKEN then
                ChatboxLog(string.format(GetString(MSAL_BACKPACK_UNMARK_FOR_LIST),
                    LocalizeString("<<1>>", GetItemLinkName(link)), cfg.listName))
            elseif token == WLIST_JUNK_TOKEN then
                ChatboxLog(string.format(GetString(MSAL_BACKPACK_MARK_FOR_LIST),
                    LocalizeString("<<1>>", GetItemLinkName(link)), cfg.listName))
            end
        end
        CALLBACK_MANAGER:FireCallbacks("MSAL-RefreshListsDropmenu")
    end

    local function addListItem(link, token)
        if link == nil or link == "" then
            return
        end
        local cfg = getListConfig(token)

        local inputLinkItemId = GetItemLinkItemId(link)
        if inputLinkItemId == 0 then
            ChatboxLog(GetString(SI_STOREITEMRESULT1))
            WM:GetControlByName(cfg.controlName).editbox:SetText("")
            return
        end

        local listTokens = {
            BLIST_TOKEN,
            WLIST_TOKEN,
            WLIST_JUNK_TOKEN
        }
        for _, currentToken in ipairs(listTokens) do
            if currentToken ~= token then
                local otherCfg = getListConfig(currentToken)
                for i = #otherCfg.list, 1, -1 do
                    if ListEntryMatches(otherCfg.list[i], link) then
                        local removedLink = otherCfg.list[i]
                        ChatboxLog(string.format(GetString(MSAL_LIST_REMOVE), LocalizeString("<<1>>", GetItemLinkName(removedLink)),
                            otherCfg.listName))
                        table.remove(otherCfg.list, i)
                        refreshRemoveDropdown(currentToken)
                    end
                end
            end
        end

        -- Check if item already exists in current list
        for _, v in pairs(cfg.list) do
            if ListEntryMatches(v, link) then
                ChatboxLog(string.format(GetString(MSAL_LIST_ALREADY_EXIST), LocalizeString("<<1>>", GetItemLinkName(link)), cfg.listName))
                WM:GetControlByName(cfg.controlName).editbox:SetText("")
                return
            end
        end
        table.insert(cfg.list, link)

        if token == WLIST_TOKEN then
            for bagSlot = 1, GetBagSize(BAG_BACKPACK) do
                local itemLink = GetItemLink(BAG_BACKPACK, bagSlot)
                if inputLinkItemId == GetItemLinkItemId(itemLink) then
                    if IsItemJunk(BAG_BACKPACK, bagSlot) then
                        SetItemIsJunk(BAG_BACKPACK, bagSlot, false)
                        ChatboxLog(GetString(MSAL_UNMARK_WHITELIST))
                    end
                end
            end
        elseif token == WLIST_JUNK_TOKEN then
            for bagSlot = 1, GetBagSize(BAG_BACKPACK) do
                local itemLink = GetItemLink(BAG_BACKPACK, bagSlot)
                if inputLinkItemId == GetItemLinkItemId(itemLink) then
                    if not IsItemJunk(BAG_BACKPACK, bagSlot) and CanItemBeMarkedAsJunk(BAG_BACKPACK, bagSlot) then
                        SetItemIsJunk(BAG_BACKPACK, bagSlot, true)
                        ChatboxLog(GetString(SI_ITEM_ACTION_MARK_AS_JUNK) .. GetString(MSAL_SPACE) .. itemLink)
                    end
                end
            end
        elseif token == BLIST_TOKEN then
            if db.useAccountWide then
                dbChar.blacklist = dbAccount.blacklist
            else
                dbAccount.blacklist = dbChar.blacklist
            end
        end

        ChatboxLog(string.format(GetString(MSAL_LIST_ADD), LocalizeString("<<1>>", GetItemLinkName(link)), cfg.listName))
        if token == BLIST_TOKEN and Settings.GetIsUsingVanillaAutoLoot() then
            local disableLink = ZO_LinkHandler_CreateLinkWithoutBrackets(GetString(MSAL_AUTOLOOT_DISABLE_TEXT), nil,
                MSAL_AUTOLOOT_DISABLE)
            ChatboxLog(zo_strformat(GetString(MSAL_BLIST_AUTOLOOT_WARNING), disableLink))
        end

        -- WM:GetControlByName(cfg.controlName).editbox:SetText("")
        -- WM:GetControlByName(cfg.removeControlName):UpdateChoices(getListChoices(token))

        CALLBACK_MANAGER:FireCallbacks("MSAL-RefreshListsDropmenu")
    end

    local function removeListItem(itemId, token)
        local cfg = getListConfig(token)

        if not itemId or itemId == 0 then
            local ctrl = WM:GetControlByName(cfg.removeControlName)
            if ctrl and ctrl.dropdown then
                ctrl.dropdown:SetSelectedItem(nil)
            end
            return
        else
            for i = #cfg.list, 1, -1 do
                if GetItemLinkItemId(cfg.list[i]) == itemId then
                    ChatboxLog(string.format(GetString(MSAL_LIST_REMOVE), LocalizeString("<<1>>", GetItemLinkName(cfg.list[i])), cfg.listName))
                    table.remove(cfg.list, i)
                end
            end

            -- For junk whitelist, unmark matching items in backpack
            if token == WLIST_JUNK_TOKEN then
                for bagSlot = 1, GetBagSize(BAG_BACKPACK) do
                    local itemLink = GetItemLink(BAG_BACKPACK, bagSlot)
                    if tostring(GetItemLinkItemId(itemLink)) == itemid then
                        if IsItemJunk(BAG_BACKPACK, bagSlot) then
                            SetItemIsJunk(BAG_BACKPACK, bagSlot, false)
                            ChatboxLog(GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK) .. GetString(MSAL_SPACE) .. itemLink)
                        end
                    end
                end
            end
        end

        if token == BLIST_TOKEN then
            if db.useAccountWide then
                dbChar.blacklist = dbAccount.blacklist
            else
                dbAccount.blacklist = dbChar.blacklist
            end
        end

        -- WM:GetControlByName(cfg.removeControlName).dropdown:SetSelectedItem(nil)
        -- WM:GetControlByName(cfg.removeControlName):UpdateChoices(getListChoices(token))
        CALLBACK_MANAGER:FireCallbacks("MSAL-RefreshListsDropmenu")
    end

    local optionsData = {
        {
            type = "description",
            text = GetString(MSAL_HELP_TITLE),
            width = "full"
        },
        {
            type = "checkbox",
            name = GetString(MSAL_USE_ACCOUNT_WIDE),
            tooltip = GetString(MSAL_USE_ACCOUNT_WIDE_TOOLTIP),
            getFunc = function()
                return dbChar.useAccountWide
            end,
            setFunc = function(value)
                dbChar.useAccountWide = value
                if dbChar.useAccountWide then
                    Settings.SetDB(dbAccount)
                else
                    Settings.SetDB(dbChar)
                end
                if not ZO_IsConsoleOrGameCoreUI() then
                    -- local ctrl = WM:GetControlByName("MSAL_RemoveBList")
                    -- if ctrl then ctrl:UpdateChoices(getListChoices(BLIST_TOKEN)) end
                    -- ctrl = WM:GetControlByName("MSAL_RemoveWList")
                    -- if ctrl then ctrl:UpdateChoices(getListChoices(WLIST_TOKEN)) end
                    -- ctrl = WM:GetControlByName("MSAL_RemoveWListJunk")
                    -- if ctrl then ctrl:UpdateChoices(getListChoices(WLIST_JUNK_TOKEN)) end
                    CALLBACK_MANAGER:FireCallbacks("MSAL-RefreshListsDropmenu")
                end
            end,
            default = true
        },
        {
            type = "checkbox",
            name = GetString(MSAL_ENABLE_MSAL),
            keybind = "UI_SHORTCUT_PRIMARY",
            reference = "MSAL_Enable",
            getFunc = function()
                return db.enabled
            end,
            setFunc = function(value)
                db.enabled = value
                if db.enabled == true then
                    if not ZO_IsConsoleOrGameCoreUI() then
                        SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT, 0)
                        SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AOE_LOOT, 1)
                        SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_ADD_TO_CRAFT_BAG, 1)
                    else
                        Settings.SetIsUsingVanillaAutoLoot(tonumber(GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT)))
                        if (Settings.GetIsUsingVanillaAutoLoot()) then
                            ChatboxLog(zo_strformat(GetString(MSAL_CONSOLE_ENABLED_REMINDER),
                                GetString(SI_GAMEPAD_OPTIONS_MENU), GetString(SI_SETTINGSYSTEMPANEL4),
                                GetString(SI_GAMEPLAY_OPTIONS_ITEMS)))
                        end
                    end
                    EVENT_MANAGER:RegisterForEvent("MSAL_LOOT_UPDATED", EVENT_LOOT_UPDATED, MSAL.OnLootUpdatedThrottled)
                    EVENT_MANAGER:RegisterForEvent("MSAL_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
                        OnInventoryUpdate)
                    EVENT_MANAGER:AddFilterForEvent("MSAL_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
                        REGISTER_FILTER_IS_NEW_ITEM, true)
                    EVENT_MANAGER:AddFilterForEvent("MSAL_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
                        REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
                    EVENT_MANAGER:AddFilterForEvent("MSAL_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
                        REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
                    EVENT_MANAGER:RegisterForEvent("MSAL_LOOT_CLOSED", EVENT_LOOT_CLOSED, OnLootClosed)
                    EVENT_MANAGER:RegisterForEvent("MSAL_OPEN_STORE", EVENT_OPEN_STORE, OnOpenStore)
                    EVENT_MANAGER:RegisterForEvent("MSAL_OPEN_FENCE", EVENT_OPEN_FENCE, OnOpenFence)
                    EVENT_MANAGER:RegisterForEvent("MSAL_OPEN_LAUNDER", EVENT_OPEN_FENCE, OnOpenLaunder)
                    EVENT_MANAGER:RegisterForEvent("MSAL_LOCKPICK_SUCCESS", EVENT_LOCKPICK_SUCCESS, OnLockpickSuccess)
                    -- EVENT_MANAGER:RegisterForEvent("MSAL_INTERACT_CHECK", EVENT_CLIENT_INTERACT_RESULT, OnInteractResult)
                    -- EVENT_MANAGER:RegisterForEvent("MSAL_INTERACT_CANCEL", EVENT_PENDING_INTERACTION_CANCELLED,
                    --     OnInteractCancelled)
                else
                    EVENT_MANAGER:UnregisterForEvent("MSAL_LOOT_UPDATED", EVENT_LOOT_UPDATED)
                    EVENT_MANAGER:UnregisterForEvent("MSAL_SLOT_UPDATE", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
                    EVENT_MANAGER:UnregisterForEvent("MSAL_LOOT_CLOSED", EVENT_LOOT_CLOSED)
                    EVENT_MANAGER:UnregisterForEvent("MSAL_OPEN_STORE", EVENT_OPEN_STORE)
                    EVENT_MANAGER:UnregisterForEvent("MSAL_OPEN_FENCE", EVENT_OPEN_FENCE)
                    EVENT_MANAGER:UnregisterForEvent("MSAL_OPEN_LAUNDER", EVENT_OPEN_FENCE)
                    EVENT_MANAGER:UnregisterForEvent("MSAL_LOCKPICK_SUCCESS", EVENT_LOCKPICK_SUCCESS)
                    -- EVENT_MANAGER:UnregisterForEvent("MSAL_INTERACT_CHECK", EVENT_CLIENT_INTERACT_RESULT)
                    -- EVENT_MANAGER:UnregisterForEvent("MSAL_INTERACT_CANCEL", EVENT_PENDING_INTERACTION_CANCELLED)
                end
            end,
            default = defaults.enabled
        },
        {
            type = "submenu",
            name = GetString(MSAL_GENERAL_SETTINGS),
            controls = {
                {
                    type = "checkbox",
                    name = GetString(MSAL_AUTOLOOT_CURRENCY),
                    tooltip = GetString(MSAL_AUTOLOOT_CURRENCY_TOOLTIP),
                    getFunc = function()
                        return db.filters.lootCurrencies
                    end,
                    setFunc = function(value)
                        db.filters.lootCurrencies = value
                    end,
                    default = defaults.filters.lootCurrencies
                },
                {
                    type = "checkbox",
                    name = GetString(MSAL_LOOT_EXISTING_STACKABLE),
                    tooltip = GetString(MSAL_LOOT_EXISTING_STACKABLE_TOOLTIP),
                    getFunc = function()
                        return db.alwaysLootStackable
                    end,
                    setFunc = function(value)
                        db.alwaysLootStackable = value
                    end,
                    default = defaults.alwaysLootStackable
                },
                {
                    type = "checkbox",
                    name = GetString(MSAL_CLOSE_LOOT_WINDOW),
                    tooltip = GetString(MSAL_CLOSE_LOOT_WINDOW_TOOLTIP),
                    getFunc = function()
                        return db.closeLootWindow
                    end,
                    setFunc = function(value)
                        db.closeLootWindow = value
                    end,
                    default = defaults.closeLootWindow
                },
                {
                    type = "checkbox",
                    name = GetString(MSAL_LEGACY_MODE),
                    tooltip = GetString(MSAL_LEGACY_MODE_TOOLTIP),
                    getFunc = function()
                        return db.legacyMode
                    end,
                    setFunc = function(value)
                        db.legacyMode = value
                    end,
                    default = defaults.legacyMode
                },
                {
                    type = "header",
                    name = "|c999999 / " .. GetString(MSAL_CHATBOX_LOG) .. "|r",
                    width = "full"
                },
                {
                    type = "checkbox",
                    name = GetString(MSAL_LOGIN_REMINDER),
                    tooltip = GetString(MSAL_LOGIN_REMINDER_TOOLTIP),
                    getFunc = function()
                        return db.loginReminder
                    end,
                    setFunc = function(value)
                        db.loginReminder = value
                    end,
                    default = defaults.loginReminder
                },
                {
                    type = "dropdown",
                    name = GetString(MSAL_LOOT_LOG_THRESHOLD),
                    choices = logQualityThresholdChoices,
                    choicesValues = logQualityThresholdChoicesValues,
                    getFunc = function()
                        return db.printLootThreshold
                    end,
                    setFunc = function(value)
                        db.printLootThreshold = value
                    end,
                    default = defaults.printLootThreshold
                },
                {
                    type = "dropdown",
                    name = GetString(MSAL_DISPOSE_LOG_THRESHOLD),
                    tooltip = GetString(MSAL_DISPOSE_LOG_THRESHOLD_TOOLTIP),
                    choices = logQualityThresholdChoices,
                    choicesValues = logQualityThresholdChoicesValues,
                    getFunc = function()
                        return db.printDisposeThreshold
                    end,
                    setFunc = function(value)
                        db.printDisposeThreshold = value
                    end,
                    default = defaults.printDisposeThreshold
                },
                {
                    type = "checkbox",
                    name = GetString(MSAL_DECON_LOG),
                    getFunc = function()
                        return db.deconLogEnabled
                    end,
                    setFunc = function(value)
                        db.deconLogEnabled = value
                    end,
                    default = defaults.deconLogEnabled
                },
                {
                    type = "checkbox",
                    name = GetString(MSAL_SELL_JUNK_LOG),
                    getFunc = function()
                        return db.sellJunkLogEnabled
                    end,
                    setFunc = function(value)
                        db.sellJunkLogEnabled = value
                    end,
                    default = defaults.sellJunkLogEnabled
                },
                {
                    type = "checkbox",
                    name = GetString(MSAL_USE_ICONS_IN_LOG),
                    tooltip = zo_strformat(GetString(MSAL_USE_ICONS_IN_LOG_TOOLTIP),
                        GetString(SI_ITEM_ACTION_LOOT_TAKE), GetString(SI_ITEM_ACTION_MARK_AS_JUNK),
                        GetString(MSAL_REGISTER_FOR_DECON), GetString(SI_ITEM_ACTION_DESTROY)),
                    getFunc = function()
                        return db.useIconsInLog
                    end,
                    setFunc = function(value)
                        db.useIconsInLog = value
                    end,
                    default = defaults.useIconsInLog
                },
                {
                    type = "header",
                    name = "|c999999 / " .. GetString(MSAL_STEALING) .. "|r",
                    width = "full"
                },
                {
                    type = "dropdown",
                    name = GetString(MSAL_STOLEN_ITEMS_RULE),
                    tooltip = zo_strformat(GetString(MSAL_STOLEN_ITEMS_RULE_TOOLTIP), GetString(MSAL_FOLLOW_RULES), GetString(MSAL_DONT_STEAL), GetString(MSAL_DONT_STEAL_STRICT)),
                    choices = stolenChoices,
                    choicesValues = stolenChoicesValues,
                    getFunc = function()
                        return db.stolenRule
                    end,
                    setFunc = function(value)
                        db.stolenRule = value
                    end,
                    default = defaults.stolenRule
                },
                {
                    type = "checkbox",
                    name = GetString(MSAL_AUTO_LAUNDER),
                    tooltip = GetString(MSAL_AUTO_LAUNDER_TOOLTIP),
                    getFunc = function()
                        return db.autoLaunder
                    end,
                    setFunc = function(value)
                        db.autoLaunder = value
                    end,
                    default = defaults.autoLaunder
                },
                {
                    type = "dropdown",
                    name = GetString(MSAL_STOLEN_TREASURE_QUALITY_FILTER),
                    tooltip = GetString(MSAL_STOLEN_TREASURE_QUALITY_FILTER_TOOLTIP),
                    choices = qualityGreenToPurpleChoices,
                    choicesValues = qualityGreenToPurpleChoicesValues,
                    getFunc = function()
                        return db.stolenTreasureThreshold
                    end,
                    setFunc = function(value)
                        db.stolenTreasureThreshold = value
                    end,
                    default = defaults.stolenTreasureThreshold
                },
                {
                    type = "header",
                    name = "|c999999 / " .. GetString(MSAL_UNBOX) .. "|r",
                    width = "full"
                },
                {
                    type = "description",
                    text = zo_strformat(GetString(MSAL_HELP_UNBOX), GetString(MSAL_GENERAL_DISPOSER)),
                    width = "full"
                },
                {
                    type = "dropdown",
                    name = zo_strformat(GetString(MSAL_AUTO_UNBOX), GetString(SI_ITEMTYPE18)),
                    choices = unboxChoices,
                    choicesValues = unboxChoicesValues,
                    getFunc = function()
                        return db.autoUnboxContainer
                    end,
                    setFunc = function(value)
                        db.autoUnboxContainer = value
                    end,
                    default = defaults.autoUnboxContainer
                },
                {
                    type = "button",
                    name = zo_strformat(GetString(MSAL_LRM_UNBOX), GetString(SI_ITEMTYPE18)),
                    tooltip = GetString(MSAL_LRM_UNBOX_CONTAINER_TOOLTIP),
                    func = function()
                        MSAL.UnboxInventoryContainer()
                    end
                },
                {
                    type = "checkbox",
                    name = zo_strformat(GetString(MSAL_AUTO_UNBOX), GetString(SI_ITEMTYPE70)),
                    tooltip = zo_strformat(GetString(MSAL_AUTO_UNBOX),
                        zo_strformat(GetString(MSAL_UNBOX_GEODE_TOOLTIP), geodeName)),
                    getFunc = function()
                        return db.autoUnboxGeode
                    end,
                    setFunc = function(value)
                        db.autoUnboxGeode = value
                    end,
                    default = defaults.autoUnboxGeode
                },
                {
                    type = "button",
                    name = zo_strformat(GetString(MSAL_LRM_UNBOX), GetString(SI_ITEMTYPE70)),
                    tooltip = zo_strformat(GetString(MSAL_LRM_UNBOX_TOOLTIP), GetString(SI_ITEMTYPE70)),
                    func = function()
                        MSAL.UnboxInventoryGeode()
                    end
                },
                {
                    type = "checkbox",
                    name = zo_strformat(GetString(MSAL_AUTO_UNBOX), GetString(SI_ITEMTYPE75)),
                    tooltip = zo_strformat(GetString(MSAL_AUTO_UNBOX),
                        GetString(SI_SPECIALIZEDITEMTYPE2750) .. " / " .. GetString(SI_SPECIALIZEDITEMTYPE101) ..
                            GetString(MSAL_SPACE) .. GetString(SI_ITEMTYPE18)),
                    getFunc = function()
                        return db.autoUnboxUnopened
                    end,
                    setFunc = function(value)
                        db.autoUnboxUnopened = value
                    end,
                    default = defaults.autoUnboxUnopened
                },
                {
                    type = "button",
                    name = zo_strformat(GetString(MSAL_LRM_UNBOX), GetString(SI_ITEMTYPE75)),
                    tooltip = zo_strformat(GetString(MSAL_LRM_UNBOX_TOOLTIP), GetString(SI_ITEMTYPE75)),
                    func = function()
                        MSAL.UnboxInventoryUnopened()
                    end
                },
                {
                    type = "checkbox",
                    name = zo_strformat(GetString(MSAL_AUTO_UNBOX), GetString(SI_ITEMTYPE54)),
                    getFunc = function()
                        return db.autoUnboxFish
                    end,
                    setFunc = function(value)
                        db.autoUnboxFish = value
                    end,
                    default = defaults.autoUnboxFish
                },
                {
                    type = "button",
                    name = zo_strformat(GetString(MSAL_LRM_UNBOX), GetString(SI_ITEMTYPE54)),
                    tooltip = zo_strformat(GetString(MSAL_LRM_UNBOX_TOOLTIP), GetString(SI_ITEMTYPE54)),
                    func = function()
                        MSAL.UnboxInventoryFish()
                    end
                }
            }
        },
        {
            type = "submenu",
            name = GetString(MSAL_DISPOSER),
            controls = {
                {
                    type = "description",
                    text = zo_strformat(GetString(MSAL_HELP_UNWANTED_CONSOLE), GetString(SI_ITEM_ACTION_MARK_AS_JUNK)),
                    width = "full"
                },
                {
                    type = "dropdown",
                    name = GetString(MSAL_GENERAL_DISPOSER),
                    tooltip = GetString(MSAL_GENERAL_DISPOSER_TOOLTIP),
                    choices = disposerChoices,
                    choicesValues = disposerChoicesValues,
                    getFunc = function()
                        return db.unwantedItemsDisposer
                    end,
                    setFunc = function(value)
                        db.unwantedItemsDisposer = value
                    end,
                    default = defaults.unwantedItemsDisposer
                },
                {
                    type = "checkbox",
                    name = "/ " .. GetString(MSAL_CLEAN_BAG_CONTAINER_LEFTOVERS),
                    tooltip = zo_strformat(GetString(MSAL_CLEAN_BAG_CONTAINER_LEFTOVERS_TOOLTIP),
                        GetString(MSAL_GENERAL_DISPOSER), GetString(MSAL_LEAVE_BEHIND)),
                    getFunc = function()
                        return db.cleanBagContainerLeftovers
                    end,
                    setFunc = function(value)
                        db.cleanBagContainerLeftovers = value
                    end,
                    default = defaults.cleanBagContainerLeftovers,
                    disabled = function()
                        return db.unwantedItemsDisposer ~= "none"
                    end
                },
                -- {
                --     type = "slider",
                --     name = "/ " .. GetString(MSAL_JUNK_THRESHOLD),
                --     tooltip = zo_strformat(GetString(MSAL_JUNK_THRESHOLD_TOOLTIP), GetString(SI_ITEM_ACTION_MARK_AS_JUNK), GetString(MSAL_GENERAL_DISPOSER)),
                --     min = 0,
                --     max = 300,
                --     step = 10,
                --     getFunc = function()
                --         return db.junkThreshold
                --     end,
                --     setFunc = function(value)
                --         db.junkThreshold = value
                --     end,
                --     default = 0,
                --     disabled = function()
                --         return db.unwantedItemsDisposer ~= "junk"
                --     end
                -- },
                {
                    type = "dropdown",
                    name = GetString(MSAL_GEAR_DISPOSER),
                    tooltip = zo_strformat(GetString(MSAL_GEAR_DISPOSER_TOOLTIP), GetString(MSAL_REGISTER_FOR_DECON)),
                    choices = gearDisposerChoices,
                    choicesValues = gearDisposerChoicesValues,
                    getFunc = function()
                        return db.gearDisposer
                    end,
                    setFunc = function(value)
                        db.gearDisposer = value
                    end,
                    default = defaults.gearDisposer
                },
                {
                    type = "dropdown",
                    name = "/ " .. GetString(MSAL_DECON_THRESHOLD),
                    tooltip = zo_strformat(GetString(MSAL_DECON_THRESHOLD_TOOLTIP),
                        GetString(MSAL_REGISTER_FOR_DECON_AND_JUNK), GetString(MSAL_GEAR_DISPOSER),
                        GetString(MSAL_REGISTER_FOR_DECON)),
                    choices = deconThresholdChoices,
                    choicesValues = deconThresholdChoicesValues,
                    getFunc = function()
                        return db.deconThreshold
                    end,
                    setFunc = function(value)
                        db.deconThreshold = value
                    end,
                    default = defaults.deconThreshold,
                    disabled = function()
                        return db.gearDisposer ~= "decon and junk"
                    end
                }
            }
        },
        {
            type = "submenu",
            name = GetString(MSAL_GEAR_FILTERS),
            controls = {
                {
                    type = "description",
                    text = zo_strformat(GetString(MSAL_HELP_GEAR), GetString(MSAL_GEAR_FILTERS)),
                    width = "full"
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEM_SETS_BOOK_TITLE),
                    choices = setChoices,
                    choicesValues = setChoicesValues,
                    getFunc = function()
                        return db.filters.set
                    end,
                    setFunc = function(value)
                        db.filters.set = value
                    end,
                    default = defaults.filters.set
                },
                {
                    type = "checkbox",
                    name = GetString(MSAL_AUTOBIND),
                    tooltip = GetString(MSAL_AUTOBIND_TOOLTIP),
                    getFunc = function()
                        return db.autoBind
                    end,
                    setFunc = function(value)
                        db.autoBind = value
                    end,
                    default = defaults.autoBind
                },
                {
                    type = "checkbox",
                    name = "/ " .. GetString(MSAL_DISPOSE_AFTER_BIND),
                    tooltip = zo_strformat(GetString(MSAL_DISPOSE_AFTER_BIND_TOOLTIP), GetString(MSAL_GEAR_DISPOSER)),
                    getFunc = function()
                        return db.autoDisposeAfterBind
                    end,
                    setFunc = function(value)
                        db.autoDisposeAfterBind = value
                    end,
                    default = defaults.autoDisposeAfterBind,
                    disabled = function()
                        return not db.autoBind
                    end
                },
                {
                    type = "header",
                    name = "|c999999 / " .. GetString(MSAL_TRAIT_GEARS) .. "|r",
                    width = "full"
                },
                {
                    type = "dropdown",
                    name = GetString(MSAL_RARE_TRAIT),
                    tooltip = GetString(MSAL_RARE_TRAIT_TOOLTIP),
                    choices = deconChoices,
                    choicesValues = deconChoicesValues,
                    getFunc = function()
                        return db.filters.rareTrait
                    end,
                    setFunc = function(value)
                        db.filters.rareTrait = value
                    end,
                    default = defaults.filters.rareTrait
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTRAITINFORMATION3),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.unresearched
                    end,
                    setFunc = function(value)
                        db.filters.unresearched = value
                    end,
                    default = defaults.filters.unresearched
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTRAITTYPE19),
                    choices = junkChoices,
                    choicesValues = junkChoicesValues,
                    getFunc = function()
                        return db.filters.ornate
                    end,
                    setFunc = function(value)
                        db.filters.ornate = value
                    end,
                    default = defaults.filters.ornate
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTRAITTYPE20),
                    tooltip = zo_strformat(GetString(MSAL_INTRICATE_DECON_TOOLTIP), GetString(SI_INTERACT_OPTION_LOOT) .. " & " .. GetString(MSAL_REGISTER_FOR_DECON)),
                    choices = intricateChoices,
                    choicesValues = intricateChoicesValues,
                    getFunc = function()
                        return db.filters.intricate
                    end,
                    setFunc = function(value)
                        db.filters.intricate = value
                    end,
                    default = defaults.filters.intricate
                },
                {
                    type = "dropdown",
                    name = "/ " .. GetString(SI_TRADESKILLTYPE1),
                    tooltip = zo_strformat(GetString(MSAL_INTRICATE_DECON_TOOLTIP), GetString(SI_INTERACT_OPTION_LOOT) .. " & " .. GetString(MSAL_REGISTER_FOR_DECON)),
                    choices = deconChoices,
                    choicesValues = deconChoicesValues,
                    getFunc = function()
                        return db.filters.blacksmithingIntricate
                    end,
                    setFunc = function(value)
                        db.filters.blacksmithingIntricate = value
                    end,
                    default = defaults.filters.blacksmithingIntricate,
                    disabled = function()
                        return not (db.filters.intricate == "type based")
                    end
                },
                {
                    type = "dropdown",
                    name = "/ " .. GetString(SI_TRADESKILLTYPE2),
                    tooltip = zo_strformat(GetString(MSAL_INTRICATE_DECON_TOOLTIP), GetString(SI_INTERACT_OPTION_LOOT) .. " & " .. GetString(MSAL_REGISTER_FOR_DECON)),
                    choices = deconChoices,
                    choicesValues = deconChoicesValues,
                    getFunc = function()
                        return db.filters.clothingIntricate
                    end,
                    setFunc = function(value)
                        db.filters.clothingIntricate = value
                    end,
                    default = defaults.filters.clothingIntricate,
                    disabled = function()
                        return not (db.filters.intricate == "type based")
                    end
                },
                {
                    type = "dropdown",
                    name = "/ " .. GetString(SI_TRADESKILLTYPE6),
                    tooltip = zo_strformat(GetString(MSAL_INTRICATE_DECON_TOOLTIP), GetString(SI_INTERACT_OPTION_LOOT) .. " & " .. GetString(MSAL_REGISTER_FOR_DECON)),
                    choices = deconChoices,
                    choicesValues = deconChoicesValues,
                    getFunc = function()
                        return db.filters.woodworkingIntricate
                    end,
                    setFunc = function(value)
                        db.filters.woodworkingIntricate = value
                    end,
                    default = defaults.filters.woodworkingIntricate,
                    disabled = function()
                        return not (db.filters.intricate == "type based")
                    end
                },
                {
                    type = "dropdown",
                    name = "/ " .. GetString(SI_TRADESKILLTYPE7),
                    tooltip = zo_strformat(GetString(MSAL_INTRICATE_DECON_TOOLTIP), GetString(SI_INTERACT_OPTION_LOOT) .. " & " .. GetString(MSAL_REGISTER_FOR_DECON)),
                    choices = deconChoices,
                    choicesValues = deconChoicesValues,
                    getFunc = function()
                        return db.filters.jewelryIntricate
                    end,
                    setFunc = function(value)
                        db.filters.jewelryIntricate = value
                    end,
                    default = defaults.filters.jewelryIntricate,
                    disabled = function()
                        return not (db.filters.intricate == "type based")
                    end
                },
                {
                    type = "header",
                    name = "|c999999 / " .. GetString(MSAL_GENERAL_GEARS) .. "|r",
                    width = "full"
                },
                                {
                    type = "dropdown",
                    name = GetString(MSAL_CRAFTED_GEARS),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.craftedGears
                    end,
                    setFunc = function(value)
                        db.filters.craftedGears = value
                    end,
                    default = defaults.filters.craftedGears
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEM_FORMAT_STR_COMPANION),
                    choices = qualityPurpleChoices,
                    choicesValues = qualityPurpleChoicesValues,
                    getFunc = function()
                        return db.filters.companionGears
                    end,
                    setFunc = function(value)
                        db.filters.companionGears = value
                    end,
                    default = defaults.filters.companionGears
                },
                {
                    type = "dropdown",
                    name = zo_strformat(GetString(MSAL_GENERAL), GetString(SI_ITEMTYPEDISPLAYCATEGORY1)),
                    choices = qualityBlueToGoldChoices,
                    choicesValues = qualityBlueToGoldChoicesValues,
                    getFunc = function()
                        return db.filters.weapons
                    end,
                    setFunc = function(value)
                        db.filters.weapons = value
                    end,
                    default = defaults.filters.weapons
                },
                {
                    type = "dropdown",
                    name = zo_strformat(GetString(MSAL_GENERAL), GetString(SI_ITEMTYPEDISPLAYCATEGORY2)),
                    choices = qualityBlueToGoldChoices,
                    choicesValues = qualityBlueToGoldChoicesValues,
                    getFunc = function()
                        return db.filters.armors
                    end,
                    setFunc = function(value)
                        db.filters.armors = value
                    end,
                    default = defaults.filters.armors
                },
                {
                    type = "dropdown",
                    name = zo_strformat(GetString(MSAL_GENERAL), GetString(SI_ITEMTYPEDISPLAYCATEGORY3)),
                    choices = qualityBlueToGoldChoices,
                    choicesValues = qualityBlueToGoldChoicesValues,
                    getFunc = function()
                        return db.filters.jewelry
                    end,
                    setFunc = function(value)
                        db.filters.jewelry = value
                    end,
                    default = defaults.filters.jewelry
                }
            }
        },
        {
            type = "submenu",
            name = GetString(MSAL_MATERIAL_FILTERS),
            controls = {
                {
                    type = "description",
                    text = GetString(MSAL_HELP_MATERIAL),
                    width = "full"
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPEDISPLAYCATEGORY10),
                    choices = materialChoices,
                    choicesValues = materialChoicesValues,
                    getFunc = function()
                        return db.filters.blacksmithingMaterials
                    end,
                    setFunc = function(value)
                        db.filters.blacksmithingMaterials = value
                    end,
                    default = defaults.filters.blacksmithingMaterials
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPEDISPLAYCATEGORY11),
                    choices = materialChoices,
                    choicesValues = materialChoicesValues,
                    getFunc = function()
                        return db.filters.clothingMaterials
                    end,
                    setFunc = function(value)
                        db.filters.clothingMaterials = value
                    end,
                    default = defaults.filters.clothingMaterials
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPEDISPLAYCATEGORY12),
                    choices = materialChoices,
                    choicesValues = materialChoicesValues,
                    getFunc = function()
                        return db.filters.woodworkingMaterials
                    end,
                    setFunc = function(value)
                        db.filters.woodworkingMaterials = value
                    end,
                    default = defaults.filters.woodworkingMaterials
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPEDISPLAYCATEGORY13),
                    choices = materialChoices,
                    choicesValues = materialChoicesValues,
                    getFunc = function()
                        return db.filters.jewelryCraftingMaterials
                    end,
                    setFunc = function(value)
                        db.filters.jewelryCraftingMaterials = value
                    end,
                    default = defaults.filters.jewelryCraftingMaterials
                },
                {
                    type = "dropdown",
                    name = GetString(SI_SMITHING_EXTRACTION_REFINE_HEADER),
                    choices = qualityBlueToGoldChoices,
                    choicesValues = qualityBlueToGoldChoicesValues,
                    getFunc = function()
                        return db.filters.refineMaterials
                    end,
                    setFunc = function(value)
                        db.filters.refineMaterials = value
                    end,
                    default = defaults.filters.refineMaterials
                },
                {
                    type = "header",
                    name = "|c999999 / " .. GetString(MSAL_MISC_MATERIAL) .. "|r",
                    width = "full"
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE44),
                    choices = styleMaterialsChoices,
                    choicesValues = styleMaterialsChoicesValues,
                    getFunc = function()
                        return db.filters.styleMaterials
                    end,
                    setFunc = function(value)
                        db.filters.styleMaterials = value
                    end,
                    default = defaults.filters.styleMaterials
                },
                {
                    type = "dropdown",
                    name = GetString(SI_GAMEPADITEMCATEGORY30),
                    choices = traitMaterialsChoices,
                    choicesValues = traitMaterialsChoicesValues,
                    getFunc = function()
                        return db.filters.traitMaterials
                    end,
                    setFunc = function(value)
                        db.filters.traitMaterials = value
                    end,
                    default = defaults.filters.traitMaterials
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPEDISPLAYCATEGORY14),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.alchemy
                    end,
                    setFunc = function(value)
                        db.filters.alchemy = value
                    end,
                    default = defaults.filters.alchemy
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPEDISPLAYCATEGORY16),
                    choices = ingredientChoices,
                    choicesValues = ingredientChoicesValues,
                    getFunc = function()
                        return db.filters.ingredients
                    end,
                    setFunc = function(value)
                        db.filters.ingredients = value
                    end,
                    default = defaults.filters.ingredients
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPEDISPLAYCATEGORY15),
                    choices = enchantingChoices,
                    choicesValues = enchantingChoicesValues,
                    getFunc = function()
                        return db.filters.runes
                    end,
                    setFunc = function(value)
                        db.filters.runes = value
                    end,
                    default = defaults.filters.runes
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE62),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.furnishingMaterials
                    end,
                    setFunc = function(value)
                        db.filters.furnishingMaterials = value
                    end,
                    default = defaults.filters.furnishingMaterials
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE74),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.ink
                    end,
                    setFunc = function(value)
                        db.filters.ink = value
                    end,
                    default = defaults.filters.ink
                }
            }
        },
        {
            type = "submenu",
            name = GetString(MSAL_MISC_FILTERS),
            controls = {
                {
                    type = "description",
                    text = GetString(MSAL_HELP_MISC),
                    width = "full"
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE61),
                    choices = dynamicfurnitureChoices,
                    choicesValues = dynamicfurnitureChoicesValues,
                    getFunc = function()
                        return db.filters.furniture
                    end,
                    setFunc = function(value)
                        db.filters.furniture = value
                    end,
                    default = defaults.filters.furniture
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE5),
                    tooltip = GetString(SI_SPECIALIZEDITEMTYPE108) .. " & " .. GetString(SI_SPECIALIZEDITEMTYPE104) ..
                        " & " .. GetString(SI_SPECIALIZEDITEMTYPE105) .. " & " .. GetString(SI_SPECIALIZEDITEMTYPE107),
                    choices = dynamicBooleanChoices,
                    choicesValues = dynamicBooleanChoicesValues,
                    getFunc = function()
                        return db.filters.trophy
                    end,
                    setFunc = function(value)
                        db.filters.trophy = value
                    end,
                    default = defaults.filters.trophy
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEM_FORMAT_STR_COLLECTIBLE),
                    tooltip = GetString(SI_ITEMTYPEDISPLAYCATEGORY24) .. " & " ..
                        GetString(SI_ITEMTYPEDISPLAYCATEGORY21) .. " & " ..
                        GetString(SI_PROVISIONERSPECIALINGREDIENTTYPE_TRADINGHOUSERECIPECATEGORY3) .. " & " ..
                        GetString(SI_SPECIALIZEDITEMTYPE80) .. " & " .. GetString(SI_SPECIALIZEDITEMTYPE109),
                    choices = dynamicBooleanChoices,
                    choicesValues = dynamicBooleanChoicesValues,
                    getFunc = function()
                        return db.filters.recipes
                    end,
                    setFunc = function(value)
                        db.filters.recipes = value
                    end,
                    default = defaults.filters.recipes
                },
                {
                    type = "checkbox",
                    name = "/ " .. GetString(MSAL_LOOT_UNKNOWN_COLLECTIBLE),
                    tooltip = GetString(MSAL_LOOT_UNKNOWN_COLLECTIBLE_TOOLTIP),
                    getFunc = function()
                        return db.filters.recipesAlwaysLootUnknown
                    end,
                    setFunc = function(value)
                        db.filters.recipesAlwaysLootUnknown = value
                    end,
                    default = defaults.filters.recipesAlwaysLootUnknown
                },
                {
                    type = "checkbox",
                    name = "// " .. GetString(MSAL_LOOT_ANY_CHAR_UNKNOWN),
                    tooltip = GetString(MSAL_LOOT_ANY_CHAR_UNKNOWN_TOOLTIP),
                    getFunc = function()
                        return db.filters.recipesAlwaysLootAnyCharUnknown
                    end,
                    setFunc = function(value)
                        db.filters.recipesAlwaysLootAnyCharUnknown = value
                    end,
                    default = defaults.filters.recipesAlwaysLootAnyCharUnknown,
                    disabled = function()
                        return not LCK
                    end
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE73),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.scribing
                    end,
                    setFunc = function(value)
                        db.filters.scribing = value
                    end,
                    default = defaults.filters.scribing
                },
                {
                    type = "checkbox",
                    name = "/ " .. zo_strformat(GetString(MSAL_AUTO_MARK), zo_strformat(
                        GetString(SI_ITEM_FORMAT_STR_KNOWN_ITEM_TYPE), GetString(SI_ITEMTYPE73))),
                    tooltip = zo_strformat(GetString(MSAL_SCRIPT_TOOLTIP), GetString(SI_ITEMTYPE73)),
                    getFunc = function()
                        return db.filters.scribingAutoMark
                    end,
                    setFunc = function(value)
                        db.filters.scribingAutoMark = value
                    end,
                    default = defaults.filters.scribingAutoMark,
                    disabled = function()
                        return db.filters.scribing == "never loot"
                    end
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPEDISPLAYCATEGORY30),
                    tooltip = GetString(MSAL_GLYPH_FILTER_TOOLTIP),
                    choices = deconChoices,
                    choicesValues = deconChoicesValues,
                    getFunc = function()
                        return db.filters.glyphs
                    end,
                    setFunc = function(value)
                        db.filters.glyphs = value
                    end,
                    default = defaults.filters.glyphs
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE18),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.containers
                    end,
                    setFunc = function(value)
                        db.filters.containers = value
                    end,
                    default = defaults.filters.containers
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE75),
                    tooltip = zo_strformat(GetString(MSAL_UNOPENED_TOOLTIP), 
                    GetString(SI_ITEMTYPE75), 
                    GetString(SI_SPECIALIZEDITEMTYPE2750), 
                    GetString(SI_SPECIALIZEDITEMTYPE101), 
                    GetString(SI_SPECIALIZEDITEMTYPE100)),
                    choices = unopenedChoices,
                    choicesValues = unopenedChoicesValues,
                    getFunc = function()
                        return db.filters.unopened
                    end,
                    setFunc = function(value)
                        db.filters.unopened = value
                    end,
                    default = defaults.filters.unopened
                },
                {
                    type = "dropdown",
                    name = "/ " .. GetString(SI_ITEMTYPE75) .. GetString(MSAL_SPACE) .. GetString(SI_ITEMTYPE60),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.writs
                    end,
                    setFunc = function(value)
                        db.filters.writs = value
                    end,
                    default = defaults.filters.writs,
                    disabled = function()
                        return not (db.filters.unopened == "type based")
                    end
                },
                {
                    type = "dropdown",
                    name = "/ " .. GetString(SI_ITEMTYPE75) .. GetString(MSAL_SPACE) ..
                        GetString(SI_SPECIALIZEDITEMTYPE101),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.survey
                    end,
                    setFunc = function(value)
                        db.filters.survey = value
                    end,
                    default = defaults.filters.survey,
                    disabled = function()
                        return not (db.filters.unopened == "type based")
                    end
                },
                {
                    type = "dropdown",
                    name = "/ " .. GetString(SI_ITEMTYPE75) .. GetString(MSAL_SPACE) ..
                        GetString(SI_SPECIALIZEDITEMTYPE100),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.treasureMaps
                    end,
                    setFunc = function(value)
                        db.filters.treasureMaps = value
                    end,
                    default = defaults.filters.treasureMaps,
                    disabled = function()
                        return not (db.filters.unopened == "type based")
                    end
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEM_FORMAT_STR_QUEST_ITEM),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.questItems
                    end,
                    setFunc = function(value)
                        db.filters.questItems = value
                    end,
                    default = defaults.filters.questItems
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE57),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.crownItems
                    end,
                    setFunc = function(value)
                        db.filters.crownItems = value
                    end,
                    default = defaults.filters.crownItems
                },
                {
                    type = "dropdown",
                    name = GetString(SI_SPECIALIZEDITEMTYPE900),
                    choices = soulGemsChoices,
                    choicesValues = soulGemsChoicesValues,
                    getFunc = function()
                        return db.filters.soulGems
                    end,
                    setFunc = function(value)
                        db.filters.soulGems = value
                    end,
                    default = defaults.filters.soulGems
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE76),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.skillScrolls
                    end,
                    setFunc = function(value)
                        db.filters.skillScrolls = value
                    end,
                    default = defaults.filters.skillScrolls
                },
                {
                    type = "dropdown",
                    name = GetString(SI_GAMEPAD_VENDOR_ANTIQUITY_LEAD_GROUP_HEADER),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.leads
                    end,
                    setFunc = function(value)
                        db.filters.leads = value
                    end,
                    default = defaults.filters.leads
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE4) .. " & " .. GetString(SI_ITEMTYPE12),
                    choices = foodChoices,
                    choicesValues = foodChoicesValues,
                    getFunc = function()
                        return db.filters.foodAndDrink
                    end,
                    setFunc = function(value)
                        db.filters.foodAndDrink = value
                    end,
                    default = defaults.filters.foodAndDrink
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPEDISPLAYCATEGORY23),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.poisons
                    end,
                    setFunc = function(value)
                        db.filters.poisons = value
                    end,
                    default = defaults.filters.poisons
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPEDISPLAYCATEGORY22),
                    choices = potionsChoices,
                    choicesValues = potionsChoicesValues,
                    getFunc = function()
                        return db.filters.potions
                    end,
                    setFunc = function(value)
                        db.filters.potions = value
                    end,
                    default = defaults.filters.potions
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE47) .. " & " .. GetString(SI_ITEMTYPE6) .. " & " .. GetString(SI_SPECIALIZEDITEMTYPE3100),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.allianceWarConsumables
                    end,
                    setFunc = function(value)
                        db.filters.allianceWarConsumables = value
                    end,
                    default = defaults.filters.allianceWarConsumables
                },
                {
                    type = "dropdown",
                    name = trimLastCharUTF8(GetString(SI_HOOK_POINT_STORE_REPAIR_KIT_HEADER)),
                    tooltip = "|H1:item:44879:121:50:0:0:0:0:0:0:0:0:0:0:0:0:36:0:0:0:0:0|h|h" .. " / " ..
                        "|H1:item:61079:121:50:0:0:0:0:0:0:0:0:0:0:0:0:36:0:0:0:0:0|h|h" .. " / " ..
                        "|H1:item:157516:121:50:0:0:0:0:0:0:0:0:0:0:0:0:36:0:0:0:0:0|h|h",
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.repairKits
                    end,
                    setFunc = function(value)
                        db.filters.repairKits = value
                    end,
                    default = defaults.filters.repairKits
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE22),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.lockpicks
                    end,
                    setFunc = function(value)
                        db.filters.lockpicks = value
                    end,
                    default = defaults.filters.lockpicks
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE9),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.tools
                    end,
                    setFunc = function(value)
                        db.filters.tools = value
                    end,
                    default = defaults.filters.tools
                },
                {
                    type = "dropdown",
                    name = GetString(SI_SPECIALIZEDITEMTYPE600) .. " & " .. GetString(SI_SPECIALIZEDITEMTYPE650),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.costumes
                    end,
                    setFunc = function(value)
                        db.filters.costumes = value
                    end,
                    default = defaults.filters.costumes
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPEDISPLAYCATEGORY35),
                    choices = booleanChoices,
                    choicesValues = booleanChoicesValues,
                    getFunc = function()
                        return db.filters.fishingBaits
                    end,
                    setFunc = function(value)
                        db.filters.fishingBaits = value
                    end,
                    default = defaults.filters.fishingBaits
                },
                {
                    type = "dropdown",
                    name = GetString(SI_SPECIALIZEDITEMTYPE2550),
                    choices = junkChoices,
                    choicesValues = junkChoicesValues,
                    getFunc = function()
                        return db.filters.treasures
                    end,
                    setFunc = function(value)
                        db.filters.treasures = value
                    end,
                    default = defaults.filters.treasures
                },
                {
                    type = "dropdown",
                    name = GetString(SI_ITEMTYPE48),
                    choices = junkChoices,
                    choicesValues = junkChoicesValues,
                    getFunc = function()
                        return db.filters.trash
                    end,
                    setFunc = function(value)
                        db.filters.trash = value
                    end,
                    default = defaults.filters.trash
                }
            }
        }
    }

    local function findSectionIndex(sectionName)
        for i, section in ipairs(optionsData) do
            if section.type == "submenu" and section.name == sectionName then
                return i
            end
        end
        return nil
    end

    local function findControlIndex(sectionIndex, controlName)
        if not optionsData[sectionIndex] or not optionsData[sectionIndex].controls then
            return nil
        end
        for i, control in ipairs(optionsData[sectionIndex].controls) do
            if control.name == controlName then
                return i
            end
        end
        return nil
    end

    local descriptionIndex = 1
    local miscSettingsIndex = findSectionIndex(GetString(MSAL_MISC_FILTERS))
    -- dynamic options for 3rd party pricing addons
    if (MasterMerchant or TamrielTradeCentre or ArkadiusTradeTools or TSCApi) then
        optionsData[miscSettingsIndex].controls[descriptionIndex].text = GetString(MSAL_HELP_MISC_3RD_ENABLED)
        local dynamicSlider = {
            type = "slider",
            name = GetString(MSAL_THIRD_PARTY_AVG_THRESHOLD),
            tooltip = GetString(MSAL_THIRD_PARTY_AVG_THRESHOLD_TOOLTIP),
            min = 0,
            max = 99999,
            step = 500,
            getFunc = function()
                return db.filters.thirdPartyMinValue
            end,
            setFunc = function(value)
                db.filters.thirdPartyMinValue = value
            end,
            default = defaults.filters.thirdPartyMinValue
        }
        local dynamicDropdown = {
            type = "dropdown",
            name = GetString(MSAL_THIRD_PARTY_USED),
            choices = dynamicThirdPartyChoices,
            choicesValues = dynamicThirdPartyChoicesValues,
            getFunc = function()
                return db.filters.thirdParty
            end,
            setFunc = function(value)
                db.filters.thirdParty = value
            end,
            default = defaults.filters.thirdParty
        }
        local scriptIndex = findControlIndex(miscSettingsIndex, GetString(SI_ITEMTYPE73))
        table.insert(optionsData[miscSettingsIndex].controls, scriptIndex, {
            type = "header",
            name = "|c999999 / " .. GetString(MSAL_LOW_VALUE_MISC) .. "|r",
            width = "full"
        })
        -- table.insert(optionsData[miscSettingsIndex].controls, descriptionIndex + 1, dynamicCheckboxNoPrice)
        table.insert(optionsData[miscSettingsIndex].controls, descriptionIndex + 1, dynamicSlider)
        table.insert(optionsData[miscSettingsIndex].controls, descriptionIndex + 1, dynamicDropdown)

        local styleMat3rdDropDown = {
            type = "dropdown",
            name = GetString(SI_ITEMTYPE44),
            tooltip = zo_strformat(GetString(MSAL_STYLE_MATERIAL_3RD_TOOLTIP), GetString(MSAL_USE_DEFAULT),
                GetString(MSAL_MATERIAL_FILTERS), GetString(SI_ITEMTYPE44),
                zo_strformat(GetString(MSAL_USE), GetString(MSAL_THIRD_PARTY))),
            choices = dynamicStyleMatChoices,
            choicesValues = dynamicStyleMatChoicesValues,
            getFunc = function()
                return db.filters.styleMaterials3rd
            end,
            setFunc = function(value)
                db.filters.styleMaterials3rd = value
            end,
            default = defaults.filters.styleMaterials3rd
        }
        local styleMat3rdSlider = {
            type = "slider",
            name = "/ " .. zo_strformat(GetString(MSAL_STYLE_MATERIAL_3RD), GetString(SI_ITEMTYPE44)),
            min = 0,
            max = 2000,
            step = 50,
            getFunc = function()
                return db.filters.styleMaterials3rdPriceThreshold
            end,
            setFunc = function(value)
                db.filters.styleMaterials3rdPriceThreshold = value
            end,
            default = defaults.filters.styleMaterials3rdPriceThreshold,
            disabled = function()
                return db.filters.styleMaterials3rd == "use default"
            end
        }

        local styleMatGearCheckbox = {
            type = "checkbox",
            name = "/ " .. GetString(MSAL_STYLE_MATERIAL_3RD_GEAR_LOOTING),
            tooltip = GetString(MSAL_STYLE_MATERIAL_3RD_GEAR_LOOTING_TOOLTIP),
            getFunc = function()
                return db.filters.styleMaterials3rdGearLooting
            end,
            setFunc = function(value)
                db.filters.styleMaterials3rdGearLooting = value
            end,
            default = defaults.filters.styleMaterials3rdGearLooting,
            disabled = function()
                return db.filters.styleMaterials3rd == "use default"
            end
        }
        local styleMatGearAutoDeconCheckbox = {
            type = "checkbox",
            name = "// " .. GetString(MSAL_REGISTER_ABOVE_ITEM_FOR_DECON),
            tooltip = GetString(MSAL_REGISTER_ABOVE_ITEM_FOR_DECON_TOOLTIP),
            getFunc = function()
                return db.filters.styleMaterials3rdGearAutoDecon
            end,
            setFunc = function(value)
                db.filters.styleMaterials3rdGearAutoDecon = value
            end,
            default = defaults.filters.styleMaterials3rdGearAutoDecon,
            disabled = function()
                return db.filters.styleMaterials3rd == "use default" or not db.filters.styleMaterials3rdGearLooting
            end
        }
        local smAnchor = "// " .. GetString(MSAL_LOOT_ANY_CHAR_UNKNOWN)
        local accountwideUnknownIndex2 = findControlIndex(miscSettingsIndex, smAnchor)
        table.insert(optionsData[miscSettingsIndex].controls, accountwideUnknownIndex2 + 1,
            styleMatGearAutoDeconCheckbox)
        table.insert(optionsData[miscSettingsIndex].controls, accountwideUnknownIndex2 + 1, styleMatGearCheckbox)
        table.insert(optionsData[miscSettingsIndex].controls, accountwideUnknownIndex2 + 1, styleMat3rdSlider)
        table.insert(optionsData[miscSettingsIndex].controls, accountwideUnknownIndex2 + 1, styleMat3rdDropDown)
    end

    if WritCreater or SimpleDailyCraft then
        local generalSettingsIndex = findSectionIndex(GetString(MSAL_GENERAL_SETTINGS))
        local autoUnboxSettingIndex = findControlIndex(generalSettingsIndex, zo_strformat(GetString(MSAL_AUTO_UNBOX),
            GetString(SI_ITEMTYPE18)))
        optionsData[generalSettingsIndex].controls[autoUnboxSettingIndex].tooltip = GetString(
            MSAL_UNBOX_CONTAINER_TOOLTIP)
    end

    local generalSettingsIndex = findSectionIndex(GetString(MSAL_GENERAL_SETTINGS))
    local unwantedSettingsIndex = findSectionIndex(GetString(MSAL_DISPOSER))
    -- Shared by the console dropdown callbacks, remove buttons and the console list refresh wiring below, so it must live at this scope
    local consolePendingRemove = {}
    if not ZO_IsConsoleOrGameCoreUI() then
        local attachmentHeader = {
            type = "header",
            name = "|c999999 / " .. GetString(SI_MAIL_ATTACHMENTS_HEADER) .. "|r",
            width = "full"
        }
        local addLootWindowJunkingButtonsSettings = {
            type = "checkbox",
            name = zo_strformat(GetString(MSAL_ATTACH_LOOT_BUTTON), GetString(SI_ITEM_ACTION_MARK_AS_JUNK)),
            tooltip = GetString(MSAL_ADD_JUNKING_BUTTON_TOOLTIP),
            getFunc = function()
                return db.addJunkingButton
            end,
            setFunc = function(value)
                db.addJunkingButton = value
                ReorganizeLootWindowButtons()
            end,
            default = defaults.addJunkingButton
        }
        local addLootWindowDestroyButtonsSettings = {
            type = "checkbox",
            name = zo_strformat(GetString(MSAL_ATTACH_LOOT_BUTTON), GetString(SI_ITEM_ACTION_DESTROY)),
            getFunc = function()
                return db.addDestroyButton
            end,
            setFunc = function(value)
                db.addDestroyButton = value
                ReorganizeLootWindowButtons()
            end,
            default = defaults.addDestroyButton
        }
        local hostLootWindowLootAllButtonsSettings = {
            type = "checkbox",
            name = zo_strformat(GetString(MSAL_HOST_LOOT_ALL), GetString(SI_LOOT_TAKE_ALL)),
            tooltip = zo_strformat(GetString(MSAL_HOST_LOOT_ALL_TOOLTIP), GetString(SI_LOOT_TAKE_ALL)),
            getFunc = function()
                return db.hostNativeLootAll
            end,
            setFunc = function(value)
                db.hostNativeLootAll = value
                if value == true then
                    ZO_KeybindButtonTemplate_Setup(ZO_LootAlphaContainerButton1, "LOOT_ALL", function()
                        MSAL.LootAllPlus(self)
                    end, GetString(SI_LOOT_TAKE_ALL) .. "+")
                else
                    ZO_KeybindButtonTemplate_Setup(ZO_LootAlphaContainerButton1, "LOOT_ALL",
                        ZO_LootActionButtonCallback_LootAll, GetString(SI_LOOT_TAKE_ALL))
                end
            end,
            default = defaults.hostNativeLootAll
        }
        local generalUnboxFishSettingsIndex = findControlIndex(generalSettingsIndex, zo_strformat(
            GetString(MSAL_LRM_UNBOX), GetString(SI_ITEMTYPE54)))
        -- when insert multiple controls in a row always insert them in reverted order, to the same index
        table.insert(optionsData[generalSettingsIndex].controls, generalUnboxFishSettingsIndex + 1,
            hostLootWindowLootAllButtonsSettings)
        table.insert(optionsData[generalSettingsIndex].controls, generalUnboxFishSettingsIndex + 1,
            addLootWindowDestroyButtonsSettings)
        table.insert(optionsData[generalSettingsIndex].controls, generalUnboxFishSettingsIndex + 1,
            addLootWindowJunkingButtonsSettings)
        table.insert(optionsData[generalSettingsIndex].controls, generalUnboxFishSettingsIndex + 1, attachmentHeader)

        local unwantedPrintSettingIndex = findControlIndex(generalSettingsIndex, GetString(MSAL_DISPOSE_LOG_THRESHOLD))
        optionsData[unwantedSettingsIndex].controls[descriptionIndex].text = GetString(MSAL_HELP_UNWANTED)
        optionsData[generalSettingsIndex].controls[unwantedPrintSettingIndex].tooltip = nil

        local gearSettingsIndex = findSectionIndex(GetString(MSAL_GEAR_FILTERS))
        local gearAutoBindSettingsIndex = findControlIndex(gearSettingsIndex, GetString(MSAL_AUTOBIND))
        optionsData[gearSettingsIndex].controls[gearAutoBindSettingsIndex].tooltip = GetString(MSAL_AUTOBIND_TOOLTIP)

        local skipDialogSettings = {
            type = "checkbox",
            name = GetString(MSAL_SKIP_DIALOG),
            tooltip = zo_strformat(GetString(MSAL_SKIP_DIALOG_TOOLTIP), GetString(MSAL_AUTO_SELL),
                GetString(MSAL_AUTO_LAUNDER)),
            getFunc = function()
                return db.skipDialog
            end,
            setFunc = function(value)
                db.skipDialog = value
            end,
            default = defaults.skipDialog
        }
        local closeLootWindowSettingsIndex = findControlIndex(generalSettingsIndex, GetString(MSAL_CLOSE_LOOT_WINDOW))
        -- when insert multiple controls in a row always insert them in reverted order, to the same index
        table.insert(optionsData[generalSettingsIndex].controls, closeLootWindowSettingsIndex + 1, skipDialogSettings)

        -- local scriptAutoMarkSettings = 
        -- local scriptFilterIndex
        -- local miscIndex = findSectionIndex(GetString(MSAL_MISC_FILTERS))
        -- scriptFilterIndex = findControlIndex(miscIndex, GetString(SI_ITEMTYPE73))
        -- table.insert(optionsData[miscSettingsIndex].controls, scriptFilterIndex + 1, scriptAutoMarkSettings)

        local blistNames, blistIds = getListChoices(BLIST_TOKEN)
        local wlistNames, wlistIds = getListChoices(WLIST_TOKEN)
        local wlistJunkNames, wlistJunkIds = getListChoices(WLIST_JUNK_TOKEN)
        local BWListSettings = {
            type = "submenu",
            name = GetString(MSAL_BLIST) .. " / " .. GetString(MSAL_WLIST),
            -- MAIN_MENU_KEYBOARD:ShowScene("itemSetsBook")
            controls = {
                {
                    type = "description",
                    text = string.format(GetString(MSAL_HELP_LIST), GetString(MSAL_BLIST), GetString(MSAL_WLIST)),
                    width = "full"
                },
                {
                    type = "checkbox",
                    name = GetString(MSAL_CONTEXT_MENU),
                    tooltip = GetString(MSAL_CONTEXT_MENU_TOOLTIP),
                    getFunc = function()
                        return db.contextMenuEnabled
                    end,
                    setFunc = function(value)
                        db.contextMenuEnabled = value
                    end,
                    default = defaults.contextMenuEnabled,
                    disabled = function()
                        return not LibCustomMenu
                    end
                },
                {
                    type = "header",
                    name = "|c999999 / " .. GetString(MSAL_BLIST) .. "|r",
                    width = "full"
                },
                {
                    type = "editbox",
                    name = string.format(GetString(MSAL_ADD_ITEM), GetString(MSAL_BLIST)),
                    default = "",
                    reference = "MSAL_AddBList",
                    getFunc = function()
                        return
                    end,
                    setFunc = function(value)
                        addListItem(value, BLIST_TOKEN)
                    end
                },
                {
                    type = "dropdown",
                    name = string.format(GetString(MSAL_REMOVE_ITEM), GetString(MSAL_BLIST)),
                    tooltip = GetString(MSAL_BLIST_TOOLTIP),
                    choices = blistNames,
                    choicesValues = blistIds,
                    reference = "MSAL_RemoveBList",
                    scrollable = true,
                    getFunc = function()
                        return
                    end,
                    setFunc = function(value)
                        removeListItem(value, BLIST_TOKEN)
                    end
                },
                {
                    type = "header",
                    name = "|c999999 / " .. GetString(MSAL_WLIST) .. "|r",
                    width = "full"
                },
                {
                    type = "editbox",
                    name = string.format(GetString(MSAL_ADD_ITEM), GetString(MSAL_WLIST)),
                    default = "",
                    reference = "MSAL_AddWList",
                    getFunc = function()
                        return
                    end,
                    setFunc = function(value)
                        addListItem(value, WLIST_TOKEN)
                    end
                },
                {
                    type = "dropdown",
                    name = string.format(GetString(MSAL_REMOVE_ITEM), GetString(MSAL_WLIST)),
                    choices = wlistNames,
                    choicesValues = wlistIds,
                    reference = "MSAL_RemoveWList",
                    scrollable = true,
                    getFunc = function()
                        return
                    end,
                    setFunc = function(value)
                        removeListItem(value, WLIST_TOKEN)
                    end
                },
                {
                    type = "header",
                    name = "|c999999 / " .. GetString(MSAL_WLIST) .. " (" .. GetString(SI_ITEM_ACTION_MARK_AS_JUNK) .. ")" .. "|r",
                    width = "full"
                },
                {
                    type = "editbox",
                    name = string.format(GetString(MSAL_ADD_ITEM), GetString(MSAL_WLIST) .. " (" .. GetString(SI_ITEM_ACTION_MARK_AS_JUNK) .. ")"),
                    default = "",
                    reference = "MSAL_AddWListJunk",
                    getFunc = function()
                        return
                    end,
                    setFunc = function(value)
                        addListItem(value, WLIST_JUNK_TOKEN)
                    end
                },
                {
                    type = "dropdown",
                    name = string.format(GetString(MSAL_REMOVE_ITEM), GetString(MSAL_WLIST) .. " (" .. GetString(SI_ITEM_ACTION_MARK_AS_JUNK) .. ")"),
                    choices = wlistJunkNames,
                    choicesValues = wlistJunkIds,
                    reference = "MSAL_RemoveWListJunk",
                    scrollable = true,
                    getFunc = function()
                        return
                    end,
                    setFunc = function(value)
                        removeListItem(value, WLIST_JUNK_TOKEN)
                    end
                }
            }
        }
        table.insert(optionsData, miscSettingsIndex + 1, BWListSettings)
    else
        local consoleBListNames, consoleBListIds = getListChoices(BLIST_TOKEN, false)
        local consoleWListNames, consoleWListIds = getListChoices(WLIST_TOKEN, false)
        local consoleWListJunkNames, consoleWListJunkIds = getListChoices(WLIST_JUNK_TOKEN, false)
        local consoleBWListSettings = {
            type = "submenu",
            name = GetString(MSAL_BLIST) .. " / " .. GetString(MSAL_WLIST),
            controls = {
                {
                    type = "description",
                    text = string.format(GetString(MSAL_HELP_LIST_CONSOLE), GetString(MSAL_BLIST), GetString(MSAL_WLIST)),
                    width = "full"
                },
                {
                    type = "checkbox",
                    name = GetString(MSAL_CONTEXT_MENU),
                    tooltip = GetString(MSAL_CONTEXT_MENU_TOOLTIP_CONSOLE) .. GetString(MSAL_AUTO_RELOAD),
                    getFunc = function()
                        return db.contextMenuEnabled
                    end,
                    setFunc = function(value)
                        if db.contextMenuEnabled == value then
                            return
                        end
                        db.contextMenuEnabled = value
                        ScheduleContextSettingReload()
                    end,
                    default = defaults.contextMenuEnabled
                },
                {
                    type = "header",
                    name = "|c999999 / " .. GetString(MSAL_BLIST) .. "|r",
                    width = "full"
                },
                {
                    type = "dropdown",
                    name = string.format(GetString(MSAL_REMOVE_ITEM), GetString(MSAL_BLIST)),
                    tooltip = GetString(MSAL_BLIST_TOOLTIP),
                    choices = consoleBListNames,
                    choicesValues = consoleBListIds,
                    reference = "MSAL_RemoveBList",
                    scrollable = true,
                    getFunc = function()
                        return
                    end,
                    setFunc = function(value)
                        consolePendingRemove[BLIST_TOKEN] = value
                    end
                },
                {
                    type = "button",
                    name = string.format(GetString(MSAL_REMOVE_SELECTED_ITEM), GetString(MSAL_BLIST)),
                    tooltip = GetString(MSAL_REMOVE_SELECTED_ITEM_TOOLTIP),
                    func = function()
                        local itemId = consolePendingRemove[BLIST_TOKEN]
                        if itemId and itemId ~= 0 then
                            removeListItem(itemId, BLIST_TOKEN)
                        else
                            ChatboxLog(GetString(MSAL_REMOVE_SELECTED_ITEM_HINT))
                        end
                    end
                },
                {
                    type = "header",
                    name = "|c999999 / " .. GetString(MSAL_WLIST) .. "|r",
                    width = "full"
                },
                {
                    type = "dropdown",
                    name = string.format(GetString(MSAL_REMOVE_ITEM), GetString(MSAL_WLIST)),
                    choices = consoleWListNames,
                    choicesValues = consoleWListIds,
                    reference = "MSAL_RemoveWList",
                    scrollable = true,
                    getFunc = function()
                        return
                    end,
                    setFunc = function(value)
                        consolePendingRemove[WLIST_TOKEN] = value
                    end
                },
                {
                    type = "button",
                    name = string.format(GetString(MSAL_REMOVE_SELECTED_ITEM), GetString(MSAL_WLIST)),
                    tooltip = GetString(MSAL_REMOVE_SELECTED_ITEM_TOOLTIP),
                    func = function()
                        local itemId = consolePendingRemove[WLIST_TOKEN]
                        if itemId and itemId ~= 0 then
                            removeListItem(itemId, WLIST_TOKEN)
                        else
                            ChatboxLog(GetString(MSAL_REMOVE_SELECTED_ITEM_HINT))
                        end
                    end
                },
                {
                    type = "header",
                    name = "|c999999 / " .. GetString(MSAL_WLIST) .. " (" .. GetString(SI_ITEM_ACTION_MARK_AS_JUNK) .. ")" .. "|r",
                    width = "full"
                },
                {
                    type = "dropdown",
                    name = string.format(GetString(MSAL_REMOVE_ITEM), GetString(MSAL_WLIST) .. " (" .. GetString(SI_ITEM_ACTION_MARK_AS_JUNK) .. ")"),
                    choices = consoleWListJunkNames,
                    choicesValues = consoleWListJunkIds,
                    reference = "MSAL_RemoveWListJunk",
                    scrollable = true,
                    getFunc = function()
                        return
                    end,
                    setFunc = function(value)
                        consolePendingRemove[WLIST_JUNK_TOKEN] = value
                    end
                },
                {
                    type = "button",
                    name = string.format(GetString(MSAL_REMOVE_SELECTED_ITEM),
                        GetString(MSAL_WLIST) .. " (" .. GetString(SI_ITEM_ACTION_MARK_AS_JUNK) .. ")"),
                    tooltip = GetString(MSAL_REMOVE_SELECTED_ITEM_TOOLTIP),
                    func = function()
                        local itemId = consolePendingRemove[WLIST_JUNK_TOKEN]
                        if itemId and itemId ~= 0 then
                            removeListItem(itemId, WLIST_JUNK_TOKEN)
                        else
                            ChatboxLog(GetString(MSAL_REMOVE_SELECTED_ITEM_HINT))
                        end
                    end
                }
            }
        }
        table.insert(optionsData, miscSettingsIndex + 1, consoleBWListSettings)

        local contextJunkingCheckbox = {
            type = "checkbox",
            name = GetString(MSAL_CONTEXT_MENU_JUNKING),
            tooltip = GetString(MSAL_CONTEXT_MENU_JUNKING_TOOLTIP) .. GetString(MSAL_AUTO_RELOAD),
            getFunc = function()
                return db.contextJunkingEnabled
            end,
            setFunc = function(value)
                if db.contextJunkingEnabled == value then
                    return
                end
                db.contextJunkingEnabled = value
                GAMEPAD_INVENTORY:MarkDirty()
                if GAMEPAD_INVENTORY.scene:IsShowing() then
                    GAMEPAD_INVENTORY:RefreshActiveCategoryList()
                end
                ScheduleContextSettingReload()
            end,
            default = defaults.contextJunkingEnabled
        }
        table.insert(optionsData[unwantedSettingsIndex].controls, contextJunkingCheckbox)
    end

    local autoSellJunkCheckbox = {
        type = "checkbox",
        name = GetString(MSAL_AUTO_SELL),
        tooltip = trimLastCharUTF8(GetString(SI_ITEM_FORMAT_STR_PRIORITY_SELL)) .. " / " ..
            trimLastCharUTF8(GetString(SI_ITEM_FORMAT_STR_PRIORITY_FENCE)),
        getFunc = function()
            return db.autoSellJunk
        end,
        setFunc = function(value)
            db.autoSellJunk = value
        end,
        default = defaults.autoSellJunk
    }
    table.insert(optionsData[unwantedSettingsIndex].controls, autoSellJunkCheckbox)

    if GetUnitDisplayName("player") == DecorateDisplayName(MSAL.author) then
        local legacyModeIndex = findControlIndex(generalSettingsIndex, GetString(MSAL_LEGACY_MODE))
        table.insert(optionsData[generalSettingsIndex].controls, legacyModeIndex + 1, {
            type = "checkbox",
            name = GetString(MSAL_DEBUG),
            tooltip = GetString(MSAL_DEBUG_TOOLTIP),
            getFunc = function()
                return db.debugMode
            end,
            setFunc = function(value)
                db.debugMode = value
            end,
            default = defaults.debugMode
        })
        local debugHeader = {
            type = "header",
            name = "|c999999 / " .. GetString(MSAL_GENERAL_SETTINGS_FOR_DEVS) .. "|r",
            width = "full"
        }
        table.insert(optionsData[generalSettingsIndex].controls, legacyModeIndex + 1, debugHeader)
    end

    MSAL.FoolDrop.ApplyToSettingsPanel(panelData, optionsData)

    MSAL.SettingsPanel = LAM2:RegisterAddonPanel("MuchSmarterAutoLootOptions", panelData)
    LAM2:RegisterOptionControls("MuchSmarterAutoLootOptions", optionsData)

    -- Console: rebuild LHAS-converted dropdowns via their labels (WM refresh doesn't apply).
    if ZO_IsConsoleOrGameCoreUI() then
        local consoleSettings = LibAddonMenu2.LHASConversion.settingTables["MuchSmarterAutoLootOptions"]
        if consoleSettings then
            local consoleRemoveLabels = {
                [BLIST_TOKEN] = string.format(GetString(MSAL_REMOVE_ITEM), GetString(MSAL_BLIST)),
                [WLIST_TOKEN] = string.format(GetString(MSAL_REMOVE_ITEM), GetString(MSAL_WLIST)),
                [WLIST_JUNK_TOKEN] = string.format(GetString(MSAL_REMOVE_ITEM),
                    GetString(MSAL_WLIST) .. " (" .. GetString(SI_ITEM_ACTION_MARK_AS_JUNK) .. ")"),
            }
            local function buildConsoleListItems(token)
                local names, ids = getListChoices(token, false)
                local items = {}
                for i = 1, #names do
                    items[i] = { name = names[i], data = ids[i] }
                end
                return items
            end
            local consoleRemoveDropdowns = {}
            for _, setting in ipairs(consoleSettings.settings) do
                if setting.type == LibHarvensAddonSettings.ST_DROPDOWN then
                    for token, label in pairs(consoleRemoveLabels) do
                        if setting.labelText == label then
                            setting.items = function()
                                return buildConsoleListItems(token)
                            end
                            -- Restore the highlighted entry, falling back to the first item.
                            setting.getFunction = function()
                                local itemId = consolePendingRemove[token]
                                local items = buildConsoleListItems(token)
                                if itemId and itemId ~= 0 then
                                    for _, item in ipairs(items) do
                                        if item.data == itemId then
                                            return item.name
                                        end
                                    end
                                end
                                local firstItem = items[1]
                                if firstItem and firstItem.data and firstItem.data ~= 0 then
                                    consolePendingRemove[token] = firstItem.data
                                    return firstItem.name
                                else
                                    consolePendingRemove[token] = nil
                                end
                                return nil
                            end
                            consoleRemoveDropdowns[token] = setting
                            break
                        end
                    end
                end
            end
            CALLBACK_MANAGER:RegisterCallback("MSAL-RefreshListsDropmenu", function()
                for _, setting in pairs(consoleRemoveDropdowns) do
                    if setting.control then
                        setting:UpdateControl()
                    end
                end
            end)
        end
    end

    -- it's not working as intended but I still leave it here. maybe someday I'll find the right way to refresh context-menu-added items in the list dropmenu
    -- CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
    --     if panel ~= MSAL.SettingsPanel then return end
    --     local function refresh(token)
    --         local ctrl = WM:GetControlByName(getListConfig(token).removeControlName)
    --         if ctrl then ctrl:UpdateChoices(getListChoices(token)) end
    --     end
    --     refresh(BLIST_TOKEN)
    --     refresh(WLIST_TOKEN)
    --     refresh(WLIST_JUNK_TOKEN)
    -- end)

    -- I found it!!
    local function RefreshListDropmenuItems()
        refreshRemoveDropdown(BLIST_TOKEN)
        refreshRemoveDropdown(WLIST_TOKEN)
        refreshRemoveDropdown(WLIST_JUNK_TOKEN)
    end
    CALLBACK_MANAGER:RegisterCallback("MSAL-RefreshListsDropmenu", RefreshListDropmenuItems)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
        if panel == MSAL.SettingsPanel then
            RefreshListDropmenuItems()
        end
    end)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
        if panel == MSAL.SettingsPanel then
            RefreshListDropmenuItems()
        end
    end)
end


local function FoolLoadSection()
    local FOOL_ICON_HISTORY = 10
    local FOOL_POSITION_HISTORY_MS = 1200
    local FOOL_SAMPLE_INTERVAL_MS = 100
    local FOOL_ROLL_INTERVAL_MS = 500
    local FOOL_DROP_CHANCE = 0.12
    local FOOL_TEST_CHANCE_MULTIPLIER = 2
    local FOOL_JUNK_RESCAN_MS = 2000
    local FOOL_ANIM_INTERVAL_MS = 16
    local FOOL_BEHIND_MS = 500
    local FOOL_SPAWN_HEIGHT = 2
    local FOOL_APEX_HEIGHT = 2
    local FOOL_FLIGHT_MS = 900
    local FOOL_BOUNCE_COUNT = 3
    local FOOL_BOUNCE_FACTOR = 0.45
    local FOOL_BOUNCE_DISTANCE_FACTOR = 2 / 3
    local FOOL_ICON_SIZE = 0.525
    local FOOL_SPIN_SPEED_MIN = 10
    local FOOL_SPIN_SPEED_MAX = 22
    local FOOL_SPIN_FACTOR = 0.45
    local FOOL_MAX_ACTIVE = 6

    local FOOL_CANVAS_NAME = "MSAL_FoolDropCanvas"
    local FOOL_CAMERA_NAME = FOOL_CANVAS_NAME .. "Camera"
    local FOOL_SAMPLE_NAME = "MSAL_FOOL_DROP_SAMPLE"
    local FOOL_ANIM_NAME = "MSAL_FOOL_DROP_ANIM"
    local FOOL_LOOT_EVENT = "MSAL_FOOL_DROP_LOOT"
    local FOOL_LOADED_EVENT = "MSAL_FOOL_DROP_LOADED"

    local foolCanvas
    local foolCameraControl
    local foolCamera = {}
    local foolIconPool = {}
    local foolLootedIcons = {}
    local foolJunkIcons = {}
    local foolJunkScanTime = 0
    local foolPositionSamples = {}
    local foolActiveDrops = {}
    local foolTestMode = false
    local foolRollAccumulator = 0

    local function FoolRefreshCameraBasis()
        Set3DRenderSpaceToCurrentCamera(FOOL_CAMERA_NAME)
        foolCamera.fX, foolCamera.fY, foolCamera.fZ = foolCameraControl:Get3DRenderSpaceForward()
        foolCamera.rX, foolCamera.rY, foolCamera.rZ = foolCameraControl:Get3DRenderSpaceRight()
        foolCamera.uX, foolCamera.uY, foolCamera.uZ = foolCameraControl:Get3DRenderSpaceUp()
    end

    local function FoolRecordLootedIcon(icon)
        if not icon or icon == "" then
            return
        end
        local newest = foolLootedIcons[#foolLootedIcons]
        if newest and newest.icon == icon and GetGameTimeMilliseconds() - newest.time < 1000 then
            return
        end
        foolLootedIcons[#foolLootedIcons + 1] = { icon = icon, time = GetGameTimeMilliseconds() }
        while #foolLootedIcons > FOOL_ICON_HISTORY do
            table.remove(foolLootedIcons, 1)
        end
    end

    local function FoolOnLootReceived(eventCode, receivedBy, itemLink, quantity, itemSound, lootType, lootedBySelf)
        if not lootedBySelf or not itemLink or itemLink == "" then
            return
        end
        FoolRecordLootedIcon(GetItemLinkInfo(itemLink))
    end

    local function FoolRefreshJunkIcons(now)
        foolJunkScanTime = now
        local icons, seen = {}, {}
        for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
            if IsItemJunk(BAG_BACKPACK, slotIndex) then
                local icon = GetItemInfo(BAG_BACKPACK, slotIndex)
                if icon and icon ~= "" and not seen[icon] then
                    seen[icon] = true
                    icons[#icons + 1] = icon
                end
            end
        end
        foolJunkIcons = icons
    end

    local function FoolBuildDropPool(now)
        if now - foolJunkScanTime >= FOOL_JUNK_RESCAN_MS then
            FoolRefreshJunkIcons(now)
        end

        local pool, seen = {}, {}
        for i = 1, #foolLootedIcons do
            local icon = foolLootedIcons[i].icon
            if not seen[icon] then
                seen[icon] = true
                pool[#pool + 1] = icon
            end
        end
        for i = 1, #foolJunkIcons do
            local icon = foolJunkIcons[i]
            if not seen[icon] then
                seen[icon] = true
                pool[#pool + 1] = icon
            end
        end
        return pool
    end

    local function FoolSamplePlayerPosition(now)
        local _, x, y, z = GetUnitRawWorldPosition("player")
        if not x then
            return
        end
        foolPositionSamples[#foolPositionSamples + 1] = { time = now, x = x, y = y, z = z }
        while #foolPositionSamples > 1 and now - foolPositionSamples[1].time > FOOL_POSITION_HISTORY_MS do
            table.remove(foolPositionSamples, 1)
        end
    end

    local function FoolGetPositionBehind(now)
        local target = now - FOOL_BEHIND_MS
        local older, newer
        for i = #foolPositionSamples, 1, -1 do
            if foolPositionSamples[i].time <= target then
                older = foolPositionSamples[i]
                newer = foolPositionSamples[i + 1]
                break
            end
        end
        if not older then
            return foolPositionSamples[1]
        end
        if not newer or newer.time == older.time then
            return older
        end
        local fraction = (target - older.time) / (newer.time - older.time)
        return {
            x = older.x + (newer.x - older.x) * fraction,
            y = older.y + (newer.y - older.y) * fraction,
            z = older.z + (newer.z - older.z) * fraction,
        }
    end

    local function FoolAcquireIconEntry()
        for _, entry in ipairs(foolIconPool) do
            if not entry.busy then
                entry.busy = true
                return entry
            end
        end

        local control = WINDOW_MANAGER:CreateControl(FOOL_CANVAS_NAME .. "Icon" .. (#foolIconPool + 1), foolCanvas,
            CT_TEXTURE)
        control:Create3DRenderSpace()
        control:Set3DLocalDimensions(FOOL_ICON_SIZE, FOOL_ICON_SIZE)
        control:Set3DRenderSpaceUsesDepthBuffer(true)
        control:SetHidden(true)

        local entry = { control = control, busy = true }
        foolIconPool[#foolIconPool + 1] = entry
        return entry
    end

    local function FoolReleaseEntry(entry)
        entry.control:SetHidden(true)
        entry.busy = false
    end

    local function FoolStartAnimLoop()
        EVENT_MANAGER:UnregisterForUpdate(FOOL_ANIM_NAME)
        EVENT_MANAGER:RegisterForUpdate(FOOL_ANIM_NAME, FOOL_ANIM_INTERVAL_MS, function()
            local now = GetGameTimeMilliseconds()
            FoolRefreshCameraBasis()

            for i = #foolActiveDrops, 1, -1 do
                local drop = foolActiveDrops[i]
                local elapsed = now - drop.startTime
                if elapsed >= drop.duration then
                    FoolReleaseEntry(drop.entry)
                    table.remove(foolActiveDrops, i)
                else
                    local segment = 1
                    while segment < #drop.segmentEnd and elapsed >= drop.segmentEnd[segment] do
                        segment = segment + 1
                    end
                    local segmentStart = segment == 1 and 0 or drop.segmentEnd[segment - 1]
                    local segmentElapsed = elapsed - segmentStart

                    local x = drop.startX + drop.dirX * drop.speed * elapsed / 1000
                    local z = drop.startZ + drop.dirZ * drop.speed * elapsed / 1000
                    local y
                    if segment == 1 then
                        local offsetMs = elapsed - drop.peakMs
                        y = drop.apexY - drop.arcA * offsetMs * offsetMs
                    else
                        local fraction = segmentElapsed / drop.segmentMs[segment]
                        y = drop.groundY + 4 * drop.hopHeight[segment] * fraction * (1 - fraction)
                    end

                    local alpha = 1
                    if segment > 1 then
                        alpha = 1 - (elapsed - FOOL_FLIGHT_MS) / drop.bounceMs
                    end

                    local angle = 0
                    for previous = 1, segment - 1 do
                        angle = angle + drop.spinSpeed[previous] * drop.segmentMs[previous] / 1000
                    end
                    angle = angle + drop.spinSpeed[segment] * segmentElapsed / 1000

                    local cos, sin = math.cos(angle), math.sin(angle)
                    local rightX = foolCamera.rX * cos + foolCamera.uX * sin
                    local rightY = foolCamera.rY * cos + foolCamera.uY * sin
                    local rightZ = foolCamera.rZ * cos + foolCamera.uZ * sin
                    local upX = foolCamera.uX * cos - foolCamera.rX * sin
                    local upY = foolCamera.uY * cos - foolCamera.rY * sin
                    local upZ = foolCamera.uZ * cos - foolCamera.rZ * sin

                    local control = drop.entry.control
                    control:SetAlpha(alpha)
                    control:Set3DRenderSpaceOrigin(x, y, z)
                    control:Set3DRenderSpaceForward(foolCamera.fX, foolCamera.fY, foolCamera.fZ)
                    control:Set3DRenderSpaceRight(rightX, rightY, rightZ)
                    control:Set3DRenderSpaceUp(upX, upY, upZ)
                end
            end

            if #foolActiveDrops == 0 then
                EVENT_MANAGER:UnregisterForUpdate(FOOL_ANIM_NAME)
            end
        end)
    end

    local function FoolSpawnDrop()
        if not foolCanvas or #foolActiveDrops >= FOOL_MAX_ACTIVE then
            return false
        end

        local now = GetGameTimeMilliseconds()
        local pool = FoolBuildDropPool(now)
        if #pool == 0 then
            return false
        end

        local _, playerX, playerY, playerZ = GetUnitRawWorldPosition("player")
        if not playerX then
            return false
        end

        local startX, startY, startZ = WorldPositionToGuiRender3DPosition(playerX, playerY, playerZ)
        local behind = FoolGetPositionBehind(now)
        local endX, endY, endZ
        if behind then
            endX, endY, endZ = WorldPositionToGuiRender3DPosition(behind.x, behind.y, behind.z)
        else
            endX, endY, endZ = startX, startY, startZ
        end

        local deltaX, deltaZ = endX - startX, endZ - startZ
        local distance = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)
        local apexY = startY + FOOL_SPAWN_HEIGHT + FOOL_APEX_HEIGHT

        local climbRatio = math.max(0.1, math.sqrt(math.max(0.01, apexY - endY) / FOOL_APEX_HEIGHT))
        local peakMs = FOOL_FLIGHT_MS / (1 + climbRatio)

        local drop = {
            entry = FoolAcquireIconEntry(),
            startTime = now,
            startX = startX,
            startZ = startZ,
            groundY = endY,
            dirX = distance > 0.001 and deltaX / distance or 0,
            dirZ = distance > 0.001 and deltaZ / distance or 0,
            speed = distance / (FOOL_FLIGHT_MS / 1000),
            apexY = apexY,
            arcA = FOOL_APEX_HEIGHT / (peakMs * peakMs),
            peakMs = peakMs,
            segmentEnd = {},
            segmentMs = {},
            hopHeight = {},
            spinSpeed = {},
        }

        local segmentEnd = FOOL_FLIGHT_MS
        local hopMs = FOOL_FLIGHT_MS * FOOL_BOUNCE_FACTOR * FOOL_BOUNCE_DISTANCE_FACTOR
        local hopHeight = FOOL_APEX_HEIGHT * FOOL_BOUNCE_FACTOR
        local spinBase = (FOOL_SPIN_SPEED_MIN + math.random() * (FOOL_SPIN_SPEED_MAX - FOOL_SPIN_SPEED_MIN))
            * (math.random(0, 1) == 0 and -1 or 1)
        drop.segmentEnd[1] = segmentEnd
        drop.segmentMs[1] = FOOL_FLIGHT_MS
        drop.hopHeight[1] = 0
        drop.spinSpeed[1] = spinBase
        for i = 1, FOOL_BOUNCE_COUNT do
            segmentEnd = segmentEnd + hopMs
            drop.segmentEnd[i + 1] = segmentEnd
            drop.segmentMs[i + 1] = hopMs
            drop.hopHeight[i + 1] = hopHeight
            drop.spinSpeed[i + 1] = spinBase * FOOL_SPIN_FACTOR ^ i
            hopMs = hopMs * FOOL_BOUNCE_FACTOR
            hopHeight = hopHeight * FOOL_BOUNCE_FACTOR
        end
        drop.duration = segmentEnd
        drop.bounceMs = drop.duration - FOOL_FLIGHT_MS

        local control = drop.entry.control
        control:SetTexture(pool[math.random(1, #pool)])
        control:SetHidden(false)

        foolActiveDrops[#foolActiveDrops + 1] = drop
        FoolStartAnimLoop()
        return true
    end

    local function FoolStopSampleLoop()
        EVENT_MANAGER:UnregisterForUpdate(FOOL_SAMPLE_NAME)
        foolPositionSamples = {}
        foolRollAccumulator = 0
    end

    local function FoolStartSampleLoop()
        EVENT_MANAGER:UnregisterForUpdate(FOOL_SAMPLE_NAME)
        EVENT_MANAGER:RegisterForUpdate(FOOL_SAMPLE_NAME, FOOL_SAMPLE_INTERVAL_MS, function()
            local now = GetGameTimeMilliseconds()
            FoolSamplePlayerPosition(now)

            foolRollAccumulator = foolRollAccumulator + FOOL_SAMPLE_INTERVAL_MS
            if foolRollAccumulator < FOOL_ROLL_INTERVAL_MS then
                return
            end
            foolRollAccumulator = 0
            local chance = FOOL_DROP_CHANCE
            if foolTestMode then
                chance = chance * FOOL_TEST_CHANCE_MULTIPLIER
            end
            if not IsUnitInCombat("player") and IsPlayerMoving() and math.random() < chance then
                FoolSpawnDrop()
            end
        end)
    end

    local function FoolStop()
        FoolStopSampleLoop()
        EVENT_MANAGER:UnregisterForUpdate(FOOL_ANIM_NAME)
        EVENT_MANAGER:UnregisterForEvent(FOOL_LOOT_EVENT, EVENT_LOOT_RECEIVED)
        for i = #foolActiveDrops, 1, -1 do
            FoolReleaseEntry(foolActiveDrops[i].entry)
            table.remove(foolActiveDrops, i)
        end
    end

    local function FoolIsAprilFools()
        local currentDate = os.date("*t")
        return currentDate.month == 4 and currentDate.day == 1
    end

    local function FoolIsTestMode()
        return dbAccount.aprilFoolsTest == true
    end

    local function FoolIsActive()
        return FoolIsAprilFools() or FoolIsTestMode()
    end

    local function FoolGetPanelName()
        return "|c2e5c8cL|r|c385f86y|r|c416281k|r|c4b657be|r|c546976i|r|c5d6c70o|r|c676f6bn|r|c707265'|r"
            .. "|c7a7560s|r |c83785aA|r|c8c7b55u|r|c967e4ft|r|c9f814ao|r|ca88544D|r|cb2883fr|r|cbb8b39o|r"
            .. "|cc58e34p|r|cce912e+|r"
    end

    local function FoolToggleTestMode()
        dbAccount.aprilFoolsTest = not (dbAccount.aprilFoolsTest == true)
        ReloadUI("ingame")
    end

    local function FoolInitialize()
        if GetDisplayName() == "@Lykeion" then
            SLASH_COMMANDS["/lalshed"] = FoolToggleTestMode
        end

        if not FoolIsActive() then
            return
        end

        foolTestMode = FoolIsTestMode()

        foolCanvas = WINDOW_MANAGER:CreateTopLevelWindow(FOOL_CANVAS_NAME)
        foolCanvas:SetDrawLayer(DL_BACKGROUND)
        foolCanvas:SetDrawTier(DT_LOW)
        foolCanvas:SetDrawLevel(0)
        foolCanvas:SetHidden(false)

        foolCameraControl = WINDOW_MANAGER:CreateControl(FOOL_CAMERA_NAME, foolCanvas, CT_CONTROL)
        foolCameraControl:Create3DRenderSpace()
        Set3DRenderSpaceToCurrentCamera(FOOL_CAMERA_NAME)

        EVENT_MANAGER:RegisterForEvent(FOOL_LOOT_EVENT, EVENT_LOOT_RECEIVED, FoolOnLootReceived)
        FoolStartSampleLoop()

        if foolTestMode then
            DebugPrint("[AL+] AutoDrop+ test mode is on; /lalshed turns it off again (reloads the UI)")
        end
    end

    local function FoolApplyToSettingsPanel(panelData, optionsData)
        if not FoolIsActive() then
            return
        end
        panelData.name = "Lykeion's AutoDrop+"
        panelData.displayName = FoolGetPanelName()
        for _, entry in ipairs(optionsData) do
            if entry.type == "description" then
                entry.text = GetString(MSAL_FOOL_HELP_TITLE)
                break
            end
        end
        table.insert(optionsData, 4, {
            type = "button",
            name = GetString(MSAL_FOOL_STOP_BUTTON),
            width = "full",
            tooltip = GetString(MSAL_FOOL_STOP_TOOLTIP),
            func = FoolStop,
        })
    end

    MSAL.FoolDrop = {
        IsActive = FoolIsActive,
        GetPanelName = FoolGetPanelName,
        ApplyToSettingsPanel = FoolApplyToSettingsPanel,
        Stop = FoolStop,
    }

    EVENT_MANAGER:RegisterForEvent(FOOL_LOADED_EVENT, EVENT_ADD_ON_LOADED, function(_, addon)
        if addon == "MuchSmarterAutoLoot" then
            EVENT_MANAGER:UnregisterForEvent(FOOL_LOADED_EVENT, EVENT_ADD_ON_LOADED)
            FoolInitialize()
        end
    end)
end

FoolLoadSection()
