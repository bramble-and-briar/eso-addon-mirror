-- Fury's Inventory Ledger
-- Catalogs every item you own, everywhere, and exports it in an Excel-friendly format.
-- Author: Furyous

FurysInventoryLedger = FurysInventoryLedger or {}
local FIL = FurysInventoryLedger

FIL.name    = "FurysInventoryLedger"
FIL.title   = "Fury's Inventory Ledger"
FIL.version = "1.7.4"
-- The Windows tools (Excel export) can't ship in the ESOUI zip; this page has the download.
FIL.toolsUrl = "https://github.com/AlbertHoffpauir/FurysInventoryLedger#downloads"
FIL.COPY_SCENE    = "FurysInventoryLedgerCopy"
FIL.SUMMARY_SCENE = "FurysInventoryLedgerSummary"

-- Controls > Addon Keybinds (actions in Bindings.xml)
ZO_CreateStringId("SI_BINDING_NAME_FURYSINVENTORYLEDGER_SUMMARY", "Open/close the summary")
ZO_CreateStringId("SI_BINDING_NAME_FURYSINVENTORYLEDGER_COPY", "Open/close the copy window")

local ACCOUNT_OWNER = "(Account)"
local ROW_MARKER    = "FIL|"     -- prefix on each saved export row, so the PowerShell exporter can find them
local PAGE_CHARS    = 28000      -- in-game copy window page size (the edit box tops out around 32k)
local SCAN_DELAY_MS = 1500       -- debounce for rescans after inventory changes
local HOUSE_DELAY_MS = 4000      -- give placed furniture time to load after zoning into a house

local TAG = "|cA08CFF"   -- Fury Night violet (Theme.lua)
local function Msg(text, ...)
    FIL.Theme.Chat(zo_strformat(text, ...))   -- 1.6.4: the shared chat line (Theme.lua)
end
-- A line of chat help: no zo_strformat, so "<words>" and "|" style text shows as typed.
local function Help(text)
    FIL.Theme.Chat(text)
end

local SV         -- whole saved-variable table
local acct       -- this account+server's data
local charRec    -- this character's record

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------
local function Clean(s)
    if s == nil then return "" end
    s = tostring(s)
    s = s:gsub("[\t\r\n]", " ")
    return s
end

local function FormatName(s)
    if not s or s == "" then return "" end
    return zo_strformat(SI_TOOLTIP_ITEM_NAME, s)
end

local function FormatTime(ts)
    if not ts then return "" end
    return os.date("%Y-%m-%d %H:%M", ts)
end

local function EnumString(prefix, value, noneValue)
    if value == nil or value == noneValue then return "" end
    local s = GetString(prefix, value)
    return s or ""
end

-- Set by every read; the saved Excel list and the daily totals are only rebuilt when it is set.
local dirty = true

local function NewContainer(owner, location, container)
    dirty = true
    FIL.dataRev = (FIL.dataRev or 0) + 1   -- lets the tooltip index know it is out of date
    return { owner = owner, location = location, container = container, updated = GetTimeStamp(), items = {} }
end

------------------------------------------------------------------------------
-- Packed items (saved data version 2)
-- A container's items are saved as one line of text each in cont.p: "qty;flags;link or name".
-- Flags: b = bound, s = stolen (item links); c = currency name; n = plain name (furniture
-- with no link). The link or name comes last, so it may hold any character.
-- While a container is being read its items sit in cont.items as small tables; Seal packs
-- them. cont.items is then left as an empty list, so a build from before 1.5.1 finds
-- nothing there instead of failing. Readers always go through FIL.Items(cont).
------------------------------------------------------------------------------
local unpacked = setmetatable({}, { __mode = "k" })   -- container -> its items as tables, this session only

local function PackItem(it)
    if it.l then
        return it.q .. ";" .. (it.b and "b" or "") .. (it.s and "s" or "") .. ";" .. it.l
    end
    return it.q .. ";" .. (it.cur and "c" or "n") .. ";" .. (it.n or "")
end

local function UnpackItem(line)
    local q, flags, rest = line:match("^(%d+);(%a*);(.*)$")
    if not q then return nil end
    q = tonumber(q)
    if flags == "c" then return { n = rest, q = q, cur = true } end
    if flags == "n" then return { n = rest, q = q } end
    local it = { l = rest, q = q }
    if flags:find("b", 1, true) then it.b = true end
    if flags:find("s", 1, true) then it.s = true end
    return it
end

local function SameItem(a, b)
    return a ~= nil and b ~= nil and a.l == b.l and a.n == b.n and a.q == b.q
        and (a.b or false) == (b.b or false) and (a.s or false) == (b.s or false) and (a.cur or false) == (b.cur or false)
end

-- Packs a container's items. Each line is read back and compared first; if any item does
-- not survive the trip the container is left exactly as it was (old layout, still readable).
local function Seal(cont)
    local items = cont.items
    local lines = {}
    for i, it in ipairs(items) do
        local line = PackItem(it)
        if not SameItem(it, UnpackItem(line)) then return cont end
        lines[i] = line
    end
    cont.p = lines
    cont.items = {}
    unpacked[cont] = items
    return cont
end

-- The items of a container as a list of tables, whichever layout it was saved in.
local function Items(cont)
    if not cont then return {} end
    if not cont.p then return cont.items or {} end
    local items = unpacked[cont]
    if not items then
        items = {}
        for _, line in ipairs(cont.p) do items[#items + 1] = UnpackItem(line) end
        unpacked[cont] = items
    end
    return items
end

-- Adds one stack to a container, merging identical items (same link, bound and stolen state).
local function AddItem(cont, index, link, qty, bound, stolen)
    if not link or link == "" or not qty or qty <= 0 then return end
    local key = link .. (bound and "#b" or "") .. (stolen and "#s" or "")
    local entry = index[key]
    if entry then
        entry.q = entry.q + qty
    else
        entry = { l = link, q = qty, b = bound or nil, s = stolen or nil }
        index[key] = entry
        cont.items[#cont.items + 1] = entry
    end
end

-- Reads a real bag into a container record.
local function ReadBag(cont, bagId, index)
    index = index or {}
    local function readSlot(slot)
        local link = GetItemLink(bagId, slot, LINK_STYLE_DEFAULT)
        if link ~= "" then
            local stack = GetSlotStackSize(bagId, slot)
            AddItem(cont, index, link, stack, IsItemBound(bagId, slot), IsItemStolen(bagId, slot))
        end
    end
    if bagId == BAG_VIRTUAL then
        local slot = GetNextVirtualBagSlotId(nil)
        while slot do
            readSlot(slot)
            slot = GetNextVirtualBagSlotId(slot)
        end
    else
        for slot = 0, GetBagSize(bagId) - 1 do
            readSlot(slot)
        end
    end
    return index
end

local function CollectibleLabel(collectibleId)
    if not collectibleId or collectibleId == 0 then return "" end
    local name = zo_strformat("<<1>>", GetCollectibleName(collectibleId))
    local nick = GetCollectibleNickname(collectibleId)
    if nick and nick ~= "" then
        return zo_strformat("<<1>>", nick) .. " (" .. name .. ")"
    end
    return name
end

------------------------------------------------------------------------------
-- Scanners
------------------------------------------------------------------------------
local function ScanCharacterBags()
    local name = charRec.name
    local c = NewContainer(name, "Character", "Backpack")
    ReadBag(c, BAG_BACKPACK)
    c.size, c.used = GetBagSize(BAG_BACKPACK), GetNumBagUsedSlots(BAG_BACKPACK)
    charRec.containers.backpack = Seal(c)

    c = NewContainer(name, "Character", "Equipped")
    ReadBag(c, BAG_WORN)
    charRec.containers.worn = Seal(c)

    if HasActiveCompanion() then
        local defId = GetActiveCompanionDefId()
        local compName = zo_strformat("<<1>>", GetCompanionName(defId))
        c = NewContainer(name, "Companion", compName .. " (equipped)")
        ReadBag(c, BAG_COMPANION_WORN)
        charRec.containers["companion_" .. defId] = Seal(c)
    end
end

local function ScanBank()
    local c = NewContainer(ACCOUNT_OWNER, "Bank", "Bank")
    local index = ReadBag(c, BAG_BANK)
    ReadBag(c, BAG_SUBSCRIBER_BANK, index)
    c.size = GetBagUseableSize(BAG_BANK) + GetBagUseableSize(BAG_SUBSCRIBER_BANK)
    c.used = GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK)
    acct.shared.bank = Seal(c)
end

local function ScanCraftBag()
    local c = NewContainer(ACCOUNT_OWNER, "Craft Bag", "Craft Bag")
    ReadBag(c, BAG_VIRTUAL)
    acct.shared.craftbag = Seal(c)
end

local function HouseBankBags()
    local bags = {}
    for bag = BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TEN do
        if IsHouseBankBag(bag) then bags[#bags + 1] = bag end
    end
    return bags
end

local function ScanStorageBag(bagId)
    if bagId == BAG_FURNITURE_VAULT then
        local c = NewContainer(ACCOUNT_OWNER, "Furniture Vault", "Furniture Vault")
        ReadBag(c, bagId)
        c.size, c.used = GetBagSize(bagId), GetNumBagUsedSlots(bagId)
        acct.shared.vault = Seal(c)
    elseif IsHouseBankBag(bagId) then
        local label = CollectibleLabel(GetCollectibleForBag(bagId))
        if label == "" then label = "Storage " .. (bagId - BAG_HOUSE_BANK_ONE + 1) end
        local c = NewContainer(ACCOUNT_OWNER, "House Storage", label)
        ReadBag(c, bagId)
        c.size, c.used = GetBagSize(bagId), GetNumBagUsedSlots(bagId)
        acct.shared["housebank_" .. bagId] = Seal(c)
    end
end

-- House storage and the vault are only readable at certain times; never wipe a cache with an empty read.
local function ScanStorageIfReadable()
    if GetNumBagUsedSlots(BAG_FURNITURE_VAULT) > 0 then
        ScanStorageBag(BAG_FURNITURE_VAULT)
    end
    for _, bag in ipairs(HouseBankBags()) do
        if GetNumBagUsedSlots(bag) > 0 then ScanStorageBag(bag) end
    end
end

local function ScanPlacedFurniture()
    local houseId = GetCurrentZoneHouseId()
    if not houseId or houseId == 0 or not IsOwnerOfCurrentHouse() then return false end
    local houseName = CollectibleLabel(GetCollectibleIdForHouse(houseId))
    local c = NewContainer(ACCOUNT_OWNER, "Placed in House", houseName)
    local index = {}
    local count = 0
    local fid = GetNextPlacedHousingFurnitureId(nil)
    while fid do
        local itemLink, collectibleLink = GetPlacedFurnitureLink(fid, LINK_STYLE_DEFAULT)
        if itemLink and itemLink ~= "" then
            AddItem(c, index, itemLink, 1, false, false)
        elseif collectibleLink and collectibleLink ~= "" then
            AddItem(c, index, collectibleLink, 1, false, false)
        else
            local itemName = GetPlacedHousingFurnitureInfo(fid)
            if itemName and itemName ~= "" then
                local key = "name:" .. itemName
                local e = index[key]
                if e then e.q = e.q + 1 else
                    e = { n = FormatName(itemName), q = 1 }
                    index[key] = e
                    c.items[#c.items + 1] = e
                end
            end
        end
        count = count + 1
        fid = GetNextPlacedHousingFurnitureId(fid)
    end
    acct.shared["house_" .. houseId] = Seal(c)
    return true, houseName, count
end

local CURRENCIES = {
    CURT_MONEY, CURT_ALLIANCE_POINTS, CURT_TELVAR_STONES, CURT_WRIT_VOUCHERS,
    CURT_TRANSMUTE_CRYSTALS, CURT_UNDAUNTED_KEYS, CURT_SEALS, CURT_ARCHIVAL_FORTUNES,
    CURT_IMPERIAL_FRAGMENTS, CURT_STYLE_STONES, CURT_TOME_POINTS, CURT_TOME_TOKENS,
    CURT_TRADE_BARS, CURT_UNDAUNTED_CRESTS, CURT_CROWNS, CURT_CROWN_GEMS,
}

local function ScanCurrencies()
    local charC = NewContainer(charRec.name, "Character", "Wallet")
    local bankC = NewContainer(ACCOUNT_OWNER, "Bank", "Bank Wallet")
    local acctC = NewContainer(ACCOUNT_OWNER, "Account Wallet", "Account Wallet")
    for _, ctype in ipairs(CURRENCIES) do
        local cname = zo_strformat("<<1>>", GetCurrencyName(ctype, false, false))
        local loc = GetCurrencyPlayerStoredLocation(ctype)
        local amount = GetCurrencyAmount(ctype, loc)
        if amount > 0 then
            local target = (loc == CURRENCY_LOCATION_CHARACTER) and charC or acctC
            target.items[#target.items + 1] = { n = cname, q = amount, cur = true }
        end
        if loc == CURRENCY_LOCATION_CHARACTER and CanCurrencyBeStoredInLocation(ctype, CURRENCY_LOCATION_BANK) then
            local banked = GetCurrencyAmount(ctype, CURRENCY_LOCATION_BANK)
            if banked > 0 then
                bankC.items[#bankC.items + 1] = { n = cname, q = banked, cur = true }
            end
        end
    end
    charRec.containers.wallet = Seal(charC)
    acct.shared.bankwallet = Seal(bankC)
    acct.shared.acctwallet = Seal(acctC)
end

local function ScanEverythingReadable()
    ScanCharacterBags()
    ScanBank()
    ScanCraftBag()
    ScanCurrencies()
    ScanStorageIfReadable()
    charRec.updated = GetTimeStamp()
end

------------------------------------------------------------------------------
-- Debounced rescans
------------------------------------------------------------------------------
local openStorageBag = nil
local pending = {}

local function FlushPending()
    EVENT_MANAGER:UnregisterForUpdate(FIL.name .. "Debounce")
    if pending.char then ScanCharacterBags(); ScanCurrencies() end
    if pending.cur and not pending.char then ScanCurrencies() end
    if pending.bank then ScanBank() end
    if pending.craft then ScanCraftBag() end
    if pending.storage and openStorageBag then ScanStorageBag(openStorageBag) end
    if pending.house then ScanPlacedFurniture() end
    charRec.updated = GetTimeStamp()
    pending = {}
end

local function Queue(what, delay)
    pending[what] = true
    EVENT_MANAGER:UnregisterForUpdate(FIL.name .. "Debounce")
    EVENT_MANAGER:RegisterForUpdate(FIL.name .. "Debounce", delay or SCAN_DELAY_MS, FlushPending)
end

local function OnSlotUpdate(_, bagId)
    if bagId == BAG_BACKPACK or bagId == BAG_WORN or bagId == BAG_COMPANION_WORN then
        Queue("char")
    elseif bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK then
        Queue("bank")
    elseif bagId == BAG_VIRTUAL then
        Queue("craft")
    elseif bagId == openStorageBag then
        Queue("storage")
    end
end

local function OnOpenBank(_, bankBag)
    if bankBag == BAG_FURNITURE_VAULT or IsHouseBankBag(bankBag) then
        openStorageBag = bankBag
        ScanStorageBag(bankBag)
    else
        ScanBank()
    end
end

local function OnCloseBank()
    if openStorageBag then
        ScanStorageBag(openStorageBag)
        openStorageBag = nil
    end
    ScanBank()
end

-- The full read happens once per login or reload. After that the item, bank and currency
-- events keep everything current, so a zone change costs nothing.
local firstActivation = true

local function OnPlayerActivated()
    if firstActivation then
        firstActivation = false
        ScanEverythingReadable()
        -- 1.6.2: one line on a new install, like every Fury addon.
        if FIL.newInstall then
            FIL.Theme.Welcome(SV, "welcomeShown", "Welcome! Type /ledger for the summary of everything you own; its Start here button explains it in one page. Everything starts turned off.")
        end
    end
    if GetCurrentZoneHouseId() ~= 0 and IsOwnerOfCurrentHouse() then
        Queue("house", HOUSE_DELAY_MS)
    end
end

local function OnFurnitureChanged()
    if IsOwnerOfCurrentHouse() then Queue("house", 3000) end
end

------------------------------------------------------------------------------
-- Export
------------------------------------------------------------------------------
local HEADERS = {
    "Account", "Character", "Location", "Container", "Item", "Qty", "Quality",
    "Item Type", "Sub Type", "Equip Slot", "Armor/Weapon", "Trait", "Set", "Style",
    "Level", "CP", "Bound", "Stolen", "Crafted", "Vendor Value (each)", "Vendor Value (total)",
    "Item ID", "Scanned", "Item Link",
}
local LINK_COL = #HEADERS

local infoCache = {}
local function LinkInfo(link)
    local info = infoCache[link]
    if info then return info end
    info = {}
    if link:find(":collectible:", 1, true) then
        info.name = FormatName(GetCollectibleName(GetCollectibleIdFromLink(link)))
        info.itype = "Collectible"
        info.value = 0
        info.id = GetCollectibleIdFromLink(link) or ""
    else
        local itemType, specType = GetItemLinkItemType(link)
        local equipType = GetItemLinkEquipType(link)
        local armorType = GetItemLinkArmorType(link)
        local weaponType = GetItemLinkWeaponType(link)
        local traitType = GetItemLinkTraitInfo(link)
        local hasSet, setName = GetItemLinkSetInfo(link, false)
        info.name    = FormatName(GetItemLinkName(link))
        info.qnum    = GetItemLinkDisplayQuality(link)
        info.quality = EnumString("SI_ITEMDISPLAYQUALITY", info.qnum)
        info.itype   = EnumString("SI_ITEMTYPE", itemType, ITEMTYPE_NONE)
        info.stype   = EnumString("SI_SPECIALIZEDITEMTYPE", specType, SPECIALIZED_ITEMTYPE_NONE)
        info.equip   = EnumString("SI_EQUIPTYPE", equipType, EQUIP_TYPE_INVALID)
        if armorType and armorType ~= ARMORTYPE_NONE then
            info.gear = EnumString("SI_ARMORTYPE", armorType)
        elseif weaponType and weaponType ~= WEAPONTYPE_NONE then
            info.gear = EnumString("SI_WEAPONTYPE", weaponType)
        end
        info.trait   = EnumString("SI_ITEMTRAITTYPE", traitType, ITEM_TRAIT_TYPE_NONE)
        info.set     = hasSet and FormatName(setName) or ""
        if equipType ~= EQUIP_TYPE_INVALID then
            local style = GetItemLinkItemStyle(link)
            if style and style ~= 0 then info.style = zo_strformat("<<1>>", GetItemStyleName(style)) end
        end
        local lvl = GetItemLinkRequiredLevel(link)
        local cp  = GetItemLinkRequiredChampionPoints(link)
        info.level   = (lvl and lvl > 0) and lvl or ""
        info.cp      = (cp and cp > 0) and cp or ""
        info.crafted = IsItemLinkCrafted(link) and "Yes" or ""
        info.value   = GetItemLinkValue(link, false) or 0
        info.id      = GetItemLinkItemId(link)
    end
    infoCache[link] = info
    return info
end

local function BuildRows()
    local rows = {}
    local function addContainer(acctKey, cont)
        if not cont then return end
        local scanned = FormatTime(cont.updated)
        for _, it in ipairs(Items(cont)) do
            local r
            if it.l then
                local info = LinkInfo(it.l)
                r = {
                    acctKey, cont.owner, cont.location, cont.container, info.name, it.q, info.quality or "",
                    info.itype or "", info.stype or "", info.equip or "", info.gear or "", info.trait or "",
                    info.set or "", info.style or "", info.level or "", info.cp or "",
                    it.b and "Yes" or "", it.s and "Yes" or "", info.crafted or "",
                    info.value, info.value * it.q, info.id or "", scanned, it.l,
                }
            else
                r = {
                    acctKey, cont.owner, cont.location, cont.container, it.n or "", it.q, "",
                    it.cur and "Currency" or "Furniture", "", "", "", "", "", "", "", "",
                    "", "", "", "", "", "", scanned, "",
                }
            end
            for i = 1, #r do r[i] = Clean(r[i]) end
            rows[#rows + 1] = r
        end
    end

    for acctKey, a in pairs(SV.accounts) do
        for _, ch in pairs(a.chars) do
            for _, cont in pairs(ch.containers) do addContainer(acctKey, cont) end
        end
        for _, cont in pairs(a.shared) do addContainer(acctKey, cont) end
    end

    -- One sort key per row (account, owner, location, container, item), built once.
    -- Account-wide rows get an empty owner so they sort ahead of characters.
    local keys = {}
    for _, r in ipairs(rows) do
        local owner = (r[2] == ACCOUNT_OWNER) and "" or ("\2" .. r[2])
        keys[r] = table.concat({ r[1], owner, r[3], r[4], r[5], r[LINK_COL], r[17], r[18] }, "\1")   -- link, bound, stolen settle ties
    end
    table.sort(rows, function(x, y) return keys[x] < keys[y] end)
    return rows
end

local function SaveExport(rows)
    local out = { ROW_MARKER .. table.concat(HEADERS, "\t") }
    for _, r in ipairs(rows) do
        out[#out + 1] = ROW_MARKER .. table.concat(r, "\t")
    end
    SV.export = out
    SV.exportBuilt = GetTimeStamp()
end

-- The saved Excel list doubles the size of the saved file, so it is only kept when the
-- player asked for it: "Keep the Excel file ready" in the settings, or "Prepare the Excel file".
local exportPrepared = false

local function WantsExport()
    return SV.settings.autoExport or exportPrepared
end

-- Runs when the character leaves the world (logout, reload, zone change).
local function OnDeactivated()
    FlushPending()
    local today = os.date("%Y-%m-%d", GetTimeStamp())
    local needTotals = dirty or not (acct.history and acct.history[today])
    if dirty and WantsExport() then SaveExport(BuildRows()) end
    if needTotals then FIL.RecordSnapshot() end
    dirty = false
end

local RELOAD_TEXT = "<<1>> rows are ready for Excel. The game only writes them to your PC when the interface reloads or you log out.\n\nReload the interface now? You get a short loading screen. After it, run ExportToExcel.cmd from the Windows tools."
local function ReloadNow() ReloadUI("ingame") end
local function ReloadLater() Msg("The Excel list will be written the next time you log out or reload.") end

-- Builds the list for the Windows tools now, then offers to reload so the game writes it to disk.
function FIL.PrepareExport()
    FlushPending()
    local rows = BuildRows()
    SaveExport(rows)
    exportPrepared = true
    dirty = false
    -- 1.6.4: the pop-up is the shared one (Theme.lua), the same in every Fury addon.
    FIL.Theme.Confirm("Fury's Inventory Ledger", zo_strformat(RELOAD_TEXT, ZO_CommaDelimitNumber(#rows)), "Reload now", ReloadNow, ReloadLater)
end

local function CsvField(s)
    if s:find('[,"]') then return '"' .. s:gsub('"', '""') .. '"' end
    return s
end

-- Lines for the in-game copy window (no item link column, to keep pages small).
local function BuildCopyLines(rows)
    local sep = (SV.settings.sep == "comma") and "," or "\t"
    local function join(r)
        local parts = {}
        for i = 1, LINK_COL - 1 do
            parts[i] = (sep == ",") and CsvField(r[i]) or r[i]
        end
        return table.concat(parts, sep)
    end
    local hdr = {}
    for i = 1, LINK_COL - 1 do hdr[i] = HEADERS[i] end
    local lines = { table.concat(hdr, sep) }
    for _, r in ipairs(rows) do lines[#lines + 1] = join(r) end
    return lines
end

local function Paginate(lines)
    local pages, cur, len = {}, {}, 0
    for _, line in ipairs(lines) do
        if len + #line + 1 > PAGE_CHARS and #cur > 0 then
            pages[#pages + 1] = table.concat(cur, "\n")
            cur, len = {}, 0
        end
        cur[#cur + 1] = line
        len = len + #line + 1
    end
    if #cur > 0 then pages[#pages + 1] = table.concat(cur, "\n") end
    return pages
end

------------------------------------------------------------------------------
-- Copy window
------------------------------------------------------------------------------
local pages, pageIndex, rowCount = {}, 1, 0
local allRows = {}                 -- every row, before the two pickers narrow it
local copyFrom, copyType = nil, nil   -- chosen picker entries (nil = everything / all types)
local ALL_FROM, ALL_TYPES = "Everything on this PC", "All item types"

local function ShowPage()
    local win = FurysInventoryLedgerWindow
    local edit = win:GetNamedChild("EditBg"):GetNamedChild("Edit")
    edit:SetText(pages[pageIndex] or "")
    win:GetNamedChild("PageLabel"):SetText(zo_strformat("Page <<1>> of <<2>>", pageIndex, math.max(#pages, 1)))
    win:GetNamedChild("Prev"):SetEnabled(pageIndex > 1)
    win:GetNamedChild("Next"):SetEnabled(pageIndex < #pages)
end

-- The "List" picker: everything, this account, one character, or one kind of place.
local function FromChoices()
    local key = FIL.accountKey
    local list = { { name = ALL_FROM }, { name = "This account", col = 1, value = key } }
    local names = {}
    for _, ch in pairs(acct.chars) do names[#names + 1] = ch.name end
    table.sort(names)
    for _, name in ipairs(names) do list[#list + 1] = { name = name, col = 2, value = name } end
    for _, loc in ipairs({ "Bank", "Craft Bag", "House Storage", "Furniture Vault", "Placed in House" }) do
        list[#list + 1] = { name = loc, col = 3, value = loc }
    end
    return list
end

local function RowsFrom(choice)
    if not choice or not choice.col then return allRows end
    local key, out = FIL.accountKey, {}
    for _, r in ipairs(allRows) do
        if r[1] == key and r[choice.col] == choice.value then out[#out + 1] = r end
    end
    return out
end

local function ApplyCopyFilter()
    local rows = RowsFrom(copyFrom)
    if copyType then
        local out = {}
        for _, r in ipairs(rows) do
            if r[8] == copyType then out[#out + 1] = r end
        end
        rows = out
    end
    rowCount = #rows
    pages = Paginate(BuildCopyLines(rows))
    pageIndex = 1
    local win = FurysInventoryLedgerWindow
    local sepName = (SV.settings.sep == "comma") and "comma-separated" or "tab-separated"
    win:GetNamedChild("Info"):SetText(zo_strformat(
        (#pages > 1) and "<<1>> rows on <<3>> pages, <<2>>. On each page: Select All, Ctrl+C, paste into Excel under the last page."
            or "<<1>> rows, <<2>>. Click Select All, press Ctrl+C, then paste into Excel.",
        ZO_CommaDelimitNumber(rowCount), sepName, #pages))
    ShowPage()
end

-- The "Type" picker only offers item types that the chosen list really holds.
local function FillTypeCombo()
    local combo = ZO_ComboBox_ObjectFromContainer(FurysInventoryLedgerWindow:GetNamedChild("Type"))
    local seen, types = {}, {}
    for _, r in ipairs(RowsFrom(copyFrom)) do
        local t = r[8]
        if t ~= "" and not seen[t] then seen[t] = true; types[#types + 1] = t end
    end
    table.sort(types)
    if copyType and not seen[copyType] then copyType = nil end
    combo:SetSortsItems(false)
    combo:ClearItems()
    combo:AddItem(combo:CreateItemEntry(ALL_TYPES, function() FIL.PickCopyType(nil) end), ZO_COMBOBOX_SUPPRESS_UPDATE)
    for _, t in ipairs(types) do
        combo:AddItem(combo:CreateItemEntry(t, function() FIL.PickCopyType(t) end), ZO_COMBOBOX_SUPPRESS_UPDATE)
    end
    combo:UpdateItems()
    combo:SetSelectedItemText(copyType or ALL_TYPES)
end

local function FillFromCombo()
    local combo = ZO_ComboBox_ObjectFromContainer(FurysInventoryLedgerWindow:GetNamedChild("From"))
    combo:SetSortsItems(false)
    combo:ClearItems()
    local still = false
    for _, choice in ipairs(FromChoices()) do
        if copyFrom and copyFrom.name == choice.name then copyFrom, still = choice, true end
        combo:AddItem(combo:CreateItemEntry(choice.name, function() FIL.PickCopyFrom(choice) end), ZO_COMBOBOX_SUPPRESS_UPDATE)
    end
    if not still then copyFrom = nil end
    combo:UpdateItems()
    combo:SetSelectedItemText(copyFrom and copyFrom.name or ALL_FROM)
end

function FIL.PickCopyFrom(choice)
    copyFrom = choice
    FillTypeCombo()
    ApplyCopyFilter()
end

function FIL.PickCopyType(itemType)
    copyType = itemType
    ApplyCopyFilter()
end

function FIL.OpenWindow()
    FlushPending()
    allRows = BuildRows()
    FillFromCombo()
    FillTypeCombo()
    ApplyCopyFilter()
    SCENE_MANAGER:Show(FIL.COPY_SCENE)
end

function FIL.ToggleCopy()
    if SCENE_MANAGER:IsShowing(FIL.COPY_SCENE) then
        SCENE_MANAGER:Hide(FIL.COPY_SCENE)
    else
        FIL.OpenWindow()
    end
end

function FIL.PrevPage() if pageIndex > 1 then pageIndex = pageIndex - 1; ShowPage() end end
function FIL.NextPage() if pageIndex < #pages then pageIndex = pageIndex + 1; ShowPage() end end

function FIL.SelectAll()
    local edit = FurysInventoryLedgerWindow:GetNamedChild("EditBg"):GetNamedChild("Edit")
    edit:TakeFocus()
    edit:SelectAll()
end

function FIL.CloseWindow()
    if SCENE_MANAGER:IsShowing(FIL.COPY_SCENE) then SCENE_MANAGER:Hide(FIL.COPY_SCENE) end
end

-- Each window is its own scene, so Esc closes it, the mouse cursor comes up with it,
-- and opening a game menu (settings, map, inventory) hides it.
function FIL.CreateScene(sceneName, control)
    local scene = ZO_Scene:New(sceneName, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    scene:AddFragment(ZO_SimpleSceneFragment:New(control))
end

------------------------------------------------------------------------------
-- Settings page (Settings > Addons > Fury's Inventory Ledger), LibAddonMenu-2.0
------------------------------------------------------------------------------
local settingsPanel

function FIL.SetAutoExport(value)
    SV.settings.autoExport = value
    if value then dirty = true end
end

local function BuildSettings()
    local LAM = LibAddonMenu2
    settingsPanel = LAM:RegisterAddonPanel("FurysInventoryLedgerSettings", {
        type = "panel",
        name = FIL.title,
        displayName = TAG .. FIL.title .. "|r",
        author = "Furyous",
        version = FIL.version,
        website = "https://www.esoui.com/downloads/info5099.html",
        slashCommand = "/ledgersettings",
    })
    local options = {
        { type = "header", name = "Summary" },
        { type = "button", name = "Open the summary",
          tooltip = "Opens the summary window. /ledger does the same, and you can bind a key under Controls > Addon Keybinds.",
          func = function() FIL.OpenSummary() end },
        { type = "description",
          text = "Totals by item type, quality and location, currencies with changes since yesterday and the last 7 days, your most-owned items and every character. /ledger opens it." },

        { type = "header", name = "Copy window" },
        { type = "dropdown", name = "Separator",
          tooltip = "How columns are separated in the in-game copy window. Tab pastes straight into Excel columns; comma makes CSV.",
          choices = { "Tab", "Comma" }, choicesValues = { "tab", "comma" },
          getFunc = function() return SV.settings.sep end,
          setFunc = function(value) SV.settings.sep = value end },
        { type = "button", name = "Open the copy window",
          tooltip = "Opens the whole list as text you can copy and paste into Excel. /ledger copy does the same.",
          func = function() FIL.OpenWindow() end },

        { type = "header", name = "Item tooltips" },
        { type = "checkbox", name = "Show what I own on item tooltips",
          tooltip = "Adds one line to item tooltips, for example: You own 412: Bank 200, Craft Bag 212. It counts every character and account the addon has read. Starts turned off.",
          getFunc = function() return SV.settings.tooltip end,
          setFunc = function(value) SV.settings.tooltip = value end },

        { type = "header", name = "Scanning" },
        { type = "button", name = "Rescan now",
          tooltip = "Reads this character, the bank, the craft bag and any house storage that can be read right now.",
          func = function()
              ScanEverythingReadable()
              Msg("Rescanned this character, bank, craft bag and readable storage.")
          end },
        { type = "description",
          text = "The addon reads the character you are on. Log in once on each character to add it. Open each storage coffer and the Furniture Vault once, and visit each house you own. " ..
                 "The summary lists what is still to read. /ledger forget <name> drops a deleted character." },

        { type = "header", name = "Export to Excel (Windows)" },
        { type = "description",
          text = "For one spreadsheet file with every item: click Prepare the Excel file, then run ExportToExcel.cmd from the Windows tools. " ..
                 "The tools run outside the game, so ESOUI's rules keep them out of the addon download: they're a separate free zip. Unzip it into any folder." },
        { type = "button", name = "Prepare the Excel file",
          tooltip = "Builds the full list for the Windows tools, then asks before it reloads the interface so the game writes it to your PC.",
          func = function() FIL.PrepareExport() end },
        { type = "checkbox", name = "Keep the Excel file ready",
          tooltip = "On: the full list is saved again every time you log out, reload or change zone, so the Windows tools always have it. This about doubles the size of the addon's saved file. Off: the list is only saved when you click Prepare the Excel file. Starts turned off on new installs.",
          getFunc = function() return SV.settings.autoExport end,
          setFunc = function(value) FIL.SetAutoExport(value) end },
        { type = "button", name = "Get the Windows tools",
          tooltip = "Opens the download page on GitHub in your browser. The game asks before it opens.",
          func = function() RequestOpenUnsafeURL(FIL.toolsUrl) end },
    }
    FIL.Theme.MoreOptions(options)   -- 1.6.3: the other Fury addons, at the very end
    LAM:RegisterOptionControls("FurysInventoryLedgerSettings", options)
end

-- The gear on the copy window, /ledger settings and /ledgersettings all land here.
function FIL.OpenSettings()
    LibAddonMenu2:OpenToPanel(settingsPanel)
end

------------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------------
local function ListCharacters()
    local seen = {}
    Msg("Scanned characters for <<1>>:", GetDisplayName())
    for id, ch in pairs(acct.chars) do
        seen[id] = true
        Msg("  <<1>> - <<2>>", ch.name, FormatTime(ch.updated))
    end
    local missing = {}
    for i = 1, GetNumCharacters() do
        local name, _, _, _, _, _, id = GetCharacterInfo(i)
        if not seen[id] then missing[#missing + 1] = zo_strformat("<<1>>", name) end
    end
    if #missing > 0 then
        Msg("Not scanned yet (log in once on each): <<1>>", table.concat(missing, ", "))
    else
        Msg("Every character on this account has been scanned.")
    end
end

local function Forget(name)
    local typed = zo_strtrim(name or "")
    name = typed:lower()
    if name == "" then Msg("Usage: /ledger forget <character name>") return end
    for id, ch in pairs(acct.chars) do
        if ch.name:lower() == name then
            if id == GetCurrentCharacterId() then Msg("Can't forget the character you're logged in on.") return end
            acct.chars[id] = nil
            dirty = true
            Msg("Forgot <<1>>.", ch.name)
            return
        end
    end
    Msg("No scanned character named <<1>>. /ledger chars lists them.", typed)
end

------------------------------------------------------------------------------
-- Start here (1.6.2): one page on how the ledger works, the same window as every Fury addon.
------------------------------------------------------------------------------
local START = {
    { title = "1. Get your things on the list", lines = {
        "Log in on each character once. The ledger reads its bags, gear and wallet, the bank and the craft bag by itself, and again a moment after anything changes.",
        "Open and close each house storage coffer and the Furniture Vault once. Enter each house you own once to count the furniture placed there.",
        "The summary's Still to read section lists what is missing and how to add it. It disappears when nothing is left.",
    } },
    { title = "2. The summary", lines = {
        "Totals with the change since yesterday, every currency, where your things are, gold over time, space left, sets, split stacks and your most owned items.",
        "Type part of an item or set name in the Find box (top right) to see how many you own and where, on every character and account.",
    } },
    { title = "3. Get it out of the game", lines = {
        "Copy for Excel opens the whole list as text: Select All, Ctrl+C, paste into Excel or Google Sheets.",
        "For the full file, use Prepare the Excel file in the settings (or /ledger export) and the free Windows tools (/ledger tools).",
    } },
    { title = "4. Settings", lines = {
        "The gear at the top right opens the settings. Everything that can be turned off starts turned off, such as the line on item tooltips and keeping the Excel file ready.",
        "Type /ledger help any time for every command.",
    } },
}

function FIL.ShowStart()
    FIL.Theme.StartPage(FurysInventoryLedger_StartHere,
        FIL.title .. " v" .. FIL.version .. ": every item you own in one list, on every character and account.", START)
end

local function Slash(args)
    local cmd, rest = (args or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "show" or cmd == "summary" then
        FIL.OpenSummary()
    elseif cmd == "copy" then
        FIL.OpenWindow()
    elseif cmd == "export" or cmd == "excel" then
        FIL.PrepareExport()
    elseif cmd == "find" then
        FIL.FindToChat(rest)
    elseif cmd == "scan" then
        ScanEverythingReadable()
        local ok, house, count = ScanPlacedFurniture()
        Msg("Rescanned this character, bank, craft bag and readable storage.")
        if ok then Msg("Counted <<1>> placed furniture in <<2>>.", count, house) end
    elseif cmd == "start" then
        FIL.ShowStart()
    elseif cmd == "settings" then
        FIL.OpenSettings()
    elseif cmd == "tools" then
        RequestOpenUnsafeURL(FIL.toolsUrl)
    elseif cmd == "chars" then
        ListCharacters()
    elseif cmd == "forget" then
        Forget(rest)
    elseif cmd == "sep" then
        if rest == "comma" or rest == "tab" then
            SV.settings.sep = rest
            Msg("In-game copy will use <<1>> separators.", rest)
        else
            Msg("Usage: /ledger sep tab   or   /ledger sep comma")
        end
    else
        Help(FIL.title .. " v" .. FIL.version .. " commands:")
        Help("/ledger  open the summary")
        Help("/ledger start  the Start here page: how the ledger works, in one page")
        Help("/ledger find WORDS  where an item or set is, across every character and account")
        Help("/ledger copy  open the copy window (Excel-ready)")
        Help("/ledger export  prepare the full Excel file for the Windows tools (asks before it reloads)")
        Help("/ledger scan  rescan everything readable right now")
        Help("/ledger chars  list scanned characters and who's still missing")
        Help("/ledger forget NAME  drop a deleted character")
        Help("/ledger sep tab, /ledger sep comma  separator for the copy window")
        Help("/ledger settings  open the settings (or the gear on either window)")
        Help("/ledger tools  get the Windows tools (Excel export) from GitHub")
    end
end

------------------------------------------------------------------------------
-- Shared with Summary.lua
------------------------------------------------------------------------------
FIL.ACCOUNT_OWNER = ACCOUNT_OWNER
FIL.Items = Items
FIL.HouseBankBags = HouseBankBags
FIL.CollectibleLabel = CollectibleLabel
FIL.LinkInfo      = LinkInfo
FIL.FormatTime    = FormatTime
FIL.FlushPending  = FlushPending
FIL.Msg           = Msg
function FIL.GetAccount() return acct end
function FIL.GetAllAccounts() return SV.accounts end
function FIL.TooltipWanted() return SV.settings.tooltip end

------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------
local function OnLoaded(_, addonName)
    if addonName ~= FIL.name then return end
    EVENT_MANAGER:UnregisterForEvent(FIL.name, EVENT_ADD_ON_LOADED)

    local newInstall = (FurysInventoryLedger_SV == nil)
    FurysInventoryLedger_SV = FurysInventoryLedger_SV or {}
    SV = FurysInventoryLedger_SV
    -- Version 2 (1.5.1): items packed one line each. Containers saved by an older build are
    -- packed here once; Seal checks every line and leaves a container alone if it cannot.
    if (SV.version or 1) < 2 and SV.accounts then
        for _, a in pairs(SV.accounts) do
            for _, ch in pairs(a.chars or {}) do
                for _, cont in pairs(ch.containers or {}) do
                    if not cont.p and cont.items then Seal(cont) end
                end
            end
            for _, cont in pairs(a.shared or {}) do
                if not cont.p and cont.items then Seal(cont) end
            end
        end
    end
    SV.version  = 2
    SV.settings = SV.settings or { sep = "tab" }
    -- New in 1.5.0. Installs from before it always kept the Excel list, so they keep doing so;
    -- new installs start with it turned off.
    if SV.settings.autoExport == nil then SV.settings.autoExport = not newInstall end
    -- A list prepared by hand is dropped a day later, so it does not stay in the file for good.
    if not SV.settings.autoExport and SV.export and GetTimeStamp() - (SV.exportBuilt or 0) > 86400 then
        SV.export, SV.exportBuilt = nil, nil
    end
    SV.accounts = SV.accounts or {}

    local acctKey = GetDisplayName() .. " (" .. GetWorldName() .. ")"
    FIL.accountKey = acctKey
    SV.accounts[acctKey] = SV.accounts[acctKey] or { chars = {}, shared = {} }
    acct = SV.accounts[acctKey]

    local charId = GetCurrentCharacterId()
    acct.chars[charId] = acct.chars[charId] or { containers = {} }
    charRec = acct.chars[charId]
    charRec.name = zo_strformat("<<1>>", GetUnitName("player"))

    EVENT_MANAGER:RegisterForEvent(FIL.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(FIL.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)
    -- Only real item changes (added, removed, stack size). Skips durability, charge and other updates
    -- that fire constantly in combat and never change what you own.
    EVENT_MANAGER:AddFilterForEvent(FIL.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    -- Gold, AP, Tel Var, vouchers and the rest: keep the wallet current for the summary's running totals.
    EVENT_MANAGER:RegisterForEvent(FIL.name, EVENT_CURRENCY_UPDATE, function() Queue("cur") end)
    EVENT_MANAGER:RegisterForEvent(FIL.name, EVENT_OPEN_BANK, OnOpenBank)
    EVENT_MANAGER:RegisterForEvent(FIL.name, EVENT_CLOSE_BANK, OnCloseBank)
    EVENT_MANAGER:RegisterForEvent(FIL.name, EVENT_HOUSING_FURNITURE_PLACED, OnFurnitureChanged)
    EVENT_MANAGER:RegisterForEvent(FIL.name, EVENT_HOUSING_FURNITURE_REMOVED, OnFurnitureChanged)
    -- Daily totals, and the saved Excel list when it is wanted, but only if something changed.
    EVENT_MANAGER:RegisterForEvent(FIL.name, EVENT_PLAYER_DEACTIVATED, OnDeactivated)

    FIL.CreateScene(FIL.COPY_SCENE, FurysInventoryLedgerWindow)
    FIL.CreateScene(FIL.SUMMARY_SCENE, FurysInventoryLedgerSummary)
    FIL.Theme.Window(FurysInventoryLedgerWindow)
    FIL.Theme.Window(FurysInventoryLedgerSummary)
    -- The version sits beside each window title, so a build can be told apart at a glance.
    -- 1.6.2: the same header as every Fury addon (Theme.lua): title and version, Start here
    -- after them, the gear and close button at the right, each with a hover tip.
    local T = FIL.Theme
    T.SetTitle(FurysInventoryLedgerWindow, FIL.title .. " - Copy for Excel", FIL.version)
    T.SetTitle(FurysInventoryLedgerSummary, FIL.title, FIL.version)
    T.StartButton(FurysInventoryLedgerSummary, FIL.ShowStart,
        "New here? One page on how the ledger works: what it lists, when it reads, the summary and getting it into Excel.\n(also /ledger start)")
    T.CloseTip(FurysInventoryLedgerWindow:GetNamedChild("Close"))
    T.CloseTip(FurysInventoryLedgerSummary:GetNamedChild("Close"))
    -- The other Fury addons, one click each, in the title bar (Theme.lua).
    T.TitleIcons(FurysInventoryLedgerSummary, FurysInventoryLedgerSummary:GetNamedChild("Settings"))

    FIL.HookTooltips()
    FurysInventoryLedgerSummary:GetNamedChild("FindBg"):GetNamedChild("Edit"):SetDefaultText("Find an item or set")

    SLASH_COMMANDS["/ledger"] = Slash
    BuildSettings()
    FIL.newInstall = newInstall
end

EVENT_MANAGER:RegisterForEvent(FIL.name, EVENT_ADD_ON_LOADED, OnLoaded)
