CALLBACK_MANAGER:RegisterCallback(ALT_GROUP_FRAMES.EVENT.MANAGER_CREATED, function(UnitFramesManager)
	local LAM2 = LibAddonMenu2
	local movable = false

	LAM2:RegisterAddonPanel("ALTGF_Settings", {
		type = "panel",
		name = "Alternative Group Frames",
		displayName = "Alternative Group Frames",
		author = "|c943810BulDeZir|r, Glande-Pas",
		version = string.format("|c00FF00%s|r", ALT_GROUP_FRAMES.VERSION),
		slashCommand = "/altgf",
		registerForRefresh = true,
		registerForDefaults = true,
	})

	local optionsData = {
		-- ── Display ──────────────────────────────────────────────────────────
		{
			type = "header",
			name = "Displayed Information",
		},
		{
			type = "dropdown",
			name = "Info shown with bar colors",
			tooltip = "Colorizes the health bar gradient. 'Roles' uses Tank/Healer/DPS colors; 'Classes' uses per-class colors; 'Nothing' uses a uniform bar.",
			choices = { "Nothing", "Roles", "Classes" },
			choicesValues = { 0, 1, 2 },
			default = function()
				return UnitFramesManager.DEFAULTS["COLORS_SHOW"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.COLORS_SHOW
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.COLORS_SHOW = newValue
				UnitFramesManager:RefreshData()
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "dropdown",
			name = "Info shown with icons",
			tooltip = "Shows a small icon on each frame. 'Roles' shows LFG role icons; 'Classes' shows class icons; 'Nothing' hides the icon slot.",
			choices = { "Nothing", "Roles", "Classes" },
			choicesValues = { 0, 1, 2 },
			default = function()
				return UnitFramesManager.DEFAULTS["ICONS_SHOW"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.ICONS_SHOW
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.ICONS_SHOW = newValue
				UnitFramesManager:RefreshData()
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "checkbox",
			name = "Use Character Names",
			tooltip = "Display the character name instead of the account name (@handle) on each frame.",
			default = function()
				return UnitFramesManager.DEFAULTS["USE_CHARACTER_NAMES"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.USE_CHARACTER_NAMES
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.USE_CHARACTER_NAMES = newValue
				UnitFramesManager:RefreshData()
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "checkbox",
			name = "Show Role Icon for DPS",
			tooltip = "DPS has no official role icon in ESO. Enable this to show a placeholder icon for DPS members when icons are set to show Roles.",
			default = function()
				return UnitFramesManager.DEFAULTS["SHOW_DPS_ICON"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.SHOW_DPS_ICON
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.SHOW_DPS_ICON = newValue
				UnitFramesManager:RefreshData()
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "checkbox",
			name = "Show Level",
			tooltip = "Display the player's level or Champion Point total on each frame.",
			default = function()
				return UnitFramesManager.DEFAULTS["SHOW_LEVEL"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.SHOW_LEVEL
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.SHOW_LEVEL = newValue
				UnitFramesManager:RefreshData()
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "checkbox",
			name = "Display Group Difficulty icon on Group Lead",
			tooltip = "Shows a small icon on the group leader's frame indicating the current group difficulty (Normal, Veteran, Hard Mode).",
			default = function()
				return UnitFramesManager.DEFAULTS["SHOW_DIFFICULTY_ON_LEAD"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.SHOW_DIFFICULTY_ON_LEAD
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.SHOW_DIFFICULTY_ON_LEAD = newValue
				UnitFramesManager:RefreshData()
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "checkbox",
			name = "Hide class/role icon when showing target marker",
			tooltip = "When a target marker (skull, star, etc.) is placed on a group member, their class or role icon is replaced by the marker icon.",
			default = function()
				return UnitFramesManager.DEFAULTS["HIDE_ICON_MARKER"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.HIDE_ICON_MARKER
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.HIDE_ICON_MARKER = newValue
				UnitFramesManager:RefreshData()
				UnitFramesManager:RefreshView(true)
			end,
		},
		-- ── Frame Ordering ───────────────────────────────────────────────────
		{
			type = "header",
			name = "Frame Ordering",
		},
		{
			type = "checkbox",
			name = "Enable drag to reorder",
			tooltip = "Left-click and drag a frame to set a custom order. When enabled, role-based ordering is replaced by your saved custom order.",
			default = function()
				return UnitFramesManager.DEFAULTS["USE_CUSTOM_ORDER"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.USE_CUSTOM_ORDER
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.USE_CUSTOM_ORDER = newValue
				UnitFramesManager:RefreshData()
			end,
		},
		{
			type = "slider",
			name = "Max saved entries",
			tooltip = "Maximum number of players kept in the custom order list. When a drag pushes the list over this limit, the least recently seen entry is removed.",
			min = 12,
			max = 100,
			step = 1,
			default = function()
				return UnitFramesManager.DEFAULTS["CUSTOM_ORDER_MAX_SIZE"]
			end,
			getFunc = function()
				return zo_round(UnitFramesManager.SAVEVARS.CUSTOM_ORDER_MAX_SIZE)
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.CUSTOM_ORDER_MAX_SIZE = zo_round(newValue)
			end,
		},
		{
			type = "dropdown",
			name = "Auto-clear entries after",
			tooltip = "Saved order entries that haven't been seen for this long are removed on login. Set to 'Never' to keep entries indefinitely.",
			choices = { "1 hour", "1 day", "10 days", "1 month", "Never" },
			choicesValues = { 3600, 86400, 864000, 2592000, 0 },
			default = function()
				return UnitFramesManager.DEFAULTS["CUSTOM_ORDER_TTL"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CUSTOM_ORDER_TTL
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.CUSTOM_ORDER_TTL = newValue
			end,
		},
		{
			type = "description",
			text = function()
				return string.format("Saved entries: |cFFFFFF%d|r", #UnitFramesManager.SAVEVARS.CUSTOM_ORDER)
			end,
		},
		{
			type = "button",
			name = "Clear order list",
			tooltip = "Remove all saved entries from the custom order list. Frames will fall back to role-based ordering until reordered again.",
			func = function()
				UnitFramesManager.SAVEVARS.CUSTOM_ORDER = {}
				UnitFramesManager:RefreshData()
			end,
			width = "half",
		},
		{
			type = "button",
			name = "Reset to role order",
			tooltip = "Clear the saved custom order and disable drag-to-reorder, reverting to role-based ordering (Tank → Healer → DPS).",
			func = function()
				UnitFramesManager.SAVEVARS.CUSTOM_ORDER = {}
				UnitFramesManager.SAVEVARS.USE_CUSTOM_ORDER = false
				UnitFramesManager:RefreshData()
			end,
			width = "half",
		},
		-- ── Layout ────────────────────────────────────────────────────────────
		{
			type = "header",
			name = "Layout",
		},
		{
			type = "checkbox",
			name = "Display all frame info on a single row",
			tooltip = "Switches between a compact single-row layout and a taller two-row layout. Toggling this swaps the saved frame size settings between the two layouts.",
			default = function()
				return UnitFramesManager.DEFAULTS["SINGLE_ROW_FRAME"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.SINGLE_ROW_FRAME
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.SINGLE_ROW_FRAME = newValue
				-- Position is no longer part of this swap: it's owned by the Edit HUD now,
				-- not per-layout saved offsets.
				local altSize = UnitFramesManager.SAVEVARS.UNIT_FRAME_ALT_SIZE
				local c, w, h, dx, dy, _
				if #altSize == 7 then
					-- Saved before the Edit HUD migration dropped the position fields: {col, x, y, w, h, dx, dy}
					c, _, _, w, h, dx, dy = unpack(altSize)
				else
					c, w, h, dx, dy = unpack(altSize)
				end
				UnitFramesManager.SAVEVARS.UNIT_FRAME_ALT_SIZE = {
					UnitFramesManager.SAVEVARS.FRAMES_PER_COLUMN,
					UnitFramesManager.SAVEVARS.UNIT_FRAME_WIDTH,
					UnitFramesManager.SAVEVARS.UNIT_FRAME_HEIGHT,
					UnitFramesManager.SAVEVARS.UNIT_FRAME_PAD_X,
					UnitFramesManager.SAVEVARS.UNIT_FRAME_PAD_Y,
				}
				UnitFramesManager.SAVEVARS.FRAMES_PER_COLUMN = c
				UnitFramesManager.SAVEVARS.UNIT_FRAME_WIDTH = w
				UnitFramesManager.SAVEVARS.UNIT_FRAME_HEIGHT = h
				UnitFramesManager.SAVEVARS.UNIT_FRAME_PAD_X = dx
				UnitFramesManager.SAVEVARS.UNIT_FRAME_PAD_Y = dy
				UnitFramesManager:RefreshData()
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "checkbox",
			name = "Unlock Frame Resizing",
			tooltip = "Shows a resize handle on the frame container so you can resize it. To move the frame to a new position, open the Esc menu and choose Edit HUD.",
			default = function()
				return false
			end,
			getFunc = function()
				return movable
			end,
			setFunc = function(newValue)
				movable = newValue
				UnitFramesManager:UnlockUI(newValue)
				UnitFramesManager:RefreshData()
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "button",
			name = "Reset Frame Position",
			tooltip = "Move the frame back to its default screen position. Useful if the frame has been dragged off-screen in the Edit HUD.",
			func = function()
				UnitFramesManager:ResetPosition()
			end,
		},
		{
			type = "slider",
			name = "Units per column",
			tooltip = "Maximum number of frames shown in a single column before wrapping to a new column.",
			min = 2,
			max = 12,
			step = 1,
			default = function()
				return UnitFramesManager.DEFAULTS["FRAMES_PER_COLUMN"]
			end,
			getFunc = function()
				return zo_round(UnitFramesManager.SAVEVARS.FRAMES_PER_COLUMN)
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.FRAMES_PER_COLUMN = zo_round(newValue)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "slider",
			name = "Frame Margin X",
			tooltip = "Horizontal spacing between frames.",
			min = 1,
			max = 60,
			step = 1,
			default = function()
				return UnitFramesManager.DEFAULTS["UNIT_FRAME_PAD_X"]
			end,
			getFunc = function()
				return zo_round(UnitFramesManager.SAVEVARS.UNIT_FRAME_PAD_X)
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.UNIT_FRAME_PAD_X = zo_round(newValue)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "slider",
			name = "Frame Margin Y",
			tooltip = "Vertical spacing between frames.",
			min = 0,
			max = 8,
			step = 1,
			default = function()
				return UnitFramesManager.DEFAULTS["UNIT_FRAME_PAD_Y"]
			end,
			getFunc = function()
				return zo_round(UnitFramesManager.SAVEVARS.UNIT_FRAME_PAD_Y)
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.UNIT_FRAME_PAD_Y = zo_round(newValue)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "slider",
			name = "Icon size",
			tooltip = "Size in pixels of the class, role, or custom icon displayed on each frame.",
			min = 5,
			max = 40,
			step = 1,
			default = function()
				return UnitFramesManager.DEFAULTS["UNIT_FRAME_ICONSIZE"]
			end,
			getFunc = function()
				return zo_round(UnitFramesManager.SAVEVARS.UNIT_FRAME_ICONSIZE)
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.UNIT_FRAME_ICONSIZE = zo_round(newValue)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "slider",
			name = "Font size",
			tooltip = "Size of the name text displayed on each frame.",
			min = 4,
			max = 36,
			step = 1,
			default = function()
				return UnitFramesManager.DEFAULTS["UNIT_FRAME_FONTSIZE"]
			end,
			getFunc = function()
				return zo_round(UnitFramesManager.SAVEVARS.UNIT_FRAME_FONTSIZE)
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.UNIT_FRAME_FONTSIZE = zo_round(newValue)
				UnitFramesManager:RefreshView(true)
			end,
		},
		-- ── Third-party Integrations ──────────────────────────────────────────
		{
			type = "header",
			name = "Third-party Integrations",
		},
		{
			type = "checkbox",
			name = "Show icons from Player Role Indicator",
			tooltip = "When Player Role Indicator is installed, shows its custom role icons on frames instead of the standard class or LFG role icons.",
			default = function()
				return UnitFramesManager.DEFAULTS["SHOW_CUSTOM_ROLE_ICONS"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.SHOW_CUSTOM_ROLE_ICONS
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.SHOW_CUSTOM_ROLE_ICONS = newValue
				UnitFramesManager:RefreshData()
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "checkbox",
			name = "Show Player Role Indicator roles in frames menu",
			tooltip = "When right-clicking a frame, shows options to assign or remove Player Role Indicator roles. Requires 'Show icons from Player Role Indicator' to be enabled.",
			default = function()
				return UnitFramesManager.DEFAULTS["SHOW_CUSTOM_ROLE_MENU"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.SHOW_CUSTOM_ROLE_MENU
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.SHOW_CUSTOM_ROLE_MENU = newValue
			end,
			disabled = function()
				return not UnitFramesManager.SAVEVARS.SHOW_CUSTOM_ROLE_ICONS
			end,
		},
		{
			type = "checkbox",
			name = "Show icons from Ody Support Icons",
			tooltip = "When OdySupportIcons is installed, shows its support role icons on frames. Requires the OdySupportIcons addon to be active.",
			default = function()
				return UnitFramesManager.DEFAULTS["SHOW_CUSTOM_ODY_ICONS"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.SHOW_CUSTOM_ODY_ICONS
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.SHOW_CUSTOM_ODY_ICONS = newValue
				UnitFramesManager:RefreshData()
				UnitFramesManager:RefreshView(true)
			end,
			disabled = function()
				return OSI == nil
			end,
		},
		-- ── Colors ────────────────────────────────────────────────────────────
		{
			type = "header",
			name = "Colors",
		},
		{
			type = "colorpicker",
			name = "Shield color",
			tooltip = "Color of the shield/damage shield overlay on the health bar.",
			default = function()
				return UnitFramesManager.DEFAULTS["SHIELD_COLOR"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.SHIELD_COLOR:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.SHIELD_COLOR = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Trauma color",
			tooltip = "Color of the trauma (healing reduction) overlay on the health bar.",
			default = function()
				return UnitFramesManager.DEFAULTS["TRAUMA_COLOR"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.TRAUMA_COLOR:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.TRAUMA_COLOR = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		-- ── Role Colors ───────────────────────────────────────────────────────
		{
			type = "header",
			name = "Role Colors",
		},
		{
			type = "colorpicker",
			name = "Tank Color Gradient Start",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["LFG_COLORS"][LFG_ROLE_TANK][1]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.LFG_COLORS[LFG_ROLE_TANK][1]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.LFG_COLORS[LFG_ROLE_TANK][1] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Tank Color Gradient End",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["LFG_COLORS"][LFG_ROLE_TANK][2]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.LFG_COLORS[LFG_ROLE_TANK][2]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.LFG_COLORS[LFG_ROLE_TANK][2] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Healer Color Gradient Start",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["LFG_COLORS"][LFG_ROLE_HEAL][1]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.LFG_COLORS[LFG_ROLE_HEAL][1]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.LFG_COLORS[LFG_ROLE_HEAL][1] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Healer Color Gradient End",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["LFG_COLORS"][LFG_ROLE_HEAL][2]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.LFG_COLORS[LFG_ROLE_HEAL][2]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.LFG_COLORS[LFG_ROLE_HEAL][2] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "DPS Color Gradient Start",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["LFG_COLORS"][LFG_ROLE_DPS][1]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.LFG_COLORS[LFG_ROLE_DPS][1]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.LFG_COLORS[LFG_ROLE_DPS][1] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "DPS Color Gradient End",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["LFG_COLORS"][LFG_ROLE_DPS][2]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.LFG_COLORS[LFG_ROLE_DPS][2]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.LFG_COLORS[LFG_ROLE_DPS][2] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		-- ── Class Colors ──────────────────────────────────────────────────────
		{
			type = "header",
			name = "Class Colors",
		},
		{
			type = "colorpicker",
			name = "DragonKnight Color Gradient Start",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["CLASS_COLORS"][1][1]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CLASS_COLORS[1][1]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.CLASS_COLORS[1][1] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "DragonKnight Color Gradient End",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["CLASS_COLORS"][1][2]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CLASS_COLORS[1][2]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.CLASS_COLORS[1][2] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Sorcerer Color Gradient Start",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["CLASS_COLORS"][2][1]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CLASS_COLORS[2][1]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.CLASS_COLORS[2][1] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Sorcerer Color Gradient End",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["CLASS_COLORS"][2][2]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CLASS_COLORS[2][2]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.CLASS_COLORS[2][2] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Nightblade Color Gradient Start",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["CLASS_COLORS"][3][1]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CLASS_COLORS[3][1]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.CLASS_COLORS[3][1] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Nightblade Color Gradient End",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["CLASS_COLORS"][3][2]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CLASS_COLORS[3][2]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.CLASS_COLORS[3][2] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Templar Color Gradient Start",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["CLASS_COLORS"][4][1]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CLASS_COLORS[4][1]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.CLASS_COLORS[4][1] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Templar Color Gradient End",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["CLASS_COLORS"][4][2]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CLASS_COLORS[4][2]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.CLASS_COLORS[4][2] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Warden Color Gradient Start",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["CLASS_COLORS"][5][1]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CLASS_COLORS[5][1]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.CLASS_COLORS[5][1] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Warden Color Gradient End",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["CLASS_COLORS"][5][2]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CLASS_COLORS[5][2]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.CLASS_COLORS[5][2] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Necromancer Color Gradient Start",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["CLASS_COLORS"][6][1]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CLASS_COLORS[6][1]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.CLASS_COLORS[6][1] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Necromancer Color Gradient End",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["CLASS_COLORS"][6][2]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CLASS_COLORS[6][2]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.CLASS_COLORS[6][2] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Arcanist Color Gradient Start",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["CLASS_COLORS"][7][1]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CLASS_COLORS[7][1]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.CLASS_COLORS[7][1] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Arcanist Color Gradient End",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["CLASS_COLORS"][7][2]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.CLASS_COLORS[7][2]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.CLASS_COLORS[7][2] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		-- ── Companion Colors ──────────────────────────────────────────────────
		{
			type = "header",
			name = "Companion Colors",
		},
		{
			type = "colorpicker",
			name = "Companion Color Gradient Start",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["COMPANION_COLORS"][1]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.COMPANION_COLORS[1]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.COMPANION_COLORS[1] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		{
			type = "colorpicker",
			name = "Companion Color Gradient End",
			width = "half",
			default = function()
				return UnitFramesManager.DEFAULTS["COMPANION_COLORS"][2]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.COMPANION_COLORS[2]:UnpackRGBA()
			end,
			setFunc = function(...)
				UnitFramesManager.SAVEVARS.COMPANION_COLORS[2] = ZO_ColorDef:New(...)
				UnitFramesManager:RefreshView(true)
			end,
		},
		-- ── Debug ─────────────────────────────────────────────────────────────
		{
			type = "header",
			name = "Debug",
		},
		{
			type = "checkbox",
			name = "Show Myself if no group",
			tooltip = "Shows your own frame when not in a group. Useful for previewing layout and color changes without needing to be grouped.",
			default = function()
				return UnitFramesManager.DEFAULTS["SHOW_NOGROUP"]
			end,
			getFunc = function()
				return UnitFramesManager.SAVEVARS.SHOW_NOGROUP
			end,
			setFunc = function(newValue)
				UnitFramesManager.SAVEVARS.SHOW_NOGROUP = newValue
				UnitFramesManager:RefreshData()
				UnitFramesManager:RefreshView(true)
			end,
		},
	}
	LAM2:RegisterOptionControls("ALTGF_Settings", optionsData)
end)
