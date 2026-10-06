-- Главная таблица аддона
NecroCat = NecroCat or {}
NecroCat.name    = "NecroCat"

local NC = NecroCat
NC.lastWhisperTime = 0 

---------------------------------------------------------
-- 1. ФУНКЦИИ ДЕЙСТВИЙ (МАУНТ, ЧАТ, ТЕЛЕПОРТ)
---------------------------------------------------------

function NC.CastleHall()
    local accountName = GetDisplayName()
    if accountName == "@NecroCat_Crimson" then
        RequestJumpToHouse(13)
    else
        JumpToSpecificHouse("@NecroCat_Crimson", 13)
    end
end

function NC.SelfWhisper()
    local myId = GetDisplayName()
    if myId and myId ~= "" then
        StartChatInput("/w " .. myId .. " ")
    end
end

function NC.MountRider()
    if IsUnitInCombat("player") or IsUnitDead("player") then return end
    if not IsUnitGrouped("player") then return end

    for i = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(i)
        if not AreUnitsEqual("player", unitTag) and IsUnitOnline(unitTag) then
            local displayName = GetUnitDisplayName(unitTag)
            local mountedState, hasGroupMount, hasFreeSlot = GetTargetMountedStateInfo(displayName)
            
            if mountedState == MOUNTED_STATE_MOUNT_RIDER and hasGroupMount and hasFreeSlot then
                local _, x1, y1, z1 = GetUnitWorldPosition("player")
                local _, x2, y2, z2 = GetUnitWorldPosition(unitTag)
                if (zo_distance3D(x1, y1, z1, x2, y2, z2) / 100) < 5 then
                    EnablePreviewMode(true)
                    DisablePreviewMode()
                    UseMountAsPassenger(displayName)
                    return
                end
            end
        end
    end
end

-- Автоматическое переключение режима спринта (по нажатию на маунте, по удержанию пешком)
function NC.UpdateMountSprintToggle(isMounted)
    if not NC.savedVars or not NC.savedVars.mountSprintToggle then return end
    if isMounted then
        SetSetting(13, 17, "1")
    else
        SetSetting(13, 17, "0")
    end
end

function NC.OnChatMessage(eventCode, channelType, fromName, text, isCustomerService, fromDisplayName)
    if channelType ~= CHAT_CHANNEL_WHISPER or not NC.savedVars.whisperAlert then return end

    local sender = fromDisplayName:gsub("%^%w+", "")
    if sender == "" then sender = fromName:gsub("%^%w+", "") end
    
    NC.WhisperLabel:SetText(zo_strformat(GetString(SI_NC_WHISPER_ALERT), sender))
    NC.WhisperFrame:SetHidden(false)
    PlaySound("Whisper_Receive")

    local currentTime = GetFrameTimeSeconds()
    NC.lastWhisperTime = currentTime
    zo_callLater(function() 
        if NC.WhisperFrame and NC.lastWhisperTime == currentTime then 
            NC.WhisperFrame:SetHidden(true) 
        end
    end, NC.savedVars.whisperDuration * 1000)
end

-- Автоприем готовности при нахождении данжа (Activity Finder)
function NC.OnActivityFinderStatusUpdate(eventCode, status)
    if not NC.savedVars.autoAcceptDungeon then return end

    if status == ACTIVITY_FINDER_STATUS_READY_CHECK then
        zo_callLater(function()
            if GetActivityFinderStatus() == ACTIVITY_FINDER_STATUS_READY_CHECK then
                AcceptLFGReadyCheckNotification()
                --d(GetString(SI_NC_DUNGEON_FOUND))
            end
        end, 500)
    end
end

-- Автоприем входа в Сиродил и Имперский город (PvP кампания / затягивание группой)
function NC.OnCampaignQueueStateChange(eventCode, id, isGroup, state)
    if not NC.savedVars or not NC.savedVars.autoAcceptPvPQueue then return end

    if state == CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then
        ConfirmCampaignEntry(id, isGroup, true)
        local campName = (GetCampaignName and GetCampaignName(id)) or "Campaign"
        d(zo_strformat(GetString(SI_NC_CAMPAIGN_QUEUE_CONFIRMED), campName))
    end
end

-- Автоматический отзыв и возврат небоевых питомцев в триалах
function NC.CheckTrialPets()
    if not NC.savedVars or not NC.savedVars.dismissPetsInTrials then return end

    local charId = GetCurrentCharacterId()
    NC.savedVars.storedPets = NC.savedVars.storedPets or {}

    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    local isInTrial = (zoneId and NC.TrialZoneIds and NC.TrialZoneIds[zoneId]) or (IsRaidInProgress and IsRaidInProgress())

    if isInTrial then
        zo_callLater(function()
            if IsUnitInCombat("player") or IsUnitDead("player") then return end
            
            local activePetId = GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_VANITY_PET)
            if activePetId and activePetId > 0 then
                NC.savedVars.storedPets[charId] = activePetId
                UseCollectible(activePetId)
                d(GetString(SI_NC_PET_DISMISSED))
            end
        end, 2500)
    else
        local isInHouse = (GetCurrentZoneHouseId and GetCurrentZoneHouseId() ~= 0)
        if isInHouse then return end

        local storedPet = NC.savedVars.storedPets[charId] or NC.savedVars.storedPetId
        if storedPet and storedPet > 0 then
            zo_callLater(function()
                if IsUnitInCombat("player") or IsUnitDead("player") then return end
                if GetCurrentZoneHouseId and GetCurrentZoneHouseId() ~= 0 then return end

                if GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_VANITY_PET) == 0 then
                    UseCollectible(storedPet)
                    d(GetString(SI_NC_PET_SUMMONED))
                end
                NC.savedVars.storedPets[charId] = nil
                NC.savedVars.storedPetId = 0
            end, 2500)
        end
    end
end

-- Умная проверка статуса игрока (ручной выбор имеет высший приоритет над списком друзей)
function NC.IsPlayerFavorite(displayName, charName)
    local sv = NC.savedVars
    if not sv then return false end

    local favs = sv.favoritePlayers or {}

    if displayName and favs[displayName] ~= nil then
        return favs[displayName]
    end
    if charName and favs[charName] ~= nil then
        return favs[charName]
    end

    if sv.treatFriendsAsFavorites and displayName and IsFriend and IsFriend(displayName) then
        return true
    end

    return false
end

-- Исключение из группы всех игроков, которых нет в списке избранных
function NC.KickNonFavorites()
    if not IsUnitGrouped("player") then
        d(GetString(SI_NC_KICK_NO_GROUP))
        return
    end

    if not IsUnitGroupLeader("player") then
        d(GetString(SI_NC_KICK_NOT_LEADER))
        return
    end

    local kickedCount = 0

    for i = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(i)
        if unitTag and not AreUnitsEqual("player", unitTag) then
            local displayName = GetUnitDisplayName(unitTag)
            local charName = GetUnitName(unitTag)

            if not NC.IsPlayerFavorite(displayName, charName) then
                GroupKick(unitTag)
                kickedCount = kickedCount + 1
                local kickedName = (displayName and displayName ~= "") and displayName or (charName or unitTag)
                d(zo_strformat(GetString(SI_NC_KICKED_MEMBER), kickedName))
            end
        end
    end

    if kickedCount == 0 then
        d(GetString(SI_NC_KICK_ALL_FAVORITES))
    end
end

-- Поиск всех неизвестных рецептов, чертежей мебели, мотивов и страниц стилей
function NC.GetUnknownKnowledgeItems()
    local unknownList = {}
    local bagSize = GetBagSize(BAG_BACKPACK)

    for slotIndex = 0, bagSize - 1 do
        local itemLink = GetItemLink(BAG_BACKPACK, slotIndex)
        if itemLink and itemLink ~= "" then
            local itemType, specializedItemType = GetItemType(BAG_BACKPACK, slotIndex)
            local isUnknown = false

            -- 1. Рецепты еды, напитков и чертежи мебели (всегда по умолчанию)
            if itemType == ITEMTYPE_RECIPE then
                if not IsItemLinkRecipeKnown(itemLink) then
                    isUnknown = true
                end

            -- 2. Ремесленные мотивы (главы и полные книги крафта)
            elseif NC.savedVars.includeMotifs and (itemType == ITEMTYPE_RACIAL_STYLE_MOTIF or specializedItemType == SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER or specializedItemType == SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_BOOK) then
                if not IsItemLinkBookKnown(itemLink) then
                    isUnknown = true
                end

            -- 3. Страницы стилей нарядов (маски монстров, плечи, оружие, ивентовые стили)
            elseif NC.savedVars.includeStylePages then
                local isStyleItem = (specializedItemType == SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE)
                                 or (specializedItemType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE)
                                 or (itemType == ITEMTYPE_CONTAINER)
                                 or (itemType == ITEMTYPE_COLLECTIBLE)

                if isStyleItem then
                    local numCollectibles = (GetItemLinkNumContainerCollectibles and GetItemLinkNumContainerCollectibles(itemLink)) or 0
                    if numCollectibles > 0 then
                        for cIdx = 1, numCollectibles do
                            local collectibleId = GetItemLinkContainerCollectibleId(itemLink, cIdx)
                            if collectibleId and not IsCollectibleUnlocked(collectibleId) then
                                isUnknown = true
                                break
                            end
                        end
                    elseif GetItemLinkItemUseReferenceId then
                        local collectibleId = GetItemLinkItemUseReferenceId(itemLink)
                        if collectibleId and collectibleId > 0 and not IsCollectibleUnlocked(collectibleId) then
                            isUnknown = true
                        end
                    end
                end
            end

            if isUnknown then
                table.insert(unknownList, {
                    slotIndex = slotIndex,
                    itemLink  = itemLink,
                })
            end
        end
    end

    return unknownList
end

-- Глушение всплывающего окна книги при изучении мотивов
local function HookLoreReaderSuppression()
    if not LORE_READER then return end
    ZO_PreHook(LORE_READER, "Show", function(self)
        if NC.isLearningKnowledge then
            EndInteraction(INTERACTION_BOOK)
            return true
        end
    end)
end

-- Поочередное быстрое изучение найденных предметов (Турбо-режим)
function NC.LearnAllUnknownKnowledge()
    if IsUnitInCombat("player") or IsUnitDead("player") then
        d(GetString(SI_NC_LEARN_IN_COMBAT))
        return
    end

    local items = NC.GetUnknownKnowledgeItems()
    if #items == 0 then
        d(GetString(SI_NC_LEARN_NONE))
        return
    end

    d(zo_strformat(GetString(SI_NC_LEARN_START), #items))

    NC.isLearningKnowledge = true
    local count = 0

    local function ProcessNext(index)
        if index > #items then
            NC.isLearningKnowledge = false
            d(zo_strformat(GetString(SI_NC_LEARN_DONE), count))
            return
        end

        local item = items[index]
        local currentLink = GetItemLink(BAG_BACKPACK, item.slotIndex)

        if currentLink == item.itemLink then
            CallSecureProtected("UseItem", BAG_BACKPACK, item.slotIndex)
            count = count + 1
            d(string.format("|c66f2ff[NecroCat]|r (%d/%d): %s", index, #items, item.itemLink))
        end

        zo_callLater(function()
            ProcessNext(index + 1)
        end, 350)
    end

    ProcessNext(1)
end

---------------------------------------------------------
-- БЫСТРЫЙ ТЕЛЕПОРТ
---------------------------------------------------------
function NecroCat.TeleportToVivec()
    FastTravelToNode(284)
end

---------------------------------------------------------
-- AUTO-RECHARGE & AUTO-REPAIR: ПОИСК РАСХОДНИКОВ
---------------------------------------------------------

function NC.FindSoulGem(priority)
    local normalSlot, crownSlot = nil, nil
    local bagSize = GetBagSize(BAG_BACKPACK)

    for slotIndex = 0, bagSize - 1 do
        local itemType, specializedType = GetItemType(BAG_BACKPACK, slotIndex)
        if itemType == ITEMTYPE_SOUL_GEM then
            local _, isFilled = GetSoulGemItemInfo(BAG_BACKPACK, slotIndex)
            if isFilled and (isFilled == 1 or isFilled == true) then
                local link = GetItemLink(BAG_BACKPACK, slotIndex)
                local itemId = GetItemLinkItemId(link)
                local isCrown = (itemId == 61422) or (specializedType == SPECIALIZED_ITEMTYPE_SOUL_GEM_CROWN)
                
                if isCrown then
                    if not crownSlot then crownSlot = slotIndex end
                else
                    if not normalSlot then normalSlot = slotIndex end
                end
                
                -- Нашли оба варианта — дальше сумку можно не перебирать
                if normalSlot and crownSlot then break end
            end
        end
    end

    if priority == 1 then     -- Только обычные
        return normalSlot
    elseif priority == 2 then -- Сначала обычные -> затем кронные
        return normalSlot or crownSlot
    elseif priority == 3 then -- Сначала кронные -> затем обычные
        return crownSlot or normalSlot
    elseif priority == 4 then -- Только кронные
        return crownSlot
    end

    return normalSlot or crownSlot
end

-- Надежное распознавание кронных ремнаборов
local function IsCrownRepairKit(itemId, specializedType)
    return (itemId == 61079) or (itemId == 61421)
        or (specializedType == SPECIALIZED_ITEMTYPE_TOOL_REPAIR_KIT_CROWN)
        or (specializedType == SPECIALIZED_ITEMTYPE_REPAIR_KIT_CROWN)
end


function NC.FindRepairKit(priority)
    local normalSlot, crownSlot = nil, nil
    local bagSize = GetBagSize(BAG_BACKPACK)

    for slotIndex = 0, bagSize - 1 do
        local link = GetItemLink(BAG_BACKPACK, slotIndex)
        if link and link ~= "" then
            local itemId = GetItemLinkItemId(link)
            -- Отсекаем отмычки (ID 30357)
            if itemId and itemId > 0 and itemId ~= 30357 then
                local itemType, specializedType = GetItemType(BAG_BACKPACK, slotIndex)

                -- 1. Кронный ремнабор ищем прямо по ID 61079 / 61421 и типам кроны
                if IsCrownRepairKit(itemId, specializedType) then
                    if not crownSlot then crownSlot = slotIndex end

                -- 2. Обычный ремнабор ищем строго среди инструментов (исключая рецепты)
                elseif itemType ~= ITEMTYPE_RECIPE and (itemType == ITEMTYPE_TOOL or itemType == ITEMTYPE_REPAIR_KIT or specializedType == SPECIALIZED_ITEMTYPE_TOOL_REPAIR_KIT or itemId == 44879) then
                    if not normalSlot then normalSlot = slotIndex end
                end

                if normalSlot and crownSlot then break end
            end
        end
    end

    if priority == 1 then     -- Только обычные
        return normalSlot
    elseif priority == 2 then -- Сначала обычные -> затем кронные
        return normalSlot or crownSlot
    elseif priority == 3 then -- Сначала кронные -> затем обычные
        return crownSlot or normalSlot
    elseif priority == 4 then -- Только кронные
        return crownSlot
    end

    return normalSlot or crownSlot
end

-- Авто-зарядка оружия и починка брони ремнаборами
function NC.OnWornSlotUpdate(eventCode, bagId, slotIndex)
    if bagId ~= BAG_WORN then return end
    if IsUnitDead("player") then return end

    -- 1. АВТО-ЗАРЯДКА ОРУЖИЯ
    if NC.savedVars.autoRechargeEnabled then
        local itemLink = GetItemLink(BAG_WORN, slotIndex)
        if itemLink and itemLink ~= "" then
            local maxcharge = GetItemLinkMaxEnchantCharges(itemLink)
            if maxcharge and maxcharge > 0 then
                local charge = GetItemLinkNumEnchantCharges(itemLink)
                local percent = (charge / maxcharge) * 100
                if percent <= (NC.savedVars.autoRechargeThreshold or 20) then
                    local gemSlot = NC.FindSoulGem(NC.savedVars.autoRechargePriority or 2)
                    if gemSlot then
                        ChargeItemWithSoulGem(BAG_WORN, slotIndex, BAG_BACKPACK, gemSlot)
                    end
                end
            end
        end
    end

    -- 2. АВТО-ПОЧИНКА РЕМНАБОРАМИ (доспехи)
    if NC.savedVars.autoRepairKitsEnabled then
        local itemLink = GetItemLink(BAG_WORN, slotIndex)
        if itemLink and itemLink ~= "" then
            local itemType = GetItemType(BAG_WORN, slotIndex)
            local hasDurability = (DoesItemHaveDurability and DoesItemHaveDurability(BAG_WORN, slotIndex)) or (itemType == ITEMTYPE_ARMOR)
            
            if hasDurability and (slotIndex ~= EQUIP_SLOT_NECK and slotIndex ~= EQUIP_SLOT_RING1 and slotIndex ~= EQUIP_SLOT_RING2) then
                local condition = GetItemLinkCondition(itemLink)
                if condition and condition <= (NC.savedVars.autoRepairKitsThreshold or 20) then
                    local kitSlot = NC.FindRepairKit(NC.savedVars.autoRepairKitsPriority or 2)
                    if kitSlot then
                        local kitLink = GetItemLink(BAG_BACKPACK, kitSlot)
                        local kitItemId = GetItemLinkItemId(kitLink)
                        local _, kitSpecializedType = GetItemType(BAG_BACKPACK, kitSlot)

                        local isCrown = IsCrownRepairKit(kitItemId, kitSpecializedType)

                        if isCrown then
                            local now = GetFrameTimeSeconds()
                            NC.lastCrownRepairTime = NC.lastCrownRepairTime or 0
                            -- Защита от спама: кронный набор чинит сразу всё снаряжение, используем 1 раз за 3 сек
                            if (now - NC.lastCrownRepairTime > 3) and not IsUnitInCombat("player") then
                                NC.lastCrownRepairTime = now
                                if IsProtectedFunction("UseItem") then
                                    CallSecureProtected("UseItem", BAG_BACKPACK, kitSlot)
                                else
                                    UseItem(BAG_BACKPACK, kitSlot)
                                end
                                d(GetString(SI_NC_REPAIR_CROWN))
                            end
                        else
                            RepairItemWithRepairKit(BAG_WORN, slotIndex, BAG_BACKPACK, kitSlot)
                        end
                    end
                end
            end
        end
    end

    -- 3. ОБНОВЛЕНИЕ РАМОК И ЦИФР НА ЭКРАНЕ ПЕРСОНАЖА (C)
    if NC.UpdateCharacterSlotGear then
        NC.UpdateCharacterSlotGear(slotIndex)
    end
end

-- Проверка и починка/зарядка всех надетых вещей сразу (включая вторую панель оружия)
function NC.CheckAllWornGear()
    if IsUnitDead("player") then return end
    for slotIndex = 0, 16 do
        NC.OnWornSlotUpdate(nil, BAG_WORN, slotIndex)
    end
end

-- Авто-починка у торговца за золото
function NC.OnOpenStore()
    if not NC.savedVars.autoVendorRepairEnabled then return end

    if CanStoreRepair() and GetRepairAllCost() > 0 then
        local cost = GetRepairAllCost()
        local currentMoney = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER)
        if currentMoney >= cost then
            RepairAll()
            d(zo_strformat(GetString(SI_NC_REPAIR_VENDOR), cost))

            -- Обновляем все слоты на экране персонажа
            if NC.UpdateAllCharacterGear then
                NC.UpdateAllCharacterGear()
            end
        end
    end
end

---------------------------------------------------------
-- 2. ЛОГИКА ГРУППЫ (ИНВЕРСИЯ ИМЕН И @ID)
---------------------------------------------------------

-- Автоматический перевод группы в рейд при 5+ участниках
function NC.CheckAutoConvertToRaid()
    if not NC.savedVars.autoConvertToRaid then return end

    if IsUnitGroupLeader("player") and GetGroupSize() >= 5 and not IsGroupRaid() then
        ConvertToRaid()
        d(GetString(SI_NC_AUTO_RAID_CONVERT))
    end
end

-- Глушение назойливых всплывающих окон и авто-телепорт
local function SuppressDialog(dialogName, dialogData)
    -- 1. Глушим предупреждение о рейде
    if NC.savedVars.autoConvertToRaid then
        if dialogName == "LARGE_GROUP_INVITE_WARNING" 
           or dialogName == "CONVERT_TO_RAID" 
           or dialogName == "CONFIRM_CONVERT_TO_RAID" then
            return true
        end
    end

    -- 2. Глушим предложение телепорта к лидеру при входе в группу
    if NC.savedVars.suppressJumpToLeader then
        if dialogName == "JUMP_TO_GROUP_LEADER" 
           or dialogName == "CONFIRM_JUMP_TO_GROUP_LEADER"
           or (type(dialogName) == "string" and string.find(dialogName, "JUMP_TO_GROUP_LEADER")) then
            return true
        end
    end

    -- 3. Мгновенный телепорт (и бесплатный от святилища, и платный из любой точки)
    if NC.savedVars.fastTravelConfirm and (dialogName == "FAST_TRAVEL_CONFIRM" or dialogName == "RECALL_CONFIRM") then
        if dialogData and dialogData.nodeIndex then
            FastTravelToNode(dialogData.nodeIndex)
            if SCENE_MANAGER and SCENE_MANAGER:IsShowing("worldMap") then
                SCENE_MANAGER:Hide("worldMap")
            end
            return true
        end
    end

    -- 4. Авто-подтверждение входа и очереди в PvP (Сиродил / Имперка)
    if NC.savedVars.autoAcceptPvPQueue and dialogName == "PTP_TIMED_RESPONSE_PROMPT" then
        local dialogInfo = ESO_Dialogs and ESO_Dialogs[dialogName]
        local btn1 = dialogInfo and dialogInfo.buttons and dialogInfo.buttons[1]
        if btn1 and btn1.callback then
            zo_callLater(function()
                btn1.callback(ZO_Dialog1, dialogData)
            end, 20)
        elseif dialogData and type(dialogData.callback) == "function" then
            dialogData.callback()
        end
        return true
    end
end

-- Авто-заполнение проверочного текста (Крафт и Уничтожение предметов)
local function AutoConfirmDialog(dialogName)
    if type(dialogName) ~= "string" then return end

    -- Строжайшая защита: наглухо блокируем удаление персонажей, писем и разбор вещей на станках
    if string.find(dialogName, "DELETE") or string.find(dialogName, "DECONSTRUCT") then
        return
    end

    local shouldFill = false

    -- 1. Проверка для крафта (заточка, глифы, улучшение)
    if NC.savedVars.autoConfirmCrafting then
        if string.find(dialogName, "IMPROVE")
           or string.find(dialogName, "ENCHANT")
           or string.find(dialogName, "RETRAIT")
           or string.find(dialogName, "RECONSTRUCT")
           or string.find(dialogName, "TRANSMUTE")
           or string.find(dialogName, "MODIFY_LOCKED") then
            shouldFill = true
        end
    end

    -- 2. Проверка для уничтожения предметов из инвентаря (Мифики, кронные расходники)
    if NC.savedVars.autoConfirmDestroy then
        if string.find(dialogName, "DESTROY") then
            shouldFill = true
        end
    end

    if shouldFill then
        zo_callLater(function()
            local dialog = ZO_Dialog1
            if dialog and not dialog:IsHidden() then
                local editBox = ZO_Dialog1EditBox or dialog:GetNamedChild("EditBox")
                if editBox and not editBox:IsHidden() then
                    local matchText = GetString(SI_PERFORM_ACTION_CONFIRMATION)
                    local dialogInfo = ESO_Dialogs and ESO_Dialogs[dialogName]
                    if dialogInfo and dialogInfo.editBox and dialogInfo.editBox.matchingString then
                        local ms = dialogInfo.editBox.matchingString
                        if type(ms) == "string" and ms ~= "" then
                            matchText = ms
                        elseif type(ms) == "number" then
                            matchText = GetString(ms)
                        elseif type(ms) == "function" then
                            matchText = ms(dialog)
                        end
                    end

                    if matchText and matchText ~= "" then
                        editBox:SetText(matchText)
                    end
                end
            end
        end, 20)
    end
end

local function HookDialogSuppressions()
    HookLoreReaderSuppression()
    ZO_PreHook("ZO_Dialogs_ShowPlatformDialog", function(dialogName, dialogData)
        AutoConfirmDialog(dialogName)
        return SuppressDialog(dialogName, dialogData)
    end)
    ZO_PreHook("ZO_Dialogs_ShowDialog", function(dialogName, dialogData)
        AutoConfirmDialog(dialogName)
        return SuppressDialog(dialogName, dialogData)
    end)
end

local function ShowNecroTooltip(header, text)
    InitializeTooltip(InformationTooltip, GuiRoot, TOPLEFT, 0, 0)
    local mouseX, mouseY = GetUIMousePosition()
    InformationTooltip:ClearAnchors()
    InformationTooltip:SetAnchor(BOTTOM, GuiRoot, TOPLEFT, mouseX, mouseY - 15)
    
    InformationTooltip:AddLine(header, "ZoFontGameSmall")
    InformationTooltip:AddLine(text, "ZoFontWinH4", 1, 1, 1, CENTER)
end

local function NC_GroupEntryHook(self, control, data)
    if not control.characterNameLabel or not data then return end

    local charName = zo_strformat("<<1>>", data.characterName)
    local userID   = zo_strformat("<<1>>", data.displayName)

    local listText, tooltipHeader, tooltipText

    if NC.savedVars.swapGroupNames then
        listText = userID
        tooltipHeader = "Имя персонажа:"
        tooltipText = charName
    else
        listText = charName
        tooltipHeader = "ID аккаунта:"
        tooltipText = userID
    end

    control.characterNameLabel:SetText(zo_strformat(SI_GROUP_LIST_PANEL_CHARACTER_NAME, data.index, listText))

    local onEnter = function(ctrl) ShowNecroTooltip(tooltipHeader, tooltipText) end
    local onExit = function() ClearTooltip(InformationTooltip) end

    control.characterNameLabel:SetMouseEnabled(true)
    control.characterNameLabel:SetHandler("OnMouseEnter", onEnter)
    control.characterNameLabel:SetHandler("OnMouseExit", onExit)

    control:SetHandler("OnMouseEnter", onEnter)
    control:SetHandler("OnMouseExit", onExit)
end

---------------------------------------------------------
-- 3. INTERACTION FIX
---------------------------------------------------------

local function NC_InitInteractionFix()
    if not PLAYER_TO_PLAYER then return end

    ZO_PreHook(PLAYER_TO_PLAYER, "AddMenuEntry", function(self, text)
        if not NC.savedVars or not text or text == "" then return end
        local cleanText = string.lower(zo_strformat("<<1>>", text))

        -- 1. Исключить из группы
        if NC.savedVars.hideRemoveFromGroup then
            if (SI_PLAYER_TO_PLAYER_REMOVE_GROUP and text == GetString(SI_PLAYER_TO_PLAYER_REMOVE_GROUP))
               or string.find(cleanText, "исключить") 
               or string.find(cleanText, "remove from group") then
                return true
            end
        end

        -- 2. Пожаловаться на игрока
        if NC.savedVars.hideReport then
            if string.find(cleanText, "пожаловаться") 
               or string.find(cleanText, "report") then
                return true
            end
        end

        -- 3. Пригласить в карты (Легенды о наградах)
        if NC.savedVars.hideTributeInvite then
            if (SI_PLAYER_TO_PLAYER_TRIBUTE_INVITE and text == GetString(SI_PLAYER_TO_PLAYER_TRIBUTE_INVITE))
               or string.find(cleanText, "наградах") 
               or string.find(cleanText, "tribute") then
                return true
            end
        end

        -- 4. Добавить в друзья
        if NC.savedVars.hideAddFriend then
            if (SI_PLAYER_TO_PLAYER_ADD_FRIEND and text == GetString(SI_PLAYER_TO_PLAYER_ADD_FRIEND))
               or string.find(cleanText, "друзья") 
               or string.find(cleanText, "add friend") then
                return true
            end
        end

        -- 5. Вызвать на дуэль
        if NC.savedVars.hideDuel then
            if (SI_PLAYER_TO_PLAYER_CHALLENGE_DUEL and text == GetString(SI_PLAYER_TO_PLAYER_CHALLENGE_DUEL))
               or string.find(cleanText, "дуэль") 
               or string.find(cleanText, "duel") then
                return true
            end
        end

        -- 6. Обмен
        if NC.savedVars.hideTrade then
            if (SI_PLAYER_TO_PLAYER_TRADE and text == GetString(SI_PLAYER_TO_PLAYER_TRADE))
               or string.find(cleanText, "обмен") 
               or string.find(cleanText, "trade") then
                return true
            end
        end
    end)
end

function NC.UpdateJumpToLeaderSuppression()
    if not PLAYER_TO_PLAYER or not PLAYER_TO_PLAYER.control then return end

    if NC.savedVars.suppressJumpToLeader then
        PLAYER_TO_PLAYER.control:UnregisterForEvent(EVENT_UNIT_CREATED)
        PLAYER_TO_PLAYER.control:UnregisterForEvent(EVENT_ZONE_UPDATE)
        PLAYER_TO_PLAYER.control:UnregisterForEvent(EVENT_GROUP_MEMBER_JOINED)
        PLAYER_TO_PLAYER.control:UnregisterForEvent(EVENT_LEADER_UPDATE)
        PLAYER_TO_PLAYER.control:UnregisterForEvent(EVENT_GROUP_MEMBER_LEFT)
    end
end

---------------------------------------------------------
-- 4. РАБОТА С UI И МЕНЮ
---------------------------------------------------------

---------------------------------------------------------
-- МОДУЛЬ: ДОЛГИЕ БАФФЫ (ЕДА И СВИТКИ)
---------------------------------------------------------

NC.LongBuffControls = {}

local function ShowBuffTooltip(control, buffData)
    if not buffData or not buffData.name then return end
    InitializeTooltip(InformationTooltip, control, TOP, 0, 5)
    InformationTooltip:AddLine(zo_strformat("<<1>>", buffData.name), "ZoFontWinH4", 1, 0.85, 0.2)

    if buffData.abilityId and buffData.abilityId > 0 then
        local desc = GetAbilityDescription(buffData.abilityId)
        if desc and desc ~= "" then
            InformationTooltip:AddLine(zo_strformat("<<1>>", desc), "ZoFontGameSmall", 1, 1, 1)
        end
    end

    if buffData.stackCount and buffData.stackCount > 1 then
        InformationTooltip:AddLine(zo_strformat(GetString(SI_NC_TT_BUFF_STACKS), buffData.stackCount), "ZoFontGameSmall", 0.9, 0.9, 0.9)
    end

    if buffData.isPermanent then
        InformationTooltip:AddLine(GetString(SI_NC_TT_BUFF_PERMANENT), "ZoFontGameSmall")
    elseif buffData.remain and buffData.remain > 0 then
        local hours = math.floor(buffData.remain / 3600)
        local mins = math.floor((buffData.remain % 3600) / 60)
        local secs = math.floor(buffData.remain % 60)
        local timeStr = ""
        if hours > 0 then
            timeStr = string.format("%d h %d m", hours, mins)
        elseif mins > 0 then
            timeStr = string.format("%d m %d s", mins, secs)
        else
            timeStr = string.format("%.1f s", buffData.remain)
        end
        InformationTooltip:AddLine(zo_strformat(GetString(SI_NC_TT_BUFF_REMAIN), timeStr), "ZoFontGameSmall")
    end
end

local function FormatBuffTime(seconds)
    if seconds <= 0 then return "" end
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    if hours > 0 then
        return string.format("%d:%02d", hours, mins)
    else
        return string.format("%d:%02d", mins, secs)
    end
end

function NC.UpdateLongBuffsUI()
    if not NC.LongBuffsFrame or not NC.LongBuffsFragment then return end
    local sv = NC.savedVars
    if not sv then return end

    local unlocked = sv.longBuffsUnlocked
    local size = sv.longBuffsSize or 36
    local isVertical = (sv.longBuffsOrientation == 1)
    local numSlots = 5
    local spacing = 4
    local totalLength = (size * numSlots) + (spacing * (numSlots - 1))

    NC.LongBuffsFrame:SetMovable(unlocked)
    NC.LongBuffsFrame:SetMouseEnabled(unlocked)
    NC.LongBuffsPreview:SetHidden(not unlocked)

    if isVertical then
        NC.LongBuffsFrame:SetDimensions(size, totalLength)
    else
        NC.LongBuffsFrame:SetDimensions(totalLength, size)
    end

    local menuScene = SCENE_MANAGER:GetScene("gameMenuInGame")
    if sv.longBuffsEnabled then
        HUD_SCENE:AddFragment(NC.LongBuffsFragment)
        HUD_UI_SCENE:AddFragment(NC.LongBuffsFragment)
        if unlocked then
            menuScene:AddFragment(NC.LongBuffsFragment)
        else
            menuScene:RemoveFragment(NC.LongBuffsFragment)
        end
    else
        HUD_SCENE:RemoveFragment(NC.LongBuffsFragment)
        HUD_UI_SCENE:RemoveFragment(NC.LongBuffsFragment)
        menuScene:RemoveFragment(NC.LongBuffsFragment)
        NC.LongBuffsFrame:SetHidden(true)
        return
    end

    NC.UpdateLongBuffs()
end

local function GetOrCreateBuffControl(index)
    if NC.LongBuffControls[index] then
        return NC.LongBuffControls[index]
    end

    local size = NC.savedVars.longBuffsSize or 36
    local parent = NC.LongBuffsFrame

    local ctrl = WINDOW_MANAGER:CreateControl("NecroCat_LongBuff" .. index, parent, CT_CONTROL)
    ctrl:SetDimensions(size, size)

    local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", ctrl, CT_TEXTURE)
    icon:SetAnchorFill(ctrl)
    icon:SetDrawLayer(DL_CONTROLS)

    -- Черная плашка на слое OVERLAY (всегда поверх текстуры баффа)
    local labelBg = WINDOW_MANAGER:CreateControl("$(parent)LabelBg", ctrl, CT_BACKDROP)
    labelBg:SetAnchor(BOTTOMLEFT, ctrl, BOTTOMLEFT, 0, 0)
    labelBg:SetAnchor(BOTTOMRIGHT, ctrl, BOTTOMRIGHT, 0, 0)
    labelBg:SetHeight(14)
    labelBg:SetCenterColor(0, 0, 0, 0.75)
    labelBg:SetEdgeColor(0, 0, 0, 0.9)
    labelBg:SetDrawLayer(DL_OVERLAY)
    labelBg:SetDrawLevel(1)

    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", ctrl, CT_LABEL)
    label:SetAnchor(CENTER, labelBg, CENTER, 0, 0)
    label:SetFont("ZoFontWinH5")
    label:SetColor(1, 1, 1, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawLevel(2)

    local buffData = {
        control = ctrl,
        icon    = icon,
        label   = label,
        labelBg = labelBg,
    }

    ctrl:SetHandler("OnMouseEnter", function(self)
        ShowBuffTooltip(self, buffData.data)
    end)
    ctrl:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    NC.LongBuffControls[index] = buffData
    return buffData
end

function NC.UpdateLongBuffs()
    if not NC.LongBuffsFrame or not NC.savedVars or not NC.savedVars.longBuffsEnabled then return end

    local activeBuffs = {}
    local isUnlocked = NC.savedVars.longBuffsUnlocked

    -- В режиме настройки показываем 5 образцовых долгих баффов
    if isUnlocked then
        activeBuffs = {
            { icon = "EsoUI/Art/Icons/ability_buff_major_sorcery.dds", remain = 7140, isPermanent = false, stackCount = 0, timeStarted = 1, slot = 1 },
            { icon = "EsoUI/Art/Icons/ability_buff_major_prophecy.dds", remain = 3540, isPermanent = false, stackCount = 0, timeStarted = 2, slot = 2 },
            { icon = "EsoUI/Art/Icons/ability_buff_major_vitality.dds", remain = 1180, isPermanent = false, stackCount = 0, timeStarted = 3, slot = 3 },
            { icon = "EsoUI/Art/Icons/ability_buff_major_courage.dds", remain = 0, isPermanent = true, stackCount = 0, timeStarted = 4, slot = 4 },
            { icon = "EsoUI/Art/Icons/ability_buff_major_resolve.dds", remain = 0, isPermanent = true, stackCount = 0, timeStarted = 5, slot = 5 },
        }
    else
        local numBuffs = GetNumBuffs("player")
        local now = GetFrameTimeSeconds()

        for i = 1, numBuffs do
            local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId = GetUnitBuffInfo("player", i)

            if effectType == BUFF_EFFECT_TYPE_BUFF and iconFilename and iconFilename ~= "" then
                local isPermanent = (timeEnding == 0) or (timeEnding <= timeStarted)
                local totalDuration = isPermanent and 0 or (timeEnding - timeStarted)
                local remain = isPermanent and 0 or (timeEnding - now)

                local lowerName = string.lower(buffName or "")
                local cleanIcon = string.lower(iconFilename)

                local isSoulSummons = (abilityId == 43752)
                        or string.find(cleanIcon, "soul")
                        or string.find(lowerName, "душ")
                        or string.find(lowerName, "soul")

                -- Отсекаем способности оружия/доспехов (например, "Затяжная атака" на скорость коня)
                local isCombatAbility = string.find(cleanIcon, "ability_weapon")
                        or string.find(cleanIcon, "ability_armor")

                -- Военный торт (отслеживаем до самой последней секунды)
                local isTorte = string.find(lowerName, "военн") or string.find(lowerName, "war")
                        or string.find(lowerName, "торт") or string.find(lowerName, "torte")
                        or string.find(cleanIcon, "torte")

                -- Свитки опыта и Амброзия (отслеживаем до самой последней секунды)
                local isXP = string.find(lowerName, "опыт") or string.find(lowerName, "exper")
                        or string.find(lowerName, "амброз") or string.find(lowerName, "ambros")
                        or string.find(cleanIcon, "experience") or string.find(cleanIcon, "ambrosia") or string.find(cleanIcon, "scroll")

                -- Долгий бафф: это либо торт, либо опыт, либо еда/бафф длиннее 10 минут (и не боевой скилл)
                local isLongBuff = isTorte or isXP or (totalDuration > 600 and not isCombatAbility)

                -- Фильтр: бафф изначально длится >= 1800 сек (еда, свитки) или вечный
                if not isSoulSummons and ((not isPermanent and isLongBuff and remain > 0) or (isPermanent and NC.savedVars.longBuffsShowPermanent)) then
                    table.insert(activeBuffs, {
                        name        = buffName,
                        icon        = iconFilename,
                        remain      = remain,
                        isPermanent = isPermanent,
                        timeStarted = timeStarted or 0,
                        slot        = buffSlot or 0,
                        abilityId   = abilityId or 0,
                        stackCount  = stackCount or 0,
                    })
                end
            end
        end
    end

    -- Сортировка: сначала временные (еда), затем вечные; внутри — по порядку появления
    table.sort(activeBuffs, function(a, b)
        if a.isPermanent ~= b.isPermanent then
            return not a.isPermanent
        end
        return a.timeStarted < b.timeStarted
    end)

    local size = NC.savedVars.longBuffsSize or 36
    local isVertical = (NC.savedVars.longBuffsOrientation == 1)
    local growthMode = NC.savedVars.longBuffsGrowth or 1
    local spacing = 4

    -- Определяем направление роста (Прямой или Обратный)
    local isReverse = false
    if growthMode == 2 then
        isReverse = false
    elseif growthMode == 3 then
        isReverse = true
    else
        -- Режим Авто: определяем по положению на экране
        local cx, cy = NC.LongBuffsFrame:GetCenter()
        local sw, sh = GuiRoot:GetDimensions()
        if isVertical then
            isReverse = (cy and cy > (sh / 2))
        else
            isReverse = (cx and cx > (sw / 2))
        end
    end

    local isUnlocked = NC.savedVars.longBuffsUnlocked
    for i, buff in ipairs(activeBuffs) do
        local ctrlData = GetOrCreateBuffControl(i)
        ctrlData.data = buff
        ctrlData.control:SetMouseEnabled(not isUnlocked)
        ctrlData.control:SetDimensions(size, size)
        ctrlData.control:ClearAnchors()

        if i == 1 then
            -- Первый бафф крепится к соответствующему краю рамки
            if isVertical then
                if isReverse then
                    ctrlData.control:SetAnchor(BOTTOM, NC.LongBuffsFrame, BOTTOM, 0, 0)
                else
                    ctrlData.control:SetAnchor(TOP, NC.LongBuffsFrame, TOP, 0, 0)
                end
            else
                if isReverse then
                    ctrlData.control:SetAnchor(RIGHT, NC.LongBuffsFrame, RIGHT, 0, 0)
                else
                    ctrlData.control:SetAnchor(LEFT, NC.LongBuffsFrame, LEFT, 0, 0)
                end
            end
        else
            -- Последующие баффы строятся цепочкой
            local prevCtrl = NC.LongBuffControls[i - 1].control
            if isVertical then
                if isReverse then
                    ctrlData.control:SetAnchor(BOTTOM, prevCtrl, TOP, 0, -spacing)
                else
                    ctrlData.control:SetAnchor(TOP, prevCtrl, BOTTOM, 0, spacing)
                end
            else
                if isReverse then
                    ctrlData.control:SetAnchor(RIGHT, prevCtrl, LEFT, -spacing, 0)
                else
                    ctrlData.control:SetAnchor(LEFT, prevCtrl, RIGHT, spacing, 0)
                end
            end
        end

        ctrlData.icon:SetTexture(buff.icon)

        if buff.isPermanent then
            ctrlData.label:SetText("")
            ctrlData.label:SetHidden(true)
            if ctrlData.labelBg then ctrlData.labelBg:SetHidden(true) end
        else
            ctrlData.label:SetText(FormatBuffTime(buff.remain))
            ctrlData.label:SetHidden(false)
            if ctrlData.labelBg then ctrlData.labelBg:SetHidden(false) end
        end

        ctrlData.control:SetHidden(false)
    end

    -- Прячем лишние контролы
    for i = #activeBuffs + 1, #NC.LongBuffControls do
        NC.LongBuffControls[i].control:SetHidden(true)
    end
end

function NC.CreateLongBuffsUI()
    if NC.LongBuffsFrame then return end

    local size = NC.savedVars.longBuffsSize or 36

    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_LongBuffsFrame")
    frame:SetDimensions(size, size)
    frame:ClearAnchors()
    if NC.savedVars and NC.savedVars.longBuffsLeft and NC.savedVars.longBuffsTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NC.savedVars.longBuffsLeft, NC.savedVars.longBuffsTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetMovable(NC.savedVars.longBuffsUnlocked)
    frame:SetMouseEnabled(NC.savedVars.longBuffsUnlocked)
    frame:SetClampedToScreen(true)

    -- Полупрозрачная направляющая подложка (видна только при настройке)
    local preview = WINDOW_MANAGER:CreateControl("$(parent)Preview", frame, CT_BACKDROP)
    preview:SetAnchorFill(frame)
    preview:SetCenterColor(0, 0, 0, 0.4)
    preview:SetEdgeColor(0.2, 0.8, 1, 0.8)
    preview:SetDrawLayer(DL_BACKGROUND)

    preview:SetHidden(not NC.savedVars.longBuffsUnlocked)

    frame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        NC.savedVars.longBuffsLeft = self:GetLeft()
        NC.savedVars.longBuffsTop = self:GetTop()
    end)

    frame:SetHidden(true)

    NC.LongBuffsFrame        = frame
    NC.LongBuffsPreview      = preview
    NC.LongBuffsPreviewLabel = previewLabel
    NC.LongBuffsFragment     = ZO_SimpleSceneFragment:New(frame)

    NC.UpdateLongBuffsUI()
end

---------------------------------------------------------
-- МОДУЛЬ: КОРОТКИЕ БАФФЫ ИГРОКА
---------------------------------------------------------

NC.ShortBuffControls = {}

local function FormatShortBuffTime(seconds)
    if seconds <= 0 then return "" end
    if seconds >= 60 then
        local mins = math.floor(seconds / 60)
        local secs = math.floor(seconds % 60)
        return string.format("%d:%02d", mins, secs)
    elseif seconds >= 5 then
        return string.format("%d", math.ceil(seconds))
    else
        return string.format("%.1f", seconds)
    end
end

function NC.UpdateShortBuffsUI()
    if not NC.ShortBuffsFrame or not NC.ShortBuffsFragment then return end
    local sv = NC.savedVars
    if not sv then return end

    local unlocked = sv.shortBuffsUnlocked
    local size = sv.shortBuffsSize or 36
    local isVertical = (sv.shortBuffsOrientation == 1)
    local numSlots = 5
    local spacing = 4
    local totalLength = (size * numSlots) + (spacing * (numSlots - 1))

    NC.ShortBuffsFrame:SetMovable(unlocked)
    NC.ShortBuffsFrame:SetMouseEnabled(unlocked)
    NC.ShortBuffsPreview:SetHidden(not unlocked)

    if isVertical then
        NC.ShortBuffsFrame:SetDimensions(size, totalLength)
    else
        NC.ShortBuffsFrame:SetDimensions(totalLength, size)
    end

    local menuScene = SCENE_MANAGER:GetScene("gameMenuInGame")
    if sv.shortBuffsEnabled then
        HUD_SCENE:AddFragment(NC.ShortBuffsFragment)
        HUD_UI_SCENE:AddFragment(NC.ShortBuffsFragment)
        if unlocked then
            menuScene:AddFragment(NC.ShortBuffsFragment)
        else
            menuScene:RemoveFragment(NC.ShortBuffsFragment)
        end
    else
        HUD_SCENE:RemoveFragment(NC.ShortBuffsFragment)
        HUD_UI_SCENE:RemoveFragment(NC.ShortBuffsFragment)
        menuScene:RemoveFragment(NC.ShortBuffsFragment)
        NC.ShortBuffsFrame:SetHidden(true)
        return
    end

    NC.UpdateShortBuffs()
end

local function GetOrCreateShortBuffControl(index)
    if NC.ShortBuffControls[index] then
        return NC.ShortBuffControls[index]
    end

    local size = NC.savedVars.shortBuffsSize or 36
    local parent = NC.ShortBuffsFrame

    local ctrl = WINDOW_MANAGER:CreateControl("NecroCat_ShortBuff" .. index, parent, CT_CONTROL)
    ctrl:SetDimensions(size, size)

    local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", ctrl, CT_TEXTURE)
    icon:SetAnchorFill(ctrl)
    icon:SetDrawLayer(DL_CONTROLS)

    -- Черная плашка под таймер
    local labelBg = WINDOW_MANAGER:CreateControl("$(parent)LabelBg", ctrl, CT_BACKDROP)
    labelBg:SetAnchor(BOTTOMLEFT, ctrl, BOTTOMLEFT, 0, 0)
    labelBg:SetAnchor(BOTTOMRIGHT, ctrl, BOTTOMRIGHT, 0, 0)
    labelBg:SetHeight(14)
    labelBg:SetCenterColor(0, 0, 0, 0.75)
    labelBg:SetEdgeColor(0, 0, 0, 0.9)
    labelBg:SetDrawLayer(DL_OVERLAY)
    labelBg:SetDrawLevel(1)

    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", ctrl, CT_LABEL)
    label:SetAnchor(CENTER, labelBg, CENTER, 0, 0)
    label:SetFont("ZoFontWinH5")
    label:SetColor(1, 1, 1, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawLevel(2)

    -- Метка количества стаков способности (например, x5)
    local stackLabel = WINDOW_MANAGER:CreateControl("$(parent)Stack", ctrl, CT_LABEL)
    stackLabel:SetAnchor(TOPRIGHT, ctrl, TOPRIGHT, -1, 1)
    stackLabel:SetFont("ZoFontGameBold")
    stackLabel:SetColor(1, 0.85, 0.2, 1)
    stackLabel:SetDrawLayer(DL_OVERLAY)
    stackLabel:SetDrawLevel(3)
    stackLabel:SetHidden(true)

    local buffData = {
        control    = ctrl,
        icon       = icon,
        label      = label,
        labelBg    = labelBg,
        stackLabel = stackLabel,
    }

    ctrl:SetHandler("OnMouseEnter", function(self)
        ShowBuffTooltip(self, buffData.data)
    end)
    ctrl:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    NC.ShortBuffControls[index] = buffData
    return buffData
end

function NC.UpdateShortBuffs()
    if not NC.ShortBuffsFrame or not NC.savedVars or not NC.savedVars.shortBuffsEnabled then return end

    local activeBuffs = {}
    local isUnlocked = NC.savedVars.shortBuffsUnlocked

    -- В режиме настройки показываем 5 образцовых коротких боевых баффов
    if isUnlocked then
        activeBuffs = {
            { icon = "EsoUI/Art/Icons/ability_buff_major_brutality.dds", remain = 23.5, stackCount = 0, timeStarted = 1, slot = 1 },
            { icon = "EsoUI/Art/Icons/ability_buff_major_berserk.dds", remain = 14.0, stackCount = 0, timeStarted = 2, slot = 2 },
            { icon = "EsoUI/Art/Icons/ability_buff_minor_force.dds", remain = 8.2, stackCount = 0, timeStarted = 3, slot = 3 },
            { icon = "EsoUI/Art/Icons/ability_buff_major_expedition.dds", remain = 4.1, stackCount = 3, timeStarted = 4, slot = 4 },
            { icon = "EsoUI/Art/Icons/ability_buff_minor_evasion.dds", remain = 1.8, stackCount = 0, timeStarted = 5, slot = 5 },
        }
    else
        local numBuffs = GetNumBuffs("player")
        local now = GetFrameTimeSeconds()

        for i = 1, numBuffs do
                    local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff = GetUnitBuffInfo("player", i)

                    if effectType == BUFF_EFFECT_TYPE_BUFF and iconFilename and iconFilename ~= "" then
                        local isPermanent = (timeEnding == 0) or (timeEnding <= timeStarted)
                        local totalDuration = isPermanent and 0 or (timeEnding - timeStarted)
                        local remain = isPermanent and 0 or (timeEnding - now)

                        local lowerName = string.lower(buffName or "")
                        local isConsumable = canClickOff
                            or (abilityId == 66776 or abilityId == 147687 or abilityId == 147466 or abilityId == 147467 or abilityId == 147733 or abilityId == 147734)
                            or string.find(lowerName, "военн") or string.find(lowerName, "war")
                            or string.find(lowerName, "торт") or string.find(lowerName, "torte")
                            or string.find(lowerName, "опыт") or string.find(lowerName, "exper")
                            or string.find(lowerName, "амброз") or string.find(lowerName, "ambros")

                        -- Фильтр: баффы, которые ИЗНАЧАЛЬНО длятся < 120 сек (еда сюда не попадет никогда!)
                        if not isPermanent and not isConsumable and totalDuration > 0 and totalDuration < 120 and remain > 0 then
                    table.insert(activeBuffs, {
                        name        = buffName,
                        icon        = iconFilename,
                        remain      = remain,
                        stackCount  = stackCount or 0,
                        timeStarted = timeStarted or 0,
                        slot        = buffSlot or 0,
                        abilityId   = abilityId or 0,
                    })
                end
            end
        end
    end

    -- Сортировка: строго по порядку появления (не прыгают при тиканье)
    table.sort(activeBuffs, function(a, b)
        local timeA = a.timeStarted or 0
        local timeB = b.timeStarted or 0
        if timeA ~= timeB then
            return timeA < timeB
        end
        return (a.slot or 0) < (b.slot or 0)
    end)

    local size = NC.savedVars.shortBuffsSize or 36
    local isVertical = (NC.savedVars.shortBuffsOrientation == 1)
    local growthMode = NC.savedVars.shortBuffsGrowth or 1
    local spacing = 4

    -- Направление роста
    local isReverse = false
    if growthMode == 2 then
        isReverse = false
    elseif growthMode == 3 then
        isReverse = true
    else
        local cx, cy = NC.ShortBuffsFrame:GetCenter()
        local sw, sh = GuiRoot:GetDimensions()
        if isVertical then
            isReverse = (cy and cy > (sh / 2))
        else
            isReverse = (cx and cx > (sw / 2))
        end
    end

    local isUnlocked = NC.savedVars.shortBuffsUnlocked
    for i, buff in ipairs(activeBuffs) do
        local ctrlData = GetOrCreateShortBuffControl(i)
        ctrlData.data = buff
        ctrlData.control:SetMouseEnabled(not isUnlocked)
        ctrlData.control:SetDimensions(size, size)
        ctrlData.control:ClearAnchors()

        if i == 1 then
            if isVertical then
                if isReverse then
                    ctrlData.control:SetAnchor(BOTTOM, NC.ShortBuffsFrame, BOTTOM, 0, 0)
                else
                    ctrlData.control:SetAnchor(TOP, NC.ShortBuffsFrame, TOP, 0, 0)
                end
            else
                if isReverse then
                    ctrlData.control:SetAnchor(RIGHT, NC.ShortBuffsFrame, RIGHT, 0, 0)
                else
                    ctrlData.control:SetAnchor(LEFT, NC.ShortBuffsFrame, LEFT, 0, 0)
                end
            end
        else
            local prevCtrl = NC.ShortBuffControls[i - 1].control
            if isVertical then
                if isReverse then
                    ctrlData.control:SetAnchor(BOTTOM, prevCtrl, TOP, 0, -spacing)
                else
                    ctrlData.control:SetAnchor(TOP, prevCtrl, BOTTOM, 0, spacing)
                end
            else
                if isReverse then
                    ctrlData.control:SetAnchor(RIGHT, prevCtrl, LEFT, -spacing, 0)
                else
                    ctrlData.control:SetAnchor(LEFT, prevCtrl, RIGHT, spacing, 0)
                end
            end
        end

        ctrlData.icon:SetTexture(buff.icon)
        ctrlData.label:SetText(FormatShortBuffTime(buff.remain))
        ctrlData.label:SetHidden(false)
        ctrlData.labelBg:SetHidden(false)

        if buff.stackCount > 1 then
            ctrlData.stackLabel:SetText(tostring(buff.stackCount))
            ctrlData.stackLabel:SetHidden(false)
        else
            ctrlData.stackLabel:SetHidden(true)
        end

        ctrlData.control:SetHidden(false)
    end

    -- Прячем неиспользуемые контролы
    for i = #activeBuffs + 1, #NC.ShortBuffControls do
        NC.ShortBuffControls[i].control:SetHidden(true)
    end
end

function NC.CreateShortBuffsUI()
    if NC.ShortBuffsFrame then return end

    local size = NC.savedVars.shortBuffsSize or 36

    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_ShortBuffsFrame")
    frame:SetDimensions(size, size)
    frame:ClearAnchors()
    if NC.savedVars and NC.savedVars.shortBuffsLeft and NC.savedVars.shortBuffsTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NC.savedVars.shortBuffsLeft, NC.savedVars.shortBuffsTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetMovable(NC.savedVars.shortBuffsUnlocked)
    frame:SetMouseEnabled(NC.savedVars.shortBuffsUnlocked)
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)

    -- Полупрозрачная направляющая подложка
    local preview = WINDOW_MANAGER:CreateControl("$(parent)Preview", frame, CT_BACKDROP)
    preview:SetAnchorFill(frame)
    preview:SetCenterColor(0, 0, 0, 0.4)
    preview:SetEdgeColor(0.2, 0.8, 1, 0.8)
    preview:SetDrawLayer(DL_BACKGROUND)
    preview:SetHidden(not NC.savedVars.shortBuffsUnlocked)

    frame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        NC.savedVars.shortBuffsLeft = self:GetLeft()
        NC.savedVars.shortBuffsTop = self:GetTop()
    end)

    NC.ShortBuffsFrame    = frame
    NC.ShortBuffsPreview  = preview
    NC.ShortBuffsFragment = ZO_SimpleSceneFragment:New(frame)

    NC.UpdateShortBuffsUI()
end

---------------------------------------------------------
-- МОДУЛЬ: ДЕБАФФЫ НА ИГРОКЕ
---------------------------------------------------------

NC.PlayerDebuffControls = {}

function NC.UpdatePlayerDebuffsUI()
    if not NC.PlayerDebuffsFrame or not NC.PlayerDebuffsFragment then return end
    local sv = NC.savedVars
    if not sv then return end

    local unlocked = sv.playerDebuffsUnlocked
    local size = sv.playerDebuffsSize or 36
    local isVertical = (sv.playerDebuffsOrientation == 1)
    local numSlots = 5
    local spacing = 4
    local slotHeight = size + 14 -- Высота с учетом таймера под иконкой

    NC.PlayerDebuffsFrame:SetMovable(unlocked)
    NC.PlayerDebuffsFrame:SetMouseEnabled(unlocked)
    NC.PlayerDebuffsPreview:SetHidden(not unlocked)

    if isVertical then
        local totalHeight = (slotHeight * numSlots) + (spacing * (numSlots - 1))
        NC.PlayerDebuffsFrame:SetDimensions(size, totalHeight)
    else
        local totalWidth = (size * numSlots) + (spacing * (numSlots - 1))
        NC.PlayerDebuffsFrame:SetDimensions(totalWidth, slotHeight)
    end

    local menuScene = SCENE_MANAGER:GetScene("gameMenuInGame")
    if sv.playerDebuffsEnabled then
        HUD_SCENE:AddFragment(NC.PlayerDebuffsFragment)
        HUD_UI_SCENE:AddFragment(NC.PlayerDebuffsFragment)
        if unlocked then
            menuScene:AddFragment(NC.PlayerDebuffsFragment)
        else
            menuScene:RemoveFragment(NC.PlayerDebuffsFragment)
        end
    else
        HUD_SCENE:RemoveFragment(NC.PlayerDebuffsFragment)
        HUD_UI_SCENE:RemoveFragment(NC.PlayerDebuffsFragment)
        menuScene:RemoveFragment(NC.PlayerDebuffsFragment)
        NC.PlayerDebuffsFrame:SetHidden(true)
        return
    end

    NC.UpdatePlayerDebuffs()
end

local function GetOrCreatePlayerDebuffControl(index)
    if NC.PlayerDebuffControls[index] then
        return NC.PlayerDebuffControls[index]
    end

    local size = NC.savedVars.playerDebuffsSize or 36
    local parent = NC.PlayerDebuffsFrame

    -- Контейнер вмещает иконку + таймер под ней
    local ctrl = WINDOW_MANAGER:CreateControl("NecroCat_PlayerDebuff" .. index, parent, CT_CONTROL)
    ctrl:SetDimensions(size, size + 14)

    -- Иконка дебаффа
    local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", ctrl, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, ctrl, TOPLEFT, 0, 0)
    icon:SetDimensions(size, size)
    icon:SetDrawLayer(DL_CONTROLS)

    -- Черная плашка СНИЗУ ПОД иконкой
    local labelBg = WINDOW_MANAGER:CreateControl("$(parent)LabelBg", ctrl, CT_BACKDROP)
    labelBg:SetAnchor(TOPLEFT, icon, BOTTOMLEFT, 0, 0)
    labelBg:SetAnchor(BOTTOMRIGHT, ctrl, BOTTOMRIGHT, 0, 0)
    labelBg:SetCenterColor(0, 0, 0, 0.75)
    labelBg:SetEdgeColor(0, 0, 0, 0)
    labelBg:SetDrawLayer(DL_OVERLAY)
    labelBg:SetDrawLevel(1)

    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", ctrl, CT_LABEL)
    label:SetAnchor(CENTER, labelBg, CENTER, 0, 0)
    label:SetFont("ZoFontWinH5")
    label:SetColor(1, 0.4, 0.4, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawLevel(2)

    -- Стаки в правом верхнем углу иконки
    local stackLabel = WINDOW_MANAGER:CreateControl("$(parent)Stack", ctrl, CT_LABEL)
    stackLabel:SetAnchor(TOPRIGHT, icon, TOPRIGHT, -1, 1)
    stackLabel:SetFont("ZoFontGameSmall")
    stackLabel:SetColor(1, 0.9, 0.2, 1)
    stackLabel:SetDrawLayer(DL_OVERLAY)
    stackLabel:SetDrawLevel(3)
    stackLabel:SetHidden(true)

    local debuffData = {
        control    = ctrl,
        icon       = icon,
        label      = label,
        labelBg    = labelBg,
        stackLabel = stackLabel,
    }

    ctrl:SetHandler("OnMouseEnter", function(self)
        ShowBuffTooltip(self, debuffData.data)
    end)
    ctrl:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    NC.PlayerDebuffControls[index] = debuffData
    return debuffData
end

function NC.UpdatePlayerDebuffs()
    if not NC.PlayerDebuffsFrame or not NC.savedVars or not NC.savedVars.playerDebuffsEnabled then return end

    local activeDebuffs = {}
    local isUnlocked = NC.savedVars.playerDebuffsUnlocked

    -- Если включен режим настройки — показываем 5 образцовых дебаффов
    if isUnlocked then
        activeDebuffs = {
            { icon = "EsoUI/Art/Icons/ability_debuff_stun.dds", remain = 8.2, stackCount = 0, isPermanent = false },
            { icon = "EsoUI/Art/Icons/ability_debuff_snare.dds", remain = 5.4, stackCount = 3, isPermanent = false },
            { icon = "EsoUI/Art/Icons/ability_debuff_major_defile.dds", remain = 3.0, stackCount = 0, isPermanent = false },
            { icon = "EsoUI/Art/Icons/ability_debuff_major_breach.dds", remain = 12.0, stackCount = 0, isPermanent = false },
            { icon = "EsoUI/Art/Icons/ability_debuff_minor_vulnerability.dds", remain = 1.5, stackCount = 0, isPermanent = false },
        }
    else
        local numBuffs = GetNumBuffs("player")
        local now = GetFrameTimeSeconds()

        for i = 1, numBuffs do
            local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId = GetUnitBuffInfo("player", i)

            -- Фильтр: строго отрицательные дебаффы игрока
            if effectType == BUFF_EFFECT_TYPE_DEBUFF and iconFilename and iconFilename ~= "" then
                local isPermanent = (timeEnding == 0) or (timeEnding <= timeStarted)
                local remain = isPermanent and 0 or (timeEnding - now)

                table.insert(activeDebuffs, {
                    name        = buffName,
                    icon        = iconFilename,
                    remain      = remain,
                    isPermanent = isPermanent,
                    stackCount  = stackCount or 0,
                    timeStarted = timeStarted or 0,
                    slot        = buffSlot or 0,
                    abilityId   = abilityId or 0,
                })
            end
        end
    end

    -- Сортировка дебаффов: по порядку получения
    table.sort(activeDebuffs, function(a, b)
        if a.isPermanent ~= b.isPermanent then
            return not a.isPermanent
        end
        local timeA = a.timeStarted or 0
        local timeB = b.timeStarted or 0
        if timeA ~= timeB then
            return timeA < timeB
        end
        return (a.slot or 0) < (b.slot or 0)
    end)

    local size = NC.savedVars.playerDebuffsSize or 36
    local isVertical = (NC.savedVars.playerDebuffsOrientation == 1)
    local growthMode = NC.savedVars.playerDebuffsGrowth or 1
    local spacing = 4

    local isReverse = false
    if growthMode == 2 then
        isReverse = false
    elseif growthMode == 3 then
        isReverse = true
    else
        local cx, cy = NC.PlayerDebuffsFrame:GetCenter()
        local sw, sh = GuiRoot:GetDimensions()
        if isVertical then
            isReverse = (cy and cy > (sh / 2))
        else
            isReverse = (cx and cx > (sw / 2))
        end
    end

    for i, debuff in ipairs(activeDebuffs) do
        local ctrlData = GetOrCreatePlayerDebuffControl(i)
        ctrlData.data = debuff
        ctrlData.control:SetMouseEnabled(not isUnlocked)
        ctrlData.control:SetDimensions(size, size + 14)
        ctrlData.icon:SetDimensions(size, size)
        ctrlData.control:ClearAnchors()

        if i == 1 then
            if isVertical then
                if isReverse then
                    ctrlData.control:SetAnchor(BOTTOM, NC.PlayerDebuffsFrame, BOTTOM, 0, 0)
                else
                    ctrlData.control:SetAnchor(TOP, NC.PlayerDebuffsFrame, TOP, 0, 0)
                end
            else
                if isReverse then
                    ctrlData.control:SetAnchor(RIGHT, NC.PlayerDebuffsFrame, RIGHT, 0, 0)
                else
                    ctrlData.control:SetAnchor(LEFT, NC.PlayerDebuffsFrame, LEFT, 0, 0)
                end
            end
        else
            local prevCtrl = NC.PlayerDebuffControls[i - 1].control
            if isVertical then
                if isReverse then
                    ctrlData.control:SetAnchor(BOTTOM, prevCtrl, TOP, 0, -spacing)
                else
                    ctrlData.control:SetAnchor(TOP, prevCtrl, BOTTOM, 0, spacing)
                end
            else
                if isReverse then
                    ctrlData.control:SetAnchor(RIGHT, prevCtrl, LEFT, -spacing, 0)
                else
                    ctrlData.control:SetAnchor(LEFT, prevCtrl, RIGHT, spacing, 0)
                end
            end
        end

        ctrlData.icon:SetTexture(debuff.icon)

        if debuff.isPermanent then
            ctrlData.label:SetText("")
            ctrlData.label:SetHidden(true)
            ctrlData.labelBg:SetHidden(true)
        else
            ctrlData.label:SetText(FormatShortBuffTime(debuff.remain))
            ctrlData.label:SetHidden(false)
            ctrlData.labelBg:SetHidden(false)
        end

        if debuff.stackCount > 1 then
            ctrlData.stackLabel:SetText(tostring(debuff.stackCount))
            ctrlData.stackLabel:SetHidden(false)
        else
            ctrlData.stackLabel:SetHidden(true)
        end

        ctrlData.control:SetHidden(false)
    end

    for i = #activeDebuffs + 1, #NC.PlayerDebuffControls do
        NC.PlayerDebuffControls[i].control:SetHidden(true)
    end
end

function NC.CreatePlayerDebuffsUI()
    if NC.PlayerDebuffsFrame then return end

    local size = NC.savedVars.playerDebuffsSize or 36

    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_PlayerDebuffsFrame")
    frame:SetDimensions(size, size)
    frame:ClearAnchors()
    if NC.savedVars and NC.savedVars.playerDebuffsLeft and NC.savedVars.playerDebuffsTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NC.savedVars.playerDebuffsLeft, NC.savedVars.playerDebuffsTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetMovable(NC.savedVars.playerDebuffsUnlocked)
    frame:SetMouseEnabled(NC.savedVars.playerDebuffsUnlocked)
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)

    -- Тревожная полупрозрачная темно-красная направляющая
    local preview = WINDOW_MANAGER:CreateControl("$(parent)Preview", frame, CT_BACKDROP)
    preview:SetAnchorFill(frame)
    preview:SetCenterColor(0.4, 0, 0, 0.4)
    preview:SetEdgeColor(1, 0.2, 0.2, 0.85)
    preview:SetDrawLayer(DL_BACKGROUND)
    preview:SetHidden(not NC.savedVars.playerDebuffsUnlocked)

    frame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        NC.savedVars.playerDebuffsLeft = self:GetLeft()
        NC.savedVars.playerDebuffsTop = self:GetTop()
    end)

    NC.PlayerDebuffsFrame    = frame
    NC.PlayerDebuffsPreview  = preview
    NC.PlayerDebuffsFragment = ZO_SimpleSceneFragment:New(frame)

    NC.UpdatePlayerDebuffsUI()
end

function NC.TestPlayerDebuff()
    if not NC.PlayerDebuffsFrame then return end
    local ctrlData = GetOrCreatePlayerDebuffControl(1)
    local size = NC.savedVars.playerDebuffsSize or 36
    ctrlData.control:SetDimensions(size, size)
    ctrlData.control:ClearAnchors()
    ctrlData.control:SetAnchor(TOPLEFT, NC.PlayerDebuffsFrame, TOPLEFT, 0, 0)
    ctrlData.icon:SetTexture("EsoUI/Art/Icons/ability_debuff_stun.dds")
    ctrlData.label:SetText("5.4")
    ctrlData.label:SetHidden(false)
    ctrlData.labelBg:SetHidden(false)
    ctrlData.stackLabel:SetText("x3")
    ctrlData.stackLabel:SetHidden(false)
    ctrlData.control:SetHidden(false)
    d("|c66f2ff[NecroCat]|r Тестовый дебафф показан на 8 секунд!")
    zo_callLater(function()
        if ctrlData and ctrlData.control then
            ctrlData.control:SetHidden(true)
        end
    end, 8000)
end

---------------------------------------------------------
-- МОДУЛЬ: ДЕБАФФЫ НА ЦЕЛИ (ВРАГЕ)
---------------------------------------------------------

NC.TargetDebuffControls = {}

function NC.UpdateTargetDebuffsUI()
    if not NC.TargetDebuffsFrame or not NC.TargetDebuffsFragment then return end
    local sv = NC.savedVars
    if not sv then return end

    local unlocked = sv.targetDebuffsUnlocked
    local size = sv.targetDebuffsSize or 36
    local isVertical = (sv.targetDebuffsOrientation == 1)
    local numSlots = 5
    local spacing = 4
    local slotHeight = size + 14

    NC.TargetDebuffsFrame:SetMovable(unlocked)
    NC.TargetDebuffsFrame:SetMouseEnabled(unlocked)
    NC.TargetDebuffsPreview:SetHidden(not unlocked)

    if isVertical then
        local totalHeight = (slotHeight * numSlots) + (spacing * (numSlots - 1))
        NC.TargetDebuffsFrame:SetDimensions(size, totalHeight)
    else
        NC.TargetDebuffsFrame:SetDimensions(size, slotHeight)
    end

    local menuScene = SCENE_MANAGER:GetScene("gameMenuInGame")
    if sv.targetDebuffsEnabled then
        HUD_SCENE:AddFragment(NC.TargetDebuffsFragment)
        HUD_UI_SCENE:AddFragment(NC.TargetDebuffsFragment)
        if unlocked then
            menuScene:AddFragment(NC.TargetDebuffsFragment)
        else
            menuScene:RemoveFragment(NC.TargetDebuffsFragment)
        end
    else
        HUD_SCENE:RemoveFragment(NC.TargetDebuffsFragment)
        HUD_UI_SCENE:RemoveFragment(NC.TargetDebuffsFragment)
        menuScene:RemoveFragment(NC.TargetDebuffsFragment)
        NC.TargetDebuffsFrame:SetHidden(true)
        return
    end

    NC.UpdateTargetDebuffs()
end

local function GetOrCreateTargetDebuffControl(index)
    if NC.TargetDebuffControls[index] then
        return NC.TargetDebuffControls[index]
    end

    local size = NC.savedVars.targetDebuffsSize or 36
    local parent = NC.TargetDebuffsFrame

    local ctrl = WINDOW_MANAGER:CreateControl("NecroCat_TargetDebuff" .. index, parent, CT_CONTROL)
    ctrl:SetDimensions(size, size + 14)

    local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", ctrl, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, ctrl, TOPLEFT, 0, 0)
    icon:SetDimensions(size, size)
    icon:SetDrawLayer(DL_CONTROLS)

    local labelBg = WINDOW_MANAGER:CreateControl("$(parent)LabelBg", ctrl, CT_BACKDROP)
    labelBg:SetAnchor(TOPLEFT, icon, BOTTOMLEFT, 0, 0)
    labelBg:SetAnchor(BOTTOMRIGHT, ctrl, BOTTOMRIGHT, 0, 0)
    labelBg:SetCenterColor(0, 0, 0, 0.75)
    labelBg:SetEdgeColor(0, 0, 0, 0)
    labelBg:SetDrawLayer(DL_OVERLAY)
    labelBg:SetDrawLevel(1)

    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", ctrl, CT_LABEL)
    label:SetAnchor(CENTER, labelBg, CENTER, 0, 0)
    label:SetFont("ZoFontWinH5")
    label:SetColor(1, 0.4, 0.4, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawLevel(2)

    local stackLabel = WINDOW_MANAGER:CreateControl("$(parent)Stack", ctrl, CT_LABEL)
    stackLabel:SetAnchor(TOPRIGHT, icon, TOPRIGHT, -1, 1)
    stackLabel:SetFont("ZoFontGameSmall")
    stackLabel:SetColor(1, 0.9, 0.2, 1)
    stackLabel:SetDrawLayer(DL_OVERLAY)
    stackLabel:SetDrawLevel(3)
    stackLabel:SetHidden(true)

    local debuffData = {
        control    = ctrl,
        icon       = icon,
        label      = label,
        labelBg    = labelBg,
        stackLabel = stackLabel,
    }

    ctrl:SetHandler("OnMouseEnter", function(self)
        if ShowBuffTooltip then ShowBuffTooltip(self, debuffData.data) end
    end)
    ctrl:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    NC.TargetDebuffControls[index] = debuffData
    return debuffData
end

function NC.UpdateTargetDebuffs()
    if not NC.TargetDebuffsFrame or not NC.savedVars or not NC.savedVars.targetDebuffsEnabled then return end

    local activeDebuffs = {}
    local isUnlocked = NC.savedVars.targetDebuffsUnlocked

    -- В режиме настройки показываем 3 образцовых дебаффа цели
    if isUnlocked then
        NC.TargetDebuffsFrame:SetHidden(false)
        activeDebuffs = {
            { icon = "EsoUI/Art/Icons/ability_debuff_major_breach.dds", remain = 18.0, stackCount = 0, isPermanent = false },
            { icon = "EsoUI/Art/Icons/ability_debuff_minor_vulnerability.dds", remain = 12.5, stackCount = 0, isPermanent = false },
            { icon = "EsoUI/Art/Icons/ability_debuff_major_defile.dds", remain = 7.0, stackCount = 0, isPermanent = false },
        }
    else
        if not DoesUnitExist("reticleover") or IsUnitDead("reticleover") then
            for i = 1, #NC.TargetDebuffControls do
                NC.TargetDebuffControls[i].control:SetHidden(true)
            end
            return
        end

        local numBuffs = GetNumBuffs("reticleover")
        local now = GetFrameTimeSeconds()
        local debuffMap = {}

        for i = 1, numBuffs do
            local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer = GetUnitBuffInfo("reticleover", i)

            if effectType == BUFF_EFFECT_TYPE_DEBUFF and iconFilename and iconFilename ~= "" and buffName and buffName ~= "" then
                local passesPlayerFilter = not NC.savedVars.targetDebuffsOnlyPlayer or castByPlayer
                if passesPlayerFilter then
                    local isPermanent = (timeEnding == 0) or (timeEnding <= timeStarted)
                    local remain = isPermanent and 0 or (timeEnding - now)

                    local newDebuff = {
                        name         = buffName,
                        icon         = iconFilename,
                        remain       = remain,
                        isPermanent  = isPermanent,
                        stackCount   = stackCount or 0,
                        timeStarted  = timeStarted or 0,
                        slot         = buffSlot or 0,
                        abilityId    = abilityId or 0,
                        castByPlayer = castByPlayer or false,
                    }

                    local existing = debuffMap[buffName]
                    if not existing then
                        debuffMap[buffName] = newDebuff
                    else
                        -- Приоритет 1: свой личный дебафф всегда вытесняет чужой
                        if newDebuff.castByPlayer and not existing.castByPlayer then
                            debuffMap[buffName] = newDebuff
                        -- Приоритет 2: чужой дебафф никогда не может затереть твой
                        elseif not newDebuff.castByPlayer and existing.castByPlayer then
                            -- оставляем существующий твой
                        -- Приоритет 3: если оба твои или оба чужие — берем с наибольшим таймером
                        elseif newDebuff.remain > existing.remain then
                            debuffMap[buffName] = newDebuff
                        end
                    end
                end
            end
        end

        for _, debuff in pairs(debuffMap) do
            table.insert(activeDebuffs, debuff)
        end
    end

    -- Сортировка дебаффов цели: по времени получения
    table.sort(activeDebuffs, function(a, b)
        if a.isPermanent ~= b.isPermanent then
            return not a.isPermanent
        end
        local timeA = a.timeStarted or 0
        local timeB = b.timeStarted or 0
        if timeA ~= timeB then
            return timeA < timeB
        end
        return (a.slot or 0) < (b.slot or 0)
    end)

    local size = NC.savedVars.targetDebuffsSize or 36
    local isVertical = (NC.savedVars.targetDebuffsOrientation == 1)
    local spacing = 4

    local numDebuffs = #activeDebuffs
    local totalRowWidth = (numDebuffs * size) + ((numDebuffs - 1) * spacing)
    local startX = -(totalRowWidth / 2) + (size / 2)

    for i, debuff in ipairs(activeDebuffs) do
        local ctrlData = GetOrCreateTargetDebuffControl(i)
        ctrlData.data = debuff
        ctrlData.control:SetMouseEnabled(not isUnlocked)
        ctrlData.control:SetDimensions(size, size + 14)
        ctrlData.icon:SetDimensions(size, size)
        ctrlData.control:ClearAnchors()

        if isVertical then
            if i == 1 then
                ctrlData.control:SetAnchor(TOP, NC.TargetDebuffsFrame, TOP, 0, 0)
            else
                local prevCtrl = NC.TargetDebuffControls[i - 1].control
                ctrlData.control:SetAnchor(TOP, prevCtrl, BOTTOM, 0, spacing)
            end
        else
            -- Динамическое центрирование ряда относительно центра фрейма
            local offsetX = startX + ((i - 1) * (size + spacing))
            ctrlData.control:SetAnchor(TOP, NC.TargetDebuffsFrame, TOP, offsetX, 0)
        end

        ctrlData.icon:SetTexture(debuff.icon)

        if debuff.isPermanent then
            ctrlData.label:SetText("")
            ctrlData.label:SetHidden(true)
            ctrlData.labelBg:SetHidden(true)
        else
            local s = debuff.remain
            local timeStr = ""
            if s <= 0 then
                timeStr = ""
            elseif s >= 60 then
                local mins = math.floor(s / 60)
                local secs = math.floor(s % 60)
                timeStr = string.format("%d:%02d", mins, secs)
            elseif s >= 5 then
                timeStr = string.format("%d", math.ceil(s))
            else
                timeStr = string.format("%.1f", s)
            end

            ctrlData.label:SetText(timeStr)
            ctrlData.label:SetHidden(false)
            ctrlData.labelBg:SetHidden(false)
        end

        if debuff.stackCount > 1 then
            ctrlData.stackLabel:SetText(tostring(debuff.stackCount))
            ctrlData.stackLabel:SetHidden(false)
        else
            ctrlData.stackLabel:SetHidden(true)
        end

        ctrlData.control:SetHidden(false)
    end

    for i = #activeDebuffs + 1, #NC.TargetDebuffControls do
        NC.TargetDebuffControls[i].control:SetHidden(true)
    end
end

function NC.CreateTargetDebuffsUI()
    if NC.TargetDebuffsFrame then return end

    local size = NC.savedVars.targetDebuffsSize or 36

    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_TargetDebuffsFrame")
    frame:SetDimensions(size, size)
    frame:ClearAnchors()
    if NC.savedVars and NC.savedVars.targetDebuffsLeft and NC.savedVars.targetDebuffsTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NC.savedVars.targetDebuffsLeft, NC.savedVars.targetDebuffsTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetMovable(NC.savedVars.targetDebuffsUnlocked)
    frame:SetMouseEnabled(NC.savedVars.targetDebuffsUnlocked)
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)

    -- Полупрозрачная оранжево-красная направляющая для настройки положения
    local preview = WINDOW_MANAGER:CreateControl("$(parent)Preview", frame, CT_BACKDROP)
    preview:SetAnchorFill(frame)
    preview:SetCenterColor(0.4, 0.1, 0, 0.4)
    preview:SetEdgeColor(1, 0.4, 0.1, 0.85)
    preview:SetDrawLayer(DL_BACKGROUND)
    preview:SetHidden(not NC.savedVars.targetDebuffsUnlocked)

    frame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        NC.savedVars.targetDebuffsLeft = self:GetLeft()
        NC.savedVars.targetDebuffsTop = self:GetTop()
    end)

    NC.TargetDebuffsFrame    = frame
    NC.TargetDebuffsPreview  = preview
    NC.TargetDebuffsFragment = ZO_SimpleSceneFragment:New(frame)

    NC.UpdateTargetDebuffsUI()
end

---------------------------------------------------------
-- МОДУЛЬ: НАПОМИНАНИЕ О ЕДЕ И ВОЕННОМ ТОРТЕ
---------------------------------------------------------

-- Надежная проверка физического нахождения в PvP-зонах (Сиродил и Имперский город)
local function IsInTortePvPZone()
    if GetCurrentZoneHouseId and GetCurrentZoneHouseId() ~= 0 then return false end

    local inCyro = (IsPlayerInAvAWorld and IsPlayerInAvAWorld()) and (not IsInImperialCity or not IsInImperialCity())
    local inIC = (IsInImperialCity and IsInImperialCity()) or (IsInImperialCitySewers and IsInImperialCitySewers())

    return inCyro or inIC
end

-- Надежная проверка физического нахождения в боевых локациях для Еды
local function IsInFoodCombatZone()
    -- 1. В любых домах и гильдхоллах ID дома всегда больше 0 — наглухо блокируем
    if GetCurrentZoneHouseId and GetCurrentZoneHouseId() > 0 then 
        return false 
    end

    -- 2. Физические боевые локации (только когда ты стоишь в них прямо сейчас)
    local isDungeon = IsUnitInDungeon and IsUnitInDungeon("player")
    local isRaid = IsRaidInProgress and IsRaidInProgress()
    local isBG = IsActiveWorldBattleground and IsActiveWorldBattleground()
    local isPvP = (IsPlayerInAvAWorld and IsPlayerInAvAWorld()) or (IsInImperialCity and IsInImperialCity())

    local zoneId = GetZoneId and GetZoneId(GetUnitZoneIndex("player"))
    local isTrialOrArena = (zoneId and NC.TrialZoneIds and NC.TrialZoneIds[zoneId] == true)

    return isDungeon or isRaid or isBG or isPvP or isTrialOrArena
end

-- Сканирование наличия активных баффов еды, военного торта и свитков опыта (Международный стандарт)
local function CheckFoodAndTorteBuffs()
    local hasFood = false
    local hasTorte = false
    local hasXPScroll = false
    local numBuffs = GetNumBuffs("player")
    local now = GetFrameTimeSeconds()

    for i = 1, numBuffs do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId = GetUnitBuffInfo("player", i)

        if effectType == BUFF_EFFECT_TYPE_BUFF and iconFilename and iconFilename ~= "" then
            local isPermanent = (timeEnding == 0) or (timeEnding <= timeStarted)
            local totalDuration = isPermanent and 0 or (timeEnding - timeStarted)
            local remain = isPermanent and 0 or (timeEnding - now)
            local cleanIcon = string.lower(iconFilename)

            local lowerName = string.lower(buffName or "")

            local isTorteBuff = (abilityId == 147466 or abilityId == 147467 or abilityId == 147687 or abilityId == 147733 or abilityId == 147734)
                or string.find(lowerName, "военн") or string.find(lowerName, "war")
                or string.find(lowerName, "торт") or string.find(lowerName, "torte")
                or string.find(cleanIcon, "torte")

            local isXPBuff = (abilityId == 66776 or abilityId == 64210 or abilityId == 85501 or abilityId == 85502 or abilityId == 85503 or abilityId == 88445 or abilityId == 89683)
                or string.find(lowerName, "опыт") or string.find(lowerName, "exper")
                or string.find(lowerName, "амброз") or string.find(lowerName, "ambros")
                or string.find(cleanIcon, "experience") or string.find(cleanIcon, "ambrosia") or string.find(cleanIcon, "scroll")

            local isSoulSummons = (abilityId == 43752)
                or string.find(cleanIcon, "soul")
                or string.find(lowerName, "душ")
                or string.find(lowerName, "soul")

            -- 1. Торт (+AP: Коловианский, Расплавленный, Бело-золотой по системным ID и текстуре)
            if isTorteBuff then
                if isPermanent or remain > 0 then
                    hasTorte = true
                end

            -- 2. Свитки опыта и Амброзия (+XP: системные иконки свитков и амброзии, исключая ивенты)
            elseif isXPBuff
               and not string.find(cleanIcon, "cake")
               and not string.find(cleanIcon, "pie")
               and not string.find(cleanIcon, "brew")
               and not string.find(cleanIcon, "event") then
                if isPermanent or remain > 0 then
                    hasXPScroll = true
                end

            -- 3. Настоящая еда/напитки (стандартный тайминг еды в ESO: 30 мин, 1 час, 2 часа)
            elseif not isPermanent and remain > 600 and totalDuration >= 1500 then
                if not isTorteBuff and not isXPBuff and not isSoulSummons
                   and not string.find(cleanIcon, "ability_weapon")
                   and not string.find(cleanIcon, "ability_armor") then
                    hasFood = true
                end
            end
        end
    end

    return hasFood, hasTorte, hasXPScroll
end

function NC.UpdateFoodReminderUI()
    if not NC.FoodReminderFrame or not NC.FoodReminderFragment then return end
    local sv = NC.savedVars
    if not sv then return end

    local canMove = sv.foodReminderUnlocked or sv.foodReminderPreview
    NC.FoodReminderFrame:SetMovable(canMove)
    NC.FoodReminderFrame:SetMouseEnabled(canMove)

    if sv.foodReminderEnabled then
        HUD_SCENE:AddFragment(NC.FoodReminderFragment)
        HUD_UI_SCENE:AddFragment(NC.FoodReminderFragment)
    else
        HUD_SCENE:RemoveFragment(NC.FoodReminderFragment)
        HUD_UI_SCENE:RemoveFragment(NC.FoodReminderFragment)
        NC.FoodReminderFrame:SetHidden(true)
        return
    end

    NC.UpdateFoodReminder()
end

function NC.UpdateFoodReminder()
    if not NC.FoodReminderFrame or not NC.savedVars or not NC.savedVars.foodReminderEnabled then return end

    local sv = NC.savedVars
    local size = sv.foodReminderSize or 48
    local spacing = 8

    local showFood = (sv.foodReminderShowFood ~= false)
    local showTorte = (sv.foodReminderShowTorte ~= false)
    local showXP = (sv.foodReminderShowXP == true)

    -- 1. РЕЖИМ ТЕСТОВОГО ПРЕВЬЮ: показывает только включенные иконки
    if sv.foodReminderPreview then
        if NC.FoodReminderPreview then NC.FoodReminderPreview:SetHidden(false) end

        local previewIcons = {}
        if showFood then table.insert(previewIcons, NC.FoodReminderFoodIcon) end
        if showTorte then table.insert(previewIcons, NC.FoodReminderTorteIcon) end
        if showXP then table.insert(previewIcons, NC.FoodReminderXPIcon) end

        NC.FoodReminderFoodIcon:SetHidden(not showFood)
        NC.FoodReminderTorteIcon:SetHidden(not showTorte)
        NC.FoodReminderXPIcon:SetHidden(not showXP)

        if #previewIcons == 0 then
            NC.FoodReminderFrame:SetHidden(true)
            return
        end

        for i, iconCtrl in ipairs(previewIcons) do
            iconCtrl:SetDimensions(size, size)
            iconCtrl:ClearAnchors()
            if i == 1 then
                iconCtrl:SetAnchor(LEFT, NC.FoodReminderFrame, LEFT, 0, 0)
            else
                iconCtrl:SetAnchor(LEFT, previewIcons[i - 1], RIGHT, spacing, 0)
            end
        end

        local totalWidth = (size * #previewIcons) + (spacing * (#previewIcons - 1))
        NC.FoodReminderFrame:SetDimensions(totalWidth, size)
        NC.FoodReminderFrame:SetHidden(false)
        return
    end

    -- 2. БОЕВОЙ РЕЖИМ: зеленая рамка скрыта
    if NC.FoodReminderPreview then NC.FoodReminderPreview:SetHidden(true) end

    -- Если открыты полноэкранные меню (инвентарь, карта и т.д.) — скрываем
    if not NC.FoodReminderFragment or not NC.FoodReminderFragment:IsShowing() then
        NC.FoodReminderFrame:SetHidden(true)
        return
    end

    local inFoodZone = IsInFoodCombatZone()
    local inTorteZone = IsInTortePvPZone()
    local inCombatZone = inFoodZone or inTorteZone

    if not inCombatZone then
        NC.FoodReminderFrame:SetHidden(true)
        return
    end

    local hasFood, hasTorte, hasXPScroll = CheckFoodAndTorteBuffs()

    local needFoodAlert = inFoodZone and showFood and not hasFood
    local needTorteAlert = inTorteZone and showTorte and not hasTorte
    local needXPAlert = inCombatZone and showXP and not hasXPScroll

    local activeIcons = {}
    if needFoodAlert then table.insert(activeIcons, NC.FoodReminderFoodIcon) end
    if needTorteAlert then table.insert(activeIcons, NC.FoodReminderTorteIcon) end
    if needXPAlert then table.insert(activeIcons, NC.FoodReminderXPIcon) end

    NC.FoodReminderFoodIcon:SetHidden(not needFoodAlert)
    NC.FoodReminderTorteIcon:SetHidden(not needTorteAlert)
    NC.FoodReminderXPIcon:SetHidden(not needXPAlert)

    if #activeIcons == 0 then
        NC.FoodReminderFrame:SetHidden(true)
    else
        for i, iconCtrl in ipairs(activeIcons) do
            iconCtrl:SetDimensions(size, size)
            iconCtrl:ClearAnchors()
            if i == 1 then
                iconCtrl:SetAnchor(LEFT, NC.FoodReminderFrame, LEFT, 0, 0)
            else
                iconCtrl:SetAnchor(LEFT, activeIcons[i - 1], RIGHT, spacing, 0)
            end
        end
        local totalWidth = (size * #activeIcons) + (spacing * (#activeIcons - 1))
        NC.FoodReminderFrame:SetDimensions(totalWidth, size)
        NC.FoodReminderFrame:SetHidden(false)
    end
end

function NC.CreateFoodReminderUI()
    if NC.FoodReminderFrame then return end

    local size = NC.savedVars.foodReminderSize or 48

    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_FoodReminderFrame")
    frame:SetDimensions((size * 3) + 16, size)
    frame:ClearAnchors()
    if NC.savedVars and NC.savedVars.foodReminderLeft and NC.savedVars.foodReminderTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NC.savedVars.foodReminderLeft, NC.savedVars.foodReminderTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetMovable(NC.savedVars.foodReminderUnlocked or NC.savedVars.foodReminderPreview)
    frame:SetMouseEnabled(NC.savedVars.foodReminderUnlocked or NC.savedVars.foodReminderPreview)
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)

    -- Зеленая подложка (видна ТОЛЬКО при тестовом превью)
    local preview = WINDOW_MANAGER:CreateControl("$(parent)Preview", frame, CT_BACKDROP)
    preview:SetAnchorFill(frame)
    preview:SetCenterColor(0, 0.3, 0.1, 0.4)
    preview:SetEdgeColor(0.2, 1, 0.4, 0.85)
    preview:SetDrawLayer(DL_BACKGROUND)
    preview:SetHidden(true)

    local foodIcon = WINDOW_MANAGER:CreateControl("$(parent)Food", frame, CT_TEXTURE)
    foodIcon:SetDimensions(size, size)
    foodIcon:SetTexture("NecroCat/imgs/buffs/food.dds")
    foodIcon:SetDrawLayer(DL_CONTROLS)
    foodIcon:SetHidden(true)

    local torteIcon = WINDOW_MANAGER:CreateControl("$(parent)Torte", frame, CT_TEXTURE)
    torteIcon:SetDimensions(size, size)
    torteIcon:SetTexture("NecroCat/imgs/buffs/torte.dds")
    torteIcon:SetDrawLayer(DL_CONTROLS)
    torteIcon:SetHidden(true)

    local xpIcon = WINDOW_MANAGER:CreateControl("$(parent)XP", frame, CT_TEXTURE)
    xpIcon:SetDimensions(size, size)
    xpIcon:SetTexture("NecroCat/imgs/buffs/xpscroll.dds")
    xpIcon:SetDrawLayer(DL_CONTROLS)
    xpIcon:SetHidden(true)

    frame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        NC.savedVars.foodReminderLeft = self:GetLeft()
        NC.savedVars.foodReminderTop = self:GetTop()
    end)

    NC.FoodReminderFrame     = frame
    NC.FoodReminderPreview   = preview
    NC.FoodReminderFoodIcon  = foodIcon
    NC.FoodReminderTorteIcon = torteIcon
    NC.FoodReminderXPIcon    = xpIcon
    NC.FoodReminderFragment  = ZO_SimpleSceneFragment:New(frame)

    NC.FoodReminderFragment:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_FRAGMENT_SHOWING then
            NC.UpdateFoodReminder()
        elseif newState == SCENE_FRAGMENT_HIDING then
            NC.FoodReminderFrame:SetHidden(true)
        end
    end)

    NC.UpdateFoodReminderUI()
end

---------------------------------------------------------
-- МОДУЛЬ: ВЕТЕРАНСТВО (PVP РАНГ)
---------------------------------------------------------

function NC.UpdateVeterancyUI()
    if not NC.VeterancyFrame or not NC.VeterancyFragment then return end
    local sv = NC.savedVars
    if not sv then return end

    local unlocked = sv.veterancyUnlocked
    local size = sv.veterancySize or 48
    local showSub = (sv.veterancyShowSubText ~= false)

    -- Если нижняя строчка скрыта — высота окна равна строго размеру значка
    if showSub then
        NC.VeterancyFrame:SetDimensions(size + 20, size + 16)
    else
        NC.VeterancyFrame:SetDimensions(size, size)
    end

    NC.VeterancyIcon:SetDimensions(size, size)
    NC.VeterancyFrame:SetMovable(unlocked)
    NC.VeterancyFrame:SetMouseEnabled(true)

    -- Адаптивный шрифт цифры внутри значка
    if size >= 56 then
        NC.VeterancyLabel:SetFont("ZoFontWinH1")
    elseif size >= 42 then
        NC.VeterancyLabel:SetFont("ZoFontWinH2")
    else
        NC.VeterancyLabel:SetFont("ZoFontWinH4")
    end

    if sv.veterancyEnabled then
        HUD_SCENE:AddFragment(NC.VeterancyFragment)
        HUD_UI_SCENE:AddFragment(NC.VeterancyFragment)
    else
        HUD_SCENE:RemoveFragment(NC.VeterancyFragment)
        HUD_UI_SCENE:RemoveFragment(NC.VeterancyFragment)
        NC.VeterancyFrame:SetHidden(true)
        return
    end

    -- Автообновление при открытии окна Полей Сражений
    if BATTLEGROUND_FINDER_KEYBOARD and not NC.bgFinderHooked then
        ZO_PostHook(BATTLEGROUND_FINDER_KEYBOARD, "Refresh", function()
            if NC.UpdateVeterancy then NC.UpdateVeterancy() end
        end)
        NC.bgFinderHooked = true
    end

    -- Мягкое пробуждение через 2 сек после загрузки
    zo_callLater(function()
        if NC.UpdateVeterancy then NC.UpdateVeterancy() end
    end, 2000)

    NC.UpdateVeterancy()
end

function NC.UpdateVeterancy()
    if not NC.VeterancyFrame or not NC.savedVars or not NC.savedVars.veterancyEnabled then return end

    local sv = NC.savedVars
    local showSub = (sv.veterancyShowSubText ~= false)

    -- 1. Защитная проверка ZOS
    local rank = nil
    if GetUnitVeterancyRank then
        rank = GetUnitVeterancyRank("player")
    end

    if not rank or rank <= 0 then
        if not sv.veterancyUnlocked then
            NC.VeterancyFrame:SetHidden(true)
            return
        else
            rank = 1
        end
    end

    -- 2. Прогресс ранга (%) с принудительным обновлением в реальном времени
    local progressVal = 0
    local rankObj = BATTLEGROUND_FINDER_KEYBOARD and BATTLEGROUND_FINDER_KEYBOARD.veterancyRankObject
    if rankObj then
        if rankObj.Refresh then rankObj:Refresh() end
        if rankObj.statusBar and rankObj.statusBar.GetValue then
            progressVal = rankObj.statusBar:GetValue() or 0
        end
    elseif ZO_BattlegroundFinder_KeyboardVeterancyRankXPBar and ZO_BattlegroundFinder_KeyboardVeterancyRankXPBar.GetValue then
        progressVal = ZO_BattlegroundFinder_KeyboardVeterancyRankXPBar:GetValue() or 0
    end
    local pct = progressVal * 100

    -- Железная память: если игра спит после релога, берем последний сохраненный процент
    if pct > 0 then
        sv.veterancyLastPct = pct
    else
        pct = sv.veterancyLastPct or 0
    end

    -- Сброс в 06:00 по МСК
    local todayDate = math.floor((GetTimeStamp() - 10800) / 86400)
    if not sv.veterancyDailyDate or sv.veterancyDailyDate ~= todayDate or not sv.veterancyDailyStartRank or sv.veterancyDailyStartRank == 0 then
        sv.veterancyDailyDate = todayDate
        sv.veterancyDailyStartRank = rank
    end
    local ranksGainedToday = math.max(0, rank - sv.veterancyDailyStartRank)

    -- 4. Вывод реальных живых данных (без фейковых заглушек)
    NC.VeterancyLabel:SetText(tostring(rank))
    NC.VeterancySubLabel:SetText(string.format("|c00FF00+%d|r |cAAAAAA(%.1f%%)|r", ranksGainedToday, pct))
    NC.VeterancySubLabel:SetHidden(not showSub)
    NC.VeterancyFrame:SetHidden(false)

    -- 5. Данные для всплывающей подсказки
    NC.VeterancyFrame.tooltipData = {
        rank   = rank,
        pct    = pct,
        gained = ranksGainedToday,
    }
end

function NC.CreateVeterancyUI()
    if NC.VeterancyFrame then return end

    local sv = NC.savedVars
    local size = (sv and sv.veterancySize) or 48

    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_VeterancyFrame")
    frame:SetDimensions(size + 20, size + 16)
    frame:ClearAnchors()
    if sv and sv.veterancyLeft and sv.veterancyTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.veterancyLeft, sv.veterancyTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetMovable(sv and sv.veterancyUnlocked)
    frame:SetMouseEnabled(true)
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)

    -- Крутой значок 100-го уровня
    local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", frame, CT_TEXTURE)
    icon:SetAnchor(TOP, frame, TOP, 0, 0)
    icon:SetDimensions(size, size)
    icon:SetTexture("EsoUI/Art/Vengeance/ranks/season00/s00_uniquerank_100.dds")
    icon:SetDrawLayer(DL_CONTROLS)

    -- Крупная цифра ранга по центру значка
    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", frame, CT_LABEL)
    label:SetAnchor(CENTER, icon, CENTER, 0, 0)
    label:SetFont("ZoFontWinH2")
    label:SetColor(1, 1, 1, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawLevel(2)

    -- Нижняя строчка: +N (X.X%)
    local subLabel = WINDOW_MANAGER:CreateControl("$(parent)SubLabel", frame, CT_LABEL)
    subLabel:SetAnchor(TOP, icon, BOTTOM, 0, 1)
    subLabel:SetFont("ZoFontGameSmall")
    subLabel:SetColor(1, 1, 1, 1)
    subLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    subLabel:SetDrawLayer(DL_OVERLAY)
    subLabel:SetDrawLevel(2)

    frame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        if NC.savedVars then
            NC.savedVars.veterancyLeft = self:GetLeft()
            NC.savedVars.veterancyTop = self:GetTop()
        end
    end)

    -- Подсказка при наведении мыши
    frame:SetHandler("OnMouseEnter", function(self)
        if NC.savedVars and NC.savedVars.veterancyUnlocked then return end
        local d = self.tooltipData
        if not d then return end

        InitializeTooltip(InformationTooltip, self, TOP, 0, 5)
        InformationTooltip:AddLine(string.format("|c66f2ffВетеранство (PvP): Ранг %d|r", d.rank), "ZoFontWinH4")
        InformationTooltip:AddLine(string.format("Прогресс ранга: |c00FF00%.1f%%|r", d.pct), "ZoFontGame")
        InformationTooltip:AddLine(string.format("Получено за сегодня: |c00FF00+%d|r", d.gained), "ZoFontGameSmall")
    end)
    frame:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

    NC.VeterancyFrame    = frame
    NC.VeterancyIcon     = icon
    NC.VeterancyLabel    = label
    NC.VeterancySubLabel = subLabel
    NC.VeterancyFragment = ZO_SimpleSceneFragment:New(frame)

    NC.UpdateVeterancyUI()
end

---------------------------------------------------------
-- МОДУЛЬ: СУТОЧНЫЙ ТРЕКЕР ВАЛЮТ И ОПЫТА
---------------------------------------------------------

NC.CurrencyEntries = {}

-- Умный подсчет валюты с памятью по всем персонажам аккаунта
local function GetAccountWideCurrency(curtId, curt)
    local sv = NC.savedVars
    if not sv then return 0 end

    -- 1. Чисто аккаунтные валюты (Архивные фортуны, Торговые слитки)
    if curt == (CURT_TRADE_BARS or 9) or curt == (CURT_ARCHIVAL_FORTUNES or 12) then
        return GetCurrencyAmount(curt, CURRENCY_LOCATION_ACCOUNT or 3) or 0
    end

    -- 2. Валюты из карманов персонажей (Золото, AP, Тель-Вар)
    sv.charPockets = sv.charPockets or {}
    local charId = GetCurrentCharacterId()
    sv.charPockets[charId] = sv.charPockets[charId] or {}

    local currentPocket = GetCurrencyAmount(curt, CURRENCY_LOCATION_CHARACTER) or 0

    -- Страховка от ложного дневного плюса при первом входе на нового твинка
    if sv.currencyDailyStarts and sv.currencyDailyStarts[curtId] ~= nil and sv.charPockets[charId][curtId] == nil then
        sv.currencyDailyStarts[curtId] = sv.currencyDailyStarts[curtId] + currentPocket
    end

    sv.charPockets[charId][curtId] = currentPocket

    -- Суммируем карманы всех известных персонажей + Банк
    local total = GetCurrencyAmount(curt, CURRENCY_LOCATION_BANK) or 0
    for _, pockets in pairs(sv.charPockets) do
        total = total + (pockets[curtId] or 0)
    end

    return total
end

-- Умный подсчет планарных ключей со всего аккаунта
local function GetAccountWidePlanarKeys()
    local sv = NC.savedVars
    if not sv then return 0 end

    sv.charPockets = sv.charPockets or {}
    local charId = GetCurrentCharacterId()
    sv.charPockets[charId] = sv.charPockets[charId] or {}

    -- Считаем ключи в рюкзаке текущего персонажа
    local keyId = NC.PLANAR_KEY_ITEM_ID or 224302
    local curKeys = 0
    local bagSize = GetBagSize(BAG_BACKPACK)
    for slotIndex = 0, bagSize do
        if GetItemId(BAG_BACKPACK, slotIndex) == keyId then
            curKeys = curKeys + (GetSlotStackSize(BAG_BACKPACK, slotIndex) or 0)
        end
    end

    -- Страховка от ложного дневного плюса на новом твинке
    if sv.currencyDailyStarts and sv.currencyDailyStarts["planar_keys"] ~= nil and sv.charPockets[charId]["planar_keys"] == nil then
        sv.currencyDailyStarts["planar_keys"] = sv.currencyDailyStarts["planar_keys"] + curKeys
    end

    sv.charPockets[charId]["planar_keys"] = curKeys

    -- Считаем ключи в Банке и Банке ESO Plus
    local bankKeys = 0
    for _, bagId in ipairs({ BAG_BANK, BAG_SUBSCRIBER_BANK }) do
        local bSize = GetBagSize(bagId)
        for slotIndex = 0, bSize do
            if GetItemId(bagId, slotIndex) == keyId then
                bankKeys = bankKeys + (GetSlotStackSize(bagId, slotIndex) or 0)
            end
        end
    end

    -- Суммируем: банк + рюкзаки всех персонажей
    local total = bankKeys
    for _, pockets in pairs(sv.charPockets) do
        total = total + (pockets["planar_keys"] or 0)
    end

    return total
end

local function FormatCurrencyNumber(amount)
    if not amount then return "|cAAAAAA0|r" end
    local isNeg = (amount < 0)
    local raw = tostring(math.abs(amount))
    local formatted = raw:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")

    if isNeg then
        return "|cFF4444-" .. formatted .. "|r"
    elseif amount > 0 then
        return "|c00FF00+" .. formatted .. "|r"
    else
        return "|cAAAAAA0|r"
    end
end

local function IsInArchiveZone()
    local zoneIndex = GetUnitZoneIndex("player")
    local zoneId = GetZoneId(zoneIndex)
    if zoneId == 1438 or zoneId == 1439 then return true end
    local zoneName = string.lower(GetZoneNameById(zoneId) or "")
    return string.find(zoneName, "архив") ~= nil or string.find(zoneName, "archive") ~= nil
end

local function IsInPvPTrackerZone()
    local inCyro = IsPlayerInAvAWorld and IsPlayerInAvAWorld()
    local inIC = (IsInImperialCity and IsInImperialCity()) or (IsInImperialCitySewers and IsInImperialCitySewers())
    local inBG = IsActiveWorldBattleground and IsActiveWorldBattleground()
    return inCyro or inIC or inBG
end

local function GetCurrentRawXP()
    if GetUnitLevel("player") < 50 then
        return GetUnitXP("player") or 0, GetUnitXPMax("player") or 1
    else
        local cpXP = GetPlayerChampionXP and GetPlayerChampionXP() or 0
        local cpMax = (GetChampionXPInStrength and GetChampionXPInStrength()) or (GetUnitXPMax and GetUnitXPMax("player")) or 300000
        return cpXP, cpMax
    end
end

function NC.UpdateCurrencyTrackerUI()
    if not NC.CurrencyTrackerFrame or not NC.CurrencyTrackerFragment then return end
    local sv = NC.savedVars
    if not sv then return end

    NC.CurrencyTrackerFrame:SetMovable(sv.currencyTrackerUnlocked)
    NC.CurrencyTrackerFrame:SetMouseEnabled(sv.currencyTrackerUnlocked)
    if NC.CurrencyTrackerPreview then
        NC.CurrencyTrackerPreview:SetHidden(not sv.currencyTrackerUnlocked)
    end

    if sv.currencyTrackerEnabled then
        HUD_SCENE:AddFragment(NC.CurrencyTrackerFragment)
        HUD_UI_SCENE:AddFragment(NC.CurrencyTrackerFragment)
    else
        HUD_SCENE:RemoveFragment(NC.CurrencyTrackerFragment)
        HUD_UI_SCENE:RemoveFragment(NC.CurrencyTrackerFragment)
        NC.CurrencyTrackerFrame:SetHidden(true)
        return
    end

    NC.UpdateCurrencyTracker()
end

local function GetOrCreateCurrencyControl(index)
    if NC.CurrencyEntries[index] then
        return NC.CurrencyEntries[index]
    end

    local parent = NC.CurrencyTrackerFrame
    local ctrl = WINDOW_MANAGER:CreateControl("NecroCat_CurItem" .. index, parent, CT_CONTROL)
    ctrl:SetDimensions(80, 24)

    local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", ctrl, CT_TEXTURE)
    icon:SetDimensions(20, 20)
    icon:SetAnchor(LEFT, ctrl, LEFT, 0, 0)
    icon:SetDrawLayer(DL_CONTROLS)

    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", ctrl, CT_LABEL)
    label:SetAnchor(LEFT, icon, RIGHT, 4, 0)
    label:SetFont("ZoFontWinH5")
    label:SetColor(1, 1, 1, 1)
    label:SetDrawLayer(DL_OVERLAY)

    local entryData = {
        control = ctrl,
        icon    = icon,
        label   = label,
    }

    NC.CurrencyEntries[index] = entryData
    return entryData
end

function NC.UpdateCurrencyTracker()
    if not NC.CurrencyTrackerFrame or not NC.savedVars or not NC.savedVars.currencyTrackerEnabled then return end
    if not NC.isPlayerActivated then return end -- Ждем полной прогрузки банка и персонажа от сервера!

    local sv = NC.savedVars

    -- Суточный сброс (Daily Reset) в 06:00 МСК (03:00 UTC)
    local todayDate = math.floor((GetTimeStamp() - 10800) / 86400)
    sv.currencyDailyStarts = sv.currencyDailyStarts or {}
    if sv.currencyDailyDate ~= todayDate then
        sv.currencyDailyDate = todayDate
        sv.currencyDailyStarts = {}
    end

    local isContext = sv.currencyTrackerContextOnly
    local inPvP = IsInPvPTrackerZone()
    local inArchive = IsInArchiveZone()

    local activeItems = {}

    -- 1. Режим настройки (показываем пример с системными иконками)
    if sv.currencyTrackerUnlocked then
        local keyLink = string.format("|H1:item:%d:4:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", NC.PLANAR_KEY_ITEM_ID or 224302)
        local keyIcon = GetItemLinkIcon(keyLink) or "EsoUI/Art/Icons/icon_missing.dds"

        activeItems = {
            { icon = GetCurrencyKeyboardIcon(CURT_MONEY), delta = 17188 },
            { icon = GetCurrencyKeyboardIcon(CURT_ALLIANCE_POINTS), delta = 123998 },
            { icon = GetCurrencyKeyboardIcon(CURT_TELVAR_STONES), delta = -4000 },
            { icon = keyIcon, delta = 12 },
            { icon = GetCurrencyKeyboardIcon(CURT_TRADE_BARS or 9), delta = 300 },
            { icon = GetCurrencyKeyboardIcon(CURT_ARCHIVAL_FORTUNES or 12), delta = 5999 },
            { icon = "EsoUI/Art/Icons/icon_experience.dds", delta = 54200 },
        }
    else
        -- 2. Реальный боевой расчет
        local defs = {
            { id = "gold",    curt = CURT_MONEY,                    opt = "currencyShowGold",    pvp = false, arc = false },
            { id = "bars",    curt = CURT_TRADE_BARS or 9,          opt = "currencyShowBars",    pvp = false, arc = false },
            { id = "ap",      curt = CURT_ALLIANCE_POINTS,          opt = "currencyShowAP",      pvp = true,  arc = false },
            { id = "telvar",  curt = CURT_TELVAR_STONES,            opt = "currencyShowTelVar",  pvp = true,  arc = false },
            { id = "archive", curt = CURT_ARCHIVAL_FORTUNES or 12,  opt = "currencyShowArchive", pvp = false, arc = true },
        }

        for _, d in ipairs(defs) do
            if sv[d.opt] ~= false then
                local passesZone = true
                if isContext then
                    if d.pvp and not inPvP then passesZone = false end
                    if d.arc and not inArchive then passesZone = false end
                end

                if passesZone then
                    local currentAmount = GetAccountWideCurrency(d.id, d.curt)
                    if sv.currencyDailyStarts[d.id] == nil then
                        sv.currencyDailyStarts[d.id] = currentAmount
                    end
                    local delta = currentAmount - (sv.currencyDailyStarts[d.id] or currentAmount)
                    local curIcon = GetCurrencyKeyboardIcon(d.curt)
                    table.insert(activeItems, { icon = curIcon, delta = delta })
                end
            end
        end

        -- Планарные ключи за день (всегда на экране)
        if sv.currencyShowPlanarKeys ~= false then
            local currentKeys = GetAccountWidePlanarKeys()
            if sv.currencyDailyStarts["planar_keys"] == nil then
                sv.currencyDailyStarts["planar_keys"] = currentKeys
            end
            local delta = currentKeys - (sv.currencyDailyStarts["planar_keys"] or currentKeys)
            local keyLink = string.format("|H1:item:%d:4:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", NC.PLANAR_KEY_ITEM_ID or 224302)
            local keyIcon = GetItemLinkIcon(keyLink) or "EsoUI/Art/Icons/icon_missing.dds"
            table.insert(activeItems, { icon = keyIcon, delta = delta })
        end
        
        -- Опыт за день (Накопительный безопасный расчет)
        if sv.currencyShowXP ~= false then
            local curXP, maxXP = GetCurrentRawXP()
            sv.currencyDailyStarts["xp_earned"] = sv.currencyDailyStarts["xp_earned"] or 0

            -- Первую точку отсчета просто запоминаем без начисления ложного опыта
            if NC.lastKnownXP == nil then
                NC.lastKnownXP = curXP
                NC.lastKnownMaxXP = maxXP
            else
                if curXP > NC.lastKnownXP then
                    local diff = curXP - NC.lastKnownXP
                    sv.currencyDailyStarts["xp_earned"] = sv.currencyDailyStarts["xp_earned"] + diff
                elseif curXP < NC.lastKnownXP then
                    local lastMax = NC.lastKnownMaxXP or maxXP
                    local diff = math.max(0, (lastMax - NC.lastKnownXP) + curXP)
                    sv.currencyDailyStarts["xp_earned"] = sv.currencyDailyStarts["xp_earned"] + diff
                end
                NC.lastKnownXP = curXP
                NC.lastKnownMaxXP = maxXP
            end

            local totalEarnedXP = sv.currencyDailyStarts["xp_earned"] or 0
            table.insert(activeItems, { icon = "EsoUI/Art/Icons/icon_experience.dds", delta = totalEarnedXP })
        end
    end

    -- Выстраивание в одну горизонтальную строчку
    local currentX = 4
    local spacing = 12

    for i, item in ipairs(activeItems) do
        local ctrlData = GetOrCreateCurrencyControl(i)
        ctrlData.icon:SetTexture(item.icon)
        ctrlData.label:SetText(FormatCurrencyNumber(item.delta))

        local textWidth = ctrlData.label:GetTextWidth()
        local itemWidth = 22 + textWidth + 4

        ctrlData.control:SetDimensions(itemWidth, 24)
        ctrlData.control:ClearAnchors()
        ctrlData.control:SetAnchor(LEFT, NC.CurrencyTrackerFrame, LEFT, currentX, 0)
        ctrlData.control:SetHidden(false)

        currentX = currentX + itemWidth + spacing
    end

    -- Прячем неиспользуемые элементы
    for i = #activeItems + 1, #NC.CurrencyEntries do
        NC.CurrencyEntries[i].control:SetHidden(true)
    end

    local totalWidth = math.max(60, currentX - spacing + 4)
    NC.CurrencyTrackerFrame:SetDimensions(totalWidth, 26)

    -- Если мы не в режиме настройки и открыто полноэкранное меню — скрываем
    if not sv.currencyTrackerUnlocked and NC.CurrencyTrackerFragment and not NC.CurrencyTrackerFragment:IsShowing() then
        NC.CurrencyTrackerFrame:SetHidden(true)
    else
        NC.CurrencyTrackerFrame:SetHidden(#activeItems == 0)
    end
end

function NC.CreateCurrencyTrackerUI()
    if NC.CurrencyTrackerFrame then return end

    local sv = NC.savedVars

    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_CurrencyTrackerFrame")
    frame:SetDimensions(120, 26)
    frame:ClearAnchors()
    if sv and sv.currencyTrackerLeft and sv.currencyTrackerTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.currencyTrackerLeft, sv.currencyTrackerTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetMovable(sv and sv.currencyTrackerUnlocked)
    frame:SetMouseEnabled(sv and sv.currencyTrackerUnlocked)
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)

    -- Полупрозрачная подложка (видна при настройке)
    local preview = WINDOW_MANAGER:CreateControl("$(parent)Preview", frame, CT_BACKDROP)
    preview:SetAnchorFill(frame)
    preview:SetCenterColor(0, 0, 0, 0.45)
    preview:SetEdgeColor(0.2, 0.8, 1, 0.8)
    preview:SetDrawLayer(DL_BACKGROUND)
    preview:SetHidden(not (sv and sv.currencyTrackerUnlocked))

    frame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        if NC.savedVars then
            NC.savedVars.currencyTrackerLeft = self:GetLeft()
            NC.savedVars.currencyTrackerTop = self:GetTop()
        end
    end)

    NC.CurrencyTrackerFrame    = frame
    NC.CurrencyTrackerPreview  = preview
    NC.CurrencyTrackerFragment = ZO_SimpleSceneFragment:New(frame)

    NC.UpdateCurrencyTrackerUI()
end

---------------------------------------------------------
-- МОДУЛЬ: АВТО-ВСКРЫТИЕ ПАЧЕК КОНТЕЙНЕРОВ И КОНВЕРТОВ
---------------------------------------------------------

NC.isUnboxing = false
NC.unboxBagId = nil
NC.unboxSlotIndex = nil
NC.unboxItemLink = nil
NC.unboxRemaining = 0
NC.unboxTotalOpened = 0
NC.unboxCallLaterId = nil

function NC.StopUnboxStack(reason)
    if not NC.isUnboxing then return end
    NC.isUnboxing = false

    if NC.unboxCallLaterId then
        zo_removeCallLater(NC.unboxCallLaterId)
        NC.unboxCallLaterId = nil
    end

    if NC.UnboxFrame then
        NC.UnboxFrame:SetHidden(true)
    end

    if reason == "bag_full" then
        d(GetString(SI_NC_UNBOX_BAG_FULL))
    elseif reason == "stopped" then
        d(GetString(SI_NC_UNBOX_STOPPED))
    elseif reason == "done" then
        d(zo_strformat(GetString(SI_NC_UNBOX_DONE), NC.unboxTotalOpened))
    end

    NC.unboxBagId = nil
    NC.unboxSlotIndex = nil
    NC.unboxItemLink = nil
end

function NC.ProcessUnboxTick()
    if not NC.isUnboxing then return end

    -- 1. Проверка места в сумке (если осталось <= 1 свободного слота — стоп)
    if GetNumBagFreeSlots(BAG_BACKPACK) <= 1 then
        NC.StopUnboxStack("bag_full")
        return
    end

    -- 2. Проверяем, что в слоте все еще тот же предмет
    local currentLink = GetItemLink(NC.unboxBagId, NC.unboxSlotIndex)
    if not currentLink or currentLink == "" or currentLink ~= NC.unboxItemLink then
        NC.StopUnboxStack("done")
        return
    end

    local currentStack = select(1, GetSlotStackSize(NC.unboxBagId, NC.unboxSlotIndex)) or 0
    if currentStack <= 0 then
        NC.StopUnboxStack("done")
        return
    end

    -- 3. Открываем 1 контейнер
    if IsProtectedFunction("UseItem") then
        CallSecureProtected("UseItem", NC.unboxBagId, NC.unboxSlotIndex)
    else
        UseItem(NC.unboxBagId, NC.unboxSlotIndex)
    end
    NC.unboxTotalOpened = NC.unboxTotalOpened + 1

    -- 4. Обновляем счетчик на плашке (показываем честный остаток в сумке)
    if NC.UnboxRemainLabel then
        local remainingAfter = math.max(0, currentStack - 1)
        NC.UnboxRemainLabel:SetText(zo_strformat(GetString(SI_NC_UNBOX_REMAINING), remainingAfter))
    end

    -- 5. Безопасная пауза перед следующим открытием
    local delay = ((NC.savedVars and NC.savedVars.unboxDelay) or 1.8) * 1000
    NC.unboxCallLaterId = zo_callLater(function()
        NC.ProcessUnboxTick()
    end, delay)
end

function NC.StartUnboxStack(bagId, slotIndex)
    if IsUnitInCombat("player") or IsUnitDead("player") then
        d(GetString(SI_NC_LEARN_IN_COMBAT))
        return
    end

    local itemLink = GetItemLink(bagId, slotIndex)
    local stackCount = select(1, GetSlotStackSize(bagId, slotIndex)) or 0
    if not itemLink or itemLink == "" or stackCount <= 1 then return end

    if GetNumBagFreeSlots(BAG_BACKPACK) <= 1 then
        d(GetString(SI_NC_UNBOX_BAG_FULL))
        return
    end

    NC.isUnboxing = true
    NC.unboxBagId = bagId
    NC.unboxSlotIndex = slotIndex
    NC.unboxItemLink = itemLink
    NC.unboxTotalOpened = 0

    if not NC.UnboxFrame then
        NC.CreateUnboxUI()
    end

    local itemName = zo_strformat("<<1>>", GetItemLinkName(itemLink))
    NC.UnboxTitleLabel:SetText(itemName)
    NC.UnboxRemainLabel:SetText(zo_strformat(GetString(SI_NC_UNBOX_REMAINING), stackCount))
    NC.UnboxFrame:SetHidden(false)
    NC.UnboxFrame:BringWindowToTop()

    d(zo_strformat(GetString(SI_NC_UNBOX_START), itemLink, stackCount))

    NC.ProcessUnboxTick()
end

function NC.CreateUnboxUI()
    if NC.UnboxFrame then return end

    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_UnboxFrame")
    frame:SetDimensions(280, 105)
    frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, -120)
    frame:SetMovable(true)
    frame:SetMouseEnabled(true)
    frame:SetClampedToScreen(true)
    frame:SetDrawTier(DT_HIGH)
    frame:SetHidden(true)

    local bg = WINDOW_MANAGER:CreateControl("$(parent)BG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0.05, 0.05, 0.05, 0.95)
    bg:SetEdgeColor(0.2, 0.85, 1, 0.9)
    bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 8, 8)

    local title = WINDOW_MANAGER:CreateControl("$(parent)Title", frame, CT_LABEL)
    title:SetAnchor(TOP, frame, TOP, 0, 10)
    title:SetFont("ZoFontWinH4")
    title:SetColor(0.4, 0.9, 1, 1)
    title:SetMaxLineCount(1)
    title:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    title:SetDimensions(260, 20)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local remain = WINDOW_MANAGER:CreateControl("$(parent)Remain", frame, CT_LABEL)
    remain:SetAnchor(TOP, title, BOTTOM, 0, 4)
    remain:SetFont("ZoFontGame")
    remain:SetColor(1, 1, 1, 1)
    remain:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local stopBtn = WINDOW_MANAGER:CreateControl("$(parent)StopBtn", frame, CT_BUTTON)
    stopBtn:SetDimensions(130, 26)
    stopBtn:SetAnchor(BOTTOM, frame, BOTTOM, 0, -8)
    stopBtn:SetFont("ZoFontWinH4")
    stopBtn:SetText("|cFF5555" .. GetString(SI_NC_UNBOX_FRAME_STOP) .. "|r")
    stopBtn:SetHandler("OnClicked", function()
        NC.StopUnboxStack("stopped")
    end)

    NC.UnboxFrame       = frame
    NC.UnboxTitleLabel  = title
    NC.UnboxRemainLabel = remain
end

-- Хук контекстного меню инвентаря для контейнеров и конвертов
function NC.HookInventoryContextMenu()
    if not LibCustomMenu then return end

    LibCustomMenu:RegisterContextMenu(function(inventorySlot)
        if NC.savedVars and NC.savedVars.autoUnboxEnabled == false then return end
        if not inventorySlot then return end

        local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
        if not bagId or not slotIndex then return end

        local stackCount = select(1, GetSlotStackSize(bagId, slotIndex)) or 0
        if stackCount <= 1 then return end

        local itemType, specializedType = GetItemType(bagId, slotIndex)
        local itemLink = GetItemLink(bagId, slotIndex)

        -- 1. Конверты с отчётами об исследованиях (спец-тип 890 и 300)
        -- 2. Стандартные контейнеры (коробки дейликов, жеоды, сундуки)
        -- 3. Страницы стилей и ивентовые мешки
        local isUnboxable = (specializedType == 890)
                         or (specializedType == 300)
                         or (itemType == ITEMTYPE_CONTAINER)
                         or (specializedType == SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE)
                         or (specializedType == SPECIALIZED_ITEMTYPE_CONTAINER_EVENT)
                         or (IsItemLinkContainer and IsItemLinkContainer(itemLink))
                         or (GetItemLinkItemUseType and GetItemLinkItemUseType(itemLink) == ITEM_USE_TYPE_OPEN_CONTAINER)

        if isUnboxable then
            AddCustomMenuItem(GetString(SI_NC_MENU_UNBOX_STACK), function()
                NC.StartUnboxStack(bagId, slotIndex)
            end)
        end
    end)
end

---------------------------------------------------------
-- МОДУЛЬ: СПИДОМЕТР (ТЕКУЩАЯ СКОРОСТЬ)
---------------------------------------------------------

NC.lastSpeedX, NC.lastSpeedY, NC.lastSpeedZ, NC.lastSpeedTime = 0, 0, 0, 0

function NC.UpdateSpeedometerUI()
    if not NC.SpeedometerFrame or not NC.SpeedometerFragment then return end
    local sv = NC.savedVars
    if not sv then return end

    local unlocked = sv.speedometerUnlocked
    NC.SpeedometerFrame:SetMovable(unlocked)
    NC.SpeedometerFrame:SetMouseEnabled(unlocked)
    if NC.SpeedometerBG then NC.SpeedometerBG:SetHidden(not unlocked) end

    if sv.speedometerEnabled then
        HUD_SCENE:AddFragment(NC.SpeedometerFragment)
        HUD_UI_SCENE:AddFragment(NC.SpeedometerFragment)
    else
        HUD_SCENE:RemoveFragment(NC.SpeedometerFragment)
        HUD_UI_SCENE:RemoveFragment(NC.SpeedometerFragment)
        NC.SpeedometerFrame:SetHidden(true)
        return
    end

    NC.UpdateSpeedometer()
end

function NC.UpdateSpeedometer()
    if not NC.SpeedometerFrame or not NC.savedVars or not NC.savedVars.speedometerEnabled then return end

    local sv = NC.savedVars
    local ICON_SPEED = "|t18:18:EsoUI/Art/Icons/ability_buff_major_expedition.dds|t"

    -- В режиме настройки держим видимым для настройки
    if sv.speedometerUnlocked then
        NC.SpeedometerLabel:SetText(string.format("%s |c66f2ff1330|r", ICON_SPEED))
        NC.SpeedometerFrame:SetHidden(false)
        return
    end

    -- Если открыты меню, инвентарь, карта или диалог — спидометр спит и скрыт
    if not NC.SpeedometerFragment or not NC.SpeedometerFragment:IsShowing() then
        NC.SpeedometerFrame:SetHidden(true)
        return
    end

    -- Проверка фильтра: показывать только на маунте
    if sv.speedometerOnlyMounted and not IsMounted() then
        NC.SpeedometerFrame:SetHidden(true)
        return
    end

    -- Мы на боевом экране HUD и в седле -> включаем видимость!
    NC.SpeedometerFrame:SetHidden(false)

    local now = GetFrameTimeSeconds()
    local _, x, y, z = GetUnitWorldPosition("player")

    if NC.lastSpeedTime and NC.lastSpeedTime > 0 then
        local dt = now - NC.lastSpeedTime
        if dt >= 0.08 then
            local dist = zo_distance3D(NC.lastSpeedX, NC.lastSpeedY, NC.lastSpeedZ, x, y, z)
            local spd = zo_round(dist / dt)

            if spd > 100 then
                NC.SpeedometerLabel:SetText(string.format("%s |c66f2ff%d|r", ICON_SPEED, spd))
            else
                NC.SpeedometerLabel:SetText(string.format("%s |c8888880|r", ICON_SPEED))
            end

            NC.lastSpeedX, NC.lastSpeedY, NC.lastSpeedZ, NC.lastSpeedTime = x, y, z, now
        end
    else
        NC.lastSpeedX, NC.lastSpeedY, NC.lastSpeedZ, NC.lastSpeedTime = x, y, z, now
    end
end

function NC.CreateSpeedometerUI()
    if NC.SpeedometerFrame then return end

    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_SpeedometerFrame")
    frame:SetDimensions(85, 26)
    frame:ClearAnchors()
    if NC.savedVars and NC.savedVars.speedometerLeft and NC.savedVars.speedometerTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NC.savedVars.speedometerLeft, NC.savedVars.speedometerTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetMovable(NC.savedVars.speedometerUnlocked)
    frame:SetMouseEnabled(NC.savedVars.speedometerUnlocked)
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)

    local bg = WINDOW_MANAGER:CreateControl("$(parent)BG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0, 0, 0, 0.4)
    bg:SetEdgeColor(0.2, 0.8, 1, 0.8)
    bg:SetHidden(not NC.savedVars.speedometerUnlocked)

    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", frame, CT_LABEL)
    label:SetAnchor(CENTER, frame, CENTER, 0, 0)
    label:SetFont("ZoFontWinH4")

    frame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        NC.savedVars.speedometerLeft = self:GetLeft()
        NC.savedVars.speedometerTop = self:GetTop()
    end)

    NC.SpeedometerFrame    = frame
    NC.SpeedometerBG       = bg
    NC.SpeedometerLabel    = label
    NC.SpeedometerFragment = ZO_SimpleSceneFragment:New(frame)

    NC.UpdateSpeedometerUI()
end

---------------------------------------------------------
-- МОДУЛЬ: СПИДРАН И РЕЙДОВЫЙ ТАЙМЕР
---------------------------------------------------------

-- Красивое форматирование времени для таймера (ММ:СС или Ч:ММ:СС)
function NC.FormatRaidTimer(seconds)
    if not seconds or seconds < 0 then seconds = 0 end
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, mins, secs)
    else
        return string.format("%02d:%02d", mins, secs)
    end
end

-- Получение целевого времени спидрана для текущей зоны
function NC.GetCurrentSpeedrunTarget()
    local zoneIndex = GetUnitZoneIndex("player")
    local zoneId = GetZoneId(zoneIndex)
    if zoneId and NC.SpeedrunParTimes[zoneId] then
        return NC.SpeedrunParTimes[zoneId]
    end
    -- Для обычных 4-man данжей стандартное время спидрана — 20 минут (1200 сек)
    if IsUnitInDungeon("player") then
        return 1200
    end
    return nil
end

NC.dungeonStartTime = 0
NC.isDungeonTimerActive = false

function NC.UpdateSpeedrunHudUI()
    if not NC.SpeedrunFrame or not NC.SpeedrunFragment then return end
    local sv = NC.savedVars
    if not sv then return end

    local unlocked = sv.speedrunHudUnlocked
    NC.SpeedrunFrame:SetMovable(unlocked)
    NC.SpeedrunFrame:SetMouseEnabled(unlocked)

    if sv.speedrunHudEnabled then
        HUD_SCENE:AddFragment(NC.SpeedrunFragment)
        HUD_UI_SCENE:AddFragment(NC.SpeedrunFragment)
    else
        HUD_SCENE:RemoveFragment(NC.SpeedrunFragment)
        HUD_UI_SCENE:RemoveFragment(NC.SpeedrunFragment)
        NC.SpeedrunFrame:SetHidden(true)
        return
    end

    NC.UpdateSpeedrunHud()
end

function NC.UpdateSpeedrunHud()
    if not NC.SpeedrunFrame or not NC.savedVars or not NC.savedVars.speedrunHudEnabled then return end

    local sv = NC.savedVars
    local isUnlocked = sv.speedrunHudUnlocked
    local ICON_TIME = "|t20:20:esoui/art/miscellaneous/timer_32.dds|t"

    -- Режим настройки: показываем аккуратный тестовый виджет
    if isUnlocked then
        NC.SpeedrunFrame:SetHidden(false)
        NC.SpeedrunTimerLabel:SetText(string.format("%s |c66f2ff14:25|r |cAAAAAA/ 30:00|r", ICON_TIME))
        return
    end

    -- Проверяем, находимся ли мы в данже, триале или арене
    local isInDungeon = IsUnitInDungeon("player")
    local isRaid = (IsRaidInProgress and IsRaidInProgress()) or (GetRaidDuration and GetRaidDuration() > 0)

    if not isInDungeon and not isRaid then
        NC.SpeedrunFrame:SetHidden(true)
        return
    end

    -- Проверка фильтра сложности (только ветеран, если включено)
    if sv.speedrunHudVetOnly then
        local isVet = (GetCurrentZoneDungeonDifficulty and GetCurrentZoneDungeonDifficulty() == DUNGEON_DIFFICULTY_VETERAN) 
                   or (GetGroupDifficulty and GetGroupDifficulty() == DUNGEON_DIFFICULTY_VETERAN)
        if not isVet then
            NC.SpeedrunFrame:SetHidden(true)
            return
        end
    end

    local targetTime = NC.GetCurrentSpeedrunTarget and NC.GetCurrentSpeedrunTarget()
    local elapsed = 0

    if isRaid then
        elapsed = (GetRaidDuration and GetRaidDuration() or 0) / 1000 -- игра отдает миллисекунды
    elseif isInDungeon and sv.dungeonStartTimeStamp and sv.dungeonStartTimeStamp > 0 then
        elapsed = GetTimeStamp() - sv.dungeonStartTimeStamp
    end

    -- Формируем строку времени
    local timeStr = NC.FormatRaidTimer(elapsed)
    local isOvertime = targetTime and (elapsed > targetTime)

    if targetTime then
        local targetStr = NC.FormatRaidTimer(targetTime)
        if isOvertime then
            NC.SpeedrunTimerLabel:SetText(string.format("%s |cFF3333%s|r |c888888/ %s|r", ICON_TIME, timeStr, targetStr))
        else
            NC.SpeedrunTimerLabel:SetText(string.format("%s |c66f2ff%s|r |cAAAAAA/ %s|r", ICON_TIME, timeStr, targetStr))
        end
    else
        NC.SpeedrunTimerLabel:SetText(string.format("%s |c66f2ff%s|r", ICON_TIME, timeStr))
    end

    NC.SpeedrunFrame:SetHidden(false)
end

function NC.CreateSpeedrunHudUI()
    if NC.SpeedrunFrame then return end

    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_SpeedrunFrame")
    frame:SetDimensions(165, 28)
    frame:ClearAnchors()
    if NC.savedVars and NC.savedVars.speedrunHudLeft and NC.savedVars.speedrunHudTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NC.savedVars.speedrunHudLeft, NC.savedVars.speedrunHudTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetMovable(NC.savedVars.speedrunHudUnlocked)
    frame:SetMouseEnabled(NC.savedVars.speedrunHudUnlocked)
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)

    -- Аккуратная темная полупрозрачная полосочка без рамок
    local bg = WINDOW_MANAGER:CreateControl("$(parent)BG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0, 0, 0, 0.55)
    bg:SetEdgeColor(0, 0, 0, 0)

    -- Таймер по центру аккуратной плашки
    local timerLabel = WINDOW_MANAGER:CreateControl("$(parent)Timer", frame, CT_LABEL)
    timerLabel:SetAnchor(CENTER, frame, CENTER, 0, 0)
    timerLabel:SetFont("ZoFontWinH4")

    frame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        NC.savedVars.speedrunHudLeft = self:GetLeft()
        NC.savedVars.speedrunHudTop = self:GetTop()
    end)

    NC.SpeedrunFrame      = frame
    NC.SpeedrunTimerLabel = timerLabel
    NC.SpeedrunFragment   = ZO_SimpleSceneFragment:New(frame)

    NC.UpdateSpeedrunHudUI()
end

-- Автоматическое управление записью логов боя (Encounter Log)
function NC.CheckAutoEncounterLog()
    if not NC.savedVars or not NC.savedVars.autoEncounterLog then return end

    local isInDungeon = IsUnitInDungeon("player")
    local isRaid = (IsRaidInProgress and IsRaidInProgress()) or (GetRaidDuration and GetRaidDuration() > 0)
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    local isTrialZone = (zoneId and NC.TrialZoneIds and NC.TrialZoneIds[zoneId])

    local inCombatZone = isInDungeon or isRaid or isTrialZone

    local isVet = (GetCurrentZoneDungeonDifficulty and GetCurrentZoneDungeonDifficulty() == DUNGEON_DIFFICULTY_VETERAN) 
               or (GetGroupDifficulty and GetGroupDifficulty() == DUNGEON_DIFFICULTY_VETERAN)

    local shouldLog = false
    if inCombatZone then
        if NC.savedVars.autoEncounterLogVetOnly then
            shouldLog = isVet
        else
            shouldLog = true
        end
    end

    local isCurrentlyLogging = IsEncounterLogEnabled()

    if shouldLog and not isCurrentlyLogging then
        SetEncounterLogEnabled(true)
        d(GetString(SI_NC_LOG_ENABLED))
    elseif not shouldLog and isCurrentlyLogging then
        SetEncounterLogEnabled(false)
        d(GetString(SI_NC_LOG_DISABLED))
    end
end

---------------------------------------------------------
-- МОДУЛЬ: СЧЕТЧИК СУНДУКОВ ЗОНЫ / ДАНЖА (УНИВЕРСАЛЬНЫЙ)
---------------------------------------------------------

NC.isLockpickingActive = false
NC.lastLockpickEndTime = 0

local function GetCurrentMainZoneId()
    local zoneIndex = GetUnitZoneIndex("player")
    local zoneId = GetZoneId(zoneIndex)
    local parentZoneId = GetParentZoneId(zoneId)
    return (parentZoneId and parentZoneId > 0) and parentZoneId or zoneId
end

function NC.UpdateChestCounterDisplay()
    if not NC.ChestCounterLabel then return end
    local count = (NC.savedVars and NC.savedVars.currentChestsCount) or 0

    if count > 0 then
        NC.ChestCounterLabel:SetText(tostring(count))
        NC.ChestCounterLabel:SetHidden(false)
    else
        NC.ChestCounterLabel:SetText("")
        NC.ChestCounterLabel:SetHidden(true)
    end
end
function NC.ResetChestCounter()
    if not NC.savedVars then return end
    NC.savedVars.currentChestsCount = 0
    NC.savedVars.openedChestsCoords = {}
    NC.UpdateChestCounterDisplay()
end

function NC.CheckZoneChangeForChestCounter()
    if not NC.savedVars then return end

    local currentZoneId = GetCurrentMainZoneId()
    if not NC.savedVars.lastZoneId or NC.savedVars.lastZoneId ~= currentZoneId then
        NC.savedVars.lastZoneId = currentZoneId
        NC.ResetChestCounter()
    else
        NC.UpdateChestCounterDisplay()
    end
end

function NC.UpdateChestCounterVisibility()
    if not NC.ChestCounterFragment then return end

    if NC.savedVars.showChestCounter then
        HUD_SCENE:AddFragment(NC.ChestCounterFragment)
        HUD_UI_SCENE:AddFragment(NC.ChestCounterFragment)
    else
        HUD_SCENE:RemoveFragment(NC.ChestCounterFragment)
        HUD_UI_SCENE:RemoveFragment(NC.ChestCounterFragment)
        if NC.ChestCounterFrame then NC.ChestCounterFrame:SetHidden(true) end
    end
end

function NC.UpdateChestCounterSize()
    if not NC.ChestCounterFrame then return end

    local size = NC.savedVars.chestSize or 36
    NC.ChestCounterFrame:SetDimensions(size, size)
    NC.ChestCounterIcon:SetDimensions(size, size)

    -- Плавный размер шрифта строго пропорционально размеру иконки
    local fontSize = math.max(10, math.floor(size * 0.42))
    NC.ChestCounterLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", fontSize))

    -- Точный оптический центр замка с масштабированием
    local offsetX = 0
    local offsetY = math.floor(size * 0.14)
    NC.ChestCounterLabel:ClearAnchors()
    NC.ChestCounterLabel:SetAnchor(CENTER, NC.ChestCounterFrame, CENTER, offsetX, offsetY)
end

-- Отслеживаем сцену взлома
local function HookLockpickScenes()
    local scenes = { "lockpickKeyboard", "lockpickGamepad" }
    for _, sceneName in ipairs(scenes) do
        local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(sceneName)
        if scene then
            scene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                    NC.isLockpickingActive = true
                elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                    NC.lastLockpickEndTime = GetFrameTimeSeconds()
                    NC.isLockpickingActive = false
                end
            end)
        end
    end
end

function NC.CreateChestCounterUI()
    if NC.ChestCounterFrame then return end

    local size = NC.savedVars.chestSize or 36

    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_ChestFrame")
    frame:SetDimensions(size, size)
    frame:ClearAnchors()
    if NC.savedVars and NC.savedVars.chestLeft and NC.savedVars.chestTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NC.savedVars.chestLeft, NC.savedVars.chestTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetMovable(true)
    frame:SetMouseEnabled(true)
    frame:SetClampedToScreen(true)
    frame:SetDrawTier(DT_HIGH)
    frame:SetHidden(true)

    -- Иконка сундука
    local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", frame, CT_TEXTURE)
    icon:SetAnchorFill(frame)
    icon:SetTexture("NecroCat/imgs/stuffs/dungeonchest.dds")
    icon:SetDrawLayer(DL_CONTROLS)

-- Текст счетчика идеально посажен на фасад замка сундука
    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", frame, CT_LABEL)
    label:SetColor(1, 1, 1, 1)
    label:SetAnchor(CENTER, frame, CENTER, 0, 10)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawLevel(2)
    label:SetText(tostring(NC.savedVars.currentChestsCount or 0))

    -- Сохранение позиции при перемещении
    frame:SetHandler("OnMoveStop", function(self)
        NC.savedVars.chestLeft = self:GetLeft()
        NC.savedVars.chestTop = self:GetTop()
    end)

    -- Сброс по клику ПКМ
    frame:SetHandler("OnMouseUp", function(self, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then
            NC.ResetChestCounter()
            d(GetString(SI_NC_CHEST_RESET))
        end
    end)

    -- Подсказка
    frame:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, TOP, 0, 5)
        InformationTooltip:AddLine(GetString(SI_NC_TT_CHEST_TITLE), "ZoFontWinH4")
        InformationTooltip:AddLine(zo_strformat(GetString(SI_NC_TT_CHEST_DESC), NC.savedVars.currentChestsCount or 0), "ZoFontGame")
        InformationTooltip:AddLine(GetString(SI_NC_TT_CHEST_RMB), "ZoFontGameSmall")
        InformationTooltip:AddLine(GetString(SI_NC_TT_CHEST_DRAG), "ZoFontGameSmall")
        InformationTooltip:AddLine(GetString(SI_NC_TT_CHEST_AUTORESET), "ZoFontGameSmall")
    end)
    frame:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

    NC.ChestCounterFrame    = frame
    NC.ChestCounterIcon     = icon
    NC.ChestCounterLabel    = label
    NC.ChestCounterFragment = ZO_SimpleSceneFragment:New(frame)

    NC.UpdateChestCounterSize()
    NC.UpdateChestCounterDisplay()
    NC.UpdateChestCounterVisibility()

    HookLockpickScenes()
end

-- Надежный подсчет по координатам
function NC.CountChestAtPlayerPos()
    local _, x, y, z = GetUnitWorldPosition("player")
    NC.savedVars.openedChestsCoords = NC.savedVars.openedChestsCoords or {}

    for _, coord in ipairs(NC.savedVars.openedChestsCoords) do
        if (zo_distance3D(x, y, z, coord.x, coord.y, coord.z) / 100) < 6 then
            return
        end
    end

    table.insert(NC.savedVars.openedChestsCoords, { x = x, y = y, z = z })
    NC.savedVars.currentChestsCount = (NC.savedVars.currentChestsCount or 0) + 1
    NC.UpdateChestCounterDisplay()
    d(zo_strformat(GetString(SI_NC_CHEST_COUNTED), NC.savedVars.currentChestsCount))
end

-- 1. Срабатывает при успешном взломе замка своими руками
function NC.OnLockpickSuccessForChestCounter()
    if not NC.savedVars or not NC.savedVars.showChestCounter then return end
    NC.CountChestAtPlayerPos()
end

-- 2. Срабатывает при открытии уже взломанного или незапертого сундука
function NC.OnClientInteractResultForChestCounter(eventCode, result, interactTargetName)
    if not NC.savedVars or not NC.savedVars.showChestCounter then return end
    if result ~= 0 then return end
    if not interactTargetName or interactTargetName == "" then return end

    -- Если идет взлом (или взлом только что сорвался меньше 2 сек назад) — игнорируем!
    local now = GetFrameTimeSeconds()
    if NC.isLockpickingActive or (now - NC.lastLockpickEndTime < 2) then
        return
    end

    local cleanName = zo_strformat("<<1>>", interactTargetName)
    local lowerName = zo_strlower(cleanName)

    if string.find(lowerName, "сундук") or string.find(lowerName, "chest") or string.find(lowerName, "coffre") or string.find(lowerName, "truhe") then
        NC.CountChestAtPlayerPos()
    end
end

-- 3. Дополнительная страховка через окно лута
function NC.OnLootUpdatedForChestCounter()
    if not NC.savedVars or not NC.savedVars.showChestCounter then return end

    local targetName = GetLootTargetInfo()
    if not targetName or targetName == "" then return end

    local cleanName = zo_strformat("<<1>>", targetName)
    local lowerName = zo_strlower(cleanName)

    if string.find(lowerName, "сундук") or string.find(lowerName, "chest") or string.find(lowerName, "coffre") or string.find(lowerName, "truhe") then
        NC.CountChestAtPlayerPos()
    end
end

---------------------------------------------------------
-- МОДУЛЬ: ВИДЖЕТ ПЛАНАРНЫХ КЛЮЧЕЙ
---------------------------------------------------------

NC.PLANAR_KEY_ITEM_ID = 224302
local PLANAR_KEY_BAGS = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }

-- Функция подсчёта ключей (Сумка + Банк + Банк ESO Plus)
function NC.GetPlanarKeyTotalCount()
    local total = 0
    for _, bagId in ipairs(PLANAR_KEY_BAGS) do
        local bagSize = GetBagSize(bagId)
        for slotIndex = 0, bagSize do
            if GetItemId(bagId, slotIndex) == NC.PLANAR_KEY_ITEM_ID then
                total = total + (GetSlotStackSize(bagId, slotIndex) or 0)
            end
        end
    end
    return total
end

-- Обновление текста на виджете
function NC.UpdatePlanarKeyWidgetDisplay()
    if not NC.PlanarKeyWidgetLabel then return end
    local count = NC.GetPlanarKeyTotalCount()
    NC.PlanarKeyWidgetLabel:SetText(tostring(count))
end

-- Применение размеров, шрифтов, смещения и видимости
function NC.UpdatePlanarKeyWidgetUI()
    if not NC.PlanarKeyWidgetFrame or not NC.PlanarKeyWidgetFragment then return end
    local sv = NC.savedVars
    if not sv then return end

    local size = sv.planarKeyWidgetSize or 56
    local fontSize = sv.planarKeyWidgetFontSize or 26
    local offX = sv.planarKeyWidgetOffsetX or 0
    local offY = sv.planarKeyWidgetOffsetY or 0
    local unlocked = sv.planarKeyWidgetUnlocked or false

    NC.PlanarKeyWidgetFrame:SetDimensions(size, size)
    NC.PlanarKeyWidgetIcon:SetDimensions(size, size)
    NC.PlanarKeyWidgetFrame:SetMovable(unlocked)
    NC.PlanarKeyWidgetFrame:SetMouseEnabled(unlocked)

    -- Применяем смещение X/Y и размер шрифта для цифры
    NC.PlanarKeyWidgetLabel:ClearAnchors()
    NC.PlanarKeyWidgetLabel:SetAnchor(CENTER, NC.PlanarKeyWidgetIcon, CENTER, offX, offY)
    NC.PlanarKeyWidgetLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", fontSize))

    if NC.PlanarKeyWidgetPreview then
        NC.PlanarKeyWidgetPreview:SetHidden(not unlocked)
    end

    if sv.planarKeyWidgetEnabled then
        HUD_SCENE:AddFragment(NC.PlanarKeyWidgetFragment)
        HUD_UI_SCENE:AddFragment(NC.PlanarKeyWidgetFragment)
        NC.UpdatePlanarKeyWidgetDisplay()
    else
        HUD_SCENE:RemoveFragment(NC.PlanarKeyWidgetFragment)
        HUD_UI_SCENE:RemoveFragment(NC.PlanarKeyWidgetFragment)
        NC.PlanarKeyWidgetFrame:SetHidden(true)
    end
end

-- Создание окна виджета
function NC.CreatePlanarKeyWidgetUI()
    if NC.PlanarKeyWidgetFrame then return end

    local sv = NC.savedVars
    local size = (sv and sv.planarKeyWidgetSize) or 56

    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_PlanarKeyFrame")
    frame:SetDimensions(size, size)
    frame:ClearAnchors()
    if sv and sv.planarKeyWidgetLeft and sv.planarKeyWidgetTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.planarKeyWidgetLeft, sv.planarKeyWidgetTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetClampedToScreen(true)
    frame:SetDrawTier(DT_HIGH)
    frame:SetHidden(true)

    -- Подложка-ориентир (видна только когда окно разблокировано для перемещения)
    local preview = WINDOW_MANAGER:CreateControl("$(parent)Preview", frame, CT_BACKDROP)
    preview:SetAnchorFill(frame)
    preview:SetCenterColor(0, 0, 0, 0.4)
    preview:SetEdgeColor(0.2, 0.8, 1, 0.8)
    preview:SetDrawLayer(DL_BACKGROUND)
    preview:SetHidden(not (sv and sv.planarKeyWidgetUnlocked))

    -- Иконка ключа
    local itemLink = string.format("|H1:item:%d:4:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", NC.PLANAR_KEY_ITEM_ID)
    local iconTexture = GetItemLinkIcon(itemLink) or "EsoUI/Art/Icons/icon_missing.dds"

    local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", frame, CT_TEXTURE)
    icon:SetAnchorFill(frame)
    icon:SetTexture(iconTexture)
    icon:SetDrawLayer(DL_CONTROLS)

    -- Цифра счетчика
    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", frame, CT_LABEL)
    label:SetColor(1, 1, 1, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawLevel(2)

    frame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        if NC.savedVars then
            NC.savedVars.planarKeyWidgetLeft = self:GetLeft()
            NC.savedVars.planarKeyWidgetTop  = self:GetTop()
        end
    end)

    NC.PlanarKeyWidgetFrame    = frame
    NC.PlanarKeyWidgetPreview  = preview
    NC.PlanarKeyWidgetIcon     = icon
    NC.PlanarKeyWidgetLabel    = label
    NC.PlanarKeyWidgetFragment = ZO_SimpleSceneFragment:New(frame)

    NC.UpdatePlanarKeyWidgetUI()
end

---------------------------------------------------------
-- МОДУЛЬ: УМНАЯ КАМЕРА (МИР И БОЙ)
---------------------------------------------------------

-- Применение пресета к движку игры
function NC.ApplyCameraPreset(presetKey, isForced)
    if not NC.savedVars then return end
    if not isForced and not NC.savedVars.cameraSwitcherEnabled then return end

    local data = NC.savedVars[presetKey]
    if not data then return end

    SetSetting(2, 9,  string.format("%.6f", data.horizPos or 0))
    SetSetting(2, 10, string.format("%.6f", data.horizOffset or 0))
    SetSetting(2, 11, string.format("%.6f", data.vertOffset or 0))
    SetSetting(2, 12, string.format("%.6f", data.fov or 50))
end

-- Захват текущих настроек из игры в выбранный пресет
function NC.CaptureCameraPreset(presetKey)
    if not NC.savedVars then return end

    local curHorizPos    = tonumber(GetSetting(2, 9)) or 0
    local curHorizOffset = tonumber(GetSetting(2, 10)) or 0
    local curVertOffset  = tonumber(GetSetting(2, 11)) or 0
    local curFov         = tonumber(GetSetting(2, 12)) or 50

    NC.savedVars[presetKey] = {
        horizPos    = curHorizPos,
        horizOffset = curHorizOffset,
        vertOffset  = curVertOffset,
        fov         = curFov,
    }

    local name = (presetKey == "cameraInCombat") and GetString(SI_NC_CAM_PRESET_COMBAT) or GetString(SI_NC_CAM_PRESET_OUT)
    d(zo_strformat(GetString(SI_NC_CAM_SAVED), name))
    return NC.savedVars[presetKey]
end

-- Реакция на смену боя / мира
function NC.OnCameraCombatStateChanged(inCombat)
    if not NC.savedVars or not NC.savedVars.cameraSwitcherEnabled then return end
    if inCombat then
        NC.ApplyCameraPreset("cameraInCombat", false)
    else
        NC.ApplyCameraPreset("cameraOutCombat", false)
    end
end

---------------------------------------------------------
-- МОДУЛЬ: УМНЫЙ ФИЛЬТР ИСТОРИИ ЛУТА
---------------------------------------------------------

local RAW_CRAFTING_TYPES = {}
local TRAIT_STYLE_TYPES  = {}

-- Безопасное добавление типов без риска получить table index is nil
local function RegisterItemType(targetTable, constValue)
    if constValue and type(constValue) == "number" then
        targetTable[constValue] = true
    end
end

-- 1. Ресурсы сбора и материалы ремесла
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_BLACKSMITHING_RAW_MATERIAL)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_BLACKSMITHING_MATERIAL)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_CLOTHIER_RAW_MATERIAL)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_CLOTHIER_MATERIAL)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_WOODWORKING_RAW_MATERIAL)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_WOODWORKING_MATERIAL)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_JEWELRYCRAFTING_MATERIAL)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_REAGENT)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_POTION_BASE)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_POISON_BASE)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_INGREDIENT)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_ENCHANTING_RUNE_POTENCY)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_ENCHANTING_RUNE_ASPECT)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_ENCHANTING_RUNE_ESSENCE)
RegisterItemType(RAW_CRAFTING_TYPES, ITEMTYPE_FURNISHING_MATERIAL)

-- 2. Камни стилей и особенностей (трейтов)
RegisterItemType(TRAIT_STYLE_TYPES, ITEMTYPE_STYLE_MATERIAL)
RegisterItemType(TRAIT_STYLE_TYPES, ITEMTYPE_RAW_STYLE_MATERIAL)
RegisterItemType(TRAIT_STYLE_TYPES, ITEMTYPE_ARMOR_TRAIT)
RegisterItemType(TRAIT_STYLE_TYPES, ITEMTYPE_WEAPON_TRAIT)
RegisterItemType(TRAIT_STYLE_TYPES, ITEMTYPE_JEWELRY_TRAIT)
RegisterItemType(TRAIT_STYLE_TYPES, ITEMTYPE_JEWELRY_RAW_TRAIT)

-- Проверка: нужно ли заглушить предмет
function NC.ShouldHideLootItem(link)
    if not NC.savedVars or not NC.savedVars.lootFilterEnabled then return false end
    if not link or type(link) ~= "string" or not string.find(link, "^|H") then return false end

    local sv = NC.savedVars
    local quality = GetItemLinkQuality(link) or 1
    local itemType, specializedItemType = GetItemLinkItemType(link)

    -- 1. СТРАХОВКА: Рецепты, мотивы и страницы стилей показываем ВСЕГДА
    if sv.lootFilterAlwaysRecipes then
        if itemType == ITEMTYPE_RECIPE 
           or itemType == ITEMTYPE_RACIAL_STYLE_MOTIF
           or specializedItemType == SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER
           or specializedItemType == SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_BOOK
           or specializedItemType == SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE
           or specializedItemType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE then
            return false
        end
    end

    -- 2. СТРАХОВКА: Редкие материалы и заточки (фиолетовые 4 и золотые 5: Воск, Розиум, Темперинг)
    if sv.lootFilterAlwaysRare and quality >= 4 then
        return false
    end

    -- 3. СЕРЫЙ МУСОР (Качество 0: кишки, кости, панцири, хлам)
    if sv.lootFilterHideTrash then
        if quality == 0 or itemType == ITEMTYPE_TRASH then
            return true -- Глушим!
        end
    end

    -- 4. РЕСУРСЫ СБОРА И СЫРЬЕ (Руда, дерево, ткань, травы, ингредиенты еды)
    if sv.lootFilterHideMaterials then
        if RAW_CRAFTING_TYPES[itemType] or (GetItemLinkCraftingSkillType and GetItemLinkCraftingSkillType(link) > 0) then
            return true -- Глушим!
        end
    end

    -- 5. КАМНИ СТИЛЕЙ И ТРЕЙТОВ
    if sv.lootFilterHideTraits and TRAIT_STYLE_TYPES[itemType] then
        return true -- Глушим!
    end

    -- 6. МИНИМАЛЬНЫЙ ПОРОГ КАЧЕСТВА (2: Зеленый+, 3: Синий+, 4: Фиолет+, 5: Золото)
    local minQual = sv.lootFilterMinQuality or 0
    if minQual > 0 and quality < minQual then
        return true -- Глушим всё, что ниже порога!
    end

    return false
end

-- Хук системной истории лута ESO (Только чистая фильтрация)
local function HookLootHistoryFilter()
    if not ZO_LootHistory_Shared then return end
    ZO_PreHook(ZO_LootHistory_Shared, "OnNewItemReceived", function(self, itemLinkOrName)
        if NC.ShouldHideLootItem and NC.ShouldHideLootItem(itemLinkOrName) then
            return true -- Наглухо блокируем всплывание мусора!
        end
    end)
end

NC.GuildIcons = {
    [839248] = "NecroCat/imgs/fons/CastleofNecroCat.dds",
    [698160] = "NecroCat/imgs/fons/garden.dds",
    [766278] = "NecroCat/imgs/fons/gym.dds", 
}


-- [NEW MODULE] Guild Bank Switcher UI (с поддержкой нашего порядка)
function NC.UpdateGuildBankButtons()
    if not NC.BankFrame then return end

    local sortedGuilds = NC.GetSortedGuildList()
    local numGuilds = #sortedGuilds

    for i = 1, 5 do
        local btn = NC.BankFrame.buttons and NC.BankFrame.buttons[i]
        if not btn then
            NC.BankFrame.buttons = NC.BankFrame.buttons or {}
            btn = WINDOW_MANAGER:CreateControl("NecroCat_BankBtn" .. i, NC.BankFrame, CT_BUTTON)
            btn:SetDimensions(30, 30)
            btn:SetAnchor(LEFT, NC.BankFrame, LEFT, 5 + ((i - 1) * 35), 0)
            NC.BankFrame.buttons[i] = btn
        end

        local gData = sortedGuilds[i]
        if gData then
            local gid = gData.guildId
            local customIcon = NC.GuildIcons[gid]

            if customIcon then
                btn:SetNormalTexture(customIcon)
                btn:SetMouseOverTexture(customIcon)
            else
                btn:SetNormalTexture("EsoUI/Art/Buttons/pointsplus_up.dds")
                btn:SetMouseOverTexture("EsoUI/Art/Buttons/pointsplus_over.dds")
            end

            btn:SetHandler("OnClicked", function()
                ZO_SharedInventory_SelectAccessibleGuildBank(gid)
            end)

            btn:SetHandler("OnMouseEnter", function(ctrl)
                InitializeTooltip(InformationTooltip, ctrl, TOP, 0, 5)
                SetTooltipText(InformationTooltip, gData.guildName)
            end)

            btn:SetHandler("OnMouseExit", function() 
                ClearTooltip(InformationTooltip) 
            end)

            btn:SetHidden(false)
        else
            btn:SetHidden(true)
        end
    end

    NC.BankFrame:SetWidth(10 + (numGuilds * 35))
end

---------------------------------------------------------
-- МОДУЛЬ: ЦВЕТ КАЧЕСТВА И ПРОЧНОСТЬ НА ЭКРАНЕ ПЕРСОНАЖА (C)
---------------------------------------------------------

local GEAR_SLOTS = {
    [EQUIP_SLOT_HEAD]           = ZO_CharacterEquipmentSlotsHead,
    [EQUIP_SLOT_NECK]           = ZO_CharacterEquipmentSlotsNeck,
    [EQUIP_SLOT_CHEST]          = ZO_CharacterEquipmentSlotsChest,
    [EQUIP_SLOT_SHOULDERS]      = ZO_CharacterEquipmentSlotsShoulder,
    [EQUIP_SLOT_MAIN_HAND]      = ZO_CharacterEquipmentSlotsMainHand,
    [EQUIP_SLOT_OFF_HAND]       = ZO_CharacterEquipmentSlotsOffHand,
    [EQUIP_SLOT_POISON]         = ZO_CharacterEquipmentSlotsPoison,
    [EQUIP_SLOT_WAIST]          = ZO_CharacterEquipmentSlotsBelt,
    [EQUIP_SLOT_LEGS]           = ZO_CharacterEquipmentSlotsLeg,
    [EQUIP_SLOT_FEET]           = ZO_CharacterEquipmentSlotsFoot,
    [EQUIP_SLOT_COSTUME]        = ZO_CharacterEquipmentSlotsCostume,
    [EQUIP_SLOT_RING1]          = ZO_CharacterEquipmentSlotsRing1,
    [EQUIP_SLOT_RING2]          = ZO_CharacterEquipmentSlotsRing2,
    [EQUIP_SLOT_HAND]           = ZO_CharacterEquipmentSlotsGlove,
    [EQUIP_SLOT_BACKUP_MAIN]    = ZO_CharacterEquipmentSlotsBackupMain,
    [EQUIP_SLOT_BACKUP_OFF]     = ZO_CharacterEquipmentSlotsBackupOff,
    [EQUIP_SLOT_BACKUP_POISON]  = ZO_CharacterEquipmentSlotsBackupPoison,
}

local function GetDurabilityColor(val, a)
    local r, g
    if val > 100 then val = 100 end

    if val >= 50 then
        r = 100 - ((val - 50) * 2)
        g = 100
    else
        r = 100
        g = val * 2
    end

    return r / 100, g / 100, 0, a or 0.95
end

function NC.UpdateCharacterSlotGear(slot)
    if slot == EQUIP_SLOT_COSTUME then return end

    local t = _G["NecroCat_GearBg" .. slot]
    local l = _G["NecroCat_GearLabel" .. slot]
    if not t or not l then return end

    local p = t:GetParent()
    if not p then return end

    p:SetMouseOverTexture(not ZO_Character_IsReadOnly() and "NecroCat/imgs/gear/mo.dds" or nil)
    p:SetPressedMouseOverTexture(not ZO_Character_IsReadOnly() and "NecroCat/imgs/gear/mo.dds" or nil)

    local s = p:GetNamedChild("DropCallout")
    if s then
        s:ClearAnchors()
        s:SetAnchor(TOPLEFT, p, TOPLEFT, 0, 2)
        s:SetDimensions(52, 52)
        s:SetTexture("NecroCat/imgs/gear/spot.dds")
        s:SetDrawLayer(0)
    end

    s = p:GetNamedChild("Highlight")
    if s then
        s:ClearAnchors()
        s:SetAnchor(TOPLEFT, p, TOPLEFT, 0, 2)
        s:SetDimensions(52, 52)
        s:SetTexture("NecroCat/imgs/gear/spot.dds")
    end

    if not NC.savedVars.showGearStatus then
        t:SetHidden(true)
        l:SetHidden(true)
        return
    end

    if GetItemInstanceId(BAG_WORN, slot) then
        local itemLink = GetItemLink(BAG_WORN, slot)

        t:SetHidden(false)
        t:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, GetItemLinkDisplayQuality(itemLink)))

        local hasDurability = (DoesItemHaveDurability and DoesItemHaveDurability(BAG_WORN, slot)) or (GetItemType(BAG_WORN, slot) == ITEMTYPE_ARMOR)
        
        if hasDurability and (slot ~= EQUIP_SLOT_NECK and slot ~= EQUIP_SLOT_RING1 and slot ~= EQUIP_SLOT_RING2) then
            local con = GetItemLinkCondition(itemLink)
            l:SetText(con .. "%")
            l:SetColor(GetDurabilityColor(con, 0.95))
            l:SetHidden(false)
        elseif DoesItemLinkHaveEnchantCharges and DoesItemLinkHaveEnchantCharges(itemLink) then
            local maxC = GetItemLinkMaxEnchantCharges(itemLink)
            if maxC and maxC > 0 then
                local con = (GetItemLinkNumEnchantCharges(itemLink) / maxC) * 100
                l:SetText(zo_round(con) .. "%")
                l:SetColor(GetDurabilityColor(con, 0.95))
                l:SetHidden(false)
            else
                l:SetHidden(true)
            end
        else
            l:SetHidden(true)
        end
    else
        t:SetHidden(true)
        l:SetHidden(true)
    end
end

function NC.InitCharacterGearUI()
    if NC.gearUIInitialized then return end

    for slotId, slotControl in pairs(GEAR_SLOTS) do
        if slotControl then
            local s = WINDOW_MANAGER:CreateControl("NecroCat_GearBg" .. slotId, slotControl, CT_TEXTURE)
            s:SetHidden(true)
            s:SetDrawLevel(1)
            s:SetTexture("NecroCat/imgs/gear/hole.dds")
            s:SetAnchorFill()

            local l = WINDOW_MANAGER:CreateControl("NecroCat_GearLabel" .. slotId, slotControl, CT_LABEL)
            l:SetFont("ZoFontGameBold")
            l:SetAnchor(TOPRIGHT, slotControl, TOPRIGHT, 7, -8)
            l:SetDimensions(50, 14)
            l:SetHidden(true)
            l:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        end
    end

    NC.gearUIInitialized = true
end

function NC.UpdateAllCharacterGear()
    if not NC.gearUIInitialized then
        NC.InitCharacterGearUI()
    end

    for slotId in pairs(GEAR_SLOTS) do
        NC.UpdateCharacterSlotGear(slotId)
    end
end

function NC.CreateGuildBankUI()
    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_BankFrame")
    frame:SetDimensions(200, 40)
    frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NC.savedVars.guildBankLeft, NC.savedVars.guildBankTop)
    frame:SetMovable(true)
    frame:SetMouseEnabled(true)
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)
    frame:SetHandler("OnMoveStop", function(self)
        NC.savedVars.guildBankLeft = self:GetLeft()
        NC.savedVars.guildBankTop = self:GetTop()
    end)

    local bg = WINDOW_MANAGER:CreateControl("NecroCat_BankBG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0, 0, 0, 0.5)
    bg:SetEdgeColor(0, 0, 0, 0.5)

    NC.BankFrame = frame
    NC.UpdateGuildBankButtons()
end

function NC.CreateDifficultyUI()
    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_DifficultyFrame")
    frame:SetDimensions(400, 50)
    frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 200)
    frame:SetHidden(true)
    local label = WINDOW_MANAGER:CreateControl("NecroCat_DifficultyLabel", frame, CT_LABEL)
    label:SetAnchorFill(frame)
    label:SetFont("ZoFontWinH2")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    NC.DifficultyFrame = frame
    NC.DifficultyLabel = label
end

-- Создание переключателя "Автоприем" и кнопки "Кик чужих" в меню группы (P)
function NC.CreateGroupMenuAutoAcceptUI()
    local parent = ZO_SearchingForGroupStatus and ZO_SearchingForGroupStatus:GetParent() or ZO_GroupMenu_Keyboard_TopLevel
    if not parent then return end

    local check = CreateControlFromVirtual("NecroCat_AutoAcceptDungeonCheck", parent, "ZO_CheckButton")
    if check then
        check:ClearAnchors()
        if ZO_SearchingForGroupStatus then
            check:SetAnchor(BOTTOMLEFT, ZO_SearchingForGroupStatus, TOPLEFT, 0, -25)
        else
            check:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 20, -90)
        end

        check:SetDrawTier(DT_HIGH)
        check:SetHidden(not NC.savedVars.showAutoAcceptButton)

        ZO_CheckButton_SetLabelText(check, "|c66f2ff" .. GetString(SI_NC_GROUP_AUTO_ACCEPT) .. "|r")
        ZO_CheckButton_SetCheckState(check, NC.savedVars.autoAcceptDungeon)

        ZO_CheckButton_SetToggleFunction(check, function(control, isChecked)
            NC.savedVars.autoAcceptDungeon = isChecked
        end)

        NC.AutoAcceptDungeonCheck = check
    end

    -- Кнопка быстрой очистки группы от рандомов
    local kickBtn = CreateControlFromVirtual("NecroCat_KickRandomsBtn", parent, "ZO_DefaultButton")
    if kickBtn then
        kickBtn:SetDimensions(130, 26)
        if check then
            kickBtn:SetAnchor(LEFT, check, RIGHT, 110, 0)
        else
            kickBtn:SetAnchor(BOTTOMLEFT, parent, BOTTOMLEFT, 150, -90)
        end
        kickBtn:SetText("|cFF5555" .. GetString(SI_NC_GROUP_KICK_RANDOM) .. "|r")
        kickBtn:SetDrawTier(DT_HIGH)
        kickBtn:SetHidden(NC.savedVars and NC.savedVars.showKickRandomsButton == false)

        kickBtn:SetHandler("OnClicked", function()
            NC.KickNonFavorites()
        end)

        kickBtn:SetHandler("OnMouseEnter", function(self)
            InitializeTooltip(InformationTooltip, self, TOP, 0, 5)
            InformationTooltip:AddLine(GetString(SI_NC_TT_KICK_TITLE), "ZoFontWinH4")
            InformationTooltip:AddLine(GetString(SI_NC_TT_KICK_DESC), "ZoFontGameSmall")
        end)
        kickBtn:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

        NC.KickRandomsBtn = kickBtn
    end
end

-- [NEW MODULE] Плавающая иконка изучения рецептов (Инвентарь и Банки)
function NC.UpdateRecipeButtonVisibility()
    if not NC.RecipeFragment then return end
    if NC.savedVars.showRecipeButton then
        -- Добавляем фрагмент в сцены
        SCENE_MANAGER:GetScene("inventory"):AddFragment(NC.RecipeFragment)
        SCENE_MANAGER:GetScene("bank"):AddFragment(NC.RecipeFragment)
        SCENE_MANAGER:GetScene("guildBank"):AddFragment(NC.RecipeFragment)
        SCENE_MANAGER:GetScene("houseBank"):AddFragment(NC.RecipeFragment)
    else
        -- Убираем фрагмент из сцен
        SCENE_MANAGER:GetScene("inventory"):RemoveFragment(NC.RecipeFragment)
        SCENE_MANAGER:GetScene("bank"):RemoveFragment(NC.RecipeFragment)
        SCENE_MANAGER:GetScene("guildBank"):RemoveFragment(NC.RecipeFragment)
        SCENE_MANAGER:GetScene("houseBank"):RemoveFragment(NC.RecipeFragment)
    end
end

function NC.CreateRecipeLearnerUI()
    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_RecipeFrame")
    frame:SetDimensions(36, 36)
    frame:ClearAnchors()
    if NC.savedVars and NC.savedVars.recipeButtonLeft and NC.savedVars.recipeButtonTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NC.savedVars.recipeButtonLeft, NC.savedVars.recipeButtonTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetMovable(true)
    frame:SetMouseEnabled(true)
    frame:SetClampedToScreen(true)
    frame:SetDrawTier(DT_HIGH)
    frame:SetDrawLayer(DL_OVERLAY)
    frame:SetHidden(true)

    -- Иконка книги
    local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", frame, CT_TEXTURE)
    icon:SetAnchorFill(frame)
    icon:SetTexture("EsoUI/Art/MainMenu/menuBar_journal_up.dds")

    -- Подсветка при наведении
    local highlight = WINDOW_MANAGER:CreateControl("$(parent)Highlight", frame, CT_TEXTURE)
    highlight:SetAnchorFill(frame)
    highlight:SetTexture("EsoUI/Art/MainMenu/menuBar_journal_over.dds")
    highlight:SetHidden(true)

    -- Перетаскивание: движок ESO сам перемещает окно
    frame:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        NC.savedVars.recipeButtonLeft = self:GetLeft()
        NC.savedVars.recipeButtonTop = self:GetTop()
    end)

    -- Фиксируем начальную точку клика
    local startX, startY = 0, 0
    frame:SetHandler("OnMouseDown", function(self, button)
        startX, startY = self:GetLeft(), self:GetTop()
    end)

    -- Если отпустили на том же месте — это клик (изучаем). Если сдвинули — это перетаскивание!
    frame:SetHandler("OnMouseUp", function(self, button, upInside)
        if upInside then
            local endX, endY = self:GetLeft(), self:GetTop()
            if math.abs(endX - startX) < 5 and math.abs(endY - startY) < 5 then
                NC.LearnAllUnknownKnowledge()
            end
        end
    end)

    frame:SetHandler("OnMouseEnter", function(self)
        highlight:SetHidden(false)
        local count = #NC.GetUnknownKnowledgeItems()
        InitializeTooltip(InformationTooltip, self, TOP, 0, 5)
        InformationTooltip:AddLine(GetString(SI_NC_TT_RECIPE_TITLE), "ZoFontWinH4")
        InformationTooltip:AddLine(zo_strformat(GetString(SI_NC_TT_RECIPE_COUNT), count), "ZoFontGame")
        InformationTooltip:AddLine(GetString(SI_NC_TT_RECIPE_CLICK), "ZoFontGameSmall")
        InformationTooltip:AddLine(GetString(SI_NC_TT_CHEST_DRAG), "ZoFontGameSmall")
    end)

    frame:SetHandler("OnMouseExit", function(self)
        highlight:SetHidden(true)
        ClearTooltip(InformationTooltip)
    end)

    NC.RecipeFrame = frame
    NC.RecipeFragment = ZO_SimpleSceneFragment:New(frame)

    NC.UpdateRecipeButtonVisibility()
end

function NC.ShowFriendNotification(displayName)
    if not NC.FriendNotificationFrame then return end
    
    local now = GetFrameTimeSeconds()
    NC.lastNotificationTime = NC.lastNotificationTime or {}
    if NC.lastNotificationTime[displayName] and (now - NC.lastNotificationTime[displayName] < 2) then 
        return 
    end
    NC.lastNotificationTime[displayName] = now 
    
    NC.FriendNotificationLabel:SetText(zo_strformat(GetString(SI_NC_FRIEND_ONLINE), displayName))
    NC.FriendNotificationFrame:SetHidden(false)
    PlaySound("Quest_Complete")
    zo_callLater(function() if NC.FriendNotificationFrame then NC.FriendNotificationFrame:SetHidden(true) end end, 5000)
end

function NC.ShowDifficultyStatus(text)
    if not NC.DifficultyFrame then return end
    NC.DifficultyLabel:SetText(text)
    NC.DifficultyFrame:SetHidden(false)
    zo_callLater(function() if NC.DifficultyFrame then NC.DifficultyFrame:SetHidden(true) end end, 10000)
end

function NC.UpdateFriendUI()
    if not NC.FriendNotificationFrame then return end
    local locked = NC.savedVars.friendNotificationLocked
    NC.FriendNotificationFrame:SetMovable(not locked)
    NC.FriendNotificationFrame:SetMouseEnabled(not locked)
    NC.FriendNotificationFrame:SetHidden(locked)
    NC.FriendNotificationBG:SetCenterColor(0, 0, 0, locked and 0 or 0.5)
    if not locked then NC.FriendNotificationLabel:SetText(GetString(SI_NC_DRAG_FRIEND_FRAME)) end
end

local function CreateFriendNotificationUI()
    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_FriendFrame")
    frame:SetDimensions(500, 60)
    frame:ClearAnchors()
    if NC.savedVars and NC.savedVars.friendNotificationLeft and NC.savedVars.friendNotificationTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NC.savedVars.friendNotificationLeft, NC.savedVars.friendNotificationTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)
    frame:SetHandler("OnMoveStop", function(self)
        NC.savedVars.friendNotificationLeft = self:GetLeft()
        NC.savedVars.friendNotificationTop = self:GetTop()
    end)

    local bg = WINDOW_MANAGER:CreateControl("NecroCat_FriendBG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0, 0, 0, 0)
    bg:SetEdgeColor(0, 0, 0, 0)

    local label = WINDOW_MANAGER:CreateControl("NecroCat_FriendLabel", frame, CT_LABEL)
    label:SetAnchor(CENTER, frame, CENTER, 0, 0)
    label:SetFont("ZoFontWinH1")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    NC.FriendNotificationFrame = frame
    NC.FriendNotificationLabel = label
    NC.FriendNotificationBG    = bg
end

function NC.UpdateWhisperUI()
    if not NC.WhisperFrame then return end
    local locked = NC.savedVars.whisperLocked
    NC.WhisperFrame:SetMovable(not locked)
    NC.WhisperFrame:SetMouseEnabled(not locked)
    NC.WhisperFrame:SetHidden(locked)
    NC.WhisperBG:SetCenterColor(0, 0, 0, locked and 0 or 0.5)
    if not locked then NC.WhisperLabel:SetText(GetString(SI_NC_DRAG_WHISPER_FRAME)) end
end

local function CreateWhisperUI()
    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_WhisperFrame")
    frame:SetDimensions(500, 60)
    frame:ClearAnchors()
    if NC.savedVars and NC.savedVars.whisperLeft and NC.savedVars.whisperTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NC.savedVars.whisperLeft, NC.savedVars.whisperTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetClampedToScreen(true)
    frame:SetHandler("OnMoveStop", function(self)
        NC.savedVars.whisperLeft = self:GetLeft()
        NC.savedVars.whisperTop = self:GetTop()
    end)

    local bg = WINDOW_MANAGER:CreateControl("NecroCat_WhisperBG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0, 0, 0, 0)
    bg:SetEdgeColor(0, 0, 0, 0)

    local label = WINDOW_MANAGER:CreateControl("NecroCat_WhisperLabel", frame, CT_LABEL)
    label:SetAnchor(CENTER, frame, CENTER, 0, 0)
    label:SetFont("ZoFontWinH1")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    NC.WhisperFrame = frame
    NC.WhisperLabel = label
    NC.WhisperBG    = bg
end

local function UpdateCastleIconPosition(newCoord)
    NC.savedVars.vrxCoord = newCoord
    NC.CastleIcon:ClearAnchors()
    NC.CastleIcon:SetAnchor(TOPRIGHT, ZO_ChatWindow, TOPRIGHT, -newCoord, 10)
end

local function UpdateNoteIconPosition(newCoord)
    NC.savedVars.noteXCoord = newCoord
    NC.NoteIcon:ClearAnchors()
    NC.NoteIcon:SetAnchor(TOPRIGHT, ZO_ChatWindow, TOPRIGHT, -newCoord, 10)
end

function NC.OpenSettings()
    if NC.SettingsUI and NC.SettingsUI.Toggle then
        NC.SettingsUI.Toggle()
    end
end

---------------------------------------------------------
-- 5. ИНВАЙТ И МЕНЮ
---------------------------------------------------------


local function TryTeleportToPlayer(displayName)
    if not displayName or displayName == "" then return end

    if IsFriend(displayName) then
        JumpToFriend(displayName)
        d(zo_strformat(GetString(SI_NC_TELEPORT_FRIEND), displayName))
        return
    end

    local foundInGroup = false
    for i = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(i)
        if GetUnitDisplayName(unitTag) == displayName then
            JumpToGroupMember(unitTag)
            d(zo_strformat(GetString(SI_NC_TELEPORT_GROUP), displayName))
            foundInGroup = true
            break
        end
    end
    
    if foundInGroup then return end

    d(zo_strformat(GetString(SI_NC_TELEPORT_FAIL), displayName))
end

-- =========================================================
-- КОПИРОВАНИЕ ID И ХУК ЧАТА
-- =========================================================

-- Функция копирования через игровой чат
function NC.ShowCopyDialog(textToCopy)
    StartChatInput(textToCopy) -- Открывает чат и вставляет ник
    if ZO_ChatWindowTextEntryEditBox then
        ZO_ChatWindowTextEntryEditBox:SelectAll() -- Выделяет ник синим цветом
        ZO_ChatWindowTextEntryEditBox:TakeFocus() -- Переводит клавиатуру на чат
    end
end

-- Хук для клика по нику в чате
local function HookChatContextMenu()
    ZO_PreHook("ZO_ChatSystem_ShowGameplayContextMenu", function(link)
        if not LibCustomMenu then return end
        local linkType, displayName = ZO_LinkHandler_ParseLink(link)
        if linkType == "player" and displayName then
            AddCustomMenuItem(GetString(SI_NC_MENU_COPY_ID), function()
                NC.ShowCopyDialog(displayName)
            end)
        end
    end)
end


-- Финальная функция меню NecroCat с отдельными вкладками
local function AddNecroMenuEntries(data)
    local displayName = data.displayName
    if not displayName then return end

    -- 1. Пункт Копирования @ID
    AddCustomMenuItem(GetString(SI_NC_MENU_COPY_ID), function()
        NC.ShowCopyDialog(displayName)
    end)

    -- 2. Пункт Телепорта к игроку
    AddCustomMenuItem(GetString(SI_NC_MENU_TRAVEL_PLAYER), function() 
        TryTeleportToPlayer(displayName)
    end)
    
    -- 3. Пункт Инвайта
    AddCustomMenuItem(GetString(SI_NC_MENU_INVITE_PARTY), function() 
        if GroupInviteByName then GroupInviteByName(displayName) end 
    end)

    -- =========================================================
    -- ВЫЕЗЖАЮЩАЯ ВКЛАДКА 1: "NecroCat" (Друзья, слежка, настройки)
    -- =========================================================
    if not NC.savedVars.trackedPlayers then NC.savedVars.trackedPlayers = {} end
    if not NC.savedVars.favoritePlayers then NC.savedVars.favoritePlayers = {} end
    local isTracked = NC.savedVars.trackedPlayers[displayName]
    local isFavorite = NC.IsPlayerFavorite(displayName)

    local necroCatSubMenu = {
        {
            label = isTracked and GetString(SI_NC_MENU_DISABLE_TRACKING) or GetString(SI_NC_MENU_ENABLE_TRACKING),
            callback = function()
                if isTracked then
                    NC.savedVars.trackedPlayers[displayName] = nil
                    d(string.format("[NecroCat] %s: tracking off", displayName))
                else
                    NC.savedVars.trackedPlayers[displayName] = true
                    d(string.format("[NecroCat] %s: tracking on", displayName))
                end
            end
        },
        {
            label = isFavorite and GetString(SI_NC_MENU_FAVORITE_REMOVE) or GetString(SI_NC_MENU_FAVORITE_ADD),
            callback = function()
                if isFavorite then
                    if NC.savedVars.treatFriendsAsFavorites and IsFriend and IsFriend(displayName) then
                        NC.savedVars.favoritePlayers[displayName] = false
                    else
                        NC.savedVars.favoritePlayers[displayName] = nil
                    end
                    d(string.format("|c66f2ff[NecroCat]|r %s removed from favorites.", displayName))
                else
                    if NC.savedVars.favoritePlayers[displayName] == false then
                        NC.savedVars.favoritePlayers[displayName] = nil
                    else
                        NC.savedVars.favoritePlayers[displayName] = true
                    end
                    d(string.format("|c66f2ff[NecroCat]|r %s added to favorites!", displayName))
                end
            end
        },
        {
            label = GetString(SI_NC_MENU_PIN_FRIEND),
            callback = function()
                local nextNum = 1
                if NC.savedVars and NC.savedVars.pinned then
                    for name, priority in pairs(NC.savedVars.pinned) do
                        if priority >= nextNum then nextNum = priority + 1 end
                    end
                end
                StartChatInput(string.format("/pinfriend %s %d", displayName, nextNum))
            end
        },
        {
            label = GetString(SI_NC_MENU_UNPIN_FRIEND),
            callback = function()
                StartChatInput(string.format("/unpinfriend %s", displayName))
            end
        },
        {
            label = GetString(SI_NC_MENU_LIST_PINNED),
            callback = function()
                SLASH_COMMANDS["/listpinned"]()
            end
        },
        {
            label = GetString(SI_NC_MENU_CLEAR_PINNED),
            callback = function()
                SLASH_COMMANDS["/pinclear"]()
            end
        }
    }

    -- 1-я вкладка: NecroCat
    AddCustomSubMenuItem("|c66f2ffNecroCat|r", necroCatSubMenu)

    
    -- =========================================================
    -- ВЫЕЗЖАЮЩАЯ ВКЛАДКА 2: "House" (Только дома этого игрока)
    -- =========================================================
    local playerHouseList = NC.savedVars.playerHouses and NC.savedVars.playerHouses[displayName]
    local houseSubMenu = {}

    -- А. Список домов для телепорта (с поддержкой истинного хозяина)
    if playerHouseList and #playerHouseList > 0 then
        for index, hData in ipairs(playerHouseList) do
            local targetOwner = hData.owner or displayName
            table.insert(houseSubMenu, {
                label = string.format("|c00FF00|t18:18:EsoUI/Art/Icons/mapkey/mapkey_housing.dds|t %d. %s|r", index, hData.name),
                callback = function()
                    d(string.format("|c66f2ff[NecroCat]|r %s (%s)...", hData.name, targetOwner))
                    if targetOwner == GetDisplayName() then
                        RequestJumpToHouse(hData.houseId)
                    else
                        JumpToSpecificHouse(targetOwner, hData.houseId)
                    end
                end
            })
        end
    else
        table.insert(houseSubMenu, {
            label = GetString(SI_NC_MENU_HOUSE_EMPTY),
            callback = function() end
        })
    end

    -- Б. Кнопка привязки
    table.insert(houseSubMenu, {
        label = GetString(SI_NC_MENU_HOUSE_PIN),
        callback = function()
            local nextHousePos = (playerHouseList and #playerHouseList or 0) + 1
            local curHouseId = GetCurrentZoneHouseId()
            if curHouseId and curHouseId > 0 then
                StartChatInput(string.format("/housepin %s %d %d", displayName, curHouseId, nextHousePos))
            else
                StartChatInput(string.format("/housepin %s ", displayName))
            end
        end
    })

    -- В. Удаление домов
    if playerHouseList and #playerHouseList > 0 then
        table.insert(houseSubMenu, {
            label = GetString(SI_NC_MENU_HOUSE_UNPIN),
            callback = function()
                if #playerHouseList == 1 then
                    StartChatInput(string.format("/unhousepin %s 1", displayName))
                else
                    StartChatInput(string.format("/unhousepin %s ", displayName))
                end
            end
        })
        table.insert(houseSubMenu, {
            label = GetString(SI_NC_MENU_HOUSE_CLEAR),
            callback = function()
                SLASH_COMMANDS["/clearhouses"](displayName)
            end
        })
    end

    -- 2-я вкладка: House
    AddCustomSubMenuItem("|c66f2ffHouse|r", houseSubMenu)
end

local function HookFriendsAndGuildMenu()
    if not LibCustomMenu then return end
    
    local function AddCustomItems(data)
        AddNecroMenuEntries(data)
    end
    
    LibCustomMenu:RegisterFriendsListContextMenu(AddCustomItems, LibCustomMenu.CATEGORY_LATE)
    LibCustomMenu:RegisterGuildRosterContextMenu(AddCustomItems, LibCustomMenu.CATEGORY_LATE)
end

-- Хук для перекраски пунктов стандартных контекстных меню
function NC.HookMenuColors()
    local origAddMenuItem = AddMenuItem
    if not origAddMenuItem then return end

    AddMenuItem = function(text, callback, itemType, font, normalColor, highlightColor, item)
        if text and type(text) == "string" and not string.find(text, "^|c") then
            local inGroupScene = SCENE_MANAGER and (SCENE_MANAGER:IsShowing("groupMenuKeyboard") or SCENE_MANAGER:IsShowing("groupList"))

            -- 1. Золотой: Сделать лидером
            if (SI_GROUP_LIST_MENU_PROMOTE_TO_LEADER and text == GetString(SI_GROUP_LIST_MENU_PROMOTE_TO_LEADER))
               or string.find(text, "Сделать лидером")
               or string.find(text, "Promote to Leader") then
                text = "|cFFD700" .. text .. "|r"

            -- 2. Красный: Исключить из группы, Голосование за исключение
            elseif (SI_GROUP_LIST_MENU_KICK_FROM_GROUP and text == GetString(SI_GROUP_LIST_MENU_KICK_FROM_GROUP))
               or (SI_GROUP_LIST_MENU_VOTE_KICK_FROM_GROUP and text == GetString(SI_GROUP_LIST_MENU_VOTE_KICK_FROM_GROUP))
               or string.find(text, "Исключить")
               or string.find(text, "Голосовать за исключение")
               or string.find(text, "Remove from Group")
               or string.find(text, "Vote to Kick") then
                text = "|cFF4444" .. text .. "|r"

            -- 3. Синий: Покинуть группу, Распустить группу
            elseif (SI_GROUP_LIST_MENU_LEAVE_GROUP and text == GetString(SI_GROUP_LIST_MENU_LEAVE_GROUP))
               or (SI_GROUP_LIST_MENU_DISBAND_GROUP and text == GetString(SI_GROUP_LIST_MENU_DISBAND_GROUP))
               or string.find(text, "Покинуть группу")
               or string.find(text, "Распустить группу")
               or string.find(text, "Leave Group")
               or string.find(text, "Disband") then
                text = "|c55AAFF" .. text .. "|r"

            -- 4. Синий: Переместиться к игроку (ТОЛЬКО в группе / на плашках группы)
            elseif (SI_GROUP_LIST_MENU_JUMP_TO_MEMBER and text == GetString(SI_GROUP_LIST_MENU_JUMP_TO_MEMBER))
               or (inGroupScene and (string.find(text, "Переместиться") or string.find(text, "Travel to") or string.find(text, "Jump to")))
               or string.find(text, "согруппнику")
               or string.find(text, "Group Member") then
                text = "|c55AAFF" .. text .. "|r"

            -- 5. Зеленый: Пригласить в группу (везде)
            elseif (SI_GROUP_LIST_MENU_INVITE_TO_GROUP and text == GetString(SI_GROUP_LIST_MENU_INVITE_TO_GROUP))
               or (SI_FRIENDS_LIST_MENU_INVITE_TO_GROUP and text == GetString(SI_FRIENDS_LIST_MENU_INVITE_TO_GROUP))
               or (SI_CHAT_PLAYER_CONTEXT_INVITE_TO_GROUP and text == GetString(SI_CHAT_PLAYER_CONTEXT_INVITE_TO_GROUP))
               or string.find(text, "Пригласить в группу")
               or string.find(text, "Invite to Group") then
                text = "|c22FF22" .. text .. "|r"
            end
        end

        return origAddMenuItem(text, callback, itemType, font, normalColor, highlightColor, item)
    end
    
    ZO_Menu_AddMenuItem = AddMenuItem
end

---------------------------------------------------------
-- 6. ЗАГРУЗКА
---------------------------------------------------------

function NC.UpdateAggroMarker()
    if NC.savedVars.aggroMarkerEnabled then
        local size = NC.savedVars.aggroMarkerSize or 48
        local texture = NC.savedVars.aggroMarkerTexture or "NecroCat/imgs/stuffs/aggro.dds"
        SetFloatingMarkerInfo(MAP_PIN_TYPE_AGGRO, size, texture)
    else
        SetFloatingMarkerInfo(MAP_PIN_TYPE_AGGRO, 0, "")
    end
end
---------------------------------------------------------
-- МОДУЛЬ: АВТО-ПРИВЯЗКА СЕТОВ И ТОСТ
---------------------------------------------------------

function NC.CreateSetToastUI()
    local frame = WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_SetToastFrame")
    frame:SetDimensions(360, 54)
    frame:ClearAnchors()
    if NC.savedVars and NC.savedVars.setToastLeft and NC.savedVars.setToastTop then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, NC.savedVars.setToastLeft, NC.savedVars.setToastTop)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    frame:SetMovable(true)
    frame:SetMouseEnabled(true)
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)
    frame:SetDrawTier(DT_HIGH)

    frame:SetHandler("OnMoveStop", function(self)
        NC.savedVars.setToastLeft = self:GetLeft()
        NC.savedVars.setToastTop  = self:GetTop()
    end)

    local bg = WINDOW_MANAGER:CreateControl("$(parent)BG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0.03, 0.03, 0.03, 0.92)
    bg:SetEdgeColor(0.2, 0.85, 1, 0.9)
    bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 8, 8)

    local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", frame, CT_TEXTURE)
    icon:SetDimensions(40, 40)
    icon:SetAnchor(LEFT, frame, LEFT, 8, 0)

    local nameLabel = WINDOW_MANAGER:CreateControl("$(parent)Name", frame, CT_LABEL)
    nameLabel:SetAnchor(TOPLEFT, icon, TOPRIGHT, 10, -2)
    nameLabel:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -8, -2)
    nameLabel:SetFont("ZoFontWinH4")
    nameLabel:SetMaxLineCount(1)
    nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    local setLabel = WINDOW_MANAGER:CreateControl("$(parent)Set", frame, CT_LABEL)
    setLabel:SetAnchor(BOTTOMLEFT, icon, BOTTOMRIGHT, 10, 2)
    setLabel:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -8, 2)
    setLabel:SetFont("ZoFontGameSmall")
    setLabel:SetMaxLineCount(1)

    NC.SetToastFrame = frame
    NC.SetToastIcon  = icon
    NC.SetToastName  = nameLabel
    NC.SetToastSet   = setLabel
end

function NC.ShowSetToast(itemLink, setId, setName)
    if not NC.SetToastFrame then return end

    local icon = GetItemLinkIcon(itemLink) or "EsoUI/Art/Icons/icon_missing.dds"
    local pieceName = zo_strformat("<<1>>", GetItemLinkName(itemLink))

    local done, total = 0, 0
    if setId and setId > 0 and ITEM_SET_COLLECTIONS_DATA_MANAGER then
        local itemSetData = ITEM_SET_COLLECTIONS_DATA_MANAGER:GetItemSetCollectionData(setId)
        if itemSetData then
            done = itemSetData:GetNumUnlockedPieces()
            total = itemSetData:GetNumPieces()
            -- Визуально прибавляем текущую привязываемую вещь
            done = math.min(done + 1, total)
        end
    end

    NC.SetToastIcon:SetTexture(icon)
    NC.SetToastName:SetText(pieceName)
    if total > 0 then
        NC.SetToastSet:SetText(string.format("|c66f2ff%s|r  |c00FF00(%d/%d)|r", setName, done, total))
    else
        NC.SetToastSet:SetText(string.format("|c66f2ff%s|r", setName))
    end

    NC.SetToastFrame:SetHidden(false)
    PlaySound("Item_Unlocked")

    local showTime = GetFrameTimeSeconds()
    NC.lastSetToastTime = showTime
    zo_callLater(function()
        if NC.SetToastFrame and NC.lastSetToastTime == showTime then
            NC.SetToastFrame:SetHidden(true)
        end
    end, 3500)
end

function NC.TestSetToast()
    if not NC.SetToastFrame then return end

    NC.SetToastIcon:SetTexture("EsoUI/Art/Icons/gear_nord_heavy_chest_d.dds")
    NC.SetToastName:SetText("|c00FF00Кираса матери ночи|r")
    NC.SetToastSet:SetText("|c66f2ffОбъятия матери ночи|r  |c00FF00(12/25)|r")
    NC.SetToastFrame:SetHidden(false)
    NC.SetToastFrame:BringWindowToTop()
    PlaySound("Item_Unlocked")

    local showTime = GetFrameTimeSeconds()
    NC.lastSetToastTime = showTime
    zo_callLater(function()
        if NC.SetToastFrame and NC.lastSetToastTime == showTime then
            NC.SetToastFrame:SetHidden(true)
        end
    end, 6000)
end

function NC.OnInventorySlotUpdateForAutoBind(eventCode, bagId, slotIndex, isNewItem)
    if not NC.savedVars.autoBindSetItems then return end
    if bagId ~= BAG_BACKPACK then return end

    local itemLink = GetItemLink(bagId, slotIndex)
    if not itemLink or itemLink == "" then return end

    -- РУБЕЖ 1: Наглухо блокируем любые скрафченные предметы
    if IsItemLinkCrafted(itemLink) or (IsItemCrafted and IsItemCrafted(bagId, slotIndex)) then
        return
    end

    -- РУБЕЖ 2: Проверяем, входит ли этот сет вообще в коллекцию наклеек (Stickerbook)
    if not IsItemLinkSetCollectionPiece(itemLink) then
        return
    end

    -- Если вещь уже привязана — пропускаем
    if IsItemBound(bagId, slotIndex) then
        return
    end

    local pieceId = GetItemLinkItemId(itemLink)
    if not pieceId or pieceId <= 0 then return end

    -- Если этой вещи действительно еще нет в коллекции наклеек — привязываем
    if not IsItemSetCollectionPieceUnlocked(pieceId) then
        BindItem(bagId, slotIndex)

        local _, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink)
        if NC.savedVars.showAutoBindToast and setName and setName ~= "" then
            NC.ShowSetToast(itemLink, setId, setName)
        end
    end
end

function NC.OnAddOnLoaded(eventCode, addOnName)
    if not addOnName or string.lower(addOnName) ~= string.lower(NC.name) then return end

    NC.savedVars = ZO_SavedVars:NewAccountWide("NecroCat_SV", 1, nil, {
        vrxCoord        = 136,
        noteXCoord      = 170,
        showIcon        = true,
        showNoteIcon    = false,
        guildHomeVisibility = 1,
        pinned          = {},
        whisperAlert    = false,
        whisperLocked   = true,
        whisperDuration = 3.5,
        firstLoad       = true,
        disableEnforceRole = true,
        swapGroupNames  = false,
        hideRemoveFromGroup = false,
        hideReport          = false,
        hideTributeInvite   = false,
        hideAddFriend       = false,
        hideDuel            = false,
        hideTrade           = false,
        trackedPlayers           = {},
        favoritePlayers          = {},
        treatFriendsAsFavorites  = true,
        friendNotificationLocked = true,
        followAutoAccept = false,
        followShowOwn = false,
        followShowButton = false,
        followButtonX = 177,
        followDialogLeft = 500,
        followDialogTop = 300,
        followAutoPrepare = false,
        guildBankEnabled = false,
        guildBankLeft = 500,
        guildBankTop = 300,
        customGuildOrder = {},
        guildBankDefaultGuildId = 0,
        autoAcceptDungeon    = false,
        autoAcceptPvPQueue   = false,
        showAutoAcceptButton = false,
        autoConvertToRaid    = false,
        suppressJumpToLeader = false,
        fastTravelConfirm    = false,
        dismissPetsInTrials  = false,
        storedPetId          = 0,
        autoConfirmCrafting  = false,
        autoConfirmDestroy   = false,
        showRecipeButton     = false,
        includeMotifs        = false,
        includeStylePages    = false,
        autoUnboxEnabled     = true,
        unboxDelay           = 1.8,
        -- Smart Auto-Recharge & Auto-Repair
        autoRechargeEnabled     = false,
        autoRechargeThreshold   = 20,
        autoRechargePriority    = 2,
        
        autoRepairKitsEnabled   = false,
        autoRepairKitsThreshold = 20,
        autoRepairKitsPriority  = 2,
        
        autoVendorRepairEnabled = false,
        showGearStatus          = false,

        -- Маркер агро над врагами
        aggroMarkerEnabled      = false,
        aggroMarkerSize         = 48,
        aggroMarkerTexture      = "NecroCat/imgs/stuffs/aggro.dds",

        -- Авто-привязка сетов (Stickerbook) и всплывающий тост
        autoBindSetItems        = false,
        showAutoBindToast       = true,
        -- Счетчик сундуков
        showChestCounter        = false,
        chestSize               = 36,
        currentChestsCount      = 0,
        lastZoneId              = 0,
        openedChestsCoords      = {},
        customColorIcons        = false,
        showBgZoneIcon          = false,
        playerHouses            = {},
        minimap                 = {},
        
        -- Виджет планарных ключей
        planarKeyWidgetEnabled   = false,
        planarKeyWidgetSize      = 56,
        planarKeyWidgetFontSize  = 26,
        planarKeyWidgetOffsetX   = 0,
        planarKeyWidgetOffsetY   = 0,
        planarKeyWidgetUnlocked  = false,
        currencyShowPlanarKeys   = false,
        
        -- Модуль: Умная камера (Пресеты Мира и Боя)
        cameraSwitcherEnabled = false,
        cameraOutCombat = {
            fov         = 50.0,
            horizPos    = 0.0,
            horizOffset = 0.0,
            vertOffset  = 0.0,
        },
        cameraInCombat = {
            fov         = 55.0,
            horizPos    = 0.0,
            horizOffset = 0.0,
            vertOffset  = -0.12,
        },

        -- Модуль: Умный фильтр истории лута
        lootFilterEnabled        = false,
        lootFilterMinQuality     = 0,     -- 0: Все, 2: Зеленый+, 3: Синий+, 4: Фиолет+, 5: Золото
        lootFilterHideTrash      = true,  -- Скрывать серый мусор (кишки, сломанное оружие)
        lootFilterHideMaterials  = false, -- Скрывать сырье и ресурсы сбора (руда, дерево, ткань, травы)
        lootFilterHideTraits     = false, -- Скрывать камни стиля и особенностей (трейты)
        lootFilterAlwaysRare     = true,  -- Страховка: всегда показывать заточки и ресурсы фиол/золото (>=4)
        lootFilterAlwaysRecipes  = true,  -- Страховка: всегда показывать рецепты, мотивы и стили

        -- Модуль: Долгие баффы (Еда и свитки)
        longBuffsEnabled         = false,
        longBuffsShowPermanent   = false,
        longBuffsOrientation     = 1, -- 1: Вертикально, 2: Горизонтально
        longBuffsGrowth          = 1, -- 1: Авто, 2: Прямой (Вправо/Вниз), 3: Обратный (Влево/Вверх)
        longBuffsSize            = 36,
        longBuffsUnlocked        = false,

        -- Модуль: Короткие боевые баффы игрока
        shortBuffsEnabled        = false,
        shortBuffsOrientation    = 2, -- 1: Вертикально, 2: Горизонтально
        shortBuffsGrowth         = 1, -- 1: Авто, 2: Прямой (Вправо/Вниз), 3: Обратный (Влево/Вверх)
        shortBuffsSize           = 36,
        shortBuffsUnlocked       = false,

        -- Модуль: Дебаффы на игроке
        playerDebuffsEnabled     = false,
        playerDebuffsOrientation = 2, -- 1: Вертикально, 2: Горизонтально
        playerDebuffsGrowth      = 1, -- 1: Авто, 2: Прямой (Вправо/Вниз), 3: Обратный (Влево/Вверх)
        playerDebuffsSize        = 36,
        playerDebuffsUnlocked    = false,

        -- Модуль: Дебаффы на цели (враге)
        targetDebuffsEnabled     = false,
        targetDebuffsOnlyPlayer  = false,
        targetDebuffsOrientation = 2, -- 1: Вертикально, 2: Горизонтально
        targetDebuffsGrowth      = 1, -- 1: Авто, 2: Прямой (Вправо/Вниз), 3: Обратный (Влево/Вверх)
        targetDebuffsSize        = 36,
        targetDebuffsUnlocked    = false,

        -- Модуль: Напоминание о еде, торте и свитках опыта
        foodReminderEnabled      = false,
        foodReminderShowFood     = true,
        foodReminderShowTorte    = true,
        foodReminderShowXP       = false,
        foodReminderSize         = 48,
        foodReminderUnlocked     = false,
        foodReminderPreview      = false,

        -- Модуль: Спидран и Рейдовый таймер
        speedrunHudEnabled       = false,
        speedrunHudUnlocked      = false,
        speedrunHudVetOnly       = true,
        dungeonStartTimeStamp    = 0,
        dungeonStartZoneId       = 0,

        -- Авто-запись логов боя (Encounter Log)
        autoEncounterLog         = false,
        autoEncounterLogVetOnly  = true,

        -- Умный спринт на маунте
        mountSprintToggle        = false,

        -- Модуль: Спидометр
        speedometerEnabled       = false,
        speedometerOnlyMounted   = false,
        speedometerUnlocked      = false,

        -- Модуль: Ветеранство (PvP ранг)
        veterancyEnabled         = false,
        veterancySize            = 40,
        veterancyUnlocked        = false,

        -- Модуль: Суточный трекер валют и опыта
        currencyTrackerEnabled      = false,
        currencyTrackerUnlocked      = false,
        currencyTrackerContextOnly  = true,
        currencyShowGold            = true,
        currencyShowBars            = true,
        currencyShowAP              = true,
        currencyShowTelVar          = true,
        currencyShowArchive         = true,
        currencyShowXP              = true,
        currencyDailyDate           = "",
        currencyDailyStarts         = {},
    }, GetWorldName())
    
    
    
    -- Бесшовная миграция старой настройки банка со слота на ID
    if (not NC.savedVars.guildBankDefaultGuildId or NC.savedVars.guildBankDefaultGuildId == 0) and NC.savedVars.guildBankDefaultIndex and NC.savedVars.guildBankDefaultIndex > 0 then
        NC.savedVars.guildBankDefaultGuildId = GetGuildId(NC.savedVars.guildBankDefaultIndex)
    end

    -- Бесшовная авто-миграция пути маркера агро для всех игроков
    if NC.savedVars.aggroMarkerTexture == "NecroCat/imgs/aggro.dds" then
        NC.savedVars.aggroMarkerTexture = "NecroCat/imgs/stuffs/aggro.dds"
    end

    if NC.savedVars.firstLoad then
        NC.savedVars.firstLoad = false
        NC.savedVars.vrxCoord = 136
    end
    
    NC.ApplyCustomIcons()

    NC.CastleIcon = WINDOW_MANAGER:CreateControl("NecroCatGuildHall", ZO_ChatWindow, CT_BUTTON)
    NC.CastleIcon:SetDimensions(25, 25)
    NC.CastleIcon:SetNormalTexture("NecroCat/imgs/fons/CastleofNecroCat.dds")
    NC.CastleIcon:SetHidden(not NC.savedVars.showIcon)
    NC.CastleIcon:SetAnchor(TOPRIGHT, ZO_ChatWindow, TOPRIGHT, -NC.savedVars.vrxCoord, 10)
    NC.CastleIcon:SetHandler("OnMouseUp", function(ctrl, button, upInside)
        if not upInside then return end
        if button == MOUSE_BUTTON_INDEX_LEFT then
            NC.CastleHall()
        elseif button == MOUSE_BUTTON_INDEX_RIGHT then
            NC.OpenSettings()
        end
    end)
    NC.CastleIcon:SetHandler("OnMouseEnter", function(ctrl)
        InitializeTooltip(InformationTooltip, ctrl, TOP, 0, 5)
        InformationTooltip:AddLine(GetString(SI_NC_TT_GUILDHALL), "ZoFontWinH4")
        InformationTooltip:AddLine(GetString(SI_NC_TT_GUILDHALL_LMB), "ZoFontGameSmall")
        InformationTooltip:AddLine(GetString(SI_NC_TT_GUILDHALL_RMB), "ZoFontGameSmall")
    end)
    NC.CastleIcon:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    
    NC.NoteIcon = WINDOW_MANAGER:CreateControl("NecroCatSelfWhisper", ZO_ChatWindow, CT_BUTTON)
    NC.NoteIcon:SetDimensions(25, 25)
    NC.NoteIcon:SetNormalTexture("EsoUI/Art/MainMenu/menuBar_journal_up.dds")
    NC.NoteIcon:SetHidden(not NC.savedVars.showNoteIcon)
    NC.NoteIcon:SetAnchor(TOPRIGHT, ZO_ChatWindow, TOPRIGHT, -NC.savedVars.noteXCoord, 10)
    NC.NoteIcon:SetHandler("OnClicked", NC.SelfWhisper)
    NC.NoteIcon:SetHandler("OnMouseEnter", function(ctrl)
        InitializeTooltip(InformationTooltip, ctrl, TOP, 0, 5)
        SetTooltipText(InformationTooltip, GetString(SI_NC_TT_NOTE))
    end)
    NC.NoteIcon:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    
    NC.isReady = false
    zo_callLater(function() NC.isReady = true end, 5000) 
    
    if GROUP_LIST then
        ZO_PostHook(GROUP_LIST, "SetupGroupEntry", NC_GroupEntryHook)
    end

    ZO_PreHook(GROUP_FINDER_SEARCH_MANAGER, 'ExecuteSearch', function()
        if NC.savedVars.disableEnforceRole then
            SetGroupFinderFilterEnforceRoles(false)
        end
    end)

    NC_InitInteractionFix()
    NC.UpdateJumpToLeaderSuppression()
    
    -- Безопасные вызовы хуков
    if HookFriendsAndGuildMenu then HookFriendsAndGuildMenu() end
    if NC.HookInventoryContextMenu then NC.HookInventoryContextMenu() end
    NC.HookFriendsSorting()
    NC.HookGuildSelector()
    NC.HookMenuColors()
    NC.HookBattlegroundZoneIcons()
    
    CreateWhisperUI()
    NC.UpdateWhisperUI()
    CreateFriendNotificationUI()
    NC.UpdateFriendUI()
    NC.CreateDifficultyUI()
    NC.CreateGuildBankUI()
    NC.CreateRecipeLearnerUI()
    NC.CreateGroupMenuAutoAcceptUI()
    NC.CreateSetToastUI()
    NC.UpdateAggroMarker()
    NC.CreateChestCounterUI()
    NC.CreateLongBuffsUI()
    NC.CreateShortBuffsUI()
    NC.CreatePlayerDebuffsUI()
    NC.CreateTargetDebuffsUI()
    NC.CreateFoodReminderUI()
    NC.CreateSpeedrunHudUI()
    NC.CreateSpeedometerUI()
    NC.CreateVeterancyUI()
    NC.CreateCurrencyTrackerUI()
    NC.CreatePlanarKeyWidgetUI()

    -- Отслеживание событий триала
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_TrialStart", EVENT_RAID_TRIAL_STARTED, function()
        if NC.UpdateSpeedrunHud then NC.UpdateSpeedrunHud() end
    end)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_TrialComplete", EVENT_RAID_TRIAL_COMPLETE, function()
        if NC.UpdateSpeedrunHud then NC.UpdateSpeedrunHud() end
    end)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_TrialFailed", EVENT_RAID_TRIAL_FAILED, function()
        if NC.UpdateSpeedrunHud then NC.UpdateSpeedrunHud() end
    end)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_TrialRevives", EVENT_RAID_REVIVE_COUNTER_UPDATE, function()
        if NC.UpdateSpeedrunHud then NC.UpdateSpeedrunHud() end
    end)

    -- Вспомогательная функция старта таймера данжа
    local function StartDungeonTimerIfReady(forceStart)
        local isRaid = (IsRaidInProgress and IsRaidInProgress()) or (GetRaidDuration and GetRaidDuration() > 0)
        if IsUnitInDungeon("player") and not isRaid then
            local sv = NC.savedVars
            if sv and (not sv.dungeonStartTimeStamp or sv.dungeonStartTimeStamp == 0) then
                local currentZoneId = GetZoneId(GetUnitZoneIndex("player"))
                local targetSubzone = NC.DungeonStartSubzones and NC.DungeonStartSubzones[currentZoneId]

                -- Если для данжа задана подзона (Тюрьма ИГ, Путь Жертвоприношений и т.д.),
                -- бой на входе игнорируем, ждем именно перехода за порог или босса!
                if forceStart or not targetSubzone or (GetUnitName and GetUnitName("boss1") ~= "") then
                    sv.dungeonStartTimeStamp = GetTimeStamp()
                    sv.dungeonStartZoneId = currentZoneId
                end
            end
        end
    end

    -- 1. Старт по первому бою (для обычных данжей)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_DungeonCombat", EVENT_PLAYER_COMBAT_STATE, function(eventCode, inCombat)
        if inCombat then
            StartDungeonTimerIfReady(false)
        end
    end)

    EVENT_MANAGER:RegisterForEvent(NC.name .. "_GroupDungeonCombat", EVENT_UNIT_COMBAT_STATE_CHANGED, function(eventCode, unitTag, inCombat)
        if inCombat and (unitTag == "player" or string.find(unitTag, "^group")) then
            StartDungeonTimerIfReady(false)
        end
    end)

    -- 2. Старт по переходу в подзону (принудительный старт: Бастион, Ущелье Запаха Крови и т.д.)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_DungeonSubzone", EVENT_ZONE_CHANGED, function(eventCode, zoneName, subZoneName, newSubzone, zoneId, subZoneId)
        local currentZoneId = GetZoneId(GetUnitZoneIndex("player"))
        local targetSubzone = NC.DungeonStartSubzones and NC.DungeonStartSubzones[currentZoneId]
        if targetSubzone and subZoneId == targetSubzone then
            StartDungeonTimerIfReady(true)
        end
    end)

    -- 3. Особый крюк для Нечестивой Могилы (Unhallowed Grave ID 1153)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_UnhallowedGraveHook", EVENT_COMBAT_EVENT, function(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
        if abilityId == 131774 and result == ACTION_RESULT_EFFECT_GAINED then
            StartDungeonTimerIfReady(true)
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(NC.name .. "_UnhallowedGraveHook", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 131774)

    -- Сброс таймера только при выходе из данжа в другую зону
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_DungeonZoneChange", EVENT_PLAYER_ACTIVATED, function()
        local sv = NC.savedVars
        if sv then
            local currentZoneId = GetZoneId(GetUnitZoneIndex("player"))
            if not IsUnitInDungeon("player") or (sv.dungeonStartZoneId and sv.dungeonStartZoneId > 0 and sv.dungeonStartZoneId ~= currentZoneId) then
                sv.dungeonStartTimeStamp = 0
                sv.dungeonStartZoneId = 0
            end
        end
        if NC.UpdateSpeedrunHud then NC.UpdateSpeedrunHud() end
    end)

    -- Отслеживание изменений баффов и дебаффов игрока
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_BuffsChanged", EVENT_EFFECT_CHANGED, function(eventCode, changeType, effectSlot, effectName, unitTag)
        if unitTag == "player" then
            if NC.UpdateLongBuffs then NC.UpdateLongBuffs() end
            if NC.UpdateShortBuffs then NC.UpdateShortBuffs() end
            if NC.UpdatePlayerDebuffs then NC.UpdatePlayerDebuffs() end
            if NC.UpdateFoodReminder then NC.UpdateFoodReminder() end
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(NC.name .. "_BuffsChanged", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    -- Отслеживание наведения прицела и дебаффов на цели
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_TargetChanged", EVENT_RETICLE_TARGET_CHANGED, function()
        if NC.UpdateTargetDebuffs then NC.UpdateTargetDebuffs() end
    end)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_TargetBuffsChanged", EVENT_EFFECT_CHANGED, function(eventCode, changeType, effectSlot, effectName, unitTag)
        if unitTag == "reticleover" and NC.UpdateTargetDebuffs then
            NC.UpdateTargetDebuffs()
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(NC.name .. "_TargetBuffsChanged", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "reticleover")

    -- Быстрый таймер обновления боевых секунд и спидрана (раз в 100 мс)
    EVENT_MANAGER:RegisterForUpdate(NC.name .. "_BuffsTimer", 100, function()
        local sv = NC.savedVars
        if not sv then return end

        if sv.longBuffsEnabled and not sv.longBuffsUnlocked and NC.UpdateLongBuffs then
            NC.UpdateLongBuffs()
        end
        if sv.shortBuffsEnabled and not sv.shortBuffsUnlocked and NC.UpdateShortBuffs then
            NC.UpdateShortBuffs()
        end
        if sv.playerDebuffsEnabled and not sv.playerDebuffsUnlocked and NC.UpdatePlayerDebuffs then
            NC.UpdatePlayerDebuffs()
        end
        if sv.targetDebuffsEnabled and not sv.targetDebuffsUnlocked and NC.UpdateTargetDebuffs then
            NC.UpdateTargetDebuffs()
        end
        if sv.speedrunHudEnabled and not sv.speedrunHudUnlocked and NC.UpdateSpeedrunHud then
            NC.UpdateSpeedrunHud()
        end
        if sv.speedometerEnabled and not sv.speedometerUnlocked and NC.UpdateSpeedometer then
            NC.UpdateSpeedometer()
        end
    end)

    -- Спокойный опрос напоминания о еде (раз в 2 секунды вместо безумных 100 мс)
    EVENT_MANAGER:RegisterForUpdate(NC.name .. "_FoodTimer", 2000, function()
        local sv = NC.savedVars
        if sv and sv.foodReminderEnabled and not sv.foodReminderPreview and NC.UpdateFoodReminder then
            NC.UpdateFoodReminder()
        end
    end)

    EVENT_MANAGER:RegisterForEvent(NC.name .. "_LockpickSuccess", EVENT_LOCKPICK_SUCCESS, NC.OnLockpickSuccessForChestCounter)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_ClientInteract", EVENT_CLIENT_INTERACT_RESULT, NC.OnClientInteractResultForChestCounter)

    -- Регистрация авто-привязки сетов со скоростным фильтром (только новые вещи в рюкзаке)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_AutoBind", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, NC.OnInventorySlotUpdateForAutoBind)
    EVENT_MANAGER:AddFilterForEvent(NC.name .. "_AutoBind", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK, REGISTER_FILTER_IS_NEW_ITEM, true)
    
-- Сцена банка гильдии
    local bankScene = SCENE_MANAGER:GetScene("guildBank")
    
    local function AutoSelectDefaultGuildBank()
        local gid = NC.savedVars.guildBankDefaultGuildId
        if gid and gid > 0 then
            zo_callLater(function()
                ZO_SharedInventory_SelectAccessibleGuildBank(gid)
            end, 200)
        end
    end

    bankScene:RegisterCallback("StateChange", function(oldState, newState)
        if not NC.savedVars.guildBankEnabled then return end
        
        if newState == SCENE_SHOWING then
            NC.BankFrame:SetHidden(false)
            AutoSelectDefaultGuildBank()
        elseif newState == SCENE_HIDING then
            NC.BankFrame:SetHidden(true)
        end
    end)

    -- Проверка при старте (если мы уже в банке)
    if bankScene:GetState() == SCENE_SHOWING and NC.savedVars.guildBankEnabled then
        NC.BankFrame:SetHidden(false)
        AutoSelectDefaultGuildBank()
    else
        NC.BankFrame:SetHidden(true)
    end

    -- Отслеживание изменений сумок и банка для планарных ключей
    local isPlanarThrottled = false
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_PlanarKeyInv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(eventCode, bagId)
        if bagId == BAG_BACKPACK or bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK then
            if not isPlanarThrottled then
                isPlanarThrottled = true
                zo_callLater(function()
                    isPlanarThrottled = false
                    if NC.UpdatePlanarKeyWidgetDisplay then NC.UpdatePlanarKeyWidgetDisplay() end
                    if NC.UpdateCurrencyTracker then NC.UpdateCurrencyTracker() end
                end, 200)
            end
        end
    end)


    EVENT_MANAGER:RegisterForEvent(NC.name, EVENT_CHAT_MESSAGE_CHANNEL, NC.OnChatMessage)
    EVENT_MANAGER:RegisterForEvent(NC.name, EVENT_ACTIVITY_FINDER_STATUS_UPDATE, NC.OnActivityFinderStatusUpdate)
    EVENT_MANAGER:RegisterForEvent(NC.name, EVENT_CAMPAIGN_QUEUE_STATE_CHANGED, NC.OnCampaignQueueStateChange)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_MountSprint", EVENT_MOUNTED_STATE_CHANGED, function(eventCode, mounted) 
        NC.UpdateMountSprintToggle(mounted) 
        if NC.UpdateSpeedometer then NC.UpdateSpeedometer() end
    end)
    EVENT_MANAGER:RegisterForEvent(NC.name, EVENT_PLAYER_ACTIVATED, function()
        NC.isPlayerActivated = true
        NC.CheckTrialPets()
        NC.UpdateAggroMarker()
        NC.CheckZoneChangeForChestCounter()
        NC.CheckAllWornGear()
        if NC.UpdateFoodReminder then NC.UpdateFoodReminder() end
        if NC.UpdateMountSprintToggle then NC.UpdateMountSprintToggle(IsMounted()) end
        if NC.UpdateVeterancy then NC.UpdateVeterancy() end
        if NC.UpdateCurrencyTracker then NC.UpdateCurrencyTracker() end
        if NC.UpdatePlanarKeyWidgetDisplay then NC.UpdatePlanarKeyWidgetDisplay() end
        if NC.OnCameraCombatStateChanged then NC.OnCameraCombatStateChanged(IsUnitInCombat("player")) end

        -- Авто-проверка логов боя при входе/выходе из зон
        if NC.CheckAutoEncounterLog then
            zo_callLater(NC.CheckAutoEncounterLog, 1500)
        end
    end)

    -- Автообновление ранга Ветеранства при получении очков Альянса (AP)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_VeterancyAP", EVENT_ALLIANCE_POINT_UPDATE, function()
        if NC.UpdateVeterancy then NC.UpdateVeterancy() end
    end)

    -- Автообновление суточного трекера при изменении баланса валют или опыта
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_CurUpdate", EVENT_CURRENCY_UPDATE, function()
        if NC.UpdateCurrencyTracker then NC.UpdateCurrencyTracker() end
    end)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_XPUpdate", EVENT_EXPERIENCE_UPDATE, function()
        if NC.UpdateCurrencyTracker then NC.UpdateCurrencyTracker() end
    end)

    -- Авто-проверка починки и зарядки при выходе из боя и после воскрешения
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_CombatState", EVENT_PLAYER_COMBAT_STATE, function(eventCode, inCombat)
        if not inCombat then
            NC.CheckAllWornGear()
        end
        if NC.OnCameraCombatStateChanged then
            NC.OnCameraCombatStateChanged(inCombat)
        end
    end)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_PlayerAlive", EVENT_PLAYER_ALIVE, function()
        NC.CheckAllWornGear()
    end)
    EVENT_MANAGER:RegisterForEvent(NC.name, EVENT_GROUP_MEMBER_JOINED, function()
        NC.CheckAutoConvertToRaid()
    end)
    HookDialogSuppressions()
    
    -- Подключение модуля отображения качества и прочности экипировки
    NC.InitCharacterGearUI()

    -- Авто-обновление при ЛЮБОМ открытии окна персонажа (C)
    if ZO_Character then
        ZO_PostHookHandler(ZO_Character, "OnEffectivelyShown", function()
            if NC.UpdateAllCharacterGear then
                NC.UpdateAllCharacterGear()
            end
        end)
    end

    -- Обновление при смене сборки в оружейной
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_Armory", EVENT_ARMORY_BUILD_RESTORE_RESPONSE, function()
        if NC.UpdateAllCharacterGear then
            NC.UpdateAllCharacterGear()
        end
    end)
    
    -- Регистрация авто-починки у торговца
    EVENT_MANAGER:RegisterForEvent(NC.name, EVENT_OPEN_STORE, NC.OnOpenStore)

    -- Регистрация проверки надетого снаряжения со строгим фильтром BAG_WORN (надетые вещи)
    EVENT_MANAGER:RegisterForEvent(NC.name .. "_WornSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, NC.OnWornSlotUpdate)
    EVENT_MANAGER:AddFilterForEvent(NC.name .. "_WornSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    
    EVENT_MANAGER:RegisterForEvent(NC.name, EVENT_FRIEND_PLAYER_STATUS_CHANGED, function(eventCode, displayName, characterName, oldStatus, newStatus)
        if NC.isReady and newStatus == PLAYER_STATUS_ONLINE and NC.savedVars.trackedPlayers[displayName] then
            NC.ShowFriendNotification(displayName)
        end
    end)

    EVENT_MANAGER:RegisterForEvent(NC.name, EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED, function(eventCode, guildId, displayName, characterName, oldStatus, newStatus)
        if NC.isReady and newStatus == PLAYER_STATUS_ONLINE and NC.savedVars.trackedPlayers[displayName] then
            NC.ShowFriendNotification(displayName)
        end
    end)

-- Запуск хука для чата
    HookChatContextMenu()
-- Запуск фильтра истории лута
    HookLootHistoryFilter()
    
    NecroCat.Follow.Init()
    
    EVENT_MANAGER:UnregisterForEvent(NC.name, EVENT_ADD_ON_LOADED)
end

---------------------------------------------------------
-- 7. УПРАВЛЕНИЕ СЛОЖНОСТЬЮ
---------------------------------------------------------

NC.lastDifficultySwitchTime = 0

function NC.SetDifficulty(difficultyType)
    local reason = GetOverlandDifficultyDisabledReason()
    
    if reason ~= OVERLAND_DIFFICULTY_DISABLED_REASON_NONE then
        d("|cFF0000[NecroCat]|r Невозможно сменить сложность. Причина: " .. tostring(reason))
        return
    end

    local now = GetFrameTimeSeconds()
    if (now - NC.lastDifficultySwitchTime) < 10 then
        local remaining = math.ceil(10 - (now - NC.lastDifficultySwitchTime))
        NC.ShowDifficultyStatus("Подождите еще " .. remaining .. " сек.")
        return
    end

    NC.lastDifficultySwitchTime = now
    RequestChangePlayerOverlandDifficulty(difficultyType)
    NC.ShowDifficultyStatus("Сложность изменена!")
end

function NC.SetDiffAdventurer() NC.SetDifficulty(OVERLAND_DIFFICULTY_TYPE_ADVENTURER) end
function NC.SetDiffBasegame()   NC.SetDifficulty(OVERLAND_DIFFICULTY_TYPE_BASEGAME) end
function NC.SetDiffJourneyman() NC.SetDifficulty(OVERLAND_DIFFICULTY_TYPE_JOURNEYMAN) end
function NC.SetDiffVeteran()    NC.SetDifficulty(OVERLAND_DIFFICULTY_TYPE_VETERAN) end

---------------------------------------------------------
-- МОДУЛЬ: ИКОНКА БГ В СПИСКАХ ДРУЗЕЙ И ГИЛЬДИИ
---------------------------------------------------------
NecroCat = NecroCat or {}
local NC = NecroCat

NC.BgZoneNames = nil

-- Реестр всех ID Полей Сражений
local BG_ZONE_IDS = { 
    508, 509, 510, 511, 512, 513, 514, 515, 516, 517, 518, 520,
    1481, 1482, 1483, 1484, 1485, 1487, 1488 
}

local function BuildBattlegroundNamesCache()
    if NC.BgZoneNames then return end
    NC.BgZoneNames = {}

    for _, zoneId in ipairs(BG_ZONE_IDS) do
        local name = GetZoneNameById(zoneId)
        if name and name ~= "" then
            local clean = string.lower(zo_strformat("<<1>>", name))
            table.insert(NC.BgZoneNames, clean)
        end
    end
end

function NC.HookBattlegroundZoneIcons()
    BuildBattlegroundNamesCache()

    local function ApplyBgIcon(manager, control, data)
        local sv = NecroCat.savedVars or (NC and NC.savedVars)
        if sv and sv.showBgZoneIcon == false then return end
        if not control or not data or type(data) ~= "table" then return end

        local zoneLabel = control:GetNamedChild("Zone")
        if not zoneLabel or not zoneLabel.GetText then return end

        local rawZone = data.formattedZone or data.zone or zoneLabel:GetText()
        if not rawZone or type(rawZone) ~= "string" or rawZone == "" then return end

        local cleanZone = string.lower(zo_strformat("<<1>>", rawZone):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""))

        -- Мягкий поиск: проверяем, содержится ли точное название БГ внутри строки
        local isBG = false
        if NC.BgZoneNames then
            for _, bgName in ipairs(NC.BgZoneNames) do
                if bgName ~= "" and string.find(cleanZone, bgName, 1, true) then
                    isBG = true
                    break
                end
            end
        end

        if isBG then
            local currentText = zoneLabel:GetText()
            if currentText and not string.find(currentText, "poi_battlefield_complete") then
                zoneLabel:SetText("|t16:16:EsoUI/Art/Icons/poi/poi_battlefield_complete.dds|t " .. currentText)
            end
        end
    end

    if FRIENDS_LIST and FRIENDS_LIST.SetupRow then
        ZO_PostHook(FRIENDS_LIST, "SetupRow", ApplyBgIcon)
    end

    if GUILD_ROSTER_KEYBOARD and GUILD_ROSTER_KEYBOARD.SetupRow then
        ZO_PostHook(GUILD_ROSTER_KEYBOARD, "SetupRow", ApplyBgIcon)
    end
end

---------------------------------------------------------
-- МОДУЛЬ: ЦВЕТНЫЕ ИКОНКИ КЛАССОВ И АЛЬЯНСОВ
---------------------------------------------------------
function NC.ApplyCustomIcons()
    if not NC.savedVars or not NC.savedVars.customColorIcons then return end

    -- 1. Иконки классов (Клавиатура 32x32)
    RedirectTexture("esoui/art/icons/class/class_dragonknight.dds", "NecroCat/imgs/icons/dragonknight32.dds")
    RedirectTexture("esoui/art/icons/class/class_necromancer.dds", "NecroCat/imgs/icons/necro32.dds")
    RedirectTexture("esoui/art/icons/class/class_nightblade.dds", "NecroCat/imgs/icons/nightblade32.dds")
    RedirectTexture("esoui/art/icons/class/class_sorcerer.dds", "NecroCat/imgs/icons/sorc32.dds")
    RedirectTexture("esoui/art/icons/class/class_templar.dds", "NecroCat/imgs/icons/templar32.dds")
    RedirectTexture("esoui/art/icons/class/class_warden.dds", "NecroCat/imgs/icons/warden32.dds")
    RedirectTexture("esoui/art/icons/class/class_arcanist.dds", "NecroCat/imgs/icons/arcanist32.dds")

    -- 2. Иконки классов (Геймпад 64x64)
    RedirectTexture("esoui/art/icons/class/gamepad/gp_class_dragonknight.dds", "NecroCat/imgs/icons/gpdragonknight.dds")
    RedirectTexture("esoui/art/icons/class/gamepad/gp_class_necromancer.dds", "NecroCat/imgs/icons/gpnecro.dds")
    RedirectTexture("esoui/art/icons/class/gamepad/gp_class_nightblade.dds", "NecroCat/imgs/icons/gpnightblade.dds")
    RedirectTexture("esoui/art/icons/class/gamepad/gp_class_sorcerer.dds", "NecroCat/imgs/icons/gpsorc.dds")
    RedirectTexture("esoui/art/icons/class/gamepad/gp_class_templar.dds", "NecroCat/imgs/icons/gptemplar.dds")
    RedirectTexture("esoui/art/icons/class/gamepad/gp_class_warden.dds", "NecroCat/imgs/icons/gpwarden.dds")
    RedirectTexture("esoui/art/icons/class/gamepad/gp_class_arcanist.dds", "NecroCat/imgs/icons/arcanist64.dds")

    -- 3. Значки Альянсов (32, 64, 128)
    RedirectTexture("esoui/art/contacts/social_allianceicon_aldmeri.dds", "NecroCat/imgs/icons/aldmeri32.dds")
    RedirectTexture("esoui/art/contacts/social_allianceicon_daggerfall.dds", "NecroCat/imgs/icons/daggerfall32.dds")
    RedirectTexture("esoui/art/contacts/social_allianceicon_ebonheart.dds", "NecroCat/imgs/icons/ebonheart32.dds")
    RedirectTexture("esoui/art/stats/alliancebadge_aldmeri.dds", "NecroCat/imgs/icons/aldmeri64.dds")
    RedirectTexture("esoui/art/stats/alliancebadge_daggerfall.dds", "NecroCat/imgs/icons/daggerfall64.dds")
    RedirectTexture("esoui/art/stats/alliancebadge_ebonheart.dds", "NecroCat/imgs/icons/ebonheart64.dds")
    RedirectTexture("esoui/art/ava/avacapturebar_alliancebadge_aldmeri.dds", "NecroCat/imgs/icons/aldmeri128.dds")
    RedirectTexture("esoui/art/ava/avacapturebar_alliancebadge_daggerfall.dds", "NecroCat/imgs/icons/daggerfall128.dds")
    RedirectTexture("esoui/art/ava/avacapturebar_alliancebadge_ebonheart.dds", "NecroCat/imgs/icons/ebonheart128.dds")

    -- 4. Торговец и Война Альянсов
    RedirectTexture("esoui/art/guild/gamepad/gp_ownership_icon_guildtrader.dds", "NecroCat/imgs/icons/guildtrader64.dds")
    RedirectTexture("esoui/art/guild/ownership_icon_guildtrader.dds", "NecroCat/imgs/icons/guildtrader128.dds")
    RedirectTexture("esoui/art/guild/ownership_icon_keep.dds", "NecroCat/imgs/icons/alliancewarowned.dds")

    -- 5. Иконки Чемпионской системы (ЧП)
    RedirectTexture("esoui/art/champion/champion_icon.dds", "NecroCat/imgs/icons/cpsmall.dds")
    RedirectTexture("esoui/art/champion/champion_icon_32.dds", "NecroCat/imgs/icons/cpsmall32.dds")
    RedirectTexture("esoui/art/champion/gamepad/gp_champion_icon.dds", "NecroCat/imgs/icons/cpsmall.dds")
end

EVENT_MANAGER:RegisterForEvent(NC.name, EVENT_ADD_ON_LOADED, NC.OnAddOnLoaded)


-- =========================================================
-- МОДУЛЬ: ПРИВЯЗКА ДОМОВ ИГРОКОВ (BOOKMARKS)
-- =========================================================

-- Получение красивого названия дома по его ID
function NC.GetHouseNameById(houseId)
    if not houseId or houseId <= 0 then return "Неизвестный дом" end
    if GetCollectibleIdForHouse then
        local collectibleId = GetCollectibleIdForHouse(houseId)
        if collectibleId and collectibleId > 0 then
            local name = GetCollectibleName(collectibleId)
            if name and name ~= "" then
                return zo_strformat("<<1>>", name)
            end
        end
    end
    return "Дом #" .. tostring(houseId)
end

-- Добавление / перемещение дома для конкретного игрока (с поддержкой истинного владельца)
function NC.AddHouseToPlayer(displayName, houseId, houseName, targetPos, actualOwner)
    if not displayName or displayName == "" or not houseId or houseId <= 0 then return end
    
    NC.savedVars.playerHouses = NC.savedVars.playerHouses or {}
    NC.savedVars.playerHouses[displayName] = NC.savedVars.playerHouses[displayName] or {}
    
    local list = NC.savedVars.playerHouses[displayName]
    local realOwner = (actualOwner and actualOwner ~= "") and actualOwner or displayName
    local finalName = (houseName and houseName ~= "") and houseName or NC.GetHouseNameById(houseId)

    -- Если дом чужой, а записывается в твой список - аккуратно помечаем ник владельца в названии
    if realOwner ~= displayName and not string.find(finalName, "@") then
        finalName = string.format("%s (%s)", finalName, realOwner)
    end

    -- Удаляем этот же дом у того же владельца, если он уже был записан ранее
    for i = #list, 1, -1 do
        if list[i].houseId == houseId and (list[i].owner == realOwner or list[i].owner == nil) then
            table.remove(list, i)
        end
    end

    local pos = tonumber(targetPos) or (#list + 1)
    if pos < 1 then pos = 1 end
    if pos > (#list + 1) then pos = #list + 1 end

    table.insert(list, pos, { houseId = houseId, name = finalName, owner = realOwner })

    d(zo_strformat(GetString(SI_NC_HOUSE_SAVED), finalName, displayName, pos))
end

-- Удаление дома по номеру позиции
function NC.RemoveHouseFromPlayer(displayName, pos)
    if not displayName or not NC.savedVars.playerHouses or not NC.savedVars.playerHouses[displayName] then
        d("|cFF0000[NecroCat]|r У игрока " .. tostring(displayName) .. " нет сохраненных домов.")
        return
    end

    local list = NC.savedVars.playerHouses[displayName]
    local index = tonumber(pos)

    if index and list[index] then
        local removed = table.remove(list, index)
        d(zo_strformat(GetString(SI_NC_HOUSE_DELETED), removed.name, index, displayName))
        if #list == 0 then
            NC.savedVars.playerHouses[displayName] = nil
        end
    else
        d("|cFF0000[NecroCat]|r Неверный номер позиции дома.")
    end
end

-- =========================================================
-- ЛОГИКА СОРТИРОВКИ ГИЛЬДИЙ
-- =========================================================

function NC.GetSortedGuildList()
    local guildList = {}
    local assignedGids = {}
    local numGuilds = GetNumGuilds()

    -- 1. Сначала берем гильдии из настроенных слотов 1..5
    if NC.savedVars.customGuildOrder then
        for slot = 1, 5 do
            local targetGid = NC.savedVars.customGuildOrder[slot]
            if targetGid and targetGid > 0 then
                for i = 1, numGuilds do
                    local gid = GetGuildId(i)
                    if gid == targetGid and not assignedGids[gid] then
                        table.insert(guildList, {
                            guildId    = gid,
                            guildIndex = i,
                            guildName  = GetGuildName(gid),
                            slot       = slot,
                        })
                        assignedGids[gid] = true
                        break
                    end
                end
            end
        end
    end

    -- 2. Все остальные гильдии добавляем следом в их обычном порядке
    for i = 1, numGuilds do
        local gid = GetGuildId(i)
        if not assignedGids[gid] then
            table.insert(guildList, {
                guildId    = gid,
                guildIndex = i,
                guildName  = GetGuildName(gid),
                slot       = nil,
            })
        end
    end

    return guildList
end

-- Функция перехвата и сортировки выпадающего списка гильдий
function NC.HookGuildSelector()
    if not ZO_GuildSelectorComboBox then return end
    local cb = ZO_ComboBox_ObjectFromContainer(ZO_GuildSelectorComboBox)
    if not cb then return end

    ZO_PreHook(cb, "ShowDropdown", function(self)
        if not NC.savedVars.customGuildOrder then return end

        local sortedGuilds = NC.GetSortedGuildList()
        if #sortedGuilds == 0 then return end

        local guildEntries = {}
        local otherEntries = {}

        -- Разделяем гильдии и служебные пункты (Поиск/Создание)
        for _, entry in ipairs(self.m_sortedItems or {}) do
            local isGuild = false
            for _, gData in ipairs(sortedGuilds) do
                if (entry.guildId and entry.guildId == gData.guildId) or (entry.name and string.find(entry.name, gData.guildName, 1, true)) then
                    entry.ncGuildId = gData.guildId
                    table.insert(guildEntries, entry)
                    isGuild = true
                    break
                end
            end
            if not isGuild then
                table.insert(otherEntries, entry)
            end
        end

        -- Сортируем гильдии в порядке из наших настроек
        local orderMap = {}
        for index, gData in ipairs(sortedGuilds) do
            orderMap[gData.guildId] = index
        end

        table.sort(guildEntries, function(a, b)
            local orderA = orderMap[a.ncGuildId] or 99
            local orderB = orderMap[b.ncGuildId] or 99
            return orderA < orderB
        end)

        -- Собираем итоговый правильный список
        local newItems = {}
        for _, entry in ipairs(guildEntries) do
            table.insert(newItems, entry)
        end
        for _, entry in ipairs(otherEntries) do
            table.insert(newItems, entry)
        end

        self.m_sortedItems = newItems
    end)
end

-- =========================================================
-- ЛОГИКА ЗАКРЕПЛЕНИЯ ДРУЗЕЙ (МЫ ПЕРЕНЕСЛИ ЕЁ СЮДА!)
-- =========================================================

-- Функция для закрепления со сдвигом
function NC.PinAndShift(targetName, targetPriority)
    NC.savedVars.pinned[targetName] = nil

    for name, priority in pairs(NC.savedVars.pinned) do
        if priority >= targetPriority then
            NC.savedVars.pinned[name] = priority + 1
        end
    end

    NC.savedVars.pinned[targetName] = targetPriority

    local tempArray = {}
    for name, priority in pairs(NC.savedVars.pinned) do
        table.insert(tempArray, { name = name, priority = priority })
    end

    table.sort(tempArray, function(a, b)
        return a.priority < b.priority
    end)

    NC.savedVars.pinned = {}
    for index, item in ipairs(tempArray) do
        NC.savedVars.pinned[item.name] = index
    end
end

-- Функция для открепления со схлопыванием
function NC.UnpinAndNormalize(targetName)
    NC.savedVars.pinned[targetName] = nil

    local tempArray = {}
    for name, priority in pairs(NC.savedVars.pinned) do
        table.insert(tempArray, { name = name, priority = priority })
    end

    table.sort(tempArray, function(a, b)
        return a.priority < b.priority
    end)

    NC.savedVars.pinned = {}
    for index, item in ipairs(tempArray) do
        NC.savedVars.pinned[item.name] = index
    end
end

-- Функция сортировки закреплений (Список друзей + Список гильдии)
function NC.HookFriendsSorting()
    -- 1. Сортировка списка друзей
    if FRIENDS_LIST and FRIENDS_LIST.sortFunction then
        local origFriendsSort = FRIENDS_LIST.sortFunction
        FRIENDS_LIST.sortFunction = function(listEntry1, listEntry2)
            if listEntry1 and listEntry2 and listEntry1.data and listEntry2.data then
                local name1 = listEntry1.data.displayName
                local name2 = listEntry2.data.displayName

                if name1 and name2 and NC.savedVars and NC.savedVars.pinned then
                    local p1 = NC.savedVars.pinned[name1]
                    local p2 = NC.savedVars.pinned[name2]

                    if p1 and not p2 then return true
                    elseif not p1 and p2 then return false
                    elseif p1 and p2 then
                        if p1 ~= p2 then return p1 < p2 end
                        return name1 < name2
                    end
                end
            end
            return origFriendsSort(listEntry1, listEntry2)
        end
    end

    -- 2. Сортировка списка участников гильдии
    if GUILD_ROSTER_KEYBOARD and GUILD_ROSTER_KEYBOARD.sortFunction then
        local origGuildSort = GUILD_ROSTER_KEYBOARD.sortFunction
        GUILD_ROSTER_KEYBOARD.sortFunction = function(listEntry1, listEntry2)
            if listEntry1 and listEntry2 and listEntry1.data and listEntry2.data then
                local name1 = listEntry1.data.displayName
                local name2 = listEntry2.data.displayName

                if name1 and name2 and NC.savedVars and NC.savedVars.pinned then
                    local p1 = NC.savedVars.pinned[name1]
                    local p2 = NC.savedVars.pinned[name2]

                    if p1 and not p2 then return true
                    elseif not p1 and p2 then return false
                    elseif p1 and p2 then
                        if p1 ~= p2 then return p1 < p2 end
                        return name1 < name2
                    end
                end
            end
            return origGuildSort(listEntry1, listEntry2)
        end
    end
end

-- =========================================================
-- КОМАНДЫ УПРАВЛЕНИЯ В ЧАТЕ
-- =========================================================

SLASH_COMMANDS["/pinfriend"] = function(argStr)
    local displayName, priorityStr = string.match(argStr, "^(%S+)%s*(%d*)$")
    local priority = tonumber(priorityStr) or 1

    if not displayName or displayName == "" then
        d("[NecroCat] Использование: /pinfriend @ИмяДруга Позиция")
        return
    end

    NC.PinAndShift(displayName, priority)
    d(string.format("[NecroCat] %s теперь на позиции %d! Остальные сдвинулись.", displayName, priority))

    if FRIENDS_LIST then FRIENDS_LIST:RefreshData() end
    if GUILD_ROSTER_KEYBOARD then GUILD_ROSTER_KEYBOARD:RefreshData() end
end

SLASH_COMMANDS["/unpinfriend"] = function(displayName)
    displayName = displayName and string.match(displayName, "(%S+)")
    if not displayName or displayName == "" then
        d("[NecroCat] Использование: /unpinfriend @ИмяДруга")
        return
    end

    if NC.savedVars.pinned[displayName] then
        NC.UnpinAndNormalize(displayName)
        d(string.format("[NecroCat] Друг %s удален, позиции остальных скорректированы.", displayName))
        if FRIENDS_LIST then FRIENDS_LIST:RefreshData() end
        if GUILD_ROSTER_KEYBOARD then GUILD_ROSTER_KEYBOARD:RefreshData() end
    else
        d(string.format("[NecroCat] Друг %s не найден в закрепленных.", displayName))
    end
end

SLASH_COMMANDS["/pinclear"] = function()
    NC.savedVars.pinned = {}
    d("[NecroCat] Список закрепленных друзей полностью очищен!")
    if FRIENDS_LIST then FRIENDS_LIST:RefreshData() end
    if GUILD_ROSTER_KEYBOARD then GUILD_ROSTER_KEYBOARD:RefreshData() end
end

SLASH_COMMANDS["/guildsclear"] = function()
    NC.savedVars.customGuildOrder = {}
    d("[NecroCat] Порядок всех гильдий сброшен на стандартный!")
    if GUILD_SHARED_INFO and GUILD_SHARED_INFO.UpdateGuildSelector then
        GUILD_SHARED_INFO:UpdateGuildSelector()
    end
end

SLASH_COMMANDS["/housepin"] = function(argStr)
    argStr = argStr or ""
    local houseId, targetDisplayName, actualOwner, houseName, targetPos

    -- 1. Проверяем, указан ли в начале целевой список (@Ник)
    local leadingName = string.match(argStr, "^(@%S+)%s+")

    -- 2. Ищем ссылку на дом любого вида: |H...:housing:ID:OWNER...|h
    local linkId, linkOwner = string.match(argStr, "|H%d:housing:(%d+):(@?[^:|]+)")
    if linkId and linkOwner then
        houseId = tonumber(linkId)
        actualOwner = linkOwner
        targetDisplayName = leadingName or linkOwner -- Если указан @Ник в начале - пишем ему, иначе владельцу ссылки

        local linkText = string.match(argStr, "|h%[?(.-)%]?|h")
        if linkText and linkText ~= "" then
            houseName = linkText
        end

        local afterLink = string.gsub(argStr, "|H.-|h", "")
        if leadingName then
            afterLink = string.gsub(afterLink, "^@%S+", "")
        end
        targetPos = tonumber(string.match(afterLink, "(%d+)"))
    else
        -- 3. Формат без ссылки: @Ник ID_дома [позиция]
        local nameMatch, idMatch, posMatch = string.match(argStr, "^(@%S+)%s+(%d+)%s*(%d*)$")
        if nameMatch and idMatch then
            targetDisplayName = nameMatch
            actualOwner = nameMatch
            houseId = tonumber(idMatch)
            targetPos = tonumber(posMatch)
        end
    end

    if not targetDisplayName or not houseId or houseId <= 0 then
        d("|c66f2ff[NecroCat]|r Использование /housepin:")
        d("  1. Чужой дом себе: |c22ff22/housepin @ТвойНик [Ссылка] [Номер]|r")
        d("  2. Дом в список друга: |c22ff22/housepin [Ссылка] [Номер]|r")
        d("  3. По ID дома: |c22ff22/housepin @Ник ID_дома [Номер]|r")
        return
    end

    if not string.find(targetDisplayName, "^@") then targetDisplayName = "@" .. targetDisplayName end
    if actualOwner and not string.find(actualOwner, "^@") then actualOwner = "@" .. actualOwner end

    NC.AddHouseToPlayer(targetDisplayName, houseId, houseName, targetPos, actualOwner)
end

SLASH_COMMANDS["/unhousepin"] = function(argStr)
    local displayName, pos = string.match(argStr or "", "^(@?%S+)%s*(%d*)$")
    if not displayName or displayName == "" then
        d("[NecroCat] Использование: /unhousepin @Ник [Позиция]")
        return
    end
    if not string.find(displayName, "^@") then displayName = "@" .. displayName end

    local list = NC.savedVars.playerHouses and NC.savedVars.playerHouses[displayName]
    if not list or #list == 0 then
        d(string.format("[NecroCat] У %s нет сохраненных домов.", displayName))
        return
    end

    local targetIndex = tonumber(pos)
    -- Если номер не указан, но у человека всего 1 дом — удаляем его сразу
    if not targetIndex and #list == 1 then
        targetIndex = 1
    end

    if not targetIndex then
        d(string.format("[NecroCat] У %s несколько домов. Укажите номер для удаления:", displayName))
        for i, h in ipairs(list) do
            d(string.format("  /unhousepin %s %d  (для «%s»)", displayName, i, h.name))
        end
        return
    end

    NC.RemoveHouseFromPlayer(displayName, targetIndex)
end

SLASH_COMMANDS["/listhouses"] = function(displayName)
    displayName = displayName and string.match(displayName, "(%S+)")
    if not displayName or displayName == "" then
        d("[NecroCat] Использование: /listhouses @Ник")
        return
    end
    if not string.find(displayName, "^@") then displayName = "@" .. displayName end

    local list = NC.savedVars.playerHouses and NC.savedVars.playerHouses[displayName]
    if not list or #list == 0 then
        d(string.format("[NecroCat] У %s нет сохраненных домов.", displayName))
        return
    end

    d(string.format("|c66f2ff[NecroCat]|r Дома игрока |cFFFF22%s|r:", displayName))
    for i, hData in ipairs(list) do
        d(string.format("  |c00FF00%d.|r %s (ID: %d)", i, hData.name, hData.houseId))
    end
end

SLASH_COMMANDS["/clearhouses"] = function(displayName)
    displayName = displayName and string.match(displayName, "(%S+)")
    if not displayName or displayName == "" then
        d("[NecroCat] Использование: /clearhouses @Ник")
        return
    end
    if not string.find(displayName, "^@") then displayName = "@" .. displayName end

    if NC.savedVars.playerHouses then
        NC.savedVars.playerHouses[displayName] = nil
    end
    d(string.format("[NecroCat] Все сохраненные дома игрока %s удалены.", displayName))
end

SLASH_COMMANDS["/necrocat"] = function() NC.OpenSettings() end
SLASH_COMMANDS["/nc"]       = function() NC.OpenSettings() end
SLASH_COMMANDS["/kickrandoms"] = function() NC.KickNonFavorites() end
SLASH_COMMANDS["/nckick"]       = function() NC.KickNonFavorites() end
-- =========================================================
-- СПРАВОЧНАЯ КОМАНДА NECROCAT
-- =========================================================

SLASH_COMMANDS["/necrohelp"] = function()
    d("|c66f2ff================ [NecroCat Справка] ================|r")
    d("|cffff22👑 Закрепление друзей (Друзья 'O' и Гильдии 'G'):|r")
    d("  |c22ff22/pinfriend @Имя [Позиция]|r - Закрепить друга со сдвигом.")
    d("  |c22ff22/unpinfriend @Имя|r - Убрать друга из закрепленных.")
    d("  |c22ff22/listpinned|r - Показать список закрепленных.")
    d("  |c22ff22/pinclear|r - Сбросить все закрепления.")
    d("|cffff22🏠 Дома игроков (Закладки и Телепорт):|r")
    d("  |c22ff22/housepin [Ссылка] [Номер]|r - Записать дом в список хозяина.")
    d("  |c22ff22/housepin @Кому [Ссылка] [Номер]|r - Записать чужой дом себе.")
    d("  |c22ff22/housepin @Имя ID [Номер]|r - Записать дом по номеру ID.")
    d("  |c22ff22/unhousepin @Имя [Номер]|r - Удалить дом из списка игрока.")
    d("  |c22ff22/listhouses @Имя|r - Показать список домов игрока.")
    d("  |c22ff22/clearhouses @Имя|r - Очистить все дома игрока.")
    d("|cffff22⚙️ Настройки и Гильдии:|r")
    d("  |c22ff22/necrocat|r или |c22ff22/nc|r - Меню настроек аддона.")
    d("  |c22ff22/guildsclear|r - Сбросить порядок гильдий на стандартный.")
    d("|c66f2ff====================================================|r")
end