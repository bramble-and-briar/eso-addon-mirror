-- While the settings panel is open the compass is drawn over it, with sample members, so that each
-- change can be seen. The panel is not a HUD scene, so without this nothing would show.
local A = PBS_COMPASS

function A:SetPanelOpen(open)
	self.panelOpen = open and true or false
	self:ApplyLayout()
	self:RefreshVisibility()
end

-- On console the library fires AddonSelected before it pushes its scene, and not at all when the same
-- panel is opened again; the scene's own state changes are what to follow (PB's ChatWindowCustomizer
-- measured this on a PS5, and PB's Clock does the same). The scene exists only after the first
-- selection, so it is looked up then.
function A:WatchSettingsScene()
	local library = LibHarvensAddonSettings
	local scene = library and library.scene
	if not scene and SCENE_MANAGER then
		scene = SCENE_MANAGER:GetScene("LibHarvensAddonSettingsScene")
	end
	-- The desktop library shows its panel inside the current settings scene.
	if not scene and SCENE_MANAGER then
		scene = SCENE_MANAGER:GetCurrentScene()
	end
	if not scene or scene == HUD_SCENE or scene == HUD_UI_SCENE then
		return nil
	end
	self.watchedScenes = self.watchedScenes or {}
	if not self.watchedScenes[scene] then
		self.watchedScenes[scene] = true
		scene:RegisterCallback("StateChange", function(_, state)
			if state == SCENE_SHOWN then
				self:SetPanelOpen(self.panel and self.panel.selected == true)
			elseif state == SCENE_HIDING or state == SCENE_HIDDEN then
				self:SetPanelOpen(false)
			end
		end)
	end
	return scene
end

function A:OnAddonSelected(panel)
	local scene = self:WatchSettingsScene()
	self:SetPanelOpen(panel == self.panel and (not scene or scene:IsShowing()))
end
