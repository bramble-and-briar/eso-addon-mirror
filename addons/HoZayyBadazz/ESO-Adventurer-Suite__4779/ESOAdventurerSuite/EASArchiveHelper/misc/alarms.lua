local AH = _G.EASArchiveHelper
AH.Sounds = {
    Gw = {sound = _G.SOUNDS.BATTLEGROUND_ONE_MINUTE_WARNING, cycle = 1},
    Marauder = {sound = _G.SOUNDS.DUEL_START, cycle = 5},
    Terrain = {sound = _G.SOUNDS.DUEL_START, cycle = 1},
    Tomeshell = {sound = _G.SOUNDS.CHAMPION_POINTS_COMMITTED, cycle = 1},
}

AH.bosses = {}

local function isMarauder(name)
    local bossName = name:lower()

    for _, marauder in ipairs(AH.Marauders) do
        if (bossName:find(marauder, 1, true)) then
            return true
        end
    end

    return false
end

local function bossHandled(unitTag, name)
    if (AH.bosses[unitTag] == name) then
        return true
    end

    AH.bosses[unitTag] = name

    return false
end

function AH.OnNewBoss(_, unitTag)
    local check = AH.Vars.MarauderPlay or AH.Vars.MarauderCheck

    if (not check) then
        return
    end

    if (not IsInstanceEndlessDungeon() or ((unitTag or "") == "")) then
        return
    end

    local bossName = GetUnitName(unitTag)

    if (bossHandled(unitTag, bossName)) then
        return
    end

    if (isMarauder(bossName)) then
        if (AH.Vars.MarauderPlay) then
            AH.PlayAlarm(AH.Sounds.Marauder)
        end

        AH.MARAUDER = bossName
    end
end

function AH.PlayAlarm(sound)
    PlaySound(sound.sound)
    local count = 1

    if (sound.cycle > 1) then
        EVENT_MANAGER:RegisterForUpdate(
            AH.Name .. "_alarm",
            250,
            function()
                PlaySound(sound.sound)
                count = count + 1

                if (count == sound.cycle) then
                    EVENT_MANAGER:UnregisterForUpdate(AH.Name .. "_alarm")
                end
            end
        )
    end
end
