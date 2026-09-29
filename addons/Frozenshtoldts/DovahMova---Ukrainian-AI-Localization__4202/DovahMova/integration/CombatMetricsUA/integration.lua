-- =================================================================================================
-- Combat Metrics: українські рядки (у Combat Metrics немає lang/ua.lua).
-- Застосовуються до ініціалізації Combat Metrics, тож його меню будується українською.
-- =================================================================================================

local DovahMova = DovahMova

DovahMova.RegisterIntegration({
	name = "CombatMetrics",
	IsAvailable = function()
		return CMX ~= nil
	end,
	Prepare = function()
		DovahMova.Util.OverrideStrings(DovahMova.IntegrationStrings.CombatMetrics, 1)
	end,
})
