local EM = EVENT_MANAGER





-- LCK may be installed but never fire EVENT_INITIALIZED (broken install,
-- version mismatch). Give up waiting after this many ticks and start anyway
-- rather than polling forever.
local MAX_DELAYED_START_TRIES = 40   -- 40 x 500ms = 20s

function FrankGrinder:DelayedStart()
    local LCK = LibCharacterKnowledge
    local ready = (not LCK) or (self._lckIsLoaded == true)

    if not ready then
        self._delayedStartTries = (self._delayedStartTries or 0) + 1
        if self._delayedStartTries < MAX_DELAYED_START_TRIES then
            return
        end
        self:ChatMsg("LibCharacterKnowledge did not initialise - starting without it.")
    end

    EM:UnregisterForUpdate(self.name .. ".DelayedStart")

    -- Clear any ElmsMarkers entries left over from a crash or hard exit
    self:RemoveZoneTrackMarkersFromElms()

    self:InitializeLeadWarning()

    self:InitializeGroupFinderNotifications()

    if self:GetSettingOverridePAKnown() then
        self:PA_Install()
    end

    self:InitializeLeadWarningHook()

    self:InitializeMailer()

    self:InitializeNightMarket()
    
    self:OnStart()
end

function FrankGrinder:Initialize(eventCode, addonName)
    if addonName ~= self.name then return end
    EM:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)

    if FrankGrinder.A() then
        ZO_CreateStringId("SI_BINDING_NAME_FRANKGRINDER_TOGGLE", GetString(GG_SHOW_WINDOW))
        ZO_CreateStringId("SI_BINDING_NAME_FRANKGRINDER_TOGGLEZONE", GetString(GG_TOGGLE_LOCATION_TRACKER))
        ZO_CreateStringId("SI_BINDING_NAME_FRANKGRINDER_NMKEYFARM", GetString(GG_NM_GROUP_AUTOMATION_KEYBIND))

        local world = GetWorldName()
        self:InitSavedVars(world)

        self:InitializeKeyChording()

        EM:RegisterForEvent(self.name, EVENT_QUEST_REMOVED, function(...) self:UpdateTime(...) end)

        self:BuildMenu()
        self:RegisterSlashCommands()

        self:LeadWarnings_ResetState()

        EM:RegisterForUpdate(self.name .. ".DelayedStart", 500, function() self:DelayedStart() end)
    end
end

EM:RegisterForEvent(FrankGrinder.name, EVENT_ADD_ON_LOADED, function(...) FrankGrinder:Initialize(...) end)

do
    local LCK = LibCharacterKnowledge
    if LCK then
        LCK.RegisterForCallback(FrankGrinder.name, LCK.EVENT_INITIALIZED, function()
            FrankGrinder._lckIsLoaded = true
            FrankGrinder:PA_ClearCaches()
        end)
    end
end
