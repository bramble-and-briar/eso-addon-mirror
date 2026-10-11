local BA = BuildAdvisor
-- Roles, and the registry the activity files in Data/Targets/ add themselves to.
-- Activity picker order is manifest load order.

-- noun: how findings refer to someone in the role ("for a tank", "most damage dealers").
BA.roles = {
    { id = "damage", name = "Damage", noun = "damage dealer" },
    { id = "tank", name = "Tank", noun = "tank" },
    { id = "healer", name = "Healer", noun = "healer" },
}
BA.rolesById = {}
for _, role in ipairs(BA.roles) do BA.rolesById[role.id] = role end

BA.activities = {}
BA.activitiesById = {}
BA.targets = {}

-- Works out groupPenetration and statusCount from the tier's assumed debuffs.
local function ApplyDebuffs(target)
    target.groupPenetration = target.extraPenetration or 0
    target.statusCount = 0
    target.hasDebuff = {}
    for _, id in ipairs(target.debuffs or {}) do
        local debuff = BA.DEBUFFS[id]
        target.hasDebuff[id] = true
        target.groupPenetration = target.groupPenetration + (debuff.pen or 0)
        if debuff.status then target.statusCount = target.statusCount + 1 end
    end
end

-- def: { id, name, note (picker tooltip), target = { see Data/Targets/Common.lua } }
function BA.RegisterActivity(def)
    ApplyDebuffs(def.target)
    BA.activities[#BA.activities + 1] = def
    BA.activitiesById[def.id] = def
    BA.targets[def.id] = def.target
end
