local R=RuntimeWatch
local W,H,N=1380,920,7
local tabNames={'ADD-ON CPU','FUNCTIONS','BASELINE COMPARISON','LOAD INTERVALS','ERRORS','HELP'}
local function fmt(v)return string.format('%.2f',tonumber(v)or 0)end
local function rate(row,report)return row.ms/math.max(1,report.elapsedMs)*1000 end
local function text(parent,x,y,w,h,size)
 local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL);c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(w,h)
 c:SetFont('$(GAMEPAD_MEDIUM_FONT)|'..size..'|soft-shadow-thin');c:SetColor(.94,.96,1,1);return c
end
local help={
 {'First capture','The first enable captures startup once. Later captures must be armed with X or /runtime arm.'},
 {'Capture coverage','Starts when Runtime Watch initializes. Earlier add-ons and pre-login work are excluded; alphabetical folder names do not guarantee load order.'},
 {'Startup window','Stops three seconds after player activation, or after 12 seconds / 600 frames, whichever comes first. Long loading screens may exceed this window.'},
 {'Manual capture','A records five seconds now. Reproduce the lag or open the crafting station during that window. /runtime stop ends a capture early.'},
 {'CPU totals','Native profiler records are grouped by source add-on. Exclusive time subtracts direct child calls, avoiding nested double-counting.'},
 {'Libraries and engine calls','Libraries keep their own source bucket. Native / ESO calls inherit a traceable calling add-on; unrelated engine work stays ESO / unattributed.'},
 {'Limited mode','If native profiling is absent or blocked, CPU rankings are unavailable. Load intervals, errors, FPS samples and timer gaps are supporting clues only.'},
 {'Load intervals are not CPU','The interval before a named load event can include other add-ons, parsing, callbacks or engine waiting. It does not prove that named add-on is slow.'},
 {'Compare like with like','Y saves the last report as baseline. Capture the same activity on the same character, changing one suspected add-on at a time in ESO settings.'},
 {'Profiling has overhead','Keep captures short and run one profiler at a time. Timer gaps and FPS changes can include loading screens, rendering and other add-ons.'},
 {'Bounded reports','Analysis runs in small batches. Large frames and records above the limit are omitted and clearly marked PARTIAL. Only the last report and one baseline are saved.'},
 {'No automatic changes','Runtime Watch does not disable add-ons, force garbage collection or replace other add-ons’ event callbacks. Nothing is sent to chat or other players automatically.'},
 {'Runtime warnings','A timeout may abort a function before a usable completed record exists. Check Errors and compare another controlled run before naming a culprit.'},
 {'Controls','LB/RB tabs. D-pad selection. LT/RT pages. A capture. X arm next login. Y baseline. Left-stick click Socials. B close.'},
}
function R.Rows()
 local report=R.db and R.db.last;local rows={}
 if R.tab==6 then for _,h in ipairs(help)do rows[#rows+1]={title=h[1],sub=h[2],detail=h[2]}end;return rows end
 if not report then return {{title='No completed report yet',sub='A: capture five seconds now. X: arm the next login or /reloadui.'}}end
 if R.tab==1 then
  if report.mode~='cpu'then return {{title='CPU profiling unavailable on this client',sub=report.note or 'Use Load intervals, Errors and controlled comparisons. These do not identify per-add-on CPU.'}}end
  for _,a in ipairs(report.addons or {})do
   rows[#rows+1]={title=a.name,metric=fmt(a.ms)..' ms | '..a.calls..' calls',sub=a.name==R.name and 'Runtime Watch overhead (includes capture administration).'or a.name=='ESO / unattributed'and 'Engine / unassigned records; not an add-on culprit.'or ('Exclusive CPU rate: '..fmt(rate(a,report))..' ms/s'),detail='Exclusive captured script CPU: '..fmt(a.ms)..' ms. Largest exclusive function record: '..fmt(a.max)..' ms. Calls are profiler function records, not event-loop counts.'}
  end
 elseif R.tab==2 then
  for _,f in ipairs(report.functions or {})do
   rows[#rows+1]={title=f.name,metric=fmt(f.ms)..' ms | '..f.calls..' calls',sub=f.owner..' | '..f.file..':'..f.line,detail=f.owner..' | '..f.file..':'..f.line..'\nLargest exclusive record: '..fmt(f.max)..' ms. This page ranks exclusive time, not whole parent-call duration.'}
  end
 elseif R.tab==3 then
  local baseline=R.db.baseline
  if not baseline then return {{title='No baseline saved',sub='Complete a capture, press Y, then record the same activity with one suspected add-on changed.'}}end
  if report.mode~='cpu'or baseline.mode~='cpu'then return {{title='CPU comparison unavailable',sub='Both captures need native profiler results. Load intervals cannot replace per-add-on CPU measurements.'}}end
  local lookup={};for _,a in ipairs(baseline.addons or {})do lookup[a.name]={before=a}end
  for _,a in ipairs(report.addons or {})do local v=lookup[a.name]or {};v.after=a;lookup[a.name]=v end
  for name,v in pairs(lookup)do
   local b=v.before and rate(v.before,baseline)or 0;local c=v.after and rate(v.after,report)or 0
   rows[#rows+1]={title=name,metric=string.format('%+.2f ms/s',c-b),sub='Baseline '..fmt(b)..' ms/s | Current '..fmt(c)..' ms/s',delta=c-b,detail='Baseline: '..baseline.character..' / '..baseline.kind..'. Current: '..report.character..' / '..report.kind..'. Compare matching activities and durations; startup coverage can differ.'}
  end
  table.sort(rows,function(a,b)return math.abs(a.delta)>math.abs(b.delta)end)
 elseif R.tab==4 then
  for _,g in ipairs(report.loadGaps or {})do rows[#rows+1]={title='Before '..g.name,metric=fmt(g.ms)..' ms elapsed',sub='Load-event interval; NOT the named add-on’s CPU time.',detail='Startup interval before this event; it can predate a manual capture. Other handlers, add-ons, parsing and engine waits may contribute. This is not named add-on CPU.',ms=g.ms}end
  table.sort(rows,function(a,b)return a.ms>b.ms end)
 elseif R.tab==5 then
  for _,e in ipairs(report.errors or {})do rows[#rows+1]={title=e.kind,sub=e.message,detail=e.message}end
 end
 if #rows==0 then rows[1]={title='No records on this page',sub=report.mode=='cpu'and 'Captured records may be empty, untraceable or limited; see Help.'or 'See Help for capture limits.'}end
 return rows
end
function R.Paint()
 if not R.window or not R.db then return end
 local report=R.db.last
 local mode=R.run and ('CAPTURING / '..R.run.mode:upper())or R.analysis and 'ANALYZING' or report and (report.mode=='cpu'and 'NATIVE CPU' or 'LIMITED / NO CPU RANKING')or 'READY'
 local line=R.status:sub(1,100)..'\nNext login: '..(R.db.armed and 'ARMED' or 'OFF')..' | '..mode
 if report then
  local fps=report.samples>0 and fmt(report.fpsSum/report.samples)or 'N/A'
  line=line..'\n'..report.character..' | '..report.kind..' | '..fmt(report.elapsedMs/1000)..'s | Avg FPS '..fps..' | Max timer gap '..fmt(report.maxGap)..'ms'..(report.partial and ' | PARTIAL' or '')
 end
 R.summary:SetText(line)
 R.tabLabel:SetText(tabNames[R.tab]..'   /   LB / RB change page type')
 local rows=R.Rows();R.count=#rows;R.selected=math.max(1,math.min(R.selected,#rows));R.page=math.floor((R.selected-1)/N)+1
 for i,c in ipairs(R.labels)do
  local idx=(R.page-1)*N+i;local r=rows[idx]
  c.bg:SetHidden(not r);c.bg:SetCenterColor(idx==R.selected and .15 or .045,idx==R.selected and .18 or .055,idx==R.selected and .23 or .07,1)
  c.bg:SetEdgeColor(idx==R.selected and .85 or .24,idx==R.selected and .65 or .27,idx==R.selected and .28 or .32,1)
  c.title:SetText(r and r.title or '');c.metric:SetText(r and r.metric or '');c.sub:SetText(r and r.sub or '')
 end
 local r=rows[R.selected];R.detail:SetText(r and r.detail or r and r.sub or '')
 R.footer:SetText('Page '..R.page..'/'..math.max(1,math.ceil(#rows/N))..' | LT/RT pages | D-pad select | A capture | X arm login | Y baseline\nCapture starts after Runtime Watch loads. Earlier work is excluded. Profiling adds overhead.')
 if R.scene:IsShowing()then KEYBIND_STRIP:UpdateKeybindButtonGroup(R.keys)end
end
function R.Open()
 if not R.db then return end
 if IsUnitInCombat('player')then d('Runtime Watch: open after combat.');return end
 if not R.window then
  local w=WINDOW_MANAGER:CreateTopLevelWindow('TGWRuntimeWatchWindow');R.window=w;w:SetDimensions(W,H);w:SetAnchor(CENTER,GuiRoot,CENTER,0,-15);w:SetHidden(true)
  local function resize()w:SetScale(math.min(GuiRoot:GetWidth()*.94/W,GuiRoot:GetHeight()*.88/H))end
  local bg=WINDOW_MANAGER:CreateControl(nil,w,CT_BACKDROP);bg:SetAnchorFill(w);bg:SetCenterColor(.025,.035,.05,1);bg:SetEdgeColor(.55,.36,.13,1);bg:SetEdgeTexture(nil,1,1,2)
  text(w,36,20,1308,50,38):SetText('RUNTIME WATCH')
  text(w,36,78,1308,32,24):SetText(R.author..' | '..R.version..' | Startup and short script captures')
  R.summary=text(w,36,120,1308,94,24);R.tabLabel=text(w,36,224,1308,36,28)
  R.labels={}
  for i=1,N do
   local b=WINDOW_MANAGER:CreateControl(nil,w,CT_BACKDROP);b:SetAnchor(TOPLEFT,w,TOPLEFT,30,272+(i-1)*62);b:SetDimensions(1320,60);b:SetEdgeTexture(nil,1,1,1)
   local title=text(b,12,2,850,31,26);title:SetMaxLineCount(1);title:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
   local metric=text(b,900,2,408,31,24)
   local sub=text(b,12,32,1296,28,22);sub:SetMaxLineCount(1);sub:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
   R.labels[i]={bg=b,title=title,metric=metric,sub=sub}
  end
  R.detail=text(w,36,724,1308,104,23);R.detail:SetMaxLineCount(4)
  R.footer=text(w,36,844,1308,65,22)
  R.tab=1;R.page=1;R.selected=1
  local function move(n)R.selected=math.max(1,math.min(R.count or 1,R.selected+n));R.Paint()end
  local function tab(n)R.tab=(R.tab-1+n)%#tabNames+1;R.selected=1;R.Paint()end
  R.keys={alignment=KEYBIND_STRIP_ALIGN_LEFT,
   TGWAAA_RuntimeWatchSocials.Keybind(),
   {name='Capture 5s',keybind='UI_SHORTCUT_PRIMARY',callback=function()R.Start(false);R.Paint()end},
   {name='Arm next login',keybind='UI_SHORTCUT_SECONDARY',callback=function()R.Arm();R.Paint()end},
   {name='Save baseline',keybind='UI_SHORTCUT_TERTIARY',callback=function()R.SaveBaseline();R.Paint()end},
   {name='Previous tab',keybind='UI_SHORTCUT_LEFT_SHOULDER',callback=function()tab(-1)end},
   {name='Next tab',keybind='UI_SHORTCUT_RIGHT_SHOULDER',callback=function()tab(1)end},
   {keybind='UI_SHORTCUT_LEFT_TRIGGER',ethereal=true,callback=function()move(-N)end},
   {keybind='UI_SHORTCUT_RIGHT_TRIGGER',ethereal=true,callback=function()move(N)end},
   {keybind='UI_SHORTCUT_INPUT_UP',ethereal=true,callback=function()move(-1)end},
   {keybind='UI_SHORTCUT_INPUT_DOWN',ethereal=true,callback=function()move(1)end},
   {name='Close',keybind='UI_SHORTCUT_NEGATIVE',callback=function()SCENE_MANAGER:Hide('runtimeWatch')end},
  }
  R.scene=ZO_Scene:New('runtimeWatch',SCENE_MANAGER);R.scene:AddFragment(ZO_SimpleSceneFragment:New(w))
  R.scene:AddFragmentGroup(IsInGamepadPreferredMode()and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW or FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
  local active=false
  R.scene:RegisterCallback('StateChange',function(_,state)
   if state==SCENE_SHOWING then resize();R.Paint();if not active then KEYBIND_STRIP:AddKeybindButtonGroup(R.keys);active=true end
   elseif state==SCENE_HIDING or state==SCENE_HIDDEN then if active then KEYBIND_STRIP:RemoveKeybindButtonGroup(R.keys);active=false end end
  end)
  w:RegisterForEvent(EVENT_SCREEN_RESIZED,resize);resize()
 end
 R.Paint();SCENE_MANAGER:Show('runtimeWatch')
end
