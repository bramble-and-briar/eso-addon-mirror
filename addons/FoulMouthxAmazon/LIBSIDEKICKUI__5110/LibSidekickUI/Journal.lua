local UI=LibSidekickUI
if UI.revision>101 then return end
if UI._journalRevision and UI._journalRevision>=101 then return end
UI._journalRevision=101
local function Journal()
 local journal=LibExtendedJournal
 if type(journal)=="table" and type(journal.RegisterTab)=="function" and type(journal.Show)=="function" then return journal end
end
function UI.HasJournal()return Journal()~=nil end
-- Call at CONSUMER FILE LOAD, before EVENT_ADD_ON_LOADED. The library itself
-- does not claim the journal just because it happens to be installed.
function UI.DeclareJournalUsage()
 local journal=Journal();if not journal then return false,"LibExtendedJournal is not installed." end
 journal.Used=true;return true
end
function UI.CreateJournalCanvas(parent)
 local canvas=WINDOW_MANAGER:CreateControl(nil,parent,CT_CONTROL)
 UI.Place(canvas,parent,0,0,UI.JOURNAL_WIDTH,UI.JOURNAL_HEIGHT);canvas:SetAlpha(1)
 local header=WINDOW_MANAGER:CreateControl(nil,canvas,CT_CONTROL);UI.Place(header,canvas,20,4,880,72)
 local body=WINDOW_MANAGER:CreateControl(nil,canvas,CT_CONTROL);UI.Place(body,canvas,20,90,880,530)
 local footer=WINDOW_MANAGER:CreateControl(nil,canvas,CT_CONTROL);UI.Place(footer,canvas,20,662,880,30)
 return canvas,header,body,footer
end
function UI.RegisterJournalTab(clientId,options)
 assert(type(clientId)=="string" and clientId:match("^[%w_]+$"),"Journal client id must contain only letters, digits or underscores")
 if UI.clients[clientId] then return UI.clients[clientId]end
 local journal=Journal();if not journal then return nil,"LibExtendedJournal is not installed. Use your standalone view." end
 if not journal.Used then return nil,"Call DeclareJournalUsage at addon file load before registering a journal tab." end
 local o=options or {};assert(type(o.title)=="string" and o.title~="","A journal title is required")
 if o.build then assert(type(o.build)=="function","build must be a function")end
 if o.onShow then assert(type(o.onShow)=="function","onShow must be a function")end
 if o.onHide then assert(type(o.onHide)=="function","onHide must be a function")end
 local host=WINDOW_MANAGER:CreateControl(nil,GuiRoot,CT_CONTROL);host:SetHidden(true)
 local canvas,header,body,footer=UI.CreateJournalCanvas(host)
 local ctx={id=clientId,host=host,canvas=canvas,header=header,body=body,footer=footer,width=920,height=700,bodyWidth=880,bodyHeight=530,active=false}
 function ctx:Fit()
  local width,height=self.host:GetWidth(),self.host:GetHeight()
  if width>0 and height>0 then self.canvas:SetScale(math.min(1,width/UI.JOURNAL_WIDTH,height/UI.JOURNAL_HEIGHT))end
 end
 function ctx:Show()journal.Show(self.id)end
 function ctx:Hide()if self.active then SCENE_MANAGER:ShowBaseScene()end end
 function ctx:IsActive()return self.active end
 host:SetHandler("OnRectChanged",function()ctx:Fit()end)
 if o.authorInfo then
  local info={};for k,v in pairs(o.authorInfo)do info[k]=v end;info.x=0;info.y=0;info.width=880
  ctx.authorFooter=UI.CreateAuthorFooter(footer,info)
 end
 -- Build once before public registration so a client build error cannot leave
 -- a half-registered tab. The caller can fix its build callback and retry.
 if o.build then
  local ok,message=pcall(o.build,ctx)
  if not ok then host:SetHidden(true);return nil,"Journal build failed: "..tostring(message)end
 end
 local data={order=o.order or 920,title=o.title,iconPrefix=o.iconPrefix or "EsoUI/Art/MainMenu/menuBar_journal_",control=host,
  callbackShow=function()
   if ctx.active then return end
   ctx.active=true
   if o.standaloneWindow then ctx.wasStandaloneVisible=not o.standaloneWindow:IsHidden();o.standaloneWindow:SetHidden(true)end
   canvas:SetAlpha(1);ctx:Fit()
   if o.onShow then o.onShow(ctx)end
  end,
  callbackHide=function()
   if not ctx.active then return end
   ctx.active=false
   if o.standaloneWindow then o.standaloneWindow:SetHidden(not ctx.wasStandaloneVisible)end
   if ClearTooltip and InformationTooltip then ClearTooltip(InformationTooltip)end
   if o.onHide then o.onHide(ctx)end
  end,
 }
 local ok,message=pcall(journal.RegisterTab,clientId,data)
 if not ok then host:SetHidden(true);return nil,"Journal registration failed: "..tostring(message)end
 ctx.tabData=data;UI.clients[clientId]=ctx;return ctx
end
