-- Group frames (5.23.0): what the "Group frames" display does besides drawing its frames (Display/Displays.lua,
-- Items.frames):
--   * places other trackers' entries on each member's frame ("On group frames": an ally missing a buff, your heal on
--     them, a buff's time left as a thin bar along the frame), once per update after every display has drawn;
--   * the mouse on a frame: a tooltip, and the game's own group menu on right-click (whisper, jump to, promote, kick /
--     vote to kick, leave, disband -- the same entries, conditions and dialogs as the group list, esoui
--     zo_grouplist_keyboard.lua GroupListRow_OnMouseUp);
--   * "Hide the game's group frames": hides the game's group / raid frame container (ZO_UnitFramesGroups) while a group
--     frames tracker with that option is shown, and shows it again when none is. The game never hides or shows that
--     container itself (unitframes.lua only creates frames inside it), so nothing fights over it; the target frame is
--     outside it and stays. (The game's own way, UNIT_FRAMES:SetGroupAndRaidFramesHiddenForReason, also hides the
--     whole unit frames window -- the target frame with it -- so it isn't used.)

local DT = DebuffTracker
local GF = DT.GroupFrames
local U = DT.Util
local L = DT.L

local active = {}       -- [onframes display] = true while it has entries to place
local frameDisplays = {}  -- [frames display] = true while it's shown
local hiders = {}       -- [frames display] = true while it wants the game's group frames hidden
local hidGame = false

------------------------------------------------------------------------------
-- The game's group frames
------------------------------------------------------------------------------

local function ApplyGameFrames()
    local want = next(hiders) ~= nil
    local container = rawget(_G, "ZO_UnitFramesGroups")
    if not container or not container.SetHidden then return end
    if want and not hidGame then
        container:SetHidden(true)
        hidGame = true
    elseif not want and hidGame then
        container:SetHidden(false)
        hidGame = false
    end
end
function GF.GameFramesHidden() return hidGame end

function GF.FramesRendered(display, visible)
    if visible then frameDisplays[display] = true else frameDisplays[display] = nil end
    local want = visible and display.ds and display.ds.hideGameFrames == true and not DT.editorPreview and not DT.unlocked
    -- (while editing / moving, sample frames show: the game's stay as they are until the real ones show)
    if want then hiders[display] = true else hiders[display] = nil end
    ApplyGameFrames()
end
function GF.FramesHidden(display)
    frameDisplays[display] = nil
    hiders[display] = nil
    ApplyGameFrames()
end
GF.FramesGone = GF.FramesHidden

------------------------------------------------------------------------------
-- "On group frames": placing entries on each member's frame
------------------------------------------------------------------------------

function GF.SetActive(display, on)
    if on then active[display] = true else active[display] = nil end
    if not on and display.order then
        for _, it in ipairs(display.order) do
            it.placed = false
            if it.control then it.control:SetHidden(true) end
        end
    end
end
function GF.IsActive(display) return active[display] == true end

-- the group frames display an "On group frames" tracker uses: the one it names, else the first one shown
local function FramesFor(ds)
    local want = ds.framesOf or ""
    if want ~= "" then
        local d = DT.Displays.Get(want)
        if d and frameDisplays[d] then return d end
        return nil
    end
    for _, t in ipairs(DT.Engine.trackers) do
        local d = DT.Displays.Get(t.id)
        if d and frameDisplays[d] then return d end
    end
    return nil
end
GF.FramesFor = FramesFor

local function HideAll(items)
    for _, it in ipairs(items) do
        it.placed = false
        it.control:SetHidden(true)
    end
end

local byFrame = {}      -- [frames display] = { [unit tag] = frame item }
local stacks = {}       -- [frame item] = { right = px, left = px, inside = px, bottom = px, top = px }

local function FrameMap(fd)
    local map = byFrame[fd]
    if not map then map = {}; byFrame[fd] = map end
    for k in pairs(map) do map[k] = nil end
    for _, it in ipairs(fd.order or {}) do
        local s = it.state
        if s and not it.control:IsHidden() then
            local tag = s.memberTag or s.unitTag
            if tag then map[tag] = it end
        end
    end
    return map
end

local function PlaceIcons(d, items, frame, spot, size, gap, offset)
    local x = offset
    local fc = frame.control
    for _, it in ipairs(items) do
        DT.Displays.SizeHeadItem(it, d, size)
        it.placed = true
        it.control:SetHidden(false)
        it.control:ClearAnchors()
        if spot == "left" then
            it.control:SetAnchor(RIGHT, fc, LEFT, -(gap + x), 0)
        elseif spot == "inside" then
            it.control:SetAnchor(RIGHT, fc, RIGHT, -(2 + x), 0)
        else
            it.control:SetAnchor(LEFT, fc, RIGHT, gap + x, 0)
        end
        x = x + size + gap
    end
    return x
end

local function PlaceBars(d, items, frame, spot, thick, offset)
    local fc = frame.control
    local w = fc:GetWidth()
    local y = offset
    for _, it in ipairs(items) do
        it.barW, it.barH = w, thick
        it.control:SetDimensions(w, thick)
        it.placed = true
        it.control:SetHidden(false)
        it.control:ClearAnchors()
        if spot == "top" then
            it.control:SetAnchor(TOPLEFT, fc, TOPLEFT, 0, y)
        else
            it.control:SetAnchor(BOTTOMLEFT, fc, BOTTOMLEFT, 0, -y)
        end
        y = y + thick + 1
    end
    return y
end

local byTag = {}
-- Once per update (end of Engine.Tick): every active "On group frames" tracker, in profile order, on its frames.
function GF.Place()
    if not next(active) then return end
    for k in pairs(stacks) do stacks[k] = nil end
    local maps = {}
    for _, t in ipairs(DT.Engine.trackers) do
        local d = DT.Displays.Get(t.id)
        if d and active[d] and not d.window:IsHidden() then
            local ds = d.ds
            local fd = FramesFor(ds)
            if not fd then
                HideAll(d.order)
            else
                local map = maps[fd]
                if not map then map = FrameMap(fd); maps[fd] = map end
                for k in pairs(byTag) do byTag[k] = nil end
                for _, it in ipairs(d.order) do
                    local tag = it.state and it.state.unitTag
                    local frame = tag and map[tag]
                    if frame then
                        local list = byTag[frame]
                        if not list then list = {}; byTag[frame] = list end
                        if #list < (ds.maxShown or 10) then list[#list + 1] = it
                        else it.placed = false; it.control:SetHidden(true) end
                    else
                        it.placed = false
                        it.control:SetHidden(true)
                    end
                end
                local bar = d.kind == "framebar"
                local spot = bar and (ds.frameSpot == "top" and "top" or "bottom")
                    or ((ds.frameSpot == "left" or ds.frameSpot == "inside") and ds.frameSpot or "right")
                for frame, list in pairs(byTag) do
                    local st = stacks[frame]
                    if not st then st = {}; stacks[frame] = st end
                    if bar then
                        st[spot] = PlaceBars(d, list, frame, spot, math.max(1, ds.frameBarSize or 3), st[spot] or 0)
                    else
                        local fh = frame.control:GetHeight()
                        local size = (ds.frameIconSize or 0) > 0 and ds.frameIconSize or math.max(10, math.floor(fh - 2))
                        st[spot] = PlaceIcons(d, list, frame, spot, size, math.max(1, ds.spacing or 2), st[spot] or 0)
                    end
                end
            end
        end
    end
end

------------------------------------------------------------------------------
-- The mouse on a frame
------------------------------------------------------------------------------

local function Fn(name) local f = rawget(_G, name); return type(f) == "function" and f or nil end

local function Line(text)
    if InformationTooltip and InformationTooltip.AddLine then InformationTooltip:AddLine(text, "ZoFontGame") end
end

-- The member's gear sets, when LibSetDetection is installed (optional): it shares each player's equipped sets with the
-- group (members need it too). LibSetDetection 5: GetUnitSetData(tag) = { [setId] = { activeType, numEquip = { body,
-- front, back }, setName, maxEquip } } ("body" counts on both bars), {} while no data came from that member.
local ACTIVE_TEXT = { [1] = "both bars", [2] = "front bar", [3] = "back bar" }
function GF.SetLines(tag)
    local lsd = rawget(_G, "LibSetDetection")
    if type(lsd) ~= "table" or type(lsd.GetUnitSetData) ~= "function" or not tag then return nil end
    local data = lsd.GetUnitSetData(tag)
    if type(data) ~= "table" or next(data) == nil then
        return { "|c888888" .. L("No set data (they need LibSetDetection too)") .. "|r" }
    end
    local list = {}
    for setId, d in pairs(data) do
        if type(d) == "table" then
            local n = d.numEquip or {}
            local body = tonumber(n.body) or 0
            local most = math.max(body + (tonumber(n.front) or 0), body + (tonumber(n.back) or 0))
            local name = d.setName
            if (not name or name == "") and type(lsd.GetSetName) == "function" then name = lsd.GetSetName(setId) end
            list[#list + 1] = { name = U.CleanName(name or tostring(setId)), most = most, max = tonumber(d.maxEquip) or 0,
                active = tonumber(d.activeType) or 0 }
        end
    end
    table.sort(list, function(a, b)
        if (a.active > 0) ~= (b.active > 0) then return a.active > 0 end
        return a.name < b.name
    end)
    local out = {}
    for _, x in ipairs(list) do
        local count = x.max > 0 and string.format("%d/%d", x.most, x.max) or tostring(x.most)
        if x.active > 0 then
            out[#out + 1] = string.format("|cE8C878%s|r  %s  |c9AA0A8%s|r", x.name, count, L(ACTIVE_TEXT[x.active] or ""))
        else
            out[#out + 1] = string.format("|c888888%s  %s|r", x.name, count)
        end
    end
    return out
end

-- The effects on the member right now (the game's own list, GetUnitBuffInfo): timed ones by time left, debuffs in
-- red; "all" adds the ones without an end (passives, food, set bonuses...) after them. At most MAX_EFFECTS lines.
local MAX_EFFECTS = 16
local FOREVER = 4000000     -- seconds: longer than any real effect (the game uses huge end times for "no end")
function GF.EffectLines(tag, mode)
    if mode == "none" or not tag or type(GetNumBuffs) ~= "function" then return nil end
    local now = GetFrameTimeSeconds()
    local timed, lasting = {}, {}
    for i = 1, GetNumBuffs(tag) or 0 do
        local name, _, finish, _, stacks, icon, _, effectType = GetUnitBuffInfo(tag, i)
        if name and name ~= "" then
            local left = (finish or 0) - now
            local e = { name = U.CleanName(name), icon = icon, left = left, stacks = tonumber(stacks) or 0,
                debuff = BUFF_EFFECT_TYPE_DEBUFF ~= nil and effectType == BUFF_EFFECT_TYPE_DEBUFF }
            if left > 0 and left < FOREVER then timed[#timed + 1] = e else lasting[#lasting + 1] = e end
        end
    end
    table.sort(timed, function(a, b) return a.left < b.left end)
    table.sort(lasting, function(a, b) return a.name < b.name end)
    local list = timed
    if mode == "all" then for _, e in ipairs(lasting) do list[#list + 1] = e end end
    if #list == 0 then return { "|c888888" .. L("No effects") .. "|r" } end
    local out = {}
    for i, e in ipairs(list) do
        if i > MAX_EFFECTS then
            out[#out + 1] = "|c888888" .. L("+<<1>> more", #list - MAX_EFFECTS) .. "|r"
            break
        end
        local text = (e.icon and e.icon ~= "" and ("|t18:18:" .. e.icon .. "|t ") or "") .. e.name
        if e.stacks > 1 then text = text .. " x" .. e.stacks end
        if e.left > 0 and e.left < FOREVER then text = text .. "  |c9AA0A8" .. U.FormatTime(e.left, "auto") .. "|r" end
        if e.debuff then text = "|cF07070" .. text .. "|r" end
        out[#out + 1] = text
    end
    return out
end

function GF.TooltipLines(s, ds)
    local out = {}
    local title = s.account ~= "" and s.account or s.character or s.unitName or ""
    out[#out + 1] = title
    if s.character and s.character ~= "" and s.character ~= title then out[#out + 1] = s.character end
    if s.companion then
        out[#out + 1] = L("Companion")
    else
        local bits = {}
        if s.classId and s.classId ~= 0 and Fn("GetClassName") then
            local icon = DT.Group.ClassIcon(s.classId)
            bits[#bits + 1] = (icon and ("|t20:20:" .. icon .. "|t ") or "") .. U.CleanName(GetClassName(GENDER_MALE or 1, s.classId) or "")
        end
        local roleTex = U.ROLE_ICONS[s.role or ""]
        if roleTex then bits[#bits + 1] = "|t20:20:" .. roleTex .. "|t " .. L(({ tank = "Tank", healer = "Healer", dps = "Damage" })[s.role]) end
        if s.leader then bits[#bits + 1] = L("Group leader") end
        if #bits > 0 then out[#out + 1] = table.concat(bits, "   ") end
    end
    local status = DT.Displays.FrameStatusText(s)
    if status then
        out[#out + 1] = status
    else
        local hp = string.format("%s / %s (%d%%)", DT.Displays.ShortNumber(s.value), DT.Displays.ShortNumber(s.max), math.floor((s.pct or 0) + 0.5))
        out[#out + 1] = L("Health: <<1>>", hp)
        if (s.shield or 0) > 0 then out[#out + 1] = L("Damage shield: <<1>>", DT.Displays.ShortNumber(s.shield)) end
        if (s.trauma or 0) > 0 then out[#out + 1] = L("Trauma: <<1>>", DT.Displays.ShortNumber(s.trauma)) end
        if s.noHeal then out[#out + 1] = L("Can't be healed") end
        if s.inRange == false and not s.isMe then out[#out + 1] = L("Out of support range") end
    end
    if s.unitTag and Fn("GetUnitZone") and not s.isMe then
        local zone = GetUnitZone(s.unitTag)
        if zone and zone ~= "" then out[#out + 1] = U.CleanName(zone) end
    end
    -- what they wear and what's on them (only read while the mouse is on the frame)
    if s.unitTag and not s.companion and s.online ~= false and (not ds or ds.frameTipSets ~= false) then
        local sets = GF.SetLines(s.unitTag)
        if sets then
            out[#out + 1] = "|cC5A572" .. L("Sets") .. "|r"
            for _, l in ipairs(sets) do out[#out + 1] = l end
        end
    end
    if s.unitTag and s.online ~= false and not s.dead then
        local effects = GF.EffectLines(s.unitTag, ds and ds.frameTipEffects or "timed")
        if effects then
            out[#out + 1] = "|cC5A572" .. L("Effects") .. "|r"
            for _, l in ipairs(effects) do out[#out + 1] = l end
        end
    end
    if s.unitTag and not s.companion then out[#out + 1] = "|c888888" .. L("Right-click: group options") .. "|r" end
    return out
end

function GF.OnEnter(it, display)
    local s = it.state
    if not s or not InformationTooltip or type(InitializeTooltip) ~= "function" then return end
    if DT.unlocked then return end
    InitializeTooltip(InformationTooltip, it.control, TOPLEFT, 0, 0, TOPRIGHT)
    local lines = GF.TooltipLines(s, display.ds)
    if type(SetTooltipText) == "function" then SetTooltipText(InformationTooltip, lines[1]) else Line(lines[1]) end
    for i = 2, #lines do Line(lines[i]) end
    it.tooltip = true
end

function GF.OnExit(it, display)
    if it.tooltip and type(ClearTooltip) == "function" and InformationTooltip then ClearTooltip(InformationTooltip) end
    it.tooltip = nil
end

-- The menu, as the game's group list builds it. Returns { { text, fn }, ... } (the tests read it).
function GF.MenuEntries(s)
    local out = {}
    local tag = s.unitTag
    if not tag or s.companion or s.preview then return out end
    local function Add(sid, fn)
        local text = rawget(_G, sid) and GetString(rawget(_G, sid)) or sid
        out[#out + 1] = { text, fn, id = sid }
    end
    local isMe = s.isMe
    local name = s.account ~= "" and s.account or s.character
    if isMe then
        Add("SI_GROUP_LIST_MENU_LEAVE_GROUP", function() ZO_Dialogs_ShowDialog("GROUP_LEAVE_DIALOG") end)
    elseif s.online ~= false then
        if not Fn("IsChatSystemAvailableForCurrentPlatform") or IsChatSystemAvailableForCurrentPlatform() then
            Add("SI_SOCIAL_LIST_PANEL_WHISPER", function() StartChatInput("", CHAT_CHANNEL_WHISPER, name) end)
        end
        Add("SI_SOCIAL_MENU_JUMP_TO_PLAYER", function() JumpToGroupMember(name) end)
    end
    local playerLeader = Fn("IsUnitGroupLeader") and IsUnitGroupLeader("player")
    if not Fn("IsGroupModificationAvailable") or IsGroupModificationAvailable() then
        local vote = Fn("DoesGroupModificationRequireVote") and DoesGroupModificationRequireVote()
        if playerLeader then
            if isMe then
                if not vote then Add("SI_GROUP_LIST_MENU_DISBAND_GROUP", function() ZO_Dialogs_ShowDialog("GROUP_DISBAND_DIALOG") end) end
            elseif not vote then
                Add("SI_GROUP_LIST_MENU_KICK_FROM_GROUP", function() GroupKick(tag) end)
            end
        end
        if vote and not isMe then
            Add("SI_GROUP_LIST_MENU_VOTE_KICK_FROM_GROUP", function()
                BeginGroupElection(GROUP_ELECTION_TYPE_KICK_MEMBER, ZO_GROUP_ELECTION_DESCRIPTORS and ZO_GROUP_ELECTION_DESCRIPTORS.NONE, tag)
            end)
        end
    end
    if playerLeader and not isMe and s.online ~= false then
        Add("SI_GROUP_LIST_MENU_PROMOTE_TO_LEADER", function() GroupPromote(tag) end)
    end
    return out
end

function GF.OnClick(it, display, button, upInside)
    if upInside == false or DT.unlocked then return end
    local s = it.state
    if not s then return end
    local right = MOUSE_BUTTON_INDEX_RIGHT or 2
    if button == right then
        local entries = GF.MenuEntries(s)
        if #entries == 0 or type(ClearMenu) ~= "function" then return end
        ClearMenu()
        for _, e in ipairs(entries) do AddMenuItem(e[1], e[2]) end
        ShowMenu(it.control)
    elseif DT.Displays.ClickToEdit() and display.tracker then
        -- with the editor open, a click opens the tracker in it (like every other tracker window)
        DT.UI.Edit(display.tracker.id)
    end
end
