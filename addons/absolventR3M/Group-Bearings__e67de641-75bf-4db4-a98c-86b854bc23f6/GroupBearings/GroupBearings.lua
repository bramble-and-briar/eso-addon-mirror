-- Group Bearings: saved settings, group roster, per-frame update, preview.

local GB = GroupBearings
local Core = GB.Core

GB.ADDON_NAME = "GroupBearings"
GB.DISPLAY_NAME = "Group Bearings"
GB.VERSION = "0.1.0"
GB.AUTHOR = "absolventR3M"
GB.SAVED_VARIABLES = "GroupBearings_SV"

local UPDATE_NAME = "GroupBearings_Update"
local IDLE_INTERVAL_MS = 100       -- solo with nothing to track: 10 checks a second is plenty
local ROSTER_REFRESH_MS = 1000     -- safety net on top of the group and marker events
local TEXTURE_CHECK_MS = 1000
local PREVIEW_SECONDS = 30
local CHAT_COLOR = "9FD3FF"

GB.DEFAULTS = {
    enabled = true,

    -- Compass: distance under marked symbols
    markerDistances = true,

    -- Group members: distances under the game's own group pins on the compass,
    -- and a light beam over each member without a symbol.
    groupDistances = false,
    memberBeams = false,
    memberBeamColor = "By role",           -- a name from GB.MEMBER_BEAM_COLOR_CHOICES
    memberBeamCustomColor = { 0.45, 0.80, 1.00, 1 },

    -- Crown (group leader)
    crownAsSymbol = false,      -- show the crown's distance on the compass
    crownBeam = true,           -- light beam over the crown (while the crown is tracked)
    crownArrow = true,          -- arrow at your feet toward the crown (while tracked)
    keepCrown = true,           -- the crown icon draws over every compass marker it overlaps
    crownOnTop = false,         -- the crown wins every overlap, whatever the distance
    crownColor = "Game default",           -- a name from GB.CROWN_COLOR_CHOICES
    crownCustomColor = { 1.00, 0.85, 0.30, 1 },

    -- Symbols at your feet, with the light beam
    pointers = false,
    pointerArrows = true,
    pointerSize = 100,          -- percent
    pointerSpacing = 45,        -- degrees: closer arrows win inside this angle, 0 = off
    beam = true,
    beamTransparency = 50,      -- percent
    beamMinDistance = 15,       -- metres, 0 = always
    beamMaxDistance = 0,        -- metres, 0 = no limit
    beamThroughWalls = false,   -- off: hills and walls hide the bottom of the beam

    -- Advanced
    compassFov = Core.DEFAULT_FOV_DEGREES,
    labelOffset = 0,            -- extra pixels below the compass
}

---------------------------------------------------------------------------
-- Symbols
---------------------------------------------------------------------------
local MARKER_STYLES = {
    { "ONE",   "Target_Blue_Square",     { 0.35, 0.62, 1.00 } },
    { "TWO",   "Target_Gold_Star",       { 1.00, 0.82, 0.22 } },
    { "THREE", "Target_Green_Circle",    { 0.35, 0.90, 0.35 } },
    { "FOUR",  "Target_Orange_Triangle", { 1.00, 0.55, 0.12 } },
    { "FIVE",  "Target_Pink_Moons",      { 1.00, 0.45, 0.80 } },
    { "SIX",   "Target_Purple_Oblivion", { 0.72, 0.45, 1.00 } },
    { "SEVEN", "Target_Red_Weapons",     { 1.00, 0.28, 0.28 } },
    { "EIGHT", "Target_White_Skull",     { 0.95, 0.95, 0.95 } },
}

GB.CROWN_STYLE = {
    color = { 0.55, 0.88, 1.00 },
    compassTexture = "EsoUI/Art/Compass/groupLeader.dds",
}

GB.markers = {}           -- [TARGET_MARKER_TYPE_*] = { color, compassTexture }
GB.markerByPinType = {}   -- [MAP_PIN_TYPE_TARGET_MARKER_TYPE_*] = TARGET_MARKER_TYPE_*

local function BuildMarkerStyles()
    for _, s in ipairs(MARKER_STYLES) do
        local markerType = _G["TARGET_MARKER_TYPE_" .. s[1]]
        if markerType ~= nil then
            GB.markers[markerType] = {
                color = s[3],
                compassTexture = "EsoUI/Art/Compass/" .. s[2] .. ".dds",
            }
            local pinType = _G["MAP_PIN_TYPE_TARGET_MARKER_TYPE_" .. s[1]]
            if pinType ~= nil then GB.markerByPinType[pinType] = markerType end
        end
    end
end

-- Icon shown at your feet: the game's own target marker art.
function GB.GetSymbolIcon(markerType)
    if markerType == nil then return GB.CROWN_STYLE.compassTexture end
    if ZO_GetPlatformTargetMarkerIcon then
        local icon = ZO_GetPlatformTargetMarkerIcon(markerType)
        if icon then return icon end
    end
    local style = GB.markers[markerType]
    return style and style.compassTexture
end

-- Colour of a symbol's arrow and beam; nil markerType means the crown.
function GB.GetSymbolColor(markerType)
    if markerType == nil then return GB.GetCrownBeamColor() end
    local style = GB.markers[markerType]
    return style and style.color or GB.CROWN_STYLE.color
end

local MARKER_NAMES = {
    ONE = "Blue Square", TWO = "Gold Star", THREE = "Green Circle", FOUR = "Orange Triangle",
    FIVE = "Pink Moons", SIX = "Purple Oblivion", SEVEN = "Red Weapons", EIGHT = "White Skull",
}
function GB.GetSymbolName(markerType)
    for _, s in ipairs(MARKER_STYLES) do
        if _G["TARGET_MARKER_TYPE_" .. s[1]] == markerType then return MARKER_NAMES[s[1]] end
    end
    return "Symbol"
end

---------------------------------------------------------------------------
-- Colours: member beams, and the crown's beam and arrow. Each setting is a name
-- from a list: a fixed colour, "Custom" (its colour picker), or a special
-- choice ("By role" for members, "Game default" = light blue for the crown).
-- Compass icons always keep the game's own look: the game greys a texture after
-- its colour is applied, and its icons are coloured already, so recolouring
-- them only ever gives grey or white.
---------------------------------------------------------------------------
GB.COLORS = {
    { name = "Green",  color = { 0.20, 0.85, 0.25, 1 } },
    { name = "Red",    color = { 1.00, 0.25, 0.25, 1 } },
    { name = "Blue",   color = { 0.30, 0.55, 1.00, 1 } },
    { name = "Yellow", color = { 1.00, 0.90, 0.20, 1 } },
    { name = "Orange", color = { 1.00, 0.55, 0.10, 1 } },
    { name = "Purple", color = { 0.70, 0.40, 1.00, 1 } },
    { name = "Pink",   color = { 1.00, 0.45, 0.80, 1 } },
    { name = "Cyan",   color = { 0.30, 0.90, 1.00, 1 } },
    { name = "Gold",   color = { 1.00, 0.80, 0.25, 1 } },
    { name = "White",  color = { 1.00, 1.00, 1.00, 1 } },
}
local COLOR_BY_NAME = {}
for _, c in ipairs(GB.COLORS) do COLOR_BY_NAME[c.name] = c.color end

local function Choices(first, last)
    local list = {}
    for _, name in ipairs(first) do list[#list + 1] = name end
    for _, c in ipairs(GB.COLORS) do list[#list + 1] = c.name end
    for _, name in ipairs(last) do list[#list + 1] = name end
    return list
end
GB.MEMBER_BEAM_COLOR_CHOICES = Choices({ "By role" }, { "Custom" })
GB.CROWN_COLOR_CHOICES = Choices({ "Game default" }, { "Custom" })

-- Role colours for "By role": tank blue, healer green, damage red.
GB.ROLE_COLORS = {}
local function BuildRoleColors()
    if LFG_ROLE_TANK then GB.ROLE_COLORS[LFG_ROLE_TANK] = { 0.35, 0.60, 1.00, 1 } end
    if LFG_ROLE_HEAL then GB.ROLE_COLORS[LFG_ROLE_HEAL] = { 0.35, 0.90, 0.35, 1 } end
    if LFG_ROLE_DPS then GB.ROLE_COLORS[LFG_ROLE_DPS] = { 1.00, 0.35, 0.30, 1 } end
end

-- Colour of the beam over a group member without a symbol.
function GB.GetMemberBeamColor(role)
    local choice = GB.sv.memberBeamColor
    if choice == "By role" then return GB.ROLE_COLORS[role] or COLOR_BY_NAME.White end
    if choice == "Custom" then return GB.sv.memberBeamCustomColor end
    return COLOR_BY_NAME[choice] or COLOR_BY_NAME.White
end

-- The crown colour chosen for its beam and arrow; nil for Game default.
function GB.GetCrownColor()
    local choice = GB.sv.crownColor
    if choice == "Game default" then return nil end
    if choice == "Custom" then return GB.sv.crownCustomColor end
    return COLOR_BY_NAME[choice]
end

-- The crown's arrow and beam use the crown colour, or light blue by default.
function GB.GetCrownBeamColor()
    return GB.GetCrownColor() or GB.CROWN_STYLE.color
end

function GB.IsCrownTracked()
    local sv = GB.sv
    return sv.crownAsSymbol == true or sv.crownOnTop == true
end

-- The crown icon is drawn above every other compass marker (Keep the crown when
-- overlapping, or Crown always on top, which includes it).
function GB.IsCrownKeptOnTop()
    local sv = GB.sv
    return sv.keepCrown == true or sv.crownOnTop == true
end

---------------------------------------------------------------------------
-- Textures we ship, each with a game texture to fall back on if ours does not load
---------------------------------------------------------------------------
GB.TEXTURES = {
    chevron = { file = "GroupBearings/Textures/chevron.dds", fallback = "EsoUI/Art/Buttons/Gamepad/gp_downArrow.dds", users = {} },
    beam = { file = "GroupBearings/Textures/beam.dds", fallback = "", users = {} },
}

function GB.UseTexture(control, kind)
    local t = GB.TEXTURES[kind]
    t.users[#t.users + 1] = control
    control:SetTexture(t.useFallback and t.fallback or t.file)
end

-- Once a second: if one of our textures has been on screen for a few seconds
-- without loading, switch that kind to the game's texture for the session.
function GB.CheckTextures(now)
    for _, t in pairs(GB.TEXTURES) do
        if not t.verified and not t.useFallback then
            for _, control in ipairs(t.users) do
                if control.IsTextureLoaded and not control:IsHidden() then
                    if control:IsTextureLoaded() then
                        t.verified = true
                    else
                        t.firstSeen = t.firstSeen or now
                        if now - t.firstSeen >= 3000 then
                            t.useFallback = true
                            for _, user in ipairs(t.users) do user:SetTexture(t.fallback) end
                        end
                    end
                    break
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Chat
---------------------------------------------------------------------------
function GB.Say(text)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(string.format("|c%s[Group Bearings] %s|r", CHAT_COLOR, text))
    end
end

---------------------------------------------------------------------------
-- Group roster (unit tags, leader, symbol), refreshed on events and once a second
---------------------------------------------------------------------------
local roster = { count = 0, tags = {}, isLeader = {}, marker = {}, role = {} }
GB.roster = roster

local state = {
    running = false,
    rosterDirty = true,
    nextRosterAt = 0,
    nextIdleAt = 0,
    nextTextureCheckAt = 0,
}

-- The game's own map only asks "same instance?" inside dungeons and houses
-- (ZO_WorldMapPins_Manager:RefreshGroupPins); in the open world the answer is
-- not meaningful. Do the same, so overworld groups are never dropped.
local function InInstancedArea()
    if IsUnitInDungeon and IsUnitInDungeon("player") then return true end
    if GetCurrentZoneHouseId and GetCurrentZoneHouseId() ~= 0 then return true end
    return false
end

-- Why a group member can't be tracked right now, or nil if they can.
local function SkipReason(tag, instanced)
    if not tag or not DoesUnitExist(tag) then return "no unit" end
    if AreUnitsEqual(tag, "player") then return "you" end
    if not IsUnitOnline(tag) then return "offline" end
    if instanced and IsGroupMemberInSameInstanceAsPlayer and IsGroupMemberInSameInstanceAsPlayer(tag) == false then
        return "another instance"
    end
    return nil
end

local function RefreshRoster(now)
    state.rosterDirty = false
    state.nextRosterAt = now + ROSTER_REFRESH_MS
    local n = 0
    local size = GetGroupSize and GetGroupSize() or 0
    -- Ask both ways: the leader's unit tag, and each member's leader flag.
    local leaderTag = (size > 0 and GetGroupLeaderUnitTag) and GetGroupLeaderUnitTag() or ""
    roster.grouped = size > 0
    roster.playerLeads = size > 0 and (IsUnitGroupLeader("player") == true
        or (leaderTag ~= "" and AreUnitsEqual(leaderTag, "player")))
    roster.leaderFound = false
    local instanced = size > 0 and InInstancedArea()
    for i = 1, size do
        local tag = GetGroupUnitTagByIndex(i)
        if SkipReason(tag, instanced) == nil then
            n = n + 1
            local isLeader = IsUnitGroupLeader(tag) == true or (leaderTag ~= "" and AreUnitsEqual(tag, leaderTag))
            roster.tags[n] = tag
            roster.isLeader[n] = isLeader
            roster.marker[n] = GetUnitTargetMarkerType(tag)
            roster.role[n] = GetGroupMemberSelectedRole and GetGroupMemberSelectedRole(tag) or nil
            if isLeader then roster.leaderFound = true end
        end
    end
    for i = n + 1, roster.count do
        roster.tags[i], roster.isLeader[i], roster.marker[i], roster.role[i] = nil, nil, nil, nil
    end
    roster.count = n
end

local function MarkRosterDirty()
    state.rosterDirty = true
end

---------------------------------------------------------------------------
-- Preview: fake symbols and group members around you for a short while
---------------------------------------------------------------------------
local preview = nil

local PREVIEW_LAYOUT = {
    -- angle in degrees (+ is right of where the camera faces), distance in metres
    { kind = "marker", marker = "TWO", angle = 0, dist = 25 },     -- gold star dead ahead
    { kind = "marker", marker = "ONE", angle = 6, dist = 40 },     -- overlaps the star: the closer one keeps the text
    { kind = "member", angle = -25, dist = 30, role = "TANK" },    -- two members side by side: only the closer one's distance
    { kind = "member", angle = -26.5, dist = 34, role = "HEAL" },
    { kind = "leader", angle = 50, dist = 60, role = "DPS" },      -- far enough from the star that both arrows show
    { kind = "marker", marker = "THREE", angle = 52, dist = 45 },  -- covers the crown unless Keep the crown is on
    { kind = "member", angle = -45, dist = 80, role = "DPS" },
}

function GB.IsPreviewActive()
    return preview ~= nil
end

function GB.StartPreview()
    if not (GB.sv and GB.sv.enabled) then
        GB.Say("Turn Group Bearings on first (Settings > Add-Ons > Group Bearings).")
        return
    end
    local sv = GB.sv
    if not GB.HasWork() then
        GB.Say("Turn on at least one feature first, then preview.")
        return
    end
    local zoneId, px, py, pz = GetUnitRawWorldPosition("player")
    local heading = Core.NormalizeAngle(GetPlayerCameraHeading() or 0)
    local items = {}
    for i, item in ipairs(PREVIEW_LAYOUT) do
        local x, z = Core.OffsetFromHeading(px, pz, heading, math.rad(item.angle), item.dist * 100)
        items[i] = {
            kind = item.kind,
            markerType = item.marker and _G["TARGET_MARKER_TYPE_" .. item.marker] or nil,
            role = item.role and _G["LFG_ROLE_" .. item.role] or nil,
            x = math.floor(x + 0.5), y = py, z = math.floor(z + 0.5),
        }
    end
    preview = { zoneId = zoneId, untilMs = GetFrameTimeMilliseconds() + PREVIEW_SECONDS * 1000, items = items }
    GB.Say(string.format("Preview for %d seconds. Close the menu and look around.", PREVIEW_SECONDS))
    GB.Refresh()
end

function GB.StopPreview()
    if preview then
        preview = nil
        GB.Refresh()
    end
end

---------------------------------------------------------------------------
-- Per-frame update
---------------------------------------------------------------------------
local markerEntries, memberEntries, pointerEntries = {}, {}, {}
local markersSeen = {}

function GB.NewEntry(pool, n)
    local e = pool[n]
    if not e then
        e = {}
        pool[n] = e
    end
    return e
end
local NewEntry = GB.NewEntry

local function HasPosition(x, z)
    return x ~= 0 or z ~= 0
end

---------------------------------------------------------------------------
-- Marked NPCs under your crosshair. The game shares an NPC's position while
-- your crosshair is on it (close range only; players outside your group always
-- read 0,0,0). While it keeps updating it gets everything a group member gets.
-- Once it stops, only the beam stays on the last known spot for a while,
-- fading out, since the spot is still useful as "last seen here".
-- (Same approach as NdgCrown.)
---------------------------------------------------------------------------
local SIGHTING_FRESH_MS = 1000
local BEAM_LINGER_MS = 10000
local BEAM_FADE_PORTION = 0.3
local sightings = {}   -- [markerType] = { zone, x, y, z, seenAt }
GB.sightings = sightings

function GB.ClearSightings()
    for k in pairs(sightings) do sightings[k] = nil end
end

local function ReticleMarker(NONE)
    local marker = GetUnitTargetMarkerType("reticleover")
    if marker ~= nil and marker ~= NONE and GB.markers[marker] ~= nil then return marker end
    return nil
end

-- One frame's worth of targets. Kept at file scope so the update allocates nothing.
local frame = { px = 0, py = 0, pz = 0, heading = 0, markers = 0, members = 0, pointers = 0 }

-- live = false: last known spot of a marked NPC (beam only, at beamFactor strength).
local function AddTarget(order, marked, markerType, isLeader, tx, ty, tz, drawIcon, live, beamFactor, role)
    local dist = Core.Distance3D(frame.px, frame.py, frame.pz, tx, ty, tz)
    local angle = Core.RelativeAngle(frame.px, frame.pz, tx, tz, frame.heading)
    local text = Core.FormatDistance(dist)
    live = live ~= false
    if live then
        local e
        if marked then
            frame.markers = frame.markers + 1
            e = NewEntry(markerEntries, frame.markers)
            e.markerType = markerType
            e.drawIcon = drawIcon
            e.isCrown = isLeader == true and GB.IsCrownTracked()
            e.leaderSymbol = isLeader == true -- a symbol on the leader: the crown can go over it
            markersSeen[markerType] = true
        else
            frame.members = frame.members + 1
            e = NewEntry(memberEntries, frame.members)
            e.isLeader = isLeader
            e.role = role
            e.drawIcon = drawIcon -- preview members: the game has no pin for them
        end
        e.order, e.dist, e.angle, e.text = order, dist, angle, text
    end
    local crown = isLeader == true and GB.IsCrownTracked()
    -- Members without a symbol can get a beam of their own (Beam over group members).
    local memberBeam = not marked and GB.sv.memberBeams == true
    if marked or crown or memberBeam then
        frame.pointers = frame.pointers + 1
        local p = NewEntry(pointerEntries, frame.pointers)
        p.order = order
        p.markerType = marked and markerType or nil
        p.isCrown = crown
        p.marked = marked
        p.memberBeam = memberBeam
        p.role = role
        p.x, p.y, p.z, p.dist, p.text = tx, ty, tz, dist, text
        p.live, p.beamFactor = live, beamFactor or 1
    end
end

local function OnUpdate()
    local now = GetFrameTimeMilliseconds()
    if preview and now >= preview.untilMs then
        GB.StopPreview()
        if not state.running then return end
    end
    if state.rosterDirty or now >= state.nextRosterAt then
        RefreshRoster(now)
    end
    local NONE = TARGET_MARKER_TYPE_NONE
    local reticleMarker = ReticleMarker(NONE)
    local busy = roster.count > 0 or preview ~= nil or reticleMarker ~= nil or next(sightings) ~= nil
    -- Idle: check 10 times a second. The first idle frame still draws, so
    -- whatever was on screen clears right away.
    if not busy and not state.wasBusy then
        if now < state.nextIdleAt then return end
        state.nextIdleAt = now + IDLE_INTERVAL_MS
    end
    state.wasBusy = busy
    if now >= state.nextTextureCheckAt then
        state.nextTextureCheckAt = now + TEXTURE_CHECK_MS
        GB.CheckTextures(now)
    end

    local zoneId, px, py, pz = GetUnitRawWorldPosition("player")
    frame.px, frame.py, frame.pz = px, py, pz
    frame.heading = Core.NormalizeAngle(GetPlayerCameraHeading() or 0)
    frame.markers, frame.members, frame.pointers = 0, 0, 0
    for k in pairs(markersSeen) do markersSeen[k] = nil end

    for i = 1, roster.count do
        local z, tx, ty, tz = GetUnitRawWorldPosition(roster.tags[i])
        if z == zoneId and HasPosition(tx, tz) then
            local marker = roster.marker[i]
            local marked = marker ~= nil and marker ~= NONE and GB.markers[marker] ~= nil
            AddTarget(i, marked, marked and marker or nil, roster.isLeader[i], tx, ty, tz, false, nil, nil, roster.role[i])
        end
    end

    -- Group members first: a symbol on a group member never comes from the crosshair.
    if reticleMarker and not markersSeen[reticleMarker] then
        local z, x, y, zz = GetUnitWorldPosition("reticleover")
        if not HasPosition(x, zz) then
            z, x, y, zz = GetUnitRawWorldPosition("reticleover")
        end
        if z == zoneId and HasPosition(x, zz) then
            local s = sightings[reticleMarker]
            if not s then
                s = {}
                sightings[reticleMarker] = s
            end
            s.zone, s.x, s.y, s.z, s.seenAt = z, x, y, zz, now
        end
    end
    for markerType, s in pairs(sightings) do
        local age = now - s.seenAt
        if markersSeen[markerType] or s.zone ~= zoneId or age > SIGHTING_FRESH_MS + BEAM_LINGER_MS then
            sightings[markerType] = nil
        else
            AddTarget(300 + markerType, true, markerType, false, s.x, s.y, s.z, false,
                age <= SIGHTING_FRESH_MS, Core.LingerFactor(age, SIGHTING_FRESH_MS, BEAM_LINGER_MS, BEAM_FADE_PORTION))
        end
    end

    if preview and preview.zoneId == zoneId then
        for k, item in ipairs(preview.items) do
            if item.kind == "marker" then
                if item.markerType and not markersSeen[item.markerType] then
                    AddTarget(100 + k, true, item.markerType, false, item.x, item.y, item.z, true)
                end
            else
                AddTarget(100 + k, false, nil, item.kind == "leader", item.x, item.y, item.z, true, nil, nil, item.role)
            end
        end
    end

    GB.Compass.Render(markerEntries, frame.markers, memberEntries, frame.members, markersSeen)
    GB.World.Render(pointerEntries, frame.pointers, px, py, pz, frame.heading)
end

-- An error inside a per-frame update would pop up every frame. Stop instead,
-- say so once, and let a settings change or Reload UI start it again.
local function SafeUpdate()
    local ok, err = pcall(OnUpdate)
    if not ok then
        state.running = false
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
        pcall(GB.Compass.HideAll)
        pcall(GB.World.HideAll)
        GB.Say("Stopped after an error: " .. tostring(err))
    end
end
GB.OnUpdate = SafeUpdate

---------------------------------------------------------------------------
-- Turning things on and off
---------------------------------------------------------------------------
function GB.HasWork()
    local sv = GB.sv
    return sv ~= nil and sv.enabled == true
        and (sv.markerDistances or sv.groupDistances or sv.pointers or sv.memberBeams
            or GB.IsCrownTracked() or GB.IsCrownKeptOnTop()) == true
end

-- Call after any setting changes.
function GB.Refresh()
    if not GB.sv then return end
    GB.Compass.ApplySettings()
    GB.World.ApplySettings()
    local shouldRun = GB.HasWork()
    if shouldRun and not state.running then
        state.running = true
        state.rosterDirty = true
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 0, SafeUpdate)
    elseif not shouldRun and state.running then
        state.running = false
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    end
    if not shouldRun then
        preview = nil
        GB.Compass.HideAll()
        GB.World.HideAll()
    end
end

function GB.IsRunning()
    return state.running
end

function GB.SetEnabled(enabled)
    GB.sv.enabled = enabled
    GB.Refresh()
    GB.Say(enabled and "On." or "Off.")
end

---------------------------------------------------------------------------
-- Crown hint and status report (settings buttons and /groupbearings status)
---------------------------------------------------------------------------
-- Said when a crown option is turned on but there is no crown to show.
function GB.CrownHint()
    if not (GB.sv and (GB.IsCrownTracked() or GB.IsCrownKeptOnTop())) then return end
    RefreshRoster(GetFrameTimeMilliseconds())
    if not roster.grouped then
        GB.Say("Crown: you are not in a group yet. It shows once you join a group someone else leads.")
    elseif roster.playerLeads then
        GB.Say("Crown: you lead this group yourself, so there is no crown to show. It shows when someone else leads.")
    end
end

local function OnOff(value) return value and "on" or "off" end

function GB.PrintStatus()
    local sv = GB.sv
    if not sv then return end
    RefreshRoster(GetFrameTimeMilliseconds())
    local zoneId, px, py, pz = GetUnitRawWorldPosition("player")
    GB.Say(string.format("Version %s, %s. %s", GB.VERSION, sv.enabled and "on" or "off",
        roster.grouped and string.format("Group: %d other member(s) in range.", roster.count) or "Not in a group."))

    local crownLine = "Crown: none."
    if roster.grouped and roster.playerLeads then
        crownLine = "Crown: you lead the group, nothing to point to."
    elseif roster.grouped then
        crownLine = "Crown: the leader is not in range (another zone, instance, or offline)."
        for i = 1, roster.count do
            if roster.isLeader[i] then
                local z, tx, ty, tz = GetUnitRawWorldPosition(roster.tags[i])
                local name = GetUnitDisplayName and GetUnitDisplayName(roster.tags[i]) or roster.tags[i]
                if z == zoneId and HasPosition(tx, tz) then
                    crownLine = string.format("Crown: %s, %s away.", name or "leader",
                        Core.FormatDistance(Core.Distance3D(px, py, pz, tx, ty, tz)))
                end
            end
        end
    end
    GB.Say(crownLine)

    -- Every other group member and what the add-on sees for them.
    local size = GetGroupSize and GetGroupSize() or 0
    local instanced = size > 0 and InInstancedArea()
    local leaderTag = (size > 0 and GetGroupLeaderUnitTag) and GetGroupLeaderUnitTag() or ""
    for i = 1, size do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and not AreUnitsEqual(tag, "player") then
            local name = (GetUnitDisplayName and GetUnitDisplayName(tag)) or tag
            if name == "" then name = tag end
            local isLeader = IsUnitGroupLeader(tag) == true or (leaderTag ~= "" and AreUnitsEqual(tag, leaderTag))
            local line = SkipReason(tag, instanced)
            if not line then
                local z, tx, ty, tz = GetUnitRawWorldPosition(tag)
                if z ~= zoneId then
                    line = "another zone"
                elseif not HasPosition(tx, tz) then
                    line = "the game gives no position"
                else
                    line = Core.FormatDistance(Core.Distance3D(px, py, pz, tx, ty, tz)) .. " away"
                end
            end
            GB.Say(string.format("%s%s: %s.", name, isLeader and " (crown)" or "", line))
        end
    end

    local found = 0
    for i = 1, roster.count do
        local marker = roster.marker[i]
        if marker and marker ~= TARGET_MARKER_TYPE_NONE and GB.markers[marker] then
            local z, tx, ty, tz = GetUnitRawWorldPosition(roster.tags[i])
            if z == zoneId and HasPosition(tx, tz) then
                found = found + 1
                GB.Say(string.format("%s on a group member, %s away.", GB.GetSymbolName(marker),
                    Core.FormatDistance(Core.Distance3D(px, py, pz, tx, ty, tz))))
            end
        end
    end
    local now = GetFrameTimeMilliseconds()
    for marker, s in pairs(sightings) do
        found = found + 1
        GB.Say(string.format("%s (crosshair), %s away, seen %.1fs ago.", GB.GetSymbolName(marker),
            Core.FormatDistance(Core.Distance3D(px, py, pz, s.x, s.y, s.z)), (now - s.seenAt) / 1000))
    end
    if found == 0 then GB.Say("No tracked symbols right now.") end

    GB.Say(string.format("Compass distances %s, member distances %s, crown %s%s, crown kept over markers %s, arrows at feet %s, beam %s, member beams %s.",
        OnOff(sv.markerDistances), OnOff(sv.groupDistances), OnOff(GB.IsCrownTracked()),
        sv.crownOnTop and " (always on top)" or "", OnOff(GB.IsCrownKeptOnTop()),
        OnOff(sv.pointers and sv.pointerArrows), OnOff(sv.pointers and sv.beam), OnOff(sv.memberBeams)))
end

---------------------------------------------------------------------------
-- Slash commands (where typing in chat is available)
---------------------------------------------------------------------------
local function OnSlashCommand(args)
    local command = string.lower((string.gsub(args or "", "^%s*(.-)%s*$", "%1")))
    if command == "preview" or command == "test" then
        GB.StartPreview()
    elseif command == "status" then
        GB.PrintStatus()
    elseif command == "on" then
        GB.SetEnabled(true)
    elseif command == "off" then
        GB.SetEnabled(false)
    else
        GB.Say("/groupbearings preview | status | on | off. Settings: Settings > Add-Ons > Group Bearings.")
    end
end
GB.OnSlashCommand = OnSlashCommand

---------------------------------------------------------------------------
-- Load
---------------------------------------------------------------------------
local function Guarded(label, fn)
    local ok, err = pcall(fn)
    if not ok then
        GB.Say(label .. " failed to load: " .. tostring(err))
    end
    return ok
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= GB.ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(GB.ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- Account-wide: every character on the account shares these settings.
    GB.sv = ZO_SavedVars:NewAccountWide(GB.SAVED_VARIABLES, 1, nil, GB.DEFAULTS)
    -- Older versions saved colour names that no longer exist; fall back to defaults.
    local function KnownChoice(key, list)
        for _, name in ipairs(list) do if GB.sv[key] == name then return end end
        GB.sv[key] = GB.DEFAULTS[key]
    end
    KnownChoice("memberBeamColor", GB.MEMBER_BEAM_COLOR_CHOICES)
    -- Settings from test builds before 0.1.0 that no longer exist: overlap dots,
    -- tinted compass icons, and Group Bearings' own copy of the group pins (the
    -- game's pins now always show; member distances stay on only if they were).
    local saved = GB.sv
    if saved.groupOnCompass ~= nil then
        saved.groupDistances = (saved.groupOnCompass and saved.groupDistances) == true
    end
    saved.dotPreset, saved.dotColor, saved.groupOnCompass, saved.hideGamePins = nil, nil, nil, nil
    saved.memberColor, saved.memberCustomColor = nil, nil
    KnownChoice("crownColor", GB.CROWN_COLOR_CHOICES)
    BuildMarkerStyles()
    BuildRoleColors()

    SLASH_COMMANDS["/groupbearings"] = OnSlashCommand
    if SLASH_COMMANDS["/gb"] == nil then
        SLASH_COMMANDS["/gb"] = OnSlashCommand
    end

    Guarded("Compass", GB.Compass.Initialize)
    Guarded("Pointers", GB.World.Initialize)
    Guarded("Settings panel", GB.Settings.Initialize)

    local name = GB.ADDON_NAME
    for _, event in ipairs({
        EVENT_GROUP_UPDATE, EVENT_GROUP_MEMBER_JOINED, EVENT_GROUP_MEMBER_LEFT,
        EVENT_LEADER_UPDATE, EVENT_GROUP_MEMBER_CONNECTED_STATUS, EVENT_TARGET_MARKER_UPDATE,
        EVENT_ZONE_CHANGED,
    }) do
        EVENT_MANAGER:RegisterForEvent(name, event, MarkRosterDirty)
    end
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
        MarkRosterDirty()
        GB.ClearSightings() -- world positions are per zone
        GB.Refresh()
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        GB.Refresh()
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_INTERFACE_SETTING_CHANGED, function()
        GB.Compass.ApplySettings()
    end)

    GB.Refresh()
end

EVENT_MANAGER:RegisterForEvent(GB.ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
