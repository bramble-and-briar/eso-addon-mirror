if AutoRecruit == nil then AutoRecruit = {} end
local AR = AutoRecruit

function AR.MakeMenu()

	local guilds = {}

	for guild = 1, GetNumGuilds() do
		table.insert(guilds, GetGuildName(GetGuildId(guild)))
	end

	local panelData = {
    type = "panel",
    name = "Auto Recruit",
    displayName = "Auto Recruit",
    author = "|c6C00FFpeniku8|r, |c4444CCSirNightstorm|r",
    version = AR.version,
    --slashCommand = "/autorecruit",
    registerForRefresh = true,
    registerForDefaults = true,
    website = "https://www.esoui.com/downloads/info2571-AutoRecruit.html",
	}

  local function currentGuild()
    return AR.getGuildIndex(AR.getIDfromName(AR.settings.recruitFor))
  end

  -- LibAddonMenu2 wiki: https://github.com/sirinsidiator/ESO-LibAddonMenu/wiki/Controls
  local optionsTable = {
    {
      type = "header",
      name = "Display Settings",
      width = "full",
    },
    {
      type = "checkbox",
      name = "Chat Notifications",
      tooltip = "Enable chat notifications",
      getFunc = function()
        return AR.settings.notifications
      end,
      setFunc = function(value)
        AR.settings.notifications = value
      end,
      width = "full",
      default = AR.defaults.notifications,
    },
    {
      type = "checkbox",
      name = "Guild Trader Notification",
      tooltip = "Notifies you when your guild has no guild trader",
      getFunc = function()
        return AR.settings.trader
      end,
      setFunc = function(value)
        AR.settings.trader = value
      end,
      width = "full",
      default = AR.defaults.trader,
    },
    {
      type = "slider",
      name = "Space Warning",
      tooltip = "Notifies you when your guild is almost full. 0 = off",
      min = 0,
      max = 20,
      step = 1,
      getFunc = function()
        return AR.settings.warning
      end,
      setFunc = function(value)
        AR.settings.warning = value
      end,
      width = "full",
      default = AR.defaults.warning,
    },
    {
      type = "checkbox",
      name = "Show Info Overlay",
      tooltip = "Display a status information message onscreen",
      getFunc = function()
        return AR.settings.shown
      end,
      setFunc = function(value)
        AR.settings.shown = value
      end,
      width = "full",
      default = AR.defaults.shown,
    },

    {
      type = "checkbox",
      name = "Show Pending Applications on Overlay",
      tooltip = "List a pending applications count on the info overlay",
      getFunc = function()
        return AR.settings.showPending
      end,
      setFunc = function(value)
        AR.settings.showPending = value
      end,
      width = "full",
      default = AR.defaults.showPending,
    },

    {
      type = "dropdown",
      name = "Zones Grid",
      tooltip = "A grid of zones: green = posted & on cooldown, grey = inaccessible)",
      choices = { "Hidden", "Automatic", "Always show" },
      getFunc = function()
        return AR.settings.showZonesGrid
      end,
      setFunc = function(value)
        AR.settings.showZonesGrid = value
        AR.RefreshWindow()
      end,
      width = "full",
      default = AR.defaults.showZonesGrid,
    },


    {
      type = "header",
      name = "Teleporter Settings",
      width = "full",
    },
    {
      type = "dropdown",
      name = "Auto-Port mode:",
      tooltip = "Manual: Port to the next zone via keybind\nSemi-auto: Automatically port to the next zone once the recruitment message is sent to the zone chat\nFull-auto: Continuously port through the zones without stopping",
      choices = { "Manual", "Semi-auto", "Full-auto" },
      getFunc = function()
        return AR.settings.portMode
      end,
      setFunc = function(value)
        AR.settings.portMode = value
      end,
      width = "full",
      default = AR.defaults.portMode,
    },
    {
      type = "dropdown",
      name = "Included zones:",
      tooltip = "Major: main base and DLC chapter zones\nAll: all public map zones",
      choices = { "Major", "All" },
      getFunc = function()
        return AR.settings.includedZones
      end,
      setFunc = function(value)
        AR.settings.includedZones = value
        AR.getZones()
      end,
      width = "full",
      default = AR.defaults.includedZones,
    },
    {
      type = "checkbox",
      name = "Post recruitment ad upon arrival",
      getFunc = function()
        return AR.settings.postAd
      end,
      setFunc = function(value)
        AR.settings.postAd = value
      end,
      width = "full",
      default = AR.defaults.postAd,
    },
    {
      type = "checkbox",
      name = "Skip zones on cooldown",
      tooltip = "Don't port to zones which you've recently posted an ad to",
      getFunc = function()
        return AR.settings.skipZoneOnCD
      end,
      setFunc = function(value)
        AR.settings.skipZoneOnCD = value
      end,
      width = "full",
      default = AR.defaults.skipZoneOnCD,
    },
    {
      type = "dropdown",
      name = "Destination Priority",
      tooltip = "When there is both a player and a house in the target zone, which to pick first?",
      choices = { "Players first", "Houses first" },
      choicesValues = { false, true },
      getFunc = function()
        return AR.settings.prioritisePortToHouse
      end,
      setFunc = function(value)
        AR.settings.prioritisePortToHouse = value
        AR.RefreshWindow()
      end,
      width = "full",
      default = AR.defaults.prioritisePortToHouse,
    },
    {
      type = "checkbox",
      name = "Multiple rounds",
      tooltip = "Teleport through all zones again after a certain time",
      getFunc = function()
        return AR.settings.keepPorting
      end,
      setFunc = function(value)
        AR.settings.keepPorting = value
      end,
      width = "full",
      default = AR.defaults.keepPorting,
    },
    {
      type = "slider",
      name = "Multiple rounds cooldown",
      tooltip = "How long to wait after every round",
      min = 1,
      max = 60,
      step = 1,
      getFunc = function()
        return AR.settings.portingTime
      end,
      setFunc = function(value)
        AR.settings.portingTime = value
      end,
      width = "full",
      default = AR.defaults.portingTime,
    },
    {
      type = "checkbox",
      name = "Write skipped zones to chat",
      tooltip = "Write messages to the Chat window when skipping a zone",
      getFunc = function()
        return AR.settings.logSkippedZones
      end,
      setFunc = function(value)
        AR.settings.logSkippedZones = value
      end,
      width = "full",
      default = AR.defaults.logSkippedZones,
    },

    {
      type = "header",
      name = "Whisper Auto-Recruiting",
      width = "full",
    },
    {
      type = "checkbox",
      name = "Enabled",
      tooltip = "Enable Whisper Auto-Recruiting",
      getFunc = function()
        return AR.settings.whisperEnabled
      end,
      setFunc = function(value)
        AR.settings.whisperEnabled = value
      end,
      width = "full",
      default = AR.defaults.whisperEnabled,
    },
    {
      type = "checkbox",
      name = "Standard Keywords",
      tooltip = "Listen to keywords like 'invite' 'inv' '+' 'join' and more",
      getFunc = function()
        return AR.settings.standardEnabled
      end,
      setFunc = function(value)
        AR.settings.standardEnabled = value
      end,
      disabled = function() return not AR.settings.whisperEnabled end,
      width = "full",
      default = AR.defaults.standardEnabled,
    },
    {
      type = "editbox",
      name = "Keyword",
      tooltip = "Check received whispers for this keyword",
      getFunc = function()
        return AR.settings.keyword
      end,
      setFunc = function(value)
        AR.settings.keyword = value
      end,
      disabled = function() return not AR.settings.whisperEnabled end,
      isMultiline = false,
      width = "full",
      default = AR.defaults.keyword,
    },
    {
      type = "checkbox",
      name = "Case Sensitive",
      tooltip = "Make your keyword case sensitive",
      getFunc = function()
        return AR.settings.caseSensitive
      end,
      setFunc = function(value)
        AR.settings.caseSensitive = value
      end,
      disabled = function() return not AR.settings.whisperEnabled end,
      width = "full",
      default = AR.defaults.caseSensitive,
    },

    {
      type = "header",
      name = "Active Guild",
      width = "full",
    },
    {
      type = "dropdown",
      name = "Recruit for:",
      tooltip = "Select the guild you want to recruit for",
      choices = guilds,
      getFunc = function() return AR.settings.recruitFor end,
      setFunc = function(value) AR.settings.recruitFor = value end,
      width = "full",
      default = guilds[1]
    },

    {
      type = "header",
      name = function() return AR.settings.recruitFor end,
      width = "full",
    },
    {
      type = "checkbox",
      name = "Chat Notifications",
      getFunc = function() return AR.settings.guild[currentGuild()] end,
      setFunc = function(value) AR.settings.guild[currentGuild()] = value end,
      width = "full",
      default = false,
    },
    {
      type = "editbox",
      name = "Recruitment Message",
      tooltip = function()
        if string.len(AR.settings.ad[currentGuild()]) > 0 then
          return "Quickly paste this to your chat via keybind:\n\n" .. AR.settings.ad[currentGuild()]
        end
      end,
      getFunc = function() return AR.settings.ad[currentGuild()] end,
      setFunc = function(value) AR.settings.ad[currentGuild()] = value end,
      isMultiline = true,
      isExtraWide = true,
      width = "full",
      default = "",
    },
    {
      type = "checkbox",
      name = "Enable Welcome Message",
      tooltip = "Enable automatically pasting the following welcome message into guild chat when a new member is recruited",
      getFunc = function() return AR.settings.welcome[currentGuild()] end,
      setFunc = function(value) AR.settings.welcome[currentGuild()] = value end,
      width = "full",
      default = false,
    },
    {
      type = "editbox",
      name = "Welcome Message",
      tooltip = function()
        return "Message automatically pasted into guild chat when a new member is recruited.\n\n" .. AR.settings.welcomeText[currentGuild()]
      end,
      getFunc = function() return AR.settings.welcomeText[currentGuild()] end,
      setFunc = function(value) AR.settings.welcomeText[currentGuild()] = value end,
      isMultiline = true,
      isExtraWide = true,
      width = "full",
      default = "",
    },
    {
      type = "slider",
      name = "Welcome message cooldown",
      tooltip = "Set a cooldown in minutes to not spam the guild chat",
      min = 0,
      max = 60,
      step = 1,
      getFunc = function() return AR.settings.welcomeCooldown[currentGuild()] end,
      setFunc = function(value) AR.settings.welcomeCooldown[currentGuild()] = value end,
      width = "full",
      default = 30,
    },
    {
      type = "slider",
      name = "Recruitment message zone cooldown",
      tooltip = "Set a cooldown in minutes to not spam the same zone",
      min = 0,
      max = 60,
      step = 1,
      getFunc = function() return AR.settings.adCooldown[currentGuild()] end,
      setFunc = function(value) AR.settings.adCooldown[currentGuild()] = value end,
      width = "full",
      default = 30,
    },
    {
      type = "dropdown",
      name = "Welcome Mail",
      --tooltip = "Manual: Open a mail to the last recruit using a keybind\nAutomatic: Opens a mail to the latest recruit immediately after posting the welcome chat message",
      --choices = { "Disabled", "Manual", "Automatic" },
      tooltip = "Opens the Send Mail form to the most recent recruit, prefilled with the template information below.\n" ..
                "Ask: Offers to open the form after a welcome chat message has been sent\n" ..
                "Automatic: Automatically opens the form after a welcome chat message has been sent",
      choices = { "Disabled", "Ask", "Automatic" },
      getFunc = function()
        return AR.settings.mailMode[currentGuild()]
      end,
      setFunc = function(value)
        AR.settings.mailMode[currentGuild()] = value
      end,
      width = "full",
      default = AR.defaults.mailMode[currentGuild()],
    },
    {
      type = "editbox",
      name = "Welcome Mail Subject",
      tooltip = function()
        return "Subject copied into the Mail form\n\n" .. AR.settings.mailSubject[currentGuild()]
      end,
      getFunc = function() return AR.settings.mailSubject[currentGuild()] end,
      setFunc = function(value) AR.settings.mailSubject[currentGuild()] = value end,
      isMultiline = false,
      isExtraWide = true,
      width = "full",
      default = "",
    },
    {
      type = "editbox",
      name = "Welcome Mail Body",
      tooltip = function()
        return "Body text copied into the Mail form\n\n" .. AR.settings.mailBody[currentGuild()]
      end,
      getFunc = function() return AR.settings.mailBody[currentGuild()] end,
      setFunc = function(value) AR.settings.mailBody[currentGuild()] = value end,
      isMultiline = true,
      isExtraWide = true,
      width = "full",
      default = "",
    },
    {
      type = "description",
      text = "|cC5C29EUse the |cFFFFFF@|cC5C29E character to insert the newly recruited member's UserID into welcome text. " ..
              "Use |cFFFFFF@@|cC5C29E to include an '@' prefix before the UserID.|r"
    },
  }

  local menu = LibAddonMenu2
	local panel = menu:RegisterAddonPanel("Auto_Recruit", panelData)
	menu:RegisterOptionControls("Auto_Recruit", optionsTable)

	SLASH_COMMANDS["/autorecruit"] = function(extra)
		if extra == "save 1" then
			AR.settings.saveLastPosted = true -- Store last posted times so that cooldowns survive /reloadui or a game restart
			d("Auto Recruit: Save last posted times: enabled")
		elseif extra == "save 0" then
			AR.settings.saveLastPosted = false
			d("Auto Recruit: Save last posted times: disabled")
		else
			menu:OpenToPanel(panel)
		end
	end
end