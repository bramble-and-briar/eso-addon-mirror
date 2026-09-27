--[[ ## New API, (v101041), Global Variables and Functions needed for this addons Overhaul (3.18.2024) by @Dr_Z ## ]]--
--[[ ## DEBUGGED for 101050 101051 by @Dr_Z   ## ]]--
--[[ ## Last Updated:	9.26.2026  by @Dr_Z	## ]]--
RaffleGold = {
	db = nil,
	name = "RaffleGold",
	THIS_ADDON = "RaffleGold",
	ADDON_NAME = "Raffle Gold",
	ADDON_DISPLAY_NAME = "|cFFFFFFRaffle |cb38600Gold|r",
	ADDON_AUTHOR = "@Dr_Z, depeshmood",
	ADDON_VERSION = "26.51.00",
	ADDON_WEBSITE = "https://www.esoui.com/downloads/info3826-RaffleGold.html",
	lastDeposit = nil,
	defaults = {
		building = false,
		raffleType = "",
		totalEntries = "",
		totalAmount = "",
		entryPrice = "1000",
		ticketPrice = nil,
		bonusTickets = nil,
		placeFirst = "30",
		placeSecond = "15",
		placeThird = "5",
		startAmt = "",
		dateStart = "-",
		dateEnd = "-",
		timeStart = "-",
		timeEnd = "-",
		restriction = "Multiple",
		prizes = {}
	}
}

---------------------------
-- Here's the MENU Section.  I know, I know, blah blah blah
---------------------------
function RaffleGold:Menu()
	local LAM2 = LibAddonMenu2
	self.db = ZO_SavedVars:NewAccountWide("RaffleGold_SavedVars", 1, nil, self.defaults)

-- Vars for NEW Guild Name and Guild Rank Custom Name Dropdown Menus		-- added 7.1-2.2026 by @Dr_Z
	local g_list_C = nil
	local g_list_C__val = nil
	local Guild_list_Choices, Guild_list_ChoiceValues = RaffleGold:Get_Guild_Menu_Choices(g_list_C, g_list_C__val)
	local gR_list_C = nil
	local gR_list_C_val = nil
	local GuildRank_list_Choices, GuildRank_list_ChoiceValues = self:Get_GuildRank_Menu_Choices(gR_list_C, gR_list_C_val)
	if self.db and self.db.guild then
		GuildRank_list_Choices, GuildRank_list_ChoiceValues = self:Get_GuildRank_Menu_Choices(self.db.guild)
	end
	local panelData = {
		type = "panel",
		name = self.ADDON_NAME,
		displayName = RaffleGold.ADDON_DISPLAY_NAME.."  |t24:24:esoui/art/icons/item_generic_coinBag.dds|t",
		author = "|cFFF1B8"..self.ADDON_AUTHOR.."|r",
		version = "|cFFF1B8"..self.ADDON_VERSION.."|r",
		website = self.ADDON_WEBSITE,
		slashCommand = "/rafflegold",
		registerForRefresh = true,
		registerForDefaults = true,
	}
	LAM2:RegisterAddonPanel(self.THIS_ADDON .. "LAM2Options", panelData)
	local optionsTable = {
		{
			type = "header",
			name = "|cFFF1B8Global Raffle Settings|r",
			width = "full",
		},
		{
			type = "description",
			text = RaffleGold.ADDON_DISPLAY_NAME .. " will display any error messages and the results of the raffle drawing in the chat window."
		},
		{
			type = "editbox",
			name = "Entry Price     $",
			tooltip = "The amount for each entry into the raffle.",
			width = "full",
			default = self.defaults.entryPrice,
			getFunc = function() return self.db.entryPrice end,
			setFunc = function(choice) self.db.entryPrice = choice end,
		},
		{
			type = "editbox",
			name = "1st Place     %",
			tooltip = "The percentage that the first place winner wins from the total amount.",
			width = "full",
			default = self.defaults.placeFirst,
			getFunc = function() return self.db.placeFirst end,
			setFunc = function(choice) self.db.placeFirst = choice end
		},
		{
			type = "button",
			name = "Draw 1st Place",
			tooltip = "This will select only the first place winner.",
			width = "full",
			warning = "This will only select a winning number for 1st place!",
			func = function() self:DrawRaffle(true, "frt") CHAT_SYSTEM:Maximize() end
		},
		{
			type = "editbox",
			name = "2nd Place     %",
			tooltip = "The percentage that the second place winner wins from the total amount.",
			width = "full",
			default = self.defaults.placeSecond,
			getFunc = function() return self.db.placeSecond end,
			setFunc = function(choice) self.db.placeSecond = choice end
		},
		{
			type = "button",
			name = "Draw 2nd Place",
			tooltip = "This will select only the second place winner.",
			width = "full",
			warning = "This will only select a winning number for 2nd place!",
			func = function() self:DrawRaffle(true, "scd") CHAT_SYSTEM:Maximize() end
		},
		{
			type = "editbox",
			name = "3rd Place     %",
			tooltip = "The percentage that the third place winner wins from the total amount.",
			width = "full",
			default = self.defaults.placeThird,
			getFunc = function() return self.db.placeThird end,
			setFunc = function(choice) self.db.placeThird = choice end
		},
		{
			type = "button",
			name = "Draw 3rd Place",
			tooltip = "This will select only the third place winner.",
			width = "full",
			warning = "This will only select a winning number for 3rd place!",
			func = function() self:DrawRaffle(true, "trd") CHAT_SYSTEM:Maximize() end
		},
		{
			type = "header",
			name = "|cFFF1B8Basic Raffle Drawing|r",
			width = "full",
		},
		{
			type = "editbox",
			name = "Total Entries",
			tooltip = "This is the total number of entries for the raffle, but should only be used if not pulling from the guild bank's deposit history.",
			width = "full",
			default = self.defaults.totalEntries,
			getFunc = function() return self.db.totalEntries end,
			setFunc = function(choice) self.db.totalEntries = choice end
		},
		{
			type = "editbox",
			name = "Total Amount     $",
			tooltip = "The grand total dollar amount.\n(if not using \"Entry Price\" above)",
			width = "full",
			default = self.defaults.totalAmount,
			getFunc = function() return self.db.totalAmount end,
			setFunc = function(choice) self.db.totalAmount = choice end
		},
		{
			type = "button",
			name = "Draw Raffle",
			tooltip = "This will select winning raffle ticket numbers only, based on the information above.\nThis will NOT include any of the \"Guild Bank Raffle Drawing\" settings and/or guild bank deposits.",
			width = "half",
			func = function() self:DrawRaffle(true) CHAT_SYSTEM:Maximize() end
		},
		{
			type = "button",
			name = "Display Results",
			tooltip = "This will display the winners from the last time \"Draw Raffle\" was run.",
			width = "half",
			func = function() self:DrawRaffle(true, "d") CHAT_SYSTEM:Maximize() end
		},
		{
			type = "header",
			name = "|cFFF1B8Guild Bank Raffle Drawing|r",
			width = "full",
		},
-- NEW Dropdown Guild Name list. Also Checks Guild Gold View Permissions		 -- Changed and Added 6.12.2026 - Updated 7.2.2026 by @Dr_Z
-- Sets a Color to Guild name.  GREEN Text = Has Permissions.  RED Text = NO Permissions
		{
			type = "dropdown",
			name = "Guild",
			tooltip = "Select a Guild to do Raffles.\nIf Guild Name is in RED, You do NOT have permissions to Scan for Gold Deposits in that Guild.",
			choices = Guild_list_Choices,
			choicesValues = Guild_list_ChoiceValues,
			default = "-",
			getFunc = function() return self.db.guild end,
			setFunc = function(choice)
				self.db.guild = choice
				self.db.guildRank = 0
				GuildRank_list_Choices, GuildRank_list_ChoiceValues = self:Get_GuildRank_Menu_Choices(choice)
				RaffleGoldGuildRank:UpdateChoices(GuildRank_list_Choices, GuildRank_list_ChoiceValues)
			end,
		},
-- NEW Dropdown Guild Rank Name list.							-- Changed and Added 7.2.2026 by @Dr_Z
 		{
			type = "dropdown",
			name = "Exclude Guild Rank(s) ",
			tooltip = "SET Guild Rank(s) to Exclude\n(Ranks in RED text are Excluded) ",
			choices = GuildRank_list_Choices,
			choicesValues = GuildRank_list_ChoiceValues,
			reference = "RaffleGoldGuildRank",
			default = "-",
			getFunc = function() return self.db.guildRank end,
			setFunc = function(choice) 
				self.db.guildRank = choice
				GuildRank_list_Choices, GuildRank_list_ChoiceValues = self:Get_GuildRank_Menu_Choices(self.db.guild, self.db.guildRank)
				RaffleGoldGuildRank:UpdateChoices(GuildRank_list_Choices, GuildRank_list_ChoiceValues)
				RaffleGoldGuildRank:UpdateValue(false)
			end,
		},
-- END --
		{
			type = "editbox",
			name = "Starting Amount     $",
			tooltip = "This is the base amount being offered, without any raffle tickets even being purchased.",
			width = "full",
			default = self.defaults.startAmt,
			getFunc = function() return self.db.startAmt end,
			setFunc = function(choice) self.db.startAmt = choice end
		},
		{
			type = "dropdown",
			name = "Starting Date",
			tooltip = "This is the date that entries started being deposited for the raffle.",
			width = "full",
			choices = self:CreateDates(),
			default = self.defaults.dateStart,
			getFunc = function() return self.db.dateStart end,
			setFunc = function(choice) self.db.dateStart = choice end
		},
		{
			type = "dropdown",						-- Changed and Added  6.7.2026 by @Dr_Z
			name = "Starting Time",
			tooltip = "This is the time that entries started being deposited.",
			width = "full",
			choices = {"12 midnite", "1 am", "2 am", "3 am", "4 am", "5 am", "6 am", "7 am", "8 am", "9 am", "10 am", "11 am", "12 noon", 
					"1 pm", "2 pm", "3 pm", "4 pm", "5 pm", "6 pm", "7 pm", "8 pm", "9 pm", "10 pm", "11 pm"},
			choicesValues = {"0:00", "1:00", "2:00", "3:00", "4:00", "5:00", "6:00", "7:00", "8:00", "9:00", "10:00", "11:00", "12:00", 
					"13:00", "14:00", "15:00", "16:00", "17:00", "18:00", "19:00", "20:00", "21:00", "22:00", "23:00"},	
			default = self.defaults.timeStart,
			getFunc = function() return self.db.timeStart end,
			setFunc = function(choice) self.db.timeStart = choice end
		},
		{
			type = "dropdown",
			name = "Ending Date",
			tooltip = "This is the date that the entries finished being deposited for the raffle.",
			width = "full",
			choices = self:CreateDates(),
			default = self.defaults.dateEnd,
			getFunc = function() return self.db.dateEnd end,
			setFunc = function(choice) self.db.dateEnd = choice end
		},
		{
			type = "dropdown",						-- Changed and Added 6.7.2026 by @Dr_Z
			name = "Ending Time",
			tooltip = "Any deposits made after this time, on the Ending Date, will be excluded from this raffle.",
			width = "full",
			choices = {"12 midnite", "1 am", "2 am", "3 am", "4 am", "5 am", "6 am", "7 am", "8 am", "9 am", "10 am", "11 am", "12 noon", 
					"1 pm", "2 pm", "3 pm", "4 pm", "5 pm", "6 pm", "7 pm", "8 pm", "9 pm", "10 pm", "11 pm"},
			choicesValues = {"0:00", "1:00", "2:00", "3:00", "4:00", "5:00", "6:00", "7:00", "8:00", "9:00", "10:00", "11:00", "12:00", 
					"13:00", "14:00", "15:00", "16:00", "17:00", "18:00", "19:00", "20:00", "21:00", "22:00", "23:00"},	
			default = self.defaults.timeEnd,
			getFunc = function() return self.db.timeEnd end,
			setFunc = function(choice) self.db.timeEnd = choice end
		},
		{ 
			type = "dropdown",
			name = "Prizes Per Username",
			tooltip = "The number of allowed prizes per username.\nOne: Can only win one of the 3 places\nMultiple: First ticket # drawn",
			width = "full",
			choices = {"One", "Multiple"},
			default = self.defaults.restriction,
			getFunc = function() return self.db.restriction end,
			setFunc = function(choice) self.db.restriction = choice end
		},
		{
			type = "button",
			name = "Guild Raffle",
			tooltip = "This will select winners based on the deposits made into the guild bank and will not use the \"Basic Raffle Drawing\" settings.",
			width = "half",
			func = function() self:GuildRaffle() CHAT_SYSTEM:Maximize() end
		},
		{
			type = "button",
			name = "Display Results",
			tooltip = "This will display the winners from the last time \"Guild Raffle\" was run.",
			width = "half",
			func = function() self:GuildResults() CHAT_SYSTEM:Maximize() end
		},
		{
			type = "description",
			text = "Please note: If the guild is large enough and has enough transactions via the guild bank, it might take a few seconds, or so, to build the database.\nThere will be a message in the chat window letting you know that it has finished.\n\nThe guild bank's history is limited to 10 days, including today, and is only able to obtain information 9 days into the past. You will need to run this within that timeframe in order to retrieve any results.\n\nThe SavedVariables\\RaffleGold.lua file contains any of the entered information above and will also populate the guild entrants, which will need to be parsed if you would like to view and/or display them anywhere.\n\nTo open this menu, type: /rafflegold\nTo access the slash commands, type: /rg <COMMAND> (For example: /rg help)"
		}
	}
	LAM2:RegisterOptionControls(self.THIS_ADDON .. "LAM2Options", optionsTable)
end

--------------------------------------------------------
-- Lets find all guilds we're in
--------------------------------------------------------
function RaffleGold:GetGuilds(gName)
	local guilds = {}
	guilds[1] = "-"
	local guild_ct = 1
	if GetNumGuilds() > 0 then
		for guild_ct = 1, GetNumGuilds() do
			local guildId = GetGuildId(guild_ct)
			local guildName = GetGuildName(guildId)
			if(not guildName or (guildName):len() < 1) then
				guildName = "Guild " .. guildId
			end
			if gName ~= nil and gName == guildName then
				return guildId
			end
			guilds[guild_ct + 1] = guildName
		end
	end
	return guilds
end

-------------------------------------------------------------------
--  Get Number of Guilds and Guild Names for Dropdown Settings Menu			-- Added  6.11.2026 by @Dr_Z
--  with Color Coding which Guild Player has Permissions to View Guild Gold Depsoits
-------------------------------------------------------------------
function RaffleGold:Get_Guild_Menu_Choices(gNames)
	local Guild_list_Choices = {}
	local Guild_list_ChoiceValues = {}
	local g_count = 1
	for g_count = 1, GetNumGuilds() do
		local guildID =  GetGuildId(g_count)
		local guildName = GetGuildName(GetGuildId(g_count))
		local hasGoldViewPerm = DoesPlayerHaveGuildPermission(guildID, GUILD_PERMISSION_BANK_VIEW_DEPOSIT_HISTORY)
		if not hasGoldViewPerm then
			Guild_list_Choices[#Guild_list_Choices + 1] = "|cFF3333"..guildName.."|r"
		else
			Guild_list_Choices[#Guild_list_Choices + 1] = "|cB9FF00"..guildName.."|r"
		end
		Guild_list_ChoiceValues[#Guild_list_ChoiceValues + 1] = guildName
	end
	return Guild_list_Choices, Guild_list_ChoiceValues
end

-------------------------------------------------------------------
--  Get Number of Guild Ranks and Guild Rank Names for Dropdown Settings Menu		-- Added  7.2.2026 by @Dr_Z
--  Also, Lets check to see if User has Rank Permissions to scan Guild.
-------------------------------------------------------------------
function RaffleGold:Get_GuildRank_Menu_Choices(guildName)
	local selectedRank = tonumber(self.db.guildRank) or 0
	local GuildRank_list_Choices = {}
	local GuildRank_list_ChoiceValues = {}
    -- ** No Guild Selected - Set Ranks to Default
	if guildName == nil or guildName == "-" then
		GuildRank_list_Choices[1] = "-"
		GuildRank_list_ChoiceValues[1] = 0
		return GuildRank_list_Choices, GuildRank_list_ChoiceValues
	end
    -- ** Get GUILD(s) Id(s)
	local guildId = nil
	local guildIndex = 1
	for guildIndex = 1, GetNumGuilds() do
		local id = GetGuildId(guildIndex)
		if GetGuildName(id) == guildName then
			guildId = id
		end
	end
    -- ** No guildId - Set Ranks to Default
	if not guildId then
		GuildRank_list_Choices[1] = "-"
		GuildRank_list_ChoiceValues[1] = 0
		return GuildRank_list_Choices, GuildRank_list_ChoiceValues
	end
    -- ** SET First Default, Dummy Rank dropdown entry in Settings Menu
	GuildRank_list_Choices[1] = "-"
	GuildRank_list_ChoiceValues[1] = 0
    -- ** SET Guild Ranks by Default Rank Names or Custom Rank Names for the dropdown menu
    	local drI = 1	-- drI means defualtRankIndex
	local rI  = 1	-- rI means rankIndex
	for rI = 1, GetNumGuildRanks(guildId) do
		local rankName = GetGuildRankCustomName(guildId, rI)
		if rankName == "" then
			-- ** Custom Rank Name is Empty, Then Check for Default Rank ID's and Give it a Name
			local default_Rank_ID = GetGuildRankId(guildId, rI)
			if default_Rank_ID == 255 then
				rankName = "Guildmaster"
			elseif default_Rank_ID == 254 then
				rankName = "Officer"
			elseif default_Rank_ID == 2 then
				rankName = "Member"
			elseif default_Rank_ID == 1 then
				rankName = "Recruit"
			else
				-- Nothing Left to Check --
			end
		end
	     -- ** Color Code Rank Names for Exclusions: Red Text = Excluded,  Green Text = NOT Excluded
		if rI <= selectedRank then
			rankName = "|cFF3333"..rankName.."|r"
		else
			rankName = "|cB9FF00"..rankName.."|r"
		end
		--GuildRank_list_Choices[#GuildRank_list_Choices + 1] = GetGuildRankCustomName(guildId, rI)
		GuildRank_list_Choices[#GuildRank_list_Choices + 1] = rankName
		GuildRank_list_ChoiceValues[#GuildRank_list_ChoiceValues + 1] = rI
	end
	return GuildRank_list_Choices, GuildRank_list_ChoiceValues
end

----------------------------
-- Lets Draw for the Raffle
----------------------------
function RaffleGold:DrawRaffle(out, p)
	m = nil
	if out == true and p == nil then
		self.db.prizes = {}
		self.db.raffleType = "draw"
	end
	if out == true and p ~= nil and self.db.raffleType == "guild" then
		return self:GuildRaffle(p)
	end
	nums = {
		entAmt = tonumber(self.db.entryPrice),
		entries = tonumber(self.db.totalEntries),
		pFrt = tonumber(self.db.placeFirst),
		pScd = tonumber(self.db.placeSecond),
		pTrd = tonumber(self.db.placeThird),
		tktAmt = tonumber(self.db.ticketPrice),
		totAmt = tonumber(self.db.totalAmount)
	}
	--d("self.db.totalEntries")
	--d(self.db.totalEntries)
	if out == true and (nums.entries == nil or nums.entries < 1) then
		m = "Total Entries"
		if self.db.totalEntries ~= nil and self.db.totalEntries ~= "" then
			m = "Valid " .. m
		end
	elseif out == true and (nums.totAmt == nil and nums.entAmt == nil) then
		m = "Total Amount or Entry Price"
	elseif out == true and self.db.totalAmount ~= nil and self.db.totalAmount ~= "" and (nums.totAmt == nil or nums.totAmt < 1) then
		m = "Valid Total Amount"
	elseif self.db.entryPrice ~= nil and self.db.entryPrice ~= "" and (nums.entAmt == nil or nums.entAmt < 1) then
		m = "Valid Entry Price"
	elseif out == true and nums.totAmt ~= nil and nums.entAmt ~= nil and (nums.entries * nums.entAmt) ~= nums.totAmt then
		m = "Valid Total Amount vs Entries and Entry Price"
	elseif self.db.ticketPrice ~= nil and self.db.ticketPrice ~= "" and (nums.tktAmt == nil or nums.tktAmt < 1 or nums.tktAmt >= nums.entAmt or (zo_round(nums.entAmt / nums.tktAmt) * nums.tktAmt) ~= nums.entAmt) then
		m = "Valid Price Per Ticket"
	elseif (p == nil or p == "frt") and (nums.pFrt == nil or nums.pFrt < 1) then
		m = "First Place Percentage"
		if self.db.placeFirst ~= nil and self.db.placeFirst ~= "" then
			m = "Valid " .. m
		end
	elseif (p == nil or p == "scd") and nums.pScd == nil then
		m = "Second Place Percentage"
		if self.db.placeSecond ~= nil and self.db.placeSecond ~= "" then
			m = "Valid " .. m
		end
	elseif (p == nil or p == "trd") and nums.pTrd == nil then
		m = "Third Place Percentage"
		if self.db.placeThird ~= nil and self.db.placeThird ~= "" then
			m = "Valid " .. m
		end
	end
	if m ~= nil then
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000Required: " .. m .. "\r")
		return false
	end
	if out == false then
		return true
	end
	eAmt = nums.entries
	if nums.tktAmt ~= nil then
		eAmt = (zo_round(nums.entAmt / nums.tktAmt) * nums.entries)
	end
	if nums.totAmt ~= nil then
		tAmt = nums.totAmt
	else
		tAmt = nums.entAmt * nums.entries
	end
	sysMes = ""
	if p ~= "d" then
		sysMes = " -- \nTotal Raffle Tickets: " .. eAmt
		if eAmt ~= nums.entries then
			sysMes = sysMes .. " (Total Entries: " .. nums.entries .. ")"
		end
		sysMes = sysMes .. ", Total Amount: $" .. tAmt
	end
	if p == nil or p == "frt" or (p == "d" and self.db.prizes.numFrt ~= nil) then
		if p ~= "d" then
			self.db.prizes.numFrt = math.random(1, eAmt)
			while self.db.prizes.numScd == self.db.prizes.numFrt or self.db.prizes.numTrd == self.db.prizes.numFrt do
				self.db.prizes.numFrt = math.random(1, eAmt)
			end
			self.db.prizes.amtFrt = zo_round((nums.pFrt * .01) * tAmt)
		end
		sysMes = sysMes .. " -- \n1st Place: Ticket # " .. self.db.prizes.numFrt .. " won $" .. self.db.prizes.amtFrt
	end
	if ((p == nil or p == "scd") and nums.pScd > 0 and eAmt > 1) or (p == "d" and self.db.prizes.numScd ~= nil) then
		if p ~= "d" then
			self.db.prizes.numScd = zo_round(math.random(1, eAmt))
			while self.db.prizes.numScd == self.db.prizes.numFrt or self.db.prizes.numTrd == self.db.prizes.numScd do
				self.db.prizes.numScd = math.random(1, eAmt)
			end
			self.db.prizes.amtScd = zo_round((nums.pScd * .01) * tAmt)
		end
		sysMes = sysMes .. " -- \n2nd Place: Ticket # " .. self.db.prizes.numScd .. " won $" .. self.db.prizes.amtScd
	end
	if ((p == nil or p == "trd") and nums.pScd > 0 and nums.pTrd > 0 and eAmt > 2) or (p == "d" and self.db.prizes.numTrd ~= nil) then
		if p ~= "d" then
			self.db.prizes.numTrd = zo_round(math.random(1, eAmt))
			while self.db.prizes.numTrd == self.db.prizes.numFrt or self.db.prizes.numTrd == self.db.prizes.numScd do
				self.db.prizes.numTrd = math.random(1, eAmt)
			end
			self.db.prizes.amtTrd = zo_round((nums.pTrd * .01) * tAmt)
		end
		sysMes = sysMes .. " -- \n3rd Place: Ticket # " .. self.db.prizes.numTrd .. " won $" .. self.db.prizes.amtTrd
	end
	if out == true then
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. sysMes)
	end
	return true
end

----------------------------
-- Guild Raffle Stuff
----------------------------
function RaffleGold:GuildRaffle(p)
	if p == nil then
		self.db.prizes = {
			eAmt = nil,
			entries = nil,
			tAmt = nil,
			numFrt = nil,
			amtFrt = nil,
			nameFrt = nil,
			numScd = nil,
			amtScd = nil,
			nameScd = nil,
			numTrd = nil,
			amtTrd = nil,
			nameTrd = nil,
			drawDate = nil
		}
		self.db.raffleType = "guild"
	end
	m = nil
	if self:DrawRaffle(false) == false then
		return
	end
	if self.db.guild == nil or self.db.guild == "-" then
		m = "Guild"
	end
	stAmt = tonumber(self.db.startAmt)
	if self.db.startAmt ~= "" and stAmt == nil then
		m = "Valid Starting Amount"
	end
	if self.db.dateStart == nil or self.db.dateStart == "-" then
		m = "Starting Date"
	end
	if self.db.timeStart == nil or self.db.timeStart == "-" then
		m = "Start/End Time"
	end
	if m ~= nil then
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000Required: " .. m .. "\r")
		return false
	end
	sT = self:StartDate(self.db.dateStart, self.db.timeStart)
	if sT == nil then
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642Starting Date is out of range!\r|r")
		return
	end
	eT = self:StartDate(self.db.dateEnd, self.db.timeEnd)
	if eT == nil then
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642Ending Date is out of range!\r|r")
		return
	end
	if sT >= eT then
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000REQUIRED: Valid starting and ending date/time.\r\n(Ending Date/Time cannot be the same or less than Starting Date/Time)")
		return
	end
	cT = GetTimeStamp()
	guildId = self:GetGuilds(self.db.guild)
	numEvents = self:BuildHistory(guildId, sT, cT, nil, eT)
	
	if numEvents == nil or numEvents == 0 then
	--d(sT) d(self.lastDeposit)
	--d(numEvents) d(guildId)
   -- ** Added  6.11.2026 by @Dr_Z	
	-- ** Check to see if We have Permissions to SCAN Guild Gold History					
		local playersName, _, playersRankIndex, _, _ = GetGuildMemberInfo( guildId, GetPlayerGuildMemberIndex(guildId))
		local playersRankHasPerm = DoesGuildRankHavePermission(guildId, playersRankIndex, GUILD_PERMISSION_BANK_VIEW_GOLD)
	--	--d("#1") d(playersName) d(playersRankIndex)
		if not playersRankHasPerm then
			--d("#1 message")
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ":")
			CHAT_SYSTEM:AddMessage("|cFF0000ERROR: |cf5e642You do NOT have the proper permissions \nto scan |cFFFFFF"..self.db.guild.."'s|r Gold Deposits.|r")
			return false
		end
-- END
		if self.lastDeposit ~= nil or self.lastDeposit ~= 0 then
			--d(self.lastDeposit)
			m = "Older transactions found for " .. self.db.guild .. ".\r\n"
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: " .. m .. "\n |cf5e642Must wait till Newer transactions get logged.|r")
			return false
		elseif numEvents == 0 then
			m = "Collecting raffle entries for " .. self.db.guild .. ".\r\n"
		else
			m = "No raffle entries were found!\r\nIf you feel this is in error, "
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: " .. m .. " Then wait for the addon to build the database and try again.|r")
			return false
		end
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: " .. m .. "|cf5e642Please wait for the addon to build the database and try again.|r")
		return false
	end
	
	nums = {
		entries = 0,
		entAmt = tonumber(self.db.entryPrice),
		pFrt = tonumber(self.db.placeFirst),
		pScd = tonumber(self.db.placeSecond),
		pTrd = tonumber(self.db.placeThird),
		tktAmt = tonumber(self.db.ticketPrice),
		tktPerEnt = "",
		totAmt = 0
	}
	if nums.tktAmt == nil or self.db.ticketPrice == "" then
		nums.tktAmt = nums.entAmt
	end

	if nums.entAmt == nil then
		CHAT_SYSTEM:AddMessage( "|cFF0000ERROR:|r|cf5e642 YOU MUST SET a Value for \"Entry Price \$\"\r|r")
		return
	else 
		nums.tktPerEnt = nums.entAmt / nums.tktAmt
	end
	n = 1
	nn = 1
	depositInfo = {}
	entries = {}
	usernames = {}
	userRanks = {}
	self.db.prizes.entrants = {}

   -- ** For Loop Overhauled (3.18.2024) by @Dr_Z	
	for tIndex=numEvents, 1, -1 do
		_, secondsSinceDeposit, _, eventType, depositerName, _, amount, _ = GetGuildHistoryBankedCurrencyEventInfo(guildId,tIndex)
		depositerName = "@" .. depositerName
	--	tS = cT - secondsSinceDeposit
		tS = secondsSinceDeposit
		if nums.entAmt ~= nil then
			tP = amount / nums.entAmt
		end
		if eventType == GUILD_HISTORY_BANKED_CURRENCY_EVENT_DEPOSITED and zo_round(tP) * nums.entAmt == amount and tS >= sT and tS <= eT then
			tP = self:TicketCount(tP, amount)
			depositInfo[n] = { tS, tIndex, tP , depositerName, amount }
			userRanks[depositerName] = depositerName
			n = n + 1
		end
	end
	if self.db.guildRank ~= nil and self.db.guildRank ~= "-" then
		userRanks = self:CheckGuildRank(guildId, self.db.guildRank, userRanks)
	end
	table.sort(depositInfo, function(a, b) return a[1] < b[1] end)
	n = 1
	oC = 0
	for k,v in ipairs(depositInfo) do								-- TICKET Generator
		if self.db.guildRank == nil or self.db.guildRank == "-" or userRanks[v[4]] == false then
			nums.totAmt = nums.totAmt + v[5]
			nums.entries = nums.entries + 1
			tP = v[3] * nums.tktPerEnt
			tckNums = n
			if tP > 1 then
				tckNums = tckNums .. "-" .. (n + tP - 1)
			end
			self.db.prizes.entrants[nn] = {
				entryNum = nn,
				userName = v[4],
				tickets = tP,
				depositAmount = v[5],
				ticketNums = tckNums,
				timestamp = v[1]
			}
			nn = nn + 1
			for i=1, tP, 1 do
				entries[n] = { name = v[4] }
				n = n + 1
			end
			usernames[v[4]] = v[4]
		else
			oC = oC + v[5]
		end
	end
	if oC > 0 then
		self.db.prizes.oContrib = oC
	end
	usercount = nil
	if self.db.restriction == "One" then
		usercount = 0
		for _ in pairs(usernames) do usercount = usercount + 1 end
		if usercount > 0 then CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- Unique # of usernames: " .. usercount) end
	end
	n = n-1
	if eT > cT then
		if stAmt ~= nil then
			nums.totAmt = nums.totAmt + stAmt
		end
		local playersName, _, playersRankIndex, _, _ = GetGuildMemberInfo( guildId, GetPlayerGuildMemberIndex(guildId))
		local playersRankHasPerm = DoesGuildRankHavePermission(guildId, playersRankIndex, GUILD_PERMISSION_BANK_VIEW_GOLD)
		--d("#2") d(playersName) d(playersRankIndex) d(playersRankHasPerm)
		if playersRankHasPerm then
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \nGuild: " .. self.db.guild .. " -- \nCurrent Entries: " .. nums.entries .. " -- \nCurrent Tickets: " .. n .. " -- \nCurrent Amount: $" .. nums.totAmt .. " -- \nTime Remaining: " .. self:RemainingTime(eT - cT) .. "\r")
			return
		else
			--d("#2 message")
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ":")
			CHAT_SYSTEM:AddMessage("|cFF0000ERROR: |cf5e642You do NOT have the proper permissions \nto scan |cFFFFFF"..self.db.guild.."'s|r Gold Deposits.|r")
			return
		end
	end
	eAmt = nums.entries
	if eAmt == 0 then
     -- ** Added  6.11.2026 by @Dr_Z
	-- ** Check to see if We have Permissions to SCAN Guild Gold History
		local guildId = self:GetGuilds(self.db.guild)
		local playersName, _, playersRankIndex, _, _ = GetGuildMemberInfo( guildId, GetPlayerGuildMemberIndex(guildId))
		local playersRankHasPerm = DoesGuildRankHavePermission(guildId, playersRankIndex, GUILD_PERMISSION_BANK_VIEW_GOLD)
		--d("#3") d(playersName) d(playersRankIndex)
		if not playersRankHasPerm then
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ":")
			CHAT_SYSTEM:AddMessage("|cFF0000ERROR: |cf5e642You do NOT have the proper permissions \nto scan |cFFFFFF"..self.db.guild.."'s|r Gold Deposits.|r")
			return
		else
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642No entries were found.\r|r")
			return false
		end
	end
	if n > nums.entries then
		eAmt = n
	end
	if nums.totAmt ~= nil then
		tAmt = nums.totAmt
	else
		tAmt = nums.entAmt * nums.entries
	end
	if stAmt ~= nil then
		tAmt = tAmt + stAmt
	end
	if p == nil then
		self.db.prizes.eAmt = eAmt
		self.db.prizes.entries = nums.entries
		self.db.prizes.tAmt = tAmt
		self.db.prizes.drawDate = GetDateStringFromTimestamp(eT)
	end
	sysMes = " -- \nTotal Raffle Tickets: " .. eAmt
	if eAmt ~= nums.entries then
		sysMes = sysMes .. " (Total Entries: " .. nums.entries .. ")"
	end
	sysMes = sysMes .. ", Total Amount: $" .. tAmt .. ", Drawing: " .. self.db.prizes.drawDate
	if p == nil or p == "frt" then
		self.db.prizes.numFrt = math.random(1, eAmt)
		while self.db.prizes.numScd == self.db.prizes.numFrt or self.db.prizes.numTrd == self.db.prizes.numFrt or (usercount ~= nil and ((self.db.prizes.nameScd ~= nil and entries[self.db.prizes.numFrt].name == self.db.prizes.nameScd) or (self.db.prizes.nameTrd ~= nil and entries[self.db.prizes.numFrt].name == self.db.prizes.nameTrd))) do
			self.db.prizes.numFrt = math.random(1, eAmt)
		end
		self.db.prizes.amtFrt = zo_round((nums.pFrt * .01) * tAmt)
		self.db.prizes.nameFrt = entries[self.db.prizes.numFrt].name
		sysMes = sysMes .. " -- \n1st Place: " .. self.db.prizes.nameFrt .. ", ticket # " .. self.db.prizes.numFrt .. ", won $" .. self.db.prizes.amtFrt
	end
	if (p == nil or p == "scd") and nums.pScd > 0 and eAmt > 1 and (usercount == nil or usercount >= 2) then
		self.db.prizes.numScd = zo_round(math.random(1, eAmt))
		while self.db.prizes.numScd == self.db.prizes.numFrt or self.db.prizes.numTrd == self.db.prizes.numScd or (usercount ~= nil and ((self.db.prizes.nameFrt ~= nil and entries[self.db.prizes.numScd].name == self.db.prizes.nameFrt) or (self.db.prizes.nameTrd ~= nil and entries[self.db.prizes.numScd].name == self.db.prizes.nameTrd))) do
			self.db.prizes.numScd = math.random(1, eAmt)
		end
		self.db.prizes.amtScd = zo_round((nums.pScd * .01) * tAmt)
		self.db.prizes.nameScd = entries[self.db.prizes.numScd].name
		sysMes = sysMes .. " -- \n2nd Place: " .. self.db.prizes.nameScd .. ", ticket # " .. self.db.prizes.numScd .. ", won $" .. self.db.prizes.amtScd
	end
	if (p == nil or p == "trd") and nums.pScd > 0 and nums.pTrd > 0 and eAmt > 2 and (usercount == nil or usercount >= 3) then
		self.db.prizes.numTrd = zo_round(math.random(1, eAmt))
		while self.db.prizes.numTrd == self.db.prizes.numFrt or self.db.prizes.numTrd == self.db.prizes.numScd or (usercount ~= nil and ((self.db.prizes.nameFrt ~= nil and entries[self.db.prizes.numTrd].name == self.db.prizes.nameFrt) or (self.db.prizes.nameScd ~= nil and entries[self.db.prizes.numTrd].name == self.db.prizes.nameScd))) do
			self.db.prizes.numTrd = math.random(1, eAmt)
		end
		self.db.prizes.amtTrd = zo_round((nums.pTrd * .01) * tAmt)
		self.db.prizes.nameTrd = entries[self.db.prizes.numTrd].name
		sysMes = sysMes .. " -- \n3rd Place: " .. self.db.prizes.nameTrd .. ", ticket # " .. self.db.prizes.numTrd .. ", won $" .. self.db.prizes.amtTrd
	end
	CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \nGuild: " .. self.db.guild .. sysMes)
	CHAT_SYSTEM:AddMessage("(\"Display Results\" will show the guild earnings)")
end

--------------------------------------------------------------
-- Post results to Guild Chat
--------------------------------------------------------------
function RaffleGold:GuildResults()
	if self.db.prizes.numFrt == nil then
		return false
	end
	if self.db.raffleType == "draw" or self.db.prizes.nameFrt == nil then
		self:DrawRaffle(true)
		return false
	end

	eAmt = self.db.prizes.eAmt
	entries = self.db.prizes.entries
	tAmt = self.db.prizes.tAmt
	gAmt = tAmt

	sysMes = " -- \nTotal Raffle Tickets: " .. eAmt
	if eAmt ~= entries then
		sysMes = sysMes .. " (Total Entries: " .. entries .. ")"
	end
	sysMes = sysMes .. ", Total Amount: $" .. tAmt .. ", Drawing: " .. self.db.prizes.drawDate
	sysMes = sysMes .. " -- \n1st Place: " .. self.db.prizes.nameFrt .. ", ticket # " .. self.db.prizes.numFrt .. ", won $" .. self.db.prizes.amtFrt
	gAmt = gAmt - self.db.prizes.amtFrt
	if self.db.prizes.nameScd ~= nil then
		sysMes = sysMes .. " -- \n2nd Place: " .. self.db.prizes.nameScd .. ", ticket # " .. self.db.prizes.numScd .. ", won $" .. self.db.prizes.amtScd
		gAmt = gAmt - self.db.prizes.amtScd
	end
	if self.db.prizes.nameTrd ~= nil then
		sysMes = sysMes .. " -- \n3rd Place: " .. self.db.prizes.nameTrd .. ", ticket # " .. self.db.prizes.numTrd .. ", won $" .. self.db.prizes.amtTrd
		gAmt = gAmt - self.db.prizes.amtTrd
	end
	CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \nGuild: " .. self.db.guild .. sysMes .. " -- \nGuild Earned: $".. gAmt)
end

------------------------------------------------------------
-- Lets build some Dates, Times, Start, and End of Raffle Gold Deposit Collections
function RaffleGold:CreateDates(d)
	-- OLD CODE
--[[	sD = GetTimeStamp() - (86400 * 10)
	rD = {}
	rD[1] = "-"
	n = 2
	for i=1, 21, 1 do
END OLD CODE 
]]--
	-- ** NEW Code to gather 30 Days of Gold Deposits Thanks to @MisterKarnos
	sD = GetTimeStamp() - (86400 * 30)
	rD = {}
	rD[1] = "-"
	n = 2
	for i=1, 41, 1 do
	--END New Code
		t = sD + (86400 * i)
		if d == GetDateStringFromTimestamp(t) then
			return t
		else
			rD[n] = GetDateStringFromTimestamp(t)
			n = n+1
		end
	end
	if d ~= nil then
		return nil
	end
	return rD
end

------------------------------
-- This function Not being used.  Leave Here. Might have to use it for future updates.
function RaffleGold:CreateTimes()
	rT = {}
	rT[1] = "-"
	for i=0, 23, 1 do
		rT[i+2] = i .. ":00"
	end
	return rT
end

-------------------------------
function RaffleGold:StartDate(sD, sT)
	sD = self:CreateDates(sD)
	if sD == nil then return nil end
	cT = {}
	cT.time = GetTimeString(sD)
	cT.hour, cT.min, cT.sec = cT.time:match("([^%:]+):([^%:]+):([^%:]+)")
	cT.sel, cT.sMin = sT:match("([^%:]+):([^%:]+)")
	sD = sD - (cT.min * 60) - cT.sec + ((tonumber(cT.sel) - tonumber(cT.hour)) * 60 * 60)
	return sD
end

--------------------------------
function RaffleGold:BuildHistory(gID, sT, cT, tot, eT)					-- Overhauled (3.18.2024) by @Dr_Z	
	if self.defaults.building == true and tot == nil then return nil end
	local nE = GetNumGuildHistoryEvents(gID, GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY)
	if tot == nil and (nE == 0 or eT > cT) then
		self.defaults.building = true
	--	RequestMoreGuildHistoryCategoryEvents(gID, GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY)
		if nE == 0 then
			zo_callLater(function()
				RaffleGold:BuildHistory(gID, sT, cT, 0)
			end, 1500)
			return nil
		elseif GetNumGuildHistoryEvents(gID, GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY) > nE then
			zo_callLater(function()
				RaffleGold:GetRecentHistory(gID, cT)
			end, 1500)
			return nil
		end
	end
	local _, secondsSinceDeposit, _, eventType, depositerName, _, amount, _ = GetGuildHistoryBankedCurrencyEventInfo(gID, GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY, nE)
	if DoesGuildHistoryHaveOutstandingRequest(gID, GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY) == true and (cT - secondsSinceDeposit) > sT then
		self.defaults.building = true
		time = 1500
		if nE > 1 then
			time = time + math.random(1, nE)
		end
	--	RequestMoreGuildHistoryCategoryEvents(gID, GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY)
		zo_callLater(function()
			RaffleGold:BuildHistory(gID, sT, cT, nE)
		end, time)
		return nil
	end
	self.defaults.building = false
	self.lastDeposit = secondsSinceDeposit
	if tot ~= nil then
	--d(tot)

	-- Added  6.11.2026 by @Dr_Z
	-- Check to see if We have Permissions to SCAN Guild Gold History
		local guildId = self:GetGuilds(self.db.guild)
		local playersName, _, playersRankIndex, _, _ = GetGuildMemberInfo( guildId, GetPlayerGuildMemberIndex(guildId))
		local playersRankHasPerm = DoesGuildRankHavePermission(guildId, playersRankIndex, GUILD_PERMISSION_BANK_VIEW_GOLD)
		--d("#4") d(playersName) d(playersRankIndex)
		if not playersRankHasPerm then
		--	--d("#4 no message")
			-- DO NOTHING. We do NOT have Permissions.
			return
		elseif self.LastDeposit == nil then
			return false
		else
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " is now ready.")
		end
	end
	return nE
end

---------------------------
-- Gather Event Histories
---------------------------
function RaffleGold:GetRecentHistory(gID, cT)						-- Overhauled (3.18.2024) by @Dr_Z	
	local nE = GetNumGuildHistoryEvents(gID, GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY)
	d("ct")
	d(ct)
	local _, secondsSinceDeposit, _, _, _, _, _, _ = GetGuildHistoryBankedCurrencyEventInfo(gID, GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY, nE)
	if DoesGuildHistoryCategoryHaveMoreEvents(gID, GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY) == true and (cT - secondsSinceDeposit) >= self.lastDeposit then
		self.defaults.building = true
		local time = 1500
		if nE > 1 then
			time = time + math.random(1, nE)
		end
	--	RequestMoreGuildHistoryCategoryEvents(gID, GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY)
		zo_callLater(function()
			RaffleGold:GetRecentHistory(gID, cT)
		end, time)
		return nil
	end
	self.defaults.building = false
	CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " is now ready. code 2")
end

-----------------------------
-- Get Guild Ranks
-----------------------------
function RaffleGold:CheckGuildRank(gID, rank, users)
	local memberCount = GetNumGuildMembers(gID)
	if memberCount ~= 0 then
		for mIndex=1, memberCount, 1 do
			cName, _, cRank, _, _ = GetGuildMemberInfo(gID, mIndex)
			if cName ~= nil and users[cName] ~= nil then
				if cRank <= rank then
					users[cName] = true
				else
					users[cName] = false
				end
			end
		end
	end
	return users
end

-----------------------------
-- How Much Time before Raffle Drawing
-----------------------------
function RaffleGold:RemainingTime(t)
	local days = 0
	local hours = 0
	local mins = 0
	while t > 86400 do
		days = days + 1
		t = t - 86400
	end
	while t > 3600 do
		hours = hours + 1
		t = t - 3600
	end
	while t > 60 do
		mins = mins + 1
		t = t - 60
	end
	return days .. "d " .. hours .. "h " .. mins .. "m"
end

------------------------
-- Convert those nasty Strings into Numbers
------------------------
function RaffleGold:ConvertNumber(amt, c)
	if c ~= nil and tonumber(amt) ~= nil then
		return amt
	end
	if tonumber(amt) ~= nil then
		lamt = tonumber(amt)
		if amt >= 1000000 then
			amt = amt / 1000000
			return amt .. "M"
		elseif amt >= 1000 then
			amt = amt / 1000
			return amt .. "k"
		end
	else
		if string.find(string.lower(amt), "m") then
			amt = tonumber(string.sub(amt, 0, string.find(string.lower(amt), "m") - 1))
			if amt == nil then
				return false
			end
			return amt * 1000000
		elseif string.find(string.lower(amt), "k") then
			amt = tonumber(string.sub(amt, 0, string.find(string.lower(amt), "k") - 1))
			return amt * 1000
		end
	end
	return amt
end

-----------------------
-- Generate Tickets and get totals
-----------------------
function RaffleGold:TicketCount(tickets, amount)
	if self.db.bonusTickets == nil or amount <= 0 then return tickets end
	for k,v in pairs(self.db.bonusTickets["amount"]) do
		if amount >= v[1] then
			tickets = tickets + v[2]
			amount = amount - v[1]
			if self.db.bonusTickets.multi == false then return (tickets) end
			return RaffleGold:TicketCount(tickets, amount)
		end
	end
	return tickets
end

-----------------------
-- Slash Commands, Oh'My....
-----------------------
function RaffleGold.Cmd(txt)
	if txt == "" then
		CHAT_SYSTEM:AddMessage("|cFFFFFF____________________________________")
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ': type "/rg help" for a list of commands.')
		return
	end
	arr = {}
	i = 1
	for val in string.gmatch(txt,"%w+") do
		arr[i] = val
	    i = i + 1
	end
	if txt == "help" or arr[1] == "help" or arr[2] == "help" then
		if arr[2] == "help" then
			arr[2] = arr[1]
		end
		CHAT_SYSTEM:AddMessage("|cFFFFFF____________________________________")
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " commands:")
		if arr[2] == "set" then
			CHAT_SYSTEM:AddMessage('/rg set entry price <AMOUNT> - Sets the "Entry Price"')
			CHAT_SYSTEM:AddMessage('/rg set ticket price <AMOUNT> - Sets the "Ticket Price"')
			CHAT_SYSTEM:AddMessage('/rg set first place <PERCENT> - Sets the "1st Place" percentage')
			CHAT_SYSTEM:AddMessage('/rg set second place <PERCENT> - Sets the "2nd Place" percentage')
			CHAT_SYSTEM:AddMessage('/rg set third place <PERCENT> - Sets the "3rd Place" percentage')
			CHAT_SYSTEM:AddMessage('/rg set total entries <AMOUNT> - Sets the "Total Entries" for Basic Raffle')
			CHAT_SYSTEM:AddMessage('/rg set total amount <AMOUNT> - Sets the "Total Amount $" for Basic Raffle')
			CHAT_SYSTEM:AddMessage('/rg set guild <GUILD_NAME> - Sets the "Guild" for Guild Bank Raffle (case sensitive)')
			CHAT_SYSTEM:AddMessage('/rg set rank <GUILD_RANK_NUMBER> - Sets the "Exclude Guild Rank(s)" for Guild Bank Raffle (numeric value)')
			CHAT_SYSTEM:AddMessage('/rg set start amount <AMOUNT> - Sets the "Starting Amount $" for Guild Bank Raffle')
			CHAT_SYSTEM:AddMessage('/rg set start date <M/D/YYYY> - Sets the "Starting Date" for Guild Bank Raffle')
			CHAT_SYSTEM:AddMessage('/rg set start time <H:MM> - Sets the "Starting Time" for Guild Bank Raffle (military format)')
			CHAT_SYSTEM:AddMessage('/rg set end date <M/D/YYYY> - Sets the "Ending Date" for Guild Bank Raffle')
			CHAT_SYSTEM:AddMessage('/rg set end time <H:MM> - Sets the "Ending Time" for Guild Bank Raffle (military format)')
			CHAT_SYSTEM:AddMessage('/rg set prizes <One OR Multiple> - Sets the number of prizes a username can win per raffle')
			CHAT_SYSTEM:AddMessage('/rg set bonus <AMOUNT> <QUANTITY> - Gives QUANTITY of free tickets when AMOUNT of tickets purchased, per deposit, not username')
			CHAT_SYSTEM:AddMessage('/rg set bonus multi <YES or NO> - Sets whether a deposit can receive multiple bonuses, default is "YES"')
		elseif arr[2] == "draw" then
			CHAT_SYSTEM:AddMessage('/rg draw basic - This will draw the Basic Raffle')
			CHAT_SYSTEM:AddMessage('/rg basic results - Results from the last Basic Raffle drawing')
			CHAT_SYSTEM:AddMessage("/rg draw guild - This will run the Guild Bank Raffle\n(In-progress displays information; Ended displays winners)")
			CHAT_SYSTEM:AddMessage('/rg guild results - Results from the last Guild Bank Raffle drawing\n(A new draw will overwrite this information)')
			CHAT_SYSTEM:AddMessage("/rg entry <ENTRY_NUMBER> - Displays username, number of tickets, ticket numbers and amount deposited")
			CHAT_SYSTEM:AddMessage("/rg entry <USERNAME> - Displays all entries for the username")
			CHAT_SYSTEM:AddMessage("/rg draw first - This will draw only the 1st place winner")
			CHAT_SYSTEM:AddMessage("/rg draw second - This will draw only the 2nd place winner")
			CHAT_SYSTEM:AddMessage("/rg draw third - This will draw only the 3rd place winner")
		elseif arr[2] == "list" then
			CHAT_SYSTEM:AddMessage('/rg list entry price - Displays the "Entry Price" amount')
			CHAT_SYSTEM:AddMessage('/rg list ticket price - Displays the "Price per Ticket" amount')
			CHAT_SYSTEM:AddMessage('/rg list percents - Displays the percentages for 1st, 2nd and 3rd')
			CHAT_SYSTEM:AddMessage('/rg list first place - Displays the "1st Place" percentage')
			CHAT_SYSTEM:AddMessage('/rg list second place - Displays the "2nd Place" percentage')
			CHAT_SYSTEM:AddMessage('/rg list third place - Displays the "3rd Place" percentage')
			CHAT_SYSTEM:AddMessage('/rg list basic settings - Displays the "Basic Raffle" specific settings')
			CHAT_SYSTEM:AddMessage('/rg list total entries - Displays the "Total Entries" for the Basic Raffle')
			CHAT_SYSTEM:AddMessage('/rg list total amount - Displays the "Total Amount" for the Basic Raffle')
			CHAT_SYSTEM:AddMessage('/rg list guild settings - Displays the "Guild Bank Raffle" specific settings')
			CHAT_SYSTEM:AddMessage('/rg list guild - Displays the "Guild" for the Guild Bank Raffle')
			CHAT_SYSTEM:AddMessage('/rg list rank - Displays the "Exclude Guild Rank(s)" for the Guild Bank Raffle')
			CHAT_SYSTEM:AddMessage('/rg list start amount - Displays the "Starting Amount" for the Guild Bank Raffle')
			CHAT_SYSTEM:AddMessage('/rg list start date - Displays the "Starting Date" for the Guild Bank Raffle')
			CHAT_SYSTEM:AddMessage('/rg list start time - Displays the "Starting Time" for the Guild Bank Raffle')
			CHAT_SYSTEM:AddMessage('/rg list end date - Displays the "Ending Date" for the Guild Bank Raffle')
			CHAT_SYSTEM:AddMessage('/rg list end time - Displays the "Ending Time" for the Guild Bank Raffle')
			CHAT_SYSTEM:AddMessage('/rg list prizes - Displays the "Prizes Per Username" for the Guild Bank Raffle')
			CHAT_SYSTEM:AddMessage('/rg list bonus - Displays all ticket purchase amounts and the number of free tickets for that amount')
		elseif arr[2] == "reset" or arr[2] == "remove" then
			CHAT_SYSTEM:AddMessage('/rg reset all - Resets ALL of the stored information')
			CHAT_SYSTEM:AddMessage('/rg reset defaults - Resets only the default UI information')
			CHAT_SYSTEM:AddMessage('/rg reset bonus - Resets all bonus ticket amounts')
			CHAT_SYSTEM:AddMessage('/rg remove bonus <AMOUNT> - Removes bonus tickets for the specified amount')
		else
			CHAT_SYSTEM:AddMessage('/rafflegold - Displays the menu UI')
			CHAT_SYSTEM:AddMessage('/rg help - Displays the list of commands')
			CHAT_SYSTEM:AddMessage('/rg help set - Displays the command settings')
			CHAT_SYSTEM:AddMessage('/rg help list - Displays the commands for showing the current setting(s)')
			CHAT_SYSTEM:AddMessage('/rg help draw - Displays the commands for drawing the raffle')
			CHAT_SYSTEM:AddMessage('/rg help reset - Displays the commands for resetting the raffle')
		end
		return
	end
	if arr[1] == "reset" and arr[2] ~= nil then
		m = "|cFF0000ERROR: |cf5e642Reset command not found.\r\nFor the list of commands, type: /rg help reset|r"
		if arr[2] == "all" or string.find(arr[2], "default") then
			if arr[2] == "all" then
				self.db.bonusTickets = nil
				m = "All default settings restored."
			else
				m = "Default settings restored, excluding items and/or winners."
			end
			m = m .. "\nIf you do not see the change(s) in the menu, type: /reloadui"
			self.db.building = self.defaults.building
			self.db.raffleType = self.defaults.raffleType
			self.db.totalEntries = self.defaults.totalEntries
			self.db.totalAmount = self.defaults.totalAmount
			self.db.entryPrice = self.defaults.entryPrice
			self.db.placeFirst = self.defaults.placeFirst
			self.db.placeSecond = self.defaults.placeSecond
			self.db.placeThird = self.defaults.placeThird
			self.db.startAmt = self.defaults.startAmt
			self.db.dateStart = self.defaults.dateStart
			self.db.dateEnd = self.defaults.dateEnd
			self.db.timeStart = self.defaults.timeStart
			self.db.timeEnd = self.defaults.timeEnd
			self.db.restriction = self.defaults.restriction
			self.db.prizes = self.defaults.prizes
		elseif string.find(arr[2], "bon") then
			self.db.bonusTickets = nil
			m = "Bonus ticket amounts have been reset."
		end
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n" .. m)
		return
	end
	if arr[1] == "remove" then
		arr[3] = tonumber(RaffleGold:ConvertNumber(arr[3], true))
		if string.find(arr[2], "bon") and self.db.bonusTickets ~= nil and self.db.bonusTickets["amount"][arr[3]] ~= nil then
			s = "s"
			if self.db.bonusTickets["amount"][arr[3]] == 1 then s = "" end
			m = "Successfully removed " .. self.db.bonusTickets["amount"][arr[3]][2] .. " bonus ticket" .. s .. " when " .. RaffleGold:ConvertNumber(self.db.bonusTickets["amount"][arr[3]][1]) .. " deposited"
			if self.db.bonusTickets["arrCount"] == 1 then
				self.db.bonusTickets = nil
			else
				table.remove(self.db.bonusTickets["amount"], arr[3])
				self.db.bonusTickets["arrCount"] = self.db.bonusTickets["arrCount"] - 1
				table.sort(self.db.bonusTickets["amount"], function(a, b) return a[1] > b[1] end)
			end
		end
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n" .. m)
		return
	end
	if arr[1] == "set" then
		if arr[2] == nil then
			m = "|cFF0000ERROR:|cf5e642 SET command missing.\r\nFor the available commands, type: /rg help Set|r"
		elseif string.find(arr[2], "ent") and arr[3] == "price" then
			arr[4] = tonumber(arr[4])
			if arr[4] == nil or arr[4] == 0 then arr[4] = self.defaults.entryPrice end
			self.db.entryPrice = arr[4]
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set the "Entry Price" to $' .. self.db.entryPrice .. "\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if string.find(arr[2], "tick") and arr[3] == "price" then
			arr[4] = tonumber(arr[4]) 
			if arr[4] == nil or arr[4] == 0 then
				self.db.ticketPrice = self.defaults.ticketPrice
				arr[4] = '<empty>'
			else
				self.db.ticketPrice = arr[4]
				arr[4] = '$' .. arr[4]
			end
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set the "Ticket Price" to ' .. arr[4] .. "\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if (arr[2] == "first" or arr[2] == "1st") and arr[3] == "place" then
			arr[4] = tonumber(arr[4])
			if arr[4] == nil or arr[4] == 0 then arr[4] = self.defaults.placeFirst end
			self.db.placeFirst = arr[4]
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set "1st Place" to ' .. self.db.placeFirst .. "%\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if (arr[2] == "second" or arr[2] == "2nd") and arr[3] == "place" then
			arr[4] = tonumber(arr[4])
			if arr[4] == nil then arr[4] = 0 end
			self.db.placeSecond = arr[4]
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set "2nd Place" to ' .. self.db.placeSecond .. "%\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if (arr[2] == "third" or arr[2] == "3rd") and arr[3] == "place" then
			arr[4] = tonumber(arr[4])
			if arr[4] == nil then arr[4] = 0 end
			self.db.placeThird = arr[4]
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set "3rd Place" to ' .. self.db.placeThird .. "%\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if string.find(arr[2], "tot") and string.find(arr[2], "ent") then
			arr[4] = tonumber(arr[4])
			if arr[4] == nil or arr[4] == 0 then
				self.db.totalEntries = self.defaults.totalEntries
				arr[4] = '<empty>'
			else
				self.db.totalEntries = arr[4]
			end
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set the "Total Entries" for the Basic Raffle to ' .. arr[4] .. "\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if string.find(arr[2], "tot") and (arr[3] == "amount" or arr[3] == "amt") then
			arr[4] = tonumber(arr[4])
			if arr[4] == nil or arr[4] == 0 then
				self.db.totalAmount = self.defaults.totalAmount
				arr[4] = '<empty>'
			else
				self.db.totalAmount = arr[4]
				arr[4] = '$' .. arr[4]
			end
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set the "Total Amount" for the Basic Raffle to ' .. arr[4] .. "\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if arr[2] == "guild" then
			if arr[3] == nil or arr[3] == "-" then
				self.db.guild = "-"
				arr[4] = '-'
			else
				n = 4
				while n < i do
					arr[3] = arr[3] .. " " .. arr[n]
					n = n + 1
				end
				if tonumber(RaffleGold:GetGuilds(arr[3])) == nil then
					CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642You are not in the guild you entered!\r\nThe guild's name is case sensitive.|r")
					return
				end
				self.db.guild = arr[3]
			end
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set the "Guild" for the Guild Bank Raffle to "' .. self.db.guild .. "\"\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if string.find(arr[2], "rank") then
			arr[3] = tonumber(arr[3])
			if arr[3] == nil or arr[3] < 1 or arr[3] > 10 then
				arr[3] = "-"
				self.db.guildRank = arr[3]
			else
				self.db.guildRank = arr[3]
				if arr[3] > 1 then arr[3] = "1-" .. arr[3] end
			end
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set the "Exclude Guild Rank(s)" for the Guild Bank Raffle to "' .. arr[3] .. "\"\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if string.find(arr[2], "start") and (arr[3] == "amount" or arr[3] == "amt") then
			arr[4] = tonumber(arr[4])
			if arr[4] == nil or arr[4] == 0 then
				self.db.startAmt = self.defaults.startAmt
				arr[4] = '<empty>'
			else
				self.db.startAmt = arr[4]
				arr[4] = '$' .. arr[4]
			end
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set the "Starting Amount" for the Guild Bank Raffle to ' .. arr[4] .. "\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if string.find(arr[2], "start") and arr[3] == "date" then
			arr[4] = tonumber(arr[4])
			arr[5] = tonumber(arr[5])
			arr[6] = tonumber(arr[6])
			if arr[4] == nil or arr[5] == nil or arr[6] == nil then
				self.db.dateStart = self.defaults.dateStart
			else
				arr[4] = arr[4] .. '/' .. arr[5] .. '/' .. arr[6]
				if RaffleGold:CreateDates(arr[4]) == nil then
					CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642Starting Date was not found!\r\nPlease make sure you are using the M/D/YYYY format.\nTo see the available date range, type: /rafflegold |r")
					return
				end
				self.db.dateStart = arr[4]
			end
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set the "Starting Date" for the Guild Bank Raffle to ' .. self.db.dateStart .. "\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if string.find(arr[2], "start") and arr[3] == "time" then
			if arr[4] == nil or arr[4] == "-" or arr[5] == nil or arr[5] == "-" then
				self.db.timeStart = self.defaults.timeStart
			else
				found = false
				arr[4] = tonumber(arr[4])
				arr[5] = tonumber(arr[5])
				if arr[4] ~= nil and arr[5] ~= nil then
					if arr[6] ~= nil and string.lower(arr[6]) == "pm" then arr[4] = arr[4] + 12 end
					if arr[4] >= 24 then arr[4] = arr[4] - 24 end
					for i=0, 23, 1 do
						if i == arr[4] then
							found = true
							break
						end
					end
				end
				if found == false then
					CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642Invalid Starting Time!\r\nThis must be in military time in the H:MM format.\nTo see the available times, type: /rafflegold |r")
					return
				end
				if arr[5] >= 30 and arr[4] < 23 then
					arr[4] = tonumber(arr[4]) + 1
				end
				self.db.timeStart = arr[4] .. ":00"
			end
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set the "Starting Time" for the Guild Bank Raffle to ' .. self.db.timeStart .. "\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if string.find(arr[2], "end") and arr[3] == "date" then
			arr[4] = tonumber(arr[4])
			arr[5] = tonumber(arr[5])
			arr[6] = tonumber(arr[6])
			if arr[4] == nil or arr[5] == nil or arr[6] == nil then
				self.db.dateEnd = self.defaults.dateEnd
			else
				arr[4] = arr[4] .. '/' .. arr[5] .. '/' .. arr[6]
				if RaffleGold:CreateDates(arr[4]) == nil then
					CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642Ending Date was not found!\r\nPlease make sure you are using the M/D/YYYY format.\nTo see the available date range, type: /rafflegold |r")
					return
				end
				self.db.dateEnd = arr[4]
			end
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set the "Ending Date" for the Guild Bank Raffle to ' .. self.db.dateEnd .. "\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if string.find(arr[2], "end") and arr[3] == "time" then
			if arr[4] == nil or arr[4] == "-" or arr[5] == nil or arr[5] == "-" then
				self.db.timeEnd = self.defaults.timeEnd
			else
				found = false
				arr[4] = tonumber(arr[4])
				arr[5] = tonumber(arr[5])
				if arr[4] ~= nil and arr[5] ~= nil then
					if arr[6] ~= nil and string.lower(arr[6]) == "pm" then arr[4] = arr[4] + 12 end
					if arr[4] >= 24 then arr[4] = arr[4] - 24 end
					for i=0, 23, 1 do
						if i == arr[4] then
							found = true
							break
						end
					end
				end
				if found == false then
					CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642Invalid Ending Time!\r\nThis must be in military time in the H:MM format.\nTo see the available times, type: /rafflegold |r")
					return
				end
				if arr[5] >= 30 and arr[4] < 23 then
					arr[4] = tonumber(arr[4]) + 1
				end
				self.db.timeEnd = arr[4] .. ":00"
			end
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set the "Ending Time" for the Guild Bank Raffle to ' .. self.db.timeEnd .. "\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if string.find(arr[2], "prize") then
			if string.find(string.lower(arr[3]), "on") or arr[3] == "1" then
				self.db.restriction = "One"
			else
				self.db.restriction = self.defaults.restriction
			end
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set the prizes per winner to ' .. self.db.restriction .. "\nIf you do not see the change(s) in the menu, type: /reloadui")
			return
		end
		if (string.find(arr[2], "bon") and string.find(arr[3], "m")) or (string.find(arr[3], "bon") and string.find(arr[2], "m")) then
			if self.db.bonusTickets == nil then
				CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642No bonus tickets were found |r")
				return
			else
				arr[4] = string.lower(arr[4])
				if string.find(arr[4], "y") or string.find(arr[4], "t") then
					self.db.bonusTickets["multi"] = true
					arr[4] = "YES"
				else
					self.db.bonusTickets["multi"] = false
					arr[4] = "NO"
				end
			end
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set the bonus multiplier to "' .. arr[4] .. '"')
			return
		end		
		arr[3] = RaffleGold:ConvertNumber(arr[3], true)
		arr[4] = RaffleGold:ConvertNumber(arr[4], true)
		if string.find(arr[2], "bon") and tonumber(arr[3]) ~= nil and tonumber(arr[4]) ~= nil then
			arr[3] = tonumber(arr[3])
			if self.db.bonusTickets == nil then
				self.db.bonusTickets = {}
				self.db.bonusTickets["arrCount"] = 0
				self.db.bonusTickets["multi"] = true
				self.db.bonusTickets["amount"] = {}
			end
			found = false
			for k,v in pairs(self.db.bonusTickets["amount"]) do
				if v[1] == arr[3] then
					found = true
					self.db.bonusTickets["amount"][k] = { arr[3], tonumber(arr[4]) }
					break
				end
			end
			if found == false then
				k = self.db.bonusTickets["arrCount"] + 1
				self.db.bonusTickets["arrCount"] = k
				self.db.bonusTickets["amount"][k] = { arr[3], tonumber(arr[4]) }
			end
			if tonumber(arr[4]) == 1 then
				arr[4] = ""
			else
				arr[4] = "s"
			end
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. ' set ' .. self.db.bonusTickets["amount"][k][2] .. ' bonus ticket' .. arr[4] .. ' when ' .. RaffleGold:ConvertNumber(arr[3]) .. ' is deposited')
			table.sort(self.db.bonusTickets["amount"], function(a, b) return a[1] > b[1] end)
			return
		end
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642Settings command not found.\r\nFor the list of commands, type: /rg help set|r")
		return
	end
	if arr[1] == "draw" then
		if arr[2] == "basic" then
			RaffleGold:DrawRaffle(true)
			return
		elseif arr[2] == "guild" then
			RaffleGold:GuildRaffle()
			return
		elseif arr[2] == "first" or arr[2] == "1st" then
			RaffleGold:DrawRaffle(true, "frt")
			return
		elseif arr[2] == "second" or arr[2] == "2nd" then
			RaffleGold:DrawRaffle(true, "scd")
			return
		elseif arr[2] == "third" or arr[2] == "3rd" then
			RaffleGold:DrawRaffle(true, "trd")
			return
		end
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642Drawing command not found.\r\nFor the list of commands, type: /rg help draw |r")
		return
	end
	if arr[2] == "results" or arr[2] == "result" then
		if arr[1] == "basic" then
			RaffleGold:DrawRaffle(true, "d")
			return
		elseif arr[1] == "guild" then
			if RaffleGold:GuildResults() == false then
				RaffleGold:GuildRaffle()
			end
			return
		end
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642Results command not found.\r\nFor the list of commands, type: /rg help draw |r")
		return
	end
	if arr[1] == "list" or arr[1] == "display" then
		m = "|cFF0000ERROR: |cf5e642List command not found.\r\nFor the available commands, type: /rg help list |r"
		if arr[2] == nil then
			m = "|cFF0000ERROR: |cf5e642List command missing.\r\nFor the available commands, type: /rg help list |r"	
		elseif string.find(arr[2], "ent") and arr[3] == "price" then
			m = "Entry Price: $" .. self.db.entryPrice
		elseif arr[2] == "ticket" and arr[3] == "price" then
			m = "Price per Ticket: $" .. self.db.ticketPrice
		elseif string.find(arr[2], "percent") then
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \nRaffle Percentages")
			CHAT_SYSTEM:AddMessage("1st Place: " .. self.db.placeFirst .. "%")
			CHAT_SYSTEM:AddMessage("2nd Place: " .. self.db.placeSecond .. "%")
			CHAT_SYSTEM:AddMessage("3rd Place: " .. self.db.placeThird .. "%")
			return
		elseif (arr[2] == "first" or arr[2] == "1st") and arr[3] == "place" then
			m = "1st Place: " .. self.db.placeFirst .. "%"
		elseif (arr[2] == "second" or arr[2] == "2nd") and arr[3] == "place" then
			m = "2nd Place: " .. self.db.placeSecond .. "%"
		elseif (arr[2] == "third" or arr[2] == "3rd") and arr[3] == "place" then
			m = "3rd Place: " .. self.db.placeThird .. "%"
		elseif arr[2] == "basic" and string.find(arr[3], "setting") then
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \nBasic Raffle Drawing Settings")
			CHAT_SYSTEM:AddMessage("Total Entries: " .. self.db.totalAmount)
			CHAT_SYSTEM:AddMessage("Total Amount: $" .. self.db.totalAmount)
			return
		elseif string.find(arr[2], "tot") and string.find(arr[3], "ent") then
			m = "Total Entries: " .. self.db.totalAmount
		elseif string.find(arr[2], "tot") and (arr[3] == "amount" or arr[3] == "amt") then
			m = "Total Amount: $" .. self.db.totalAmount
		elseif arr[2] == "guild" and (arr[3] == "setting" or arr[3] == "settings") then
			CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \nGuild Bank Raffle Drawing Settings")
			CHAT_SYSTEM:AddMessage("Guild: " .. self.db.guild)
			arr[3] = tonumber(self.db.guildRank)
			if arr[3] ~= nil and arr[3] > 1 then
				arr[3] = "1-"
			else
				arr[3] = ""
			end
			CHAT_SYSTEM:AddMessage("Exclude Guild Rank(s): " .. arr[3] .. self.db.guildRank)
			CHAT_SYSTEM:AddMessage("Starting Amount: $" .. self.db.startAmt)
			CHAT_SYSTEM:AddMessage("Starting Date: " .. self.db.dateStart)
			CHAT_SYSTEM:AddMessage("Starting Time: " .. self.db.timeStart)
			CHAT_SYSTEM:AddMessage("Ending Date: " .. self.db.dateEnd)
			CHAT_SYSTEM:AddMessage("Ending Time: " .. self.db.timeEnd)
			CHAT_SYSTEM:AddMessage("Prizes Per Username: " .. self.db.restriction)
			return
		elseif arr[2] == "guild" then
			m = "Guild: " .. self.db.guild
		elseif string.find(arr[2], "rank") then
			arr[3] = tonumber(self.db.guildRank)
			if arr[3] ~= nil and arr[3] > 1 then
				arr[3] = "1-"
			else
				arr[3] = ""
			end
			m = "Exclude Guild Rank(s): " .. arr[3] .. self.db.guildRank
		elseif string.find(arr[2], "start") and (arr[3] == "amt" or arr[3] == "amount") then
			m = "Starting Amount: $" .. self.db.startAmt
		elseif string.find(arr[2], "start") and arr[3] == "date" then
			m = "Starting Date: " .. self.db.dateStart
		elseif string.find(arr[2], "start") and arr[3] == "time" then
			m = "Starting Time: " .. self.db.timeStart
		elseif string.find(arr[2], "end") and arr[3] == "date" then
			m = "Ending Date: " .. self.db.dateEnd
		elseif string.find(arr[2], "end") and arr[3] == "time" then
			m = "Ending Time: " .. self.db.timeEnd
		elseif string.find(arr[2], "prize") then
			m = "Prizes Per Username: " .. self.db.restriction
		elseif string.find(arr[2], "bon") then
			if self.db.bonusTickets == nil then
				CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642No bonus ticket amounts were found!|r")
			else
				CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \nBonus ticket amounts...")
				for k,v in pairs(self.db.bonusTickets["amount"]) do
					s = "s"
					if v[2] == 1 then s = "" end
					CHAT_SYSTEM:AddMessage(RaffleGold:ConvertNumber(v[1]) .. " deposited gives " .. v[2] .. " free ticket" .. s .. " (" .. k .. ")")
				end
				if self.db.bonusTickets.multi == true then
					m = "YES"
				else
					m = "NO"
				end
				if self.db.bonusTickets["arrCount"] >= 2 then
					m = m .. " (For example: " .. RaffleGold:ConvertNumber(self.db.bonusTickets["amount"][1][1] + self.db.bonusTickets["amount"][2][1]) .. " deposit would give " .. (self.db.bonusTickets["amount"][1][2] + self.db.bonusTickets["amount"][2][2]) .. " bonus tickets)"
				else
					m = m .. " (For example: " .. RaffleGold:ConvertNumber(self.db.bonusTickets["amount"][1][1]*2) .. " deposit would give " .. (self.db.bonusTickets["amount"][1][2]*2) .. " bonus tickets)"
				end
				CHAT_SYSTEM:AddMessage("Bonus ticket multiplier is on? " .. m)
			end
			return
		end
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n" .. m)
		return
	end
	if string.find(arr[1], "ent") and arr[2] ~= nil and arr[2] ~= "" then
		if self.db.prizes.entrants ~= nil then
			if tonumber(arr[2]) == nil then
				uN = string.lower(arr[2])
				found = false
				i = 1
				ii = 0
				totAmt = 0
				while self.db.prizes.entrants[i] do
					if string.find(string.lower(self.db.prizes.entrants[i].userName), uN) then
						found = true
						ii = ii + 1
						CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- Result: " .. ii .. " -- \nUsername: " .. self.db.prizes.entrants[i].userName .. " -- Entry #: " .. self.db.prizes.entrants[i].entryNum .. " -- Tickets Purchased: " .. self.db.prizes.entrants[i].tickets .. " -- Ticket Numbers: " .. self.db.prizes.entrants[i].ticketNums .. " -- Amount Deposited: $" .. self.db.prizes.entrants[i].depositAmount)
						totAmt = totAmt + self.db.prizes.entrants[i].depositAmount
					end
					i = i + 1
				end
				if found == true then
					CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- Total Entries Found: " .. ii .. " -- Total Deposited Found: $" .. totAmt)
					return
				end
			end
			arr[2] = tonumber(arr[2])
			if arr[2] ~= nil then
				if self.db.prizes.entrants[arr[2]] == nil then
					CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642Entry number not found!|r")
				else
					CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \nEntry #: " .. self.db.prizes.entrants[arr[2]].entryNum .. " -- \nUsername: " .. self.db.prizes.entrants[arr[2]].userName .. " -- \nTickets Purchased: " .. self.db.prizes.entrants[arr[2]].tickets .. " -- \nTicket Numbers: " .. self.db.prizes.entrants[arr[2]].ticketNums .. " -- \nAmount Deposited: $" .. self.db.prizes.entrants[arr[2]].depositAmount)
				end
				return
			end
		end
		CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642No entries were found!|r")
		return
	end
	CHAT_SYSTEM:AddMessage(RaffleGold.ADDON_DISPLAY_NAME .. " -- \n|cFF0000ERROR: |cf5e642Command not found.\r\nFor the list of commands, type: /rg help |r")
end

-------------------------------
function RaffleGold:Initialize()
	self:Menu()
	SLASH_COMMANDS["/rg"] = RaffleGold.Cmd
	if self.db.bonusTickets == nil and self.db.ticketPrice ~= "" and tonumber(self.db.ticketPrice) ~= nil then
		self.db.ticketPrice = nil
	end
end
 
--------------------------------
function RaffleGold.OnAddOnLoaded(event, addon)
	if addon == RaffleGold.THIS_ADDON then
		RaffleGold:Initialize()
	end
end

EVENT_MANAGER:RegisterForEvent(RaffleGold.THIS_ADDON, EVENT_ADD_ON_LOADED, RaffleGold.OnAddOnLoaded)