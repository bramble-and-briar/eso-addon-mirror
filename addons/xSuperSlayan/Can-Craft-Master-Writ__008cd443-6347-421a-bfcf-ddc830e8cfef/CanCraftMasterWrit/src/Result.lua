-- The outcome of checking one writ: a list of checks, each passed, failed, unknown or informational,
-- plus an overall status worked out from them. Craft evaluators fill it in; the tooltip draws it.
--
-- Each check has a category (motif, trait, materials and so on), which picks its icon in the tooltip and lets
-- the settings turn whole requirements off, and a label with an optional value, drawn as "Label: value".

local addon = CanCraftMasterWrit
local Result = {}
addon.Result = Result

Result.STATE_PASS = 1
Result.STATE_FAIL = 2
Result.STATE_UNKNOWN = 3
Result.STATE_INFO = 4

Result.STATUS_CRAFTABLE = 1
Result.STATUS_NOT_CRAFTABLE = 2
Result.STATUS_UNKNOWN = 3

Result.CATEGORY_GENERAL = "general"
Result.CATEGORY_MOTIF = "motif"
Result.CATEGORY_TRAIT = "trait"
Result.CATEGORY_SET = "set"
Result.CATEGORY_RUNES = "runes"
Result.CATEGORY_REAGENTS = "reagents"
Result.CATEGORY_RECIPE = "recipe"
Result.CATEGORY_SKILLS = "skills"
Result.CATEGORY_MATERIALS = "materials"

-- Returns "label: value", or the label alone when there is no value.
function Result.JoinLabelValue(label, value)
    if value == nil or value == "" then
        return label
    end
    return zo_strformat(SI_CCMW_LABEL_VALUE, label, value)
end

-- Returns a detail line: a label and a value, such as a material and "3/13".
function Result.Detail(label, value)
    return { label = label, value = value, text = Result.JoinLabelValue(label, value) }
end

-- Returns "have/need".
function Result.Count(have, need)
    return zo_strformat(SI_CCMW_COUNT, have, need)
end

local ResultObject = {}
ResultObject.__index = ResultObject

function Result.New(writ)
    return setmetatable({ writ = writ, checks = {}, status = Result.STATUS_UNKNOWN }, ResultObject)
end

-- Adds one line to the result. Details are extra lines shown under it, such as each missing material.
-- text is the plain "label: value", used for chat and screen narration.
function ResultObject:Add(state, category, label, value, details)
    local check = {
        state = state,
        category = category or Result.CATEGORY_GENERAL,
        label = label,
        value = value,
        text = Result.JoinLabelValue(label, value),
        details = details or {},
    }
    table.insert(self.checks, check)
    return check
end

function ResultObject:Pass(category, label, value, details)
    return self:Add(Result.STATE_PASS, category, label, value, details)
end
function ResultObject:Fail(category, label, value, details)
    return self:Add(Result.STATE_FAIL, category, label, value, details)
end
function ResultObject:Unknown(category, label, value, details)
    return self:Add(Result.STATE_UNKNOWN, category, label, value, details)
end
function ResultObject:Info(category, label, value, details)
    return self:Add(Result.STATE_INFO, category, label, value, details)
end

-- Adds a skills check. Each requirement is { name, required, current }, or { unlockText, required, current } for
-- something that is either unlocked or not; ranks of nil count as unknown.
function ResultObject:AddSkills(requirements)
    local missing = {}
    local unknown = false
    for _, requirement in ipairs(requirements) do
        local required = requirement.required or 0
        if requirement.current == nil then
            unknown = true
        elseif requirement.current < required then
            if requirement.unlockText then
                table.insert(missing, Result.Detail(requirement.unlockText, GetString(SI_CCMW_NOT_UNLOCKED)))
            else
                table.insert(missing, Result.Detail(requirement.name, Result.Count(requirement.current, required)))
            end
        end
    end
    local category = Result.CATEGORY_SKILLS
    if #missing > 0 then
        return self:Fail(category, GetString(SI_CCMW_SKILLS_MISSING), nil, missing)
    elseif unknown then
        return self:Unknown(category, GetString(SI_CCMW_SKILLS_UNKNOWN))
    end
    return self:Pass(category, GetString(SI_CCMW_SKILLS_OK))
end

-- Adds a materials check. Each requirement is { link, needed }; { links, needed } for a choice of items; or
-- { name, owned, needed } when the game gives a count but no link. Requirements for the same item are added
-- together first.
function ResultObject:AddMaterials(requirements)
    local merged, order = {}, {}
    for _, requirement in ipairs(requirements) do
        local key = requirement.link or requirement.name or table.concat(requirement.links, ",")
        if merged[key] then
            merged[key].needed = merged[key].needed + requirement.needed
        else
            merged[key] = ZO_ShallowTableCopy(requirement)
            table.insert(order, key)
        end
    end

    local missing = {}
    for _, key in ipairs(order) do
        local requirement = merged[key]
        local owned, name
        if requirement.owned then
            owned, name = requirement.owned, requirement.name
        elseif requirement.links then
            -- A choice: the requirement is met if any one of the items is in stock.
            owned = 0
            local names = {}
            for _, link in ipairs(requirement.links) do
                owned = zo_max(owned, addon.Util.CountOwned(link))
                table.insert(names, addon.Util.ItemName(link))
            end
            name = zo_strformat(SI_CCMW_STYLE_OR_MIMIC, names[1], names[2])
        else
            owned = addon.Util.CountOwned(requirement.link)
            name = addon.Util.ItemName(requirement.link)
        end
        if owned < requirement.needed then
            table.insert(missing, Result.Detail(name, Result.Count(owned, requirement.needed)))
        end
    end

    local category = Result.CATEGORY_MATERIALS
    if #missing > 0 then
        return self:Fail(category, GetString(SI_CCMW_MATERIALS_MISSING), nil, missing)
    end
    return self:Pass(category, GetString(SI_CCMW_MATERIALS_OK))
end

-- Drops every check whose category the player turned off in the settings, so it is neither shown nor counted.
function ResultObject:RemoveCategories(isCategoryChecked)
    for index = #self.checks, 1, -1 do
        if not isCategoryChecked(self.checks[index].category) then
            table.remove(self.checks, index)
        end
    end
end

-- Works out the overall status: craftable only if nothing failed and nothing is unknown.
function ResultObject:Finish()
    local anyFailed, anyUnknown = false, false
    for _, check in ipairs(self.checks) do
        if check.state == Result.STATE_FAIL then
            anyFailed = true
        elseif check.state == Result.STATE_UNKNOWN then
            anyUnknown = true
        end
    end
    if anyFailed then
        self.status = Result.STATUS_NOT_CRAFTABLE
    elseif anyUnknown or #self.checks == 0 then
        self.status = Result.STATUS_UNKNOWN
    else
        self.status = Result.STATUS_CRAFTABLE
    end
    return self
end
