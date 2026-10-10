local C = CombatRecap
local U = {tab=1,page=1,selected=1}
C.UI=U
local function n(v) return string.format('%.0f',v or 0) end
local function short(v) v=v or 0; return v>=1000000 and string.format('%.2fm',v/1000000) or v>=1000 and string.format('%.1fk',v/1000) or n(v) end
local function pct(v,total) return string.format('%.1f%%',total>0 and v/total*100 or 0) end
local function label(parent,x,y,w,h,font)
 local l=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL);l:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);l:SetDimensions(w,h);l:SetFont(font or 'ZoFontGamepad18');l:SetColor(.9,.91,.94,1);return l
end
local function panel(parent,x,y,w,h)
 local b=WINDOW_MANAGER:CreateControl(nil,parent,CT_TEXTURE);b:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);b:SetDimensions(w,h);b:SetColor(.035,.04,.055,1);return b
end
function U:Initialize()
 if self.window then return end
 local w=WINDOW_MANAGER:CreateTopLevelWindow('CombatRecapWindow');self.window=w;w:SetHidden(true);w:SetAnchor(CENTER,GuiRoot,CENTER,0,-15);w:SetDimensions(1200,740)
 -- Untextured texture controls render a solid colour; no external asset required.
 self.bg=panel(w,0,0,1200,740);self.bg:SetColor(.012,.015,.022,1)
 panel(w,18,142,1164,40);panel(w,18,190,778,482);panel(w,806,190,376,482)
 self.title=label(w,26,16,1100,38,'ZoFontGamepad27');self.title:SetText('COMBAT RECAP');self.title:SetColor(.95,.38,.35,1)
 self.meta=label(w,26,58,770,26);self.summary=label(w,26,92,770,35,'ZoFontGamepad22')
 self.tabs=label(w,26,150,1148,28,'ZoFontGamepad22');self.heading=label(w,28,200,758,25)
 self.cells={};self.headers={}
 for col=1,6 do self.headers[col]=label(w,0,200,100,24);self.headers[col]:SetColor(.9,.57,.4,1) end
 for row=1,14 do
  panel(w,24,232+(row-1)*30,766,28):SetColor(.12,.14,.18,row%2==0 and 1 or .45)
  self.cells[row]={};for col=1,6 do self.cells[row][col]=label(w,0,232+(row-1)*30,100,28) end
 end
 self.sideTitle=label(w,822,202,342,28,'ZoFontGamepad22');self.sideText=label(w,822,238,342,425)
 self.effectLabels={}
 for col=1,2 do for row=1,18 do
  local l=label(w,822+(col-1)*176,238+(row-1)*23,170,23)
  l:SetMaxLineCount(1)
  self.effectLabels[#self.effectLabels+1]=l
 end end
 self.weaveBox=panel(w,806,16,376,112)
 self.weaveText=label(w,820,23,350,100)
 self.gameVersion=label(w,1080,704,100,25);self.gameVersion:SetText('ESO U51')
 self.buildGroup=WINDOW_MANAGER:CreateControl(nil,w,CT_CONTROL);self.buildGroup:SetAnchorFill(w)
 panel(self.buildGroup,18,142,1164,530)
 self.buildGear={}
 for i=1,14 do
  local y=188+(i-1)*33
  local icon=WINDOW_MANAGER:CreateControl(nil,self.buildGroup,CT_TEXTURE);icon:SetAnchor(TOPLEFT,self.buildGroup,TOPLEFT,128,y);icon:SetDimensions(27,27)
  self.buildGear[i]={slot=label(self.buildGroup,28,y,98,26),icon=icon,name=label(self.buildGroup,162,y,510,21),detail=label(self.buildGroup,162,y+19,510,18,'ZoFontGamepad18')}
 end
 self.buildHead=label(self.buildGroup,28,149,1135,32,'ZoFontGamepad22')
 self.buildBars={}
 for bar=1,2 do
  local x=bar==1 and 694 or 938
  label(self.buildGroup,x,188,230,25,'ZoFontGamepad22'):SetText(bar==1 and 'FRONT BAR' or 'BACK BAR')
  self.buildBars[bar]={}
  for i=1,6 do
   local y=220+(i-1)*30
   local icon=WINDOW_MANAGER:CreateControl(nil,self.buildGroup,CT_TEXTURE);icon:SetAnchor(TOPLEFT,self.buildGroup,TOPLEFT,x,y);icon:SetDimensions(24,24)
   self.buildBars[bar][i]={icon=icon,text=label(self.buildGroup,x+30,y,204,28)}
  end
 end
 self.buildCP={}
 local colours={{.35,.7,1,1},{1,.45,.45,1},{.4,.85,.5,1}}
 for group=1,3 do
  self.buildCP[group]={}
  for row=1,5 do
   local l=label(self.buildGroup,694+(group-1)*163,404+(row-1)*31,153,30)
   l:SetColor((unpack or table.unpack)(colours[group]));l:SetMaxLineCount(2)
   self.buildCP[group][row]=l
  end
 end
 self.buildMastery=label(self.buildGroup,694,565,478,67)
 self.buildNote=label(self.buildGroup,694,636,478,28)
 self.footer=label(w,26,687,1148,44)
 self.keybinds={alignment=KEYBIND_STRIP_ALIGN_LEFT,
 {name=function() return self.tab==1 and 'View build' or 'Combat report' end,keybind='UI_SHORTCUT_PRIMARY',callback=function() self.tab=3-self.tab;self.page=1;self:Refresh() end},
 {name='More abilities / effects',keybind='UI_SHORTCUT_SECONDARY',callback=function() self.page=self.page%(self.pages or 1)+1;self:Refresh() end,visible=function() return self.tab==1 and (self.pages or 1)>1 end},
 {name='Next fight',keybind='UI_SHORTCUT_TERTIARY',callback=function() if #C.saved.history>0 then self.selected=self.selected%#C.saved.history+1 end;self.page=1;self:Refresh() end},
 {name='Back',keybind='UI_SHORTCUT_NEGATIVE',callback=function() if self.tab==2 then self.tab=1;self:Refresh() else SCENE_MANAGER:Hide('combatRecap') end end}}
 local s=ZO_Scene:New('combatRecap',SCENE_MANAGER);self.scene=s;s:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW);s:AddFragment(ZO_SimpleSceneFragment:New(w))
 s:RegisterCallback('StateChange',function(_,state) if state==SCENE_SHOWING then self:Refresh();KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds) elseif state==SCENE_HIDING then KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybinds) end end)
end
function U:Open(index)
 if IsUnitInCombat('player') then d('Combat Recap: open after combat. /recap stop ends recording.');return end
 if C.Tracker.fight and not C.Tracker:EncounterInProgress() then C.Tracker:Finish('Combat ended') end
 self:Initialize();self.selected=math.max(1,math.min(index or 1,#C.saved.history));self.tab=1;self.page=1;SCENE_MANAGER:Show('combatRecap')
end
function U:Refresh()
 local scale=math.min(1,GuiRoot:GetWidth()*.94/1200,GuiRoot:GetHeight()*.86/740);self.window:SetScale(scale)
 self.buildGroup:SetHidden(self.tab~=2)
 self.weaveBox:SetHidden(self.tab==2);self.weaveText:SetHidden(self.tab==2)
 for _,l in ipairs(self.effectLabels) do l:SetHidden(self.tab==2);l:SetText('') end
 self.sideTitle:SetHidden(self.tab==2);self.sideText:SetHidden(self.tab==2);self.heading:SetHidden(self.tab==2)
 for _,l in ipairs(self.headers) do l:SetHidden(self.tab==2) end
 for _,row in ipairs(self.cells) do for _,l in ipairs(row) do l:SetHidden(self.tab==2) end end
 self.tabs:SetText(self.tab==1 and '|cEF7464COMBAT OVERVIEW|r                         A: View fight build' or 'COMBAT OVERVIEW     |cEF7464BUILD & WEAVING|r')
 for _,row in ipairs(self.cells) do for _,l in ipairs(row) do l:SetText('') end end
 for _,l in ipairs(self.headers) do l:SetText('') end
 local f=C.saved.history[self.selected];self.heading:SetText('')
 if not f then self.meta:SetText('No recorded fights');self.summary:SetText('Finish a fight, then open /recap.');self.sideTitle:SetText('PERSONAL RECAP');self.sideText:SetText('Player and pets.\nNo group or companion damage.');self.footer:SetText('Combat Recap '..C.VERSION..' | @TheGreyWolf98');self.weaveText:SetText('');self.pages=1;return end
 local targets=C.Sorted(f.targets,'damage');local abilities=C.Sorted(f.abilities,'damage');local effects=C.Sorted(f.effects,'uptimeMs')
 if self.tab==2 then self:PaintBuild(f);return end
 self.meta:SetText(string.format('%s | %s | %s | Fight %d/%d',f.character,targets[1] and targets[1].name or 'Unknown',f.zone,self.selected,#C.saved.history))
 self.summary:SetText(string.format('DPS %s    DAMAGE %s    TIME %.1fs    CRIT %s    HITS %s',n(f.damage/f.duration),short(f.damage),f.duration,pct(f.crits,f.hits),n(f.hits)))
 local rows,headers,x,widths={},{},{},{ }
 if self.tab==1 then
  headers={'ABILITY','DAMAGE','SHARE','HITS','CRIT','MAX'};x={28,360,455,545,620,706};widths={325,90,85,70,80,78}
  for _,e in ipairs(abilities) do rows[#rows+1]={e.name,short(e.damage),pct(e.damage,f.damage),n(e.hits),pct(e.crits,e.hits),short(e.max)} end
  self.pages=math.max(1,math.ceil(#rows/14),math.ceil(#effects/36));self.page=math.min(self.page,self.pages)
  -- Effect paging is independent of ability paging when all effects fit.
  local effectPage=math.min(self.page,math.max(1,math.ceil(#effects/36)))
  self.sideTitle:SetText('PLAYER EFFECTS ('..#effects..')')
  self.sideText:SetText('')
  for i,l in ipairs(self.effectLabels) do
   local e=effects[(effectPage-1)*36+i]
   l:SetText(e and (pct(e.uptimeMs,f.duration*1000)..' '..e.name) or '')
  end
  self.weaveText:SetText('WEAVING\nLA inputs / damage events: '..n(f.weave.laInputs)..' / '..n(f.laHits)..'\nOne LA input / interval: '..pct(f.weave.single,f.weave.intervals)..'\nInputs are not confirmed landed hits.')
 else
  headers={'SLOT','EQUIPMENT','TRAIT','ENCHANT','', ''};x={28,145,458,605,780,780};widths={112,308,142,180,1,1}
  for _,e in ipairs(f.gear or {}) do rows[#rows+1]={e.slot,e.name,e.trait,e.enchant} end
  if not f.gear then rows={{'No snapshot','Record a new fight for gear.'}} end
  self.pages=1;self.page=1;self.sideTitle:SetText('WEAVING OBSERVATIONS')
  local v=f.weave;local mean=v.delayCount>0 and v.delaySum/v.delayCount or 0
  self.sideText:SetText(string.format('LA input events: %s\nClassified LA damage events: %s\nLA damage: %s\nHeavy input events: %s\n\nSkill events: %s\nUltimate events: %s\nEligible intervals: %s\nOne LA input: %s\nZero / multiple: %s / %s\nMean interval: %sms\nExcluded intervals: %s\n\nInputs do not prove landed hits.\nNo missed-weave score.\n\nGear saved at fight start.',n(v.laInputs),n(f.laHits),short(f.laDamage),n(v.heavyInputs),n(v.skills),n(v.ultimates),n(v.intervals),pct(v.single,v.intervals),n(v.zero),n(v.multiple),n(mean),n(v.excluded)))
 end
 for col=1,6 do local l=self.headers[col];l:ClearAnchors();l:SetAnchor(TOPLEFT,self.window,TOPLEFT,x[col],200);l:SetDimensions(widths[col],24);l:SetText(headers[col] or '') end
 for row=1,14 do local values=rows[(self.page-1)*14+row];for col=1,6 do local l=self.cells[row][col];l:ClearAnchors();l:SetAnchor(TOPLEFT,self.window,TOPLEFT,x[col],232+(row-1)*30);l:SetDimensions(widths[col],28);l:SetText(values and values[col] or '') end end
 self.footer:SetText(string.format('DPS: first to last damage | Personal + pets | Detail page %d/%d\nCombat Recap %s | @TheGreyWolf98',self.page,self.pages,C.VERSION))
end

function U:PaintBuild(f)
 local b=f.build
 self.tabs:SetText('');self.buildHead:SetText('FIGHT BUILD | '..(b and b.race..' '..b.class or 'Older snapshot')..(b and b.pairLocked and ' | Weapon swap locked' or ''))
 self.meta:SetText(f.character..' | '..f.zone..' | Fight '..self.selected..'/'..#C.saved.history)
 self.summary:SetText(b and ('Level '..b.level..' / CP '..b.cp..' | Mundus: '..b.mundus) or 'Older fight: new build details were not captured.')
 for i,c in ipairs(self.buildGear) do
  local e=(b and b.gear or f.gear or {})[i]
  c.slot:SetText(e and e.slot or '');c.name:SetText(e and e.name or '')
  c.name:SetColor(.9,.75,.4,1)
  c.detail:SetText(e and (e.detail or 'Older snapshot: trait text unavailable') or '')
  c.icon:SetHidden(not(e and e.icon));if e and e.icon then c.icon:SetTexture(e.icon) end
 end
 for bar,controls in ipairs(self.buildBars) do
  local rows=b and (bar==1 and b.front or b.back) or {}
  for i,c in ipairs(controls) do local e=rows[i];c.text:SetText(e and ((e.ultimate and 'ULT: ' or '')..e.name) or 'Not captured');c.icon:SetHidden(not(e and e.icon));if e and e.icon then c.icon:SetTexture(e.icon) end end
 end
 local names={'WARFARE','FITNESS','CRAFT'};local types={CHAMPION_DISCIPLINE_TYPE_COMBAT,CHAMPION_DISCIPLINE_TYPE_CONDITIONING,CHAMPION_DISCIPLINE_TYPE_WORLD}
 for group=1,3 do
  local entries={}
  for _,e in ipairs(b and b.champion or {}) do if e.discipline==types[group] then entries[#entries+1]=e.name..' · '..tostring(e.points or '?') end end
  self.buildCP[group][1]:SetText(names[group])
  for row=1,4 do self.buildCP[group][row+1]:SetText(entries[row] or 'Not captured') end
 end
 local mastery={'CLASS MASTERY'}
 for _,e in ipairs(b and b.masteries or {}) do mastery[#mastery+1]=e.name..(e.rank and (' · Rank '..e.rank) or '') end
 if #mastery==1 then mastery[#mastery+1]=b and b.masteryReadable and 'None purchased' or 'Not available from this snapshot' end
 self.buildMastery:SetText(table.concat(mastery,'\n'))
 self.buildNote:SetText('Saved at fight start | B: combat report')
 self.footer:SetText('Combat Recap '..C.VERSION..' | @TheGreyWolf98 | Fight-start build snapshot')
end
