local AH = _G.MarkTrialHelper
local IS_RU = (GetCVar("language.2") == "ru")
local lastAlertTime = {}

local function IsAlertEnabled()
    if AH.Vars and AH.Vars.RoleDeathAlert == false then
        return false
    end
    return true
end

local function ShowRoleDeathAlert(role, unitName, displayName)
    local isTank = (role == LFG_ROLE_TANK)
    local roleLabel = isTank
        and (IS_RU and "ТАНК" or "TANK")
        or  (IS_RU and "ХИЛ" or "HEALER")

    local statusText = IS_RU and "ПОГИБ!" or "DIED!"
    local colorHex = isTank and "ff5555" or "55ffaa"
    local iconPath = ZO_GetRoleIcon and ZO_GetRoleIcon(role)
    local iconPrefix = iconPath and (zo_iconFormat(iconPath, 32, 32) .. " ") or ""

    local targetLabel = (displayName and displayName ~= "") and string.format("%s (%s)", unitName, displayName) or unitName
    local bannerText = string.format("%s|c%s[%s]|r |cffffff%s|r |cff3333%s|r", iconPrefix, colorHex, roleLabel, targetLabel, statusText)

    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_MAJOR_TEXT)
    params:SetText(bannerText)
    params:SetSound(SOUNDS.GENERAL_ALERT_ERROR)
    params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_SYSTEM_BROADCAST)
    params:MarkShowImmediately()
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)

    d(string.format("|cff9900[Mark Trial Helper]|r |c%s[%s]|r %s — |cff3333%s|r", colorHex, roleLabel, targetLabel, statusText))
end

local function OnUnitDeathStateChanged(_, unitTag, isDead)
    if not isDead or not IsAlertEnabled() then return end
    if AreUnitsEqual(unitTag, "player") then return end

    local role = GetGroupMemberSelectedRole(unitTag)
    if role ~= LFG_ROLE_TANK and role ~= LFG_ROLE_HEAL then return end

    local now = GetGameTimeMilliseconds()
    if lastAlertTime[unitTag] and (now - lastAlertTime[unitTag]) < 3000 then return end
    lastAlertTime[unitTag] = now

    local unitName = zo_strformat("<<1>>", GetUnitName(unitTag))
    local displayName = GetUnitDisplayName(unitTag)
    ShowRoleDeathAlert(role, unitName, displayName)
end

function AH.ToggleRoleDeathAlert()
    if not AH.Vars then return end
    if AH.Vars.RoleDeathAlert == nil then AH.Vars.RoleDeathAlert = true end
    AH.Vars.RoleDeathAlert = not AH.Vars.RoleDeathAlert

    local state = AH.Vars.RoleDeathAlert
        and (IS_RU and "|c00ff00ВКЛ|r" or "|c00ff00ON|r")
        or  (IS_RU and "|cff5555ВЫКЛ|r" or "|cff5555OFF|r")

    d(string.format(IS_RU and "|cff9900[Mark Trial Helper]|r Оповещения о смерти Танка/Хила: %s"
                          or "|cff9900[Mark Trial Helper]|r Tank/Healer death alerts: %s", state))
end

function AH.TestRoleDeathAlert()
    local name = zo_strformat("<<1>>", GetUnitName("player"))
    local acc = GetUnitDisplayName("player")
    ShowRoleDeathAlert(LFG_ROLE_TANK, name, acc)
end

EVENT_MANAGER:RegisterForEvent(AH.Name .. "_RoleAlerts", EVENT_UNIT_DEATH_STATE_CHANGED, OnUnitDeathStateChanged)
EVENT_MANAGER:AddFilterForEvent(AH.Name .. "_RoleAlerts", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")

SLASH_COMMANDS["/mrole"] = function() AH.ToggleRoleDeathAlert() end
SLASH_COMMANDS["/mroletest"] = function() AH.TestRoleDeathAlert() end
