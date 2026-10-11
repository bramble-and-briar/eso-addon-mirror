-- Small helpers shared by every module: item links, stock counts, skill ranks and debug output.

local addon = CanCraftMasterWrit
local Util = {}
addon.Util = Util

local ITEM_LINK_FORMAT = "|H0:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"

-- Returns a plain item link for an item ID. Good enough for names, stock counts and requirements.
function Util.ItemLink(itemId)
    return string.format(ITEM_LINK_FORMAT, itemId)
end

-- Returns the display name of an item link, formatted the way the game shows it.
function Util.ItemName(itemLink)
    return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink))
end

-- Returns how many of an item the character can use at a crafting station: backpack, bank and craft bag.
-- House storage is left out on purpose, because crafting stations can't reach it.
function Util.CountOwned(itemLink)
    local backpack, bank, craftBag = GetItemLinkStacks(itemLink)
    return (backpack or 0) + (bank or 0) + (craftBag or 0)
end

-- Finds a stack of an item the character can craft with. Returns its bag and slot, or nil.
-- The craft bag is checked first because its slot index is the item ID.
function Util.FindItemSlot(itemId)
    if HasCraftBagAccess() and GetSlotStackSize(BAG_VIRTUAL, itemId) > 0 then
        return BAG_VIRTUAL, itemId
    end
    for _, bagId in ipairs({ BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }) do
        for slotIndex = 0, GetBagSize(bagId) - 1 do
            if GetItemId(bagId, slotIndex) == itemId then
                return bagId, slotIndex
            end
        end
    end
    return nil
end

-- Splits an item link into its numeric data fields.
-- Returns the item ID and an array of the writ data fields. Master writs store their requirements in
-- link fields 7 to 12 (counting the item ID as field 1), which become writFields[1] to writFields[6].
function Util.ParseWritLink(itemLink)
    local parts = { ZO_LinkHandler_ParseLink(itemLink) }
    -- parts[1] = text, parts[2] = style, parts[3] = link type, parts[4] = item ID, parts[5...] = data fields.
    if parts[3] ~= ITEM_LINK_TYPE then
        return nil
    end
    local writFields = {}
    for index = 10, zo_max(#parts, 24) do
        writFields[#writFields + 1] = tonumber(parts[index]) or 0
    end
    return tonumber(parts[4]), writFields
end

-- Returns the character's current rank in a crafting passive, given any rank's ability ID.
function Util.GetPassiveRank(abilityId)
    local skillType, skillLineIndex, skillIndex = GetSpecificSkillAbilityKeysByAbilityId(abilityId)
    if not skillType or skillType == 0 or not skillLineIndex or not skillIndex then
        return nil
    end
    if not IsSkillAbilityPurchased(skillType, skillLineIndex, skillIndex) then
        return 0
    end
    local currentRank = GetSkillAbilityUpgradeInfo(skillType, skillLineIndex, skillIndex)
    return currentRank or 1
end

-- Returns an ability's name without rank markers, or the fallback when the game doesn't know it.
function Util.AbilityName(abilityId, fallback)
    local name = abilityId and GetAbilityName(abilityId) or ""
    if name == "" then
        return fallback or ""
    end
    return zo_strformat(SI_ABILITY_NAME, name)
end

-- Returns the name of the passive that sets the material or potency level for a craft, such as Metalworking.
function Util.LevelPassiveName(tradeskillType)
    return Util.AbilityName(GetTradeskillLevelPassiveAbilityId(tradeskillType))
end

-- Returns the character's rank in the passive that sets the material or potency level for a craft.
function Util.LevelPassiveRank(tradeskillType)
    return GetNonCombatBonus(GetNonCombatBonusLevelTypeForTradeskillType(tradeskillType))
end

-- Autumn leaf colours, red to gold. All are bright enough to read on the chat window's dark background; brown and
-- dark red are left out on purpose.
local FALL_COLORS = {
    { 0xFF, 0x4F, 0x3A }, -- Maple red
    { 0xFF, 0x57, 0x22 }, -- Scarlet orange
    { 0xFF, 0x8F, 0x00 }, -- Pumpkin
    { 0xFF, 0xB3, 0x00 }, -- Amber
    { 0xFF, 0xD5, 0x4F }, -- Harvest gold
}

-- Returns the colour at a point (0 to 1) along the palette, going red to gold and back to red.
local function FallColorAt(position)
    -- Fold the second half back, so the text starts and ends on red.
    local folded = position <= 0.5 and position * 2 or (1 - position) * 2
    local scaled = folded * (#FALL_COLORS - 1)
    local index = zo_min(zo_floor(scaled) + 1, #FALL_COLORS - 1)
    local fraction = scaled - (index - 1)
    local from, to = FALL_COLORS[index], FALL_COLORS[index + 1]
    local color = {}
    for channel = 1, 3 do
        color[channel] = zo_floor(from[channel] + (to[channel] - from[channel]) * fraction + 0.5)
    end
    return string.format("%02X%02X%02X", color[1], color[2], color[3])
end

-- Colours each letter of the text along the fall palette. Spaces are left plain.
-- Letters are read as whole UTF-8 characters, so accented letters in other languages stay intact.
function Util.FallGradient(text)
    local characters = {}
    for character in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(characters, character)
    end
    local length = #characters
    local parts = {}
    for index, character in ipairs(characters) do
        if character == " " then
            table.insert(parts, character)
        else
            local position = length > 1 and (index - 1) / (length - 1) or 0
            table.insert(parts, string.format("|c%s%s|r", FallColorAt(position), character))
        end
    end
    return table.concat(parts)
end

-- Prints a debug message to chat when debug output is switched on.
function Util.Debug(message, ...)
    if addon.debug then
        CHAT_ROUTER:AddSystemMessage(string.format("[%s] %s", addon.name, string.format(message, ...)))
    end
end
