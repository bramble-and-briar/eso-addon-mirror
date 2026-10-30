-- Tamriel Collections - Guild Market Scanner v1.0.4c FILTER OFF NATIVE RESTORE TEST
-- Local-only; L3 scans additional trader pages and caches collection matches.
GuildMarketScannerDev = GuildMarketScannerDev or {}
local GMS = GuildMarketScannerDev
GMS.name, GMS.version = 'GuildMarketScannerDev', '1.3.0'
GMS.enabled, GMS.traderOpen, GMS.keybindAttached = false, false, false
-- Diagnostics are disabled in normal gameplay. /gmsdebug toggles them for testing.
GMS.debug = false
local function Say(msg)
    if not GMS.debug then return end
    local line = '|cD9AD51[Tamriel|r |cB58AE8Collections]|r ' .. tostring(msg)
    if false and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then CHAT_ROUTER:AddSystemMessage(line) else -- release: silent
    end
end
local function TryBoolean(fn, ...)
    if type(fn) ~= 'function' then return nil end
    local ok, value = pcall(fn, ...)
    if ok and type(value) == 'boolean' then return value end
    return nil
end
-- Returns true for a confirmed missing item, false for a confirmed owned/known
-- item, nil if this version cannot safely determine ownership.
function GMS:Missing(link)
    if type(link) ~= 'string' or link == '' then return nil end
    local okType, itemType = pcall(GetItemLinkItemType, link)
    if not okType then return nil end
    -- ESO's sticker-book ownership API works directly from an item link.
    -- This is more reliable than looking for a UI-only isLockedSetPiece flag.
    if type(IsItemLinkSetCollectionPiece)=='function'
        and type(IsItemSetCollectionPieceUnlocked)=='function'
        and type(GetItemLinkItemId)=='function' then
        local collectible=TryBoolean(IsItemLinkSetCollectionPiece,link)
        if collectible==true then
            local ok,id=pcall(GetItemLinkItemId,link)
            if ok and type(id)=='number' then
                local unlocked=TryBoolean(IsItemSetCollectionPieceUnlocked,id)
                if unlocked~=nil then return not unlocked end
            end
        end
    end
    -- Runeboxes and other containers can directly reference the collectible
    -- they unlock. This is an ownership test, not an item-name heuristic.
    if type(GetItemLinkContainerCollectibleId)=='function' and type(IsCollectibleUnlocked)=='function' then
        local ok, collectibleId=pcall(GetItemLinkContainerCollectibleId,link)
        if ok and type(collectibleId)=='number' and collectibleId>0 then
            local unlocked=TryBoolean(IsCollectibleUnlocked,collectibleId)
            if unlocked~=nil then return not unlocked end
        end
    end
    -- Some collectible links expose an ID directly rather than as a container.
    if type(GetCollectibleIdFromLink)=='function' and type(IsCollectibleUnlocked)=='function' then
        local ok, collectibleId=pcall(GetCollectibleIdFromLink,link)
        if ok and type(collectibleId)=='number' and collectibleId>0 then
            local unlocked=TryBoolean(IsCollectibleUnlocked,collectibleId)
            if unlocked~=nil then return not unlocked end
        end
    end
    -- Style pages may be books even when their item type is not the racial
    -- motif constant. Only invoke the book-known API for actual books.
    if type(IsItemLinkBook)=='function' then
        local isBook=TryBoolean(IsItemLinkBook,link)
        if isBook==true then
            local known=TryBoolean(IsItemLinkBookKnown,link)
            if known~=nil then return not known end
        end
    end
    if itemType == ITEMTYPE_RECIPE then
        local known = TryBoolean(IsItemLinkRecipeKnown, link)
        if known ~= nil then return not known end
    elseif itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
        local known = TryBoolean(IsItemLinkBookKnown, link)
        if known ~= nil then return not known end
    end
    return nil
end
-- Achievement-backed quantity fragments. Separate from GMS:Missing.
-- These IDs and criterion indices were confirmed by /gmsach in ESO.
local GMS_QUANTITY_FRAGMENTS = {
    [207814] = {4081, 1}, -- Remnant of Deception
    [207815] = {4081, 2}, -- Remnant of Cruelty
}
-- Verified collectible-fragment achievement criteria from in-game diagnostics.
-- Keep the two proven Remnant item IDs as the highest-priority exact matches.
-- The remaining entries are matched by localized ESO criterion descriptions.
local GMS_COLLECTION_CRITERIA = {
    [2591] = {1},        -- Skeletal Marionette Parts
    [3723] = {1,2},      -- Graht-Oak Acorns / Valenwood Seedlings
    [3913] = {1,2,3,4,5,6,7}, -- Big-Eared Ginger Kitten
    [3916] = {1},        -- Scaly Cloth Scraps
    [3917] = {1},        -- Inscribed Shards
    [3918] = {1,2},      -- Coral Haj Mota Lures / Decoys
    [4081] = {1,2},      -- Remnants (exact IDs preferred)
    [4226] = {1},        -- Horned Owl Feathers
    [4294] = {1},        -- Harvested Soul Fragment
    [4448] = {1},        -- Wormwrithe Haj Mota Scales
    [4743] = {1},        -- Spectral Distillation Ampoules
    [4744] = {1},        -- Chameleon Tincture Phials
    [3911] = {1,2,3,4,5,6,7}, -- Dwarven Theodolite
    [3912] = {1,2,3,4,5,6,7}, -- Sixth House Robe
    [3914] = {1,2,3,4,5,6,7}, -- Psijic Glowglobe
    [3915] = {1,2,3,4,5,6,7}, -- Master Field Cartographer
    [3832] = {1},        -- Possessed Shreds
    [4479] = {1},        -- Worm-Touched Soul Gems
    [2519] = {1},        -- Mummified Alfiq Parts (Alfiq Mummy Master)
    [2520] = {1},        -- Plague-Drenched Fabric (Peryite Plague-Clothes Patcher)
    [4447] = {1},        -- Shards of Writhing Bone (Skill Stylist: Caltrops)
    -- Swamp Jelly ACH 2378 tracks the final pet, not the seven parts.
    -- Do not apply a guessed collectible ID or criterion mapping.
}
local function GMSNormalizeCollectionPart(value)
    if type(value)~='string' then return '' end
    value=value:lower():gsub('|c%x%x%x%x%x%x',''):gsub('|r','')
        :gsub('[’]','\''):gsub('[^%w%s\'%-]',''):gsub('%s+',' ')
        :gsub('^%s+',''):gsub('%s+$','')
    -- ESO often uses plural achievement criteria for singular Guild Trader items.
    -- Only remove a trailing plural s, never modify internal words.
    if value:sub(-1)=='s' and value:sub(-2)~='ss' then value=value:sub(1,-2) end
    return value
end
-- v1.2.12: Check the finished provisioning recipe, not the fragment item.
-- Verify result name before using the observed recipe index (indices can change).
local function GMSRecipeStillMissing(expectedName, recipeIndex)
    if type(GetRecipeInfo)~='function' or type(GetRecipeResultItemLink)~='function'
        or type(GetItemLinkName)~='function' then return nil end
    local ok, known=pcall(GetRecipeInfo,15,recipeIndex)
    local okLink, resultLink=pcall(GetRecipeResultItemLink,15,recipeIndex)
    if not ok or not okLink or type(known)~='boolean' or type(resultLink)~='string' then return nil end
    local okName, name=pcall(GetItemLinkName,resultLink)
    if not okName or type(name)~='string' or name:lower()~=expectedName then return nil end
    return not known
end

function GMS:MissingFragment(link)
    if type(link)~='string' or link=='' or type(GetItemLinkItemId)~='function'
        or type(GetAchievementCriterion)~='function' then return nil end
    local okId,itemId=pcall(GetItemLinkItemId,link)
    if not okId then return nil end
    -- v1.2.7: Exact Guild Trader item IDs confirmed by /gmsitem.
    -- Reward IDs were checked against in-game collectible diagnostics.
    -- Do not infer ownership from the fragment's own recipeKnown flag.
    local GMS_REWARD_FRAGMENT_IDS = {
        [171479] = 8186,  -- Sealed Fabrication Materials -> Microtized Verminous Fabricant
        [147658] = 5885,  -- Festive Noise Maker Parts
        [147659] = 5887,  -- Joke Popper Parts
        [217925] = 13792, -- Phial of Tainted Blood -> Eviscerate, Violet Purple
    }
    -- v1.2.9: Werewolf forms found by /gmstotems.
    -- Both totem shard IDs are associated with the Red form; test in trader.
    GMS_REWARD_FRAGMENT_IDS[226958] = 14659 -- Wolf Totem Shard
    GMS_REWARD_FRAGMENT_IDS[226959] = 14659 -- Hunter Totem Shard
    GMS_REWARD_FRAGMENT_IDS[225219] = 14400 -- Shard of Parched Stone -> Blood Scion, Coldharbour
    -- Bitten Chew Bone: keep it only until all three form rewards are unlocked.
    if itemId==225220 and type(IsCollectibleUnlocked)=='function' then
        local allOwned=true
        for _,cid in ipairs({14773,14774,14775}) do
            local ok,owned=pcall(IsCollectibleUnlocked,cid)
            if not ok or type(owned)~='boolean' then return nil end
            if not owned then allOwned=false end
        end
        return not allOwned
    end
    local rewardCollectibleId=GMS_REWARD_FRAGMENT_IDS[itemId]
    if rewardCollectibleId and type(IsCollectibleUnlocked)=='function' then
        local success, unlocked=pcall(IsCollectibleUnlocked,rewardCollectibleId)
        if success and type(unlocked)=='boolean' then return not unlocked end
    end
    -- Recipe fragments: exact IDs where known; Psijic I-VII use an anchored
    -- item-name match so no unrelated recipe or material is classified.
    if itemId==115028 then
        return GMSRecipeStillMissing('mythic aetherial ambrosia',11)
    elseif itemId==224840 or itemId==224841 or itemId==224842 then
        return GMSRecipeStillMissing('tonic of portent favor',18)
    elseif itemId==64705 then
        return GMSRecipeStillMissing('psijic ambrosia',1)
    end
    if type(GetItemLinkName)=='function' then
        local okRecipeName, recipePartName=pcall(GetItemLinkName,link)
        if okRecipeName and type(recipePartName)=='string' then
            local low=recipePartName:lower()
            if low:match('^recipe: psijic ambrosia, fragment [ivx]+$') then
                return GMSRecipeStillMissing('psijic ambrosia',1)
            end
        end
    end
    local record=GMS_QUANTITY_FRAGMENTS[itemId]
    if record then
        local ok,description,current,required=pcall(GetAchievementCriterion,record[1],record[2])
        if ok and type(current)=='number' and type(required)=='number' and required>0 then
            return current<required
        end
        return nil
    end
    if type(GetItemLinkName)~='function' then return nil end
    local okName,itemName=pcall(GetItemLinkName,link)
    if not okName then return nil end
    -- v1.2.4: Exact reward ownership checks for fragment groups whose
    -- individual progress is not exposed through achievement criteria.
    -- Only classify the known fragment item names; do not apply these
    -- collectible IDs to unrelated reward runeboxes or similarly named pets.
    local lowerName = type(itemName)=='string' and itemName:lower() or ''
    -- v1.2.4: Seven independently tracked Apple-Bobbing Cauldron fragments.
    -- These collectible IDs and names were verified using /gmsparts in ESO.
    -- Check the finished reward first, then the individual part's ownership.
    -- Never match the reward container or unrelated items by a broad substring.
    local applePartIds = {
        ['apple-bobbing fresh gorapples']=6737,
        ['apple-bobbing cold iron cauldron']=6738,
        ['apple-bobbing aged fetid fish']=6739,
        ['apple-bobbing stale creek water']=6740,
        ['apple-bobbing poise guide']=6741,
        ['apple-bobbing viscous slime']=6742,
        ['apple-bobbing fenwood ladle']=6743,
    }
    local appleId = applePartIds[lowerName]
    if appleId and type(IsCollectibleUnlocked)=='function' then
        local okReward, rewardOwned = pcall(IsCollectibleUnlocked,5590)
        if okReward and rewardOwned==true then return false end
        local okPart, partOwned = pcall(IsCollectibleUnlocked,appleId)
        if okPart and type(partOwned)=='boolean' then return not partOwned end
    end
    -- v1.2.14: Mosaic Style Shreds, confirmed in-game as criterion 1
    -- of Skill Stylist: Grand Healing (achievement 4055, 10 required).
    -- Do NOT treat Dawnbreaker/Meteor customization fragments as this item.
    -- When criterion information is unavailable, preserve native behavior.
    if lowerName=='mosaic style shred' or lowerName=='mosaic style shreds'
        or lowerName=='mosaic skill shred' or lowerName=='mosaic skill shreds' then
        if type(GetAchievementCriterion)=='function' then
            local okM,descM,currentM,requiredM=pcall(GetAchievementCriterion,4055,1)
            if okM and type(descM)=='string'
                and GMSNormalizeCollectionPart(descM)=='mosaic style shred'
                and type(currentM)=='number' and type(requiredM)=='number' and requiredM>0 then
                return currentM<requiredM
            end
        end
        return nil
    end
    -- v1.2.13: Seven Guar Stomp component names; final emote collectible 6197.
    -- Exact names prevent unrelated Guar items from being hidden.
    local guarParts = {
        ['guar stomp elucidating hand-sculpture']=true,
        ['guar stomp history in street theatre']=true,
        ['guar stomp illustrated reports']=true,
        ['guar stomp noise reports']=true,
        ['guar stomp rehearsal tuning fork']=true,
        ['guar stomp skeletal reconstruction']=true,
        ['guar stomp steps-practice rug']=true,
    }
    if guarParts[lowerName] and type(IsCollectibleUnlocked)=='function' then
        local okGuar,owned=pcall(IsCollectibleUnlocked,6197)
        if okGuar and type(owned)=='boolean' then return not owned end
    end
    local rewardId = nil
    if lowerName=='bonedust pigment' or lowerName=='bonedust pigments' then
        rewardId=9389 -- Witch-Tamed Bear-Dog
    elseif lowerName=='rune-carved bone fragment' or lowerName=='rune-carved bone fragments' then
        rewardId=8079 -- Throwing Bones
    elseif lowerName=='swamp jelly fragment' or lowerName=='swamp jelly fragments' then
        rewardId=5656 -- base Swamp Jelly; do not confuse with named variants
    end
    if rewardId and type(IsCollectibleUnlocked)=='function' then
        local good,unlocked=pcall(IsCollectibleUnlocked,rewardId)
        if good and type(unlocked)=='boolean' then return not unlocked end
    end
    local normalized=GMSNormalizeCollectionPart(itemName)
    if normalized=='' then return nil end
    for achievementId,criteria in pairs(GMS_COLLECTION_CRITERIA) do
        for _,criterion in ipairs(criteria) do
            local ok,description,current,required=pcall(GetAchievementCriterion,achievementId,criterion)
            if ok and type(description)=='string'
                and GMSNormalizeCollectionPart(description)==normalized
                and type(current)=='number' and type(required)=='number' and required>0 then
                if achievementId==3913 and type(IsCollectibleUnlocked)=='function' then
                    local unlockedOk,unlocked=pcall(IsCollectibleUnlocked,4996)
                    if unlockedOk and unlocked==true then return false end
                end
                return current<required
            end
        end
    end
    return nil -- Unknown items continue through the original native filter.
end
-- Prefer ESO's own icon/status data. The guild-store entry may expose
-- canBeUsedToLearn (learning icon) or isLockedSetPiece (sticker-book icon).
-- An absent flag is UNKNOWN, not a negative result.
local function NativeMissingStatus(entry)
    -- Do not use # on a sparse candidates array: nil intermediate wrappers
    -- previously stopped inspection before we reached actual ESO status data.
    if type(entry)~='table' then return nil, 'invalid-entry' end
    local function flags(value)
        if type(value)~='table' then return false end
        return value.canBeUsedToLearn == true or value.isLockedSetPiece == true
            or value.isLockedSetItem == true
    end
    local data=entry.data
    local nested=type(data)=='table' and data.dataEntry or nil
    local deep=type(nested)=='table' and nested.data or nil
    local itemData=type(data)=='table' and data.itemData or nil
    if flags(entry) or flags(data) or flags(nested) or flags(deep) or flags(itemData) then
        return true, 'native-flag'
    end
    return nil, 'no-native-flag'
end

-- The native gamepad result builder retains original itemData and purchase indexes.
-- Skip only entries we can positively identify as already known; leave unsupported
-- item types untouched rather than silently hiding possible collectibles.
-- Console builds can expose the browse panel even when its named class is nil.
-- Resolve inherited methods from the live panel and override only this instance.
function GMS:GetPanel()
    local panel = GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS
    if type(panel) ~= 'table' and type(TRADING_HOUSE_GAMEPAD) == 'table' then
        panel = TRADING_HOUSE_GAMEPAD.browseResults or TRADING_HOUSE_GAMEPAD.browseResultsPanel
    end
    return type(panel) == 'table' and panel or nil
end
-- Experimental visible-list filtering. The previous build temporarily substituted
-- searchResultItemDataList while invoking FilterScrollList, but the displayed list
-- did not change. Here we leave the server results completely untouched.
-- First let ESO rebuild the list, then remove *only* verified-known item entries
-- from its scroll-list data. Keep every original data object and slotIndex.
-- ESO gamepad scroll entries contain data.dataEntry.data.itemLink on PS5.
-- Inspect only these explicit wrapper levels; never change purchase data.
local function EntryLink(entry)
    if type(entry) ~= 'table' then return nil, 'entry-not-table' end
    local candidates = {
        {'entry', entry},
        {'data', entry.data},
        {'data.dataEntry', type(entry.data)=='table' and entry.data.dataEntry},
        {'data.dataEntry.data', type(entry.data)=='table' and type(entry.data.dataEntry)=='table' and entry.data.dataEntry.data},
        {'data.itemData', type(entry.data)=='table' and entry.data.itemData},
    }
    for i=1,#candidates do
        local label, value = candidates[i][1], candidates[i][2]
        if type(value)=='table' then
            local link = value.itemLink or value.link
            if type(link)=='string' and link~='' then return link,label end
        end
    end
    return nil,'not-found'
end
-- Read-only: inspect the *actual* ZO_ScrollList entries without changing them.
local function Shape(value, depth)
    if type(value) ~= 'table' then return type(value) end
    if depth > 1 then return 'table' end
    local keys = {}
    for k, v in pairs(value) do
        if #keys < 22 then
            local name = tostring(k)
            if type(v) == 'table' then
                keys[#keys+1] = name .. ':{' .. Shape(v, depth+1) .. '}'
            else
                keys[#keys+1] = name .. ':' .. type(v)
            end
        end
    end
    table.sort(keys)
    return table.concat(keys, ',')
end
-- Read-only comparison of original results and the actual scroll-list entries.
-- Do not modify scroll-list data until we know which wrapper contains a valid item link.
local function LinkSummary(link)
    if type(link) ~= 'string' or link == '' then return 'absent' end
    local okType, kind = pcall(GetItemLinkItemType, link)
    local okId, itemId = false, nil
    if type(GetItemLinkItemId) == 'function' then okId, itemId = pcall(GetItemLinkItemId, link) end
    local missing = GMS:Missing(link)
    return 'id=' .. (okId and tostring(itemId) or '?') ..
        ',type=' .. (okType and tostring(kind) or 'ERROR') ..
        ',status=' .. (missing == false and 'KNOWN' or missing == true and 'MISSING' or 'UNKNOWN')
end
function GMS:CompareEntries(panel)
    local results = panel and panel.searchResultItemDataList
    local list = panel and panel.list
    if type(results) ~= 'table' or not list or type(ZO_ScrollList_GetDataList) ~= 'function' then
        Say('COMPARE unavailable: results=' .. type(results) .. ' list=' .. type(list)); return
    end
    local ok, entries = pcall(ZO_ScrollList_GetDataList, list)
    if not ok or type(entries) ~= 'table' then Say('COMPARE scroll entries unavailable'); return end
    Say('COMPARE resultCount=' .. tostring(#results) .. ' scrollCount=' .. tostring(#entries))
    local knownResults, knownScroll, identical, linked = 0, 0, 0, 0
    local resultLinks = {}
    for i = 1, #results do
        local r = results[i]
        local link = type(r)=='table' and r.itemLink or nil
        if type(link)=='string' then
            resultLinks[link] = true
            if self:Missing(link)==false then knownResults=knownResults+1 end
        end
    end
    for i = 1, #entries do
        local link = EntryLink(entries[i])
        if type(link)=='string' then
            linked=linked+1
            if resultLinks[link] then identical=identical+1 end
            if self:Missing(link)==false then knownScroll=knownScroll+1 end
        end
    end
    Say('COMPARE links=' .. linked .. ' exactMatches=' .. identical ..
        ' knownResults=' .. knownResults .. ' knownScroll=' .. knownScroll)
    for i=1,math.min(3,#entries,#results) do
        local entry, result = entries[i], results[i]
        local direct, path = EntryLink(entry)
        local wrapper = type(entry)=='table' and entry.data or nil
        local nested = type(wrapper)=='table' and wrapper.dataEntry or nil
        local deep = type(nested)=='table' and nested.data or nil
        Say('COMPARE #' .. i .. ' result {' .. LinkSummary(type(result)=='table' and result.itemLink) .. '}')
        Say('COMPARE #' .. i .. ' ' .. tostring(path) .. ' {' .. LinkSummary(direct) .. '}')
        Say('COMPARE #' .. i .. ' nested {' .. LinkSummary(type(deep)=='table' and deep.itemLink) .. '}')
        local rSlot=type(result)=='table' and result.slotIndex or nil
        local eSlot=type(wrapper)=='table' and wrapper.slotIndex or nil
        Say('COMPARE #' .. i .. ' slot result=' .. tostring(rSlot) .. ' wrapper=' .. tostring(eSlot))
    end
end
-- On an empty filtered server page ESO can hide its native trigger prompts.
-- Provide fallback triggers ONLY while the filtered result list is empty.
-- Never replace ESO's native page controls on nonempty pages.
-- The old empty-result L2/R2 keybind strip was a legacy manual-page fallback.
-- The native filtered-results footer provides the working L2/R2 controls.
-- Keep this hook as a no-op so scan/pagination call sites remain unchanged.
function GMS:UpdateEmptyPageNavigation(isEmpty)
    self.emptyFilteredPage = false
    if self.emptyPageKeybindAttached and KEYBIND_STRIP and self.emptyPageKeybindGroup then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.emptyPageKeybindGroup)
        self.emptyPageKeybindAttached = false
    end
end

function GMS:FilterVisibleEntries(panel)
    local list = panel and panel.list
    if not list or type(ZO_ScrollList_GetDataList) ~= 'function' then return end
    local ok, entries = pcall(ZO_ScrollList_GetDataList, list)
    if not ok or type(entries) ~= 'table' then return end
    local originalCount = #entries
    local kept, known, unknown = {}, 0, 0
    for i=1,originalCount do
        local entry = entries[i]
        local link = EntryLink(entry)
        local missing = self:Missing(link)
        local fragmentMissing = self:MissingFragment(link)
        if fragmentMissing ~= nil then missing = fragmentMissing end
        local native, reason = NativeMissingStatus(entry)
        if native ~= true and panel and type(panel.searchResultItemDataList)=='table' then
            local nativeEntry=panel.searchResultItemDataList[i]
            local candidate=NativeMissingStatus(nativeEntry)
            if candidate==true then native=true end
        end
        if native == true and fragmentMissing == nil then missing = true end
        if native == true then self.nativeFlagHits = (self.nativeFlagHits or 0) + 1 end
        if missing == true then
            kept[#kept+1] = entry
        else
            known = known + 1
            if missing == nil then unknown = unknown + 1 end
        end
    end
    if self.collecting and not self.replayingPage then
        local search = TRADING_HOUSE_SEARCH
        local page = search and type(search.GetPage)=='function' and search:GetPage() or nil
        if type(page)=='number' and not self.collectedPages[page] then
            self.collectedPages[page] = true
            for i=1,#kept do
                local source = kept[i]
                local data = type(source)=='table' and source.data or nil
                if type(data)=='table' then
                    -- Copy wrapper, never mutate ESO's native purchase slot.
                    local copy = {}
                    for k,v in pairs(data) do copy[k]=v end
                    copy.gmsSourcePage = page
                    copy.gmsItemLink = EntryLink(source)
                    -- Capture immutable listing identity while its server page is live.
                    -- The result API returns uniqueId as its ninth return value.
                    -- The visible scroll-list index is NOT necessarily the native
                    -- trading-house result index after filtering. Resolve by item
                    -- link and verify price/seller where available. Never guess a
                    -- purchase slot or borrow an ID from a different listing.
                    if type(GetTradingHouseSearchResultItemInfo)=='function'
                        and type(GetTradingHouseSearchResultItemLink)=='function'
                        and type(GetTradingHouseSearchResultsInfo)=='function' then
                        local countOk, nativeCount=pcall(GetTradingHouseSearchResultsInfo)
                        if countOk and type(nativeCount)=='number' then
                            local expectedPrice=copy.purchasePrice or copy.price or copy.totalPrice
                            local expectedSeller=copy.sellerName or copy.seller
                            local matches={}
                            for slot=1,nativeCount do
                                local linkOk,liveLink=pcall(GetTradingHouseSearchResultItemLink,slot,LINK_STYLE_DEFAULT)
                                if linkOk and liveLink==copy.gmsItemLink then
                                    local infoOk,_,_,_,_,seller,_,price,_,uniqueId=pcall(GetTradingHouseSearchResultItemInfo,slot)
                                    if infoOk and uniqueId~=nil and type(price)=='number' and price>0
                                        and (type(expectedPrice)~='number' or price==expectedPrice)
                                        and (type(expectedSeller)~='string' or seller==expectedSeller) then
                                        matches[#matches+1]={id=uniqueId,price=price,seller=seller,slot=slot}
                                    end
                                end
                            end
                            -- A repeated item link can represent multiple sellers;
                            -- ambiguous matches must never be silently assigned.
                            if #matches==1 then
                                copy.gmsPurchaseId=matches[1].id
                                copy.gmsPurchasePrice=matches[1].price
                                copy.gmsSeller=matches[1].seller
                                copy.gmsLiveSlot=matches[1].slot
                                self.verifiedPurchaseIds=(self.verifiedPurchaseIds or 0)+1
                            else
                                self.unverifiedPurchaseIds=(self.unverifiedPurchaseIds or 0)+1
                            end
                        end
                    end
                    self.collected[#self.collected+1] = {typeId=source.typeId, data=copy}
                end
            end
        end
    end
    self.hiddenCount, self.unknownCount = known, unknown
    self.scrollCount, self.linkCount = originalCount, originalCount - unknown
    self.visibleFilterStatus = 'filtered'
    self:UpdateEmptyPageNavigation(#kept == 0)
    -- Preserve the original native entry objects, including their purchase slots.
    -- Do not alter searchResultItemDataList or any server-provided indexes.
    if known == 0 then return end
    self.originalScrollEntries = {}
    for i=1,originalCount do self.originalScrollEntries[i]=entries[i] end
    for i=originalCount,1,-1 do entries[i]=nil end
    for i=1,#kept do entries[i]=kept[i] end
    if type(ZO_ScrollList_Commit) == 'function' then
        local committed, err = pcall(ZO_ScrollList_Commit, list)
        if committed then
            -- A scroll-list commit can leave the previous selected item pointing
            -- to a removed entry. Re-anchor the gamepad selection to a retained
            -- native entry; do not alter any purchase data or slot indexes.
            local selectionStatus = 'empty'
            if #kept > 0 then
                local first = kept[1]
                local selected = false
                if type(ZO_ScrollList_SelectData) == 'function' and type(first)=='table' then
                    local okSelect = pcall(ZO_ScrollList_SelectData, list, first.data)
                    selected = okSelect
                    if selected then selectionStatus = 'select-data' end
                end
                if not selected and type(ZO_ScrollList_TrySelectFirstData)=='function' then
                    selected = pcall(ZO_ScrollList_TrySelectFirstData, list)
                    if selected then selectionStatus='select-first' end
                end
                if type(ZO_ScrollList_ResetToTop)=='function' then
                    pcall(ZO_ScrollList_ResetToTop, list)
                end
                if type(ZO_ScrollList_ScrollDataIntoView)=='function' then
                    pcall(ZO_ScrollList_ScrollDataIntoView, list, 1)
                end
                if not selected then selectionStatus='selection-unavailable' end
            end
            self.navigationStatus=selectionStatus
            self.visibleFilterStatus='filtered-nav-'..selectionStatus
        end
        if not committed then
            for i=#entries,1,-1 do entries[i]=nil end
            for i=1,#self.originalScrollEntries do entries[i]=self.originalScrollEntries[i] end
            self.originalScrollEntries=nil
            self.visibleFilterStatus='commit-error'
            Say('FILTER commit error: '..tostring(err))
        end
    else
        self.visibleFilterStatus='commit-unavailable'
    end
end
function GMS:InstallFilterHook()
    local panel = self:GetPanel()
    if not panel then return false end
    if self.hookedPanel == panel and type(panel.FilterScrollList) == 'function' then return true end
    local original = panel.FilterScrollList
    if type(original) ~= 'function' then return false end
    panel.FilterScrollList = function(instance, ...)
        local result = { pcall(original, instance, ...) }
        if not result[1] then
            if not GMS.filterErrorShown then
                GMS.filterErrorShown = true
                Say('FILTER native error: ' .. tostring(result[2]))
            end
            return nil
        end
        if GMS.combinedVisible and GMS.traderOpen and GMS.enabled then
            GMS:ShowCombinedPage()
            return unpack(result, 2)
        end
        GMS.originalScrollEntries = nil -- native rebuild supersedes any prior snapshot
        if not GMS.enabled then GMS:UpdateEmptyPageNavigation(false) end
        if GMS.traderOpen and GMS.enabled and not GMS.combinedVisible then
            local ok, err = pcall(GMS.FilterVisibleEntries, GMS, instance)
            if not ok then
                GMS.visibleFilterStatus = 'filter-error'
                Say('FILTER visible error: ' .. tostring(err))
            end
        end
        return unpack(result, 2)
    end
    self.hookedPanel, self.filterHookInstalled = panel, true
    return true
end
function GMS:RefreshResults()
    local panel = self:GetPanel()
    if not panel or type(panel.FilterScrollList) ~= 'function' then return false end
    self.hiddenCount, self.unknownCount = 0, 0
    if not self.enabled then self:UpdateEmptyPageNavigation(false) end
    self.visibleFilterStatus = 'refresh-pending'
    self.navigationStatus = 'none'
    -- Restore prior visible entries before native refresh when turning OFF.
    if not self.enabled and self.originalScrollEntries and type(ZO_ScrollList_GetDataList)=='function' then
        local okList, entries = pcall(ZO_ScrollList_GetDataList, panel.list)
        if okList and type(entries)=='table' then
            for i=#entries,1,-1 do entries[i]=nil end
            for i=1,#self.originalScrollEntries do entries[i]=self.originalScrollEntries[i] end
            if type(ZO_ScrollList_Commit)=='function' then pcall(ZO_ScrollList_Commit,panel.list) end
        end
        self.originalScrollEntries=nil
    end
    local ok, err = pcall(panel.FilterScrollList, panel)
    if not ok then Say('FILTER refresh error: ' .. tostring(err)) end
    return ok
end
-- Diagnostic: identify which browse-result objects/methods exist on console.
-- No automatic searches and no modification to ESO's purchase callbacks.
-- Read-only inspection of the live gamepad results and list implementations.
-- We deliberately do NOT mutate masterList, list.data, or result indexes.
local function Describe(value)
    if type(value) ~= 'table' then return type(value) end
    local n = 0
    for _ in pairs(value) do n = n + 1; if n >= 999 then break end end
    return 'table(' .. tostring(n) .. ')'
end
local function InspectMethods(label, object)
    if type(object) ~= 'table' then
        Say('DIAG ' .. label .. '=' .. type(object)); return
    end
    local methods, fields = {}, {}
    local function Scan(t, prefix)
        if type(t) ~= 'table' then return end
        for k,v in pairs(t) do
            if type(k) == 'string' then
                local lower = string.lower(k)
                if string.find(lower,'list') or string.find(lower,'result') or
                   string.find(lower,'entry') or string.find(lower,'refresh') or
                   string.find(lower,'populate') or string.find(lower,'update') or
                   string.find(lower,'data') or string.find(lower,'filter') then
                    local entry = prefix .. k .. ':' .. Describe(v)
                    if type(v) == 'function' then methods[#methods+1] = entry
                    else fields[#fields+1] = entry end
                end
            end
        end
    end
    Scan(object, '')
    local mt = getmetatable(object)
    if type(mt) == 'table' then
        Scan(mt, 'mt.')
        if type(mt.__index) == 'table' then Scan(mt.__index, 'index.') end
    end
    table.sort(methods); table.sort(fields)
    Say('DIAG ' .. label .. ' metatable=' .. type(mt) .. ' methods=' ..
        (#methods > 0 and table.concat(methods, ', ', 1, math.min(#methods, 18)) or 'none'))
    Say('DIAG ' .. label .. ' fields=' ..
        (#fields > 0 and table.concat(fields, ', ', 1, math.min(#fields, 12)) or 'none'))
end
function GMS:DiagnoseBrowse()
    local panel = self:GetPanel()
    Say('DIAG panel=' .. type(panel) .. ', class=' .. type(ZO_GamepadTradingHouse_BrowseResults))
    if not panel then return end
    InspectMethods('panel', panel)
    InspectMethods('list', panel.list)
    InspectMethods('masterList', panel.masterList)
    InspectMethods('results', panel.searchResultItemDataList)
    local list = panel.list
    if type(list) == 'table' then
        Say('DIAG list data=' .. Describe(list.data) .. ', dataList=' ..
            Describe(list.dataList) .. ', entries=' .. Describe(list.entries) ..
            ', GetNumEntries=' .. type(list.GetNumEntries) ..
            ', Clear=' .. type(list.Clear) .. ', AddEntry=' .. type(list.AddEntry) ..
            ', Commit=' .. type(list.Commit))
    end
    local result = panel.searchResultItemDataList
    if type(result) == 'table' then
        local first = result[1]
        if type(first) == 'table' then
            local keys = {}
            for k,v in pairs(first) do
                if type(k) == 'string' and #keys < 18 then
                    keys[#keys+1] = k .. ':' .. type(v)
                end
            end
            table.sort(keys)
            Say('DIAG first result keys: ' .. table.concat(keys, ', '))
        else
            Say('DIAG first result=' .. type(first))
        end
    end
    Say('DIAG hook=' .. tostring(self.filterHookInstalled) ..
        ', original count=' .. Describe(result) .. ', hidden=' .. tostring(self.hiddenCount or 0))
end

-- Inspect only the loaded results. Never request new pages or alter purchase indexes.
-- This report distinguishes unsupported item types from failed ownership checks.
function GMS:DiagnoseCollections()
    local panel = self:GetPanel()
    local results = panel and panel.searchResultItemDataList
    if type(results) ~= 'table' then Say('COLLECT: no results table available'); return end
    local totals = {all=0, recipes=0, motifs=0, other=0, known=0, missing=0, uncertain=0, invalid=0}
    local types = {}
    local samples = {}
    for i=1,#results do
        local data=results[i]
        totals.all=totals.all+1
        local link=type(data)=='table' and (data.itemLink or data.link) or nil
        if type(link)~='string' or link=='' then
            totals.invalid=totals.invalid+1
        else
            local ok,t=pcall(GetItemLinkItemType,link)
            if not ok then t='API_ERROR' end
            local key=tostring(t)
            types[key]=(types[key] or 0)+1
            local category
            if t==ITEMTYPE_RECIPE then category='recipe'; totals.recipes=totals.recipes+1
            elseif t==ITEMTYPE_RACIAL_STYLE_MOTIF then category='motif'; totals.motifs=totals.motifs+1
            else category='other'; totals.other=totals.other+1 end
            local status=self:Missing(link)
            if status==false then totals.known=totals.known+1
            elseif status==true then totals.missing=totals.missing+1
            else totals.uncertain=totals.uncertain+1 end
            if category~='other' and #samples<4 then
                local name=type(data.name)=='string' and data.name or '?'
                samples[#samples+1]=category..':'..name:sub(1,38)..'='..(status==false and 'KNOWN' or status==true and 'MISSING' or 'UNKNOWN')
            end
        end
    end
    local distribution={}
    for k,v in pairs(types) do distribution[#distribution+1]={k,v} end
    table.sort(distribution,function(a,b) return a[2]>b[2] end)
    local top={}
    for i=1,math.min(#distribution,6) do top[#top+1]=distribution[i][1]..'='..distribution[i][2] end
    Say('COLLECT loaded='..totals.all..' motifs='..totals.motifs..' recipes='..totals.recipes..' other='..totals.other..' invalid='..totals.invalid)
    Say('COLLECT known='..totals.known..' missing='..totals.missing..' uncertain='..totals.uncertain)
    Say('COLLECT item types: '..table.concat(top,', '))
    Say('COLLECT APIs recipe='..type(IsItemLinkRecipeKnown)..' book='..type(IsItemLinkBookKnown)..' itemType='..type(GetItemLinkItemType))
    if #samples>0 then Say('COLLECT samples: '..table.concat(samples,'; '))
    else Say('COLLECT no motif/recipe in current 100 results; search motifs or recipes for a meaningful test') end
end


-- Combined list is a preview. Cross-page purchases are never submitted.
-- Diagnostic counters only: no saved variables and no additional server requests.
local function DiagnosticTime()
    if type(GetFrameTimeMilliseconds)=='function' then return GetFrameTimeMilliseconds() end
    return 0
end
local function DiagnosticPrint(message)
    local line='[GMS DIAG] '..tostring(message)
    if not GMS.debug then return end
    if false and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then CHAT_ROUTER:AddSystemMessage(line) elseif false and type(d)=='function' then d(line) end
end
function GMS:DiagnosticSummary()
    local diag=self.scanDiagnostic
    if not diag then DiagnosticPrint('No scan recorded yet.'); return end
    local elapsed=math.max(0,DiagnosticTime()-(diag.start or 0))
    DiagnosticPrint('SUMMARY elapsed='..math.floor(elapsed/1000)..'s pages='..tostring(diag.pages or 0)..' matches='..tostring(#(self.collected or {}))..' transitions='..tostring(diag.transitions or 0)..' waiting='..tostring(diag.waiting or 0)..' complete='..tostring(diag.complete or 0)..' nextRequests='..tostring(diag.requests or 0)..' currentESOPage='..tostring(TRADING_HOUSE_SEARCH and TRADING_HOUSE_SEARCH.GetPage and TRADING_HOUSE_SEARCH:GetPage() or '?'))
end
-- Present cached matches in pages of 25 while preserving their original
-- unique listing identities. No purchase slot is ever rewritten.
GMS.combinedPageSize = 25
-- v1.0.5: cache-preserving name filtering. Read ESO's search model only;
-- never change native server search criteria or listing purchase identities.
-- v1.0.5a: ESO gamepad search UI may keep submitted text in its
-- browse filter controls instead of TRADING_HOUSE_SEARCH getters.
-- Read-only access: never call Search(), change criteria, or issue requests.
local function ReadNameFromObject(object)
    if type(object)~='table' then return nil end
    local methods={'GetSearchTerm','GetSearchText','GetNameFilter','GetTextFilter'}
    for _,method in ipairs(methods) do
        local fn=object[method]
        if type(fn)=='function' then
            local ok,value=pcall(fn,object)
            if ok and type(value)=='string' then return value end
        end
    end
    local fields={'searchTerm','searchText','nameFilter','textFilter','searchName','itemNameFilter'}
    for _,field in ipairs(fields) do
        if type(object[field])=='string' then return object[field] end
    end
    return nil
end
function GMS:ReadCachedNameQuery()
    -- PS5 v1.0.5d probe confirmed this exact gamepad browse field.
    -- This is the submitted text, not the transient keyboard edit box.
    local browse=GAMEPAD_TRADING_HOUSE_BROWSE
        or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
    local feature=browse and browse.features and browse.features.nameSearchFeature
    if feature and type(feature.searchText)=='string' then
        return feature.searchText
    end
    local search=TRADING_HOUSE_SEARCH
    local browse=GAMEPAD_TRADING_HOUSE_BROWSE
        or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
    local panel=self:GetPanel()
    -- Prefer the live gamepad browse filter, where Square submits text.
    local sources={
        browse and browse.searchFilters,
        browse and browse.searchFilter,
        browse and browse.filterData,
        browse and browse.searchData,
        browse,
        panel and panel.searchFilters,
        panel and panel.searchFilter,
        search and search.searchFilters,
        search and search.searchData,
        search,
    }
    for i=1,10 do
        local query=ReadNameFromObject(sources[i])
        if query~=nil then return query end
    end
    -- Common edit-box controls, when exposed as gamepad browse fields.
    local controls={
        browse and browse.nameEdit,
        browse and browse.nameEditBox,
        browse and browse.searchEdit,
        browse and browse.searchEditBox,
        browse and browse.textSearch,
        browse and browse.searchTextControl,
        panel and panel.nameEdit,
        panel and panel.searchEdit,
    }
    for i=1,8 do
        local control=controls[i]
        if control and type(control.GetText)=='function' then
            local ok,value=pcall(control.GetText,control)
            if ok and type(value)=='string' then return value end
        end
    end
    return nil
end
-- v1.0.5f: Price filters apply only to the already collected listings.
-- ESO gamepad feature field names vary; use only validated numeric bounds.
local function GMSPriceNumber(v)
    if type(v)=='number' then return v end
    if type(v)=='string' then return tonumber((v:gsub('[^%d]',''))) end
    return nil
end
function GMS:ReadCachedPriceBounds()
    local browse=GAMEPAD_TRADING_HOUSE_BROWSE
        or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
    local features=browse and browse.features
    if type(features)~='table' then return nil,nil end
    local candidates={features.priceRangeFeature,features.priceSearchFeature,
        features.priceFeature,features.priceFilterFeature,features}
    for _,obj in ipairs(candidates) do
        if type(obj)=='table' then
            local lo=GMSPriceNumber(obj.minPrice or obj.minimumPrice or obj.minValue or obj.min)
            local hi=GMSPriceNumber(obj.maxPrice or obj.maximumPrice or obj.maxValue or obj.max)
            if lo~=nil or hi~=nil then
                if lo and lo<0 then lo=0 end
                if hi and hi>=2100000000 then hi=nil end
                return lo,hi
            end
        end
    end
    return nil,nil
end
function GMS:ProbePriceSources()
    local function emit(msg)
        local line='[GMS PRICE PROBE] '..msg
        if false and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then CHAT_ROUTER:AddSystemMessage(line)
        elseif false and type(d)=='function' then d(line) end
    end
    local browse=GAMEPAD_TRADING_HOUSE_BROWSE
        or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
    local features=browse and browse.features
    local lo,hi=self:ReadCachedPriceBounds()
    emit('read min='..tostring(lo)..' max='..tostring(hi))
    if type(features)~='table' then emit('browse.features unavailable'); return end
    local count=0
    for key,obj in pairs(features) do
        if type(key)=='string' and (key:lower():find('price') or key:lower():find('range')) then
            emit('feature='..key..' type='..type(obj))
            if type(obj)=='table' then
                for k,v in pairs(obj) do
                    if type(k)=='string' and (k:lower():find('price') or k:lower():find('min') or k:lower():find('max') or k:lower():find('value'))
                        and (type(v)=='number' or type(v)=='string') then
                        emit(key..'.'..k..'='..tostring(v)); count=count+1
                        if count>=18 then emit('limit reached'); return end
                    end
                end
            end
        end
    end
    emit('end')
end
-- v1.0.5g: Read the selected native gamepad quality without changing server filters.
-- Unknown feature shapes deliberately leave the cached list unfiltered.
local function GMSQualityNumber(value)
    if type(value)=='number' then return value end
    if type(value)=='table' then
        return GMSQualityNumber(value.quality or value.itemQuality or value.value)
    end
    return nil
end
function GMS:ReadCachedQuality()
    local browse=GAMEPAD_TRADING_HOUSE_BROWSE
        or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
    local features=browse and browse.features
    if type(features)~='table' then return nil end
    for _,key in ipairs({'qualityFeature','qualitySearchFeature','qualityFilterFeature','itemQualityFeature'}) do
        local feature=features[key]
        if type(feature)=='table' then
            -- Native gamepad dropdown is one-based: Any=1, Normal=2, Fine=3,
            -- Superior=4, Epic=5, Legendary=6. Item quality constants are
            -- Normal=1 through Legendary=5. Confirmed Epic index=5 on PS5.
            local choice=tonumber(feature.selectedChoiceIndex)
            if choice then
                choice=math.floor(choice)
                if choice==1 then return nil end
                if choice>=2 and choice<=6 then return choice-1 end
                -- Unknown choice: leave results unfiltered, never guess.
                return nil
            end
            local value=GMSQualityNumber(feature.selectedQuality or feature.quality
                or feature.selectedValue or feature.currentValue or feature.value)
            if value and value>=1 and value<=5 then return value end
        end
    end
    return nil
end
-- v1.0.5h: protected, bounded quality probe. Does not modify scan/filter state.
local function GMSQualityProbeOutput(msg)
    local line='[GMS QUALITY] '..tostring(msg)
    -- d() is the same native chat output used by ESO diagnostic messages.
    if type(d)=='function' then
        local ok=pcall(d,line)
        if ok then return end
    end
    if false and CHAT_ROUTER and type(CHAT_ROUTER.AddSystemMessage)=='function' then
        pcall(CHAT_ROUTER.AddSystemMessage,CHAT_ROUTER,line)
    end
end
function GMS:ProbeQualitySources()
    GMSQualityProbeOutput('v1.0.5i probe running')
    local ok,err=pcall(function()
        GMSQualityProbeOutput('mapped quality='..tostring(self:ReadCachedQuality()))
        local browse=GAMEPAD_TRADING_HOUSE_BROWSE
            or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
        if not browse then GMSQualityProbeOutput('browse unavailable'); return end
        local roots={{'features',browse.features},{'browse',browse},{'panel',self:GetPanel()}}
        local count=0
        for _,root in ipairs(roots) do
            local prefix,obj=root[1],root[2]
            if type(obj)=='table' then
                for key,value in pairs(obj) do
                    if type(key)=='string' and (key:lower():find('quality',1,true) or key:lower():find('filter',1,true)) then
                        GMSQualityProbeOutput(prefix..'.'..key..' ['..type(value)..']')
                        count=count+1
                        if type(value)=='table' then
                            local fields=0
                            for field,inner in pairs(value) do
                                if type(field)=='string' and (field:lower():find('quality',1,true)
                                    or field:lower():find('select',1,true)
                                    or field:lower():find('value',1,true)
                                    or field:lower():find('index',1,true)
                                    or field:lower():find('current',1,true)) then
                                    GMSQualityProbeOutput('  '..field..'='..tostring(inner))
                                    fields=fields+1
                                    if fields>=6 then break end
                                end
                            end
                        end
                        if count>=12 then GMSQualityProbeOutput('limit reached'); return end
                    end
                end
            end
        end
        GMSQualityProbeOutput('end; matches='..count)
    end)
    if not ok then GMSQualityProbeOutput('probe error: '..tostring(err)) end
end

-- v1.0.5l: compact selected-category diagnostic; does not change working filters.
local function GMSCategoryLine(message)
    local line='[GMS CATEGORY] '..tostring(message)
    if false and CHAT_ROUTER and type(CHAT_ROUTER.AddSystemMessage)=='function' then
        local ok=pcall(CHAT_ROUTER.AddSystemMessage,CHAT_ROUTER,line)
        if ok then return end
    end
    if type(d)=='function' then pcall(d,line) end
end
function GMS:ProbeCategorySources()
    GMSCategoryLine('v1.0.5n category hierarchy probe')
    local ok,err=pcall(function()
        local browse=GAMEPAD_TRADING_HOUSE_BROWSE or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
        local feature=browse and browse.features and browse.features.searchCategoryFeature
        if type(feature)~='table' then GMSCategoryLine('category feature unavailable'); return end
        GMSCategoryLine('header='..tostring(feature.selectedHeader)..' subkey='..tostring(feature.selectedSubcategoryKey))
        for _,field in ipairs({'selectedCategoryKey','selectedSubcategoryKey','selectedHeader','selectedCategory','selectedCategoryData','selectedSubcategory','categoryEntryData','subcategoryEntryData','selectedCategoryEntry','selectedSubcategoryEntry'}) do
            local value=feature[field]
            if type(value)=='table' then
                local parts={}
                for _,subfield in ipairs({'key','header','name','category','categoryKey','subcategoryKey','itemType','specializedItemType','isAllItemsCategory'}) do
                    local v=value[subfield]
                    if type(v)=='string' or type(v)=='number' or type(v)=='boolean' then parts[#parts+1]=subfield..'='..tostring(v) end
                end
                GMSCategoryLine(field..'={'..table.concat(parts,',')..'}')
            elseif value~=nil then
                GMSCategoryLine(field..'='..tostring(value))
            end
        end
        for key,value in pairs(feature) do
            if type(key)=='string' and (string.find(string.lower(key),'selected',1,true) or string.find(string.lower(key),'categorykey',1,true)) then
                if type(value)=='string' or type(value)=='number' or type(value)=='boolean' then
                    GMSCategoryLine('feature.'..key..'='..tostring(value))
                end
            end
        end
        local entry=feature.categoryEntryData
        if type(entry)=='table' then
            for _,key in ipairs({'key','header','category','categoryKey','subcategoryKey','specializedItemType','itemType','filterType'}) do
                local v=entry[key]
                if type(v)=='string' or type(v)=='number' or type(v)=='boolean' then
                    GMSCategoryLine('entry.'..key..'='..tostring(v))
                end
            end
        end
        local count=0
        for _,record in ipairs(self.collected or {}) do
            local data=record and record.data
            if type(data)=='table' then
                local link=data.itemLink or data.gmsItemLink or data.link
                if type(link)=='string' and link~='' then
                    local function read(fn)
                        if type(fn)~='function' then return 'API unavailable' end
                        local success,x,y=pcall(fn,link)
                        if not success then return 'error' end
                        return tostring(x)..(y~=nil and (','..tostring(y)) or '')
                    end
                    GMSCategoryLine('item '..tostring(data.name or data.itemName or '?'):sub(1,24)
                        ..' type='..read(GetItemLinkItemType)
                        ..' specialized='..read(GetItemLinkSpecializedItemType))
                    count=count+1
                    if count>=5 then break end
                end
            end
        end
        GMSCategoryLine('end; samples='..count)
    end)
    if not ok then GMSCategoryLine('error: '..tostring(err)) end
end

-- v1.0.5o: preserve header selection when last dropdown is AllSubcategories.
-- v1.0.5p: guarded read of the second-level native category selection.
-- Do not treat an empty final-level AllSubcategories key as "all consumables".
local function GMSNativeCategorySelection(feature)
    local function keyOf(value)
        if type(value)=='string' then return value end
        if type(value)=='table' then
            return value.key or value.categoryKey or value.selectedCategoryKey
                or (type(value.data)=='table' and value.data.key)
        end
        return nil
    end
    -- PS5 confirmed: selectedCategoryParams.key = Consumable8 for Motif.
    local params=feature.selectedCategoryParams
    local nativeKey=keyOf(params)
    if type(nativeKey)=='string' and nativeKey~='' then return nativeKey end
    for _,field in ipairs({'selectedCategoryKey','selectedCategory','selectedCategoryData',
        'selectedCategoryEntry','categoryEntryData'}) do
        local key=keyOf(feature[field])
        if type(key)=='string' and key~='' then return key end
    end
    for _,field in ipairs({'categoryDropdown','categoryDropDown','categoryComboBox',
        'categorySelector','categoryList'}) do
        local control=feature[field]
        if type(control)=='table' then
            for _,method in ipairs({'GetSelectedItemData','GetSelectedItem','GetSelectedData'}) do
                if type(control[method])=='function' then
                    local ok,value=pcall(control[method],control)
                    local key=ok and keyOf(value) or nil
                    if type(key)=='string' and key~='' then return key end
                end
            end
        end
    end
    return nil
end

-- Focused second-level selection probe. Reports values only; never changes filters.

-- v1.0.5z: Jewelry-specific read-only selection diagnostic.
function GMS:ProbeJewelrySelection()
    local browse=GAMEPAD_TRADING_HOUSE_BROWSE or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
    local feature=browse and browse.features and browse.features.searchCategoryFeature
    GMSCategoryLine('JEWELRY PROBE v1.0.6a')
    if type(feature)~='table' then GMSCategoryLine('No category feature'); return end
    local params=feature.selectedCategoryParams
    GMSCategoryLine('header='..tostring(feature.selectedHeader)..' parent='..tostring(GMSNativeCategorySelection(feature))..' third='..tostring(feature.selectedSubcategoryKey))
    if type(params)=='table' then
        for _,k in ipairs({'key','name','text','label','equipType','equipmentType','categoryKey','itemType','index','categoryIndex'}) do
            GMSCategoryLine('params.'..k..'='..tostring(params[k]))
        end
    end
    local map=feature.headerToCategoriesMap
    local choices=type(map)=='table' and map[feature.selectedHeader]
    if type(choices)=='table' then
        for i,v in ipairs(choices) do
            if i>8 then break end
            if type(v)=='table' then
                GMSCategoryLine('option['..i..'] key='..tostring(v.key)..' name='..tostring(v.name)..' text='..tostring(v.text)..' equip='..tostring(v.equipType))
            end
        end
    end
    local sample=0
    for _,entry in ipairs(self.collected or {}) do
        local d=entry.data
        local link=type(d)=='table' and (d.itemLink or d.gmsItemLink or d.link)
        if type(link)=='string' and type(GetItemLinkEquipType)=='function' then
            local ok,equip=pcall(GetItemLinkEquipType,link)
            if ok and (equip==EQUIP_TYPE_NECK or equip==EQUIP_TYPE_RING) then
                GMSCategoryLine('sample equip='..tostring(equip)..' neck='..tostring(EQUIP_TYPE_NECK)..' ring='..tostring(EQUIP_TYPE_RING)..' name='..tostring(d.name or d.itemName):sub(1,28))
                sample=sample+1
                if sample>=2 then break end
            end
        end
    end
    GMSCategoryLine('END JEWELRY PROBE')
end


-- v1.0.6d: Read-only native category-depth probe. Do not alter matching.
function GMS:ProbeFilterDepth()
    local browse=GAMEPAD_TRADING_HOUSE_BROWSE
        or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
    local feature=browse and browse.features and browse.features.searchCategoryFeature
    GMSCategoryLine('DEPTH PROBE v1.0.6f')
    if type(feature)~='table' then
        GMSCategoryLine('Category feature unavailable')
        return
    end
    GMSCategoryLine('header='..tostring(feature.selectedHeader))
    GMSCategoryLine('parent='..tostring(GMSNativeCategorySelection(feature)))
    GMSCategoryLine('subcategory='..tostring(feature.selectedSubcategoryKey))
    local params=feature.selectedCategoryParams
    if type(params)=='table' then
        for _,k in ipairs({'key','name','text','label','itemType','equipType','weaponType','armorType','specializedItemType'}) do
            local v=params[k]
            if type(v)=='string' or type(v)=='number' then
                GMSCategoryLine('params.'..k..'='..tostring(v))
            end
        end
    end
    for _,k in ipairs({'selectedCategoryKey','selectedSubcategoryKey','selectedLevelType','selectedLevelRange','selectedLevel','selectedChampionPoints'}) do
        local v=feature[k]
        if type(v)=='string' or type(v)=='number' or type(v)=='boolean' then
            GMSCategoryLine('feature.'..k..'='..tostring(v))
        end
    end
    GMSCategoryLine('END DEPTH PROBE')
end

function GMS:ProbeParentDropdown()
    GMSCategoryLine('v1.0.5r SECOND LEVEL SELECTION')
    local browse=GAMEPAD_TRADING_HOUSE_BROWSE or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
    local feature=browse and browse.features and browse.features.searchCategoryFeature
    if type(feature)~='table' then GMSCategoryLine('feature missing'); return end
    local function show(prefix,obj,depth)
        if type(obj)~='table' then return end
        local n=0
        for k,v in pairs(obj) do
            if type(k)=='string' and (string.find(string.lower(k),'categor',1,true)
                or string.find(string.lower(k),'select',1,true)
                or string.find(string.lower(k),'dropdown',1,true)
                or string.find(string.lower(k),'combo',1,true)
                or string.find(string.lower(k),'entry',1,true)) then
                n=n+1
                if n>35 then break end
                if type(v)=='string' or type(v)=='number' or type(v)=='boolean' then
                    GMSCategoryLine(prefix..k..'='..tostring(v):sub(1,65))
                elseif type(v)=='table' then
                    GMSCategoryLine(prefix..k..'={table}')
                    if depth>0 then
                        for _,f in ipairs({'key','name','text','label','categoryKey','selectedKey','selectedIndex','selectedItem','selectedData','data'}) do
                            local x=v[f]
                            if type(x)=='string' or type(x)=='number' then GMSCategoryLine('  '..f..'='..tostring(x):sub(1,65)) end
                        end
                        for _,method in ipairs({'GetSelectedItemData','GetSelectedItem','GetSelectedData','GetSelectedItemText'}) do
                            if type(v[method])=='function' then
                                local ok,x=pcall(v[method],v)
                                if ok then
                                    if type(x)=='table' then GMSCategoryLine('  '..method..'={key='..tostring(x.key)..',text='..tostring(x.text)..',name='..tostring(x.name)..'}')
                                    else GMSCategoryLine('  '..method..'='..tostring(x):sub(1,65)) end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    show('feature.',feature,1)
    show('browse.',browse,0)
    GMSCategoryLine('END SECOND LEVEL')
end

-- v1.0.5t: infer the first-level family from ESO's own header category
-- descriptors, rather than assuming the numeric header order is universal.
local function GMSCategoryFamily(feature,header)
    if header==nil then return nil end
    local map=feature.headerToCategoriesMap
    local choices=type(map)=='table' and map[header] or nil
    if type(choices)=='table' then
        for _,choice in ipairs(choices) do
            if type(choice)=='table' then
                local key=choice.key
                if type(key)=='string' then
                    local lower=string.lower(key)
                    if string.sub(lower,1,3)=='all' then lower=string.sub(lower,4) end
                    for _,family in ipairs({'weapons','apparel','jewelry','jewellery','consumables',
                        'materials','glyphs','furnishings','companionequipment','miscellaneous','misc'}) do
                        if string.find(lower,family,1,true)==1 then return family=='misc' and 'miscellaneous' or family end
                    end
                end
            end
        end
    end
    -- Header values 1/2/3 were directly observed in the PS5 diagnostics.
    if header==1 then return 'weapons' end
    if header==2 then return 'apparel' end
    if header==3 then return 'consumables' end
    return nil
end

local function GMSIsItemType(itemType,...)
    for i=1,select('#',...) do
        local candidate=select(i,...)
        if candidate~=nil and itemType==candidate then return true end
    end
    return false
end

function GMS:ReadCachedCategory()
    local browse=GAMEPAD_TRADING_HOUSE_BROWSE or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
    local feature=browse and browse.features and browse.features.searchCategoryFeature
    if type(feature)~='table' then return nil,nil,nil,nil,nil end
    local header=feature.selectedHeader
    local key=feature.selectedSubcategoryKey
    local parentKey=GMSNativeCategorySelection(feature)
    local specialized=type(key)=='string' and tonumber(string.match(key,'^SpecializedItemType(%d+)$')) or nil
    local family=GMSCategoryFamily(feature,header)
    if family==nil and type(parentKey)=='string' then
        local lower=string.lower(parentKey)
        if string.find(lower,'misc',1,true)==1 then family='miscellaneous' end
    end
    return tostring(header)..':'..tostring(parentKey)..':'..tostring(key),specialized,header,parentKey,family
end
-- v1.0.5v: Native category labels and ESO item attributes must be matched
-- independently. Native dropdown keys (Weapons6, Consumable3, etc.) are
-- category IDs, NOT GetItemLinkWeaponType / GetItemLinkArmorType enum values.
-- Read the food/drink type of the item produced by a provisioning recipe.
-- Not all ESO builds expose these functions; unavailable data stays unknown.
local function GMSRecipeResultType(recipeLink)
    local fn=GetItemLinkRecipeResultItemLink
    if type(fn)=='function' then
        local ok,result=pcall(fn,recipeLink)
        if ok and type(result)=='string' and result~='' and type(GetItemLinkItemType)=='function' then
            local resultOk,itemType=pcall(GetItemLinkItemType,result)
            if resultOk then return itemType end
        end
    end
    return nil
end

local function GMSMatchSecondLevel(link,itemType,parent,family)
    if type(parent)~='string' or parent=='' or string.sub(parent,1,3)=='All' then return nil end
    local browse=GAMEPAD_TRADING_HOUSE_BROWSE or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
    local feature=browse and browse.features and browse.features.searchCategoryFeature
    local params=feature and feature.selectedCategoryParams
    local label=type(params)=='table' and (params.name or params.text or params.label) or nil
    -- v1.0.5x: Some native selectedCategoryParams entries omit their display
    -- name. Resolve it through ESO's own category table by the selected key.
    if (type(label)~='string' or label=='') and feature then
        local map=feature.headerToCategoriesMap
        local selectedHeader=feature.selectedHeader
        local entries=type(map)=='table' and map[selectedHeader]
        if type(entries)=='table' then
            for _,candidate in pairs(entries) do
                if type(candidate)=='table' and candidate.key==parent then
                    label=candidate.name or candidate.text or candidate.label
                    if type(label)=='string' then break end
                end
            end
        end
    end
    local p=type(label)=='string' and string.lower(label) or ''
    local key=string.lower(parent)
    local function has(word) return string.find(p,word,1,true)~=nil end
    local function one(...) return GMSIsItemType(itemType,...) end
    local function field(fn)
        if type(fn)~='function' then return nil end
        local ok,value=pcall(fn,link)
        return ok and value or nil
    end
    local equip=field(GetItemLinkEquipType)
    local selectedEquip=type(params)=='table' and (params.equipType or params.equipmentType) or nil
    -- The native listing may carry an equip slot even when the link API
    -- cannot resolve it. Do not discard all jewelry on a missing slot.
    if equip==nil then
        local panelData=GMS._categoryMatchEntryData
        if type(panelData)=='table' then equip=panelData.equipType end
    end
    if family=='weapons' then
        local weapon=field(GetItemLinkWeaponType)
        if weapon==nil then return false end
        if has('one') or has('1h') then
            return weapon==WEAPONTYPE_AXE or weapon==WEAPONTYPE_HAMMER
                or weapon==WEAPONTYPE_SWORD or weapon==WEAPONTYPE_DAGGER
        elseif has('two') or has('2h') then
            return weapon==WEAPONTYPE_TWO_HANDED_AXE or weapon==WEAPONTYPE_TWO_HANDED_HAMMER
                or weapon==WEAPONTYPE_TWO_HANDED_SWORD
        elseif has('bow') then return weapon==WEAPONTYPE_BOW
        elseif has('destruction') then
            return weapon==WEAPONTYPE_FIRE_STAFF or weapon==WEAPONTYPE_FROST_STAFF
                or weapon==WEAPONTYPE_LIGHTNING_STAFF
        elseif has('restoration') then return weapon==WEAPONTYPE_HEALING_STAFF
        elseif has('shield') then return equip==EQUIP_TYPE_OFF_HAND end
        return false -- Never interpret WeaponsN as a weapon-type enum.
    elseif family=='apparel' then
        -- Keep the previously verified apparel logic, including ArmorN matching.
        local number=tonumber(string.match(parent,'^Armor(%d+)$'))
        if number then
            local actual=field(GetItemLinkArmorType)
            if actual~=nil then return actual==number end
        end
        if has('shield') then return equip==EQUIP_TYPE_OFF_HAND end
        return nil
    elseif family=='jewelry' or family=='jewellery' then
        -- Jewelry's native keys can be opaque and its display names can be
        -- absent on gamepad. ESO's ordered category list has All Pieces,
        -- Neck, Ring; use that selection order when no readable label exists.
        local selectedKind=nil
        if has('neck') or key:find('neck',1,true) or selectedEquip==EQUIP_TYPE_NECK then
            selectedKind='neck'
        elseif has('ring') or key:find('ring',1,true) or selectedEquip==EQUIP_TYPE_RING then
            selectedKind='ring'
        else
            local map=feature and feature.headerToCategoriesMap
            local entries=type(map)=='table' and map[feature.selectedHeader]
            if type(entries)=='table' then
                local chosenIndex=nil
                for i,choice in ipairs(entries) do
                    if type(choice)=='table' and choice.key==parent then
                        chosenIndex=i
                        break
                    end
                end
                if chosenIndex==2 then selectedKind='neck'
                elseif chosenIndex==3 then selectedKind='ring' end
            end
        end
        if selectedKind=='neck' then
            return equip~=nil and equip==EQUIP_TYPE_NECK or false
        elseif selectedKind=='ring' then
            return equip~=nil and equip==EQUIP_TYPE_RING or false
        end
        -- All Pieces retains first-level Jewelry filtering.
        return nil
    elseif family=='consumables' then
        if parent=='Consumable8' or has('motif') then return one(ITEMTYPE_RACIAL_STYLE_MOTIF) end
        if has('furnish') and (has('plan') or has('blueprint')) then
            if not one(ITEMTYPE_RECIPE) then return false end
            -- ESO furnishing plans are recipes, but the specialized subtype
            -- link API may be unavailable on gamepad. Plan-name prefixes
            -- distinguish them from food and drink recipes.
            local itemName=field(GetItemLinkName)
            local n=type(itemName)=='string' and string.lower(itemName) or ''
            return n:find('^blueprint:')~=nil or n:find('^pattern:')~=nil
                or n:find('^design:')~=nil or n:find('^diagram:')~=nil
                or n:find('^praxis:')~=nil or n:find('^formula:')~=nil
                or n:find('^sketch:')~=nil
        end
        if has('recipe') then
            if not one(ITEMTYPE_RECIPE) then return false end
            local itemName=field(GetItemLinkName)
            local n=type(itemName)=='string' and string.lower(itemName) or ''
            if n:find('^recipe:')==nil then return false end
            local resultType=GMSRecipeResultType(link)
            if has('food') then
                if resultType~=nil then return resultType==ITEMTYPE_FOOD end
                -- Never classify every unknown provisioning recipe as food.
                return false
            end
            if has('drink') then
                if resultType~=nil then return resultType==ITEMTYPE_DRINK end
                return false
            end
            return true
        end
        if has('container') then return one(ITEMTYPE_CONTAINER) end
        if has('repair') then return one(ITEMTYPE_AVA_REPAIR) end
        if has('scroll') then return one(ITEMTYPE_CROWN_ITEM,ITEMTYPE_TOOL) end
        if has('potion') then return one(ITEMTYPE_POTION) end
        if has('poison') then return one(ITEMTYPE_POISON) end
        if has('food') then return one(ITEMTYPE_FOOD) end
        if has('drink') then return one(ITEMTYPE_DRINK) end
        return false
    elseif family=='miscellaneous' then
        if has('soul') then return one(ITEMTYPE_SOUL_GEM) end
        if has('lure') then return one(ITEMTYPE_LURE) end
        if has('tool') then return one(ITEMTYPE_TOOL) end
        if has('siege') then return one(ITEMTYPE_SIEGE) end
        if has('tabard') then return one(ITEMTYPE_TABARD) end
        if has('trophy') then
            return one(ITEMTYPE_TROPHY,ITEMTYPE_TREASURE_MAP,ITEMTYPE_COLLECTIBLE,
                ITEMTYPE_RECIPE_FRAGMENT,ITEMTYPE_RUNBOX)
        end
        return false
    elseif family=='glyphs' then
        if has('weapon') then return one(ITEMTYPE_GLYPH_WEAPON) end
        if has('armor') then return one(ITEMTYPE_GLYPH_ARMOR) end
        if has('jewel') then return one(ITEMTYPE_GLYPH_JEWELRY) end
    elseif family=='companionequipment' then
        if has('weapon') then return one(ITEMTYPE_COMPANION_WEAPON) end
        if has('armor') then return one(ITEMTYPE_COMPANION_ARMOR) end
        if has('jewel') then return one(ITEMTYPE_COMPANION_JEWELRY) end
    elseif family=='furnishings' then
        if has('material') then return one(ITEMTYPE_FURNISHING_MATERIAL) end
        if has('furnish') then return one(ITEMTYPE_FURNISHING) end
    elseif family=='materials' then
        if has('alchemy') then return one(ITEMTYPE_ALCHEMY_BASE,ITEMTYPE_ALCHEMY_REAGENT) end
        if has('enchant') or has('rune') then
            return one(ITEMTYPE_ENCHANTING_RUNE_ASPECT,ITEMTYPE_ENCHANTING_RUNE_ESSENCE,ITEMTYPE_ENCHANTING_RUNE_POTENCY)
        end
        if has('ingredient') or has('provision') then return one(ITEMTYPE_INGREDIENT) end
        if has('style') then return one(ITEMTYPE_STYLE_MATERIAL) end
        if has('trait') then return one(ITEMTYPE_ARMOR_TRAIT,ITEMTYPE_WEAPON_TRAIT,ITEMTYPE_JEWELRY_TRAIT) end
        if has('furnish') then return one(ITEMTYPE_FURNISHING_MATERIAL) end
    end
    return nil
end

function GMS:CachedCategoryMatches(entry)
    local data=entry and entry.data
    local link=type(data)=='table' and (data.itemLink or data.gmsItemLink or data.link)
    local family=self.gmsCategoryFamily
    if type(link)~='string' or type(GetItemLinkItemType)~='function' then
        return self.gmsCategorySpecialized==nil and family==nil
    end
    local ok,itemType,specialized=pcall(GetItemLinkItemType,link)
    if not ok then return self.gmsCategorySpecialized==nil and family==nil end
    -- v1.0.6a: Jewelry's visible Neck/Ring choices are stored by ESO in
    -- selectedSubcategoryKey (EquipType2 / EquipType12), NOT the parent key.
    -- Use the verified native equip-type values and the actual item link.
    if family=='jewelry' or family=='jewellery' then
        local browse=GAMEPAD_TRADING_HOUSE_BROWSE
            or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
        local feature=browse and browse.features and browse.features.searchCategoryFeature
        local subkey=feature and feature.selectedSubcategoryKey
        local selectedEquip=type(subkey)=='string'
            and tonumber(string.match(subkey,'^EquipType(%d+)$')) or nil
        if selectedEquip~=nil then
            if type(GetItemLinkEquipType)~='function' then return false end
            local equipOk,equip=pcall(GetItemLinkEquipType,link)
            return equipOk and equip==selectedEquip
        end
    end
    -- v1.0.6b: Third-level native subtype keys are independent of the
    -- selected parent. Apply known ESO item-link enums before parent matching.
    -- AllSubcategories deliberately leaves the parent filter active.
    local browse=GAMEPAD_TRADING_HOUSE_BROWSE
        or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
    local feature=browse and browse.features and browse.features.searchCategoryFeature
    local subkey=feature and feature.selectedSubcategoryKey
    if type(subkey)=='string' and subkey~='AllSubcategories' then
        local subtype,number=string.match(subkey,'^(%a+)(%d+)$')
        number=tonumber(number)
        local getter=nil
        if subtype=='EquipType' then getter=GetItemLinkEquipType
        elseif subtype=='ArmorType' then getter=GetItemLinkArmorType
        elseif subtype=='WeaponType' then getter=GetItemLinkWeaponType
        elseif subtype=='ItemType' then
            return itemType==number
        end
        if getter~=nil and type(getter)=='function' then
            local valid,actual=pcall(getter,link)
            if not valid or actual~=number then return false end
            -- The parent still needs to match; do not return true here.
        end
    end
    -- v1.0.6f: Miscellaneous Trophy has its own native subcategory-key
    -- namespace. Preserve the working weapon/apparel/jewelry paths above.
    -- Parent Trophy matching remains handled by GMSMatchSecondLevel below.
    if family=='miscellaneous' and type(subkey)=='string' then
        local trophyIndex=tonumber(string.match(subkey,'^TrophySubcategory(%d+)$'))
        if trophyIndex~=nil then
            local function equalsType(...)
                for i=1,select('#',...) do
                    local t=select(i,...)
                    if t~=nil and itemType==t then return true end
                end
                return false
            end
            -- The ESO menu orders these as Treasure Map, Recipe Fragment,
            -- Scroll, Runebox Fragment, Other Trophies.
            if trophyIndex==1 then return equalsType(ITEMTYPE_TREASURE_MAP) end
            if trophyIndex==2 then return equalsType(ITEMTYPE_RECIPE_FRAGMENT) end
            if trophyIndex==3 then
                -- Scroll is represented by different item classifications
                -- across ESO releases; do not claim a verified match here.
                return equalsType(ITEMTYPE_TROPHY) and
                    type(GetItemLinkName)=='function' and
                    string.find(string.lower(GetItemLinkName(link) or ''),'scroll',1,true)~=nil
            end
            if trophyIndex==4 then return equalsType(ITEMTYPE_RUNBOX) end
            if trophyIndex==5 then
                return equalsType(ITEMTYPE_TROPHY,ITEMTYPE_COLLECTIBLE)
                    and not (type(GetItemLinkName)=='function'
                        and string.find(string.lower(GetItemLinkName(link) or ''),'scroll',1,true))
            end
            return false
        end
    end
    if self.gmsCategorySpecialized~=nil then return specialized==self.gmsCategorySpecialized end
    local parent=self.gmsCategoryParentKey
    GMS._categoryMatchEntryData=data
    local secondMatch=GMSMatchSecondLevel(link,itemType,parent,family)
    GMS._categoryMatchEntryData=nil
    if secondMatch~=nil then return secondMatch end
    if family=='consumables' and type(parent)=='string'
        and (parent=='Consumable8' or string.find(string.lower(parent),'motif',1,true)~=nil
            or string.find(string.lower(parent),'racialstyle',1,true)~=nil) then
        return itemType==ITEMTYPE_RACIAL_STYLE_MOTIF
    end
    if family=='weapons' then
        return GMSIsItemType(itemType,ITEMTYPE_WEAPON)
    elseif family=='apparel' then
        if not GMSIsItemType(itemType,ITEMTYPE_ARMOR,ITEMTYPE_COSTUME) then return false end
        if type(GetItemLinkEquipType)=='function' then
            local equipOk,equip=pcall(GetItemLinkEquipType,link)
            if equipOk and (equip==EQUIP_TYPE_RING or equip==EQUIP_TYPE_NECK) then return false end
        end
        return true
    elseif family=='jewelry' or family=='jewellery' then
        if type(GetItemLinkEquipType)=='function' then
            local equipOk,equip=pcall(GetItemLinkEquipType,link)
            if equipOk then return equip==EQUIP_TYPE_RING or equip==EQUIP_TYPE_NECK end
        end
        return false
    elseif family=='consumables' then
        return GMSIsItemType(itemType,ITEMTYPE_RECIPE,ITEMTYPE_RACIAL_STYLE_MOTIF,
            ITEMTYPE_POTION,ITEMTYPE_POISON,ITEMTYPE_FOOD,ITEMTYPE_DRINK,
            ITEMTYPE_CONTAINER,ITEMTYPE_SOUL_GEM,ITEMTYPE_LURE,ITEMTYPE_TOOL,
            ITEMTYPE_CROWN_ITEM,ITEMTYPE_MASTER_WRIT,ITEMTYPE_AVA_REPAIR)
    elseif family=='materials' then
        return GMSIsItemType(itemType,ITEMTYPE_BLACKSMITHING_MATERIAL,ITEMTYPE_CLOTHIER_MATERIAL,
            ITEMTYPE_WOODWORKING_MATERIAL,ITEMTYPE_JEWELRYCRAFTING_MATERIAL,
            ITEMTYPE_ALCHEMY_BASE,ITEMTYPE_ALCHEMY_REAGENT,ITEMTYPE_ENCHANTING_RUNE_ASPECT,
            ITEMTYPE_ENCHANTING_RUNE_ESSENCE,ITEMTYPE_ENCHANTING_RUNE_POTENCY,
            ITEMTYPE_INGREDIENT,ITEMTYPE_RAW_MATERIAL,ITEMTYPE_STYLE_MATERIAL,
            ITEMTYPE_ARMOR_TRAIT,ITEMTYPE_WEAPON_TRAIT,ITEMTYPE_JEWELRY_TRAIT,
            ITEMTYPE_FURNISHING_MATERIAL,ITEMTYPE_TEMPERS,ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL,
            ITEMTYPE_JEWELRYCRAFTING_BOOSTER,ITEMTYPE_CLOTHIER_RAW_MATERIAL,
            ITEMTYPE_BLACKSMITHING_RAW_MATERIAL,ITEMTYPE_WOODWORKING_RAW_MATERIAL)
    elseif family=='glyphs' then
        return GMSIsItemType(itemType,ITEMTYPE_GLYPH_ARMOR,ITEMTYPE_GLYPH_WEAPON,ITEMTYPE_GLYPH_JEWELRY)
    elseif family=='furnishings' then
        return GMSIsItemType(itemType,ITEMTYPE_FURNISHING,ITEMTYPE_FURNISHING_MATERIAL)
    elseif family=='companionequipment' then
        return GMSIsItemType(itemType,ITEMTYPE_COMPANION_ARMOR,ITEMTYPE_COMPANION_WEAPON,
            ITEMTYPE_COMPANION_JEWELRY)
    elseif family=='miscellaneous' then
        -- ESO's Miscellaneous group is heterogeneous. Exclude recognized
        -- other first-level families, without assuming every leftover item
        -- is necessarily classified Miscellaneous by ESO.
        if GMSIsItemType(itemType,ITEMTYPE_WEAPON,ITEMTYPE_ARMOR,ITEMTYPE_COSTUME,
            ITEMTYPE_RECIPE,ITEMTYPE_RACIAL_STYLE_MOTIF,ITEMTYPE_POTION,
            ITEMTYPE_POISON,ITEMTYPE_FOOD,ITEMTYPE_DRINK,ITEMTYPE_CONTAINER,
            ITEMTYPE_SOUL_GEM,ITEMTYPE_LURE,ITEMTYPE_TOOL,ITEMTYPE_CROWN_ITEM,
            ITEMTYPE_MASTER_WRIT,ITEMTYPE_AVA_REPAIR,
            ITEMTYPE_BLACKSMITHING_MATERIAL,ITEMTYPE_CLOTHIER_MATERIAL,
            ITEMTYPE_WOODWORKING_MATERIAL,ITEMTYPE_JEWELRYCRAFTING_MATERIAL,
            ITEMTYPE_ALCHEMY_BASE,ITEMTYPE_ALCHEMY_REAGENT,
            ITEMTYPE_ENCHANTING_RUNE_ASPECT,ITEMTYPE_ENCHANTING_RUNE_ESSENCE,
            ITEMTYPE_ENCHANTING_RUNE_POTENCY,ITEMTYPE_INGREDIENT,
            ITEMTYPE_RAW_MATERIAL,ITEMTYPE_STYLE_MATERIAL,ITEMTYPE_ARMOR_TRAIT,
            ITEMTYPE_WEAPON_TRAIT,ITEMTYPE_JEWELRY_TRAIT,
            ITEMTYPE_FURNISHING_MATERIAL,ITEMTYPE_TEMPERS,
            ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL,ITEMTYPE_JEWELRYCRAFTING_BOOSTER,
            ITEMTYPE_CLOTHIER_RAW_MATERIAL,ITEMTYPE_BLACKSMITHING_RAW_MATERIAL,
            ITEMTYPE_WOODWORKING_RAW_MATERIAL,ITEMTYPE_GLYPH_ARMOR,
            ITEMTYPE_GLYPH_WEAPON,ITEMTYPE_GLYPH_JEWELRY,ITEMTYPE_FURNISHING,
            ITEMTYPE_COMPANION_ARMOR,ITEMTYPE_COMPANION_WEAPON,
            ITEMTYPE_COMPANION_JEWELRY) then return false end
        return true
    end
    return true
end

-- v1.0.6i: read-only autocomplete state diagnostic. No search requests or UI mutations.
function GMS:ProbeNameAutocomplete()
    local browse=GAMEPAD_TRADING_HOUSE_BROWSE
        or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
    local feature=browse and browse.features and browse.features.nameSearchFeature
    local function emit(message)
        local line='[GMS NAME] '..tostring(message)
        if false and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
            CHAT_ROUTER:AddSystemMessage(line)
        elseif false and type(d)=='function' then d(line) end
    end
    local function brief(value)
        if type(value)=='string' then return string.sub(value,1,90) end
        if type(value)=='number' or type(value)=='boolean' then return tostring(value) end
        if type(value)=='table' then
            local parts={}
            for _,key in ipairs({'name','text','itemName','itemId','itemIdString','itemLink','label','value','id','key'}) do
                local v=value[key]
                if type(v)=='string' or type(v)=='number' then
                    parts[#parts+1]=key..'='..string.sub(tostring(v),1,55)
                end
            end
            return 'table{'..table.concat(parts,',')..'}'
        end
        return type(value)
    end
    emit('cachedQuery='..brief(self.gmsNameQuery)..' readQuery='..brief(self:ReadCachedNameQuery()))
    if type(feature)~='table' then emit('nameSearchFeature unavailable'); return end
    for _,key in ipairs({'searchText','selectedItem','selectedData','selectedItemData',
        'selectedName','selectedItemName','selectedSearchText','selectedSuggestion',
        'selectedResult','searchTerm','searchString','name','text','itemId',
        'selectedItemId','selectedItemLink','itemLink','searchResult','searchResults',
        'suggestions','autoComplete','autocomplete','autocompleteSelection'}) do
        local value=feature[key]
        if value~=nil then emit(key..'='..brief(value)) end
    end
    for _,method in ipairs({'GetSelectedItem','GetSelectedItemData','GetSelectedData',
        'GetSelectedItemText','GetSearchText','GetSearchTerm','GetSelectedItemName'}) do
        local fn=feature[method]
        if type(fn)=='function' then
            local ok,value=pcall(fn,feature)
            emit(method..'='..(ok and brief(value) or 'error'))
        end
    end
end
-- Normalize ESO's quoted autocomplete selections for cached item-name matching.
-- Only paired surrounding quotation marks are removed; internal quotes remain intact.
local function GMSNormalizeCachedNameQuery(value)
    if type(value)~='string' then return '' end
    value=value:gsub('^%s+',''):gsub('%s+$','')
    local pairsOfQuotes={{'"','"'},{'“','”'},{'„','“'},{"'","'"}}
    for _,pair in ipairs(pairsOfQuotes) do
        local first,last=pair[1],pair[2]
        if #value>=#first+#last and value:sub(1,#first)==first and value:sub(-#last)==last then
            value=value:sub(#first+1,#value-#last)
            value=value:gsub('^%s+',''):gsub('%s+$','')
            break
        end
    end
    return string.lower(value)
end
function GMS:RefreshCachedNameFilter()
    if not (self.traderOpen and self.enabled and self.combinedVisible) then return end

    local query=self:ReadCachedNameQuery()
    if query==nil then
        if not self.gmsNameSourceNotice then
            self.gmsNameSourceNotice=true
            Say('Name filter: ESO search-text getter unavailable; original scan remains unchanged.')
        end
        return
    end
    query=GMSNormalizeCachedNameQuery(query)
    local minPrice,maxPrice=self:ReadCachedPriceBounds()
    local quality=self:ReadCachedQuality()
    local categoryKey,categorySpecialized,categoryHeader,categoryParentKey,categoryFamily=self:ReadCachedCategory()
    if query==self.gmsNameQuery and minPrice==self.gmsMinPrice and maxPrice==self.gmsMaxPrice
        and quality==self.gmsQuality and categoryKey==self.gmsCategoryKey then
        local panel=self:GetPanel()
        local label=panel and panel.footer and panel.footer.pageNumberLabel
        if label and type(label.IsHidden)=='function' and label:IsHidden() then
            self:RefreshFilteredFooter()
        end
        return
    end
    self.gmsNameQuery=query
    self.gmsMinPrice,self.gmsMaxPrice=minPrice,maxPrice
    self.gmsQuality=quality
    self.gmsCategoryKey,self.gmsCategorySpecialized,self.gmsCategoryHeader,self.gmsCategoryParentKey,self.gmsCategoryFamily=categoryKey,categorySpecialized,categoryHeader,categoryParentKey,categoryFamily
    self.combinedPage=1
    self:ShowCombinedPage()
end
function GMS:GetDisplayedCollected()
    if not self.combinedVisible then return self.collected or {} end
    local query=self.gmsNameQuery or ''
    if query=='' and self.gmsMinPrice==nil and self.gmsMaxPrice==nil and self.gmsQuality==nil and self.gmsCategorySpecialized==nil and self.gmsCategoryFamily==nil then return self.collected or {} end
    local matches={}
    for _,entry in ipairs(self.collected or {}) do
        local data=entry.data
        local name=type(data)=='table' and (data.name or data.itemName) or nil
        if type(name)~='string' and type(data)=='table' and type(data.itemLink)=='string'
            and type(GetItemLinkName)=='function' then
            local ok,value=pcall(GetItemLinkName,data.itemLink)
            if ok then name=value end
        end
        local price=type(data)=='table' and (data.purchasePrice or data.price or data.totalPrice) or nil
        local nameOk=query=='' or (type(name)=='string' and string.find(string.lower(name),query,1,true)~=nil)
        local priceOk=type(price)=='number' or (self.gmsMinPrice==nil and self.gmsMaxPrice==nil)
        if type(price)=='number' then
            if self.gmsMinPrice and price<self.gmsMinPrice then priceOk=false end
            if self.gmsMaxPrice and price>self.gmsMaxPrice then priceOk=false end
        end
        local qualityOk=true
        if self.gmsQuality~=nil then
            local itemQuality=type(data)=='table' and GMSQualityNumber(data.displayQuality or data.quality or data.itemQuality) or nil
            if itemQuality==nil and type(data)=='table' and type(GetItemLinkDisplayQuality)=='function' then
                local link=data.itemLink or data.gmsItemLink
                if type(link)=='string' then
                    local ok,value=pcall(GetItemLinkDisplayQuality,link)
                    if ok then itemQuality=GMSQualityNumber(value) end
                end
            end
            qualityOk=(itemQuality==self.gmsQuality)
        end
        if nameOk and priceOk and qualityOk and self:CachedCategoryMatches(entry) then matches[#matches+1]=entry end
    end
    return matches
end
-- v1.0.6g: sort the COMPLETE filtered cache, before pagination.
-- Diagnostic/manual control while we verify native PS5 header selection signals.
local function GMSSortNumber(data, names)
    if type(data)~='table' then return nil end
    for _,name in ipairs(names) do
        if type(data[name])=='number' then return data[name] end
    end
    return nil
end
function GMS:SortDisplayedCache(matches)
    if not self.gmsSortField or #matches<2 then return matches end
    local source=matches
    matches={}
    for i=1,#source do matches[i]=source[i] end
    local field=self.gmsSortField
    local descending=self.gmsSortDescending
    local decorated={}
    for i,entry in ipairs(matches) do
        local data=entry and entry.data
        local total=GMSSortNumber(data,{'purchasePrice','totalPrice','price'})
        local stack=GMSSortNumber(data,{'stackCount','quantity','itemCount'}) or 1
        if stack<1 then stack=1 end
        local value
        if field=='total' then value=total
        elseif field=='unit' and total then value=total/stack
        elseif field=='time' then value=GMSSortNumber(data,{'timeRemaining','timeRemainingSeconds','timeLeft','timeLeftSeconds','timeRemainingInSeconds'}) end
        decorated[i]={entry=entry,value=value,original=i}
    end
    table.sort(decorated,function(a,b)
        if a.value==nil and b.value~=nil then return false end
        if b.value==nil and a.value~=nil then return true end
        if a.value~=nil and b.value~=nil and a.value~=b.value then
            return descending and a.value>b.value or (not descending and a.value<b.value)
        end
        return a.original<b.original
    end)
    for i,record in ipairs(decorated) do matches[i]=record.entry end
    return matches
end
function GMS:ProbeNativeSort()
    local panel=self:GetPanel()
    local function emit(line)
        if false and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then CHAT_ROUTER:AddSystemMessage('[GMS sort] '..line) end
    end
    if not panel then emit('No browse-results panel'); return end
    local function inspect(label,obj)
        if type(obj)~='table' then emit(label..'= '..type(obj)); return end
        local pieces={}
        for k,v in pairs(obj) do
            if type(k)=='string' and (string.find(string.lower(k),'sort',1,true) or string.find(string.lower(k),'header',1,true)) then
                if type(v)=='string' or type(v)=='number' or type(v)=='boolean' then
                    pieces[#pieces+1]=k..'='..tostring(v)
                else pieces[#pieces+1]=k..'('..type(v)..')' end
            end
        end
        table.sort(pieces)
        emit(label..': '..(#pieces>0 and table.concat(pieces,', '):sub(1,400) or 'no sort fields'))
    end
    inspect('panel',panel)
    inspect('sortHeaderGroup',panel.sortHeaderGroup)
    inspect('sortHeader',panel.sortHeader)
    inspect('search',TRADING_HOUSE_SEARCH)
    local sample=self.collected and self.collected[1]
    if sample and type(sample.data)=='table' then
        local fields={}
        for k,v in pairs(sample.data) do
            if type(k)=='string' and (string.find(string.lower(k),'price',1,true) or string.find(string.lower(k),'time',1,true) or string.find(string.lower(k),'stack',1,true) or string.find(string.lower(k),'quantity',1,true)) then
                if type(v)=='string' or type(v)=='number' then fields[#fields+1]=k..'='..tostring(v) end
            end
        end
        table.sort(fields)
        emit('cached item fields: '..table.concat(fields,', '):sub(1,500))
    end
end
-- v1.0.6h: Read ESO's native sort state without issuing a trader search.
-- Observed PS5 keys: Time=1, Unit=2, Total=3. Direction is read
-- directly; reverse orientation can be checked in the next PS5 test.
function GMS:SyncNativeCachedSort()
    if not (self.traderOpen and self.combinedVisible and self.enabled) then return false end
    local panel=self:GetPanel()
    if not panel then return false end
    local key=panel.currentSortKey
    local order=panel.currentSortOrder
    if type(key)~='number' or type(order)~='boolean' then return false end
    local field=({[1]='time',[2]='unit',[3]='total'})[key]
    if not field then return false end
    -- ESO sorts ascending when the boolean is true for numeric columns.
    -- For Time, remaining time increases for newer listings.
    local descending=not order
    if field=='time' then descending=order end
    if self.gmsNativeSortKey==key and self.gmsNativeSortOrder==order then return false end
    self.gmsNativeSortKey,self.gmsNativeSortOrder=key,order
    self.gmsSortField,self.gmsSortDescending=field,descending
    self.combinedPage=1
    return true
end
-- The native browse panel can repaint its footer after a cached page commit.
-- Keep GMS's page label in sync, including on the first page.
local GMS_CHROME_CONTROL_NAMES = {'waitingForResultsLabel','waitingLabel','loadingLabel','statusLabel','searchStatusLabel','noResultsLabel','emptyText','emptyLabel'}
function GMS:RefreshCachedDisplayChrome()
    if not (self.traderOpen and self.combinedVisible) then return end
    self:RefreshFilteredFooter()
    local panel=self:GetPanel()
    if not panel then return end
    -- Only hide a control if its actual text is the stale waiting message.
    -- Do not alter ESO's search state, result list, or purchase controls.
    -- Reuse the same control-name list rather than allocating it every check.
    for _,name in ipairs(GMS_CHROME_CONTROL_NAMES) do
        local control=panel[name]
        if control and type(control.GetText)=='function' and type(control.SetHidden)=='function' then
            local ok,value=pcall(control.GetText,control)
            if ok and type(value)=='string' and string.find(string.lower(value),'waiting for results',1,true) then
                pcall(control.SetHidden,control,true)
            end
        end
    end
end

-- v1.0.6s: intercept the *native results preview keybind* before scene push.
-- Never send a stale cached slot index to ESO's live trading-house preview.

-- v1.0.6w: use ESO's existing trading-house preview SCENE, but invoke the
-- client item-link preview primitive instead of the stale server result index.
function GMS:InstallItemLinkPreviewBridge()
    if self.gmsItemLinkPreviewBridge then return true end
    local helper=ITEM_PREVIEW_LIST_HELPER_GAMEPAD
    if type(helper)~='table' or type(helper.PreviewList)~='function' then return false end
    local original=helper.PreviewList
    helper.PreviewList=function(obj,previewType,entries,startIndex,dontWrap)
        if GMS.gmsPendingItemLinkPreview and
           previewType==ZO_ITEM_PREVIEW_TRADING_HOUSE_SEARCH_RESULT then
            local link=GMS.gmsPendingItemLinkPreview
            GMS.gmsPendingItemLinkPreview=nil
            local ok,result=pcall(function()
                if ITEM_PREVIEW_GAMEPAD and ITEM_PREVIEW_GAMEPAD.ClearPreviewCollection then
                    ITEM_PREVIEW_GAMEPAD:ClearPreviewCollection()
                end
                PreviewItemLink(link)
                -- ESO's shared item preview manager applies its collection after
                -- invoking the low-level preview function. Our bridge previously
                -- omitted that essential commit step.
                if type(ApplyChangesToPreviewCollectionShown)=='function' then
                    ApplyChangesToPreviewCollectionShown()
                end
                return true
            end)
            if false and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
                CHAT_ROUTER:AddSystemMessage('[GMS] PreviewItemLink called: ok='..tostring(ok)..' result='..tostring(result)..' linkType='..tostring(GetItemLinkItemType(link)))
            end
            if not ok or result==false then
                if SCENE_MANAGER then SCENE_MANAGER:Hide('tradingHousePreview_Gamepad') end
            end
            return
        end
        return original(obj,previewType,entries,startIndex,dontWrap)
    end
    self.gmsItemLinkPreviewBridge=true
    return true
end
function GMS:OpenNativeItemLinkPreview(panel,data)
    if type(data)~='table' or type(data.itemLink)~='string' then return false end
    if type(PreviewItemLink)~='function' then return false end
    if not self:InstallItemLinkPreviewBridge() then return false end
    local link=data.itemLink
    -- v1.0.6x: pass the ORIGINAL furnishing-plan item link to ESO.
    -- The previous build passed the crafted result link and displayed the character.
    -- Do not rewrite the link or create a custom preview scene.
    if type(CanItemLinkBePreviewed)=='function' and not CanItemLinkBePreviewed(link) then return false end
    if not (SCENE_MANAGER and SCENE_MANAGER:GetScene('tradingHousePreview_Gamepad')) then return false end
    self.gmsPendingItemLinkPreview=link
    -- The existing ESO scene expects a non-nil selected item and a preview
    -- index, but its PreviewList call is intercepted before index resolution.
    panel.previewItemData=data
    panel.previewListEntries={data.slotIndex or 1}
    -- Push the preview onto the scene stack, so Circle returns to the
    -- trading-house results instead of backing out of the trading house.
    -- Do not fall back to Show(): Show() does not retain the return scene.
    if type(SCENE_MANAGER.Push)~='function' then
        self.gmsPendingItemLinkPreview=nil
        return false
    end
    local ok=pcall(SCENE_MANAGER.Push,SCENE_MANAGER,'tradingHousePreview_Gamepad')
    if not ok then
        self.gmsPendingItemLinkPreview=nil
        return false
    end
    return true
end

function GMS:InstallPreviewSceneGuard()
    local panel=self:GetPanel()
    if not panel or type(panel.keybindStripDescriptor)~='table' then return end
    for _,descriptor in ipairs(panel.keybindStripDescriptor) do
        if type(descriptor)=='table' and descriptor.keybind=='UI_SHORTCUT_SECONDARY'
            and type(descriptor.callback)=='function' and not descriptor.gmsPreviewGuard then
            local original=descriptor.callback
            descriptor.callback=function(...)
                if not (GMS.enabled and GMS.combinedVisible and GMS.traderOpen) then
                    return original(...)
                end
                local selected=type(panel.GetSelectedData)=='function' and panel:GetSelectedData() or nil
                local data=type(selected)=='table' and (selected.data or selected) or nil
                if not data then return end
                local ok,opened=pcall(GMS.OpenNativeItemLinkPreview,GMS,panel,data)
                if ok and opened then return end
                if false and not ok and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
                    CHAT_ROUTER:AddSystemMessage('[GMS] Preview setup error: '..tostring(opened))
                end
                -- Live listing verification is the same identity check used for X.
                if GMS:IsSelectedLiveListing(panel) and
                    type(panel.CanPreviewTradingHouseItem)=='function' and
                    panel:CanPreviewTradingHouseItem(data) then
                    -- ESO's preview callback relies on previewListEntries as well.
                    local slot=data.slotIndex
                    if type(slot)=='number' and type(panel.previewListEntries)=='table' then
                        local found=false
                        for _,index in ipairs(panel.previewListEntries) do
                            if index==slot then found=true; break end
                        end
                        if not found then table.insert(panel.previewListEntries,slot) end
                        return original(...)
                    end
                end
                -- No scene transition: preserve selection/focus and avoid crash.
                if false and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
                    CHAT_ROUTER:AddSystemMessage('[GMS] Furnishing preview requires the live trader result; staying in results.')
                end
            end
            descriptor.gmsPreviewGuard=true
            break
        end
    end
end
function GMS:ShowCombinedPage()
    if not self.combinedVisible then return end
    local panel=self:GetPanel()
    if not panel or not panel.list or type(ZO_ScrollList_GetDataList)~='function' then return end
    local ok,entries=pcall(ZO_ScrollList_GetDataList,panel.list)
    if not ok or type(entries)~='table' then return end
    self:InstallPreviewSceneGuard()
    local displayed=self:SortDisplayedCache(self:GetDisplayedCollected())
    local count=#displayed
    local pages=math.max(1,math.ceil(count/self.combinedPageSize))
    self.combinedPage=math.max(1,math.min(self.combinedPage or 1,pages))
    for i=#entries,1,-1 do entries[i]=nil end
    local first=(self.combinedPage-1)*self.combinedPageSize+1
    for i=first,math.min(count,first+self.combinedPageSize-1) do
        entries[#entries+1]=displayed[i]
    end
    if type(ZO_ScrollList_Commit)=='function' then pcall(ZO_ScrollList_Commit,panel.list) end
    if #entries>0 and type(ZO_ScrollList_TrySelectFirstData)=='function' then
        pcall(ZO_ScrollList_TrySelectFirstData,panel.list)
    end
    if type(ZO_ScrollList_ResetToTop)=='function' then pcall(ZO_ScrollList_ResetToTop,panel.list) end
    if false and GMS.debug and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage('[GMS] Filtered page '..self.combinedPage..'/'..pages..' ('..count..' listings)')
    end
    -- ESO's gamepad footer has its own page label and trigger-button states.
    -- Refresh that real footer after our cached page changes, rather than
    -- adding a second navigation bar or leaving the original server page.
    self:RefreshFilteredFooter()
    -- Update native chrome on cached-page commits, never on idle polling.
    self:RefreshCachedDisplayChrome()
    if type(zo_callLater)=='function' then
        local generation=self.filterGeneration
        zo_callLater(function()
            if GMS.traderOpen and GMS.combinedVisible and GMS.filterGeneration==generation then
                GMS:RefreshCachedDisplayChrome()
            end
        end, 150)
    end
end
function GMS:RefreshFilteredFooter()
    if not (self.traderOpen and self.combinedVisible) then return end
    local panel=self:GetPanel()
    if not panel then return end
    if type(panel.RefreshPagingControls)=='function' then
        pcall(panel.RefreshPagingControls,panel)
    end
    -- Directly synchronize ESO's existing footer as a fallback if another
    -- addon overrides RefreshPagingControls. Do not create any new controls.
    local footer=panel.footer
    if type(footer)=='table' then
        local count=#self:GetDisplayedCollected()
        local pages=math.max(1,math.ceil(count/self.combinedPageSize))
        local page=math.max(1,math.min(self.combinedPage or 1,pages))
        local focused=type(panel.IsPanelFocused)~='function' or panel:IsPanelFocused()
        if footer.previousButton then
            footer.previousButton:SetHidden(pages<=1)
            footer.previousButton:SetEnabled(focused and page>1)
        end
        if footer.nextButton then
            footer.nextButton:SetHidden(pages<=1)
            footer.nextButton:SetEnabled(focused and page<pages)
        end
        if footer.pageNumberLabel then
            footer.pageNumberLabel:SetHidden(false)
            -- Use ESO's own label font/size; only replace its page number.
            -- GMS must not permanently restyle this shared native control.
            footer.pageNumberLabel:SetText(tostring(page)..'/'..tostring(pages))
        end
    end
end
function GMS:TurnCombinedPage(direction)
    if not self.combinedVisible then return end
    local pages=math.max(1,math.ceil(#self:GetDisplayedCollected()/self.combinedPageSize))
    local target=(self.combinedPage or 1)+direction
    if target<1 or target>pages then return end
    self.combinedPage=target
    self:ShowCombinedPage()
end
function GMS:AttachResultsKeybinds()
    if not KEYBIND_STRIP or self.resultsKeybindAttached then return end
    self.resultsKeybindGroup={
        alignment=KEYBIND_STRIP_ALIGN_RIGHT,
        {name='GMS Prev',keybind='UI_SHORTCUT_LEFT_TRIGGER',
         callback=function() GMS:TurnCombinedPage(-1) end,
         visible=function() return GMS.traderOpen and GMS.combinedVisible and (GMS.combinedPage or 1)>1 end},
        {name='GMS Next',keybind='UI_SHORTCUT_RIGHT_TRIGGER',
         callback=function() GMS:TurnCombinedPage(1) end,
         visible=function() return GMS.traderOpen and GMS.combinedVisible and (GMS.combinedPage or 1)<math.ceil(#GMS:GetDisplayedCollected()/25) end},
    }
    KEYBIND_STRIP:AddKeybindButtonGroup(self.resultsKeybindGroup)
    self.resultsKeybindAttached=true
end
function GMS:DetachResultsKeybinds()
    if self.resultsKeybindAttached and KEYBIND_STRIP and self.resultsKeybindGroup then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.resultsKeybindGroup)
    end
    self.resultsKeybindAttached=false
end
-- Route ESO's existing gamepad page actions to GMS while its filtered
-- result session is active. Do not add competing L2/R2 keybind groups.
-- Keep native search functions untouched outside the filtered session.
function GMS:InstallFilteredNavigation()
    local search=TRADING_HOUSE_SEARCH
    if not search or self.navigationHookSearch==search then return end
    local originalNext=search.SearchNextPage
    local originalPrev=search.SearchPreviousPage
    if type(originalNext)~='function' or type(originalPrev)~='function' then
        Say('GMS pagination: native search navigation methods unavailable')
        return
    end
    search.SearchNextPage=function(instance,...)
        if GMS.traderOpen and GMS.combinedVisible then
            GMS:TurnCombinedPage(1)
            return
        end
        return originalNext(instance,...)
    end
    search.SearchPreviousPage=function(instance,...)
        if GMS.traderOpen and GMS.combinedVisible then
            GMS:TurnCombinedPage(-1)
            return
        end
        return originalPrev(instance,...)
    end
    self.navigationHookSearch=search
    -- Native UI may use these methods to decide whether trigger buttons show.
    if type(search.HasPreviousPage)=='function' then
        local oldHasPrevious=search.HasPreviousPage
        search.HasPreviousPage=function(instance,...)
            if GMS.traderOpen and GMS.combinedVisible then
                return (GMS.combinedPage or 1)>1
            end
            return oldHasPrevious(instance,...)
        end
    end
    if type(search.HasNextPage)=='function' then
        local oldHasNext=search.HasNextPage
        search.HasNextPage=function(instance,...)
            if GMS.traderOpen and GMS.combinedVisible then
                return (GMS.combinedPage or 1)<math.ceil(#GMS:GetDisplayedCollected()/25)
            end
            return oldHasNext(instance,...)
        end
    end
    if type(search.GetPage)=='function' then
        local oldGetPage=search.GetPage
        search.GetPage=function(instance,...)
            if GMS.traderOpen and GMS.combinedVisible then
                return (GMS.combinedPage or 1)-1
            end
            return oldGetPage(instance,...)
        end
    end
end
function GMS:ShowCombined()
    if not self.enabled or not self.traderOpen or not self.collecting then return end
    -- The final server page must be captured before switching to preview mode.
    local panel=self:GetPanel()
    if panel and type(self.FilterVisibleEntries)=='function' then
        pcall(self.FilterVisibleEntries,self,panel)
    end
    self.collecting=false
    self.combinedVisible=true
    self.gmsNameQuery=GMSNormalizeCachedNameQuery(self:ReadCachedNameQuery() or '')
    self.gmsMinPrice,self.gmsMaxPrice=self:ReadCachedPriceBounds()
    self.gmsQuality=self:ReadCachedQuality()
    self.gmsCategoryKey,self.gmsCategorySpecialized,self.gmsCategoryHeader,self.gmsCategoryParentKey,self.gmsCategoryFamily=self:ReadCachedCategory()
    self.combinedPage=1
    self.gmsNativeSortKey,self.gmsNativeSortOrder=nil,nil
    self:SyncNativeCachedSort()
    self:UpdateEmptyPageNavigation(false)
    self:InstallFilteredNavigation()
    self:DetachResultsKeybinds()
    self:ShowCombinedPage()
    if false and GMS.debug and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage('[GMS] Listing identity check: '..tostring(self.verifiedPurchaseIds or 0)..' verified; '..tostring(self.unverifiedPurchaseIds or 0)..' ambiguous/unverified.')
    end
    if false and GMS.debug and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage('[GMS] '..tostring(#self.collected)..' uncollected listings on filtered pages of 25. X uses unique-ID purchase selection when verified.')
    end
end
function GMS:ContinueCollection()
    if not self.collecting or not self.enabled or not self.traderOpen then return end
    local search=TRADING_HOUSE_SEARCH
    if not search or type(search.GetPage)~='function' or type(search.HasNextPage)~='function' then return end
    local page=search:GetPage()
    if type(page)~='number' or page==self.lastAutoPage then return end
    self.lastAutoPage=page
    self.autoPages=(self.autoPages or 0)+1
    if self.scanDiagnostic then
        local diag=self.scanDiagnostic
        diag.pages=diag.pages+1
        if diag.pages==1 or diag.pages%10==0 then
            DiagnosticPrint('PAGE '..tostring(page)..' visited='..diag.pages..' matches='..tostring(#self.collected)..' elapsed='..math.floor((DiagnosticTime()-diag.start)/1000)..'s')
        end
    end
    if not search:HasNextPage() then self:ShowCombined(); return end
    if type(search.SearchNextPage)=='function' then
        local generation=self.filterGeneration
        local function request()
            if not GMS.collecting or not GMS.traderOpen or GMS.filterGeneration~=generation then return end
            local remaining=0
            if type(GetTradingHouseCooldownRemaining)=='function' then
                local ok,value=pcall(GetTradingHouseCooldownRemaining)
                if ok and type(value)=='number' then remaining=value end
            end
            if remaining>0 then
                if type(zo_callLater)=='function' then
                    zo_callLater(request,math.max(500,math.min(3000,remaining+250)))
                end
                return
            end
            if GMS.scanDiagnostic then GMS.scanDiagnostic.requests=GMS.scanDiagnostic.requests+1 end
            search:SearchNextPage()
        end
        request()
    end
end
function GMS:InstallPagingCallback()
    if self.pagingCallbackInstalled then return end
    local search=TRADING_HOUSE_SEARCH
    if not search or type(search.RegisterCallback)~='function' then return end
    search:RegisterCallback('OnSearchStateChanged',function(state,outcome)
        if GMS.scanDiagnostic and GMS.enabled and GMS.traderOpen then
            local diag=GMS.scanDiagnostic
            diag.transitions=diag.transitions+1
            if state==TRADING_HOUSE_SEARCH_STATE_COMPLETE then diag.complete=diag.complete+1 else diag.waiting=diag.waiting+1 end
        end
        if not GMS.enabled or not GMS.traderOpen then return end
        if state~=TRADING_HOUSE_SEARCH_STATE_COMPLETE then return end
        if GMS.replayingPage then
            local page=search:GetPage()
            if type(page)=='number' and type(GMS.targetPage)=='number' and page~=GMS.targetPage then
                local fn=page>GMS.targetPage and search.SearchPreviousPage or search.SearchNextPage
                if type(fn)=='function' and type(zo_callLater)=='function' then
                    zo_callLater(function() if GMS.replayingPage and GMS.traderOpen then fn(search) end end,150)
                end
            else GMS.replayingPage=false; GMS.targetPage=nil end
            return
        end
        if not GMS.collecting then return end
        local generation=GMS.filterGeneration
        if type(zo_callLater)=='function' then zo_callLater(function()
            if GMS.filterGeneration~=generation then return end
            if outcome==TRADING_HOUSE_SEARCH_OUTCOME_HAS_RESULTS then GMS:ContinueCollection()
            else GMS:ShowCombined() end
        end,150) end
    end)
    self.pagingCallbackInstalled=true
end
-- Never trust cached purchase slots. Only the currently loaded live server
-- page can confirm a listing; compare its live link before forwarding X.
function GMS:IsSelectedLiveListing(panel)
    local search=TRADING_HOUSE_SEARCH
    if not panel or not panel.list or not search or type(search.GetPage)~='function' then return false end
    if type(ZO_ScrollList_GetSelectedData)~='function' then return false end
    local ok,selected=pcall(ZO_ScrollList_GetSelectedData,panel.list)
    if not ok or type(selected)~='table' then return false end
    if selected.gmsSourcePage~=search:GetPage() then return false end
    local slot=selected.slotIndex
    if type(slot)~='number' and type(selected.dataEntry)=='table' then
        slot=selected.dataEntry.data and selected.dataEntry.data.slotIndex
    end
    if type(slot)~='number' or type(GetTradingHouseSearchResultItemLink)~='function' then return false end
    local okLink,live=pcall(GetTradingHouseSearchResultItemLink,slot,LINK_STYLE_DEFAULT)
    return okLink and type(selected.gmsItemLink)=='string' and live==selected.gmsItemLink
end
-- v1.0.2: use the EXISTING ESO browse-results X descriptor. Do not
-- register a competing keybind and never submit a purchase from X itself.
local function GMSPurchaseNotice(message)
    if false and CHAT_ROUTER then CHAT_ROUTER:AddSystemMessage('[GMS X] '..tostring(message):sub(1,150)) end
end
function GMS:SelectCachedPurchase(panel)
    if not self.enabled or not self.combinedVisible or not panel then return true end
    -- Native panel:GetSelectedData() is exactly what its X descriptor uses.
    self.gmsPendingPurchase=nil
    local selected = type(panel.GetSelectedData)=='function' and panel:GetSelectedData() or nil
    if type(selected)~='table' then
        GMSPurchaseNotice('No highlighted listing; purchase blocked.')
        return true
    end
    local data=selected.data or selected
    local id,price=data.gmsPurchaseId,data.gmsPurchasePrice
    if id==nil or type(price)~='number' or price<=0 or price~=data.purchasePrice then
        GMSPurchaseNotice('Unverified listing ID or price; purchase blocked.')
        return true
    end
    if type(data.gmsItemLink)~='string' or data.gmsItemLink=='' or data.gmsItemLink~=data.itemLink then
        GMSPurchaseNotice('Item identity mismatch; purchase blocked.')
        return true
    end
    if data.sellerName==GetDisplayName() then
        GMSPurchaseNotice('Cannot buy your own listing.')
        return true
    end
    if type(GetCurrencyAmount)=='function' and price>GetCurrencyAmount(CURT_MONEY,CURRENCY_LOCATION_CHARACTER) then
        GMSPurchaseNotice('Insufficient gold.')
        return true
    end
    if type(SetPendingItemPurchaseByItemUniqueId)~='function' or
       type(ZO_GamepadTradingHouse_Dialogs_DisplayConfirmationDialog)~='function' then
        GMSPurchaseNotice('Native purchase API unavailable; blocked.')
        return true
    end
    local ok,err=pcall(function()
        -- Native ESO confirmation's confirm callback handles the final purchase.
        -- Set the pending listing by its ORIGINAL unique ID, never by cached slotIndex.
        SetPendingItemPurchaseByItemUniqueId(id,price)
        ZO_GamepadTradingHouse_Dialogs_DisplayConfirmationDialog(data,
            'TRADING_HOUSE_CONFIRM_BUY_ITEM',price,data.icon)
        self.gmsPendingPurchase={id=id,price=price,link=data.gmsItemLink,
            seller=data.gmsSeller,at=DiagnosticTime()}
    end)
    if not ok then
        GMSPurchaseNotice('Confirmation failed: '..tostring(err):gsub('[\r\n].*',''):sub(1,110))
    end
    return true
end
-- v1.0.3: remove a cached listing ONLY after a successful server response.
function GMS:OnPurchaseResponse(responseType, result)
    if not (self.traderOpen and self.enabled and self.combinedVisible) then return end
    if type(TRADING_HOUSE_RESULT_PURCHASE_PENDING)~='number' or
       type(TRADING_HOUSE_RESULT_SUCCESS)~='number' or
       responseType~=TRADING_HOUSE_RESULT_PURCHASE_PENDING then return end
    local pending=self.gmsPendingPurchase
    if result~=TRADING_HOUSE_RESULT_SUCCESS then
        self.gmsPendingPurchase=nil
        return
    end
    if not pending then return end
    self.gmsPendingPurchase=nil
    if DiagnosticTime()-pending.at>120000 then return end
    local found=nil
    for i,entry in ipairs(self.collected or {}) do
        local data=entry and entry.data
        if data and data.gmsPurchaseId==pending.id and
           data.gmsPurchasePrice==pending.price and
           data.gmsItemLink==pending.link and
           data.gmsSeller==pending.seller then
            if found then return end
            found=i
        end
    end
    if not found then return end
    table.remove(self.collected,found)
    self:ShowCombinedPage()
    GMSPurchaseNotice('Purchased listing removed; '..tostring(#self.collected)..' remaining.')
end

function GMS:InstallNativePurchaseKeybind()
    local panel=self:GetPanel()
    if not panel or type(panel.keybindStripDescriptor)~='table' then return false end
    local descriptor=panel.keybindStripDescriptor[1]
    if type(descriptor)~='table' or descriptor.keybind~='UI_SHORTCUT_PRIMARY' then return false end
    if descriptor.gmsNativeXInstalled then return true end
    local original=descriptor.callback
    if type(original)~='function' then return false end
    descriptor.callback=function(...)
        if GMS.enabled and GMS.combinedVisible then
            local ok,err=pcall(GMS.SelectCachedPurchase,GMS,panel)
            if not ok then GMSPurchaseNotice('Handler error: '..tostring(err):gsub('[\r\n].*',''):sub(1,110)) end
            return
        end
        return original(...)
    end
    descriptor.gmsNativeXInstalled=true
    self.nativeXPanel=panel
    return true
end
-- Keep the combined shopping session intact when X is pressed.
-- A cached cross-page entry is not a live trading-house slot; ESO's native
-- confirmation must never receive an unverified slot from another page.
function GMS:InstallPurchaseGuard()
    local panel=self:GetPanel()
    if not panel or self.purchaseGuardPanel==panel or type(panel.ShowPurchaseItemConfirmation)~='function' then return end
    local original=panel.ShowPurchaseItemConfirmation
    panel.ShowPurchaseItemConfirmation=function(instance,...)
        if GMS.enabled and GMS.combinedVisible then
            return GMS:SelectCachedPurchase(instance)
        end
        return original(instance,...)
    end
    self.purchaseGuardPanel=panel
end
-- The previous guard was too late: ESO could navigate from the result
-- activation handler before reaching ShowPurchaseItemConfirmation.
-- Wrap the live panel's earlier selection methods only when they exist.
-- Never submit a cached slot as a purchase and never request source pages here.
function GMS:InstallSelectionGuard()
    local panel=self:GetPanel()
    if not panel then return end
    if self.selectionGuardPanel==panel then return end
    local installed=0
    local names={'OnItemSelected','OnSelectedItem','OnItemActivated','OnItemClicked','OnResultSelected'}
    for i=1,#names do
        local name=names[i]
        local original=panel[name]
        if type(original)=='function' then
            panel[name]=function(instance,...)
                if GMS.enabled and GMS.combinedVisible then
                    return GMS:SelectCachedPurchase(instance)
                end
                return original(instance,...)
            end
            installed=installed+1
        end
    end
    self.selectionGuardPanel=panel
    if self.debug then Say('Selection guards installed: '..tostring(installed)) end
end
function GMS:SyncFilteredKeybinds()
    if not self.traderOpen or not KEYBIND_STRIP then return end
    local panel = self:GetPanel()
    -- Refresh native panel descriptors first; ESO changes these when switching
    -- from the search form to a results page. This prevents stale prompts from
    -- being laid out together with GMS fallback triggers.
    if panel and type(panel.RefreshKeybinds)=='function' then
        pcall(panel.RefreshKeybinds, panel)
    elseif panel and type(panel.UpdateKeybinds)=='function' then
        pcall(panel.UpdateKeybinds, panel)
    end
    self:UpdateEmptyPageNavigation(self.emptyFilteredPage)
    self:InstallNativePurchaseKeybind()
    if self.keybindAttached and self.keybindGroup then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindGroup)
    end
end
function GMS:Toggle()
    if not self.traderOpen then return end
    self.pendingKeybindSync = true
    self.enabled = not self.enabled
    self:DetachResultsKeybinds()
    self.filterGeneration = (self.filterGeneration or 0) + 1
    self.autoPages, self.lastAutoPage = 0, nil
    self.nativeFlagHits = 0
    self.verifiedPurchaseIds, self.unverifiedPurchaseIds = 0, 0
    self.collecting, self.combinedVisible, self.replayingPage = false, false, false
    self.collected, self.collectedPages = {}, {}
    self.gmsNameQuery=nil
    self.gmsQuality=nil
    self.gmsCategoryKey,self.gmsCategorySpecialized,self.gmsCategoryHeader,self.gmsCategoryParentKey,self.gmsCategoryFamily=nil,nil,nil,nil,nil
    self.gmsNameSourceNotice=false
    self:InstallPagingCallback()
    self:InstallPurchaseGuard()
    self:InstallSelectionGuard()
    self:InstallNativePurchaseKeybind()
    local installed = self:InstallFilterHook()
    -- Capture the first native result page and request subsequent pages only
    -- after the visible list has been rebuilt by ESO's own result handler.
    if self.enabled then self.collecting=true end
    local refreshed = installed and self:RefreshResults()
    if not self.enabled then
        -- The cached GMS page was committed to ESO's native scroll list.
        -- Turning the flag OFF alone does not update the visible footer.
        -- Rebuild the native list and footer synchronously so the player
        -- does not have to press L2 to force ESO to repaint its results.
        self:RestoreNativeBrowseOnOpen()
        local panel=self:GetPanel()
        if panel and panel.list then
            if type(ZO_ScrollList_TrySelectFirstData)=='function' then
                pcall(ZO_ScrollList_TrySelectFirstData,panel.list)
            end
            if type(ZO_ScrollList_ResetToTop)=='function' then
                pcall(ZO_ScrollList_ResetToTop,panel.list)
            end
        end
    end
    if self.enabled then
        if not refreshed then
            self.collecting=false
            Say('Unable to initialize the native results list; collection cancelled.')
        else
            local generation=self.filterGeneration
            if type(zo_callLater)=='function' then
                zo_callLater(function()
                    if GMS.filterGeneration==generation and GMS.collecting then
                        GMS:ContinueCollection()
                    end
                end,600)
            end
        end
    end
    Say('Not Collected ' .. (self.enabled and 'ON' or 'OFF') ..
        ' - filter=' .. tostring(installed) .. ', refreshed=' .. tostring(refreshed) ..
        ', hidden=' .. tostring(self.hiddenCount or 0) ..
        ', unknown=' .. tostring(self.unknownCount or 0) ..
        ', scroll=' .. tostring(self.scrollCount or 0) ..
        ', links=' .. tostring(self.linkCount or 0) ..
        ', status=' .. tostring(self.visibleFilterStatus or 'none') ..
        ', navigation=' .. tostring(self.navigationStatus or 'none'))

    if self.enabled then
        Say('Native status flag matches=' .. tostring(self.nativeFlagHits or 0))
    end
    -- Let ESO finish its own keybind changes before displaying the fallback.
    local generation = self.filterGeneration
    local function sync()
        if GMS.filterGeneration ~= generation or not GMS.traderOpen then return end
        GMS.pendingKeybindSync = false
        GMS:SyncFilteredKeybinds()
    end
    if type(zo_callLater)=='function' then zo_callLater(sync, 100) else sync() end
end
function GMS:EnsureKeybind()
    if not self.traderOpen or not KEYBIND_STRIP then return end
    if not self.keybindGroup then
        self.keybindGroup = {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            { name = function() return GMS.enabled and 'GMS: Return to Store' or 'GMS: Scan Store' end,
              keybind = 'UI_SHORTCUT_LEFT_STICK',
              callback = function() GMS:Toggle() end,
              visible = function() return GMS.traderOpen end },
        }
    end
    -- Do not remove/re-add every 750ms: it changes keybind group ordering and
    -- can create overlapping prompts while the native scene is transitioning.
    if not self.keybindAttached then
        KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindGroup)
        self.keybindAttached = true
    end
end

-- v0.9.33: Compare real result identities, not just page counters.
-- No automatic scanning, purchasing, or manipulation of the visible list.
local function ProbeMessage(message)
    local line = '[GMS 0.9.33 PROBE] ' .. tostring(message)
    if false and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(line)
    elseif false and type(d)=='function' then d(line) end
end
local function ProbeSnapshot()
    local count, page = GetTradingHouseSearchResultsInfo()
    local sample, valid = {}, 0
    count = type(count)=='number' and count or 0
    if type(GetTradingHouseSearchResultItemLink)=='function' then
        for i=1, math.min(count, 100) do
            local ok, link = pcall(GetTradingHouseSearchResultItemLink, i, LINK_STYLE_DEFAULT)
            if ok and type(link)=='string' and link~='' then
                valid=valid+1
                -- A bounded sample; compare identities without printing full item links.
                if i<=5 or i==count then sample[#sample+1]=tostring(i)..':'..link end
            end
        end
    end
    return {count=count,page=page,valid=valid, sample=table.concat(sample,' | ')}
end
local function ProbeSummary(before, after)
    return 'page='..tostring(after.page)..' count='..tostring(after.count)..
        ' validLinks='..tostring(after.valid)..
        ' sampledLinksChanged='..tostring(before.sample~=after.sample)
end
function GMS:ProbeBackgroundRequest()
    if not self.traderOpen then ProbeMessage('Open a guild trader first.'); return end
    if self.enabled then ProbeMessage('Turn L3 OFF before probing.'); return end
    if self.probeActive then ProbeMessage('Probe already running.'); return end
    local search = TRADING_HOUSE_SEARCH
    if not search or type(search.GetPage)~='function' or type(search.HasNextPage)~='function' then
        ProbeMessage('Search manager unavailable.'); return
    end
    local current = search:GetPage()
    if type(current)~='number' or not search:HasNextPage() then
        ProbeMessage('No next page. Start Show All Listings and retry.'); return
    end
    if type(ExecuteTradingHouseSearch)~='function' or type(GetTradingHouseSearchResultsInfo)~='function' then
        ProbeMessage('Direct search API unavailable.'); return
    end
    if type(GetTradingHouseCooldownRemaining)=='function' then
        local ok, remaining = pcall(GetTradingHouseCooldownRemaining)
        if ok and type(remaining)=='number' and remaining>0 then
            ProbeMessage('Search cooldown '..tostring(remaining)..'; retry later.'); return
        end
    end
    local before=ProbeSnapshot()
    local panel=self:GetPanel()
    local visible=panel and panel.searchResultItemDataList
    local beforeVisible=type(visible)=='table' and #visible or -1
    self.probeActive=true
    ProbeMessage('BEFORE manager='..tostring(current)..' '..ProbeSummary(before,before)..' visible='..tostring(beforeVisible))
    local eventName=self.name..'_probe_once'
    local done=false
    local function finish(reason)
        if done then return end
        done=true
        if type(EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED)=='number' then
            EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED)
        end
        self.probeActive=false
        local after=ProbeSnapshot()
        local pnl=self:GetPanel()
        local shown=pnl and pnl.searchResultItemDataList
        local afterVisible=type(shown)=='table' and #shown or -1
        ProbeMessage(reason..' AFTER manager='..tostring(search:GetPage())..' '..ProbeSummary(before,after)..' visible='..tostring(afterVisible))
        ProbeMessage('Original sample='..tostring(before.sample~='' and 'available' or 'unavailable')..'; after sample='..tostring(after.sample~='' and 'available' or 'unavailable'))
        if before.sample==after.sample then
            ProbeMessage('No sampled listing change detected. Page counter alone does NOT prove retrieval.')
        else
            ProbeMessage('Listing sample changed. Check whether the visible results also changed.')
        end
        ProbeMessage('No automatic restore; close/reopen search if native page state is inconsistent.')
    end
    if type(EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED)=='number' then
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED, function(_, ...)
            ProbeMessage('Search results event received.')
            if type(zo_callLater)=='function' then zo_callLater(function() finish('EVENT') end,300) else finish('EVENT') end
        end)
    else
        ProbeMessage('Search-results event constant unavailable; relying on delayed sample.')
    end
    local sortField=TRADING_HOUSE_SORT_SALE_PRICE or TRADING_HOUSE_SORT_TIME or 0
    local ok, result=pcall(ExecuteTradingHouseSearch, current+1, sortField, true, true)
    if not ok then ProbeMessage('REQUEST ERROR '..tostring(result)); finish('ERROR'); return end
    ProbeMessage('Requested page '..tostring(current+1)..' directly; return='..tostring(result))
    if type(zo_callLater)=='function' then
        zo_callLater(function()
            if not done then
                local mid=ProbeSnapshot()
                ProbeMessage('CHECK 2s '..ProbeSummary(before,mid))
            end
        end,2000)
        zo_callLater(function() finish('CHECK 8s') end,8000)
    else
        finish('NO DELAY API')
    end
end

-- v0.9.34: bounded read-only cache test. /gmscollect requests up to 3 additional
-- server pages using the proven direct API path; never writes the native list.
-- The API owns one active search result buffer, so each page is copied before
-- requesting the next one. This test deliberately does not enable purchases.
local function CollectMessage(message)
    local line='[GMS 0.9.37 COLLECT] '..tostring(message)
    if false and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(line)
    elseif false and type(d)=='function' then d(line) end
end
local function CollectPage(page)
    local count=select(1,GetTradingHouseSearchResultsInfo())
    count=type(count)=='number' and count or 0
    local all, matches, unknown, known, nonCollectible=0,0,0,0,0
    local entries, byType={},{}
    local identitySamples, listingIdentities={},{}
    -- Do not confuse ordinary trade goods with unrecognized collectibles.
    -- Only recipe/motif links have verified ownership checks in this build.
    -- Every other type remains visible in normal L3 filtering; this is diagnostic only.
    local function hasSupportedCheck(kind)
        return kind==ITEMTYPE_RECIPE or kind==ITEMTYPE_RACIAL_STYLE_MOTIF
    end
    local samples={}
    for i=1,math.min(count,200) do
        local ok,link=pcall(GetTradingHouseSearchResultItemLink,i,LINK_STYLE_DEFAULT)
        if ok and type(link)=='string' and link~='' then
            all=all+1
            -- The item link is not a unique sale ID: multiple sellers can list
            -- identical items. Record a position-specific fingerprint and a
            -- cross-page sample, without incorrectly deduplicating by item link.
            if i<=5 or i==count then
                identitySamples[#identitySamples+1]=tostring(i)..':'..link
            end
            listingIdentities[#listingIdentities+1]=link
            local typeOK,kind=pcall(GetItemLinkItemType,link)
            local key=typeOK and tostring(kind) or 'invalid-type'
            local bucket=byType[key]
            if not bucket then
                bucket={total=0,missing=0,known=0,unknown=0}
                byType[key]=bucket
            end
            bucket.total=bucket.total+1
            local status=GMS:Missing(link)
            if status==true then
                matches=matches+1
                bucket.missing=bucket.missing+1
                entries[#entries+1]={page=page,slot=i,link=link}
            elseif status==false then
                known=known+1
                bucket.known=bucket.known+1
            else
                if typeOK and not hasSupportedCheck(kind) then
                    nonCollectible=nonCollectible+1
                    bucket.nonCollectible=(bucket.nonCollectible or 0)+1
                else
                    unknown=unknown+1
                    bucket.unknown=bucket.unknown+1
                    if #samples<3 then samples[#samples+1]='slot='..tostring(i)..' type='..key end
                end
            end
        end
    end
    return {entries=entries,all=all,matches=matches,known=known,unknown=unknown,nonCollectible=nonCollectible,count=count,byType=byType,samples=samples,identitySample=table.concat(identitySamples," | "),listingIdentities=listingIdentities}
end
local function CollectTypeReport(record)
    local ranked={}
    for kind,bucket in pairs(record.byType) do
        ranked[#ranked+1]={kind=kind,bucket=bucket}
    end
    table.sort(ranked,function(a,b) return a.bucket.total>b.bucket.total end)
    local parts={}
    for i=1,math.min(5,#ranked) do
        local e=ranked[i]
        parts[#parts+1]=e.kind..':'..e.bucket.total..'(M'..e.bucket.missing..'/K'..e.bucket.known..'/U'..e.bucket.unknown..'/O'..(e.bucket.nonCollectible or 0)..')'
    end
    return table.concat(parts,' ')
end

function GMS:CollectBackgroundTest()
    if not self.traderOpen then CollectMessage('Open a guild trader first.'); return end
    if self.enabled then CollectMessage('Turn L3 OFF for this diagnostic.'); return end
    if self.probeActive or self.collectProbeActive then CollectMessage('Another test is running.'); return end
    local search=TRADING_HOUSE_SEARCH
    if not search or type(search.GetPage)~='function' or type(search.HasNextPage)~='function' then
        CollectMessage('Guild store search manager unavailable.'); return
    end
    if type(ExecuteTradingHouseSearch)~='function' or type(GetTradingHouseSearchResultsInfo)~='function' or type(GetTradingHouseSearchResultItemLink)~='function' then
        CollectMessage('Required API unavailable.'); return
    end
    local initialPage=search:GetPage()
    if type(initialPage)~='number' then CollectMessage('No results page loaded.'); return end
    local generation=self.filterGeneration or 0
    self.collectProbeActive=true
    self.backgroundTestCache={}
    local cache=self.backgroundTestCache
    local total=0
    local current=initialPage
    local pages=0
    local start=DiagnosticTime()
    local cooldownWaits=0
    local waitStart=nil
    local repeatedPageSamples=0
    local overlapLinks=0
    local previousRecord=nil
    local function active()
        return GMS.collectProbeActive and GMS.traderOpen and not GMS.enabled and (GMS.filterGeneration or 0)==generation
    end
    local function stop(reason)
        if not GMS.collectProbeActive then return end
        GMS.collectProbeActive=false
        CollectMessage('END '..reason..' cachedPages='..tostring(pages)..' confirmedMatches='..tostring(total)..' currentESOPage='..tostring(search:GetPage())..' cooldownWaits='..tostring(cooldownWaits)..' repeatedPageSamples='..tostring(repeatedPageSamples)..' overlappingItemLinks='..tostring(overlapLinks)..' elapsed='..tostring(math.floor((DiagnosticTime()-start)/1000))..'s')
        CollectMessage('Read-only cache; visible list not modified. Search state advanced; reopen search to reset if needed.')
    end
    local function save(page)
        if cache[page] then return end
        local record=CollectPage(page)
        cache[page]=record
        if previousRecord then
            if previousRecord.identitySample==record.identitySample then
                repeatedPageSamples=repeatedPageSamples+1
                CollectMessage('WARNING page='..tostring(page)..' listing sample identical to preceding page; verify page retrieval')
            end
            -- Repeated item links are informational, NOT proof of duplicate
            -- listings; identical items can legitimately appear on many pages.
            local seen={}
            for _,link in ipairs(previousRecord.listingIdentities) do seen[link]=true end
            local overlaps=0
            for _,link in ipairs(record.listingIdentities) do
                if seen[link] then overlaps=overlaps+1 end
            end
            overlapLinks=overlapLinks+overlaps
            CollectMessage('IDENTITY page='..tostring(page)..' priorPage='..tostring(page-1)..' samePageSample='..tostring(previousRecord.identitySample==record.identitySample)..' repeatedItemLinks='..tostring(overlaps)..' (links are not unique listing IDs)')
        end
        previousRecord=record
        pages=pages+1
        total=total+record.matches
        CollectMessage('CACHED page='..tostring(page)..' links='..tostring(record.all)..' matches='..tostring(record.matches)..' known='..tostring(record.known)..' unknown='..tostring(record.unknown)..' otherTypes='..tostring(record.nonCollectible)..' cumulative='..tostring(total))
        CollectMessage('TYPES page='..tostring(page)..' '..CollectTypeReport(record))
        if #record.samples>0 then CollectMessage('UNKNOWN SAMPLES page='..tostring(page)..' '..table.concat(record.samples,', ')) end
    end
    save(current)
    local requestNext
    requestNext=function()
        if not active() then stop('CANCELLED'); return end
        if pages>=4 then stop('LIMIT REACHED'); return end
        if not search:HasNextPage() then stop('LAST PAGE'); return end
        local cooldown=0
        if type(GetTradingHouseCooldownRemaining)=='function' then
            local ok,remaining=pcall(GetTradingHouseCooldownRemaining)
            if ok and type(remaining)=='number' then cooldown=remaining end
        end
        if cooldown>0 then
            -- ESO reports its trading-house cooldown in milliseconds. Do not
            -- issue a request while the cooldown is active. Limit the total
            -- wait to 90 seconds for this diagnostic experiment.
            if not waitStart then waitStart=DiagnosticTime() end
            if DiagnosticTime()-waitStart>90000 then stop('COOLDOWN WAIT LIMIT'); return end
            cooldownWaits=cooldownWaits+1
            if cooldownWaits<=3 or cooldownWaits%10==0 then
                CollectMessage('WAIT cooldown='..tostring(cooldown)..'ms; no request sent')
            end
            if type(zo_callLater)=='function' then
                zo_callLater(requestNext,math.max(500,math.min(3000,math.floor(cooldown)+250)))
            else stop('NO DELAY API') end
            return
        end
        waitStart=nil
        local before=ProbeSnapshot()
        local target=current+1
        local sortField=TRADING_HOUSE_SORT_SALE_PRICE or TRADING_HOUSE_SORT_TIME or 0
        local ok,err=pcall(ExecuteTradingHouseSearch,target,sortField,true,true)
        if not ok then stop('REQUEST ERROR '..tostring(err)); return end
        CollectMessage('REQUEST page='..tostring(target)..' (waiting for changed listing identities)')
        local attempts=0
        local function poll()
            if not active() then stop('CANCELLED'); return end
            attempts=attempts+1
            local after=ProbeSnapshot()
            if after.page==target and after.sample~='' and before.sample~=after.sample then
                current=target
                save(target)
                if type(zo_callLater)=='function' then zo_callLater(requestNext,1800) else stop('NO DELAY API') end
            elseif attempts>=12 then
                stop('TIMEOUT page='..tostring(target)..' (no confirmed new listing sample)')
            elseif type(zo_callLater)=='function' then zo_callLater(poll,500)
            else stop('NO DELAY API') end
        end
        if type(zo_callLater)=='function' then zo_callLater(poll,500) else stop('NO DELAY API') end
    end
    CollectMessage('NOTE: Native side-menu refresh may still occur; no ESO UI handlers are suppressed for safety.')
    CollectMessage('START initialESOPage='..tostring(initialPage)..' up to 3 background page requests; L3 OFF')
    if type(zo_callLater)=='function' then zo_callLater(requestNext,400) else stop('NO DELAY API') end
end

-- Session lifecycle: discard temporary combined scroll entries before ESO
-- closes its trading-house UI. Never leave cached results in a native list.
-- v1.0.4: End filtered mode without committing an empty list into ESO's
-- persistent browse-results panel. ESO owns rebuilding its native results.
-- Release the native gamepad item tooltip when the trader closes.
function GMS:ClearClosedTraderTooltip()
    if GAMEPAD_TOOLTIPS and type(GAMEPAD_TOOLTIPS.ClearTooltip)=='function'
       and GAMEPAD_RIGHT_TOOLTIP then
        pcall(GAMEPAD_TOOLTIPS.ClearTooltip, GAMEPAD_TOOLTIPS, GAMEPAD_RIGHT_TOOLTIP)
    end
end

function GMS:EndTradingSession()
    self.filterGeneration = (self.filterGeneration or 0) + 1
    self.traderOpen, self.enabled, self.collecting = false, false, false
    self.combinedVisible, self.replayingPage = false, false
    self:ClearClosedTraderTooltip()
    local closingPanel=self:GetPanel()
    -- Do not leave native footer controls hidden across trader sessions.
    -- ESO owns their state after GMS exits filtered mode.
    if closingPanel and type(closingPanel.RefreshPagingControls)=='function' then
        pcall(closingPanel.RefreshPagingControls,closingPanel)
    end
    self.pendingKeybindSync = false
    self.gmsPendingPurchase = nil
    self.targetPage = nil
    self.combinedPage = nil
    self:UpdateEmptyPageNavigation(false) -- remove obsolete fallback L2/R2 group
    self:DetachResultsKeybinds()
    if self.keybindAttached and KEYBIND_STRIP and self.keybindGroup then
        pcall(KEYBIND_STRIP.RemoveKeybindButtonGroup, KEYBIND_STRIP, self.keybindGroup)
    end
    self.keybindAttached = false
    -- Never clear/commit the native scroll list while the trading scene closes.
    -- A deferred native rebuild on reopening replaces any cached GMS entries.
    self.collected, self.collectedPages, self.originalScrollEntries = {}, {}, nil
    self.gmsNameQuery=nil
    self.gmsQuality=nil
    self.gmsCategoryKey,self.gmsCategorySpecialized,self.gmsCategoryHeader,self.gmsCategoryParentKey,self.gmsCategoryFamily=nil,nil,nil,nil,nil
    self.emptyFilteredPage = false
    self.gmsRestoreNativeOnOpen = true
end

function GMS:RestoreNativeBrowseOnOpen()
    if not self.traderOpen or self.enabled or self.combinedVisible then return end
    local panel=self:GetPanel()
    if not panel then return end
    -- FilterScrollList's GMS wrapper passes straight through to the original
    -- ESO method whenever GMS is disabled. Never call ShowCombinedPage here.
    if type(panel.FilterScrollList)=='function' then
        pcall(panel.FilterScrollList,panel)
    end
    if type(panel.RefreshPagingControls)=='function' then
        pcall(panel.RefreshPagingControls,panel)
    end
end

-- v1.0.5b read-only diagnostic: discover which ESO gamepad search
-- object actually retains the submitted name. No protected UI mutations.
function GMS:ProbeNameSources()
    -- Read-only inspection of ESO's active browse filters. Avoid invoking
    -- unknown functions or mutating search state while a trader is open.
    local browse=GAMEPAD_TRADING_HOUSE_BROWSE or
        (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
    local roots={
        {'browse',browse}, {'search',TRADING_HOUSE_SEARCH},
        {'panel',self:GetPanel()}, {'gamepad',TRADING_HOUSE_GAMEPAD},
        {'filters',GAMEPAD_TRADING_HOUSE_BROWSE_FILTERS},
    }
    local count=0
    local visited={}
    local function emit(message)
        if count>=24 then return end
        count=count+1
        local line='[GMS NAME PROBE] '..tostring(message)
        if false and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
            CHAT_ROUTER:AddSystemMessage(line)
        elseif false and type(d)=='function' then d(line) end
    end
    emit('v1.0.5d name='..tostring(self:ReadCachedNameQuery()))
    local nodes=0
    local function inspect(path,obj,depth)
        if type(obj)~='table' or visited[obj] or nodes>=260 or depth>4 then return end
        visited[obj]=true
        nodes=nodes+1
        local ok,iterator,state,initial=pcall(pairs,obj)
        if not ok then return end
        local children={}
        local seen=0
        for key,value in iterator,state,initial do
            seen=seen+1
            if seen>140 or nodes>=260 then break end
            local label=tostring(key)
            local lower=string.lower(label)
            local relevant=lower:find('name',1,true) or lower:find('text',1,true)
                or lower:find('search',1,true) or lower:find('filter',1,true)
                or lower:find('term',1,true) or lower:find('input',1,true)
                or lower:find('query',1,true) or lower:find('edit',1,true)
            if type(value)=='string' and value~='' and
                (relevant or string.lower(value):find('recipe',1,true)) then
                emit(path..'.'..label..' = '..value:sub(1,45))
            elseif type(value)=='table' and depth<4 then
                -- Descend into ESO filter/search models, including nested
                -- numeric entries; don't recursively traverse unrelated UI.
                if relevant or depth==0 or type(key)=='number' then
                    children[#children+1]={path..'.'..label,value}
                end
            end
        end
        for _,child in ipairs(children) do
            if count>=23 or nodes>=260 then break end
            inspect(child[1],child[2],depth+1)
        end
    end
    for _,root in ipairs(roots) do inspect(root[1],root[2],0) end
    emit('end; inspected '..nodes..' objects')
end


-- v1.0.6l: read-only state comparison. NEVER activates an item or changes scenes.
function GMS:ProbeRecentSearchState()
    local function emit(msg)
        if false and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
            CHAT_ROUTER:AddSystemMessage('[GMS RECENT] '..tostring(msg))
        elseif type(d)=='function' then d('[GMS RECENT] '..tostring(msg)) end
    end
    local panel=self:GetPanel()
    local browse=GAMEPAD_TRADING_HOUSE_BROWSE or (TRADING_HOUSE_GAMEPAD and TRADING_HOUSE_GAMEPAD.browse)
    local feature=browse and browse.features and browse.features.nameSearchFeature
    emit('combined='..tostring(self.combinedVisible)..' collecting='..tostring(self.collecting)..' trader='..tostring(self.traderOpen)..' page='..tostring(self.combinedPage))
    emit('query='..tostring(self.gmsNameQuery)..' raw='..tostring(self:ReadCachedNameQuery()))
    emit('nameFeature searchText='..tostring(feature and feature.searchText)..' selectedItem='..type(feature and feature.selectedItem)..' selectedData='..type(feature and feature.selectedData))
    if not panel then emit('panel=nil'); return end
    emit('panel='..tostring(panel)..' list='..type(panel.list)..' focused='..tostring(type(panel.IsPanelFocused)=='function' and panel:IsPanelFocused() or '?'))
    local list=panel.list
    if list and type(ZO_ScrollList_GetDataList)=='function' then
        local ok,entries=pcall(ZO_ScrollList_GetDataList,list)
        if ok and type(entries)=='table' then
            local first=entries[1]
            local data=first and first.data
            emit('listCount='..tostring(#entries)..' first='..type(first)..' data='..type(data)..' id='..tostring(data and (data.id or data.uniqueId or data.itemUniqueId))..' name='..tostring(data and data.name))
        else emit('list entries unavailable') end
    end
    local search=TRADING_HOUSE_SEARCH
    emit('native searchText='..tostring(search and search.searchText)..' sortKey='..tostring(panel.currentSortKey))
end

-- Legacy crash snapshot calls are intentionally inert in release builds.
function GMS:CrashSnapshot() end

-- Manual memory diagnostics: no background timers, snapshots, or forced GC.
local gmsMemPreviousMB = nil
local function GMSMemoryReading()
    local mb = nil
    if type(GetTotalMemoryUsageInMB) == 'function' then
        local ok, result = pcall(GetTotalMemoryUsageInMB)
        if ok and type(result) == 'number' then mb = result end
    end
    if mb == nil and type(collectgarbage) == 'function' then
        local ok, kb = pcall(collectgarbage, 'count')
        if ok and type(kb) == 'number' then mb = kb / 1024 end
    end
    if mb == nil then
        if type(d) == 'function' then d('GMS memory: unavailable') end
        return
    end
    local delta = gmsMemPreviousMB and string.format(' | since last %+.2f MB', mb - gmsMemPreviousMB) or ' | first reading'
    local message = string.format('GMS memory: %.2f MB%s', mb, delta)
    gmsMemPreviousMB = mb
    if CHAT_ROUTER and type(CHAT_ROUTER.AddSystemMessage) == 'function' then
        CHAT_ROUTER:AddSystemMessage(message)
    elseif type(d) == 'function' then
        d(message)
    end
end

-- v1.1.0: Read-only fragment API diagnostic. Does not alter scanning or filtering.
local function FragmentDiagnosticMessage(message)
    local line = '[GMS Fragment] ' .. tostring(message)
    if CHAT_ROUTER and type(CHAT_ROUTER.AddSystemMessage)=='function' then
        CHAT_ROUTER:AddSystemMessage(line)
    elseif type(d)=='function' then
        d(line)
    end
end
local function FragmentProbeCall(name, link)
    local fn = _G and _G[name]
    if type(fn)~='function' then return 'unavailable' end
    local ok, result = pcall(fn, link)
    if not ok then return 'error' end
    if result==nil then return 'nil' end
    return tostring(result)
end
local function FragmentDiagnostic(arg)
    local requested = tonumber((arg or ''):match('^%s*(%d+)%s*$'))
    if type(GetTradingHouseSearchResultsInfo)~='function'
        or type(GetTradingHouseSearchResultItemLink)~='function' then
        FragmentDiagnosticMessage('Trading House APIs unavailable.')
        return
    end
    local okCount, count = pcall(GetTradingHouseSearchResultsInfo)
    if not okCount or type(count)~='number' then
        FragmentDiagnosticMessage('Open a Guild Trader search-results page first.')
        return
    end
    local found, shown = 0, 0
    for slot=1,math.min(count,200) do
        local ok, link = pcall(GetTradingHouseSearchResultItemLink,slot,LINK_STYLE_DEFAULT)
        if ok and type(link)=='string' and link~='' then
            local okId, itemId = pcall(GetItemLinkItemId,link)
            if okId and type(itemId)=='number' and (requested==nil or itemId==requested) then
                found=found+1
                -- Without an ID, report a small bounded sample, not the whole store.
                if shown<3 then
                    shown=shown+1
                    local okName, itemName=pcall(GetItemLinkName,link)
                    FragmentDiagnosticMessage('slot='..slot..' id='..itemId..' '..(okName and tostring(itemName) or '?'))
                    FragmentDiagnosticMessage('container='..FragmentProbeCall('GetItemLinkContainerCollectibleId',link)
                        ..' collectibleLink='..FragmentProbeCall('GetCollectibleIdFromLink',link)
                        ..' book='..FragmentProbeCall('IsItemLinkBook',link))
                    FragmentDiagnosticMessage('nativeMissing='..tostring(GMS:Missing(link))
                        ..' type='..FragmentProbeCall('GetItemLinkItemType',link))
                end
            end
        end
    end
    if found==0 then
        FragmentDiagnosticMessage('No matching listing on the CURRENT results page. Search for the fragment, then run /gmsfrag <itemID>.')
    else
        FragmentDiagnosticMessage('Matches on current page: '..found..'. Diagnostic only; no filter changes.')
    end
end


-- Diagnostic only: search native achievement records for the tooltip's reward name.
-- Runs only when explicitly requested; small batches avoid freezing the gamepad UI.
local gmsAchievementProbeRunning = false
local function GMSAchievementProbe()
    if gmsAchievementProbeRunning then
        FragmentDiagnosticMessage('Achievement lookup already running.')
        return
    end
    if type(GetAchievementInfo) ~= 'function' or type(GetAchievementCriterion) ~= 'function' then
        FragmentDiagnosticMessage('Achievement API unavailable.')
        return
    end
    gmsAchievementProbeRunning = true
    local id, hits, limit = 1, 0, 15000
    FragmentDiagnosticMessage('Searching achievement names for Echo of the Abolisher (diagnostic only).')
    local function batch()
        local stop = math.min(id + 99, limit)
        while id <= stop do
            local ok, name = pcall(GetAchievementInfo, id)
            if ok and type(name) == 'string' and name:lower():find('echo of the abolisher', 1, true) then
                hits = hits + 1
                FragmentDiagnosticMessage('achievement=' .. id .. ' name=' .. name)
                if type(GetAchievementNumCriteria) == 'function' then
                    local okNum, num = pcall(GetAchievementNumCriteria, id)
                    if okNum and type(num) == 'number' then
                        for criterion = 1, math.min(num, 12) do
                            local okCrit, description, count, required = pcall(GetAchievementCriterion, id, criterion)
                            if okCrit then
                                FragmentDiagnosticMessage('criterion=' .. criterion .. ' ' .. tostring(description)
                                    .. ' progress=' .. tostring(count) .. '/' .. tostring(required))
                            end
                        end
                    end
                end
            end
            id = id + 1
        end
        if id <= limit and type(zo_callLater) == 'function' then
            zo_callLater(batch, 25)
        else
            gmsAchievementProbeRunning = false
            FragmentDiagnosticMessage('Achievement lookup finished; matches=' .. hits .. '. No filter changes.')
        end
    end
    batch()
end


-- Diagnostic only. Read ESO's native collectible combination data for the kitten.
-- No scanner/filter changes. Unknown data is reported, never interpreted as missing.
local gmsKittenProbeRunning = false
local function GMSKittenProbe()
    if gmsKittenProbeRunning then FragmentDiagnosticMessage('Kitten lookup already running.'); return end
    if type(GetCollectibleInfo) ~= 'function' then FragmentDiagnosticMessage('GetCollectibleInfo unavailable.'); return end
    gmsKittenProbeRunning = true
    local nextId, hits, limit = 1, 0, 30000
    FragmentDiagnosticMessage('Searching native Collections for Big-Eared Ginger Kitten (diagnostic only).')
    local function safe(fn, ...)
        if type(fn) ~= 'function' then return nil end
        local ok, a, b, c = pcall(fn, ...)
        if ok then return a, b, c end
        return nil
    end
    local function inspect(id, name)
        hits = hits + 1
        local unlocked = safe(IsCollectibleUnlocked, id)
        local ref = safe(GetCollectibleReferenceId, id)
        FragmentDiagnosticMessage('collectible=' .. id .. ' ' .. tostring(name) .. ' unlocked=' .. tostring(unlocked) .. ' reference=' .. tostring(ref))
        local combination = (type(ref) == 'number' and ref > 0) and ref or nil
        if combination then
            local count = safe(GetCombinationNumCollectibleComponents, combination)
            FragmentDiagnosticMessage('combination=' .. combination .. ' components=' .. tostring(count))
            if type(count) == 'number' then
                for i=1, math.min(count, 24) do
                    local component = safe(GetCombinationCollectibleComponentId, combination, i)
                    local cname = component and safe(GetCollectibleInfo, component) or nil
                    local owned = component and safe(IsCollectibleUnlocked, component) or nil
                    FragmentDiagnosticMessage('part=' .. i .. ' collectible=' .. tostring(component) .. ' owned=' .. tostring(owned) .. ' ' .. tostring(cname))
                end
            end
        end
    end
    local function batch()
        local stop = math.min(nextId + 149, limit)
        while nextId <= stop do
            local name = safe(GetCollectibleInfo, nextId)
            if type(name) == 'string' and name:lower():find('big%-eared ginger kitten') then
                inspect(nextId, name)
            end
            nextId = nextId + 1
        end
        if nextId <= limit and type(zo_callLater) == 'function' then
            zo_callLater(batch, 20)
        else
            gmsKittenProbeRunning = false
            FragmentDiagnosticMessage('Kitten lookup finished; matches=' .. hits .. '. No filter changes.')
        end
    end
    batch()
end


-- v1.1.4 diagnostic only: kitten's seven parts are tracked as achievement criteria.
-- Do not modify the working fragment filter or interpret unknown values as missing.
local gmsKittenAchievementRunning = false
local function GMSKittenAchievementProbe()
    if gmsKittenAchievementRunning then FragmentDiagnosticMessage('Kitten achievement lookup already running.'); return end
    if type(GetAchievementInfo) ~= 'function' or type(GetAchievementCriterion) ~= 'function' then
        FragmentDiagnosticMessage('Achievement API unavailable.'); return
    end
    gmsKittenAchievementRunning = true
    local id, hits, limit = 1, 0, 15000
    FragmentDiagnosticMessage('Searching kitten achievement criteria (diagnostic only).')
    local function batch()
        local stop = math.min(id + 99, limit)
        while id <= stop do
            local ok, name = pcall(GetAchievementInfo, id)
            if ok and type(name) == 'string' and name:lower():find('big-eared ginger kitten', 1, true) then
                hits = hits + 1
                FragmentDiagnosticMessage('achievement=' .. id .. ' name=' .. name)
                local okNum, num = false, nil
                if type(GetAchievementNumCriteria) == 'function' then
                    okNum, num = pcall(GetAchievementNumCriteria, id)
                end
                if okNum and type(num) == 'number' then
                    FragmentDiagnosticMessage('criteria=' .. tostring(num))
                    for criterion = 1, math.min(num, 16) do
                        local okCrit, description, count, required = pcall(GetAchievementCriterion, id, criterion)
                        if okCrit then
                            FragmentDiagnosticMessage('part=' .. criterion .. ' ' .. tostring(description)
                                .. ' progress=' .. tostring(count) .. '/' .. tostring(required))
                        end
                    end
                else
                    FragmentDiagnosticMessage('Criteria count unavailable.')
                end
            end
            id = id + 1
        end
        if id <= limit and type(zo_callLater) == 'function' then
            zo_callLater(batch, 25)
        else
            gmsKittenAchievementRunning = false
            FragmentDiagnosticMessage('Kitten achievement lookup finished; matches=' .. hits .. '. No filter changes.')
        end
    end
    batch()
end

-- Read-only targeted discovery for tradeable collectible components.
-- This is a candidate finder, NOT proof that a component is tradeable.
-- The narrow phrases below avoid broad words like 'vault' and 'remnant'.
local gmsCollectionDiscoveryRunning = false
local function GMSCollectionDiscovery()
    if gmsCollectionDiscoveryRunning then
        FragmentDiagnosticMessage('Collection discovery is already running.'); return
    end
    if type(GetAchievementInfo)~='function' or type(GetAchievementCriterion)~='function'
        or type(GetAchievementNumCriteria)~='function' then
        FragmentDiagnosticMessage('Achievement criteria API unavailable.'); return
    end
    local targets = {
        'big-eared ginger kitten', 'remnants of deception', 'remnants of cruelty',
        'coral haj mota', 'graht-oak', 'valenwood seedling',
        'inscribed shard', 'scaly cloth', 'thrafey', 'bonedust pigment',
        'skeletal marionette', 'marionette parts', 'rune-carved bone',
        'throwing bones', 'horned owl', 'writhing haj mota', 'wormwrithe',
        'harvested soul fragment', 'sealed fabrication material',
        'chameleon tincture', 'spectral distillation',
        'nowhere vault fragment', 'nowhere vault collectible',
        'kitten', 'haj mota decoy', 'haj mota lure',
    }
    local function relevant(value)
        if type(value)~='string' then return false end
        value=value:lower()
        for _,phrase in ipairs(targets) do
            if value:find(phrase,1,true) then return true end
        end
        return false
    end
    local id, total, shown, cap, limit = 1, 0, 0, 24, 15000
    gmsCollectionDiscoveryRunning = true
    FragmentDiagnosticMessage('Targeted collection discovery started. Up to 24 matches; no store changes.')
    local function batch()
        local stop=math.min(id+99,limit)
        while id<=stop do
            local ok,name=pcall(GetAchievementInfo,id)
            if ok and type(name)=='string' and name~='' then
                local nameMatch=relevant(name)
                local okCount,count=pcall(GetAchievementNumCriteria,id)
                if okCount and type(count)=='number' and count>0 then
                    local matches={}
                    for criterion=1,math.min(count,40) do
                        local good,desc,current,required=pcall(GetAchievementCriterion,id,criterion)
                        if good and type(desc)=='string' and relevant(desc) then
                            matches[#matches+1]={criterion,desc,current,required}
                        end
                    end
                    -- Only include achievements with targeted component criteria,
                    -- or exact target names with a plausible small criteria set.
                    if #matches>0 or (nameMatch and count<=12) then
                        total=total+1
                        if shown<cap then
                            shown=shown+1
                            FragmentDiagnosticMessage('COL '..id..' '..name..' ['..count..']')
                            local printed=0
                            for _,v in ipairs(matches) do
                                if printed>=8 then break end
                                FragmentDiagnosticMessage('  '..v[1]..' '..v[2]..' '..tostring(v[3])..'/'..tostring(v[4]))
                                printed=printed+1
                            end
                            -- For named achievements with no criterion name match,
                            -- print up to 7 criteria to identify the component system.
                            if #matches==0 then
                                for criterion=1,math.min(count,7) do
                                    local good,desc,current,required=pcall(GetAchievementCriterion,id,criterion)
                                    if good then FragmentDiagnosticMessage('  '..criterion..' '..tostring(desc)..' '..tostring(current)..'/'..tostring(required)) end
                                end
                            end
                        end
                    end
                end
            end
            id=id+1
        end
        if id<=limit and type(zo_callLater)=='function' then
            zo_callLater(batch,25)
        else
            gmsCollectionDiscoveryRunning=false
            FragmentDiagnosticMessage('Collection discovery finished. '..total..' candidate achievements; '..shown..' shown (max '..cap..'). Tradeability not verified.')
        end
    end
    batch()
end


-- v1.2.2: Read-only, narrowly targeted collectible reward ownership diagnostic.
-- Uses safe API calls and prints only matches for five outstanding collections.
local gmsRewardProbeRunning = false
local function GMSRewardOwnershipProbe()
    if gmsRewardProbeRunning then
        FragmentDiagnosticMessage('Reward lookup already running.'); return
    end
    if type(GetCollectibleInfo) ~= 'function' then
        FragmentDiagnosticMessage('GetCollectibleInfo unavailable. No changes.'); return
    end
    local targets = {
        {label='Swamp Jelly', terms={'swamp jelly'}},
        {label='Apple-Bobbing Cauldron', terms={'apple-bobbing','apple bobbing','bobbing cauldron'}},
        {label='Bonedust Pigment', terms={'witch-tamed bear-dog','witch tamed bear dog','bonedust pigment'}},
        {label='Rune-Carved Bone Fragment', terms={'throwing bones','rune-carved bone'}},
        {label='Sealed Fabrication Materials', terms={'fabrication','fabricant','sealed fabrication'}},
    }
    local apis={'GetCollectibleInfo','IsCollectibleUnlocked','GetCollectibleIdFromLink',
                'GetCollectibleFragmentInfo','GetNumCollectibleFragments',
                'GetCollectibleFragmentId','GetAchievementInfo','GetAchievementCriterion'}
    local function safe(fn, ...)
        if type(fn)~='function' then return nil end
        local ok,a,b,c,d=pcall(fn,...)
        if ok then return a,b,c,d end
        return nil
    end
    local function relevant(name, terms)
        if type(name)~='string' then return false end
        name=name:lower()
        for _,term in ipairs(terms) do
            if name:find(term,1,true) then return true end
        end
        return false
    end
    local id,limit,step=1,20000,150
    local found={0,0,0,0,0}
    gmsRewardProbeRunning=true
    FragmentDiagnosticMessage('Reward ownership lookup: 5 targets, read-only. Scanning collectible names...')
    local available={}
    for _,name in ipairs(apis) do
        if type(_G[name])=='function' then available[#available+1]=name end
    end
    FragmentDiagnosticMessage('Available APIs: '..table.concat(available, ', '))
    local function batch()
        local last=math.min(id+step-1,limit)
        while id<=last do
            local name=safe(GetCollectibleInfo,id)
            if type(name)=='string' and name~='' then
                for k,target in ipairs(targets) do
                    if relevant(name,target.terms) then
                        found[k]=found[k]+1
                        if found[k]<=5 then
                            local unlocked=safe(IsCollectibleUnlocked,id)
                            FragmentDiagnosticMessage(target.label..': collectible '..id..' '..name..' unlocked='..tostring(unlocked))
                        end
                    end
                end
            end
            id=id+1
        end
        if id<=limit and type(zo_callLater)=='function' then
            zo_callLater(batch,25)
        else
            gmsRewardProbeRunning=false
            for k,target in ipairs(targets) do
                FragmentDiagnosticMessage(target.label..': '..found[k]..' name match(es)'..(found[k]==0 and ' (try reward name/alternative API)' or ''))
            end
            FragmentDiagnosticMessage('Finished. No fragment filter, purchase, or scanner changes.')
        end
    end
    batch()
end

-- v1.2.4: Compact read-only diagnostic for Apple-Bobbing component IDs
-- and sealed fabrication reward ambiguity. Prints all matching names,
-- including owned state, without modifying Guild Trader behavior.
local gmsPartsProbeRunning=false
local function GMSRemainingPartsProbe()
    if gmsPartsProbeRunning then FragmentDiagnosticMessage('Parts lookup already running.'); return end
    if type(GetCollectibleInfo)~='function' then FragmentDiagnosticMessage('Collectible API unavailable.'); return end
    gmsPartsProbeRunning=true
    FragmentDiagnosticMessage('Looking up Apple-Bobbing pieces and Fabricant rewards (read-only)...')
    local id,limit,step=1,20000,180
    local apple,fabricant=0,0
    local function batch()
        local stop=math.min(limit,id+step-1)
        while id<=stop do
            local ok,name=pcall(GetCollectibleInfo,id)
            if ok and type(name)=='string' then
                local low=name:lower()
                local isApple=low:find('apple-bobbing',1,true)~=nil
                local isFab=low:find('fabricant',1,true)~=nil or low:find('fabrication',1,true)~=nil
                if isApple or isFab then
                    local owned='unknown'
                    if type(IsCollectibleUnlocked)=='function' then
                        local good,value=pcall(IsCollectibleUnlocked,id)
                        if good then owned=tostring(value) end
                    end
                    if isApple then
                        apple=apple+1
                        if apple<=20 then FragmentDiagnosticMessage('APPLE '..id..' '..name..' owned='..owned) end
                    end
                    if isFab then
                        fabricant=fabricant+1
                        if fabricant<=18 then FragmentDiagnosticMessage('FAB '..id..' '..name..' owned='..owned) end
                    end
                end
            end
            id=id+1
        end
        if id<=limit and type(zo_callLater)=='function' then
            zo_callLater(batch,25)
        else
            gmsPartsProbeRunning=false
            FragmentDiagnosticMessage('Done: '..apple..' Apple names, '..fabricant..' Fabricant names. Item-to-reward association still requires verification.')
        end
    end
    batch()
end


-- v1.2.5: Read-only discovery of candidate rewards for tradeable fragments.
-- Name matches are clues only, not proof of an item-to-reward association.
local gmsNextRewardsRunning=false
local function GMSNextFragmentRewards()
    if gmsNextRewardsRunning then FragmentDiagnosticMessage('Fragment reward lookup already running.'); return end
    local names={
        {'Revelry',{'revelry','reveler'}},
        {'Mirth',{'playful prankster','mirth'}},
        {'Noise Maker',{'festive noise maker','noise maker'}},
        {'Joke Popper',{'joke popper'}},
        {'Minstrel',{'daedroth suit','minstrel'}},
        {'Guar Stomp',{'guar stomp'}},
        {'Mosaic',{'mosaic','skill style'}},
        {'Tainted Blood',{'eviscerate','tainted blood'}},
        {'Fabrication',{'fabricant','fabrication'}},
        {'Portent',{'portent favor','tonic of portent'}},
    }
    local apis={'GetCollectibleInfo','IsCollectibleUnlocked','GetRecipeInfo','GetRecipeListInfo',
        'GetNumRecipeLists','GetNumRecipesInRecipeList','GetItemLinkItemId',
        'GetItemLinkRecipeResultItemLink','GetItemLinkName','IsItemLinkRecipeKnown',
        'GetItemLinkItemType','GetAchievementInfo','GetAchievementCriterion'}
    local available={}
    for _,name in ipairs(apis) do
        if type(_G[name])=='function' then available[#available+1]=name end
    end
    FragmentDiagnosticMessage('v1.2.5 reward discovery: read-only, no filters changed.')
    FragmentDiagnosticMessage('Available APIs: '..table.concat(available,', '))
    if type(GetCollectibleInfo)~='function' then FragmentDiagnosticMessage('Collectible lookup unavailable.'); return end
    local found={}
    for i=1,#names do found[i]=0 end
    local id,limit,step=1,20000,180
    gmsNextRewardsRunning=true
    local function batch()
        local stop=math.min(limit,id+step-1)
        while id<=stop do
            local ok,name=pcall(GetCollectibleInfo,id)
            if ok and type(name)=='string' and name~='' then
                local low=name:lower()
                for i,entry in ipairs(names) do
                    local match=false
                    for _,term in ipairs(entry[2]) do
                        if low:find(term,1,true) then match=true; break end
                    end
                    if match then
                        found[i]=found[i]+1
                        if found[i]<=7 then
                            local owned='unknown'
                            if type(IsCollectibleUnlocked)=='function' then
                                local good,value=pcall(IsCollectibleUnlocked,id)
                                if good then owned=tostring(value) end
                            end
                            FragmentDiagnosticMessage(entry[1]..' '..id..' '..name..' owned='..owned)
                        end
                    end
                end
            end
            id=id+1
        end
        if id<=limit and type(zo_callLater)=='function' then
            zo_callLater(batch,25)
        else
            gmsNextRewardsRunning=false
            for i,entry in ipairs(names) do
                FragmentDiagnosticMessage(entry[1]..': '..found[i]..' collectible name matches')
            end
            FragmentDiagnosticMessage('Done. Name matches require reward verification; no scan/filter changes.')
        end
    end
    batch()
end


-- v1.2.6: read-only selected Guild Trader listing probe.
-- Never changes scanning, result selection, or purchase state.
local function GMSSelectedListingProbe()
    local function say(msg)
        if type(d)=='function' then d('[GMS Item] '..tostring(msg))
        elseif CHAT_ROUTER and type(CHAT_ROUTER.AddSystemMessage)=='function' then CHAT_ROUTER:AddSystemMessage('[GMS Item] '..tostring(msg)) end
    end
    local panel=GMS:GetPanel()
    if not panel or not panel.list or type(ZO_ScrollList_GetSelectedData)~='function' then
        say('Open Guild Trader results and highlight the item first.'); return
    end
    local ok,selected=pcall(ZO_ScrollList_GetSelectedData,panel.list)
    if not ok or type(selected)~='table' then say('No highlighted result found.'); return end
    local entry=selected
    if type(selected.dataEntry)=='table' and type(selected.dataEntry.data)=='table' then entry=selected.dataEntry.data end
    local slot=selected.slotIndex or entry.slotIndex
    local link=selected.gmsItemLink or entry.gmsItemLink or selected.itemLink or entry.itemLink
    local name=selected.name or entry.name or selected.itemName or entry.itemName
    if type(slot)=='number' and type(GetTradingHouseSearchResultItemLink)=='function' then
        local success,live=pcall(GetTradingHouseSearchResultItemLink,slot,LINK_STYLE_DEFAULT)
        if success and type(live)=='string' and live~='' then
            if type(link)=='string' and link~=live then say('Note: cached and live listing links differ') end
            link=live
        end
    end
    say('Name='..tostring(name or '?'):sub(1,80)..' slot='..tostring(slot or '?'))
    if type(link)~='string' or link=='' then say('No item link exposed by selected row'); return end
    say('Link='..link)
    for _,spec in ipairs({
        {'itemId','GetItemLinkItemId'},
        {'itemType','GetItemLinkItemType'},
        {'containerCollectibleId','GetItemLinkContainerCollectibleId'},
        {'collectibleId','GetCollectibleIdFromLink'},
        {'isSetCollectionPiece','IsItemLinkSetCollectionPiece'},
        {'recipeKnown','IsItemLinkRecipeKnown'},
    }) do
        local fn=_G[spec[2]]
        if type(fn)=='function' then
            local success,value=pcall(fn,link)
            say(spec[1]..'='..(success and tostring(value) or 'API error'))
        end
    end
    if type(GetItemLinkContainerCollectibleId)=='function' and type(IsCollectibleUnlocked)=='function' then
        local success,id=pcall(GetItemLinkContainerCollectibleId,link)
        if success and type(id)=='number' and id>0 then
            local own,v=pcall(IsCollectibleUnlocked,id)
            say('containerRewardUnlocked='..(own and tostring(v) or 'API error'))
        end
    end
    say('Done. Read-only; no filter or purchase changes.')
end


-- v1.2.8: Read-only targeted collectible/achievement name discovery.
-- These are candidate name matches, not verified item-to-reward associations.
local gmsTotemProbeRunning=false
local function GMSTotemRewardProbe()
    if gmsTotemProbeRunning then FragmentDiagnosticMessage('Totem probe already running.'); return end
    if type(GetCollectibleInfo)~='function' then FragmentDiagnosticMessage('GetCollectibleInfo unavailable.'); return end
    local groups={
        {'Werewolf',{'werewolf','wolf form','wolf totem','hunter totem'}},
        {'Blood Scion',{'blood scion','coldharbour','parched stone'}},
        {'Stone Husk',{'stone husk','target dummy','training dummy'}},
        {'Chew Bone',{'chew bone','ashen','bitten'}},
    }
    local matches={}; for i=1,#groups do matches[i]=0 end
    FragmentDiagnosticMessage('v1.2.8 totem/bone/stone reward search (read-only).')
    local id,limit,step=1,24000,160
    gmsTotemProbeRunning=true
    local function batch()
        local stop=math.min(limit,id+step-1)
        while id<=stop do
            local ok,name=pcall(GetCollectibleInfo,id)
            if ok and type(name)=='string' and name~='' then
                local low=name:lower()
                for i,group in ipairs(groups) do
                    local hit=false
                    for _,term in ipairs(group[2]) do
                        if low:find(term,1,true) then hit=true; break end
                    end
                    if hit then
                        matches[i]=matches[i]+1
                        if matches[i]<=18 then
                            local owned='unknown'
                            if type(IsCollectibleUnlocked)=='function' then
                                local yes,value=pcall(IsCollectibleUnlocked,id)
                                if yes then owned=tostring(value) end
                            end
                            FragmentDiagnosticMessage(group[1]..' ID='..id..' '..name:sub(1,48)..' owned='..owned)
                        end
                    end
                end
            end
            id=id+1
        end
        if id<=limit and type(zo_callLater)=='function' then zo_callLater(batch,30)
        else
            gmsTotemProbeRunning=false
            for i,group in ipairs(groups) do FragmentDiagnosticMessage(group[1]..' matches='..matches[i]) end
            FragmentDiagnosticMessage('Done. Name matches are candidates only; no filters changed.')
        end
    end
    batch()
end

-- v1.2.9: Focused diagnostic for the two still-unmapped stone fragments.
-- No broad Coldharbour/Ashen name search; no filter modifications.
local function GMSStoneProbe()
    local say=FragmentDiagnosticMessage
    say('v1.2.9 stone reward diagnostic (read-only).')
    local candidates={8461,8462,14659,14773,14774,14775}
    for _,cid in ipairs(candidates) do
        local name='unknown'; local owned='unknown'
        if type(GetCollectibleInfo)=='function' then
            local ok,n=pcall(GetCollectibleInfo,cid)
            if ok and type(n)=='string' then name=n end
        end
        if type(IsCollectibleUnlocked)=='function' then
            local ok,v=pcall(IsCollectibleUnlocked,cid)
            if ok then owned=tostring(v) end
        end
        say('ID='..cid..' '..name:sub(1,46)..' owned='..owned)
    end
    -- Search exact phrases only to avoid unrelated Coldharbour results.
    if type(GetCollectibleInfo)~='function' then say('No collectible API.'); return end
    local terms={'stone husk','blood scion form','blood scion,','parched stone','stone husk target'}
    local id,limit,step,matches=1,30000,250,0
    local function batch()
        local stop=math.min(limit,id+step-1)
        while id<=stop do
            local ok,name=pcall(GetCollectibleInfo,id)
            if ok and type(name)=='string' and name~='' then
                local low=name:lower()
                for _,term in ipairs(terms) do
                    if low:find(term,1,true) then
                        matches=matches+1
                        if matches<=24 then
                            local owned='unknown'
                            if type(IsCollectibleUnlocked)=='function' then
                                local yes,v=pcall(IsCollectibleUnlocked,id)
                                if yes then owned=tostring(v) end
                            end
                            say('Candidate ID='..id..' '..name:sub(1,44)..' owned='..owned)
                        end
                        break
                    end
                end
            end
            id=id+1
        end
        if id<=limit and type(zo_callLater)=='function' then zo_callLater(batch,30)
        else say('Stone candidates='..matches..'. Done; no filter changes.') end
    end
    batch()
end


-- v1.2.10: Read-only recipe knowledge discovery for fragment-based recipes.
-- GetRecipeInfo's first return is the known flag; the actual completed recipe
-- must be inspected, never the ingredient fragment's recipeKnown property.
local function GMSRecipeFragmentProbe()
    local say=FragmentDiagnosticMessage
    say('v1.2.11 recipe knowledge scan (read-only).')
    if type(GetNumRecipeLists)~='function' or type(GetRecipeListInfo)~='function'
        or type(GetRecipeInfo)~='function' or type(GetRecipeResultItemLink)~='function' then
        say('Recipe list API incomplete. No filters changed.'); return
    end
    local okCount,listCount=pcall(GetNumRecipeLists)
    if not okCount or type(listCount)~='number' then
        say('Recipe list count unavailable.'); return
    end
    local terms={'psijic ambrosia','mythic aetherial ambrosia','tonic of portent favor'}
    local listIndex,recipeIndex,recipeCount=1,1,0
    local inspected,matches,failures=0,0,0
    local function scanBatch()
        local budget=200
        while listIndex<=math.min(listCount,100) and budget>0 do
            if recipeIndex==1 then
                local ok,_,count=pcall(GetRecipeListInfo,listIndex)
                if ok and type(count)=='number' then recipeCount=math.min(count,2000)
                else recipeCount=0; failures=failures+1 end
            end
            if recipeIndex>recipeCount then
                listIndex=listIndex+1; recipeIndex=1
            else
                local ri=recipeIndex
                recipeIndex=recipeIndex+1
                budget=budget-1
                inspected=inspected+1
                local okInfo,known,recipeName=pcall(GetRecipeInfo,listIndex,ri)
                local okLink,link=pcall(GetRecipeResultItemLink,listIndex,ri)
                local resultName=''
                if okLink and type(link)=='string' and link~='' and type(GetItemLinkName)=='function' then
                    local okName,name=pcall(GetItemLinkName,link)
                    if okName and type(name)=='string' then resultName=name end
                end
                local combined=((type(recipeName)=='string' and recipeName or '')..' '..resultName):lower()
                for _,term in ipairs(terms) do
                    if combined:find(term,1,true) then
                        matches=matches+1
                        if matches<=20 then
                            local display=resultName~='' and resultName or (type(recipeName)=='string' and recipeName or term)
                            say(display:sub(1,48)..' known='..tostring(known)..' list='..listIndex..' recipe='..ri)
                        end
                        break
                    end
                end
                if not okInfo or not okLink then failures=failures+1 end
            end
        end
        if listIndex<=math.min(listCount,100) and type(zo_callLater)=='function' then
            zo_callLater(scanBatch,30)
        else
            say('Done. lists='..listCount..' checked='..inspected..' matches='..matches..' errors='..failures)
            say('No recipe fragment filters changed.')
        end
    end
    scanBatch()
end

-- v1.2.12: Targeted read-only search for remaining fragment achievements.
-- Collectible-name matches are NOT assumed to be fragment rewards.
local function GMSRemainingFragmentProbe()
    local say=FragmentDiagnosticMessage
    say('v1.2.13 remaining fragment search (read-only).')
    if type(GetAchievementInfo)~='function' or type(GetAchievementCriterion)~='function' then
        say('Achievement API unavailable.'); return
    end
    local id, limit, matches=1,30000,0
    local terms={'stone husk','guar stomp','mosaic skill','mosaic shreds','arkthzand'}
    local function batch()
        local stop=math.min(limit,id+250-1)
        while id<=stop do
            local ok,name=pcall(GetAchievementInfo,id)
            if ok and type(name)=='string' and name~='' then
                local lower=name:lower()
                local hit=false
                for _,term in ipairs(terms) do
                    if lower:find(term,1,true) then hit=true; break end
                end
                if hit then
                    matches=matches+1
                    if matches<=15 then
                        say('ACH '..id..' '..name:sub(1,48))
                        for c=1,12 do
                            local good,desc,current,required=pcall(GetAchievementCriterion,id,c)
                            if good and type(desc)=='string' and desc~='' and type(required)=='number' and required>0 then
                                say('  '..c..' '..desc:sub(1,33)..' '..tostring(current)..'/'..tostring(required))
                            end
                        end
                    end
                end
            end
            id=id+1
        end
        if id<=limit and type(zo_callLater)=='function' then zo_callLater(batch,30)
        else say('Done. achievement matches='..matches..'. No filter changes.') end
    end
    batch()
end

-- v1.2.13: Read-only, targeted Mosaic achievement discovery.
-- We report candidates and criteria; no speculative ownership filter.
local function GMSMosaicProbe()
    local say=FragmentDiagnosticMessage
    if type(GetAchievementInfo)~='function' or type(GetAchievementCriterion)~='function' then
        say('Mosaic: achievement API unavailable.'); return
    end
    say('v1.2.13 Mosaic skill-style achievement search started.')
    local id,limit,matches=1,30000,0
    local function batch()
        local stop=math.min(limit,id+249)
        while id<=stop do
            local ok,name=pcall(GetAchievementInfo,id)
            if ok and type(name)=='string' and name~='' then
                local lower=name:lower()
                if lower:find('skill stylist',1,true) or lower:find('grand healing',1,true)
                    or lower:find('dawnbreaker',1,true) or lower:find('meteor',1,true)
                    or lower:find('mosaic',1,true) then
                    matches=matches+1
                    if matches<=35 then
                        say('ACH '..id..' '..name:sub(1,48))
                        for c=1,8 do
                            local good,desc,current,required=pcall(GetAchievementCriterion,id,c)
                            if good and type(desc)=='string' and desc~='' and type(required)=='number' and required>0 then
                                say('  '..c..' '..desc:sub(1,35)..' '..tostring(current)..'/'..tostring(required))
                            end
                        end
                    end
                end
            end
            id=id+1
        end
        if id<=limit and type(zo_callLater)=='function' then zo_callLater(batch,30)
        else say('Mosaic done. matches='..matches..'. No Mosaic filter changes.') end
    end
    batch()
end

function GMS:Initialize()
    -- Development-only slash diagnostics removed for the public release.
    if type(EVENT_TRADING_HOUSE_RESPONSE_RECEIVED)=='number' then
        EVENT_MANAGER:RegisterForEvent(self.name .. '_purchase_response',
            EVENT_TRADING_HOUSE_RESPONSE_RECEIVED,
            function(_, responseType, result)
                GMS:OnPurchaseResponse(responseType,result)
            end)
    end
    EVENT_MANAGER:RegisterForEvent(self.name .. '_open', EVENT_OPEN_TRADING_HOUSE, function()
        GMS.traderOpen, GMS.enabled = true, false
        GMS.filterGeneration = (GMS.filterGeneration or 0) + 1
        GMS.autoPages, GMS.lastAutoPage = 0, nil
        GMS:InstallPagingCallback()
        GMS:InstallNativePurchaseKeybind()
        GMS:EnsureKeybind()
        -- v1.0.4b diagnostic: no delayed GMS-driven native browse refresh.
        -- ESO owns its normal result refresh on opening the trader.
        GMS.gmsRestoreNativeOnOpen=false
        GMS.gmsChromeNextCheckMs=nil
        -- Native paging remains owned by ESO until GMS enables filtering.
    end)
    EVENT_MANAGER:RegisterForEvent(self.name .. '_close', EVENT_CLOSE_TRADING_HOUSE, function()
        GMS:EndTradingSession()
    end)
    EVENT_MANAGER:RegisterForUpdate(self.name .. '_keybind', 750, function()
        if GMS.traderOpen then
            GMS:EnsureKeybind()
            GMS:RefreshCachedNameFilter()
            if GMS.combinedVisible then
                if GMS:SyncNativeCachedSort() then GMS:ShowCombinedPage() end
                -- UI chrome is now refreshed on page commits only.
            end
        end
    end)
    -- Wait until the player is in-world, then allow the HUD chat to initialize.
    -- Print only once per login, not on every zone transition.
    local startupEvent = self.name .. '_startup_message'
    EVENT_MANAGER:RegisterForEvent(startupEvent, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(startupEvent, EVENT_PLAYER_ACTIVATED)
        local function announce()
            local line = '|cFFD15AGMS|r |c44D5C7- Guild Market Scanner|r |c50BFFFv'..GMS.version..'|r |c73E58Cloaded!|r'
            if CHAT_ROUTER and type(CHAT_ROUTER.AddSystemMessage)=='function' then
                CHAT_ROUTER:AddSystemMessage(line)
            elseif type(d)=='function' then
                d(line)
            end
        end
        if type(zo_callLater)=='function' then
            zo_callLater(announce, 1800)
        else
            announce()
        end
    end)
end
EVENT_MANAGER:RegisterForEvent(GMS.name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= GMS.name then return end
    EVENT_MANAGER:UnregisterForEvent(GMS.name, EVENT_ADD_ON_LOADED)
    GMS:Initialize()
end)
