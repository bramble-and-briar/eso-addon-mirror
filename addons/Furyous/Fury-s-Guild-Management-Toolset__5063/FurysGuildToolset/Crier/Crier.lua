-- Guild Crier (part of Fury's Guild Management Toolset; formerly the standalone Fury's Guild Crier 1.4)
-- A clickable menu of canned guild messages, plus an optional weighted
-- rotation key. ESO does not allow addons to send chat on their own, so
-- clicking a message loads it into the chat box and you press Enter.

FuryGMT.Crier = {}
local GC = FuryGMT.Crier
GC.name = "FuryGMTCrier"
GC.displayName = "Fury's GMT: Guild Crier"
GC.version = "1.5"
GC.newest = {}   -- guildId -> @name of the newest member seen this session

ZO_CreateStringId("SI_BINDING_NAME_FURYGMT_CRIER_MENU", "Guild Crier: open/close message menu")
ZO_CreateStringId("SI_BINDING_NAME_FURYGMT_CRIER_POST", "Guild Crier: post next rotation message")
ZO_CreateStringId("SI_BINDING_NAME_FURYGMT_REPORT", "Open/close the report window")

local MAX_CHAT = 350
local PREFIX = "|cD4AF37[Fury's Guild Crier]|r "

-- Dark and gold theme
local GOLD      = { 0.83, 0.69, 0.22, 1 }
local GOLD_HI   = { 1.00, 0.85, 0.35, 1 }
local TEXT      = { 0.88, 0.88, 0.85, 1 }
local DIM       = { 0.60, 0.60, 0.58, 1 }
local BG        = { 0.06, 0.06, 0.07, 0.94 }

local WIN_W, WIN_H = 540, 600

local GUILD_CHANNELS = {
    CHAT_CHANNEL_GUILD_1, CHAT_CHANNEL_GUILD_2, CHAT_CHANNEL_GUILD_3,
    CHAT_CHANNEL_GUILD_4, CHAT_CHANNEL_GUILD_5,
}

local defaults = {
    guild = 1,
    rotation = nil,        -- message text -> place in the weighted rotation (kept between sessions)
    winX = nil,
    winY = nil,
    messages = nil,        -- your editable message list (seeded from Messages.lua)
    closeOnClick = false,  -- close the menu after clicking a message
    timerMinutes = 0,      -- rotation reminder interval, 0 = off
    timerAutoLoad = false, -- reminder loads the next rotation message into chat
    collapsed = {},        -- section name -> true when closed in the menu
}

local ICON_OPEN   = "|t20:20:EsoUI/Art/Buttons/tree_open_up.dds|t "
local ICON_CLOSED = "|t20:20:EsoUI/Art/Buttons/tree_closed_up.dds|t "

local function Say(msg) d(PREFIX .. msg) end
local function Messages()
    if GC.sv and GC.sv.messages then return GC.sv.messages end
    return FuryGMT_CrierMessages or {}
end
GC.Messages = Messages
GC.Say = Say
GC.MAX_CHAT = MAX_CHAT

-- Copy of the default list in Messages.lua (so edits never touch the defaults)
function GC.CopyDefaults()
    local out = {}
    for i, m in ipairs(FuryGMT_CrierMessages or {}) do
        out[i] = { cat = m.cat, chan = m.chan, weight = m.weight, text = m.text }
    end
    return out
end

-- Section names in the order they first appear
function GC.Categories()
    local order, seen = {}, {}
    for _, m in ipairs(Messages()) do
        local cat = m.cat or "Messages"
        if not seen[cat] then
            seen[cat] = true
            order[#order + 1] = cat
        end
    end
    return order
end
local function Weight(m) return tonumber(m.weight) or 0 end

local function GuildLabel(index)
    local id = GetGuildId(index)
    if id and id ~= 0 then return GetGuildName(id) end
    return nil
end

-- ---------- placeholders ----------
local function Fill(text)
    local id = GetGuildId(GC.sv.guild)
    local gname = GuildLabel(GC.sv.guild) or ""
    local newest = (id and GC.newest[id]) or ""
    if text:find("{new}", 1, true) and newest == "" then
        Say("No new member has joined this guild since you logged in. Fill in {new} by hand.")
    end
    text = text:gsub("{guild}", function() return gname end)
    text = text:gsub("{new}", function() return newest end)
    return text
end

-- ---------- sending ----------
local function SendToChat(m)
    local chan = (m.chan or ""):lower()
    local zone = chan == "zone"
    local whisper = chan == "whisper"
    local target
    if whisper then
        target = GC.whisperBox and zo_strtrim(GC.whisperBox:GetText()) or ""
        if target == "" then
            Say("Type the player's @name in the \"Whisper to\" box first.")
            return
        end
        if target:sub(1, 1) ~= "@" then target = "@" .. target end
    elseif not zone and not GuildLabel(GC.sv.guild) then
        Say("You're not in guild #" .. GC.sv.guild .. ". Pick another guild in the menu or use /crier guild <1-5>.")
        return
    end
    local text = Fill(m.text)
    if #text > MAX_CHAT then
        Say("Warning: this message is " .. #text .. " characters; ESO will cut it at " .. MAX_CHAT .. ".")
    end
    local channel
    if whisper then
        channel = CHAT_CHANNEL_WHISPER
    elseif zone then
        channel = CHAT_CHANNEL_ZONE
    else
        channel = GUILD_CHANNELS[GC.sv.guild]
    end
    StartChatInput(text, channel, target)
end

-- ---------- weighted rotation (smooth weighted round-robin) ----------
-- Each message's place in the rotation is saved by its text (sv.rotation), so it
-- carries over between sessions, and adding, removing, moving or editing other
-- messages doesn't send the whole rotation back to the start. An edited message
-- simply starts fresh.
local function ListSignature()
    local h = 7
    for _, m in ipairs(Messages()) do
        local s = tostring(Weight(m)) .. ":" .. tostring(m.text or "") .. "|"
        for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
    end
    return h
end

function GC.SyncState()
    local sv = GC.sv
    if not sv.rotation then
        sv.rotation = {}
        -- Older versions kept the rotation by list position. Carry it over if the
        -- list is still the one it was saved for.
        if sv.current and sv.signature == ListSignature() then
            for i, m in ipairs(Messages()) do
                if sv.current[i] and m.text then sv.rotation[m.text] = sv.current[i] end
            end
        end
        sv.current = nil
        sv.signature = nil
    end
    -- Forget messages that are gone or no longer in the rotation.
    local live = {}
    for _, m in ipairs(Messages()) do
        if Weight(m) > 0 and m.text then live[m.text] = true end
    end
    for text in pairs(sv.rotation) do
        if not live[text] then sv.rotation[text] = nil end
    end
end

function GC.ResetRotation()
    GC.sv.rotation = {}
end

local function PickNext()
    local msgs = Messages()
    local rot = GC.sv.rotation
    local total, best, bestVal = 0, nil, nil
    for i, m in ipairs(msgs) do
        local w = Weight(m)
        if w > 0 and m.text and m.text ~= "" then
            local c = (rot[m.text] or 0) + w
            rot[m.text] = c
            total = total + w
            if bestVal == nil or c > bestVal then best, bestVal = i, c end
        end
    end
    if not best then return nil end
    rot[msgs[best].text] = bestVal - total
    return msgs[best]
end

function GC.Post()
    if not GC.sv then return end
    GC.SyncState()
    local m = PickNext()
    if not m then
        Say("No messages have a weight, so the rotation key has nothing to post. Use the menu instead.")
        return
    end
    SendToChat(m)
end

-- ---------- menu window ----------
local function Color(ctrl, c) ctrl:SetColor(c[1], c[2], c[3], c[4]) end

local function MakeLabel(name, parent, font, color, text)
    local l = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    l:SetFont(font)
    Color(l, color)
    l:SetText(text or "")
    return l
end

local function MakeClickable(label, normal, hover, onClick, tip)
    label:SetMouseEnabled(true)
    label:SetHandler("OnMouseEnter", function(self)
        Color(self, hover)
        FuryGMT.Report.ShowTip(self, tip)
    end)
    label:SetHandler("OnMouseExit", function(self)
        Color(self, normal)
        FuryGMT.Report.HideTip()
    end)
    label:SetHandler("OnMouseUp", function(self, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then onClick(self) end
    end)
end

function GC.RefreshHeader()
    if not GC.guildCombo then return end
    local combo = GC.guildCombo
    combo:ClearItems()
    local selected
    for i = 1, GetNumGuilds() do
        local name = GuildLabel(i)
        if name then
            local index = i
            combo:AddItem(combo:CreateItemEntry(name, function()
                GC.sv.guild = index
            end), ZO_COMBOBOX_SUPPRESS_UPDATE)
            if i == GC.sv.guild then selected = name end
        end
    end
    combo:UpdateItems()
    combo:SetSelectedItemText(selected or "Pick a guild")
end

-- Puts the menu contents back in the Crier's own window.
function GC.DockHome()
    local content, win = GC.content, GC.window or FuryGMTCrierWindow
    if not content or not win then return end
    content:SetParent(win)
    content:ClearAnchors()
    content:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 42)
    content:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -10, -12)
    content:SetHidden(false)
    GC.docked = false
end

-- Shows the menu contents inside another control (the /gt window's Crier tab).
function GC.DockInto(area)
    if not GC.content then return end
    if GC.window and not GC.window:IsHidden() then SCENE_MANAGER:HideTopLevel(GC.window) end
    local content = GC.content
    content:SetParent(area:GetParent())
    content:ClearAnchors()
    content:SetAnchor(TOPLEFT, area, TOPLEFT, 0, 0)
    content:SetAnchor(BOTTOMRIGHT, area, BOTTOMRIGHT, 0, 0)
    content:SetHidden(false)
    GC.docked = true
    GC.RefreshHeader()
    GC.RefreshRows()
end

function GC.Undock()
    if GC.docked then
        GC.content:SetHidden(true)
        GC.DockHome()
    end
end

local function BuildWindow()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("FuryGMTCrierWindow")
    win:SetDimensions(WIN_W, WIN_H)
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    if GC.sv.winX and GC.sv.winY then
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GC.sv.winX, GC.sv.winY)
    else
        win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    win:SetHandler("OnMoveStop", function(self)
        GC.sv.winX, GC.sv.winY = self:GetLeft(), self:GetTop()
    end)

    local bg = WINDOW_MANAGER:CreateControl("FuryGMTCrierWindowBG", win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(BG[1], BG[2], BG[3], BG[4])
    bg:SetEdgeColor(GOLD[1], GOLD[2], GOLD[3], GOLD[4])
    bg:SetEdgeTexture("", 2, 2, 2)

    local title = MakeLabel("FuryGMTCrierTitle", win, "ZoFontWinH3", GOLD, "Fury's Guild Crier")
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 10)

    local close = MakeLabel("FuryGMTCrierClose", win, "ZoFontWinH3", DIM, "X")
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -14, 10)
    MakeClickable(close, DIM, GOLD_HI, function() SCENE_MANAGER:HideTopLevel(win) end, "Close (Esc)")

    -- Everything below the title lives in one container, so the same menu can also
    -- be shown inside the Crier tab of the /gt window (see GC.DockInto).
    local content = WINDOW_MANAGER:CreateControl("FuryGMTCrierContent", win, CT_CONTROL)
    GC.content = content
    GC.DockHome()

    -- Guild picker
    local glabel = MakeLabel("FuryGMTCrierGuildLabel", content, "ZoFontGame", DIM, "Post guild messages to:")
    glabel:SetAnchor(TOPLEFT, content, TOPLEFT, 0, 0)
    local cbCtrl = WINDOW_MANAGER:CreateControlFromVirtual("FuryGMTCrierGuildCombo", content, "ZO_ComboBox")
    cbCtrl:SetDimensions(260, 28)
    cbCtrl:SetAnchor(LEFT, glabel, RIGHT, 10, 0)
    GC.guildCombo = ZO_ComboBox_ObjectFromContainer(cbCtrl)
    GC.guildCombo:SetSortsItems(false)

    local hint = MakeLabel("FuryGMTCrierHint", content, "ZoFontGameSmall", DIM,
        "Click a section to open or close it. Click a message to load it into chat, then press Enter.")
    hint:SetAnchor(TOPLEFT, glabel, BOTTOMLEFT, 0, 14)

    local scroll = WINDOW_MANAGER:CreateControlFromVirtual("FuryGMTCrierScroll", content, "ZO_ScrollContainer")
    scroll:SetAnchor(TOPLEFT, hint, BOTTOMLEFT, 0, 10)
    scroll:SetAnchor(BOTTOMRIGHT, content, BOTTOMRIGHT, 0, 0)

    GC.scrollChild = GetControl(scroll, "ScrollChild")
    GC.headPool, GC.rowPool = {}, {}

    -- "Whisper to" box: lives inside the list, right under the section
    -- that holds the whisper messages, so the pairing is obvious.
    local wrow = WINDOW_MANAGER:CreateControl("FuryGMTCrierWhisperRow", GC.scrollChild, CT_CONTROL)
    wrow:SetHeight(30)
    local wlabel = MakeLabel("FuryGMTCrierWhisperLabel", wrow, "ZoFontGame", DIM, "Whisper to:")
    wlabel:SetAnchor(LEFT, wrow, LEFT, 12, 0)
    local wbd = WINDOW_MANAGER:CreateControlFromVirtual("FuryGMTCrierWhisperBG", wrow, "ZO_EditBackdrop")
    wbd:SetDimensions(220, 26)
    wbd:SetAnchor(LEFT, wlabel, RIGHT, 8, 0)
    GC.whisperBox = WINDOW_MANAGER:CreateControlFromVirtual("FuryGMTCrierWhisperBox", wbd, "ZO_DefaultEditForBackdrop")
    GC.whisperBox:SetMaxInputChars(40)
    GC.whisperBox:SetHandler("OnEnter", function(self) self:LoseFocus() end)
    local wclear = MakeLabel("FuryGMTCrierWhisperClear", wrow, "ZoFontGame", DIM, "clear")
    wclear:SetAnchor(LEFT, wbd, RIGHT, 8, 0)
    MakeClickable(wclear, DIM, GOLD_HI, function() GC.whisperBox:SetText("") end, "Clears the whisper name.")
    wrow:SetHidden(true)
    GC.whisperRow = wrow

    GC.window = win
    -- Registering with the scene manager makes Esc close the window
    -- and handles the mouse cursor for us.
    SCENE_MANAGER:RegisterTopLevel(win, false)
    GC.RefreshHeader()
    GC.RefreshRows()
end

-- (Re)draws the message list. Labels are pooled and reused, so the menu
-- can update right away when messages are edited in Settings.
local ROW_WIDTH = WIN_W - 60

function GC.RefreshRows()
    if not GC.window then return end
    local child = GC.scrollChild
    for _, c in ipairs(GC.headPool) do c:SetHidden(true) end
    for _, c in ipairs(GC.rowPool) do c:SetHidden(true) end
    GC.whisperRow:SetHidden(true)
    local whisperPlaced = false

    local prev, nh, nr = nil, 0, 0
    local function Place(ctrl, gap)
        ctrl:ClearAnchors()
        ctrl:SetWidth(ROW_WIDTH)
        if prev then
            ctrl:SetAnchor(TOPLEFT, prev, BOTTOMLEFT, 0, gap)
        else
            ctrl:SetAnchor(TOPLEFT, child, TOPLEFT, 0, 0)
        end
        ctrl:SetHidden(false)
        prev = ctrl
    end

    local groups = {}
    for _, m in ipairs(Messages()) do
        if m.text and m.text ~= "" then
            local cat = m.cat or "Messages"
            groups[cat] = groups[cat] or {}
            table.insert(groups[cat], m)
        end
    end

    for gi, cat in ipairs(GC.Categories()) do
        if groups[cat] then
            nh = nh + 1
            local head = GC.headPool[nh]
            if not head then
                head = MakeLabel("FuryGMTCrierHead" .. nh, child, "ZoFontWinH4", GOLD)
                MakeClickable(head, GOLD, GOLD_HI, function(self)
                    GC.sv.collapsed[self.cat] = not GC.sv.collapsed[self.cat]
                    GC.RefreshRows()
                end, "Click to open or close this section.")
                GC.headPool[nh] = head
            end
            local closed = GC.sv.collapsed[cat]
            head.cat = cat
            head:SetText((closed and ICON_CLOSED or ICON_OPEN) .. cat .. string.format(" |c999999(%d)|r", #groups[cat]))
            Place(head, gi == 1 and 0 or 12)

            local hasWhisper = false
            for _, m in ipairs(groups[cat]) do
                if (m.chan or ""):lower() == "whisper" then hasWhisper = true break end
            end
            if not closed and hasWhisper and not whisperPlaced then
                Place(GC.whisperRow, 6)
                whisperPlaced = true
            end

            for _, m in ipairs(closed and {} or groups[cat]) do
                nr = nr + 1
                local row = GC.rowPool[nr]
                if not row then
                    row = MakeLabel("FuryGMTCrierRow" .. nr, child, "ZoFontGame", TEXT)
                    MakeClickable(row, TEXT, GOLD_HI, function(self)
                        SendToChat(self.msg)
                        if GC.sv.closeOnClick then SCENE_MANAGER:HideTopLevel(GC.window) end
                    end, "Loads this message into chat. Press Enter to send it.")
                    GC.rowPool[nr] = row
                end
                local c = (m.chan or ""):lower()
                local tag = (c == "zone" and "|c8FB3D9[Zone]|r ") or ""
                row.msg = m
                row:SetText("- " .. tag .. m.text)
                Place(row, 6)
            end
        end
    end
end

-- Call after any change to the message list
function GC.MessagesChanged()
    GC.SyncState()
    GC.RefreshRows()
end

function GC.ToggleMenu()
    if not GC.sv then return end
    if not GC.window then BuildWindow() end
    if GC.window:IsHidden() then
        if GC.docked then
            FuryGMT.Report:Hide()
            GC.DockHome()
        end
        GC.RefreshHeader()
        SCENE_MANAGER:ShowTopLevel(GC.window)
    else
        SCENE_MANAGER:HideTopLevel(GC.window)
    end
end

-- ---------- slash commands ----------
local function ShowList()
    local msgs = Messages()
    local total = 0
    for _, m in ipairs(msgs) do total = total + math.max(Weight(m), 0) end
    Say(#msgs .. " messages. Posting to " ..
        (GuildLabel(GC.sv.guild) or ("guild #" .. GC.sv.guild)))
    for i, m in ipairs(msgs) do
        local w = Weight(m)
        local share = (total > 0 and w > 0) and string.format("rotation %d%%", math.floor(w / total * 100 + 0.5)) or "menu only"
        local len = #(m.text or "")
        local flag = len > MAX_CHAT and (" |cFF5555[" .. len .. " chars - TOO LONG]|r") or ""
        local preview = (m.text or ""):sub(1, 50)
        if len > 50 then preview = preview .. "..." end
        d(string.format("  %d. [%s] %s%s  %s", i, m.cat or "Messages", share, flag, preview))
    end
end

local function ShowHelp()
    Say("Commands:")
    d("  /crier - open/close the message menu")
    d("  /crier next - load the next rotation message")
    d("  /crier guild <1-5> - which guild to post to")
    d("  /crier list - show all messages, categories and rotation share")
    d("  /crier reset - restart the rotation")
    d("  /crier settings - open the settings panel")
    d("  Keybinds: Controls > Keybindings > Fury's Guild Crier")
end

local function Slash(args)
    args = zo_strtrim(args or ""):lower()
    local cmd, rest = args:match("^(%S*)%s*(.*)$")
    if cmd == "" or cmd == "menu" then
        GC.ToggleMenu()
    elseif cmd == "next" then
        GC.Post()
    elseif cmd == "guild" then
        local n = tonumber(rest)
        if n and n >= 1 and n <= 5 then
            GC.sv.guild = n
            Say("Now posting to " .. (GuildLabel(n) or ("guild #" .. n .. " (you're not in one there)")))
            GC.RefreshHeader()
        else
            for i = 1, GetNumGuilds() do d(string.format("  %d. %s", i, GuildLabel(i) or "?")) end
            Say("Currently guild #" .. GC.sv.guild .. ". Use /crier guild <1-5>.")
        end
    elseif cmd == "list" then
        ShowList()
    elseif cmd == "reset" then
        GC.ResetRotation()
        Say("Rotation reset.")
    elseif cmd == "settings" or cmd == "options" then
        if GC.OpenSettings then GC.OpenSettings() else Say("Settings need LibAddonMenu-2.0 installed.") end
    else
        ShowHelp()
    end
end

-- ---------- module wiring ----------
-- Settings live in the toolset's saved variables (sv.modules.crier). The first
-- time this runs while the old standalone addon is still enabled, its messages
-- and settings are copied over. While the standalone addon is enabled, this
-- copy stays inactive so you never get two menus or two reminders.

local GT = FuryGMT
local module = GT:RegisterModule("crier", {})
module.defaults = defaults

local IMPORT_KEYS = { "guild", "current", "signature", "winX", "winY", "messages", "closeOnClick",
    "timerMinutes", "timerAutoLoad", "collapsed" }

local function DeepCopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = DeepCopy(x) end
    return out
end

-- The standalone addon defines a global FurysGuildCrier with its own saved variables.
local function StandaloneActive()
    return FurysGuildCrier ~= nil and FurysGuildCrier.sv ~= nil
end

local function OnMemberAdded(_, guildId, displayName)
    GC.newest[guildId] = displayName
end

function module:Initialize(sv)
    GC.sv = sv
    sv.collapsed = sv.collapsed or {}
    -- The "Reminders" section is called "Tips" now. Rename it once in saved lists,
    -- keeping the messages, weights and rotation position (the rotation ignores section names).
    if not sv.tipsRenamed then
        for _, m in ipairs(sv.messages or {}) do
            if m.cat == "Reminders" then m.cat = "Tips" end
        end
        if sv.collapsed["Reminders"] ~= nil then
            sv.collapsed["Tips"] = sv.collapsed["Reminders"]
            sv.collapsed["Reminders"] = nil
        end
        sv.tipsRenamed = true
    end
    self:RegisterTab()
end

local PAUSED_TEXT = "Paused: the old standalone \"Fury's Guild Crier\" addon is still turned on. To switch over: Esc > Add-Ons, untick \"Fury's Guild Crier\", then /reloadui. Your messages and settings were already copied here."

-- "Crier" tab in the report window, so the crier is easy to find from /gt.
function module:RegisterTab()
    GT.Report:RegisterTab({
        id = "crier",
        title = "Crier",
        tip = "Your guild, zone and whisper messages. Click one to load it into chat.",
        GetSummary = function()
            if not GC.active then return "|cFFCC66" .. PAUSED_TEXT .. "|r" end
            local reminder = (GC.sv.timerMinutes or 0) > 0 and ("reminder every " .. GC.sv.timerMinutes .. " min") or "reminder off"
            return "Same as the Crier menu (" .. reminder .. ")."
        end,
        -- While active, the tab shows the Crier menu itself instead of a list.
        SetPanelShown = function(shown, area)
            if not GC.active then return false end
            if shown then
                if not GC.window then BuildWindow() end
                GC.DockInto(area)
            else
                GC.Undock()
            end
            return true
        end,
        GetRows = function()
            local rows = {}
            if not GC.active then
                rows[1] = { text = "Fury's Guild Crier is part of this toolset now, but it's paused (see above)." }
                return rows
            end
            for _, m in ipairs(Messages()) do
                if m.text and m.text ~= "" then
                    local msg = m
                    local tag = (m.cat or "Messages")
                    if (m.chan or "") ~= "" then tag = tag .. ", " .. m.chan end
                    if Weight(m) > 0 then tag = tag .. ", rotation x" .. Weight(m) end
                    rows[#rows + 1] = {
                        text = "|cD4AF37[" .. tag .. "]|r " .. m.text,
                        tooltip = m.text,
                        actions = { { label = "Post", tip = "Loads this message into chat. Press Enter to send it.",
                            fn = function() SendToChat(msg) end } },
                    }
                end
            end
            if #rows == 0 then rows[1] = { text = "No messages yet. Add some in Crier settings." } end
            return rows
        end,
        footer = function()
            if not GC.active then return {} end
            return {
                { label = "Pop out menu", tip = "Opens the Crier menu in its own small window.",
                  fn = function() GC.ToggleMenu() end },
                { label = "Post next (rotation)", tip = "Loads the next message in the rotation into chat.",
                  fn = function() GC.Post() end },
                { label = "Crier settings", tip = "Edit the messages, rotation and reminder.",
                  fn = function() if GC.OpenSettings then GC.OpenSettings() end end },
            }
        end,
        GetExportLines = function()
            local lines = { "Category\tChannel\tRotation weight\tMessage" }
            for _, m in ipairs(Messages()) do
                lines[#lines + 1] = table.concat({ m.cat or "Messages", m.chan or "guild", Weight(m), m.text or "" }, "\t")
            end
            return lines
        end,
    })
end

-- A "Guild Crier" section in the main toolset settings that points to the crier's own panel.
function module:BuildSettings(options)
    options[#options + 1] = { type = "submenu", name = "Guild Crier", controls = {
        { type = "description", text = function()
            if not GC.active then return PAUSED_TEXT end
            return "The crier's messages, rotation and reminder have their own settings page: \"Fury's Guild Management - Crier\" in the Add-Ons list. Open the message menu with /crier, /gt crier, the Crier tab in /gt, or a keybind (Controls > Keybindings > Fury's Guild Management)."
        end },
        { type = "button", name = "Open Crier settings", width = "half",
          tooltip = "Opens the Crier's own settings page for messages, rotation and reminder.",
          disabled = function() return not GC.active end,
          func = function() if GC.OpenSettings then GC.OpenSettings() end end },
    } }
end

function module:OnPlayerActivated()
    local sv = GC.sv
    if StandaloneActive() then
        if not sv.importedFromStandalone then
            local old = FurysGuildCrier.sv
            for _, key in ipairs(IMPORT_KEYS) do
                if old[key] ~= nil then sv[key] = DeepCopy(old[key]) end
            end
            sv.importedFromStandalone = GetTimeStamp()
            Say("Copied your messages and settings from the standalone Fury's Guild Crier.")
        end
        Say("The standalone Fury's Guild Crier is still enabled, so the toolset's crier is paused. Disable \"Fury's Guild Crier\" in the Add-Ons menu and /reloadui to switch over.")
        return
    end
    sv.messages = sv.messages or GC.CopyDefaults()
    GC.active = true
    EVENT_MANAGER:RegisterForEvent(GC.name, EVENT_GUILD_MEMBER_ADDED, OnMemberAdded)
    SLASH_COMMANDS["/crier"] = Slash
    if GC.InitSettings then GC.InitSettings() end
    if GC.StartTimer then GC.StartTimer() end
end

-- Keybinds call these; they do nothing while paused.
function GC.KeyToggleMenu() if GC.active then GC.ToggleMenu() end end
function GC.KeyPost() if GC.active then GC.Post() end end
