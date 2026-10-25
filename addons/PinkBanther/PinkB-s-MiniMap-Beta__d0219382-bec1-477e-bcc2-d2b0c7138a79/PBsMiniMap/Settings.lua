-- PBS_MINIMAP is nil if Main.lua bailed out early (e.g. the add-on was already loaded).
if not PBS_MINIMAP then
	return
end

local addon = PBS_MINIMAP

function addon:InitSettings()
	local LibHarvensAddonSettings = LibHarvensAddonSettings

	-- Heading is a fixed Lua string with the manifest version appended (see Main.lua).
	local settings = LibHarvensAddonSettings:AddAddon(self.title)
	if not settings then
		return
	end
	self.settingsControls = settings
	settings.allowDefaults = true
	settings.author = self.author
	settings.version = self.version

	-- Credit to the add-on that inspired this one, kept out of the author field so that stays
	-- the actual author of this version.
	local creditSetting =
		settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBSMINIMAP_CREDIT)
		}
	)

	-- Set a size on the credit line rather than a font.
	--
	-- The panel's rows are built by the settings library and only exist once the panel has
	-- been opened, so this runs on selection rather than now. Taking the size out of whatever
	-- font is already there keeps the platform's own face and styling: on console that is a
	-- gamepad font, on PC it is not, and hardcoding either would look wrong somewhere.
	local creditResized = false
	local function ShrinkCreditLine()
		if creditResized or not creditSetting then
			return
		end
		local control = creditSetting.control
		local label = control and (control.label or (control.GetNamedChild and control:GetNamedChild("Label")))
		if not label or not label.GetFont or not label.SetFont then
			return
		end
		local font = label:GetFont()
		if not font then
			return
		end
		-- "face|size|style" - scale only the middle field, and only once.
		local scaled, replacements =
			font:gsub("|(%d+)", function(size)
				return "|" .. tostring(math.max(10, math.floor(tonumber(size) * 0.8)))
			end, 1)
		if replacements > 0 then
			label:SetFont(scaled)
			creditResized = true
		end
	end
	CALLBACK_MANAGER:RegisterCallback(
		"LibHarvensAddonSettings_AddonSelected",
		function(_, addonSettings)
			if addonSettings == settings then
				ShrinkCreditLine()
			end
		end
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_KEYBINDINGS_CATEGORY_PBSMINIMAP),
			tooltip = GetString(SI_PBSMINIMAP_MINI_MAP_TOOLTIP),
			default = self.accountDefaults.enableMap,
			getFunction = function()
				return self.account.enableMap
			end,
			setFunction = function(value)
				self.account.enableMap = value
			end
		}
	)
	-- A button row still needs a label: the row text is what the panel draws, and with an
	-- empty one the entry came out blank. The empty spacer above it was the visible gap.
	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_BUTTON,
			label = GetString(SI_PBSMINIMAP_APPLY_LABEL),
			tooltip = GetString(SI_PBSMINIMAP_APPLY_TOOLTIP),
			buttonText = GetString(SI_PBSMINIMAP_APPLY_BUTTON),
			clickHandler = function()
				SLASH_COMMANDS["/reloadui"]()
			end
		}
	)

	-- Lite minimap (init level 2): size and position for the game's own map window, applied
	-- directly without any of the InitMiniMap machinery.
	if (self.initLevel or 0) == 2 then
		local function applyLayout()
			if self.ResetLiteLayoutBackoff then
				self:ResetLiteLayoutBackoff()
			end
			self:ApplyLiteMinimapLayout()
			self:ApplyLiteAlpha()
			-- The maintenance tick skips a hidden window; refresh so the preview follows too.
			if self.litePreviewAdded then
				WORLD_MAP_FRAGMENT:Refresh()
			end
		end
		local uiWidth, uiHeight = GuiRoot:GetDimensions()
		local styleItems = {
			{name = GetString(SI_PBSMINIMAP_STYLE_SQUARE), data = {value = "square"}},
			{name = GetString(SI_PBSMINIMAP_STYLE_COMPASS), data = {value = "compass"}},
		}
		settings:AddSetting({
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBSMINIMAP_STYLE),
			tooltip = GetString(SI_PBSMINIMAP_STYLE_TOOLTIP),
			items = styleItems,
			default = styleItems[1].name,
			getFunction = function()
				return styleItems[self.account.mapStyle == "compass" and 2 or 1].name
			end,
			setFunction = function(_, _, item)
				self.account.mapStyle = item.data.value
				self:ApplyLiteBorder()
			end,
		})

		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_LABEL,
				label = GetString(SI_KEYBINDINGS_CATEGORY_PBSMINIMAP)
			}
		)

		-- Live preview: park the World Map fragment in whatever scene the settings panel is
		-- running in, so size and offset can be judged while they are being adjusted.
		local previewScene
		local function removePreview()
			if not self.litePreviewAdded then
				return
			end
			self.litePreviewAdded = false
			if previewScene then
				previewScene:RemoveFragment(WORLD_MAP_FRAGMENT)
				previewScene = nil
			end
			WORLD_MAP_FRAGMENT:Refresh()
			-- Leaving the preview hands the window back to the HUD, and the game re-anchors it
			-- on the way. Re-assert straight away instead of waiting for the maintenance tick.
			if self.ResetLiteLayoutBackoff then
				self:ResetLiteLayoutBackoff()
			end
			self:ApplyLiteMinimapLayout()
		end
		local function addPreview()
			if self.litePreviewAdded then
				return
			end
			previewScene = SCENE_MANAGER:GetCurrentScene()
			if not previewScene then
				return
			end
			self.litePreviewAdded = true
			previewScene:AddFragment(WORLD_MAP_FRAGMENT)
			WORLD_MAP_FRAGMENT:Refresh()
			applyLayout()
		end
		-- Drop the preview again as soon as another add-on's panel is selected.
		CALLBACK_MANAGER:RegisterCallback(
			"LibHarvensAddonSettings_AddonSelected",
			function(_, addonSettings)
				if addonSettings ~= settings then
					removePreview()
				end
			end
		)

		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_CHECKBOX,
				label = GetString(SI_PBSMINIMAP_SHOW_IN_SETTINGS),
				tooltip = GetString(SI_PBSMINIMAP_LITE_PREVIEW_TOOLTIP),
				default = false,
				getFunction = function()
					return self.litePreviewAdded == true
				end,
				setFunction = function(value)
					if value then
						addPreview()
					else
						removePreview()
					end
				end
			}
		)
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_SLIDER,
				label = GetString(SI_PBSMINIMAP_LITE_WIDTH),
				tooltip = GetString(SI_PBSMINIMAP_LITE_WIDTH_TOOLTIP),
				min = 20,
				max = math.floor(uiWidth),
				step = 2,
				default = 304,
				format = "%d",
				unit = "",
				getFunction = function()
					return self.account.width or 304
				end,
				setFunction = function(value)
					self.account.width = value
					applyLayout()
				end
			}
		)
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_SLIDER,
				label = GetString(SI_PBSMINIMAP_LITE_HEIGHT),
				tooltip = GetString(SI_PBSMINIMAP_LITE_HEIGHT_TOOLTIP),
				min = 20,
				max = math.floor(uiHeight),
				step = 2,
				default = 368,
				format = "%d",
				unit = "",
				getFunction = function()
					return self.account.height or 368
				end,
				setFunction = function(value)
					self.account.height = value
					applyLayout()
				end
			}
		)
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_SLIDER,
				label = GetString(SI_PBSMINIMAP_LITE_OFFSET_X),
				tooltip = GetString(SI_PBSMINIMAP_LITE_OFFSET_X_TOOLTIP),
				min = -math.floor(uiWidth / 2),
				max = math.floor(uiWidth / 2),
				step = 4,
				default = math.floor(uiWidth / 2 - 304),
				format = "%d",
				unit = "",
				getFunction = function()
					return self.account.x or (uiWidth / 2 - 304)
				end,
				setFunction = function(value)
					self.account.x = value
					applyLayout()
				end
			}
		)
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_SLIDER,
				label = GetString(SI_PBSMINIMAP_LITE_OFFSET_Y),
				tooltip = GetString(SI_PBSMINIMAP_LITE_OFFSET_Y_TOOLTIP),
				min = -math.floor(uiHeight / 2),
				max = math.floor(uiHeight / 2),
				step = 4,
				default = math.floor(uiHeight / 2 - 368),
				format = "%d",
				unit = "",
				getFunction = function()
					return self.account.y or (uiHeight / 2 - 368)
				end,
				setFunction = function(value)
					self.account.y = value
					applyLayout()
				end
			}
		)
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_SLIDER,
				label = GetString(SI_PBSMINIMAP_LITE_OPACITY),
				tooltip = GetString(SI_PBSMINIMAP_LITE_OPACITY_TOOLTIP),
				min = 10,
				max = 100,
				step = 5,
				default = self.accountDefaults.liteAlpha,
				format = "%d",
				unit = "%",
				getFunction = function()
					return self.account.liteAlpha or 100
				end,
				setFunction = function(value)
					self.account.liteAlpha = value
					self:ApplyLiteAlpha()
				end
			}
		)
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_CHECKBOX,
				label = GetString(SI_PBSMINIMAP_LITE_BORDER),
				tooltip = GetString(SI_PBSMINIMAP_LITE_BORDER_TOOLTIP),
				default = self.accountDefaults.showBorder,
				getFunction = function()
					return self.account.showBorder
				end,
				setFunction = function(value)
					self.account.showBorder = value
					self:ApplyLiteBorder()
				end
			}
		)
		do
			local drawOrderItems = {
				{name = GetString(SI_PBSMINIMAP_LITE_DRAW_ORDER_FRONT), data = {value = "front"}},
				{name = GetString(SI_PBSMINIMAP_LITE_DRAW_ORDER_DEFAULT), data = {value = "default"}},
				{name = GetString(SI_PBSMINIMAP_LITE_DRAW_ORDER_BACK), data = {value = "back"}}
			}
			-- The dropdown works in display names, the saved setting in keys, so the two have
			-- to be translated across. Anything unrecognised reads as the default entry.
			local function drawOrderName(value)
				for index = 1, #drawOrderItems do
					if drawOrderItems[index].data.value == value then
						return drawOrderItems[index].name
					end
				end
				return drawOrderItems[2].name
			end
			settings:AddSetting(
				{
					type = LibHarvensAddonSettings.ST_DROPDOWN,
					label = GetString(SI_PBSMINIMAP_LITE_DRAW_ORDER),
					tooltip = GetString(SI_PBSMINIMAP_LITE_DRAW_ORDER_TOOLTIP),
					items = drawOrderItems,
					default = drawOrderName(self.accountDefaults.liteDrawOrder),
					getFunction = function()
						return drawOrderName(self.account.liteDrawOrder)
					end,
					setFunction = function(combobox, name, item)
						self.account.liteDrawOrder = item.data.value
						self:ApplyLiteDrawOrder()
					end
				}
			)
		end
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_CHECKBOX,
				label = GetString(SI_PBSMINIMAP_LITE_ZONE_TITLE),
				tooltip = GetString(SI_PBSMINIMAP_LITE_ZONE_TITLE_TOOLTIP),
				default = self.accountDefaults.showZoneTitle,
				getFunction = function()
					return self.account.showZoneTitle
				end,
				setFunction = function(value)
					self.account.showZoneTitle = value
					self:UpdateZoneTitle()
				end
			}
		)
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_SLIDER,
				label = GetString(SI_PBSMINIMAP_LITE_ZONE_TITLE_SIZE),
				tooltip = GetString(SI_PBSMINIMAP_LITE_ZONE_TITLE_SIZE_TOOLTIP),
				min = 12,
				max = 48,
				step = 1,
				default = self.accountDefaults.zoneTitleSize,
				format = "%d",
				unit = "",
				getFunction = function()
					return self.account.zoneTitleSize or 24
				end,
				setFunction = function(value)
					self.account.zoneTitleSize = value
					self:UpdateZoneTitle()
				end
			}
		)
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_CHECKBOX,
				label = GetString(SI_PBSMINIMAP_LITE_FOLLOW),
				tooltip = GetString(SI_PBSMINIMAP_LITE_FOLLOW_TOOLTIP),
				default = self.accountDefaults.followPlayer,
				getFunction = function()
					return self.account.followPlayer
				end,
				setFunction = function(value)
					self.account.followPlayer = value
					if self.ResetFollowState then
						self:ResetFollowState()
					end
				end
			}
		)
		-- One zoom per context: indoors the game swaps to a much smaller map, where an
		-- outdoor zoom level is far too close to see anything around the player.
		local function addZoomSetting(label, key, tooltip)
			settings:AddSetting(
				{
					type = LibHarvensAddonSettings.ST_SLIDER,
					label = label,
					tooltip = tooltip,
					-- Scale relative to the map's native resolution, not a 0..1 position -- see
					-- AdjustLiteZoom in Main.lua. Higher means more magnified.
					min = 0.05,
					max = 2,
					step = 0.05,
					default = self.accountDefaults[key],
					format = "%.2f",
					unit = "",
					getFunction = function()
						return self.account[key] or self.accountDefaults[key]
					end,
					setFunction = function(value)
						self.account[key] = value
						if self.ResetFollowState then
							self:ResetFollowState()
						end
					end
				}
			)
		end

		addZoomSetting(
			GetString(SI_PBSMINIMAP_LITE_ZOOM_OUTDOOR),
			"liteScale",
			GetString(SI_PBSMINIMAP_LITE_ZOOM_OUTDOOR_TOOLTIP)
		)
		addZoomSetting(
			GetString(SI_PBSMINIMAP_LITE_ZOOM_SUBZONE),
			"liteScaleSubZone",
			GetString(SI_PBSMINIMAP_LITE_ZOOM_SUBZONE_TOOLTIP)
		)
		addZoomSetting(
			GetString(SI_PBSMINIMAP_LITE_ZOOM_DUNGEON),
			"liteScaleDungeon",
			GetString(SI_PBSMINIMAP_LITE_ZOOM_DUNGEON_TOOLTIP)
		)
		addZoomSetting(
			GetString(SI_PBSMINIMAP_LITE_ZOOM_BG),
			"liteScaleBattleground",
			GetString(SI_PBSMINIMAP_LITE_ZOOM_BG_TOOLTIP)
		)
		addZoomSetting(
			GetString(SI_PBSMINIMAP_LITE_ZOOM_AVA),
			"liteScaleAva",
			GetString(SI_PBSMINIMAP_LITE_ZOOM_AVA_TOOLTIP)
		)
		settings:AddSetting(
			{
				type = LibHarvensAddonSettings.ST_BUTTON,
				label = GetString(SI_PBSMINIMAP_LITE_REAPPLY),
				tooltip = GetString(SI_PBSMINIMAP_LITE_REAPPLY_TOOLTIP),
				buttonText = GetString(SI_PBSMINIMAP_LITE_REAPPLY),
				clickHandler = applyLayout
			}
		)
	end

	settings:AddSetting({
		type = LibHarvensAddonSettings.ST_BUTTON,
		label = GetString(SI_PBSMINIMAP_PIN_DIAGNOSTIC),
		buttonText = GetString(SI_PBSMINIMAP_PIN_DIAGNOSTIC),
		tooltip = GetString(SI_PBSMINIMAP_PIN_DIAGNOSTIC_TOOLTIP),
		clickHandler = function() self:PrintLitePlayerPinDiagnostic() end,
	})

	-- Continuous verbose logging remains locked; the button above reports only the last HUD sample.
	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSMINIMAP_DEBUG_LOG),
			tooltip = GetString(SI_PBSMINIMAP_DEBUG_LOG_TOOLTIP),
			default = self.accountDefaults.debug,
			getFunction = function()
				return self.account.debug
			end,
			setFunction = function(value)
				self.account.debug = value
				-- Print the pan/zoom API right away, so it can be read without a reload.
				if value and self.DumpPanZoomApi then
					self:DumpPanZoomApi()
				end
			end,
			disable = true
		}
	)
end
