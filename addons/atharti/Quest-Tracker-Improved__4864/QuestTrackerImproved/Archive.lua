local QTI = QuestTrackerImproved

function QTI.HideArchiveButton()
	ENDLESS_DUNGEON_HUD_TRACKER.showBuffTrackerKeybindButton:SetHidden(true)

	ZO_PreHook(ZO_EndlessDungeonHUDTracker, "OnShown", function(self)
		self.showBuffTrackerKeybindButton:SetHidden(true)
		return true
	end)
end