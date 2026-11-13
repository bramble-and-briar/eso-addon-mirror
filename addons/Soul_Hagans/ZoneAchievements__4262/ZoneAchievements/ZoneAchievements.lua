-- ZoneAchievements.lua (полная версия с вкладками, историей, разделителем и лестницей испытаний)
local ADDON_NAME = "ZoneAchievements"
ZoneAchievements = ZoneAchievements or {}
local ZA = ZoneAchievements
local L = ZA.L or {}

ZA.Cache = ZA.Cache or {}
ZA.RecentUpdates = ZA.RecentUpdates or {}
ZA.CurrentTab = "zone" -- Активная вкладка по умолчанию

local ZA_EXPECTED = _G["ZA_Names"] or {}

-- Вспомогательный массив для отслеживания созданных строк
local createdRows = {}

-- Получаем ID и название зоны
function ZA:GetCurrentZoneInfo()
    local zoneId
    local rawZoneName

    if self.DevLockedZoneId and self.DevLockedZoneId > 0 then
        zoneId = self.DevLockedZoneId
        rawZoneName = GetZoneNameById(zoneId) or "Заблокированная зона"
    else
        zoneId = GetUnitWorldPosition("player") or 0
        rawZoneName = (zoneId > 0 and GetZoneNameById(zoneId)) or GetUnitZone('player') or "Неизвестно"
    end

    local cleanZoneName = zo_strformat("<<1>>", rawZoneName)
    return zoneId, cleanZoneName
end

-- Получаем информацию об ачивке
function ZA:GetAchievementInfo(achievementId)
    local name, description, points, icon, completed, earned, category, hidden = GetAchievementInfo(achievementId)
    local cleanName = name and zo_strformat("<<1>>", name) or (L and L.unknown or "Unknown")
    local cleanDesc = description and zo_strformat("<<1>>", description) or ""
    return {
        id = achievementId,
        name = cleanName,
        desc = cleanDesc,
        points = points or 0,
        icon = icon or "/esoui/art/icons/icon_missing.dds",
        completed = completed or false,
        earned = earned or false
    }
end

-- Прогресс
function ZA:GetAchievementProgress(achievementId)
    local numCriteria = GetAchievementNumCriteria(achievementId)
    if not numCriteria or numCriteria == 0 then
        local completed = select(5, GetAchievementInfo(achievementId))
        return completed and 1 or 0, 1
    end
    local done, total = 0, 0
    for i = 1, numCriteria do
        local _, numCompleted, numRequired = GetAchievementCriterion(achievementId, i)
        done = done + (numCompleted or 0)
        total = total + (numRequired or 0)
    end
    return done, total
end

-- Черный список ачивок, содержащих слово "ветеран", но не являющихся ветеранским режимом
local VET_BLACKLIST = {
    [4062] = true, -- Ветеран Архива I
    [4063] = true, -- Ветеран Архива II
}

-- Проверка, требует ли ачивка ветеранский режим (по названию, описанию и критериям)
function ZA:IsVeteranAchievement(achInfo)
    if not achInfo or VET_BLACKLIST[achInfo.id] then return false end
    local keywords = { "ветеран", "veteran", "vétéran" }

    -- 1. Сканируем название и описание (через zo_strlower для идеального учета русского регистра)
    local fullText = zo_strlower(string.format("%s %s", achInfo.name or "", achInfo.desc or ""))
    for _, kw in ipairs(keywords) do
        if string.find(fullText, kw, 1, true) then
            return true
        end
    end

    -- 2. Страховка: сканируем условия (критерии) ачивки
    local numCriteria = GetAchievementNumCriteria(achInfo.id) or 0
    for i = 1, numCriteria do
        local critDesc = GetAchievementCriterion(achInfo.id, i)
        if critDesc and critDesc ~= "" then
            local critText = zo_strlower(critDesc)
            for _, kw in ipairs(keywords) do
                if string.find(critText, kw, 1, true) then
                    return true
                end
            end
        end
    end

    return false
end

-- Получить особый тип ачивки (сначала смотрим в SavedVars, потом в ZA_Data.lua)
function ZA:GetAchievementSpecialType(achievementId)
    if self.SavedVars and self.SavedVars.SpecialTypes and self.SavedVars.SpecialTypes[achievementId] then
        return self.SavedVars.SpecialTypes[achievementId]
    end
    local globalSpecial = _G["ZA_SPECIAL_TYPES"]
    if globalSpecial and globalSpecial[achievementId] then
        return globalSpecial[achievementId]
    end
    return nil
end

-- Установить или снять особую метку
function ZA:SetAchievementSpecialType(achievementId, specialType)
    if not self.SavedVars then return end
    self.SavedVars.SpecialTypes = self.SavedVars.SpecialTypes or {}
    
    if specialType == nil then
        self.SavedVars.SpecialTypes[achievementId] = nil
        PlaySound(SOUNDS.DEFAULT_CLICK)
    else
        self.SavedVars.SpecialTypes[achievementId] = specialType
        PlaySound(SOUNDS.BOOK_ACQUIRED)
    end

    -- Формируем красивый экспорт для SavedVariables
    self.SavedVars.DevSpecialFormatted = {}
    table.insert(self.SavedVars.DevSpecialFormatted, "ZA_SPECIAL_TYPES = {")
    for id, sType in pairs(self.SavedVars.SpecialTypes) do
        local achName = select(1, GetAchievementInfo(id)) or "Unknown"
        local cleanName = zo_strformat("<<1>>", achName)
        local line = string.format('    [%d] = "%s", -- %s', id, sType, cleanName)
        table.insert(self.SavedVars.DevSpecialFormatted, line)
    end
    table.insert(self.SavedVars.DevSpecialFormatted, "}")

    self:ShowZoneAchievementsWindow()
end

-- ================= Окно =================
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 500, 520

local ZAWindow = WINDOW_MANAGER:CreateTopLevelWindow("ZoneAchievements_Window")
ZAWindow:SetDimensions(DEFAULT_WIDTH, DEFAULT_HEIGHT)
ZAWindow:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
ZAWindow:SetMovable(true)
ZAWindow:SetClampedToScreen(true)
ZAWindow:SetHidden(true)
ZAWindow:SetMouseEnabled(true)
ZAWindow:SetResizeHandleSize(10)
ZAWindow:SetHandler("OnShow", function()
    SCENE_MANAGER:SetInUIMode(true)
end)

ZAWindow:SetHandler("OnHide", function()
    SCENE_MANAGER:SetInUIMode(false)
end)

-- Фон
local bg = WINDOW_MANAGER:CreateControl(nil, ZAWindow, CT_BACKDROP)
bg:SetAnchorFill()
bg:SetCenterColor(0, 0, 0, 0.7)
bg:SetEdgeColor(0.7, 0.7, 0.7, 1)

-- Заголовок
local title = WINDOW_MANAGER:CreateControl(nil, ZAWindow, CT_LABEL)
title:SetFont("ZoFontWinH1")
title:SetAnchor(TOP, ZAWindow, TOP, 0, 10)
title:SetText("|c39DB92Zone Achievements|r")

-- ПОДЗАГОЛОВОК ЗОНЫ
local zoneLabel = WINDOW_MANAGER:CreateControl(nil, ZAWindow, CT_LABEL)
zoneLabel:SetFont("ZoFontGameLargeBold")
zoneLabel:SetAnchor(TOP, title, BOTTOM, 0, 2)
zoneLabel:SetColor(1, 1, 1, 1)
ZA.ZoneLabel = zoneLabel

-- Кнопка закрытия
local closeBtn = WINDOW_MANAGER:CreateControl(nil, ZAWindow, CT_BUTTON)
closeBtn:SetDimensions(40, 40)
closeBtn:SetAnchor(TOPRIGHT, ZAWindow, TOPRIGHT, 5, 5)
closeBtn:SetNormalTexture("EsoUI/Art/Buttons/closebutton_up.dds")
closeBtn:SetPressedTexture("EsoUI/Art/Buttons/closebutton_down.dds")
closeBtn:SetHandler("OnClicked", function() ZAWindow:SetHidden(true) end)

-- == КОНТЕЙНЕР ВКЛАДОК ==
local tabContainer = WINDOW_MANAGER:CreateControl("ZoneAchievements_TabContainer", ZAWindow, CT_CONTROL)
tabContainer:SetDimensions(250, 30)
tabContainer:SetAnchor(TOP, zoneLabel, BOTTOM, 0, 6)

local tabZone = WINDOW_MANAGER:CreateControlFromVirtual("ZoneAchievements_TabZone", tabContainer, "ZO_DefaultTextButton")
tabZone:SetText(L.tabZone)
tabZone:SetDimensions(110, 25)
tabZone:SetAnchor(LEFT, tabContainer, LEFT, 0, 0)

local tabHistory = WINDOW_MANAGER:CreateControlFromVirtual("ZoneAchievements_TabHistory", tabContainer, "ZO_DefaultTextButton")
tabHistory:SetText(L.tabHistory)
tabHistory:SetDimensions(110, 25)
tabHistory:SetAnchor(RIGHT, tabContainer, RIGHT, 0, 0)

-- Функция обновления подсветки вкладок
function ZA:UpdateTabVisuals()
    if self.CurrentTab == "history" then
        tabZone:SetNormalFontColor(0.6, 0.6, 0.6, 1)
        tabHistory:SetNormalFontColor(0.9, 0.7, 0.2, 1)
    else
        tabZone:SetNormalFontColor(0.9, 0.7, 0.2, 1)
        tabHistory:SetNormalFontColor(0.6, 0.6, 0.6, 1)
    end
end

tabZone:SetHandler("OnClicked", function()
    ZA.CurrentTab = "zone"
    ZA:UpdateTabVisuals()
    ZA:ShowZoneAchievementsWindow()
end)

tabHistory:SetHandler("OnClicked", function()
    ZA.CurrentTab = "history"
    ZA:UpdateTabVisuals()
    ZA:ShowZoneAchievementsWindow()
end)

-- ================= ВСПЛЫВАЮЩЕЕ ОКНО (TOAST HUD) =================
local ZAToast = WINDOW_MANAGER:CreateTopLevelWindow("ZoneAchievements_Toast")
ZAToast:SetDimensions(360, 60)
ZAToast:SetAnchor(TOP, GuiRoot, TOP, 0, 150)
ZAToast:SetHidden(true)
ZAToast:SetClampedToScreen(true)
ZAToast:SetMovable(true)
ZAToast:SetMouseEnabled(true)

local toastBg = WINDOW_MANAGER:CreateControl(nil, ZAToast, CT_BACKDROP)
toastBg:SetAnchorFill()
toastBg:SetCenterColor(0, 0, 0, 0.85)
toastBg:SetEdgeColor(0.9, 0.7, 0.2, 1)
toastBg:SetEdgeTexture(nil, 1, 1, 1, 1)

local toastIcon = WINDOW_MANAGER:CreateControl(nil, ZAToast, CT_TEXTURE)
toastIcon:SetDimensions(44, 44)
toastIcon:SetAnchor(LEFT, ZAToast, LEFT, 8, 0)
toastIcon:SetTexture("/esoui/art/icons/icon_missing.dds")

local toastTitle = WINDOW_MANAGER:CreateControl(nil, ZAToast, CT_LABEL)
toastTitle:SetFont("ZoFontWinH4")
toastTitle:SetAnchor(TOPLEFT, toastIcon, TOPRIGHT, 10, 2)
toastTitle:SetColor(1, 1, 1, 1)

local toastProgress = WINDOW_MANAGER:CreateControl(nil, ZAToast, CT_LABEL)
toastProgress:SetFont("ZoFontGameSmall")
toastProgress:SetAnchor(BOTTOMLEFT, toastIcon, BOTTOMRIGHT, 10, -2)
toastProgress:SetColor(0.7, 0.7, 0.7, 1)

ZAToast:SetHandler("OnMoveStop", function()
    ZA.SavedVars.toastLeft, ZA.SavedVars.toastTop = ZAToast:GetLeft(), ZAToast:GetTop()
end)

-- Скролл-контейнер
local scroll = WINDOW_MANAGER:CreateControlFromVirtual("ZoneAchievements_Scroll", ZAWindow, "ZO_ScrollContainer")
scroll:SetAnchor(TOPLEFT, ZAWindow, TOPLEFT, 14, 115)
scroll:SetDimensions(DEFAULT_WIDTH - 28, DEFAULT_HEIGHT - 135)

local scrollChild = scroll:GetNamedChild("ScrollChild")
scrollChild:SetAnchor(TOPLEFT, scrollChild:GetParent(), TOPLEFT, 0, 0)
scrollChild:SetWidth(scroll:GetWidth() - 10)

-- Очистка
local function ClearScrollChild()
    if not scrollChild then return end

    if type(scrollChild.RemoveAllChildren) == "function" then
        scrollChild:RemoveAllChildren()
    else
        for i = scrollChild:GetNumChildren(), 1, -1 do
            local child = scrollChild:GetChild(i)
            if child then
                if type(child.Destroy) == "function" then
                    child:Destroy()
                else
                    child:SetHidden(true)
                    child:ClearAnchors()
                    child:SetParent(nil)
                end
            end
        end
    end

    for i = #createdRows, 1, -1 do
        local r = createdRows[i]
        if r then
            if type(r.Destroy) == "function" then
                r:Destroy()
            else
                r:SetHidden(true)
                r:ClearAnchors()
                r:SetParent(nil)
            end
        end
        createdRows[i] = nil
    end

    scrollChild:SetHeight(0)
end

-- ================== КЭШИРОВАНИЕ ==================
local function BuildZoneCache(zoneId)
    local achievementIds = ZONE_ACHIEVEMENTS[zoneId] or {}
    local zoneCache = {}

    for _, achId in ipairs(achievementIds) do
        local achInfo = ZA:GetAchievementInfo(achId)
        local done, total = ZA:GetAchievementProgress(achId)
        table.insert(zoneCache, {
            info = achInfo,
            done = done,
            total = total,
        })
    end

    ZA.Cache[zoneId] = zoneCache
    return zoneCache
end

-- =======================
-- Глобальные функции пересчета
-- =======================
function ZA:RecalculateAll()
    if not self.rows or not self.scrollChild or not self.scroll or not self.header then return end

    local header = self.header
    local rows = self.rows
    local scrollChildLocal = self.scrollChild
    local scrollLocal = self.scroll

    for _, r in ipairs(rows) do
        if r.criteriaContainer then
            if r.criteriaContainer:IsHidden() then
                local ch = r.collapsedHeight or (r.desc and (r.desc:GetBottom() - r:GetTop() + 10) or 40)
                r:SetHeight(ch)
            else
                local newH = (r.criteriaContainer:GetBottom() - r:GetTop()) + 10
                r:SetHeight(newH)
            end
        elseif r.isDivider then
            r:SetHeight(26)
        end
    end

    local prev = header
    for _, r in ipairs(rows) do
        r:ClearAnchors()
        r:SetAnchor(TOPLEFT, prev, BOTTOMLEFT, 0, r.isDivider and 10 or 20)
        prev = r
    end

    local top = scrollChildLocal:GetTop()
    local lastBottom = prev and prev:GetBottom() or top
    local newHeight = lastBottom - top + 30
    scrollChildLocal:SetHeight(math.max(newHeight, scrollLocal:GetHeight() + 1))

    if type(ZO_Scroll_UpdateScrollBar) == "function" then
        ZO_Scroll_UpdateScrollBar(scrollLocal)
    elseif scrollLocal.UpdateScroll and type(scrollLocal.UpdateScroll) == "function" then
        scrollLocal:UpdateScroll()
    end
end

function ZA:UpdateRowWidths(newWidth)
    if not self.rows then return end
    for _, r in ipairs(self.rows) do
        local scrollbarReserve = 20
        if r.isDivider then
            r:SetWidth(newWidth - 10)
        end
        if r.desc then
            r.desc:SetWidth(newWidth - 90 - scrollbarReserve)
            r.desc:SetText(r.desc:GetText())
        end
        if r.nameLabel then
            r.nameLabel:SetWidth(newWidth - 120 - scrollbarReserve)
            r.nameLabel:SetText(r.nameLabel:GetText())
        end
        if r.barFrame then
            local newBarWidth = math.max(newWidth - 180 - scrollbarReserve, 120)
            r.barFrame:SetWidth(newBarWidth + 4)
        end
        if r.criteriaContainer and r.criteriaContainer:GetNumChildren() > 0 then
            for i = 1, r.criteriaContainer:GetNumChildren() do
                local critRow = r.criteriaContainer:GetChild(i)
                if critRow and critRow:GetNumChildren() > 1 then
                    local critLabel = critRow:GetChild(2)
                    if critLabel and critLabel.SetWidth then
                        critLabel:SetWidth(newWidth - 140 - scrollbarReserve)
                        critLabel:SetText(critLabel:GetText())
                    end
                end
            end
        end
    end
    zo_callLater(function() ZA:RecalculateAll() end, 50)
end

-- ================== ЛОГИКА ИСТОРИИ ==================
function ZA:AddSneezeToHistory(achievementId)
    if not self.SavedVars then return end
    self.SavedVars.History = self.SavedVars.History or {}
    
    local done, total = self:GetAchievementProgress(achievementId)
    local completed = select(5, GetAchievementInfo(achievementId))
    local _, zoneName = self:GetCurrentZoneInfo()
    local timestamp = GetTimeStamp()

    local foundIndex = nil
    for i, entry in ipairs(self.SavedVars.History) do
        if entry.achievementId == achievementId then
            foundIndex = i
            break
        end
    end

    if foundIndex then
        local entry = self.SavedVars.History[foundIndex]
        entry.timestamp = timestamp
        entry.done = done
        entry.total = total
        entry.completed = completed
        entry.zoneName = zoneName

        table.remove(self.SavedVars.History, foundIndex)
        table.insert(self.SavedVars.History, 1, entry)
    else
        table.insert(self.SavedVars.History, 1, {
            achievementId = achievementId,
            timestamp = timestamp,
            zoneName = zoneName,
            done = done,
            total = total,
            completed = completed
        })
    end
end

function ZA:CleanupHistory()
    if not self.SavedVars or not self.SavedVars.History then return end
    local now = GetTimeStamp()
    local history = self.SavedVars.History

    for i = #history, 1, -1 do
        local entry = history[i]
        if (now - entry.timestamp) > 86400 then
            table.remove(history, i)
        end
    end
end

function ZA:FormatTimeElapsed(timestamp)
    local now = GetTimeStamp()
    local elapsed = now - timestamp
    if elapsed < 0 then elapsed = 0 end

    if elapsed < 60 then
        return L.justNow
    elseif elapsed < 3600 then
        local mins = math.floor(elapsed / 60)
        return string.format(L.minutesAgo, mins)
    else
        local hours = math.floor(elapsed / 3600)
        return string.format(L.hoursAgo, hours)
    end
end

-- ================== Показ окна ==================
function ZA:ShowZoneAchievementsWindow()
    if self.CurrentTab == "history" then
        self:CleanupHistory()
    end

    local zoneId, zoneName = self:GetCurrentZoneInfo()
    local cache = {}

    if self.ZoneLabel then
        if self.CurrentTab == "history" then
            self.ZoneLabel:SetText("|cFFFF00" .. L.historyTitle .. "|r")
        else
            self.ZoneLabel:SetText(string.format("|cFFFF00%s|r |cAAAAAA(ID: %d)|r", zoneName, zoneId))
        end
    end

    if self.CurrentTab == "history" then
        local historyList = self.SavedVars.History or {}
        for _, entry in ipairs(historyList) do
            local achInfo = self:GetAchievementInfo(entry.achievementId)
            table.insert(cache, {
                info = achInfo,
                done = entry.done,
                total = entry.total,
                isHistoryEntry = true,
                timestamp = entry.timestamp,
                zoneName = entry.zoneName
            })
        end
    else
        cache = BuildZoneCache(zoneId)
    end

    ClearScrollChild()

    local leftPadding = 6
    local blockWidth = scrollChild:GetWidth()
    local rows = {}

    local header = WINDOW_MANAGER:CreateControl(nil, scrollChild, CT_CONTROL)
    header:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, leftPadding, 10)
    header:SetHidden(true)

    if #cache == 0 then
        ZA.rows = {}
        ZA.header = header
        ZA.scrollChild = scrollChild
        ZA.scroll = scroll
        ZA:RecalculateAll()
        ZAWindow:SetHidden(false)
        return
    end

    -- ================= СОРТИРОВКА =================
    local ordered = {}
    if self.CurrentTab == "history" then
        ordered = cache
    else
        local specialList, vetList, recentList, completedList, incompleteList = {}, {}, {}, {}, {}
        
        for _, entry in ipairs(cache) do
            local sType = self:GetAchievementSpecialType(entry.info.id)
            local lastUpdate = self.RecentUpdates[entry.info.id]
            local isRecent = lastUpdate and (GetFrameTimeSeconds() - lastUpdate <= (self.SavedVars.recentDuration or 300))

            if sType then
                table.insert(specialList, entry)
            elseif self:IsVeteranAchievement(entry.info) then
                table.insert(vetList, entry)
            elseif isRecent then
                table.insert(recentList, entry)
            elseif entry.info and entry.info.completed then
                table.insert(completedList, entry)
            else
                table.insert(incompleteList, entry)
            end
        end

        -- Внутри ветеранского списка сначала показываем невыполненные
        table.sort(vetList, function(a, b)
            if a.info.completed ~= b.info.completed then
                return not a.info.completed
            end
            return a.info.id < b.info.id
        end)

        -- Лестница сложности: 1.ВЕТ -> 2.СПИДРАН -> 3.НЕУМИРАЙКА -> 4.ХМ (+1,+2,+3) -> 5.ТРИФЕКТА -> 6.НЕВЗГОДЫ (1..3)
        local typeWeight = { 
            ["VET"] = 1, ["SPEED"] = 2, ["NODEATH"] = 3, ["HM"] = 4, ["TRIFECTA"] = 5,
            ["MISFORTUNE_1"] = 6, ["MISFORTUNE_2"] = 7, ["MISFORTUNE_3"] = 8 
        }
        table.sort(specialList, function(a, b)
            local sTypeA = self:GetAchievementSpecialType(a.info.id)
            local sTypeB = self:GetAchievementSpecialType(b.info.id)
            local wA = typeWeight[sTypeA] or 99
            local wB = typeWeight[sTypeB] or 99
            if wA ~= wB then
                return wA < wB
            else
                return a.info.id < b.info.id
            end
        end)

        -- 1. Выводим ТОП-лестницу испытаний
        if #specialList > 0 then
            table.insert(ordered, { isDivider = true, text = L.specialHeader or "Главные испытания" })
        end
        for _, e in ipairs(specialList) do table.insert(ordered, e) end

        -- 2. Разделитель и блок ветеранских ачивок
        if #vetList > 0 then
            table.insert(ordered, { isDivider = true, text = L.vetHeader or "Ветеранский режим" })
            for _, e in ipairs(vetList) do table.insert(ordered, e) end
        end

        -- 3. Разделитель и блок обычных/прочих ачивок
        local hasRegulars = (#recentList > 0) or (#completedList > 0) or (#incompleteList > 0)
        if (#specialList > 0 or #vetList > 0) and hasRegulars then
            table.insert(ordered, { isDivider = true, text = L.otherHeader or "Прочие достижения" })
        end

        for _, e in ipairs(recentList) do table.insert(ordered, e) end
        for _, e in ipairs(completedList) do table.insert(ordered, e) end
        for _, e in ipairs(incompleteList) do table.insert(ordered, e) end
    end

    -- ================= ЦИКЛ ПО АЧИВКАМ =================
    for _, entry in ipairs(ordered) do
        if entry.isDivider then
            -- Отрисовка разделителя
            local divRow = WINDOW_MANAGER:CreateControl(nil, scrollChild, CT_CONTROL)
            divRow:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, leftPadding, 0)
            divRow:SetDimensions(blockWidth - 10, 26)
            divRow.isDivider = true

            local divLabel = WINDOW_MANAGER:CreateControl(nil, divRow, CT_LABEL)
            divLabel:SetFont("ZoFontHeader2")
            divLabel:SetAnchor(CENTER, divRow, CENTER, 0, 0)
            divLabel:SetColor(0.8, 0.7, 0.2, 0.9)
            divLabel:SetText(entry.text or L.otherHeader)

            table.insert(rows, divRow)
            table.insert(createdRows, divRow)
        else
            local achInfo = entry.info
            local done, total = entry.done, entry.total

            local percent = total > 0 and math.floor((done / total) * 100) or 0
            local statusColor = achInfo.completed and "00FF00" or "FF0000"

            local row = WINDOW_MANAGER:CreateControl(nil, scrollChild, CT_CONTROL)
            row:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, leftPadding, 0)
            row:SetWidth(blockWidth - 10)

            local rowBg = WINDOW_MANAGER:CreateControl(nil, row, CT_BACKDROP)
            rowBg:SetAnchorFill(row)
            rowBg:SetCenterColor(0, 0, 0, 0)
            rowBg:SetEdgeColor(0, 0, 0, 0)

            row:SetMouseEnabled(true)
            row:SetHandler("OnMouseEnter", function() rowBg:SetCenterColor(0.2, 0.4, 0.8, 0.25) end)
            row:SetHandler("OnMouseExit", function() rowBg:SetCenterColor(0, 0, 0, 0) end)
            
            -- Обработчик ЛКМ и ПКМ
            row:SetHandler("OnMouseUp", function(control, button, upInside)
                if not upInside then return end

                if button == MOUSE_BUTTON_INDEX_LEFT then
                    ACHIEVEMENTS:ShowAchievement(achInfo.id)
                elseif button == MOUSE_BUTTON_INDEX_RIGHT then
                    local isDev = ZA.SavedVars and ZA.SavedVars.devMode
                    local isShift = IsShiftKeyDown()

                    if isDev and not isShift then
                        ClearMenu()
                        AddMenuItem(L.menuSetVet, function() ZA:SetAchievementSpecialType(achInfo.id, "VET") end)
                        AddMenuItem(L.menuSetSpeed, function() ZA:SetAchievementSpecialType(achInfo.id, "SPEED") end)
                        AddMenuItem(L.menuSetNoDeath, function() ZA:SetAchievementSpecialType(achInfo.id, "NODEATH") end)
                        AddMenuItem(L.menuSetHM, function() ZA:SetAchievementSpecialType(achInfo.id, "HM") end)
                        AddMenuItem(L.menuSetTrifecta, function() ZA:SetAchievementSpecialType(achInfo.id, "TRIFECTA") end)
                        AddMenuItem(L.menuSetMisfortune1, function() ZA:SetAchievementSpecialType(achInfo.id, "MISFORTUNE_1") end)
                        AddMenuItem(L.menuSetMisfortune2, function() ZA:SetAchievementSpecialType(achInfo.id, "MISFORTUNE_2") end)
                        AddMenuItem(L.menuSetMisfortune3, function() ZA:SetAchievementSpecialType(achInfo.id, "MISFORTUNE_3") end)
                        AddMenuItem(L.menuClearTag, function() ZA:SetAchievementSpecialType(achInfo.id, nil) end)
                        ShowMenu(control)
                    else
                        local link = GetAchievementLink(achInfo.id)
                        if link and link ~= "" then
                            ZO_LinkHandler_InsertLink(link)
                        end
                    end
                end
            end)

            -- Иконка
            local icon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
            icon:SetDimensions(48, 48)
            icon:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
            icon:SetTexture(achInfo.icon)
            icon:SetColor(achInfo.completed and 1 or 0.35, achInfo.completed and 1 or 0.35, achInfo.completed and 1 or 0.35, 1)

            -- Название + ярлыки
            local nameLabel = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
            nameLabel:SetFont("ZoFontWinH4")
            nameLabel:SetAnchor(TOPLEFT, icon, TOPRIGHT, 10, 0)
            nameLabel:SetWidth(blockWidth - 180)
            nameLabel:SetWrapMode(TEXT_WRAP_MODE_WORD)
            nameLabel:SetMaxLineCount(2)
            nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

            local specialTag = ""
            local sType = self:GetAchievementSpecialType(achInfo.id)
            if sType == "VET" then
                specialTag = L.tagVet
            elseif sType == "SPEED" then
                specialTag = L.tagSpeed
            elseif sType == "NODEATH" then
                specialTag = L.tagNoDeath
            elseif sType == "HM" then
                specialTag = L.tagHM
            elseif sType == "TRIFECTA" then
                specialTag = L.tagTrifecta
            elseif sType == "MISFORTUNE_1" then
                specialTag = L.tagMisfortune1
            elseif sType == "MISFORTUNE_2" then
                specialTag = L.tagMisfortune2
            elseif sType == "MISFORTUNE_3" then
                specialTag = L.tagMisfortune3
            end

            local nameText = specialTag .. "|c" .. statusColor .. achInfo.name .. "|r"

            if entry.isHistoryEntry then
                local timeStr = self:FormatTimeElapsed(entry.timestamp)
                local zoneStr = entry.zoneName or L.unknown
                nameText = string.format("%s  |cAAAAAA(%s - %s)|r", nameText, timeStr, zoneStr)
            else
                local earnedDate = ""
                if achInfo.completed and achInfo.earned and achInfo.earned ~= "" then
                    earnedDate = " |cAAAAAA" .. achInfo.earned .. "|r"
                end

                local lastUpdate = self.RecentUpdates[achInfo.id]
                local isRecent = lastUpdate and (GetFrameTimeSeconds() - lastUpdate <= (self.SavedVars.recentDuration or 300))
                local recentTag = isRecent and L.recentTag or ""

                nameText = nameText .. recentTag .. "  (" .. percent .. "%)" .. earnedDate
            end

            nameLabel:SetText(nameText)
            row.nameLabel = nameLabel

            -- Кнопка плюс/минус
            local toggleBtn = WINDOW_MANAGER:CreateControl(nil, row, CT_BUTTON)
            toggleBtn:SetDimensions(24, 24)
            toggleBtn:ClearAnchors()
            toggleBtn:SetAnchor(TOPLEFT, icon, TOPLEFT, -5, -5)
            toggleBtn:SetNormalTexture("/esoui/art/buttons/plus_up.dds")
            toggleBtn:SetPressedTexture("/esoui/art/buttons/plus_down.dds")
            toggleBtn:SetMouseOverTexture("/esoui/art/buttons/plus_over.dds")

            -- Рамка для прогресс-бара
            local barFrame = WINDOW_MANAGER:CreateControl(nil, row, CT_BACKDROP)
            local barWidth = math.max(blockWidth - 180, 120)
            barFrame:SetDimensions(barWidth + 4, 22)
            barFrame:SetAnchor(TOPLEFT, nameLabel, BOTTOMLEFT, -2, 4)
            barFrame:SetCenterColor(0, 0, 0, 0)
            barFrame:SetEdgeTexture(nil, 1, 1, 1, 1)
            barFrame:SetEdgeColor(0.9, 0.7, 0.2, 1)

            -- Прогресс-бар
            local bar = WINDOW_MANAGER:CreateControl(nil, barFrame, CT_STATUSBAR)
            bar:SetAnchor(TOPLEFT, barFrame, TOPLEFT, 2, 2)
            bar:SetAnchor(BOTTOMRIGHT, barFrame, BOTTOMRIGHT, -2, -2)
            bar:SetMinMax(0, total > 0 and total or 1)
            bar:SetValue(done)
            bar:SetColor(achInfo.completed and 0 or 0.7, achInfo.completed and 0.7 or 0.2, 0.2, 1)

            -- Текст прогресса
            local progLabel = WINDOW_MANAGER:CreateControl(nil, bar, CT_LABEL)
            progLabel:SetFont("ZoFontGameSmall")
            progLabel:SetAnchor(CENTER, bar, CENTER, 0, 0)
            progLabel:SetColor(1, 1, 1, 1)
            progLabel:SetText(string.format("%d / %d", done, total))

            -- Описание
            local desc = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
            desc:SetFont("ZoFontGame")
            desc:SetAnchor(TOPLEFT, bar, BOTTOMLEFT, 0, 6)
            desc:SetWidth(blockWidth - 70)
            desc:SetWrapMode(TEXT_WRAP_MODE_WORD)
            desc:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            desc:SetText(achInfo.desc)

            -- Контейнер критериев
            local criteriaContainer = WINDOW_MANAGER:CreateControl(nil, row, CT_CONTROL)
            criteriaContainer:SetAnchor(TOPLEFT, desc, BOTTOMLEFT, 0, 6)
            local criteriaWidth = ZAWindow:GetWidth() - 80 
            criteriaContainer:SetWidth(criteriaWidth)
            criteriaContainer:SetResizeToFitDescendents(true)

            local previousCrit = nil
            local numCriteria = GetAchievementNumCriteria(achInfo.id) or 0
            for i = 1, numCriteria do
                local critDesc, cur, max, flag = GetAchievementCriterion(achInfo.id, i)
                if critDesc and critDesc ~= "" then
                    local isDone = (max and max > 0 and cur >= max) or flag

                    local critRow = WINDOW_MANAGER:CreateControl(nil, criteriaContainer, CT_CONTROL)
                    critRow:SetAnchor(TOPLEFT, previousCrit or criteriaContainer, previousCrit and BOTTOMLEFT or TOPLEFT, 0, previousCrit and 4 or 0)
                    critRow:SetWidth(criteriaWidth) 
                    critRow:SetHeight(25)

                    local critIcon = WINDOW_MANAGER:CreateControl(nil, critRow, CT_TEXTURE)
                    critIcon:SetDimensions(18, 18)
                    critIcon:SetAnchor(LEFT, critRow, LEFT, 0, 0)
                    critIcon:SetTexture(isDone and "/esoui/art/buttons/accept_up.dds" or "/esoui/art/buttons/decline_up.dds")
                    critIcon:SetColor(isDone and 0 or 1, isDone and 1 or 0, 0, 1)

                    local critLabel = WINDOW_MANAGER:CreateControl(nil, critRow, CT_LABEL)
                    critLabel:SetFont("ZoFontGame")
                    critLabel:SetAnchor(LEFT, critIcon, RIGHT, 8, 0)
                    critLabel:SetAnchor(RIGHT, critRow, RIGHT, 0, 0)
                    critLabel:SetWrapMode(TEXT_WRAP_MODE_WORD)
                    critLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
                    critLabel:SetColor(1, 1, 1, 1) 
                    
                    local displayText = max and max > 1 and string.format("%s (%d/%d)", critDesc, cur or 0, max) or critDesc
                    critLabel:SetText(displayText)

                    previousCrit = critRow
                end
            end

            criteriaContainer:SetHidden(true)

            local collapsedHeight = desc:GetBottom() - row:GetTop() + 10
            row.collapsedHeight = collapsedHeight
            row.desc = desc
            row.criteriaContainer = criteriaContainer
            row.barFrame = barFrame
            row:SetHeight(collapsedHeight)

            toggleBtn:SetHandler("OnClicked", function()
                local wasHidden = criteriaContainer:IsHidden()
                criteriaContainer:SetHidden(not wasHidden)
                if wasHidden then
                    toggleBtn:SetNormalTexture("/esoui/art/buttons/minus_up.dds")
                else
                    toggleBtn:SetNormalTexture("/esoui/art/buttons/plus_up.dds")
                end
                zo_callLater(function() ZA:RecalculateAll() end, 50)
            end)

            table.insert(rows, row)
            table.insert(createdRows, row)
        end
    end

    ZA.rows = rows
    ZA.header = header
    ZA.scrollChild = scrollChild
    ZA.scroll = scroll

    ZA:RecalculateAll()
    ZAWindow:SetHidden(false)
    -- Даём игре 50 мс рассчитать высоту текста и идеально подогнать синий бокс:
    zo_callLater(function() ZA:RecalculateAll() end, 50)
end

local function InitializeSavedVars()
    ZA.SavedVars = ZO_SavedVars:NewAccountWide("ZoneAchievements_SavedVars", 1, nil, {
        left = nil,
        top = nil,
        width = DEFAULT_WIDTH,
        height = DEFAULT_HEIGHT,
        Snapshots = {}, 
        devMode = false,
        DevDumpRaw = {},
        DevDumpFormatted = {},
        DevZoneOrder = {},
        SpecialTypes = {},
        DevSpecialFormatted = {},
        toastLeft = nil,
        toastTop = nil,
        recentDuration = 300,
        toastDuration = 5000,
        showToast = true,
        History = {},
    }, GetWorldName())

    if ZA.SavedVars.left and ZA.SavedVars.top then
        ZAWindow:ClearAnchors()
        ZAWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, ZA.SavedVars.left, ZA.SavedVars.top)
    else
        ZAWindow:ClearAnchors()
        ZAWindow:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end

    if ZAToast then
        if ZA.SavedVars.toastLeft and ZA.SavedVars.toastTop then
            ZAToast:ClearAnchors()
            ZAToast:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, ZA.SavedVars.toastLeft, ZA.SavedVars.toastTop)
        else
            ZAToast:ClearAnchors()
            ZAToast:SetAnchor(TOP, GuiRoot, TOP, 0, 150)
        end
    end

    ZAWindow:SetDimensions(ZA.SavedVars.width, ZA.SavedVars.height)
    local w, h = ZAWindow:GetDimensions()
    scroll:SetAnchor(TOPLEFT, ZAWindow, TOPLEFT, 14, 115)
    scroll:SetDimensions(w - 28, h - 135)
    scrollChild:SetWidth(scroll:GetWidth() - 10)

    ZA:CleanupHistory()
end

local function RegisterSlashCommands()
    local function SlashCommandParser(extra)
        local args = {}
        for word in string.gmatch(extra, "%S+") do
            table.insert(args, string.lower(word))
        end

        local cmd = args[1] or ""

        if cmd == "dev" then
            if ZA.SavedVars then
                ZA.SavedVars.devMode = not ZA.SavedVars.devMode
                local status = ZA.SavedVars.devMode and "|c00FF00ENABLED|r" or "|cFF0000DISABLED|r"
                d(string.format("|c39DB92[ZA]|r Developer Mode is now: %s", status))
            end

        elseif cmd == "test" then
            if ZAToast:IsHidden() then
                ZA:ShowTestToast()
                d("|c39DB92[ZA-Dev]|r Test window is shown. Left-click and drag it anywhere. Type |cFFFF00/za test|r again to hide and save position.")
            else
                ZAToast:SetHidden(true)
                d("|c39DB92[ZA-Dev]|r Position saved, test window hidden.")
            end

        elseif cmd == "recent" then
            local mins = tonumber(args[2])
            if mins and mins > 0 then
                ZA.SavedVars.recentDuration = mins * 60
                d(string.format("|c39DB92[ZA]|r [NEW] display duration set to |cFFFF00%d|r min. (Default: 5 min.)", mins))
            else
                local curMins = (ZA.SavedVars.recentDuration or 300) / 60
                d(string.format("|c39DB92[ZA]|r Current [NEW] timer: |cFFFF00%d|r min. (Default: 5 min.). To change, enter: |cFFFF00/za recent <minutes>|r", curMins))
            end

        elseif cmd == "toast" then
            local arg = args[2] or ""
            
            if arg == "off" or arg == "disable" then
                ZA.SavedVars.showToast = false
                d("|c39DB92[ZA]|r Screen notifications are now |cFF0000DISABLED|r.")
                
            elseif arg == "on" or arg == "enable" then
                ZA.SavedVars.showToast = true
                local curSecs = (ZA.SavedVars.toastDuration or 4000) / 1000
                d(string.format("|c39DB92[ZA]|r Screen notifications are now |c00FF00ENABLED|r (Duration: |cFFFF00%d|r sec.).", curSecs))
                
            else
                local secs = tonumber(arg)
                if secs and secs > 0 then
                    ZA.SavedVars.showToast = true
                    ZA.SavedVars.toastDuration = secs * 1000
                    d(string.format("|c39DB92[ZA]|r Screen notifications |c00FF00ENABLED|r, duration set to |cFFFF00%d|r sec.", secs))
                else
                    local status = (ZA.SavedVars.showToast ~= false) and "|c00FF00ENABLED|r" or "|cFF0000DISABLED|r"
                    local curSecs = (ZA.SavedVars.toastDuration or 4000) / 1000
                    d(string.format("|c39DB92[ZA]|r Screen notifications are currently: %s (Duration: |cFFFF00%d|r sec.).\nTo disable: |cFFFF00/za toast off|r. To change duration: |cFFFF00/za toast <seconds>|r", status, curSecs))
                end
            end

        elseif cmd == "id" then
            local zoneId, zoneName = ZA:GetCurrentZoneInfo()
            d(string.format("|c39DB92[ZA-Dev]|r Current Location: |cFFFF00%s|r (Zone ID: |cFFFF00%d|r)", zoneName, zoneId))

        elseif cmd == "lock" then
            local targetId = tonumber(args[2])
            if targetId and targetId > 0 then
                ZA.DevLockedZoneId = targetId
                local zoneName = GetZoneNameById(targetId) or "Unknown Zone"
                d(string.format("|c39DB92[ZA-Dev]|r Target zone LOCKED to: |cFFFF00%s|r (ID: |cFFFF00%d|r). All updates will save here!", zoneName, targetId))
            else
                d("|cFF0000[ZA-Dev] Error:|r Please specify a valid Zone ID. Example: /za lock 1552")
            end

        elseif cmd == "unlock" or cmd == "reset" then
            ZA.DevLockedZoneId = nil
            local zoneId, zoneName = ZA:GetCurrentZoneInfo()
            d(string.format("|c39DB92[ZA-Dev]|r Lock removed. Back to real location: |cFFFF00%s|r (ID: |cFFFF00%d|r)", zoneName, zoneId))

        else
            ZoneAchievements_ToggleWindow()
        end
    end

    SLASH_COMMANDS["/za"] = SlashCommandParser
    SLASH_COMMANDS["/zoneach"] = SlashCommandParser
end

ZAWindow:SetHandler("OnMoveStop", function()
    ZA.SavedVars.left, ZA.SavedVars.top = ZAWindow:GetLeft(), ZAWindow:GetTop()
end)

ZAWindow:SetHandler("OnResizeStop", function()
    local w, h = ZAWindow:GetDimensions()
    ZA.SavedVars.width, ZA.SavedVars.height = w, h
    scroll:SetDimensions(w - 28, h - 135)
    scrollChild:SetWidth(scroll:GetWidth() - 10)

    zo_callLater(function()
        ZA:UpdateRowWidths(w)
    end, 50)
end)

local function OnPlayerActivated(event)
    if ZA.SavedVars and ZA.SavedVars.devMode then
        local zoneId, zoneName = ZA:GetCurrentZoneInfo()
        d(string.format("|c39DB92[ZA-Dev]|r Entered: |cFFFF00%s|r (Zone ID: |cFFFF00%d|r)", zoneName, zoneId))
    end
end

function ZA:ToggleAchievementInDump(zoneId, zoneName, achievementId)
    self.SavedVars.DevDumpRaw = self.SavedVars.DevDumpRaw or {}
    self.SavedVars.DevDumpFormatted = self.SavedVars.DevDumpFormatted or {}
    self.SavedVars.DevZoneOrder = self.SavedVars.DevZoneOrder or {}

    self.SavedVars.DevDumpRaw[zoneId] = self.SavedVars.DevDumpRaw[zoneId] or {}
    local dumpList = self.SavedVars.DevDumpRaw[zoneId]

    local foundIndex = nil
    for i, id in ipairs(dumpList) do
        if id == achievementId then
            foundIndex = i
            break
        end
    end

    local achName = select(1, GetAchievementInfo(achievementId)) or "Unknown Achievement"

    if foundIndex then
        table.remove(dumpList, foundIndex)
        PlaySound(SOUNDS.DEFAULT_CLICK)
        d(string.format("|c39DB92[ZA-Dev]|r |cFF0000[-] Removed:|r %s (ID: %d) from zone %s", achName, achievementId, zoneName))
    else
        table.insert(dumpList, achievementId)
        PlaySound(SOUNDS.BOOK_ACQUIRED)
        d(string.format("|c39DB92[ZA-Dev]|r |c00FF00[+] Added:|r %s (ID: %d) to zone %s", achName, achievementId, zoneName))
    end

    local orderIndex = nil
    for i, id in ipairs(self.SavedVars.DevZoneOrder) do
        if id == zoneId then
            orderIndex = i
            break
        end
    end

    if #dumpList > 0 then
        if not orderIndex then
            table.insert(self.SavedVars.DevZoneOrder, zoneId)
        end
    else
        self.SavedVars.DevDumpRaw[zoneId] = nil
        if orderIndex then
            table.remove(self.SavedVars.DevZoneOrder, orderIndex)
        end
    end

    self.SavedVars.DevDumpFormatted = {}

    for _, zId in ipairs(self.SavedVars.DevZoneOrder) do
        local rawList = self.SavedVars.DevDumpRaw[zId]
        if rawList and #rawList > 0 then
            table.sort(rawList)
            local idsString = table.concat(rawList, ", ")
            local rawName = GetZoneNameById(zId) or "Unknown Zone"
            local cleanName = zo_strformat("<<1>>", rawName)
            local line = string.format("[%d] = {%s}, -- %s", zId, idsString, cleanName)
            table.insert(self.SavedVars.DevDumpFormatted, line)
        end
    end
end

ZA.LastProcessedId = 0
ZA.LastProcessedTime = 0

local function OnChatMessage(eventCode, channelType, fromName, text, isCustomerService, fromDisplayName)
    if not (ZA.SavedVars and ZA.SavedVars.devMode) then return end
    if fromDisplayName ~= GetDisplayName() then return end

    local achievementIdStr = string.match(text, "|H%d+:achievement:(%d+):")
    if achievementIdStr then
        local achievementId = tonumber(achievementIdStr)
        if achievementId and achievementId > 0 then
            
            local now = GetGameTimeMilliseconds()
            if achievementId == ZA.LastProcessedId and (now - ZA.LastProcessedTime) < 1000 then
                return
            end
            
            ZA.LastProcessedId = achievementId
            ZA.LastProcessedTime = now

            local zoneId, zoneName = ZA:GetCurrentZoneInfo()
            if zoneId and zoneId > 0 then
                ZA:ToggleAchievementInDump(zoneId, zoneName, achievementId)
            end
        end
    end
end

function ZA:ShowTestToast()
    EVENT_MANAGER:UnregisterForUpdate("ZA_Toast_Hide_Timer")
    toastIcon:SetTexture("/esoui/art/icons/icon_missing.dds")
    toastTitle:SetText(L.testTitle)
    toastProgress:SetText(L.dragMe)
    ZAToast:SetHidden(false)
end

function ZA:ShowToastNotification(achievementId, isCompleted)
    if self.SavedVars and self.SavedVars.showToast == false then return end
    if not achievementId or achievementId <= 0 then return end

    local name, _, _, icon, completed = GetAchievementInfo(achievementId)
    if not name or name == "" then return end

    local done, total = self:GetAchievementProgress(achievementId)

    toastIcon:SetTexture(icon)
    toastTitle:SetText(zo_strformat("<<1>>", name))

    if isCompleted or completed then
        toastProgress:SetText(L.completed)
    else
        toastProgress:SetText(string.format(L.progress, done, total))
    end

    ZAToast:SetHidden(false)

    local timerName = "ZA_Toast_Hide_Timer"
    EVENT_MANAGER:UnregisterForUpdate(timerName)
    EVENT_MANAGER:RegisterForUpdate(timerName, self.SavedVars.toastDuration or 4000, function()
        EVENT_MANAGER:UnregisterForUpdate(timerName)
        ZAToast:SetHidden(true)
    end)
end

function ZA:RecordRecentUpdate(achievementId)
    if not achievementId or achievementId <= 0 then return end

    local zoneId, zoneName = self:GetCurrentZoneInfo()
    if not zoneId or zoneId <= 0 then return end

    local zoneAchievements = ZONE_ACHIEVEMENTS[zoneId]
    if not zoneAchievements then return end

    local belongsToZone = false
    for _, id in ipairs(zoneAchievements) do
        if id == achievementId then
            belongsToZone = true
            break
        end
    end

    if belongsToZone then
        self.RecentUpdates[achievementId] = GetFrameTimeSeconds()

        if self.SavedVars and self.SavedVars.devMode then
            d(string.format("|c39DB92[ZA-Recent]|r Recorded fresh update for achievement ID: %d", achievementId))
        end

        if not ZAWindow:IsHidden() then
            self:ShowZoneAchievementsWindow()
        end
    end
end

local function OnAchievementUpdated(eventCode, achievementId)
    -- Игнорируем фоновые проверки предметов для уже выполненных ачивок
    local completed = select(5, GetAchievementInfo(achievementId))
    if completed then return end

    ZA:RecordRecentUpdate(achievementId)
    ZA:AddSneezeToHistory(achievementId)
    ZA:ShowToastNotification(achievementId, false)
end

local function OnAchievementAwarded(eventCode, name, points, achievementId, link)
    ZA:RecordRecentUpdate(achievementId)
    ZA:AddSneezeToHistory(achievementId)
    ZA:ShowToastNotification(achievementId, true)
end

local function OnAddOnLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    InitializeSavedVars()
    RegisterSlashCommands()
    
    ZA.CurrentTab = "zone"
    ZA:UpdateTabVisuals()
    
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CHAT_MESSAGE_CHANNEL, OnChatMessage)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACHIEVEMENT_UPDATED, OnAchievementUpdated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACHIEVEMENT_AWARDED, OnAchievementAwarded)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    
    d("|cFF00FFZoneAchievements загружен!|r Используй |cFFFF00/za|r")
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

function ZoneAchievements_ToggleWindow()
    if ZAWindow:IsHidden() then
        ZA:ShowZoneAchievementsWindow()
    else
        ZAWindow:SetHidden(true)
    end
end