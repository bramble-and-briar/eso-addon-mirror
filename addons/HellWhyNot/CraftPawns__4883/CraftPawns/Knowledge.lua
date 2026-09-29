local CAM = CraftPawns
CAM.Knowledge = {}
local K = CAM.Knowledge

-- Increment independently of the game API whenever catalogue validation
-- changes so stale item-id scans are rebuilt automatically.
K.catalogApi = 10105101
K.catalogMaxItemId = 500000
K.catalogChunk = 500

-- These two retired runestones remain addressable as item records and report
-- unknown forever, but are no longer learnable in the live game.
K.retiredRunes = { ["jaedi"]=true, ["lire"]=true }

local function itemLink(itemId)
    return string.format("|H1:item:%d:25:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId)
end

local function runeTypes()
    local types = {}
    if ITEMTYPE_ENCHANTING_RUNE_ASPECT then types[ITEMTYPE_ENCHANTING_RUNE_ASPECT]=true end
    if ITEMTYPE_ENCHANTING_RUNE_ESSENCE then types[ITEMTYPE_ENCHANTING_RUNE_ESSENCE]=true end
    if ITEMTYPE_ENCHANTING_RUNE_POTENCY then types[ITEMTYPE_ENCHANTING_RUNE_POTENCY]=true end
    return types
end

function K:Initialize()
    CAM.sv.knowledgeCatalog = CAM.sv.knowledgeCatalog or {}
    local c = CAM.sv.knowledgeCatalog
    if c.api == self.catalogApi and c.complete and c.reagents and c.runes then
        self.catalog = c
        return
    end
    self.catalog = { api=self.catalogApi, complete=false, scanning=true, nextId=1, reagents={}, runes={}, reagentNames={}, runeNames={} }
    CAM.sv.knowledgeCatalog = self.catalog
    self:StartCatalogScan()
end

function K:StartCatalogScan()
    if self.catalog.complete then return end
    local runeTypeSet = runeTypes()
    EVENT_MANAGER:RegisterForUpdate(CAM.name.."KnowledgeCatalog", 20, function()
        local first = self.catalog.nextId or 1
        local last = math.min(self.catalogMaxItemId, first + self.catalogChunk - 1)
        for itemId=first,last do
            local link = itemLink(itemId)
            local ok, itemType = pcall(GetItemLinkItemType, link)
            if ok then
                if itemType == ITEMTYPE_REAGENT then
                    local name=GetItemLinkName(link)
                    if name and name~="" and not self.catalog.reagentNames[name] then self.catalog.reagentNames[name]=true; self.catalog.reagents[#self.catalog.reagents+1]=itemId end
                elseif runeTypeSet[itemType] then
                    local name=GetItemLinkName(link)
                    if name and name~="" and not self.catalog.runeNames[name] then self.catalog.runeNames[name]=true; self.catalog.runes[#self.catalog.runes+1]=itemId end
                end
            end
        end
        self.catalog.nextId = last + 1
        if CAM.UI and CAM.UI.scanLabel and not CAM.UI.window:IsHidden() then
            CAM.UI.scanLabel:SetText(string.format("Building knowledge catalogue %d%%", math.floor(last/self.catalogMaxItemId*100)))
        end
        if last >= self.catalogMaxItemId then
            EVENT_MANAGER:UnregisterForUpdate(CAM.name.."KnowledgeCatalog")
            self.catalog.complete=true; self.catalog.scanning=false; self.catalog.nextId=nil
            zo_callLater(function() CAM.Scanner:ScanAndCommit() end, 500)
        end
    end)
end

local function lastBoolean(results)
    for i=#results,2,-1 do if type(results[i])=="boolean" then return results[i] end end
    return nil
end

function K:ScanEnchanting()
    local data = { known={}, unknown={}, valid=false, cataloging=not self.catalog or not self.catalog.complete }
    if data.cataloging then return data end
    if type(GetItemLinkEnchantingRuneName) ~= "function" then data.error="Rune knowledge API unavailable"; return data end
    for _,itemId in ipairs(self.catalog.runes) do
        local link=itemLink(itemId)
        local name=zo_strformat(SI_TOOLTIP_ITEM_NAME,GetItemLinkName(link))
        -- API 101050 returns (known, translatedName), not just a translated
        -- name. Retired rune item records return nil and must not contribute
        -- to either the total or the missing count.
        local ok,known,translation=pcall(GetItemLinkEnchantingRuneName,link)
        if ok and known~=nil and not self.retiredRunes[string.lower(name or "")] then
            local entry={itemId=itemId,name=name,translation=translation or name,link=link}
            table.insert(known == true and data.known or data.unknown,entry)
        end
    end
    data.valid=(#data.known+#data.unknown)>0
    return data
end

function K:ScanAlchemy()
    local data = { known={}, unknown={}, valid=false, cataloging=not self.catalog or not self.catalog.complete,
        incompleteReagents=0, missingEffects=0 }
    if data.cataloging then return data end
    if type(GetItemLinkReagentTraitInfo) ~= "function" then data.error="Reagent knowledge API unavailable"; return data end
    for _,itemId in ipairs(self.catalog.reagents) do
        local link=itemLink(itemId)
        local entry={itemId=itemId,name=zo_strformat(SI_TOOLTIP_ITEM_NAME,GetItemLinkName(link)),link=link,unknownEffects={}}
        for traitIndex=1,4 do
            local results={pcall(GetItemLinkReagentTraitInfo,link,traitIndex)}
            local traitKnown=results[1] and lastBoolean(results)
            local traitName=results[2]
            if traitKnown~=true then
                entry.unknownEffects[#entry.unknownEffects+1]={index=traitIndex,name=traitName or ("Effect "..traitIndex)}
            end
        end
        if #entry.unknownEffects>0 then
            data.unknown[#data.unknown+1]=entry
            data.incompleteReagents=data.incompleteReagents+1
            data.missingEffects=data.missingEffects+#entry.unknownEffects
        else data.known[#data.known+1]=entry end
    end
    data.valid=#self.catalog.reagents>0
    return data
end

function K:ScanMotifs()
    local data={fullSets={},knownSets=0,checkedSets=0,valid=false}
    local styleKnownFunction=IsItemStyleKnown or IsSmithingStyleKnown
    if type(GetNumValidItemStyles)~="function" or type(GetValidItemStyleId)~="function" or type(GetItemStyleName)~="function" or type(styleKnownFunction)~="function" then return data end
    local ok,count=pcall(GetNumValidItemStyles); if not ok or type(count)~="number" then return data end
    for styleIndex=1,count do
        local idOk,styleId=pcall(GetValidItemStyleId,styleIndex)
        if idOk and styleId then
            local nameOk,name=pcall(GetItemStyleName,styleId); local full,checked=true,false
            for chapter=1,14 do local knownOk,known=pcall(styleKnownFunction,styleId,chapter); if knownOk then checked=true; if not known then full=false end else full=false end end
            if checked then data.checkedSets=data.checkedSets+1; if full then data.knownSets=data.knownSets+1; data.fullSets[#data.fullSets+1]={id=styleId,name=nameOk and name or tostring(styleId)} end end
        end
    end
    data.valid=data.checkedSets>0
    return data
end

function K:ScanProvisioningRecipes()
    local data={known=0,total=0,valid=false}
    if type(GetNumRecipeLists)~="function" or type(GetRecipeListInfo)~="function" or type(GetRecipeInfo)~="function" then return data end
    local ok,listCount=pcall(GetNumRecipeLists)
    if not ok or type(listCount)~="number" then return data end
    for listIndex=1,listCount do
        local listOk,_,recipeCount=pcall(GetRecipeListInfo,listIndex)
        if listOk and type(recipeCount)=="number" then
            for recipeIndex=1,recipeCount do
                local recipeOk,known=pcall(GetRecipeInfo,listIndex,recipeIndex)
                if recipeOk then
                    data.total=data.total+1
                    if known==true then data.known=data.known+1 end
                end
            end
        end
    end
    data.valid=data.total>0
    return data
end
