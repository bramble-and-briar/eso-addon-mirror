local LCCC = LibCodesCommonCode
local Internal = LibMultiAccountCollectiblesInternal
local Public = LibMultiAccountCollectibles


--------------------------------------------------------------------------------
-- Settings Panel
--------------------------------------------------------------------------------

function Internal.RegisterSettingsPanel( )
	local LAM = LCCC.GetLibAddonMenu()

	if (LAM) then
		local panelId = "LMACSettings"

		Internal.settingsPanel = LAM:RegisterAddonPanel(panelId, {
			type = "panel",
			name = Internal.name,
			version = LCCC.FormatVersion(LCCC.GetAddOnVersion(Internal.name)),
			author = "@code65536",
			website = "https://www.esoui.com/downloads/info3320.html",
			donation = "https://www.esoui.com/downloads/info3320.html#donate",
			slashCommand = "/lmac",
			registerForRefresh = true,
		})

		Internal.shareText = ""

		local getAccountList = function( key )
			local accounts = { }
			for account in pairs(Internal.GetVarsTable(key)) do
				table.insert(accounts, account)
			end
			table.sort(accounts)
			return table.concat(accounts, ", ")
		end

		local setAccountList = function( key, text )
			Internal.vars[key] = { }
			local accounts = { zo_strsplit(", ", zo_strlower(text)) }
			for _, account in ipairs(accounts) do
				Internal.vars[key][DecorateDisplayName(account)] = true
			end
		end

		LAM:RegisterOptionControls(panelId, {
			--------------------------------------------------------------------
			{
				type = "description",
				text = SI_LMAC_SETTINGS_CHATCOMMAND,
			},

			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_LMAC_SETTINGS_SHARE_SECTION,
			},
			--------------------
			{
				type = "editbox",
				name = SI_LMAC_SETTINGS_SHARE_CAPTION,
				getFunc = function() return Internal.shareText end,
				setFunc = function(text) Internal.shareText = text end,
				isMultiline = true,
				isExtraWide = true,
				maxChars = 0xFFFF,
				textType = TEXT_TYPE_ALL,
				reference = "LMAC_ExportBox",
			},
			--------------------
			{
				type = "button",
				name = SI_LMAC_SETTINGS_SHARE_EXPORTC,
				func = Internal.ExportCurrent,
				tooltip = SI_LMAC_SETTINGS_SHARE_EXPORTCT,
				width = "half",
			},
			--------------------
			{
				type = "button",
				name = SI_LMAC_SETTINGS_SHARE_IMPORT,
				func = Internal.Import,
				width = "half",
			},
			--------------------
			{
				type = "button",
				name = SI_LMAC_SETTINGS_SHARE_EXPORTA,
				func = function() Internal.ExportMultiple(true) end,
				tooltip = SI_LMAC_SETTINGS_SHARE_EXPORTAT,
				width = "half",
			},
			--------------------
			{
				type = "button",
				name = SI_LMAC_SETTINGS_SHARE_CLEAR,
				func = function() Internal.shareText = "" end,
				width = "half",
			},
			--------------------
			{
				type = "button",
				name = Internal.GetExportSelectedText,
				func = function() Internal.ExportMultiple(false) end,
				tooltip = SI_LMAC_SETTINGS_SHARE_EXPORTST,
				width = "half",
				disabled = function() return Internal.CountExportSelection() == 0 end,
				reference = "LMAC_ExportSelected",
			},
			--------------------
			{
				type = "submenu",
				name = SI_LMAC_SETTINGS_SHARE_SELECT,
				controls = {
					{
						type = "editbox",
						name = SI_LMAC_SETTINGS_SHARE_SELECTT,
						getFunc = function() return getAccountList("exportSelection") end,
						setFunc = function( text )
							setAccountList("exportSelection", text)
							if (LMAC_ExportSelected and LMAC_ExportSelected.button) then
								LMAC_ExportSelected.button:SetText(Internal.GetExportSelectedText())
							end
						end,
						isExtraWide = true,
						maxChars = 0xFF,
						textType = TEXT_TYPE_ALL,
					},
				},
			},

			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_LMAC_SETTINGS_DELETE_SECTION,
			},
			--------------------
			{
				type = "custom",
				width = "half",
			},
			--------------------
			{
				type = "button",
				name = SI_LMAC_SETTINGS_DELETE_BUTTON,
				func = function( )
					LibMultiAccountCollectiblesData = { }
					ReloadUI()
				end,
				tooltip = SI_LMAC_SETTINGS_DELETE_WARNING,
				width = "half",
				isDangerous = true,
				warning = SI_LMAC_SETTINGS_DELETE_WARNING,
			},

			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_LMAC_SETTINGS_NOSAVE_SECTION,
			},
			--------------------
			{
				type = "editbox",
				name = SI_LMAC_SETTINGS_NOSAVE_CAPTION,
				getFunc = function() return getAccountList("noSave") end,
				setFunc = function(text) setAccountList("noSave", text) end,
				isMultiline = true,
				isExtraWide = true,
				maxChars = 0xFFF,
				textType = TEXT_TYPE_ALL,
			},
		})
	end
end


--------------------------------------------------------------------------------
-- Public Access
--------------------------------------------------------------------------------

function Public.OpenSettingsPanel( )
	if (Internal.settingsPanel) then
		LibAddonMenu2:OpenToPanel(Internal.settingsPanel)
	end
end


--------------------------------------------------------------------------------
-- Export/Import
--------------------------------------------------------------------------------

local LDEI = LibDataExportImport
local SHARE_TAG = "C"
local SHARE_VERSION = 2 -- Version of the current export/import format
local SHARE_VERSION_COMPATIBILITY = {
	[SHARE_VERSION] = true,
}

function Internal.CountExportSelection( )
	return NonContiguousCount(Internal.GetVarsTable("exportSelection"))
end

function Internal.GetExportSelectedText( )
	return string.format(GetString(SI_LMAC_SETTINGS_SHARE_EXPORTS), Internal.CountExportSelection())
end

function Internal.ExportSelectText( )
	if (LMAC_ExportBox and LMAC_ExportBox.editbox) then
		zo_callLater(function( )
			LMAC_ExportBox:UpdateValue()
			LMAC_ExportBox.editbox:SelectAll()
			LMAC_ExportBox.editbox:TakeFocus()
		end, 100)
	end
end

function Internal.CreateExportEntry( server, account, data )
	return LDEI.Wrap(SHARE_TAG, SHARE_VERSION, {
		server,
		UndecorateDisplayName(account),
		LCCC.Implode(LCCC.Unchunk(data)),
	}), { server = server, identifier = account, timestamp = Internal.ReadTimeStamp(data) }
end

function Internal.ExportCurrent( )
	Internal.shareText = Internal.CreateExportEntry(Internal.server, Internal.account, Internal.currentData) .. " "
	Internal.ExportSelectText()
end

function Internal.ExportMultiple( exportAll )
	local entries = { }

	for _, server in ipairs(LCCC.GetSortedKeys(Internal.data, Internal.server)) do
		for account in pairs(Internal.data[server]) do
			if (exportAll or Internal.GetVarsTable("exportSelection")[zo_strlower(account)]) then
				table.insert(entries, { Internal.CreateExportEntry(server, account, Internal.data[server][account]) })
			end
		end
	end

	Internal.shareText = LDEI.ExportMultiple(entries, function(...) Internal.Msg(zo_strformat(SI_LMAC_SHARE_EXPORT_LIMIT, ...)) end) .. " "
	Internal.ExportSelectText()
end

function Internal.Import( )
	if (not LDEI.Import(Internal.shareText, SHARE_TAG)) then
		Internal.Msg(GetString(SI_LMAC_SHARE_IMPORT_INVALID))
	end
end

function Internal.ProcessImportData( dataset )
	local newAccount = false
	local imported = 0

	for _, data in ipairs(dataset) do
		if (not SHARE_VERSION_COMPATIBILITY[data.version]) then
			return imported, SI_LMAC_SHARE_IMPORT_BADVERSION, newAccount
		else
			local server, account, payload = zo_strsplit(",", data.payload)
			account = DecorateDisplayName(account)
			payload = LCCC.Explode(payload)
			local timestamp = Internal.ReadTimeStamp(payload)

			if (server == Internal.server and account == Internal.account) then
				Internal.Msg(zo_strformat(SI_LMAC_SHARE_IMPORT_STALE, server, account))
			else
				-- Prepare the destination data tables
				if (not Internal.data[server]) then Internal.data[server] = { } end
				local data = Internal.data[server][account]

				if (not data) then
					newAccount = true
				end

				if (data and Internal.ReadTimeStamp(data) >= timestamp) then
					Internal.Msg(zo_strformat(SI_LMAC_SHARE_IMPORT_STALE, server, account))
				else
					Internal.data[server][account] = Internal.Chunk(payload)
					imported = imported + 1
					Internal.Msg(zo_strformat(SI_LMAC_SHARE_IMPORT_DONE, server, account, os.date("%Y/%m/%d %H:%M", timestamp)))
				end
			end
		end
	end

	return imported, nil, newAccount
end

LCCC.RunAfterInitialLoadscreen(function( )
	LDEI.RegisterProcessor(SHARE_TAG, function( ... )
		local importedCount, stringId, newAccount = Internal.ProcessImportData(...)

		if (importedCount > 0) then
			Internal.FireCallbacks(Public.EVENT_COLLECTION_UPDATED, newAccount)
		end

		if (stringId) then
			Internal.Msg(GetString(stringId))
		end

		if (newAccount) then
			Internal.Msg(GetString(SI_LMAC_SHARE_IMPORT_NEWACCOUNT))
		end

		Internal.Msg(zo_strformat(SI_LMAC_SHARE_IMPORT_TALLY, importedCount))
		Internal.shareText = ""
	end)
end)
