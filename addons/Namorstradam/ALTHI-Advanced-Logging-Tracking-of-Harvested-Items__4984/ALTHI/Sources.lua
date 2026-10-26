local A = ALTHarvestItems
local function L(key) return A:T(key) end
A.sourceLabels = {
    ore = "ORE_NODES", fibre = "FIBRE_PLANTS", wood = "WOOD_NODES", water = "WATER_SOURCES",
    runestone = "RUNESTONES", plant = "PLANTS", mushroom = "MUSHROOMS", waterplant = "WATER_PLANTS",
    crimson = "CRIMSON_NIRNROOT_NODES", jewelry = "JEWELLERY_SEAMS", creature = "ANIMAL_NPC_LOOT",
    mudcrab = "MUDCRABS", container = "PROVISIONING_INGREDIENT_CONTAINERS", portal = "PSIJIC_PORTALS",
    dungeon = "RANDOM_DUNGEON_REWARD_MAIL", refining = "REFINING", deconstruction = "DECONSTRUCTION",
    dust = "RARELY_FROM_BASE_GAME_RESOURCE_NODES", nirn = "EQUIPMENT_RESOURCE_NODES_IN_CRAGLORN",
    world = "SPECIAL_WORLD_OBJECTS", normal = "RESOURCE_NODES", mail = "TAKEN_FROM_MAIL",
    writ="CRAFTING_WRITS_DEPENDING_ON_CRAFTING_RANK",hireling="HIRELING_MAIL_MATCHING_CRAFT",
    vendor="CRAFTING_NPC_BASIC_STYLE_MATERIALS",beetle="BEETLES",butterfly="BUTTERFLIES",
    fleshfly="FLESHFLIES_ZOMBIES",scrib="SCRIBS",spider="SPIDERS",torchbug="TORCHBUGS",
    chaurus="CHAURUS",harrowstorm="HARROWSTORMS",dragon="DRAGONS_IN_ELSWEYR",
    clam="GIANT_CLAMS_IN_SUMMERSET",oil="ENEMY_LOOT_POISON_SOLVENTS",waterskin="WATER_SKINS",
    trove="THIEVES_TROVES_THIEVES_GUILD",antiquity="ANTIQUITIES",solo="SOLO_DUNGEONS",
    sewers="IMPERIAL_CITY_SEWERS",treasuremap="TREASURE_MAPS_IN_ORIGINAL_ALLIANCE_ZONES",
    coldwood="COLD_ZONES_WOOD_AND_UNDEAD",
    mastervendor="MASTER_WRIT_VENDOR",warvendor="WAR_RESEARCHER_IN_CYRODIIL",
    weeklytrial="WEEKLY_TRIAL_REWARD",
}
function A:KnownSources(id)
    local known = A.SourceData and A.SourceData.items[id]
    if known then return known end
    local item = self.db.catalog[id]
    if item then
        if item.itemType==ITEMTYPE_RAW_MATERIAL and GetItemLinkRefinedMaterialItemLink then
            local link=GetItemLinkRefinedMaterialItemLink(self.Link(id),LINK_STYLE_DEFAULT)
            if link and link~="" and GetItemLinkItemId(link)==75370 then
                return {{kind="trove",evidence="Thieves-Materials"}}
            end
        end
        for suffix,entries in pairs(A.SourceData.typeSources or {}) do
            if _G["ITEMTYPE_" .. suffix] and item.itemType == _G["ITEMTYPE_" .. suffix] then
                local result={}; for _,entry in ipairs(entries) do result[#result+1]=entry end
                if suffix=="STYLE_MATERIAL" and GetItemStyleMaterialLink then
                    for style=1,10 do
                        local link=GetItemStyleMaterialLink(style,LINK_STYLE_DEFAULT)
                        if link and link~="" and GetItemLinkItemId(link)==id then
                            result[#result+1]={kind="vendor",evidence="Basic-Styles"}; break
                        end
                    end
                end
                if suffix=="JEWELRY_TRAIT" and GetSmithingTraitItemInfo then
                    for index=1,GetNumSmithingTraitItems() do
                        local trait=GetSmithingTraitItemInfo(index)
                        local link=GetSmithingTraitItemLink(index,LINK_STYLE_DEFAULT)
                        if link and link~="" and GetItemLinkItemId(link)==id then
                            local kind
                            if ITEM_TRAIT_TYPE_JEWELRY_SWIFT and trait==ITEM_TRAIT_TYPE_JEWELRY_SWIFT then kind="mastervendor"
                            elseif ITEM_TRAIT_TYPE_JEWELRY_TRIUNE and trait==ITEM_TRAIT_TYPE_JEWELRY_TRIUNE then kind="warvendor"
                            elseif ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY and trait==ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY then kind="weeklytrial" end
                            if kind then result[#result+1]={kind=kind,evidence="Schmuck-Guide"} end
                        end
                    end
                end
                return result
            end
        end
    end
    return {}
end
A.sourceGroups={
    creature="creature",mudcrab="creature",beetle="creature",butterfly="creature",fleshfly="creature",
    scrib="creature",spider="creature",torchbug="creature",chaurus="creature",dragon="creature",oil="creature",
    portal="world",world="world",container="world",trove="world",clam="world",treasuremap="world",
    dungeon="mail",mail="mail",hireling="mail",writ="activity",harrowstorm="activity",solo="activity",
    sewers="activity",coldwood="activity",antiquity="activity",vendor="vendor",
    mastervendor="vendor",warvendor="vendor",weeklytrial="activity",
    refining="processing",deconstruction="processing",ore="normal",fibre="normal",wood="normal",
    water="normal",runestone="normal",plant="normal",mushroom="normal",waterplant="normal",
    crimson="normal",jewelry="normal",dust="normal",nirn="normal",normal="normal",waterskin="world",
}
function A:KnownText(id)
    local labels, seen = {}, {}
    for _, entry in ipairs(self:KnownSources(id)) do
        if not seen[entry.kind] then
            labels[#labels + 1] = L(self.sourceLabels[entry.kind]); seen[entry.kind] = true
        end
    end
    return #labels > 0 and table.concat(labels, ", ") or L("NOT_YET_DOCUMENTED")
end
function A:RecordSource(id, kind, target)
    local item = self.db.catalog[id]
    if not item then return end
    item.observed = item.observed or {}
    local old = item.observed[kind]
    item.observed[kind] = { at = GetTimeStamp(), target = target or "" }
    if not old then self.catalogRevision = (self.catalogRevision or 0) + 1 end
    self:QueueRefresh()
end
function A:ObservedText(item)
    local labels = {}
    for _, kind in ipairs({ "normal", "world", "creature", "mail" }) do
        if item.observed and item.observed[kind] then labels[#labels + 1] = L(self.sourceLabels[kind]) end
    end
    return #labels > 0 and table.concat(labels, ", ") or L("NO_CONFIRMED_PERSONAL_FIND_YET")
end
function A:SourceText(item, id)
    return L("ORIGIN") .. self:KnownText(id) .. "\n" .. L("OBSERVED") .. self:ObservedText(item)
end
function A:TrackingText(id)
    return (self:IsEnabled(id) and L("MATERIAL_ENABLED") or L("MATERIAL_DISABLED"))
        .. " · " .. L("ONLY_CONFIRMED_RESOURCE_NODES_COUNT_NPC_ANIMAL_LOOT_AND_MAIL_DO_NOT")
end
function A:SourceMatches(item, id)
    local filter = self.db.ui.sourceFilter
    if filter == "all" then return true end
    local observed = item.observed or {}
    local matches = {}
    for _, entry in ipairs(self:KnownSources(id)) do
        local group=self.sourceGroups[entry.kind]
        if group then matches[group]=true end
    end
    for kind in pairs(observed) do matches[kind] = true end
    if filter == "unknown" then return next(matches) == nil end
    return matches[filter] == true
end
-- Ordered material IDs: LibLazyCrafting Smithing.lua and CraftStore solvent list.
-- Raw material links resolve to their refined tier without requiring owned items.
local tiers={}
local function Add(ids,skill,maximum,solvent)
 for tier,id in ipairs(ids) do tiers[id]={tier=tier,rank=solvent and math.max(1,tier-1) or tier,skill=skill,max=maximum} end
end
Add({5413,4487,23107,6000,6001,46127,46128,46129,46130,64489},"METALWORKING",10)
Add({811,4463,23125,23126,23127,46131,46132,46133,46134,64504},"TAILORING",10)
Add({794,4447,23099,23100,23101,46135,46136,46137,46138,64506},"TAILORING",10)
Add({793,4448,23095,6020,23097,23142,23143,800,4478,71239},"TAILORING",10)
Add({803,533,23121,23122,23123,46139,46140,46141,46142,64502},"WOODWORKING",10)
Add({135138,135140,135142,135144,135146},"ENGRAVER",5)
Add({135137,135139,135141,135143,135145},"ENGRAVER",5)
Add({883,1187,4570,23265,23266,23267,23268,64500,64501},"SOLVENT_PROFICIENCY",8,true)
Add({75357,75358,75359,75360,75361,75362,75363,75364,75365},"SOLVENT_PROFICIENCY",8,true)
function A:MaterialRank(id)
 if tiers[id] then return tiers[id] end
 if type(GetItemLinkRefinedMaterialItemLink)=="function" then
  local ok,link=pcall(GetItemLinkRefinedMaterialItemLink,self.Link(id),LINK_STYLE_DEFAULT)
  if ok and type(link)=="string" and link~="" then return tiers[GetItemLinkItemId(link)] end
 end
end
function A:MaterialTier(id)
 local entry=self:MaterialRank(id); return entry and entry.tier
end
function A:TraitText(id)
    if type(GetSmithingTraitItemInfo)~="function" or type(GetString)~="function" then return "" end
    if not self.traitNames then
        self.traitNames={}
        for index=1,GetNumSmithingTraitItems() do
            local trait=GetSmithingTraitItemInfo(index)
            local link=GetSmithingTraitItemLink(index,LINK_STYLE_DEFAULT)
            local material=link and GetItemLinkItemId(link) or 0
            if trait and trait>0 and material>0 then
                local name=GetString("SI_ITEMTRAITTYPE",trait)
                if name and name~="" then
                    self.traitNames[material]=self.traitNames[material] or {}
                    self.traitNames[material][name]=true
                end
            end
        end
    end
    local names=self.traitNames[id]
    if not names and type(GetItemLinkRefinedMaterialItemLink)=="function" then
        local link=GetItemLinkRefinedMaterialItemLink(self.Link(id),LINK_STYLE_DEFAULT)
        if link and link~="" then names=self.traitNames[GetItemLinkItemId(link)] end
    end
    local result={}; for name in pairs(names or {}) do result[#result+1]=name end
    table.sort(result)
    return #result>0 and L("TRAIT")..table.concat(result,", ") or ""
end
function A:MaterialInfo(id)
 local trait=self:TraitText(id); if trait~="" then return trait end
 local entry=self:MaterialRank(id)
 return entry and (L(entry.skill)..": "..L("RANK")..entry.rank.."/"..entry.max) or ""
end
function A:MaterialTooltip(control, id)
    local item = self.db.catalog[id]
    if not item then return end
    InitializeTooltip(ItemTooltip, control, TOPRIGHT, 0, 0, TOPLEFT)
    ItemTooltip:SetLink(self.Link(id)); ItemTooltip:AddLine(item.name .. " · ID " .. id)
    ItemTooltip:AddLine(self:SourceText(item, id)); ItemTooltip:AddLine(self:TrackingText(id))
    local level = self:MaterialInfo(id)
    if level ~= "" then
        ItemTooltip:AddLine(level)
        if self:MaterialRank(id) then
            ItemTooltip:AddLine(L("MATERIAL_PASSIVE_GUIDANCE_RESOURCE_NODES_SCALE_PARTLY_WITH_THIS_PASSIV"))
        end
    end
    local price, source = self:Price(id)
    ItemTooltip:AddLine((price ~= nil and self.UnitGold(price) or L("NO_PRICE_AVAILABLE")) .. " · " .. source)
    local evidence = {}
    for _, entry in ipairs(self:KnownSources(id)) do
        if not evidence[entry.evidence] then
            evidence[entry.evidence] = true
            ItemTooltip:AddLine(L("EVIDENCE") .. entry.evidence)
        end
    end
end
