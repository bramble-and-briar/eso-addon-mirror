PBsLowestPriceFinder = PBsLowestPriceFinder or {}
local ADDON = PBsLowestPriceFinder

---------------------------------------------------------------------------------------------------
-- Start-up, events and the /lpf command
---------------------------------------------------------------------------------------------------

local Print = ADDON.Print
local SafeCall = ADDON.SafeCall

-- The version is written only in the manifest's ## Title line; read it back from there.
local function ReadManifestVersion()
	local manager = GetAddOnManager()
	for index = 1, manager:GetNumAddOns() do
		local name, title = manager:GetAddOnInfo(index)
		if name == ADDON.name and title then
			local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
			return plain:match("([%d]+[%d%.]*)%s*$") or ""
		end
	end
	return ""
end

---------------------------------------------------------------------------------------------------
-- /lpf probe: what the game tells the add-on at a guild trader
--
-- Printed with plain English labels on purpose: it is for reading a measurement back to the author,
-- not for the player. Everything the add-on assumes about the guild store is asked here.
---------------------------------------------------------------------------------------------------

function ADDON:Probe()
	local function P(text)
		Print("[lpf probe] " .. text)
	end
	local function Show(value)
		if value == nil then
			return "nil"
		end
		return tostring(value)
	end

	P(string.format("%s, API %s, language %s", ADDON.title, Show(SafeCall(GetAPIVersion)), Show(SafeCall(GetCVar, "language.2"))))
	local open = ADDON.scan.open
	P("guild trader open: " .. tostring(open) .. ", interaction type " .. Show(SafeCall(GetInteractionType)) .. " (trading house is " .. Show(INTERACTION_TRADINGHOUSE) .. ")")

	-- Is any function the add-on calls restricted? Asking is itself unmeasured on a console.
	if type(IsPrivateFunction) == "function" then
		for _, name in ipairs(ADDON.scan.RAW_FUNCTIONS) do
			local private = SafeCall(IsPrivateFunction, name)
			local protected = SafeCall(IsProtectedFunction, name)
			P(string.format("%s: private=%s protected=%s", name, Show(private), Show(protected)))
		end
	else
		P("IsPrivateFunction does not exist here")
	end

	if not open then
		P("(open a guild trader for the rest; /lpf probe arms it)")
		return
	end

	local trader = ADDON:ReadTrader()
	P(string.format("trader NPC: read from=%s name=%s isGuildKiosk=%s ownerGuildId=%s", Show(trader.tag), Show(trader.kiosk), Show(trader.isKiosk), Show(trader.ownerId)))
	local hint = ADDON.chatterTrader
	P(string.format("read when the talk began: %s", hint and string.format("name=%s ownerGuildId=%s", Show(hint.kiosk), Show(hint.ownerId)) or "nothing (not a guild kiosk, or no talk seen)"))
	P(string.format("here: zone='%s' location='%s' subzone='%s' zoneId=%s x=%s z=%s", trader.zone, trader.loc, trader.sub, Show(trader.zoneId), Show(trader.x), Show(trader.z)))
	P(string.format("traders change at (despawn timestamp): %s, now %s", Show(trader.validUntil), Show(GetTimeStamp())))

	local selected = SafeCall(GetSelectedTradingHouseGuildId)
	local _, selectedName = SafeCall(GetCurrentTradingHouseGuildDetails)
	P(string.format("selected store: id=%s name=%s", Show(selected), Show(selectedName)))

	local count = SafeCall(GetNumTradingHouseGuilds) or 0
	P("stores the trading house offers: " .. count)
	for index = 1, count do
		local guildId, name, alliance = SafeCall(GetTradingHouseGuildDetails, index)
		P(string.format("  %d: id=%s name=%s alliance=%s canBuy=%s canSell=%s", index, Show(guildId), Show(name), Show(alliance),
			Show(guildId and SafeCall(CanBuyFromTradingHouse, guildId)), Show(guildId and SafeCall(CanSellOnTradingHouse, guildId))))
	end

	local own = SafeCall(GetNumGuilds) or 0
	P("guilds the player is in: " .. own)
	for index = 1, own do
		local guildId = SafeCall(GetGuildId, index)
		P(string.format("  %d: id=%s name=%s tradingHousePrivilege=%s ownedTrader=%s", index, Show(guildId), Show(guildId and SafeCall(GetGuildName, guildId)),
			Show(guildId and SafeCall(DoesGuildHavePrivilege, guildId, GUILD_PRIVILEGE_TRADING_HOUSE)),
			Show(guildId and SafeCall(GetGuildOwnedKioskInfo, guildId))))
	end

	P(string.format("search cooldown left: %s ms, min letters in a name: %s", Show(SafeCall(GetTradingHouseCooldownRemaining)), Show(SafeCall(GetMinLettersInTradingHouseItemNameForCurrentLanguage))))
	P(string.format("max name hashes in one filter: %s", Show(SafeCall(GetMaxTradingHouseFilterExactTerms, TRADING_HOUSE_FILTER_TYPE_NAME_HASH))))
end

---------------------------------------------------------------------------------------------------
-- /lpf
---------------------------------------------------------------------------------------------------

local function CountKeys(map)
	local n = 0
	for _ in pairs(map) do
		n = n + 1
	end
	return n
end

local function PrintStatus()
	local sv = ADDON.sv
	local scan = ADDON.scan
	Print(string.format("%s: %d item(s) watched, %d with prices, %d trader place(s), %d guild(s) placed.", ADDON.title, #sv.watch, CountKeys(sv.prices), CountKeys(sv.places.kiosks), CountKeys(sv.places.guilds)))
	Print(string.format("auto search %s (skips what is under %d min old), ignore prices older than %d day(s), panel %s (%d s, size %d).", tostring(sv.autoScan), sv.rescanMinutes, sv.maxAgeDays, tostring(sv.panel), sv.panelHoldSec, sv.panelSize))
	Print(string.format("trader open: %s, search running: %s, stopped by an error: %s.", tostring(scan.open), tostring(scan.run ~= nil), tostring(scan.broken)))
end

local function PrintLog()
	local log = ADDON.log
	if #log == 0 then
		Print(GetString(SI_PBSLPF_LOG_EMPTY))
		return
	end
	local first = math.max(1, #log - 29)
	for index = first, #log do
		Print(log[index])
	end
end

local function OnSlashCommand(text)
	local word, rest = (text or ""):match("^%s*(%S*)%s*(.-)%s*$")
	word = zo_strlower(word or "")
	local sv = ADDON.sv

	if word == "" or word == "show" then
		local limit = 3
		if zo_strlower(rest) == "all" then
			limit = nil
		end
		ADDON:PrintReport(limit)
		ADDON.panel:Show()
	elseif word == "find" then
		ADDON:Find(rest)
	elseif word == "add" then
		ADDON:AddWatch(rest)
		ADDON.panel:Refresh()
	elseif word == "remove" or word == "rm" or word == "del" then
		local index = ADDON:FindWatch(rest)
		if index then
			local _, entry = ADDON:RemoveWatch(index)
			Print(ADDON.Format(SI_PBSLPF_REMOVE_DONE, ADDON:WatchLabel(entry)))
			ADDON.panel:Refresh()
		else
			Print(ADDON.Format(SI_PBSLPF_REMOVE_NONE, rest))
		end
	elseif word == "list" then
		ADDON:PrintList()
	elseif word == "scan" then
		ADDON.scan:Request()
	elseif word == "auto" then
		local value = zo_strlower(rest)
		if value == "on" or value == "off" then
			sv.autoScan = value == "on"
		else
			sv.autoScan = not sv.autoScan
		end
		Print(GetString(sv.autoScan and SI_PBSLPF_AUTO_ON or SI_PBSLPF_AUTO_OFF))
	elseif word == "panel" then
		ADDON.panel:Show()
	elseif word == "forget" then
		ADDON:ForgetData()
		Print(GetString(SI_PBSLPF_FORGOT))
		ADDON.panel:Refresh()
	elseif word == "clear" then
		ADDON:ClearWatch()
		Print(GetString(SI_PBSLPF_CLEARED))
		ADDON.panel:Refresh()
	elseif word == "probe" then
		if ADDON.scan.open then
			ADDON:Probe()
		else
			ADDON.scan.probeNext = true
			ADDON:Probe()
			Print(GetString(SI_PBSLPF_PROBE_ARMED))
		end
	elseif word == "log" then
		PrintLog()
	elseif word == "status" then
		PrintStatus()
	else
		Print(GetString(SI_PBSLPF_HELP))
	end
end
ADDON.OnSlashCommand = OnSlashCommand

---------------------------------------------------------------------------------------------------
-- Start-up
---------------------------------------------------------------------------------------------------

local function OnAddOnLoaded(_, addonName)
	if addonName ~= ADDON.name then
		return
	end
	local em = EVENT_MANAGER
	em:UnregisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED)

	ADDON.version = ReadManifestVersion()
	ADDON.title = ADDON.version ~= "" and (ADDON.displayName .. " " .. ADDON.version) or ADDON.displayName

	ADDON.sv = ZO_SavedVars:NewAccountWide(ADDON.SAVED_VARS_NAME, ADDON.SAVED_VARS_VERSION, nil, ADDON.DEFAULTS)
	-- 0.2.0 kept what its experiment with searching other guilds' stores by ID learned; the game refuses that, so
	-- the setting and its record are dropped from the saved variables.
	ADDON.sv.tryKnownGuilds = nil
	ADDON.sv.reach = nil
	-- 0.3.3 dropped "search every store": a scan always covers every store the trader offers.
	ADDON.sv.allStores = nil

	local scan = ADDON.scan
	em:RegisterForEvent(ADDON.name .. "Open", EVENT_OPEN_TRADING_HOUSE, function()
		scan:OnOpen()
	end)
	em:RegisterForEvent(ADDON.name .. "Close", EVENT_CLOSE_TRADING_HOUSE, function()
		scan:OnClose()
	end)
	em:RegisterForEvent(ADDON.name .. "Chatter", EVENT_CHATTER_BEGIN, function()
		ADDON:NoteChatter(GetTimeStamp())
	end)
	em:RegisterForEvent(ADDON.name .. "Status", EVENT_TRADING_HOUSE_STATUS_RECEIVED, function()
		scan:OnStatus()
	end)
	em:RegisterForEvent(ADDON.name .. "Match", EVENT_MATCH_TRADING_HOUSE_ITEM_NAMES_COMPLETE, function(_, taskId, numResults)
		scan:OnMatchComplete(taskId, numResults)
	end)
	em:RegisterForEvent(ADDON.name .. "Response", EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, function(_, responseType, result)
		scan:OnResponse(responseType, result)
	end)
	em:RegisterForEvent(ADDON.name .. "Error", EVENT_TRADING_HOUSE_ERROR, function(_, errorCode)
		scan:OnError(errorCode)
	end)
	em:RegisterForEvent(ADDON.name .. "Timeout", EVENT_TRADING_HOUSE_RESPONSE_TIMEOUT, function(_, responseType)
		scan:OnTimeout(responseType)
	end)

	SLASH_COMMANDS["/lpf"] = OnSlashCommand

	if ADDON.InitializeSettings then
		ADDON:InitializeSettings()
	end
end

EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
