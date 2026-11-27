ESOHardcore={}
local N=ESOHardcore
function N.safe(f,...) if type(f)~='function' then return end;local ok,a,b,c,d,e=pcall(f,...);if ok then return a,b,c,d,e end end
function N.gameplay() local sc=SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene();local n=sc and sc:GetName();return not n or n:lower():match('^hud')~=nil end

-- Visual mode is never an enrollment or a change to earned HC progress.
function N.isImmersive() local a=N.hardcore and N.hardcore.saved;return a~=nil and a.immersiveMode==true and not a.active and not a.fallen end
function N.visualActive() local a=N.hardcore and N.hardcore.saved;return a~=nil and ((a.active and not a.fallen) or N.isImmersive()) end
function N.setImmersive(v) local a=N.hardcore and N.hardcore.saved;if not a or a.active or a.fallen then return false end;a.immersiveMode=v==true;if N.clearSkillNotices then N.clearSkillNotices() end;if N.drop then N.drop:SetHidden(true) end;return true end
