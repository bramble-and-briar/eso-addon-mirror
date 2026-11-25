local V=VendorSidekick
local M=V.Model
local UI=LibSidekickUI
UI.DeclareJournalUsage() -- Before addon loaded: public journal requirement.
local WM=WINDOW_MANAGER
V.page="ledger";V.kind="all";V.character="all";V.period="Today";V.search="";V.ledgerPage=1;V.queuePage=1
local function Label(parent,text,x,y,w,small,heading)
 return UI.CreateLabel(parent,{text=text,x=x,y=y,width=w or 860,small=small,heading=heading,maxLines=1})
end
local function Button(parent,text,x,y,w,fn)return UI.CreateButton(parent,{text=text,x=x,y=y,width=w,onClick=fn})end
local function Page(parent)local p=WM:CreateControl(nil,parent,CT_CONTROL);UI.Place(p,parent,0,0,880,530);return p end
local function CharOptions()
 local items={{id="all",label="All characters"}};local sorted={}
 for id,c in pairs(V.db.characters)do sorted[#sorted+1]={id=id,label=c.name}end
 table.sort(sorted,function(a,b)return a.label<b.label end);for _,c in ipairs(sorted)do items[#items+1]=c end;return items
end
local function ChangeFilter(view,key,value)V[key]=value;V.ledgerPage=1;V.selectedRecord=nil;V.Render()end
local function BuildView(canvas,header,body,footer)
 local view={canvas=canvas,pages={},rows={},queueRows={}};V.views[#V.views+1]=view
 view.tabs=UI.CreateTabs(header,{width=880,items={{id="ledger",label="Ledger"},{id="queue",label="Junk queue"},{id="settings",label="Settings"},{id="export",label="Copy / export"},{id="help",label="Help"}},value=V.page,
  onSelect=function(id)V.page=id;V.Render()end})
 for _,name in ipairs({"ledger","queue","settings","export","help"})do view.pages[name]=Page(body)end
 view.filters=WM:CreateControl(nil,header,CT_CONTROL);UI.Place(view.filters,header,0,38,880,34)
 view.kind=UI.CreateDropdown(view.filters,{width=155,items={{id="all",label="All activity"},{id="vendor",label="Vendor sales"},{id="fence",label="Fence sales"},{id="launder",label="Laundering"},{id="buyback",label="Buybacks"}},value="all",onSelect=function(id)ChangeFilter(view,"kind",id)end})
 view.character=UI.CreateDropdown(view.filters,{x=165,width=260,items=CharOptions(),value="all",onSelect=function(id)ChangeFilter(view,"character",id)end})
 view.period=UI.CreateDropdown(view.filters,{x=435,width=155,items={{id="Today",label="Today"},{id="7 days",label="7 days"},{id="All",label="All retained"}},value="Today",onSelect=function(id)ChangeFilter(view,"period",id)end})
 view.search=UI.CreateEditBox(view.filters,{x=605,width=265,height=34,maxChars=100,text="",onChanged=function(text)V.search=text;V.ledgerPage=1;V.ScheduleRender()end})
 local p=view.pages.ledger
 view.totals=UI.CreateLabel(p,{text="",width=860,height=78})
 for _,c in ipairs({{"Date",0,125},{"Character",125,140},{"Activity",275,115},{"Item",400,280},{"Qty",700,45},{"Gold",760,90}})do Label(p,c[1],c[2],99,c[3],true,true)end
 for i=1,12 do
  local row=WM:CreateControl(nil,p,CT_BUTTON);UI.Place(row,p,0,128+(i-1)*28,860,28);row:SetMouseEnabled(true)
  local bg=WM:CreateControl(nil,row,CT_BACKDROP);bg:SetAnchorFill();bg:SetCenterColor(.08,.09,.12,i%2==0 and .4 or .1);bg:SetEdgeColor(0,0,0,0)
  row.date=Label(row,"",0,0,120,true);row.character=Label(row,"",125,0,140,true);row.kind=Label(row,"",275,0,120,true);row.item=Label(row,"",400,0,290,true);row.qty=Label(row,"",700,0,50,true);row.gold=Label(row,"",760,0,100,true)
  row:SetHandler("OnClicked",function(self)V.selectedRecord=self.record;V.page="export";V.Render()end);view.rows[i]=row
 end
 view.empty=Label(p,"No transactions match these filters yet.",0,135,850)
 Button(p,"Previous",0,474,150,function()V.ledgerPage=math.max(1,V.ledgerPage-1);V.Render()end)
 Button(p,"Next",170,474,150,function()V.ledgerPage=V.ledgerPage+1;V.Render()end)
 view.pageLabel=Label(p,"",345,478,400,true)
 p=view.pages.queue
 view.queueStatus=UI.CreateLabel(p,{text="",width=860,height=65})
 Button(p,"Pause this visit",0,66,190,function()
  if V.open then V.Pause()else V.notice="No merchant open. Turn auto-sale OFF to review before the next visit."end;V.Render()
 end)
 Button(p,"Refresh preview",205,66,165,function()V.Render()end)
 view.queueAuto=Button(p,"",390,66,210,function()V.db.settings.autoSell=not V.db.settings.autoSell;if not V.db.settings.autoSell then V.manualBatch=false end;V.Render()end)
 view.sellAll=Button(p,"Sell all ready junk",620,66,240,function()local ok,msg=V.StartBatch();if not ok then V.notice=msg end;V.Render()end)
 for _,c in ipairs({{"Item",0,305},{"Qty",315,45},{"Each",375,75},{"Line value",455,90},{"Sale status",550,160}})do Label(p,c[1],c[2],116,c[3],true,true)end
 -- Explicitly anchored paged rows avoid relying on a virtual scroll child's
 -- clipping/layout state. Both the standalone view and journal share this table.
 for i=1,7 do
  local row=WM:CreateControl(nil,p,CT_CONTROL);UI.Place(row,p,0,146+(i-1)*42,860,40)
  local bg=WM:CreateControl(nil,row,CT_BACKDROP);bg:SetAnchorFill();bg:SetCenterColor(.08,.09,.12,i%2==0 and .4 or .1);bg:SetEdgeColor(0,0,0,0)
  row.nameLabel=Label(row,"",4,7,301,true)
  row.quantity=Label(row,"",315,7,45,true)
  row.unit=Label(row,"",375,7,75,true)
  row.total=Label(row,"",455,7,90,true)
  row.saleStatus=Label(row,"",550,7,160,true)
  row.keep=Button(row,"",725,4,135,function()local id=tostring(row.itemId);V.db.keep[id]=not V.db.keep[id] or nil;V.Render()end)
  view.queueRows[i]=row
 end
 view.queueEmpty=UI.CreateLabel(p,{text="No items marked as junk. Mark items in ESO's inventory, then refresh this preview.",y=155,width=850,height=70})
 view.queueTotal=Label(p,"",0,449,860,false,true)
 Button(p,"Previous",0,488,150,function()V.queuePage=math.max(1,V.queuePage-1);V.Render()end)
 Button(p,"Next",170,488,150,function()V.queuePage=V.queuePage+1;V.Render()end)
 view.queuePageLabel=Label(p,"",345,493,505,true)
 p=view.pages.settings
 view.auto=Button(p,"",0,0,750,function()V.db.settings.autoSell=not V.db.settings.autoSell;if not V.db.settings.autoSell then V.manualBatch=false end;V.Render()end)
 view.receipts=Button(p,"",0,44,750,function()V.db.settings.receipts=not V.db.settings.receipts;V.Render()end)
 view.protect=Button(p,"",0,88,750,function()V.db.settings.protectPurple=not V.db.settings.protectPurple;V.Render()end)
 UI.CreateLabel(p,{y=145,width=850,height=140,text="Stolen goods: TRACKING ONLY. No auto-fence or auto-launder option exists.\n\nAutomation sells ordinary junk at merchants. Keep rules only affect this addon; use ESO item locks to prevent accidental manual sales too.\n\nSaved history: up to 5,000 recent transactions per account/server."})
 view.kept=UI.CreateLabel(p,{y=315,width=850,height=150,text=""})
 p=view.pages.export
 Label(p,"Click the field, then Ctrl+A / Ctrl+C. Mouse wheel scrolls the text.",0,0,860,true)
 view.export=UI.CreateEditBox(p,{y=38,width=860,height=390,multiline=true,maxChars=120000,text=""})
 Button(p,"Export filtered ledger",0,448,330,function()V.selectedRecord=nil;V.Render()end)
 Button(p,"Back to ledger",380,448,250,function()V.page="ledger";V.Render()end)
 p=view.pages.help
 local _,child=UI.CreateScroll(p,{width=880,height=525,contentHeight=2000})
 local help=UI.CreateLabel(child,{text=V.help,width=850,height=2000});local _,height=help:GetTextDimensions();help:SetHeight(height);child:SetHeight(height+20)
 view.status=Label(canvas,"",20,630,880,true)
 UI.CreateAuthorFooter(footer,{author="FoulMouthxAmazon",version=V.version,donation="https://buymeacoffee.com/foulmouthxamazon",goldRecipient="@FoulMouthxAmazon",onMessage=V.Say})
 return view
end
local function ShowQueue(view)
 local list,summary=M.QueueReceipt(V.Preview());local pages=math.max(1,math.ceil(#list/7))
 V.queuePage=math.max(1,math.min(V.queuePage,pages))
 view.queueStatus:SetText(string.format("RECEIPT PREVIEW - %d ordinary items ready in %d lines\nExcluded: %d items. Values are previews; excluded lines are not included in the total.",summary.quantity,summary.lines,summary.excluded))
 view.queueAuto:SetText("Auto-sale: "..(V.db.settings.autoSell and "ON" or "OFF"))
 view.queueEmpty:SetHidden(#list>0)
 for i,row in ipairs(view.queueRows)do
  local item=list[(V.queuePage-1)*7+i];row:SetHidden(item==nil)
  if item then
   row.itemId=item.itemId;row.nameLabel:SetText(item.link and item.link~="" and item.link or item.name)
   row.quantity:SetText(tostring(item.quantity));row.unit:SetText(M.Gold(item.price));row.total:SetText(M.Gold(item.total))
   row.saleStatus:SetText(item.exclusion or "Ready to sell")
   row.keep:SetText(V.db.keep[tostring(item.itemId)] and "Allow" or "Keep")
  end
 end
 view.queueTotal:SetText("READY-TO-SELL TOTAL: "..M.Gold(summary.total).."  |  "..summary.quantity.." items (all pages)")
 view.queuePageLabel:SetText("Page "..V.queuePage.." / "..pages.." | "..#list.." receipt lines")
end
function V.Render()
 if not V.db then return end
 local rows=M.Filter(V.kind,V.character,V.period,V.search);local totals=M.Totals(rows)
 V.ledgerPage=math.max(1,math.min(V.ledgerPage,math.max(1,math.ceil(#rows/12))))
 for _,view in ipairs(V.views)do
  view.tabs:Select(V.page,false)
  for name,page in pairs(view.pages)do page:SetHidden(name~=V.page)end
  view.filters:SetHidden(V.page~="ledger")
  if V.page=="ledger" then
   UI.UpdateDropdown(view.character,CharOptions(),V.character,function(id)ChangeFilter(view,"character",id)end)
   view.kind.sidekickCombo:SetSelectedItem(V.kind=="all" and "All activity" or V.kinds[V.kind]);view.period.sidekickCombo:SetSelectedItem(V.period=="All" and "All retained" or V.period)
   view.totals:SetText(string.format("Vendor income: %dg     Fence income: %dg\nLaundering: -%dg     Buybacks: -%dg\nNet vendor flow: %dg | %d transactions | %d unconfirmed costs",totals.vendor,totals.fence,totals.launder,totals.buyback,totals.net,totals.transactions,totals.unknown))
   view.empty:SetHidden(#rows>0)
   for i,row in ipairs(view.rows)do
    local r=rows[(V.ledgerPage-1)*12+i];row.record=r;row:SetHidden(not r)
    if r then
     row.date:SetText(GetDateStringFromTimestamp(r.time));row.character:SetText(r.characterName);row.kind:SetText(V.kinds[r.kind]);row.item:SetText(r.link~="" and r.link or r.name);row.qty:SetText(tostring(r.quantity or "?"))
     row.gold:SetText(r.gold==nil and "?" or ((r.kind=="launder" or r.kind=="buyback") and "-" or "+")..r.gold.."g")
    end
   end
   view.pageLabel:SetText("Page "..V.ledgerPage.." / "..math.max(1,math.ceil(#rows/12)).." | Click a row for details")
  elseif V.page=="queue" then ShowQueue(view)
  elseif V.page=="settings" then
   local s=V.db.settings;view.auto:SetText("Auto-sell ordinary junk: "..(s.autoSell and "ON" or "OFF"));view.receipts:SetText("One receipt in chat after a vendor visit: "..(s.receipts and "ON" or "OFF"));view.protect:SetText("Extra purple/gold protection: "..(s.protectPurple and "ON" or "OFF"))
   local count=0;for _ in pairs(V.db.keep)do count=count+1 end;view.kept:SetText("Keep list: "..count.." base item IDs\nUse the Junk queue to Keep/Allow individual item types.\n\nNo startup chat spam; no guild sales, purchases, repairs or bounties are included in the ledger.")
  elseif V.page=="export" then
   local r=V.selectedRecord;local text
   if r then text=V.kinds[r.kind].."\n"..r.name.."\n"..r.link.."\nQuantity: "..tostring(r.quantity or "?").."\nGold: "..M.Gold(r.gold).."\nCharacter: "..r.characterName.."\nVendor: "..r.vendor.."\nDate: "..GetDateStringFromTimestamp(r.time).." "..(r.clock or "").."\nSource: "..(r.automatic and "Vendor Sidekick automatic sale" or "Manual / another addon").."\n\n"..M.Export({r})
   else text=M.Export(rows)end
   view.export:SetValue(text)
  end
  local status=V.notice or (V.open and (V.fence and "Fence: tracking only" or V.paused and "Automatic sales paused" or "Merchant open") or "Tracking NPC transactions | ordinary-junk automation "..(V.db.settings.autoSell and "ON" or "OFF"))
  local f=V.db.characters[V.characterId].fence
  if f and f.reset>GetTimeStamp() then status=status..string.format(" | Fence %d/%d; launder %d/%d used",f.used,f.total,f.launderUsed,f.launderTotal)end
  view.status:SetText(status)
 end
end
function V.ScheduleRender()
 if V.renderQueued then return end;V.renderQueued=true
 zo_callLater(function()V.renderQueued=false;if #V.views>0 then V.Render()end end,150)
end
function V.InitUI()
 local window=WM:CreateTopLevelWindow("VendorSidekickWindow");V.window=window
 window:SetDimensions(960,780);window:SetAnchor(CENTER,GuiRoot,CENTER,0,0);window:SetHidden(true);window:SetMouseEnabled(true);window:SetMovable(true);window:SetClampedToScreen(true)
 window:SetScale(math.min(1,(GuiRoot:GetWidth()-30)/960,(GuiRoot:GetHeight()-30)/780))
 local bg=WM:CreateControl(nil,window,CT_BACKDROP);bg:SetAnchorFill();bg:SetCenterColor(.035,.045,.065,.96);bg:SetEdgeColor(.38,.37,.28,1)
 UI.CreateLabel(window,{text="VENDOR SIDEKICK",x=20,y=10,width=750,heading=true})
 Button(window,"Close",835,8,100,function()window:SetHidden(true)end)
 local canvas,header,body,footer=UI.CreateJournalCanvas(window);UI.Place(canvas,window,20,55,920,700);BuildView(canvas,header,body,footer)
 local tab,problem=UI.RegisterJournalTab(V.name,{title="Vendor Sidekick",order=935,iconPrefix="EsoUI/Art/MainMenu/menuBar_inventory_",standaloneWindow=window,
  build=function(ctx)BuildView(ctx.canvas,ctx.header,ctx.body,ctx.footer)end,onShow=function()V.Render()end})
 V.journal=tab;V.journalProblem=problem;V.Render()
end
function V.Open(forceWindow)
 if V.journal and not forceWindow then if V.journal:IsActive()then V.journal:Hide()else V.journal:Show()end
 else if V.journal and V.journal:IsActive()then V.journal:Hide()end;V.window:SetHidden(not V.window:IsHidden());V.Render()end
end
