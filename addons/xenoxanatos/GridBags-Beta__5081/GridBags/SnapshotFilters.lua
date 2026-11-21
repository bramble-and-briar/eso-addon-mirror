-- Capture core AF classifications while the source bags are genuinely live.
-- Offline evaluation reads booleans only: no AF callback or bag API is replayed.
GridBagsSnapshotFilters = { cache = {}, warnings = {} }
local F = GridBagsSnapshotFilters

local function LabelFor(name)
    local strings = AdvancedFilters and AdvancedFilters.strings
    return strings and strings[name] or tostring(name)
end

function F:BuildSchema()
    local af = AdvancedFilters
    if not af or not af.subfilterGroups or not af.subfilterCallbacks or not ZO_ItemFilterUtils
        or type(ZO_ItemFilterUtils.IsSlotFilterDataInItemTypeDisplayCategory) ~= "function" then return end
    local group = af.subfilterGroups[INVENTORY_BACKPACK]
    local bars = group and group[CRAFTING_TYPE_INVALID]
    if not bars then return end
    local categories, entries, keys = {}, {}, {}
    for category, bar in pairs(bars) do
        if type(category) == "number" and bar.subfilterButtons then keys[#keys + 1] = category end
    end
    table.sort(keys)
    for _, category in ipairs(keys) do
        local bar = bars[category]
        local groupName = af.filterTypeNames and af.filterTypeNames[category]
        local categoryId = "c:" .. category
        local cat = { id = categoryId, label = LabelFor(groupName or category), subfilters = {} }
        entries[#entries + 1] = { id = categoryId, category = category, label = cat.label }
        for _, button in ipairs(bar.subfilterButtons) do
            local name = button.name
            local coreGroup = af.subfilterCallbacks[button.groupName or groupName]
            local core = coreGroup and coreGroup[name]
            -- Only inventory core definitions are eligible; addon plugin callback
            -- registries and their start/end hooks are deliberately not invoked.
            if core and type(core.filterCallback) == "function" and core.filterCallback == button.filterCallback then
                local id = categoryId .. ":s:" .. name
                local sub = { id = id, label = LabelFor(name), details = {} }
                cat.subfilters[#cat.subfilters + 1] = sub
                entries[#entries + 1] = { id = id, parent = categoryId, callback = core.filterCallback, label = sub.label }
                for index, detail in ipairs(type(core.dropdownCallbacks) == "table" and core.dropdownCallbacks or {}) do
                    if type(detail.name) == "string" and type(detail.filterCallback) == "function" then
                        local detailId = id .. ":d:" .. index .. ":" .. detail.name
                        local label = LabelFor(detail.name)
                        if type(detail.addString) == "string" then label = label .. " " .. LabelFor(detail.addString) end
                        sub.details[#sub.details + 1] = { id = detailId, label = label }
                        entries[#entries + 1] = { id = detailId, parent = id, callback = detail.filterCallback, label = label }
                    end
                end
            end
        end
        categories[#categories + 1] = cat
    end
    if #categories == 0 then return end
    local old = self.schema
    local same = old and #old.entries == #entries
    if same then
        for i, entry in ipairs(entries) do
            local previous = old.entries[i]
            if previous.id ~= entry.id or previous.callback ~= entry.callback or previous.category ~= entry.category
                or previous.label ~= entry.label then same = false; break end
        end
    end
    if same then return old end
    self.cache = {}
    self.schema = { catalog = { version = 1, categories = categories }, entries = entries }
    return self.schema
end

function F:Enrich(record, sources)
    local schema = self:BuildSchema()
    if not schema or not SHARED_INVENTORY then return end
    record.afFilters = schema.catalog -- Persisted catalog contains no callbacks.
    record.afFilterErrors = 0
    local now = GetTimeStamp()
    for i, item in ipairs(record.items) do
        local source = sources[i]
        local cacheSlot = source.bag .. ":" .. source.slot
        local signature = table.concat({ GetCurrentCharacterId(), item.link, item.stack, item.quality,
            tostring(item.junk), tostring(item.playerLocked), tostring(item.stolen),
            Id64ToString(GetItemUniqueId(source.bag, source.slot)) }, ":")
        local cached = self.cache[cacheSlot]
        if not cached or cached.signature ~= signature or now - cached.time >= 1 then
            local native = SHARED_INVENTORY:GenerateSingleSlotData(source.bag, source.slot)
            local data = {}
            for key, value in pairs(native or {}) do data[key] = value end
            data.bagId, data.slotIndex = source.bag, source.slot
            data.isJunk, data.filterData = item.junk, item.filters
            local matches, unknown = {}, {}
            for _, entry in ipairs(schema.entries) do
                if not entry.parent or matches[entry.parent] then
                    local ok, value = pcall(function()
                        if not native then error("native slot data unavailable") end
                        if entry.category then
                            return ZO_ItemFilterUtils.IsSlotFilterDataInItemTypeDisplayCategory(data, entry.category)
                        end
                        return entry.callback(data)
                    end)
                    if ok then
                        if value then matches[entry.id] = true end
                    else
                        unknown[entry.id] = true
                        if not self.warnings[entry.id] then
                            self.warnings[entry.id] = true
                            d("GridBags: snapshot filter classification unavailable: " .. entry.label)
                        end
                    end
                end
            end
            cached = { signature = signature, time = now, matches = matches, unknown = unknown }
            self.cache[cacheSlot] = cached
        end
        item.afMatches = cached.matches
        if next(cached.unknown) then item.afUnknown = cached.unknown; record.afFilterErrors = record.afFilterErrors + 1 end
    end
end

function F:Matches(item, selection)
    if not selection then return true end
    for _, id in ipairs({ selection.category or false, selection.subfilter or false, selection.detail or false }) do
        if id and not (item.afMatches and item.afMatches[id]) then return false end
    end
    return true
end

local function Find(entries, id)
    for _, entry in ipairs(entries or {}) do if entry.id == id then return entry end end
end

function F:Normalize(record, panel)
    local selection = panel.snapshotSelection or {}
    panel.snapshotSelection = selection
    local category = Find(record.afFilters.categories, selection.category)
    if not category then selection.category, selection.subfilter, selection.detail = nil, nil, nil end
    local subfilter = category and Find(category.subfilters, selection.subfilter)
    if not subfilter then selection.subfilter, selection.detail = nil, nil end
    local detail = subfilter and Find(subfilter.details, selection.detail)
    if not detail then selection.detail = nil end
    return selection, category, subfilter, detail
end

function F:Menu(owner, button, level)
    local record = GridBagsSnapshots:GetSelected(owner)
    if not record or not record.afFilters then return end
    local panel = owner.backpack
    local selection, category, subfilter = self:Normalize(record, panel)
    local entries = level == "category" and record.afFilters.categories or
        (level == "subfilter" and category and category.subfilters) or (subfilter and subfilter.details) or {}
    local function Select(id)
        selection[level] = id
        if level == "category" then selection.subfilter, selection.detail = nil, nil end
        if level == "subfilter" then selection.detail = nil end
        panel.scrollRow = 0
        owner:QueueRefresh()
    end
    ClearMenu()
    AddMenuItem("All", function() Select(nil) end)
    for _, entry in ipairs(entries) do
        local id = entry.id
        AddMenuItem(entry.label, function() Select(id) end)
    end
    ShowMenu(button)
end

function F:CreateUI(owner, parent)
    local WM = WINDOW_MANAGER
    local ui = { control = WM:CreateControl("GridBagsSavedFilters", parent, CT_CONTROL) }
    ui.control:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 158)
    ui.control:SetDrawTier(DT_MEDIUM)
    ui.control:SetDrawLayer(DL_CONTROLS)
    ui.control:SetDrawLevel(10)
    local background = WM:CreateControl(nil, ui.control, CT_BACKDROP)
    background:SetAnchorFill(ui.control)
    background:SetCenterColor(0.07, 0.08, 0.10, 0.98)
    background:SetEdgeColor(0.35, 0.31, 0.23, 1)
    background:SetEdgeTexture("", 1, 1, 1, 0)
    background:SetDrawLayer(DL_BACKGROUND)
    background:SetDrawTier(DT_MEDIUM)
    ui.title = WM:CreateControl(nil, ui.control, CT_LABEL)
    ui.title:SetFont("ZoFontGameSmall")
    ui.title:SetDrawTier(DT_MEDIUM)
    ui.title:SetAnchor(TOPLEFT, ui.control, TOPLEFT, 6, 2)
    for _, level in ipairs({ "category", "subfilter", "detail" }) do
        local button = WM:CreateControlFromVirtual(nil, ui.control, "ZO_DefaultButton")
        button:SetMouseEnabled(true)
        button:SetDrawTier(DT_MEDIUM)
        button:SetDrawLayer(DL_CONTROLS)
        button:SetDrawLevel(11)
        button:SetHandler("OnClicked", function(c) self:Menu(owner, c, level) end)
        ui[level] = button
    end
    ui.caption = WM:CreateControl(nil, ui.control, CT_LABEL)
    ui.caption:SetFont("ZoFontGameSmall")
    ui.caption:SetDrawTier(DT_MEDIUM)
    ui.caption:SetAnchor(TOPLEFT, ui.control, TOPLEFT, 6, 98)
    ui.control:SetHidden(true)
    return ui
end

function F:UpdateUI(owner, ui, record, width)
    local classified = record.afFilters and record.afFilters.categories ~= nil
    local selection, category, subfilter, detail
    if classified then selection, category, subfilter, detail = self:Normalize(record, owner.backpack)
    else owner.backpack.snapshotSelection = nil end
    local half = (width - 22) / 2
    ui.control:SetDimensions(width, 160)
    ui.control:SetHidden(false)
    for _, level in ipairs({ "category", "subfilter", "detail" }) do
        local button = ui[level]
        button:ClearAnchors()
        button:SetAnchor(TOPLEFT, ui.control, TOPLEFT, level == "subfilter" and half + 16 or 6, level == "detail" and 62 or 26)
        button:SetDimensions(level == "detail" and width - 12 or half, 30)
        button:SetHidden(false)
    end
    ui.title:SetText(classified and "SNAPSHOT FILTERS" or "SNAPSHOT FILTERS | Refresh required")
    ui.category:SetEnabled(classified and true or false)
    ui.category:SetText("Category: " .. (category and category.label or "All"))
    ui.subfilter:SetText("Type: " .. (subfilter and subfilter.label or "All"))
    ui.subfilter:SetEnabled(category ~= nil)
    ui.detail:SetText("Detail: " .. (detail and detail.label or "All"))
    ui.detail:SetEnabled(subfilter ~= nil and #subfilter.details > 0)
    ui.caption:SetDimensions(width - 12, 60)
    ui.caption:SetText(not classified and "This older record has no detailed filter data. Log into this character, or visit the banker for the bank snapshot. Search and basic filters still work." or
        "Saved Advanced Filters classifications. Core filters only; live/plugin filters unavailable." ..
        ((record.afFilterErrors or 0) > 0 and "\nSome classifications were unavailable when captured." or ""))
end
