-- ErrorCatcherLoadActions.lua: the add-on load order, and when each untrusted game function was wrapped
--
-- HookActions sees who calls ZO_PreHook / ZO_PostHook, but only once this add-on has loaded, and not a
-- function replaced by plain assignment. The scan lists every untrusted game function, but not who made it
-- so. This joins the two: the names the last scan listed are checked again at this add-on's own load event
-- (untrusted already: wrapped by an add-on that loaded before) and at every later add-on's load event (newly
-- untrusted: wrapped by that add-on). Which add-ons loaded before comes from the game's add-on list.
local LoadActions = {}

local Log = ErrorCatcher.LogUtils
local GameUtils = ErrorCatcher.GameUtils
local LoadUtils = ErrorCatcher.LoadUtils
local ScanUtils = ErrorCatcher.ScanUtils

-- Add-ons recorded as loading after this one, and names followed from one scan to the next.
local MAX_LOADED = 400
local MAX_WATCHED = 600
local MAX_LINE_CHARS = 220

---Check the names still trusted so far; the ones untrusted now were wrapped since the last check.
---@param moment string LoadUtils.BEFORE, LoadUtils.AFTER or the add-on whose load event this is
---@param previous string|nil The add-on loaded just before
local function Check(moment, previous)
    local state = ErrorCatcher.state
    local load = state.load
    if not state.trustApi or #load.pending == 0 then
        return
    end
    local still, found = {}, nil
    for _, name in ipairs(load.pending) do
        local fn = LoadUtils.Resolve(name, _G)
        if fn and GameUtils.IsTrusted(fn) == false then
            found = found or {}
            found[#found + 1] = name
        else
            still[#still + 1] = name
        end
    end
    load.pending = still
    if found then
        load.groups[#load.groups + 1] = { title = LoadUtils.Title(moment, previous), names = found }
    end
end

---At this add-on's own load event, once its saved variables are attached: take up the last scan's names.
---What is untrusted already was wrapped by an add-on that loaded before this one.
function LoadActions.StartWatch()
    local state = ErrorCatcher.state
    local load = state.load
    local names = state.savedVars.watchNames
    load.pending = {}
    load.watched = {}
    if type(names) == "table" then
        for index = 1, math.min(#names, MAX_WATCHED) do
            local name = names[index]
            if type(name) == "string" and not load.watched[name] then
                load.watched[name] = true
                load.pending[#load.pending + 1] = name
            end
        end
    end
    load.following = #load.pending > 0
    Check(LoadUtils.BEFORE, nil)

    -- Which of the add-ons that loaded after this one last time have their global already: if any does, the
    -- game runs every add-on's files before the first load event.
    local previous = state.savedVars.loadOrder
    if type(previous) == "table" and type(previous.after) == "table" then
        for index = 1, math.min(#previous.after, MAX_LOADED) do
            local name = previous.after[index]
            if type(name) == "string" then
                load.early[name] = GameUtils.HasGlobal(name)
            end
        end
    end
end

---At the load event of an add-on after this one.
---@param addonName any
function LoadActions.OnOtherLoaded(addonName)
    local load = ErrorCatcher.state.load
    local name = tostring(addonName)
    if #load.after < MAX_LOADED then
        load.after[#load.after + 1] = name
    end
    Check(name, load.previous)
    load.previous = name
end

---Ask the game which add-ons are enabled. Run in a step of its own, so the scan does not hang on it.
function LoadActions.ReadEnabled()
    local load = ErrorCatcher.state.load
    if type(GetAddOnManager) ~= "function" then
        return
    end
    local manager = GetAddOnManager()
    local enabled = {}
    for index = 1, manager:GetNumAddOns() do
        local name, _title, _author, _description, isEnabled, loadState = manager:GetAddOnInfo(index)
        if isEnabled and (ADDON_STATE_ENABLED == nil or loadState == ADDON_STATE_ENABLED) and type(name) == "string" then
            enabled[#enabled + 1] = name
            load.listNumber[name] = index
        end
    end
    load.enabled = enabled
end

---The load order as lines: where this add-on stood, who loaded before it (their order is not seen) and who
---after it, in order, each with its number in the game's add-on list.
---@return string[] lines
local function OrderLines()
    local state = ErrorCatcher.state
    local load = state.load
    local lines = {}
    local function Add(title, names)
        for _, line in ipairs(ScanUtils.Pack(title, LoadUtils.Numbered(names, load.listNumber), MAX_LINE_CHARS)) do
            lines[#lines + 1] = line
        end
    end
    if not load.enabled then
        lines[#lines + 1] = "load order: add-ons loaded before this one are not known (the game gave no add-on list)"
    else
        local before = LoadUtils.Before(load.enabled, load.after, ErrorCatcher.name)
        lines[#lines + 1] = LoadUtils.OrderLine(#before + 1, #before + 1 + #load.after, load.after, load.previousOrder)
        if #before > 0 then
            Add(string.format("add-ons loaded before this one (%d)", #before), before)
        else
            lines[#lines + 1] = "add-ons loaded before this one: none"
        end
    end
    if #load.after > 0 then
        Add(string.format("add-ons loaded after this one (%d), in order", #load.after), load.after)
    end
    local tested, early = 0, 0
    for _, name in ipairs(load.after) do
        if load.early[name] ~= nil and GameUtils.HasGlobal(name) then
            tested = tested + 1
            if load.early[name] then
                early = early + 1
            end
        end
    end
    lines[#lines + 1] = LoadUtils.FilesFirstLine(tested, early)
    return lines
end

---Write the load order, once per UI load, in a queued step after the add-on list was read; and keep it for
---the next UI load to compare with.
function LoadActions.WriteOrder()
    local state = ErrorCatcher.state
    local load = state.load
    local sv = state.savedVars
    load.previousOrder = type(sv.loadOrder) == "table" and sv.loadOrder or nil
    for _, line in ipairs(OrderLines()) do
        Log.Line("%s", line)
    end
    local after = {}
    for index, name in ipairs(load.after) do
        after[index] = name
    end
    local before = load.enabled and LoadUtils.Before(load.enabled, load.after, ErrorCatcher.name) or {}
    sv.loadOrder = {
        character = GameUtils.CharacterName(),
        position = #before + 1,
        total = #before + 1 + #after,
        after = after,
    }
end

---The load order again, for "/ec order".
---@return string[] lines
function LoadActions.DescribeOrder()
    return OrderLines()
end

---The moments of wrapping, as lines for the scan's listing (the load order they refer to is written on
---entering the world, by WriteOrder); then the scan's names become the ones followed on the next UI load.
---@param untrusted string[] Every name this scan found untrusted
---@return string[] lines
function LoadActions.Finish(untrusted)
    local state = ErrorCatcher.state
    local load = state.load
    Check(LoadUtils.AFTER, nil)

    local lines = {}
    local function Add(title, names)
        for _, line in ipairs(ScanUtils.Pack(title, names, MAX_LINE_CHARS)) do
            lines[#lines + 1] = line
        end
    end

    if state.trustApi then
        if load.following then
            for _, group in ipairs(load.groups) do
                Add(group.title, group.names)
            end
        else
            lines[#lines + 1] = "when each was wrapped: not known on this UI load (no earlier scan to follow); the next one says"
        end
        local new = {}
        for _, name in ipairs(untrusted) do
            if load.following and not load.watched[name] then
                new[#new + 1] = name
            end
        end
        Add("first seen untrusted on this scan, followed from the next UI load", new)

        local watchNames = {}
        for index = 1, math.min(#untrusted, MAX_WATCHED) do
            watchNames[index] = untrusted[index]
        end
        state.savedVars.watchNames = watchNames
    end
    return lines
end

ErrorCatcher.LoadActions = LoadActions
