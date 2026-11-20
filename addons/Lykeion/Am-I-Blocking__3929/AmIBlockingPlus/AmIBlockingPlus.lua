AmIBlockingPlus = {}

AmIBlockingPlus.name = "AmIBlockingPlus"
AmIBlockingPlus.author = "|c215895Qcell Lykeion|r"
AmIBlockingPlus.version = "|ccc922f3.15|r"

local lastUpdated = 0
-- local old_is_block_active = false
local dodgeStartTime = 0
local blurStartTime = 0
local shieldWallEndTime = 0
local blurring = false
local unlockUI = false
local labelTextWidth
local labelTextHeight
local WIDGETS_HORIZONTAL_GAP = 20
local WIDGETS_VERTICAL_GAP = 10
local wearingStormWearver = 0
local aibpUiLocked = true
local LCA = LibCombatAlerts
local db
local noWarn = {
    1,
    1,
    1,
    1
}
local yellowWarn = {
    1,
    0.78431,
    0.38431,
    1
}
local orangeWarn = {
    1,
    0.55686,
    0.20784,
    1
}
local redWarn = {
    1,
    0.29019,
    0.09412,
    1
}
local defaults = {
    textsize = 32,
    blur = true,
    permaBlur = false,
    blockColor = {
        0.22745,
        0.57255,
        1,
        1
    },
    reblockColor = {
        0.8,
        0.57255,
        0.18431,
        1
    },
    sound = "Stable_FeedCarry",
    interval = 300,
    left = nil, 
    top = nil,
    gadgetTextSize = 24,
    gadgetLayout = "horizontal",
    showBlockLeft = true,
    showDodgeLeft = false,
    showBashLeft = false,
    permanentGadgets = true,
    tankOnly = false,
    pos = nil
}

local function doGamepadMove(enable)
    local handler = AmIBlockingPlus.positionHandler
    if handler then
        handler:ToggleGamepadMove(enable)
    end
end

function AmIBlockingPlus:Initialize()
    if not IsUnitDead("player") and not IsUnitSwimming("player") then
        EVENT_MANAGER:RegisterForUpdate("AmIBlockingPlusTickUpdate", 1000 / 60, function() self.UpdateBlock() end)
    end
    
    db = ZO_SavedVars:NewAccountWide("AmIBlockingPlusSavedVariables", 1, nil, defaults)
    unlockUI = false
    AmIBlockingPlusControl:SetMovable(false)
    AmIBlockingPlusControl:SetMouseEnabled(false)

    AmIBlockingPlusControl:GetNamedChild("Label"):SetFont("$(BOLD_FONT)|" .. db.textsize .. "|soft-shadow-thick")
    AmIBlockingPlusControl:GetNamedChild("Label"):SetColor(unpack(db.blockColor))
    AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetFont(
        "$(BOLD_FONT)|" .. db.gadgetTextSize .. "|soft-shadow-thick")
    AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetFont(
        "$(BOLD_FONT)|" .. db.gadgetTextSize .. "|soft-shadow-thick")
    AmIBlockingPlusControl:GetNamedChild("BashNum")
        :SetFont("$(BOLD_FONT)|" .. db.gadgetTextSize .. "|soft-shadow-thick")
    AmIBlockingPlus.AddonMenu()

    _, _, _, wearingStormWearver, _, _, _ = GetItemLinkSetInfo("|H0:item:190887:364:50:0:0:0:0:0:0:0:0:0:0:0:2048:10:0:0:0:10000:0|h|h", true)

    labelTextWidth, labelTextHeight = AmIBlockingPlusControl:GetNamedChild("Label"):GetTextDimensions()
    labelTextWidth = labelTextWidth * 0.5 + 30
    labelTextHeight = labelTextHeight * 0.5 + 12
    self.RestorePosition()
    self.ReorganizeWidgets()

    -- LibCombatAlerts move handler
    if LCA then
        local handler = LCA.MoveableControl:New(AmIBlockingPlusControl)
        AmIBlockingPlus.positionHandler = handler

        if db.pos then
            handler:UpdatePosition(db.pos)
        end

        handler:SetSnap(20)

        handler:RegisterCallback(AmIBlockingPlus.name, LCA.EVENT_CONTROL_MOVE_STOP, function(newPos)
            db.pos = newPos
        end)
    end

    local currentDate = os.date("*t")
    if currentDate.month == 4 and currentDate.day == 1 then
        local bigT = {}
        local postFix = GetString(SI_KEYCODE107) .. GetString(SI_KEYCODE107) .. GetString(SI_KEYCODE107) .. GetString(SI_CRAFTING_COMPONENT_TOOLTIP_UNKNOWN_TRAIT)
        local bigA = {705, 1838, 2075, 2139, 2467, 2746, 3003, 3249, 3564, 4019, 2368}
        for i = 1, #bigA do
            local _, titl = GetAchievementRewardTitle(bigA[i])
            table.insert(bigT, titl .. postFix)
        end
        GetUnitTitle = function(unitTag)
            return bigT[math.random(1, #bigT)]
        end
    else
        local GetUnitTitle_original = GetUnitTitle
        GetUnitTitle = function(unitTag)
            if (GetUnitDisplayName(unitTag) == "@Lykeion") then
                if GetUnitName(unitTag) == "This One Adores Inigo" then
                    if GetCVar("language.2") == "zh" then
                        return "|c9d1112鲜|r|c8b1011血|r|c790e0f铸|r|c670d0e就|r"
                    else
                        return "|cab1213A|r|ca61112g|r|ca21112e|r|c9d1112d|r |c991011T|r|c941011h|r|c901011r|r|c8b1011o|r|c870f10u|r|c820f10g|r|c7e0f10h|r |c790e0fB|r|c750e0fl|r|c700e0fo|r|c6c0d0eo|r|c670d0ed|r"
                    end
                elseif GetUnitName(unitTag) == "This One Might Have Wares" then
                    if GetCVar("language.2") == "zh" then
                        return "|c365f88黎|r|c4b677c明|r|c616e6f纪|r|c767562元|r|c8c7c55的|r|ca18449风|r|cb78b3c笛|r|ccc922f手|r"
                    else
                        return "|c275a91P|r|c2e5d8di|r|c365f88p|r|c3d6284e|r|c446480r|r |c4b677ca|r|c526977t|r |c596b73t|r|c616e6fh|r|c68706be|r |c6f7366G|r|c767562a|r|c7d775et|r|c847a5ae|r|c8c7c55s|r |c937f51o|r|c9a814df|r |ca18449D|r|ca88644a|r|caf8840w|r|cb78b3cn|r |cbe8d38E|r|cc59033r|r|ccc922fa|r"
                    end
                elseif GetUnitName(unitTag) == "This One Smuggles Skooma" then
                    if GetCVar("language.2") == "zh" then
                        return "|c5b33b4与|r|c4d309a死|r|c402e81者|r|c322b67共|r|c25284d舞|r"
                    else
                        return "|c6435c7D|r|c6134c0a|r|c5d34b9n|r|c5933b1c|r|c5532aai|r|c5231a3n|r|c4e319cg|r |c4a3095w|r|c472f8ei|r|c432e86t|r|c3f2d7fh|r |c3b2d78t|r|c382c71h|r|c342b6ae|r |c302a63D|r|c2c2a5be|r|c292954a|r|c25284dd|r"
                    end
                elseif GetUnitName(unitTag) == "This One Bears With You" then
                    if GetCVar("language.2") == "zh" then
                        return "|cbed768生|r|cd4cb61吞|r|ce9be5b活|r|cffb254剥|r"
                    else
                        return "|cb1de6bE|r|cb9d969a|r|cc2d466t|r|ccbcf64e|r|cd4cb61n|r |cdcc65eA|r|ce5c15cl|r|ceebc59i|r|cf6b757v|r|cffb254e|r"
                    end
                elseif GetUnitName(unitTag) == "This One Needs Moonsugar" then
                    if GetCVar("language.2") == "zh" then
                        return  "|cf3a300吾|r|ce77600心|r|cda4a00之|r|cce1d00形|r"
                    else
                        return  "|cfcc200S|r|cf8b600h|r|cf5a900a|r|cf19c00p|r|cee8f00e|r |cea8300o|r|ce77600f|r |ce36900M|r|ce05d00y|r |cdc5000H|r|cd94300e|r|cd53600a|r|cd22a00r|r|cce1d00t|r"
                    end
                elseif GetUnitName(unitTag) == "This One Steals Nothing" then
                    if GetCVar("language.2") == "zh" then
                        return "|c7ee1ca晶|r|c5ec9b0体|r|c3db196管|r"
                    else
                        return "|c95f2dcT|r|c8bebd4r|r|c82e3cda|r|c78dcc5n|r|c6ed5bds|r|c64ceb5i|r|c5ac7ads|r|c51bfa6t|r|c47b89eo|r|c3db196r|r"
                    end
                elseif GetUnitName(unitTag) == "This One Tells No Lie" then
                    if GetCVar("language.2") == "zh" then
                        return "|cd7d4a7恶|r|caeab87业|r|c868367长|r|c5d5a47存|r"
                    else
                        return "|cf5f2bfT|r|cebe8b7h|r|ce1deafe|r |cd7d4a7E|r|cccc99fv|r|cc2bf97i|r|cb8b58fl|r |caeab87T|r|ca4a17fh|r|c9a9777a|r|c908d6ft|r |c868367M|r|c7b785fe|r|c716e57n|r |c67644fD|r|c5d5a47o|r"
                    end
                else
                    if GetCVar("language.2") == "zh" then
                        return "|c3c6646沥|r|c3c6258青|r|c3d5e69世|r|c3d5a7b界|r"
                    else
                        return "|c3b693aA|r|c3b6740s|r|c3c6646p|r|c3c654ch|r|c3c6352a|r|c3c6258l|r|c3c615dt|r |c3c5f63W|r|c3d5e69o|r|c3d5d6fr|r|c3d5b75l|r|c3d5a7bd|r"
                    end
                end
            elseif (GetUnitDisplayName(unitTag) == "@lsxun" or GetUnitDisplayName(unitTag) == "@Isxun") then
                if GetCVar("language.2") == "zh" then
                    return "|cdcc9bc喵|cc48241喵|c8b5030喵|c3a3231喵|r"
                else
                    return "|cdcc9bcMeow |cc48241Meow |c8b5030Meow |c3a3231Meow|r"
                end
            else
                return GetUnitTitle_original(unitTag)   
            end
        end
    end
end

function AmIBlockingPlus.GetOffset(total, index)
    if db.gadgetLayout == "wraparound" then
        local offsetX = (total == 1 and index == 1) and 0 or (index == 1 and -1 * labelTextWidth or (index == total and labelTextWidth or 0))
        local offsetY = ((total == 1 and index == 1) or (total == 3 and index == 2)) and labelTextHeight or 0
        return CENTER, AmIBlockingPlusControl, CENTER, offsetX, offsetY
    elseif db.gadgetLayout == "vertical" then
        local offsetX = labelTextWidth
        local offsetY = (total == 1 and index == 1) and 0 or (index == 1 and -WIDGETS_VERTICAL_GAP * total or (index == total and WIDGETS_VERTICAL_GAP * total or 0))
        return CENTER, AmIBlockingPlusControl, CENTER, offsetX, offsetY
    elseif db.gadgetLayout == "horizontal" then
        local offsetX = (total == 1 and index == 1) and 0 or (index == 1 and -WIDGETS_HORIZONTAL_GAP * total or (index == total and WIDGETS_HORIZONTAL_GAP * total or 0))
        local offsetY = labelTextHeight
        return CENTER, AmIBlockingPlusControl, CENTER, offsetX, offsetY
    end
end

function AmIBlockingPlus.ReorganizeWidgets()
    local activeWidgetPivots = {}
    local deactiveWidgets = {}
    if db.showDodgeLeft then
        table.insert(activeWidgetPivots, {AmIBlockingPlusControl:GetNamedChild("DodgePivot"), AmIBlockingPlusControl:GetNamedChild("DodgeIcon"), AmIBlockingPlusControl:GetNamedChild("DodgeNum")})
    else
        table.insert(deactiveWidgets, {AmIBlockingPlusControl:GetNamedChild("DodgeIcon"), AmIBlockingPlusControl:GetNamedChild("DodgeNum")})
    end
    if db.showBlockLeft then
        table.insert(activeWidgetPivots, {AmIBlockingPlusControl:GetNamedChild("BlockPivot"), AmIBlockingPlusControl:GetNamedChild("BlockIcon"), AmIBlockingPlusControl:GetNamedChild("BlockNum")})
    else
        table.insert(deactiveWidgets, {AmIBlockingPlusControl:GetNamedChild("BlockIcon"), AmIBlockingPlusControl:GetNamedChild("BlockNum")})
    end
    if db.showBashLeft then
        table.insert(activeWidgetPivots, {AmIBlockingPlusControl:GetNamedChild("BashPivot"), AmIBlockingPlusControl:GetNamedChild("BashIcon"), AmIBlockingPlusControl:GetNamedChild("BashNum")})
    else
        table.insert(deactiveWidgets, {AmIBlockingPlusControl:GetNamedChild("BashIcon"), AmIBlockingPlusControl:GetNamedChild("BashNum")})
    end

    -- reorganize gadgets anchor based on active gadgets and their orders
    for index, controls in ipairs(activeWidgetPivots) do
        controls[1]:ClearAnchors()
        controls[1]:SetAnchor(AmIBlockingPlus.GetOffset(#activeWidgetPivots, index))
        controls[2]:SetHidden(false)
        controls[3]:SetHidden(false)
    end
    
    -- hide deactive gadgets
    for _, controls in ipairs(deactiveWidgets) do
        controls[1]:SetHidden(true)
        controls[2]:SetHidden(true)
    end
end

function AmIBlockingPlus.OnAddOnLoaded(event, addonName)
    if addonName == AmIBlockingPlus.name then
        EVENT_MANAGER:UnregisterForEvent(AmIBlockingPlus.name, EVENT_ADD_ON_LOADED)

        AmIBlockingPlus:Initialize()
        
        EVENT_MANAGER:RegisterForEvent(AmIBlockingPlus.name, EVENT_PLAYER_DEAD, AmIBlockingPlus.StopUpdate)
        EVENT_MANAGER:RegisterForEvent(AmIBlockingPlus.name, EVENT_PLAYER_ALIVE, AmIBlockingPlus.StartUpdate)
        EVENT_MANAGER:RegisterForEvent(AmIBlockingPlus.name, EVENT_PLAYER_SWIMMING, AmIBlockingPlus.StopUpdate)
        EVENT_MANAGER:RegisterForEvent(AmIBlockingPlus.name, EVENT_PLAYER_NOT_SWIMMING, AmIBlockingPlus.StartUpdate)
        EVENT_MANAGER:RegisterForEvent(AmIBlockingPlus.name, EVENT_COMBAT_EVENT, AmIBlockingPlus.OnDodgeStart)
        EVENT_MANAGER:AddFilterForEvent(AmIBlockingPlus.name, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        EVENT_MANAGER:AddFilterForEvent(AmIBlockingPlus.name, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED)
        EVENT_MANAGER:AddFilterForEvent(AmIBlockingPlus.name, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 28549)
        EVENT_MANAGER:RegisterForEvent(AmIBlockingPlus.name, EVENT_EFFECT_CHANGED, AmIBlockingPlus.OnEffectChanged)
        EVENT_MANAGER:AddFilterForEvent(AmIBlockingPlus.name, EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        EVENT_MANAGER:RegisterForEvent(AmIBlockingPlus.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, AmIBlockingPlus.OnGearChange)
        EVENT_MANAGER:AddFilterForEvent(AmIBlockingPlus.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    end
end

function AmIBlockingPlus.StartUpdate(event)
    EVENT_MANAGER:RegisterForUpdate("AmIBlockingPlusTickUpdate", 1000 / 60, function() AmIBlockingPlus.UpdateBlock() end)
end

function AmIBlockingPlus.StopUpdate(event)
    EVENT_MANAGER:UnregisterForUpdate("AmIBlockingPlusTickUpdate")
    AmIBlockingPlusControl:GetNamedChild("Label"):SetHidden(true)
    AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetHidden(true)
    AmIBlockingPlusControl:GetNamedChild("BlockIcon"):SetHidden(true)
    AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetHidden(true)
    AmIBlockingPlusControl:GetNamedChild("DodgeIcon"):SetHidden(true)
    AmIBlockingPlusControl:GetNamedChild("BashNum"):SetHidden(true)
    AmIBlockingPlusControl:GetNamedChild("BashIcon"):SetHidden(true)
    if blurring then
        SetFullscreenEffect(FULLSCREEN_EFFECT_NONE)
        blurring = false
    end
end

function AmIBlockingPlus.OnDodgeStart(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType,
    sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId,
    abilityId, overflow)
    dodgeStartTime = GetGameTimeMilliseconds()
end

function AmIBlockingPlus.OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount,
    iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceUnitType)
    if changeType == EFFECT_RESULT_GAINED and (abilityId == 83272 or abilityId == 83292 or abilityId == 83310) then
        shieldWallEndTime = GetGameTimeMilliseconds() + (endTime - beginTime) * 1000
    end
end

function AmIBlockingPlus.OnGearChange(_)
    _, _, _, wearingStormWearver, _, _, _ = GetItemLinkSetInfo("|H0:item:190887:364:50:0:0:0:0:0:0:0:0:0:0:0:2048:10:0:0:0:10000:0|h|h", true)
end

function AmIBlockingPlus.ThrottledWarning()
    local currentTime = GetGameTimeMilliseconds()
    if currentTime - lastUpdated > db.interval and currentTime > dodgeStartTime + 600 then
        PlaySound(db.sound)
        lastUpdated = currentTime
    end
end

function AmIBlockingPlus.UpdateBlock()
    local currentTime = GetGameTimeMilliseconds()

    -- Tank only check
    if db.tankOnly and GetSelectedLFGRole() ~= LFG_ROLE_TANK then
        AmIBlockingPlusControl:GetNamedChild("Label"):SetHidden(true)
        AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetHidden(true)
        AmIBlockingPlusControl:GetNamedChild("BlockIcon"):SetHidden(true)
        AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetHidden(true)
        AmIBlockingPlusControl:GetNamedChild("DodgeIcon"):SetHidden(true)
        AmIBlockingPlusControl:GetNamedChild("BashNum"):SetHidden(true)
        AmIBlockingPlusControl:GetNamedChild("BashIcon"):SetHidden(true)
        if blurring then
            SetFullscreenEffect(FULLSCREEN_EFFECT_NONE)
            blurring = false
        end
        return
    end

    -- dealing with gadgets
    if (db.permanentGadgets and IsUnitInCombat("player")) or IsBlockActive() or (currentTime < shieldWallEndTime) then
        local blockingResource = COMBAT_MECHANIC_FLAGS_STAMINA
        local dodgeBashResource = COMBAT_MECHANIC_FLAGS_STAMINA
        local currentWeapon
        if GetHeldWeaponPair() == ACTIVE_WEAPON_PAIR_MAIN then
            currentWeapon = GetItemWeaponType(BAG_WORN, EQUIP_SLOT_MAIN_HAND)
        else
            currentWeapon = GetItemWeaponType(BAG_WORN, EQUIP_SLOT_BACKUP_MAIN)
        end
        local triFocusUnlocked = IsSkillAbilityPurchased(2, 5, 8) 
        if currentWeapon == WEAPONTYPE_FROST_STAFF and triFocusUnlocked then
            blockingResource = COMBAT_MECHANIC_FLAGS_MAGICKA
        end
        if wearingStormWearver > 0 then
            blockingResource = COMBAT_MECHANIC_FLAGS_MAGICKA
            dodgeBashResource = COMBAT_MECHANIC_FLAGS_MAGICKA
        end

        local blockLeft = 0
        local dodgeLeft = 0
        local bashLeft = 0
        local currentBlock, _, _ = GetUnitPower("player", blockingResource)
        local currentDodgeBash, _, _ = GetUnitPower("player", dodgeBashResource)
        local _, blockCost, _ = GetAdvancedStatValue(ADVANCED_STAT_DISPLAY_TYPE_BLOCK_COST)
        blockLeft = zo_floor(currentBlock / blockCost)
        local _, dodgeCost, _ = GetAdvancedStatValue(ADVANCED_STAT_DISPLAY_TYPE_DODGE_COST)
        dodgeLeft = zo_floor(currentDodgeBash / dodgeCost)
        local _, bashCost, _ = GetAdvancedStatValue(ADVANCED_STAT_DISPLAY_TYPE_BASH_COST)
        bashLeft = zo_floor(currentDodgeBash / bashCost)

        if db.showBlockLeft then
            AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetText(blockLeft)
            if blockLeft > 5 then
                AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetColor(unpack(noWarn))
                AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetFont("$(BOLD_FONT)|" .. db.gadgetTextSize .. ")|soft-shadow-thick")
            elseif blockLeft > 3 then
                AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetColor(unpack(yellowWarn))
                AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetFont("$(BOLD_FONT)|" .. math.floor(db.gadgetTextSize * 1.1) .. ")|soft-shadow-thick")
            elseif blockLeft > 1 then
                AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetColor(unpack(orangeWarn))
                AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetFont("$(BOLD_FONT)|" .. math.floor(db.gadgetTextSize * 1.2) .. ")|soft-shadow-thick")
            else
                AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetColor(unpack(redWarn))
                AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetFont("$(BOLD_FONT)|" .. math.floor(db.gadgetTextSize * 1.4) .. ")|soft-shadow-thick")
            end
            AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetHidden(false)
            AmIBlockingPlusControl:GetNamedChild("BlockIcon"):SetHidden(false)
        else
            AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetHidden(true)
            AmIBlockingPlusControl:GetNamedChild("BlockIcon"):SetHidden(true)
        end

        if db.showDodgeLeft then
            AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetText(dodgeLeft)
            if dodgeLeft > 2 then
                AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetColor(unpack(noWarn))
                AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetFont("$(BOLD_FONT)|" .. db.gadgetTextSize .. ")|soft-shadow-thick")
            elseif dodgeLeft > 1 then
                AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetColor(unpack(yellowWarn))
                AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetFont("$(BOLD_FONT)|" .. math.floor(db.gadgetTextSize * 1.1) .. ")|soft-shadow-thick")
            elseif dodgeLeft > 0 then
                AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetColor(unpack(orangeWarn))
                AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetFont("$(BOLD_FONT)|" .. math.floor(db.gadgetTextSize * 1.2) .. ")|soft-shadow-thick")
            else
                AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetColor(unpack(redWarn))
                AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetFont("$(BOLD_FONT)|" .. math.floor(db.gadgetTextSize * 1.4) .. ")|soft-shadow-thick")
            end
            AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetHidden(false)
            AmIBlockingPlusControl:GetNamedChild("DodgeIcon"):SetHidden(false)
        else
            AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetHidden(true)
            AmIBlockingPlusControl:GetNamedChild("DodgeIcon"):SetHidden(true)
        end

        if db.showBashLeft then
            AmIBlockingPlusControl:GetNamedChild("BashNum"):SetText(bashLeft)
            if bashLeft > 8 then
                AmIBlockingPlusControl:GetNamedChild("BashNum"):SetColor(unpack(noWarn))
                AmIBlockingPlusControl:GetNamedChild("BashNum"):SetFont("$(BOLD_FONT)|" .. db.gadgetTextSize .. ")|soft-shadow-thick")
            elseif bashLeft > 4 then
                AmIBlockingPlusControl:GetNamedChild("BashNum"):SetColor(unpack(yellowWarn))
                AmIBlockingPlusControl:GetNamedChild("BashNum"):SetFont("$(BOLD_FONT)|" .. math.floor(db.gadgetTextSize * 1.1) .. ")|soft-shadow-thick")
            elseif bashLeft > 2 then
                AmIBlockingPlusControl:GetNamedChild("BashNum"):SetColor(unpack(orangeWarn))
                AmIBlockingPlusControl:GetNamedChild("BashNum"):SetFont("$(BOLD_FONT)|" .. math.floor(db.gadgetTextSize * 1.2) .. ")|soft-shadow-thick")
            else
                AmIBlockingPlusControl:GetNamedChild("BashNum"):SetColor(unpack(redWarn))
                AmIBlockingPlusControl:GetNamedChild("BashNum"):SetFont("$(BOLD_FONT)|" .. math.floor(db.gadgetTextSize * 1.4) .. ")|soft-shadow-thick")
            end
            AmIBlockingPlusControl:GetNamedChild("BashNum"):SetHidden(false)
            AmIBlockingPlusControl:GetNamedChild("BashIcon"):SetHidden(false)
        else
            AmIBlockingPlusControl:GetNamedChild("BashNum"):SetHidden(true)
            AmIBlockingPlusControl:GetNamedChild("BashIcon"):SetHidden(true)
        end
    else
        if unlockUI or not aibpUiLocked then
            if db.showBlockLeft then
                AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetHidden(false)
                AmIBlockingPlusControl:GetNamedChild("BlockIcon"):SetHidden(false)
            end
            if db.showDodgeLeft then
                AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetHidden(false)
                AmIBlockingPlusControl:GetNamedChild("DodgeIcon"):SetHidden(false)
            end
            if db.showBashLeft then
                AmIBlockingPlusControl:GetNamedChild("BashNum"):SetHidden(false)
                AmIBlockingPlusControl:GetNamedChild("BashIcon"):SetHidden(false)
            end
        else
            if db.showBlockLeft then
                AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetHidden(true)
                AmIBlockingPlusControl:GetNamedChild("BlockIcon"):SetHidden(true)
            end
            if db.showDodgeLeft then
                AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetHidden(true)
                AmIBlockingPlusControl:GetNamedChild("DodgeIcon"):SetHidden(true)
            end
            if db.showBashLeft then
                AmIBlockingPlusControl:GetNamedChild("BashNum"):SetHidden(true)
                AmIBlockingPlusControl:GetNamedChild("BashIcon"):SetHidden(true)
            end
        end
    end

    -- dealing with block panel
    if IsBlockActive() or (currentTime < shieldWallEndTime) then
        local isDodging = currentTime <= dodgeStartTime + 600
        local stamReg = 0
        local magReg = 0
        if IsUnitInCombat("player") then
            stamReg = GetPlayerStat(STAT_STAMINA_REGEN_COMBAT, STAT_BONUS_OPTION_APPLY_BONUS)
            magReg = GetPlayerStat(STAT_MAGICKA_REGEN_COMBAT, STAT_BONUS_OPTION_APPLY_BONUS)
        else
            stamReg = GetPlayerStat(STAT_STAMINA_REGEN_IDLE, STAT_BONUS_OPTION_APPLY_BONUS)
            magReg = GetPlayerStat(STAT_MAGICKA_REGEN_IDLE, STAT_BONUS_OPTION_APPLY_BONUS)
        end
        local is_block_active = false
        if (stamReg ~= 0 and magReg ~= 0 and not isDodging) then
            is_block_active = false
        else
            is_block_active = true
        end

        if is_block_active or (currentTime < shieldWallEndTime) then
            AmIBlockingPlusControl:GetNamedChild("Label"):SetText(GetString(AIBP_BLOCKING))
            AmIBlockingPlusControl:GetNamedChild("Label"):SetColor(unpack(db.blockColor))
            AmIBlockingPlusControl:GetNamedChild("Label"):SetHidden(false)
            if blurring then
                SetFullscreenEffect(FULLSCREEN_EFFECT_NONE)
                blurring = false
            end
        else
            AmIBlockingPlusControl:GetNamedChild("Label"):SetText(GetString(AIBP_REBLOCK))
            AmIBlockingPlusControl:GetNamedChild("Label"):SetColor(unpack(db.reblockColor))
            AmIBlockingPlusControl:GetNamedChild("Label"):SetHidden(false)
            if db.blur then
                SetFullscreenEffect(FULLSCREEN_EFFECT_CHARACTER_FRAMING_BLUR)
                if not blurring then
                    blurStartTime = currentTime
                    blurring = true
                end
            end
            zo_callLater(function()
                AmIBlockingPlus.ThrottledWarning()
            end, db.interval)
        end
    else
        if unlockUI or not aibpUiLocked then
            AmIBlockingPlusControl:GetNamedChild("Label"):SetHidden(false)
        else
            AmIBlockingPlusControl:GetNamedChild("Label"):SetHidden(true)
        end
        if blurring then
            SetFullscreenEffect(FULLSCREEN_EFFECT_NONE)
            blurring = false
        end
    end

    if db.blur and not db.permaBlur and blurring and currentTime - blurStartTime > 800 then
        SetFullscreenEffect(FULLSCREEN_EFFECT_NONE)
    end
end

function AmIBlockingPlus.OnMove()
    if not unlockUI and aibpUiLocked then
        return
    end

    local centerX, centerY = AmIBlockingPlusControl:GetCenter()
    local guiRootCenterX, guiRootCenterY = AmIBlockingPlusControl:GetParent():GetCenter()
    local top, left = centerY - guiRootCenterY, centerX - guiRootCenterX
    db.left = left
    db.top = top
    AmIBlockingPlusControl:ClearAnchors()
    AmIBlockingPlusControl:SetAnchor(CENTER, GuiRoot, CENTER, db.left, db.top)
end

function AmIBlockingPlus.MoveRight()
    local centerX, centerY = AmIBlockingPlusControl:GetCenter()
    local guiRootCenterX, guiRootCenterY = AmIBlockingPlusControl:GetParent():GetCenter()
    local top, left = centerY - guiRootCenterY, centerX - guiRootCenterX
    db.left = left + 50
    db.top = top
    AmIBlockingPlusControl:ClearAnchors()
    AmIBlockingPlusControl:SetAnchor(CENTER, GuiRoot, CENTER, db.left, db.top)
end

function AmIBlockingPlus.ResetPosition()
    if ZO_IsConsoleOrGameCoreUI() then
        local pos = {
            center = 0,
            mid = 0
        }
        AmIBlockingPlus.positionHandler:UpdatePosition(pos)
        db.pos = pos
        doGamepadMove(false)
    else
        db.left = 0
        db.top = 0
        AmIBlockingPlusControl:ClearAnchors()
        AmIBlockingPlusControl:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
end

function AmIBlockingPlus.RestorePosition()
    if LCA and AmIBlockingPlus.positionHandler and db.pos then
        AmIBlockingPlus.positionHandler:UpdatePosition(db.pos)
    elseif db.left or db.top then
        AmIBlockingPlusControl:ClearAnchors()
        AmIBlockingPlusControl:SetAnchor(CENTER, GuiRoot, CENTER, db.left, db.top)
    else
        AmIBlockingPlusControl:ClearAnchors()
        AmIBlockingPlusControl:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end

    -- local left = db.left
    -- local top = db.top
    -- if (left ~= nil and top ~= nil) then
    --     if AmIBlockingPlusControl:GetAnchor() ~= nil then
    --         AmIBlockingPlusControl:ClearAnchors()
    --     end
    --     AmIBlockingPlusControl:SetAnchor(CENTER, GuiRoot, CENTER, left, top)
    -- else
    --     AmIBlockingPlus.ResetPosition()
    -- end
end

local layoutChoices = {
    GetString(AIBP_WIDGET_HORIZONTAL),
    GetString(AIBP_WIDGET_VERTICAL),
    GetString(AIBP_WIDGET_WRAPAROUND)
}
local layoutChoicesValues = {
    "horizontal",
    "vertical",
    "wraparound"
}

function AmIBlockingPlus.AddonMenu()
    local menuOptions = {
        type = "panel",
        name = "Am I Blocking Plus",
        displayName = "|c305d8aA|r|c3b6184m|r |c46647dI|r |c526877B|r|c5d6c70l|r|c68706ao|r|c737463c|r|c7e775dk|r|c897b56i|r|c947f50n|r|c9f8349g|r |cab8743P|r|cb68a3cl|r|cc18e36u|r|ccc922fs|r",
        author = AmIBlockingPlus.author,
        version = AmIBlockingPlus.version,
        slashCommand = "/aibp",
        registerForRefresh = true
    }

    local dataTable = {
        {
            type = "description",
            text = GetString(AIBP_DESCRIPTION)
        },
        {
            type = "header",
            name = GetString(AIBP_BLOCK_PANEL),
            width = "full"
        },
        {
            type = "button",
            name = ZO_IsConsoleOrGameCoreUI() and GetString(AIBP_MOVE_PANEL) or GetString(AIBP_MOVE_RIGHT),
            tooltip = ZO_IsConsoleOrGameCoreUI() and GetString(AIBP_MOVE_PANEL_TOOLTIP) or GetString(AIBP_MOVE_RIGHT_TOOLTIP),
            func = function()
                if ZO_IsConsoleOrGameCoreUI() then
                    aibpUiLocked = not aibpUiLocked
                    if aibpUiLocked then
                        AmIBlockingPlusControl:SetMovable(false)
                        AmIBlockingPlusControl:SetMouseEnabled(false)
                        doGamepadMove(false)
                        AmIBlockingPlusControl:GetNamedChild("Label"):SetHidden(true)
                        d("|cCC922FAm I Blocking Plus|r: " .. GetString(AIBP_MOVE_PANEL_LOCKED))
                    else
                        AmIBlockingPlusControl:SetMovable(true)
                        AmIBlockingPlusControl:SetMouseEnabled(true)
                        doGamepadMove(true)
                        AmIBlockingPlusControl:GetNamedChild("Label"):SetText(string.upper(GetString(SI_MARKET_PRODUCT_TOOLTIP_UNLOCK)))
                        AmIBlockingPlusControl:GetNamedChild("Label"):SetHidden(false)
                        d("|cCC922FAm I Blocking Plus|r: " .. GetString(AIBP_MOVE_PANEL_UNLOCKED))
                    end
                else
                    AmIBlockingPlus.MoveRight()
                end
            end
        },
        {
            type = "button",
            name = GetString(AIBP_RESET_POSITION),
            func = function()
                AmIBlockingPlus.ResetPosition()
            end
        },
        {
            type = "slider",
            name = GetString(AIBP_PANEL_TEXT_SIZE),
            min = 24,
            max = 36,
            step = 2,
            getFunc = function()
                return db.textsize;
            end,
            setFunc = function(value)
                db.textsize = value;
                AmIBlockingPlusControl:GetNamedChild("Label"):SetFont("$(BOLD_FONT)|" .. db.textsize .. ")|soft-shadow-thick")
            end,
            default = 32
        },
        {
            type = "colorpicker",
            name = GetString(AIBP_CHANGE_BLOCK_COLOR),
            tooltip = GetString(AIBP_COLORPICKER_TOOLTIP),
            getFunc = function()
                return unpack(db.blockColor)
            end,
            setFunc = function(r, g, b, a)
                db.blockColor = {
                    r,
                    g,
                    b,
                    a
                }
                AmIBlockingPlusControl:GetNamedChild("Label"):SetText(GetString(AIBP_BLOCKING))
                AmIBlockingPlusControl:GetNamedChild("Label"):SetColor(unpack(db.blockColor))
            end,
            default = {
                r = 0.22745,
                g = 0.57255,
                b = 1,
                a = 1
            }
        },
        {
            type = "colorpicker",
            name = GetString(AIBP_CHANGE_REBLOCK_COLOR),
            tooltip = GetString(AIBP_COLORPICKER_TOOLTIP),
            getFunc = function()
                return unpack(db.reblockColor)
            end,
            setFunc = function(r, g, b, a)
                db.reblockColor = {
                    r,
                    g,
                    b,
                    a
                }
                AmIBlockingPlusControl:GetNamedChild("Label"):SetText(GetString(AIBP_REBLOCK))
                AmIBlockingPlusControl:GetNamedChild("Label"):SetColor(unpack(db.reblockColor))
            end,
            default = {
                r = 0.8,
                g = 0.57255,
                b = 0.18431,
                a = 1
            }
        },
        {
            type = "checkbox",
            name = GetString(AIBP_BLUR),
            tooltip = GetString(AIBP_BLUR_TOOLTIP),
            default = true,
            getFunc = function()
                return db.blur
            end,
            setFunc = function(newValue)
                db.blur = newValue;
                if not newValue and blurring then
                    SetFullscreenEffect(FULLSCREEN_EFFECT_NONE)
                    blurring = false
                end
            end
        },
        {
            type = "checkbox",
            name = GetString(AIBP_PERMA_BLUR),
            tooltip = GetString(AIBP_PERMA_BLUR_TOOLTIP),
            default = false,
            getFunc = function()
                return db.permaBlur
            end,
            setFunc = function(newValue)
                db.permaBlur = newValue;
            end,
            disabled = function()
                return db.blur == false
            end
        },
        {
            type = "checkbox",
            name = GetString(AIBP_TANK_ONLY),
            tooltip = GetString(AIBP_TANK_ONLY_TOOLTIP),
            default = false,
            getFunc = function()
                return db.tankOnly
            end,
            setFunc = function(newValue)
                db.tankOnly = newValue;
            end
        },
        {
            type = "dropdown",
            name = GetString(AIBP_SOUND_EFFECT),
            tooltip = GetString(AIBP_SOUND_EFFECT_TOOLTIP),
            choices = {
                "No_Sound",
                "Stable_FeedCarry",
                "QuestShare_Accepted",
                "Skill_Gained",
                "Duel_Start",
                "Undaunted_Transact"
            },
            getFunc = function()
                return db.sound
            end,
            setFunc = function(value)
                db.sound = value
            end,
            default = "Stable_FeedCarry"
        },
        {
            type = "slider",
            name = GetString(AIBP_SOUND_EFFECT_INTERVAL),
            min = 100,
            max = 500,
            getFunc = function()
                return db.interval
            end,
            setFunc = function(value)
                db.interval = value
            end,
            default = 300
        },
        {
            type = "button",
            name = GetString(AIBP_PLAY_TEST_SOUND),
            func = function()
                EVENT_MANAGER:RegisterForUpdate(AmIBlockingPlus.name, db.interval, function()
                    PlaySound(db.sound)
                end)
                zo_callLater(function()
                    EVENT_MANAGER:UnregisterForUpdate(AmIBlockingPlus.name)
                end, 1200)
            end
        },
        {
            type = "header",
            name = GetString(AIBP_WIDGETS),
            width = "full"
        },
        {
            type = "slider",
            name = GetString(AIBP_WIDGET_TEXT_SIZE),
            tooltip = GetString(AIBP_WIDGET_TEXT_SIZE_TOOLTIP),
            min = 16,
            max = 36,
            step = 2,
            getFunc = function()
                return db.gadgetTextSize;
            end,
            setFunc = function(value)
                db.gadgetTextSize = value;
                AmIBlockingPlusControl:GetNamedChild("BlockNum"):SetFont("$(BOLD_FONT)|" .. db.gadgetTextSize .. ")|soft-shadow-thick")
                AmIBlockingPlusControl:GetNamedChild("DodgeNum"):SetFont("$(BOLD_FONT)|" .. db.gadgetTextSize .. ")|soft-shadow-thick")
                AmIBlockingPlusControl:GetNamedChild("BashNum"):SetFont("$(BOLD_FONT)|" .. db.gadgetTextSize .. ")|soft-shadow-thick")
            end,
            default = 24
        },
        {
            type = "checkbox",
            name = GetString(AIBP_SHOW_DODGE),
            default = false,
            getFunc = function()
                return db.showDodgeLeft
            end,
            setFunc = function(newValue)
                db.showDodgeLeft = newValue;
                AmIBlockingPlus.ReorganizeWidgets()
            end
        },
        {
            type = "checkbox",
            name = GetString(AIBP_SHOW_BLOCK),
            default = true,
            getFunc = function()
                return db.showBlockLeft
            end,
            setFunc = function(newValue)
                db.showBlockLeft = newValue;
                AmIBlockingPlus.ReorganizeWidgets()
            end
        },
        {
            type = "checkbox",
            name = GetString(AIBP_SHOW_BASH),
            default = false,
            getFunc = function()
                return db.showBashLeft
            end,
            setFunc = function(newValue)
                db.showBashLeft = newValue;
                AmIBlockingPlus.ReorganizeWidgets()
            end
        },
        {
            type = "dropdown",
            name = GetString(AIBP_WIDGET_LAYOUT),
            choices = layoutChoices,
            choicesValues = layoutChoicesValues,
            getFunc = function()
                return db.gadgetLayout
            end,
            setFunc = function(value)
                db.gadgetLayout = value
                AmIBlockingPlus.ReorganizeWidgets()
            end,
            default = "horizontal"
        },
        {
            type = "checkbox",
            name = GetString(AIBP_SHOW_WIDGETS_PERMANENTLY),
            tooltip = GetString(AIBP_SHOW_WIDGETS_PERMANENTLY_TOOLTIP),
            default = true,
            getFunc = function()
                return db.permanentGadgets
            end,
            setFunc = function(newValue)
                db.permanentGadgets = newValue;
            end,
        },
    }

    LAM = LibAddonMenu2
    local settingPanel = LAM:RegisterAddonPanel(AmIBlockingPlus.name .. "Options", menuOptions)
    LAM:RegisterOptionControls(AmIBlockingPlus.name .. "Options", dataTable)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
        if panel ~= settingPanel then
            return
        end
        unlockUI = true
        AmIBlockingPlusControl:GetNamedChild("Label"):SetText(string.upper(GetString(SI_MARKET_PRODUCT_TOOLTIP_UNLOCK)))
        AmIBlockingPlusControl:SetMovable(true)
        AmIBlockingPlusControl:SetMouseEnabled(true)
    end)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if panel ~= settingPanel then
            return
        end
        unlockUI = false
        AmIBlockingPlusControl:SetMovable(false)
        AmIBlockingPlusControl:SetMouseEnabled(false)
        if ZO_IsConsoleOrGameCoreUI() then
            aibpUiLocked = true
            doGamepadMove(false)
            AmIBlockingPlusControl:GetNamedChild("Label"):SetHidden(true)
        end
    end)
end

SLASH_COMMANDS["/aibpmove"] = function(str)
    aibpUiLocked = not aibpUiLocked
    if ZO_IsConsoleOrGameCoreUI() then
        doGamepadMove(not aibpUiLocked)
    end
    if aibpUiLocked then
        if not ZO_IsConsoleOrGameCoreUI() then
            AmIBlockingPlusControl:SetMovable(false)
            AmIBlockingPlusControl:SetMouseEnabled(false)
            AmIBlockingPlusControl:GetNamedChild("Label"):SetHidden(true)
        end
        d("|cCC922FAm I Blocking Plus|r: Panel locked. Use /aibpmove again to unlock.")
    else
        if not ZO_IsConsoleOrGameCoreUI() then
            AmIBlockingPlusControl:SetMovable(true)
            AmIBlockingPlusControl:SetMouseEnabled(true)
            AmIBlockingPlusControl:GetNamedChild("Label"):SetText(string.upper(GetString(SI_MARKET_PRODUCT_TOOLTIP_UNLOCK)))
            AmIBlockingPlusControl:GetNamedChild("Label"):SetHidden(false)
        end
        d("|cCC922FAm I Blocking Plus|r: Panel unlocked. Use /aibpmove again to lock.")
    end
end

EVENT_MANAGER:RegisterForEvent(AmIBlockingPlus.name, EVENT_ADD_ON_LOADED, AmIBlockingPlus.OnAddOnLoaded)
