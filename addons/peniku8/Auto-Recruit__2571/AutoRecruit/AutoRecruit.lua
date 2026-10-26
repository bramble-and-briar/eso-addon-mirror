if AutoRecruit == nil then AutoRecruit = {} end
local AR = AutoRecruit
local em = EVENT_MANAGER
AutoRecruitKeybind = {}

AR.name = "AutoRecruit"
AR.version = "3.2.1"
AR.cooldown = {0, 0, 0, 0, 0}
AR.inviteeID = "@"
AR.posted = ""
AR.lastPosted = {}
AR.doubleCheck = 0
AR.onlinePlayers = {}
AR.zones = {}
AR.nextZone = 1
AR.status = 0
AR.lastRound = 0
AR.failed = 0
AR.portingTo = nil
AR.mailBoxOpen = false
AR.settings = {}
AR.defaults = {
    recruitFor = GetGuildName(GetGuildId(1)),

    whisperEnabled = false,
    standardEnabled = true,
    keyword = "",
    caseSensitive = false,

    notifications = true,
    trader = true,
    warning = 5,
    shown = true,
		showPending = true,

    portMode = "Semi-auto",
    postAd = true,
    keepPorting = false,
    portingTime = 15,
    skipZoneOnCD = true,
		logSkippedZones = true,
    includedZones = "Major",
		prioritisePortToHouse = false,
    saveLastPosted = true,
		showZonesGrid = "Hidden",

    guild1 = false,
    ad = {"", "", "", "", ""},
    guild = {},
    welcome = {},
    welcomeText = {"", "", "", "", ""},
    welcomeCooldown = {30, 30, 30, 30, 30},
    adCooldown = {15, 15, 15, 15, 15},
		mailMode = {"Disabled", "Disabled", "Disabled", "Disabled", "Disabled"},
		mailSubject = {"", "", "", "", ""},
		mailBody = {"", "", "", "", ""},
}


	function AR.getIDfromName(guildname)
		for guild = 1, GetNumGuilds() do
		  if guildname == GetGuildName(GetGuildId(guild))
		   then return GetGuildId(guild)
	    end
	  end
	end
	

	function AR.getGuildIndex(guildID)
		for guild = 1, GetNumGuilds() do
		  if guildID == GetGuildId(guild) then
		  	return guild
	    end
	  end
	end


  function AR.checkFor(string1, string2)
  	if string1 == nil or string2 == nil then
  		return false
  	 elseif string.match(string1, string2) == string2 then
  	 	return true
  	 else
  	 	return false
  	end
  end

	function AR.AttachAcceptApplicationCallback()
		local existingCallback = ESO_Dialogs["GUILD_ACCEPT_APPLICATION"].buttons[1].callback

		ESO_Dialogs["GUILD_ACCEPT_APPLICATION"].buttons[1].callback = function(dialog)
			AR.acceptedID = dialog.data.name
			--d("AR.AttachAcceptApplicationCallback: " .. AR.acceptedID)
			existingCallback(dialog)
		end
	end

  function AutoRecruitKeybind.pasteText(guild)
  	CHAT_SYSTEM:Maximize()
    local currentZone = GetPlayerActiveZoneName()

  	if string.len(AR.settings.ad[guild]) > 0 then
  	 	local cooldown = 0

  	 	if AR.lastPosted[currentZone] then
  	 		cooldown = math.ceil((AR.settings.adCooldown[guild]*60-(GetTimeStamp()-AR.lastPosted[currentZone]))/60)
  	 	end

  	 	if cooldown>1 and AR.doubleCheck ~= 1 then
  	 		d(zo_strformat("|c6C00FFAuto Recruit - |cFFFFFF <<1>> still on cooldown for <<2>> more minutes", currentZone, cooldown))
  	 		zo_callLater(function() d("|cFFFFFFPress 'Paste' again within 5 seconds to post it anyways") end, 1500)
  	 		AR.doubleCheck = 1
  	 		zo_callLater(function() AR.doubleCheck = 0 end, 6000)
  	 	 elseif cooldown==1 and AR.doubleCheck ~= 1 then
  	 		d(zo_strformat("|c6C00FFAuto Recruit - |cFFFFFF <<1>> still on cooldown for <<2>> more minute", currentZone, cooldown))
  	 		zo_callLater(function() d("|cFFFFFFPress 'Paste' again within 5 seconds to post it anyways") end, 1500)
  	 		AR.doubleCheck = 1
  	 		zo_callLater(function() AR.doubleCheck = 0 end, 6000)
  	 	 else
				d(zo_strformat("|c82fa58Recruitment message for <<1>> pasted to the chat (<<2>>)", GetGuildName(GetGuildId(guild)), currentZone))
    		ZO_ChatWindowTextEntryEditBox:SetText("/z " .. AR.settings.ad[guild])
    		AR.settings.recruitFor = GetGuildName(GetGuildId(guild))
				AR.RefreshWindow()
  	  end
  	 else
		d(zo_strformat("|c6C00FFAuto Recruit - |cFF8174You have not specified a recruitment message for <<1>> yet.", GetGuildName(GetGuildId(guild))))
  	end
  end

	function AutoRecruitKeybind.pasteWelcome()
		if AR.inviteeID then
			AR.pasteWelcomeMessage(AR.inviteeGuildID, AR.inviteeID)
		else
			d("|c6C00FFAuto Recruit - |cFF8174No recently accepted guild member found. Cannot paste welcome message.")
		end
	end

  function AutoRecruitKeybind.openMail()
		local guild = AR.getGuildIndex(AR.inviteeGuildID)
		if AR.settings.mailMode[guild] == "Disabled" then
			d("|c6C00FFAuto Recruit - |cFF8174Guild does not have a welcome mail enabled.")
		elseif #AR.inviteeID < 2 then
			if GetDisplayName() == '@SirNightstorm' then
				AR.inviteeID = '@NightstormII'
				AR.inviteeGuildID = GetGuildId(1)
				ZO_Dialogs_ShowPlatformDialog("AUTORECRUIT_SHOW_MAIL", {}, {mainTextParams = {'@NightstormII', GetGuildName(AR.inviteeGuildID)}})
			else
				d("|c6C00FFAuto Recruit - |cFF8174No recently accepted guild member found. Cannot create welcome mail.")
			end
		else
			ZO_Dialogs_ShowPlatformDialog("AUTORECRUIT_SHOW_MAIL", {}, {mainTextParams = {AR.inviteeID, GetGuildName(AR.inviteeGuildID)}})
		end
	end

  function AR.freeSpots(guildID)
  	local freeSpots = 500-zo_strformat("<<1>>", GetGuildInfo(guildID))-zo_strformat("<<4>>", GetGuildInfo(guildID))

  	if freeSpots<=AR.settings.warning then
  		if freeSpots == 0 then
  			return ("|cFF8174This guild is now full!")
  		 elseif freeSpots == 1 then
  			return ("|c82fa58There is just|cFF8174 1 |c82fa58free spot left. Please notify |cFFFFFF" .. zo_strformat("<<3>>", GetGuildInfo(guildID)) .. ".")
  		 else
  			return ("|c82fa58There are just |cFF8174" .. freeSpots .. "|c82fa58 free spots left. Please notify |cFFFFFF" .. zo_strformat("<<3>>", GetGuildInfo(guildID)) .. ".")
  		end
  	 else
  	 	return ("|c82fa58There are " .. freeSpots .. " free spots left.")
  	end
  end

function AR.substitutePlaceholders(text, userID)
	-- Replace '@@' with the full userID, including '@' prefix
	text = string.gsub(text, "@@", userID)
	-- Replace '@' with the userID without '@' prefix
  userID = string.gsub(userID, "@", "")
	return string.gsub(text, "@", userID)
end

  function AR.pasteWelcomeMessage(guildID, userID)
		local guild = AR.getGuildIndex(guildID)

		if GetGuildMemberIndexFromDisplayName(guildID, userID) then
			local message = AR.substitutePlaceholders(AR.settings.welcomeText[guild], userID)
			local messageAnon = string.gsub(string.gsub(AR.settings.welcomeText[guild], ", @", "", 1), " @", "", 1)
			local _, _, _, playerStatus = GetGuildMemberInfo(guildID, GetGuildMemberIndexFromDisplayName(guildID, userID))

			if playerStatus~=4 then
				if AR.cooldown[guild]<GetTimeStamp() and string.len(ZO_ChatWindowTextEntryEditBox:GetText())==0 then
					CHAT_SYSTEM:Maximize()
					ZO_ChatWindowTextEntryEditBox:SetText("/g" .. guild .. " " .. message)
				elseif ZO_ChatWindowTextEntryEditBox:GetText() == AR.posted then -- multiple players accepted
					CHAT_SYSTEM:Maximize()
					ZO_ChatWindowTextEntryEditBox:SetText("/g" .. guild .. " " .. messageAnon)
				end
				AR.posted = (ZO_ChatWindowTextEntryEditBox:GetText())
			end
		end
	end

	function AR.createMail(guildID, userID)
		local guildIndex = AR.getGuildIndex(guildID)
		local subject = AR.substitutePlaceholders(AR.settings.mailSubject[guildIndex], userID)
		local body = AR.substitutePlaceholders(AR.settings.mailBody[guildIndex], userID)

		SCENE_MANAGER:Show('mailSend')
		zo_callLater(function()
			ZO_MailSendToField:SetText(userID)
			ZO_MailSendSubjectField:SetText(subject)
			ZO_MailSendBodyField:SetText(body)
			ZO_MailSendBodyField:TakeFocus()
		end, 200)
	end

	function AR.sendMail(guildID, userID)
		if not AR.mailBoxOpen then
			RequestOpenMailbox()
			zo_callLater(function() AR.sendMail(guildID, userID) end, 500)
			return
		end

		local guildIndex = AR.getGuildIndex(guildID)
		local subject = AR.substitutePlaceholders(AR.settings.mailSubject[guildIndex], userID)
		local body = AR.substitutePlaceholders(AR.settings.mailBody[guildIndex], userID)

		AR.sendingMail = true
		SendMail(userID, subject, body)

		d(zo_strformat("|c6C00FFAuto Recruit - |cFFFFFF Sending mail to <<1>> of <<2>>", userID, GetGuildName(guildID)))
		--d(zo_strformat("[<<1>>][<<2>>][<<3>>]", userID, subject, body))
	end

  function AR.memberAdded(_, guildID, userID)
  	local guild = AR.getGuildIndex(guildID)

  	if AR.settings.notifications then
  		CHAT_SYSTEM:Maximize()
    	for i=1, GetNumGuilds() do
        if guildID == AR.getIDfromName(AR.settings.recruitFor) or guildID == GetGuildId(i) and AR.settings.guild[i] then
         	if not GetGuildMemberIndexFromDisplayName(guildID, userID) then
         		d("|cFFFFFF" .. userID .. "|c82fa58 has been invited to " .. GetGuildName(guildID) .. ".")
   			   else
   			   	d("|cFFFFFF" .. userID .. "|c82fa58 joined " .. GetGuildName(guildID) .. ".")
   				  d(AR.freeSpots(guildID))
   				end
   			  break
        end
  		end
	  end

		if userID == AR.acceptedID and -- We accepted this user
		   GetGuildMemberIndexFromDisplayName(guildID, userID) then
			AR.inviteeID = userID
			AR.inviteeGuildID = guildID
			local _, _, _, playerStatus = GetGuildMemberInfo(guildID, GetGuildMemberIndexFromDisplayName(guildID, userID))
			if playerStatus~=4 then -- Online
				if AR.settings.welcome[guild] then
					AR.pasteWelcomeMessage(guildID, userID)
				end
			else -- Offline
				if AR.settings.mailMode[guild] == "Ask" then
					ZO_Dialogs_ShowPlatformDialog("AUTORECRUIT_SHOW_MAIL", {}, {mainTextParams = {userID, GetGuildName(guildID)}})
				elseif AR.settings.mailMode[guild] == "Automatic" then
					AR.sendMail(guildID, userID)
				end
			end
		else
			AR.inviteeID = nil
			AR.inviteeGuildID = nil
		end
  end


  function AR.Invite(userID)
  	local delay = math.random(2500, 10000)
  	local guildID = AR.getIDfromName(AR.settings.recruitFor)

  	zo_callLater(function()
  		CHAT_SYSTEM:Maximize()
  		GuildInvite(guildID, userID)
  		if AR.settings.trader and not GetGuildKioskAttribute(guildID) then
  			d("|cFF8174" .. AR.settings.recruitFor .. " has not hired a trader!")
  		end
  	end, delay)
  end


  function AR.context(userID)

    for guild = 1, GetNumGuilds() do
      local guildID = GetGuildId(guild)

      if DoesPlayerHaveGuildPermission(guildID, GUILD_PERMISSION_INVITE) and not GetGuildMemberIndexFromDisplayName(guildID, userID) then
        AddCustomMenuItem("|c82fa58Invite to |cFFFFFF" .. GetGuildName(guildID), function() GuildInvite(guildID, userID)  end)
      end

      if GetGuildMemberIndexFromDisplayName(guildID, userID) and DoesPlayerHaveGuildPermission(guildID, GUILD_PERMISSION_REMOVE)
       and tonumber(zo_strformat("<<3>>", GetGuildMemberInfo(guildID, GetGuildMemberIndexFromDisplayName(guildID, userID)))) > tonumber(zo_strformat("<<3>>", GetGuildMemberInfo(guildID, GetGuildMemberIndexFromDisplayName(guildID, GetDisplayName())))) then
      	AddCustomMenuItem("|cFF8174Kick from |cFFFFFF" .. GetGuildName(guildID), function() GuildRemove(guildID, userID) end)
      end
    end
  end


  function AR.getZones()
	  AR.zones = {}
    local minSkyshards = (AR.settings.includedZones == "All") and 0 or 15

    for i = 1, GetNumMaps() do
      local _, _, _, zoneIndex, _ = GetMapInfoByIndex(i)
      local zoneID = GetZoneId(zoneIndex)
	  -- Include parent zones, plus Apocrypha, Arteum and Solstice;
	  -- exclude "Clean Test", Cyrodiil and Imperial City
      if (zoneID == GetParentZoneId(zoneID) or zoneID==1413 or zoneID==1027 or zoneID == 1502) and
					(GetNumSkyshardsInZone(zoneID)>=minSkyshards or zoneID == 1502) and
          zoneID~=181 and zoneID~=584 and zoneID~=2 and CanJumpToPlayerInZone(zoneID) then
        table.insert(AR.zones, zoneID)
      end
    end

		if minSkyshards == 0 then
			-- The Brass Fortress is a separate zone chat area, but not on a top-level map
			table.insert(AR.zones, 981)
		end
  end


  function AR.getOnlinePlayers()
  	AR.onlinePlayers = {}
  	for guild=1, GetNumGuilds() do
  		local guildID = GetGuildId(guild)

  		for i=1, GetNumGuildMembers(guildID) do
  			local userID, _, _, playerStatus = GetGuildMemberInfo(guildID, i)

  			if playerStatus~=4 and userID~=GetDisplayName() then
  			  local _, _, _, _, _, _, _, zoneID = GetGuildMemberCharacterInfo(guildID, i)
  			  table.insert(AR.onlinePlayers, { userID, zoneID })
  			end
    	end
    end
  end

  function AR.getHouses()
    AR.zoneHouses = {}
    local function IsHousingCat(categoryData)
      return categoryData:IsHousingCategory()
    end
  
    local function IsHouseCollectible(collectibleData)
      return collectibleData:IsCategoryType(COLLECTIBLE_CATEGORY_TYPE_HOUSE)
    end
  
    for _, categoryData in ZO_COLLECTIBLE_DATA_MANAGER:CategoryIterator({IsHousingCat}) do
      for _, subCategoryData in categoryData:SubcategoryIterator({IsHousingCat}) do
        for _, subCatCollectibleData in subCategoryData:CollectibleIterator({IsHouseCollectible}) do
          if subCatCollectibleData:IsUnlocked() and not subCatCollectibleData:IsBlocked() then
            local houseID = subCatCollectibleData:GetReferenceId()
            local zoneID = GetHouseFoundInZoneId(houseID)
            if not AR.zoneHouses[zoneID] then
              local name, _, _, _, _, _, _, _, _ = GetCollectibleInfo(subCatCollectibleData:GetId())
              AR.zoneHouses[zoneID] = { houseID, name }
            end
          end
        end
      end
    end
  end
  
  function AutoRecruitKeybind.start()
  	AR.status = 1
  	AR.start()
  end


  function AutoRecruitKeybind.stop()
  	AR.status = 0
  	AR.stop()
  end

local function OnMailOpenMailBox()
	AR.mailBoxOpen = true
	--d("|c2DC50EMail Box Opened!")
end

local function OnMailCloseMailBox()
	AR.mailBoxOpen = false
	--d("|cC80F14Mail Box Closed!")
end

local function OnMailSendSuccess()
	if AR.sendingMail then
		d(zo_strformat("|c6C00FFAuto Recruit - |cFFFFFF Sent mail to <<1>>", AR.inviteeID))
		CloseMailbox()
		AR.sendingMail = false
	end
end

local function OnMailSendFailed(_, reason)
	local error = "Unknown error"
	if     reason == 8  then error = "COD Error"
	elseif reason == 11 then error = "Self"
	elseif reason == 7  then error = "Blank Mail"
	elseif reason == 1  then error = "DB Error"
	elseif reason == 4  then error = "Ignored"
	elseif reason == 10 then error = "In Progress"
	elseif reason == 2  then error = "Invalid Name"
	elseif reason == 3  then error = "Full Inbox"
	elseif reason == 6  then error = "Invalid Item"
	elseif reason == 12 then error = "Mail Disabled"
	elseif reason == 13 then error = "Mailbox Closed"
	elseif reason == 9  then error = "COD Error"
	elseif reason == 5  then error = "Gold Error"
	elseif reason == 15 then error = "User Not Found"
	elseif reason == 0  then error = "Success"
	elseif reason == 14 then error = "Attachment Error"
	end
	d(zo_strformat("|c6C00FFAuto Recruit - |cFFFFFF Failed to send mail to <<1>>: <<3>>", AR.inviteeID, error))
	AR.sendingMail = false
end


function AR.Initialize(_, addon)
	if addon ~= AR.name then return end

	em:UnregisterForEvent("AutoRecruitInitialize", EVENT_ADD_ON_LOADED)

	AR.settings = ZO_SavedVars:NewAccountWide("AutoRecruitSavedVars", 1, nil, AR.defaults)
  if AR.settings.saveLastPosted then
    AR.lastPosted = ZO_SavedVars:NewAccountWide("AutoRecruitLastPosted", 1, nil, {})
  end

	ZO_CreateStringId("SI_BINDING_NAME_AUTO_RECRUIT_PASTE1", "Paste " .. GetGuildName(GetGuildId(1)) .. "'s Ad")
	ZO_CreateStringId("SI_BINDING_NAME_AUTO_RECRUIT_PASTE2", "Paste " .. GetGuildName(GetGuildId(2)) .. "'s Ad")
	ZO_CreateStringId("SI_BINDING_NAME_AUTO_RECRUIT_PASTE3", "Paste " .. GetGuildName(GetGuildId(3)) .. "'s Ad")
	ZO_CreateStringId("SI_BINDING_NAME_AUTO_RECRUIT_PASTE4", "Paste " .. GetGuildName(GetGuildId(4)) .. "'s Ad")
	ZO_CreateStringId("SI_BINDING_NAME_AUTO_RECRUIT_PASTE5", "Paste " .. GetGuildName(GetGuildId(5)) .. "'s Ad")
	ZO_CreateStringId("SI_BINDING_NAME_AUTO_RECRUIT_STARTPORT", "Start porting")
	ZO_CreateStringId("SI_BINDING_NAME_AUTO_RECRUIT_STOPPORT", "Stop porting")
	ZO_CreateStringId("SI_BINDING_NAME_AUTO_RECRUIT_PASTEWELCOME", "Paste Welcome Message")
	ZO_CreateStringId("SI_BINDING_NAME_AUTO_RECRUIT_MAIL", "Open Welcome mail form")

	AR.MakeMenu()
	AR.getZones()

	em:RegisterForEvent("AutoRecruitStart", EVENT_PLAYER_ACTIVATED, function(...) AR.RefreshWindow(...) end)
  em:RegisterForEvent("AutoRecruitStart", EVENT_CHAT_MESSAGE_CHANNEL, AR.chatMessage)
  em:RegisterForEvent("AutoRecruitStart", EVENT_ACTION_LAYER_POPPED, AR.chatMessage)
  em:RegisterForEvent("AutoRecruitInfo", EVENT_GUILD_MEMBER_ADDED, AR.memberAdded)

	em:RegisterForEvent(AR.name, EVENT_MAIL_OPEN_MAILBOX, OnMailOpenMailBox)
	em:RegisterForEvent(AR.name, EVENT_MAIL_CLOSE_MAILBOX, OnMailCloseMailBox)
	em:RegisterForEvent(AR.name, EVENT_MAIL_SEND_SUCCESS, OnMailSendSuccess)
	em:RegisterForEvent(AR.name, EVENT_MAIL_SEND_FAILED, OnMailSendFailed)

	LibCustomMenu:RegisterPlayerContextMenu(AR.context)

	AR.AttachAcceptApplicationCallback()

	local customShowMailDialog = {
		customControl = AR_SendMailDialog,
		title = { text = "Welcome Mail" },
		mainText = { text = function() return "Send a welcome message to <<1>> of <<2>>?" end },
		buttons = {
			{
				control = GetControl(AR_SendMailDialog, "Send"),
				keybind = "DIALOG_PRIMARY",
				text = "Send",
				callback = function()
					AR.sendMail(AR.inviteeGuildID, AR.inviteeID)
				end,
			}, {
				control = GetControl(AR_SendMailDialog, "Edit"),
				keybind = "DIALOG_SECONDARY",
				text = "Edit",
				callback = function()
					AR.createMail(AR.inviteeGuildID, AR.inviteeID)
				end
			}, {
				control = GetControl(AR_SendMailDialog, "Cancel"),
				keybind = "DIALOG_NEGATIVE",
				text = "Cancel",
			}
		}
	}
	ZO_Dialogs_RegisterCustomDialog("AUTORECRUIT_SHOW_MAIL", customShowMailDialog)
end

em:RegisterForEvent("AutoRecruitInitialize", EVENT_ADD_ON_LOADED, function(...) AR.Initialize(...) end)




function AR.afterPort(destination)
	em:UnregisterForEvent("AutoPortArrived", EVENT_PLAYER_ACTIVATED)

	if GetUnitWorldPosition("player") == destination then
		AR.failed = 0
		AR.portingTo = nil
		
		if AR.settings.postAd then
			AutoRecruitKeybind.pasteText(AR.getGuildIndex(AR.getIDfromName(AR.settings.recruitFor)))
		end

		if AR.status == 1 and AR.settings.portMode == "Full-auto" then AR.start() end
	end
end



function AR.portFailed(destination)
	local zoneName = GetZoneNameById(destination)

	if AR.status == 1 then
	  d(zo_strformat("|c6C00FFAuto Port - |cFFFFFFFailed to port to <<1>> trying again...", zoneName))
		AR.portingTo = nil
	  AR.nextZone = AR.nextZone - 1
	  AR.start()
	end
end

function AR.keepPorting()
	if AR.status ~= 2 then return end

	local delay = AR.settings.portingTime*60-(GetTimeStamp()-AR.lastRound)

	if delay<=5 then
		AR.start()
	else
		AR.RefreshWindow()

		if AR.settings.shown then
			delay = 5 -- If the window is visible, update status every 5 seconds
		else
			if delay>120 then
				d("|c6C00FFAuto Port - |cFFFFFFStarting another loop in " .. math.floor(delay/60) .. " minutes...")
				delay = 60
			elseif delay>60 then
				d("|c6C00FFAuto Port - |cFFFFFFStarting another loop in ~1 minute...")
				delay = delay - 45 -- next alert with 45 seconds left
			else
				d("|c6C00FFAuto Port - |cFFFFFFStarting another loop in " .. delay .. " seconds...")
				delay = 15
			end
		end
		zo_callLater(function() AR.keepPorting() end, delay*1000)
	end
end

function AR.start()
	if AR.status == 0 then return end

	if AR.status == 2 then
		d("|c6C00FFAuto Port - |cFFFFFFStarting another loop now...")
	end

  CancelCast()
	em:UnregisterForEvent("AutoPortArrived", EVENT_PLAYER_ACTIVATED)
	AR.status = 1


  if AR.nextZone > #AR.zones then
  	AR.status = 2
  	AR.nextZone = 1
  	d("|c6C00FFAuto Port - |cFFFFFFLoop finished")

  	if AR.settings.keepPorting then
			AR.keepPorting()
  	end

	  AR.RefreshWindow()
  	return
  end

  AR.getOnlinePlayers()
  AR.getHouses()
  local nextZoneName = GetZoneNameById(AR.zones[AR.nextZone])
  local guild = AR.getGuildIndex(AR.getIDfromName(AR.settings.recruitFor))
  local ownZone = GetUnitWorldPosition("player")

  if AR.nextZone == 1 then
  	AR.lastRound = GetTimeStamp()
  end

  if ownZone == AR.zones[AR.nextZone] then
  	AR.nextZone = AR.nextZone + 1
  end

 	if AR.lastPosted[nextZoneName] and AR.settings.skipZoneOnCD then
 		local cooldown = AR.settings.adCooldown[guild]*60-(GetTimeStamp()-AR.lastPosted[nextZoneName])

		if cooldown>10 then
			if AR.settings.logSkippedZones then
				d(zo_strformat("|c6C00FFAuto Port - |cFFFFFF<<1>> is still on cooldown. Skipping this zone...", nextZoneName))
			end
			AR.nextZone = AR.nextZone + 1
			AR.start()
			return
		end
 	end

	local portStarted

	-- Try to port to a house first if either the player chose it in Settings, or porting to a player has failed
	if AR.settings.prioritisePortToHouse or AR.failed > 0 then
		portStarted = AR.TryToPortToHouse(nextZoneName) or
				          AR.TryToPortToPlayer(ownZone)
	else
		portStarted = AR.TryToPortToPlayer(ownZone) or
				          AR.TryToPortToHouse(nextZoneName)
	end

	AR.RefreshWindow()

	if not portStarted then
		if AR.settings.logSkippedZones then
			d(zo_strformat("|c6C00FFAuto Port - |cFFFFFFCould not port to <<1>>. Skipping this zone...", nextZoneName))
		end
		AR.nextZone = AR.nextZone + 1
		AR.start()
	end
end

function AR.TryToPortToPlayer(ownZone)
	for i=1, #AR.onlinePlayers do
		local userID = AR.onlinePlayers[i][1]
		local userZone = AR.onlinePlayers[i][2]

		if userZone == AR.zones[AR.nextZone] and ownZone ~= userZone then
			d(zo_strformat("|c6C00FFAuto Port - |cFFFFFFJumping to <<1>> in <<2>>", userID, GetZoneNameById(userZone)))
			AR.nextZone = AR.nextZone + 1
			AR.portingTo = GetZoneNameById(userZone)
			zo_callLater(function() JumpToGuildMember(userID) end, 100)
			em:RegisterForEvent("AutoPortArrived", EVENT_PLAYER_ACTIVATED, function() AR.afterPort(userZone) end)
			zo_callLater(function()
				if ownZone==GetUnitWorldPosition("player") and userZone == AR.zones[AR.nextZone-1] then
					if AR.failed<3 then
						AR.failed = AR.failed + 1
						AR.portFailed(userZone)
					else
						d(zo_strformat("|c6C00FFAuto Port - |cFFFFFFPorting to <<1>> failed. Try again later.", GetZoneNameById(userZone)))
						AR.stop()
					end
				end
			end, 10000)
			return true
		end
	end

	return false
end

function AR.TryToPortToHouse(nextZoneName)
	local houseId = AR.zoneHouses[AR.zones[AR.nextZone]] --AR.HM:GetHouseIDFromZoneID(AR.zones[AR.nextZone])
	if houseId and CanJumpToHouseFromCurrentLocation() then
		local houseZone = AR.zones[AR.nextZone]
		local houseID, houseName = unpack(AR.zoneHouses[houseZone])
		d(zo_strformat("|c6C00FFAuto Port - |cFFFFFFJumping to <<1>> in <<2>>", houseName, nextZoneName))
		AR.nextZone = AR.nextZone + 1
		AR.portingTo = nextZoneName
		zo_callLater(function() RequestJumpToHouse(houseID, true) end, 100)
		em:RegisterForEvent("AutoPortArrived", EVENT_PLAYER_ACTIVATED, function() AR.afterPort(houseZone) end)
		return true
	end

	return false
end

function AR.stop()
	CancelCast()
	em:UnregisterForEvent("AutoPortArrived", EVENT_PLAYER_ACTIVATED)
  AR.status = 0
	d("|c6C00FFAuto Port - |cFFFFFFStopped porting.")
	AR.RefreshWindow()
end



function AR.chatMessage(_, channel, _, text, _, userID)
	if not text or string.len(text) < 1 then return end
	
	if channel == 2 and AR.settings.whisperEnabled then
		local key = AR.settings.keyword

		if not AR.settings.caseSensitive then
			text = string.lower(text)
			key = string.lower(AR.settings.keyword)
		end

		if AR.checkFor(text, key) and string.len(key) >= 1 and key ~= " " then
			AR.Invite(userID)
		end

		if AR.settings.standardEnabled then
			if AR.checkFor(text, "search") or AR.checkFor(text, "add") or AR.checkFor(text, "space") or AR.checkFor(text, "glad") or AR.checkFor(text, "need")
  			or AR.checkFor(text, "inv") or AR.checkFor(text, "+") or AR.checkFor(text, "join") or AR.checkFor(text, "sign") or AR.checkFor(text, "interest")
  			or AR.checkFor(text, "looking for") or AR.checkFor(text, "look for") and not AR.checkFor(text, "group") and not AR.checkFor(text, "raid")
  			and not AR.checkFor(text, "pve") and not AR.checkFor(text, "pvp")
			 then
				AR.Invite(userID)
			end
		end
	end
	
	
  if channel == 31 and text == AR.settings.ad[AR.getGuildIndex(AR.getIDfromName(AR.settings.recruitFor))] then
    AR.lastPosted[GetPlayerActiveZoneName()] = GetTimeStamp()
  end
  
  
	for guild=1, GetNumGuilds() do

		if AR.settings.welcomeText[guild] ~= nil and AR.settings.welcomeText[guild] ~= "" then
			local inviteeID = AR.inviteeID or ""
			local message = string.gsub(AR.settings.welcomeText[guild], "@", inviteeID, 1)
			message = string.gsub(message, "%W", "")
			local messageAnon = string.gsub(string.gsub(AR.settings.welcomeText[guild], ", @", "", 1), " @", "", 1)
			messageAnon = string.gsub(messageAnon, "%W", "")
			local text2 = string.gsub(text, "%W", "")

			if channel == 11+guild and (AR.checkFor(text2, message) or AR.checkFor(text2, messageAnon)) then
				AR.cooldown[guild] = GetTimeStamp() + (AR.settings.welcomeCooldown[guild]*60)

				if ZO_ChatWindowTextEntryEditBox:GetText() == text then
					ZO_ChatWindowTextEntryEditBox:Clear()
				end

				if AR.inviteeID ~= nil and AR.inviteeGuildID ~= nil then
					if AR.settings.mailMode[guild] == "Ask" then
						ZO_Dialogs_ShowPlatformDialog("AUTORECRUIT_SHOW_MAIL", {}, {mainTextParams = {AR.inviteeID, GetGuildName(AR.inviteeGuildID)}})
					elseif AR.settings.mailMode[guild] == "Automatic" then
						AR.sendMail(AR.inviteeGuildID, AR.inviteeID)
					end
				end
			end
		end
	end


	if channel == 31 and AR.status == 1 and AR.settings.portMode == "Semi-auto" and GetUnitWorldPosition("player") == AR.zones[AR.nextZone-1]
	   and userID == GetDisplayName() and text == AR.settings.ad[AR.getGuildIndex(AR.getIDfromName(AR.settings.recruitFor))] then
	 AR.start()
	end

	AR.RefreshWindow()
end