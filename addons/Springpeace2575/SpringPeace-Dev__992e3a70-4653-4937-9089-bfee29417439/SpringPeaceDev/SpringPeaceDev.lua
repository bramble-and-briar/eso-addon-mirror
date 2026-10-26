SpringPeaceDev = SpringPeaceDev or {}
local SP = SpringPeaceDev

-- local RMPlayer = RandoMotePlayer
local ERMWheels = ExtraRadialMenuWheels

SP.name             = "SpringPeaceDev"
SP.displayName      = "SpringPeace (Dev)"
SP.savedVarsName    = "SpringPeaceDevSavedVars"
SP.settingsPanelId  = "SpringPeaceDevPanel"
SP.version          = "1.8.6"

SP.savedVarsVersion = 1

SP.defaults = {
    --[[ enableRM = false,
    enableCTA = false, ]]
    enableGSW = false,
    enableERM = false,
    enableFTA = false,
}

--[[ SP.defaults.rm = {
    enable = true,
    debug = false,
    useStandard = true,
    useCollectible = true,
    useFavouriteOnly = false,
    selectedPreset = "None",
    showLocked = false,
    showSlash = false,
    chatOutput = false,
    idleMax = 15,
    minTime = 10,
    maxTime = 30,
    useEmote = {},
    useCategory = {},
    favEmote = {},
    presetEmote = {
        None = {},
        Dancer = {},
        Musician = {},
        Goofball = {},
        Custom1 = {},
        Custom2 = {},
        Custom3 = {},
    },
}

SP.defaults.cta = {
    showUncollectedItemsOnly = false,
    enablePageRotation = true,
    showIcons = true,
    orderedBy = 3,
    debug = false,
    enable = true,

    selectedCategory = "All",
    selectedSubcategory = "All",
    selectedSource = "All",
    selectedGroup = "All",

    -- collections, values by ix
    results = {},
    categories = {},
    subcategories = {},
    sources = {},
    groups = {},
    types = {},

    collectedCount = 0,
    totalCount = 0,
} ]]

SP.defaults.gsw = {
    maxResults = 5000,
    captureSearchResponses = true,
    capturePageResponses = true,
    keepUncollectedItemsOnly = false,
    showCheapestItemsOnly = true,
    showUncollectedItemsOnly = false,
    enablePageRotation = true,
    deleteOnConfirmationOnly = true,
    deleteWholeItem = false,
    clearOnConfirmationOnly = true,
    trimResults = false,
    orderedByName = false,
    debug = false,
    enable = false,

    selectedProvince = "All",
    selectedAlliance = "All",
    selectedZone = "All",
    selectedSign = "All",
    selectedTrader = "All",

    tradersLastCheck = {},

    -- collections, values by ix
    results = {},
    items = {},
    contexts = {},
    sellers = {},
    locations = {},
    traders = {},
    guilds = {},
    searches = {},

    resultsCount = 0,
    resultsLength = 0,
}

SP.defaults.erm = {
    enable = true,
    keepOriginalAlliesWheel = false,

    wheelsEnabled = {
		[ERMWheels.ERM_WHEEL1] = false,
		[ERMWheels.ERM_WHEEL2] = false,
		[ERMWheels.ERM_WHEEL3] = true,
		-- [ERMWheels.ERM_WHEEL4] = false,
		-- [ERMWheels.ERM_WHEEL5] = false,
		-- [ERMWheels.ERM_WHEEL6] = false,
		-- [ERMWheels.ERM_WHEEL7] = false,
	},
	wheelsEntries = {
		[ERMWheels.ERM_WHEEL1] = {},
		[ERMWheels.ERM_WHEEL2] = {},
		[ERMWheels.ERM_WHEEL3] = {
            -- 1 local houseId = 6 -- Flaming Nix Deluxe Garret
            -- 2 local houseId = 124 -- Night's Den
            -- 3 local houseId = 94 -- Seaveil Spire
            -- 8 local houseId = 62 -- Grand Psijic Villa
            6,
            124,
            94,
            nil,
            nil,
            nil,
            nil,
            62,
        },
		-- [ERMWheels.ERM_WHEEL4] = {},
		-- [ERMWheels.ERM_WHEEL5] = {},
		-- [ERMWheels.ERM_WHEEL6] = {},
		-- [ERMWheels.ERM_WHEEL7] = {},
	},
}

SP.defaults.fta = {
    showUncollectedItemsOnly = false,
    buildOnDemand = true,
    enablePageRotation = true,
    showIcons = true,
    orderedBy = 3,
    debug = false,
    enable = true,

    freshLevelTimeUnit = "Day",
    freshLevelTimeValue = 1,
    recentLevelTimeUnit = "Month",
    recentLevelTimeValue = 1,

    selectedCategory = "All",
    selectedSubcategory = "All",
    selectedSource = "All",
    selectedGroup = "All",
    selectedTag = "All",
    selectedInventory = "All",

    inventoriesLastCheck = {},

    -- collections, values by ix
    results = {},
    categories = {},
    subcategories = {},
    sources = {},
    groups = {},
    tags = {},
    types = {},

    collectedCount = 0,
    totalCount = 0,
}

SP.playTestEnabled = false

SP.slashCommand = {}

SP.slashCommand.enablePlayTest	= "/spplaytest"
SP.slashCommand.checkMementos	= "/spchmems"
SP.slashCommand.enableRM		= "/sprm"
SP.slashCommand.enableCTA		= "/spcta"
SP.slashCommand.enableFTA		= "/spfta"
SP.slashCommand.enableGSW		= "/spgsw"
SP.slashCommand.enableERM		= "/sperm"

function SP.Initialize()
    SP.sv = ZO_SavedVars:NewAccountWide(SP.savedVarsName, SP.savedVarsVersion, nil, SP.defaults, GetWorldName())

    --[[ if RandoMote and RandoMote.Initialize and SP.sv.enableRM then
		RandoMote.Initialize(SP.sv.rm, true)
        RandoMote.Activate()
	end

    if CollectThemAll and CollectThemAll.Initialize and SP.sv.enableCTA then
		CollectThemAll.Initialize(SP.sv.cta, true)
        CollectThemAll.Activate()
	end ]]

    if GuildStoreWatch and GuildStoreWatch.Initialize and SP.sv.enableGSW then
		GuildStoreWatch.Initialize(SP.sv.gsw, true)
        GuildStoreWatch.Activate()
	end

    if ExtraRadialMenu and ExtraRadialMenu.Initialize and SP.sv.enableERM then
        ExtraRadialMenu.Initialize(SP.sv.erm, true)
        ExtraRadialMenu.Activate()
    end

    if FurnishThemAll and FurnishThemAll.Initialize and SP.sv.enableFTA then
        FurnishThemAll.Initialize(SP.sv.fta, true)
        FurnishThemAll.Activate()
    end
end

-- TODO: move this to RandoMote - special slash command
function SP.TestEmoteLoop(index, slash)
	if SP.playTestEnabled == false then
		return
	end

	local POLL_INTERVAL = 100          -- ms
	local MAX_DURATION  = 30000        -- ms (30 s)

    local running = true
    local startTime = GetGameTimeMilliseconds()

    local function Poll()
        if not running then return end

        local elapsed = GetGameTimeMilliseconds() - startTime

        -- End test when it is not possible already
		local canPlay, _ = RMPlayer.CanPlayEmoteNow()
        if not canPlay then
            running = false
            d(string.format("%s -> STOPPED (after %.2f s)", slash, elapsed / 1000))
            return
        end

        -- Timeout = emote is probably LOOP
        if elapsed >= MAX_DURATION then
            running = false
            d(string.format("%s -> LOOP (ran %.2f s)", slash, elapsed / 1000))
            return
        end

        zo_callLater(Poll, POLL_INTERVAL)
    end

    -- start polling
    zo_callLater(Poll, POLL_INTERVAL)
end

--[[ function RMPlayer.PlayEmoteNow(emote)
	SCENE_MANAGER:ShowBaseScene()
	zo_callLater(function()
		local canPlay, reason = RMPlayer.CanPlayEmoteNow()
		if not canPlay then
			d(reason)
			-- RM.SafeStartChatInput(emote.slash)
			return
		end
		PlayEmoteByIndex(emote.index)
		SP.TestEmoteLoop(emote.index, emote.slash)
	end, 200)
end ]]

function SP.VarToString(name, value)
	return " ; "..name..": "..tostring(value)
end

function SP.MementoCategoryType()
    ---@type CollectibleCategoryType
    return COLLECTIBLE_CATEGORY_TYPE_MEMENTO
end

function SP.CheckMementos()
	local categoryType = SP.MementoCategoryType()
	d("Mementos: "
		..SP.VarToString("COLLECTIBLE_CATEGORY_TYPE_MEMENTO", COLLECTIBLE_CATEGORY_TYPE_MEMENTO)
		..SP.VarToString("GetTotalCollectiblesByCategoryType", GetTotalCollectiblesByCategoryType(categoryType))
	)
	-- local available = {}
	for i = 1, GetTotalCollectiblesByCategoryType(categoryType) do
		local collectibleId = GetCollectibleIdFromType(categoryType, i)
		-- local isUnlocked = IsCollectibleUnlocked(collectibleId)
		-- if GetCollectibleCategoryType(collectibleId) ~= COLLECTIBLE_CATEGORY_TYPE_MEMENTO then return end
		-- if id and IsCollectibleUnlocked(collectibleId) then table.insert(available, collectibleId) end
		local name, _, _, _, unlocked = GetCollectibleInfo(collectibleId)

        if i > 300 then -- output switched off now
            -- not possile to output all at once
            d(""
                ..SP.VarToString("ix", i)
                ..SP.VarToString("id", collectibleId)
                ..SP.VarToString("name", name)
                ..SP.VarToString("unlocked", unlocked)
            )
        end
    end
end

function SP.OnAddOnLoaded(eventCode, addonName)
    if addonName ~= SP.name then return end

    SP.Initialize()

    SLASH_COMMANDS[SP.slashCommand.enablePlayTest] = function() SP.playTestEnabled = true end
	SLASH_COMMANDS[SP.slashCommand.checkMementos] = function() SP.CheckMementos() end

    --[[ SLASH_COMMANDS[SP.slashCommand.enableRM] = function()
		SP.sv.enableRM = not SP.sv.enableRM
		d("RM Enable: "..tostring(SP.sv.enableRM))
		zo_callLater(function() ReloadUI() end, 1000)
	end

    SLASH_COMMANDS[SP.slashCommand.enableCTA] = function()
        SP.sv.enableCTA = not SP.sv.enableCTA
        d("CTA Enable: "..tostring(SP.sv.enableCTA))
		zo_callLater(function() ReloadUI() end, 1000)
    end ]]

	SLASH_COMMANDS[SP.slashCommand.enableGSW] = function()
		SP.sv.enableGSW = not SP.sv.enableGSW
		d("GSW Enable: "..tostring(SP.sv.enableGSW))
		zo_callLater(function() ReloadUI() end, 1000)
	end

    SLASH_COMMANDS[SP.slashCommand.enableERM] = function()
		SP.sv.enableERM = not SP.sv.enableERM
		d("ERM Enable: "..tostring(SP.sv.enableERM))
		zo_callLater(function() ReloadUI() end, 1000)
	end

    SLASH_COMMANDS[SP.slashCommand.enableFTA] = function()
		SP.sv.enableFTA = not SP.sv.enableFTA
		d("FTA Enable: "..tostring(SP.sv.enableFTA))
		zo_callLater(function() ReloadUI() end, 1000)
	end
end

EVENT_MANAGER:RegisterForEvent(SP.name, EVENT_ADD_ON_LOADED, SP.OnAddOnLoaded)
