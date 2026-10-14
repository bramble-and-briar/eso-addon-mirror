-- Groupbound_Watch.lua : "fake roles" (ESO forums: someone joins as a tank or healer, then switches
-- to damage once inside). While you lead a group, Groupbound remembers each member's role and tells
-- you when one switches after joining: a chat line and the small notice at the top right.
-- Role changes in the first 15 s after joining don't count (people fix their role right away).
-- Calls as in esoui zo_grouplist_manager.lua: GetGroupSize, GetGroupUnitTagByIndex,
-- GetGroupMemberSelectedRole, EVENT_GROUP_MEMBER_ROLE_CHANGED.

local G = Groupbound
local L = G.L
local Watch = {}
G.Watch = Watch

local JOIN_GRACE = 15
local members = {}       -- [account lowercase] = { role, since, account, char }

local function RoleName(lfg)
    local text = GetString("SI_LFGROLE", lfg)
    if text and text ~= "" then return text end
    return "?"
end

-- reads every member's role; announce = tell about switches (only while you lead)
local function Scan(announce)
    local now = G.Now()
    local seen = {}
    local okSize, size = pcall(GetGroupSize)
    for i = 1, (okSize and size or 0) do
        local okTag, tag = pcall(GetGroupUnitTagByIndex, i)
        if okTag and tag and not AreUnitsEqual(tag, "player") then
            local okAcc, account = pcall(GetUnitDisplayName, tag)
            local key = okAcc and G.AccountKey(account)
            if key then
                seen[key] = true
                local okRole, role = pcall(GetGroupMemberSelectedRole, tag)
                role = okRole and role or LFG_ROLE_INVALID
                local m = members[key]
                if not m then
                    members[key] = { role = role, since = now, account = account, char = GetUnitName(tag) }
                elseif m.role ~= role then
                    local from = m.role
                    m.role = role
                    if announce and G.sv.roleWatch and now - m.since >= JOIN_GRACE
                        and from ~= LFG_ROLE_INVALID and role ~= LFG_ROLE_INVALID
                        and IsUnitGroupLeader("player") then
                        Watch.Announce(m, from, role)
                    end
                end
            end
        end
    end
    for key in pairs(members) do
        if not seen[key] then members[key] = nil end
    end
end

function Watch.Announce(m, from, to)
    local who = (m.char and m.char ~= "") and zo_strformat("<<1>>", m.char) or m.account
    G.Print(L("ROLE_SWITCH_CHAT", who, m.account, RoleName(from), RoleName(to)))
    if G.sv.toast and G.HUD and G.HUD.Notice then
        G.HUD.Notice(L("ROLE_SWITCH_TITLE", who), L("ROLE_SWITCH_LINE", RoleName(from), RoleName(to)))
    end
    if G.sv.sound then PlaySound(SOUNDS.GENERAL_ALERT_ERROR or SOUNDS.DEFAULT_CLICK) end
end

function Watch.Init()
    local function Quiet() Scan(false) end
    if EVENT_GROUP_MEMBER_ROLE_CHANGED then
        G.EM:RegisterForEvent("Groupbound_WatchRole", EVENT_GROUP_MEMBER_ROLE_CHANGED, function() Scan(true) end)
    end
    G.EM:RegisterForEvent("Groupbound_WatchJoin", EVENT_GROUP_MEMBER_JOINED, Quiet)
    G.EM:RegisterForEvent("Groupbound_WatchLeft", EVENT_GROUP_MEMBER_LEFT, Quiet)
    if EVENT_GROUP_UPDATE then G.EM:RegisterForEvent("Groupbound_WatchUpdate", EVENT_GROUP_UPDATE, Quiet) end
    G.EM:RegisterForEvent("Groupbound_WatchLoad", EVENT_PLAYER_ACTIVATED, Quiet)
end
