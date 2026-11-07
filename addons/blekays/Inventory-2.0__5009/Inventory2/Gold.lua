InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- What your money did, kept day by day, for the drawer that draws it (GoldDrawer.lua).
--
-- Per character rather than per account. A bag belongs to whoever is carrying it, and so does
-- the question this answers: what did this character earn today, and on what.
--
-- Nothing here ever reads a purse and compares it with a number it wrote down last time. Every
-- figure in this file arrived as an event while the addon was listening, which is the one way
-- to know what a change was *for*. The price of that is that a night spent with the addon
-- switched off is a night that never happened -- and that is the answer we want. A line saying
-- "unknown: 40,000" is not a record of anything; it is the sum of what we failed to watch, and
-- putting it on the screen beside real answers would make the real ones read as guesses too.

local sv, csv

-- How many days are kept. Thirty covers every range the drawer offers (Today, 7 days, 30 days)
-- and the month a player thinks in. Older days are dropped, but nothing is lost from the sum:
-- the lifetime totals below are added to as the day happens, never worked out from the days
-- still in the table, so "All" stays true after the day it was earned on has been let go.
--
-- What it costs: one day only exists once something has happened in it, and inside a day only
-- the currencies and the sources actually touched are written. A day of ordinary play is one
-- currency and a handful of sources -- a few dozen numbers. Thirty of those is single-digit
-- kilobytes per character, and a character who never sells anything writes nothing at all.
local KEEP_DAYS = 30

---------------------------------------------------------------------------
-- The currencies
---------------------------------------------------------------------------

-- Asked for by name rather than written as constants, because a client that has never heard of
-- one of these hands back nil and a nil is no key at all: indexing a table with it is an error
-- rather than a miss. Anything this client does not have simply is not a currency here.
local CURRENCY_SPEC = {
    { key = "gold",     constant = "CURT_MONEY",          label = "Gold",
      icon = "EsoUI/Art/currency/currency_gold.dds" },
    { key = "telvar",   constant = "CURT_TELVAR_STONES",  label = "Tel Var",
      icon = "EsoUI/Art/currency/currency_telvar.dds" },
    { key = "ap",       constant = "CURT_ALLIANCE_POINTS", label = "Alliance Points",
      icon = "EsoUI/Art/currency/alliancepoints.dds" },
    { key = "vouchers", constant = "CURT_WRIT_VOUCHERS",  label = "Writ Vouchers",
      icon = "EsoUI/Art/currency/currency_writvoucher.dds" },
}

-- The ones this client actually has, in the order above, and the way back from the game's own
-- number to our key.
IG.CURRENCIES = {}
local CURRENCY_BY_TYPE = {}

for _, spec in ipairs(CURRENCY_SPEC) do
    local currencyType = _G[spec.constant]
    if currencyType ~= nil then
        local entry = { key = spec.key, label = spec.label, icon = spec.icon,
            currencyType = currencyType }
        IG.CURRENCIES[#IG.CURRENCIES + 1] = entry
        CURRENCY_BY_TYPE[currencyType] = entry
    end
end

function IG.CurrencyAmount(entry)
    if not entry then return 0 end
    return GetCurrencyAmount(entry.currencyType, CURRENCY_LOCATION_CHARACTER) or 0
end

---------------------------------------------------------------------------
-- What a change was for
---------------------------------------------------------------------------

-- One line per source, and every reason the game might give for it. The reasons are named as
-- strings for the same reason the currencies are: this list is written against an API that adds
-- to itself every year, and a name that is not in this client is skipped rather than fatal.
--
-- A source is not an earning or a spending. The same source is both -- you sell to a merchant
-- and you buy from one -- and which block a figure lands in is decided by the sign of the
-- change, not by the reason. That is also what keeps the two blocks honest: a refund from a
-- merchant is money back from the merchant, not a new kind of income.
--
-- group names the category in the list a line jumps to when it is clicked. Most sources have no
-- honest answer to that -- there is no category in a bag for "a quest paid me" -- and those
-- lines are not clickable at all, which says more than a line that jumps somewhere arbitrary.
--
-- Every name here was first guessed and then checked against the reasons the live API actually
-- names, and nine of the guesses were wrong -- QUEST_REWARD is QUESTREWARD, LAUNDER is
-- VENDOR_LAUNDER, STABLE is STABLESPACE, and so on. A wrong name is silent: it matches nothing,
-- so a whole kind of spending quietly became Other. The real name goes first in each line.
--
-- The guesses that could not be confirmed are kept behind the confirmed ones rather than
-- deleted, because the list they were checked against is one client's and this API grows every
-- year. A name that does not exist costs one lookup at load and matches nothing, which is
-- exactly what it should do; a name deleted today because this client has not heard of it would
-- have to be guessed again the year it appears.
--
-- The client names a good many more reasons than are claimed here, and they are left unclaimed
-- on purpose. Most of them move something that is not money -- crowns, gems, seals, Alliance
-- Points for the keep and camp lines, soul gems -- and a line put under Upkeep because its name
-- sounds like a cost would be a figure the player cannot check. A reason is claimed here only
-- when it is certain that gold is what changes hands: the pickpocket's purse, the fine the
-- guards take, the stabler's fee, a bank's fee, the coin handed back when a wayshrine jump
-- fails. The rest go to Other, and the reason the game gave is written down (NoteUnknown).
local SOURCES = {
    { key = "fence",   label = "Fence",       group = "STOLEN",
      icon = "EsoUI/Art/Inventory/inventory_stolenItem_icon.dds",
      reasons = { "SELL_STOLEN", "VENDOR_LAUNDER", "PICKPOCKET" } },
    { key = "vendor",  label = "Vendor",      group = "SELL",
      icon = "EsoUI/Art/Vendor/vendor_tabIcon_sell_up.dds",
      reasons = { "VENDOR", "BUYBACK" } },
    { key = "repair",  label = "Repairs",
      icon = "EsoUI/Art/Vendor/vendor_tabIcon_repair_up.dds",
      reasons = { "VENDOR_REPAIR", "REPAIR" } },
    { key = "store",   label = "Guild Store",
      icon = "EsoUI/Art/MainMenu/menuBar_guilds_up.dds",
      -- A sale's proceeds are not a reason of their own: they come by mail, and are moved here
      -- from Mail once the mail they came in is known (see "Whose mail it was" below).
      reasons = { "TRADINGHOUSE_PURCHASE", "TRADINGHOUSE_LISTING", "TRADINGHOUSE_REFUND",
                  "GUILD_STORE_PURCHASE", "GUILD_STORE_SALE", "GUILD_STORE_LISTING" } },
    { key = "quest",   label = "Quests",      group = "QUEST",
      icon = "EsoUI/Art/Inventory/inventory_tabIcon_quest_up.dds",
      reasons = { "QUESTREWARD", "QUEST", "QUEST_REWARD" } },
    { key = "rewards", label = "Rewards",
      icon = "EsoUI/Art/TreeIcons/achievements_indexIcon_events_up.dds",
      reasons = { "REWARD" } },
    { key = "loot",    label = "Loot",
      icon = "EsoUI/Art/Inventory/inventory_tabIcon_Container_up.dds",
      reasons = { "LOOT", "LOOT_STOLEN", "LOOT_CURRENCY_CONTAINER", "CONTAINER", "KILL",
                  "MEDAL", "BATTLEGROUND", "ALLIANCE_ACTION", "PVP_KILL_TRANSFER" } },
    { key = "mail",    label = "Mail",
      icon = "EsoUI/Art/MainMenu/menuBar_mail_up.dds",
      reasons = { "MAIL", "CASH_ON_DELIVERY", "MAIL_COD" } },
    { key = "trade",   label = "Trade",
      icon = "EsoUI/Art/LFG/LFG_indexIcon_group_up.dds",
      reasons = { "TRADE" } },
    { key = "writs",   label = "Writs",
      icon = "EsoUI/Art/TradingHouse/tradingHouse_holiday_writ_up.dds",
      reasons = { "WRIT_VOUCHER", "WRIT_VOUCHER_REWARD", "HIRELING" } },
    { key = "craft",   label = "Crafting",    group = "CRAFT",
      icon = "EsoUI/Art/Inventory/inventory_tabIcon_crafting_up.dds",
      reasons = { "CRAFT", "RESEARCH_TRAIT", "TRAIT_REVEAL", "CRAFT_CONSUME", "RESEARCH",
                  "ENCHANTING", "CROWN_CRAFTING_MOTIF" } },
    { key = "upkeep",  label = "Upkeep",
      icon = "EsoUI/Art/Collections/collections_tabIcon_mounts_up.dds",
      reasons = { "STABLESPACE", "BAGSPACE", "BANKSPACE", "RESPEC_MORPHS", "RESPEC_ATTRIBUTES",
                  "RESPEC_SKILLS", "RESPEC_CHAMPION", "CHARACTER_UPGRADE", "EDIT_GUILD_HERALDRY",
                  "GUILD_TABARD", "KEEP_REPAIR", "BOUNTY_PAID_FENCE", "BOUNTY_PAID_GUARD",
                  "BOUNTY_CONFISCATED", "DEATH", "TRAVEL_GRAVEYARD", "JUMP_FAILURE_REFUND",
                  "FEED_MOUNT", "BANK_FEE",
                  "STABLE", "ABILITY_RESPEC", "ATTRIBUTE_RESPEC", "SKILL_RESPEC", "TRAVEL",
                  "FAST_TRAVEL", "HOUSING", "HOUSING_FURNITURE", "BOUNTY_PAID_THIEF" } },
}

-- Money moving between two pockets of your own is not earned and not spent, and counting it
-- would double every coin that ever passes through the bank. These reasons are dropped whole,
-- and so is the one the game hands out when it tells us what we already have at login.
--
-- BANK_FEE is deliberately not here: a fee is money gone, not money moved, and it stands with
-- the other costs under Upkeep.
local IGNORED = { "PLAYER_INIT", "BANK_DEPOSIT", "BANK_WITHDRAWAL", "GUILD_BANK_DEPOSIT",
    "GUILD_BANK_WITHDRAWAL", "CONVERSATION",
    "BANK", "GUILD_BANK", "TRANSFER" }

-- The whole prefix said once. Every one of these is CURRENCY_CHANGE_REASON_<NAME>.
local REASON_PREFIX = "CURRENCY_CHANGE_REASON_"

IG.GOLD_SOURCES = SOURCES
IG.GOLD_SOURCE_BY_KEY = {}
for _, source in ipairs(SOURCES) do IG.GOLD_SOURCE_BY_KEY[source.key] = source end

-- Everything the game can tell us, as a source key or as the word for "leave this alone".
-- Built once, at load, out of whatever this client actually names.
local sourceForReason = {}
local ignoredReason = {}

local function BuildReasonMap()
    for _, source in ipairs(SOURCES) do
        -- Not every line in SOURCES names reasons. Other is added to the end of the list below
        -- precisely because nothing names it: it is where a reason goes when no source claimed
        -- it, so it has nothing to claim itself. A line without reasons claims nothing and is
        -- passed over here; it still shows in the list, fed by whatever falls through.
        if source.reasons then
            for _, name in ipairs(source.reasons) do
                local reason = _G[REASON_PREFIX .. name]
                if reason ~= nil then sourceForReason[reason] = source.key end
            end
        end
    end
    for _, name in ipairs(IGNORED) do
        local reason = _G[REASON_PREFIX .. name]
        if reason ~= nil then ignoredReason[reason] = true end
    end
end

-- Anything this client gave a reason for that the list above does not name. Kept rather than
-- dropped: a coin that was really earned belongs in the sum whether or not we can say where it
-- came from, and a line called Other that grows is how we find out what is missing here.
local OTHER = { key = "other", label = "Other",
    icon = "EsoUI/Art/Inventory/inventory_tabIcon_misc_up.dds" }
SOURCES[#SOURCES + 1] = OTHER
IG.GOLD_SOURCE_BY_KEY[OTHER.key] = OTHER

---------------------------------------------------------------------------
-- Finding out what Other is
---------------------------------------------------------------------------

-- Other is honest but mute: it says a thousand gold left the purse and not a word about what
-- for. So every change that lands there writes down the reason the game gave for it, in the
-- saved variables (goldUnknown). Nothing here changes a figure on the screen -- the coin still
-- goes to Other and the totals are the totals -- this is the margin, not the ledger.
--
-- Kept on the account rather than on the character, because the question is about this client's
-- list of reasons and not about who happened to be standing there when one turned up.

-- Every reason name this client is known to have, so that the number an event carries can be
-- said as a word.
--
-- Written out rather than found by walking the globals, which is what this did first and what
-- cost us a crash: pairs(_G) touches every global there is, and some of what the game keeps
-- there is private. Reading one of those from an addon's stack is refused outright -- the same
-- rule that stops us committing an inventory list, met from the other side -- so the walk died
-- on UpdateMarketDisplayGroup before it had read a name. Asking for a name we chose, one at a
-- time, never touches anything we did not name.
--
-- The list is this client's, taken from the constants the game actually defines. Anything it has
-- not heard of is skipped at load rather than fatal, exactly as in the two lists above, and a
-- reason that is in the client but missing from here still gets written down -- as its number,
-- which is worth having and can be looked up.
local ALL_REASONS = {
    "ABILITY_UPGRADE_PURCHASE", "ACHIEVEMENT", "ACTION", "ANTIQUITY_REWARD", "BAGSPACE",
    "BANKSPACE", "BANK_DEPOSIT", "BANK_FEE", "BANK_WITHDRAWAL", "BATTLEGROUND",
    "BOUNTY_CONFISCATED", "BOUNTY_PAID_FENCE", "BOUNTY_PAID_GUARD", "BUYBACK",
    "CASH_ON_DELIVERY", "CHARACTER_UPGRADE", "COMMAND", "CONSUME_FOOD_DRINK", "CONSUME_POTION",
    "CONVERSATION", "CRAFT", "CROWNS_PURCHASED", "CROWN_CRATE_DUPLICATE", "DEATH", "DECONSTRUCT",
    "DEFENSIVE_KEEP_REWARD", "EDIT_GUILD_HERALDRY", "FEED_MOUNT", "GUILD_BANK_DEPOSIT",
    "GUILD_BANK_WITHDRAWAL", "GUILD_FORWARD_CAMP", "GUILD_STANDARD", "GUILD_TABARD",
    "HARVEST_REAGENT", "ITEM_CONVERTED_TO_GEMS", "JUMP_FAILURE_REFUND", "KEEP_REPAIR",
    "KEEP_REWARD", "KEEP_UPGRADE", "KILL", "LOOT", "LOOT_CURRENCY_CONTAINER", "LOOT_STOLEN",
    "MAIL", "MEDAL", "OFFENSIVE_KEEP_REWARD", "PICKPOCKET", "PLAYER_INIT", "PURCHASED_WITH_CROWNS",
    "PURCHASED_WITH_ENDEAVOR_SEALS", "PURCHASED_WITH_GEMS", "PVP_KILL_TRANSFER", "PVP_RESURRECT",
    "QUESTREWARD", "RECIPE", "RECONSTRUCTION", "REFORGE", "RESEARCH_TRAIT", "RESPEC_ATTRIBUTES",
    "RESPEC_CHAMPION", "RESPEC_MORPHS", "RESPEC_SKILLS", "REWARD", "SELL_STOLEN", "SOULWEARY",
    "SOUL_HEAL", "STABLESPACE", "STUCK", "TRADE", "TRADINGHOUSE_LISTING", "TRADINGHOUSE_PURCHASE",
    "TRADINGHOUSE_REFUND", "TRAIT_REVEAL", "TRAVEL_GRAVEYARD", "UNKNOWN", "VENDOR",
    "VENDOR_LAUNDER", "VENDOR_REPAIR",
}

-- The way back from the number to the name, built the first time anything asks. One lookup per
-- name above, and nothing else is read.
local reasonName

local function ReasonNames()
    if reasonName then return reasonName end
    reasonName = {}
    for _, name in ipairs(ALL_REASONS) do
        local value = _G[REASON_PREFIX .. name]
        if type(value) == "number" then reasonName[value] = name end
    end
    return reasonName
end

-- How many different reasons the notes may hold. A client names a couple of hundred and only a
-- handful of them can ever reach Other, so fifty is far past anything a real save will collect;
-- it is here so that a client that starts handing out a reason per transaction cannot grow the
-- save without limit. Full, new reasons are turned away and counted, because "there were others
-- we did not write down" is itself worth knowing.
local UNKNOWN_LIMIT = 50

local function UnknownStore()
    sv.goldUnknown = sv.goldUnknown or { reasons = {}, dropped = 0 }
    sv.goldUnknown.reasons = sv.goldUnknown.reasons or {}
    sv.goldUnknown.dropped = sv.goldUnknown.dropped or 0
    return sv.goldUnknown
end

-- One note per reason *and* currency. The same reason can move gold in one place and Tel Var in
-- another, and a single line adding the two together would be a worse answer than no line.
local function NoteUnknown(reason, currencyKey, amount, earned)
    if not sv then return end
    local store = UnknownStore()
    local name = reason ~= nil and ReasonNames()[reason] or nil
    local key = string.format("%s@%s", name or tostring(reason), currencyKey)

    local note = store.reasons[key]
    if not note then
        local count = 0
        for _ in pairs(store.reasons) do count = count + 1 end
        if count >= UNKNOWN_LIMIT then
            store.dropped = store.dropped + 1
            return
        end
        note = { name = name, reason = reason, currency = currencyKey,
            count = 0, earned = 0, spent = 0 }
        store.reasons[key] = note
    end

    note.count = note.count + 1
    if earned then note.earned = note.earned + amount else note.spent = note.spent + amount end
    note.date = (GetDate and GetDate()) or note.date
end

---------------------------------------------------------------------------
-- The days
---------------------------------------------------------------------------

-- Which day it is, counted off the player's own midnight rather than off the server's.
--
-- GetTimeStamp is the server's clock and GetSecondsSinceMidnight is how far the player's own
-- day has got. The difference between them is the moment the player's day began, said in the
-- server's numbers -- a figure that does not move all day and jumps by exactly one day's worth
-- at the player's midnight. Divided down it is a day number that turns over when the player
-- says it does, wherever in the world the player is sitting.
--
-- A client that cannot answer the second question falls back to the server's own midnight,
-- which is a day boundary in the wrong place rather than no day boundary at all.
local function DayIndex()
    local now = GetTimeStamp()
    if not now then return 0 end
    local since = GetSecondsSinceMidnight and GetSecondsSinceMidnight() or nil
    if since then return zo_floor((now - since) / 86400) end
    return zo_floor(now / 86400)
end

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

-- A day is stamped with the calendar date it began on when it is first written to, so that it
-- can be named later without any arithmetic: the day number above is good for ordering and for
-- ranges, and says nothing a player would recognise.
local function Today()
    return DayIndex(), (GetDate and GetDate() or 0)
end

-- "12 Sep", out of the YYYYMMDD the game writes dates as.
function IG.GoldDayName(date)
    if not date or date <= 0 then return "" end
    local month = zo_floor(date / 100) % 100
    local day = date % 100
    return string.format("%d %s", day, MONTHS[month] or "")
end

local function Store()
    csv.gold = csv.gold or { days = {}, total = {} }
    csv.gold.days = csv.gold.days or {}
    csv.gold.total = csv.gold.total or {}
    return csv.gold
end

-- Anything older than the window we keep. Run when a day is first written to, which is the only
-- moment the answer can have changed.
local function Prune(store, today)
    local oldest = today - KEEP_DAYS + 1
    for index in pairs(store.days) do
        if index < oldest then store.days[index] = nil end
    end
end

local function Bucket(holder, currencyKey, earned)
    holder[currencyKey] = holder[currencyKey] or { earned = {}, spent = {} }
    local side = holder[currencyKey]
    return earned and side.earned or side.spent
end

---------------------------------------------------------------------------
-- Whose mail it was
---------------------------------------------------------------------------

-- The purse is told only "MAIL". Which mail is said a moment later, by
-- EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS (mailId) -- MoneyWhere reads the order the same way: the
-- coin arrives first, the mail is named after, and by then the mail's own attachedMoney is 0.
-- So a mail credit is written down as Mail at once, and moved when its mail is known:
--   returned to us            -> our own coin coming back, neither earned nor spent
--   system mail "Item Sold"   -> a guild store sale, filed under Guild Store
--   sent by our own account   -> coin moved between our own pockets, dropped
--   anything else             -> left as Mail
-- The two halves are paired oldest-first, so a mail addon emptying many mails at speed still pairs
-- each coin with its own mail. Either half may arrive first; one that waits longer than
-- MAIL_MATCH_MS for its partner is let go, and the coin stays under Mail.
--
-- The "Item Sold" subject is the English client's (MoneyWhere matches the same text). On another
-- language a sale stays under Mail rather than being guessed at.
local MAIL_MATCH_MS = 3000
local pendingCredits, pendingVerdicts = {}, {}

local function DropStale(queue, now)
    while queue[1] and now - queue[1].time > MAIL_MATCH_MS do table.remove(queue, 1) end
end

local function ClassifyMail(mailId)
    -- senderDisplayName, senderCharacterName, subject, icon, unread, fromSystem,
    -- fromCustomerService, returned, numAttachments, attachedMoney, codAmount, ...
    local sender, _, subject, _, _, fromSystem, fromCS, returned = GetMailItemInfo(mailId)
    local verdict = { sender = sender or "?", subject = subject or "" }
    if returned then
        verdict.target, verdict.why = nil, "returned"
    elseif fromSystem and subject and string.find(subject, "Item Sold", 1, true) then
        verdict.target, verdict.why = "store", "guild store sale"
    elseif not fromSystem and not fromCS and sender and sender == GetDisplayName() then
        verdict.target, verdict.why = nil, "own account"
    else
        verdict.target, verdict.why = "mail", fromSystem and "system mail" or "player mail"
    end
    return verdict
end

local function MoveCredit(holder, credit, target)
    local side = Bucket(holder, credit.currency, true)
    local left = (side.mail or 0) - credit.amount
    side.mail = left > 0 and left or nil
    if target then side[target] = (side[target] or 0) + credit.amount end
end

local function Settle(credit, verdict)
    if verdict.target ~= "mail" then
        local store = Store()
        local day = store.days[credit.day]
        if day and day.cur then MoveCredit(day.cur, credit, verdict.target) end
        MoveCredit(store.total, credit, verdict.target)
        if IG.RefreshOpenDrawer then IG.RefreshOpenDrawer() end
    end
end

-- Called for every gold credit whose reason is MAIL.
local function NoteMailCredit(credit)
    local now = GetFrameTimeMilliseconds()
    DropStale(pendingVerdicts, now)
    if pendingVerdicts[1] then
        Settle(credit, table.remove(pendingVerdicts, 1))
    else
        credit.time = now
        pendingCredits[#pendingCredits + 1] = credit
    end
end

local function OnMailMoneyTaken(_, mailId)
    local verdict = ClassifyMail(mailId)
    local now = GetFrameTimeMilliseconds()
    DropStale(pendingCredits, now)
    if pendingCredits[1] then
        Settle(table.remove(pendingCredits, 1), verdict)
    else
        verdict.time = now
        pendingVerdicts[#pendingVerdicts + 1] = verdict
    end
end

---------------------------------------------------------------------------
-- What the game tells us
---------------------------------------------------------------------------

local function OnCurrencyUpdate(_, currencyType, location, newAmount, oldAmount, reason)
    -- The purse on the character, not the one in the bank: the bank's own figure moves for
    -- every deposit and would count the same coin a second time.
    if location ~= CURRENCY_LOCATION_CHARACTER then return end
    local currency = CURRENCY_BY_TYPE[currencyType]
    if not currency then return end
    if reason ~= nil and ignoredReason[reason] then return end

    local delta = (newAmount or 0) - (oldAmount or 0)
    if delta == 0 then return end

    local store = Store()
    local today, date = Today()
    local day = store.days[today]
    if not day then
        Prune(store, today)
        day = { date = date, cur = {} }
        store.days[today] = day
    end
    -- A save that was carried over from another day and is being written to again keeps the
    -- date it was opened with; a day that opened before midnight and is still being written to
    -- after it is a new day number and so a new record, which is the point of the number.
    day.date = day.date or date

    local sourceKey = (reason ~= nil and sourceForReason[reason]) or OTHER.key
    local earned = delta > 0
    local amount = earned and delta or -delta

    -- Written down in the margin on the way past, where the reason is still in hand. A step
    -- further down it is only the word "other".
    if sourceKey == OTHER.key then NoteUnknown(reason, currency.key, amount, earned) end

    local into = Bucket(day.cur, currency.key, earned)
    into[sourceKey] = (into[sourceKey] or 0) + amount

    local lifetime = Bucket(store.total, currency.key, earned)
    lifetime[sourceKey] = (lifetime[sourceKey] or 0) + amount

    -- Money out of a mail is filed as Mail for now and settled when the game says which mail.
    if earned and currency.key == "gold" and reason ~= nil
        and reason == _G[REASON_PREFIX .. "MAIL"] then
        NoteMailCredit({ day = today, currency = currency.key, amount = amount })
    end

    -- The drawer is redrawn only while it is the thing on screen. Nothing here rebuilds a list.
    if IG.RefreshOpenDrawer then IG.RefreshOpenDrawer() end
end

---------------------------------------------------------------------------
-- What the drawer asks
---------------------------------------------------------------------------

-- days: 1 for today, 7, 30, or nil for everything ever. The answer is one table, so the panel
-- draws the same shape whichever range it was given.
--
-- "All" is answered out of the lifetime totals rather than by adding the days up, because the
-- days only go back a month and the totals go back to the first coin. The best day inside it
-- can only be one of the days still kept, and says so where it is written.
function IG.GoldSummary(currencyKey, days)
    local store = Store()
    local result = { earned = {}, spent = {}, earnedTotal = 0, spentTotal = 0,
        bestAmount = 0, bestDate = nil, partialBest = days == nil }

    local function Add(into, from, total)
        for key, amount in pairs(from or {}) do
            into[key] = (into[key] or 0) + amount
            total = total + amount
        end
        return total
    end

    if days == nil then
        local side = store.total[currencyKey]
        if side then
            result.earnedTotal = Add(result.earned, side.earned, result.earnedTotal)
            result.spentTotal = Add(result.spent, side.spent, result.spentTotal)
        end
    end

    local today = DayIndex()
    local first = days and (today - days + 1) or (today - KEEP_DAYS + 1)
    for index, day in pairs(store.days) do
        if index >= first and index <= today then
            local side = day.cur and day.cur[currencyKey]
            if side then
                local dayEarned = 0
                for _, amount in pairs(side.earned or {}) do dayEarned = dayEarned + amount end
                if dayEarned > result.bestAmount then
                    result.bestAmount, result.bestDate = dayEarned, day.date
                end
                if days ~= nil then
                    result.earnedTotal = Add(result.earned, side.earned, result.earnedTotal)
                    result.spentTotal = Add(result.spent, side.spent, result.spentTotal)
                end
            end
        end
    end

    result.net = result.earnedTotal - result.spentTotal
    return result
end

-- Every source that has a figure in one of the two blocks, largest first, as
-- { key, label, group, amount, share } -- share being how much of its own block it is, which is
-- what the bar beside it is drawn from.
function IG.GoldLines(amounts, total)
    local lines = {}
    for key, amount in pairs(amounts or {}) do
        if amount > 0 then
            local source = IG.GOLD_SOURCE_BY_KEY[key] or OTHER
            lines[#lines + 1] = { key = key, label = source.label, group = source.group,
                amount = amount, share = total > 0 and (amount / total) or 0 }
        end
    end
    table.sort(lines, function(a, b)
        if a.amount ~= b.amount then return a.amount > b.amount end
        return a.label < b.label
    end)
    return lines
end

function IG.InitGold(accountSettings, characterSettings)
    sv, csv = accountSettings, characterSettings
    Store()
    BuildReasonMap()

    -- The Global Switch stops the listening, the way it stops everything else the addon does.
    -- What is already saved stays saved.
    if not IG.IsEnabled() then return end
    EVENT_MANAGER:RegisterForEvent("InventoryGroupingGold", EVENT_CURRENCY_UPDATE, OnCurrencyUpdate)
    EVENT_MANAGER:RegisterForEvent("InventoryGroupingGold", EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS,
        OnMailMoneyTaken)
end

