-- Survey/map metadata is readable without opening or consuming the items.
local S=SurveySidekick
local T=S.Text
local pairs,ipairs,tonumber,type=pairs,ipairs,tonumber,type
local sort=table.sort
local GetBagSize,GetItemLink,GetItemInfo=GetBagSize,GetItemLink,GetItemInfo
local GetItemLinkItemType,GetItemLinkItemId=GetItemLinkItemType,GetItemLinkItemId
local LINK_STYLE_DEFAULT=LINK_STYLE_DEFAULT
local BAG_BACKPACK=BAG_BACKPACK
local EVENT_MANAGER,EVENT_SHOW_BOOK,EVENT_HIDE_BOOK=EVENT_MANAGER,EVENT_SHOW_BOOK,EVENT_HIDE_BOOK
local SURVEY=SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT
local TREASURE=SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP
-- ESO item IDs, cross-checked in the U47/U49 ESOUI developer threads.
-- Explicit IDs avoid matching unrelated stackable containers or English names.
local unopened={
    [219849]={kind="survey",craft="Blacksmithing"},
    [219850]={kind="survey",craft="Clothing"},
    [219851]={kind="survey",craft="Woodworking"},
    [219852]={kind="survey",craft="Enchanting"},
    [219853]={kind="survey",craft="Alchemy"},
    [219854]={kind="survey",craft="Jewelry"},
    [224681]={kind="treasure"},
}
function S.UnidentifiedInfo(id)return unopened[id]end

function S.ReadMapBag(bag)
    local items={}
    for slot=0,GetBagSize(bag)-1 do
        local link=GetItemLink(bag,slot,LINK_STYLE_DEFAULT)
        if link~="" then
            local _,special=GetItemLinkItemType(link)
            local id=GetItemLinkItemId(link)
            local kind
            local sealed=unopened[id]
            if sealed then kind=sealed.kind
            elseif SURVEY and special==SURVEY then kind="survey"
            elseif (TREASURE and special==TREASURE) or (S.treasureLocations and S.treasureLocations[id]) then kind="treasure" end
            if kind then
                local _,count=GetItemInfo(bag,slot)
                local item=items[id]
                if not item then
                    item={id=id,link=link,kind=kind,count=0,unidentified=sealed~=nil,craft=sealed and sealed.craft}
                    item.name=S.MaterialName(item);items[id]=item
                end
                item.count=item.count+count
            end
        end
    end
    return items
end

function S.BankMapItems()
    if type(S.db.bankItems)=="table" then return S.db.bankItems end
    -- Preserve survey counts from older versions until a full bank scan is possible.
    local items={}
    for id,count in pairs(S.db.bank or {})do
        id=tonumber(id)
        if id and type(count)=="number" and count>0 then
            items[id]={id=id,link=S.Link(id),kind="survey",count=count}
        end
    end
    return items
end

function S.InventoryEntries(kind,source,zoneId)
    local merged={}
    local function add(items,where,fallbackKind)
        for id,item in pairs(items or {})do
            if (item.count or 0)>0 then
                local row=merged[id]
                if not row then
                    local sealed=unopened[id]
                    local itemKind=sealed and sealed.kind or item.kind or fallbackKind
                    local location=not sealed and (itemKind=="survey" and S.locations or S.treasureLocations or {})[id]
                    row={id=id,link=item.link or S.Link(id),kind=itemKind,backpack=0,bank=0,
                        unidentified=sealed~=nil,craft=sealed and sealed.craft or item.craft or (location and location.craft),
                        zone=sealed and "Unidentified / Unopened" or (location and location.zone or "Location unavailable"),mapId=location and location.mapId}
                    row.name=S.MaterialName(item);merged[id]=row
                end
                row[where]=row[where]+item.count
            end
        end
    end
    add(S.inventory,"backpack","survey");add(S.treasureInventory,"backpack","treasure")
    add(S.BankMapItems(),"bank")
    local rows={}
    for _,row in pairs(merged)do
        local included=(source=="backpack" and row.backpack>0) or (source=="bank" and row.bank>0)
            or (source~="backpack" and source~="bank")
        if included and (kind~="survey" and kind~="treasure" or row.kind==kind)
            and (not zoneId or row.mapId==zoneId) then rows[#rows+1]=row end
    end
    sort(rows,function(a,b)if a.zone==b.zone then return a.name<b.name end;return a.zone<b.zone end)
    return rows
end

function S.InventoryZoneGroups(entries,source)
    local groups,byKey={},{}
    for _,item in ipairs(entries)do
        local key=item.unidentified and "unidentified" or (item.mapId and tostring(item.mapId) or "unknown")
        local group=byKey[key]
        if not group then
            group={key=key,name=item.zone,items={},surveys=0,maps=0};byKey[key]=group;groups[#groups+1]=group
        end
        group.items[#group.items+1]=item
        local kind=item.kind=="survey" and "surveys" or "maps"
        local count=source=="backpack" and item.backpack or (source=="bank" and item.bank or item.backpack+item.bank)
        group[kind]=group[kind]+count
    end
    sort(groups,function(a,b)
        if a.key=="unidentified" then return b.key~="unidentified" end
        if b.key=="unidentified" then return false end
        if a.key=="unknown" then return false end
        if b.key=="unknown" then return true end
        if a.name==b.name then return a.key<b.key end
        return a.name<b.name
    end)
    for _,group in ipairs(groups)do
        sort(group.items,function(a,b)
            if a.kind~=b.kind then return a.kind=="survey" end
            if a.name==b.name then return a.id<b.id end
            return a.name<b.name
        end)
    end
    return groups
end

function S.PinCatalogItem()
    S.Scan()
    local id=S.catalogSelected
    for _,item in ipairs(S.InventoryEntries("all","both"))do
        if item.id==id then
            if item.unidentified then S.Say("Identify this item from your backpack before placing a waypoint.");return end
            local location=(item.kind=="survey" and S.locations or S.treasureLocations or {})[id]
            if not location then
                S.Say("Install/update LibTreasure to preview item locations.");return
            end
            S.ShowMap(location);return
        end
    end
    S.Say("Select an item from Surveys & Maps first.")
end

local function FindMap(id)
    if not id then return end
    for _,item in ipairs(S.InventoryEntries("all","both"))do
        if item.id==id then return item end
    end
end

function S.ShowItemHint(id)
    S.Scan()
    local item=FindMap(id)
    if not item then S.Say("Select a survey or treasure map first.");return end
    local location=not item.unidentified and (item.kind=="survey" and S.locations or S.treasureLocations or {})[id]
    local rows={item.name,T(item.kind=="survey" and "Surveys" or "Treasure maps"),
        T("Backpack %d | Bank %d",item.backpack,item.bank),""}
    local flavor=GetItemLinkFlavorText(item.link)
    if flavor and flavor~="" then rows[#rows+1]=flavor;rows[#rows+1]="" end
    if location then
        rows[#rows+1]=T("Zone: %s",location.zone)
        rows[#rows+1]=T("Map position: %.1f%%, %.1f%%",location.x*100,location.y*100)
        local node,name=S.ClosestShrine(location)
        rows[#rows+1]=node and T("Nearest unlocked wayshrine: %s",name) or T("No unlocked wayshrine is shown for this location.")
        rows[#rows+1]=T("Use Map Pin to mark this location. Normal travel costs and restrictions apply.")
    elseif item.unidentified then
        if item.craft then rows[#rows+1]=T("Survey Type: %s",T(item.craft))end
        rows[#rows+1]=T("This item's zone is not revealed yet. Open it from your backpack to identify it.")
        rows[#rows+1]=T("Opening an unidentified item consumes one container and reveals a survey or treasure map. Nothing is opened automatically.")
    else rows[#rows+1]=T("Install/update LibTreasure to preview item locations.")end
    rows[#rows+1]=""
    rows[#rows+1]=T(item.unidentified and "Withdraw bank-only items before identifying them." or "Open Survey / Open Map displays the original item picture. Withdraw bank-only items first.")
    S.ShowExport(table.concat(rows,"\n"),"Survey / Map Hint")
end

local reading
local readEvents="SurveySidekickItemRead"
local function FinishReading()
    if not reading then return end
    local previous=reading;reading=nil
    EVENT_MANAGER:UnregisterForEvent(readEvents,EVENT_SHOW_BOOK)
    EVENT_MANAGER:UnregisterForEvent(readEvents,EVENT_HIDE_BOOK)
    for _,window in ipairs(previous.windows)do window:SetHidden(false)end
    if previous.shown then S.Scan();S.Refresh()end
end

function S.OpenMapItem(id)
    if not id then S.Say("Select a survey or treasure map first.");return end
    if unopened[id]then S.Say("Open this unidentified item from your backpack to reveal its zone. Nothing is opened automatically.");return end
    if IsUnitInCombat("player") then S.Say("Leave combat before opening a survey or treasure map.");return end
    -- Resolve a fresh slot for this item ID on every explicit click. Never use a
    -- cached slot: inventory sorting/transfers can replace the item occupying it.
    local slot
    for index=0,GetBagSize(BAG_BACKPACK)-1 do
        local link=GetItemLink(BAG_BACKPACK,index,LINK_STYLE_DEFAULT)
        if link~="" and GetItemLinkItemId(link)==id then
            local _,special=GetItemLinkItemType(link)
            if (SURVEY and special==SURVEY) or (TREASURE and special==TREASURE)
                or (S.locations and S.locations[id]) or (S.treasureLocations and S.treasureLocations[id]) then
                slot=index;break
            end
        end
    end
    if not slot then
        if S.BankMapItems()[id] then S.Say("Withdraw this item from your bank before opening its picture.")
        else S.Say("This survey or treasure map is no longer in your backpack.")end
        S.Scan();return
    end
    local usable,actionSlotOnly=IsItemUsable(BAG_BACKPACK,slot)
    if not usable or actionSlotOnly or not CanInteractWithItem(BAG_BACKPACK,slot) then
        S.Say("ESO cannot open this item right now. Try again from your backpack.");return
    end
    FinishReading()
    local state={shown=false,windows={}};reading=state
    EVENT_MANAGER:RegisterForEvent(readEvents,EVENT_SHOW_BOOK,function()
        if reading~=state or state.shown then return end
        state.shown=true
        for _,window in ipairs({S.ui or false,S.catalogWindow or false,S.detourWindow or false,
            S.accountantWindow or false,S.export or false,S.appearanceWindow or false})do
            if window and not window:IsHidden() then
                state.windows[#state.windows+1]=window;window:SetHidden(true)
            end
        end
    end)
    EVENT_MANAGER:RegisterForEvent(readEvents,EVENT_HIDE_BOOK,FinishReading)
    -- UseItem is a protected ESO API. This call occurs only from the player's
    -- Open button, with the usual item-use/combat checks; it is never automated.
    local success=CallSecureProtected("UseItem",BAG_BACKPACK,slot)
    if not success then
        FinishReading();S.Say("ESO cannot open this item right now. Try again from your backpack.");return
    end
    zo_callLater(function()
        if reading==state and not state.shown then
            FinishReading();S.Say("ESO did not open the map picture. Try the item directly in your backpack.")
        end
    end,5000)
end
