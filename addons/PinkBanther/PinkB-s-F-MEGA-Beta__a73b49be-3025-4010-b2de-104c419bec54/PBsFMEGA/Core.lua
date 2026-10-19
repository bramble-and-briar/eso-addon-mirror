PBF=PBF or {}
local C={};PBF.Core=C
local pi=math.pi
function C.clamp(v,lo,hi) if v<lo then return lo elseif v>hi then return hi end return v end
function C.lerp(a,b,t) return a+(b-a)*t end
-- Lua 5.1 (the client) has atan2; 5.4 (the test machine) folded it into atan.
C.atan2=math.atan2 or function(y,x) return math.atan(y,x) end
function C.wrapAngle(a)
 while a>pi do a=a-2*pi end
 while a<-pi do a=a+2*pi end
 return a
end
-- A replay with the same seed has to repeat exactly, and math.random is shared with every other
-- add-on, so the race owns a small generator of its own.
function C.Rng(seed)
 local s=math.floor(seed)%2147483647
 if s<=0 then s=s+2147483646 end
 return function() s=(s*48271)%2147483647;return s/2147483647 end
end
-- Race clock as m:ss.cc, the way a lap board prints it.
function C.FormatTime(t)
 if not t then return '--:--.--' end
 local m=math.floor(t/60);local s=t-m*60
 return string.format('%d:%05.2f',m,s)
end
