-- FurnitureFinderLiteLinesActions.lua: a furnishing's source lines, with the names the game knows.
--
-- The data holds ids for whatever the game can name in the player's own language (zones,
-- achievements, quests, houses, containers, plans) and English text for the rest.
local FFL = FurnitureFinderLite
local DataUtils = FFL.DataUtils
local LinesUtils = FFL.LinesUtils

local Lines = {}

local BARE_LINK_FORMAT = "|H0:item:%d:0:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
local MUTED = "|c888888%s|r"

---@param name string|nil a name as the game hands it out (grammar markers and all)
---@return string|nil
local function Clean(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return zo_strformat("<<C:1>>", name)
end

---@param itemId integer
---@return string|nil name of an item, from its id alone
local function ItemName(itemId)
    return Clean(GetItemLinkName(string.format(BARE_LINK_FORMAT, itemId)))
end

-- What a token reads as, by letter. A letter without an entry is an index into the English texts.
local RESOLVERS = {
    z = function(value)
        return Clean(GetZoneNameById(tonumber(value)))
    end,
    ["$"] = function(value, texts)
        local amount, currency = string.match(value, "^(%d+)%.(%d+)$")
        if not amount then
            return nil
        end
        return LinesUtils.NumberText(tonumber(amount)) .. " " .. tostring(texts[tonumber(currency)])
    end,
    a = function(value)
        local achievementId = tonumber(value)
        if achievementId == 0 then
            return "an achievement"
        end
        local name = Clean(GetAchievementName(achievementId))
        if not name then
            return "an achievement"
        end
        return name .. (IsAchievementComplete(achievementId) and " (earned)" or " (not earned)")
    end,
    s = function(value)
        local skillLineId, rank = string.match(value, "^(%d+)%.(%d+)$")
        local name = skillLineId and Clean(GetSkillLineNameById(tonumber(skillLineId)))
        if not name then
            return nil
        end
        return tonumber(rank) > 0 and (name .. " rank " .. rank) or name
    end,
    C = function(value)
        return Clean(GetCollectibleName(tonumber(value)))
    end,
    q = function(value)
        local questId = tonumber(value)
        return questId ~= 0 and Clean(GetQuestName(questId)) or "a quest"
    end,
    h = function(value)
        return Clean(GetCollectibleName(tonumber(value)))
    end,
    c = function(value)
        return ItemName(tonumber(value))
    end,
    G = function(value)
        return Clean(GetString("SI_MONSTERSOCIALCLASS", tonumber(value)))
    end,
    d = function(value)
        return LinesUtils.DateText(value)
    end,
    B = function(value)
        local planId = tonumber(value)
        local name = ItemName(planId)
        if not name then
            return nil
        end
        return name .. (IsItemLinkRecipeKnown(string.format(BARE_LINK_FORMAT, planId)) and " (known)" or " (not known)")
    end,
}

---@param letter string
---@param value string
---@return string|nil
local function Resolve(letter, value)
    local texts = FFL.Data.texts[letter]
    local resolver = RESOLVERS[letter]
    if resolver then
        return resolver(value, texts)
    end
    return texts and texts[tonumber(value)] or nil
end

---The source lines of a furnishing.
---@param itemId integer
---@return string[]|nil lines nil when the furnishing is not in the data
function Lines.ForFurnishing(itemId)
    local records = DataUtils.Records(FFL.Data, itemId)
    if not records then
        return nil
    end
    return LinesUtils.Compose(records, Resolve)
end

---The lines of a plan: the sources of the furnishing it makes that say where the plan itself
---comes from (a merchant selling it, a container holding it). "Crafting" alone says nothing
---on the plan's own tooltip, and neither does a line naming the plan.
---@param furnishingId integer the furnishing the plan makes
---@return string[]|nil
function Lines.ForPlanOf(furnishingId)
    local records = DataUtils.Records(FFL.Data, furnishingId)
    if not records then
        return nil
    end
    local aboutThePlan = {}
    for _, record in ipairs(records) do
        local kept, namesPlan = {}, false
        for _, token in ipairs(record) do
            if token[1] == "B" then
                namesPlan = true
            else
                kept[#kept + 1] = token
            end
        end
        if namesPlan and #kept > 1 then
            aboutThePlan[#aboutThePlan + 1] = kept
        end
    end
    if #aboutThePlan == 0 then
        return nil
    end
    return LinesUtils.Compose(aboutThePlan, Resolve)
end

---The lines a tooltip of this item gets.
---@param itemLink string
---@return string[]|nil lines nil for an item this add-on has nothing to say about
function Lines.ForLink(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end
    local itemType = GetItemLinkItemType(itemLink)
    if itemType == ITEMTYPE_RECIPE then
        if not IsItemLinkFurnitureRecipe(itemLink) then
            return nil
        end
        local resultLink = GetItemLinkRecipeResultItemLink(itemLink, LINK_STYLE_DEFAULT)
        local furnishingId = resultLink and resultLink ~= "" and GetItemLinkItemId(resultLink) or 0
        return furnishingId > 0 and Lines.ForPlanOf(furnishingId) or nil
    end
    -- Some placeable furnishings report another item type (trophy-style wall decor, per
    -- Furniture Finder's field notes), so ask the game whether it can be placed.
    if itemType ~= ITEMTYPE_FURNISHING and not IsItemLinkPlaceableFurniture(itemLink) then
        return nil
    end
    local lines = Lines.ForFurnishing(GetItemLinkItemId(itemLink))
    if lines then
        return lines
    end
    return { string.format(MUTED, "Source: not in the data (updated " .. tostring(FFL.Data.updated) .. ")") }
end

FFL.Lines = Lines
