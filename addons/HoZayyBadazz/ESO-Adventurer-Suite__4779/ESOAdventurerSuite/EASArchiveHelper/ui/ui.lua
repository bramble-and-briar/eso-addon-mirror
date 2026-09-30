local AH = _G.EASArchiveHelper

local baseFrame = ZO_Object:Subclass()
function baseFrame:New() local frame=ZO_Object.New(self) frame:Initialise() return frame end
function baseFrame:Initialise()
    self.control=WINDOW_MANAGER:CreateTopLevelWindow()
    self.control:SetResizeToFitDescendents(true) self.control:SetDrawTier(DT_HIGH) self.control:SetMouseEnabled(true) self.control:SetMovable(true) self.control:SetClampedToScreen(true)
    self.control.Background=WINDOW_MANAGER:CreateControl(nil,self.control,CT_BACKDROP) self.control.Background:SetAnchorFill() self.control.Background:SetEdgeColor(0,0,0,0)
    self.control.Border=WINDOW_MANAGER:CreateControl(nil,self.control,CT_BACKDROP) self.control.Border:SetDrawTier(DT_MEDIUM) self.control.Border:SetCenterTexture(0,0,0,0) self.control.Border:SetAnchorFill() self.control.Border:SetEdgeTexture("/esoui/art/worldmap/worldmap_frame_edge.dds",128,16)
    self.control.Label=WINDOW_MANAGER:CreateControl(nil,self.control,CT_LABEL) self.control.Label:SetAnchor(CENTER) self.control.Label:SetFont("${BOLD_FONT}|24") self.control.Label:SetHorizontalAlignment(TEXT_ALIGN_CENTER) self.control.Label:SetVerticalAlignment(TEXT_ALIGN_CENTER) self.control.Label:SetColor(1,1,0,1)
    self.control:SetHidden(true)
end
function baseFrame:SetBackgroundColour(r,g,b,a) self.control.Background:SetCenterColor(r,g,b,a) end
function baseFrame:SetPosition()
    local defaultY=GuiRoot:GetHeight()/6 local defaultX=GuiRoot:GetCenter()-(self.width/2)
    if not AH.Vars[self.name.."Position"] then AH.Vars[self.name.."Position"]={top=defaultY,left=defaultX} end
end
function baseFrame:SetMouseHandler()
    self.control:SetHandler("OnMouseUp",function() AH.Vars[self.name.."Position"]={top=self.control:GetTop(),left=self.control:GetLeft()} end)
end
function baseFrame:SetDimensions(width,height) self.width=width self.height=height self.control.Label:SetDimensions(width,height) end
function baseFrame:SetName(name) self.name=name end
function baseFrame:SetAnchor(...) self.control:SetAnchor(...) end
function baseFrame:SetColour(r,g,b,a) self.control.Label:SetColor(r,g,b,a) end
function baseFrame:SetText(text) self.control.Label:SetText(text) end
function baseFrame:SetHidden(hidden) self.control:SetHidden(hidden) end
function baseFrame:IsHidden() return self.control:IsHidden() end
function baseFrame:ClearAnchors() self.control:ClearAnchors() end

local solutionsWindow
local function ensureFramePoolExists()
    if not AH.FrameObjectPool then
        AH.FrameObjectPool=ZO_ObjectPool:New(function() return baseFrame:New() end,function(frame) frame:SetHidden(true) frame:ClearAnchors() frame:SetText("") frame:SetColour(1,1,0,1) end)
    end
end
function AH.SetTime()
    if not AH.Timer then return end
    AH.Timer:SetText(ZO_CachedStrFormat(_G.ARCHIVEHELPER_DEN_TIMER,AH.CurrentTimerValue))
    if AH.CurrentTimerValue<11 then AH.Timer:SetColour(1,0,0,1) end
end
function AH.StartTimer()
    if not AH.Timer then AH.ShowTimer() end
    if not AH.Timer then return end
    AH.CurrentTimerValue=AH.Vars.EchoingDenTimer AH.Timer:SetColour(1,1,0,1)
    EVENT_MANAGER:UnregisterForUpdate(AH.Name.."_timer")
    EVENT_MANAGER:RegisterForUpdate(AH.Name.."_timer",1000,function() AH.CurrentTimerValue=AH.CurrentTimerValue-1 AH.SetTime() if AH.CurrentTimerValue<=0 then AH.StopTimer() end end)
    AH.Timer:SetHidden(false)
end
function AH.StopTimer() EVENT_MANAGER:UnregisterForUpdate(AH.Name.."_timer") if AH.Timer then AH.Timer:SetHidden(true) end end
local function setCommon(frame,name,width,height) frame:SetName(name) frame:SetDimensions(width,height) frame:SetPosition() frame:SetMouseHandler() frame:SetBackgroundColour(0.23,0.23,0.23,0.7) end
function AH.ShowTimer()
    if AH.IsInEchoingDen and AH.Vars.ShowTimer and not AH.Timer then
        ensureFramePoolExists() local timer,timerKey=AH.FrameObjectPool:AcquireObject() setCommon(timer,"Timer",200,40)
        timer:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,AH.Vars.TimerPosition.left,AH.Vars.TimerPosition.top) AH.CurrentTimerValue=AH.Vars.EchoingDenTimer timer:SetColour(1,1,0,1) timer:SetHidden(false)
        AH.Timer=timer AH.Keys.Timer=timerKey AH.SetTime()
    end
end
function AH.HideTimer() if AH.Timer then AH.Release("Timer") end end
function AH.ShowNotice(message)
    if not AH.Vars.ShowNotice then return end

    -- v0.29.747: ESO Adventurer Suite already owns the recommendation banner
    -- above the Verse/Vision selector. ArchiveHelper's legacy notice occupied
    -- the same top-center space, producing the stacked/double-overlay look.
    -- Keep the Suite recommendation as the single authoritative selector-top
    -- surface and suppress only this legacy selector notice.
    local EPC = _G.ESOProgressionCoach
    local IA = EPC and EPC.InfiniteArchiveOverlay
    if IA and type(IA.SetArchiveChoiceBanner029173) == "function" and AH.ShowingBuffs == true then
        if AH.Notice then
            AH.Release("Notice")
            AH.Notice = nil
        end
        return
    end

    ensureFramePoolExists()
    local parent=_G[AH.SELECTOR_SHORT]
    if not parent then return end
    local notice,noticeKey=AH.FrameObjectPool:AcquireObject()
    setCommon(notice,"Notice",300+(AH.IsRu and 50 or 0),40)
    notice:ClearAnchors()
    notice:SetAnchor(BOTTOM,parent,TOP,0,-32)
    notice:SetAnchor(TOP,parent,TOP,0,-72)
    notice:SetText(message)
    notice:SetHidden(false)
    AH.Notice=notice
    AH.Keys.Notice=noticeKey
end
function AH.ShowQuestReminder()
    if AH.Vars.CheckQuestItems and AH.FoundQuestItem then
        ensureFramePoolExists() local parent=_G[AH.SELECTOR_SHORT] if not parent then return end local questReminder,questReminderKey=AH.FrameObjectPool:AcquireObject() setCommon(questReminder,"Quest",400+(AH.IsRu and 100 or 0),40)
        questReminder:ClearAnchors() questReminder:SetAnchor(BOTTOM,parent,TOP,0,-120) questReminder:SetAnchor(TOP,parent,TOP,0,-160) questReminder:SetText(AH.LC.Format(_G.ARCHIVEHELPER_REMINDER_QUEST_TEXT)) questReminder:SetHidden(false) AH.QuestReminder=questReminder AH.Keys.QuestReminder=questReminderKey
    end
end
function AH.ShowTomeshellCount()
    if AH.IsInFilersWing and AH.Vars.CountTomes and not AH.TomeCount then
        ensureFramePoolExists() local count,countKey=AH.FrameObjectPool:AcquireObject() setCommon(count,"Count",200,40)
        count:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,AH.Vars.CountPosition.left,AH.Vars.CountPosition.top) count:SetColour(1,1,0,1) count:SetHidden(false) AH.TomeCount=count AH.Keys.TomeCount=countKey
    end
end

local function createComboBox(name,parent,width,height,choices,default,callback)
    local combo=WINDOW_MANAGER:CreateControlFromVirtual(name,parent,"ZO_ComboBox") combo:SetDimensions(width,height)
    combo.UpdateValues=function(self,array,index)
        local comboBox=self.m_comboBox combo.comboBox=comboBox
        if array then comboBox:ClearItems() for idx,value in pairs(array) do local entry=ZO_ComboBox:CreateItemEntry(value,function() combo.value=value self:UpdateParent() if callback then callback(value) end end) entry.id=idx comboBox:AddItem(entry,ZO_COMBOBOX_SUPRESS_UPDATE) end end
        comboBox:SelectItemByIndex(index,true) combo.value=default self:UpdateParent()
    end
    combo.SetDisabled=function(self,value) self.disabled=value self:SetMouseEnabled(not value) self:GetNamedChild("OpenDropdown"):SetMouseEnabled(not value) self:SetAlpha(value and 0.5 or 1) self:UpdateParent() end
    combo.UpdateParent=function(self) if parent:GetType()==CT_LABEL then local colour=self.disabled and {0.3,0.3,0.3,1} or choices[combo.value]=="Disabled" and {0.5,0.5,0.4,1} or {0.8,0.8,0.6,1} parent:SetColor(unpack(colour)) end end
    local index=default
    if type(index)=="string" then combo.array={} for idx,value in pairs(choices) do combo.array[value]=idx end index=combo.array[index] end
    combo.SetSelected=function(idx) combo.comboBox:SelectItemByIndex(idx,true) combo.comboBox:HideDropdown() end
    combo:UpdateValues(choices,index) return combo
end
local function getOptions()
    local options={} for _,optionGroup in ipairs(AH.CrossingOptions) do local group={} for path in optionGroup:gmatch("(%d[LR]?)") do table.insert(group,path) end table.insert(options,group) end return options
end
local options=getOptions() local refined={}
local function findOptions(searchOptions,box)
    local refinedOptions={} box=box or 1
    for _,option in ipairs(searchOptions) do
        if tonumber(AH.selectedBox[box])~=0 then local opt=box if box==3 then opt=#option end if option[opt]:find(AH.selectedBox[box]) then table.insert(refinedOptions,option) end else table.insert(refinedOptions,option) end
    end
    if box==3 then refined=refinedOptions else findOptions(refinedOptions,box+1) end
end
local function isReset() for _,value in pairs(AH.selectedBox) do if tonumber(value) then return false end end return true end
function AH.CrossingUpdate(box,value,doNotShare)
    if value=="" then value=0 end AH.selectedBox[box]=tostring(value)
    local box1=tonumber(AH.selectedBox[1]) or 0 local box2=tonumber(AH.selectedBox[2]) or 0 local box3=tonumber(AH.selectedBox[3]) or 0 local test=box1+box2+box3
    if test==0 then if solutionsWindow then solutionsWindow:SetText("") end else
        findOptions(options) local solutions=""
        for _,solution in ipairs(refined) do local formattedSolution="" for index,selection in ipairs(solution) do local opt=selection if opt:len()==2 then opt=opt:sub(1,1)..AH.ch_icons[selection:sub(2)]..((index==#solution) and "" or "  ") else opt=opt..((index==#solution) and "" or AH.LC.Space(6)) end local isFirst=box1~=0 and index==1 local isSecond=box2~=0 and index==2 local isLast=box3~=0 and index==#solution local colour=(isFirst or isSecond or isLast) and AH.LC.Yellow or AH.LC.White formattedSolution=string.format("%s%s",formattedSolution,colour:Colorize(opt)) end if #solution==5 then formattedSolution=string.format("%s%s",formattedSolution,AH.LC.Space(8)) end solutions=string.format("%s%s%s",solutions,AH.LF,formattedSolution) end
        if solutions:len()==0 or isReset() then solutions=GetString(_G.ARCHIVEHELPER_CROSSING_NO_SOLUTIONS) end if solutionsWindow then solutionsWindow:SetText(solutions) end
    end
    if doNotShare~=true then AH.ShareData(AH.SHARE.CROSSING,string.format("%s%s%s",box1,box2,box3)) end
end
function AH.SetDisableCombos()
    local groupType=AH.GetActualGroupType() if groupType==ENDLESS_DUNGEON_GROUP_TYPE_SOLO and AH.AH_SHARING and not AH.DEBUG then AH.AH_SHARING=false end
end
function AH.ShowCrossingHelper(bypass)
    if not AH.ch_icons then AH.ch_icons={L=AH.LC.GetIconTexture("/esoui/art/buttons/large_leftdoublearrow_up.dds",AH.LC.White,20,20),R=AH.LC.GetIconTexture("esoui/art/buttons/large_rightdoublearrow_up.dds",AH.LC.White,20,20)} end
    if AH.IsInCrossing or bypass then
        if not AH.CrossingHelperFrame then
            local frame=WINDOW_MANAGER:CreateTopLevelWindow() frame:SetDrawTier(DT_HIGH) frame:SetMouseEnabled(true) frame:SetMovable(true) frame:SetClampedToScreen(true)
            frame.background=WINDOW_MANAGER:CreateControl(nil,frame,CT_BACKDROP) frame.background:SetAnchorFill() frame.background:SetEdgeColor(0,0,0,0) frame.background:SetCenterColor(0,0,0,0.9)
            frame.border=WINDOW_MANAGER:CreateControl(nil,frame,CT_BACKDROP) frame.border:SetDrawTier(DT_MEDIUM) frame.border:SetCenterTexture(0,0,0,0) frame.border:SetAnchorFill() frame.border:SetEdgeTexture("/esoui/art/worldmap/worldmap_frame_edge.dds",128,16)
            frame:SetWidth(400) frame:SetHeight(500) frame:SetHidden(true)
            local defaultY=GuiRoot:GetHeight()/6 local defaultX=GuiRoot:GetCenter()-(frame:GetWidth()/2) if not AH.Vars.CrossingHelperPosition then AH.Vars.CrossingHelperPosition={top=defaultY,left=defaultX} end
            frame:SetHandler("OnMouseUp",function() AH.Vars.CrossingHelperPosition={top=frame:GetTop(),left=frame:GetLeft()} end)
            frame:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,AH.Vars.CrossingHelperPosition.left,AH.Vars.CrossingHelperPosition.top)
            frame.label=WINDOW_MANAGER:CreateControl(nil,frame,CT_LABEL) frame.label:SetFont("${BOLD_FONT}|24") frame.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER) frame.label:SetVerticalAlignment(TEXT_ALIGN_CENTER) frame.label:SetText(GetString(_G.ARCHIVEHELPER_CROSSING_TITLE)) frame.label:SetColor(1,1,0,1) frame.label:SetAnchor(TOPLEFT,frame,TOPLEFT,0,10) frame.label:SetAnchor(BOTTOMRIGHT,frame,TOPRIGHT,0,30)
            frame.close=WINDOW_MANAGER:CreateControlFromVirtual(nil,frame,"ZO_CloseButton") frame.close:SetAnchor(TOPRIGHT,frame,TOPRIGHT,-10,10) frame.close:SetHandler("OnClicked",AH.HideCrossingHelper)
            frame.text=WINDOW_MANAGER:CreateControl(nil,frame,CT_LABEL) frame.text:SetAnchor(TOPLEFT,frame.label,BOTTOMLEFT,10,10) frame.text:SetAnchor(BOTTOMRIGHT,frame,BOTTOMRIGHT,-10,-370) frame.text:SetFont("${MEDIUM_FONT}|14") frame.text:SetHorizontalAlignment(TEXT_ALIGN_LEFT) frame.text:SetVerticalAlignment(TEXT_ALIGN_CENTER) frame.text:SetColor(0.82,0.82,0.82,1) frame.text:SetText(GetString(_G.ARCHIVEHELPER_CROSSING_INSTRUCTIONS))
            local ordinals={[1]=GetString(_G.ARCHIVEHELPER_CROSSING_START),[2]=ZO_CachedStrFormat("<<i:1>>",2),[3]=GetString(_G.ARCHIVEHELPER_CROSSING_END)}
            for box=1,3 do
                frame["box"..box]=createComboBox(AH.Name.."_choice"..box,frame,40,40,{1,2,3,4,5,6,""},nil,function(value) AH.CrossingUpdate(box,value) end)
                frame["box"..box]:SetAnchor(TOPLEFT,frame.text,BOTTOMLEFT,20+(box*75),50)
                frame["boxlabel"..box]=WINDOW_MANAGER:CreateControl(nil,frame,CT_LABEL) local boxlabel=frame["boxlabel"..box] boxlabel:SetText(ordinals[box]) boxlabel:SetAnchor(CENTER,frame["box"..box],CENTER,0,-40) boxlabel:SetFont("${MEDIUM_FONT}|16") boxlabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT) boxlabel:SetColor(1,1,0,1)
            end
            frame.pathsLabel=WINDOW_MANAGER:CreateControl(nil,frame,CT_LABEL) frame.pathsLabel:SetText(GetString(_G.ARCHIVEHELPER_CROSSING_PATHS)) frame.pathsLabel:SetAnchor(CENTER,frame.text,CENTER,0,180) frame.pathsLabel:SetFont("${BOLD_FONT}|24") frame.pathsLabel:SetColor(0.46,0.74,0.76,1) frame.pathsLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            solutionsWindow=WINDOW_MANAGER:CreateControl(nil,frame,CT_LABEL) solutionsWindow:SetAnchor(TOPLEFT,frame.text,BOTTOMLEFT,0,100) solutionsWindow:SetAnchor(BOTTOMRIGHT,frame,BOTTOMRIGHT,-10,-10) solutionsWindow:SetFont("${MEDIUM_FONT}|24") solutionsWindow:SetHorizontalAlignment(TEXT_ALIGN_CENTER) solutionsWindow:SetVerticalAlignment(TEXT_ALIGN_CENTER) solutionsWindow:SetColor(0.976,0.976,0.976,1)
            frame.key=WINDOW_MANAGER:CreateControl(nil,frame,CT_LABEL) frame.key:SetAnchor(CENTER,frame,CENTER,0,230) frame.key:SetFont("${BOLD_FONT}|16") frame.key:SetColor(0.82,0.82,0.82,1) frame.key:SetHorizontalAlignment(TEXT_ALIGN_CENTER) frame.key:SetText(ZO_CachedStrFormat(_G.ARCHIVEHELPER_CROSSING_KEY,AH.ch_icons.L,AH.ch_icons.R))
            AH.selectedBox={[1]=0,[2]=0,[3]=0} AH.CrossingHelperFrame=frame
        end
        AH.SetDisableCombos() AH.CrossingHelperFrame:SetHidden(false)
    end
end
function AH.HideCrossingHelper()
    AH.selectedBox=AH.selectedBox or {} AH.selectedBox[1]=0 AH.selectedBox[2]=0 AH.selectedBox[3]=0
    if AH.CrossingHelperFrame then AH.CrossingHelperFrame.box1.SetSelected(7,true) AH.CrossingHelperFrame.box2.SetSelected(7,true) AH.CrossingHelperFrame.box3.SetSelected(7,true) if solutionsWindow then solutionsWindow:SetText("") end AH.CrossingHelperFrame:SetHidden(true) end
end
