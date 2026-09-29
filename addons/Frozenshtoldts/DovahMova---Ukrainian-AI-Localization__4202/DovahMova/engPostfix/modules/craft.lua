-- =================================================================================================
-- Назви сетів на ремісничих верстатах: "Кузня (Сет)" -> "Кузня (Сет — Set)".
-- =================================================================================================

local DovahMova = DovahMova

local Craft = {}
DovahMova.Craft = Craft

local installed = false

function Craft.Install()
	if installed then
		return
	end
	installed = true

	local craftActionName = GetString(SI_GAMECAMERAACTIONTYPE5)
	local original = GetGameCameraInteractableActionInfo

	local function Translate(action, name, ...)
		local mode = DovahMova.settings.ShowCraft
		if action ~= craftActionName or not name or mode == DovahMova.MODE_UA then
			return action, name, ...
		end
		local stationName, ukrainianSet = string.match(name, "^(.*) %((.*)%)$")
		local englishSet = ukrainianSet and DovahMova.db.SetsNames[DovahMova.Util.ToKey(ukrainianSet)]
		if not englishSet then
			return action, name, ...
		end
		if mode == DovahMova.MODE_UAEN then
			name = string.format("%s (%s — %s)", stationName, ukrainianSet, englishSet)
		else
			name = string.format("%s (%s)", stationName, englishSet)
		end
		return action, name, ...
	end

	GetGameCameraInteractableActionInfo = function()
		return Translate(original())
	end
end
