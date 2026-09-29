-- =================================================================================================
-- vAS Helper: українське ім'я Святого Олмса і написи «ОЧИЩЕННЯ».
-- vAS Helper показує мітки лише коли string.lower(GetUnitName("boss1")) є в vASHelper.bossNames.
-- Меню vAS Helper має лише англійський текст, тому його не перекладаємо.
-- =================================================================================================

local DovahMova = DovahMova

local BOSS_NAME = "Святий Олмс Справедливий" -- як у ua.lang
local PURGE_TEXT = "ОЧИЩЕННЯ"
local PURGE_LABELS = { "LeftTop", "LeftBottom", "RightTop", "RightBottom" }

DovahMova.RegisterIntegration({
	name = "vASHelper",
	IsAvailable = function()
		return vASHelper ~= nil and vASHelper.bossNames ~= nil
	end,
	Apply = function()
		vASHelper.bossNames[string.lower(BOSS_NAME)] = true

		for _, labelName in ipairs(PURGE_LABELS) do
			local label = _G["vASHelperFrame" .. labelName]
			if label then
				label:SetText(PURGE_TEXT)
			end
		end
	end,
})
