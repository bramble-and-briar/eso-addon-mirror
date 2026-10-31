-- Small native controls shared by the custom planner; no web renderer or new library.
SmartChatMsg=SmartChatMsg or {}
local S=SmartChatMsg
local UI={};S.PlannerUI=UI
local gold={0.78,0.65,0.36,1}
UI.theme={gold=gold,text={0.91,0.90,0.87,1},muted={0.62,0.68,0.71,1},teal={0.56,0.74,0.71,1},green={0.38,0.84,0.47,1}}
UI.fonts={body='$(MEDIUM_FONT)|18|soft-shadow-thin',heading='$(BOLD_FONT)|20|soft-shadow-thin',small='$(MEDIUM_FONT)|16|soft-shadow-thin',title='$(BOLD_FONT)|24|soft-shadow-thin'}
function UI.control(parent,key,kind,virtual)
    parent.plannerControls=parent.plannerControls or {}
    local c=parent.plannerControls[key]
    local controlKind=virtual or kind
    if c and c.plannerControlKind and c.plannerControlKind~=controlKind then
        error('SmartChatMsg planner control key reused for incompatible types: '..tostring(key))
    end
    if not c then
        S.plannerControlSerial=(S.plannerControlSerial or 0)+1
        local name='SCM_PlannerControl'..S.plannerControlSerial
        c=virtual and WINDOW_MANAGER:CreateControlFromVirtual(name,parent,virtual) or WINDOW_MANAGER:CreateControl(name,parent,kind)
        parent.plannerControls[key]=c
        c.plannerControlKind=controlKind
    end
    c.plannerScroll=parent.plannerScroll
    if c.plannerScroll then c:SetHandler('OnMouseWheel',function(_,delta)ZO_Scroll_OnMouseWheel(c.plannerScroll,delta)end) end
    c:SetHidden(false);return c
end
function UI.place(c,x,y,w,h)
    c:ClearAnchors();c:SetAnchor(TOPLEFT,c:GetParent(),TOPLEFT,x,y);c:SetDimensions(w,h);return c
end
function UI.hide(parent)
    for key,c in pairs(parent.plannerControls or {}) do if key~='bg' then c:SetHidden(true) end end
end
function UI.tooltip(c,text)
    c:SetMouseEnabled(true)
    c:SetHandler('OnMouseEnter',function(control) InitializeTooltip(InformationTooltip,control,TOP,0,8);SetTooltipText(InformationTooltip,text) end)
    c:SetHandler('OnMouseExit',function()ClearTooltip(InformationTooltip)end)
end
function UI.label(parent,key,text,x,y,w,h,heading)
    local c=UI.control(parent,key,CT_LABEL);c:SetFont(heading and UI.fonts.heading or UI.fonts.body)
    c:SetHorizontalAlignment(TEXT_ALIGN_LEFT);c:SetVerticalAlignment(TEXT_ALIGN_TOP)
    c:SetColor(unpack(UI.theme.text));c:SetText(text);return UI.place(c,x,y,w,h or 28)
end
function UI.box(parent,key,x,y,w,h,selected)
    local c=UI.control(parent,key,CT_CONTROL);UI.place(c,x,y,w,h)
    local bg=UI.control(c,'bg',nil,'ZO_DefaultBackdrop');bg:SetAnchorFill(c)
    bg:SetCenterColor(selected and 0.18 or 0.065,selected and 0.155 or 0.095,selected and 0.09 or 0.12,0.98)
    bg:SetEdgeColor(selected and 0.78 or 0.23,selected and 0.65 or 0.30,selected and 0.36 or 0.34,1)
    bg:SetMouseEnabled(false);return c
end
function UI.button(parent,key,text,x,y,w,callback,primary,help)
    local c=UI.control(parent,key,CT_BUTTON);UI.place(c,x,y,w,32)
    c:SetMouseEnabled(true)
    if not c.plannerBackdrop then
        c.plannerBackdrop=UI.control(c,'backdrop',nil,'ZO_DefaultBackdrop');c.plannerBackdrop:SetAnchorFill(c);c.plannerBackdrop:SetMouseEnabled(false)
    end
    c.plannerBackdrop:SetCenterColor(primary and 0.26 or 0.09,primary and 0.21 or 0.13,primary and 0.10 or 0.16,1)
    c.plannerBackdrop:SetEdgeColor(primary and 0.78 or 0.28,primary and 0.65 or 0.37,primary and 0.36 or 0.41,1)
    -- A label anchored to every edge remains centered even when rows are taller.
    c:SetText('')
    local label=UI.label(c,'buttonText',text,4,0,w-8,32)
    label:ClearAnchors();label:SetAnchor(TOPLEFT,c,TOPLEFT,6,0);label:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-6,0)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER);label:SetVerticalAlignment(TEXT_ALIGN_CENTER);label:SetMouseEnabled(false)
    label:SetColor(unpack(primary and gold or UI.theme.text))
    c:SetHandler('OnMouseEnter',function(control)
        label:SetColor(1,0.92,0.70,1)
        if help then InitializeTooltip(InformationTooltip,control,TOP,0,8);SetTooltipText(InformationTooltip,help) end
    end)
    c:SetHandler('OnMouseExit',function()label:SetColor(unpack(primary and gold or UI.theme.text));if help then ClearTooltip(InformationTooltip)end end)
    c:SetHandler('OnClicked',callback);return c
end
function UI.edit(parent,key,text,x,y,w,h,callback,multiline,help,maxChars)
    local box=UI.box(parent,key,x,y,w,h)
    local edit=UI.control(box,'edit',CT_EDITBOX);UI.place(edit,8,4,w-16,h-8)
    edit:SetFont(UI.fonts.body);edit:SetColor(unpack(UI.theme.text));edit:SetMaxInputChars(maxChars or (multiline and 2000 or 120))
    edit:SetMultiLine(multiline==true);edit:SetMouseEnabled(true)
    edit:SetEditEnabled(true)
    edit:SetCopyEnabled(true);edit:SetPasteEnabled(true);edit:SetSelectAllOnFocus(false)
    edit:SetNewLineEnabled(multiline==true);edit:SetSelectionColor(0.28,0.46,0.58,0.90)
    edit:SetHandler('OnMouseDown',function(c,button)if button==MOUSE_BUTTON_INDEX_LEFT then c:TakeFocus()end end)
    if multiline then
        edit:SetHandler('OnMouseWheel',function(c,delta)
            if c:HasFocus()then c:SetTopLineIndex(math.max(1,math.min(c:GetScrollExtents()+1,c:GetTopLineIndex()-delta)))
            elseif c.plannerScroll then ZO_Scroll_OnMouseWheel(c.plannerScroll,delta)end
        end)
    end
    edit:SetHandler('OnTextChanged',nil);edit:SetText(tostring(text or ''))
    edit:SetHandler('OnTextChanged',function(c)if not S.plannerRefreshing then callback(c:GetText()) end end)
    edit:SetHandler('OnEscape',function(c)c:LoseFocus()end)
    if not multiline then edit:SetHandler('OnEnter',function(c)c:LoseFocus()end) end
    if help then UI.tooltip(box,help) end;box.edit=edit;return box
end
function UI.check(parent,key,text,value,x,y,w,callback,help,disabled)
    local c=UI.control(parent,key,CT_BUTTON);UI.place(c,x,y,w,28);c:SetMouseEnabled(not disabled)
    local box=UI.control(c,'box',nil,'ZO_CheckButton');UI.place(box,0,2,24,24);box:SetMouseEnabled(not disabled);box:SetAlpha(disabled and 0.4 or 1)
    ZO_CheckButton_SetCheckState(box,value==true)
    local l=UI.label(c,'label',text,32,0,w-32,28);l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    if disabled then l:SetColor(0.45,0.49,0.51,1) end
    local function changed(nextValue)
        if disabled then ZO_CheckButton_SetCheckState(box,value==true);return end
        value=nextValue==true;ZO_CheckButton_SetCheckState(box,value);callback(value)
    end
    ZO_CheckButton_SetToggleFunction(box,function(_,checked)changed(checked)end)
    c:SetHandler('OnClicked',function()changed(not value)end)
    if help then UI.tooltip(box,help);box:SetMouseEnabled(not disabled) end
    if help then UI.tooltip(c,help);c:SetMouseEnabled(true) end
    return c
end
function UI.combo(parent,key,labels,values,value,x,y,w,callback,help)
    local c=UI.control(parent,key,nil,'ZO_ComboBox');UI.place(c,x,y,w,32)
    local combo=ZO_ComboBox_ObjectFromContainer(c);combo:SetSortsItems(false);combo:ClearItems()
    if combo.SetFont then combo:SetFont(UI.fonts.body) end
    local selected='Choose'
    for i,label in ipairs(labels) do
        local v=values and values[i] or label
        local entry=combo:CreateItemEntry(label,function()if not S.plannerRefreshing then callback(v)end end)
        combo:AddItem(entry);if v==value then selected=label end
    end
    combo:SetSelectedItem(selected);if help then UI.tooltip(c,help) end;return c
end
function UI.slider(parent,key,label,value,min,max,x,y,w,callback,format,help,exactMax,exactMin)
    local holder=UI.control(parent,key,CT_CONTROL);UI.place(holder,x,y,w,58)
    local labelControl=UI.label(holder,'label',label..' — '..format(value),0,0,w,27)
    holder.exactMin=exactMin or min;holder.exactMax=math.max(exactMax or max,value)
    holder.sliderMax=max
    local sliderWidth=math.max(70,w-116)
    local c=UI.control(holder,'slider',CT_SLIDER);UI.place(c,8,30,sliderWidth,24)
    c:SetOrientation(ORIENTATION_HORIZONTAL)
    c:SetMouseEnabled(true)
    c:SetMinMax(min,max);c:SetValueStep(1)
    c:SetThumbTexture('EsoUI/Art/Buttons/smoothsliderbutton_up.dds','EsoUI/Art/Buttons/smoothsliderbutton_up.dds','EsoUI/Art/Buttons/smoothsliderbutton_up.dds',22,22)
    local bg=UI.control(c,'track',CT_BACKDROP);UI.place(bg,0,9,sliderWidth,6)
    bg:SetCenterColor(0.09,0.14,0.18,1);bg:SetEdgeColor(0.34,0.45,0.49,1)
    bg:SetEdgeTexture('EsoUI/Art/Tooltips/UI-SliderBackdrop.dds',32,2);bg:SetDrawLayer(DL_BACKGROUND);bg:SetMouseEnabled(false)
    c:SetHandler('OnValueChanged',nil);c:SetValue(value)
    local syncing=false;local exact
    local function change(v,typed)
        if S.plannerRefreshing or syncing or holder.plannerDisabled then return end
        if not v or v~=math.floor(v) or v<holder.exactMin or v>holder.exactMax then return end
        syncing=true;value=v
        if typed then c:SetMinMax(math.min(min,v),math.max(holder.sliderMax,v));c:SetValue(v)end
        labelControl:SetText(label..' — '..format(v))
        if exact and exact.edit:GetText()~=tostring(v)then exact.edit:SetText(tostring(v))end
        syncing=false;callback(v)
    end
    exact=UI.edit(holder,'exact',tostring(value),w-86,28,82,30,function(text)change(tonumber(text),true)end,false,'Enter an exact whole-number value in the same units as this slider.',8)
    exact.edit:SetTextType(TEXT_TYPE_NUMERIC)
    exact.edit:SetHandler('OnFocusLost',function()if exact.edit:GetText()~=tostring(value)then syncing=true;exact.edit:SetText(tostring(value));syncing=false end end)
    c:SetHandler('OnValueChanged',function(_,v)change(math.floor(v+0.5),false)end)
    if help then UI.tooltip(holder,help) end;return holder
end
function UI.scroll(parent,key,x,y,w,h)
    local c=UI.control(parent,key,nil,'ZO_ScrollContainer');UI.place(c,x,y,w,h)
    local child=c:GetNamedChild('Scroll'):GetNamedChild('Child');child:SetResizeToFitDescendents(false);child:SetWidth(w-24)
    child.plannerScroll=c
    child:SetMouseEnabled(true);child:SetHandler('OnMouseWheel',function(_,d)ZO_Scroll_OnMouseWheel(c,d)end)
    return c,child,w-24
end
function UI.scrollEnd(scroll,child,height)
    child:SetHeight(math.max(1,height));ZO_Scroll_UpdateScrollBar(scroll)
end
function UI.clock(parent,key,value,x,y,w,callback,zone)
    local hour,minute,ampm=tostring(value or ''):match('^(%d%d?):(%d%d) ([AP]M)$')
    hour,minute,ampm=hour or '08',minute or '00',ampm or 'PM'
    local hours,minutes={},{};for h=1,12 do hours[#hours+1]=string.format('%02d',h)end;for m=0,59 do minutes[#minutes+1]=string.format('%02d',m)end
    local part=math.floor((w-38)/3)
    UI.combo(parent,key..'h',hours,nil,hour,x,y,part,function(v)callback(v..':'..minute..' '..ampm)end)
    UI.combo(parent,key..'m',minutes,nil,minute,x+part+3,y,part,function(v)callback(hour..':'..v..' '..ampm)end)
    UI.combo(parent,key..'a',{'AM','PM'},nil,ampm,x+part*2+6,y,part,function(v)callback(hour..':'..minute..' '..v)end)
    UI.label(parent,key..'z',zone or '',x+part*3+9,y+3,36,28)
end
-- A native, timezone-neutral calendar. Dates are civil dates, never OS-local timestamps.
function S:ShowPlannerCalendar(date,callback)
    local win=self.plannerWindow;local UI=self.PlannerUI
    local popup=UI.box(win,'calendar',0,0,330,330,true);popup:ClearAnchors();popup:SetAnchor(CENTER,win,CENTER,0,0);popup:SetDrawTier(DT_HIGH);popup:SetMouseEnabled(true)
    local year,month=tostring(date):match('^(%d%d%d%d)%-(%d%d)');year,month=tonumber(year) or 2026,tonumber(month) or 1
    year=math.max(2007,math.min(2099,year));month=math.max(1,math.min(12,month))
    local function render()
        UI.hide(popup);UI.box(popup,'background',0,0,330,330,true)
        UI.label(popup,'month',os.date('!%B %Y',self:ParseScheduleDateTime(string.format('%04d-%02d-01',year,month),'12:00 PM','FIRST',{timeZone='ET'})),45,12,240,28,true)
        UI.button(popup,'prev','<',10,10,30,function()if year==2007 and month==1 then return end;month=month-1;if month<1 then month=12;year=year-1 end;render()end)
        UI.button(popup,'next','>',288,10,30,function()if year==2099 and month==12 then return end;month=month+1;if month>12 then month=1;year=year+1 end;render()end)
        for i,label in ipairs({'Su','Mo','Tu','We','Th','Fr','Sa'}) do UI.label(popup,'day'..i,label,14+(i-1)*44,51,40,25)end
        local first=self:ParseScheduleDateTime(string.format('%04d-%02d-01',year,month),'12:00 PM','FIRST',{timeZone='ET'})
        local weekday=os.date('!*t',first).wday
        local days=({31,year%4==0 and (year%100~=0 or year%400==0) and 29 or 28,31,30,31,30,31,31,30,31,30,31})[month]
        for d=1,days do local day=d;local slot=weekday+d-2
            UI.button(popup,'date'..d,tostring(d),12+slot%7*44,78+math.floor(slot/7)*35,40,function()popup:SetHidden(true);callback(string.format('%04d-%02d-%02d',year,month,day))end,date==string.format('%04d-%02d-%02d',year,month,day))
        end
        UI.button(popup,'cancel','Cancel',110,291,110,function()popup:SetHidden(true)end)
    end
    render()
end
function UI.date(parent,key,date,x,y,w,callback)
    return UI.button(parent,key,date or 'Choose date',x,y,w,function()S:ShowPlannerCalendar(date,callback)end,false,'Choose a calendar date in the guild scheduling timezone.')
end
