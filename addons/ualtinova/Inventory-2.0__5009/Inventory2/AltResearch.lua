InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- RESEARCHABLE (ALTS): gear this character already knows the trait of (or is researching right
-- now) that another character on the same account does not know yet. Off by default, and only
-- ever filled when LibCharacterKnowledge is installed (CharacterKnowledge addon) -- an optional
-- dependency, never required, the same way Researchable.lua reads it.
--
-- A piece belongs here once: the normal RESEARCHABLE group already covers "this character can
-- research it"; this one is only pieces that character is done with. A piece needed by two or
-- more alts is listed once under each of them -- the question is "which alt do I take this to",
-- and the answer can be more than one name.
--
-- Real API, confirmed against the installed library source (2026-11-03):
--   LibCharacterKnowledge.GetServerList()                                   Public.lua:38
--   LibCharacterKnowledge.GetCharacterList(server)                          Public.lua:57
--   LibCharacterKnowledge.CanItemLinkBeTraitResearchedByCharacter(          Public.lua:338
--       itemLink, server, charId)
--   LibCharacterKnowledge.RegisterForCallback(name, eventCode, callback)    Public.lua:461
--   LibCharacterKnowledge.EVENT_UPDATE_REFRESH                             Public.lua:31
-- GetCurrentCharacterId() is the game's own API (used the same way by the library itself,
-- Internal.lua:48).

local GEAR_TYPES = { [ITEMTYPE_ARMOR] = true, [ITEMTYPE_WEAPON] = true }
local CALLBACK_NAME = "Inventory2AltResearch"
local NAME = "InventoryGroupingAltResearch"
local REFRESH_MS = 250

-- [itemInstanceId] = { [charId] = charName } for every alt that can still research this piece's
-- trait, or false once asked with nothing to show. Only research starting, finishing or being
-- cancelled on any character changes the answer, and those clear this whole table.
local altCache = {}

local function ClearCache()
    ZO_ClearTable(altCache)
end
IG.ClearAltResearchCache = ClearCache

-- Every alt that can still research this link's trait, cached per item instance since the same
-- physical piece is asked about on every list refresh otherwise. Nothing at all when this
-- character can research it itself -- that is RESEARCHABLE's piece -- or is researching it now.
-- Deliberately NOT gated on the game's own trait information (CAN_BE_RESEARCHED): that answers
-- for the character playing, and a piece this character already knows reads as something else
-- there, which is exactly the piece this list is for (reported 2026-11-03: a main that knows
-- every trait had nothing researchable, so nothing was ever asked of the alts).
local function AltsFor(itemInstanceId, itemLink, lck, server, chars, currentCharId)
    if itemInstanceId then
        local cached = altCache[itemInstanceId]
        if cached ~= nil then return cached end
    end
    if lck.CanItemLinkBeTraitResearchedByCharacter(itemLink, server, currentCharId) == true then
        if itemInstanceId then altCache[itemInstanceId] = false end
        return nil
    end
    local matches
    for _, char in ipairs(chars) do
        if char.id ~= currentCharId
            and lck.CanItemLinkBeTraitResearchedByCharacter(itemLink, server, char.id) == true then
            matches = matches or {}
            matches[char.id] = char.name
        end
    end
    if itemInstanceId then altCache[itemInstanceId] = matches or false end
    return matches
end

-- Why a piece is worth a second look: locked (you marked it "not this one"), in an Armory build,
-- or in a saved setup (Setups.lua) -- all three say you are using this piece, not holding it for
-- an alt. Each reason has its own switch (Settings.lua: researchAltsShowLocked/Armory/Setup):
-- off, the piece is left out entirely; on, it is shown anyway but still carries the note, so
-- turning one on does not quietly drop the other two's warnings too.
-- Returns the note text (or nil, for an ordinary piece) and whether to leave it out altogether.
local function PieceStatus(data, bagId, slotIndex)
    if IG.IsSlotLocked(data) then
        return "Locked", not (IG.sv and IG.sv.researchAltsShowLocked)
    end
    if IsItemInArmory and IsItemInArmory(bagId, slotIndex) then
        return "In Armory", not (IG.sv and IG.sv.researchAltsShowArmory)
    end
    if IG.SetupPathFor and IG.SetupPathFor(data) then
        return "In a Setup", not (IG.sv and IG.sv.researchAltsShowSetup)
    end
    return nil, false
end

-- Called for the backpack only (inventoryType check below), the same as Researchable.lua: a
-- worn piece is never researched, and nothing else carries this trait.
function IG.CollectAltResearchEntries(inventory, inventoryType, rawEntries, searchText)
    local result = {}
    if not (IG.sv and IG.sv.researchAltsEnabled) then return result end
    -- Backpack or the player's own bank: a bench can research either, same as RESEARCHABLE.
    if inventoryType ~= INVENTORY_BACKPACK and inventoryType ~= INVENTORY_BANK then return result end
    if inventoryType == INVENTORY_BANK and IG.sv.bankModules and IG.sv.bankModules.RESEARCHALTS == false then
        return result
    end
    local lck = LibCharacterKnowledge
    if not (lck and lck.GetServerList and lck.GetCharacterList
        and lck.CanItemLinkBeTraitResearchedByCharacter and GetCurrentCharacterId) then
        return result
    end
    local server = lck.GetServerList()[1]
    if not server then return result end
    local chars = lck.GetCharacterList(server)
    if not chars or #chars < 2 then return result end
    local currentCharId = GetCurrentCharacterId()

    local root = IG.MakeGroupNode("RESEARCHALTS")
    local charNodes, order = {}, 0

    for _, entry in ipairs(rawEntries) do
        local data = entry.data
        local bagId, slotIndex = data.bagId, data.slotIndex
        -- Not always on the row's own data (Researchable.lua reads it the same guarded way).
        local itemType = data.itemType
        if itemType == nil and bagId and slotIndex then itemType = GetItemType(bagId, slotIndex) end
        if (bagId == BAG_BACKPACK or bagId == BAG_BANK) and slotIndex and GEAR_TYPES[itemType] then
            local link = GetItemLink(bagId, slotIndex)
            if link and link ~= "" then
                local matches = AltsFor(data.itemInstanceId, link, lck, server, chars, currentCharId)
                if matches then
                    local note, exclude = PieceStatus(data, bagId, slotIndex)
                    if not exclude then
                        for charId, charName in pairs(matches) do
                            local node = charNodes[charId]
                            if not node then
                                order = order + 1
                                node = { id = "altchar" .. charId, label = charName,
                                    color = IG.GetGroupColor("RESEARCHALTS"), order = order,
                                    altCharId = charId, altItems = {}, altSeen = {} }
                                charNodes[charId] = node
                            end
                            if not node.altSeen[link] then
                                node.altSeen[link] = true
                                node.altItems[#node.altItems + 1] = link
                            end
                            local proxy = setmetatable(
                                { igAltResearch = true, igAltResearchNote = note },
                                { __index = data })
                            result[#result + 1] = { data = proxy, path = { root, node } }
                        end
                    end
                end
            end
        end
    end
    return result
end

-- Starting, finishing or cancelling research on any character changes the answer for every
-- piece with that trait, not only the one slot -- the same reasoning Researchable.lua's own
-- refresh uses, just a shared trigger since both read the same underlying state.
local function OnResearchChanged()
    ClearCache()
    if not (IG.sv and IG.sv.researchAltsEnabled) then return end
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Refresh")
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Refresh", REFRESH_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(NAME .. "Refresh")
        if IG.RefreshLists then IG.RefreshLists() end
    end)
end

local registered = false

local function ApplyEnabled(on)
    if on == registered then return end
    registered = on
    ClearCache()
    local lck = LibCharacterKnowledge
    if on then
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_SMITHING_TRAIT_RESEARCH_STARTED, OnResearchChanged)
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED, OnResearchChanged)
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_SMITHING_TRAIT_RESEARCH_CANCELED, OnResearchChanged)
        if lck and lck.RegisterForCallback and lck.EVENT_UPDATE_REFRESH then
            lck.RegisterForCallback(CALLBACK_NAME, lck.EVENT_UPDATE_REFRESH, OnResearchChanged)
        end
        -- The library finishes reading every character's knowledge some time after login. A
        -- list built before that asked it about nothing it knew yet, and "nobody can research
        -- this" was cached for each piece until a research event cleared it -- which is how the
        -- list stayed empty after a reload although /i2altwhy (no cache) found 241 pieces
        -- (reported 2026-11-03). Cleared when it says it is ready, and once more a while after
        -- login in case that signal was missed.
        if lck and lck.RegisterForCallback and lck.EVENT_INITIALIZED then
            lck.RegisterForCallback(CALLBACK_NAME .. "Init", lck.EVENT_INITIALIZED, OnResearchChanged)
        end
        zo_callLater(OnResearchChanged, 8000)
    else
        EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_SMITHING_TRAIT_RESEARCH_STARTED)
        EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED)
        EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_SMITHING_TRAIT_RESEARCH_CANCELED)
        if lck and lck.UnregisterForCallback and lck.EVENT_UPDATE_REFRESH then
            lck.UnregisterForCallback(CALLBACK_NAME, lck.EVENT_UPDATE_REFRESH)
        end
        if lck and lck.UnregisterForCallback and lck.EVENT_INITIALIZED then
            lck.UnregisterForCallback(CALLBACK_NAME .. "Init", lck.EVENT_INITIALIZED)
        end
    end
end

IG.MODULE_APPLY = IG.MODULE_APPLY or {}
IG.MODULE_APPLY.researchAltsEnabled = ApplyEnabled

-- Hovering a character's heading under RESEARCHABLE (ALTS): how many traits that character still
-- has to learn (per craft, read from LibCharacterKnowledge the way the module reads everything
-- else) and which pieces in this list are for them. Asked at the hover, not kept: it is a few
-- hundred cheap lookups once, never per refresh.
local TRADESKILLS = {}
for _, name in ipairs({ "CRAFTING_TYPE_BLACKSMITHING", "CRAFTING_TYPE_CLOTHIER", "CRAFTING_TYPE_WOODWORKING",
    "CRAFTING_TYPE_JEWELRYCRAFTING" }) do
    if _G[name] then TRADESKILLS[#TRADESKILLS + 1] = _G[name] end
end
local TIP_ITEMS_MAX = 12

function IG.ShowAltCharTooltip(row, data)
    local lck = LibCharacterKnowledge
    if not (lck and lck.GetServerList and lck.GetSmithingResearchLineTraitInfoForCharacter) then return end
    local server = lck.GetServerList()[1]
    local charId = data.altCharId
    if not (server and charId) then return end
    local r, g, b = IG.HexToRGB(data.color)

    InitializeTooltip(InformationTooltip, row, RIGHT, -12, 0, LEFT)
    InformationTooltip:AddLine(data.label, "ZoFontWinH2", r, g, b)
    ZO_Tooltip_AddDivider(InformationTooltip)

    local total = 0
    local perCraft = {}
    for _, craftingType in ipairs(TRADESKILLS) do
        local missing = 0
        for lineIndex = 1, GetNumSmithingResearchLines(craftingType) do
            local numTraits = select(3, GetSmithingResearchLineInfo(craftingType, lineIndex)) or 0
            for traitIndex = 1, numTraits do
                local _, _, known = lck.GetSmithingResearchLineTraitInfoForCharacter(
                    craftingType, lineIndex, traitIndex, server, charId)
                if known == false then missing = missing + 1 end
            end
        end
        if missing > 0 then
            perCraft[#perCraft + 1] = string.format("%s: %d", GetString("SI_TRADESKILLTYPE", craftingType), missing)
            total = total + missing
        end
    end
    InformationTooltip:AddLine(string.format("%d traits still to research", total), "ZoFontWinH5", r, g, b)
    if #perCraft > 0 then
        InformationTooltip:AddLine(table.concat(perCraft, "  ·  "), "ZoFontGame", 0.92, 0.92, 0.88)
    end

    local items = data.altItems
    if items and #items > 0 then
        ZO_Tooltip_AddDivider(InformationTooltip)
        InformationTooltip:AddLine(string.format("%d here for them", #items), "ZoFontWinH5", r, g, b)
        for index = 1, zo_min(#items, TIP_ITEMS_MAX) do
            InformationTooltip:AddLine(zo_strformat("<<1>>", items[index]), "ZoFontGame", 0.92, 0.92, 0.88)
        end
        if #items > TIP_ITEMS_MAX then
            InformationTooltip:AddLine(string.format("... and %d more", #items - TIP_ITEMS_MAX), "ZoFontGameSmall", 0.65, 0.65, 0.65)
        end
    end
end
