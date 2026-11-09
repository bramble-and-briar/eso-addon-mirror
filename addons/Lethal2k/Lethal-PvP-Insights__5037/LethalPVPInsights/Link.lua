-- Lethal PVP Insights - build links in chat
-- Select a player in the LPI window and press "Link": a link like [LPI build: @Name] goes into the
-- chat input. Anyone with Lethal PVP Insights can click it to open that build (class, race, CP, role,
-- mundus, skill bars or skills seen, gear) in their LPI window. Same idea as SuperStar's build links:
-- a custom link type whose data is packed into a short string. The alphabet has no vowels, so chat's
-- profanity filter can't turn part of it into ***.
local PDI = PVPDataInsight
local Link = {}
PDI.Link = Link

Link.TYPE = "pdib"
local VERSION = 2            -- 2: + buffs
local MAX_BUFFS = 15
local LINK_COLOR = ZO_ColorDef and ZO_ColorDef:New("66CCFF") or nil   -- links stand out in chat
local ALPHA = "0123456789BCDFGHJKLMNPQRSTVWXYZbcdfghjklmnpqrstvwxyz(){}<>.!?+-/;~@&$^_="
local NA = #ALPHA
local CHUNK_BITS, CHUNK_CHARS = 49, 8           -- NA^8 > 2^49
local MAX_SKILLS = 12

-- lists the encounter log uses (index 0 = unknown / none)
local SLOTS = { "HEAD", "SHOULDERS", "CHEST", "HAND", "WAIST", "LEGS", "FEET", "NECK", "RING1", "RING2",
                "MAIN_HAND", "OFF_HAND", "BACKUP_MAIN", "BACKUP_OFF" }
local TRAITS = { "NONE",
    "ARMOR_STURDY", "ARMOR_IMPENETRABLE", "ARMOR_REINFORCED", "ARMOR_WELL_FITTED", "ARMOR_TRAINING",
    "ARMOR_INFUSED", "ARMOR_PROSPEROUS", "ARMOR_DIVINES", "ARMOR_NIRNHONED", "ARMOR_INTRICATE", "ARMOR_ORNATE",
    "WEAPON_POWERED", "WEAPON_CHARGED", "WEAPON_PRECISE", "WEAPON_INFUSED", "WEAPON_DEFENDING", "WEAPON_TRAINING",
    "WEAPON_SHARPENED", "WEAPON_DECISIVE", "WEAPON_NIRNHONED", "WEAPON_INTRICATE", "WEAPON_ORNATE",
    "JEWELRY_ARCANE", "JEWELRY_HEALTHY", "JEWELRY_ROBUST", "JEWELRY_TRIUNE", "JEWELRY_INFUSED",
    "JEWELRY_PROTECTIVE", "JEWELRY_SWIFT", "JEWELRY_HARMONY", "JEWELRY_BLOODTHIRSTY", "JEWELRY_INTRICATE",
    "JEWELRY_ORNATE" }
local ENCHANTS = { "INVALID",
    "HEALTH", "MAGICKA", "STAMINA", "HEALTH_REGEN", "MAGICKA_REGEN", "STAMINA_REGEN", "PRISMATIC_DEFENSE",
    "INCREASE_PHYSICAL_DAMAGE", "INCREASE_SPELL_DAMAGE", "REDUCE_SPELL_COST", "REDUCE_FEAT_COST", "DAMAGE_SHIELD",
    "REDUCE_POWER", "REDUCE_BLOCK_AND_BASH", "DISEASE_RESISTANT", "DECREASE_PHYSICAL_DAMAGE", "DECREASE_SPELL_DAMAGE",
    "ABSORB_HEALTH", "ABSORB_MAGICKA", "ABSORB_STAMINA", "BEFOULED_WEAPON", "BERSERKER", "CHARGED_WEAPON",
    "DAMAGE_HEALTH", "FIERY_WEAPON", "FROZEN_WEAPON", "POISONED_WEAPON", "PRISMATIC_ONSLAUGHT", "REDUCE_ARMOR",
    "FIRE_RESISTANT", "FROST_RESISTANT", "SHOCK_RESISTANT", "POISON_RESISTANT" }
local QUALITY = { "TRASH", "NORMAL", "MAGIC", "ARCANE", "ARTIFACT", "LEGENDARY" }

local function indexOf(list)
    local t = {}
    for i, v in ipairs(list) do t[v] = i end
    return t
end
local SLOT_IX, TRAIT_IX, ENCH_IX, Q_IX = indexOf(SLOTS), indexOf(TRAITS), indexOf(ENCHANTS), indexOf(QUALITY)

---------------------------------------------------------------------------
-- bit buffer <-> text
---------------------------------------------------------------------------
local function writer() return { bits = {} } end
local function put(w, value, width)
    value = math.floor(tonumber(value) or 0)
    local maxv = 2 ^ width - 1
    if value < 0 then value = 0 elseif value > maxv then value = maxv end
    for i = width - 1, 0, -1 do
        local b = math.floor(value / 2 ^ i) % 2
        w.bits[#w.bits + 1] = b
    end
end
local function encode(w)
    local bits = w.bits
    local out = {}
    for start = 1, #bits, CHUNK_BITS do
        local num = 0
        for i = start, start + CHUNK_BITS - 1 do num = num * 2 + (bits[i] or 0) end
        local chars = {}
        for _ = 1, CHUNK_CHARS do
            local r = num % NA
            table.insert(chars, 1, ALPHA:sub(r + 1, r + 1))
            num = math.floor(num / NA)
        end
        out[#out + 1] = table.concat(chars)
    end
    return table.concat(out)
end
local function reader(text)
    local bits = {}
    for start = 1, #text, CHUNK_CHARS do
        local num = 0
        for i = start, start + CHUNK_CHARS - 1 do
            local ch = text:sub(i, i)
            local v = ch ~= "" and ALPHA:find(ch, 1, true)
            if not v then return nil end            -- damaged in chat
            num = num * NA + (v - 1)
        end
        local chunk = {}
        for i = CHUNK_BITS, 1, -1 do
            chunk[i] = num % 2
            num = math.floor(num / 2)
        end
        for i = 1, CHUNK_BITS do bits[#bits + 1] = chunk[i] end
    end
    return { bits = bits, pos = 1 }
end
local function get(r, width)
    local v = 0
    for _ = 1, width do
        v = v * 2 + (r.bits[r.pos] or 0)
        r.pos = r.pos + 1
    end
    return v
end

---------------------------------------------------------------------------
-- build <-> data
-- b = { cls, race, cp, role, mundus = {ids}, bar1 = {ids}, bar2 = {ids}, skills = {ids}, gear = {entries} }
---------------------------------------------------------------------------
local function packBuild(b)
    local w = writer()
    put(w, VERSION, 4)
    put(w, b.cls, 7); put(w, b.race, 4); put(w, b.cp, 12); put(w, b.role, 3)
    local m = b.mundus or {}
    put(w, m[1], 19); put(w, m[2], 19)
    for _, bar in ipairs({ b.bar1 or {}, b.bar2 or {} }) do
        put(w, math.min(#bar, 6), 3)
        for i = 1, math.min(#bar, 6) do put(w, bar[i], 19) end
    end
    local sk = b.skills or {}
    put(w, math.min(#sk, MAX_SKILLS), 4)
    for i = 1, math.min(#sk, MAX_SKILLS) do put(w, sk[i], 19) end
    local bf = b.buffs or {}
    put(w, math.min(#bf, MAX_BUFFS), 4)
    for i = 1, math.min(#bf, MAX_BUFFS) do put(w, bf[i].id, 19); put(w, bf[i].perm and 1 or 0, 1) end
    local bySlot = {}
    for _, g in ipairs(b.gear or {}) do if SLOT_IX[g.slot] then bySlot[SLOT_IX[g.slot]] = g end end
    for i = 1, #SLOTS do put(w, bySlot[i] and 1 or 0, 1) end
    for i = 1, #SLOTS do
        local g = bySlot[i]
        if g then
            put(w, g.item, 19); put(w, g.set, 12)
            put(w, TRAIT_IX[g.trait] or 0, 6); put(w, ENCH_IX[g.ench] or 0, 6); put(w, Q_IX[g.q] or 0, 3)
            put(w, g.lvl, 6); put(w, g.cp and 1 or 0, 1)
        end
    end
    return encode(w)
end

local function unpackBuild(data)
    local r = reader(data or "")
    if not r then return nil end
    local ver = get(r, 4)
    if ver < 1 or ver > VERSION then return nil end
    local b = { cls = get(r, 7), race = get(r, 4), cp = get(r, 12), role = get(r, 3), mundus = {} }
    for _ = 1, 2 do local m = get(r, 19); if m > 0 then b.mundus[#b.mundus + 1] = m end end
    b.bar1, b.bar2 = {}, {}
    for _, bar in ipairs({ b.bar1, b.bar2 }) do
        for _ = 1, get(r, 3) do bar[#bar + 1] = get(r, 19) end
    end
    b.skills = {}
    for _ = 1, get(r, 4) do b.skills[#b.skills + 1] = get(r, 19) end
    b.buffs = {}
    if ver >= 2 then
        for _ = 1, get(r, 4) do b.buffs[#b.buffs + 1] = { id = get(r, 19), perm = get(r, 1) == 1 } end
    end
    local has = {}
    for i = 1, #SLOTS do has[i] = get(r, 1) == 1 end
    b.gear = {}
    for i = 1, #SLOTS do
        if has[i] then
            local g = { slot = SLOTS[i], item = get(r, 19), set = get(r, 12) }
            g.trait = TRAITS[get(r, 6)] or "NONE"
            g.ench = ENCHANTS[get(r, 6)] or "INVALID"
            g.q = QUALITY[get(r, 3)] or "NORMAL"
            g.lvl = get(r, 6)
            g.cp = get(r, 1) == 1
            b.gear[#b.gear + 1] = g
        end
    end
    return b
end

---------------------------------------------------------------------------
-- From the LPI window's selection
---------------------------------------------------------------------------
local MUNDUS_BY_NAME
local function mundusIds(rec, snap)
    if not MUNDUS_BY_NAME then
        MUNDUS_BY_NAME = {}
        for id, n in pairs(PDI.MUNDUS_IDS or {}) do MUNDUS_BY_NAME[n] = MUNDUS_BY_NAME[n] or id end
    end
    local out = {}
    for _, id in ipairs(snap and snap.v and snap.v.effects or {}) do
        if PDI.MUNDUS_IDS[id] then out[#out + 1] = id end
    end
    if #out == 0 then
        for n in pairs(rec.mundus or {}) do if MUNDUS_BY_NAME[n] then out[#out + 1] = MUNDUS_BY_NAME[n] end end
    end
    return out
end

function Link:FromSelection(sel, snap)
    if not sel then return nil end
    local rec = sel.rec or {}
    local v = snap and snap.v or {}
    local b = {
        cls = rec.cls or (snap and snap.cls), race = (type(rec.race) == "number" and rec.race) or (snap and snap.race),
        cp = rec.cp or (snap and snap.cp), role = rec.role, mundus = mundusIds(rec, snap),
        bar1 = v.bar1, bar2 = v.bar2, gear = v.gear, skills = {},
    }
    if not (b.bar1 and #b.bar1 > 0) then
        -- no captured bars: the skills seen (an enemy's hits), most used first
        local list = {}
        for _, sk in pairs(rec.skills or {}) do
            if sk.id and sk.id > 0 and PDI.Skills:Classify(sk) ~= "hidden" then list[#list + 1] = sk end
        end
        table.sort(list, function(a, c) return (a.h or 0) > (c.h or 0) end)
        for i = 1, math.min(#list, MAX_SKILLS) do b.skills[i] = list[i].id end
    end
    -- buffs seen on them (targeted players, group members): what the details show, most telling first
    local buffs, seen = {}, {}
    for name, bf in pairs(rec.buffs or {}) do
        local id = type(bf) == "table" and bf.id or bf
        local perm = type(bf) == "table" and bf.perm or nil
        if type(id) == "number" and id > 0 then
            local cat, shown = PDI.Skills:ClassifyBuff(name, id, perm)
            if cat ~= "hidden" and not seen[shown] then
                seen[shown] = true
                buffs[#buffs + 1] = { id = id, perm = perm, o = PDI.Skills.ORDER[cat] or 50, n = shown }
            end
        end
    end
    table.sort(buffs, function(a, c) if a.o ~= c.o then return a.o < c.o end return a.n < c.n end)
    b.buffs = {}
    for i = 1, math.min(#buffs, MAX_BUFFS) do b.buffs[i] = buffs[i] end
    return b
end

function Link:Create(who, b)
    local name = string.format("LPI build: %s", who or "?")
    -- sent without a colour (chat doesn't allow colour codes); everyone with LPI shows it coloured
    return ZO_LinkHandler_CreateLink(name, nil, self.TYPE, packBuild(b))
end

-- "Link" button: put the selected build into the chat input
function Link:InsertSelected()
    local UI = PDI.UI
    local s = UI and UI.sel
    if not s then PDI.Msg("Select a player first.") return end
    local b = self:FromSelection(s, UI:SelectedLog())
    if not b then return end
    local link = self:Create(s.who, b)
    if CHAT_SYSTEM and CHAT_SYSTEM.textEntry then
        if CHAT_SYSTEM.Maximize and CHAT_SYSTEM.IsMinimized and CHAT_SYSTEM:IsMinimized() then CHAT_SYSTEM:Maximize() end
        StartChatInput("")
        CHAT_SYSTEM.textEntry:InsertLink(link)
    end
end

---------------------------------------------------------------------------
-- Opening a link
---------------------------------------------------------------------------
local function whoFromText(text)
    local who = text and text:match("[LP][PD]I build: ([^%]|]+)")   -- LPI, and PDI from older versions
    return who and zo_strtrim(who) or "?"
end

function Link:Open(data, text, from)
    local b = unpackBuild(data)
    if not b then
        PDI.Msg("This build link is damaged (chat changed part of it) or from a newer Lethal PVP Insights.")
        return
    end
    b.who = whoFromText(text)
    b.from = from
    PDI.UI:ShowLinked(b)
end

local lastOpen = 0
local function onLink(link, button, text, linkStyle, linkType, data)
    if linkType ~= Link.TYPE then return end
    if button == MOUSE_BUTTON_INDEX_LEFT and GetFrameTimeMilliseconds() - lastOpen > 300 then
        lastOpen = GetFrameTimeMilliseconds()      -- both link events fire for one click
        Link:Open(data, text)
    end
    return true
end

---------------------------------------------------------------------------
-- Chat: let the link through (custom link types are dropped/escaped otherwise)
---------------------------------------------------------------------------
function Link:Init()
    if ZO_VALID_LINK_TYPES_CHAT then ZO_VALID_LINK_TYPES_CHAT[self.TYPE] = true end
    local lcm = LibChatMessage
    if lcm and lcm.RegisterCustomChatLink then
        lcm:RegisterCustomChatLink(self.TYPE, function(linkStyle, linkType, data, displayText)
            return ZO_LinkHandler_CreateLinkWithoutBrackets(displayText, LINK_COLOR, linkType, data)
        end)
    else
        -- without LibChatMessage the chat shows the link escaped: repeat it as a clickable line
        EVENT_MANAGER:RegisterForEvent(PDI.name .. "Link", EVENT_CHAT_MESSAGE_CHANNEL,
            function(_, _, _, text, _, fromDisplayName)
                if type(text) ~= "string" then return end
                local data, shown = text:match("|+H%d:" .. Link.TYPE .. ":([^|]+)|+h([^|]*)|+h")
                if data and CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
                    local name = shown:gsub("^%[", ""):gsub("%]$", "")
                    CHAT_ROUTER:AddSystemMessage(string.format("%s linked %s", fromDisplayName or "?",
                        ZO_LinkHandler_CreateLink(name, LINK_COLOR, Link.TYPE, data)))
                end
            end)
    end
    if LINK_HANDLER then
        LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_MOUSE_UP_EVENT, onLink)
        LINK_HANDLER:RegisterCallback(LINK_HANDLER.LINK_CLICKED_EVENT, onLink)
    end
end

-- for tests
Link._pack, Link._unpack = packBuild, unpackBuild
