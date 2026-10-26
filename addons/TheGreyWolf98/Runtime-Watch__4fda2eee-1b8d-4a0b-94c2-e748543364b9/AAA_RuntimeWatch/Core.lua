RuntimeWatch={name='AAA_RuntimeWatch',version='0.1.0',author='@TheGreyWolf98',status='Waiting for initialization',errors={},loadGaps={},limits={records=250000,frameRecords=50000,functions=1000}}
local R=RuntimeWatch
local EM=EVENT_MANAGER
local function now()return GetGameTimeMilliseconds()end
local function clean(v)return tostring(v or ''):gsub('|',''):sub(1,600)end
R.Clean=clean
local function read(fn,...)
 if type(fn)~='function'then return nil end
 local ok,a,b,c,d,e=pcall(fn,...);if ok then return a,b,c,d,e end
end
R.Read=read
local function note(s)R.status=clean(s);if R.Paint then R.Paint()end end
local function append(t,v,max)t[#t+1]=v;if #t>max then table.remove(t,1)end end
function R.Owner(file)
 file=tostring(file or ''):gsub('\\','/')
 return file:match('[Aa]dd[Oo]ns[Mm]anaged/[^/]+/([^/]+)/')or file:match('[Aa]dd[Oo]ns/([^/]+)/')
end
function R.Capabilities()
 local list={'StartScriptProfiler','StopScriptProfiler','IsScriptProfilerEnabled','GetScriptProfilerNumFrames','GetScriptProfilerFrameNumRecords','GetScriptProfilerRecordInfo','GetScriptProfilerClosureInfo'}
 for _,key in ipairs(list)do if type(_G[key])~='function'then return false,key..' unavailable'end end
 return true
end
function R.Inventory()
 local out={}
 local count=read(GetNumAddOns)or 0
 for i=1,math.min(count,200)do
  local folder,title,author,_,enabled,state=read(GetAddOnInfo,i)
  if folder and enabled then out[#out+1]={name=clean(folder),title=clean(title),author=clean(author),state=state}end
 end
 table.sort(out,function(a,b)return a.name<b.name end)
 return out
end
local function info(kind,id,cache)
 local key=tostring(kind)..':'..tostring(id);local item=cache[key];if item then return item end
 local title,file,line
 if kind==SCRIPT_PROFILER_RECORD_DATA_TYPE_CLOSURE then title,file,line=read(GetScriptProfilerClosureInfo,id)
 elseif kind==SCRIPT_PROFILER_RECORD_DATA_TYPE_CFUNCTION then title=read(GetScriptProfilerCFunctionInfo,id);file='[native]'
 elseif kind==SCRIPT_PROFILER_RECORD_DATA_TYPE_GARBAGE_COLLECTION then title='Garbage collection';file='[GC]'
 else title='Profiler / other';file='[other]'end
 if kind==SCRIPT_PROFILER_RECORD_DATA_TYPE_CLOSURE and title==nil and file==nil then cache.failed=true end
 item={name=clean(title or 'Unnamed function'),file=clean(file or '[unknown]'),line=tonumber(line)or 0,owner=R.Owner(file)}
 cache[key]=item;return item
end
function R.NewAnalysis(report,frames)
 return {report=report,frames=frames,frame=1,index=1,phase='read',records={},children={},metadata={},addons={},functions={},functionCount=0,visited=0}
end
local function bucket(t,key,init)local row=t[key];if not row then row=init;t[key]=row end;return row end
local function ownerFor(a,index)
 local row=a.records[index];if row.ownerResolved then return row.owner end
 local owner=row.meta.owner;local parent=row.parent;local depth=0
 while not owner and parent and a.records[parent]and depth<128 do
  local p=a.records[parent];owner=p.meta.owner or p.owner;parent=p.parent;depth=depth+1
 end
 row.owner=owner or 'ESO / unattributed';row.ownerResolved=true;return row.owner
end
local function aggregate(a,index)
 local row=a.records[index];if not row or row.duration<0 then return end
 local exclusive=math.max(0,row.duration-(a.children[index]or 0))/1000000
 local owner=ownerFor(a,index)
 local addon=bucket(a.addons,owner,{name=owner,ms=0,calls=0,max=0})
 addon.ms=addon.ms+exclusive;addon.calls=addon.calls+1;addon.max=math.max(addon.max,exclusive)
 local m=row.meta;local key=owner..'\n'..m.file..':'..m.line..':'..m.name
 if not a.functions[key]and a.functionCount>=R.limits.functions then key='[other functions]'end
 local fn=a.functions[key]
 if not fn then
  a.functionCount=a.functionCount+1
  fn={owner=owner,name=m.name,file=m.file,line=m.line,ms=0,calls=0,max=0}
  if key=='[other functions]'then fn.owner='Multiple';fn.name='Other functions (detail limit)';fn.file='[limited]'end
  a.functions[key]=fn
 end
 fn.ms=fn.ms+exclusive;fn.calls=fn.calls+1;fn.max=math.max(fn.max,exclusive)
 a.report.cpuMs=a.report.cpuMs+exclusive
end
function R.AnalysisStep(a,maxOps,budget)
 local started=now();local ops=0
 while ops<maxOps and now()-started<budget do
  if a.frame>a.frames then return true end
  if a.phase=='read'then
   if a.index==1 then
    local n=read(GetScriptProfilerFrameNumRecords,a.frame)
    if type(n)~='number'then a.report.partial=true;a.report.note='Profiler frame read failed';return true end
    a.count=n
    if n>R.limits.frameRecords then a.report.partial=true;a.report.skippedFrames=a.report.skippedFrames+1;a.count=0 end
   end
   if a.count==0 or a.index>a.count then a.phase='sum';a.index=1
   elseif a.visited>=R.limits.records then
    a.report.partial=true;a.report.note='Record limit reached; incomplete frame excluded';return true
   else
    local id,s,e,parent,kind=read(GetScriptProfilerRecordInfo,a.frame,a.index)
    if id==nil and s==nil and e==nil then a.report.mode='limited';a.report.partial=true;a.report.note='Native profiler records are not readable on this client';return true end
    if type(s)=='number'and type(e)=='number'and e>=s and e>0 then
     local duration=e-s;local meta=info(kind,id,a.metadata)
     if a.metadata.failed then a.report.mode='limited';a.report.partial=true;a.report.note='Native source metadata is not readable on this client';return true end
     a.records[a.index]={duration=duration,parent=parent and parent>0 and parent or nil,meta=meta}
     if parent and parent>0 then a.children[parent]=(a.children[parent]or 0)+duration end
    else a.report.partial=true end
    a.index=a.index+1;a.visited=a.visited+1;ops=ops+1
   end
  else
   if a.index>a.count then a.frame=a.frame+1;a.index=1;a.phase='read';a.records={};a.children={}
   else aggregate(a,a.index);a.index=a.index+1;ops=ops+1 end
  end
 end
 return false
end
local function sorted(map,limit)
 local rows={};for _,v in pairs(map)do rows[#rows+1]=v end
 table.sort(rows,function(a,b)if a.ms~=b.ms then return a.ms>b.ms end;return a.name<b.name end)
 while #rows>limit do table.remove(rows)end;return rows
end
function R.FinishAnalysis()
 local a=R.analysis;if not a then return end
 EM:UnregisterForUpdate('RuntimeWatchAnalyze');R.analysis=nil
 a.report.addons=sorted(a.addons,128);a.report.functions=sorted(a.functions,80);a.report.records=a.visited
 R.db.last=a.report;note('Report ready. /runtime to view.');d('[Runtime Watch] Report ready. /runtime')
end
function R.BeginAnalysis(report)
 local frames=read(GetScriptProfilerNumFrames)
 if type(frames)~='number'then report.mode='limited';report.note='Profiler data could not be read';R.db.last=report;note('Limited report ready');return end
 R.analysis=R.NewAnalysis(report,frames)
 EM:RegisterForUpdate('RuntimeWatchAnalyze',10,function()
  if read(IsScriptProfilerEnabled)then
   R.analysis.report.partial=true;R.analysis.report.note='Another profiler started during analysis';R.FinishAnalysis();return
  end
  if R.AnalysisStep(R.analysis,300,2)then R.FinishAnalysis()end
 end)
 note('Analyzing captured frames in small batches...')
end
function R.Stop()
 local run=R.run;if not run then return end
 R.run=nil;EM:UnregisterForUpdate('RuntimeWatchCapture')
 run.elapsedMs=now()-run.started;run.stopped=read(GetTimeString)or '';run.cpuMs=0;run.skippedFrames=0;run.addons={};run.functions={};run.inventory=R.Inventory()
 run.errors={};for _,e in ipairs(R.errors)do if e.at>=run.started then run.errors[#run.errors+1]={message=e.message,kind=e.kind}end end
 run.loadGaps={};for _,g in ipairs(R.loadGaps)do run.loadGaps[#run.loadGaps+1]={name=g.name,ms=g.ms}end
 if run.mode=='cpu'then
  local ok,err=pcall(StopScriptProfiler)
  if not ok or read(IsScriptProfilerEnabled)~=false then run.mode='limited';run.note='Profiler stop not confirmed; reload UI before another capture: '..clean(err);R.db.last=run;note('Limited report ready');return end
  R.BeginAnalysis(run)
 else R.db.last=run;note('Limited report ready. CPU profiling unavailable.')end
end
function R.Start(startup)
 if R.run or R.analysis then note('A capture or analysis is already running.');return false end
 local supported,reason=R.Capabilities()
 if supported then
  local state=read(IsScriptProfilerEnabled)
  if state==true then note('Another script profiler is already active. Stop it before capturing.');return false
  elseif state~=false then supported=false;reason='Profiler state is not readable on this client'end
 end
 local mode='limited'
 if supported then
  local ok,err=pcall(StartScriptProfiler)
  if ok and read(IsScriptProfilerEnabled)==true then mode='cpu'else if ok then pcall(StopScriptProfiler)end;reason='Profiler could not start: '..clean(err or 'client did not enable it')end
 end
 local started=now()
 R.run={started=started,mode=mode,note=reason,character=read(GetUnitName,'player')or 'Unknown',world=read(GetWorldName)or '',time=read(GetTimeString)or '',kind=startup and 'Startup' or 'Manual 5 seconds',fpsSum=0,samples=0,fpsMin=999,maxGap=0,lastTick=started,lateTicks=0,peakPing=0,deadline=started+(startup and 12000 or 5000)}
 EM:RegisterForUpdate('RuntimeWatchCapture',100,function()
  local run=R.run;if not run then return end
  local t=now();local gap=t-run.lastTick;run.maxGap=math.max(run.maxGap,gap);if gap>250 then run.lateTicks=run.lateTicks+1 end;run.lastTick=t
  local fps=read(GetFramerate);if type(fps)=='number'and fps>0 then run.samples=run.samples+1;run.fpsSum=run.fpsSum+fps;run.fpsMin=math.min(run.fpsMin,fps)end
  run.peakPing=math.max(run.peakPing,tonumber(read(GetLatency))or 0)
  local frames=run.mode=='cpu'and read(GetScriptProfilerNumFrames)or 0
  if t>=run.deadline or (type(frames)=='number'and frames>=600)then R.Stop()end
 end)
 note(mode=='cpu'and 'Capturing native script CPU...'or 'Limited capture: '..clean(reason))
 return true
end
function R.SaveBaseline()
 if not R.db.last then note('Capture a report first.');return end
 R.db.baseline=R.db.last;note('Baseline saved. Next capture will leave it intact.')
end
function R.Arm()
 R.db.armed=not R.db.armed;note(R.db.armed and 'Next login / reload armed. Capture begins when Runtime Watch initializes.'or 'Next-login capture disabled.')
end
local lastLoad=now()
EM:RegisterForEvent('RuntimeWatchLoadGaps',EVENT_ADD_ON_LOADED,function(_,addon)
 local t=now();append(R.loadGaps,{name=clean(addon),ms=math.max(0,t-lastLoad)},200);lastLoad=t
end)
EM:RegisterForEvent('RuntimeWatchErrors',EVENT_LUA_ERROR,function(_,message)
 append(R.errors,{at=now(),kind='Lua error',message=clean(message)},20)
end)
if EVENT_SCRIPT_ACCESS_VIOLATION then EM:RegisterForEvent('RuntimeWatchAccess',EVENT_SCRIPT_ACCESS_VIOLATION,function(_,fn)
 append(R.errors,{at=now(),kind='Restricted API',message=clean(fn)},20)
end)end
EM:RegisterForEvent('RuntimeWatchPlayer',EVENT_PLAYER_ACTIVATED,function()
 EM:UnregisterForEvent('RuntimeWatchLoadGaps',EVENT_ADD_ON_LOADED)
 if R.run then R.run.character=read(GetUnitName,'player')or 'Unknown';if R.run.kind=='Startup'then R.run.deadline=math.min(R.run.deadline,now()+3000)end end
end)
EM:RegisterForEvent('RuntimeWatchLeave',EVENT_PLAYER_DEACTIVATED,function()if R.run then R.Stop()end end)
EM:RegisterForEvent('RuntimeWatchInit',EVENT_ADD_ON_LOADED,function(_,addon)
 if addon~=R.name then return end
 EM:UnregisterForEvent('RuntimeWatchInit',EVENT_ADD_ON_LOADED)
 R.db=ZO_SavedVars:NewAccountWide('TGWRuntimeWatchSaved',1,nil,{armed=true},GetWorldName())
 SLASH_COMMANDS['/runtime']=function(arg)
  arg=zo_strtrim(arg or ''):lower()
  if arg=='start'then R.Start(false)elseif arg=='stop'then R.Stop()elseif arg=='arm'then R.Arm()elseif arg=='baseline'then R.SaveBaseline()else R.Open()end
 end
 SLASH_COMMANDS['/diag']=SLASH_COMMANDS['/runtime']
 local armed=R.db.armed;R.db.armed=false
 if armed then R.Start(true)else note('Ready. /runtime opens diagnostics.')end
end)
