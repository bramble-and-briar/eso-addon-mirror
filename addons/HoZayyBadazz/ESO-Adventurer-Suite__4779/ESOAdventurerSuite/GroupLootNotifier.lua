-- ESO Adventurer Suite
-- Group Loot Notifier
-- Suite-native implementation inspired by the user-supplied Group Loot Notifier feature set.
-- No standalone addon files or legacy global-handler replacements are bundled.

local EPC = ESOProgressionCoach
if not EPC then return end

EPC.GroupLootNotifier = EPC.GroupLootNotifier or {}
local N = EPC.GroupLootNotifier

N.eventNamespace = (EPC.name or "ESOAdventurerSuite") .. "_GroupLootNotifier"
N.notableHistory = N.notableHistory or {}
N.allHistory = N.allHistory or {}
N.groupAccounts = N.groupAccounts or {}
N.linkOwners = N.linkOwners or {}
N.maxHistory = 250
N.settingsInjected = false
N.initialized = false

local function default(key, value)
    EPC.defaults = EPC.defaults or {}
    if EPC.defaults[key] == nil then EPC.defaults[key] = value end
end

default("groupLootNotifierEnabled029665", true)
default("groupLootNotifierShowAll029665", false)
default("groupLootNotifierShowSetItems029665", true)
default("groupLootNotifierShowCollectibles029665", false)
default("groupLootNotifierShowUnique029665", true)
default("groupLootNotifierJewelryQuality029665", ITEM_QUALITY_ARTIFACT or 4)
default("groupLootNotifierShowCollectedSets029665", true)
default("groupLootNotifierGroupFilter029665", true)
default("groupLootNotifierShowIcons029665", true)
default("groupLootNotifierShowTraits029665", true)
default("groupLootNotifierShowTypes029665", true)
default("groupLootNotifierTimestamp029665", false)
default("groupLootNotifierLogHistory029665", true)
default("groupLootNotifierNameMode029665", "ACCOUNT")

local NOTABLE_ITEM_IDS = {
    [56862] = true,
    [56863] = true,
    [68342] = true,
    [135154] = true,
}

local UNIQUE_EXCEPTIONS = {
    [64713] = true, [64690] = true,
    [87703] = true, [139669] = true, [114427] = true,
    [139664] = true, [87702] = true, [139668] = true,
    [87705] = true, [87706] = true, [74680] = true,
    [94089] = true, [139670] = true, [94121] = true, [94122] = true,
    [133559] = true, [133225] = true, [133560] = true,
    [126581] = true, [126033] = true, [126032] = true, [126030] = true, [126031] = true,
    [94085] = true, [119561] = true, [134623] = true,
    [138711] = true, [138712] = true, [141739] = true, [141738] = true,
    [141770] = true, [139674] = true, [139673] = true, [151970] = true,
}

local JEWELRY_TRAITS = {}
for _, trait in ipairs({
    ITEM_TRAIT_TYPE_JEWELRY_ARCANE,
    ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY,
    ITEM_TRAIT_TYPE_JEWELRY_HARMONY,
    ITEM_TRAIT_TYPE_JEWELRY_HEALTHY,
    ITEM_TRAIT_TYPE_JEWELRY_INFUSED,
    ITEM_TRAIT_TYPE_JEWELRY_INTRICATE,
    ITEM_TRAIT_TYPE_JEWELRY_ORNATE,
    ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE,
    ITEM_TRAIT_TYPE_JEWELRY_ROBUST,
    ITEM_TRAIT_TYPE_JEWELRY_SWIFT,
    ITEM_TRAIT_TYPE_JEWELRY_TRIUNE,
}) do
    if trait ~= nil then JEWELRY_TRAITS[trait] = true end
end

local function saved(key, fallback)
    if EPC.saved and EPC.saved[key] ~= nil then return EPC.saved[key] end
    if EPC.defaults and EPC.defaults[key] ~= nil then return EPC.defaults[key] end
    return fallback
end

local function setSaved(key, value)
    if EPC.saved then EPC.saved[key] = value end
end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e
end

local function clearTable(t)
    if type(t) ~= "table" then return end
    for k in pairs(t) do t[k] = nil end
end

local function stripGenderSuffix(name)
    name = tostring(name or "")
    return (name:gsub("%^%a+$", ""))
end

local function pushBounded(list, value)
    list[#list + 1] = value
    local over = #list - (N.maxHistory or 250)
    if over > 0 then
        for _ = 1, over do table.remove(list, 1) end
    end
end

local function post(message)
    message = tostring(message or "")
    if CHAT_SYSTEM and type(CHAT_SYSTEM.AddMessage) == "function" then
        CHAT_SYSTEM:AddMessage(message)
    elseif type(d) == "function" then
        d(message)
    end
end

local function itemHasSet(itemLink)
    local hasSet = safeCall(GetItemLinkSetInfo, itemLink)
    return hasSet == true
end

local function getItemTypeText(itemLink, itemType, traitType)
    if saved("groupLootNotifierShowTypes029665", true) == false then return "" end

    local armorType = safeCall(GetItemLinkArmorType, itemLink)
    if armorType == ARMORTYPE_LIGHT then return "|cFFFFFFLight|r " end
    if armorType == ARMORTYPE_MEDIUM then return "|cFFFFFFMedium|r " end
    if armorType == ARMORTYPE_HEAVY then return "|cFFFFFFHeavy|r " end
    if JEWELRY_TRAITS[traitType] then return "|cFFFFFFJewelry|r " end

    if itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_WEAPON_TRAIT then
        local weaponType = safeCall(GetItemLinkWeaponType, itemLink)
        if weaponType == WEAPONTYPE_SHIELD then return "|cFFFFFFShield|r " end
        return "|cFFFFFFWeapon|r "
    end
    return ""
end

local function getTraitText(itemLink, itemType)
    if saved("groupLootNotifierShowTraits029665", true) == false then return "" end
    if itemType == ITEMTYPE_ARMOR_TRAIT or itemType == ITEMTYPE_WEAPON_TRAIT then return "" end

    local traitType = safeCall(GetItemLinkTraitInfo, itemLink)
    if traitType == nil or traitType == ITEM_TRAIT_TYPE_NONE then return "" end
    local traitName = safeCall(GetString, "SI_ITEMTRAITTYPE", traitType)
    if not traitName or traitName == "" then return "" end
    return string.format(" |cFFFFFF(%s)|r", tostring(traitName))
end

local function getIconText(itemLink, lootType)
    if saved("groupLootNotifierShowIcons029665", true) == false then return "" end

    local icon
    if lootType == LOOT_TYPE_COLLECTIBLE and type(GetCollectibleIdFromLink) == "function" then
        local collectibleId = safeCall(GetCollectibleIdFromLink, itemLink)
        if collectibleId and collectibleId ~= 0 then
            local _, _, collectibleIcon = safeCall(GetCollectibleInfo, collectibleId)
            icon = collectibleIcon
        end
    end
    if not icon or icon == "" then
        icon = safeCall(GetItemLinkInfo, itemLink)
    end
    if not icon or icon == "" then return "" end
    return string.format("|t18:18:%s|t", tostring(icon))
end

function N:RefreshGroupMembers()
    clearTable(self.groupAccounts)
    local count = tonumber(safeCall(GetGroupSize)) or 0
    for i = 1, count do
        local tag = "group" .. tostring(i)
        local characterName = safeCall(GetUnitName, tag)
        local displayName = safeCall(GetUnitDisplayName, tag)
        characterName = zo_strformat and zo_strformat(SI_UNIT_NAME, characterName or "") or tostring(characterName or "")
        if characterName ~= "" and displayName and displayName ~= "" then
            self.groupAccounts[characterName] = displayName
            self.groupAccounts[stripGenderSuffix(characterName)] = displayName
        end
    end
end

function N:RecipientLabel(receivedBy, isSelf)
    if isSelf then return "You" end
    local characterName = zo_strformat and zo_strformat(SI_UNIT_NAME, receivedBy or "") or tostring(receivedBy or "")
    if saved("groupLootNotifierNameMode029665", "ACCOUNT") == "CHARACTER" then
        return stripGenderSuffix(characterName)
    end
    return tostring(self.groupAccounts[characterName] or self.groupAccounts[stripGenderSuffix(characterName)] or stripGenderSuffix(characterName))
end

function N:IsCollectedSetPiece(itemLink)
    if not itemHasSet(itemLink) then return false end
    if type(IsItemSetCollectionPieceUnlocked) ~= "function" then return false end
    local itemId = tonumber(safeCall(GetItemLinkItemId, itemLink))
    if not itemId then return false end
    return safeCall(IsItemSetCollectionPieceUnlocked, itemId) == true
end

function N:IsNotable(itemLink, lootType, itemId)
    if saved("groupLootNotifierShowAll029665", false) == true then return true end
    if lootType ~= LOOT_TYPE_ITEM and lootType ~= LOOT_TYPE_COLLECTIBLE then return false end

    local itemType, specializedType = safeCall(GetItemLinkItemType, itemLink)
    local quality = tonumber(safeCall(GetItemLinkQuality, itemLink)) or 0
    local traitType = safeCall(GetItemLinkTraitInfo, itemLink)
    local isSet = itemHasSet(itemLink)
    local consumable = safeCall(IsItemLinkConsumable, itemLink) == true
    local groupSize = tonumber(safeCall(GetGroupSize)) or 0

    if isSet and saved("groupLootNotifierShowSetItems029665", true) ~= false then
        if saved("groupLootNotifierShowCollectedSets029665", true) == false and self:IsCollectedSetPiece(itemLink) then
            return false
        end
        return true
    end

    if JEWELRY_TRAITS[traitType] then
        local minQuality = tonumber(saved("groupLootNotifierJewelryQuality029665", ITEM_QUALITY_ARTIFACT or 4)) or (ITEM_QUALITY_ARTIFACT or 4)
        if quality >= minQuality then return true end
    end

    if lootType == LOOT_TYPE_COLLECTIBLE then
        return saved("groupLootNotifierShowCollectibles029665", false) == true
    end

    if quality >= (ITEM_QUALITY_ARTIFACT or 4) then return true end

    local uniqueEnabled = saved("groupLootNotifierShowUnique029665", true) == true
    if saved("groupLootNotifierGroupFilter029665", true) == true and groupSize > 1 then
        uniqueEnabled = false
    end
    if not uniqueEnabled then return false end
    if UNIQUE_EXCEPTIONS[itemId] then return false end
    if NOTABLE_ITEM_IDS[itemId] then return true end

    if itemId == 69059 or itemId == 64487 then
        specializedType = SPECIALIZED_ITEMTYPE_TROPHY_KEY_FRAGMENT
    end

    local keyFragment = itemType == ITEMTYPE_TROPHY and specializedType == SPECIALIZED_ITEMTYPE_TROPHY_KEY_FRAGMENT
    local special = (itemType == ITEMTYPE_TROPHY and not keyFragment)
        or itemType == ITEMTYPE_COLLECTIBLE
        or consumable
    local noTrait = traitType == nil or traitType == ITEM_TRAIT_TYPE_NONE

    if quality >= (ITEM_QUALITY_ARCANE or 3) and special then return true end
    if quality >= (ITEM_QUALITY_ARTIFACT or 4) and noTrait then return true end
    return false
end

function N:FormatLootLine(receivedBy, itemLink, quantity, lootType, isSelf)
    local itemType = safeCall(GetItemLinkItemType, itemLink)
    local traitType = safeCall(GetItemLinkTraitInfo, itemLink)
    local recipient = self:RecipientLabel(receivedBy, isSelf)
    local qty = tonumber(quantity) or 1
    local qtyText = qty > 1 and string.format(" |cFFFFFFx%d|r", qty) or ""
    local collectedText = ""
    if itemHasSet(itemLink) and not self:IsCollectedSetPiece(itemLink) then
        collectedText = " |c66FF66(not collected)|r"
    end

    local ownerKey = tostring(itemLink or "")
    if ownerKey ~= "" then
        self.linkOwners[ownerKey] = { owner = recipient, isSelf = isSelf == true, time = GetTimeStamp and GetTimeStamp() or 0 }
    end

    return string.format(
        "%s%s%s%s%s%s → |cE8B347%s|r",
        getIconText(itemLink, lootType),
        getItemTypeText(itemLink, itemType, traitType),
        tostring(itemLink or ""),
        qtyText,
        getTraitText(itemLink, itemType),
        collectedText,
        tostring(recipient)
    )
end

function N:OnLootReceived(_, receivedBy, itemLink, quantity, _, lootType, isSelf, _, _, itemId)
    if saved("groupLootNotifierEnabled029665", true) == false then return end
    if type(itemLink) ~= "string" or itemLink == "" then return end
    if lootType ~= LOOT_TYPE_ITEM and lootType ~= LOOT_TYPE_COLLECTIBLE then return end

    if not isSelf and safeCall(IsItemLinkBound, itemLink) == true then return end

    local line = self:FormatLootLine(receivedBy, itemLink, quantity, lootType, isSelf == true)
    if saved("groupLootNotifierLogHistory029665", true) == true then
        local stamp = type(GetTimeString) == "function" and tostring(GetTimeString() or "") or ""
        pushBounded(self.allHistory, stamp ~= "" and ("[" .. stamp .. "] " .. line) or line)
    end

    if not self:IsNotable(itemLink, lootType, tonumber(itemId)) then return end

    if saved("groupLootNotifierLogHistory029665", true) == true then
        local stamp = type(GetTimeString) == "function" and tostring(GetTimeString() or "") or ""
        pushBounded(self.notableHistory, stamp ~= "" and ("[" .. stamp .. "] " .. line) or line)
    end

    local prefix = "|cE8B347Loot:|r "
    if saved("groupLootNotifierTimestamp029665", false) == true and type(GetTimeString) == "function" then
        prefix = "|cBBBBBB" .. tostring(GetTimeString() or "") .. "|r " .. prefix
    end
    post(prefix .. line)
end

function N:PostHistory(which)
    local list = which == "all" and self.allHistory or self.notableHistory
    if #list == 0 then
        post("|cE8B347ESO Adventurer Suite:|r Loot history is empty.")
        return
    end
    post("|cE8B347========== Loot History ==========|r")
    for i = 1, #list do post(list[i]) end
    post("|cE8B347==================================|r")
end

function N:ClearHistory()
    clearTable(self.notableHistory)
    clearTable(self.allHistory)
    clearTable(self.linkOwners)
    post("|cE8B347ESO Adventurer Suite:|r Loot history cleared.")
end

function N:HandleSlashCommand(text)
    local command = string.lower(tostring(text or "")):match("^%s*(.-)%s*$")
    if command == "list" or command == "notable" then
        self:PostHistory("notable")
    elseif command == "listall" or command == "allhistory" then
        self:PostHistory("all")
    elseif command == "clear" then
        self:ClearHistory()
    elseif command == "on" then
        setSaved("groupLootNotifierEnabled029665", true)
        self:RefreshEvents()
        post("|cE8B347ESO Adventurer Suite:|r Group Loot Notifier enabled.")
    elseif command == "off" then
        setSaved("groupLootNotifierEnabled029665", false)
        self:RefreshEvents()
        post("|cE8B347ESO Adventurer Suite:|r Group Loot Notifier disabled.")
    elseif command == "all" then
        local enabled = saved("groupLootNotifierShowAll029665", false) ~= true
        setSaved("groupLootNotifierShowAll029665", enabled)
        post("|cE8B347ESO Adventurer Suite:|r Show all loot " .. (enabled and "enabled." or "disabled."))
    else
        post("|cE8B347/easloot|r list | listall | clear | on | off | all")
    end
end

function N:RefreshEvents()
    if not EVENT_MANAGER then return end
    EVENT_MANAGER:UnregisterForEvent(self.eventNamespace, EVENT_LOOT_RECEIVED)
    EVENT_MANAGER:UnregisterForEvent(self.eventNamespace, EVENT_GROUP_MEMBER_JOINED)
    EVENT_MANAGER:UnregisterForEvent(self.eventNamespace, EVENT_GROUP_MEMBER_LEFT)
    EVENT_MANAGER:UnregisterForEvent(self.eventNamespace, EVENT_PLAYER_ACTIVATED)

    if saved("groupLootNotifierEnabled029665", true) == false then return end

    EVENT_MANAGER:RegisterForEvent(self.eventNamespace, EVENT_LOOT_RECEIVED, function(...) N:OnLootReceived(...) end)
    EVENT_MANAGER:RegisterForEvent(self.eventNamespace, EVENT_GROUP_MEMBER_JOINED, function() N:RefreshGroupMembers() end)
    EVENT_MANAGER:RegisterForEvent(self.eventNamespace, EVENT_GROUP_MEMBER_LEFT, function() N:RefreshGroupMembers() end)
    EVENT_MANAGER:RegisterForEvent(self.eventNamespace, EVENT_PLAYER_ACTIVATED, function() N:RefreshGroupMembers() end)
end

function N:InstallLinkMenuHook()
    if self.linkMenuHooked then return end
    if type(ZO_PostHook) ~= "function" or type(ZO_LinkHandler_OnLinkMouseUp) ~= "function" then return end
    self.linkMenuHooked = true

    ZO_PostHook("ZO_LinkHandler_OnLinkMouseUp", function(link, button, control)
        if button ~= MOUSE_BUTTON_INDEX_RIGHT then return end
        local info = N.linkOwners[tostring(link or "")]
        if not info then return end

        if type(AddMenuItem) ~= "function" or type(ShowMenu) ~= "function" then return end
        if info.isSelf then
            AddMenuItem("Offer item to group", function()
                if type(StartChatInput) == "function" then
                    StartChatInput("/p " .. tostring(link) .. " - anyone need this?")
                end
            end)
        elseif info.owner and info.owner ~= "" then
            local whisperTarget = tostring(info.owner)
            AddMenuItem("Ask for item", function()
                if type(StartChatInput) == "function" then
                    StartChatInput("/w " .. whisperTarget .. " You looted " .. tostring(link) .. " - may I have it?")
                end
            end)
        end
        ShowMenu(control)
    end)
end

function N:GetSettingsOptions()
    local qualityChoices = { "Green", "Blue", "Purple", "Gold" }
    local qualityValues = {
        ITEM_QUALITY_MAGIC or 2,
        ITEM_QUALITY_ARCANE or 3,
        ITEM_QUALITY_ARTIFACT or 4,
        ITEM_QUALITY_LEGENDARY or 5,
    }

    return {
        { type = "header", name = "Group Loot Notifier" },
        {
            type = "description",
            title = "Group loot chat alerts",
            text = "Shows notable group loot in chat, keeps a lightweight session history, and adds safe right-click Ask/Offer actions to loot links. Uses event-driven updates only and does not replace ESO's global link handler or performance-meter layout.",
        },
        {
            type = "checkbox", name = "Enable Group Loot Notifier",
            getFunc = function() return saved("groupLootNotifierEnabled029665", true) end,
            setFunc = function(v) setSaved("groupLootNotifierEnabled029665", v == true) N:RefreshEvents() end,
            default = EPC.defaults.groupLootNotifierEnabled029665,
        },
        {
            type = "checkbox", name = "Show all loot",
            tooltip = "When enabled, every item/collectible loot event is shown instead of only notable loot.",
            getFunc = function() return saved("groupLootNotifierShowAll029665", false) end,
            setFunc = function(v) setSaved("groupLootNotifierShowAll029665", v == true) end,
            default = EPC.defaults.groupLootNotifierShowAll029665,
        },
        {
            type = "checkbox", name = "Show set items",
            getFunc = function() return saved("groupLootNotifierShowSetItems029665", true) end,
            setFunc = function(v) setSaved("groupLootNotifierShowSetItems029665", v == true) end,
            default = EPC.defaults.groupLootNotifierShowSetItems029665,
        },
        {
            type = "checkbox", name = "Show collectible loot",
            getFunc = function() return saved("groupLootNotifierShowCollectibles029665", false) end,
            setFunc = function(v) setSaved("groupLootNotifierShowCollectibles029665", v == true) end,
            default = EPC.defaults.groupLootNotifierShowCollectibles029665,
        },
        {
            type = "checkbox", name = "Show unique / special loot",
            tooltip = "Includes selected rare materials, high-quality special items, maps/trophies, and similar notable loot.",
            getFunc = function() return saved("groupLootNotifierShowUnique029665", true) end,
            setFunc = function(v) setSaved("groupLootNotifierShowUnique029665", v == true) end,
            default = EPC.defaults.groupLootNotifierShowUnique029665,
        },
        {
            type = "dropdown", name = "Minimum jewelry quality",
            choices = qualityChoices,
            choicesValues = qualityValues,
            getFunc = function() return tonumber(saved("groupLootNotifierJewelryQuality029665", ITEM_QUALITY_ARTIFACT or 4)) or (ITEM_QUALITY_ARTIFACT or 4) end,
            setFunc = function(v) setSaved("groupLootNotifierJewelryQuality029665", tonumber(v) or (ITEM_QUALITY_ARTIFACT or 4)) end,
            default = EPC.defaults.groupLootNotifierJewelryQuality029665,
        },
        {
            type = "checkbox", name = "Show collected set pieces",
            tooltip = "Disable to suppress set pieces that are already unlocked in your Set Collections.",
            getFunc = function() return saved("groupLootNotifierShowCollectedSets029665", true) end,
            setFunc = function(v) setSaved("groupLootNotifierShowCollectedSets029665", v == true) end,
            default = EPC.defaults.groupLootNotifierShowCollectedSets029665,
        },
        {
            type = "checkbox", name = "Reduce unique-item noise while grouped",
            tooltip = "When grouped, focuses the notifier on set/high-value loot instead of miscellaneous unique reward items.",
            getFunc = function() return saved("groupLootNotifierGroupFilter029665", true) end,
            setFunc = function(v) setSaved("groupLootNotifierGroupFilter029665", v == true) end,
            default = EPC.defaults.groupLootNotifierGroupFilter029665,
        },
        {
            type = "dropdown", name = "Group member name format",
            choices = { "Account name", "Character name" },
            choicesValues = { "ACCOUNT", "CHARACTER" },
            getFunc = function() return saved("groupLootNotifierNameMode029665", "ACCOUNT") end,
            setFunc = function(v) setSaved("groupLootNotifierNameMode029665", v == "CHARACTER" and "CHARACTER" or "ACCOUNT") end,
            default = EPC.defaults.groupLootNotifierNameMode029665,
        },
        {
            type = "checkbox", name = "Show item icons",
            getFunc = function() return saved("groupLootNotifierShowIcons029665", true) end,
            setFunc = function(v) setSaved("groupLootNotifierShowIcons029665", v == true) end,
            default = EPC.defaults.groupLootNotifierShowIcons029665,
            width = "half",
        },
        {
            type = "checkbox", name = "Show item traits",
            getFunc = function() return saved("groupLootNotifierShowTraits029665", true) end,
            setFunc = function(v) setSaved("groupLootNotifierShowTraits029665", v == true) end,
            default = EPC.defaults.groupLootNotifierShowTraits029665,
            width = "half",
        },
        {
            type = "checkbox", name = "Show item type",
            getFunc = function() return saved("groupLootNotifierShowTypes029665", true) end,
            setFunc = function(v) setSaved("groupLootNotifierShowTypes029665", v == true) end,
            default = EPC.defaults.groupLootNotifierShowTypes029665,
            width = "half",
        },
        {
            type = "checkbox", name = "Show timestamps",
            getFunc = function() return saved("groupLootNotifierTimestamp029665", false) end,
            setFunc = function(v) setSaved("groupLootNotifierTimestamp029665", v == true) end,
            default = EPC.defaults.groupLootNotifierTimestamp029665,
            width = "half",
        },
        {
            type = "checkbox", name = "Keep session loot history",
            tooltip = "Keeps up to 250 recent entries in memory for /easloot list and /easloot listall. History resets when the UI reloads.",
            getFunc = function() return saved("groupLootNotifierLogHistory029665", true) end,
            setFunc = function(v) setSaved("groupLootNotifierLogHistory029665", v == true) end,
            default = EPC.defaults.groupLootNotifierLogHistory029665,
        },
        {
            type = "button", name = "Post notable loot history",
            func = function() N:PostHistory("notable") end,
            width = "half",
        },
        {
            type = "button", name = "Clear loot history",
            func = function() N:ClearHistory() end,
            width = "half",
        },
    }
end

function N:Initialize()
    if self.initialized then return end
    self.initialized = true
    self:RefreshGroupMembers()
    self:RefreshEvents()
    self:InstallLinkMenuHook()

    SLASH_COMMANDS["/easloot"] = function(text) N:HandleSlashCommand(text) end
    if not SLASH_COMMANDS["/loot"] then
        SLASH_COMMANDS["/loot"] = function(text) N:HandleSlashCommand(text) end
    end
end


if EVENT_MANAGER then
    EVENT_MANAGER:RegisterForEvent(N.eventNamespace .. "_Load", EVENT_ADD_ON_LOADED, function(_, addonName)
        if addonName ~= EPC.name then return end
        EVENT_MANAGER:UnregisterForEvent(N.eventNamespace .. "_Load", EVENT_ADD_ON_LOADED)
        if type(zo_callLater) == "function" then
            zo_callLater(function() N:Initialize() end, 0)
        else
            N:Initialize()
        end
    end)
end

EPC.groupLootNotifier029665 = true
