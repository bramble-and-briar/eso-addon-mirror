-- Native antiquity catalogue. Nothing is enumerated until the archive is opened.
local TC=TamrielCollections
local Catalogue={}
TC.antiquityCatalogue=Catalogue
local model,building,generation=nil,false,0
local ReadPart
-- Known music-box rewards seed the native furniture subcategory. This is
-- classification metadata, never a manually maintained ownership catalogue.
local musicBoxSeeds={[163431]=true,[190938]=true,[197829]=true,[204423]=true,[214343]=true}
local familyDefinitions={
    {key='mythics',name='Mythics',singular='Mythic',partsKey='mythicParts'},
    {key='mythicParts',name='Mythic Parts',partsView=true},
    {key='musicBoxes',name='Music Boxes',singular='Music Box',partsKey='musicBoxParts'},
    {key='musicBoxParts',name='Music Box Parts',partsView=true},
    {key='mounts',name='Mounts',singular='Mount',partsKey='mountParts'},
    {key='mountParts',name='Mount Parts',partsView=true},
    {key='zoneTreasures',name='Default Zone Treasures',singular='Zone treasures'},
    {key='motifs',name='Motifs',singular='Motif'},
    {key='furnishings',name='Furnishings',singular='Furnishing',partsKey='furnishingParts'},
    {key='furnishingParts',name='Furnishing Parts',partsView=true},
    {key='pets',name='Pets',singular='Pet',partsKey='petParts'},
    {key='petParts',name='Pet Parts',partsView=true},
    {key='appearance',name='Appearance and Emotes',singular='Collectible',partsKey='appearanceParts'},
    {key='appearanceParts',name='Appearance Parts',partsView=true},
    {key='treasures',name='Other Treasures',singular='Treasure',partsKey='otherRewardParts'},
    {key='otherRewards',name='Other Rewards',singular='Reward',partsKey='otherRewardParts'},
    {key='otherRewardParts',name='Other Reward Parts',partsView=true},
}
local function Text(value)
    return zo_strformat and zo_strformat(value or '') or tostring(value or '')
end
function Catalogue.Key(value)
    return (zo_strlower or string.lower)(Text(value)):gsub('’',"'")
        :gsub('|c%x%x%x%x%x%x',''):gsub('|r',''):gsub('%^.*$',''):gsub('%s+',' ')
end
function Catalogue.Get()return model end
function Catalogue.IsBuilding()return building end
function Catalogue.Invalidate()
    generation=generation+1;model,building=nil,false
end
local function Supported()
    return GetNextAntiquityId and GetAntiquitySetId and GetAntiquitySetRewardId
        and GetNumAntiquitySetAntiquities and GetAntiquitySetAntiquityId
        and GetAntiquityName and GetAntiquitySetName
        and GetNumAntiquityLoreEntries and GetNumAntiquityLoreEntriesAcquired
        and GetRewardType and GetItemRewardItemLink and GetItemLinkItemType
        and REWARD_ENTRY_TYPE_ITEM and ITEMTYPE_ARMOR
end
local function FurnitureFamily(link,reward,musicCategories)
    local itemId=GetItemRewardItemId and GetItemRewardItemId(reward)
    local categoryKey,subcategory
    if GetItemLinkFurnitureDataId and GetFurnitureDataCategoryInfo then
        local dataId=GetItemLinkFurnitureDataId(link)
        if dataId and dataId>0 then
            local category
            category,subcategory=GetFurnitureDataCategoryInfo(dataId)
            if category and category>0 and subcategory and subcategory>0 then
                categoryKey=tostring(category)..':'..tostring(subcategory)
            end
        end
    end
    local namedMusicBox=categoryKey and GetFurnitureCategoryName
        and Catalogue.Key(GetFurnitureCategoryName(subcategory))=='music boxes'
    if musicBoxSeeds[itemId] or namedMusicBox then
        if categoryKey then musicCategories[categoryKey]=true end
        return 'musicBoxes'
    end
    return 'furnishings',categoryKey
end
local function CollectibleFamily(id)
    local category
    if GetCollectibleCategoryType then category=GetCollectibleCategoryType(id)
    elseif GetCollectibleInfo then
        local _,_,_,_,_,_,_,nativeCategory=GetCollectibleInfo(id);category=nativeCategory
    end
    if not category then return 'otherRewards'end
    if COLLECTIBLE_CATEGORY_TYPE_MOUNT and category==COLLECTIBLE_CATEGORY_TYPE_MOUNT then return 'mounts'end
    if COLLECTIBLE_CATEGORY_TYPE_VANITY_PET and category==COLLECTIBLE_CATEGORY_TYPE_VANITY_PET then return 'pets'end
    if COLLECTIBLE_CATEGORY_TYPE_FURNITURE and category==COLLECTIBLE_CATEGORY_TYPE_FURNITURE then return 'furnishings'end
    for _,name in ipairs({'BODY_MARKING','HEAD_MARKING','HAT','EMOTE','OUTFIT_STYLE','SKIN',
        'COSTUME','PERSONALITY','HAIR','FACIAL_ACCESSORY','FACIAL_HAIR_HORNS','PIERCING_JEWELRY','MEMENTO'})do
        local value=_G['COLLECTIBLE_CATEGORY_TYPE_'..name]
        if value and category==value then return 'appearance'end
    end
    return 'otherRewards'
end
local function RewardFamily(id,musicCategories)
    local reward=GetAntiquitySetRewardId(id)
    if not reward or reward<=0 then return end
    local rewardType=GetRewardType(reward)
    if REWARD_ENTRY_TYPE_COLLECTIBLE and rewardType==REWARD_ENTRY_TYPE_COLLECTIBLE then
        local collectibleId=GetCollectibleRewardCollectibleId and GetCollectibleRewardCollectibleId(reward)
        if not collectibleId or collectibleId<=0 then return end
        return CollectibleFamily(collectibleId),nil,collectibleId
    end
    if rewardType~=REWARD_ENTRY_TYPE_ITEM then return 'otherRewards'end
    -- One transient link per unique reward, never per antiquity/fragment.
    local link=GetItemRewardItemLink(reward,1,REWARD_DISPLAY_FLAGS_NONE or 0,LINK_STYLE_DEFAULT or 0)
    if not link or link=='' then return 'otherRewards'end
    local itemType=GetItemLinkItemType(link)
    if itemType==ITEMTYPE_ARMOR then
        if GetItemLinkDisplayQuality and ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE
            and GetItemLinkDisplayQuality(link)~=ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE then return 'otherRewards'end
        -- Earlier clients lack display quality. Antiquity equipment rewards
        -- are Mythics; furnishing and collectible rewards do not enter here.
        return 'mythics'
    end
    if ITEMTYPE_FURNISHING and itemType==ITEMTYPE_FURNISHING then return FurnitureFamily(link,reward,musicCategories)end
    if ITEMTYPE_TREASURE and itemType==ITEMTYPE_TREASURE then return 'treasures'end
    return 'otherRewards'
end
local function ReadFurniture(id,result,familyKey,collectibleId,description)
    local part=ReadPart(id)
    if not part then return end
    part.single,part.family,part.collectibleId=true,familyKey,collectibleId
    part.furnishing=familyKey=='furnishings'or familyKey=='musicBoxes'
    part.key=(part.furnishing and 'furnishing:'or 'antiquity:')..id
    part.description=description
    if collectibleId and IsCollectibleUnlocked then part.unlocked=IsCollectibleUnlocked(collectibleId)end
    part.kind=result.byFamily[familyKey].singular
    result.parts[#result.parts+1]=part;result.byKey[part.key]=part
    local items=result.byFamily[familyKey].items;items[#items+1]=part
    if part.complete then result.partsComplete=result.partsComplete+1 end
    if collectibleId then result.collectibleIds[collectibleId]=true end
end
local function ReadSingle(id,result,musicCategories,pending)
    if DoesAntiquityPassVisibilityRequirements and not DoesAntiquityPassVisibilityRequirements(id)then return end
    local reward=GetAntiquityRewardId and GetAntiquityRewardId(id)
    if GetAntiquityRewardId and (not reward or reward<=0)then return end
    local rewardType=reward and reward>0 and GetRewardType(reward)
    if REWARD_ENTRY_TYPE_COLLECTIBLE and rewardType==REWARD_ENTRY_TYPE_COLLECTIBLE then
        local collectibleId=GetCollectibleRewardCollectibleId and GetCollectibleRewardCollectibleId(reward)
        if collectibleId and collectibleId>0 then
            local description=GetCollectibleDescription and GetCollectibleDescription(collectibleId)
            ReadFurniture(id,result,CollectibleFamily(collectibleId),collectibleId,description);return
        end
        if GetCollectibleRewardCollectibleId then return end
    end
    if rewardType~=REWARD_ENTRY_TYPE_ITEM then ReadFurniture(id,result,'otherRewards');return end
    local link=GetItemRewardItemLink(reward,1,REWARD_DISPLAY_FLAGS_NONE or 0,LINK_STYLE_DEFAULT or 0)
    if not link or link==''then ReadFurniture(id,result,'otherRewards');return end
    local itemType=GetItemLinkItemType(link)
    if ITEMTYPE_RACIAL_STYLE_MOTIF and itemType==ITEMTYPE_RACIAL_STYLE_MOTIF and TC.antiquityMotifs then
        TC.antiquityMotifs.Read(id,result,ReadPart,Catalogue.Key,link)
        return
    end
    local description=GetItemLinkFlavorText and GetItemLinkFlavorText(link)
    if ITEMTYPE_FURNISHING and itemType==ITEMTYPE_FURNISHING then
        local family,category=FurnitureFamily(link,reward,musicCategories)
        if family=='musicBoxes'then ReadFurniture(id,result,family,nil,description)
        else pending[#pending+1]={id=id,category=category,single=true,description=description}end
    else ReadFurniture(id,result,ITEMTYPE_TREASURE and itemType==ITEMTYPE_TREASURE and 'treasures'or 'otherRewards',nil,description)end
end
ReadPart=function(id,parent)
    local name=Text(GetAntiquityName(id))
    if name=='' then return end
    local total=math.max(0,GetNumAntiquityLoreEntries(id) or 0)
    local known=math.max(0,GetNumAntiquityLoreEntriesAcquired(id) or 0)
    local recovered=GetNumAntiquitiesRecovered and GetNumAntiquitiesRecovered(id) or 0
    local combination=DoesAntiquityNeedCombination and DoesAntiquityNeedCombination(id) or false
    local repeatable=IsAntiquityRepeatable and IsAntiquityRepeatable(id) or false
    local lead=DoesAntiquityHaveLead and DoesAntiquityHaveLead(id) or false
    local seconds=lead and GetAntiquityLeadTimeRemainingSeconds and GetAntiquityLeadTimeRemainingSeconds(id) or 0
    local now=GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
    return {id=id,key='part:'..id,name=name,nameKey=Catalogue.Key(name),parent=parent,
        icon=GetAntiquityIcon and GetAntiquityIcon(id),zoneId=GetAntiquityZoneId and GetAntiquityZoneId(id),
        known=known,total=total,complete=total>0 and known>=total,recovered=recovered,
        ready=combination or (recovered>0 and not repeatable),hasLead=lead,repeatable=repeatable,
        leadExpires=seconds>0 and now+seconds or nil,
        requiresLead=not DoesAntiquityRequireLead or DoesAntiquityRequireLead(id)}
end
local function ReadSet(id,result,familyKey,collectibleId)
    local family=result.byFamily[familyKey]
    local set={id=id,key='set:'..id,name=Text(GetAntiquitySetName(id)),parts={},
        icon=GetAntiquitySetIcon and GetAntiquitySetIcon(id),known=0,total=0,complete=true,ready=0,partsRecovered=0,
        family=familyKey,kind=family.singular,collectibleId=collectibleId}
    if collectibleId and IsCollectibleUnlocked then set.unlocked=IsCollectibleUnlocked(collectibleId)end
    if collectibleId then
        result.collectibleIds[collectibleId]=true
        if GetCollectibleDescription then set.description=GetCollectibleDescription(collectibleId)end
    end
    set.nameKey=Catalogue.Key(set.name)
    set.shortName=set.name
    if familyKey=='musicBoxes' then
        set.shortName=set.name:gsub('^[Mm]usic [Bb]ox,%s*',''):gsub('%s+[Mm]usic [Bb]ox$','')
    end
    local count=GetNumAntiquitySetAntiquities(id) or 0
    -- Native sets are small. Reject a corrupt size rather than blocking a frame.
    if count<1 or count>64 then return end
    for index=1,count do
        local partId=GetAntiquitySetAntiquityId(id,index)
        local visible=partId and (not DoesAntiquityPassVisibilityRequirements
            or DoesAntiquityPassVisibilityRequirements(partId))
        -- Respect the game's release/visibility gates for the entire reward.
        if not visible then return end
        local part=ReadPart(partId,set)
        if not part then return end
        set.parts[#set.parts+1]=part
        set.known,set.total=set.known+part.known,set.total+part.total
        set.complete=set.complete and part.complete
        set.recovered=set.recovered and math.min(set.recovered,part.recovered) or part.recovered
        if part.ready then set.ready=set.ready+1 end
        if part.recovered>0 then set.partsRecovered=set.partsRecovered+1 end
    end
    result.sets[#result.sets+1]=set;result.byKey[set.key]=set
    family.items[#family.items+1]=set
    if set.complete then result.setsComplete=result.setsComplete+1 end
    for _,part in ipairs(set.parts)do
        result.parts[#result.parts+1]=part;result.byKey[part.key]=part
        local parts=result.byFamily[family.partsKey].items
        parts[#parts+1]=part
        if part.complete then result.partsComplete=result.partsComplete+1 end
    end
end
local treasureTiers={'Green','Blue','Purple'}
local function ReadTreasure(id,tier)
    if DoesAntiquityPassVisibilityRequirements and not DoesAntiquityPassVisibilityRequirements(id)then return end
    local expected=_G['ANTIQUITY_QUALITY_'..string.upper(treasureTiers[tier])]
    if expected and GetAntiquityQuality and GetAntiquityQuality(id)~=expected then return end
    local part=ReadPart(id)
    if not part or not part.zoneId or part.zoneId<=0 then return end
    part.key,part.treasure,part.tier='treasure:'..id,true,tier
    part.nameKey=Catalogue.Key(part.name..' '..treasureTiers[tier])
    return part
end
local function AddTreasureChain(chain,records,result,groups)
    local green,blue,purple=records[chain[1]],records[chain[2]],records[chain[3]]
    -- Only use IDs returned by the native iterator. An older client may not
    -- contain a newer chain; never query unknown IDs or invent its missing rows.
    if not(green and blue and purple)or green.zoneId~=blue.zoneId or green.zoneId~=purple.zoneId then return end
    local zone=green.zoneId
    local group=groups[zone]
    if not group then
        local name=Text(GetZoneNameById and GetZoneNameById(zone))
        if name=='' then return end
        group={id=zone,key='zone:'..zone,name=name,shortName=name,nameKey=Catalogue.Key(name),
            family='zoneTreasures',kind='Zone treasures',treasureGroup=true,zoneId=zone,
            parts={},known=0,total=0,complete=true,partsRecovered=0}
        groups[zone]=group;result.byKey[group.key]=group
        result.sets[#result.sets+1]=group
        local items=result.byFamily.zoneTreasures.items;items[#items+1]=group
    end
    local parts={green,blue,purple}
    for tier,part in ipairs(parts)do
        part.parent,part.chainId=group,chain[1]
        local description=tier==1 and 'Starter treasure. No lead purchase is needed; scry and excavate it in this zone.'
            or ('Excavate "'..parts[tier-1].name..'" in this zone to receive this lead.')
        if tier==3 and not part.repeatable then description=description..' One-time treasure.'end
        part.source={location=group.name,description=description,zones={zone}}
        group.parts[#group.parts+1]=part
        group.known,group.total=group.known+part.known,group.total+part.total
        group.complete=group.complete and part.complete
        if part.recovered>0 then group.partsRecovered=group.partsRecovered+1 end
        result.byKey[part.key]=part;result.parts[#result.parts+1]=part
        if part.complete then result.partsComplete=result.partsComplete+1 end
    end
end
function Catalogue.Request(alive,finished)
    if model then finished(model);return end
    if building then return end
    if not zo_callLater then return end
    building=true
    local token=generation
    local result={sets={},parts={},byKey={},families={},byFamily={},collectibleIds={},setsComplete=0,partsComplete=0}
    for _,definition in ipairs(familyDefinitions)do
        local family={items={}}
        for key,value in pairs(definition)do family[key]=value end
        result.families[#result.families+1]=family;result.byFamily[family.key]=family
    end
    local seen,last,processed={},nil,0
    local musicCategories,pending,pendingIndex,phase={},{},1,'catalogue'
    local treasureChains=TC.antiquityTreasureChains or {}
    local treasureTiersById,treasureRecords,treasureGroups,chainIndex={},{},{},1
    for _,chain in ipairs(treasureChains)do
        for tier,id in ipairs(chain)do treasureTiersById[id]=tier end
    end
    local function Finish()
        local function Compare(a,b)
            if a.nameKey~=b.nameKey then return a.nameKey<b.nameKey end
            return a.id<b.id
        end
        table.sort(result.sets,Compare);table.sort(result.parts,Compare)
        for _,set in ipairs(result.sets)do
            if set.treasureGroup then
                table.sort(set.parts,function(a,b)
                    if a.chainId~=b.chainId then return a.chainId<b.chainId end
                    return a.tier<b.tier
                end)
            else table.sort(set.parts,Compare)end
            if (set.treasureGroup or set.motifGroup)and set.complete then result.setsComplete=result.setsComplete+1 end
        end
        for _,family in ipairs(result.families)do table.sort(family.items,Compare)end
        model,building=result,false
        if alive() then finished(result)end
    end
    local function Step()
        if token~=generation then return end
        if not alive() then building=false;return end
        if not Supported() then result.error='Antiquity data is not available on this client.';Finish();return end
        local start=GetGameTimeMilliseconds and GetGameTimeMilliseconds()
        for unit=1,(start and 32 or 8) do
            if phase=='catalogue' then
                local nextId=GetNextAntiquityId(last)
                if not nextId or nextId==0 then phase='furniture'
                else
                    if nextId==last or processed>=50000 then
                        result.error='Antiquity data could not be read. Close and reopen the archive to retry.'
                        Catalogue.Invalidate();building=true;Finish();return
                    end
                    last,processed=nextId,processed+1
                    local setId=GetAntiquitySetId(nextId)
                    if setId and setId>0 and not seen[setId] then
                        seen[setId]=true
                        local family,category,collectibleId=RewardFamily(setId,musicCategories)
                        if family=='furnishings'then pending[#pending+1]={id=setId,category=category}
                        elseif family then ReadSet(setId,result,family,collectibleId)end
                    elseif not(setId and setId>0)and treasureTiersById[nextId]then
                        treasureRecords[nextId]=ReadTreasure(nextId,treasureTiersById[nextId])
                    elseif not(setId and setId>0)then
                        ReadSingle(nextId,result,musicCategories,pending)
                    end
                end
            elseif phase=='furniture' then
                local candidate=pending[pendingIndex]
                if not candidate then phase='treasures'
                else
                    local family=musicCategories[candidate.category]and 'musicBoxes'or 'furnishings'
                    if candidate.single then ReadFurniture(candidate.id,result,family,nil,candidate.description)
                    else ReadSet(candidate.id,result,family)end
                    pendingIndex=pendingIndex+1
                end
            else
                local chain=treasureChains[chainIndex]
                if not chain then Finish();return end
                AddTreasureChain(chain,treasureRecords,result,treasureGroups)
                chainIndex=chainIndex+1
            end
            if start and GetGameTimeMilliseconds()-start>=1 then break end
        end
        zo_callLater(Step,0)
    end
    zo_callLater(Step,0)
end
