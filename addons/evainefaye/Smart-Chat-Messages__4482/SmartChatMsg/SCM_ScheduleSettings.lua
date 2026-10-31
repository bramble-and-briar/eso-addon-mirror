SmartChatMsg = SmartChatMsg or {}

-- Open sections when their controls become relevant, not on every refresh.
-- Track native instances too: LAM creates widgets asynchronously.
function SmartChatMsg:RefreshEventTimingExpansion()
    local draft=self:GetScheduleEditorDraft()
    local selected=self:IsMessagesSelectionComplete()
    local scheduled=selected and self:GetGuildRunAt(self.savedVars.selectedMessagesCommand,self:GetSelectedGuildNameForMessages())=="SCHEDULED"
    local key=self.scheduleEditor.key
    local state=self.relevantSettingsExpansion
    if not state or state.key~=key then state={key=key,controls={}};self.relevantSettingsExpansion=state end
    local repeating=draft.recurrence and draft.recurrence~="NONE"
    local rules={
        {"SCM_MessagesSubmenu",self:CanUseMessagesSection()},
        {"SCM_SchedulingSubmenu",scheduled,"SCM_MessagesSubmenu"},
        {"SCM_WindowTimingSubmenu",scheduled and draft.mode=="WINDOW","SCM_SchedulingSubmenu"},
        {"SCM_ReminderTimingSubmenu",scheduled and draft.mode=="REMINDER","SCM_SchedulingSubmenu"},
        {"SCM_EventTimingSubmenu",scheduled and draft.mode=="EVENT","SCM_SchedulingSubmenu"},
        {"SCM_FactionRotationSubmenu",scheduled and draft.mode=="EVENT" and repeating and draft.specialPattern=="FACTION_ROTATION","SCM_SchedulingSubmenu"},
        {"SCM_EventRotationSubmenu",scheduled and draft.mode=="EVENT" and repeating and draft.specialPattern=="EVENT_ROTATION","SCM_SchedulingSubmenu"},
        {"SCM_OccurrenceCancellationSubmenu",scheduled and (next(draft.occurrenceExceptions or {})~=nil or draft.mode=="EVENT" and repeating and (draft.specialPattern=="EVENT_ROTATION" or draft.specialPattern=="FACTION_ROTATION")),"SCM_SchedulingSubmenu"},
        {"SCM_RepeatOptionsSubmenu",scheduled and repeating,"SCM_SchedulingSubmenu"},
        {"SCM_MonthlyWeekdaySubmenu",scheduled and draft.recurrence=="MONTHLY_WEEKDAY","SCM_SchedulingSubmenu"},
        {"SCM_RepeatWeekdaysSubmenu",scheduled and (draft.recurrence=="DAILY" or draft.recurrence=="WEEKLY" or draft.recurrence=="BIWEEKLY"),"SCM_RepeatOptionsSubmenu"},
        {"SCM_MessageDeliverySubmenu",scheduled and draft.mode~="REMINDER","SCM_SchedulingSubmenu"},
    }
    for _,phase in ipairs({"ANY","BEFORE","DAY","SOON","LIVE"}) do
        local relevant=scheduled and ((phase=="ANY")~=(draft.mode=="EVENT")) and (phase~="SOON" or draft.startingSoonEnabled)
        rules[#rules+1]={"SCM_Phase"..phase.."Submenu",relevant,"SCM_SchedulingSubmenu",draft.mode=="EVENT" and (draft.specialPattern or "NONE") or "ANY"}
    end
    local parents={SCM_SchedulingSubmenu="SCM_MessagesSubmenu",SCM_RepeatOptionsSubmenu="SCM_SchedulingSubmenu"}
    local function reveal(name)
        if not name then return true end
        local control=_G[name]
        if control and control.disabled then return false end
        if not reveal(parents[name]) then return false end
        if control and not control.open then control.open=true;control.animation:PlayFromStart() end
        return true
    end
    -- Include all current and future submenus, including Period Timeline,
    -- important times and Availability. Sections with no enabled editor close.
    local known={};for _,rule in ipairs(rules) do known[rule[1]]=true end
    local function disabled(option)
        local value=option.disabled
        if type(value)=='function' then local ok,result=pcall(value);return not ok or result==true end
        return value==true
    end
    local function editable(list)
        for _,option in ipairs(list) do if not disabled(option) then
            if option.type=='submenu' then if editable(option.controls or {}) then return true end
            elseif option.type~='description' and option.type~='header' and option.type~='divider' then return true end
        end end
        return false
    end
    local function collect(list,parent,parentActive)
        for _,option in ipairs(list) do if option.type=='submenu' then
            local enabled=parentActive and not disabled(option) and editable(option.controls or {})
            if option.reference then
                parents[option.reference]=parent
                if not known[option.reference] then rules[#rules+1]={option.reference,enabled,parent} end
            end
            collect(option.controls or {},option.reference or parent,enabled)
        end end
    end
    collect(self.settings and self.settings.optionDefinitions or {},nil,true)
    for _,rule in ipairs(rules) do
        local name,active,parent,variant=unpack(rule)
        local control=_G[name]
        if control then
            local previous=state.controls[name]
            if not active or control.disabled then
                if control.open then
                    control.open=false
                    if control.animation and control.animation.PlayFromEnd then control.animation:PlayFromEnd() end
                end
                state.controls[name]={control=control,active=false}
            elseif not control.disabled and (not previous or previous.control~=control or not previous.active or previous.variant~=variant) then
                if reveal(parent) then reveal(name);state.controls[name]={control=control,active=true,variant=variant} end
            end
        end
    end
end

local function copy(v)
    if type(v)~="table" then return v end
    local r={}; for k,item in pairs(v) do r[k]=copy(item) end; return r
end

-- Upstream DatePicker uses local os.time/os.date. This timestamp carries a
-- calendar day, not a zoned instant; the engine alone resolves scheduling time.
function SmartChatMsg:ScheduleDateToPicker(date)
    local y,m,d=tostring(date or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not y then return GetTimeStamp() end
    return os.time({year=tonumber(y),month=tonumber(m),day=tonumber(d),hour=0,min=0,sec=0})
end
function SmartChatMsg:ScheduleDateFromPicker(timestamp)
    if type(timestamp)~="number" then return "" end
    local p=os.date("*t",timestamp)
    return string.format("%04d-%02d-%02d",p.year,p.month,p.day)
end

function SmartChatMsg:GetNextScheduleOccurrenceText(draft)
    local label=draft.mode=="EVENT" and "Next event" or draft.mode=="REMINDER" and "Next reminder" or "Next window"
    local schedule,reason=self:NormalizeSchedule(draft)
    if not schedule then return label..": "..tostring(reason) end
    local occurrence=self:GetUpcomingScheduleOccurrences(schedule,GetTimeStamp(),1,true)[1]
    local text=label..": "..(occurrence and self:FormatScheduleDateTime(occurrence.eventAtUtc,occurrence) or "None scheduled.")
    if occurrence and schedule.specialPattern~="NONE" then
        local variant=self:GetScheduleEventVariant(schedule,occurrence.eventAtUtc)
        text=text.."\n"..(schedule.specialPattern=="FACTION_ROTATION" and "Faction: " or "Message group: ")..self:GetScheduleVariantLabel(variant,schedule.specialPattern,schedule)
    end
    return text
end

function SmartChatMsg:GetScheduleEditorDraft()
    local id=self.savedVars.selectedMessagesCommand
    local guild=self:GetSelectedGuildNameForMessages()
    local key=tostring(id)..":"..tostring(guild)
    local source=self:GetGuildSchedule(id,guild)
    if not self.scheduleEditor or self.scheduleEditor.key~=key or self.scheduleEditor.source~=source then
        local p=self:GetTimeZoneParts(GetTimeStamp(),self:GetGuildSchedulingTimeZone(guild))
        local date=string.format("%04d-%02d-%02d",p.year,p.month,p.day)
        local d=source and copy(source) or {enabled=false,paused=false,delivery="REPEAT",intervalMinutes=15,
            startDate=date,startTime="08:00 PM",eventDate=date,eventTime="08:00 PM",endDate=date,endTime="09:00 PM"}
        d.timeZone=self:GetGuildSchedulingTimeZone(guild)
        d.startingSoonMinutes=d.startingSoonMinutes or 120
        d.mode=d.mode or (source and "EVENT" or "WINDOW"); d.recurrence=d.recurrence or "NONE"
        d.messagePhases=d.messagePhases or {}; d.phaseIntervals=d.phaseIntervals or {}; d.phaseOnce=d.phaseOnce or {}; d.weekdays=d.weekdays or {}
        d.specialPattern=d.specialPattern or "NONE";d.rotationWeeks=d.rotationWeeks or 4
        d.rotationEvery=d.rotationEvery or 1;d.rotationEvents=d.rotationEvents or {};d.occurrenceExceptions=d.occurrenceExceptions or {}
        d.rotationFactions=d.rotationFactions or {"AD","EP","DC"};d.messageVariants=d.messageVariants or {}
        for _,field in ipairs({"start","event","end"}) do
            if not d[field.."Date"] or d[field.."Date"]=="" then
                local utc=d[field=="start" and "startsAtUtc" or field=="end" and "endsAtUtc" or "eventAtUtc"]
                if utc then
                    local t=self:GetScheduleParts(utc,d)
                    d[field.."Date"]=string.format("%04d-%02d-%02d",t.year,t.month,t.day)
                    d[field.."Time"]=string.format("%02d:%02d %s",t.hour%12==0 and 12 or t.hour%12,t.min,t.hour>=12 and "PM" or "AM")
                else d[field.."Date"],d[field.."Time"]=date,"08:00 PM" end
            end
        end
        -- Retain legacy exact start/end until the user changes promotion offsets.
        if not source then d.promotionDays,d.endDelayMinutes=1,60 end
        if not source then
            d.mode='EVENT';d.timelineVersion=1;d.importantTimes={};d.timelineUsage={}
            local messages={};for _,entry in ipairs(self:GetMessageEntriesForCommandAndGuild(id,guild) or {}) do messages[#messages+1]=entry.id end
            d.reminders={{id=self:GenerateUuid(),label='New period',start={kind='OFFSET',minutes=-60},finish={kind='OFFSET',minutes=0},intervalMinutes=15,lateMinutes=5,once=false,timeSensitive=false,messageIds=messages}}
        end
        self.scheduleEditor={key=key,source=source,draft=d}
    end
    return self.scheduleEditor.draft,id,guild
end

-- Preview contexts are explicit: never replace ESO's clock or stored settings.
function SmartChatMsg:GetMessagePreviewContext(entry,phase)
    local schedule=self:GetGuildSchedule(entry.commandId,entry.guildName)
    local selected=self.savedVars.selectedMessagesCommand==entry.commandId and self:GetSelectedGuildNameForMessages()==entry.guildName
    if selected and (schedule or self:GetGuildRunAt(entry.commandId,entry.guildName)=="SCHEDULED") then
        local reason
        schedule,reason=self:NormalizeSchedule(self:GetScheduleEditorDraft())
        if not schedule then return nil,reason end
    end
    if not schedule then
        if phase then return nil,"Configure the schedule's dates and times first." end
        return nil
    end
    -- Normal testing uses today's actual clock; phase testing pins one occurrence.
    local occurrence=self:GetScheduleOccurrence(schedule,GetTimeStamp()) or self:BuildScheduleOccurrence(schedule,schedule.eventAtUtc)
    if not occurrence then return nil,"No event occurrence is available to preview." end
    local context={schedule=schedule,occurrence=occurrence,now=GetTimeStamp(),phase=phase}
    if not phase then return context end
    local first,last=occurrence.startsAtUtc,occurrence.endsAtUtc
    if schedule.mode=="EVENT" then
        local event=occurrence.eventAtUtc
        local parts=self:GetScheduleParts(event,schedule)
        local midnight=self:ParseScheduleDateTime(string.format("%04d-%02d-%02d",parts.year,parts.month,parts.day),"12:00 AM",nil,schedule)
        local soon=schedule.startingSoonEnabled and event-schedule.startingSoonMinutes*60 or event
        if phase=="BEFORE" then
            last=math.min(midnight,soon)
            -- Prefer one calendar day before the event, handling DST correctly.
            -- UTC civil dates avoid depending on the player's computer timezone.
            local previous=os.date("!*t",event+self:GetTimeZoneUtcOffset(event,schedule.timeZone)*3600-86400)
            local preferred=self:ParseScheduleDateTime(string.format("%04d-%02d-%02d",previous.year,previous.month,previous.day),string.format("%02d:%02d %s",parts.hour%12==0 and 12 or parts.hour%12,parts.min,parts.hour>=12 and "PM" or "AM"),nil,schedule)
            context.now=math.max(first,math.min(preferred or first,last-1))
        elseif phase=="DAY" then first,last=math.max(first,midnight),math.min(soon,event)
        elseif phase=="SOON" then
            if not schedule.startingSoonEnabled then return nil,"Enable Starting soon to preview that phase." end
            first,last=math.max(first,soon),event
        elseif phase=="LIVE" then first=event
        else return nil,"Choose a valid event phase." end
    elseif phase~="ANY" then return nil,"This schedule has no event phases." end
    if first>=last then return nil,"That phase has no time in this promotion window. Adjust the timing to preview it." end
    if phase~="BEFORE" then context.now=first+math.floor((last-first)/2) end
    return context
end

function SmartChatMsg:TestMessagePreview(messageId,phase)
    local entry
    for _,item in ipairs(self.savedVars.messages or {}) do if item.id==messageId then entry=item;break end end
    if not entry then self:AddLocalChatMessage("[SmartChatMsg] Test unavailable: message no longer exists.");return nil end
    local context,reason=self:GetMessagePreviewContext(entry,phase)
    if reason then self:AddLocalChatMessage("[SmartChatMsg] Test unavailable: "..reason);return nil end
    local text=self.settings and self.settings.GetEffectiveMessageText and self.settings:GetEffectiveMessageText(entry) or entry.text
    local output=self:ApplyMessageSubstitutions(text,entry.commandId,entry.guildName,context)
    local labels={BEFORE="Before event day",DAY="Event day",SOON="Starting soon",LIVE="After event starts",ANY="While active"}
    local label=phase and labels[phase] or "Current time"
    local at=context and self:FormatScheduleDateTime(context.now,context.schedule) or self:FormatZonedDateTime(GetTimeStamp(),self:GetGuildSchedulingTimeZone(entry.guildName))
    self:AddLocalChatMessage("[SmartChatMsg] Message test — "..label.." — "..at)
    self:AddLocalChatMessage(output)
    return output,context
end

function SmartChatMsg:GetScheduleMessagePhaseText(messageId,schedule)
    if not schedule then return "" end
    if schedule.mode~="EVENT" then return "While active" end
    local assigned=schedule.messagePhases and schedule.messagePhases[messageId]
    local labels={BEFORE="Before event day",DAY="Event day",SOON="Starting soon",LIVE="After event starts"}
    local result={}
    for _,phase in ipairs({"BEFORE","DAY","SOON","LIVE"}) do
        if (not assigned or assigned.ANY or assigned[phase]) and (phase~="SOON" or schedule.startingSoonEnabled) then
            result[#result+1]=labels[phase]
        end
    end
    local text=#result>0 and table.concat(result," · ") or "Not selected for any phase"
    if schedule.specialPattern and schedule.specialPattern~="NONE" then
        local variant=self:GetScheduleMessageVariant(schedule,messageId)
        text=text.." · "..self:GetScheduleVariantLabel(variant,schedule.specialPattern,schedule)
        if schedule.specialPattern=="FACTION_ROTATION" and variant~="ALL" then
            local selected=false;for _,code in ipairs(schedule.rotationFactions or {}) do if code==variant then selected=true end end
            if not selected then text=text.." (not in rotation)" end
        end
    end
    return text
end

-- View-only stable sorting: a message belongs to its earliest enabled phase.
function SmartChatMsg:SortScheduledMessageEntries(entries,schedule)
    local decorated={}
    local function rank(entry)
        if not schedule then return 1 end
        local a=(schedule.messagePhases or {})[entry.id]
        if not a or a.ANY then return 1 end
        if schedule.mode~="EVENT" then return 5 end
        for i,phase in ipairs({"BEFORE","DAY","SOON","LIVE"}) do
            if a[phase] and (phase~="SOON" or schedule.startingSoonEnabled) then return i end
        end
        return 5
    end
    for i,entry in ipairs(entries) do decorated[i]={entry=entry,rank=rank(entry),index=i} end
    table.sort(decorated,function(a,b) return a.rank==b.rank and a.index<b.index or a.rank<b.rank end)
    local result={};for i,item in ipairs(decorated) do result[i]=item.entry end
    return result
end
function SmartChatMsg:CaptureMessageListScroll(container,positions)
    local viewport=container and container.scroll
    if not viewport or not viewport.GetScrollOffsets then return nil end
    local _,offset=viewport:GetScrollOffsets();if type(offset)~="number" then return nil end
    local snapshot={offset=offset}
    for _,row in ipairs(positions or {}) do
        if row.y+row.height>offset then snapshot.id=row.id;snapshot.delta=offset-row.y;break end
    end
    return snapshot
end
function SmartChatMsg:RestoreMessageListScroll(container,snapshot,positions)
    local viewport=container and container.scroll
    if not snapshot or not viewport or not viewport.GetScrollExtents or not viewport.SetVerticalScroll then return end
    local offset=snapshot.offset
    for _,row in ipairs(positions or {}) do if row.id==snapshot.id then offset=row.y+snapshot.delta;break end end
    local _,extent=viewport:GetScrollExtents()
    if type(extent)~="number" then return end
    viewport:SetVerticalScroll(math.max(0,math.min(offset,extent)))
    ZO_Scroll_UpdateScrollBar(container,true)
end

function SmartChatMsg:GetScheduleMessageChecklist(phase)
    local _,id,guild=self:GetScheduleEditorDraft()
    local result={}
    local schedule=self:GetScheduleEditorDraft()
    for _,entry in ipairs(self:SortScheduledMessageEntries(self:GetMessageEntriesForCommandAndGuild(id,guild),schedule)) do
        local messageId=entry.id
        local d=self:GetScheduleEditorDraft()
        local variantChoices=d.specialPattern=="MONTH_FINAL" and {"REGULAR","FINAL","ALL"} or nil
        if d.specialPattern=="FACTION_ROTATION" then
            variantChoices={"ALL"};local seen={}
            for i=1,3 do
                local code=d.rotationFactions[i]
                if code and code~="NONE" and not seen[code] then variantChoices[#variantChoices+1]=code;seen[code]=true end
            end
        end
        if d.specialPattern=='EVENT_ROTATION' then
            variantChoices={'ALL'};for _,activity in ipairs(d.rotationEvents or {}) do variantChoices[#variantChoices+1]=activity.id end
        end
        result[#result+1]={type="checkbox",name=(entry.name and entry.name..": " or "")..entry.text,messageId=messageId,
            variantChoices=variantChoices,variant=self:GetScheduleMessageVariant(d,messageId),
            setVariant=function(value)
                local current=self:GetScheduleEditorDraft();current.messageVariants[messageId]=value
                if self.scheduleEditor then self.scheduleEditor.dirty=true end
                self:RefreshSettingsUI()
            end,
            phaseText=(entry.locked==true and "Locked · " or "")..self:GetScheduleMessagePhaseText(messageId,self:GetScheduleEditorDraft()),
            getFunc=function()
                local a=self:GetScheduleEditorDraft().messagePhases[messageId]
                return a==nil or a[phase]==true or (phase~="ANY" and a.ANY==true)
            end,
            setFunc=function(v)
                local d=self:GetScheduleEditorDraft(); local a=d.messagePhases[messageId]
                if phase=="ANY" then a=a or {}; a.ANY=v
                else
                    if not a or a.ANY then a={BEFORE=true,DAY=true,LIVE=true,SOON=true} end
                    a[phase]=v
                end
                d.messagePhases[messageId]=a
                if self.scheduleEditor then self.scheduleEditor.dirty=true end
                self:RefreshSettingsUI()
            end}
    end
    return result
end

-- Each assigned phase is a separate link: clicking "Event day" must not
-- inherit the containing pool's "Before event day" preview clock.
function SmartChatMsg:RefreshSchedulePhaseLinks(row,text)
    local phases={["Before event day"]="BEFORE",["Event day"]="DAY",["Starting soon"]="SOON",["After event starts"]="LIVE",["While active"]="ANY"}
    if not row.phaseLinkContainer then
        row.phaseLinkContainer=WINDOW_MANAGER:CreateControl(nil,row,CT_CONTROL)
        row.phaseLinkContainer:SetAnchor(TOPLEFT,row.label,BOTTOMLEFT,0,4)
        row.phaseLinks={}
    end
    local container=row.phaseLinkContainer
    local width=row.label:GetWidth()
    container:SetWidth(width)
    local tags={"Used:"}
    for tag in (tostring(text or "").." · "):gmatch("(.-) · ") do tags[#tags+1]=tag end
    for _,link in ipairs(row.phaseLinks) do link:SetHidden(true) end
    local x,y,lineHeight=0,0,0
    for i,tag in ipairs(tags) do
        local link=row.phaseLinks[i]
        if not link then
            link=WINDOW_MANAGER:CreateControl(nil,container,CT_LABEL)
            link:SetFont("ZoFontGame")
            row.phaseLinks[i]=link
        end
        local phase=phases[tag]
        link.phase=phase
        link:SetText(tag)
        link:SetWidth(width);link:SetHeight(10000)
        local textWidth=link.GetTextWidth and link:GetTextWidth() or #tag*8
        local linkWidth=math.min(width,math.max(24,textWidth+2))
        link:SetWidth(linkWidth)
        local height=math.max(20,link:GetTextHeight())
        link:SetHeight(height)
        if x>0 and x+linkWidth>width then x=0;y=y+lineHeight+4;lineHeight=0 end
        link:ClearAnchors();link:SetAnchor(TOPLEFT,container,TOPLEFT,x,y)
        link:SetHidden(false);link:SetMouseEnabled(phase~=nil)
        link:SetColor(phase and 0.95 or 0.77,phase and 0.82 or 0.76,phase and 0.45 or 0.62,1)
        link:SetHandler("OnMouseUp",phase and function(_,button,upInside)
            if button==MOUSE_BUTTON_INDEX_LEFT and upInside then self:TestMessagePreview(row.messageId,phase) end
        end or nil)
        link:SetHandler("OnMouseEnter",phase and function(label)
            InitializeTooltip(InformationTooltip,label,TOP,0,8)
            SetTooltipText(InformationTooltip,"Test this message during "..tag.." using a simulated time inside that phase.")
        end or nil)
        link:SetHandler("OnMouseExit",phase and function() ClearTooltip(InformationTooltip) end or nil)
        link:SetHandler("OnMouseWheel",function(_,delta) ZO_Scroll_OnMouseWheel(row.scheduleScroll,delta) end)
        x=x+linkWidth+8;lineHeight=math.max(lineHeight,height)
    end
    local height=y+lineHeight
    container:SetHeight(height)
    return height
end

-- Native LAM custom rows update with selection and newly added/deleted messages.
function SmartChatMsg:RefreshScheduleMessagePool(control,phase)
    if control.scheduleRefreshing then return end
    control.scheduleRefreshing=true
    local viewportHeight=230
    local width=control:GetWidth()
    -- Collapsed submenus can initially report no width; remeasure when shown.
    if not width or width<100 then width=520 end
    if not control.scheduleScroll then
        self.schedulePoolControlSerial=(self.schedulePoolControlSerial or 0)+1
        local name="SCM_ScheduleMessagePool"..self.schedulePoolControlSerial
        control.schedulePoolName=name
        local scroll=WINDOW_MANAGER:CreateControlFromVirtual(name,control,"ZO_ScrollContainer")
        scroll:SetAnchor(TOPLEFT,control,TOPLEFT,0,0)
        scroll:SetHeight(viewportHeight)
        control.scheduleScroll=scroll
        control.scheduleContent=scroll:GetNamedChild("Scroll"):GetNamedChild("Child")
        control.scheduleContent:SetResizeToFitDescendents(false)
        control.scheduleRows={}
        control:SetHandler("OnEffectivelyShown",function() self:RefreshScheduleMessagePool(control,phase) end)
        control:SetHandler("OnRectWidthChanged",function() self:RefreshScheduleMessagePool(control,phase) end)
    end
    local scroll,content=control.scheduleScroll,control.scheduleContent
    local scrollSnapshot=self:CaptureMessageListScroll(scroll,control.scheduleRowPositions)
    local positions={}
    scroll:SetWidth(width)
    local contentWidth=math.max(80,width-(ZO_SCROLL_BAR_WIDTH or 16)-8)
    local viewportWidth=scroll:GetNamedChild("Scroll"):GetWidth()
    if viewportWidth and viewportWidth>80 then contentWidth=math.min(contentWidth,viewportWidth-8) end
    content:SetWidth(contentWidth)
    local choices=self:GetScheduleMessageChecklist(phase)
    for _,row in ipairs(control.scheduleRows) do row:SetHidden(true) end
    local y=0
    for i,choice in ipairs(choices) do
        local row=control.scheduleRows[i]
        if not row then
            local name=control.schedulePoolName.."Row"..i
            row=WINDOW_MANAGER:CreateControl(name,content,CT_CONTROL)
            row.scheduleControlName=name
            row.backdrop=WINDOW_MANAGER:CreateControlFromVirtual(name.."Backdrop",row,"ZO_DefaultBackdrop")
            row.backdrop:SetAnchorFill(row)
            row.backdrop:SetCenterColor(0,0,0,0.25)
            row.backdrop:SetEdgeColor(0.45,0.43,0.30,0.7)
            row.check=WINDOW_MANAGER:CreateControlFromVirtual(name.."Check",row,"ZO_CheckButton")
            row.check:SetAnchor(TOPLEFT,row,TOPLEFT,6,6)
            row.label=WINDOW_MANAGER:CreateControl(name.."Label",row,CT_LABEL)
            row.label:SetFont("ZoFontGame")
            row.label:SetAnchor(TOPLEFT,row,TOPLEFT,40,6)
            row.label:SetMouseEnabled(true)
            local function wheel(_,delta) ZO_Scroll_OnMouseWheel(scroll,delta) end
            row:SetMouseEnabled(true)
            row:SetHandler("OnMouseWheel",wheel)
            row.check:SetHandler("OnMouseWheel",wheel)
            row.label:SetHandler("OnMouseWheel",wheel)
            control.scheduleRows[i]=row
        end
        row.label:SetHandler("OnMouseUp",function(_,button,upInside)
            if button==MOUSE_BUTTON_INDEX_LEFT and upInside then self:TestMessagePreview(choice.messageId,phase) end
        end)
        row.label:SetHandler("OnMouseEnter",function(label)
            label:SetColor(1,0.85,0.35,1)
            InitializeTooltip(InformationTooltip,label,TOP,0,8)
            SetTooltipText(InformationTooltip,"Click to test this message in local chat using this phase's simulated time. The checkbox controls whether it is used.")
        end)
        row.label:SetHandler("OnMouseExit",function(label) label:SetColor(1,1,1,1);ClearTooltip(InformationTooltip) end)
        row.messageId=choice.messageId
        row.scheduleScroll=scroll
        row:SetWidth(contentWidth)
        row.label:SetWidth(math.max(40,contentWidth-50))
        row:SetHidden(false); row:ClearAnchors(); row:SetAnchor(TOPLEFT,content,TOPLEFT,0,y)
        -- Clear the old height before measuring a new wrapped message/width.
        row.label:SetHeight(10000)
        row.label:SetText(choice.name or "")
        local height=math.max(32,row.label:GetTextHeight()+12)
        row.label:SetHeight(height-12)
        height=height+4+self:RefreshSchedulePhaseLinks(row,choice.phaseText)
        if choice.variantChoices and choice.variantChoices[1]=="REGULAR" then
            if not row.variantButton then
                row.variantButton=WINDOW_MANAGER:CreateControlFromVirtual(row.scheduleControlName.."VariantButton",row,"ZO_DefaultButton")
                row.variantButton:SetHeight(31)
            end
            row.variantButton:SetHidden(false);row.variantButton:ClearAnchors()
            row.variantButton:SetAnchor(TOPLEFT,row.phaseLinkContainer,BOTTOMLEFT,0,4)
            row.variantButton:SetWidth(math.max(100,contentWidth-50))
            row.variantButton:SetText("Group: "..self:GetScheduleVariantLabel(choice.variant,"MONTH_FINAL"))
            row.variantButton:SetHandler("OnClicked",function()
                local nextVariant={REGULAR="FINAL",FINAL="ALL",ALL="REGULAR"}
                choice.setVariant(nextVariant[choice.variant] or "REGULAR")
            end)
            if row.variantControl then row.variantControl:SetHidden(true) end
            height=height+42
        elseif choice.variantChoices then
            if row.variantButton then row.variantButton:SetHidden(true) end
            if not row.variantControl then
                row.variantControl=WINDOW_MANAGER:CreateControlFromVirtual(row.scheduleControlName.."Variant",row,"ZO_ComboBox")
                row.variantControl:SetHeight(31)
                row.variantCombo=ZO_ComboBox_ObjectFromContainer(row.variantControl)
                row.variantCombo:SetSortsItems(false)
                row.variantControl:SetHandler("OnMouseWheel",function(_,delta) ZO_Scroll_OnMouseWheel(scroll,delta) end)
            end
            row.variantControl:SetHidden(false);row.variantControl:ClearAnchors()
            row.variantControl:SetAnchor(TOPLEFT,row.phaseLinkContainer,BOTTOMLEFT,0,4)
            row.variantControl:SetWidth(math.max(100,contentWidth-50))
            row.variantCombo:ClearItems()
            for _,value in ipairs(choice.variantChoices) do
                local variant=value
                row.variantCombo:AddItem(row.variantCombo:CreateItemEntry(self:GetScheduleVariantLabel(value,self:GetScheduleEditorDraft().specialPattern,self:GetScheduleEditorDraft()),function() choice.setVariant(variant) end))
            end
            row.variantCombo:SetSelectedItem(self:GetScheduleVariantLabel(choice.variant,self:GetScheduleEditorDraft().specialPattern,self:GetScheduleEditorDraft()))
            height=height+42
        else
            if row.variantControl then row.variantControl:SetHidden(true) end
            if row.variantButton then row.variantButton:SetHidden(true) end
        end
        row:SetHeight(height);positions[#positions+1]={id=choice.messageId,y=y,height=height}; y=y+height+6
        ZO_CheckButton_SetCheckState(row.check,choice.getFunc())
        ZO_CheckButton_SetToggleFunction(row.check,function(button) choice.setFunc(ZO_CheckButton_IsChecked(button)) end)
    end
    content:SetHeight(math.max(1,y))
    control:SetHeight(viewportHeight)
    local _,id,guild=self:GetScheduleEditorDraft()
    local key=tostring(id)..":"..tostring(guild)..":"..phase
    if control.scheduleSelectionKey~=key then
        ZO_Scroll_ResetToTop(scroll)
        control.scheduleSelectionKey=key
    else
        self:RestoreMessageListScroll(scroll,scrollSnapshot,positions)
    end
    control.scheduleRowPositions=positions
    ZO_Scroll_UpdateScrollBar(scroll)
    control.scheduleRefreshing=false
end

function SmartChatMsg:RefreshRotationEditorChoices()
    for reference,provider in pairs(self.rotationEditorChoiceProviders or {}) do
        local control=_G[reference]
        if control and control.UpdateChoices then control:UpdateChoices(provider()) end
    end
end
function SmartChatMsg:BuildScheduleOptionControls()
    local function draft() return self:GetScheduleEditorDraft() end
    local function refresh() if self.scheduleEditor then self.scheduleEditor.dirty=true end; self:RefreshSettingsUI() end
    local function selected() local _,id,guild=draft(); return self:GetCommandById(id) and self:GetGuildSlotByName(guild) end
    local function number(name,key,tooltip)
        return {type="editbox",name=name,tooltip=tooltip,getFunc=function()
            local d=draft(); local value=d[key]
            if value==nil and key=="promotionDays" and d.eventAtUtc and d.startsAtUtc then value=math.ceil(math.max(0,(d.eventAtUtc-d.startsAtUtc)/86400)) end
            if value==nil and key=="endDelayMinutes" and d.endsAtUtc and d.eventAtUtc then value=math.max(0,(d.endsAtUtc-d.eventAtUtc)/60) end
            return tostring(value or "")
        end,setFunc=function(v)
            local d=draft(); d[key]=v
            if key=="recurrenceInterval" and v=="" then d[key]=nil end
            if key=="endDelayMinutes" and d.promotionDays==nil then d.promotionDays=math.ceil(math.max(0,((d.eventAtUtc or 0)-(d.startsAtUtc or 0))/86400)) end
            if key=="promotionDays" and d.endDelayMinutes==nil then d.endDelayMinutes=d.endsAtUtc and d.eventAtUtc and math.max(0,(d.endsAtUtc-d.eventAtUtc)/60) or 60 end
            refresh()
        end}
    end
    local modeLabels={"Run during a window","Remind me at set times","Promote an event"}
    local modeValues={"WINDOW","REMINDER","EVENT"}
    local repeatLabels={"Does not repeat","Every day","Every week","Every other week","Same day each month","Monthly on weekday"}
    local repeatValues={"NONE","DAILY","WEEKLY","BIWEEKLY","MONTHLY_DATE","MONTHLY_WEEKDAY"}
    local function label(values,labels,value) for i,v in ipairs(values) do if v==value then return labels[i] end end; return labels[1] end
    local function dropdown(name,labels,values,key)
        return {type="dropdown",name=name,choices=labels,getFunc=function() return label(values,labels,draft()[key]) end,
            setFunc=function(v)
                for i,text in ipairs(labels) do if text==v then
                    draft()[key]=values[i]
                    if key=='specialPattern' and values[i]=='EVENT_ROTATION' then
                        local ids={ALL=true};for _,a in ipairs(draft().rotationEvents or {}) do ids[a.id]=true end
                        for id,group in pairs(draft().messageVariants or {}) do if not ids[group] then draft().messageVariants[id]='ALL' end end
                    end
                    if (key=="mode" and values[i]~="EVENT") or (key=="recurrence" and values[i]=="NONE") then draft().specialPattern="NONE" end
                    break
                end end
                refresh()
            end}
    end
    local function dateTime(field,title)
        local hours,minutes={},{}
        for i=1,12 do hours[#hours+1]=string.format("%02d",i) end
        for i=0,59 do minutes[#minutes+1]=string.format("%02d",i) end
        local function parts()
            local h,m,a=tostring(draft()[field.."Time"] or ""):match("^(%d%d?):(%d%d)%s+([AP]M)$")
            return h and string.format("%02d",tonumber(h)) or "08",m or "00",a or "PM"
        end
        local result={{type="datepicker",name=function() return title.." date ("..draft().timeZone..")" end,datePickerType="normal",tooltip="Calendar date in this guild's scheduling timezone; select the time separately.",
            getFunc=function() return self:ScheduleDateToPicker(draft()[field.."Date"]) end,
            setFunc=function(v) draft()[field.."Date"]=self:ScheduleDateFromPicker(v); refresh() end}}
        for i,entry in ipairs({{"hour",hours},{"minute",minutes},{"AM / PM",{"AM","PM"}}}) do
            local index=i
            result[#result+1]={type="dropdown",name=title.." "..entry[1],choices=entry[2],
                getFunc=function() local h,m,a=parts(); return ({h,m,a})[index] end,
                setFunc=function(v) local h,m,a=parts(); local p={h,m,a}; p[index]=v; draft()[field.."Time"]=p[1]..":"..p[2].." "..p[3]; refresh() end}
        end
        return result
    end
    local function append(target,source) for _,v in ipairs(source) do target[#target+1]=v end end
    local controls={
        {type="description",text=function() return "Uses the command, guild and output channel selected above. All times are "..self:GetSchedulingTimeZoneName(draft().timeZone).." Time ("..draft().timeZone.."). Save and activate starts automatically while you are online. Press Enter to send each prepared message." end},
        {type="description",text=function() local _,id,guild=draft(); local command=self:GetCommandById(id); local channel=self.GetSelectedMessagesChannel and self:GetSelectedMessagesChannel() or ""; return (command and command.name or "No command").." / "..tostring(guild or "No guild").." / "..tostring(channel).."\n"..self:GetScheduleStatusText(id,guild)..(self.scheduleEditor and self.scheduleEditor.dirty and "\nUnsaved changes — review and save below." or "") end},
        {type="description",text="Advanced scheduling configuration is available at https://scm.perdues.me. Open your SmartChatMsg SavedVariables file in the web editor, then download the updated file to use in ESO. You can also configure schedules here in the addon."},
        {type="dropdown",name="Guild timezone",choices={"Use global default","Eastern (ET)","Central (CT)","Mountain (MT)","Pacific (PT)"},
            tooltip="Default timezone for ALL schedules in the selected guild, across commands. Use global default follows Global Settings. Changing it keeps each existing schedule's date and clock time and moves it to the new zone.",
            getFunc=function()
                local _,_,guild=draft();local zone=self:GetGuildSchedulingTimeZoneOverride(guild)
                return zone=="GLOBAL" and "Use global default" or self:GetSchedulingTimeZoneName(zone).." ("..zone..")"
            end,
            setFunc=function(value)
                local _,_,guild=draft();local zone=value=="Use global default" and "GLOBAL" or value:match("%((%u%u)%)")
                local ok,reason=self:SetGuildSchedulingTimeZone(guild,zone)
                if not ok then ZO_Alert(UI_ALERT_CATEGORY_ERROR,SOUNDS.NEGATIVE_CLICK,reason) end
            end},
        dropdown("Schedule type",modeLabels,modeValues,"mode"),
    }
    -- LAM has no hidden callback. Its supported disabled callback automatically
    -- closes submenus, keeping irrelevant fields out of the expanded form.
    local window=dateTime("start","Start"); append(window,dateTime("end","End"))
    local reminder=dateTime("start","Reminder")
    reminder[#reminder+1]={type="description",text="Prepares one message per occurrence while online. Missed reminders are skipped; there is a two-minute grace period."}
    local event=dateTime("event","Event")
    event[#event+1]=number("Start promoting (days before event)","promotionDays","0 starts at midnight in your scheduling timezone on event day. Positive values start that many days before the event at its clock time.")
    event[#event+1]={type="description",reference="SCM_PromotionStartNote",text=function()
        local schedule,reason=self:NormalizeSchedule(draft())
        local occurrence=schedule and self:GetUpcomingScheduleOccurrences(schedule,GetTimeStamp(),1,true)[1]
        local starts=occurrence and self:FormatScheduleDateTime(occurrence.startsAtUtc,occurrence) or (schedule and "None scheduled." or tostring(reason))
        return "0 = midnight on event day. 1+ = that many days earlier at the event's time.\nPromotion starts: "..starts
    end}
    event[#event+1]={type="checkbox",name="Enable Starting soon phase",tooltip="Use a separate message pool and interval during the final minutes before the event.",getFunc=function() return draft().startingSoonEnabled==true end,setFunc=function(v) draft().startingSoonEnabled=v;refresh() end}
    local soonLead=number("Starting soon begins (minutes before event)","startingSoonMinutes","120 means two hours before the event. This phase ends at the event start and stays within the promotion window.")
    soonLead.disabled=function() return not draft().startingSoonEnabled end
    event[#event+1]=soonLead
    for _,entry in ipairs({{"WINDOW",window},{"REMINDER",reminder},{"EVENT",event}}) do
        local mode=entry[1]
        controls[#controls+1]={type="submenu",reference=({WINDOW="SCM_WindowTimingSubmenu",REMINDER="SCM_ReminderTimingSubmenu",EVENT="SCM_EventTimingSubmenu"})[mode],name=({WINDOW="Window dates and times",REMINDER="First reminder date and time",EVENT="Event and promotion timing"})[mode],controls=entry[2],disabled=function() return draft().mode~=mode end}
    end
    controls[#controls+1]=dropdown("Repeat schedule",repeatLabels,repeatValues,"recurrence")
    local monthly={
        {type='description',text='Choose an ordinal and weekday. Last occurs every month; Fifth skips months with only four of that weekday. The original event date anchors the starting month and earliest eligible date. Custom repeat interval counts months.'},
        {type='dropdown',name='Monthly on',choices={'First','Second','Third','Fourth','Fifth','Last'},getFunc=function()
            local d=draft();local week=d.monthlyWeek
            if not week then local normalized=self:NormalizeSchedule(d);week=normalized and normalized.monthlyWeek end
            return ({[1]='First',[2]='Second',[3]='Third',[4]='Fourth',[5]='Fifth',LAST='Last'})[week] or 'First'
        end,setFunc=function(value)
            local values={First=1,Second=2,Third=3,Fourth=4,Fifth=5,Last='LAST'};draft().monthlyWeek=values[value];refresh()
        end},
        {type='dropdown',name='Weekday',choices={'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'},getFunc=function()
            local d=draft();local weekday=d.monthlyWeekday
            if not weekday then local normalized=self:NormalizeSchedule(d);weekday=normalized and normalized.monthlyWeekday end
            return ({'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'})[weekday] or 'Sunday'
        end,setFunc=function(value)
            for day,name in ipairs({'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'}) do if value==name then draft().monthlyWeekday=day;break end end;refresh()
        end},
    }
    controls[#controls+1]={type='submenu',reference='SCM_MonthlyWeekdaySubmenu',name='Monthly weekday',controls=monthly,disabled=function() return draft().recurrence~='MONTHLY_WEEKDAY' end}
    local pattern=dropdown("Special event pattern",{"None","Faction rotation","Rotating event","Last event of month"},{"NONE","FACTION_ROTATION","EVENT_ROTATION","MONTH_FINAL"},"specialPattern")
    pattern.disabled=function() return draft().mode~="EVENT" or draft().recurrence=="NONE" end
    controls[#controls+1]=pattern
    local rotation={
        {type="description",text="The Event date under Event and promotion timing anchors the first faction's block. The order repeats automatically, including weeks you are offline. Use %eventfaction% in message text to show the proper full faction name for each event."},
        number("Faction frequency (weeks)","rotationWeeks","Each selected faction runs for this many calendar weeks. Total cycle = frequency × selected factions."),
    }
    for i,title in ipairs({"First faction","Second faction","Third faction"}) do
        local index=i
        rotation[#rotation+1]={type="dropdown",name=title,choices=index==1 and {"Aldmeri Dominion","Ebonheart Pact","Daggerfall Covenant"} or {"Not used","Aldmeri Dominion","Ebonheart Pact","Daggerfall Covenant"},
            getFunc=function() local code=draft().rotationFactions[index];return code and code~="NONE" and self:GetScheduleVariantLabel(code) or "Not used" end,
            setFunc=function(value)
                if value=="Not used" then draft().rotationFactions[index]="NONE";refresh();return end
                for _,code in ipairs({"AD","EP","DC"}) do if self:GetScheduleVariantLabel(code)==value then draft().rotationFactions[index]=code;refresh();break end end
            end}
    end
    rotation[#rotation+1]={type="description",text=function()
        local schedule=self:NormalizeSchedule(draft())
        if not schedule then return "Choose your factions and frequency to calculate the complete cycle." end
        return string.format("Complete rotation: %d weeks (%d weeks × %d factions).",schedule.rotationWeeks*#schedule.rotationFactions,schedule.rotationWeeks,#schedule.rotationFactions)
    end}
    controls[#controls+1]={type="submenu",reference="SCM_FactionRotationSubmenu",name="Faction rotation",controls=rotation,disabled=function() return draft().specialPattern~="FACTION_ROTATION" or draft().mode~="EVENT" end}
    local activities={
        {type='description',text='Activities repeat in this order, counting scheduled occurrences from the Event date, including while offline. Use %eventactivity% in messages. Names may repeat; activity IDs stay stable when you rename or reorder an activity.'},
        number('Occurrences per activity','rotationEvery','Run each activity for 1 to 1000 scheduled occurrences before advancing.'),
        {type='editbox',name='New activity name',getFunc=function() return self.pendingRotationActivityName or '' end,setFunc=function(v) self.pendingRotationActivityName=v end},
        {type='button',name='Add activity',func=function()
            local d=draft();local name=self:Trim(self.pendingRotationActivityName or '')
            if #name<1 or (select(2,name:gsub('[^\128-\191]','')))>80 or #d.rotationEvents>=50 then self:ShowStatusMessage('Enter an activity name from 1 to 80 characters; maximum 50 activities.');return end
            self.rotationActivityIdHistory=self.rotationActivityIdHistory or {}
            local ids=self.rotationActivityIdHistory;for _,a in ipairs(d.rotationEvents) do ids[a.id]=true end
            local base=self:GenerateUuid();local id=base;local suffix=1
            while ids[id] do suffix=suffix+1;id=base..'-'..suffix end
            ids[id]=true
            d.rotationEvents[#d.rotationEvents+1]={id=id,name=name};self.pendingRotationActivityName='';refresh()
        end},
    }
    local function activityIndex() return math.min(self.selectedRotationActivityIndex or 1,#draft().rotationEvents) end
    local function activityChoices()
        local out={};for i,a in ipairs(draft().rotationEvents) do out[#out+1]=i..'. '..a.name end;return out
    end
    self.rotationEditorChoiceProviders={SCM_SelectedRotationActivity=activityChoices}
    activities[#activities+1]={type='dropdown',reference='SCM_SelectedRotationActivity',name='Selected activity',choices=activityChoices(),getFunc=function() local i=activityIndex();local a=draft().rotationEvents[i];return a and i..'. '..a.name or '' end,
    setFunc=function(v) self.selectedRotationActivityIndex=tonumber(v:match('^(%d+)'));refresh() end}
    activities[#activities+1]={type='editbox',name='Activity name',getFunc=function() local a=draft().rotationEvents[activityIndex()];return a and a.name or '' end,
    setFunc=function(v) local a=draft().rotationEvents[activityIndex()];if a then a.name=v;refresh() end end}
    for _,entry in ipairs({{'Move activity up',-1},{'Move activity down',1}}) do
        local delta=entry[2];activities[#activities+1]={type='button',name=entry[1],func=function()
            local list=draft().rotationEvents;local i=activityIndex();local j=i+delta
            if list[i] and list[j] then list[i],list[j]=list[j],list[i];self.selectedRotationActivityIndex=j;refresh() end
        end}
    end
    activities[#activities+1]={type='button',name='Remove activity',func=function()
        local d=draft();local i=activityIndex();local a=d.rotationEvents[i];if not a then return end
        for _,variant in pairs(d.messageVariants) do if variant==a.id then self:ShowStatusMessage('Assign this activity’s messages to another group before removing it.');return end end
        table.remove(d.rotationEvents,i);refresh()
    end}
    controls[#controls+1]={type='submenu',reference='SCM_EventRotationSubmenu',name='Rotating event',controls=activities,disabled=function() return draft().specialPattern~='EVENT_ROTATION' or draft().mode~='EVENT' end}
    local function cancellationRows()
        local normalized=self:NormalizeSchedule(draft());return normalized and self:GetNominalScheduleOccurrences(normalized,GetTimeStamp(),12) or {},normalized
    end
    local function cancellationChoices()
        local rows,config=cancellationRows();local choices,seen={},{}
        for _,o in ipairs(rows) do
            local date=self:GetScheduleOccurrenceDate(config,o.eventAtUtc)
            seen[date]=true
            choices[#choices+1]=date..' — '..self:GetScheduleVariantLabel(self:GetScheduleEventVariant(config,o.eventAtUtc),config.specialPattern,config)..(o.cancelled and ' (cancelled: '..o.exceptionAction..')' or '')
        end
        local saved={};for date,value in pairs(draft().occurrenceExceptions or {}) do if not seen[date] then saved[#saved+1]=date..' (cancelled: '..value.action..')' end end;table.sort(saved)
        for _,label in ipairs(saved) do choices[#choices+1]=label end
        return choices
    end
    local function cancellationSelection()
        local choices=cancellationChoices();for _,label in ipairs(choices) do if label:sub(1,10)==self.selectedCancellationDate then return label end end
        return choices[1] or ''
    end
    self.rotationEditorChoiceProviders.SCM_SelectedCancellationOccurrence=cancellationChoices
    local cancellations={
        {type='description',text='Cancel a date with Keep rotation to advance normally, or Postpone rotation to hold that slot. Faction postponement holds the calendar span to the next nominal occurrence. Undo removes the cancellation. Changes take effect when you save the schedule.'},
        {type='description',text=function() return table.concat(cancellationChoices(),'\n') end},
        {type='dropdown',reference='SCM_SelectedCancellationOccurrence',name='Occurrence to cancel or undo',choices=cancellationChoices(),getFunc=cancellationSelection,setFunc=function(v) self.selectedCancellationDate=v:sub(1,10);refresh() end},
        {type='dropdown',name='Cancellation rotation',choices={'Keep rotation','Postpone rotation'},getFunc=function() return self.pendingCancellationAction=='POSTPONE' and 'Postpone rotation' or 'Keep rotation' end,
        setFunc=function(v) self.pendingCancellationAction=v=='Postpone rotation' and 'POSTPONE' or 'KEEP' end},
        {type='button',name='Cancel selected occurrence',func=function()
            local selected=cancellationSelection():sub(1,10);if selected=='' then return end
            if selected then draft().occurrenceExceptions[selected]={action=self.pendingCancellationAction or 'KEEP'};refresh() end
        end},
        {type='button',name='Undo selected cancellation',func=function()
            local selected=cancellationSelection():sub(1,10);if selected=='' then return end
            if selected then draft().occurrenceExceptions[selected]=nil;refresh() end
        end},
        {type='description',text=function()
            local dates={};for date,value in pairs(draft().occurrenceExceptions) do dates[#dates+1]=date..' ('..value.action..')' end;table.sort(dates)
            return #dates>0 and 'Saved cancellations: '..table.concat(dates,', ') or 'No cancellations.'
        end},
        {type='editbox',name='Earlier cancellation date (YYYY-MM-DD)',getFunc=function() return self.earlierCancellationDate or '' end,setFunc=function(v) self.earlierCancellationDate=v end},
        {type='button',name='Undo earlier cancellation',func=function() draft().occurrenceExceptions[self.earlierCancellationDate or '']=nil;refresh() end},
    }
    controls[#controls+1]={type='submenu',reference='SCM_OccurrenceCancellationSubmenu',name='Occurrence cancellations',controls=cancellations,disabled=function() return next(draft().occurrenceExceptions or {})==nil and (draft().mode~='EVENT' or (draft().specialPattern~='EVENT_ROTATION' and draft().specialPattern~='FACTION_ROTATION')) end}
    controls[#controls+1]={type="description",text=function()
        local d=draft()
        if d.specialPattern=='EVENT_ROTATION' then return 'Choose All activities or an activity in each message row. Use %eventactivity% for its name.' end
        if d.specialPattern=="FACTION_ROTATION" then return "In each message row, choose All selected factions or a faction. Keep using the phase checkboxes for when it runs." end
        if d.specialPattern=="MONTH_FINAL" then return "Works with any repeating event schedule. Unmarked messages use Regular events. Click the Group button beneath a message to cycle through Regular events, Month-final events, and All events. All events messages are eligible for both kinds of occurrence, within their selected phases. The last scheduled event in each month uses the month-final pool throughout promotion. If none are marked month-final, regular messages are used instead, together with All events messages." end
        return "Special patterns are optional. Message group choices appear in each phase's message list when enabled."
    end}
    controls[#controls+1]={type="description",reference="SCM_NextScheduleOccurrence",text=function() return self:GetNextScheduleOccurrenceText(draft()) end}
    controls[#controls+1]={type="description",text="For repeating schedules, the original date anchors the repeat pattern. The next date is calculated automatically."}
    local repeats={number("Custom repeat interval (optional)","recurrenceInterval",
        "Controls recurrence of the entire schedule, not chat frequency. Blank or 1 uses your Repeat schedule. Daily: days; Weekly: weeks; Every other week: two-week blocks; Monthly: months. Weekly + 2 = every two weeks; Every other week + 2 = every four weeks.")}
    repeats[1].disabled=function() return draft().recurrence=="NONE" end
    repeats[#repeats+1]={type="description",text="Repeat on weekdays is optional. With none selected, Weekly and Every other week use the original event weekday. Selecting days adds occurrences on those days within eligible weeks. Daily schedules still honor their interval and only run on selected days."}
    local weekdays={}
    for i,name in ipairs({"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"}) do
        local day=i
        weekdays[#weekdays+1]={type="checkbox",name=name,getFunc=function() return draft().weekdays[day]==true end,setFunc=function(v) draft().weekdays[day]=v; refresh() end}
    end
    repeats[#repeats+1]={type="submenu",reference="SCM_RepeatWeekdaysSubmenu",name="Repeat on weekdays (optional)",controls=weekdays,disabled=function()
        local r=draft().recurrence; return r~="DAILY" and r~="WEEKLY" and r~="BIWEEKLY"
    end}
    controls[#controls+1]={type="submenu",reference="SCM_RepeatOptionsSubmenu",name="More repeat options",controls=repeats}
    controls[#controls+1]={type="submenu",reference="SCM_MessageDeliverySubmenu",name="Message delivery",controls={dropdown("Delivery",{"Repeat while active","On zone arrival"},{"REPEAT","ZONE"},"delivery"),number("Message interval (minutes)","intervalMinutes")},disabled=function() return draft().mode=="REMINDER" end}
    controls[#controls+1]={type="description",text=function()
        if draft().mode~="EVENT" then return "Choose several messages to select one at random." end
        return "Choose messages for each part of promotion; one eligible message is selected at random. Click message text to test this phase, or a Used phase name to test that named phase. Event-day promotion starts at midnight in your scheduling timezone; live promotion starts at the event time.\n\n%eventdate%, %eventtime%, and %eventwhen% use the scheduled occurrence. %eventcountdown% shows time remaining. Faction rotation can use %eventfaction%.\n\nAdd whole-number offsets to eventtime or eventcountdown: -30m, -2h, -1d, or +30m (minutes, hours, days). For example, %eventtime-1h% is one hour before the event; %eventcountdown-1h% counts down to that deadline. Offsets are elapsed time: -1d is 24 hours.\n\nExample: Raffle at %eventtime% (%eventcountdown%). Sales close at %eventtime-1h% (%eventcountdown-1h%).\n\nExplicit countdown tokens prevent automatic countdown insertion for the whole message. Add parentheses yourself. A countdown can show soon, now, or passed."
    end}
    local phaseLabels={ANY="Messages",BEFORE="Before event day",DAY="On event day",SOON="Starting soon",LIVE="After event starts"}
    local onceLabels={BEFORE="Prepare only once before event day",DAY="Prepare only once on event day",SOON="Prepare only once during Starting soon",LIVE="Prepare only once after event starts"}
    for _,name in ipairs({"ANY","BEFORE","DAY","SOON","LIVE"}) do
        local phase=name
        local pool={}
        if phase=="LIVE" then
            pool[#pool+1]=number("Promote after start (minutes)","endDelayMinutes","0 stops promotion exactly when the event starts. A positive number keeps these messages eligible for that many minutes afterward.")
            pool[#pool+1]={type="description",text="Use these messages after the event has started, while people can still join. Set 0 to stop at the event start; for example, 120 continues for two hours. The interval below controls how often a message is prepared during that time."}
        end
        pool[#pool+1]={type="custom",minHeight=230,maxHeight=230,createFunc=function(control) self:RefreshScheduleMessagePool(control,phase) end,refreshFunc=function(control) self:RefreshScheduleMessagePool(control,phase) end}
        pool[#pool+1]={type="description",text=function()
            local count=0; for _,choice in ipairs(self:GetScheduleMessageChecklist(phase)) do if choice.getFunc() then count=count+1 end end
            local d=draft(); local interval=d.phaseIntervals[phase] or d.intervalMinutes
            if phase=="LIVE" and tonumber(d.endDelayMinutes)==0 then return "Post-start promotion is off: stops at the event start. Message selections are saved." end
            return tostring(count).." messages selected · "..((d.mode=="REMINDER" or d.phaseOnce[phase]) and "Prepare once" or d.delivery=="ZONE" and "On zone arrival" or "Every "..tostring(interval).." minutes")
        end}
        if phase~="ANY" then
            pool[#pool+1]={type="editbox",name="Message interval override (optional)",getFunc=function() return tostring(draft().phaseIntervals[phase] or "") end,setFunc=function(v) draft().phaseIntervals[phase]=v; refresh() end}
            pool[#pool+1]={type="checkbox",name=onceLabels[phase],tooltip="One randomly selected announcement for this phase per event occurrence. After a confirmed send (or a matching announcement from another player), this phase is complete even if its interval comes around again. An unsent message may retry while the phase remains active. The next event starts fresh.",getFunc=function() return draft().phaseOnce[phase]==true end,setFunc=function(v) draft().phaseOnce[phase]=v; refresh() end}
        end
        controls[#controls+1]={type="submenu",reference="SCM_Phase"..phase.."Submenu",name=phaseLabels[phase],controls=pool,disabled=function() return (phase=="ANY")==(draft().mode=="EVENT") or (phase=="SOON" and not draft().startingSoonEnabled) end}
    end
    controls[#controls+1]={type="description",text=function()
        local normalized,reason=self:NormalizeSchedule(draft())
        if not normalized then return "Preview: "..tostring(reason) end
        if not self.GetUpcomingScheduleOccurrences then return "Preview unavailable." end
        local upcoming=self:GetUpcomingScheduleOccurrences(normalized,GetTimeStamp(),3)
        local lines={"Review your schedule ("..draft().timeZone.."):"}
        local occurrence=upcoming and upcoming[1]
        if occurrence then
            lines[#lines+1]="Starts: "..self:FormatScheduleDateTime(occurrence.startsAtUtc,occurrence)
            lines[#lines+1]="Stops: "..self:FormatScheduleDateTime(occurrence.endsAtUtc,occurrence)
            if normalized.mode=="EVENT" then
                lines[#lines+1]="Event: "..self:FormatScheduleDateTime(occurrence.eventAtUtc,occurrence)
                if normalized.startingSoonEnabled then lines[#lines+1]="Starting soon: "..self:FormatScheduleDateTime(math.max(occurrence.startsAtUtc,occurrence.eventAtUtc-normalized.startingSoonMinutes*60),normalized) end
            end
        end
        lines[#lines+1]="Upcoming occurrences ("..draft().timeZone.."):"
        for _,s in ipairs(upcoming or {}) do
            local utc=normalized.mode=="EVENT" and s.eventAtUtc or s.startsAtUtc
            if utc then
                local line=self:FormatScheduleDateTime(utc,normalized)
                if normalized.specialPattern~="NONE" then line=line.." — "..self:GetScheduleVariantLabel(self:GetScheduleEventVariant(normalized,utc),normalized.specialPattern,normalized) end
                lines[#lines+1]=line
            end
        end
        if not upcoming or #upcoming==0 then lines[#lines+1]="No future occurrences." end
        return table.concat(lines,"\n")
    end}
    for _,action in ipairs({{"Save and activate",true},{"Save disabled",false}}) do
        local enabled=action[2]
        controls[#controls+1]={type="button",name=action[1],disabled=function() return not selected() end,func=function()
            local d,id,guild=draft(); local candidate=copy(d)
            candidate.enabled,candidate.paused=enabled,false
            if candidate.timelineVersion==1 and candidate.eventDurationMinutes==0 then candidate.eventDurationMinutes=nil end
            candidate.nextDueAt,candidate.nextDuePhase=nil,nil
            local ok,reason=self:SaveGuildSchedule(id,guild,candidate)
            self:ShowStatusMessage(ok and (enabled and "Schedule saved and activated." or "Schedule saved disabled.") or reason)
            if ok then self.scheduleEditor=nil end
            self:RefreshSettingsUI()
        end}
    end
    for _,entry in ipairs({{"Pause saved schedule","PauseGuildSchedule"},{"Resume saved schedule","ResumeGuildSchedule"}}) do
        local method=entry[2]
        controls[#controls+1]={type="button",name=entry[1],disabled=function() return not selected() end,func=function()
            local _,id,guild=draft(); local ok,reason=self[method](self,id,guild)
            if not ok then self:ShowStatusMessage(reason) end; self.scheduleEditor=nil; refresh()
        end}
    end
    return controls
end
