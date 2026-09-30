local addon = {}
addon.name = 'ImpressiveStats'
addon.displayName = '|c7c42f2Imp|ceeeeee-ressive Stats|r'
addon.version = '1.5.7'

local Log = IMP_STATS_Logger('IMP_STATS_MAIN')

local DEFAULTS = {
	battlegrounds = {
		enabled = true,
		namingMode = 1,
		-- selectedCharacters = {},
		showOnlyLastUpdateMatches = false,
		last150 = false,
		saveBuilds = false,
	},
	duels = {
		enabled = true,
		namingMode = 1,
		-- selectedCharacters = {},
		saveBuilds = false,
	},
	tot = {
		enabled = true,
		namingMode = 1,
		leaderboard = false,
		-- selectedCharacters = {},
	},
	errors = {
		enabled = true,
		allowCSA = false,
		allowAlerts = true,
	}
}

local CHARACTER_DEFAULTS = {
	battlegrounds = {
		-- enabled = true,
		-- namingMode = 1,
		selectedCharacters = {},
	},
	duels = {
		-- enabled = true,
		-- namingMode = 1,
		selectedCharacters = {},
	},
	tot = {
		-- enabled = true,
		-- namingMode = 1,
		selectedCharacters = {},
	},
}

local function MakeItPerfect()
	local FRAGMENTS_TO_REMOVE = {
		FRAME_PLAYER_FRAGMENT,
		RIGHT_BG_FRAGMENT,
		TITLE_FRAGMENT,
		IMP_STATS_TITLE_FRAGMENT,
		-- background for custom left panel
		IMP_STATS_LEFT_PANEL_BACKGROUND,
	}

	local function recreateBackground(control)
		PP:CreateBackground(control, --[[#1]] nil, nil, nil, -10, -10, --[[#2]] nil, nil, nil, 0, 10)
	end

	local function reanchorControl(control)
		PP.Anchor(control, --[[#1]] TOPRIGHT, GuiRoot, TOPRIGHT, 0, 120, --[[#2]] true, BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, -70)
	end

	local function magic(control, scene)
		recreateBackground(control)
		reanchorControl(control)

		if scene then
			PP.removeFragmentsFromScene(scene, FRAGMENTS_TO_REMOVE)
		end
	end

	for sceneName, container in pairs(IMP_STATS_MENU.scenes) do
		magic(container, SCENE_MANAGER:GetScene(sceneName))
	end

	reanchorControl(IMP_STATS_RightPanel)

	PP.Anchor(LMMXMLSceneGroupBar, --[[#1]] TOPRIGHT, GuiRoot, TOPRIGHT, -30, 64)
	PP.Font(LMMXMLSceneGroupBar:GetNamedChild("Label"), --[[Font]] PP.f.u67, 22, "outline", --[[Alpha]] 0.9, --[[Color]] nil, nil, nil, nil, --[[StyleColor]] 0, 0, 0, 0.5)

	-- Tribute Leaderboard
	PP:CreateBackground(IMP_STATS_TRIBUTE_LEADERBOARD, --[[#1]] nil, nil, nil, -10, -10, --[[#2]] nil, nil, nil, 0, 10)
	PP.Anchor(IMP_STATS_TRIBUTE_LEADERBOARD, --[[#1]] TOPLEFT, GuiRoot, TOPLEFT, 0, 120, --[[#2]] true, BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 0, -70)
end

function addon:OnLoad()
	Log('Loading %s v%s', self.name, self.version)

	self.sv = ZO_SavedVars:NewAccountWide('ImpressiveStatsSV', 1, nil, DEFAULTS)
	self.csv = ZO_SavedVars:NewCharacterIdSettings('ImpressiveStatsCSV', 1, nil, CHARACTER_DEFAULTS)

	IMP_STATS_MENU:Initialize(self.sv.battlegrounds.enabled, self.sv.duels.enabled, self.sv.tot.enabled)

	if self.sv.battlegrounds.enabled then
    	IMP_STATS_InitializeNewMatchManager(self.sv.battlegrounds, self.csv.battlegrounds)
	end

	if self.sv.duels.enabled then
		IMP_STATS_InitializeDuelsManager(self.sv.duels, self.csv.duels)
		Log('Duels initialized')
	end

	if self.sv.tot.enabled then
		IMP_STATS_InitializeTributeManager(self.sv.tot, self.csv.tot)
		Log('Tales of tribute initialized')
	end

	if PP then MakeItPerfect() end

	-- ------------------------------------------------------------------------

	IMP_STATS_SHARED.Errors:Initialize(self.sv.errors)

	--[[
	IMP_STATS_SHARED.Errors:AddError('Test', 'Test message 1', 'Test traceback 1')
	IMP_STATS_SHARED.Errors:AddError('Test', 'Test message 2', 'Test traceback 2')
	IMP_STATS_SHARED.Errors:AddError('Test', 'Test message 3', 'Test traceback 3')
	--]]

	if self.sv.errors.enabled then
		IMP_STATS_SHARED.Notifications.RegisterNotifications()
	end

	-- ------------------------------------------------------------------------

	IMP_STATS_InitializeSettings(self)

	GetControl('IMP_STATS_VersionLabel'):SetText('v.' .. addon.version)
end

local function OnAddonLoaded(_, addonName)
	if addonName ~= addon.name then return end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	addon:OnLoad()

	-- IMP_STATS = addon
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)