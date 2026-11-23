--*** Slots Count Revised ***--
-- Last Updated: 11.22.2026 by @Dr_Z

-- **  Namespace  ** --
DLC_SlotsCount = {}
local DSC = DLC_SlotsCount
DSC.THIS_ADDON = "SlotsCount"
DSC.ADDON_NAME = "Slots Count"
DSC.ADDON_DISPLAY_NAME = "|cA0A0F3Slots  Count|r |t32:32:/esoui/art/guild/gamepad/gp_ownership_icon_guildtrader.dds|t" 
DSC.ADDON_AUTHOR = "|cFFF1B8 @Dr_Z, |cA0A0F3 DLC|r"
DSC.ADDON_VERSION = "|cFFF1B8 2.51.00 |r"
DSC.ADDON_WEBSITE = "https://www.esoui.com/downloads/info3337-SlotsCount.html"
DSC.defaults = {
	nonMember_Guild_Scan = false,
		}
DSC.COLOURS = {
	purp   = "|cA0A0F3",
	white  = "|cFFFFFF",
	tan    = "|cFFF1B8",
	yellow = "|cFFFF33",
	orange = "|cFFB300",
	red    = "|cFF462E",
	}
DSC.guildData = {}
DSC.guildSlots = {}
DSC.guildName = {}
DSC.isScanning = false
DSC.previousGuildData = nil
DSC.previousGuildSlots = nil
DSC.previousGuildName = nil
DSC.scanningGuildId = nil
DSC.scanningGuildName = nil
DSC.expectedPage = nil
DSC.seenListingIds = nil
DSC.completedPages = nil
DSC.scanRequestToken = 0
DSC.pageRetryCount = 0
DSC.savedDataVersion = 1
local SLOTS_COUNT_VIEWER_SCENE_NAME = "slotsCountViewer"
local SLOTS_COUNT_SORT_KEYS = {
	displayName = { },
	listingCount = { tiebreaker = "displayName", isNumeric = true },
	guildName = { tiebreaker = "displayName" },
}
local DLC_SlotsCount_ViewerManager = ZO_SortFilterList:Subclass()
local slotsCountViewerScene
local slotsCountViewerOpenedUI = false
-- DSC.savedData = nil

-- ** Megaserver name for SavedVars table ** --
local worldName = "**** " .. GetWorldName() .. " ****"

local logger = nil
if LibDebugLogger then
	logger = LibDebugLogger.Create(DSC.THIS_ADDON)
	DSC.logger = logger
else
	logger = {
		Info = function(msg) end,
		Debug = function(msg) end,
	}
end

-- ** Cheak Members last counted listings ** --			
function DLC_SlotsCount:GetUserSlots(guildID, userDisplayName)
	local guildName = GetGuildName(guildID)
	local gd = DSC.guildData[guildName]
	local slots = 0
	if gd then
		local sellerName = userDisplayName:gsub("|c.*|r", "")
		slots = gd[sellerName] or 0
	end
	return slots
end

-- ** If GUild Store is open, update Count Slots button ** --
function DLC_SlotsCount:SetUI(isStoreOpened)
	DSC.storeOpened = isStoreOpened
	DLC_SlotsCount:UpdateButtons()
end

-- ** Show the Count SLots button if Store is Open -- Hide if Not open ** --
function DLC_SlotsCount:UpdateButtons()
	if DSC.storeOpened then 
		if (not KEYBIND_STRIP:HasKeybindButton(DSC.startScanButton)) then
			KEYBIND_STRIP:AddKeybindButton(DSC.startScanButton)
		else
			KEYBIND_STRIP:UpdateKeybindButton(DSC.startScanButton)
		end
	else
		KEYBIND_STRIP:RemoveKeybindButton(DSC.startScanButton)
	end
end

-- ** Save data to SavedVariables and updates display ** -- 
function DSC.SaveData()
	if DSC.isScanning then return end
	DSC.savedData.Guild_Members_Total_Listings = DSC.guildData 
	DSC.savedData.Guilds_Total_Listing_Counts = DSC.guildSlots 
	DSC.savedData.Guilds_ID_Names = DSC.guildName 
	if DSC.viewerManager then
		DSC.viewerManager:RefreshGuildDropdown()
		DSC.viewerManager:RefreshData()
	end
end

-- ** SavedVariables Clear Confirmation ** --						
function DSC.ClearData()
	ZO_Dialogs_ShowDialog("DLC_SLOTSCOUNT_CLEAR_DATA")
end

-- ** Clear Users SavedVariables ** --							
function DSC.ClearSavedData()
	if DSC.isScanning then return end	
	-- ** Clear CACHE Memory ** --
	DSC.guildData = {}
	DSC.guildSlots = {}
	DSC.guildName = {}
	-- ** Clear savedVariables Tables for the Account that is Logged in ** --
	DSC.savedData.Guild_Members_Total_Listings = nil
	DSC.savedData.Guilds_Total_Listing_Counts = nil
	DSC.savedData.Guilds_ID_Names = nil
	DSC.savedData.Guilds_Last_Scan = nil

	DSC.slotsColumn:SetGuildFilter({}) 
	CHAT_SYSTEM:Maximize()
	CHAT_ROUTER:AddSystemMessage("|ca0a0F3SlotsCount|r:MSG: |cFFFFFFCLEARED All Saved Data for this Account|r")
	LibGuildRoster:Refresh()
end

-- ** Reset Confirmation window ** --						
function DSC.ResetData()
	ZO_Dialogs_ShowDialog("DLC_SLOTSCOUNT_RESET_DATA")
end

-- ** SavedVariables Reset - NUKE It ALL - Deletes All SavedVariables for All Accounts ** --						
function DSC.ResetSavedData()
	if DSC.isScanning then return end	
	-- ** Clear CACHE Memory ** --
	DSC.guildData = {}
	DSC.guildSlots = {}
	DSC.guildName = {}
	-- ** RESET or NUKE All savedVariables Tables for All Accounts ** --
        if SlotsCountData and SlotsCountData.Default then
		for accountName in pairs(SlotsCountData.Default) do
			SlotsCountData.Default[accountName] = nil
		end
        end
	DSC.slotsColumn:SetGuildFilter({}) 
	DSC.savedData = ZO_SavedVars:NewAccountWide("SlotsCountData", DSC.savedDataVersion, worldName, nil, nil)
	CHAT_SYSTEM:Maximize()
	CHAT_ROUTER:AddSystemMessage("|ca0a0F3SlotsCount|r:MSG: |cFFFFFFDELETED All Saved Data for All Accounts|r")
	LibGuildRoster:Refresh()
end

-- ** Custom Message Box for Count Listings / Slots ** --				
local function DLC_ShowMsgBox(title, msg)
	if ZO_Dialogs_IsShowing("DLCSlotsCount") and DSC.activeDialog then
		ZO_Dialogs_UpdateDialogMainText(DSC.activeDialog, {text = DSC.COLOURS.white..msg.."|r"})
	else
		local confirmDialog = {
			title = { text = DSC.COLOURS.purp..title.."|r" },
			mainText = { text = DSC.COLOURS.white..msg.."|r" },
			 buttons = {}
		}
		ZO_Dialogs_RegisterCustomDialog("DLCSlotsCount", confirmDialog)
		DSC.activeDialog = ZO_Dialogs_ShowDialog("DLCSlotsCount")
		DSC.activeDialog:GetNamedChild("Text"):SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	end 
end

-- ** Done scanning? Close Custom Message Window ** --
local function DLC_CloseMsgBox()
	ZO_Dialogs_ReleaseDialog("DLCSlotsCount", false)
	DSC.activeDialog = nil
end

-- ** Delay function so we don't Hammer the Server ** --
local function DLC_GetDelay()
	return math.max(GetTradingHouseCooldownRemaining() + 100, 500)
end

-- ** Refresh Store Browse Tab after scan ** --
local function DLC_RefreshStoreAfterScan(guildId)
	if not DSC.storeOpened or DSC.isScanning then
		return
	end
	local currentGuildId = GetCurrentTradingHouseGuildDetails()
	if currentGuildId ~= guildId then
		return
	end
	ClearTooltip(ItemTooltip)
	ZO_InventorySlot_RemoveMouseOverKeybinds()
	TRADING_HOUSE:ClearSearchResults()
	TRADING_HOUSE_SEARCH:ResetAllSearchData()
	TRADING_HOUSE_SEARCH:DoSearch()
end

-- ** Stop a bad scan without replacing the last valid scan ** --
-- ** If scan is Unsuccessful, load last known good scanned variables. ** --
local function DLC_FailCurrentScan()
	local gid = DSC.scanningGuildId
	local guildName = DSC.scanningGuildName or "this guild"

	EVENT_MANAGER:UnregisterForEvent(DSC.THIS_ADDON, EVENT_TRADING_HOUSE_RESPONSE_RECEIVED)
	ClearAllTradingHouseSearchTerms()

	if guildName ~= "this guild" then
		DSC.guildData[guildName] = DSC.previousGuildData
		DSC.guildSlots[guildName] = DSC.previousGuildSlots
	end
	if gid then
		DSC.guildName[gid] = DSC.previousGuildName
	end

	DSC.isScanning = false
	DSC.scanRequestToken = DSC.scanRequestToken + 1
	DSC.previousGuildData = nil
	DSC.previousGuildSlots = nil
	DSC.previousGuildName = nil
	DSC.scanningGuildId = nil
	DSC.scanningGuildName = nil
	DSC.expectedPage = nil
	DSC.seenListingIds = nil
	DSC.completedPages = nil
	DSC.pageRetryCount = 0
	DSC.UpdateButtons()
	DLC_RefreshStoreAfterScan(gid)

	DLC_ShowMsgBox("ERROR", "An error has occurred.\nPlease rescan " .. guildName .. ".\n\nLast Scan not Saved.")
	CHAT_ROUTER:AddSystemMessage("|ca0a0F3SlotsCount|r: |cFF462EERROR|r - An error has occurred. Please rescan |cFFFFFF" .. guildName .. "|r. Last Scan not Saved.")
	zo_callLater(DLC_CloseMsgBox, 7000)
end

-- ** Request one page at a time / If Server does not respond, Retries it ** --	
local function DLC_RequestScanPage(page)
	if not DSC.isScanning then
		return
	end
	DSC.expectedPage = page
	DSC.scanRequestToken = DSC.scanRequestToken + 1
	local requestToken = DSC.scanRequestToken
	-- Send the page request after each delay
	zo_callLater(function()
		if not DSC.isScanning or DSC.scanRequestToken ~= requestToken then
			return
		end
		ExecuteTradingHouseSearch(page)
		-- Retrie an unanswered page after ten seconds, or stops after three retries.
		zo_callLater(function()
		if not DSC.isScanning or DSC.scanRequestToken ~= requestToken or DSC.expectedPage ~= page then
			return
		end
		DSC.pageRetryCount = DSC.pageRetryCount + 1
		if DSC.pageRetryCount > 3 then
			DLC_FailCurrentScan()
			return
		end
		DLC_ShowMsgBox("Counting   Slots \/ Listings", "Page " .. (page + 1) .. " did not respond.\nRetrying page " .. (page + 1) .. " - attempt " .. DSC.pageRetryCount .. " of 3.")
		logger:Debug("Retrying scan page " .. tostring(page + 1))
		DLC_RequestScanPage(page)
		end, 10000)
	end, DLC_GetDelay())
end

-- ** Lets Build some Data Tables - Counts each seller's listings, page by page ** --							-- fixed do to a "nil" BUG
local function DLC_ProcessTradingHouseSearchResults()
	local numItemsOnPage, currentPage, hasMorePages = GetTradingHouseSearchResultsInfo()
	local gid, guildName = GetCurrentTradingHouseGuildDetails()

	if not DSC.isScanning then
		return
	end

	if guildName ~= DSC.scanningGuildName or currentPage ~= DSC.expectedPage then
		logger:Debug("Ignored Trading House response for guild " .. tostring(gid) .. ", page " .. tostring(currentPage + 1))
		return
	end

	DSC.pageRetryCount = 0
	DLC_ShowMsgBox("Counting   Slots \/ Listings", "scanning page    \[ " .. (currentPage+1).." \]")
	logger:Debug("...scanning page  " .. (currentPage+1))  
	for i = 1, numItemsOnPage do
		local _, _, _, stackCount, sellerName, _, _, _, uid = GetTradingHouseSearchResultItemInfo(i)
		local listingKey = uid and Id64ToString(uid)

		if not listingKey or not DSC.seenListingIds[listingKey] then
			if listingKey then
				DSC.seenListingIds[listingKey] = true
			end

			sellerName = sellerName:gsub("|c.*|r", "")
			local count = DSC.guildData[guildName][sellerName] or 0
			DSC.guildData[guildName][sellerName] = count + 1
			local total = DSC.guildSlots[guildName] + 1
			DSC.guildSlots[guildName] = total
			else
				logger:Debug("Ignored duplicate Trading House listing " .. listingKey)
			end
		end
		DSC.completedPages[currentPage] = true
		if hasMorePages then
			local nextPage = currentPage + 1
			DLC_RequestScanPage(nextPage)
		else
			EVENT_MANAGER:UnregisterForEvent(DSC.THIS_ADDON, EVENT_TRADING_HOUSE_RESPONSE_RECEIVED)
			DSC.scanRequestToken = DSC.scanRequestToken + 1
			ClearAllTradingHouseSearchTerms()

			local scanHasError = false
			for page = 0, currentPage do
				if not DSC.completedPages[page] then
					scanHasError = true
					logger:Debug("Scan validation found missing page " .. tostring(page + 1))
					break
				end
			end

			for _, listingCount in pairs(DSC.guildData[guildName]) do
				if listingCount > 30 then
					scanHasError = true
					break
				end
			end

			if scanHasError then
				DLC_FailCurrentScan()
				return
			end

			local guildFilter = {}
			local n=1
			for guildIndex = 1, GetNumGuilds() do
				local guildID = GetGuildId(guildIndex)
				local guildName = GetGuildName(guildID)
				if DSC.guildData[guildName] then
					guildFilter[n] = guildID
					n = n + 1
					logger:Debug(guildName .. " (" .. guildID .. ") added to guild filter")
				end
			end
			logger:Debug("guild filter has: " .. #guildFilter .. " entries")
			DSC.slotsColumn:SetGuildFilter(guildFilter)
			LibGuildRoster:Refresh()
			DLC_ShowMsgBox("Counting   Slots \/ Listings", "Scanning finished. SlotsCount: " .. (DSC.guildSlots[guildName]))

			local Total_Members_Listing = 0
			CHAT_ROUTER:AddSystemMessage("|ca0a0F3SlotsCount|r: guild: |cFFFFFF" .. guildName .. "|r total listings:|cFFFFFF " .. (DSC.guildSlots[guildName]))
			if DSC.savedData.Guild_Members_Total_Listings then
				Total_Members_Listing = DLC_SlotsCount:GetGuildTotalMembersListing(DSC.savedData.Guild_Members_Total_Listings[guildName])
				CHAT_ROUTER:AddSystemMessage("|ca0a0F3          |rTotal Guild Members Listing: |cFFFFFF" .. Total_Members_Listing .."|r")
			end
			local completionToken = DSC.scanRequestToken
			-- Save the completed scans 
			zo_callLater(function()
			if not DSC.isScanning or DSC.scanRequestToken ~= completionToken then
				return
			end
			logger:Info("SlotsCount Scanning finished. SlotsCount: " .. (DSC.guildSlots[guildName]))			
			--CHAT_ROUTER:AddSystemMessage("SlotsCount: You can use /sc_clear command to remove slots count data from memory.")
			DSC.isScanning = false
			DSC.savedData.Guilds_Last_Scan = DSC.savedData.Guilds_Last_Scan or {}
			DSC.savedData.Guilds_Last_Scan[guildName] = GetTimeStamp()
			DSC.previousGuildData = nil
			DSC.previousGuildSlots = nil
			DSC.previousGuildName = nil
			DSC.scanningGuildId = nil
			DSC.scanningGuildName = nil
			DSC.expectedPage = nil
			DSC.seenListingIds = nil
			DSC.completedPages = nil
			DSC.scanRequestToken = DSC.scanRequestToken + 1
			DSC.pageRetryCount = 0
			DSC.UpdateButtons()
			DSC.SaveData()
			DLC_CloseMsgBox()
			DLC_RefreshStoreAfterScan(gid)
		end, DLC_GetDelay())
	end
end

-- ** Do we have more Pending Search Results ** --
local function DLC_OnTradingHouseResponseReceived(eventCode, responseType, result)
	if (responseType == TRADING_HOUSE_RESULT_SEARCH_PENDING) then
		DLC_ProcessTradingHouseSearchResults()
	end
end

-- ** Count Total Guild Members listing Items ** --						-- Added 7-11-2026 by @Dr_Z
function DLC_SlotsCount:GetGuildTotalMembersListing(Total_Members)
	if not Total_Members then
		return 0
	end
	local count = 0
	for _ in pairs(Total_Members) do
		count = count + 1
	end
	return count
end	

-- ** Slash Commands Help menu for chat window ** --						-- Added 7.28.2026 by @Dr_Z
local function ShowSlashCommandHelp()
	local commandColour = DSC.COLOURS.purp
	d(commandColour.."/schelp|r -- Lists slash commands and descriptions in chat")
	d(commandColour.."/scmenu|r -- Opens Settings Menu")
	d(commandColour.."/slotscount|r -- Opens or Closes the Slots Count window")
	d(commandColour.."/slots|r -- Opens or Closes the Slots Count window")
	d(commandColour.."/sc_save|r -- Saves Scanned Data")
	d(commandColour.."/sc_clear|r -- Clears Saved Data on Current Account")
	d(commandColour.."/sc_reset|r -- RESETS Saved Data for All Accounts")
end

-- ** Settings Menu ** --
function DLC_SlotsCount:SettingsMenu()
	local LAM2 = LibAddonMenu2

	local panelData =
	{
		type = "panel",
		name = self.ADDON_NAME,
		displayName = self.ADDON_DISPLAY_NAME,
		author = self.ADDON_AUTHOR,
		version = self.ADDON_VERSION,
		website = self.ADDON_WEBSITE,
		--comment = self.ADDON_COMMENT,
		slashCommand = "/scmenu",
		registerForRefresh = true,
		registerForDefaults = true
	}
	self.settingsPanel = LAM2:RegisterAddonPanel(DSC.THIS_ADDON .. "LAM2Options", panelData)
	-- SubMenu SLASH Command Description Data
	local SLASH_COMMAND_INFO = {
		type = "description",
		title = self.COLOURS.tan.."Use Slash Commands if you don't want to log into the Settings Menu|r",
		text = "\n  "..self.COLOURS.purp.."/schelp "..self.COLOURS.tan.."-- Lists slash commands and descriptions in chat \n  "..self.COLOURS.purp.."/scmenu "..self.COLOURS.tan.."-- Opens Settings Menu \n  "..self.COLOURS.purp.."/slotscount "..self.COLOURS.tan.."-- Opens or Closes the Slots Count window \n  "..self.COLOURS.purp.."/slots "..self.COLOURS.tan.."-- Opens or Closes the Slots Count window \n  "..self.COLOURS.purp.."/sc_save "..self.COLOURS.tan.."-- Saves Scanned Data|r\n  "..self.COLOURS.purp.."/sc_clear "..self.COLOURS.tan.."-- Clears Saved Data on Current Account  \n  "..self.COLOURS.purp.."/sc_reset "..self.COLOURS.tan.."-- RESETS Saved Data for All Accounts",	
	}
	-- *** Main Menu Optoins *** --
	local optionsTable =
	{
		-- Description
		{
			type = "description",
			text = self.COLOURS.tan.."This Addon adds a Custom Column to the Guild Roster.\nInitiate a Scan while in a Guild Store to scan all item Listings / Slots.|r",
			width = "full",
		},
		-- Header Set CUTOFF Day/Time
		{
			type = "header",
			name = self.COLOURS.purp.."Scan NonMember Guild Stores|r"
		},
		-- Set CUTOFF Description
		{
			type = "description",
			text = self.COLOURS.tan.."Be Forewarned: Setting this to \"ON\" will increase Saved Data memory\nand Game Load times.\nIt'll be a good idea to Reset Saved Data once in a while if you turn this on|r",
			width = "full",
		},
		-- IMAGE Divider -  testing different images
		{
			type = "texture",
			image = "esoui\\art\\miscellaneous\\horizontaldivider_dynamic.dds",
			imageWidth = 480,	--
			imageHeight = 4,	--
			width = "full",
		},
		-- CHECKBOX  -  Set this to scan nonMember Guilds
		{
			type = "checkbox",
			name = "Scan NonMember Guilds",
			tooltip = "I Dare You to Click It",
			getFunc = function()
				return self.savedData.nonMember_Guild_Scan or self.defaults.nonMember_Guild_Scan
			end,
			setFunc = function(choice)
				self.savedData.nonMember_Guild_Scan = choice
			end,
			width = "full",	
			warning = "Remember to Clear Data once in a while to reduce Data buildup and Load times.",
		},
		-- Header for Buttons
		{
			type = "header",
			name = self.COLOURS.purp.."Action Buttons|r"
		},
		-- Text about Buttons
		{
			type = "description",
			text = self.COLOURS.tan.."These "..self.COLOURS.purp.."Action Buttons|r "..self.COLOURS.tan.."can be used instead of the Slash Commands.|r",
			width = "full",
		},
		-- Save Data Reloadui
		{
			type = "button",
			name = self.COLOURS.white.."Save & /ReloadUI|r",
			--tooltip = "Button to Save Guild Data",
			width = "half",
			func = function() ReloadUI() end,
			warning = "This will reload the UI.",
		},
		{
			type = "button",
			name = self.COLOURS.purp.."Open Slots Count|r",
			tooltip = "View saved guild listing counts",
			width = "half",
			func = function()
				DSC.ToggleViewer()
			end,
		},
		-- Clears All Variabls for the account You're logged into
		{
			type = "button",
			name = self.COLOURS.orange.."Clear Data this Account|r",
			tooltip = "Erase Saved Account Data",
			width = "half",
			--isDangerous = true,
			warning = "|cFFFF00WARNING|r... This Will Delete Saved Data on the account You're Logged into",
			func = function() 
				DSC.ClearData()
			end,
		},
		-- RESET All Variabls for All Accounts - This is the NUKE ALL DATA Button
		{
			type = "button",
			text = "|cFFFF00WARNING|r... This Will Delete ALL Saved Data for All Accounts.|r",
			name = self.COLOURS.red.."Reset All Accounts|r",
			tooltip = "NUKE All Saved Data of this Addon",
			width = "half",
			--isDangerous = true,
			warning = self.COLOURS.red.."WARNING|r... This Will Delete ALL Saved Data for All Accounts",
			func = function() 
				DSC.ResetData()
			end,
		},
		-- The Blah Blah Blah Area
		{
			type = "description",
			title = nil,	
			text = self.COLOURS.tan.."The button above, All in "..self.COLOURS.red.."RED|r"..self.COLOURS.tan..", Deletes ALL SAVED DATA for All Accounts from this Addon!|r",
			width = "full",	
		},
		-- SUBMENU Slash Command Menu
		{
			type = "submenu",
			name = self.COLOURS.purp.."Slash Commands Menu|r",
			controls = {SLASH_COMMAND_INFO},
		},

	}
	LAM2:RegisterOptionControls(DSC.THIS_ADDON .. "LAM2Options", optionsTable)
end

-- ** Search/Scan for Guild Members Listings/Slots Totals ** --					-- Updated 7.11-18.2026 by @Dr_Z
function DLC_SlotsCount:Scan()
	if self.isScanning then
		return
	end
	local gid, name = GetCurrentTradingHouseGuildDetails()
	-- ** Test if checkbox is true to Scan NonMember GUilds  ** --				-- Added 7.28.2026 by @Dr_Z
	local to_Scan_or_Not_to_Scan = self.savedData.nonMember_Guild_Scan or false
	if not to_Scan_or_Not_to_Scan then
	-- ** check if Player is part of Trading House Guild **					-- Added 7-13-2026 by @Dr_Z
		local CanPlayer_SELL_IN_TRADING_HOUSE = CanSellOnTradingHouse(gid)
		if not CanPlayer_SELL_IN_TRADING_HOUSE then
			local Is_Player_InGuild = IsPlayerInGuild(gid)
			if not Is_Player_InGuild then
				DLC_ShowMsgBox("Sorry", "You're NOT a member of \n\""..name.."\"\nGoto Settings Menu to Unlock this feature...")
				KEYBIND_STRIP:RemoveKeybindButton(DSC.startScanButton)
				zo_callLater(DLC_CloseMsgBox, 5000)
				return
			else
				DLC_ShowMsgBox("Sorry", "You either: Don't have permission to scan the Guild. \nOr, The Guild has less then 50 members")
				KEYBIND_STRIP:RemoveKeybindButton(DSC.startScanButton)
				zo_callLater(DLC_CloseMsgBox, 5000)
				return
			end
		end
	end

    -- ** Check Trading House TAB Mode - Browse/Search, Sell, or Listings **			-- Added 7-13-2026 by @Dr_Z
    -- ** Member guilds use LISTINGS; other guilds remain on BROWSE.      **
	local what_Mode = TRADING_HOUSE:GetCurrentMode()
	if IsPlayerInGuild(gid) and what_Mode ~= ZO_TRADING_HOUSE_MODE_LISTINGS then
		ZO_MenuBar_SelectDescriptor(TRADING_HOUSE.menuBar, ZO_TRADING_HOUSE_MODE_LISTINGS, true, false)
	end
 
	if not DSC.storeOpened then 
		DLC_ShowMsgBox("Slots Count", "Guild Store Not Opened")
		zo_callLater(DLC_CloseMsgBox, 2000)
		return 
	end
	CHAT_SYSTEM:Maximize()
	DLC_ShowMsgBox("Counting   Slots \/ Listings", "Scanning guild " .. name .. "...")		
	logger:Info("SlotsCount Started scanning guild " .. name .. "...")
	DSC.isScanning = true
	DSC.UpdateButtons()
	DSC.previousGuildData = DSC.guildData[name]
	DSC.previousGuildSlots = DSC.guildSlots[name]
	DSC.previousGuildName = DSC.guildName[gid]
	DSC.scanningGuildId = gid
	DSC.scanningGuildName = name
	DSC.expectedPage = 0
	DSC.seenListingIds = {}
	DSC.completedPages = {}
	DSC.pageRetryCount = 0
	DSC.guildData[name] = {}
	DSC.guildSlots[name] = 0				
	DSC.guildName[gid] = name
	TRADING_HOUSE_SEARCH:CancelPendingSearch()
	TRADING_HOUSE:ClearSearchResults()
	ClearTooltip(ItemTooltip)
	ClearAllTradingHouseSearchTerms()
	EVENT_MANAGER:RegisterForEvent(DSC.THIS_ADDON, EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, DLC_OnTradingHouseResponseReceived)
	DLC_RequestScanPage(0)
end

-- ** Guild Store Open? - Display Count Slots button ** --
local function DLC_OnTradingHouseOpened()
	DLC_SlotsCount:SetUI(true)
end

-- ** Restore previous counts if a Scan is unfinished when the store closes ** --
local function DLC_OnTradingHouseClosed()
	if DSC.isScanning then
		local guildName = DSC.scanningGuildName
		local guildId = DSC.scanningGuildId
		DSC.guildData[guildName] = DSC.previousGuildData
		DSC.guildSlots[guildName] = DSC.previousGuildSlots
		DSC.guildName[guildId] = DSC.previousGuildName
		DLC_CloseMsgBox()
	end
	DSC.previousGuildData = nil
	DSC.previousGuildSlots = nil
	DSC.previousGuildName = nil
	EVENT_MANAGER:UnregisterForEvent(DSC.THIS_ADDON, EVENT_TRADING_HOUSE_RESPONSE_RECEIVED)
	DSC.isScanning = false
	DSC.scanRequestToken = DSC.scanRequestToken + 1
	DSC.scanningGuildId = nil
	DSC.scanningGuildName = nil
	DSC.expectedPage = nil
	DSC.seenListingIds = nil
	DSC.completedPages = nil
	DSC.pageRetryCount = 0
	DLC_SlotsCount:SetUI(false)
end

-- ** Restore LISTINGS from SavedVars after a new login or reload		-- Added 7-8-2026 by @Dr_Z
function DLC_SlotsCount:buildSavedData()
     -- ** Restore cached data from SavedVariables ** --
	DSC.guildData = DSC.savedData.Guild_Members_Total_Listings or {}
	DSC.guildSlots = DSC.savedData.Guilds_Total_Listing_Counts or {}
	DSC.guildName = DSC.savedData.Guilds_ID_Names or {}
     -- ** Rebuild guildfilter ** --
	local guildFilter = {}
	local n = 1
	for guildIndex = 1, GetNumGuilds() do
		local guildID = GetGuildId(guildIndex)
		local guildName = GetGuildName(guildID)
		if DSC.guildData[guildName] then
			guildFilter[n] = guildID
			n = n + 1
		end
	end
	DSC.slotsColumn:SetGuildFilter(guildFilter)
	LibGuildRoster:Refresh()
end

-- ** Slots Count Viewer Window ** --								
function DLC_SlotsCount_ViewerManager:New(control)
	local manager = ZO_SortFilterList.New(self, control)
	-- Fills each visible viewer row with a seller's counts.
	ZO_ScrollList_AddDataType(manager.list, 1, "DLCSlotsCountViewerRow", 30, function(rowControl, data)
		manager:SetupRow(rowControl, data)
	end)
	ZO_ScrollList_EnableHighlight(manager.list, "ZO_ThinListHighlight")
	manager:SetAlternateRowBackgrounds(true)
	manager.control = control
	manager.resultCount = GetControl(control, "ResultCount")
	manager.guildFilter = ZO_ComboBox_ObjectFromContainer(GetControl(control, "GuildFilter"))
	manager.guildFilter:SetSortsItems(false)
	manager.guildFilter:SetFont("ZoFontWinT1")
	manager.guildFilter:SetSpacing(4)
	manager.nameFilterBox = GetControl(control, "NameFilterBox")
	-- Updates the list when a user uses the search box.
	manager.nameFilterBox:SetHandler("OnTextChanged", function(editControl)
		manager:OnSearchTextChanged(editControl)
	end)
	manager.selectedGuildName = nil
	manager.masterList = {}
	manager.sortHeaderGroup:SelectHeaderByKey("displayName")
	return manager
end

-- ** Display seller's name, count, and guild - Highlight guild members in other shared guilds ** --
function DLC_SlotsCount_ViewerManager:SetupRow(control, data)
	ZO_SortFilterList.SetupRow(self, control, data)
	local nameLabel = GetControl(control, "Name")
	local listingsLabel = GetControl(control, "Listings")
	local guildLabel = GetControl(control, "Guild")
	nameLabel:SetText((data.sortIndex or 0) .. "  " .. data.displayName)
	listingsLabel:SetText(ZO_CommaDelimitNumber(data.listingCount))
	guildLabel:SetText(data.guildName)
	local red, green, blue = 1, 1, 1
	if data.sharesPlayerGuild then
		red, green, blue = 0.73, 1, 0
	end
	nameLabel:SetColor(red, green, blue, 1)
	listingsLabel:SetColor(red, green, blue, 1)
	guildLabel:SetColor(red, green, blue, 1)
end

-- ** Lists users guilds and their members so shared guilds with other members can be recognized easily ** --
function DLC_SlotsCount_ViewerManager:BuildSharedGuildLookup()
	self.playerGuildNames = {}
	self.sharedGuildUsers = {}
	for guildIndex = 1, GetNumGuilds() do
		local guildId = GetGuildId(guildIndex)
		local guildName = GetGuildName(guildId)
		if guildName and guildName ~= "" then
			self.playerGuildNames[guildName] = true
		end
		for memberIndex = 1, GetNumGuildMembers(guildId) do
			local displayName = GetGuildMemberInfo(guildId, memberIndex)
			if displayName and displayName ~= "" then
				self.sharedGuildUsers[displayName:lower()] = true
			end
		end
	end
end

-- ** Combine all saved guild counts into a list for the viewer wiundow ** --
function DLC_SlotsCount_ViewerManager:BuildMasterList()
	ZO_ClearNumericallyIndexedTable(self.masterList)
	self:BuildSharedGuildLookup()
	for guildName, members in pairs(DSC.guildData) do
		for displayName, listingCount in pairs(members) do
			table.insert(self.masterList, {
				displayName = displayName,
				listingCount = listingCount,
				guildName = guildName,
				sharesPlayerGuild = not self.playerGuildNames[guildName] and self.sharedGuildUsers[displayName:lower()] == true,
			})
		end
	end
end

-- ** Function to show a Guilds data when selected ** --
function DLC_SlotsCount_ViewerManager:FilterScrollList()
	local scrollData = ZO_ScrollList_GetDataList(self.list)
	ZO_ClearNumericallyIndexedTable(scrollData)
	local guildCount = 0
	local visibleGuilds = {}
	local userCount = 0
	local listingTotal = 0
	local nameFilter = self.nameFilterBox:GetText():lower()
	for _, data in ipairs(self.masterList) do
		local guildMatches = not self.selectedGuildName or data.guildName == self.selectedGuildName
		local nameMatches = nameFilter == "" or zo_plainstrfind(data.displayName:lower(), nameFilter)
		if guildMatches and nameMatches then
			if not visibleGuilds[data.guildName] then
				visibleGuilds[data.guildName] = true
				guildCount = guildCount + 1
			end
			userCount = userCount + 1
			listingTotal = listingTotal + data.listingCount
			table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, data))
		end
	end
	local totalsText = "TOTALS:  "
	if not self.selectedGuildName then
		totalsText = totalsText .. ZO_CommaDelimitNumber(guildCount) .. " Guilds / "
	end
	totalsText = totalsText .. ZO_CommaDelimitNumber(userCount) .. " Users / " .. ZO_CommaDelimitNumber(listingTotal) .. " Listings"
	self.resultCount:SetText(totalsText)
end

-- ** Update the search box and filter the data being displayed ** --
function DLC_SlotsCount_ViewerManager:OnSearchTextChanged(control)
	ZO_EditDefaultText_OnTextChanged(control)
	self:RefreshFilters()
end

-- ** Decides which of two rows comes first under the selected column and sort direction ** --
function DLC_SlotsCount_ViewerManager:CompareRows(listEntry1, listEntry2)
	return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, SLOTS_COUNT_SORT_KEYS, self.currentSortOrder)
end

-- ** Put the rows in the chosen order ** --
function DLC_SlotsCount_ViewerManager:SortScrollList()
	if self.currentSortKey ~= nil and self.currentSortOrder ~= nil then
		local scrollData = ZO_ScrollList_GetDataList(self.list)
		table.sort(scrollData, function(listEntry1, listEntry2)
			return self:CompareRows(listEntry1, listEntry2)
		end)
	end
end

function DLC_SlotsCount_ViewerManager:ColorRow(control, data, mouseIsOver)
end

-- ** Builds Guild dropdown menu and Colors a user's Guilds ** --
function DLC_SlotsCount_ViewerManager:RefreshGuildDropdown()
	self.guildFilter:ClearItems()
	-- Display saved results for all guilds when All Guilds is selected.
	local allGuilds = self.guildFilter:CreateItemEntry("ALL GUILDS", function()
		self.selectedGuildName = nil
		self:RefreshFilters()
	end)
	allGuilds.guildName = nil
	self.guildFilter:AddItem(allGuilds)
	local playerGuildNames = {}
	for guildIndex = 1, GetNumGuilds() do
		local guildId = GetGuildId(guildIndex)
		local playerGuildName = GetGuildName(guildId)
		if playerGuildName and playerGuildName ~= "" then
			playerGuildNames[playerGuildName] = true
		end
	end
	local guildNames = {}
	for guildName in pairs(DSC.guildData) do
		table.insert(guildNames, guildName)
	end
	table.sort(guildNames)
	for _, guildName in ipairs(guildNames) do
		local selectedGuildName = guildName
		local displayedGuildName = selectedGuildName
		if playerGuildNames[selectedGuildName] then
			displayedGuildName = DSC.COLOURS.purp .. selectedGuildName .. "|r"
		end
		-- Display only the guild chosen from the dropdown.
		local item = self.guildFilter:CreateItemEntry(displayedGuildName, function()
			self.selectedGuildName = selectedGuildName
			self:RefreshFilters()
		end)
		item.guildName = selectedGuildName
		self.guildFilter:AddItem(item)
	end
	self.selectedGuildName = nil
	self.guildFilter:SelectItem(allGuilds)
end

-- ** Hide SlotsCount veiwer window ** --
local function HideSlotsCountViewer()
	if slotsCountViewerScene and SCENE_MANAGER:IsShowing(SLOTS_COUNT_VIEWER_SCENE_NAME) then
		SCENE_MANAGER:ShowBaseScene()
	elseif DSC.viewerManager then
		DSC.viewerManager.control:SetHidden(true)
	end
	if slotsCountViewerOpenedUI then
		SetGameCameraUIMode(false)
	end
	slotsCountViewerOpenedUI = false
end

-- ** Open viewer window with refreshed counts, or closes it if it's already open ** --
function DSC.ToggleViewer()
	local manager = DSC.viewerManager
	if not manager then return end
	if slotsCountViewerScene and SCENE_MANAGER:IsShowing(SLOTS_COUNT_VIEWER_SCENE_NAME) then
		HideSlotsCountViewer()
	else
		manager:RefreshGuildDropdown()
		manager:RefreshData()
		slotsCountViewerOpenedUI = not IsGameCameraUIModeActive()
		if slotsCountViewerOpenedUI then
			SetGameCameraUIMode(true)
		end
		SCENE_MANAGER:Show(SLOTS_COUNT_VIEWER_SCENE_NAME)
		manager.control:BringWindowToTop()
	end
end

function DSC.Viewer_OnInitialized(control)
	DSC.viewerManager = DLC_SlotsCount_ViewerManager:New(control)
	slotsCountViewerScene = ZO_Scene:New(SLOTS_COUNT_VIEWER_SCENE_NAME, SCENE_MANAGER)
	slotsCountViewerScene:AddFragment(ZO_FadeSceneFragment:New(control))
	slotsCountViewerScene:RegisterCallback("StateChange", function(_oldState, newState)
		if newState == SCENE_HIDDEN then
			if slotsCountViewerOpenedUI then
				SetGameCameraUIMode(false)
			end
			slotsCountViewerOpenedUI = false
		end
	end)
end

-- ** Remember last position of SlotsCount's display window ** --
function DSC.Viewer_SaveWindowPosition(control)
	if not DSC.savedData then return end
	DSC.savedData.ViewerWindowLeft = control:GetLeft()
	DSC.savedData.ViewerWindowTop = control:GetTop()
end

function DSC.Viewer_Close()
	HideSlotsCountViewer()
end

-- ** Highlight Row when Mouse is over ** --
function DSC.ViewerRow_OnMouseEnter(control)
	DSC.viewerManager:EnterRow(control)
end

-- ** Stop Highlighting Row on Mouse Exit ** --
function DSC.ViewerRow_OnMouseExit(control)
	DSC.viewerManager:ExitRow(control)
end

-- ** SHow Reset Filter tooltip control ** --
function DSC.ViewerResetFilters_OnMouseEnter(control)
	InitializeTooltip(InformationTooltip, control, BOTTOMRIGHT, 0, 0, TOPLEFT)
	SetTooltipText(InformationTooltip, "Reset Filter")
end

-- ** Hide Reset Filter tooltip ** --
function DSC.ViewerResetFilters_OnMouseExit(control)
	ClearTooltip(InformationTooltip)
end

-- ** Reset CLicked? Then sets dropdown to All Guilds and clears the name search box ** --
function DSC.ViewerResetFilters_OnClicked(self)
	local manager = DSC.viewerManager
	manager.guildFilter:SelectFirstItem()
	manager.nameFilterBox:Clear()
end

-- ** Show Open Settings Menu tooltip ** --
function DSC.ViewerSettings_OnMouseEnter(control)
	InitializeTooltip(InformationTooltip, control, BOTTOMRIGHT, 0, 0, TOPLEFT)
	SetTooltipText(InformationTooltip, "Open Settings Menu")
end

-- ** Hide Settings tooltip ** --
function DSC.ViewerSettings_OnMouseExit(control)
	ClearTooltip(InformationTooltip)
end

-- ** Open SlotsCount's settings menu ** --
function DSC.ViewerSettings_OnClicked(self)
	if DSC.settingsPanel then
		LibAddonMenu2:OpenToPanel(DSC.settingsPanel)
	end
end

-- ** Close SlotsCount's window when user moves ** --
local function DLC_OnViewerMovementStarted()
	if DSC.viewerManager and not DSC.viewerManager.control:IsHidden() then
		HideSlotsCountViewer()
	end
end

-- ** Set up Roster column, Scan button, Confirmation windows, Saved data, and Settings ** --
function DLC_SlotsCount:Initialize()
	DSC.slotsColumn = LibGuildRoster:AddColumn({
		key = 'DLCSlotsCount',
		width = 90,
     -- ** New Header  w/ MouseOver Tooltip for Column Title **					
		header = {
			title = "|ca0a0F3Listings|r",
			tooltip = function()			    
			    local guildID = GUILD_ROSTER_MANAGER.guildId
			    local guildName_IS = GetGuildName(guildID)
			    local sd = DSC.savedData	-- sd means savedData
			    if not sd then
				return "Saved data is not loaded."
			    end
			    if not sd.Guilds_Last_Scan or not sd.Guilds_Last_Scan[guildName_IS] then
				return "No scan has been performed."
			    end
			    local scan_Time = string.format(
				"Last Scan:\n%s",
				os.date("|cFFFFFF%m/%d/%Y %I:%M:%S %p|r", sd.Guilds_Last_Scan[guildName_IS])
			    )
			    local time_Is = GetTimeStamp()
			    local L_S_T = sd.Guilds_Last_Scan[guildName_IS]
			    local total_Seconds = math.floor(time_Is - L_S_T)
			    local time_Past_msg
			    -- ** Local Vars for Countdown Clock Text **
			    local min_Past = ""
			    local hours_Past = ""
			    local days_Past = math.floor(total_Seconds / 86400)

			    if total_Seconds < 60 then
			    	time_Past_msg = "|c27F538"..total_Seconds.." seconds ago|r"				-- GREEN TEXT
			    elseif total_Seconds < 3600 then
			    	if total_Seconds < 120 then
					min_Past = 1
					time_Past_msg = "|c27F538"..min_Past.." minute ago|r"				-- GREEN TEXT
				else
					min_Past = math.floor(total_Seconds / 60)
					time_Past_msg = "|c27F538"..min_Past.." minutes ago|r"				-- GREEN TEXT
			    	end			    	
			    elseif total_Seconds < 86400 then
			    	if total_Seconds < 7200 then
					hours_Past = 1
			    		time_Past_msg = "|cF5EE27"..hours_Past.." hour ago|r"				-- YELLOW TEXT
				else
					hours_Past = math.floor(total_Seconds / 3600)
					if hours_Past <= 3 then 
						time_Past_msg = "|cF5EE27"..hours_Past.." hours ago|r"			-- YELLOW TEXT
					elseif hours_Past > 3 and hours_Past < 8 then
						time_Past_msg = "|cFFAA00"..hours_Past.." hours ago|r"			-- ORANGE TEXT
					elseif hours_Past > 7 and hours_Past < 24 then
						time_Past_msg = "|cF53F27Last scan was "..hours_Past.." hours ago|cFFFFFF \n     New Scan Needed|r"	-- RED TEXT
					end
				end
			    else
			    	if days_Past == 1 then					-- RED TEXT
					time_Past_msg = "|cF53F27It\'s been "..days_Past.." day since last scan|cFFFFFF\n     New Scan Is Overdo \n     Drastic Measures will happen soon|r"
				elseif days_Past > 1 and days_Past < 7 then				-- RED TEXT
					time_Past_msg = "|cF53F27It\'s been "..days_Past.." days since last scan|cFFFFFF\n     New Scan Is Overdo \n     Drastic Measures will happen soon|r"
				else							-- RED TEXT
					time_Past_msg = "|cF53F27Last Scan was OVER a week ago|cFFFFFF \n     Drastic Measures are in place \n     Data is Now being Erased|r"
					self.ClearData()
				end
			    end
			    local t_members_listing = DLC_SlotsCount:GetGuildTotalMembersListing(sd.Guild_Members_Total_Listings[guildName_IS])
			    local t_Listings = sd.Guilds_Total_Listing_Counts[guildName_IS]
			    return scan_Time.."\n|cFFFFFF     "..time_Past_msg.."|r\nGuild\'s Total Listings:\n|cFFFFFF     "..t_Listings.."|r\nTotal Members Listing:\n|cFFFFFF     "..t_members_listing.."|r"
			end
		},
		row = {
			align = TEXT_ALIGN_CENTER,
			data = function(guildID, rowData, index)
			return DLC_SlotsCount:GetUserSlots(guildID, rowData.displayName)
			end,
			format = function(value)
				value = tonumber(value) or 0
				return zo_strformat("<<1>>", ZO_LocalizeDecimalNumber(value))
			end
		},
		guildFilter = { nil }
	})
	ZO_CreateStringId("SI_BINDING_NAME_DLC_SC_SCAN", "|cFFFFFFCount Slots|r")
	ZO_CreateStringId("SI_BINDING_NAME_DLC_SC_VIEWER_TOGGLE", "|cFFFFFFShow/Hide Slots Count|r")
	DSC.startScanButton = {
		name = "|ca0a0F3Count Slots|r",
		keybind = "DLC_SC_SCAN",
		-- Start scan when the user presses Count Slots button
		callback = function()
		DLC_SlotsCount:Scan()
		end,
		-- Disable Count Slots button whn a scan is running.
		enabled = function()
			return not DSC.isScanning
		end,
		alignment = KEYBIND_STRIP_ALIGN_LEFT
	}
     -- ** (Yes / NO) Dialog confirmation window to Clear savedData for uers account ** --			
	ZO_Dialogs_RegisterCustomDialog("DLC_SLOTSCOUNT_CLEAR_DATA",
	{
	    title = { text = self.COLOURS.purp.."Slots Count CLEAR|r", },
	    mainText = { text = self.COLOURS.tan.."Are you sure you want to Clear savedData, of this addon, for this account?\n\nThis action cannot be undone.|r", },
	    buttons = {
		{ text = self.COLOURS.orange.."Yes|r", callback = function(dialog) DLC_SlotsCount:ClearSavedData() end, },
		{ text = self.COLOURS.white.."No|r", callback = function(dialog) end, },
	    },
	})
     -- ** (Yes / NO) Dialog confirmation window to RESET ALL savedData for ALL Accounts ** --			
	ZO_Dialogs_RegisterCustomDialog("DLC_SLOTSCOUNT_RESET_DATA",
	{
	    title = { text = self.COLOURS.purp.."Slots Count RESET|r", },
	    mainText = { text = self.COLOURS.tan.."Are you sure you want to RESET, or NUKE, All savedData, of this Addon, for All accounts?\n\nThis action cannot be undone.|r", },
	    buttons = {
		{ text = self.COLOURS.red.."Yes|r", callback = function(dialog) DLC_SlotsCount:ResetSavedData() end, },
		{ text = self.COLOURS.white.."No|r", callback = function(dialog) end, },
	    },
	})

	DSC.savedData = ZO_SavedVars:NewAccountWide("SlotsCountData", DSC.savedDataVersion, worldName, nil, nil)
	self:buildSavedData()
	if DSC.viewerManager then
		DSC.viewerManager:RefreshGuildDropdown()
		DSC.viewerManager:RefreshData()
		if DSC.savedData.ViewerWindowLeft and DSC.savedData.ViewerWindowTop then
			DLCSlotsCountViewer:ClearAnchors()
			DLCSlotsCountViewer:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, DSC.savedData.ViewerWindowLeft, DSC.savedData.ViewerWindowTop)
		end
	end
	DLC_SlotsCount:SettingsMenu()
	logger:Info("SlotsCount initialized!")
end

-- ** Are We Loaded Yet??? ** --
local function DLC_OnAddonLoaded(event, addonName)
	if addonName == DSC.THIS_ADDON then
		DLC_SlotsCount:Initialize()
		SLASH_COMMANDS['/schelp'] = ShowSlashCommandHelp
		SLASH_COMMANDS['/sc_clear'] = DSC.ClearData
		SLASH_COMMANDS['/sc_save'] = DSC.SaveData
		SLASH_COMMANDS['/sc_reset'] = DSC.ResetData
		SLASH_COMMANDS['/slotscount'] = DSC.ToggleViewer
		SLASH_COMMANDS['/slots'] = DSC.ToggleViewer
		EVENT_MANAGER:UnregisterForEvent(DSC.THIS_ADDON, event)
		EVENT_MANAGER:RegisterForEvent(DSC.THIS_ADDON, EVENT_CLOSE_TRADING_HOUSE, DLC_OnTradingHouseClosed)
		EVENT_MANAGER:RegisterForEvent(DSC.THIS_ADDON, EVENT_OPEN_TRADING_HOUSE, DLC_OnTradingHouseOpened)
		EVENT_MANAGER:RegisterForEvent(DSC.THIS_ADDON, EVENT_NEW_MOVEMENT_IN_UI_MODE, DLC_OnViewerMovementStarted)
		logger:Info("SlotsCount Loaded!")
	end
end

EVENT_MANAGER:RegisterForEvent(DSC.THIS_ADDON, EVENT_ADD_ON_LOADED, DLC_OnAddonLoaded)
