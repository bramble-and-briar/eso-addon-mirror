-- Stable game API and Lua references; optional addon APIs are resolved when used.
local pairs, ipairs, tonumber, tostring, type = pairs, ipairs, tonumber, tostring, type
local _G = _G
local math, string, table = math, string, table
local EVENT_MANAGER, SLASH_COMMANDS = EVENT_MANAGER, SLASH_COMMANDS
local BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK = BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK
local EVENT_ADD_ON_LOADED = EVENT_ADD_ON_LOADED
local SI_TOOLTIP_ITEM_NAME = SI_TOOLTIP_ITEM_NAME
local GetItemLinkItemType, GetItemLinkName = GetItemLinkItemType, GetItemLinkName
local GetFrameTimeSeconds, GetTimeStamp = GetFrameTimeSeconds, GetTimeStamp
local zo_callLater, zo_strformat, zo_strlower = zo_callLater, zo_strformat, zo_strlower

SurveySidekick = {name = "SurveySidekick", version = "0.6.2"}
local S = SurveySidekick
local function T(...) return S.Text(...) end
S.Model = {}
local M = S.Model
local Q = SurveySidekickQuantityFilter
function M.NewRun(now)
    return {started=now,seconds=0,running=false,materials={},total=0,
        breakdown={regular=0,survey=0,other=0},pending=0,goal={}}
end
function M.AddMaterial(run,id,link,name,quantity)
    if not run or not run.running or quantity<=0 then return false end
    local mat=run.materials[id]
    if not mat then mat={id=id,link=link,name=name,count=0,regular=0,survey=0,other=0};run.materials[id]=mat end
    mat.count=mat.count+quantity;run.total=run.total+quantity;run.pending=(run.pending or 0)+quantity
    return true
end
function M.Classify(run,id,quantity,bucket)
    local mat=run.materials[id]
    mat[bucket]=(mat[bucket] or 0)+quantity
    run.breakdown[bucket]=(run.breakdown[bucket] or 0)+quantity
    run.pending=math.max(0,(run.pending or 0)-quantity)
end
function M.AddLoot(run,id,link,name,quantity)
    if not run or not run.running or type(quantity)~="number" or quantity~=quantity
        or quantity<=0 or quantity==math.huge then return false end
    run.loot=run.loot or {}
    local key=link or tostring(id)
    local item=run.loot[key]
    if not item then item={id=id,link=link,name=name,count=0};run.loot[key]=item end
    item.count=item.count+quantity
    run.lootTotal=(run.lootTotal or 0)+quantity
    return true
end
function S.SortedLoot(run)
    local rows={};for _,item in pairs(run and run.loot or {})do rows[#rows+1]=item end
    table.sort(rows,function(a,b)return S.MaterialName(a)<S.MaterialName(b)end)
    return rows
end
function M.Migrate(run)
    -- Preserve old totals; historical loot cannot be reconstructed into node-sized pulls.
    if not run then return end
    local totals={regular=0,survey=0,other=0}
    for _,mat in pairs(run.materials or {}) do
        mat.regular=mat.regular or 0;mat.survey=mat.survey or 0;mat.other=mat.other or 0
        local missing=math.max(0,mat.count-mat.regular-mat.survey-mat.other)
        if missing>0 then mat.other=mat.other+missing;run.legacyClassification=true end
        totals.regular=totals.regular+mat.regular;totals.survey=totals.survey+mat.survey;totals.other=totals.other+mat.other
    end
    run.breakdown=totals;run.pending=0
end
function M.Total(items)
    local sum=0;for _,v in pairs(items or {})do sum=sum+v.count end;return sum
end
function M.UpdateRecords(records,run)
    local new={}
    if run.total>(records.haul or 0) then records.haul=run.total;new[1]="haul" end
    return new
end
function M.GoalProgress(run)
    local g=run.goal or {};if not g.id or not g.target then return 0,0 end
    return run.materials[g.id] and run.materials[g.id].count or 0,g.target
end
function S.Link(id)
    return string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",id)
end
function S.Say(text) d("|c68D9DBSurvey Sidekick|r: "..T(text)) end
function S.Clean(text)
    return (tostring(text or ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[\t\r\n]", " "))
end
function S.Time(seconds)
    seconds=math.floor(seconds or 0);return string.format("%02d:%02d:%02d",math.floor(seconds/3600),math.floor(seconds/60)%60,seconds%60)
end
function S.Refresh()
    S.dirty=true
    if not S.ui or S.ui:IsHidden() or S.paintQueued then return end
    S.paintQueued=true
    -- Coalesce loot bursts without delaying the actual material accounting.
    zo_callLater(function()
        S.paintQueued=false
        if S.ui and not S.ui:IsHidden() and S.dirty then S.Render()end
    end,100)
end
function S.CountBackpack()
    local n=0;for _,v in pairs(S.inventory or {}) do n=n+v.count end;return n
end
local CRAFTS={blacksmith="Blacksmithing",clothier="Clothing",woodworker="Woodworking",alchemist="Alchemy",enchanter="Enchanting",jewelry="Jewelry"}
function S.Craft(pin)
    for pattern,craft in pairs(CRAFTS) do if (pin.texture or ""):find(pattern,1,true) then return craft end end
    return "Other"
end
function S.BuildLocations()
    S.locations={};S.treasureLocations={}
    if not LibTreasure_GetAllItemsData then return end
    local chosen={}
    local function remember(id,pin)
        if pin.pinType=="survey" or pin.pinType=="treasure" then chosen[id]=pin end
    end
    for id,pin in pairs(LibTreasure_GetAllItemsData())do remember(id,pin)end
    -- Prefer zone-map records for both surveys and treasure maps.
    if LibTreasure_GetMapIdData then
        for index=1,GetNumMaps()do
            local mapId=GetMapIdByIndex(index)
            local _,kind=GetMapInfoById(mapId)
            if kind==MAPTYPE_ZONE then
                for _,pin in ipairs(LibTreasure_GetMapIdData(mapId) or {})do remember(pin.itemId,pin)end
            end
        end
    end
    for id,pin in pairs(chosen)do
        if type(pin.mapId)=="number" and type(pin.x)=="number" and type(pin.y)=="number"
            and pin.x>=0 and pin.x<=1 and pin.y>=0 and pin.y<=1 then
            local location={id=id,mapId=pin.mapId,x=pin.x,y=pin.y,zone=GetMapNameById(pin.mapId)}
            if pin.pinType=="survey" then
                location.craft=S.Craft(pin);S.locations[id]=location
            else S.treasureLocations[id]=location end
        end
    end
end
function S.Scan()
    local backpack=S.ReadMapBag(BAG_BACKPACK)
    local surveys,treasures={},{}
    for id,item in pairs(backpack)do
        if item.kind=="survey" then
            local loc=S.locations[id]
            item.zone=item.unidentified and "Unidentified / Unopened" or (loc and loc.zone or "Location unavailable")
            item.craft=item.craft or (loc and loc.craft or "Other")
            surveys[id]=item
        else treasures[id]=item end
    end
    S.inventory=surveys;S.treasureInventory=treasures
    if IsBankOpen() then
        local bankItems,bankSurveys={},{}
        for _,bag in ipairs({BAG_BANK,BAG_SUBSCRIBER_BANK})do
            for id,item in pairs(S.ReadMapBag(bag))do
                if bankItems[id] then bankItems[id].count=bankItems[id].count+item.count
                else bankItems[id]=item end
                if item.kind=="survey" then bankSurveys[id]=(bankSurveys[id] or 0)+item.count end
            end
        end
        S.db.bankItems=bankItems;S.db.bank=bankSurveys;S.db.bankSeen=GetTimeStamp()
    end
    if S.RenderDetours then S.RenderDetours()end
    if S.RenderCatalog then S.RenderCatalog()end
    S.Refresh()
end
function S.QueueScan()
    if S.scanQueued then return end;S.scanQueued=true
    zo_callLater(function()S.scanQueued=false;S.Scan()end,250)
end
function S.StartRun()
    if not S.character.run then S.character.run=M.NewRun(GetTimeStamp()) end
    local run=S.character.run
    if run.running then return end
    run.running=true;S.tick=GetFrameTimeSeconds();S.Say("Run started. All crafting materials looted during the run will count.");S.Refresh()
end
function S.UpdateTimer()
    local r=S.character.run
    local now=GetFrameTimeSeconds()
    if r and r.running and S.tick and not S.loading then r.seconds=r.seconds+math.max(0,now-S.tick) end
    S.tick=now
end
function S.PauseRun()
    Q.FlushAll()
    S.UpdateTimer();if S.character.run then S.character.run.running=false end
    S.Say("Run paused.");S.Refresh()
end
function S.Ping()
    local sounds = SOUNDS
    if sounds and sounds.ACHIEVEMENT_AWARDED then PlaySound(sounds.ACHIEVEMENT_AWARDED) end
end
function S.EndRun()
    local run=S.character.run
    if not run then S.Say("No run to finish.");return end
    Q.FlushAll()
    S.UpdateTimer();run.running=false;run.finished=GetTimeStamp()
    run.newRecords=M.UpdateRecords(S.db.records,run)
    table.insert(S.db.history,1,run)
    while #S.db.history>30 do table.remove(S.db.history) end
    S.character.run=nil;S.reportIndex=1
    S.Say(T("The Hoard Report is ready: %d materials, %s.",run.total,S.Time(run.seconds)))
    if #run.newRecords>0 then S.Say("New personal record! Your hoard is getting out of hand.");S.Ping() end
    S.tab="report";S.Refresh()
end
function S.UnitPrice(id,link)
    local manual=S.db.prices[id]
    if manual and manual>0 then return manual,"manual" end
    local ttc = TamrielTradeCentrePrice
    if ttc and type(ttc.GetPriceInfo)=="function" then
        local p = ttc:GetPriceInfo(link)
        if p then
            local amount=tonumber(p.SuggestedPrice)
            if not amount or amount<=0 then amount=tonumber(p.Avg) end
            if amount and amount>0 then return amount,"TTC" end
        end
    end
end
function S.Value(materials)
    local value,unpriced=0,0
    for id,v in pairs(materials) do
        local price=S.UnitPrice(v.id or id,v.link)
        if price then value=value+price*v.count else unpriced=unpriced+v.count end
    end
    return value,unpriced
end
function S.Report(run,tsv)
    if not run then return T("No report yet. Start a run and go claim your hoard.") end
    local value,unpriced=S.Value(run.materials)
    local b=run.breakdown or {regular=0,survey=0,other=run.total}
    local rows={T("THE HOARD REPORT"),T("Materials looted: %d | Active time: %s",run.total,S.Time(run.seconds)),
        T("Regular-sized: %d | Survey/Large: %d | Other: %d",b.regular,b.survey,b.other),
        "Survey/Large is an estimate and may include other unusually large material drops.",
        T("Estimated value: %.0fg | Unpriced items: %d (not included)",value,unpriced),
        "Values use current TTC suggestions/averages or manual prices; not guaranteed sale proceeds.",""}
    if run.legacyClassification then rows[#rows+1]="Older/unresolved loot is kept under Other; the original split is unavailable." end
    if tsv then rows[#rows+1]="Item ID\tMaterial\tQuantity\tRegular-sized\tSurvey/Large\tOther\tUnit estimate\tTotal estimate" end
    local sorted={};for _,v in pairs(run.materials)do sorted[#sorted+1]=v end
    table.sort(sorted,function(a,b)if a.count==b.count then return a.name<b.name end;return a.count>b.count end)
    for _,v in ipairs(sorted)do
        local p=S.UnitPrice(v.id,v.link)
        if tsv then
            rows[#rows+1]=table.concat({v.id,S.Clean(S.MaterialName(v)),v.count,v.regular or 0,v.survey or 0,v.other or v.count,p or "",p and string.format("%.0f",p*v.count) or ""},"\t")
        else
            rows[#rows+1]=T("%s x%d | Regular %d / Survey-Large %d / Other %d",S.MaterialName(v),v.count,v.regular or 0,v.survey or 0,v.other or v.count)
        end
    end
    if run.loot and next(run.loot) then
        local lootValue,lootMissing=S.Value(run.loot)
        rows[#rows+1]="";rows[#rows+1]=T("OTHER LOOT")
        rows[#rows+1]=T("Estimated value: %.0fg | Unpriced items: %d (not included)",lootValue,lootMissing)
        if tsv then rows[#rows+1]="Item ID\tItem\tQuantity\tUnit estimate\tTotal estimate"end
        for _,item in ipairs(S.SortedLoot(run))do
            local price=S.UnitPrice(item.id,item.link)
            rows[#rows+1]=tsv and table.concat({item.id,S.Clean(S.MaterialName(item)),item.count,price or "",price and string.format("%.0f",price*item.count) or ""},"\t")
                or (S.MaterialName(item).." x"..item.count)
        end
    end
    rows[#rows+1]="";rows[#rows+1]=T("PERSONAL RECORD: %d materials in one run",S.db.records.haul or 0)
    for i,row in ipairs(rows)do rows[i]=T(row)end
    return table.concat(rows,"\n")
end
S.GoalCrafts={"Alchemy","Blacksmithing","Clothing","Enchanting","Jewelry","Woodworking","Other materials"}
local GOAL_TYPES={
    Alchemy={"REAGENT","POTION_BASE","POISON_BASE"},
    Blacksmithing={"BLACKSMITHING_RAW_MATERIAL","BLACKSMITHING_MATERIAL","BLACKSMITHING_BOOSTER"},
    Clothing={"CLOTHIER_RAW_MATERIAL","CLOTHIER_MATERIAL","CLOTHIER_BOOSTER"},
    Enchanting={"ENCHANTING_RUNE_ASPECT","ENCHANTING_RUNE_ESSENCE","ENCHANTING_RUNE_POTENCY"},
    Jewelry={"JEWELRYCRAFTING_RAW_MATERIAL","JEWELRYCRAFTING_MATERIAL","JEWELRYCRAFTING_RAW_BOOSTER","JEWELRYCRAFTING_BOOSTER","JEWELRY_TRAIT","JEWELRY_RAW_TRAIT"},
    Woodworking={"WOODWORKING_RAW_MATERIAL","WOODWORKING_MATERIAL","WOODWORKING_BOOSTER"}
}
function S.GoalCraftFor(kind,special)
    for craft,names in pairs(GOAL_TYPES)do
        for _,name in ipairs(names)do if _G["ITEMTYPE_"..name] and kind==_G["ITEMTYPE_"..name] then return craft end end
    end
    local furniture={Alchemy="ALCHEMY",Blacksmithing="BLACKSMITHING",Clothing="CLOTHIER",Enchanting="ENCHANTING",Jewelry="JEWELRYCRAFTING",Woodworking="WOODWORKING"}
    for craft,name in pairs(furniture)do
        local value=_G["SPECIALIZED_ITEMTYPE_FURNISHING_MATERIAL_"..name]
        if value and value==special then return craft end
    end
    return "Other materials"
end
function S.RegisterGoalMaterial(id,link,name)
    id=tonumber(id);if not id or id<1 then return end
    S.goalCatalog=S.goalCatalog or {}
    if S.goalCatalog[id] then return S.goalCatalog[id] end
    link=link or S.Link(id)
    local kind,special=GetItemLinkItemType(link)
    if not S.materialTypes[kind] then return end
    name=name or zo_strformat(SI_TOOLTIP_ITEM_NAME,GetItemLinkName(link))
    if not name or name=="" then return end
    local entry={id=id,link=link,name=name,craft=S.GoalCraftFor(kind,special)}
    S.goalCatalog[id]=entry;return entry
end
function S.BuildGoalCatalog()
    S.goalCatalog={}
    for _,id in ipairs(SurveySidekickGoalItemIds or {})do S.RegisterGoalMaterial(id)end
    local run=S.character.run
    if run then
        for id,v in pairs(run.materials or {})do S.RegisterGoalMaterial(id,v.link,v.name)end
        if run.goal and run.goal.id then S.RegisterGoalMaterial(run.goal.id)end
    end
    for _,r in ipairs(S.db.history)do
        for id,v in pairs(r.materials or {})do S.RegisterGoalMaterial(id,v.link,v.name)end
    end
end
function S.GoalChoices(craft)
    local items={}
    for _,entry in pairs(S.goalCatalog or {})do if entry.craft==craft then items[#items+1]=entry end end
    table.sort(items,function(a,b)return zo_strlower(a.name)<zo_strlower(b.name)end)
    return items
end
function S.SetGoal(id,target)
    id,target=tonumber(id),tonumber(target)
    if not id or id<1 or id%1~=0 or not target or target<1 or target%1~=0 then
        S.Say("Choose a survey type and material, enter a positive whole-number quantity, then click Set Goal.");return
    end
    local entry=S.RegisterGoalMaterial(id)
    if not entry then S.Say("Choose a supported material from the dropdown.");return end
    if not S.character.run then S.StartRun() end
    S.character.goalItemId=id;S.character.goalCraft=entry.craft
    S.character.run.goal={id=id,target=target,name=entry.name};S.Refresh()
end
local MATERIAL_NAMES={"ITEMTYPE_BLACKSMITHING_RAW_MATERIAL","ITEMTYPE_CLOTHIER_RAW_MATERIAL","ITEMTYPE_WOODWORKING_RAW_MATERIAL",
    "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL","ITEMTYPE_REAGENT","ITEMTYPE_ENCHANTING_RUNE_ASPECT","ITEMTYPE_ENCHANTING_RUNE_ESSENCE",
    "ITEMTYPE_ENCHANTING_RUNE_POTENCY","ITEMTYPE_FURNISHING_MATERIAL","ITEMTYPE_STYLE_MATERIAL","ITEMTYPE_RAW_MATERIAL",
    "ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER","ITEMTYPE_SCRIBING_INK","ITEMTYPE_POTION_BASE","ITEMTYPE_POISON_BASE",
    "ITEMTYPE_BLACKSMITHING_MATERIAL","ITEMTYPE_CLOTHIER_MATERIAL","ITEMTYPE_WOODWORKING_MATERIAL","ITEMTYPE_JEWELRYCRAFTING_MATERIAL",
    "ITEMTYPE_BLACKSMITHING_BOOSTER","ITEMTYPE_CLOTHIER_BOOSTER","ITEMTYPE_WOODWORKING_BOOSTER","ITEMTYPE_JEWELRYCRAFTING_BOOSTER",
    "ITEMTYPE_ARMOR_TRAIT","ITEMTYPE_WEAPON_TRAIT","ITEMTYPE_JEWELRY_TRAIT","ITEMTYPE_JEWELRY_RAW_TRAIT","ITEMTYPE_INGREDIENT","ITEMTYPE_LURE"}
S.materialTypes={};for _,name in ipairs(MATERIAL_NAMES) do if _G[name] then S.materialTypes[_G[name]]=true end end
function S.Loot(_,receivedBy,itemName,quantity,soundCategory,lootType,isSelf,isPickpocket,questIcon,itemId,isStolen)
    local run=S.character.run
    if not run or not run.running or not isSelf or not itemId or itemId<=0 then return end
    local link=itemName and itemName:find("|H",1,true) and itemName or S.Link(itemId)
    local kind=GetItemLinkItemType(link)
    local name=zo_strformat(SI_TOOLTIP_ITEM_NAME,GetItemLinkName(link))
    if not S.materialTypes[kind] then
        if M.AddLoot(run,itemId,link,name,quantity)then S.Refresh()end
        return
    end
    S.RegisterGoalMaterial(itemId,link,name)
    if M.AddMaterial(run,itemId,link,name,quantity) then
        local category=Q.Category(kind,name)
        if category=="Runes" then
            Q.QueueRunes("self",quantity,function(blocked)
                M.Classify(run,itemId,quantity,blocked and "survey" or "regular")
                S.Refresh()
            end)
        else
            local limit=Q.Limit(category)
            M.Classify(run,itemId,quantity,limit and (quantity>limit and "survey" or "regular") or "other")
        end
        local current,target=M.GoalProgress(run)
        if target>0 and current>=target and not run.goal.announced then
            run.goal.announced=true;S.Say(T("Material goal reached: %s x%d!",S.MaterialName({id=run.goal.id,name=run.goal.name or name}),target));S.Ping()
        end
        S.Refresh()
    end
end
function S.Command(args)
    local cmd,tail=(args or ""):match("^%s*(%S*)%s*(.-)%s*$");cmd=string.lower(cmd)
    if cmd=="start" then S.StartRun()
    elseif cmd=="pause" then S.PauseRun()
    elseif cmd=="finish" then S.EndRun()
    elseif cmd=="goal" then
        local id,n=tail:match("^(%d+)%s+(%d+)$")
        if id then S.SetGoal(id,n)else
            S.tab="run"
            if S.character.minimized then S.SetMinimized(false)end
            S.SetWindowVisible(true)
        end
    elseif cmd=="price" then
        local id,price=tail:match("^(%d+)%s+([%d%.]+)$");id,price=tonumber(id),tonumber(price)
        if id and price and price>=0 then S.db.prices[id]=price>0 and price or nil;S.Say("Manual price updated.");S.Refresh()
        else S.Say("/surveys price ITEM_ID GOLD_EACH (0 clears it).") end
    elseif cmd=="journal" then S.OpenJournal()
    elseif cmd=="inventory" then S.ShowCatalog()
    elseif cmd=="detour" then S.ShowDetours()
    elseif cmd=="compare" then S.ShowAccountant()
    elseif cmd=="colors" then S.ShowAppearance()
    elseif cmd=="opacity" then S.SetOpacityPercent(tail)
    elseif cmd=="buttons" then S.SetButtonOpacityPercent(tail)
    elseif cmd=="scale" then S.SetScalePercent(tail)
    elseif cmd=="help" then S.ShowExport(S.Help(),"Survey Sidekick Help")
    elseif cmd=="" then S.SetWindowVisible(S.ui:IsHidden());S.Scan()
    else S.Say("Use /surveys help for commands.") end
end
function S.MaterialName(material)
    local link=material.link or (material.id and S.Link(material.id))
    local name=link and GetItemLinkName(link)
    if name and name~="" then return zo_strformat(SI_TOOLTIP_ITEM_NAME,name)end
    return material.name or tostring(material.id or "")
end
function S.Help()
    if S.journalUtilityMode then
        return "SURVEYS & MAPS\nClick the map icon, then a zone to see your surveys and treasure maps. Filter by item type, storage or survey type. Select an item to use Hint, Open, Map Pin, cost preview or travel when available. Withdraw bank-only items before opening or traveling. Open unidentified containers from your backpack.\n\nCURRENT RUN\nClick the bag icon. Play starts or resumes tracking. Pause pauses it. Stop finishes and saves the run. Choose a material and quantity to set a gathering goal. Other Loot includes item drops collected while your run is active, including treasure-chest items.\n\nTHE HOARD REPORT\nClick the book icon to view saved runs, material totals and Other Loot. Use the arrows for older/newer reports, Copy or Export for shareable text, or Compare Runs for the Petty Accountant. Gold values and survey classifications are estimates.\n\nTREASURE DETOUR\nSelect a survey to see carried treasure maps for the same zone.\n\nUse Back to return from a page, or ESO's Exit control to leave Extended Journal."
    end
    return T("CLEANUP_HELP").."\n\n"..T("DETOUR_ACCOUNTANT_HELP").."\n\n"..T("HINT_OPEN_HELP")
end
function S.Init(_,name)
    if name~=S.name then return end
    EVENT_MANAGER:UnregisterForEvent(S.name,EVENT_ADD_ON_LOADED)
    S.db=ZO_SavedVars:NewAccountWide("SurveySidekickSavedVariables",1,GetWorldName(),{characters={},history={},records={},prices={},bank={}})
    local id=tostring(GetCurrentCharacterId());S.db.characters[id]=S.db.characters[id] or {};S.character=S.db.characters[id]
    if S.character.run then S.character.run.running=false end
    if S.character.visit then S.character.legacyVisit=S.character.visit;S.character.visit=nil end
    M.Migrate(S.character.run)
    for _,run in ipairs(S.db.history)do M.Migrate(run)end
    S.tab=({surveys=true,run=true,report=true})[S.character.lastTab] and S.character.lastTab or "surveys"
    S.craftFilter=({All=true,Blacksmithing=true,Clothing=true,Woodworking=true,Alchemy=true,Enchanting=true,Jewelry=true,Other=true})[S.character.craftFilter] and S.character.craftFilter or "All"
    S.reportIndex=1
    S.BuildLocations();S.BuildGoalCatalog();S.Scan();S.CreateUI();S.RegisterJournal()
    SLASH_COMMANDS["/surveys"]=S.Command
    SLASH_COMMANDS["/surveyport"]=function()S.TravelCatalog(false)end
    EVENT_MANAGER:RegisterForEvent(S.name,EVENT_LOOT_RECEIVED,S.Loot)
    EVENT_MANAGER:RegisterForEvent(S.name,EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,bag)if bag==BAG_BACKPACK or bag==BAG_BANK or bag==BAG_SUBSCRIBER_BANK then S.QueueScan()end end)
    EVENT_MANAGER:RegisterForEvent(S.name,EVENT_OPEN_BANK,S.QueueScan)
    EVENT_MANAGER:RegisterForEvent(S.name,EVENT_PLAYER_ACTIVATED,function()S.loading=false;S.tick=GetFrameTimeSeconds();S.QueueScan()end)
    EVENT_MANAGER:RegisterForEvent(S.name,EVENT_PLAYER_DEACTIVATED,function()Q.FlushAll();S.UpdateTimer();S.SaveWindowState();S.loading=true;S.tick=nil end)
    EVENT_MANAGER:RegisterForUpdate(S.name,1000,function()
        S.UpdateTimer()
        local run=S.character.run
        local liveTimer=run and run.running and (S.tab=="run" or S.character.minimized)
        if not S.ui:IsHidden() and (S.dirty or liveTimer)then S.Render()end
    end)
end
EVENT_MANAGER:RegisterForEvent(S.name,EVENT_ADD_ON_LOADED,S.Init)
