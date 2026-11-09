local ADDON = 'WritFolioInspector'
-- Native ESO Controls > Keybindings label (registered when the addon loads).
ZO_CreateStringId('SI_BINDING_NAME_WRITFOLIOINSPECTOR_TOGGLE', 'Toggle Writ Folio Inspector')
local W = {groups = WritFolioInspectorData or {}, index = {}, idIndex = {}, planNameIndex = {}, ready = false, scanning = false, selected = 1, groupOffset = 0, recipeOffset = 0, filter = 'all', tier = 'all', search = '', docSearch = '', catalog = {}, catalogMode = false, pageSize = 12}
_G.WritFolioInspector = W

local C = {bg={.035,.047,.069,.98},panel={.065,.085,.116,.96},edge={.27,.37,.49,1},gold={.94,.77,.43,1},text={.9,.94,.98,1},muted={.58,.67,.76,1},accent={.19,.45,.61,1},}
local function say(s) if CHAT_SYSTEM then CHAT_SYSTEM:AddMessage('|c91D5FF[Writ Folio]|r '..tostring(s)) end end
local function clean(s)
  s=tostring(s or ''):lower()
  s=s:gsub('’',"'"):gsub('‘',"'"):gsub('“','"'):gsub('”','"')
  return s:gsub('heartlh','hearth'):gsub('[%s%p]+',' '):gsub('^%s+',''):gsub('%s+$','')
end
local function valid(s) return type(s)=='string' and s:find('|H',1,true)~=nil end
local function apiReady()
  local lib=_G.LibFurnitureCatalogue; local api=lib and lib.API
  if not api or type(api.IsReady)~='function' then return nil end
  local ok,v=pcall(api.IsReady); return ok and v and api or nil
end
local function linkFor(api,id)
  if not api or not id then return nil end
  local ok,v=pcall(api.GetItemLink,id); return ok and valid(v) and v or nil
end
local function stripPrefix(s) return tostring(s or ''):gsub('^%s*[%a]+:%s*','') end
local function resolve(item)
  if type(item)=='table' then
    if item.id and W.idIndex[item.id] then return W.idIndex[item.id] end
    return W.planNameIndex[clean(item.name)] or W.index[clean(stripPrefix(item.name))]
  end
  return W.planNameIndex[clean(item)] or W.index[clean(stripPrefix(item))]
end
-- Knowledge results are cached until an explicit invalidation (new scan, recipe learned,
-- or panel reopened). Scrolling never asks the game for the same recipe twice.
local knowledgeCache = {}
local knowledgeEpoch = 0
local function invalidateKnowledge()
  knowledgeCache = {}
  knowledgeEpoch = knowledgeEpoch + 1
  W.tallyCache = {}
  W.rowsCache = {}
end
local function knowledge(record)
  if record and knowledgeCache[record] then return knowledgeCache[record] end
  if not record or not valid(record.link) then return 'unresolved' end
  local ok,known=pcall(IsItemLinkRecipeKnown,record.link)
  if not ok then return 'unresolved' end
  local state=known and 'known' or 'missing'
  knowledgeCache[record]=state
  return state
end
local function tally(group)
  W.tallyCache=W.tallyCache or {}
  local cached=W.tallyCache[group]
  if cached then return cached[1],cached[2],cached[3] end
  local yes,no,unk=0,0,0
  for _,item in ipairs(group.recipes or group.plans or {}) do
    local status=knowledge(resolve(item))
    if status=='known' then yes=yes+1 elseif status=='missing' then no=no+1 else unk=unk+1 end
  end
  W.tallyCache[group]={yes,no,unk}
  return yes,no,unk
end
local function totalRecords()
  local n=0; for _,g in ipairs(W.groups) do n=n+#(g.recipes or g.plans or {}) end; return n
end
function W.Scan(force)
  -- OnReady and SCAN_COMPLETE can arrive together: never run overlapping scans.
  if W.scanning then return end
  local api=apiReady()
  if not api or type(api.GetItemIds)~='function' or type(api.GetEntry)~='function' then
    W.ready=false; W.scanError=nil
    if W.Render then W.Render() end
    return
  end
  local ok,ids=pcall(api.GetItemIds)
  if not ok or type(ids)~='table' then
    W.ready=false; W.scanError='Catalogue item list unavailable'
    if W.Render then W.Render() end
    return
  end
  local rev=nil
  if type(api.GetDBRevision)=='function' then
    local okRev,value=pcall(api.GetDBRevision)
    if okRev then rev=value end
  end
  -- Reuse a completed catalogue without temporarily showing it as unavailable.
  if not force and W.ready and W.readyRevision~=nil and rev~=nil and W.readyRevision==rev then return end
  W.generation=(W.generation or 0)+1
  local generation,nextIndex,index,idIndex,planNameIndex,catalog=W.generation,1,{},{},{},{}
  W.scanning=true; W.ready=false; W.scanError=nil
  if W.Render then W.Render() end
  local function batch()
    if generation~=W.generation then return end
    local changed=false
    if rev~=nil and type(api.GetDBRevision)=='function' then
      local okRev,value=pcall(api.GetDBRevision)
      changed=(not okRev or value~=rev)
    end
    if not apiReady() or changed then
      W.scanning=false; W.ready=false; W.readyRevision=nil
      if W.Render then W.Render() end
      -- A revision change during a batch invalidates its partial results.
      -- Restart only when the catalogue reports that it is ready again.
      if changed and apiReady() then zo_callLater(function() W.Scan(true) end,100) end
      return
    end
    local last=math.min(#ids,nextIndex+199)
    for i=nextIndex,last do
      local id=tonumber(ids[i])
      if id then
        local good,entry=pcall(api.GetEntry,id)
        local blueprint=good and type(entry)=='table' and tonumber(entry.blueprint)
        if blueprint and blueprint>0 then
          local plan,result=linkFor(api,blueprint),linkFor(api,id)
          if plan and result then
            local goodName,name=pcall(GetItemLinkName,result)
            if goodName and name and name~='' then
              local row={link=plan,result=result,title=name,blueprintId=blueprint,furnishingId=id}
              index[clean(name)]=row; idIndex[blueprint]=row
              local okName,planName=pcall(GetItemLinkName,plan)
              if okName and planName and planName~='' then planNameIndex[clean(planName)]=row end
              catalog[#catalog+1]=row
            end
          end
        end
      end
    end
    nextIndex=last+1
    if nextIndex<=#ids then
      zo_callLater(batch,1)
    else
      table.sort(catalog,function(a,b) return clean(a.title)<clean(b.title) end)
      W.index,W.idIndex,W.planNameIndex,W.catalog=index,idIndex,planNameIndex,catalog
      W.ready=true; W.scanning=false; W.readyRevision=rev
      invalidateKnowledge()
      -- Resolve source IDs from the catalogue for data entries without a fixed ID.
      if W.RebuildWritSources then W.RebuildWritSources() end
      if W.Render then W.Render() end
    end
  end
  zo_callLater(batch,1)
end

local function backdrop(parent,x,y,w,h,center,edge)
  local b=WINDOW_MANAGER:CreateControl(nil,parent,CT_BACKDROP)
  b:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); b:SetDimensions(w,h)
  b:SetCenterColor(unpack(center)); b:SetEdgeColor(unpack(edge or C.edge)); b:SetEdgeTexture('',1,1,1)
  return b
end
local function label(parent,x,y,w,h,font,color)
  local o=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
  o:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); o:SetDimensions(w,h)
  o:SetFont(font or 'ZoFontGame'); o:SetColor(unpack(color or C.text))
  o:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  return o
end
local function button(parent,title,x,y,w,h,fn)
  local b=WINDOW_MANAGER:CreateControl(nil,parent,CT_BUTTON)
  b:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); b:SetDimensions(w,h)
  b:SetFont('ZoFontGame'); b:SetText(title)
  b:SetNormalFontColor(unpack(C.text)); b:SetMouseOverFontColor(unpack(C.gold))
  b:SetHandler('OnClicked',fn)
  return b
end
local function setTab(btn,active)
  if active then btn:SetNormalFontColor(unpack(C.gold)) else btn:SetNormalFontColor(unpack(C.text)) end
end
local function edit(parent,x,y,w,h,hint,change)
  local frame=backdrop(parent,x,y,w,h,C.panel)
  frame:SetMouseEnabled(false)
  local box=WINDOW_MANAGER:CreateControl(nil,parent,CT_EDITBOX)
  box:SetAnchor(TOPLEFT,parent,TOPLEFT,x+9,y+3); box:SetDimensions(w-18,h-6)
  box:SetFont('ZoFontGame'); box:SetColor(unpack(C.text)); box:SetMaxInputChars(90)
  box:SetMouseEnabled(true); box:SetEditEnabled(true)
  box:SetText('')
  local hintLabel=label(parent,x+11,y,w-20,h,'ZoFontGame',C.muted)
  hintLabel:SetText(hint); hintLabel:SetMouseEnabled(false)
  local function syncHint() hintLabel:SetHidden(box:HasFocus() or box:GetText()~='') end
  box:SetHandler('OnMouseDown',function(self) self:TakeFocus() end)
  box:SetHandler('OnFocusGained',syncHint)
  box:SetHandler('OnFocusLost',syncHint)
  box:SetHandler('OnTextChanged',function(self)
    syncHint()
    change(clean(self:GetText()))
  end)
  return box
end

local function truncate(s,n)
  s=tostring(s or ''); if #s>n then return s:sub(1,n-3)..'...' end; return s
end
local function matchingGroups()
  local result={}
  for i,g in ipairs(W.groups) do
    local name=clean(g.name)
    if (W.tier=='all' or (W.tier=='journeymanMixed' and (g.tier=='Journeyman' or g.tier=='Mixed')) or (W.tier=='master' and g.tier=='Master'))
       and (W.docSearch=='' or name:find(W.docSearch,1,true) or clean(g.region):find(W.docSearch,1,true)) then
      result[#result+1]=i
    end
  end
  return result
end
local function rowsForGroup(group)
  W.rowsCache=W.rowsCache or {}
  local key='doc|'..tostring(group)..'|'..W.search..'|'..W.filter
  if W.rowsCache[key] then return W.rowsCache[key] end
  local rows={}
  if not group then return rows end
  for _,item in ipairs(group.recipes or group.plans or {}) do
    local name=type(item)=='table' and item.name or item
    local record=resolve(item)
    local state=knowledge(record)
    if (W.search=='' or clean(name):find(W.search,1,true))
       and (W.filter=='all' or state==W.filter) then
      rows[#rows+1]={name=name,record=record,item=item,state=state}
    end
  end
  W.rowsCache[key]=rows
  return rows
end
local function catalogRows()
  W.rowsCache=W.rowsCache or {}
  local key='cat|'..W.search..'|'..W.filter
  if W.rowsCache[key] then return W.rowsCache[key] end
  local rows={}
  for _,record in ipairs(W.catalog) do
    if (W.search=='' or clean(record.title):find(W.search,1,true)) then
      local state=knowledge(record)
      if W.filter=='all' or W.filter==state then
        rows[#rows+1]={name=record.title,record=record,state=state}
      end
    end
  end
  W.rowsCache[key]=rows
  return rows
end
local function pageText(offset,total,n)
  if total==0 then return '0 / 0' end
  return string.format('%d-%d / %d',offset+1,math.min(offset+n,total),total)
end
local function makeWindow()
  local win=WINDOW_MANAGER:CreateTopLevelWindow('WritFolioInspectorWindow')
  win:SetDimensions(1020,692); win:SetAnchor(CENTER,GuiRoot,CENTER)
  win:SetClampedToScreen(true);win:SetMovable(true);win:SetMouseEnabled(true);win:SetHidden(true)
  -- Dragging is handled by a dedicated header surface, not the whole window,
  -- so dragging does not interfere with searching, clicking plans or scrolling.
  local bg=WINDOW_MANAGER:CreateControl(nil,win,CT_BACKDROP)
  bg:SetAnchorFill(win); bg:SetCenterColor(unpack(C.bg));bg:SetEdgeColor(unpack(C.edge));bg:SetEdgeTexture('',1,1,1)
  local headerBg=backdrop(win,0,0,1020,68,{.075,.105,.145,1},C.edge)
  local headingLabel=label(win,25,12,650,34,'ZoFontWinH2',C.gold)
  headingLabel:SetText('WRIT FOLIO  |  INSPECTOR')
  W.summary=label(win,27,42,700,19,'ZoFontGame',C.muted)
  local closeButton=button(win,'X',973,15,28,28,function() win:SetHidden(true) end)
  local minimizeButton=button(win,'−',936,15,32,28,function() W.SetMinimized(not W.minimized) end)
  -- The draggable title surface is created later; keep action buttons above it.
  closeButton:SetDrawLayer(DL_OVERLAY)
  closeButton:SetDrawLevel(20)
  minimizeButton:SetDrawLayer(DL_OVERLAY)
  minimizeButton:SetDrawLevel(20)
  closeButton:SetMouseEnabled(true)
  minimizeButton:SetMouseEnabled(true)
  W.docTab=button(win,'DOCUMENTS',24,77,135,33,function() W.catalogMode=false;W.recipeOffset=0;W.Render() end)
  W.catTab=button(win,'CATALOGUE',166,77,139,33,function() W.catalogMode=true;W.recipeOffset=0;W.Render() end)
  W.refresh=button(win,'Refresh catalogue',834,78,161,32,function() W.Scan(true) end)
  backdrop(win,17,116,326,520,C.panel)
  backdrop(win,353,116,649,520,C.panel)
  label(win,31,126,295,28,'ZoFontGameBold',C.gold):SetText('DOCUMENT COLLECTION')
  W.docSearchBox=edit(win,29,162,302,31,'Search documents / region',function(s) W.docSearch=s;W.groupOffset=0;W.Render() end)
  -- Seller filter removed; Journeyman and Mixed share a single tier filter.
  W.tierTabs={}
  local tiers={{'All','all',43},{'|c69B8FF●|r Journeyman + Mixed','journeymanMixed',181},{'|cC58BFF●|r Master','master',74}}
  local tx=30
  for i,t in ipairs(tiers) do
    W.tierTabs[i]=button(win,t[1],tx,203,t[3],31,function() W.tier=t[2];W.groupOffset=0;W.Render() end)
    tx=tx+t[3]+1
  end
  W.docCount=label(win,30,240,300,21,'ZoFontGame',C.muted)
  W.groupRows={};W.recipeRows={}
  for i=1,12 do
    local dy=270+(i-1)*29
    local d=button(win,'',32,dy+1,294,23,function(self)
      if self.groupIndex then W.selected=self.groupIndex;W.catalogMode=false;W.recipeOffset=0;W.Render() end
    end)
    W.groupRows[i]=d
    local ry=250+(i-1)*29
    local r=button(win,'',370,ry,615,29,function(self)
      local record=self.record
      local link=record and record.link
      if not link and self.planId then link=linkFor(apiReady(),self.planId) end
      if link then
        say(link)
      else say('Plan link unavailable; wait for catalogue scan.') end
    end)
    W.recipeRows[i]=r
  end
  W.heading=label(win,373,127,603,34,'ZoFontWinH3',C.gold)
  W.meta=label(win,374,159,608,28,'ZoFontGame',C.muted)
  W.searchBox=edit(win,370,196,314,33,'Search plans',function(s) W.search=s;W.recipeOffset=0;W.Render()end)
  W.filters={}
  local filters={{'All','all'},{'Missing','missing'},{'Known','known'}}
  local fw={65,83,72};local pos=700
  for i,f in ipairs(filters) do
    W.filters[i]=button(win,f[1],pos,197,fw[i],31,function() W.filter=f[2];W.recipeOffset=0;W.Render() end)
    pos=pos+fw[i]+2
  end
  W.listHeader=label(win,372,228,600,19,'ZoFontGame',C.muted)
  -- Document knowledge summary; identical tally used in the collection list.
  W.recipePosition=label(win,685,604,301,24,'ZoFontGame',C.muted)
  W.recipePosition:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  W.footer=label(win,24,648,715,30,'ZoFontGame',C.muted)
  W.footer:SetText('Click a recipe to link in chat  •  /wf to open or close')
  -- Permanent creator credit, independent of catalogue loading state.
  W.credit=label(win,775,648,201,30,'ZoFontGameBold',C.gold)
  W.credit:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  W.credit:SetText('Created byNayim')
  local function scrollDocuments(_,delta)
    W.groupOffset=math.max(0,W.groupOffset-delta*3)
    W.Render(true)
  end
  local function scrollRecipes(_,delta)
    W.recipeOffset=math.max(0,W.recipeOffset-delta*3)
    W.Render(true)
  end
  -- Child controls receive wheel events before the top-level window.
  -- Bind scrolling to each list row and to the empty list areas as well.
  for _,row in ipairs(W.groupRows) do row:SetHandler('OnMouseWheel',scrollDocuments) end
  for _,row in ipairs(W.recipeRows) do row:SetHandler('OnMouseWheel',scrollRecipes) end
  W.docCount:SetMouseEnabled(true); W.docCount:SetHandler('OnMouseWheel',scrollDocuments)
  W.listHeader:SetMouseEnabled(true); W.listHeader:SetHandler('OnMouseWheel',scrollRecipes)
  W.docScrollSurface=WINDOW_MANAGER:CreateControl(nil,win,CT_CONTROL)
  W.docScrollSurface:SetAnchor(TOPLEFT,win,TOPLEFT,28,265)
  W.docScrollSurface:SetDimensions(302,357)
  W.docScrollSurface:SetMouseEnabled(true)
  W.docScrollSurface:SetHandler('OnMouseWheel',scrollDocuments)
  W.docScrollSurface:SetDrawLayer(DL_BACKGROUND)
  W.recipeScrollSurface=WINDOW_MANAGER:CreateControl(nil,win,CT_CONTROL)
  W.recipeScrollSurface:SetAnchor(TOPLEFT,win,TOPLEFT,365,245)
  W.recipeScrollSurface:SetDimensions(625,354)
  W.recipeScrollSurface:SetMouseEnabled(true)
  W.recipeScrollSurface:SetHandler('OnMouseWheel',scrollRecipes)
  W.recipeScrollSurface:SetDrawLayer(DL_BACKGROUND)
  win:SetHandler('OnMouseWheel',scrollRecipes)
  win:SetHandler('OnEffectivelyShown',function() W.Render() end)
  W.window=win

  -- A single independent compact launcher. The entire visible icon is the
  -- hit target; left-drag moves it, a stationary left-click opens the panel.
  local launcher=WINDOW_MANAGER:CreateTopLevelWindow('WritFolioInspectorLauncher')
  launcher:SetDimensions(64,64)
  launcher:SetAnchor(CENTER,GuiRoot,CENTER)
  launcher:SetClampedToScreen(true)
  launcher:SetMovable(true)
  launcher:SetMouseEnabled(true)
  launcher:SetHidden(true)
  local emblem=WINDOW_MANAGER:CreateControl(nil,launcher,CT_TEXTURE)
  emblem:SetAnchorFill(launcher)
  emblem:SetTexture('WritFolioInspector/Textures/WF_Emblem.dds')
  emblem:SetMouseEnabled(false)
  -- Use one mouse surface only. A child CT_BUTTON consumed the mouse events
  -- in v0.8.15 and prevented the parent launcher from being dragged.
  -- Explicit mouse tracking is more reliable on compact top-level controls
  -- than StartMoving(), which can be interrupted by ESO mouse capture.
  local dragging=false
  local dragStartX,dragStartY,iconStartLeft,iconStartTop=0,0,0,0
  local moved=false
  launcher:SetHandler('OnMouseDown',function(self,key)
    if key~=MOUSE_BUTTON_INDEX_LEFT then return end
    dragStartX,dragStartY=GetUIMousePosition()
    iconStartLeft,iconStartTop=self:GetLeft(),self:GetTop()
    dragging=true
    moved=false
  end)
  launcher:SetHandler('OnUpdate',function(self)
    if not dragging then return end
    local x,y=GetUIMousePosition()
    local dx,dy=x-dragStartX,y-dragStartY
    if math.abs(dx)+math.abs(dy)>5 then moved=true end
    if moved then
      self:ClearAnchors()
      self:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,iconStartLeft+dx,iconStartTop+dy)
    end
  end)
  launcher:SetHandler('OnMouseUp',function(self,key)
    if key~=MOUSE_BUTTON_INDEX_LEFT or not dragging then return end
    local x,y=GetUIMousePosition()
    local dx,dy=x-dragStartX,y-dragStartY
    local shouldRestore=not moved and math.abs(dx)+math.abs(dy)<6
    dragging=false
    if shouldRestore then W.SetMinimized(false) end
  end)
  launcher:SetHandler('OnMouseEnter',function(self)
    InitializeTooltip(InformationTooltip,self,BOTTOMRIGHT,0,0)
    SetTooltipText(InformationTooltip,'Writ Folio Inspector\nLeft-click: Open  |  Drag: Move')
  end)
  launcher:SetHandler('OnMouseExit',function(self)
    ClearTooltip(InformationTooltip)
  end)
  W.launcher=launcher
  W.minimized=false
  function W.SetMinimized(compact)
    if W.minimized==compact then return end
    W.minimized=compact
    if compact then
      local left,top=win:GetLeft(),win:GetTop()
      if left and top then
        launcher:ClearAnchors()
        launcher:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,left+8,top+8)
      end
      win:SetHidden(true)
      launcher:SetHidden(false)
    else
      launcher:SetHidden(true)
      win:SetHidden(false)
      W.Render()
    end
  end

  -- The drag hit area overlays only the free part of the title bar. It does not
  -- cover the minimize and close buttons at its right edge.
  local dragHeader=WINDOW_MANAGER:CreateControl(nil,win,CT_CONTROL)
  dragHeader:SetAnchor(TOPLEFT,win,TOPLEFT,0,0)
  dragHeader:SetDimensions(905,68)
  dragHeader:SetDrawLayer(DL_BACKGROUND)
  dragHeader:SetMouseEnabled(true)
  dragHeader:SetHandler('OnMouseDown',function(self,key)
    if key==MOUSE_BUTTON_INDEX_LEFT then win:StartMoving() end
  end)
  dragHeader:SetHandler('OnMouseUp',function(self,key)
    if key==MOUSE_BUTTON_INDEX_LEFT then win:StopMovingOrResizing() end
  end)
end
-- Fast path: wheel events update only the 12 visible buttons; no full filtering.
local function renderVisibleRows()
  local groups=W.visibleGroups or {}
  local rows=W.visibleRows or {}
  W.groupOffset=math.min(math.max(0,W.groupOffset),math.max(0,#groups-12))
  W.recipeOffset=math.min(math.max(0,W.recipeOffset),math.max(0,#rows-12))
  for i,btn in ipairs(W.groupRows) do
    local idx=groups[W.groupOffset+i]; btn.groupIndex=idx; btn:SetHidden(not idx)
    if idx then
      local g=W.groups[idx]
      local known=tally(g)
      local short=tostring(g.name):gsub(" Furnisher's Document",'')
      btn:SetText((idx==W.selected and '|cFFDEA0> ' or '  ')..truncate(short,28)..'  |cDDE9F5'..known..'/'..#(g.recipes or g.plans or {})..'|r'..(g.vouchers and ('  |cD9BB72'..g.vouchers..'v|r') or ''))
    end
  end
  for i,btn in ipairs(W.recipeRows) do
    local item=rows[W.recipeOffset+i];btn:SetHidden(not item)
    btn.record=item and item.record
    btn.planId=item and type(item.item)=='table' and item.item.id or nil
    if item then
      local tag=item.state=='known' and '|c72E0A3KNOWN|r' or item.state=='missing' and '|cFF938EMISSING|r' or '|c91A6BDUNKNOWN|r'
      btn:SetText((tag~='' and tag..'  ' or '')..truncate(item.name,74))
    end
  end
end
function W.Render(onlyVisible)
  if not W.window or W.minimized then return end
  if onlyVisible then renderVisibleRows(); return end
  local state=W.scanning and 'Scanning...' or (W.scanError or (W.ready and 'Catalogue ready' or 'Waiting for LibFurnitureCatalogue'))
  W.summary:SetText(string.format('%d documents  |  %d plans  |  %s',#W.groups,totalRecords(),state))
  setTab(W.docTab,not W.catalogMode);setTab(W.catTab,W.catalogMode)
  for i,b in ipairs(W.tierTabs) do setTab(b,({'all','journeymanMixed','master'})[i]==W.tier) end
  for i,b in ipairs(W.filters) do setTab(b,({'all','missing','known'})[i]==W.filter) end
  local groups=matchingGroups()
  W.visibleGroups=groups
  local rows={}
  if W.catalogMode then
    W.heading:SetText('FURNITURE CATALOGUE')
    rows=catalogRows()
    W.meta:SetText(string.format('%d indexed plans  |  Across all documents',#W.catalog))
  else
    local g=W.groups[W.selected]
    if g then
      W.heading:SetText(truncate(g.name:gsub(" Furnisher's Document",''),54))
      local known,missing,unresolved=tally(g)
      local region=tostring(g.region or '?')
      W.meta:SetText(string.format('%s  |  %s  |  Known %d  Missing %d  |  %s',region,tostring(g.tier or '?'),known,missing,g.vouchers and (g.vouchers..' Writ Vouchers') or 'Voucher price not set'))
      rows=rowsForGroup(g)
    else W.heading:SetText('No document selected');W.meta:SetText('') end
  end
  W.listHeader:SetText(string.format('%d matching plans  |  %s',#rows,(not W.catalogMode and W.groups[W.selected] and W.groups[W.selected].partialPool) and 'Listed pool may be partial' or 'Click a plan to link it'))
  W.recipeOffset=math.min(math.max(0,W.recipeOffset),math.max(0,#rows-12))
   if W.catalogMode then
     W.recipePosition:SetText('')
   else
     local selectedGroup=W.groups[W.selected]
     if selectedGroup then
       local known,missing,unresolved=tally(selectedGroup)
       local total=#(selectedGroup.recipes or selectedGroup.plans or {})
       W.recipePosition:SetText(string.format('Known %d/%d  Missing %d  Unknown %d',known,total,missing,unresolved))
     else
       W.recipePosition:SetText('')
     end
   end
  W.visibleRows=rows
  renderVisibleRows()
end
-- Public keybinding entry point. Uses the same toggle path as /wf.
function WritFolioInspector_ToggleKeybind()
  if _G.WritFolioInspector and _G.WritFolioInspector.Toggle then
    _G.WritFolioInspector.Toggle()
  end
end

function W.Toggle()
  if not W.window then return end
  if W.minimized then
    W.SetMinimized(false)
  else
    W.window:SetHidden(not W.window:IsHidden())
    if not W.window:IsHidden() then invalidateKnowledge(); W.Render() end
  end
end

-- Writ Voucher source hints for furnishing PLAN tooltips.
-- The indicator is probabilistic: a listed random Document is not a guaranteed drop.
local WRIT_PREFIXES={Blueprint=true,Design=true,Diagram=true,Formula=true,Pattern=true,Praxis=true,Sketch=true}
local function writKey(s) return clean(s) end
local function buildWritSourceIndex()
  W.writPlanIds,W.writPlanNames={},{}
  for _,g in ipairs(W.groups) do
    for _,item in ipairs(g.recipes or g.plans or {}) do
      local name=type(item)=='table' and item.name or item
      local id=type(item)=='table' and tonumber(item.id) or nil
      -- Some document pools list recipe names but have no verified recipe ID.
      -- Once the library is ready, use its matching plan name to recover an ID.
      if not id then
        local record=W.planNameIndex[writKey(name)]
        id=record and record.blueprintId or nil
      end
      local entry={name=g.name, tier=g.tier, vouchers=g.vouchers}
      if id then
        W.writPlanIds[id]=W.writPlanIds[id] or {}
        table.insert(W.writPlanIds[id],entry)
      else
        local key=writKey(name)
        W.writPlanNames[key]=W.writPlanNames[key] or {}
        table.insert(W.writPlanNames[key],entry)
      end
    end
  end
end
W.RebuildWritSources=buildWritSourceIndex
-- Item names are localized in ESO and community translations.  Detect recipes by
-- the game's language-independent item type, not English "Blueprint:" prefixes.
-- Restrict to furnishing plans if the recipe-result API is available.
local function isFurnishingPlanLink(link, name)
  if type(GetItemLinkItemType)=='function' and ITEMTYPE_RECIPE then
    local ok,kind=pcall(GetItemLinkItemType,link)
    if ok then
      if kind~=ITEMTYPE_RECIPE then return false end
      if type(GetItemLinkRecipeResultItemLink)=='function' and ITEMTYPE_FURNISHING then
        local good,result=pcall(GetItemLinkRecipeResultItemLink,link)
        if good and valid(result) then
          local goodType,resultType=pcall(GetItemLinkItemType,result)
          if goodType then return resultType==ITEMTYPE_FURNISHING end
        end
      end
      return true -- Recipe type is reliable even when the result API is unavailable.
    end
  end
  -- Older UI compatibility when the item type API is unavailable.
  return type(name)=='string' and WRIT_PREFIXES[name:match('^%s*(%a+)%s*:')]==true
end
local function writSourcesForLink(link)
  if not valid(link) then return nil end
  local okName,name=pcall(GetItemLinkName,link)
  if not okName or not isFurnishingPlanLink(link,name) then return nil end
  local id
  if type(GetItemLinkItemId)=='function' then
    local ok,num=pcall(GetItemLinkItemId,link)
    if ok then id=tonumber(num) end
  end
  local sources=id and W.writPlanIds[id] or nil
  if not sources then sources=W.writPlanNames[writKey(name)] end
  return sources or {}, name
end
local function decorateWritTooltip(tooltip,link)
  if not tooltip or not tooltip.AddLine then return end
  local sources,name=writSourcesForLink(link)
  if not name then return end
  -- Multiple tooltip methods can run for one Guild Trader hover.
  -- Append the source block only once until the tooltip clears or changes item.
  if tooltip._wfiSourceLink == link then return end
  tooltip._wfiSourceLink = link
  tooltip:AddLine(' ')
  if #sources>0 then
    tooltip:AddLine('|c70B9FFPossible Furnisher\'s Document sources (random drops):|r')
    local seen={}
    for _,source in ipairs(sources) do
      local doc=tostring(source.name or ''):gsub(" Furnisher's Document$",'')
      if doc~='' and not seen[doc] then
        seen[doc]=true
        tooltip:AddLine('|cA9BDD1'..doc..'|r'..(source.vouchers and ('  |cD9BB72('..source.vouchers..' vouchers)|r') or ''))
      end
    end
  else
    tooltip:AddLine('|cFFB48FNo source listed in this addon (pools may be incomplete).|r')
  end
end
local function hookWritTooltip(tooltip,method,resolver)
  if not tooltip or type(tooltip[method])~='function' or type(ZO_PostHook)~='function' then return end
  ZO_PostHook(tooltip,method,function(self,...)
    local ok,link=pcall(resolver,...)
    if ok and link then decorateWritTooltip(self,link) end
  end)
end
local hookedWritMethods=setmetatable({}, {__mode='k'})
local function registerWritTooltips()
  buildWritSourceIndex()
  local names={'ItemTooltip','PopupTooltip','InformationTooltip','ComparativeTooltip1','ComparativeTooltip2'}
  for _,name in ipairs(names) do
    local tooltip=_G[name]
    if tooltip then
      local hooked=hookedWritMethods[tooltip] or {}
      hookedWritMethods[tooltip]=hooked
      local function once(method,resolver)
        if type(tooltip[method])=='function' and hooked[method]~=tooltip[method] then
          if method=='ClearLines' then
            ZO_PostHook(tooltip,method,function(self) self._wfiSourceLink=nil end)
          else
            hookWritTooltip(tooltip,method,resolver)
          end
          hooked[method]=tooltip[method]
        end
      end
      -- A fresh tooltip cycle clears the marker, so repeated hovers still work.
      once('ClearLines',function() return nil end)
      once('SetLink',function(link) return link end)
      once('SetBagItem',function(bag,slot)
        if type(GetItemLink)=='function' then return GetItemLink(bag,slot) end
      end)
      -- ESO keyboard Guild Trader browse/search-result rows use SetTradingHouseItem.
      -- SetTradingHouseSearchResultItem is not the vanilla method name.
      once('SetTradingHouseItem',function(index)
        if type(GetTradingHouseSearchResultItemLink)=='function' then
          return GetTradingHouseSearchResultItemLink(index)
        end
      end)
      -- Compatibility with alternative tooltip implementations.
      once('SetTradingHouseSearchResultItem',function(index)
        if type(GetTradingHouseSearchResultItemLink)=='function' then
          return GetTradingHouseSearchResultItemLink(index)
        end
      end)
      once('SetTradingHouseListing',function(index)
        if type(GetTradingHouseListingItemLink)=='function' then
          return GetTradingHouseListingItemLink(index)
        end
      end)
    end
  end
end

local function initialize()
  makeWindow()
  registerWritTooltips()
  -- AwesomeGuildStore can replace the trading-house tooltip handler after addon load.
  -- Reattach once its UI has finished initializing, without stacking our own hooks.
  local ags=_G.AwesomeGuildStore
  if ags and type(ags.RegisterCallback)=='function' and ags.callback and ags.callback.AFTER_INITIAL_SETUP then
    pcall(function()
      ags:RegisterCallback(ags.callback.AFTER_INITIAL_SETUP, function()
        registerWritTooltips()
      end)
    end)
  end
  SLASH_COMMANDS['/writfolio']=W.Toggle;SLASH_COMMANDS['/wf']=W.Toggle
  local api=_G.LibFurnitureCatalogue and _G.LibFurnitureCatalogue.API
  if api and type(api.OnReady)=='function' then api.OnReady(function() W.Scan() end) end
  if api and api.RegisterCallback and api.Events and api.Events.SCAN_COMPLETE then
    api.RegisterCallback(api.Events.SCAN_COMPLETE,function() W.Scan() end)
  end
  W.Scan()
  if EVENT_RECIPE_LEARNED then
    EVENT_MANAGER:RegisterForEvent(ADDON..'_Knowledge',EVENT_RECIPE_LEARNED,function() invalidateKnowledge(); if W.Render then W.Render() end end)
  end
  say(string.format('Ready: %d Documents / %d plans. Open with /wf.',#W.groups,totalRecords()))
end
EVENT_MANAGER:RegisterForEvent(ADDON,EVENT_ADD_ON_LOADED,function(_,addon)
  if addon~=ADDON then return end
  EVENT_MANAGER:UnregisterForEvent(ADDON,EVENT_ADD_ON_LOADED)
  initialize()
end)
