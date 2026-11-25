local UI=LibSidekickUI
if UI.revision>101 then return end
if UI._authorRevision and UI._authorRevision>=101 then return end
UI._authorRevision=101
local function Report(options,ok,message)
 if not ok and options.onMessage then options.onMessage(message)end
 return ok,message
end
function UI.CreateAuthorFooter(parent,options)
 local o=options or {};assert(parent,"Footer parent is required")
 local key=o.key or "default";local footers=UI._footers[parent]
 if not footers then footers={};UI._footers[parent]=footers end
 if footers[key] then return footers[key]end
 local width=UI._Number(o.width,880,240);local author=tostring(o.author or "");local version=tostring(o.version or "")
 local root=WINDOW_MANAGER:CreateControl(nil,parent,CT_CONTROL);footers[key]=root
 UI.Place(root,parent,o.x or 0,o.y or 0,width,24);root.links={}
 local label=UI.CreateLabel(root,{x=0,y=0,width=width,height=24,small=true,muted=true,maxLines=1,text="Author: "..author..(version~="" and " | v"..version or "")})
 root.authorLabel=label
 local links={}
 if o.website and o.website~="" then links[#links+1]={text="Website",width=82,action=function()return UI.OpenURL(o.website)end}end
 if o.feedback and o.feedback~="" then links[#links+1]={text="Feedback",width=92,action=function()return UI.OpenURL(o.feedback)end}end
 if o.donation and o.donation~="" then links[#links+1]={text="Buy Me a Coffee",width=142,action=function()return UI.OpenURL(o.donation)end}end
 if o.goldRecipient and o.goldRecipient~="" then links[#links+1]={text="Tip ESO Gold",width=120,action=function()return UI.ComposeGoldTip(o.goldRecipient)end}end
 -- Preserve readable link sizes; wrap onto additional rows instead of squeezing.
 local x,y=math.min(330,width),0
 for _,link in ipairs(links)do
  if x+link.width>width then x=0;y=y+28 end
  local action=link.action
  local button=UI.CreateButton(root,{x=x,y=y,width=link.width,height=24,small=true,text=link.text,onClick=function()Report(o,action())end})
  root.links[#root.links+1]=button;x=x+link.width+8
 end
 root:SetHeight(y+24);return root
end
function UI.RegisterAuthorPanel(clientId,options)
 assert(type(clientId)=="string" and clientId~="","A client id is required")
 if UI._panels[clientId] then return UI._panels[clientId]end
 local lam=LibAddonMenu2;if not lam or type(lam.RegisterAddonPanel)~="function" or type(lam.RegisterOptionControls)~="function" then return nil,"LibAddonMenu-2.0 is not installed." end
 local o=options or {};local controls={{type="description",text=o.description or ""}}
 if o.onOpen then controls[#controls+1]={type="button",name="Open "..(o.title or clientId),func=o.onOpen}end
 if o.goldRecipient then controls[#controls+1]={type="button",name="Tip ESO Gold",tooltip="Opens a draft. You choose the amount and send it yourself.",func=function()Report(o,UI.ComposeGoldTip(o.goldRecipient))end}end
 if o.donation then controls[#controls+1]={type="button",name="Buy Me a Coffee",func=function()Report(o,UI.OpenURL(o.donation))end}end
 local panel=lam:RegisterAddonPanel(clientId.."SidekickAuthor",{type="panel",name=o.title or clientId,displayName=o.title or clientId,author=o.author or "",version=o.version or "",website=o.website,feedback=o.feedback,donation=o.donation})
 lam:RegisterOptionControls(clientId.."SidekickAuthor",controls);UI._panels[clientId]=panel;return panel
end
