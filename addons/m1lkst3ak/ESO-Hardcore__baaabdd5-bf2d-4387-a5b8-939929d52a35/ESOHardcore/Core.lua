ESOHardcore={}
local N=ESOHardcore
function N.safe(f,...) if type(f)~='function' then return end;local ok,a,b,c,d,e=pcall(f,...);if ok then return a,b,c,d,e end end
function N.gameplay() local sc=SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene();local n=sc and sc:GetName();return not n or n:lower():match('^hud')~=nil end
