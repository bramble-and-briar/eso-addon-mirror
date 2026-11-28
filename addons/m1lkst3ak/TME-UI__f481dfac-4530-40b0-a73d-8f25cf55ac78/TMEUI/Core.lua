TMEUI={name="TMEUI",version="1.0.7"}
local N=TMEUI
function N.safe(f,...)
 if type(f)~="function" then return nil end
 local ok,a,b,c,d,e=pcall(f,...); if ok then return a,b,c,d,e end
end
function N.gameplay()
 local scene=SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
 local name=scene and scene:GetName()
 return not name or name:lower()=="hud" or name:lower()=="hudui" or name:lower()=="hudgamepad" or name:lower()=="huduigamepad"
end
