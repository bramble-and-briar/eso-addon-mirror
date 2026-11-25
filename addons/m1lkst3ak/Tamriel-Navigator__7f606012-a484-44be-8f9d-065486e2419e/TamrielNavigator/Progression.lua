local N=TamrielNavigator
local function call(n,...) local f=_G[n]; if type(f)~='function' then return end; local ok,a,b,c,d,e,f=pcall(f,...); if ok then return a,b,c,d,e,f end end
local function rank(name)
 for t=1,(SKILL_TYPE_MAX_VALUE or 9) do
  for i=1,(call('GetNumSkillLines',t) or 0) do
   local label,r=call('GetSkillLineInfo',t,i)
   if label==name then return r end
  end
 end
end
local function status(r,target) if type(r)~='number' then return 'CHECK' end; return r>=target and 'DONE' or (r..' / '..target) end
function N:guideDisplay(title,lines,page,kind)
 -- split on bounded chunks to avoid a fixed-height wall of text
 local pages,cur={},{}; local chars=0
 for _,line in ipairs(lines) do
  while #line>420 do local cut=420; while cut>300 and line:sub(cut,cut)~=' ' do cut=cut-1 end; local part=line:sub(1,cut); if chars+#part>650 and #cur>0 then pages[#pages+1]=table.concat(cur,'\n\n'); cur={}; chars=0 end; cur[#cur+1]=part; chars=chars+#part; line=line:sub(cut+1) end
  if chars+#line>650 and #cur>0 then pages[#pages+1]=table.concat(cur,'\n\n'); cur={}; chars=0 end
  cur[#cur+1]=line; chars=chars+#line
 end
 if #cur>0 then pages[#pages+1]=table.concat(cur,'\n\n') end
 if #pages==0 then pages[1]='No information available.' end
 page=((page or 1)-1)%#pages+1; self.guideKind=kind; self.guidePage=page
 self.title:SetText(title..'  |  '..page..'/'..#pages); self.body:SetText(pages[page]); self:fit(); self.token=(self.token or 0)+1; self.hud:SetHidden(false)
end
function N:development(page)
 local speed,stamina,capacity=call('GetRidingStats'); local level=call('GetUnitLevel','player'); local mundus='CHECK'
 local lines={
 '|cD6B66A01  DAILY RIDING|r  Speed '..status(speed,60)..' | Stamina '..status(stamina,60)..' | Capacity '..status(capacity,60)..'. Visit a stablemaster when training is available; speed first.',
 '|cD6B66A02  GUILDS|r  Fighters '..status(rank('Fighters Guild'),1)..'; Mages '..status(rank('Mages Guild'),1)..'; Undaunted '..status(rank('Undaunted'),1)..'. Join early to earn reputation.',
 '|cD6B66A03  CYRODIIL|r  '..(type(level)=='number' and level<10 and 'Unlocks at level 10.' or 'Assault '..status(rank('Assault'),3)..'. Complete the introduction and purchase Continuous Attack for Major Gallop.'),
 '|cD6B66A04  WRITS|r  CHECK: certify your crafting disciplines and complete available daily writs.',
 '|cD6B66A05  ALCHEMY|r  '..status(rank('Alchemy'),50)..'. Purchase Medicinal Use rank 3 for longer potion effects.',
 '|cD6B66A06  UNDAUNTED|r  '..status(rank('Undaunted'),9)..'. Invest in Undaunted Mettle for mixed armor bonuses.',
 '|cD6B66A07  SKILL LINES|r  Unlock armor, weapon and class lines; equip appropriate skills when earning XP.',
 '|cD6B66A08  MUNDUS|r  CHECK: select a boon appropriate to your role; Thief, Ritual, Atronach or Lord are examples.',
 '|cD6B66A09  SKILL POINTS|r  Available: '..tostring(call('GetAvailableSkillPoints') or 'unknown')..'. Collect skyshards, public dungeon group events and one-time dungeon quest rewards.',
 '|cD6B66A10  SCRIBING|r  CHECK: unlock the Scholarium if accessible; use scripts to fill utility gaps.',
 '|cD6B66A11  CHAMPION POINTS|r  CHECK: allocate available points and slot relevant stars, including on alts.',
 '|cD6B66A12  GEAR|r  '..(type(level)=='number' and level<50 and 'Use Training gear while leveling.' or 'At CP160 gear cap, refine sets, traits and glyphs. Prioritize weapon upgrades where useful.'),
 '|cD6B66A13  CONSUMABLES|r  CHECK: maintain appropriate food or drink and quickslot potions.',
 '|cD6B66A14  OPTIONAL SYSTEMS|r  Psijic '..status(rank('Psijic Order'),1)..'; Scrying '..status(rank('Scrying'),1)..'. Consider Antiquities, vampire or werewolf only when useful.'}
 self:guideDisplay('CHARACTER DEVELOPMENT',lines,page,'development')
end
local priorities={
 {"Story","ZONE_STORY_QUESTS","Continue the regional story to understand the conflict and earn quest rewards."},
 {"Skyshards","SKYSHARDS","Collect missing skyshards; every three collected across Tamriel grant a skill point."},
 {"Public dungeons","PUBLIC_DUNGEONS","Explore unfinished public dungeons; check their group event for a separate skill point."},
 {"Wayshrines","WAYSHRINES","Discover missing wayshrines to make future travel easier."},
 {"Lorebooks","MAGES_GUILD_BOOKS","Recover unread Shalidor books for Mages Guild reputation."},
 {"Delves","DELVES","Explore unfinished delves and search for their skyshards."},
 {"Side quests / POIs","POINTS_OF_INTEREST","Help local inhabitants at unfinished points of interest."},
 {"World events","WORLD_EVENTS","Join an unfinished world event for rewards and regional progress."},
 {"World bosses","WORLD_BOSSES","Find allies for an undefeated world boss."},
}
function N:zoneSnapshot()
 local idx=call('GetUnitZoneIndex','player'); local id=idx and call('GetZoneId',idx)
 local story=id and call('GetZoneStoryZoneIdForZoneId',id); if type(story)=='number' and story>0 then id=story end
 local zone=(id and call('GetZoneNameById',id)) or call('GetUnitZone','player') or 'Unknown zone'
 local rows,seen={},{}; local function add(typ,label,advice)
  if not typ or seen[typ] or not id then return end; seen[typ]=true
  local total=call('GetNumZoneActivitiesForZoneCompletionType',id,typ)
  local done=call('GetNumCompletedZoneActivitiesForZoneCompletionType',id,typ)
  if type(total)=='number' and total>0 and type(done)=='number' and done>=0 then
   local available=call('GetNumUnblockedZoneStoryActivitiesForZoneCompletionType',id,typ)
   rows[#rows+1]={typ=typ,label=label,advice=advice,total=total,done=done,blocked=type(available)=='number' and available<=done and done<total}
  end
 end
 for _,v in ipairs(priorities) do add(_G['ZONE_COMPLETION_TYPE_'..v[2]],v[1],v[3]) end
 for _,typ in ipairs(ZO_ZONE_STORY_ACTIVITY_COMPLETION_TYPES_SORTED_LIST or {}) do add(typ,call('GetString','SI_ZONECOMPLETIONTYPE',typ) or 'Other activity','Explore the remaining activity.') end
 return zone,id,rows
end
function N:zoneGuide(page)
 local zone,id,rows=self:zoneSnapshot(); local lore=NavigatorZoneLore[zone]; self.zoneTarget=nil
 local lines={'|cD6B66A'..zone..'|r',lore or 'Regional lore is not yet available for this location.'}
 local nextRow; local done,total=0,0; local remaining,finished={},{}
 for _,r in ipairs(rows) do
  done=done+math.min(r.done,r.total); total=total+r.total
  local label=r.label..': '..r.done..' / '..r.total
  if r.done>=r.total then finished[#finished+1]=label else
   remaining[#remaining+1]=label..' ('..(r.total-r.done)..' left)'..(r.blocked and ' - gated' or '')
   if not nextRow and not r.blocked then nextRow=r end
  end
 end
 if nextRow then
  self.zoneTarget={id=id,typ=nextRow.typ}
  lines[#lines+1]='|cD6B66ANEXT RECOMMENDED ACTION|r\n'..nextRow.advice..'\nUse Track recommended zone activity in settings to open the native map and track it.'
 elseif total>0 and #remaining==0 then lines[#lines+1]='|cD6B66AZONE GUIDE COMPLETE|r\nAll measured zone activities are complete. Optional collectible and repeatable quests may remain.'
 elseif total>0 then lines[#lines+1]='Remaining activities appear gated. Check the native Zone Guide for requirements.'
 else lines[#lines+1]='Live zone completion unavailable here. No completion or recommendation is assumed.' end
 if total>0 then lines[#lines+1]='|cD6B66APROGRESS|r  '..done..' / '..total..' tracked activities (native Zone Guide scope).' end
 if #remaining>0 then lines[#lines+1]='|cD6B66ASTILL TO DO|r\n'..table.concat(remaining,'\n') end
 if #finished>0 then lines[#lines+1]='|cD6B66ACOMPLETED|r\n'..table.concat(finished,'\n') end
 self:guideDisplay('ZONE INTELLIGENCE',lines,page,'zone')
end
function N:trackZoneAdvice()
 self:zoneGuide(1); local t=self.zoneTarget
 if not t then d('[Navigator] No verified actionable zone activity.'); return end
 local found=call('TrackNextActivityForZoneStory',t.id,t.typ,true)
 if found then self.hud:SetHidden(true) else d('[Navigator] Native tracking unavailable for this activity. Open Zone Guide manually.') end
end
function N:guideNext() if self.guideKind=='zone' then self:zoneGuide((self.guidePage or 0)+1) else self:development((self.guidePage or 0)+1) end end

-- Independent compact HUD; full reports retain their existing window.
function N:initZoneStrip()
 local w=WINDOW_MANAGER
 self.zoneStrip=w:CreateTopLevelWindow('TamrielNavigatorZoneStrip'); self.zoneStrip:SetMouseEnabled(false); self.zoneStrip:SetHidden(true)
 local b=w:CreateControl(nil,self.zoneStrip,CT_BACKDROP); b:SetAnchorFill(); b:SetCenterColor(.018,.014,.009,.91); b:SetEdgeColor(.76,.59,.30,1); b:SetEdgeTexture('',8,1,2)
 self.zoneHead=w:CreateControl(nil,self.zoneStrip,CT_LABEL); self.zoneHead:SetColor(.91,.78,.48,1); self.zoneHead:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
 self.zoneAction=w:CreateControl(nil,self.zoneStrip,CT_LABEL); self.zoneAction:SetColor(.95,.93,.88,1); self.zoneAction:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
 self.zoneArrow=w:CreateControl(nil,self.zoneStrip,CT_TEXTURE); self.zoneArrow:SetTexture("TamrielNavigator/Arrow.dds"); self.zoneArrow:SetHidden(true)
 self:layoutZoneStrip()
 EVENT_MANAGER:RegisterForUpdate(self.name.."Arrow",50,function() N:updateAdventureArrow() end)
 EVENT_MANAGER:RegisterForUpdate(self.name..'ZoneStrip',2000,function() N:updateZoneStrip() end)
end
function N:layoutZoneStrip()
 if not self.zoneStrip then return end
 local s=self.s; local scale=s.zoneScale/100; local rw,rh=GuiRoot:GetWidth(),GuiRoot:GetHeight(); local width=math.min(rw-12,rw*s.zoneWidth/100)/scale; local font=s.zoneFont
 self.zoneStrip:SetScale(scale); self.zoneStrip:SetWidth(width); self.zoneStrip:SetHeight(font*3+16)
 local halfW=width*scale/2; local halfH=(font*3+16)*scale/2
 self.zoneStrip:ClearAnchors(); self.zoneStrip:SetAnchor(CENTER,GuiRoot,TOPLEFT,math.max(halfW,math.min(rw-halfW,rw*s.zoneX/100)),math.max(halfH,math.min(rh-halfH,rh*s.zoneY/100)))
 for i,label in ipairs({self.zoneHead,self.zoneAction}) do label:ClearAnchors(); label:SetAnchor(TOPLEFT,self.zoneStrip,TOPLEFT,8,i==1 and 5 or font+9); label:SetWidth(width-16); label:SetHeight(i==1 and font+5 or font*2+2); label:SetFont('$(MEDIUM_FONT)|'..font..'|soft-shadow-thin') end
 self.zoneArrow:ClearAnchors(); self.zoneArrow:SetAnchor(LEFT,self.zoneStrip,LEFT,8,font/2); self.zoneArrow:SetDimensions(font*1.7,font*1.7)
end
function N:updateZoneStrip(preview)
 if not self.zoneStrip then return end
 local scene=SCENE_MANAGER and (SCENE_MANAGER:IsShowing('hud') or SCENE_MANAGER:IsShowing('hudui'))
 if not self.s.zoneHud or self.travel or (not preview and (not scene or self.s.zoneCombat and call('IsUnitInCombat','player'))) then self.zoneStrip:SetHidden(true); return end
 local zone,id,rows=self:zoneSnapshot(); local done,total,nextRow=0,0,nil
 local skill=call('GetAvailableSkillPoints')
 for _,r in ipairs(rows) do
  done=done+math.min(r.done,r.total); total=total+r.total
  if r.done<r.total and not r.blocked then
   if not nextRow or (type(skill)=='number' and skill==0 and r.label=='Skyshards') then nextRow=r end
  end
 end
 self.zoneHead:SetText(zone..(total>0 and ('  |  '..math.floor(done*100/total)..'%') or ''))
 self.zoneAction:SetText(nextRow and ('NEXT: '..nextRow.label..'  |  '..(nextRow.total-nextRow.done)..' left') or (total==0 and 'Zone progress unavailable' or (done==total and 'Zone Guide complete' or 'Remaining activities gated')))
 local text,status=self:adventureText()
 if text then self.zoneAction:SetWidth(self.zoneStrip:GetWidth()-self.s.zoneFont*4-16); self.zoneAction:ClearAnchors(); self.zoneAction:SetAnchor(TOP,self.zoneStrip,TOP,0,self.s.zoneFont+9); self.zoneAction:SetText(text) else self.zoneAction:SetWidth(self.zoneStrip:GetWidth()-16) end
 self.zoneStrip:SetHidden(false); self:updateAdventureArrow()
end
