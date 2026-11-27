-- MANA Recycling by Beardborn
-- Deconstructs gear and glyphs and refines raw materials automatically at crafting stations.
-- UI texts are English; translations live in lang/<language>.lua (see MANARecycling.T).
-- AI disclosure: written with the help of an AI assistant (Claude by Anthropic) from the author's design;
-- tested in game and maintained by the author.

-- The single global MANARecycling is shared with the language files in lang/.
MANARecycling = MANARecycling or {}
local MR = MANARecycling
local T = MR.T

MR.name = "MANARecycling"
MR.displayName = "MANA Recycling"
MR.version = "1.0.1"
MR.author = "Beardborn"

local SV_VERSION = 1
local DEFAULTS = {
    enabled = true,
    maxQuality = 2,          -- deconstruct this quality and below (2 = green)
    skipCrafted = true,      -- keep player-crafted items
    skipUnresearched = true, -- keep items with unresearched traits
    skipSets = true,         -- keep set items

    refine = true,           -- refine raw materials (ore -> ingots etc.)
    refineFromBank = true,   -- also refine raw materials stored in the bank

    glyphs = true,           -- deconstruct glyphs at the enchanting station
    glyphMaxQuality = 2,     -- glyphs of this quality and below
    glyphSkipCrafted = true, -- keep player-crafted glyphs
    chat = true,
    respectFCOIS = true,     -- honour FCO ItemSaver protection
}

local START_DELAY_MS = 800
local MODE_SWITCH_DELAY_MS = 500  -- let the panel switch settle     -- delay after opening a station
local NEXT_BATCH_DELAY_MS = 800   -- let the inventory update after a batch
local STALL_RETRY_MS = 1000       -- wait if the inventory has not updated yet
local MAX_STALLS = 3
local CRAFT_TIMEOUT_MS = 6000  -- how long to wait for the server
local BATCH_SIZE = 50          -- items per request
local MIN_FREE_SLOTS = 3       -- free slots required for materials

local QUALITY_CHOICES = {
    { value = 1, name = T"Normal (white)" },
    { value = 2, name = T"Fine (green)" },
    { value = 3, name = T"Superior (blue)" },
    { value = 4, name = T"Epic (purple)" },
    { value = 5, name = T"Legendary (gold)" },
}

local SMITHING_TYPES = {}
for _, constName in ipairs({ "CRAFTING_TYPE_BLACKSMITHING", "CRAFTING_TYPE_CLOTHIER",
                             "CRAFTING_TYPE_WOODWORKING", "CRAFTING_TYPE_JEWELRYCRAFTING" }) do
    if _G[constName] then SMITHING_TYPES[#SMITHING_TYPES + 1] = _G[constName] end
end

local sv
local stationSkill = nil
local running = false
local pending, pendingToken = false, 0
local lastBatch = { gear = 0, raw = 0 }
local lastEligible, lastPhase = nil, nil
local stalls = 0
local debugMode = false

local function Debug(text)
    if debugMode then d("|c888888[MANA Recycling debug]|r " .. text) end
end
local totalGear, totalRaw = 0, 0

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local PREFIX = "|cB088FF[MANA Recycling]|r "

local function Say(text) d(PREFIX .. text) end
local function Msg(text) if sv and sv.chat then Say(text) end end

local function Call(fnName, ...)
    if IsProtectedFunction(fnName) then
        return CallSecureProtected(fnName, ...)
    end
    return _G[fnName](...)
end

local function IsSmithingStation(craftSkill)
    for _, t in ipairs(SMITHING_TYPES) do
        if t == craftSkill then return true end
    end
    return false
end

local function IsEnchantingStation(craftSkill)
    return CRAFTING_TYPE_ENCHANTING ~= nil and craftSkill == CRAFTING_TYPE_ENCHANTING
end

-- A station where the add-on has something to do.
local function IsSupportedStation(craftSkill)
    if IsSmithingStation(craftSkill) then return true end
    return IsEnchantingStation(craftSkill) and sv.glyphs
end

local GLYPH_TYPES = {}
for _, constName in ipairs({ "ITEMTYPE_GLYPH_ARMOR", "ITEMTYPE_GLYPH_WEAPON", "ITEMTYPE_GLYPH_JEWELRY" }) do
    if _G[constName] then GLYPH_TYPES[_G[constName]] = true end
end

local function GetQuality(bagId, slotIndex)
    if GetItemFunctionalQuality then return GetItemFunctionalQuality(bagId, slotIndex) end
    return GetItemQuality(bagId, slotIndex)
end

-- Quality colors as in the game; fallback values if the function is unavailable.
local QUALITY_FALLBACK_HEX = { [1] = "FFFFFF", [2] = "2DC50E", [3] = "3A92FF", [4] = "A02EF7", [5] = "EECA2A" }

local function ColorizeQuality(value, text)
    if GetItemQualityColor then
        local ok, color = pcall(GetItemQualityColor, value)
        if ok and color and color.Colorize then return color:Colorize(text) end
    end
    return "|c" .. (QUALITY_FALLBACK_HEX[value] or "FFFFFF") .. text .. "|r"
end

local function QualityName(value)
    for _, q in ipairs(QUALITY_CHOICES) do
        if q.value == value then return ColorizeQuality(value, q.name) end
    end
    return tostring(value)
end

---------------------------------------------------------------------------
-- Item checks
---------------------------------------------------------------------------

local function CanExtractAt(bagId, slotIndex, craftSkill)
    if craftSkill then
        return CanItemBeSmithingExtractedOrRefined(bagId, slotIndex, craftSkill)
    end
    for _, t in ipairs(SMITHING_TYPES) do  -- no station: any station will do
        if CanItemBeSmithingExtractedOrRefined(bagId, slotIndex, t) then return true end
    end
    return false
end

-- Returns true if the item can be deconstructed; otherwise false and a reason.
-- Common restrictions for any item.
-- FCO ItemSaver: use its dedicated API for the exact action (not the generic FCOIS.IsLocked,
-- which depends on the currently open panel). If a function is missing, fall back to
-- "marked with any icon" so that items are rather kept than destroyed.
local FCOIS_API = {
    decon = { "IsDeconstructionLocked" },
    extract = { "IsEnchantingExtractionLocked" },
    refine = { "IsRefinementLocked", "IsDeconstructionLocked" },
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

-- Common restrictions for any item; action = "decon" | "extract" | "refine".
local function GetProtectionReason(bagId, slotIndex, action)
    if IsItemPlayerLocked(bagId, slotIndex) then return T"locked" end
    if IsFCOISProtected(bagId, slotIndex, action) then return T"locked (FCOIS)" end
    if IsItemStolen(bagId, slotIndex) then return T"stolen" end
    return nil
end

local function CheckGlyph(bagId, slotIndex)
    if not sv.glyphs then return false end
    if not GLYPH_TYPES[GetItemType(bagId, slotIndex)] then return false end
    local protected = GetProtectionReason(bagId, slotIndex, "extract")
    if protected then return false, protected end
    if GetQuality(bagId, slotIndex) > sv.glyphMaxQuality then return false, T"glyph quality above limit" end
    if sv.glyphSkipCrafted and IsItemLinkCrafted(GetItemLink(bagId, slotIndex)) then
        return false, T"glyph crafted by a player"
    end
    return true
end

local function CheckGear(bagId, slotIndex, craftSkill)
    local itemType = GetItemType(bagId, slotIndex)
    if itemType ~= ITEMTYPE_ARMOR and itemType ~= ITEMTYPE_WEAPON then return false end
    if not CanExtractAt(bagId, slotIndex, craftSkill) then return false end

    local protected = GetProtectionReason(bagId, slotIndex, "decon")
    if protected then return false, protected end
    if GetItemActorCategory and GAMEPLAY_ACTOR_CATEGORY_PLAYER
        and GetItemActorCategory(bagId, slotIndex) ~= GAMEPLAY_ACTOR_CATEGORY_PLAYER then
        return false, T"companion item"
    end

    if GetQuality(bagId, slotIndex) > sv.maxQuality then return false, T"quality above limit" end

    local link = GetItemLink(bagId, slotIndex)
    if sv.skipCrafted and IsItemLinkCrafted(link) then return false, T"crafted by a player" end
    if sv.skipUnresearched
        and GetItemTraitInformation(bagId, slotIndex) == ITEM_TRAIT_INFORMATION_CAN_BE_RESEARCHED then
        return false, T"trait not researched"
    end
    if sv.skipSets then
        local hasSet = GetItemLinkSetInfo(link, false)
        if hasSet then return false, T"set item" end
    end
    return true
end

-- Returns true if the item can be deconstructed at this station; otherwise false and a reason.
-- craftSkill == nil: check without a station (preview) — gear and glyphs.
function MR.CheckItem(bagId, slotIndex, craftSkill)
    if craftSkill == nil then
        if GLYPH_TYPES[GetItemType(bagId, slotIndex)] then return CheckGlyph(bagId, slotIndex) end
        return CheckGear(bagId, slotIndex, nil)
    end
    if IsEnchantingStation(craftSkill) then return CheckGlyph(bagId, slotIndex) end
    return CheckGear(bagId, slotIndex, craftSkill)
end

local RAW_TYPES = {}
for _, constName in ipairs({ "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL", "ITEMTYPE_CLOTHIER_RAW_MATERIAL",
                             "ITEMTYPE_WOODWORKING_RAW_MATERIAL", "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL" }) do
    if _G[constName] then RAW_TYPES[_G[constName]] = true end
end

local function RefineStackSize()
    if GetRequiredSmithingRefinementStackSize then
        local ok, size = pcall(GetRequiredSmithingRefinementStackSize)
        if ok and size and size > 0 then return size end
    end
    return 10
end

-- Gear/glyphs to deconstruct: { { slot =, qty = }, ... }
local function CollectEligible(craftSkill)
    local list = {}
    for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
        if MR.CheckItem(BAG_BACKPACK, slot, craftSkill) then
            list[#list + 1] = { bag = BAG_BACKPACK, slot = slot, qty = GetSlotStackSize(BAG_BACKPACK, slot) }
        end
    end
    return list
end

-- Raw materials to refine: full tens only; junk and locked are skipped.
local function CollectRaw(craftSkill)
    local list = {}
    if not sv.refine or not IsSmithingStation(craftSkill) then return list end
    local stackSize = RefineStackSize()
    local bags = { BAG_BACKPACK }
    if sv.refineFromBank then bags[#bags + 1] = BAG_BANK end  -- stations can use raw materials from the bank
    for _, bag in ipairs(bags) do
        for slot in ZO_IterateBagSlots(bag) do
            if RAW_TYPES[GetItemType(bag, slot)]
                and not IsItemJunk(bag, slot)
                and not GetProtectionReason(bag, slot, "refine")
                and CanItemBeSmithingExtractedOrRefined(bag, slot, craftSkill) then
                local count = GetSlotStackSize(bag, slot)
                local qty = count - (count % stackSize)
                if qty > 0 then list[#list + 1] = { bag = bag, slot = slot, qty = qty } end
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Deconstruction
---------------------------------------------------------------------------

local function Finish(reason)
    running = false
    pending = false
    if reason then Say(reason) end
    local parts = {}
    if totalGear > 0 then parts[#parts + 1] = T"items deconstructed: " .. totalGear end
    if totalRaw > 0 then parts[#parts + 1] = T"raw materials refined: " .. totalRaw end
    if #parts > 0 then Msg(T"Done — " .. table.concat(parts, ", ") .. ".") end
end

local SendBatch

local function OnBatchDone(token)
    if not running or not pending or token ~= pendingToken then return end
    pending = false
    totalGear = totalGear + lastBatch.gear
    totalRaw = totalRaw + lastBatch.raw
    zo_callLater(SendBatch, NEXT_BATCH_DELAY_MS)
end

local function OnCraftTimeout(token)
    if not running or not pending or token ~= pendingToken then return end
    Finish(T"|cFF6666The server did not confirm the deconstruction — stopped.|r")
end

-- Switch the station to the panel that matches the action (deconstruction, refinement or
-- glyph extraction) before doing anything, as the game and other add-ons (e.g. FCO ItemSaver)
-- apply their protection to the currently open panel. Returns true if the panel was switched.
local function EnsureCraftingMode(phase)
    if IsEnchantingStation(stationSkill) then
        if ENCHANTING and ENCHANTING.GetEnchantingMode and ENCHANTING:GetEnchantingMode() ~= ENCHANTING_MODE_EXTRACTION then
            if ENCHANTING.modeBar then
                ZO_MenuBar_SelectDescriptor(ENCHANTING.modeBar, ENCHANTING_MODE_EXTRACTION)
            else
                ENCHANTING:SetEnchantingMode(ENCHANTING_MODE_EXTRACTION)
            end
            return true
        end
    elseif SMITHING then
        local wanted = (phase == "raw") and SMITHING_MODE_REFINEMENT or SMITHING_MODE_DECONSTRUCTION
        if SMITHING.mode ~= wanted then
            if SMITHING.modeBar then
                ZO_MenuBar_SelectDescriptor(SMITHING.modeBar, wanted)
            else
                SMITHING:SetMode(wanted)
            end
            return true
        end
    end
    return false
end

SendBatch = function()
    if not running then return end
    if not stationSkill then return Finish() end

    -- If the station is busy (e.g. Lazy Writ Crafter is working), wait.
    if ZO_CraftingUtils_IsPerformingCraftProcess and ZO_CraftingUtils_IsPerformingCraftProcess() then
        zo_callLater(SendBatch, 500)
        return
    end

    -- Deconstruct gear/glyphs first, then refine raw materials.
    local phase, list = "gear", CollectEligible(stationSkill)
    if #list == 0 then phase, list = "raw", CollectRaw(stationSkill) end
    if #list == 0 then return Finish() end

    -- Open the matching panel first, then look at the inventory again.
    if EnsureCraftingMode(phase) then
        Debug("panel switched for phase " .. phase)
        zo_callLater(SendBatch, MODE_SWITCH_DELAY_MS)
        return
    end

    -- Loop guard: the previous request changed nothing.
    local units = 0
    for _, e in ipairs(list) do units = units + e.qty end
    Debug(string.format(T"phase %s: entries %d, units %d (was %s)", phase, #list, units, tostring(lastEligible)))
    if lastPhase == phase and lastEligible and units >= lastEligible then
        -- The inventory may not have updated after the last request yet — wait.
        stalls = stalls + 1
        if stalls >= MAX_STALLS then
            return Finish(T"|cFF6666Items are not being processed — stopped.|r")
        end
        Debug(T"inventory unchanged, waiting (" .. stalls .. ")")
        zo_callLater(SendBatch, STALL_RETRY_MS)
        return
    end
    stalls = 0
    lastPhase, lastEligible = phase, units

    if GetNumBagFreeSlots(BAG_BACKPACK) < MIN_FREE_SLOTS then
        return Finish(T"|cFF6666Not enough free inventory slots for materials — free up some space.|r")
    end

    lastBatch = { gear = 0, raw = 0 }
    if PrepareDeconstructMessage and AddItemToDeconstructMessage and SendDeconstructMessage then
        Call("PrepareDeconstructMessage")
        local count = 0
        for _, e in ipairs(list) do
            if count >= BATCH_SIZE then break end
            Call("AddItemToDeconstructMessage", e.bag, e.slot, e.qty)
            Debug(T"  sent: " .. GetItemLink(e.bag, e.slot) .. " x" .. e.qty .. (e.bag == BAG_BANK and T" (from bank)" or ""))
            count = count + 1
            if phase == "raw" then lastBatch.raw = lastBatch.raw + e.qty else lastBatch.gear = lastBatch.gear + 1 end
        end
        Call("SendDeconstructMessage")
    else
        local e = list[1]
        if IsEnchantingStation(stationSkill) then
            Call("ExtractEnchantingItem", e.bag, e.slot)
        else
            Call("ExtractOrRefineSmithingItem", e.bag, e.slot)
        end
        if phase == "raw" then lastBatch.raw = RefineStackSize() else lastBatch.gear = 1 end
    end

    pendingToken = pendingToken + 1
    pending = true
    local token = pendingToken
    zo_callLater(function() OnCraftTimeout(token) end, CRAFT_TIMEOUT_MS)
end

function MR.Run()
    if running then return end
    if IsInGamepadPreferredMode() then
        Say(T"Gamepad mode is not supported yet — nothing was deconstructed.")
        return
    end
    if not stationSkill or not IsSupportedStation(stationSkill) then
        Say(T"Open a blacksmithing, clothing, woodworking, jewelry or enchanting station.")
        return
    end
    running = true
    totalGear, totalRaw = 0, 0
    lastEligible, lastPhase = nil, nil
    stalls = 0
    SendBatch()
end

local function OnStationInteract(_, craftSkill)
    stationSkill = craftSkill
    if not sv.enabled or not IsSupportedStation(craftSkill) then return end
    zo_callLater(function()
        if stationSkill == craftSkill then MR.Run() end
    end, START_DELAY_MS)
end

local function OnStationEnd()
    stationSkill = nil
    if running then Finish(T"Station closed — deconstruction stopped.") end
end

local function OnCraftCompleted()
    Debug(T"server: deconstruction complete")
    if pending then OnBatchDone(pendingToken) end
end

---------------------------------------------------------------------------
-- Preview
---------------------------------------------------------------------------

function MR.Preview()
    local willDo, skipped = {}, {}
    for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
        local ok, reason = MR.CheckItem(BAG_BACKPACK, slot, stationSkill)
        if ok then
            willDo[#willDo + 1] = GetItemLink(BAG_BACKPACK, slot)
        elseif reason then
            skipped[reason] = (skipped[reason] or 0) + 1
        end
    end
    Say(T"Will be deconstructed: " .. #willDo)
    for _, link in ipairs(willDo) do d("  " .. link) end
    local parts = {}
    for reason, n in pairs(skipped) do parts[#parts + 1] = reason .. ": " .. n end
    if #parts > 0 then Say(T"Skipped — " .. table.concat(parts, ", ")) end
    if stationSkill and IsSmithingStation(stationSkill) then
        local raw = CollectRaw(stationSkill)
        Say(T"Raw materials to refine: " .. #raw .. (sv.refine and "" or T" (refining disabled)"))
        for _, e in ipairs(raw) do
            d("  " .. GetItemLink(e.bag, e.slot) .. " x" .. e.qty .. (e.bag == BAG_BANK and T" (from bank)" or ""))
        end
    end
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

local function CreateSettings()
    local LAM = LibAddonMenu2

    local qNames, qValues = {}, {}
    for _, q in ipairs(QUALITY_CHOICES) do
        qNames[#qNames + 1] = ColorizeQuality(q.value, q.name)
        qValues[#qValues + 1] = q.value
    end

    LAM:RegisterAddonPanel("MANARecycling_Panel", {
        type = "panel",
        name = MR.displayName,
        displayName = MR.displayName,
        author = MR.author,
        version = MR.version,
        slashCommand = "/manarecyclingsettings",
        registerForRefresh = true,
    })

    LAM:RegisterOptionControls("MANARecycling_Panel", {
        { type = "description",
          text = T"When you open a blacksmithing, clothing, woodworking or jewelry station, the add-on deconstructs matching gear from your inventory; at an enchanting station it deconstructs glyphs. Locked, stolen and companion items are never touched. Mythic items are never deconstructed." },
        { type = "checkbox", name = T"Deconstruct automatically",
          tooltip = T"If disabled, deconstruction only runs via /manarecycling run.",
          getFunc = function() return sv.enabled end,
          setFunc = function(v) sv.enabled = v end },
        { type = "header", name = T"Gear" },
        { type = "dropdown", name = T"Deconstruct quality up to",
          tooltip = T"The selected quality and everything below it.",
          choices = qNames, choicesValues = qValues,
          getFunc = function() return sv.maxQuality end,
          setFunc = function(v) sv.maxQuality = v end },
        { type = "checkbox", name = T"Keep crafted items",
          tooltip = T"Items crafted by players, e.g. for daily writs.",
          getFunc = function() return sv.skipCrafted end,
          setFunc = function(v) sv.skipCrafted = v end },
        { type = "checkbox", name = T"Keep items with unresearched traits",
          tooltip = T"You will need them for trait research.",
          getFunc = function() return sv.skipUnresearched end,
          setFunc = function(v) sv.skipUnresearched = v end },
        { type = "checkbox", name = T"Keep set items",
          getFunc = function() return sv.skipSets end,
          setFunc = function(v) sv.skipSets = v end },
        { type = "header", name = T"Raw materials" },
        { type = "checkbox", name = T"Refine raw materials",
          tooltip = T"Ore, raw cloth and hides, rough wood and jewelry dust are refined at their station after gear is deconstructed. Only full tens are refined; junk-marked and locked raw materials are not touched.",
          getFunc = function() return sv.refine end,
          setFunc = function(v) sv.refine = v end },
        { type = "checkbox", name = T"Refine raw materials from the bank",
          tooltip = T"Crafting stations can use raw materials straight from the bank. Inventory and bank stacks are refined separately: 9 in the inventory plus 1 in the bank do not add up to 10.",
          disabled = function() return not sv.refine end,
          getFunc = function() return sv.refineFromBank end,
          setFunc = function(v) sv.refineFromBank = v end },

        { type = "header", name = T"Glyphs" },
        { type = "checkbox", name = T"Deconstruct glyphs",
          tooltip = T"At the enchanting station.",
          getFunc = function() return sv.glyphs end,
          setFunc = function(v) sv.glyphs = v end },
        { type = "dropdown", name = T"Deconstruct glyph quality up to",
          tooltip = T"The selected quality and everything below it.",
          choices = qNames, choicesValues = qValues,
          disabled = function() return not sv.glyphs end,
          getFunc = function() return sv.glyphMaxQuality end,
          setFunc = function(v) sv.glyphMaxQuality = v end },
        { type = "checkbox", name = T"Keep crafted glyphs",
          tooltip = T"Glyphs crafted by players, e.g. for daily writs.",
          disabled = function() return not sv.glyphs end,
          getFunc = function() return sv.glyphSkipCrafted end,
          setFunc = function(v) sv.glyphSkipCrafted = v end },

        { type = "header", name = T"Other" },
        { type = "checkbox", name = T"Respect FCO ItemSaver protection",
          tooltip = T"Items protected in FCO ItemSaver against deconstruction, glyph extraction or refinement are skipped.",
          getFunc = function() return sv.respectFCOIS end,
          setFunc = function(v) sv.respectFCOIS = v end },
        { type = "checkbox", name = T"Chat messages",
          getFunc = function() return sv.chat end,
          setFunc = function(v) sv.chat = v end },
    })
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
    if addonName ~= MR.name then return end
    EVENT_MANAGER:UnregisterForEvent(MR.name, EVENT_ADD_ON_LOADED)

    sv = LoadSavedVars("MANARecycling_SV", SV_VERSION, DEFAULTS)

    EVENT_MANAGER:RegisterForEvent(MR.name, EVENT_CRAFTING_STATION_INTERACT, OnStationInteract)
    EVENT_MANAGER:RegisterForEvent(MR.name, EVENT_END_CRAFTING_STATION_INTERACT, OnStationEnd)
    EVENT_MANAGER:RegisterForEvent(MR.name, EVENT_CRAFT_COMPLETED, OnCraftCompleted)

    CreateSettings()

    SLASH_COMMANDS["/manarecycling"] = function(arg)
        arg = zo_strlower(zo_strtrim(arg or ""))
        if arg == "run" then
            MR.Run()
        elseif arg == "preview" then
            MR.Preview()
        elseif arg == "debug" then
            debugMode = not debugMode
            Say(T"Debug " .. (debugMode and T"enabled" or T"disabled") .. ".")
        elseif arg == "stop" then
            if running then Finish(T"Stopped.") end
        else
            Say(T"Gear: " .. QualityName(sv.maxQuality) .. T" and below.")
            Say(T"Glyphs: " .. (sv.glyphs and (QualityName(sv.glyphMaxQuality) .. T" and below") or T"not deconstructed") .. ".")
            Say(T"/manarecycling preview — show what would be deconstructed (changes nothing)")
            Say(T"/manarecycling run — deconstruct manually (at a station)")
            Say(T"/manarecycling stop — stop")
            Say(T"/manarecyclingsettings — settings")
        end
    end
end

EVENT_MANAGER:RegisterForEvent(MR.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
