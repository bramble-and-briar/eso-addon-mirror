-- PBS_CHAT_ASSISTANT is nil if Main.lua bailed out early (the add-on was already loaded).
if not PBS_CHAT_ASSISTANT then
	return
end

local addon = PBS_CHAT_ASSISTANT

local function AddHeading(settings, LibHarvensAddonSettings, label)
	settings:AddSetting({
		type = LibHarvensAddonSettings.ST_SECTION or LibHarvensAddonSettings.ST_LABEL,
		label = label,
	})
end

-- The wait, and nothing else.
--
-- It is the only setting a player has any reason to reach for. Everything else -- arming Enter,
-- releasing the keyboard again, the arrow keys, the focus watcher, the log -- is either on
-- because it should be, or a diagnostic, and a panel of switches that are already right is just
-- somewhere to make a mistake. The slash commands still reach all of them.
--
-- The wait is different because the right value is a property of the machine rather than of the
-- add-on. Too short and the chat box opens without the console's input screen following, which
-- is the one failure that looks like the add-on is broken rather than mistuned.
function addon:InitSettings()
	local LibHarvensAddonSettings = LibHarvensAddonSettings
	if not LibHarvensAddonSettings then
		return
	end

	local settings = LibHarvensAddonSettings:AddAddon(self.title)
	if not settings then
		return
	end

	self.settingsControls = settings
	settings.allowDefaults = true
	settings.author = self.author
	settings.version = self.version

	-- L2+D-pad Right on the HUD. Reaches the same setting as /pbchat hudchannel.
	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHATASSISTANT_HUDCHANNEL),
			tooltip = GetString(SI_PBSCHATASSISTANT_HUDCHANNEL_TOOLTIP),
			default = true,
			getFunction = function()
				return self.sv.hudChannelEnabled
			end,
			setFunction = function(value)
				self.sv.hudChannelEnabled = value
			end
		}
	)

	-- Guild tabs, and whether the normal tab still carries their chat.
	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHATASSISTANT_GUILDTABS),
			tooltip = GetString(SI_PBSCHATASSISTANT_GUILDTABS_TOOLTIP),
			default = true,
			getFunction = function()
				return self.sv.guildTabsEnabled
			end,
			setFunction = function(value)
				self.sv.guildTabsEnabled = value
				if self.chatTabs then
					if value then
						self.chatTabs:Reconcile()
					else
						self.chatTabs:RemoveAll()
					end
				end
			end
		}
	)

	-- LibHarvens rows have fixed labels. This panel is therefore built on the first
	-- EVENT_PLAYER_ACTIVATED, when the guild list is available, and only joined guilds get rows.
	-- Capture the guild ID rather than its slot so the switch keeps referring to the same guild if
	-- the game's slot order changes while the panel exists. This is the same pattern as ChatFilter.
	local guilds = self.chatTabs and self.chatTabs:GuildSlots() or {}
	if #guilds == 0 then
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_LABEL,
				label = GetString(SI_PBSCHATASSISTANT_GUILD_EMPTY),
			}
		)
	else
		for _, guild in ipairs(guilds) do
			local guildId = guild.guildId
			settings:AddSetting({
				type = LibHarvensAddonSettings.ST_CHECKBOX,
				label = zo_strformat(GetString(SI_PBSCHATASSISTANT_GUILDINMAIN), guild.name),
				tooltip = GetString(SI_PBSCHATASSISTANT_GUILDINMAIN_TOOLTIP),
				default = true,
				getFunction = function()
					return not self.chatTabs or self.chatTabs:IsGuildInMainTab(guildId)
				end,
				setFunction = function(value)
					if self.chatTabs then
						self.chatTabs:SetGuildInMainTab(guildId, value)
					end
				end
			})
		end
	end

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHATASSISTANT_TAB_VISIBLE),
			tooltip = GetString(SI_PBSCHATASSISTANT_TAB_VISIBLE_TOOLTIP),
			default = true,
			getFunction = function()
				return self.sv.tabNameVisible ~= false
			end,
			setFunction = function(value)
				self.sv.tabNameVisible = value
				if self.chatTabs then
					self.chatTabs:RefreshStrip()
				end
			end
		}
	)

	-- Where the active-tab name sits. Sliders rather than a command, because nudging something into
	-- place is exactly what a slider is for.
	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCHATASSISTANT_TABSTRIP_X),
			tooltip = GetString(SI_PBSCHATASSISTANT_TABSTRIP_POS_TOOLTIP),
			min = -800,
			max = 800,
			step = 10,
			default = 0,
			format = "%d",
			unit = "",
			getFunction = function()
				return self.sv.tabStripX
			end,
			setFunction = function(value)
				self.sv.tabStripX = value
				if self.chatTabs then
					self.chatTabs:PositionStrip()
				end
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCHATASSISTANT_TABSTRIP_Y),
			tooltip = GetString(SI_PBSCHATASSISTANT_TABSTRIP_POS_TOOLTIP),
			min = 0,
			max = 1000,
			step = 10,
			default = 110,
			format = "%d",
			unit = "",
			getFunction = function()
				return self.sv.tabStripY
			end,
			setFunction = function(value)
				self.sv.tabStripY = value
				if self.chatTabs then
					self.chatTabs:PositionStrip()
				end
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCHATASSISTANT_TAB_TEXT_SIZE),
			tooltip = GetString(SI_PBSCHATASSISTANT_TAB_TEXT_SIZE_TOOLTIP),
			min = 14,
			max = 72,
			step = 1,
			default = 28,
			format = "%d",
			unit = "",
			getFunction = function()
				return self.sv.tabTextSize
			end,
			setFunction = function(value)
				self.sv.tabTextSize = value
				if self.chatTabs then
					self.chatTabs:PositionStrip()
				end
			end
		}
	)

	local tabLayerItems = {
		{ name = GetString(SI_PBSCHATASSISTANT_TAB_LAYER_BACKGROUND), data = { value = "background" } },
		{ name = GetString(SI_PBSCHATASSISTANT_TAB_LAYER_CONTROLS), data = { value = "controls" } },
		{ name = GetString(SI_PBSCHATASSISTANT_TAB_LAYER_TEXT), data = { value = "text" } },
		{ name = GetString(SI_PBSCHATASSISTANT_TAB_LAYER_OVERLAY), data = { value = "overlay" } },
	}
	local function TabLayerName()
		local wanted = self.sv.tabTextLayer or "text"
		for _, item in ipairs(tabLayerItems) do
			if item.data.value == wanted then
				return item.name
			end
		end
		return tabLayerItems[3].name
	end

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCHATASSISTANT_TAB_LAYER),
			tooltip = GetString(SI_PBSCHATASSISTANT_TAB_LAYER_TOOLTIP),
			items = tabLayerItems,
			default = tabLayerItems[3].name,
			getFunction = TabLayerName,
			setFunction = function(_, _, item)
				self.sv.tabTextLayer = item.data.value
				if self.chatTabs then
					self.chatTabs:PositionStrip()
				end
			end
		}
	)

	-- Which channel a session starts on.
	--
	-- The item list is rebuilt whenever this panel is opened rather than fixed when the add-on
	-- loads. At load the player may not be in a guild yet as far as the client is concerned, and a
	-- guild channel is exactly what someone wants to default to; built then, the list would offer
	-- slash commands instead of guild names, or miss the channels entirely.
	local channelItems = {}
	local NO_DEFAULT = GetString(SI_PBSCHATASSISTANT_DEFAULT_CHANNEL_NONE)

	local function DefaultChannelName()
		local wanted = self.sv.defaultChannel or 0
		if wanted == 0 then
			return NO_DEFAULT
		end
		return self:GetChannelDisplayName(wanted)
	end

	local function RebuildChannelItems()
		ZO_ClearNumericallyIndexedTable(channelItems)
		channelItems[1] = { name = NO_DEFAULT, data = { value = 0 } }
		for _, channel in ipairs(self:GetSelectableChannels()) do
			channelItems[#channelItems + 1] = {
				name = self:GetChannelDisplayName(channel.id),
				data = { value = channel.id },
			}
		end
	end

	RebuildChannelItems()

	CALLBACK_MANAGER:RegisterCallback(
		"LibHarvensAddonSettings_AddonSelected",
		function(_, addonSettings)
			if addonSettings == settings then
				RebuildChannelItems()
			end
		end
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSCHATASSISTANT_DEFAULT_CHANNEL),
			tooltip = GetString(SI_PBSCHATASSISTANT_DEFAULT_CHANNEL_TOOLTIP),
			items = channelItems,
			default = NO_DEFAULT,
			getFunction = DefaultChannelName,
			setFunction = function(combobox, name, item)
				self.sv.defaultChannel = item.data.value
				-- Applied at once as well as at login, so choosing it does something visible
				-- rather than only mattering next time.
				self:ApplyDefaultChannel()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCHATASSISTANT_DELAY),
			tooltip = GetString(SI_PBSCHATASSISTANT_DELAY_TOOLTIP),
			min = 0,
			max = 2000,
			step = 50,
			default = 100,
			format = "%d",
			unit = "ms",
			getFunction = function()
				return self.sv.delayMs
			end,
			setFunction = function(value)
				self.sv.delayMs = value
			end
		}
	)

	-- Keep the filter sections after every existing setting. LibHarvens treats following rows as
	-- belonging to the most recent heading, so placing them earlier folds unrelated rows into them.
	-- Chat history. Placed before the filter sections, under its own heading for the same reason.
	if self.chatHistory then
		local history = self.chatHistory
		AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCHATASSISTANT_HISTORY_SECTION))
		settings:AddSetting({
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHATASSISTANT_HISTORY),
			tooltip = GetString(SI_PBSCHATASSISTANT_HISTORY_TOOLTIP),
			default = true,
			getFunction = function()
				return self.sv.historyEnabled ~= false
			end,
			setFunction = function(value)
				self.sv.historyEnabled = value
			end,
		})
		settings:AddSetting({
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCHATASSISTANT_HISTORY_COUNT),
			tooltip = GetString(SI_PBSCHATASSISTANT_HISTORY_COUNT_TOOLTIP),
			min = history.MIN_COUNT,
			max = history.MAX_COUNT,
			step = 10,
			default = 50,
			format = "%d",
			getFunction = function()
				return history:MaxCount()
			end,
			setFunction = function(value)
				self.sv.historyCount = value
				history:Trim()
			end,
		})
		settings:AddSetting({
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCHATASSISTANT_HISTORY_MINUTES),
			tooltip = GetString(SI_PBSCHATASSISTANT_HISTORY_MINUTES_TOOLTIP),
			min = history.MIN_MINUTES,
			max = history.MAX_MINUTES,
			step = 5,
			default = 60,
			format = "%d",
			unit = GetString(SI_PBSCHATASSISTANT_HISTORY_MINUTES_UNIT),
			getFunction = function()
				return math.floor(history:MaxAgeSeconds() / 60)
			end,
			setFunction = function(value)
				self.sv.historyMinutes = value
			end,
		})
	end

	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCHATASSISTANT_RECRUIT_SECTION))
	settings:AddSetting({
		type = LibHarvensAddonSettings.ST_LABEL,
		label = GetString(SI_PBSCHATASSISTANT_RECRUIT_NOTE),
	})
	settings:AddSetting({
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = GetString(SI_PBSCHATASSISTANT_RECRUIT),
		tooltip = GetString(SI_PBSCHATASSISTANT_RECRUIT_TOOLTIP),
		default = false,
		getFunction = function()
			return self.sv.recruitFilterEnabled == true
		end,
		setFunction = function(value)
			self.sv.recruitFilterEnabled = value
		end,
	})
	settings:AddSetting({
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = GetString(SI_PBSCHATASSISTANT_RECRUIT_WHISPER),
		tooltip = GetString(SI_PBSCHATASSISTANT_RECRUIT_WHISPER_TOOLTIP),
		default = false,
		getFunction = function()
			return self.sv.recruitFilterWhispers == true
		end,
		setFunction = function(value)
			self.sv.recruitFilterWhispers = value
		end,
	})

	AddHeading(settings, LibHarvensAddonSettings, GetString(SI_PBSCHATASSISTANT_NPC_SECTION))
	settings:AddSetting({
		type = LibHarvensAddonSettings.ST_LABEL,
		label = GetString(SI_PBSCHATASSISTANT_NPC_NOTE),
	})
	settings:AddSetting({
		type = LibHarvensAddonSettings.ST_CHECKBOX,
		label = GetString(SI_PBSCHATASSISTANT_NPC),
		tooltip = GetString(SI_PBSCHATASSISTANT_NPC_TOOLTIP),
		default = false,
		getFunction = function()
			return self.sv.npcChatFilterEnabled == true
		end,
		setFunction = function(value)
			self.sv.npcChatFilterEnabled = value
		end,
	})
end
