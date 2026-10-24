-- Tamriel Collections - Guild Market Scanner v1.0.4c FILTER OFF NATIVE RESTORE TEST
-- Local-only; L3 scans additional trader pages and caches collection matches.
GuildMarketScannerDev = GuildMarketScannerDev or {}
local GMS = GuildMarketScannerDev
GMS.name, GMS.version = 'GuildMarketScannerDev', '1.0.5c'
GMS.enabled, GMS.traderOpen, GMS.keybindAttached = false, false, false
-- Diagnostics are disabled in normal gameplay. /gmsdebug toggles them for testing.
GMS.debug = false
local function Say(msg)
    if not GMS.debug then return end
    local line = '|cD9AD51[Tamriel|r |cB58AE8Collections]|r ' .. tostring(msg)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then CHAT_ROUTER:AddSystemMessage(line) else d(line) end
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
function GMS:UpdateEmptyPageNavigation(isEmpty)
    self.emptyFilteredPage = self.enabled and self.traderOpen and isEmpty == true
    if not KEYBIND_STRIP then return end
    -- During an L3 toggle ESO may still be showing the search-form keybind bar.
    -- Wait until the native panel has updated before adding our fallback group.
    if self.pendingKeybindSync then return end
    if not self.emptyPageKeybindGroup then
        self.emptyPageKeybindGroup = {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            { name = 'Prev', keybind = 'UI_SHORTCUT_LEFT_TRIGGER',
              visible = function()
                  local search = TRADING_HOUSE_SEARCH
                  return GMS.emptyFilteredPage and search and type(search.GetPage)=='function'
                      and type(search.SearchPreviousPage)=='function' and (search:GetPage() or 0)>0
              end,
              callback = function()
                  local search = TRADING_HOUSE_SEARCH
                  if search and type(search.SearchPreviousPage)=='function' then search:SearchPreviousPage() end
              end },
            { name = 'Next', keybind = 'UI_SHORTCUT_RIGHT_TRIGGER',
              visible = function()
                  local search = TRADING_HOUSE_SEARCH
                  return GMS.emptyFilteredPage and search and type(search.HasNextPage)=='function'
                      and type(search.SearchNextPage)=='function' and search:HasNextPage()
              end,
              callback = function()
                  local search = TRADING_HOUSE_SEARCH
                  if search and type(search.SearchNextPage)=='function' then search:SearchNextPage() end
              end },
        }
    end
    if self.emptyFilteredPage and not self.emptyPageKeybindAttached then
        KEYBIND_STRIP:AddKeybindButtonGroup(self.emptyPageKeybindGroup)
        self.emptyPageKeybindAttached = true
    elseif not self.emptyFilteredPage and self.emptyPageKeybindAttached then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.emptyPageKeybindGroup)
        self.emptyPageKeybindAttached = false
    end
    if self.emptyPageKeybindAttached then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.emptyPageKeybindGroup)
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
        local native, reason = NativeMissingStatus(entry)
        if native ~= true and panel and type(panel.searchResultItemDataList)=='table' then
            local nativeEntry=panel.searchResultItemDataList[i]
            local candidate=NativeMissingStatus(nativeEntry)
            if candidate==true then native=true end
        end
        if native == true then missing = true end
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
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then CHAT_ROUTER:AddSystemMessage(line) elseif type(d)=='function' then d(line) end
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
        if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then CHAT_ROUTER:AddSystemMessage(line)
        elseif type(d)=='function' then d(line) end
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
    query=string.lower((query:gsub('^%s+',''):gsub('%s+$','')))
    local minPrice,maxPrice=self:ReadCachedPriceBounds()
    if query==self.gmsNameQuery and minPrice==self.gmsMinPrice and maxPrice==self.gmsMaxPrice then
        local panel=self:GetPanel()
        local label=panel and panel.footer and panel.footer.pageNumberLabel
        if label and type(label.IsHidden)=='function' and label:IsHidden() then
            self:RefreshFilteredFooter()
        end
        return
    end
    self.gmsNameQuery=query
    self.gmsMinPrice,self.gmsMaxPrice=minPrice,maxPrice
    self.combinedPage=1
    self:ShowCombinedPage()
end
function GMS:GetDisplayedCollected()
    if not self.combinedVisible then return self.collected or {} end
    local query=self.gmsNameQuery or ''
    if query=='' and self.gmsMinPrice==nil and self.gmsMaxPrice==nil then return self.collected or {} end
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
        if nameOk and priceOk then matches[#matches+1]=entry end
    end
    return matches
end
function GMS:ShowCombinedPage()
    if not self.combinedVisible then return end
    local panel=self:GetPanel()
    if not panel or not panel.list or type(ZO_ScrollList_GetDataList)~='function' then return end
    local ok,entries=pcall(ZO_ScrollList_GetDataList,panel.list)
    if not ok or type(entries)~='table' then return end
    local displayed=self:GetDisplayedCollected()
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
    if GMS.debug and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage('[GMS] Filtered page '..self.combinedPage..'/'..pages..' ('..count..' listings)')
    end
    -- ESO's gamepad footer has its own page label and trigger-button states.
    -- Refresh that real footer after our cached page changes, rather than
    -- adding a second navigation bar or leaving the original server page.
    self:RefreshFilteredFooter()
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
            footer.pageNumberLabel:SetText('Filtered Page '..tostring(page)..' / '..tostring(pages))
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
    self.gmsNameQuery=string.lower((self:ReadCachedNameQuery() or ''):gsub('^%s+',''):gsub('%s+$',''))
    self.gmsMinPrice,self.gmsMaxPrice=self:ReadCachedPriceBounds()
    self.combinedPage=1
    self:UpdateEmptyPageNavigation(false)
    self:InstallFilteredNavigation()
    self:DetachResultsKeybinds()
    self:ShowCombinedPage()
    self:DiagnosticSummary()
    if GMS.debug and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage('[GMS] Listing identity check: '..tostring(self.verifiedPurchaseIds or 0)..' verified; '..tostring(self.unverifiedPurchaseIds or 0)..' ambiguous/unverified.')
    end
    if GMS.debug and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
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
    if self.autoPages>100 or not search:HasNextPage() then self:ShowCombined(); return end
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
    if CHAT_ROUTER then CHAT_ROUTER:AddSystemMessage('[GMS X] '..tostring(message):sub(1,150)) end
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
    self.gmsNameSourceNotice=false
    if self.enabled then
        self.scanDiagnostic={start=DiagnosticTime(),pages=0,transitions=0,waiting=0,complete=0,requests=0}
        DiagnosticPrint('START integrated L3 collection across guild trader pages')
    else
        self:DiagnosticSummary()
    end
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
            { name = function() return GMS.enabled and 'Not Collected: ON' or 'Not Collected: OFF' end,
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
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(line)
    elseif type(d)=='function' then d(line) end
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
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(line)
    elseif type(d)=='function' then d(line) end
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
    if closingPanel and closingPanel.footer then
        local footer=closingPanel.footer
        if footer.pageNumberLabel then
            pcall(footer.pageNumberLabel.SetHidden, footer.pageNumberLabel, true)
        end
        if footer.previousButton then
            pcall(footer.previousButton.SetHidden, footer.previousButton, true)
        end
        if footer.nextButton then
            pcall(footer.nextButton.SetHidden, footer.nextButton, true)
        end
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
        if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
            CHAT_ROUTER:AddSystemMessage(line)
        elseif type(d)=='function' then d(line) end
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

function GMS:Initialize()
    if SLASH_COMMANDS then SLASH_COMMANDS['/gmsdebug']=function() GMS.debug=not GMS.debug; local msg='[GMS] Debug messages '..(GMS.debug and 'ON' or 'OFF'); if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then CHAT_ROUTER:AddSystemMessage(msg) elseif type(d)=='function' then d(msg) end end end
    if SLASH_COMMANDS then SLASH_COMMANDS['/gmsnameprobe']=function() GMS:ProbeNameSources() end end
    if SLASH_COMMANDS then SLASH_COMMANDS['/gmspriceprobe']=function() GMS:ProbePriceSources() end end
    if SLASH_COMMANDS then SLASH_COMMANDS['/gmscollect']=function() GMS:CollectBackgroundTest() end end
    if SLASH_COMMANDS then SLASH_COMMANDS['/gmsprobe']=function() GMS:ProbeBackgroundRequest() end end
    if SLASH_COMMANDS then SLASH_COMMANDS['/gmsdiag']=function() GMS:DiagnosticSummary() end end
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
    end)
    EVENT_MANAGER:RegisterForEvent(self.name .. '_close', EVENT_CLOSE_TRADING_HOUSE, function()
        GMS:EndTradingSession()
    end)
    EVENT_MANAGER:RegisterForUpdate(self.name .. '_keybind', 750, function()
        if GMS.traderOpen then
            GMS:EnsureKeybind()
            GMS:RefreshCachedNameFilter()
        end
    end)
    Say('v1.0.5f cached price filtering test loaded.')
end
EVENT_MANAGER:RegisterForEvent(GMS.name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= GMS.name then return end
    EVENT_MANAGER:UnregisterForEvent(GMS.name, EVENT_ADD_ON_LOADED)
    GMS:Initialize()
end)
