-- No saved variables, startup windows, automatic messages or native UI overrides.
local previous=LibSidekickUI
assert(previous==nil or type(previous)=="table","LibSidekickUI global name is already in use")
if previous and (previous.revision or 0)>=101 then return end
local UI=previous or {}
LibSidekickUI=UI
UI.version="0.1.1-beta"
UI.revision=101
UI.apiVersion=1
UI.clients=UI.clients or {}
UI._footers=UI._footers or setmetatable({},{__mode="k"})
UI._panels=UI._panels or {}
UI._controlSerial=UI._controlSerial or 0
-- Virtual XML templates name children with $(parent). An anonymous root can
-- therefore register bare global children such as BG or SelectedItemText.
-- All virtual instances need a unique, named root, even under anonymous hosts.
function UI._TemplateName(requested,kind)
 if requested~=nil then
  assert(type(requested)=="string" and requested~="","A template control name must be a nonempty string")
  assert(rawget(_G,requested)==nil,"Control name already exists: "..requested)
  return requested
 end
 local name
 repeat
  UI._controlSerial=UI._controlSerial+1
  name="LibSidekickUI"..kind.."Auto"..UI._controlSerial
 until rawget(_G,name)==nil
 return name
end
UI.JOURNAL_WIDTH=920
UI.JOURNAL_HEIGHT=700
local palette={body={.86,.86,.86,1},heading={.77,.75,.58,1},muted={.67,.67,.67,1},hover={1,1,1,1},background={.035,.045,.065,.88},border={.38,.37,.28,1}}
function UI.GetColor(role)
 local color=assert(palette[role or "body"],"Unknown LibSidekickUI color role")
 return {color[1],color[2],color[3],color[4]}
end
function UI._Number(value,fallback,low,high)
 if value==nil then value=fallback end
 assert(type(value)=="number" and value==value and value~=math.huge and value~=-math.huge,"Expected a finite number")
 assert((not low or value>=low) and (not high or value<=high),"Number outside supported range")
 return value
end
function UI.Place(control,parent,x,y,width,height)
 assert(control and parent,"Control and parent are required")
 x=UI._Number(x,0);y=UI._Number(y,0);width=UI._Number(width,100,1);height=UI._Number(height,30,1)
 control:ClearAnchors();control:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);control:SetDimensions(width,height)
 return control
end
function UI._Backdrop(parent,alpha)
 local bg=WINDOW_MANAGER:CreateControl(nil,parent,CT_BACKDROP)
 bg:SetAnchorFill();local c=palette.background;bg:SetCenterColor(c[1],c[2],c[3],alpha or c[4])
 bg:SetEdgeColor(unpack(palette.border));bg:SetEdgeTexture("",1,1,1)
 return bg
end
function UI._Tooltip(control,text)
 if not text or text=="" then return end
 control:SetHandler("OnMouseEnter",function(self)
  if InformationTooltip and InitializeTooltip and SetTooltipText then
   InitializeTooltip(InformationTooltip,self,TOP,0,-6,BOTTOM);SetTooltipText(InformationTooltip,text)
  end
 end)
 local function clear()if ClearTooltip and InformationTooltip then ClearTooltip(InformationTooltip)end end
 control:SetHandler("OnMouseExit",clear);control:SetHandler("OnEffectivelyHidden",clear)
end
-- Optional facilities always return a status. Consumers choose their fallback UI.
function UI.OpenURL(url)
 if type(url)~="string" or not url:match("^https://[%w%.%-]+[/%%?%w%-%._~:#=&+]*$") then return false,"A valid https:// URL is required." end
 if type(RequestOpenUnsafeURL)~="function" then return false,"External links are unavailable in this client." end
 RequestOpenUnsafeURL(url);return true
end
function UI.ComposeGoldTip(recipient)
 if type(recipient)~="string" or #recipient<2 or #recipient>80 or not recipient:match("^@[^%c]+$") then return false,"Enter an ESO @account recipient." end
 local sender=MAIL_SEND
 if type(IsInGamepadPreferredMode)=="function" and IsInGamepadPreferredMode() and MAIL_MANAGER_GAMEPAD and type(MAIL_MANAGER_GAMEPAD.GetSend)=="function" then sender=MAIL_MANAGER_GAMEPAD:GetSend() end
 if not sender or type(sender.ComposeMailTo)~="function" then return false,"Open Mail and address your optional tip to "..recipient.."." end
 sender:ComposeMailTo(recipient);return true
end
