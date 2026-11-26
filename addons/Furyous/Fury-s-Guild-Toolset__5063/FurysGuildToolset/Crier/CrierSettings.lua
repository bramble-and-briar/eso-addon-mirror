-- Fury's Guild Crier - settings panel (LibAddonMenu-2.0) and rotation reminder
--
-- Edits to text, channel and weight apply right away and update the menu.
-- Deleting and renaming change the layout of this panel, which LibAddonMenu can
-- only rebuild with a UI reload, so those reload, always after a Confirm / Cancel pop-up
-- (1.31.0, Albert: nothing reloads without asking). Adding does not (1.31.0, Albert):
-- a new message goes into the menu and rotation at once and shows on this panel
-- after the next /reloadui, so you can add several in a row.

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
        GC.Post(true)
    else
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEW_NOTIFICATION, "Guild Crier: time for a guild message!")
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
local prefixForm = {}   -- section name -> the prefix typed for "Add to every message" (1.32.0)
local quickAdd = {}
local quickAddChan, quickAddWeight = {}, {}
local panel

-- Messages added since the last reload: they are in the menu and rotation, not on this panel yet.
local addedSinceReload = 0
local ADD_WARNING = "Does not reload the UI. The new message goes into the /crier menu and the rotation right away, but this settings page only lists it after you type /reloadui. Add as many as you like first."

local function Added(where)
    addedSinceReload = addedSinceReload + 1
    GC.MessagesChanged()
    GC.Say(string.format("Added to %s. It's in the /crier menu and the rotation now. Type /reloadui to see it on this settings page (%d added since your last reload).",
        where, addedSinceReload))
    if panel then CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel) end
end

-- Character counters that count while you type (1.31.0, Albert: they only changed after you
-- clicked out of the box). LibAddonMenu builds the controls when the panel first opens; each
-- box gets a reference name, and once the controls exist its label is updated on every
-- keystroke. onText(text), when given, also keeps the typed text (used by the Add boxes, so
-- Add works without clicking out of the box first).
local liveBoxes, liveBoxCount = {}, 0
local function LiveRef(labelFor, onText)
    liveBoxCount = liveBoxCount + 1
    local ref = "FurysGuildToolset_CrierBox" .. liveBoxCount
    liveBoxes[#liveBoxes + 1] = { ref = ref, labelFor = labelFor, onText = onText }
    return ref
end

local function HookLiveBoxes(createdPanel)
    if createdPanel ~= panel then return end
    for _, box in ipairs(liveBoxes) do
        local control = _G[box.ref]
        if control and not box.hooked then
            box.hooked = true
            ZO_PostHookHandler(control.editbox, "OnTextChanged", function(edit)
                local text = edit:GetText()
                if box.onText then box.onText(text) end
                control.label:SetText(box.labelFor(text))
            end)
        end
    end
end

local function CountLabel(prefix, text)
    local len = #(text or "")
    local s = string.format("%s (%d/%d characters)", prefix, len, GC.MAX_CHAT)
    if len > GC.MAX_CHAT then s = s .. " |cFF6B86too long!|r" end
    return s
end

local ADD_NOTE = "|cFFC857New messages are in the /crier menu and the rotation as soon as you click Add, but they only show on this settings page after you type /reloadui. Pick the channel and weight here first, because they can only be changed on this page after the reload.|r"

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
        reference = LiveRef(function(text) return LengthLabel({ text = text }) end),
        tooltip = "Edit the message, then click outside the box to save. Placeholders: {new} = newest member's @name, {guild} = guild name.",
        isMultiline = true,
        isExtraWide = true,
        width = "full",
        maxChars = 1000,
        getFunc = function() return m.text or "" end,
        setFunc = function(v)
            v = CleanText(v)
            if v ~= "" then
                GC.TextChanged(m.text, v)
                m.text = v
            end
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
        tooltip = "0 = menu only. Higher numbers come up more often in the rotation (3 comes up 3x as often as 1), spread evenly, never in a row.",
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
        warning = "Asks first, then deletes this message for good and reloads the UI.",
        func = function()
            GT.Actions.Confirm("Delete message",
                "Delete this message for good?\n\n\"" .. Preview(m.text) .. "\"\n\nThis reloads the UI (a few seconds) so the settings page no longer shows it.",
                function()
                    local i = IndexOf(m)
                    if i then table.remove(GC.Messages(), i) end
                    ReloadUI("ingame")
                end)
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
        warning = "Asks first, then reloads the UI.",
        func = function()
            local new = renameForm[cat]
            if not new or new == "" or new == cat then return end
            GT.Actions.Confirm("Rename section",
                string.format("Rename the section \"%s\" to \"%s\"?\n\nThis reloads the UI (a few seconds) so the settings page shows the new name.", cat, new),
                function()
                    for _, m in ipairs(GC.Messages()) do
                        if (m.cat or "Messages") == cat then m.cat = new end
                    end
                    ReloadUI("ingame")
                end)
        end,
    }
    -- 1.32.0: one prefix for every message of the section, for example "PSA - ". Messages that
    -- already start with it are left alone, so a second click changes nothing.
    controls[#controls + 1] = {
        type = "editbox",
        name = "Prefix for every message",
        tooltip = "Text to put in front of every message in this section, for example \"PSA -\". A space is added after it. Messages that already start with it are left as they are.",
        width = "half",
        getFunc = function() return prefixForm[cat] or "" end,
        setFunc = function(v) prefixForm[cat] = CleanText(v) end,
    }
    controls[#controls + 1] = {
        type = "button",
        name = "Add prefix",
        tooltip = "Puts the text typed on the left in front of every message in this section. Asks first. No reload.",
        width = "half",
        func = function()
            local typed = prefixForm[cat] or ""
            if typed == "" then
                GC.Say("Type the prefix first, then click out of the box.")
                return
            end
            local prefix = typed .. " "
            local todo, tooLong = {}, 0
            for _, m in ipairs(GC.Messages()) do
                if (m.cat or "Messages") == cat and string.sub(m.text or "", 1, #prefix) ~= prefix then
                    todo[#todo + 1] = m
                    if #(m.text or "") + #prefix > GC.MAX_CHAT then tooLong = tooLong + 1 end
                end
            end
            if #todo == 0 then
                GC.Say(string.format("Every message in %s already starts with \"%s\".", cat, typed))
                return
            end
            local body = string.format("Put \"%s\" in front of %d message(s) in the section \"%s\"?", typed, #todo, cat)
            if tooLong > 0 then
                body = body .. string.format("\n\n%d of them will be longer than the %d characters chat takes. They are marked \"too long\" on this page so you can shorten them.", tooLong, GC.MAX_CHAT)
            end
            GT.Actions.Confirm("Add prefix", body, function()
                for _, m in ipairs(todo) do
                    GC.TextChanged(m.text, prefix .. (m.text or ""))
                    m.text = prefix .. (m.text or "")
                end
                GC.MessagesChanged()
                GC.Say(string.format("Added \"%s\" to %d message(s) in %s.", typed, #todo, cat))
                if panel then CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel) end
            end)
        end,
    }
    -- Quick add, right inside the section
    local sectionChan = "guild"
    for _, m in ipairs(GC.Messages()) do
        if (m.cat or "Messages") == cat then sectionChan = ChanValue(m) break end
    end
    local sectionWeight = 0
    for _, m in ipairs(GC.Messages()) do
        if (m.cat or "Messages") == cat then sectionWeight = tonumber(m.weight) or 0 break end
    end
    quickAdd[cat] = quickAdd[cat] or ""
    quickAddChan[cat] = quickAddChan[cat] or sectionChan
    quickAddWeight[cat] = quickAddWeight[cat] or sectionWeight
    local function AddLabel(text) return CountLabel(string.format("|cA08CFF+ Add a message to %s|r", cat), text) end
    controls[#controls + 1] = { type = "divider" }
    controls[#controls + 1] = { type = "description", text = ADD_NOTE }
    controls[#controls + 1] = {
        type = "editbox",
        name = function() return AddLabel(quickAdd[cat]) end,
        reference = LiveRef(AddLabel, function(text) quickAdd[cat] = CleanText(text) end),
        tooltip = "Type the new message, pick its channel and rotation weight below, then click Add. Placeholders: {new} = newest member's @name, {guild} = guild name.",
        isMultiline = true,
        isExtraWide = true,
        width = "full",
        maxChars = 1000,
        getFunc = function() return quickAdd[cat] end,
        setFunc = function(v) quickAdd[cat] = CleanText(v) end,
    }
    controls[#controls + 1] = {
        type = "dropdown",
        name = "Channel for the new message",
        tooltip = "Guild posts to the guild picked in the menu. Zone posts to zone chat. Whisper goes to the name in the menu's \"Whisper to\" box. Starts as this section's first message's channel.",
        choices = CHANNEL_NAMES,
        choicesValues = CHANNEL_VALUES,
        width = "half",
        getFunc = function() return quickAddChan[cat] end,
        setFunc = function(v) quickAddChan[cat] = v end,
    }
    controls[#controls + 1] = {
        type = "slider",
        name = "Rotation weight for the new message",
        tooltip = "0 = menu only. Higher numbers come up more often in the rotation (3 comes up 3x as often as 1), spread evenly, never in a row. Starts as this section's first message's weight.",
        min = 0, max = 5, step = 1,
        width = "half",
        getFunc = function() return quickAddWeight[cat] end,
        setFunc = function(v) quickAddWeight[cat] = v end,
    }
    controls[#controls + 1] = {
        type = "button",
        name = "Add",
        tooltip = "Adds the message typed above to this section, with the channel and weight picked above, and empties the box for the next one. No reload: it is in the /crier menu and rotation right away and shows on this page after /reloadui.",
        width = "half",
        warning = ADD_WARNING,
        func = function()
            local text = quickAdd[cat] or ""
            if text == "" then
                GC.Say("Type the message first, then click out of the box.")
                return
            end
            if #text > GC.MAX_CHAT then
                GC.Say(string.format("That message is %d characters; chat takes %d. Make it shorter first.", #text, GC.MAX_CHAT))
                return
            end
            local m = { cat = cat, text = text }
            SetChan(m, quickAddChan[cat])
            if quickAddWeight[cat] > 0 then m.weight = quickAddWeight[cat] end
            local list, pos = GC.Messages(), nil
            for i, x in ipairs(list) do
                if (x.cat or "Messages") == cat then pos = i end
            end
            table.insert(list, (pos and pos + 1) or (#list + 1), m)
            quickAdd[cat] = ""
            Added(cat)
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
            { type = "description", text = ADD_NOTE },
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
                name = function() return CountLabel("First message", addForm.text) end,
                reference = LiveRef(function(text) return CountLabel("First message", text) end,
                    function(text) addForm.text = CleanText(text) end),
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
                tooltip = "Creates a new section with the name and first message typed above, and empties the boxes. No reload: the section shows on this page after /reloadui.",
                warning = ADD_WARNING,
                func = function()
                    if addForm.newCat == "" then
                        GC.Say("Give the new section a name first.")
                        return
                    end
                    if addForm.text == "" then
                        GC.Say("A section needs at least one message. Type it first, then click out of the box.")
                        return
                    end
                    if #addForm.text > GC.MAX_CHAT then
                        GC.Say(string.format("That message is %d characters; chat takes %d. Make it shorter first.", #addForm.text, GC.MAX_CHAT))
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
                    addForm.newCat, addForm.text = "", ""
                    Added("the new section " .. cat)
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
        text = "Open the menu with |cA08CFF/crier|r or your keybind, click a message, then press Enter to send. Edits to a message save when you click out of the box and show in the menu right away. New messages go into the menu right away too, and show on this page after you type /reloadui. Deleting, renaming and importing ask first, then reload the UI.",
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
        tooltip = "On: the reminder puts the next rotation message in your chat box, ready for Enter. One you don't send comes back at the next reminder. Off: you just get an alert.",
        disabled = function() return (GC.sv.timerMinutes or 0) == 0 end,
        getFunc = function() return GC.sv.timerAutoLoad end,
        setFunc = function(v) GC.sv.timerAutoLoad = v end,
    }
    o[#o + 1] = {
        type = "button",
        name = "Restart rotation",
        tooltip = "Start the rotation over from the top of your list, as a new round.",
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
                warning = "Asks first, then reloads the UI.",
                func = function()
                    GT.Actions.Confirm("Import new messages",
                        "Add every message from Messages.lua that isn't in your list yet? Nothing is removed.\n\nThis reloads the UI (a few seconds) so the settings page shows them.",
                        function()
                            GC.Say(ImportDefaults(nil) .. " new message(s) imported.")
                            ReloadUI("ingame")
                        end)
                end,
            },
            {
                type = "button",
                name = "Import new tips",
                tooltip = "Adds only the Tips from Messages.lua that aren't already in your list, at the end of your Tips section. Nothing else is added or removed.",
                width = "half",
                warning = "Asks first, then reloads the UI.",
                func = function()
                    GT.Actions.Confirm("Import new tips",
                        "Add the Tips from Messages.lua that aren't in your list yet, at the end of your Tips section? Nothing else changes.\n\nThis reloads the UI (a few seconds) so the settings page shows them.",
                        function()
                            GC.Say(ImportDefaults("Tips") .. " new tip(s) imported.")
                            ReloadUI("ingame")
                        end)
                end,
            },
            {
                type = "button",
                name = "Reset to Messages.lua",
                tooltip = "Replaces all your messages with the generic samples that come with the addon.",
                width = "half",
                warning = "Asks first. Replaces ALL your messages with the generic sample list in Messages.lua. Your own messages will be lost. Reloads the UI.",
                func = function()
                    GT.Actions.Confirm("Reset to Messages.lua",
                        "Replace ALL your messages with the generic sample list in Messages.lua? Your own messages will be lost.\n\nThis reloads the UI (a few seconds).",
                        function()
                            GC.sv.messages = GC.CopyDefaults()
                            GC.ResetRotation()
                            ReloadUI("ingame")
                        end)
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
            name = "Fury's Guild Toolset - Crier",
            displayName = "|cA08CFFFury's Guild Toolset: Guild Crier|r",
            author = "Furyous",
            version = GT.version,
            website = GT.website,
            registerForRefresh = true,
        })
        LAM:RegisterOptionControls("FurysGuildToolset_CrierPanel", BuildOptions())
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", HookLiveBoxes)
    end
    Register()  -- the toolset calls InitSettings once you're in the world, so guild names are ready
end

function GC.OpenSettings()
    if panel then LibAddonMenu2:OpenToPanel(panel) end
end
