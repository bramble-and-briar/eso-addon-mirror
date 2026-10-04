local S = PBS_HUD_MANAGER_STRINGS

PBS_HUD_MANAGER = {
    name = "PBsHudManager", baseTitle = "PB’s HudManager", author = "PinkBanther", version = "1.0.2",
    slotCount = 3, nameMaxChars = 24, confirmMs = 10000, reloadDelayMs = 600,
    defaults = { initialized = false, slots = {} },
}
local A = PBS_HUD_MANAGER

-- Same as the other PB add-ons: the version is read back from the manifest's ## Title.
local manager = GetAddOnManager and GetAddOnManager()
if manager then
    for index = 1, manager:GetNumAddOns() do
        local name, title = manager:GetAddOnInfo(index)
        if name == A.name and title then
            local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
            A.version = plain:match("(%d+[%d%.]*)%s*$") or A.version
            break
        end
    end
end
A.title = A.baseTitle .. " " .. A.version

-- ---------------------------------------------------------------------------------------
-- The add-ons whose settings are switched
--
-- `global` is the table each add-on publishes, `store` the field of it that holds its saved
-- settings (the table ZO_SavedVars:NewAccountWide returned). An add-on counts as installed
-- when both exist, which is also true of one that is installed but turned off: its global is
-- simply never created.
--
-- `exclude` lists the top-level keys that are NOT settings and must stay as they are: what the
-- client measured, the stock font an add-on captured so that "reset" can put it back, and the
-- markers of a one-off migration, which would run again on a restored value. Everything else
-- at the top level is copied, so a setting added to an add-on later is switched without this
-- file knowing about it -- and so are the ones an add-on only stores once they are changed,
-- which are not in its defaults at all (the minimap's position, for one).
-- ---------------------------------------------------------------------------------------

local function set(list)
    local out = {}
    for _, key in ipairs(list) do out[key] = true end
    return out
end

A.targets = {
    { id = "PBsConsoleHudCustomizer", label = "PB’s ResourceAndSkillBarCustomizer",
        global = "PBS_CONSOLE_HUD_CUSTOMIZER", store = "account", exclude = set({ "measured" }) },
    { id = "PBsClock", label = "PB’s Clock",
        global = "PBS_CLOCK", store = "sv",
        -- Fields of the layout before 1.2, kept by the clock only so it can still migrate them.
        exclude = set({ "x", "y", "size", "fontSize", "analogX", "analogY", "analogFontSize" }) },
    { id = "PBsChatWindowCustomizer", label = "PB’s ChatWindowCustomizer",
        global = "PBS_CHAT_WINDOW_CUSTOMIZER", store = "account", exclude = set({ "measured" }) },
    { id = "PBsCyrodiilAlert", label = "PB’s CyrodiilAlert",
        global = "PBS_CYRODIIL_ALERT", store = "sv", exclude = set({}) },
    { id = "PBsMiniMap", label = "PB’s MiniMap",
        global = "PBS_MINIMAP", store = "account",
        exclude = set({ "bgScaleRetuned", "hideMapLabels", "debug", "diagLog" }) },
    { id = "PBsNamePlateChanger", label = "PB’s NamePlateChanger",
        global = "PBS_NAMEPLATE_CHANGER", store = "account",
        exclude = set({ "originalCaptured", "originalGamepadFont", "originalGamepadStyle",
            "originalKeyboardFont", "originalKeyboardStyle", "diag" }) },
    { id = "PBsQuestTrackerFontChanger", label = "PB’s QuestTrackerFontChanger",
        global = "PBS_QUEST_TRACKER_FONT_CHANGER", store = "account", exclude = set({ "measured" }) },
}

-- The saved-settings table of an add-on, or nil if it is not there.
function A:Store(target)
    local root = _G[target.global]
    if type(root) ~= "table" then return nil end
    local store = root[target.store]
    if type(store) ~= "table" then return nil end
    return store
end

function A:InstalledTargets()
    local list = {}
    for _, target in ipairs(self.targets) do
        if self:Store(target) then list[#list + 1] = target end
    end
    return list
end

-- ZO_SavedVars keeps its own bookkeeping inside the settings table: the version, and for a
-- character-wide table the name it was last used under. None of it belongs to a set.
local ALWAYS_IGNORED = { version = true }
function A:Ignored(target, key)
    if type(key) ~= "string" then return false end
    return ALWAYS_IGNORED[key] == true or key:sub(1, 1) == "$" or target.exclude[key] == true
end

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for k, v in pairs(value) do out[copy(k, seen)] = copy(v, seen) end
    return out
end
A.Copy = copy

-- What the add-on is set to now: its settings table minus what is not a setting. A copy, so a
-- set never shares a table with a live setting.
function A:Capture(target)
    local store = self:Store(target)
    if not store then return nil end
    local out = {}
    for key, value in pairs(store) do
        if not self:Ignored(target, key) then out[key] = copy(value) end
    end
    return out
end

-- Puts saved values into the add-on's own settings table, in place. The table itself is never
-- replaced: the add-on holds it, and it is the one the game writes out on reload. Keys that
-- are not in the set are removed, so a setting that was at the game's own value when the set
-- was saved is back at it, rather than left at whatever it has been changed to since.
function A:Restore(target, data)
    local store = self:Store(target)
    if not store or type(data) ~= "table" then return false end
    local stale = {}
    for key in pairs(store) do
        if not self:Ignored(target, key) then stale[#stale + 1] = key end
    end
    for _, key in ipairs(stale) do store[key] = nil end
    for key, value in pairs(data) do
        if not self:Ignored(target, key) then store[key] = copy(value) end
    end
    return true
end

-- ---------------------------------------------------------------------------------------
-- The sets
-- ---------------------------------------------------------------------------------------

function A:ValidSlot(index)
    index = tonumber(index)
    if not index or index ~= math.floor(index) or index < 1 or index > self.slotCount then return nil end
    return index
end

local function truncate(text, max)
    local count, position = 0, 1
    for character in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > max then return text:sub(1, position - 1) end
        position = position + #character
    end
    return text
end

function A:CleanName(name)
    if type(name) ~= "string" then return "" end
    name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    return truncate(name, self.nameMaxChars)
end

-- Fills {name}-style placeholders in a string from a table. A placeholder with no value is left
-- as it is, so a mistake shows in the text instead of raising an error in the middle of a
-- button press.
function A:Format(text, values)
    return (text:gsub("{(%w+)}", function(key)
        local value = values[key]
        if value == nil then return "{" .. key .. "}" end
        return tostring(value)
    end))
end

function A:DefaultName(index)
    return self:Format(S.defaultName, { set = index })
end

function A:Slot(index)
    return self.sv.slots[index]
end

function A:SlotName(index)
    local slot = self:Slot(index)
    return slot and slot.name or self:DefaultName(index)
end

function A:SlotAddonCount(index)
    local slot, count = self:Slot(index), 0
    if slot then
        for _, data in pairs(slot.addons) do
            if type(data) == "table" then count = count + 1 end
        end
    end
    return count
end

-- The installed add-ons that this set holds settings for.
function A:SlotTargets(index)
    local slot, list = self:Slot(index), {}
    if slot then
        for _, target in ipairs(self:InstalledTargets()) do
            if type(slot.addons[target.id]) == "table" then list[#list + 1] = target end
        end
    end
    return list
end

local function stamp(timestamp)
    if type(timestamp) ~= "number" or type(os) ~= "table" or type(os.date) ~= "function" then return nil end
    local ok, text = pcall(os.date, "%Y-%m-%d %H:%M", timestamp)
    return ok and text or nil
end

-- The heading of a set in the panel: the name the player gave it, which is what tells one set
-- from another. A set that is still empty has only its number.
function A:SlotTitle(index)
    local slot = self:Slot(index)
    if not slot then return self:Format(S.slotTitleEmpty, { set = index }) end
    return self:Format(S.slotTitle, { set = index, name = slot.name })
end

-- When it was saved and how many add-ons it holds.
function A:SlotDetail(index)
    local slot = self:Slot(index)
    if not slot then return S.summaryEmpty end
    local values = { date = stamp(slot.savedAt), count = self:SlotAddonCount(index) }
    return self:Format(values.date and S.detailFilled or S.detailFilledNoDate, values)
end

-- Both on one line, for the command's list.
function A:SlotSummary(index)
    local slot = self:Slot(index)
    if not slot then return S.summaryEmpty end
    return slot.name .. "  |  " .. self:SlotDetail(index)
end

-- The settings table is whatever came back from the saved file, which a hand edit or an older
-- build may have left in any shape.
function A:Normalize()
    local sv = self.sv
    if type(sv.slots) ~= "table" then sv.slots = {} end
    for index = 1, self.slotCount do
        local slot = sv.slots[index]
        if slot ~= nil then
            if type(slot) ~= "table" then
                sv.slots[index] = nil
            else
                if type(slot.addons) ~= "table" then slot.addons = {} end
                slot.name = self:CleanName(slot.name)
                if slot.name == "" then slot.name = self:DefaultName(index) end
            end
        end
    end
    sv.initialized = sv.initialized == true
end

-- Saves what every installed add-on is set to now into a set. Add-ons that are not installed
-- keep what the set already holds for them, so a set saved with everything still has their
-- settings in it on the day they are installed again.
function A:SaveSlot(index, name)
    local installed = self:InstalledTargets()
    if #installed == 0 then return false, "none" end
    local slot = self:Slot(index)
    if not slot then
        slot = { addons = {} }
        self.sv.slots[index] = slot
    end
    for _, target in ipairs(installed) do
        slot.addons[target.id] = self:Capture(target)
    end
    local clean = self:CleanName(name)
    if clean ~= "" then
        slot.name = clean
    elseif not slot.name or slot.name == "" then
        slot.name = self:DefaultName(index)
    end
    slot.savedAt = GetTimeStamp and GetTimeStamp() or nil
    return true, #installed
end

-- Writes a set into the installed add-ons it holds settings for. The others are left alone: an
-- add-on that was installed after the set was saved keeps its own settings.
function A:LoadSlot(index)
    local slot = self:Slot(index)
    if not slot then return false, "empty" end
    local applied = 0
    for _, target in ipairs(self:SlotTargets(index)) do
        if self:Restore(target, slot.addons[target.id]) then applied = applied + 1 end
    end
    if applied == 0 then return false, "nothing" end
    return true, applied
end

-- ---------------------------------------------------------------------------------------
-- What the buttons and the command do. Both go through here, so they say the same things.
-- ---------------------------------------------------------------------------------------

function A:Say(text)
    self.message = text
    if self.panel and self.panel.UpdateControls then self.panel:UpdateControls() end
end

-- True on the second press of the same button within a few seconds. The first press only arms
-- it: saving over a set, and loading one, both throw settings away.
function A:Confirm(action, index)
    local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
    local pending = self.pending
    if pending and pending.action == action and pending.slot == index
        and now - pending.at <= self.confirmMs then
        self.pending = nil
        return true
    end
    self.pending = { action = action, slot = index, at = now }
    return false
end

function A:Save(index, name)
    local ok, count = self:SaveSlot(index, name)
    if not ok then
        self:Say(S.nothingToSave)
        return false
    end
    self:Say(self:Format(S.saved, { count = count, set = index, name = self:SlotName(index) }))
    return true
end

function A:Reload()
    if type(ReloadUI) ~= "function" then
        self:Say(S.reloadFailed)
        return false
    end
    local function go()
        if not pcall(ReloadUI, "ingame") then self:Say(S.reloadFailed) end
    end
    if zo_callLater then
        zo_callLater(go, self.reloadDelayMs)
    else
        go()
    end
    return true
end

function A:Load(index)
    local ok, count = self:LoadSlot(index)
    if not ok then
        self:Say(self:Format(count == "empty" and S.emptySlot or S.nothingToLoad, { set = index }))
        return false
    end
    local reloadable = type(ReloadUI) == "function"
    self:Say(self:Format(reloadable and S.loadedReloading or S.loadedNoReload,
        { set = index, name = self:SlotName(index), count = count }))
    if reloadable then self:Reload() end
    return true
end

-- The Save button: a set that holds something asks to be pressed twice.
function A:PressSave(index, name)
    if self:Slot(index) and not self:Confirm("save", index) then
        self:Say(self:Format(S.confirmSave, { set = index, name = self:SlotName(index) }))
        return false
    end
    self.pending = nil
    return self:Save(index, name)
end

-- The Load button.
function A:PressLoad(index)
    if not self:Slot(index) then
        self:Say(self:Format(S.emptySlot, { set = index }))
        return false
    end
    local count = #self:SlotTargets(index)
    if count == 0 then
        self:Say(self:Format(S.nothingToLoad, { set = index }))
        return false
    end
    if not self:Confirm("load", index) then
        self:Say(self:Format(S.confirmLoad, { set = index, name = self:SlotName(index), count = count }))
        return false
    end
    self.pending = nil
    return self:Load(index)
end

-- The first time the add-on runs, whatever the add-ons are set to becomes set 1, so there is
-- a way back to it. Done once everything has loaded, not at load: some add-ons repair their
-- saved settings during theirs. Left undone while no supported add-on is installed.
function A:EnsureInitialSet()
    if self.sv.initialized then return end
    if self:SaveSlot(1, S.initialName) then self.sv.initialized = true end
end

function A:ListLines()
    local lines = { S.listHeader }
    for index = 1, self.slotCount do
        lines[#lines + 1] = "  " .. index .. ": " .. self:SlotSummary(index)
    end
    local names = {}
    for _, target in ipairs(self:InstalledTargets()) do names[#names + 1] = target.label end
    lines[#lines + 1] = self:Format(S.listTargets, { list = #names > 0 and table.concat(names, ", ") or "-" })
    return lines
end
