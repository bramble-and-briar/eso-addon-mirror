-- MANA Bank by Beardborn
-- Deposits items into the bank up to a set number of stacks per rule and marks
-- the excess left in the inventory as junk. Optionally keeps a set amount of gold on hand.
-- Texts live in lang/en.lua (default) and lang/<language>.lua.
-- AI disclosure: written with the help of an AI assistant (Claude by Anthropic) from the author's design;
-- tested in game and maintained by the author.

-- The single global MANABank is shared with the language files in lang/.
MANABank = MANABank or {}
local BR = MANABank
local L = BR.L

BR.name = "MANABank"
BR.displayName = "MANA Bank"
BR.version = "1.0.1"
BR.author = "Beardborn"

local SV_VERSION = 1
local DEFAULTS = {
    enabled = true,
    markJunk = true,
    chat = true,
    respectFCOIS = true, -- honour FCO ItemSaver protection when marking junk
    delay = 100,
    goldEnabled = false,
    goldKeep = 10000,    -- gold to keep on hand
    goldWithdraw = true, -- withdraw the shortfall from the bank
    itemRules = {},     -- [itemId] = { stacks = n, name = "...", link = "..." }
    categoryRules = {},  -- [itemType] = n
}

local UNLIMITED = -1             -- "unlimited": deposit everything, never mark as junk
local STACK_CHOICES = { 0, 1, 2, 3, 5, 10, UNLIMITED }
local MOVE_TIMEOUT_MS = 1500   -- how long to wait for the server to confirm a move
local MAX_STALLS = 3           -- how many failed moves in a row before giving up

-- Item types offered as categories (labels come from L.CATEGORY).
-- Constants unknown to the current game version are skipped.
local CATEGORY_DEFS = {
    "ITEMTYPE_STYLE_MATERIAL", "ITEMTYPE_RAW_MATERIAL",
    "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL", "ITEMTYPE_BLACKSMITHING_MATERIAL", "ITEMTYPE_BLACKSMITHING_BOOSTER",
    "ITEMTYPE_CLOTHIER_RAW_MATERIAL", "ITEMTYPE_CLOTHIER_MATERIAL", "ITEMTYPE_CLOTHIER_BOOSTER",
    "ITEMTYPE_WOODWORKING_RAW_MATERIAL", "ITEMTYPE_WOODWORKING_MATERIAL", "ITEMTYPE_WOODWORKING_BOOSTER",
    "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL", "ITEMTYPE_JEWELRYCRAFTING_MATERIAL",
    "ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER", "ITEMTYPE_JEWELRYCRAFTING_BOOSTER",
    "ITEMTYPE_JEWELRY_RAW_TRAIT", "ITEMTYPE_JEWELRY_TRAIT",
    "ITEMTYPE_ARMOR_TRAIT", "ITEMTYPE_WEAPON_TRAIT",
    "ITEMTYPE_ENCHANTING_RUNE_ASPECT", "ITEMTYPE_ENCHANTING_RUNE_ESSENCE", "ITEMTYPE_ENCHANTING_RUNE_POTENCY",
    "ITEMTYPE_ENCHANTMENT_BOOSTER",
    "ITEMTYPE_INGREDIENT", "ITEMTYPE_REAGENT", "ITEMTYPE_POTION_BASE", "ITEMTYPE_POISON_BASE",
    "ITEMTYPE_FURNISHING_MATERIAL",
    "ITEMTYPE_GLYPH_ARMOR", "ITEMTYPE_GLYPH_WEAPON", "ITEMTYPE_GLYPH_JEWELRY",
    "ITEMTYPE_FOOD", "ITEMTYPE_DRINK", "ITEMTYPE_POTION", "ITEMTYPE_POISON",
    "ITEMTYPE_RECIPE", "ITEMTYPE_RACIAL_STYLE_MOTIF",
    "ITEMTYPE_SOUL_GEM", "ITEMTYPE_LURE", "ITEMTYPE_FISH",
    "ITEMTYPE_TROPHY", "ITEMTYPE_TREASURE", "ITEMTYPE_CONTAINER",
    "ITEMTYPE_FURNISHING", "ITEMTYPE_DYE_STAMP", "ITEMTYPE_MASTER_WRIT",
    "ITEMTYPE_SCRIBING_INK", "ITEMTYPE_TOOL", "ITEMTYPE_AVA_REPAIR", "ITEMTYPE_SIEGE",
    "ITEMTYPE_COSTUME", "ITEMTYPE_DISGUISE",
    "ITEMTYPE_ARMOR", "ITEMTYPE_WEAPON",
}

local sv
local running = false
local queue, queueIndex = {}, 1
local waiting, waitToken = false, 0
local totals = { deposited = 0, junked = 0, full = false }
local panel
local ui = { category = nil, catStacks = 1, item = nil, itemStacks = 1 }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local PREFIX = "|c88CCFF[MANA Bank]|r "

local function Say(text)        -- always
    d(PREFIX .. text)
end

local function Msg(text)        -- only if chat messages are enabled
    if sv and sv.chat then Say(text) end
end

local function StacksText(n)
    if n == UNLIMITED then return L.UNLIMITED end
    if n == 0 then return L.ZERO_STACKS end
    return L.STACKS(n)
end

local function Quote(text) return L.Q_OPEN .. text .. L.Q_CLOSE end

local function ItemName(link)
    return zo_strformat("<<t:1>>", GetItemLinkName(link))
end

local categoryLabels -- [itemType] = label, filled on load

function BR.GetCategoryName(itemType)
    if categoryLabels and categoryLabels[itemType] then return categoryLabels[itemType] end
    local name = GetString("SI_ITEMTYPE", itemType)
    if not name or name == "" then return string.format(L.TYPE_FALLBACK, tostring(itemType)) end
    return zo_strformat("<<1>>", name)
end

local function BuildCategoryList()
    local list = {}
    categoryLabels = {}
    for _, constName in ipairs(CATEGORY_DEFS) do
        local itemType = _G[constName]
        if itemType and not categoryLabels[itemType] then
            local label = L.CATEGORY[constName] or BR.GetCategoryName(itemType)
            categoryLabels[itemType] = label
            list[#list + 1] = { itemType = itemType, name = label }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

---------------------------------------------------------------------------
-- Rules
---------------------------------------------------------------------------

-- An item rule takes priority over a category rule.
function BR.GetRuleFor(bagId, slotIndex)
    local itemRule = sv.itemRules[GetItemId(bagId, slotIndex)]
    if itemRule then return itemRule.stacks end
    return sv.categoryRules[GetItemType(bagId, slotIndex)]
end

function BR.SetItemRule(itemId, stacks, link)
    sv.itemRules[itemId] = { stacks = stacks, name = ItemName(link), link = link }
    Say(string.format(L.MSG_ITEM_RULE, link, StacksText(stacks)))
    BR.RefreshSettings()
end

function BR.RemoveItemRule(itemId)
    local rule = sv.itemRules[itemId]
    sv.itemRules[itemId] = nil
    if rule then Say(string.format(L.MSG_RULE_REMOVED, rule.link or rule.name)) end
    BR.RefreshSettings()
end

function BR.SetCategoryRule(itemType, stacks)
    sv.categoryRules[itemType] = stacks
    Say(string.format(L.MSG_CAT_RULE, Quote(BR.GetCategoryName(itemType)), StacksText(stacks)))
    BR.RefreshSettings()
end

function BR.RemoveCategoryRule(itemType)
    if sv.categoryRules[itemType] == nil then return end
    sv.categoryRules[itemType] = nil
    Say(string.format(L.MSG_CAT_RULE_REMOVED, Quote(BR.GetCategoryName(itemType))))
    BR.RefreshSettings()
end

---------------------------------------------------------------------------
-- Item checks
---------------------------------------------------------------------------

-- Can the item be deposited at all?
local function IsBankable(bagId, slotIndex)
    if IsItemJunk(bagId, slotIndex) then return false end  -- junk stays in the inventory
    if IsItemStolen(bagId, slotIndex) then return false end
    if IsItemBoundToCharacter and IsItemBoundToCharacter(bagId, slotIndex) then return false end
    return true
end

-- Never mark as junk: locked items (game lock or FCO ItemSaver).
-- FCO ItemSaver: use its dedicated API for the exact action (not the generic FCOIS.IsLocked,
-- which depends on the currently open panel). If a function is missing, fall back to
-- "marked with any icon" so that items are rather kept than destroyed.
local FCOIS_API = {
    junk = { "IsJunkLocked", "IsVendorSellLocked" },
}

local function IsFCOISProtected(bagId, slotIndex, action)
    if not sv.respectFCOIS or not FCOIS then return false end
    for _, fnName in ipairs(FCOIS_API[action] or {}) do
        local fn = FCOIS[fnName]
        if fn then
            local ok, locked
            if fnName == "IsDeconstructionLocked" then
                ok, locked = pcall(fn, bagId, slotIndex, nil)  -- nil: FCOIS also checks jewelry itself
            else
                ok, locked = pcall(fn, bagId, slotIndex)
            end
            return ok and locked == true
        end
    end
    if FCOIS.IsMarked then
        local ok, marked = pcall(FCOIS.IsMarked, bagId, slotIndex, -1)
        return ok and marked == true
    end
    return false
end

-- Never mark as junk: locked items (game lock or FCO ItemSaver protection against junk/selling).
local function IsProtectedFromJunk(bagId, slotIndex)
    if IsItemPlayerLocked(bagId, slotIndex) then return true end
    if IsFCOISProtected(bagId, slotIndex, "junk") then return true end
    return not CanItemBeMarkedAsJunk(bagId, slotIndex)
end

---------------------------------------------------------------------------
-- Banking
---------------------------------------------------------------------------

local function GetItemState(itemId)
    local state = { bankCount = 0, maxStack = 1, sources = {} }

    for slot in ZO_IterateBagSlots(BAG_BANK) do
        if GetItemId(BAG_BANK, slot) == itemId then
            local count, maxStack = GetSlotStackSize(BAG_BANK, slot)
            state.bankCount = state.bankCount + count
            if maxStack > state.maxStack then state.maxStack = maxStack end
        end
    end

    for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
        if GetItemId(BAG_BACKPACK, slot) == itemId and IsBankable(BAG_BACKPACK, slot) then
            local count, maxStack = GetSlotStackSize(BAG_BACKPACK, slot)
            if maxStack > state.maxStack then state.maxStack = maxStack end
            state.sources[#state.sources + 1] = { slot = slot, count = count }
        end
    end

    return state
end

-- Destination: first a partial stack of the same item, then an empty slot.
local function FindDestination(instanceId, maxStack)
    if maxStack > 1 then
        for slot in ZO_IterateBagSlots(BAG_BANK) do
            if GetItemInstanceId(BAG_BANK, slot) == instanceId then
                local count, max = GetSlotStackSize(BAG_BANK, slot)
                if count < max then return slot, max - count end
            end
        end
    end
    local empty = FindFirstEmptySlotInBag(BAG_BANK)
    if empty then return empty, maxStack end
    return nil
end

local function MoveToBank(srcSlot, destSlot, qty)
    if IsProtectedFunction("RequestMoveItem") then
        CallSecureProtected("RequestMoveItem", BAG_BACKPACK, srcSlot, BAG_BANK, destSlot, qty)
    else
        RequestMoveItem(BAG_BACKPACK, srcSlot, BAG_BANK, destSlot, qty)
    end
end

local function BuildQueue()
    local list, seen = {}, {}
    for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
        local itemId = GetItemId(BAG_BACKPACK, slot)
        if itemId ~= 0 and not seen[itemId] and IsBankable(BAG_BACKPACK, slot) then
            local stacks = BR.GetRuleFor(BAG_BACKPACK, slot)
            if stacks then
                seen[itemId] = true
                list[#list + 1] = {
                    itemId = itemId,
                    stacks = stacks,
                    link = GetItemLink(BAG_BACKPACK, slot),
                    deposited = 0,
                    junked = 0,
                    protected = 0,
                    stalls = 0,
                    lastBankCount = nil,
                    bankFull = false,
                }
            end
        end
    end
    return list
end

local function Finish()
    running = false
    waiting = false
    if totals.deposited > 0 or totals.junked > 0 then
        Msg(string.format(L.DONE, totals.deposited, totals.junked))
    end
    if totals.full then
        Say("|cFF6666" .. L.BANK_FULL .. "|r")
    end
end

local function ReportJob(job)
    local parts = {}
    if job.deposited > 0 then parts[#parts + 1] = string.format(L.JOB_DEPOSITED, job.deposited) end
    if job.junked > 0 then parts[#parts + 1] = string.format(L.JOB_JUNKED, job.junked) end
    if job.protected > 0 then parts[#parts + 1] = string.format(L.JOB_LOCKED, job.protected) end
    if job.bankFull then parts[#parts + 1] = "|cFF6666" .. L.JOB_BANK_FULL .. "|r" end
    if job.stalls >= MAX_STALLS then parts[#parts + 1] = "|cFF6666" .. L.JOB_STALLED .. "|r" end
    if #parts > 0 then Msg(job.link .. ": " .. table.concat(parts, ", ")) end
end

local ProcessStep

local function ContinueAfterMove(token)
    if not running or not waiting or token ~= waitToken then return end
    waiting = false
    zo_callLater(ProcessStep, sv.delay)
end

local function WaitForMove()
    waitToken = waitToken + 1
    waiting = true
    local token = waitToken
    zo_callLater(function() ContinueAfterMove(token) end, MOVE_TIMEOUT_MS)
end

local function NextJob(job)
    ReportJob(job)
    queueIndex = queueIndex + 1
    zo_callLater(ProcessStep, 10)
end

ProcessStep = function()
    if not running then return end
    local job = queue[queueIndex]
    if not job then return Finish() end

    local state = GetItemState(job.itemId)
    local target = (job.stacks == UNLIMITED) and math.huge or job.stacks * state.maxStack
    local need = target - state.bankCount

    -- Guard against an endless loop if the server rejects the move.
    if job.lastBankCount ~= nil and job.lastBankCount == state.bankCount then
        job.stalls = job.stalls + 1
        if job.stalls >= MAX_STALLS then return NextJob(job) end
    end

    if need > 0 and #state.sources > 0 then
        local src = state.sources[1]
        local instanceId = GetItemInstanceId(BAG_BACKPACK, src.slot)
        local destSlot, room = FindDestination(instanceId, state.maxStack)
        if destSlot then
            local qty = math.min(need, src.count, room)
            job.lastBankCount = state.bankCount
            MoveToBank(src.slot, destSlot, qty)
            job.deposited = job.deposited + qty
            totals.deposited = totals.deposited + qty
            WaitForMove()
            return
        end
        job.bankFull = true
        totals.full = true
    end

    -- Bank limit reached: everything left in the inventory goes to junk.
    if need <= 0 and sv.markJunk then
        for _, src in ipairs(state.sources) do
            if not IsItemJunk(BAG_BACKPACK, src.slot) then
                if IsProtectedFromJunk(BAG_BACKPACK, src.slot) then
                    job.protected = job.protected + src.count
                else
                    SetItemIsJunk(BAG_BACKPACK, src.slot, true)
                    job.junked = job.junked + src.count
                    totals.junked = totals.junked + src.count
                end
            end
        end
    end

    NextJob(job)
end

-- Gold: keep exactly sv.goldKeep on hand.
-- Excess goes to the bank, the shortfall comes from the bank (if enabled and available).
local function MoveGold(amount, toBank)
    local from = toBank and CURRENCY_LOCATION_CHARACTER or CURRENCY_LOCATION_BANK
    local to = toBank and CURRENCY_LOCATION_BANK or CURRENCY_LOCATION_CHARACTER
    if TransferCurrency and CURRENCY_LOCATION_CHARACTER and CURRENCY_LOCATION_BANK then
        TransferCurrency(CURT_MONEY, amount, from, to)
    elseif toBank then
        DepositCurrencyIntoBank(CURT_MONEY, amount)
    else
        WithdrawCurrencyFromBank(CURT_MONEY, amount)
    end
end

local function BalanceGold()
    if not sv.goldEnabled then return end
    local keep = sv.goldKeep or 0
    local carried = GetCarriedCurrencyAmount(CURT_MONEY)

    if carried > keep then
        local excess = carried - keep
        MoveGold(excess, true)
        Msg(string.format(L.GOLD_DEPOSIT,
            ZO_CommaDelimitNumber(excess), ZO_CommaDelimitNumber(keep)))
    elseif carried < keep and sv.goldWithdraw then
        local banked = GetBankedCurrencyAmount(CURT_MONEY)
        local amount = math.min(keep - carried, banked)
        if amount > 0 then
            MoveGold(amount, false)
            Msg(string.format(L.GOLD_WITHDRAW,
                ZO_CommaDelimitNumber(amount), ZO_CommaDelimitNumber(carried + amount)))
        end
        if banked < keep - carried then
            Msg(string.format(L.GOLD_SHORT, ZO_CommaDelimitNumber(keep)))
        end
    end
end

function BR.Run()
    if running then return end
    if not IsBankOpen() then
        Say(L.OPEN_BANK_FIRST)
        return
    end
    BalanceGold()
    queue = BuildQueue()
    queueIndex = 1
    totals = { deposited = 0, junked = 0, full = false }
    if #queue == 0 then return end
    running = true
    ProcessStep()
end

local function OnOpenBank(_, bankBag)
    if not sv.enabled then return end
    if bankBag ~= nil and bankBag ~= BAG_BANK then return end  -- ignore house storage chests
    zo_callLater(BR.Run, 300)
end

local function OnCloseBank()
    if running then
        running = false
        waiting = false
        Say(L.BANK_CLOSED)
    end
end

local function OnBankSlotUpdate()
    if waiting then ContinueAfterMove(waitToken) end
end

---------------------------------------------------------------------------
-- Context menu (right-click on an item)
---------------------------------------------------------------------------

local function BuildStackEntries(current, onPick, onRemove)
    local entries = {}
    for _, n in ipairs(STACK_CHOICES) do
        local label = StacksText(n)
        if n == current then label = "» " .. label end
        entries[#entries + 1] = { label = label, callback = function() onPick(n) end }
    end
    if current ~= nil then
        entries[#entries + 1] = { label = L.REMOVE_RULE, callback = onRemove }
    end
    return entries
end

local function AddContextMenu(inventorySlot, slotActions)
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if bagId ~= BAG_BACKPACK and bagId ~= BAG_BANK then return end
    local itemId = GetItemId(bagId, slotIndex)
    if not itemId or itemId == 0 then return end

    local link = GetItemLink(bagId, slotIndex)
    local itemType = GetItemType(bagId, slotIndex)

    local itemRule = sv.itemRules[itemId]
    local itemCurrent = itemRule and itemRule.stacks
    local itemTitle = L.MENU_ITEM
    if itemCurrent then itemTitle = itemTitle .. " (" .. StacksText(itemCurrent) .. ")" end
    AddCustomSubMenuItem(itemTitle, BuildStackEntries(itemCurrent,
        function(n) BR.SetItemRule(itemId, n, link) end,
        function() BR.RemoveItemRule(itemId) end))

    if itemType and itemType ~= ITEMTYPE_NONE then
        local catCurrent = sv.categoryRules[itemType]
        local catTitle = string.format(L.MENU_CATEGORY, Quote(BR.GetCategoryName(itemType)))
        if catCurrent then catTitle = catTitle .. " (" .. StacksText(catCurrent) .. ")" end
        AddCustomSubMenuItem(catTitle, BuildStackEntries(catCurrent,
            function(n) BR.SetCategoryRule(itemType, n) end,
            function() BR.RemoveCategoryRule(itemType) end))
    end
end

---------------------------------------------------------------------------
-- Settings (LibAddonMenu)
---------------------------------------------------------------------------

local function CategoryRulesText()
    local lines = {}
    for itemType, stacks in pairs(sv.categoryRules) do
        lines[#lines + 1] = BR.GetCategoryName(itemType) .. ": " .. StacksText(stacks)
    end
    if #lines == 0 then return L.NO_RULES end
    table.sort(lines)
    return table.concat(lines, "\n")
end

local function ItemRulesText()
    local lines = {}
    for _, rule in pairs(sv.itemRules) do
        lines[#lines + 1] = (rule.name or "?") .. ": " .. StacksText(rule.stacks)
    end
    if #lines == 0 then return L.NO_ITEM_RULES end
    table.sort(lines)
    return table.concat(lines, "\n")
end

local function ItemChoices()
    local ids = {}
    for id in pairs(sv.itemRules) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b)
        return (sv.itemRules[a].name or "") < (sv.itemRules[b].name or "")
    end)
    local names, values = {}, {}
    for _, id in ipairs(ids) do
        names[#names + 1] = sv.itemRules[id].name or tostring(id)
        values[#values + 1] = id
    end
    if #names == 0 then
        names[1] = "—"
        values[1] = 0
    end
    return names, values
end

local function SetDescription(refName, text)
    local ctrl = _G[refName]
    if not ctrl then return end
    if ctrl.data then ctrl.data.text = text end
    if ctrl.desc then ctrl.desc:SetText(text) end
end

function BR.RefreshSettings()
    if ui.item and not sv.itemRules[ui.item] then ui.item = nil end
    local dropdown = _G["MANABank_ItemDropdown"]
    if dropdown and dropdown.UpdateChoices then
        local names, values = ItemChoices()
        dropdown:UpdateChoices(names, values)
    end
    SetDescription("MANABank_CategoryList", CategoryRulesText())
    SetDescription("MANABank_ItemList", ItemRulesText())
    if panel then CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel) end
end

local function CreateSettings()
    local LAM = LibAddonMenu2

    local categories = BuildCategoryList()
    local catNames, catValues = {}, {}
    for _, c in ipairs(categories) do
        catNames[#catNames + 1] = c.name
        catValues[#catValues + 1] = c.itemType
    end
    ui.category = catValues[1]
    local itemNames, itemValues = ItemChoices()

    panel = LAM:RegisterAddonPanel("MANABank_Panel", {
        type = "panel",
        name = BR.displayName,
        displayName = BR.displayName,
        author = BR.author,
        version = BR.version,
        slashCommand = "/manabanksettings",
        registerForRefresh = true,
    })

    local options = {
        { type = "description",
          text = L.SET_DESC },

        { type = "header", name = L.SET_GENERAL },
        { type = "checkbox", name = L.SET_ENABLE,
          getFunc = function() return sv.enabled end,
          setFunc = function(v) sv.enabled = v end },
        { type = "checkbox", name = L.SET_JUNK,
          tooltip = L.SET_JUNK_TT,
          getFunc = function() return sv.markJunk end,
          setFunc = function(v) sv.markJunk = v end },
        { type = "checkbox", name = L.SET_CHAT,
          getFunc = function() return sv.chat end,
          setFunc = function(v) sv.chat = v end },
        { type = "checkbox", name = L.SET_FCOIS, tooltip = L.SET_FCOIS_TT,
          getFunc = function() return sv.respectFCOIS end,
          setFunc = function(v) sv.respectFCOIS = v end },
        { type = "slider", name = L.SET_DELAY,
          tooltip = L.SET_DELAY_TT,
          min = 50, max = 500, step = 10,
          getFunc = function() return sv.delay end,
          setFunc = function(v) sv.delay = v end },

        { type = "header", name = L.SET_GOLD },
        { type = "checkbox", name = L.SET_GOLD_ENABLE,
          tooltip = L.SET_GOLD_ENABLE_TT,
          getFunc = function() return sv.goldEnabled end,
          setFunc = function(v) sv.goldEnabled = v end },
        { type = "checkbox", name = L.SET_GOLD_WITHDRAW,
          tooltip = L.SET_GOLD_WITHDRAW_TT,
          disabled = function() return not sv.goldEnabled end,
          getFunc = function() return sv.goldWithdraw end,
          setFunc = function(v) sv.goldWithdraw = v end },
        { type = "editbox", name = L.SET_GOLD_KEEP,
          tooltip = L.SET_GOLD_KEEP_TT,
          textType = TEXT_TYPE_NUMERIC_UNSIGNED_INT,
          disabled = function() return not sv.goldEnabled end,
          getFunc = function() return tostring(sv.goldKeep or 0) end,
          setFunc = function(v) sv.goldKeep = tonumber(v) or 0 end },

        { type = "header", name = L.SET_CAT_HEADER },
        { type = "dropdown", name = L.SET_CATEGORY, scrollable = true,
          choices = catNames, choicesValues = catValues,
          getFunc = function() return ui.category end,
          setFunc = function(v)
              ui.category = v
              if sv.categoryRules[v] ~= nil then ui.catStacks = sv.categoryRules[v] end
          end },
        { type = "checkbox", name = L.SET_UNLIMITED,
          tooltip = L.SET_UNLIMITED_TT,
          getFunc = function() return ui.catStacks == UNLIMITED end,
          setFunc = function(v) ui.catStacks = v and UNLIMITED or 1 end },
        { type = "slider", name = L.SET_STACKS,
          tooltip = L.SET_STACKS_TT,
          min = 0, max = 20, step = 1,
          disabled = function() return ui.catStacks == UNLIMITED end,
          getFunc = function() return math.max(ui.catStacks, 0) end,
          setFunc = function(v) ui.catStacks = v end },
        { type = "button", name = L.SET_SAVE, width = "half",
          func = function() if ui.category then BR.SetCategoryRule(ui.category, ui.catStacks) end end },
        { type = "button", name = L.SET_DELETE, width = "half",
          func = function() if ui.category then BR.RemoveCategoryRule(ui.category) end end },
        { type = "description", title = L.SET_CAT_LIST,
          text = CategoryRulesText(), reference = "MANABank_CategoryList" },

        { type = "header", name = L.SET_ITEM_HEADER },
        { type = "description",
          text = L.SET_ITEM_DESC },
        { type = "dropdown", name = L.SET_ITEM, scrollable = true,
          choices = itemNames, choicesValues = itemValues,
          reference = "MANABank_ItemDropdown",
          getFunc = function() return ui.item or 0 end,
          setFunc = function(v)
              if v ~= 0 and sv.itemRules[v] then
                  ui.item = v
                  ui.itemStacks = sv.itemRules[v].stacks
              else
                  ui.item = nil
              end
          end },
        { type = "checkbox", name = L.SET_UNLIMITED,
          tooltip = L.SET_UNLIMITED_TT,
          disabled = function() return ui.item == nil end,
          getFunc = function() return ui.itemStacks == UNLIMITED end,
          setFunc = function(v) ui.itemStacks = v and UNLIMITED or 1 end },
        { type = "slider", name = L.SET_STACKS,
          tooltip = L.SET_STACKS_TT,
          min = 0, max = 20, step = 1,
          disabled = function() return ui.item == nil or ui.itemStacks == UNLIMITED end,
          getFunc = function() return math.max(ui.itemStacks, 0) end,
          setFunc = function(v) ui.itemStacks = v end },
        { type = "button", name = L.SET_SAVE, width = "half",
          func = function()
              local rule = ui.item and sv.itemRules[ui.item]
              if rule then BR.SetItemRule(ui.item, ui.itemStacks, rule.link) end
          end },
        { type = "button", name = L.SET_DELETE, width = "half",
          func = function() if ui.item then BR.RemoveItemRule(ui.item) end end },
        { type = "description", title = L.SET_ITEM_LIST,
          text = ItemRulesText(), reference = "MANABank_ItemList" },
    }

    LAM:RegisterOptionControls("MANABank_Panel", options)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(createdPanel)
        if createdPanel == panel then BR.RefreshSettings() end
    end)
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

-- Server-dependent account-wide settings (EU and NA have different banks and items).
-- Settings saved by earlier versions (not server dependent) are copied to each server once.
local function LoadSavedVars(svName, version, defaults)
    local displayName = GetDisplayName()
    local raw = _G[svName]
    local old = raw and raw["Default"] and raw["Default"][displayName] and raw["Default"][displayName]["$AccountWide"]
    local saved = ZO_SavedVars:NewAccountWide(svName, version, nil, defaults, GetWorldName())
    -- Copy (not move), so every server you play on gets the old settings once.
    if old and not saved.copiedFromDefault then
        for key, value in pairs(old) do
            if key ~= "version" then
                saved[key] = (type(value) == "table") and ZO_DeepTableCopy(value) or value
            end
        end
        saved.copiedFromDefault = true
    end
    return saved
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= BR.name then return end
    EVENT_MANAGER:UnregisterForEvent(BR.name, EVENT_ADD_ON_LOADED)

    sv = LoadSavedVars("MANABank_SV", SV_VERSION, DEFAULTS)
    sv.itemRules = sv.itemRules or {}
    sv.categoryRules = sv.categoryRules or {}

    EVENT_MANAGER:RegisterForEvent(BR.name, EVENT_OPEN_BANK, OnOpenBank)
    EVENT_MANAGER:RegisterForEvent(BR.name, EVENT_CLOSE_BANK, OnCloseBank)
    EVENT_MANAGER:RegisterForEvent(BR.name .. "_BankSlot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnBankSlotUpdate)
    EVENT_MANAGER:AddFilterForEvent(BR.name .. "_BankSlot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_BANK)

    if LibCustomMenu then
        LibCustomMenu:RegisterContextMenu(AddContextMenu, LibCustomMenu.CATEGORY_LATE)
    end

    CreateSettings()

    SLASH_COMMANDS["/manabank"] = function(arg)
        arg = zo_strlower(zo_strtrim(arg or ""))
        if arg == "run" then
            BR.Run()
        elseif arg:match("^gold") then
            local amount = tonumber(arg:match("^gold%s+(%d+)"))
            if amount then
                sv.goldKeep = amount
                sv.goldEnabled = true
                Say(string.format(L.GOLD_KEEP_SET, ZO_CommaDelimitNumber(amount)))
            else
                sv.goldEnabled = not sv.goldEnabled
                Say(sv.goldEnabled and L.GOLD_ON or L.GOLD_OFF)
            end
        elseif arg == "list" then
            Say(L.LIST_CATEGORIES .. "\n" .. CategoryRulesText())
            Say(L.LIST_ITEMS .. "\n" .. ItemRulesText())
        else
            for _, line in ipairs(L.HELP) do Say(line) end
        end
    end
end

EVENT_MANAGER:RegisterForEvent(BR.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
