-- Who Wants Spaulder? (2.0, a rewrite of 1.0)
--
-- The Spaulder of Ruin's Aura of Pride gives up to 6 group members in its 12 m range 260 Weapon and Spell Damage, and
-- costs the wearer recovery for each one (UESP). Which 6 get it can be steered by reinviting members: kicking someone
-- and inviting them straight back takes the buff off them (research and testing by Ickypiggy). This addon keeps a
-- ticked list of group members and reinvites them in one click or one keybind.
--
-- What 1.0 did, and what changed here:
--  * The list: 1.0 made one row per name the first time it saw it, at the height it had then, and never moved it
--    again -- after the group changed, rows from earlier groups sat on top of each other (two names on one line). And
--    it only refreshed when opened. Here a pool of rows is laid out again on every refresh, and group events refresh it.
--  * Reinvite: 1.0 went through every row it had ever made, so a ticked member who had left could be kicked / invited
--    back. Here only ticked members who are in the group now (not the leader, not you) are reinvited.
--  * The timing is 1.0's, found by trial and error: kick, then invite after 1000 ms -- inviting sooner fails ("already
--    in a group"). The setting can make it longer, never shorter.
--  * Profiles: one row in the window (choose / Load / Save / Delete, with a confirmation) instead of a second window.
--    Loading a profile now replaces the ticks instead of adding to them.
--  * The window: one scene of its own (opened by the keybind / slash command; the game handles the cursor and Esc), and
--    shown next to the group menu when you're the leader of a big enough group (Settings).

WhoWantsSpaulder = WhoWantsSpaulder or {}
local WWS = WhoWantsSpaulder
WWS.name = "WhoWantsSpaulder"
WWS.version = "2.1.0"

local WM = WINDOW_MANAGER
local SCENE_NAME = "WhoWantsSpaulder"
local GROUP_MENU_SCENE = "groupMenuKeyboard"
WWS.MIN_DELAY = 1000          -- ms between the kick and the invite (1.0's value; less doesn't register)

WWS.DEFAULTS = {
    profiles = {},              -- [name] = { display names }   (1.0's format)
    windowPosition = { x = 500, y = 300 },
    checked = {},               -- [display name] = true        (when "remember" is on)
    rememberChecks = true,
    reinviteDelay = 1000,
    openWithGroupMenu = true,
    groupMenuLeaderOnly = true,
    groupMenuMinSize = 5,       -- 1.0: groups of more than 4
    locked = false,
    scale = 1,
    bgAlpha = 0.85,
    chatMessages = true,
}

local sv
local sessionChecks = {}
local busy = false
local selectedProfile


------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

function WWS.Msg(text, force)
    if force or not sv or sv.chatMessages then
        CHAT_ROUTER:AddSystemMessage("|cF3D27A[Who Wants Spaulder]|r " .. text)
    end
end

local function Checks()
    if sv and sv.rememberChecks then return sv.checked end
    return sessionChecks
end
WWS.Checks = Checks

function WWS.IsChecked(name) return Checks()[name] == true end
function WWS.SetChecked(name, on)
    Checks()[name] = on and true or nil
end

-- The group, leader first, then everyone else by name.
function WWS.Members()
    local list, leader = {}, nil
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        local name = tag and GetUnitDisplayName(tag)
        if name and name ~= "" then
            local m = {
                name = name, tag = tag,
                leader = IsUnitGroupLeader(tag),
                online = IsUnitOnline(tag),
                me = AreUnitsEqual(tag, "player"),
                role = GetGroupMemberSelectedRole and GetGroupMemberSelectedRole(tag) or nil,
                classId = GetUnitClassId and GetUnitClassId(tag) or 0,
            }
            if m.leader then leader = m else list[#list + 1] = m end
        end
    end
    table.sort(list, function(a, b) return zo_strlower(a.name) < zo_strlower(b.name) end)
    if leader then table.insert(list, 1, leader) end
    return list
end

local function IsLeader() return GetGroupSize() > 0 and IsUnitGroupLeader("player") end

-- ticked members who are in the group right now and can be reinvited. Offline ones are left alone: the kick would go
-- through but the invite back couldn't be accepted, so they'd just be out of the group.
function WWS.Targets()
    local out, offline = {}, {}
    for _, m in ipairs(WWS.Members()) do
        if WWS.IsChecked(m.name) and not m.leader and not m.me then
            if m.online then out[#out + 1] = m.name else offline[#offline + 1] = m.name end
        end
    end
    return out, offline
end

------------------------------------------------------------------------------
-- Reinvite
------------------------------------------------------------------------------

function WWS.Delay()
    return math.max(WWS.MIN_DELAY, tonumber(sv and sv.reinviteDelay) or WWS.MIN_DELAY)
end

function WWS.ReinviteChecked()
    if busy then return end
    if GetGroupSize() == 0 then WWS.Msg("You're not in a group.", true) return end
    if not IsLeader() then WWS.Msg("Only the group leader can reinvite.", true) return end
    local targets, offline = WWS.Targets()
    if #offline > 0 then WWS.Msg("Skipped (offline): " .. table.concat(offline, ", "), true) end
    if #targets == 0 then
        if #offline == 0 then WWS.Msg("Nobody in the group is marked.", true) end
        return
    end

    local delay = WWS.Delay()
    for _, name in ipairs(targets) do
        GroupKickByName(name)
        zo_callLater(function() GroupInviteByName(name) end, delay)
    end
    WWS.Msg("Reinviting " .. table.concat(targets, ", "))
    -- no second press while the invites are on their way
    busy = true
    WWS.MarkBusyStart()
    WWS.Refresh()
    zo_callLater(function()
        busy = false
        WWS.Refresh()
    end, delay + 500)
end

function WWS.IsBusy() return busy end

------------------------------------------------------------------------------
-- Profiles
------------------------------------------------------------------------------

function WWS.ProfileNames()
    local names = {}
    for name in pairs(sv.profiles) do names[#names + 1] = name end
    table.sort(names, function(a, b) return zo_strlower(a) < zo_strlower(b) end)
    return names
end

-- the ticked names (in the group or not: a profile is about people, not this group)
function WWS.SaveProfile(name)
    name = zo_strtrim(name or "")
    if name == "" then WWS.Msg("A loadout needs a name.", true) return false end
    local list = {}
    for n in pairs(Checks()) do list[#list + 1] = n end
    table.sort(list)
    local existed = sv.profiles[name] ~= nil
    sv.profiles[name] = list
    selectedProfile = name
    WWS.Msg(string.format("Loadout '%s' %s (%d marked).", name, existed and "updated" or "saved", #list))
    WWS.Refresh()
    return true
end

-- replaces the ticks with the profile's
function WWS.LoadProfile(name)
    local list = name and sv.profiles[name]
    if not list then WWS.Msg("Pick a loadout first.", true) return false end
    local checks = Checks()
    for n in pairs(checks) do checks[n] = nil end
    for _, n in ipairs(list) do checks[n] = true end
    selectedProfile = name
    WWS.Msg(string.format("Loadout '%s' loaded.", name))
    WWS.Refresh()
    return true
end

function WWS.DeleteProfile(name)
    if not (name and sv.profiles[name]) then return false end
    sv.profiles[name] = nil
    if selectedProfile == name then selectedProfile = nil end
    WWS.Msg(string.format("Loadout '%s' deleted.", name))
    WWS.Refresh()
    return true
end

function WWS.SelectedProfile() return selectedProfile end
function WWS.SelectProfile(name) selectedProfile = name; WWS.Refresh() end

local function RegisterDialogs()
    ZO_Dialogs_RegisterCustomDialog("WHOWANTSSPAULDER_SAVE_PROFILE", {
        title = { text = "Save loadout" },
        mainText = { text = "A name for the marked members (an existing name is overwritten):" },
        editBox = {},
        buttons = {
            { text = SI_DIALOG_ACCEPT, callback = function(dialog) WWS.SaveProfile(ZO_Dialogs_GetEditBoxText(dialog)) end },
            { text = SI_DIALOG_CANCEL },
        },
    })
    ZO_Dialogs_RegisterCustomDialog("WHOWANTSSPAULDER_DELETE_PROFILE", {
        title = { text = "Delete loadout" },
        mainText = { text = "Delete the loadout '<<1>>'?" },
        buttons = {
            { text = SI_DIALOG_ACCEPT, callback = function(dialog) WWS.DeleteProfile(dialog.data and dialog.data.name) end },
            { text = SI_DIALOG_CANCEL },
        },
    })
end

function WWS.AskSaveProfile()
    ZO_Dialogs_ShowDialog("WHOWANTSSPAULDER_SAVE_PROFILE")
end

function WWS.AskDeleteProfile(name)
    name = name or selectedProfile
    if not (name and sv.profiles[name]) then WWS.Msg("Pick a loadout first.", true) return end
    ZO_Dialogs_ShowDialog("WHOWANTSSPAULDER_DELETE_PROFILE", { name = name }, { mainTextParams = { name } })
end

------------------------------------------------------------------------------
-- Window ("endgame" look: obsidian panel, ember and molten-gold trim, the Spaulder itself in the header)
------------------------------------------------------------------------------

local THEME = {
    panel = { 0.035, 0.028, 0.026 },        -- obsidian (its alpha: the Background opacity setting)
    trim = { 0.78, 0.33, 0.10, 1 },         -- ember edge
    gold = { 0.98, 0.78, 0.36, 1 },         -- molten gold
    ember = { 1.00, 0.45, 0.14, 1 },
    blood = { 0.78, 0.16, 0.10, 1 },
    bone = { 0.94, 0.90, 0.83, 1 },
    dim = { 0.56, 0.51, 0.47, 1 },
    row = { 1, 1, 1, 0.025 },
    rowAlt = { 1, 1, 1, 0.05 },
}
local SPAULDER_ICON = "/esoui/art/icons/gear_razorhorndaedric_shoulder_a.dds"   -- (DebuffTracker's proc data, ESO-Hub)
local ROLE_ICONS = {        -- (esoui sharedtextures.lua)
    [LFG_ROLE_DPS or 1] = "EsoUI/Art/LFG/LFG_icon_dps.dds",
    [LFG_ROLE_TANK or 2] = "EsoUI/Art/LFG/LFG_icon_tank.dds",
    [LFG_ROLE_HEAL or 4] = "EsoUI/Art/LFG/LFG_icon_healer.dds",
}
local LEADER_ICON = "EsoUI/Art/UnitFrames/groupIcon_leader.dds"
local function Font(face, size, effect) return string.format("$(%s)|%d|%s", face, size, effect or "soft-shadow-thick") end

local W = {}            -- the window's controls
local WIDTH, PAD, ROW_H = 320, 14, 30
local HEADER_H, CHIPS_H, BIG_H, BTN_H, SECTION_H = 64, 26, 42, 26, 22
local INNER = WIDTH - 2 * PAD
-- everything above the list and below it, in px (the window's height follows the group)
local ABOVE_LIST = HEADER_H + 10 + CHIPS_H + 10
local BELOW_LIST = 8 + BTN_H + 10 + BIG_H + 4 + 18 + 12 + SECTION_H + 4 + BTN_H + 6 + BTN_H + PAD
local rows = {}         -- pooled member rows

local function Label(parent, font, color, align)
    local l = WM:CreateControl(nil, parent, CT_LABEL)
    l:SetFont(font)
    l:SetColor(unpack(color))
    l:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return l
end

local function Backdrop(parent, center, edge, thickness)
    local b = WM:CreateControl(nil, parent, CT_BACKDROP)
    b:SetCenterColor(unpack(center))
    b:SetEdgeColor(unpack(edge or { 0, 0, 0, 0 }))
    b:SetEdgeTexture(nil, 1, 1, thickness or 1)
    return b
end

-- a left-to-right fade made of thin slices (no texture file needed)
local function Fade(parent, color, width, height, slices)
    local box = WM:CreateControl(nil, parent, CT_CONTROL)
    box:SetDimensions(width, height)
    local w = width / slices
    for i = 1, slices do
        local s = Backdrop(box, { color[1], color[2], color[3], color[4] * (1 - (i - 1) / slices) })
        s:SetAnchor(TOPLEFT, box, TOPLEFT, (i - 1) * w, 0)
        s:SetDimensions(math.ceil(w), height)
    end
    return box
end

-- flat buttons in the panel's style. kind: "primary" (the big Reinvite) or "ghost" (outlined)
local function Button(parent, text, width, height, kind, onClick)
    local b = { kind = kind, enabled = true }
    b.control = WM:CreateControl(nil, parent, CT_CONTROL)
    b.control:SetDimensions(width, height)
    b.control:SetMouseEnabled(true)
    if kind == "primary" then
        b.bg = Backdrop(b.control, { 0.42, 0.10, 0.05, 0.95 }, THEME.gold, 1)
        b.fill = Backdrop(b.control, { THEME.ember[1], THEME.ember[2], THEME.ember[3], 0.55 })
        b.fill:SetAnchor(TOPLEFT, b.control, TOPLEFT, 1, 1)
        b.fill:SetDimensions(0, height - 2)
        b.fill:SetHidden(true)
        b.glow = Backdrop(b.control, { 0, 0, 0, 0 }, THEME.ember, 2)
        b.glow:SetAnchor(TOPLEFT, b.control, TOPLEFT, -3, -3)
        b.glow:SetAnchor(BOTTOMRIGHT, b.control, BOTTOMRIGHT, 3, 3)
        b.label = Label(b.control, Font("BOLD_FONT", 18), THEME.bone, TEXT_ALIGN_CENTER)
    else
        b.bg = Backdrop(b.control, { 1, 1, 1, 0.03 }, { THEME.trim[1], THEME.trim[2], THEME.trim[3], 0.6 }, 1)
        b.label = Label(b.control, Font("BOLD_FONT", 13), THEME.gold, TEXT_ALIGN_CENTER)
    end
    b.bg:SetAnchorFill()
    b.label:SetAnchorFill()
    b.label:SetText(text)
    local function Look(hover)
        if kind == "primary" then
            b.bg:SetCenterColor(b.enabled and (hover and 0.55 or 0.42) or 0.12, b.enabled and (hover and 0.14 or 0.10) or 0.11,
                b.enabled and 0.05 or 0.10, 0.95)
            b.bg:SetEdgeColor(unpack(b.enabled and THEME.gold or THEME.dim))
            b.label:SetColor(unpack(b.enabled and THEME.bone or THEME.dim))
        else
            b.bg:SetCenterColor(1, 1, 1, (b.enabled and hover) and 0.08 or 0.03)
            b.label:SetColor(unpack(b.enabled and (hover and THEME.ember or THEME.gold) or THEME.dim))
        end
    end
    b.Look = Look
    b.control:SetHandler("OnMouseEnter", function() b.hover = true; Look(true) end)
    b.control:SetHandler("OnMouseExit", function() b.hover = false; Look(false) end)
    b.control:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and b.enabled then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            onClick()
        end
    end)
    function b:SetText(t) self.label:SetText(t) end
    function b:SetEnabled(on) self.enabled = on and true or false; Look(self.hover) end
    Look(false)
    return b
end

local function SectionTitle(parent, text)
    local l = Label(parent, Font("BOLD_FONT", 13), THEME.gold)
    l:SetText(text)
    l:SetDimensions(INNER, SECTION_H)
    local line = Backdrop(parent, { THEME.trim[1], THEME.trim[2], THEME.trim[3], 0.45 })
    line:SetAnchor(LEFT, l, LEFT, 0, 0)
    line:SetDimensions(INNER, 1)
    line:ClearAnchors()
    line:SetAnchor(BOTTOMLEFT, l, BOTTOMLEFT, 0, 0)
    return l
end

local function Chip(parent, width)
    local c = {}
    c.control = Backdrop(parent, { 0, 0, 0, 0.35 }, { THEME.trim[1], THEME.trim[2], THEME.trim[3], 0.35 }, 1)
    c.control:SetDimensions(width, CHIPS_H)
    c.key = Label(c.control, Font("MEDIUM_FONT", 11), THEME.dim)
    c.key:SetAnchor(LEFT, c.control, LEFT, 8, 0)
    c.value = Label(c.control, Font("BOLD_FONT", 15), THEME.bone, TEXT_ALIGN_RIGHT)
    c.value:SetAnchor(RIGHT, c.control, RIGHT, -8, 0)
    return c
end

-- Only the group leader can reinvite, so only the leader marks. Marks made earlier stay (shown dimmed) for when the
-- lead comes back.
function WWS.CanMark() return IsLeader() end

local function Toggle(m)
    if m.leader or m.me or not WWS.CanMark() then return end
    WWS.SetChecked(m.name, not WWS.IsChecked(m.name))
    WWS.Refresh()
end

local function NewRow(index)
    local r = {}
    r.control = WM:CreateControl(nil, W.list, CT_CONTROL)
    r.control:SetDimensions(INNER, ROW_H)
    r.control:SetMouseEnabled(true)
    r.bg = Backdrop(r.control, THEME.row)
    r.bg:SetAnchorFill()
    r.accent = Backdrop(r.control, THEME.ember)          -- the mark: an ember bar down the left side
    r.accent:SetAnchor(TOPLEFT, r.control, TOPLEFT, 0, 0)
    r.accent:SetDimensions(3, ROW_H)
    r.box = Backdrop(r.control, { 0, 0, 0, 0.5 }, THEME.trim, 1)     -- the tick box
    r.box:SetDimensions(14, 14)
    r.box:SetAnchor(LEFT, r.control, LEFT, 12, 0)
    r.tick = Backdrop(r.box, THEME.ember)
    r.tick:SetAnchor(TOPLEFT, r.box, TOPLEFT, 3, 3)
    r.tick:SetAnchor(BOTTOMRIGHT, r.box, BOTTOMRIGHT, -3, -3)
    r.leaderIcon = WM:CreateControl(nil, r.control, CT_TEXTURE)
    r.leaderIcon:SetDimensions(18, 18)
    r.leaderIcon:SetAnchor(LEFT, r.control, LEFT, 10, 0)
    r.leaderIcon:SetTexture(LEADER_ICON)
    r.role = WM:CreateControl(nil, r.control, CT_TEXTURE)
    r.role:SetDimensions(20, 20)
    r.role:SetAnchor(LEFT, r.control, LEFT, 32, 0)
    -- the class (esoui: GetUnitClassId, ZO_GetClassIcon -- the group list does the same)
    r.class = WM:CreateControl(nil, r.control, CT_TEXTURE)
    r.class:SetDimensions(22, 22)
    r.class:SetAnchor(LEFT, r.control, LEFT, 54, 0)
    r.name = Label(r.control, Font("MEDIUM_FONT", 16), THEME.bone)
    r.name:SetAnchor(LEFT, r.control, LEFT, 82, 0)
    r.name:SetAnchor(RIGHT, r.control, RIGHT, -78, 0)
    r.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    r.name:SetMaxLineCount(1)
    r.tag = Label(r.control, Font("BOLD_FONT", 11), THEME.dim, TEXT_ALIGN_RIGHT)
    r.tag:SetAnchor(RIGHT, r.control, RIGHT, -10, 0)
    r.tag:SetDimensions(70, ROW_H)
    -- the whole row marks / unmarks
    r.control:SetHandler("OnMouseEnter", function() r.hover = true; if r.member then WWS.PaintRow(r) end end)
    r.control:SetHandler("OnMouseExit", function() r.hover = false; if r.member then WWS.PaintRow(r) end end)
    r.control:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and r.member then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            Toggle(r.member)
        end
    end)
    rows[index] = r
    return r
end

function WWS.PaintRow(r)
    local m = r.member
    local fixed = m.leader or m.me
    local marked = not fixed and WWS.IsChecked(m.name)
    local base = (r.index % 2 == 0) and THEME.rowAlt or THEME.row
    if marked and WWS.CanMark() then
        r.bg:SetCenterColor(THEME.ember[1], THEME.ember[2], THEME.ember[3], r.hover and 0.22 or 0.15)
    else
        r.bg:SetCenterColor(base[1], base[2], base[3], base[4] + (r.hover and not fixed and WWS.CanMark() and 0.05 or 0))
    end
    r.accent:SetHidden(not marked)
    r.box:SetHidden(fixed)
    -- not the leader: the box greyed out, a mark shown dimmed
    local can = WWS.CanMark()
    r.box:SetEdgeColor(unpack(can and THEME.trim or THEME.dim))
    r.tick:SetCenterColor(unpack(can and THEME.ember or THEME.dim))
    r.accent:SetCenterColor(unpack(can and THEME.ember or THEME.dim))
    r.tick:SetHidden(not marked)
    r.leaderIcon:SetHidden(not m.leader)
    local roleIcon = m.role and ROLE_ICONS[m.role]
    r.role:SetHidden(roleIcon == nil)
    if roleIcon then r.role:SetTexture(roleIcon) end
    local classIcon = (m.classId or 0) > 0 and ZO_GetClassIcon and ZO_GetClassIcon(m.classId)
    r.class:SetHidden(not classIcon)
    if classIcon then
        r.class:SetTexture(classIcon)
        r.class:SetAlpha(m.online and 1 or 0.45)
    end
    r.name:SetText(m.name)
    r.name:SetColor(unpack((not m.online) and THEME.dim or ((marked and WWS.CanMark()) and THEME.gold or THEME.bone)))
    if m.leader then r.tag:SetText("LEADER"); r.tag:SetColor(unpack(THEME.gold))
    elseif m.me then r.tag:SetText("YOU"); r.tag:SetColor(unpack(THEME.dim))
    elseif not m.online then r.tag:SetText("OFFLINE"); r.tag:SetColor(unpack(THEME.blood))
    elseif marked then r.tag:SetText("REINVITE"); r.tag:SetColor(unpack(WWS.CanMark() and THEME.ember or THEME.dim))
    else r.tag:SetText("") end
end

local function SetupRow(r, i, m, y)
    r.member, r.index = m, i
    r.control:ClearAnchors()
    r.control:SetAnchor(TOPLEFT, W.list, TOPLEFT, 0, y)
    r.control:SetHidden(false)
    WWS.PaintRow(r)
end

-- the big button: a slow ember pulse while it's ready, a fill counting down while the invites are on their way
local busyStart = 0
function WWS.MarkBusyStart() busyStart = GetFrameTimeMilliseconds() end
local function AnimateReinvite()
    local b = W.reinvite
    local now = GetFrameTimeMilliseconds()
    if busy then
        local f = zo_clamp((now - busyStart) / WWS.Delay(), 0, 1)
        b.fill:SetHidden(false)
        b.fill:SetWidth(math.max(0, (W.reinvite.control:GetWidth() - 2) * f))
        b.glow:SetHidden(true)
        local left = math.max(0, (WWS.Delay() - (now - busyStart)) / 1000)
        b:SetText(left > 0 and string.format("REINVITING  %.1fs", left) or "INVITING BACK...")
    else
        b.fill:SetHidden(true)
        b.glow:SetHidden(not b.enabled)
        if b.enabled then b.glow:SetAlpha(0.35 + 0.35 * (math.sin(now / 420) * 0.5 + 0.5)) end
    end
end

-- (re)lays the whole window out from the current group: every row is placed again, unused ones hidden
function WWS.Refresh(force)
    if not W.window or (W.window:IsHidden() and not force) then return end
    local members = WWS.Members()
    local leader = IsLeader()
    local y = 0
    for i, m in ipairs(members) do
        local r = rows[i] or NewRow(i)
        SetupRow(r, i, m, y)
        y = y + ROW_H
    end
    -- spare rows: hidden, and back at the top
    for i = #members + 1, #rows do
        local r = rows[i]
        r.member = nil
        r.control:SetHidden(true)
        r.control:ClearAnchors()
        r.control:SetAnchor(TOPLEFT, W.list, TOPLEFT, 0, 0)
    end
    W.empty:SetHidden(#members > 0)
    local listH = math.max(#members * ROW_H, 44)
    W.list:SetHeight(listH)
    W.window:SetHeight(ABOVE_LIST + listH + BELOW_LIST)

    local n = #WWS.Targets()
    local marked = 0
    for _, m in ipairs(members) do if not m.leader and not m.me and WWS.IsChecked(m.name) then marked = marked + 1 end end
    W.chipGroup.value:SetText(tostring(#members))
    W.chipMarked.value:SetText(tostring(marked))
    W.chipMarked.value:SetColor(unpack(marked > 0 and THEME.ember or THEME.bone))
    W.chipLead.value:SetText(leader and "YOU" or (GetGroupSize() > 0 and "NO" or "-"))
    W.chipLead.value:SetColor(unpack(leader and THEME.gold or THEME.blood))

    if not busy then W.reinvite:SetText(n > 0 and string.format("REINVITE  %d", n) or "REINVITE") end
    W.reinvite:SetEnabled(leader and n > 0 and not busy)
    if GetGroupSize() == 0 then
        W.status:SetText("Not in a group")
    elseif not leader then
        W.status:SetText("Only the group leader can mark and reinvite")
    elseif busy then
        W.status:SetText("Kicked - inviting back")
    else
        W.status:SetText(n == 0 and "Mark who loses the Aura of Pride" or "Kick and invite back: the aura moves on")
    end

    -- loadouts (profiles)
    local combo = W.combo
    combo:ClearItems()
    local names = WWS.ProfileNames()
    for _, name in ipairs(names) do
        combo:AddItem(combo:CreateItemEntry(name, function() WWS.SelectProfile(name) end), ZO_COMBOBOX_SUPPRESS_UPDATE)
    end
    combo:UpdateItems()
    if selectedProfile and not sv.profiles[selectedProfile] then selectedProfile = nil end
    combo:SetSelectedItemText(selectedProfile or (#names > 0 and "Choose a loadout" or "No loadouts saved"))
    W.load:SetEnabled(selectedProfile ~= nil and leader)
    W.markAll:SetEnabled(leader)
    W.clear:SetEnabled(leader)
    W.delete:SetEnabled(selectedProfile ~= nil)
end

function WWS.ApplyLook()
    if not W.window then return end
    W.window:SetScale(sv.scale or 1)
    W.bg:SetCenterColor(THEME.panel[1], THEME.panel[2], THEME.panel[3], sv.bgAlpha or 0.85)
    W.window:SetMovable(not sv.locked)
end

function WWS.RestorePosition()
    local p = sv.windowPosition
    W.window:ClearAnchors()
    W.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, p.x or 500, p.y or 300)
end

function WWS.ResetPosition()
    sv.windowPosition = { x = 500, y = 300 }
    if W.window then WWS.RestorePosition() end
end

local function Build()
    local win = WM:CreateTopLevelWindow("WhoWantsSpaulder_Window")
    W.window = win
    win:SetDimensions(WIDTH, 400)       -- (the height follows the group: WWS.Refresh)
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetHidden(true)
    win:SetHandler("OnMoveStop", function()
        sv.windowPosition = { x = math.floor(win:GetLeft() + 0.5), y = math.floor(win:GetTop() + 0.5) }
    end)

    -- panel: obsidian, a 2 px ember edge and a thin gold line inside it
    W.bg = Backdrop(win, { THEME.panel[1], THEME.panel[2], THEME.panel[3], 0.85 }, THEME.trim, 2)
    W.bg:SetAnchorFill()
    local inner = Backdrop(win, { 0, 0, 0, 0 }, { THEME.gold[1], THEME.gold[2], THEME.gold[3], 0.25 }, 1)
    inner:SetAnchor(TOPLEFT, win, TOPLEFT, 4, 4)
    inner:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -4, -4)

    -- header: an ember glow fading to the right, the Spaulder, the title
    local glow = Fade(win, { THEME.ember[1], THEME.ember[2], THEME.ember[3], 0.28 }, WIDTH - 8, HEADER_H - 6, 16)
    glow:SetAnchor(TOPLEFT, win, TOPLEFT, 4, 4)
    local iconFrame = Backdrop(win, { 0, 0, 0, 0.6 }, THEME.gold, 1)
    iconFrame:SetDimensions(44, 44)
    iconFrame:SetAnchor(LEFT, win, TOPLEFT, PAD, HEADER_H / 2)
    local icon = WM:CreateControl(nil, iconFrame, CT_TEXTURE)
    icon:SetTexture(SPAULDER_ICON)
    icon:SetAnchor(TOPLEFT, iconFrame, TOPLEFT, 2, 2)
    icon:SetAnchor(BOTTOMRIGHT, iconFrame, BOTTOMRIGHT, -2, -2)
    -- (kept clear of the close button: the preview showed "SPAULDER" running under it at 20 px)
    local title = Label(win, Font("BOLD_FONT", 17), THEME.bone)
    title:SetText("WHO WANTS SPAULDER")
    title:SetAnchor(BOTTOMLEFT, iconFrame, RIGHT, 10, 1)
    title:SetDimensions(WIDTH - PAD - 44 - 10 - 34, 24)
    title:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    local tagline = Label(win, Font("MEDIUM_FONT", 12), THEME.ember)
    tagline:SetText("AURA OF PRIDE CONTROL")
    tagline:SetAnchor(TOPLEFT, iconFrame, RIGHT, 11, 1)
    local close = WM:CreateControlFromVirtual(nil, win, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -8, 8)
    close:SetHandler("OnClicked", function() WWS.HideWindow() end)
    local headLine = Backdrop(win, { THEME.trim[1], THEME.trim[2], THEME.trim[3], 0.7 })
    headLine:SetAnchor(TOPLEFT, win, TOPLEFT, 4, HEADER_H)
    headLine:SetDimensions(WIDTH - 8, 1)

    -- three chips: group size, marked, who leads
    local chipW = math.floor((INNER - 12) / 3)
    W.chipGroup = Chip(win, chipW); W.chipGroup.key:SetText("GROUP")
    W.chipGroup.control:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, HEADER_H + 10)
    W.chipMarked = Chip(win, chipW); W.chipMarked.key:SetText("MARKED")
    W.chipMarked.control:SetAnchor(LEFT, W.chipGroup.control, RIGHT, 6, 0)
    W.chipLead = Chip(win, chipW); W.chipLead.key:SetText("LEAD")
    W.chipLead.control:SetAnchor(LEFT, W.chipMarked.control, RIGHT, 6, 0)

    -- the roster
    W.list = WM:CreateControl(nil, win, CT_CONTROL)
    W.list:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, ABOVE_LIST)
    W.list:SetDimensions(INNER, 44)
    W.empty = Label(W.list, Font("MEDIUM_FONT", 15), THEME.dim, TEXT_ALIGN_CENTER)
    W.empty:SetAnchorFill()
    W.empty:SetText("Not in a group")

    -- mark all / clear
    local half = math.floor((INNER - 6) / 2)
    local all = Button(win, "MARK ALL", half, BTN_H, "ghost", function()
        if not WWS.CanMark() then return end
        for _, m in ipairs(WWS.Members()) do if not m.leader and not m.me then WWS.SetChecked(m.name, true) end end
        WWS.Refresh()
    end)
    all.control:SetAnchor(TOPLEFT, W.list, BOTTOMLEFT, 0, 8)
    W.markAll = all
    local none = Button(win, "CLEAR", half, BTN_H, "ghost", function()
        if not WWS.CanMark() then return end
        local c = Checks()
        for name in pairs(c) do c[name] = nil end
        WWS.Refresh()
    end)
    none.control:SetAnchor(LEFT, all.control, RIGHT, 6, 0)
    W.clear = none

    -- the big one
    W.reinvite = Button(win, "REINVITE", INNER, BIG_H, "primary", function() WWS.ReinviteChecked() end)
    W.reinvite.control:SetAnchor(TOPLEFT, all.control, BOTTOMLEFT, 0, 10)
    W.reinvite.control:SetHandler("OnUpdate", AnimateReinvite)
    W.status = Label(win, Font("MEDIUM_FONT", 12), THEME.dim, TEXT_ALIGN_CENTER)
    W.status:SetAnchor(TOPLEFT, W.reinvite.control, BOTTOMLEFT, 0, 4)
    W.status:SetDimensions(INNER, 18)

    -- loadouts (profiles): choose / Load / Save / Delete
    local section = SectionTitle(win, "LOADOUTS")
    section:SetAnchor(TOPLEFT, W.status, BOTTOMLEFT, 0, 12)
    local comboCtrl = WM:CreateControlFromVirtual("WhoWantsSpaulder_ProfileCombo", win, "ZO_ComboBox")
    comboCtrl:SetDimensions(INNER, BTN_H)
    comboCtrl:SetAnchor(TOPLEFT, section, BOTTOMLEFT, 0, 4)
    W.combo = ZO_ComboBox_ObjectFromContainer(comboCtrl)
    W.combo:SetSortsItems(false)
    local third = math.floor((INNER - 12) / 3)
    W.load = Button(win, "LOAD", third, BTN_H, "ghost", function() WWS.LoadProfile(selectedProfile) end)
    W.load.control:SetAnchor(TOPLEFT, comboCtrl, BOTTOMLEFT, 0, 6)
    W.save = Button(win, "SAVE", third, BTN_H, "ghost", function() WWS.AskSaveProfile() end)
    W.save.control:SetAnchor(LEFT, W.load.control, RIGHT, 6, 0)
    W.delete = Button(win, "DELETE", third, BTN_H, "ghost", function() WWS.AskDeleteProfile() end)
    W.delete.control:SetAnchor(LEFT, W.save.control, RIGHT, 6, 0)

    WWS.RestorePosition()
    WWS.ApplyLook()

    WWS.fragment = ZO_FadeSceneFragment:New(win)
    WWS.fragment:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_SHOWING then WWS.Refresh(true) end
    end)
    local scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    scene:AddFragment(WWS.fragment)
    WWS.scene = scene
end

WWS.W = W       -- (for the tests)

------------------------------------------------------------------------------
-- Showing it
------------------------------------------------------------------------------

-- next to the group menu: the leader of a big enough group (Settings)
function WWS.WantsGroupMenu()
    if not sv.openWithGroupMenu then return false end
    if sv.groupMenuLeaderOnly and not IsLeader() then return false end
    return GetGroupSize() >= (sv.groupMenuMinSize or 5)
end

function WWS.UpdateGroupMenu()
    if not (WWS.fragment and SCENE_MANAGER:IsShowing(GROUP_MENU_SCENE)) then return end
    if WWS.WantsGroupMenu() then SCENE_MANAGER:AddFragment(WWS.fragment)
    else SCENE_MANAGER:RemoveFragment(WWS.fragment) end
end

function WWS.IsShowing() return W.window ~= nil and not W.window:IsHidden() end

function WWS.ShowWindow()
    if SCENE_MANAGER:IsShowing(GROUP_MENU_SCENE) then
        SCENE_MANAGER:AddFragment(WWS.fragment)
    else
        SCENE_MANAGER:Show(SCENE_NAME)
    end
end

function WWS.HideWindow()
    if SCENE_MANAGER:IsShowing(SCENE_NAME) then
        SCENE_MANAGER:Hide(SCENE_NAME)
    else
        SCENE_MANAGER:RemoveFragment(WWS.fragment)
    end
end

function WWS.ToggleWindow()
    if WWS.IsShowing() then WWS.HideWindow() else WWS.ShowWindow() end
end
WWS.ToggleGUI = WWS.ToggleWindow        -- (1.0's name)

------------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------------

local function OnGroupChanged()
    WWS.UpdateGroupMenu()
    WWS.Refresh()
end

local function OnLoaded(_, addonName)
    if addonName ~= WWS.name then return end
    EVENT_MANAGER:UnregisterForEvent(WWS.name, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("WhoWantsSpaulder_SavedVars", 1, nil, WWS.DEFAULTS)
    sv.profileWindowPosition = nil      -- (1.0's second window is gone)
    sv.reinviteDelay = math.max(WWS.MIN_DELAY, tonumber(sv.reinviteDelay) or WWS.MIN_DELAY)
    WWS.sv = sv

    Build()
    RegisterDialogs()

    local groupMenu = SCENE_MANAGER:GetScene(GROUP_MENU_SCENE)
    if groupMenu then
        groupMenu:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING then WWS.UpdateGroupMenu() end
        end)
    end

    for _, ev in ipairs({ EVENT_GROUP_MEMBER_JOINED, EVENT_GROUP_MEMBER_LEFT, EVENT_GROUP_UPDATE, EVENT_LEADER_UPDATE,
        EVENT_GROUP_MEMBER_CONNECTED_STATUS }) do
        EVENT_MANAGER:RegisterForEvent(WWS.name .. "_Group" .. ev, ev, OnGroupChanged)
    end

    SLASH_COMMANDS["/spauldergui"] = WWS.ToggleWindow
    SLASH_COMMANDS["/spaulder"] = WWS.ToggleWindow

    if WWS.SetupSettings then WWS.SetupSettings() end
end

ZO_CreateStringId("SI_BINDING_NAME_WhoWantsSpaulder_REINVITE", "Reinvite marked members")
ZO_CreateStringId("SI_BINDING_NAME_WhoWantsSpaulder_OPEN", "Open / close the window")

EVENT_MANAGER:RegisterForEvent(WWS.name, EVENT_ADD_ON_LOADED, OnLoaded)
