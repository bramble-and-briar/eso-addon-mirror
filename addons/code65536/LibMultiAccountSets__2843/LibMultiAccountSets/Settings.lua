local LCCC = LibCodesCommonCode
local Internal = LibMultiAccountSetsInternal
local Public = LibMultiAccountSets


--------------------------------------------------------------------------------
-- Settings Panel
--------------------------------------------------------------------------------

function Internal.RegisterSettingsPanel( )
	local LAM = LCCC.GetLibAddonMenu()

	if (LAM) then
		local panelId = "LMASSettings"

		Internal.settingsPanel = LAM:RegisterAddonPanel(panelId, {
			type = "panel",
			name = Internal.name,
			version = LCCC.FormatVersion(LCCC.GetAddOnVersion(Internal.name)),
			author = "@code65536",
			website = "https://www.esoui.com/downloads/info2843.html",
			donation = "https://www.esoui.com/downloads/info2843.html#donate",
			slashCommand = "/lmas",
			registerForRefresh = true,
		})

		Internal.shareText = ""

		local getAccountList = function( key )
			local accounts = { }
			for account in pairs(Internal.vars[key]) do
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
				text = SI_LMAS_SETTINGS_CHATCOMMAND,
			},

			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_LMAS_SETTINGS_CHAT_SECTION,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_LMAS_SETTINGS_CHAT_UPDATES,
				getFunc = function() return Internal.vars.chatUpdates end,
				setFunc = function(enabled) Internal.vars.chatUpdates = enabled end,
			},

			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_LMAS_SETTINGS_SHARE_SECTION,
			},
			--------------------
			{
				type = "editbox",
				name = SI_LMAS_SETTINGS_SHARE_CAPTION,
				getFunc = function() return Internal.shareText end,
				setFunc = function(text) Internal.shareText = text end,
				isMultiline = true,
				isExtraWide = true,
				maxChars = 0xFFFF,
				textType = TEXT_TYPE_ALL,
				reference = "LMAS_ExportBox",
			},
			--------------------
			{
				type = "button",
				name = SI_LMAS_SETTINGS_SHARE_EXPORTC,
				func = Internal.ExportCurrent,
				tooltip = SI_LMAS_SETTINGS_SHARE_EXPORTCT,
				width = "half",
			},
			--------------------
			{
				type = "button",
				name = SI_LMAS_SETTINGS_SHARE_IMPORT,
				func = Internal.Import,
				width = "half",
			},
			--------------------
			{
				type = "button",
				name = SI_LMAS_SETTINGS_SHARE_EXPORTA,
				func = function() Internal.ExportMultiple(true) end,
				tooltip = SI_LMAS_SETTINGS_SHARE_EXPORTAT,
				width = "half",
			},
			--------------------
			{
				type = "button",
				name = SI_LMAS_SETTINGS_SHARE_CLEAR,
				func = function() Internal.shareText = "" end,
				width = "half",
			},
			--------------------
			{
				type = "button",
				name = Internal.GetExportSelectedText,
				func = function() Internal.ExportMultiple(false) end,
				tooltip = SI_LMAS_SETTINGS_SHARE_EXPORTST,
				width = "half",
				disabled = function() return Internal.CountExportSelection() == 0 end,
				reference = "LMAS_ExportSelected",
			},
			--------------------
			{
				type = "submenu",
				name = SI_LMAS_SETTINGS_SHARE_SELECT,
				controls = {
					{
						type = "editbox",
						name = SI_LMAS_SETTINGS_SHARE_SELECTT,
						getFunc = function() return getAccountList("exportSelection") end,
						setFunc = function( text )
							setAccountList("exportSelection", text)
							if (LMAS_ExportSelected and LMAS_ExportSelected.button) then
								LMAS_ExportSelected.button:SetText(Internal.GetExportSelectedText())
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
				name = SI_LMAS_SETTINGS_DELETE_SECTION,
			},
			--------------------
			{
				type = "custom",
				width = "half",
			},
			--------------------
			{
				type = "button",
				name = SI_LMAS_SETTINGS_DELETE_BUTTON,
				func = function( )
					LibMultiAccountSetsData = { }
					ReloadUI()
				end,
				tooltip = SI_LMAS_SETTINGS_DELETE_WARNING,
				width = "half",
				isDangerous = true,
				warning = SI_LMAS_SETTINGS_DELETE_WARNING,
			},

			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_LMAS_SETTINGS_NOSAVE_SECTION,
			},
			--------------------
			{
				type = "editbox",
				name = SI_LMAS_SETTINGS_NOSAVE_CAPTION,
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
local SHARE_TAG = "S"
local SHARE_VERSION = 6 -- Version of the current export/import format
local SHARE_VERSION_COMPATIBILITY = {
	[SHARE_VERSION] = true,
}

function Internal.CountExportSelection( )
	return NonContiguousCount(Internal.vars.exportSelection)
end

function Internal.GetExportSelectedText( )
	return string.format(GetString(SI_LMAS_SETTINGS_SHARE_EXPORTS), Internal.CountExportSelection())
end

function Internal.ExportSelectText( )
	if (LMAS_ExportBox and LMAS_ExportBox.editbox) then
		zo_callLater(function( )
			LMAS_ExportBox:UpdateValue()
			LMAS_ExportBox.editbox:SelectAll()
			LMAS_ExportBox.editbox:TakeFocus()
		end, 100)
	end
end

function Internal.CreateExportEntry( server, account, data )
	local payload = LCCC.Chunk(LCCC.Implode(LCCC.Unchunk(data)), 0xE00)
	return LDEI.Wrap(SHARE_TAG, SHARE_VERSION, {
		server,
		UndecorateDisplayName(account),
		(type(payload) == "string") and payload or table.concat(payload, " "),
	}), { server = server, identifier = account, timestamp = Internal.DecodeAtIndex(data, 1) }
end

function Internal.ExportCurrent( )
	Internal.shareText = Internal.CreateExportEntry(Internal.server, Internal.account, Internal.AccessCurrentData()) .. " "
	Internal.ExportSelectText()
end

function Internal.ExportMultiple( exportAll )
	local entries = { }

	for _, server in ipairs(LCCC.GetSortedKeys(Internal.data, Internal.server)) do
		for account in pairs(Internal.data[server]) do
			if (exportAll or Internal.vars.exportSelection[zo_strlower(account)]) then
				table.insert(entries, { Internal.CreateExportEntry(server, account, Internal.data[server][account]) })
			end
		end
	end

	Internal.shareText = LDEI.ExportMultiple(entries, function(...) Internal.Msg(zo_strformat(SI_LMAS_SHARE_EXPORT_LIMIT, ...)) end) .. " "
	Internal.ExportSelectText()
end

function Internal.Import( )
	if (not LDEI.Import(Internal.shareText, SHARE_TAG)) then
		Internal.Msg(GetString(SI_LMAS_SHARE_IMPORT_INVALID))
	end
end

function Internal.ProcessImportData( dataset )
	local newAccount = false
	local imported = 0

	for _, data in ipairs(dataset) do
		if (not SHARE_VERSION_COMPATIBILITY[data.version]) then
			return imported, SI_LMAS_SHARE_IMPORT_BADVERSION, newAccount
		else
			local server, account, payload = zo_strsplit(",", data.payload)
			account = DecorateDisplayName(account)
			payload = LCCC.Explode(zo_strgsub(payload, " ", ""))
			local timestamp = Internal.DecodeAtIndex(payload, 1)

			if (server == Internal.server and account == Internal.account) then
				Internal.Msg(zo_strformat(SI_LMAS_SHARE_IMPORT_STALE, server, account))
			else
				-- Prepare the destination data tables
				if (not Internal.data[server]) then Internal.data[server] = { } end
				if (not Internal.data[server][account]) then
					newAccount = true
				end
				if (Public.GetLastScanTimeEx(server, account) >= timestamp) then
					Internal.Msg(zo_strformat(SI_LMAS_SHARE_IMPORT_STALE, server, account))
				else
					Internal.data[server][account] = Internal.Chunk(payload)
					imported = imported + 1
					Internal.Msg(zo_strformat(SI_LMAS_SHARE_IMPORT_DONE, server, account, os.date("%Y/%m/%d %H:%M", timestamp)))
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
			Internal.Msg(GetString(SI_LMAS_SHARE_IMPORT_NEWACCOUNT))
		end

		Internal.Msg(zo_strformat(SI_LMAS_SHARE_IMPORT_TALLY, importedCount))
		Internal.shareText = ""
	end)
end)
