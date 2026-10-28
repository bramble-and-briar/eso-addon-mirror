local A=Atlas
local function name(s)
 return zo_strformat("<<1>>",s or ""):gsub("%^%a+",""):lower():gsub("^%s+",""):gsub("%s+$","")
end
local names={}
for _,s in ipairs({"Chest","Truhe","coffre","Сундук","宝箱","Cofre"})do names[name(s)]="chests"end
for _,s in ipairs({"Thieves Trove","Diebesgut","trésor des voleurs","Воровской клад","盗賊の宝","Tesoro de los ladrones"})do names[name(s)]="troves"end
local function near(points,x,y)
 for _,p in ipairs(points or {})do
  if math.abs(p[1]-x)<=.003 and math.abs(p[2]-y)<=.003 then return true end
 end
end
function A.LearnContainer(_,result,target)
 if result~=CLIENT_INTERACT_RESULT_SUCCESS then return end
 local kind=names[name(target)]
 if not kind or not DoesCurrentMapMatchMapForPlayerLocation() then return end
 local map=A.MapKey()
 local x,y=GetMapPlayerPosition("player")
 if map=="" or type(x)~="number" or type(y)~="number" or x~=x or y~=y or x<=0 or x>=1 or y<=0 or y>=1 then return end
 local saved=A.saved
 saved.containerLocations=saved.containerLocations or {chests={},troves={}}
 local data=saved.containerLocations[kind]
 local points=data[map]or {}
 if near(A[kind][map],x,y) or near(points,x,y) then return end
 -- Bound additional persistent discoveries independently of bundled coordinates.
 if (saved.learnedContainerCount or 0)>=2000 or #points>=500 then return end
 points[#points+1]={math.floor(x*10000+.5)/10000,math.floor(y*10000+.5)/10000}
 data[map]=points;saved.learnedContainerCount=(saved.learnedContainerCount or 0)+1
 if A.cache then A.cache[kind]=nil end
 A.QueueRefresh({kind})
end
function A.RegisterContainerLearning()
 if EVENT_CLIENT_INTERACT_RESULT and DoesCurrentMapMatchMapForPlayerLocation and GetMapPlayerPosition then
  EVENT_MANAGER:RegisterForEvent("AtlasContainers",EVENT_CLIENT_INTERACT_RESULT,A.LearnContainer)
 end
end
