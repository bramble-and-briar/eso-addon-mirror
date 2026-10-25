-- Cache the global table locally at the top of the file
local HarvensExtraIcons = HarvensExtraIcons

-- Safely ensure the parent table exists
if not HarvensExtraIcons then
    HarvensExtraIcons = {}
    _G["HarvensExtraIcons"] = HarvensExtraIcons
end

-- Define your clean array of icon texture paths directly as a subtable
HarvensExtraIcons.List = {
    "HarvensExtraIcons/icons/DynamicEncounter.dds",
    "/esoui/art/zonestories/completiontypeicon_skyshard.dds",
}
