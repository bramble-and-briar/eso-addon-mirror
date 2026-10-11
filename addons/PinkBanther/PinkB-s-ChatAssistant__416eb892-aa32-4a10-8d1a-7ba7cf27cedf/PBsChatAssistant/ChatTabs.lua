-- Chat tabs: the normal tab, a group tab, and one per guild.
--
-- Console chat ships with a single tab and no way to add one. The parts are all there and are
-- shared rather than keyboard-only: SharedChatContainer:AddWindow makes a tab, HandleTabClick
-- switches to one, SetWindowFilterEnabled routes a category to a tab, and ZO_ChatWindowTabTemplate
-- is in the shared XML. The note in gamepadchatsystem.lua about not wanting more chat containers
-- on console is about containers, not about tabs inside one. Confirmed on a PS5 before this was
-- written: a tab can be added, selected from Lua, and removed again.
--
-- Officer chat shares its guild's tab. Splitting it would double the tab count for something read
-- in the same breath as the guild it belongs to.
if not PBS_CHAT_ASSISTANT then
	return
end

local addon = PBS_CHAT_ASSISTANT
local tabs = {}
addon.chatTabs = tabs

-- Guild data is not ready the moment the world appears, and a tab named after a guild needs the
-- name. Reconciling is debounced so the three events that can trigger it do not do the work three
-- times over.
local RECONCILE_DELAY_MS = 2000

-- Tab strip geometry, applied by this add-on rather than by the client.
--
-- The client anchors tabs BOTTOMLEFT to the container's TOPLEFT, which puts them above the box
-- and outside its rectangle. On console that comes out invisible: measured with five tabs, all
-- reporting hidden false with real widths, and nothing on screen. Rather than work out which of
-- the several reasons that could be, the strip is placed inside the container where there is
-- nothing to argue with -- and along the bottom, which is where it was asked for.
local TAB_STRIP_X = -20
local TAB_STRIP_Y = -215
local TAB_STRIP_WIDTH = 900
local TAB_STRIP_HEIGHT = 32

local function Print(formatString, ...)
	d(string.format("|cFF69B4PB's ChatAssistant|r: " .. formatString, ...))
end

local function GetContainer()
	local chat = type(ZO_GetChatSystem) == "function" and ZO_GetChatSystem()
	return chat and chat.primaryContainer
end

-- Built rather than declared: a table constructor with a nil key raises at load, and these are
-- client constants that a future update could rename.
local function GuildCategories(index)
	local guild = { CHAT_CATEGORY_GUILD_1, CHAT_CATEGORY_GUILD_2, CHAT_CATEGORY_GUILD_3,
		CHAT_CATEGORY_GUILD_4, CHAT_CATEGORY_GUILD_5 }
	local officer = { CHAT_CATEGORY_OFFICER_1, CHAT_CATEGORY_OFFICER_2, CHAT_CATEGORY_OFFICER_3,
		CHAT_CATEGORY_OFFICER_4, CHAT_CATEGORY_OFFICER_5 }
	return guild[index], officer[index]
end

local function GuildChannel(index)
	local channels = { CHAT_CHANNEL_GUILD_1, CHAT_CHANNEL_GUILD_2, CHAT_CHANNEL_GUILD_3,
		CHAT_CHANNEL_GUILD_4, CHAT_CHANNEL_GUILD_5 }
	return channels[index]
end

local function GuildIndexForChannel(channelId)
	local guild = { CHAT_CHANNEL_GUILD_1, CHAT_CHANNEL_GUILD_2, CHAT_CHANNEL_GUILD_3,
		CHAT_CHANNEL_GUILD_4, CHAT_CHANNEL_GUILD_5 }
	local officer = { CHAT_CHANNEL_OFFICER_1, CHAT_CHANNEL_OFFICER_2, CHAT_CHANNEL_OFFICER_3,
		CHAT_CHANNEL_OFFICER_4, CHAT_CHANNEL_OFFICER_5 }
	for index = 1, 5 do
		if channelId == guild[index] or channelId == officer[index] then
			return index
		end
	end
	return nil
end

-- The group tab is named from a string of this add-on's own, not from anything the client
-- supplies, so it follows the UI language. The name it was created under is kept in the saved
-- settings, which is how a tab made in one language is found and renamed in another instead of
-- being left behind beside a new one.
local function GroupTabName()
	local name = type(GetString) == "function" and SI_PBSCHATASSISTANT_GROUP_TAB
		and GetString(SI_PBSCHATASSISTANT_GROUP_TAB)
	if type(name) == "string" and name ~= "" then
		return name
	end
	return "Group"
end

local function IsPartyChannel(channelId)
	return channelId ~= nil and CHAT_CHANNEL_PARTY ~= nil and channelId == CHAT_CHANNEL_PARTY
end

-- Channels that have a tab of their own. Everything else belongs to the normal tab, which is what
-- "the channel to go back to" means when the normal tab is selected again.
local function IsDedicatedChannel(channelId)
	return GuildIndexForChannel(channelId) ~= nil or IsPartyChannel(channelId)
end

-- Which guilds the player is in, by slot, with the names the tabs are called after.
function tabs:GuildSlots()
	local slots = {}
	local numGuilds = type(GetNumGuilds) == "function" and GetNumGuilds() or 0
	for guildIndex = 1, numGuilds do
		local guildId = type(GetGuildId) == "function" and GetGuildId(guildIndex)
		if guildId and guildId ~= 0 then
			local name = type(GetGuildName) == "function" and GetGuildName(guildId)
			if not name or name == "" then
				name = "#" .. tostring(guildId)
			end
			slots[#slots + 1] = { index = guildIndex, guildId = guildId, name = name }
		end
	end
	return slots
end

-- Per guild, not one switch for all of them. Missing means shown, so a guild joined later behaves
-- the way the chat did before any of this existed.
function tabs:IsGuildInMainTab(guildId)
	local map = addon.sv and addon.sv.guildMainTab
	if not map or guildId == nil then
		return true
	end
	local stored = map[tostring(guildId)]
	if stored == nil then
		return true
	end
	return stored
end

function tabs:SetGuildInMainTab(guildId, shown)
	if not addon.sv or guildId == nil then
		return
	end
	addon.sv.guildMainTab = addon.sv.guildMainTab or {}
	addon.sv.guildMainTab[tostring(guildId)] = shown and true or false
	self:Reconcile()
end

local function GuildTabName(guildIndex)
	local guildId = GetGuildId and GetGuildId(guildIndex)
	local name = guildId and GetGuildName and GetGuildName(guildId)
	if name and name ~= "" then
		return name
	end
	return nil
end

local function FindTabByName(container, name)
	for index = 1, #container.windows do
		if container:GetTabName(index) == name then
			return index
		end
	end
	return nil
end

local function RemoveAllTabsNamed(container, name)
	for index = #container.windows, 2, -1 do
		if container:GetTabName(index) == name then
			container:RemoveWindow(index)
		end
	end
end

-- Keep exactly one tab of this name. Removing from the end prevents index shifts from skipping a
-- duplicate; the returned index follows the kept tab if a lower duplicate was removed.
local function RemoveDuplicateTabsNamed(container, name, keepIndex)
	for index = #container.windows, 2, -1 do
		if index ~= keepIndex and container:GetTabName(index) == name then
			container:RemoveWindow(index)
			if index < keepIndex then
				keepIndex = keepIndex - 1
			end
		end
	end
	return keepIndex
end

----------------------------------------------------------------------------------------------
-- Category routing
----------------------------------------------------------------------------------------------

-- Everything off except this guild and its officer channel.
--
-- A new tab inherits whatever categories the client had enabled by default, which is most of
-- them, so the guild tab has to be cleared rather than only added to. SetWindowFilterEnabled is a
-- no-op when the value already matches, so this is cheap on every pass but the first.
function tabs:RouteGuildTab(container, tabIndex, guildCategory, officerCategory)
	if type(GetNumChatCategories) ~= "function" then
		return
	end

	for category = 1, GetNumChatCategories() do
		local wanted = (category == guildCategory) or (category == officerCategory)
		container:SetWindowFilterEnabled(tabIndex, category, wanted)
	end
end

-- The normal tab keeps everything it had; only the guild and officer categories are touched, and
-- only according to the setting. Reading every guild in one place is the point of leaving them on.
function tabs:ApplyMainTabGuildVisibility(container)
	for guildIndex = 1, 5 do
		local guildCategory, officerCategory = GuildCategories(guildIndex)
		local guildId = GetGuildId and GetGuildId(guildIndex)
		local wanted = self:IsGuildInMainTab(guildId)

		if guildCategory then
			container:SetWindowFilterEnabled(1, guildCategory, wanted)
		end
		if officerCategory then
			container:SetWindowFilterEnabled(1, officerCategory, wanted)
		end
	end
end

----------------------------------------------------------------------------------------------
-- Reconciling
----------------------------------------------------------------------------------------------

-- Tabs persist in the client's own chat settings, so this has to be idempotent: a tab is created
-- only when one of that name is not already there, or every login would add another.
--
-- Tabs we created are remembered by name against the guild id, so a guild the player has left can
-- have its tab taken away again without touching a tab somebody made by hand.
function tabs:Reconcile()
	if not addon.sv or not addon.sv.guildTabsEnabled then
		return
	end

	local container = GetContainer()
	if not container or #container.windows == 0 then
		return
	end

	-- Before the guilds, so a fresh install lays the tabs out in the order they are walked.
	self:EnsureGroupTab(container)

	addon.sv.guildTabNames = addon.sv.guildTabNames or {}
	local known = addon.sv.guildTabNames
	local seen = {}

	local numGuilds = GetNumGuilds and GetNumGuilds() or 0
	for guildIndex = 1, numGuilds do
		local name = GuildTabName(guildIndex)
		local guildCategory, officerCategory = GuildCategories(guildIndex)
		local guildId = GetGuildId and GetGuildId(guildIndex)

		if name and guildCategory and guildId then
			seen[tostring(guildId)] = true

			local tabIndex = FindTabByName(container, name)
			local previous = known[tostring(guildId)]
			if previous and previous ~= name then
				local previousIndex = FindTabByName(container, previous)
				if tabIndex then
					-- A current-name tab already exists, so every old-name tab is stale.
					RemoveAllTabsNamed(container, previous)
					tabIndex = FindTabByName(container, name)
				elseif previousIndex then
					-- Otherwise preserve the existing buffer and filters by renaming it.
					container:SetTabName(previousIndex, name)
					tabIndex = previousIndex
				end
			end

			if not tabIndex then
				container:AddWindow(name)
				tabIndex = FindTabByName(container, name)
			end

			if tabIndex then
				tabIndex = RemoveDuplicateTabsNamed(container, name, tabIndex)
				known[tostring(guildId)] = name
				self:RouteGuildTab(container, tabIndex, guildCategory, officerCategory)
			end
		end
	end

	-- Tabs for guilds no longer joined.
	for guildId, name in pairs(known) do
		if not seen[guildId] then
			RemoveAllTabsNamed(container, name)
			known[guildId] = nil
		end
	end

	self:ApplyMainTabGuildVisibility(container)
	self:RefreshStrip(container)
end

function tabs:GroupTabIndex(container)
	local name = (addon.sv and addon.sv.groupTabName) or GroupTabName()
	return FindTabByName(container, name)
end

-- The group tab: party chat and nothing else, the same shape as a guild tab.
--
-- It exists whether or not the player is in a group. A tab that came and went with the group
-- would lose its history every time the group disbanded, and would change the order the chord
-- walks the tabs in from one press to the next.
function tabs:EnsureGroupTab(container)
	if not CHAT_CATEGORY_PARTY then
		return nil
	end

	local name = GroupTabName()
	local previous = addon.sv.groupTabName
	local tabIndex = FindTabByName(container, name)
	if previous and previous ~= name then
		local previousIndex = FindTabByName(container, previous)
		if tabIndex then
			RemoveAllTabsNamed(container, previous)
			tabIndex = FindTabByName(container, name)
		elseif previousIndex then
			container:SetTabName(previousIndex, name)
			tabIndex = previousIndex
		end
	end

	if not tabIndex then
		container:AddWindow(name)
		tabIndex = FindTabByName(container, name)
	end

	if tabIndex then
		tabIndex = RemoveDuplicateTabsNamed(container, name, tabIndex)
		addon.sv.groupTabName = name
		self:RouteGuildTab(container, tabIndex, CHAT_CATEGORY_PARTY, nil)
	end
	return tabIndex
end

function tabs:ScheduleReconcile()
	if self.reconcilePending then
		return
	end
	self.reconcilePending = true
	zo_callLater(function()
		self.reconcilePending = false
		self:Reconcile()
	end, RECONCILE_DELAY_MS)
end

-- Takes away every tab this add-on made, and hands the guild categories back to the normal tab so
-- nothing becomes unreadable by turning the feature off.
function tabs:RemoveAll()
	local container = GetContainer()
	if not container or not addon.sv then
		return
	end

	local known = addon.sv.guildTabNames or {}
	for guildId, name in pairs(known) do
		local tabIndex = FindTabByName(container, name)
		if tabIndex and tabIndex > 1 then
			container:RemoveWindow(tabIndex)
		end
		known[guildId] = nil
	end

	-- Party chat was never taken out of the normal tab, so removing the group tab loses nothing.
	if addon.sv.groupTabName then
		RemoveAllTabsNamed(container, addon.sv.groupTabName)
		addon.sv.groupTabName = nil
	end

	for index = 1, 5 do
		local guildCategory, officerCategory = GuildCategories(index)
		if guildCategory then
			container:SetWindowFilterEnabled(1, guildCategory, true)
		end
		if officerCategory then
			container:SetWindowFilterEnabled(1, officerCategory, true)
		end
	end

	self:RefreshStrip(container)
end

----------------------------------------------------------------------------------------------
-- Selecting
----------------------------------------------------------------------------------------------

-- currentBuffer is the client's authoritative selected-tab state. Visibility is only a fallback:
-- the game can hide chat controls as part of HUD/minimise state, which is not a tab selection.
function tabs:GetActiveIndex(container)
	if container.currentBuffer then
		for index, window in ipairs(container.windows) do
			if window.buffer == container.currentBuffer then
				return index
			end
		end
	end

	if container.tabGroup and type(container.tabGroup.GetClickedButton) == "function" then
		local clicked = container.tabGroup:GetClickedButton()
		if clicked and clicked.index and container.windows[clicked.index] then
			return clicked.index
		end
	end

	local remembered = self.activeIndices and self.activeIndices[container]
	if remembered and container.windows[remembered] then
		return remembered
	end

	for index = 1, #container.windows do
		if not container.windows[index]:IsHidden() then
			return index
		end
	end
	return 1
end

-- The active tab, as one line of text.
--
-- The strip of per-tab controls is abandoned, and it was never the drawing that failed: the window
-- was never created at all. /pbchat tabs reported "strip false", because it was built lazily from
-- inside RefreshStrip and nothing ever reached that call. The draw test, which creates its control
-- immediately and unconditionally, displayed every time.
--
-- So this is built the way the draw test is: made once, on entering the world, before anything can
-- decide not to. One label, naming the active tab, in the colour that tab's chat already uses.
local INDICATOR_NAME = "PBsChatAssistantTabIndicator"
local INDICATOR_WIDTH = 1100
local INDICATOR_DRAW_LAYERS = {
	background = DL_BACKGROUND,
	controls = DL_CONTROLS,
	text = DL_TEXT,
	overlay = DL_OVERLAY,
}

-- The offsets have meant three different things across these releases: an inset from the chat box,
-- an offset from the bottom right of the screen, and now a position measured from the top centre.
-- A saved value only takes a default when the save is new, so one written under the old meaning
-- stays and is read under the new one, which is how the strip came to sit 215 pixels above the top
-- of the screen and looked, for several rounds, exactly like something that would not draw.
function tabs:MigrateStripPosition()
	if not addon.sv or addon.sv.tabStripPlaced then
		return
	end
	addon.sv.tabStripPlaced = true
	addon.sv.tabStripX = 0
	addon.sv.tabStripY = 110
	addon.sv.tabTextSize = addon.sv.tabTextSize or 28
end

function tabs:EnsureIndicator()
	if self.indicator then
		return self.indicator
	end
	-- WINDOW_MANAGER is supplied by the client and is not guaranteed to report Lua type "table"
	-- on every platform. The old type check prevented this window being created on such clients,
	-- while DrawTest (which had no check) continued to work.
	if not WINDOW_MANAGER then
		return nil
	end

	local window = WINDOW_MANAGER:CreateTopLevelWindow(INDICATOR_NAME)
	window:SetMouseEnabled(false)
	if window.SetDrawTier and DT_HIGH then
		window:SetDrawTier(DT_HIGH)
	end

	local label = WINDOW_MANAGER:CreateControl(INDICATOR_NAME .. "Label", window, CT_LABEL)
	label:SetAnchorFill()
	label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	if label.SetDrawLayer and DL_TEXT then
		label:SetDrawLayer(DL_TEXT)
	end

	self.indicator = window
	self.indicatorLabel = label
	self:ApplyIndicatorStyle()
	return window
end

-- A tab can be selected by this add-on or by the client's own controls. Watching the container's
-- single selection method keeps the indicator correct for both without polling every frame.
function tabs:HookContainer(container)
	if not container or type(ZO_PostHook) ~= "function" then
		return false
	end

	self.hookedContainers = self.hookedContainers or {}
	if self.hookedContainers[container] then
		return true
	end
	self.hookedContainers[container] = true

	ZO_PostHook(container, "HandleTabClick", function(_, tab)
		self:OnTabSelected(container, tab and tab.index)
	end)
	return true
end

-- Keep changes made by the game's channel selector in step with the visible tab as well. Without
-- this reverse direction, choosing a guild destination while the normal tab is visible produces
-- exactly the misleading state the indicator is meant to prevent.
function tabs:HookChatChannel()
	local chat = type(ZO_GetChatSystem) == "function" and ZO_GetChatSystem()
	if not chat or self.hookedChat == chat or type(ZO_PostHook) ~= "function" then
		return
	end
	self.hookedChat = chat
	ZO_PostHook(chat, "SetChannel", function(_, channelId)
		if not self.settingChannel and addon.sv and addon.sv.guildTabsEnabled then
			self:SelectTabForChannel(channelId)
		end
	end)
end

function tabs:SetChatChannel(chat, channelId)
	self.settingChannel = true
	chat:SetChannel(channelId)
	self.settingChannel = false
end

function tabs:NormalChannel(chat)
	local current = chat and chat.currentChannel
	if current and not IsDedicatedChannel(current) then
		self.normalChannel = current
		return current
	end

	local configured = addon.sv and addon.sv.defaultChannel
	if self.normalChannel and not IsDedicatedChannel(self.normalChannel) then
		return self.normalChannel
	elseif configured and configured ~= 0 and not IsDedicatedChannel(configured) then
		return configured
	elseif chat and type(chat.GetDefaultChatChannel) == "function" then
		local channelId = chat:GetDefaultChatChannel()
		if channelId and not IsDedicatedChannel(channelId) then
			return channelId
		end
	end
	return CHAT_CHANNEL_ZONE or CHAT_CHANNEL_SAY
end

-- A guild tab is both a view of that guild's messages and the destination for the next message.
-- The normal tab is a mixed view, so selecting it deliberately leaves the current destination
-- alone rather than guessing zone, say or whichever channel the player last used.
function tabs:SetOutgoingChannelForTab(container, index)
	if not container then
		return false
	end
	local chat = type(ZO_GetChatSystem) == "function" and ZO_GetChatSystem()
	if not chat or type(chat.SetChannel) ~= "function" then
		return false
	end

	if index == 1 then
		local channelId = self:NormalChannel(chat)
		if channelId then
			self.normalChannel = channelId
			if chat.currentChannel ~= channelId then
				self:SetChatChannel(chat, channelId)
			end
			return true
		end
		return false
	end

	-- The group tab sends to party chat. Selecting it while not in a group is allowed: the client
	-- defers that channel's requirement to the moment a message is sent, and says so then.
	if index == self:GroupTabIndex(container) then
		if not CHAT_CHANNEL_PARTY then
			return false
		end
		if chat.currentChannel and not IsDedicatedChannel(chat.currentChannel) then
			self.normalChannel = chat.currentChannel
		end
		self:SetChatChannel(chat, CHAT_CHANNEL_PARTY)
		return true
	end

	local name = container:GetTabName(index)
	for guildIndex = 1, 5 do
		local guildId = GetGuildId and GetGuildId(guildIndex)
		local guildName = guildId and GetGuildName and GetGuildName(guildId)
		if guildName and guildName == name then
			local channelId = GuildChannel(guildIndex)
			if channelId and chat and type(chat.SetChannel) == "function" then
				if chat.currentChannel and not IsDedicatedChannel(chat.currentChannel) then
					self.normalChannel = chat.currentChannel
				end
				self:SetChatChannel(chat, channelId)
				return true
			end
			return false
		end
	end

	return false
end

function tabs:OnTabSelected(container, selectedIndex)
	local index = selectedIndex or self:GetActiveIndex(container)
	if not container.windows[index] then
		index = self:GetActiveIndex(container)
	end
	self.activeIndices = self.activeIndices or {}
	self.activeIndices[container] = index
	self:RefreshStrip(container)
	if not self.suppressChannelSync then
		self:SetOutgoingChannelForTab(container, index)
	end
end

function tabs:ApplyIndicatorStyle()
	if not self.indicator then
		return
	end

	local size = (addon.sv and addon.sv.tabTextSize) or 28
	local x = (addon.sv and addon.sv.tabStripX) or 0
	local y = (addon.sv and addon.sv.tabStripY) or 110

	-- Y is measured down from the top, so a negative one is always wrong. Clamped, because an
	-- offset that puts the text off the screen looks exactly like text that was never drawn, and
	-- telling those apart has already cost enough.
	if y < 0 then
		y = 0
	end

	self.indicator:SetDimensions(INDICATOR_WIDTH, size + 12)
	self.indicator:ClearAnchors()
	self.indicator:SetAnchor(TOP, GuiRoot, TOP, x, y)

	-- The size is the player's, so the font is built from one rather than naming a ready-made
	-- font of the client's.
	self.indicatorLabel:SetFont(string.format("$(GAMEPAD_MEDIUM_FONT)|%d|soft-shadow-thick", size))
	local layerName = (addon.sv and addon.sv.tabTextLayer) or "text"
	local drawLayer = INDICATOR_DRAW_LAYERS[layerName] or DL_TEXT
	if drawLayer and self.indicatorLabel.SetDrawLayer then
		self.indicatorLabel:SetDrawLayer(drawLayer)
	end
end

function tabs:IsHUDShowing()
	return not SCENE_MANAGER or type(SCENE_MANAGER.IsShowing) ~= "function"
		or SCENE_MANAGER:IsShowing("hud")
end

function tabs:UpdateIndicatorVisibility()
	if self.indicator then
		self.indicator:SetHidden(not self.indicatorWanted or not self:IsHUDShowing())
	end
end

function tabs:HookHUDScene()
	if self.hudSceneHooked or not SCENE_MANAGER or type(SCENE_MANAGER.GetScene) ~= "function" then
		return
	end
	local scene = SCENE_MANAGER:GetScene("hud")
	if scene and type(scene.RegisterCallback) == "function" then
		self.hudSceneHooked = true
		scene:RegisterCallback("StateChange", function()
			self:UpdateIndicatorVisibility()
		end)
	end
end

-- Kept as the public name used by settings and slash commands in earlier builds.
function tabs:PositionStrip()
	self:ApplyIndicatorStyle()
end

-- White for the normal tab; for a guild tab, the colour that guild's messages are already written
-- in, so the indicator matches the chat below it rather than inventing a palette.
function tabs:IndicatorColour(container, index)
	if index == 1 then
		return 1, 1, 1, 1
	end

	if index == self:GroupTabIndex(container) and CHAT_CATEGORY_PARTY
		and type(GetChatCategoryColor) == "function" then
		local r, g, b = GetChatCategoryColor(CHAT_CATEGORY_PARTY)
		if r then
			return r, g, b, 1
		end
	end

	local name = container:GetTabName(index)
	for guildIndex = 1, 5 do
		local guildId = GetGuildId and GetGuildId(guildIndex)
		local guildName = guildId and GetGuildName and GetGuildName(guildId)
		if guildName and guildName == name then
			local category = GuildCategories(guildIndex)
			if category and type(GetChatCategoryColor) == "function" then
				local r, g, b = GetChatCategoryColor(category)
				if r then
					return r, g, b, 1
				end
			end
		end
	end

	return 1, 1, 1, 1
end

function tabs:RefreshStrip(container)
	self:MigrateStripPosition()

	container = container or GetContainer()
	self:HookContainer(container)
	self:HookChatChannel()
	self:HookHUDScene()
	local window = self:EnsureIndicator()
	if not window then
		return
	end

	self:ApplyIndicatorStyle()

	local wanted = container and addon.sv and addon.sv.guildTabsEnabled
		and addon.sv.tabNameVisible ~= false and #container.windows > 0
	self.indicatorWanted = wanted
	self:UpdateIndicatorVisibility()
	if not wanted then
		return
	end

	local index = self:GetActiveIndex(container)
	self.indicatorLabel:SetText(container:GetTabName(index) or tostring(index))
	self.indicatorLabel:SetColor(self:IndicatorColour(container, index))
end

-- The smallest possible question: can this add-on put anything on screen at all?
--
-- It could once. The status label this add-on used to show for the outgoing channel was a top
-- level window of 1100x40 anchored TOP to GuiRoot at y 110 with a ZoFontGame label, and it
-- displayed. The tab strip is built the same way and does not. So this reproduces that label
-- exactly, adds a bright backdrop behind it so there is something to see even if text is the
-- problem, and is created and shown immediately rather than from inside a reconcile.
--
-- If this shows, the fault is in when or whether RefreshStrip runs. If it does not, nothing this
-- add-on draws reaches the screen any more and the strip cannot be built this way at all.
function tabs:DrawTest(on)
	if not on then
		if self.testWindow then
			self.testWindow:SetHidden(true)
		end
		Print("draw test off")
		return
	end

	if not self.testWindow then
		local window = WINDOW_MANAGER:CreateTopLevelWindow("PBsChatAssistantDrawTest")
		window:SetDimensions(1100, 40)
		window:SetAnchor(TOP, GuiRoot, TOP, 0, 110)
		window:SetMouseEnabled(false)

		local backdrop = WINDOW_MANAGER:CreateControl("PBsChatAssistantDrawTestBg", window, CT_BACKDROP)
		backdrop:SetAnchorFill()
		backdrop:SetCenterColor(1, 0, 0, 0.8)
		backdrop:SetEdgeColor(1, 1, 0, 1)

		local label = WINDOW_MANAGER:CreateControl("PBsChatAssistantDrawTestLabel", window, CT_LABEL)
		label:SetAnchorFill()
		label:SetFont("ZoFontGame")
		label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
		label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		label:SetText("PB DRAW TEST")
		label:SetColor(1, 1, 1, 1)

		self.testWindow = window
	end

	self.testWindow:SetHidden(false)
	Print("draw test on: red bar with PB DRAW TEST, top centre, 110 down")
end

function tabs:SelectTab(index, announce, syncChannel)
	local container = GetContainer()
	local window = container and container.windows[index]
	if not window then
		return false
	end

	local hooked = self:HookContainer(container)
	local previousSuppression = self.suppressChannelSync
	if syncChannel == false then
		self.suppressChannelSync = true
	end
	if container.tabGroup and window.tab then
		-- SetClickedButton invokes HandleTabClick through the tab's selection callback.
		container.tabGroup:SetClickedButton(window.tab)
		-- A restored tab group can already consider the button selected while currentBuffer still
		-- points elsewhere. In that state SetClickedButton does not invoke its callback, so make the
		-- actual buffer selection explicit only when the first call did not take effect.
		if self:GetActiveIndex(container) ~= index then
			container:HandleTabClick(window.tab)
		end
	else
		container:HandleTabClick(window.tab)
	end
	-- ZO_PostHook handles normal clients, including selections made by the client itself. Keep the
	-- direct path for a client where post-hooks are unavailable.
	if not hooked then
		self:OnTabSelected(container, index)
	end
	self.suppressChannelSync = previousSuppression
	local selected = self:GetActiveIndex(container) == index
	if selected then
		self:RefreshStrip(container)
	end

	if announce and selected then
		Print(GetString(SI_PBSCHATASSISTANT_TAB_LABEL), tostring(container:GetTabName(index)))
	end
	return selected
end

-- Match the visible tab to a channel chosen by the login default. Officer chat shares its
-- guild's tab. All non-guild channels use the normal mixed tab. Channel synchronisation is
-- suppressed here so an officer default remains officer rather than being replaced by guild chat.
function tabs:SelectTabForChannel(channelId)
	local container = GetContainer()
	if not container then
		return false
	end

	if IsPartyChannel(channelId) then
		local groupIndex = self:GroupTabIndex(container)
		if not groupIndex then
			self:Reconcile()
			groupIndex = self:GroupTabIndex(container)
		end
		if groupIndex then
			return self:SelectTab(groupIndex, false, false)
		end
	end

	local guildIndex = GuildIndexForChannel(channelId)
	if not guildIndex then
		self.normalChannel = channelId
		return self:SelectTab(1, false, false)
	end

	local guildId = GetGuildId and GetGuildId(guildIndex)
	local guildName = guildId and GetGuildName and GetGuildName(guildId)
	local tabIndex = guildName and FindTabByName(container, guildName)
	if not tabIndex then
		self:Reconcile()
		tabIndex = guildName and FindTabByName(container, guildName)
	end
	return tabIndex and self:SelectTab(tabIndex, false, false) or false
end

-- The order the chord walks the tabs in: normal, group, then the guilds by guild slot.
--
-- Decided here rather than by where the tabs physically sit. A tab is appended when it is created,
-- so anyone who already had guild tabs gets the group tab at the far end, and the client keeps its
-- per-tab filter settings by position, which makes moving a tab a way to scramble them. Walking a
-- list of our own gives the asked-for order whatever order they were made in. Tabs this add-on did
-- not make come last, in the order they stand.
function tabs:CycleOrder(container)
	local order, used = { 1 }, { [1] = true }
	local function Add(tabIndex)
		if tabIndex and container.windows[tabIndex] and not used[tabIndex] then
			used[tabIndex] = true
			order[#order + 1] = tabIndex
		end
	end

	Add(self:GroupTabIndex(container))
	for guildIndex = 1, 5 do
		local name = GuildTabName(guildIndex)
		Add(name and FindTabByName(container, name))
	end
	for tabIndex = 2, #container.windows do
		Add(tabIndex)
	end
	return order
end

function tabs:Cycle(step)
	local container = GetContainer()
	if not container then
		return false
	end

	local count = #container.windows
	if count < 2 then
		return false
	end

	local order = self:CycleOrder(container)
	local current = self:GetActiveIndex(container)
	local position = 1
	for index, tabIndex in ipairs(order) do
		if tabIndex == current then
			position = index
			break
		end
	end

	local nextIndex = order[((position - 1 + step) % #order) + 1]
	-- The indicator itself reports the new tab. Avoid adding a second announcement to normal chat.
	return self:SelectTab(nextIndex, false)
end

function tabs:PrintStatus()
	local container = GetContainer()
	if not container then
		Print("no chat container")
		return
	end

	local window = self.indicator
	Print("indicator %s, hidden %s, size %s", tostring(window ~= nil),
		tostring(window and window:IsHidden()), tostring(addon.sv and addon.sv.tabTextSize))

	local chat = type(ZO_GetChatSystem) == "function" and ZO_GetChatSystem()
	Print("tabs %d, active %d, guild tabs %s, guilds %d", #container.windows,
		self:GetActiveIndex(container), tostring(addon.sv and addon.sv.guildTabsEnabled),
		GetNumGuilds and GetNumGuilds() or -1)

	-- Whether a tab exists and whether it can be seen are different questions, and the answer so
	-- far is "no visible change", which both would produce. Minimised is the suspect: the console
	-- chat sits collapsed during play, and the tabs are children of the container that collapses.
	Print("container hidden %s, minimised %s, HUD %s",
		tostring(container.control and container.control:IsHidden()),
		tostring(chat and chat.isMinimized), tostring(chat and chat.hudEnabled))

	for index = 1, #container.windows do
		local tab = container.windows[index].tab
		local label = tab and tab.GetNamedChild and tab:GetNamedChild("Text")
		local parent = tab and tab:GetParent()
		Print("  %d: %s w %s h %s a %s hidden %s", index, tostring(container:GetTabName(index)),
			tostring(tab and tab:GetWidth()), tostring(tab and tab:GetHeight()),
			tostring(tab and tab:GetAlpha()), tostring(tab and tab:IsHidden()))
		Print("     parent %s (hidden %s, a %s), label %s (hidden %s, a %s)",
			tostring(parent and parent.GetName and parent:GetName()),
			tostring(parent and parent:IsHidden()), tostring(parent and parent:GetAlpha()),
			tostring(label ~= nil), tostring(label and label:IsHidden()),
			tostring(label and label:GetAlpha()))
	end
	for _, slot in ipairs(self:GuildSlots()) do
		Print("  guild %d %s: in normal tab %s", slot.index, tostring(slot.name),
			tostring(self:IsGuildInMainTab(slot.guildId)))
	end
end
