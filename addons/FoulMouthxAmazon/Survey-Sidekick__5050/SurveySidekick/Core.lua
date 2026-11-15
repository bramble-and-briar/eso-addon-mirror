-- Stable game API and Lua references; optional addon APIs are resolved when used.
local pairs, ipairs, tonumber, tostring, type = pairs, ipairs, tonumber, tostring, type
local _G = _G
local math, string, table = math, string, table
local EVENT_MANAGER, SLASH_COMMANDS = EVENT_MANAGER, SLASH_COMMANDS
local BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK = BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK
local EVENT_ADD_ON_LOADED = EVENT_ADD_ON_LOADED
local LINK_STYLE_DEFAULT, SI_TOOLTIP_ITEM_NAME = LINK_STYLE_DEFAULT, SI_TOOLTIP_ITEM_NAME
local SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT = SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT
local GetBagSize, GetItemInfo, GetItemLink = GetBagSize, GetItemInfo, GetItemLink
local GetItemLinkItemId, GetItemLinkItemType, GetItemLinkName = GetItemLinkItemId, GetItemLinkItemType, GetItemLinkName
local GetFrameTimeSeconds, GetTimeStamp = GetFrameTimeSeconds, GetTimeStamp
local zo_callLater, zo_strformat, zo_strlower = zo_callLater, zo_strformat, zo_strlower

SurveySidekick = {name = "SurveySidekick", version = "0.2.3-beta"}
local S = SurveySidekick
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
function S.Say(text) d("|c68D9DBSurvey Sidekick|r: "..text) end
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
    S.locations={}
    if not LibTreasure_GetAllItemsData then return end
    local data=LibTreasure_GetAllItemsData()
    local chosen={}
    for id,pin in pairs(data) do if pin.pinType=="survey" then chosen[id]=pin end end
    -- Walk the map catalog once, rather than once per survey.
    if LibTreasure_GetMapIdData then
        for index=1,GetNumMaps() do
            local mapId=GetMapIdByIndex(index)
            local _,kind=GetMapInfoById(mapId)
            if kind==MAPTYPE_ZONE then
                for _,pin in ipairs(LibTreasure_GetMapIdData(mapId) or {}) do
                    if pin.pinType=="survey" then chosen[pin.itemId]=pin end
                end
            end
        end
    end
    for id,pin in pairs(chosen) do
        S.locations[id]={id=id,mapId=pin.mapId,x=pin.x,y=pin.y,zone=GetMapNameById(pin.mapId),craft=S.Craft(pin)}
    end
end
function S.Scan()
    local items={}
    for slot=0,GetBagSize(BAG_BACKPACK)-1 do
        local link=GetItemLink(BAG_BACKPACK,slot,LINK_STYLE_DEFAULT)
        if link~="" then
            local _,special=GetItemLinkItemType(link)
            if special==SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
                local id=GetItemLinkItemId(link);local _,count=GetItemInfo(BAG_BACKPACK,slot)
                if not items[id] then
                    local loc=S.locations[id]
                    items[id]={id=id,link=link,name=zo_strformat(SI_TOOLTIP_ITEM_NAME,GetItemLinkName(link)),count=0,
                        zone=loc and loc.zone or "Location unavailable",craft=loc and loc.craft or "Other"}
                end
                items[id].count=items[id].count+count
            end
        end
    end
    S.inventory=items
    if IsBankOpen() then
        local bank={}
        for _,bag in ipairs({BAG_BANK,BAG_SUBSCRIBER_BANK}) do
            for slot=0,GetBagSize(bag)-1 do
                local link=GetItemLink(bag,slot,LINK_STYLE_DEFAULT)
                if link~="" then
                    local _,special=GetItemLinkItemType(link)
                    if special==SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
                        local id=GetItemLinkItemId(link);local _,count=GetItemInfo(bag,slot)
                        bank[id]=(bank[id] or 0)+count
                    end
                end
            end
        end
        S.db.bank=bank;S.db.bankSeen=GetTimeStamp()
    end
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
    S.Say("The Hoard Report is ready: "..run.total.." materials, "..S.Time(run.seconds)..".")
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
        local price=S.UnitPrice(id,v.link)
        if price then value=value+price*v.count else unpriced=unpriced+v.count end
    end
    return value,unpriced
end
function S.Report(run,tsv)
    if not run then return "No report yet. Start a run and go claim your hoard." end
    local value,unpriced=S.Value(run.materials)
    local b=run.breakdown or {regular=0,survey=0,other=run.total}
    local rows={"THE HOARD REPORT","Materials looted: "..run.total.." | Active time: "..S.Time(run.seconds),
        "Regular-sized: "..b.regular.." | Survey/Large: "..b.survey.." | Other: "..b.other,
        "Survey/Large is an estimate and may include other unusually large material drops.",
        string.format("Estimated value: %.0fg | Unpriced items: %d (not included)",value,unpriced),
        "Values use current TTC suggestions/averages or manual prices; not guaranteed sale proceeds.",""}
    if run.legacyClassification then rows[#rows+1]="Older/unresolved loot is kept under Other; the original split is unavailable." end
    if tsv then rows[#rows+1]="Item ID\tMaterial\tQuantity\tRegular-sized\tSurvey/Large\tOther\tUnit estimate\tTotal estimate" end
    local sorted={};for _,v in pairs(run.materials)do sorted[#sorted+1]=v end
    table.sort(sorted,function(a,b)if a.count==b.count then return a.name<b.name end;return a.count>b.count end)
    for _,v in ipairs(sorted)do
        local p=S.UnitPrice(v.id,v.link)
        if tsv then
            rows[#rows+1]=table.concat({v.id,S.Clean(v.name),v.count,v.regular or 0,v.survey or 0,v.other or v.count,p or "",p and string.format("%.0f",p*v.count) or ""},"\t")
        else
            rows[#rows+1]=v.name.." x"..v.count.." | Regular "..(v.regular or 0).." / Survey-Large "..(v.survey or 0).." / Other "..(v.other or v.count)
        end
    end
    rows[#rows+1]="";rows[#rows+1]="PERSONAL RECORD: "..(S.db.records.haul or 0).." materials in one run"
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
    if not S.materialTypes[kind] then return end
    local name=zo_strformat(SI_TOOLTIP_ITEM_NAME,GetItemLinkName(link))
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
            run.goal.announced=true;S.Say("Material goal reached: "..(run.goal.name or name).." x"..target.."!");S.Ping()
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
    elseif cmd=="colors" then S.ShowAppearance()
    elseif cmd=="scale" then S.SetScalePercent(tail)
    elseif cmd=="help" then S.ShowExport(S.Help())
    elseif cmd=="" then S.SetWindowVisible(S.ui:IsHidden());S.Scan()
    else S.Say("Use /surveys help for commands.") end
end
function S.Help()
    return "SURVEY SIDEKICK — HOW TO USE\n\nSTART A GATHERING RUN\n1. Type /surveys to open the window.\n2. Open Current Run and click Start / Resume.\n3. Gather materials. Your quantities and timer update automatically.\n4. Click Pause for a break; Start / Resume continues the same run.\n5. Click Finish Run to save your results in The Hoard Report.\n\nSET A COLLECTION GOAL\nIn Current Run, choose a Survey Type, choose a material by name, enter the quantity you want, then click Set Goal. Progress includes that material already gathered during the current run. You will get a message and sound when you reach the target.\n\nFIND AND TRAVEL TO SURVEYS\nPut your surveys in your backpack. In My Surveys, select a survey from the list. Survey Type beside The Hoard Report cycles through the crafting types.\n• Map icon: open the survey map and place a waypoint.\n• Wayshrine icon: travel to its closest unlocked wayshrine. Normal travel costs apply.\n• Gold coin: preview the destination and recall quote without traveling.\n• Circular arrow: refresh the list and duplicate counts. The list also updates automatically.\nLibTreasure is needed for survey locations and travel. Bank counts are refreshed while your bank is open.\n\nREAD AND COPY YOUR RESULTS\nFinish a run, then open The Hoard Report. Newer / Older browse saved runs. Copy Summary opens a short message to copy; Export Details opens the full list. Click the text and use Ctrl+A, then Ctrl+C. Nothing is sent automatically. Price estimates appear when price data is available.\n\nWINDOW CONTROLS\nClick Colors in the title bar or type /surveys colors to choose a preset, background, title bar and border colors. Changes apply instantly and save for this character. Reset Colors restores Plum.\nMinus minimizes to a live tracker bar. Plus restores the full window. Gathering keeps counting while minimized. Close hides the window; /surveys reopens it. Its position and open/closed state are remembered. Hover over buttons for their descriptions.\nUse /surveys scale 70 for a smaller window, or /surveys scale 80 for the default.\n\nCOMMANDS\n/surveys — open or close\n/surveys start — start or resume\n/surveys pause — pause\n/surveys finish — save the run\n/surveys goal — open collection setup\n/surveyport — travel to the selected survey\n/surveys help — show this guide\n\nAfter /reloadui or login, click Start / Resume to continue a saved run."
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
    S.tab="surveys";S.craftFilter="All";S.reportIndex=1
    S.BuildLocations();S.BuildGoalCatalog();S.Scan();S.CreateUI()
    SLASH_COMMANDS["/surveys"]=S.Command
    SLASH_COMMANDS["/surveyport"]=function()S.Travel(false)end
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
