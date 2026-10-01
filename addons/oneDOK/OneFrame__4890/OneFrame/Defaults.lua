local A = OneFrame
A.roleResources = {
    [LFG_ROLE_TANK] = COMBAT_MECHANIC_FLAGS_HEALTH,
    [LFG_ROLE_HEAL] = COMBAT_MECHANIC_FLAGS_MAGICKA,
    [LFG_ROLE_DPS] = COMBAT_MECHANIC_FLAGS_STAMINA,
}
function A:ResourceColor(role)
    local resource = self.roleResources[role] or COMBAT_MECHANIC_FLAGS_HEALTH
    return { ZO_POWER_BAR_GRADIENT_COLORS[resource][1]:UnpackRGBA() }
end
function A:MakeDefaults()
    local colors = {}
    for role in pairs(self.roleResources) do colors[role] = self:ResourceColor(role) end
    return {
        enabled = true, sort = false, account = false, class = true, level = true, cp = true,
        roleStats = {}, colors = colors, customColors = {}, dps = false, hps = false, hodor = true, ultimate = true,
        shield = true, shieldColor = { 0.5, 0.5, 1 }, shieldOpacity = 0.45,
        interaction = true, contextMenu = true, groupDps = true,
    }
end
function A:RoleGradient(tag)
    local role = GetGroupMemberSelectedRole(tag)
    if self.sv.customColors[role] and self.sv.colors[role] then
        local color = ZO_ColorDef:New(unpack(self.sv.colors[role]))
        return { color, color }
    end
    return ZO_POWER_BAR_GRADIENT_COLORS[self.roleResources[role] or COMBAT_MECHANIC_FLAGS_HEALTH]
end

function A:RoleStatistic(role)
    local selected = self.sv.roleStats and self.sv.roleStats[role]
    if selected then return selected end
    if role == LFG_ROLE_DPS and self.sv.dps then return "dps" end
    if role == LFG_ROLE_HEAL and self.sv.hps then return "hps" end
    return "none"
end
function A:PrepareRoleStatistics()
    self.sv.roleStats = self.sv.roleStats or {}
    for role in pairs(self.roleResources) do
        self.sv.roleStats[role] = self:RoleStatistic(role)
    end
    self.sv.dps, self.sv.hps = false, false
    for _, value in pairs(self.sv.roleStats) do
        if value == "dps" then self.sv.dps = true end
        if value == "hps" then self.sv.hps = true end
    end
end
