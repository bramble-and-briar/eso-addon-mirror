-- Lethal PVP Insights - show our keybind category first in Controls > Addon Keybinds
-- The game lists keybind categories in the order the addons were loaded. We move
-- our category in KEYBINDINGS_MANAGER's data so it is the first addon category.
local PDI = PVPDataInsight
local K = {}
PDI.Keybinds = K

local OUR_ACTION = "PVPDI_TOGGLE"
K.diag = {}

local KNOWN = { layerIndex = true, categoryIndex = true, categoryName = true, actions = true,
    actionName = true, localizedActionName = true, localizedActionNameNarration = true,
    isRebindable = true, actionIndex = true, dataSource = true, layerName = true, categories = true }

local function src(d)
    if type(d) == "table" and d.GetDataSource then
        local ok, s = pcall(d.GetDataSource, d)
        if ok and type(s) == "table" then return s end
    end
    return d
end

local function isOurs(cat)
    for _, a in ipairs(src(cat).actions or {}) do
        if src(a).actionName == OUR_ACTION then return true end
    end
end

-- Unknown true/false fields on a category (or its first action) that may mark addon categories
local function flagsOf(cat)
    local f = {}
    local s = src(cat)
    for k, v in pairs(s) do
        if not KNOWN[k] and type(v) == "boolean" then f["c." .. k] = v end
    end
    local a = s.actions and s.actions[1] and src(s.actions[1])
    if a then
        for k, v in pairs(a) do
            if not KNOWN[k] and type(v) == "boolean" then f["a." .. k] = v end
        end
    end
    -- extra return values of the category / action info functions
    local r = { pcall(GetActionLayerCategoryInfo, s.layerIndex, s.categoryIndex) }
    for i = 4, #r do if type(r[i]) == "boolean" then f["cinfo" .. i] = r[i] end end
    if a then
        r = { pcall(GetActionInfo, s.layerIndex, s.categoryIndex, a.actionIndex) }
        for i = 5, #r do if type(r[i]) == "boolean" then f["ainfo" .. i] = r[i] end end
    end
    return f
end

-- Global API functions such as Is...AddOn... that answer per category or per action
local apiFns
local function addonApis()
    if apiFns then return apiFns end
    apiFns = {}
    for name, fn in pairs(_G) do
        if type(fn) == "function" and type(name) == "string" and name:find("AddOn") and
           (name:find("Action") or name:find("Keybind") or name:find("Binding")) and name:find("^Is") then
            apiFns[#apiFns + 1] = name
        end
    end
    return apiFns
end

local function apiFlags(cat)
    local f = {}
    local s = src(cat)
    local a = s.actions and s.actions[1] and src(s.actions[1])
    for _, name in ipairs(addonApis()) do
        local ok, v = pcall(_G[name], s.layerIndex, s.categoryIndex)
        if ok and type(v) == "boolean" then f["api2." .. name] = v end
        if a then
            ok, v = pcall(_G[name], s.layerIndex, s.categoryIndex, a.actionIndex)
            if ok and type(v) == "boolean" then f["api3." .. name] = v end
            ok, v = pcall(_G[name], a.actionName)
            if ok and type(v) == "boolean" then f["apiN." .. name] = v end
        end
    end
    return f
end

local function allFlags(cat)
    local f = flagsOf(cat)
    for k, v in pairs(apiFlags(cat)) do f[k] = v end
    return f
end

-- Find the marker: true on our category and false on the layer's first category (a game one)
local function findMarker(cats, ourPos)
    local ours = allFlags(cats[ourPos])
    local first = allFlags(cats[1])
    for k, v in pairs(ours) do
        if v == true and first[k] == false then return k end
    end
end

function K:Reorder()
    local mgr = KEYBINDINGS_MANAGER
    local layers = mgr and mgr.keybindLayers
    if type(layers) ~= "table" then return end
    for _, layer in ipairs(layers) do
        local cats = src(layer).categories
        if type(cats) == "table" then
            local ourPos
            for i, c in ipairs(cats) do if isOurs(c) then ourPos = i; break end end
            if ourPos and ourPos > 1 then
                local marker = findMarker(cats, ourPos)
                self.diag.marker = marker or "none"
                if marker then
                    for i = 1, ourPos - 1 do
                        if allFlags(cats[i])[marker] == true then
                            table.insert(cats, i, table.remove(cats, ourPos))
                            self.diag.moved = ourPos .. " -> " .. i
                            break
                        end
                    end
                end
            end
        end
    end
end

function K:Init()
    local mgr = KEYBINDINGS_MANAGER
    if not mgr or not mgr.InitializeKeybindData then return end
    local hook = SecurePostHook or ZO_PostHook
    hook(mgr, "InitializeKeybindData", function() pcall(K.Reorder, K) end)
    pcall(K.Reorder, K)
end

-- /lpi keybinds : what the reorder found (to send to the author if the position is wrong)
function K:PrintDiagnostics()
    PDI.Msg("Keybind order: marker=" .. tostring(self.diag.marker) .. ", moved=" .. tostring(self.diag.moved or "no"))
    local layers = KEYBINDINGS_MANAGER and KEYBINDINGS_MANAGER.keybindLayers or {}
    for _, layer in ipairs(layers) do
        local cats = src(layer).categories or {}
        for i, c in ipairs(cats) do
            if isOurs(c) or i == 1 then
                local parts = {}
                for k, v in pairs(allFlags(c)) do parts[#parts + 1] = k .. "=" .. tostring(v) end
                PDI.Msg(string.format("%s #%d %s: %s", tostring(src(layer).layerName), i,
                    isOurs(c) and "LPI" or "first", table.concat(parts, " ")))
            end
        end
    end
end
