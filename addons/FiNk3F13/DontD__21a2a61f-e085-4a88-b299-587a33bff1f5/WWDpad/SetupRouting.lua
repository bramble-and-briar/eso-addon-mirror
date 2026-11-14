-- Explicit button-driven routing only. No enemy, room or target detection.
WWDpadRouting = {}
local R = WWDpadRouting
local config, say
local cursors, diverted = {}, {}

local function Trim(name)
    return type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
end

local function Normalize(name)
    name = Trim(name)
    if zo_strformat then name = zo_strformat("<<1>>", name) end
    return (zo_strlower or string.lower)(name)
end

local function Context()
    local ww = WizardsWardrobe
    local zone, pageId = ww.selection.zone, ww.selection.pageId
    local character = ww.storage and ww.storage.selectedCharacterId or ww.currentCharacterId or "player"
    local key = tostring(character) .. ":" .. zone.tag .. ":" .. tostring(pageId)
    if not diverted[key] then cursors[key] = ww.currentIndex end
    if cursors[key] == nil then cursors[key] = ww.currentIndex end
    local page = ww.setups and ww.setups[zone.tag] and ww.setups[zone.tag][pageId]
    return key, zone, pageId, page, cursors[key]
end

local function Indices(page)
    local indices = {}
    for index, setup in pairs(page) do
        if type(index) == "number" and index > 0 and type(setup) == "table" then indices[#indices + 1] = index end
    end
    table.sort(indices)
    return indices
end

local function MakePlan(key, zone, pageId, page, index, direct)
    return {zone = zone, pageId = pageId, index = index, context = key, direct = direct, setupRef = page[index]}
end

function R.Plan(direct, quiet)
    local function Report(message) if not quiet then say(message) end end
    local key, zone, pageId, page, currentIndex = Context()
    if type(page) ~= "table" or not next(page) then
        Report("Keine Setups auf der ausgewaehlten WW-Seite.")
        return
    end
    if direct then
        local target = Normalize(config.targetSetupName)
        if target == "" then
            Report("Fuer Hotkey 2 zuerst einen Setupnamen eintragen, z.B. Miniboss.")
            return
        end
        local match
        for index, setup in pairs(page) do
            if type(index) == "number" and index > 0 and type(setup) == "table"
                and Normalize(setup.name) == target then
                if match then
                    Report("Setupname ist mehrfach vorhanden. Bitte einen eindeutigen Namen verwenden.")
                    return
                end
                match = index
            end
        end
        if not match then
            Report("Setup nicht auf dieser WW-Seite gefunden: " .. config.targetSetupName)
            return
        end
        return MakePlan(key, zone, pageId, page, match, true)
    end
    local indices = Indices(page)
    if #indices == 0 then say("Keine Setups auf der ausgewaehlten WW-Seite."); return end
    local index = indices[1]
    for _, candidate in ipairs(indices) do
        if candidate > currentIndex then index = candidate; break end
    end
    local plan = MakePlan(key, zone, pageId, page, index, false)
    plan.adjacent = not diverted[key]
    return plan
end

function R.IsCurrent(plan)
    local key, _, _, page = Context()
    return plan and key == plan.context and page and page[plan.index] == plan.setupRef
end

function R.PlanForBoss(name)
    local key, zone, pageId, page = Context()
    if type(page) ~= "table" then return end
    local target = Normalize(name)
    if target == "" then return end
    -- Explicit WW conditions take precedence over setup labels.
    for pass = 1, 2 do
        local match
        for _, index in ipairs(Indices(page)) do
            local setup = page[index]
            local value = pass == 1 and setup.condition and setup.condition.boss or (pass == 2 and setup.name)
            if type(value) == "string" and Normalize(value) == target then
                if match then return end -- ambiguous: do not guess
                match = index
            end
        end
        if match then return MakePlan(key, zone, pageId, page, match, true) end
    end
end

function R.Commit(plan)
    if not plan then return end
    if plan.direct then
        diverted[plan.context] = true
    else
        cursors[plan.context] = plan.adjacent and WizardsWardrobe.currentIndex or plan.index
        diverted[plan.context] = nil
    end
end

function R.GetTargetName() return config.targetSetupName end
function R.SetTargetName(name) config.targetSetupName = Trim(name) end

function R.UseLoadedName()
    local ww = WizardsWardrobe
    local page = ww.setups and ww.setups[ww.selection.zone.tag]
        and ww.setups[ww.selection.zone.tag][ww.selection.pageId]
    local setup = page and page[ww.currentIndex]
    if not setup or Trim(setup.name) == "" then
        say("Zuerst das gewuenschte Setup in WW laden.")
        return
    end
    R.SetTargetName(setup.name)
    say("Ziel fuer Hotkey 2: " .. config.targetSetupName)
end

function R.Initialize(settings, output)
    config, say = settings, output
    config.targetSetupName = Trim(config.targetSetupName)
end
