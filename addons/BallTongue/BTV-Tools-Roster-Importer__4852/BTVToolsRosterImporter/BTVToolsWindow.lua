-- The import window and its wizard (#477, #478, #479, #480): Paste > Review > Missing
-- gear > Flex > Skill placements > Write > The plan, with Missing gear only when the plan
-- has pieces to create, Flex only when the payload carries flex slots, and Skill
-- placements only when a skill has no saved slot on a bar it is on. While an import is in
-- progress `/btv` opens the plan, with Edit picks (Missing gear / Flex from the stored
-- payload, then Write, then the plan again) and New import; Past imports lives behind
-- the Paste step.
--
-- Pure Lua from stock ZOS virtual templates, modelled on Wizard's Wardrobe's own transfer
-- dialog so it reads as a sibling (docs/research/2026-09-01-ww-ui-style.md): near-black
-- ZO_DefaultBackdrop, caps title, parchment gold C5C29E, FF7070 error, F8FF70 attention,
-- yellow warning triangles with tooltips, item names coloured by quality.
--
-- Every state transition is a plain function on BTV.wizard, so the harness drives exactly
-- the code the buttons do, against stubbed WINDOW_MANAGER controls (#474's one seam).

local BTV = BTVTools
local WW = WizardsWardrobe

local GOLD, ERR, WARN, DIM, DONE, IDLE = "C5C29E", "FF7070", "F8FF70", "9A9A9A", "A9A68C", "5C5C5C"
local GREEN = "2DC50E" -- a placed skill's name
local WARN_TEXTURE = "/esoui/art/miscellaneous/eso_icon_warning.dds"

BTV.wizard = {}
local Wizard = BTV.wizard

local ui -- the controls, built once on first open

-- The grid's fixed cell order: the ten body slots the matcher deals into, then the four
-- weapon slots bar by bar.
local DISPLAY_SLOTS = {
	EQUIP_SLOT_HEAD, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_HAND, EQUIP_SLOT_WAIST,
	EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_NECK, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2,
	EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND, EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF,
}

-- The Review step's miss tiers, in the order the ticket lists them: worst first.
local TIERS = {
	{ key = "nowhere", head = "Nowhere on the account" },
	{ key = "shape", head = "Owned, wrong weapon shape" },
	{ key = "weight", head = "Weight ran out" },
	{ key = "noslot", head = "No free slot" },
	{ key = "unknown", head = "Ownership unknown" },
}

-- ------------------------------------------------------------------- helpers

local function StripMarkup( name )
	return zo_strformat( SI_TOOLTIP_ITEM_NAME, name )
end

-- Item names are always coloured by quality, WW's own idiom.
local function ItemLabel( link )
	local name = StripMarkup( GetItemLinkName( link ) )
	local color = GetItemQualityColor( GetItemLinkDisplayQuality( link ) )
	if color then return color:Colorize( name ) end
	return name
end

local function TierHead( text )
	return "|c" .. GOLD .. text:upper() .. "|r"
end

local function Label( name, parent, font )
	local label = WINDOW_MANAGER:CreateControl( name, parent, CT_LABEL )
	label:SetFont( font or "ZoFontGame" )
	return label
end

-- The game's own checkbox (owner hand test 2026-09-08, three times: a mouse-enabled
-- texture never took the click, only its label did). `onSet` gets the new state and
-- must be idempotent: ZO_CheckButton_SetCheckState fires it too.
local function CheckBox( name, parent, text, onSet )
	local box = WINDOW_MANAGER:CreateControlFromVirtual( name, parent, "ZO_CheckButton" )
	ZO_CheckButton_SetLabelText( box, text )
	ZO_CheckButton_SetToggleFunction( box, function( _, checked ) onSet( checked ) end )
	return box
end

local function Button( name, parent, text, onClick )
	local button = WINDOW_MANAGER:CreateControlFromVirtual( name, parent, "ZO_DefaultButton" )
	button:SetDimensions( 170, 28 )
	button:SetText( text )
	button:SetHandler( "OnClicked", onClick )
	return button
end

-- The quality dropdown (#470): gold by default (owner, 2026-09-08), the game's own colour per step. The
-- game's names for green and blue are MAGIC and ARCANE (owner hand test 2026-09-04).
local QUALITIES = {
	{ ITEM_DISPLAY_QUALITY_NORMAL, "White" }, { ITEM_DISPLAY_QUALITY_MAGIC, "Green" },
	{ ITEM_DISPLAY_QUALITY_ARCANE, "Blue" }, { ITEM_DISPLAY_QUALITY_ARTIFACT, "Purple" },
	{ ITEM_DISPLAY_QUALITY_LEGENDARY, "Gold" },
}

-- A stock ZO_ComboBox over `entries` ({ value, label } each); `onPick` gets the value.
local function ComboBox( name, parent, width, entries, onPick )
	local container = WINDOW_MANAGER:CreateControlFromVirtual( name, parent, "ZO_ComboBox" )
	container:SetDimensions( width, 26 )
	local box = ZO_ComboBox_ObjectFromContainer( container )
	box:SetSortsItems( false )
	for _, entry in ipairs( entries ) do
		box:AddItem( box:CreateItemEntry( entry[ 2 ], function() onPick( entry[ 1 ] ) end ) )
	end
	container.box, container.entries = box, entries
	return container
end

local function ShowChoice( container, value )
	for index, entry in ipairs( container.entries ) do
		if entry[ 1 ] == value then container.box:SelectItemByIndex( index, true ) end
	end
end

local function QualityBox( name, parent, onPick )
	local entries = {}
	for _, entry in ipairs( QUALITIES ) do
		table.insert( entries, { entry[ 1 ], GetItemQualityColor( entry[ 1 ] ):Colorize( entry[ 2 ] ) } )
	end
	-- 135 wide: the width the ZO_ComboBox template draws at whatever the container is
	-- told, so anything anchored to its right has to sit past that (owner hand test).
	return ComboBox( name, parent, 135, entries, onPick )
end

-- Every zone Wizard's Wardrobe knows, General first then by name: where a roster with
-- no trial of its own gets written (the player's pick, owner request 2026-09-04).
local function ZoneEntries()
	local zones = {}
	for tag, zone in pairs( WW.zones ) do
		if tag ~= "GEN" then table.insert( zones, { tag, zone.name or tag } ) end
	end
	table.sort( zones, function( a, b ) return a[ 2 ] < b[ 2 ] end )
	table.insert( zones, 1, { "GEN", WW.zones[ "GEN" ] and WW.zones[ "GEN" ].name or "General" } )
	return zones
end

-- The WW warning idiom: yellow triangle, detail in a text tooltip.
local function WarningMark( name, parent )
	local mark = WINDOW_MANAGER:CreateControl( name, parent, CT_TEXTURE )
	mark:SetTexture( WARN_TEXTURE )
	mark:SetColor( 1, 1, 0, 1 )
	mark:SetDimensions( 20, 20 )
	mark:SetMouseEnabled( true )
	mark:SetHandler( "OnMouseEnter", function( self )
		if self.tip then ZO_Tooltips_ShowTextTooltip( self, TOP, self.tip ) end
	end )
	mark:SetHandler( "OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end )
	return mark
end

-- ------------------------------------------------------------------ building

local function BuildRailBox( index )
	-- Inside the scroll child like every other clickable row: a box parented to the
	-- container itself sits under it and never gets the click (owner hand test 2026-09-15).
	local parent = ui.rail:GetNamedChild( "ScrollChild" ) or ui.rail
	-- A plain CT_CONTROL takes the click like the flex, missing and list rows do; the
	-- backdrop only paints. A mouse-enabled backdrop never got the click here (owner
	-- hand test 2026-09-18), the same as the mouse-enabled texture above CheckBox.
	local box = WINDOW_MANAGER:CreateControl( "BTVToolsWindowRailBox" .. index, parent, CT_CONTROL )
	local paint = WINDOW_MANAGER:CreateControl( "BTVToolsWindowRailBox" .. index .. "BG", box, CT_BACKDROP )
	paint:SetCenterColor( 1, 1, 1, 0.045 )
	paint:SetEdgeColor( 0.29, 0.29, 0.26, 1 )
	paint:SetEdgeTexture( "", 1, 1, 1 )
	paint:SetAnchorFill( box )
	box:SetDimensions( 226, 62 )
	box:SetAnchor( TOPLEFT, parent, TOPLEFT, 4, 4 + ( index - 1 ) * 68 )
	box:SetMouseEnabled( true )
	box:SetHandler( "OnMouseUp", function( self ) Wizard.Select( self.key ) end )
	box.name = Label( "BTVToolsWindowRailBox" .. index .. "Name", box, "ZoFontWinH4" )
	box.name:SetAnchor( TOPLEFT, box, TOPLEFT, 8, 5 )
	box.status = Label( "BTVToolsWindowRailBox" .. index .. "Status", box )
	box.status:SetAnchor( TOPLEFT, box.name, BOTTOMLEFT, 0, 2 )
	table.insert( ui.railBoxes, box )
	return box
end

local function BuildCell( index )
	local cell = WINDOW_MANAGER:CreateControl( "BTVToolsWindowCell" .. index, ui.grid, CT_BACKDROP )
	cell:SetCenterColor( 0.09, 0.1, 0.11, 0.9 )
	cell:SetEdgeColor( 0.3, 0.29, 0.26, 1 )
	cell:SetEdgeTexture( "", 1, 1, 1 )
	-- Four to a row, names in the small font on two lines at most with an ellipsis, the
	-- full name on hover: five 100px cells wrapped "Ansuul's Perfected Jack" onto three
	-- lines and out of the box (owner hand test 2026-09-15).
	cell:SetDimensions( 126, 66 )
	cell:SetAnchor( TOPLEFT, ui.grid, TOPLEFT, ( ( index - 1 ) % 4 ) * 132, math.floor( ( index - 1 ) / 4 ) * 72 )
	cell:SetMouseEnabled( true )
	cell:SetHandler( "OnMouseEnter", function( self )
		if self.tip then ZO_Tooltips_ShowTextTooltip( self, TOP, self.tip ) end
	end )
	cell:SetHandler( "OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end )
	cell.slot = Label( "BTVToolsWindowCell" .. index .. "Slot", cell )
	cell.slot:SetFont( "ZoFontGameSmall" )
	cell.slot:SetAnchor( TOPLEFT, cell, TOPLEFT, 5, 4 )
	cell.item = Label( "BTVToolsWindowCell" .. index .. "Item", cell, "ZoFontGameSmall" )
	cell.item:SetAnchor( TOPLEFT, cell.slot, BOTTOMLEFT, 0, 2 )
	cell.item:SetDimensions( 116, 40 )
	cell.item:SetMaxLineCount( 2 )
	cell.item:SetWrapMode( TEXT_WRAP_MODE_ELLIPSIS )
	cell.mark = WarningMark( "BTVToolsWindowCell" .. index .. "Mark", cell )
	cell.mark:SetAnchor( TOPRIGHT, cell, TOPRIGHT, -3, 3 )
	return cell
end

local function BuildPrompt()
	-- Its own TOP-LEVEL window, not a child of the wizard (owner hand test 2026-09-03):
	-- inside one window ESO draws all text above same-layer backdrops, so the Review text
	-- bled through the prompt. WW's own dialogs are separate top-levels for this reason.
	local prompt = WINDOW_MANAGER:CreateTopLevelWindow( "BTVToolsWindowPrompt" )
	prompt:SetAnchorFill( GuiRoot )
	prompt:SetDrawTier( DT_HIGH )
	prompt:SetMouseEnabled( true )
	prompt:SetHidden( true )
	-- Hand-built backdrops, not ZO_DefaultBackdrop: the virtual's center did not paint here.
	local dim = WINDOW_MANAGER:CreateControl( "BTVToolsWindowPromptDim", prompt, CT_BACKDROP )
	dim:SetCenterColor( 0, 0, 0, 0.7 )
	dim:SetEdgeColor( 0, 0, 0, 0 )
	dim:SetEdgeTexture( "", 1, 1, 1 )
	dim:SetAnchorFill( prompt )
	dim:SetMouseEnabled( true ) -- swallows clicks so the Review pane is inert underneath
	local box = WINDOW_MANAGER:CreateControl( "BTVToolsWindowPromptBox", prompt, CT_BACKDROP )
	box:SetCenterColor( 0.04, 0.04, 0.04, 0.97 )
	box:SetEdgeColor( 0.47, 0.46, 0.41, 1 )
	box:SetEdgeTexture( "", 1, 1, 1 )
	box:SetDimensions( 500, 300 )
	box:SetAnchor( CENTER, prompt, CENTER, 0, 0 )
	prompt.title = Label( "BTVToolsWindowPromptTitle", prompt, "ZoFontWinH1" )
	prompt.title:SetAnchor( TOP, box, TOP, 0, 18 )
	prompt.body = Label( "BTVToolsWindowPromptBody", prompt )
	prompt.body:SetAnchor( TOP, prompt.title, BOTTOM, 0, 12 )
	prompt.body:SetWidth( 440 )
	prompt.check = WINDOW_MANAGER:CreateControl( "BTVToolsWindowPromptCheck", prompt, CT_TEXTURE )
	prompt.check:SetDimensions( 20, 20 )
	prompt.check:SetAnchor( TOPLEFT, prompt.body, BOTTOMLEFT, 4, 14 )
	prompt.check:SetMouseEnabled( true )
	prompt.check:SetHandler( "OnMouseUp", function() Wizard.ToggleDontAsk() end )
	prompt.checkLabel = Label( "BTVToolsWindowPromptCheckLabel", prompt )
	prompt.checkLabel:SetAnchor( LEFT, prompt.check, RIGHT, 6, 0 )
	prompt.checkLabel:SetText( "|c" .. DIM .. "Don't ask again, always overwrite my BTV pages|r" )
	prompt.checkLabel:SetMouseEnabled( true )
	prompt.checkLabel:SetHandler( "OnMouseUp", function() Wizard.ToggleDontAsk() end )
	prompt.overwrite = Button( "BTVToolsWindowPromptOverwrite", prompt, "Overwrite",
		function() Wizard.Resolve( "overwrite", Wizard.dontAsk ) end )
	prompt.overwrite:SetAnchor( BOTTOMLEFT, box, BOTTOMLEFT, 16, -14 )
	prompt.overwrite:SetDimensions( 130, 28 )
	-- A fixed label: the full new page name overflows the button, the body names it.
	prompt.create = Button( "BTVToolsWindowPromptCreate", prompt, "Create new",
		function() Wizard.Resolve( "create", Wizard.dontAsk ) end )
	prompt.create:SetAnchor( BOTTOM, box, BOTTOM, 0, -14 )
	prompt.create:SetDimensions( 150, 28 )
	prompt.cancel = Button( "BTVToolsWindowPromptCancel", prompt, "Cancel",
		function() Wizard.Resolve( "cancel" ) end )
	prompt.cancel:SetAnchor( BOTTOMRIGHT, box, BOTTOMRIGHT, -16, -14 )
	prompt.cancel:SetDimensions( 130, 28 )
	return prompt
end

-- A Step tip: the prompt's look (its own top-level, dim, box, gold title) with one button.
local function BuildTip()
	local tip = WINDOW_MANAGER:CreateTopLevelWindow( "BTVToolsWindowTip" )
	tip:SetAnchorFill( GuiRoot )
	tip:SetDrawTier( DT_HIGH )
	tip:SetMouseEnabled( true )
	tip:SetHidden( true )
	local dim = WINDOW_MANAGER:CreateControl( "BTVToolsWindowTipDim", tip, CT_BACKDROP )
	dim:SetCenterColor( 0, 0, 0, 0.7 )
	dim:SetEdgeColor( 0, 0, 0, 0 )
	dim:SetEdgeTexture( "", 1, 1, 1 )
	dim:SetAnchorFill( tip )
	dim:SetMouseEnabled( true )
	local box = WINDOW_MANAGER:CreateControl( "BTVToolsWindowTipBox", tip, CT_BACKDROP )
	box:SetCenterColor( 0.04, 0.04, 0.04, 0.97 )
	box:SetEdgeColor( 0.47, 0.46, 0.41, 1 )
	box:SetEdgeTexture( "", 1, 1, 1 )
	box:SetDimensions( 500, 300 )
	box:SetAnchor( CENTER, tip, CENTER, 0, 0 )
	tip.title = Label( "BTVToolsWindowTipTitle", tip, "ZoFontWinH1" )
	tip.title:SetAnchor( TOP, box, TOP, 0, 18 )
	tip.body = Label( "BTVToolsWindowTipBody", tip )
	tip.body:SetAnchor( TOP, tip.title, BOTTOM, 0, 12 )
	tip.body:SetWidth( 440 )
	tip.hint = Label( "BTVToolsWindowTipHint", tip )
	tip.hint:SetAnchor( TOPLEFT, tip.body, BOTTOMLEFT, 0, 14 )
	tip.hint:SetWidth( 440 )
	tip.ok = Button( "BTVToolsWindowTipOk", tip, "Got it", function() Wizard.NextTip() end )
	tip.ok:SetAnchor( BOTTOM, box, BOTTOM, 0, -14 )
	tip.ok:SetDimensions( 130, 28 )
	return tip
end

-- ---- Skill placements: our own drag, since the game cursor only carries purchased skills ----

-- The slot box under the mouse, by rectangle: the drag icon itself takes no mouse.
local function SlotUnderMouse()
	local x, y = GetUIMousePosition()
	for slot, box in pairs( ui.placeBoxes ) do
		if x >= box:GetLeft() and x <= box:GetRight() and y >= box:GetTop() and y <= box:GetBottom() then return slot end
	end
end

-- Press a skill to pick it up. Let go over a slot box and it lands there (a drag); let go
-- anywhere else and it stays held until a slot is clicked (click, then click).
local function OnSkillDown( control, button )
	if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
	Wizard.pressFresh = Wizard.held == nil
	if Wizard.pressFresh then Wizard.Hold( control.skill, control.from ) end
end

local function OnSkillUp( control, button )
	if button == MOUSE_BUTTON_INDEX_RIGHT then Wizard.Hold( nil ) return end
	if button ~= MOUSE_BUTTON_INDEX_LEFT or not Wizard.held then return end
	local slot = SlotUnderMouse()
	if Wizard.pressFresh then
		if slot and slot ~= Wizard.held.from then Wizard.Place( slot ) end
	elseif slot then
		Wizard.Place( slot )
	else
		Wizard.Hold( control.skill, control.from )
	end
end

-- A skill to drag: a plain CT_CONTROL takes the mouse, its art only paints (the rail box lesson).
local function SkillControl( name, parent, size )
	local control = WINDOW_MANAGER:CreateControl( name, parent, CT_CONTROL )
	control:SetMouseEnabled( true )
	control:SetHandler( "OnMouseDown", OnSkillDown )
	control:SetHandler( "OnMouseUp", OnSkillUp )
	control:SetHandler( "OnMouseEnter", function( self )
		local skill = self.skill
		if skill then
			ZO_Tooltips_ShowTextTooltip( self, TOP, GetAbilityName( skill.id ) .. ( skill.tag and ( skill.bar == 0 and " (front bar)" or " (back bar)" ) or "" ) )
		end
	end )
	control:SetHandler( "OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end )
	control.art = WINDOW_MANAGER:CreateControl( name .. "Art", control, CT_TEXTURE )
	control.art:SetDimensions( size, size )
	control.art:SetAnchor( LEFT, control, LEFT, 0, 0 )
	return control
end

-- One of the five slots, like a WW bar. A slot holds many skills, small icons side by side.
local function BuildPlaceBox( slot )
	local name = "BTVToolsWindowPlaceBox" .. slot
	local box = WINDOW_MANAGER:CreateControl( name, ui.placementPane, CT_CONTROL )
	local paint = WINDOW_MANAGER:CreateControl( name .. "BG", box, CT_BACKDROP )
	paint:SetCenterColor( 1, 1, 1, 0.045 )
	paint:SetEdgeColor( 0.29, 0.29, 0.26, 1 )
	paint:SetEdgeTexture( "", 1, 1, 1 )
	paint:SetAnchorFill( box )
	box:SetDimensions( 148, 200 )
	box:SetAnchor( TOPLEFT, ui.placementPane, TOPLEFT, ( slot - 3 ) * 158, 0 )
	box:SetMouseEnabled( true )
	box:SetHandler( "OnMouseUp", function( self, button )
		if button == MOUSE_BUTTON_INDEX_LEFT and Wizard.held then Wizard.Place( self.slot ) end
	end )
	box.slot = slot
	box.name = Label( name .. "Name", box, "ZoFontWinH4" )
	box.name:SetAnchor( TOPLEFT, box, TOPLEFT, 8, 5 )
	box.name:SetText( TierHead( "Slot " .. ( slot - 2 ) ) )
	box.mark = WarningMark( name .. "Mark", box )
	box.mark:SetAnchor( TOPRIGHT, box, TOPRIGHT, -4, 4 )
	box.icons = {}
	return box
end

-- The icon that follows the mouse while a skill is held.
local function BuildDrag()
	local drag = WINDOW_MANAGER:CreateTopLevelWindow( "BTVToolsWindowDrag" )
	drag:SetDimensions( 40, 40 )
	drag:SetDrawTier( DT_HIGH )
	drag:SetHidden( true )
	drag.art = WINDOW_MANAGER:CreateControl( "BTVToolsWindowDragArt", drag, CT_TEXTURE )
	drag.art:SetAnchorFill( drag )
	drag:SetHandler( "OnUpdate", function( self )
		local x, y = GetUIMousePosition()
		self:ClearAnchors()
		self:SetAnchor( CENTER, GuiRoot, TOPLEFT, x, y )
	end )
	return drag
end

local function BuildWindow()
	if ui then return end
	ui = { railBoxes = {}, cells = {} }
	Wizard.controls = ui

	local window = WINDOW_MANAGER:CreateTopLevelWindow( "BTVToolsWindow" )
	window:SetDimensions( 840, 620 )
	window:SetAnchor( CENTER, GuiRoot, CENTER, 0, 0 )
	window:SetMovable( true )
	window:SetMouseEnabled( true )
	window:SetClampedToScreen( true )
	window:SetHidden( true )
	ui.window = window

	local backdrop = WINDOW_MANAGER:CreateControlFromVirtual( "BTVToolsWindowBG", window, "ZO_DefaultBackdrop" )
	backdrop:SetAnchorFill( window )
	backdrop:SetAlpha( 0.95 )

	ui.title = Label( "BTVToolsWindowTitle", window, "ZoFontWinH1" )
	ui.title:SetAnchor( TOP, window, TOP, 0, 14 )
	ui.title:SetText( "BTV ROSTER IMPORT" )

	local close = WINDOW_MANAGER:CreateControl( "BTVToolsWindowClose", window, CT_BUTTON )
	close:SetDimensions( 24, 24 )
	close:SetAnchor( TOPRIGHT, window, TOPRIGHT, -10, 10 )
	close:SetNormalTexture( "/esoui/art/buttons/decline_up.dds" )
	close:SetPressedTexture( "/esoui/art/buttons/decline_down.dds" )
	close:SetMouseOverTexture( "/esoui/art/buttons/decline_over.dds" )
	close:SetHandler( "OnClicked", function() Wizard.Close() end )

	if BTV.canSupport then
		local support = WINDOW_MANAGER:CreateControl( "BTVToolsWindowSupport", window, CT_BUTTON )
		support:SetDimensions( 24, 24 )
		support:SetAnchor( TOPLEFT, window, TOPLEFT, 10, 10 )
		support:SetNormalTexture( "/esoui/art/currency/currency_gold_32.dds" )
		support:SetHandler( "OnClicked", function() BTV.Support() end )
		support:SetHandler( "OnMouseEnter", function( self ) ZO_Tooltips_ShowTextTooltip( self, TOP, "Support" ) end )
		support:SetHandler( "OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end )
	end

	ui.sub = Label( "BTVToolsWindowSub", window )
	ui.sub:SetAnchor( TOP, ui.title, BOTTOM, 0, 2 )
	ui.sub:SetWidth( 800 )
	ui.steps = Label( "BTVToolsWindowSteps", window, "ZoFontGameBold" )
	ui.steps:SetAnchor( TOP, ui.sub, BOTTOM, 0, 6 )
	-- WW's own help icon (its transfer dialog), replaying this screen's Step tips.
	ui.help = WINDOW_MANAGER:CreateControl( "BTVToolsWindowHelp", window, CT_BUTTON )
	ui.help:SetDimensions( 24, 24 )
	ui.help:SetAnchor( LEFT, ui.steps, RIGHT, 8, 0 )
	ui.help:SetNormalTexture( "/esoui/art/menubar/menubar_help_up.dds" )
	ui.help:SetMouseOverTexture( "/esoui/art/menubar/menubar_help_over.dds" )
	ui.help:SetHandler( "OnClicked", function() Wizard.ReplayTips() end )

	local divider = WINDOW_MANAGER:CreateControl( "BTVToolsWindowDivider", window, CT_TEXTURE )
	divider:SetTexture( "/esoui/art/miscellaneous/centerscreen_topdivider.dds" )
	divider:SetDimensions( 800, 2 )
	divider:SetAnchor( TOP, ui.steps, BOTTOM, 0, 8 )

	-- ---- Paste ----
	local paste = WINDOW_MANAGER:CreateControl( "BTVToolsWindowPaste", window, CT_CONTROL )
	paste:SetAnchor( TOPLEFT, window, TOPLEFT, 30, 112 )
	paste:SetDimensions( 780, 440 )
	ui.pastePane = paste
	local editBackdrop = WINDOW_MANAGER:CreateControlFromVirtual( "BTVToolsWindowPasteBG", paste, "ZO_EditBackdrop" )
	editBackdrop:SetDimensions( 780, 280 )
	editBackdrop:SetAnchor( TOPLEFT, paste, TOPLEFT, 0, 0 )
	editBackdrop:SetAlpha( 0.9 )
	ui.paste = WINDOW_MANAGER:CreateControlFromVirtual( "BTVToolsWindowPasteEdit", editBackdrop, "ZO_DefaultEditMultiLine" )
	ui.paste:SetAnchorFill( editBackdrop )
	ui.paste:SetMaxInputChars( BTV.PASTE_LIMIT )
	ui.paste:SetHandler( "OnTextChanged", function()
		-- A fresh paste retires the last attempt's error; only typing clears it, so a
		-- Render right after a failed Next still shows it.
		Wizard.error = nil
		ui.pasteError:SetText( "" )
		Wizard.OnPasteChanged()
	end )
	ui.pageLine = Label( "BTVToolsWindowPageLine", paste )
	ui.pageLine:SetAnchor( TOPLEFT, editBackdrop, BOTTOMLEFT, 0, 10 )
	ui.pageLine:SetWidth( 780 )
	-- Where a roster naming no trial gets written: WW's General zone unless the player
	-- picks another (the Infinite Archive, say, which the builder has no template for).
	ui.zoneLine = Label( "BTVToolsWindowZoneLine", paste )
	ui.zoneLine:SetAnchor( TOPLEFT, ui.pageLine, BOTTOMLEFT, 0, 8 )
	ui.zoneLine:SetText( "|c" .. DIM .. "This roster names no trial. Write it under|r" )
	ui.zone = ComboBox( "BTVToolsWindowZone", paste, 240, ZoneEntries(), function( tag ) Wizard.zoneTag = tag end )
	ui.zone:SetAnchor( LEFT, ui.zoneLine, RIGHT, 10, 0 )
	-- Follow the roster to the letter (owner, 2026-09-08): a setting, so it sticks.
	ui.exactTraits = CheckBox( "BTVToolsWindowExactTraits", paste,
		"Exact traits only: never wear an off-trait piece, plan a new one instead",
		function( on ) Wizard.SetExactTraits( on ) end )
	ui.exactTraits:SetAnchor( TOPLEFT, ui.zoneLine, BOTTOMLEFT, 0, 10 )
	ui.pasteError = Label( "BTVToolsWindowPasteError", paste )
	ui.pasteError:SetAnchor( TOPLEFT, ui.exactTraits, BOTTOMLEFT, 0, 8 )
	ui.pasteError:SetWidth( 780 )

	-- ---- Review: rail + detail + grid ----
	local review = WINDOW_MANAGER:CreateControl( "BTVToolsWindowReview", window, CT_CONTROL )
	review:SetAnchor( TOPLEFT, window, TOPLEFT, 20, 112 )
	review:SetDimensions( 800, 440 )
	ui.reviewPane = review
	ui.rail = WINDOW_MANAGER:CreateControlFromVirtual( "BTVToolsWindowRail", review, "ZO_ScrollContainer" )
	ui.rail:SetDimensions( 240, 440 )
	ui.rail:SetAnchor( TOPLEFT, review, TOPLEFT, 0, 0 )
	ui.detail = WINDOW_MANAGER:CreateControlFromVirtual( "BTVToolsWindowDetail", review, "ZO_ScrollContainer" )
	ui.detail:SetDimensions( 550, 440 )
	ui.detail:SetAnchor( TOPLEFT, ui.rail, TOPRIGHT, 10, 0 )
	local detailChild = ui.detail:GetNamedChild( "ScrollChild" ) or ui.detail
	ui.grid = WINDOW_MANAGER:CreateControl( "BTVToolsWindowGrid", detailChild, CT_CONTROL )
	ui.grid:SetDimensions( 530, 284 )
	ui.grid:SetAnchor( TOPLEFT, detailChild, TOPLEFT, 0, 4 )
	for index = 1, #DISPLAY_SLOTS do
		ui.cells[ index ] = BuildCell( index )
	end
	ui.detailText = Label( "BTVToolsWindowDetailText", detailChild )
	ui.detailText:SetWidth( 530 )
	ui.placedToggle = Button( "BTVToolsWindowPlacedToggle", review, "Show placed", function() Wizard.TogglePlaced() end )
	ui.placedToggle:SetDimensions( 110, 22 )
	ui.placedToggle:SetAnchor( TOPRIGHT, review, TOPRIGHT, -24, 0 )

	-- ---- Missing gear (#479): a bar with the quality controls, then one picker per gap ----
	local missing = WINDOW_MANAGER:CreateControl( "BTVToolsWindowMissing", window, CT_CONTROL )
	missing:SetDimensions( 780, 440 )
	missing:SetAnchor( TOPLEFT, window, TOPLEFT, 30, 112 )
	ui.missingPane = missing
	ui.qualityLabel = Label( "BTVToolsWindowMissingQualityLabel", missing )
	ui.qualityLabel:SetAnchor( TOPLEFT, missing, TOPLEFT, 0, 4 )
	ui.qualityLabel:SetText( "|c" .. DIM .. "Quality for every piece|r" )
	ui.quality = QualityBox( "BTVToolsWindowMissingQuality", missing, function( quality ) Wizard.SetQuality( quality ) end )
	ui.quality:SetAnchor( LEFT, ui.qualityLabel, RIGHT, 10, 0 )
	ui.perPiece = CheckBox( "BTVToolsWindowMissingPerPiece", missing, "Pick a quality per piece",
		function( on ) Wizard.SetPerPiece( on ) end )
	ui.perPiece:SetAnchor( LEFT, ui.quality, RIGHT, 40, 0 )
	ui.missingList = WINDOW_MANAGER:CreateControlFromVirtual( "BTVToolsWindowMissingList", missing, "ZO_ScrollContainer" )
	ui.missingList:SetDimensions( 780, 404 )
	ui.missingList:SetAnchor( TOPLEFT, missing, TOPLEFT, 0, 36 )
	ui.missingRows, ui.missingQuality = {}, {}

	-- ---- Flex (#478): one block per distinct flex slot, options as radio rows ----
	local flex = WINDOW_MANAGER:CreateControlFromVirtual( "BTVToolsWindowFlex", window, "ZO_ScrollContainer" )
	flex:SetDimensions( 780, 440 )
	flex:SetAnchor( TOPLEFT, window, TOPLEFT, 30, 112 )
	ui.flexPane = flex
	ui.flexRows = {}

	-- ---- Skill placements: five slot boxes, the skills to place under them, then the buttons ----
	local placement = WINDOW_MANAGER:CreateControl( "BTVToolsWindowPlacement", window, CT_CONTROL )
	placement:SetDimensions( 780, 440 )
	placement:SetAnchor( TOPLEFT, window, TOPLEFT, 30, 112 )
	ui.placementPane = placement
	ui.placeBoxes = {}
	for slot = 3, 7 do ui.placeBoxes[ slot ] = BuildPlaceBox( slot ) end
	ui.placeList = WINDOW_MANAGER:CreateControlFromVirtual( "BTVToolsWindowPlaceList", placement, "ZO_ScrollContainer" )
	ui.placeList:SetDimensions( 780, 190 )
	ui.placeList:SetAnchor( TOPLEFT, placement, TOPLEFT, 0, 210 )
	ui.placeRows = {}
	ui.placeFill = Button( "BTVToolsWindowPlaceFill", placement, "Fill from my bars", function() Wizard.FillFromBars() end )
	ui.placeFill:SetAnchor( BOTTOMLEFT, placement, BOTTOMLEFT, 0, 0 )
	ui.placeSkip = Button( "BTVToolsWindowPlaceSkip", placement, "Skip", function() Wizard.SkipPlacements() end )
	ui.placeSkip:SetAnchor( LEFT, ui.placeFill, RIGHT, 12, 0 )
	ui.placeNever = Button( "BTVToolsWindowPlaceNever", placement, "Never ask", function() Wizard.NeverAsk() end )
	ui.placeNever:SetAnchor( LEFT, ui.placeSkip, RIGHT, 12, 0 )
	ui.placeForget = Button( "BTVToolsWindowPlaceForget", placement, "Forget all", function() Wizard.AskForget() end )
	ui.placeForget:SetAnchor( LEFT, ui.placeFill, RIGHT, 12, 0 )
	ui.drag = BuildDrag()

	-- ---- The plan and Past imports (#480): one list of rows, a check mark per line ----
	local list = WINDOW_MANAGER:CreateControlFromVirtual( "BTVToolsWindowList", window, "ZO_ScrollContainer" )
	list:SetDimensions( 780, 440 )
	list:SetAnchor( TOPLEFT, window, TOPLEFT, 30, 112 )
	ui.listPane = list
	ui.listRows = {}

	-- ---- Footer ----
	ui.summary = Label( "BTVToolsWindowSummary", window )
	ui.summary:SetAnchor( BOTTOM, window, BOTTOM, 0, -22 )
	ui.back = Button( "BTVToolsWindowBack", window, "Back", function() Wizard.Back() end )
	ui.back:SetAnchor( BOTTOMLEFT, window, BOTTOMLEFT, 24, -16 )
	ui.next = Button( "BTVToolsWindowNext", window, "Next", function() Wizard.Continue() end )
	ui.next:SetAnchor( BOTTOMRIGHT, window, BOTTOMRIGHT, -24, -16 )
	-- The plan's one live action at a bank or coffer (#481): Fetch on the importer,
	-- Deposit on an alt. Hidden when there is nothing to move.
	ui.move = Button( "BTVToolsWindowMove", window, "", function()
		if Wizard.moves and #Wizard.moves.items > 0 then BTV.MoveGear( Wizard.moves ) end
	end )
	ui.move:SetAnchor( RIGHT, ui.next, LEFT, -12, 0 )

	ui.prompt = BuildPrompt()
	ui.tip = BuildTip()
end

-- ----------------------------------------------------------------- rendering

-- Whether this import has flex picks to make, so the Flex step only exists when it
-- has something to ask (#478).
local function HasFlex()
	return Wizard.analysis and Wizard.analysis.flex and #Wizard.analysis.flex > 0
end

-- Whether this import has pieces to create, so the Missing gear step only exists when
-- it has something to plan (#479).
local function HasMissing()
	local missing = Wizard.analysis and Wizard.analysis.missing
	return missing ~= nil and #missing.gaps > 0
end

-- The Skill placements step's state, one screen for both bars (owner, 2026-10-15).
-- `entries` lists a skill once per bar it sits on with no saved slot there, tagged FB / BB
-- when it sits on both bars in this import; `picks[ bar ][ key ]` is what was dropped, saved
-- on Next. `/btv placements` (`placementOnly`) lists nothing and draws every saved skill.
local TAG = { [ 0 ] = "FB", [ 1 ] = "BB" }
local function NewPlacing()
	local saved = BTV.svAccount.placements
	local placing = { entries = {}, listed = { [ 0 ] = {}, [ 1 ] = {} }, picks = { [ 0 ] = {}, [ 1 ] = {} } }
	if Wizard.placementOnly then return placing end
	placing.bars, placing.writes = BTV.PlacementSkills( Wizard.analysis )
	-- Skills in first-seen order, front bar first, so a skill's FB and BB sit together.
	local on, order = { [ 0 ] = {}, [ 1 ] = {} }, {}
	for bar = 0, 1 do
		for _, skill in ipairs( placing.bars[ bar ] ) do
			if not on[ 0 ][ skill.key ] and not on[ 1 ][ skill.key ] then table.insert( order, skill.key ) end
			on[ bar ][ skill.key ] = skill
		end
	end
	placing.both = {}
	for _, key in ipairs( order ) do
		placing.both[ key ] = on[ 0 ][ key ] ~= nil and on[ 1 ][ key ] ~= nil
		for bar = 0, 1 do
			local skill = on[ bar ][ key ]
			if skill and not ( saved[ key ] and saved[ key ][ bar ] ) then
				table.insert( placing.entries, { key = key, id = skill.id, bar = bar, tag = placing.both[ key ] and TAG[ bar ] or nil } )
				placing.listed[ bar ][ key ] = true
			end
		end
	end
	return placing
end

-- Kept while the step is open, or Fill from my bars could make it vanish under the player.
local function HasPlacement()
	if Wizard.placementOnly or Wizard.placing then return true end
	return Wizard.analysis ~= nil and BTV.Setting( "usePlacements" ) and #NewPlacing().entries > 0
end

-- The steps this import walks, in order: the optional ones only when they have
-- something to ask. "write" is the Next button on the step before the plan, never a
-- pane. Edit picks (#480) skips Paste and Review: the payload comes from the record.
local STEP_WORD = { paste = "Paste", review = "Review", missing = "Plan missing gear", flex = "Flex",
	placement = "Skill placements", write = "Write", plan = "The plan" }
local function Steps()
	if Wizard.placementOnly then return { "placement" } end
	local steps = Wizard.editing and {} or { "paste", "review" }
	if HasMissing() then table.insert( steps, "missing" ) end
	if HasFlex() then table.insert( steps, "flex" ) end
	if HasPlacement() then table.insert( steps, "placement" ) end
	table.insert( steps, "write" )
	table.insert( steps, "plan" )
	return steps
end

local function StepIndex( steps, step )
	for index, name in ipairs( steps ) do
		if name == step then return index end
	end
	return 1
end

local function StepsLine()
	local steps = Steps()
	local current = StepIndex( steps, Wizard.step )
	local parts = {}
	for index, step in ipairs( steps ) do
		local color = index == current and GOLD or ( index < current and DONE or IDLE )
		table.insert( parts, "|c" .. color .. STEP_WORD[ step ]:upper() .. "|r" )
	end
	return table.concat( parts, "  |c" .. IDLE .. ">|r  " )
end

local function FoundLines( pieces )
	local lines = {}
	for _, piece in ipairs( pieces ) do
		table.insert( lines, string.format( "%s  |c%s%s|r", ItemLabel( piece.link ), DIM, piece.where ) )
	end
	return lines
end

-- The All setups detail: found gear grouped by source, placed collapsed to a count line,
-- misses grouped by tier (#477).
local function AllText()
	local analysis = Wizard.analysis
	local found, lines = analysis.found, {}

	table.insert( lines, string.format( "%s |c%s%d pieces, nothing to do|r",
		TierHead( "On this character" ), DIM, #found.here ) )
	if Wizard.showPlaced then
		for _, line in ipairs( FoundLines( found.here ) ) do table.insert( lines, "  " .. line ) end
	end
	if #found.bank > 0 then
		table.insert( lines, TierHead( "In the bank" )
			.. string.format( " |c%s%d to withdraw|r", DIM, #found.bank ) )
		for _, line in ipairs( FoundLines( found.bank ) ) do table.insert( lines, "  " .. line ) end
	end
	if #found.away > 0 then
		table.insert( lines, TierHead( "Elsewhere on the account" )
			.. string.format( " |c%s%d on the fetch list|r", DIM, #found.away ) )
		for _, line in ipairs( FoundLines( found.away ) ) do table.insert( lines, "  " .. line ) end
	end

	for _, tier in ipairs( TIERS ) do
		local block = {}
		for _, miss in ipairs( analysis.misses ) do
			if miss.tier == tier.key then table.insert( block, "  " .. miss.line ) end
		end
		if #block > 0 then
			table.insert( lines, TierHead( tier.head ) )
			for _, line in ipairs( block ) do table.insert( lines, line ) end
		end
	end

	if #analysis.traits > 0 then
		table.insert( lines, TierHead( "Off trait" ) .. " |c" .. DIM .. "the cheapest miss, every piece is slotted|r" )
		for _, line in ipairs( analysis.traits ) do table.insert( lines, "  " .. line ) end
	end

	return table.concat( lines, "\n" )
end

local function RenderCell( cell, slotId, review )
	cell.slot:SetText( "|c" .. IDLE .. ( BTV.SLOT_NAME[ slotId ] or tostring( slotId ) ):upper() .. "|r" )
	local hit = review.grid[ slotId ]
	cell.tip = nil
	cell.mark:SetHidden( true )
	if not hit then
		cell.item:SetText( "|c" .. IDLE .. "-|r" )
	elseif hit.miss then
		cell.item:SetText( "|c" .. ( hit.tier == "nowhere" and ERR or WARN ) .. "missing|r" )
		cell.mark:SetHidden( false )
		cell.mark.tip = hit.miss
		cell.tip = hit.miss
	else
		cell.item:SetText( ItemLabel( hit.link ) .. ( hit.remote and " |c" .. WARN .. "(fetch)|r" or "" ) )
		-- The cell shows two lines at most, so the whole name lives on hover.
		cell.tip = ItemLabel( hit.link )
		if hit.remote then
			cell.tip = cell.tip .. "\nWritten into the setup, not on this character. Bring it to your backpack: "
				.. ( hit.places and table.concat( hit.places, " or " ) or "IIfA did not say where" )
		end
	end
end

local function EntryText( review )
	local lines = {}
	for _, line in ipairs( review.extra ) do table.insert( lines, line ) end
	table.insert( lines, string.format(
		"|c%sHover a mark for the miss tier. Skills are written with your flex picks and skill placements. CP is written as the roster has it.|r", DIM ) )
	return table.concat( lines, "\n" )
end

local function RenderRail()
	local analysis = Wizard.analysis
	local function Fill( index, key, name, status )
		local box = ui.railBoxes[ index ] or BuildRailBox( index )
		box.key = key
		box:SetHidden( false )
		local selected = Wizard.selected == key
		box.name:SetText( ( selected and "|c" .. GOLD or "|cFFFFFF" ) .. name:upper() .. "|r" )
		box.status:SetText( status )
	end
	local summary = analysis.summary
	Fill( 1, "all", "All setups", string.format( "|c%s%d/%d pieces|r%s", DIM, summary.placed, summary.total,
		summary.unplaced > 0 and string.format( "  |c%s%d to sort|r", WARN, summary.unplaced ) or "" ) )
	for index, review in ipairs( analysis.entries ) do
		local name = review.rows > 1 and string.format( "%s x%d", review.name, review.rows ) or review.name
		local missing = review.demandCount - review.placedCount
		Fill( index + 1, index, name, string.format( "|c%s%d/%d|r%s", DIM, review.placedCount, review.demandCount,
			missing > 0 and string.format( "  |c%s%d to sort|r", WARN, missing ) or "" ) )
	end
	for index = #analysis.entries + 2, #ui.railBoxes do
		ui.railBoxes[ index ]:SetHidden( true )
	end
end

-- ---- The Flex step (#478) ----

local function BuildFlexRow( index )
	local parent = ui.flexPane:GetNamedChild( "ScrollChild" ) or ui.flexPane
	local row = WINDOW_MANAGER:CreateControl( "BTVToolsWindowFlexRow" .. index, parent, CT_CONTROL )
	row:SetDimensions( 740, 24 )
	row:SetAnchor( TOPLEFT, parent, TOPLEFT, 0, 4 + ( index - 1 ) * 26 )
	row:SetMouseEnabled( true )
	row:SetHandler( "OnMouseUp", function( self ) if self.onClick then self.onClick() end end )
	row.radio = WINDOW_MANAGER:CreateControl( "BTVToolsWindowFlexRow" .. index .. "Radio", row, CT_TEXTURE )
	row.radio:SetDimensions( 20, 20 )
	row.radio:SetAnchor( LEFT, row, LEFT, 16, 0 )
	row.icon = WINDOW_MANAGER:CreateControl( "BTVToolsWindowFlexRow" .. index .. "Icon", row, CT_TEXTURE )
	row.icon:SetDimensions( 24, 24 )
	row.icon:SetAnchor( LEFT, row.radio, RIGHT, 8, 0 )
	row.label = Label( "BTVToolsWindowFlexRow" .. index .. "Label", row )
	table.insert( ui.flexRows, row )
	return row
end

-- Every position the block fills: content matching can merge a front bar slot with a
-- back bar one, and the header has to say so.
local function FlexSlotWords( block )
	local parts = {}
	for _, position in ipairs( block.positions ) do
		local where = position.bar == "0" and "Front bar" or "Back bar"
		if position.slot == "8" then
			table.insert( parts, where .. " ultimate" )
		else
			table.insert( parts, where .. " skill " .. tostring( tonumber( position.slot ) - 2 ) )
		end
	end
	return table.concat( parts, " + " )
end

local function WriteLabel( analysis )
	return string.format( "Write %d setup%s", #analysis.writes, #analysis.writes == 1 and "" or "s" )
end

-- What the Next button says on a step: the next step's name, or the write.
local function NextLabel()
	local steps = Steps()
	local following = steps[ StepIndex( steps, Wizard.step ) + 1 ]
	if following == "missing" then return "Next: plan missing gear" end
	if following == "flex" then return "Next: flex picks" end
	if following == "placement" then return "Next: skill placements" end
	return WriteLabel( Wizard.analysis )
end

-- ---- Step tips (docs/plans/2026-10-14-ww-addon-step-tips.md) ----

-- The owner's wording; **x** is drawn gold.
local TIPS = {
	paste = { "PASTE", "Open the roster link and press **WW export** at the top (or **WW Export** in the sidebar on your own roster). Pick your name, press **Copy WW payload**, and paste it here." },
	review = { "REVIEW", "The addon finds the best combination of gear you already own to match the roster. This shows where every piece is located: on you, in the bank, on another character, or in a coffer." },
	missing = { "PLAN MISSING GEAR", "Pieces that can't be found anywhere on your account need to be obtained to match the roster. Here you choose how to get each one: craft, reconstruct, buy or farm." },
	flex = { "FLEX", "Some skill slots are open as flex. Pick one skill and it fills every setup with that slot." },
	placement = { "SKILL PLACEMENTS", "Drag each skill onto the slot you want it in, or click it and then click a slot. The addon remembers, and puts it in that slot in every setup it writes, for every roster. Already have your bars the way you like? Press **Fill from my bars**." },
	plan = { "THE PLAN", "Your setups are saved, and this is your to-do list to gather all the gear. Boxes tick themselves as gear lands in your inventory. The addon doesn't walk you to the right places: you still go to the bank, coffers, crafting and transmute stations yourself to get the gear." },
	crafting = { "CRAFTING", "You could turn on **Auto craft and reconstruct** in the settings, then walk up to the right station and the addon makes the correct gear for you. It's experimental and spends real mats, so check the item on the roster first." },
	bank = { "BANK", "Withdraw the pieces this build needs, or turn on **Auto deposit/withdraw** in the settings and the addon does it for you when you open the bank. Gear on another character? Deposit it there, then withdraw it on the right character." },
}

-- Keyed by the step that really comes next; "plan" goes on the plan screen's last tip
-- before Bank, "bank" on Bank.
local TIP_HINTS = {
	review = "Next: see where all your gear is.",
	missing = "Next: pick how to get the gear you don't own.",
	flex = "Next: pick skills for the open slots.",
	placement = "Next: pick a slot for each new skill.",
	write = "Next: press Write to save your setups to Wizard's Wardrobe.",
	plan = "Next: open your bank to grab your gear.",
	bank = "Once every box is ticked, you're done.",
}

local function HasCraftLine()
	for _, group in ipairs( Wizard.plan and Wizard.plan.groups or {} ) do
		if group.kind == "craft" or group.kind == "reconstruct" then return true end
	end
	return false
end

-- The tips this screen has, in order. Bank only once Fetch/Deposit shows, unless it is
-- the "?" asking.
local function ScreenTips( replay )
	local step = Wizard.step
	if step ~= "plan" then return TIPS[ step ] and { step } or {} end
	local keys = { "plan" }
	if HasCraftLine() then table.insert( keys, "crafting" ) end
	if replay or ( Wizard.moves and #Wizard.moves.items > 0 ) then table.insert( keys, "bank" ) end
	return keys
end

-- Queues this screen's unseen tips (never over a prompt) and shows the first. A tip is
-- seen once it is on screen.
local function RenderTip()
	if Wizard.tipStep ~= Wizard.step then Wizard.tips = nil end
	local seen = BTV.svAccount.tipsSeen
	if not Wizard.tips and not Wizard.prompt then
		local fresh = {}
		for _, key in ipairs( ScreenTips() ) do
			if not seen[ key ] then table.insert( fresh, key ) end
		end
		if #fresh > 0 then Wizard.tips, Wizard.tipStep = fresh, Wizard.step end
	end
	ui.help:SetHidden( #ScreenTips( true ) == 0 )
	local key = Wizard.tips and Wizard.tips[ 1 ]
	ui.tip:SetHidden( key == nil )
	if not key then return end
	seen[ key ] = true
	local hint
	if key == "bank" then
		hint = TIP_HINTS.bank
	elseif key == "crafting" or ( key == "plan" and Wizard.tips[ 2 ] ~= "crafting" ) then
		hint = TIP_HINTS.plan
	elseif key ~= "plan" then
		local steps = Steps()
		hint = TIP_HINTS[ steps[ StepIndex( steps, key ) + 1 ] ]
	end
	ui.tip.title:SetText( TIPS[ key ][ 1 ] )
	ui.tip.body:SetText( ( TIPS[ key ][ 2 ]:gsub( "%*%*(.-)%*%*", "|c" .. GOLD .. "%1|r" ) ) )
	ui.tip.hint:SetText( hint and ( "|c" .. DIM .. hint .. "|r" ) or "" )
	ui.tip.ok:SetText( #Wizard.tips > 1 and "Next" or "Got it" )
end

-- ---- The Missing gear step (#479) ----

local function BuildMissingRow( index )
	local parent = ui.missingList:GetNamedChild( "ScrollChild" ) or ui.missingList
	local row = WINDOW_MANAGER:CreateControl( "BTVToolsWindowMissingRow" .. index, parent, CT_CONTROL )
	row:SetDimensions( 760, 24 )
	row:SetMouseEnabled( true )
	row:SetHandler( "OnMouseUp", function( self ) if self.onClick then self.onClick() end end )
	row.radio = WINDOW_MANAGER:CreateControl( "BTVToolsWindowMissingRow" .. index .. "Radio", row, CT_TEXTURE )
	row.radio:SetDimensions( 20, 20 )
	row.label = Label( "BTVToolsWindowMissingRow" .. index .. "Label", row )
	table.insert( ui.missingRows, row )
	return row
end

local PATH_WORD = { craft = "Craft", reconstruct = "Reconstruct", farm = "Farm", buy = "Buy" }

-- Transmute crystals the way the game writes them: the amount and its icon.
local function Crystals( amount )
	if ZO_Currency_FormatKeyboard then
		return ZO_Currency_FormatKeyboard( CURT_CHAOTIC_CREATIA, amount or 0, ZO_CURRENCY_FORMAT_AMOUNT_ICON )
	end
	return tostring( amount or 0 ) .. " crystals"
end
Wizard.Crystals = Crystals

-- "head, medium, Divines": the shape a created piece takes, in the roster's words.
local function ShapeLabel( cand )
	local shape = BTV.ShapeWords( cand )
	if cand.trait and cand.trait > 0 then shape = shape .. ", " .. BTV.TraitName( cand.trait ) end
	return shape
end

-- One way to get a whole set, with the facts summed over its pieces (#468, #470).
local function PathText( block, path, picked, missing )
	local word = ( picked and "|cFFFFFF" or "|c" .. GOLD ) .. PATH_WORD[ path ] .. "|r"
	local detail
	if path == "craft" then
		local short = 0
		for _, gap in ipairs( block.gaps ) do
			if not gap.cand.facts.canCraft then short = short + 1 end
		end
		detail = "at a " .. BTV.SetLabel( block.setId ) .. " station"
		local station = block.gaps[ 1 ].cand.facts.station
		if station then detail = detail .. " in " .. station end
		detail = detail .. " (or a Grand Master station that has it)"
		local crafter = block.crafter
		if crafter then
			detail = detail .. ", on " .. ( crafter.here and "this character" or crafter.name )
			if crafter.count < #block.gaps then
				detail = detail .. string.format( " (%d of %d pieces)", crafter.count, #block.gaps )
			end
			if crafter.unread then
				detail = detail .. string.format( ", |c%spassives not read on %s yet: log in there once|r|c%s", WARN, crafter.name or "it", DIM )
			elseif ( crafter.tempers or 8 ) > 8 then
				detail = detail .. string.format( ", |c%simprovement passive not maxed there: gold costs %d tempers, not 8|r|c%s",
					WARN, crafter.tempers, DIM )
			end
		end
		if short > 0 then
			detail = detail .. string.format( ", |c%s%d piece%s no character seen so far can craft: log in once on your crafter so its passives are read|r|c%s",
				WARN, short, short == 1 and "" or "s", DIM )
		end
	elseif path == "reconstruct" then
		local cost, count, locked = 0, 0, 0
		for _, gap in ipairs( block.gaps ) do
			local facts = gap.cand.facts
			if facts.unlocked then cost, count = cost + ( facts.cost or 0 ), count + 1 else locked = locked + 1 end
		end
		detail = string.format( "%d piece%s for %s, you have %s", count, count == 1 and "" or "s",
			Crystals( cost ), Crystals( missing.balance ) )
		if locked > 0 then
			detail = detail .. string.format( ", |c%s%d not in your sticker book, see below|r|c%s", WARN, locked, DIM )
		end
	elseif path == "farm" then
		detail = block.gaps[ 1 ].cand.facts.where or "drop location unknown"
	else
		detail = "from a guild trader"
	end
	return string.format( "%s  |c%s%s|r", word, DIM, detail )
end

-- One piece: its shape, which character has the research for it under craft or
-- reconstruct, its own crystals, and what it fills.
local function PieceText( gap, picked, quality, block )
	local cand, facts = gap.cand, gap.cand.facts
	local name = GetItemQualityColor( quality ):Colorize( facts.name )
	if not picked then name = "|c" .. GOLD .. facts.name .. "|r" end
	local text = name .. "  |c" .. DIM .. ShapeLabel( cand )
	if gap.path == "craft" or gap.path == "reconstruct" then
		if facts.traitKnown == false then
			text = text .. string.format( ", |c%s%s not researched on any character|r|c%s", WARN, BTV.TraitName( cand.trait ), DIM )
		elseif gap.path == "craft" and not facts.canCraft and next( facts.tierShort or {} ) then
			local names = {}
			for _, name in pairs( facts.tierShort ) do table.insert( names, name ) end
			table.sort( names )
			text = text .. string.format( ", |c%s%s has the research but not the top material passive (CP160): auto craft stays off there. Log in once on a character that has the passives, or learn them|r|c%s",
				WARN, table.concat( names, ", " ), DIM )
		elseif gap.path == "craft" and not facts.canCraft then
			text = text .. string.format( ", |c%s%d/%d traits, no character can craft it yet|r|c%s",
				WARN, facts.known or 0, facts.traitsNeeded or 0, DIM )
		elseif gap.path == "craft" and block.crafter and not ( facts.canOn or {} )[ block.crafter.id ] then
			text = text .. string.format( ", |c%s%s can't craft this one|r|c%s, research on %s", WARN, block.crafter.name, DIM,
				facts.crafter or "this character" )
		end
	end
	if gap.path ~= block.path and facts.unlocked == false then
		text = text .. string.format( ", |c%snot in your sticker book|r|c%s, so %s it", WARN, DIM, PATH_WORD[ gap.path ]:lower() )
		if gap.path == "farm" and facts.where then text = text .. ": " .. facts.where end
	end
	if gap.path == "reconstruct" and facts.unlocked then text = text .. ", " .. Crystals( facts.cost ) end
	if gap.fills > 1 then text = text .. string.format( ", fills %d setups", gap.fills ) end
	return text .. "|r"
end

local function AltText( option )
	return string.format( "|c%sor get|r %s |c%sinstead  %s%s|r", DIM, "|c" .. GOLD .. option.cand.facts.name .. "|r", DIM,
		ShapeLabel( option.cand ), option.sheet and "  (what the sheet has on this slot)" or "" )
end

local function RenderMissing()
	local missing = Wizard.analysis.missing
	ZO_CheckButton_SetCheckState( ui.perPiece, missing.perPiece and true or false )
	ShowChoice( ui.quality, missing.quality )

	-- Flattened into uniform rows (owner, 2026-09-08): a set is a header, one radio row
	-- per way to get it, then its pieces, each a line (a radio row when it has
	-- alternatives, which follow it), then a spacer. `indent` is in pixels.
	local rows = {}
	for _, block in ipairs( missing.sets ) do
		table.insert( rows, { text = string.format( "%s  |c%s%d piece%s|r", TierHead( BTV.SetLabel( block.setId ) ),
			DIM, #block.gaps, #block.gaps == 1 and "" or "s" ) } )
		for _, path in ipairs( block.paths ) do
			table.insert( rows, { indent = 16, picked = block.path == path,
				text = PathText( block, path, block.path == path, missing ),
				onClick = function() Wizard.PickPath( block.setId, path ) end } )
		end
		for _, gap in ipairs( block.gaps ) do
			local quality = gap.quality or missing.quality
			local choice = #gap.options > 1
			table.insert( rows, { gap = gap, indent = choice and 40 or 24, picked = choice and true or nil,
				text = PieceText( gap, true, quality, block ), header = true } )
			if gap.sheet then
				table.insert( rows, { indent = 40, text = string.format(
					"|c%sThe sheet has %s on this slot. The plan moved sets between slots so you get fewer pieces. Click a row below to follow the sheet instead.|r",
					DIM, BTV.SetLabel( gap.sheet.set ) ) } )
			end
			for index = 2, #gap.options do
				table.insert( rows, { indent = 40, picked = false, text = AltText( gap.options[ index ] ),
					onClick = function() Wizard.PickMissing( gap, index ) end } )
			end
		end
		table.insert( rows, { text = "" } )
	end

	local parent = ui.missingList:GetNamedChild( "ScrollChild" ) or ui.missingList
	local y = 4
	for index, spec in ipairs( rows ) do
		local row = ui.missingRows[ index ] or BuildMissingRow( index )
		local indent = spec.indent or 0
		row:SetHidden( false )
		row.onClick = spec.onClick
		local dropdown = ui.missingQuality[ index ]
		if dropdown then dropdown:SetHidden( true ) end
		row.radio:ClearAnchors()
		row.label:ClearAnchors()
		if spec.picked ~= nil then
			row.radio:SetHidden( false )
			row.radio:SetAnchor( TOPLEFT, row, TOPLEFT, indent, 2 )
			row.radio:SetTexture( spec.picked and "/esoui/art/buttons/radiobutton_down.dds"
				or "/esoui/art/buttons/radiobutton_up.dds" )
			indent = indent + 28
		else
			row.radio:SetHidden( true )
		end
		-- The per-piece override: a dropdown on the piece's row (#470).
		local hasDropdown = spec.header and missing.perPiece
		row.label:SetAnchor( TOPLEFT, row, TOPLEFT, indent, 3 )
		row.label:SetWidth( 760 - indent - ( hasDropdown and 150 or 0 ) )
		row.label:SetText( spec.text )
		if hasDropdown then
			row.gap = spec.gap
			if not dropdown then
				dropdown = QualityBox( "BTVToolsWindowMissingRow" .. index .. "Quality", row,
					function( quality ) Wizard.SetQuality( quality, row.gap ) end )
				dropdown:SetAnchor( TOPRIGHT, row, TOPRIGHT, -8, 0 )
				ui.missingQuality[ index ] = dropdown
			end
			dropdown:SetHidden( false )
			ShowChoice( dropdown, spec.gap.quality or missing.quality )
		end
		-- Rows grow with their text, so a long drop location wraps instead of running off.
		local height = math.max( 24, ( row.label:GetTextHeight() or 0 ) + 6 )
		row:SetHeight( height )
		row:ClearAnchors()
		row:SetAnchor( TOPLEFT, parent, TOPLEFT, 0, y )
		y = y + height + 2
	end
	for index = #rows + 1, #ui.missingRows do ui.missingRows[ index ]:SetHidden( true ) end
end

local function RenderFlex()
	-- Flattened into uniform rows so the controls can be reused across payloads: a
	-- block is a header, the quoted note, then one row per option (or the open-slot
	-- explanation), then a spacer.
	local rows = {}
	for _, block in ipairs( Wizard.analysis.flex ) do
		table.insert( rows, { text = string.format( "%s  |c%sfills %d setup%s|r",
			TierHead( FlexSlotWords( block ) ), DIM, block.fills, block.fills == 1 and "" or "s" ) } )
		if block.note then
			table.insert( rows, { text = string.format( '|c%s"%s"|r', GOLD, block.note ) } )
		end
		if #block.options == 0 then
			table.insert( rows, { text = "|c" .. DIM
				.. "No options given. The slot stays open: fill it later by dragging a skill from the game's skills window onto the bar.|r" } )
		end
		for index, option in ipairs( block.options ) do
			table.insert( rows, { block = block, index = index, option = option } )
		end
		table.insert( rows, { text = "" } )
	end
	for index, spec in ipairs( rows ) do
		local row = ui.flexRows[ index ] or BuildFlexRow( index )
		row:SetHidden( false )
		row.label:ClearAnchors()
		if spec.text ~= nil then
			row.onClick = nil
			row.radio:SetHidden( true )
			row.icon:SetHidden( true )
			row.label:SetAnchor( LEFT, row, LEFT, 0, 0 )
			row.label:SetText( spec.text )
		else
			local block, option = spec.block, spec.option
			local picked = block.pick == spec.index
			row.radio:SetHidden( false )
			row.radio:SetTexture( picked and "/esoui/art/buttons/radiobutton_down.dds"
				or "/esoui/art/buttons/radiobutton_up.dds" )
			-- The skill's own art, so the options read the way the bar does; greyed
			-- along with the name when the option is not learned.
			row.icon:SetHidden( false )
			row.icon:SetTexture( GetAbilityIcon( option.id ) )
			row.icon:SetDesaturation( option.learned and 0 or 1 )
			row.label:SetAnchor( LEFT, row.icon, RIGHT, 8, 0 )
			local name = GetAbilityName( option.id )
			if option.learned then
				row.label:SetText( ( picked and "|cFFFFFF" or "|c" .. GOLD ) .. name .. "|r" )
				row.onClick = function() Wizard.PickFlex( block, spec.index ) end
			else
				-- Greyed and inert: the import never writes a skill the player does not own.
				row.label:SetText( "|c" .. DIM .. name .. "  (not learned)|r" )
				row.onClick = nil
			end
		end
	end
	for index = #rows + 1, #ui.flexRows do ui.flexRows[ index ]:SetHidden( true ) end
end

-- ---- The Skill placements step (docs/plans/2026-10-15-skill-placement-one-screen.md) ----

-- A skill's own slot on a bar: a drop on this screen or its saved slot, the newer of the
-- two, so Fill from my bars beats earlier drops and later drops beat it.
local function OwnSlot( placing, bar, key )
	local pick = placing.picks[ bar ][ key ]
	local own = BTV.svAccount.placements[ key ] and BTV.svAccount.placements[ key ][ bar ]
	if pick and not ( own and own.seq > pick.seq ) then return pick.slot, pick.seq end
	if own then return own.slot, own.seq end
end

-- Where a skill sits on a bar. A listed one with no slot of its own there follows its other
-- bar: BB follows FB until it is moved itself (owner, 2026-10-15).
local function SlotOf( placing, bar, key )
	local slot, seq = OwnSlot( placing, bar, key )
	if slot or not placing.listed[ bar ][ key ] then return slot, seq end
	return OwnSlot( placing, 1 - bar, key )
end

-- Next: every drop, and every listed skill sitting where its other bar put it, becomes a
-- saved slot for its own bar.
local function SavePlacing( placing )
	for bar = 0, 1 do
		for key, pick in pairs( placing.picks[ bar ] ) do
			local own = BTV.svAccount.placements[ key ] and BTV.svAccount.placements[ key ][ bar ]
			if not ( own and own.seq > pick.seq ) then BTV.SavePlacement( pick.id, bar, pick.slot, pick.seq ) end
		end
	end
	local saved = BTV.svAccount.placements
	for _, entry in ipairs( placing.entries ) do
		local slot, seq = SlotOf( placing, entry.bar, entry.key )
		if slot and not ( saved[ entry.key ] and saved[ entry.key ][ entry.bar ] ) then BTV.SavePlacement( entry.id, entry.bar, slot, seq ) end
	end
	placing.picks = { [ 0 ] = {}, [ 1 ] = {} }
end

-- What the boxes draw, one per skill per bar: this import's, or under /btv placements every
-- saved one, read live so Fill from my bars shows at once. Tagged like the list.
local function BoxSkills( placing )
	local skills = {}
	if placing.bars then
		for bar = 0, 1 do
			for _, skill in ipairs( placing.bars[ bar ] ) do
				table.insert( skills, { key = skill.key, id = skill.id, bar = bar, tag = placing.both[ skill.key ] and TAG[ bar ] or nil } )
			end
		end
		return skills
	end
	for key, skill in pairs( BTV.svAccount.placements ) do
		for bar = 0, 1 do
			if skill[ bar ] then
				table.insert( skills, { key = key, id = skill.id, bar = bar, tag = ( skill[ 0 ] and skill[ 1 ] ) and TAG[ bar ] or nil } )
			end
		end
	end
	return skills
end

local function TagText( tag )
	return tag and ( "  |c" .. DIM .. tag .. "|r" ) or ""
end

local function BuildPlaceRow( index )
	local parent = ui.placeList:GetNamedChild( "ScrollChild" ) or ui.placeList
	local row = SkillControl( "BTVToolsWindowPlaceRow" .. index, parent, 28 )
	row:SetDimensions( 380, 30 )
	row:SetAnchor( TOPLEFT, parent, TOPLEFT, ( ( index - 1 ) % 2 ) * 390, 4 + math.floor( ( index - 1 ) / 2 ) * 32 )
	row.label = Label( "BTVToolsWindowPlaceRow" .. index .. "Label", row )
	row.label:SetAnchor( LEFT, row, LEFT, 36, 0 )
	table.insert( ui.placeRows, row )
	return row
end

local function BuildBoxIcon( box, slot, i )
	local name = "BTVToolsWindowPlaceBox" .. slot .. "Icon" .. i
	local icon = SkillControl( name, box, 26 )
	icon:SetDimensions( 26, 26 )
	-- ponytail: 5 to a row, 6 rows, so 30 skills to a slot before they spill out; scroll the box if anyone gets there
	icon:SetAnchor( TOPLEFT, box, TOPLEFT, 6 + ( ( i - 1 ) % 5 ) * 28, 30 + math.floor( ( i - 1 ) / 5 ) * 28 )
	icon.tag = Label( name .. "Tag", icon, "ZoFontGameSmall" )
	icon.tag:SetAnchor( BOTTOMRIGHT, icon, BOTTOMRIGHT, 0, 2 )
	box.icons[ i ] = icon
	return icon
end

local function RenderPlacement()
	local placing = Wizard.placing
	local inSlot = {}
	for slot = 3, 7 do inSlot[ slot ] = {} end
	for _, skill in ipairs( BoxSkills( placing ) ) do
		local slot, seq = SlotOf( placing, skill.bar, skill.key )
		if slot then
			skill.seq = seq
			table.insert( inSlot[ slot ], skill )
		end
	end
	for slot = 3, 7 do
		local box, skills = ui.placeBoxes[ slot ], inSlot[ slot ]
		table.sort( skills, function( a, b )
			if a.seq ~= b.seq then return a.seq < b.seq end
			return a.bar < b.bar
		end )
		for i, skill in ipairs( skills ) do
			local icon = box.icons[ i ] or BuildBoxIcon( box, slot, i )
			icon:SetHidden( false )
			icon.skill, icon.from = skill, slot
			icon.art:SetTexture( GetAbilityIcon( skill.id ) )
			icon.tag:SetText( skill.tag or "" )
		end
		for i = #skills + 1, #box.icons do box.icons[ i ]:SetHidden( true ) end
		-- Two skills in one slot that share a bar in a setup of this import: only one fits.
		local tips = {}
		for i = 1, #skills do
			for j = i + 1, #skills do
				local a, b, count = skills[ i ], skills[ j ], 0
				if a.bar == b.bar then
					for _, write in ipairs( placing.writes or {} ) do
						if write[ a.bar ][ a.key ] and write[ a.bar ][ b.key ] then count = count + 1 end
					end
				end
				if count > 0 then
					table.insert( tips, string.format( "%s and %s share a %s bar in %d setup%s. The one placed last gets slot %d.",
						GetAbilityName( a.id ), GetAbilityName( b.id ), a.bar == 0 and "front" or "back",
						count, count == 1 and "" or "s", slot - 2 ) )
				end
			end
		end
		box.mark:SetHidden( #tips == 0 )
		box.mark.tip = table.concat( tips, "\n" )
	end

	for index, entry in ipairs( placing.entries ) do
		local row = ui.placeRows[ index ] or BuildPlaceRow( index )
		local placed = SlotOf( placing, entry.bar, entry.key ) ~= nil
		row:SetHidden( false )
		row.skill, row.from = entry, nil
		row:SetMouseEnabled( not placed )
		row.art:SetHidden( placed )
		row.art:SetTexture( GetAbilityIcon( entry.id ) )
		row.label:SetText( "|c" .. ( placed and GREEN or GOLD ) .. GetAbilityName( entry.id ) .. "|r" .. TagText( entry.tag ) )
	end
	for index = #placing.entries + 1, #ui.placeRows do ui.placeRows[ index ]:SetHidden( true ) end
	ui.placeSkip:SetHidden( Wizard.placementOnly == true )
	ui.placeNever:SetHidden( Wizard.placementOnly == true )
	ui.placeForget:SetHidden( not Wizard.placementOnly )
end

-- ---- The plan and Past imports (#480) ----

local function BuildListRow( index )
	local parent = ui.listPane:GetNamedChild( "ScrollChild" ) or ui.listPane
	local row = WINDOW_MANAGER:CreateControl( "BTVToolsWindowListRow" .. index, parent, CT_CONTROL )
	row:SetDimensions( 760, 24 )
	row:SetMouseEnabled( true )
	row:SetHandler( "OnMouseUp", function( self ) if self.onClick then self.onClick() end end )
	row.check = WINDOW_MANAGER:CreateControl( "BTVToolsWindowListRow" .. index .. "Check", row, CT_TEXTURE )
	row.check:SetDimensions( 20, 20 )
	row.label = Label( "BTVToolsWindowListRow" .. index .. "Label", row )
	table.insert( ui.listRows, row )
	return row
end

-- Uniform rows: `text`, an `indent` in pixels, `done` (true / false for a box, nil for
-- none) and an `onClick`.
local function RenderList( rows )
	local parent = ui.listPane:GetNamedChild( "ScrollChild" ) or ui.listPane
	local y = 4
	for index, spec in ipairs( rows ) do
		local row = ui.listRows[ index ] or BuildListRow( index )
		local indent = spec.indent or 0
		row:SetHidden( false )
		row.onClick = spec.onClick
		row.check:ClearAnchors()
		row.label:ClearAnchors()
		if spec.done ~= nil then
			row.check:SetHidden( false )
			row.check:SetAnchor( TOPLEFT, row, TOPLEFT, indent, 2 )
			row.check:SetTexture( spec.done and "/esoui/art/buttons/checkbox_checked.dds"
				or "/esoui/art/buttons/checkbox_unchecked.dds" )
			indent = indent + 28
		else
			row.check:SetHidden( true )
		end
		row.label:SetAnchor( TOPLEFT, row, TOPLEFT, indent, 3 )
		row.label:SetWidth( 760 - indent )
		row.label:SetText( spec.text )
		local height = math.max( 24, ( row.label:GetTextHeight() or 0 ) + 6 )
		row:SetHeight( height )
		row:ClearAnchors()
		row:SetAnchor( TOPLEFT, parent, TOPLEFT, 0, y )
		y = y + height + 2
	end
	for index = #rows + 1, #ui.listRows do ui.listRows[ index ]:SetHidden( true ) end
end

local Render
-- One line of the checklist: the piece by quality where it has a link, a piece still to
-- make in the quality the player picked (owner, 2026-09-15: so they know what to expect),
-- dimmed once done, "x2" when a row wants two of it and "1 of 2 so far" on the way.
local function PlanLineText( line )
	local name
	if line.link then
		name = ItemLabel( line.link )
	elseif line.pick then
		name = GetItemQualityColor( line.pick.quality or ITEM_DISPLAY_QUALITY_LEGENDARY ):Colorize( line.name )
	else
		name = "|cFFFFFF" .. line.name .. "|r"
	end
	if line.done then name = "|c" .. DIM .. line.name .. "|r" end
	if line.count > 1 then name = name .. " x" .. line.count end
	local detail = line.detail
	if not line.done and line.have > 0 then
		detail = string.format( "%d of %d so far%s", line.have, line.count, detail and ( ", " .. detail ) or "" )
	end
	if detail then name = name .. "  |c" .. DIM .. detail .. "|r" end
	return name
end

-- A craft or reconstruct row still to make is a click that queues it (#482), the same
-- plain-row idiom as the toggles above it; a craft row without LibLazyCrafting says what
-- auto-craft needs instead. Returns the row's tag and whether it takes the click.
local function QueueTag( group, line )
	if line.done or not line.id or ( group.kind ~= "craft" and group.kind ~= "reconstruct" ) then return nil end
	if group.kind == "craft" and not LibLazyCrafting then return "auto-craft needs LibLazyCrafting", false end
	-- Read live, so the same plan opens up on a character that has the passives. The row
	-- still queues: the queue is spent by whichever character can craft it.
	local block = group.kind == "craft" and line.pick and BTV.PickBlock( line.pick )
	if block then return ( line.queued and "queued, " or "click to queue, " ) .. "no auto craft here: " .. block, true end
	return line.queued and "queued" or "click to queue", true
end

-- Hide done and the folded "Already in your bags" group are plain list rows: one click
-- each (owner hand test 2026-09-09).
local function RenderPlan()
	local plan = Wizard.plan
	local hide = BTV.svAccount.hideDone == true
	local rows = { { done = hide, text = "|c" .. DIM .. "Hide ticked lines|r",
		onClick = function() BTV.svAccount.hideDone = not hide Render() end } }
	-- Any quality is fine: on the record, so it is this import's call, and a live check
	-- follows so the boxes tick at once.
	local record = BTV.GetRecord()
	if record then
		table.insert( rows, { done = plan.anyQuality, text = "|c" .. DIM .. "Any quality is fine: tick made pieces before they are gold|r",
			onClick = function()
				record.anyQuality = not plan.anyQuality
				if not BTV.CheckPlan() then Render() end
			end } )
	end
	-- Auto deposit/withdraw (#481): the setting, toggled here too, so a cautious player
	-- turns it on where the gear moves.
	table.insert( rows, { done = BTV.Setting( "autoDeposit" ) == true,
		text = "|c" .. DIM .. "Auto deposit/withdraw: move this plan's gear the moment a bank or coffer opens|r",
		onClick = function() BTV.SetSetting( "autoDeposit", not BTV.Setting( "autoDeposit" ) ) Render() end } )
	-- Auto craft and reconstruct (#482): the master switch for the station runs, the same
	-- setting the settings panel shows.
	table.insert( rows, { done = BTV.Setting( "autoCraft" ) == true,
		text = "|c" .. DIM .. "Auto craft and reconstruct: run queued lines the moment a station opens|r",
		onClick = function() BTV.SetSetting( "autoCraft", not BTV.Setting( "autoCraft" ) ) Render() end } )
	for _, group in ipairs( plan.groups ) do
		local folded = group.kind == "have" and not Wizard.showHave
		if not ( hide and group.done ) then
			local head = TierHead( group.head )
			local onClick
			if group.kind == "have" then
				head = string.format( "%s  |c%s%d, click to %s|r", head, DIM, #group.lines, folded and "show" or "hide" )
				onClick = function() Wizard.showHave = not Wizard.showHave Render() end
			end
			-- Queue all (owner, 2026-09-15): the head of a craft or reconstruct group queues
			-- every line still to make in one click, and unqueues them all once they are.
			local queueable, unqueued = 0, 0
			for _, line in ipairs( group.lines ) do
				local _, clickable = QueueTag( group, line )
				if clickable then
					queueable = queueable + 1
					if not line.queued then unqueued = unqueued + 1 end
				end
			end
			if queueable > 0 then
				head = string.format( "%s  |c%sclick to %s all|r", head, DIM, unqueued > 0 and "queue" or "unqueue" )
				onClick = function()
					for _, line in ipairs( group.lines ) do
						local _, clickable = QueueTag( group, line )
						if clickable then BTV.ToggleQueue( line.id, unqueued > 0 ) end
					end
					if not BTV.CheckPlan() then Render() end
				end
			end
			table.insert( rows, { text = head, onClick = onClick } )
			for _, line in ipairs( group.lines ) do
				if not folded and not ( hide and line.done ) then
					local tag, clickable = QueueTag( group, line )
					local text = PlanLineText( line )
					if tag then text = text .. "  |c" .. ( ( line.queued or tag:find( "no auto craft", 1, true ) ) and WARN or DIM ) .. tag .. "|r" end
					local onLine = clickable and function()
						BTV.ToggleQueue( line.id )
						if not BTV.CheckPlan() then Render() end
					end or nil
					-- A glyph row the player does not care about is skipped by hand (owner,
					-- 2026-09-19). Its own group, so it never meets the queue click above.
					if group.kind == "glyph" and ( line.skipGlyph or not line.done ) then
						text = text .. "  |c" .. DIM .. ( line.skipGlyph and "skipped, click to undo" or "click to skip" ) .. "|r"
						onLine = function()
							BTV.ToggleGlyphSkip( line.id )
							if not BTV.CheckPlan() then Render() end
						end
					end
					table.insert( rows, { indent = 16, done = line.done, text = text, onClick = onLine } )
				end
			end
			table.insert( rows, { text = "" } )
		end
	end
	if plan.total == 0 then
		table.insert( rows, { text = "|c" .. DIM .. "Nothing to do: every piece was already in your bags.|r" } )
	end
	RenderList( rows )
end

local function When( ts )
	if ts and GetDateStringFromTimestamp then return GetDateStringFromTimestamp( ts ) end
	return tostring( ts or "?" )
end

local function RenderHistory()
	local rows = {}
	for index, record in ipairs( BTV.svAccount.history ) do
		local when = record.doneAt and ( "done " .. When( record.doneAt ) ) or ( "started " .. When( record.startedAt ) )
		table.insert( rows, { indent = 16, onClick = function() Wizard.Reactivate( index ) end,
			text = string.format( "|c%s%s|r  |c%s%s|r", GOLD, record.pageName or "?", DIM, when ) } )
	end
	if #rows == 0 then table.insert( rows, { text = "|c" .. DIM .. "No past imports yet.|r" } ) end
	RenderList( rows )
end

-- Whether Edit picks has anything to open: picks exist, and this is the character the
-- page was written for (its bag ids are what the write holds).
local function CanEdit()
	local record = BTV.GetRecord()
	return record ~= nil and record.characterId == GetCurrentCharacterId() and Wizard.plan ~= nil
		and ( #( record.missing or {} ) > 0 or next( record.flex or {} ) ~= nil )
end

-- While the match or a re-plan runs (Busy), the summary line says how far it got.
local function BusyLine()
	return string.format( "|c%sMatching your gear... %d%%|r", GOLD, math.floor( ( Wizard.busy or 0 ) * 100 ) )
end

Render = function()
	local step = Wizard.step
	if step == "placement" then
		Wizard.placing = Wizard.placing or NewPlacing()
	else
		Wizard.Hold( nil )
	end
	ui.steps:SetText( step == "history" and TierHead( "Past imports" ) or StepsLine() )
	ui.pastePane:SetHidden( step ~= "paste" )
	ui.reviewPane:SetHidden( step ~= "review" )
	ui.missingPane:SetHidden( step ~= "missing" )
	ui.flexPane:SetHidden( step ~= "flex" )
	ui.placementPane:SetHidden( step ~= "placement" )
	ui.listPane:SetHidden( step ~= "plan" and step ~= "history" )
	ui.prompt:SetHidden( not Wizard.prompt )
	ui.back:SetHidden( step == nil or ( step == "paste" and #BTV.svAccount.history == 0 ) or ( step == "plan" and not CanEdit() )
		or ( step == "placement" and Wizard.placementOnly ) )
	ui.next:SetHidden( step == "history" )
	ui.back:SetText( step == "paste" and "Past imports" or ( step == "plan" and "Edit picks" or "Back" ) )
	Wizard.moves = step == "plan" and BTV.Moves( Wizard.plan ) or nil
	local moving = Wizard.moves ~= nil and #Wizard.moves.items > 0
	ui.move:SetHidden( not moving )

	if step == "paste" then
		ZO_CheckButton_SetCheckState( ui.exactTraits, BTV.Setting( "exactTraits" ) and true or false )
		ui.sub:SetText( "|c" .. DIM .. "Paste your roster export from the share page.|r" )
		ui.next:SetText( "Next: review" )
		ui.summary:SetText( "" )
		Wizard.OnPasteChanged()
		ui.pasteError:SetText( Wizard.error or "" )
	elseif step == "plan" then
		local plan = Wizard.plan
		ui.sub:SetText( string.format( "|c%s%s, started %s. Boxes tick themselves as pieces reach your bags.|r",
			DIM, plan.pageName, When( plan.startedAt ) ) )
		ui.next:SetText( "New import" )
		local summary = plan.done and "|c" .. DONE .. "Every box ticked: this import is done.|r"
			or string.format( "|c%s%d of %d to go|r", WARN, plan.left, plan.total )
		if moving then
			local moves = Wizard.moves
			local word = moves.dir == "fetch" and "Fetch" or "Deposit"
			ui.move:SetText( string.format( "%s %d", word, #moves.items ) )
			summary = string.format( "%s  |c%s%s %d %s %s|r", summary, WARN, word, #moves.items,
				moves.dir == "fetch" and "from" or "in", moves.place )
		end
		ui.summary:SetText( summary )
		RenderPlan()
	elseif step == "history" then
		ui.sub:SetText( "|c" .. DIM .. "Click a past import to make it active again.|r" )
		ui.summary:SetText( "" )
		RenderHistory()
	elseif step == "missing" then
		local analysis = Wizard.analysis
		ui.sub:SetText( string.format(
			"|c%sPick how to get each set: craft, reconstruct, farm or buy. Planning only, nothing is spent yet.|r", DIM ) )
		ui.next:SetText( NextLabel() )
		local missing = analysis.missing
		local summary = string.format( "|c%s%d piece%s to get", DIM, #missing.gaps, #missing.gaps == 1 and "" or "s" )
		if missing.crystals > 0 then
			summary = summary .. string.format( ", %s to reconstruct, you have %s",
				Crystals( missing.crystals ), Crystals( missing.balance ) )
		end
		ui.summary:SetText( summary .. "|r" )
		RenderMissing()
	elseif step == "flex" then
		local analysis = Wizard.analysis
		ui.sub:SetText( string.format( "|c%sPick each flex skill. One pick fills every setup it appears in.|r", DIM ) )
		ui.next:SetText( NextLabel() )
		ui.summary:SetText( string.format( "|c%s%s|r", DIM, analysis.pageName ) )
		RenderFlex()
	elseif step == "placement" then
		local placing = Wizard.placing
		if Wizard.placementOnly then
			ui.sub:SetText( string.format( "|c%sEvery skill you've saved. Drag one to another slot to move it. FB is front bar, BB is back bar.|r", DIM ) )
			ui.next:SetText( "Save" )
			local count = 0
			for _ in pairs( BTV.svAccount.placements ) do count = count + 1 end
			ui.summary:SetText( "|c" .. DIM .. ( count > 0 and string.format( "%d skill%s saved", count, count == 1 and "" or "s" )
				or "Nothing saved yet. Press Fill from my bars, or place skills on your next import." ) .. "|r" )
		else
			ui.sub:SetText( string.format( "|c%sDrag each skill onto the slot you want it in, or click it and then click a slot. FB is front bar, BB is back bar.|r", DIM ) )
			ui.next:SetText( NextLabel() )
			local left = 0
			for _, entry in ipairs( placing.entries ) do
				if not SlotOf( placing, entry.bar, entry.key ) then left = left + 1 end
			end
			ui.summary:SetText( "|c" .. DIM .. ( left > 0
				and string.format( "%d skill%s still to place. Unplaced skills keep the leader's order.", left, left == 1 and "" or "s" )
				or "Every skill has a slot." ) .. "|r" )
		end
		RenderPlacement()
	elseif step == "review" then
		local analysis = Wizard.analysis
		local summary = analysis.summary
		ui.sub:SetText( string.format( "|c%s%s|r", DIM, analysis.pageName ) )
		ui.next:SetText( NextLabel() )
		ui.summary:SetText( string.format(
			"|cFFFFFF%d|r of |cFFFFFF%d|r pieces placed  |c%s%d to fetch|r  |c%s%d unplaced|r  |c%s%d off trait|r",
			summary.placed, summary.total, WARN, summary.toFetch, ERR, summary.unplaced, DIM, summary.traitCount ) )
		RenderRail()
		local all = Wizard.selected == "all"
		ui.grid:SetHidden( all )
		ui.placedToggle:SetHidden( not all )
		ui.placedToggle:SetText( Wizard.showPlaced and "Hide placed" or "Show placed" )
		if all then
			ui.detailText:SetText( AllText() )
			ui.detailText:ClearAnchors()
			ui.detailText:SetAnchor( TOPLEFT, ui.detail:GetNamedChild( "ScrollChild" ) or ui.detail, TOPLEFT, 0, 4 )
		else
			local review = analysis.entries[ Wizard.selected ]
			for index, slotId in ipairs( DISPLAY_SLOTS ) do
				RenderCell( ui.cells[ index ], slotId, review )
			end
			ui.detailText:SetText( EntryText( review ) )
			ui.detailText:ClearAnchors()
			ui.detailText:SetAnchor( TOPLEFT, ui.grid, BOTTOMLEFT, 0, 10 )
		end
	end

	if Wizard.prompt == "replace" then
		-- Writing a different page while the active import still has unticked boxes (#480).
		local record, left = BTV.GetRecord(), Wizard.replaceLeft or 0
		ui.prompt.title:SetText( "IMPORT IN PROGRESS" )
		ui.prompt.body:SetText( string.format(
			"|cFFFFFF%s|r still has %d unticked box%s.\n\n|c%sReplace moves that plan to Past imports, where you can pick it up again. The page itself stays in Wizard's Wardrobe.|r",
			record and record.pageName or "?", left, left == 1 and "" or "es", DIM ) )
		ui.prompt.overwrite:SetText( "Replace" )
		ui.prompt.create:SetHidden( true )
		ui.prompt.check:SetHidden( true )
		ui.prompt.checkLabel:SetHidden( true )
	elseif Wizard.prompt == "forget" then
		ui.prompt.title:SetText( "FORGET ALL SKILL PLACEMENTS" )
		ui.prompt.body:SetText( string.format( "Every saved slot, front bar and back bar, is cleared.\n\n|c%sSetups already written stay as they are.|r", DIM ) )
		ui.prompt.overwrite:SetText( "Forget all" )
		ui.prompt.create:SetHidden( true )
		ui.prompt.check:SetHidden( true )
		ui.prompt.checkLabel:SetHidden( true )
	elseif Wizard.prompt then
		local analysis = Wizard.analysis
		-- A name match, so no claim about who made the page: a hand-made page under this
		-- exact name would reach the same prompt, and Overwrite would replace it too. Under
		-- Edit picks the page IS ours and reads hand-edited, so there is no don't-ask-again
		-- to offer (#480).
		ui.prompt.title:SetText( Wizard.editing and "PAGE WAS EDITED BY HAND" or "PAGE ALREADY EXISTS" )
		ui.prompt.body:SetText( string.format(
			"A page named |cFFFFFF%s|r is already in Wizard's Wardrobe%s.\n\n|c%sOverwrite replaces that page. Create keeps it and writes |cFFFFFF%s|r|c%s instead. Other pages are never touched.|r",
			analysis.pageName, Wizard.editing and " and no longer reads as BTV wrote it" or "", DIM, Wizard.createName, DIM ) )
		ui.prompt.overwrite:SetText( "Overwrite" )
		ui.prompt.create:SetHidden( false )
		ui.prompt.check:SetHidden( Wizard.editing == true )
		ui.prompt.checkLabel:SetHidden( Wizard.editing == true )
		ui.prompt.check:SetTexture( Wizard.dontAsk
			and "/esoui/art/buttons/checkbox_checked.dds" or "/esoui/art/buttons/checkbox_unchecked.dds" )
	end
	-- Next and Back wait for the work in progress (Busy).
	ui.next:SetEnabled( not Wizard.busy )
	ui.back:SetEnabled( not Wizard.busy )
	if Wizard.busy then ui.summary:SetText( BusyLine() ) end
	RenderTip()
end

-- The match and every re-plan run a slice per frame (BTV.RunSliced): in one go, a big
-- roster held the game long enough for the server to drop the player (error 303,
-- 2026-10-15). `Wizard.busy` is how far it got, nil when nothing runs.
local function Busy( work, done )
	Wizard.busy = 0
	Render()
	BTV.RunSliced( work, function( progress )
		Wizard.busy = progress
		ui.summary:SetText( BusyLine() )
	end, function( ... )
		Wizard.busy = nil
		done( ... )
	end )
end

-- -------------------------------------------------------------------- wizard

-- The first page name not yet taken: "<name> 2", "<name> 3", ...
local function FreeName( zone, name )
	for n = 2, 99 do
		local candidate = name .. " " .. n
		if not BTV.FindPage( zone, candidate ) then return candidate end
	end
	return name .. " " .. GetTimeStamp()
end

local function Show()
	Render()
	if ui.window:IsHidden() then
		ui.window:SetHidden( false )
		-- The cursor comes up with the window, so /btv from chat is clickable at once.
		SetGameCameraUIMode( true )
		PlaySound( SOUNDS.DEFAULT_WINDOW_OPEN )
	end
end

-- A fresh import, at Paste. "New import" on the plan lands here too; the active record
-- stays until the write replaces it (#480).
function Wizard.Open()
	BuildWindow()
	Wizard.step = "paste"
	Wizard.analysis, Wizard.error, Wizard.prompt, Wizard.plan = nil, nil, nil, nil
	Wizard.editing, Wizard.warned = false, false
	Wizard.placementOnly, Wizard.placing = false, nil
	Wizard.selected, Wizard.showPlaced, Wizard.dontAsk = "all", false, false
	Wizard.zoneTag = "GEN"
	Wizard.parts = nil
	-- A match still running from before is dropped, not finished into the new import.
	if Wizard.busy then BTV.CancelSliced() Wizard.busy = nil end
	ui.paste:SetText( "" )
	Show()
end

-- The plan for the active record (#480), built fresh; `plan` is the one a live check
-- just built when there is one.
function Wizard.OpenPlan( plan )
	BuildWindow()
	local record = BTV.GetRecord()
	if not plan and record then
		local why
		plan, why = BTV.BuildPlan( record )
		if why then d( "|c7B68EE[BTV]|r " .. why ) end
	end
	if not plan then
		Wizard.Open()
		return
	end
	Wizard.plan, Wizard.analysis = plan, nil
	Wizard.step, Wizard.prompt, Wizard.editing = "plan", nil, false
	Wizard.placementOnly, Wizard.placing = false, nil
	Show()
end

function Wizard.OpenHistory()
	BuildWindow()
	Wizard.step, Wizard.prompt = "history", nil
	Show()
end

-- A past import made active again (#472): its plan opens, boxes ticked as things stand.
function Wizard.Reactivate( index )
	if BTV.Reactivate( index ) then Wizard.OpenPlan() end
end

-- Edit picks (#480): straight to Missing gear or Flex on the record's own payload, then
-- Write, then the plan. The record is matched again here, the one place that still
-- costs a full match, so the picks shown are the ones the record holds.
function Wizard.EditPicks()
	if not CanEdit() or Wizard.busy then return end
	local record = BTV.GetRecord()
	Busy( function() return BTV.RestoreAnalysis( record ) end, function( analysis, why )
		if not analysis then
			d( "|c7B68EE[BTV]|r " .. why )
			Render()
			return
		end
		Wizard.analysis = analysis
		Wizard.analysis.editing = true
		Wizard.editing, Wizard.warned, Wizard.dontAsk = true, false, false
		Wizard.placementOnly, Wizard.placing = false, nil
		Wizard.step = Steps()[ 1 ]
		Render()
		PlaySound( SOUNDS.TABLET_PAGE_TURN )
	end )
end

function Wizard.Close()
	if Wizard.busy then BTV.CancelSliced() Wizard.busy = nil end
	ui.window:SetHidden( true )
	Wizard.autoOpened = false
	-- Its own top-level now, so it no longer hides with its former parent.
	ui.prompt:SetHidden( true )
	ui.tip:SetHidden( true )
	Wizard.Hold( nil )
	Wizard.step, Wizard.prompt, Wizard.tips = nil, nil, nil
	PlaySound( SOUNDS.DEFAULT_WINDOW_CLOSE )
end

-- What the paste is: the box, or the joined parts once every part is in. A roster too
-- long for the game's paste box (about 29,900 characters) comes from the site as parts
-- tagged "BTV:k/N:", pasted one after the other. The second return is the first part
-- still missing.
function Wizard.PasteText()
	local parts = Wizard.parts
	if not parts then return ui.paste:GetText() end
	for k = 1, parts.n do
		if not parts[ k ] then return nil, k end
	end
	return table.concat( parts, "", 1, parts.n )
end

-- The target page name and the re-paste-replaces reminder, live as the box fills (#477).
function Wizard.OnPasteChanged()
	local box = ui.paste:GetText()
	local k, n, chunk = box:match( "^BTV:(%d+)/(%d+):(.*)$" )
	k, n = tonumber( k ), tonumber( n )
	-- A real split is a handful of parts; a garbage tag must not set up millions to count.
	if k and k >= 1 and k <= n and n <= 50 then
		-- A part from another split (another N) starts over; the same part twice replaces it.
		if not Wizard.parts or Wizard.parts.n ~= n then Wizard.parts = { n = n } end
		Wizard.parts[ k ] = chunk
		ui.paste:SetText( "" )
	elseif box ~= "" then
		-- Anything else pasted is a whole roster of its own.
		Wizard.parts = nil
	end

	local text, missing = Wizard.PasteText()
	local pageName = text and BTV.PeekPageName( text )
	if missing then
		local held = 0
		for i = 1, Wizard.parts.n do if Wizard.parts[ i ] then held = held + 1 end end
		ui.pageLine:SetText( string.format( "|c%s%d of %d parts received.|r Paste part %d.", GOLD, held, Wizard.parts.n, missing ) )
	elseif pageName then
		ui.pageLine:SetText( string.format( "One page per player: |c%s%s|r. Pasting again replaces it.", GOLD, pageName ) )
	else
		ui.pageLine:SetText( "|c" .. DIM .. "One page per player, named BTV <roster> <you>. Pasting again replaces it.|r" )
	end
	local needsZone = pageName and BTV.PeekNeedsZone( text ) or false
	ui.zoneLine:SetHidden( not needsZone )
	ui.zone:SetHidden( not needsZone )
	if needsZone then ShowChoice( ui.zone, Wizard.zoneTag ) end
end

function Wizard.Next()
	if Wizard.step ~= "paste" or Wizard.busy then return end
	local text, missing = Wizard.PasteText()
	if missing then
		Wizard.error = string.format( "|cFF7070paste part %d of %d first.|r", missing, Wizard.parts.n )
		Render()
		return
	end
	local zoneTag = Wizard.zoneTag
	Busy( function() return BTV.Analyze( text, zoneTag ) end, function( analysis, why )
		if not analysis then
			Wizard.error = why
			Render()
			return
		end
		Wizard.analysis, Wizard.error = analysis, nil
		Wizard.step, Wizard.selected = "review", "all"
		Render()
		PlaySound( SOUNDS.TABLET_PAGE_TURN )
	end )
end

-- Back and Next walk Steps() (#479): the optional steps only exist when they have
-- something to ask, and the last step's Next always writes.
function Wizard.Back()
	if Wizard.busy then return end
	local step = Wizard.step
	if step == "paste" then
		if #BTV.svAccount.history > 0 then Wizard.OpenHistory() end
		return
	elseif step == "history" then
		Wizard.Open()
		return
	elseif step == "plan" then
		Wizard.EditPicks()
		return
	end
	local steps = Steps()
	local index = StepIndex( steps, step )
	if step == nil then return end
	-- Leaving the step backwards: it is worked out afresh next time.
	Wizard.placing = nil
	if index <= 1 then
		-- Edit picks starts past Paste and Review: Back from its first step is the plan.
		if Wizard.editing then Wizard.OpenPlan( Wizard.plan ) end
		return
	end
	Wizard.step = steps[ index - 1 ]
	Render()
end

function Wizard.Continue()
	if Wizard.busy then return end
	if Wizard.step == "paste" then
		Wizard.Next()
		return
	elseif Wizard.step == "plan" then
		Wizard.Open()
		return
	elseif Wizard.step == "history" or Wizard.step == nil then
		return
	elseif Wizard.step == "placement" then
		-- Next saves, then writes, or under /btv placements closes.
		SavePlacing( Wizard.placing )
		if Wizard.placementOnly then
			Wizard.Close()
			return
		end
	end
	local steps = Steps()
	local following = steps[ StepIndex( steps, Wizard.step ) + 1 ]
	if following == nil or following == "write" then
		Wizard.Write()
		return
	end
	Wizard.step = following
	Render()
	PlaySound( SOUNDS.TABLET_PAGE_TURN )
end

function Wizard.PickFlex( block, index )
	local option = block.options[ index ]
	if not option or not option.learned then return end
	block.pick = index
	Render()
end

-- ---- The Skill placements step's controls ----

-- `/btv placements`: the same screen over every saved skill, asking about none.
function Wizard.OpenPlacements()
	BuildWindow()
	Wizard.analysis, Wizard.plan, Wizard.prompt, Wizard.editing = nil, nil, nil, false
	Wizard.placementOnly, Wizard.placing = true, nil
	Wizard.step = "placement"
	Show()
end

-- The skill on the mouse ({ key, id, bar }), or none; `from` is the slot it was lifted from.
function Wizard.Hold( skill, from )
	Wizard.held = skill and { key = skill.key, id = skill.id, bar = skill.bar, from = from } or nil
	if not ui then return end
	ui.drag:SetHidden( Wizard.held == nil )
	if skill then ui.drag.art:SetTexture( GetAbilityIcon( skill.id ) ) end
end

-- The held skill dropped in a slot (3..7) of its own bar. Saved on Next.
function Wizard.Place( slot )
	local held, placing = Wizard.held, Wizard.placing
	Wizard.Hold( nil )
	if not held or not placing then return end
	placing.picks[ held.bar ][ held.key ] = { slot = slot, seq = BTV.NextPlacementSeq(), id = held.id }
	Render()
end

function Wizard.FillFromBars()
	BTV.RememberBars()
	Render()
end

-- Write with nothing saved from this step: skills with no slot keep the leader's order.
function Wizard.SkipPlacements()
	Wizard.Hold( nil )
	Wizard.Write()
end

function Wizard.NeverAsk()
	BTV.SetSetting( "usePlacements", false )
	Wizard.SkipPlacements()
end

function Wizard.AskForget()
	Wizard.prompt = "forget"
	Render()
end

-- The Missing gear step's controls (#479). A pick re-plans with every other pick kept,
-- so the plan can never be illegal; quality is display only until the queues.
function Wizard.PickMissing( gap, index )
	if Wizard.busy then return end
	Busy( function() BTV.PickMissing( Wizard.analysis, gap, index ) end, function( _, why )
		if why then d( "|c7B68EE[BTV]|r " .. why ) end
		Render()
	end )
end

function Wizard.PickPath( setId, path )
	BTV.PickPath( Wizard.analysis, setId, path )
	Render()
end

function Wizard.SetQuality( quality, gap )
	if gap then
		gap.quality = quality
	else
		Wizard.analysis.missing.quality = quality
	end
	Render()
end

function Wizard.SetPerPiece( on )
	local missing = Wizard.analysis and Wizard.analysis.missing
	if not missing or ( missing.perPiece or false ) == on then return end
	missing.perPiece = on
	if not on then
		for _, gap in ipairs( missing.gaps ) do gap.quality = nil end
	end
	Render()
end

function Wizard.TogglePerPiece()
	Wizard.SetPerPiece( not ( Wizard.analysis.missing.perPiece or false ) )
end

function Wizard.SetExactTraits( on )
	if BTV.Setting( "exactTraits" ) == on then return end
	BTV.SetSetting( "exactTraits", on )
end

function Wizard.Select( key )
	Wizard.selected = key
	Render()
end

function Wizard.TogglePlaced()
	Wizard.showPlaced = not Wizard.showPlaced
	Render()
end

-- "Got it" / "Next" on a Step tip.
function Wizard.NextTip()
	table.remove( Wizard.tips, 1 )
	if #Wizard.tips == 0 then Wizard.tips = nil end
	Render()
end

-- The "?": every tip this screen has, seen or not.
function Wizard.ReplayTips()
	if Wizard.prompt then return end
	local keys = ScreenTips( true )
	if #keys == 0 then return end
	Wizard.tips, Wizard.tipStep = keys, Wizard.step
	Render()
end

function Wizard.ToggleDontAsk()
	Wizard.dontAsk = not Wizard.dontAsk
	Render()
end

-- Write, or ask first. Two gates (#480), each once: a DIFFERENT page replacing an import
-- that still has unticked boxes warns; then a page that already exists prompts
-- overwrite-or-create unless autoOverwrite is on, or this is Edit picks and the page
-- still reads exactly as the record wrote it (a silent rewrite eats nothing). Don't-ask-again turns on the
-- autoOverwrite setting, the same switch the settings panel shows (#467, #477).
function Wizard.Write()
	local step = Wizard.step
	if step == nil or step == "paste" or step == "plan" or step == "history" or Wizard.prompt then return end
	local analysis = Wizard.analysis
	local record = BTV.GetRecord()
	if record and not Wizard.editing and not Wizard.warned
		and ( record.pageName ~= analysis.pageName or record.zoneTag ~= analysis.zone.tag ) then
		Wizard.warned = true
		local plan = BTV.BuildPlan( record )
		if plan and not plan.done then
			Wizard.prompt, Wizard.replaceLeft = "replace", plan.left
			Render()
			return
		end
	end
	if BTV.FindPage( analysis.zone, analysis.pageName ) and not BTV.Setting( "autoOverwrite" )
		and not ( Wizard.editing and BTV.PageMatchesRecord( analysis.zone, analysis.pageName ) ) then
		Wizard.prompt = "overwrite"
		Wizard.dontAsk = false
		Wizard.createName = FreeName( analysis.zone, analysis.pageName )
		Render()
		return
	end
	Wizard.Commit( analysis.pageName )
end

function Wizard.Resolve( choice, dontAskAgain )
	local kind = Wizard.prompt
	if not kind then return end
	Wizard.prompt = nil
	-- Hidden now, not at the next Render: the prompt's dim layer swallows every click, so
	-- an error inside the write must not leave it up (owner hand test 2026-09-09).
	ui.prompt:SetHidden( true )
	if choice == "cancel" then
		Render()
		return
	end
	if kind == "forget" then
		BTV.svAccount.placements = {}
		Wizard.placing = nil
		Render()
		return
	end
	if kind == "replace" then
		-- Warned once; Write runs its second gate now.
		Wizard.Write()
		return
	end
	if dontAskAgain and not Wizard.editing then BTV.SetSetting( "autoOverwrite", true ) end
	-- Write always sets createName before raising the prompt.
	Wizard.Commit( choice == "create" and Wizard.createName or Wizard.analysis.pageName )
end

-- The wizard ends in the plan (#480): the record the write just saved, read back.
function Wizard.Commit( pageName )
	local analysis = Wizard.analysis
	analysis.pageName = pageName
	-- Always confirmed: the wizard has already asked its own richer question.
	BTV.WriteAnalysis( analysis, true )
	PlaySound( SOUNDS.DIALOG_ACCEPT )
	Wizard.OpenPlan()
end

-- `/btv` bare and `/btv missing` land here (#473, #480): the plan while an import is in
-- progress, Paste otherwise.
-- `auto` marks an opening the bank or coffer did (#481), so the container shutting can
-- close it again; a window the player already had open is left theirs.
function BTV.OpenWindow( view, auto )
	local wasHidden = ui == nil or ui.window:IsHidden()
	if view == "plan" and BTV.GetRecord() then
		Wizard.OpenPlan()
	elseif view == "placements" then
		Wizard.OpenPlacements()
	else
		Wizard.Open()
	end
	Wizard.autoOpened = auto == true and wasHidden
end

function BTV.OnContainerClosed()
	if Wizard.autoOpened and ui and not ui.window:IsHidden() then Wizard.Close() end
end

-- A setting flipped in the settings panel redraws a plan that is on screen, so its rows
-- agree with the panel (owner, 2026-09-15).
function BTV.OnSettingChanged()
	if Wizard.step == "plan" and ui and not ui.window:IsHidden() then Render() end
end

-- A live check while the plan is on screen redraws it; once the record has finished the
-- last plan stays up, every box ticked (#480).
function BTV.OnPlanChanged( plan )
	if Wizard.step ~= "plan" or not ui or ui.window:IsHidden() then return end
	Wizard.plan = plan
	Render()
end
