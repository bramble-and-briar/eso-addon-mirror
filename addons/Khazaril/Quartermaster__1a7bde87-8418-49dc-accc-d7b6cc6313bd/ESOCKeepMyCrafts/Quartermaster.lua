-- Quartermaster: selling junk, repairing, and keeping gear with the traits you want.
--
-- At a normal merchant (not a fence, not a guild trader) it can repair all your gear and sell the
-- clutter from your backpack, then say in chat what it did. Each kind of clutter is a switch in
-- Settings > Add-Ons > Quartermaster (needs LibHarvensAddonSettings; without it the defaults apply).
--
-- Never sold, whatever the settings: locked, stolen, Crown Store or Crown Crate items, and anything
-- one of your characters crafted. Gear: Ornate pieces (any quality) and white gear are sold; gold
-- gear and other green/blue/purple player gear are left for you to deconstruct. Only the backpack
-- is touched.
--
-- Gear with a trait you keep (per armor / weapons / jewelry / companion gear) is never sold, and set
-- pieces with a kept trait are also hidden from deconstruction, like your crafted items.
--
-- Weapon charge: when an equipped weapon (either bar) drops to the charge you set (default 10%), it
-- is recharged with a filled soul gem from your backpack, ordinary gems before Crown ones.

ESOC_Quartermaster = ESOC_Quartermaster or {}
local QM = ESOC_Quartermaster

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i end
    return nil
end

---------------------------------------------------------------------------
-- Options
---------------------------------------------------------------------------
QM.DEFAULTS = {
    autoSell = true, -- sell when a merchant opens; off = a "Sell trash" button on the Sell screen
    autoRepair = true,
    sellJunk = true, -- items you marked as junk
    sellTrash = true,
    sellTreasure = true,
    sellPotions = true, -- looted potions and poisons
    sellTrophies = true, -- monster trophies (collectible items only worth gold)
    sellRepairKits = true, -- green or lower repair kits
    sellOrnate = true, -- Ornate gear of any quality
    sellWhiteGear = true, -- all white (normal quality) gear
    sellCompanionGreen = true,
    sellCompanionBlue = true, -- unless it has a kept companion trait
    sellCompanionPurple = false,
    autoCharge = true, -- recharge equipped weapons with soul gems
    chargePercent = 10, -- ...when their charge is at or below this
    keepTraits = {}, -- filled from DEFAULT_KEEP below
}

-- Trait lists for the menu: constant name, shown label. Ornate and Intricate are handled separately.
QM.TRAITS = {
    armor = {
        { "ITEM_TRAIT_TYPE_ARMOR_DIVINES", "Divines" }, { "ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE", "Impenetrable" },
        { "ITEM_TRAIT_TYPE_ARMOR_INFUSED", "Infused" }, { "ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS", "Invigorating" },
        { "ITEM_TRAIT_TYPE_ARMOR_NIRNHONED", "Nirnhoned" }, { "ITEM_TRAIT_TYPE_ARMOR_REINFORCED", "Reinforced" },
        { "ITEM_TRAIT_TYPE_ARMOR_STURDY", "Sturdy" }, { "ITEM_TRAIT_TYPE_ARMOR_TRAINING", "Training" },
        { "ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED", "Well-Fitted" },
    },
    weapon = {
        { "ITEM_TRAIT_TYPE_WEAPON_CHARGED", "Charged" }, { "ITEM_TRAIT_TYPE_WEAPON_DECISIVE", "Decisive" },
        { "ITEM_TRAIT_TYPE_WEAPON_DEFENDING", "Defending" }, { "ITEM_TRAIT_TYPE_WEAPON_INFUSED", "Infused" },
        { "ITEM_TRAIT_TYPE_WEAPON_NIRNHONED", "Nirnhoned" }, { "ITEM_TRAIT_TYPE_WEAPON_POWERED", "Powered" },
        { "ITEM_TRAIT_TYPE_WEAPON_PRECISE", "Precise" }, { "ITEM_TRAIT_TYPE_WEAPON_SHARPENED", "Sharpened" },
        { "ITEM_TRAIT_TYPE_WEAPON_TRAINING", "Training" },
    },
    jewelry = {
        { "ITEM_TRAIT_TYPE_JEWELRY_ARCANE", "Arcane" }, { "ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY", "Bloodthirsty" },
        { "ITEM_TRAIT_TYPE_JEWELRY_HARMONY", "Harmony" }, { "ITEM_TRAIT_TYPE_JEWELRY_HEALTHY", "Healthy" },
        { "ITEM_TRAIT_TYPE_JEWELRY_INFUSED", "Infused" }, { "ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE", "Protective" },
        { "ITEM_TRAIT_TYPE_JEWELRY_ROBUST", "Robust" }, { "ITEM_TRAIT_TYPE_JEWELRY_SWIFT", "Swift" },
        { "ITEM_TRAIT_TYPE_JEWELRY_TRIUNE", "Triune" },
    },
    -- Companion traits exist for armor, weapons and jewelry; one switch covers all three.
    companion = {
        { "AGGRESSIVE", "Aggressive" }, { "AUGMENTED", "Augmented" }, { "BOLSTERED", "Bolstered" },
        { "FOCUSED", "Focused" }, { "PROLIFIC", "Prolific" }, { "QUICKENED", "Quickened" },
        { "SHATTERING", "Shattering" }, { "SOOTHING", "Soothing" }, { "VIGOROUS", "Vigorous" },
    },
}
local DEFAULT_KEEP = {
    ITEM_TRAIT_TYPE_ARMOR_DIVINES = true,
    ITEM_TRAIT_TYPE_WEAPON_PRECISE = true, ITEM_TRAIT_TYPE_WEAPON_SHARPENED = true, ITEM_TRAIT_TYPE_WEAPON_INFUSED = true,
}

local opts = {}
local function initOptions(saved)
    saved.qm = saved.qm or {}
    local o = saved.qm
    for k, v in pairs(QM.DEFAULTS) do
        if o[k] == nil and type(v) ~= "table" then o[k] = v end
    end
    if o.keepTraits == nil then
        o.keepTraits = {}
        for k in pairs(DEFAULT_KEEP) do o.keepTraits[k] = true end
    end
    opts = o
    return o
end
QM.InitOptions = initOptions
function QM.Options() return opts end

-- Trait type number -> keep key ("ITEM_TRAIT_TYPE_..." or a companion trait word)
local traitKey
local function buildTraitKeys()
    traitKey = {}
    for _, group in pairs({ QM.TRAITS.armor, QM.TRAITS.weapon, QM.TRAITS.jewelry }) do
        for _, t in ipairs(group) do
            local v = _G[t[1]]
            if v ~= nil then traitKey[v] = t[1] end
        end
    end
    for _, t in ipairs(QM.TRAITS.companion) do
        for _, kind in ipairs({ "ARMOR", "WEAPON", "JEWELRY" }) do
            local v = _G["ITEM_TRAIT_TYPE_" .. kind .. "_" .. t[1]]
            if v ~= nil then traitKey[v] = t[1] end
        end
    end
end

local function isOrnate(trait)
    return trait ~= nil and (trait == ITEM_TRAIT_TYPE_ARMOR_ORNATE or trait == ITEM_TRAIT_TYPE_WEAPON_ORNATE or trait == ITEM_TRAIT_TYPE_JEWELRY_ORNATE)
end
local function isIntricate(trait)
    return trait ~= nil and (trait == ITEM_TRAIT_TYPE_ARMOR_INTRICATE or trait == ITEM_TRAIT_TYPE_WEAPON_INTRICATE or trait == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE)
end

local function hasKeptTrait(bag, slot)
    if not traitKey then buildTraitKeys() end
    local trait = safe(GetItemTrait, bag, slot)
    local k = trait and traitKey[trait]
    return k ~= nil and opts.keepTraits and opts.keepTraits[k] == true
end
QM.HasKeptTrait = hasKeptTrait

local function isGear(itemType)
    return itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON
end

local function isCompanion(bag, slot)
    return GAMEPLAY_ACTOR_CATEGORY_COMPANION ~= nil and safe(GetItemActorCategory, bag, slot) == GAMEPLAY_ACTOR_CATEGORY_COMPANION
end

local function isSetPiece(bag, slot)
    local link = safe(GetItemLink, bag, slot)
    if not link then return false end
    return safe(GetItemLinkSetInfo, link, false) == true
end

-- Set gear (and companion gear) with a kept trait: never sold, hidden from deconstruction.
function QM.IsKept(bag, slot)
    local itemType = safe(GetItemType, bag, slot)
    if not isGear(itemType) then return false end
    if not hasKeptTrait(bag, slot) then return false end
    return isCompanion(bag, slot) or isSetPiece(bag, slot)
end

---------------------------------------------------------------------------
-- What to sell
---------------------------------------------------------------------------
-- Why an item would be sold ("trash", "treasure", ...), or nil to keep it. isMine(bag, slot) says
-- whether one of your characters crafted it.
function QM.SellReason(bag, slot, isMine)
    local o = opts
    if (safe(GetItemId, bag, slot) or 0) == 0 then return nil end
    if safe(IsItemPlayerLocked, bag, slot) then return nil end
    if safe(IsItemStolen, bag, slot) then return nil end
    if safe(IsItemFromCrownStore, bag, slot) or safe(IsItemFromCrownCrate, bag, slot) then return nil end
    if safe(IsItemJunk, bag, slot) then return nil end -- the game's Sell All Junk handles these
    if isMine and isMine(bag, slot) then return nil end
    if ITEM_SELL_INFORMATION_CANNOT_SELL ~= nil and safe(GetItemSellInformation, bag, slot) == ITEM_SELL_INFORMATION_CANNOT_SELL then return nil end
    if (safe(GetItemSellValueWithBonuses, bag, slot) or 1) <= 0 then return nil end

    local itemType, specialized = safe(GetItemType, bag, slot)
    local quality = safe(GetItemDisplayQuality, bag, slot)
    if itemType ~= nil and itemType == ITEMTYPE_COLLECTIBLE and specialized ~= nil
        and specialized == SPECIALIZED_ITEMTYPE_COLLECTIBLE_MONSTER_TROPHY then
        return o.sellTrophies and "monster trophies" or nil
    end
    if itemType == ITEMTYPE_TRASH then return o.sellTrash and "trash" or nil end
    if itemType == ITEMTYPE_TREASURE then return o.sellTreasure and "treasure" or nil end
    if itemType == ITEMTYPE_POTION or itemType == ITEMTYPE_POISON then return o.sellPotions and "potions" or nil end
    if itemType == ITEMTYPE_TOOL then
        -- repair kits; green or lower only
        if o.sellRepairKits and quality ~= nil and ITEM_DISPLAY_QUALITY_MAGIC ~= nil and quality <= ITEM_DISPLAY_QUALITY_MAGIC then return "repair kits" end
        return nil
    end
    if not isGear(itemType) then return nil end

    -- Gear: Ornate of any quality, and any white gear, can go
    local trait = safe(GetItemTrait, bag, slot)
    if isOrnate(trait) and o.sellOrnate then return "ornate gear" end
    if quality ~= nil and quality == ITEM_DISPLAY_QUALITY_NORMAL then return o.sellWhiteGear and "white gear" or nil end
    -- Otherwise only green, blue or purple, and not with a kept trait
    local green, blue, purple = ITEM_DISPLAY_QUALITY_MAGIC, ITEM_DISPLAY_QUALITY_ARCANE, ITEM_DISPLAY_QUALITY_ARTIFACT
    if quality ~= green and quality ~= blue and quality ~= purple then return nil end
    if hasKeptTrait(bag, slot) then return nil end
    if isIntricate(trait) then return nil end
    if isCompanion(bag, slot) then
        if quality == green and o.sellCompanionGreen then return "companion gear" end
        if quality == blue and o.sellCompanionBlue then return "companion gear" end
        if quality == purple and o.sellCompanionPurple then return "companion gear" end
        return nil
    end
    return nil -- other player gear: left for you to deconstruct
end

-- Everything in the backpack that would be sold, as { bag, slot, count, value, reason }.
function QM.SellList(isMine)
    local list = {}
    local bag = BAG_BACKPACK
    for slot = 0, (safe(GetBagSize, bag) or 0) - 1 do
        local reason = QM.SellReason(bag, slot, isMine)
        if reason then
            local _, count = safe(GetItemInfo, bag, slot)
            count = count or 1
            local value = (safe(GetItemSellValueWithBonuses, bag, slot) or 0) * count
            list[#list + 1] = { bag = bag, slot = slot, count = count, value = value, reason = reason }
        end
    end
    return list
end

-- Junk you marked yourself, counted for the summary (sold by the game's own Sell All Junk).
local function junkCount()
    local n, value = 0, 0
    local bag = BAG_BACKPACK
    for slot = 0, (safe(GetBagSize, bag) or 0) - 1 do
        if safe(IsItemJunk, bag, slot) and not safe(IsItemStolen, bag, slot) then
            local _, count = safe(GetItemInfo, bag, slot)
            n = n + 1
            value = value + (safe(GetItemSellValueWithBonuses, bag, slot) or 0) * (count or 1)
        end
    end
    return n, value
end

---------------------------------------------------------------------------
-- At the merchant
---------------------------------------------------------------------------
local atStore, atFence = false, false
local watchCharge -- defined in the Weapon charge section below
local selling = nil -- { list, index, gold, items }
local SELL_GAP_MS = 150 -- one sale at a time, so the server doesn't refuse a burst

local function say(text)
    pcall(d, "[Quartermaster] " .. text)
end
QM.say = say

local function money(n)
    local ok, s = pcall(ZO_CommaDelimitNumber, n)
    return ok and s or tostring(n)
end

local function finish(report)
    local parts = {}
    if report.repaired then parts[#parts + 1] = "Repaired for " .. money(report.repaired) .. " gold." end
    if report.items > 0 then
        parts[#parts + 1] = string.format("Sold %d item%s for %s gold.", report.items, report.items == 1 and "" or "s", money(report.gold))
    end
    if report.stopped then parts[#parts + 1] = "Stopped when the merchant closed." end
    if #parts > 0 then say(table.concat(parts, " ")) end
    selling = nil
    if QM.onChanged then pcall(QM.onChanged) end
end

local function sellNext()
    local s = selling
    if not s then return end
    if not atStore then s.report.stopped = true; finish(s.report); return end
    local item = s.list[s.index]
    if not item then finish(s.report); return end
    s.index = s.index + 1
    -- the slot may have changed since the list was made
    if QM.SellReason(item.bag, item.slot, s.isMine) then
        safe(SellInventoryItem, item.bag, item.slot, item.count)
        s.report.items = s.report.items + 1
        s.report.gold = s.report.gold + item.value
    end
    if zo_callLater then zo_callLater(sellNext, SELL_GAP_MS) else sellNext() end
end

-- Sell everything on the list (and marked junk). Called automatically, or by the Sell trash button.
function QM.SellNow(isMine, report)
    if selling or not atStore or atFence then return false end
    report = report or { items = 0, gold = 0 }
    if opts.sellJunk then
        local n, value = junkCount()
        if n > 0 then
            safe(SellAllJunk)
            report.items, report.gold = report.items + n, report.gold + value
        end
    end
    selling = { list = QM.SellList(isMine), index = 1, report = report, isMine = isMine }
    sellNext()
    return true
end

function QM.Repair()
    if not opts.autoRepair or not safe(CanStoreRepair) then return nil end
    local cost = safe(GetRepairAllCost) or 0
    if cost <= 0 then return nil end
    -- GetCarriedCurrencyAmount is PC-only (a compatibility alias); consoles need GetCurrencyAmount
    local gold = safe(GetCurrencyAmount, CURT_MONEY, CURRENCY_LOCATION_CHARACTER)
        or safe(GetCarriedCurrencyAmount, CURT_MONEY)
    if gold ~= nil and gold < cost then
        say("Not enough gold to repair (" .. money(cost) .. " needed).")
        return nil
    end
    safe(RepairAll)
    return cost
end

-- Items the Sell trash button would sell right now (including marked junk).
function QM.PendingCount(isMine)
    local n = #QM.SellList(isMine)
    if opts.sellJunk then n = n + junkCount() end
    return n
end

function QM.IsAtStore() return atStore and not atFence end
function QM.IsSelling() return selling ~= nil end

function QM.Init(saved, isMine)
    initOptions(saved)
    if not EVENT_MANAGER then return end
    local name = "ESOC_Quartermaster"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_OPEN_FENCE, function() atFence = true end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_OPEN_STORE, function()
        atStore = true
        -- give a fence's own event a moment to arrive; fences and guild traders are left alone
        local function go()
            if not atStore or atFence then return end
            local report = { items = 0, gold = 0 }
            report.repaired = QM.Repair()
            if opts.autoSell then
                QM.SellNow(isMine, report)
            elseif report.repaired then
                finish(report)
            end
            if QM.onChanged then pcall(QM.onChanged) end
        end
        if zo_callLater then zo_callLater(go, 300) else go() end
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_CLOSE_STORE, function()
        atStore, atFence = false, false
    end)
    watchCharge()
end

---------------------------------------------------------------------------
-- Weapon charge
---------------------------------------------------------------------------
local WEAPON_SLOTS = { "EQUIP_SLOT_MAIN_HAND", "EQUIP_SLOT_OFF_HAND", "EQUIP_SLOT_BACKUP_MAIN", "EQUIP_SLOT_BACKUP_OFF" }
local lastCharge = {} -- slot -> game time (ms) of the last recharge, so one drop doesn't use several gems
local warnedNoGems = false

-- A filled soul gem in the backpack: ordinary ones first, Crown soul gems only if there's nothing else.
local function findSoulGem()
    local crown
    local bag = BAG_BACKPACK
    for slot = 0, (safe(GetBagSize, bag) or 0) - 1 do
        if SOUL_GEM_TYPE_FILLED ~= nil and safe(IsItemSoulGem, SOUL_GEM_TYPE_FILLED, bag, slot) then
            if safe(IsItemFromCrownStore, bag, slot) then
                crown = crown or slot
            else
                return slot
            end
        end
    end
    return crown
end

local function soulGemCount()
    local n = 0
    local bag = BAG_BACKPACK
    for slot = 0, (safe(GetBagSize, bag) or 0) - 1 do
        if SOUL_GEM_TYPE_FILLED ~= nil and safe(IsItemSoulGem, SOUL_GEM_TYPE_FILLED, bag, slot) then
            local _, count = safe(GetItemInfo, bag, slot)
            n = n + (count or 1)
        end
    end
    return n
end

-- Charge left on a worn weapon as a percentage, or nil if it doesn't take charge.
function QM.ChargePercent(slot)
    if not safe(IsItemChargeable, BAG_WORN, slot) then return nil end
    local charges, maxCharges = safe(GetChargeInfoForItem, BAG_WORN, slot)
    if not maxCharges or maxCharges <= 0 then return nil end
    return (charges or 0) * 100 / maxCharges
end

-- Recharge every equipped weapon at or below the chosen charge. Returns how many were recharged.
function QM.CheckCharge()
    if not opts.autoCharge then return 0 end
    local now = safe(GetGameTimeMilliseconds) or 0
    local done = 0
    for _, name in ipairs(WEAPON_SLOTS) do
        local slot = _G[name]
        local pct = slot ~= nil and QM.ChargePercent(slot)
        if pct and pct <= (opts.chargePercent or 10) and (not lastCharge[slot] or now - lastCharge[slot] > 3000) then
            local gem = findSoulGem()
            if not gem then
                if not warnedNoGems then
                    say("A weapon is low on charge but you have no filled soul gems.")
                    warnedNoGems = true
                end
                return done
            end
            local gemsLeft = math.max(0, soulGemCount() - 1)
            safe(ChargeItemWithSoulGem, BAG_WORN, slot, BAG_BACKPACK, gem)
            lastCharge[slot] = now
            done = done + 1
            local weapon = safe(GetItemName, BAG_WORN, slot) or "weapon"
            local ok, nice = pcall(zo_strformat, "<<1>>", weapon)
            say(string.format("Recharged %s (%d%% left). Soul gems left: %d.", ok and nice or weapon, math.floor(pct + 0.5), gemsLeft))
        end
    end
    if soulGemCount() > 0 then warnedNoGems = false end
    return done
end

watchCharge = function()
    if not EVENT_MANAGER or not EVENT_INVENTORY_SINGLE_SLOT_UPDATE then return end
    local name = "ESOC_QuartermasterCharge"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bagId, _, _, _, reason)
        if bagId ~= BAG_WORN then return end
        if INVENTORY_UPDATE_REASON_ITEM_CHARGE ~= nil and reason ~= INVENTORY_UPDATE_REASON_ITEM_CHARGE then return end
        pcall(QM.CheckCharge)
    end)
    if EVENT_MANAGER.AddFilterForEvent and REGISTER_FILTER_BAG_ID then
        pcall(EVENT_MANAGER.AddFilterForEvent, EVENT_MANAGER, name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    end
    -- also after swapping bars, logging in and leaving combat
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function() pcall(QM.CheckCharge) end) end
    if EVENT_PLAYER_ACTIVATED then EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function() pcall(QM.CheckCharge) end) end
    if EVENT_PLAYER_COMBAT_STATE then EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat) if not inCombat then pcall(QM.CheckCharge) end end) end
end

---------------------------------------------------------------------------
-- Settings page: Settings > Add-Ons > Quartermaster (needs LibHarvensAddonSettings)
---------------------------------------------------------------------------
local settingsMade = false
function QM.CreateSettings(saved, extra)
    if settingsMade then return end
    local LHAS = LibHarvensAddonSettings
    if not LHAS or not LHAS.AddAddon then return end
    settingsMade = true
    local o = opts
    local panel = LHAS:AddAddon("Quartermaster", { allowDefaults = true, allowRefresh = true })
    QM.settingsPanel = panel
    local function check(label, tooltip, name)
        return {
            type = LHAS.ST_CHECKBOX, label = label, tooltip = tooltip, default = QM.DEFAULTS[name],
            getFunction = function() return o[name] end,
            setFunction = function(v) o[name] = v; if QM.onChanged then pcall(QM.onChanged) end end,
        }
    end
    local function keep(constName, label)
        return {
            type = LHAS.ST_CHECKBOX, label = label, default = DEFAULT_KEEP[constName] == true,
            getFunction = function() return o.keepTraits[constName] == true end,
            setFunction = function(v) o.keepTraits[constName] = v or nil; if QM.onChanged then pcall(QM.onChanged) end end,
        }
    end
    local list = {
        { type = LHAS.ST_SECTION, label = "At a merchant" },
        check("Sell automatically", "Sell the items ticked below as soon as you open a merchant (not fences or guild traders). Off: a Sell trash button (left stick) on the Sell screen instead.", "autoSell"),
        check("Repair automatically", "Repair all your gear when you open a merchant, if you have the gold.", "autoRepair"),
        { type = LHAS.ST_SECTION, label = "Weapon charge" },
        check("Recharge weapons automatically", "Use a filled soul gem from your backpack when an equipped weapon (either bar) runs low. Ordinary soul gems are used before Crown ones.", "autoCharge"),
        {
            type = LHAS.ST_SLIDER, label = "Recharge at or below (% charge left)",
            tooltip = "For example 10: recharge when 10% of the charge is left.",
            min = 1, max = 50, step = 1, format = "%d", unit = "%", default = QM.DEFAULTS.chargePercent,
            getFunction = function() return o.chargePercent end,
            setFunction = function(v) o.chargePercent = math.floor(tonumber(v) or QM.DEFAULTS.chargePercent); pcall(QM.CheckCharge) end,
            disable = function() return not o.autoCharge end,
        },
        { type = LHAS.ST_SECTION, label = "What to sell (backpack only)" },
        check("Items marked as junk", "Everything you marked as junk.", "sellJunk"),
        check("Trash", "Items in the Trash category.", "sellTrash"),
        check("Treasure", "Treasure that isn't stolen (stolen goods only sell at a fence).", "sellTreasure"),
        check("Looted potions and poisons", "Never ones crafted by your characters, never Crown potions.", "sellPotions"),
        check("Monster trophies", "Trophies dropped by monsters, worth only their gold.", "sellTrophies"),
        check("Repair kits (green or lower)", "Higher-quality, group and Crown repair kits are kept.", "sellRepairKits"),
        check("Ornate gear (any quality)", "Ornate pieces are worth more sold than deconstructed.", "sellOrnate"),
        check("White gear", "All white (normal quality) armor, weapons and jewelry, including companion gear.", "sellWhiteGear"),
        check("Green companion gear", "Unless it has a companion trait you keep.", "sellCompanionGreen"),
        check("Blue companion gear", "Unless it has a companion trait you keep.", "sellCompanionBlue"),
        check("Purple companion gear", "Unless it has a companion trait you keep.", "sellCompanionPurple"),
        { type = LHAS.ST_LABEL, label = "Never sold: locked, stolen and Crown items, and anything your characters crafted. Gold gear and other green, blue and purple player gear (including Intricate) are left for you to deconstruct, unless Ornate." },
        { type = LHAS.ST_SECTION, label = "Keep armor with these traits" },
    }
    for _, t in ipairs(QM.TRAITS.armor) do list[#list + 1] = keep(t[1], t[2]) end
    list[#list + 1] = { type = LHAS.ST_SECTION, label = "Keep weapons with these traits" }
    for _, t in ipairs(QM.TRAITS.weapon) do list[#list + 1] = keep(t[1], t[2]) end
    list[#list + 1] = { type = LHAS.ST_SECTION, label = "Keep jewelry with these traits" }
    for _, t in ipairs(QM.TRAITS.jewelry) do list[#list + 1] = keep(t[1], t[2]) end
    list[#list + 1] = { type = LHAS.ST_SECTION, label = "Keep companion gear with these traits" }
    for _, t in ipairs(QM.TRAITS.companion) do list[#list + 1] = keep(t[1], t[2]) end
    list[#list + 1] = { type = LHAS.ST_LABEL, label = "Set pieces and companion gear with a kept trait are never sold, and set pieces are hidden from deconstruction like your crafted items." }
    for _, e in ipairs(extra or {}) do list[#list + 1] = e end
    panel:AddSettings(list)
end
