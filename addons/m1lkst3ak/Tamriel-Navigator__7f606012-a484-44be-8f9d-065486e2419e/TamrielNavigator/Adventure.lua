local N=TamrielNavigator
local function call(fn,...) if type(fn)~='function' then return end local ok,a,b,c=pcall(fn,...); if ok then return a,b,c end end
local function coord(x) return type(x)=='number' and x>0 and x<1 end
local function atan2(y,x) if math.atan2 then return math.atan2(y,x) end if x>0 then return math.atan(y/x) elseif x<0 then return math.atan(y/x)+(y>=0 and math.pi or -math.pi) elseif y~=0 then return y>0 and math.pi/2 or -math.pi/2 end return 0 end
function N:findAdventure()
 if not self.s.adventure then return end
 if call(DoesCurrentMapMatchMapForPlayerLocation)~=true then return nil,'Quest map not synchronized' end
 local x,y,h=call(GetMapPlayerPosition,'player'); if not coord(x) or not coord(y) then return nil,'Player position unavailable' end
 local texture=call(GetMapTileTexture,1); if type(texture)~='string' then return nil,'Map texture unavailable' end
 local map=texture:lower():gsub('\\','/'):gsub('%.dds$',''):gsub('^.-maps/','')
 local data=NavigatorQuestLocations[map]; if not data then return nil,'No recorded quest locations on this map' end
 local active={}; for i=1,(MAX_JOURNAL_QUESTS or 25) do local id=call(GetJournalQuestId,i); if id and id>0 then active[id]=true end end
 local best,dist; local checks={}
 local function completed(id) if checks[id]==nil then local c=call(HasCompletedQuest,id); checks[id]=c==nil and 'unknown' or c end; return checks[id] end
 local function eligible(id)
  if active[id] or NavigatorRemovedQuests[id] or completed(id)~=false or (self.adventureSkip and self.adventureSkip[map..':'..id]) then return false end
  for _,p in ipairs(NavigatorQuestPrerequisites[id] or {}) do if completed(p)~=true then return false end end
  for _,p in ipairs(NavigatorQuestBreadcrumbs[id] or {}) do if active[p] or completed(p)~=false then return false end end
  return true
 end
 for _,t in ipairs(data) do
  local px,py,id=t[1],t[2],t[5]
  if coord(px) and coord(py) and type(id)=='number' and id>0 and eligible(id) then
   local d=(px-x)^2+(py-y)^2
   if not dist or d<dist then best={x=px,y=py,id=id,giver=NavigatorQuestGivers[t[6]],name=NavigatorQuestNames[id]}; dist=d end
  end
 end
 if not best then return nil,'No eligible recorded quests' end
 best.map=map
 return best
end
function N:adventureText()
 local target,status=self:findAdventure(); self.adventureTarget=target
 if not target then return nil,status end
 local name=type(target.giver)=='string' and target.giver~='' and target.giver or 'Quest giver'
 local quest=type(target.name)=='string' and target.name~='' and target.name or 'Unstarted quest'
 return name..'  |  '..quest
end
function N:skipAdventure()
 local t=self.adventureTarget; if t then self.adventureSkip=self.adventureSkip or {}; self.adventureSkip[t.map..':'..t.id]=true; self:updateZoneStrip(true) end
end

function N:updateAdventureArrow()
 local t=self.adventureTarget
 if not self.zoneArrow then return end
 if not t or self.travel or self.zoneStrip:IsHidden() or call(DoesCurrentMapMatchMapForPlayerLocation)~=true then self.zoneArrow:SetHidden(true); return end
 local x,y,h=call(GetMapPlayerPosition,'player')
 local heading=call(GetPlayerCameraHeading) or h
 if not coord(x) or not coord(y) or type(heading)~='number' then self.zoneArrow:SetHidden(true); return end
 local dx,dy=t.x-x,t.y-y
 if dx*dx+dy*dy<0.000004 then self.zoneArrow:SetHidden(true); return end
 self.zoneArrow:SetTextureRotation(atan2(dx,-dy)+heading)
 self.zoneArrow:SetHidden(false)
end
