local ONEUP = {
    name = "0NEUP",
    lastAlertTime = {},
    bombAttackers = {},
    bombWindowStart = 0,
}

_G["0NEUP"] = ONEUP

local ALERT_COOLDOWN = 3000 -- 3 seconds between duplicate alerts
local STACK_DISTANCE_METERS = 8
local BOMB_ENEMY_THRESHOLD = 4 -- Number of enemies hitting group within 2s to trigger Defense!

-- Enemy ability name matching (covers all morphs and ranks)
local ENEMY_ABILITY_ALERTS = {
    ["Negate Magic"]       = { text = "BAD NEGATE!",        color = "FF3333" },
    ["Suppression Field"]  = { text = "BAD NEGATE!",        color = "FF3333" },
    ["Absorption Field"]   = { text = "BAD NEGATE!",        color = "FF3333" },
    ["Eye of the Storm"]   = { text = "EYE OF THE STORM!",  color = "AA44FF" },
    ["Fiery Rage"]         = { text = "EYE OF THE STORM!",  color = "AA44FF" },
    ["Icy Rage"]           = { text = "EYE OF THE STORM!",  color = "AA44FF" },
    ["Thunderous Rage"]    = { text = "EYE OF THE STORM!",  color = "AA44FF" },
    ["Corrosive Armor"]    = { text = "CORROSIVE!",         color = "FF8800" },
    ["Mechanical Acuity"]  = { text = "MECHANICAL ACUITY!", color = "FFCC00" },
}

-- Siege keywords to catch all enemy siege types
local SIEGE_KEYWORDS = {
    "Ballista", "Trebuchet", "Catapult", "Flaming Oil", "Meatbag", "Scattershot", "Cold Fire"
}

-- Create the center-screen alert text UI
function ONEUP.CreateUI()
    local tlw = WINDOW_MANAGER:CreateTopLevelWindow("ONEUPWindow")
    tlw:SetDimensions(800, 120)
    tlw:SetAnchor(CENTER, GuiRoot, CENTER, 0, -140)
    tlw:SetMouseEnabled(false)
    tlw:SetMovable(false)

    local label = WINDOW_MANAGER:CreateControl("ONEUPLabel", tlw, CT_LABEL)
    label:SetAnchor(CENTER, tlw, CENTER, 0, 0)
    label:SetFont("$(BOLD_FONT)|42|thick-outline")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetText("")
    label:SetAlpha(0)

    ONEUP.label = label
end

-- Show center-screen pop-up text with a fade out
function ONEUP.ShowAlert(message, hexColor, soundId)
    local now = GetGameTimeMilliseconds()
    if ONEUP.lastAlertTime[message] and (now - ONEUP.lastAlertTime[message] < ALERT_COOLDOWN) then
        return
    end
    ONEUP.lastAlertTime[message] = now

    ONEUP.label:SetText(string.format("|c%s%s|r", hexColor or "FFFFFF", message))
    ONEUP.label:SetAlpha(1)

    if soundId then
        PlaySound(soundId)
    end

    EVENT_MANAGER:UnregisterForUpdate(ONEUP.name .. "_Fade")
    EVENT_MANAGER:RegisterForUpdate(ONEUP.name .. "_Fade", 2200, function()
        ONEUP.label:SetAlpha(0)
        EVENT_MANAGER:UnregisterForUpdate(ONEUP.name .. "_Fade")
    end)
end

-- Set a large Gold Crown on the group leader for any group size
function ONEUP.ApplyGoldCrown()
    SetFloatingMarkerInfo(MAP_PIN_TYPE_GROUP_LEADER, 64, "EsoUI/Art/Compass/groupLeader.dds")
end

-- Check distance between player and group leader (8 meters)
function ONEUP.CheckGroupStack()
    if not IsUnitGrouped("player") or not IsUnitInCombat("player") then return end
    if IsUnitDead("player") then return end

    local leaderTag = GetGroupLeaderUnitTag()
    if not leaderTag or leaderTag == "" or AreUnitsEqual("player", leaderTag) then return end
    if not IsUnitOnline(leaderTag) or IsUnitDead(leaderTag) then return end

    local pZone, pX, pY, pZ = GetUnitWorldPosition("player")
    local lZone, lX, lY, lZ = GetUnitWorldPosition(leaderTag)

    if pZone ~= lZone then return end

    -- ESO world units are in centimeters; divide by 100 for meters
    local distMeters = zo_sqrt((pX - lX)^2 + (pY - lY)^2 + (pZ - lZ)^2) / 100

    if distMeters > STACK_DISTANCE_METERS then
        ONEUP.ShowAlert("STACK! (" .. math.floor(distMeters) .. "m)", "00FFFF", SOUNDS.ACTIVE_SKILL_READY)
    end
end

-- Monitor combat events for enemy skills, siege, and bomb groups
function ONEUP.OnCombatEvent(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
    if sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_GROUP or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET then
        return
    end

    -- 1. Check specific enemy ultimate/set alerts
    local alertData = ENEMY_ABILITY_ALERTS[abilityName]
    if alertData then
        ONEUP.ShowAlert(alertData.text, alertData.color, SOUNDS.NEW_NOTIFICATION)
        return
    end

    -- 2. Check Enemy Siege hits/casts
    for _, keyword in ipairs(SIEGE_KEYWORDS) do
        if string.find(abilityName, keyword, 1, true) then
            ONEUP.ShowAlert("ENEMY SIEGE!", "FF5500", SOUNDS.NEW_NOTIFICATION)
            return
        end
    end

    -- 3. Detect Bomb Group push (4+ distinct enemy players damaging your group within 2 seconds)
    if (targetType == COMBAT_UNIT_TYPE_PLAYER or targetType == COMBAT_UNIT_TYPE_GROUP) and hitValue > 0 then
        local now = GetGameTimeMilliseconds()
        if (now - ONEUP.bombWindowStart) > 2000 then
            ONEUP.bombWindowStart = now
            ONEUP.bombAttackers = {}
        end

        if sourceUnitId and sourceUnitId > 0 then
            ONEUP.bombAttackers[sourceUnitId] = true
            local attackerCount = 0
            for _ in pairs(ONEUP.bombAttackers) do
                attackerCount = attackerCount + 1
            end

            if attackerCount >= BOMB_ENEMY_THRESHOLD then
                ONEUP.ShowAlert("DEFENSE!", "FF0066", SOUNDS.DUEL_START)
                ONEUP.bombAttackers = {}
            end
        end
    end
end

function ONEUP.OnAddOnLoaded(event, addonName)
    if addonName ~= ONEUP.name then return end
    EVENT_MANAGER:UnregisterForEvent(ONEUP.name, EVENT_ADD_ON_LOADED)

    ONEUP.CreateUI()
    ONEUP.ApplyGoldCrown()

    -- Register combat listener
    EVENT_MANAGER:RegisterForEvent(ONEUP.name, EVENT_COMBAT_EVENT, ONEUP.OnCombatEvent)

    -- Check group stack distance every 1 second
    EVENT_MANAGER:RegisterForUpdate(ONEUP.name .. "_StackCheck", 1000, ONEUP.CheckGroupStack)

    -- Re-apply gold crown whenever group roster updates
    EVENT_MANAGER:RegisterForEvent(ONEUP.name, EVENT_GROUP_UPDATE, ONEUP.ApplyGoldCrown)
    EVENT_MANAGER:RegisterForEvent(ONEUP.name, EVENT_LEADER_UPDATE, ONEUP.ApplyGoldCrown)

    -- Slash command to test alerts on screen (/0neup)
    SLASH_COMMANDS["/0neup"] = function()
        ONEUP.ShowAlert("BAD NEGATE!", "FF3333", SOUNDS.NEW_NOTIFICATION)
        d("|cFFD700[0NEUP]|r Test alert triggered! Gold Crown active.")
    end
end

EVENT_MANAGER:RegisterForEvent(ONEUP.name, EVENT_ADD_ON_LOADED, ONEUP.OnAddOnLoaded)
