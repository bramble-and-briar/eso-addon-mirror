-- Optional LibExtendedJournal integration. Journal controls are separate from
-- standalone controls, sharing the same saved data and snapshot readers.
local C=CompanionSidekick
local Journal=LibExtendedJournal
local available=type(Journal)=="table" and type(Journal.RegisterTab)=="function" and type(Journal.Show)=="function"
if available then Journal.Used=true end -- Required before EVENT_ADD_ON_LOADED.
local WM=WINDOW_MANAGER
local ipairs,pairs,math,tostring=ipairs,pairs,math,tostring
local TOPLEFT,CENTER,CT_CONTROL,CT_LABEL,CT_TEXTURE,CT_BUTTON,CT_BACKDROP=TOPLEFT,CENTER,CT_CONTROL,CT_LABEL,CT_TEXTURE,CT_BUTTON,CT_BACKDROP
local InitializeTooltip,SetTooltipText,ClearTooltip=InitializeTooltip,SetTooltipText,ClearTooltip
local InformationTooltip=InformationTooltip
local previousVisible=false
local columns={{"Companion",42,175},{"Access",224,123},{"Rapport",354,143},{"Lv",505,45},{"Keepsake",559,113},{"Quest / overview",680,200}}
local function Place(control,parent,x,y,w,h)
    control:ClearAnchors();control:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);control:SetDimensions(w,h)
end
local function Label(parent,text,x,y,w,header)
    local c=WM:CreateControl(nil,parent,CT_LABEL);Place(c,parent,x,y,w,28)
    c:SetFont(header and "ZoFontGameBold" or "ZoFontGame")
    c:SetColor(header and .77 or .86,header and .75 or .86,header and .58 or .86,1)
    c:SetMaxLineCount(1);c:SetText(text or "");return c
end
local function Icon(parent,x,prefix,description,fn)
    local c=WM:CreateControlFromVirtual(nil,parent,"ZO_ButtonBehaviorClickSound")
    Place(c,parent,x,6,36,36)
    c:SetNormalTexture(prefix.."up.dds");c:SetPressedTexture(prefix.."down.dds");c:SetMouseOverTexture(prefix.."over.dds")
    c:SetMouseEnabled(true);c:SetHandler("OnClicked",function()ClearTooltip(InformationTooltip);fn()end)
    c:SetHandler("OnMouseEnter",function(self)InitializeTooltip(InformationTooltip,self,TOP,0,-6,BOTTOM);SetTooltipText(InformationTooltip,description)end)
    c:SetHandler("OnMouseExit",function()ClearTooltip(InformationTooltip)end)
    c:SetHandler("OnEffectivelyHidden",function()ClearTooltip(InformationTooltip)end)
    return c
end
local function Fit()
    if not C.journalHost then return end
    local w,h=C.journalHost:GetWidth(),C.journalHost:GetHeight()
    if w>0 and h>0 then C.journalCanvas:SetScale(math.min(1,w/920,h/680))end
end
function C.JournalIsOpen()return C.journalActive==true end
function C.CloseJournal()
    if C.journalActive then SCENE_MANAGER:ShowBaseScene()end
end
function C.OpenJournal()
    if not C.journalRegistered then C.Say("Enable LibExtendedJournal and reload the UI to use the journal tab. /csidekick opens the standalone tracker.");return end
    Journal.Show("CompanionSidekick")
end
local function Page(page)
    if page~="roster" and page~="help" and not C.byId[C.selectedCompanion] then
        C.Say("Select a companion from the roster first.");return
    end
    C.journalPage=page;C.RenderJournal()
end
local function Help()
    return "COMPANION TRACKING\nChoose Account overview or a character, then click a companion.\n\nProgress shows recruitment, recorded personal quests, active objectives, rapport and permanent keepsake requirements. Gear & Skills shows the shared build and recorded ability unlocks. Characters shows who has recruited the companion.\n\nThe person icon returns to the roster. The book opens Progress, the bag opens Gear & Skills, and the character icon opens Character Access. Hover over icons for descriptions. Refresh rescans the character you are currently playing.\n\nLog into each character once to record their recruitment and quests. Summon companions to scan rapport, gear and skills. Offline characters show last-seen snapshots, never live data. Unseen information stays Unknown. NA and EU are separate.\n\nCompletion requires recruitment, recorded personal quests, level 20 and permanent keepsake. It does not mean every skill line is maxed. Some personal quest names and keepsakes may be unresolved and remain Unknown.\n\nExtended Journal uses one fixed presentation. ESO's Exit closes the journal. The standalone tracker remains available through /csidekick."
end
function C.RenderJournal()
    if not C.journalActive or not C.journalCanvas then return end
    local roster=C.journalPage=="roster"
    C.journalRoster:SetHidden(not roster);C.journalDetail:SetHidden(roster)
    for _,tab in ipairs(C.journalTabs)do tab.control:SetNormalTexture(tab.prefix..(C.journalPage==tab.page and "down.dds" or "up.dds"))end
    local char=C.selectedCharacter and C.db.characters[C.selectedCharacter]
    if roster then
        C.journalTitle:SetText("Companions")
        C.journalCombo:SetSelectedItem(char and char.name or "Account overview")
        for i,e in ipairs(C.catalog)do
            local row=C.journalRows[i]
            if not row then
                row=WM:CreateControl(nil,C.journalChild,CT_BUTTON);Place(row,C.journalChild,0,(i-1)*38,880,36)
                local bg=WM:CreateControl(nil,row,CT_BACKDROP);bg:SetAnchorFill()
                bg:SetCenterColor(.08,.09,.12,i%2==0 and .42 or .12);bg:SetEdgeColor(0,0,0,0)
                row.icon=WM:CreateControl(nil,row,CT_TEXTURE);Place(row.icon,row,5,4,28,28)
                row.labels={};for n,col in ipairs(columns)do row.labels[n]=Label(row,"",col[2],5,col[3])end
                row:SetMouseEnabled(true);row:SetHandler("OnClicked",function(self)C.selectedCompanion=self.companionId;Page("progress")end)
                C.journalRows[i]=row
            end
            row.companionId=e.id;row:SetHidden(false);row.icon:SetTexture(e.icon)
            local r=char and char.companions and char.companions[e.id]
            local access,rapport,quest
            if char then access=C.UnlockText(r);rapport=C.RapportText(r);quest=C.QuestSummary(e,r)
            else
                local unlocked,scanned,total=C.AccountCounts(e.id)
                access=string.format("%d/%d chars",unlocked,total);rapport=scanned.." scanned";quest="Select for companion details"
            end
            local shared=C.db.shared[e.id]
            local values={e.name,access,rapport,shared and shared.level and tostring(shared.level) or "?",C.KeepsakeText(e),quest}
            for n,text in ipairs(values)do row.labels[n]:SetText(text)end
        end
        for i=#C.catalog+1,#C.journalRows do C.journalRows[i]:SetHidden(true)end
        C.journalChild:SetHeight(math.max(400,#C.catalog*38))
    else
        local text
        if C.journalPage=="help" then C.journalTitle:SetText("Companion Sidekick Help");text=Help()
        else
            local e=C.byId[C.selectedCompanion]
            if not e then C.journalPage="roster";C.RenderJournal();return end
            local r,recordCharacter=C.SelectedRecord(e.id)
            local title=({progress="Progress",build="Gear & Skills",characters="Character Access"})[C.journalPage]
            C.journalTitle:SetText(e.name.." — "..title)
            text=C.journalPage=="build" and C.BuildEquipment(e)
                or C.journalPage=="characters" and C.BuildCharacters(e) or C.BuildProgress(e,r,recordCharacter)
        end
        C.journalText:SetText(text)
        local _,height=C.journalText:GetTextDimensions();C.journalDetailChild:SetHeight(math.max(470,height+25))
    end
    C.journalFooter:SetText(C.indexing and "Indexing quest names and keepsakes..." or (char and char.name.." | Snapshot: "..C.Age(char.seen) or "Account overview | Other characters show last-seen snapshots."))
    Fit()
end
function C.RegisterJournal()
    if not available or C.journalRegistered then return end
    local host=WM:CreateControl("CompanionSidekickJournalHost",GuiRoot,CT_CONTROL);host:SetHidden(true);C.journalHost=host
    local canvas=WM:CreateControl("CompanionSidekickJournalCanvas",host,CT_CONTROL)
    Place(canvas,host,0,0,920,680);C.journalCanvas=canvas
    C.journalPage="roster";C.journalRows={};C.journalTabs={}
    for i,tab in ipairs({{"roster","character","Companion roster"},{"progress","journal","Quests, rapport and keepsake progress"},
        {"build","inventory","Recorded gear and skills"},{"characters","collections","Character recruitment and rapport"}})do
        local page,prefix=tab[1],"EsoUI/Art/MainMenu/menuBar_"..tab[2].."_"
        local control=Icon(canvas,20+(i-1)*56,prefix,tab[3],function()Page(page)end)
        C.journalTabs[#C.journalTabs+1]={page=page,prefix=prefix,control=control}
    end
    local refresh=Icon(canvas,800,"EsoUI/Art/Buttons/edit_","Refresh the current character's companion information",function()C.Refresh()end)
    refresh:SetNormalTexture("CompanionSidekick/textures/refresh.dds")
    refresh:SetPressedTexture("CompanionSidekick/textures/refresh.dds")
    refresh:SetMouseOverTexture("CompanionSidekick/textures/refresh.dds")
    Icon(canvas,856,"EsoUI/Art/MenuBar/menuBar_help_","How to use Companion Sidekick",function()Page("help")end)
    C.journalTitle=Label(canvas,"Companions",20,58,880,true)
    local dropdown=WM:CreateControlFromVirtual("CompanionSidekickJournalCharacters",canvas,"ZO_ComboBox")
    Place(dropdown,canvas,125,96,400,30)
    C.journalCombo=ZO_ComboBox_ObjectFromContainer(dropdown);C.journalCombo:SetSortsItems(false)
    C.journalCombo:AddItem(C.journalCombo:CreateItemEntry("Account overview",function()C.selectedCharacter=nil;C.Render()end))
    local chars={};for id,char in pairs(C.db.characters)do chars[#chars+1]={id=id,name=char.name}end
    table.sort(chars,function(a,b)return a.name<b.name end)
    for _,char in ipairs(chars)do local id=char.id;C.journalCombo:AddItem(C.journalCombo:CreateItemEntry(char.name,function()C.selectedCharacter=id;C.Render()end))end
    Label(canvas,"Character",20,98,100,true)
    C.journalRoster=WM:CreateControl(nil,canvas,CT_CONTROL);Place(C.journalRoster,canvas,20,142,880,480)
    for _,col in ipairs(columns)do Label(C.journalRoster,col[1],col[2],0,col[3],true)end
    local scroll=WM:CreateControlFromVirtual("CompanionSidekickJournalRosterScroll",C.journalRoster,"ZO_ScrollContainer")
    Place(scroll,C.journalRoster,0,36,900,438);C.journalChild=scroll:GetNamedChild("ScrollChild");C.journalChild:SetWidth(880)
    C.journalDetail=WM:CreateControlFromVirtual("CompanionSidekickJournalDetailScroll",canvas,"ZO_ScrollContainer")
    Place(C.journalDetail,canvas,20,142,900,475)
    C.journalDetailChild=C.journalDetail:GetNamedChild("ScrollChild");C.journalDetailChild:SetWidth(880)
    C.journalText=WM:CreateControl(nil,C.journalDetailChild,CT_LABEL)
    C.journalText:SetAnchor(TOPLEFT,C.journalDetailChild,TOPLEFT,0,0);C.journalText:SetWidth(865)
    C.journalText:SetFont("ZoFontGame");C.journalText:SetColor(.86,.86,.86,1)
    C.journalFooter=Label(canvas,"",20,624,880);C.journalFooter:SetFont("ZoFontGameSmall")
    C.journalSupportFooter=C.CreateJournalSupportFooter(canvas,654,880)
    local render,detail,help,appearance=C.Render,C.ShowDetail,C.ShowHelp,C.ShowAppearance
    C.Render=function()render();C.RenderJournal()end
    C.ShowDetail=function(id)if C.journalActive then C.selectedCompanion=id;Page("progress")else detail(id)end end
    C.ShowHelp=function()if C.journalActive then Page("help")else help()end end
    C.ShowAppearance=function()if not C.journalActive then appearance()end end
    host:SetHandler("OnRectChanged",Fit)
    Journal.RegisterTab("CompanionSidekick",{order=910,title="Companion Sidekick",iconPrefix="EsoUI/Art/MainMenu/menuBar_character_",control=host,
        callbackShow=function()
            if C.journalActive then return end
            previousVisible=not C.window:IsHidden();C.journalActive=true
            C.window:SetHidden(true);C.detail:SetHidden(true)
            if C.appearanceWindow then C.appearanceWindow:SetHidden(true)end
            C.Refresh();C.RenderJournal()
        end,
        callbackHide=function()
            if not C.journalActive then return end
            C.journalActive=false;C.window:SetHidden(not previousVisible)
            ClearTooltip(InformationTooltip)
        end,
    })
    C.journalRegistered=true
end
