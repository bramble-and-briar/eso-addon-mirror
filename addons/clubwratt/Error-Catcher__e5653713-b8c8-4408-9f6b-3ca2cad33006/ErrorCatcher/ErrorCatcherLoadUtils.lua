-- ErrorCatcherLoadUtils.lua: naming when a game function was wrapped, and the add-on load order (pure)
local LoadUtils = {}

-- Moments a watched function can first read untrusted, besides the load of a named add-on.
LoadUtils.BEFORE = "(before)"
LoadUtils.AFTER = "(after)"

---The parts of a scan name: "TABLE.Member" is a table and its member, "ZO_Function" a global.
---@param name string
---@return string|nil tableName, string member
function LoadUtils.Split(name)
    local tableName, member = string.match(name, "^([^.]+)%.(.+)$")
    if tableName then
        return tableName, member
    end
    return nil, name
end

---The function a scan name stands for right now; nil when there is none (yet).
---@param name string
---@param globals table
---@return function|nil
function LoadUtils.Resolve(name, globals)
    local tableName, member = LoadUtils.Split(name)
    local holder = globals
    if tableName then
        holder = globals[tableName]
        if type(holder) ~= "table" then
            return nil
        end
    end
    local ok, value = pcall(function() return holder[member] end)
    if ok and type(value) == "function" then
        return value
    end
    return nil
end

---Add-ons the game has enabled that were not seen loading after this one: they loaded before it.
---@param enabled string[]
---@param after string[]
---@param own string
---@return string[] before Sorted
function LoadUtils.Before(enabled, after, own)
    local seen = { [own] = true }
    for _, name in ipairs(after) do
        seen[name] = true
    end
    local before = {}
    for _, name in ipairs(enabled) do
        if not seen[name] then
            seen[name] = true
            before[#before + 1] = name
        end
    end
    table.sort(before)
    return before
end

---The heading for the functions first seen untrusted at one moment. A function is checked when an add-on's
---load event arrives, which is after that add-on's files ran but before its own handler of the event; what
---the handler wraps shows at the next add-on's event, so both are named.
---@param moment string LoadUtils.BEFORE, LoadUtils.AFTER or the add-on whose load event it was
---@param previous string|nil The add-on loaded just before, when it is not this one
---@return string
function LoadUtils.Title(moment, previous)
    if moment == LoadUtils.BEFORE then
        return "wrapped before this add-on loaded"
    end
    if moment == LoadUtils.AFTER then
        return "wrapped after the add-ons loaded"
    end
    if previous then
        return string.format("wrapped by the time %s had loaded (its files, or the load handler of %s)", moment, previous)
    end
    return string.format("wrapped by the time %s had loaded (its files)", moment)
end

---Names with their number in the game's add-on list, to see whether the load order follows that list.
---@param names string[]
---@param listNumber table<string, number>
---@return string[] "AddOn #12"
function LoadUtils.Numbered(names, listNumber)
    local numbered = {}
    for index, name in ipairs(names) do
        numbered[index] = listNumber[name] and string.format("%s #%d", name, listNumber[name]) or name
    end
    return numbered
end

---@param left string[]|nil
---@param right string[]
---@return boolean
function LoadUtils.SameList(left, right)
    if type(left) ~= "table" or #left ~= #right then
        return false
    end
    for index = 1, #right do
        if left[index] ~= right[index] then
            return false
        end
    end
    return true
end

---Where this add-on stood in the load, against the UI load before.
---@param position number Its load event was the position-th
---@param total number Add-ons enabled
---@param after string[] Add-ons loaded after it, in order
---@param previous ErrorCatcherLoadOrder|nil
---@return string
function LoadUtils.OrderLine(position, total, after, previous)
    local line = string.format("load order: this add-on's load event was #%d of %d enabled add-ons", position, total)
    if type(previous) ~= "table" or type(previous.position) ~= "number" then
        return line .. "; no earlier UI load to compare with"
    end
    return string.format("%s; on the UI load before (%s) it was #%d of %d, and the add-ons after it %s",
        line, tostring(previous.character or "?"), previous.position, tonumber(previous.total) or 0,
        LoadUtils.SameList(previous.after, after) and "are the same in the same order" or "differ, or their order does")
end

---What it means that add-ons loaded after this one had their global already at this add-on's own load event.
---@param tested number Add-ons after this one that have a global of their own name
---@param early number Of those, the ones that had it already at this add-on's own load event
---@return string
function LoadUtils.FilesFirstLine(tested, early)
    if tested == 0 then
        return "files before events check: nothing to go by yet (it needs the load order of the UI load before; the next UI load says)"
    end
    local verdict
    if early == 0 then
        verdict = "each add-on's files run just before its own load event"
    elseif early == tested then
        verdict = "every add-on's files run before the first load event, so a figure per load event holds saved variables and load handlers only"
    else
        verdict = "some files run early and some do not"
    end
    return string.format("files before events check: of the %d add-ons after this one that have a global of their own name, %d had it already at this add-on's own load event: %s",
        tested, early, verdict)
end

ErrorCatcher.LoadUtils = LoadUtils
