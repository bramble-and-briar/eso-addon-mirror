if not Taneth or not Taneth.IsExternal() then return end

SLASH_COMMANDS = SLASH_COMMANDS or {}

if not HUD_SCENE then
	HUD_SCENE = { IsShowing = function() return false end }
end

if not HUD_UI_SCENE then
	HUD_UI_SCENE = { IsShowing = function() return false end }
end
