-- Bundled-data adapter. No external Lead List namespace or installation is used.
local A=AntiquityAtlas
A.BundledData=A.Data
function A.RefreshProvider()
    local provider=A.BundledData
    if type(provider)~="table" or type(provider.Locations)~="table"
        or type(provider.FindScryDifferentZones)~="table"
        or type(provider.SETID_2_ITEMID)~="table" then
        return false,"Antiquity Atlas: bundled source data is missing; reinstall the complete archive."
    end
    local locations={}
    for id,source in pairs(provider.Locations) do
        if type(source)=="table" then locations[id]={source[1],source[2],source[3]} end
    end
    A.Data={Locations=locations,FindScryDifferentZones=provider.FindScryDifferentZones,
        SETID_2_ITEMID=provider.SETID_2_ITEMID}
    A.FallbackLocations=locations
    for id,detail in pairs(A.SourceDetails or {}) do
        local source,target=locations[id],A.InstanceZones[detail.zone]
        if source and target then
            source[1]=detail.boss.." - delve boss in "..target.name
            source[3]="(D) "..target.name
        end
    end
    return true
end
