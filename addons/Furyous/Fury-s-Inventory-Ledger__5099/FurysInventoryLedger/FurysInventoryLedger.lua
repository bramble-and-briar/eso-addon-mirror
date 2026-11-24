-- Fury's Inventory Ledger
-- Catalogs every item you own, everywhere, and exports it in an Excel-friendly format.
-- Author: Furyous

FurysInventoryLedger = FurysInventoryLedger or {}
local FIL = FurysInventoryLedger

FIL.name    = "FurysInventoryLedger"
FIL.title   = "Fury's Inventory Ledger"
FIL.version = "1.4.0"
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
    d(TAG .. "[Ledger]|r " .. zo_strformat(text, ...))
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

local function NewContainer(owner, location, container)
    return { owner = owner, location = location, container = container, updated = GetTimeStamp(), items = {} }
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
    charRec.containers.backpack = c

    c = NewContainer(name, "Character", "Equipped")
    ReadBag(c, BAG_WORN)
    charRec.containers.worn = c

    if HasActiveCompanion() then
        local defId = GetActiveCompanionDefId()
        local compName = zo_strformat("<<1>>", GetCompanionName(defId))
        c = NewContainer(name, "Companion", compName .. " (equipped)")
        ReadBag(c, BAG_COMPANION_WORN)
        charRec.containers["companion_" .. defId] = c
    end
end

local function ScanBank()
    local c = NewContainer(ACCOUNT_OWNER, "Bank", "Bank")
    local index = ReadBag(c, BAG_BANK)
    ReadBag(c, BAG_SUBSCRIBER_BANK, index)
    acct.shared.bank = c
end

local function ScanCraftBag()
    local c = NewContainer(ACCOUNT_OWNER, "Craft Bag", "Craft Bag")
    ReadBag(c, BAG_VIRTUAL)
    acct.shared.craftbag = c
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
        acct.shared.vault = c
    elseif IsHouseBankBag(bagId) then
        local label = CollectibleLabel(GetCollectibleForBag(bagId))
        if label == "" then label = "Storage " .. (bagId - BAG_HOUSE_BANK_ONE + 1) end
        local c = NewContainer(ACCOUNT_OWNER, "House Storage", label)
        ReadBag(c, bagId)
        acct.shared["housebank_" .. bagId] = c
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
    acct.shared["house_" .. houseId] = c
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
    charRec.containers.wallet = charC
    acct.shared.bankwallet = bankC
    acct.shared.acctwallet = acctC
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

local function OnPlayerActivated()
    ScanEverythingReadable()
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
        if not cont or not cont.items then return end
        local scanned = FormatTime(cont.updated)
        for _, it in ipairs(cont.items) do
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

    table.sort(rows, function(x, y)
        for i = 1, 5 do
            if x[i] ~= y[i] then
                -- account-wide rows sort ahead of characters
                if i == 2 then
                    if x[2] == ACCOUNT_OWNER then return true end
                    if y[2] == ACCOUNT_OWNER then return false end
                end
                return x[i] < y[i]
            end
        end
        return false
    end)
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

local function ShowPage()
    local win = FurysInventoryLedgerWindow
    local edit = win:GetNamedChild("EditBg"):GetNamedChild("Edit")
    edit:SetText(pages[pageIndex] or "")
    win:GetNamedChild("PageLabel"):SetText(zo_strformat("Page <<1>> of <<2>>", pageIndex, #pages))
    win:GetNamedChild("Prev"):SetEnabled(pageIndex > 1)
    win:GetNamedChild("Next"):SetEnabled(pageIndex < #pages)
end

function FIL.OpenWindow()
    FlushPending()
    local rows = BuildRows()
    SaveExport(rows)
    rowCount = #rows
    pages = Paginate(BuildCopyLines(rows))
    pageIndex = 1
    local win = FurysInventoryLedgerWindow
    local sepName = (SV.settings.sep == "comma") and "comma-separated" or "tab-separated"
    win:GetNamedChild("Info"):SetText(zo_strformat(
        "<<1>> rows, <<2>>. Click Select All, press Ctrl+C, paste into Excel. Paste each page under the last.",
        ZO_CommaDelimitNumber(rowCount), sepName))
    ShowPage()
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

local function BuildSettings()
    local LAM = LibAddonMenu2
    settingsPanel = LAM:RegisterAddonPanel("FurysInventoryLedgerSettings", {
        type = "panel",
        name = FIL.title,
        displayName = TAG .. FIL.title .. "|r",
        author = "Furyous",
        version = FIL.version,
        slashCommand = "/ledgersettings",
    })
    LAM:RegisterOptionControls("FurysInventoryLedgerSettings", {
        { type = "header", name = "Summary" },
        { type = "button", name = "Open the summary", func = function() FIL.OpenSummary() end },
        { type = "description",
          text = "Totals by item type, quality and location, currencies with changes since yesterday and the last 7 days, your most-owned items and every character. /ledger opens it." },

        { type = "header", name = "Copy window" },
        { type = "dropdown", name = "Separator",
          tooltip = "How columns are separated in the in-game copy window. Tab pastes straight into Excel columns; comma makes CSV.",
          choices = { "Tab", "Comma" }, choicesValues = { "tab", "comma" },
          getFunc = function() return SV.settings.sep end,
          setFunc = function(value) SV.settings.sep = value end },
        { type = "button", name = "Open the copy window", func = function() FIL.OpenWindow() end },

        { type = "header", name = "Scanning" },
        { type = "button", name = "Rescan now",
          tooltip = "Reads this character, the bank, the craft bag and any house storage that can be read right now.",
          func = function()
              ScanEverythingReadable()
              Msg("Rescanned this character, bank, craft bag and readable storage.")
          end },
        { type = "description",
          text = "/ledger chars lists the characters scanned so far and the ones still missing. /ledger forget <name> drops a deleted character." },

        { type = "header", name = "Export to Excel (Windows)" },
        { type = "description",
          text = "Type /reloadui (or log out), then run ExportToExcel.cmd from the Windows tools for a full spreadsheet file. " ..
                 "The tools run outside the game, so ESOUI's rules keep them out of the addon download: they're a separate free zip. Unzip it into any folder." },
        { type = "button", name = "Get the Windows tools",
          tooltip = "Opens the download page on GitHub in your browser. The game asks before it opens.",
          func = function() RequestOpenUnsafeURL(FIL.toolsUrl) end },
    })
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
    name = zo_strtrim(name or ""):lower()
    if name == "" then Msg("Usage: /ledger forget <character name>") return end
    for id, ch in pairs(acct.chars) do
        if ch.name:lower() == name then
            if id == GetCurrentCharacterId() then Msg("Can't forget the character you're logged in on.") return end
            acct.chars[id] = nil
            Msg("Forgot <<1>>.", ch.name)
            return
        end
    end
    Msg("No scanned character named <<1>>.", name)
end

local function Slash(args)
    local cmd, rest = (args or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "show" or cmd == "summary" then
        FIL.OpenSummary()
    elseif cmd == "copy" or cmd == "export" then
        FIL.OpenWindow()
    elseif cmd == "scan" then
        ScanEverythingReadable()
        local ok, house, count = ScanPlacedFurniture()
        Msg("Rescanned this character, bank, craft bag and readable storage.")
        if ok then Msg("Counted <<1>> placed furniture in <<2>>.", count, house) end
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
        Msg("Commands:")
        d("  /ledger - open the summary")
        d("  /ledger copy - open the copy window (Excel-ready)")
        d("  /ledger scan - rescan everything readable right now")
        d("  /ledger chars - list scanned characters and who's still missing")
        d("  /ledger forget <name> - drop a deleted character")
        d("  /ledger sep tab|comma - separator for the copy window")
        d("  /ledger settings - open the settings (or the gear on either window)")
        d("  /ledger tools - get the Windows tools (Excel export) from GitHub")
        d("  For a full spreadsheet file, /reloadui then run ExportToExcel.cmd from the Windows tools.")
    end
end

------------------------------------------------------------------------------
-- Shared with Summary.lua
------------------------------------------------------------------------------
FIL.ACCOUNT_OWNER = ACCOUNT_OWNER
FIL.LinkInfo      = LinkInfo
FIL.FormatTime    = FormatTime
FIL.FlushPending  = FlushPending
FIL.Msg           = Msg
function FIL.GetAccount() return acct end

------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------
local function OnLoaded(_, addonName)
    if addonName ~= FIL.name then return end
    EVENT_MANAGER:UnregisterForEvent(FIL.name, EVENT_ADD_ON_LOADED)

    FurysInventoryLedger_SV = FurysInventoryLedger_SV or {}
    SV = FurysInventoryLedger_SV
    SV.version  = 1
    SV.settings = SV.settings or { sep = "tab" }
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
    -- Rebuild the saved export on every logout / reload / zone change so the file is always current.
    EVENT_MANAGER:RegisterForEvent(FIL.name, EVENT_PLAYER_DEACTIVATED, function()
        FlushPending()
        SaveExport(BuildRows())
        FIL.RecordSnapshot()
    end)

    FIL.CreateScene(FIL.COPY_SCENE, FurysInventoryLedgerWindow)
    FIL.CreateScene(FIL.SUMMARY_SCENE, FurysInventoryLedgerSummary)
    FIL.Theme.Window(FurysInventoryLedgerWindow)
    FIL.Theme.Window(FurysInventoryLedgerSummary)

    SLASH_COMMANDS["/ledger"] = Slash
    BuildSettings()
end

EVENT_MANAGER:RegisterForEvent(FIL.name, EVENT_ADD_ON_LOADED, OnLoaded)
