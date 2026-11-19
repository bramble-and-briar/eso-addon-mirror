local checks=0
local function check(value,message)checks=checks+1;assert(value,message)end
local constants={"COLLECTIBLE_CATEGORY_TYPE_COMPANION","COLLECTIBLE_ASSOCIATED_QUEST_STATE_COMPLETED",
    "COLLECTIBLE_ASSOCIATED_QUEST_STATE_INACTIVE","BAG_COMPANION_WORN","LINK_STYLE_DEFAULT","HOTBAR_CATEGORY_COMPANION",
    "EQUIP_SLOT_HEAD","EQUIP_SLOT_SHOULDERS","EQUIP_SLOT_CHEST","EQUIP_SLOT_HAND","EQUIP_SLOT_WAIST","EQUIP_SLOT_LEGS",
    "EQUIP_SLOT_FEET","EQUIP_SLOT_NECK","EQUIP_SLOT_RING1","EQUIP_SLOT_RING2","EQUIP_SLOT_MAIN_HAND","EQUIP_SLOT_OFF_HAND",
    "EVENT_ADD_ON_LOADED","EVENT_PLAYER_ACTIVATED","EVENT_COMPANION_ACTIVATED","EVENT_COMPANION_DEACTIVATED",
    "EVENT_COMPANION_RAPPORT_UPDATE","EVENT_COMPANION_EXPERIENCE_GAIN","EVENT_COMPANION_SKILLS_FULL_UPDATE",
    "EVENT_COMPANION_SKILL_RANK_UPDATE","EVENT_COMPANION_SKILL_XP_UPDATE","EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED",
    "EVENT_QUEST_ADDED","EVENT_QUEST_ADVANCED","EVENT_QUEST_REMOVED","EVENT_QUEST_COMPLETE","EVENT_COLLECTIBLE_UPDATED",
    "EVENT_ACHIEVEMENT_UPDATED","EVENT_INVENTORY_SINGLE_SLOT_UPDATE","TOPLEFT","CENTER","DT_HIGH","CT_LABEL",
    "CT_BACKDROP","CT_CONTROL","CT_BUTTON"}
for i,name in ipairs(constants)do _G[name]=i end
MAX_JOURNAL_QUESTS=25
local timers,events={},{}
EVENT_MANAGER={RegisterForEvent=function(_,n,e,fn)events[e]=fn end,UnregisterForEvent=function(_,n,e)events[e]=nil end,
    RegisterForUpdate=function(_,n,ms,fn)timers[n]=fn end,UnregisterForUpdate=function(_,n)timers[n]=nil end}
local function tick()
    local todo={};for n,fn in pairs(timers)do todo[n]=fn end
    for _,fn in pairs(todo)do fn()end
end
local controls={}
local function control(name,parent)
    local c={name=name,parent=parent,hidden=false,handlers={},text=""};controls[#controls+1]=c
    function c:SetAnchor(...)self.anchor={...}end
    function c:ClearAnchors()self.anchor=nil end
    function c:SetAnchorFill()end
    function c:SetDimensions(w,h)self.width=w;self.height=h end
    function c:SetWidth(w)self.width=w end
    function c:SetHeight(h)self.height=h end
    function c:SetFont()end
    function c:SetColor()end
    function c:SetText(t)self.text=t end
    function c:SetCenterColor()end
    function c:SetEdgeColor()end
    function c:SetEdgeTexture()end
    function c:SetMouseEnabled()end
    function c:SetMovable()end
    function c:SetClampedToScreen()end
    function c:SetDrawTier()end
    function c:SetDrawLevel()end
    function c:SetHidden(v)self.hidden=v end
    function c:IsHidden()return self.hidden end
    function c:SetHandler(n,fn)self.handlers[n]=fn end
    function c:SetScale(v)self.scale=v end
    function c:SetMaxLineCount()end
    function c:GetLeft()return 100 end
    function c:GetTop()return 150 end
    function c:GetTextDimensions()return 500,#self.text/2 end
    function c:GetNamedChild(n)self.child=self.child or control(nil,self);return self.child end
    return c
end
WINDOW_MANAGER={CreateControl=function(_,n,p)return control(n,p)end,CreateControlFromVirtual=function(_,n,p)return control(n,p)end,
    CreateTopLevelWindow=function(_,n)return control(n)end}
GuiRoot=control('GuiRoot')
function ZO_ComboBox_ObjectFromContainer()
    local c={items={}}
    function c:SetSortsItems()end
    function c:CreateItemEntry(n,fn)return {name=n,fn=fn}end
    function c:AddItem(item)self.items[#self.items+1]=item end
    function c:SetSelectedItem(n)self.selected=n end
    return c
end
local clock=100000
function GetTimeStamp()return clock end
local active,skillsReady=0,false
local charId,charName='a','Amazon'
local done={a={[101]=true},b={}}
local ids={9245,9353,9911,9912,11113,11114,12172,12173}
local names={'Bastian Hallix','Mirri Elendis','Ember','Isobel Veloise','Sharp-as-Night','Azandar al-Cybiades','Tanlorin','Zerith-var'}
local questNames={[101]='Competition and Contracts',[102]='Shattered and Scattered',[6662]='Things Lost, Things Found',
    [6664]='Family Secrets',[7000]='The Lost Symbol',[7001]="A Mother's Request",[7002]='The Princess Detective',
    [8000]='Of Crowns and Thorns'}
local journal={[24]={id=6662,name='Things Lost, Things Found',objective='Find the missing letter'}}
local function companion(cid)for i,id in ipairs(ids)do if cid==id then return i end end end
function GetCollectibleInfo(cid)
    local id=companion(cid)
    return id and names[id] or 'Keepsake','', 'icon.dds','',true,false,false,id and COLLECTIBLE_CATEGORY_TYPE_COMPANION or 999,''
end
function GetCollectibleReferenceId(cid)return companion(cid) or 0 end
function GetCompanionCollectibleId(id)return ids[id] or 0 end
function GetCompanionName(id)return names[id]end
function GetCompanionPassivePerkAbilityId(id)return 1000+id end
function GetCompanionIntroQuestId(id)return 100+id end
function GetTotalCollectiblesByCategoryType()return #ids end
function GetCollectibleIdFromType(_,i)return ids[i]end
function GetCollectibleAssociatedQuestState(cid)
    return done[charId][100+(companion(cid) or 0)] and COLLECTIBLE_ASSOCIATED_QUEST_STATE_COMPLETED or COLLECTIBLE_ASSOCIATED_QUEST_STATE_INACTIVE
end
function GetActiveCompanionDefId()return active end
function GetActiveCompanionLevelInfo()return 20,5000 end
function GetActiveCompanionRapport()return charId=='a' and 4321 or 1000 end
function GetActiveCompanionRapportLevel()return 4 end
function GetMaximumRapport()return 5500 end
function GetMinimumRapport()return -5000 end
function GetString(id,n)return id..':'..tostring(n)end
function GetQuestName(id)return questNames[id] or ''end
function HasCompletedQuest(id)return done[charId][id]==true end
function IsValidQuestIndex(i)return journal[i]~=nil end
function GetJournalQuestId(i)return journal[i].id end
function GetJournalQuestInfo(i)return journal[i].name,'',journal[i].objective,0,''end
function GetJournalQuestNumConditions()return 1 end
function GetJournalQuestConditionInfo(i)return journal[i].objective,0,1,false,false,false,true end
local emptyGear=false
function GetItemLink(bag,slot)return not emptyGear and slot==EQUIP_SLOT_MAIN_HAND and '|Hitem:staff|hStaff|h' or ''end
function GetItemLinkName()return 'Companion Staff'end
function GetItemLinkDisplayQuality()return 4 end
function GetItemLinkTraitInfo()return 7,'trait'end
function GetItemLinkArmorType()return 0 end
function GetItemLinkWeaponType()return 12 end
function AreCompanionSkillsInitialized()return skillsReady end
function GetSlotBoundId(slot)return slot==8 and 0 or slot+2000 end
function GetAbilityName(id)return 'Ability '..id end
function GetAbilityIcon()return 'ability.dds'end
function GetAbilityDescription(id)return 'Description '..id end
function GetNumSkillTypes()return 2 end
function GetNumCompanionSkillLines(t)return t==1 and 1 or 0 end
function GetCompanionSkillLineId()return 90 end
function GetCompanionSkillLineDynamicInfo()return 10,true,true end
function GetCompanionSkillLineXPInfo()return 100,200,150 end
function GetCompanionSkillLineNameById()return 'Companion Magic'end
function GetNumAbilitiesInCompanionSkillLine()return 2 end
function GetCompanionAbilityId(_,i)return 3000+i end
function IsCompanionAbilityUnlocked(id)return id==3001 end
function IsAbilityPassive(id)return id==3002 end
function GetCompanionAbilityRankRequired(id)return id==3001 and 1 or 15 end
function GetCVar()return 'en'end
function GetAPIVersion()return 101051 end
function GetNumCollectibleCategories()return 1 end
function GetCollectibleCategoryInfo()return 'Upgrades',1,0 end
function GetCollectibleSubCategoryInfo()return 'Keepsakes',1 end
function GetCollectibleId()return 5001 end
function GetCollectibleDescription()return 'Permanently grants Ability 1001 to the bearer.'end
function GetNumAchievementCategories()return 1 end
function GetAchievementCategoryInfo()return 'Character',1,0 end
function GetAchievementSubCategoryInfo()return 'Companions',1 end
function GetAchievementId()return 6001 end
function GetAchievementRewardCollectible()return true,5001 end
function IsCollectibleUnlocked()return true end
function GetAchievementInfo()return 'Brother-in-Arms'end
function GetAchievementNumCriteria()return 2 end
function GetAchievementCriterion(_,i)return 'Criterion '..i,i==1 and 1 or 0,1 end
function GetWorldName()return 'NA Megaserver'end
function GetCurrentCharacterId()return charId end
function GetUnitName()return charName end
function GetNumCharacters()return 2 end
function GetCharacterInfo(i)return i==1 and 'Amazon' or 'Alt',0,50,1,1,1,i==1 and 'a' or 'b'end
SLASH_COMMANDS={};local logs={}
function d(text)logs[#logs+1]=text end
local database={}
ZO_SavedVars={NewAccountWide=function(_,n,v,ns,defaults,world)check(world=='NA Megaserver','separate server namespace');return database end}
-- @MODULES@
local C=CompanionSidekick
C.Init(nil,'WrongAddon');check(C.db==nil,'ignore other addon load events')
C.Init(nil,C.name)
check(#C.catalog==8,'discover all eight companions without duplicate seeds')
check(C.db.characters.a and C.db.characters.b,'roster includes unvisited alts')
check(C.db.characters.b.companions[1]==nil,'unvisited alt not falsely locked')
check(C.UnlockText(nil)=='Unknown','unknown is distinct from locked')
check(C.db.characters.a.companions[1].unlocked,'intro completion records character unlock')
check(C.db.characters.a.companions[2].unlocked==false,'account collectible does not imply character unlock')
GetCollectibleAssociatedQuestState=function()return COLLECTIBLE_ASSOCIATED_QUEST_STATE_COMPLETED end
C.Refresh();check(C.db.characters.a.companions[2].unlocked==false,'account quest collectible state cannot override character quest completion')
check(C.db.characters.a.companions[1].quests[2].active,'quest journal slot holes handled')
check(C.db.characters.a.companions[1].quests[2].objective=='Find the missing letter','active quest objective captured')
check(C.db.shared[1]==nil,'inactive companion never gets a fabricated build')
check(C.window:IsHidden(),'no startup window spam')
SLASH_COMMANDS['/companions']('')
check(not C.window:IsHidden() and #C.rows==8,'slash command opens compact roster')
C.combo.items[1].fn()
check(C.selectedCharacter==nil and C.rows[1].text[2].text:find('chars',1,true),'account overview access counts')
C.combo.items[2].fn();check(C.selectedCharacter~=nil,'character selector works')
active=1;C.Refresh()
local r=C.db.characters.a.companions[1]
check(r.rapport==4321 and r.rapportMax==5500,'rapport numbers captured for active character')
check(C.db.shared[1].level==20 and #C.db.shared[1].gear==12,'level and equipment captured once per companion')
check(C.db.shared[1].bar==nil,'uninitialized skills not captured')
skillsReady=true;C.Refresh()
check(#C.db.shared[1].bar==6 and C.db.shared[1].bar[6].id==0,'five skills and empty ultimate stored')
check(C.db.shared[1].lines[1].abilities[2].passive and not C.db.shared[1].lines[1].abilities[2].unlocked,'passive lock state captured')
skillsReady=false;C.Refresh()
check(#C.db.shared[1].bar==6,'temporary uninitialized skills preserve previous scan')
local savedRapport=r.rapport
active=2;C.Refresh()
check(r.rapport==savedRapport,'switching companions preserves prior rapport')
active=0;C.Refresh();check(C.db.shared[1].level==20,'dismissal preserves shared build')
for _=1,120 do tick()end
check(not C.indexing and C.db.indexKey=='101051:en','batched indexes complete and cache')
check(C.db.questIndex['The Lost Symbol'][1]==7000,'story quest names resolve to game IDs')
check(C.db.questIndex['Of Crowns and Flowers'][1]==8000,'known quest title variants resolve')
check(C.byId[1].keepsake==5001 and C.byId[1].achievement==6001,'exact passive description maps keepsake achievement')
check(C.KeepsakeText(C.byId[1])=='Permanent','permanent perk checked using collectible unlock')
check(C.KeepsakeText(C.byId[2])=='Unknown','unidentified perk remains unknown')
check(C.Requirements(C.byId[1])[3]:find('0/1',1,true),'missing achievement requirement is visible')
done.a[6662]=true;done.a[6664]=true;journal={};C.Refresh()
check(C.Progress(C.byId[1],r)=='Complete','completion requires story level and keepsake')
check(C.QuestSummary(C.byId[1],r)=='Story complete','completed chain summarized')
done.a[6664]=false;C.Refresh()
check(C.Progress(C.byId[1],r)=='In progress','incomplete story blocks full completion')
check(C.QuestSummary(C.byId[1],r)=='Next: Family Secrets','next quest shown without claiming availability')
local oldSeen=r.rapportSeen
charId='b';charName='Alt';C.characterId=charId;C.characterName=charName;active=1;clock=clock+60;C.Refresh()
check(C.db.characters.b.companions[1].unlocked and C.db.characters.b.companions[1].rapport==1000,'active companion on second character creates independent unlock and rapport')
check(r.rapport==4321 and r.rapportSeen==oldSeen,'alt scan leaves previous character intact')
check(C.db.shared[1].level==20,'alt uses shared companion build')
local u,s,t=C.AccountCounts(1);check(u==2 and s==2 and t==2,'account counts include both scanned characters')
active=0;C.Refresh()
check(not C.db.characters.b.companions[1].unlocked,'subsequent intro check replaces stale active override')
C.ShowDetail(1);check(not C.detail:IsHidden(),'row details opens')
C.detailTab='build';C.RenderDetail()
check(C.detailText.text:find('Companion Staff',1,true) and C.detailText.text:find('Passive:',1,true),'gear and passive details render')
C.detailTab='characters';C.RenderDetail()
check(C.detailText.text:find('Amazon',1,true) and C.detailText.text:find('Alt',1,true),'all character access view renders')
C.ShowHelp();check(C.detailText.text:find('/csidekick',1,true),'help explains slash command')
SLASH_COMMANDS['/companions']('scale 1');check(C.window.scale==.55 and C.detail.scale==.55,'minimum scale clamped')
SLASH_COMMANDS['/companions']('scale 999');check(C.window.scale==1.2,'maximum scale clamped')
local count=0;for _ in pairs(timers)do count=count+1 end
C.Schedule();C.Schedule();tick()
check(timers[C.name..'Refresh']==nil,'event bursts debounced')
local update=false;local oldRefresh=C.Refresh;C.Refresh=function()update=true end
events[EVENT_INVENTORY_SINGLE_SLOT_UPDATE](nil,999);check(not timers[C.name..'Refresh'],'unrelated inventory does not scan')
events[EVENT_INVENTORY_SINGLE_SLOT_UPDATE](nil,BAG_COMPANION_WORN);tick();check(update,'companion equipment updates trigger capture')
C.Refresh=oldRefresh
check(#logs==0,'no startup or event chat spam')
check(SLASH_COMMANDS['/csidekick']~=nil,'unique command always registered')
for _,c in ipairs(controls)do
    if c.text=='_' and c.handlers.OnClicked then
        c.handlers.OnClicked();check(C.minimized and C.body:IsHidden() and C.window.height==44,'minimize collapses roster')
        c.handlers.OnClicked();check(not C.minimized and not C.body:IsHidden() and C.window.height==440,'restore expands roster')
    end
end
local primary=SLASH_COMMANDS['/csidekick'];local other=function()end
SLASH_COMMANDS['/companions']=other
C.Init(nil,C.name)
check(SLASH_COMMANDS['/companions']==other,'existing slash alias is preserved')
check(C.db.characters.a.companions[1].rapport==4321,'saved character data survives reload')
local beforeTimers=timers[C.name..'Index'];C.BuildIndexes()
check(timers[C.name..'Index']==beforeTimers and not C.indexing,'cached indexes are reused without rescanning')
C.ShowAppearance()
check(not C.appearanceWindow:IsHidden() and C.appearanceCombos.preset.selected=='Teal','appearance menu opens with original teal theme')
C.appearanceCombos.preset.items[2].fn()
check(C.appearanceCombos.background.selected=='Plum' and C.appearanceCombos.title.selected=='Plum','preset applies across theme parts')
C.appearanceCombos.title.items[4].fn()
check(C.appearanceCombos.title.selected=='Ocean' and C.appearanceCombos.background.selected=='Plum' and C.appearanceCombos.preset.selected=='Custom','mixed colors remain independent')
check(not C.SetAppearance('title','MissingColor') and not C.SetAppearance('missingPart','Plum'),'invalid appearance settings rejected')
local choice=C.db.settings.appearanceByCharacter[C.characterId]
C.ApplyAppearance();check(choice.title=='Ocean','appearance remains saved after redraw')
local previousId=C.characterId;C.characterId='other-character';C.ApplyAppearance()
check(C.appearanceCombos.preset.selected=='Teal','new character receives default colors')
C.characterId=previousId;C.ApplyAppearance()
check(C.appearanceCombos.title.selected=='Ocean','returning character restores chosen colors')
SLASH_COMMANDS['/csidekick']('scale 70')
check(C.window.scale==.7 and C.detail.scale==.7 and C.appearanceWindow.scale==.7 and C.sizeValue.text=='70%','size control updates every window and percentage')
check(not C.SetScalePercent('invalid'),'invalid size ignored')
C.SetScalePercent(85);C.SetAppearance('preset','Teal')
check(C.sizeValue.text=='85%' and C.appearanceCombos.preset.selected=='Teal','default size and colors can be restored')
TEST_RESULT=checks..' companion tracker checks passed'
