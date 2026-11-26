-- shared
-- Money, bag space and Champion Points spent.
--   c.gold, c.telvar, c.ap, c.vouchers   what the character carries
--   c.bagUsed, c.bagSize
--   c.cp = { { name =, spent =, unspent = }, ... }   one per Champion Point tree
--   account.bankGold, bankTelvar, bankAP, bankVouchers, bankUsed, bankSize
--   account.wallet = { "Transmute Crystals|1234", ... }   what the whole account shares
local CT = FurysCharacterTracker
local U = CT.Util


-- Game only.
local function Read(c, account)
    local function Carried(currency) return GetCurrencyAmount(currency, CURRENCY_LOCATION_CHARACTER) or 0 end
    local function Banked(currency) return GetCurrencyAmount(currency, CURRENCY_LOCATION_BANK) or 0 end
    c.gold, c.telvar = Carried(CURT_MONEY), Carried(CURT_TELVAR_STONES)
    c.ap, c.vouchers = Carried(CURT_ALLIANCE_POINTS), Carried(CURT_WRIT_VOUCHERS)
    c.bagUsed, c.bagSize = GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK)
    c.cp = {}
    for index = 1, GetNumChampionDisciplines() do
        local id = GetChampionDisciplineId(index)
        c.cp[index] = { name = U.Plain(GetChampionDisciplineName(id)), spent = GetNumSpentChampionPoints(id),
                        unspent = GetNumUnspentChampionPoints(id) }
    end
    account.bankGold, account.bankTelvar = Banked(CURT_MONEY), Banked(CURT_TELVAR_STONES)
    account.bankAP, account.bankVouchers = Banked(CURT_ALLIANCE_POINTS), Banked(CURT_WRIT_VOUCHERS)
    account.bankUsed = GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK)
    account.bankSize = GetBagSize(BAG_BANK) + GetBagSize(BAG_SUBSCRIBER_BANK)
    -- Everything the account shares, under the game's own names.
    local shared = { CURT_TRANSMUTE_CRYSTALS, CURT_UNDAUNTED_KEYS, CURT_SEALS, CURT_ARCHIVAL_FORTUNES, CURT_IMPERIAL_FRAGMENTS,
                     CURT_TRADE_BARS, CURT_TOME_POINTS, CURT_TOME_TOKENS, CURT_TOME_POINT_CACHES, CURT_TOME_CHALLENGE_REROLLS,
                     CURT_UNDAUNTED_CRESTS, CURT_STYLE_STONES, CURT_CROWN_GEMS, CURT_CROWNS }
    local wallet = {}
    for _, currency in ipairs(shared) do
        if IsCurrencyValid(currency) and GetCurrencyPlayerStoredLocation(currency) == CURRENCY_LOCATION_ACCOUNT then
            local amount = GetCurrencyAmount(currency, CURRENCY_LOCATION_ACCOUNT) or 0
            if amount > 0 then wallet[#wallet + 1] = U.Clean(U.Plain(GetCurrencyName(currency, false, false))) .. "|" .. amount end
        end
    end
    account.wallet, account.transmutes = wallet, nil
end

-- The top line of the Wallet tab: the bank, then what the account shares. Returns the line and,
-- for the hover text, the same thing one item per line.
function CT.WalletSummary(data)
    local a = data.account or {}
    if not a.bankGold then return "Bank: not read yet. Log in on any character of this account.", nil end
    local short = string.format("Bank: %s gold  ·  %s Tel Var  ·  %s AP  ·  %s vouchers  ·  space %d/%d",
        U.Comma(a.bankGold), U.Comma(a.bankTelvar), U.Comma(a.bankAP), U.Comma(a.bankVouchers), a.bankUsed or 0, a.bankSize or 0)
    local long = { "In the bank", "  Gold  " .. U.Comma(a.bankGold), "  Tel Var  " .. U.Comma(a.bankTelvar), "  Alliance Points  " .. U.Comma(a.bankAP),
                   "  Writ vouchers  " .. U.Comma(a.bankVouchers), string.format("  Bank space  %d / %d", a.bankUsed or 0, a.bankSize or 0) }
    local shared = {}
    for _, text in ipairs(a.wallet or {}) do
        local p = U.Split(text, "|")
        shared[#shared + 1] = { name = p[1], amount = tonumber(p[2]) or 0 }
    end
    if not a.wallet and a.transmutes then shared[1] = { name = "Transmute Crystals", amount = a.transmutes } end
    if #shared > 0 then
        long[#long + 1] = "\nShared by the whole account"
        local parts = {}
        for _, item in ipairs(shared) do
            long[#long + 1] = string.format("  %s  %s", item.name, U.Comma(item.amount))
            parts[#parts + 1] = string.format("%s %s", U.Comma(item.amount), item.name)
        end
        short = short .. "  ·  Account: " .. table.concat(parts, "  ·  ")
    end
    return short, table.concat(long, "\n")
end

local function Money(key, title, width, field, what)
    return { key = key, title = title, width = width, sum = true, head = what .. " by this character. The bottom row is the total.",
             value = function(e) return e.c[field] or 0 end,
             display = function(v) return U.Comma(v) end, dim = function(v) return v == 0 end, tip = what }
end

local function Tree(e, index) return (e.c.cp or {})[index] end

local function ChampionTree(index)
    return { key = "cp" .. index, width = 96,
             -- Tree names come from the game; the first character that has them names the column.
             title = function()
                 for _, id in ipairs(CT.Data().order) do
                     local c = CT.Data().characters[id]
                     local tree = c and c.cp and c.cp[index]
                     if tree then return tree.name end
                 end
                 return "CP " .. index
             end,
             head = "Champion Points spent in this tree, out of the points this character has for it.",
             max = function(e) local t = Tree(e, index); return t and (t.spent + t.unspent) > 0 and (t.spent + t.unspent) or nil end,
             value = function(e) local t = Tree(e, index); return t and t.spent or 0 end,
             display = function(v, e) local t = Tree(e, index); return t and U.Of(v, t.spent + t.unspent) or "-" end,
             tip = function(e)
                 local t = Tree(e, index)
                 if not t then return "Not read yet" end
                 return string.format("%s: %d spent, %d not spent\nViolet = every point in this tree spent", t.name, t.spent, t.unspent)
             end }
end

CT.Track({
    id = "wallet",
    read = Read,
    events = { EVENT_MONEY_UPDATE, EVENT_CURRENCY_UPDATE, EVENT_CHAMPION_PURCHASE_RESULT, EVENT_UNSPENT_CHAMPION_POINTS_CHANGED },
    start = function(queue)
        EVENT_MANAGER:RegisterForEvent(CT.name .. "Bag", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, queue)
        EVENT_MANAGER:AddFilterForEvent(CT.name .. "Bag", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    end,
    columns = {
        Money("gold", "Gold", 112, "gold", "Gold carried"), Money("telvar", "Tel Var", 88, "telvar", "Tel Var stones carried"),
        Money("ap", "AP", 100, "ap", "Alliance Points held"), Money("vouchers", "Vouchers", 96, "vouchers", "Writ vouchers held"),
        { key = "bag", title = "Bag", width = 84, bar = false, value = function(e) return e.c.bagUsed or 0 end,
          head = "Bag: backpack slots used, out of the slots this character has.",
          display = function(v, e) return e.c.bagSize and U.Of(v, e.c.bagSize) or "-" end,
          dim = function(_, e) return not e.c.bagSize end,
          tip = function(e) return e.c.bagSize and string.format("Backpack: %d used, %d free", e.c.bagUsed, e.c.bagSize - e.c.bagUsed) or "Not read yet" end },
        ChampionTree(1), ChampionTree(2), ChampionTree(3),
    },
    sections = function(e)
        local c = e.c
        local section = { title = "Wallet & CP", items = {
            { "Gold", U.Comma(c.gold) }, { "Tel Var", U.Comma(c.telvar) }, { "Alliance Points", U.Comma(c.ap) }, { "Writ vouchers", U.Comma(c.vouchers) },
            { "Bag", c.bagSize and (U.Whole(c.bagUsed) .. " / " .. U.Whole(c.bagSize)) or "-" } } }
        for _, t in ipairs(c.cp or {}) do
            section.items[#section.items + 1] = { t.name, U.Whole(t.spent) .. " / " .. U.Whole(t.spent + t.unspent), done = t.unspent == 0 and t.spent > 0 }
        end
        return { section }
    end,
    export = {
        { "Gold", function(e) return e.c.gold end }, { "Tel Var", function(e) return e.c.telvar end },
        { "Alliance Points", function(e) return e.c.ap end }, { "Writ vouchers", function(e) return e.c.vouchers end },
        { "Bag used", function(e) return e.c.bagUsed end }, { "Bag size", function(e) return e.c.bagSize end },
    },
})
