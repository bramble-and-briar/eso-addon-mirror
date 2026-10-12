Hermes = {
    db = nil,
    name = "Hermes",
    addonName = "Hermes",
    displayName = "Hermes",
    author = "Niwasaka",
    website = "https://www.esoui.com/downloads/fileinfo.php?id=3499",
    slashCommand = "/hermes",
    version = "1.6.0",
    guildIndex = 0,

    defaults = {
        showTeleport = true,
        showMail = true,
        showHouse = true,
        showChangelog = true,
        enableTomeAutoClaim = true,
        autoTrackTomes = false,
        showTomeProgressBar = true,
        showTomeIconUI = true,
        enableTomeAlert = true,
        locationTomeAlert = 0,
        tomeColorWeekly = "|c3595de",
        tomeColorSeasonal = "|c3595de",
        showTomeReward = false,
        showSeasonalTomeProgress = false,
        tomeWindowX = nil,
        tomeWindowY = nil,
        tomeWindowVisible = false,
        tomeWindowLastFilter = "weekly",
        tomeWindowCompactMode = false,
        tomeWindowBackgroundAlpha = 100,
        tomeIconUIX = 0,
        tomeIconUIY = 900,
        tomeQueue = {},
        changelogX = nil,
        changelogY = nil,
        guideX = nil,
        guideY = nil,
    },

    panel = nil,
}

function Hermes:Initialize()
    self.db = ZO_SavedVars:NewAccountWide("HermesSavedVars", 1, nil, self.defaults)

    self:InitializeMenu()
    self:InitializeChatMenu()
    self:UpdateGroupMembers()
    self:InitializeTomeAlerts()
    self:InitializeTomeWindow()
    self:InitializeTomeIcon()
    self:InitializeGuide()
    self:SetChatHook()
    self:ChangelogScreen()

    EVENT_MANAGER:UnregisterForEvent(Hermes.name, EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(Hermes.name, EVENT_GROUP_MEMBER_JOINED, function()
        self:UpdateGroupMembers()
    end)
    EVENT_MANAGER:RegisterForEvent(Hermes.name, EVENT_GROUP_MEMBER_LEFT, function()
        self:UpdateGroupMembers()
    end)

    SLASH_COMMANDS["/htomes"] = function()
        self:ToggleTomeWindow()
    end

end

function Hermes.OnAddOnLoaded(_, addon)
    if addon == Hermes.name then
        Hermes:Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(Hermes.name, EVENT_ADD_ON_LOADED, Hermes.OnAddOnLoaded)

