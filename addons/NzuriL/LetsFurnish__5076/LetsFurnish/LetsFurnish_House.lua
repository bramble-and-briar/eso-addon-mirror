local LF = LetsFurnish
local ask, say = LF.ask, LF.say
local unrecordable, record = LF.unrecordable, LF.record
local L, count, sentences, list = LF.L, LF.count, LF.sentences, LF.list
local HOUSE, COLLECTION = L.house.in_house, L.house.collection
local DEFAULT_BACKUP_LIMIT = 5
local MOST_BACKUPS = 20
LF.MOST_BACKUPS = MOST_BACKUPS
local EDITOR_WAIT = 600
local function clean(name)
    return name and (string.gsub(name, "%^.*$", "")) or nil
end
local function itemLink(row)
    return row.link or string.format("|H1:item:%d:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", row.item_id)
end
local function rowName(row)
    local name
    if row.kind == "collectible" then name = ask(GetCollectibleName, row.item_id) else name = ask(GetItemLinkName, itemLink(row)) end
    if LF.nonempty(clean(name)) then return clean(name) end
    if row.kind == "collectible" then return zo_strformat(L.house.collectible, tostring(row.item_id)) end
    return zo_strformat(L.house.item, tostring(row.item_id))
end
local function iconOf(row, id)
    local icon = id and LF.nonempty(select(2, ask(GetPlacedHousingFurnitureInfo, id)))
    if not icon and row then
        if row.kind == "collectible" then icon = ask(GetCollectibleIcon, row.item_id) else icon = ask(GetItemLinkIcon, itemLink(row)) end
    end
    return type(icon) == "string" and LF.nonempty(icon) or nil
end
LF.clean, LF.itemLink, LF.rowName, LF.iconOf = clean, itemLink, rowName, iconOf
local function limitOf(dataId)
    if not dataId or dataId == 0 then return nil end
    local _, _, _, limit = ask(GetFurnitureDataInfo, dataId)
    return limit
end
local function rowLimit(row)
    if row.kind == "collectible" then return limitOf(ask(GetCollectibleFurnitureDataId, row.item_id)) end
    return limitOf(ask(GetItemLinkFurnitureDataId, itemLink(row)))
end
function LF.stock()
    local stock = {}
    for _, bag in ipairs(LF.takeBags()) do
        local place = LF.bagName(bag)
        for slot = 0, (ask(GetBagSize, bag) or 0) - 1 do
            local itemId = GetItemId(bag, slot)
            if itemId and itemId ~= 0 and ask(IsItemPlaceableFurniture, bag, slot) ~= false then
                local what = "item:" .. tostring(itemId)
                local count = ask(GetSlotStackSize, bag, slot) or 1
                local places = stock[what] or {}
                stock[what] = places
                local last = places[#places]
                if last and last.place == place then
                    last.count = last.count + count
                else
                    places[#places + 1] = { place = place, count = count }
                end
            end
        end
    end
    return stock
end
function LF.slots(tasks)
    local houseId = GetCurrentZoneHouseId()
    local slots, by = {}, {}
    local first, last = HOUSING_FURNISHING_LIMIT_TYPE_ITERATION_BEGIN, HOUSING_FURNISHING_LIMIT_TYPE_ITERATION_END
    if first and last then
        for limit = first, last do
            local slot = { limit = limit, name = ask(GetString, "SI_HOUSINGFURNISHINGLIMITTYPE", limit) or zo_strformat(L.house.limit, tostring(limit)),
                           placed = ask(GetNumHouseFurnishingsPlaced, limit) or 0, most = ask(GetHouseFurnishingPlacementLimit, houseId, limit) or 0,
                           adding = 0, freeing = 0 }
            slots[#slots + 1] = slot
            by[limit] = slot
        end
    end
    for _, task in ipairs(tasks or {}) do
        local slot = by[task.limit]
        if slot and task.action == "remove" then
            slot.freeing = slot.freeing + 1
        elseif slot and (task.action == "item" or task.action == "collectible") and not task.missing and not task.sources[1].house then
            slot.adding = slot.adding + 1
        end
    end
    return slots
end
function LF.diff(layout, withLinks)
    local steps, counts, bound, found, claimed, lacking, inPlace, keyOf = LF.plan(layout, withLinks)
    local ids = LF.placedIds()
    local stock = LF.stock()
    local keys = {}
    for key in pairs(ids) do
        if not claimed[key] then keys[#keys + 1] = key end
    end
    table.sort(keys)
    local loose = {}
    for _, key in ipairs(keys) do
        local what = LF.whatIs(ids[key])
        loose[what] = loose[what] or {}
        table.insert(loose[what], key)
    end
    local tasks, wanted, offered = {}, {}, {}
    local known = {}
    local function about(row)
        local key = LF.rowWhat(row) .. "|" .. tostring(row.link or "")
        local found = known[key]
        if not found then
            found = { name = rowName(row), icon = iconOf(row), limit = rowLimit(row) }
            known[key] = found
        end
        return found
    end
    for _, step in ipairs(steps) do
        if step.action == "item" or step.action == "collectible" then
            local what = LF.rowWhat(step.row)
            local standing = loose[what] or {}
            wanted[what] = (wanted[what] or 0) + 1
            local sources, total = {}, #standing
            if standing[wanted[what]] then
                sources[#sources + 1] = { place = HOUSE, house = true, count = #standing, key = standing[wanted[what]], id = ids[standing[wanted[what]]] }
                offered[standing[wanted[what]]] = true
            end
            if step.action == "collectible" and #standing == 0 then
                sources[#sources + 1] = { place = COLLECTION, count = 1 }
                total = 1
            end
            for _, source in ipairs(step.action == "item" and stock[what] or {}) do
                sources[#sources + 1] = source
                total = total + source.count
            end
            step.sources, step.missing = sources, wanted[what] > total
            step.limit = about(step.row).limit
        end
        if step.row then step.name = about(step.row).name end
        if step.id and not step.name then step.name = clean(ask(GetPlacedHousingFurnitureInfo, step.id)) end
        step.icon = step.id and iconOf(step.row, step.id) or (step.row and about(step.row).icon) or nil
        tasks[#tasks + 1] = step
    end
    if withLinks then
        local rowByUid, placing = {}, {}
        for _, row in ipairs(type(layout.items) == "table" and layout.items or {}) do
            if type(row) == "table" and row.uid ~= nil then rowByUid[row.uid] = row end
        end
        for _, task in ipairs(tasks) do
            if (task.action == "item" or task.action == "collectible") and not task.missing and task.uid ~= nil then placing[task.uid] = true end
        end
        for _, task in ipairs(tasks) do
            if task.action == "link" then
                local up = rowByUid[task.parentUid]
                task.parentName = up and about(up).name or nil
                task.blocked = (task.childKey == nil and not placing[task.uid]) or (task.parentKey == nil and not placing[task.parentUid]) or nil
            end
        end
    end
    for _, row in ipairs(lacking) do
        tasks[#tasks + 1] = { action = "missing", row = row, uid = row.uid, name = about(row).name, icon = about(row).icon, missing = true }
    end
    for _, key in ipairs(keys) do
        if not offered[key] then
            local name, _, dataId = ask(GetPlacedHousingFurnitureInfo, ids[key])
            tasks[#tasks + 1] = { action = "remove", id = ids[key], key = key, name = clean(name) or key, icon = iconOf(nil, ids[key]), limit = limitOf(dataId) }
        end
    end
    for _, standing in ipairs(inPlace) do
        standing.uid, standing.name, standing.icon = standing.row.uid, rowName(standing.row), iconOf(standing.row, standing.id)
    end
    return { layout = layout, tasks = tasks, counts = counts, bound = bound, found = found, inPlace = inPlace, slots = LF.slots(tasks), keyOf = keyOf or {} }
end
local function refused(layout)
    if GetCurrentZoneHouseId() == 0 then return L.core.no_house end
    if not IsOwnerOfCurrentHouse() then return L.house.not_owner end
    if LF.queue then return L.house.busy end
    if layout and layout.house_id and layout.house_id ~= GetCurrentZoneHouseId() then
        return zo_strformat(L.house.other_house, tostring(layout.house_id), tostring(GetCurrentZoneHouseId()))
    end
    return nil
end
LF.unchangeable = refused
local function inEditor(go)
    if GetHousingEditorMode() == HOUSING_EDITOR_MODE_DISABLED then
        HousingEditorRequestModeChange(HOUSING_EDITOR_MODE_SELECTION)
        zo_callLater(go, EDITOR_WAIT)
    else
        go()
    end
end
function LF.job(layout, found)
    local done = LF.appliedOf(layout)
    done.started, done.finished, done.stopped = GetTimeStamp(), nil, nil
    for _, f in ipairs(found or {}) do
        if f.uid ~= nil then
            done.items[f.uid] = { result = "placed", game_id = f.game_id }
            LF.forget(done, f.uid)
        end
    end
    return { layout = layout, tally = LF.tally(done) }
end
function LF.settle(job, diff)
    for _, task in ipairs(diff.tasks) do
        if task.action ~= "remove" and task.action ~= "conform" and not task.missing and not task.blocked then return end
    end
    job.tally.done.finished, job.tally.done.stopped = job.tally.done.finished or GetTimeStamp(), nil
end
local function stepOf(task, n)
    local source = task.sources and (task.sources[n or 1] or task.sources[1])
    if source and source.house then
        return { action = "move", id = source.id, row = task.row, uid = task.uid, take = true }
    elseif source and n and task.action == "item" then
        return { action = "item", row = task.row, uid = task.uid, place = source.place }
    end
    return task
end
function LF.act(job, task, n, after)
    local why = refused(job.layout)
    if why or task.missing then
        say(why or zo_strformat(L.house.not_found, tostring(task.name)))
        return false
    end
    LF.guard("change", job.layout.name)
    local step = stepOf(task, n or 1)
    inEditor(function()
        local refusal = refused(job.layout)
        if refusal or not LF.sameHouse(job.tally) then
            say(refusal or L.house.not_owner)
            return
        end
        local outcome = LF.perform(job.tally, step)
        if outcome.result == "absent" and step.action == "item" then LF.takeProblem(1, task.name) end
        if outcome.result == "absent" and step.action == "item" then LF.trace(job.tally, "stopped", step, { why = "no_place" }) end
        if outcome.result == "failed" or outcome.result == "error" or (outcome.result == "absent" and step.action ~= "item") then
            local reason = outcome.code and ask(GetString, "SI_HOUSINGREQUESTRESULT", outcome.code) or outcome.error or L.house.moved_away
            say(zo_strformat(L.house.refused, task.name or "?", tostring(reason)))
        end
        if after then after(outcome) end
    end)
    return true
end
local MOVES = { move = true, state = true, path = true }
local function inList(task, which)
    if task.action == "remove" or task.missing or task.blocked then return false end
    if task.action == "link" or task.action == "unlink" then
        local standing = task.childKey ~= nil and (task.action == "unlink" or task.parentKey ~= nil)
        if which == "move" then return standing end
        if which == "place" then return not standing end
        return true
    end
    if task.action == "conform" then return which ~= "place" end
    if which == "move" then return MOVES[task.action] == true end
    if which == "place" then return not MOVES[task.action] end
    return true
end
LF.inList = inList
function LF.run(job, diff, which)
    local why = refused(job.layout)
    if why then
        say(why)
        return false
    end
    local steps = {}
    for _, task in ipairs(diff.tasks) do
        if inList(task, which) then steps[#steps + 1] = stepOf(task) end
    end
    if #steps == 0 then return false end
    LF.guard("apply", job.layout.name)
    local done = job.tally.done
    done.started, done.finished, done.stopped = GetTimeStamp(), nil, nil
    LF.start(job.layout.name, steps, done)
    say(sentences(count(L.core.applying, #steps), L.core.stop_stops))
    return true
end
local MAX_CHILDREN = 50
local function houseLinks(ids)
    local parents, counts = {}, {}
    for key, id in pairs(ids) do
        local up = LF.parentKey(id)
        if up then
            parents[key] = up
            counts[up] = (counts[up] or 0) + 1
        end
    end
    return parents, counts
end
local function capacityIssue(tree, parents, counts)
    local delta = {}
    for _, m in ipairs(tree.members) do
        local old = m.key and parents[m.key]
        if old then delta[old] = (delta[old] or 0) - 1 end
        local new = m.parent and m.parent.key
        if new then delta[new] = (delta[new] or 0) + 1 end
    end
    for _, m in ipairs(tree.members) do
        local total = (counts[m.key] or 0) + (delta[m.key] or 0)
        if total > MAX_CHILDREN then
            return zo_strformat(L.window.link_capacity, m.name, total, MAX_CHILDREN)
        end
    end
end
function LF.linkTrees(diff)
    local layout, keyOf = diff.layout, diff.keyOf or {}
    local items = type(layout.items) == "table" and layout.items or {}
    local ids = LF.placedIds()
    local parents, counts = houseLinks(ids)
    local hasLinks = false
    for _, row in ipairs(items) do
        if type(row) == "table" and row.parent ~= nil then hasLinks = true break end
    end
    if not hasLinks and not next(parents) then return {}, {} end
    local rows, byUid, kids = {}, {}, {}
    for _, row in ipairs(items) do
        if LF.usable(row) and row.uid ~= nil and not byUid[row.uid] then
            byUid[row.uid] = row
            rows[#rows + 1] = row
        end
    end
    local function up(row)
        return row.parent ~= nil and row.parent ~= row.uid and byUid[row.parent] or nil
    end
    for _, row in ipairs(rows) do
        local parent = up(row)
        if parent then
            kids[parent.uid] = kids[parent.uid] or {}
            table.insert(kids[parent.uid], row)
        end
    end
    local function nameOf(key)
        local id = key and ids[key]
        return id and clean(ask(GetPlacedHousingFurnitureInfo, id)) or tostring(key)
    end
    local trees = {}
    for _, top in ipairs(rows) do
        if not up(top) and kids[top.uid] then
            local tree = { root = top, uid = top.uid, members = {}, missing = 0, lost = {}, done = true }
            local stack = { { row = top, depth = 0 } }
            while #stack > 0 do
                local member = table.remove(stack)
                local row = member.row
                member.key = keyOf[row.uid]
                member.id = member.key and ids[member.key] or nil
                member.name, member.icon = rowName(row), iconOf(row, member.id)
                tree.members[#tree.members + 1] = member
                local children = kids[row.uid] or {}
                for i = #children, 1, -1 do
                    stack[#stack + 1] = { row = children[i], parent = member, depth = member.depth + 1 }
                end
            end
            for _, m in ipairs(tree.members) do
                if not m.id then
                    tree.missing, tree.done = tree.missing + 1, false
                else
                    local now, want = parents[m.key], m.parent and m.parent.key or nil
                    m.previousKey = now
                    if now ~= want or (m.parent and not m.parent.id) then tree.done = false end
                    if now and now ~= want then tree.lost[#tree.lost + 1] = { name = m.name, parent = nameOf(now) } end
                end
            end
            tree.capacityIssue = capacityIssue(tree, parents, counts)
            tree.name, tree.icon = tree.members[1].name, tree.members[1].icon
            trees[#trees + 1] = tree
        end
    end
    local wanted, extras, groups = {}, {}, {}
    for _, row in ipairs(rows) do
        local child = keyOf[row.uid]
        if child and up(row) then wanted[child] = keyOf[row.parent] end
    end
    for child, parent in pairs(parents) do
        if wanted[child] ~= parent then
            local group = groups[parent]
            if not group then
                group = { key = parent, name = nameOf(parent), icon = iconOf(nil, ids[parent]), links = {} }
                groups[parent] = group
                extras[#extras + 1] = group
            end
            group.links[#group.links + 1] = { key = child, id = ids[child], parent = parent, name = nameOf(child) }
        end
    end
    table.sort(extras, function(a, b) return a.key < b.key end)
    for _, group in ipairs(extras) do table.sort(group.links, function(a, b) return a.key < b.key end) end
    return trees, extras
end
function LF.linkable(trees)
    local out = {}
    for _, tree in ipairs(trees or {}) do
        if not tree.done and tree.missing == 0 and not tree.capacityIssue then out[#out + 1] = tree end
    end
    return out
end
function LF.linkTreesRun(layout, trees)
    local why = refused(layout)
    if why then
        say(why)
        return false
    end
    local ids = LF.placedIds()
    local parents, counts = houseLinks(ids)
    local unlinks, links = {}, {}
    for _, tree in ipairs(LF.linkable(trees)) do
        local issue = capacityIssue(tree, parents, counts)
        if issue then say(issue) return false end
        for _, m in ipairs(tree.members) do
            if not ids[m.key] or LF.parentKey(m.id) ~= m.previousKey then return false end
            if m.previousKey then unlinks[#unlinks + 1] = { action = "unlink", id = m.id, name = m.name } end
        end
        for _, m in ipairs(tree.members) do
            if m.parent then
                links[#links + 1] = { action = "link", fixed = true, id = m.id, parentId = m.parent.id, parentKey = m.parent.key, previousKey = m.previousKey, name = m.name }
            end
        end
    end
    if #links == 0 then return false end
    local steps = unlinks
    for _, step in ipairs(links) do steps[#steps + 1] = step end
    LF.guard("change", layout.name)
    LF.start(layout.name, steps, { items = {} })
    say(sentences(count(L.core.applying, #steps), L.core.stop_stops))
    return true
end
function LF.linksInHouse()
    local out = {}
    for key, id in pairs(LF.placedIds()) do
        local parent = LF.parentKey(id)
        if parent then out[#out + 1] = { key = key, id = id, parent = parent, name = clean(ask(GetPlacedHousingFurnitureInfo, id)) or key } end
    end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end
function LF.unlinkAll(links, title)
    local why = refused()
    if why then
        say(why)
        return false
    end
    local steps = {}
    for _, f in ipairs(links) do
        if LF.parentKey(f.id) == f.parent then
            steps[#steps + 1] = { action = "unlink", id = f.id, name = f.name, clearsLink = true }
        end
    end
    if #steps == 0 then return false end
    LF.guard("change")
    LF.start(title or L.window.unlink_all, steps, { items = {} })
    say(sentences(count(L.core.applying, #steps), L.core.stop_stops))
    return true
end
local PLACE_STEP = 100
local function around(n)
    local x, z, dx, dz, len, walked, turns = 0, 0, 1, 0, 1, 0, 0
    for _ = 1, n do
        x, z, walked = x + dx, z + dz, walked + 1
        if walked == len then
            walked, dx, dz, turns = 0, -dz, dx, turns + 1
            if turns % 2 == 0 then len = len + 1 end
        end
    end
    return x, z
end
function LF.placeFromPlan(place)
    local free = {}
    for _, slot in ipairs(LF.slots({})) do
        if slot.most > 0 then free[slot.limit] = math.max(0, slot.most - slot.placed) end
    end
    local units, over = {}, 0
    for _, bag in ipairs(place.bag == BAG_BANK and { BAG_BANK, BAG_SUBSCRIBER_BANK } or { place.bag }) do
        for slot = 0, (bag and ask(GetBagSize, bag) or 0) - 1 do
            local id = ask(GetItemId, bag, slot)
            if id and id ~= 0 and ask(IsItemPlaceableFurniture, bag, slot) ~= false then
                local limit = rowLimit({ kind = "item", item_id = id })
                for _ = 1, ask(GetSlotStackSize, bag, slot) or 1 do
                    if limit and free[limit] then
                        if free[limit] > 0 then
                            free[limit] = free[limit] - 1
                            units[#units + 1] = id
                        else
                            over = over + 1
                        end
                    else
                        units[#units + 1] = id
                    end
                end
            end
        end
    end
    return { name = place.name, bag = place.bag, units = units, over = over }
end
function LF.placeFrom(place, confirmed)
    local why = refused()
    if why then
        say(why)
        return false
    end
    local px, py, pz = ask(GetPlayerWorldPositionInHouse)
    if type(px) ~= "number" or type(py) ~= "number" or type(pz) ~= "number" then
        say(L.house.no_position)
        return false
    end
    local plan = LF.placeFromPlan(place)
    if confirmed then
        local changed = #confirmed.units ~= #plan.units or confirmed.over ~= plan.over
        for i, id in ipairs(plan.units) do
            if confirmed.units[i] ~= id then changed = true break end
        end
        if changed then return false, "changed" end
    end
    if #plan.units == 0 then
        say(zo_strformat(L.house.nothing_to_place_from, plan.name))
        return false
    end
    local bags = place.bag == BAG_BANK and { BAG_BANK, BAG_SUBSCRIBER_BANK } or { place.bag }
    local steps = {}
    for i, id in ipairs(plan.units) do
        local x, z = around(i - 1)
        steps[i] = { action = "item", bags = bags, row = { kind = "item", item_id = id, position = { px + x * PLACE_STEP, py, pz + z * PLACE_STEP },
                                                           rotation = { 0, 0, 0 } } }
    end
    LF.guard("change")
    LF.start(zo_strformat(L.window.place_from, plan.name), steps, { items = {} }, true)
    say(sentences(count(L.core.applying, #steps), L.core.stop_stops))
    return true
end
local function startRemovals(name, steps, wholeHouse)
    LF.start(name, steps, { items = {} })
    LF.queue.removing, LF.queue.wholeHouse = true, wholeHouse
    say(sentences(count(L.core.removing, #steps), L.core.stop_stops))
    return true
end
function LF.removeAll(layout, diff)
    local why = refused(layout)
    if why then
        say(why)
        return false
    end
    local confirmed, steps = {}, {}
    for _, task in ipairs(diff.tasks) do
        if task.action == "remove" then confirmed[task.key] = true end
    end
    for _, task in ipairs(LF.diff(layout).tasks) do
        if task.action == "remove" and confirmed[task.key] then
            steps[#steps + 1] = { action = "remove", id = task.id, key = task.key, name = task.name }
        end
    end
    if #steps == 0 then return false end
    LF.guard("change", layout.name)
    return startRemovals(layout.name, steps)
end
function LF.houseRemovalSteps()
    local steps = {}
    for key, id in pairs(LF.placedIds()) do
        steps[#steps + 1] = { action = "remove", key = key, id = id, name = clean(ask(GetPlacedHousingFurnitureInfo, id)) or key }
    end
    table.sort(steps, function(a, b) return a.key < b.key end)
    return steps
end
local RETRIEVE_BAGS = ZO_HOUSING_FURNITURE_RETRIEVE_TO_BAGS or {}
local RESTORE_WAIT = 2000
local R = {}
function LF.gameWords(id, ours)
    return LF.nonempty(id and ask(GetString, id) or "") or ours
end
local function retrieveBag(bag, kind)
    local chest = ask(GetCollectibleForBag, bag) or 0
    local name
    if chest ~= 0 then
        name = LF.nonempty(ask(GetCollectibleNickname, chest) or "") or LF.clean(ask(GetCollectibleName, chest))
    else
        name = LF.nonempty(ask(GetString, "SI_BAG", bag) or "")
        if name and string.find(name, "^SI_BAG") then name = nil end
    end
    local used, total = ask(GetNumBagUsedSlots, bag) or 0, ask(GetBagUseableSize, bag) or 0
    if bag == BAG_BANK and BAG_SUBSCRIBER_BANK then
        used, total = used + (ask(GetNumBagUsedSlots, BAG_SUBSCRIBER_BANK) or 0), total + (ask(GetBagUseableSize, BAG_SUBSCRIBER_BANK) or 0)
    end
    local enabled, why = true, nil
    if bag == BAG_FURNITURE_VAULT then
        if kind == "take" then
        elseif not ask(IsESOPlusSubscriber) then
            enabled, why = false, LF.gameWords(SI_FURNITURE_VAULT_ERROR_NEED_ESO_PLUS, L.house.vault_needs_plus)
        elseif chest == 0 or not ask(IsCollectibleUnlocked, chest) then
            enabled, why = false, LF.gameWords(SI_FURNITURE_VAULT_ERROR_NEED_COLLECTIBLE, L.house.vault_locked)
        end
    elseif chest ~= 0 and not ask(IsCollectibleUnlocked, chest) then
        enabled, why = false, zo_strformat(L.house.chest_locked, LF.clean(ask(GetCollectibleName, chest)) or "?")
    end
    return { bag = bag, name = name or LF.bagName(bag), used = used, total = total, enabled = enabled, why = why, chest = chest,
             unlocked = chest ~= 0 and ask(IsCollectibleUnlocked, chest) == true }
end
local function takeDefault()
    local out = {}
    for _, bag in ipairs(LF.bags) do
        if bag ~= BAG_SUBSCRIBER_BANK then out[#out + 1] = bag end
    end
    return out
end
local function putDefault()
    local out = { BAG_BACKPACK }
    for _, bag in ipairs(RETRIEVE_BAGS) do
        if bag ~= BAG_BACKPACK then out[#out + 1] = bag end
    end
    return out
end
local function settingsOf(kind)
    local all = type(LF.saved.settings) == "table" and LF.saved.settings or {}
    LF.saved.settings = all
    local kept = type(all[kind]) == "table" and all[kind] or {}
    all[kind] = kept
    local default = kind == "take" and takeDefault() or putDefault()
    local known, seen, order = {}, {}, {}
    for _, bag in ipairs(default) do known[bag] = true end
    if kind == "put" and tonumber(LF.saved.retrieveTo) then
        kept.order = { tonumber(LF.saved.retrieveTo), unpack(type(kept.order) == "table" and kept.order or default) }
        LF.saved.retrieveTo = nil
    end
    for _, bag in ipairs(type(kept.order) == "table" and kept.order or {}) do
        bag = tonumber(bag)
        if bag and known[bag] and not seen[bag] then
            seen[bag] = true
            order[#order + 1] = bag
        end
    end
    for _, bag in ipairs(default) do
        if not seen[bag] then order[#order + 1] = bag end
    end
    kept.order = order
    kept.off = type(kept.off) == "table" and kept.off or {}
    return kept
end
local function furnishingsIn(bag)
    local n = 0
    for _, b in ipairs(bag == BAG_BANK and { BAG_BANK, BAG_SUBSCRIBER_BANK } or { bag }) do
        for slot = 0, (b and ask(GetBagSize, b) or 0) - 1 do
            local id = ask(GetItemId, b, slot)
            if id and id ~= 0 and ask(IsItemPlaceableFurniture, b, slot) ~= false then n = n + (ask(GetSlotStackSize, b, slot) or 1) end
        end
    end
    return n
end
function LF.places(kind, counted)
    local kept, out, named = settingsOf(kind), {}, {}
    for _, bag in ipairs(kept.order) do
        local place = retrieveBag(bag, kind)
        if not ask(IsHouseBankBag, bag) or place.unlocked then
            place.on = not kept.off[tostring(bag)]
            if counted and kind == "take" then place.count = furnishingsIn(bag) end
            out[#out + 1] = place
            named[place.name] = (named[place.name] or 0) + 1
        end
    end
    for _, place in ipairs(out) do
        if named[place.name] > 1 and ask(IsHouseBankBag, place.bag) and BAG_HOUSE_BANK_ONE then
            place.name = zo_strformat(L.house.chest_numbered, place.name, place.bag - BAG_HOUSE_BANK_ONE + 1)
        end
    end
    return out
end
function LF.togglePlace(kind, bag, on)
    settingsOf(kind).off[tostring(bag)] = (not on) or nil
end
function LF.movePlace(kind, bag, delta)
    local visible = LF.places(kind)
    local neighbor
    for i, place in ipairs(visible) do
        if place.bag == bag and visible[i + delta] then neighbor = visible[i + delta].bag end
    end
    if not neighbor then return end
    local order = settingsOf(kind).order
    for i, b in ipairs(order) do
        if b == bag then order[i] = neighbor elseif b == neighbor then order[i] = bag end
    end
end
function LF.resetPlaces()
    LF.saved.settings = nil
end
function LF.takeBags()
    local out = {}
    for _, place in ipairs(LF.places("take")) do
        if place.on and place.enabled then
            out[#out + 1] = place.bag
            if place.bag == BAG_BANK and BAG_SUBSCRIBER_BANK then out[#out + 1] = BAG_SUBSCRIBER_BANK end
        end
    end
    return out
end
local function removalOrder()
    local out = {}
    for _, place in ipairs(LF.places("put")) do
        if place.on and place.enabled then out[#out + 1] = place end
    end
    return out
end
LF.removalOrder = removalOrder
local function reasons(kind)
    local lines = {}
    for _, place in ipairs(LF.places(kind)) do
        local line
        if not place.on then
            line = zo_strformat(L.house.place_off, place.name)
        elseif not place.enabled then
            line = zo_strformat(L.house.place_unavailable, place.name, place.why or "")
        elseif kind == "put" and (tonumber(place.total) or 0) <= 0 then
            line = zo_strformat(L.house.place_no_slots, place.name)
        elseif kind == "put" then
            line = zo_strformat(L.house.place_full, place.name, place.used, place.total)
        else
            line = zo_strformat(L.house.place_none, place.name)
        end
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n")
end
local function problem(kind, title, text)
    say(text)
    if LF.showProblem then LF.showProblem(kind, title, text .. "\n\n" .. reasons(kind)) end
end
function LF.notPutAway(q, step, why)
    local tried, lines = {}, {}
    for _, t in ipairs(step.tried or {}) do tried[t.bag] = t.why end
    if why then
        lines[1] = zo_strformat(L.house.place_refused, L.house.collection, why)
    else
        for _, place in ipairs(LF.places("put")) do
            local line
            if tried[place.bag] then
                line = zo_strformat(L.house.place_refused, place.name, tried[place.bag])
            elseif not place.on then
                line = zo_strformat(L.house.place_off, place.name)
            elseif not place.enabled then
                line = zo_strformat(L.house.place_unavailable, place.name, place.why or "")
            elseif (tonumber(place.total) or 0) <= 0 then
                line = zo_strformat(L.house.place_no_slots, place.name)
            else
                line = zo_strformat(L.house.place_full, place.name, place.used, place.total)
            end
            lines[#lines + 1] = line
        end
    end
    q.skipped = q.skipped or {}
    q.skipped[#q.skipped + 1] = { name = clean(ask(GetPlacedHousingFurnitureInfo, step.id)) or tostring(step.id), why = table.concat(lines, "\n") }
    LF.trace(q, "not_put_away", step, { places = table.concat(lines, "; ") })
    return { result = LF.SKIPPED }
end
local SKIPPED_SHOWN = 12
function LF.notPutAwayProblem(skipped)
    local groups, order = {}, {}
    for _, s in ipairs(skipped) do
        local g = groups[s.why]
        if not g then
            g = { why = s.why, names = {}, counts = {} }
            groups[s.why] = g
            order[#order + 1] = g
        end
        if not g.counts[s.name] then g.names[#g.names + 1] = s.name end
        g.counts[s.name] = (g.counts[s.name] or 0) + 1
    end
    local parts, shown = {}, 0
    for _, g in ipairs(order) do
        local names = {}
        for _, name in ipairs(g.names) do
            if shown < SKIPPED_SHOWN then
                names[#names + 1] = g.counts[name] > 1 and zo_strformat(L.house.name_times, name, g.counts[name]) or name
            end
            shown = shown + 1
        end
        if #names > 0 then parts[#parts + 1] = zo_strformat(L.house.not_put_away_for, list(unpack(names))) .. "\n" .. g.why end
    end
    if shown > SKIPPED_SHOWN then parts[#parts + 1] = count(L.house.and_more, shown - SKIPPED_SHOWN) end
    local text = count(L.house.not_put_away, #skipped)
    say(text)
    if LF.showProblem then LF.showProblem("put", L.house.not_put_away_title, text .. "\n\n" .. table.concat(parts, "\n\n")) end
end
function LF.takeProblem(left, name)
    problem("take", L.house.nothing_title, count(L.house.nothing_to_take, left, name or "?"))
end
local function setRetrieve(bag)
    local current = ask(HousingEditorGetRetrieveToBag)
    if R.original == nil then R.original = current end
    R.restoreAt = nil
    if current ~= bag then HousingEditorSetRetrieveToBag(bag) end
end
function LF.removalBag(q, tried)
    R.sentTo, R.usedAt = R.sentTo or {}, R.usedAt or {}
    local refused_ = {}
    for _, t in ipairs(tried or {}) do refused_[t.bag] = true end
    for _, b in ipairs(removalOrder()) do
        R.usedAt[b.bag] = R.usedAt[b.bag] or b.used
        local used = math.max(b.used, R.usedAt[b.bag] + (R.sentTo[b.bag] or 0))
        if used < b.total and not refused_[b.bag] then
            setRetrieve(b.bag)
            return b.bag
        end
    end
    return nil
end
function LF.removalAccepted(bag)
    R.sentTo[bag] = (R.sentTo[bag] or 0) + 1
end
function LF.removalRefused(bag)
    if bag and R.sentTo and (R.sentTo[bag] or 0) > 0 then R.sentTo[bag] = R.sentTo[bag] - 1 end
end
function LF.restoreRetrieve()
    if R.original == nil then return end
    local at = (R.restoreAt or 0) + 1
    R.restoreAt = at
    zo_callLater(function()
        if R.restoreAt ~= at or LF.queue or R.original == nil then return end
        if ask(HousingEditorGetRetrieveToBag) ~= R.original then HousingEditorSetRetrieveToBag(R.original) end
        R.original, R.restoreAt, R.sentTo, R.usedAt = nil, nil, nil, nil
    end, RESTORE_WAIT)
end
function LF.intoText(q)
    local parts = {}
    for _, bag in ipairs(RETRIEVE_BAGS) do
        local n = q.into and q.into[bag]
        if n and n > 0 then parts[#parts + 1] = zo_strformat(L.house.into, n, retrieveBag(bag).name) end
    end
    if #parts == 0 then return nil end
    return zo_strformat(L.house.removed_into, list(unpack(parts)))
end
local CONFORM_WAIT = 300
function LF.conform(id, want, done)
    local finish = done
    done = function(value)
        zo_callLater(function() LF.selecting = nil end, CONFORM_WAIT)
        finish(value)
    end
    LF.selecting = true
    inEditor(function()
        ask(HousingEditorSetPlacementType, HOUSING_EDITOR_PLACEMENT_TYPE_PRECISION)
        local ok, result = pcall(HousingEditorSelectPathNodeByIndex, id, 1)
        if not ok or result ~= HOUSING_REQUEST_RESULT_SUCCESS then return done(nil) end
        zo_callLater(function()
            ask(HousingEditorRequestModeChange, HOUSING_EDITOR_MODE_PATH)
            zo_callLater(function()
                local now = ask(HousingEditorGetSelectedFurniturePathConformToGround)
                if want ~= nil and now ~= nil and now ~= want then ask(HousingEditorToggleSelectedFurniturePathConformToGround) end
                zo_callLater(function()
                    local after = ask(HousingEditorGetSelectedFurniturePathConformToGround)
                    ask(HousingEditorRequestModeChange, HOUSING_EDITOR_MODE_SELECTION)
                    if type(after) == "boolean" then done(after) else done(nil) end
                end, CONFORM_WAIT)
            end, CONFORM_WAIT)
        end, CONFORM_WAIT)
    end)
end
function LF.readConforms(layout, done)
    done = done or function() end
    if LF.editRefused() then return done() end
    local ids = type(layout.private) == "table" and layout.private.game_ids or {}
    local walkers = {}
    for _, item in ipairs(layout.items or {}) do
        local path = item.path
        if type(path) == "table" and type(path.nodes) == "table" and #path.nodes > 0 and ids[item.uid] then walkers[#walkers + 1] = item end
    end
    local i = 0
    local function nextOne()
        i = i + 1
        local item = walkers[i]
        if not item or LF.queue then return done() end
        local id = LF.placedIds()[ids[item.uid]]
        if not id then return nextOne() end
        LF.conform(id, nil, function(value)
            item.path.conform_to_ground = value
            nextOne()
        end)
    end
    nextOne()
end
function LF.editRefused()
    if GetCurrentZoneHouseId() == 0 then return L.core.no_house end
    if not IsOwnerOfCurrentHouse() and not ask(HasAnyEditingPermissionsForCurrentHouse) then return L.house.not_owner end
    if LF.queue then return L.house.busy end
    return nil
end
function LF.editInPlace(id)
    local why = LF.editRefused()
    if why then
        say(why)
        return false
    end
    inEditor(function()
        ask(HousingEditorSetPlacementType, HOUSING_EDITOR_PLACEMENT_TYPE_PRECISION)
        local ok, result = pcall(HousingEditorSelectFurnitureById, id)
        if ok then
            ask(ZO_AlertEvent, EVENT_HOUSING_EDITOR_REQUEST_RESULT, result)
        else
            say(zo_strformat(L.house.refused, tostring(ask(GetPlacedHousingFurnitureInfo, id) or id), tostring(result)))
        end
    end)
    return true
end
function LF.waypoint(id)
    local ok = pcall(function() SHARED_FURNITURE:SetPlayerWaypointTo(SHARED_FURNITURE:CreatePlacedFurnitureData(id)) end)
    if not ok then
        ask(SetHousingEditorTrackedFurnitureId, id)
        local x, y, z = ask(HousingEditorGetFurnitureWorldPosition, id)
        if x then ask(SetPlayerWaypointByWorldLocation, x, y, z) end
    end
end
local function houseKey()
    return string.format("%d %s", GetCurrentZoneHouseId(), tostring(ask(GetCurrentHouseOwner)))
end
LF.houseKey = houseKey
local function stamp(seconds)
    return ask(os.date, "%Y-%m-%d %H:%M", seconds) or tostring(seconds)
end
LF.stamp = stamp
function LF.backups(kept)
    local all = LF.saved.backups or {}
    if kept then
        LF.saved.backups = all
        all[houseKey()] = all[houseKey()] or {}
    end
    return all[houseKey()] or {}
end
local function reasonOf(backup)
    local source = LF.tab(LF.tab(backup.private).source)
    return source.reason, source.layout
end
LF.reasonOf = reasonOf
function LF.backupKind(backup)
    return reasonOf(backup) == "hand" and "hand" or "auto"
end
function LF.backupLimit(kind)
    local limits = LF.saved.backupLimits
    local value = type(limits) == "table" and tonumber(limits[kind])
    return value and value >= 1 and value < math.huge and math.min(math.floor(value), MOST_BACKUPS) or DEFAULT_BACKUP_LIMIT
end
function LF.setBackupLimit(kind, value)
    if (kind ~= "hand" and kind ~= "auto") or type(value) ~= "number" or not (value >= 1 and value < math.huge) then return end
    if type(LF.saved.backupLimits) ~= "table" then LF.saved.backupLimits = {} end
    LF.saved.backupLimits[kind] = math.min(math.floor(value), MOST_BACKUPS)
end
function LF.backupName(backup)
    local created = LF.tab(backup.private).created
    return type(created) == "number" and stamp(created) or tostring(LF.tab(backup.meta).name)
end
local function overflow(list, kind)
    local limit, n, lost = LF.backupLimit(kind), 0, {}
    for _, backup in ipairs(list) do
        if LF.backupKind(backup) == kind then
            n = n + 1
            if n >= limit then lost[#lost + 1] = backup end
        end
    end
    return lost
end
function LF.requestManualBackup(done)
    local house = houseKey()
    local function make(approved)
        if house ~= houseKey() then return end
        local lost = overflow(LF.backups(), "hand")
        if #lost > 0 and not unrecordable() then
            if not approved then
                LF.confirmManualBackup(#lost, LF.backupName(lost[#lost]), function() make(lost) end)
                return
            end
            for i, backup in ipairs(lost) do
                if approved[i] ~= backup or #lost ~= #approved then
                    zo_callLater(function() make() end, 0)
                    return
                end
            end
        end
        if LF.backup("hand") and done then done() end
    end
    make()
end
local function keepBackup(layout, reason, layoutName)
    layout.private.source = { kind = "backup", addon_version = LF.version, reason = reason, layout = layoutName }
    layout.catalog = nil
    local list = LF.backups(true)
    local kind = LF.backupKind(layout)
    local limit = LF.backupLimit(kind)
    local lost = overflow(list, kind)
    local n = #lost
    for i = #list, 1, -1 do
        if n == 0 then break end
        if list[i] == lost[n] then
            table.remove(list, i)
            n = n - 1
        end
    end
    table.insert(list, 1, layout)
    LF.guarded = houseKey()
    if reason == "hand" then
        local pushed = #lost > 0 and count(L.house.pushed_out, limit, LF.backupName(lost[#lost])) or nil
        say(sentences(count(L.house.backed_up, #layout.items, layout.meta.name), pushed))
    end
    return layout
end
function LF.backup(reason, layoutName)
    local layout, why = record(zo_strformat(L.house.backup_name, stamp(GetTimeStamp())))
    if not layout then
        if reason == "hand" then
            say(why)
            LF.alert(why)
        end
        return nil
    end
    return keepBackup(layout, reason, layoutName)
end
function LF.emptyHouse(house, steps)
    if LF.houseKey() ~= house or #steps == 0 then return end
    local why = refused()
    if why then say(why) return end
    local layout, problem = record(zo_strformat(L.house.backup_name, stamp(GetTimeStamp())))
    if not layout then say(problem) return end
    LF.afterPaths(layout, function(skipped)
        if LF.houseKey() ~= house or refused() then return end
        if #skipped > 0 then
            local message = zo_strformat(L.window.empty_path_failed, table.concat(skipped, ", "))
            say(message)
            LF.alert(message)
            return
        end
        keepBackup(layout, "change", L.window.empty_house)
        startRemovals(L.window.empty_house, steps, true)
    end)
end
function LF.guard(reason, layoutName)
    if LF.guarded ~= houseKey() then LF.backup(reason, layoutName) end
end
function LF.forgetBackup(backup)
    local list = LF.backups()
    for i = #list, 1, -1 do
        if list[i] == backup then table.remove(list, i) end
    end
    say(zo_strformat(L.house.backup_deleted, LF.backupName(backup)))
end
local function asLayout(backup)
    return LF.asLayout(backup, backup.meta.name)
end
local function rollbackBlocks(diff, removing, lost)
    local blocks = {}
    if #lost > 0 then
        local names = {}
        for i, task in ipairs(lost) do
            if i <= 3 then names[#names + 1] = tostring(task.name or "?") end
        end
        if #lost > 3 then names[#names + 1] = count(L.house.more_furnishings, #lost - 3) end
        blocks[#blocks + 1] = count(L.house.blocked_missing, #lost, list(unpack(names)))
    end
    local needed, free = 0, 0
    for _, task in ipairs(removing) do
        if not string.find(LF.whatIs(task.id), "^collectible:") then needed = needed + 1 end
    end
    for _, place in ipairs(LF.removalOrder()) do free = free + math.max(0, (tonumber(place.total) or 0) - (tonumber(place.used) or 0)) end
    if needed > free then blocks[#blocks + 1] = count(L.house.blocked_room, needed, free) end
    for _, slot in ipairs(diff.slots or {}) do
        local would = slot.placed - slot.freeing + slot.adding
        if slot.most > 0 and slot.adding > 0 and would > slot.most then
            blocks[#blocks + 1] = zo_strformat(L.house.blocked_limit, slot.name, would, slot.most)
        end
    end
    return blocks
end
function LF.rollbackPlan(n)
    local why = refused()
    local backup = not why and n and LF.backups()[n]
    if why or not backup then
        return nil, why or L.house.no_backup
    end
    local ok, diff = pcall(LF.diff, asLayout(backup), true)
    if not ok then return nil, zo_strformat(L.house.backup_unreadable, tostring(diff)) end
    local removing, steps, lost = {}, {}, {}
    for _, task in ipairs(diff.tasks) do
        if task.action == "remove" then
            removing[#removing + 1] = task
        elseif task.missing then
            lost[#lost + 1] = task
        elseif task.action ~= "conform" and not task.blocked then
            steps[#steps + 1] = stepOf(task)
        end
    end
    local summary = list(LF.some(L.house.to_remove, #removing), LF.some(L.house.to_restore, #steps), LF.some(L.house.no_longer_found, #lost))
    local blocks = rollbackBlocks(diff, removing, lost)
    for i, task in ipairs(removing) do table.insert(steps, i, task) end
    return { backup = backup, steps = steps, summary = summary, missing = #lost, blocks = blocks }
end
function LF.blockedText(plan)
    return zo_strformat(L.house.rollback_blocked, table.concat(plan.blocks, " "))
end
function LF.keepBackup(backup, name)
    local refusal
    name, refusal = LF.nameRefused(name)
    if refusal then return nil, refusal end
    local function copy(v)
        if type(v) ~= "table" then return v end
        local out = {}
        for k, x in pairs(v) do out[k] = copy(x) end
        return out
    end
    local layout = copy(backup)
    layout.id = LF.newId()
    layout.meta = { name = name }
    layout.private = layout.private or {}
    layout.private.created, layout.private.modified = GetTimeStamp(), GetTimeStamp()
    layout.private.source = { kind = "addon", addon_version = LF.version, backup = backup.meta and backup.meta.name }
    LF.saved.exports[name] = layout
    say(zo_strformat(L.house.backup_kept, name))
    return true
end
local function offerKeep(backup, said, reasons, partly)
    say(sentences(said, L.house.keep_hint))
    if LF.offerKeep then LF.offerKeep(backup, reasons, partly) end
end
LF.offerKeepBackup = offerKeep
function LF.rollback(n, confirmed)
    local plan, why = LF.rollbackPlan(n)
    if not plan then
        say(why)
        return false
    end
    local backup = plan.backup
    if #plan.blocks > 0 then
        offerKeep(backup, LF.blockedText(plan), table.concat(plan.blocks, " "))
        return false
    end
    if #plan.steps == 0 then
        say(L.house.already_as)
        return true
    end
    if not confirmed then
        say(zo_strformat(L.house.rollback_preview, backup.meta.name, count(L.window.furnishings, #backup.items), plan.summary, tostring(n or 1)))
        return true
    end
    LF.guard("rollback")
    local list, at = LF.backups(), nil
    for i, kept in ipairs(list) do
        if kept == backup then at = i end
    end
    LF.start(backup.meta.name, plan.steps, { items = {} })
    if not at then
        list[#list + 1] = backup
        at = #list
        LF.queue.onFinished = function()
            for i, kept in ipairs(list) do
                if kept == backup then table.remove(list, i) break end
            end
        end
    end
    LF.queue.rollback = at
    LF.queue.onEnded = function(q)
        if q.failed + q.absent + (q.unlinked or 0) + (q.skipped and #q.skipped or 0) > 0 then
            local text = zo_strformat(L.house.rollback_incomplete, backup.meta.name)
            offerKeep(backup, text, text, true)
        end
    end
    say(sentences(zo_strformat(L.house.rolling_back, plan.summary), L.core.stop_stops))
    return true
end
local CODE_UPDATE = "LetsFurnishCode"
local MAKE_SLICE, READ_SLICE = 1024, 32768
LF.CODE_MOST = 32000
local function houseName(houseId)
    return LF.nonempty(clean(ask(GetCollectibleName, ask(GetCollectibleIdForHouse, houseId)))) or zo_strformat(L.house.house, tostring(houseId))
end
LF.houseName = houseName
local function shareable(layout)
    layout.catalog, layout.private = nil, nil
    return layout
end
function LF.progress()
    local q = LF.queue
    if q then
        local words = (q.wholeHouse and L.window.empty_house) or (q.rollback and zo_strformat(L.house.rolling_back_to, q.name)) or (q.removing and zo_strformat(L.house.removing_from, q.name))
                      or zo_strformat(L.house.applying_layout, q.name)
        return { words = words, done = math.min(q.index, #q.steps), total = #q.steps, stop = function() SLASH_COMMANDS["/lf"]("stop") end }
    end
    local c = LF.coding
    if c then return { words = c.words, share = c.share, stop = LF.stopCode } end
    if LF.patternJob then return { words = L.needs.reading_patterns, share = LF.patternsShare(), stop = LF.stopPatterns } end
    return nil
end
local function runCode(job, slice, words, done, failed)
    EVENT_MANAGER:UnregisterForUpdate(CODE_UPDATE)
    LF.coding = { words = words, share = 0, failed = failed }
    EVENT_MANAGER:RegisterForUpdate(CODE_UPDATE, 0, function()
        local ok, finished, result = pcall(job, slice)
        if ok and finished == false then
            LF.coding.share = result or 0
            if LF.onProgress then LF.onProgress() end
            return
        end
        EVENT_MANAGER:UnregisterForUpdate(CODE_UPDATE)
        LF.coding = nil
        if ok and finished then done(result) else failed(tostring(ok and result or finished)) end
        if LF.onProgress then LF.onProgress() end
    end)
end
function LF.stopCode()
    if not LF.coding then return false end
    EVENT_MANAGER:UnregisterForUpdate(CODE_UPDATE)
    local failed = LF.coding.failed
    LF.coding = nil
    failed(L.house.code_stopped)
    if LF.onProgress then LF.onProgress() end
    return true
end
function LF.share(name, tell, shown)
    local function told(text)
        say(text)
        tell(text)
    end
    name = LF.nonempty(name) or houseName(GetCurrentZoneHouseId())
    local layout, why = record(name)
    if not layout then
        told(why)
        LF.alert(why)
        return false
    end
    local function encode()
        layout = shareable(layout)
        local ok, job = pcall(LF.code.encoder, layout)
        if not ok then return told(zo_strformat(L.house.no_code, tostring(job))) end
        runCode(job, MAKE_SLICE, zo_strformat(L.house.making_code, name), function(text)
            local parts = LF.code.split(text)
            local copied = pcall(function() CopyToClipboard(parts[1]) end)
            local made = zo_strformat(L.house.code_made, name, list(count(L.window.furnishings, #layout.items), count(L.house.characters, #text)))
            if #parts > 1 then
                told(sentences(made, count(L.house.in_parts, #parts, LF.CODE_MOST), copied and L.house.part_on_clipboard or L.house.part_by_hand))
            else
                told(sentences(made, copied and L.house.on_clipboard or L.house.copy_by_hand))
            end
            shown(parts)
        end, function(why) told(zo_strformat(L.house.no_code, why)) end)
    end
    LF.afterPaths(layout, function() LF.readConforms(layout, encode) end)
    return true
end
local function asReceived(layout)
    local major = tonumber(string.match(tostring(layout.version), "^(%d+)%."))
    if layout.format ~= LF.HOUSE_FORMAT or not major then return nil, L.house.no_house_named end
    if major < 2 then return nil, L.house.code_earlier end
    layout.meta = LF.tab(layout.meta)
    layout.meta.name = LF.nonempty(type(layout.meta.name) == "string" and layout.meta.name or "") or L.house.shared_layout
    layout.private = { created = GetTimeStamp(), source = { kind = "code" } }
    layout.catalog = nil
    layout.id = tostring(layout.id or layout.meta.name)
    return layout
end
function LF.heldParts()
    local held = LF.saved.parts
    if type(held) ~= "table" or type(held.bodies) ~= "table" or type(held.n) ~= "number" then return nil end
    return held
end
local function partsState(held)
    local have, missing = 0, {}
    for k = 1, held.n do
        if held.bodies[k] then have = have + 1 else missing[#missing + 1] = tostring(k) end
    end
    return have, missing
end
local function numbers(all)
    if #all < 2 then return all[1] or "" end
    return zo_strformat(L.core.and_last, list(unpack(all, 1, #all - 1)), all[#all])
end
function LF.partsText()
    local held = LF.heldParts()
    if not held then return nil end
    local have, missing = partsState(held)
    local present = {}
    for k = 1, held.n do
        if held.bodies[k] then present[#present + 1] = tostring(k) end
    end
    local next_ = #missing == 1 and zo_strformat(L.house.part_last_next, missing[1]) or zo_strformat(L.house.parts_next, numbers(missing))
    local now = have == 1 and zo_strformat(L.house.part_have, present[1], held.n) or zo_strformat(L.house.parts_have, numbers(present), held.n)
    return sentences(now, next_)
end
function LF.forgetParts()
    if LF.heldParts() then
        LF.saved.parts = nil
        say(L.house.parts_forgotten)
    end
end
local function takeParts(text, told)
    local fresh, refusals = nil, {}
    for _, read in ipairs(LF.code.parts(text)) do
        local part = read.part
        if not part then
            refusals[#refusals + 1] = read.why
        else
            fresh = fresh or { id = part.id, n = part.n, bodies = {} }
            if part.id == fresh.id and part.n == fresh.n then fresh.bodies[part.k] = part.body else refusals[#refusals + 1] = L.code.parts_mixed end
        end
    end
    local held = LF.heldParts()
    if fresh and partsState(fresh) == fresh.n then
        held = fresh
    elseif fresh and held and (held.id ~= fresh.id or held.n ~= fresh.n) then
        local have = partsState(held)
        refusals[#refusals + 1] = zo_strformat(L.house.part_other, have, held.n)
        fresh = nil
    elseif fresh then
        held = held or { id = fresh.id, n = fresh.n, bodies = {} }
        for k, body in pairs(fresh.bodies) do held.bodies[k] = body end
        LF.saved.parts = held
    end
    local said = {}
    for _, why in ipairs(refusals) do said[#said + 1] = zo_strformat(L.house.not_read, why) end
    if not held or not fresh then
        told(sentences(unpack(said)) ~= "" and sentences(unpack(said)) or zo_strformat(L.house.not_read, L.code.part_unreadable))
        return nil
    end
    local have = partsState(held)
    if have < held.n then
        told(sentences(LF.partsText(), unpack(said)))
        return nil, true
    end
    local kept = LF.heldParts()
    if kept and kept.id == held.id then LF.saved.parts = nil end
    local joined, why = LF.code.join(held)
    if not joined then
        told(sentences(zo_strformat(L.house.not_read, why), L.house.parts_forgotten))
        return nil
    end
    return joined
end
function LF.paste(text, tell, done)
    local function told(said)
        say(said)
        tell(said)
    end
    if LF.code.isParts(text) then
        local took
        text, took = takeParts(text, told)
        if not text then return false, took end
    end
    runCode(LF.code.decoder(text), READ_SLICE, L.house.reading_code, function(layout)
        local row, why = asReceived(layout)
        local view = row and LF.view(row)
        if not row or type(view.house_id) ~= "number" then
            told(why or L.house.no_house_named)
            return
        end
        local list = LF.saved.pasted or {}
        LF.saved.pasted = list
        for i = #list, 1, -1 do
            if list[i].id == row.id then table.remove(list, i) end
        end
        table.insert(list, 1, row)
        told(sentences(zo_strformat(L.house.received, view.name, houseName(view.house_id), count(L.window.furnishings, LF.furnishings(view.items))),
            view.house_id == GetCurrentZoneHouseId() and L.house.chosen_here or L.house.go_there))
        zo_callLater(function() done(row) end, 0)
    end, function(why) told(zo_strformat(L.house.not_read, why)) end)
    return true
end
function LF.onLoaded()
    EVENT_MANAGER:RegisterForEvent(LF.name .. "House", EVENT_PLAYER_ACTIVATED, function() LF.guarded = nil end)
    if LF.onLoadedWindow then LF.onLoadedWindow() end
end
