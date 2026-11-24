-- Fury's Guild Crier - settings panel (LibAddonMenu-2.0) and rotation reminder
--
-- Edits to text, channel and weight apply right away and update the menu.
-- Adding, deleting or renaming sections changes the layout of this panel,
-- which LibAddonMenu can only rebuild with a UI reload, so those reload.

local GT = FurysGuildToolset
local GC = GT.Crier

local CHANNEL_NAMES  = { "Guild", "Zone", "Whisper" }
local CHANNEL_VALUES = { "guild", "zone", "whisper" }

local function ChanValue(m)
    local c = (m.chan or ""):lower()
    if c == "zone" or c == "whisper" then return c end
    return "guild"
end

local function SetChan(m, v)
    if v == "guild" then m.chan = nil else m.chan = v end
end

local function CleanText(v)
    v = (v or ""):gsub("[\r\n]+", " ")
    return zo_strtrim(v)
end

local function IndexOf(msg)
    for i, m in ipairs(GC.Messages()) do
        if m == msg then return i end
    end
end

local function Preview(text)
    local t = text or ""
    if #t > 45 then t = t:sub(1, 45) .. "..." end
    return t
end

local function LengthLabel(m)
    local len = #(m.text or "")
    if len > GC.MAX_CHAT then
        return string.format("|cFF6B86%d/%d characters, too long!|r", len, GC.MAX_CHAT)
    end
    return string.format("%d/%d characters", len, GC.MAX_CHAT)
end

-- ---------- rotation reminder ----------
local TIMER_NAME = "FurysGuildToolset_CrierTimer"

local function ChatBusy()
    return CHAT_SYSTEM:IsTextEntryOpen()
end

-- One reminder at a time: while a reminder is waiting for combat to end or for you to
-- finish typing, the interval timer doesn't queue another one.
local function TryReminder()
    if IsUnitInCombat("player") then
        GC.reminderPending = true          -- OnCombatState tries again when combat ends
        return
    end
    if ChatBusy() then
        GC.reminderPending = true
        zo_callLater(TryReminder, 30000)   -- don't stomp on what you're typing
        return
    end
    GC.reminderPending = false
    GC.sv.timerLastAt = GetTimeStamp()     -- saved, so the next one is on time after logouts and reloads
    if GC.sv.timerAutoLoad then
        GC.Say("Reminder: next rotation message loaded into chat. Press Enter to send.")
        GC.Post()
    else
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEW_NOTIFICATION, "Fury's Guild Crier: time for a guild message!")
        GC.Say("Time for a guild message! Use your rotation key or /crier next.")
    end
end

function GC.FireReminder()
    if GC.reminderPending then return end   -- one is already waiting
    TryReminder()
end

-- The time of the last reminder is saved (sv.timerLastAt, account-wide), so the
-- interval keeps counting through logouts, character switches and /reloadui.
-- A check every 15 seconds fires the reminder once the interval has passed since
-- the last one. If it came due while you were offline, it fires soon after login.
local CHECK_MS = 15000

local function CheckReminder()
    local minutes = tonumber(GC.sv.timerMinutes) or 0
    if minutes <= 0 then return end
    if GetTimeStamp() - (GC.sv.timerLastAt or 0) >= minutes * 60 then
        GC.FireReminder()
    end
end

function GC.StartTimer()
    EVENT_MANAGER:UnregisterForUpdate(TIMER_NAME)
    local minutes = tonumber(GC.sv.timerMinutes) or 0
    if minutes > 0 then
        if not GC.sv.timerLastAt then GC.sv.timerLastAt = GetTimeStamp() end   -- first start: full interval
        EVENT_MANAGER:RegisterForUpdate(TIMER_NAME, CHECK_MS, CheckReminder)
    end
end

local function OnCombatState(_, inCombat)
    if not inCombat and GC.reminderPending and not ChatBusy() then
        zo_callLater(TryReminder, 3000)
    end
end

-- ---------- panel ----------
local addForm = { newCat = "", chan = "guild", weight = 0, text = "" }
local renameForm = {}
local quickAdd = {}
local panel

local function GuildChoices()
    local names, values = {}, {}
    for i = 1, 5 do
        local id = GetGuildId(i)
        if id and id ~= 0 then
            names[#names + 1] = GetGuildName(id)
            values[#values + 1] = i
        end
    end
    if #names == 0 then names, values = { "Guild 1" }, { 1 } end
    return names, values
end

local function MessageControls(m, controls)
    controls[#controls + 1] = {
        type = "editbox",
        name = function() return LengthLabel(m) end,
        tooltip = "Edit the message, then click outside the box to save. Placeholders: {new} = newest member's @name, {guild} = guild name.",
        isMultiline = true,
        isExtraWide = true,
        width = "full",
        maxChars = 1000,
        getFunc = function() return m.text or "" end,
        setFunc = function(v)
            v = CleanText(v)
            if v ~= "" then m.text = v end
            GC.MessagesChanged()
        end,
    }
    controls[#controls + 1] = {
        type = "dropdown",
        name = "Channel",
        tooltip = "Guild posts to the guild picked in the menu. Zone posts to zone chat. Whisper goes to the name in the menu's \"Whisper to\" box.",
        choices = CHANNEL_NAMES,
        choicesValues = CHANNEL_VALUES,
        width = "half",
        getFunc = function() return ChanValue(m) end,
        setFunc = function(v) SetChan(m, v); GC.MessagesChanged() end,
    }
    controls[#controls + 1] = {
        type = "slider",
        name = "Rotation weight",
        tooltip = "0 = menu only. Higher numbers come up more often in the rotation (3 comes up 3x as often as 1).",
        min = 0, max = 5, step = 1,
        width = "half",
        getFunc = function() return tonumber(m.weight) or 0 end,
        setFunc = function(v)
            if v == 0 then m.weight = nil else m.weight = v end
            GC.MessagesChanged()
        end,
    }
    controls[#controls + 1] = {
        type = "button",
        name = "Delete message",
        tooltip = function() return "Delete: " .. Preview(m.text) end,
        width = "half",
        isDangerous = true,
        warning = "Deletes this message for good and reloads the UI.",
        func = function()
            local i = IndexOf(m)
            if i then table.remove(GC.Messages(), i) end
            ReloadUI("ingame")
        end,
    }
end

local function SectionSubmenu(cat)
    local controls = {}
    local count = 0
    renameForm[cat] = cat
    for _, m in ipairs(GC.Messages()) do
        if (m.cat or "Messages") == cat then
            if count > 0 then controls[#controls + 1] = { type = "divider", alpha = 0.3 } end
            MessageControls(m, controls)
            count = count + 1
        end
    end
    controls[#controls + 1] = { type = "divider" }
    controls[#controls + 1] = {
        type = "editbox",
        name = "Rename this section",
        width = "half",
        getFunc = function() return renameForm[cat] end,
        setFunc = function(v) renameForm[cat] = CleanText(v) end,
    }
    controls[#controls + 1] = {
        type = "button",
        name = "Apply rename",
        tooltip = "Renames this section to the name typed above.",
        width = "half",
        warning = "Reloads the UI.",
        func = function()
            local new = renameForm[cat]
            if not new or new == "" or new == cat then return end
            for _, m in ipairs(GC.Messages()) do
                if (m.cat or "Messages") == cat then m.cat = new end
            end
            ReloadUI("ingame")
        end,
    }
    -- Quick add, right inside the section
    local sectionChan = "guild"
    for _, m in ipairs(GC.Messages()) do
        if (m.cat or "Messages") == cat then sectionChan = ChanValue(m) break end
    end
    quickAdd[cat] = quickAdd[cat] or ""
    controls[#controls + 1] = { type = "divider" }
    controls[#controls + 1] = {
        type = "editbox",
        name = function()
            local len = #(quickAdd[cat] or "")
            local t = string.format("|cA08CFF+ Add a message to %s|r (%d/%d)", cat, len, GC.MAX_CHAT)
            return t
        end,
        tooltip = "Type the new message, click out of the box, then click Add. It uses the same channel as this section's first message; change channel or weight afterwards if needed.",
        isMultiline = true,
        isExtraWide = true,
        width = "full",
        maxChars = 1000,
        getFunc = function() return quickAdd[cat] end,
        setFunc = function(v) quickAdd[cat] = CleanText(v) end,
    }
    controls[#controls + 1] = {
        type = "button",
        name = "Add",
        tooltip = "Adds the message typed above to this section.",
        width = "half",
        warning = "Reloads the UI so the new message shows up here.",
        func = function()
            local text = quickAdd[cat] or ""
            if text == "" then
                GC.Say("Type the message first, then click out of the box.")
                return
            end
            local m = { cat = cat, text = text }
            SetChan(m, sectionChan)
            local list, pos = GC.Messages(), nil
            for i, x in ipairs(list) do
                if (x.cat or "Messages") == cat then pos = i end
            end
            table.insert(list, (pos and pos + 1) or (#list + 1), m)
            ReloadUI("ingame")
        end,
    }
    return {
        type = "submenu",
        name = string.format("%s (%d)", cat, count),
        controls = controls,
    }
end

local function AddSubmenu(cats)
    return {
        type = "submenu",
        name = "|cA08CFF+ Add a new section|r",
        controls = {
            {
                type = "editbox",
                name = "Section name",
                width = "full",
                getFunc = function() return addForm.newCat end,
                setFunc = function(v) addForm.newCat = CleanText(v) end,
            },
            {
                type = "dropdown",
                name = "Channel",
                choices = CHANNEL_NAMES,
                choicesValues = CHANNEL_VALUES,
                width = "half",
                getFunc = function() return addForm.chan end,
                setFunc = function(v) addForm.chan = v end,
            },
            {
                type = "slider",
                name = "Rotation weight",
                tooltip = "0 = menu only.",
                min = 0, max = 5, step = 1,
                width = "half",
                getFunc = function() return addForm.weight end,
                setFunc = function(v) addForm.weight = v end,
            },
            {
                type = "editbox",
                name = function()
                    local len = #(addForm.text or "")
                    local s = string.format("First message (%d/%d characters)", len, GC.MAX_CHAT)
                    if len > GC.MAX_CHAT then s = "|cFF6B86" .. s .. "|r" end
                    return s
                end,
                isMultiline = true,
                isExtraWide = true,
                width = "full",
                maxChars = 1000,
                getFunc = function() return addForm.text end,
                setFunc = function(v) addForm.text = CleanText(v) end,
            },
            {
                type = "button",
                name = "Add section",
                tooltip = "Creates a new section with the name and first message typed above.",
                warning = "Reloads the UI so the new section shows up here.",
                func = function()
                    if addForm.newCat == "" then
                        GC.Say("Give the new section a name first.")
                        return
                    end
                    if addForm.text == "" then
                        GC.Say("A section needs at least one message. Type it first, then click out of the box.")
                        return
                    end
                    local cat = addForm.newCat
                    local m = { cat = cat, text = addForm.text }
                    SetChan(m, addForm.chan)
                    if addForm.weight > 0 then m.weight = addForm.weight end
                    -- Keep sections together: insert after the last message in that section
                    local list, pos = GC.Messages(), nil
                    for i, x in ipairs(list) do
                        if (x.cat or "Messages") == cat then pos = i end
                    end
                    table.insert(list, (pos and pos + 1) or (#list + 1), m)
                    ReloadUI("ingame")
                end,
            },
        },
    }
end

-- Adds messages from Messages.lua that aren't in the list yet (matched by text).
-- With onlyCat, adds only that section, placed after the last message already in it.
local function ImportDefaults(onlyCat)
    local have, list, added = {}, GC.Messages(), 0
    for _, m in ipairs(list) do have[m.text or ""] = true end
    for _, m in ipairs(GC.CopyDefaults()) do
        if not have[m.text or ""] and (not onlyCat or m.cat == onlyCat) then
            local pos = #list + 1
            if onlyCat then
                for i, x in ipairs(list) do
                    if (x.cat or "Messages") == onlyCat then pos = i + 1 end
                end
            end
            table.insert(list, pos, m)
            have[m.text or ""] = true
            added = added + 1
        end
    end
    return added
end

local function BuildOptions()
    local o = {}
    o[#o + 1] = {
        type = "description",
        text = "Open the menu with |cA08CFF/crier|r or your keybind, click a message, then press Enter to send. Edits to a message save when you click out of the box and show in the menu right away. Adding, deleting or renaming reloads the UI.",
    }

    -- General
    local gNames, gValues = GuildChoices()
    o[#o + 1] = { type = "header", name = "General" }
    o[#o + 1] = {
        type = "dropdown",
        name = "Post guild messages to",
        choices = gNames,
        choicesValues = gValues,
        getFunc = function() return GC.sv.guild end,
        setFunc = function(v) GC.sv.guild = v; if GC.RefreshHeader then GC.RefreshHeader() end end,
    }
    o[#o + 1] = {
        type = "checkbox",
        name = "Close the menu after clicking a message",
        getFunc = function() return GC.sv.closeOnClick end,
        setFunc = function(v) GC.sv.closeOnClick = v end,
    }
    o[#o + 1] = {
        type = "button",
        name = "Reset menu position",
        tooltip = "Moves the Crier pop-out window back to the middle of the screen.",
        width = "half",
        func = function()
            GC.sv.winX, GC.sv.winY = nil, nil
            if GC.window then
                GC.window:ClearAnchors()
                GC.window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
            end
        end,
    }

    -- Rotation
    o[#o + 1] = { type = "header", name = "Rotation reminder" }
    o[#o + 1] = {
        type = "slider",
        name = "Remind me every (minutes)",
        tooltip = "0 = off. Counts from the last reminder, including time logged out, so logging on and off or reloading doesn't restart it. Waits until you're out of combat and not typing.",
        min = 0, max = 120, step = 5,
        getFunc = function() return GC.sv.timerMinutes or 0 end,
        setFunc = function(v) GC.sv.timerMinutes = v; GC.StartTimer() end,
    }
    o[#o + 1] = {
        type = "checkbox",
        name = "Load the next message into chat automatically",
        tooltip = "On: the reminder puts the next rotation message in your chat box, ready for Enter. Off: you just get an alert.",
        disabled = function() return (GC.sv.timerMinutes or 0) == 0 end,
        getFunc = function() return GC.sv.timerAutoLoad end,
        setFunc = function(v) GC.sv.timerAutoLoad = v end,
    }
    o[#o + 1] = {
        type = "button",
        name = "Restart rotation",
        tooltip = "Start the weighted rotation over from the top.",
        width = "half",
        func = function() GC.ResetRotation(); GC.Say("Rotation reset.") end,
    }

    -- Messages
    local cats = GC.Categories()
    o[#o + 1] = { type = "header", name = "Messages" }
    for _, cat in ipairs(cats) do
        o[#o + 1] = SectionSubmenu(cat)
    end
    o[#o + 1] = AddSubmenu(cats)

    -- Defaults
    o[#o + 1] = {
        type = "submenu",
        name = "Defaults (Messages.lua)",
        controls = {
            {
                type = "description",
                text = "Messages.lua holds the starting list. Your edits here are saved separately, so changes to Messages.lua only show up if you import them.",
            },
            {
                type = "button",
                name = "Import new messages",
                tooltip = "Adds any message from Messages.lua that isn't already in your list. Nothing is removed.",
                width = "half",
                warning = "Reloads the UI.",
                func = function()
                    GC.Say(ImportDefaults(nil) .. " new message(s) imported.")
                    ReloadUI("ingame")
                end,
            },
            {
                type = "button",
                name = "Import new tips",
                tooltip = "Adds only the Tips from Messages.lua that aren't already in your list, at the end of your Tips section. Nothing else is added or removed.",
                width = "half",
                warning = "Reloads the UI.",
                func = function()
                    GC.Say(ImportDefaults("Tips") .. " new tip(s) imported.")
                    ReloadUI("ingame")
                end,
            },
            {
                type = "button",
                name = "Reset to Messages.lua",
                tooltip = "Replaces all your messages with the generic samples that come with the addon.",
                width = "half",
                isDangerous = true,
                warning = "Replaces ALL your messages with the generic sample list in Messages.lua. Your own messages will be lost. Reloads the UI.",
                func = function()
                    GC.sv.messages = GC.CopyDefaults()
                    GC.ResetRotation()
                    ReloadUI("ingame")
                end,
            },
        },
    }
    return o
end

function GC.InitSettings()
    EVENT_MANAGER:RegisterForEvent(GC.name .. "Combat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)

    local LAM = LibAddonMenu2

    -- Guild names aren't always ready at load, so build the panel once
    -- the player is in the world.
    local function Register()
        EVENT_MANAGER:UnregisterForEvent(GC.name .. "Settings", EVENT_PLAYER_ACTIVATED)
        panel = LAM:RegisterAddonPanel("FurysGuildToolset_CrierPanel", {
            type = "panel",
            name = "Fury's Guild Management - Crier",
            displayName = "|cA08CFFFury's Guild Management Toolset: Guild Crier|r",
            author = "Furyous",
            version = GT.version,
            registerForRefresh = true,
        })
        LAM:RegisterOptionControls("FurysGuildToolset_CrierPanel", BuildOptions())
    end
    Register()  -- the toolset calls InitSettings once you're in the world, so guild names are ready
end

function GC.OpenSettings()
    if panel then LibAddonMenu2:OpenToPanel(panel) end
end
