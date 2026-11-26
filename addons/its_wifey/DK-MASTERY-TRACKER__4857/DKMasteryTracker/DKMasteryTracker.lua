local D = {}
D.name = "DKMasteryTracker"
D.displayName = "DK Mastery Tracker"
D.version = "1.0.5"
local EM = EVENT_MANAGER

local IDS = {
    LANDSLIDE = 29465,
    BOOMING_TRIGGER = 263200,
    BOOMING_ACTIVE = 270020,
    WILDFIRE = 263208,
    RESOLUTE = 263230,
    MAJOR_PROTECTION = 61722,
    MAJOR_BERSERK = 61745,
}

-- Actual Dragonknight Class Mastery passive ability IDs. These IDs are used for
-- artwork only; proc/effect tracking continues to use the diagnosed IDs above.
local MASTERY_IDS = {
    landslide = 238232, -- Inexorable Descent
    booming   = 240268, -- Booming Voice
    wildfire  = 259224, -- Wildfire Embers
    resolute  = 263220, -- Resolute Defense
    lead      = 263247, -- Lead From the Front
}

local defaults = {
    enabled = true,
    locked = false,
    hideOOC = false,
    scale = 1.0,
    iconSize = 52,
    fontSize = 24,
    showNames = true,
    textColor = {1.0, 0.8235, 0.2745, 1.0},
    landslideUpColor = {0.20, 1.00, 0.20, 1.00},
    landslideDownColor = {1.00, 0.15, 0.15, 1.00},
    magmaEnabled = true,
    magmaBarWidth = 350,
    magmaBarHeight = 32,
    magmaBarX = 0,
    magmaBarY = -150,
    magmaCountdownX = 0,
    magmaCountdownY = -60,
    magmaCountdownSize = 72,
    magmaCountdownColor = {1,0,0,1},
    trackers = {
        landslide = { enabled=true, x=300, y=300 },
        booming   = { enabled=true, x=370, y=300 },
        wildfire  = { enabled=true, x=440, y=300 },
        resolute  = { enabled=true, x=510, y=300 },
        lead      = { enabled=true, x=580, y=300 },
    },
}

D.defs = {
    landslide = { label="Inexorable Descent", masteryId=MASTERY_IDS.landslide, kind="stack" },
    booming   = { label="Booming Voice", masteryId=MASTERY_IDS.booming, kind="booming" },
    wildfire  = { label="Wildfire Embers", masteryId=MASTERY_IDS.wildfire, kind="stacktimer" },
    resolute  = { label="Resolute Defense", masteryId=MASTERY_IDS.resolute, kind="stack" },
    lead      = { label="Lead From the Front", masteryId=MASTERY_IDS.lead, kind="timer" },
}

D.state = {}
D.controls = {}
D.leadArmedUntil = 0
D.previewGeneration = {}
D.masteryActive = {}
D.eventsRegistered = {}
D.hudFragment = nil
D.hudRoot = nil
local magmaBarWindow, magmaIcon, magmaBar, magmaLabel, magmaCountdownWindow, magmaCountdownLabel

local function now() return GetFrameTimeSeconds() end

local function setInactiveIcon(texture)
    if texture.SetDesaturation then texture:SetDesaturation(1) end
    texture:SetColor(1,1,1,1)
    texture:SetAlpha(0.38)
end

local function setActiveIcon(texture)
    if texture.SetDesaturation then texture:SetDesaturation(0) end
    texture:SetColor(1,1,1,1)
    texture:SetAlpha(1)
end

local function setPendingIcon(texture)
    -- Pending should read as a restrained yellow warning, not look more active
    -- than the actual full-color mastery state.
    if texture.SetDesaturation then texture:SetDesaturation(0.72) end
    texture:SetColor(1.00,0.88,0.45,1)
    texture:SetAlpha(0.72)
end

local function iconForMastery(id)
    local icon = GetAbilityIcon(id)
    if icon and icon ~= "" then return icon end
    return "/esoui/art/icons/icon_missing.dds"
end

local function savePosition(key)
    local c = D.controls[key]
    if not c then return end
    local left, top = c:GetLeft(), c:GetTop()
    if left and top then
        D.sv.trackers[key].x = left
        D.sv.trackers[key].y = top
    end
end

local function createTracker(key, def)
    local wm = WINDOW_MANAGER
    local c = wm:CreateTopLevelWindow("DKMT_"..key)
    c:SetHidden(true)
    c:SetDimensions(250,64)
    c:SetClampedToScreen(true)
    c:SetMouseEnabled(true)
    c:SetMovable(true)
    c:SetDrawLayer(DL_OVERLAY)
    c:SetHandler("OnMoveStop", function() savePosition(key) end)

    local iconHolder = wm:CreateControl(nil,c,CT_CONTROL)
    iconHolder:SetDimensions(64,64)
    iconHolder:SetAnchor(LEFT,c,LEFT,0,0)

    local tex = wm:CreateControl(nil,iconHolder,CT_TEXTURE)
    tex:SetAnchorFill(iconHolder)
    tex:SetTexture(iconForMastery(def.masteryId))
    -- Mastery textures already contain ESO's circular mastery presentation.
    -- Do not crop/mask them; that was what produced the rounded-square look.

    local main = wm:CreateControl(nil,iconHolder,CT_LABEL)
    main:SetAnchor(CENTER,iconHolder,CENTER,0,0)
    main:SetFont("ZoFontWinH1")
    main:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    main:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    main:SetColor(1,1,1,1)
    main:SetText("")

    local timer = wm:CreateControl(nil,iconHolder,CT_LABEL)
    timer:SetAnchor(BOTTOM,iconHolder,BOTTOM,0,-2)
    timer:SetFont("ZoFontGameSmall")
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetColor(1,1,1,1)
    timer:SetText("")

    local nameLabel = wm:CreateControl(nil,c,CT_LABEL)
    nameLabel:SetAnchor(LEFT,iconHolder,RIGHT,10,0)
    nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    nameLabel:SetText(def.label)

    c.iconHolder, c.icon, c.main, c.timer, c.nameLabel = iconHolder, tex, main, timer, nameLabel
    D.controls[key] = c
    D.state[key] = { active=false, stacks=0, endTime=0, direction="neutral", phase="inactive", preview=false }
end

local function refreshLayout()
    local size = D.sv.iconSize or 52
    local textSize = D.sv.fontSize or 24
    local gap = math.max(8, math.floor(size * 0.15))
    local nameWidth = math.max(260, textSize * 15)
    local rowHeight = math.max(size, math.ceil(textSize * 1.35))
    local tc = D.sv.textColor or defaults.textColor

    for key,c in pairs(D.controls) do
        local cfg = D.sv.trackers[key]
        c:ClearAnchors()
        c:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,cfg.x,cfg.y)
        c:SetScale(D.sv.scale)
        c:SetDimensions(D.sv.showNames and (size + gap + nameWidth) or size, rowHeight)

        c.iconHolder:SetDimensions(size,size)
        c.iconHolder:ClearAnchors()
        c.iconHolder:SetAnchor(LEFT,c,LEFT,0,0)

        c.main:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", math.max(14,math.floor(size*.48))))
        c.timer:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", math.max(12,math.floor(size*.23))))

        c.nameLabel:ClearAnchors()
        c.nameLabel:SetAnchor(LEFT,c.iconHolder,RIGHT,gap,0)
        c.nameLabel:SetDimensions(nameWidth,math.max(20,math.ceil(textSize*1.35)))
        c.nameLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick",textSize))
        c.nameLabel:SetColor(tc[1],tc[2],tc[3],tc[4])
        c.nameLabel:SetHidden(not D.sv.showNames)

        c:SetMovable(not D.sv.locked)
        c:SetMouseEnabled(not D.sv.locked)
    end
end

local function shouldShow(key)
    if IsUnitDead("player") then return false end
    if not D.sv.enabled or not D.sv.trackers[key].enabled then return false end
    -- A preview may temporarily show any tracker, but normal HUD display is limited
    -- to masteries the current character has actually purchased.
    if not D.state[key].preview and not D.masteryActive[key] then return false end
    if D.sv.hideOOC and not IsUnitInCombat("player") and not D.state[key].preview then return false end
    return true
end

local function refreshOne(key)
    local c, s, def = D.controls[key], D.state[key], D.defs[key]
    if not c then return end
    c:SetHidden(not shouldShow(key))
    if c:IsHidden() then return end

    c.main:SetText("")
    c.timer:SetText("")
    c.main:SetColor(1,1,1,1)

    if key == "booming" and s.phase == "pending" then
        setPendingIcon(c.icon)
        if s.endTime > 0 then c.main:SetText(tostring(math.max(0, math.ceil(s.endTime-now())))) end
    elseif s.active then
        setActiveIcon(c.icon)
        if def.kind == "stack" then
            if s.stacks > 0 then c.main:SetText(tostring(s.stacks)) end
            if key == "landslide" then
                local col = nil
                if s.direction == "up" then col = D.sv.landslideUpColor
                elseif s.direction == "down" then col = D.sv.landslideDownColor end
                if col then c.main:SetColor(col[1],col[2],col[3],col[4]) end
            end
        elseif def.kind == "timer" then
            if s.endTime > 0 then c.main:SetText(string.format("%.1f", math.max(0,s.endTime-now()))) end
        elseif def.kind == "stacktimer" then
            if s.stacks > 0 then c.main:SetText(tostring(s.stacks)) end
            if s.endTime > 0 then c.timer:SetText(string.format("%.1f", math.max(0,s.endTime-now()))) end
        elseif def.kind == "booming" then
            -- Active Booming Voice is intentionally color-only: no countdown.
        end
    else
        setInactiveIcon(c.icon)
    end
end

local function uiRefreshNeeded()
    if not D.sv or not D.sv.enabled then return false end
    for key, state in pairs(D.state) do
        if D.sv.trackers[key].enabled and (state.preview or (state.endTime or 0) > now() or state.phase == "pending") then
            return true
        end
    end
    return false
end

local function refreshAll()
    -- Booming Voice's 15-second pending phase is addon-timed. If the expected
    -- active effect never arrives, expire it here so the UI updater cannot run
    -- forever displaying 0.
    local t = now()
    local booming = D.state.booming
    if booming and not booming.preview and booming.phase == "pending" and (booming.endTime or 0) <= t then
        booming.phase = "inactive"
        booming.active = false
        booming.endTime = 0
    end

    -- Timed effects normally send EFFECT_RESULT_FADED, but also expire their
    -- local display state by endTime so a missed fade cannot leave stale UI or
    -- a periodic updater running indefinitely. Stack-only effects have endTime 0.
    for key, state in pairs(D.state) do
        local kind = D.defs[key] and D.defs[key].kind
        if not state.preview and state.active and (state.endTime or 0) > 0 and state.endTime <= t
           and (kind == "timer" or kind == "stacktimer" or kind == "booming") then
            state.active = false
            state.endTime = 0
            if kind == "stacktimer" then state.stacks = 0 end
            if kind == "booming" then state.phase = "inactive" end
        end
    end

    for key in pairs(D.controls) do refreshOne(key) end
    if not uiRefreshNeeded() then EM:UnregisterForUpdate(D.name.."_UI") end
end

local function updateUIRefreshRegistration()
    if uiRefreshNeeded() then
        EM:RegisterForUpdate(D.name.."_UI", 100, refreshAll)
    else
        EM:UnregisterForUpdate(D.name.."_UI")
    end
end

local function setState(key, active, stacks, endTime)
    local s = D.state[key]
    if not s then return end
    stacks = tonumber(stacks) or 0

    if key == "landslide" then
        local old = s.stacks or 0
        if active and old > 0 and stacks > old then s.direction = "up"
        elseif active and old > 0 and stacks < old then s.direction = "down"
        elseif active and old == 0 and stacks > 0 then s.direction = "up"
        elseif not active then s.direction = "neutral" end
    end

    s.active = active
    s.stacks = active and stacks or 0
    s.endTime = active and (tonumber(endTime) or 0) or 0
    if key == "booming" then s.phase = active and "active" or "inactive" end
    refreshOne(key)
    updateUIRefreshRegistration()
end

local function effectHandlerFor(key)
    return function(eventCode, changeType, effectSlot, effectName, unitTag,
                    beginTime, endTime, stackCount, iconName, buffType,
                    effectType, abilityType, statusEffectType, unitName,
                    unitId, abilityId, sourceType)
        if D.state[key].preview then return end
        local active = changeType ~= EFFECT_RESULT_FADED
        setState(key, active, stackCount, endTime)
    end
end

local function onBoomingTrigger(eventCode, result, isError, abilityName, abilityGraphic,
                                abilityActionSlotType, sourceName, sourceType, targetName,
                                targetType, hitValue, powerType, damageType, log, sourceUnitId,
                                targetUnitId, abilityId, overflow)
    local s = D.state.booming
    if s.preview then return end
    s.phase = "pending"
    s.active = false
    s.stacks = 0
    s.endTime = now() + 15
    refreshOne("booming")
    updateUIRefreshRegistration()
end

local function onBoomingActive(eventCode, changeType, effectSlot, effectName, unitTag,
                               beginTime, endTime, stackCount, iconName, buffType,
                               effectType, abilityType, statusEffectType, unitName,
                               unitId, abilityId, sourceType)
    local s = D.state.booming
    if s.preview then return end
    if changeType == EFFECT_RESULT_FADED then
        s.phase = "inactive"; s.active = false; s.endTime = 0
    else
        s.phase = "active"; s.active = true; s.endTime = tonumber(endTime) or 0
    end
    refreshOne("booming")
    updateUIRefreshRegistration()
end

local function onLeadEffect(eventCode, changeType, effectSlot, effectName, unitTag,
                            beginTime, endTime, stackCount, iconName, buffType,
                            effectType, abilityType, statusEffectType, unitName,
                            unitId, abilityId, sourceType)
    if D.state.lead.preview then return end
    local activeChange = changeType ~= EFFECT_RESULT_FADED
    if activeChange then
        if now() > D.leadArmedUntil then return end
        if abilityId == IDS.MAJOR_BERSERK then D.leadBerserkUntil = endTime or 0
        elseif abilityId == IDS.MAJOR_PROTECTION then D.leadProtectionUntil = endTime or 0 end
        local e = math.max(D.leadBerserkUntil or 0, D.leadProtectionUntil or 0)
        if e > now() then setState("lead", true, 0, e) end
    else
        if abilityId == IDS.MAJOR_BERSERK then D.leadBerserkUntil = 0 end
        if abilityId == IDS.MAJOR_PROTECTION then D.leadProtectionUntil = 0 end
        local e = math.max(D.leadBerserkUntil or 0, D.leadProtectionUntil or 0)
        if e <= now() then setState("lead", false, 0, 0) end
    end
end

local function onUltimateUsed(eventCode, slotNum)
    if slotNum == ACTION_BAR_ULTIMATE_SLOT_INDEX or slotNum == ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 then
        D.leadArmedUntil = now() + 1.5
        D.leadBerserkUntil = 0
        D.leadProtectionUntil = 0
    end
end

local updateTrackerEventRegistrations

local function refreshPurchasedMasteries()
    local found = {}
    for key in pairs(D.defs) do found[key] = false end

    for skillType = 1, GetNumSkillTypes() do
        for skillLineIndex = 1, GetNumSkillLines(skillType) do
            for skillIndex = 1, GetNumSkillAbilities(skillType, skillLineIndex) do
                local abilityName, _, _, _, _, purchased = GetSkillAbilityInfo(skillType, skillLineIndex, skillIndex)
                if purchased then
                    local abilityId = GetSkillAbilityId(skillType, skillLineIndex, skillIndex, false)
                    for key, def in pairs(D.defs) do
                        if abilityId == def.masteryId or abilityName == def.label then
                            found[key] = true
                        end
                    end
                end
            end
        end
    end

    for key in pairs(D.defs) do
        D.masteryActive[key] = found[key] == true
        if not D.masteryActive[key] and not D.state[key].preview then
            local st = D.state[key]
            st.active=false; st.stacks=0; st.endTime=0; st.direction="neutral"; st.phase="inactive"
        end
    end
    refreshAll()
    if D.sv then updateTrackerEventRegistrations() end
end

local function unregisterEvent(name, eventId)
    EM:UnregisterForEvent(name, eventId)
    D.eventsRegistered[name] = nil
end

local function registerEffect(name, id, handler, unitTag, playerSource)
    if D.eventsRegistered[name] then return end
    EM:RegisterForEvent(name, EVENT_EFFECT_CHANGED, handler)
    -- Keep all applicable filters in one Event Manager call so filtering happens
    -- in ESO's C-side event system before the Lua callback is invoked.
    if unitTag and playerSource then
        EM:AddFilterForEvent(name, EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_ABILITY_ID, id,
            REGISTER_FILTER_UNIT_TAG, unitTag,
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    elseif unitTag then
        EM:AddFilterForEvent(name, EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_ABILITY_ID, id,
            REGISTER_FILTER_UNIT_TAG, unitTag)
    elseif playerSource then
        EM:AddFilterForEvent(name, EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_ABILITY_ID, id,
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    else
        EM:AddFilterForEvent(name, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id)
    end
    D.eventsRegistered[name] = EVENT_EFFECT_CHANGED
end

local function trackerWanted(key)
    return D.sv.enabled and D.sv.trackers[key].enabled and D.masteryActive[key]
end

updateTrackerEventRegistrations = function()
    local specs = {
        landslide = { D.name.."_Landslide", IDS.LANDSLIDE, effectHandlerFor("landslide"), "player", true },
        booming   = { D.name.."_BoomingActive", IDS.BOOMING_ACTIVE, onBoomingActive, "player", true },
        wildfire  = { D.name.."_Wildfire", IDS.WILDFIRE, effectHandlerFor("wildfire"), nil, true },
        resolute  = { D.name.."_Resolute", IDS.RESOLUTE, effectHandlerFor("resolute"), "player", true },
        leadB     = { D.name.."_LeadBerserk", IDS.MAJOR_BERSERK, onLeadEffect, "player", true },
        leadP     = { D.name.."_LeadProtection", IDS.MAJOR_PROTECTION, onLeadEffect, "player", true },
    }

    local wanted = {
        landslide = trackerWanted("landslide"),
        booming = trackerWanted("booming"),
        wildfire = trackerWanted("wildfire"),
        resolute = trackerWanted("resolute"),
        leadB = trackerWanted("lead"),
        leadP = trackerWanted("lead"),
    }

    for key, spec in pairs(specs) do
        if wanted[key] then
            registerEffect(spec[1], spec[2], spec[3], spec[4], spec[5])
        else
            unregisterEvent(spec[1], EVENT_EFFECT_CHANGED)
        end
    end

    local boomingTrigger = D.name.."_BoomingTrigger"
    if trackerWanted("booming") then
        if not D.eventsRegistered[boomingTrigger] then
            EM:RegisterForEvent(boomingTrigger, EVENT_COMBAT_EVENT, onBoomingTrigger)
            EM:AddFilterForEvent(boomingTrigger, EVENT_COMBAT_EVENT,
                REGISTER_FILTER_ABILITY_ID, IDS.BOOMING_TRIGGER,
                REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
            D.eventsRegistered[boomingTrigger] = EVENT_COMBAT_EVENT
        end
    else
        unregisterEvent(boomingTrigger, EVENT_COMBAT_EVENT)
    end

    local ultimateEvent = D.name.."_Ultimate"
    if trackerWanted("lead") then
        if not D.eventsRegistered[ultimateEvent] then
            EM:RegisterForEvent(ultimateEvent, EVENT_ACTION_SLOT_ABILITY_USED, onUltimateUsed)
            D.eventsRegistered[ultimateEvent] = EVENT_ACTION_SLOT_ABILITY_USED
        end
    else
        unregisterEvent(ultimateEvent, EVENT_ACTION_SLOT_ABILITY_USED)
    end

    local combatEvent = D.name.."_CombatState"
    if D.sv.enabled and D.sv.hideOOC then
        if not D.eventsRegistered[combatEvent] then
            EM:RegisterForEvent(combatEvent, EVENT_PLAYER_COMBAT_STATE, refreshAll)
            D.eventsRegistered[combatEvent] = EVENT_PLAYER_COMBAT_STATE
        end
    else
        unregisterEvent(combatEvent, EVENT_PLAYER_COMBAT_STATE)
    end

end

local function setupHudFragment()
    if D.hudFragment or not SCENE_MANAGER or not HUD_SCENE or not HUD_UI_SCENE then return end
    if not D.hudRoot then
        D.hudRoot = WINDOW_MANAGER:CreateTopLevelWindow("DKMT_HUDRoot")
        D.hudRoot:SetDimensions(1,1)
        D.hudRoot:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
        D.hudRoot:SetMouseEnabled(false)
    end
    D.hudFragment = ZO_SimpleSceneFragment:New(D.hudRoot)
    HUD_SCENE:AddFragment(D.hudFragment)
    HUD_UI_SCENE:AddFragment(D.hudFragment)
end

local function updateCoreEventRegistrations()
    local specs = {
        { D.name.."_SkillsFull", EVENT_SKILLS_FULL_UPDATE, refreshPurchasedMasteries },
        { D.name.."_SkillPoints", EVENT_SKILL_POINTS_CHANGED, refreshPurchasedMasteries },
    }
    for _, spec in ipairs(specs) do
        local name, eventId, callback = spec[1], spec[2], spec[3]
        if D.sv.enabled then
            if not D.eventsRegistered[name] then
                EM:RegisterForEvent(name, eventId, callback)
                D.eventsRegistered[name] = eventId
            end
        else
            unregisterEvent(name, eventId)
        end
    end
end

local function registerPlayerActivatedOnce()
    local name = D.name.."_PlayerActivated"
    EM:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
        EM:UnregisterForEvent(name, EVENT_PLAYER_ACTIVATED)
        D.eventsRegistered[name] = nil
        setupHudFragment()
        if D.sv.enabled then refreshPurchasedMasteries() end
    end)
    D.eventsRegistered[name] = EVENT_PLAYER_ACTIVATED
end

local function resetPreview(key, generation)
    if D.previewGeneration[key] ~= generation then return end
    local s = D.state[key]
    s.preview=false; s.active=false; s.stacks=0; s.endTime=0; s.direction="neutral"; s.phase="inactive"
    refreshOne(key)
    updateUIRefreshRegistration()
end

local function preview(key)
    D.previewGeneration[key] = (D.previewGeneration[key] or 0) + 1
    local gen = D.previewGeneration[key]
    local s = D.state[key]
    s.preview = true
    s.direction = "neutral"

    if key == "landslide" then
        s.active=true; s.phase="active"; s.stacks=8; s.direction="up"
        refreshOne(key)
        zo_callLater(function()
            if D.previewGeneration[key] ~= gen then return end
            s.stacks=7; s.direction="down"; refreshOne(key)
        end, 1500)
        zo_callLater(function() resetPreview(key,gen) end, 3000)
    elseif key == "booming" then
        s.active=false; s.phase="pending"; s.endTime=now()+15
        refreshOne(key)
        zo_callLater(function()
            if D.previewGeneration[key] ~= gen then return end
            s.phase="active"; s.active=true; s.endTime=now()+10; refreshOne(key)
        end,15000)
        zo_callLater(function() resetPreview(key,gen) end,25000)
    elseif key == "wildfire" then
        s.active=true; s.phase="active"; s.stacks=7; s.endTime=now()+3
        refreshOne(key); zo_callLater(function() resetPreview(key,gen) end,3000)
    elseif key == "resolute" then
        s.active=true; s.phase="active"; s.stacks=5; s.endTime=0
        refreshOne(key); zo_callLater(function() resetPreview(key,gen) end,3000)
    elseif key == "lead" then
        s.active=true; s.phase="active"; s.endTime=now()+3
        refreshOne(key); zo_callLater(function() resetPreview(key,gen) end,3000)
    end
    updateUIRefreshRegistration()
end

-- Optional DK utility: proven Magma Armor / Magma Shell / Corrosive Armor tracker.
local MAGMA_ABILITIES = { [15957]=true, [17874]=true, [17878]=true }
local magma = { active=false, beginTime=0, endTime=0, abilityId=0, name="MAGMA SHELL", icon="", test=false }
local function hideMagma()
    if magmaBarWindow then magmaBarWindow:SetHidden(true) end
    if magmaCountdownWindow then magmaCountdownWindow:SetHidden(true) end
end


local function saveMagmaBarPosition()
    if not magmaBarWindow then return end
    local x,y=magmaBarWindow:GetCenter(); local rx,ry=GuiRoot:GetCenter()
    if x and y then D.sv.magmaBarX=x-rx; D.sv.magmaBarY=y-ry end
end
local function saveMagmaCountdownPosition()
    if not magmaCountdownWindow then return end
    local x,y=magmaCountdownWindow:GetCenter(); local rx,ry=GuiRoot:GetCenter()
    if x and y then D.sv.magmaCountdownX=x-rx; D.sv.magmaCountdownY=y-ry end
end

local function refreshMagmaLayout()
    if not magmaBarWindow then return end
    magmaBarWindow:SetDimensions(D.sv.magmaBarWidth + D.sv.magmaBarHeight + 6, D.sv.magmaBarHeight)
    magmaBarWindow:ClearAnchors(); magmaBarWindow:SetAnchor(CENTER,GuiRoot,CENTER,D.sv.magmaBarX,D.sv.magmaBarY)
    magmaIcon:SetDimensions(D.sv.magmaBarHeight,D.sv.magmaBarHeight)
    magmaBar:SetDimensions(D.sv.magmaBarWidth,D.sv.magmaBarHeight)
    magmaCountdownWindow:ClearAnchors(); magmaCountdownWindow:SetAnchor(CENTER,GuiRoot,CENTER,D.sv.magmaCountdownX,D.sv.magmaCountdownY)
    magmaCountdownLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick",D.sv.magmaCountdownSize))
    local c=D.sv.magmaCountdownColor; magmaCountdownLabel:SetColor(c[1],c[2],c[3],c[4])
    local movable=not D.sv.locked
    magmaBarWindow:SetMovable(movable); magmaBarWindow:SetMouseEnabled(movable)
    magmaCountdownWindow:SetMovable(movable); magmaCountdownWindow:SetMouseEnabled(movable)
end

local function createMagmaTracker()
    local wm=WINDOW_MANAGER
    magmaBarWindow=wm:CreateTopLevelWindow("DKMT_MagmaBar")
    magmaBarWindow:SetClampedToScreen(true); magmaBarWindow:SetHidden(true)
    magmaIcon=wm:CreateControl("DKMT_MagmaIcon",magmaBarWindow,CT_TEXTURE)
    magmaIcon:SetAnchor(LEFT,magmaBarWindow,LEFT,0,0); magmaIcon:SetTexture(GetAbilityIcon(17874))
    magmaBar=wm:CreateControl("DKMT_MagmaStatus",magmaBarWindow,CT_STATUSBAR)
    magmaBar:SetAnchor(LEFT,magmaIcon,RIGHT,6,0); magmaBar:SetMinMax(0,1); magmaBar:SetValue(1); magmaBar:SetColor(.85,.35,.05,.95)
    magmaLabel=wm:CreateControl("DKMT_MagmaLabel",magmaBar,CT_LABEL)
    magmaLabel:SetAnchorFill(magmaBar); magmaLabel:SetFont("$(BOLD_FONT)|20|soft-shadow-thick")
    magmaLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER); magmaLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    magmaCountdownWindow=wm:CreateTopLevelWindow("DKMT_MagmaCountdown")
    magmaCountdownWindow:SetDimensions(400,180); magmaCountdownWindow:SetClampedToScreen(true); magmaCountdownWindow:SetHidden(true)
    magmaCountdownLabel=wm:CreateControl("DKMT_MagmaCountdownLabel",magmaCountdownWindow,CT_LABEL)
    magmaCountdownLabel:SetAnchorFill(magmaCountdownWindow); magmaCountdownLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER); magmaCountdownLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    magmaBarWindow:SetHandler("OnMoveStop",saveMagmaBarPosition); magmaCountdownWindow:SetHandler("OnMoveStop",saveMagmaCountdownPosition)
    refreshMagmaLayout()
end

local updateMagma

local function startMagmaUpdate()
    EM:RegisterForUpdate(D.name.."_MagmaUI",50,function() updateMagma() end)
end

updateMagma = function()
    if not D.sv.enabled or not D.sv.magmaEnabled then hideMagma(); return end
    if not magma.active and not magma.test then hideMagma(); return end
    local t=now(); local remaining=magma.endTime-t
    if remaining<=0 then magma.active=false; magma.test=false; EM:UnregisterForUpdate(D.name.."_MagmaUI"); hideMagma(); return end
    local total=math.max(.001,magma.endTime-magma.beginTime)
    magmaBarWindow:SetHidden(false); magmaBar:SetValue(zo_clamp(remaining/total,0,1))
    local nm=magma.test and "MAGMA SHELL" or magma.name
    magmaLabel:SetText(string.format("%s  %.1f",nm,remaining))
    local ic=magma.test and GetAbilityIcon(17874) or magma.icon
    if ic and ic~="" then magmaIcon:SetTexture(ic) end
    if remaining<=5 then magmaCountdownWindow:SetHidden(false); magmaCountdownLabel:SetText(tostring(math.max(1,math.ceil(remaining))))
    else magmaCountdownWindow:SetHidden(true) end
end

local function onMagmaEffect(eventCode,changeType,effectSlot,effectName,unitTag,beginTime,endTime,stackCount,iconName,buffType,effectType,abilityType,statusEffectType,unitName,unitId,abilityId,sourceType)
    if changeType==EFFECT_RESULT_GAINED or changeType==EFFECT_RESULT_UPDATED then
        magma.active=true; magma.test=false; magma.beginTime=beginTime or now(); magma.endTime=endTime or magma.beginTime
        magma.abilityId=abilityId; magma.name=string.upper((effectName and effectName~="") and effectName or (GetAbilityName(abilityId) or "MAGMA")); magma.icon=(iconName and iconName~="") and iconName or GetAbilityIcon(abilityId)
        startMagmaUpdate()
    elseif changeType==EFFECT_RESULT_FADED and (magma.abilityId==0 or magma.abilityId==abilityId) then
        magma.active=false; EM:UnregisterForUpdate(D.name.."_MagmaUI"); hideMagma()
    end
end

local function testMagma()
    if not D.sv.enabled or not D.sv.magmaEnabled then return end
    magma.test=true; magma.active=false; magma.beginTime=now(); magma.endTime=magma.beginTime+15; magma.name="MAGMA SHELL"; magma.icon=GetAbilityIcon(17874); startMagmaUpdate()
end

local function unregisterMagma()
    for abilityId in pairs(MAGMA_ABILITIES) do
        local n=D.name.."_Magma_"..abilityId
        EM:UnregisterForEvent(n,EVENT_EFFECT_CHANGED)
        D.eventsRegistered[n]=nil
    end
    EM:UnregisterForUpdate(D.name.."_MagmaUI")
    magma.active=false; magma.test=false; hideMagma()
end

local function updateMagmaRegistration()
    if not D.sv.enabled or not D.sv.magmaEnabled then
        unregisterMagma()
        return
    end
    for abilityId in pairs(MAGMA_ABILITIES) do
        local n=D.name.."_Magma_"..abilityId
        if not D.eventsRegistered[n] then
            EM:RegisterForEvent(n,EVENT_EFFECT_CHANGED,onMagmaEffect)
            EM:AddFilterForEvent(n, EVENT_EFFECT_CHANGED,
                REGISTER_FILTER_ABILITY_ID, abilityId,
                REGISTER_FILTER_UNIT_TAG, "player",
                REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
            D.eventsRegistered[n]=EVENT_EFFECT_CHANGED
        end
    end
end

local function setupLAM()
    local LAM = LibAddonMenu2

    -- Match HealingMeter's known-good LAM panel registration structure exactly.
    local ADDON_NAME = D.name
    local DISPLAY_NAME = D.displayName
    local VERSION = D.version
    local panel = ADDON_NAME .. "Options"

    -- ESO native Dragonknight class emblem. Using the built-in texture avoids
    -- custom DDS loading issues while showing the actual DK class icon.
    local panelIcon = "/esoui/art/icons/class/class_dragonknight.dds"
    local panelDisplayName = DISPLAY_NAME
    if panelIcon and panelIcon ~= "" then
        panelDisplayName = DISPLAY_NAME .. " |t22:22:" .. panelIcon .. "|t"
    end

    LAM:RegisterAddonPanel(panel, {
        type = "panel",
        name = panelDisplayName,
        displayName = panelDisplayName,
        author = "WifeyRytic",
        version = VERSION,
        registerForRefresh = true,
        registerForDefaults = true,
    })
    local opts = {
        {type="checkbox", name="Enable addon", getFunc=function() return D.sv.enabled end,
            setFunc=function(v) D.sv.enabled=v; updateCoreEventRegistrations(); if v then refreshPurchasedMasteries() else updateTrackerEventRegistrations() end; updateMagmaRegistration(); updateUIRefreshRegistration(); refreshAll() end, default=defaults.enabled},
        {type="checkbox", name="Lock trackers", getFunc=function() return D.sv.locked end,
            setFunc=function(v) D.sv.locked=v; refreshLayout() end, default=defaults.locked},
        {type="checkbox", name="Hide out of combat", getFunc=function() return D.sv.hideOOC end,
            setFunc=function(v) D.sv.hideOOC=v; updateTrackerEventRegistrations(); refreshAll() end, default=defaults.hideOOC},
        {type="checkbox", name="Show mastery names beside icons", getFunc=function() return D.sv.showNames end,
            setFunc=function(v) D.sv.showNames=v; refreshLayout(); refreshAll() end, default=defaults.showNames},
        {type="slider", name="Icon Size", min=28, max=100, step=1,
            getFunc=function() return D.sv.iconSize end,
            setFunc=function(v) D.sv.iconSize=v; refreshLayout() end, default=defaults.iconSize},
        {type="slider", name="Mastery Text Size", min=12, max=40, step=1,
            getFunc=function() return D.sv.fontSize end,
            setFunc=function(v) D.sv.fontSize=v; refreshLayout() end, default=defaults.fontSize},
        {type="colorpicker", name="Mastery Name Color",
            getFunc=function() local c=D.sv.textColor; return c[1],c[2],c[3],c[4] end,
            setFunc=function(r,g,b,a) D.sv.textColor={r,g,b,a}; refreshLayout() end,
            default={unpack(defaults.textColor)}},
        {type="slider", name="Tracker size", min=60, max=160, step=5,
            getFunc=function() return math.floor(D.sv.scale*100+0.5) end,
            setFunc=function(v) D.sv.scale=v/100; refreshLayout() end, default=100},
        {type="header",name="Inexorable Descent stack colors"},
        {type="colorpicker",name="Increasing stacks color",
            getFunc=function() local c=D.sv.landslideUpColor; return c[1],c[2],c[3],c[4] end,
            setFunc=function(r,g,b,a) D.sv.landslideUpColor={r,g,b,a}; refreshOne("landslide") end,
            default={unpack(defaults.landslideUpColor)}},
        {type="colorpicker",name="Decreasing stacks color",
            getFunc=function() local c=D.sv.landslideDownColor; return c[1],c[2],c[3],c[4] end,
            setFunc=function(r,g,b,a) D.sv.landslideDownColor={r,g,b,a}; refreshOne("landslide") end,
            default={unpack(defaults.landslideDownColor)}},
    }
    local order={"landslide","booming","wildfire","resolute","lead"}
    for _,key in ipairs(order) do
        local def=D.defs[key]
        table.insert(opts,{type="header",name=def.label})
        table.insert(opts,{type="checkbox",name="Show "..def.label,
            getFunc=function() return D.sv.trackers[key].enabled end,
            setFunc=function(v) D.sv.trackers[key].enabled=v; updateTrackerEventRegistrations(); updateUIRefreshRegistration(); refreshOne(key) end, default=true})
        table.insert(opts,{type="button",name="Test / Preview",func=function() preview(key) end,width="half"})
    end
    table.insert(opts,{type="header",name="Magma Shell Utility"})
    table.insert(opts,{type="checkbox",name="Enable Magma Shell tracker",getFunc=function() return D.sv.magmaEnabled end,
        setFunc=function(v) D.sv.magmaEnabled=v; updateMagmaRegistration() end,default=defaults.magmaEnabled})
    table.insert(opts,{type="slider",name="Magma bar width",min=200,max=600,step=10,getFunc=function() return D.sv.magmaBarWidth end,
        setFunc=function(v) D.sv.magmaBarWidth=v; refreshMagmaLayout() end,default=defaults.magmaBarWidth})
    table.insert(opts,{type="slider",name="Magma bar height",min=24,max=60,step=2,getFunc=function() return D.sv.magmaBarHeight end,
        setFunc=function(v) D.sv.magmaBarHeight=v; refreshMagmaLayout() end,default=defaults.magmaBarHeight})
    table.insert(opts,{type="slider",name="Magma final countdown size",min=36,max=120,step=2,getFunc=function() return D.sv.magmaCountdownSize end,
        setFunc=function(v) D.sv.magmaCountdownSize=v; refreshMagmaLayout() end,default=defaults.magmaCountdownSize})
    table.insert(opts,{type="colorpicker",name="Magma final countdown color",getFunc=function() local c=D.sv.magmaCountdownColor; return c[1],c[2],c[3],c[4] end,
        setFunc=function(r,g,b,a) D.sv.magmaCountdownColor={r,g,b,a}; refreshMagmaLayout() end,default={1,0,0,1}})
    table.insert(opts,{type="button",name="Test Magma Shell Tracker",func=testMagma,width="half"})
    LAM:RegisterOptionControls(panel, opts)
end

local function initialize()
    -- These SavedVariables are UI/preferences only, so keeping the original
    -- account-wide structure preserves existing users' settings across updates.
    D.sv = ZO_SavedVars:NewAccountWide("DKMasteryTrackerSavedVariables", 1, nil, defaults)
    -- Migrate v0.1 saved vars by filling new color settings if needed.
    if D.sv.iconSize == nil then D.sv.iconSize=defaults.iconSize end
    if D.sv.fontSize == nil then D.sv.fontSize=defaults.fontSize end
    if D.sv.textColor == nil then D.sv.textColor={unpack(defaults.textColor)} end
    if D.sv.showNames == nil then D.sv.showNames=true end
    if not D.sv.landslideUpColor then D.sv.landslideUpColor={unpack(defaults.landslideUpColor)} end
    if not D.sv.landslideDownColor then D.sv.landslideDownColor={unpack(defaults.landslideDownColor)} end
    if D.sv.magmaEnabled==nil then D.sv.magmaEnabled=defaults.magmaEnabled end
    if not D.sv.magmaCountdownColor then D.sv.magmaCountdownColor={unpack(defaults.magmaCountdownColor)} end
    for key,def in pairs(D.defs) do createTracker(key,def) end
    createMagmaTracker()
    refreshLayout()
    setupLAM()
    updateCoreEventRegistrations()
    registerPlayerActivatedOnce()
    if D.sv.enabled then refreshPurchasedMasteries() end
    updateMagmaRegistration()
end

local function onLoaded(eventCode, addonName)
    if addonName ~= D.name then return end
    EM:UnregisterForEvent(D.name, EVENT_ADD_ON_LOADED)
    initialize()
end
EM:RegisterForEvent(D.name, EVENT_ADD_ON_LOADED, onLoaded)
