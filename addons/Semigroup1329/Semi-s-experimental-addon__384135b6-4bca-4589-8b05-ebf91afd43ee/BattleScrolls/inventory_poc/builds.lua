if not SemisPlaygroundCheckAccess() then return end

---@alias InventoryPocBuildChoice 'healer'|'damage'|'pvp'
---@alias InventoryPocBuildStatus 'bank'|'armory'|'wardrobe'|'done'|'paused'|'missing'
---@class InventoryPocBuildProfile
---@field id InventoryPocBuildChoice
---@field label number
---@field armoryName string
---@field armoryIndex number
---@field pageName string
---@class InventoryPocBuildMemory
---@field name string
---@field gear table<number, string>
---@alias InventoryPocBuildIssueKind 'gear'|'skill'|'champion'|'food'|'selector'|'interrupted'
---@class InventoryPocBuildIssue
---@field kind InventoryPocBuildIssueKind
---@field slot number|nil
---@field bar HotBarCategory|nil
---@field expected string|number|nil
---@field actual string|number|nil
---@class InventoryPocBuildState
---@field choice InventoryPocBuildChoice|nil
---@field status InventoryPocBuildStatus
---@field armoryDone boolean
---@field armory table<number, InventoryPocBuildMemory>
---@field applying boolean|nil
---@field issue InventoryPocBuildIssue|nil Last mismatch, retained if the switch times out
---@class InventoryPocBuildRequest
---@field kind 'armory'|'wardrobe'
---@field started number
---@field armoryIndex number
---@field page number
---@field setup InventoryPocWardrobeSetup|nil
---@field sawSelector boolean
---@field base table<number, string>
---@field expectedGear table<number, string>|nil
---@class InventoryPocBuilds
---@field profiles InventoryPocBuildProfile[]
---@field request InventoryPocBuildRequest|nil
---@field registered boolean
---@field ownRequest boolean
---@field moving table<string, boolean>
local builds = {
    profiles = {
        { id = 'healer', label = BATTLESCROLLS_IPOC_HEALER, armoryName = 'hehehealer', armoryIndex = 5, pageName = 'Page 18' },
        { id = 'damage', label = BATTLESCROLLS_IPOC_DAMAGE, armoryName = 'PvE', armoryIndex = 2, pageName = 'Reaving DD' },
        { id = 'pvp', label = BATTLESCROLLS_IPOC_PVP, armoryName = 'PvP', armoryIndex = 4, pageName = 'Page 18' },
    },
    registered = false, ownRequest = false, moving = {},
}
BattleScrolls.inventoryPocBuilds = builds
local poc = BattleScrolls.inventoryPoc
local facts = BattleScrolls.inventoryPocFacts
local EVENT_NAME = 'BattleScrollsInventoryPocBuilds'
-- Healers Haven's gearing-up pages, checked 2026-10-18. Includes situational
-- and beginner healer choices, named support alternatives, and perfected
-- variants. Sources and LibSets' numeric ID mapping are in research.md.
local HEALER_SETS = {
    -- Main and special sets.
    [185] = true, -- Spell Power Cure
    [180] = true, -- Powerful Assault
    [649] = true, [650] = true, -- Pillager's Profit / Perfected
    [496] = true, [497] = true, -- Roaring Opportunist / Perfected
    [346] = true, -- Jorvuld's Guidance
    [332] = true, -- Master Architect
    [331] = true, -- War Machine
    [769] = true, [770] = true, -- Xoryn's Masterpiece / Perfected
    [147] = true, -- Way of Martial Knowledge
    [516] = true, -- Elemental Catalyst
    [455] = true, -- Z'en's Redress
    [585] = true, [589] = true, -- Saxhleel Champion / Perfected
    [391] = true, [395] = true, -- Vestment of Olorime / Perfected
    [50] = true, -- The Morag Tong
    [641] = true, -- Serpent's Disdain
    [281] = true, -- Armor of the Trainee
    [642] = true, -- Druid's Braid
    [128] = true, -- Blessing of the Potentates
    -- Monster sets and support alternatives mentioned alongside them.
    [633] = true, -- Nazaray
    [687] = true, -- Ozezan the Inferno
    [436] = true, -- Symphony of Blades
    [666] = true, -- Archdruid Devyric
    [738] = true, -- The Blind
    [577] = true, -- Encratis's Behemoth
    [609] = true, -- Magma Incarnate (one piece with Spaulder)
    [622] = true, -- Turning Tide
    [634] = true, -- Nunatak
    -- Mythics.
    [627] = true, -- Spaulder of Ruin
    [691] = true, -- Cryptcanon Vestments
    [576] = true, -- Pearls of Ehlnofey
    [596] = true, -- Death Dealer's Fete
    [625] = true, -- Markyn Ring of Majesty
    [503] = true, -- Ring of the Wild Hunt
    -- Arena weapons, normal and perfected.
    [318] = true, [533] = true, -- Grand Rejuvenation (Master restoration)
    [416] = true, [428] = true, -- Mender's Ward (Blackrose restoration)
    [368] = true, [362] = true, -- Timeless Blessing (Asylum restoration)
    [374] = true, [527] = true, -- Precise Regeneration (Maelstrom restoration)
    [373] = true, [526] = true, -- Crushing Wall (Maelstrom destruction)
    -- Beginner healer sets.
    [468] = true, -- Daring Corsair
    [610] = true, -- Wretched Vitality
    [696] = true, -- Telvanni Efficiency
    [92] = true, -- Kagrenac's Hope
    [167] = true, -- Nightflame
    [268] = true, -- Sentinel of Rkugamz
}

---@return InventoryPocWardrobe|nil
local function wardrobe()
    return rawget(_G, 'WizardsWardrobe')
end

---@return InventoryPocBuildState|nil
function builds.state()
    if not poc.enabled or not poc.saved or facts.crafterId() ~= GetCurrentCharacterId() then return nil end
    local id = GetCurrentCharacterId()
    if not poc.saved.builds[id] then
        poc.saved.builds[id] = { status = 'done', armoryDone = false, armory = {} }
    end
    return poc.saved.builds[id]
end

---@return InventoryPocBuildProfile|nil
local function profile()
    local state = builds.state()
    if state then
        for _, entry in ipairs(builds.profiles) do if entry.id == state.choice then return entry end end
    end
end

---@param state InventoryPocBuildState
---@param kind InventoryPocBuildIssueKind|nil
---@param slot number|nil
---@param bar HotBarCategory|nil
---@param expected string|number|nil
---@param actual string|number|nil
local function setIssue(state, kind, slot, bar, expected, actual)
    local old = state.issue
    if not old and not kind then return end
    if old and old.kind == kind and old.slot == slot and old.bar == bar
        and old.expected == expected and old.actual == actual then return end
    state.issue = kind and { kind = kind, slot = slot, bar = bar, expected = expected, actual = actual } or nil
    poc.revision = poc.revision + 1
end

---@param result 'done'|'uncertain'
---@param setupName string|nil
local function log(result, setupName)
    local selected, state = profile(), builds.state()
    if not selected or not state then return end
    poc.appendLog({ timestamp = GetTimeStamp(), character = GetUnitName('player'), action = 'keep',
        result = result, itemLink = '', itemId = 0, quantity = 0, fromBag = BAG_WORN,
        buildName = selected.armoryName, setupName = setupName,
        buildIssue = result == 'uncertain' and state.issue or nil })
end

function builds.stop()
    poc.wake()
    local state = builds.state()
    if builds.request and state then
        state.status, state.applying = 'paused', nil
        setIssue(state, 'interrupted')
        log('uncertain')
    end
    builds.request, builds.moving = nil, {}
end

---@param choice InventoryPocBuildChoice
function builds.choose(choice)
    local state = builds.state()
    if not state or builds.request then return end
    for _, entry in ipairs(builds.profiles) do
        if entry.id == choice then
            state.choice, state.armoryDone, state.status = choice, false, 'bank'
            setIssue(state, nil)
            poc.wake()
            return
        end
    end
end

---@param item InventoryPocItem
---@param toBackpack boolean
---@return boolean
function builds.canMove(item, toBackpack)
    local source = toBackpack and (item.bag == BAG_BANK or item.bag == BAG_SUBSCRIBER_BANK) or item.bag == BAG_BACKPACK
    return source and builds.moving[item.uniqueId] == toBackpack
end

---@param state InventoryPocBuildState
local function captureArmory(state)
    for _, build in ipairs(facts.armory()) do
        local memory = state.armory[build.index]
        if not memory or zo_strlower(memory.name) ~= zo_strlower(build.name) then
            memory = { name = build.name, gear = {} }; state.armory[build.index] = memory
        end
        memory.name = build.name
        for _, item in ipairs(build.gear) do
            if item.state == ARMORY_BUILD_EQUIP_SLOT_STATE_EMPTY then memory.gear[item.equipSlot] = nil
            elseif item.uniqueId and item.uniqueId ~= '0' and item.link ~= '' then
                memory.gear[item.equipSlot] = item.uniqueId
            end
        end
    end
end

---@param ww InventoryPocWardrobe
---@param name string
---@return number|nil
local function pageId(ww, name)
    name = zo_strlower(name)
    local found
    for id, page in pairs(ww.pages.SUB or {}) do
        if id > 0 and zo_strlower(page.name) == name then
            if found then return nil end -- Ambiguous names must not select a random page.
            found = id
        end
    end
    return found
end

---@param item InventoryPocItem
---@return boolean
local function healerExtra(item)
    if item.kind ~= 'gear' or not IsItemPlayerLocked(item.bag, item.slot) then return false end
    local _, _, _, _, _, setId = GetItemLinkSetInfo(item.link, false)
    return HEALER_SETS[setId] == true
end

---@param gear table<number, string>
---@return boolean
local function wornMatches(gear)
    for slot, id in pairs(gear) do
        if Id64ToString(GetItemUniqueId(BAG_WORN, slot)) ~= id then return false end
    end
    return true
end

---@param setup InventoryPocWardrobeSetup|nil
---@return boolean
local function emptySetup(setup)
    if not setup then return true end
    if next(setup.gear or {}) or next(setup.cp or {}) or next(setup.food or {}) or (setup.code and setup.code ~= '') then return false end
    for _, slots in pairs(setup.skills or {}) do if next(slots) then return false end end
    return true
end

---@param setup InventoryPocWardrobeSetup|nil
---@param ww InventoryPocWardrobe
---@return table<number, string>
local function wardrobeGear(setup, ww)
    local gear = {}
    if emptySetup(setup) or not ww.settings.auto.gear then return gear end
    for _, slot in ipairs(facts.gearSlots) do
        local ref = setup.gear[slot]
        if ref and ref.id and ref.id ~= '0' then gear[slot] = ref.id
        elseif ref and ww.settings.unequipEmpty then gear[slot] = '0' end
    end
    for _, pair in ipairs({ { EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND }, { EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF } }) do
        local ref = setup.gear[pair[1]]
        if ref and ref.link ~= '' and GetItemLinkEquipType(ref.link) == EQUIP_TYPE_TWO_HAND then gear[pair[2]] = '0' end
    end
    return gear
end

---@param request InventoryPocBuildRequest
---@param ww InventoryPocWardrobe
---@return InventoryPocBuildIssueKind|nil kind
---@return number|nil slot
---@return HotBarCategory|nil bar
---@return string|number|nil expected
---@return string|number|nil actual
local function wardrobeMismatch(request, ww)
    for slot, id in pairs(request.expectedGear or request.base) do
        local actual = Id64ToString(GetItemUniqueId(BAG_WORN, slot))
        if actual ~= id then return 'gear', slot, nil, id, actual end
    end
    local setup = request.setup
    if setup and ww.settings.auto.skills then
        for bar, slots in pairs(setup.skills or {}) do
            for slot, id in pairs(slots) do
                -- WW stores effective ability IDs. GetSlotBoundId instead gives
                -- a crafted-ability ID for scribed skills; WW's helper converts it.
                local actual = ww.GetSlotBoundAbilityId(slot, bar)
                local cryptcanon = id == 195031 or (slot == 8 and ww.HasCryptCanon())
                if not cryptcanon and (id > 0 or ww.settings.unequipEmpty) and not ww.AreSkillsEqual(id, actual) then
                    return 'skill', slot, bar, id, actual
                end
            end
        end
    end
    if setup and ww.settings.auto.cp then
        for slot, id in pairs(setup.cp or {}) do
            local actual = GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION)
            if (id > 0 or ww.settings.unequipEmpty) and actual ~= id then return 'champion', slot, nil, id, actual end
        end
    end
    if setup and ww.settings.auto.food and setup.food and type(setup.food.id) == 'number' then
        local buff = ww.BUFFFOOD[setup.food.id]
        local actual = ww.HasFoodRunning()
        if not buff or actual ~= buff then return 'food', nil, nil, buff or 0, actual or 0 end
    end
end

---A transition owns inventory work only while Armory/WW is actually applying.
---The selected bundle stays bankable after completion without re-equipping it.
---@param reserved table<string, boolean>
---@param pass InventoryPocPass|nil
---@return boolean
function builds.step(reserved, pass)
    local state, selected = builds.state(), profile()
    if not state or not selected then return false end
    if IsUnitInCombat('player') or IsUnitDead('player') then return builds.request ~= nil end
    local ww = wardrobe()
    local request = builds.request
    if request then
        if request.kind == 'wardrobe' and ww and request.sawSelector then
            local kind, slot, bar, expected, actual = wardrobeMismatch(request, ww)
            setIssue(state, kind, slot, bar, expected, actual)
            if not kind then
                state.status, state.applying = 'done', nil
                log('done', request.setup and request.setup.name or selected.pageName)
                builds.request = nil
                poc.dirty = true
                return false
            end
        end
        if GetFrameTimeMilliseconds() - request.started > 90000 then
            state.status, state.applying = 'paused', nil
            log('uncertain', request.setup and request.setup.name)
            builds.request = nil
            poc.dirty = true
            return false
        end
        return true
    end
    if not poc.dirty then return false end
    if state.status == 'paused' then return false end
    if not ww or not ww.conditions or not ww.gui or not ww.pages or not ww.setups then state.status = 'missing'; return false end
    local page = pageId(ww, selected.pageName)
    local setups = page and ww.setups.SUB and ww.setups.SUB[page]
    if not page or not setups or not ww.pages.SUB[0] or not ww.zones.SUB then state.status = 'missing'; return false end
    captureArmory(state)
    local base = state.armory[selected.armoryIndex]
    if zo_strlower(GetArmoryBuildName(selected.armoryIndex)) ~= zo_strlower(selected.armoryName) or not base then
        state.status = 'missing'; return false
    end
    local wanted, all, carried = {}, {}, {}
    for id in pairs(reserved) do all[id] = true end
    for _, memory in pairs(state.armory) do for _, id in pairs(memory.gear) do all[id] = true end end
    for _, id in pairs(base.gear) do wanted[id] = true end
    for _, setup in pairs(setups) do for slot, ref in pairs(setup.gear or {}) do
        if type(slot) == 'number' and type(ref) == 'table' and ref.id and ref.id ~= '0' then wanted[ref.id] = true end
    end end
    local backpack = pass and pass.backpack or facts.bag(BAG_BACKPACK, reserved)
    local worn = pass and pass.worn or facts.bag(BAG_WORN, reserved)
    if pass then pass.worn = worn end
    for _, item in ipairs(worn) do carried[item.uniqueId] = true end
    for _, item in ipairs(backpack) do carried[item.uniqueId] = true end
    local bankOpen = IsBankOpen() and (GetBankingBag() == BAG_BANK or GetBankingBag() == BAG_SUBSCRIBER_BANK)
    local bank = pass and pass.bank or {}
    if bankOpen and not (pass and pass.bank) then
        local bags = IsESOPlusSubscriber() and { BAG_BANK, BAG_SUBSCRIBER_BANK } or { BAG_BANK }
        for _, bag in ipairs(bags) do for _, item in ipairs(facts.bag(bag, reserved)) do bank[#bank + 1] = item end end
        if pass then pass.bank = bank end
    end
    for _, list in ipairs({ backpack, bank }) do for _, item in ipairs(list) do
        if healerExtra(item) then
            all[item.uniqueId] = true
            if selected.id == 'healer' then wanted[item.uniqueId] = true end
        end
    end end
    builds.moving = {}
    if bankOpen then
        -- Make room first; worn items are never unequipped just to bank them.
        for _, item in ipairs(backpack) do
            if all[item.uniqueId] and not wanted[item.uniqueId] then
                builds.moving[item.uniqueId] = false
                if poc.moveBuildItem(item, false) then return true end
            end
        end
        for _, item in ipairs(bank) do
            if wanted[item.uniqueId] then
                builds.moving[item.uniqueId] = true
                if poc.moveBuildItem(item, true) then return true end
            end
        end
    end
    if state.status == 'done' then return false end
    local complete = true
    for id in pairs(wanted) do if not carried[id] then complete = false; break end end
    -- A never-observed missing Armory slot cannot silently disappear from the
    -- bundle just because its exact ID has not been captured yet.
    for _, slot in ipairs(facts.gearSlots) do
        local slotState = GetArmoryBuildEquipSlotInfo(selected.armoryIndex, slot)
        if slotState ~= ARMORY_BUILD_EQUIP_SLOT_STATE_EMPTY and not base.gear[slot] then complete = false end
    end
    if not state.armoryDone or (complete and state.status == 'armory') then
        if GetInteractionType() == INTERACTION_ARMORY then
            builds.request = { kind = 'armory', started = GetFrameTimeMilliseconds(),
                armoryIndex = selected.armoryIndex, page = page, base = base.gear, sawSelector = false }
            state.applying = true
            setIssue(state, nil)
            builds.ownRequest = true
            RestoreArmoryBuild(selected.armoryIndex)
            builds.ownRequest = false
            return true
        end
        state.status = complete and 'armory' or 'bank'
        return false
    end
    if not complete then state.status = 'bank'; return false end
    local interaction = GetInteractionType()
    if (interaction ~= INTERACTION_NONE and interaction ~= INTERACTION_ARMORY) or IsPlayerMoving() then state.status = 'wardrobe'; return false end
    LibEffect.Yield():Await()
    ww.pages.SUB[0].selected = page
    ww.gui.OnZoneSelect(ww.zones.SUB)
    -- WW's event wrapper caches the last boss name. Calling its substitute
    -- selector directly permits a page change while the boss stays the same.
    -- WW still chooses the setup and applies its existing substitute settings.
    local bossName = GetUnitName('boss1')
    if bossName == '' then bossName = GetUnitName('boss2') end
    request = { kind = 'wardrobe', started = GetFrameTimeMilliseconds(), armoryIndex = selected.armoryIndex,
        page = page, base = base.gear, sawSelector = false }
    builds.request = request
    state.status, state.applying = 'wardrobe', true
    setIssue(state, nil)
    builds.ownRequest = true
    ww.conditions.LoadSubstitute(bossName)
    builds.ownRequest = false
    if not request.sawSelector then
        -- WW may disable substitutes in this zone. Do not claim it equipped.
        builds.request = nil
        state.status, state.applying = 'paused', nil
        setIssue(state, 'selector')
        log('uncertain')
    end
    return builds.request ~= nil
end

function builds.initialize()
    if builds.registered then return end
    builds.registered = true
    local current = builds.state()
    if current and current.applying then
        current.status, current.applying = 'paused', nil
        setIssue(current, 'interrupted')
        log('uncertain')
    end
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_ARMORY_BUILD_RESTORE_RESPONSE, function(_, result, index)
        local request, state = builds.request, builds.state()
        if not state or not request or request.kind ~= 'armory' or request.armoryIndex ~= index then return end
        builds.request = nil
        state.applying = nil
        if result == ARMORY_BUILD_RESTORE_RESULT_SUCCESS then
            state.armoryDone, state.status = true, 'bank'
            log('done')
        else state.status = 'paused'; log('uncertain') end
        poc.wake()
    end)
    ZO_PreHook('RestoreArmoryBuild', function()
        if poc.enabled and not builds.ownRequest then
            local state = builds.state()
            if state and state.choice then builds.stop(); state.status = 'paused' end
        end
    end)
    local ww = wardrobe()
    if ww then
        -- A reservation edit can happen without an inventory slot changing.
        -- Invalidate a paced cleanup pass before the saved equipment changes.
        if ww.SaveGear then ZO_PreHook(ww, 'SaveGear', poc.wake) end
        ZO_PreHook(ww, 'LoadSetup', function(zone, page, index, auto)
            if not builds.ownRequest and not auto then poc.wake() end
            local state, request = builds.state(), builds.request
            if not state then return end
            if not request then
                local selected = profile()
                if selected and not auto and (zone.tag ~= 'SUB' or page ~= pageId(ww, selected.pageName)) then state.status = 'paused' end
                return
            end
            if request.kind ~= 'wardrobe' then return end
            if zone.tag ~= 'SUB' or page ~= request.page then builds.stop(); return end
            request.setup = ww.setups.SUB[page][index]
            request.sawSelector = true
            request.started = GetFrameTimeMilliseconds()
            setIssue(state, nil)
            local uncovered = {}
            local replacement = wardrobeGear(request.setup, ww)
            request.expectedGear = {}
            for slot, id in pairs(request.base) do
                request.expectedGear[slot] = id
                if not replacement[slot] then uncovered[slot] = id end
            end
            for slot, id in pairs(replacement) do request.expectedGear[slot] = id end
            if not wornMatches(uncovered) then
                -- Armory-first can finish after banking only if WW equips all
                -- the missing slots. Otherwise finish at Armory on the next visit.
                builds.request = nil
                state.status, state.applying = 'armory', nil
                return true
            end
        end)
    end
end
