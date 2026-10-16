ScryMaster = {name="ScryMaster", version="1.0.1", entries={}, zones={}, sets={}, expanded={}, dirty=true}
local SM = ScryMaster
local EM = EVENT_MANAGER
SM.filters = {"All", "Never dug", "Dug before", "Codex unfinished", "Codex complete", "Lead ready", "Need a lead"}

function SM:Clean(s)
    return zo_strformat("<<1>>", s or "")
end
function SM:Lower(s)
    return zo_strlower(s or "")
end
function SM:Visible()
    return self.window and not self.window:IsHidden()
end
function SM:ReadEntry(id)
    local zone = GetAntiquityZoneId(id)
    local name = self:Clean(GetAntiquityName(id))
    if name == "" then return end
    local e = {id=id, name=name, zone=zone, zoneName=self:Clean(GetZoneNameById(zone)),
        dug=GetNumAntiquitiesRecovered(id), lore=GetNumAntiquityLoreEntriesAcquired(id),
        total=GetNumAntiquityLoreEntries(id), lead=DoesAntiquityHaveLead(id),
        requiresLead=DoesAntiquityRequireLead(id), setId=GetAntiquitySetId(id),
        quality=GetAntiquityQuality(id)}
    if e.zoneName == "" then e.zoneName = "Other / no excavation zone" end
    e.complete = e.total > 0 and e.lore >= e.total
    e.search = self:Lower(e.name .. " " .. e.zoneName .. " " .. (e.setId ~= 0 and GetAntiquitySetName(e.setId) or ""))
    return e
end
function SM:AddEntry(p, id)
    if p.seen[id] then return end
    p.seen[id] = true
    local e = self:ReadEntry(id)
    if not e then return end
    p.entries[#p.entries+1] = e
    p.zones[e.zone] = e.zoneName
    if e.setId == 0 then return end
    local g = p.sets[e.setId]
    if not g then
        local quality = GetAntiquitySetQuality(e.setId)
        g = {id="set:"..e.setId, setId=e.setId, isGroup=true,
            name=self:Clean(GetAntiquitySetName(e.setId)), quality=quality,
            mythic=quality == ANTIQUITY_QUALITY_ORANGE, children={},
            pieces=GetNumAntiquitySetAntiquities(e.setId), dugPieces=0,
            lore=0, total=0, lead=false, requiresLead=true, complete=false}
        p.sets[e.setId] = g
        -- Ask ESO for the full component list, regardless of discovery/ownership.
        -- The queue also fills any components not returned by the main iterator.
        for i=1,g.pieces do
            local component = GetAntiquitySetAntiquityId(e.setId,i)
            if component and component > 0 then p.components[#p.components+1]=component end
        end
    end
    e.setName = g.name
    g.children[#g.children+1] = e
    if e.dug > 0 then g.dugPieces = g.dugPieces+1 end
    g.dug = g.dug and math.min(g.dug,e.dug) or e.dug
    g.lore, g.total = g.lore+e.lore, g.total+e.total
    g.lead = g.lead or e.lead
    g.requiresLead = g.requiresLead and e.requiresLead
end
function SM:FinishScan(p)
    local sets,zones = {},{}
    for _,g in pairs(p.sets) do
        table.sort(g.children,function(a,b) return a.name < b.name end)
        -- Never infer a finished item or full codex from a partial component list.
        g.allComponents = #g.children >= g.pieces and g.pieces > 0
        if not g.allComponents then g.dug=0 end
        g.complete = g.allComponents and g.total > 0 and g.lore >= g.total
        g.search = self:Lower(g.name)
        for _,e in ipairs(g.children) do g.search=g.search.." "..e.search end
        sets[#sets+1] = g
    end
    table.sort(sets,function(a,b) return a.name < b.name end)
    for zone,name in pairs(p.zones) do zones[#zones+1]={id=zone,name=name} end
    table.sort(zones,function(a,b) return a.name < b.name end)
    self.entries,self.zones,self.sets = p.entries,zones,sets
    self:StopScan()
    self:Refresh()
    if self.rescan or self.dirty then self:QueueRefresh() end
end
function SM:StopScan()
    EM:UnregisterForUpdate(self.name .. "Scan")
    self.scanning = false
    self.pending = nil
end
function SM:Scan()
    if not self:Visible() or self.scanning then return end
    self.scanning, self.dirty, self.rescan = true, false, false
    self.pending = {entries={}, zones={}, sets={}, seen={}, components={}, componentIndex=1, last=nil}
    self:Refresh(false)
    EM:RegisterForUpdate(self.name .. "Scan", 20, function()
        if not self:Visible() then self:StopScan(); self.dirty=true; return end
        if IsUnitInCombat("player") then return end
        local p, started = self.pending, GetGameTimeMilliseconds()
        for _ = 1, 16 do
            local id
            if not p.componentsPhase then
                id=GetNextAntiquityId(p.last)
                if id then p.last=id else p.componentsPhase=true end
            end
            if p.componentsPhase then
                id=p.components[p.componentIndex]
                p.componentIndex=p.componentIndex+1
                if not id then self:FinishScan(p); return end
            end
            self:AddEntry(p,id)
            if GetGameTimeMilliseconds()-started >= 4 then break end
        end
    end)
end
function SM:QueueRefresh()
    self.dirty = true
    if self.scanning then self.rescan=true; return end
    if not self:Visible() then return end
    EM:UnregisterForUpdate(self.name .. "Refresh")
    EM:RegisterForUpdate(self.name .. "Refresh", 180, function()
        EM:UnregisterForUpdate(self.name .. "Refresh")
        if self:Visible() then self:Scan() end
    end)
end
function SM:InCategory(e)
    if self.zone == -2 then return e.isGroup and e.mythic end
    if self.zone == -3 then return e.isGroup end
    local zone = self.zone == -1 and GetZoneId(GetUnitZoneIndex("player")) or self.zone
    return zone == 0 or e.zone == zone
end
function SM:Matches(e, query)
    if not self:InCategory(e) then return false end
    if query ~= "" and not e.search:find(query, 1, true) then return false end
    local f = self.filter
    if f == 2 then return e.isGroup and e.dugPieces == 0 or not e.isGroup and e.dug == 0 end
    if f == 3 then return e.isGroup and e.dugPieces > 0 or not e.isGroup and e.dug > 0 end
    if f == 4 then return e.total > 0 and not e.complete end
    if f == 5 then return e.complete end
    if f == 6 then return e.lead or not e.requiresLead end
    if f == 7 then
        if e.isGroup then
            for _,child in ipairs(e.children) do if child.requiresLead and not child.lead then return true end end
            return false
        end
        return e.requiresLead and not e.lead
    end
    return true
end
function SM:BuildResults()
    local selected = self.results and self.results[self.selected]
    local query = self:Lower(self.search:GetText()):match("^%s*(.-)%s*$")
    self.categories = {{id=0,name="All zones"},{id=-1,name="Current zone"},
        {id=-2,name="Mythics"},{id=-3,name="Mythics & sets"}}
    for _, zone in ipairs(self.zones) do self.categories[#self.categories+1] = zone end
    self.results = {}
    self.stats = {all=0, dug=0, complete=0, unfinished=0}
    local source = (self.zone == -2 or self.zone == -3) and self.sets or self.entries
    local matches = {}
    for _, e in ipairs(source) do
        -- Summary describes the selected zone, independently of the status/search filters.
        if self:InCategory(e) then
            self.stats.all=self.stats.all+1
            if e.dug > 0 then self.stats.dug=self.stats.dug+1 end
            if e.complete then self.stats.complete=self.stats.complete+1 end
            if e.total > 0 and not e.complete then self.stats.unfinished=self.stats.unfinished+1 end
        end
        if self:Matches(e,query) then matches[#matches+1]=e end
    end
    table.sort(matches,function(a,b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    for _,e in ipairs(matches) do
        self.results[#self.results+1]=e
        if e.isGroup and self.expanded[e.id] then
            for _,child in ipairs(e.children) do self.results[#self.results+1]=child end
        end
    end
    if selected then
        for i,e in ipairs(self.results) do if e.id==selected.id then self.selected=i; break end end
    end
    self.selected=math.max(1,math.min(self.selected,#self.results))
    self.categorySelected=math.max(1,math.min(self.categorySelected,#self.categories))
end
function SM:CodexText(e)
    if e.total == 0 then return "Codex n/a" end
    return "Codex " .. e.lore .. "/" .. e.total
end
function SM:DetailText(e)
    if not e then return self.scanning and "Reading antiquities in small batches. Pauses during combat."
        or "No matches. Try All, choose another zone, or clear the search." end
    if e.isGroup then
        return e.name.."  |  A: expand / collapse fragments\n"..e.dugPieces.."/"..e.pieces
            .." fragments dug  |  "..self:CodexText(e).."  |  "..e.dug.." full excavation sets"
            .."\nEach fragment shows its excavation zone. Lead drop sources are not catalogued."
    end
    local set = e.setId ~= 0 and ("  |  Part of " .. self:Clean(GetAntiquitySetName(e.setId))) or ""
    local lead
    if e.lead then
        local seconds = GetAntiquityLeadTimeRemainingSeconds(e.id)
        lead = "Lead held" .. (seconds > 0 and (" (" .. math.max(1,math.ceil(seconds/3600)) .. "h left)") or "")
    elseif not e.requiresLead then lead = "No lead required"
    else lead = "Lead needed" end
    return e.name .. set .. "\nExcavate: " .. e.zoneName .. "  |  Dug: " .. e.dug .. "  |  " .. self:CodexText(e)
        .. "\n" .. lead .. "  |  Lead drop source: not catalogued in this version."
end
function SM:Initialize()
    ZO_CreateStringId("SI_BINDING_NAME_SCRY_MASTER_TOGGLE", "Open / close Scry Master")
    SLASH_COMMANDS["/sm"] = function() self:Toggle() end
    SLASH_COMMANDS["/scrymaster"] = SLASH_COMMANDS["/sm"]
    for _, event in ipairs({EVENT_ANTIQUITY_UPDATED, EVENT_ANTIQUITY_LEAD_ACQUIRED,
        EVENT_ANTIQUITY_DIG_SITES_UPDATED, EVENT_PLAYER_ACTIVATED}) do
        EM:RegisterForEvent(self.name, event, function() self:QueueRefresh() end)
    end
end
EM:RegisterForEvent(SM.name, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= SM.name then return end
    EM:UnregisterForEvent(SM.name, EVENT_ADD_ON_LOADED)
    SM:Initialize()
end)
