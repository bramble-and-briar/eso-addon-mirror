if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS

------------------------------------------------------------------------------------------------------------------------
-- GuildHistory --
------------------------------------------------------------------------------------------------------------------------
local ENTRIES_PER_PAGE = 100 -- local ENTRIES_PER_PAGE = 100 in guildHistory_shared.lua
local MAX_PAGES = 400

local securePosthookOfGuildHistoryKeyboardInitWasDone = false
local securePosthookOfGuildHistoryKeyboardSetSelectedEventCategoryWasDone = false
local securePosthookOfGuildHistoryKeyboardPrevAndNextPageWasDone = false
local securePosthookOfGuildHistoryKeyboardGetMoreKeybindWasDone = false
local refreshLoadingSpinnerCheck = false
local guildHistoryNavFirstButton, guildHistoryNavLastButton

local guildHistoryKB = GUILD_HISTORY_KEYBOARD


local function getGuildHistoryCurrentCategoryListPages()
    if guildHistoryKB and guildHistoryKB.SetCurrentPage then
        local masterList = guildHistoryKB.masterList
        local numEntriesTotal = (masterList ~= nil and #masterList) or 1
        --local numVisibleEvents = GetOldestGuildHistoryEventIndexForUpToDateEventsWithoutGaps(guildHistoryKB.guildId, guildHistoryKB.selectedEventCategory) or 1
--d("[FCOCS]GuildHistory numEntriesTotal: " ..tostring(numEntriesTotal) .. ", numVisibleEvents: " ..tostring(numVisibleEvents))
        if numEntriesTotal <= 1 then return 1 end
        local numEntriesOfSubcategory = 0

        --Filter the total entries by the subFilter (e.g. if at banked items we got the total = deposit & withdraw, but only need to get the max pages of subcategory deposit)
        local selectedSubcategoryIndex = guildHistoryKB.selectedSubcategoryIndex
        for i = 1, numEntriesTotal do
            local data = masterList[i]
            if selectedSubcategoryIndex == data:GetUISubcategoryIndex() then
                numEntriesOfSubcategory = numEntriesOfSubcategory + 1
            end
        end
--d(">numEntriesOfSubcategory: " ..tostring(numEntriesOfSubcategory))
        if numEntriesOfSubcategory < 1 then numEntriesOfSubcategory = 1 end

        local lastPageVal = numEntriesOfSubcategory / ENTRIES_PER_PAGE
        local lastPage = (lastPageVal ~= nil and zo_ceil(lastPageVal)) or 1
        if lastPage == nil or lastPage == 0 then lastPage = 1 end
        return lastPage
    end
    return 1
end

local function showFirstPage()
    if guildHistoryKB and guildHistoryKB.SetCurrentPage then
        if guildHistoryKB.currentPage == 1 then return end
        guildHistoryKB:SetCurrentPage(1, false)
    end
end
local function showLastPage()
    if guildHistoryKB and guildHistoryKB.SetCurrentPage then
        local lastPage = getGuildHistoryCurrentCategoryListPages()
        if guildHistoryKB.currentPage == lastPage then return end
        guildHistoryKB:SetCurrentPage(lastPage, false)
    end
end

--Skips to the last page of guild history to save you pressing the arrow keys
local autoJumpToNextGuildHistoryPage = false
local function recursivelyAutoNavigateToLastGuildHistoryPage()
--d("[FCOCS]recursivelyAutoNavigateToLastGuildHistoryPage")
    autoJumpToNextGuildHistoryPage = false
    if guildHistoryKB == nil or guildHistoryKB.hasNextPage == nil or guildHistoryKB.ShowNextPage == nil then return end
    local lastPage = getGuildHistoryCurrentCategoryListPages()
    if lastPage > MAX_PAGES then lastPage = MAX_PAGES end --to prevent an endless loop, abort after 300 pages à 100 items. Should contain the 30 days history in total then

    local currentPage = guildHistoryKB.currentPage
--d(">currentPage: " ..tostring(currentPage) .. ", lastPage: " ..tostring(lastPage))
    if currentPage == nil then return end
    if lastPage <= currentPage then return end

    if currentPage < lastPage and guildHistoryKB.hasNextPage == true then
        autoJumpToNextGuildHistoryPage = true
        guildHistoryKB:ShowNextPage() --> See SecurePostHook below. Will call recursivelyAutoNavigateToLastGuildHistoryPage() again if autoJumpToNextGuildHistoryPage == true
    end
end
FCOChangeStuff.recursivelyAutoNavigateToLastGuildHistoryPage = recursivelyAutoNavigateToLastGuildHistoryPage

local function updateFirstAndLastNavButtonsVisibleState(comingFromSetPage, currentPage, advanceToLastPage)
    if guildHistoryKB == nil or not guildHistoryKB.initialized then return end

    if guildHistoryNavFirstButton ~= nil or guildHistoryNavLastButton ~= nil then
        comingFromSetPage = comingFromSetPage or false
        advanceToLastPage = advanceToLastPage or false

        local doHide = not FCOChangeStuff.settingsVars.settings.addGuildHistoryNavigationFirstAndLastPage
        guildHistoryNavFirstButton:SetHidden(doHide)
        guildHistoryNavLastButton:SetHidden(doHide)

--d("[FCOCS]updateFirstAndLastNavButtonsVisibleState - doHide: " ..tostring(doHide) .. ", comingFromSetPage: " .. tostring(comingFromSetPage))
        if doHide == true then return end

        local lastPage = getGuildHistoryCurrentCategoryListPages()
        if lastPage == nil then lastPage = 1 end
        currentPage = currentPage or guildHistoryKB.currentPage

--d(">currentPage: " ..tostring(currentPage) .. ", lastPage: " .. tostring(lastPage))

        if guildHistoryNavFirstButton ~= nil then
            --Are we currently on the 1st page: Hide it
            if currentPage ~= nil and currentPage == 1 then
                guildHistoryNavFirstButton:SetEnabled(false)
            else
                guildHistoryNavFirstButton:SetEnabled(true)
            end
        end
        if guildHistoryNavLastButton ~= nil then
            --Are we currently on the last page: Hide it
            if (not guildHistoryKB.hasNextPage or (currentPage ~= nil and currentPage >= lastPage)) then
                guildHistoryNavLastButton:SetEnabled(false)
            else
                guildHistoryNavLastButton:SetEnabled(true)
                guildHistoryNavLastButton.data = {
                    tooltip = "Last page: " .. tostring(lastPage)
                }

                if advanceToLastPage == true then
                    showLastPage()
                end
            end
        end
    end
end

local function showTooltip(ctrl, isFirstButton)
    ZO_Tooltips_HideTextTooltip()
    if ctrl == nil or ctrl.data == nil or ctrl.data.tooltip == nil then return end
    ZO_Tooltips_ShowTextTooltip(ctrl, isFirstButton and LEFT or RIGHT, ctrl.data.tooltip)
end

local function createGuildHistoryFirstAndLastNavigationButtons()
    if not FCOChangeStuff.settingsVars.settings.addGuildHistoryNavigationFirstAndLastPage then return end
--d("[FCOCS]createGuildHistoryFirstAndLastNavigationButtons")

    local guildHistoryCtrl = guildHistoryKB.control -- > ZO_GuildHistory_Keyboard_TL
    if guildHistoryCtrl == nil then return end
    local footerCtrl = guildHistoryCtrl:GetNamedChild("Footer")
    if footerCtrl == nil then return end
    local prevButton = footerCtrl:GetNamedChild("PreviousButton")
    if prevButton == nil then return end
    local nextButton = footerCtrl:GetNamedChild("NextButton")
    if nextButton == nil then return end
    guildHistoryNavFirstButton = CreateControl("FCOChangeStuff_GuildHistory_Nav_FirstPageButton", footerCtrl, CT_BUTTON)
    if guildHistoryNavFirstButton ~= nil then
        guildHistoryNavFirstButton:SetHidden(true)
        guildHistoryNavFirstButton:SetDimensions(64, 64)
        guildHistoryNavFirstButton:ClearAnchors()
        guildHistoryNavFirstButton:SetHandler("OnClicked", function()
            showFirstPage()
        end)
        guildHistoryNavFirstButton.data = {
            tooltip = "First page"
        }
        guildHistoryNavFirstButton:SetHandler("OnMouseEnter", function(ctrl)
            showTooltip(ctrl, true)
        end)
        guildHistoryNavFirstButton:SetHandler("OnMouseExit", function(ctrl)
            ZO_Tooltips_HideTextTooltip()
        end)
        guildHistoryNavFirstButton:SetNormalTexture("EsoUI/Art/Buttons/large_leftArrow_up.dds")
        guildHistoryNavFirstButton:SetPressedTexture("EsoUI/Art/Buttons/large_leftArrow_down.dds")
        guildHistoryNavFirstButton:SetMouseOverTexture("EsoUI/Art/Buttons/large_leftArrow_over.dds")
        guildHistoryNavFirstButton:SetDisabledTexture("EsoUI/Art/Buttons/large_leftArrow_disabled.dds")
        guildHistoryNavFirstButton:SetAnchor(RIGHT, prevButton, LEFT, -10, 0)
    end
    guildHistoryNavLastButton = CreateControl("FCOChangeStuff_GuildHistory_Nav_LastPageButton", footerCtrl, CT_BUTTON)
    if guildHistoryNavLastButton ~= nil then
        guildHistoryNavLastButton:SetHidden(true)
        guildHistoryNavLastButton:SetDimensions(64, 64)
        guildHistoryNavLastButton:ClearAnchors()
        guildHistoryNavLastButton:SetHandler("OnClicked", function()
            showLastPage()
        end)
        guildHistoryNavLastButton:SetHandler("OnMouseEnter", function(ctrl)
            showTooltip(ctrl, false)
        end)
        guildHistoryNavLastButton:SetHandler("OnMouseExit", function(ctrl)
            ZO_Tooltips_HideTextTooltip()
        end)
        guildHistoryNavLastButton:SetNormalTexture("EsoUI/Art/Buttons/large_rightArrow_up.dds")
        guildHistoryNavLastButton:SetPressedTexture("EsoUI/Art/Buttons/large_rightArrow_down.dds")
        guildHistoryNavLastButton:SetMouseOverTexture("EsoUI/Art/Buttons/large_rightArrow_over.dds")
        guildHistoryNavLastButton:SetDisabledTexture("EsoUI/Art/Buttons/large_rightArrow_disabled.dds")
        guildHistoryNavLastButton:SetAnchor(LEFT, nextButton, RIGHT, 10, 0)
    end
end

local function addFirstAndLastPageControlsToGuildHistoryNavigation()
--d("[FCOCS]addFirstAndLastPageControlsToGuildHistoryNavigation")
    if guildHistoryKB == nil or not guildHistoryKB.initialized then return end
    if guildHistoryNavFirstButton == nil and guildHistoryNavLastButton == nil then
        --Create the extra first and last navigation buttons
        createGuildHistoryFirstAndLastNavigationButtons()
    end
    updateFirstAndLastNavButtonsVisibleState()
end

local function callDelayedUpdateOfFirstAndLastNavButtonsVisibleState(delay, currentPage, advanceToLastPage)
--d("[FCOCS]callDelayedUpdateOfFirstAndLastNavButtonsVisibleState - delay: " ..tostring(delay) ..", currentPage: " ..tostring(currentPage) ..", advanceToLastPage: " ..tostring(advanceToLastPage))
    delay = delay or 25
    zo_callLater(function()
        updateFirstAndLastNavButtonsVisibleState(nil, currentPage, advanceToLastPage)
    end, delay)
end


function FCOChangeStuff.GuildHistoryNavigationHelper()

    if FCOChangeStuff.settingsVars.settings.addGuildHistoryNavigationFirstAndLastPage == true then
        --Coming from LAM settings after guild history was initialized already?
        if guildHistoryKB ~= nil and guildHistoryKB.initialized == true then
            addFirstAndLastPageControlsToGuildHistoryNavigation()
        end

        --Called once as this addon loads, or LAM settings change to "enabled"
        if not securePosthookOfGuildHistoryKeyboardInitWasDone then
            SecurePostHook(ZO_GuildHistory_Shared, "OnDeferredInitialize", function()
    --d("[FCOCS]ZO_GuildHistory_Shared:OnDeferredInitialize")
                addFirstAndLastPageControlsToGuildHistoryNavigation()
            end)
            securePosthookOfGuildHistoryKeyboardInitWasDone = true
        end

        if not securePosthookOfGuildHistoryKeyboardSetSelectedEventCategoryWasDone then
            SecurePostHook(ZO_GuildHistory_Shared, "SetSelectedEventCategory", function(selfVar, eventCategory, subcategoryIndex)
--d("[FCOCS]ZO_GuildHistory_Shared:SetSelectedEventCategory")
                refreshLoadingSpinnerCheck = false
                callDelayedUpdateOfFirstAndLastNavButtonsVisibleState(25)
            end)
            securePosthookOfGuildHistoryKeyboardSetSelectedEventCategoryWasDone = true
        end

        if not securePosthookOfGuildHistoryKeyboardPrevAndNextPageWasDone then
            SecurePostHook(ZO_GuildHistory_Shared, "ShowPreviousPage", function()
--d("[FCOCS]ZO_GuildHistory_Shared:ShowPreviousPage")
                callDelayedUpdateOfFirstAndLastNavButtonsVisibleState(25)
            end)
            SecurePostHook(ZO_GuildHistory_Shared, "ShowNextPage", function()
--d("[FCOCS]ZO_GuildHistory_Shared:ShowNextPage")
                callDelayedUpdateOfFirstAndLastNavButtonsVisibleState(25)

                --Jump to next guild history page automatically?
                if autoJumpToNextGuildHistoryPage == true then
                    recursivelyAutoNavigateToLastGuildHistoryPage()
                end
            end)
            SecurePostHook(ZO_GuildHistory_Shared, "SetCurrentPage", function(selfVar, newCurrentPage, suppressRefresh)
--d("[FCOCS]ZO_GuildHistory_Shared:SetCurrentPage-newCurrentPage: " ..tostring(newCurrentPage))
                --if newCurrentPage == nil then return end
                callDelayedUpdateOfFirstAndLastNavButtonsVisibleState(50, newCurrentPage)
            end)
            securePosthookOfGuildHistoryKeyboardPrevAndNextPageWasDone = true
        end

        if not securePosthookOfGuildHistoryKeyboardGetMoreKeybindWasDone then
            local updateHandlerName = "FCOCS_GuildHistory_TryAdvanceToLastPage"
            local triesExecuted = 0

            local function tryAdvanceToLastPage(selfVar, maxTries)
                maxTries = maxTries or 1
--d("[FCOCS]ZO_GuildHistory_Shared:RefreshLoadingSpinner - refreshLoadingSpinnerCheck: " ..tostring(refreshLoadingSpinnerCheck))
                if not refreshLoadingSpinnerCheck or triesExecuted >= maxTries then
                    EVENT_MANAGER:UnregisterForUpdate(updateHandlerName)
                    refreshLoadingSpinnerCheck = false
                    return
                end
                triesExecuted = triesExecuted + 1

                local showLoadingSpinner = false
                if selfVar.guildId and selfVar.selectedEventCategory then
                    local requestLoadingSpinner = selfVar:GetRequestForSelection()
                    --If the request is queued or pending, we want to show the loading spinner
                    if requestLoadingSpinner:IsRequestQueued() or requestLoadingSpinner:IsRequestQueuedFromAddon() or requestLoadingSpinner:IsRequestResponsePending() then
                        showLoadingSpinner = true
                    end
                end
--d(">showLoadingSpinner: " .. tostring(showLoadingSpinner))
                --No request pending, all done?
                if showLoadingSpinner == false then
                    EVENT_MANAGER:UnregisterForUpdate(updateHandlerName)
                    callDelayedUpdateOfFirstAndLastNavButtonsVisibleState(50, nil, true)
                    refreshLoadingSpinnerCheck = false
                end

                if triesExecuted == maxTries then
                    EVENT_MANAGER:UnregisterForUpdate(updateHandlerName)
                    refreshLoadingSpinnerCheck = false
                end
            end

            local function tryAdvancedToLastPageSetup(selfVar, maxTries, delay)
                maxTries = maxTries or 5
                delay = delay or 500

--d("[FCOCS]tryAdvancedToLastPageSetup")
                triesExecuted = 0
                EVENT_MANAGER:UnregisterForUpdate(updateHandlerName)
                EVENT_MANAGER:RegisterForUpdate(updateHandlerName, delay, function() tryAdvanceToLastPage(selfVar, maxTries) end)
            end

            SecurePostHook(ZO_GuildHistory_Shared, "TryShowMore", function(selfVar)
--d("[FCOCS]ZO_GuildHistory_Shared:TryShowMore")
                refreshLoadingSpinnerCheck = false
                local request = selfVar:GetRequestForSelection()
                local readyState = request:RequestMoreEvents()
                if readyState == nil or readyState == GUILD_HISTORY_DATA_READY_STATE_ON_COOLDOWN then
--d("<ABORT! readyState = " ..tostring(readyState))
                    EVENT_MANAGER:UnregisterForUpdate(updateHandlerName)
                    return false
                end
--d(">refreshLoadingSpinnerCheck set to TRUE")
                refreshLoadingSpinnerCheck = true

                tryAdvancedToLastPageSetup(selfVar, 20, 500) --try 10 seconds, each 1/2 second 1 try (20 in total)
            end)
            securePosthookOfGuildHistoryKeyboardGetMoreKeybindWasDone = true
        end


    else
        updateFirstAndLastNavButtonsVisibleState()
    end
end

function FCOChangeStuff.GuildHistoryChanges()
    FCOChangeStuff.GuildHistoryNavigationHelper()
end
