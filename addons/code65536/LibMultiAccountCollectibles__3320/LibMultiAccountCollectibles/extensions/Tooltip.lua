local LCCC = LibCodesCommonCode
local LMAC = LibMultiAccountCollectibles
local LEJ = LibExtendedJournal
local Internal = LibMultiAccountCollectiblesInternal

-- The tooltip extension is available only to users of an Extended Journal addon
if (not LEJ or not LEJ.HookItemTooltips) then return end

local Vars


--------------------------------------------------------------------------------
-- GenerateAccountList
--------------------------------------------------------------------------------

local function GenerateAccountList( server, accounts, collectibleId )
	local results = Internal.GetScratch()
	for _, account in ipairs(accounts) do
		local unlocked = LMAC.IsCollectibleOwnedByAccount(server, account, collectibleId)
		table.insert(results, string.format("|c%06X%s|r", LEJ.GetTooltipColor(2, unlocked and 1 or 2), account))
	end
	return table.concat(results, ", ")
end


--------------------------------------------------------------------------------
-- AddTooltipExtension
--------------------------------------------------------------------------------

local function AddTooltipExtension( tooltip, item, server )
	-- item can either be a collectible item link, a collectible container, or a direct ID
	local collectibleId = GetCollectibleIdFromLink(item) -- nil if invalid
	if (type(collectibleId) ~= "number") then
		if (type(item) == "number") then
			collectibleId = item
		else
			collectibleId = GetItemLinkContainerCollectibleId(item) -- 0 if invalid
		end
	end

	-- Abort if the item is not something we can handle
	if (collectibleId == 0) then return end

	local servers = LMAC.GetServerAndAccountList(true)

	if (Vars.multiServer and #servers >= 2) then
		local extension = LEJ.TooltipExtensionInitialize(true)

		for _, data in ipairs(servers) do
			extension:AddSection(
				string.format("[%s] %s", data.server, GetString(SI_MACTT_COLLECTED_BY)),
				GenerateAccountList(data.server, data.accounts, collectibleId)
			)
		end

		extension:Finalize(tooltip)
	else
		local placeholder = -1

		-- If no server is specified, then default to the first set (current server)
		local accounts = server and placeholder or nil
		for _, data in ipairs(servers) do
			if (data.server == server or not accounts) then
				accounts = data.accounts
			end
		end

		-- Accounts section
		if (accounts ~= placeholder and #accounts > 1) then
			local extension = LEJ.TooltipExtensionInitialize(false)
			extension:AddSection(GetString(SI_MACTT_COLLECTED_BY), GenerateAccountList(server, accounts, collectibleId))
			extension:Finalize(tooltip)
		end
	end
end


--------------------------------------------------------------------------------
-- HookExternalTooltips
--------------------------------------------------------------------------------

local AreExternalTooltipsHooked = false

local function HookExternalTooltips( )
	if (AreExternalTooltipsHooked or not Vars.enabled) then return end
	AreExternalTooltipsHooked = true

	LEJ.HookItemTooltips(function( control, functionName, itemLink, sourceContext )
		if (Vars.enabled) then
			AddTooltipExtension(control, itemLink)
		end
	end)
end


--------------------------------------------------------------------------------
-- RegisterSettingsPanel
--------------------------------------------------------------------------------

local function RegisterSettingsPanel( )
	local LAM = LCCC.GetLibAddonMenu()

	if (LAM) then
		local panelId = "MACTT"

		LAM:RegisterAddonPanel(panelId, {
			type = "panel",
			name = GetString(SI_MACTT_TITLE),
			author = "@code65536",
			registerForRefresh = true,
		})

		LAM:RegisterOptionControls(panelId, {
			--------------------------------------------------------------------
			{
				type = "checkbox",
				name = SI_MACTT_ENABLE_SETTING,
				getFunc = function() return Vars.enabled end,
				setFunc = function( enabled )
					Vars.enabled = enabled
					if (enabled) then
						HookExternalTooltips()
					end
				end,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_MACTT_MULTI_SERVER,
				getFunc = function() return Vars.multiServer end,
				setFunc = function(enabled) Vars.multiServer = enabled end,
				disabled = function() return #LMAC.GetServerAndAccountList(true) < 2 end
			},
			--------------------
			{
				type = "colorpicker",
				name = SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_UNLOCKED,
				getFunc = function() return LEJ.GetTooltipColorUnpacked(2, 1) end,
				setFunc = function(...) LEJ.SetTooltipColor(2, 1, ...) end,
			},
			--------------------
			{
				type = "colorpicker",
				name = SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED,
				getFunc = function() return LEJ.GetTooltipColorUnpacked(2, 2) end,
				setFunc = function(...) LEJ.SetTooltipColor(2, 2, ...) end,
			},
		})
	end
end


--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

LCCC.RunAfterInitialLoadscreen(function( )
	local defaults = {
		enabled = true,
		multiServer = false,
	}
	Vars = ZO_SavedVars:NewAccountWide("MultiAccountCollectiblesTooltip", 1, nil, defaults, nil, "$InstallationWide")

	RegisterSettingsPanel()
	HookExternalTooltips()
	LMAC.AddTooltipExtension = AddTooltipExtension
end)
