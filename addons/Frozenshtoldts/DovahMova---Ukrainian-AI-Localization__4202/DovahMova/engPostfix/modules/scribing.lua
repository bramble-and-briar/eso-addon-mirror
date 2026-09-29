-- =================================================================================================
-- Назви скриптів скрайбінгу.
-- =================================================================================================

local DovahMova = DovahMova
local Util = DovahMova.Util

local Scribing = {}
DovahMova.Scribing = Scribing

local installed = false

function Scribing.Install()
	if installed then
		return
	end
	installed = true

	local originalGetScriptName = GetCraftedAbilityScriptDisplayName
	GetCraftedAbilityScriptDisplayName = function(scriptId)
		local ukrainianName = originalGetScriptName(scriptId)
		if not ukrainianName or DovahMova.isBuildingDatabase then
			return ukrainianName
		end
		local englishName = DovahMova.db.ScribingScripts[scriptId]
		return Util.FormatBilingual(ukrainianName, englishName, DovahMova.settings.ShowScribing)
	end
end
