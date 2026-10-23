-- Tamriel Collections - Guild Market Scanner v0.9.25 NAV LABEL LAYOUT
-- Local-only, no saved market history, exports or automatic page requests.
GuildMarketScannerDev = GuildMarketScannerDev or {}
local GMS = GuildMarketScannerDev
GMS.name, GMS.version = 'GuildMarketScannerDev', '0.9.32'
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
    local data = type(entry)=='table' and entry.data or nil
    local candidates = {
        entry,
        data,
        type(data)=='table' and data.dataEntry or nil,
        type(data)=='table' and type(data.dataEntry)=='table' and data.dataEntry.data or nil,
        type(data)=='table' and data.itemData or nil,
    }
    for i=1,#candidates do
        local candidate=candidates[i]
        if type(candidate)=='table' then
            if candidate.canBeUsedToLearn == true or candidate.isLockedSetPiece == true then
                return true, 'native-flag'
            end
        end
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
        GMS.originalScrollEntries = nil -- native rebuild supersedes any prior snapshot
        if not GMS.enabled then GMS:UpdateEmptyPageNavigation(false) end
        if GMS.traderOpen and GMS.enabled then
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
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then CHAT_ROUTER:AddSystemMessage(line) else d(line) end
end
function GMS:DiagnosticSummary()
    local diag=self.scanDiagnostic
    if not diag then DiagnosticPrint('No scan recorded yet.'); return end
    local elapsed=math.max(0,DiagnosticTime()-(diag.start or 0))
    DiagnosticPrint('SUMMARY elapsed='..math.floor(elapsed/1000)..'s pages='..tostring(diag.pages or 0)..' matches='..tostring(#(self.collected or {}))..' transitions='..tostring(diag.transitions or 0)..' waiting='..tostring(diag.waiting or 0)..' complete='..tostring(diag.complete or 0)..' nextRequests='..tostring(diag.requests or 0)..' currentESOPage='..tostring(TRADING_HOUSE_SEARCH and TRADING_HOUSE_SEARCH.GetPage and TRADING_HOUSE_SEARCH:GetPage() or '?'))
end
-- Combined result pages are independent of ESO's server page number.
GMS.resultsPageSize = 25
function GMS:ShowCombinedPage()
    if not self.combinedVisible then return end
    local panel=self:GetPanel()
    if not panel or not panel.list or type(ZO_ScrollList_GetDataList)~='function' then return end
    local ok,entries=pcall(ZO_ScrollList_GetDataList,panel.list)
    if not ok or type(entries)~='table' then return end
    local total=#self.collected
    local pages=math.max(1,math.ceil(total/self.resultsPageSize))
    self.resultsPage=math.max(1,math.min(self.resultsPage or 1,pages))
    for i=#entries,1,-1 do entries[i]=nil end
    local first=(self.resultsPage-1)*self.resultsPageSize+1
    for i=first,math.min(total,first+self.resultsPageSize-1) do
        entries[#entries+1]=self.collected[i]
    end
    if type(ZO_ScrollList_Commit)=='function' then pcall(ZO_ScrollList_Commit,panel.list) end
    if type(ZO_ScrollList_TrySelectFirstData)=='function' then pcall(ZO_ScrollList_TrySelectFirstData,panel.list) end
    DiagnosticPrint('RESULTS '..tostring(self.resultsPage)..'/'..tostring(pages)..' items='..tostring(#entries)..' total='..tostring(total))
    if KEYBIND_STRIP and self.resultsKeybindGroup then KEYBIND_STRIP:UpdateKeybindButtonGroup(self.resultsKeybindGroup) end
end
function GMS:TurnCombinedPage(direction)
    if not self.combinedVisible then return end
    local maxPage=math.max(1,math.ceil(#self.collected/self.resultsPageSize))
    local nextPage=math.max(1,math.min(maxPage,(self.resultsPage or 1)+direction))
    if nextPage~=(self.resultsPage or 1) then
        self.resultsPage=nextPage
        self:ShowCombinedPage()
    end
end
function GMS:AttachResultsKeybinds()
    if not KEYBIND_STRIP then return end
    if not self.resultsKeybindGroup then
        self.resultsKeybindGroup={
            alignment=KEYBIND_STRIP_ALIGN_RIGHT,
            {name='GMS Previous',keybind='UI_SHORTCUT_LEFT_TRIGGER',
             visible=function() return GMS.combinedVisible and GMS.resultsPage>1 end,
             callback=function() GMS:TurnCombinedPage(-1) end},
            {name='GMS Next',keybind='UI_SHORTCUT_RIGHT_TRIGGER',
             visible=function() return GMS.combinedVisible and GMS.resultsPage<math.ceil(#GMS.collected/GMS.resultsPageSize) end,
             callback=function() GMS:TurnCombinedPage(1) end},
        }
    end
    if not self.resultsKeybindAttached then
        KEYBIND_STRIP:AddKeybindButtonGroup(self.resultsKeybindGroup)
        self.resultsKeybindAttached=true
    end
end
function GMS:DetachResultsKeybinds()
    if self.resultsKeybindAttached and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.resultsKeybindGroup)
    end
    self.resultsKeybindAttached=false
end
function GMS:ShowCombined()
    if not self.enabled or not self.traderOpen or not self.collecting then return end
    self.collecting=false
    DiagnosticPrint('COLLECTION FINISHED - server page request time remains unchanged')
    self:DiagnosticSummary()
    self.combinedVisible=true
    self.resultsPage=1
    self:AttachResultsKeybinds()
    self:ShowCombinedPage()
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage('[GMS] '..tostring(#self.collected)..' unlearned motif listings. Combined pages contain up to 25 items. Selecting a listing returns to its ESO source page.')
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
        if self.scanDiagnostic then self.scanDiagnostic.requests=self.scanDiagnostic.requests+1 end
        search:SearchNextPage()
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
function GMS:InstallPurchaseGuard()
    local panel=self:GetPanel()
    if not panel or self.purchaseGuardPanel==panel or type(panel.ShowPurchaseItemConfirmation)~='function' then return end
    local original=panel.ShowPurchaseItemConfirmation
    panel.ShowPurchaseItemConfirmation=function(instance,...)
        if GMS.enabled and GMS.combinedVisible then
            local search=TRADING_HOUSE_SEARCH
            local selected=instance.list and type(ZO_ScrollList_GetSelectedData)=='function' and ZO_ScrollList_GetSelectedData(instance.list)
            local page=selected and selected.gmsSourcePage
            if type(page)=='number' and search and type(search.GetPage)=='function' then
                GMS.combinedVisible=false
                GMS:DetachResultsKeybinds()
        GMS:UpdateEmptyPageNavigation(false)
                GMS.replayingPage=true
                GMS.targetPage=page
                local current=search:GetPage()
                if type(current)=='number' and current~=page then
                    local fn=current>page and search.SearchPreviousPage or search.SearchNextPage
                    if type(fn)=='function' then fn(search) end
                end
                if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
                    CHAT_ROUTER:AddSystemMessage('[GMS] Returning to original listing page. Select and verify the item again before buying.')
                end
            end
            return -- never purchase a copied combined-list entry
        end
        return original(instance,...)
    end
    self.purchaseGuardPanel=panel
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
    self.collecting, self.combinedVisible, self.replayingPage = false, false, false
    self.collected, self.collectedPages = {}, {}
    if self.enabled then
        self.scanDiagnostic={start=DiagnosticTime(),pages=0,transitions=0,waiting=0,complete=0,requests=0}
        DiagnosticPrint('START v0.9.32 background request probe (no automatic paging)')
    else
        self:DiagnosticSummary()
    end
    self:InstallPagingCallback()
    self:InstallPurchaseGuard()
    local installed = self:InstallFilterHook()
    local refreshed = installed and self:RefreshResults()
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

-- v0.9.32: One-request API feasibility probe. Does not change GMS's working L3 flow.
-- Run only at the trader, with L3 OFF, after a normal search has results.
local function GMSProbeMessage(message)
    local line = '[GMS 0.9.32 PROBE] ' .. tostring(message)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(line)
    elseif type(d)=='function' then d(line) end
end
function GMS:ProbeBackgroundRequest()
    if not self.traderOpen then GMSProbeMessage('Open a guild trader first.'); return end
    if self.enabled then GMSProbeMessage('Turn L3 OFF before probing.'); return end
    if self.probeActive then GMSProbeMessage('Probe already running.'); return end
    local search = TRADING_HOUSE_SEARCH
    if not search or type(search.GetPage)~='function' or type(search.HasNextPage)~='function' then
        GMSProbeMessage('Search manager unavailable.'); return
    end
    local current = search:GetPage()
    if type(current)~='number' or not search:HasNextPage() then
        GMSProbeMessage('No next page. Search for Show All Listings and retry.'); return
    end
    if type(ExecuteTradingHouseSearch)~='function' or type(GetTradingHouseSearchResultsInfo)~='function' then
        GMSProbeMessage('Native direct search API unavailable.'); return
    end
    if type(GetTradingHouseCooldownRemaining)=='function' then
        local ok, remaining = pcall(GetTradingHouseCooldownRemaining)
        if ok and type(remaining)=='number' and remaining>0 then
            GMSProbeMessage('Search cooldown '..tostring(remaining)..'ms; retry after cooldown.'); return
        end
    end
    local num, apiPage = GetTradingHouseSearchResultsInfo()
    local panel = self:GetPanel()
    local visible = panel and panel.searchResultItemDataList
    local visibleCount = type(visible)=='table' and #visible or -1
    self.probeActive = true
    self.probeOrigin = current
    GMSProbeMessage('BEFORE managerPage='..tostring(current)..' apiPage='..tostring(apiPage)..' apiItems='..tostring(num)..' visibleItems='..tostring(visibleCount))
    -- Observe the native result event; do not replace, fake or buy listings.
    local eventName = self.name..'_probe_once'
    local done = false
    local function finish(reason)
        if done then return end
        done=true
        EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED)
        self.probeActive=false
        local n,p = GetTradingHouseSearchResultsInfo()
        local manager = search:GetPage()
        local pnl = self:GetPanel()
        local shown = pnl and pnl.searchResultItemDataList
        GMSProbeMessage(reason..' AFTER managerPage='..tostring(manager)..' apiPage='..tostring(p)..' apiItems='..tostring(n)..' visibleItems='..tostring(type(shown)=='table' and #shown or -1))
        GMSProbeMessage('Check whether the visible list changed, stayed put, or jumped. No auto-restore performed.')
    end
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED, function(_, guildId, count, page, hasMore)
        GMSProbeMessage('RESPONSE page='..tostring(page)..' count='..tostring(count)..' more='..tostring(hasMore))
        if type(zo_callLater)=='function' then zo_callLater(function() finish('RECEIVED') end,350) else finish('RECEIVED') end
    end)
    local sortField = TRADING_HOUSE_SORT_SALE_PRICE or TRADING_HOUSE_SORT_TIME or 0
    -- Use last executed search filters; do not alter the player's query.
    local ok, result = pcall(ExecuteTradingHouseSearch, current+1, sortField, true, true)
    if not ok then GMSProbeMessage('REQUEST ERROR '..tostring(result)); finish('ERROR'); return end
    GMSProbeMessage('Requested next page directly, returned '..tostring(result))
    if type(zo_callLater)=='function' then zo_callLater(function() finish('TIMEOUT/NO EVENT') end,8000) end
end

function GMS:Initialize()
    if SLASH_COMMANDS then SLASH_COMMANDS['/gmsprobe']=function() GMS:ProbeBackgroundRequest() end end
    if SLASH_COMMANDS then SLASH_COMMANDS['/gmsdiag']=function() GMS:DiagnosticSummary() end end
    EVENT_MANAGER:RegisterForEvent(self.name .. '_open', EVENT_OPEN_TRADING_HOUSE, function()
        GMS.traderOpen, GMS.enabled = true, false
        GMS.filterGeneration = (GMS.filterGeneration or 0) + 1
        GMS.autoPages, GMS.lastAutoPage = 0, nil
        GMS:InstallPagingCallback()
        GMS:EnsureKeybind()
    end)
    EVENT_MANAGER:RegisterForEvent(self.name .. '_close', EVENT_CLOSE_TRADING_HOUSE, function()
        GMS.traderOpen, GMS.enabled = false, false
        GMS:DetachResultsKeybinds()
        GMS.filterGeneration = (GMS.filterGeneration or 0) + 1
        if GMS.keybindAttached and KEYBIND_STRIP then KEYBIND_STRIP:RemoveKeybindButtonGroup(GMS.keybindGroup) end
        GMS.keybindAttached = false
    end)
    EVENT_MANAGER:RegisterForUpdate(self.name .. '_keybind', 750, function()
        if GMS.traderOpen then GMS:EnsureKeybind() end
    end)
    Say('v0.9.27 keybind sync test loaded.')
end
EVENT_MANAGER:RegisterForEvent(GMS.name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= GMS.name then return end
    EVENT_MANAGER:UnregisterForEvent(GMS.name, EVENT_ADD_ON_LOADED)
    GMS:Initialize()
end)
