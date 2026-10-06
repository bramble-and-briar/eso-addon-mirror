--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

function LibAPH.GetPlatformString()
	local platform = GetUIPlatform()
	if platform == UI_PLATFORM_PC then return "PC"
	elseif platform == UI_PLATFORM_XBOX then return "Xbox"
	elseif platform == UI_PLATFORM_PS4 then return "PlayStation 4"
	elseif platform == UI_PLATFORM_PS5 then return "PlayStation 5"
	end
	return nil
end

function LibAPH.GetPlatformServiceName()
	if GetUIPlatform() ~= UI_PLATFORM_PC then return nil end
	local service = GetPlatformServiceType()
	if service == PLATFORM_SERVICE_TYPE_STEAM then return "Steam"
	elseif service == PLATFORM_SERVICE_TYPE_EPIC then return "Epic"
	elseif service == PLATFORM_SERVICE_TYPE_ZOS then return "ZOS"
	elseif service == PLATFORM_SERVICE_TYPE_DMM then return "DMM"
	end
	return nil
end

function LibAPH.IsAddOnRunningState(isEnabled, state)
	return isEnabled == true and (state == ADDON_STATE_ENABLED or state == ADDON_STATE_VERSION_MISMATCH)
end

function LibAPH.IsAddonActiveAndRunning(addonName)
	local am = GetAddOnManager()
	for i = 1, am:GetNumAddOns() do
		local name, _, _, _, isEnabled, state = am:GetAddOnInfo(i)
		if name == addonName and LibAPH.IsAddOnRunningState(isEnabled, state) then return true end
	end
	return false
end

function LibAPH.IsLibraryAddonByName(am, addonName)
	for i = 1, am:GetNumAddOns() do
		local name, _, _, _, _, _, _, isLibrary = am:GetAddOnInfo(i)
		if name == addonName then return isLibrary or string.sub(name, 1, 3) == "Lib" end
	end
	return false
end

function LibAPH.GetKeybindMarkup(action)
	return ZO_Keybindings_GetHighestPriorityBindingStringFromAction(action,
		KEYBIND_TEXT_OPTIONS_ABBREVIATED_NAME, KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP, true) or ""
end

function LibAPH.IsGameScreenShown()
	local scene = SCENE_MANAGER:GetCurrentScene()
	return SCENE_MANAGER:IsShowingBaseScene() and scene ~= nil and scene:GetState() == SCENE_SHOWN
end

function LibAPH.ShowMenuScene(scene)
	local menu = MAIN_MENU_KEYBOARD
	if menu and type(menu.ShowScene) == "function" and menu.sceneInfo and menu.sceneInfo[scene] then
		menu:ShowScene(scene)
	else
		SCENE_MANAGER:Show(scene)
	end
end

function LibAPH.AfterSceneShown(scene, fn)
	local function Shown()
		if type(SCENE_MANAGER.GetCurrentScene) ~= "function" then return SCENE_MANAGER:IsShowing(scene) end
		local current = SCENE_MANAGER:GetCurrentScene()
		if not current or type(current.GetName) ~= "function" or type(current.GetState) ~= "function" then
			return SCENE_MANAGER:IsShowing(scene)
		end
		return current:GetName() == scene and current:GetState() == SCENE_SHOWN
	end

	local function Wait(attempt)
		if Shown() then return fn() end
		if attempt < 10 then zo_callLater(function() Wait(attempt + 1) end, 100) end
	end
	if Shown() then return fn() end
	zo_callLater(function() Wait(1) end, 100)
end
