local UI=LibSidekickUI
if UI.revision>101 then return end
if UI._widgetsRevision and UI._widgetsRevision>=101 then return end
UI._widgetsRevision=101
local WM=WINDOW_MANAGER
local function opts(options)return options or {}end
function UI.CreateLabel(parent,options)
 local o=opts(options);local c=WM:CreateControl(o.name,parent,CT_LABEL)
 UI.Place(c,parent,o.x,o.y,o.width or 880,o.height or 28)
 c:SetFont(o.small and "ZoFontGameSmall" or o.heading and "ZoFontGameBold" or "ZoFontGame")
 c:SetColor(unpack(UI.GetColor(o.muted and "muted" or o.heading and "heading" or "body")))
 if o.maxLines then c:SetMaxLineCount(UI._Number(o.maxLines,1,1))end
 c:SetText(o.text or "");return c
end
function UI.CreateButton(parent,options)
 local o=opts(options);local c=WM:CreateControl(o.name,parent,CT_BUTTON)
 UI.Place(c,parent,o.x,o.y,o.width or 150,o.height or 30);c:SetFont(o.small and "ZoFontGameSmall" or "ZoFontGameBold")
 c:SetText(o.text or "");c:SetNormalFontColor(unpack(UI.GetColor("heading")));c:SetMouseOverFontColor(unpack(UI.GetColor("hover")))
 c:SetMouseEnabled(o.enabled~=false)
 if o.onClick then assert(type(o.onClick)=="function","onClick must be a function");c:SetHandler("OnClicked",o.onClick)end
 UI._Tooltip(c,o.tooltip);return c
end
function UI.CreateIconButton(parent,options)
 local o=opts(options);assert(type(o.normal)=="string" and o.normal~="","A normal icon texture path is required")
 local c=WM:CreateControl(o.name,parent,CT_BUTTON)
 UI.Place(c,parent,o.x,o.y,o.width or 36,o.height or 36)
 c:SetNormalTexture(o.normal);c:SetPressedTexture(o.pressed or o.normal);c:SetMouseOverTexture(o.over or o.normal)
 c:SetMouseEnabled(o.enabled~=false)
 if o.onClick then assert(type(o.onClick)=="function","onClick must be a function");c:SetHandler("OnClicked",o.onClick)end
 UI._Tooltip(c,o.tooltip);return c
end
function UI.UpdateDropdown(control,items,selected,onSelect)
 assert(control and control.sidekickCombo,"Use a dropdown created by LibSidekickUI")
 assert(type(items)=="table","Dropdown items must be a list")
 if onSelect~=nil then assert(type(onSelect)=="function","onSelect must be a function")end
 -- Validate the entire list before mutating the existing menu.
 local seen={}
 for _,item in ipairs(items)do
  assert(type(item)=="table" and (type(item.id)=="string" or type(item.id)=="number") and type(item.label)=="string","Each dropdown item needs an id and label")
  assert(not seen[item.id],"Duplicate dropdown item id");seen[item.id]=true
 end
 local combo=control.sidekickCombo;combo:ClearItems();local label=nil
 for _,item in ipairs(items)do
  local id,text=item.id,item.label
  combo:AddItem(combo:CreateItemEntry(text,function()
   control.sidekickValue=id
   if control.sidekickOnSelect then control.sidekickOnSelect(id,control)end
  end))
  if id==selected then label=text end
 end
 control.sidekickOnSelect=onSelect;control.sidekickValue=label and selected or nil
 combo:SetSelectedItem(label or control.sidekickPlaceholder or "Choose...")
 return label~=nil
end
function UI.CreateDropdown(parent,options)
 local o=opts(options);local c=WM:CreateControlFromVirtual(UI._TemplateName(o.name,"Dropdown"),parent,"ZO_ComboBox")
 UI.Place(c,parent,o.x,o.y,o.width or 300,o.height or 30)
 c.sidekickCombo=ZO_ComboBox_ObjectFromContainer(c);c.sidekickCombo:SetSortsItems(false);c.sidekickPlaceholder=o.placeholder or "Choose..."
 UI.UpdateDropdown(c,o.items or {},o.value,o.onSelect);return c,c.sidekickCombo
end
function UI.CreateScroll(parent,options)
 local o=opts(options);local c=WM:CreateControlFromVirtual(UI._TemplateName(o.name,"Scroll"),parent,"ZO_ScrollContainer")
 UI.Place(c,parent,o.x,o.y,o.width or 880,o.height or 520)
 local child=c:GetNamedChild("ScrollChild");child:SetWidth((o.width or 880)-UI._Number(o.gutter,20,0));child:SetHeight(o.contentHeight or o.height or 520)
 return c,child
end
function UI.CreateEditBox(parent,options)
 local o=opts(options);if o.onChanged then assert(type(o.onChanged)=="function","onChanged must be a function")end
 local root=WM:CreateControl(o.name,parent,CT_CONTROL)
 UI.Place(root,parent,o.x,o.y,o.width or 850,o.height or 36)
 root.background=UI._Backdrop(root,.45)
 local edit=WM:CreateControl(nil,root,CT_EDITBOX);UI.Place(edit,root,8,5,root:GetWidth()-16,root:GetHeight()-10)
 edit:SetFont("ZoFontGame");edit:SetColor(unpack(UI.GetColor("body")))
 edit:SetMaxInputChars(UI._Number(o.maxChars,3000,1,120000));edit:SetMultiLine(o.multiline==true);edit:SetNewLineEnabled(o.multiline==true)
 edit:SetCopyEnabled(true);edit:SetPasteEnabled(o.readOnly~=true);edit:SetEditEnabled(o.readOnly~=true);edit:SetMouseEnabled(true)
 edit:SetHandler("OnEscape",function(self)self:LoseFocus()end)
 edit:SetHandler("OnMouseWheel",function(self,delta)
  if not o.multiline then return end
  local maxLine=math.max(1,self:GetScrollExtents());self:SetTopLineIndex(math.max(1,math.min(maxLine,self:GetTopLineIndex()-delta*3)))
 end)
 root.edit=edit
 function root:GetValue()return self.edit:GetText()end
 function root:SetValue(text,notify)
  assert(type(text)=="string","Edit value must be a string");self.settingValue=true;self.edit:SetText(text);self.edit:SetCursorPosition(0);self.edit:SetTopLineIndex(1);self.settingValue=false
  if notify and o.onChanged then o.onChanged(self:GetValue(),self)end
 end
 edit:SetHandler("OnTextChanged",function()if not root.settingValue and o.onChanged then o.onChanged(root:GetValue(),root)end end)
 root:SetValue(o.text or "");return root,edit
end
function UI.CreateTabs(parent,options)
 local o=opts(options);local items=o.items or {};assert(#items>0,"At least one tab is required")
 if o.onSelect then assert(type(o.onSelect)=="function","onSelect must be a function")end
 local width=UI._Number(o.width,880,80);local minWidth=UI._Number(o.minTabWidth,100,60)
 local columns=math.max(1,math.min(#items,math.floor(width/minWidth)));local rows=math.ceil(#items/columns)
 local root=WM:CreateControl(o.name,parent,CT_CONTROL);UI.Place(root,parent,o.x,o.y,width,rows*36)
 root.buttons={};root.selected=nil
 for i,item in ipairs(items)do
  local id=item.id;assert(id~=nil and type(item.label)=="string" and not root.buttons[id],"Tabs need unique ids and text labels")
  root.buttons[id]=UI.CreateButton(root,{x=((i-1)%columns)*(width/columns),y=math.floor((i-1)/columns)*36,width=width/columns-4,text=item.label,onClick=function()root:Select(id,true)end})
 end
 function root:Select(id,notify)
  assert(self.buttons[id],"Unknown tab id");self.selected=id
  for key,button in pairs(self.buttons)do button:SetNormalFontColor(unpack(UI.GetColor(key==id and "hover" or "heading")))end
  if notify and o.onSelect then o.onSelect(id,self)end
 end
 root:Select(o.value or items[1].id,false);return root
end
