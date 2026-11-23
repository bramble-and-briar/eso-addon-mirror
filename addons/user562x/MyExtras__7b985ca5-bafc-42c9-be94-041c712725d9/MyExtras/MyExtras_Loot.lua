local ME = MyExtras
local Loot = {}
ME.Loot = Loot

--------------------------------------------------
-- Config
--------------------------------------------------
local LOOT_FEATURE  = "Loot"
local TRADE_FEATURE = "Trade"
local BIND_FEATURE  = "Bind"
local EVENT_NAME    = "MyExtras_Loot"
local MAX_MESSAGE   = 345
local BIND_STEP_MS  = 250
local BIND_CHECK_MS = 800
local REQUEST_TEXT  = "If you don't need %s, could I have it?"
local NAME_COLOR    = "FFFFFF"
local REQUEST_COLOR = "FF9900"

local DEFAULTS = {
    lootEnabled   = false,
    lootSets      = true,
    lootSetsHave  = false,
    lootNotable   = false,
    lootMaterials = false,
    lootOther     = false,
    lootSelf      = true,
    lootGroup     = true,
    lootHideLog   = true,
}

local scope = ME:NewScope("lootCharSettings")
scope:AddDefaults(DEFAULTS, "loot")
Loot.defaults = scope.defaults

Loot.showChoices = {
    { name = "Missing Set Items",   value = "lootSets"      },
    { name = "Collected Set Items", value = "lootSetsHave"  },
    { name = "Notable",             value = "lootNotable"   },
    { name = "Materials",           value = "lootMaterials" },
    { name = "Everything Else",     value = "lootOther"     },
}

Loot.whoChoices = {
    { name = "You",   value = "lootSelf"  },
    { name = "Group", value = "lootGroup" },
}

local requests = {}
local requestOrder = {}
local nextRequest = 0
local REQUEST_KEEP = 50
local keybindHooked = false
local watching = false
local linked = {}
local binding = false
local lootLogHooked = false

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return scope:Settings()
end

local function CV()
    return ME.charVariables
end

local function Say(feature, text)
    ME:Chat(ME:ChatPrefix(feature) .. text)
end

local function Plural(count, word)
    if count == 1 then return "1 " .. word end
    return ZO_CommaDelimitNumber(count) .. " " .. word .. "s"
end

local function ItemText(itemLink)
    return ME:Icon(GetItemLinkIcon(itemLink)) .. itemLink
end

local function UserName(displayName)
    if type(ZO_FormatUserFacingDisplayName) == "function" then
        return ZO_FormatUserFacingDisplayName(displayName)
    end
    return displayName
end

local function IsGearType(itemType)
    return itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR
end

local function IsSetItem(itemLink)
    local itemType = GetItemLinkItemType(itemLink)
    return IsGearType(itemType) and GetItemLinkSetInfo(itemLink) == true
end

local function IsMissingPiece(itemLink)
    if IsItemLinkLockedSetPiece then return IsItemLinkLockedSetPiece(itemLink) == true end
    if not (IsItemLinkSetCollectionPiece and IsItemLinkSetCollectionPiece(itemLink)) then return false end
    return not IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink))
end

local LEARN_TYPES = {
    ITEMTYPE_RACIAL_STYLE_MOTIF,
    ITEMTYPE_RECIPE,
    ITEMTYPE_CRAFTED_ABILITY,
    ITEMTYPE_CRAFTED_ABILITY_SCRIPT,
}

local NOTABLE_SPECIALIZED = {
    SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP,
    SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH,
    SPECIALIZED_ITEMTYPE_CONTAINER_STACKABLE,
}

local function InList(list, value)
    if value == nil then return false end
    for i = 1, #list do
        if list[i] ~= nil and list[i] == value then return true end
    end
    return false
end

local function IsNotable(itemLink)
    local itemType, specialized = GetItemLinkItemType(itemLink)
    if InList(LEARN_TYPES, itemType) or InList(NOTABLE_SPECIALIZED, specialized) then return true end
    if CanItemLinkBeUsedToLearn and CanItemLinkBeUsedToLearn(itemLink) then return true end
    local quality = GetItemLinkFunctionalQuality(itemLink)
    return ITEM_FUNCTIONAL_QUALITY_LEGENDARY ~= nil and quality ~= nil and quality >= ITEM_FUNCTIONAL_QUALITY_LEGENDARY
end

local function IsMaterial(itemLink)
    return CanItemLinkBeVirtual ~= nil and CanItemLinkBeVirtual(itemLink) == true
end

local function Kind(itemLink)
    if IsSetItem(itemLink) then
        if IsMissingPiece(itemLink) then return "lootSets" end
        return "lootSetsHave"
    end
    if IsMaterial(itemLink) then return "lootMaterials" end
    if IsNotable(itemLink) then return "lootNotable" end
    return "lootOther"
end

local function OwnedCount(itemLink)
    local total = 0
    local counts = { GetItemLinkStacks(itemLink) }
    for i = 1, math.min(#counts, 5) do
        total = total + (tonumber(counts[i]) or 0)
    end
    return total
end

local function GroupDisplayName(characterName)
    local plain = zo_strformat(SI_UNIT_NAME, characterName)
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        if tag then
            local raw = GetRawUnitName(tag)
            if raw == characterName or zo_strformat(SI_UNIT_NAME, raw) == plain then
                return GetUnitDisplayName(tag)
            end
        end
    end
    return nil, plain
end

--------------------------------------------------
-- Request
--------------------------------------------------
local function LatestChatEntry()
    local entries = CHAT_MENU_GAMEPAD and CHAT_MENU_GAMEPAD.messageEntries
    if type(entries) ~= "table" then return nil end
    return entries[#entries]
end

local function KeepRequest(displayName, itemLink)
    nextRequest = nextRequest + 1
    requests[nextRequest] = { displayName = displayName, itemLink = itemLink }
    requestOrder[#requestOrder + 1] = nextRequest
    if #requestOrder > REQUEST_KEEP then
        requests[table.remove(requestOrder, 1)] = nil
    end
    return nextRequest
end

local function SelectedRequest()
    local list = CHAT_MENU_GAMEPAD and CHAT_MENU_GAMEPAD.list
    if not (list and list.GetTargetData) then return nil end
    local target = list:GetTargetData()
    local id = target and type(target.data) == "table" and target.data.myExtrasRequestId
    return id and requests[id] or nil
end

local function SendRequest(entry)
    local text = string.format(REQUEST_TEXT, entry.itemLink)
    if type(StartChatInput) == "function" then
        StartChatInput(text, CHAT_CHANNEL_WHISPER, entry.displayName)
    elseif ZO_GetChatSystem then
        ZO_GetChatSystem():StartTextEntry(text, CHAT_CHANNEL_WHISPER, entry.displayName)
    end
end

local function HookRequestKeybind()
    if keybindHooked then return end
    local descriptor = CHAT_MENU_GAMEPAD and CHAT_MENU_GAMEPAD.chatEntryListKeybindDescriptor
    if type(descriptor) ~= "table" then return end
    for i = 1, #descriptor do
        local button = descriptor[i]
        if button.keybind == "UI_SHORTCUT_PRIMARY" then
            local name, enabled, visible, callback = button.name, button.enabled, button.visible, button.callback
            button.name = function(...)
                if SelectedRequest() then return "Request" end
                if type(name) == "function" then return name(...) end
                return name
            end
            button.enabled = function(...)
                if SelectedRequest() then return true end
                if type(enabled) == "function" then return enabled(...) end
                return enabled == nil or enabled == true
            end
            button.visible = function(...)
                if SelectedRequest() then return true end
                if type(visible) == "function" then return visible(...) end
                return visible == nil or visible == true
            end
            button.callback = function(...)
                local entry = SelectedRequest()
                if entry then
                    SendRequest(entry)
                    return
                end
                if callback then return callback(...) end
            end
            keybindHooked = true
            return
        end
    end
end

--------------------------------------------------
-- Loot In Chat
--------------------------------------------------
local function ShouldShow(kind, isSelf)
    local sv = SV()
    if not sv.lootEnabled or not sv[kind] then return false end
    if isSelf then return sv.lootSelf == true end
    return sv.lootGroup == true
end

local function PrintLoot(who, itemLink, quantity, kind, requestFrom)
    local text = "|c" .. NAME_COLOR .. who .. "|r " .. ItemText(itemLink)
    if (tonumber(quantity) or 1) > 1 then text = text .. " x" .. ZO_CommaDelimitNumber(quantity) end
    if kind == "lootMaterials" then
        text = text .. " (you have " .. ZO_CommaDelimitNumber(OwnedCount(itemLink)) .. ")"
    end
    local requestId
    if requestFrom then
        requestId = KeepRequest(requestFrom, itemLink)
        text = text .. "  |c" .. REQUEST_COLOR .. "[Request]|r"
        HookRequestKeybind()
    end
    local before = LatestChatEntry()
    Say(LOOT_FEATURE, text)
    if requestId then
        local entry = LatestChatEntry()
        if entry and entry ~= before and type(entry.data) == "table" then
            entry.data.myExtrasRequestId = requestId
        end
    end
end

local function OnLootReceived(_, receivedBy, itemLink, quantity, _, lootType, isSelf)
    if lootType ~= LOOT_TYPE_ITEM or type(itemLink) ~= "string" or itemLink == "" then return end
    if not SV().lootEnabled then return end
    itemLink = string.gsub(itemLink, "^|H%d:", "|H1:", 1)
    local kind = Kind(itemLink)
    if not ShouldShow(kind, isSelf) then return end
    if isSelf then
        PrintLoot("You", itemLink, quantity, kind)
        return
    end
    local displayName, plain = GroupDisplayName(receivedBy)
    local who = displayName and UserName(displayName) or plain or tostring(receivedBy)
    local requestFrom
    if displayName and kind == "lootSets" then
        requestFrom = displayName
    end
    PrintLoot(who, itemLink, quantity, kind, requestFrom)
end

--------------------------------------------------
-- Loot Log
--------------------------------------------------
local function HideFromLog(itemLink, lootType)
    local sv = SV()
    if not (sv.lootEnabled and sv.lootHideLog) then return false end
    if lootType ~= LOOT_TYPE_ITEM or type(itemLink) ~= "string" or itemLink == "" then return false end
    return ShouldShow(Kind(itemLink), true)
end

local function HookLootLog()
    if lootLogHooked then return end
    local history = rawget(_G, "ZO_LootHistory_Shared")
    if type(history) ~= "table" or type(history.OnNewItemReceived) ~= "function" then return end
    lootLogHooked = true
    ZO_PreHook(history, "OnNewItemReceived", function(_, itemLink, _, _, lootType)
        local ok, hide = pcall(HideFromLog, itemLink, lootType)
        return ok and hide == true
    end)
end

--------------------------------------------------
-- Trade List
--------------------------------------------------
local function TradeData()
    local cv = CV()
    if type(cv.lootTradeIds) ~= "table" then cv.lootTradeIds = {} end
    return cv
end

local function UniqueKey(bagId, slotIndex)
    local id = GetItemUniqueId(bagId, slotIndex)
    if not id then return nil end
    return Id64ToString(id)
end

local function InGroupInstance()
    if not (IsUnitInDungeon("player") or (IsPlayerInRaid and IsPlayerInRaid())) then return false end
    local difficulty = GetCurrentZoneDungeonDifficulty()
    return difficulty ~= nil and difficulty ~= DUNGEON_DIFFICULTY_NONE
end

local function CheckZone()
    if not InGroupInstance() then return end
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    local data = TradeData()
    if data.lootTradeZone ~= zoneId then
        data.lootTradeZone = zoneId
        data.lootTradeIds = {}
        linked = {}
    end
end

local function OnNewItem(_, bagId, slotIndex, isNewItem)
    if not isNewItem or not IsItemBoPAndTradeable(bagId, slotIndex) then return end
    local key = UniqueKey(bagId, slotIndex)
    if key then TradeData().lootTradeIds[key] = true end
end

local function IsEligible(bagId, slotIndex)
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and not AreUnitsEqual("player", tag) and IsUnitOnline(tag) then
            local displayName = GetUnitDisplayName(tag)
            if IsDisplayNameInItemBoPAccountTable then
                if IsDisplayNameInItemBoPAccountTable(bagId, slotIndex, UndecorateDisplayName(displayName)) then return true end
            else
                for n = 1, GetItemBoPTradeableNumEligibleNames(bagId, slotIndex) do
                    local name = GetItemBoPTradeableEligibleNameByIndex(bagId, slotIndex, n)
                    if name == displayName or name == UndecorateDisplayName(displayName) then return true end
                end
            end
        end
    end
    return false
end

local function TradeCandidates()
    local ids = TradeData().lootTradeIds
    local found, seen = {}, {}
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local key = UniqueKey(BAG_BACKPACK, slotIndex)
        if key and ids[key] then
            seen[key] = true
            if IsItemBoPAndTradeable(BAG_BACKPACK, slotIndex)
                and (GetItemBoPTimeRemainingSeconds(BAG_BACKPACK, slotIndex) or 0) > 0
                and not IsItemPlayerLocked(BAG_BACKPACK, slotIndex) then
                local itemLink = GetItemLink(BAG_BACKPACK, slotIndex, LINK_STYLE_BRACKETS)
                if IsItemLinkSetCollectionPiece(itemLink) and not IsItemLinkLockedSetPiece(itemLink)
                    and IsEligible(BAG_BACKPACK, slotIndex) then
                    found[#found + 1] = { key = key, itemLink = itemLink }
                end
            else
                ids[key] = nil
            end
        end
    end
    for key in pairs(ids) do
        if not seen[key] then ids[key] = nil end
    end
    return found
end

function Loot:LinkUnwanted()
    if not IsUnitGrouped("player") then
        Say(TRADE_FEATURE, "You're not in a group.")
        return
    end
    local candidates = TradeCandidates()
    local fresh = {}
    for i = 1, #candidates do
        if not linked[candidates[i].key] then fresh[#fresh + 1] = candidates[i] end
    end
    if #fresh == 0 then
        linked = {}
        Say(TRADE_FEATURE, "Nothing left to link.")
        return
    end
    local parts, length, used = {}, 0, 0
    for i = 1, #fresh do
        local itemLink = fresh[i].itemLink
        local added = #itemLink + (#parts > 0 and 1 or 0)
        if #parts > 0 and length + added > MAX_MESSAGE then break end
        parts[#parts + 1] = itemLink
        length = length + added
        linked[fresh[i].key] = true
        used = i
    end
    local left = #fresh - used
    if left > 0 then
        Say(TRADE_FEATURE, Plural(left, "more item") .. ", use /tuw again.")
    end
    local text = table.concat(parts, " ")
    zo_callLater(function()
        if type(StartChatInput) == "function" then
            StartChatInput(text, CHAT_CHANNEL_PARTY)
        else
            ZO_GetChatSystem():StartTextEntry(text, CHAT_CHANNEL_PARTY)
        end
    end, 100)
end

--------------------------------------------------
-- Bind All
--------------------------------------------------
local function BindCandidates()
    local found = {}
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if IsGearType(GetItemType(BAG_BACKPACK, slotIndex))
            and not IsItemBound(BAG_BACKPACK, slotIndex)
            and not IsItemPlayerLocked(BAG_BACKPACK, slotIndex) then
            local itemLink = GetItemLink(BAG_BACKPACK, slotIndex, LINK_STYLE_BRACKETS)
            if IsItemLinkSetCollectionPiece(itemLink)
                and not IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink)) then
                found[#found + 1] = { slotIndex = slotIndex, itemId = GetItemLinkItemId(itemLink), uniqueId = UniqueKey(BAG_BACKPACK, slotIndex) }
            end
        end
    end
    return found
end

function Loot:BindAll()
    if binding then return end
    if IsUnitInCombat("player") then
        Say(BIND_FEATURE, "You can't bind items during combat.")
        return
    end
    local list = BindCandidates()
    if #list == 0 then
        Say(BIND_FEATURE, "Nothing to bind.")
        return
    end
    binding = true
    local index, bound = 0, {}
    local function Finish()
        zo_callLater(function()
            local count = 0
            for i = 1, #bound do
                local item = bound[i]
                if UniqueKey(BAG_BACKPACK, item.slotIndex) == item.uniqueId and IsItemBound(BAG_BACKPACK, item.slotIndex) then
                    count = count + 1
                end
            end
            binding = false
            if count == 0 then
                Say(BIND_FEATURE, "Nothing to bind.")
            else
                Say(BIND_FEATURE, "Bound " .. Plural(count, "item") .. ".")
            end
        end, BIND_CHECK_MS)
    end
    local function Step()
        index = index + 1
        local item = list[index]
        if not item or IsUnitInCombat("player") then
            Finish()
            return
        end
        if UniqueKey(BAG_BACKPACK, item.slotIndex) == item.uniqueId
            and not IsItemBound(BAG_BACKPACK, item.slotIndex)
            and not IsItemSetCollectionPieceUnlocked(item.itemId) then
            if ME:CallGame("BindItem", BAG_BACKPACK, item.slotIndex) then bound[#bound + 1] = item end
        end
        zo_callLater(Step, BIND_STEP_MS)
    end
    Step()
end

--------------------------------------------------
-- Commands
--------------------------------------------------
local function RegisterCommands()
    if not SLASH_COMMANDS then return end
    local link = function() Loot:LinkUnwanted() end
    local bind = function() Loot:BindAll() end
    SLASH_COMMANDS["/tuw"] = link
    SLASH_COMMANDS["/tradeunwanted"] = link
    SLASH_COMMANDS["/bindall"] = bind
end

--------------------------------------------------
-- Apply
--------------------------------------------------
function Loot:Refresh()
    local on = SV().lootEnabled == true
    if on and not watching then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME .. "Received", EVENT_LOOT_RECEIVED, OnLootReceived)
    elseif not on and watching then
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAME .. "Received", EVENT_LOOT_RECEIVED)
    end
    watching = on
end

--------------------------------------------------
-- Menu
--------------------------------------------------
local function ChecklistValues(choices)
    local sv = SV()
    local values = {}
    for i = 1, #choices do
        local key = choices[i].value
        if sv[key] then values[#values + 1] = key end
    end
    return values
end

local function SaveChecklist(choices, values)
    local sv = SV()
    local set = {}
    if type(values) == "table" then
        for i = 1, #values do set[values[i]] = true end
    end
    for i = 1, #choices do
        local key = choices[i].value
        sv[key] = set[key] == true
    end
end

local function DefaultValues(choices)
    local values = {}
    for i = 1, #choices do
        local key = choices[i].value
        if DEFAULTS[key] then values[#values + 1] = key end
    end
    return values
end

function Loot:PageOption()
    local defaults = DEFAULTS
    local function IsOff() return not SV().lootEnabled end

    return {
        type    = "submenu",
        name    = "Loot",
        tooltip = function()
            return "Shows loot in chat and helps you trade set pieces.\n\n"
                .. "/tuw: links your tradeable set pieces from this trial or dungeon in group chat. Use it again for more.\n\n"
                .. ME:SavedTip(scope, "loot")
        end,
        options = {
            {
                type    = "toggle",
                name    = "Enabled",
                preset  = "YES_NO",
                default = defaults.lootEnabled,
                tooltip = "Shows a message in chat for each item you or your group loot.\n\n"
                       .. "When someone in your group loots a set piece you haven't collected, the message ends with [Request]. "
                       .. "Highlight it in text chat and press Request to whisper them asking for it. "
                       .. "You still press send yourself.",
                getFunc = function() return SV().lootEnabled end,
                setFunc = function(val)
                    SV().lootEnabled = val
                    Loot:Refresh()
                end,
            },
            ME:CharacterOption(scope, "loot", function() Loot:Refresh() end),
            {
                type     = "checklist",
                name     = "Show",
                choices  = self.showChoices,
                default  = DefaultValues(self.showChoices),
                disabled = IsOff,
                tooltip  = "Which items show in chat.\n\n"
                        .. "Missing Set Items: set pieces you haven't collected yet.\n"
                        .. "Collected Set Items: set pieces you already have.\n"
                        .. "Notable: motifs, recipes, style pages, runeboxes, scribing items, treasure maps "
                        .. "and gold quality items.\n"
                        .. "Materials: anything that goes in the craft bag. Also shows how many you have.\n"
                        .. "Everything Else: all other items.",
                getFunc  = function() return ChecklistValues(Loot.showChoices) end,
                setFunc  = function(values) SaveChecklist(Loot.showChoices, values) end,
            },
            {
                type     = "checklist",
                name     = "Whose Loot",
                choices  = self.whoChoices,
                default  = DefaultValues(self.whoChoices),
                disabled = IsOff,
                tooltip  = "Whose loot shows in chat.\n\n"
                        .. "You: what you loot.\n"
                        .. "Group: what your group members loot.",
                getFunc  = function() return ChecklistValues(Loot.whoChoices) end,
                setFunc  = function(values) SaveChecklist(Loot.whoChoices, values) end,
            },
            {
                type     = "toggle",
                name     = "Hide In Loot Log",
                preset   = "YES_NO",
                default  = defaults.lootHideLog,
                disabled = function() return IsOff() or not SV().lootSelf end,
                tooltip  = "Your loot that shows in chat doesn't show in the game's loot log.",
                getFunc  = function() return SV().lootHideLog end,
                setFunc  = function(val) SV().lootHideLog = val end,
            },
        },
    }
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function Loot:Init()
    RegisterCommands()
    HookLootLog()
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME .. "New", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnNewItem)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAME .. "New", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    if CHAT_MENU_GAMEPAD and type(CHAT_MENU_GAMEPAD.OnShow) == "function" then
        ZO_PreHook(CHAT_MENU_GAMEPAD, "OnShow", function() HookRequestKeybind() end)
    end
    self:Refresh()
end

function Loot:OnPlayerActivated()
    RegisterCommands()
    HookLootLog()
    CheckZone()
end

function Loot:ResetSkipKeys()
    return scope:ResetSkipKeys()
end

function Loot:OnReset()
    scope:ResetCharacter()
    self:Refresh()
end

ME:RegisterFeature(Loot)
