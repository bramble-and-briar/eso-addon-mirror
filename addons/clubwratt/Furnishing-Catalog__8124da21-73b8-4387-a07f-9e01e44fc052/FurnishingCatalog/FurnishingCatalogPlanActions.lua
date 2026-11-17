-- FurnishingCatalogPlanActions.lua: a furnishing's plan, read from the game.
--
-- The built-in list says which plan makes a furnishing (ids only); name, link and whether this
-- character knows it come from the game. Nothing is kept beyond the fields set on the item.
local FC = FurnishingCatalog
local ScanUtils = FC.ScanUtils
local PlanUtils = FC.PlanUtils

local Plans = {}

---The (furnishing, plan) pairs in use: a full scan's own, else the built-in list's.
---@return integer[]|nil pairs
---@return string source "scan" or "built-in list"
function Plans.Pairs()
    local catalog = FC.Scan and FC.Scan.GetCatalog()
    if catalog and catalog.source == "full" and type(catalog.plans) == "table" then
        return catalog.plans, "scan"
    end
    return FC.Seed and FC.Seed.plans, "built-in list"
end

---@return integer numPlans furnishings a plan is known for
---@return string source
function Plans.Count()
    local pairs, source = Plans.Pairs()
    return type(pairs) == "table" and math.floor(#pairs / 2) or 0, source
end

---The plan of a furnishing, when this client holds that plan.
---@param itemId integer
---@return integer|nil planId
function Plans.IdOf(itemId)
    local planId = PlanUtils.PlanOf((Plans.Pairs()), itemId)
    if planId and GetItemLinkName(ScanUtils.BareLink(planId)) ~= "" then
        return planId
    end
    return nil
end

---Link of a plan in the form the game itself writes.
---@param planId integer
---@return string
function Plans.LinkOf(planId)
    return ScanUtils.Link(planId, GetItemLinkDisplayQuality(ScanUtils.BareLink(planId)) or 0)
end

---@param planId integer
---@return string
function Plans.NameOf(planId)
    return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(ScanUtils.BareLink(planId)))
end

-- Does the game itself say whether a furnishing has a plan? GetRecipeInfoFromItemId takes the
-- item a recipe makes; the first few furnishings looked at, with a built-in plan and without,
-- are logged with its answer beside the built-in list's, so a console export settles it.
local RECIPE_LOG_LIMIT = 6 -- of each kind
local recipesLogged = { [true] = 0, [false] = 0 }

---@param item FurnishingCatalogItem
local function LogGameRecipe(item)
    local hasPlan = item.planLink ~= nil
    if recipesLogged[hasPlan] >= RECIPE_LOG_LIMIT or not FC.IsDebug() then
        return
    end
    recipesLogged[hasPlan] = recipesLogged[hasPlan] + 1
    local game = "GetRecipeInfoFromItemId missing"
    local lookup = rawget(_G, "GetRecipeInfoFromItemId")
    if type(lookup) == "function" then
        local ok, station, listIndex, recipeIndex = pcall(lookup, item.id)
        if not ok then
            game = "error: " .. tostring(station)
        elseif listIndex and recipeIndex then
            local okInfo, known, name = pcall(GetRecipeInfo, listIndex, recipeIndex)
            game = FC.Fmt("station=%s list=%s recipe=%s known=%s name='%s'", tostring(station), tostring(listIndex), tostring(recipeIndex), tostring(okInfo and known), tostring(okInfo and name))
        else
            game = FC.Fmt("no recipe (station=%s)", tostring(station))
        end
    end
    FC.Log("recipe check %d '%s': built-in plan=%s known=%s | game: %s", item.id, tostring(item.name), tostring(item.planId), tostring(item.planLink ~= nil and IsItemLinkRecipeKnown(item.planLink) == true), game)
end

---Read an item's plan into it, once: item.planId (false when it has none), item.planLink and
---item.planState. Whether the plan is known is read each time, since a plan can be learned
---while the catalog is open.
---@param item FurnishingCatalogItem
---@return integer state PlanUtils.STATE_*
function Plans.Fill(item)
    if item.planId == nil then
        local planId = Plans.IdOf(item.id)
        item.planId = planId or false
        item.planLink = planId and Plans.LinkOf(planId) or nil
        LogGameRecipe(item)
    end
    local known = item.planLink ~= nil and IsItemLinkRecipeKnown(item.planLink) == true
    item.planState = PlanUtils.State(item.planLink ~= nil, known)
    return item.planState
end

FC.Plans = Plans
