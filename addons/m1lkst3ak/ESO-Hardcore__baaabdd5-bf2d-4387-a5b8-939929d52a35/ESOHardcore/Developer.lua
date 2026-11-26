local N=ESOHardcore
local D={row=1,skill=1,level=15,overlay=1,confirm=nil};N.dev=D
local overlays={'health','poison','burn','disease','chill','shock','bleed','control','hunger','thirst'}
local function c() return N.hardcore.saved end
local function rank(k,l) c().xp[k]=N.skillThreshold(l) end
local function all(l) for _,k in ipairs(N.skillNames) do rank(k,l) end end
function D.text()
 local a=c();local lines={'DEVELOPMENT BUILD — QA CHARACTER ONLY','D-pad up/down: select; left/right: adjust; X: apply',''}
 local values={'XP multiplier: '..(a.devXP or 1)..'x','Skill: '..N.skillNames[D.skill],'Target level: '..D.level,'Apply level to selected skill','Apply level to all skills','Unlock all (99)','Hunger: '..math.floor(a.food)..'%','Thirst: '..math.floor(a.water)..'%','Preview: '..overlays[D.overlay],'Simulate death (archives QA record)','Reset assignments and contract','Reset character progression'}
 for i,v in ipairs(values) do lines[#lines+1]=(D.row==i and '> ' or '   ')..v end
 if D.confirm then lines[#lines+1]='Press X again to confirm '..D.confirm end
 return table.concat(lines,'\n')
end
function D.move(dx,dy)
 D.confirm=nil;local a=c();if dy~=0 then D.row=math.max(1,math.min(12,D.row+dy));return end
 if D.row==1 then local values={1,2,5,10,25,50,100,250,500,1000};local i=1;for j,v in ipairs(values) do if v==(a.devXP or 1) then i=j end end;a.devXP=values[math.max(1,math.min(#values,i+dx))]
 elseif D.row==2 then D.skill=(D.skill-1+dx)%#N.skillNames+1
 elseif D.row==3 then D.level=math.max(1,math.min(99,D.level+dx))
 elseif D.row==7 then a.food=math.max(0,math.min(100,a.food+dx*5))
 elseif D.row==8 then a.water=math.max(0,math.min(100,a.water+dx*5))
 elseif D.row==9 then D.overlay=(D.overlay-1+dx)%#overlays+1 end
end
function D.apply()
 local a=c();local r=D.row
 if r==4 then rank(N.skillNames[D.skill],D.level) elseif r==5 then all(D.level) elseif r==6 then all(99)
 elseif r==9 then N.hardcore.previewKind=overlays[D.overlay];N.hardcore.previewUntil=(N.safe(GetFrameTimeSeconds) or 0)+30;return true
 elseif r>=10 then local key=({'death','assignments','character reset'})[r-9];if D.confirm~=key then D.confirm=key;return end;D.confirm=nil
 if r==10 then N.simulateDeath()
 elseif r==11 then a.daily=nil;a.contract=nil
 else a.xp={};a.ownership={};a.hcGold=0;a.difficulty=1;a.difficultySeconds={};a.integrityNotes={};a.journal=nil;a.daily=nil;a.contract=nil;a.survivalSeconds=0;a.deathTime=nil;a.fallen=false;a.active=true;a.setupDone=true;a.food=100;a.water=100;a.devXP=1;if N.clearSkillNotices then N.clearSkillNotices() end end
 end
end
