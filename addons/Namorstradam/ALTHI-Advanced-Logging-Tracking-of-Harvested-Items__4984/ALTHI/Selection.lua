local A = ALTHarvestItems
A.sections = {
    { key = "raw", name = "RAW_RESOURCES" }, { key = "refined", name = "REFINED_MATERIALS" },
    { key = "boosters", name = "UPGRADE_MATERIALS" }, { key = "housing", name = "FURNISHING_MATERIALS" },
}
function A:SectionFor(item)
    if item.category == "housing" then return "housing" end
    local kind = item.itemType
    for _, suffix in ipairs({ "BLACKSMITHING_BOOSTER", "CLOTHIER_BOOSTER", "WOODWORKING_BOOSTER",
        "JEWELRYCRAFTING_BOOSTER", "JEWELRYCRAFTING_RAW_BOOSTER" }) do
        if _G["ITEMTYPE_" .. suffix] and kind == _G["ITEMTYPE_" .. suffix] then return "boosters" end
    end
    for _, suffix in ipairs({ "BLACKSMITHING_MATERIAL", "CLOTHIER_MATERIAL", "WOODWORKING_MATERIAL",
        "JEWELRYCRAFTING_MATERIAL", "STYLE_MATERIAL", "ARMOR_TRAIT", "WEAPON_TRAIT", "JEWELRY_TRAIT" }) do
        if _G["ITEMTYPE_" .. suffix] and kind == _G["ITEMTYPE_" .. suffix] then return "refined" end
    end
    return "raw"
end
-- Presentation keys are separate from the legacy selection masks above.
A.filterCategories = {
 {key="alchemy",name="ALCHEMY",tabs={"PLANTS","MUSHROOMS","SOLVENTS","ANIMAL_REAGENTS"}},
 {key="metal",name="BLACKSMITHING",tabs={"ORES","REFINED_INGOTS","UPGRADE_MATERIALS"}},
 {key="wood",name="WOODWORKING_47A0D9",tabs={"ROUGH_WOOD","SANDED_WOOD","UPGRADE_MATERIALS"}},
 {key="cloth",name="CLOTHING",tabs={"FIBRES_RAW_HIDE","REFINED_MATERIALS","UPGRADE_MATERIALS"}},
 {key="jewelry",name="JEWELRY",tabs={"DUST","OUNCES","UPGRADE_MATERIALS"}},
 {key="runes",name="ENCHANTING"},{key="housing",name="HOUSING_MATERIALS"},
 {key="powder",name="PULVERISED_MATERIALS"},{key="style",name="STYLE_MATERIALS"},
 {key="traits",name="TRAIT_MATERIALS",tabs={"WEAPONS","ARMOR","JEWELRY"}},{key="rare",name="RARE_HARVESTS"},
}
local animals={ [77583]=true,[77585]=true,[150669]=true,[139020]=true,[150789]=true,
 [150731]=true,[150671]=true,[77587]=true,[77591]=true,[139019]=true,[77589]=true,
 [77584]=true,[77581]=true,[150670]=true,[224358]=true,[224359]=true }
function A:FilterTab(item,id)
 if item.category=="traits" then
  if item.itemType==ITEMTYPE_WEAPON_TRAIT then return 1 end
  if item.itemType==ITEMTYPE_ARMOR_TRAIT then return 2 end
  if item.itemType==ITEMTYPE_JEWELRY_TRAIT then return 3 end
 end
 if item.category=="alchemy" then
  if item.itemType==ITEMTYPE_POTION_BASE or item.itemType==ITEMTYPE_POISON_BASE then return 3 end
  if animals[id] then return 4 end
  for _,source in ipairs(self:KnownSources(id)) do if source.kind=="mushroom" then return 2 end end
  return 1
 end
 if self:SectionFor(item)=="boosters" then return 3 end
 if self:SectionFor(item)=="refined" then return 2 end
 return 1
end
function A:AllMaterialIds()
 local ids={}; for id,item in pairs(self.db.catalog) do if item.category then ids[#ids+1]=id end end
 return ids
end
function A:BuildSelectionTree()
 local rows,query={},zo_strlower(self.settingsQuery or "")
 self.expanded=self.expanded or self.db.ui.expanded
 local filtered=query~="" or self.db.ui.sourceFilter~="all"
 if filtered and not self.filteredExpanded then self.filteredExpanded={} end
 local expanded=filtered and self.filteredExpanded or self.expanded
 self.activeExpanded=expanded
 self.db.ui.filterTabs=self.db.ui.filterTabs or {}
 for _,category in ipairs(self.filterCategories) do
  local ids,items,available={}, {}, {}
  local selected=0
  for id,item in pairs(self.db.catalog) do
   if item.category==category.key then
    ids[#ids+1]=id
    if self:IsEnabled(id) then selected=selected+1 end
    if self:SourceMatches(item,id) and (query=="" or zo_strlower(item.name):find(query,1,true) or tostring(id):find(query,1,true)) then
     local tab=self:FilterTab(item,id); available[tab]=true
     items[#items+1]={id=id,name=item.name,category=item.category,icon=item.icon,quality=item.quality or 1,tab=tab}
    end
   end
  end
  if #ids>0 and (not filtered or #items>0) then
   local key="craft:"..category.key
   local active=self.db.ui.filterTabs[category.key] or 1
   if filtered and not available[active] then for index=1,4 do if available[index] then active=index; break end end end
   local group={key=key,name=self:T(category.name),category=category.key,ids=ids,group=true,
    total=#ids,selected=selected,tabs=category.tabs,activeTab=active,
    expanded=(expanded[key]==nil and filtered) or expanded[key]==true}
   rows[#rows+1]=group
   if group.expanded then
    local shown={}
    for _,item in ipairs(items) do if not category.tabs or item.tab==active then shown[#shown+1]=item end end
    items=shown
    table.sort(items,function(a,b)
     local ar,br=self:MaterialTier(a.id),self:MaterialTier(b.id)
     if a.tab==3 and category.tabs and category.tabs[3]=="UPGRADE_MATERIALS" then ar,br=a.quality,b.quality end
     if (ar or 999)~=(br or 999) then return (ar or 999)<(br or 999) end
     if a.name==b.name then return a.id<b.id end
     return zo_strlower(a.name)<zo_strlower(b.name)
    end)
    for _,item in ipairs(items) do rows[#rows+1]=item end
   end
  end
 end
 return rows
end
function A:SetItemsEnabled(ids, enabled)
    if enabled then
        -- Preserve effective choices outside the affected panel before lifting legacy masks.
        for id in pairs(self.db.catalog) do self.db.whitelist[id] = self:IsEnabled(id) == true end
    end
    for _, id in ipairs(ids) do
        local item = self.db.catalog[id]
        if item then
            self.db.whitelist[id] = enabled
            if enabled then
                local section = self:SectionFor(item)
                self.db.categoryEnabled[item.category] = true
                self.db.sectionEnabled[section] = true
                self.db.subgroupEnabled[section .. ":" .. item.category] = true
            end
        end
    end
    self:SelectionChanged()
end
function A:ToggleGroup(data)
    self:SetItemsEnabled(data.ids, data.selected ~= data.total)
end
function A:ToggleSelection(data)
    if data and not data.group then self:SetItemsEnabled({data.id}, not self:IsEnabled(data.id)) end
end
function A:SelectionRows() return self:BuildSelectionTree() end
