-- FurnishingCatalogPlanUtils.lua: pure helpers for a furnishing's plan (no game calls).
--
-- A plan is the recipe scroll that teaches a craftable furnishing: a Blueprint, Design, Diagram,
-- Formula, Pattern, Praxis or Sketch. Which plan makes which furnishing is in the built-in list
-- (FurnishingCatalogSeed.lua, plans): the game's API reads a plan's result, never a result's plan.
local FC = FurnishingCatalog
local ScanUtils = FC.ScanUtils

local PlanUtils = {}

-- How a furnishing stands to its plan; the "Plan" sections come in this order (what to shop for first).
PlanUtils.STATE_UNKNOWN = 1 -- has a plan this character has not learned
PlanUtils.STATE_KNOWN = 2   -- has a plan this character knows
PlanUtils.STATE_NONE = 3    -- no plan: not craftable

local STATE_TEXT = {
    [PlanUtils.STATE_UNKNOWN] = "Not known",
    [PlanUtils.STATE_KNOWN] = "Known",
    [PlanUtils.STATE_NONE] = "None",
}
local STATE_SECTION = {
    [PlanUtils.STATE_UNKNOWN] = "Plan not known",
    [PlanUtils.STATE_KNOWN] = "Plan known",
    [PlanUtils.STATE_NONE] = "No plan",
}

---The plan of a furnishing.
---@param plans integer[]|nil flat (furnishing item id, plan item id) pairs, sorted by furnishing id
---@param itemId integer|nil
---@return integer|nil planId nil when the furnishing has no plan
function PlanUtils.PlanOf(plans, itemId)
    return ScanUtils.PairValue(plans, itemId)
end

---@param hasPlan boolean
---@param known boolean
---@return integer state
function PlanUtils.State(hasPlan, known)
    if not hasPlan then
        return PlanUtils.STATE_NONE
    end
    return known and PlanUtils.STATE_KNOWN or PlanUtils.STATE_UNKNOWN
end

---What the header says about a furnishing's plan.
---@param state integer|nil
---@return string
function PlanUtils.StateText(state)
    return STATE_TEXT[state] or STATE_TEXT[PlanUtils.STATE_NONE]
end

---The section a furnishing is listed under in the Plan group mode.
---@param state integer|nil
---@return string
function PlanUtils.SectionName(state)
    return STATE_SECTION[state] or STATE_SECTION[PlanUtils.STATE_NONE]
end

FC.PlanUtils = PlanUtils
