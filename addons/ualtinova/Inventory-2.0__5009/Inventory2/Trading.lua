InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- Selling is a different job from keeping a bag tidy: nobody wants to open four levels of groups
-- to get rid of a white sword. While a merchant, a fence, a guild store, a trade or a mail is
-- open, the bag is laid out flat instead: a handful of categories, every one of them open, the
-- items right under their header.

local ART = "EsoUI/Art/Inventory/inventory_tabIcon_"

-- sort: "quality" = worst first (whites on top, golds at the bottom, so the things you are most
-- likely to sell come first), "value" = most expensive first, "name" = alphabetical.
IG.TRADE_CATEGORIES = {
    -- What you already decided to sell, before anything you have yet to decide about.
    { key = "TRADE_SELL",      label = "Sell",                color = "FF9A2E", icon = "EsoUI/Art/currency/currency_gold.dds", sort = "value", from = "SELL" },
    -- And what you decided to sell somewhere else, right behind it. Both are decisions already
    -- made, and the reason the flat layout exists is to put those where the hand lands first --
    -- at a guild store this is the errand itself, and at a merchant it is the one run you want
    -- to read before you start selling, so that nothing in it goes for vendor money by mistake.
    -- Its name and colour follow the category's, which the player can change.
    { key = "TRADE_GUILD",     label = "Sell [Guild Store]",  color = "F2D479", icon = "EsoUI/Art/MainMenu/menuBar_guilds_up.dds", sort = "value", from = "GUILDSELL" },
    { key = "TRADE_SETS",      label = "Set Pieces",          color = "B98CFF", icon = ART .. "armor_up.dds",       sort = "quality" },
    { key = "TRADE_GEAR",      label = "Gear Without a Set",  color = "7FB2FF", icon = ART .. "weapons_up.dds",     sort = "quality" },
    { key = "TRADE_TREASURE",  label = "Treasures and Trash", color = "FFD24A", icon = ART .. "junk_up.dds",        sort = "value" },
    { key = "TRADE_MATERIALS", label = "Materials",           color = "5CE07A", icon = ART .. "crafting_up.dds",    sort = "name" },
    { key = "TRADE_OTHER",     label = "Consumables and Other", color = "E8A0B4", icon = ART .. "consumables_up.dds", sort = "name" },
}

local CATEGORY_BY_KEY, paths = {}, {}
for order, category in ipairs(IG.TRADE_CATEGORIES) do
    category.order = order
    CATEGORY_BY_KEY[category.key] = category
    -- One shared path per category: every item in it points at the same node.
    paths[category.key] = { { id = category.key, label = category.label, color = category.color, icon = category.icon } }
end

-- Item types are looked up by name, so one the game drops or renames can't break the file.
local function TypeSet(names)
    local set = {}
    for _, name in ipairs(names) do
        if _G[name] ~= nil then set[_G[name]] = true end
    end
    return set
end

local GEAR_TYPES = TypeSet({ "ITEMTYPE_WEAPON", "ITEMTYPE_ARMOR" })
local TREASURE_TYPES = TypeSet({ "ITEMTYPE_TREASURE", "ITEMTYPE_TRASH", "ITEMTYPE_COLLECTIBLE", "ITEMTYPE_TROPHY" })
local MATERIAL_TYPES = TypeSet({
    "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL", "ITEMTYPE_BLACKSMITHING_MATERIAL", "ITEMTYPE_BLACKSMITHING_BOOSTER",
    "ITEMTYPE_CLOTHIER_RAW_MATERIAL", "ITEMTYPE_CLOTHIER_MATERIAL", "ITEMTYPE_CLOTHIER_BOOSTER",
    "ITEMTYPE_WOODWORKING_RAW_MATERIAL", "ITEMTYPE_WOODWORKING_MATERIAL", "ITEMTYPE_WOODWORKING_BOOSTER",
    "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL", "ITEMTYPE_JEWELRYCRAFTING_MATERIAL",
    "ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER", "ITEMTYPE_JEWELRYCRAFTING_BOOSTER",
    "ITEMTYPE_JEWELRY_RAW_TRAIT", "ITEMTYPE_JEWELRY_TRAIT",
    "ITEMTYPE_RAW_MATERIAL", "ITEMTYPE_STYLE_MATERIAL", "ITEMTYPE_ARMOR_TRAIT", "ITEMTYPE_WEAPON_TRAIT",
    "ITEMTYPE_REAGENT", "ITEMTYPE_POTION_BASE", "ITEMTYPE_POISON_BASE", "ITEMTYPE_INGREDIENT",
    "ITEMTYPE_ENCHANTING_RUNE_ASPECT", "ITEMTYPE_ENCHANTING_RUNE_ESSENCE", "ITEMTYPE_ENCHANTING_RUNE_POTENCY",
    "ITEMTYPE_ENCHANTMENT_BOOSTER", "ITEMTYPE_FURNISHING_MATERIAL",
    "ITEMTYPE_GLYPH_ARMOR", "ITEMTYPE_GLYPH_WEAPON", "ITEMTYPE_GLYPH_JEWELRY",
})

local function CategoryKey(slotData)
    local aside = IG.SetAsideKey and IG.SetAsideKey(slotData)
    if aside == "SELL" then return "TRADE_SELL" end
    if aside == "GUILDSELL" then return "TRADE_GUILD" end
    local itemType = slotData.itemType
    if GEAR_TYPES[itemType] then
        local hasSet = GetItemLinkSetInfo(GetItemLink(slotData.bagId, slotData.slotIndex), false)
        return hasSet and "TRADE_SETS" or "TRADE_GEAR"
    end
    if TREASURE_TYPES[itemType] then return "TRADE_TREASURE" end
    if MATERIAL_TYPES[itemType] then return "TRADE_MATERIALS" end
    return "TRADE_OTHER"
end

-- The real category a trading heading stands for (SELL, GUILDSELL), or nil for the ones that
-- exist only in this layout. Its menu repaints that category, so both layouts wear one colour.
function IG.TradingSourceKey(key)
    local category = CATEGORY_BY_KEY[key]
    if category then return category.from, true end
    return key, false
end

function IG.GetTradingPath(slotData)
    local key = CategoryKey(slotData)
    local path = paths[key]
    -- A category that stands for one of the real ones is called whatever that one is called
    -- right now: it can be renamed from its header, and a heading here still saying the name it
    -- shipped with would read as somewhere else entirely. Written onto the shared node rather
    -- than into a new one, so the whole layout goes on pointing at one node per category.
    local from = CATEGORY_BY_KEY[key].from
    if from then
        path[1].label = IG.GetGroupLabel(from)
        path[1].color = IG.GetGroupColor(from)
    end
    return path
end

-- A set piece that isn't in the set collection yet: selling it would lose it for good.
function IG.IsUncollectedPiece(slotData)
    if not GEAR_TYPES[slotData.itemType] then return false end
    local itemLink = GetItemLink(slotData.bagId, slotData.slotIndex)
    return IsItemLinkSetCollectionPiece(itemLink)
        and not IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink))
end

-- At a guild store the guild store pile is the errand and set pieces are what gets listed next,
-- so those two lead there; everywhere else the table's own order stands.
local GUILD_STORE_FIRST = { TRADE_GUILD = -2, TRADE_SETS = -1 }
-- Asked once per sort (IG.PrepareTradingSort, from the list build) rather than once per
-- comparison: the comparator runs n log n times and the scene question is the same each time.
local atGuildStore = false
function IG.PrepareTradingSort()
    atGuildStore = SCENE_MANAGER:IsShowing("tradinghouse")
end
local function CategoryOrder(category)
    if atGuildStore then
        return GUILD_STORE_FIRST[category.key] or category.order
    end
    return category.order
end

function IG.CompareTradingEntries(a, b)
    local categoryA, categoryB = CATEGORY_BY_KEY[a.igPath[1].id], CATEGORY_BY_KEY[b.igPath[1].id]
    if categoryA ~= categoryB then return CategoryOrder(categoryA) < CategoryOrder(categoryB) end
    -- A clicked column header orders the items inside each category (IG.CompareByHeader).
    local byHeader = IG.CompareByHeader(a, b)
    if byHeader ~= nil then return byHeader end
    if categoryA.sort == "quality" then
        local qualityA, qualityB = a.data.displayQuality or 0, b.data.displayQuality or 0
        if qualityA ~= qualityB then return qualityA < qualityB end
    elseif categoryA.sort == "value" then
        local valueA, valueB = a.data.stackSellPrice or 0, b.data.stackSellPrice or 0
        if valueA ~= valueB then return valueA > valueB end
    end
    if a.igSortName ~= b.igSortName then return a.igSortName < b.igSortName end
    return (a.data.slotIndex or 0) < (b.data.slotIndex or 0)
end

---------------------------------------------------------------------------
-- Selling the whole Sell category at once
---------------------------------------------------------------------------

-- The one line in this addon that hands your things over rather than moving them about, so it
-- is offered in exactly one place and nowhere near anything else.
--
-- A merchant and nobody else. A fence buys only what was stolen and a guild store does not buy
-- at all -- it lists, for a fee, at a price you name -- so a line that sold "everything in the
-- category" at either of those would mean something quite different from what it says. The two
-- are told apart twice over, because getting it wrong here costs real things: the scene on
-- screen must be the merchant's own (the fence draws fence_keyboard and the guild store
-- tradinghouse, which is how the flat layout above tells them apart already), and the last
-- shop-ish event the client sent must have been the merchant's. Either answer alone would do
-- on paper; together they also cover a client where a fence quietly raises the merchant's
-- event, which is a thing a client may do and not a thing worth finding out the hard way.
local atMerchant, atFence = false, false

local function NoteMerchant() atMerchant, atFence = true, false end
local function NoteFence() atMerchant, atFence = false, true end
local function NoteClosed() atMerchant, atFence = false, false end

EVENT_MANAGER:RegisterForEvent("InventoryGroupingSellAllStore", EVENT_OPEN_STORE, NoteMerchant)
EVENT_MANAGER:RegisterForEvent("InventoryGroupingSellAllFence", EVENT_OPEN_FENCE, NoteFence)
EVENT_MANAGER:RegisterForEvent("InventoryGroupingSellAllClose", EVENT_CLOSE_STORE, NoteClosed)

local function AtMerchant()
    if not atMerchant then return false end
    return SCENE_MANAGER ~= nil and SCENE_MANAGER:IsShowing("store")
end

-- The fence's own scene (fence_keyboard, esoui/ingame/fence/keyboard/fence_keyboard.lua), the
-- same two-answer care AtMerchant takes.
local function AtFence()
    if not atFence then return false end
    return SCENE_MANAGER ~= nil and SCENE_MANAGER:IsShowing("fence_keyboard")
end

-- What one piece is worth over the counter, for the whole stack. The per-piece question is the
-- one the game answers with every bonus already folded in, so the stack is this addon's own
-- multiplication rather than a second question -- and where that answer is missing the plain
-- item info still carries a price, which is already the stack's.
--
-- The field the rows are sorted by (stackSellPrice) is deliberately not asked. It belongs to
-- the game's slot cache and other addons write over it: Tamriel Trade Centre replaces it with
-- what the market pays, which is the right number on a row and quite the wrong one in a
-- sentence promising what this merchant will hand you.
local function StackValue(bagId, slotIndex, stack)
    if GetItemSellValueWithBonuses then
        local each = GetItemSellValueWithBonuses(bagId, slotIndex)
        if each and each > 0 then return each * stack end
    end
    local _, _, price = GetItemInfo(bagId, slotIndex)
    return price or 0
end

-- Everything the merchant would turn away, asked before anything is sold rather than one
-- refusal at a time. The game's own answer comes first and covers the most of it -- a quest
-- item, a piece bound to a purpose, anything this client simply will not have sold. On top of
-- it two the player said themselves: a lock is the one mark in this game that means "not this
-- one", and stolen goods are a fence's trade, not a merchant's, so offering them here would
-- count pieces into the sentence that the counter then silently leaves behind.
local function Refused(bagId, slotIndex, itemLink)
    if IsItemPlayerLocked and IsItemPlayerLocked(bagId, slotIndex) == true then return true end
    if IsItemStolen and IsItemStolen(bagId, slotIndex) == true then return true end
    -- A piece a crafting writ is waiting for is never sold, even from SELL (DailyWrit.lua).
    if IG.IsDailyWritItem and IG.IsDailyWritItem({ bagId = bagId, slotIndex = slotIndex }) then return true end
    if GetItemLinkSellInformation and ITEM_SELL_INFORMATION_CANNOT_SELL then
        if GetItemLinkSellInformation(itemLink) == ITEM_SELL_INFORMATION_CANNOT_SELL then return true end
    end
    return false
end

-- The pieces, their links and what the lot comes to, gathered in one pass. Gathered rather than
-- counted as it goes, because every sale empties a slot and shifts what is in the bag: a loop
-- that sold and looked again would be reading a list it had just pulled apart. The link is kept
-- with each one so the sale can check it is still the same piece, the same way the lock and
-- bind question does.
local function Gather(members)
    local pieces, total = {}, 0
    for _, member in ipairs(members or {}) do
        local bagId, slotIndex = member.bagId, member.slotIndex
        local itemLink = bagId and slotIndex and GetItemLink(bagId, slotIndex)
        if itemLink and itemLink ~= "" and not Refused(bagId, slotIndex, itemLink) then
            local stack = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 1
            if not stack or stack < 1 then stack = 1 end
            pieces[#pieces + 1] = { bagId = bagId, slotIndex = slotIndex, link = itemLink, stack = stack }
            total = total + StackValue(bagId, slotIndex, stack)
        end
    end
    return pieces, total
end

local function Commas(amount)
    if ZO_CommaDelimitNumber then return ZO_CommaDelimitNumber(amount) end
    return tostring(amount)
end

-- What Refused refuses, minus the one line that would turn away the very reason a fence is
-- open: a lock still means "not this one", a writ still keeps its piece, and a piece the game's
-- own sell-information calls unsellable still is -- fence or merchant, that answer is the
-- game's, not an addon's to second-guess.
local function FenceRefused(bagId, slotIndex, itemLink)
    if IsItemPlayerLocked and IsItemPlayerLocked(bagId, slotIndex) == true then return true end
    if IG.IsDailyWritItem and IG.IsDailyWritItem({ bagId = bagId, slotIndex = slotIndex }) then return true end
    if GetItemLinkSellInformation and ITEM_SELL_INFORMATION_CANNOT_SELL then
        if GetItemLinkSellInformation(itemLink) == ITEM_SELL_INFORMATION_CANNOT_SELL then return true end
    end
    return false
end

-- The same gathering Gather does, through the fence's own refusal.
local function GatherFence(members)
    local pieces, total = {}, 0
    for _, member in ipairs(members or {}) do
        local bagId, slotIndex = member.bagId, member.slotIndex
        local itemLink = bagId and slotIndex and GetItemLink(bagId, slotIndex)
        if itemLink and itemLink ~= "" and not FenceRefused(bagId, slotIndex, itemLink) then
            local stack = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 1
            if not stack or stack < 1 then stack = 1 end
            pieces[#pieces + 1] = { bagId = bagId, slotIndex = slotIndex, link = itemLink, stack = stack }
            total = total + StackValue(bagId, slotIndex, stack)
        end
    end
    return pieces, total
end

-- Handing a piece over is asked for the careful way, the same as locking and junking are
-- elsewhere in this addon. Nothing installed here treats this call as one an addon may only
-- reach through a click of yours, so whether a given client does cannot be read off anyone
-- else's code -- and the road is there for the client that does.
local function Sell(bagId, slotIndex, stack)
    if IsProtectedFunction and IsProtectedFunction("SellInventoryItem") then
        CallSecureProtected("SellInventoryItem", bagId, slotIndex, stack)
    else
        SellInventoryItem(bagId, slotIndex, stack)
    end
end

local SELL_ALL_DIALOG = "INVENTORY_GROUPING_SELL_ALL"
local pendingSellAll
-- Some callers have a word of their own to say once the counter is done -- the selling that
-- starts from a handful of ctrl marks has to drop those marks, which describe pieces the
-- merchant now has. It waits here beside the pieces because the window is answered later than
-- it was asked, and it is only said where something was actually sold.
local pendingSellAllAfter

-- The window was answered at one moment and the list was written down at another, and in
-- between a piece may have been moved, split, spent or sold by other means. So each one is
-- asked again by the link it was gathered under, and the merchant is asked again too: an
-- answer that arrives after the counter has closed sells nothing at all.
local function RunPendingSellAll()
    local pending, after = pendingSellAll, pendingSellAllAfter
    pendingSellAll, pendingSellAllAfter = nil, nil
    if not pending or not AtMerchant() then return end
    for _, piece in ipairs(pending) do
        if GetItemLink(piece.bagId, piece.slotIndex) == piece.link then
            Sell(piece.bagId, piece.slotIndex, piece.stack)
        end
    end
    -- No list is built from here. Every sale empties a slot and the game rebuilds after it
    -- itself; a list built from inside our own frame is the whole of the insecure callstack
    -- trouble (see HANDOFF section 5). Whatever the caller left behind is held to the same
    -- rule, and the one that is passed in today only repaints.
    if after then after() end
end

ESO_Dialogs[SELL_ALL_DIALOG] = {
    title = { text = "Sell all of it?" },
    mainText = { text = "" },
    buttons = {
        -- Out of the window's own frame before a single thing is handed over, so the question
        -- is off the screen while the counter works.
        { text = SI_DIALOG_YES, callback = function() zo_callLater(RunPendingSellAll, 0) end },
        { text = SI_DIALOG_NO, callback = function() pendingSellAll, pendingSellAllAfter = nil, nil end },
    },
}

local function ConfirmSellAll(pieces, total, after)
    pendingSellAll = pieces
    pendingSellAllAfter = after
    ESO_Dialogs[SELL_ALL_DIALOG].mainText.text = string.format(
        "Sell %d %s to this merchant for %s gold?\n\nWhat is sold is gone: a merchant holds "
            .. "only the last few things back for you, and everything else is theirs.",
        #pieces, #pieces == 1 and "piece" or "pieces", Commas(total))
    ZO_Dialogs_ShowDialog(SELL_ALL_DIALOG)
end

-- Red, and the loudest line in any menu this addon draws, because it is the only one that
-- cannot be taken back with a second click. The category still names itself the way every
-- other line names it -- its own words in its own colour -- and the two numbers the window is
-- about to repeat stand in the line already, so the window confirms what was read rather than
-- introducing it.
local SELL_ALL_COLOR = "FF3A3A"
local SELL_ALL_TOTAL_COLOR = "FFD24A"

-- Only at a merchant, and only while there is something the merchant would take: a line
-- offered over a category full of locked or stolen pieces would promise a sale it then makes
-- no part of, and a line that does nothing when pressed has to be pressed to find that out.
function IG.AddSellAllItem(Members)
    if not AtMerchant() then return end
    local pieces, total = Gather(Members())
    if #pieces == 0 then return end
    AddMenuItem(string.format("|c%s>> SELL ALL|r %s |c%s%d for %s|r",
        SELL_ALL_COLOR, IG.MenuGroupName("SELL"), SELL_ALL_TOTAL_COLOR, #pieces, Commas(total)),
        function()
            -- Asked again at the press rather than trusted from when the menu was drawn: the
            -- two are different moments, and the numbers in the window have to be the numbers
            -- of the sale it is about to make.
            local fresh, freshTotal = Gather(Members())
            if #fresh == 0 or not AtMerchant() then return end
            ConfirmSellAll(fresh, freshTotal)
        end)
end

-- The same sale, offered over a handful of pieces marked with ctrl instead of over a whole
-- category. Everything that matters is the category line's and is shared with it rather than
-- said twice: who may be sold to, which pieces the counter would turn away, what the lot comes
-- to, that the pieces are written down before the first sale, and the window that asks. What
-- the two do not share is where the pieces come from and where the line is drawn, so that much
-- is the caller's.
--
-- Which category a marked piece sits in is not asked at all. A selection is the player pointing
-- at things one by one, and a line that quietly left some of them behind for being filed
-- elsewhere would be counting pieces into a sentence the counter then does not take.
--
-- The answer is nil where there would be nothing to press: away from a merchant, or with
-- nothing among the marks the merchant would have. Otherwise it is the line's own words --
-- coloured here so both lines are the same red -- and the thing to do when it is pressed, which
-- takes what the caller wants said once the counter is done with it.
function IG.SellSelectionOffer(Pieces)
    if not AtMerchant() then return nil end
    local pieces, total = Gather(Pieces())
    if #pieces == 0 then return nil end
    local label = string.format("|c%s>> SELL %d selected|r |c%sfor %s|r",
        SELL_ALL_COLOR, #pieces, SELL_ALL_TOTAL_COLOR, Commas(total))
    return label, function(after)
        -- Asked again at the press, for the same reason the category line asks again: the menu
        -- was drawn at one moment and pressed at another, and the window has to promise the
        -- sale it is about to make.
        local fresh, freshTotal = Gather(Pieces())
        if #fresh == 0 or not AtMerchant() then return end
        ConfirmSellAll(fresh, freshTotal, after)
    end
end

---------------------------------------------------------------------------
-- AUTOMATE: selling the SELL category on its own when a merchant opens
---------------------------------------------------------------------------

-- Off unless asked for (IG.AUTOMATE_ACTIONS, actionSell: Ask or Auto). What it sells is exactly what
-- the category line above would offer: the bag's pieces standing in SELL (by the classifier,
-- so rules and your own moves alike), less what Gather leaves out -- locked, stolen, anything
-- the game will not have sold. Worn pieces are not in the backpack and never asked.
--
-- One piece at a time on a short timer rather than all in one frame, the way PersonalAssistant
-- sells junk (PAJunk.lua:278, one SellInventoryItem and then a wait before the next). Each one
-- is asked again by its link and the merchant again before it goes, so closing the store stops
-- it where it is. Nothing here builds a list: the game rebuilds after every sale itself.
local AUTO_SELL_UPDATE = "InventoryGroupingAutoSell"
-- Faster than it was (150 ms, one piece a tick): a few pieces a tick on a shorter timer. The
-- sell-all window already hands everything over in one frame, so a handful at once is safe.
local AUTO_SELL_INTERVAL = 50
local AUTO_SELL_BATCH = 4
local AUTO_SELL_TRIES = 10
local autoSelling = false

local function SellCategoryMembers()
    local members = {}
    local cache = SHARED_INVENTORY and SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
    if not cache then return members end
    for _, slotData in pairs(cache) do
        if type(slotData) == "table" and slotData.bagId == BAG_BACKPACK and slotData.slotIndex then
            local path = IG.ClassifySlot(slotData, false, false)
            if path and path[1] and path[1].id == "SELL" then members[#members + 1] = slotData end
        end
    end
    return members
end

local function StolenCategoryMembers()
    local members = {}
    local cache = SHARED_INVENTORY and SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
    if not cache then return members end
    for _, slotData in pairs(cache) do
        if type(slotData) == "table" and slotData.bagId == BAG_BACKPACK and slotData.slotIndex then
            local path = IG.ClassifySlot(slotData, false, false)
            if path and path[1] and path[1].id == "STOLEN" then members[#members + 1] = slotData end
        end
    end
    return members
end

local function RunAutoSell(pieces)
    autoSelling = true
    local index, sold, gold = 0, 0, 0
    local function Finish()
        EVENT_MANAGER:UnregisterForUpdate(AUTO_SELL_UPDATE)
        autoSelling = false
        if sold > 0 then
            d(string.format("Inventory 2.0: Sold %d %s for %s gold.",
                sold, sold == 1 and "item" or "items", Commas(gold)))
        end
    end
    EVENT_MANAGER:RegisterForUpdate(AUTO_SELL_UPDATE, AUTO_SELL_INTERVAL, function()
        for _ = 1, AUTO_SELL_BATCH do
            index = index + 1
            local piece = pieces[index]
            if not piece or not AtMerchant() then return Finish() end
            if GetItemLink(piece.bagId, piece.slotIndex) == piece.link
                and not Refused(piece.bagId, piece.slotIndex, piece.link) then
                local value = StackValue(piece.bagId, piece.slotIndex, piece.stack)
                Sell(piece.bagId, piece.slotIndex, piece.stack)
                sold, gold = sold + 1, gold + value
            end
            if index >= #pieces then return Finish() end
        end
    end)
end

-- The store's own event says a merchant opened; the scene follows a moment later, and AtMerchant
-- wants both, so it is asked a few times before giving up.
local function OnStoreOpenedAutoSell()
    if autoSelling then return end
    local mode = IG.ActionMode and IG.ActionMode("sell") or "off"
    if mode == "off" then return end
    if IG.IsEnabled and not IG.IsEnabled() then return end
    local tries = 0
    local function Try()
        tries = tries + 1
        if not AtMerchant() then
            if tries < AUTO_SELL_TRIES then zo_callLater(Try, 100) end
            return
        end
        local pieces, total = Gather(SellCategoryMembers())
        if #pieces == 0 then return end
        -- Ask: the same window the category's own Sell All puts up, which gathers again when
        -- it is answered.
        if mode == "ask" then ConfirmSellAll(pieces, total) else RunAutoSell(pieces) end
    end
    zo_callLater(Try, 100)
end

EVENT_MANAGER:RegisterForEvent("InventoryGroupingAutoSell", EVENT_OPEN_STORE, OnStoreOpenedAutoSell)

---------------------------------------------------------------------------
-- AUTOMATE: selling the STOLEN category to a fence on its own
---------------------------------------------------------------------------

-- The fence buys a limited number of pieces per visit (GetFenceSellTransactionInfo, the same
-- call the game's own fence window reads its remaining count from). Read once, when the run
-- starts: it only grows smaller as the run sells into it, never larger, so one reading at the
-- start is also the ceiling the whole run keeps to.
local AUTO_FENCE_UPDATE = "InventoryGroupingAutoFenceSell"
local autoFenceSelling = false

local function RemainingFenceSells()
    if not GetFenceSellTransactionInfo then return 0 end
    local totalSells, sellsUsed = GetFenceSellTransactionInfo()
    return zo_max((totalSells or 0) - (sellsUsed or 0), 0)
end

local function RunFenceAutoSell(pieces)
    autoFenceSelling = true
    local index, sold, gold = 0, 0, 0
    local function Finish()
        EVENT_MANAGER:UnregisterForUpdate(AUTO_FENCE_UPDATE)
        autoFenceSelling = false
        if sold > 0 then
            d(string.format("Inventory 2.0: Sold %d stolen %s to the fence for %s gold.",
                sold, sold == 1 and "item" or "items", Commas(gold)))
        end
    end
    EVENT_MANAGER:RegisterForUpdate(AUTO_FENCE_UPDATE, AUTO_SELL_INTERVAL, function()
        for _ = 1, AUTO_SELL_BATCH do
            index = index + 1
            local piece = pieces[index]
            if not piece or not AtFence() then return Finish() end
            if GetItemLink(piece.bagId, piece.slotIndex) == piece.link
                and not FenceRefused(piece.bagId, piece.slotIndex, piece.link) then
                local value = StackValue(piece.bagId, piece.slotIndex, piece.stack)
                Sell(piece.bagId, piece.slotIndex, piece.stack)
                sold, gold = sold + 1, gold + value
            end
            if index >= #pieces then return Finish() end
        end
    end)
end

local FENCE_SELL_DIALOG = "INVENTORY_GROUPING_FENCE_SELL_ALL"
local pendingFenceSell

local function RunPendingFenceSell()
    local pending = pendingFenceSell
    pendingFenceSell = nil
    if not pending or not AtFence() then return end
    for _, piece in ipairs(pending) do
        if GetItemLink(piece.bagId, piece.slotIndex) == piece.link then
            Sell(piece.bagId, piece.slotIndex, piece.stack)
        end
    end
end

ESO_Dialogs[FENCE_SELL_DIALOG] = {
    title = { text = "Sell the stolen pieces?" },
    mainText = { text = "" },
    buttons = {
        { text = SI_DIALOG_YES, callback = function() zo_callLater(RunPendingFenceSell, 0) end },
        { text = SI_DIALOG_NO, callback = function() pendingFenceSell = nil end },
    },
}

local function ConfirmFenceSell(pieces, total)
    pendingFenceSell = pieces
    ESO_Dialogs[FENCE_SELL_DIALOG].mainText.text = string.format(
        "Sell %d stolen %s to this fence for %s gold?\n\nWhat is sold is gone, the same as at a "
            .. "merchant.",
        #pieces, #pieces == 1 and "piece" or "pieces", Commas(total))
    ZO_Dialogs_ShowDialog(FENCE_SELL_DIALOG)
end

local function OnFenceOpenedAutoSell()
    if autoFenceSelling then return end
    local mode = IG.ActionMode and IG.ActionMode("fence") or "off"
    if mode == "off" then return end
    if IG.IsEnabled and not IG.IsEnabled() then return end
    local tries = 0
    local function Try()
        tries = tries + 1
        if not AtFence() then
            if tries < AUTO_SELL_TRIES then zo_callLater(Try, 100) end
            return
        end
        local remaining = RemainingFenceSells()
        if remaining <= 0 then return end
        local pieces, total = GatherFence(StolenCategoryMembers())
        if #pieces > remaining then
            -- Only as many as the fence will take this visit; the rest wait for the next one.
            local capped, keptTotal = {}, 0
            for i = 1, remaining do
                capped[i] = pieces[i]
                keptTotal = keptTotal + StackValue(pieces[i].bagId, pieces[i].slotIndex, pieces[i].stack)
            end
            pieces, total = capped, keptTotal
        end
        if #pieces == 0 then return end
        if mode == "ask" then ConfirmFenceSell(pieces, total) else RunFenceAutoSell(pieces) end
    end
    zo_callLater(Try, 100)
end

EVENT_MANAGER:RegisterForEvent("InventoryGroupingAutoFenceSell", EVENT_OPEN_FENCE, OnFenceOpenedAutoSell)
