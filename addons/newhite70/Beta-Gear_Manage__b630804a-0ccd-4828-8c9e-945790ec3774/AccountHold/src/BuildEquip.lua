-- AccountHold/src/BuildEquip.lua
--
-- Epic 0002, part 2 -- the Quartermaster Armory can now CREATE and EQUIP real
-- builds, not just plan them. A build's LOADOUT holds:
--   * gear     -- every worn piece by unique id (poisons by item id, they stack)
--   * skills   -- both weapon bars (front + back)
--   * champion -- the slottable champion stars
--   * food     -- one food/drink item eaten when the build is equipped
-- and a build can be auto-equipped by player-configured conditions (zone entry,
-- a named boss, any boss in a zone). Auto-equip is OFF by default and nothing
-- here ever acts in combat: a swap requested in combat is queued and resumed
-- when the player is out of combat and alive.
--
-- Every engine function below was verified against esoui/esoui @ 6639eb2
-- (API 101051). "doc:N" = ESOUIDocumentation.txt line N at that commit.
--
--   doc:14951 RequestEquipItem(bag, slot, wornBag, equipSlot)       NOT protected
--   doc:14953 RequestUnequipItem(wornBag, equipSlot)               NOT protected
--             (the base game calls both directly from inventory UI code:
--              esoui/ingame/inventory/inventoryslot.lua:1110, :1137)
--   doc:13726 RequestMoveItem            *protected*  -- NOT used here
--   doc:21489 UseItem                    *protected*  -- CallSecureProtected only
--   doc:11 / :11607  CallSecureProtected / IsProtectedFunction
--   doc:21674 GetItemUniqueId(bag, slot) -> id64:nilable;  doc:11613 Id64ToString
--   doc:21644 GetItemId(bag, slot)
--   doc:13002 IsUnitInCombat;  doc:13014 IsUnitDeadOrReincarnating
--   doc:13892 ArePlayerWeaponsSheathed;  doc:13110 TogglePlayerWield
--   doc:14335 GetSlotBoundId;  doc:14338 GetSlotType;  doc:17560 GetAbilityIdForCraftedAbilityId
--   doc:14418 GetAssignableAbilityBarStartAndEndSlots
--   doc:14421 GetAssignableChampionBarStartAndEndSlots
--   doc:18428 PrepareChampionPurchaseRequest(respecNeeded)
--   doc:18432 AddHotbarSlotToChampionPurchaseRequest(slotIndex, championSkillId)
--   doc:18434 GetChampionPurchaseAvailability;  doc:18440 SendChampionPurchaseRequest
--   doc:18320 CanChampionSkillTypeBeSlotted;  doc:18412 GetChampionSkillType
--   doc:18356 GetNumPointsSpentOnChampionSkill;  doc:18380 IsChampionSystemUnlocked
--   doc:20358 GetArmoryBuildSlotBoundId;  doc:20367 GetArmoryBuildEquipSlotInfo
--   doc:20370 SaveArmoryBuild(buildIndex)  -- NOT protected, but see EXPORT below
--   doc:8198  ARMORY_BUILD_SAVE_RESULT_NO_INTERACTION
--   doc:20398 GetArmoryOperationsCooldownRemaining
--   doc:21422 GetUnitZoneIndex;  doc:23734 GetZoneId;  doc:23749 GetZoneNameById
--   doc:12810 DoesUnitExist;  doc:21419 GetUnitName
--   events: doc:27402 EVENT_BOSSES_CHANGED, :27436 EVENT_CHAMPION_PURCHASE_RESULT,
--           :27857 EVENT_OPEN_ARMORY_MENU, :27375 EVENT_ARMORY_BUILD_SAVE_RESPONSE,
--           :27880 EVENT_PLAYER_ALIVE, :27881 EVENT_PLAYER_COMBAT_STATE,
--           :28145 EVENT_ZONE_CHANGED, :28182 EVENT_PLAYER_ACTIVATED
--
-- SKILLS go through the base game's own Lua manager, exactly like the Skills
-- screen does, never through the protected C functions (SelectSlotAbility /
-- ClearSlot are *protected*, doc:14317-14319):
--   esoui/ingame/skills/actionbarassignmentmanager.lua
--     :531  Hotbar:GetSlotData(i);  :256 SlottablePlayerSkill:GetEffectiveAbilityId
--     :271  skillData:GetPointAllocator():IsPurchased()
--     :633  Hotbar:ClearSlot(i)  (Lua method -- validates, then marks dirty)
--     :681  Hotbar:AssignSkillToSlotByAbilityId(i, abilityId)
--     :1003 AddChangesToMessage -- both PRIMARY and BACKUP are submitted
--   esoui/ingame/skills/skillsandactionbarmanager.lua:34 registers an every-frame
--     update and :132-137 sends a dirty assignment from it in the default
--     PURCHASE_ONLY mode -- so no Skills scene has to be open.
-- BOSS units: esoui/ingame/unitframes/bossbar.lua:24-25 walks
--   BOSS_RANK_ITERATION_BEGIN..END as "boss"..i.
--
-- EXPORT TO THE IN-GAME ARMORY. SaveArmoryBuild carries no *protected* marker,
-- but its result enum has ARMORY_BUILD_SAVE_RESULT_NO_INTERACTION (doc:8198):
-- the server only accepts it while the player is interacting with an Armory
-- Station, and it snapshots what the character is wearing RIGHT NOW (the base
-- game calls it only from its station dialog, armorydialogs.lua:267). So export
-- is: equip the Quartermaster build, then -- when the player next opens an
-- Armory Station (EVENT_OPEN_ARMORY_MENU) -- ask them to confirm saving it into
-- the slot they picked. Nothing is ever written to the Armory without that A
-- press at the station.
--
-- QUICKSLOT WHEEL. Not possible: the wheel accepts only ITEM, COLLECTIBLE,
-- QUEST_ITEM, EMOTE and QUICK_CHAT action types
-- (esoui/ingame/utilitywheel/assignableutilitywheel_shared.lua:4-12) and every
-- function that writes a slot (SelectSlotItem / SelectSlotSimpleAction) is
-- *protected* (doc:14321-14323). There is no add-on action type, and console
-- cannot bind custom Bindings.xml keys. The closest equivalent is the one-press
-- "Quick equip" list at the top of the Quartermaster Armory.
--
-- ESO runs Lua 5.1. This file must LOAD under tests/zos_mock.lua with none of
-- the engine globals present: every global is resolved BY NAME at call time.

AccountHold = AccountHold or {}
AccountHold.BuildEquip = AccountHold.BuildEquip or {}

local BE = AccountHold.BuildEquip
local addon

-- ---------------------------------------------------------------------------
-- Guarded primitives
-- ---------------------------------------------------------------------------

local function L(id, fallback)
    local f = AccountHold and AccountHold.L
    if type(f) == "function" then
        local ok, v = pcall(f, id, fallback)
        if ok and type(v) == "string" and v ~= "" then return v end
    end
    return fallback
end

local function g(name)
    local ok, v = pcall(function() return _G[name] end)
    if ok then return v end
    return nil
end

local function gfn(name)
    local v = g(name)
    if type(v) == "function" then return v end
    return nil
end

local function gnum(name)
    local v = g(name)
    if type(v) == "number" then return v end
    return nil
end

-- EIGHT results: GetItemLinkSetInfo's setId is the 6th (doc:21885-21886) and
-- truncating multi-returns has bitten this add-on before.
local function call(name, ...)
    local f = gfn(name)
    if not f then return nil end
    local ok, a, b, c, d, e, f6, g7, h8 = pcall(f, ...)
    if not ok then return nil end
    return a, b, c, d, e, f6, g7, h8
end

local function fmt(pattern, ...)
    local ok, s = pcall(string.format, pattern, ...)
    if ok then return s end
    return tostring(pattern)
end

local function diag(level, pattern, ...)
    local a = addon or AccountHold
    if a and type(a.Diagnostic) == "function" then
        local msg = fmt(pattern, ...)
        pcall(a.Diagnostic, a, level, "[build] %s", msg)
    end
end

-- Console players cannot see Lua errors: every outcome the player caused (or
-- an auto-equip caused for them) is said on screen.
local function alert(msg)
    if type(msg) ~= "string" or msg == "" then return end
    local N = AccountHold and AccountHold.Notify
    if type(N) == "table" and type(N.Alert) == "function" then
        if pcall(N.Alert, N, msg) then return end
    end
    local a = addon or AccountHold
    if a and type(a.Log) == "function" then pcall(a.Log, a, "%s", msg) end
end

local function safe()
    return AccountHold and AccountHold.Core and AccountHold.Core.Safe
end

-- obj:name(...) for an ENGINE object (userdata on hardware) or a Lua object.
-- Guards on the METHOD, never on type(obj) == "table".
local function invoke(obj, name, ...)
    if obj == nil then return false, nil end
    local S = safe()
    local m
    if S and type(S.Method) == "function" then
        m = S.Method(obj, name)
    else
        local ok, v = pcall(function() return obj[name] end)
        if ok and type(v) == "function" then m = v end
    end
    if not m then return false, nil end
    local ok, a, b = pcall(m, obj, ...)
    if not ok then return false, a end
    return true, a, b
end

local function model()
    local bc = AccountHold and AccountHold.BuildCreator
    if type(bc) == "table" then return bc end
    return nil
end

local function getBuild(buildId)
    local bc = model()
    if not bc or type(bc.GetBuild) ~= "function" then return nil end
    local ok, rec = pcall(bc.GetBuild, bc, buildId)
    if ok and type(rec) == "table" then return rec end
    return nil
end

local OWNER_KEY = "ahCharacterId"

local function currentCharKey()
    local a = addon or AccountHold
    if a and type(a.GetCharacterId) == "function" then
        local ok, id = pcall(a.GetCharacterId, a)
        if ok and id ~= nil then return tostring(id) end
    end
    local id = call("GetCurrentCharacterId")
    if id ~= nil then return tostring(id) end
    return nil
end

local function ownerOf(rec)
    if type(rec) ~= "table" or rec[OWNER_KEY] == nil then return nil end
    return tostring(rec[OWNER_KEY])
end

local function nowMs()
    local t = call("GetFrameTimeMilliseconds") or call("GetGameTimeMilliseconds")
    if type(t) == "number" then return t end
    return 0
end

local function timestamp()
    local t = call("GetTimeStamp")
    if type(t) == "number" then return t end
    return 0
end

-- id64 -> stable string. Id64ToString (doc:11613) where it exists; the mock and
-- any client without it fall back to tostring.
local function uidString(id)
    if id == nil then return nil end
    local f = gfn("Id64ToString")
    if f then
        local ok, s = pcall(f, id)
        if ok and type(s) == "string" and s ~= "" then return s end
    end
    local s = tostring(id)
    if s == "" or s == "0" then return nil end
    return s
end

local function uidAt(bag, slot)
    if bag == nil or slot == nil then return nil end
    return uidString((call("GetItemUniqueId", bag, slot)))
end

local function itemIdAt(bag, slot)
    local id = call("GetItemId", bag, slot)
    if type(id) == "number" and id > 0 then return id end
    return nil
end

local function linkAt(bag, slot)
    local style = gnum("LINK_STYLE_DEFAULT")
    local link
    if style then link = call("GetItemLink", bag, slot, style) else link = call("GetItemLink", bag, slot) end
    if type(link) == "string" and link ~= "" then return link end
    return nil
end

-- ---------------------------------------------------------------------------
-- Gear slots
-- ---------------------------------------------------------------------------
-- Keyed by EQUIP_SLOT_* constant NAME (a string) because this is persisted: a
-- stored number would silently re-point at a different slot if ZOS renumbered
-- the enum, and console players cannot repair SavedVariables.
local GEAR_SLOTS = {
    { name = "EQUIP_SLOT_HEAD",          key = "head" },
    { name = "EQUIP_SLOT_SHOULDERS",     key = "shoulders" },
    { name = "EQUIP_SLOT_CHEST",         key = "chest" },
    { name = "EQUIP_SLOT_HAND",          key = "hands" },
    { name = "EQUIP_SLOT_WAIST",         key = "waist" },
    { name = "EQUIP_SLOT_LEGS",          key = "legs" },
    { name = "EQUIP_SLOT_FEET",          key = "feet" },
    { name = "EQUIP_SLOT_NECK",          key = "neck" },
    { name = "EQUIP_SLOT_RING1",         key = "ring1" },
    { name = "EQUIP_SLOT_RING2",         key = "ring2" },
    { name = "EQUIP_SLOT_MAIN_HAND",     key = "mainHand",   weapon = true },
    { name = "EQUIP_SLOT_OFF_HAND",      key = "offHand",    weapon = true, clearable = true },
    { name = "EQUIP_SLOT_BACKUP_MAIN",   key = "backupMain", weapon = true },
    { name = "EQUIP_SLOT_BACKUP_OFF",    key = "backupOff",  weapon = true, clearable = true },
    -- doc:4955 / :4941. Poisons STACK, so they are matched by item id, not by
    -- unique id: the stack the player saved may have been used up and replaced.
    { name = "EQUIP_SLOT_POISON",        key = "poison",       weapon = true, stack = true, clearable = true },
    { name = "EQUIP_SLOT_BACKUP_POISON", key = "backupPoison", weapon = true, stack = true, clearable = true },
}
BE.GEAR_SLOTS = GEAR_SLOTS

local GEAR_LABELS = {
    poison       = { "SI_ACCOUNTHOLD_BUILDEQ_SLOT_POISON",        "Poison" },
    backupPoison = { "SI_ACCOUNTHOLD_BUILDEQ_SLOT_BACKUP_POISON", "Backup Poison" },
}

local function slotLabel(def)
    local bc = model()
    if bc and type(bc.IsSlot) == "function" and bc:IsSlot(def.key) then
        local ok, s = pcall(bc.GetSlotLabel, bc, def.key)
        if ok and type(s) == "string" then return s end
    end
    local l = GEAR_LABELS[def.key]
    if l then return L(l[1], l[2]) end
    return def.key
end

local function resolvedGearSlots()
    local out = {}
    for _, def in ipairs(GEAR_SLOTS) do
        local v = gnum(def.name)
        if v ~= nil then out[#out + 1] = { def = def, equipSlot = v } end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Bars
-- ---------------------------------------------------------------------------

local BARS = {
    { key = "primary", const = "HOTBAR_CATEGORY_PRIMARY" },
    { key = "backup",  const = "HOTBAR_CATEGORY_BACKUP" },
}
BE.BARS = BARS

local function skillRange()
    local a, b = call("GetAssignableAbilityBarStartAndEndSlots")
    if type(a) == "number" and type(b) == "number" and b >= a and b - a < 12 then return a, b end
    -- actionbarassignmentmanager.lua:56-58: first normal slot 3 .. ultimate 8.
    return 3, 8
end

local function championRange()
    local a, b = call("GetAssignableChampionBarStartAndEndSlots")
    if type(a) == "number" and type(b) == "number" and b >= a and b - a < 24 then return a, b end
    return 1, 12
end

local function hotbar(cat)
    local mgr = g("ACTION_BAR_ASSIGNMENT_MANAGER")
    local ok, bar = invoke(mgr, "GetHotbar", cat)
    if ok and bar ~= nil then return bar end
    return nil
end

local function readSkill(cat, i)
    local bar = hotbar(cat)
    if bar then
        local ok, data = invoke(bar, "GetSlotData", i)
        if ok and data ~= nil then
            local ok2, id = invoke(data, "GetEffectiveAbilityId")
            if ok2 and type(id) == "number" then return id end
            ok2, id = invoke(data, "GetActionId")
            if ok2 and type(id) == "number" then return id end
            return 0
        end
    end
    local id = call("GetSlotBoundId", i, cat)
    if type(id) ~= "number" then return 0 end
    local crafted = gnum("ACTION_TYPE_CRAFTED_ABILITY")
    if crafted and call("GetSlotType", i, cat) == crafted then
        id = call("GetAbilityIdForCraftedAbilityId", id) or 0
    end
    return id
end

local function readChampion(i)
    local cat = gnum("HOTBAR_CATEGORY_CHAMPION")
    if not cat then return 0 end
    local id = call("GetSlotBoundId", i, cat)
    if type(id) == "number" then return id end
    return 0
end

-- ---------------------------------------------------------------------------
-- Init / gate
-- ---------------------------------------------------------------------------

function BE:IsEnabled()
    local F = AccountHold and AccountHold.Features
    if type(F) ~= "table" or type(F.IsEnabled) ~= "function" then return false end
    local ok, v = pcall(F.IsEnabled, F, "buildCreator")
    return (ok and v) and true or false
end

local function isAvailable()
    local F = AccountHold and AccountHold.Features
    if type(F) ~= "table" or type(F.REGISTRY) ~= "table" then return true end
    local reg = F.REGISTRY.buildCreator
    if type(reg) ~= "table" then return true end
    return reg.available ~= false
end

local function state()
    local a = addon or AccountHold
    if not a or type(a.sv) ~= "table" then return nil end
    if type(a.sv.buildEquip) ~= "table" then a.sv.buildEquip = {} end
    local key = currentCharKey()
    if not key then return nil end
    local s = a.sv.buildEquip[key]
    if type(s) ~= "table" then
        s = {}
        a.sv.buildEquip[key] = s
    end
    return s
end
BE._State = state

local EVENT_NAME = "AccountHold_BuildEquip"
local TICK_NAME  = "AccountHold_BuildEquipTick"
local TICK_MS    = 200
local VERIFY_TICKS = 10
local CP_COOLDOWN_MS = 30000
local MAX_RULES = 20

BE.TICK_MS, BE.VERIFY_TICKS = TICK_MS, VERIFY_TICKS

-- Every engine callback goes through here: a throw is reported in the
-- diagnostics ring AND on screen, never swallowed.
local function guarded(label, fn)
    return function(_, ...)
        local ok, err = pcall(fn, BE, ...)
        if not ok then
            diag("error", "%s failed: %s", label, tostring(err))
            alert(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_HANDLER_FAILED",
                "Quartermaster Armory: %s hit an error and stopped. Details are in the diagnostics."), label))
        end
    end
end

local function register(event, label, fn)
    local em = g("EVENT_MANAGER")
    local ev = g(event)
    if em == nil or ev == nil then return false end
    local ok = invoke(em, "RegisterForEvent", EVENT_NAME, ev, guarded(label, fn))
    return ok
end

function BE:Initialize(addonRef)
    addon = addonRef
    self._run, self._pending = nil, nil
    self._lastZoneId, self._lastBossKey = nil, nil
    if not isAvailable() then
        diag("info", "Feature 'buildCreator' unavailable - build equip events NOT registered.")
        return
    end
    -- Registered once; every handler re-checks the runtime gate, so turning
    -- the feature off in settings makes all of them inert without a reload.
    register("EVENT_PLAYER_ACTIVATED",        "zone check",        BE.OnPlayerActivated)
    register("EVENT_ZONE_CHANGED",            "zone check",        BE.OnZoneChanged)
    register("EVENT_BOSSES_CHANGED",          "boss check",        BE.OnBossesChanged)
    register("EVENT_PLAYER_COMBAT_STATE",     "combat resume",     BE.OnCombatState)
    register("EVENT_PLAYER_ALIVE",            "revive resume",     BE.OnPlayerAlive)
    register("EVENT_CHAMPION_PURCHASE_RESULT","champion result",   BE.OnChampionResult)
    register("EVENT_OPEN_ARMORY_MENU",        "Armory Station",    BE.OnArmoryMenuOpened)
    register("EVENT_ARMORY_BUILD_SAVE_RESPONSE", "Armory save",    BE.OnArmorySaveResponse)
end

-- ---------------------------------------------------------------------------
-- Player state
-- ---------------------------------------------------------------------------

-- True when NOTHING may be done right now. Unknown == blocked: if the client
-- cannot tell us the player is out of combat, we do not assume it.
function BE:IsBlocked()
    if not gfn("IsUnitInCombat") then return true, "noApi" end
    if call("IsUnitInCombat", "player") then return true, "combat" end
    if call("IsUnitDeadOrReincarnating", "player") then return true, "dead" end
    return false
end

function BE:CurrentZone()
    local idx = call("GetUnitZoneIndex", "player")
    local zoneId = (type(idx) == "number") and call("GetZoneId", idx) or nil
    if type(zoneId) ~= "number" or zoneId <= 0 then return nil, nil end
    local name = call("GetZoneNameById", zoneId)
    if type(name) ~= "string" or name == "" then name = call("GetUnitZone", "player") end
    if type(name) ~= "string" or name == "" then name = fmt("Zone %d", zoneId) end
    return zoneId, name
end

-- Display form of an engine name: drops the "^Mx" grammar suffix.
local function plainName(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub("%^.*$", ""))
end
BE._PlainName = plainName

function BE:CurrentBosses()
    local first = gnum("BOSS_RANK_ITERATION_BEGIN") or 1
    local last  = gnum("BOSS_RANK_ITERATION_END") or 12
    if last < first or last - first > 24 then first, last = 1, 12 end
    local out, seen = {}, {}
    for i = first, last do
        local tag = "boss" .. i
        if call("DoesUnitExist", tag) then
            local name = call("GetUnitName", tag)
            if type(name) == "string" and name ~= "" and not seen[name] then
                seen[name] = true
                out[#out + 1] = name
            end
        end
    end
    table.sort(out)
    return out
end

-- ---------------------------------------------------------------------------
-- Loadout records
-- ---------------------------------------------------------------------------

function BE:GetLoadout(buildId)
    local rec = getBuild(buildId)
    if rec and type(rec.loadout) == "table" then return rec.loadout end
    return nil
end

function BE:HasLoadout(buildId)
    local lo = self:GetLoadout(buildId)
    if not lo then return false end
    if type(lo.gear) == "table" and next(lo.gear) ~= nil then return true end
    if type(lo.skills) == "table" and next(lo.skills) ~= nil then return true end
    if type(lo.cp) == "table" and next(lo.cp) ~= nil then return true end
    return type(lo.food) == "table"
end

-- A build tagged to ANOTHER character must never be captured onto or equipped
-- here: the items and skills are not this character's.
local function ownedHere(rec)
    local owner = ownerOf(rec)
    if owner == nil then return true end
    return owner == currentCharKey()
end

local function refuse(msg, pattern, ...)
    diag("warn", pattern or "%s", ...)
    alert(msg)
    return false
end

-- Snapshot the character as they are now into the build's loadout. Also fills
-- the build PLAN (set per slot) from the worn gear, so the planner reflects it.
function BE:CaptureLoadout(buildId)
    if not self:IsEnabled() then
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_DISABLED", "The Quartermaster Armory is switched off."),
            "CaptureLoadout refused: feature gate off.")
    end
    local rec = getBuild(buildId)
    if not rec then
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_NO_BUILD", "That build no longer exists."),
            "CaptureLoadout: no build %s.", tostring(buildId))
    end
    if not ownedHere(rec) then
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_OTHER_CHAR",
            "That build belongs to another character. Assign it to this character first."),
            "CaptureLoadout: build %s is owned by %s.", tostring(buildId), tostring(ownerOf(rec)))
    end

    local worn = gnum("BAG_WORN")
    local lo = { capturedAt = timestamp(), gear = {}, skills = {}, cp = {} }
    local counts = { gear = 0, skills = 0, cp = 0 }
    local bc = model()

    if worn then
        for _, r in ipairs(resolvedGearSlots()) do
            local def = r.def
            local uid  = uidAt(worn, r.equipSlot)
            local link = linkAt(worn, r.equipSlot)
            if uid or link then
                lo.gear[def.name] = { uid = uid, link = link, itemId = itemIdAt(worn, r.equipSlot) }
                counts.gear = counts.gear + 1
                if bc and type(bc.IsSlot) == "function" and bc:IsSlot(def.key) and link then
                    local hasSet, _, _, _, _, setId = call("GetItemLinkSetInfo", link, false)
                    if hasSet and type(setId) == "number" and setId > 0 then
                        pcall(bc.SetSlot, bc, buildId, def.key, setId)
                    end
                end
            elseif def.clearable then
                -- Only weapon-config slots record "empty": a two-hander build
                -- must take the shield off. Armour slots left empty mean "leave
                -- alone", never "strip the character".
                lo.gear[def.name] = { empty = true }
            end
        end
    end

    local first, last = skillRange()
    for _, bar in ipairs(BARS) do
        local cat = gnum(bar.const)
        if cat then
            local t = {}
            for i = first, last do
                t[i] = readSkill(cat, i)
                if t[i] ~= 0 then counts.skills = counts.skills + 1 end
            end
            lo.skills[bar.key] = t
        end
    end

    local c1, c2 = championRange()
    if gnum("HOTBAR_CATEGORY_CHAMPION") then
        for i = c1, c2 do
            lo.cp[i] = readChampion(i)
            if lo.cp[i] ~= 0 then counts.cp = counts.cp + 1 end
        end
    end

    -- Food is chosen explicitly (there is no API that names the food you ate),
    -- so a re-capture keeps whatever the player picked.
    if type(rec.loadout) == "table" and type(rec.loadout.food) == "table" then
        lo.food = rec.loadout.food
    end

    rec.loadout = lo
    rec.updatedAt = timestamp()
    if ownerOf(rec) == nil then rec[OWNER_KEY] = currentCharKey() end
    diag("info", "Captured loadout for build %s: %d gear, %d skills, %d stars.",
        tostring(buildId), counts.gear, counts.skills, counts.cp)
    return true, counts
end

-- Copy an in-game Armory build's gear, bars and stars into a build's loadout.
-- Used by Import so an imported build can be equipped straight away.
function BE:ImportLoadoutFromArmory(buildId, buildIndex)
    local rec = getBuild(buildId)
    if not rec or type(buildIndex) ~= "number" then return false end
    local lo = { capturedAt = timestamp(), gear = {}, skills = {}, cp = {}, fromArmory = buildIndex }
    local counts = { gear = 0, skills = 0, cp = 0 }
    if gfn("GetArmoryBuildEquipSlotInfo") then
        local VALID = gnum("ARMORY_BUILD_EQUIP_SLOT_STATE_VALID")
        for _, r in ipairs(resolvedGearSlots()) do
            local st, bag, slot = call("GetArmoryBuildEquipSlotInfo", buildIndex, r.equipSlot)
            if bag ~= nil and slot ~= nil and (VALID == nil or st == VALID
               or call("IsItemInArmory", bag, slot) == true) then
                local uid = uidAt(bag, slot)
                if uid then
                    lo.gear[r.def.name] = { uid = uid, link = linkAt(bag, slot), itemId = itemIdAt(bag, slot) }
                    counts.gear = counts.gear + 1
                end
            end
        end
    end
    -- armorybuilddata.lua:61-66 -- the base game reads bars and stars exactly so.
    if gfn("GetArmoryBuildSlotBoundId") then
        local first, last = skillRange()
        for _, bar in ipairs(BARS) do
            local cat = gnum(bar.const)
            if cat then
                local t = {}
                for i = first, last do
                    local id = call("GetArmoryBuildSlotBoundId", buildIndex, i, cat)
                    t[i] = (type(id) == "number") and id or 0
                    if t[i] ~= 0 then counts.skills = counts.skills + 1 end
                end
                lo.skills[bar.key] = t
            end
        end
        local cpCat = gnum("HOTBAR_CATEGORY_CHAMPION")
        if cpCat then
            local c1, c2 = championRange()
            for i = c1, c2 do
                local id = call("GetArmoryBuildSlotBoundId", buildIndex, i, cpCat)
                lo.cp[i] = (type(id) == "number") and id or 0
                if lo.cp[i] ~= 0 then counts.cp = counts.cp + 1 end
            end
        end
    end
    if counts.gear + counts.skills + counts.cp == 0 then return false, counts end
    rec.loadout = lo
    rec.updatedAt = timestamp()
    return true, counts
end

-- ---------------------------------------------------------------------------
-- Locating items
-- ---------------------------------------------------------------------------

local function findByUid(uid)
    if not uid then return nil end
    local worn, pack = gnum("BAG_WORN"), gnum("BAG_BACKPACK")
    if worn then
        for _, r in ipairs(resolvedGearSlots()) do
            if uidAt(worn, r.equipSlot) == uid then return worn, r.equipSlot end
        end
    end
    if pack then
        local size = call("GetBagSize", pack) or 0
        for s = 0, size - 1 do
            if uidAt(pack, s) == uid then return pack, s end
        end
    end
    return nil
end

local function findByItemId(itemId)
    local pack = gnum("BAG_BACKPACK")
    if not pack or not itemId then return nil end
    local size = call("GetBagSize", pack) or 0
    for s = 0, size - 1 do
        if itemIdAt(pack, s) == itemId then return pack, s end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Planning: what would equipping this build actually change?
-- ---------------------------------------------------------------------------

-- actionbarassignmentmanager.lua:681-684 resolves the id through
-- SKILLS_DATA_MANAGER and :271 asks the point allocator whether it is bought.
local function isPurchased(abilityId)
    local sdm = g("SKILLS_DATA_MANAGER")
    local ok, prog = invoke(sdm, "GetProgressionDataByAbilityId", abilityId)
    if not ok or prog == nil then return false, "unknown" end
    local ok2, skillData = invoke(prog, "GetSkillData")
    if not ok2 or skillData == nil then return false, "unknown" end
    local ok3, alloc = invoke(skillData, "GetPointAllocator")
    if ok3 and alloc ~= nil then
        local ok4, purchased = invoke(alloc, "IsPurchased")
        if ok4 then return purchased and true or false, (not purchased) and "notPurchased" or nil end
    end
    local ok5, purchased = invoke(skillData, "IsPurchased")
    if ok5 then return purchased and true or false, (not purchased) and "notPurchased" or nil end
    return false, "unknown"
end

local function starUsable(id)
    local slottable = call("CanChampionSkillTypeBeSlotted", call("GetChampionSkillType", id))
    local spent = call("GetNumPointsSpentOnChampionSkill", id)
    return (slottable and type(spent) == "number" and spent > 0) and true or false
end

-- Slots this character CANNOT fill (skill not learned, star not bought) do
-- not count as differences: no equip could ever close them, and counting them
-- would make "is this build on?" false forever.
local function skillsDiffer(lo)
    if type(lo.skills) ~= "table" then return false end
    for _, bar in ipairs(BARS) do
        local cat, want = gnum(bar.const), lo.skills[bar.key]
        if cat and type(want) == "table" then
            for i, id in pairs(want) do
                if type(i) == "number" and readSkill(cat, i) ~= id
                   and (id == 0 or isPurchased(id)) then
                    return true
                end
            end
        end
    end
    return false
end

local function cpDiffers(lo)
    if type(lo.cp) ~= "table" then return false end
    for i, id in pairs(lo.cp) do
        if type(i) == "number" and id ~= 0 and readChampion(i) ~= id and starUsable(id) then return true end
    end
    return false
end

-- Returns an ordered step list. `opts.food == false` omits the food step (used
-- to ask "is this build already on?").
function BE:PlanSteps(buildId, opts)
    opts = opts or {}
    local lo = self:GetLoadout(buildId)
    local steps = {}
    if not lo then return steps end
    local worn = gnum("BAG_WORN")
    if worn and type(lo.gear) == "table" then
        for _, r in ipairs(resolvedGearSlots()) do
            local want = lo.gear[r.def.name]
            if type(want) == "table" then
                local label = slotLabel(r.def)
                if want.empty then
                    if uidAt(worn, r.equipSlot) or itemIdAt(worn, r.equipSlot) then
                        steps[#steps + 1] = { kind = "unequip", equipSlot = r.equipSlot, label = label,
                                              weapon = r.def.weapon }
                    end
                elseif r.def.stack then
                    if want.itemId and itemIdAt(worn, r.equipSlot) ~= want.itemId then
                        steps[#steps + 1] = { kind = "gear", stack = true, itemId = want.itemId,
                                              equipSlot = r.equipSlot, label = label, weapon = true }
                    end
                elseif want.uid and uidAt(worn, r.equipSlot) ~= want.uid then
                    steps[#steps + 1] = { kind = "gear", uid = want.uid, equipSlot = r.equipSlot,
                                          label = label, weapon = r.def.weapon }
                end
            end
        end
    end
    if skillsDiffer(lo) then steps[#steps + 1] = { kind = "skills" } end
    if cpDiffers(lo) then steps[#steps + 1] = { kind = "cp" } end
    if opts.food ~= false and type(lo.food) == "table" and lo.food.itemId then
        steps[#steps + 1] = { kind = "food", itemId = lo.food.itemId, link = lo.food.link }
    end
    return steps
end

function BE:IsEquipped(buildId)
    if not self:HasLoadout(buildId) then return false, 0 end
    local steps = self:PlanSteps(buildId, { food = false })
    return #steps == 0, #steps
end

-- ---------------------------------------------------------------------------
-- The runner. One step per tick; never in combat.
-- ---------------------------------------------------------------------------

local function startTicker()
    local em = g("EVENT_MANAGER")
    local ok = invoke(em, "RegisterForUpdate", TICK_NAME, TICK_MS, function()
        local okStep, err = pcall(BE.Step, BE)
        if not okStep then
            diag("error", "equip step failed: %s", tostring(err))
            alert(L("SI_ACCOUNTHOLD_BUILDEQ_STEP_FAILED",
                "Quartermaster stopped equipping the build because of an error. Details are in the diagnostics."))
            BE._run = nil
            invoke(g("EVENT_MANAGER"), "UnregisterForUpdate", TICK_NAME)
        end
    end)
    return ok
end

local function stopTicker()
    invoke(g("EVENT_MANAGER"), "UnregisterForUpdate", TICK_NAME)
end

local function buildName(buildId)
    local rec = getBuild(buildId)
    return (rec and type(rec.name) == "string" and rec.name ~= "" and rec.name) or tostring(buildId)
end

local function blockedMessage(why)
    if why == "dead" then
        return L("SI_ACCOUNTHOLD_BUILDEQ_WHY_DEAD", "you are dead")
    elseif why == "noApi" then
        return L("SI_ACCOUNTHOLD_BUILDEQ_WHY_NOAPI", "this client cannot report combat state")
    end
    return L("SI_ACCOUNTHOLD_BUILDEQ_WHY_COMBAT", "you are in combat")
end

-- Request an equip. opts = { reason = "manual"|"auto"|"export", trigger = {...} }
-- Returns a status string: "started", "deferred", "already", "refused".
function BE:Equip(buildId, opts)
    opts = opts or {}
    if not self:IsEnabled() then
        refuse(L("SI_ACCOUNTHOLD_BUILDEQ_DISABLED", "The Quartermaster Armory is switched off."),
            "Equip refused: feature gate off.")
        return "refused"
    end
    local rec = getBuild(buildId)
    if not rec then
        refuse(L("SI_ACCOUNTHOLD_BUILDEQ_NO_BUILD", "That build no longer exists."),
            "Equip: no build %s.", tostring(buildId))
        return "refused"
    end
    if not ownedHere(rec) then
        refuse(L("SI_ACCOUNTHOLD_BUILDEQ_OTHER_CHAR",
            "That build belongs to another character. Assign it to this character first."),
            "Equip: build %s owned by %s.", tostring(buildId), tostring(ownerOf(rec)))
        return "refused"
    end
    if not self:HasLoadout(buildId) then
        refuse(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_NO_LOADOUT",
            "\"%s\" has nothing saved to equip yet. Save what you are wearing to it first (Y)."), rec.name or "?"),
            "Equip: build %s has no loadout.", tostring(buildId))
        return "refused"
    end

    if self._run then
        if self._run.buildId == buildId then return "started" end
        diag("info", "Equip of %s replaces the unfinished equip of %s.", tostring(buildId), tostring(self._run.buildId))
        self._run = nil
        stopTicker()
    end

    local blocked, why = self:IsBlocked()
    if blocked then
        self._pending = { buildId = buildId, reason = opts.reason or "manual", trigger = opts.trigger,
                          skipFood = opts.skipFood }
        alert(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_DEFERRED",
            "Quartermaster will equip \"%s\" as soon as you are out of combat (%s)."), rec.name or "?", blockedMessage(why)))
        diag("info", "Equip of %s deferred (%s).", tostring(buildId), tostring(why))
        return "deferred"
    end
    self._pending = nil

    -- Food is a consumable: never eat twice for one request (a paused run that
    -- already ate), and never re-eat when an auto rule re-applies the build
    -- that is already the last one equipped.
    local skipFood = opts.skipFood or (opts.reason == "auto" and self:LastEquipped() == buildId)
    local steps = self:PlanSteps(buildId, { food = not skipFood })
    if #steps == 0 then
        local s = state()
        if s then s.lastEquipped = buildId end
        if opts.reason ~= "auto" then
            alert(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_ALREADY", "\"%s\" is already equipped."), rec.name or "?"))
        end
        return "already"
    end

    self._run = {
        buildId = buildId, name = rec.name or "?", steps = steps, i = 1,
        reason = opts.reason or "manual", trigger = opts.trigger,
        report = { gear = 0, skills = 0, cp = 0, food = 0, failed = {}, notes = {} },
    }
    if not startTicker() then
        self._run = nil
        refuse(L("SI_ACCOUNTHOLD_BUILDEQ_NO_TICKER", "This client cannot schedule the equip. Nothing was changed."),
            "Equip: EVENT_MANAGER:RegisterForUpdate unavailable.")
        return "refused"
    end
    alert(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_STARTED", "Equipping \"%s\"..."), rec.name or "?"))
    return "started"
end

function BE:IsBusy() return self._run ~= nil end
function BE:GetPending() return self._pending end
function BE:LastEquipped()
    local s = state()
    return s and s.lastEquipped or nil
end

local function fail(run, step, reason)
    run.report.failed[#run.report.failed + 1] = { kind = step.kind, label = step.label or step.kind, reason = reason }
    diag("warn", "Equip %s: step %s (%s) failed: %s", tostring(run.buildId), tostring(step.kind),
        tostring(step.label), tostring(reason))
    return "next"
end

local STEP = {}

STEP.gear = function(run, step)
    local worn = gnum("BAG_WORN")
    local function inPlace()
        if step.stack then return itemIdAt(worn, step.equipSlot) == step.itemId end
        return uidAt(worn, step.equipSlot) == step.uid
    end
    if step.phase == "verify" then
        if inPlace() then
            run.report.gear = run.report.gear + 1
            return "next"
        end
        step.attempts = (step.attempts or 0) + 1
        if step.attempts >= VERIFY_TICKS then return fail(run, step, "timeout") end
        return "wait"
    end
    if inPlace() then return "next" end
    local bag, slot
    if step.stack then bag, slot = findByItemId(step.itemId) else bag, slot = findByUid(step.uid) end
    if bag == nil then return fail(run, step, "missing") end
    -- Weapons cannot be swapped while drawn: sheathe once per run, then wait a
    -- tick for the animation before the first weapon move.
    if step.weapon and not run.sheathed and call("ArePlayerWeaponsSheathed") == false then
        run.sheathed = true
        call("TogglePlayerWield")
        return "wait"
    end
    local f = gfn("RequestEquipItem")
    if not f then return fail(run, step, "noApi") end
    local ok, err = pcall(f, bag, slot, worn, step.equipSlot)
    if not ok then return fail(run, step, "rejected: " .. tostring(err)) end
    step.phase, step.attempts = "verify", 0
    return "wait"
end

STEP.unequip = function(run, step)
    local worn = gnum("BAG_WORN")
    local function empty() return uidAt(worn, step.equipSlot) == nil and itemIdAt(worn, step.equipSlot) == nil end
    if step.phase == "verify" then
        if empty() then
            run.report.gear = run.report.gear + 1
            return "next"
        end
        step.attempts = (step.attempts or 0) + 1
        if step.attempts >= VERIFY_TICKS then return fail(run, step, "timeout") end
        return "wait"
    end
    if empty() then return "next" end
    local f = gfn("RequestUnequipItem")
    if not f then return fail(run, step, "noApi") end
    local ok, err = pcall(f, worn, step.equipSlot)
    if not ok then return fail(run, step, "rejected: " .. tostring(err)) end
    step.phase, step.attempts = "verify", 0
    return "wait"
end

local function skillName(id)
    local n = call("GetAbilityName", id, "player")
    if type(n) == "string" and n ~= "" then return plainName(n) end
    return fmt("#%d", id)
end

STEP.skills = function(run, step)
    local lo = BE:GetLoadout(run.buildId) or {}
    if step.phase == "verify" then
        step.attempts = (step.attempts or 0) + 1
        local pendingSlots = 0
        for _, bar in ipairs(BARS) do
            local cat, want = gnum(bar.const), (lo.skills or {})[bar.key]
            if cat and type(want) == "table" then
                for i, id in pairs(want) do
                    if type(i) == "number" and not (step.skipped[bar.key .. i]) and readSkill(cat, i) ~= id then
                        pendingSlots = pendingSlots + 1
                    end
                end
            end
        end
        if pendingSlots == 0 then
            run.report.skills = run.report.skills + step.assigned
            return "next"
        end
        if step.attempts >= VERIFY_TICKS then
            run.report.skills = run.report.skills + math.max(0, step.assigned - pendingSlots)
            return fail(run, { kind = "skills", label = L("SI_ACCOUNTHOLD_BUILDEQ_SKILLS", "Skills") },
                fmt("%d slot(s) did not change", pendingSlots))
        end
        return "wait"
    end
    step.assigned, step.skipped = 0, {}
    for _, bar in ipairs(BARS) do
        local cat, want = gnum(bar.const), (lo.skills or {})[bar.key]
        local hb = cat and hotbar(cat)
        if cat and type(want) == "table" then
            if not hb then
                return fail(run, { kind = "skills", label = L("SI_ACCOUNTHOLD_BUILDEQ_SKILLS", "Skills") }, "noApi")
            end
            local first, last = skillRange()
            for i = first, last do
                local id = want[i]
                if type(id) == "number" and readSkill(cat, i) ~= id then
                    if id == 0 then
                        -- :633-646 returns false when the slot cannot be edited.
                        local ok, res = invoke(hb, "ClearSlot", i)
                        if ok and res ~= false then
                            step.assigned = step.assigned + 1
                        else
                            step.skipped[bar.key .. i] = true
                        end
                    else
                        local purchased, why = isPurchased(id)
                        if purchased then
                            -- :649-679 returns true only when it changed the slot.
                            local ok, res = invoke(hb, "AssignSkillToSlotByAbilityId", i, id)
                            if ok and res == true then
                                step.assigned = step.assigned + 1
                            else
                                step.skipped[bar.key .. i] = true
                                run.report.failed[#run.report.failed + 1] = {
                                    kind = "skills", label = skillName(id), reason = "rejected" }
                            end
                        else
                            step.skipped[bar.key .. i] = true
                            run.report.failed[#run.report.failed + 1] = {
                                kind = "skills", label = skillName(id), reason = why or "notPurchased" }
                        end
                    end
                end
            end
        end
    end
    step.phase, step.attempts = "verify", 0
    return "wait"
end

STEP.cp = function(run, step)
    local label = L("SI_ACCOUNTHOLD_BUILDEQ_CP", "Champion stars")
    if step.phase == "wait" then
        if step.result ~= nil then
            local success = gnum("CHAMPION_PURCHASE_SUCCESS")
            if success ~= nil and step.result == success then
                run.report.cp = run.report.cp + (step.added or 0)
                BE._cpCooldownUntil = nowMs() + CP_COOLDOWN_MS
                return "next"
            end
            return fail(run, { kind = "cp", label = label }, fmt("result %s", tostring(step.result)))
        end
        step.attempts = (step.attempts or 0) + 1
        if step.attempts >= VERIFY_TICKS * 3 then return fail(run, { kind = "cp", label = label }, "timeout") end
        return "wait"
    end
    local lo = BE:GetLoadout(run.buildId) or {}
    if call("IsChampionSystemUnlocked") == false then
        run.report.notes[#run.report.notes + 1] = L("SI_ACCOUNTHOLD_BUILDEQ_CP_LOCKED", "champion system not unlocked")
        return "next"
    end
    if BE._cpCooldownUntil and nowMs() < BE._cpCooldownUntil then
        return fail(run, { kind = "cp", label = label }, "cooldown")
    end
    local success = gnum("CHAMPION_PURCHASE_SUCCESS")
    local avail = call("GetChampionPurchaseAvailability")
    if success ~= nil and avail ~= nil and avail ~= success then
        return fail(run, { kind = "cp", label = label }, fmt("unavailable (%s)", tostring(avail)))
    end
    if not (gfn("PrepareChampionPurchaseRequest") and gfn("AddHotbarSlotToChampionPurchaseRequest")
            and gfn("SendChampionPurchaseRequest")) then
        return fail(run, { kind = "cp", label = label }, "noApi")
    end
    local NO_RESPEC = false
    call("PrepareChampionPurchaseRequest", NO_RESPEC)
    local added = 0
    local c1, c2 = championRange()
    for i = c1, c2 do
        local id = (lo.cp or {})[i]
        if type(id) == "number" and id > 0 then
            local slottable = starUsable(id)
            if slottable then
                call("AddHotbarSlotToChampionPurchaseRequest", i, id)
                added = added + 1
            else
                local n = call("GetChampionSkillName", id)
                run.report.failed[#run.report.failed + 1] = {
                    kind = "cp", label = (type(n) == "string" and n ~= "") and plainName(n) or fmt("#%d", id),
                    reason = "notPurchased" }
            end
        end
    end
    if added == 0 then return "next" end
    step.added, step.result, step.attempts, step.phase = added, nil, 0, "wait"
    BE._cpWaiting = step
    call("SendChampionPurchaseRequest")
    return "wait"
end

local function secureUse(bag, slot)
    local protected = true
    local isProt = gfn("IsProtectedFunction")
    if isProt then
        local ok, v = pcall(isProt, "UseItem")
        protected = ok and v and true or false
    end
    if protected then
        local csp = gfn("CallSecureProtected")
        if not csp then return false, "CallSecureProtected missing" end
        local ok, res = pcall(csp, "UseItem", bag, slot)
        if not ok then return false, res end
        if res == false then return false, "refused" end
        return true
    end
    local use = gfn("UseItem")
    if not use then return false, "UseItem missing" end
    local ok, err = pcall(use, bag, slot)
    if not ok then return false, err end
    return true
end

STEP.food = function(run, step)
    local label = L("SI_ACCOUNTHOLD_BUILDEQ_FOOD", "Food")
    local bag, slot = findByItemId(step.itemId)
    if bag == nil then return fail(run, { kind = "food", label = label }, "missing") end
    local ok, why = secureUse(bag, slot)
    if not ok then return fail(run, { kind = "food", label = label }, tostring(why)) end
    run.report.food = run.report.food + 1
    return "next"
end

local REASON_TEXT = {
    missing      = { "SI_ACCOUNTHOLD_BUILDEQ_R_MISSING",       "not on this character" },
    timeout      = { "SI_ACCOUNTHOLD_BUILDEQ_R_TIMEOUT",       "the game did not confirm" },
    notPurchased = { "SI_ACCOUNTHOLD_BUILDEQ_R_NOT_PURCHASED", "not learned on this character" },
    unknown      = { "SI_ACCOUNTHOLD_BUILDEQ_R_UNKNOWN",       "not a skill this character has" },
    cooldown     = { "SI_ACCOUNTHOLD_BUILDEQ_R_COOLDOWN",      "on cooldown, try again shortly" },
    noApi        = { "SI_ACCOUNTHOLD_BUILDEQ_R_NOAPI",         "not supported on this client" },
    rejected     = { "SI_ACCOUNTHOLD_BUILDEQ_R_REJECTED",      "the game refused the change" },
}

function BE.FormatReport(run)
    if type(run) ~= "table" or type(run.report) ~= "table" then return "" end
    local r = run.report
    local parts = {}
    if r.gear > 0 then parts[#parts + 1] = fmt(L("SI_ACCOUNTHOLD_BUILDEQ_N_GEAR", "%d gear"), r.gear) end
    if r.skills > 0 then parts[#parts + 1] = fmt(L("SI_ACCOUNTHOLD_BUILDEQ_N_SKILLS", "%d skills"), r.skills) end
    if r.cp > 0 then parts[#parts + 1] = fmt(L("SI_ACCOUNTHOLD_BUILDEQ_N_CP", "%d stars"), r.cp) end
    if r.food > 0 then parts[#parts + 1] = L("SI_ACCOUNTHOLD_BUILDEQ_N_FOOD", "food") end
    local changed = (#parts > 0) and table.concat(parts, ", ") or L("SI_ACCOUNTHOLD_BUILDEQ_NOTHING", "nothing changed")
    if #r.failed == 0 then
        return fmt(L("SI_ACCOUNTHOLD_BUILDEQ_DONE", "Equipped \"%s\" (%s)."), run.name or "?", changed)
    end
    local probs = {}
    for i = 1, math.min(#r.failed, 4) do
        local f = r.failed[i]
        local why = REASON_TEXT[f.reason]
        probs[#probs + 1] = fmt("%s: %s", tostring(f.label), why and L(why[1], why[2]) or tostring(f.reason))
    end
    if #r.failed > 4 then probs[#probs + 1] = fmt(L("SI_ACCOUNTHOLD_BUILDEQ_MORE", "%d more"), #r.failed - 4) end
    return fmt(L("SI_ACCOUNTHOLD_BUILDEQ_DONE_PROBLEMS", "Equipped \"%s\" (%s) with problems - %s."),
        run.name or "?", changed, table.concat(probs, "; "))
end

local function finish(run)
    BE._run = nil
    stopTicker()
    local s = state()
    if s then s.lastEquipped = run.buildId end
    alert(BE.FormatReport(run))
    if run.reason == "export" then
        local p = s and s.pendingExport
        if type(p) == "table" and p.buildId == run.buildId then
            alert(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_NEXT",
                "Now open an Armory Station: Quartermaster will ask to save \"%s\" into Armory slot %d."),
                run.name or "?", p.armoryIndex or 0))
        end
    end
    diag("info", "Equip of %s finished: %d failure(s).", tostring(run.buildId), #run.report.failed)
end

-- One tick. Public so tests (and nothing else) can drive it deterministically.
function BE:Step()
    local run = self._run
    if not run then stopTicker() return end
    if not self:IsEnabled() then
        self._run = nil
        stopTicker()
        alert(L("SI_ACCOUNTHOLD_BUILDEQ_STOPPED_GATE", "Quartermaster stopped equipping: the Armory was switched off."))
        return
    end
    local blocked, why = self:IsBlocked()
    if blocked then
        -- Pause, never push through. Remaining steps are re-planned on resume,
        -- so whatever already landed is not repeated.
        self._run = nil
        stopTicker()
        self._pending = { buildId = run.buildId, reason = run.reason, trigger = run.trigger, resumed = true,
                          skipFood = (run.report.food > 0) or nil }
        alert(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_PAUSED",
            "Paused equipping \"%s\" (%s). It will finish when you are out of combat."), run.name, blockedMessage(why)))
        return
    end
    local step = run.steps[run.i]
    if not step then finish(run) return end
    local handler = STEP[step.kind]
    local res = handler and handler(run, step) or "next"
    if res == "next" then
        run.i = run.i + 1
        if run.steps[run.i] == nil then finish(run) end
    end
end

-- ---------------------------------------------------------------------------
-- Resuming a deferred equip
-- ---------------------------------------------------------------------------

-- A deferred AUTO swap is re-validated before it runs: equipping a boss build
-- after the boss is gone, or a zone build after leaving, helps nobody.
function BE:TriggerStillValid(trigger)
    if type(trigger) ~= "table" then return true end
    local zoneId = self:CurrentZone()
    if trigger.zoneId and zoneId ~= trigger.zoneId then return false end
    if trigger.kind == "boss" then
        for _, n in ipairs(self:CurrentBosses()) do
            if n == trigger.name then return true end
        end
        return false
    elseif trigger.kind == "anyBoss" then
        return #self:CurrentBosses() > 0
    end
    return true
end

function BE:TryResume()
    local p = self._pending
    if not p or not self:IsEnabled() then return false end
    if self:IsBlocked() then return false end
    self._pending = nil
    if p.reason == "auto" and not self:TriggerStillValid(p.trigger) then
        alert(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_STALE",
            "Skipped auto-equip of \"%s\": the fight or zone that triggered it is over."), buildName(p.buildId)))
        return false
    end
    return self:Equip(p.buildId, { reason = p.reason, trigger = p.trigger, resumed = true,
                                   skipFood = p.skipFood }) ~= "refused"
end

function BE:OnCombatState(inCombat)
    if not self:IsEnabled() then return end
    if inCombat then return end
    self:TryResume()
end

function BE:OnPlayerAlive()
    if not self:IsEnabled() then return end
    self:TryResume()
end

function BE:OnChampionResult(result)
    if not self:IsEnabled() then return end
    local step = self._cpWaiting
    if not step then return end
    self._cpWaiting = nil
    step.result = result
end

-- ---------------------------------------------------------------------------
-- Auto-equip rules
-- ---------------------------------------------------------------------------
-- rec.auto = { enabled = false, rules = { { kind = "zone"|"boss"|"anyBoss",
--              zoneId = n, zoneName = s, name = s } } }

local function autoOf(rec, create)
    if type(rec) ~= "table" then return nil end
    if type(rec.auto) ~= "table" then
        if not create then return nil end
        rec.auto = { enabled = false, rules = {} }
    end
    if type(rec.auto.rules) ~= "table" then rec.auto.rules = {} end
    return rec.auto
end
BE._AutoOf = autoOf

function BE:GetAuto(buildId)
    local rec = getBuild(buildId)
    local a = autoOf(rec, false)
    if not a then return { enabled = false, rules = {} } end
    return a
end

function BE:SetAutoEnabled(buildId, on)
    local rec = getBuild(buildId)
    if not rec then return false end
    autoOf(rec, true).enabled = on and true or false
    rec.updatedAt = timestamp()
    return true
end

local function sameRule(a, b)
    return a.kind == b.kind and a.zoneId == b.zoneId and a.name == b.name
end

function BE:AddRule(buildId, rule)
    local rec = getBuild(buildId)
    if not rec or type(rule) ~= "table" then return false end
    if rule.kind ~= "zone" and rule.kind ~= "boss" and rule.kind ~= "anyBoss" then return false end
    if rule.kind ~= "boss" and type(rule.zoneId) ~= "number" then return false end
    if rule.kind == "boss" and (type(rule.name) ~= "string" or rule.name == "") then return false end
    local a = autoOf(rec, true)
    for _, r in ipairs(a.rules) do
        if sameRule(r, rule) then return true end
    end
    if #a.rules >= MAX_RULES then return false end
    a.rules[#a.rules + 1] = { kind = rule.kind, zoneId = rule.zoneId, zoneName = rule.zoneName, name = rule.name }
    rec.updatedAt = timestamp()
    return true
end

function BE:RemoveRule(buildId, index)
    local rec = getBuild(buildId)
    local a = autoOf(rec, false)
    if not a or type(index) ~= "number" or a.rules[index] == nil then return false end
    table.remove(a.rules, index)
    rec.updatedAt = timestamp()
    return true
end

-- Which build should be on right now? Boss rules beat any-boss rules beat zone
-- rules. Two DIFFERENT builds tied at the winning level is ambiguous: nothing
-- is equipped and the player is told, rather than guessing.
function BE:EvaluateAuto(zoneId, bosses)
    if not self:IsEnabled() then return nil end
    local charKey = currentCharKey()
    local bc = model()
    if not bc or not charKey then return nil end
    local okList, list = pcall(bc.ListBuilds, bc)
    if not okList or type(list) ~= "table" then return nil end
    local bossSet = {}
    for _, n in ipairs(bosses or {}) do bossSet[n] = true end
    local hasBoss = next(bossSet) ~= nil

    local best, bestPrio, bestRule, tied = nil, 0, nil, {}
    for _, b in ipairs(list) do
        local rec = getBuild(b.id)
        local a = autoOf(rec, false)
        if rec and a and a.enabled and ownerOf(rec) == charKey and self:HasLoadout(b.id) then
            for _, r in ipairs(a.rules) do
                local prio = 0
                if r.kind == "boss" and bossSet[r.name] and (r.zoneId == nil or r.zoneId == zoneId) then
                    prio = 3
                elseif r.kind == "anyBoss" and hasBoss and r.zoneId == zoneId then
                    prio = 2
                elseif r.kind == "zone" and not hasBoss and r.zoneId == zoneId then
                    prio = 1
                end
                if prio > bestPrio then
                    best, bestPrio, bestRule, tied = b.id, prio, r, { [tostring(b.id)] = b.name }
                elseif prio > 0 and prio == bestPrio and best ~= b.id then
                    tied[tostring(b.id)] = b.name
                end
            end
        end
    end
    if not best then return nil end
    local names = {}
    for _, n in pairs(tied) do names[#names + 1] = n end
    if #names > 1 then
        table.sort(names)
        return nil, nil, names
    end
    return best, bestRule
end

local function autoEquip(self, zoneId, bosses, why)
    local buildId, rule, ambiguous = self:EvaluateAuto(zoneId, bosses)
    if ambiguous then
        local key = table.concat(ambiguous, "|")
        if self._lastAmbiguous ~= key then
            self._lastAmbiguous = key
            alert(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_AMBIGUOUS",
                "Auto-equip skipped: more than one build matches here (%s). Remove a condition so only one does."),
                table.concat(ambiguous, ", ")))
        end
        return nil
    end
    self._lastAmbiguous = nil
    if not buildId then return nil end
    if self._run and self._run.buildId == buildId then return nil end
    if self._pending and self._pending.buildId == buildId then return nil end
    -- Already wearing it (by any route): record it, say nothing, change nothing.
    if self:IsEquipped(buildId) then
        local s = state()
        if s then s.lastEquipped = buildId end
        return nil
    end
    local trigger = { kind = rule.kind, zoneId = rule.zoneId, name = rule.name }
    alert(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_AUTO", "Auto-equip: \"%s\" (%s)."), buildName(buildId), why))
    return self:Equip(buildId, { reason = "auto", trigger = trigger })
end

function BE:CheckZone(zoneId)
    if not self:IsEnabled() then return nil end
    if type(zoneId) ~= "number" then zoneId = self:CurrentZone() end
    if type(zoneId) ~= "number" or zoneId == self._lastZoneId then return nil end
    self._lastZoneId = zoneId
    local _, name = self:CurrentZone()
    return autoEquip(self, zoneId, self:CurrentBosses(),
        fmt(L("SI_ACCOUNTHOLD_BUILDEQ_WHY_ZONE", "entered %s"), plainName(name or "")))
end

function BE:OnPlayerActivated()
    if not self:IsEnabled() then return end
    self._lastZoneId = nil
    self:CheckZone(nil)
end

function BE:OnZoneChanged(_zoneName, _subZoneName, _newSubzone, zoneId)
    if not self:IsEnabled() then return end
    self:CheckZone(zoneId)
end

function BE:OnBossesChanged()
    if not self:IsEnabled() then return nil end
    local bosses = self:CurrentBosses()
    local key = table.concat(bosses, "|")
    if key == self._lastBossKey then return nil end
    self._lastBossKey = key
    local zoneId = self:CurrentZone()
    local why
    if #bosses > 0 then
        why = fmt(L("SI_ACCOUNTHOLD_BUILDEQ_WHY_BOSS", "%s appeared"), plainName(bosses[1]))
    else
        why = L("SI_ACCOUNTHOLD_BUILDEQ_WHY_BOSS_GONE", "boss fight over")
    end
    return autoEquip(self, zoneId, bosses, why)
end

-- ---------------------------------------------------------------------------
-- Food
-- ---------------------------------------------------------------------------

function BE:ListFood()
    local pack = gnum("BAG_BACKPACK")
    local food, drink = gnum("ITEMTYPE_FOOD"), gnum("ITEMTYPE_DRINK")
    local out, seen = {}, {}
    if not pack or (not food and not drink) then return out end
    local size = call("GetBagSize", pack) or 0
    for s = 0, size - 1 do
        local t = call("GetItemType", pack, s)
        if t ~= nil and (t == food or t == drink) then
            local id = itemIdAt(pack, s)
            if id and not seen[id] then
                seen[id] = true
                local link = linkAt(pack, s)
                local name = link and call("GetItemLinkName", link) or call("GetItemName", pack, s)
                out[#out + 1] = { itemId = id, link = link,
                                  name = plainName((type(name) == "string" and name ~= "") and name or fmt("#%d", id)) }
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function BE:SetFood(buildId, itemId, link, name)
    local rec = getBuild(buildId)
    if not rec then return false end
    if type(rec.loadout) ~= "table" then rec.loadout = { capturedAt = timestamp(), gear = {}, skills = {}, cp = {} } end
    if itemId == nil then
        rec.loadout.food = nil
    else
        rec.loadout.food = { itemId = itemId, link = link, name = name }
    end
    rec.updatedAt = timestamp()
    return true
end

-- ---------------------------------------------------------------------------
-- Describing a loadout (for the Armory screen)
-- ---------------------------------------------------------------------------

function BE:DescribeLoadout(buildId)
    local lo = self:GetLoadout(buildId)
    if not lo then return nil end
    local d = { bars = {}, cp = {}, gearSaved = 0, gearHere = 0, missing = {}, food = nil }
    local first, last = skillRange()
    for _, bar in ipairs(BARS) do
        local names = {}
        local t = (lo.skills or {})[bar.key]
        if type(t) == "table" then
            for i = first, last do
                if type(t[i]) == "number" and t[i] ~= 0 then names[#names + 1] = skillName(t[i]) end
            end
        end
        d.bars[bar.key] = names
    end
    local c1, c2 = championRange()
    for i = c1, c2 do
        local id = (lo.cp or {})[i]
        if type(id) == "number" and id ~= 0 then
            local n = call("GetChampionSkillName", id)
            d.cp[#d.cp + 1] = (type(n) == "string" and n ~= "") and plainName(n) or fmt("#%d", id)
        end
    end
    for _, r in ipairs(resolvedGearSlots()) do
        local want = (lo.gear or {})[r.def.name]
        if type(want) == "table" and not want.empty then
            d.gearSaved = d.gearSaved + 1
            local here
            if r.def.stack then here = want.itemId and findByItemId(want.itemId) ~= nil
                or itemIdAt(gnum("BAG_WORN"), r.equipSlot) == want.itemId
            else here = findByUid(want.uid) ~= nil end
            if here then d.gearHere = d.gearHere + 1 else d.missing[#d.missing + 1] = slotLabel(r.def) end
        end
    end
    if type(lo.food) == "table" then
        local n = lo.food.name or (lo.food.link and call("GetItemLinkName", lo.food.link))
        d.food = plainName((type(n) == "string" and n ~= "") and n or fmt("#%s", tostring(lo.food.itemId)))
    end
    return d
end

-- ---------------------------------------------------------------------------
-- Export to the in-game Armory (see the header for why it works this way)
-- ---------------------------------------------------------------------------

BE.EXPORT_DIALOG = "ACCOUNTHOLD_ARMORY_EXPORT_CONFIRM"

function BE:GetPendingExport()
    local s = state()
    local p = s and s.pendingExport
    if type(p) == "table" and p.buildId ~= nil then return p end
    return nil
end

function BE:CancelExport()
    local s = state()
    if s then s.pendingExport = nil end
    self._awaitSave = nil
    return true
end

function BE:RequestExport(buildId, armoryIndex)
    if not self:IsEnabled() then
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_DISABLED", "The Quartermaster Armory is switched off."),
            "RequestExport refused: gate off.")
    end
    local n = call("GetNumUnlockedArmoryBuilds")
    if type(armoryIndex) ~= "number" or armoryIndex < 1 or type(n) ~= "number" or armoryIndex > n then
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_BAD_SLOT", "That Armory slot is not unlocked on this character."),
            "RequestExport: bad Armory slot %s (unlocked %s).", tostring(armoryIndex), tostring(n))
    end
    local rec = getBuild(buildId)
    if not rec or not self:HasLoadout(buildId) then
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_NO_LOADOUT",
            "Save a loadout to this build first - the Armory stores what you are wearing."),
            "RequestExport: build %s has no loadout.", tostring(buildId))
    end
    if not ownedHere(rec) then
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_OTHER_CHAR",
            "That build belongs to another character. Assign it to this character first."),
            "RequestExport: build %s owned elsewhere.", tostring(buildId))
    end
    local s = state()
    if not s then return false end
    local slotName = call("GetArmoryBuildName", armoryIndex)
    s.pendingExport = { buildId = buildId, armoryIndex = armoryIndex,
                        armoryName = (type(slotName) == "string" and slotName ~= "") and slotName or nil,
                        at = timestamp() }
    local status = self:Equip(buildId, { reason = "export" })
    if status == "already" then
        alert(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_NEXT",
            "Now open an Armory Station: Quartermaster will ask to save \"%s\" into Armory slot %d."),
            rec.name or "?", armoryIndex))
    end
    return status ~= "refused", status
end

local function ensureExportDialog()
    if BE._exportDialogRegistered then return true end
    local reg = gfn("ZO_Dialogs_RegisterCustomDialog")
    if not reg then return false end
    local basic = 1
    local okB, b = pcall(function() return GAMEPAD_DIALOGS.BASIC end)
    if okB and b ~= nil then basic = b end
    local ok = pcall(reg, BE.EXPORT_DIALOG, {
        canQueue    = true,
        gamepadInfo = { dialogType = basic },
        title       = { text = L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_TITLE", "Save to the Armory") },
        mainText    = {
            text = function(dialog)
                local ok2, text = pcall(function()
                    local d = (dialog and dialog.data) or {}
                    return fmt(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_BODY",
                        "Save the Quartermaster build \"%s\" into Armory slot %d (%s)? This replaces what is saved in that slot."),
                        tostring(d.name or "?"), tonumber(d.armoryIndex) or 0, tostring(d.armoryName or "-"))
                end)
                if ok2 and type(text) == "string" then return text end
                return L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_TITLE", "Save to the Armory")
            end,
        },
        buttons = {
            {
                text     = L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_SAVE", "Save"),
                keybind  = "DIALOG_PRIMARY",
                callback = function(dialog)
                    local okC, err = pcall(BE.ConfirmExport, BE, dialog and dialog.data)
                    if not okC then
                        diag("error", "ConfirmExport failed: %s", tostring(err))
                        alert(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_FAILED", "Saving to the Armory failed. Nothing was changed."))
                    end
                end,
            },
            {
                text    = L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_LATER", "Not now"),
                keybind = "DIALOG_NEGATIVE",
            },
            {
                text     = L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_FORGET", "Forget export"),
                keybind  = "DIALOG_SECONDARY",
                callback = function()
                    pcall(BE.CancelExport, BE)
                    alert(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_FORGOTTEN", "Export cancelled. Nothing was saved."))
                end,
            },
        },
    })
    BE._exportDialogRegistered = ok and true or false
    return BE._exportDialogRegistered
end
BE._EnsureExportDialog = ensureExportDialog

function BE:OfferExport()
    local p = self:GetPendingExport()
    if not p then return false end
    local name = buildName(p.buildId)
    if not getBuild(p.buildId) then
        self:CancelExport()
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_NO_BUILD", "That build no longer exists."),
            "OfferExport: pending build %s is gone.", tostring(p.buildId))
    end
    if self._run then
        return refuse(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_BUSY",
            "Quartermaster is still equipping \"%s\". Reopen the Armory Station when it has finished."), name),
            "OfferExport: equip still running.")
    end
    local equipped, diff = self:IsEquipped(p.buildId)
    if not equipped then
        return refuse(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_NOT_ON",
            "\"%s\" is not fully equipped (%d difference(s)), so it was not offered for the Armory. Equip it from the Quartermaster Armory first."),
            name, diff or 0), "OfferExport: build %s not equipped (%s diffs).", tostring(p.buildId), tostring(diff))
    end
    if not ensureExportDialog() then
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_NO_DIALOG",
            "This client could not show the Armory save prompt. Use Save Build (Y) on the Armory Station instead."),
            "OfferExport: dialog registration unavailable.")
    end
    local data = { buildId = p.buildId, name = name, armoryIndex = p.armoryIndex,
                   armoryName = p.armoryName or call("GetArmoryBuildName", p.armoryIndex) }
    local show = gfn("ZO_Dialogs_ShowGamepadDialog") or gfn("ZO_Dialogs_ShowDialog")
    if not show then
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_NO_DIALOG",
            "This client could not show the Armory save prompt. Use Save Build (Y) on the Armory Station instead."),
            "OfferExport: no dialog show function.")
    end
    local ok, err = pcall(show, BE.EXPORT_DIALOG, data)
    if not ok then
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_NO_DIALOG",
            "This client could not show the Armory save prompt. Use Save Build (Y) on the Armory Station instead."),
            "OfferExport: show failed: %s", tostring(err))
    end
    return true
end

function BE:OnArmoryMenuOpened()
    if not self:IsEnabled() or not self:GetPendingExport() then return end
    -- Let the native Armory scene finish showing first; a dialog requested
    -- mid-transition can be dropped (zo_dialog.lua:356-377).
    local later = gfn("zo_callLater")
    if later then
        later(function()
            local ok, err = pcall(BE.OfferExport, BE)
            if not ok then
                diag("error", "OfferExport failed: %s", tostring(err))
                alert(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_FAILED", "Saving to the Armory failed. Nothing was changed."))
            end
        end, 600)
    else
        self:OfferExport()
    end
end

function BE:ConfirmExport(data)
    local p = self:GetPendingExport()
    if not p or type(data) ~= "table" or data.buildId ~= p.buildId then
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_STALE", "That export is no longer pending. Nothing was saved."),
            "ConfirmExport: stale data.")
    end
    if self:IsBlocked() then
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_COMBAT", "You cannot save to the Armory in combat."),
            "ConfirmExport: blocked.")
    end
    local remaining = call("GetArmoryOperationsCooldownRemaining")
    if type(remaining) == "number" and remaining > 0 then
        return refuse(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_COOLDOWN",
            "The Armory is on cooldown for %d more second(s). Try again then."), math.ceil(remaining / 1000)),
            "ConfirmExport: Armory cooldown %s ms.", tostring(remaining))
    end
    local save = gfn("SaveArmoryBuild")
    if not save then
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_NO_API", "This client has no Armory save function. Nothing was saved."),
            "ConfirmExport: SaveArmoryBuild missing.")
    end
    local ok, err = pcall(save, p.armoryIndex)
    if not ok then
        return refuse(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_FAILED", "Saving to the Armory failed. Nothing was changed."),
            "ConfirmExport: SaveArmoryBuild threw: %s", tostring(err))
    end
    self._awaitSave = p.armoryIndex
    diag("info", "SaveArmoryBuild(%d) sent for build %s.", p.armoryIndex, tostring(p.buildId))
    return true
end

local SAVE_RESULTS = {
    { "ARMORY_BUILD_SAVE_RESULT_NO_INTERACTION",  "SI_ACCOUNTHOLD_BUILDEQ_SAVE_NO_INTERACTION", "you must be at an Armory Station" },
    { "ARMORY_BUILD_SAVE_RESULT_IN_COMBAT",       "SI_ACCOUNTHOLD_BUILDEQ_SAVE_IN_COMBAT",      "you are in combat" },
    { "ARMORY_BUILD_SAVE_RESULT_COOLDOWN",        "SI_ACCOUNTHOLD_BUILDEQ_SAVE_COOLDOWN",       "the Armory is on cooldown" },
    { "ARMORY_BUILD_SAVE_RESULT_BUSY",            "SI_ACCOUNTHOLD_BUILDEQ_SAVE_BUSY",           "another Armory operation is running" },
    { "ARMORY_BUILD_SAVE_RESULT_IN_WEREWOLF_FORM","SI_ACCOUNTHOLD_BUILDEQ_SAVE_WEREWOLF",       "you are a werewolf" },
}

function BE.DescribeSaveResult(result)
    for _, r in ipairs(SAVE_RESULTS) do
        local v = gnum(r[1])
        if v ~= nil and v == result then return L(r[2], r[3]) end
    end
    return fmt(L("SI_ACCOUNTHOLD_BUILDEQ_SAVE_CODE", "result code %s"), tostring(result))
end

function BE:OnArmorySaveResponse(result, buildIndex)
    if not self:IsEnabled() then return end
    if self._awaitSave == nil or buildIndex ~= self._awaitSave then return end
    self._awaitSave = nil
    local p = self:GetPendingExport()
    local success = gnum("ARMORY_BUILD_SAVE_RESULT_SUCCESS")
    if success ~= nil and result == success then
        local name = p and buildName(p.buildId) or "?"
        self:CancelExport()
        alert(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_DONE", "Saved \"%s\" into Armory slot %d."), name, buildIndex))
        return true
    end
    alert(fmt(L("SI_ACCOUNTHOLD_BUILDEQ_EXPORT_REFUSED",
        "The Armory did not save the build: %s. The export is still pending."), BE.DescribeSaveResult(result)))
    diag("warn", "SaveArmoryBuild(%d) refused: %s", buildIndex, tostring(result))
    return false
end

return BE
