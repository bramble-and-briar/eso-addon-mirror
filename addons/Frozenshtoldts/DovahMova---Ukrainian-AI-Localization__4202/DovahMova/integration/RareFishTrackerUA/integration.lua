-- =================================================================================================
-- Rare Fish Tracker: українські рядки.
-- Назви риб RFT бере з GetItemLinkName, тож вони вже проходять через DovahMova (узгодження
-- прикметників і англійський постфікс). RFT сканує досягнення під час свого завантаження —
-- раніше за DovahMova, тому пересканувуємо, щоб назви в прогресі збігалися з новими.
-- =================================================================================================

local DovahMova = DovahMova

DovahMova.RegisterIntegration({
	name = "RareFishTracker",
	IsAvailable = function()
		return RFT ~= nil
	end,
	Prepare = function()
		DovahMova.Util.OverrideStrings(DovahMova.IntegrationStrings.RareFishTracker, 1)
	end,
	Apply = function()
		if RFT.RescanAchievements then
			RFT:RescanAchievements()
		end
		if RFT.RefreshWindow then
			RFT.RefreshWindow()
		end
	end,
})
