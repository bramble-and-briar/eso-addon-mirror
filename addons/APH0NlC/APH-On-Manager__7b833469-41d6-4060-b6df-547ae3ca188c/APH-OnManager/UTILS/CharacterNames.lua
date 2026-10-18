--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local LibAPH = LibAPH
local unescape = LibAPH.UnescapeName

local game_unique_name = GetUniqueNameForCharacter
if type(game_unique_name) == "function" then
	GetUniqueNameForCharacter = function(characterName, ...)
		return game_unique_name(unescape(characterName), ...)
	end
end

if ZO_AddOnManager and type(ZO_AddOnManager.GetCharacterInfo) == "function" then
	local game_character_info = ZO_AddOnManager.GetCharacterInfo
	ZO_AddOnManager.GetCharacterInfo = function(self, characterIndex)
		return unescape(game_character_info(self, characterIndex))
	end
end
