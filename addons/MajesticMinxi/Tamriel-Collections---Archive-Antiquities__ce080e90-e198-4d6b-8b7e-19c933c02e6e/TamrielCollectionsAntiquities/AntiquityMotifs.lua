-- Native motif rewards. Acquisition facts: UESP; see SourceAttribution.txt.
-- These ranges identify verified lead sources, never owned/learned chapters.
local TC=TamrielCollections
local Motifs={}
TC.antiquityMotifs=Motifs
local sourceRanges={{18,59},{316,329},{360,373},{416,429},{485,498}}
local function Source(part)
    local verified=false
    for _,range in ipairs(sourceRanges)do
        if part.id>=range[1]and part.id<=range[2]then verified=true;break end
    end
    if not verified or not part.zoneId or part.zoneId<=0 then return end
    if part.id>=316 and part.id<=329 then
        return {location='The Reach / Western Skyrim / Blackreach',
            description='Open treasure-map chests in The Reach, Western Skyrim, Greymoor Caverns or Arkthzand Cavern.',
            zones={1207,1160,1161,1208}}
    end
    local name=GetZoneNameById and GetZoneNameById(part.zoneId)
    if not name or name=='' then return end
    name=zo_strformat and zo_strformat(name)or name
    return {location=name..' treasure maps',
        description='Open chests found using this zone\'s treasure maps for a chance at the lead.',zones={part.zoneId}}
end
function Motifs.Read(id,result,readPart,key,link)
    -- Reward type and the transient link were checked by the catalogue.
    local part=readPart(id)
    if not part then return end
    -- Antiquity chapter titles use the localized "Style: Chapter" form.
    -- A future title without a separator keeps its own group rather than
    -- merging unrelated rewards or relying on English item names/style IDs.
    local name=(part.name:match('^(.-):')or part.name):gsub('^%s+',''):gsub('%s+$','')
    if name==''then name=part.name end
    local groupKey='motif:'..key(name)
    local group=result.byKey[groupKey]
    if not group then
        group={id=id,key=groupKey,name=name,shortName=name,nameKey=key(name),family='motifs',
            kind='Motif',motifGroup=true,parts={},known=0,total=0,complete=true,
            chaptersComplete=0,chaptersLearned=0,chaptersChecked=0}
        result.byKey[groupKey]=group;result.sets[#result.sets+1]=group
        local items=result.byFamily.motifs.items;items[#items+1]=group
    end
    part.key,part.motif,part.parent='motifChapter:'..id,true,group
    if IsItemLinkBookKnown then part.learned=IsItemLinkBookKnown(link)end
    part.source=Source(part)
    group.parts[#group.parts+1]=part
    group.known,group.total=group.known+part.known,group.total+part.total
    group.complete=group.complete and part.complete
    if part.complete then group.chaptersComplete=group.chaptersComplete+1;result.partsComplete=result.partsComplete+1 end
    if part.learned~=nil then group.chaptersChecked=group.chaptersChecked+1 end
    if part.learned then group.chaptersLearned=group.chaptersLearned+1 end
    result.parts[#result.parts+1]=part;result.byKey[part.key]=part
end
