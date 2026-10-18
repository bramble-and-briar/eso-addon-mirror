-- PB's FurnitureEditor -- Copy and Cut in the housing editor
--
-- In the gamepad housing editor, aiming at a furnishing shows a small palette of buttons beside the
-- reticle (x Edit, triangle Precision Edit, L3 Link). With a linked furnishing in the reticle this
-- adds two more:
--
--   circle   Copy     the whole link tree the furnishing belongs to, onto the clipboard
--   square   Cut      the same, and it leaves this house at once
--
-- That is all: no screen, no choosing a house. It is a clipboard. Leave the editor, go to any house of
-- yours, and the quickslot wheel offers Paste (or Move, after a cut), Wheel.lua.
--
-- What the client's own code says (ingame/housingeditor/housingeditorhud.lua):
--
--   * The palette is a list of descriptors, HOUSING_EDITOR_SHARED.selectionModeKeybindPaletteGamepadDescriptor,
--     handed to HOUSING_EDITOR_KEYBIND_PALETTE:AddKeybinds(list) whenever the target changes. Each is
--     { name, keybind, callback, enabled, visible, order, ethereal = true }; `visible` and `enabled`
--     are evaluated on every refresh. Selection mode uses the actions PRIMARY (x), TERTIARY (triangle),
--     BEGIN_FURNITURE_LINKING (L3) and QUINARY (path); NEGATIVE (circle) is not used there, so Copy
--     takes it. (Reported from a console: Copy appears and is drawn.)
--   * SECONDARY (square) IS used there, by the strip's "Browse" button. The strip keeps ONE descriptor
--     per keybind: adding a second runs internalassert and then removes the one registered FIRST. A
--     palette button is drawn from its descriptor alone (ZO_KeybindButtonMixin:SetKeybindButtonDescriptor),
--     whether or not the strip registered it, so Cut can be SHOWN on the palette like Copy. Who HANDLES
--     the square button is whichever the strip kept, and that depends on the order of the last two
--     calls (UpdateKeybinds adds the palette, then the strip, so Browse wins; RefreshKeybinds re-adds
--     only the palette, so the palette's entry wins). Both are therefore written to do the same thing:
--     with a linked furnishing in the reticle the square button cuts, at any other time it browses.
--   * Cut is shown on the palette ONLY. The strip's Browse is not renamed "Cut": the strip is drawn along
--     the bottom of the screen, and the same word there was a second copy of the palette's. While a
--     linked furnishing is in the reticle the palette's Cut is made the descriptor the strip keeps (the
--     palette is refreshed after the client's own update), which removes Browse's button from the strip,
--     and the palette's callback does the cut. Browse comes back when the reticle leaves a linked piece.
--   * This changes data (adds two descriptors to a list; replaces the callback and `visible` of another)
--     and hooks nothing. The cost is that our `visible`, `name` and `callback` functions are called
--     from inside the client's own keybind code. They are written to do nothing but look and
--     schedule, to catch every error (a failing one answers "not applicable", so the original
--     behaviour stands), and the callbacks start their work a moment later, outside that chain.

local addon = PBS_FURNITURE_EDITOR

local Call, Try1 = addon.Call, addon.Try1
local IdKey, IsNoId = addon.IdKey, addon.IsNoId
local Print, Line = addon.Print, addon.Line

local COPY_ACTION = "HOUSING_EDITOR_NEGATIVE_ACTION"
local BROWSE_ACTION = "HOUSING_EDITOR_SECONDARY_ACTION"

local TEXT = {
	en = { copy = "Copy", cut = "Cut" },
	jp = { copy = "コピー", cut = "カット" },
}

local function Text()
	return TEXT[Try1(GetCVar, "language.2")] or TEXT.en
end

-- ---------------------------------------------------------------------------------------
-- What is in the reticle
-- ---------------------------------------------------------------------------------------

-- The furnishing in the reticle, or nil. A path node is not a furnishing.
local function TargetId()
	local results = Call(HousingEditorGetTargetInfo)
	if not results then
		return nil
	end

	local id, pathIndex = results[1], results[2]
	if id == nil or IsNoId(id) or pathIndex ~= nil then
		return nil
	end
	return id
end

local function IsLinked(id)
	local parent = Try1(GetPlacedFurnitureParent, id)
	if parent ~= nil and not IsNoId(parent) then
		return true
	end

	local children = Call(GetPlacedFurnitureChildren, id)
	return children ~= nil and children[1] ~= nil and not IsNoId(children[1])
end

-- Does the key mean Copy / Cut right now? Never raises: a failure is "no", and "no" leaves the
-- client's own button doing what it always did.
function addon:EditorKeyApplies(kind)
	local ok, result = pcall(function()
		if self.sv.editorKeys == false or self.editorBroken then
			return false
		end
		if not Try1(IsInGamepadPreferredMode) then
			return false
		end
		if self.run then
			return false
		end

		local access = self:HouseAccess()
		if not access then
			return false
		end
		-- a copy needs the right to look, a cut the right to remove
		if kind == "cut" then
			if not access.owner then
				return false
			end
		elseif not access.editor then
			return false
		end

		local id = TargetId()
		return id ~= nil and IsLinked(id)
	end)

	return ok and result and true or false
end

-- ---------------------------------------------------------------------------------------
-- Putting the two keys in
-- ---------------------------------------------------------------------------------------

function addon:InstallEditorKeys()
	if self.editorKeysInstalled then
		return true
	end
	if self.editorBroken then
		return false, self.editorBroken
	end

	-- Not there (yet) is not a failure: the HUD may not exist when this runs, and the next time the
	-- player is activated it is asked again. Third return: try again later.
	local hud = HOUSING_EDITOR_SHARED
	if type(hud) ~= "table" then
		return false, "the housing editor HUD was not found", true
	end

	local palette = hud.selectionModeKeybindPaletteGamepadDescriptor
	local strip = hud.selectionModeGamepadKeybindStripDescriptor
	if type(palette) ~= "table" or type(strip) ~= "table" then
		return false, "the editor's keybind lists were not found", true
	end

	local browse
	for _, descriptor in ipairs(strip) do
		if type(descriptor) == "table" and descriptor.keybind == BROWSE_ACTION then
			browse = descriptor
			break
		end
	end
	if not browse then
		return false, "the Browse button was not found"
	end

	-- ---- Copy: a new palette entry on the circle button
	local function copyApplies()
		return addon:EditorKeyApplies("copy")
	end

	table.insert(palette, {
		name = function() return Text().copy end,
		keybind = COPY_ACTION,
		callback = function() addon:PressedEditorKey("copy") end,
		enabled = copyApplies,
		visible = copyApplies,
		order = 50,
		ethereal = true,
		pbfe = true,
	})

	-- ---- Cut: the square button, which is Browse unless a linked furnishing is in the reticle
	local originalCallback, originalEnabled = browse.callback, browse.enabled

	-- Would the client's own Browse be allowed right now?
	local function browseEnabled()
		if type(originalEnabled) == "function" then
			local ok, value = pcall(originalEnabled, browse)
			return (not ok) or value ~= false
		end
		return originalEnabled ~= false
	end

	local function squareCallback(...)
		if addon:EditorKeyApplies("cut") then
			return addon:PressedEditorKey("cut")
		end
		if originalCallback then
			return originalCallback(...)
		end
	end

	local function cutApplies()
		return addon:EditorKeyApplies("cut")
	end

	-- shown on the palette beside Copy; and, when the strip keeps this one rather than Browse, it
	-- does Browse's job whenever it is not a Cut
	table.insert(palette, {
		name = function() return Text().cut end,
		keybind = BROWSE_ACTION,
		callback = squareCallback,
		enabled = function() return cutApplies() or browseEnabled() end,
		visible = cutApplies,
		order = 60,
		ethereal = true,
		pbfe = true,
	})
	-- the palette sorts itself once, on the first show; ask it to again
	palette.sorted = false

	-- and the strip's own Browse, for when the strip keeps that one: it keeps its name (nothing says "Cut"
	-- along the bottom), and it does what the palette's Cut does, so that the square button cuts whichever
	-- of the two the strip has registered
	browse.callback = squareCallback

	-- The strip asks `visible` when it draws a button, i.e. when Browse has just been registered. If a linked
	-- furnishing is in the reticle that is the wrong one to have: say so, and the palette's Cut is put back
	-- as the one the strip keeps (a moment later, outside the client's keybind code).
	local originalVisible = browse.visible
	browse.visible = function(...)
		if addon:EditorKeyApplies("cut") then
			addon:ScheduleEditorSettle()
		end
		if type(originalVisible) == "function" then
			local ok, value = pcall(originalVisible, ...)
			return (not ok) or value ~= false
		end
		return originalVisible ~= false
	end

	self.editorOriginals = { browse = browse, callback = originalCallback, visible = originalVisible }
	self.editorKeysInstalled = true
	return true
end

-- Take everything back out: the palette entries go, and Browse is Browse again, untouched.
function addon:UninstallEditorKeys()
	if not self.editorKeysInstalled then
		return
	end

	local hud = HOUSING_EDITOR_SHARED
	local palette = type(hud) == "table" and hud.selectionModeKeybindPaletteGamepadDescriptor
	if type(palette) == "table" then
		for index = #palette, 1, -1 do
			if type(palette[index]) == "table" and palette[index].pbfe then
				table.remove(palette, index)
			end
		end
		palette.sorted = false
	end

	local originals = self.editorOriginals
	if originals then
		originals.browse.callback = originals.callback
		originals.browse.visible = originals.visible
	end

	self.editorOriginals = nil
	self.editorKeysInstalled = false
end

-- Have the editor rebuild its buttons now, so that a change shows without a target change.
function addon:RebuildEditorKeys()
	pcall(function()
		local hud = HOUSING_EDITOR_SHARED
		if type(hud) == "table" and type(hud.UpdateKeybinds) == "function" then
			hud:UpdateKeybinds()
		end
	end)
end

-- Called when the player is somewhere the HUD can exist; quiet when there is nothing to do.
function addon:EnsureEditorKeys()
	if self.editorKeysInstalled or self.editorBroken or self.sv.editorKeys == false then
		return
	end

	local ok, installed, why, later = pcall(self.InstallEditorKeys, self)
	if not ok then
		self.editorBroken = tostring(installed)
		Print("the editor Copy/Cut buttons could not be added: %s", self.editorBroken)
	elseif not installed and later then
		-- nothing is said: this is the normal state until the editor exists
		self.editorWaiting = tostring(why)
	elseif not installed then
		self.editorBroken = tostring(why)
		Print("the editor Copy/Cut buttons could not be added: %s", self.editorBroken)
	end
end

-- Which descriptor the strip keeps for the square button decides what is drawn along the bottom: Browse's
-- button, or nothing (the palette's Cut is input-only on the strip). With a linked furnishing in the
-- reticle it should be the palette's, so there is no "Cut" at the bottom to repeat the palette's; with
-- anything else it should be Browse, so the button is there. The client changes it on every target change
-- (its own update registers Browse last), so this is done once the client has finished, a frame later.
function addon:SettleEditorKeys()
	self.editorSettlePending = false
	pcall(function()
		local hud = HOUSING_EDITOR_SHARED
		if not (self.editorKeysInstalled and type(hud) == "table") then
			return
		end

		if self:EditorKeyApplies("cut") then
			local palette = HOUSING_EDITOR_KEYBIND_PALETTE
			if palette and palette.RefreshKeybinds then
				palette:RefreshKeybinds()
			end
		elseif hud.currentKeybindDescriptor and KEYBIND_STRIP then
			KEYBIND_STRIP:UpdateKeybindButtonGroup(hud.currentKeybindDescriptor)
		end
	end)
end

-- One at a time: a strip update asks `visible` of several buttons, and the target changes in bursts.
function addon:ScheduleEditorSettle()
	if self.editorSettlePending then
		return
	end
	self.editorSettlePending = true
	addon.Later(0, function()
		addon:SettleEditorKeys()
	end)
end

function addon:RefreshEditorStrip()
	if self.editorKeysInstalled then
		self:ScheduleEditorSettle()
	end
end

-- ---------------------------------------------------------------------------------------
-- A key was pressed
--
-- Runs inside the client's keybind handling: it notes what is in the reticle (a C call) and schedules
-- the rest.
-- ---------------------------------------------------------------------------------------

function addon:PressedEditorKey(kind)
	local id = TargetId()
	if id == nil then
		return
	end

	addon.Later(0, function()
		addon:PerformEditorKey(kind, id)
	end)
end

-- The link tree the furnishing belongs to, as groups, the way a copy reads it.
function addon:GroupOfFurniture(id)
	local access = self:HouseAccess()
	if not access then
		return nil
	end
	if not access.editor then
		Print("you can only copy from a house you can edit")
		return nil
	end

	local house = self:ReadHouse()
	local pose = self:PlayerPose()
	local entry = house.byKey[IdKey(id)]
	if not entry then
		Print("that furnishing is not in the house list")
		return nil
	end

	return access, house, pose, { self:GroupFromRoot(house, self:RootOf(house, entry), pose) }
end

-- Copy puts the group on the clipboard; Cut does the same and takes it out of this house. Either way
-- the clipboard is "fresh", which is what puts Paste (or Move) on the quickslot wheel in any house of
-- yours until it has been pasted.
function addon:PerformEditorKey(kind, id)
	if self.run then
		Print("a %s is running -- /pbfe stop", self.run.kind)
		return
	end

	-- A cut is the only record of where its furnishings go: not replaced by a second copy or cut.
	local waiting = self.sv.clip
	if waiting and waiting.cut then
		-- Cut again on a piece of that cut that is still standing: it is the same cut, carried on.
		if kind == "cut" then
			local standing, here = self:CutStatus(waiting)
			if here and standing and standing > 0 and self:InPendingCut(waiting, id) then
				Print("carrying on with the cut: %d of %d are still standing", standing, #waiting.nodes)
				addon.Alert("Carrying on with the cut: %d to go", standing)
				self:ResumeCut(true, false, "/pbfe cut resume")
				return
			end
		end

		Print("a cut is still waiting (%d furnishings), so a new %s is refused", #waiting.nodes, kind == "cut" and "cut" or "copy")
		self:PrintCutAdvice(waiting)
		local standing, here = self:CutStatus(waiting)
		if here and standing and standing > 0 then
			addon.Alert("A cut is unfinished: %d still stand here. Press Cut on one of them to carry on", standing)
		else
			addon.Alert("A cut of %d furnishings is waiting: pick Move on the quickslot wheel", #waiting.nodes)
		end
		return
	end

	local access, _, pose, chosen = self:GroupOfFurniture(id)
	if not access then
		return
	end

	local clip = self:MakeClip(chosen, access, pose)

	if kind == "copy" then
		self.sv.clip = clip
		self.sv.clipFresh = true

		local items, collectibles, links, paths = self:ClipSummary(clip)
		Print("copied %d furnishings (%d items, %d collectibles, %d links)", #clip.nodes, items, collectibles, links)
		if paths > 0 then
			Print("%d of them follow a path; the path is NOT copied", paths)
		end
		Print("leave the editor, go to a house of yours, and use the quickslot wheel: Paste")
		self:AnnounceMenu()
		return
	end

	if not access.owner then
		Print("you can only cut from a house you own")
		return
	end

	local keys = {}
	for i = #clip.nodes, 1, -1 do
		keys[#keys + 1] = clip.nodes[i].srcKey
	end

	-- the usual cut: the bag-room check, the clipboard, the removal, and the wheel when it is done
	self:RunCut(clip, keys, clip.nodes, true, false, "/pbfe cut")
end

-- ---------------------------------------------------------------------------------------
-- Events, and the switch
-- ---------------------------------------------------------------------------------------

function addon:OnInitialiseEditor()
	EVENT_MANAGER:RegisterForEvent(self.name .. "Editor", EVENT_PLAYER_ACTIVATED, function()
		addon:EnsureEditorKeys()
	end)

	if EVENT_HOUSING_TARGET_FURNITURE_CHANGED then
		EVENT_MANAGER:RegisterForEvent(self.name .. "Editor", EVENT_HOUSING_TARGET_FURNITURE_CHANGED, function()
			addon:RefreshEditorStrip()
		end)
	end
end

addon:AddCommand("editor", "  /pbfe editor [on|off]   Copy (circle) and Cut (square) in the housing editor", function(self, words)
	local what = words[1]

	if what == "off" then
		self.sv.editorKeys = false
		self:UninstallEditorKeys()
		self:RebuildEditorKeys()
		Print("the editor Copy/Cut buttons are off (the square button is Browse again)")
		return
	elseif what == "on" then
		self.sv.editorKeys = true
		self.editorBroken = nil
		self:EnsureEditorKeys()
		self:RebuildEditorKeys()
		Print("the editor Copy/Cut buttons are on")
		return
	end

	Print("editor buttons: %s%s", self.sv.editorKeys == false and "off" or "on",
		self.editorBroken and (" -- stopped: " .. self.editorBroken) or "")
	Print("installed: %s%s", self.editorKeysInstalled and "yes" or "no",
		(not self.editorKeysInstalled and self.editorWaiting) and (" (waiting: " .. self.editorWaiting .. ")") or "")
	Print("aim at linked furniture in the editor: circle = Copy, square = Cut")
end)
