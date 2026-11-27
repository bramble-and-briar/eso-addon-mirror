-- Discover named addon HUD windows. Nothing is moved merely by being discovered.
local H=HUDMoveUI
local JOB=H.name.."Discovery"
local MAX_NODES,MAX_WINDOWS,BATCH=6000,120,150
local HUD_ROOTS={ZO_ActionBar1=true,ZO_PlayerAttribute=true,ZO_UnitFrames=true,
    ZO_BuffDebuffTopLevel=true,ZO_ReticleContainer=true}
local function normalized(name) return (name or ""):lower():gsub("[^%w]","") end
local function title(text) return (text or ""):gsub("|c%x%x%x%x%x%x",""):gsub("|r","") end
local function getName(c)
    if not c or not c.GetName then return "" end
    local ok,name=pcall(c.GetName,c)
    return ok and type(name)=="string" and name or ""
end
local function findControl(name)
    local control=_G[name]
    if not control and WINDOW_MANAGER.GetControlByName then control=WINDOW_MANAGER:GetControlByName(name) end
    return control
end
local function installedAddons()
    local result={}
    local manager=GetAddOnManager and GetAddOnManager()
    if not manager then return result end
    for i=1,manager:GetNumAddOns() do
        local name,display,_,_,enabled,_,_,library=manager:GetAddOnInfo(i)
        if enabled and name and name~=H.name and not library then
            local token=normalized(name)
            if #token>=3 then result[#result+1]={name=name,title=title(display or name),token=token} end
        end
    end
    table.sort(result,function(a,b) return #a.token>#b.token end)
    return result
end
local function ownerOf(name,addons)
    local token=normalized(name)
    for _,addon in ipairs(addons) do
        if token:find(addon.token,1,true) then return addon end
    end
end
function H.RegisterDiscovered(name,owner)
    if type(name)~="string" or name=="" or #name>200 then return end
    local key="addon:"..name
    local entry=H.byKey[key]
    if not entry then
        local count=0
        for _,known in ipairs(H.entries) do if known.custom then count=count+1 end end
        if count>=MAX_WINDOWS then return end
        entry={key=key,title=(owner and owner.title and (owner.title.." / ") or "")..name,
            section="07 Erkannte Addon-Fenster",names={name},w=360,h=100,x=.5,y=.5,
            custom=true,controlName=name,owner=owner and owner.name}
        entry.resolve=function() return findControl(name) end
        H.entries[#H.entries+1]=entry; H.byKey[key]=entry
    end
    H.saved.discovered[name]={owner=entry.owner,title=entry.title}
    return entry
end
function H.RestoreDiscovered()
    H.saved.discovered=H.saved.discovered or {}
    local count=0
    for name,metadata in pairs(H.saved.discovered) do
        if count>=MAX_WINDOWS then break end
        if type(name)=="string" and type(metadata)=="table" then
            local entry=H.RegisterDiscovered(name)
            if entry then
                entry.owner=metadata.owner; entry.title=metadata.title or name
                H.saved.discovered[name]={owner=entry.owner,title=entry.title}
                count=count+1
            end
        end
    end
end
function H.DiscoveryItems()
    local items={}
    for _,entry in ipairs(H.entries) do
        if entry.custom then
            items[#items+1]={name=entry.title,data=entry.key}
        end
    end
    table.sort(items,function(a,b) return a.name:lower()<b.name:lower() end)
    if #items==0 then items[1]={name="Noch keine Fenster erkannt",data=""} end
    return items
end
function H.SelectedAddon()
    local entry=H.byKey[H.saved.selectedAddon or ""]
    return entry and entry.custom and entry or nil
end
function H.SelectedAddonName()
    local entry=H.SelectedAddon()
    return entry and entry.title or H.DiscoveryItems()[1].name
end
local function refreshMenu()
    local L=LibHarvensAddonSettings
    if L and L.RefreshAddonSettings then L:RefreshAddonSettings() end
end
function H.StartDiscovery()
    if H.scanning then return end
    if IsUnitInCombat("player") or H.moving then H.Print("Fenster bitte ausserhalb von Kampf und Move UI suchen."); return end
    local addons=installedAddons()
    local known={}
    for _,entry in ipairs(H.entries) do
        if not entry.custom then local c=H.Resolve(entry); if c then known[c]=true end end
    end
    local queue,seen={},{}
    local head,found,visited=1,0,0
    local function enqueueChildren(c,depth)
        if not c.GetNumChildren or not c.GetChild or depth>5 then return end
        local ok,count=pcall(c.GetNumChildren,c)
        if not ok or type(count)~="number" then return end
        for i=1,count do
            if #queue>=MAX_NODES then break end
            local success,child=pcall(c.GetChild,c,i)
            if success and child and not seen[child] then
                seen[child]=true; queue[#queue+1]={control=child,depth=depth}
            end
        end
    end
    enqueueChildren(GuiRoot,0)
    H.scanning=true; H.discoveryStarted=true
    H.discoveryStatus="Addon-Fenster werden gesucht ..."
    local function finish()
        EVENT_MANAGER:UnregisterForUpdate(JOB)
        H.scanning=false
        H.discoveryStatus=string.format("%d passende Fenster in dieser Suche erkannt. Fenster zuerst im jeweiligen Addon oeffnen, dann erneut suchen.",found)
        if not H.SelectedAddon() then
            local items=H.DiscoveryItems(); H.saved.selectedAddon=items[1].data
        end
        queue,seen,known,addons=nil,nil,nil,nil
        H.Refresh(); refreshMenu()
        H.Print(H.discoveryStatus)
    end
    EVENT_MANAGER:RegisterForUpdate(JOB,30,function()
        if IsUnitInCombat("player") or H.moving then
            H.discoveryStatus="Suche unterbrochen. Nach dem Kampf erneut suchen."
            EVENT_MANAGER:UnregisterForUpdate(JOB); H.scanning=false
            queue,seen,known,addons=nil,nil,nil,nil
            return
        end
        for _=1,BATCH do
            local node=queue[head]
            if not node or found>=MAX_WINDOWS then finish(); return end
            head=head+1; visited=visited+1
            local c,name=node.control,getName(node.control)
            local native=name:match("^ZO_") or name=="GuiRoot"
            local helper=name:match("^HUDMoveUI") or name:match("^Lib") or name:lower():find("tooltip",1,true)
            local candidate=false
            if name~="" and not native and not helper and not known[c] and c.GetWidth and c.GetHeight then
                local ok,w,h=pcall(function() return c:GetWidth(),c:GetHeight() end)
                local owner=ownerOf(name,addons)
                local descriptive=name:lower():find("hud",1,true) or name:lower():find("window",1,true)
                    or name:lower():find("panel",1,true) or name:lower():find("tracker",1,true)
                    or name:lower():find("meter",1,true) or name:lower():find("display",1,true)
                    or name:lower():find("frame",1,true) or name:lower():find("bar",1,true)
                local full=ok and w>=GuiRoot:GetWidth()*.9 and h>=GuiRoot:GetHeight()*.9
                if ok and w>=40 and h>=16 and not full and (owner or descriptive) and findControl(name)==c then
                    local entry=H.RegisterDiscovered(name,owner)
                    if entry then found=found+1; candidate=true end
                end
            end
            -- Avoid thousands of native menu rows and selecting children of a discovered window.
            if not helper and not candidate and (not native or HUD_ROOTS[name]) then enqueueChildren(c,node.depth+1) end
        end
        H.discoveryStatus=string.format("Suche: %d Steuerelemente geprueft, %d Fenster erkannt ...",visited,found)
    end)
    refreshMenu()
end
