ICT = ICT or {}
ICT.name = "ICNextBossTelVar"
ICT.version = "1.6.4-console"

-- PSN whitelist. On PlayStation ESO exposes the platform account display name
-- using GetDisplayName(). Never substitute a character name or another identity.
-- This client-side restriction is not tamper-resistant.
ICT.allowedPSN = {
    ["jh20405270"] = true,
    ["xnoxreason"] = true,
}

function ICT.IsAuthorizedPSN()
    if type(GetDisplayName) ~= "function" then return false end
    local name = GetDisplayName()
    if type(name) ~= "string" or name == "" then return false end
    -- The decorated account display name may have a leading '@'.
    local canonical = name:gsub("^@", ""):lower()
    return ICT.allowedPSN[canonical] == true
end

ICT.running = false
ICT.spawntime = 900 --Respawn after 15 minutes
ICT.fallbackMaxTime = 60
ICT.damageWindow = 120 -- Maximum seconds between personal damage and confirmed death.
ICT.personalHits = {}

-- A district starts unknown. "ready" requires a living boss observed via the reticle.
-- An expired countdown from a confirmed death yields estimated "ready".
-- Unknown remains the default without any verified evidence.
ICT.confirmedAlive = {}
ICT.bossObservedAlive = {}
ICT.aliveTTL = 45 -- A recent observation expires; never claim permanent readiness.
ICT.bossToId = {}
ICT.idToBoss = {}
ICT.lastBroadcast = {}

function ICT.resetBossObservations()
    for district in pairs(ICT.timetable) do
        ICT.timetable[district] = 0
        ICT.confirmedAlive[district] = nil
    end
    for boss in pairs(ICT.fallbackTimes) do
        ICT.fallbackTimes[boss] = 0
    end
    ICT.bossObservedAlive = {}
    ICT.lastBroadcast = {}
    ICT.personalHits = {}
end

-- Persist only absolute respawn timestamps. UI countdowns are derived from wall time,
-- so leaving IC, loading screens and relogs never pause the countdown.
function ICT.persistBossTimers()
    if not ICT.savedVariables then return end
    local stored = ICT.savedVariables.bossRespawnTimes
    if type(stored) ~= "table" then
        stored = {}
        ICT.savedVariables.bossRespawnTimes = stored
    end
    for district, untilTime in pairs(ICT.timetable) do
        stored[district] = untilTime > 0 and untilTime or nil
    end
end

function ICT.restoreBossTimers()
    local stored = ICT.savedVariables and ICT.savedVariables.bossRespawnTimes
    if type(stored) ~= "table" then return end
    for district in pairs(ICT.timetable) do
        local value = tonumber(stored[district]) or 0
        ICT.timetable[district] = value > 0 and value or 0
    end
end

function ICT.resetTransientObservations()
    for boss in pairs(ICT.fallbackTimes) do
        ICT.fallbackTimes[boss] = 0
    end
    ICT.bossObservedAlive = {}
    ICT.confirmedAlive = {}
    ICT.lastBroadcast = {}
    ICT.personalHits = {}
end

function ICT.resetStoredBossTimers()
    for district in pairs(ICT.timetable) do
        ICT.timetable[district] = 0
    end
    ICT.resetTransientObservations()
    ICT.persistBossTimers()
    ICT.updateTimers()
end

-- Original ICTheNextBoss recognition: any reported named boss death starts a timer.
-- A reticle corpse alone never starts a timer: fallback needs a prior living sighting.
function ICT.recordBossDeath(name, source)
    local district = ICT.locations[name]
    if not district or not ICT.running then return end
    local now = os.time()
    if (ICT.timetable[district] or 0) > now then return end -- duplicate corpse
    ICT.confirmedAlive[district] = nil
    ICT.timetable[district] = now + ICT.spawntime
    ICT.persistBossTimers()
    ICT.fallbackTimes[name] = 0
    if ICT.savedVariables.chatdebug then d(name .. " death observed (" .. source .. ").") end
    ICT.updateTimers()
end

function ICT.updateTimers()
    for boss, remaining in pairs(ICT.fallbackTimes) do
        if remaining > 0 then
            ICT.fallbackTimes[boss] = remaining - 1
        end
    end

    local now = os.time()
    local districts, timers, flags = {}, {}, {}
    for district, respawn in pairs(ICT.timetable) do
        local color, display
        if respawn > os.time() then
            color = "|cFF5555"
            display = ICT.secondsToClock(respawn - os.time())
        elseif (respawn > 0 and respawn <= now) or
               (ICT.confirmedAlive[district] and ICT.confirmedAlive[district] > now) then
            -- "ready" after an observed, personally qualified death means
            -- estimated respawn availability, not a server-confirmed spawn.
            color = "|c00FF00"
            display = "ready"
        else
            -- Neither a qualified death nor a recent living-boss sighting.
            color = "|cFFD700"
            display = "unknown"
        end
        -- Keep the district name white when its boss status is unknown;
        -- the status text itself remains yellow for quick visual distinction.
        local districtColor = (display == "unknown") and "|cFFFFFF" or color
        districts[#districts + 1] = districtColor .. district .. "|r"
        timers[#timers + 1] = color .. display .. "|r"
        if ICT.savedVariables.showICFlags then flags[#flags + 1] = ICT.getFlagText(district) end
        if ICT.savedVariables.maptimers and ICT.ui.districts[district] then
            ICT.ui.districts[district]:SetText(color .. display .. "|r")
        end
    end
    if ICT.savedVariables.timetable then
        ICTDistricLabel:SetText(table.concat(districts, "\n"))
        ICTTimerLabel:SetText(table.concat(timers, "\n"))
        ICTFlagLabel:SetHidden(not ICT.savedVariables.showICFlags)
        ICTFlagLabel:SetText(table.concat(flags, "\n"))
    end
end

function ICT.onMonsterDeath(_, unitTag, isDead)
    if not isDead or not unitTag then return end
    local name = GetUnitName(unitTag)
    if name and ICT.locations[name] then ICT.recordBossDeath(name, "death event") end
end

function ICT.onMonsterReticle(_)
    -- Use the highlighted unit name as in the original addon.
    local name = GetUnitNameHighlightedByReticle()
    if not name or name == "" or not ICT.locations[name] then return end
    local dead = IsUnitDead("reticleover")
    if dead then
        if (ICT.fallbackTimes[name] or 0) > 0 then
            ICT.recordBossDeath(name, "live-to-dead reticle")
        end
    else
        ICT.fallbackTimes[name] = ICT.fallbackMaxTime
        ICT.observeLivingBoss(name, false)
    end
end

-- Panel visibility is independent from the IC-only boss event listeners.
function ICT.refreshPanelVisibility()
    if not ICT.savedVariables or not ICT.ui or not ICT.ui.timetable then return end
    local visible = ICT.savedVariables.timetable == true and
        (ICT.running == true or ICT.savedVariables.showTimersEverywhere == true)
    if visible then
        HUD_SCENE:AddFragment(ICT.ui.timetable)
        HUD_UI_SCENE:AddFragment(ICT.ui.timetable)
        ICTTimeTable:SetHidden(false)
        ICT.updateTimers()
    else
        ICTTimeTable:SetHidden(true)
        HUD_SCENE:RemoveFragment(ICT.ui.timetable)
        HUD_UI_SCENE:RemoveFragment(ICT.ui.timetable)
    end
end

function ICT.onZoneChange(_, _)
    local zone = GetUnitWorldPosition("player")
    local inIC = zone == 584 or zone == 643
    if inIC and not ICT.running then
        ICT.resetTransientObservations()
        ICT.running = true
        ICT.refreshFlagOwnership()
        EVENT_MANAGER:RegisterForEvent(ICT.name .. "_flag", EVENT_KEEP_ALLIANCE_OWNER_CHANGED, ICT.onFlagOwnershipChanged)
        EVENT_MANAGER:RegisterForEvent(ICT.name .. "_flagattack", EVENT_KEEP_UNDER_ATTACK_CHANGED, ICT.onFlagUnderAttackChanged)
        EVENT_MANAGER:RegisterForEvent(ICT.name .. "_death", EVENT_UNIT_DEATH_STATE_CHANGED, ICT.onMonsterDeath)
        EVENT_MANAGER:RegisterForEvent(ICT.name, EVENT_RETICLE_TARGET_CHANGED, ICT.onMonsterReticle)
        ICT.configurePanelDimensions()
    elseif not inIC and ICT.running then
        EVENT_MANAGER:UnregisterForEvent(ICT.name .. "_death", EVENT_UNIT_DEATH_STATE_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(ICT.name, EVENT_RETICLE_TARGET_CHANGED)
        ICT.running = false
        ICT.icFlagOwners = {}
        ICT.icFlagUnderAttack = {}
        ICT.icFlagDistrictByKeep = {}
        EVENT_MANAGER:UnregisterForEvent(ICT.name .. "_flag", EVENT_KEEP_ALLIANCE_OWNER_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(ICT.name .. "_flagattack", EVENT_KEEP_UNDER_ATTACK_CHANGED)
        ICT.resetTransientObservations()
    end
    ICT.refreshPanelVisibility()
end

function ICT.HandleClickEvent(rawLink, mouseButton, linkText, linkStyle, linkType, data)
	if linkType == "icdebug" then
		CHAT_SYSTEM.textEntry:Open(data)
		return true
	end
end

function ICT.OnAddOnLoaded(event, addonName)
	if addonName ~= ICT.name then return end
    EVENT_MANAGER:UnregisterForEvent(ICT.name, EVENT_ADD_ON_LOADED)
    if not ICT.IsAuthorizedPSN() then
        ICT.running = false
        -- Do not register boss, settings or bank event handlers.
        -- Hide precreated interface controls in case XML instantiated them.
        if ICTTimeTable then ICTTimeTable:SetHidden(true) end
        if ICTMapTimers then ICTMapTimers:SetHidden(true) end
        if d then d("IC Next Boss + Tel Var: PSN nicht freigegeben.") end
        return
    end
	
	EVENT_MANAGER:RegisterForEvent(ICT.name, EVENT_PLAYER_ACTIVATED, ICT.onZoneChange)
    -- Maintain live second-by-second display even when outside Imperial City.
    EVENT_MANAGER:RegisterForUpdate(ICT.name .. "_loop", 1000, ICT.updateTimers)
	
	LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, ICT.HandleClickEvent)
	LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_CLICKED_EVENT, ICT.HandleClickEvent)
	
	ICT.initializeSettingsMenu()
    ICT.restoreBossTimers()
    ICT.applyPanelScale()
    ICT.initializeGroupBroadcast()
    ICT.setPanelMover(ICT.savedVariables.panelMover)
	if IsKeyboardUISupported() then ICT.onMapOpen() end
	if IsKeyboardUISupported() then ICT.disableMapMouseWheelZoom() end
	ICTMapTimers:SetDrawTier(DT_HIGH) --Draw above WorldMap
	
	ICT.running = false
	ICT.RegisterTelVarBanking()
end

EVENT_MANAGER:RegisterForEvent(ICT.name, EVENT_ADD_ON_LOADED, ICT.OnAddOnLoaded)