LetsFurnish = { name = "LetsFurnish", version = "0.6.3", build = 603, release = true, delay = 250 }
local LF = LetsFurnish
local IsOwnerOfCurrentHouse, GetHousingVisitorRole, GetCurrentZoneHouseId = IsOwnerOfCurrentHouse, GetHousingVisitorRole, GetCurrentZoneHouseId
local GetCurrentHouseOwner, GetDisplayName = GetCurrentHouseOwner, GetDisplayName
local VISITOR_ROLE_PREVIEW = HOUSING_VISITOR_ROLE_PREVIEW
local L = LetsFurnish_L
LF.L = L
local HOUSE_FORMAT, INBOX_FORMAT = "letsfurnish.house", "letsfurnish.inbox"
local FORMAT_VERSION, SCHEMA = "2.0", "2.0"
local FORMAT_MAJOR = 2
local SCHEMA_MAJOR = 2
local SAVED_VARS_VERSION = 1
local UPDATE_NAME = "LetsFurnishApply"
local PLACED, REQUESTED, MOVED, SWITCHED, REMOVED, FAILED, ABSENT, UNAVAILABLE, ERROR, UNCONFIRMED, FULL, PATHED, SKIPPED, LINKED =
    "placed", "requested", "moved", "switched", "removed", "failed", "absent", "unavailable", "error", "unconfirmed", "full", "pathed", "skipped",
    "linked"
local WAIT_TICKS = 8
local ANSWER_MS = 2000
local SPEEDS = { 100, 250, 500, 1000 }
local STREAK_STOP = 5
local RETRY_MS = 1500
local PATH_REREAD_MS = 1500
local PATH_ON = HOUSING_FURNITURE_PATH_STATE_ON or 1
local PATH_OFF = HOUSING_FURNITURE_PATH_STATE_OFF or 0
local pathEvents = {
    insert = EVENT_HOUSING_FURNITURE_PATH_NODE_ADDED, modify = EVENT_HOUSING_FURNITURE_PATH_NODE_MOVED,
    remove = EVENT_HOUSING_FURNITURE_PATH_NODE_REMOVED, pathdata = EVENT_HOUSING_FURNITURE_PATH_DATA_CHANGED,
    pathstart = EVENT_HOUSING_FURNITURE_PATH_STARTING_NODE_INDEX_CHANGED,
}
local ANSWER_SECONDS = 30
local NAME_MOST = 64
local TWO_PI = 2 * math.pi
local SAME_ANGLE = 1e-4
local function stepDelay()
    local chosen = tonumber(LF.saved and LF.saved.speed)
    for _, ms in ipairs(SPEEDS) do
        if ms == chosen then return ms end
    end
    return LF.delay
end
local function waitTicks()
    return math.max(WAIT_TICKS, math.ceil(ANSWER_MS / stepDelay()))
end
LF.waiting = {}
local function say(text)
    CHAT_ROUTER:AddSystemMessage("|c9fd4ffLetsFurnish!|r " .. text)
end
local PLURALS = {
    one = function(n) return n == 1 and "one" or "other" end,
    fr = function(n) return (n == 0 or n == 1) and "one" or "other" end,
    ru = function(n)
        local last, two = n % 10, n % 100
        if last == 1 and two ~= 11 then return "one" end
        if last >= 2 and last <= 4 and not (two >= 12 and two <= 14) then return "few" end
        return "many"
    end,
    none = function() return "other" end,
}
local function count(forms, n, ...)
    local rule = PLURALS[L._plural] or PLURALS.one
    return zo_strformat(forms[rule(math.abs(math.floor(n)))] or forms.other, n, ...)
end
local function joined(two, ...)
    local out
    for i = 1, select("#", ...) do
        local part = select(i, ...)
        if part and part ~= "" then out = out and zo_strformat(two, out, part) or part end
    end
    return out or ""
end
local function sentences(...) return joined(L.core.sentences, ...) end
local function list(...) return joined(L.core.list, ...) end
local function some(forms, n, ...)
    if not n or n == 0 then return nil end
    return count(forms, n, ...)
end
local function counted(...)
    local text = list(...)
    return text ~= "" and text or L.core.nothing_to_do
end
local function passed(ok, ...)
    if ok then return ... end
    return nil
end
local function ask(fn, ...)
    if not fn then return nil end
    return passed(pcall(fn, ...))
end
local function alert(text)
    ask(ZO_Alert, UI_ALERT_CATEGORY_ERROR, SOUNDS and SOUNDS.GENERAL_ALERT_ERROR, text)
end
local function nonempty(v)
    if v == "" or v == 0 then return nil end
    return v
end
local function now()
    local t = ask(GetTimeStamp)
    if type(t) == "number" then return t end
    return nil
end
local function majorMinor(text)
    local major, minor = string.match(tostring(text or ""), "^%s*(%d+)%.(%d+)%s*$")
    if major then return tonumber(major), tonumber(minor) end
    return nil
end
local function mix(text, salt)
    local h = 5381 + salt
    for i = 1, #text do h = (h * 33 + string.byte(text, i)) % 4294967296 end
    return h
end
local function newId()
    local saved = LF.saved or {}
    saved.idCount = (tonumber(saved.idCount) or 0) + 1
    local seed = table.concat({ tostring(ask(GetDisplayName) or ""), tostring(ask(GetTimeStamp) or 0), tostring(ask(GetGameTimeMilliseconds) or 0),
                                tostring(saved.idCount), tostring(math.random()) }, ":")
    local parts = {}
    for k = 1, 4 do parts[k] = string.format("%08x", (mix(seed, k * 7919) + math.random(0, 65535)) % 4294967296) end
    local s = table.concat(parts)
    local variant = string.sub("89ab", (mix(seed, 31) % 4) + 1, (mix(seed, 31) % 4) + 1)
    return string.format("%s-%s-4%s-%s%s-%s", s:sub(1, 8), s:sub(9, 12), s:sub(14, 16), variant, s:sub(18, 20), s:sub(21, 32))
end
local function writerBlock()
    return { app = "LetsFurnish addon", version = LF.version, build = LF.build, game_api = ask(GetAPIVersion) }
end
local function recordPath(id)
    local count = ask(HousingEditorGetNumPathNodesForFurniture, id)
    if not count or count == 0 then return nil end
    local nodes = {}
    for i = 1, count do
        local x, y, z = ask(HousingEditorGetPathNodeWorldPosition, id, i)
        if not (x and y and z) or (x == 0 and y == 0 and z == 0) then return nil, true end
        local pitch, yaw, roll = ask(HousingEditorGetPathNodeOrientation, id, i)
        nodes[i] = {
            position = { x or 0, y or 0, z or 0 },
            yaw = yaw or 0,
            pitch = pitch ~= 0 and pitch or nil,
            roll = roll ~= 0 and roll or nil,
            speed = ask(HousingEditorPathNodeSpeed, id, i),
            delay = ask(HousingEditorPathNodeDelayTime, id, i),
        }
    end
    local start = ask(HousingEditorGetStartingNodeIndexForPath, id)
    return {
        state = ask(HousingEditorGetFurniturePathState, id),
        follow_type = ask(HousingEditorGetFurniturePathFollowType, id),
        start = type(start) == "number" and start > 1 and start - 1 or nil,
        nodes = nodes,
    }
end
LF.recordPath = recordPath
local function recordState(id)
    local count = ask(GetPlacedHousingFurnitureNumObjectStates, id)
    if not count or count == 0 then return nil, nil end
    local index = ask(GetPlacedHousingFurnitureCurrentObjectStateIndex, id) or 0
    local names = {}
    for i = 1, count do names[i] = nonempty(ask(GetPlacedFurniturePreviewVariationDisplayName, id, i)) or "" end
    return index, names
end
local function identity(link)
    local kind, id = string.match(link or "", "^|H%d+:(%a+):(%d+)")
    if id then return kind, tonumber(id) end
    return "item", 0
end
local function recordItem(id, n, things)
    local x, y, z = HousingEditorGetFurnitureWorldPosition(id)
    local pitch, yaw, roll = HousingEditorGetFurnitureOrientation(id)
    local itemLink, collectibleLink = ask(GetPlacedFurnitureLink, id, LINK_STYLE_BRACKETS)
    local link = nonempty(itemLink) or collectibleLink
    local kind, itemId = identity(link)
    local key = kind .. ":" .. tostring(itemId)
    local parent = ask(GetPlacedFurnitureParent, id)
    local stateIndex, stateNames = recordState(id)
    local path, unread = recordPath(id)
    local item = {
        uid = "r-" .. n,
        item_id = itemId,
        kind = kind,
        position = { x, y, z },
        rotation = { pitch, yaw, roll },
        state = stateIndex,
        path = path,
    }
    if things[key] then return item, Id64ToString(id), parent and Id64ToString(parent) or nil, key, nil, unread end
    local name, icon, dataId = ask(GetPlacedHousingFurnitureInfo, id)
    local thing = {
        name = nonempty(name),
        icon = nonempty(icon),
        link = nonempty(link),
        states = stateNames,
    }
    local pathable = ask(HousingEditorCanFurnitureBePathed, id)
    if pathable ~= nil then thing.pathable = pathable and true or false end
    if dataId then
        local category, _, _, limitType = ask(GetFurnitureDataInfo, dataId)
        thing.category, thing.limit_type = category, limitType
    end
    return item, Id64ToString(id), parent and Id64ToString(parent) or nil, key, thing, unread
end
local function recordHouse(houseId)
    local collectibleId = ask(GetCollectibleIdForHouse, houseId)
    local limits = {}
    local first = HOUSING_FURNISHING_LIMIT_TYPE_ITERATION_BEGIN
    local last = HOUSING_FURNISHING_LIMIT_TYPE_ITERATION_END
    if first and last then
        for t = first, last do
            limits[tostring(t)] = ask(GetHouseFurnishingPlacementLimit, houseId, t)
        end
    end
    return { name = collectibleId and ask(GetCollectibleName, collectibleId) or nil, limits = limits },
           collectibleId and nonempty(ask(GetCollectibleNickname, collectibleId)) or nil
end
local function unrecordable()
    local houseId = GetCurrentZoneHouseId()
    if not houseId or houseId == 0 then return L.core.no_house end
    local preview = VISITOR_ROLE_PREVIEW ~= nil and ask(GetHousingVisitorRole) == VISITOR_ROLE_PREVIEW
    if preview or not ask(IsOwnerOfCurrentHouse) then
        return L.core.not_yours
    end
    return nil
end
local function record(name)
    local why = unrecordable()
    if why then return nil, why end
    local mine = ask(GetCurrentHouseOwner) == ask(GetDisplayName)
    if not mine then return nil, L.core.not_yours end
    local houseId = GetCurrentZoneHouseId()
    local items, ids, parents, things = {}, {}, {}, {}
    local uidOf, unread = {}, {}
    local id = GetNextPlacedHousingFurnitureId()
    while id do
        local item, gameId, parent, key, thing, notGiven = recordItem(id, #items + 1, things)
        items[#items + 1] = item
        if notGiven then unread[#unread + 1] = { item = item, id = id } end
        ids[item.uid], uidOf[gameId], parents[item] = gameId, item.uid, parent
        things[key] = things[key] or thing
        id = GetNextPlacedHousingFurnitureId(id)
    end
    for item, parent in pairs(parents) do item.parent = uidOf[parent] end
    local house, nickname = recordHouse(houseId)
    local now = GetTimeStamp()
    local layout = {
        format = HOUSE_FORMAT,
        version = FORMAT_VERSION,
        writer = writerBlock(),
        id = newId(),
        meta = { name = name },
        house = { house_id = houseId },
        items = items,
        catalog = { game_api = ask(GetAPIVersion), language = ask(GetCVar, "Language.2"), house = house, things = things },
        private = {
            created = now,
            modified = now,
            source = { kind = "addon", addon_version = LF.version },
            owner = ask(GetCurrentHouseOwner),
            game_ids = ids,
            house = { nickname = nickname },
            player = { account = ask(GetDisplayName), character = ask(GetUnitName, "player"), visitor_role = ask(GetHousingVisitorRole) },
        },
    }
    if #unread > 0 then LF.rereadPaths(layout, unread) end
    return layout
end
LF.pendingPaths = setmetatable({}, { __mode = "k" })
local function placedName(id)
    local ok, name = pcall(GetPlacedHousingFurnitureInfo, id)
    return ok and type(name) == "string" and name ~= "" and (string.gsub(name, "%^.*$", "")) or Id64ToString(id)
end
function LF.rereadPaths(layout, unread)
    LF.pendingPaths[layout] = {}
    zo_callLater(function()
        local skipped = {}
        for _, u in ipairs(unread) do
            local path, still = recordPath(u.id)
            if path and not still then u.item.path = path else skipped[#skipped + 1] = placedName(u.id) end
        end
        if #skipped > 0 then
            say(zo_strformat(L.core.path_unread_recorded, tostring(LF.tab(layout.meta).name or ""), list(unpack(skipped))))
        end
        local waiting = LF.pendingPaths[layout] or {}
        LF.pendingPaths[layout] = nil
        for _, go in ipairs(waiting) do go(skipped) end
    end, PATH_REREAD_MS)
end
function LF.afterPaths(layout, go)
    local waiting = LF.pendingPaths[layout]
    if waiting then waiting[#waiting + 1] = go else go({}) end
end
local function nameRefused(name, except)
    name = string.match(tostring(name or ""), "^%s*(.-)%s*$")
    if name == "" then return name, L.core.name_empty end
    local _, characters = string.gsub(name, "[^\128-\191]", "")
    if characters > NAME_MOST then return name, zo_strformat(L.core.name_long, NAME_MOST) end
    for _, entry in ipairs(LF.listed()) do
        if entry.name == name and not (except and entry.layout == except.layout) then return name, zo_strformat(L.core.name_used, name) end
    end
    return name, nil
end
local function export(name, quiet)
    if nonempty(name or "") == nil then
        say(L.core.export_usage)
        return false, L.core.export_usage
    end
    local why = unrecordable()
    local refusal
    name, refusal = nameRefused(name)
    if refusal and not why then
        if not quiet then say(refusal) end
        return false, refusal
    end
    local layout
    if not why then layout, why = record(name) end
    if not layout then
        say(why)
        alert(why)
        return false, why
    end
    LF.saved.exports[name] = layout
    say(count(L.core.recorded, #layout.items, name))
    if LF.readConforms then LF.readConforms(layout) end
    return true
end
local function inbox()
    local box = LetsFurnish_Inbox
    if type(box) ~= "table" or next(box) == nil then
        return nil, L.core.inbox_none
    end
    if box.format ~= INBOX_FORMAT then
        return nil, L.core.inbox_foreign
    end
    local major = majorMinor(box.version)
    if not major then
        return nil, zo_strformat(L.core.inbox_unknown, tostring(box.version))
    end
    local app = type(box.app) == "table" and box.app.version or "?"
    if major > FORMAT_MAJOR then
        return nil, zo_strformat(L.core.inbox_newer, tostring(box.version), tostring(app))
    end
    if type(box.min_addon) == "number" and box.min_addon > LF.build then
        return nil, zo_strformat(L.core.inbox_build, tostring(box.min_addon), tostring(app), tostring(LF.build), LF.version)
    end
    if type(box.layouts) ~= "table" then
        return nil, L.core.inbox_no_layouts
    end
    return box
end
local function tab(v)
    return type(v) == "table" and v or {}
end
local views = setmetatable({}, { __mode = "k" })
local rowsOf = setmetatable({}, { __mode = "k" })
local function view(layout, row)
    local v = views[layout] or {}
    views[layout] = v
    local meta, house, own, catalog = tab(layout.meta), tab(layout.house), tab(layout.private), tab(layout.catalog)
    local ids, things = tab(own.game_ids), tab(catalog.things)
    v.id, v.name, v.house_id, v.owner, v.layout = layout.id, meta.name, house.house_id, nonempty(own.owner or ""), layout
    if row then v.sent, v.digest = row.sent, row.digest end
    local source = type(layout.items) == "table" and layout.items or nil
    if v.source == source and v.count == (source and #source or 0) and v.ids == ids then return v end
    local items = {}
    for _, item in ipairs(source or {}) do
        local r = item
        if type(item) == "table" then
            r = rowsOf[item]
            if not r then
                r = {}
                for k, value in pairs(item) do r[k] = value end
                local thing = things[tostring(item.kind) .. ":" .. tostring(item.item_id)]
                r.link = type(thing) == "table" and nonempty(thing.link or "") or nil
                rowsOf[item] = r
            end
            r.game_id = item.uid ~= nil and ids[tostring(item.uid)] or nil
        end
        items[#items + 1] = r
    end
    v.items = source and items or nil
    v.source, v.count, v.ids = source, source and #source or 0, ids
    return v
end
local function findLayout(box, name)
    for _, row in ipairs(type(box) == "table" and type(box.layouts) == "table" and box.layouts or {}) do
        local v = type(row) == "table" and type(row.layout) == "table" and view(row.layout, row) or row
        if type(v) == "table" and v.name == name then return v end
    end
    return nil
end
local function furnishings(items)
    local n = 0
    for _, row in ipairs(items or {}) do
        if type(row) == "table" and (row.kind == "item" or row.kind == "collectible") then n = n + 1 end
    end
    return n
end
local function dismissed(layout)
    local mark = type(LF.saved.dismissed) == "table" and LF.saved.dismissed[tostring(layout.id)]
    return type(mark) == "number" and (tonumber(layout.sent) or 0) <= mark
end
local function received()
    local box, why = inbox()
    local all = {}
    for _, row in ipairs(box and box.layouts or {}) do
        if type(row) == "table" and type(row.layout) == "table" then
            local v = view(row.layout, row)
            if not dismissed(v) then all[#all + 1] = v end
        end
    end
    for _, layout in ipairs(LF.saved and LF.saved.pasted or {}) do
        if type(layout) == "table" then all[#all + 1] = view(layout) end
    end
    return { layouts = all }, why
end
local function asLayout(record, name)
    local v = view(record)
    v.name, v.recorded = name, true
    return v
end
local function listed()
    local box, why = inbox()
    local out = {}
    for _, row in ipairs(box and box.layouts or {}) do
        if type(row) == "table" and type(row.layout) == "table" then
            local v = view(row.layout, row)
            if not dismissed(v) then
                out[#out + 1] = { source = "app", layout = row, plan = v, name = tostring(v.name), house_id = v.house_id, count = furnishings(v.items) }
            end
        end
    end
    for _, layout in ipairs(LF.saved.pasted or {}) do
        if type(layout) == "table" then
            local v = view(layout)
            out[#out + 1] = { source = "code", layout = layout, plan = v, name = tostring(v.name), house_id = v.house_id, count = furnishings(v.items) }
        end
    end
    local keys = {}
    for key, record in pairs(LF.saved.exports) do
        if type(record) == "table" then keys[#keys + 1] = key end
    end
    local function created(key)
        return tonumber(tab(LF.saved.exports[key].private).created) or 0
    end
    table.sort(keys, function(a, b) return created(a) > created(b) or (created(a) == created(b) and tostring(a) < tostring(b)) end)
    for _, key in ipairs(keys) do
        local record = LF.saved.exports[key]
        out[#out + 1] = { source = "recorded", layout = record, plan = asLayout(record, tostring(key)), key = key, name = tostring(key),
                          count = furnishings(type(record.items) == "table" and record.items or nil),
                          house_id = tab(record.house).house_id }
    end
    return out, why
end
local function forgetLayout(entry)
    if entry.source == "app" then
        LF.saved.dismissed = type(LF.saved.dismissed) == "table" and LF.saved.dismissed or {}
        LF.saved.dismissed[tostring(entry.plan.id)] = tonumber(entry.plan.sent) or 0
        say(zo_strformat(L.core.hidden, entry.name))
        return
    elseif entry.source == "code" then
        local list = LF.saved.pasted or {}
        for i = #list, 1, -1 do
            if list[i] == entry.layout then table.remove(list, i) end
        end
    elseif LF.saved.exports[entry.key] == entry.layout then
        LF.saved.exports[entry.key] = nil
    end
    say(zo_strformat(L.core.deleted, entry.name))
end
local function rename(entry, wanted)
    if entry.source == "app" then return nil, L.core.rename_app end
    local name, refusal = nameRefused(wanted, entry)
    if refusal then return nil, refusal end
    if name == entry.name then return true end
    if entry.source == "code" then
        entry.layout.meta = tab(entry.layout.meta)
        entry.layout.meta.name = name
    elseif LF.saved.exports[entry.key] == entry.layout then
        LF.saved.exports[entry.key] = nil
        LF.saved.exports[name] = entry.layout
        entry.layout.meta, entry.layout.private = tab(entry.layout.meta), tab(entry.layout.private)
        entry.layout.meta.name, entry.layout.private.modified = name, GetTimeStamp()
    else
        return nil, zo_strformat(L.core.not_received, entry.name)
    end
    say(zo_strformat(L.core.renamed, entry.name, name))
    return true
end
LF.bags = {}
for _, bag in ipairs({ "BAG_BACKPACK", "BAG_BANK", "BAG_SUBSCRIBER_BANK", "BAG_HOUSE_BANK_ONE", "BAG_HOUSE_BANK_TWO", "BAG_HOUSE_BANK_THREE",
                       "BAG_HOUSE_BANK_FOUR", "BAG_HOUSE_BANK_FIVE", "BAG_HOUSE_BANK_SIX", "BAG_HOUSE_BANK_SEVEN", "BAG_HOUSE_BANK_EIGHT",
                       "BAG_HOUSE_BANK_NINE", "BAG_HOUSE_BANK_TEN", "BAG_FURNITURE_VAULT" }) do
    if _G[bag] ~= nil then LF.bags[#LF.bags + 1] = _G[bag] end
end
local function bagName(bag)
    if bag == BAG_BACKPACK then return L.core.backpack end
    if bag == BAG_BANK or bag == BAG_SUBSCRIBER_BANK then return L.core.bank end
    if bag == BAG_FURNITURE_VAULT then return L.core.furniture_vault end
    local chest = ask(GetCollectibleForBag, bag)
    local name = chest and chest ~= 0 and (nonempty(ask(GetCollectibleNickname, chest)) or ask(GetCollectibleName, chest))
    return name and name ~= "" and (string.gsub(name, "%^.*$", "")) or L.core.house_storage
end
local function findInBags(itemId, place)
    for _, bag in ipairs(LF.takeBags and LF.takeBags() or LF.bags) do
        if place == nil or bagName(bag) == place then
            for slot = 0, (ask(GetBagSize, bag) or 0) - 1 do
                if GetItemId(bag, slot) == itemId then return bag, slot end
            end
        end
    end
    return nil
end
local function placedIds()
    local ids = {}
    local id = GetNextPlacedHousingFurnitureId()
    while id do
        ids[Id64ToString(id)] = id
        id = GetNextPlacedHousingFurnitureId(id)
    end
    return ids
end
local function whole(v)
    return math.floor(v + 0.5)
end
local function sameAngle(a, b)
    local d = math.abs(a - b) % TWO_PI
    return math.min(d, TWO_PI - d) < SAME_ANGLE
end
local function samePlace(id, row)
    local x, y, z = HousingEditorGetFurnitureWorldPosition(id)
    local p, yw, r = HousingEditorGetFurnitureOrientation(id)
    local pos, rot = row.position, row.rotation
    return math.abs(x - whole(pos[1])) < 1 and math.abs(y - whole(pos[2])) < 1 and math.abs(z - whole(pos[3])) < 1
        and sameAngle(p, rot[1]) and sameAngle(yw, rot[2]) and sameAngle(r, rot[3])
end
local function triple(v)
    return type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number"
end
local function usable(row)
    return type(row) == "table" and (row.kind == "item" or row.kind == "collectible") and type(row.item_id) == "number"
        and triple(row.position) and triple(row.rotation)
end
local function rowWhat(row)
    return row.kind .. ":" .. tostring(row.item_id)
end
local function whatIs(id)
    local itemLink, collectibleLink = ask(GetPlacedFurnitureLink, id, LINK_STYLE_BRACKETS)
    local kind, itemId = identity(nonempty(itemLink) or collectibleLink)
    return kind .. ":" .. tostring(itemId)
end
local function bindable(layout)
    return layout.owner ~= nil and layout.owner == ask(GetCurrentHouseOwner)
end
local function distance(id, row)
    local x, y, z = HousingEditorGetFurnitureWorldPosition(id)
    local p = row.position
    return math.sqrt((x - p[1]) ^ 2 + (y - p[2]) ^ 2 + (z - p[3]) ^ 2)
end
local function parentKey(id)
    local parent = ask(GetPlacedFurnitureParent, id)
    if parent == nil then return nil end
    local key = Id64ToString(parent)
    return key ~= "0" and key ~= "" and key or nil
end
LF.parentKey = parentKey
local function appliedKey(layout)
    return tostring(layout.id)
end
local function appliedOf(layout)
    LF.saved.applied = LF.saved.applied or {}
    local key = appliedKey(layout)
    LF.saved.applied[key] = LF.saved.applied[key] or { items = {} }
    local done = LF.saved.applied[key]
    done.items = done.items or {}
    done.name, done.digest = layout.name, layout.digest
    done.owner, done.world = ask(GetCurrentHouseOwner), nil
    return done
end
local function plan(layout, withLinks)
    local ids = placedIds()
    local bound = bindable(layout)
    local done = LF.saved.applied and LF.saved.applied[appliedKey(layout)]
    local earlierItems = type(done) == "table" and type(done.items) == "table" and done.items or {}
    local rows = type(layout.items) == "table" and layout.items or {}
    local steps, found, lacking, inPlace = {}, {}, {}, {}
    local counts = { missing = 0, unchanged = 0, already = 0, skipped = 0, waiting = 0 }
    local taken = {}
    local conforms = {}
    local function onItsWay(row)
        if row.uid == nil or type(done) ~= "table" or #LF.waiting == 0 then return false end
        local t = now()
        for _, w in ipairs(LF.waiting) do
            if w.done == done and w.uid == row.uid and (not t or not w.at or t - w.at < ANSWER_SECONDS) then return true end
        end
        return false
    end
    local function boundId(row)
        local id = row.game_id and ids[row.game_id]
        return id and whatIs(id) == rowWhat(row) and id or nil
    end
    local function inItsPlace(id, row)
        return samePlace(id, row) or LF.walksRight(id, row)
    end
    local function standsRight(id, row, move)
        local right = true
        if row.state ~= nil and row.state ~= ask(GetPlacedHousingFurnitureCurrentObjectStateIndex, id) then
            steps[#steps + 1] = { action = "state", id = id, state = row.state, uid = row.uid }
            right = false
        end
        if move then
            steps[#steps + 1] = { action = "move", id = id, row = row, uid = row.uid }
            right = false
        end
        if LF.pathDiffers(id, row.path) then
            steps[#steps + 1] = { action = "path", id = id, row = row, uid = row.uid }
            right = false
        end
        if LF.conformOf(row) ~= nil then conforms[#conforms + 1] = { action = "conform", id = id, want = LF.conformOf(row), uid = row.uid } end
        if right and inItsPlace(id, row) then
            inPlace[#inPlace + 1] = { row = row, id = id }
        end
    end
    local function placedBefore(row)
        local earlier = row.uid ~= nil and earlierItems[row.uid]
        if type(earlier) == "table" and earlier.result == PLACED and earlier.game_id and ids[earlier.game_id]
           and whatIs(ids[earlier.game_id]) == rowWhat(row) then
            return earlier.game_id
        end
        return nil
    end
    local claimed = {}
    local ok, boundOf, beforeOf = {}, {}, {}
    for i, row in ipairs(rows) do
        if usable(row) then
            ok[i] = true
            local id = boundId(row)
            if id then
                boundOf[i] = id
                claimed[row.game_id] = true
            else
                local before = placedBefore(row)
                if before then
                    beforeOf[i] = before
                    claimed[before] = true
                end
            end
        end
    end
    local standing = {}
    local parentOf, childrenOf = {}, {}
    for key, id in pairs(ids) do
        local up = parentKey(id)
        if up then
            parentOf[key] = up
            childrenOf[up] = childrenOf[up] or {}
            table.insert(childrenOf[up], key)
        end
        local what = whatIs(id)
        local collectible = string.match(what, "^collectible:(%d+)$")
        if collectible then taken[tonumber(collectible)] = true end
        if not claimed[key] then
            standing[what] = standing[what] or {}
            table.insert(standing[what], key)
        end
    end
    local at, reused = {}, {}
    local loose = {}
    for i, row in ipairs(rows) do
        if ok[i] and not boundOf[i] and not beforeOf[i] then
            local list = standing[rowWhat(row)] or {}
            for i, key in ipairs(list) do
                if inItsPlace(ids[key], row) then
                    at[row] = key
                    table.remove(list, i)
                    break
                end
            end
            if not at[row] then loose[#loose + 1] = row end
        end
    end
    local pairsBy = {}
    for _, row in ipairs(loose) do
        local list = standing[rowWhat(row)]
        if list and #list > 0 then
            for _, key in ipairs(list) do
                pairsBy[#pairsBy + 1] = { row = row, key = key, d = distance(ids[key], row) }
            end
        end
    end
    table.sort(pairsBy, function(a, b) return a.d < b.d end)
    local taken_ = {}
    for _, p in ipairs(pairsBy) do
        if not reused[p.row] and not taken_[p.key] then
            reused[p.row], taken_[p.key] = p.key, true
        end
    end
    for _, key in pairs(at) do claimed[key] = true end
    for _, key in pairs(reused) do claimed[key] = true end
    local keyOf, byUid = {}, {}
    for i, row in ipairs(rows) do
        if ok[i] and row.uid ~= nil then
            byUid[row.uid] = row
            keyOf[row.uid] = (boundOf[i] and row.game_id) or beforeOf[i] or at[row] or reused[row]
        end
    end
    local depths = {}
    local function depth(key)
        if not key then return 0 end
        if depths[key] then return depths[key] end
        local path, seen, at = {}, {}, key
        while at and depths[at] == nil and not seen[at] do
            seen[at], path[#path + 1] = true, at
            at = parentOf[at]
        end
        local n = at and depths[at] or -1
        for i = #path, 1, -1 do
            n = n + 1
            depths[path[i]] = n
        end
        return depths[key]
    end
    local order
    if next(parentOf) then
        order = {}
        for i, row in ipairs(rows) do
            order[i] = { i = i, depth = ok[i] and row.uid ~= nil and depth(keyOf[row.uid]) or 0 }
        end
        table.sort(order, function(a, b) if a.depth ~= b.depth then return a.depth < b.depth end return a.i < b.i end)
    end
    for index in ipairs(rows) do
        local i = order and order[index].i or index
        local row = rows[i]
        local id = boundOf[i]
        if not ok[i] then
            counts.skipped = counts.skipped + 1
        elseif beforeOf[i] or id then
            local standingId = id or ids[beforeOf[i]]
            local earlier = earlierItems[row.uid]
            if row.kind == "collectible" and type(earlier) == "table" and earlier.position_pending and earlier.game_id == Id64ToString(standingId) then
                steps[#steps + 1] = { action = "move", id = standingId, row = row, uid = row.uid, settlePlacement = true }
            elseif beforeOf[i] then
                local here = inItsPlace(standingId, row)
                standsRight(standingId, row, not here)
                if here then counts.already = counts.already + 1 end
            else
                local here = inItsPlace(id, row)
                standsRight(id, row, not here)
                if here then counts.unchanged = counts.unchanged + 1 end
            end
        elseif at[row] then
            standsRight(ids[at[row]], row)
            counts.already = counts.already + 1
            found[#found + 1] = { uid = row.uid, game_id = at[row] }
        elseif reused[row] then
            steps[#steps + 1] = { action = "move", id = ids[reused[row]], row = row, uid = row.uid, take = true }
        else
            if onItsWay(row) then
                counts.waiting = counts.waiting + 1
            elseif row.kind == "collectible" then
                if ask(IsCollectibleUnlocked, row.item_id) and not taken[row.item_id] then
                    taken[row.item_id] = true
                    steps[#steps + 1] = { action = "collectible", row = row, uid = row.uid }
                else
                    counts.missing = counts.missing + 1
                    lacking[#lacking + 1] = row
                end
            else
                steps[#steps + 1] = { action = "item", row = row, uid = row.uid }
            end
        end
    end
    local moving, rowOfKey = {}, {}
    for _, s in ipairs(steps) do
        if s.action == "move" then moving[Id64ToString(s.id)] = true end
    end
    for uid, key in pairs(keyOf) do rowOfKey[key] = byUid[uid] end
    for _, s in ipairs(steps) do
        if s.action == "move" then
            for _, key in ipairs(childrenOf[Id64ToString(s.id)] or {}) do
                if rowOfKey[key] and not moving[key] then
                    s.children = s.children or {}
                    s.children[#s.children + 1] = { id = ids[key], row = rowOfKey[key] }
                end
            end
        end
    end
    local linking = {}
    for i, row in ipairs(withLinks and rows or {}) do
        local up = ok[i] and row.uid ~= nil and row.parent ~= nil and row.parent ~= row.uid and byUid[row.parent] or nil
        local child = ok[i] and row.uid ~= nil and keyOf[row.uid] or nil
        if up then
            local parent = keyOf[up.uid]
            if not (child and parent and parentOf[child] == parent) then
                steps[#steps + 1] = { action = "link", row = row, uid = row.uid, parentUid = up.uid, childKey = child, parentKey = parent,
                                      id = child and ids[child] or nil }
                linking[row.uid] = true
            end
        elseif layout.recorded and child and row.parent == nil and parentOf[child] then
            steps[#steps + 1] = { action = "unlink", row = row, uid = row.uid, id = ids[child], childKey = child }
            linking[row.uid] = true
        end
    end
    if next(linking) then
        for i = #inPlace, 1, -1 do
            if linking[inPlace[i].row.uid] then table.remove(inPlace, i) end
        end
    end
    for _, c in ipairs(conforms) do steps[#steps + 1] = c end
    return steps, counts, bound, found, claimed, lacking, inPlace, keyOf
end
local function runStep(step, q)
    if step.action == "state" then
        return HousingEditorRequestChangeState(step.id, step.state)
    elseif step.action == "remove" then
        return HousingEditorRequestRemoveFurniture(step.id)
    elseif step.action == "pathnode" or step.action == "pathdata" or step.action == "pathstart" then
        return LF.runPathStep(step)
    elseif step.action == "link" then
        return HousingEditorRequestSetFurnitureParent(step.id, step.parentId)
    elseif step.action == "unlink" then
        return HousingEditorRequestClearFurnitureParent(step.id)
    end
    local row = step.row
    local rot = row.rotation
    local x, y, z = whole(row.position[1]), whole(row.position[2]), whole(row.position[3])
    if step.action == "move" then
        return HousingEditorRequestChangePositionAndOrientation(step.id, x, y, z, rot[1], rot[2], rot[3])
    elseif step.action == "collectible" then
        return HousingEditorRequestCollectiblePlacement(row.item_id, x, y, z, rot[1], rot[2], rot[3])
    end
    local bag, slot
    if step.bags then
        for _, b in ipairs(step.bags) do
            for s = 0, (ask(GetBagSize, b) or 0) - 1 do
                if not bag and GetItemId(b, s) == row.item_id then bag, slot = b, s end
            end
        end
    else
        bag, slot = findInBags(row.item_id, step.place)
    end
    if LF.debugEntry then LF.debugEntry("item_source", q, step, { bag = bag, slot = slot, found = bag ~= nil }) end
    if not bag then return nil end
    return HousingEditorRequestItemPlacement(bag, slot, x, y, z, rot[1], rot[2], rot[3])
end
local function stopApplying(message, stopped)
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    local q = LF.queue
    if q and q.check and LF.confirmed then LF.confirmed(q, true, stopped) end
    if q and q.onFinished and not stopped then q.onFinished() end
    if q and q.done then
        if stopped then q.done.stopped = GetTimeStamp() else q.done.finished = GetTimeStamp() end
        if stopped then
            for _, w in ipairs(LF.waiting) do
                if w.queue == q then w.skipState = true end
            end
        end
    end
    LF.queue = nil
    if message and q and LF.intoText then message = sentences(message, LF.intoText(q)) end
    if q and q.log then
        local log = q.log
        log.kind = (q.rollback and "rollback") or (q.single and "remove one") or (q.removing and "remove") or log.kind
        log.ended, log.how, log.said, log.steps = GetTimeStamp(), stopped and "stopped" or "finished", message, #q.steps
        log.counts = { moved = q.moved, switched = q.switched, placed = q.placed, removed = q.removed, failed = q.failed, absent = q.absent,
                       pathed = q.pathed, linked = q.linked, not_linked = q.unlinked, unlinked = q.cleared, not_put_away = q.skipped and #q.skipped or 0 }
        if LF.debugEntry then LF.debugEntry("run_end", q, nil, { how = log.how, summary = message, counts = log.counts }) end
    end
    if LF.restoreRetrieve then LF.restoreRetrieve() end
    LF.lastRun = message
    if message then say(message) end
    if q and q.skipped and #q.skipped > 0 and LF.notPutAwayProblem then LF.notPutAwayProblem(q.skipped) end
    if q and q.onEnded then q.onEnded(q) end
    if LF.onProgress then LF.onProgress() end
end
local function forget(done, uid)
    if uid == nil then return end
    for i = #LF.waiting, 1, -1 do
        if LF.waiting[i].done == done and LF.waiting[i].uid == uid then table.remove(LF.waiting, i) end
    end
end
local function listen(q, step)
    forget(q.done, step.uid)
    local w = { step = step, row = step.row, uid = step.uid, done = q.done, queue = q, ticks = 0, at = now() }
    LF.waiting[#LF.waiting + 1] = w
    q.pending = w
    return w
end
local function sameHouse(q)
    return q.house == GetCurrentZoneHouseId() and q.owner == ask(GetCurrentHouseOwner) and IsOwnerOfCurrentHouse()
end
local function completeTask(q, step)
    local progress = q.progress
    local task = progress and progress.tasks[step]
    if not task then return end
    progress.tasks[step] = nil
    task.remaining = task.remaining - 1
    if task.remaining == 0 then
        progress.done = progress.done + 1
        if LF.queue == q and LF.onProgress then LF.onProgress() end
    end
end
local function delegateTask(q, step, requests)
    local progress = q.progress
    local task = progress and progress.tasks[step]
    if not task then return end
    progress.tasks[step] = nil
    task.remaining = task.remaining - 1 + #requests
    for _, request in ipairs(requests) do progress.tasks[request] = task end
end
local function restoreState(q, id, row)
    local steps = {}
    if row.state ~= nil and row.state ~= ask(GetPlacedHousingFurnitureCurrentObjectStateIndex, id) then
        steps[#steps + 1] = { action = "state", id = id, state = row.state, uid = row.uid }
    end
    if LF.pathDiffers and LF.pathDiffers(id, row.path) then
        steps[#steps + 1] = { action = "path", id = id, row = row, uid = row.uid }
    end
    if LF.conformOf and LF.conformOf(row) ~= nil and LF.queue == q then
        q.steps[#q.steps + 1] = { action = "conform", id = id, want = LF.conformOf(row), uid = row.uid }
    end
    for i, step in ipairs(steps) do
        if LF.queue == q then
            table.insert(q.steps, q.index + i, step)
        elseif not LF.queue then
            LF.perform(q, step)
        end
    end
end
local function onPlaced(_, furnitureId, collectibleId)
    if LF.debugEntry then
        LF.debugEntry("placed_event", LF.queue, nil, { furniture = Id64ToString(furnitureId), collectible = collectibleId,
                      waiting = #LF.waiting, observed = LF.debugState(furnitureId) })
    end
    if #LF.waiting == 0 then return end
    local ok, what = pcall(function()
        if collectibleId and collectibleId ~= 0 then return "collectible:" .. tostring(collectibleId) end
        return whatIs(furnitureId)
    end)
    if not ok then
        if LF.debugEntry then LF.debugEntry("placement_identity_error", LF.queue, nil, { error = tostring(what) }) end
        return
    end
    local collectible = string.match(what, "^collectible:") ~= nil
    local candidate
    if collectible then
        for _, w in ipairs(LF.waiting) do
            if sameHouse(w.queue) and what == rowWhat(w.row) then
                if LF.queue == w.queue and w.queue.pending == w then candidate = w; break end
                if candidate == nil then candidate = w else candidate = false end
            end
        end
    end
    for i, w in ipairs(LF.waiting) do
        local fine, matches = pcall(function()
            if collectible then return candidate == w end
            return sameHouse(w.queue) and what == rowWhat(w.row) and samePlace(furnitureId, w.row)
        end)
        if LF.debugEntry then
            LF.debugEntry("placement_match", w.queue, w.step, { furniture = Id64ToString(furnitureId), identity = what,
                          same_house = sameHouse(w.queue), matched = fine and matches or false, error = not fine and tostring(matches) or nil })
        end
        if fine and matches then
            table.remove(LF.waiting, i)
            LF.solved(w.step, "late")
            w.placement = { result = PLACED, game_id = Id64ToString(furnitureId), position_pending = collectible or nil }
            if w.uid ~= nil then w.done.items[w.uid] = w.placement end
            w.queue.placed = w.queue.placed + 1
            if w.queue.pending == w then w.queue.pending = nil end
            if not collectible then completeTask(w.queue, w.step) end
            if not w.skipState then
                if collectible then
                    local verify = { action = "move", id = furnitureId, row = w.row, uid = w.uid, settlePlacement = true }
                    LF.queueOps(w.queue, { verify }, w.step)
                else
                    restoreState(w.queue, furnitureId, w.row)
                end
            end
            return
        end
    end
end
local start
local RUNS_KEPT, EVENTS_KEPT = 5, 200
local function gameMs()
    return ask(GetGameTimeMilliseconds) or 0
end
local function newLog(name, kind)
    local log = { name = tostring(name or ""), kind = kind, started = GetTimeStamp(), started_ms = gameMs(), speed = stepDelay(),
                  addon = LF.build, house = GetCurrentZoneHouseId(), events = {}, dropped = 0 }
    LF.saved.runs = type(LF.saved.runs) == "table" and LF.saved.runs or {}
    table.insert(LF.saved.runs, 1, log)
    while #LF.saved.runs > RUNS_KEPT do table.remove(LF.saved.runs) end
    return log
end
local function about(step)
    local out = { action = step.action, name = step.name, uid = step.uid }
    if step.row then out.thing = step.row.kind .. ":" .. tostring(step.row.item_id) end
    if step.id then
        out.id = Id64ToString(step.id)
        if not out.thing then
            local ok, what = pcall(whatIs, step.id)
            if ok then out.thing = what end
        end
        if not out.name then
            local ok, name = pcall(GetPlacedHousingFurnitureInfo, step.id)
            if ok and type(name) == "string" and name ~= "" then out.name = string.gsub(name, "%^.*$", "") end
        end
    end
    return out
end
function LF.trace(q, what, step, extra)
    if not (q and LF.saved) then return end
    q.log = q.log or newLog(q.name or (q.done and q.done.name), "by hand")
    if LF.debugEntry then LF.debugEntry("problem", q, step, { what = what, details = extra }) end
    local log = q.log
    if #log.events >= EVENTS_KEPT then
        log.dropped = log.dropped + 1
        return nil
    end
    local entry = step and about(step) or {}
    entry.what, entry.ms, entry.step = what, gameMs() - (log.started_ms or 0), q.index
    if type(extra) == "table" then
        for k, v in pairs(extra) do entry[k] = v end
    end
    if entry.code ~= nil and entry.answer == nil then
        entry.answer = nonempty(ask(GetString, "SI_HOUSINGREQUESTRESULT", entry.code) or "")
    end
    if entry.place then entry.place_name = LF.bagName and LF.bagName(entry.place) or nil end
    log.events[#log.events + 1] = entry
    if step then
        step.problems = step.problems or {}
        step.problems[#step.problems + 1] = entry
    end
    return entry
end
function LF.solved(step, how, place)
    for _, entry in ipairs(step and step.problems or {}) do
        if not entry.solved then
            entry.solved = how
            if place then entry.solved_place = LF.bagName and LF.bagName(place) or tostring(place) end
        end
    end
end
local function tally(done)
    return { moved = 0, switched = 0, placed = 0, removed = 0, failed = 0, absent = 0, pathed = 0, linked = 0, unlinked = 0, cleared = 0, streak = 0,
             done = done, pending = nil,
             house = GetCurrentZoneHouseId(), owner = ask(GetCurrentHouseOwner) }
end
local function linkEnds(q, step)
    local ids = placedIds()
    local function endOf(uid, key)
        if key == nil and uid ~= nil then
            local d = q.done and type(q.done.items) == "table" and q.done.items[uid]
            key = type(d) == "table" and d.game_id or nil
        end
        return key and ids[key] or nil, key
    end
    local child, childKey = endOf(step.uid, step.childKey)
    if step.action == "unlink" then return child, childKey end
    local parent, parentKey_ = endOf(step.parentUid, step.parentKey)
    return child, childKey, parent, parentKey_
end
local function restoreParent(q, step)
    if step.restore or not step.previousKey or not step.id or parentKey(step.id) ~= nil then return end
    local previous = placedIds()[step.previousKey]
    if not previous then return end
    LF.queueOps(q, { { action = "link", fixed = true, restore = true, id = step.id, parentId = previous, parentKey = step.previousKey,
                       name = step.name } })
end
local function perform(q, step)
    if (step.action == "collectible" or step.action == "state" or step.action == "link" or step.action == "unlink"
        or (step.action == "move" and step.children)) and LF.queue ~= q then
        return LF.queueOps(q, { step })
    end
    if q.unconfirmedPaths and step.id and q.unconfirmedPaths[Id64ToString(step.id)]
       and (step.action == "move" or step.action == "conform" or string.find(step.action, "^path")) then
        LF.trace(q, "skipped", step, { why = "path_unconfirmed" })
        return { result = SKIPPED }
    end
    if step.action == "remove" and not q.removing and LF.queue ~= q then
        start(q.name or "", { { action = "remove", id = step.id, key = step.key, name = step.name } }, { items = {} })
        LF.queue.removing, LF.queue.single = true, true
        return { result = REQUESTED }
    end
    if step.action == "remove" and step.tried and #step.tried > 0 and not LF.stands(step.id) then
        local last = table.remove(step.tried).bag
        q.removed, q.streak = q.removed + 1, 0
        completeTask(q, step)
        LF.solved(step, "late", last)
        if last then
            LF.removalAccepted(last)
            q.into = q.into or {}
            q.into[last] = (q.into[last] or 0) + 1
        end
        return { result = REMOVED }
    end
    if step.action == "remove" and step.tried and #step.tried > 0 and step.tried[#step.tried].bag == nil then
        return LF.notPutAway(q, step, step.tried[#step.tried].why)
    end
    if step.action == "remove" and LF.removalBag and not string.find(whatIs(step.id), "^collectible:") then
        step.tried = step.tried or {}
        step.into = LF.removalBag(q, step.tried)
        if not step.into then return LF.notPutAway(q, step) end
    end
    if step.action == "path" then
        return LF.expandPath(q, step)
    end
    if (step.action == "link" and not step.fixed) or (step.action == "unlink" and step.uid ~= nil) then
        local child, childKey, parent, parentKey_ = linkEnds(q, step)
        if not child or (step.action == "link" and not parent) then
            q.unlinked = q.unlinked + 1
            LF.trace(q, "link", step, { why = child and "link_no_parent" or "link_no_child" })
            return { result = SKIPPED }
        end
        step.id, step.childKey = child, childKey
        local now = parentKey(child)
        if step.action == "unlink" then
            if now == nil then
                completeTask(q, step)
                return { result = LINKED }
            end
        else
            step.parentId, step.parentKey = parent, parentKey_
            if now == parentKey_ then
                completeTask(q, step)
                return { result = LINKED }
            end
            if now ~= nil and not step.cleared then
                step.cleared, step.previousKey = true, now
                return LF.queueOps(q, { { action = "unlink", id = child, name = step.name }, step }, step)
            end
        end
    end
    if step.action == "conform" then
        if LF.queue ~= q then return LF.queueOps(q, { step }) end
        q.conforming = { ticks = 0 }
        local waiting = q.conforming
        LF.conform(step.id, step.want, function(value)
            if q.conforming ~= waiting then return end
            q.conforming = nil
            if value == step.want then
                q.pathed, q.streak = q.pathed + 1, 0
                completeTask(q, step)
            else
                q.failed = q.failed + 1
                LF.trace(q, "conform", step, { want = step.want, got = value == nil and "unread" or value })
            end
        end)
        return { result = REQUESTED }
    end
    if step.settlePlacement then
        if LF.queue ~= q then return LF.queueOps(q, { step }) end
        q.check = { step = step, ticks = 0, done = function() return samePlace(step.id, step.row) or LF.walksRight(step.id, step.row) end }
        return { result = REQUESTED }
    end
    if step.action == "move" and not step.stopped then
        local follow = LF.walking(step.id)
        if follow then
            local ops = { { action = "pathdata", id = step.id, state = PATH_OFF, follow = follow, uid = step.uid } }
            local moved = {}
            for k, v in pairs(step) do moved[k] = v end
            moved.stopped = true
            ops[2] = moved
            if not (step.row and type(step.row.path) == "table") then
                ops[3] = { action = "pathdata", id = step.id, state = PATH_ON, follow = follow, uid = step.uid }
            end
            return LF.queueOps(q, ops, step)
        end
    end
    local pathRequest = step.action == "pathnode" or step.action == "pathdata" or step.action == "pathstart"
    if pathRequest then
        q.check = { step = step, ticks = 0, path = true, event = pathEvents[step.op or step.action],
                    done = function() return LF.pathStepApplied(step) end }
    end
    if LF.debugEntry then LF.debugEntry("request", q, step, { observed = LF.debugState(step.id, step.index) }) end
    local placement = step.action == "collectible" and listen(q, step)
    local ok, result = pcall(runStep, step, q)
    if LF.debugEntry then
        LF.debugEntry("request_result", q, step, { ok = ok, code = ok and result or nil, returned_nil = ok and result == nil,
                      answer = ok and result and ask(GetString, "SI_HOUSINGREQUESTRESULT", result) or nil,
                      error = not ok and tostring(result) or nil })
    end
    if pathRequest and (not ok or result ~= HOUSING_REQUEST_RESULT_SUCCESS) then q.check = nil end
    if placement and (not ok or result ~= HOUSING_REQUEST_RESULT_SUCCESS) then
        if q.pending == placement then q.pending = nil end
        for i, w in ipairs(LF.waiting) do
            if w == placement then table.remove(LF.waiting, i); break end
        end
    end
    local outcome
    if not ok then
        q.failed = q.failed + 1
        outcome = { result = ERROR, error = tostring(result) }
        LF.trace(q, "error", step, { error = tostring(result) })
    elseif result == nil then
        q.absent = q.absent + 1
        outcome = { result = ABSENT }
        LF.trace(q, "absent", step)
    elseif result == HOUSING_REQUEST_RESULT_SUCCESS then
        if step.action == "move" and step.take then
            q.moved = q.moved + 1
            outcome = { result = PLACED, game_id = Id64ToString(step.id) }
            q.check = { step = step, ticks = 0, counted = "moved", done = function() return samePlace(step.id, step.row) end }
        elseif step.action == "move" then
            q.moved = q.moved + 1
            outcome = { result = MOVED, game_id = Id64ToString(step.id) }
            q.check = { step = step, ticks = 0, counted = "moved", done = function() return samePlace(step.id, step.row) end }
        elseif step.action == "state" then
            q.switched = q.switched + 1
            outcome = { result = SWITCHED, game_id = Id64ToString(step.id) }
            q.check = { step = step, ticks = 0, counted = "switched",
                        done = function() return ask(GetPlacedHousingFurnitureCurrentObjectStateIndex, step.id) == step.state end }
        elseif pathRequest then
            outcome = { result = REQUESTED, game_id = Id64ToString(step.id), action = "path" }
            q.check.outcome = outcome
        elseif step.action == "link" then
            if not step.restore then q.linked = q.linked + 1 end
            outcome = { result = LINKED, game_id = Id64ToString(step.id) }
            q.check = { step = step, ticks = 0, counted = not step.restore and "linked" or nil,
                        done = function() return parentKey(step.id) == step.parentKey end }
        elseif step.action == "unlink" then
            outcome = { result = REQUESTED }
            local counted = (step.uid ~= nil and "linked") or (step.clearsLink and "cleared") or nil
            if counted then q[counted] = q[counted] + 1 end
            q.check = { step = step, ticks = 0, counted = counted, done = function() return parentKey(step.id) == nil end }
        elseif step.action == "remove" then
            if step.into then LF.removalAccepted(step.into) end
            q.check = { step = step, ticks = 0, done = function() return not LF.stands(step.id) end }
            outcome = { result = REQUESTED }
        elseif placement then
            outcome = placement.placement or { result = REQUESTED }
        else
            outcome = { result = REQUESTED }
            listen(q, step)
        end
    elseif step.action == "remove" then
        local why = nonempty(ask(GetString, "SI_HOUSINGREQUESTRESULT", result) or "") or zo_strformat(L.core.refused_code, tostring(result))
        LF.trace(q, "refused", step, { code = result, place = step.into })
        if not step.into then return LF.notPutAway(q, step, why) end
        step.tried[#step.tried + 1] = { bag = step.into, why = why }
        if LF.queue == q then
            q.retry = step
            return { result = REQUESTED }
        end
        return LF.queueOps(q, { step })
    elseif (step.action == "link" and parentKey(step.id) == step.parentKey) or (step.action == "unlink" and parentKey(step.id) == nil) then
        completeTask(q, step)
        outcome = { result = LINKED }
    elseif step.action == "link" or step.action == "unlink" then
        q.failed = q.failed + 1
        q.streak = (q.streak or 0) + 1
        outcome = { result = FAILED, code = result }
        LF.trace(q, "link", step, { code = result, restored = step.previousKey and not step.restore or nil })
        if step.action == "link" then restoreParent(q, step) end
    elseif step.action == "state" and not step.retried and LF.queue == q then
        LF.trace(q, "failed", step, { code = result, retry_ms = RETRY_MS })
        step.retried = true
        q.retry, q.retryTicks = step, math.ceil(RETRY_MS / stepDelay())
        return { result = REQUESTED }
    else
        q.failed = q.failed + 1
        q.streak = (q.streak or 0) + 1
        outcome = { result = FAILED, code = result }
        LF.trace(q, "failed", step, { code = result })
    end
    if step.uid and not step.correctPlacement and step.action ~= "link" and step.action ~= "unlink" then
        local previous = q.done.items[step.uid]
        if not previous or (step.action ~= "state" and not pathRequest)
           or (pathRequest and (previous.result == PATHED or previous.action == "path")) then
            q.done.items[step.uid] = outcome
        end
    end
    if step.take and outcome.result == PLACED then restoreState(q, step.id, step.row) end
    return outcome
end
local function didText(q)
    local parts = counted(some(L.core.done_moved, q.moved), some(L.core.done_switched, q.switched), some(L.core.done_paths, q.pathed),
        some(L.core.done_placed, q.placed), some(L.core.done_linked, q.linked or 0), some(L.core.done_unlinked, q.cleared or 0), some(L.core.done_removed, q.removed),
        some(L.core.done_failed, q.failed), some(L.core.done_absent, q.absent), some(L.core.done_not_linked, q.unlinked or 0),
        some(L.core.done_not_put_away, q.skipped and #q.skipped or 0))
    return parts ~= "" and zo_strformat(L.core.done, parts) or nil
end
local function confirmed(q, finalCheck, stopping)
    local c = q.check
    if c.path and not (c.answered or finalCheck) then return false end
    local ok, done = pcall(c.done)
    if LF.debugEntry then
        LF.debugEntry("state_check", q, c.step, { tick = c.ticks, final = finalCheck, event_seen = c.answered == true,
                      confirmed = ok and done or false, error = not ok and tostring(done) or nil, observed = LF.debugState(c.step.id, c.step.index) })
    end
    if not (ok and done) then return false end
    q.check, q.streak = nil, 0
    completeTask(q, c.step)
    if c.step.problems then
        LF.solved(c.step, (c.step.action == "remove" and "other_place") or (c.step.correctPlacement and "corrected") or "retried",
                  c.step.action == "remove" and c.step.into or nil)
    end
    if c.step.action == "move" and c.step.children and not stopping then
        local back = {}
        for _, child in ipairs(c.step.children) do
            if LF.stands(child.id) and not (samePlace(child.id, child.row) or LF.walksRight(child.id, child.row)) then
                back[#back + 1] = { action = "move", id = child.id, row = child.row, uid = child.row.uid }
            end
        end
        if #back > 0 then LF.queueOps(q, back) end
    end
    if c.step.settlePlacement or c.step.correctPlacement then
        if not stopping then
            local bound = q.done.items[c.step.uid]
            if bound and bound.game_id == Id64ToString(c.step.id) then bound.position_pending = nil end
            restoreState(q, c.step.id, c.step.row)
        end
    elseif c.path then
        q.pathed = q.pathed + 1
        c.outcome.result, c.outcome.action = PATHED, nil
    elseif c.step.action == "remove" then
        q.removed = q.removed + 1
        if c.step.into then
            q.into = q.into or {}
            q.into[c.step.into] = (q.into[c.step.into] or 0) + 1
        end
    end
    return true
end
LF.confirmed = confirmed
local function checking(q)
    local c = q.check
    if not c then return false end
    c.ticks = c.ticks + 1
    local expired = c.ticks >= waitTicks()
    if confirmed(q, expired) then return false end
    if not expired then return true end
    q.check, q.streak = nil, (q.streak or 0) + 1
    local step = c.step
    if step.settlePlacement and ask(whatIs, step.id) == rowWhat(step.row) then
        q.streak = 0
        q.retry = { action = "move", id = step.id, row = step.row, uid = step.uid, correctPlacement = true }
        delegateTask(q, step, { q.retry })
        if LF.debugEntry then LF.debugEntry("placement_correction", q, step, { waited_ms = c.ticks * stepDelay() }) end
        return false
    end
    if c.path then
        c.outcome.result = UNCONFIRMED
        q.failed = q.failed + 1
        LF.trace(q, c.answered and "unconfirmed" or "unanswered", step,
                 { op = step.op, node = step.index, waited_ms = c.ticks * stepDelay() })
        q.unconfirmedPaths = q.unconfirmedPaths or {}
        q.unconfirmedPaths[Id64ToString(step.id)] = true
        return false
    end
    LF.trace(q, step.action == "remove" and "not_taken" or "unconfirmed", step, { place = step.into, waited_ms = c.ticks * stepDelay(),
                                                                                   retry_ms = step.action == "state" and not step.retried and RETRY_MS or nil })
    if step.action == "remove" then
        step.tried = step.tried or {}
        step.tried[#step.tried + 1] = { bag = step.into, why = L.house.not_taken }
        if step.into then LF.removalRefused(step.into) end
        q.retry = step
        return true
    end
    if c.counted then q[c.counted] = q[c.counted] - 1 end
    if step.action == "state" and not step.retried then
        step.retried = true
        q.retry, q.retryTicks = step, math.ceil(RETRY_MS / stepDelay())
        return false
    end
    q.failed = q.failed + 1
    if step.action == "link" then restoreParent(q, step) end
    if not (step.settlePlacement or step.correctPlacement or step.action == "link" or step.action == "unlink") and step.uid ~= nil
       and q.done.items[step.uid] and q.done.items[step.uid].game_id == Id64ToString(step.id) then
        q.done.items[step.uid] = { result = UNCONFIRMED, game_id = Id64ToString(step.id) }
    end
    return false
end
local function onTick()
    local q = LF.queue
    if not q then return end
    if not sameHouse(q) then
        local why = q.house ~= GetCurrentZoneHouseId() and zo_strformat(L.house.other_house, q.house, GetCurrentZoneHouseId()) or L.house.not_owner
        LF.trace(q, "stopped", nil, { why = q.house ~= GetCurrentZoneHouseId() and "left_house" or "not_owner" })
        stopApplying(why, true)
        return
    end
    if GetHousingEditorMode() == HOUSING_EDITOR_MODE_DISABLED then
        HousingEditorRequestModeChange(HOUSING_EDITOR_MODE_SELECTION)
        return
    end
    if checking(q) then return end
    if q.conforming then
        q.conforming.ticks = q.conforming.ticks + 1
        if q.conforming.ticks * stepDelay() < 10000 then return end
        q.conforming, q.failed = nil, q.failed + 1
        LF.trace(q, "conform", nil, { got = "timeout" })
    end
    if q.pending then
        q.pending.ticks = q.pending.ticks + 1
        if q.pending.ticks < waitTicks() then return end
        if q.pending.uid ~= nil then
            q.done.items[q.pending.uid] = { result = UNCONFIRMED }
        end
        LF.trace(q, "unanswered", q.pending.step, { waited_ms = waitTicks() * stepDelay() })
        q.pending, q.streak = nil, (q.streak or 0) + 1
    end
    if (q.streak or 0) >= STREAK_STOP then
        local slowest = stepDelay() >= SPEEDS[#SPEEDS]
        LF.trace(q, "stopped", nil, { why = "too_fast", streak = q.streak })
        stopApplying(sentences(didText(q), count(slowest and L.core.not_done_slowest or L.core.not_done_slower, q.streak)), true)
        return
    end
    if q.retry and (q.retryTicks or 0) > 0 then
        q.retryTicks = q.retryTicks - 1
        return
    end
    local step = q.retry
    if step then
        q.retry = nil
    else
        q.index = q.index + 1
        step = q.steps[q.index]
    end
    if not step then
        local said = didText(q) or zo_strformat(L.core.done, counted(some(L.core.done_moved, 0)))
        stopApplying((not q.single or (q.skipped and #q.skipped > 0)) and said or nil)
        return
    end
    local result = perform(q, step).result
    if LF.debugEntry then LF.debugEntry("step_result", q, step, { result = result }) end
    if result == ABSENT and step.action == "item" then
        local left = 0
        for i = q.index, #q.steps do
            if q.steps[i].action == step.action then left = left + 1 end
        end
        q.absent = q.absent - 1
        LF.trace(q, "stopped", step, { why = "no_place", left = left })
        stopApplying(didText(q), true)
        LF.takeProblem(left, step.name)
        return
    end
    if LF.onProgress then LF.onProgress() end
end
local function detachFirst(steps)
    local ids, first, detach = nil, nil, {}
    for i, s in ipairs(steps) do
        if s.action == "link" and not s.fixed then first = first or i end
        if s.action == "link" and not s.fixed and s.childKey then
            ids = ids or placedIds()
            local child = ids[s.childKey]
            local now = child and parentKey(child)
            if now and now ~= s.parentKey then
                local own = {}
                for k, v in pairs(s) do own[k] = v end
                own.cleared, own.previousKey = true, now
                steps[i] = own
                detach[#detach + 1] = { action = "unlink", id = child, name = s.name }
            end
        end
    end
    for k = #detach, 1, -1 do table.insert(steps, first, detach[k]) end
end
function start(name, steps, done, placing)
    detachFirst(steps)
    for _, w in ipairs(LF.waiting) do w.skipState = true end
    LF.queue = tally(done)
    LF.queue.name, LF.queue.steps, LF.queue.index = name, steps, 0
    for _, step in ipairs(steps) do
        if placing or step.action == "item" or step.action == "collectible" or step.settlePlacement then
            local progress = { done = 0, total = #steps, tasks = {} }
            for _, original in ipairs(steps) do progress.tasks[original] = { remaining = 1 } end
            LF.queue.progress = progress
            break
        end
    end
    LF.queue.log = newLog(name, "run")
    if LF.debugEntry then LF.debugEntry("run_start", LF.queue, nil, { steps = #steps, speed_ms = stepDelay() }) end
    LF.lastRun = nil
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, stepDelay(), onTick)
end
local function apply(name, confirmed)
    if confirmed and LF.queue then return say(L.house.busy) end
    local box, why = received()
    local layout = findLayout(box, name)
    local record = not layout and LF.saved.exports[name]
    if type(record) == "table" and type(record.house) == "table" and record.house.house_id == GetCurrentZoneHouseId() then
        layout = asLayout(record, name)
    end
    if not layout then
        say(why or zo_strformat(L.core.not_received, name))
        return
    end
    if type(layout.house_id) ~= "number" or type(layout.items) ~= "table" then
        say(zo_strformat(L.core.no_house_or_items, name))
        return
    end
    if GetCurrentZoneHouseId() ~= layout.house_id then
        say(zo_strformat(L.core.other_house, name, tostring(layout.house_id), tostring(GetCurrentZoneHouseId())))
        return
    end
    if not IsOwnerOfCurrentHouse() then
        say(L.core.owner_applies)
        return
    end
    local planned, steps, counts, bound, found = pcall(plan, layout)
    if not planned then
        say(zo_strformat(L.core.unreadable, name, tostring(steps)))
        return
    end
    local moves, places, states, paths, links = 0, 0, 0, 0, 0
    for _, s in ipairs(steps) do
        if s.action == "move" then
            moves = moves + 1
        elseif s.action == "state" then
            states = states + 1
        elseif s.action == "path" then
            paths = paths + 1
        elseif s.action == "link" or s.action == "unlink" then
            links = links + 1
        elseif s.action ~= "conform" then
            places = places + 1
        end
    end
    local ownerless = layout.owner == nil or layout.owner == ""
    local where = not bound and (ownerless and L.core.not_tied or L.core.other_owner) or nil
    if not confirmed then
        local waiting = counts.waiting > 0 and count(L.core.waiting, counts.waiting) or nil
        local parts = counted(some(L.core.to_move, moves), some(L.core.to_place, places), some(L.core.states_to_switch, states), some(L.core.paths_to_set, paths),
            some(L.core.links_to_set, links),
            some(L.core.already_right, counts.unchanged), some(L.core.placed_earlier, counts.already),
            some(L.core.collectibles_unavailable, counts.missing), some(L.core.not_for_the_game, counts.skipped))
        say(sentences(zo_strformat(L.core.preview, name, parts), waiting, where, zo_strformat(L.core.go_ahead, name)))
        return
    end
    local done = appliedOf(layout)
    done.started, done.finished, done.stopped = GetTimeStamp(), nil, nil
    for _, f in ipairs(found) do
        if f.uid ~= nil then
            done.items[f.uid] = { result = PLACED, game_id = f.game_id }
            forget(done, f.uid)
        end
    end
    if LF.guard then LF.guard("apply", name) end
    start(name, steps, done)
    say(sentences(count(L.core.applying, #steps), where, L.core.stop_stops))
end
local function openSite()
    local asked = type(RequestOpenUnsafeURL) == "function" and pcall(RequestOpenUnsafeURL, LF.SITE)
    if asked then say(zo_strformat(L.core.site_asked, LF.SITE)) else say(zo_strformat(L.core.site_by_hand, LF.SITE)) end
end
local function stopRun()
    local q = LF.queue
    if not q then return false end
    LF.trace(q, "stopped", nil, { why = "stop" })
    local message = q.rollback and zo_strformat(L.core.stopped_rollback, tostring(q.rollback)) or
                    (q.wholeHouse and (L.window.empty_house .. " — " .. L.window.log_stopped)) or (q.removing and L.core.stopped_remove) or zo_strformat(L.core.stopped_apply, q.name)
    stopApplying(message, true)
    return true
end
local function command(text)
    local verb, rest = string.match(text or "", "^%s*(%S*)%s*(.-)%s*$")
    if verb == "export" then
        export(rest)
    elseif verb == "apply" then
        local name, word = string.match(rest, "^(.-)%s+(confirm)$")
        apply(name or rest, word == "confirm")
    elseif verb == "" and LF.toggleWindow then
        LF.toggleWindow()
    elseif verb == "stop" then
        if not stopRun() and not (LF.stopCode and LF.stopCode()) and not (LF.stopPatterns and LF.stopPatterns()) then
            say(L.core.nothing_applying)
        end
    elseif verb == "backup" and LF.requestManualBackup then
        LF.requestManualBackup()
    elseif verb == "rollback" and LF.rollback then
        local n, word = string.match(rest, "^(%d*)%s*(%a*)$")
        LF.rollback(tonumber(n) or 1, word == "confirm")
    elseif verb == "share" and LF.showShare then
        LF.showShare(rest)
    elseif verb == "paste" and LF.showPaste then
        LF.showPaste()
    elseif verb == "patterns" and LF.readPatterns then
        LF.readPatterns(true)
    elseif verb == "version" then
        say(zo_strformat(L.core.version, LF.version, tostring(LF.build), FORMAT_VERSION))
    elseif verb == "help" then
        say(sentences(L.core.usage, zo_strformat(L.core.get_app, LF.SITE)))
    else
        say(L.core.usage)
    end
end
local function tidy()
    local box = inbox()
    if not box then return end
    local imported, held, gone = {}, {}, 0
    for _, id in ipairs(type(box.imported) == "table" and box.imported or {}) do imported[tostring(id)] = true end
    for name, record in pairs(LF.saved.exports) do
        if type(record) == "table" and record.id ~= nil and imported[tostring(record.id)] then
            LF.saved.exports[name] = nil
            gone = gone + 1
        end
    end
    for _, row in ipairs(box.layouts) do
        if type(row) == "table" and type(row.layout) == "table" then held[tostring(row.layout.id)] = true end
    end
    for id in pairs(type(LF.saved.dismissed) == "table" and LF.saved.dismissed or {}) do
        if not held[id] then LF.saved.dismissed[id] = nil end
    end
    if gone > 0 then
        EVENT_MANAGER:RegisterForEvent(LF.name .. "Imported", EVENT_PLAYER_ACTIVATED, function()
            EVENT_MANAGER:UnregisterForEvent(LF.name .. "Imported", EVENT_PLAYER_ACTIVATED)
            say(count(L.core.imported, gone))
        end)
    end
end
local function onLoaded(_, addonName)
    if addonName ~= LF.name then return end
    EVENT_MANAGER:UnregisterForEvent(LF.name, EVENT_ADD_ON_LOADED)
    LF.saved = ZO_SavedVars:NewAccountWide("LetsFurnishSV", SAVED_VARS_VERSION, nil, { schema = SCHEMA, exports = {}, applied = {} })
    local major = majorMinor(LF.saved.schema)
    if not major or major < SCHEMA_MAJOR then
        local had = next(LF.saved.exports or {}) ~= nil or next(LF.saved.backups or {}) ~= nil or next(LF.saved.pasted or {}) ~= nil
        for _, key in ipairs({ "exports", "applied", "backups", "pasted", "dismissed", "parts", "active", "window" }) do LF.saved[key] = nil end
        if had then
            EVENT_MANAGER:RegisterForEvent(LF.name .. "Cleared", EVENT_PLAYER_ACTIVATED, function()
                EVENT_MANAGER:UnregisterForEvent(LF.name .. "Cleared", EVENT_PLAYER_ACTIVATED)
                say(L.core.cleared)
            end)
        end
    end
    LF.saved.schema = SCHEMA
    LF.saved.exports = LF.saved.exports or {}
    LF.saved.applied = LF.saved.applied or {}
    if LF.saved.debugEnabled then LF.setDebug(true) end
    LF.saved.addon = { version = LF.version, build = LF.build, api = ask(GetAPIVersion), path_waits = LF.pathWaits and LF.pathWaits() or nil }
    tidy()
    if not LF.saved.welcomed then
        EVENT_MANAGER:RegisterForEvent(LF.name .. "Welcome", EVENT_PLAYER_ACTIVATED, function()
            EVENT_MANAGER:UnregisterForEvent(LF.name .. "Welcome", EVENT_PLAYER_ACTIVATED)
            LF.saved.welcomed = true
            say(L.core.welcome)
        end)
    end
    EVENT_MANAGER:RegisterForEvent(LF.name, EVENT_HOUSING_FURNITURE_PLACED, onPlaced)
    EVENT_MANAGER:RegisterForEvent(LF.name, EVENT_PLAYER_DEACTIVATED, function()
        stopRun()
        LF.waiting = {}
    end)
    SLASH_COMMANDS["/lf"] = command
    if LF.onLoaded then LF.onLoaded() end
end
LF.say, LF.ask, LF.nonempty, LF.alert = say, ask, nonempty, alert
LF.count, LF.sentences, LF.list, LF.some = count, sentences, list, some
LF.record, LF.unrecordable, LF.inbox, LF.findLayout, LF.received = record, unrecordable, inbox, findLayout, received
LF.listed, LF.forgetLayout, LF.rename, LF.nameRefused, LF.export, LF.asLayout = listed, forgetLayout, rename, nameRefused, export, asLayout
LF.furnishings, LF.view, LF.tab, LF.HOUSE_FORMAT, LF.FORMAT_VERSION, LF.writerBlock, LF.newId = furnishings, view, tab, HOUSE_FORMAT, FORMAT_VERSION, writerBlock, newId
LF.NAME_MOST = NAME_MOST
local WALK_SPEED = HOUSING_PATH_MOVEMENT_SPEED_WALK or 0
local function delayMs(node)
    if type(node.delay) == "number" then return math.max(0, whole(node.delay)) end
    return 0
end
local function sameWait(ms, node)
    local step = ask(HousingEditorGetPathNodeValueFromDelayTime, ms)
    local wanted = ask(HousingEditorGetPathNodeValueFromDelayTime, delayMs(node))
    if step ~= nil and wanted ~= nil then return step == wanted end
    return math.abs((ms or 0) - delayMs(node)) < 1
end
local function sameNode(game, node)
    local p = type(node.position) == "table" and node.position or {}
    if type(p[1]) ~= "number" or type(p[2]) ~= "number" or type(p[3]) ~= "number" then return true end
    return math.abs(game.position[1] - whole(p[1])) < 1 and math.abs(game.position[2] - whole(p[2])) < 1
        and math.abs(game.position[3] - whole(p[3])) < 1 and sameAngle(game.yaw or 0, tonumber(node.yaw) or 0)
        and (game.speed or WALK_SPEED) == (tonumber(node.speed) or WALK_SPEED) and sameWait(game.delay, node)
end
function LF.pathStepApplied(step)
    local id, i = step.id, step.index
    if not LF.stands(id) then return false end
    if step.action == "pathdata" then
        return HousingEditorGetFurniturePathState(id) == step.state and HousingEditorGetFurniturePathFollowType(id) == step.follow
    elseif step.action == "pathstart" then
        return HousingEditorGetStartingNodeIndexForPath(id) == i
    end
    local count = HousingEditorGetNumPathNodesForFurniture(id)
    if step.op == "remove" then return count == i - 1 end
    if not count or count < i or (step.op == "insert" and count ~= i) then return false end
    local x, y, z = HousingEditorGetPathNodeWorldPosition(id, i)
    local _, yaw = HousingEditorGetPathNodeOrientation(id, i)
    local speed, delay = HousingEditorPathNodeSpeed(id, i), HousingEditorPathNodeDelayTime(id, i)
    if not (x and y and z and yaw and speed and delay) then return false end
    return sameNode({ position = { x, y, z }, yaw = yaw, speed = speed, delay = delay }, step.node)
end
local function usableNodes(path)
    local out = {}
    for _, node in ipairs(type(path) == "table" and type(path.nodes) == "table" and path.nodes or {}) do
        local p = type(node) == "table" and node.position
        if type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" and type(p[3]) == "number" then out[#out + 1] = node end
    end
    return out
end
local function unreadPath(path)
    for _, node in ipairs(type(path) == "table" and type(path.nodes) == "table" and path.nodes or {}) do
        local p = type(node) == "table" and node.position
        if type(p) == "table" and p[1] == 0 and p[2] == 0 and p[3] == 0 then return true end
    end
    return false
end
local function pathOps(id, path, uid)
    if type(path) ~= "table" or unreadPath(path) then return {} end
    local now, unread = recordPath(id)
    if unread then return nil end
    now = now or { nodes = {} }
    local want = usableNodes(path)
    local have = #now.nodes
    local ops = {}
    for i = have, #want + 1, -1 do
        ops[#ops + 1] = { action = "pathnode", op = "remove", id = id, index = i, uid = uid }
    end
    for i = 1, math.min(have, #want) do
        if not sameNode(now.nodes[i], want[i]) then ops[#ops + 1] = { action = "pathnode", op = "modify", id = id, index = i, node = want[i], uid = uid } end
    end
    for i = have + 1, #want do
        ops[#ops + 1] = { action = "pathnode", op = "insert", id = id, index = i, node = want[i], uid = uid }
    end
    local state = tonumber(path.state) or now.state
    local follow = tonumber(path.follow_type) or now.follow_type
    if #want > 0 and (state ~= now.state or follow ~= now.follow_type) and state ~= nil and follow ~= nil then
        ops[#ops + 1] = { action = "pathdata", id = id, state = state, follow = follow, uid = uid }
    end
    local start = tonumber(path.start)
    if start and start >= 0 and start < #want and start ~= (now.start or 0) then
        ops[#ops + 1] = { action = "pathstart", id = id, index = start + 1, uid = uid }
    end
    return ops
end
LF.pathReads = {}
local function noteUnread(id)
    local key = Id64ToString(id)
    local r = LF.pathReads[key]
    if r then return r.state end
    r = { state = "waiting" }
    LF.pathReads[key] = r
    zo_callLater(function()
        if LF.pathReads[key] ~= r then return end
        local _, still = recordPath(id)
        if still then
            r.state = "failed"
            say(zo_strformat(L.core.path_unread_skipped, placedName(id)))
        else
            LF.pathReads[key] = nil
        end
        if LF.onPathsRead then LF.onPathsRead() end
    end, PATH_REREAD_MS)
    return r.state
end
function LF.pathReadFailed(id)
    local r = id and LF.pathReads[Id64ToString(id)]
    return r ~= nil and r.state == "failed"
end
EVENT_MANAGER:RegisterForEvent(LF.name .. "PathReads", EVENT_PLAYER_ACTIVATED, function() LF.pathReads = {} end)
function LF.pathDiffers(id, path)
    if type(path) ~= "table" then return false end
    local ok, ops = pcall(pathOps, id, path)
    if ok and ops == nil then
        noteUnread(id)
        return false
    end
    if ok then LF.pathReads[Id64ToString(id)] = nil end
    return ok and #ops > 0
end
function LF.conformOf(row)
    local path = row.path
    if type(path) ~= "table" or type(path.conform_to_ground) ~= "boolean" or #usableNodes(path) == 0 or unreadPath(path) then return nil end
    return path.conform_to_ground
end
function LF.walking(id)
    if ask(HousingEditorGetFurniturePathState, id) ~= PATH_ON or (ask(HousingEditorGetNumPathNodesForFurniture, id) or 0) == 0 then return nil end
    return ask(HousingEditorGetFurniturePathFollowType, id) or 0
end
function LF.walksRight(id, row)
    local path = row.path
    return type(path) == "table" and tonumber(path.state) == PATH_ON and #usableNodes(path) > 0 and not LF.pathDiffers(id, path)
end
function LF.queueOps(q, ops, parent)
    if LF.queue == q then
        if parent then delegateTask(q, parent, ops) end
        for i, op in ipairs(ops) do table.insert(q.steps, q.index + i, op) end
    elseif not LF.queue then
        start(q.name or (q.done and q.done.name) or "", ops, q.done)
    end
    return { result = REQUESTED }
end
function LF.stands(id)
    local ok, name = pcall(GetPlacedHousingFurnitureInfo, id)
    return ok and type(name) == "string" and name ~= ""
end
function LF.runPathStep(step)
    if step.action == "pathdata" then
        return HousingEditorRequestChangeFurniturePathData(step.id, step.state, step.follow)
    elseif step.action == "pathstart" then
        return HousingEditorRequestSetStartingNodeIndex(step.id, step.index)
    elseif step.op == "remove" then
        return HousingEditorRequestRemovePathNode(step.id, step.index)
    end
    local n, p = step.node, step.node.position
    local request = step.op == "insert" and HousingEditorRequestInsertPathNode or HousingEditorRequestModifyPathNode
    return request(step.id, step.index, whole(p[1]), whole(p[2]), whole(p[3]), tonumber(n.yaw) or 0, tonumber(n.speed) or WALK_SPEED, delayMs(n))
end
function LF.expandPath(q, step)
    local ok, ops = pcall(pathOps, step.id, step.row and step.row.path, step.uid)
    if not ok then
        q.failed = q.failed + 1
        return { result = ERROR, error = tostring(ops) }
    end
    if ops == nil then
        if not step.pathRetried and LF.queue == q then
            step.pathRetried = true
            LF.trace(q, "skipped", step, { why = "path_unread", retry_ms = PATH_REREAD_MS })
            q.retry, q.retryTicks = step, math.ceil(PATH_REREAD_MS / stepDelay())
            return { result = REQUESTED }
        end
        q.failed = q.failed + 1
        if not step.pathRetried then LF.trace(q, "skipped", step, { why = "path_unread" }) end
        say(zo_strformat(L.core.path_unread_skipped, placedName(step.id)))
        return { result = SKIPPED }
    end
    if step.pathRetried then LF.solved(step, "retried") end
    if #ops == 0 then
        completeTask(q, step)
        return { result = PATHED, game_id = Id64ToString(step.id) }
    end
    LF.queueOps(q, ops, step)
    return { result = REQUESTED, game_id = Id64ToString(step.id) }
end
local function pathAnswered(event, id, index)
    local c = LF.queue and LF.queue.check
    local matched = c and c.path and event == c.event and id and Id64ToString(id) == Id64ToString(c.step.id) and index == c.step.index
    if LF.debugEntry then
        local operation
        for op, code in pairs(pathEvents) do if code == event then operation = op end end
        LF.debugEntry("path_event", LF.queue, c and c.step, { event = event, furniture = id and Id64ToString(id), index = index,
                      operation = operation, expected_event = c and c.event, matched = matched == true, observed = LF.debugState(id, index) })
    end
    if matched then
        c.answered = true
    end
end
for _, event in pairs(pathEvents) do
    EVENT_MANAGER:RegisterForEvent(LF.name .. "Path", event, pathAnswered)
end
local function pathWaits()
    local last = HOUSING_PATH_DELAY_TIME_EXTREMELY_LONG
    if type(last) ~= "number" or type(HousingEditorGetPathNodeDelayTimeFromValue) ~= "function" then return nil end
    local out = {}
    for v = 0, math.min(last, 30) do out[#out + 1] = ask(HousingEditorGetPathNodeDelayTimeFromValue, v) end
    return #out > 0 and out or nil
end
LF.pathWaits = pathWaits
LF.plan, LF.appliedOf, LF.forget = plan, appliedOf, forget
LF.placedIds, LF.whatIs, LF.rowWhat, LF.bagName, LF.usable = placedIds, whatIs, rowWhat, bagName, usable
LF.tally, LF.perform, LF.start = tally, perform, start
LF.sameHouse = sameHouse
LF.FULL, LF.SKIPPED, LF.SPEEDS, LF.stepDelay = FULL, SKIPPED, SPEEDS, stepDelay
function LF.setSpeed(ms)
    for _, known in ipairs(SPEEDS) do
        if known == ms then
            LF.saved.speed = ms ~= LF.delay and ms or nil
            if LF.queue then EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, stepDelay(), onTick) end
            return true
        end
    end
    return false
end
LF.SITE, LF.openSite = L._site, openSite
do
    local limit, trim = 4096, 512
    local function tripleCopy(v)
        if v then return { v[1], v[2], v[3] } end
    end
    local function write(kind, q, step, entry)
        if unrecordable() == L.core.not_yours then return end
        local log = LF.saved.debugLog
        local rows = log.entries
        if #rows >= limit then
            local n = #rows
            for i = 1, n - trim do rows[i] = rows[i + trim] end
            for i = n - trim + 1, n do rows[i] = nil end
            log.dropped = log.dropped + trim
        end
        entry = entry or {}
        entry.kind, entry.time, entry.game_ms, entry.house = kind, GetTimeStamp(), gameMs(), GetCurrentZoneHouseId()
        if q then
            entry.run, entry.step = q.name or (q.done and q.done.name), q.index
            entry.run_ms = q.log and entry.game_ms - q.log.started_ms or nil
        end
        if step then
            entry.action, entry.uid, entry.op, entry.node = step.action, step.uid, step.op, step.index
            entry.placement_phase = (step.settlePlacement and "settling") or (step.correctPlacement and "correction") or nil
            entry.id, entry.state, entry.follow = step.id and Id64ToString(step.id), step.state, step.follow
            entry.destination, entry.name = step.into, step.name
            local row = step.row
            if row then
                entry.thing, entry.position, entry.rotation = rowWhat(row), tripleCopy(row.position), tripleCopy(row.rotation)
            end
            if step.node then
                entry.position, entry.yaw, entry.speed, entry.delay = tripleCopy(step.node.position), step.node.yaw, step.node.speed, step.node.delay
            end
        end
        rows[#rows + 1] = entry
    end
    function LF.debugState(id, i)
        if not id then return nil end
        local x, y, z = ask(HousingEditorGetFurnitureWorldPosition, id)
        local p, yaw, r = ask(HousingEditorGetFurnitureOrientation, id)
        local nodes = ask(HousingEditorGetNumPathNodesForFurniture, id)
        local seen = { position = x and { x, y, z }, rotation = p and { p, yaw, r }, name = ask(GetPlacedHousingFurnitureInfo, id),
                       state = ask(GetPlacedHousingFurnitureCurrentObjectStateIndex, id), nodes = nodes }
        if nodes and nodes > 0 then
            seen.path_state, seen.follow = ask(HousingEditorGetFurniturePathState, id), ask(HousingEditorGetFurniturePathFollowType, id)
            seen.start = ask(HousingEditorGetStartingNodeIndexForPath, id)
            if i and i >= 1 and i <= nodes then
                seen.node_position = { ask(HousingEditorGetPathNodeWorldPosition, id, i) }
                seen.node_rotation = { ask(HousingEditorGetPathNodeOrientation, id, i) }
                seen.speed, seen.delay = ask(HousingEditorPathNodeSpeed, id, i), ask(HousingEditorPathNodeDelayTime, id, i)
            end
        end
        return seen
    end
    local observers = {
        EVENT_HOUSING_EDITOR_REQUEST_RESULT = function(_, code)
            write("housing_result", LF.queue, nil, { code = code, answer = ask(GetString, "SI_HOUSINGREQUESTRESULT", code) })
        end,
        EVENT_HOUSING_FURNITURE_STATE_CHANGED = function(_, id, state, previous, source, reason)
            write("state_event", LF.queue, nil, { furniture = Id64ToString(id), state = state, previous = previous,
                  source = source and Id64ToString(source), reason = reason })
        end,
        EVENT_HOUSING_FURNITURE_MOVED = function(_, id)
            write("moved_event", LF.queue, nil, { furniture = Id64ToString(id), observed = LF.debugState(id) })
        end,
        EVENT_HOUSING_FURNITURE_REMOVED = function(_, id, collectible)
            write("removed_event", LF.queue, nil, { furniture = Id64ToString(id), collectible = collectible })
        end,
        EVENT_LUA_ERROR = function(_, message, code)
            if type(message) == "string" and string.find(string.lower(message), "addons/letsfurnish/", 1, true) then
                write("lua_error", LF.queue, nil, { error = string.sub(message, 1, 4096), code = code })
            end
        end,
    }
    function LF.setDebug(on)
        if on == (LF.debugEntry ~= nil) then return end
        LF.saved.debugEnabled = on or nil
        if on then
            LF.saved.debugLog = LF.saved.debugLog or { entries = {}, dropped = 0 }
            LF.debugEntry = write
            write("debug_on", LF.queue, nil, { build = LF.build, api = ask(GetAPIVersion), speed_ms = stepDelay() })
        else
            write("debug_off", LF.queue)
            LF.debugEntry = nil
        end
        for name, handler in pairs(observers) do
            local event = _G[name]
            if event then
                if on then EVENT_MANAGER:RegisterForEvent(LF.name .. "Debug", event, handler)
                else EVENT_MANAGER:UnregisterForEvent(LF.name .. "Debug", event) end
            end
        end
    end
end
EVENT_MANAGER:RegisterForEvent(LF.name, EVENT_ADD_ON_LOADED, onLoaded)
