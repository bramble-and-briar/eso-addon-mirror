-- CallToArm_Status.lua
-- Pure campaign selection, freshness and population-status rules.
local CallToArm = _G.CallToArm or {}
_G.CallToArm = CallToArm
CallToArm.Status = CallToArm.Status or {}

local Status = CallToArm.Status

Status.SELECTION_MAX_AGE_SECONDS = 120

local POPULATION_MESSAGES = {
    advantage = {
        stable = {
            "{GuildAlliance} holds the population advantage in Cyrodiil",
            "{GuildAlliance} fields the stronger force",
        },
        improving = {
            "{GuildAlliance} gains the population advantage",
            "Reinforcements strengthen {GuildAlliance}",
        },
        worsening = {
            "{GuildAlliance} still leads, but enemy numbers are rising",
        },
    },
    quiet = {
        stable = {
            "Cyrodiil is quiet: alliance populations remain low",
            "Low activity across the selected campaign",
        },
        improving = {
            "{GuildAlliance} numbers begin to grow",
        },
        worsening = {
            "{GuildAlliance} presence is thinning in Cyrodiil",
        },
    },
    balanced = {
        stable = {
            "Campaign populations are evenly matched",
            "The selected campaign remains evenly contested",
        },
        improving = {
            "{GuildAlliance} draws level with the strongest enemy force",
        },
        worsening = {
            "Enemy numbers draw level with {GuildAlliance}",
        },
    },
    pressured = {
        stable = {
            "{GuildAlliance} is slightly outnumbered: reinforcements welcome",
            "Enemy numbers edge ahead of {GuildAlliance}",
        },
        improving = {
            "{GuildAlliance} closes the population gap",
        },
        worsening = {
            "Population pressure grows against {GuildAlliance}",
        },
    },
    outnumbered = {
        stable = {
            "{GuildAlliance} is heavily outnumbered: warriors needed",
            "Enemy population dominates the selected campaign",
        },
        improving = {
            "{GuildAlliance} remains outnumbered, but the gap is closing",
        },
        worsening = {
            "Enemy population advantage is growing: reinforcements needed",
        },
    },
    critical = {
        stable = {
            "{GuildAlliance} presence is critically low: answer the call",
            "The selected campaign urgently needs {GuildAlliance} reinforcements",
        },
        improving = {
            "{GuildAlliance} presence remains critical, but reinforcements are arriving",
        },
        worsening = {
            "{GuildAlliance} presence has fallen to a critical level",
        },
    },
}

function Status.ResolveCampaign(args)
    args = args or {}
    local gid = tonumber(args.guildId) or 0
    if args.lockActive == true and tonumber(args.lockedGuildId) == gid then
        return tonumber(args.lockedCampaignId) or 0
    end
    local configured = tonumber(args.configuredCampaignId) or 0
    if configured ~= 0 then return configured end
    return tonumber(args.assignedCampaignId) or 0
end

function Status.GetCampaignContextKey(selectedCampaignId, assignedCampaignId, currentCampaignId, inAvAWorld)
    local selected = tonumber(selectedCampaignId) or 0
    if selected == 0 then return nil end
    if selected == (tonumber(assignedCampaignId) or 0) then return "assigned" end
    if inAvAWorld == true and selected == (tonumber(currentCampaignId) or 0) then return "local" end
    return nil
end

function Status.ShouldRaiseThroneDefense(owned, total, threshold, lastOwned)
    owned = tonumber(owned)
    total = tonumber(total)
    threshold = tonumber(threshold)
    lastOwned = tonumber(lastOwned)
    if owned == nil or total == nil or total <= 0 or threshold == nil then return false end
    if owned > threshold then return false end
    if lastOwned ~= nil and lastOwned == owned then return false end
    return true
end

function Status.FormatCampaignRemaining(seconds)
    seconds = tonumber(seconds)
    if seconds == nil or seconds <= 0 then return nil end
    seconds = math.floor(seconds)
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainingSeconds = seconds % 60

    local function Unit(value, singular, plural)
        return tostring(value) .. " " .. (value == 1 and singular or plural)
    end

    if days > 0 then
        if hours > 0 then return Unit(days, "day", "days") .. " " .. Unit(hours, "hour", "hours") end
        return Unit(days, "day", "days")
    end
    if hours > 0 then
        if minutes > 0 then return Unit(hours, "hour", "hours") .. " " .. Unit(minutes, "minute", "minutes") end
        return Unit(hours, "hour", "hours")
    end
    if minutes > 0 then
        if remainingSeconds > 0 then return Unit(minutes, "minute", "minutes") .. " " .. Unit(remainingSeconds, "second", "seconds") end
        return Unit(minutes, "minute", "minutes")
    end
    return Unit(remainingSeconds, "second", "seconds")
end

function Status.IsSelectionDataFresh(now, receivedAt, requestSerial, readySerial, maxAge)
    now = tonumber(now) or 0
    receivedAt = tonumber(receivedAt) or 0
    requestSerial = tonumber(requestSerial) or 0
    readySerial = tonumber(readySerial) or -1
    maxAge = tonumber(maxAge) or Status.SELECTION_MAX_AGE_SECONDS
    if receivedAt <= 0 or requestSerial <= 0 or readySerial ~= requestSerial then return false end
    local age = now - receivedAt
    return age >= 0 and age <= maxAge
end

function Status.IsValidPopulationValue(value)
    local number = tonumber(value)
    if number == nil then return false end
    local minimum = tonumber(_G.CAMPAIGN_POP_NONE) or 0
    local maximum = tonumber(_G.CAMPAIGN_POP_FULL) or 4
    return number >= minimum and number <= maximum and number == math.floor(number)
end

function Status.ValidatePopulation(population)
    if type(population) ~= "table" then return false end
    for alliance = 1, 3 do
        if not Status.IsValidPopulationValue(population[alliance]) then return false end
    end
    return true
end

local function PopulationNumbers(population, guildAlliance)
    if not Status.ValidatePopulation(population) then return nil end
    guildAlliance = tonumber(guildAlliance) or 0
    if guildAlliance < 1 or guildAlliance > 3 then return nil end
    local own = tonumber(population[guildAlliance])
    local enemies = {}
    for alliance = 1, 3 do
        if alliance ~= guildAlliance then enemies[#enemies + 1] = tonumber(population[alliance]) end
    end
    return own, enemies[1], enemies[2]
end

function Status.CalculatePopulationState(population, guildAlliance, previous)
    local own, enemyOne, enemyTwo = PopulationNumbers(population, guildAlliance)
    if own == nil then return nil, "population-unavailable" end

    local enemyMax = math.max(enemyOne, enemyTwo)
    local enemyMin = math.min(enemyOne, enemyTwo)
    local margin = own - enemyMax
    local key

    if own == (_G.CAMPAIGN_POP_NONE or 0)
        and enemyMax >= (_G.CAMPAIGN_POP_HIGH or 3) then
        key = "critical"
    elseif margin <= -2 then
        key = "outnumbered"
    elseif margin == -1 then
        key = "pressured"
    elseif own <= (_G.CAMPAIGN_POP_LOW or 1)
        and enemyMax <= (_G.CAMPAIGN_POP_LOW or 1) then
        key = "quiet"
    elseif margin == 0 then
        key = "balanced"
    else
        key = "advantage"
    end

    local direction = "stable"
    if type(previous) == "table" and previous.own ~= nil and previous.enemyMax ~= nil then
        local previousMargin = tonumber(previous.own) - tonumber(previous.enemyMax)
        if margin > previousMargin then direction = "improving"
        elseif margin < previousMargin then direction = "worsening" end
    end

    return {
        key = key,
        direction = direction,
        own = own,
        enemyOne = enemyOne,
        enemyTwo = enemyTwo,
        enemyMax = enemyMax,
        enemyMin = enemyMin,
        margin = margin,
    }
end

function Status.SelectPopulationMessage(state, randomIndex)
    if type(state) ~= "table" then return nil end
    local bucket = POPULATION_MESSAGES[state.key]
    if not bucket then return nil end
    local list = bucket[state.direction] or bucket.stable
    if not list or #list == 0 then return nil end
    local index
    if type(randomIndex) == "function" then
        index = tonumber(randomIndex(#list))
    end
    if not index then index = math.random(1, #list) end
    if index < 1 or index > #list then index = 1 end
    return list[index]
end

function Status.GetPopulationMessages()
    return POPULATION_MESSAGES
end

