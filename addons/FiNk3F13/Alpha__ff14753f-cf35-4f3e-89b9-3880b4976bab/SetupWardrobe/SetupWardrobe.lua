local NAME = "SetupWardrobe"
local em = EVENT_MANAGER
local slots = {
    EQUIP_SLOT_HEAD, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_WAIST,
    EQUIP_SLOT_HAND, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_NECK,
    EQUIP_SLOT_RING1, EQUIP_SLOT_RING2, EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND,
    EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF,
}
local bars = { HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }
local weaponSlots = { EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND, EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF }
local gearReadyAt, checkedWeaponPose, sheathDeadline = 0, false, nil
local saved, selected, flight, previousKey, attempts
local gearBatchTried, skillBatchTried
local hud
local championSwap, championTarget
local function title(index)
    return saved.names[index] or ("Setup " .. index)
end

local function refreshHud()
    local lastName = saved.last and saved.setups[saved.last] and title(saved.last)
    local text = "|c83e4cfSetup|r  " .. (lastName or "Noch keines geladen")
    if selected then text = text .. "\n|cdec487→|r  " .. title(selected) end
    local cpStatus=championSwap and championSwap.Status()
    if championTarget and cpStatus then
        text=text.."\n|cdec487"..cpStatus.." · "..title(championTarget).."|r"
    end
    hud:SetText(text)
end

local function message(text) d("SetupWardrobe – " .. text) end

local function updateChampion()
    if not championTarget then return end
    if IsUnitInCombat("player") or IsUnitDeadOrReincarnating("player") then
        refreshHud()
        return
    end
    local setup=saved.setups[championTarget]
    local done,reason=championSwap.Step(setup and setup.cp)
    if done or reason then
        championTarget=nil
        em:UnregisterForUpdate(NAME.."Champion")
        if reason then message(reason) end
    end
    refreshHud()
end

local function item(bag, slot)
    if GetItemId(bag, slot) == 0 then return "" end
    return Id64ToString(GetItemUniqueId(bag, slot))
end

local function skill(bar, slot)
    local data = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(bar):GetSlotData(slot)
    return data:IsEmpty() and 0 or data:GetEffectiveAbilityId()
end

local function matchesSkill(bar, slot, wanted)
    local actual = skill(bar, slot)
    if actual == wanted then return true end
    if not actual or actual == 0 or not wanted or wanted == 0 then return false end
    local a = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(actual)
    local b = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(wanted)
    if not a or not b then return false end
    return a == b
end

local combatPaused = false
local resumeAt = 0
local function save(index)
    if selected then message("Wechsel läuft. Bitte danach speichern."); return end
    local setup = { gear = {}, skills = {}, gearNames = {}, links = {}, cp = {}, food = "Kein bekannter Essensbuff aktiv" }
    for _, slot in ipairs(slots) do
        setup.gear[slot] = item(BAG_WORN, slot)
        setup.links[slot] = GetItemLink(BAG_WORN, slot, LINK_STYLE_DEFAULT)
        setup.gearNames[slot] = zo_strformat("<<t:1>>", GetItemName(BAG_WORN, slot))
    end
    for slot = 1, 12 do setup.cp[slot] = GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION) end
    for i = 1, GetNumBuffs("player") do
        local name, _, _, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
        if ControllerWardrobeFoodEffects[id] then setup.food = zo_strformat("<<1>>", name); break end
    end
    for _, bar in ipairs(bars) do
        setup.skills[bar] = {}
        for slot = 3, 8 do setup.skills[bar][slot] = skill(bar, slot) end
    end
    saved.setups[index] = setup
    message("Setup " .. index .. " gespeichert.")
end

local function stop(text)
    selected, flight, previousKey, attempts = nil, nil, nil, 0
    refreshHud()
    em:UnregisterForUpdate(NAME)
    if text then message(text) end
end

local function locate(id)
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if item(BAG_BACKPACK, slot) == id then return BAG_BACKPACK, slot end
    end
    for _, slot in ipairs(slots) do
        if item(BAG_WORN, slot) == id then return BAG_WORN, slot end
    end
end

local function issue(key, confirmed, action, gearMove)
    if previousKey ~= key then attempts = 0 end
    previousKey, attempts = key, attempts + 1
    if attempts > 3 then stop("ESO hat den Wechsel nicht bestätigt (" .. key .. ")."); return end
    local now = GetGameTimeMilliseconds()
    flight = { confirmed = confirmed, untilMS = now + 1500 * attempts }
    if gearMove then gearReadyAt = now end
    action()
end

local function step()
    if not selected then return end
    if IsUnitInCombat("player") or IsUnitDeadOrReincarnating("player") then
        combatPaused = true
        return
    end
    if combatPaused then
        combatPaused = false
        resumeAt = GetGameTimeMilliseconds() + 250
        flight, previousKey, attempts = nil, nil, 0
    end
    if GetGameTimeMilliseconds() < resumeAt then return end
    if flight and not flight.confirmed() and GetGameTimeMilliseconds() < flight.untilMS then return end
    flight = nil
    local setup = saved.setups[selected]
    local now = GetGameTimeMilliseconds()
    if now < gearReadyAt then return end
    local changes = {}
    for _,bar in ipairs(bars) do
        for slot=3,8 do
            local id=setup.skills[bar][slot]
            if id ~= nil and not matchesSkill(bar,slot,id) then
                changes[#changes+1]={bar=bar,slot=slot,id=id}
            end
        end
    end
    if #changes>0 then
        local count=skillBatchTried and 1 or #changes
        skillBatchTried=true
        local first=changes[1]
        local key=count>1 and "Skillleisten" or ((first.bar==HOTBAR_CATEGORY_BACKUP and "Backbar" or "Frontbar").." · "..(first.slot==8 and "Ulti" or "Skill "..(first.slot-2)).." · "..(first.id==0 and "Platz leeren" or zo_strformat("<<1>>",GetAbilityName(first.id))))
        issue(key,function()
            for i=1,count do
                local c=changes[i]
                if not matchesSkill(c.bar,c.slot,c.id) then return false end
            end
            return true
        end,function()
            for i=1,count do
                local c=changes[i]
                local hotbar=ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(c.bar)
                if c.id==0 then hotbar:ClearSlot(c.slot)
                else hotbar:AssignSkillToSlotByAbilityId(c.slot,c.id) end
            end
        end)
        return
    end
    if not checkedWeaponPose then
        checkedWeaponPose = true
        if ArePlayerWeaponsSheathed and TogglePlayerWield and not ArePlayerWeaponsSheathed()
            and not (IsBlockActive and IsBlockActive()) then
            for _, slot in ipairs(weaponSlots) do
                if setup.gear[slot] and item(BAG_WORN, slot) ~= setup.gear[slot] then
                    sheathDeadline = now + 900
                    TogglePlayerWield()
                    return
                end
            end
        end
    end
    if sheathDeadline then
        if now < sheathDeadline and not ArePlayerWeaponsSheathed() then return end
        sheathDeadline = nil
    end
    -- Backpack items in independent worn slots can be requested together.
    -- Keep weapon pairs and worn-to-worn moves on the confirmed single-step path.
    local moves = {}
    for _, slot in ipairs(slots) do
        local id = setup.gear[slot]
        if id and id ~= "" and item(BAG_WORN, slot) ~= id then
            local bag, source = locate(id)
            if bag == BAG_BACKPACK and slot ~= EQUIP_SLOT_MAIN_HAND and slot ~= EQUIP_SLOT_OFF_HAND
                and slot ~= EQUIP_SLOT_BACKUP_MAIN and slot ~= EQUIP_SLOT_BACKUP_OFF then
                moves[#moves+1] = {slot=slot, source=source, id=id}
            end
        end
    end
    if #moves > 1 and not gearBatchTried then
        gearBatchTried = true
        local key = "Ausrüstungsgruppe"
        issue(key, function()
            for _,move in ipairs(moves) do
                if item(BAG_WORN, move.slot) == move.id then return true end
            end
            return false
        end, function()
            for _,move in ipairs(moves) do
                if item(BAG_BACKPACK, move.source) == move.id then
                    CallSecureProtected("RequestMoveItem", BAG_BACKPACK, move.source, BAG_WORN, move.slot, 1)
                end
            end
        end)
        return
    end
    for _, slot in ipairs(slots) do
        local id = setup.gear[slot]
        if id and id ~= "" and item(BAG_WORN, slot) ~= id then
            local bag, source = locate(id)
            if not bag then stop("Teil für Platz " .. slot .. " fehlt im Inventar."); return end
            if bag == BAG_WORN then
                local free = FindFirstEmptySlotInBag(BAG_BACKPACK)
                if not free then stop("Ein freier Rucksackplatz wird benötigt."); return end
                issue("Ablegen " .. source, function() return item(BAG_BACKPACK, free) == id end,
                    function() CallSecureProtected("RequestMoveItem", bag, source, BAG_BACKPACK, free, 1) end, true)
            else
                issue("Ausrüstung " .. slot, function() return item(BAG_WORN, slot) == id end,
                    function() CallSecureProtected("RequestMoveItem", bag, source, BAG_WORN, slot, 1) end, true)
            end
            return
        end
    end
    for _, slot in ipairs(slots) do
        if setup.gear[slot] == "" and item(BAG_WORN, slot) ~= "" then
            local free = FindFirstEmptySlotInBag(BAG_BACKPACK)
            if not free then stop("Rucksack ist voll."); return end
            issue("Leeren " .. slot, function() return item(BAG_WORN, slot) == "" end,
                function() CallSecureProtected("RequestMoveItem", BAG_WORN, slot, BAG_BACKPACK, free, 1) end, true)
            return
        end
    end
    saved.last = selected
    stop(title(selected) .. " geladen.")
end

local function loadSetup(index)
    if not saved.setups[index] then message("Setup " .. index .. " ist leer."); return end
    if selected then
        if selected ~= index then message("Bitte den laufenden Wechsel abwarten.") end
        return
    end
    local setup = saved.setups[index]
    if type(setup.gear) ~= "table" or type(setup.skills) ~= "table"
        or type(setup.skills[bars[1]]) ~= "table" or type(setup.skills[bars[2]]) ~= "table" then
        message("Dieses Setup ist unvollständig. Bitte erneut speichern.")
        return
    end
    for _, slot in ipairs(slots) do
        local id = setup.gear[slot]
        if id and id ~= "" and not locate(id) then
            message("Teil für Platz " .. slot .. " fehlt im Inventar.")
            return
        end
    end
    local valid,reason=championSwap.Validate(setup.cp)
    if not valid then message(reason); return end
    championTarget=index
    championSwap.Reset()
    em:UnregisterForUpdate(NAME.."Champion")
    em:RegisterForUpdate(NAME.."Champion",100,updateChampion)
    selected, previousKey, attempts = index, nil, 0
    combatPaused, resumeAt = false, 0
    checkedWeaponPose, sheathDeadline = false, nil
    gearBatchTried, skillBatchTried = false, false
    refreshHud()
    em:UnregisterForUpdate(NAME)
    em:RegisterForUpdate(NAME, 50, step)
    if IsUnitInCombat("player") or IsUnitDeadOrReincarnating("player") then
        message("Setup " .. index .. " vorgemerkt.")
    end
    step()
end

em:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addon)
    if addon ~= NAME then return end
    em:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    saved = ZO_SavedVars:NewCharacterIdSettings("ControllerWardrobeSaved", 1, nil, { setups = {}, names = {} })
    championSwap=SetupWardrobeChampionSwap()
    local root = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. "HUD")
    root:SetDimensions(540, 84)
    root:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 55, -185)
    hud = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
    hud:SetAnchorFill(root)
    hud:SetFont("ZoFontGamepad22")
    hud:SetMaxLineCount(3)
    local fragment = ZO_HUDFadeSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    refreshHud()
    if LibRadialMenu then LibRadialMenu:RegisterAddon("ControllerWardrobe", "SetupWardrobe") end
    local lib = LibHarvensAddonSettings
    local menu = lib:AddAddon("SetupWardrobe", { allowDefaults = false })
    ControllerWardrobeMenu(menu, saved, slots, bars, title, save, loadSetup, locate, refreshHud,
        function() return selected end,
        function()
            championTarget=nil
            em:UnregisterForUpdate(NAME.."Champion")
            stop("Ausstehender Wechsel abgebrochen.")
        end)
    SLASH_COMMANDS["/cw"] = function(text)
        local index = tonumber(text)
        if index and index == math.floor(index) and index >= 1 and index <= 4 then loadSetup(index)
        else message("/cw 1 bis /cw 4 lädt den gespeicherten Platz.") end
    end
    em:RegisterForEvent(NAME, EVENT_PLAYER_DEACTIVATED, function()
        championTarget=nil
        em:UnregisterForUpdate(NAME.."Champion")
        stop()
    end)
end)
