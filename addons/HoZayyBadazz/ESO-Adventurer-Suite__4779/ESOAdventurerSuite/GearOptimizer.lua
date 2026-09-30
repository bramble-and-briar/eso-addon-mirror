-- ESO Adventurer Suite
-- Endgame gear optimizer
local EPC = ESOProgressionCoach
EPC.GearOptimizer = EPC.GearOptimizer or {}
local G = EPC.GearOptimizer

G.PRESETS = {
    SINGLE_TARGET = { label = "SINGLE TARGET", frontTrait = "PRECISE", backTrait = "INFUSED", armorBias = "BALANCED" },
    AOE_TRASH = { label = "AOE / TRASH", frontTrait = "CHARGED", backTrait = "INFUSED", armorBias = "MEDIUM" },
    SOLO = { label = "SOLO", frontTrait = "PRECISE", backTrait = "INFUSED", armorBias = "SURVIVAL" },
    TRIAL = { label = "TRIAL", frontTrait = "PRECISE", backTrait = "INFUSED", armorBias = "BALANCED" },
}
G.PRESET_ORDER = { "SINGLE_TARGET", "AOE_TRASH", "SOLO", "TRIAL" }

function G:GetPreset()
    local key = tostring(EPC.saved and EPC.saved.gearOptimizerPreset or "TRIAL")
    if not self.PRESETS[key] then key = "TRIAL" end
    return key, self.PRESETS[key]
end

function G:SetPreset(key)
    key = tostring(key or "")
    if not self.PRESETS[key] or not EPC.saved then return false end
    EPC.saved.gearOptimizerPreset = key
    if EPC.Print then EPC:Print("Endgame Gear preset: " .. self.PRESETS[key].label) end
    return true
end

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok,a,b,c,d,e,f,g,h = pcall(fn, ...)
    if not ok then return fallback end
    return a,b,c,d,e,f,g,h
end
local function safeNumber(fn, fallback, ...)
    local value = safe(fn, fallback, ...)
    local number = tonumber(value)
    if number ~= nil then return number end
    return tonumber(fallback) or 0
end
local function lower(s) return string.lower(tostring(s or "")) end
local function same(a,b) return lower(a) == lower(b) and lower(a) ~= "" end

local BODY_SLOTS = {
    EQUIP_SLOT_HEAD, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_HAND,
    EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET,
}
local EQUIP_TYPE_TO_SLOT = {
    [EQUIP_TYPE_HEAD]=EQUIP_SLOT_HEAD,[EQUIP_TYPE_CHEST]=EQUIP_SLOT_CHEST,
    [EQUIP_TYPE_SHOULDERS]=EQUIP_SLOT_SHOULDERS,[EQUIP_TYPE_HAND]=EQUIP_SLOT_HAND,
    [EQUIP_TYPE_WAIST]=EQUIP_SLOT_WAIST,[EQUIP_TYPE_LEGS]=EQUIP_SLOT_LEGS,
    [EQUIP_TYPE_FEET]=EQUIP_SLOT_FEET,[EQUIP_TYPE_NECK]=EQUIP_SLOT_NECK,
}

local SLOT_LABELS = {
    [EQUIP_SLOT_HEAD] = "Head",
    [EQUIP_SLOT_CHEST] = "Chest",
    [EQUIP_SLOT_SHOULDERS] = "Shoulders",
    [EQUIP_SLOT_HAND] = "Hands",
    [EQUIP_SLOT_WAIST] = "Waist",
    [EQUIP_SLOT_LEGS] = "Legs",
    [EQUIP_SLOT_FEET] = "Feet",
    [EQUIP_SLOT_NECK] = "Neck",
    [EQUIP_SLOT_RING1] = "Ring 1",
    [EQUIP_SLOT_RING2] = "Ring 2",
    [EQUIP_SLOT_MAIN_HAND] = "Front Main Hand",
    [EQUIP_SLOT_OFF_HAND] = "Front Off Hand",
    [EQUIP_SLOT_BACKUP_MAIN] = "Back Main Hand",
    [EQUIP_SLOT_BACKUP_OFF] = "Back Off Hand",
}

local function itemName(link)
    if not link or link == "" then return "Empty" end
    if type(GetItemLinkName) == "function" then
        local name = safe(GetItemLinkName, "", link)
        if name and name ~= "" then return tostring(name) end
    end
    return tostring(link)
end

function G:NotifyResult(message, isSuccess)
    message = tostring(message or "")
    if message == "" then return end
    if EPC and EPC.Print then EPC:Print(message) end
    if type(ZO_Alert) == "function" then
        local category = UI_ALERT_CATEGORY_ALERT or 1
        pcall(ZO_Alert, category, nil, message)
    end
end

function G:ScoreCurrentLoadout(profile, presetKey)
    profile = profile or self:GetProfile()
    presetKey = presetKey or select(1, self:GetPreset())
    local targetCounts = self:CollectWornSetCounts()
    local currentFrontType = type(GetItemWeaponType)=="function" and safe(GetItemWeaponType,WEAPONTYPE_NONE or 0,BAG_WORN,EQUIP_SLOT_MAIN_HAND) or nil
    local currentBackType = type(GetItemWeaponType)=="function" and safe(GetItemWeaponType,WEAPONTYPE_NONE or 0,BAG_WORN,EQUIP_SLOT_BACKUP_MAIN) or nil
    local slots = {
        EQUIP_SLOT_HEAD, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_HAND,
        EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_NECK,
        EQUIP_SLOT_RING1, EQUIP_SLOT_RING2, EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_BACKUP_MAIN,
    }
    local total = 0
    for _,dest in ipairs(slots) do
        local bar = dest == EQUIP_SLOT_BACKUP_MAIN and "BACK" or "FRONT"
        local weaponType = dest == EQUIP_SLOT_BACKUP_MAIN and currentBackType or currentFrontType
        local score = self:ScoreItem(BAG_WORN,dest,dest,profile,targetCounts,weaponType,presetKey,bar)
        total = total + (tonumber(score) or 0)
    end
    return math.floor(total + 0.5)
end

function G:ReportVerifiedChanges(beforeLinks, beforeScore, requested, profile, presetKey, presetLabel)
    local confirmed = 0
    local details = {}
    for _,item in ipairs(requested or {}) do
        local dest = item.dest
        local before = beforeLinks[dest] or ""
        local after = safe(GetItemLink,"",BAG_WORN,dest,LINK_STYLE_DEFAULT or 0)
        if after ~= before and after ~= "" then
            confirmed = confirmed + 1
            details[#details+1] = string.format("%s: %s -> %s", SLOT_LABELS[dest] or ("Slot "..tostring(dest)), itemName(before), itemName(after))
        end
    end
    local afterScore = self:ScoreCurrentLoadout(profile,presetKey)
    local delta = afterScore - (tonumber(beforeScore) or 0)
    if confirmed > 0 then
        self:NotifyResult(string.format("GEAR UPDATED: %d change%s confirmed | Score %d -> %d (%+d)", confirmed, confirmed == 1 and "" or "s", tonumber(beforeScore) or 0, afterScore, delta), true)
        for _,line in ipairs(details) do if EPC and EPC.Print then EPC:Print("  " .. line) end end
    else
        self:NotifyResult(string.format("NO GEAR CHANGES CONFIRMED | Score %d -> %d", tonumber(beforeScore) or 0, afterScore), false)
        if EPC and EPC.Print then EPC:Print("Endgame Gear: ESO did not confirm any requested swaps. Check inventory space, locked items, and equipment restrictions.") end
    end
    if EPC and EPC.RequestRefresh then EPC:RequestRefresh("endgame-gear-verified") end
end

function G:GetProfile()
    local classId = safeNumber(GetUnitClassId, 0, "player")
    local magCurrent, magMax = safe(GetUnitPower, 0, "player", POWERTYPE_MAGICKA)
    local stamCurrent, stamMax = safe(GetUnitPower, 0, "player", POWERTYPE_STAMINA)
    local mag = tonumber(magMax) or tonumber(magCurrent) or 0
    local stam = tonumber(stamMax) or tonumber(stamCurrent) or 0
    local magicka = mag >= stam
    local role = EPC.Role and type(EPC.Role.GetRole) == "function" and EPC.Role:GetRole() or "DAMAGE"
    local metaKey = EPC.EndgameMeta and type(EPC.EndgameMeta.GetProfileKey) == "function" and EPC.EndgameMeta:GetProfileKey(classId, magicka, role) or nil
    local metaLabel = EPC.EndgameMeta and type(EPC.EndgameMeta.GetProfileLabel) == "function" and EPC.EndgameMeta:GetProfileLabel(classId, magicka, role) or nil
    return {
        id = metaKey or (magicka and "MAGICKA_PVE" or "STAMINA_PVE"),
        metaKey = metaKey,
        classId = classId,
        magicka = magicka,
        role = role,
        label = metaLabel or (role == "TANK" and "PvE Tank" or role == "HEALER" and "PvE Healer" or (magicka and "Magicka PvE DPS" or "Stamina PvE DPS")),
    }
end

function G:GetMetaTemplate(profile, presetKey)
    if not EPC.EndgameMeta or type(EPC.EndgameMeta.GetTemplate) ~= "function" then return nil end
    return EPC.EndgameMeta:GetTemplate(profile or self:GetProfile(), presetKey or select(1, self:GetPreset()))
end

function G:GetMetaSummaryLines()
    local profile = self:GetProfile()
    local presetKey = select(1, self:GetPreset())
    if EPC.EndgameMeta and type(EPC.EndgameMeta.GetSummaryLines) == "function" then
        return EPC.EndgameMeta:GetSummaryLines(profile, presetKey)
    end
    return {"Live endgame meta snapshot unavailable."}
end

function G:GetTargetSets()
    local result = {}
    if EPC.TargetBuild and type(EPC.TargetBuild.GetTargetSets) == "function" then
        for _,name in ipairs(EPC.TargetBuild:GetTargetSets() or {}) do
            if tostring(name or "") ~= "" then result[#result+1] = tostring(name) end
        end
    end
    return result
end

local function setNameFor(link)
    if type(GetItemLinkSetInfo) ~= "function" then return "" end
    local hasSet,name = safe(GetItemLinkSetInfo, false, link, true)
    return hasSet == true and tostring(name or "") or ""
end

local function effectiveItemLevel(bag, slot)
    local cp = safeNumber(GetItemRequiredChampionPoints, 0, bag, slot)
    local level = safeNumber(GetItemRequiredLevel, 0, bag, slot)
    if cp > 0 then return 50 + math.min(160,cp)/10 end
    return math.min(50,level)
end

local function traitScore(link, equipType, profile, presetKey, weaponBar)
    if type(GetItemLinkTraitInfo) ~= "function" then return 0 end
    local trait = safeNumber(GetItemLinkTraitInfo, ITEM_TRAIT_TYPE_NONE or 0, link)
    if equipType == EQUIP_TYPE_RING or equipType == EQUIP_TYPE_NECK then
        if trait == (ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY or -1) then return presetKey == "SOLO" and 125 or 165 end
        if trait == (ITEM_TRAIT_TYPE_JEWELRY_INFUSED or -2) then return presetKey == "SOLO" and 145 or 125 end
        if trait == (ITEM_TRAIT_TYPE_JEWELRY_ARCANE or -3) and profile.magicka then return 70 end
        if trait == (ITEM_TRAIT_TYPE_JEWELRY_ROBUST or -4) and not profile.magicka then return 70 end
        return 10
    end
    local armorType = safeNumber(GetItemLinkArmorType, ARMORTYPE_NONE or 0, link)
    if armorType ~= (ARMORTYPE_NONE or 0) then
        if trait == (ITEM_TRAIT_TYPE_ARMOR_DIVINES or -10) then return presetKey == "SOLO" and 125 or 165 end
        if trait == (ITEM_TRAIT_TYPE_ARMOR_INFUSED or -11) then return presetKey == "SOLO" and 115 or 75 end
        if trait == (ITEM_TRAIT_TYPE_ARMOR_REINFORCED or -12) then return presetKey == "SOLO" and 80 or 10 end
        return 5
    end
    local wt = safeNumber(GetItemLinkWeaponType, WEAPONTYPE_NONE or 0, link)
    if wt ~= (WEAPONTYPE_NONE or 0) then
        local front = weaponBar ~= "BACK"
        if trait == (ITEM_TRAIT_TYPE_WEAPON_PRECISE or -20) then
            if presetKey == "AOE_TRASH" then return front and 115 or 70 end
            return front and 165 or 80
        end
        if trait == (ITEM_TRAIT_TYPE_WEAPON_INFUSED or -21) then return front and 105 or 175 end
        if trait == (ITEM_TRAIT_TYPE_WEAPON_CHARGED or -22) then return (presetKey == "AOE_TRASH" and front) and 170 or 105 end
        if trait == (ITEM_TRAIT_TYPE_WEAPON_NIRNHONED or -23) then return (presetKey == "AOE_TRASH" and front) and 135 or 95 end
        return 10
    end
    return 0
end

local function armorScore(link, profile, presetKey)
    local armorType = safeNumber(GetItemLinkArmorType, ARMORTYPE_NONE or 0, link)
    if armorType == (ARMORTYPE_NONE or 0) then return 0 end
    if profile.magicka then
        if presetKey == "AOE_TRASH" then
            if armorType == (ARMORTYPE_MEDIUM or -2) then return 80 end
            if armorType == (ARMORTYPE_LIGHT or -1) then return 65 end
        elseif presetKey == "SOLO" then
            if armorType == (ARMORTYPE_LIGHT or -1) then return 75 end
            if armorType == (ARMORTYPE_MEDIUM or -2) then return 60 end
            if armorType == (ARMORTYPE_HEAVY or -3) then return 35 end
        else
            if armorType == (ARMORTYPE_LIGHT or -1) then return 78 end
            if armorType == (ARMORTYPE_MEDIUM or -2) then return 72 end
        end
    else
        if armorType == (ARMORTYPE_MEDIUM or -2) then return 75 end
        if armorType == (ARMORTYPE_LIGHT or -1) then return 35 end
    end
    return 5
end

local function weaponScore(link, profile, currentWeaponType, presetKey, weaponBar)
    local wt = safeNumber(GetItemLinkWeaponType, WEAPONTYPE_NONE or 0, link)
    if wt == (WEAPONTYPE_NONE or 0) then return 0 end
    if currentWeaponType and currentWeaponType ~= (WEAPONTYPE_NONE or 0) and wt == currentWeaponType then return 165 end
    if profile.magicka then
        if presetKey == "AOE_TRASH" then
            if wt == (WEAPONTYPE_LIGHTNING_STAFF or -2) then return 145 end
            if wt == (WEAPONTYPE_FIRE_STAFF or -1) then return 125 end
        elseif presetKey == "SOLO" then
            if wt == (WEAPONTYPE_LIGHTNING_STAFF or -2) then return 138 end
            if wt == (WEAPONTYPE_FIRE_STAFF or -1) then return 128 end
        else
            if wt == (WEAPONTYPE_FIRE_STAFF or -1) then return 142 end
            if wt == (WEAPONTYPE_LIGHTNING_STAFF or -2) then return 130 end
        end
    end
    return 0
end

function G:ScoreItem(bag,slot,dest,profile,targetCounts,currentWeaponType,presetKey,weaponBar)
    local _,_,_,meets,locked,equipType,_,fq,dq = safe(GetItemInfo,nil,bag,slot)
    if not equipType or equipType == EQUIP_TYPE_INVALID or meets == false or locked == true then return nil end
    if type(IsItemPlayerLocked)=="function" and safe(IsItemPlayerLocked,false,bag,slot)==true then return nil end
    local link = safe(GetItemLink,"",bag,slot,LINK_STYLE_DEFAULT or 0)
    if link == "" then return nil end
    local quality = tonumber(fq) or tonumber(dq) or 0
    local score = effectiveItemLevel(bag,slot)*22 + quality*38
    score = score + traitScore(link,equipType,profile,presetKey,weaponBar) + armorScore(link,profile,presetKey) + weaponScore(link,profile,currentWeaponType,presetKey,weaponBar)
    local setName = setNameFor(link)
    for _,wanted in ipairs(self:GetTargetSets()) do
        if same(setName,wanted) then
            local current = targetCounts[lower(wanted)] or 0
            local setBase = (presetKey == "SOLO") and 820 or 1050
            score = score + setBase
            if current < 5 then score = score + ((presetKey == "SOLO") and 580 or 760) end
            if current == 4 then score = score + ((presetKey == "SOLO") and 760 or 1150) end
        end
    end
    return score,equipType,link,setName
end

function G:CollectWornSetCounts()
    local counts = {}
    local slots = {unpack(BODY_SLOTS)}
    slots[#slots+1]=EQUIP_SLOT_NECK; slots[#slots+1]=EQUIP_SLOT_RING1; slots[#slots+1]=EQUIP_SLOT_RING2
    slots[#slots+1]=EQUIP_SLOT_MAIN_HAND; slots[#slots+1]=EQUIP_SLOT_OFF_HAND
    slots[#slots+1]=EQUIP_SLOT_BACKUP_MAIN; slots[#slots+1]=EQUIP_SLOT_BACKUP_OFF
    for _,slot in ipairs(slots) do
        local link = safe(GetItemLink,"",BAG_WORN,slot,LINK_STYLE_DEFAULT or 0)
        if link ~= "" then
            local n = setNameFor(link)
            if n ~= "" then counts[lower(n)] = (counts[lower(n)] or 0) + 1 end
        end
    end
    return counts
end

function G:GetWornScore(slot,profile,targetCounts,currentWeaponType,presetKey,weaponBar)
    local score = self:ScoreItem(BAG_WORN,slot,slot,profile,targetCounts,currentWeaponType,presetKey,weaponBar)
    return tonumber(score) or -1
end

function G:BuildPlan()
    local plan,best,rings,frontWeapons,backWeapons = {},{}, {}, {}, {}
    if not BAG_BACKPACK or type(GetBagSize)~="function" then return plan end
    local profile = self:GetProfile()
    local presetKey = select(1, self:GetPreset())
    local targetCounts = self:CollectWornSetCounts()
    local currentFrontType = type(GetItemWeaponType)=="function" and safe(GetItemWeaponType,WEAPONTYPE_NONE or 0,BAG_WORN,EQUIP_SLOT_MAIN_HAND) or nil
    local currentBackType = type(GetItemWeaponType)=="function" and safe(GetItemWeaponType,WEAPONTYPE_NONE or 0,BAG_WORN,EQUIP_SLOT_BACKUP_MAIN) or nil

    -- The currently equipped loadout is the optimizer baseline. A worn piece is
    -- never replaced just because something exists in the backpack; a backpack
    -- candidate has to beat the equipped piece for the selected endgame preset.
    local fixedSlots = {
        EQUIP_SLOT_HEAD, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_HAND,
        EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_NECK,
    }
    for _,dest in ipairs(fixedSlots) do
        local score,equipType,link,setName = self:ScoreItem(BAG_WORN,dest,dest,profile,targetCounts,currentFrontType,presetKey,"FRONT")
        if score then
            best[dest] = {bag=BAG_WORN,slot=dest,dest=dest,score=score,equipType=equipType,link=link,setName=setName,worn=true}
        end
    end

    -- Rings are evaluated as a two-slot pool so a strong ring you already wear
    -- remains eligible alongside every ring in the backpack.
    for _,dest in ipairs({EQUIP_SLOT_RING1,EQUIP_SLOT_RING2}) do
        local score,equipType,link,setName = self:ScoreItem(BAG_WORN,dest,dest,profile,targetCounts,currentFrontType,presetKey,"FRONT")
        if score then rings[#rings+1] = {bag=BAG_WORN,slot=dest,dest=dest,score=score,equipType=equipType,link=link,setName=setName,worn=true} end
    end

    -- Front/back weapons each start with what is actually equipped on that bar.
    local frontScore,frontEquip,frontLink,frontSet = self:ScoreItem(BAG_WORN,EQUIP_SLOT_MAIN_HAND,EQUIP_SLOT_MAIN_HAND,profile,targetCounts,currentFrontType,presetKey,"FRONT")
    if frontScore then frontWeapons[#frontWeapons+1] = {bag=BAG_WORN,slot=EQUIP_SLOT_MAIN_HAND,dest=EQUIP_SLOT_MAIN_HAND,score=frontScore,equipType=frontEquip,link=frontLink,setName=frontSet,worn=true} end
    local backScore,backEquip,backLink,backSet = self:ScoreItem(BAG_WORN,EQUIP_SLOT_BACKUP_MAIN,EQUIP_SLOT_BACKUP_MAIN,profile,targetCounts,currentBackType,presetKey,"BACK")
    if backScore then backWeapons[#backWeapons+1] = {bag=BAG_WORN,slot=EQUIP_SLOT_BACKUP_MAIN,dest=EQUIP_SLOT_BACKUP_MAIN,score=backScore,equipType=backEquip,link=backLink,setName=backSet,worn=true} end

    local count = safeNumber(GetBagSize, 0, BAG_BACKPACK)
    local evaluated = 0
    for slot=0,count-1 do
        local score,equipType,link,setName = self:ScoreItem(BAG_BACKPACK,slot,nil,profile,targetCounts,currentFrontType,presetKey,"FRONT")
        if score then
            evaluated = evaluated + 1
            local c={bag=BAG_BACKPACK,slot=slot,score=score,equipType=equipType,link=link,setName=setName,worn=false}
            if equipType==EQUIP_TYPE_RING then
                rings[#rings+1]=c
            elseif equipType==EQUIP_TYPE_MAIN_HAND or equipType==EQUIP_TYPE_ONE_HAND or equipType==EQUIP_TYPE_TWO_HAND or equipType==EQUIP_TYPE_OFF_HAND then
                local fs = select(1,self:ScoreItem(BAG_BACKPACK,slot,nil,profile,targetCounts,currentFrontType,presetKey,"FRONT")) or -1
                local bs = select(1,self:ScoreItem(BAG_BACKPACK,slot,nil,profile,targetCounts,currentBackType,presetKey,"BACK")) or -1
                frontWeapons[#frontWeapons+1]={bag=BAG_BACKPACK,slot=slot,score=fs,equipType=equipType,link=link,setName=setName,worn=false}
                backWeapons[#backWeapons+1]={bag=BAG_BACKPACK,slot=slot,score=bs,equipType=equipType,link=link,setName=setName,worn=false}
            else
                local dest=EQUIP_TYPE_TO_SLOT[equipType]
                local current=dest and best[dest] or nil
                if dest and (not current or score > current.score + 30) then best[dest]=c end
            end
        end
    end

    for dest,c in pairs(best) do
        if c.bag ~= BAG_WORN then c.dest=dest; plan[#plan+1]=c end
    end

    table.sort(rings,function(a,b) return a.score>b.score end)
    local chosen={}
    for _,c in ipairs(rings) do
        if #chosen>=2 then break end
        local duplicate=false
        for _,picked in ipairs(chosen) do
            if picked.bag==c.bag and picked.slot==c.slot then duplicate=true break end
        end
        if not duplicate then chosen[#chosen+1]=c end
    end
    local occupied={}
    for _,c in ipairs(chosen) do if c.worn and c.dest then occupied[c.dest]=true end end
    local openSlots={}
    for _,dest in ipairs({EQUIP_SLOT_RING1,EQUIP_SLOT_RING2}) do if not occupied[dest] then openSlots[#openSlots+1]=dest end end
    table.sort(openSlots,function(a,b)
        return self:GetWornScore(a,profile,targetCounts,currentFrontType,presetKey,"FRONT") < self:GetWornScore(b,profile,targetCounts,currentFrontType,presetKey,"FRONT")
    end)
    local openIndex=1
    for _,c in ipairs(chosen) do
        if not c.worn and openSlots[openIndex] then c.dest=openSlots[openIndex]; plan[#plan+1]=c; openIndex=openIndex+1 end
    end

    table.sort(frontWeapons,function(a,b) return a.score>b.score end)
    table.sort(backWeapons,function(a,b) return a.score>b.score end)
    local bestFront=frontWeapons[1]
    local usedBackpackSlot=nil
    if bestFront and not bestFront.worn then
        bestFront.dest=EQUIP_SLOT_MAIN_HAND; plan[#plan+1]=bestFront; usedBackpackSlot=bestFront.slot
    end
    local bestBack=nil
    for _,c in ipairs(backWeapons) do
        if c.worn or c.slot~=usedBackpackSlot then bestBack=c break end
    end
    if bestBack and not bestBack.worn then bestBack.dest=EQUIP_SLOT_BACKUP_MAIN; plan[#plan+1]=bestBack end

    table.sort(plan,function(a,b) return a.score>b.score end)
    self.lastProfile=profile
    self.lastPreset=presetKey
    self.lastBackpackCandidates=evaluated
    return plan
end

function G:EquipBestArmorWeight(weightKey)
    if safe(IsUnitInCombat,false,"player") == true then
        self:NotifyResult("Best Armor: leave combat before changing equipment.", false)
        return false
    end
    if type(RequestEquipItem) ~= "function" or not BAG_BACKPACK then
        self:NotifyResult("Best Armor: ESO's equipment API is unavailable.", false)
        return false
    end
    local wanted = {
        LIGHT = ARMORTYPE_LIGHT,
        MEDIUM = ARMORTYPE_MEDIUM,
        HEAVY = ARMORTYPE_HEAVY,
    }
    local armorType = wanted[string.upper(tostring(weightKey or ""))]
    if armorType == nil then return false end

    local profile = self:GetProfile()
    local presetKey = select(1, self:GetPreset())
    local targetCounts = self:CollectWornSetCounts()
    local best = {}
    local beforeLinks = {}
    for _, dest in ipairs(BODY_SLOTS) do
        beforeLinks[dest] = safe(GetItemLink,"",BAG_WORN,dest,LINK_STYLE_DEFAULT or 0)
        local currentLink = beforeLinks[dest]
        if currentLink ~= "" and safeNumber(GetItemLinkArmorType, ARMORTYPE_NONE or 0, currentLink) == armorType then
            local score,equipType,link,setName = self:ScoreItem(BAG_WORN,dest,dest,profile,targetCounts,nil,presetKey,"FRONT")
            if score then best[dest] = {bag=BAG_WORN,slot=dest,dest=dest,score=score,link=link,worn=true} end
        end
    end

    local count = safeNumber(GetBagSize, 0, BAG_BACKPACK)
    for slot=0,count-1 do
        local link = safe(GetItemLink,"",BAG_BACKPACK,slot,LINK_STYLE_DEFAULT or 0)
        if link ~= "" and safeNumber(GetItemLinkArmorType, ARMORTYPE_NONE or 0, link) == armorType then
            local score,equipType = self:ScoreItem(BAG_BACKPACK,slot,nil,profile,targetCounts,nil,presetKey,"FRONT")
            local dest = equipType and EQUIP_TYPE_TO_SLOT[equipType] or nil
            if score and dest and (not best[dest] or score > best[dest].score) then
                best[dest] = {bag=BAG_BACKPACK,slot=slot,dest=dest,score=score,link=link,worn=false}
            end
        end
    end

    local requested = {}
    for _,dest in ipairs(BODY_SLOTS) do
        local item = best[dest]
        if item and not item.worn then
            if pcall(RequestEquipItem,item.bag,item.slot,BAG_WORN,dest) then
                requested[#requested+1] = {dest=dest, expected=item.link}
            end
        end
    end
    if #requested == 0 then
        self:NotifyResult("BEST " .. string.upper(tostring(weightKey)) .. ": no armor upgrades found in backpack.", false)
        return false
    end
    self:NotifyResult(string.format("BEST %s: requested %d armor change%s.", string.upper(tostring(weightKey)), #requested, #requested == 1 and "" or "s"), true)
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            local confirmed = 0
            for _,item in ipairs(requested) do
                local after = safe(GetItemLink,"",BAG_WORN,item.dest,LINK_STYLE_DEFAULT or 0)
                if after ~= "" and after ~= beforeLinks[item.dest] then confirmed = confirmed + 1 end
            end
            self:NotifyResult(string.format("BEST %s: %d/%d change%s confirmed.", string.upper(tostring(weightKey)), confirmed, #requested, #requested == 1 and "" or "s"), confirmed > 0)
            if EPC and EPC.RequestRefresh then EPC:RequestRefresh("best-armor-weight") end
        end, 900)
    end
    return true
end


local function metaSetMatches(actual, wanted)
    if EPC.EndgameMeta and type(EPC.EndgameMeta.SameSet) == "function" then
        return EPC.EndgameMeta:SameSet(actual, wanted)
    end
    return same(actual, wanted)
end

local function metaArmorTypeMatches(link, wanted)
    wanted = string.upper(tostring(wanted or ""))
    if wanted == "" then return true end
    local armorType = safeNumber(GetItemLinkArmorType, ARMORTYPE_NONE or 0, link)
    if wanted == "LIGHT" then return armorType == (ARMORTYPE_LIGHT or -1) end
    if wanted == "MEDIUM" then return armorType == (ARMORTYPE_MEDIUM or -2) end
    if wanted == "HEAVY" then return armorType == (ARMORTYPE_HEAVY or -3) end
    return true
end

local function metaWeaponTypeMatches(link, wanted)
    wanted = string.upper(tostring(wanted or ""))
    if wanted == "" then return true end
    local wt = safeNumber(GetItemLinkWeaponType, WEAPONTYPE_NONE or 0, link)
    local equipType = safeNumber(GetItemLinkEquipType, EQUIP_TYPE_INVALID or 0, link)
    if wanted == "LIGHTNING STAFF" then return wt == (WEAPONTYPE_LIGHTNING_STAFF or -1) end
    if wanted == "INFERNO STAFF" or wanted == "FIRE STAFF" then return wt == (WEAPONTYPE_FIRE_STAFF or -2) end
    if wanted == "FROST STAFF" or wanted == "ICE STAFF" then return wt == (WEAPONTYPE_FROST_STAFF or -3) end
    if wanted == "RESTORATION STAFF" or wanted == "HEALING STAFF" then return wt == (WEAPONTYPE_HEALING_STAFF or -4) end
    if wanted == "GREATSWORD" then return wt == (WEAPONTYPE_TWO_HANDED_SWORD or -5) end
    if wanted == "BATTLE AXE" then return wt == (WEAPONTYPE_TWO_HANDED_AXE or -6) end
    if wanted == "MAUL" then return wt == (WEAPONTYPE_TWO_HANDED_HAMMER or -7) end
    if wanted == "DAGGER" then return wt == (WEAPONTYPE_DAGGER or -8) end
    if wanted == "SWORD" then return wt == (WEAPONTYPE_SWORD or WEAPONTYPE_ONE_HANDED_SWORD or -9) end
    if wanted == "AXE" then return wt == (WEAPONTYPE_AXE or WEAPONTYPE_ONE_HANDED_AXE or -10) end
    if wanted == "MACE" or wanted == "HAMMER" then return wt == (WEAPONTYPE_HAMMER or WEAPONTYPE_ONE_HANDED_HAMMER or -11) end
    if wanted == "BOW" then return wt == (WEAPONTYPE_BOW or -12) end
    if wanted == "SHIELD" then
        return wt == (WEAPONTYPE_SHIELD or -13) or equipType == (EQUIP_TYPE_OFF_HAND or -14)
    end
    return true
end

local function metaTraitMatches(link, wanted)
    wanted = string.upper(tostring(wanted or ""))
    if wanted == "" or type(GetItemLinkTraitInfo) ~= "function" then return true end
    local trait = safeNumber(GetItemLinkTraitInfo, ITEM_TRAIT_TYPE_NONE or 0, link)
    local armorType = safeNumber(GetItemLinkArmorType, ARMORTYPE_NONE or 0, link)
    local wt = safeNumber(GetItemLinkWeaponType, WEAPONTYPE_NONE or 0, link)
    local expected = nil
    if wanted == "INFUSED" then
        if wt ~= (WEAPONTYPE_NONE or 0) then expected = ITEM_TRAIT_TYPE_WEAPON_INFUSED
        elseif armorType ~= (ARMORTYPE_NONE or 0) then expected = ITEM_TRAIT_TYPE_ARMOR_INFUSED
        else expected = ITEM_TRAIT_TYPE_JEWELRY_INFUSED end
    elseif wanted == "DIVINES" then expected = ITEM_TRAIT_TYPE_ARMOR_DIVINES
    elseif wanted == "STURDY" then expected = ITEM_TRAIT_TYPE_ARMOR_STURDY
    elseif wanted == "REINFORCED" then expected = ITEM_TRAIT_TYPE_ARMOR_REINFORCED
    elseif wanted == "BLOODTHIRSTY" then expected = ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY
    elseif wanted == "ARCANE" then expected = ITEM_TRAIT_TYPE_JEWELRY_ARCANE
    elseif wanted == "HEALTHY" then expected = ITEM_TRAIT_TYPE_JEWELRY_HEALTHY
    elseif wanted == "TRIUNE" then expected = ITEM_TRAIT_TYPE_JEWELRY_TRIUNE
    elseif wanted == "PRECISE" then expected = ITEM_TRAIT_TYPE_WEAPON_PRECISE
    elseif wanted == "CHARGED" then expected = ITEM_TRAIT_TYPE_WEAPON_CHARGED
    elseif wanted == "NIRNHONED" then expected = ITEM_TRAIT_TYPE_WEAPON_NIRNHONED
    elseif wanted == "POWERED" then expected = ITEM_TRAIT_TYPE_WEAPON_POWERED
    elseif wanted == "DECISIVE" then expected = ITEM_TRAIT_TYPE_WEAPON_DECISIVE
    elseif wanted == "DEFENDING" then expected = ITEM_TRAIT_TYPE_WEAPON_DEFENDING
    end
    return expected == nil or trait == expected
end

local function metaDestinationForLink(link)
    if not link or link == "" then return nil end
    local equipType = safeNumber(GetItemLinkEquipType, EQUIP_TYPE_INVALID or 0, link)
    return EQUIP_TYPE_TO_SLOT[equipType]
end

function G:ScoreMetaCandidate(bag, slot, requirement, wornDest)
    if type(requirement) ~= "table" then return nil end
    local _,_,_,meets,locked,equipType,_,fq,dq = safe(GetItemInfo,nil,bag,slot)
    if not equipType or equipType == EQUIP_TYPE_INVALID or meets == false then return nil end
    if bag ~= BAG_WORN and locked == true then return nil end
    if bag ~= BAG_WORN and type(IsItemPlayerLocked) == "function" and safe(IsItemPlayerLocked,false,bag,slot)==true then return nil end
    local link = safe(GetItemLink,"",bag,slot,LINK_STYLE_DEFAULT or 0)
    if link == "" then return nil end
    local setName = setNameFor(link)
    if not metaSetMatches(setName, requirement.set) then return nil end

    local score = effectiveItemLevel(bag,slot) * 25 + (tonumber(fq) or tonumber(dq) or 0) * 45 + 1800
    if requirement.perfectedPreferred and string.find(lower(itemName(link)), "perfected", 1, true) then score = score + 350 end
    if requirement.armor then score = score + (metaArmorTypeMatches(link, requirement.armor) and 260 or -90) end
    if requirement.weapon then score = score + (metaWeaponTypeMatches(link, requirement.weapon) and 620 or -500) end
    if requirement.trait then score = score + (metaTraitMatches(link, requirement.trait) and 320 or 0) end
    if bag == BAG_WORN then score = score + 12 end

    local dest = wornDest or metaDestinationForLink(link)
    return {
        bag = bag,
        slot = slot,
        dest = dest,
        worn = bag == BAG_WORN,
        link = link,
        setName = setName,
        score = score,
        requirement = requirement,
        key = tostring(bag) .. ":" .. tostring(slot),
    }
end

function G:CollectMetaCandidates(requirement, kind)
    local out = {}
    local function add(bag, slot, dest)
        local c = self:ScoreMetaCandidate(bag, slot, requirement, dest)
        if not c then return end
        if kind == "BODY" then
            local valid = false
            for _,bodyDest in ipairs(BODY_SLOTS) do if c.dest == bodyDest then valid = true break end end
            if not valid then return end
        elseif kind == "NECK" then
            if safeNumber(GetItemLinkEquipType, EQUIP_TYPE_INVALID or 0, c.link) ~= (EQUIP_TYPE_NECK or -1) then return end
            c.dest = EQUIP_SLOT_NECK
        elseif kind == "RING" then
            if safeNumber(GetItemLinkEquipType, EQUIP_TYPE_INVALID or 0, c.link) ~= (EQUIP_TYPE_RING or -1) then return end
        elseif kind == "FRONT" then
            if not metaWeaponTypeMatches(c.link, requirement.weapon) then return end
            c.dest = EQUIP_SLOT_MAIN_HAND
        elseif kind == "FRONT_OFF" then
            if not metaWeaponTypeMatches(c.link, requirement.weapon) then return end
            c.dest = EQUIP_SLOT_OFF_HAND
        elseif kind == "BACK" then
            if not metaWeaponTypeMatches(c.link, requirement.weapon) then return end
            c.dest = EQUIP_SLOT_BACKUP_MAIN
        elseif kind == "BACK_OFF" then
            if not metaWeaponTypeMatches(c.link, requirement.weapon) then return end
            c.dest = EQUIP_SLOT_BACKUP_OFF
        end
        out[#out+1] = c
    end

    if kind == "BODY" then
        for _,dest in ipairs(BODY_SLOTS) do add(BAG_WORN,dest,dest) end
    elseif kind == "NECK" then
        add(BAG_WORN,EQUIP_SLOT_NECK,EQUIP_SLOT_NECK)
    elseif kind == "RING" then
        add(BAG_WORN,EQUIP_SLOT_RING1,EQUIP_SLOT_RING1)
        add(BAG_WORN,EQUIP_SLOT_RING2,EQUIP_SLOT_RING2)
    elseif kind == "FRONT" then
        add(BAG_WORN,EQUIP_SLOT_MAIN_HAND,EQUIP_SLOT_MAIN_HAND)
    elseif kind == "FRONT_OFF" then
        add(BAG_WORN,EQUIP_SLOT_OFF_HAND,EQUIP_SLOT_OFF_HAND)
    elseif kind == "BACK" then
        add(BAG_WORN,EQUIP_SLOT_BACKUP_MAIN,EQUIP_SLOT_BACKUP_MAIN)
    elseif kind == "BACK_OFF" then
        add(BAG_WORN,EQUIP_SLOT_BACKUP_OFF,EQUIP_SLOT_BACKUP_OFF)
    end

    local count = safeNumber(GetBagSize, 0, BAG_BACKPACK)
    for slot=0,count-1 do add(BAG_BACKPACK,slot,nil) end
    table.sort(out,function(a,b) return a.score > b.score end)
    return out
end

local function bestMetaForDest(candidates, dest)
    local best = nil
    for _,c in ipairs(candidates or {}) do
        if c.dest == dest and (not best or c.score > best.score) then best = c end
    end
    return best
end

local function appendMissing(missing, text)
    if text and text ~= "" then missing[#missing+1] = text end
end

local function appendUnique(list, seen, text)
    text = tostring(text or "")
    if text == "" or seen[text] then return end
    seen[text] = true
    list[#list+1] = text
end

local function addMetaCandidateImprovements(candidate, requirement, improvements, seen)
    if not candidate or not requirement then return end
    local setLabel = tostring(requirement.set or candidate.setName or "Item")
    if requirement.armor and not metaArmorTypeMatches(candidate.link, requirement.armor) then
        appendUnique(improvements,seen,setLabel .. ": prefer " .. tostring(requirement.armor) .. " armor weight")
    end
    if requirement.trait and not metaTraitMatches(candidate.link, requirement.trait) then
        appendUnique(improvements,seen,setLabel .. ": transmute/reconstruct to " .. tostring(requirement.trait))
    end
    if requirement.perfectedPreferred and not string.find(lower(itemName(candidate.link)), "perfected", 1, true) then
        appendUnique(improvements,seen,setLabel .. ": perfected version is the endgame target")
    end
end

function G:BuildMetaBodySelection(template)
    local selected, missing = {}, {}
    local body = template and template.body or {}
    if #body == 0 then return selected, missing, 0, 0 end

    local bulkIndex, bulkReq = nil, nil
    for i,req in ipairs(body) do
        if (tonumber(req.count) or 1) > 1 and (not bulkReq or (tonumber(req.count) or 1) > (tonumber(bulkReq.count) or 1)) then
            bulkIndex, bulkReq = i, req
        end
    end
    local singletons = {}
    for i,req in ipairs(body) do
        if i ~= bulkIndex then
            singletons[#singletons+1] = {req=req,candidates=self:CollectMetaCandidates(req,"BODY")}
        end
    end
    local bulkCandidates = bulkReq and self:CollectMetaCandidates(bulkReq,"BODY") or {}

    local bestAssign, bestScore = {}, -999999999
    local function evaluate(assign, used, baseScore)
        local coverage = 0
        for _,dest in ipairs(BODY_SLOTS) do
            if not used[dest] and bestMetaForDest(bulkCandidates,dest) then coverage = coverage + 1 end
        end
        local score = baseScore + coverage * 5000
        if score > bestScore then
            bestScore = score
            bestAssign = {}
            for k,v in pairs(assign) do bestAssign[k] = v end
        end
    end
    local function walk(index, assign, used, score)
        if index > #singletons then evaluate(assign,used,score); return end
        local entry = singletons[index]
        local tried = false
        local bestByDest = {}
        for _,c in ipairs(entry.candidates or {}) do
            if not used[c.dest] and (not bestByDest[c.dest] or c.score > bestByDest[c.dest].score) then bestByDest[c.dest] = c end
        end
        for dest,c in pairs(bestByDest) do
            tried = true
            used[dest] = true
            assign[index] = c
            walk(index+1,assign,used,score+c.score+8000)
            assign[index] = nil
            used[dest] = nil
        end
        -- Also consider skipping a conflicting singleton so the solver can choose
        -- the best partial meta combination when two special pieces share a slot.
        walk(index+1,assign,used,score-8000)
    end
    walk(1,{}, {},0)

    local matched, total = 0, 0
    local used = {}
    for i,entry in ipairs(singletons) do
        total = total + (tonumber(entry.req.count) or 1)
        local c = bestAssign[i]
        if c then
            selected[c.dest] = c
            used[c.dest] = true
            matched = matched + 1
        else
            appendMissing(missing, tostring(entry.req.set) .. " body piece")
        end
    end

    if bulkReq then
        local wanted = tonumber(bulkReq.count) or 1
        total = total + wanted
        local got = 0
        for _,dest in ipairs(BODY_SLOTS) do
            if not used[dest] and got < wanted then
                local c = bestMetaForDest(bulkCandidates,dest)
                if c then
                    selected[dest] = c
                    used[dest] = true
                    got = got + 1
                    matched = matched + 1
                end
            end
        end
        if got < wanted then appendMissing(missing, string.format("%s body: %d more piece%s", tostring(bulkReq.set), wanted-got, (wanted-got)==1 and "" or "s")) end
    end
    return selected, missing, matched, total
end

function G:BuildMetaPlan(template)
    local plan, missing, improvements, improvementSeen = {}, {}, {}, {}
    local matched, total = 0, 0
    if type(template) ~= "table" then return plan, missing, matched, total, improvements end

    local bodySelected, bodyMissing, bodyMatched, bodyTotal = self:BuildMetaBodySelection(template)
    matched, total = matched + bodyMatched, total + bodyTotal
    for _,text in ipairs(bodyMissing) do missing[#missing+1] = text end
    for dest,c in pairs(bodySelected) do
        if c then
            addMetaCandidateImprovements(c,c.requirement,improvements,improvementSeen)
            if c.bag ~= BAG_WORN then c.dest=dest; plan[#plan+1]=c end
        end
    end

    if template.neck then
        total = total + 1
        local c = self:CollectMetaCandidates(template.neck,"NECK")[1]
        if c then
            matched = matched + 1
            addMetaCandidateImprovements(c,template.neck,improvements,improvementSeen)
            if c.bag ~= BAG_WORN then c.dest=EQUIP_SLOT_NECK; plan[#plan+1]=c end
        else appendMissing(missing, tostring(template.neck.set) .. " necklace") end
    end

    local ringReqs = template.rings or {}
    if #ringReqs > 0 then
        total = total + #ringReqs
        local pools = {}
        for i,req in ipairs(ringReqs) do pools[i] = self:CollectMetaCandidates(req,"RING") end
        local bestPair, bestPairScore = nil, -999999999
        if #ringReqs == 2 then
            for _,a in ipairs(pools[1]) do
                for _,b in ipairs(pools[2]) do
                    if a.key ~= b.key then
                        local bonus = 0
                        if a.worn and b.worn and a.dest ~= b.dest then bonus = 100 end
                        local score = a.score + b.score + bonus
                        if score > bestPairScore then bestPairScore=score; bestPair={a,b} end
                    end
                end
            end
        end
        if bestPair then
            matched = matched + 2
            local occupied = {}
            for _,c in ipairs(bestPair) do if c.worn and c.dest then occupied[c.dest]=true end end
            local open = {}
            for _,dest in ipairs({EQUIP_SLOT_RING1,EQUIP_SLOT_RING2}) do if not occupied[dest] then open[#open+1]=dest end end
            local oi=1
            for i,c in ipairs(bestPair) do
                addMetaCandidateImprovements(c,ringReqs[i],improvements,improvementSeen)
                if not c.worn then c.dest=open[oi] or EQUIP_SLOT_RING1; oi=oi+1; plan[#plan+1]=c end
            end
        else
            for i,req in ipairs(ringReqs) do
                local c = pools[i] and pools[i][1] or nil
                if c then
                    matched = matched + 1
                    addMetaCandidateImprovements(c,req,improvements,improvementSeen)
                    if c.bag ~= BAG_WORN then
                        c.dest = i == 1 and EQUIP_SLOT_RING1 or EQUIP_SLOT_RING2
                        plan[#plan+1]=c
                    end
                else appendMissing(missing, tostring(req.set) .. " ring") end
            end
        end
    end

    local function chooseWeaponPair(mainReq, offReq, mainKind, offKind, mainDest, offDest, barLabel)
        if not mainReq and not offReq then return end
        if mainReq and offReq then
            total = total + 2
            local mainPool = self:CollectMetaCandidates(mainReq,mainKind)
            local offPool = self:CollectMetaCandidates(offReq,offKind)
            local bestMain,bestOff,bestScore = nil,nil,-999999999
            for _,a in ipairs(mainPool) do
                for _,b in ipairs(offPool) do
                    if a.key ~= b.key then
                        local score = (a.score or 0) + (b.score or 0)
                        if a.worn and a.dest == mainDest then score = score + 100 end
                        if b.worn and b.dest == offDest then score = score + 100 end
                        if score > bestScore then bestScore=score; bestMain=a; bestOff=b end
                    end
                end
            end
            -- If only one side is owned, still count/equip that side and report the other as missing.
            if not bestMain and mainPool[1] then bestMain = mainPool[1] end
            if not bestOff then
                for _,candidate in ipairs(offPool) do
                    if not bestMain or candidate.key ~= bestMain.key then bestOff = candidate break end
                end
            end
            if bestMain then
                matched = matched + 1
                addMetaCandidateImprovements(bestMain,mainReq,improvements,improvementSeen)
                if not (bestMain.worn and bestMain.dest == mainDest) then bestMain.dest=mainDest; plan[#plan+1]=bestMain end
            else
                appendMissing(missing,tostring(mainReq.set) .. " " .. tostring(mainReq.weapon or (barLabel .. " main hand")))
            end
            if bestOff then
                matched = matched + 1
                addMetaCandidateImprovements(bestOff,offReq,improvements,improvementSeen)
                if not (bestOff.worn and bestOff.dest == offDest) then bestOff.dest=offDest; plan[#plan+1]=bestOff end
            else
                appendMissing(missing,tostring(offReq.set) .. " " .. tostring(offReq.weapon or (barLabel .. " off hand")))
            end
            return
        end

        local req = mainReq or offReq
        local kind = mainReq and mainKind or offKind
        local dest = mainReq and mainDest or offDest
        total = total + 1
        local c = self:CollectMetaCandidates(req,kind)[1]
        if c then
            matched = matched + 1
            addMetaCandidateImprovements(c,req,improvements,improvementSeen)
            if not (c.worn and c.dest == dest) then c.dest=dest; plan[#plan+1]=c end
        else
            appendMissing(missing,tostring(req.set) .. " " .. tostring(req.weapon or (barLabel .. " weapon")))
        end
    end

    chooseWeaponPair(template.frontWeapon,template.frontOffhand,"FRONT","FRONT_OFF",EQUIP_SLOT_MAIN_HAND,EQUIP_SLOT_OFF_HAND,"front")
    chooseWeaponPair(template.backWeapon,template.backOffhand,"BACK","BACK_OFF",EQUIP_SLOT_BACKUP_MAIN,EQUIP_SLOT_BACKUP_OFF,"back")

    table.sort(plan,function(a,b) return (a.score or 0) > (b.score or 0) end)
    return plan, missing, matched, total, improvements
end

function G:PrintMetaMissing(template, missing, matched, total, improvements)
    if not EPC or not EPC.Print then return end
    local snapshot = EPC.EndgameMeta and EPC.EndgameMeta.SNAPSHOT or {}
    EPC:Print(string.format("BEST ENDGAME META: %s | %d/%d owned", tostring(template and template.label or "ENDGAME"), tonumber(matched) or 0, tonumber(total) or 0))
    if missing and #missing > 0 then
        EPC:Print("Missing from worn + backpack:")
        for _,line in ipairs(missing) do EPC:Print("  - " .. tostring(line)) end
    else
        EPC:Print("All curated meta requirements are present in worn + backpack gear.")
    end
    if improvements and #improvements > 0 then
        EPC:Print("Owned-piece improvements toward the exact meta target:")
        for _,line in ipairs(improvements) do EPC:Print("  - " .. tostring(line)) end
    end
end


function G:ReportMetaVerifiedChanges(beforeLinks, requested, template)
    local confirmed = 0
    for _,item in ipairs(requested or {}) do
        local before = beforeLinks[item.dest] or ""
        local after = safe(GetItemLink,"",BAG_WORN,item.dest,LINK_STYLE_DEFAULT or 0)
        if after ~= "" and after ~= before then confirmed = confirmed + 1 end
    end
    local remainingPlan,missing,matched,total,improvements = self:BuildMetaPlan(template)
    self:NotifyResult(string.format("BEST ENDGAME: %d/%d change%s confirmed | Meta gear owned %d/%d", confirmed, #(requested or {}), #(requested or {})==1 and "" or "s", matched, total), confirmed > 0 or (#missing==0 and #remainingPlan==0))
    self:PrintMetaMissing(template,missing,matched,total,improvements)
    if #remainingPlan > 0 and EPC and EPC.Print then EPC:Print("Some owned meta pieces are still not equipped. Run BEST ENDGAME again after ESO finishes inventory updates.") end
    if EPC and EPC.RequestRefresh then EPC:RequestRefresh("endgame-meta-verified") end
end

function G:EquipBestRecommended()
    if safe(IsUnitInCombat,false,"player")==true then self:NotifyResult("Endgame Gear: leave combat before changing equipment.", false); return false end
    if type(RequestEquipItem)~="function" then self:NotifyResult("Endgame Gear: ESO's equipment API is unavailable.", false); return false end
    local profile=self:GetProfile()
    local presetKey,preset = self:GetPreset()
    local template = self:GetMetaTemplate(profile,presetKey)

    -- Curated live-meta path. This is intentionally local/versioned: ESO addons
    -- cannot query websites at runtime, so the snapshot ships with the addon.
    if template then
        local plan,missing,matched,total,improvements = self:BuildMetaPlan(template)
        self:PrintMetaMissing(template,missing,matched,total,improvements)
        if #plan==0 then
            if #missing==0 then
                self:NotifyResult(string.format("BEST ENDGAME: current worn gear already matches the owned %s template.", tostring(template.label or preset.label)), true)
            else
                self:NotifyResult("BEST ENDGAME: no owned meta upgrades are available to equip. Missing pieces were printed in chat.", false)
            end
            return #missing==0
        end

        local beforeLinks = {}
        local requested = {}
        local equipped=0
        for _,item in ipairs(plan) do
            beforeLinks[item.dest] = safe(GetItemLink,"",BAG_WORN,item.dest,LINK_STYLE_DEFAULT or 0)
            if pcall(RequestEquipItem,item.bag,item.slot,BAG_WORN,item.dest) then
                equipped=equipped+1
                requested[#requested+1] = {dest=item.dest, expected=item.link}
            end
        end
        if equipped>0 then
            local snapshot = EPC.EndgameMeta and EPC.EndgameMeta.SNAPSHOT or {}
            self:NotifyResult(string.format("BEST ENDGAME: requested %d meta change%s...", equipped, equipped==1 and "" or "s"), true)
            local verify = function()
                self:ReportMetaVerifiedChanges(beforeLinks,requested,template)
            end
            if type(zo_callLater) == "function" then zo_callLater(verify,900) else verify() end
            return true
        end
        self:NotifyResult("BEST ENDGAME: ESO did not accept the meta equipment changes.", false)
        return false
    end

    -- Generic fallback for profiles that do not yet have a curated live template.
    local targets=self:GetTargetSets()
    local minimumTargets = presetKey == "SOLO" and 1 or 2
    if #targets<minimumTargets then
        self:NotifyResult("Endgame Gear: no curated live template exists for this class/role/preset yet. Configure " .. tostring(minimumTargets) .. " Target Set" .. (minimumTargets == 1 and "" or "s") .. " for the local optimizer.", false)
        return false
    end
    local beforeScore = self:ScoreCurrentLoadout(profile,presetKey)
    local plan=self:BuildPlan()
    if #plan==0 then
        self:NotifyResult(string.format("NO UPGRADES FOUND | Current score: %d", beforeScore), false)
        if EPC and EPC.Print then EPC:Print("Endgame Gear: your current loadout is already the best configuration I can build from worn + backpack gear for "..profile.label.." ["..preset.label.."].") end
        return false
    end

    local beforeLinks = {}
    local requested = {}
    local equipped=0
    for _,item in ipairs(plan) do
        beforeLinks[item.dest] = safe(GetItemLink,"",BAG_WORN,item.dest,LINK_STYLE_DEFAULT or 0)
        if pcall(RequestEquipItem,item.bag,item.slot,BAG_WORN,item.dest) then
            equipped=equipped+1
            requested[#requested+1] = {dest=item.dest, expected=item.link}
        end
    end
    if equipped>0 then
        self:NotifyResult(string.format("GEAR OPTIMIZER: requested %d change%s...", equipped, equipped==1 and "" or "s"), true)
        if type(zo_callLater) == "function" then
            zo_callLater(function()
                self:ReportVerifiedChanges(beforeLinks,beforeScore,requested,profile,presetKey,preset.label)
            end, 900)
        else
            self:ReportVerifiedChanges(beforeLinks,beforeScore,requested,profile,presetKey,preset.label)
        end
        return true
    end
    self:NotifyResult("Endgame Gear: ESO did not accept the equipment changes.", false)
    return false
end

local function isWeaponDestination(dest)
    return dest == EQUIP_SLOT_MAIN_HAND or dest == EQUIP_SLOT_OFF_HAND or dest == EQUIP_SLOT_BACKUP_MAIN or dest == EQUIP_SLOT_BACKUP_OFF
end

local function isJewelryDestination(dest)
    return dest == EQUIP_SLOT_NECK or dest == EQUIP_SLOT_RING1 or dest == EQUIP_SLOT_RING2
end

function G:EquipPlanSubset(label, predicate)
    if safe(IsUnitInCombat,false,"player") == true then
        self:NotifyResult(label .. ": leave combat before changing the loadout.", false)
        return false
    end
    if type(RequestEquipItem) ~= "function" then
        self:NotifyResult(label .. ": ESO's equipment API is unavailable.", false)
        return false
    end
    local plan = self:BuildPlan()
    local requested = {}
    local beforeLinks = {}
    for _,item in ipairs(plan or {}) do
        if predicate(item.dest, item) then
            beforeLinks[item.dest] = safe(GetItemLink,"",BAG_WORN,item.dest,LINK_STYLE_DEFAULT or 0)
            if pcall(RequestEquipItem,item.bag,item.slot,BAG_WORN,item.dest) then
                requested[#requested+1] = {dest=item.dest, expected=item.link}
            end
        end
    end
    if #requested == 0 then
        self:NotifyResult(label .. ": no upgrades found in worn + backpack gear.", false)
        return false
    end
    self:NotifyResult(string.format("%s: requested %d change%s.", label, #requested, #requested == 1 and "" or "s"), true)
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            local confirmed = 0
            for _,item in ipairs(requested) do
                local after = safe(GetItemLink,"",BAG_WORN,item.dest,LINK_STYLE_DEFAULT or 0)
                if after ~= "" and after ~= beforeLinks[item.dest] then confirmed = confirmed + 1 end
            end
            self:NotifyResult(string.format("%s: %d/%d change%s confirmed.", label, confirmed, #requested, #requested == 1 and "" or "s"), confirmed > 0)
            if EPC and EPC.RequestRefresh then EPC:RequestRefresh("best-loadout-subset") end
        end, 900)
    end
    return true
end

function G:EquipBestWeapons()
    return self:EquipPlanSubset("BEST WEAPONS", function(dest) return isWeaponDestination(dest) end)
end

function G:EquipBestJewelry()
    return self:EquipPlanSubset("BEST JEWELRY", function(dest) return isJewelryDestination(dest) end)
end

local function containsAny(text, words)
    text = lower(text)
    for _,word in ipairs(words or {}) do
        if string.find(text, lower(word), 1, true) then return true end
    end
    return false
end

function G:CollectPurchasedActiveAbilities()
    local out = {}
    local seen = {}
    local stats = {
        available = 0,
        normalPurchased = 0,
        normalUnresolved = 0,
        scribedPurchased = 0,
        scribedUnresolved = 0,
        scribedDisabled = 0,
    }
    if type(GetNumSkillTypes) ~= "function" or type(GetNumSkillLines) ~= "function" or type(GetNumSkillAbilities) ~= "function" or type(GetSkillAbilityInfo) ~= "function" then
        return out, stats
    end

    local function add(entry, key)
        if not entry or not key or seen[key] then return false end
        local abilityIndex = tonumber(entry.abilityIndex) or 0
        local abilityId = tonumber(entry.abilityId) or 0
        if abilityId <= 0 and abilityIndex > 0 and type(GetAbilityIdByIndex) == "function" then
            abilityId = safeNumber(GetAbilityIdByIndex, 0, abilityIndex)
            entry.abilityId = abilityId
        end
        if tostring(entry.name or "") == "" or abilityId <= 0 then return false end
        if entry.crafted ~= true and abilityIndex <= 0 then return false end
        seen[key] = true
        entry.actionId = entry.crafted == true and (tonumber(entry.craftedAbilityId) or abilityId) or abilityId
        out[#out+1] = entry
        stats.available = stats.available + 1
        if entry.crafted == true then stats.scribedPurchased = stats.scribedPurchased + 1
        else stats.normalPurchased = stats.normalPurchased + 1 end
        return true
    end

    -- Keep the proven pre-Scribing normal-skill enumeration path intact. The
    -- previous 0.29.10 collector made normal skills depend on the newer crafted
    -- ability resolution path and could collapse the regular candidate pool to
    -- zero on live clients. Normal abilities are resolved independently first.
    for skillType=1,safeNumber(GetNumSkillTypes,0) do
        for skillLine=1,safeNumber(GetNumSkillLines,0,skillType) do
            local count=safeNumber(GetNumSkillAbilities,0,skillType,skillLine)
            local lineId=type(GetSkillLineId)=="function" and safeNumber(GetSkillLineId,0,skillType,skillLine) or 0
            local lineName=easSkillLineName and easSkillLineName(skillType,skillLine,lineId) or ""
            for skillIndex=1,count do
                local crafted=type(IsCraftedAbilitySkill)=="function" and safe(IsCraftedAbilitySkill,false,skillType,skillLine,skillIndex)==true
                if not crafted then
                    local name,texture,earnedRank,passive,ultimate,purchased,progressionIndex,rank=safe(GetSkillAbilityInfo,nil,skillType,skillLine,skillIndex)
                    if purchased==true and passive~=true and name and name~="" then
                        local abilityName=tostring(name)
                        local abilityIndex=0
                        local abilityId=type(GetSkillAbilityId)=="function" and safeNumber(GetSkillAbilityId,0,skillType,skillLine,skillIndex,false) or 0
                        if progressionIndex and type(GetAbilityProgressionInfo)=="function" and type(GetAbilityProgressionAbilityInfo)=="function" then
                            local _,morphChoice,currentRank=safe(GetAbilityProgressionInfo,nil,progressionIndex)
                            local resolvedRank=tonumber(currentRank)
                            if not resolvedRank or resolvedRank<=0 then resolvedRank=tonumber(rank) or 1 end
                            local morphedName,_,idx=safe(GetAbilityProgressionAbilityInfo,nil,progressionIndex,tonumber(morphChoice) or 0,resolvedRank)
                            if morphedName and morphedName~="" then abilityName=tostring(morphedName) end
                            abilityIndex=tonumber(idx) or 0
                        end
                        if abilityIndex<=0 and abilityId>0 and type(GetAbilityIndex)=="function" then
                            abilityIndex=safeNumber(GetAbilityIndex,0,abilityId)
                        end
                        if abilityIndex>0 and type(GetAbilityIdByIndex)=="function" then
                            local liveId=safeNumber(GetAbilityIdByIndex,0,abilityIndex)
                            if liveId>0 then abilityId=liveId end
                        end
                        local key=string.format("normal:%d:%d:%d",tonumber(skillType) or 0,tonumber(skillLine) or 0,tonumber(skillIndex) or 0)
                        if not add({
                            name=abilityName, abilityIndex=abilityIndex, abilityId=abilityId,
                            ultimate=ultimate==true, skillType=skillType, skillLine=skillLine,
                            skillIndex=skillIndex, skillLineId=lineId, skillLineName=lineName,
                            progressionIndex=progressionIndex, crafted=false,
                        },key) then
                            stats.normalUnresolved=stats.normalUnresolved+1
                        end
                    end
                end
            end
        end
    end

    -- Add Scribed abilities as a second, independent pass. A failure to resolve
    -- a Grimoire can never suppress or invalidate the normal purchased skills.
    if type(IsCraftedAbilitySkill)=="function" then
        for skillType=1,safeNumber(GetNumSkillTypes,0) do
            for skillLine=1,safeNumber(GetNumSkillLines,0,skillType) do
                local count=safeNumber(GetNumSkillAbilities,0,skillType,skillLine)
                local lineId=type(GetSkillLineId)=="function" and safeNumber(GetSkillLineId,0,skillType,skillLine) or 0
                local lineName=easSkillLineName and easSkillLineName(skillType,skillLine,lineId) or ""
                for skillIndex=1,count do
                    if safe(IsCraftedAbilitySkill,false,skillType,skillLine,skillIndex)==true then
                        local craftedAbilityId=type(GetCraftedAbilitySkillCraftedAbilityId)=="function" and safeNumber(GetCraftedAbilitySkillCraftedAbilityId,0,skillType,skillLine,skillIndex) or 0
                        local isScribed=craftedAbilityId>0
                        if isScribed and type(IsCraftedAbilityScribed)=="function" then isScribed=safe(IsCraftedAbilityScribed,false,craftedAbilityId)==true end
                        local disabled=craftedAbilityId>0 and type(IsCraftedAbilityDisabled)=="function" and safe(IsCraftedAbilityDisabled,false,craftedAbilityId)==true
                        if isScribed and disabled then
                            stats.scribedDisabled=stats.scribedDisabled+1
                        elseif isScribed then
                            local abilityId=type(GetAbilityIdForCraftedAbilityId)=="function" and safeNumber(GetAbilityIdForCraftedAbilityId,0,craftedAbilityId) or 0
                            if abilityId<=0 and type(GetCraftedAbilityRepresentativeAbilityId)=="function" then abilityId=safeNumber(GetCraftedAbilityRepresentativeAbilityId,0,craftedAbilityId) end
                            local abilityIndex=abilityId>0 and type(GetAbilityIndex)=="function" and safeNumber(GetAbilityIndex,0,abilityId) or 0
                            local abilityName=abilityId>0 and type(GetAbilityName)=="function" and tostring(safe(GetAbilityName,"",abilityId) or "") or ""
                            if abilityName=="" and type(GetCraftedAbilityDisplayName)=="function" then abilityName=tostring(safe(GetCraftedAbilityDisplayName,"",craftedAbilityId) or "") end
                            local key="crafted:"..tostring(craftedAbilityId)
                            if not add({
                                name=abilityName, abilityIndex=abilityIndex, abilityId=abilityId,
                                ultimate=false, skillType=skillType, skillLine=skillLine,
                                skillIndex=skillIndex, skillLineId=lineId, skillLineName=lineName,
                                crafted=true, craftedAbilityId=craftedAbilityId,
                            },key) then
                                stats.scribedUnresolved=stats.scribedUnresolved+1
                            end
                        end
                    end
                end
            end
        end
    end
    return out,stats
end

local SORC_MAG_PRIORITY = {
    {"Crystal Fragments","Crystal Shard"},
    {"Daedric Prey","Haunting Curse","Daedric Curse"},
    {"Volatile Familiar","Unstable Familiar"},
    {"Twilight Tormentor","Twilight Matriarch","Winged Twilight"},
    {"Barbed Trap","Bound Aegis","Critical Surge","Unstable Wall of Elements","Elemental Blockade"},
}
local SORC_MAG_ULTIMATES = {"Greater Storm Atronach","Summon Charged Atronach","Summon Storm Atronach","Power Overload","Energy Overload","Overload"}

function G:ScoreFallbackAbility(a, profile)
    local score = 0
    local n = lower(a.name)
    if a.skillType == SKILL_TYPE_CLASS then score = score + 500 end
    if a.skillType == SKILL_TYPE_WEAPON then score = score + 260 end
    if a.skillType == SKILL_TYPE_GUILD then score = score + 120 end
    if profile.magicka then
        if containsAny(n,{"crystal","curse","prey","familiar","twilight","wall","surge","mage","orb","trap"}) then score=score+360 end
        if containsAny(n,{"stamina","poison","bow","dual wield"}) then score=score-120 end
    else
        if containsAny(n,{"weapon","poison","trap","blade","bow","stamina"}) then score=score+300 end
    end
    return score
end


local function EAS_BaseWornBuildContext(self)
    local profile = self:GetProfile()
    local role = EPC.Role and EPC.Role:GetRole() or "DAMAGE"
    local sets = {}
    local seen = {}
    if type(GetItemLink) == "function" then
        local slots = {
            EQUIP_SLOT_HEAD, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_HAND,
            EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_NECK,
            EQUIP_SLOT_RING1, EQUIP_SLOT_RING2, EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_BACKUP_MAIN,
        }
        for _,slot in ipairs(slots) do
            local link = safe(GetItemLink,"",BAG_WORN,slot,LINK_STYLE_DEFAULT or 0)
            local setName = setNameFor(link)
            if setName ~= "" and not seen[setName] then
                seen[setName] = true
                sets[#sets+1] = setName
            end
        end
    end
    table.sort(sets,function(a,b) return lower(a) < lower(b) end)
    local frontType = type(GetItemWeaponType)=="function" and safe(GetItemWeaponType,WEAPONTYPE_NONE or 0,BAG_WORN,EQUIP_SLOT_MAIN_HAND) or 0
    local backType = type(GetItemWeaponType)=="function" and safe(GetItemWeaponType,WEAPONTYPE_NONE or 0,BAG_WORN,EQUIP_SLOT_BACKUP_MAIN) or 0
    local function weaponLabel(w)
        if w == (WEAPONTYPE_FIRE_STAFF or -101) then return "Inferno Staff" end
        if w == (WEAPONTYPE_FROST_STAFF or -102) then return "Ice Staff" end
        if w == (WEAPONTYPE_LIGHTNING_STAFF or -103) then return "Lightning Staff" end
        if w == (WEAPONTYPE_HEALING_STAFF or -104) then return "Restoration Staff" end
        if w == (WEAPONTYPE_BOW or -105) then return "Bow" end
        if w == (WEAPONTYPE_DUAL_WIELD or -106) then return "Dual Wield" end
        if w == (WEAPONTYPE_TWO_HANDED_SWORD or -107) or w == (WEAPONTYPE_TWO_HANDED_AXE or -108) or w == (WEAPONTYPE_TWO_HANDED_HAMMER or -109) then return "Two Handed" end
        if w == (WEAPONTYPE_ONE_HAND_AND_SHIELD or -110) then return "One Hand + Shield" end
        return "Weapon"
    end
    local presetKey = select(1,self:GetPreset())
    local classRow = EPC.EndgameMeta and EPC.EndgameMeta.CLASSES and EPC.EndgameMeta.CLASSES[tonumber(profile.classId) or 0] or nil
    return {
        profile=profile, role=role, sets=sets, frontWeaponType=frontType, backWeaponType=backType,
        frontWeapon=weaponLabel(frontType), backWeapon=weaponLabel(backType),
        classId=tonumber(profile.classId) or 0,
        className=classRow and classRow.name or "Unknown Class",
        resource=profile.magicka and "MAGICKA" or "STAMINA",
        presetKey=presetKey,
    }
end

local function EAS_BaseScoreAbilityForCurrentBuild(self, a, context)
    local profile = context.profile or self:GetProfile()
    local role = context.role or "DAMAGE"
    local score = self:ScoreFallbackAbility(a, profile)
    local n = lower(a.name)
    local setText = lower(table.concat(context.sets or {}, " "))

    if role == "HEALER" then
        if containsAny(n,{"heal","healing","regeneration","ward","ritual","orb","prayer","combat prayer","matriarch"}) then score=score+700 end
        if a.skillType == SKILL_TYPE_WEAPON and (context.frontWeapon == "Restoration Staff" or context.backWeapon == "Restoration Staff") then score=score+220 end
        if containsAny(n,{"taunt","puncture"}) then score=score-260 end
    elseif role == "TANK" then
        if containsAny(n,{"taunt","puncture","armor","ward","shield","resolve","dark deal","vigor","block"}) then score=score+700 end
        if context.frontWeapon == "One Hand + Shield" or context.backWeapon == "One Hand + Shield" then
            if a.skillType == SKILL_TYPE_WEAPON then score=score+260 end
        end
        if containsAny(n,{"execute","spammable"}) then score=score-100 end
    else
        if containsAny(n,{"crystal fragments","daedric prey","haunting curse","barbed trap","wall of elements","elemental blockade","critical surge","bound aegis"}) then score=score+520 end
        if profile.magicka and (context.frontWeapon == "Inferno Staff" or context.frontWeapon == "Lightning Staff" or context.backWeapon == "Inferno Staff" or context.backWeapon == "Lightning Staff") then
            if containsAny(n,{"wall of elements","elemental blockade","force pulse","crushing shock"}) then score=score+320 end
        end
    end

    -- Light set-synergy signals. These do not hard-code one meta; they bias toward
    -- skills that make sense with common damage/support themes in the worn sets.
    if containsAny(setText,{"orders wrath","law of julianos","new moon acolyte","mother's sorrow","medusa"}) then
        if containsAny(n,{"crystal","curse","prey","trap","wall","surge","familiar","twilight"}) then score=score+180 end
    end
    if containsAny(setText,{"healer","spell power cure","olorime","roaring opportunist"}) and role == "HEALER" then
        if containsAny(n,{"heal","prayer","regeneration","orb","matriarch"}) then score=score+180 end
    end
    return score
end

function G:BuildBestAbilityView()
    local plan=self:BuildFullSkillPlan()
    local context=plan.context or self:GetWornBuildContext()
    return {
        context=context,
        abilities=plan.frontWanted or {},
        ultimate=plan.frontUltWanted,
        backAbilities=plan.backWanted or {},
        backUltimate=plan.backUltWanted,
        meta=plan.skillMeta,
        frontMetaStats=plan.frontMetaStats,
        backMetaStats=plan.backMetaStats,
        purchased=#(plan.allActive or {}),
    }
end

function G:ChooseBestAbilities()
    local view = self:BuildBestAbilityView()
    return view.abilities or {}, view.ultimate
end

-- Standalone BEST ABILITIES action removed in 0.29.14.
-- Skill/action-bar rebuilding is handled by RESPEC + BUILD below.


-- Full current-build skill respec / rebuild (v0.25.53)
-- Uses ESO's native full allocation request so the change is one user-initiated
-- transaction.  The planner intentionally spends points only on combat-relevant
-- skills; surplus points remain available for crafting or personal preferences.
function G:GetTotalSkillPointBudget()
    local available = type(GetAvailableSkillPoints) == "function" and safeNumber(GetAvailableSkillPoints,0) or 0
    local allocated = 0
    local mgr = rawget(_G,"SKILL_POINT_ALLOCATION_MANAGER")
    if mgr and type(mgr.GetNumPointsAllocatedInSkillLine) == "function" and type(GetNumSkillTypes) == "function" and type(GetNumSkillLines) == "function" then
        for skillType=1,safeNumber(GetNumSkillTypes,0) do
            for skillLine=1,safeNumber(GetNumSkillLines,0,skillType) do
                local ok,value = pcall(mgr.GetNumPointsAllocatedInSkillLine,mgr,skillType,skillLine)
                if ok then allocated = allocated + (tonumber(value) or 0) end
            end
        end
    end
    -- Fallback for clients where the allocation manager method signature differs.
    if allocated <= 0 and type(GetNumSkillTypes) == "function" and type(GetNumSkillLines) == "function" and type(GetNumSkillAbilities) == "function" then
        for skillType=1,safeNumber(GetNumSkillTypes,0) do
            for skillLine=1,safeNumber(GetNumSkillLines,0,skillType) do
                for skillIndex=1,safeNumber(GetNumSkillAbilities,0,skillType,skillLine) do
                    local _,_,_,passive,_,purchased,progressionIndex,rank = safe(GetSkillAbilityInfo,nil,skillType,skillLine,skillIndex)
                    if purchased == true then
                        if passive == true then allocated = allocated + math.max(1,tonumber(rank) or 1)
                        else
                            allocated = allocated + 1
                            if progressionIndex and type(GetAbilityProgressionInfo) == "function" then
                                local _,morphChoice = safe(GetAbilityProgressionInfo,nil,progressionIndex)
                                if (tonumber(morphChoice) or 0) > 0 then allocated = allocated + 1 end
                            end
                        end
                    end
                end
            end
        end
    end
    return math.max(0,available + allocated), available, allocated
end

local function EAS_BaseScorePassiveForCurrentBuild(self, entry, context)
    local n = lower(entry.name or "")
    local role = context.role or "DAMAGE"
    local profile = context.profile or self:GetProfile()
    local score = 0
    if entry.skillType == SKILL_TYPE_CLASS then score = score + 820
    elseif entry.skillType == SKILL_TYPE_RACIAL then score = score + 760
    elseif entry.skillType == SKILL_TYPE_WEAPON then score = score + 580
    elseif entry.skillType == SKILL_TYPE_ARMOR then score = score + 500
    elseif entry.skillType == SKILL_TYPE_GUILD then score = score + 300
    elseif entry.skillType == SKILL_TYPE_WORLD then score = score + 180
    elseif entry.skillType == SKILL_TYPE_AVA then score = score + 140
    elseif entry.skillType == SKILL_TYPE_TRADESKILL then score = score - 1400 end

    if role == "TANK" then
        if containsAny(n,{"health","armor","resist","block","shield","stamina","constitution","heavy"}) then score=score+600 end
        if containsAny(n,{"healing received","mitigation","defense"}) then score=score+420 end
    elseif role == "HEALER" then
        if containsAny(n,{"heal","healing","magicka","recovery","restoration","support","spell","critical"}) then score=score+560 end
        if containsAny(n,{"damage done"}) then score=score+80 end
    else
        if profile.magicka then
            if containsAny(n,{"magicka","spell","critical","penetration","recovery","damage","light armor","elemental"}) then score=score+560 end
            if containsAny(n,{"stamina cost","bow","dual wield"}) then score=score-180 end
        else
            if containsAny(n,{"stamina","weapon","critical","penetration","recovery","damage","medium armor","martial"}) then score=score+560 end
            if containsAny(n,{"magicka cost"}) then score=score-120 end
        end
    end
    if EPC.SkillMeta and type(EPC.SkillMeta.GetPassiveBonus)=="function" and context and context.skillMeta then
        score = score + (tonumber(EPC.SkillMeta:GetPassiveBonus(entry.name,context.skillMeta)) or 0)
    end
    return score
end

local function easAbilityNameById(id, fallback)
    if tonumber(id) and tonumber(id) > 0 and type(GetAbilityName) == "function" then
        local name = safe(GetAbilityName,"",tonumber(id))
        if name and name ~= "" then return tostring(name) end
    end
    return tostring(fallback or "")
end

function G:ChooseBuildMorph(skillType,skillLine,skillIndex,progressionId,context,currentMorph,canMorph)
    local base = rawget(_G,"MORPH_SLOT_BASE") or 0
    local m1 = rawget(_G,"MORPH_SLOT_MORPH_1") or 1
    local m2 = rawget(_G,"MORPH_SLOT_MORPH_2") or 2
    if not progressionId or progressionId <= 0 or type(GetProgressionSkillMorphSlotAbilityId) ~= "function" then
        return base, type(GetSkillAbilityId)=="function" and safeNumber(GetSkillAbilityId,0,skillType,skillLine,skillIndex,false) or 0
    end
    -- Only spend the extra point on a morph when ESO reports that the
    -- progression has actually reached the morph point. Existing morphs may
    -- still be changed during a full respec.
    if canMorph ~= true and (tonumber(currentMorph) or base) == base then
        local baseId = safeNumber(GetProgressionSkillMorphSlotAbilityId,0,progressionId,base)
        if baseId <= 0 and type(GetSkillAbilityId)=="function" then
            baseId = safeNumber(GetSkillAbilityId,0,skillType,skillLine,skillIndex,false)
        end
        return base,baseId
    end
    local id1 = safeNumber(GetProgressionSkillMorphSlotAbilityId,0,progressionId,m1)
    local id2 = safeNumber(GetProgressionSkillMorphSlotAbilityId,0,progressionId,m2)
    if id1 <= 0 and id2 <= 0 then
        local baseId = safeNumber(GetProgressionSkillMorphSlotAbilityId,0,progressionId,base)
        return base,baseId
    end
    local function morphScore(id,slot)
        if id <= 0 then return -100000 end
        local pseudo={name=easAbilityNameById(id,""),skillType=skillType,skillLine=skillLine,ultimate=false}
        local score=self:ScoreAbilityForCurrentBuild(pseudo,context)
        if slot == currentMorph then score=score+25 end
        return score
    end
    local s1,s2=morphScore(id1,m1),morphScore(id2,m2)
    if s2 > s1 then return m2,id2 end
    return m1,id1
end

local function easSkillLineName(skillType, skillLine, lineId)
    if tonumber(lineId) and tonumber(lineId) > 0 and type(GetSkillLineNameById) == "function" then
        local name = safe(GetSkillLineNameById,"",tonumber(lineId))
        if name and name ~= "" then return tostring(name) end
    end
    if type(GetSkillLineInfo) == "function" then
        local name = safe(GetSkillLineInfo,"",skillType,skillLine)
        if name and name ~= "" then return tostring(name) end
    end
    return ""
end

function G:GetWeaponSkillFamily(weaponType)
    local w=tonumber(weaponType) or 0
    if w==(WEAPONTYPE_FIRE_STAFF or -101) or w==(WEAPONTYPE_FROST_STAFF or -102) or w==(WEAPONTYPE_LIGHTNING_STAFF or -103) then return "destruction staff" end
    if w==(WEAPONTYPE_HEALING_STAFF or -104) then return "restoration staff" end
    if w==(WEAPONTYPE_BOW or -105) then return "bow" end
    if w==(WEAPONTYPE_DUAL_WIELD or -106) then return "dual wield" end
    if w==(WEAPONTYPE_TWO_HANDED_SWORD or -107) or w==(WEAPONTYPE_TWO_HANDED_AXE or -108) or w==(WEAPONTYPE_TWO_HANDED_HAMMER or -109) then return "two handed" end
    if w==(WEAPONTYPE_ONE_HAND_AND_SHIELD or -110) then return "one hand and shield" end
    return ""
end

function G:IsPlannedAbilityCompatibleWithWeapon(entry, weaponType)
    if not entry or entry.skillType ~= SKILL_TYPE_WEAPON then return true end
    local family=self:GetWeaponSkillFamily(weaponType)
    if family=="" then return false end
    local line=lower(entry.skillLineName or "")
    if family=="one hand and shield" then
        return containsAny(line,{"one hand and shield","one hand & shield","sword and shield"})
    end
    if family=="two handed" then return containsAny(line,{"two handed","two-handed"}) end
    return string.find(line,family,1,true)~=nil
end


local function EAS_BaseSkillMetaForContext(self, context)
    context=context or self:GetWornBuildContext()
    local presetKey=context.presetKey or select(1,self:GetPreset())
    if not EPC.SkillMeta or type(EPC.SkillMeta.GetProfile)~="function" then return nil,presetKey end
    local profile=context.profile or self:GetProfile()
    local meta=EPC.SkillMeta:GetProfile(profile.classId,context.role or profile.role,profile.magicka,presetKey)
    context.skillMeta=meta
    context.skillPreset=presetKey
    return meta,presetKey
end

local function easMetaEntryKey(e)
    if not e then return nil end
    return tostring(e.skillType)..":"..tostring(e.skillLine)..":"..tostring(e.skillIndex)
end

function G:ApplyMetaMorphPreference(entry, desiredName)
    if not entry or not desiredName or not EPC.SkillMeta or type(EPC.SkillMeta.NameMatches)~="function" then return false end
    local function matches(name) return EPC.SkillMeta:NameMatches(name,desiredName) end
    if matches(entry.name) then
        entry.metaPreferredName=tostring(desiredName)
        return true
    end
    -- If the profile named the base skill, keep the planner's best available
    -- morph. Profiles list the preferred morph first and the base skill last.
    if matches(entry.baseName) then
        entry.metaPreferredName=tostring(desiredName)
        return true
    end
    local progressionId=tonumber(entry.progressionId) or 0
    if progressionId<=0 or type(GetProgressionSkillMorphSlotAbilityId)~="function" then return false end
    local base=rawget(_G,"MORPH_SLOT_BASE") or 0
    local slots={base,rawget(_G,"MORPH_SLOT_MORPH_1") or 1,rawget(_G,"MORPH_SLOT_MORPH_2") or 2}
    for _,morphSlot in ipairs(slots) do
        local abilityId=safeNumber(GetProgressionSkillMorphSlotAbilityId,0,progressionId,morphSlot)
        local morphName=easAbilityNameById(abilityId,"")
        if abilityId>0 and matches(morphName) then
            -- A morph can only be planned when ESO says the progression is at
            -- the morph point (or the character already owns a morph and can
            -- legally switch it during the full respec). Otherwise select the
            -- correct base skill and let it remain unmorphed rather than fail.
            if morphSlot~=base then
                if entry.canMorph==true or (tonumber(entry.currentMorph) or base)~=base then
                    entry.morphSlot=morphSlot
                    entry.abilityId=abilityId
                    entry.name=morphName
                end
            end
            entry.metaPreferredName=tostring(desiredName)
            return true
        end
    end
    return false
end

-- 0.29.395 - Resolve a curated SkillMeta choice to the exact ESO morph slot.
-- ApplyMetaMorphPreference can return early when entry.name already matches the
-- requested display name.  That is normally harmless, but it can leave the
-- entry's morphSlot pointing at the generic scorer's previously selected morph.
-- Bound Armor -> Bound Armaments/Bound Aegis exposed this: the bar contained the
-- correct progression, while the pending respec committed the opposite morph.
function G:ForceExactMetaMorph029395(entry)
    if not entry or not entry.metaPreferredName then return false end
    if not EPC.SkillMeta or type(EPC.SkillMeta.NameMatches)~="function" then return false end
    local progressionId=tonumber(entry.progressionId) or 0
    if progressionId<=0 or type(GetProgressionSkillMorphSlotAbilityId)~="function" then return false end

    local wanted=tostring(entry.metaPreferredName)
    local base=rawget(_G,"MORPH_SLOT_BASE") or 0
    local m1=rawget(_G,"MORPH_SLOT_MORPH_1") or 1
    local m2=rawget(_G,"MORPH_SLOT_MORPH_2") or 2
    for _,morphSlot in ipairs({m1,m2,base}) do
        local abilityId=safeNumber(GetProgressionSkillMorphSlotAbilityId,0,progressionId,morphSlot)
        if abilityId>0 then
            local name=easAbilityNameById(abilityId,"")
            if EPC.SkillMeta:NameMatches(name,wanted) then
                -- A requested morph can only be committed when this progression
                -- has actually reached ESO's morph point.  Buying a base skill
                -- during a respec does not grant the XP needed to morph it.
                -- Keep the requested morph as a future target, but stage the base
                -- skill now so MAX POWER applies the strongest legal build instead
                -- of repeatedly submitting an impossible morph transaction.
                if morphSlot~=base and entry.canMorph~=true and (tonumber(entry.currentMorph) or base)==base then
                    entry.desiredMorphSlot029396=morphSlot
                    entry.desiredMorphAbilityId029396=abilityId
                    entry.desiredMorphName029396=name~="" and name or wanted
                    entry.morphBlockedByProgression029396=true
                    local baseId=safeNumber(GetProgressionSkillMorphSlotAbilityId,0,progressionId,base)
                    if baseId>0 then entry.abilityId=baseId end
                    entry.morphSlot=base
                    entry.name=entry.baseName or easAbilityNameById(baseId,entry.name)
                    entry.metaExactMorph029395=true
                    return true
                end
                entry.morphSlot=morphSlot
                entry.abilityId=abilityId
                entry.name=name~="" and name or wanted
                entry.metaExactMorph029395=true
                return true
            end
        end
    end
    return false
end

function G:FindMetaAbilityEntry(active, candidates, context, isBackup, used, wantUltimate)
    if type(candidates)=="string" then candidates={candidates} end
    if type(candidates)~="table" then return nil,nil end
    local weaponType=isBackup and context.backWeaponType or context.frontWeaponType
    for _,desired in ipairs(candidates) do
        for _,entry in ipairs(active or {}) do
            local key=easMetaEntryKey(entry)
            if (entry.ultimate==true)==(wantUltimate==true) and not (used and used[key]) and self:IsPlannedAbilityCompatibleWithWeapon(entry,weaponType) then
                if self:ApplyMetaMorphPreference(entry,desired) then
                    return entry,tostring(desired)
                end
            end
        end
    end
    return nil,nil
end

function G:BuildMetaWeaponBar(active, context, isBackup, meta)
    if not meta then
        local wanted,ultimate=self:BuildPlannedWeaponBar(active,context,isBackup)
        return wanted,ultimate,{matched=0,fallback=5,requested=5,ultimateMatched=false}
    end
    local wantedBar=isBackup and meta.back or meta.front
    local wantedUlt=isBackup and meta.backUlt or meta.frontUlt
    local result,used={},{}
    local stats={matched=0,fallback=0,requested=5,slotMatches={},ultimateMatched=false}

    for i=1,5 do
        local candidates=wantedBar and wantedBar[i] or nil
        local entry,desired=self:FindMetaAbilityEntry(active,candidates,context,isBackup,used,false)
        if entry then
            local key=easMetaEntryKey(entry)
            used[key]=true
            result[i]=entry
            stats.matched=stats.matched+1
            stats.slotMatches[i]=desired
        end
    end

    -- Any meta skill the character has not unlocked (or that conflicts with the
    -- equipped weapon) is filled by the proven generic scorer. This keeps
    -- RESPEC + BUILD complete for leveling characters and unusual weapon bars.
    local fallback={}
    for _,entry in ipairs(active or {}) do
        if entry.ultimate~=true and not used[easMetaEntryKey(entry)] then
            local score=self:ScoreAbilityForWeaponBar(entry,context,isBackup)
            if score>-900000 then fallback[#fallback+1]={entry=entry,score=score} end
        end
    end
    table.sort(fallback,function(a,b)
        if a.score==b.score then return lower(a.entry.name)<lower(b.entry.name) end
        return a.score>b.score
    end)
    local fi=1
    for i=1,5 do
        if not result[i] then
            while fallback[fi] and used[easMetaEntryKey(fallback[fi].entry)] do fi=fi+1 end
            if fallback[fi] then
                local entry=fallback[fi].entry
                result[i]=entry
                used[easMetaEntryKey(entry)]=true
                stats.fallback=stats.fallback+1
                fi=fi+1
            end
        end
    end

    local ultimate,desiredUlt=self:FindMetaAbilityEntry(active,wantedUlt,context,isBackup,nil,true)
    if ultimate then
        stats.ultimateMatched=true
        stats.ultimateName=desiredUlt
    else
        local best,bestScore=nil,-1000000
        for _,entry in ipairs(active or {}) do
            if entry.ultimate==true then
                local score=self:ScoreAbilityForWeaponBar(entry,context,isBackup)
                if score>bestScore then best,bestScore=entry,score end
            end
        end
        ultimate=best
    end
    return result,ultimate,stats
end

function G:ScoreAbilityForWeaponBar(entry, context, isBackup)
    local score=self:ScoreAbilityForCurrentBuild(entry,context)
    local weaponType=isBackup and context.backWeaponType or context.frontWeaponType
    if not self:IsPlannedAbilityCompatibleWithWeapon(entry,weaponType) then return -1000000 end
    local n=lower(entry.name or "")
    local role=context.role or "DAMAGE"
    -- Primary/front emphasizes frequent attacks, executes and burst. Backup/back
    -- emphasizes DoTs, buffs, shields, healing and setup. Pets that disappear
    -- when unslotted are intentionally competitive on both bars.
    local persistentPet=containsAny(n,{"familiar","clannfear","twilight","tormentor","matriarch"})
    if isBackup then
        if containsAny(n,{"wall","blockade","stampede","volley","hail","trap","curse","prey","surge","armor","resolve","shield","ward","heal","regeneration","ritual","orb","vigor","buff","debuff"}) then score=score+330 end
        if containsAny(n,{"execute","spammable","crystal fragment","crushing shock","force pulse","rapid strikes","wrecking blow"}) then score=score-160 end
    else
        if containsAny(n,{"execute","spammable","crystal fragment","crushing shock","force pulse","rapid strikes","wrecking blow","snipe","whip","jabs","flurry"}) then score=score+300 end
        if role=="DAMAGE" and containsAny(n,{"heal","regeneration","ritual"}) then score=score-120 end
    end
    if persistentPet then score=score+240 end
    return score
end

function G:BuildPlannedWeaponBar(active, context, isBackup)
    local normals,ults={},{}
    for _,e in ipairs(active or {}) do
        local score=self:ScoreAbilityForWeaponBar(e,context,isBackup)
        if score>-900000 then
            local row={entry=e,score=score}
            if e.ultimate then ults[#ults+1]=row else normals[#normals+1]=row end
        end
    end
    local function sorter(a,b)
        if a.score==b.score then return lower(a.entry.name)<lower(b.entry.name) end
        return a.score>b.score
    end
    table.sort(normals,sorter); table.sort(ults,sorter)
    local chosen={}
    for i=1,math.min(5,#normals) do chosen[#chosen+1]=normals[i].entry end
    return chosen, ults[1] and ults[1].entry or nil
end


-- 0.29.393 - MAX POWER should only spend skill points on passives that can
-- materially benefit the selected build. The old e.score > 0 rule treated the
-- broad skill-type baseline as recommendation evidence and could buy/report
-- unrelated passives such as Improved Hiding or Bounty Hunter.
function G:IsPassiveRecommendedForMaxPower029393(entry,context)
    if not entry then return false end
    context=context or self:GetWornBuildContext()
    local metaBonus=0
    if EPC.SkillMeta and type(EPC.SkillMeta.GetPassiveBonus)=="function" and context.skillMeta then
        metaBonus=tonumber(EPC.SkillMeta:GetPassiveBonus(entry.name,context.skillMeta)) or 0
    end
    if metaBonus>0 then return true end

    local st=entry.skillType
    -- Class and racial passives are core character-power passives. Keep them
    -- even when their localized text does not contain one of our scoring words.
    if st==SKILL_TYPE_CLASS or st==SKILL_TYPE_RACIAL then return true end

    -- Weapon passives only matter when their line matches one of the two
    -- equipped weapon families.
    if st==SKILL_TYPE_WEAPON then
        return self:IsPlannedAbilityCompatibleWithWeapon(entry,context.frontWeaponType)
            or self:IsPlannedAbilityCompatibleWithWeapon(entry,context.backWeaponType)
    end

    local score=tonumber(entry.score) or self:ScorePassiveForCurrentBuild(entry,context) or 0
    -- Armor and miscellaneous lines must have actual build relevance above the
    -- generic category baseline. Curated SkillMeta priorities already returned
    -- above, so utility/crafting passives are not purchased just because points
    -- remain.
    if st==SKILL_TYPE_ARMOR then return score>=900 end
    if st==SKILL_TYPE_GUILD or st==SKILL_TYPE_WORLD or st==SKILL_TYPE_AVA then return score>=700 end
    return false
end

-- 0.29.394 - Distinguish mandatory MAX POWER passives from optional beneficial
-- extras. Optional extras may still be purchased when points remain, but they
-- must not make an otherwise correct build report BUILD INCOMPLETE.
function G:IsPassiveRequiredForMaxPowerCompletion029394(entry,context)
    if not entry then return false end
    context=context or self:GetWornBuildContext()
    local metaBonus=0
    if EPC.SkillMeta and type(EPC.SkillMeta.GetPassiveBonus)=="function" and context.skillMeta then
        metaBonus=tonumber(EPC.SkillMeta:GetPassiveBonus(entry.name,context.skillMeta)) or 0
    end
    if metaBonus>0 then return true end

    local st=entry.skillType
    -- Racial passives are always direct character power.
    if st==SKILL_TYPE_RACIAL then return true end
    -- Equipped-weapon passives are mandatory for a power build; unrelated
    -- weapon lines remain optional/unselected.
    if st==SKILL_TYPE_WEAPON then
        return self:IsPlannedAbilityCompatibleWithWeapon(entry,context.frontWeaponType)
            or self:IsPlannedAbilityCompatibleWithWeapon(entry,context.backWeaponType)
    end
    -- Armor passives only become mandatory when the relevance score shows an
    -- actual combat benefit for the current build. Class/guild/world/AVA
    -- passives not explicitly curated by SkillMeta are treated as optional
    -- extras rather than completion blockers.
    if st==SKILL_TYPE_ARMOR then
        local score=tonumber(entry.score) or self:ScorePassiveForCurrentBuild(entry,context) or 0
        return score>=900
    end
    return false
end

function G:BuildFullSkillPlan()
    local context=self:GetWornBuildContext()
    local skillMeta,skillPreset=self:GetSkillMetaForContext(context)
    local budget,available,allocated=self:GetTotalSkillPointBudget()
    local active,passives={},{}
    local playerLevel = type(GetUnitLevel)=="function" and safeNumber(GetUnitLevel,1,"player") or 1
    if type(GetNumSkillTypes) ~= "function" or type(GetNumSkillLines) ~= "function" or type(GetNumSkillAbilities) ~= "function" then
        return {context=context,budget=budget,available=available,allocated=allocated,active={},passives={},spent=0}
    end
    for skillType=1,safeNumber(GetNumSkillTypes,0) do
        for skillLine=1,safeNumber(GetNumSkillLines,0,skillType) do
            local lineRank,_,isActive,isDiscovered = safe(GetSkillLineDynamicInfo,nil,skillType,skillLine)
            if isDiscovered ~= false and isActive ~= false then
                local lineId=type(GetSkillLineId)=="function" and safeNumber(GetSkillLineId,0,skillType,skillLine) or 0
                for skillIndex=1,safeNumber(GetNumSkillAbilities,0,skillType,skillLine) do
                    local skipCrafted=type(IsCraftedAbilitySkill)=="function" and safe(IsCraftedAbilitySkill,false,skillType,skillLine,skillIndex)==true
                    local autoGrant=type(IsSkillAbilityAutoGrant)=="function" and safe(IsSkillAbilityAutoGrant,false,skillType,skillLine,skillIndex)==true
                    if not skipCrafted and not autoGrant then
                        local name,_,_,passive,ultimate,purchased,progressionIndex,currentRank=safe(GetSkillAbilityInfo,nil,skillType,skillLine,skillIndex)
                        local neededRank=type(GetSkillAbilityLineRankNeededToUnlock)=="function" and safeNumber(GetSkillAbilityLineRankNeededToUnlock,0,skillType,skillLine,skillIndex) or 0
                        local neededLevel=type(GetSkillAbilityCharacterLevelNeededToUnlock)=="function" and safeNumber(GetSkillAbilityCharacterLevelNeededToUnlock,0,skillType,skillLine,skillIndex) or 0
                        local unlocked=(tonumber(lineRank) or 0)>=neededRank and playerLevel>=neededLevel
                        if unlocked and name and name~="" then
                            if passive==true then
                                local maxRanks=type(GetNumPassiveSkillRanks)=="function" and safeNumber(GetNumPassiveSkillRanks,1,skillType,skillLine,skillIndex) or 1
                                if type(GetUpgradeSkillHighestRankAvailableAtSkillLineRank)=="function" then
                                    maxRanks=math.min(maxRanks, safeNumber(GetUpgradeSkillHighestRankAvailableAtSkillLineRank,maxRanks,skillType,skillLine,skillIndex,tonumber(lineRank) or 0))
                                end
                                local e={name=tostring(name),skillType=skillType,skillLine=skillLine,skillIndex=skillIndex,skillLineId=lineId,skillLineName=easSkillLineName(skillType,skillLine,lineId),maxRank=math.max(1,maxRanks),currentRank=purchased==true and math.max(1,tonumber(currentRank) or 1) or 0}
                                e.score=self:ScorePassiveForCurrentBuild(e,context)
                                passives[#passives+1]=e
                            else
                                local progressionId=type(GetProgressionSkillProgressionId)=="function" and safeNumber(GetProgressionSkillProgressionId,0,skillType,skillLine,skillIndex) or 0
                                local currentMorph=rawget(_G,"MORPH_SLOT_BASE") or 0
                                local progressionRank=tonumber(currentRank) or 1
                                local canMorph=false
                                if progressionIndex and type(GetAbilityProgressionInfo)=="function" then
                                    local _,mc,pr=safe(GetAbilityProgressionInfo,nil,progressionIndex)
                                    currentMorph=tonumber(mc) or currentMorph
                                    progressionRank=tonumber(pr) or progressionRank
                                end
                                if progressionIndex and type(GetAbilityProgressionXPInfo)=="function" then
                                    local _,_,_,atMorph=safe(GetAbilityProgressionXPInfo,nil,progressionIndex)
                                    canMorph=(atMorph==true) or ((tonumber(currentMorph) or (rawget(_G,"MORPH_SLOT_BASE") or 0)) ~= (rawget(_G,"MORPH_SLOT_BASE") or 0))
                                else
                                    canMorph=((tonumber(currentMorph) or (rawget(_G,"MORPH_SLOT_BASE") or 0)) ~= (rawget(_G,"MORPH_SLOT_BASE") or 0))
                                end
                                local morphSlot,abilityId=self:ChooseBuildMorph(skillType,skillLine,skillIndex,progressionId,context,currentMorph,canMorph)
                                local displayName=easAbilityNameById(abilityId,name)
                                local e={name=displayName,baseName=tostring(name),skillType=skillType,skillLine=skillLine,skillIndex=skillIndex,skillLineId=lineId,skillLineName=easSkillLineName(skillType,skillLine,lineId),progressionId=progressionId,progressionIndex=progressionIndex,progressionRank=progressionRank,morphSlot=morphSlot,abilityId=abilityId,ultimate=ultimate==true,purchased=purchased==true,currentMorph=currentMorph,canMorph=canMorph}
                                e.score=self:ScoreAbilityForCurrentBuild(e,context)
                                active[#active+1]=e
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(active,function(a,b) if a.score==b.score then return lower(a.name)<lower(b.name) end return a.score>b.score end)
    table.sort(passives,function(a,b) if a.score==b.score then return lower(a.name)<lower(b.name) end return a.score>b.score end)

    -- Plan Primary and Backup independently from their equipped weapon types.
    -- The purchase list is the union of both bar plans, so the respec buys the
    -- skills needed by either weapon rather than taking a generic top-ten list.
    local frontWanted,frontUltWanted,frontMetaStats
    local backWanted,backUltWanted,backMetaStats
    if skillMeta then
        frontWanted,frontUltWanted,frontMetaStats=self:BuildMetaWeaponBar(active,context,false,skillMeta)
        backWanted,backUltWanted,backMetaStats=self:BuildMetaWeaponBar(active,context,true,skillMeta)
    else
        frontWanted,frontUltWanted=self:BuildPlannedWeaponBar(active,context,false)
        backWanted,backUltWanted=self:BuildPlannedWeaponBar(active,context,true)
        frontMetaStats={matched=0,fallback=5,requested=5,ultimateMatched=false}
        backMetaStats={matched=0,fallback=5,requested=5,ultimateMatched=false}
    end

    -- Curated profile names are authoritative for morph choice. Normalize the
    -- selected bar entries now, before they are deduplicated into the purchase
    -- plan, budgeted, morphed, staged, or verified. This prevents a generic
    -- pre-score morph from surviving when the requested SkillMeta name already
    -- happened to match the entry's display name.
    if skillMeta then
        for _,e in ipairs(frontWanted or {}) do self:ForceExactMetaMorph029395(e) end
        for _,e in ipairs(backWanted or {}) do self:ForceExactMetaMorph029395(e) end
        self:ForceExactMetaMorph029395(frontUltWanted)
        self:ForceExactMetaMorph029395(backUltWanted)
    end

    local chosen,chosenMap={},{}
    local chosenUlts={}
    local spent=0
    local baseMorph=rawget(_G,"MORPH_SLOT_BASE") or 0
    local function entryKey(e)
        if not e then return nil end
        return tonumber(e.progressionId) or (tostring(e.skillType)..":"..tostring(e.skillLine)..":"..tostring(e.skillIndex))
    end
    local function addActive(e,target)
        if not e then return false end
        local key=entryKey(e)
        if chosenMap[key] then return true end
        -- Secure the base skill first. Morph upgrades are budgeted only after
        -- both weapon bars (5 normal skills + Ultimate each) are complete.
        local cost=1
        if spent+cost>budget then return false end
        target[#target+1]=e; chosenMap[key]=true; spent=spent+cost
        return true
    end

    -- Reserve Ultimates BEFORE normal skills/passives. An earlier build could
    -- consume the point budget on normal abilities and leave Backup Ultimate
    -- empty even though a legal class Ultimate was available.
    addActive(frontUltWanted,chosenUlts)
    addActive(backUltWanted,chosenUlts)

    -- Interleave normal skills so both bars develop together.
    for i=1,5 do addActive(frontWanted[i],chosen); addActive(backWanted[i],chosen) end

    -- Build the FINAL bars from skills that are actually in the purchase plan.
    -- If one bar's fifth choice was skipped by the point budget, keep searching
    -- the selected pool (then the remaining ranked pool) for another compatible
    -- ability instead of staging an unpurchased skill and leaving slot 5 blank.
    local function rebuildBar(isBackup, originalWanted)
        local result,used={},{}
        local function tryAdd(e, allowPurchase)
            if not e or #result>=5 or e.ultimate then return false end
            local key=entryKey(e)
            if used[key] then return false end
            if self:ScoreAbilityForWeaponBar(e,context,isBackup)<=-900000 then return false end
            if not chosenMap[key] then
                if not allowPurchase or not addActive(e,chosen) then return false end
            end
            used[key]=true
            result[#result+1]=e
            return true
        end
        -- Keep each bar's highest-ranked intended choices first.
        for _,e in ipairs(originalWanted or {}) do tryAdd(e,false) end
        -- Reuse skills selected for the other bar when compatible. This both
        -- fills all five slots and avoids wasting skill points on duplicates.
        for _,e in ipairs(chosen) do tryAdd(e,false) end
        -- If still short and points remain, purchase the next legal candidates.
        for _,e in ipairs(active or {}) do
            if #result>=5 then break end
            tryAdd(e,true)
        end
        return result
    end

    frontWanted=rebuildBar(false,frontWanted)
    backWanted=rebuildBar(true,backWanted)

    -- Ultimate fallback: if a bar-specific Ultimate could not be purchased, use
    -- any already-selected legal Ultimate before leaving the slot empty.
    local function finalUltimate(isBackup,wanted)
        local function compatible(e)
            return e and e.ultimate and self:ScoreAbilityForWeaponBar(e,context,isBackup)>-900000
        end
        if wanted and chosenMap[entryKey(wanted)] and compatible(wanted) then return wanted end
        for _,e in ipairs(chosenUlts) do if compatible(e) then return e end end
        -- Last chance: purchase the next legal Ultimate if budget permits.
        local candidates={}
        for _,e in ipairs(active or {}) do
            if e.ultimate and compatible(e) then
                candidates[#candidates+1]={entry=e,score=self:ScoreAbilityForWeaponBar(e,context,isBackup)}
            end
        end
        table.sort(candidates,function(a,b) return a.score>b.score end)
        for _,row in ipairs(candidates) do
            if addActive(row.entry,chosenUlts) then return row.entry end
        end
        return nil
    end
    frontUltWanted=finalUltimate(false,frontUltWanted)
    backUltWanted=finalUltimate(true,backUltWanted)

    -- Bar completeness has priority over morphs/passives. Once the 12 bar
    -- targets are secured, spend remaining points on the recommended morphs.
    -- If there is not enough budget for a morph, keep the legal base ability
    -- rather than sacrificing slot 5 or an Ultimate.
    local morphedSeen={}
    local function budgetMorph(e)
        if not e then return end
        local key=entryKey(e)
        if morphedSeen[key] then return end
        morphedSeen[key]=true
        if e.morphSlot and e.morphSlot~=baseMorph then
            if spent+1<=budget then
                spent=spent+1
            else
                e.morphSlot=baseMorph
                if type(GetProgressionSkillMorphSlotAbilityId)=="function" and (tonumber(e.progressionId) or 0)>0 then
                    local baseId=safeNumber(GetProgressionSkillMorphSlotAbilityId,0,e.progressionId,baseMorph)
                    if baseId>0 then e.abilityId=baseId end
                elseif type(GetSkillAbilityId)=="function" then
                    local baseId=safeNumber(GetSkillAbilityId,0,e.skillType,e.skillLine,e.skillIndex,false)
                    if baseId>0 then e.abilityId=baseId end
                end
                e.name=e.baseName or e.name
            end
        end
    end
    for _,e in ipairs(chosenUlts) do budgetMorph(e) end
    for _,e in ipairs(chosen) do budgetMorph(e) end

    local desiredPassiveRanks={}
    for _,e in ipairs(passives) do
        if self:IsPassiveRecommendedForMaxPower029393(e,context) then
            local can=math.min(e.maxRank,math.max(0,budget-spent))
            if can>0 then desiredPassiveRanks[e]=can spent=spent+can end
        end
    end
    return {context=context,budget=budget,available=available,allocated=allocated,allActive=active,allPassives=passives,chosen=chosen,chosenUlts=chosenUlts,chosenMap=chosenMap,frontWanted=frontWanted,backWanted=backWanted,frontUltWanted=frontUltWanted,backUltWanted=backUltWanted,desiredPassiveRanks=desiredPassiveRanks,spent=spent,skillMeta=skillMeta,skillMetaPreset=skillPreset,frontMetaStats=frontMetaStats,backMetaStats=backMetaStats}
end

local function easProtectedOrDirect(functionName,...)
    local fn=rawget(_G,functionName)
    if type(fn)=="function" then
        local ok,a,b=pcall(fn,...)
        if ok then return true,a,b end
    end
    if type(CallSecureProtected)=="function" then
        local ok,a,b=pcall(CallSecureProtected,functionName,...)
        if ok and a~=false then return true,a,b end
    end
    return false
end


function G:ResolvePlannedAbilityIndex(entry)
    if not entry then return nil end
    local progressionIndex=tonumber(entry.progressionIndex)
    if (not progressionIndex or progressionIndex<=0) and type(GetProgressionSkillProgressionIndex)=="function" then
        progressionIndex=safeNumber(GetProgressionSkillProgressionIndex,0,entry.skillType,entry.skillLine,entry.skillIndex)
    end
    if progressionIndex and progressionIndex>0 and type(GetAbilityProgressionInfo)=="function" and type(GetAbilityProgressionAbilityInfo)=="function" then
        local _,morph,rank=safe(GetAbilityProgressionInfo,nil,progressionIndex)
        local _,_,abilityIndex=safe(GetAbilityProgressionAbilityInfo,nil,progressionIndex,tonumber(morph) or 0,tonumber(rank) or 1)
        if tonumber(abilityIndex) and tonumber(abilityIndex)>0 then return tonumber(abilityIndex) end
    end
    if tonumber(entry.abilityId) and tonumber(entry.abilityId)>0 and type(GetAbilityIndex)=="function" then
        local idx=safeNumber(GetAbilityIndex,0,entry.abilityId)
        if idx>0 then return idx end
    end
    return nil
end

function G:GetAbilityLegalityForBar(abilityId, abilityIndex, slot, category, craftedAbilityId)
    abilityId=tonumber(abilityId) or 0
    abilityIndex=tonumber(abilityIndex) or 0
    craftedAbilityId=tonumber(craftedAbilityId) or 0
    if abilityId<=0 then return false,"missing ability id" end
    if craftedAbilityId<=0 and abilityIndex<=0 then return false,"missing normal ability index" end

    -- IMPORTANT: Do NOT reject a purchased skill because IsActionSlotMutable()
    -- reports false here. On live ESO that state can be false for a weapon bar
    -- that is not currently active (and in some UI states for both bars), while
    -- ACTION_BAR_ASSIGNMENT_MANAGER can still legally edit Primary/Backup out of
    -- combat. That pre-check was the reason 0.29.11/0.29.12 reduced a valid pool
    -- to zero regular candidates and printed "no unused compatible ability".
    --
    -- Planning only needs to know whether the ACTION TYPE belongs in a regular
    -- slot or the Ultimate slot. Actual edit permission is decided when ESO's
    -- assignment manager / protected slot API receives the requested change.
    if craftedAbilityId>0 then
        if type(IsValidCraftedAbilityForSlot)=="function" and safe(IsValidCraftedAbilityForSlot,false,craftedAbilityId,slot)~=true then
            return false,"scribed ability is not valid for this slot"
        end
    elseif type(IsValidAbilityForSlot)=="function" and safe(IsValidAbilityForSlot,false,abilityIndex,slot)~=true then
        return false,"ability type is not valid for this slot"
    end
    return true,"slot type legal"
end

function G:IsAbilityLegalForBar(abilityId, abilityIndex, slot, category, craftedAbilityId)
    local legal=self:GetAbilityLegalityForBar(abilityId,abilityIndex,slot,category,craftedAbilityId)
    return legal==true
end

function G:BuildCompatiblePurchasedBar(category, context)
    local pool,poolStats=self:CollectPurchasedActiveAbilities()
    local normal,ults={},{}
    local stats={
        available=#(pool or {}),
        normalPurchased=poolStats and poolStats.normalPurchased or 0,
        normalUnresolved=poolStats and poolStats.normalUnresolved or 0,
        scribedPurchased=poolStats and poolStats.scribedPurchased or 0,
        scribedUnresolved=poolStats and poolStats.scribedUnresolved or 0,
        scribedDisabled=poolStats and poolStats.scribedDisabled or 0,
        hotbarLegal=0,
        hotbarRejected=0,
        buildFiltered=0,
        regularCandidates=0,
        ultimateCandidates=0,
        rejectReasons={},
    }
    for _,a in ipairs(pool or {}) do
        local abilityId=tonumber(a.abilityId) or 0
        a.abilityId=abilityId
        local first=tonumber(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX) or 3
        local probeSlot=a.ultimate and (tonumber(ACTION_BAR_ULTIMATE_SLOT_INDEX) or (first+5)) or first
        local legal,reason=self:GetAbilityLegalityForBar(abilityId,a.abilityIndex,probeSlot,category,a.craftedAbilityId)
        if legal then
            stats.hotbarLegal=stats.hotbarLegal+1
            if (not a.skillLineName or a.skillLineName=="") and a.skillType and a.skillLine then
                local lineId=type(GetSkillLineId)=="function" and safeNumber(GetSkillLineId,0,a.skillType,a.skillLine) or 0
                a.skillLineName=easSkillLineName(a.skillType,a.skillLine,lineId)
            end
            local isBackup=category==(rawget(_G,"HOTBAR_CATEGORY_BACKUP") or 1)
            local score=self:ScoreAbilityForWeaponBar(a,context,isBackup)
            if score>-900000 then
                local row={ability=a,score=score}
                if a.ultimate then ults[#ults+1]=row else normal[#normal+1]=row end
            else
                stats.buildFiltered=stats.buildFiltered+1
            end
        else
            stats.hotbarRejected=stats.hotbarRejected+1
            reason=tostring(reason or "rejected")
            stats.rejectReasons[reason]=(stats.rejectReasons[reason] or 0)+1
        end
    end
    local function sorter(x,y)
        if x.score==y.score then return lower(x.ability.name)<lower(y.ability.name) end
        return x.score>y.score
    end
    table.sort(normal,sorter); table.sort(ults,sorter)
    stats.regularCandidates=#normal
    stats.ultimateCandidates=#ults
    local chosen={}
    for i=1,math.min(5,#normal) do chosen[#chosen+1]=normal[i].ability end
    return chosen,ults[1] and ults[1].ability or nil,normal,ults,stats
end

-- 0.29.388 - resolve a plan entry to the exact ability ID for its requested morph.
-- The plan can retain a base/progression-facing abilityId while ESO's hotbar stores
-- the current morph ability ID, so never compare only entry.abilityId.
function G:ResolvePlannedSlottableAbilityId029388(entry)
    if not entry then return 0 end
    local progressionId=tonumber(entry.progressionId) or 0
    local morphSlot=tonumber(entry.morphSlot)
    if progressionId>0 and morphSlot~=nil and type(GetProgressionSkillMorphSlotAbilityId)=="function" then
        local id=safeNumber(GetProgressionSkillMorphSlotAbilityId,0,progressionId,morphSlot)
        if id>0 then return id end
    end
    local id=tonumber(entry.abilityId) or 0
    if id>0 then return id end
    if type(GetSkillAbilityId)=="function" then
        id=safeNumber(GetSkillAbilityId,0,entry.skillType,entry.skillLine,entry.skillIndex,false)
        if id>0 then return id end
    end
    return 0
end

function G:DoesHotbarAbilityMatchPlan029388(gotAbilityId, entry, hotbarCategory)
    gotAbilityId=tonumber(gotAbilityId) or 0
    if gotAbilityId<=0 or not entry then return false end
    local want=self:ResolvePlannedSlottableAbilityId029388(entry)
    if want>0 and gotAbilityId==want then return true end
    if tonumber(entry.abilityId) and gotAbilityId==tonumber(entry.abilityId) then return true end

    -- 0.29.392: ESO can expose a weapon-dependent EFFECTIVE ability ID on the
    -- hotbar instead of the progression's canonical morph ID. Destruction Staff
    -- Wall is the common example: the planned morph is Unstable Wall of Elements
    -- while an Inferno Staff exposes Unstable Wall of Fire. Compare each canonical
    -- progression ID against the effective hotbar ID for this category as well.
    local function matchesCanonical(id)
        id=tonumber(id) or 0
        if id<=0 then return false end
        if gotAbilityId==id then return true end
        if hotbarCategory~=nil and type(GetEffectiveAbilityIdForAbilityOnHotbar)=="function" then
            local effective=safeNumber(GetEffectiveAbilityIdForAbilityOnHotbar,0,id,hotbarCategory)
            if effective>0 and gotAbilityId==effective then return true end
        end
        return false
    end

    -- Treat base + either morph of the same progression as the same slottable skill.
    -- Morph correctness is verified separately by GetPlannedBuildVerification().
    local progressionId=tonumber(entry.progressionId) or 0
    if progressionId>0 and type(GetProgressionSkillMorphSlotAbilityId)=="function" then
        local slots={rawget(_G,"MORPH_SLOT_BASE") or 0,rawget(_G,"MORPH_SLOT_1") or 1,rawget(_G,"MORPH_SLOT_2") or 2}
        for _,morph in ipairs(slots) do
            local id=safeNumber(GetProgressionSkillMorphSlotAbilityId,0,progressionId,morph)
            if matchesCanonical(id) then return true end
        end
    end
    return matchesCanonical(want)
end

-- 0.29.391 - canonical physical player action-bar slots.
-- ESO's exported ACTION_BAR_* constants are zero-based in several clients,
-- while GetSlotBoundId/SelectSlotAbility and the pending assignment hotbar use
-- the physical 1-based skill slots. Prefer ESO's live assignable range when it
-- exists; otherwise convert the exported constants by +1.
function G:GetPhysicalPlayerHotbarSlots029391()
    local first,ult
    if type(GetAssignableAbilityBarStartAndEndSlots)=="function" then
        local ok,a,b=pcall(GetAssignableAbilityBarStartAndEndSlots)
        if ok then first=tonumber(a); ult=tonumber(b) end
    end
    if not first then first=(tonumber(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX) or 2)+1 end
    if not ult then ult=(tonumber(ACTION_BAR_ULTIMATE_SLOT_INDEX) or 7)+1 end
    return first,ult
end

function G:StagePlannedHotbarsInRespec(plan)
    if not plan then return false,0,{"missing plan"} end
    local barMgr=rawget(_G,"ACTION_BAR_ASSIGNMENT_MANAGER")
    local skillsMgr=rawget(_G,"SKILLS_DATA_MANAGER")
    if not barMgr or type(barMgr.GetHotbar)~="function" or not skillsMgr or type(skillsMgr.GetSkillDataByIndices)~="function" then
        return false,0,{"ESO action-bar assignment manager unavailable"}
    end

    -- 0.29.391: stage into ESO's physical 1-based skill slots. 0.29.389
    -- accidentally fed the exported zero-based ACTION_BAR constants directly
    -- into the pending hotbar and caused four legal recommendations to be
    -- rejected. Use the same canonical physical range everywhere.
    local first,ultSlot=self:GetPhysicalPlayerHotbarSlots029391()
    local PRIMARY=rawget(_G,"HOTBAR_CATEGORY_PRIMARY") or 0
    local BACKUP=rawget(_G,"HOTBAR_CATEGORY_BACKUP") or 1
    local changed=0
    local failures={}

    local function getSkillData(entry)
        if not entry then return nil end
        local ok,data=pcall(skillsMgr.GetSkillDataByIndices,skillsMgr,entry.skillType,entry.skillLine,entry.skillIndex)
        if ok then return data end
        return nil
    end

    local function stageCategory(category,label,wanted,ultimate)
        local okBar,hotbar=pcall(barMgr.GetHotbar,barMgr,category)
        if not okBar or not hotbar then
            failures[#failures+1]=label.." bar unavailable"
            return
        end

        -- Rebuild all six skill slots on this specific hotbar inside ESO's
        -- pending respec state. This is the same hotbar model the vanilla
        -- Skills screen commits with SKILLS_AND_ACTION_BAR_MANAGER:ApplyChanges().
        if type(hotbar.ClearSlot)=="function" then
            for i=1,5 do
                local slot=first+(i-1)
                pcall(hotbar.ClearSlot,hotbar,slot)
            end
            pcall(hotbar.ClearSlot,hotbar,ultSlot)
        end

        for i=1,5 do
            local entry=wanted and wanted[i]
            if entry then
                local skillData=getSkillData(entry)
                local slot=first+(i-1)
                local targetId=self:ResolvePlannedSlottableAbilityId029388(entry)
                local ok,result=false,false
                -- 0.29.390: During a pending full respec, the requested morph may not
                -- exist yet as a live ability ID even though ESO's SkillData object
                -- already represents the pending purchased/morphed skill. Prefer the
                -- native SkillData assignment path and use the ability-ID path only as
                -- a fallback. This is required for pending morphs/ultimates such as
                -- Force Pulse, Hurricane, Flawless Dawnbreaker and Power Overload.
                if skillData and type(hotbar.AssignSkillToSlot)=="function" then
                    ok,result=pcall(hotbar.AssignSkillToSlot,hotbar,slot,skillData)
                end
                if (not ok or result==false) and targetId>0 and type(hotbar.AssignSkillToSlotByAbilityId)=="function" then
                    ok,result=pcall(hotbar.AssignSkillToSlotByAbilityId,hotbar,slot,targetId)
                end
                if ok and result~=false then
                    changed=changed+1
                else
                    failures[#failures+1]=label.." "..i.."="..tostring(entry.name)
                end
            else
                failures[#failures+1]=label.." "..i.." missing from build plan"
            end
        end

        if ultimate then
            local skillData=getSkillData(ultimate)
            local targetId=self:ResolvePlannedSlottableAbilityId029388(ultimate)
            local ok,result=false,false
            if skillData and type(hotbar.AssignSkillToSlot)=="function" then
                ok,result=pcall(hotbar.AssignSkillToSlot,hotbar,ultSlot,skillData)
            end
            if (not ok or result==false) and targetId>0 and type(hotbar.AssignSkillToSlotByAbilityId)=="function" then
                ok,result=pcall(hotbar.AssignSkillToSlotByAbilityId,hotbar,ultSlot,targetId)
            end
            if ok and result~=false then
                changed=changed+1
            else
                failures[#failures+1]=label.." Ultimate="..tostring(ultimate.name)
            end
        else
            failures[#failures+1]=label.." Ultimate missing from build plan"
        end
    end

    stageCategory(PRIMARY,"Primary",plan.frontWanted,plan.frontUltWanted)

    local backUnlocked=true
    if type(GetWeaponSwapUnlockedLevel)=="function" and type(GetUnitLevel)=="function" then
        backUnlocked=safeNumber(GetUnitLevel,1,"player")>=safeNumber(GetWeaponSwapUnlockedLevel,15)
    end
    if backUnlocked then
        stageCategory(BACKUP,"Backup",plan.backWanted,plan.backUltWanted)
    else
        failures[#failures+1]="Backup weapon bar is not unlocked"
    end

    local expected=backUnlocked and 12 or 6
    local complete=(changed>=expected and #failures==0)
    return complete,changed,failures
end

function G:GetPlannedBuildVerification(plan)
    if not plan then return nil end
    local base=rawget(_G,"MORPH_SLOT_BASE") or 0
    local expectedSkills,confirmedSkills=0,0
    local expectedMorphs,confirmedMorphs=0,0
    local expectedPassiveRanks,confirmedPassiveRanks=0,0
    local missingMorphs={}
    local blockedMorphs={}
    local missingPassives={}
    local seen={}

    -- A few ESO progressions can report a stale/alternate currentMorph value
    -- after respec even though the exact requested morph is live on the bar.
    -- Bound Armaments is one observed case. Verify the exact requested morph
    -- against the physical hotbars as a second authoritative signal.
    local first,ultSlot=self:GetPhysicalPlayerHotbarSlots029391()
    local PRIMARY=rawget(_G,"HOTBAR_CATEGORY_PRIMARY") or 0
    local BACKUP=rawget(_G,"HOTBAR_CATEGORY_BACKUP") or 1
    local function exactMorphIsSlotted(e)
        if not e or type(GetSlotBoundId)~="function" then return false end
        local wanted=self:ResolvePlannedSlottableAbilityId029388(e)
        if wanted<=0 then wanted=tonumber(e.abilityId) or 0 end
        if wanted<=0 then return false end
        local function matches(category,slot)
            local got=safeNumber(GetSlotBoundId,0,slot,category)
            if got==wanted then return true end
            if type(GetEffectiveAbilityIdForAbilityOnHotbar)=="function" then
                local effective=safeNumber(GetEffectiveAbilityIdForAbilityOnHotbar,0,wanted,category)
                if effective>0 and got==effective then return true end
            end
            return false
        end
        for i=1,5 do
            local slot=first+i-1
            if matches(PRIMARY,slot) or matches(BACKUP,slot) then return true end
        end
        return matches(PRIMARY,ultSlot) or matches(BACKUP,ultSlot)
    end

    local function verifyActive(e)
        if not e then return end
        local key=string.format("%s:%s:%s",tostring(e.skillType),tostring(e.skillLine),tostring(e.skillIndex))
        if seen[key] then return end
        seen[key]=true
        expectedSkills=expectedSkills+1
        local _,_,_,passive,_,purchased,progressionIndex,rank=safe(GetSkillAbilityInfo,nil,e.skillType,e.skillLine,e.skillIndex)
        if passive~=true and purchased==true then confirmedSkills=confirmedSkills+1 end
        local wantedMorph=tonumber(e.morphSlot) or base
        if e.morphBlockedByProgression029396==true then
            local desired=tostring(e.desiredMorphName029396 or e.metaPreferredName or e.name or key)
            local baseName=tostring(e.baseName or e.name or "base skill")
            blockedMorphs[#blockedMorphs+1]=string.format("%s (level %s to its morph point / Rank IV)",desired,baseName)
        elseif wantedMorph~=base then
            expectedMorphs=expectedMorphs+1
            progressionIndex=tonumber(progressionIndex) or tonumber(e.progressionIndex)
            if progressionIndex and progressionIndex>0 then
                local _,currentMorph=safe(GetAbilityProgressionInfo,nil,progressionIndex)
                if tonumber(currentMorph)==wantedMorph or exactMorphIsSlotted(e) then
                    confirmedMorphs=confirmedMorphs+1
                else
                    missingMorphs[#missingMorphs+1]=tostring(e.name or e.baseName or key)
                end
            elseif exactMorphIsSlotted(e) then
                confirmedMorphs=confirmedMorphs+1
            else
                missingMorphs[#missingMorphs+1]=tostring(e.name or e.baseName or key)
            end
        end
    end

    for _,e in ipairs(plan.chosen or {}) do verifyActive(e) end
    for _,e in ipairs(plan.chosenUlts or {}) do verifyActive(e) end

    for e,desired in pairs(plan.desiredPassiveRanks or {}) do
        desired=math.max(0,tonumber(desired) or 0)
        if desired>0 and e and self:IsPassiveRequiredForMaxPowerCompletion029394(e,plan.context) then
            expectedPassiveRanks=expectedPassiveRanks+desired
            local _,_,_,passive,_,purchased,_,rank=safe(GetSkillAbilityInfo,nil,e.skillType,e.skillLine,e.skillIndex)
            if passive==true and purchased==true then
                local have=math.min(desired,math.max(1,tonumber(rank) or 1))
                confirmedPassiveRanks=confirmedPassiveRanks+have
                if have<desired then missingPassives[#missingPassives+1]=string.format("%s %d/%d",tostring(e.name or "Passive"),have,desired) end
            else
                missingPassives[#missingPassives+1]=string.format("%s 0/%d",tostring(e.name or "Passive"),desired)
            end
        end
    end

    local primaryCount,backupCount=0,0
    if type(GetSlotBoundId)=="function" then
        for i=1,5 do
            if safeNumber(GetSlotBoundId,0,first+i-1,PRIMARY)>0 then primaryCount=primaryCount+1 end
            if safeNumber(GetSlotBoundId,0,first+i-1,BACKUP)>0 then backupCount=backupCount+1 end
        end
        if safeNumber(GetSlotBoundId,0,ultSlot,PRIMARY)>0 then primaryCount=primaryCount+1 end
        if safeNumber(GetSlotBoundId,0,ultSlot,BACKUP)>0 then backupCount=backupCount+1 end
    end

    local backRequired=true
    if type(GetWeaponSwapUnlockedLevel)=="function" and type(GetUnitLevel)=="function" then
        backRequired=safeNumber(GetUnitLevel,1,"player")>=safeNumber(GetWeaponSwapUnlockedLevel,15)
    end
    local complete=confirmedSkills>=expectedSkills
        and confirmedMorphs>=expectedMorphs
        and confirmedPassiveRanks>=expectedPassiveRanks
        and primaryCount>=6
        and ((not backRequired) or backupCount>=6)
    return {
        complete=complete,
        expectedSkills=expectedSkills, confirmedSkills=confirmedSkills,
        expectedMorphs=expectedMorphs, confirmedMorphs=confirmedMorphs,
        expectedPassiveRanks=expectedPassiveRanks, confirmedPassiveRanks=confirmedPassiveRanks,
        primaryCount=primaryCount, backupCount=backupCount, backRequired=backRequired,
        missingMorphs=missingMorphs, blockedMorphs=blockedMorphs, missingPassives=missingPassives,
    }
end

function G:ConfirmFullSkillBuild(plan)
    local v=self:GetPlannedBuildVerification(plan)
    if not v then return false end
    local hasLevelingLock=v.blockedMorphs and #v.blockedMorphs>0
    local state=v.complete and (hasLevelingLock and "BUILD APPLIED - MORPH LEVELING NEEDED" or "BUILD CONFIRMED") or "BUILD INCOMPLETE"
    local msg=string.format(
        "%s: Skills %d/%d | Morphs %d/%d | Passive ranks %d/%d | Primary %d/6 | Backup %d/6.",
        state,v.confirmedSkills,v.expectedSkills,v.confirmedMorphs,v.expectedMorphs,
        v.confirmedPassiveRanks,v.expectedPassiveRanks,v.primaryCount,v.backupCount)
    if not v.backRequired then msg=msg:gsub(" | Backup %d/6%."," | Backup locked.") end
    if #v.missingMorphs>0 then
        msg=msg.." Missing morph: "..table.concat(v.missingMorphs,", ").."."
    end
    if v.blockedMorphs and #v.blockedMorphs>0 then
        msg=msg.." Morph locked by progression XP: "..table.concat(v.blockedMorphs,", ")..". Re-run MAX POWER after the base skill reaches its morph point."
    end
    if #v.missingPassives>0 then
        local shown={}
        for i=1,math.min(6,#v.missingPassives) do shown[#shown+1]=v.missingPassives[i] end
        msg=msg.." Missing passive ranks: "..table.concat(shown,", ")
        if #v.missingPassives>#shown then msg=msg..string.format(" (+%d more)",#v.missingPassives-#shown) end
        msg=msg.."."
    end
    self:NotifyResult(msg,v.complete)
    return v.complete
end

-- 0.29.387 - verify the exact MAX POWER bar plan, not merely six non-empty slots.
function G:VerifyExactPlannedHotbars029387(plan, quiet)
    if not plan or type(GetSlotBoundId)~="function" then return false end
    local first,ultSlot=self:GetPhysicalPlayerHotbarSlots029391()
    local PRIMARY=rawget(_G,"HOTBAR_CATEGORY_PRIMARY") or 0
    local BACKUP=rawget(_G,"HOTBAR_CATEGORY_BACKUP") or 1
    local matched,expected=0,0
    local mismatches={}

    local function expectedAbilityId(entry)
        if not entry then return 0 end
        local id=tonumber(entry.abilityId) or 0
        if id>0 then return id end
        if type(GetSkillAbilityId)=="function" then
            return safeNumber(GetSkillAbilityId,0,entry.skillType,entry.skillLine,entry.skillIndex,false)
        end
        return 0
    end

    local function verifySlot(category,slot,entry,label)
        if not entry then return end
        local want=expectedAbilityId(entry)
        if want<=0 then return end
        expected=expected+1
        local got=safeNumber(GetSlotBoundId,0,slot,category)
        if self:DoesHotbarAbilityMatchPlan029388(got,entry,category) then
            matched=matched+1
        else
            local gotName=(got>0 and type(GetAbilityName)=="function") and tostring(safe(GetAbilityName,"",got) or "") or "empty"
            mismatches[#mismatches+1]=string.format("%s=%s (got %s)",label,tostring(entry.name or want),gotName~="" and gotName or tostring(got))
        end
    end

    for i=1,5 do
        verifySlot(PRIMARY,first+i-1,plan.frontWanted and plan.frontWanted[i],"Primary "..i)
    end
    verifySlot(PRIMARY,ultSlot,plan.frontUltWanted,"Primary U")

    local backRequired=true
    if type(GetWeaponSwapUnlockedLevel)=="function" and type(GetUnitLevel)=="function" then
        backRequired=safeNumber(GetUnitLevel,1,"player")>=safeNumber(GetWeaponSwapUnlockedLevel,15)
    end
    if backRequired then
        for i=1,5 do
            verifySlot(BACKUP,first+i-1,plan.backWanted and plan.backWanted[i],"Backup "..i)
        end
        verifySlot(BACKUP,ultSlot,plan.backUltWanted,"Backup U")
    end

    local complete=expected>0 and matched>=expected
    if not quiet then
        local msg=string.format("MAX POWER BAR VERIFY: %d/%d recommended slots match.",matched,expected)
        if #mismatches>0 then msg=msg.." Missing/wrong: "..table.concat(mismatches,", ") end
        self:NotifyResult(msg,complete)
    end
    return complete,matched,expected,mismatches
end

function G:VerifyPlannedHotbars(plan, quiet)
    if not plan or type(GetSlotBoundId)~="function" then return false end
    local first,ultSlot=self:GetPhysicalPlayerHotbarSlots029391()
    local PRIMARY=rawget(_G,"HOTBAR_CATEGORY_PRIMARY") or 0
    local BACKUP=rawget(_G,"HOTBAR_CATEGORY_BACKUP") or 1
    local primaryCount,backupCount=0,0
    for i=1,5 do
        if safeNumber(GetSlotBoundId,0,first+i-1,PRIMARY)>0 then primaryCount=primaryCount+1 end
        if safeNumber(GetSlotBoundId,0,first+i-1,BACKUP)>0 then backupCount=backupCount+1 end
    end
    if safeNumber(GetSlotBoundId,0,ultSlot,PRIMARY)>0 then primaryCount=primaryCount+1 end
    if safeNumber(GetSlotBoundId,0,ultSlot,BACKUP)>0 then backupCount=backupCount+1 end
    if not quiet then
        self:NotifyResult(string.format("BEST BUILD BAR VERIFY: Primary %d/6, Backup %d/6.",primaryCount,backupCount), backupCount>0 and primaryCount>0)
    end
    return primaryCount>0 and backupCount>0
end

function G:ApplyPlannedHotbars(plan, quiet)
    if not plan or safe(IsUnitInCombat,false,"player")==true or type(CallSecureProtected)~="function" then return false,0 end
    local first,ultSlot=self:GetPhysicalPlayerHotbarSlots029391()
    local PRIMARY=rawget(_G,"HOTBAR_CATEGORY_PRIMARY") or 0
    local BACKUP=rawget(_G,"HOTBAR_CATEGORY_BACKUP") or 1
    local context=plan.context or self:GetWornBuildContext()
    local changed=0
    local labels={}

    local function applyCategory(category,label)
        local chosen,ultimate=self:BuildCompatiblePurchasedBar(category,context)
        for i=1,5 do
            local slot=first+(i-1)
            local a=chosen[i]
            if a and self:IsAbilityLegalForBar(a.abilityId,a.abilityIndex,slot,category) then
                local ok,result=pcall(CallSecureProtected,"SelectSlotAbility",a.abilityIndex,slot,category)
                if ok and result~=false then changed=changed+1; labels[#labels+1]=label.." "..i.."="..tostring(a.name) end
            end
        end
        if ultimate and self:IsAbilityLegalForBar(ultimate.abilityId,ultimate.abilityIndex,ultSlot,category) then
            local ok,result=pcall(CallSecureProtected,"SelectSlotAbility",ultimate.abilityIndex,ultSlot,category)
            if ok and result~=false then changed=changed+1; labels[#labels+1]=label.." U="..tostring(ultimate.name) end
        end
    end

    applyCategory(PRIMARY,"Primary")
    -- Back bar may be unavailable at low level; don't force it.
    local backUnlocked=true
    if type(GetWeaponSwapUnlockedLevel)=="function" and type(GetUnitLevel)=="function" then
        backUnlocked=safeNumber(GetUnitLevel,1,"player")>=safeNumber(GetWeaponSwapUnlockedLevel,15)
    end
    if backUnlocked then applyCategory(BACKUP,"Backup") end

    if not quiet then
        if changed>0 then
            self:NotifyResult(string.format("BEST BUILD BAR: applied %d validated slot%s. %s",changed,changed==1 and "" or "s",table.concat(labels," | ")),true)
        else
            self:NotifyResult("BEST BUILD BAR: no legal purchased abilities were accepted for the current weapon bars.",false)
        end
    end
    if EPC and EPC.AbilityOverlays and EPC.AbilityOverlays.Refresh then EPC.AbilityOverlays:Refresh() end
    return changed>0,changed
end

-- 0.29.387 - immediate best-effort hotbar application for recommended skills
-- that are already purchased.  This is primarily a fallback when ESO refuses to
-- enter full respec mode; it also gives the user useful feedback instead of a no-op.
function G:ApplyPurchasedPlannedHotbars029387(plan, quiet)
    if not plan or safe(IsUnitInCombat,false,"player")==true or type(CallSecureProtected)~="function" then return false,0,{} end
    local first,ultSlot=self:GetPhysicalPlayerHotbarSlots029391()
    local PRIMARY=rawget(_G,"HOTBAR_CATEGORY_PRIMARY") or 0
    local BACKUP=rawget(_G,"HOTBAR_CATEGORY_BACKUP") or 1
    local changed=0
    local skipped={}

    local function isPurchased(entry)
        if not entry then return false end
        local _,_,_,passive,_,purchased=safe(GetSkillAbilityInfo,nil,entry.skillType,entry.skillLine,entry.skillIndex)
        return passive~=true and purchased==true
    end

    local function applyOne(category,slot,entry,label)
        if not entry then skipped[#skipped+1]=label.." missing"; return end
        if not isPurchased(entry) then skipped[#skipped+1]=label.." not purchased"; return end
        local idx=self:ResolvePlannedAbilityIndex(entry)
        if not idx or idx<=0 then skipped[#skipped+1]=label.." unresolved"; return end
        local ok,result=pcall(CallSecureProtected,"SelectSlotAbility",idx,slot,category)
        if ok and result~=false then changed=changed+1 else skipped[#skipped+1]=label.." rejected" end
    end

    for i=1,5 do applyOne(PRIMARY,first+i-1,plan.frontWanted and plan.frontWanted[i],"Primary "..i) end
    applyOne(PRIMARY,ultSlot,plan.frontUltWanted,"Primary U")

    local backUnlocked=true
    if type(GetWeaponSwapUnlockedLevel)=="function" and type(GetUnitLevel)=="function" then
        backUnlocked=safeNumber(GetUnitLevel,1,"player")>=safeNumber(GetWeaponSwapUnlockedLevel,15)
    end
    if backUnlocked then
        for i=1,5 do applyOne(BACKUP,first+i-1,plan.backWanted and plan.backWanted[i],"Backup "..i) end
        applyOne(BACKUP,ultSlot,plan.backUltWanted,"Backup U")
    end

    if not quiet then
        local ok=changed>0
        local msg=string.format("MAX POWER BAR FALLBACK: applied %d already-purchased recommended slot%s.",changed,changed==1 and "" or "s")
        if #skipped>0 then msg=msg.." Pending respec/unavailable: "..table.concat(skipped,", ") end
        self:NotifyResult(msg,ok)
    end
    if EPC and EPC.AbilityOverlays and EPC.AbilityOverlays.Refresh then EPC.AbilityOverlays:Refresh() end
    if EPC and EPC.DualActionBar and EPC.DualActionBar.RefreshDynamic029311 then EPC.DualActionBar:RefreshDynamic029311(true) end
    return changed>0,changed,skipped
end

function G:ApplyFullSkillPlan(plan)
    plan=plan or self:BuildFullSkillPlan()
    if safe(IsUnitInCombat,false,"player")==true then
        self:NotifyResult("RESPEC BUILD: leave combat first.",false)
        return false
    end

    local FULL=rawget(_G,"SKILL_POINT_ALLOCATION_MODE_FULL")
    local mgr=rawget(_G,"SKILLS_AND_ACTION_BAR_MANAGER")
    local allocMgr=rawget(_G,"SKILL_POINT_ALLOCATION_MANAGER")
    local skillsMgr=rawget(_G,"SKILLS_DATA_MANAGER")
    if FULL==nil or not mgr or not allocMgr or not skillsMgr then
        self:NotifyResult("RESPEC BUILD: ESO's current Skills respec managers are unavailable.",false)
        return false
    end

    -- current ESO clients: NEVER directly prepare a RESPEC_PAYMENT_TYPE_GOLD request here.
    -- Vanilla ESO first enters a shrine-free respec session with StartSkillRespecFromUI(),
    -- then edits SKILL_POINT_ALLOCATION_MANAGER state and commits through
    -- SKILLS_AND_ACTION_BAR_MANAGER:ApplyChanges(). Calling Prepare... with GOLD
    -- before that session is active produces RESPEC_RESULT_NOT_AT_SKILL_RESPEC_SHRINE.
    local function allocationReady()
        return type(mgr.DoesSkillPointAllocationModeBatchSave)=="function"
            and mgr:DoesSkillPointAllocationModeBatchSave()==true
    end

    local function applyIntoCurrentRespecSession()
        -- Force full allocation mode if ESO started another legal batch mode.
        if type(mgr.SetSkillPointAllocationMode)=="function" then
            mgr:SetSkillPointAllocationMode(FULL)
        end
        if not allocationReady() then return false end

        if type(allocMgr.ClearPointsOnAllSkillLines)~="function" then
            self:NotifyResult("RESPEC BUILD: ESO's clear-all skill allocator is unavailable.",false)
            return false
        end
        allocMgr:ClearPointsOnAllSkillLines()

        local base=rawget(_G,"MORPH_SLOT_BASE") or 0
        local purchasedActives,morphedActives,passiveRanks=0,0,0
        local morphedCounted={}
        local failures={}
        local function countMorphOnce(e)
            if not e then return end
            local key=tostring(e.skillType)..":"..tostring(e.skillLine)..":"..tostring(e.skillIndex)
            if not morphedCounted[key] then
                morphedCounted[key]=true
                morphedActives=morphedActives+1
            end
        end

        local function getAllocator(e)
            if type(skillsMgr.GetSkillDataByIndices)~="function" then return nil end
            local ok,data=pcall(skillsMgr.GetSkillDataByIndices,skillsMgr,e.skillType,e.skillLine,e.skillIndex)
            if not ok or not data or type(data.GetPointAllocator)~="function" then return nil end
            local ok2,a=pcall(data.GetPointAllocator,data)
            if ok2 then return a end
            return nil
        end

        -- Purchase the exact combat actives selected by the planner. Because all
        -- points were cleared above, each selected active must be repurchased.
        for _,e in ipairs(plan.chosen or {}) do
            local a=getAllocator(e)
            if a then
                local bought=false
                if type(a.CanPurchase)=="function" and type(a.Purchase)=="function" then
                    local okCan,can=pcall(a.CanPurchase,a)
                    if okCan and can==true then
                        local okBuy=pcall(a.Purchase,a)
                        bought=okBuy==true
                        if bought then purchasedActives=purchasedActives+1 end
                    end
                end
                local wantedMorph=tonumber(e.morphSlot) or base
                -- MAX POWER wants the exact recommended morph. A freshly morphed
                -- ability being rank I is valid; rank IV is not required. ESO only
                -- needs the base progression to be morph-eligible. Purchase first,
                -- then morph immediately in the same pending respec transaction.
                if wantedMorph~=base and type(a.CanMorph)=="function" and type(a.Morph)=="function" then
                    local okCan,can=pcall(a.CanMorph,a)
                    if okCan and can==true then
                        local okMorph,result=pcall(a.Morph,a,wantedMorph)
                        if okMorph and result~=false then countMorphOnce(e) end
                    end
                end
                if not bought and type(a.IsPurchased)=="function" then
                    local okPurchased,isPurchased=pcall(a.IsPurchased,a)
                    if not okPurchased or not isPurchased then failures[#failures+1]=tostring(e.name) end
                end
            else
                failures[#failures+1]=tostring(e.name)
            end
        end
        for _,e in ipairs(plan.chosenUlts or {}) do
            local a=getAllocator(e)
            if a then
                local bought=false
                if type(a.CanPurchase)=="function" and type(a.Purchase)=="function" then
                    local okCan,can=pcall(a.CanPurchase,a)
                    if okCan and can==true then
                        local okBuy=pcall(a.Purchase,a)
                        bought=okBuy==true
                        if bought then purchasedActives=purchasedActives+1 end
                    end
                end
                local wantedMorph=tonumber(e.morphSlot) or base
                -- MAX POWER wants the exact recommended morph. A freshly morphed
                -- ability being rank I is valid; rank IV is not required. ESO only
                -- needs the base progression to be morph-eligible. Purchase first,
                -- then morph immediately in the same pending respec transaction.
                if wantedMorph~=base and type(a.CanMorph)=="function" and type(a.Morph)=="function" then
                    local okCan,can=pcall(a.CanMorph,a)
                    if okCan and can==true then
                        local okMorph,result=pcall(a.Morph,a,wantedMorph)
                        if okMorph and result~=false then countMorphOnce(e) end
                    end
                end
            else
                failures[#failures+1]=tostring(e.name)
            end
        end

        -- 0.29.394: retry every requested morph after all active skills have
        -- been purchased. ESO's pending full-respec allocator can report
        -- CanMorph=false immediately after Purchase for an individual skill even
        -- though the morph becomes legal once the complete pending allocation has
        -- settled. A rank-I morph is valid; do not require rank IV.
        local morphRetried={}
        local function retryExactMorph(e)
            if not e then return end
            local key=tostring(e.skillType)..":"..tostring(e.skillLine)..":"..tostring(e.skillIndex)
            if morphRetried[key] then return end
            morphRetried[key]=true
            local wantedMorph=tonumber(e.morphSlot) or base
            if wantedMorph==base then return end
            local a=getAllocator(e)
            if not a or type(a.Morph)~="function" then return end
            -- Prefer ESO's readiness signal, but make one guarded direct attempt
            -- even when CanMorph is temporarily stale inside the pending batch.
            local shouldTry=true
            if type(a.CanMorph)=="function" then
                local okCan,can=pcall(a.CanMorph,a)
                shouldTry=(not okCan) or can==true
                if not shouldTry then
                    local okMorph,result=pcall(a.Morph,a,wantedMorph)
                    if okMorph and result~=false then countMorphOnce(e) end
                    return
                end
            end
            local okMorph,result=pcall(a.Morph,a,wantedMorph)
            if okMorph and result~=false then countMorphOnce(e) end
        end
        for _,e in ipairs(plan.chosen or {}) do retryExactMorph(e) end
        for _,e in ipairs(plan.chosenUlts or {}) do retryExactMorph(e) end

        -- Rebuild the recommended passive ranks from zero.
        for _,e in ipairs(plan.allPassives or {}) do
            local desired=tonumber(plan.desiredPassiveRanks and plan.desiredPassiveRanks[e]) or 0
            if desired>0 then
                local a=getAllocator(e)
                if a then
                    local rank=0
                    if type(a.CanPurchase)=="function" and type(a.Purchase)=="function" then
                        local okCan,can=pcall(a.CanPurchase,a)
                        if okCan and can==true and pcall(a.Purchase,a) then
                            rank=1
                            passiveRanks=passiveRanks+1
                        end
                    end
                    while rank<desired and type(a.CanIncreaseRank)=="function" and type(a.IncreaseRank)=="function" do
                        local okCan,can=pcall(a.CanIncreaseRank,a)
                        if not okCan or can~=true then break end
                        if not pcall(a.IncreaseRank,a) then break end
                        rank=rank+1
                        passiveRanks=passiveRanks+1
                    end
                end
            end
        end

        -- Stage BOTH Primary and Backup bars before ApplyChanges(). ESO's current
        -- respec manager submits pending hotbar assignments together with the
        -- purchased skills/morphs/passives, which makes the backup bar persist.
        local barsOk,barsChanged,barFailures=self:StagePlannedHotbarsInRespec(plan)
        if not barsOk then
            self:NotifyResult("RESPEC BUILD STOPPED: both unlocked weapon bars must be complete before confirmation. Staged "..tostring(barsChanged or 0).."/12 slots. "..table.concat(barFailures or {},", "),false)
            return false
        end

        if type(mgr.HasAnyPendingChanges)=="function" then
            local okPending,pending=pcall(mgr.HasAnyPendingChanges,mgr)
            if okPending and pending~=true then
                -- 0.29.397: An otherwise-complete MAX POWER plan can legitimately
                -- produce zero pending changes when its only remaining target is a
                -- morph that is progression-XP locked.  Do not report this as a
                -- failed respec; the live character already matches every legal
                -- part of the plan.  Verification will surface the exact future
                -- morph target and the base skill that needs leveling.
                local verify=self:GetPlannedBuildVerification(plan)
                if verify and verify.complete==true and verify.blockedMorphs and #verify.blockedMorphs>0 then
                    self._lastAppliedFullSkillPlan=plan
                    self:NotifyResult("MAX POWER: all currently legal build changes are already applied. The remaining morph is progression-XP locked; no empty respec was submitted.",true)
                    self:ConfirmFullSkillBuild(plan)
                    return true
                end
                self:NotifyResult("RESPEC BUILD: ESO entered respec mode, but no valid skill changes were produced.",false)
                return false
            end
        end

        if type(mgr.ApplyChanges)~="function" then
            self:NotifyResult("RESPEC BUILD: ESO's current ApplyChanges function is unavailable.",false)
            return false
        end

        -- The build is fully staged at this point, but NOTHING is committed yet.
        -- Show one final confirmation only after skills, morphs, passives, Primary,
        -- and Backup bars are all ready. ApplyChanges() runs only from Confirm.
        local function commitFinishedBuild()
            local okApply,err=pcall(mgr.ApplyChanges,mgr)
            if not okApply then
                self:NotifyResult("RESPEC BUILD: ESO rejected the final confirmed respec: "..tostring(err),false)
                return false
            end

            self._lastAppliedFullSkillPlan=plan
            local msg=string.format("RESPEC BUILD CONFIRMED: %d actives/ultimates, %d morphs, %d passive ranks, plus both weapon bars submitted to ESO.",purchasedActives,morphedActives,passiveRanks)
            if #failures>0 then msg=msg.." Skipped: "..table.concat(failures,", ") end
            self:NotifyResult(msg,true)

            if type(zo_callLater)=="function" then
                -- ESO can finish the server-side respec shortly after the final confirm.
                -- Verify the exact recommended slot IDs after the server settles; the old
                -- check only counted non-empty slots and could report success with the
                -- player's previous abilities still equipped.
                zo_callLater(function() self:VerifyExactPlannedHotbars029387(plan,true) end,900)
                zo_callLater(function() self:VerifyExactPlannedHotbars029387(plan,true) end,1600)
                zo_callLater(function()
                    self:VerifyExactPlannedHotbars029387(plan,false)
                    self:ConfirmFullSkillBuild(plan)
                end,2400)
            else
                self:VerifyExactPlannedHotbars029387(plan,false)
                self:ConfirmFullSkillBuild(plan)
            end
            if EPC and EPC.RequestRefresh then EPC:RequestRefresh("full-skill-respec") end
            return true
        end

        local dialogName="EPC_CONFIRM_FULL_SKILL_BUILD"
        if type(ZO_Dialogs_RegisterCustomDialog)=="function" and type(ZO_Dialogs_ShowDialog)=="function" then
            if not self._fullSkillConfirmDialogRegistered then
                ZO_Dialogs_RegisterCustomDialog(dialogName,
                {
                    title={ text="CONFIRM RESPEC BUILD" },
                    mainText={ text="The full build is ready. Confirm to permanently apply the recommended skills, morphs, passives, Primary bar, and Backup bar." },
                    buttons=
                    {
                        {
                            text=SI_DIALOG_CONFIRM,
                            callback=function(dialog)
                                local data=dialog and dialog.data
                                if data and type(data.commit)=="function" then data.commit() end
                            end,
                        },
                        {
                            text=SI_DIALOG_CANCEL,
                            callback=function()
                                self:NotifyResult("RESPEC BUILD: final confirmation cancelled. ESO's staged respec was not committed.",false)
                            end,
                        },
                    },
                })
                self._fullSkillConfirmDialogRegistered=true
            end

            self:NotifyResult("RESPEC BUILD READY: review complete. Confirm the final dialog to apply the respec.",true)
            ZO_Dialogs_ShowDialog(dialogName,{ commit=commitFinishedBuild })
            return true
        end

        -- Fallback for clients where the custom-dialog helpers are unavailable:
        -- keep the staged respec intact and make the required final action explicit.
        self:NotifyResult("RESPEC BUILD READY: everything is staged, but the confirmation dialog API is unavailable. Open Skills and press Confirm/Apply to commit the respec.",false)
        return false
    end

    if allocationReady() then
        return applyIntoCurrentRespecSession()
    end

    if type(StartSkillRespecFromUI)~="function" then
        self:NotifyResult("RESPEC BUILD: this ESO client does not expose StartSkillRespecFromUI().",false)
        return false
    end

    self._pendingFullSkillPlan=plan
    self:NotifyResult("RESPEC BUILD: starting ESO's free skill respec mode...",true)
    local started=easProtectedOrDirect("StartSkillRespecFromUI")
    if not started then
        -- We are still on the original MAX POWER button click stack in 0.29.387,
        -- so make one trusted best-effort pass for recommendations that are already
        -- purchased.  Skills/morphs/passives that require a respec remain untouched.
        local fallbackOk,fallbackChanged=self:ApplyPurchasedPlannedHotbars029387(plan,true)
        if fallbackOk then
            self:NotifyResult("RESPEC BUILD: ESO refused full respec mode, but "..tostring(fallbackChanged or 0).." already-purchased recommended bar slots were applied. Full morph/passive changes still require ESO respec mode.",false)
        else
            self:NotifyResult("RESPEC BUILD: ESO would not start respec mode. Leave combat/leaderboard/Vengeance content and try again.",false)
        end
        return fallbackOk==true
    end

    -- StartSkillRespecFromUI has a short server/cast transition. Poll only until
    -- vanilla ESO reports batch-save respec mode, then perform the planned edits.
    local tries=0
    local function waitForRespec()
        tries=tries+1
        if allocationReady() then
            self._pendingFullSkillPlan=nil
            applyIntoCurrentRespecSession()
            return
        end
        if tries>=40 then
            self:NotifyResult("RESPEC BUILD: ESO did not enter free respec mode. Try again after the respec cooldown ends.",false)
            return
        end
        if type(zo_callLater)=="function" then zo_callLater(waitForRespec,200) end
    end
    if type(zo_callLater)=="function" then
        zo_callLater(waitForRespec,200)
        return true
    end
    self:NotifyResult("RESPEC BUILD: ESO needs zo_callLater for the respec transition on this client.",false)
    return false
end

local function EAS_BaseRespecAndApplyBestBuild(self)
    if safe(IsUnitInCombat,false,"player")==true then
        self:NotifyResult("RESPEC BUILD: leave combat first.",false)
        return false
    end
    if EPC and EPC.RefreshNow then EPC:RefreshNow("pre-skill-respec-build") end
    local now=type(GetFrameTimeMilliseconds)=="function" and safeNumber(GetFrameTimeMilliseconds,0) or 0
    local plan=(self._pendingFullSkillPlan and self._respecConfirmUntil and now<=self._respecConfirmUntil) and self._pendingFullSkillPlan or self:BuildFullSkillPlan()

    -- 0.29.397: preflight before opening ESO's respec scene. If the current
    -- character already satisfies every legal part of the plan and the only
    -- outstanding recommendation is a morph that still needs progression XP,
    -- there is nothing ESO can change in a respec transaction yet. Report the
    -- leveling target immediately instead of entering an empty respec session.
    local preflight=self:GetPlannedBuildVerification(plan)
    if preflight and preflight.complete==true and preflight.blockedMorphs and #preflight.blockedMorphs>0 then
        self._lastAppliedFullSkillPlan=plan
        self:NotifyResult("MAX POWER: current build already matches every available recommendation. Morph leveling is still required before the final morph can be purchased.",true)
        self:ConfirmFullSkillBuild(plan)
        return true
    end

    -- Start-to-finish workflow: when launched from the Codex/world, move into
    -- ESO's native Skills scene first, then begin the protected respec flow.
    if EPC and EPC.Journal and EPC.Journal.window and not EPC.Journal.window:IsHidden() and type(EPC.Journal.Hide)=="function" then
        EPC.Journal:Hide()
    end
    if SCENE_MANAGER and type(SCENE_MANAGER.Show)=="function" then
        pcall(function() SCENE_MANAGER:Show("skills") end)
    end
    if plan.skillMeta and EPC.SkillMeta then
        local fs=plan.frontMetaStats or {}
        local bs=plan.backMetaStats or {}
        self:NotifyResult(string.format("RESPEC BUILD META: %s | %s | Primary %d/5 meta | Backup %d/5 meta. Unlocked/weapon fallbacks fill the rest.",tostring(plan.skillMeta.label or "Current profile"),tostring(plan.skillMetaPreset or "TRIAL"),tonumber(fs.matched) or 0,tonumber(bs.matched) or 0),true)
    end
    self:NotifyResult("RESPEC BUILD: opening Skills and preparing the best detected build...",true)

    -- 0.29.387: Start the protected ESO respec from the original MAX POWER
    -- button click.  Deferring ApplyFullSkillPlan() with zo_callLater() loses the
    -- trusted hardware-event stack on live clients, so StartSkillRespecFromUI()
    -- can be rejected and the recommended skills/bars never get applied.
    -- ApplyFullSkillPlan() already performs its own asynchronous polling AFTER
    -- the protected respec has successfully started, which is the safe place to
    -- defer work.
    return self:ApplyFullSkillPlan(plan)
end

function G:ScorePotion(bag,slot,profile)
    local itemType = type(GetItemType) == "function" and safeNumber(GetItemType,0,bag,slot) or 0
    if itemType ~= (ITEMTYPE_POTION or -9999) then return nil end
    local link = safe(GetItemLink,"",bag,slot,LINK_STYLE_DEFAULT or 0)
    if link == "" then return nil end
    local name = itemName(link)
    local _,_,stack,meets,locked,_,_,fq,dq = safe(GetItemInfo,nil,bag,slot)
    if meets == false or locked == true then return nil end
    local quality = tonumber(fq) or tonumber(dq) or 0
    local score = effectiveItemLevel(bag,slot)*25 + quality*80 + math.min(200,tonumber(stack) or 1)
    local n=lower(name)
    if profile.magicka then
        if containsAny(n,{"spell power","sorcery","prophecy","magicka","essence of spell"}) then score=score+900 end
        if containsAny(n,{"tri-stat","tri stat","health magicka stamina"}) then score=score+600 end
    else
        if containsAny(n,{"weapon power","brutality","savagery","stamina","essence of weapon"}) then score=score+900 end
        if containsAny(n,{"tri-stat","tri stat","health magicka stamina"}) then score=score+600 end
    end
    if containsAny(n,{"health","essence of health"}) then score=score+180 end
    return score,name,link
end

function G:EquipBestPotions()
    if safe(IsUnitInCombat,false,"player") == true then
        self:NotifyResult("BEST POTIONS: leave combat before changing quickslots.", false)
        return false
    end
    if type(CallSecureProtected) ~= "function" or not BAG_BACKPACK then
        self:NotifyResult("BEST POTIONS: ESO's quickslot API is unavailable.", false)
        return false
    end
    local profile=self:GetProfile()
    local candidates={}
    local count=safeNumber(GetBagSize,0,BAG_BACKPACK)
    for slot=0,count-1 do
        local score,name,link=self:ScorePotion(BAG_BACKPACK,slot,profile)
        if score then candidates[#candidates+1]={bag=BAG_BACKPACK,slot=slot,score=score,name=name,link=link} end
    end
    table.sort(candidates,function(a,b) if a.score==b.score then return lower(a.name)<lower(b.name) end return a.score>b.score end)
    if #candidates==0 then
        self:NotifyResult("BEST POTIONS: no usable potions found in the backpack.", false)
        return false
    end
    local utilitySize=tonumber(ACTION_BAR_UTILITY_BAR_SIZE) or 8
    local firstBase=tonumber(ACTION_BAR_FIRST_UTILITY_BAR_SLOT)
    local slotsToFill=math.min(4,utilitySize,#candidates)
    local succeeded=0
    local labels={}
    for i=1,slotsToFill do
        local actionSlot = firstBase and (firstBase+i) or i
        local c=candidates[i]
        local ok,result
        if HOTBAR_CATEGORY_QUICKSLOT_WHEEL ~= nil then
            ok,result=pcall(CallSecureProtected,"SelectSlotItem",c.bag,c.slot,actionSlot,HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        end
        if not ok or result==false then ok,result=pcall(CallSecureProtected,"SelectSlotItem",c.bag,c.slot,actionSlot) end
        if ok and result~=false then succeeded=succeeded+1; labels[#labels+1]=tostring(i).."="..c.name end
    end
    if succeeded==0 then
        self:NotifyResult("BEST POTIONS: ESO did not accept the quickslot changes. Try while out of combat with the quickslot wheel closed.", false)
        return false
    end
    if type(SetCurrentQuickslot)=="function" then pcall(SetCurrentQuickslot,1) end
    self:NotifyResult("BEST POTIONS: "..table.concat(labels," | "), true)
    return true
end

function G:Initialize() end

-- v0.29.174 - MAX POWER build context and dynamic skill/passive scoring.
-- The existing curated SkillMeta remains the high-confidence starting point. This
-- layer adapts it to the current activity and scores unlocked fallbacks/morphs by
-- their live descriptions so RESPEC + BUILD is not limited to fixed name lists.
G.MAX_POWER_MODES_029174 = {
    AUTO=true, TRIAL_BOSS=true, DUNGEON=true, INFINITE_ARCHIVE=true,
    SOLO=true, AOE_TRASH=true, PVP=true,
}
G.MAX_POWER_MODE_LABELS_029174 = {
    AUTO="AUTO / CURRENT CONTENT", TRIAL_BOSS="TRIAL / BOSS",
    DUNGEON="DUNGEON / ARENA", INFINITE_ARCHIVE="INFINITE ARCHIVE",
    SOLO="SOLO / OVERLAND", AOE_TRASH="AOE / TRASH", PVP="PVP",
}

function G:GetMaxPowerMode029174()
    local key=string.upper(tostring(EPC.saved and EPC.saved.maxPowerContent or "AUTO"))
    if not self.MAX_POWER_MODES_029174[key] then key="AUTO" end
    return key
end

function G:SetMaxPowerMode029174(key)
    key=string.upper(tostring(key or "AUTO"))
    if not self.MAX_POWER_MODES_029174[key] or not EPC.saved then return false end
    EPC.saved.maxPowerContent=key
    if EPC.RequestRefresh then EPC:RequestRefresh("max-power-content") end
    if EPC.Print then EPC:Print("MAX POWER content: "..tostring(self.MAX_POWER_MODE_LABELS_029174[key] or key)) end
    return true
end

local function easIsInfiniteArchive029174()
    local fn=rawget(_G,"IsInEndlessDungeon")
    if type(fn)=="function" and safe(fn,false)==true then return true end
    local prog=rawget(_G,"GetCurrentEndlessDungeonProgression")
    if type(prog)=="function" then
        local a,b,c=safe(prog,nil)
        if tonumber(a) and tonumber(a)>0 then return true end
        if tonumber(b) and tonumber(b)>0 then return true end
        if tonumber(c) and tonumber(c)>0 then return true end
    end
    return false
end

function G:ResolveMaxPowerMode029174()
    local configured=self:GetMaxPowerMode029174()
    if configured~="AUTO" then return configured end
    if easIsInfiniteArchive029174() then return "INFINITE_ARCHIVE" end
    local bg=rawget(_G,"IsActiveWorldBattleground")
    if type(bg)=="function" and safe(bg,false)==true then return "PVP" end
    local focus=EPC.Endgame and type(EPC.Endgame.GetFocus)=="function" and tostring(EPC.Endgame:GetFocus() or "") or ""
    if focus=="TRIALS" then return "TRIAL_BOSS" end
    if focus=="DUNGEONS" then return "DUNGEON" end
    if focus=="SOLO" or focus=="QUESTING" then return "SOLO" end
    local groupSize=type(GetGroupSize)=="function" and safeNumber(GetGroupSize,0) or 0
    if groupSize>=8 then return "TRIAL_BOSS" end
    if groupSize>=2 then return "DUNGEON" end
    return "SOLO"
end

local function easPlayerStat029174(globalName)
    local statId=rawget(_G,globalName)
    if statId==nil or type(GetPlayerStat)~="function" then return 0 end
    return safeNumber(GetPlayerStat,0,statId)
end

function G:GetPowerSnapshot029174()
    local mcur,mmax=safe(GetUnitPower,0,"player",POWERTYPE_MAGICKA)
    local scur,smax=safe(GetUnitPower,0,"player",POWERTYPE_STAMINA)
    local hcur,hmax=safe(GetUnitPower,0,"player",POWERTYPE_HEALTH)
    mmax=tonumber(mmax) or tonumber(mcur) or 0
    smax=tonumber(smax) or tonumber(scur) or 0
    hmax=tonumber(hmax) or tonumber(hcur) or 0
    local high=math.max(mmax,smax,1)
    local low=math.min(mmax,smax)
    local hybrid=(low/high)>=0.88
    return {
        maxHealth=hmax,maxMagicka=mmax,maxStamina=smax,
        magickaPct=(mmax>0 and (tonumber(mcur) or mmax)/mmax or 1),
        staminaPct=(smax>0 and (tonumber(scur) or smax)/smax or 1),
        spellPower=easPlayerStat029174("STAT_SPELL_POWER"),
        weaponPower=easPlayerStat029174("STAT_WEAPON_POWER"),
        spellPen=easPlayerStat029174("STAT_SPELL_PENETRATION"),
        physicalPen=easPlayerStat029174("STAT_PHYSICAL_PENETRATION"),
        spellCrit=easPlayerStat029174("STAT_SPELL_CRITICAL"),
        weaponCrit=easPlayerStat029174("STAT_CRITICAL_STRIKE"),
        spellResist=easPlayerStat029174("STAT_SPELL_RESIST"),
        physicalResist=easPlayerStat029174("STAT_PHYSICAL_RESIST"),
        magRecovery=easPlayerStat029174("STAT_MAGICKA_REGEN_COMBAT"),
        stamRecovery=easPlayerStat029174("STAT_STAMINA_REGEN_COMBAT"),
        hybrid=hybrid,
    }
end

function G:GetPersonalPenetrationTarget029174(mode,role)
    role=string.upper(tostring(role or "DAMAGE"))
    if role~="DAMAGE" and role~="DPS" then return 0 end
    if mode=="TRIAL_BOSS" then return 3500 end
    if mode=="DUNGEON" then return 7000 end
    if mode=="AOE_TRASH" then return 9000 end
    if mode=="PVP" then return 12000 end
    return 18200
end

function G:GetSkillPresetForMaxPower029174(mode)
    mode=mode or self:ResolveMaxPowerMode029174()
    if mode=="AOE_TRASH" then return "AOE_TRASH" end
    if mode=="SOLO" or mode=="INFINITE_ARCHIVE" or mode=="PVP" then return "SOLO" end
    return "TRIAL"
end

function G:GetWornBuildContext()
    local context=EAS_BaseWornBuildContext(self) or {}
    context.maxPowerMode=self:ResolveMaxPowerMode029174()
    context.maxPowerLabel=self.MAX_POWER_MODE_LABELS_029174[context.maxPowerMode] or context.maxPowerMode
    context.power=self:GetPowerSnapshot029174()
    context.skillPresetKey=self:GetSkillPresetForMaxPower029174(context.maxPowerMode)
    context.personalPenTarget=self:GetPersonalPenetrationTarget029174(context.maxPowerMode,context.role)
    local p=context.power or {}
    local currentPen=context.profile and context.profile.magicka and (p.spellPen or 0) or (p.physicalPen or 0)
    if p.hybrid then currentPen=math.max(p.spellPen or 0,p.physicalPen or 0) end
    context.personalPen=currentPen
    context.penGap=math.max(0,(context.personalPenTarget or 0)-currentPen)
    context.archetype=(context.role=="TANK" and "TANK") or (context.role=="HEALER" and "HEALER") or (p.hybrid and "HYBRID" or (context.profile and context.profile.magicka and "MAGICKA DPS" or "STAMINA DPS"))
    return context
end

function G:GetSkillMetaForContext(context)
    context=context or self:GetWornBuildContext()
    local presetKey=context.skillPresetKey or self:GetSkillPresetForMaxPower029174(context.maxPowerMode)
    if not EPC.SkillMeta or type(EPC.SkillMeta.GetProfile)~="function" then return nil,presetKey end
    local profile=context.profile or self:GetProfile()
    local meta=EPC.SkillMeta:GetProfile(profile.classId,context.role or profile.role,profile.magicka,presetKey)
    context.skillMeta=meta
    context.skillPreset=presetKey
    return meta,presetKey
end

local function easAbilityDescription029174(a)
    if not a then return "" end
    local id=tonumber(a.abilityId) or tonumber(a.actionId) or 0
    if id>0 and type(GetAbilityDescription)=="function" then
        local d=safe(GetAbilityDescription,"",id)
        if d and d~="" then return lower(d) end
    end
    local idx=tonumber(a.abilityIndex) or 0
    if idx>0 and type(GetAbilityDescriptionByIndex)=="function" then
        local d=safe(GetAbilityDescriptionByIndex,"",idx)
        if d and d~="" then return lower(d) end
    end
    return ""
end

function G:ScoreAbilityForCurrentBuild(a,context)
    context=context or self:GetWornBuildContext()
    local score=EAS_BaseScoreAbilityForCurrentBuild(self,a,context)
    local n=lower(a and a.name or "")
    local d=easAbilityDescription029174(a)
    local text=n.." "..d
    local role=string.upper(tostring(context.role or "DAMAGE"))
    local mode=context.maxPowerMode or self:ResolveMaxPowerMode029174()
    local profile=context.profile or self:GetProfile()

    -- Real tooltip semantics: morph/fallback choices gain value for what they do,
    -- not just because their name happens to match a local list.
    local deals=containsAny(text,{"deals ","damage every","damage over","magic damage","flame damage","frost damage","shock damage","physical damage","poison damage","disease damage","bleed damage"})
    local dot=containsAny(text,{"over %d","every 1 second","every 2 seconds","damage over time","for 10 seconds","for 20 seconds"})
    local aoe=containsAny(text,{"area","nearby enemies","enemies in","radius","ground","around you","cone"})
    local execute=containsAny(text,{"less than 50%","below 50%","less than 25%","below 25%","missing health","up to 400%","execute"})
    local buff=containsAny(text,{"major brutality","major sorcery","minor force","major savagery","major prophecy","increases your weapon and spell damage","increases your critical","empower","berserk"})
    local debuff=containsAny(text,{"major breach","minor breach","vulnerability","brittle","off balance","reduces their","take %d%% more damage"})
    local heal=containsAny(text,{"heals ","healing ","restore health","healing done","heal you","heal an ally"})
    local shield=containsAny(text,{"damage shield","shield that absorbs","major resolve","minor resolve","damage taken"})
    local sustain=containsAny(text,{"restore magicka","restore stamina","recovery","reduces the cost","resource"})
    local taunt=containsAny(text,{"taunt","taunting"})
    local pet=containsAny(text,{"summon","familiar","twilight","clannfear","bear","pet"})

    if role=="TANK" then
        if taunt then score=score+1200 end
        if debuff then score=score+700 end
        if shield then score=score+720 end
        if heal then score=score+480 end
        if sustain then score=score+430 end
        if mode=="INFINITE_ARCHIVE" and deals then score=score+140 end
    elseif role=="HEALER" then
        if heal then score=score+980 end
        if buff then score=score+720 end
        if sustain then score=score+520 end
        if debuff then score=score+400 end
        if shield then score=score+330 end
        if deals then score=score+(mode=="SOLO" and 220 or 40) end
    else
        if deals then score=score+520 end
        if dot then score=score+330 end
        if buff then score=score+560 end
        if debuff then score=score+470 end
        if execute then score=score+620 end
        if pet then score=score+360 end
        if sustain then score=score+100 end
        if mode=="AOE_TRASH" and aoe then score=score+520 end
        if mode=="TRIAL_BOSS" and aoe then score=score-80 end
        if mode=="TRIAL_BOSS" and not aoe and deals then score=score+180 end
        if mode=="INFINITE_ARCHIVE" then
            if shield or heal then score=score+330 end
            if sustain then score=score+220 end
        elseif mode=="SOLO" or mode=="PVP" then
            if shield or heal then score=score+260 end
        end
        -- Skills that provide penetration are only premium while the build still
        -- has a meaningful personal penetration gap for this content.
        if containsAny(text,{"penetration","major breach","minor breach"}) then
            local gap=tonumber(context.penGap) or 0
            score=score+math.min(420,math.floor(gap/25))
        end
        if profile and profile.magicka and containsAny(text,{"restore stamina only","costs stamina"}) then score=score-60 end
        if profile and not profile.magicka and containsAny(text,{"restore magicka only","costs magicka"}) then score=score-40 end
    end
    return score
end

function G:ScorePassiveForCurrentBuild(entry,context)
    context=context or self:GetWornBuildContext()
    local score=EAS_BaseScorePassiveForCurrentBuild(self,entry,context)
    local id=tonumber(entry and entry.abilityId) or 0
    local d=""
    if id>0 and type(GetAbilityDescription)=="function" then d=lower(safe(GetAbilityDescription,"",id) or "") end
    local text=lower(entry and entry.name or "").." "..d
    local role=string.upper(tostring(context.role or "DAMAGE"))
    local mode=context.maxPowerMode or self:ResolveMaxPowerMode029174()
    if role=="DAMAGE" or role=="DPS" then
        if containsAny(text,{"damage done","weapon and spell damage","critical","penetration","max magicka","max stamina"}) then score=score+420 end
        if containsAny(text,{"cost of your","recovery","restore magicka","restore stamina"}) then score=score+180 end
        if mode=="INFINITE_ARCHIVE" and containsAny(text,{"health","damage taken","healing received","shield"}) then score=score+180 end
    elseif role=="TANK" then
        if containsAny(text,{"block","health","resistance","damage taken","healing received","stamina","magicka"}) then score=score+480 end
    elseif role=="HEALER" then
        if containsAny(text,{"healing done","magicka","recovery","critical","cost"}) then score=score+460 end
    end
    return score
end

function G:AnalyzeSkillPlan029174(plan)
    plan=plan or self:BuildFullSkillPlan()
    local counts={direct=0,dot=0,aoe=0,single=0,buff=0,heal=0,total=0}
    local function scan(e)
        if not e or e.ultimate then return end
        local t=lower(e.name or "").." "..easAbilityDescription029174(e)
        counts.total=counts.total+1
        if containsAny(t,{"damage over time","every 1 second","every 2 seconds","over 10 seconds","over 20 seconds"}) then counts.dot=counts.dot+1 else counts.direct=counts.direct+1 end
        if containsAny(t,{"area","nearby enemies","radius","ground","cone","enemies in"}) then counts.aoe=counts.aoe+1 else counts.single=counts.single+1 end
        if containsAny(t,{"major brutality","major sorcery","minor force","major savagery","major prophecy","increases your","berserk","empower"}) then counts.buff=counts.buff+1 end
        if containsAny(t,{"heal","restore health","healing"}) then counts.heal=counts.heal+1 end
    end
    for _,e in ipairs(plan.frontWanted or {}) do scan(e) end
    for _,e in ipairs(plan.backWanted or {}) do scan(e) end
    local total=math.max(1,counts.total)
    counts.directShare=counts.direct/total; counts.dotShare=counts.dot/total
    counts.aoeShare=counts.aoe/total; counts.singleShare=counts.single/total
    return counts
end

function G:RespecAndApplyBestBuild()
    local context=self:GetWornBuildContext()
    local mode=context.maxPowerLabel or context.maxPowerMode or "AUTO"
    local power=context.power or {}
    self:NotifyResult(string.format("MAX POWER BUILD: %s | %s | Health %d | Magicka %d | Stamina %d | Pen %d/%d target",tostring(context.archetype or context.role or "BUILD"),tostring(mode),tonumber(power.maxHealth) or 0,tonumber(power.maxMagicka) or 0,tonumber(power.maxStamina) or 0,tonumber(context.personalPen) or 0,tonumber(context.personalPenTarget) or 0),true)
    return EAS_BaseRespecAndApplyBestBuild(self)
end
