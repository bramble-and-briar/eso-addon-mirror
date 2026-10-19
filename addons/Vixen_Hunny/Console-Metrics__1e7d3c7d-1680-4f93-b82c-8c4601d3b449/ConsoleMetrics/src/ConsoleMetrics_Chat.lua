-- ConsoleMetrics_Chat.lua  (xb1cert edition)
-- All chat sharing for ConsoleMetrics.
-- Skills and gear are sent as real ESO |H...|h link tokens so recipients
-- can click them for full tooltips, just like a regular chat link.

---------------------------------------------------------------------------
-- Link helpers
---------------------------------------------------------------------------

-- Returns a clickable |Hability:id|h[Name]|h link, or "[Name]" fallback.
local function GetAbilityLinkSafe(abilityId, fallbackName)
    if type(abilityId) == "number" and abilityId > 0 then
        if type(GetAbilityLink) == "function" then
            local style = type(LINK_STYLE_DEFAULT) == "number" and LINK_STYLE_DEFAULT or 1
            local ok, link = pcall(GetAbilityLink, abilityId, style)
            if ok and type(link) == "string" and link ~= "" then
                return link
            end
        end
        if type(fallbackName) == "string" and fallbackName ~= "" then
            return "[" .. fallbackName .. "]"
        end
        return string.format("[ability:%d]", abilityId)
    end
    return type(fallbackName) == "string" and ("[" .. fallbackName .. "]") or "[?]"
end

-- Returns the full |Hitem:...|h[Name]|h link for a worn slot, or nil if empty.
local function GetWornItemLinkSafe(equipSlotConstant)
    if type(BAG_WORN) ~= "number" or type(equipSlotConstant) ~= "number" then return nil end
    if type(GetItemLink) ~= "function" then return nil end
    local style = type(LINK_STYLE_DEFAULT) == "number" and LINK_STYLE_DEFAULT or 1
    local ok, link = pcall(GetItemLink, BAG_WORN, equipSlotConstant, style)
    if not ok then return nil end
    if type(link) ~= "string" or link == "" then return nil end
    if link == "|H0:item:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" then return nil end
    return link
end

-- Packs link strings into the fewest chat-safe chunks (<=maxLen chars each).
local function PackLinksIntoChunks(links, prefix, maxLen)
    maxLen = maxLen or 340
    local chunks, current, currentLen = {}, {}, 0
    for i = 1, #links do
        local piece = links[i]
        local sep = currentLen > 0 and " " or ""
        if currentLen + #sep + #piece > maxLen and currentLen > 0 then
            chunks[#chunks + 1] = table.concat(current, " ")
            current, currentLen = { piece }, #piece
        else
            current[#current + 1] = piece
            currentLen = currentLen + #sep + #piece
        end
    end
    if #current > 0 then chunks[#chunks + 1] = table.concat(current, " ") end
    if #chunks == 0 then return { prefix .. ": (empty)" } end
    local result = {}
    for i = 1, #chunks do
        local lbl = #chunks == 1 and prefix or string.format("%s (%d/%d)", prefix, i, #chunks)
        result[i] = lbl .. ": " .. chunks[i]
    end
    return result
end

---------------------------------------------------------------------------
-- LMB (Link My Build) integration
-- Calls LMB's global functions when the addon is present, with graceful
-- fallback to our own link builders when it is not.
---------------------------------------------------------------------------

local function LMBAvailable()
    return type(LinkMyBars) == "function"
end

function ConsoleMetrics:LinkBuildSkillsLMB()
    if LMBAvailable() then
        LinkMyBars()
        self:Print("LMB: bars pre-filled in chat.")
    else
        self:ShareFrontBarLinksToChat()
        self:ShareBackBarLinksToChat()
        self:Print("LMB not found — used built-in bar links.")
    end
end

function ConsoleMetrics:LinkChampAndMiscLMB()
    if LMBAvailable() and type(LinkMyChampandmisc) == "function" then
        LinkMyChampandmisc()
        self:Print("LMB: CP + misc pre-filled in chat.")
    else
        self:Print("LMB not found — install LMB or use /lmc to link CP.")
    end
end

function ConsoleMetrics:LinkGearSetsLMB()
    if LMBAvailable() and type(LinkMySets) == "function" then
        LinkMySets()
        self:Print("LMB: gear sets pre-filled in chat.")
    else
        self:ShareAllGearLinksToChat()
        self:Print("LMB not found — used built-in gear links.")
    end
end

---------------------------------------------------------------------------
-- Low-level send
---------------------------------------------------------------------------

-- Sends chunk[1] via the keyboard; remaining chunks are printed to own chat.
function ConsoleMetrics:SendChunks(chunks)
    if not chunks or #chunks == 0 then return end
    self:SendToChat(chunks[1])
    if #chunks > 1 then
        self:Print(string.format("(%d more part(s) printed below)", #chunks - 1))
        for i = 2, #chunks do self:Print(chunks[i]) end
    end
end

---------------------------------------------------------------------------
-- Action-bar ability links
---------------------------------------------------------------------------

-- Raw link list for one action bar (no chunking, no label).
local function BuildBarLinksRaw(hotbarCategory)
    local firstSlot, ultimateSlot = GetActionBarSlotBounds()
    local links = {}
    for slotIndex = firstSlot, ultimateSlot do
        local abilityName, abilityId = SafeGetActionBarSlotName(slotIndex, hotbarCategory)
        if abilityName then
            links[#links + 1] = GetAbilityLinkSafe(abilityId, abilityName)
        end
    end
    return links
end

function ConsoleMetrics:BuildBarLinkChunks(hotbarCategory, label)
    return PackLinksIntoChunks(BuildBarLinksRaw(hotbarCategory), "[CM " .. label .. "]")
end

function ConsoleMetrics:ShareFrontBarLinksToChat()
    local cat = type(HOTBAR_CATEGORY_PRIMARY) == "number" and HOTBAR_CATEGORY_PRIMARY or nil
    self:SendChunks(self:BuildBarLinkChunks(cat, "Front Bar"))
end

function ConsoleMetrics:ShareBackBarLinksToChat()
    local cat = type(HOTBAR_CATEGORY_BACKUP) == "number" and HOTBAR_CATEGORY_BACKUP or nil
    self:SendChunks(self:BuildBarLinkChunks(cat, "Back Bar"))
end

---------------------------------------------------------------------------
-- Gear item links grouped by slot category
---------------------------------------------------------------------------

local ARMOR_SLOTS   = { "EQUIP_SLOT_HEAD","EQUIP_SLOT_CHEST","EQUIP_SLOT_LEGS","EQUIP_SLOT_FEET",
                         "EQUIP_SLOT_SHOULDERS","EQUIP_SLOT_HAND","EQUIP_SLOT_WAIST" }
local JEWELRY_SLOTS = { "EQUIP_SLOT_NECK","EQUIP_SLOT_RING1","EQUIP_SLOT_RING2" }
local WEAPON_SLOTS  = { "EQUIP_SLOT_MAIN_HAND","EQUIP_SLOT_OFF_HAND",
                         "EQUIP_SLOT_BACKUP_MAIN","EQUIP_SLOT_BACKUP_OFF" }

-- Raw item link list for a slot group (no chunking, no label).
local function BuildGearLinksRaw(constNames)
    local links = {}
    for i = 1, #constNames do
        local link = GetWornItemLinkSafe(_G[constNames[i]])
        if link then links[#links + 1] = link end
    end
    return links
end

local function GearChunks(constNames, label)
    return PackLinksIntoChunks(BuildGearLinksRaw(constNames), "[CM " .. label .. "]")
end

function ConsoleMetrics:ShareArmorLinksToChat()   self:SendChunks(GearChunks(ARMOR_SLOTS,   "Armor"))   end
function ConsoleMetrics:ShareJewelryLinksToChat() self:SendChunks(GearChunks(JEWELRY_SLOTS, "Jewelry")) end
function ConsoleMetrics:ShareWeaponLinksToChat()  self:SendChunks(GearChunks(WEAPON_SLOTS,  "Weapons")) end

function ConsoleMetrics:ShareAllGearLinksToChat()
    local all = {}
    for _, c in ipairs(GearChunks(ARMOR_SLOTS,   "Armor"))   do all[#all + 1] = c end
    for _, c in ipairs(GearChunks(JEWELRY_SLOTS, "Jewelry")) do all[#all + 1] = c end
    for _, c in ipairs(GearChunks(WEAPON_SLOTS,  "Weapons")) do all[#all + 1] = c end
    self:SendChunks(all)
end

---------------------------------------------------------------------------
-- CP Slottables — shared link-list builder (used by both share functions)
---------------------------------------------------------------------------

local function BuildCPSlottableLinkList()
    local champ = BuildChampionSnapshot()
    local bracketStyle = type(LINK_STYLE_BRACKETS) == "number" and LINK_STYLE_BRACKETS or 1
    local links = {}

    local function TryGetCPLink(skillId, fallbackName)
        if type(skillId) == "number" and skillId > 0 then
            local abilityId = nil
            if type(GetChampionSkillLinkIds) == "function" then
                local ok, id = pcall(GetChampionSkillLinkIds, skillId)
                if ok and type(id) == "number" and id > 0 then abilityId = id end
            end
            if not abilityId then
                for _, fnName in ipairs({ "GetChampionSkillAbilityId", "GetChampionSkillProgressionAbilityId" }) do
                    local fn = _G and _G[fnName]
                    if type(fn) == "function" then
                        local ok, id = pcall(fn, skillId)
                        if ok and type(id) == "number" and id > 0 then abilityId = id ; break end
                    end
                end
            end
            local idToLink = abilityId or skillId
            if type(GetAbilityLink) == "function" then
                local ok, link = pcall(GetAbilityLink, idToLink, bracketStyle)
                if ok and type(link) == "string" and link ~= "" then return link end
            end
        end
        return "[" .. (fallbackName or "?") .. "]"
    end

    for _, bucket in ipairs({ champ.warfare, champ.fitness, champ.craft }) do
        for _, entry in ipairs(bucket or {}) do
            for _, star in ipairs(entry.slottedStars or {}) do
                links[#links + 1] = TryGetCPLink(star.skillId, star.name)
            end
        end
    end
    return links
end

---------------------------------------------------------------------------
-- CP Slottables — send to chat
---------------------------------------------------------------------------

function ConsoleMetrics:ShareCPSlottablesToChat()
    local links = BuildCPSlottableLinkList()
    if #links == 0 then
        self:Print("No CP slottables detected. Open the Champion Point screen first so the data is loaded.")
        return
    end
    self:SendChunks(PackLinksIntoChunks(links, "[CM CP Slottables]"))
end

---------------------------------------------------------------------------
-- Full linked build — ability links + item links + CP links in one send
---------------------------------------------------------------------------

function ConsoleMetrics:ShareFullBuildLinked()
    local fCat = type(HOTBAR_CATEGORY_PRIMARY) == "number" and HOTBAR_CATEGORY_PRIMARY or nil
    local bCat = type(HOTBAR_CATEGORY_BACKUP)  == "number" and HOTBAR_CATEGORY_BACKUP  or nil

    -- Chunk each section separately so no |H...|h link token is ever cut mid-string.
    local chunks = {}
    local function AddSection(label, links)
        if #links == 0 then return end
        for _, chunk in ipairs(PackLinksIntoChunks(links, "[CM " .. label .. "]")) do
            chunks[#chunks + 1] = chunk
        end
    end

    AddSection("Front Bar", BuildBarLinksRaw(fCat))
    AddSection("Back Bar",  BuildBarLinksRaw(bCat))
    AddSection("Armor",     BuildGearLinksRaw(ARMOR_SLOTS))
    AddSection("Jewelry",   BuildGearLinksRaw(JEWELRY_SLOTS))
    AddSection("Weapons",   BuildGearLinksRaw(WEAPON_SLOTS))
    AddSection("CP",        BuildCPSlottableLinkList())

    if #chunks == 0 then
        self:Print("No build data found to share.")
        return
    end

    -- First chunk is pre-filled in the chat entry; the rest are printed to the local log.
    self:SendChunks(chunks)
end

---------------------------------------------------------------------------
-- Low-level send
---------------------------------------------------------------------------

-- SendToChat: tries to pre-fill the virtual keyboard / chat entry box.
-- Falls back to d() (system print) if CHAT_SYSTEM is unavailable.
function ConsoleMetrics:SendToChat(text)
    if type(text) ~= "string" or text == "" then return end

    -- Trim to a safe chat-line length
    if #text > 380 then
        text = string.sub(text, 1, 377) .. "..."
    end

    -- Console / gamepad: CHAT_SYSTEM.StartTextEntry opens the virtual keyboard
    -- pre-populated with text so the player can pick a channel and confirm.
    if type(CHAT_SYSTEM) == "table" and type(CHAT_SYSTEM.StartTextEntry) == "function" then
        CHAT_SYSTEM:StartTextEntry(text)
        self:Print("Chat pre-filled - choose a channel and press Confirm.")
        return
    end

    -- Fallback: write to the debug/system area the player can read.
    self:Print("[Share] " .. text)
    StartChatInput(text)
end

---------------------------------------------------------------------------
-- Fight summary share
---------------------------------------------------------------------------

function ConsoleMetrics:BuildFightShareLine(snapshot, label)
    snapshot = snapshot or {}
    local dur  = string.format("%.1fs", tonumber(snapshot.duration) or 0)
    local dps  = ShortNumber(tonumber(snapshot.dps)  or 0)
    local hps  = ShortNumber(tonumber(snapshot.hps)  or 0)
    local dmg  = ShortNumber(tonumber(snapshot.totalDamage) or 0)
    local heal = ShortNumber(tonumber(snapshot.totalHeal)   or 0)
    local tkn  = ShortNumber(tonumber(snapshot.totalTaken)  or 0)
    local crit = string.format("%.1f%%", tonumber(snapshot.critPct) or 0)
    local tag  = label or (ConsoleMetrics.name or "CM")

    return string.format(
        "[%s] %s | DPS %s | HPS %s | Dmg %s | Heal %s | Taken %s | Crit %s",
        tag, dur, dps, hps, dmg, heal, tkn, crit
    )
end

function ConsoleMetrics:ShareFightToChat(customLabel)
    local snapshot, isLive = self:GetViewedFightSnapshot()
    local label = customLabel
    if not label then
        label = isLive and "Live" or ("Fight " .. tostring(self.viewFightIndex or 0))
    end
    local line = self:BuildFightShareLine(snapshot, label)
    self:SendToChat(line)
end

---------------------------------------------------------------------------
-- Top skills share
---------------------------------------------------------------------------

function ConsoleMetrics:BuildTopSkillsShareLine(snapshot, maxSkills)
    maxSkills = maxSkills or 5
    snapshot = snapshot or {}
    local skillList = snapshot.skillList or {}
    local parts = { "[CM Skills]" }
    for i = 1, math.min(maxSkills, #skillList) do
        local s = skillList[i]
        if s then
            local name = type(s.name) == "string" and s.name or "?"
            if #name > 14 then
                -- abbreviate to first word
                name = string.match(name, "^(%S+)") or string.sub(name, 1, 14)
            end
            parts[#parts + 1] = string.format("%s:%s", name, ShortNumber(s.damage or 0))
        end
    end
    if #parts == 1 then parts[#parts + 1] = "no data" end
    return table.concat(parts, " | ")
end

function ConsoleMetrics:ShareTopSkillsToChat()
    local snapshot = self:GetViewedFightSnapshot()
    local line = self:BuildTopSkillsShareLine(snapshot, 5)
    self:SendToChat(line)
end

---------------------------------------------------------------------------
-- Resource / sustain share
---------------------------------------------------------------------------

function ConsoleMetrics:BuildResourceShareLine(snapshot)
    snapshot = snapshot or {}
    local res = snapshot.resourceSummary or {}
    local hp  = res.health   or {}
    local mag = res.magicka  or {}
    local stm = res.stamina  or {}

    local function Pct(tbl)
        if tbl.hasData then
            return string.format("%.0f%%", tonumber(tbl.averagePct) or 0)
        end
        return "n/a"
    end

    return string.format(
        "[CM Sustain] HP avg:%s | Mag avg:%s | Stam avg:%s | Samples:%d",
        Pct(hp), Pct(mag), Pct(stm),
        tonumber(res.sampleCount) or 0
    )
end

function ConsoleMetrics:ShareResourceToChat()
    local snapshot = self:GetViewedFightSnapshot()
    local line = self:BuildResourceShareLine(snapshot)
    self:SendToChat(line)
end

---------------------------------------------------------------------------
-- Build share (improved xb1 version of LinkBuildToChat)
---------------------------------------------------------------------------

function ConsoleMetrics:BuildShareLine()
    local frontBarCategory = type(HOTBAR_CATEGORY_PRIMARY) == "number" and HOTBAR_CATEGORY_PRIMARY or nil
    local backBarCategory  = type(HOTBAR_CATEGORY_BACKUP)  == "number" and HOTBAR_CATEGORY_BACKUP  or nil
    local frontBar     = BuildActionBarSnapshot(frontBarCategory)
    local backBar      = BuildActionBarSnapshot(backBarCategory)
    local equippedSets = BuildEquippedSetSummary()
    local boons        = BuildActiveBoonSnapshot()
    local champ        = BuildChampionSnapshot()

    local function Short(name, max)
        max = max or 13
        if type(name) ~= "string" or name == "" then return "?" end
        if #name <= max then return name end
        return string.match(name, "^(%S+)") or string.sub(name, 1, max)
    end

    local function BarStr(bar)
        local names = {}
        for i = 1, #bar do
            local n = bar[i] and bar[i].abilityName
            if n and n ~= "Empty" and n ~= "" then
                names[#names + 1] = Short(n, 12)
            end
        end
        return #names > 0 and table.concat(names, "/") or "-"
    end

    local setList = {}
    for i = 1, #equippedSets do
        local s = equippedSets[i]
        if s and s.setName and s.setName ~= "" then
            setList[#setList + 1] = Short(s.setName, 16) .. "(" .. tostring(s.numEquipped or 0) .. ")"
        end
    end

    local cpTotal = champ.totalPoints and NumberText(champ.totalPoints) or "?"
    local boonStr = (#boons > 0 and boons[1]) and Short(boons[1], 18) or "-"

    local line = string.format(
        "[CM Build] CP:%s | Sets:%s | Boon:%s | F[%s] B[%s]",
        cpTotal,
        #setList > 0 and table.concat(setList, " ") or "-",
        boonStr,
        BarStr(frontBar),
        BarStr(backBar)
    )
    return line
end

function ConsoleMetrics:ShareBuildToChat()
    local line = self:BuildShareLine()
    self:SendToChat(line)
end

---------------------------------------------------------------------------
-- Combined "full snapshot" share (fight + build on two lines)
---------------------------------------------------------------------------

function ConsoleMetrics:ShareFullSnapshotToChat()
    local snapshot, isLive = self:GetViewedFightSnapshot()
    local label = isLive and "Live" or ("Fight " .. tostring(self.viewFightIndex or 0))

    local fightLine = self:BuildFightShareLine(snapshot, label)
    local buildLine = self:BuildShareLine()

    -- Send both; player sends first, then second
    self:SendToChat(fightLine .. " || " .. buildLine)
end
