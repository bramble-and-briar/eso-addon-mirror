-- Questbound_Beacon.lua : markers standing in the 3D world at the objective.
--  * Talk to someone (or hand in): a Skyrim-style quest marker (dark triangle,
--    gold rim) hovers above them, with a soft golden ring of light at their feet
--    (like Lord of the Rings Online). The quest's map pin sits on the NPC, so
--    that's where they go; the height comes from the ground you've walked there.
--  * Kill monsters: the hunting area glows faint red on the ground (like ESO's
--    own map) with crossed swords floating over its middle.
--  * Anything else: a soft pillar of light, visible from far away.
-- Standing markers are two crossed planes, so they look right from any side.

local W = Questbound
local Beacon = {}
W.Beacon = Beacon

local NPC_RANGE_M = 80      -- NPC marker and ring show within this distance
local HEAD_M = 2.6          -- marker height above the ground: just over a normal person's head
                            -- (floating ghosts are reported on the floor, so they get it at chest height)
local DOOR_TOP_M = 6.0    -- "next area" marker: above a doorway (big city doors are ~4.5 m)
local KILL_RANGE_M = 150    -- hunting area shows within this distance
local PILLAR_MIN_M = 60     -- map markers / other spots: light pillar from here on (fading in)...
local NEAR_END_M = 85       -- ...fully shown from here; closer, the marker + ring fade in instead
local SPOT_M = 2.2          -- marker height over a map marker / spot (no one standing there)
local UNKNOWN_NEAR_M = 18   -- ground there unknown: your own height is trusted this close...
local UNKNOWN_SLOPE = 0.1   -- ...further away the marker floats 10 cm higher per meter...
local UNKNOWN_MAX_LIFT_M = 6 -- ...up to this much
local PILLAR_HEIGHT_M = 45
-- Open world "talk to" NPCs: the game gives addons no NPC position there, only the quest's
-- spot a few meters beside them (marker looked off, user's screenshots). So from afar our
-- marker + ring guide you, and up close they fade out and the game's own white diamond
-- (exactly over the NPC) takes over; also at once when your crosshair is on that NPC.
-- Exact positions (t.npcSnap, instances) and dungeons keep the marker.
local HANDOFF_FAR_M = 28    -- fully shown from here...
local HANDOFF_NEAR_M = 18   -- ...gone from here on
local handoff = 1           -- current fade (eased)
local RED = { r = 0.88, g = 0.38, b = 0.24 }

local win
local npc = {}       -- marker: two crossed planes
local ring = {}      -- golden ring: soft wide glow + crisp ring (flat)
local area = {}      -- hunting area: soft red disc + rim (flat)
local swords = {}    -- two crossed planes
local pillar = {}    -- two crossed planes
local supported = type(WorldPositionToGuiRender3DPosition) == "function"

local function Tex(file, pitch, yaw)
    local tex = WINDOW_MANAGER:CreateControl(nil, win, CT_TEXTURE)
    tex:SetTexture(W.TEX .. file)
    tex:Create3DRenderSpace()
    tex:Set3DRenderSpaceOrientation(pitch, yaw, 0)
    tex:Set3DRenderSpaceUsesDepthBuffer(false)   -- seen through walls and hills
    tex:SetHidden(true)
    return tex
end
local function Standing(file, yaw) return Tex(file, 0, yaw) end
local function Flat(file) return Tex(file, math.pi / 2, 0) end

local function Hide(list)
    for _, tex in ipairs(list) do tex:SetHidden(true) end
end

-- world position in cm, size in m
local function Place(list, x, y, z, w, h, r, g, b, a)
    local rx, ry, rz = WorldPositionToGuiRender3DPosition(x, y, z)
    for _, tex in ipairs(list) do
        tex:Set3DRenderSpaceOrigin(rx, ry, rz)
        tex:Set3DLocalDimensions(w, h)
        tex:SetColor(r, g, b, a)
        tex:SetHidden(false)
    end
end

function Beacon.Init()
    if not supported then return end
    win = WINDOW_MANAGER:CreateTopLevelWindow("Questbound_Beacon")
    win:SetAnchorFill(GuiRoot)
    win:SetMouseEnabled(false)
    win:SetDrawLayer(DL_BACKGROUND)
    win:SetDrawTier(DT_LOW)
    W.HudFragment(win)
    npc[1] = Standing("marker_tes.dds", 0)
    npc[2] = Standing("marker_tes.dds", math.pi / 2)
    ring[1] = Flat("dot.dds")     -- glow
    ring[2] = Flat("ring.dds")    -- ring
    area[1] = Flat("dot.dds")     -- red haze
    area[2] = Flat("ring.dds")    -- rim
    swords[1] = Standing("swords.dds", 0)
    swords[2] = Standing("swords.dds", math.pi / 2)
    pillar[1] = Standing("beam.dds", 0)
    pillar[2] = Standing("beam.dds", math.pi / 2)
end

-- Is the crosshair on the person this objective names? ("Talk to Nellic Sterone")
local function CrosshairOn(t)
    if not DoesUnitExist("reticleover") then return false end
    local name = zo_strlower(zo_strformat("<<1>>", GetUnitName("reticleover") or ""))
    local want = zo_strlower(zo_strformat("<<1>>", t.text or ""))
    for w in name:gmatch("[^%s%-]+") do
        if #w >= 3 and want:find(w, 1, true) then return true end
    end
    return false
end

-- "Talk to ..." / "Speak with ..." (en / de / fr), for objectives the game doesn't flag as talk
local TALK_WORDS = { "talk", "speak", "sprich", "rede", "parle" }
local function SaysTalk(text)
    local s = " " .. zo_strlower(zo_strformat("<<1>>", text or ""))
    for _, w in ipairs(TALK_WORDS) do
        if s:find(" " .. w, 1, true) then return true end
    end
    return false
end

-- 1 = our NPC marker fully shown, 0 = handed over to the game's own diamond.
-- (1st try relied on t.talk and skipped t.npcSnap: in-game it never faded at 7 m with the
-- crosshair on the NPC. Now any objective that is about a person fades in the open world,
-- also with a saved spot: if that spot is exact the game's diamond is right there anyway.)
Beacon.handoffInfo = "none yet"
local function HandoffTarget(t, dist)
    if t.other or t.kill then return 1 end
    local dungeon = IsUnitInDungeon("player")
    local cross = CrosshairOn(t)
    local person = t.talk or t.npcSnap or cross or SaysTalk(t.text)
    local want = 1
    if person and not dungeon then
        want = cross and 0 or zo_clamp((dist - HANDOFF_NEAR_M) / (HANDOFF_FAR_M - HANDOFF_NEAR_M), 0, 1)
    end
    Beacon.handoffInfo = string.format("shown %d%%  (person %s, crosshair on them %s, in a dungeon %s, %.0f m)",
        zo_round(want * 100), tostring(person and true or false), tostring(cross), tostring(dungeon), dist)
    return want
end

function Beacon.Update(nav, dt, now)
    if not win then return end
    local t = nav.target
    if not (nav.valid and t and nav.cal and not win:IsHidden()) then
        Hide(npc) Hide(ring) Hide(area) Hide(swords) Hide(pillar)
        return
    end
    local anim = W.sv.anim
    local moving = anim ~= "off"
    local gold = W.COLOR.theme
    local tx, tz = W.Nav.MapToWorld(t.x, t.y)
    -- ground at the objective (cm): on another floor (compass says above / below)
    -- that floor's height; else the learned height there; else your own
    local ground = t.npcY   -- the NPC's own height, when seen under the crosshair
        or W.Nav.TargetFloorHeight(tx, tz)
    local walked = W.Roads.HeightAt(tx / 100, tz / 100, 6, (nav.groundY or nav.wy) / 100)
    local known = ground ~= nil or walked ~= nil or (t.door ~= nil)
    ground = ground or (walked or ((nav.groundY or nav.wy) / 100)) * 100
    local dist = nav.dist or 0
    -- ground height there unknown (never walked; the game gives no terrain): your own
    -- height is used, fine close by, but further away the ground may rise and the
    -- marker would sink into it. So it floats a bit higher the further it is, and
    -- the ring on the ground only fades in when you're close.
    local lift, ringA = 0, 1
    if not known then
        lift = zo_clamp((dist - UNKNOWN_NEAR_M) * UNKNOWN_SLOPE, 0, UNKNOWN_MAX_LIFT_M)
        ringA = zo_clamp((UNKNOWN_NEAR_M + 8 - dist) / 8, 0, 1)
    end

    -- S1 + L1: someone to talk to, the "next area" spot (a ship captain, a carriage
    -- driver, a door) that takes you onward, and close by also map markers and other
    -- objectives (far away those get the light pillar; the two cross-fade)
    local generic = not (t.talk or t.other or t.kill)
    -- (without the pillar, the marker shows at any distance)
    local near = (generic and W.sv.path.pillar) and zo_clamp((NEAR_END_M - dist) / (NEAR_END_M - PILLAR_MIN_M), 0, 1) or 1
    -- open world talk NPC up close: hand over to the game's own diamond (eased, ~0.3 s)
    local want = HandoffTarget(t, dist)
    if moving and dt then
        handoff = handoff + (want - handoff) * math.min(1, dt * 8)
        if math.abs(want - handoff) < 0.01 then handoff = want end
    else
        handoff = want
    end
    near = near * handoff
    local showNpc = W.sv.npcMarker and not t.kill and (generic or dist <= NPC_RANGE_M) and near > 0
        and W.TextureLoaded("marker_tes.dds")
    if showNpc then
        local bob = (anim == "full") and math.sin(now * 2.2) * 0.12 or 0
        local size = 0.55 * (1 + zo_clamp((dist - 15) / 60, 0, 1) * 1.3)   -- a bit bigger far away
        if t.other then
            -- "next area": above the doorway. A learned door has its exact spot and
            -- threshold height; the game's own spot is only near the door (often
            -- on steps), so no ring on the ground there, just the marker up high
            local base = t.door and t.door.wy
            if not base then
                -- not gone through yet: the top of the steps there, not their middle
                local top = W.Roads.TopAt(tx / 100, tz / 100, 5, ground / 100, 3)
                base = top and top * 100 or ground
            end
            Place(npc, tx, base + (DOOR_TOP_M + bob) * 100, tz, size, size, 1, 1, 1, 1)
            Hide(ring)
        else
            -- ring at the NPC's own feet (their position from the crosshair), marker over
            -- their head. (No floor guessing: a ring even a little under the ground looks
            -- shifted toward you. Floating NPCs are reported on the floor anyway.)
            local head, floorY = ground, ground
            -- map markers / other spots: nobody standing there, so the marker hangs lower
            local markH = generic and SPOT_M or HEAD_M
            Place(npc, tx, head + (markH + lift + bob) * 100, tz, size, size, 1, 1, 1, near)
            if ringA > 0 then
                local glow = moving and (0.35 + 0.2 * math.sin(now * 2)) or 0.4
                Place({ ring[1] }, tx, floorY + 5, tz, 2.6, 2.6, gold.r, gold.g, gold.b, glow * near * ringA)
                Place({ ring[2] }, tx, floorY + 5, tz, 1.5, 1.5, gold.r, gold.g, gold.b, 0.9 * near * ringA)
            else
                Hide(ring)
            end
        end
    else
        Hide(npc)
        Hide(ring)
    end

    -- M1: monsters to kill
    local showKill = W.sv.killArea and t.kill and dist <= KILL_RANGE_M
    if showKill then
        local radius = zo_clamp(nav.radiusM > 0 and nav.radiusM or 12, 6, 60)
        local haze = moving and (0.16 + 0.06 * math.sin(now * 1.6)) or 0.18
        Place({ area[1] }, tx, ground + 5, tz, radius * 2.4, radius * 2.4, RED.r, RED.g, RED.b, haze)
        Place({ area[2] }, tx, ground + 5, tz, radius * 2, radius * 2, RED.r, RED.g, RED.b, 0.55)
        if W.TextureLoaded("swords.dds") then
            local bob = (anim == "full") and math.sin(now * 2) * 0.15 or 0
            Place(swords, tx, ground + (4 + bob) * 100, tz, 1.1, 1.1, RED.r, RED.g, RED.b, 0.95)
        else
            Hide(swords)
        end
    else
        Hide(area)
        Hide(swords)
    end

    -- light pillar on other objectives
    -- (only far away: close up it's a flat stripe; there the marker and ring take over)
    if W.sv.path.pillar and generic and dist >= PILLAR_MIN_M and not nav.arrived
        and W.TextureLoaded("beam.dds") then
        local a = moving and (0.45 + 0.2 * math.sin(now * 2.2)) or 0.5
        a = a * zo_clamp((dist - PILLAR_MIN_M) / (NEAR_END_M - PILLAR_MIN_M), 0, 1)   -- fades in as you move away
        Place(pillar, tx, ground + (PILLAR_HEIGHT_M / 2 - 5) * 100, tz, 1.4, PILLAR_HEIGHT_M, gold.r, gold.g, gold.b, a)
    else
        Hide(pillar)
    end
end
