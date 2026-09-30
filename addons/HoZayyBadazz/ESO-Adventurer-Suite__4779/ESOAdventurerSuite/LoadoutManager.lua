-- ESO Adventurer Suite
-- Saved character builds: gear, dual action bars, Champion profile/slots, and attribute profile.
-- Native implementation; no third-party loadout source code is included.

local EPC = ESOProgressionCoach
EPC.LoadoutManager = EPC.LoadoutManager or {}
local L = EPC.LoadoutManager
local wm = WINDOW_MANAGER

local SLOT_COUNT = 16
local MAX_PAGES = 24
local PAGE_DATA_KEY = "savedLoadoutPages029272"

local EQUIP_SLOTS = {
    EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST, EQUIP_SLOT_HAND,
    EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET,
    EQUIP_SLOT_NECK, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2,
    EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND,
    EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF,
    EQUIP_SLOT_POISON, EQUIP_SLOT_BACKUP_POISON,
}

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d,e,f = pcall(fn, ...)
    if not ok then return fallback end
    return a,b,c,d,e,f
end

-- ESO API functions frequently return multiple values. Passing a multi-return
-- call directly to tonumber() can accidentally feed the second return value
-- into tonumber's optional numeric-base argument. Route numeric conversions
-- through a one-argument Lua helper so extra return values are discarded.
local function num(value)
    return tonumber(value)
end

-- Keep the Loadout Saver on a normal UI tier and all Suite-owned popup/modal
-- windows on a genuinely higher tier. DrawLevel alone does not guarantee
-- ordering between separate ESO top-level windows when they share a tier.
local function setLoadoutWindowLayer(control)
    if not control then return end
    local medium = rawget(_G, "DT_MEDIUM") or rawget(_G, "DT_LOW") or rawget(_G, "DT_HIGH")
    local controls = rawget(_G, "DL_CONTROLS") or rawget(_G, "DL_OVERLAY")
    if medium and type(control.SetDrawTier) == "function" then control:SetDrawTier(medium) end
    if controls and type(control.SetDrawLayer) == "function" then control:SetDrawLayer(controls) end
    if type(control.SetDrawLevel) == "function" then control:SetDrawLevel(120) end
end

local function raiseLoadoutModal(control, level)
    if not control then return end
    local high = rawget(_G, "DT_HIGH")
    local overlay = rawget(_G, "DL_OVERLAY")
    if high and type(control.SetDrawTier) == "function" then control:SetDrawTier(high) end
    if overlay and type(control.SetDrawLayer) == "function" then control:SetDrawLayer(overlay) end
    if type(control.SetDrawLevel) == "function" then control:SetDrawLevel(tonumber(level) or 12000) end
end

function L:RaiseModal(control, level)
    raiseLoadoutModal(control, level)
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if control and not control:IsHidden() then raiseLoadoutModal(control, level) end
        end, 1)
        zo_callLater(function()
            if control and not control:IsHidden() then raiseLoadoutModal(control, level) end
        end, 80)
    end
end

local function notify(text, good)
    if EPC and type(EPC.Print) == "function" then EPC:Print(text) end
    if type(ZO_Alert) == "function" then
        pcall(ZO_Alert, good == false and UI_ALERT_CATEGORY_ERROR or UI_ALERT_CATEGORY_ALERT, nil, text)
    end
end

local function uniqueIdString(bag, slot)
    if type(GetItemUniqueId) ~= "function" or type(Id64ToString) ~= "function" then return "" end
    local id = safe(GetItemUniqueId, nil, bag, slot)
    if not id then return "" end
    return tostring(safe(Id64ToString, "", id) or "")
end

local function itemLink(bag, slot)
    return safe(GetItemLink, "", bag, slot, LINK_STYLE_DEFAULT or 0) or ""
end

local function itemIconFromLink(link)
    if tostring(link or "") == "" then return "" end
    return tostring(safe(GetItemLinkIcon, "", link) or "")
end

function L:MakeGearEntry(bag, slot)
    local link = itemLink(bag, slot)
    if link == "" then return nil end
    return {
        uniqueId = uniqueIdString(bag, slot),
        link = link,
        itemId = num(safe(GetItemLinkItemId, 0, link)) or 0,
        signature = self.GetGearSignature and self:GetGearSignature(link) or nil,
    }
end

function L:MakeFoodEntry(bag, slot)
    local link = itemLink(bag, slot)
    if link == "" then return nil end
    local itemType = num(safe(GetItemType, 0, bag, slot)) or 0
    if itemType ~= (rawget(_G, "ITEMTYPE_FOOD") or -1001) and itemType ~= (rawget(_G, "ITEMTYPE_DRINK") or -1002) then return nil end
    return {
        link = link,
        itemId = num(safe(GetItemLinkItemId, 0, link)) or 0,
        icon = itemIconFromLink(link),
    }
end

function L:FindBackpackItemByItemId(itemId)
    itemId = tonumber(itemId) or 0
    if itemId <= 0 or BAG_BACKPACK == nil then return nil end
    local size = num(safe(GetBagSize, 0, BAG_BACKPACK)) or 0
    for slot=0,size-1 do
        local link = itemLink(BAG_BACKPACK, slot)
        if link ~= "" and (num(safe(GetItemLinkItemId, 0, link)) or 0) == itemId then
            return BAG_BACKPACK, slot
        end
    end
    return nil
end

function L:UseSavedFood(index)
    local setup = self:EnsureSaved()[tonumber(index) or 0]
    local food = setup and setup.food
    if type(food) ~= "table" or (tonumber(food.itemId) or 0) <= 0 then
        notify("LOADOUTS: this setup has no buff food saved. Drag food onto the FOOD icon first.", false)
        return false
    end
    if safe(IsUnitInCombat, false, "player") == true then
        notify("LOADOUTS: buff food will be used after combat.", false)
        return false
    end
    local bag,slot = self:FindBackpackItemByItemId(food.itemId)
    if bag == nil then
        notify("LOADOUTS: saved buff food is missing from your backpack.", false)
        return false
    end
    local cooldown = num(safe(GetItemCooldownInfo, 0, bag, slot)) or 0
    if cooldown > 0 then return false end
    local ok,result = pcall(CallSecureProtected, "UseItem", bag, slot)
    if ok and result ~= false then
        EPC.saved.loadoutLastFoodItemId029272 = tonumber(food.itemId) or 0
        return true
    end
    notify("LOADOUTS: ESO blocked the buff-food use request.", false)
    return false
end

local function shallowCopyTable(source)
    local out = {}
    if type(source) ~= "table" then return out end
    for k,v in pairs(source) do out[k] = v end
    return out
end

function L:NormalizeSetupList(setups)
    setups = type(setups) == "table" and setups or {}
    for i=1,SLOT_COUNT do
        setups[i] = setups[i] or { name = "Build " .. i }
        local d = setups[i]
        if not d.name or d.name == "" then
            d.name = "Build " .. i
        elseif d.name == ("Loadout " .. i) then
            d.name = "Build " .. i
        end
    end
    return setups
end

function L:EnsurePages()
    EPC.saved = EPC.saved or {}
    local root = EPC.saved[PAGE_DATA_KEY]
    if type(root) ~= "table" or type(root.pages) ~= "table" then
        local legacy = type(EPC.saved.savedLoadouts) == "table" and EPC.saved.savedLoadouts or {}
        root = {
            version = 1,
            currentPageId = 1,
            nextPageId = 2,
            pages = {
                [1] = {
                    name = "General",
                    zoneId = 0,
                    zoneName = "",
                    zoneAutoSlot = 0,
                    activeIndex = tonumber(EPC.saved.savedLoadoutActiveIndex) or 0,
                    bossRules = {},
                    setups = legacy,
                },
            },
            selectedPageByZone = {},
        }
        EPC.saved[PAGE_DATA_KEY] = root
    end

    root.version = 1
    root.pages = type(root.pages) == "table" and root.pages or {}
    root.selectedPageByZone = type(root.selectedPageByZone) == "table" and root.selectedPageByZone or {}
    root.currentPageId = tonumber(root.currentPageId) or 1
    root.nextPageId = tonumber(root.nextPageId) or 2

    if type(root.pages[root.currentPageId]) ~= "table" then
        local firstId
        for id,_ in pairs(root.pages) do
            id = tonumber(id)
            if id and (not firstId or id < firstId) then firstId = id end
        end
        root.currentPageId = firstId or 1
    end
    if type(root.pages[root.currentPageId]) ~= "table" then
        root.pages[root.currentPageId] = { name = "General", zoneId = 0, zoneName = "", zoneAutoSlot = 0, activeIndex = 0, bossRules = {}, setups = {} }
    end

    for id,page in pairs(root.pages) do
        if type(page) == "table" then
            page.name = tostring(page.name or ("Page " .. tostring(id)))
            page.zoneId = tonumber(page.zoneId) or 0
            page.zoneName = tostring(page.zoneName or "")
            page.zoneAutoSlot = tonumber(page.zoneAutoSlot) or 0
            page.activeIndex = tonumber(page.activeIndex) or 0
            page.bossRules = type(page.bossRules) == "table" and page.bossRules or {}
            page.setups = self:NormalizeSetupList(page.setups)
        end
    end

    local page = root.pages[root.currentPageId]
    EPC.saved.savedLoadouts = page.setups -- compatibility alias for older Suite modules
    EPC.saved.savedLoadoutActiveIndex = page.activeIndex
    return root
end

function L:GetPageIds()
    local root = self:EnsurePages()
    local ids = {}
    for id,_ in pairs(root.pages) do
        id = tonumber(id)
        if id then ids[#ids+1] = id end
    end
    table.sort(ids)
    return ids
end

function L:GetCurrentPageId()
    return tonumber(self:EnsurePages().currentPageId) or 1
end

function L:GetCurrentPage()
    local root = self:EnsurePages()
    return root.pages[root.currentPageId]
end

function L:SetCurrentPage(pageId, rememberForZone)
    local root = self:EnsurePages()
    pageId = tonumber(pageId)
    if not pageId or type(root.pages[pageId]) ~= "table" then return false end
    root.currentPageId = pageId
    local page = root.pages[pageId]
    page.setups = self:NormalizeSetupList(page.setups)
    EPC.saved.savedLoadouts = page.setups
    EPC.saved.savedLoadoutActiveIndex = tonumber(page.activeIndex) or 0
    if rememberForZone == true and (tonumber(page.zoneId) or 0) > 0 then
        root.selectedPageByZone[tostring(page.zoneId)] = pageId
    end
    self.activeIndex = tonumber(page.activeIndex) or 0
    self:RefreshUI()
    return true
end

function L:CyclePage(direction)
    local ids = self:GetPageIds()
    if #ids == 0 then return false end
    local current = self:GetCurrentPageId()
    local pos = 1
    for i,id in ipairs(ids) do if id == current then pos = i break end end
    direction = tonumber(direction) or 1
    pos = pos + (direction < 0 and -1 or 1)
    if pos < 1 then pos = #ids elseif pos > #ids then pos = 1 end
    return self:SetCurrentPage(ids[pos], true)
end

function L:AddPage()
    local root = self:EnsurePages()
    local count = 0
    for _ in pairs(root.pages) do count = count + 1 end
    if count >= MAX_PAGES then
        notify("LOADOUTS: maximum page count reached.", false)
        return false
    end
    local id = math.max(1, tonumber(root.nextPageId) or 1)
    while root.pages[id] do id = id + 1 end
    root.nextPageId = id + 1
    root.pages[id] = {
        name = "Page " .. tostring(count + 1), zoneId = 0, zoneName = "", zoneAutoSlot = 0,
        activeIndex = 0, bossRules = {}, setups = self:NormalizeSetupList({}),
    }
    self:SetCurrentPage(id, false)
    notify("LOADOUTS: new page created.", true)
    return true
end

function L:DeleteCurrentPage()
    local root = self:EnsurePages()
    local ids = self:GetPageIds()
    if #ids <= 1 then
        notify("LOADOUTS: keep at least one page.", false)
        return false
    end
    local current = root.currentPageId
    local old = root.pages[current]
    root.pages[current] = nil
    self:RebuildGearIndex()
    for zoneText,pageId in pairs(root.selectedPageByZone) do
        if tonumber(pageId) == tonumber(current) then root.selectedPageByZone[zoneText] = nil end
    end
    local nextId = ids[1] == current and ids[2] or ids[1]
    self:SetCurrentPage(nextId, false)
    notify("LOADOUTS: deleted page " .. tostring(old and old.name or current) .. ".", true)
    return true
end

function L:SetPageName(name)
    local page = self:GetCurrentPage()
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = "Page " .. tostring(self:GetCurrentPageId()) end
    page.name = string.sub(name, 1, 32)
    self:RefreshUI()
    return true
end

function L:GetCurrentZoneInfo()
    local zoneIndex = num(safe(GetUnitZoneIndex, 0, "player")) or 0
    local zoneId = zoneIndex > 0 and (num(safe(GetZoneId, 0, zoneIndex)) or 0) or 0
    local zoneName = tostring(safe(GetUnitZone, "", "player") or "")
    if zoneName == "" and zoneIndex > 0 then zoneName = tostring(safe(GetZoneNameByIndex, "", zoneIndex) or "") end
    return zoneId, zoneName
end

function L:BindCurrentPageToZone()
    local zoneId, zoneName = self:GetCurrentZoneInfo()
    if zoneId <= 0 then notify("LOADOUTS: current zone could not be identified.", false); return false end
    local page = self:GetCurrentPage()
    page.zoneId, page.zoneName = zoneId, zoneName
    local root = self:EnsurePages()
    root.selectedPageByZone[tostring(zoneId)] = self:GetCurrentPageId()
    notify("LOADOUTS: page bound to " .. (zoneName ~= "" and zoneName or ("zone " .. zoneId)) .. ".", true)
    self:RefreshUI()
    return true
end

function L:UnbindCurrentPageZone()
    local page = self:GetCurrentPage()
    local oldZone = tonumber(page.zoneId) or 0
    page.zoneId, page.zoneName = 0, ""
    local root = self:EnsurePages()
    if oldZone > 0 and tonumber(root.selectedPageByZone[tostring(oldZone)]) == self:GetCurrentPageId() then
        root.selectedPageByZone[tostring(oldZone)] = nil
    end
    self:RefreshUI()
    return true
end

function L:GetPageForCurrentZone()
    local zoneId = self:GetCurrentZoneInfo()
    zoneId = tonumber(zoneId) or 0
    if zoneId <= 0 then return nil end
    local root = self:EnsurePages()
    local selected = tonumber(root.selectedPageByZone[tostring(zoneId)])
    if selected and root.pages[selected] and tonumber(root.pages[selected].zoneId) == zoneId then return selected end
    local best
    for id,page in pairs(root.pages) do
        if tonumber(page.zoneId) == zoneId then
            id = tonumber(id)
            if id and (not best or id < best) then best = id end
        end
    end
    return best
end

function L:GetCurrentBossName()
    for i=1,12 do
        local tag = "boss" .. tostring(i)
        if safe(DoesUnitExist, false, tag) == true then
            local name = tostring(safe(GetRawUnitName, "", tag) or safe(GetUnitName, "", tag) or "")
            name = name:gsub("^%s+", ""):gsub("%s+$", "")
            if name ~= "" then return name end
        end
    end
    return ""
end

function L:BindSetupToCurrentBoss(index)
    index = tonumber(index)
    if not index or index < 1 or index > SLOT_COUNT then return false end
    local boss = self:GetCurrentBossName()
    if boss == "" then notify("LOADOUTS: no active boss encounter to bind.", false); return false end
    local page = self:GetCurrentPage()
    page.bossRules[boss] = index
    notify(string.format("LOADOUTS: %s will auto-load Build %d on this page.", boss, index), true)
    self:RefreshUI()
    return true
end

function L:SetZoneAutoSlot(index)
    index = tonumber(index) or 0
    if index < 0 or index > SLOT_COUNT then return false end
    local page = self:GetCurrentPage()
    page.zoneAutoSlot = index
    notify(index > 0 and string.format("LOADOUTS: Build %d is the page's raid-entry setup.", index) or "LOADOUTS: raid-entry setup cleared.", true)
    self:RefreshUI()
    return true
end

function L:EnsureSaved()
    return self:GetCurrentPage().setups
end

function L:GetActionSlots()
    local first = tonumber(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX) or 3
    -- ACTION_BAR_ULTIMATE_SLOT_INDEX is the logical ultimate index used by parts
    -- of the UI. The physical hotbar slot queried/assigned by GetSlotBoundId /
    -- SelectSlotAbility is one slot after it.
    local ultBase = tonumber(ACTION_BAR_ULTIMATE_SLOT_INDEX) or (first + 5)
    local ult = ultBase + 1
    return {first, first+1, first+2, first+3, first+4, ult}
end

function L:CaptureBars()
    local bars = { primary = {}, backup = {} }
    local slots = self:GetActionSlots()
    local primary = rawget(_G, "HOTBAR_CATEGORY_PRIMARY") or 0
    local backup = rawget(_G, "HOTBAR_CATEGORY_BACKUP") or 1
    for _,slot in ipairs(slots) do
        bars.primary[#bars.primary+1] = num(safe(GetSlotBoundId, 0, slot, primary)) or 0
        bars.backup[#bars.backup+1] = num(safe(GetSlotBoundId, 0, slot, backup)) or 0
    end
    return bars
end

function L:CaptureGear()
    local gear = {}
    for _,slot in ipairs(EQUIP_SLOTS) do
        if slot ~= nil then
            local entry = self:MakeGearEntry(BAG_WORN, slot)
            if entry then gear[tostring(slot)] = entry end
        end
    end
    return gear
end

function L:CaptureAttributes()
    local health = num(safe(GetAttributeSpentPoints, 0, rawget(_G, "ATTRIBUTE_HEALTH") or 1)) or 0
    local magicka = num(safe(GetAttributeSpentPoints, 0, rawget(_G, "ATTRIBUTE_MAGICKA") or 2)) or 0
    local stamina = num(safe(GetAttributeSpentPoints, 0, rawget(_G, "ATTRIBUTE_STAMINA") or 3)) or 0
    return { health = health, magicka = magicka, stamina = stamina, total = health + magicka + stamina }
end

function L:GetChampionSlots()
    local first, last = 1, 12
    if type(GetAssignableChampionBarStartAndEndSlots) == "function" then
        local a,b = safe(GetAssignableChampionBarStartAndEndSlots, nil)
        first = tonumber(a) or first
        last = tonumber(b) or last
    end
    if last < first then first, last = 1, 12 end
    return first, last
end

function L:CaptureChampion()
    local champion = { allocations = {}, slots = {}, allocatedPoints = 0, allocationCount = 0, slottedCount = 0 }
    if type(GetNumChampionDisciplines) == "function" and type(GetNumChampionDisciplineSkills) == "function"
        and type(GetChampionSkillId) == "function" and type(GetNumPointsSpentOnChampionSkill) == "function" then
        local disciplines = num(safe(GetNumChampionDisciplines, 0)) or 0
        for di=1,disciplines do
            local skillCount = num(safe(GetNumChampionDisciplineSkills, 0, di)) or 0
            for si=1,skillCount do
                local id = num(safe(GetChampionSkillId, 0, di, si)) or 0
                if id > 0 then
                    local points = num(safe(GetNumPointsSpentOnChampionSkill, 0, id)) or 0
                    if points > 0 then
                        champion.allocations[tostring(id)] = points
                        champion.allocatedPoints = champion.allocatedPoints + points
                        champion.allocationCount = champion.allocationCount + 1
                    end
                end
            end
        end
    end
    local category = rawget(_G, "HOTBAR_CATEGORY_CHAMPION")
    if category ~= nil and type(GetSlotBoundId) == "function" then
        local first,last = self:GetChampionSlots()
        champion.firstSlot, champion.lastSlot = first,last
        for slot=first,last do
            local id = num(safe(GetSlotBoundId, 0, slot, category)) or 0
            champion.slots[tostring(slot)] = id
            if id > 0 then champion.slottedCount = champion.slottedCount + 1 end
        end
    end
    return champion
end

function L:CaptureSkillProfile()
    local profile = { purchased = {}, purchasedCount = 0 }
    if type(GetNumSkillTypes) ~= "function" or type(GetNumSkillLines) ~= "function"
        or type(GetNumSkillAbilities) ~= "function" or type(GetSkillAbilityInfo) ~= "function" then return profile end
    local typeCount = num(safe(GetNumSkillTypes, 0)) or 0
    for skillType=1,typeCount do
        local lineCount = num(safe(GetNumSkillLines, 0, skillType)) or 0
        for skillLine=1,lineCount do
            local abilityCount = num(safe(GetNumSkillAbilities, 0, skillType, skillLine)) or 0
            for abilityIndex=1,abilityCount do
                local _,_,_,passive,ultimate,purchased,progressionIndex,rank = safe(GetSkillAbilityInfo, nil, skillType, skillLine, abilityIndex)
                if purchased == true then
                    local key = string.format("%d:%d:%d", skillType, skillLine, abilityIndex)
                    local abilityId = type(GetSkillAbilityId) == "function" and (num(safe(GetSkillAbilityId, 0, skillType, skillLine, abilityIndex, false)) or 0) or 0
                    profile.purchased[key] = {
                        abilityId = abilityId,
                        passive = passive == true,
                        ultimate = ultimate == true,
                        progressionIndex = tonumber(progressionIndex) or 0,
                        rank = tonumber(rank) or 0,
                    }
                    profile.purchasedCount = profile.purchasedCount + 1
                end
            end
        end
    end
    return profile
end

function L:VerifySkillProfile(profile)
    if type(profile) ~= "table" or type(profile.purchased) ~= "table" or type(GetSkillAbilityInfo) ~= "function" then return 0,0 end
    local matched, expected = 0,0
    for key,_ in pairs(profile.purchased) do
        local a,b,c = string.match(key, "^(%d+):(%d+):(%d+)$")
        a,b,c = tonumber(a),tonumber(b),tonumber(c)
        if a and b and c then
            expected = expected + 1
            local _,_,_,_,_,purchased = safe(GetSkillAbilityInfo, nil, a,b,c)
            if purchased == true then matched = matched + 1 end
        end
    end
    return matched,expected
end

function L:CaptureBuildProfile()
    return {
        version = 2,
        attributes = self:CaptureAttributes(),
        champion = self:CaptureChampion(),
        skills = self:CaptureSkillProfile(),
    }
end

function L:ApplyChampionSlots(champion)
    if type(champion) ~= "table" or type(champion.slots) ~= "table" then return 0,0 end
    local category = rawget(_G, "HOTBAR_CATEGORY_CHAMPION")
    if category == nil or type(GetSlotBoundId) ~= "function" then return 0,0 end
    if type(PrepareChampionPurchaseRequest) ~= "function" or type(AddHotbarSlotToChampionPurchaseRequest) ~= "function"
        or type(SendChampionPurchaseRequest) ~= "function" then return 0,1 end

    local changed = 0
    for slotText,wanted in pairs(champion.slots) do
        local slot = tonumber(slotText)
        if slot then
            local current = num(safe(GetSlotBoundId, 0, slot, category)) or 0
            if current ~= (tonumber(wanted) or 0) then changed = changed + 1 end
        end
    end
    if changed == 0 then return 0,0 end

    local ok = pcall(PrepareChampionPurchaseRequest, false)
    if not ok then return 0,changed end
    local failed = 0
    for slotText,wanted in pairs(champion.slots) do
        local slot = tonumber(slotText)
        if slot then
            local addOk = pcall(AddHotbarSlotToChampionPurchaseRequest, slot, tonumber(wanted) or 0)
            if not addOk then failed = failed + 1 end
        end
    end
    local expected = type(GetExpectedResultForChampionPurchaseRequest) == "function" and safe(GetExpectedResultForChampionPurchaseRequest, nil) or nil
    local successConst = rawget(_G, "CHAMPION_PURCHASE_SUCCESS")
    if expected ~= nil and successConst ~= nil and expected ~= successConst then return 0,math.max(1,failed) end
    local sent, result = pcall(SendChampionPurchaseRequest)
    if not sent or result == false then return 0,math.max(1,failed) end
    return changed,failed
end

function L:VerifyChampionProfile(champion)
    if type(champion) ~= "table" then return 0,0,0,0 end
    local slotMatched, slotExpected = 0,0
    local category = rawget(_G, "HOTBAR_CATEGORY_CHAMPION")
    if category ~= nil and type(GetSlotBoundId) == "function" then
        for slotText,wanted in pairs(champion.slots or {}) do
            local slot = tonumber(slotText)
            if slot then
                slotExpected = slotExpected + 1
                local current = num(safe(GetSlotBoundId, 0, slot, category)) or 0
                if current == (tonumber(wanted) or 0) then slotMatched = slotMatched + 1 end
            end
        end
    end
    local pointMatched, pointExpected = 0,0
    if type(GetNumPointsSpentOnChampionSkill) == "function" then
        for idText,wanted in pairs(champion.allocations or {}) do
            local id = tonumber(idText)
            if id then
                pointExpected = pointExpected + 1
                if (num(safe(GetNumPointsSpentOnChampionSkill, 0, id)) or 0) == (tonumber(wanted) or 0) then
                    pointMatched = pointMatched + 1
                end
            end
        end
    end
    return slotMatched,slotExpected,pointMatched,pointExpected
end

function L:GetActiveIndex()
    local page = self:GetCurrentPage()
    return tonumber(page and page.activeIndex) or 0
end

function L:SetActiveIndex(index)
    EPC.saved = EPC.saved or {}
    index = tonumber(index) or 0
    if index < 1 or index > SLOT_COUNT then index = 0 end
    local page = self:GetCurrentPage()
    page.activeIndex = index
    EPC.saved.savedLoadoutActiveIndex = index
    self.activeIndex = index
    self:RefreshUI()
end

local function nowMs()
    if type(GetFrameTimeMilliseconds) == "function" then
        return num(safe(GetFrameTimeMilliseconds, 0)) or 0
    end
    if type(GetGameTimeMilliseconds) == "function" then
        return num(safe(GetGameTimeMilliseconds, 0)) or 0
    end
    return 0
end

function L:IsFilled(index)
    local d = self:EnsureSaved()[tonumber(index) or 0]
    return type(d) == "table" and (type(d.gear) == "table" or type(d.bars) == "table")
end

function L:RequestSave(index)
    index = tonumber(index)
    if not index or index < 1 or index > SLOT_COUNT then return false end
    if not self:IsFilled(index) then return self:Save(index) end

    self.pendingOverwrite = self.pendingOverwrite or {}
    local stamp = nowMs()
    if self.pendingOverwrite[index] and (stamp - self.pendingOverwrite[index]) <= 3000 then
        self.pendingOverwrite[index] = nil
        return self:Save(index)
    end

    self.pendingOverwrite[index] = stamp
    local c = self.cards and self.cards[index]
    if c and c.saveButton then c.saveButton:SetText("OVERWRITE?") end
    notify(string.format("BUILD %d already has a setup. Press OVERWRITE? again to replace it.", index), true)
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if self.pendingOverwrite and self.pendingOverwrite[index] == stamp then
                self.pendingOverwrite[index] = nil
                local card = self.cards and self.cards[index]
                if card and card.saveButton then card.saveButton:SetText("SAVE") end
            end
        end, 3100)
    end
    return false
end

function L:RequestClear(index)
    index = tonumber(index)
    if not index or index < 1 or index > SLOT_COUNT then return false end
    if not self:IsFilled(index) then return self:Clear(index) end

    self.pendingClear = self.pendingClear or {}
    local stamp = nowMs()
    if self.pendingClear[index] and (stamp - self.pendingClear[index]) <= 3000 then
        self.pendingClear[index] = nil
        return self:Clear(index)
    end

    self.pendingClear[index] = stamp
    local c = self.cards and self.cards[index]
    if c and c.clearButton then c.clearButton:SetText("CLEAR?") end
    notify(string.format("BUILD %d is saved. Press CLEAR? again to erase that setup.", index), false)
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if self.pendingClear and self.pendingClear[index] == stamp then
                self.pendingClear[index] = nil
                local card = self.cards and self.cards[index]
                if card and card.clearButton then card.clearButton:SetText("CLEAR") end
            end
        end, 3100)
    end
    return false
end

function L:Save(index)
    index = tonumber(index)
    if not index or index < 1 or index > SLOT_COUNT then return false end
    if safe(IsUnitInCombat, false, "player") == true then
        notify("BUILD: leave combat before saving or changing equipment.", false)
        return false
    end
    local all = self:EnsureSaved()
    local old = all[index] or {}
    local oldName = old.name or ("Build " .. index)
    local food = type(old.food) == "table" and shallowCopyTable(old.food) or nil
    if not food or (tonumber(food.itemId) or 0) <= 0 then
        local lastFoodId = tonumber(EPC.saved.loadoutLastFoodItemId029272) or 0
        local bag,slot = self:FindBackpackItemByItemId(lastFoodId)
        if bag ~= nil then food = self:MakeFoodEntry(bag, slot) end
    end
    all[index] = {
        name = oldName,
        gear = self:CaptureGear(),
        bars = self:CaptureBars(),
        build = self:CaptureBuildProfile(),
        food = food,
        savedAt = safe(GetTimeStamp, 0) or 0,
    }
    notify(string.format("BUILD %d SAVED: %s", index, oldName), true)
    self:RebuildGearIndex()
    self:RefreshUI()
    return true
end

function L:GetGearSignature(link)
    link = tostring(link or "")
    if link == "" then return nil end
    local sig = {
        itemId = num(safe(GetItemLinkItemId, 0, link)) or 0,
        equipType = num(safe(GetItemLinkEquipType, 0, link)) or 0,
        traitType = num(safe(GetItemLinkTraitInfo, 0, link)) or 0,
        weaponType = num(safe(GetItemLinkWeaponType, 0, link)) or 0,
        armorType = num(safe(GetItemLinkArmorType, 0, link)) or 0,
        setId = 0,
    }
    if type(GetItemLinkSetInfo) == "function" then
        local _,_,_,_,_,setId = safe(GetItemLinkSetInfo, nil, link, false)
        sig.setId = tonumber(setId) or 0
    end
    return sig
end

function L:EntryMatches(bag, slot, entry)
    if type(entry) ~= "table" then return false end
    local link = itemLink(bag, slot)
    if link == "" then return false end
    local wantedUid = tostring(entry.uniqueId or "")
    if wantedUid ~= "" then
        -- Saved setups created on this account have a stable ESO unique item id.
        -- Do not silently substitute another copy of the same set/trait: that made
        -- bank withdraw/deposit think the saved piece was already local when a
        -- different duplicate happened to match its signature. Imported setups
        -- intentionally have no unique id and still use the signature fallback.
        local actualUid = uniqueIdString(bag, slot)
        if actualUid ~= "" then return actualUid == wantedUid end
    end

    local wantedSig = type(entry.signature) == "table" and entry.signature or self:GetGearSignature(entry.link)
    local actualSig = self:GetGearSignature(link)
    if not wantedSig or not actualSig then return false end
    if (tonumber(wantedSig.itemId) or tonumber(entry.itemId) or 0) > 0
        and (tonumber(actualSig.itemId) or 0) ~= (tonumber(wantedSig.itemId) or tonumber(entry.itemId) or 0) then return false end
    for _,key in ipairs({"equipType","traitType","weaponType","armorType","setId"}) do
        local wanted = tonumber(wantedSig[key]) or 0
        if wanted > 0 and (tonumber(actualSig[key]) or 0) ~= wanted then return false end
    end
    return (tonumber(actualSig.itemId) or 0) > 0
end

function L:FindSavedItem(entry, destination)
    if not entry then return nil end

    if destination ~= nil and BAG_WORN ~= nil and self:EntryMatches(BAG_WORN, destination, entry) then
        return BAG_WORN, destination, true
    end

    local function scanBag(bag)
        if bag == nil then return nil end
        local size = num(safe(GetBagSize, 0, bag)) or 0
        for slot=0,size-1 do
            if self:EntryMatches(bag, slot, entry) then return bag, slot, false end
        end
        return nil
    end

    local bag,slot,same = scanBag(BAG_BACKPACK)
    if bag then return bag,slot,same end
    if BAG_WORN ~= nil then
        for _,slotId in ipairs(EQUIP_SLOTS) do
            if slotId ~= nil and self:EntryMatches(BAG_WORN, slotId, entry) then return BAG_WORN, slotId, false end
        end
    end
    return nil
end

function L:GetOpenBankBags()
    if type(IsBankOpen) ~= "function" or safe(IsBankOpen, false) ~= true then return {} end
    local bags = {}
    local bankBag = num(safe(GetBankingBag, rawget(_G, "BAG_BANK")))
    if bankBag ~= nil then bags[#bags+1] = bankBag end
    if bankBag == rawget(_G, "BAG_BANK") and rawget(_G, "BAG_SUBSCRIBER_BANK") ~= nil
        and safe(IsESOPlusSubscriber, false) == true then
        bags[#bags+1] = BAG_SUBSCRIBER_BANK
    end
    return bags
end

function L:FindSavedItemInBank(entry)
    for _,bag in ipairs(self:GetOpenBankBags()) do
        local size = num(safe(GetBagSize, 0, bag)) or 0
        for slot=0,size-1 do
            if self:EntryMatches(bag, slot, entry) then return bag,slot end
        end
    end
    return nil
end

function L:GetMissingItems(index, includeOpenBank)
    local setup = self:EnsureSaved()[tonumber(index) or 0]
    local missing = {}
    if not setup or type(setup.gear) ~= "table" then return missing end
    for slotText,entry in pairs(setup.gear) do
        local dest = tonumber(slotText)
        local bag = self:FindSavedItem(entry, dest)
        if not bag and includeOpenBank == true then bag = self:FindSavedItemInBank(entry) end
        if not bag then
            local label = entry.link
            if type(entry.esohubSpec) == "table" and (tonumber(entry.esohubSpec.setId) or 0) > 0 then
                label = string.format("ESO-Hub slot %s — set %d / trait %d", tostring(slotText), tonumber(entry.esohubSpec.setId) or 0, tonumber(entry.esohubSpec.traitType) or 0)
            end
            missing[#missing+1] = label or ("Gear slot " .. tostring(slotText))
        end
    end
    if type(setup.food) == "table" and (tonumber(setup.food.itemId) or 0) > 0 then
        local foodBag = self:FindBackpackItemByItemId(setup.food.itemId)
        if not foodBag then missing[#missing+1] = setup.food.link or "Saved buff food" end
    end
    return missing
end

function L:CheckMissing(index)
    index = tonumber(index)
    if not index then return false end
    local missing = self:GetMissingItems(index, true)
    if #missing == 0 then
        notify(string.format("BUILD %d: all saved gear%s is available.", index,
            (self:EnsureSaved()[index].food and " and buff food" or "")), true)
        return true
    end
    local shown = {}
    for i=1,math.min(#missing, 6) do shown[#shown+1] = tostring(missing[i]) end
    notify(string.format("BUILD %d: %d missing item%s%s", index, #missing, #missing == 1 and "" or "s",
        #shown > 0 and (" | " .. table.concat(shown, ", ")) or ""), false)
    return false
end

function L:CheckCurrentPageMissing()
    local total, setups = 0,0
    for i=1,SLOT_COUNT do
        if self:IsFilled(i) then
            setups = setups + 1
            total = total + #self:GetMissingItems(i, true)
        end
    end
    if total == 0 then notify(string.format("LOADOUTS: page check complete. %d saved setup%s ready.", setups, setups == 1 and "" or "s"), true)
    else notify(string.format("LOADOUTS: page has %d missing item%s across %d setup%s.", total, total == 1 and "" or "s", setups, setups == 1 and "" or "s"), false) end
    return total == 0
end

function L:RebuildGearIndex()
    self.gearIndexByUid, self.gearIndexBySignature = {}, {}
    local root = self:EnsurePages()
    for pageId,page in pairs(root.pages) do
        for index,setup in ipairs(page.setups or {}) do
            for _,entry in pairs((setup and setup.gear) or {}) do
                local uid = tostring(entry.uniqueId or "")
                if uid ~= "" then
                    self.gearIndexByUid[uid] = self.gearIndexByUid[uid] or {}
                    self.gearIndexByUid[uid][#self.gearIndexByUid[uid]+1] = {pageId=pageId,index=index,name=setup.name,pageName=page.name}
                end
                local sig = self:GetGearSignature(entry.link)
                if sig and sig.itemId > 0 then
                    local key = table.concat({sig.itemId,sig.equipType,sig.traitType,sig.weaponType,sig.armorType,sig.setId}, ":")
                    self.gearIndexBySignature[key] = self.gearIndexBySignature[key] or {}
                    self.gearIndexBySignature[key][#self.gearIndexBySignature[key]+1] = {pageId=pageId,index=index,name=setup.name,pageName=page.name}
                end
            end
        end
    end
end

function L:GetItemSetupReferences(bag, slot)
    if not self.gearIndexByUid then self:RebuildGearIndex() end
    local uid = uniqueIdString(bag, slot)
    if uid ~= "" and self.gearIndexByUid[uid] then return self.gearIndexByUid[uid] end
    local sig = self:GetGearSignature(itemLink(bag, slot))
    if sig then
        local key = table.concat({sig.itemId,sig.equipType,sig.traitType,sig.weaponType,sig.armorType,sig.setId}, ":")
        return self.gearIndexBySignature[key]
    end
    return nil
end

function L:IsItemInAnySetup(bag, slot)
    local refs = self:GetItemSetupReferences(bag, slot)
    return type(refs) == "table" and #refs > 0, refs
end

function L:GetBankDestinationBag(sourceBag, sourceSlot)
    local bags = self:GetOpenBankBags()
    for _,bag in ipairs(bags) do
        if safe(DoesBagHaveSpaceFor, false, bag, sourceBag, sourceSlot) == true then return bag end
    end
    return nil
end

function L:MoveItemsSequential(items, destinationResolver, callback)
    items = type(items) == "table" and items or {}
    if self.bankTransferBusy then
        notify("LOADOUTS: a bank transfer is already in progress.", false)
        if callback then callback(0, #items) end
        return false
    end

    self.bankTransferBusy = true
    self.bankTransferToken = (tonumber(self.bankTransferToken) or 0) + 1
    local token = self.bankTransferToken
    local updateName = "EAS_LoadoutBankMove" .. tostring(token)
    local pos, moved, failed = 1,0,0

    local function stopPolling()
        if EVENT_MANAGER and type(EVENT_MANAGER.UnregisterForUpdate) == "function" then
            EPC.Runtime:UnregisterUpdate("LoadoutManager", "BankMove")
        end
    end

    local function finish()
        stopPolling()
        self.bankTransferBusy = false
        if self.window and not self.window:IsHidden() then self:RefreshUI() end
        if callback then callback(moved, failed) end
    end

    local step
    local function continueLater(delay)
        if type(zo_callLater) == "function" then zo_callLater(step, delay or 100) else step() end
    end

    step = function()
        if token ~= self.bankTransferToken then finish(); return end
        if pos > #items then finish(); return end
        if safe(IsBankOpen, false) ~= true then
            failed = failed + (#items - pos + 1)
            finish()
            return
        end

        local item = items[pos]
        pos = pos + 1
        local sourceBag,sourceSlot = item and item.bag, item and item.slot
        if sourceBag == nil or sourceSlot == nil or itemLink(sourceBag, sourceSlot) == "" then
            failed = failed + 1
            continueLater(40)
            return
        end

        local destBag = type(destinationResolver) == "function" and destinationResolver(sourceBag, sourceSlot) or destinationResolver
        if destBag == nil then
            failed = failed + 1
            continueLater(40)
            return
        end
        if type(DoesBagHaveSpaceFor) == "function" and safe(DoesBagHaveSpaceFor, false, destBag, sourceBag, sourceSlot) ~= true then
            failed = failed + 1
            continueLater(40)
            return
        end

        local destSlot = num(safe(FindFirstEmptySlotInBag, nil, destBag))
        if destSlot == nil then
            failed = failed + 1
            continueLater(40)
            return
        end

        local sourceUid = uniqueIdString(sourceBag, sourceSlot)
        local sourceLink = itemLink(sourceBag, sourceSlot)
        local ok,result = pcall(CallSecureProtected, "RequestMoveItem", sourceBag, sourceSlot, destBag, destSlot, 1)
        if not ok or result == false then
            failed = failed + 1
            continueLater(80)
            return
        end

        -- Do not issue the next protected move until ESO confirms this one
        -- reached its destination. Firing several moves at the same empty slot
        -- before the bank UI updates caused transfers to appear to do nothing.
        local attempts = 0
        local completed = false
        local function checkArrival()
            if completed then return end
            attempts = attempts + 1
            local arrived = false
            local destLink = itemLink(destBag, destSlot)
            if sourceUid ~= "" then
                arrived = uniqueIdString(destBag, destSlot) == sourceUid
            elseif destLink ~= "" then
                arrived = sourceLink == "" or destLink == sourceLink
            end

            if arrived then
                completed = true
                stopPolling()
                moved = moved + 1
                continueLater(90)
            elseif attempts >= 30 or safe(IsBankOpen, false) ~= true then
                completed = true
                stopPolling()
                failed = failed + 1
                continueLater(90)
            end
        end

        if EVENT_MANAGER and type(EVENT_MANAGER.RegisterForUpdate) == "function" then
            stopPolling()
            EPC.Runtime:RegisterUpdate("LoadoutManager", "BankMove", 100, checkArrival)
        elseif type(zo_callLater) == "function" then
            local function pollLater()
                checkArrival()
                if not completed and attempts < 30 and self.bankTransferBusy and token == self.bankTransferToken then zo_callLater(pollLater, 100) end
            end
            zo_callLater(pollLater, 100)
        else
            moved = moved + 1
            step()
        end
    end

    if #items == 0 then finish() else step() end
    return true
end

function L:BuildBankTransferList(index, direction)
    local setup = self:EnsureSaved()[tonumber(index) or 0]
    local list,seen = {},{}
    if not setup or type(setup.gear) ~= "table" then return list end
    for slotText,entry in pairs(setup.gear) do
        local destination = tonumber(slotText)
        -- Poison stacks are managed by the optional poison-refill feature, not
        -- by gear banking. Keeping them out of the bank queue prevents a stack
        -- transfer from interfering with normal one-piece gear moves.
        if destination ~= rawget(_G, "EQUIP_SLOT_POISON") and destination ~= rawget(_G, "EQUIP_SLOT_BACKUP_POISON") then
            local bag,slot
            if direction == "withdraw" then
                local localBag = self:FindSavedItem(entry, destination)
                if not localBag then bag,slot = self:FindSavedItemInBank(entry) end
            else
                bag,slot = self:FindSavedItem(entry, destination)
            end
            if bag ~= nil and slot ~= nil then
                local uid = uniqueIdString(bag,slot)
                local key = uid ~= "" and uid or (tostring(bag)..":"..tostring(slot))
                if not seen[key] then seen[key]=true; list[#list+1] = {bag=bag,slot=slot,entry=entry,destination=destination} end
            end
        end
    end
    return list
end

function L:WithdrawSetup(index, callback)
    if self.bankTransferBusy then notify("LOADOUTS: a bank transfer is already in progress.", false); if callback then callback(0,0) end; return false end
    if safe(IsBankOpen, false) ~= true then notify("LOADOUTS: open a personal banker first, then press WITHDRAW.", false); if callback then callback(0,0) end; return false end
    local list = self:BuildBankTransferList(index, "withdraw")
    if #list == 0 then notify("LOADOUTS: no saved setup gear needs withdrawing.", true); if callback then callback(0,0) end; return true end
    self:MoveItemsSequential(list, BAG_BACKPACK, function(moved,failed)
        notify(string.format("LOADOUTS: withdrew %d item%s%s.", moved, moved==1 and "" or "s", failed>0 and (" | "..failed.." failed") or ""), failed==0)
        if callback then callback(moved,failed) end
    end)
    return true
end

function L:DepositSetup(index, callback)
    if self.bankTransferBusy then notify("LOADOUTS: a bank transfer is already in progress.", false); if callback then callback(0,0) end; return false end
    if safe(IsBankOpen, false) ~= true then notify("LOADOUTS: open a personal banker first, then press DEPOSIT.", false); if callback then callback(0,0) end; return false end
    local list = self:BuildBankTransferList(index, "deposit")
    if #list == 0 then notify("LOADOUTS: no setup gear is available to deposit.", true); if callback then callback(0,0) end; return true end
    self:MoveItemsSequential(list, function(bag,slot) return self:GetBankDestinationBag(bag,slot) end, function(moved,failed)
        notify(string.format("LOADOUTS: deposited %d item%s%s.", moved, moved==1 and "" or "s", failed>0 and (" | "..failed.." failed") or ""), failed==0)
        if callback then callback(moved,failed) end
    end)
    return true
end

function L:TransferCurrentPage(direction)
    if self.bankTransferBusy then notify("LOADOUTS: a bank transfer is already in progress.", false); return false end
    if safe(IsBankOpen, false) ~= true then notify("LOADOUTS: open a personal banker first, then use WITHDRAW or DEPOSIT.", false); return false end
    local combined,seen = {},{}
    for i=1,SLOT_COUNT do
        if self:IsFilled(i) then
            for _,item in ipairs(self:BuildBankTransferList(i, direction)) do
                local uid = uniqueIdString(item.bag,item.slot)
                local key = uid ~= "" and uid or (tostring(item.bag)..":"..tostring(item.slot))
                if not seen[key] then seen[key]=true; combined[#combined+1]=item end
            end
        end
    end
    local resolver = direction == "withdraw" and BAG_BACKPACK or function(bag,slot) return self:GetBankDestinationBag(bag,slot) end
    self:MoveItemsSequential(combined, resolver, function(moved,failed)
        notify(string.format("LOADOUTS: page %s moved %d item%s%s.", direction, moved, moved==1 and "" or "s", failed>0 and (" | "..failed.." failed") or ""), failed==0)
    end)
    return true
end

function L:GetSkillDataForSavedId(savedId)
    savedId = tonumber(savedId) or 0
    if savedId <= 0 then return nil end
    local mgr = rawget(_G, "SKILLS_DATA_MANAGER")
    if not mgr or type(mgr.GetSkillDataByIndices) ~= "function" then return nil end

    if type(GetSkillAbilityIndicesFromCraftedAbilityId) == "function" then
        local t,l,a = safe(GetSkillAbilityIndicesFromCraftedAbilityId, 0, savedId)
        if tonumber(t) and tonumber(t) > 0 then
            local ok, data = pcall(mgr.GetSkillDataByIndices, mgr, t,l,a)
            if ok and data then return data end
        end
    end

    if type(GetAbilityProgressionXPInfoFromAbilityId) == "function" and type(GetSkillAbilityIndicesFromProgressionIndex) == "function" then
        local hasProgression, progressionIndex = safe(GetAbilityProgressionXPInfoFromAbilityId, false, savedId)
        if hasProgression and tonumber(progressionIndex) and tonumber(progressionIndex) > 0 then
            local t,l,a = safe(GetSkillAbilityIndicesFromProgressionIndex, 0, progressionIndex)
            if tonumber(t) and tonumber(t) > 0 then
                local ok, data = pcall(mgr.GetSkillDataByIndices, mgr, t,l,a)
                if ok and data then return data end
            end
        end
    end

    -- Fallback for clients where progression lookup is stale: scan purchased skill data.
    if type(GetNumSkillTypes) == "function" and type(GetNumSkillLines) == "function" and type(GetNumSkillAbilities) == "function" then
        for t=1,(num(safe(GetNumSkillTypes,0)) or 0) do
            for l=1,(num(safe(GetNumSkillLines,0,t)) or 0) do
                for a=1,(num(safe(GetNumSkillAbilities,0,t,l)) or 0) do
                    local abilityId = num(safe(GetSkillAbilityId,0,t,l,a)) or 0
                    if abilityId == savedId then
                        local ok, data = pcall(mgr.GetSkillDataByIndices, mgr, t,l,a)
                        if ok and data then return data end
                    end
                end
            end
        end
    end
    return nil
end

function L:GetAbilityIndexForSavedId(savedId)
    savedId = tonumber(savedId) or 0
    if savedId <= 0 then return 0 end

    -- GetSlotBoundId stores the live ability id. For normal and most crafted
    -- abilities ESO can convert that id straight back to the protected API's
    -- abilityIndex.
    if type(GetAbilityIndex) == "function" then
        local idx = num(safe(GetAbilityIndex, 0, savedId)) or 0
        if idx > 0 then return idx end
    end

    -- Resolve the player's current morph/rank from the ability progression.
    if type(GetAbilityProgressionXPInfoFromAbilityId) == "function"
        and type(GetAbilityProgressionInfo) == "function"
        and type(GetAbilityProgressionAbilityInfo) == "function" then
        local hasProgression, progressionIndex = safe(GetAbilityProgressionXPInfoFromAbilityId, false, savedId)
        progressionIndex = tonumber(progressionIndex) or 0
        if hasProgression and progressionIndex > 0 then
            local _, morphChoice, rank = safe(GetAbilityProgressionInfo, nil, progressionIndex)
            local _, _, idx = safe(GetAbilityProgressionAbilityInfo, nil, progressionIndex, tonumber(morphChoice) or 0, tonumber(rank) or 1)
            idx = tonumber(idx) or 0
            if idx > 0 then return idx end
        end
    end

    -- Last-resort scan for clients where a progression lookup has not been
    -- populated yet. This also gives us the purchased skill's progression.
    if type(GetNumSkillTypes) == "function" and type(GetNumSkillLines) == "function"
        and type(GetNumSkillAbilities) == "function" and type(GetSkillAbilityInfo) == "function" then
        for t=1,(num(safe(GetNumSkillTypes,0)) or 0) do
            for l=1,(num(safe(GetNumSkillLines,0,t)) or 0) do
                for a=1,(num(safe(GetNumSkillAbilities,0,t,l)) or 0) do
                    local id = type(GetSkillAbilityId) == "function" and (num(safe(GetSkillAbilityId,0,t,l,a,false)) or 0) or 0
                    if id == savedId then
                        local _,_,_,passive,_,purchased,progressionIndex,rank = safe(GetSkillAbilityInfo,nil,t,l,a)
                        if purchased == true and passive ~= true then
                            progressionIndex = tonumber(progressionIndex) or 0
                            if progressionIndex > 0 and type(GetAbilityProgressionInfo) == "function" and type(GetAbilityProgressionAbilityInfo) == "function" then
                                local _, morphChoice, currentRank = safe(GetAbilityProgressionInfo,nil,progressionIndex)
                                local _,_,idx = safe(GetAbilityProgressionAbilityInfo,nil,progressionIndex,tonumber(morphChoice) or 0,tonumber(currentRank) or tonumber(rank) or 1)
                                idx = tonumber(idx) or 0
                                if idx > 0 then return idx end
                            end
                        end
                    end
                end
            end
        end
    end
    return 0
end

function L:ApplyBar(category, saved)
    if type(saved) ~= "table" then return 0, 0 end
    if type(CallSecureProtected) ~= "function" then return 0, #saved end

    local actionSlots = self:GetActionSlots()
    local changed, failed = 0, 0
    for i=1,#actionSlots do
        local actionSlot = actionSlots[i]
        local savedId = tonumber(saved[i]) or 0
        local currentId = num(safe(GetSlotBoundId, 0, actionSlot, category)) or 0

        if currentId ~= savedId then
            if savedId <= 0 then
                local ok, result = pcall(CallSecureProtected, "ClearSlot", actionSlot, category)
                if ok and result ~= false then changed = changed + 1 else failed = failed + 1 end
            else
                local abilityIndex = self:GetAbilityIndexForSavedId(savedId)
                local legal = abilityIndex > 0
                if legal and type(CanAbilityBeUsedFromHotbar) == "function" then
                    legal = safe(CanAbilityBeUsedFromHotbar, false, savedId, category) == true
                end
                if legal then
                    local ok, result = pcall(CallSecureProtected, "SelectSlotAbility", abilityIndex, actionSlot, category)
                    if ok and result ~= false then changed = changed + 1 else failed = failed + 1 end
                else
                    failed = failed + 1
                end
            end
        end
    end
    return changed, failed
end

function L:ApplyBars(bars)
    if type(bars) ~= "table" then return 0, 0 end
    local primary = rawget(_G, "HOTBAR_CATEGORY_PRIMARY") or 0
    local backup = rawget(_G, "HOTBAR_CATEGORY_BACKUP") or 1
    local c1,f1 = self:ApplyBar(primary, bars.primary or {})
    local c2,f2 = self:ApplyBar(backup, bars.backup or {})
    return c1+c2, f1+f2
end

function L:BuildGearOperations(gear)
    local ops = {}
    if type(gear) ~= "table" then return ops end
    for _,dest in ipairs(EQUIP_SLOTS) do
        if dest ~= nil and gear[tostring(dest)] then
            ops[#ops+1] = { destination = dest, entry = gear[tostring(dest)] }
        end
    end
    return ops
end

function L:ApplyGearSequential(gear, callback)
    if type(gear) ~= "table" then
        if callback then callback(0,0) end
        return
    end
    if type(RequestEquipItem) ~= "function" then
        if callback then callback(0,1) end
        return
    end

    local ops = self:BuildGearOperations(gear)
    local requested, missing = 0, 0
    local pos = 1

    local function finish()
        if callback then callback(requested, missing) end
    end

    local function step()
        if pos > #ops then finish(); return end
        local op = ops[pos]
        pos = pos + 1

        -- Re-find by unique id for every step because previous equip requests
        -- can move the replaced item into the backpack.
        local bag, slot, already = self:FindSavedItem(op.entry, op.destination)
        if already then
            if type(zo_callLater) == "function" then zo_callLater(step, 45) else step() end
            return
        end

        if bag ~= nil and slot ~= nil then
            local ok = pcall(RequestEquipItem, bag, slot, BAG_WORN, op.destination)
            if ok then requested = requested + 1 else missing = missing + 1 end
        else
            missing = missing + 1
        end

        -- Inventory/equipment updates are asynchronous. Spacing requests keeps
        -- ESO from dropping a multi-piece loadout swap when several slots move.
        if type(zo_callLater) == "function" then zo_callLater(step, 120) else step() end
    end

    step()
end

function L:Verify(index)
    local build = self:EnsureSaved()[index]
    if not build or not build.gear then return end
    local gearMatched, gearExpected = 0, 0
    for slotText,entry in pairs(build.gear) do
        local slot = tonumber(slotText)
        if slot then
            gearExpected = gearExpected + 1
            local uid = uniqueIdString(BAG_WORN, slot)
            if (entry.uniqueId and entry.uniqueId ~= "" and uid == entry.uniqueId)
                or ((not entry.uniqueId or entry.uniqueId == "") and self:EntryMatches(BAG_WORN, slot, entry)) then
                gearMatched = gearMatched + 1
            end
        end
    end

    local barsMatched, barsExpected = 0, 0
    local current = self:CaptureBars()
    for _,key in ipairs({"primary","backup"}) do
        for i,wanted in ipairs((build.bars and build.bars[key]) or {}) do
            barsExpected = barsExpected + 1
            if tonumber(current[key][i]) == tonumber(wanted) then barsMatched = barsMatched + 1 end
        end
    end

    local profile = build.build or {}
    local cpSlotMatched,cpSlotExpected,cpPointMatched,cpPointExpected = self:VerifyChampionProfile(profile.champion)
    local skillMatched,skillExpected = self:VerifySkillProfile(profile.skills)
    local attrs = profile.attributes
    local attrMatch = true
    local attrText = ""
    if type(attrs) == "table" then
        local now = self:CaptureAttributes()
        attrMatch = now.health == (tonumber(attrs.health) or 0) and now.magicka == (tonumber(attrs.magicka) or 0) and now.stamina == (tonumber(attrs.stamina) or 0)
        attrText = string.format(" | Attr H%d/M%d/S%d%s", tonumber(attrs.health) or 0, tonumber(attrs.magicka) or 0, tonumber(attrs.stamina) or 0, attrMatch and "" or " (profile differs)")
    end
    local cpSlotsComplete = cpSlotExpected == 0 or cpSlotMatched == cpSlotExpected
    local cpPointsComplete = cpPointExpected == 0 or cpPointMatched == cpPointExpected
    local skillsComplete = skillExpected == 0 or skillMatched == skillExpected
    local complete = gearMatched == gearExpected and barsMatched == barsExpected and cpSlotsComplete and cpPointsComplete and skillsComplete and attrMatch
    notify(string.format("BUILD %d %s: Gear %d/%d | Bars %d/%d | Skills %d/%d | CP Slots %d/%d | CP Profile %d/%d%s",
        index, complete and "CONFIRMED" or "PARTIAL", gearMatched, gearExpected, barsMatched, barsExpected, skillMatched, skillExpected,
        cpSlotMatched, cpSlotExpected, cpPointMatched, cpPointExpected, attrText), complete)
end

function L:Equip(index)
    index = tonumber(index)
    if not index or index < 1 or index > SLOT_COUNT then return false end
    if self.equipInProgress then
        notify("BUILD: another saved build is still being applied.", false)
        return false
    end
    if safe(IsUnitInCombat, false, "player") == true then
        notify("BUILD: leave combat before applying a saved build.", false)
        return false
    end
    local loadout = self:EnsureSaved()[index]
    if not loadout or not loadout.gear or not loadout.bars then
        notify(string.format("BUILD %d is empty. Save your current build first.", index), false)
        return false
    end

    self.equipInProgress = true
    self:SetActiveIndex(index)
    notify(string.format("BUILD %d LOADING: %s", index, tostring(loadout.name or ("Build "..index))), true)

    local function beginApply()
        self:ApplyGearSequential(loadout.gear, function(gearRequested, missing)
            local function applyBarsAndVerify()
                local barChanged, barFailed = self:ApplyBars(loadout.bars)
                local cpChanged, cpFailed = self:ApplyChampionSlots(loadout.build and loadout.build.champion)
                local unavailable = missing + barFailed + cpFailed

                if EPC.saved.loadoutEquipFood029272 ~= false and type(loadout.food) == "table" then
                    self:UseSavedFood(index)
                end

                if EPC.Maintenance then
                    if EPC.saved.loadoutChargeWeapons029272 == true and type(EPC.Maintenance.RechargeEquipped) == "function" then
                        pcall(EPC.Maintenance.RechargeEquipped, EPC.Maintenance, true)
                    end
                    if EPC.saved.loadoutRepairArmor029272 == true and type(EPC.Maintenance.RepairEquipped) == "function" then
                        pcall(EPC.Maintenance.RepairEquipped, EPC.Maintenance, true)
                    end
                end

                notify(string.format("BUILD %d: %d gear request%s | %d bar change%s | %d CP slot change%s%s",
                    index,
                    gearRequested, gearRequested==1 and "" or "s",
                    barChanged, barChanged==1 and "" or "s",
                    cpChanged, cpChanged==1 and "" or "s",
                    unavailable>0 and string.format(" | %d unavailable", unavailable) or ""),
                    unavailable==0)

                local function verifyDone()
                    self.equipInProgress = false
                    self:Verify(index)
                    if EPC.GearLoadoutOverlay and type(EPC.GearLoadoutOverlay.ScheduleRefresh) == "function" then
                        EPC.GearLoadoutOverlay:ScheduleRefresh(50)
                    end
                    self:RefreshUI()
                end
                if type(zo_callLater) == "function" then zo_callLater(verifyDone, 750) else verifyDone() end
            end
            if type(zo_callLater) == "function" then zo_callLater(applyBarsAndVerify, 180) else applyBarsAndVerify() end
        end)
    end

    -- If the bank is open, automatically withdraw any saved pieces that are in
    -- the bank before equipping. From normal gameplay this path is skipped.
    if safe(IsBankOpen, false) == true then
        self:WithdrawSetup(index, function()
            if type(zo_callLater) == "function" then zo_callLater(beginApply, 180) else beginApply() end
        end)
    else
        beginApply()
    end
    return true
end

function L:Clear(index)
    index = tonumber(index)
    if not index or index < 1 or index > SLOT_COUNT then return false end
    local all = self:EnsureSaved()
    local name = all[index].name or ("Build " .. index)
    all[index] = { name = name }
    if self:GetActiveIndex() == index then self:SetActiveIndex(0) end
    self:RebuildGearIndex()
    notify(string.format("BUILD %d CLEARED: %s", index, name), true)
    self:RefreshUI()
    return true
end

function L:SetName(index, name, silent)
    index = tonumber(index)
    if not index or index < 1 or index > SLOT_COUNT then return false end
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = "Build " .. index end
    name = string.sub(name, 1, 28)
    local all = self:EnsureSaved()
    all[index].name = name
    if silent ~= true then
        notify(string.format("BUILD %d RENAMED: %s", index, name), true)
    end
    self:RefreshUI()
    return true
end

function L:BeginRename(index)
    index = tonumber(index)
    local c = index and self.cards and self.cards[index]
    if not c or not c.edit then return end
    c.renaming = true
    if c.edit.SetEditEnabled then c.edit:SetEditEnabled(true) end
    self:AcquireUIMode(false)
    local function focusName()
        if not c.edit then return end
        if c.edit.SetEditEnabled then c.edit:SetEditEnabled(true) end
        c.edit:SetMouseEnabled(true)
        if c.edit.SetKeyboardEnabled then c.edit:SetKeyboardEnabled(true) end
        if c.edit.TakeFocus then c.edit:TakeFocus() end
        if c.edit.SelectAllText then c.edit:SelectAllText() end
    end
    focusName()
    if type(zo_callLater) == "function" then zo_callLater(focusName, 0) end
end


function L:GetGearDestinationForCursor(bag, slot)
    bag,slot = tonumber(bag),tonumber(slot)
    if bag == nil or slot == nil then return nil end
    if bag == BAG_WORN then return slot end
    local link = itemLink(bag, slot)
    if link == "" then return nil end
    local equipType = num(safe(GetItemLinkEquipType, 0, link)) or 0
    local shift = safe(IsShiftKeyDown, false) == true
    if equipType == rawget(_G,"EQUIP_TYPE_HEAD") then return EQUIP_SLOT_HEAD end
    if equipType == rawget(_G,"EQUIP_TYPE_SHOULDERS") then return EQUIP_SLOT_SHOULDERS end
    if equipType == rawget(_G,"EQUIP_TYPE_CHEST") then return EQUIP_SLOT_CHEST end
    if equipType == rawget(_G,"EQUIP_TYPE_HAND") then return EQUIP_SLOT_HAND end
    if equipType == rawget(_G,"EQUIP_TYPE_WAIST") then return EQUIP_SLOT_WAIST end
    if equipType == rawget(_G,"EQUIP_TYPE_LEGS") then return EQUIP_SLOT_LEGS end
    if equipType == rawget(_G,"EQUIP_TYPE_FEET") then return EQUIP_SLOT_FEET end
    if equipType == rawget(_G,"EQUIP_TYPE_NECK") then return EQUIP_SLOT_NECK end
    if equipType == rawget(_G,"EQUIP_TYPE_RING") then return shift and EQUIP_SLOT_RING2 or EQUIP_SLOT_RING1 end
    if equipType == rawget(_G,"EQUIP_TYPE_POISON") then return shift and EQUIP_SLOT_BACKUP_POISON or EQUIP_SLOT_POISON end
    if equipType == rawget(_G,"EQUIP_TYPE_OFF_HAND") then return shift and EQUIP_SLOT_BACKUP_OFF or EQUIP_SLOT_OFF_HAND end
    if equipType == rawget(_G,"EQUIP_TYPE_MAIN_HAND") or equipType == rawget(_G,"EQUIP_TYPE_ONE_HAND") or equipType == rawget(_G,"EQUIP_TYPE_TWO_HAND") then
        return shift and EQUIP_SLOT_BACKUP_MAIN or EQUIP_SLOT_MAIN_HAND
    end
    return nil
end

function L:DropGearOnSetup(index)
    index = tonumber(index)
    if not index then return false end
    local content = num(safe(GetCursorContentType, rawget(_G,"MOUSE_CONTENT_EMPTY") or 0)) or 0
    if content ~= rawget(_G,"MOUSE_CONTENT_INVENTORY_ITEM") and content ~= rawget(_G,"MOUSE_CONTENT_EQUIPPED_ITEM") then return false end
    local bag = num(safe(GetCursorBagId, nil))
    local slot = num(safe(GetCursorSlotIndex, nil))
    if bag == nil or slot == nil then return false end
    local dest = self:GetGearDestinationForCursor(bag, slot)
    if dest == nil then notify("LOADOUTS: that item cannot be assigned to a gear slot.", false); return false end
    local entry = self:MakeGearEntry(bag, slot)
    if not entry then return false end
    local setup = self:EnsureSaved()[index]
    setup.gear = type(setup.gear) == "table" and setup.gear or {}
    setup.gear[tostring(dest)] = entry
    if type(ClearCursor) == "function" then pcall(ClearCursor) end
    self:RebuildGearIndex()
    self:RefreshUI()
    notify(string.format("BUILD %d: gear slot updated. Hold Shift while dropping rings/weapons/poisons for the second/back slot.", index), true)
    return true
end

function L:SetFoodFromBagSlot(index, bag, slot)
    index = tonumber(index)
    if not index or bag == nil or slot == nil then return false end
    local food = self:MakeFoodEntry(bag, slot)
    if not food then notify("LOADOUTS: choose a food or drink item.", false); return false end
    self:EnsureSaved()[index].food = food
    EPC.saved.loadoutLastFoodItemId029272 = tonumber(food.itemId) or 0
    self:RefreshUI()
    local name = tostring(safe(GetItemLinkName, "", food.link) or "")
    if name == "" then name = "buff food" end
    notify(string.format("BUILD %d: saved food — %s.", index, name), true)
    return true
end

function L:GetBackpackFoodChoices()
    local out,seen = {},{}
    if BAG_BACKPACK == nil then return out end
    local size = num(safe(GetBagSize, 0, BAG_BACKPACK)) or 0
    for slot=0,size-1 do
        local food = self:MakeFoodEntry(BAG_BACKPACK, slot)
        if food and (tonumber(food.itemId) or 0) > 0 then
            local key = tostring(food.itemId)
            if not seen[key] then
                seen[key] = true
                food.bag,food.slot = BAG_BACKPACK,slot
                food.stack = math.max(1, num(safe(GetSlotStackSize, 1, BAG_BACKPACK, slot)) or 1)
                food.name = tostring(safe(GetItemLinkName, "", food.link) or safe(GetItemName, "Food / Drink", BAG_BACKPACK, slot) or "Food / Drink")
                out[#out+1] = food
            end
        end
    end
    table.sort(out, function(a,b) return string.lower(tostring(a.name or "")) < string.lower(tostring(b.name or "")) end)
    return out
end

function L:DropFoodOnSetup(index)
    index = tonumber(index)
    if not index then return false end
    local content = num(safe(GetCursorContentType, rawget(_G,"MOUSE_CONTENT_EMPTY") or 0)) or 0
    if content ~= rawget(_G,"MOUSE_CONTENT_INVENTORY_ITEM") then
        notify("LOADOUTS: click ADD FOOD to pick from your backpack, or drag a food/drink item onto it.", false)
        return false
    end
    local bag = num(safe(GetCursorBagId, nil))
    local slot = num(safe(GetCursorSlotIndex, nil))
    if bag == nil or slot == nil then return false end
    local ok = self:SetFoodFromBagSlot(index, bag, slot)
    if ok and type(ClearCursor) == "function" then pcall(ClearCursor) end
    return ok
end

function L:DropSkillOnSetup(index, barKey, position)
    index,position = tonumber(index),tonumber(position)
    if not index or not position then return false end
    if barKey ~= "primary" and barKey ~= "backup" then return false end
    if num(safe(GetCursorContentType, 0)) ~= rawget(_G,"MOUSE_CONTENT_ACTION") then return false end
    local abilityId = num(safe(GetCursorAbilityId, 0)) or 0
    if abilityId <= 0 then return false end
    local progression = rawget(_G,"SKILLS_DATA_MANAGER") and safe(SKILLS_DATA_MANAGER.GetProgressionDataByAbilityId, nil, SKILLS_DATA_MANAGER, abilityId) or nil
    if progression and type(progression.IsUltimate) == "function" then
        local isUltimate = safe(progression.IsUltimate, false, progression) == true
        if isUltimate ~= (position == 6) then
            notify(position == 6 and "LOADOUTS: only an Ultimate can be dropped in the last slot." or "LOADOUTS: Ultimates belong in the last slot.", false)
            return false
        end
    end
    local setup = self:EnsureSaved()[index]
    setup.bars = type(setup.bars) == "table" and setup.bars or {primary={},backup={}}
    setup.bars[barKey] = type(setup.bars[barKey]) == "table" and setup.bars[barKey] or {}
    setup.bars[barKey][position] = abilityId
    if type(ClearCursor) == "function" then pcall(ClearCursor) end
    self:RefreshUI()
    return true
end

function L:DragSavedSkillFromSetup(index, barKey, position)
    if safe(IsUnitInCombat, false, "player") == true then return false end
    local setup = self:EnsureSaved()[tonumber(index) or 0]
    local abilityId = setup and setup.bars and setup.bars[barKey] and tonumber(setup.bars[barKey][tonumber(position) or 0]) or 0
    if abilityId <= 0 or num(safe(GetCursorContentType, 0)) ~= (rawget(_G,"MOUSE_CONTENT_EMPTY") or 0) then return false end
    if type(GetSpecificSkillAbilityKeysByAbilityId) ~= "function" then return false end
    local t,l,a = safe(GetSpecificSkillAbilityKeysByAbilityId, nil, abilityId)
    if not tonumber(t) or tonumber(t) <= 0 then return false end
    local ok,result = pcall(CallSecureProtected, "PickupAbilityBySkillLine", t,l,a)
    if ok and result ~= false then
        setup.bars[barKey][position] = 0
        self:RefreshUI()
        return true
    end
    return false
end

local function encodeField(text)
    return (tostring(text or ""):gsub("([^%w%._%-])", function(ch) return string.format("%%%02X", string.byte(ch)) end))
end

local function decodeField(text)
    return (tostring(text or ""):gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex,16)) end))
end

local function splitPlain(text, sep)
    local out = {}
    text = tostring(text or "")
    if text == "" then return out end
    local start = 1
    while true do
        local pos = string.find(text, sep, start, true)
        if not pos then out[#out+1] = string.sub(text,start); break end
        out[#out+1] = string.sub(text,start,pos-1)
        start = pos + #sep
    end
    return out
end

function L:ExportSetup(index)
    index = tonumber(index)
    local setup = index and self:EnsureSaved()[index]
    if not setup or not self:IsFilled(index) then return "" end
    local fields = {"EASLOADOUT1", "name="..encodeField(setup.name or ("Build "..index))}
    local gearParts = {}
    for slotText,entry in pairs(setup.gear or {}) do
        if entry and tostring(entry.link or "") ~= "" then gearParts[#gearParts+1] = tostring(slotText).."~"..encodeField(entry.link) end
    end
    table.sort(gearParts)
    fields[#fields+1] = "gear="..table.concat(gearParts, ",")
    for _,pair in ipairs({{"p","primary"},{"b","backup"}}) do
        local ids = {}
        for i=1,6 do ids[i] = tostring(tonumber(setup.bars and setup.bars[pair[2]] and setup.bars[pair[2]][i]) or 0) end
        fields[#fields+1] = pair[1].."="..table.concat(ids, ",")
    end
    local champion = setup.build and setup.build.champion or {}
    local cpSlots = {}
    for slotText,id in pairs(champion.slots or {}) do cpSlots[#cpSlots+1] = tostring(slotText).."~"..tostring(tonumber(id) or 0) end
    table.sort(cpSlots)
    fields[#fields+1] = "cps="..table.concat(cpSlots, ",")
    local cpAlloc = {}
    for idText,points in pairs(champion.allocations or {}) do cpAlloc[#cpAlloc+1] = tostring(idText).."~"..tostring(tonumber(points) or 0) end
    table.sort(cpAlloc)
    fields[#fields+1] = "cpa="..table.concat(cpAlloc, ",")
    local attrs = setup.build and setup.build.attributes or {}
    fields[#fields+1] = string.format("attr=%d~%d~%d", tonumber(attrs.health) or 0, tonumber(attrs.magicka) or 0, tonumber(attrs.stamina) or 0)
    if type(setup.food) == "table" and (tonumber(setup.food.itemId) or 0) > 0 then
        fields[#fields+1] = "food="..tostring(tonumber(setup.food.itemId) or 0).."~"..encodeField(setup.food.link or "")
    end
    return table.concat(fields, ";")
end

local function decodeUrlComponent(text)
    text = tostring(text or "")
    text = string.gsub(text, "%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16) or 0)
    end)
    return text
end

function L:NormalizeESOHubImportText(text)
    text = tostring(text or "")

    -- ESO's edit controls can preserve CR/LF/TAB from browser clipboard data,
    -- and some browsers prepend UTF-8 BOM / zero-width characters. addondata is
    -- numeric/delimiter-only, so all of these are safe to remove before parsing.
    text = string.gsub(text, "\239\187\191", "") -- UTF-8 BOM
    text = string.gsub(text, "\226\128\139", "") -- U+200B zero-width space
    text = string.gsub(text, "\226\128\140", "") -- U+200C zero-width non-joiner
    text = string.gsub(text, "\226\128\141", "") -- U+200D zero-width joiner
    text = string.gsub(text, "\194\160", "")      -- non-breaking space

    local addonStart = string.find(string.lower(text), "addondata=", 1, true)
    if addonStart then
        text = string.sub(text, addonStart + 10)
        local amp = string.find(text, "&", 1, true)
        if amp then text = string.sub(text, 1, amp - 1) end
        text = decodeUrlComponent(text)
    end

    -- Raw addondata copied from a browser can wrap visually or actually contain
    -- clipboard whitespace. No valid field uses whitespace.
    text = string.gsub(text, "%s+", "")

    -- If the clipboard included a label/prefix, recover from the first canonical
    -- class;race;role;attributes sequence instead of rejecting the whole paste.
    local payloadStart = string.find(text, "%d+;%d+;%d+;%-?%d+:%-?%d+:%-?%d+;")
    if payloadStart and payloadStart > 1 then text = string.sub(text, payloadStart) end

    text = string.gsub(text, ";+$", "")
    return text
end

function L:ParseESOHubBuildString(text)
    text = self:NormalizeESOHubImportText(text)
    if text == "" then return nil, "empty clipboard text" end

    local p = splitPlain(text, ";")
    if #p ~= 15 then
        return nil, string.format("expected 15 sections, found %d", #p)
    end
    if not tonumber(p[1]) then return nil, "section 1 class is not numeric" end
    if not tonumber((splitPlain(p[2] or "", ","))[1]) then return nil, "section 2 race is not numeric" end
    if not tonumber(p[3]) then return nil, "section 3 role is not numeric" end

    local ah,am,as = string.match(p[4] or "", "^(%-?%d+):(%-?%d+):(%-?%d+)$")
    if not ah or not am or not as then return nil, "section 4 attributes are invalid" end

    return p, nil
end

function L:IsESOHubBuildString(text)
    local parts = self:ParseESOHubBuildString(text)
    return parts ~= nil
end

local function firstNumericToken(text)
    return tonumber(string.match(tostring(text or ""), "^(%-?%d+)")) or 0
end

function L:BuildImportedSkillProfileESOHub(primary, backup, passives, subclasses)
    local profile = {
        purchased = {}, purchasedCount = 0, unresolved = {},
        importedFrom = "ESOHUB", subclasses = {},
    }
    for _,v in ipairs(splitPlain(subclasses or "", ",")) do
        local id = tonumber(v)
        if id and id > 0 then profile.subclasses[#profile.subclasses+1] = id end
    end

    local seen = {}
    local function addToken(token)
        token = tostring(token or "")
        local abilityId = firstNumericToken(token)
        if abilityId <= 0 or seen[abilityId] then return end
        seen[abilityId] = true

        local skillType, skillLine, abilityIndex, morphSlot = 0,0,0,0
        if type(GetSpecificSkillAbilityKeysByAbilityId) == "function" then
            skillType, skillLine, abilityIndex, morphSlot = safe(GetSpecificSkillAbilityKeysByAbilityId, 0, abilityId)
            skillType, skillLine, abilityIndex, morphSlot =
                tonumber(skillType) or 0, tonumber(skillLine) or 0, tonumber(abilityIndex) or 0, tonumber(morphSlot) or 0
        end
        if skillType <= 0 or skillLine <= 0 or abilityIndex <= 0 then
            profile.unresolved[#profile.unresolved+1] = token
            return
        end

        local _,_,_,passive,ultimate,purchased,progressionIndex,rank =
            safe(GetSkillAbilityInfo, nil, skillType, skillLine, abilityIndex)
        local key = string.format("%d:%d:%d", skillType, skillLine, abilityIndex)
        profile.purchased[key] = {
            abilityId = abilityId,
            passive = passive == true,
            ultimate = ultimate == true,
            progressionIndex = tonumber(progressionIndex) or 0,
            rank = tonumber(rank) or 0,
            targetMorph = morphSlot,
            importedToken = token,
            alreadyPurchased = purchased == true,
        }
        profile.purchasedCount = profile.purchasedCount + 1
    end

    for _,field in ipairs({primary, backup, passives}) do
        for _,token in ipairs(splitPlain(field or "", ",")) do addToken(token) end
    end
    return profile
end

function L:BuildImportedGearESOHub(gearText)
    local gear = {}
    local weaponSlots = {
        [tonumber(rawget(_G,"EQUIP_SLOT_MAIN_HAND")) or -1001]=true,
        [tonumber(rawget(_G,"EQUIP_SLOT_OFF_HAND")) or -1002]=true,
        [tonumber(rawget(_G,"EQUIP_SLOT_BACKUP_MAIN")) or -1003]=true,
        [tonumber(rawget(_G,"EQUIP_SLOT_BACKUP_OFF")) or -1004]=true,
    }
    local poisonSlots = {
        [tonumber(rawget(_G,"EQUIP_SLOT_POISON")) or -1101]=true,
        [tonumber(rawget(_G,"EQUIP_SLOT_BACKUP_POISON")) or -1102]=true,
    }
    local jewelrySlots = {
        [tonumber(rawget(_G,"EQUIP_SLOT_NECK")) or -1201]=true,
        [tonumber(rawget(_G,"EQUIP_SLOT_RING1")) or -1202]=true,
        [tonumber(rawget(_G,"EQUIP_SLOT_RING2")) or -1203]=true,
    }

    for _,rawEntry in ipairs(splitPlain(gearText or "", ",")) do
        local parts = splitPlain(rawEntry, ":")
        local equipSlot = tonumber(parts[1])
        if equipSlot ~= nil then
            if poisonSlots[equipSlot] then
                local itemId, secondId = tonumber(parts[2]) or 0, tonumber(parts[3]) or 0
                if itemId > 0 then
                    gear[tostring(equipSlot)] = {
                        uniqueId = "", itemId = itemId,
                        link = string.format("ESO-Hub poison %d", itemId),
                        signature = {itemId=itemId,equipType=0,traitType=0,weaponType=0,armorType=0,setId=0},
                        esohubSpec = {slot=equipSlot,itemId=itemId,secondId=secondId},
                    }
                end
            else
                local itemType = tonumber(parts[2]) or 0
                local setId = tonumber(parts[3]) or 0
                local trait = tonumber(parts[4]) or 0
                local enchant = tonumber(parts[5]) or 0
                local sig = {itemId=0,equipType=0,traitType=trait,weaponType=0,armorType=0,setId=setId}
                if weaponSlots[equipSlot] then sig.weaponType = itemType
                elseif not jewelrySlots[equipSlot] then sig.armorType = itemType end
                gear[tostring(equipSlot)] = {
                    uniqueId = "", itemId = 0,
                    link = string.format("ESO-Hub gear: set %d / trait %d", setId, trait),
                    signature = sig,
                    esohubSpec = {slot=equipSlot,itemType=itemType,setId=setId,traitType=trait,enchantId=enchant},
                }
            end
        end
    end
    return gear
end

function L:ImportESOHubSetup(index, text)
    index = tonumber(index)
    if not index or index < 1 or index > SLOT_COUNT then return false end
    local raw = self:NormalizeESOHubImportText(text)
    local p, parseError = self:ParseESOHubBuildString(raw)
    if not p then
        self.lastESOHubImportError029781 = tostring(parseError or "unrecognized format")
        return false
    end
    self.lastESOHubImportError029781 = nil
    local classId = tonumber(p[1]) or 0
    local raceId = firstNumericToken(p[2])
    local role = tonumber(p[3]) or 0
    local ah,am,as = string.match(p[4] or "", "^(%-?%d+):(%-?%d+):(%-?%d+)$")
    ah,am,as = tonumber(ah) or 0, tonumber(am) or 0, tonumber(as) or 0

    local bars = {primary={},backup={}}
    for i,v in ipairs(splitPlain(p[8] or "", ",")) do if i <= 6 then bars.primary[i] = firstNumericToken(v) end end
    for i,v in ipairs(splitPlain(p[9] or "", ",")) do if i <= 6 then bars.backup[i] = firstNumericToken(v) end end
    for i=1,6 do bars.primary[i]=tonumber(bars.primary[i]) or 0; bars.backup[i]=tonumber(bars.backup[i]) or 0 end

    local champion = {
        slots = {}, allocations = {}, slottedCount = 0,
        allocationCount = 0, allocatedPoints = 0, importedFrom = "ESOHUB",
    }
    local firstSlot,lastSlot = self:GetChampionSlots()
    local slotValues = splitPlain(p[11] or "", ",")
    for i=1,math.min(#slotValues, math.max(0,lastSlot-firstSlot+1)) do
        local id = tonumber(slotValues[i]) or 0
        local slot = firstSlot + i - 1
        champion.slots[tostring(slot)] = id
        if id > 0 then champion.slottedCount = champion.slottedCount + 1 end
    end
    champion.firstSlot, champion.lastSlot = firstSlot,lastSlot
    for _,pair in ipairs(splitPlain(p[12] or "", ",")) do
        local id,points = string.match(pair, "^(%d+):(%d+)$")
        id,points = tonumber(id),tonumber(points)
        if id and points and id > 0 and points > 0 then
            champion.allocations[tostring(id)] = points
            champion.allocationCount = champion.allocationCount + 1
            champion.allocatedPoints = champion.allocatedPoints + points
        end
    end

    local skills = self:BuildImportedSkillProfileESOHub(p[8], p[9], p[10], p[7])
    local gear = self:BuildImportedGearESOHub(p[13])
    local foodId = firstNumericToken(p[14])
    local potionId = firstNumericToken(p[15])
    local potionSecondId = tonumber(string.match(tostring(p[15] or ""), "^%d+:(%d+)")) or 0

    local className = ""
    if classId > 0 and type(GetClassName) == "function" then
        className = tostring(safe(GetClassName, "", rawget(_G,"GENDER_MALE") or 2, classId) or "")
    end
    local setupName = className ~= "" and ("ESO-Hub "..className) or "ESO-Hub Build"

    local setup = {
        name = setupName,
        gear = gear,
        bars = bars,
        build = {
            version = 3,
            attributes = {health=ah,magicka=am,stamina=as,total=ah+am+as},
            champion = champion,
            skills = skills,
        },
        food = foodId > 0 and {itemId=foodId,link="",icon=""} or nil,
        potion = potionId > 0 and {itemId=potionId,secondId=potionSecondId} or nil,
        savedAt = safe(GetTimeStamp, 0) or 0,
        imported = {
            source = "ESOHUB", raw = raw, classId = classId, raceId = raceId,
            role = role, curseId = tonumber(p[5]) or 0, mundusId = tonumber(p[6]) or 0,
            subclasses = p[7] or "",
        },
    }

    self:EnsureSaved()[index] = setup
    self:RebuildGearIndex()
    self:RefreshUI()

    local unresolved = type(skills.unresolved) == "table" and #skills.unresolved or 0
    local gearCount = 0
    for _ in pairs(gear) do gearCount = gearCount + 1 end

    local mismatch = {}
    local currentClass = num(safe(GetUnitClassId, 0, "player")) or 0
    local currentRace = num(safe(GetUnitRaceId, 0, "player")) or 0
    if currentClass > 0 and classId > 0 and currentClass ~= classId then
        mismatch[#mismatch+1] = string.format("class %d required (you are %d)", classId, currentClass)
    end
    if currentRace > 0 and raceId > 0 and currentRace ~= raceId then
        mismatch[#mismatch+1] = string.format("race %d required (you are %d)", raceId, currentRace)
    end

    local suffix = ""
    if unresolved > 0 then suffix = suffix .. string.format(" | %d skill IDs unresolved", unresolved) end
    if #mismatch > 0 then suffix = suffix .. " | WARNING: " .. table.concat(mismatch, "; ") end
    notify(string.format(
        "BUILD %d imported from ESO-Hub: %d skills, %d gear slots, %d CP stars%s.",
        index, tonumber(skills.purchasedCount) or 0, gearCount, tonumber(champion.allocationCount) or 0, suffix
    ), unresolved == 0 and #mismatch == 0)
    return true
end

function L:ImportSetup(index, text)
    index = tonumber(index)
    text = tostring(text or "")
    if index and index >= 1 and index <= SLOT_COUNT and string.sub(text,1,11) ~= "EASLOADOUT1" then
        if self:ImportESOHubSetup(index, text) then return true end
    end
    if not index or index < 1 or index > SLOT_COUNT or string.sub(text,1,11) ~= "EASLOADOUT1" then
        local why = tostring(self.lastESOHubImportError029781 or "")
        notify("LOADOUTS: invalid setup code." .. (why ~= "" and (" ESO-Hub parser: " .. why .. ".") or "") .. " Paste an EASLOADOUT1 code or ESO-Hub addondata.", false)
        return false
    end
    local data = {}
    for _,part in ipairs(splitPlain(text,";")) do
        local eq = string.find(part,"=",1,true)
        if eq then data[string.sub(part,1,eq-1)] = string.sub(part,eq+1) end
    end
    local setup = {
        name = decodeField(data.name or "") ~= "" and decodeField(data.name) or ("Build "..index),
        gear = {}, bars = {primary={},backup={}},
        build = {version=2, attributes={health=0,magicka=0,stamina=0,total=0}, champion={slots={},allocations={},slottedCount=0,allocationCount=0,allocatedPoints=0}, skills={purchased={},purchasedCount=0}},
        savedAt = safe(GetTimeStamp, 0) or 0,
    }
    for _,part in ipairs(splitPlain(data.gear or "",",")) do
        local a,b = string.match(part,"^(%-?%d+)~(.+)$")
        local slot = tonumber(a); local link = b and decodeField(b) or ""
        if slot and link ~= "" then
            setup.gear[tostring(slot)] = {uniqueId="", link=link, itemId=num(safe(GetItemLinkItemId,0,link)) or 0, signature=self:GetGearSignature(link)}
        end
    end
    for key,barKey in pairs({p="primary",b="backup"}) do
        for i,idText in ipairs(splitPlain(data[key] or "",",")) do if i <= 6 then setup.bars[barKey][i] = tonumber(idText) or 0 end end
    end
    local champ = setup.build.champion
    for _,part in ipairs(splitPlain(data.cps or "",",")) do
        local slot,id = string.match(part,"^(%-?%d+)~(%-?%d+)$")
        if slot then champ.slots[tostring(tonumber(slot))] = tonumber(id) or 0; if (tonumber(id) or 0) > 0 then champ.slottedCount=champ.slottedCount+1 end end
    end
    for _,part in ipairs(splitPlain(data.cpa or "",",")) do
        local id,points = string.match(part,"^(%-?%d+)~(%-?%d+)$")
        if id and (tonumber(points) or 0) > 0 then champ.allocations[tostring(tonumber(id))]=tonumber(points); champ.allocationCount=champ.allocationCount+1; champ.allocatedPoints=champ.allocatedPoints+(tonumber(points) or 0) end
    end
    local ah,am,as = string.match(data.attr or "","^(%-?%d+)~(%-?%d+)~(%-?%d+)$")
    if ah then setup.build.attributes={health=tonumber(ah) or 0,magicka=tonumber(am) or 0,stamina=tonumber(as) or 0,total=(tonumber(ah) or 0)+(tonumber(am) or 0)+(tonumber(as) or 0)} end
    local foodId,foodLink = string.match(data.food or "","^(%d+)~(.+)$")
    if foodId then setup.food={itemId=tonumber(foodId) or 0,link=decodeField(foodLink),icon=itemIconFromLink(decodeField(foodLink))} end
    self:EnsureSaved()[index] = setup
    self:RebuildGearIndex()
    self:RefreshUI()
    notify(string.format("BUILD %d imported: %s", index, setup.name), true)
    return true
end

function L:CreateTransferDialog()
    if self.transferWindow then return end
    local win = wm:CreateTopLevelWindow("EAS_LoadoutTransfer")
    win:SetDimensions(580, 290); win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0); win:SetHidden(true); win:SetMouseEnabled(true); win:SetMovable(true)
    raiseLoadoutModal(win, 12500)
    local bg = wm:CreateControl("EAS_LoadoutTransferBG", win, CT_BACKDROP); bg:SetAnchorFill(win); bg:SetCenterColor(0.01,0.02,0.03,0.99); bg:SetEdgeColor(0.30,0.56,0.82,0.95); bg:SetEdgeTexture(nil,1,1,1)
    local title = wm:CreateControl("EAS_LoadoutTransferTitle", win, CT_LABEL); title:SetFont("ZoFontWinH2"); title:SetAnchor(TOPLEFT,win,TOPLEFT,16,12); title:SetDimensions(500,28); self.transferTitle=title
    local editBG = wm:CreateControl("EAS_LoadoutTransferEditBG", win, CT_BACKDROP); editBG:SetAnchor(TOPLEFT,win,TOPLEFT,16,50); editBG:SetDimensions(548,170); editBG:SetCenterColor(0.02,0.03,0.04,0.95); editBG:SetEdgeColor(0.22,0.34,0.48,0.9); editBG:SetEdgeTexture(nil,1,1,1)
    local edit = wm:CreateControl("EAS_LoadoutTransferEdit", editBG, CT_EDITBOX); edit:SetAnchor(TOPLEFT,editBG,TOPLEFT,8,8); edit:SetDimensions(532,154); edit:SetFont("ZoFontGameSmall"); edit:SetMultiLine(true); edit:SetMaxInputChars(16000); edit:SetMouseEnabled(true); if edit.SetKeyboardEnabled then edit:SetKeyboardEnabled(true) end; if edit.SetCopyEnabled then edit:SetCopyEnabled(true) end; if edit.SetPasteEnabled then edit:SetPasteEnabled(true) end; self.transferEdit=edit
    local function transferButton(name, text, handler)
        local b = wm:CreateControl(name, win, CT_BUTTON)
        b:SetFont("ZoFontGameBold"); b:SetText(text)
        if b.SetHorizontalAlignment then b:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
        if b.SetVerticalAlignment then b:SetVerticalAlignment(TEXT_ALIGN_CENTER) end
        b:SetHandler("OnClicked", handler)
        return b
    end
    local apply = transferButton("EAS_LoadoutTransferApply","IMPORT",function() if self.transferIndex then self:ImportSetup(self.transferIndex,edit:GetText()); win:SetHidden(true) end end); apply:SetAnchor(BOTTOMLEFT,win,BOTTOMLEFT,16,-16); apply:SetDimensions(120,30); self.transferApply=apply
    local close = transferButton("EAS_LoadoutTransferClose","CLOSE",function() win:SetHidden(true) end); close:SetAnchor(BOTTOMRIGHT,win,BOTTOMRIGHT,-16,-16); close:SetDimensions(120,30)
    self.transferWindow=win
    self:AttachRawHotkeyCapture(win)
end

function L:ShowExport(index)
    self:HideSetupPopup()
    self:CreateTransferDialog(); self.transferIndex=index; self.transferTitle:SetText("EXPORT SETUP — COPY THIS CODE"); self.transferEdit:SetText(self:ExportSetup(index)); self.transferApply:SetHidden(true); self.transferWindow:SetHidden(false); self:RaiseModal(self.transferWindow, 12500); self.transferEdit:TakeFocus(); if self.transferEdit.SelectAllText then self.transferEdit:SelectAllText() end
end

function L:ShowImport(index)
    self:HideSetupPopup()
    self:CreateTransferDialog(); self.transferIndex=index; self.transferTitle:SetText("IMPORT — EAS OR ESO-HUB CODE / URL"); self.transferEdit:SetText(""); self.transferApply:SetHidden(false); self.transferWindow:SetHidden(false); self:RaiseModal(self.transferWindow, 12500); self.transferEdit:TakeFocus()
end

function L:FindPrebuffAbility(preset)
    local spec = {
        ACCELERATION = {needUltimate=false, patterns={"acceleration","accelerate"}},
        DESTRO_ULT = {needUltimate=true, patterns={"elemental rage","eye of the storm","elemental storm"}, linePattern="destruction"},
        MANEUVER = {needUltimate=false, patterns={"maneuver","manoeuvre"}},
        SIEGE_SHIELD = {needUltimate=false, patterns={"siege shield","propelling shield"}},
    }
    spec = spec[preset]
    if not spec then return 0 end
    local best = 0
    local types = num(safe(GetNumSkillTypes,0)) or 0
    for t=1,types do
        local lines = num(safe(GetNumSkillLines,0,t)) or 0
        for l=1,lines do
            local lineName = ""
            if type(GetSkillLineInfo) == "function" then lineName = string.lower(tostring(safe(GetSkillLineInfo,"",t,l) or "")) end
            local abilities = num(safe(GetNumSkillAbilities,0,t,l)) or 0
            for a=1,abilities do
                local _,_,_,_,isUltimate,purchased = safe(GetSkillAbilityInfo,nil,t,l,a)
                if purchased == true and (isUltimate == true) == spec.needUltimate then
                    local id = num(safe(GetSkillAbilityId,0,t,l,a,false)) or 0
                    local name = string.lower(tostring(safe(GetAbilityName,"",id) or ""))
                    local matched = false
                    for _,pattern in ipairs(spec.patterns) do if string.find(name,pattern,1,true) then matched=true break end end
                    if matched and (not spec.linePattern or string.find(lineName,spec.linePattern,1,true)) then return id end
                    if matched then best=id end
                end
            end
        end
    end
    return best
end

function L:RestorePrebuff()
    local c = self.prebuffCache
    if not c then return false end
    self.prebuffCache = nil
    local wanted = tonumber(c.abilityId) or 0
    local current = num(safe(GetSlotBoundId,0,c.slot,c.category)) or 0
    if current == wanted then
        if (tonumber(c.originalId) or 0) <= 0 then
            pcall(CallSecureProtected,"ClearSlot",c.slot,c.category)
        else
            local idx = self:GetAbilityIndexForSavedId(c.originalId)
            if idx > 0 then pcall(CallSecureProtected,"SelectSlotAbility",idx,c.slot,c.category) end
        end
    end
    return true
end

function L:PreparePrebuff(preset)
    if safe(IsUnitInCombat,false,"player") == true then notify("PREBUFF: leave combat first.",false); return false end
    if self.prebuffCache then self:RestorePrebuff() end
    local abilityId = self:FindPrebuffAbility(preset)
    if abilityId <= 0 then notify("PREBUFF: the required purchased skill was not found on this character.",false); return false end
    local slots = self:GetActionSlots()
    local slot = preset == "DESTRO_ULT" and slots[#slots] or slots[1]
    local category = num(safe(GetActiveHotbarCategory, rawget(_G,"HOTBAR_CATEGORY_PRIMARY") or 0)) or (rawget(_G,"HOTBAR_CATEGORY_PRIMARY") or 0)
    local originalId = num(safe(GetSlotBoundId,0,slot,category)) or 0
    if originalId == abilityId then notify("PREBUFF: that skill is already on the active bar.",true); return true end
    local abilityIndex = self:GetAbilityIndexForSavedId(abilityId)
    if abilityIndex <= 0 then notify("PREBUFF: could not resolve that skill for the hotbar.",false); return false end
    local ok,result = pcall(CallSecureProtected,"SelectSlotAbility",abilityIndex,slot,category)
    if ok and result ~= false then
        self.prebuffCache={preset=preset,slot=slot,category=category,originalId=originalId,abilityId=abilityId}
        notify("PREBUFF READY: use the temporarily slotted skill; your previous slot will restore after it fires.",true)
        return true
    end
    return false
end

function L:OnPrebuffAbilityUsed(_, slotIndex)
    local c=self.prebuffCache
    if not c or tonumber(slotIndex) ~= tonumber(c.slot) then return end
    if type(zo_callLater)=="function" then zo_callLater(function() self:RestorePrebuff() end,700) else self:RestorePrebuff() end
end

function L:RefillActivePoisonSlot(slotId)
    if EPC.saved.loadoutRefillPoisons029272 ~= true then return false end
    local active = self:GetActiveIndex()
    if active <= 0 then return false end
    local setup = self:EnsureSaved()[active]
    local entry = setup and setup.gear and setup.gear[tostring(slotId)]
    if not entry then return false end
    local bag,slot,already = self:FindSavedItem(entry,slotId)
    if already then return true end
    if bag == BAG_BACKPACK and slot ~= nil then
        local ok = pcall(RequestEquipItem,bag,slot,BAG_WORN,slotId)
        return ok == true
    end
    return false
end

function L:OnWornInventoryUpdate(_, bagId, slotId)
    if bagId ~= BAG_WORN then return end
    if slotId ~= EQUIP_SLOT_POISON and slotId ~= EQUIP_SLOT_BACKUP_POISON then return end
    if EPC.saved.loadoutRefillPoisons029272 ~= true then return end
    local stack = num(safe(GetSlotStackSize,0,BAG_WORN,slotId)) or 0
    if stack > 0 then return end
    if type(zo_callLater)=="function" then zo_callLater(function() self:RefillActivePoisonSlot(slotId) end,120) else self:RefillActivePoisonSlot(slotId) end
end

function L:IsRaidContext()
    if safe(IsPlayerInRaid,false) == true then return true end
    local groupSize = num(safe(GetGroupSize,0)) or 0
    return groupSize > 4 and safe(IsUnitInDungeon,false,"player") == true
end

function L:OnPlayerActivated()
    local pageId = self:GetPageForCurrentZone()
    if pageId then self:SetCurrentPage(pageId,true) end
    if EPC.saved.loadoutAutoEquipRaids029272 ~= true or not self:IsRaidContext() then return end
    local page = self:GetCurrentPage()
    local index = tonumber(page.zoneAutoSlot) or 0
    if index > 0 and self:IsFilled(index) and self:GetActiveIndex() ~= index then
        if type(zo_callLater)=="function" then zo_callLater(function() if not safe(IsUnitInCombat,false,"player") then self:Equip(index) end end,450) else self:Equip(index) end
    end
end

function L:OnBossesChanged()
    if EPC.saved.loadoutAutoEquipRaids029272 ~= true or not self:IsRaidContext() then return end
    local boss = self:GetCurrentBossName()
    if boss == "" then return end
    local page = self:GetCurrentPage()
    local index = tonumber(page.bossRules and page.bossRules[boss]) or 0
    if index <= 0 or not self:IsFilled(index) or self:GetActiveIndex() == index then return end
    if safe(IsUnitInCombat,false,"player") == true then self.pendingRaidAutoIndex=index; return end
    if type(zo_callLater)=="function" then zo_callLater(function() if not safe(IsUnitInCombat,false,"player") then self:Equip(index) end end,250) else self:Equip(index) end
end

function L:OnCombatState(_, inCombat)
    if inCombat or not self.pendingRaidAutoIndex then return end
    local index=self.pendingRaidAutoIndex; self.pendingRaidAutoIndex=nil
    if EPC.saved.loadoutAutoEquipRaids029272 == true and self:IsRaidContext() and self:IsFilled(index) then
        if type(zo_callLater)=="function" then zo_callLater(function() self:Equip(index) end,300) else self:Equip(index) end
    end
end

function L:HideSetupPopup()
    if self.setupPopup then self.setupPopup:SetHidden(true) end
end

function L:CreateSetupPopup()
    if self.setupPopup then return self.setupPopup end
    local popup=wm:CreateTopLevelWindow("EAS_LoadoutSetupPopup")
    popup:SetDimensions(270,360)
    popup:SetHidden(true)
    popup:SetMouseEnabled(true)
    popup:SetClampedToScreen(true)
    raiseLoadoutModal(popup, 12000)

    local bg=wm:CreateControl("EAS_LoadoutSetupPopupBG",popup,CT_BACKDROP)
    bg:SetAnchorFill(popup)
    bg:SetCenterColor(0.008,0.014,0.024,0.995)
    bg:SetEdgeColor(0.34,0.58,0.82,0.98)
    bg:SetEdgeTexture(nil,1,1,1)

    popup.rows={}
    for rowIndex=1,12 do
        local row=wm:CreateControl("EAS_LoadoutSetupPopupRow"..rowIndex,popup,CT_BUTTON)
        row:SetAnchor(TOPLEFT,popup,TOPLEFT,7,7+(rowIndex-1)*30)
        row:SetDimensions(256,28)
        row:SetFont("ZoFontGameBold")
        if row.SetHorizontalAlignment then row:SetHorizontalAlignment(TEXT_ALIGN_LEFT) end
        if row.SetVerticalAlignment then row:SetVerticalAlignment(TEXT_ALIGN_CENTER) end
        row:SetHidden(true)
        local rowBG=wm:CreateControl("EAS_LoadoutSetupPopupRowBG"..rowIndex,row,CT_BACKDROP)
        rowBG:SetAnchorFill(row)
        rowBG:SetCenterColor(0.025,0.040,0.060,0.96)
        rowBG:SetEdgeColor(0.16,0.29,0.43,0.88)
        rowBG:SetEdgeTexture(nil,1,1,1)
        if rowBG.SetDrawLevel then rowBG:SetDrawLevel(0) end
        row:SetHandler("OnMouseEnter",function() rowBG:SetCenterColor(0.055,0.095,0.135,0.99) end)
        row:SetHandler("OnMouseExit",function() rowBG:SetCenterColor(0.025,0.040,0.060,0.96) end)
        popup.rows[rowIndex]={button=row,bg=rowBG}
    end
    self.setupPopup=popup
    self:AttachRawHotkeyCapture(popup)
    return popup
end

function L:ShowSetupMenu(index, anchor)
    index=tonumber(index) or 0
    if index < 1 or index > SLOT_COUNT then return end
    local items={
        {"EQUIP SETUP",function() self:Equip(index) end},
        {"CHECK MISSING ITEMS",function() self:CheckMissing(index) end},
        {"SET AS RAID ENTRY",function() self:SetZoneAutoSlot(index) end},
    }
    if self:GetCurrentBossName() ~= "" then items[#items+1]={"BIND TO CURRENT BOSS",function() self:BindSetupToCurrentBoss(index) end} end
    items[#items+1]={"WITHDRAW FROM BANK",function() self:WithdrawSetup(index) end}
    items[#items+1]={"DEPOSIT TO BANK",function() self:DepositSetup(index) end}
    local setup = self:EnsureSaved()[index]
    if setup and type(setup.food) == "table" then
        items[#items+1]={"USE SAVED FOOD NOW",function() self:UseSavedFood(index) end}
    end
    items[#items+1]={"EXPORT SETUP",function() self:ShowExport(index) end}
    items[#items+1]={"IMPORT SETUP",function() self:ShowImport(index) end}
    items[#items+1]={"RENAME SETUP",function() self:BeginRename(index) end}
    items[#items+1]={self.pendingClear and self.pendingClear[index] and "CONFIRM CLEAR" or "CLEAR SETUP",function() self:RequestClear(index) end}

    local popup=self:CreateSetupPopup()
    for rowIndex,rowData in ipairs(popup.rows or {}) do
        local item=items[rowIndex]
        local row=rowData.button
        row:SetDimensions(256,28)
        if item then
            local action=item[2]
            row:SetText("  "..item[1])
            row:SetHidden(false)
            row:SetHandler("OnClicked",function()
                self:HideSetupPopup()
                action()
            end)
        else
            row:SetHidden(true)
            row:SetHandler("OnClicked",function() end)
        end
    end
    popup:SetDimensions(270,14+#items*30)
    popup:ClearAnchors()
    local guiW,guiH=GuiRoot:GetDimensions()
    guiW=tonumber(guiW) or 1920
    guiH=tonumber(guiH) or 1080
    local x,y=math.floor(guiW*0.5-135),math.floor(guiH*0.5-(14+#items*30)*0.5)
    if anchor and type(anchor.GetLeft)=="function" then
        x=(tonumber(anchor:GetLeft()) or x)+(tonumber(anchor:GetWidth()) or 0)-270
        y=(tonumber(anchor:GetTop()) or y)+(tonumber(anchor:GetHeight()) or 0)+4
    end
    x=math.max(6,math.min(guiW-276,x))
    y=math.max(6,math.min(guiH-(20+#items*30),y))
    popup:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
    popup:SetHidden(false)
    self:RaiseModal(popup, 12000)
end

function L:ShowFoodPicker(index, anchor)
    index = tonumber(index) or 0
    if index < 1 or index > SLOT_COUNT then return false end
    local foods = self:GetBackpackFoodChoices()
    if #foods == 0 then
        notify("LOADOUTS: no food or drink was found in your backpack. Put the food in your backpack first.", false)
        return false
    end

    local setup = self:EnsureSaved()[index]
    local items = {}
    local reserveClear = setup and type(setup.food) == "table" and 1 or 0
    local maxFoods = 12 - reserveClear
    for i=1,math.min(#foods,maxFoods) do
        local food = foods[i]
        local label = tostring(food.name or "Food / Drink")
        if #label > 27 then label = string.sub(label,1,24) .. "..." end
        label = string.format("%s  x%d", label, tonumber(food.stack) or 1)
        items[#items+1] = {label,function() self:SetFoodFromBagSlot(index,food.bag,food.slot) end}
    end
    if reserveClear == 1 then
        items[#items+1] = {"CLEAR SAVED FOOD",function()
            self:EnsureSaved()[index].food = nil
            self:RefreshUI()
            notify(string.format("BUILD %d: saved food cleared.", index), true)
        end}
    end

    local popup = self:CreateSetupPopup()
    for rowIndex,rowData in ipairs(popup.rows or {}) do
        local item = items[rowIndex]
        local row = rowData.button
        if item then
            local action = item[2]
            row:SetText("  " .. item[1])
            row:SetHidden(false)
            row:SetHandler("OnClicked",function()
                self:HideSetupPopup()
                action()
            end)
        else
            row:SetHidden(true)
            row:SetHandler("OnClicked",function() end)
        end
    end

    popup:SetDimensions(300,14+#items*30)
    for _,rowData in ipairs(popup.rows or {}) do rowData.button:SetDimensions(286,28) end
    popup:ClearAnchors()
    local guiW,guiH = GuiRoot:GetDimensions()
    guiW,guiH = tonumber(guiW) or 1920, tonumber(guiH) or 1080
    local x,y = math.floor(guiW*0.5-150),math.floor(guiH*0.5-(14+#items*30)*0.5)
    if anchor and type(anchor.GetLeft)=="function" then
        x=(tonumber(anchor:GetLeft()) or x)+(tonumber(anchor:GetWidth()) or 0)-300
        y=(tonumber(anchor:GetTop()) or y)+(tonumber(anchor:GetHeight()) or 0)+4
    end
    x=math.max(6,math.min(guiW-306,x))
    y=math.max(6,math.min(guiH-(20+#items*30),y))
    popup:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
    popup:SetHidden(false)
    self:RaiseModal(popup, 12000)
    if #foods > maxFoods then
        notify(string.format("LOADOUTS: showing %d of %d food/drink types. You can also drag any food directly onto ADD FOOD.", maxFoods, #foods), true)
    end
    return true
end

function L:EnsureWindowSaved()
    EPC.saved = EPC.saved or {}
    EPC.saved.savedLoadoutWindow = EPC.saved.savedLoadoutWindow or {}
    local s = EPC.saved.savedLoadoutWindow
    -- Layout v4 is a compact ESO-style workspace. Four build cards remain
    -- visible at once, but every internal region now reflows from the live
    -- window/card dimensions so text and controls cannot overlap.
    if (tonumber(s.layoutVersion) or 0) < 4 then
        s.width = 900
        s.height = 590
        s.layoutVersion = 4
    end
    s.width = tonumber(s.width) or 900
    s.height = tonumber(s.height) or 590
    return s
end

function L:GetAbilityIconPath(savedId)
    savedId = tonumber(savedId) or 0
    if savedId <= 0 then return "" end
    local icon = ""
    if type(GetAbilityIcon) == "function" then
        icon = safe(GetAbilityIcon, "", savedId) or ""
    end
    if icon == "" then
        local data = self:GetSkillDataForSavedId(savedId)
        if data then
            if type(data.GetIcon) == "function" then
                icon = safe(data.GetIcon, "", data) or ""
            end
            if icon == "" and type(data.GetCurrentSkillProgressionKey) == "function" and type(data.GetSkillProgressionData) == "function" then
                local progressionKey = safe(data.GetCurrentSkillProgressionKey, nil, data)
                local progressionData = progressionKey and safe(data.GetSkillProgressionData, nil, data, progressionKey) or nil
                if progressionData and type(progressionData.GetIcon) == "function" then
                    icon = safe(progressionData.GetIcon, "", progressionData) or ""
                end
            end
        end
    end
    return icon or ""
end

function L:UpdateSkillIcons(iconList, barData)
    for idx,holder in ipairs(iconList or {}) do
        local savedId = tonumber((barData or {})[idx]) or 0
        if savedId > 0 then
            local icon = self:GetAbilityIconPath(savedId)
            if icon ~= "" then
                holder.icon:SetTexture(icon)
                holder.icon:SetHidden(false)
                holder.frame:SetEdgeColor(0.30, 0.56, 0.82, 0.82)
            else
                holder.icon:SetHidden(true)
                holder.frame:SetEdgeColor(0.26, 0.20, 0.20, 0.75)
            end
        else
            holder.icon:SetHidden(true)
            holder.frame:SetEdgeColor(0.18, 0.24, 0.32, 0.68)
        end
    end
end

function L:GetDefaultWindowAnchor()
    local guiW, guiH = GuiRoot:GetDimensions()
    guiW = tonumber(guiW) or 1920
    guiH = tonumber(guiH) or 1080
    local width, height = 900, 590
    local x = math.floor((guiW - width) * 0.5 + 150)
    local y = math.floor((guiH - height) * 0.5)

    local journal = EPC and EPC.Journal and EPC.Journal.window
    if journal and type(journal.IsHidden) == "function" and journal:IsHidden() == false then
        local jl, jt = tonumber(journal:GetLeft()) or 0, tonumber(journal:GetTop()) or 0
        local jw, jh = journal:GetDimensions()
        jw = tonumber(jw) or 0
        jh = tonumber(jh) or 0
        local gap = 26
        local rightX = jl + jw + gap
        local leftX = jl - width - gap
        local pad = 10
        if rightX + width <= guiW - pad then
            x = rightX
        elseif leftX >= pad then
            x = leftX
        else
            x = math.max(pad, math.min(guiW - width - pad, rightX))
        end
        y = math.max(pad, math.min(guiH - height - pad, jt))
    end

    x = math.max(10, math.min(guiW - width - 10, x))
    y = math.max(10, math.min(guiH - height - 10, y))
    return x, y
end

function L:RestoreWindowPlacement(forceReposition)
    if not self.window then return end
    local s = self:EnsureWindowSaved()
    local w = math.max(860, math.min(1120, tonumber(s.width) or 900))
    local h = math.max(560, math.min(760, tonumber(s.height) or 590))
    self.window:SetDimensions(w, h)
    self.window:ClearAnchors()
    if forceReposition == true or not tonumber(s.left) or not tonumber(s.top) then
        local x, y = self:GetDefaultWindowAnchor()
        self.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
        s.left, s.top = x, y
    else
        local guiW, guiH = GuiRoot:GetDimensions()
        guiW = tonumber(guiW) or 1920
        guiH = tonumber(guiH) or 1080
        local x = math.max(8, math.min(guiW - w - 8, tonumber(s.left) or 100))
        local y = math.max(8, math.min(guiH - h - 8, tonumber(s.top) or 100))
        self.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
        s.left, s.top = x, y
    end
end

function L:SetSlotBank(bank)
    bank = math.max(1, math.min(4, tonumber(bank) or 1))
    self.slotBank = bank
    self:RefreshUI()
end

local function setBorderColor(control, r, g, b, a)
    if control and control.easBorder and type(control.easBorder.SetEdgeColor) == "function" then
        control.easBorder:SetEdgeColor(r, g, b, a or 1)
    end
end

local function attachTooltip(control, text)
    if not control or not text then return end
    local oldTier, oldLayer, oldLevel
    control:SetHandler("OnMouseEnter", function(c)
        if type(InitializeTooltip) == "function" and InformationTooltip then
            if type(InformationTooltip.GetDrawTier) == "function" then oldTier=safe(InformationTooltip.GetDrawTier,nil,InformationTooltip) end
            if type(InformationTooltip.GetDrawLayer) == "function" then oldLayer=safe(InformationTooltip.GetDrawLayer,nil,InformationTooltip) end
            if type(InformationTooltip.GetDrawLevel) == "function" then oldLevel=safe(InformationTooltip.GetDrawLevel,nil,InformationTooltip) end
            if type(InformationTooltip.SetDrawTier) == "function" and DT_HIGH ~= nil then pcall(InformationTooltip.SetDrawTier, InformationTooltip, DT_HIGH) end
            if type(InformationTooltip.SetDrawLayer) == "function" and DL_OVERLAY ~= nil then pcall(InformationTooltip.SetDrawLayer, InformationTooltip, DL_OVERLAY) end
            if type(InformationTooltip.SetDrawLevel) == "function" then pcall(InformationTooltip.SetDrawLevel, InformationTooltip, 6800) end
            InitializeTooltip(InformationTooltip, c, TOPLEFT, 0, 0, TOPRIGHT)
            if type(SetTooltipText) == "function" then SetTooltipText(InformationTooltip, text) end
        end
    end)
    control:SetHandler("OnMouseExit", function()
        if type(ClearTooltip) == "function" and InformationTooltip then ClearTooltip(InformationTooltip) end
        if InformationTooltip then
            if oldTier ~= nil and type(InformationTooltip.SetDrawTier) == "function" then pcall(InformationTooltip.SetDrawTier,InformationTooltip,oldTier) end
            if oldLayer ~= nil and type(InformationTooltip.SetDrawLayer) == "function" then pcall(InformationTooltip.SetDrawLayer,InformationTooltip,oldLayer) end
            if oldLevel ~= nil and type(InformationTooltip.SetDrawLevel) == "function" then pcall(InformationTooltip.SetDrawLevel,InformationTooltip,oldLevel) end
        end
        oldTier,oldLayer,oldLevel=nil,nil,nil
    end)
end

local function makeBackdrop(name, parent)
    local c = wm:CreateControl(name, parent, CT_BACKDROP)
    c:SetEdgeTexture(nil, 1, 1, 1)
    return c
end

local function makeButton(name, parent, text, handler)
    local b = wm:CreateControl(name, parent, CT_BUTTON)
    b:SetFont("ZoFontGameBold")
    b:SetText(text)
    if b.SetHorizontalAlignment then b:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    if b.SetVerticalAlignment then b:SetVerticalAlignment(TEXT_ALIGN_CENTER) end
    local border = wm:CreateControl(name .. "Border", b, CT_BACKDROP)
    border:SetAnchor(TOPLEFT, b, TOPLEFT, 1, 1)
    border:SetAnchor(BOTTOMRIGHT, b, BOTTOMRIGHT, -1, -1)
    border:SetCenterColor(0.035,0.050,0.072,0.55)
    border:SetEdgeColor(0.24,0.36,0.54,0.92)
    border:SetEdgeTexture(nil,1,1,1)
    if border.SetDrawLevel then border:SetDrawLevel(0) end
    b.easBorder = border
    if handler then b:SetHandler("OnClicked", handler) end
    return b
end

local function makeEsoTab(name, parent, text, handler)
    local b = wm:CreateControl(name, parent, CT_BUTTON)
    b:SetFont("ZoFontGameBold")
    b:SetText(text)
    if b.SetHorizontalAlignment then b:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    if b.SetVerticalAlignment then b:SetVerticalAlignment(TEXT_ALIGN_CENTER) end
    local hitBG = wm:CreateControl(name .. "BG", b, CT_BACKDROP)
    hitBG:SetAnchorFill(b)
    hitBG:SetCenterColor(0.018,0.026,0.038,0.18)
    hitBG:SetEdgeColor(0,0,0,0)
    hitBG:SetEdgeTexture(nil,1,1,1)
    if hitBG.SetDrawLevel then hitBG:SetDrawLevel(0) end
    local line = wm:CreateControl(name .. "Selected", b, CT_BACKDROP)
    line:SetAnchor(BOTTOMLEFT,b,BOTTOMLEFT,6,0)
    line:SetAnchor(BOTTOMRIGHT,b,BOTTOMRIGHT,-6,0)
    line:SetHeight(2)
    line:SetCenterColor(0.86,0.68,0.30,0.98)
    line:SetEdgeColor(0,0,0,0)
    line:SetEdgeTexture(nil,1,1,1)
    line:SetHidden(true)
    b.easTabBG = hitBG
    b.easTabLine = line
    if handler then b:SetHandler("OnClicked", handler) end
    return b
end

local function setEsoTabSelected(tab, selected)
    if not tab then return end
    selected = selected == true
    if tab.easTabLine then tab.easTabLine:SetHidden(not selected) end
    if tab.easTabBG then
        tab.easTabBG:SetCenterColor(selected and 0.080 or 0.018, selected and 0.064 or 0.026, selected and 0.040 or 0.038, selected and 0.70 or 0.18)
    end
    if type(tab.SetNormalFontColor) == "function" then
        if selected then tab:SetNormalFontColor(0.96,0.80,0.46,1)
        else tab:SetNormalFontColor(0.66,0.72,0.80,1) end
    end
end

function L:LayoutUI()
    if not self.window or not self.cards then return end
    local w, h = self.window:GetDimensions()
    w = tonumber(w) or 900
    h = tonumber(h) or 590

    local side, gapX, gapY = 14, 10, 10
    local startY = 170
    local footerReserve = 30
    local cardW = math.floor((w - side * 2 - gapX) / 2)
    local cardH = math.floor((h - startY - footerReserve - gapY) / 2)
    cardH = math.max(168, math.min(188, cardH))

    -- Header controls resize with the window instead of relying on a 940px canvas.
    if self.loadoutSub then self.loadoutSub:SetDimensions(math.max(300,w-96),18) end

    -- One compact toolbar row. Widths are budgeted from the live window width so
    -- no action can escape the right edge at the minimum supported size.
    local toolbar = self.pageToolbar
    if toolbar then
        local gap = 4
        local x = 18
        local fixed = {
            {toolbar.prev,28},{toolbar.next,28},
        }
        for _,spec in ipairs(fixed) do
            local control,width = spec[1],spec[2]
            if control then
                control:ClearAnchors()
                control:SetAnchor(TOPLEFT,self.window,TOPLEFT,x,68)
                control:SetDimensions(width,26)
            end
            x = x + width + gap
        end

        local remainingFixed = 58+58+76+100+82+70+70 + gap*7
        local nameW = math.max(150, math.min(196, w - x - remainingFixed - 18))
        if self.pageNameBG then
            self.pageNameBG:ClearAnchors()
            self.pageNameBG:SetAnchor(TOPLEFT,self.window,TOPLEFT,x,68)
            self.pageNameBG:SetDimensions(nameW,26)
            if self.pageNameEdit then self.pageNameEdit:SetDimensions(nameW-14,18) end
        end
        x = x + nameW + gap

        local actions = {
            {toolbar.newPage,58},{toolbar.deletePage,58},{toolbar.bindZone,76},
            {toolbar.raidAuto,100},{toolbar.checkPage,82},{toolbar.withdraw,70},{toolbar.deposit,70},
        }
        for _,spec in ipairs(actions) do
            local control,width = spec[1],spec[2]
            if control then
                control:ClearAnchors()
                control:SetAnchor(TOPLEFT,self.window,TOPLEFT,x,68)
                control:SetDimensions(width,26)
            end
            x = x + width + gap
        end
    elseif self.pageNameBG then
        self.pageNameBG:SetDimensions(math.max(150,math.min(196,math.floor(w*0.22))),26)
        if self.pageNameEdit then self.pageNameEdit:SetDimensions(self.pageNameBG:GetWidth()-14,18) end
    end
    if self.pageStatus then
        self.pageStatus:SetDimensions(w - 28, 28)
        if type(self.pageStatus.SetMaxLineCount)=="function" then self.pageStatus:SetMaxLineCount(2) end
    end
    if self.headerDivider then
        self.headerDivider:ClearAnchors()
        self.headerDivider:SetAnchor(TOPLEFT,self.window,TOPLEFT,14,126)
        self.headerDivider:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,-14,126)
    end
    if self.tabStripBG then self.tabStripBG:SetDimensions(w-28,36) end
    if self.slotTabs then
        local usable = w - 36
        local tabW = math.floor(usable / 4)
        for n,tab in ipairs(self.slotTabs) do
            tab:ClearAnchors()
            tab:SetAnchor(TOPLEFT,self.window,TOPLEFT,18+(n-1)*tabW,132)
            tab:SetDimensions(tabW,32)
        end
    end

    for i=1,SLOT_COUNT do
        local card = self.cards[i]
        if card and card.card then
            local visual = (i - 1) % 4
            local row, col = math.floor(visual / 2), visual % 2
            card.card:ClearAnchors()
            card.card:SetAnchor(TOPLEFT,self.window,TOPLEFT,side + col*(cardW+gapX),startY + row*(cardH+gapY))
            card.card:SetDimensions(cardW,cardH)

            local tagW = math.max(108, math.min(150, math.floor(cardW*0.34)))
            local nameW = math.max(118, cardW - 44 - tagW - 22)
            if card.nameBG then
                card.nameBG:ClearAnchors()
                card.nameBG:SetAnchor(TOPLEFT,card.card,TOPLEFT,44,8)
                card.nameBG:SetDimensions(nameW,24)
            end
            if card.edit then card.edit:SetDimensions(math.max(90,nameW-12),18) end
            if card.tag then
                card.tag:ClearAnchors()
                card.tag:SetAnchor(TOPRIGHT,card.card,TOPRIGHT,-8,9)
                card.tag:SetDimensions(tagW,19)
            end
            if card.status then
                card.status:SetDimensions(cardW-16,30)
                if type(card.status.SetMaxLineCount)=="function" then card.status:SetMaxLineCount(2) end
            end

            local iconSize = cardW < 410 and 22 or 24
            local iconGap = 3
            local iconStartX = 42
            for _,rowData in ipairs({{card.frontLabel,card.frontIcons},{card.backLabel,card.backIcons}}) do
                local label, icons = rowData[1],rowData[2]
                if label then label:SetDimensions(28,18) end
                for n,holder in ipairs(icons or {}) do
                    holder.frame:ClearAnchors()
                    local y = icons == card.frontIcons and 66 or 95
                    holder.frame:SetAnchor(TOPLEFT,card.card,TOPLEFT,iconStartX+(n-1)*(iconSize+iconGap),y)
                    holder.frame:SetDimensions(iconSize,iconSize)
                end
            end

            local rightGap = 5
            local rightW = math.max(132,math.min(172,cardW - (iconStartX + 6*(iconSize+iconGap)) - 14))
            local half = math.floor((rightW-rightGap)/2)
            local rightX = cardW - rightW - 8
            local function placeRight(control, xOff, y, width)
                if not control then return end
                control:ClearAnchors()
                control:SetAnchor(TOPLEFT,card.card,TOPLEFT,rightX+xOff,y)
                control:SetDimensions(width,25)
            end
            placeRight(card.gearDrop,0,66,half)
            placeRight(card.foodDrop,half+rightGap,66,half)
            if card.cpBadge then
                card.cpBadge:ClearAnchors()
                card.cpBadge:SetAnchor(TOPLEFT,card.card,TOPLEFT,rightX,95)
                card.cpBadge:SetDimensions(half,25)
            end
            placeRight(card.readyButton,half+rightGap,95,half)

            local actionGap = 6
            local actionW = math.floor((cardW - 16 - actionGap*2)/3)
            for n,control in ipairs({card.loadButton,card.saveButton,card.moreButton}) do
                if control then
                    control:ClearAnchors()
                    control:SetAnchor(BOTTOMLEFT,card.card,BOTTOMLEFT,8+(n-1)*(actionW+actionGap),-8)
                    control:SetDimensions(actionW,27)
                end
            end
        end
    end
    if self.footer then self.footer:SetDimensions(w - 28, 18) end
end
-- v0.29.279: raw-key fallback for the Loadout Saver toggle. ESO can suppress
-- inherited custom action-layer bindings while a mouse-driven top-level window
-- owns UI mode. Compare the actual key-down against the user's saved binding so
-- the same assigned hotkey can always close the workspace, independent of
-- action-layer routing.
function L:RawKeyMatchesAction(actionName, key, ctrl, alt, shift, command)
    if type(GetNumActionLayers) ~= "function" or type(GetActionLayerInfo) ~= "function"
        or type(GetActionLayerCategoryInfo) ~= "function" or type(GetActionInfo) ~= "function"
        or type(GetActionBindingInfo) ~= "function" then
        return false
    end

    local function modifierPresent(modifierKey, m1, m2, m3, m4)
        if modifierKey == nil then return false end
        if type(ZO_Keybindings_DoesKeyMatchAnyModifiers) == "function" then
            return ZO_Keybindings_DoesKeyMatchAnyModifiers(modifierKey, m1, m2, m3, m4) == true
        end
        return m1 == modifierKey or m2 == modifierKey or m3 == modifierKey or m4 == modifierKey
    end

    local keyInvalid = rawget(_G, "KEY_INVALID")
    local keyCtrl = rawget(_G, "KEY_CTRL")
    local keyAlt = rawget(_G, "KEY_ALT")
    local keyShift = rawget(_G, "KEY_SHIFT")
    local keyCommand = rawget(_G, "KEY_COMMAND")

    local numLayers = num(safe(GetNumActionLayers, 0)) or 0
    for layerIndex = 1, numLayers do
        local _, numCategories = safe(GetActionLayerInfo, nil, layerIndex)
        numCategories = num(numCategories) or 0
        for categoryIndex = 1, numCategories do
            local _, numActions = safe(GetActionLayerCategoryInfo, nil, layerIndex, categoryIndex)
            numActions = num(numActions) or 0
            for actionIndex = 1, numActions do
                local name = safe(GetActionInfo, nil, layerIndex, categoryIndex, actionIndex)
                if name == actionName then
                    for bindingIndex = 1, 4 do
                        local boundKey, m1, m2, m3, m4 = safe(GetActionBindingInfo, nil, layerIndex, categoryIndex, actionIndex, bindingIndex)
                        if boundKey ~= nil and boundKey ~= keyInvalid and boundKey == key then
                            local wantCtrl = modifierPresent(keyCtrl, m1, m2, m3, m4)
                            local wantAlt = modifierPresent(keyAlt, m1, m2, m3, m4)
                            local wantShift = modifierPresent(keyShift, m1, m2, m3, m4)
                            local wantCommand = modifierPresent(keyCommand, m1, m2, m3, m4)
                            if (ctrl == true) == wantCtrl and (alt == true) == wantAlt
                                and (shift == true) == wantShift and (command == true) == wantCommand then
                                return true
                            end
                        end
                    end
                    return false
                end
            end
        end
    end
    return false
end

function L:AttachRawHotkeyCapture(control)
    if not control then return end
    if type(control.SetKeyboardEnabled) == "function" then control:SetKeyboardEnabled(true) end
    if type(control.SetHandler) ~= "function" then return end
    control:SetHandler("OnKeyDown", function(_, key, ctrl, alt, shift, command)
        if not self.window or self.window:IsHidden() then return end
        if self:RawKeyMatchesAction("ESO_ADVENTURER_SUITE_LOADOUT_SAVER", key, ctrl, alt, shift, command) then
            -- Native action dispatch may run immediately after OnKeyDown. Stamp
            -- this edge before hiding so any fall-through OPEN/TOGGLE action from
            -- the same physical press is debounced instead of reopening the UI.
            self.lastHotkeyToggleMs = nowMs()
            self:Hide()
            return true
        end
    end)
end

function L:CreateUI()
    if self.window then return end

    local win = wm:CreateTopLevelWindow("EAS_LoadoutManager")
    win:SetDimensions(900, 590)
    if win.SetDimensionConstraints then win:SetDimensionConstraints(860, 560, 1120, 760) end
    if win.SetResizeHandleSize then win:SetResizeHandleSize(24) end
    win:SetClampedToScreen(false)
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetHidden(true)
    setLoadoutWindowLayer(win)
    self.window = win
    self:AttachRawHotkeyCapture(win)
    self:RestoreWindowPlacement(false)

    local bg = makeBackdrop("EAS_LoadoutManagerBG", win)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0.010,0.016,0.026,0.985)
    bg:SetEdgeColor(0.27,0.48,0.70,0.95)
    self.bg = bg

    local title = wm:CreateControl("EAS_LoadoutManagerTitle", win, CT_LABEL)
    title:SetFont("ZoFontWinH2")
    title:SetText("LOADOUT SAVER")
    title:SetAnchor(TOPLEFT,win,TOPLEFT,20,13)
    title:SetDimensions(420,32)
    title:SetColor(0.96,0.98,1,1)

    local sub = wm:CreateControl("EAS_LoadoutManagerSub", win, CT_LABEL)
    sub:SetFont("ZoFontGameSmall")
    sub:SetText("Gear  •  Skills  •  Champion  •  Food  •  Raid presets")
    sub:SetAnchor(TOPLEFT,win,TOPLEFT,21,43)
    sub:SetDimensions(780,18)
    self.loadoutSub=sub
    sub:SetColor(0.57,0.69,0.82,1)

    local close = makeButton("EAS_LoadoutManagerClose",win,"X",function() self:Hide() end)
    close:SetAnchor(TOPRIGHT,win,TOPRIGHT,-16,13)
    close:SetDimensions(34,30)
    self.closeLoadoutsButton=close
    attachTooltip(close,"Close Loadout Saver")

    -- Page selector row.
    local prev = makeButton("EAS_LoadoutPagePrev",win,"<",function() self:CyclePage(-1) end)
    prev:SetAnchor(TOPLEFT,win,TOPLEFT,18,68); prev:SetDimensions(30,26)
    attachTooltip(prev,"Previous loadout page")
    local nextb = makeButton("EAS_LoadoutPageNext",win,">",function() self:CyclePage(1) end)
    nextb:SetAnchor(TOPLEFT,win,TOPLEFT,52,68); nextb:SetDimensions(30,26)
    attachTooltip(nextb,"Next loadout page")
    self.pageToolbar=self.pageToolbar or {}
    self.pageToolbar.prev=prev
    self.pageToolbar.next=nextb

    local pageNameBG=makeBackdrop("EAS_LoadoutPageNameBG",win)
    pageNameBG:SetAnchor(TOPLEFT,win,TOPLEFT,88,68)
    pageNameBG:SetDimensions(190,26)
    self.pageNameBG=pageNameBG
    pageNameBG:SetCenterColor(0.018,0.030,0.046,0.98)
    pageNameBG:SetEdgeColor(0.25,0.43,0.62,0.88)
    local pageEdit=wm:CreateControl("EAS_LoadoutPageName",pageNameBG,CT_EDITBOX)
    pageEdit:SetAnchor(TOPLEFT,pageNameBG,TOPLEFT,7,4)
    pageEdit:SetDimensions(176,18)
    pageEdit:SetFont("ZoFontGameBold")
    pageEdit:SetMaxInputChars(32)
    pageEdit:SetMouseEnabled(true)
    if pageEdit.SetKeyboardEnabled then pageEdit:SetKeyboardEnabled(true) end
    pageEdit:SetHandler("OnFocusLost",function(c) self:SetPageName(c:GetText()) end)
    pageEdit:SetHandler("OnEnter",function(c) self:SetPageName(c:GetText()); if c.LoseFocus then c:LoseFocus() end end)
    self.pageNameEdit=pageEdit

    local newPage=makeButton("EAS_LoadoutNewPage",win,"+ PAGE",function() self:AddPage() end)
    newPage:SetAnchor(TOPLEFT,win,TOPLEFT,286,68); newPage:SetDimensions(66,26)
    attachTooltip(newPage,"Create a new setup page")
    self.pageToolbar.newPage=newPage
    local delPage=makeButton("EAS_LoadoutDeletePage",win,"DELETE",function() self:DeleteCurrentPage() end)
    delPage:SetAnchor(TOPLEFT,win,TOPLEFT,356,68); delPage:SetDimensions(66,26)
    attachTooltip(delPage,"Delete the current page")
    self.pageToolbar.deletePage=delPage
    local bindZone=makeButton("EAS_LoadoutBindZone",win,"BIND ZONE",function()
        local p=self:GetCurrentPage()
        if tonumber(p.zoneId or 0)>0 then self:UnbindCurrentPageZone() else self:BindCurrentPageToZone() end
    end)
    bindZone:SetAnchor(TOPLEFT,win,TOPLEFT,426,68); bindZone:SetDimensions(86,26); self.bindZoneButton=bindZone
    attachTooltip(bindZone,"Bind this page to the current trial/zone")
    self.pageToolbar.bindZone=bindZone

    local raidAuto=makeButton("EAS_LoadoutRaidAuto",win,"RAID AUTO",function()
        EPC.saved.loadoutAutoEquipRaids029272 = EPC.saved.loadoutAutoEquipRaids029272 ~= true
        self:RefreshUI()
    end)
    raidAuto:SetAnchor(TOPLEFT,win,TOPLEFT,520,68); raidAuto:SetDimensions(112,26); self.raidAutoButton=raidAuto
    attachTooltip(raidAuto,"Automatically equip your bound setup when entering raids or boss encounters")
    self.pageToolbar.raidAuto=raidAuto

    local checkPage=makeButton("EAS_LoadoutCheckPage",win,"CHECK PAGE",function() self:CheckCurrentPageMissing() end)
    checkPage:SetAnchor(TOPLEFT,win,TOPLEFT,638,68); checkPage:SetDimensions(92,26)
    attachTooltip(checkPage,"Check every saved setup on this page for missing gear")
    self.pageToolbar.checkPage=checkPage

    local withdraw=makeButton("EAS_LoadoutWithdrawPage",win,"WITHDRAW",function() self:TransferCurrentPage("withdraw") end)
    withdraw:SetAnchor(TOPLEFT,win,TOPLEFT,736,68); withdraw:SetDimensions(72,26); self.withdrawPageButton=withdraw
    attachTooltip(withdraw,"With a bank open, withdraw gear used by this page")
    self.pageToolbar.withdraw=withdraw
    local deposit=makeButton("EAS_LoadoutDepositPage",win,"DEPOSIT",function() self:TransferCurrentPage("deposit") end)
    deposit:SetAnchor(TOPLEFT,win,TOPLEFT,812,68); deposit:SetDimensions(72,26); self.depositPageButton=deposit
    attachTooltip(deposit,"With a bank open, deposit gear used by this page")
    self.pageToolbar.deposit=deposit

    local pageStatus=wm:CreateControl("EAS_LoadoutPageStatus",win,CT_LABEL)
    pageStatus:SetFont("ZoFontGameSmall")
    pageStatus:SetAnchor(TOPLEFT,win,TOPLEFT,18,101)
    pageStatus:SetDimensions(864,28)
    pageStatus:SetColor(0.58,0.70,0.83,1)
    self.pageStatus=pageStatus

    local divider=makeBackdrop("EAS_LoadoutHeaderDivider",win)
    divider:SetAnchor(TOPLEFT,win,TOPLEFT,14,126)
    divider:SetAnchor(TOPRIGHT,win,TOPRIGHT,-14,126)
    self.headerDivider=divider
    divider:SetHeight(1)
    divider:SetCenterColor(0.16,0.28,0.42,0.88)
    divider:SetEdgeColor(0,0,0,0)

    local tabStripBG=makeBackdrop("EAS_LoadoutTabStripBG",win)
    tabStripBG:SetAnchor(TOPLEFT,win,TOPLEFT,14,130)
    tabStripBG:SetDimensions(872,36)
    tabStripBG:SetCenterColor(0.008,0.013,0.021,0.74)
    tabStripBG:SetEdgeColor(0.10,0.18,0.28,0.72)
    self.tabStripBG=tabStripBG

    self.slotTabs={}
    local tabDefs={{"BUILDS 1–4",1},{"BUILDS 5–8",2},{"BUILDS 9–12",3},{"BUILDS 13–16",4}}
    for n,def in ipairs(tabDefs) do
        local tab=makeEsoTab("EAS_LoadoutSlotBank"..n,win,def[1],function() self:SetSlotBank(def[2]) end)
        tab:SetAnchor(TOPLEFT,win,TOPLEFT,18+(n-1)*216,132)
        tab:SetDimensions(216,32)
        self["slotBank"..n.."Button"]=tab
        self.slotTabs[n]=tab
    end

    self.cards={}
    self.slotBank = self.slotBank or 1
    for i=1,SLOT_COUNT do
        local card=makeBackdrop("EAS_LoadoutCard"..i,win)
        card:SetDimensions(440,180)
        card:SetCenterColor(0.022,0.033,0.050,0.96)
        card:SetEdgeColor(0.18,0.30,0.44,0.84)
        card:SetMouseEnabled(true)
        card:SetHandler("OnMouseUp",function(control,button,upInside)
            if upInside~=false and button==MOUSE_BUTTON_INDEX_RIGHT then self:ShowSetupMenu(i,control) end
        end)

        local slotBadge=makeBackdrop("EAS_LoadoutSlotBadge"..i,card)
        slotBadge:SetAnchor(TOPLEFT,card,TOPLEFT,8,8)
        slotBadge:SetDimensions(30,24)
        slotBadge:SetCenterColor(0.035,0.075,0.115,0.98)
        slotBadge:SetEdgeColor(0.25,0.50,0.72,0.92)
        local slot=wm:CreateControl("EAS_LoadoutSlot"..i,slotBadge,CT_LABEL)
        slot:SetFont("ZoFontGameBold")
        slot:SetText(string.format("%02d",i))
        slot:SetAnchorFill(slotBadge)
        slot:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        slot:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        slot:SetColor(0.58,0.84,1,1)

        local nameBG=makeBackdrop("EAS_LoadoutNameBG"..i,card)
        nameBG:SetAnchor(TOPLEFT,card,TOPLEFT,44,8)
        nameBG:SetDimensions(176,24)
        nameBG:SetCenterColor(0.014,0.024,0.038,0.96)
        nameBG:SetEdgeColor(0.22,0.38,0.56,0.78)
        local edit=wm:CreateControl("EAS_LoadoutName"..i,nameBG,CT_EDITBOX)
        edit:SetAnchor(TOPLEFT,nameBG,TOPLEFT,6,3)
        edit:SetDimensions(162,18)
        edit:SetFont("ZoFontGameBold")
        edit:SetMaxInputChars(28)
        edit:SetColor(0.95,0.98,1,1)
        edit:SetMouseEnabled(true)
        if edit.SetKeyboardEnabled then edit:SetKeyboardEnabled(true) end
        if edit.SetEditEnabled then edit:SetEditEnabled(false) end
        edit:SetHandler("OnMouseUp",function(control,button,upInside)
            if upInside==false then return end
            if button==MOUSE_BUTTON_INDEX_RIGHT then self:ShowSetupMenu(i,control); return end
            if button~=MOUSE_BUTTON_INDEX_LEFT then return end
            local c=self.cards and self.cards[i]
            if c and c.renaming then if control.TakeFocus then control:TakeFocus() end else self:Equip(i) end
        end)
        edit:SetHandler("OnFocusLost",function(control)
            local c=self.cards and self.cards[i]
            if c and c.renaming then self:SetName(i,control:GetText(),true); c.renaming=false; if control.SetEditEnabled then control:SetEditEnabled(false) end end
        end)
        edit:SetHandler("OnEnter",function(control)
            local c=self.cards and self.cards[i]
            if c and c.renaming then self:SetName(i,control:GetText(),false); c.renaming=false end
            if control.SetEditEnabled then control:SetEditEnabled(false) end
            if control.LoseFocus then control:LoseFocus() end
        end)

        local tag=wm:CreateControl("EAS_LoadoutTag"..i,card,CT_LABEL)
        tag:SetFont("ZoFontGameBold")
        tag:SetAnchor(TOPRIGHT,card,TOPRIGHT,-8,9)
        tag:SetDimensions(176,20)
        tag:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        tag:SetColor(0.58,0.70,0.84,1)

        local status=wm:CreateControl("EAS_LoadoutStatus"..i,card,CT_LABEL)
        status:SetFont("ZoFontGameSmall")
        status:SetAnchor(TOPLEFT,card,TOPLEFT,8,36)
        status:SetDimensions(424,30)
        status:SetColor(0.57,0.68,0.80,1)

        local function createIconRow(prefix,y,barKey,labelText)
            local icons={}
            local lbl=wm:CreateControl(prefix.."Label",card,CT_LABEL)
            lbl:SetFont("ZoFontGameSmall")
            lbl:SetText(labelText)
            lbl:SetAnchor(TOPLEFT,card,TOPLEFT,8,y+5)
            lbl:SetDimensions(34,18)
            lbl:SetColor(0.62,0.74,0.88,1)
            for n=1,6 do
                local holder=makeBackdrop(prefix.."Frame"..n,card)
                holder:SetAnchor(TOPLEFT,card,TOPLEFT,43+(n-1)*29,y)
                holder:SetDimensions(26,26)
                holder:SetCenterColor(0.010,0.017,0.027,0.94)
                holder:SetEdgeColor(0.17,0.26,0.36,0.78)
                holder:SetMouseEnabled(true)
                local tex=wm:CreateControl(prefix.."Icon"..n,holder,CT_TEXTURE)
                tex:SetAnchorFill(holder)
                tex:SetHidden(true)
                holder:SetHandler("OnReceiveDrag",function() self:DropSkillOnSetup(i,barKey,n) end)
                holder:SetHandler("OnDragStart",function() self:DragSavedSkillFromSetup(i,barKey,n) end)
                holder:SetHandler("OnMouseUp",function(_,button,upInside)
                    if upInside~=false and button==MOUSE_BUTTON_INDEX_RIGHT then
                        local setup=self:EnsureSaved()[i]
                        if setup and setup.bars and setup.bars[barKey] then setup.bars[barKey][n]=0; self:RefreshUI() end
                    end
                end)
                icons[n]={frame=holder,icon=tex}
            end
            return icons
        end
        local frontIcons=createIconRow("EAS_Loadout"..i.."Front",66,"primary","F")
        local backIcons=createIconRow("EAS_Loadout"..i.."Back",95,"backup","B")
        local frontLabel=_G["EAS_Loadout"..i.."FrontLabel"]
        local backLabel=_G["EAS_Loadout"..i.."BackLabel"]

        -- Large, explicit drop/status targets replace the old GEA/FOO abbreviations.
        local gearDrop=makeButton("EAS_LoadoutGearDrop"..i,card,"GEAR",function()
            if num(safe(GetCursorContentType,0))~=(rawget(_G,"MOUSE_CONTENT_EMPTY") or 0) then self:DropGearOnSetup(i) else self:CheckMissing(i) end
        end)
        gearDrop:SetAnchor(TOPRIGHT,card,TOPRIGHT,-96,66)
        gearDrop:SetDimensions(88,26)
        gearDrop:SetMouseEnabled(true)
        gearDrop:SetHandler("OnReceiveDrag",function() self:DropGearOnSetup(i) end)
        attachTooltip(gearDrop,"Drop gear here to assign it, or click to check this setup for missing items")

        local foodDrop
        foodDrop=makeButton("EAS_LoadoutFoodDrop"..i,card,"FOOD",function()
            if num(safe(GetCursorContentType,0))~=(rawget(_G,"MOUSE_CONTENT_EMPTY") or 0) then
                self:DropFoodOnSetup(i)
            else
                self:ShowFoodPicker(i,foodDrop)
            end
        end)
        foodDrop:SetAnchor(TOPRIGHT,card,TOPRIGHT,-6,66)
        foodDrop:SetDimensions(84,26)
        foodDrop:SetMouseEnabled(true)
        foodDrop:SetHandler("OnReceiveDrag",function() self:DropFoodOnSetup(i) end)
        attachTooltip(foodDrop,"Click to choose food/drink from your backpack, or drag food here. Loading the setup uses the saved food when Loadout Food is enabled.")

        local cpBadge=makeBackdrop("EAS_LoadoutCPBadge"..i,card)
        cpBadge:SetAnchor(TOPRIGHT,card,TOPRIGHT,-96,95)
        cpBadge:SetDimensions(88,26)
        cpBadge:SetCenterColor(0.018,0.028,0.042,0.95)
        cpBadge:SetEdgeColor(0.17,0.28,0.42,0.78)
        local cpLabel=wm:CreateControl("EAS_LoadoutCPLabel"..i,cpBadge,CT_LABEL)
        cpLabel:SetAnchorFill(cpBadge)
        cpLabel:SetFont("ZoFontGameSmall")
        cpLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        cpLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        cpLabel:SetColor(0.66,0.77,0.90,1)

        local ready=makeButton("EAS_LoadoutReady"..i,card,"EMPTY",function() self:CheckMissing(i) end)
        ready:SetAnchor(TOPRIGHT,card,TOPRIGHT,-6,95)
        ready:SetDimensions(84,26)
        attachTooltip(ready,"Check whether all saved gear is available in your inventory or open bank")

        local equip=makeButton("EAS_LoadoutEquip"..i,card,"EQUIP",function() self:Equip(i) end)
        equip:SetAnchor(BOTTOMLEFT,card,BOTTOMLEFT,8,-8); equip:SetDimensions(82,27)
        local save=makeButton("EAS_LoadoutSave"..i,card,"SAVE",function() self:RequestSave(i) end)
        save:SetAnchor(BOTTOMLEFT,card,BOTTOMLEFT,96,-8); save:SetDimensions(112,27)
        local more=makeButton("EAS_LoadoutMore"..i,card,"MANAGE",function(control) self:ShowSetupMenu(i,control) end)
        more:SetAnchor(BOTTOMRIGHT,card,BOTTOMRIGHT,-8,-8); more:SetDimensions(88,27)
        attachTooltip(more,"Boss rules, bank actions, import/export, rename, and clear")

        self.cards[i]={
            card=card,slotBadge=slotBadge,nameBG=nameBG,edit=edit,status=status,tag=tag,
            frontLabel=frontLabel,backLabel=backLabel,frontIcons=frontIcons,backIcons=backIcons,
            loadButton=equip,saveButton=save,moreButton=more,
            gearDrop=gearDrop,foodDrop=foodDrop,cpBadge=cpBadge,cpLabel=cpLabel,readyButton=ready,renaming=false
        }
    end

    local footer=wm:CreateControl("EAS_LoadoutFooter",win,CT_LABEL)
    footer:SetFont("ZoFontGameSmall")
    footer:SetText("Left-click name: equip  •  Right-click card: manage  •  Drag gear/food/skills to edit  •  Hotkey closes")
    footer:SetAnchor(BOTTOMLEFT,win,BOTTOMLEFT,18,-9)
    footer:SetDimensions(908,18)
    footer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    footer:SetColor(0.45,0.57,0.71,1)
    self.footer=footer

    win:SetHandler("OnMoveStop",function(control)
        local s=self:EnsureWindowSaved(); s.left,s.top=control:GetLeft(),control:GetTop(); s.userMoved=true
    end)
    win:SetHandler("OnResizeStop",function(control)
        local s=self:EnsureWindowSaved(); local w,h=control:GetDimensions(); s.width,s.height=math.floor(w+0.5),math.floor(h+0.5); self:LayoutUI()
    end)
    self:LayoutUI()
end

function L:RefreshUI()
    if not self.cards then return end
    self:HideSetupPopup()
    local all=self:EnsureSaved()
    local page=self:GetCurrentPage()
    local pageId=self:GetCurrentPageId()
    local ids=self:GetPageIds()
    local pagePos=1
    for pos,id in ipairs(ids) do if id==pageId then pagePos=pos break end end

    if self.pageNameEdit and not self.pageNameEdit:HasFocus() then self.pageNameEdit:SetText(page.name or ("Page "..pageId)) end
    local zoneName=tostring(page.zoneName or "")
    local bossCount=0
    for _ in pairs(page.bossRules or {}) do bossCount=bossCount+1 end
    local bankOpen=safe(IsBankOpen,false)==true
    if self.pageStatus then
        local bound = zoneName~="" and ("Bound to "..zoneName) or "Not zone-bound"
        local entry = tonumber(page.zoneAutoSlot or 0)>0 and ("Raid entry Setup "..tostring(page.zoneAutoSlot)) or "No raid-entry setup"
        self.pageStatus:SetText(string.format("Page %d of %d  •  %s  •  %s\n%d boss rule%s  •  %s",pagePos,#ids,bound,entry,bossCount,bossCount==1 and "" or "s",bankOpen and "BANK OPEN" or "BANK CLOSED"))
    end
    if self.bindZoneButton then self.bindZoneButton:SetText(tonumber(page.zoneId or 0)>0 and "UNBIND" or "BIND ZONE") end
    if self.raidAutoButton then
        local on=EPC.saved.loadoutAutoEquipRaids029272==true
        self.raidAutoButton:SetText(on and "RAID AUTO: ON" or "RAID AUTO: OFF")
        setBorderColor(self.raidAutoButton,on and 0.72 or 0.24,on and 0.56 or 0.36,on and 0.20 or 0.54,0.96)
    end
    if self.withdrawPageButton then self.withdrawPageButton:SetEnabled(self.bankTransferBusy ~= true) end
    if self.depositPageButton then self.depositPageButton:SetEnabled(self.bankTransferBusy ~= true) end

    self.slotBank = math.max(1,math.min(4,tonumber(self.slotBank) or 1))
    local bankStart=(self.slotBank-1)*4+1
    local bankEnd=bankStart+3
    local filled={0,0,0,0}
    for i=1,SLOT_COUNT do
        local d=all[i]
        if d and (d.gear~=nil or d.bars~=nil or d.build~=nil or d.food~=nil) then
            local group=math.floor((i-1)/4)+1
            filled[group]=(filled[group] or 0)+1
        end
    end
    local labels={"BUILDS 1–4","BUILDS 5–8","BUILDS 9–12","BUILDS 13–16"}
    for group=1,4 do
        local button=self["slotBank"..group.."Button"]
        if button then
            button:SetText(string.format("%s   %d/4",labels[group],filled[group] or 0))
            setEsoTabSelected(button,self.slotBank==group)
        end
    end

    for i=1,SLOT_COUNT do
        local c=self.cards[i]
        local d=all[i]
        if c and d then
            c.card:SetHidden(i<bankStart or i>bankEnd)
            if i>=bankStart and i<=bankEnd then
                if not c.edit:HasFocus() then c.edit:SetText(d.name or ("Build "..i)) end
                local filled=d.gear~=nil or d.bars~=nil or d.build~=nil or d.food~=nil
                local gearCount=0
                for _ in pairs(d.gear or {}) do gearCount=gearCount+1 end
                local barCount=0
                for _,key in ipairs({"primary","backup"}) do
                    for _,id in ipairs((d.bars and d.bars[key]) or {}) do if (tonumber(id) or 0)>0 then barCount=barCount+1 end end
                end
                local cpSlots=d.build and d.build.champion and tonumber(d.build.champion.slottedCount) or 0
                local missing=filled and #self:GetMissingItems(i,true) or 0
                local active=self:GetActiveIndex()==i
                local tags={}
                if active then tags[#tags+1]="ACTIVE" end
                if tonumber(page.zoneAutoSlot or 0)==i then tags[#tags+1]="RAID ENTRY" end
                for _,idx in pairs(page.bossRules or {}) do if tonumber(idx)==i then tags[#tags+1]="BOSS"; break end end
                c.tag:SetText(table.concat(tags,"  •  "))
                if active then c.tag:SetColor(0.96,0.76,0.32,1) elseif #tags>0 then c.tag:SetColor(0.55,0.79,1,1) else c.tag:SetColor(0.48,0.60,0.74,1) end

                if filled then
                    local state = missing>0 and ("Missing "..missing.." item"..(missing==1 and "" or "s")) or "All saved gear available"
                    c.status:SetText(string.format("Gear %d  •  Skills %d/12  •  CP %d\n%s",gearCount,barCount,cpSlots,state))
                else
                    c.status:SetText("Empty setup\nSAVE current build or drag gear / food / skills")
                end

                self:UpdateSkillIcons(c.frontIcons,d.bars and d.bars.primary)
                self:UpdateSkillIcons(c.backIcons,d.bars and d.bars.backup)

                c.loadButton:SetText(active and "ACTIVE" or "EQUIP")
                if not (self.pendingOverwrite and self.pendingOverwrite[i]) then c.saveButton:SetText("SAVE") end
                c.gearDrop:SetText(gearCount>0 and ("GEAR "..gearCount) or "GEAR")
                c.foodDrop:SetText(d.food and "FOOD ✓" or "FOOD")
                c.cpLabel:SetText(cpSlots>0 and ("CP "..cpSlots) or "CP —")
                c.readyButton:SetText(not filled and "EMPTY" or (missing>0 and ("MISS "..missing) or "READY"))

                if active then
                    c.card:SetEdgeColor(0.88,0.68,0.24,0.99)
                    setBorderColor(c.loadButton,0.88,0.68,0.24,0.98)
                elseif missing>0 then
                    c.card:SetEdgeColor(0.72,0.30,0.25,0.96)
                    setBorderColor(c.loadButton,0.24,0.36,0.54,0.92)
                elseif filled then
                    c.card:SetEdgeColor(0.24,0.45,0.66,0.92)
                    setBorderColor(c.loadButton,0.24,0.42,0.60,0.92)
                else
                    c.card:SetEdgeColor(0.16,0.26,0.38,0.76)
                    setBorderColor(c.loadButton,0.20,0.30,0.43,0.82)
                end
                setBorderColor(c.readyButton, missing>0 and 0.72 or (filled and 0.24 or 0.18), missing>0 and 0.30 or (filled and 0.52 or 0.28), missing>0 and 0.25 or (filled and 0.38 or 0.42), 0.94)
                setBorderColor(c.foodDrop,d.food and 0.35 or 0.24,d.food and 0.55 or 0.36,d.food and 0.30 or 0.54,0.92)
            end
        end
    end
    self:LayoutUI()
end

function L:SetUIMode(active)
    active = active == true
    local changed = false
    if type(SetGameCameraUIMode) == "function" then
        local ok = pcall(SetGameCameraUIMode, active)
        changed = ok == true or changed
    end
    -- Keep the scene manager in agreement with camera UI mode. Some ESO
    -- scenes restore character control after a custom top-level window opens.
    if SCENE_MANAGER and type(SCENE_MANAGER.SetInUIMode) == "function" then
        local ok = pcall(SCENE_MANAGER.SetInUIMode, SCENE_MANAGER, active)
        changed = ok == true or changed
    end
    return changed
end

function L:AcquireUIMode(forceOwnership)
    local active = safe(IsGameCameraUIModeActive, false) == true
    if not active then
        if self:SetUIMode(true) then self.ownsUIMode = true end
    elseif forceOwnership == true then
        -- Used when the Codex hands its UI mode directly to this workspace.
        self.ownsUIMode = true
    end
end

function L:ReleaseUIMode()
    if self.ownsUIMode then self:SetUIMode(false) end
    self.ownsUIMode = false
end

function L:TransferUIModeToCodex()
    local owns = self.ownsUIMode == true
    self.ownsUIMode = false
    return owns
end


function L:UpdateToggleLabels(isOpen)
    isOpen = isOpen == true
    -- OPEN belongs on the launcher controls. CLOSE belongs on the Saved
    -- Loadouts overlay itself, so users never have to hunt another panel to
    -- dismiss the loadout workspace.
    if EPC.Journal and EPC.Journal.suiteSpreads and EPC.Journal.suiteSpreads.GEAR then
        local b = EPC.Journal.suiteSpreads.GEAR.savedLoadoutsButton
        if b and type(b.SetText) == "function" then b:SetText("OPEN BUILDS") end
    end
    if EPC.GearLoadoutOverlay and EPC.GearLoadoutOverlay.playerButton and type(EPC.GearLoadoutOverlay.playerButton.SetText) == "function" then
        EPC.GearLoadoutOverlay.playerButton:SetText(isOpen and "BUILDS OPEN" or "OPEN BUILDS")
    end
    if self.closeLoadoutsButton and type(self.closeLoadoutsButton.SetText) == "function" then
        self.closeLoadoutsButton:SetText("X")
    end
end
function L:Show()
    self:CreateUI()

    -- Direct hotkeys for Suite tools should switch cleanly instead of stacking
    -- independent UI-mode windows on top of one another.
    local potion = EPC and EPC.AlchemyPotionMaker
    if potion and potion.window and not potion.window:IsHidden() then
        if type(potion.CloseFromHotkey) == "function" then pcall(potion.CloseFromHotkey, potion)
        elseif type(potion.HideWindow) == "function" then pcall(potion.HideWindow, potion) end
    end
    local learner = EPC and EPC.RecipeStyleLearner
    if learner and learner.window and not learner.window:IsHidden() then
        if type(learner.CloseFromHotkey) == "function" then pcall(learner.CloseFromHotkey, learner)
        elseif type(learner.HideWindow) == "function" then pcall(learner.HideWindow, learner) end
    end

    -- Keep Live Equipment on screen while Saved Builds is open.
    if EPC.GearLoadoutOverlay and type(EPC.GearLoadoutOverlay.SetLoadoutMode) == "function" then
        EPC.GearLoadoutOverlay:SetLoadoutMode(true)
    end

    -- IMPORTANT: when the Codex was opened from normal gameplay it owns the
    -- UI/cursor mode. Transfer that ownership before hiding the Codex so its
    -- Hide() path does not return control to the character.
    local transferredFromCodex = false
    if EPC.Journal and EPC.Journal.window and not EPC.Journal.window:IsHidden() and type(EPC.Journal.Hide) == "function" then
        transferredFromCodex = EPC.Journal.ownsUIMode == true
        if transferredFromCodex then EPC.Journal.ownsUIMode = false end
        EPC.Journal:Hide()
    end

    self:AcquireUIMode(transferredFromCodex)

    -- A scene change can settle one frame after the Codex hides. Reinforce UI
    -- mode on the next tick without taking ownership when ESO itself already
    -- owned it (inventory, pause menu, etc.).
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if self.window and not self.window:IsHidden() then
                local active = safe(IsGameCameraUIModeActive, false) == true
                if not active then self:SetUIMode(true) end
            end
        end, 50)
    end

    local s = self:EnsureWindowSaved()
    self:RestoreWindowPlacement(not s.userMoved)
    local activeIndex = self:GetActiveIndex()
    if activeIndex > 0 then self.slotBank = math.floor((activeIndex - 1) / 4) + 1 end
    self:RefreshUI()
    setLoadoutWindowLayer(self.window)
    self.window:SetHidden(false)
    self:UpdateToggleLabels(true)

    -- Arm the Loadout Saver UI action layer after the opening key-down has
    -- finished. Pushing it in the same frame can make ESO deliver that opening
    -- press to the inherited CLOSE action as well, which looks like a
    -- two-press/no-open bug.
    local function armLoadoutLayer()
        if not self.window or self.window:IsHidden() then return end
        if not self.loadoutActionLayerPushed and type(PushActionLayerByName) == "function" then
            local ok = pcall(PushActionLayerByName, "ESOAdventurerSuiteLoadoutLayer")
            if ok then self.loadoutActionLayerPushed = true end
        end
    end
    if type(zo_callLater) == "function" then zo_callLater(armLoadoutLayer, 120) else armLoadoutLayer() end
end

function L:Hide(keepUIMode)
    self:HideSetupPopup()
    if self.transferWindow then self.transferWindow:SetHidden(true) end
    if self.window then self.window:SetHidden(true) end
    self:UpdateToggleLabels(false)
    if self.loadoutActionLayerPushed and type(RemoveActionLayerByName) == "function" then
        pcall(RemoveActionLayerByName, "ESOAdventurerSuiteLoadoutLayer")
        self.loadoutActionLayerPushed = false
    end
    if EPC.GearLoadoutOverlay and type(EPC.GearLoadoutOverlay.SetLoadoutMode) == "function" then
        EPC.GearLoadoutOverlay:SetLoadoutMode(false)
    end
    if keepUIMode ~= true then self:ReleaseUIMode() end
end

function L:Toggle()
    if not self.window or self.window:IsHidden() then self:Show() else self:Hide() end
end

-- v0.29.279: keep OPEN/CLOSE compatibility handlers, but the primary binding now
-- calls the true toggle and the visible top-level windows also capture the raw
-- assigned key. This makes closing independent of ESO action-layer routing.
-- ESO disables/replaces parts of the normal GENERAL binding layer while a
-- custom UI owns cursor mode, so using one Toggle action in both layers can
-- leave the opening binding available but make the closing press disappear.
-- This mirrors the working Potion Maker / Turbo Learner hotkey pattern.
function L:AcceptHotkeyEdge()
    local stamp = nowMs()
    if self.lastHotkeyToggleMs and stamp > 0 and (stamp - self.lastHotkeyToggleMs) < 220 then
        return false
    end
    self.lastHotkeyToggleMs = stamp
    return true
end

function L:OpenFromHotkey()
    if not self:AcceptHotkeyEdge() then return true end
    if self.window and not self.window:IsHidden() then return true end
    self:Show()
    return true
end

function L:CloseFromHotkey()
    if not self:AcceptHotkeyEdge() then return true end
    if self.window and not self.window:IsHidden() then
        self:Hide()
    end
    return true
end

-- Backward-compatible toggle entry point for any older Suite code or user
-- binding cache that still references the v0.29.272-v0.29.277 function.
function L:ToggleFromHotkey()
    if not self:AcceptHotkeyEdge() then return true end
    self:Toggle()
    return true
end

function ESOAdventurerSuite_OpenLoadoutSaverHotkey()
    if EPC and EPC.LoadoutManager and type(EPC.LoadoutManager.OpenFromHotkey) == "function" then
        return EPC.LoadoutManager:OpenFromHotkey()
    end
    return true
end

function ESOAdventurerSuite_CloseLoadoutSaverHotkey()
    if EPC and EPC.LoadoutManager and type(EPC.LoadoutManager.CloseFromHotkey) == "function" then
        return EPC.LoadoutManager:CloseFromHotkey()
    end
    return true
end

function ESOAdventurerSuite_ToggleLoadoutSaverHotkey()
    if EPC and EPC.LoadoutManager and type(EPC.LoadoutManager.ToggleFromHotkey) == "function" then
        return EPC.LoadoutManager:ToggleFromHotkey()
    end
    return true
end

function ESOAdventurerSuite_LoadoutPrebuffAcceleration() if EPC and EPC.LoadoutManager then return EPC.LoadoutManager:PreparePrebuff("ACCELERATION") end return false end
function ESOAdventurerSuite_LoadoutPrebuffDestroUlt() if EPC and EPC.LoadoutManager then return EPC.LoadoutManager:PreparePrebuff("DESTRO_ULT") end return false end
function ESOAdventurerSuite_LoadoutPrebuffManeuver() if EPC and EPC.LoadoutManager then return EPC.LoadoutManager:PreparePrebuff("MANEUVER") end return false end
function ESOAdventurerSuite_LoadoutPrebuffSiegeShield() if EPC and EPC.LoadoutManager then return EPC.LoadoutManager:PreparePrebuff("SIEGE_SHIELD") end return false end

function L:Initialize()
    self:EnsurePages()
    self:EnsureSaved()
    self:EnsureWindowSaved()
    self.activeIndex = self:GetActiveIndex()
    self:RebuildGearIndex()
    self:CreateUI()
    local eventName = "EAS_LoadoutManager029272"
    if EVENT_PLAYER_ACTIVATED then EPC.Runtime:RegisterEvent("LoadoutManager", "Activated", EVENT_PLAYER_ACTIVATED, function() self:OnPlayerActivated() end) end
    if EVENT_BOSSES_CHANGED then EPC.Runtime:RegisterEvent("LoadoutManager", "Boss", EVENT_BOSSES_CHANGED, function() self:OnBossesChanged() end) end
    if EVENT_PLAYER_COMBAT_STATE then EPC.Runtime:RegisterEvent("LoadoutManager", "Combat", EVENT_PLAYER_COMBAT_STATE, function(...) self:OnCombatState(...) end) end
    if EVENT_ACTION_SLOT_ABILITY_USED then EPC.Runtime:RegisterEvent("LoadoutManager", "Prebuff", EVENT_ACTION_SLOT_ABILITY_USED, function(...) self:OnPrebuffAbilityUsed(...) end) end
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then EPC.Runtime:RegisterEvent("LoadoutManager", "Worn", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(...) self:OnWornInventoryUpdate(...) end) end
    if EVENT_OPEN_BANK then EPC.Runtime:RegisterEvent("LoadoutManager", "BankOpen", EVENT_OPEN_BANK, function() if self.window and self.window:IsHidden() == false then self:RefreshUI() end end) end
    if EVENT_CLOSE_BANK then EPC.Runtime:RegisterEvent("LoadoutManager", "BankClose", EVENT_CLOSE_BANK, function() if self.window and self.window:IsHidden() == false then self:RefreshUI() end end) end
    SLASH_COMMANDS["/easloadouts"] = function() self:Toggle() end
    SLASH_COMMANDS["/easbuilds"] = function() self:Toggle() end
end
