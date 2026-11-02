-- Presentation-only material placement. Stored categories/legacy masks stay intact.
local A=ALTHarvestItems
local rareIngredients={[115026]=true,[64222]=true,[120078]=true}
local function is(kind,suffix) return _G['ITEMTYPE_'..suffix]~=nil and kind==_G['ITEMTYPE_'..suffix] end
function A:RawMaterialGroup(id,item)
    local kind=item.itemType
    if is(kind,'JEWELRY_RAW_TRAIT') then return 'traits' end
    if is(kind,'JEWELRYCRAFTING_RAW_BOOSTER') then return 'jewelry' end
    if not is(kind,'RAW_MATERIAL') then return end
    self.rawDestinations=self.rawDestinations or {}
    if self.rawDestinations[id] then return self.rawDestinations[id] end
    if GetItemLinkRefinedMaterialItemLink then
        local link=GetItemLinkRefinedMaterialItemLink(self.Link(id),LINK_STYLE_DEFAULT)
        if type(link)=='string' and link~='' and self.ValidId(GetItemLinkItemId(link)) then
            local refined=GetItemLinkItemType(link); local group
            if is(refined,'STYLE_MATERIAL') then group='style'
            elseif is(refined,'ARMOR_TRAIT') or is(refined,'WEAPON_TRAIT') or is(refined,'JEWELRY_TRAIT') then group='traits'
            elseif is(refined,'BLACKSMITHING_BOOSTER') then group='metal'
            elseif is(refined,'CLOTHIER_BOOSTER') then group='cloth'
            elseif is(refined,'WOODWORKING_BOOSTER') then group='wood'
            elseif is(refined,'JEWELRYCRAFTING_BOOSTER') then group='jewelry' end
            if group then self.rawDestinations[id]=group; return group end
        end
    end
    return 'rawOther' -- Do not guess; retry when native metadata becomes available.
end
local category=A.FilterCategoryFor
function A:FilterCategoryFor(item,id)
    if rareIngredients[id] or id==33753 then return 'provisioning' end
    return self:RawMaterialGroup(id,item) or category(self,item,id)
end
function A:FilterCategoryMatches(item,id,key)
    if key=='fishing' and (id==33753 or id==64222) then return true end
    return self:FilterCategoryFor(item,id)==key
end
local tab=A.FilterTab
function A:FilterTab(item,id,view)
    if view=='fishing' and (id==33753 or id==64222) then return 4 end
    local group=self:FilterCategoryFor(item,id); local raw=self:RawMaterialGroup(id,item)
    if group=='provisioning' then return (rareIngredients[id] or (item.quality or 1)>=5) and 2 or 1 end
    if group=='style' then return raw and 2 or 1 end
    if group=='traits' and raw then return 4 end
    if raw and (group=='metal' or group=='wood' or group=='cloth' or group=='jewelry') then return 3 end
    return tab(self,item,id)
end
for _,entry in ipairs(A.filterCategories) do
    if entry.key=='powder' then entry.key='rawOther'; entry.name='UNASSIGNED_RAW_MATERIALS'
    elseif entry.key=='style' then entry.tabs={'REFINED_MATERIALS','RAW_RESOURCES'}
    elseif entry.key=='traits' then entry.tabs={'WEAPONS','ARMOR','JEWELRY','RAW_RESOURCES'}
    elseif entry.key=='provisioning' then entry.tabs={'COMMON_INGREDIENTS','RARE_INGREDIENTS'} end
end
local load=A.LoadCatalog
function A:LoadCatalog()
    load(self)
    -- Runtime ESO metadata is authoritative for name/type/quality; no phantom catalog row.
    self:Observe(self.Link(120078))
end
