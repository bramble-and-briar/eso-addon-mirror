local AlabuzyaUI = AlabuzyaUI
AlabuzyaUI.QuestTracker = {}
-- Original AlabuzyaUI quest list. Public journal API; no third-party code.
local root,viewport,settings,ru
local controls={}
local scroll,totalHeight=0,0
local WIDTH,HEIGHT=326,340
local function Text(parent,font)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
    c:SetFont(font or AlabuzyaUI.Theme.Font(16))
    c:SetMouseEnabled(false) return c
end
local function Entries()
    local zones,order={},{}
    for i=1,MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(i) then
            local name,_,active,_,override,completed,_,level=GetJournalQuestInfo(i)
            local zone=GetJournalQuestLocationInfo(i)
            if not zone or zone=='' then zone=ru and 'Прочие' or 'Other' end
            if not zones[zone] then zones[zone]={} order[#order+1]=zone end
            zones[zone][#zones[zone]+1]={index=i,name=name,active=override~='' and override or active,completed=completed,level=level}
        end
    end
    table.sort(order)
    local entries={}
    for _,zone in ipairs(order) do
        local quests=zones[zone]
        entries[#entries+1]={zone=zone,text=(settings.collapsed[zone] and '> ' or 'v ')..'['..#quests..'] '..zone,kind='zone'}
        if not settings.collapsed[zone] then
            for _,q in ipairs(quests) do
                local assisted=GetTrackedIsAssisted(TRACK_TYPE_QUEST,q.index)
                entries[#entries+1]={quest=q.index,text='['..q.level..'] '..q.name,kind='quest',assisted=assisted}
                local seen={} local added=0
                for step=1,GetJournalQuestNumSteps(q.index) do
                    local _,visibility,_,_,conditions=GetJournalQuestStepInfo(q.index,step)
                    if visibility~=QUEST_STEP_VISIBILITY_HIDDEN and visibility~=QUEST_STEP_VISIBILITY_HINT then
                        for condition=1,conditions do
                            local text,_,_,fail,complete,_,visible=GetJournalQuestConditionInfo(q.index,step,condition,true)
                            if visible and not fail and not complete and text~='' and not seen[text] then
                                entries[#entries+1]={text=text,kind='condition'} seen[text]=true added=added+1
                            end
                        end
                    end
                end
                if added==0 and q.active and q.active~='' then entries[#entries+1]={text=q.active,kind='condition'} end
            end
        end
    end
    return entries
end
local Render
Render=function()
    local entries=Entries()
    local y=0
    for i,entry in ipairs(entries) do
        local c=controls[i]
        if not c then
            c=Text(viewport)
            c:SetMouseEnabled(true)
            c:SetHandler('OnMouseUp',function(self,button,inside)
                if button~=MOUSE_BUTTON_INDEX_LEFT or not inside then return end
                local item=self.entry
                if item.zone then settings.collapsed[item.zone]=not settings.collapsed[item.zone]
                elseif item.quest and IsValidQuestIndex(item.quest) then FOCUSED_QUEST_TRACKER:ForceAssist(item.quest) end
                Render()
            end)
            c:SetHandler('OnMouseWheel',function(_,delta)
                scroll=math.max(0,math.min(math.max(0,totalHeight-HEIGHT),scroll-delta*40)) Render()
            end)
            controls[i]=c
        end
        c.entry=entry
        c:SetFont(AlabuzyaUI.Theme.Font(entry.kind=='zone' and 18 or entry.kind=='condition' and 15 or 16))
        local indent=entry.kind=='zone' and 0 or entry.kind=='quest' and 12 or 24
        c:SetWidth(WIDTH-24-indent) c:SetHeight(0)
        c:SetText(zo_strformat('<<1>>',entry.text))
        local height=math.max(entry.kind=='zone' and 24 or 20,c:GetTextHeight()+3)
        c:SetHeight(height)
        c:ClearAnchors() c:SetAnchor(TOPLEFT,viewport,TOPLEFT,indent,y-scroll)
        if entry.assisted then c:SetColor(1,0.72,0.32,1)
        elseif entry.kind=='zone' then c:SetColor(1,0.63,0.25,1)
        elseif entry.kind=='condition' then c:SetColor(0.76,0.74,0.63,1)
        else c:SetColor(1,0.73,0.4,1) end
        c:SetHidden(false) y=y+height
    end
    for i=#entries+1,#controls do controls[i]:SetHidden(true) end
    totalHeight=y
    local maxScroll=math.max(0,y-HEIGHT)
    if scroll>maxScroll then scroll=maxScroll return Render() end
    viewport:SetHeight(math.max(24,math.min(HEIGHT,y)))
    root:SetHeight(math.max(24,math.min(HEIGHT,y))+44)
    AlabuzyaUI.Theme.SidebarHeight(root:GetHeight())
end
function AlabuzyaUI.QuestTracker.Initialize()
    if AlabuzyaUI.Settings and not AlabuzyaUI.Settings.StyleEnabled() then return end
    ru=GetCVar('language.2')=='ru'
    settings=AlabuzyaUI.SavedVariables.Account('questTracker',{collapsed={}})
    local sidebar=AlabuzyaUI.Theme.Sidebar()
    root=WINDOW_MANAGER:CreateControl('AlabuzyaUIQuestTracker',sidebar,CT_CONTROL)
    root:SetDimensions(WIDTH+16,HEIGHT+44)
    root:SetAnchor(TOPLEFT,sidebar,TOPLEFT,0,AlabuzyaUI.Theme.mapHeight or 406)
    root:SetMouseEnabled(false)
    local title=Text(root)
    AlabuzyaUI.Theme.Text(title,22)
    title:SetAnchor(TOPLEFT,root,TOPLEFT,14,7)
    title:SetText(ru and 'Задания' or 'Quests')
    viewport=WINDOW_MANAGER:CreateControl(nil,root,CT_SCROLL)
    viewport:SetDimensions(WIDTH-12,HEIGHT) viewport:SetAnchor(TOPLEFT,root,TOPLEFT,14,38)
    viewport:SetScrollBounding(SCROLL_BOUNDING_UNBOUND)
    local function HideNative()
        local c=FOCUSED_QUEST_TRACKER and FOCUSED_QUEST_TRACKER.control
        if c then c:SetHidden(true) end
    end
    local native=FOCUSED_QUEST_TRACKER and FOCUSED_QUEST_TRACKER.control
    if native then ZO_PostHookHandler(native,'OnShow',HideNative) end
    EVENT_MANAGER:RegisterForUpdate('AlabuzyaUIQuestTracker',1000,function()
        if not root:IsHidden() then Render() end
        HideNative()
    end)
    Render() HideNative()
end
