local O, P = OneCraft, OneCraft.Equipment

function P.RequestFor(item)
    local kind = P.types[item.type]
    local index = item.cp and 25 + math.floor(item.level / 10) or math.max(1, math.floor(item.level / 2))
    return {type = "smithing", pattern = kind.pattern, station = kind.station,
        materialIndex = index, materialQuantity = P.client.GetMatRequirements(kind.pattern, index, kind.station),
        style = item.style, trait = item.trait + 1, setIndex = item.set, quality = item.quality,
        useUniversalStyleItem = false, smithingQuantity = 1}
end

function P.Materials()
    local needed = {}
    for _, key in ipairs(P.slotOrder) do
        local item = P.saved.items[key]
        if item and P.ValidItem(item) then
            local request = P.RequestFor(item)
            -- Add equipment and glyph costs for every applied slot.
            local requirements = P.client:getMatRequirements(request)
            for id, count in pairs(requirements or {}) do needed[id] = (needed[id] or 0) + count end
            local selection = P.GlyphSelection(item)
            if selection then
                for _, id in ipairs(O.Enchanting.RecipeEngine.RuneIds(selection)) do needed[id] = (needed[id] or 0) + 1 end
            end
        end
    end
    local result = {}
    for id, count in pairs(needed) do
        local link = O.Enchanting.ItemLink(id)
        local backpack, bank, craftBag = GetItemLinkStacks(link)
        result[#result + 1] = {id = id, link = link, need = count, have = backpack + bank + craftBag,
            name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(link)), icon = GetItemLinkIcon(link)}
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

function P.HasQueue()
    return P.saved.batch and P.saved.batch.completed < P.saved.batch.total
end

function P.SaveQueue()
    if P.client then P.saved.queue = P.EncodeQueue(P.client:getAddonCraftingQueue()) end
end

function P.Submit()
    if ZO_CraftingUtils_IsPerformingCraftProcess() or P.HasQueue() then return false, P.words.busy end
    if not P.ValidLayout(P.saved.items) then return false, P.words.incompatible end
    local items = {}
    for _, key in ipairs(P.slotOrder) do
        local item = P.saved.items[key]
        if item then
            if not P.ValidItem(item) then return false, P.words.invalid end
            items[#items + 1] = P.Copy(item)
        end
    end
    if #items == 0 then return false, P.words.invalid end
    P.saved.serial = (P.saved.serial or 0) + 1
    P.saved.batch = {total = #items, completed = 0, done = {}, references = {}}
    -- Stage every request before enabling autocraft. No partial submission can
    -- start while the rest of the batch is still being constructed.
    local references = {}
    for i, item in ipairs(items) do
        local kind = P.types[item.type]
        local ids = item.enchant and O.Enchanting.RecipeEngine.RuneIds(P.GlyphSelection(item)) or {}
        local reference = "OneCraft:" .. P.saved.serial .. ":" .. i
        references[#references + 1] = reference
        P.saved.batch.references[reference] = true
        local request = P.client:CraftSmithingItemByLevel(kind.pattern, item.cp, item.level,
            item.style, item.trait + 1, false, kind.station, item.set, item.quality, false, reference,
            ids[1], ids[2], ids[3], 1)
        if not request then
            for _, ref in ipairs(references) do P.client:cancelItemByReference(ref) end
            P.saved.batch = nil
            P.SaveQueue()
            return false, P.words.invalid
        end
    end
    P.client:SetAllAutoCraft(true)
    P.SaveQueue()
    P.Engine.Run()
    return true
end

function P.Cancel()
    if ZO_CraftingUtils_IsPerformingCraftProcess() or P.client.active then return false, P.words.busy end
    P.client:cancelItem()
    P.saved.batch = nil
    P.SaveQueue()
    return true
end

function P.ClearAll()
    local ok, reason = P.Cancel()
    if not ok then return false, reason end
    P.saved.items, P.status, P.dragging, P.pressed = {}, nil, nil, nil
    if P.draft then P.draft = P.DefaultItem(P.selected) end
    return true
end

function P.OnCraftEvent(event, station, result)
    local batch = P.saved.batch
    if event == P.Engine.SUCCESS and batch and result and batch.references and batch.references[result.reference] and not batch.done[result.reference] then
        batch.done[result.reference] = true
        batch.completed = math.min(batch.total, batch.completed + 1)
        if batch.completed == batch.total then
            P.saved.items, P.saved.batch, P.status = {}, nil, nil
        end
    elseif event == P.Engine.FAILED then
        P.status = P.words.failed
    elseif event == P.Engine.WAITING and P.HasQueue() then
        P.status = P.words.waiting
    end
    P.SaveQueue()
    if P.RefreshUI then P.RefreshUI() end
end

function P.Initialize()
    if not GetNumConsolidatedSmithingSets then return end
    O.settings.equipmentCharacters = O.settings.equipmentCharacters or {}
    local character = GetCurrentCharacterId()
    local saved = O.settings.equipmentCharacters[character]
    if not saved then
        saved = {version = 1, items = {}}
        O.settings.equipmentCharacters[character] = saved
    end
    P.saved = saved
    P.client = P.Engine.New(P.OnCraftEvent)
    local restored = P.DecodeQueue(saved.queue)
    if restored then
        local seen = {}
        for station = 1, 7 do
            local target = P.client.personalQueue[station]
            for _, request in ipairs(restored[station] or {}) do
                if not seen[request] then
                    request.timestamp = P.Engine.NextOrder()
                    seen[request] = true
                end
                target[#target + 1] = request
            end
        end
    end
    P.Engine.Migrate(P.client)
    P.CreateUI()
    local EM = EVENT_MANAGER
    EM:RegisterForEvent("OneCraftEquipmentStation", EVENT_CRAFTING_STATION_INTERACT, function()
        P.stationOpen = true
        P.RefreshStationTab()
        P.status = nil
        for _, list in ipairs(P.client.personalQueue) do for _, request in ipairs(list) do request.failed = nil end end
        zo_callLater(P.Engine.Run, 150)
    end)
    EM:RegisterForEvent("OneCraftEquipmentEnd", EVENT_END_CRAFTING_STATION_INTERACT, function()
        P.stationOpen = false
        P.RefreshStationTab()
        P.Hide()
        P.SaveQueue()
    end)
    EM:RegisterForEvent("OneCraftEquipmentMode", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        P.RefreshStationTab()
        if IsInGamepadPreferredMode() then P.Hide() end
    end)
    -- A UI reload can initialize us after the station interaction event.
    P.stationOpen = GetCraftingInteractionType() ~= CRAFTING_TYPE_INVALID
    P.RefreshStationTab()
    EM:RegisterForEvent("OneCraftEquipmentSave", EVENT_PLAYER_DEACTIVATED, P.SaveQueue)
    -- Refresh totals after changes, coalesced to one update per inventory burst.
    local function refresh()
        if P.refreshQueued then return end
        P.refreshQueued = true
        zo_callLater(function()
            P.refreshQueued = false
            if P.visible then P.RefreshUI() end
            P.Engine.Run()
        end, 150)
    end
    EM:RegisterForEvent("OneCraftEquipmentInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, refresh)
    EM:RegisterForEvent("OneCraftEquipmentFullInventory", EVENT_INVENTORY_FULL_UPDATE, refresh)
    CALLBACK_MANAGER:RegisterCallback("CraftingAnimationsStopped", function() P.SaveQueue(); refresh() end)
    -- Native station Create bindings stay present behind the overlay.
    ZO_PreHook("ZO_KeyboardCraftingUtils_RequestCraftingCreate", function() return P.visible == true end)
end
