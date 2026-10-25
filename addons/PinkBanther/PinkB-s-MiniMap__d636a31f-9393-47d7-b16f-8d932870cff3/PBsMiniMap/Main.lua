-- PB's MiniMap
-- Author: PinkBanther
--
-- Inspired by "Votan's Minimap" by votan (https://www.esoui.com/downloads/info1399-VotansMinimap.html),
-- with thanks. The idea -- reuse the game's own world map as a minimap rather than drawing a
-- second one -- is votan's. This add-on started from that code and has since been rewritten;
-- a few small pieces still trace back to it.
--
-- Written for console (PS5/Xbox Series), where all add-ons share a 100MB memory pool. The
-- original's InitMiniMap layer exhausts that pool as soon as the standard map is zoomed out to
-- all of Tamriel; that layer is not part of this add-on. Instead the game's own map window is
-- parked on the HUD at a chosen size and position, and handed straight back when the full map
-- is opened.

if PBS_MINIMAP then
	return
end

local addon = {
	name = "PBsMiniMap"
}

-- Display name is a Lua constant, the version comes from the manifest.
--
-- The name is NOT taken from the manifest "## Title" line: reading it back produced a mangled
-- heading in the settings panel (the "PB's " prefix was lost), so the exact string is pinned
-- here where nothing else can rewrite it. The version is still read from the manifest, so a
-- release only means editing "## Title" and "## Version" there -- no Lua change.
--
--   addon.baseTitle  "PB's MiniMap"        -> sub-panel headings
--   addon.version    "1.0.3"               -> version field in the settings panel
--   addon.title      "PB's MiniMap 1.0.3"  -> settings panel heading
-- Typographic apostrophe (U+2019), not ASCII '.
--
-- With the ASCII one the settings panel rendered the name as "MINIMAP 1.4.2": the "PB's "
-- prefix was being eaten somewhere in the settings library's string handling. U+2019 is not
-- a quoting character to any of that, and it is what was asked for in the first place.
local DISPLAY_NAME = "PB’s MiniMap"
local AUTHOR = "PinkBanther"

local function ReadManifestVersion()
	local manager = GetAddOnManager and GetAddOnManager()
	if not manager then
		return ""
	end
	for index = 1, manager:GetNumAddOns() do
		local name, title = manager:GetAddOnInfo(index)
		if name == addon.name and title then
			-- Strip ESO's colour markup before reading the version.
			--
			-- "## Title:" accepts |cRRGGBB ... |r, and a title coloured as a whole ends in |r
			-- rather than in the version, so an anchored match would find nothing and the
			-- version would silently disappear from the settings panel.
			local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
			-- Trailing "1", "1.0", "1.0.2", ...
			return plain:match("([%d]+[%d%.]*)%s*$") or ""
		end
	end
	return ""
end

addon.author = AUTHOR
addon.baseTitle = DISPLAY_NAME
addon.version = ReadManifestVersion()
addon.title = addon.version ~= "" and (DISPLAY_NAME .. " " .. addon.version) or DISPLAY_NAME

local em = GetEventManager()

local function NoOp(...)
end

local function GetScene()
	return IsInGamepadPreferredMode() and GAMEPAD_WORLD_MAP_SCENE or WORLD_MAP_SCENE
end

-- True while the player has the full-screen World Map in front (keyboard or gamepad UI).
-- ZO_WorldMap_IsWorldMapShowing() is checked as well because the scene object can lag by a
-- frame during transitions, and a single frame is all it takes to start a Tamriel-wide refresh.
local function IsWorldMapInFront()
	if GetScene():IsShowing() then
		return true
	end
	return ZO_WorldMap_IsWorldMapShowing and ZO_WorldMap_IsWorldMapShowing() or false
end
addon.IsWorldMapInFront = IsWorldMapInFront

-- The scenes we park the minimap in. Built on first use because these globals are not all
-- there yet when this file is read.
local minimapHostScenes
local function IsMinimapHostScene(scene)
	if not minimapHostScenes then
		minimapHostScenes = {
			[HUD_SCENE] = true,
			[HUD_UI_SCENE] = true,
			[SIEGE_BAR_SCENE] = true,
			[SIEGE_BAR_UI_SCENE] = true,
			[LOOT_SCENE] = true,
		}
	end
	return scene ~= nil and minimapHostScenes[scene] == true
end

-- True while something other than us has the World Map on screen.
--
-- IsWorldMapInFront only recognises the two map scenes by name, so any other route the game
-- takes to put the map up goes unnoticed -- the view it opens after an antiquity dig, for
-- one. Nothing then stands the add-on down, and the follow tick keeps panning and re-zooming
-- under the player at 100ms, which reads as a map that ignores the controller.
--
-- Rather than naming more scenes and leaving the next one to be found the same way, ask the
-- question from the other side: the map is visible, and the scene showing it is not ours.
local function IsWorldMapShownElsewhere()
	if not ZO_WorldMap or ZO_WorldMap:IsHidden() then
		return false
	end
	-- Not elsewhere: it is ours.
	--
	-- The settings panel's live preview parks the map fragment in whatever scene the panel is
	-- showing in, which is not one of the HUD scenes. Without this the add-on stands down for
	-- its own preview -- the window goes back to the standard map's size and the border comes
	-- back, which is precisely what the dormant state looks like.
	if addon.litePreviewAdded then
		return false
	end
	local current = SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene()
	if not current then
		return false
	end
	return not IsMinimapHostScene(current)
end
addon.IsWorldMapShownElsewhere = IsWorldMapShownElsewhere

-- Hooks that sit on the World Map's hot path: the per-frame update, zoom changes, and the
-- pin refresh they trigger.
--
-- These all "just pass through" to the game when the minimap is not the active mode, but a
-- pass-through still leaves our Lua function on the call stack. On console, everything the
-- game allocates underneath an add-on frame is billed to the shared 100MB add-on pool -- and
-- zooming the standard map out to all of Tamriel makes the game load every fast-travel node
-- in the world (plus the housing/collectible data behind them) before culling them down to
-- the priority wayshrines. Charged to the add-on pool, that single step blows the limit.
--
-- So instead of branching inside our replacements, the originals are put back while the
-- standard World Map is showing, leaving the add-on off the call stack entirely.
local hotPathHooks = {}
local function HookHotPath(container, key, addonImpl)
	local vanilla = container[key]
	hotPathHooks[#hotPathHooks + 1] = {container = container, key = key, addonImpl = addonImpl, vanilla = vanilla}
	container[key] = addonImpl
	return vanilla
end
-- The API list shows a proper setter for this; assigning the field directly was a guess at
-- its name and had no effect, which is part of why the view still clamped to the map edge.
-- Clearing the place-name labels.
--
-- Nothing clears the location pins any more.
--
-- Hiding place names used to release the location pin pool and RemovePins("loc") along with
-- it, which does not hide names so much as delete the pins that carry them -- and the marker
-- goes with the name. That is why the merchant and service icons the standard map shows were
-- missing from the minimap: they were being thrown away to get rid of the text on them.
--
-- HideMapAreaLabels is what actually hides the names. It hides the Label child of each pin
-- and leaves the pin itself alone, which is the whole job. (An early attempt went after the
-- ZO_MapLocationPins_Manager labels instead and changed nothing, which is how the deletion
-- came to be here in the first place.)
--
-- The instance is still captured from RefreshLocations: RefreshMapLocationLabels uses it to
-- have the game rebuild the pins when the standard map comes forward, so the names we hid one
-- by one come back without us having to work out which ones it wanted.

-- Place names attached to pins.
--
-- These are the Label child of each ZO_MapPin, not the ZO_MapLocationPins_Manager labels the
-- first attempt went after -- which is why hiding those changed nothing. The game decides per
-- pin and per zoom whether a label shows, so rather than trying to predict that, walk the live
-- pins and hide what is showing.
--
-- Only ever hides. Unhiding selectively would mean guessing which labels the game wanted
-- visible; instead the standard map gets a refresh, which rebuilds the pins with the game's
-- own choices.
-- Zone name above the minimap.
--
-- A control of our own rather than ZO_WorldMapTitle: that one belongs to the map window and
-- is driven by InitMiniMap, which the lite path skips. It is also parented to GuiRoot rather
-- than to ZO_WorldMap, so the opacity setting does not fade the text along with the map, and
-- anchored to the map window so it follows wherever the minimap is put.
local zoneTitle
local lastTitleFontSize
local lastTitleText, lastTitleWidth, lastTitleHeight

function addon:EnsureZoneTitle()
	if zoneTitle or not ZO_WorldMap then
		return zoneTitle
	end
	local wm = GetWindowManager()
	if not wm then
		return nil
	end
	-- Parented to ZO_WorldMap, the way the original parents its own title.
	--
	-- It was on GuiRoot so the opacity setting would not fade the text, but nothing appeared
	-- there, and a name that fades with the map beats one that never shows. The label-hiding
	-- pass walks ZO_WorldMap, but skips anything named PBsMiniMap*, so this is left alone.
	zoneTitle = wm:CreateControl("PBsMiniMapZoneTitle", ZO_WorldMap, CT_LABEL)
	zoneTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	zoneTitle:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
	-- -4 rather than -2: at -2 the descenders of the text touched the map's top border.
	zoneTitle:SetAnchor(BOTTOM, ZO_WorldMap, TOP, 0, -4)
	-- Explicit colour, draw layer and tier. A fresh control has none of these settled, and as
	-- a child of GuiRoot it otherwise sits at the bottom of the pile where the rest of the HUD
	-- can cover it -- which is the likely reason nothing appeared.
	zoneTitle:SetColor(1, 1, 1, 1)
	zoneTitle:SetDrawLayer(DL_TEXT)
	zoneTitle:SetMouseEnabled(false)
	zoneTitle:SetExcludeFromResizeToFitExtents(true)
	zoneTitle:SetHidden(true)
	return zoneTitle
end

local function CurrentZoneName()
	local name = GetPlayerActiveSubzoneName()
	if not name or name == "" then
		name = GetPlayerLocationName()
	end
	if not name or name == "" then
		name = GetMapName()
	end
	if not name or name == "" then
		name = GetZoneNameByIndex(GetUnitZoneIndex("player"))
	end
	return name or ""
end

function addon:UpdateZoneTitle()
	local account = self.account
	if not account then
		return
	end

	-- The label is anchored above the map window rather than inside it, so whether the map is
	-- showing has to be checked here: otherwise the name is left floating once the minimap is
	-- hidden.
	local mapShowing = ZO_WorldMap and not ZO_WorldMap:IsHidden()
	local wanted = account.showZoneTitle and mapShowing and not self.dormant and (self.initLevel or 0) < 3 and account.enableMap

	if not wanted then
		if zoneTitle then
			zoneTitle:SetHidden(true)
		end
		return
	end

	local control = self:EnsureZoneTitle()
	if not control then
		return
	end

	local size = account.zoneTitleSize or 24
	if lastTitleFontSize ~= size then
		lastTitleFontSize = size
		local face = ZO_IsConsoleOrGameCoreUI() and "$(GAMEPAD_BOLD_FONT)" or "$(BOLD_FONT)"
		control:SetFont(string.format("%s|%d|soft-shadow-thick", face, size))
	end

	-- Size it explicitly. A label with no dimensions can end up zero-width, in which case the
	-- text is there but nothing is drawn. Width follows the minimap so the name sits over it.
	--
	-- Both the size and the text are only pushed when they have actually changed. This runs
	-- five times a second, and setting either invalidates layout whether or not the value
	-- differs.
	local width = ZO_WorldMap and ZO_WorldMap:GetWidth() or 0
	if width < 120 then
		width = 120
	end
	if lastTitleWidth ~= width or lastTitleHeight ~= size then
		lastTitleWidth, lastTitleHeight = width, size
		control:SetDimensions(width, size * 1.6)
	end

	local name = CurrentZoneName()
	local text = ZO_CachedStrFormat(SI_ZONE_NAME, name)
	if not text or text == "" then
		-- The zone-name grammar can come back empty for some inputs; the raw name beats
		-- showing nothing.
		text = name
	end
	if lastTitleText ~= text then
		lastTitleText = text
		control:SetText(text)
	end
	control:SetHidden(text == "")

end

-- Walk the map area and hide every label that is actually rendering text.
--
-- Going through pinManager:GetActiveObjects() was not enough -- names like "Elden Root
-- Wayshrine" survived it, so whatever draws them is not reachable that way. Rather than keep
-- guessing which manager owns which label, work on the control tree: everything inside
-- ZO_WorldMapContainer is map content, so a visible label in there is a place name.
--
-- Scoped to the container deliberately. The title bar and the add-on's own controls live
-- outside it and are left alone.
local function ForEachLabel(control, depth, callback)
	if not control or depth > 8 then
		return
	end
	local childCount = control.GetNumChildren and control:GetNumChildren() or 0
	for index = 1, childCount do
		local child = control:GetChild(index)
		if child then
			if child.GetType and child:GetType() == CT_LABEL then
				callback(child)
			end
			ForEachLabel(child, depth + 1, callback)
		end
	end
end

-- The sweep is not cheap: ZO_WorldMapContainer holds every map pin, so this walks hundreds
-- of controls. It used to run from both the 100ms and the 200ms tick, roughly fifteen times a
-- second, to catch labels the game had just put back.
--
-- Almost all of those runs found nothing. The game only reveals these labels around map
-- changes and around returning from the full map, so the sweep is now requested at those
-- points and otherwise happens once a second as insurance.
local labelSweepPending = true
function addon:RequestLabelSweep()
	labelSweepPending = true
end

-- Search from ZO_WorldMap, not ZO_WorldMapContainer.
--
-- The name of whatever the cursor was last over -- "Elden Root Wayshrine" and the like -- is
-- drawn over the map frame but is not a child of the container, so a search scoped to the
-- container never saw it.
--
-- Two things are skipped: this add-on's own controls, and the map title. Everything else
-- inside the map window that is showing text is a leftover from the full map.
local function IsOurControl(control)
	local name = control.GetName and control:GetName()
	return name ~= nil and (zo_plainstrfind(name, "PBsMiniMap") or name == "ZO_WorldMapTitle")
end

function addon:HideMapAreaLabels()
	if not ZO_WorldMap then
		return
	end
	ForEachLabel(
		ZO_WorldMap,
		0,
		function(label)
			if not label:IsHidden() and not IsOurControl(label) then
				local text = label.GetText and label:GetText()
				if text and text ~= "" then
					label:SetHidden(true)
				end
			end
		end
	)
end

-- Runs the sweep when something has asked for one, and otherwise at most once a second.
local lastLabelSweepMs = 0
function addon:SweepMapLabelsIfDue()
	local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
	if not labelSweepPending and now - lastLabelSweepMs < 1000 then
		return
	end
	labelSweepPending = false
	lastLabelSweepMs = now
	self:HideMapAreaLabels()
end

function addon:RefreshMapLocationLabels()
	local manager = self.locationPinManager
	if manager and manager.RefreshLocations then
		manager:RefreshLocations()
	end
end

function addon:SetAllowPanPastMapEdge(allow)
	local panZoom = self.panZoom
	if not panZoom then
		return
	end
	if panZoom.SetAllowPanPastMapEdge then
		panZoom:SetAllowPanPastMapEdge(allow)
	else
		panZoom.allowPanPastMapEdge = allow
	end
end

-- The Shadow Cleft HUD report has valid, non-symbolic coordinates but shown=false.
-- This flag controls the native pin's visibility, not whether the coordinates exist.
-- Accept that discrepancy only on the player's own map; another floor/parent map
-- or a symbolic entrance must never be treated as the player's actual location.
function addon:IsLitePlayerPositionUsable(x, y, shown, symbolic)
	return not symbolic and type(x) == "number" and type(y) == "number"
		and x > 0 and x < 1 and y > 0 and y < 1
		and (shown or DoesCurrentMapMatchMapForPlayerLocation())
end

function addon:RepairLitePlayerPinVisibility()
	if self.dormant or not self.account or not self.account.enableMap
		or (self.initLevel or 0) >= 3 or not ZO_WorldMap or ZO_WorldMap:IsHidden()
		or IsWorldMapInFront() or IsWorldMapShownElsewhere() then
		return
	end
	local x, y, _, shown, symbolic = GetMapPlayerPosition("player")
	if shown or not self:IsLitePlayerPositionUsable(x, y, shown, symbolic) then
		return
	end
	local pin = self.pinManager and self.pinManager:GetPlayerPin()
	if not pin then return end
	pin:SetOriginalPosition(x, y)
	pin:SetIsSymbolicPosition(false)
	-- SetLocation also restores the Background texture's visibility and geometry.
	pin:SetLocation(x, y)
	pin:SetRotation(GetPlayerCameraHeading())
	pin:SetHidden(false)
end

function addon:InitLitePlayerPinVisibilityHook()
	local original
	original = HookHotPath(ZO_WorldMapPins_Manager, "UpdateMovingPins", function(manager, ...)
		local result = original(manager, ...)
		-- Repair in the SAME update that hid the pin. A 100ms timer alone loses to
		-- the next native update and produces missing frames or flicker.
		if manager == addon.pinManager then
			addon:RepairLitePlayerPinVisibility()
		end
		return result
	end)
end

-- Votan's UpdatePinsForMapSizeChange raises the player pin's parent as well as
-- its textures. ESO gives non-clickable pin parents level 0 in SetData; raising
-- only the Background child does not restore the parent's ordering against
-- other map controls. Keep this correction confined to the HUD.
function addon:RestoreLitePlayerPinDrawLevel()
	local saved = self.litePlayerPinDrawLevel
	if saved then
		if saved.control:GetDrawLevel() == saved.applied then
			saved.control:SetDrawLevel(saved.original)
		end
		self.litePlayerPinDrawLevel = nil
	end
end

function addon:ApplyLitePlayerPinDrawLevel()
	if self.dormant or not self.account or not self.account.enableMap or IsWorldMapShownElsewhere() then
		self:RestoreLitePlayerPinDrawLevel()
		return
	end
	local pin = self.pinManager and self.pinManager:GetPlayerPin()
	local control = pin and pin:GetControl()
	local data = ZO_MapPin.PIN_DATA[MAP_PIN_TYPE_PLAYER]
	if not control or not data or type(data.level) ~= "number" then
		return
	end
	local level = zo_max(data.level, 1)
	local saved = self.litePlayerPinDrawLevel
	if saved and saved.control ~= control then
		self:RestoreLitePlayerPinDrawLevel()
		saved = nil
	end
	local current = control:GetDrawLevel()
	if not saved then
		saved = {control = control, original = current, applied = level}
		self.litePlayerPinDrawLevel = saved
	elseif current ~= saved.applied then
		-- SetData or another add-on may have reset the parent since the last sample.
		saved.original = current
	end
	if current ~= level then
		control:SetDrawLevel(level)
	end
	saved.applied = level
end

-- Preserve the last HUD sample so opening Settings does not replace the evidence
-- with the (working) full-screen map state. One small sample per second, no pin scan.
function addon:CaptureLitePlayerPinDiagnostic()
	if self.dormant or self.litePreviewAdded or IsWorldMapShownElsewhere()
		or not ZO_WorldMap or ZO_WorldMap:IsHidden() then
		return
	end
	local now = GetFrameTimeMilliseconds()
	if now < (self.nextPlayerPinDiagnosticMs or 0) then return end
	self.nextPlayerPinDiagnosticMs = now + 1000
	local x, y, _, shown, symbolic = GetMapPlayerPosition("player")
	local pin = self.pinManager and self.pinManager:GetPlayerPin()
	local control = pin and pin:GetControl()
	local background = control and control:GetNamedChild("Background")
	local px, py = 0, 0
	local cx, cy = ZO_WorldMapScroll:GetCenter()
	if control then px, py = control:GetCenter() end
	self.playerPinDiagnostic = {
		string.format("v%s t=%.1f map=%s (%s) floor=%s", self.version, now / 1000,
			tostring(GetMapName()), tostring(GetCurrentMapId()), tostring(GetMapFloorInfo())),
		string.format("pos=%.4f,%.4f shown=%s symbolic=%s ownMap=%s world=%s follow=%s", x, y,
			tostring(shown), tostring(symbolic), tostring(DoesCurrentMapMatchMapForPlayerLocation()),
			tostring(DoesCurrentMapShowPlayerWorld()), tostring(self.followSkip)),
		control and string.format("pin hidden=%s alpha=%.2f level=%d size=%.1fx%.1f offset=%.1f,%.1f",
			tostring(control:IsHidden()), control:GetAlpha(), control:GetDrawLevel(),
			control:GetWidth(), control:GetHeight(), px - cx, py - cy) or "pin missing",
		background and string.format("texture hidden=%s alpha=%.2f layer=%d level=%d texture=%s",
			tostring(background:IsHidden()), background:GetAlpha(), background:GetDrawLayer(),
			background:GetDrawLevel(), tostring(background:GetTextureFileName())) or "texture missing",
		self.CompassTextureStatus and self:CompassTextureStatus() or "compass not loaded",
	}
end

function addon:PrintLitePlayerPinDiagnostic()
	local lines = self.playerPinDiagnostic
	if not lines then
		d(GetString(SI_PBSMINIMAP_PIN_DIAGNOSTIC_EMPTY))
		return
	end
	for i = 1, #lines do
		d("[PBsMiniMap] " .. lines[i])
	end
end

-- Swapping a hook in or out means writing a saved function into a shared slot, and that slot
-- does not belong to this add-on alone.
--
-- If another add-on has hooked the same function after we did, what is installed is its
-- wrapper -- around ours. Writing our saved pointer over that does not remove our hook, it
-- removes theirs, permanently and silently. HarvestMap hooks
-- ZO_WorldMapPins_Manager:UpdatePinsForMapSizeChange, which is how its pins follow the zoom,
-- and it stopped working the first time the player opened and closed the world map: that is
-- the first dormancy transition, and the transition was overwriting its wrapper.
--
-- So a swap only happens when what is installed is still the exact function we expect to be
-- replacing. When somebody has wrapped us we leave the chain alone and stay in it; our own
-- implementations already hand straight back while the standard map is in front, which is the
-- state the swap was for.
local function SwapHook(hook, from, to)
	if hook.container[hook.key] == from then
		hook.container[hook.key] = to
		return true
	end
	return false
end

function addon:SetHotPathHooksActive(active)
	self.hotPathHooksActive = active and true or false
	for i = 1, #hotPathHooks do
		local hook = hotPathHooks[i]
		if active then
			SwapHook(hook, hook.vanilla, hook.addonImpl)
		else
			SwapHook(hook, hook.addonImpl, hook.vanilla)
		end
	end
end

-- Dormant mode: while the player has the full-screen World Map in front, this add-on stops
-- doing map work of any kind. Everything the game then does -- including loading every
-- fast-travel node in the world when zooming out to all of Tamriel -- runs purely in the
-- game's own context and is not billed to the shared 100MB console add-on pool.
--
-- Defined at module scope, and driven every frame from the observed state of the map rather
-- than from scene StateChange callbacks. Those callbacks live inside InitMiniMap, so they are
-- not even registered when the minimap is turned off, and there is no guarantee the console UI
-- drives the same scenes this add-on listens to. Polling the same answer the diagnostics print
-- means dormancy can never silently fail to engage.
-- Drop the gamepad map's sticky pin before centring.
--
-- With the stick at rest the gamepad map pans to whichever pin sits nearest the reticle, and it
-- makes that choice every frame from where the view was on the frame before. A pin picked while
-- the view was still off the player is therefore acted on one frame later, and once a pan is
-- under way it runs to the end -- sticky selection is disabled until the target is reached.
-- Clearing it here leaves nothing stale to pan to: the map picks a new one around the player on
-- its next frame. Nothing here rebuilds the map; it is a single field on the sticky-pin object.
local function ClearStickyPin(panZoom)
	local sticky = ZO_WorldMap_GetStickyPin and ZO_WorldMap_GetStickyPin()
	if sticky and sticky.ClearStickyPin and panZoom then
		sticky:ClearStickyPin(panZoom)
	end
end

-- Centre the way the game does when the map is shown. The pending offset is cleared first, as
-- InitializeMap does. Called exactly once per opening, and never repeated: it goes on to
-- SetMapToPlayerLocation, which rebuilds the whole map, and running that again from add-on
-- context while the player zooms out is what crashed 2.2.8-2.2.10.
function addon:CentreStandardMapOnPlayer()
	local panZoom = self.panZoom
	if not panZoom then
		return
	end
	ClearStickyPin(panZoom)
	if panZoom.ClearTargetOffset then
		panZoom:ClearTargetOffset()
	end
	if panZoom.OnWorldMapShowing then
		panZoom:OnWorldMapShowing()
	elseif ZO_WorldMap_JumpToPlayer then
		ZO_WorldMap_JumpToPlayer()
	end
end

-- The first opening after a UI reload leaves the player off-centre, and the reason is in the
-- game's own code rather than in ours.
--
-- ZO_MapPanAndZoom:OnWorldMapShowing calls SetMapToPlayerLocation and then JumpToPin. When that
-- call changes the map -- which it does on the first opening, and on a wayshrine map -- the new
-- map's texture is not loaded yet, CanInitializeMap is false, and JumpToPin only records itself
-- as pendingJumpToPin (worldmap.lua). InitializeMap applies it when the texture arrives, about
-- 200ms later. So the centring is held back by the very call that asks for it: postponing our
-- own call cannot avoid it, which is what 2.2.13 tried.
--
-- The centring does land, and measured with the 2.2.9 trace it landed centred. What then pulled
-- the view off the player is the gamepad sticky pin: with the stick at rest the map pans to the
-- pin nearest the reticle, chosen from where the view was on the frame before, and during those
-- 200ms the view was off-centre. The frame after the centring landed, the map began panning to
-- that stale pin, ending 271 pixels off.
--
-- A started pan can be stopped: ZO_WorldMapStickyPin:ClearStickyPin clears the mover's target
-- offset when it is moving to a pin (mappin_manager.lua), which is exactly what ZO_WorldMap_
-- JumpToPlayer does through StopMotion before jumping to the player pin. Arriving a sample late
-- is therefore fine, and that call is cheap: pin geometry and an offset, with no SetMapToPlayer-
-- Location and no map rebuild behind it. Repeating the full showing step instead is what made
-- 2.2.8-2.2.10 crash when zooming out.
local PENDING_CENTRE_TICKS = 40 -- 2 seconds at 50ms, then give up

-- The same thing happens when the player changes map level with the map open, and measured on
-- console it is worse: the first zoom-out to the parent map after a UI reload lands on a pin
-- near the old view instead of the player.
--
--   out   init=Y tex=n zoom=1.00 rng=1.00-2.16 pin=shown ofs=-129,335
--   +200  init=n tex=Y zoom=1.00 rng=1.00-8.66 pin=shown ofs=-131,189
--   +600  init=Y tex=Y zoom=1.00 rng=1.00-8.66 pin=shown ofs=-140,-168
--
-- The player pin was visible throughout, so the hidden-pin path was not it, and the zoom range
-- repaired itself. What gives it away is that the zoom never became 0.90: InitializeMap's
-- navigate branch sets 1 - NAVIGATE_IN_OR_OUT_NORMALIZED_ZOOM_ADJUSTMENT before jumping to the
-- player, so that branch never ran. The offset meanwhile slid past the centre -- a pan, not a
-- jump. InitializeMap prefers a pending pan over the navigate branch (worldmap.lua:1023), and
-- the only thing panning with the stick at rest is the sticky pin: while the map sat waiting
-- for its texture, MoveToStickyPin called PanToPin, which recorded itself as pendingPanToPin,
-- and initialisation then honoured that instead of centring on the player.
--
-- So a map level change taken while the map is still loading is armed here too, and the same
-- one-shot ZO_WorldMap_JumpToPlayer tidies it up: StopMotion drops the sticky pin and stops its
-- pan, then the view goes to the player. Nothing here runs per frame or rebuilds the map.
function addon:ArmCentreTidyUp()
	if self.panZoom and self.panZoom.pendingInitializeMap then
		self.pendingCentreTicks = PENDING_CENTRE_TICKS
	end
end

-- Driven from the 50ms watch that already runs, not from a per-frame update, and only while a
-- centring is known to be held back.
function addon:UpdatePendingCentre()
	local ticks = self.pendingCentreTicks
	if not ticks then
		return
	end
	-- The map was closed again, or the wait ran long enough that something else is going on.
	if not self.dormant or ticks <= 0 then
		self.pendingCentreTicks = nil
		return
	end
	self.pendingCentreTicks = ticks - 1
	-- Still loading: the held-back centring has not landed yet.
	if self.panZoom and self.panZoom.pendingInitializeMap then
		return
	end
	self.pendingCentreTicks = nil
	-- Only where the game would centre on the player itself: it jumps to the player pin when
	-- that pin is visible, and leaves the view alone when it is not.
	local pin = self.pinManager and self.pinManager:GetPlayerPin()
	local control = pin and pin:GetControl()
	if control and control:IsHidden() then
		return
	end
	-- It has landed. Drop the stale sticky pin, stopping its pan if one has already started,
	-- and put the view back on the player.
	if ZO_WorldMap_JumpToPlayer then
		ZO_WorldMap_JumpToPlayer()
	else
		ClearStickyPin(self.panZoom)
	end
end

local dormant = false
function addon:SetDormant(value)
	if dormant == value then
		return
	end
	dormant = value
	self.dormant = value
	-- Count the transitions. A flicker between two 50ms samples is invisible in the samples
	-- themselves but shows up here as a count that climbs while the map sits still.
	self.dormantFlips = (self.dormantFlips or 0) + 1

	if value then
		self:RestoreLitePlayerPinDrawLevel()
		-- The standard map owns the window now, so nothing of ours is waiting to settle.
		self.settleTicks = 0

		-- Stop everything we own: swap our hooks back out, then detach the minimap itself so the
		-- game owns the World Map outright. The memory watch deliberately keeps running.
		self:SetHotPathHooksActive(false)
		if self.SetMinimapAttached then
			self:SetMinimapAttached(false)
		end
		-- Lite path: the standard World Map is taking over, so restore the game's own size
		-- and position for it. (At level 3+ InitMiniMap's GoWorldMapMode already does this.)
		if (self.initLevel or 0) < 3 and self.RestoreDefaultMapLayout then
			self:RestoreDefaultMapLayout()
		end
		if self.orgAllowPanPastMapEdge ~= nil then
			self:SetAllowPanPastMapEdge(self.orgAllowPanPastMapEdge)
		end

		-- Give the zoom range back, or the standard map inherits the minimap's.
		--
		-- The range we install is deliberately narrow and usually has min == max, because the
		-- minimap is meant to sit at one zoom. The game only recomputes its own range in
		-- ZO_MapPanAndZoom:InitializeMap, which runs when a map is loaded -- not when the world
		-- map is opened. So nothing was undoing ours, and the full map could barely be zoomed
		-- at all until the player crossed into a different map.
		--
		-- Recomputed exactly the way InitializeMap does it, and any custom range is dropped
		-- first since that sits above this one.
		-- Hand the map back; do not reset it.
		--
		-- Standing down is not always the player opening the map. The game opens it for its
		-- own purposes too -- a wayshrine, an antiquity dig -- and it has already decided what
		-- that view should show. Clearing the custom zoom range destroys the magnification it
		-- installed for the dig site, and jumping to the player throws away the position it
		-- chose. Both were happening, which is the dig map coming up at the wrong zoom centred
		-- on the player.
		--
		-- Recomputing the game's own min and max is kept either way. It is what InitializeMap
		-- does, our narrow range has to go regardless, and a custom range sits above it, so a
		-- view that installed one is unaffected.
		--
		-- "The player opened it" is the map scene itself in front, not in a special mode. It
		-- used to be "not shown elsewhere", which is true for the map scene as well -- that
		-- test asks whether the scene on screen is one of the HUD scenes, and the full map's
		-- own scene is not -- so this was false on every opening, and the centring below had
		-- not run once since it was added. A view the game opens for itself is still excluded:
		-- the antiquity map sits in a scene of its own, where IsWorldMapInFront reads false,
		-- and the wayshrine map is a special mode.
		-- Which views get the step the game would have run when the map came up.
		--
		-- The game lays the full map out, zooms and centres it from WORLD_MAP_FRAGMENT's SHOWING
		-- state. The minimap keeps that fragment on the HUD, so opening the map never makes it
		-- start showing and none of that runs; what follows stands in for it.
		--
		-- That is right for the map the player opens, and for the two travel maps, which the
		-- game opens with PushSpecialMode followed by ZO_WorldMap_ShowWorldMap and then relies
		-- on that same showing step to centre -- leaving them out is why the wayshrine map came
		-- up away from the player. It is wrong for a view that sets itself up afterwards: the
		-- antiquity map zooms and places its own view (and sits in a scene of its own, where
		-- IsWorldMapInFront reads false), so it and any other special mode are left alone.
		local inSpecialMode = WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.inSpecialMode
		local mapMode = WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.GetMode and WORLD_MAP_MANAGER:GetMode()
		local travelMap = inSpecialMode and mapMode ~= nil
			and (mapMode == MAP_MODE_FAST_TRAVEL or mapMode == MAP_MODE_KEEP_TRAVEL)
		local playerFacing = IsWorldMapInFront() and (not inSpecialMode or travelMap)

		local panZoom = self.panZoom
		if panZoom then
			if playerFacing then
				-- The game never installs a custom zoom range itself; one left here is ours or
				-- another add-on's, and it sits above the range recomputed below.
				if ZO_WorldMap_ClearCustomZoomLevels then
					ZO_WorldMap_ClearCustomZoomLevels()
				elseif panZoom.ClearCustomZoomMimMax then
					panZoom:ClearCustomZoomMimMax()
				end

				-- Lay the map out at its real size first; everything after reads it.
				--
				-- Standing down writes back the layout captured at login, which is not the one
				-- the map needs now. SetCurrentNormalizedZoomInternal at the current zoom is the
				-- game's own route to SetMapWindowSize, which sizes the window and scroll the way
				-- the full map wants them (on gamepad it uses the gamepad dimensions and ignores
				-- what is passed).
				--
				-- Two things read that size. ComputeMaxZoom divides by ZO_WorldMapScroll's height,
				-- so the range below came out wrong from the stale scroll -- and a maximum of 1
				-- equals the minimum, which the gamepad map treats as "cannot zoom" and answers a
				-- zoom press by navigating to the next map level instead: the level changing by
				-- itself on the wayshrine map. And JumpToPin multiplies by the scroll's width to
				-- place the player, so a stale scroll put the player off-centre.
				if panZoom.SetCurrentNormalizedZoomInternal and panZoom.GetCurrentNormalizedZoom then
					panZoom:SetCurrentNormalizedZoomInternal(panZoom:GetCurrentNormalizedZoom())
				end
			end

			-- Give the zoom range back, recomputed the way InitializeMap does it. Kept for every
			-- view: our narrow range has to go regardless, and a custom range sits above it.
			if panZoom.SetMapZoomMinMax and panZoom.ComputeMinZoom and panZoom.ComputeMaxZoom then
				panZoom:SetMapZoomMinMax(panZoom:ComputeMinZoom(), panZoom:ComputeMaxZoom())
			end

			-- Then centre exactly the way the game does when the map is shown: the player's own
			-- map, at the current zoom, and nothing at all if the player picked a different map
			-- themselves. The pending offset is cleared first, as InitializeMap does.
			if playerFacing then
				self.pendingCentreTicks = nil
				self:CentreStandardMapOnPlayer()
				-- If the centring was held back (the map it switched to is still loading), take
				-- note: it lands on its own later, and something has to tidy up after it.
				if panZoom.pendingInitializeMap
					and not (ZO_WorldMap_DidPlayerChooseCurrentMap and ZO_WorldMap_DidPlayerChooseCurrentMap()) then
					self.pendingCentreTicks = PENDING_CENTRE_TICKS
				end
			end
		end
		if self.ApplyLiteAlpha then
			self:ApplyLiteAlpha()
		end
		if self.ApplyLiteBorder then
			self:ApplyLiteBorder()
			self:ApplyLiteDrawOrder()
			-- Standard map owns the window: stop refusing its geometry changes.
			self:SetLiteAnchorGuard(false)
		end
		if self.UpdateZoneTitle then
			self:UpdateZoneTitle()
		end
		-- Labels were hidden one by one; let the game rebuild the pins rather than trying to
		-- work out which ones it wanted visible.
		if (self.initLevel or 0) < 3 and self.account and self.account.hideMapLabels then
			self:RefreshMapLocationLabels()
			if ZO_WorldMap_UpdateMap then
				ZO_WorldMap_UpdateMap()
			end
		end
	else
		-- The map is gone; a postponed centring belongs to it and is dropped with it.
		self.pendingCentreTicks = nil
		-- Only of interest with the (locked) debug output on; see the trace window in Check.
		if self.account and self.account.debug then
			self.traceTicks = 20
		end
		-- Hold the window invisible from here until it is the right shape (see BeginLiteSettle).
		if (self.initLevel or 0) < 3 and self.BeginLiteSettle then
			self:BeginLiteSettle()
		end

		-- Everything that defends the layout has to be in place BEFORE the map is shown.
		--
		-- Hot-path hooks are swapped back to vanilla while dormant, and one of them is the
		-- RefreshMapFrameAnchor hook that puts our position back after the game re-anchors the
		-- map frame. Turning them on after attaching meant the game re-anchored during the
		-- attach with nothing hooked, and the minimap came up at the full map's position and
		-- stayed there until the 200ms layout watch noticed. The size never showed the problem
		-- because it is pinned by dimension constraints, which need no hook to hold.
		--
		-- Same for the custom zoom range: a view the game opened itself installs one, it sits
		-- above the range we ask for, and clearing it after the map is already back means the
		-- first frames are drawn at whatever zoom that view was using.
		self:SetHotPathHooksActive(true)
		if (self.initLevel or 0) < 3 then
			if ZO_WorldMap_ClearCustomZoomLevels then
				ZO_WorldMap_ClearCustomZoomLevels()
			elseif self.panZoom and self.panZoom.ClearCustomZoomMimMax then
				self.panZoom:ClearCustomZoomMimMax()
			end
		end

		if self.SetMinimapAttached and self.account and self.account.enableMap then
			-- Opening the standard map lets the game resize ZO_WorldMap to full screen, so the
			-- lite layout has to be re-applied every time we come back to the HUD. Attaching
			-- does that itself; only cover the case where it was already attached, so the
			-- window is not put through a second resize for nothing.
			local attachedNow = self:SetMinimapAttached(true)
			if not attachedNow and (self.initLevel or 0) < 3 and self.ApplyLiteMinimapLayout then
				self:ApplyLiteMinimapLayout()
			end
			-- The zoom range is computed from the window's size, so it can only be worked out
			-- once the window is the size we just gave it. Doing it here rather than waiting
			-- for the next follow tick keeps the first drawn frame at the right zoom.
			if (self.initLevel or 0) < 3 and self.AdjustLiteZoom then
				self:AdjustLiteZoom()
			end
		end
		-- Minimap is up again: let the view sit past the map edge so the player marker can stay
		-- in the middle even at the border of a small map.
		if (self.initLevel or 0) < 3 and self.orgAllowPanPastMapEdge ~= nil then
			self:SetAllowPanPastMapEdge(true)
		end
		if self.ApplyLiteAlpha then
			self:ApplyLiteAlpha()
		end
		if self.ApplyLiteBorder then
			self:ApplyLiteBorder()
			self:ApplyLiteDrawOrder()
			-- Only guarded while the minimap is actually up. Installing is idempotent, and
			-- doing it here covers the minimap being switched on after load rather than at it.
			self:InstallLiteAnchorOverride()
			self:SetLiteAnchorGuard(true)
		end
		-- Labels built while the full map was open are still on the map, and the name of
		-- whatever was last focused there lingers too. Hide both on the way back.
		if (self.initLevel or 0) < 3 and self.account and self.account.hideMapLabels then
			-- Immediately, rather than waiting up to a tick for the maintenance pass.
			self:RequestLabelSweep()
			self:HideMapAreaLabels()
		end
		if ZO_WorldMap_HandlePinExit then
			ZO_WorldMap_HandlePinExit()
		end

		-- Drop any custom zoom range the map picked up.
		--
		-- Opening the map from a wayshrine puts it in a special mode, and the game installs a
		-- custom zoom range for that view. Custom levels sit above the range we set with
		-- SetMapZoomMinMax, so until they are cleared the minimap keeps whatever the wayshrine
		-- view was using, no matter what we ask for. The original clears them on both mode
		-- transitions; both live in InitMiniMap, which this path skips, so nothing did.
		if ZO_WorldMap_ClearCustomZoomLevels then
			ZO_WorldMap_ClearCustomZoomLevels()
		elseif self.panZoom and self.panZoom.ClearCustomZoomMimMax then
			self.panZoom:ClearCustomZoomMimMax()
		end

		-- Do what the game does when the map window hides, when there is something to undo.
		--
		-- The game remembers that the player picked a map themselves -- navigated to another
		-- level, showed a quest or a keep on the map, scried an antiquity -- and while that is
		-- set, opening the map leaves the view where it was instead of centring on the player.
		-- The one place it is cleared is ZO_WorldMap_OnHide, the map window's OnHide handler:
		-- closing the full map hides the window, and the next opening starts from the player.
		--
		-- This add-on keeps that window on the HUD, so closing the full map no longer hides it.
		-- The flag stayed set until the player happened to open a menu -- which does hide the
		-- window -- and until then every opening skipped the centring. Hence "now and then".
		--
		-- So run the game's own handler at the point the window would have hidden. Only when
		-- the flag is actually set: the handler also ends the travel interactions and closes
		-- out a dig-site reveal, which is what the game does on every close, but there is no
		-- reason to do any of it when nothing needs undoing. Called before the special mode is
		-- popped below, because the handler decides what to close by the current mode.
		if ZO_WorldMap_OnHide and ZO_WorldMap_DidPlayerChooseCurrentMap and ZO_WorldMap_DidPlayerChooseCurrentMap() then
			ZO_WorldMap_OnHide()
		end

		-- Close out a fast-travel session properly.
		--
		-- Opening the map from a wayshrine puts the map manager into a special mode and starts
		-- an interaction. Backing out leaves both standing unless they are cleared, and the
		-- wayshrine then stays unusable until the player walks away and returns. The original
		-- clears them in GoMiniMapMode and on player deactivation -- both inside InitMiniMap,
		-- which this path skips, so nothing was clearing them at all.
		if WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.inSpecialMode then
			if WORLD_MAP_MANAGER.PopSpecialMode then
				WORLD_MAP_MANAGER:PopSpecialMode()
			end
			-- inSpecialMode covers every special map view, not just the wayshrine one, but
			-- only fast travel leaves an interaction standing. Ending one the player never
			-- started cuts short whatever they are actually in -- an antiquity dig, say.
			local interaction = GetInteractionType and GetInteractionType()
			local someoneElsesInteraction =
				interaction ~= nil and
				interaction ~= INTERACTION_NONE and
				interaction ~= INTERACTION_FAST_TRAVEL and
				interaction ~= INTERACTION_FAST_TRAVEL_KEEP
			if EndInteraction and not someoneElsesInteraction then
				EndInteraction(INTERACTION_FAST_TRAVEL_KEEP)
				EndInteraction(INTERACTION_FAST_TRAVEL)
			end
		elseif GetKeepFastTravelInteraction and GetKeepFastTravelInteraction() then
			EndInteraction(INTERACTION_FAST_TRAVEL_KEEP)
		end

		if self.UpdateZoneTitle then
			self:UpdateZoneTitle()
		end
	end
end

addon.pinManager = ZO_WorldMap_GetPinManager()
addon.panZoom = ZO_WorldMap_GetPanAndZoom()

function addon:InitRequiredModifications()
	local lastW, lastH, lastZone = -1, -1, -1
	local orgUpdatePinsForMapSizeChange
	orgUpdatePinsForMapSizeChange =
		HookHotPath(
		ZO_WorldMapPins_Manager,
		"UpdatePinsForMapSizeChange",
		function(pins)
			-- Never stand between the game and anything hooked beneath us while the standard
			-- map is in front.
			--
			-- This hook exists to drop redundant full pin refreshes, which is worth having on
			-- the HUD where the add-on memory pool is the constraint. But dropping a call also
			-- drops everything hooked under it: HarvestMap tracks zoom with a ZO_PreHook on
			-- this very method, add-ons load it before this one so its hook sits underneath,
			-- and its pins stopped following the zoom on the standard map because the call
			-- never reached it.
			--
			-- On the standard map there is nothing to save -- the add-on is meant to be
			-- invisible there -- so the call goes straight through.
			if IsWorldMapInFront() then
				return orgUpdatePinsForMapSizeChange(pins)
			end

			local w, h = ZO_WorldMapContainer:GetDimensions()
			w, h = zo_round(w), zo_round(h)
			local zone = GetMapTileTexture()
			if lastW ~= w or lastH ~= h or lastZone ~= zone then
				lastW, lastH, lastZone = w, h, zone
				return orgUpdatePinsForMapSizeChange(pins)
			end
		end
	)
end

function addon:Initialize()
	local accountDefaults = {
		enableMap = true,
		followPlayer = true,
		liteAlpha = 100,
		hideMapLabels = true,
		liteDrawOrder = "default",
		showBorder = true,
		mapStyle = "square",
		showZoneTitle = true,
		zoneTitleSize = 24,
		-- Scale relative to the map's native resolution, same meaning as the original's zoom
		-- settings (and the same defaults). Renamed from the old liteZoom* keys because those
		-- held 0..1 values with a completely different meaning.
		liteScale = 1.3,
		liteScaleSubZone = 0.35,
		liteScaleDungeon = 0.5,
		-- A battleground is an arena, closer in size to an interior than to a dungeon, and it
		-- was given the dungeon's number without anyone looking at the result. At 0.5 it draws
		-- two and a half times more magnified than the value that reads comfortably on the
		-- small subzone maps.
		liteScaleBattleground = 0.3,
		-- The Imperial City districts: subzone maps, but far larger and denser than a building
		-- or a town. A starting point rather than a measured value.
		liteScaleAva = 0.6,
		bgScaleRetuned = false,
		debug = false
	}
	self.accountDefaults = accountDefaults

	self.account = ZO_SavedVars:NewAccountWide("PBsMiniMap_Data", 1, nil, accountDefaults)

	-- Place names are always hidden now, and the setting for it is gone from the panel. The
	-- value is still read in the few places that act on it, so anyone who had switched it off
	-- is brought back to on rather than being left with a setting they can no longer reach.
	self.account.hideMapLabels = true

	-- One-off retune of the battleground zoom.
	--
	-- ZO_SavedVars copies the defaults into the saved table when it first creates it, so
	-- lowering the default alone would reach nobody who has already played. This moves the
	-- value only for players still sitting on the old default -- anyone who has chosen their
	-- own number keeps it -- and marks itself done so a later change back is never undone.
	if not self.account.bgScaleRetuned then
		if self.account.liteScaleBattleground == 0.5 then
			self.account.liteScaleBattleground = accountDefaults.liteScaleBattleground
		end
		self.account.bgScaleRetuned = true
	end

	-- Attaching / detaching the minimap.
	--
	-- The minimap is shown by parking the game's one and only World Map fragment in the HUD
	-- scenes. Testing showed the crash tracks exactly this: with the minimap turned off the
	-- full Tamriel view is fine, with it on the console add-on memory limit is blown. So while
	-- the player has the standard World Map in front, the fragment is taken back out of the
	-- HUD scenes, which puts the game in the same state as having the minimap disabled.
	-- Lite minimap layout.
	--
	-- Testing narrowed the console memory crash to InitMiniMap: with it skipped (init level 2)
	-- the game's own World Map can sit permanently in the HUD and the full Tamriel view is
	-- fine, but nothing sizes or positions it, so it fills the screen. This applies the user's
	-- size and position directly to ZO_WorldMap, with none of the InitMiniMap machinery and no
	-- dependency on modeData.
	-- The game's own anchoring and size for ZO_WorldMap, captured the first time we touch the
	-- window so it can be handed back verbatim when the standard World Map takes over.
	-- Snapshot of the game's own layout for the controls the lite path touches, taken the
	-- first time we touch them so it can be handed back verbatim.
	--
	-- Both controls matter: ApplyLiteMinimapLayout shrinks ZO_WorldMapScroll as well as
	-- ZO_WorldMap (the scroll is the actual map viewport, and sizing only the outer window did
	-- not take). Restoring just the outer window therefore left the standard map still wearing
	-- the minimap's size. The dimension constraints are part of the snapshot too, since the
	-- lite path lowers the floor to 20x20.
	local defaultLayout

	local function CaptureControlLayout(control)
		if not control then
			return nil
		end
		local anchors = {}
		for index = 0, 1 do
			local isValid, point, relativeTo, relativePoint, offsetX, offsetY = control:GetAnchor(index)
			if isValid then
				anchors[#anchors + 1] = {point, relativeTo, relativePoint, offsetX, offsetY}
			end
		end
		local width, height = control:GetDimensions()
		local minWidth, minHeight, maxWidth, maxHeight
		if type(control.GetDimensionConstraints) == "function" then
			minWidth, minHeight, maxWidth, maxHeight = control:GetDimensionConstraints()
		end
		return {
			anchors = anchors,
			width = width,
			height = height,
			minWidth = minWidth,
			minHeight = minHeight,
			maxWidth = maxWidth,
			maxHeight = maxHeight
		}
	end

	-- Restoring the game's own layout is also us moving the window on purpose, so the whole
	-- function is exempt -- size as well as anchors, since both are refused from outside now.
	local function RestoreControlLayout(control, layout)
		if not control or not layout then
			return
		end
		addon:BeginOwnAnchor()
		if layout.minWidth and type(control.SetDimensionConstraints) == "function" then
			control:SetDimensionConstraints(layout.minWidth, layout.minHeight, layout.maxWidth, layout.maxHeight)
		end
		if #layout.anchors > 0 then
			control:ClearAnchors()
			for index = 1, #layout.anchors do
				local anchor = layout.anchors[index]
				control:SetAnchor(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
			end
		end
		control:SetDimensions(layout.width, layout.height)
		addon:EndOwnAnchor()
	end

	local function CaptureDefaultLayout()
		if defaultLayout then
			return
		end
		if not ZO_WorldMap then
			return
		end
		defaultLayout = {
			map = CaptureControlLayout(ZO_WorldMap),
			scroll = CaptureControlLayout(ZO_WorldMapScroll)
		}
	end

	-- Standard World Map is coming to the front: give it the full-size window back.
	function addon:RestoreDefaultMapLayout()
		if not ZO_WorldMap or not defaultLayout then
			return
		end

		local orgZO_WorldMap_UpdateMap = ZO_WorldMap_UpdateMap
		ZO_WorldMap_UpdateMap = NoOp

		if ZO_WorldMap_OnResizeStart then
			ZO_WorldMap_OnResizeStart(ZO_WorldMap)
		end

		RestoreControlLayout(ZO_WorldMap, defaultLayout.map)

		if ZO_WorldMap_OnResizeStop then
			ZO_WorldMap_OnResizeStop(ZO_WorldMap)
		end

		-- Mirror the apply path: the outer window is re-asserted after the resize stop, and
		-- the scroll viewport is restored last so nothing overwrites it.
		RestoreControlLayout(ZO_WorldMap, defaultLayout.map)
		RestoreControlLayout(ZO_WorldMapScroll, defaultLayout.scroll)

		-- Then let the game re-assert whatever the current map mode actually wants. At the
		-- lite init levels this function is unhooked, so it is purely the game's own logic.
		if WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.RefreshMapFrameAnchor then
			WORLD_MAP_MANAGER:RefreshMapFrameAnchor()
		end

		ZO_WorldMap_UpdateMap = orgZO_WorldMap_UpdateMap
	end

	-- The game persists the map window's geometry, and we must not be the one writing it.
	--
	-- ZO_WorldMap_OnResizeStop calls SaveMapPosition, and SetMapWindowSize ends by storing the
	-- new width and height. Both write into WORLD_MAP_MANAGER:GetModeData(), and that table is
	-- g_savedVars[mode] -- the game's own ZO_Ingame_SavedVariables. Both are guarded by
	-- IsInMode(MAP_MODE_SMALL_CUSTOM), so with the map in any other mode they do nothing, and
	-- the logs from this add-on have only ever shown mode 2 (MAP_MODE_LARGE_CUSTOM).
	--
	-- But a player whose map is in the small mode would have the minimap's size and position
	-- written into their saved standard-map geometry, every time the layout was applied, and
	-- it would survive uninstalling this add-on. So the mode data is put back exactly as it
	-- was around anything that could touch it.
	local function CaptureModeData()
		if not WORLD_MAP_MANAGER or not WORLD_MAP_MANAGER.GetModeData then
			return nil
		end
		if not MAP_MODE_SMALL_CUSTOM or not WORLD_MAP_MANAGER:IsInMode(MAP_MODE_SMALL_CUSTOM) then
			return nil
		end
		local modeData = WORLD_MAP_MANAGER:GetModeData()
		if not modeData then
			return nil
		end
		return {
			data = modeData,
			width = modeData.width,
			height = modeData.height,
			point = modeData.point,
			relPoint = modeData.relPoint,
			x = modeData.x,
			y = modeData.y,
		}
	end

	local function RestoreModeData(saved)
		if not saved then
			return
		end
		local modeData = saved.data
		modeData.width, modeData.height = saved.width, saved.height
		modeData.point, modeData.relPoint = saved.point, saved.relPoint
		modeData.x, modeData.y = saved.x, saved.y
	end

	function addon:ApplyLiteMinimapLayout()
		local account = self.account
		if not account or not ZO_WorldMap then
			return
		end
		CaptureDefaultLayout()

		local savedModeData = CaptureModeData()

		-- Everything below is this add-on moving the window on purpose, so the anchor guard
		-- has to let it through.
		self:BeginOwnAnchor()

		-- Skip the full map update while only moving/resizing the window.
		local orgZO_WorldMap_UpdateMap = ZO_WorldMap_UpdateMap
		ZO_WorldMap_UpdateMap = NoOp

		local uiWidth, uiHeight = GuiRoot:GetDimensions()
		local wantW = account.width or 304
		local wantH = account.height or 368
		local wantX = account.x or (uiWidth / 2 - 304)
		local wantY = account.y or (uiHeight / 2 - 368)

		-- Pin the size with the constraints rather than only setting it.
		--
		-- Re-applying the size after the fact was never going to hold: the game resizes the
		-- window later in the same frame than our update runs, so the frame was drawn at the
		-- standard size and only corrected on the next one -- the two sizes alternating at
		-- frame rate. Setting min and max to the same value means any size the game asks for
		-- is clamped to ours, so there is nothing left to correct. RestoreDefaultMapLayout
		-- puts the original constraints back when the standard map takes over.
		--
		-- The resize start/stop pair stays: it is what makes the anchor change take effect.
		-- ZO_WorldMap_OnResizeStop re-applies the size held by the *current* map mode, which
		-- on this path is the standard map's, so the size is asserted again afterwards.
		if ZO_WorldMap_OnResizeStart then
			ZO_WorldMap_OnResizeStart(ZO_WorldMap)
		end

		ZO_WorldMap:ClearAnchors()
		ZO_WorldMap:SetDimensionConstraints(wantW, wantH, wantW, wantH)
		ZO_WorldMap:SetAnchor(CENTER, nil, CENTER, wantX, wantY)
		ZO_WorldMap:SetDimensions(wantW, wantH)

		if ZO_WorldMap_OnResizeStop then
			ZO_WorldMap_OnResizeStop(ZO_WorldMap)
		end

		-- Outer window: size and position both asserted again, and pinned with min == max so
		-- nothing the game does can resize it.
		--
		-- The position has to be put back here too. ZO_WorldMap_OnResizeStop restores what the
		-- *current* map mode holds, and that is a position as well as a size -- on this path,
		-- the standard map's. Only the size was being re-asserted, so the window came up
		-- correctly sized at the full map's position and was moved into place a tick later by
		-- the layout watch: the minimap appearing in the wrong spot and then jumping to its own.
		ZO_WorldMap:ClearAnchors()
		ZO_WorldMap:SetDimensionConstraints(wantW, wantH, wantW, wantH)
		ZO_WorldMap:SetAnchor(CENTER, nil, CENTER, wantX, wantY)
		ZO_WorldMap:SetDimensions(wantW, wantH)

		-- Scroll viewport: pinned as well.
		--
		-- The visible size is the scroll's, not the outer window's. With loose constraints the
		-- map system put it back to full size on the next map update, so the minimap looked
		-- correct until the first step and then snapped to standard map size.
		--
		-- Pinning it was blamed for the off-centre view in 1.2.2, but that turned out to be the
		-- zoom never being applied (it sat at 1.00 regardless of the setting), so the scroll is
		-- pinned again here. RestoreDefaultMapLayout puts its original constraints back when
		-- the standard map takes over.
		if ZO_WorldMapScroll then
			ZO_WorldMapScroll:SetDimensionConstraints(wantW, wantH, wantW, wantH)
			ZO_WorldMapScroll:SetDimensions(wantW, wantH)
		end

		ZO_WorldMap_UpdateMap = orgZO_WorldMap_UpdateMap
		RestoreModeData(savedModeData)
		self:EndOwnAnchor()

		-- The circular style is cut from the viewport just sized above, so it is re-cut here
		-- rather than from a handler on the client's own control (see Compass.lua).
		if self.ApplyLiteMapStyle then
			self:ApplyLiteMapStyle()
		end
	end

	-- Opacity.
	--
	-- Applied to ZO_WorldMap itself, so tiles, pins and frame fade together. The standard map
	-- shares that control, so full opacity has to be handed back the moment it comes forward --
	-- same arrangement as the size, position and pan-past-edge settings.
	function addon:ApplyLiteAlpha()
		if not ZO_WorldMap then
			return
		end
		local account = self.account
		if not account then
			return
		end

		local wantAlpha = 1
		if not self.dormant and (self.initLevel or 0) < 3 and account.enableMap then
			wantAlpha = (account.liteAlpha or 100) / 100
			-- Held transparent until the window is the shape it is supposed to be. The 200ms
			-- watch calls this too, so the gate has to live here rather than at the call site.
			--
			-- Not every settle hides the window. A map change runs the same phases while the
			-- minimap stays on screen: the window keeps its size and place across the change,
			-- so there is nothing misplaced to hide, and blanking it every time the player
			-- crosses a city boundary would be worse than the moment of settling it covers.
			if (self.settleTicks or 0) > 0 and not self.settleVisible then
				wantAlpha = 0
			end
		end

		if zo_abs((ZO_WorldMap:GetAlpha() or 1) - wantAlpha) > 0.005 then
			ZO_WorldMap:SetAlpha(wantAlpha)
		end
	end

	-- Never draw a frame that is wrong.
	--
	-- Measuring the wake-up settled what three rounds of reasoning could not: for about 100ms
	-- after the add-on stands back up the window is visible at the standard map's size and
	-- position, with the hooks live and our layout already applied. The game re-establishes
	-- its own geometry as the fragment is shown, after everything we do, and what actually
	-- puts it right is our own follow tick a tick or two later.
	--
	-- Rather than a fourth guess at which call to pre-empt, the window is simply held
	-- transparent until its geometry matches what was asked for. Whoever moves it and whenever
	-- they do, the player does not see it happen.
	-- keepVisible: run the phases without hiding the window. Used for map changes, where the
	-- window itself does not move and only what is drawn in it has to catch up.
	function addon:BeginLiteSettle(keepVisible)
		if (self.initLevel or 0) >= 3 or not ZO_WorldMap then
			return
		end
		-- A ceiling, not a target: normally this clears on the first or second sample. If the
		-- layout can never be satisfied the map still comes back rather than staying invisible.
		--
		-- The ceiling is only started when there is not one running. Map changes can arrive in
		-- a run -- crossing a city boundary on a mount, or a fast travel that lands next to
		-- one -- and restarting the clock on each would keep the window transparent for as
		-- long as they kept coming. The phases below are reset either way, so a settle already
		-- under way still refreshes and re-clamps for the map that has just arrived; it simply
		-- has to finish within the two seconds the first one started.
		if (self.settleTicks or 0) <= 0 then
			self.settleTicks = 40
			self.settleVisible = keepVisible and true or false
		elseif not keepVisible then
			-- A settle that has to hide the window outranks one that does not: whatever asked
			-- for hiding has something it does not want seen.
			self.settleVisible = false
		end
		self.settleRefreshed = false
		self.settleReclamped = false
		self.settleHold = 0
		self:ApplyLiteAlpha()
	end

	-- Hand the view back to the game and let it decide where it belongs.
	--
	-- This is how the original ends its return to the minimap: StopMovingOrResizing, then
	-- ZO_WorldMap_MouseUp -- the game's own "the cursor is done" path, which re-clamps an
	-- offset sitting outside the map -- and then a move to the player through
	-- ZO_WorldMap_JumpToPlayer. It computes no offset of its own anywhere in that sequence.
	--
	-- Earlier builds called the first two and then overwrote the result with an offset worked
	-- out here from the tile container, which at this moment may still belong to the map the
	-- game was showing a moment ago: the clamp was applied and thrown away in the same breath.
	-- Hence the player's experience, that the map had to be opened and the cursor moved by
	-- hand before the view came right.
	--
	-- The original also switches map mode at this point, which resets the view as a side
	-- effect. That is the route that exhausts the console memory limit, so this stands in.
	function addon:ReclampLiteMapView()
		if ZO_WorldMap and ZO_WorldMap.StopMovingOrResizing then
			ZO_WorldMap:StopMovingOrResizing()
		end
		if ZO_WorldMap_MouseUp then
			ZO_WorldMap_MouseUp()
		end
		if ZO_WorldMap_JumpToPlayer then
			ZO_WorldMap_JumpToPlayer()
		end
	end

	function addon:UpdateLiteSettle()
		local remaining = self.settleTicks or 0
		if remaining <= 0 then
			return
		end
		remaining = remaining - 1

		-- Drive it rather than waiting for the 100ms follow tick to notice the drift. This is
		-- the same work that tick does, just done at the first opportunity, and it stops as
		-- soon as the window agrees -- normally within a sample or two.
		local settled = self:IsLiteSizeCurrent() and self:IsLitePositionCurrent()
		if not settled then
			self:ApplyLiteMinimapLayout()
			settled = self:IsLiteSizeCurrent() and self:IsLitePositionCurrent()
		end
		-- The zoom range is computed from the window size, so it is only worth asking once the
		-- size agrees. AdjustLiteZoom returns true when it had to change something; the map is
		-- only shown once it has nothing left to change.
		if settled then
			-- A custom zoom range sits above the one SetMapZoomMinMax installs, so while one
			-- is in place the range we ask for has no effect on the picture. A view the game
			-- opens for itself leaves one behind, and it can be re-installed after the single
			-- clear on the way out of dormancy. Clearing it for as long as the settle window
			-- lasts covers that without leaving anything running once the map is back.
			if ZO_WorldMap_ClearCustomZoomLevels then
				ZO_WorldMap_ClearCustomZoomLevels()
			elseif self.panZoom and self.panZoom.ClearCustomZoomMimMax then
				self.panZoom:ClearCustomZoomMimMax()
			end
			if self.AdjustLiteZoom and self:AdjustLiteZoom() then
				settled = false
			end
		end

		-- Reload the picture before deciding where to point it.
		--
		-- The window can be the right shape at the right zoom and still be showing the tiles
		-- the previous map loaded -- measured at ten times the size for the same zoom. That
		-- matters beyond how it looks: the offset planted below is computed from the tile
		-- container's dimensions, so a stale container yields an offset far outside the map.
		-- Since the minimap runs with SetAllowPanPastMapEdge(true), nothing pulls that back,
		-- and the view sits off in the blank past the map edge. On the standard map it shows
		-- as exactly that -- a view outside the map's frame that only comes right once the
		-- cursor moves and the game re-clamps it.
		--
		-- The player's own workaround is two separate actions, and both are needed here in the
		-- same order: open the map, which is a full update, and then move the cursor, which
		-- fixes the position. So refresh here, wait for the tiles, and only then plant.
		if settled and not self.settleRefreshed then
			self.settleRefreshed = true
			if ZO_WorldMap_UpdateMap then
				ZO_WorldMap_UpdateMap()
			end
			self.settleHold = 6
			settled = false
		elseif settled and (self.settleHold or 0) > 0 then
			self.settleHold = self.settleHold - 1
			settled = false
		elseif settled and not self.settleReclamped then
			self.settleReclamped = true
			self:ReclampLiteMapView()
			-- The jump is eased, so let it arrive rather than revealing the window mid-slide.
			self.settleHold = 4
			settled = false
		end

		if settled or remaining <= 0 then
			remaining = 0
		end
		self.settleTicks = remaining
		if remaining == 0 then
			-- If the window ran out before the phases got there, hand the view back anyway
			-- rather than revealing one that was never re-clamped.
			if not self.settleReclamped then
				self.settleReclamped = true
				self:ReclampLiteMapView()
			end
			self:ApplyLiteAlpha()
		end
	end

	-- Border.
	--
	-- ZO_WorldMapMapFrame is the game's own frame around the map. Hiding it leaves the map
	-- itself untouched, so the minimap becomes a plain rectangle of map.
	--
	-- Shared with the standard map, so the frame is put back the moment that comes forward --
	-- the same arrangement as size, position, opacity and pan-past-edge.
	function addon:ApplyLiteBorder()
		if self.ApplyLiteMapStyle then self:ApplyLiteMapStyle() end
		if not ZO_WorldMapMapFrame then
			return
		end
		local account = self.account
		if not account then
			return
		end

		local wantHidden = false
		if not self.dormant and (self.initLevel or 0) < 3 and account.enableMap then
			wantHidden = not account.showBorder or account.mapStyle == "compass"
		end

		if ZO_WorldMapMapFrame:IsHidden() ~= wantHidden then
			ZO_WorldMapMapFrame:SetHidden(wantHidden)
		end
	end

	-- Where the minimap sits in the UI stack.
	--
	-- ZO_WorldMap is the standard map's window as well, so the game's own draw order has to be
	-- captured before anything is changed and handed straight back the moment the full map
	-- comes forward -- the same arrangement as size, position, opacity and the border.
	--
	-- Ordering happens within the window's own tier, never by changing it.
	--
	-- The tier is the coarse control -- DT_HIGH would put the map over every other tier, full
	-- screen menus included, which is not what "in front" should mean for a HUD element. So
	-- the captured tier is kept and only the layer inside it moves: DL_OVERLAY draws after the
	-- other HUD controls, DL_BACKGROUND before them. Anything in a higher tier still covers
	-- the minimap, which is the behaviour to want.
	--
	-- "default" restores exactly what the game had rather than assuming what that was.
	local orgDrawTier, orgDrawLayer, orgDrawLevel
	function addon:ApplyLiteDrawOrder()
		if not ZO_WorldMap or not ZO_WorldMap.SetDrawTier then
			return
		end
		local account = self.account
		if not account then
			return
		end

		if orgDrawTier == nil then
			orgDrawTier = ZO_WorldMap:GetDrawTier()
			orgDrawLayer = ZO_WorldMap:GetDrawLayer()
			orgDrawLevel = ZO_WorldMap:GetDrawLevel()
		end

		local order = account.liteDrawOrder or "default"
		if self.dormant or (self.initLevel or 0) >= 3 or not account.enableMap then
			order = "default"
		end

		local wantLayer = orgDrawLayer
		if order == "front" and DL_OVERLAY then
			wantLayer = DL_OVERLAY
		elseif order == "back" and DL_BACKGROUND then
			wantLayer = DL_BACKGROUND
		end

		-- The tier and level are always the game's own; only the layer carries the setting.
		ZO_WorldMap:SetDrawTier(orgDrawTier)
		ZO_WorldMap:SetDrawLayer(wantLayer)
		ZO_WorldMap:SetDrawLevel(orgDrawLevel)
	end

	-- Position only: no resize calls, so it never disturbs the pan offset. Used from the
	-- frame-anchor hook, where the game has just re-anchored the window underneath us.
	-- Refuse the move rather than undo it.
	--
	-- Size never flickers because the game cannot change it: SetDimensionConstraints with
	-- min == max means a size it asks for simply does not take. Position had no equivalent, so
	-- every defence so far has been reactive -- notice it moved, put it back -- and reactive is
	-- always at least one frame late. Correcting per frame narrowed the window and did not
	-- close it, because handler order is not ours to decide and the game can move the window
	-- after we have looked.
	--
	-- So give position the same property. While the minimap is up, anchor changes from anywhere
	-- but this add-on are ignored. Nothing to notice, nothing to hide, nothing to put back.
	--
	-- The guard is off whenever the standard map owns the window, so the game lays its own map
	-- out exactly as it always did.
	local anchorGuardActive = false
	-- A depth rather than a flag: our own anchor calls nest (the layout pass runs through the
	-- same helpers), and a plain boolean would be cleared by the inner one on the way out.
	local ownAnchorDepth = 0
	addon.anchorBlocks = 0

	function addon:SetLiteAnchorGuard(active)
		anchorGuardActive = active and true or false
	end

	-- Whether an anchor change from outside should be refused, decided at the moment of the
	-- call rather than from a flag a timer keeps up to date.
	--
	-- The flag alone was not enough, and got the mirror image of the bug it was meant to fix.
	-- Opening the standard map lays the window out before dormancy has been confirmed -- that
	-- takes up to a sample -- so the game's own anchoring was refused, and the full map could
	-- appear at the minimap's position for those 50ms. Asking the live question closes it:
	-- the moment the map is genuinely being shown, anchor calls go through.
	--
	-- Anchor calls are rare, so this costs nothing measurable.
	local function ShouldRefuseAnchor()
		if not anchorGuardActive or ownAnchorDepth > 0 then
			return false
		end
		if IsWorldMapInFront() then
			return false
		end
		if IsWorldMapShownElsewhere() then
			return false
		end
		return true
	end

	function addon:BeginOwnAnchor()
		ownAnchorDepth = ownAnchorDepth + 1
	end

	function addon:EndOwnAnchor()
		if ownAnchorDepth > 0 then
			ownAnchorDepth = ownAnchorDepth - 1
		end
	end

	-- Per-instance override. Whether it takes is not knowable from here, so everything else
	-- stays in place: if these assignments do not shadow the control's own methods, behaviour
	-- is exactly what it was before.
	function addon:InstallLiteAnchorOverride()
		if self.liteAnchorOverrideInstalled or not ZO_WorldMap then
			return
		end
		local orgSetAnchor = ZO_WorldMap.SetAnchor
		local orgClearAnchors = ZO_WorldMap.ClearAnchors
		if type(orgSetAnchor) ~= "function" or type(orgClearAnchors) ~= "function" then
			return
		end

		ZO_WorldMap.SetAnchor = function(control, ...)
			if ShouldRefuseAnchor() then
				addon.anchorBlocks = addon.anchorBlocks + 1
				return
			end
			return orgSetAnchor(control, ...)
		end
		ZO_WorldMap.ClearAnchors = function(control, ...)
			if ShouldRefuseAnchor() then
				addon.anchorBlocks = addon.anchorBlocks + 1
				return
			end
			return orgClearAnchors(control, ...)
		end

		-- Size needs the same refusal, and it turned out to need it more.
		--
		-- Measurement of the flash showed the anchor correct throughout and the size going
		-- from 274x240 to 769x769. Centred on one anchor, a window that grows expands in every
		-- direction, which is why this read as the minimap appearing where the full map sits.
		-- The position was never the problem.
		--
		-- SetDimensionConstraints with min == max was supposed to make that impossible, and it
		-- does -- right up until the game applies a map mode, which installs constraints of its
		-- own over ours. Once they are gone the size it asks for goes straight through. So the
		-- constraints are defended the same way the anchor is: while the minimap is up, the
		-- game may ask, and the answer is no.
		local orgSetDimensions = ZO_WorldMap.SetDimensions
		local orgSetDimensionConstraints = ZO_WorldMap.SetDimensionConstraints
		if type(orgSetDimensions) == "function" and type(orgSetDimensionConstraints) == "function" then
			ZO_WorldMap.SetDimensions = function(control, ...)
				if ShouldRefuseAnchor() then
					addon.anchorBlocks = addon.anchorBlocks + 1
					return
				end
				return orgSetDimensions(control, ...)
			end
			ZO_WorldMap.SetDimensionConstraints = function(control, ...)
				if ShouldRefuseAnchor() then
					addon.anchorBlocks = addon.anchorBlocks + 1
					return
				end
				return orgSetDimensionConstraints(control, ...)
			end
		end

		self.liteAnchorOverrideInstalled = true
	end

	function addon:ApplyLiteAnchorOnly()
		local account = self.account
		if not account or not ZO_WorldMap then
			return
		end
		local wantX, wantY = account.x, account.y
		if not wantX or not wantY then
			local uiWidth, uiHeight = GuiRoot:GetDimensions()
			wantX = wantX or (uiWidth / 2 - 304)
			wantY = wantY or (uiHeight / 2 - 368)
		end

		self:BeginOwnAnchor()
		ZO_WorldMap:ClearAnchors()
		ZO_WorldMap:SetAnchor(CENTER, nil, CENTER, wantX, wantY)
		self:EndOwnAnchor()
	end

	-- The game re-anchors and re-sizes ZO_WorldMap on its own (RefreshMapFrameAnchor and the
	-- map mode's saved size), which is why a one-shot ApplyLiteMinimapLayout does not stick.
	-- The original add-on solves this by hooking RefreshMapFrameAnchor, but hooks installed by
	-- InitMiniMap are exactly what blows the console memory limit, so instead the layout is
	-- simply re-asserted whenever it has drifted. No hooks, and self-healing against whatever
	-- else moves the window.
	-- Backoff so that a size the game refuses to honour cannot turn into a re-apply every
	-- 200ms forever. Reset whenever the user actually changes a setting.
	local failedAttempts = 0
	function addon:ResetLiteLayoutBackoff()
		failedAttempts = 0
	end
	-- Both size and anchor have to be checked. Only comparing dimensions meant that when the
	-- game re-anchored ZO_WorldMap without resizing it -- which is what happens on the way back
	-- from the settings screen -- the size still matched, so the drift went unnoticed and the
	-- window stayed at the old position.
	-- Size and position are checked separately, because putting them right costs very
	-- different amounts.
	--
	-- Re-applying the size runs ZO_WorldMap_OnResizeStart/Stop, which makes the map lay itself
	-- out again. Re-applying the position is two calls and disturbs nothing. Coming back from
	-- a full-screen scene it is usually only the position that has drifted, so treating that
	-- as a full re-layout put a burst of map work right where the UI was trying to return --
	-- felt as the inventory screen being slow to close.
	local function LiteSizeMatches(account)
		local wantW = account.width or 304
		local wantH = account.height or 368
		local haveW, haveH = ZO_WorldMap:GetDimensions()
		if zo_abs(haveW - wantW) > 0.5 or zo_abs(haveH - wantH) > 0.5 then
			return false
		end

		-- The scroll is the control whose size is actually visible, so drift there matters
		-- just as much as drift on the outer window.
		if ZO_WorldMapScroll then
			local scrollW, scrollH = ZO_WorldMapScroll:GetDimensions()
			if zo_abs(scrollW - wantW) > 0.5 or zo_abs(scrollH - wantH) > 0.5 then
				return false
			end
		end
		return true
	end

	local function LitePositionMatches(account)
		-- Read the anchor first and the screen only if it is needed.
		--
		-- This runs on the 50ms watch, and GuiRoot:GetDimensions() is only there to work out
		-- a default for a position that has not been set. Once the player has placed the
		-- minimap -- which is the case whenever this matters -- it is a wasted call on every
		-- sample. A mismatched anchor point is likewise decided without knowing the offsets.
		local isValid, point, _, relativePoint, offsetX, offsetY = ZO_WorldMap:GetAnchor(0)
		if not isValid or point ~= CENTER or relativePoint ~= CENTER then
			return false
		end

		local wantX, wantY = account.x, account.y
		if not wantX or not wantY then
			local uiWidth, uiHeight = GuiRoot:GetDimensions()
			wantX = wantX or (uiWidth / 2 - 304)
			wantY = wantY or (uiHeight / 2 - 368)
		end
		if zo_abs(offsetX - wantX) > 0.5 or zo_abs(offsetY - wantY) > 0.5 then
			return false
		end
		-- A second anchor would drive the geometry instead of our single centred one.
		if ZO_WorldMap:GetAnchor(1) then
			return false
		end
		return true
	end

	local function LiteLayoutMatches(account)
		return LiteSizeMatches(account) and LitePositionMatches(account)
	end

	function addon:IsLiteSizeCurrent()
		local account = self.account
		if not account or not ZO_WorldMap or ZO_WorldMap:IsHidden() then
			return true
		end
		return LiteSizeMatches(account)
	end

	function addon:IsLitePositionCurrent()
		local account = self.account
		if not account or not ZO_WorldMap or ZO_WorldMap:IsHidden() then
			return true
		end
		return LitePositionMatches(account)
	end

	function addon:MaintainLiteMinimapLayout()
		if self.dormant then
			-- Standard World Map is in front: leave it at full size.
			return
		end
		-- Same window as the follow tick guards: the game has the map up for its own purposes
		-- and dormancy has not been confirmed yet. Resizing it now resizes the game's view.
		if self.IsWorldMapShownElsewhere and self.IsWorldMapShownElsewhere() then
			return
		end
		local account = self.account
		if not account or not ZO_WorldMap or ZO_WorldMap:IsHidden() then
			return
		end
		if LiteLayoutMatches(account) then
			failedAttempts = 0
			return
		end

		-- Position-only drift takes the cheap path: no resize, so no map re-layout.
		if LiteSizeMatches(account) then
			failedAttempts = 0
			self:ApplyLiteAnchorOnly()
			return
		end

		if failedAttempts >= 5 then
			return
		end
		failedAttempts = failedAttempts + 1
		self:ApplyLiteMinimapLayout()
	end

	-- Keep the player centred on the lite minimap.
	--
	-- Two parts are needed, not one: centring only has an effect once the map is zoomed in
	-- far enough that there is something to pan. Fully zoomed out the whole zone fits in the
	-- window, the pan offset clamps, and the player sits wherever the zone puts them.
	--
	-- Everything here is gated on "not dormant", so none of it runs while the standard World
	-- Map is in front -- the full Tamriel view stays untouched.
	local lastPlayerX, lastPlayerY = -1, -1
	local lastMapTile
	local lastContainerW, lastContainerH = -1, -1
	local forceMapResync = false
	local nextMapResyncMs = 0
	function addon:ResetFollowState()
		lastPlayerX, lastPlayerY = -1, -1
		lastMapTile = nil
		lastContainerW, lastContainerH = -1, -1
	end

	-- Crossing between a city and the open world does not always leave
	-- DoesCurrentMapMatchMapForPlayerLocation() reporting a mismatch, so on its own that check
	-- let the minimap sit on the area just left. The zone events force a resync on the next
	-- tick, and the tile texture is watched as a second signal for map changes that arrive
	-- without an event.
	function addon:RequestMapResync()
		forceMapResync = true
		nextMapResyncMs = 0
	end

	-- Switching the map is two steps, not one.
	--
	-- SetMapToPlayerLocation only changes which map is selected; the tiles and pins on screen
	-- are refreshed by the OnWorldMapChanged callbacks. Without firing those, the selection
	-- moved but the picture stayed on the area just left -- which is exactly the symptom. The
	-- original add-on does the same pairing wherever it calls SetMapToPlayerLocation itself.
	local function ApplyMapToPlayer()
		local result = SetMapToPlayerLocation()
		addon.lastSetMapResult = result
		if result == SET_MAP_RESULT_MAP_CHANGED then
			CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
			if ZO_WorldMap_UpdateMap then
				ZO_WorldMap_UpdateMap()
			end

			-- A different map is a different picture, a different tile set and a different
			-- zoom, and the view is still pointed where it was on the last one. That is the
			-- same position the add-on is in coming back from a map the game opened, and it
			-- is why the zoom comes out wrong crossing between a city and the open world --
			-- reported twice, and treated then as a fault in the zoom arithmetic.
			--
			-- No dormancy transition happens here, so nothing was starting a settle. Start one:
			-- hold the window until the layout and zoom agree, refresh the tiles, hand the view
			-- back to the game, and only then show it.
			if addon.BeginLiteSettle and (addon.initLevel or 0) < 3 then
				addon:BeginLiteSettle(true)
			end
		end
		return result
	end

	function addon:StartLiteZoneWatch()
		local function resync()
			self:RequestMapResync()
			self:UpdateZoneTitle()
		end
		-- The original restores its position on this one, and we were not listening at all.
		-- The preferred mode flipping is already known to move things here: it is what picks
		-- the scene the dormancy check looks at, and a flip mid-frame was the cause of the
		-- wayshrine view being torn down in 1.9.17.
		if EVENT_GAMEPAD_PREFERRED_MODE_CHANGED then
			em:RegisterForEvent(
				self.name .. "LiteInputMode",
				EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,
				function()
					if not self.dormant and self.ApplyLiteAnchorOnly then
						self:ApplyLiteAnchorOnly()
					end
				end
			)
		end
		em:RegisterForEvent(self.name .. "LiteZone", EVENT_ZONE_CHANGED, resync)
		em:RegisterForEvent(
			self.name .. "LiteActivated",
			EVENT_PLAYER_ACTIVATED,
			resync
		)
		-- Not present on every API version, so only wire it up when it exists.
		if EVENT_LINKED_WORLD_POSITION_CHANGED then
			em:RegisterForEvent(self.name .. "LiteLinked", EVENT_LINKED_WORLD_POSITION_CHANGED, resync)
		end
	end

	-- Which zoom setting applies right now.
	--
	-- Indoors the game swaps to a much smaller map (a building or city is MAPTYPE_SUBZONE, a
	-- dungeon is MAP_CONTENT_DUNGEON). A zoom level that frames a whole zone nicely is far too
	-- close on one of those, so each context gets its own setting -- the same split the
	-- original add-on makes.
	-- Zoom on a small window is not set through SetCurrentNormalizedZoom.
	--
	-- That call is gated, and even when it is not, normalized zoom is a position inside the
	-- map's allowed zoom range -- a range the game computed for a full-screen map. In a 314px
	-- window that range is meaningless, which is why the reading sat at 1.00 no matter what
	-- was requested and an arbitrary magnified corner was on screen.
	--
	-- The original add-on does it the other way round: it computes what the maximum zoom
	-- should be for this window from the map's real tile resolution, installs it with
	-- SetMapZoomMinMax, and leaves the normalized zoom at maximum. The setting is therefore a
	-- scale relative to the map's native resolution, not a 0..1 position. Same approach here.
	local MIN_SCALE = 0.05

	local function CurrentZoomContext()
		local contentType = GetMapContentType()
		if contentType == MAP_CONTENT_BATTLEGROUND then
			return "bg"
		elseif contentType == MAP_CONTENT_DUNGEON then
			return "dungeon"
		elseif MAP_CONTENT_AVA and contentType == MAP_CONTENT_AVA and GetMapType() == MAPTYPE_SUBZONE then
			-- The Imperial City districts, and only those.
			--
			-- Both halves of the test are needed. AvA on its own is also Cyrodiil, which is an
			-- ordinary outdoor zone as far as the zoom is concerned and should stay on the
			-- outdoor setting. Subzone on its own is every building and city in the game. The
			-- districts are the intersection: AvA content drawn on a subzone map.
			--
			-- This has to come before the plain subzone test, or the districts fall into it --
			-- which is what happened in 2.0.16, and why the new setting appeared to do nothing.
			return "ava"
		elseif GetMapType() == MAPTYPE_SUBZONE then
			return "subzone"
		end
		return "outdoor"
	end
	addon.CurrentZoomContext = CurrentZoomContext

	local function CurrentScale(account)
		local function clamp(value)
			if not value or value < MIN_SCALE then
				return MIN_SCALE
			end
			return value
		end
		local context = CurrentZoomContext()
		if context == "bg" then
			return clamp(account.liteScaleBattleground or account.liteScale)
		elseif context == "dungeon" then
			return clamp(account.liteScaleDungeon or account.liteScale)
		elseif context == "subzone" then
			return clamp(account.liteScaleSubZone or account.liteScale)
		elseif context == "ava" then
			return clamp(account.liteScaleAva or account.liteScale)
		end
		return clamp(account.liteScale)
	end
	addon.CurrentZoomLevel = function(self)
		return CurrentScale(self.account)
	end

	-- Returns true when it changed the zoom range, i.e. when the pan needs re-centring.
	-- The zoom the settings ask for, as a range, without applying anything. Split out of
	-- AdjustLiteZoom so the diagnostics can report what would be asked for and compare it
	-- against both the installed range and the zoom the map is actually drawn at.
	--
	-- Returns max first: max is the zoom that was asked for, min only the floor under it.
	function addon:ComputeLiteZoomTarget()
		local account = self.account
		local panZoom = self.panZoom
		if not account or not panZoom or not ZO_WorldMapScroll then
			return nil
		end

		local w, h = ZO_WorldMapScroll:GetDimensions()
		w, h = zo_round(w), zo_round(h)
		local mapAreaUIUnits = zo_min(w, h)
		if mapAreaUIUnits < 1 then
			return nil
		end

		local targetScale = CurrentScale(account)

		-- Do not compute from tile data that is not there yet.
		--
		-- Crossing between a city and the open world, the tile count can already be the new
		-- map's while the container still holds the old texture, or none at all. Substituting
		-- a tile width of 1 there is not a fallback so much as a made-up number: it produces a
		-- wildly wrong zoom, which then gets installed and defended.
		--
		-- Nothing is remembered on this path, so the next tick simply tries again.
		local numTiles = GetMapNumTiles()
		local tilePixelWidth = ZO_WorldMapContainer1 and ZO_WorldMapContainer1:GetTextureFileDimensions()
		if not numTiles or numTiles < 1 or not tilePixelWidth or tilePixelWidth < 2 then
			return nil
		end
		local totalPixels = numTiles * tilePixelWidth
		local mapAreaPixels = mapAreaUIUnits * GetUIGlobalScale()
		if mapAreaPixels < 1 then
			mapAreaPixels = 1
		end

		-- r is the fit zoom: 1 for a square window, a little over 1 to compensate for a
		-- non-square one. native is the zoom that would show the map at its own resolution.
		local r = zo_max(w, h) / mapAreaUIUnits
		local native = totalPixels / mapAreaPixels

		-- The original interpolates between fit and native, which assumes the map texture is
		-- higher resolution than the window. On the small building and city maps it is not:
		-- native comes out below fit, the interpolation runs backwards, and turning the
		-- setting up zoomed OUT instead of in.
		--
		-- Interpolating from fit also means fit is the floor: no setting, however low, can
		-- show more of the map than exactly fills the window. Indoors that is still too close.
		--
		-- So the setting is a plain multiplier on the reference zoom instead. 1.0 draws the
		-- map at that reference, lower draws it smaller -- below fit if asked, with empty
		-- space around it -- and higher magnifies. Monotonic everywhere, and nothing special
		-- happens at the fit boundary.
		local reference = zo_max(native, r * 3)
		local maxZoom = math.floor(reference * targetScale * 500) / 500
		if maxZoom < 0.01 then
			maxZoom = 0.01
		end

		-- The lower bound has to be allowed below ComputeMinZoom().
		--
		-- That is the game's idea of the least zoom that still fills the window, and on the
		-- small building and city maps it comes out higher than the zoom being asked for. The
		-- range was then inverted, the zoom stuck to the floor, and turning the setting down
		-- to 0.1 changed nothing -- which is exactly the reported symptom.
		--
		-- Taking the smaller of the two lets the map be drawn smaller than the window, with
		-- empty space around it, which is the whole point of zooming out indoors.
		local minZoom = panZoom:ComputeMinZoom()
		if not minZoom or minZoom > maxZoom then
			minZoom = maxZoom
		end

		return maxZoom, minZoom
	end

	function addon:AdjustLiteZoom()
		local panZoom = self.panZoom
		if not panZoom then
			return false
		end
		local maxZoom, minZoom = self:ComputeLiteZoomTarget()
		if not maxZoom or not minZoom then
			return false
		end

		-- No cache on the inputs. Recompute every tick and compare against what is installed.
		--
		-- Caching on the inputs had a hole that survived two attempts to close it. The
		-- verification added earlier only asks "is the range I computed still installed?", so
		-- a value computed from inputs that were valid but stale -- the new map's tile count
		-- with the old map's texture width, or GetMapType() not yet switched over on a
		-- city/field boundary -- was cached and then defended indefinitely. Nothing changed
		-- afterwards to invalidate it, which is why waiting did not help.
		--
		-- Recomputing costs a handful of cheap API calls at 10Hz and removes the failure mode
		-- entirely: the moment any input settles, the computed value changes and is applied.
		local installedMin, installedMax
		if panZoom.GetZoomMinMax then
			installedMin, installedMax = panZoom:GetZoomMinMax()
		end
		local rangeIsCurrent =
			installedMax ~= nil and
			zo_abs(installedMax - maxZoom) <= 0.005 and
			(installedMin == nil or zo_abs(installedMin - minZoom) <= 0.005)

		if not rangeIsCurrent then
			panZoom:SetMapZoomMinMax(minZoom, maxZoom)
		end

		-- Sit at the top of the range: maxZoom is the zoom that was asked for.
		--
		-- This is checked whether or not the range needed changing. The range and the position
		-- within it move independently, and the game does move the position on its own while
		-- leaving the range alone -- which is what happens coming back from a map it opened
		-- itself. Returning early on a matching range skipped this, so the minimap held
		-- whatever zoom that view had left behind and never recovered: nothing later changed
		-- the range, so nothing brought this line back into play.
		local restored = false
		if panZoom.GetCurrentNormalizedZoom then
			local normalized = panZoom:GetCurrentNormalizedZoom()
			if normalized and normalized < 0.995 then
				if panZoom.SetCurrentNormalizedZoomInternal then
					panZoom:SetCurrentNormalizedZoomInternal(1)
				elseif panZoom.SetCurrentNormalizedZoom then
					panZoom:SetCurrentNormalizedZoom(1)
				end
				restored = true
			end
		end

		-- True means "the view moved, re-centre after this", so both routes count.
		return (not rangeIsCurrent) or restored
	end

	-- Putting the player in the middle.
	--
	-- ZO_WorldMap_JumpToPlayer alone was not doing it: the view stayed where it was and the
	-- player simply walked out of the middle, which is why it looked right immediately after
	-- closing the full map and drifted from the first step. It seems to depend on map state we
	-- do not have on the HUD.
	--
	-- Rather than guess at one replacement, try the routes in order of directness and remember
	-- which one worked. The chosen route is reported once in the debug log, so if this still
	-- misbehaves the answer is in the log rather than in another round of guessing.
	-- Putting the player in the middle, written against the API this build actually has
	-- (dumped via DumpPanZoomApi).
	--
	-- The earlier attempts failed for two separate reasons. SetCurrentOffset on its own is
	-- undone by the next Update, which eases the current offset back towards the pending
	-- target -- and the "clear the target" code was assigning made-up field names instead of
	-- calling ClearTargetOffset. Meanwhile PanToNormalizedPosition, the call actually built
	-- for this, was never reached because the SetCurrentOffset branch matched first.
	local centreRoute
	function addon:CentreOnPlayer(normalizedX, normalizedY)
		self.centreCalls = (self.centreCalls or 0) + 1

		local panZoom = self.panZoom
		if not panZoom then
			return
		end

		local function route(name)
			if centreRoute ~= name then
				centreRoute = name
				self:ReportCentreRoute(name)
			end
		end

		-- 1. The purpose-built call. It routes through GetNormalizedPositionFocusZoomAndOffset,
		-- which we override, so it lands on our centred offsets and follows the game's own
		-- sequencing rather than fighting it.
		if panZoom.PanToNormalizedPosition then
			panZoom:PanToNormalizedPosition(normalizedX, normalizedY)
			route("PanToNormalizedPosition")
			return
		end

		-- 2. Drive the offsets directly, cancelling any pan already in flight first -- this
		-- time through the real ClearTargetOffset entry point.
		if panZoom.GetNormalizedPositionFocusZoomAndOffset and panZoom.SetCurrentOffset then
			local _, offsetX, offsetY = panZoom:GetNormalizedPositionFocusZoomAndOffset(normalizedX, normalizedY)
			if offsetX and offsetY then
				if panZoom.ClearTargetOffset then
					panZoom:ClearTargetOffset()
				end
				if panZoom.ClearJumpToPinWhenAvailable then
					panZoom:ClearJumpToPinWhenAvailable()
				end
				panZoom:SetCurrentOffset(offsetX, offsetY)
				-- SetFinalTargetOffset is deliberately not called here either; see
				-- CentreOnPlayerHard. Clearing the target and then setting a target offset
				-- walks into ComputeCurvedZoom with no zoom to ease towards. This route has
				-- not thrown only because route 1 above always wins.
				route("SetCurrentOffset")
				return
			end
		end

		-- 3. The global helper, which is where this started.
		if ZO_WorldMap_JumpToPlayer then
			ZO_WorldMap_JumpToPlayer()
			route("ZO_WorldMap_JumpToPlayer")
		end
	end

	-- What ZO_MapPanAndZoom actually offers.
	--
	-- The first attempt printed nothing, because it only looked at getmetatable(panZoom).__index
	-- and gave up unless that was a table -- yet SetCurrentOffset clearly resolves, so the
	-- methods live somewhere else. This walks the whole metatable chain, also lists functions
	-- sitting directly on the object, and says what it found, so a blank result is now
	-- distinguishable from a lookup that went the wrong way.
	function addon:DumpPanZoomApi()
		local panZoom = self.panZoom
		if not panZoom then
			df("[PBsMiniMap] panZoom is nil")
			return
		end

		local function emitList(label, items)
			if #items == 0 then
				df("[PBsMiniMap] %s: (none)", label)
				return
			end
			table.sort(items)
			local line = ""
			for index = 1, #items do
				local piece = items[index]
				if #line + #piece + 2 > 180 then
					df("[PBsMiniMap] %s: %s", label, line)
					line = piece
				else
					line = (#line > 0) and (line .. ", " .. piece) or piece
				end
			end
			df("[PBsMiniMap] %s: %s", label, line)
		end

		df("[PBsMiniMap] panZoom type=%s meta=%s", type(panZoom), type(getmetatable(panZoom)))

		local methods, fields, seen = {}, {}, {}
		local function collect(source, depth)
			if type(source) ~= "table" or seen[source] or depth > 6 then
				return
			end
			seen[source] = true
			for key, value in pairs(source) do
				local name = tostring(key)
				if type(value) == "function" then
					if not seen["m" .. name] then
						seen["m" .. name] = true
						methods[#methods + 1] = name
					end
				elseif type(value) ~= "table" and depth == 0 then
					fields[#fields + 1] = string.format("%s=%s", name, tostring(value))
				end
			end

			local meta = getmetatable(source)
			if type(meta) == "table" then
				collect(rawget(meta, "__index"), depth + 1)
				collect(meta, depth + 1)
			end
		end
		collect(panZoom, 0)

		emitList("panZoom methods", methods)
		emitList("panZoom fields", fields)
	end

	function addon:ReportCentreRoute(route)
		self.centreRoute = route
		if self.account and self.account.debug then
			df("[PBsMiniMap] centring via %s", tostring(route))
		end
	end

	-- The picture can change without the map changing.
	--
	-- A settle is started on SET_MAP_RESULT_MAP_CHANGED, and a dungeon floor swap is not that:
	-- the map id stays the same and only the tiles under it are replaced. The zoom is computed
	-- from those tiles, so it comes out for the floor that has just been left, and the view is
	-- still pointed where it was -- the same failure the antiquity route had, reached by a
	-- different door.
	--
	-- So watch what actually decides the picture rather than the map's identity. Three numbers,
	-- no allocation, on the 100ms tick.
	local lastMapId, lastFloor, lastTiles
	function addon:CheckLiteMapPicture()
		local mapId = (GetCurrentMapId and GetCurrentMapId()) or 0
		local floor = (GetMapFloorInfo and GetMapFloorInfo()) or 0
		local tiles = (GetMapNumTiles and GetMapNumTiles()) or 0
		if mapId == lastMapId and floor == lastFloor and tiles == lastTiles then
			return
		end

		local first = lastMapId == nil
		lastMapId, lastFloor, lastTiles = mapId, floor, tiles
		-- Nothing to settle on the first reading: there was no previous picture to differ from.
		if first or not self.BeginLiteSettle then
			return
		end
		-- Visible: the window itself does not move for this, only what is drawn in it.
		self:BeginLiteSettle(true)
	end

	function addon:FollowPlayerTick()
		self.followTicks = (self.followTicks or 0) + 1

		if self.dormant then
			self.followSkip = "dormant"
			return
		end
		-- Not dormant yet, but the game already has the map up for something of its own.
		--
		-- Standing down takes a couple of samples to confirm, deliberately: acting on a single
		-- reading would detach the minimap on every menu transition. This tick runs at 100ms
		-- and lands inside that window, and everything it does it does to the game's view --
		-- SetMapToPlayerLocation most of all, which replaces the map the game has just chosen
		-- with the player's own. That is how the map opened by antiquity scrying came up as
		-- the city the player was standing in instead of the field it had picked.
		--
		-- The confirmation stays where it is; what is guarded is the acting on it.
		if self.IsWorldMapShownElsewhere and self.IsWorldMapShownElsewhere() then
			self.followSkip = "foreign"
			return
		end

		-- Before anything is computed from the map: has the picture underneath changed?
		--
		-- Ahead of the followPlayer guard, because a floor swap gets the zoom wrong whether or
		-- not the player is being followed, and behind a visibility check, because there is
		-- nothing to settle while the window is not on screen.
		if ZO_WorldMap and not ZO_WorldMap:IsHidden() then
			self:CheckLiteMapPicture()
		end
		local account = self.account
		if not account or not account.followPlayer then
			self.followSkip = "off"
			return
		end
		if not ZO_WorldMap then
			self.followSkip = "nomap"
			return
		end
		if ZO_WorldMap:IsHidden() then
			self.followSkip = "hidden"
			return
		end
		self.followSkip = "-"


		-- Order matters, and getting it wrong is what caused the centred/not-centred flicker:
		-- re-asserting the layout runs the map through a resize, which resets the pan offset.
		-- Doing that after centring meant every frame ended off-centre, and the next frame
		-- re-centred it, at frame rate. So centring has to be the LAST thing in the frame.
		--
		--   1. put the map on the player's own map
		--   2. hold the zoom
		--   3. restore our size and position   (may reset the pan)
		--   4. centre on the player            (always last)

		-- 1. Stay on the player's own map; walking into a new zone otherwise leaves the
		-- minimap showing the old one.
		local disturbed = false

		local mapTile = GetMapTileTexture()
		if mapTile ~= lastMapTile then
			-- The map changed underneath us: the zoom range was computed for the old one.
			lastMapTile = mapTile
			lastPlayerX, lastPlayerY = -1, -1
			disturbed = true
		end

		-- Retry missing/invalid positions, but do not continually reload the correct map
		-- solely because its visibility flag is false (observed in the Shadow Cleft).
		local x, y, _, shown, symbolic = GetMapPlayerPosition("player")
		local now = GetFrameTimeMilliseconds()
		local needsMap = not DoesCurrentMapMatchMapForPlayerLocation()
			or not self:IsLitePlayerPositionUsable(x, y, shown, symbolic)
		if forceMapResync or (needsMap and now >= nextMapResyncMs) then
			forceMapResync = false
			nextMapResyncMs = now + 1000
			ApplyMapToPlayer()
			lastMapTile = GetMapTileTexture()
			lastPlayerX, lastPlayerY = -1, -1
			disturbed = true
		end

		-- 2. Hold the requested zoom. Re-asserted rather than set once, because the game
		-- resets it on map changes.
		-- 2. Hold the zoom range for this window. Only does work when the window size, the
		-- map or the applicable setting actually changed.
		if self:AdjustLiteZoom() then
			disturbed = true
		end

		-- 3. Restore our size and position, cheapest route first. Position-only drift is put
		-- right with two anchor calls and disturbs nothing; a size change means a real
		-- re-layout, which also throws the pan away, so that one has to be re-centred after.
		self:ResetLiteLayoutBackoff()
		-- Size and position are asked separately, so the comparisons run once each. Checking
		-- the combined state first and then the size again repeated half of them every tick.
		if not self:IsLiteSizeCurrent() then
			self:ApplyLiteMinimapLayout()
			disturbed = true
		elseif not self:IsLitePositionCurrent() then
			self:ApplyLiteAnchorOnly()
		end

		-- 4. Centre on the player. Done whenever they moved, and also whenever anything above
		-- disturbed the map, since that is exactly when the pan offset was thrown away.
		-- The map's drawn size is what centring is measured against, so a change in it means
		-- the previous centring was computed against something else.
		--
		-- This is what left the player off-centre until the first step after a reload: the
		-- first tick ran before the container had been laid out, centred against nothing
		-- useful, and recorded the player position as done -- after which "has the player
		-- moved?" stayed false and it was never retried.
		local containerW, containerH = -1, -1
		if ZO_WorldMapContainer then
			containerW, containerH = ZO_WorldMapContainer:GetDimensions()
		end
		if containerW <= 0 or containerH <= 0 then
			-- Not laid out yet. Leave lastPlayer* alone so the next tick still counts as moved.
			self.followSkip = "nolayout"
			return
		end
		if zo_abs(containerW - lastContainerW) > 0.5 or zo_abs(containerH - lastContainerH) > 0.5 then
			lastContainerW, lastContainerH = containerW, containerH
			disturbed = true
		end

		x, y, _, shown, symbolic = GetMapPlayerPosition("player")
		if not self:IsLitePlayerPositionUsable(x, y, shown, symbolic) then
			-- Do not pan to a loading sentinel or a parent-map entrance marker. Leave the
			-- position dirty so recovery also recentres a player who has not moved.
			lastPlayerX, lastPlayerY = -1, -1
			self.followSkip = "noposition"
			return
		end
		-- If a scene/map transition left the pin hidden, restore just this pin using
		-- the same operations as UpdateMovingPins.
		-- The position check also accepts the own-map visibility discrepancy above.
		local playerPin = self.pinManager and self.pinManager:GetPlayerPin()
		if playerPin and playerPin:IsHidden() then
			playerPin:SetOriginalPosition(x, y)
			playerPin:SetIsSymbolicPosition(symbolic)
			playerPin:SetLocation(x, y)
			playerPin:SetRotation(GetPlayerCameraHeading())
			playerPin:SetHidden(false)
		end
		local moved = x and (zo_abs(x - lastPlayerX) >= 0.00005 or zo_abs(y - lastPlayerY) >= 0.00005)
		if (moved or disturbed) and x then
			lastPlayerX, lastPlayerY = x, y
			self:CentreOnPlayer(x, y)
		end

		-- The sweep itself has moved to the maintenance pass. A map change is when the game
		-- puts these labels back, so ask for one then rather than walking the tree every tick.
		if disturbed and account.hideMapLabels then
			self:RequestLabelSweep()
		end
	end

	-- Hooks the lite path needs. InitMiniMap is skipped at this level, so without these the
	-- game owns behaviour we have to take over:
	--
	--  * RefreshMapFrameAnchor re-anchors and re-sizes ZO_WorldMap whenever the map updates.
	--    Following the player updates the map constantly, so the window was being reset to the
	--    standard map size several times a second.
	--  * CanMapZoom decides whether a zoom change is allowed at all. On the HUD the game says
	--    no, so every frame we asked for a zoom, were refused, and asked again -- a permanent
	--    tug of war that never let the map finish an update, which is why the player pin never
	--    appeared.
	--
	-- Both are registered as hot-path hooks, so dormancy swaps them back to the game's own
	-- versions while the standard World Map is in front. Nothing of ours is installed during
	-- the full Tamriel view.
	local function LiteMinimapActive()
		return (addon.initLevel or 0) < 3 and not addon.dormant and addon.account and addon.account.enableMap
	end

	function addon:InitLiteHooks()
		self:InitLitePlayerPinVisibilityHook()
		-- Our focus offsets are deliberately unclamped, but the pan machinery clamps again on
		-- its own unless this is set. Captured here so dormancy can hand the original value
		-- back to the standard map.
		if self.panZoom and self.orgAllowPanPastMapEdge == nil then
			self.orgAllowPanPastMapEdge = self.panZoom.allowPanPastMapEdge or false
			-- Apply it now as well: dormancy only toggles it on a transition, and at startup
			-- there has not been one.
			self:SetAllowPanPastMapEdge(true)
		end

		local orgRefreshMapFrameAnchor
		orgRefreshMapFrameAnchor =
			HookHotPath(
			ZO_WorldMapManager,
			"RefreshMapFrameAnchor",
			function(manager, ...)
				local result = orgRefreshMapFrameAnchor(manager, ...)
				if LiteMinimapActive() then
					-- Suppressing this entirely also stopped the internal layout work the pin
					-- system depends on, and the player pin stopped appearing. Let it run and
					-- only put our position back afterwards -- the size is already held by the
					-- dimension constraints, and this touches nothing else.
					addon:ApplyLiteAnchorOnly()
				end
				return result
			end
		)

		local orgCanMapZoom
		orgCanMapZoom =
			HookHotPath(
			self.panZoom,
			"CanMapZoom",
			function(...)
				return orgCanMapZoom(...) or LiteMinimapActive() or false
			end
		)

		-- Place names.
		--
		-- The labels drawn across the map ("Elden Root", "Snugpod", ...) come from
		-- ZO_MapLocationPins_Manager. On a full-screen map they are useful; squeezed into a
		-- 300px minimap they cover most of it.
		--
		-- Suppress the refresh rather than deleting the labels afterwards, so none are built
		-- in the first place. Registered as a hot-path hook like the rest, so the standard map
		-- gets the game's own version back and keeps its names.
		if ZO_MapLocationPins_Manager then
			local orgRefreshLocations
			orgRefreshLocations =
				HookHotPath(
				ZO_MapLocationPins_Manager,
				"RefreshLocations",
				function(manager, ...)
					-- The only place the live pool is reachable from.
					addon.locationPinManager = manager

					-- Let the game build its location pins.
					--
					-- This used to suppress the call outright and release the pool instead,
					-- which is not hiding names but refusing to have the pins at all -- and
					-- the merchant and service icons the standard map shows are those pins.
					-- The same deletion had a second home in ClearMapLocationLabels, removed
					-- in 1.9.33; this one kept doing it on every refresh, which is why that
					-- changed nothing.
					--
					-- The names are hidden afterwards, by the sweep that hides each pin's
					-- Label child and leaves the pin alone.
					local result = orgRefreshLocations(manager, ...)
					if LiteMinimapActive() and addon.account and addon.account.hideMapLabels then
						addon:RequestLabelSweep()
					end
					return result
				end
			)
		end

		-- Centring the player needs this one too.
		--
		-- ZO_WorldMap_JumpToPlayer does not position the map itself: it asks the pan machinery
		-- to focus a normalized position, and the machinery works out the offsets through
		-- GetNormalizedPositionFocusZoomAndOffset. Left as the game's own version, that returns
		-- offsets that frame the map the way the full-screen map wants -- which is why the
		-- centre of the minimap was the centre of the map rather than the player, most
		-- obviously on the small subzone maps.
		--
		-- This is the same override the original add-on installs; the maths is its
		-- FocusZoomAndOffset, which is what actually puts a given point in the middle.
		local function IsNormalizedPointInsideMapBounds(x, y)
			return x > 0 and x < 1 and y > 0 and y < 1
		end

		local function FocusZoomAndOffset(panZoom, normalizedX, normalizedY)
			if not (normalizedX and normalizedY and IsNormalizedPointInsideMapBounds(normalizedX, normalizedY)) then
				return nil
			end

			local targetNormalizedZoom = 1

			-- Offsets are a displacement of the map's centre from the viewport's centre, so
			-- what matters is how large the map is actually drawn -- per axis.
			--
			-- The original derives that from zo_max(ZO_WorldMapScroll:GetDimensions()): the
			-- longer edge, used for both axes. It gets away with it because it keeps its
			-- minimap square. Here the window is any size the user picks, so the shorter axis
			-- was being scaled by the longer one's length and the marker sat off-centre --
			-- most visibly on a small window, where that error is a bigger share of the view.
			--
			-- Measure the rendered map instead. ZO_WorldMapContainer is the map itself and its
			-- dimensions already include the zoom, so no zoom maths is needed at all.
			local mapWidth, mapHeight
			if ZO_WorldMapContainer then
				mapWidth, mapHeight = ZO_WorldMapContainer:GetDimensions()
			end
			if not mapWidth or mapWidth <= 0 or not mapHeight or mapHeight <= 0 then
				-- Container not laid out yet: fall back to the original's estimate.
				local units = zo_max(ZO_WorldMapScroll:GetDimensions())
				local curvedTargetZoom = panZoom:ComputeCurvedZoom(targetNormalizedZoom)
				mapWidth = units * curvedTargetZoom
				mapHeight = mapWidth
			end

			-- Deliberately NOT clamped to the map edge. The original keeps the view inside the
			-- map, so a player near an edge drifts away from the middle and can end up half out
			-- of a small subzone map. On a minimap that reads as a bug rather than a feature.
			return targetNormalizedZoom, (0.5 - normalizedX) * mapWidth, (0.5 - normalizedY) * mapHeight
		end

		local panZoomClass = getmetatable(ZO_WorldMap_GetPanAndZoom()).__index
		local orgFocusZoomAndOffset
		orgFocusZoomAndOffset =
			HookHotPath(
			panZoomClass,
			"GetNormalizedPositionFocusZoomAndOffset",
			function(panZoom, normalizedX, normalizedY, useCurrentZoom)
				if LiteMinimapActive() then
					local zoom, offsetX, offsetY = FocusZoomAndOffset(panZoom, normalizedX, normalizedY)
					if zoom then
						return zoom, offsetX, offsetY
					end
				end
				return orgFocusZoomAndOffset(panZoom, normalizedX, normalizedY, useCurrentZoom)
			end
		)
	end

	function addon:StartLiteFollowWatch()
		-- 10Hz, not every frame. Re-centring drives a map update, and asking for one on every
		-- single frame never let the previous one finish -- pins are created at the end of
		-- that cycle, so the player pin never got as far as existing. Ten times a second is
		-- indistinguishable while walking and leaves the map room to complete its work.
		EVENT_MANAGER:RegisterForUpdate(
			self.name .. "LiteFollow",
			100,
			function()
				self:FollowPlayerTick()
			end
		)
	end

	function addon:StartLiteMinimapLayoutWatch()
		EVENT_MANAGER:RegisterForUpdate(
			self.name .. "LiteLayout",
			200,
			function()
				self:MaintainLiteMinimapLayout()
				self:ApplyLiteAlpha()
				self:ApplyLiteBorder()
				self:ApplyLiteDrawOrder()
				self:ApplyLitePlayerPinDrawLevel()
				self:CaptureLitePlayerPinDiagnostic()
				local mapVisible = ZO_WorldMap and not ZO_WorldMap:IsHidden()
				if mapVisible and not self.dormant and self.account and self.account.hideMapLabels then
					self:SweepMapLabelsIfDue()
				end
				self:UpdateZoneTitle()
			end
		)
	end

	local minimapAttached = false
	local orgFragmentDuration = WORLD_MAP_FRAGMENT and WORLD_MAP_FRAGMENT.duration
	-- Returns true when the state actually changed, which also means the layout has just been
	-- applied as part of it.
	function addon:SetMinimapAttached(attached)
		if minimapAttached == attached then
			return false
		end
		minimapAttached = attached
		self.minimapAttached = attached

		if attached then
			-- No fade on the fragment.
			--
			-- The map fragment lives in the HUD scenes, so it is shown and hidden on every
			-- scene change -- opening inventory, looting, and so on. Left at its default
			-- duration each of those carries an animation, which is felt as the UI being slow
			-- to respond. The original sets this to 0 for the same reason; that lives in
			-- InitMiniMap, which this path skips.
			WORLD_MAP_FRAGMENT.duration = 0

			-- Lay the window out BEFORE putting the fragment back in the HUD scenes.
			--
			-- Doing it afterwards left a frame or two where the map was already on screen but
			-- still at the full map's size and position -- visible as a flash when a scene
			-- hands back to the HUD, most obviously in the moment between choosing a
			-- fast-travel destination and the loading screen appearing.
			--
			-- The geometry can be set while the fragment is detached; it does not need to be
			-- in a scene to be sized.
			--
			-- Only the lite path needs this; at higher init levels InitMiniMap owns layout.
			if (self.initLevel or 0) < 3 then
				self:ApplyLiteMinimapLayout()
			end

			HUD_UI_SCENE:RemoveFragment(MOUSE_UI_MODE_FRAGMENT)
			HUD_SCENE:AddFragment(WORLD_MAP_FRAGMENT)
			HUD_UI_SCENE:AddFragment(WORLD_MAP_FRAGMENT)
			SIEGE_BAR_SCENE:AddFragment(WORLD_MAP_FRAGMENT)
			SIEGE_BAR_UI_SCENE:AddFragment(WORLD_MAP_FRAGMENT)
			LOOT_SCENE:AddFragment(WORLD_MAP_FRAGMENT)
			HUD_UI_SCENE:AddFragment(MOUSE_UI_MODE_FRAGMENT)
		else
			if orgFragmentDuration then
				WORLD_MAP_FRAGMENT.duration = orgFragmentDuration
			end
			HUD_SCENE:RemoveFragment(WORLD_MAP_FRAGMENT)
			HUD_UI_SCENE:RemoveFragment(WORLD_MAP_FRAGMENT)
			SIEGE_BAR_SCENE:RemoveFragment(WORLD_MAP_FRAGMENT)
			SIEGE_BAR_UI_SCENE:RemoveFragment(WORLD_MAP_FRAGMENT)
			LOOT_SCENE:RemoveFragment(WORLD_MAP_FRAGMENT)
		end
		return true
	end

	-- The minimap is either on or off. initLevel is what remains of the bisection switch that
	-- located the console memory crash: every level above 2 ran votan's InitMiniMap layer, which
	-- is gone, and the lite code still reads "level 2" to mean "the minimap is running".
	local initLevel = self.account.enableMap and 2 or 0
	self.initLevel = initLevel

	if initLevel == 2 then
		self:InitRequiredModifications()
	end

	-- The game's own map parked in the HUD, sized and positioned by ApplyLiteMinimapLayout.
	if initLevel == 2 then
		self:SetMinimapAttached(true)
	end
	if initLevel == 2 then
		self:InitLiteHooks()
		if self.ApplyLiteMapStyle then self:ApplyLiteMapStyle() end
		self:StartLiteMinimapLayoutWatch()
		self:StartLiteFollowWatch()
		self:StartLiteZoneWatch()
		-- EVENT_PLAYER_ACTIVATED may already have fired by the time the watch registers, so
		-- ask for the first sync outright rather than waiting for an event that has been and
		-- gone.
		self:RequestMapResync()

		-- Settle the first appearance the same way as every later one.
		--
		-- The settle is otherwise only reached through SetDormant, which does nothing unless
		-- the state actually changes -- and dormant starts out false, so the first
		-- SetDormant(false) from the watch is a no-op and startup went straight to showing the
		-- map. Nothing had refreshed the tiles or handed the view back to the game at that
		-- point, which is the same position the antiquity route was in, so the map could come
		-- up at whatever zoom and offset the game happened to be holding. It is also why the
		-- player pin used to be off-centre until the first step.
		if self.BeginLiteSettle then
			self:BeginLiteSettle()
		end
		self:InstallLiteAnchorOverride()
		self:SetLiteAnchorGuard(true)
		if self.account.debug then
			self:DumpPanZoomApi()
		end
	end

	if self.account.debug then
		df("[PBsMiniMap] minimap %s", initLevel == 2 and "on" or "off")
	end
end

-- Diagnostic for the console 100MB add-on memory limit. Reports the *shared* pool used by
-- every enabled add-on, not just this one.
--
-- Two things are reported: the memory reading, and how this add-on currently answers "is the
-- full-screen World Map in front?". The second half matters because every suppression in this
-- add-on hangs off that question -- if the answer is wrong on console (for example because the
-- console UI drives a different scene than WORLD_MAP_SCENE / GAMEPAD_WORLD_MAP_SCENE), then
-- none of the suppression ever engages, which would explain why the crash is unaffected by it.
-- The individual scene flags are printed separately so a disagreement is visible.
--
-- The trail is also written to SavedVariables, because the client clears the chat log when the
-- limit is hit; the saved copy is dumped on the next login.
local DIAG_MAX_ENTRIES = 24
local function InitMemoryWatchdog()
	local account = addon.account
	if not account then
		return
	end

	-- This tick is load-bearing: it is what drives dormancy every frame (see Check below), so
	-- it always runs. Only the chat output is optional, behind the debug setting. The trail is
	-- still recorded into SavedVariables either way, so it is there if a problem comes back.
	local function DebugOut(...)
		if account.debug then
			df(...)
		end
	end

	-- Dump whatever the previous session recorded before it died, then start fresh.
	local previous = account.diagLog
	account.diagLog = {}
	if type(previous) == "table" and #previous > 0 then
		DebugOut("[PBsMiniMap] --- trail from previous session ---")
		for i = 1, #previous do
			DebugOut("[PBsMiniMap] %s", previous[i])
		end
		DebugOut("[PBsMiniMap] --- end of trail (%d entries) ---", #previous)
	end

	local hasMemoryApi = type(GetTotalUserAddOnMemoryPoolUsageMB) == "function"
	if not hasMemoryApi then
		DebugOut("[PBsMiniMap] note: GetTotalUserAddOnMemoryPoolUsageMB() unavailable, memory column will read -1")
	end

	local log = account.diagLog

	local function ReadMemory()
		if not hasMemoryApi then
			return -1
		end
		return GetTotalUserAddOnMemoryPoolUsageMB() or -1
	end

	local function Bool(value)
		return value and "Y" or "n"
	end

	local lastLine, lastMemory = nil, -999
	local function Snapshot(label)
		local used = ReadMemory()
		local inFront = addon.IsWorldMapInFront()

		-- The position symptom is invisible without the anchor, and the zoom symptom without
		-- the installed range. Both are read here rather than inferred.
		local anchorX, anchorY = -9999, -9999
		if ZO_WorldMap and ZO_WorldMap.GetAnchor then
			local isValid, _, _, _, offsX, offsY = ZO_WorldMap:GetAnchor(0)
			if isValid then
				anchorX, anchorY = zo_round(offsX or 0), zo_round(offsY or 0)
			end
		end
		local rangeMin, rangeMax = -1, -1
		if addon.panZoom and addon.panZoom.GetZoomMinMax then
			local lo, hi = addon.panZoom:GetZoomMinMax()
			rangeMin, rangeMax = lo or -1, hi or -1
		end

		-- The zoom the map is actually drawn at, as opposed to the range we asked for. If the
		-- two disagree then something above SetMapZoomMinMax is in charge -- a custom zoom
		-- range left behind by a view the game opened for itself is the obvious candidate --
		-- and no amount of setting the range will move the picture.
		-- Which scene is actually current, and what the generic "someone else has the map up"
		-- test makes of it. followSkip reporting "dormant" while dormant reads n means the flag
		-- is being flipped between samples, and this is the only thing that flips it.
		local sceneName = "?"
		if SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene then
			local current = SCENE_MANAGER:GetCurrentScene()
			if current and current.GetName then
				sceneName = tostring(current:GetName())
			end
		end
		local elsewhere = addon.IsWorldMapShownElsewhere and addon.IsWorldMapShownElsewhere()

		local effZoom = -1
		if addon.panZoom and addon.panZoom.ComputeCurvedZoom and addon.panZoom.GetCurrentNormalizedZoom then
			local ok, value = pcall(function()
				return addon.panZoom:ComputeCurvedZoom(addon.panZoom:GetCurrentNormalizedZoom())
			end)
			if ok and type(value) == "number" then
				effZoom = value
			end
		end
		-- What the add-on would ask for right now, for comparison with both of the above.
		local wantZoom = -1
		if addon.ComputeLiteZoomTarget then
			wantZoom = addon:ComputeLiteZoomTarget() or -1
		end
		-- State half of the line: everything the suppression logic depends on.
		local state =
			string.format(
			"front=%s (kb=%s gp=%s api=%s gpMode=%s) dormant=%s attached=%s hooks=%s hidden=%s anchor=%d,%d blocks=%d range=%.3f-%.3f eff=%.3f want=%.3f settle=%d scene=%s elsewhere=%s mode=%s mapType=%s zoom=%.2f/%.2f(%s) player=%.3f,%.3f onOwnMap=%s size=%dx%d scroll=%dx%d flips=%d follow=%d/%s centre=%d/%s setMap=%s container=%dx%d",
			Bool(inFront),
			Bool(WORLD_MAP_SCENE and WORLD_MAP_SCENE:IsShowing()),
			Bool(GAMEPAD_WORLD_MAP_SCENE and GAMEPAD_WORLD_MAP_SCENE:IsShowing()),
			Bool(ZO_WorldMap_IsWorldMapShowing and ZO_WorldMap_IsWorldMapShowing()),
			Bool(IsInGamepadPreferredMode()),
			Bool(addon.dormant),
			Bool(addon.minimapAttached),
			Bool(addon.hotPathHooksActive),
			Bool(ZO_WorldMap and ZO_WorldMap:IsHidden()),
			anchorX,
			anchorY,
			addon.anchorBlocks or 0,
			rangeMin,
			rangeMax,
			effZoom,
			wantZoom,
			addon.settleTicks or 0,
			sceneName,
			Bool(elsewhere),
			tostring(WORLD_MAP_MANAGER:GetMode()),
			tostring(GetMapType()),
			addon.panZoom and (addon.panZoom:GetCurrentNormalizedZoom() or -1) or -1,
			addon.CurrentZoomLevel and addon:CurrentZoomLevel() or -1,
			addon.CurrentZoomContext and addon.CurrentZoomContext() or "?",
			select(1, GetMapPlayerPosition("player")) or -1,
			select(2, GetMapPlayerPosition("player")) or -1,
			Bool(DoesCurrentMapMatchMapForPlayerLocation()),
			zo_round(select(1, ZO_WorldMap:GetDimensions())),
			zo_round(select(2, ZO_WorldMap:GetDimensions())),
			ZO_WorldMapScroll and zo_round(select(1, ZO_WorldMapScroll:GetDimensions())) or -1,
			ZO_WorldMapScroll and zo_round(select(2, ZO_WorldMapScroll:GetDimensions())) or -1,
			addon.dormantFlips or 0,
			addon.followTicks or 0,
			tostring(addon.followSkip or "never"),
			addon.centreCalls or 0,
			tostring(addon.centreRoute or "none"),
			tostring(addon.lastSetMapResult or "-"),
			ZO_WorldMapContainer and zo_round(select(1, ZO_WorldMapContainer:GetDimensions())) or -1,
			ZO_WorldMapContainer and zo_round(select(2, ZO_WorldMapContainer:GetDimensions())) or -1
		)
		local _, _, _, shown, symbolic = GetMapPlayerPosition("player")
		local playerPin = addon.pinManager and addon.pinManager:GetPlayerPin()
		state = state .. string.format(" mapId=%s floor=%s playerShown=%s symbolic=%s pinHidden=%s",
			tostring(GetCurrentMapId()), tostring(GetMapFloorInfo()), Bool(shown), Bool(symbolic),
			playerPin and Bool(playerPin:IsHidden()) or "missing")
		return used, state
	end

	local function Emit(label)
		local used, state = Snapshot(label)
		local line = string.format("%.1fMB %s%s", used, state, label and (" [" .. label .. "]") or "")

		if #log >= DIAG_MAX_ENTRIES then
			table.remove(log, 1)
		end
		log[#log + 1] = line

		DebugOut("[PBsMiniMap] %s", line)
		lastLine, lastMemory = state, used
	end

	-- Coming back from dormancy assumes the player closed the map themselves, and tears a
	-- fast-travel session down accordingly: it clears the custom zoom range, pops the special
	-- mode, ends the interaction, and pins the window back to minimap size. All of that is
	-- right once the map is gone, and destructive while it is still up -- the wayshrine view
	-- loses its zoom range and stops responding to input.
	--
	-- One stray sample is enough to do it, and one can occur: GetScene() picks its scene from
	-- IsInGamepadPreferredMode(), so a momentary flip there points the check at the scene that
	-- is not showing, and ZO_WorldMap_IsWorldMapShowing() (keyboard UI) does not cover for it.
	-- Both read false with the map plainly on screen.
	--
	-- So the two directions are not treated alike. Going dormant stays immediate: a single
	-- frame of the Tamriel-wide view under our stack frames is what fills the memory pool.
	-- Coming back waits for the reading to hold, which costs nothing visible -- staying
	-- dormant an extra fraction of a second looks the same as not.
	local LEAVE_DORMANT_SAMPLES = 3
	-- The generic test wants a moment's confirmation before it is acted on: during a scene
	-- change the outgoing scene can still be the current one while the map has not been
	-- hidden yet, and standing down on a single frame of that would detach the minimap every
	-- time the player opens a menu.
	local FOREIGN_MAP_SAMPLES = 2
	local clearSamples, foreignSamples = 0, 0

	local function Check()
		-- Drive dormancy from the observed state every frame. Scene StateChange callbacks
		-- proved unreliable here (dormant never engaged on console), so the same value the
		-- diagnostics report is the value that decides whether the add-on stands down.
		--
		-- That is the only part that has to run every frame. Building the snapshot means
		-- reading the add-on memory pool and querying several scenes, so it is skipped
		-- entirely unless the (locked, off by default) debug output is on -- there is nothing
		-- to report to otherwise, and this runs behind every full-screen UI in the game.
		local inFront = addon.IsWorldMapInFront()
		if not inFront and addon.IsWorldMapShownElsewhere() then
			foreignSamples = foreignSamples + 1
			if foreignSamples >= FOREIGN_MAP_SAMPLES then
				inFront = true
			end
		else
			foreignSamples = 0
		end

		if inFront then
			clearSamples = 0
			addon:SetDormant(true)
		else
			clearSamples = clearSamples + 1
			if clearSamples >= LEAVE_DORMANT_SAMPLES then
				addon:SetDormant(false)
			end
		end

		addon:UpdatePendingCentre()
		if addon.PollCompassTexture then
			addon:PollCompassTexture()
		end

		-- Checked here rather than on the 100ms follow tick: this is the fastest thing running,
		-- and the whole point is to show the map the moment it is right.
		if addon.UpdateLiteSettle then
			addon:UpdateLiteSettle()
		end

		if not account.debug then
			return
		end

		-- Standing back up is where the trouble is, and it is over within a frame or two, so
		-- for a second afterwards print every sample whether or not anything changed. Outside
		-- that window the usual on-change rule applies, which keeps walking around quiet.
		if (addon.traceTicks or 0) > 0 then
			addon.traceTicks = addon.traceTicks - 1
			Emit("wake")
			return
		end

		local used, state = Snapshot()
		-- Print on any state change, or on a 1MB move in either direction. Steady frames stay
		-- silent so the chat log remains readable.
		if state ~= lastLine or used >= lastMemory + 1 or used <= lastMemory - 1 then
			Emit()
		end
	end

	-- Runs every frame and is deliberately NOT suspended while the World Map is in front:
	-- the moment being investigated is exactly the one that must stay visible.
	function addon:RestartMemoryWatch()
		-- 50ms rather than every frame. All this has to do in normal play is notice that the
		-- standard map has come forward, and that happens long before the player can zoom out
		-- to Tamriel -- but it runs behind every full-screen UI in the game, so the frequency
		-- is worth something.
		EVENT_MANAGER:RegisterForUpdate(self.name .. "MemoryWatch", 50, Check)
	end
	addon:RestartMemoryWatch()

	CALLBACK_MANAGER:RegisterCallback(
		"OnWorldMapChanged",
		function(wasNavigateIn)
			-- Only while the standard map is in front: this is for the player navigating
			-- between map levels there, not for walking across a zone border.
			-- Only while the standard map is in front: this is the player moving between
			-- map levels there, not walking across a zone border on the HUD.
			if addon.dormant then
				addon:ArmCentreTidyUp()
			end
			Emit("map changed: " .. tostring(GetMapName()))
		end
	)

	Emit("startup")
end

local function OnAddonLoaded(event, name)
	if name ~= addon.name then
		return
	end
	em:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)
	addon:Initialize()
	addon:InitSettings()
	InitMemoryWatchdog()
end

em:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)

PBS_MINIMAP = addon
